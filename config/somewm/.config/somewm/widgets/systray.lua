-- Systray deduplication and manual flush helper.
--
-- During awesome.restart(), somewm's awful.systray registers each tray icon
-- asynchronously (via D-Bus GetAll in fetch_item_properties) before setting
-- systray._private.items[item_key]. Because the post-restart _systray_snapshot
-- re-probe loop races with StatusNotifierWatcher's StatusNotifierItemRegistered
-- signals and fetch_registered_items(), multiple GetAll calls fire concurrently
-- for the same item_key. Each completion calls systray_item.register() (which
-- appends a new userdata object to C's systray_items array) and overwrites
-- systray._private.items[item_key], orphaning the earlier C item(s). Because
-- wibox.widget.systray renders systray_item.get_items(), all orphaned C items
-- appear as duplicate icons on the bar and compound on subsequent reloads.
--
-- Two config-side defenses fix this without patching somewm:
--   1. Deduplicate awesome._systray_snapshot at config load time before
--      awful.systray's init idle runs.
--   2. Connect to "systray::added" (which fires right after a new item is
--      stored in systray._private.items[item_key] and right before
--      "systray::update" syncs the widget) and immediately unregister any
--      orphaned or duplicate items from C's systray_items array.

local lgi = require("lgi")
local Gio = lgi.Gio
local GLib = lgi.GLib

local M = {}

-- 1. Deduplicate awesome._systray_snapshot before systray.init() reads it.
if awesome._restart and awesome._systray_snapshot then
  local seen = {}
  local deduped = {}
  for _, entry in ipairs(awesome._systray_snapshot) do
    local key = (entry.bus_name or "") .. (entry.object_path or "/StatusNotifierItem")
    if entry.bus_name and not seen[key] then
      seen[key] = true
      table.insert(deduped, entry)
    end
  end
  awesome._systray_snapshot = deduped
end

-- 2. Prune any C systray_item objects that are not the active item in
--    awful.systray._private.items (or duplicate an already-seen bus..path key).
function M.prune_duplicates()
  local s = require("awful.systray")
  local active = {}
  for _, item in pairs(s._private.items or {}) do
    active[item] = true
  end

  local seen_keys = {}
  for _, item in ipairs(systray_item.get_items()) do
    local key = (item.bus_name or "") .. (item.object_path or "")
    if not active[item] or (key ~= "" and seen_keys[key]) then
      local data = s._private.item_data and s._private.item_data[item]
      if data then
        if data.name_watch_id then
          pcall(Gio.bus_unwatch_name, data.name_watch_id)
        end
        if data.signal_sub_id and s._private.bus then
          pcall(function() s._private.bus:signal_unsubscribe(data.signal_sub_id) end)
        end
        s._private.item_data[item] = nil
      end
      systray_item.unregister(item)
    elseif key ~= "" then
      seen_keys[key] = true
    end
  end
end

awesome.connect_signal("systray::added", M.prune_duplicates)

-- 3. Manual tray flush: unregisters all current C/Lua tray items and
--    re-triggers registration for every known SNI service.
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
