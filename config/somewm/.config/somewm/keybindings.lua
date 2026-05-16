local gears = require("gears")
local awful = require("awful")
local hotkeys_popup = require("awful.hotkeys_popup")
-- Enable hotkeys help widget for VIM and other apps
-- when client with a matching name is opened:
require("awful.hotkeys_popup.keys")
--local lain = require("lain")
--local machi = require("layout-machi")

--------------------
-- Mouse bindings --
--------------------

-- 1, 2, 3, 4, 5: Left, Middle, Right, Scroll up, Scroll down
--awful.mouse.append_global_mousebindings({
--  awful.button({}, 3, function() mymainmenu:toggle() end),
--  awful.button({}, 4, awful.tag.viewnext),
--  awful.button({}, 5, awful.tag.viewprev),
--})
client.connect_signal("request::default_mousebindings", function()
  awful.mouse.append_client_mousebindings({
    -- Left click to focus
    awful.button({}, 1, function(c)
      c:activate({ context = "mouse_click" })
    end),

    -- Mod4 + Left click to move
    awful.button({ modkey }, 1, function(c)
      c:activate({ context = "mouse_click", action = "mouse_move" })
    end),

    -- Mod4 + Right click to resize
    awful.button({ modkey }, 3, function(c)
      c:activate({ context = "mouse_click", action = "mouse_resize" })
    end),
  })
end)

local ruled = require("ruled")

-- Sloppy focus (application focus follows mouse)
client.connect_signal("mouse::enter", function(c)
  local class = c.class or ""
  local instance = c.instance or ""

  -- Exclude all Steam windows (case-insensitive)
  -- if class:lower():find("^steam") or instance:lower():find("^steam") then
  --   return
  -- end

  local excluded = {
    -- { name = "", class = "" },
  }
  for _, rule in ipairs(excluded) do
    if ruled.client.match(c, rule) then return end
  end

  c:activate { context = "mouse_enter", raise = false }
end)

-----------------------
-- Keyboard bindings --
-----------------------

local function make_keys(keys)
  local result = {}
  for _, group in ipairs(keys) do
    local group_name = group[1]
    for i = 2, #group do
      local def = group[i]
      table.insert(result, awful.key(
        def[1],
        def[2],
        def[4], { description = def[3], group = group_name }
      ))
    end
  end
  return result
end

local globalkeys = {
  -- { mod, key, description, callback }
  { "awesome",
    { { modkey },          "/",     "show help",     hotkeys_popup.show_help },
    { { modkey, "Shift" }, "/",     "debug",         require('functions').save_open_windows },
    { { modkey, "Shift" }, "r",     "reload config", awesome.restart },
    { { modkey, "Shift" }, "q",     "quit",          awesome.quit },
    { { modkey },          "Space", "next layout",   function() awful.layout.inc(1) end },
    { { modkey, "Shift" }, "Space", "prev layout",   function() awful.layout.inc(-1) end },
    { { modkey },          "w",     "lock screen",   function() awful.spawn.single_instance('hyprlock') end },
    { { "Control", "Shift" }, "x", "screenshot",
      function() awful.spawn.with_shell('grim -g "$(slurp)" - | swappy -f -') end },
  },
  { "launcher",
    { { modkey },          "Return", "open terminal", function() awful.spawn(terminal) end },
    { { modkey, "Shift" }, "Return", "open app",      function() awful.spawn('rofi -show drun') end },
    { { modkey, "Control" }, "Return", "open app", function()
      awful.screen.focused().mypromptbox:run()
    end },
    { { modkey }, "x", "execute lua",
      function()
        awful.prompt.run {
          prompt = "Run Lua code: ",
          textbox = awful.screen.focused().mypromptbox.widget,
          exe_callback = function(input)
            local naughty = require('naughty')
            if not input or #input == 0 then
              naughty.notify { text = "Empty input" }
            else
              naughty.notify({ text = gears.debug.dump_return(awful.util.eval(input)) })
            end
          end,
          history_path = awful.util.get_cache_dir() .. "/history_eval"
        }
      end },
  },
  { "media",
    -- g502 side button (mapped to Ctrl+Alt+KP_Divide, which results in XF86Ungrab)
    { { "Control", "Mod1" }, "XF86Ungrab", "[mouse] play/pause", function()
      awful.spawn.with_shell("playerctl --player=fooyin,%any play-pause || pgrep -x fooyin > /dev/null || fooyin")
    end },
    { {}, "XF86AudioPlay", "play/pause", function()
      awful.spawn.with_shell("playerctl --player=fooyin,%any play-pause || pgrep -x fooyin > /dev/null || fooyin")
    end },
    { {}, "XF86AudioStop", "stop", function()
      awful.spawn("playerctl stop")
    end },
    { {}, "XF86AudioPrev", "prev", function()
      awful.spawn("playerctl previous")
    end },
    { {}, "XF86AudioNext", "next", function()
      awful.spawn("playerctl next")
    end },
    { {}, "XF86AudioRaiseVolume", "increase vol", function()
      awful.spawn("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+")
    end },
    { {}, "XF86AudioLowerVolume", "decrease vol", function()
      awful.spawn("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-")
    end },
  },
  { "tags",
    { { modkey }, "r", "rename tag",
      function()
        awful.prompt.run {
          prompt = "New tag name: ",
          textbox = awful.screen.focused().mypromptbox.widget,
          exe_callback = function(new_name)
            if not new_name or #new_name == 0 then return end
            local t = awful.screen.focused().selected_tag
            if t then t.name = t.index .. ":" .. new_name end
          end
        }
      end,
    }
  },
  { "client",
    { { modkey },          "h", "focus left",  function() awful.client.focus.global_bydirection("left") end },
    { { modkey },          "j", "focus down",  function() awful.client.focus.global_bydirection("down") end },
    { { modkey },          "k", "focus up",    function() awful.client.focus.global_bydirection("up") end },
    { { modkey },          "l", "focus right", function() awful.client.focus.global_bydirection("right") end },
    { { modkey, "Shift" }, "h", "swap left",   function() awful.client.swap.global_bydirection("left") end },
    { { modkey, "Shift" }, "j", "swap down",   function() awful.client.swap.global_bydirection("down") end },
    { { modkey, "Shift" }, "k", "swap up",     function() awful.client.swap.global_bydirection("up") end },
    { { modkey, "Shift" }, "l", "swap right",  function() awful.client.swap.global_bydirection("right") end },
    { { modkey, "Shift" }, "n", "unminimize", function()
      local c = awful.client.restore()
      -- Focus restored client
      if c then
        c:emit_signal("request::activate", "key.unminimize", { raise = true })
      end
    end },
  }
}
awful.keyboard.append_global_keybindings(make_keys(globalkeys))

