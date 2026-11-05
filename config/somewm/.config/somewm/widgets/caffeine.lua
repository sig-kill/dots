-- Wibar idle-inhibit ("Caffeine") indicator and manual/timed toggle.
--
-- Three visual states:
--   1. Off (not awesome.idle_inhibited): dim 󰾪
--   2. Auto-inhibited (MPRIS media, fullscreen client, or Wayland app): 󰅶
--   3. Manual lock (toggled or timed preset): highlighted 󰅶 (or 󰅶 30m / 1h / 2h)

local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")
local wibox = require("wibox")

local ICON_OFF = "󰾪"
local ICON_ON  = "󰅶"
local FG_DIM   = "#859289"

local PRESETS = {
  { label = "30m", seconds = 30 * 60 },
  { label = "1h",  seconds = 60 * 60 },
  { label = "2h",  seconds = 120 * 60 },
}

local M = {
  manual = false,
  preset_label = nil,
  media_playing = false,
  fullscreen_client = false,
}

local preset_idx = 0
local preset_timer = gears.timer {
  timeout     = PRESETS[1].seconds,
  autostart   = false,
  single_shot = true,
}

local label = wibox.widget {
  text   = ICON_OFF,
  widget = wibox.widget.textbox,
}

M.widget = wibox.widget {
  label,
  fg     = FG_DIM,
  widget = wibox.container.background,
}

local function format_tooltip()
  local inhibited = M.manual or (awesome.idle_inhibited == true)
  if not inhibited then
    return "Idle inhibit: Off (DPMS 15m)"
  end

  local reasons = {}
  if M.manual then
    table.insert(reasons, M.preset_label and ("Manual " .. M.preset_label) or "Manual")
  end
  if M.media_playing then
    table.insert(reasons, "Media")
  end
  if M.fullscreen_client then
    table.insert(reasons, "Fullscreen")
  end
  if type(awesome.inhibitors) == "table" then
    local seen = {}
    for _, entry in ipairs(awesome.inhibitors) do
      if entry.visible ~= false then
        local c = entry.client
        local name = (c and c.valid and (c.class or c.name)) or "Wayland app"
        if not seen[name] then
          seen[name] = true
          table.insert(reasons, name)
        end
      end
    end
  end
  if #reasons == 0 then
    table.insert(reasons, "Active")
  end
  return "Idle inhibit: Active (" .. gears.string.xml_escape(table.concat(reasons, ", ")) .. ")"
end

local tip = awful.tooltip {
  objects        = { M.widget },
  timer_function = format_tooltip,
}

function M.update()
  local inhibited = M.manual or (awesome.idle_inhibited == true)
  if M.manual then
    local text = M.preset_label and (ICON_ON .. " " .. M.preset_label) or ICON_ON
    label:set_text(text)
    M.widget:set_fg(beautiful.border_color_active or beautiful.fg_focus)
    M.widget:set_bg(beautiful.bg_focus)
  elseif inhibited then
    label:set_text(ICON_ON)
    M.widget:set_fg(beautiful.fg_focus)
    M.widget:set_bg(nil)
  else
    label:set_text(ICON_OFF)
    M.widget:set_fg(FG_DIM)
    M.widget:set_bg(nil)
  end
  if tip.visible and tip.timer_function then
    tip:timer_function()
  end
end

function M.set_sources(media_playing, fullscreen_client)
  M.media_playing = media_playing == true
  M.fullscreen_client = fullscreen_client == true
  M.update()
end

local function notify_changed()
  awesome.emit_signal("caffeine::changed", M.manual)
  M.update()
end

preset_timer:connect_signal("timeout", function()
  preset_idx = 0
  M.preset_label = nil
  M.manual = false
  notify_changed()
end)

function M.toggle()
  if preset_timer.started then
    preset_timer:stop()
  end
  preset_idx = 0
  M.preset_label = nil
  M.manual = not M.manual
  notify_changed()
end

function M.cycle_preset()
  if preset_timer.started then
    preset_timer:stop()
  end
  preset_idx = (preset_idx + 1) % (#PRESETS + 1)
  if preset_idx == 0 then
    M.preset_label = nil
    M.manual = false
  else
    local preset = PRESETS[preset_idx]
    M.preset_label = preset.label
    M.manual = true
    preset_timer.timeout = preset.seconds
    preset_timer:again()
  end
  notify_changed()
end

M.widget.buttons = {
  awful.button({}, 1, function() M.toggle() end),
  awful.button({}, 3, function() M.cycle_preset() end),
}

awesome.connect_signal("property::idle_inhibited", function()
  M.update()
end)

M.update()

return M
