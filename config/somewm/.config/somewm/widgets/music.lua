-- Music player wibar widget: album art plus the "artist - title" text for the
-- currently playing track, with an Adaptive Pastel hover popup and waveform.
--
-- One long-lived `playerctl --follow` process streams the player state into a
-- runtime file, and this widget only reads that file on a fast timer. Two
-- constraints shape that split:
--
--   * The follow output cannot be read in-process. `--follow` through
--     awful.spawn.with_line_callback leaves an lgi (Gio) callback that outlives
--     a config reload and crashes the compositor when the abandoned callback
--     fires. Spawning a process and reading a plain file are both reload-safe.
--   * Forking `playerctl` from the widget timer costs milliseconds per tick
--     (2.8ms measured on this machine), so hanging the update latency off the
--     tick rate would hang it off a CPU budget. With the fork moved out of the
--     tick, a tick is one io.open/read/close (~3us) and the timer runs at 0.15s.

local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")
local lgi = require("lgi")
local cairo = lgi.cairo
local GdkPixbuf = lgi.GdkPixbuf
local GLib = lgi.GLib
local wibox = require("wibox")
local profile = require("profile")

local player = profile.media_player or "fooyin"
local dpi = require("beautiful.xresources").apply_dpi

local music = {}

-----------------------------------
-- Constants & module-level state --
-----------------------------------

local BAR_ART_SZ = dpi(16)
local POPUP_ART_SZ = dpi(88)
local POPUP_MIN_W = dpi(280)
local POPUP_MAX_W = dpi(460)
local BLUR_SZ = 14
local WAVE_W, WAVE_H = 400, 40

local MPRIS_FILE = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/somewm-mpris"
local WAVE_FILE = MPRIS_FILE .. "-wave.png"

-- Status, art URL, track URL, position (us), length (us), albumArtist, artist,
-- album, and title, tab separated. Referencing {{position}} makes `playerctl -F`
-- emit once per second while playing (in addition to immediate emits on seek,
-- pause, stop, or track change).
local MPRIS_FORMAT = "{{status}}\t{{mpris:artUrl}}\t{{xesam:url}}\t{{position}}\t{{mpris:length}}\t{{xesam:albumArtist}}\t{{artist}}\t{{album}}\t{{title}}"

local progress_color = gears.color(beautiful.music_progress_bg or beautiful.bg_focus)
local bold_font = (beautiful.font and beautiful.font:gsub("%s+([%d%.]+)$", " Bold %1"))
  or "Hack Nerd Font Bold 10"

local has_track, is_playing = false, false
local progress_ratio = 0
local last_pos_us, track_len_us, last_sync_us = 0, 0, 0
local mpris_text, mpris_meta_key, mpris_art_url, mpris_wave_path
local art_surface, blur_surface, wave_surface
local wave_pending = false
local is_hovered, last_hover_geo = false, nil

local function make_art_imagebox(size)
  return wibox.widget {
    resize          = true,
    downscale       = true,
    upscale         = true,
    scaling_quality = "good",
    forced_width    = size,
    forced_height   = size,
    widget          = wibox.widget.imagebox,
  }
end

local function make_ellipsized_textbox(font)
  return wibox.widget {
    ellipsize = "end",
    font      = font,
    widget    = wibox.widget.textbox,
  }
end

------------------
-- Wibar widget --
------------------

local text_widget = wibox.widget.textbox()
local art_widget = make_art_imagebox(BAR_ART_SZ) -- the wibar is theme.wibar_height, dpi(20), tall
-- Icon left of the text, 4px of gap after it. Declarative construction
-- throughout: `wibox.layout.fixed.horizontal { a, b }` (call form) hands the
-- layout that table as a single bogus child on this somewm build, leaving the
-- row zero sized, and `wibox.container.margin` needs a real widget, not a
-- table. The slot goes invisible when a track has no art, so the icon and its
-- gap leave together.
local art_slot = wibox.widget {
  art_widget,
  right   = dpi(4),
  visible = false,
  layout  = wibox.container.margin,
}

-- text_widget wrapped so its colour can be swapped without pango markup: the
-- background container sets the context fg its child inherits, which keeps
-- artist/title text free of XML escaping. `set_fg(nil)` restores the colour
-- inherited from the wibar (beautiful.wibar_fg).
local text_slot = wibox.widget {
  text_widget,
  layout = wibox.container.background,
}