local clientkeys = {
  { "client",
    { { modkey }, "f", "fullscreen", function(c)
      c.fullscreen = not c.fullscreen; c:raise()
    end },
    { { modkey }, "m", "maximize", function(c)
      c.maximized = not c.maximized; c:raise()
    end },
    { { modkey }, "n", "minimize", function(c)
      c.minimized = true
    end },
    { { modkey, "Shift" }, "c", "close", function(c)
      c:kill()
    end },
    { { modkey, "Control" }, "space", "float", awful.client.floating.toggle }
  }
}

-- Apply client keybindings
client.connect_signal("request::default_keybindings", function()
  awful.keyboard.append_client_keybindings(make_keys(clientkeys))
end)

awful.keyboard.append_global_keybindings({
  awful.key {
    modifiers   = { modkey },
    keygroup    = "numrow",
    description = "only view tag",
    group       = "tag",
    on_press    = function(index)
      local screen = awful.screen.focused()
      local tag = screen.tags[index]
      if tag then
        tag:view_only()
      end
    end,
  },
  awful.key {
    modifiers   = { modkey, "Control" },
    keygroup    = "numrow",
    description = "toggle tag",
    group       = "tag",
    on_press    = function(index)
      local screen = awful.screen.focused()
      local tag = screen.tags[index]
      if tag then
        awful.tag.viewtoggle(tag)
      end
    end,
  },
  awful.key {
    modifiers   = { modkey, "Shift" },
    keygroup    = "numrow",
    description = "move focused client to tag",
    group       = "tag",
    on_press    = function(index)
      if client.focus then
        local tag = client.focus.screen.tags[index]
        if tag then
          client.focus:move_to_tag(tag)
        end
      end
    end,
  },
  awful.key {
    modifiers   = { modkey, "Control", "Shift" },
    keygroup    = "numrow",
    description = "toggle focused client on tag",
    group       = "tag",
    on_press    = function(index)
      if client.focus then
        local tag = client.focus.screen.tags[index]
        if tag then
          client.focus:toggle_tag(tag)
        end
      end
    end,
  },
  awful.key {
    modifiers   = { modkey },
    keygroup    = "numpad",
    description = "select layout directly",
    group       = "layout",
    on_press    = function(index)
      local t = awful.screen.focused().selected_tag
      if t then
        t.layout = t.layouts[index] or t.layout
      end
    end,
  }
})
