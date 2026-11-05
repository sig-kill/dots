-- Notification history wibar widget, popup center, and Do Not Disturb toggle.

local awful = require("awful")
local beautiful = require("beautiful")
local dpi = require("beautiful.xresources").apply_dpi
local gears = require("gears")
local naughty = require("naughty")
local wibox = require("wibox")
local clay = require("wibox.clay")

local M = {}

local MAX_ENTRIES = 30
local MAX_VISIBLE = 5
local POPUP_WIDTH = dpi(460)
local MAX_TITLE_CHARS = 120
local MAX_MSG_CHARS = 350
local MAX_MSG_LINES = 6
local MUTED_FG = "#B8AD96"

local bold_font = (beautiful.font and beautiful.font:gsub("%s+([%d%.]+)$", " Bold %1"))
  or "Hack Nerd Font Bold 10"

local entries = {}
local scroll_offset = 1
local pinned = false
local last_screen = nil

------------------
-- Wibar widget --
------------------

local bar_text = wibox.widget {
  text   = "󰂚",
  widget = wibox.widget.textbox,
}

M.widget = wibox.widget {
  bar_text,
  widget = wibox.container.background,
}

------------------
-- Popup widget --
------------------

local header_title = wibox.widget {
  font   = bold_font,
  text   = "Notifications (0)",
  widget = wibox.widget.textbox,
}

local dnd_label = wibox.widget {
  text   = "[DND: Off]",
  widget = wibox.widget.textbox,
}

local dnd_button = wibox.widget {
  dnd_label,
  widget = wibox.container.background,
}

local clear_label = wibox.widget {
  text   = "[Clear]",
  widget = wibox.widget.textbox,
}

local clear_button = wibox.widget {
  clear_label,
  widget = wibox.container.background,
}

local header_bar = wibox.widget {
  header_title,
  nil,
  {
    dnd_button,
    clear_button,
    spacing = dpi(8),
    layout  = wibox.layout.fixed.horizontal,
  },
  layout = wibox.layout.align.horizontal,
}

local cards_layout = wibox.widget {
  spacing = dpi(6),
  layout  = wibox.layout.fixed.vertical,
}

local bw = beautiful.border_width or dpi(2)
local outer_margin = dpi(8)
local card_bw = dpi(1)
local card_margin = dpi(6)
local inner_max_w = math.max(1, POPUP_WIDTH - 2 * bw - 2 * outer_margin - 2 * card_bw - 2 * card_margin)

local popup_root = wibox.widget {
  {
    {
      header_bar,
      cards_layout,
      spacing = dpi(8),
      layout  = wibox.layout.fixed.vertical,
    },
    margins = outer_margin,
    widget  = wibox.container.margin,
  },
  bg           = beautiful.bg_normal,
  fg           = beautiful.fg_normal,
  border_width = bw,
  border_color = beautiful.border_color_normal,
  widget       = wibox.container.background,
}

local popup = awful.popup {
  ontop          = true,
  visible        = false,
  honor_workarea = true,
  minimum_width  = POPUP_WIDTH,
  maximum_width  = POPUP_WIDTH,
  border_width   = 0,
  bg             = gears.color.transparent,
  widget         = popup_root,
}

-------------------------
-- Rendering & Actions --
-------------------------

local refresh_ui

