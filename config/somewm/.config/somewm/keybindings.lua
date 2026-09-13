local gears = require("gears")
local awful = require("awful")
local hotkeys_popup = require("awful.hotkeys_popup")
-- awful.hotkeys_popup.keys (the popup shown when a matching client opens) is
-- required by rc.lua, before this module loads.
local ruled = require("ruled")

-- The modifier every binding below is built on. Exported at the bottom of this
-- file for the taglist buttons (widgets.taglist), so no module has to read it
-- from a global.
local modkey = "Mod4"

--------------------
-- Mouse bindings --
--------------------

-- 1, 2, 3, 4, 5: Left, Middle, Right, Scroll up, Scroll down
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
      c:activate({ context = "mouse_click" })

      local t = c.screen and c.screen.selected_tag
      local l = t and t.layout
      if not c.floating and l and l.mouse_resize_handler then
        local cur = mouse.coords()
        l.mouse_resize_handler(c, nil, cur.x, cur.y)
      else
        awful.mouse.client.resize(c)
      end
    end),
  })
end)

--------------------
-- Sloppy focus --
--------------------

-- Clients matching an entry here keep the focus they had when the mouse enters
-- them. Empty today: the Steam exclusion is disabled on purpose, so every
-- client (including the bottom-monitor meters) takes focus on hover.
local focus_entry_exclusions = {
  -- { name = "", class = "" },
}

-- Sloppy focus (application focus follows mouse)
client.connect_signal("mouse::enter", function(c)
  for _, rule in ipairs(focus_entry_exclusions) do
    if ruled.client.match(c, rule) then return end
  end

  c:activate { context = "mouse_enter", raise = false }
end)

-----------------------
-- Keyboard bindings --
-----------------------

-- Groups are `{ "group name", { modifiers, key, description, callback }, ... }`.
-- Only the first four entries of each binding are used: a fifth entry and
-- beyond is silently ignored. Bindings that need a keygroup (numrow/numpad,
-- below) cannot be expressed here and are appended separately.
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

local function run_lua_prompt()
  awful.prompt.run {
    prompt = "Run Lua code: ",
    textbox = awful.screen.focused().mypromptbox.widget,
    exe_callback = function(input)
      local naughty = require('naughty')
      if not input or #input == 0 then
        naughty.notify { text = "Empty input" }
      else
        local fn, err = (loadstring or load)(input)
        if fn then
          local success, res = pcall(fn)
          if success then
            naughty.notify({ text = gears.debug.dump_return(res) })
          else
            naughty.notify({ text = "Error: " .. tostring(res) })
          end
        else
          naughty.notify({ text = "Compile error: " .. tostring(err) })
        end
      end
    end,
    history_path = gears.filesystem.get_cache_dir() .. "history_eval"
  }
end

local function rename_tag_prompt()
  awful.prompt.run {
    prompt = "New tag name: ",
    textbox = awful.screen.focused().mypromptbox.widget,
    exe_callback = function(new_name)
      if not new_name or #new_name == 0 then return end
      local t = awful.screen.focused().selected_tag
      if t then t.name = t.index .. ":" .. new_name end
    end
  }
end

local function take_screenshot()
  awful.spawn.with_shell('grim -g "$(slurp)" - | swappy -f -')
end

-- Player start/pause. Shared by the mouse side button (mapped to
-- Ctrl+Alt+KP_Divide, which results in XF86Ungrab) and the media key.
local function play_pause_player()
  awful.spawn.with_shell("playerctl --player=fooyin,%any play-pause || pgrep -x fooyin > /dev/null || fooyin")
end

local function restore_minimized_client()
  local c = awful.client.restore()
  -- Focus restored client
  if c then
    c:emit_signal("request::activate", "key.unminimize", { raise = true })
  end
end

local globalkeys = {
  -- { modifiers, key, description, callback }
  { "awesome",
    { { modkey },          "/",     "show help",     hotkeys_popup.show_help },
    { { modkey, "Shift" }, "/",     "debug",         require('persist').save_open_windows },
    { { modkey, "Shift" }, "r",     "reload config", awesome.restart },
    { { modkey, "Shift" }, "q",     "quit",          awesome.quit },
    { { modkey },          "Space", "next layout",   function() awful.layout.inc(1) end },
    { { modkey, "Shift" }, "Space", "prev layout",   function() awful.layout.inc(-1) end },
    { { modkey },          "w",     "lock screen",   function() awful.spawn.single_instance('hyprlock') end },
    { { "Control", "Shift" }, "x", "screenshot", take_screenshot },
  },
  { "launcher",
    { { modkey },          "Return", "open terminal", function() awful.spawn(terminal) end },
    { { modkey, "Shift" }, "Return", "open app",      function() awful.spawn('rofi -show drun') end },
    { { modkey, "Control" }, "Return", "open app", function()
      awful.screen.focused().mypromptbox:run()
    end },
    { { modkey }, "x", "execute lua", run_lua_prompt },
  },
  { "media",
    { { "Control", "Mod1" }, "XF86Ungrab", "[mouse] play/pause", play_pause_player },
    { {}, "XF86AudioPlay", "play/pause", play_pause_player },
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
    { { modkey }, "r", "rename tag", rename_tag_prompt },
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
    { { modkey, "Shift" }, "n", "unminimize",  restore_minimized_client },
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

-- Keygroup bindings (numrow/numpad): not expressible in the make_keys DSL above.
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

return { modkey = modkey }
