-- Manual systray flush helper.

local lgi = require("lgi")
local Gio = lgi.Gio
local GLib = lgi.GLib

local M = {}

-- Manual tray flush: unregisters all current C/Lua tray items and
-- re-triggers registration for every known SNI service.
function M.flush()
  local s = require("awful.systray")
  local watcher = require("awful.statusnotifierwatcher")

  -- Collect all unique service..path strings before clearing
  local services = {}
  local seen = {}
  local function add_service(full)
    if full and full ~= "" and not seen[full] then
      seen[full] = true
      table.insert(services, full)
    end
  end

  for _, item in ipairs(systray_item.get_items()) do
    if item.bus_name and item.bus_name ~= "" then
      add_service(item.bus_name .. (item.object_path or "/StatusNotifierItem"))
    end
  end
  for service in pairs(watcher._private.registered_items or {}) do
    add_service(service)
  end

  -- Clean up per-item D-Bus watches/subscriptions and unregister all C items
  for _, data in pairs(s._private.item_data or {}) do
    if data.name_watch_id then
      pcall(Gio.bus_unwatch_name, data.name_watch_id)
    end
    if data.signal_sub_id and s._private.bus then
      pcall(function() s._private.bus:signal_unsubscribe(data.signal_sub_id) end)
    end
  end
  s._private.items = {}
  s._private.item_data = {}
  s._private.pending_items = {}
  for _, item in ipairs(systray_item.get_items()) do
    systray_item.unregister(item)
  end
  awesome.emit_signal("systray::update")

  -- Re-probe each service via StatusNotifierItemRegistered
  if s._private.bus then
    for _, full_service in ipairs(services) do
      s._private.bus:emit_signal(
        nil,
        "/StatusNotifierWatcher",
        "org.kde.StatusNotifierWatcher",
        "StatusNotifierItemRegistered",
        GLib.Variant("(s)", { full_service })
      )
    end
  end
end

return M
