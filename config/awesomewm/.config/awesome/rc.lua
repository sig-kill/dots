-- If LuaRocks is installed, make sure that packages installed through it are
-- found (e.g. lgi). If LuaRocks is not installed, do nothing.
pcall(require, "luarocks.loader")

-- Standard awesome library
local gears = require("gears")
local awful = require("awful")
require("awful.autofocus")
-- Theme handling library
local beautiful = require("beautiful")
-- Notification library
local naughty = require("naughty")
local menubar = require("menubar")
-- Load Debian menu entries
local debian = require("debian.menu")
local has_fdo, freedesktop = pcall(require, "freedesktop")
local machi = require("layout-machi")
require("layouts")

-- Check if awesome encountered an error during startup and fell back to
-- another config (This code will only ever execute for the fallback config)
if awesome.startup_errors then
  naughty.notify({
    preset = naughty.config.presets.critical,
    title = "Oops, there were errors during startup!",
    text = awesome.startup_errors
  })
end

-- Handle runtime errors after startup
do
  local in_error = false
  awesome.connect_signal("debug::error", function(err)
    -- Make sure we don't go into an endless error loop
    if in_error then return end
    in_error = true

    naughty.notify({
      preset = naughty.config.presets.critical,
      title = "Oops, an error happened!",
      text = tostring(err)
    })
    in_error = false
  end)
end

-- {{{ Variable definitions
-- Themes define colours, icons, font and wallpapers.
local theme = 'blackburn'
beautiful.init(gears.filesystem.get_dir('config')
  .. string.format('/awesome-copycats/themes/%s/theme.lua', theme))
local dpi                       = require('beautiful.xresources').apply_dpi
beautiful.border_width          = dpi(1)
beautiful.font                  = "Hack Nerd Font 10"
beautiful.layout_machi          = machi.get_icon()
beautiful.layout_centerwork     = gears.filesystem.get_dir('config') .. '/bling/icons/layouts/centered.png'
beautiful.border_focus          = "#93f69F"
beautiful.tasklist_disable_icon = true
beautiful.useless_gap           = 5
awful.screen.set_auto_dpi_enabled(true)

-- This is used later as the default terminal and editor to run.
terminal = os.getenv('HOME') .. "/.cargo/bin/alacritty"
editor = os.getenv("EDITOR") or "vim"
editor_cmd = terminal .. " -e " .. editor
persist_tags_filename = gears.filesystem.get_dir('cache') .. "/.awesome-tags"

-- Super
modkey = "Mod4"


-- {{{ Menu
-- Create a launcher widget and a main menu
myawesomemenu = {
  {
    "hotkeys",
    function() hotkeys_popup.show_help(nil, awful.screen.focused()) end
  }, { "manual", terminal .. " -e man awesome" },
  { "edit config", editor_cmd .. " " .. awesome.conffile },
  { "restart",     awesome.restart }, { "quit", function() awesome.quit() end }
}

local menu_awesome = { "awesome", myawesomemenu, beautiful.awesome_icon }
local menu_terminal = { "open terminal", terminal }

if has_fdo then
  mymainmenu = freedesktop.menu.build({
    before = { menu_awesome },
    after = { menu_terminal }
  })
else
  mymainmenu = awful.menu({
    items = {
      menu_awesome, { "Debian", debian.menu.Debian_menu.Debian },
      menu_terminal
    }
  })
end

mylauncher = awful.widget.launcher({
  image = beautiful.awesome_icon,
  menu = mymainmenu
})

-- Menubar configuration
menubar.utils.terminal = terminal -- Set the terminal for applications that require it
-- }}}

-- Keyboard map indicator and switcher
mykeyboardlayout = awful.widget.keyboardlayout()

-- Create a wibox for each screen and add it
local taglist_buttons = gears.table.join(
  awful.button({}, 1, function(t) t:view_only() end),
  awful.button({ modkey }, 1, function(t) if client.focus then client.focus:move_to_tag(t) end end),
  awful.button({}, 3, awful.tag.viewtoggle),
  awful.button({ modkey }, 3, function(t) if client.focus then client.focus:toggle_tag(t) end end),
  awful.button({}, 4, function(t) awful.tag.viewnext(t.screen) end),
  awful.button({}, 5, function(t) awful.tag.viewprev(t.screen) end))

local tasklist_buttons = gears.table.join(
  awful.button({}, 1, function(c)
    if c == client.focus then
      c.minimized = true
    else
      c:emit_signal("request::activate", "tasklist", { raise = true })
    end
  end),
  awful.button({}, 3, function() awful.menu.client_list({ theme = { width = 250 } }) end),
  awful.button({}, 4, function() awful.client.focus.byidx(1) end),
  awful.button({}, 5, function() awful.client.focus.byidx(-1) end))

require("widgets")

naughty.config.presets.spotify = {
  -- if you want to disable Spotify notifications completely, return false
  callback  = function(args)
    return true
  end,

  -- Adjust the size of the notification
  height    = 100,
  width     = 400,
  -- Guessing the value, find a way to fit it to the proper size later
  icon_size = 90
}
table.insert(naughty.dbus.config.mapping, { { appname = "Spotify" }, naughty.config.presets.spotify })

require("keybindings")
require("rules")
require("signals")
local function run(command, pidof)
  local findme = command
  local firstspace = command:find(' ')
  if firstspace then
    findme = command:sub(0, firstspace - 1)
  end
  awful.spawn.easy_async_with_shell(string.format('pgrep -u $USER -x %s > /dev/null || (%s)', pidof or findme, command))
end

run "setxkbmap -option caps:super"
run "~/.screenlayout/layout.sh"
run "picom"
