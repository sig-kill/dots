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

autorun.run_once('kanshi')

local gears = require("gears")
-- Widget and layout library
local wibox = require("wibox")
-- Theme handling library
local beautiful = require("beautiful")
local menubar = require("menubar")
local hotkeys_popup = require("awful.hotkeys_popup")
-- Enable hotkeys help widget for VIM and other apps
-- when client with a matching name is opened:
require("awful.hotkeys_popup.keys")

-----------
-- Theme --
-----------

beautiful.init(os.getenv("HOME") .. "/.config/somewm/theme.lua")
-- Initialize lockscreen (must be after beautiful.init)
require("lockscreen").init()
awesome.log_level = "info"

------------------------------
-- Profile and shared state --
------------------------------

local profile = require("profile")
terminal = profile.terminal
editor = os.getenv("EDITOR") or "vim"
editor_cmd = terminal .. " -e " .. editor

-- Keybindings own the modifier; required here because the taglist buttons
-- (widgets.taglist) are built with it.
local keybindings = require('keybindings')

-- Display role per output model, consumed by persist.lua, rules.lua and
-- layouts.lua through the global `displays`.
displays = {}
local display_map = {
  ['LEN L27q-20'] = 'left',
  ['24GL600F'] = 'right',
  ['HP X27q'] = 'middle',
  ['Wisecoco'] = 'bottom',
  -- Work
  ['P2718EC'] = 'left',
  ['LF32TU87'] = 'middle',
}

local function update_displays(o)
  local role = display_map[o.model]
  if role then
    displays[role] = o
  end
end

for o in output do
  update_displays(o)
end

output.connect_signal("added", function(o)
  update_displays(o)
end)

------------------
-- Wibar layout --
------------------

-- Options come from the profile (profile.wibar_config): per-display wibar
-- layout keyed by display role. Roles or keys left out — and profiles without
-- the field — get the defaults: bar at the bottom with every widget shown.
local function wibar_options(s)
  local model = s.output and s.output.model
  local role = model and display_map[model]
  local config = profile.wibar_config or {}
  return role and config[role] or {}
end

----------
-- Menu --
----------

myawesomemenu = {
  { "hotkeys", function()
    hotkeys_popup.show_help(nil, awful.screen.focused())
  end },
  { "manual",      terminal .. " -e man awesome" },
  { "edit config", editor_cmd .. " " .. awesome.conffile },
  { "restart",     awesome.restart },
  { "quit",        function() awesome.quit() end },
}

mymainmenu = awful.menu({
  items = {
    { "awesome",       myawesomemenu, beautiful.awesome_icon },
    { "open terminal", terminal }
  }
})

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

local function set_wallpaper(s)
  if not beautiful.wallpaper or not gears.filesystem.file_readable(beautiful.wallpaper) then
    pick_random_wallpaper()
  end
  if beautiful.wallpaper and gears.filesystem.file_readable(beautiful.wallpaper) then
    local surf = gears.surface.load_silently(beautiful.wallpaper)
    local cropped = surf and gears.surface.crop_surface {
      surface = surf,
      ratio   = s.geometry.width / s.geometry.height,
    }
    awful.wallpaper {
      screen = s,
      widget = {
        {
          image                 = cropped or beautiful.wallpaper,
          upscale               = true,
          downscale             = true,
          horizontal_fit_policy = cropped and "fit" or "auto",
          vertical_fit_policy   = cropped and "fit" or "auto",
          widget                = wibox.widget.imagebox,
        },
        valign                  = "center",
        halign                  = "center",
        tiled                   = false,
        content_fill_horizontal = true,
        content_fill_vertical   = true,
        widget                  = wibox.container.tile,
      }
    }
  else
    awful.wallpaper { screen = s, bg = beautiful.bg_normal or "#060606" }
  end
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
-- Set the layout explicitly. somewm's xkb_get_group_names() falls back to
-- human-readable keymap names ("pc+English (US)") when no RMLVO layout is
-- configured, and awful.widget.keyboardlayout cannot parse those, so the
-- wibar entry stays blank. With the layout set it returns "pc+us".
awful.input.xkb_layout = "us"
awful.input.tap_to_click = 1
awful.input.keyboard_repeat_delay = 450
if profile.accel_speed then
  awful.input.accel_speed = profile.accel_speed
end

------------------------------------------
-- Idle timeout and display realignment --
------------------------------------------

-- Turn off monitors after 15 minutes of inactivity.
awesome.set_idle_timeout("dpms", 15 * 60, function()
  awesome.dpms_off()
end)

client.connect_signal("property::fullscreen", function()
    local dominated = false
    for _, c in ipairs(client.get()) do
        if c.fullscreen then dominated = true; break end
    end
    awesome.idle_inhibit = dominated
end)

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

autorun.run()
