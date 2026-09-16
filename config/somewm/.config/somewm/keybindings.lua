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
      -- Clients on a floating-layout tag report floating == false (that flag
      -- only marks explicit floats), yet floating's handler is corner based:
      -- it builds the mousegrabber cursor from `corner`. Route those clients
      -- to awful.mouse.client.resize, which derives the corner itself.
      if not c.floating and l and l ~= awful.layout.suit.floating
          and l.mouse_resize_handler then
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

-- Lock with Hyprlock and shorten the monitor-off idle timeout while locked.
-- SomeWM emits no Lua signal for ext-session-lock transitions, and
-- awful.spawn.single_instance reports client creation, not process exit, so
-- the lock state is tracked here: a 5-minute "dpms-locked" timeout is armed
-- on spawn and cleared when the hyprlock process exits (exit = unlock). The
-- flag swallows key-repeat presses before hyprlock acquires the lock; a
-- second hyprlock would exit instantly and clear the timeout while locked.
local locking = false

local function lock_screen()
  if locking or awesome.lock_mechanism then return end
  locking = true

  awesome.set_idle_timeout("dpms-locked", 5 * 60, function()
    awesome.dpms_off()
  end)

  local spawned = awful.spawn.easy_async('hyprlock', function()
    locking = false
    awesome.clear_idle_timeout("dpms-locked")
  end)
  if type(spawned) == "string" then
    -- Spawn failed outright (e.g. binary missing); undo the lock state.
    locking = false
    awesome.clear_idle_timeout("dpms-locked")
  end
end

local globalkeys = {
  -- { modifiers, key, description, callback }
  { "awesome",
    { { modkey },             "/",     "show help",   hotkeys_popup.show_help },
    { { modkey, "Shift" },    "/",     "debug",       require('persist').save_open_windows },
    -- modkey+Shift+r (reload) is not here: it is bound to the key *release*,
    -- see the append below the keygroup block.
    { { modkey, "Control" },  "r",     "flush tray",  function() require('widgets').systray.flush() end },
    { { modkey, "Shift" },    "q",     "quit",        awesome.quit },
    { { modkey },             "Space", "next layout", function() awful.layout.inc(1) end },
    { { modkey, "Shift" },    "Space", "prev layout", function() awful.layout.inc(-1) end },
    { { modkey },             "w",     "lock screen", lock_screen },
    { { "Control", "Shift" }, "x",     "screenshot",  take_screenshot },
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
    { { "Control", "Mod1" }, "XF86Ungrab",    "[mouse] play/pause", play_pause_player },
    { {},                    "XF86AudioPlay", "play/pause",         play_pause_player },
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

---------------------------------------------------------------------------
-- Reload quiet period
---------------------------------------------------------------------------

-- A hot-reload closes the old Lua state, so a reload that lands while the
-- previous one's systray D-Bus re-probe still has replies in flight abandons
-- an lgi callback that then fires into freed memory: freed cif, general
-- protection fault inside the closure guard (2026-09-14 21:32 crash). The
-- exposure is the first moments of a rebuilt state - a reload 1s after the
-- previous one leaked a source and crashed, one 6s after did not.
--
-- So a state that itself came from a reload refuses to start another one for
-- a few seconds. Cold boot is exempt: somewm only sets awesome._restart on a
-- state rebuilt by luaA_hot_reload, so a fresh session reloads at once.
--
-- This shadows awesome.restart before the reload binding below captures it,
-- which also puts rc.lua's menu item and awful.ipc's `reload` command behind
-- the same guard instead of letting them bypass it.
local RELOAD_QUIET_S = 3
local reload_ready = not awesome._restart
local restart = awesome.restart

if awesome._restart then
  -- Single shot: gears.timer stops when the callback returns false, and it
  -- releases its source on "exit", so it cannot outlive this state.
  gears.timer.start_new(RELOAD_QUIET_S, function()
    reload_ready = true
    return false
  end)
end

awesome.restart = function()
  if not reload_ready then
    print(string.format("somewm: reload ignored, a reload already ran "
      .. "within the last %ds", RELOAD_QUIET_S))
    return
  end
  reload_ready = false
  restart()
end

-- Reload on the key *release*, not on the press.
--
-- SomeWM re-fires a handled keybinding from the keyboard repeat timer
-- (input.c: keyrepeat() calls keybinding() again, hardcoded to the press
-- condition), and a reload blocks the event loop for longer than the repeat
-- delay, so one press runs awesome.restart() twice. The second reload closes
-- the Lua state that systray's post-reload D-Bus re-probe still has a reply in
-- flight for, and the abandoned lgi callback then fires into freed memory
-- (freed cif, GP fault in the closure guard: 2026-09-14 21:32 crash). Repeat
-- dispatch is always a press, so a release-bound restart cannot be re-fired:
-- it runs once per press, on the way up.
--
-- What makes this match is that `r` comes up while Mod4 and Shift are still
-- held - objects/keybinding.c compares the modifier mask exactly, so releasing
-- either modifier first loses the event. Release the letter first.
awful.keyboard.append_global_keybindings({
  awful.key {
    modifiers   = { modkey, "Shift" },
    key         = "r",
    description = "reload config",
    group       = "awesome",
    on_release  = awesome.restart,
  },
})

return { modkey = modkey }
