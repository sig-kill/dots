-- Centered floating popup helper for scratchpad-style windows (notes, fsearch, etc.).

local awful = require("awful")
local ruled = require("ruled")

local M = {}

local DEFAULT_WIDTH_FACTOR = 0.60
local DEFAULT_HEIGHT_FACTOR = 0.70

function M.new(opts)
  local id = assert(opts.id, "popup.new requires opts.id")
  local cmd = assert(opts.cmd, "popup.new requires opts.cmd")
  local classes = type(opts.class) == "table" and opts.class or { opts.class }
  local width_factor = opts.width_factor or DEFAULT_WIDTH_FACTOR
  local height_factor = opts.height_factor or DEFAULT_HEIGHT_FACTOR
  local on_show = opts.on_show

  local class_set = {}
  for _, cls in ipairs(classes) do
    class_set[cls] = true
  end

  local popup = {
    CLASS = classes[1],
  }

  local popup_client = nil
  local spawning = false

  local function matches(c)
    return c.class ~= nil and class_set[c.class] == true
  end

  local function find_client()
    if popup_client and popup_client.valid then
      return popup_client
    end
    for _, c in ipairs(client.get()) do
      if c.valid and matches(c) then
        popup_client = c
        return c
      end
    end
    popup_client = nil
    return nil
  end

  local function apply_geometry(c, s)
    s = s or awful.screen.focused()
    if not (s and s.valid) then return end
    local wa = s.workarea
    local width = math.floor(wa.width * width_factor)
    local height = math.floor(wa.height * height_factor)
    local x = wa.x + math.floor((wa.width - width) / 2)
    local y = wa.y + math.floor((wa.height - height) / 2)

    c.floating = true
    c.ontop = true
    c.skip_taskbar = true
    c:geometry({ x = x, y = y, width = width, height = height })
  end

  local function show_on_screen(c, s)
    s = s or awful.screen.focused()
    if not (s and s.valid) then return end
    if c.screen ~= s then
      c:move_to_screen(s)
    end
    c.hidden = false
    c.minimized = false
    local t = s.selected_tag
    if t then
      c:tags({ t })
    end
    apply_geometry(c, s)
    awful.layout.arrange(s)
    c:activate({ context = id, raise = true })
    client.focus = c
    c:raise()
  end

  local function hide(c)
    c.hidden = true
    c:tags({})
    if c.screen then
      awful.layout.arrange(c.screen)
    end
  end

  function popup.toggle()
    local s = awful.screen.focused()
    local c = find_client()

    if not c then
      if spawning then return end
      spawning = true
      local spawn_cmd = 'PATH="$HOME/bin:$HOME/.local/bin:$HOME/.cargo/bin:$PATH" exec ' .. cmd
      local pid = awful.spawn.easy_async_with_shell(spawn_cmd, function()
        spawning = false
      end)
      if type(pid) == "string" then
        spawning = false
      end
      return
    end

    if not c.hidden and c.screen == s and c:isvisible() then
      hide(c)
    else
      show_on_screen(c, s)
      if on_show then
        on_show(c)
      end
    end
  end

  ruled.client.connect_signal("request::rules", function()
    ruled.client.append_rule {
      id         = id .. "_popup",
      rule_any   = { class = classes },
      properties = {
        floating     = true,
        ontop        = true,
        skip_taskbar = true,
      },
    }
  end)

  client.connect_signal("request::manage", function(c)
    if not matches(c) then return end
    popup_client = c
    spawning = false
    c:connect_signal("request::unmanage", function()
      if popup_client == c then
        popup_client = nil
      end
    end)
    if awesome.startup and c.hidden then
      c:tags({})
      return
    end
    show_on_screen(c, awful.screen.focused())
  end)

  return popup
end

return M
