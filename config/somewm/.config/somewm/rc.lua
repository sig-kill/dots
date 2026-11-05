-- If LuaRocks is installed, make sure that packages installed through it are
-- found (e.g. lgi). If LuaRocks is not installed, do nothing.
pcall(require, "luarocks.loader")

----------
-- Core --
----------

-- Standard awesome library
local awful = require("awful")
require("awful.autofocus")

local autorun = require("autorun")
local persist = require("persist")

if not awesome._restart then
  autorun.run_once('kanshi')
end

local gears = require("gears")
-- Widget and layout library
local wibox = require("wibox")
-- Theme handling library
local beautiful = require("beautiful")
local menubar = require("menubar")
-- Enable hotkeys help widget for VIM and other apps
-- when client with a matching name is opened:
require("awful.hotkeys_popup.keys")

-----------
-- Theme --
-----------

awful.screen.set_auto_dpi_enabled(true)
beautiful.init(gears.filesystem.get_configuration_dir() .. "theme.lua")
awesome.log_level = "info"

------------------------------
-- Profile and shared state --
------------------------------

local profile = require("profile")
terminal = profile.terminal

-- Keybindings own the modifier; required here because the taglist buttons
-- (widgets.taglist) are built with it.
local keybindings = require('keybindings')

-- Display role per output model, consumed by persist.lua, rules.lua and
-- layouts.lua through the global `displays`.
displays = {}
local display_map = profile.displays or {}

local function update_displays(o)
  local role = display_map[o.model]
  if role then
    displays[role] = o
  end
end

output.connect_signal("added", update_displays)

-- A disconnected output is invalidated (only `.valid` stays readable on it), so
-- drop the role instead of leaving a dead object behind. Readers guard against
-- stale entries as well; this keeps `displays` honest for the ones that only
-- compare identities.
output.connect_signal("removed", function(o)
  for role, current in pairs(displays) do
    if current == o then displays[role] = nil end
  end
end)

------------------
-- Wibar layout --
------------------

-- Options come from the profile (profile.wibar_config): per-display wibar
-- layout keyed by display role. Roles or keys left out — and profiles without
-- the field — get the defaults: bar at the bottom with every widget shown.
local function wibar_options(s)
  local role = persist.role_of(s)
  local config = profile.wibar_config or {}
  return role and config[role] or {}
end

-- Set the terminal for applications that require it.
menubar.utils.terminal = terminal

-------------
-- Layouts --
-------------

local layouts = require('layouts')
tag.connect_signal("request::default_layouts", function()
  awful.layout.append_default_layouts(layouts.list)
end)

---------------
-- Wallpaper --
---------------

math.randomseed(os.time())
math.random()

local Gio = require("lgi").Gio

