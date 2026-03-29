local awful = require("awful")
local lain = require("lain")
local beautiful = require("beautiful")
local gears = require("gears")
local wibox = require("wibox")
local functions = require("functions")

local function set_wallpaper(s)
  -- Wallpaper
  if beautiful.wallpaper then
    local wallpaper = beautiful.wallpaper
    -- If wallpaper is a function, call it with the screen
    if type(wallpaper) == "function" then wallpaper = wallpaper(s) end
    gears.wallpaper.maximized(wallpaper, s, true)
  end
end

local separator = wibox.widget.textbox(" | ")

local volume = lain.widget.pulse {
  settings = function()
    local vlevel = volume_now.left .. "%"
    if volume_now.muted == "yes" then
      vlevel = vlevel .. " M"
    end
    widget:set_markup(lain.util.markup("#7493d2", vlevel))
  end
}
volume.widget:buttons(awful.util.table.join(
  awful.button({}, 1, function(t) awful.spawn("pavucontrol") end),
  awful.button({}, 4, function(t)
    awful.spawn("pactl set-sink-volume @DEFAULT_SINK@ +5%")
    volume.update()
  end),
  awful.button({}, 5, function(t)
    awful.spawn("pactl set-sink-volume @DEFAULT_SINK@ -5%")
    volume.update()
  end)
))

local music_player_widget = wibox.widget.textbox()
awful.spawn.with_line_callback(
  "playerctl --follow metadata --format '<{{status}}> {{artist}} - {{title}}'",
  {
    stdout = function(line)
      music_player_widget:set_text(line:gsub('<Playing>', ''):gsub('<.+>', ''))
    end
  }
)
music_player_widget:buttons(gears.table.join(
  awful.button({}, 1, function(t) awful.spawn("playerctl play-pause") end)))

local time_widget = wibox.widget.textclock("%a, %b %d %I:%M:%S", 1)
local calendar_widget = require("awesome-wm-widgets.calendar-widget.calendar")
local calendar = calendar_widget({
  theme = 'nord',
  placement = 'bottom_right',
  start_sunday = true,
  previous_month_button = 4,
  next_month_button = 5,
})
time_widget:connect_signal("mouse::enter", function() calendar.toggle() end)

local taglist_buttons = gears.table.join(
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
  awful.button({}, 4, function(t) awful.tag.viewnext(t.screen) end),
  awful.button({}, 5, function(t) awful.tag.viewprev(t.screen) end)
)
local tasklist_buttons = gears.table.join(
  awful.button({}, 1, function(c)
    if c == client.focus then
      c.minimized = true
    else
      c:emit_signal(
        "request::activate",
        "tasklist",
        { raise = true }
      )
    end
  end),
  awful.button({}, 3, function() awful.menu.client_list({ theme = { width = 250 } }) end),
  awful.button({}, 4, function() awful.client.focus.byidx(1) end),
  awful.button({}, 5, function() awful.client.focus.byidx(-1) end))

-- Re-set wallpaper when a screen's geometry changes (e.g. different resolution)
screen.connect_signal("property::geometry", set_wallpaper)

awful.screen.connect_for_each_screen(function(s)
  require('bling.module.wallpaper').setup {
    screen = s,
    set_function = require('bling.module.wallpaper').setters.random,
    wallpaper = { os.getenv('HOME') .. '/Pictures/wallpaper' },
    change_timer = 60 * 60,
    position = 'fit'
  }
  local default_layout = awful.layout.layouts[1]
  -- Vertical screens get tiletop layout
  if s.geometry.height > s.geometry.width then
    default_layout = awful.layout.layouts[2]
  end
  awful.tag.new({ "1", "2", "3", "4", "5", "6", "7", "8", "9" }, s, default_layout)
  -- Check and restore previous sessions
  functions.restore_session(s)

  -- Create a promptbox for each screen
  s.mypromptbox = awful.widget.prompt()
  -- Create an imagebox widget which will contain an icon indicating which layout we're using.
  -- We need one layoutbox per screen.
  s.mylayoutbox = awful.widget.layoutbox(s)
  s.mylayoutbox:buttons(gears.table.join(
    awful.button({}, 1, function() awful.layout.inc(1) end),
    awful.button({}, 3, function() awful.layout.inc(-1) end),
    awful.button({}, 4, function() awful.layout.inc(1) end),
    awful.button({}, 5, function() awful.layout.inc(-1) end)))
  -- Create a taglist widget
  s.mytaglist = awful.widget.taglist {
    screen = s,
    filter = awful.widget.taglist.filter.noempty,
    buttons = taglist_buttons
  }

  -- Create a tasklist widget
  s.mytasklist = awful.widget.tasklist {
    screen = s,
    filter = awful.widget.tasklist.filter.currenttags,
    buttons = tasklist_buttons
  }

  -- Create the wibox
  s.mywibox = awful.wibar({ position = "bottom", screen = s })

  -- Add widgets to the wibox
  s.mywibox:setup {
    layout = wibox.layout.align.horizontal,
    { -- Left widgets
      layout = wibox.layout.fixed.horizontal,
      mylauncher,
      s.mytaglist,
      s.mypromptbox,
      separator,
    },
    s.mytasklist, -- Middle widget
    {             -- Right widgets
      layout = wibox.layout.fixed.horizontal,
      mykeyboardlayout,
      wibox.widget.systray(),
      separator,
      volume,
      separator,
      music_player_widget,
      separator,
      time_widget,
      s.mylayoutbox
    }
  }
end)