-- One instance per config load, shared by every screen's wibar (rc.lua builds
-- one wibar per output), hence the module-level state above. Wrapped in a
-- background container whose bgimage paints a fill proportional to elapsed time.
music.widget = wibox.widget {
  {
    {
      layout = wibox.layout.fixed.horizontal,
      art_slot,
      text_slot,
    },
    top    = dpi(2), -- centres the dpi(16) icon in the dpi(20) bar
    bottom = dpi(2),
    left   = dpi(4),
    right  = dpi(4),
    layout = wibox.container.margin,
  },
  bgimage = function(_, cr, width, height)
    if progress_ratio > 0 then
      cr:set_source(progress_color)
      cr:rectangle(0, 0, width * progress_ratio, height)
      cr:fill()
    end
  end,
  layout = wibox.container.background,
}

-------------------------------------
-- Shell, surface & color helpers  --
-------------------------------------

local function clamp(x, lo, hi)
  return math.min(hi, math.max(lo, x))
end

local function sh_quote(s)
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function finish_surface(surf)
  if surf and surf.finish then
    pcall(surf.finish, surf)
  end
end

local function pixbuf_to_surface(pb, path)
  if not pb or not awesome or not awesome.pixbuf_to_surface then return nil end
  local ok, raw = pcall(awesome.pixbuf_to_surface, pb._native, path)
  if not ok or not raw then return nil end
  return cairo.Surface:is_type_of(raw) and raw or cairo.Surface(raw, true)
end

-- MPRIS URIs (artUrl and xesam:url) are percent-encoded file:// URIs on local
-- tracks; imagebox and ffmpeg want a plain filesystem path.
local function uri_to_path(url)
  local path = url and url:match("^file://(.*)$")
  if not path or path == "" then return nil end
  return (path:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end))
end

local function hsl_to_rgb(h, s, l)
  if s == 0 then return l, l, l end
  local function hue2rgb(p, q, t)
    t = t % 1
    if t < 1 / 6 then return p + (q - p) * 6 * t end
    if t < 1 / 2 then return q end
    if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
    return p
  end
  local q = l < 0.5 and l * (1 + s) or (l + s - l * s)
  local p = 2 * l - q
  return hue2rgb(p, q, h + 1 / 3), hue2rgb(p, q, h), hue2rgb(p, q, h - 1 / 3)
end

local function to_byte(c)
  return math.floor(clamp(c, 0, 1) * 255 + 0.5)
end

local function to_hex(r, g, b)
  return string.format("#%02x%02x%02x", to_byte(r), to_byte(g), to_byte(b))
end

local function hex_rgb_channels(hex)
  local r, g, b = (hex or ""):match("^#(%x%x)(%x%x)(%x%x)")
  if r then
    return tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255
  end
  return 0x1A / 255, 0x22 / 255, 0x27 / 255
end

local function cache_palette_patterns(pal)
  pal.album_fg     = pal.artist_fg .. "c7"
  pal.art_border   = pal.border .. "aa"
  pal.accent_pat   = gears.color(pal.accent)
  pal.artist_pat   = gears.color(pal.artist_fg)
  pal.unplayed_pat = gears.color(pal.artist_fg .. "47")
  pal.bg_base_pat  = gears.color(pal.bg_base)
  local grad = cairo.Pattern.create_linear(0, 0, 1, 0)
  grad:add_color_stop_rgba(0.00, pal.bg_r, pal.bg_g, pal.bg_b, pal.scrim_l)
  grad:add_color_stop_rgba(0.42, pal.bg_r, pal.bg_g, pal.bg_b, pal.scrim_m)
  grad:add_color_stop_rgba(1.00, pal.bg_r, pal.bg_g, pal.bg_b, pal.scrim_r)
  pal.scrim_grad = grad
  return pal
end