local function pick_random_wallpaper()
  local dir = beautiful.wallpaper_dir or (os.getenv("HOME") .. "/Pictures/Wallpapers")
  local enumerator = Gio.File.new_for_path(dir):enumerate_children("standard::name,standard::type", 0)
  if not enumerator then return end

  local valid_exts = { jpg = true, jpeg = true, png = true, webp = true }
  local files = {}
  for info in function() return enumerator:next_file() end do
    if info:get_file_type() == "REGULAR" then
      local name = info:get_name()
      local ext = name and name:lower():match("%.([^.]+)$")
      if ext and valid_exts[ext] then
        table.insert(files, dir:gsub("/+$", "") .. "/" .. name)
      end
    end
  end
  enumerator:close()

  if #files == 0 then return end

  local candidates = files
  if #files > 1 and beautiful.wallpaper then
    candidates = {}
    for _, f in ipairs(files) do
      if f ~= beautiful.wallpaper then
        table.insert(candidates, f)
      end
    end
    if #candidates == 0 then candidates = files end
  end

  beautiful.wallpaper = candidates[math.random(#candidates)]
end

local wallpaper_cache = { path = nil, source = nil, crops = {}, used_source = false }
local retired_surfaces = {}
local screen_wallpapers = setmetatable({}, { __mode = "k" })
local cleanup_scheduled = false

local function finish_surface(surf)
  if surf and surf.finish then
    pcall(surf.finish, surf)
  end
end

local function schedule_wallpaper_cleanup()
  if cleanup_scheduled then return end
  cleanup_scheduled = true
  gears.timer.delayed_call(function()
    cleanup_scheduled = false
    for surf in pairs(retired_surfaces) do
      finish_surface(surf)
      retired_surfaces[surf] = nil
    end
    if wallpaper_cache.source and not wallpaper_cache.used_source then
      finish_surface(wallpaper_cache.source)
      wallpaper_cache.source = nil
    end
  end)
end

local function retire_wallpaper_cache()
  if wallpaper_cache.source then
    retired_surfaces[wallpaper_cache.source] = true
  end
  for _, surf in pairs(wallpaper_cache.crops) do
    retired_surfaces[surf] = true
  end
  wallpaper_cache = { path = nil, source = nil, crops = {}, used_source = false }
  schedule_wallpaper_cleanup()
end

local function wallpaper_surface_for(s)
  local path = beautiful.wallpaper
  if not path or not gears.filesystem.file_readable(path) then
    return nil
  end
  if wallpaper_cache.path ~= path then
    retire_wallpaper_cache()
    wallpaper_cache.path = path
  end

  local geo = s.geometry
  if not geo or geo.width <= 0 or geo.height <= 0 then return nil end
  local ratio = geo.width / geo.height
  local ratio_key = math.floor(ratio * 10000 + 0.5)

  local cached = wallpaper_cache.crops[ratio_key]
  if cached then
    return cached
  end

  local src = wallpaper_cache.source
  if not src then
    src = gears.surface.load_uncached_silently(path)
    if not src then return nil end
    wallpaper_cache.source = src
    schedule_wallpaper_cleanup()
  end

  local w, h = gears.surface.get_size(src)
  if w <= 0 or h <= 0 then return nil end

  -- If the source aspect ratio already matches the screen, share `src` directly
  -- instead of allocating and painting a duplicate full-resolution surface.
  local crop_w, crop_h = w, h
  local prev_ratio = w / h
  if prev_ratio < ratio then
    crop_h = math.ceil(w * (1 / ratio))
  elseif prev_ratio > ratio then
    crop_w = math.ceil(h * ratio)
  end

  local result
  if crop_w == w and crop_h == h then
    result = src
    wallpaper_cache.used_source = true
  else
    result = gears.surface.crop_surface { surface = src, ratio = ratio }
  end

  wallpaper_cache.crops[ratio_key] = result
  return result
end

local function set_wallpaper(s)
  if not beautiful.wallpaper or not gears.filesystem.file_readable(beautiful.wallpaper) then
    pick_random_wallpaper()
  end
  local surf = wallpaper_surface_for(s)
  local entry = screen_wallpapers[s]
  if entry then
    if entry.surface ~= surf then
      entry.surface = surf
      entry.imagebox:set_image(surf)
    end
    return
  end

  local ib = wibox.widget {
    image     = surf,
    upscale   = true,
    downscale = true,
    widget    = wibox.widget.imagebox,
  }
  screen_wallpapers[s] = {
    surface   = surf,
    imagebox  = ib,
    wallpaper = awful.wallpaper {
      screen = s,
      bg     = beautiful.bg_normal or "#060606",
      widget = {
        ib,
        valign                  = "center",
        halign                  = "center",
        content_fill_horizontal = true,
        content_fill_vertical   = true,
        widget                  = wibox.container.place,
      },
    },
  }
end

pick_random_wallpaper()
screen.connect_signal("request::wallpaper", set_wallpaper)

gears.timer {
  timeout   = 6 * 60 * 60,
  autostart = true,
  callback  = function()
    pick_random_wallpaper()
    for s in screen do
      set_wallpaper(s)
    end
  end,
}

------------------------
-- Desktop decoration --
------------------------

local widgets = require('widgets')

-- Recreate the tags and clients saved by awful.permissions when an output is
-- removed (see the default tag screen removal handler), including the client
-- tag lists.
local function restore_saved_tags(s, saved)
  -- Pass 1: recreate tags and build per-client tag lists
  local client_tags = {}
  for _, td in ipairs(saved) do
    local t = awful.tag.add(td.name, {
      screen = s,
      layout = td.layout,
      master_width_factor = td.master_width_factor,
      master_count = td.master_count,
      gap = td.gap,
      selected = td.selected,
    })
    for _, c in ipairs(td.clients) do
      if c.valid then
        if not client_tags[c] then
          client_tags[c] = {}
        end
        table.insert(client_tags[c], t)
      end
    end
  end
  -- Pass 2: move clients and assign full tag lists
  for c, tags in pairs(client_tags) do
    c:move_to_screen(s)
    c:tags(tags)
  end
end

local function on_desktop_decoration(s)
  -- Restore saved tags if this output was previously removed
  local output_name = s.output and s.output.name
  local restore = output_name and awful.permissions.saved_tags[output_name]
  if restore then
    awful.permissions.saved_tags[output_name] = nil
    restore_saved_tags(s, restore)
  -- Prefer persisted tags (names/order/layout/selection) so renames survive a
  -- reload; fall back to the profile's default tags only when none are stored.
  elseif not persist.restore_tags(s) then
    layouts.default_tags(s)
  end

  -- Create a promptbox for each screen
  s.mypromptbox = awful.widget.prompt()

  -- Create an imagebox widget which will contain an icon indicating which
  -- layout we're using. We need one layoutbox per screen.
  s.mylayoutbox = widgets.layoutbox(s)
  s.mytaglist = widgets.taglist(s, keybindings.modkey)
  s.mytasklist = widgets.tasklist(s)

  s.mywibox = widgets.wibar(s, wibar_options(s))
end

screen.connect_signal("request::desktop_decoration", on_desktop_decoration)

-----------
-- Rules --
-----------

require('rules')

-----------
-- Input --
-----------

awesome._set_keyboard_setting("numlock", true)
awful.input.xkb_layout = "us"
awful.input.tap_to_click = 1
awful.input.keyboard_repeat_delay = 450
if profile.accel_speed then
  awful.input.accel_speed = profile.accel_speed
end

------------------------------------------
-- Idle timeout and display realignment --
------------------------------------------

-- Turn off monitors after 15 minutes of inactivity. somewm suppresses this
-- while awesome.idle_inhibit is true (some_idle_timers_set_inhibit()).
awesome.set_idle_timeout("dpms", 15 * 60, function()
  awesome.dpms_off()
end)

-- One function owns awesome.idle_inhibit; three sources feed it:
--   * manual caffeine lock from the wibar indicator (widgets.caffeine)
--   * any MPRIS player in "Playing" state (Firefox, mpv, fooyin, ...)
--   * any fullscreen client (games, presentations without MPRIS)
-- Firefox's own zwp_idle_inhibitor is not enough on its own: Gecko releases
-- it when it decides the page is in the background (a "locked-background"
-- wake lock is treated as an unlock), which re-arms the dpms timer while the
-- video is still playing.
local media_playing, fullscreen_client = false, false

local function apply_idle_inhibit()
  local manual_inhibit = widgets.caffeine and widgets.caffeine.manual or false
  awesome.idle_inhibit = manual_inhibit or media_playing or fullscreen_client
  if widgets.caffeine then
    widgets.caffeine.set_sources(media_playing, fullscreen_client)
  end
end

awesome.connect_signal("caffeine::changed", apply_idle_inhibit)
awesome.connect_signal("property::idle_inhibited", function()
  if widgets.caffeine then
    widgets.caffeine.update()
  end
end)
apply_idle_inhibit()

-- `--all-players status` prints one bare status line per player, and nothing
-- when no player runs. Driven by D-Bus PropertiesChanged / NameOwnerChanged
-- signals on org.mpris.MediaPlayer2.* so playerctl is only spawned on actual
-- playback or bus-owner transitions (with a 5s timer fallback if dbus is absent).
local mpris_check_running = false
local mpris_check_queued = false

local function check_mpris_playing()
  if mpris_check_running then
    mpris_check_queued = true
    return
  end
  mpris_check_running = true
  awful.spawn.easy_async({ "playerctl", "--all-players", "status" }, function(stdout)
    mpris_check_running = false
    local playing = (stdout or ""):find("Playing", 1, true) ~= nil
    if playing ~= media_playing then
      media_playing = playing
      apply_idle_inhibit()
    end
    if mpris_check_queued then
      mpris_check_queued = false
      check_mpris_playing()
    end
  end)
end

if dbus then
  local MATCH_MPRIS_PROPS = "type='signal',path='/org/mpris/MediaPlayer2',"
    .. "interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',"
    .. "arg0='org.mpris.MediaPlayer2.Player'"
  local MATCH_MPRIS_OWNER = "type='signal',sender='org.freedesktop.DBus',"
    .. "interface='org.freedesktop.DBus',member='NameOwnerChanged',"
    .. "arg0namespace='org.mpris.MediaPlayer2'"

  dbus.add_match("session", MATCH_MPRIS_PROPS)
  dbus.add_match("session", MATCH_MPRIS_OWNER)

  dbus.connect_signal("org.freedesktop.DBus.Properties", function(data, iface, changed)
    if data.path == "/org/mpris/MediaPlayer2"
        and iface == "org.mpris.MediaPlayer2.Player"
        and type(changed) == "table" then
      if changed.PlaybackStatus ~= nil then
        check_mpris_playing()
      end
      awesome.emit_signal("mpris::activity")
    end
  end)

  dbus.connect_signal("org.freedesktop.DBus", function(data, name, old_owner, new_owner)
    if data.member == "NameOwnerChanged"
        and type(name) == "string"
        and name:find("^org%.mpris%.MediaPlayer2%.") then
      if (new_owner == "" and media_playing) or (old_owner == "" and not media_playing) then
        check_mpris_playing()
      end
      awesome.emit_signal("mpris::activity")
    end
  end)

  awesome.connect_signal("exit", function()
    dbus.remove_match("session", MATCH_MPRIS_PROPS)
    dbus.remove_match("session", MATCH_MPRIS_OWNER)
  end)

  check_mpris_playing()
else
  gears.timer {
    timeout   = 5,
    autostart = true,
    call_now  = true,
    callback  = check_mpris_playing,
  }
end

local function update_fullscreen_inhibit()
  local has_fullscreen = false
  for _, c in ipairs(client.get()) do
    if c.valid and c.fullscreen then has_fullscreen = true; break end
  end
  if has_fullscreen ~= fullscreen_client then
    fullscreen_client = has_fullscreen
    apply_idle_inhibit()
  end
end

client.connect_signal("property::fullscreen", update_fullscreen_inhibit)
client.connect_signal("request::unmanage", update_fullscreen_inhibit)
update_fullscreen_inhibit()

-- Realign pinned windows (Minimeters, Rolling Sampler) after DPMS wake.
-- Staggered to handle the race with kanshi re-negotiating output positions.
awesome.connect_signal("dpms::on", function()
  persist.schedule_pinned_realign()
end)

-- Realign when a screen that owns pinned windows changes geometry
-- (mode/position change), e.g. when kanshi re-negotiates outputs.
local function on_screen_geometry(s)
  if persist.screen_has_pinned_windows(s) then
    persist.schedule_pinned_realign()
  end
end

screen.connect_signal("property::geometry", on_screen_geometry)

-------------------------------------------------------
-- External Session Lock (ext-session-lock-v1) Focus --
-------------------------------------------------------

-- Prevent Lua autofocus/permissions from stealing keyboard focus while locked
awful.permissions.add_activate_filter(function()
  if awesome.lock_mechanism ~= nil then
    return false
  end
end)

-- Restore Wayland seat keyboard focus to the ext-session-lock surface
-- after client_focus_refresh() clears deferred focus on lock startup,
-- or if any client unmanages/focuses while locked.
local function restore_ext_lock_focus()
  if awesome.lock_mechanism == "ext" then
    for s in screen do
      if s.valid and s.output then
        s.output.scale = s.output.scale
        break
      end
    end
  end
end

local was_ext_locked = false
awesome.connect_signal("refresh", function()
  local is_ext = (awesome.lock_mechanism == "ext")
  if is_ext and not was_ext_locked then
    was_ext_locked = true
    for _, delay in ipairs({ 0.05, 0.20, 0.50 }) do
      gears.timer.start_new(delay, function()
        restore_ext_lock_focus()
        return false
      end)
    end
  elseif not is_ext and was_ext_locked then
    was_ext_locked = false
  end
end)

client.connect_signal("focus", function()
  if awesome.lock_mechanism == "ext" then
    gears.timer.start_new(0.05, function()
      restore_ext_lock_focus()
      return false
    end)
  end
end)

client.connect_signal("request::unmanage", function()
  if awesome.lock_mechanism == "ext" then
    gears.timer.start_new(0.05, function()
      restore_ext_lock_focus()
      return false
    end)
  end
end)

---------------
-- Autostart --
---------------

if not awesome._restart then
  autorun.run()
end
