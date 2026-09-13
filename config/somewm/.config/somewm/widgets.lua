local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")

local widgets = {}

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
local keyboard_layout = awful.widget.keyboardlayout()
local separator = wibox.widget.textbox(" | ")
local music_player_widget = wibox.widget.textbox()
local time_widget = wibox.widget.textclock("%a, %b %d %I:%M:%S", 1)

-- The player state is polled into a runtime file rather than read from a
-- `playerctl --follow` pipe: reading a pipe needs
-- awful.spawn.with_line_callback, whose lgi (Gio) callback outlives a config
-- reload and crashes the compositor when the abandoned callback fires.
-- Spawning a process and reading a plain file are both reload-safe.
local MPRIS_FILE = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/somewm-mpris"
local mpris_text

local function poll_player_state()
  local f = io.open(MPRIS_FILE, "r")
  if f then
    local line = f:read("*l")
    f:close()
    if line and line ~= mpris_text then
      mpris_text = line
      music_player_widget:set_text(line:gsub('<Playing>', ''):gsub('<.+>', ''))
    end
  end
  awful.spawn.with_shell(
    "playerctl -p fooyin metadata "
    .. "--format '<{{status}}> {{artist}} - {{title}}' "
    .. "> " .. MPRIS_FILE .. ".tmp 2>/dev/null && "
    .. "mv " .. MPRIS_FILE .. ".tmp " .. MPRIS_FILE)
end

gears.timer {
  timeout = 1,
  autostart = true,
  callback = poll_player_state,
}

music_player_widget:buttons(gears.table.join(
  awful.button({}, 1, function()
    awful.spawn.with_shell("fooyin -t")
  end)))

------------
-- Wibar --
------------

-- Right-hand side of the bar. Separators travel with the widget they precede,
-- so a widget hidden by the per-monitor config (profile.wibar_config) leaves no
-- dangling separator.
local function build_right_widgets(opts, s)
  local right_widgets = {
    layout = wibox.layout.fixed.horizontal,
    separator,
    keyboard_layout,
  }

  local function add_optional_widget(widget)
    if widget then
      right_widgets[#right_widgets + 1] = separator
      right_widgets[#right_widgets + 1] = widget
    end
  end

  add_optional_widget(opts.tray ~= false and wibox.widget.systray())
  add_optional_widget(opts.media ~= false and music_player_widget)
  add_optional_widget(opts.clock ~= false and time_widget)
  right_widgets[#right_widgets + 1] = separator
  right_widgets[#right_widgets + 1] = s.mylayoutbox

  return right_widgets
end

widgets.wibar = function(s, opts)
  opts = opts or {}

  return awful.wibar {
    position = opts.position or "bottom",
    screen   = s,
    widget   = {
      layout = wibox.layout.align.horizontal,
      { -- Left widgets
        layout = wibox.layout.fixed.horizontal,
        s.mytaglist,
        s.mypromptbox,
        separator,
      },
      s.mytasklist,               -- Middle widget
      build_right_widgets(opts, s), -- Right widgets
    }
  }
end

return widgets