local DEFAULT_PALETTE = (function()
  local bg = (beautiful.bg_normal or "#1A2227"):sub(1, 7)
  local bg_r, bg_g, bg_b = hex_rgb_channels(bg)
  return cache_palette_patterns {
    accent    = (beautiful.fg_focus or "#ACC783"):sub(1, 7),
    artist_fg = (beautiful.fg_normal or "#DED0B2"):sub(1, 7),
    pill_bg   = (beautiful.bg_focus or "#2D373C"):sub(1, 7),
    border    = (beautiful.border_color_normal or "#384348"):sub(1, 7),
    bg_base   = bg,
    bg_r      = bg_r,
    bg_g      = bg_g,
    bg_b      = bg_b,
    scrim_l   = 0.55,
    scrim_m   = 0.88,
    scrim_r   = 0.94,
  }
end)()

local palette = DEFAULT_PALETTE

-- Extract dominant chroma-weighted hue and average relative luminance from a
-- 14x14 downscaled pixbuf, locking lightness (L=78% title/wave, L=90% artist)
-- and clamping scrim alpha so contrast stays >=7.5:1 even on pure white art.
-- Uses GdkPixbuf because lgi.cairo.ImageSurface:get_data() returns raw userdata
-- rather than a Lua string on this build.
local function extract_palette_from_pixbuf(pb)
  if not pb then return DEFAULT_PALETTE end

  local w, h = pb:get_width(), pb:get_height()
  local ch = pb:get_n_channels()
  local stride = pb:get_rowstride()
  local data = pb:read_pixel_bytes():get_data()

  local lum_sum = 0
  local cos_sum, sin_sum = 0, 0

  for y = 0, h - 1 do
    local row = y * stride
    for x = 0, w - 1 do
      local idx = row + x * ch + 1
      local r, g, b = string.byte(data, idx, idx + 2)
      r, g, b = (r or 0) / 255, (g or 0) / 255, (b or 0) / 255
      lum_sum = lum_sum + (0.2126 * r + 0.7152 * g + 0.0722 * b)

      local maxc = math.max(r, g, b)
      local minc = math.min(r, g, b)
      local d = maxc - minc
      if d > 0.08 then
        local hue
        if maxc == r then
          hue = ((g - b) / d) % 6
        elseif maxc == g then
          hue = (b - r) / d + 2
        else
          hue = (r - g) / d + 4
        end
        local angle = (hue / 6) * 2 * math.pi
        local wgt = d * d
        cos_sum = cos_sum + math.cos(angle) * wgt
        sin_sum = sin_sum + math.sin(angle) * wgt
      end
    end
  end

  local lum = lum_sum / (w * h)
  local chromatic = math.sqrt(cos_sum * cos_sum + sin_sum * sin_sum) > 0.05
  local hue = chromatic and ((math.atan2(sin_sum, cos_sum) / (2 * math.pi)) % 1) or 0.25
  local sat_scale = chromatic and 1.0 or 0.25
  local bg_r, bg_g, bg_b = hsl_to_rgb(hue, 0.24 * sat_scale, 0.11)
  local function hsl_hex(s, l)
    return to_hex(hsl_to_rgb(hue, s * sat_scale, l))
  end

  return cache_palette_patterns {
    accent    = hsl_hex(0.78, 0.78),
    artist_fg = hsl_hex(0.28, 0.90),
    pill_bg   = hsl_hex(0.26, 0.18),
    border    = hsl_hex(0.28, 0.30),
    bg_base   = to_hex(bg_r, bg_g, bg_b),
    bg_r      = bg_r,
    bg_g      = bg_g,
    bg_b      = bg_b,
    scrim_l   = 0.50 + 0.18 * lum,
    scrim_m   = 0.84 + 0.09 * lum,
    scrim_r   = 0.92 + 0.05 * lum,
  }
end

---------------------------------
-- Hover popup widget assembly --
---------------------------------

local popup_art_widget  = make_art_imagebox(POPUP_ART_SZ)
local popup_title_text  = make_ellipsized_textbox(bold_font)
local popup_artist_text = make_ellipsized_textbox(bold_font)
local popup_album_text  = make_ellipsized_textbox()

local popup_art_frame = wibox.widget {
  popup_art_widget,
  border_width = dpi(1),
  layout       = wibox.container.background,
}

local popup_art_slot = wibox.widget {
  {
    popup_art_frame,
    valign = "center",
    layout = wibox.container.place,
  },
  right   = dpi(10),
  visible = false,
  layout  = wibox.container.margin,
}

