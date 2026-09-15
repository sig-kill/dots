local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")

local widgets = {}

-- Load all widgets from this directory.
do
  local dir = gears.filesystem.get_configuration_dir() .. "widgets"
  if gears.filesystem.dir_readable(dir) then
    local Gio = require("lgi").Gio
    local enumerator = Gio.File.new_for_path(dir)
      :enumerate_children("standard::name", Gio.FileQueryInfoFlags.NONE)
    for info in function() return enumerator:next_file() end do
      -- `[^.]` drops dotfiles, and the capture is the module stem.
      local stem = info:get_name():match("^([^.].*)%.lua$")
      if stem and stem ~= "init" then
        widgets[stem] = require("widgets." .. stem)
      end
    end
    enumerator:close()
  end
end

-----------------------------
-- Client widget builders --
-----------------------------

widgets.taglist = function(s, modkey)
  assert(modkey, "widgets.taglist needs the keybindings modifier")
  return awful.widget.taglist {
    screen  = s,
    filter  = awful.widget.taglist.filter.noempty,
    buttons = {
      awful.button({}, 1, function(t) t:view_only() end),
      awful.button({ modkey }, 1, function(t)
        if client.focus then
          client.focus:move_to_tag(t)
        end
      end),
      awful.button({}, 3, awful.tag.viewtoggle),
      awful.button({ modkey }, 3, function(t)
        if client.focus then
          client.focus:toggle_tag(t)
        end
      end),
      awful.button({}, 4, function(t) awful.tag.viewprev(t.screen) end),
      awful.button({}, 5, function(t) awful.tag.viewnext(t.screen) end),
    }
  }
end

widgets.tasklist = function(s)
  return awful.widget.tasklist {
    screen  = s,
    filter  = awful.widget.tasklist.filter.currenttags,
    buttons = {
      awful.button({}, 1, function(c)
        c:activate { context = "tasklist", action = "toggle_minimization" }
      end),
      awful.button({}, 3, function()
        awful.menu.client_list { theme = { width = 250 } }
      end),
      awful.button({}, 4, function() awful.client.focus.byidx(-1) end),
      awful.button({}, 5, function() awful.client.focus.byidx(1) end),
    }
  }
end

-- Create an imagebox widget which will contain an icon indicating which
-- layout we're using. We need one layoutbox per screen.
widgets.layoutbox = function(s)
  return awful.widget.layoutbox {
    screen  = s,
    buttons = {
      awful.button({}, 1, function() awful.layout.inc(1) end),
      awful.button({}, 3, function() awful.layout.inc(-1) end),
      awful.button({}, 4, function() awful.layout.inc(-1) end),
      awful.button({}, 5, function() awful.layout.inc(1) end),
    }
  }
end

------------------
-- Shared parts --
------------------

-- One instance per config load, shared by every screen's wibar (rc.lua builds
-- one wibar per output).
local separator = wibox.widget.textbox(" | ")
local time_widget = wibox.widget.textclock("%a, %b %d %I:%M:%S", 1)

------------
-- Wibar --
------------

-- Join widgets into a horizontal row, putting `separator` between the widgets
-- that are present. A widget omitted from the per-monitor config
-- (profile.wibar_config) takes its separator with it, and the row never leads
-- or trails with one.
local function horizontal_row(child_list)
  local row = { layout = wibox.layout.fixed.horizontal }
  for _, widget in ipairs(child_list) do
    if widget then
      if #row > 0 then
        row[#row + 1] = separator
      end
      row[#row + 1] = widget
    end
  end
  return row
end

widgets.wibar = function(s, opts)
  opts = opts or {}

  return awful.wibar {
    position = opts.position or "bottom",
    screen   = s,
    widget   = {
      layout = wibox.layout.align.horizontal,
      -- Left widgets
      horizontal_row { s.mytaglist, s.mypromptbox },
      s.mytasklist, -- Middle widget
      -- Right widgets
      horizontal_row {
        opts.tray ~= false and wibox.widget.systray(),
        opts.media ~= false and widgets.music.widget,
        opts.clock ~= false and time_widget,
        s.mylayoutbox,
      },
    }
  }
end

return widgets
