-- Notification library
local naughty = require("naughty")
local awful = require("awful")
local wibox = require("wibox")
-- Declarative object management
local ruled = require("ruled")
local functions = require("functions")

local assign_tag = function(matcher, screen_role, tag_name)
  local rule = type(matcher) == "table" and matcher
      or { class = matcher }
  ruled.client.append_rule {
    id         = rule.id or rule.class or rule.name
        or rule.instance or tostring(matcher),
    rule       = rule,
    properties = {
      screen = displays[screen_role].screen,
      tag    = tag_name
    }
  }
end

local minimeters_window = function(meter_name, geometry)
  ruled.client.append_rule {
    rule = {
      class = "app.minimeters.MiniMeters",
      name = meter_name
    },
    -- callback = function(c)
    --   c:geometry(geometry)
    -- end,
    properties = {
      screen   = displays["bottom"].screen,
      tag      = "minimeters",
      urgent   = false,
      floating = true,
      x        = geometry.x,
      y        = geometry.y,
      width    = geometry.width,
      height   = geometry.height,
    }
  }
end

ruled.client.connect_signal("request::rules", function()
  ruled.client.append_rule {
    id         = "global",
    rule       = {},
    properties = {
      focus     = awful.client.focus.filter,
      raise     = true,
      screen    = awful.screen.preferred,
      placement = awful.placement.no_overlap + awful.placement.no_offscreen
    }
  }

  ruled.client.append_rule {
    id         = "floating",
    rule_any   = {
      instance = { "copyq", "pinentry" },
      class    = {
        "Arandr", "Blueman-manager", "Gpick", "Kruler", "Sxiv",
        "Tor Browser", "Wpa_gui", "veromix", "xtightvncviewer"
      },
      name     = {
        "Event Tester", -- xev.
      },
      role     = {
        "AlarmWindow",   -- Thunderbird's calendar.
        "ConfigManager", -- Thunderbird's about:config.
        "pop-up",        -- e.g. Google Chrome's (detached) Developer Tools.
      }
    },
    properties = { floating = true }
  }

  ruled.client.append_rule {
    id         = "titlebars",
    rule_any   = {
      class = { "Wine", "wine" },
    },
    properties = { titlebars_enabled = true }
  }

  assign_tag("Plex", "left", "plex")
  assign_tag("steam", "middle", "steam")
  assign_tag("firefox", "middle", "browser")
  assign_tag("Carla2", "middle", "carla")
  assign_tag("discord", "right", "discord")

  minimeters_window("MiniMeters", {
    x = 3995,
    y = 1687,
    width = 827,
    height = 245
  })
  minimeters_window("Stereometer", {
    x = 4461,
    y = 1440,
    width = 361,
    height = 247
  })
  minimeters_window("Waveform", {
    x = 3992,
    y = 1440,
    width = 467,
    height = 245
  })
  minimeters_window("Spectrogram", {
    x = 4824,
    y = 1443,
    width = 294,
    height = 490
  })

  --functions.restore_windows()
end)

-- Add a titlebar if titlebars_enabled is set to true in the rules.
client.connect_signal("request::titlebars", function(c)
  -- buttons for the titlebar
  local buttons = {
    awful.button({}, 1, function()
      c:activate { context = "titlebar", action = "mouse_move" }
    end),
    awful.button({}, 3, function()
      c:activate { context = "titlebar", action = "mouse_resize" }
    end),
  }

  awful.titlebar(c).widget = {
    { -- Left
      awful.titlebar.widget.iconwidget(c),
      buttons = buttons,
      layout  = wibox.layout.fixed.horizontal
    },
    {   -- Middle
      { -- Title
        halign = "center",
        widget = awful.titlebar.widget.titlewidget(c)
      },
      buttons = buttons,
      layout  = wibox.layout.flex.horizontal
    },
    { -- Right
      awful.titlebar.widget.floatingbutton(c),
      awful.titlebar.widget.maximizedbutton(c),
      awful.titlebar.widget.stickybutton(c),
      awful.titlebar.widget.ontopbutton(c),
      awful.titlebar.widget.closebutton(c),
      layout = wibox.layout.fixed.horizontal()
    },
    layout = wibox.layout.align.horizontal
  }
end)

-------------------
-- Notifications --
-------------------

-- Error handling
naughty.connect_signal("request::display_error", function(message, startup)
  naughty.notification {
    urgency = "critical",
    title   = "Oops, an error happened" .. (startup and " during startup!" or "!"),
    message = message
  }
end)
if awesome.x11_fallback_info then
  -- Defer notification until after startup (naughty needs event loop running)
  gears.timer.delayed_call(function()
    local info = awesome.x11_fallback_info
    local msg = string.format(
      "Your config was skipped because it contains X11-specific code that " ..
      "won't work on Wayland.\n\n" ..
      "File: %s:%d\n" ..
      "Pattern: %s\n" ..
      "Code: %s\n\n" ..
      "Suggestion: %s\n\n" ..
      "Edit your rc.lua to remove X11 dependencies, then restart somewm.",
      info.config_path or "unknown",
      info.line_number or 0,
      info.pattern or "unknown",
      info.line_content or "",
      info.suggestion or "See somewm migration guide"
    )
    naughty.notification {
      urgency = "critical",
      title   = "Config contains X11 patterns - using fallback",
      message = msg,
      timeout = 0 -- Don't auto-dismiss
    }
  end)
end

-- Other notification rules
ruled.notification.connect_signal('request::rules', function()
  ruled.notification.append_rule {
    rule       = {},
    properties = {
      screen           = awful.screen.preferred,
      implicit_timeout = 10,
    }
  }
end)

naughty.connect_signal("request::display", function(n)
  naughty.layout.box { notification = n }
end)

client.connect_signal("manage", function(c)
  naughty.notify {
    title = "New window",
    text = string.format(
      "class: %s\ninstance: %s\nname: %s\ntype: %s",
      c.class or "nil",
      c.instance or "nil",
      c.name or "nil",
      c.type or "nil"
    ),
  }
end)

awesome.connect_signal("exit", function(reason_restart)
  functions.save_open_windows()
end)