local popup_title_slot = wibox.widget {
  popup_title_text,
  layout = wibox.container.background,
}

local artist_pill_bar = wibox.widget {
  forced_width = dpi(2),
  layout       = wibox.container.background,
}

local artist_pill = wibox.widget {
  {
    layout = wibox.layout.fixed.horizontal,
    artist_pill_bar,
    {
      popup_artist_text,
      left   = dpi(5),
      right  = dpi(5),
      top    = dpi(1),
      bottom = dpi(1),
      layout = wibox.container.margin,
    },
  },
  layout = wibox.container.background,
}

local popup_artist_row = wibox.widget {
  {
    layout = wibox.layout.fixed.horizontal,
    artist_pill,
  },
  strategy = "max",
  height   = dpi(20),
  layout   = wibox.container.constraint,
}

local popup_album_row = wibox.widget {
  popup_album_text,
  strategy = "max",
  height   = dpi(20),
  layout   = wibox.container.constraint,
}

local wave_widget = wibox.widget {
  forced_height = dpi(20),
  bgimage = function(_, cr, width, height)
    if width <= 0 or height <= 0 then return end
    local split_x = width * progress_ratio
    local played_pat = is_playing and palette.accent_pat or palette.artist_pat

    if wave_surface then
      local function paint_wave_slice(x, w, pat)
        if w <= 0 then return end
        cr:save()
        cr:rectangle(x, 0, w, height)
        cr:clip()
        cr:scale(width / WAVE_W, height / WAVE_H)
        cr:set_source(pat)
        cr:mask_surface(wave_surface, 0, 0)
        cr:restore()
      end
      paint_wave_slice(split_x, width - split_x, palette.unplayed_pat)
      paint_wave_slice(0, split_x, played_pat)
      return
    end

    -- Flat bar fallback for remote streams or while ffmpeg decodes the track.
    local bar_h = math.max(2, dpi(4))
    local y = math.floor((height - bar_h) / 2)
    cr:set_source(palette.unplayed_pat)
    cr:rectangle(0, y, width, bar_h)
    cr:fill()
    if split_x > 0 then
      cr:set_source(played_pat)
      cr:rectangle(0, y, split_x, bar_h)
      cr:fill()
    end
  end,
  layout = wibox.container.background,
}

local popup_pos_text = wibox.widget.textbox("00:00")
local popup_len_text = wibox.widget.textbox("00:00")

local popup_duration_section = wibox.widget {
  layout  = wibox.layout.fixed.vertical,
  spacing = dpi(2),
  {
    wave_widget,
    top    = dpi(2),
    layout = wibox.container.margin,
  },
  {
    layout = wibox.layout.align.horizontal,
    popup_pos_text,
    nil,
    popup_len_text,
  },
}

local popup_right_col = wibox.widget {
  layout  = wibox.layout.fixed.vertical,
  spacing = dpi(2),
  {
    popup_title_slot,
    strategy = "max",
    height   = dpi(20),
    layout   = wibox.container.constraint,
  },
  popup_artist_row,
  popup_album_row,
  popup_duration_section,
}

local popup_root = wibox.widget {
  {
    {
      layout = wibox.layout.fixed.horizontal,
      popup_art_slot,
      popup_right_col,
    },
    margins = dpi(8),
    layout  = wibox.container.margin,
  },
  border_width = beautiful.border_width or dpi(2),
  bgimage = function(_, cr, width, height)
    cr:set_source(palette.bg_base_pat)
    cr:paint()
    if blur_surface and width > 0 and height > 0 then
      cr:save()
      local scale = math.max(width / BLUR_SZ, height / BLUR_SZ)
      cr:translate((width - BLUR_SZ * scale) / 2, (height - BLUR_SZ * scale) / 2)
      cr:scale(scale, scale)
      cr:set_source_surface(blur_surface, 0, 0)
      local pat = cr:get_source()
      pat:set_filter(cairo.Filter.GOOD)
      pat:set_extend(cairo.Extend.PAD)
      cr:paint_with_alpha(0.85)
      cr:restore()

      cr:save()
      cr:scale(width, height)
      cr:set_source(palette.scrim_grad)
      cr:paint()
      cr:restore()
    end
  end,
  layout = wibox.container.background,
}

