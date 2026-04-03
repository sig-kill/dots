local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")

local widgets = {}

widgets.taglist = function(s)
  return awful.widget.taglist {
    screen  = s,
    filter  = awful.widget.taglist.filter.all,
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

-------------
-- Widgets --
-------------

local keyboard_layout = awful.widget.keyboardlayout()
local separator = wibox.widget.textbox(" | ")

local music_player_widget = wibox.widget.textbox()
awful.spawn.with_line_callback(
  "playerctl --follow metadata --format '<{{status}}> {{artist}} - {{title}}'",
  {
    stdout = function(line)
      music_player_widget:set_text(line:gsub('<Playing>', ''):gsub('<.+>', ''))
    end
  }
)
music_player_widget:buttons(gears.table.join(
  awful.button({}, 1, function()
    awful.spawn.with_shell("playerctl --player=fooyin,%any play-pause || pgrep -x fooyin > /dev/null || fooyin")
  end)))

local time_widget = wibox.widget.textclock("%a, %b %d %I:%M:%S", 1)

widgets.wibar = function(s)
  return awful.wibar {
    position = "bottom",
    screen   = s,
    widget   = {
      layout = wibox.layout.align.horizontal,
      { -- Left widgets
        layout = wibox.layout.fixed.horizontal,
        s.mytaglist,
        s.mypromptbox,
        separator,
      },
      s.mytasklist, -- Middle widget
      {             -- Right widgets
        layout = wibox.layout.fixed.horizontal,
        separator,
        keyboard_layout,
        wibox.widget.systray(),
        separator,
        music_player_widget,
        separator,
        time_widget,
        separator,
        s.mylayoutbox,
      },
    }
  }
end

return widgets
