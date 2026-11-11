-- Wibar widget for listing and restoring withdrawn (hidden/minimized-to-tray) X11 windows.

local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")
local wibox = require("wibox")

local M = {}

local script_dir = debug.getinfo(1, "S").source:match("@(.*/)") or ""
local helper = script_dir .. "withdrawn_helper.py"

local ICON = "󰖲"
local FG_DIM = "#859289"

local label = wibox.widget {
  text   = ICON,
  widget = wibox.widget.textbox,
}

M.widget = wibox.widget {
  label,
  fg     = FG_DIM,
  widget = wibox.container.background,
}

awful.tooltip {
  objects        = { M.widget },
  timer_function = function()
    return "Withdrawn Windows (Click to list &amp; restore)"
  end,
}

M.widget:connect_signal("mouse::enter", function()
  M.widget:set_fg(beautiful.fg_focus or "#FFFFFF")
end)

M.widget:connect_signal("mouse::leave", function()
  M.widget:set_fg(FG_DIM)
end)

local current_menu = nil

-- Remap / restore a withdrawn window by ID.
function M.unwithdraw(wid)
  awful.spawn({ helper, "unwithdraw", wid }, false)
end

-- Connect internal SomeWM signal to unwithdraw handler.
awesome.connect_signal("withdrawn::unwithdraw", function(wid)
  M.unwithdraw(wid)
end)

-- Scan for all X11 windows in Withdrawn state and show popup menu.
function M.toggle()
  if current_menu then
    current_menu:hide()
    current_menu = nil
    return
  end

  awful.spawn.easy_async({ helper, "list" }, function(stdout)
    local items = {}
    for line in stdout:gmatch("[^\r\n]+") do
      local wid, title = line:match("^(0x%x+)\t(.*)$")
      if wid then
        table.insert(items, {
          title .. " (" .. wid .. ")",
          function()
            awesome.emit_signal("withdrawn::unwithdraw", wid)
          end
        })
      end
    end

    if #items == 0 then
      table.insert(items, { "No withdrawn windows", function() end })
    end

    current_menu = awful.menu({
      items = items,
      theme = { width = 280 }
    })
    current_menu:show()
  end)
end

M.widget:buttons(gears.table.join(
  awful.button({}, 1, function() M.toggle() end),
  awful.button({}, 3, function() M.toggle() end)
))

return M