local popup = wibox {
  ontop   = true,
  visible = false,
  width   = POPUP_MIN_W,
  height  = dpi(108),
  bg      = gears.color.transparent,
  widget  = popup_root,
}

local function update_popup_geometry(geo)
  geo = geo or last_hover_geo
  local drawable = geo and geo.drawable
  local dgeo = drawable and drawable.drawable and drawable.drawable:geometry()
  local s = mouse.screen or awful.screen.focused()
  if dgeo and awful.screen.getbycoord then
    s = screen[awful.screen.getbycoord(dgeo.x, dgeo.y)] or s
  end
  if not s then return end

  local wa = s.workarea
  local margin = dpi(5)
  local chrome_w = ((beautiful.border_width or dpi(2)) + dpi(8)) * 2
  local art_w = popup_art_slot.visible and (POPUP_ART_SZ + dpi(1) * 2 + dpi(10)) or 0
  local title_w = popup_title_text:get_preferred_size(s)
  local artist_w = popup_artist_row.visible and (popup_artist_text:get_preferred_size(s) + dpi(12)) or 0
  local album_w = popup_album_row.visible and popup_album_text:get_preferred_size(s) or 0
  local text_w = math.ceil(math.max(title_w, artist_w, album_w))

  local max_w = math.min(POPUP_MAX_W, wa.width - 2 * margin)
  local min_w = math.min(POPUP_MIN_W, max_w)
  local width = clamp(chrome_w + art_w + text_w, min_w, max_w)

  -- Constrain right column width so long track/artist/album lines ellipsize cleanly.
  popup_right_col.forced_width = math.max(dpi(100), width - chrome_w - art_w)

  local _, fitted_h = popup_root:fit({ screen = s, dpi = s.dpi }, width, wa.height)
  local height = clamp(math.ceil(fitted_h or dpi(108)), dpi(56), wa.height - 2 * margin)

  local bar = s.mywibox
  local is_top = bar and bar.position == "top"
  local y = is_top and (wa.y + margin) or (wa.y + wa.height - height - margin)

  local max_x = wa.x + wa.width - width - margin
  local x = max_x
  if dgeo and geo and geo.x then
    local right_x = dgeo.x + geo.x + (geo.width or 0)
    x = clamp(math.floor(right_x - width), wa.x + margin, max_x)
  end

  popup:set_screen(s)
  popup:geometry { x = x, y = y, width = width, height = height }
end

---------------------------------
-- Artwork & waveform pipeline --
---------------------------------

local function apply_palette()
  popup_root:set_border_color(palette.border)
  popup_root:set_fg(palette.album_fg)
  popup_art_frame:set_border_color(palette.art_border)
  popup_title_slot:set_fg(is_playing and palette.accent or palette.artist_fg)
  artist_pill_bar:set_bg(palette.accent)
  artist_pill:set_bg(palette.pill_bg)
  artist_pill:set_fg(palette.artist_fg)
  popup_root:emit_signal("widget::redraw_needed")
  wave_widget:emit_signal("widget::redraw_needed")
end
apply_palette()

-- Decode cover art once via GdkPixbuf, center-crop to a square ("fill" from
-- center), derive the 14x14 blur surface and Adaptive Pastel palette in memory,
-- and finish previous Cairo surfaces.
local function apply_art(url)
  local old_art, old_blur = art_surface, blur_surface
  art_surface, blur_surface = nil, nil

  local path = uri_to_path(url)
  local ok, pb
  if path and gears.filesystem.file_readable(path) then
    ok, pb = pcall(GdkPixbuf.Pixbuf.new_from_file_at_scale, path, POPUP_ART_SZ * 4, POPUP_ART_SZ * 4, true)
    if ok and pb then
      local w, h = pb:get_width(), pb:get_height()
      local side = math.min(w, h)
      if side > 0 and w ~= h then
        pb = pb:new_subpixbuf(math.floor((w - side) / 2), math.floor((h - side) / 2), side, side)
      end
    end
  end

  art_surface = ok and pixbuf_to_surface(pb, path)
  if art_surface then
    local small_pb = pb:scale_simple(BLUR_SZ, BLUR_SZ, GdkPixbuf.InterpType.BILINEAR)
    blur_surface = pixbuf_to_surface(small_pb, path)
    palette = extract_palette_from_pixbuf(small_pb)
  else
    palette = DEFAULT_PALETTE
  end

  local has_art = art_surface ~= nil
  art_widget:set_image(art_surface)
  popup_art_widget:set_image(art_surface)
  art_slot:set_visible(has_art)
  popup_art_slot:set_visible(has_art)

  finish_surface(old_art)
  finish_surface(old_blur)
  apply_palette()
