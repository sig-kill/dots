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

local function set_wallpaper(s)
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
          image     = cropped or beautiful.wallpaper,
          upscale   = true,
          downscale = true,
          widget    = wibox.widget.imagebox,
        },
        valign = "center",
        halign = "center",
        tiled  = false,
        widget = wibox.container.tile,
      }
    }
  else
    awful.wallpaper { screen = s, bg = beautiful.bg_normal or "#060606" }
  end
end

screen.connect_signal("request::wallpaper", set_wallpaper)

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

---------------
-- Autostart --
---------------

autorun.run()