local function clamp_scroll()
  local max_offset = math.max(1, #entries - MAX_VISIBLE + 1)
  if scroll_offset > max_offset then
    scroll_offset = max_offset
  end
  if scroll_offset < 1 then
    scroll_offset = 1
  end
end

local function scroll_by(delta)
  if #entries <= MAX_VISIBLE then return end
  local prev = scroll_offset
  scroll_offset = scroll_offset + delta
  clamp_scroll()
  if scroll_offset ~= prev then
    refresh_ui()
  end
end

local function remove_entry(target)
  for i, entry in ipairs(entries) do
    if entry == target then
      table.remove(entries, i)
      break
    end
  end
  clamp_scroll()
  refresh_ui()
end

local function utf8_truncate(str, max_chars)
  if not str or str == "" then return "" end
  if #str <= max_chars then return str end
  local count = 0
  local cutoff = nil
  for pos in str:gmatch("()[%z\1-\127\194-\244][\128-\191]*") do
    count = count + 1
    if count > max_chars then
      cutoff = pos - 1
      break
    end
  end
  if cutoff then
    return (str:sub(1, cutoff):gsub("%s+$", "")) .. "…"
  end
  return str
end

local function format_message(raw)
  if not raw or raw == "" then return "" end
  local msg = raw:gsub("\r\n", "\n"):gsub("\r", "\n"):gsub("\n\n+", "\n")
  msg = msg:gsub("^%s+", ""):gsub("%s+$", "")
  local lines = {}
  local truncated_lines = false
  for line in (msg .. "\n"):gmatch("(.-)\n") do
    if #lines < MAX_MSG_LINES then
      table.insert(lines, line)
    else
      truncated_lines = true
      break
    end
  end
  msg = table.concat(lines, "\n")
  local char_truncated = utf8_truncate(msg, MAX_MSG_CHARS)
  if char_truncated ~= msg then
    return char_truncated
  end
  if truncated_lines then
    return (msg:gsub("%s+$", "")) .. "…"
  end
  return msg
end

local function make_card(entry)
  -- Cap and clip inner content width inside the card so unbroken tokens
  -- ellipsize at the inner margin instead of overflowing the popup box.
  local clip = wibox.container.constraint(nil, "max", inner_max_w)
  local base_describe = clip._clay.describe
  clay.describe_widget(clip, function(w, ...)
    local node = base_describe(w, ...)
    node.clip = true
    return node
  end, "wibox.container.constraint")

  local raw_title = entry.title ~= "" and entry.title
    or (entry.app_name ~= "" and entry.app_name or "Notification")
  local display_title = utf8_truncate(raw_title, MAX_TITLE_CHARS)
  local escaped_title = gears.string.xml_escape(display_title)

  local icon_w = entry.icon and (dpi(24) + dpi(8)) or 0
  local text_col_w = math.max(dpi(60), inner_max_w - icon_w)
  local time_reserve_w = dpi(72)
  local title_max_w = math.max(dpi(60), text_col_w - time_reserve_w)

  local title_widget = wibox.widget {
    font         = bold_font,
    markup       = "<b>" .. escaped_title .. "</b>",
    ellipsize    = "end",
    valign       = "top",
    forced_width = title_max_w,
    widget       = wibox.widget.textbox,
  }

  local time_str = (os.date("%I:%M %p", entry.time) or ""):gsub("^0", "")
  local time_widget = wibox.widget {
    text   = time_str,
    halign = "right",
    valign = "top",
    widget = wibox.widget.textbox,
  }

  local time_slot = wibox.widget {
    time_widget,
    fg     = MUTED_FG,
    widget = wibox.container.background,
  }

  local title_row = wibox.widget {
    wibox.container.constraint(title_widget, "max", title_max_w),
    nil,
    time_slot,
    layout = wibox.layout.align.horizontal,
  }

  local msg_widget = wibox.widget {
    text         = format_message(entry.message),
    ellipsize    = "end",
    valign       = "top",
    forced_width = text_col_w,
    widget       = wibox.widget.textbox,
  }

  local text_col = wibox.widget {
    title_row,
    wibox.container.constraint(msg_widget, "max", text_col_w),
    spacing      = dpi(2),
    forced_width = text_col_w,
    layout       = wibox.layout.fixed.vertical,
  }

  local row_children = {
    fill_space = true,
    spacing    = dpi(8),
    layout     = wibox.layout.fixed.horizontal,
  }
  if entry.icon then
    table.insert(row_children, wibox.widget {
      image         = entry.icon,
      resize        = true,
      forced_width  = dpi(24),
      forced_height = dpi(24),
      widget        = wibox.widget.imagebox,
    })
  end
  table.insert(row_children, text_col)

  clip:set_widget(wibox.widget(row_children))

  local card = wibox.widget {
    {
      clip,
      margins = card_margin,
      widget  = wibox.container.margin,
    },
    bg           = beautiful.bg_focus,
    fg           = beautiful.fg_normal,
    border_width = card_bw,
    border_color = beautiful.border_color_normal,
    widget       = wibox.container.background,
  }

  card:buttons(gears.table.join(
    awful.button({}, 1, function()
      local activated = false
      for _, c in ipairs(entry.clients or {}) do
        if c and c.valid then
          c:activate { context = "notification", raise = true, switch_to_tag = true }
          activated = true
          break
        end
      end
      if not activated then
        remove_entry(entry)
      end
    end),
    awful.button({}, 3, function()
      remove_entry(entry)
    end),
    awful.button({}, 4, function() scroll_by(-1) end),
    awful.button({}, 5, function() scroll_by(1) end)
  ))

  return card
end

local function refresh_wibar()
  local count = #entries
  local dnd = naughty.suspended == true
  local icon = dnd and "󰂛" or "󰂚"
  if count > 0 then
    bar_text:set_text(string.format("%s %d", icon, count))
  else
    bar_text:set_text(icon)
  end

  if dnd then
    M.widget:set_fg(beautiful.fg_urgent)
  elseif count > 0 then
    M.widget:set_fg(beautiful.fg_focus)
  elseif pinned then
    M.widget:set_fg(beautiful.border_color_active)
  else
    M.widget:set_fg(nil)
  end
  M.widget:set_bg(pinned and beautiful.bg_focus or nil)
end

local function refresh_popup()
  local count = #entries
  local dnd = naughty.suspended == true

  header_title:set_text(string.format("Notifications (%d)", count))
  dnd_label:set_text(dnd and "[DND: On]" or "[DND: Off]")
  dnd_button:set_fg(dnd and beautiful.fg_urgent or beautiful.fg_normal)
  clear_button:set_fg(count > 0 and beautiful.fg_focus or MUTED_FG)
  popup_root:set_border_color(pinned and beautiful.border_color_active or beautiful.border_color_normal)

  cards_layout:reset()
  if count == 0 then
    cards_layout:add(wibox.widget {
      {
        text   = "No notifications",
        halign = "center",
        widget = wibox.widget.textbox,
      },
      fg     = MUTED_FG,
      widget = wibox.container.background,
    })
    return
  end

  clamp_scroll()
  local last_idx = math.min(count, scroll_offset + MAX_VISIBLE - 1)
  for i = scroll_offset, last_idx do
    cards_layout:add(make_card(entries[i]))
  end
end

refresh_ui = function()
  refresh_wibar()
  refresh_popup()
end

local function position_popup(s)
  s = (s and s.valid) and s
    or (last_screen and last_screen.valid and last_screen)
    or mouse.screen
    or awful.screen.focused()
  if not (s and s.valid) then return end
  last_screen = s
  local bar = s.mywibox
  local is_top = bar and bar.position == "top"
  local margin = dpi(5)
  popup:set_screen(s)
  popup:set_offset { x = -margin, y = is_top and margin or -margin }
  popup:set_placement(is_top and awful.placement.top_right or awful.placement.bottom_right)
end

local function show_popup(s)
  refresh_popup()
  position_popup(s)
  popup.visible = true
end

----------------
-- Public API --
----------------

function M.toggle_dnd()
  if naughty.suspended then
    local queued = gears.table.clone(
      naughty.notifications and naughty.notifications.suspended or {},
      false
    )
    for _, n in ipairs(queued) do
      if not (n._private and n._private.is_destroyed) then
        n:destroy(naughty.notification_closed_reason.silent)
      end
    end
    naughty.suspended = false
  else
    naughty.suspended = true
  end
  refresh_ui()
end

function M.clear()
  entries = {}
  scroll_offset = 1
  refresh_ui()
end

local hide_timer = gears.timer {
  timeout     = 0.1,
  single_shot = true,
  callback    = function()
    if not pinned then
      popup.visible = false
    end
  end,
}

function M.toggle()
  if hide_timer.started then
    hide_timer:stop()
  end
  if not popup.visible or not pinned then
    pinned = true
    refresh_wibar()
    show_popup(mouse.screen or awful.screen.focused())
  else
    pinned = false
    popup.visible = false
    refresh_wibar()
  end
end

function M.get_entries()
  return entries
end

-------------------------------
-- Signals & Mouse Bindings  --
-------------------------------

dnd_button:buttons(gears.table.join(
  awful.button({}, 1, function() M.toggle_dnd() end)
))

clear_button:buttons(gears.table.join(
  awful.button({}, 1, function() M.clear() end)
))

popup:buttons(gears.table.join(
  awful.button({}, 4, function() scroll_by(-1) end),
  awful.button({}, 5, function() scroll_by(1) end)
))

popup:connect_signal("property::visible", function()
  if not popup.visible and pinned then
    pinned = false
    refresh_wibar()
    refresh_popup()
  end
end)

popup:connect_signal("mouse::enter", function()
  if hide_timer.started then
    hide_timer:stop()
  end
end)

popup:connect_signal("mouse::leave", function()
  if not pinned then
    hide_timer:again()
  end
end)

M.widget:connect_signal("mouse::enter", function()
  if hide_timer.started then
    hide_timer:stop()
  end
  if not pinned then
    show_popup(mouse.screen or awful.screen.focused())
  end
end)

M.widget:connect_signal("mouse::leave", function()
  if not pinned then
    hide_timer:again()
  end
end)

M.widget:buttons(gears.table.join(
  awful.button({}, 1, function() M.toggle() end),
  awful.button({}, 2, function() M.toggle_dnd() end),
  awful.button({}, 3, function() M.toggle_dnd() end)
))

naughty.connect_signal("property::suspended", function()
  refresh_ui()
end)

local function upsert_notification(n)
  if n.ignore or (n.preset and n.preset.ignore == true) then
    return nil
  end

  local ok_clients, n_clients = pcall(function() return n.clients end)
  local entry
  if n.id ~= nil then
    for i, existing in ipairs(entries) do
      if existing.id == n.id then
        entry = table.remove(entries, i)
        break
      end
    end
  end

  if entry then
    entry.app_name = n.app_name or entry.app_name or ""
    entry.title    = n.title or ""
    entry.message  = n.message or ""
    entry.icon     = n.icon or entry.icon
    entry.time     = os.time()
    entry.clients  = (ok_clients and n_clients) or entry.clients or {}
  else
    entry = {
      id       = n.id,
      app_name = n.app_name or "",
      title    = n.title or "",
      message  = n.message or "",
      icon     = n.icon,
      time     = os.time(),
      clients  = (ok_clients and n_clients) or {},
    }
  end

  table.insert(entries, 1, entry)
  while #entries > MAX_ENTRIES do
    table.remove(entries)
  end
  clamp_scroll()
  refresh_ui()
  return entry
end

naughty.connect_signal("new", function(n)
  local entry = upsert_notification(n)
  if not entry then return end

  local function on_update()
    upsert_notification(n)
  end
  local function on_destroyed()
    n:disconnect_signal("property::title", on_update)
    n:disconnect_signal("property::message", on_update)
    n:disconnect_signal("property::icon", on_update)
    n:disconnect_signal("destroyed", on_destroyed)
  end

  n:connect_signal("property::title", on_update)
  n:connect_signal("property::message", on_update)
  n:connect_signal("property::icon", on_update)
  n:connect_signal("destroyed", on_destroyed)
end)

refresh_ui()

return M