end

-- Spawn ffmpeg in the background on local tracks to render a 400x40 peak
-- waveform PNG mask.
local function request_waveform(path)
  finish_surface(wave_surface)
  wave_surface = nil
  wave_pending = false
  os.remove(WAVE_FILE)
  wave_widget:emit_signal("widget::redraw_needed")
  if not path or not gears.filesystem.file_readable(path) then return end

  wave_pending = true
  local tmp = WAVE_FILE .. ".tmp.png"
  awful.spawn.with_shell(string.format(
    "ffmpeg -y -v error -nostdin -i %s -filter_complex 'aformat=channel_layouts=mono,showwavespic=s=%dx%d:colors=white:draw=full:filter=peak' -frames:v 1 %s 2>/dev/null && mv %s %s",
    sh_quote(path), WAVE_W, WAVE_H, sh_quote(tmp), sh_quote(tmp), sh_quote(WAVE_FILE)))
end

------------------------------------
-- MPRIS state polling & follower --
------------------------------------

local function format_duration(total_sec)
  total_sec = math.max(0, total_sec or 0)
  local h = math.floor(total_sec / 3600)
  local m = math.floor((total_sec % 3600) / 60)
  local s = total_sec % 60
  if h > 0 then
    return string.format("%d:%02d:%02d", h, m, s)
  end
  return string.format("%02d:%02d", m, s)
end

local function update_time_labels(pos_us)
  if track_len_us <= 0 then return end
  popup_pos_text:set_text(format_duration(math.floor(pos_us / 1e6 + 0.5)))
  popup_len_text:set_text(format_duration(math.floor(track_len_us / 1e6 + 0.5)))
end

local function show_popup(geo)
  update_time_labels(last_pos_us)
  update_popup_geometry(geo)
  popup_root:emit_signal("widget::redraw_needed")
  wave_widget:emit_signal("widget::redraw_needed")
  popup.visible = true
end

