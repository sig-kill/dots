-- Centered floating notes terminal popup (`nvim ~/notes`), toggled by Super+`.

local awful = require("awful")
local ruled = require("ruled")
local profile = require("profile")

local M = {}

M.CLASS = "somewm.notes"

local WIDTH_FACTOR = 0.60
local HEIGHT_FACTOR = 0.70

local notes_client = nil
local spawning = false

local function find_client()
  if notes_client and notes_client.valid then
    return notes_client
  end
  for _, c in ipairs(client.get()) do
    if c.valid and c.class == M.CLASS then
      notes_client = c
      return c
    end
  end
  notes_client = nil
  return nil
end

local function apply_geometry(c, s)
  s = s or awful.screen.focused()
  if not (s and s.valid) then return end
  local wa = s.workarea
  local width = math.floor(wa.width * WIDTH_FACTOR)
  local height = math.floor(wa.height * HEIGHT_FACTOR)
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
  local t = s.selected_tag
  if t then
    c:tags({ t })
  end
  c.hidden = false
  c.minimized = false
  apply_geometry(c, s)
  c:activate({ context = "notes", raise = true })
end

local function hide(c)
  c.hidden = true
  c:tags({})
end

function M.toggle()
  local s = awful.screen.focused()
  local c = find_client()

  if not c then
    if spawning then return end
    spawning = true
    local term = profile.terminal or "alacritty"
    local cmd = string.format(
      'PATH="$HOME/bin:$HOME/.local/bin:$HOME/.cargo/bin:$PATH" exec %s --class=%s -e nvim "$HOME/notes"',
      term, M.CLASS
    )
    local pid = awful.spawn.easy_async_with_shell(cmd, function()
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
  end
end

ruled.client.connect_signal("request::rules", function()
  ruled.client.append_rule {
    id         = "notes_popup",
    rule       = { class = M.CLASS },
    properties = {
      floating     = true,
      ontop        = true,
      skip_taskbar = true,
    },
  }
end)

client.connect_signal("request::manage", function(c)
  if c.class ~= M.CLASS then return end
  notes_client = c
  spawning = false
  c:connect_signal("request::unmanage", function()
    if notes_client == c then
      notes_client = nil
    end
  end)
  if awesome.startup and c.hidden then
    c:tags({})
    return
  end
  show_on_screen(c, awful.screen.focused())
end)

return M
