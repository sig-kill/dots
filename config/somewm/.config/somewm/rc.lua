-- awesome_mode: api-level=4:screen=on
-- If LuaRocks is installed, make sure that packages installed through it are
-- found (e.g. lgi). If LuaRocks is not installed, do nothing.
pcall(require, "luarocks.loader")

-- Standard awesome library
local awful = require("awful")
require("awful.autofocus")

awful.spawn.single_instance('kanshi')

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
local functions = require("functions")

beautiful.init(os.getenv("HOME") .. "/.config/somewm/theme.lua")
-- Initialize lockscreen (must be after beautiful.init)
require("lockscreen").init()
awesome.log_level = "info"

terminal = "ghostty"
editor = os.getenv("EDITOR") or "vim"
editor_cmd = terminal .. " -e " .. editor
modkey = "Mod4"

displays = {}
local display_map = {
  ['LEN L27q-20'] = 'left',
  ['24GL600F'] = 'right',
  ['HP X27q'] = 'middle',
  ['Wisecoco'] = 'bottom',
}
for o in output do
  local role = display_map[o.model]
  if role then
    displays[role] = o
  end
end

-- Menu
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

-- Set the teminal for applications that require it.
menubar.utils.terminal = terminal

-------------
-- Layouts --
-------------
local layouts = require('layouts')
tag.connect_signal("request::default_layouts", function()
  awful.layout.append_default_layouts(layouts.list)
end)

-- Wallpaper
screen.connect_signal("request::wallpaper", function(s)
  gears.wallpaper.centered(beautiful.wallpaper, s)
end)

local widgets = require('widgets')

screen.connect_signal("request::desktop_decoration", function(s)
  -- Restore saved tags if this output was previously removed
  local output_name = s.output and s.output.name
  local restore = output_name and awful.permissions.saved_tags[output_name]
  if restore then
    awful.permissions.saved_tags[output_name] = nil
    -- Pass 1: recreate tags and build per-client tag lists
    local client_tags = {}
    for _, td in ipairs(restore) do
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
  else
    layouts.default_tags(s)
  end

  -- Create a promptbox for each screen
  s.mypromptbox = awful.widget.prompt()

  -- Create an imagebox widget which will contain an icon indicating which
  -- layout we're using. We need one layoutbox per screen.
  s.mylayoutbox = widgets.layoutbox(s)
  s.mytaglist = widgets.taglist(s)
  s.mytasklist = widgets.tasklist(s)

  s.mywibox = widgets.wibar(s)
end)

require('keybindings')
require('rules')

awesome._set_keyboard_setting("numlock", true)
awful.input.tap_to_click = 1
awful.input.keyboard_repeat_delay = 450
--awful.input.xkb_options = "caps:super"

require('autorun')