-- Reads the state the follower wrote; never spawns anything on normal ticks,
-- so it is cheap enough to run many times a second. Between 1-second playerctl
-- position updates, elapsed time is interpolated monotonically on each 0.15s tick.
local function refresh_player_state()
  local now_us = GLib.get_monotonic_time()
  local line = ""
  local f = io.open(MPRIS_FILE, "r")
  if f then
    line = f:read("*l") or ""
    f:close()
  end

  if line ~= mpris_text then
    mpris_text = line
    local status, url, track_url, pos_str, len_str, album_artist, artist, album, title =
      line:match("^(.-)\t(.-)\t(.-)\t(.-)\t(.-)\t(.-)\t(.-)\t(.-)\t(.*)$")
    if not status then
      status, url, track_url, pos_str, len_str, album_artist, artist, album, title =
        "", "", "", "", "", "", "", "", ""
    end

    last_pos_us = math.max(0, tonumber(pos_str) or 0)
    last_sync_us = now_us

    local meta_key = string.format("%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s",
      status, url, track_url, len_str, album_artist, artist, album, title)
    if meta_key ~= mpris_meta_key then
      mpris_meta_key = meta_key

      local was_playing = is_playing
      local primary_artist = artist ~= "" and artist or album_artist
      has_track = (status == "Playing" or status == "Paused") and (title ~= "" or primary_artist ~= "")
      is_playing = has_track and status == "Playing"
      track_len_us = has_track and math.max(0, tonumber(len_str) or 0) or 0

      local display_title = title ~= "" and title or primary_artist
      local display_artist = title ~= "" and (album_artist ~= "" and album_artist or artist) or ""
      local bar_text = (primary_artist ~= "" and title ~= "") and (primary_artist .. " - " .. title) or display_title
      text_widget:set_text(has_track and bar_text or "")
      -- fg_focus is the theme's focused element colour -- the same one the
      -- focused tag and task text use; nil while not playing means "inherit
      -- the wibar fg".
      text_slot:set_fg(is_playing and beautiful.fg_focus or nil)

      popup_title_text:set_text(display_title)
      popup_title_slot:set_fg(is_playing and palette.accent or palette.artist_fg)

      popup_artist_text:set_text(display_artist)
      popup_artist_row:set_visible(display_artist ~= "")
      popup_album_text:set_text(album)
      popup_album_row:set_visible(album ~= "")
      popup_duration_section:set_visible(track_len_us > 0)

      local art_url = (has_track and url ~= "") and url or nil
      if art_url ~= mpris_art_url then
        mpris_art_url = art_url
        apply_art(art_url)
      end

      local wave_path = (has_track and track_len_us > 0) and uri_to_path(track_url) or nil
      if wave_path ~= mpris_wave_path then
        mpris_wave_path = wave_path
        request_waveform(wave_path)
      end

      if is_playing ~= was_playing then
        wave_widget:emit_signal("widget::redraw_needed")
      end

      if not has_track then
        is_hovered = false
        popup.visible = false
      elseif popup.visible or is_hovered then
        show_popup()
      end
    end
  end

  if wave_pending and gears.filesystem.file_readable(WAVE_FILE) then
    wave_pending = false
    finish_surface(wave_surface)
    wave_surface = gears.surface.load_uncached(WAVE_FILE)
    os.remove(WAVE_FILE)
    wave_widget:emit_signal("widget::redraw_needed")
  end

  local current_pos_us = last_pos_us
  if is_playing and track_len_us > 0 then
    current_pos_us = math.min(track_len_us, last_pos_us + (now_us - last_sync_us))
  end

  if popup.visible then
    update_time_labels(current_pos_us)
  end

  -- Quantize to 1/WAVE_W steps (1px on the 400px waveform) to avoid firing
  -- sub-pixel redraw signals across every screen's wibar at 6.67 Hz.
  local new_ratio = (track_len_us > 0)
    and math.floor(clamp(current_pos_us / track_len_us, 0, 1) * WAVE_W + 0.5) / WAVE_W
    or 0

  if new_ratio ~= progress_ratio then
    progress_ratio = new_ratio
    music.widget:emit_signal("widget::redraw_needed")
    wave_widget:emit_signal("widget::redraw_needed")
  end
end

-- Stream the player state into MPRIS_FILE, one line per MPRIS change: `--follow`
-- prints the state it starts with and then blocks until the player changes
-- anything. The line is written tmp-then-renamed so the reader above never sees
-- a half line. The outer loop restarts the follow when it exits, which is what
-- happens once fooyin goes away; the sleep keeps that retry off the CPU. The
-- flock is what makes a config reload (this file is re-executed) reuse the
-- running follower instead of starting a second: it is held for the follower's
-- lifetime, so the re-run bails out here.
local function start_follow()
  awful.spawn.with_shell(string.format([[
    out=%s
    exec 9>"$out.lock"
    flock -n 9 || exit 0
    rm -f "$out"
    while :; do
      playerctl -p %s metadata -F --format %s 2>/dev/null 9>&- | while IFS= read -r line; do
        printf '%%s\n' "$line" > "$out.tmp" && mv "$out.tmp" "$out"
      done 9>&-
      rm -f "$out"
      sleep 1 9>&-
    done
  ]], sh_quote(MPRIS_FILE), sh_quote(player), sh_quote(MPRIS_FORMAT)))
end

start_follow()

gears.timer {
  timeout = 0.15,
  call_now = true,
  autostart = true,
  callback = refresh_player_state,
}

music.widget:connect_signal("mouse::enter", function(_, geo)
  is_hovered = true
  last_hover_geo = geo
  if has_track then
    show_popup(geo)
  end
end)

music.widget:connect_signal("mouse::leave", function()
  is_hovered = false
  popup.visible = false
end)

-- Buttons on the row, not the textbox, so the album art is clickable too.
music.widget:buttons(gears.table.join(
  awful.button({}, 1, function()
    awful.spawn.with_shell("playerctl -p " .. sh_quote(player) .. " play-pause")
  end)))

return music
