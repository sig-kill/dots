-- Notification library
local naughty = require("naughty")
local gears = require("gears")
local awful = require("awful")
local wibox = require("wibox")
-- Declarative object management
local ruled = require("ruled")

local persist = require("persist")
local profile = require("profile")
local tags = require("tags")

--------------------
-- Rule helpers --
--------------------

-- Route windows matching `matcher` (a class string, or a rule table) to
-- `tag_name` on the display whose role is `screen_role`. The rule id falls back
-- to the matcher itself, so every helper call yields a distinctly named rule.
local function assign_tag(matcher, screen_role, tag_name)
  local rule = type(matcher) == "table" and matcher
      or { class = matcher }
  local target_screen = displays[screen_role] and displays[screen_role].screen or nil
  ruled.client.append_rule {
    id         = rule.id or rule.class or rule.name
        or rule.instance or tostring(matcher),
    rule       = rule,
    properties = {
      screen = target_screen,
      tag    = function(c) return tags.find_tag(c.screen, tag_name) end,
    }
  }
end

-- Place one profile-pinned window: fixed geometry on the spec's display role
-- and tag (profile.pinned_windows).
local function pin_window(spec)
  ruled.client.append_rule {
    rule = spec.rule,
    properties = {
      screen   = displays[spec.role] and displays[spec.role].screen or nil,
      tag      = function(c) return tags.find_tag(c.screen, spec.tag) end,
      urgent   = false,
      floating = true,
      x        = spec.geometry.x,
      y        = spec.geometry.y,
      width    = spec.geometry.width,
      height   = spec.geometry.height,
    }
  }
end

-------------------
-- Client rules --
-------------------

local function add_global_rule()
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
end

local function add_floating_rule()
  ruled.client.append_rule {
    id         = "floating",
    rule_any   = {
      instance = { "copyq", "pinentry" },
      class    = {
        "Arandr", "Blueman-manager", "Gpick", "Kruler", "Sxiv",
        "Tor Browser", "Wpa_gui", "veromix", "xtightvncviewer",
        "org.kde.dolphin", "faugus-launcher", "xdg-desktop-portal-gtk"
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
end

local function add_titlebar_rule()
  ruled.client.append_rule {
    id         = "titlebars",
    rule_any   = {
      class = { "Wine", "wine" },
    },
    properties = { titlebars_enabled = true }
  }
end

-- Application -> display role + tag. Rules are matched in append order, and the
-- matchers are Lua patterns, so "firefox" also matches
-- "firefox-developer-edition".
local function add_class_tag_rules()
  assign_tag("Plex", "left", "plex")
  assign_tag("steam", "middle", "steam")
  assign_tag("firefox", "middle", "browser")
  assign_tag("carla", "middle", "carla")
  assign_tag("raysession", "middle", "carla")
  assign_tag("vesktop", "right", "discord")
  assign_tag("fooyin", "left", "music")
end

-- Pinned windows: driven by profile.pinned_windows (single source of truth).
local function add_pinned_window_rules()
  for _, spec in ipairs(profile.pinned_windows or {}) do
    pin_window(spec)
  end
end

ruled.client.connect_signal("request::rules", function()
  add_global_rule()
  add_floating_rule()
  add_titlebar_rule()
  add_class_tag_rules()
  add_pinned_window_rules()

  -- Restore per-window placement saved on the previous exit/reload. Appended
  -- after the class rules so it overrides them for windows it matches.
  persist.restore_windows()
end)

-----------------
-- Titlebars --
-----------------

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

local function show_startup_error(message, startup)
  naughty.notification {
    urgency = "critical",
    title   = "Oops, an error happened" .. (startup and " during startup!" or "!"),
    message = message
  }
end

-- Error handling
naughty.connect_signal("request::display_error", show_startup_error)

local function build_x11_fallback_message(info)
  return string.format(
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
end

if awesome.x11_fallback_info then
  -- Defer notification until after startup (naughty needs event loop running)
  gears.timer.delayed_call(function()
    naughty.notification {
      urgency = "critical",
      title   = "Config contains X11 patterns - using fallback",
      message = build_x11_fallback_message(awesome.x11_fallback_info),
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

awesome.connect_signal("exit", function(_reason)
  persist.save_open_windows()
end)
