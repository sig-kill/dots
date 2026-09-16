-- Music player wibar widget: album art plus the "<status> artist - title"
-- text for the currently playing track.
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
local GLib = require("lgi").GLib
local wibox = require("wibox")
local profile = require("profile")

local player = profile.media_player or "fooyin"

local dpi = require("beautiful.xresources").apply_dpi

local music = {}

local progress_ratio = 0
local last_pos_us = 0
local track_len_us = 0
local last_sync_us = 0
local is_playing = false
local progress_color = gears.color(beautiful.music_progress_bg or beautiful.bg_focus)

local text_widget = wibox.widget.textbox()
local art_widget = wibox.widget {
  resize          = true,
  downscale       = true,
  upscale         = true,
  scaling_quality = "good",
  forced_width    = dpi(16), -- the wibar is theme.wibar_height, dpi(20), tall
  forced_height   = dpi(16),
  widget          = wibox.widget.imagebox,
}
-- Icon left of the text, 4px of gap after it. Declarative construction
-- throughout: `wibox.layout.fixed.horizontal { a, b }` (call form) hands the
-- layout that table as a single bogus child on this somewm build, leaving the
-- row zero sized, and `wibox.container.margin` needs a real widget, not a
-- table. The slot goes invisible when a track has no art, so the icon and its
-- gap leave together.
local art_slot = wibox.widget {
  art_widget,
  right  = dpi(4),
  layout = wibox.container.margin,
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
-- one wibar per output), hence the module-level state below. Wrapped in a
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

-- MPRIS artUrl is a URI -- fooyin writes
-- "file:///home/<user>/.cache/fooyin/covers/<hash>.jpg" -- while imagebox wants
-- a plain path, so percent-decode it. Non-file URIs (streaming players hand out
-- http(s)) are ignored; fooyin never emits them.
local function art_path(url)
  local path = url and url:match("^file://(.*)$")
  if not path then return nil end
  return (path:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end))
end

-- Load uncached: imagebox:set_image(path) goes through gears.surface, whose
-- cache is keyed by file name and never invalidated. Art is only read when
-- artUrl changes, so one surface per track is cheap.
local function apply_art(url)
  local path = art_path(url)
  local surface = path and gears.filesystem.file_readable(path)
    and gears.surface.load_uncached(path)
  if surface and art_widget:set_image(surface) then
    art_slot:set_visible(true)
  else
    art_slot:set_visible(false)
  end
end

local MPRIS_FILE = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/somewm-mpris"

-- "<status> artist - title", art URL, position (us), and length (us), tab
-- separated. Single quoted for the shell; the tabs are literal, and the parse
-- below splits on the same bytes. Referencing {{position}} makes `playerctl -F`
-- emit once per second while playing (in addition to immediate emits on seek,
-- pause, or track change).
local MPRIS_FORMAT = "'<{{status}}> {{artist}} - {{title}}\t{{mpris:artUrl}}\t{{position}}\t{{mpris:length}}'"

local mpris_text
local mpris_art_url

-- Reads the state the follower wrote; never spawns anything, so it is cheap
-- enough to run many times a second. Between 1-second playerctl position
-- updates, elapsed time is interpolated monotonically on each 0.15s tick.
local function refresh_player_state()
  local now_us = GLib.get_monotonic_time()
  local f = io.open(MPRIS_FILE, "r")
  if f then
    local line = f:read("*l")
    f:close()
    if line and line ~= mpris_text then
      mpris_text = line
      local meta, url, pos_str, len_str = line:match("^(.-)\t(.-)\t(.-)\t(.*)$")
      if not meta then
        meta, url = line:match("^(.-)\t(.*)$")
        if not meta then
          meta, url = line, nil
        end
      end

      is_playing = meta:match("^<Playing>") ~= nil
      last_pos_us = tonumber(pos_str) or 0
      track_len_us = tonumber(len_str) or 0
      last_sync_us = now_us

      text_widget:set_text(meta:gsub('<Playing>', ''):gsub('<.+>', ''))
      -- The status token is part of the streamed line, so a play/pause change
      -- redraws here even when the track stays the same. fg_focus is the
      -- theme's focused element colour -- the same one the focused tag and
      -- task text use; nil while not playing means "inherit the wibar fg".
      text_slot:set_fg(is_playing and beautiful.fg_focus or nil)
      if url ~= mpris_art_url then
        mpris_art_url = url
        apply_art(url)
      end
    end
  end

  local current_pos_us = last_pos_us
  if is_playing and track_len_us > 0 then
    current_pos_us = last_pos_us + (now_us - last_sync_us)
  end

  local new_ratio = (track_len_us > 0)
    and math.min(1, math.max(0, current_pos_us / track_len_us))
    or 0

  if new_ratio ~= progress_ratio then
    progress_ratio = new_ratio
    music.widget:emit_signal("widget::redraw_needed")
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
  awful.spawn.with_shell(
    "exec 9>'" .. MPRIS_FILE .. ".lock'; flock -n 9 || exit 0; "
    .. "while :; do playerctl -p '" .. player .. "' metadata -F --format "
    .. MPRIS_FORMAT .. " 2>/dev/null 9>&- | while IFS= read -r line; do "
    .. "printf '%s\\n' \"$line\" > '" .. MPRIS_FILE .. ".tmp' && "
    .. "mv '" .. MPRIS_FILE .. ".tmp' '" .. MPRIS_FILE .. "'; done; "
    .. "sleep 1; done")
end

start_follow()

gears.timer {
  timeout = 0.15,
  call_now = true,
  autostart = true,
  callback = refresh_player_state,
}

-- Buttons on the row, not the textbox, so the album art is clickable too.
music.widget:buttons(gears.table.join(
  awful.button({}, 1, function()
    awful.spawn.with_shell("playerctl -p '" .. player .. "' play-pause")
  end)))

return music
