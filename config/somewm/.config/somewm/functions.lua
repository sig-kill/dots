local awful = require('awful')
local gears = require('gears')
local ruled = require('ruled')
local GLib = require('lgi').GLib

local M = {}

-- Persisted-window cache. Defaults to the config-dir file; override with
-- SOMEWM_PERSIST_WINDOWS so a nested test compositor can't clobber the live one.
local CACHE_PATH = os.getenv("SOMEWM_PERSIST_WINDOWS")
    or (os.getenv("HOME") .. "/.config/somewm/.persist_windows")

local SEP = "|||"

-- Is a process named/matching `name` already running for this user?
-- `pgrep` is spawned directly with an argv list instead of via a shell:
-- `awful.spawn.with_shell` runs `$SHELL -c "<whole command>"`, so the wrapper
-- shell's own command line contains the binary name. A shell-based
-- `pgrep -f <name>` then matches that wrapper and reports every program as
-- already running, which suppresses the launch entirely.
-- Escape POSIX ERE metacharacters: the pattern is passed to pgrep as an argv
-- entry, never through a shell, so only pgrep's own regex syntax matters.
local function ere_escape(s)
  return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?%{%}%|\\]", "\\%0"))
end

-- argv[0]-basename match: the process must start with `name`, so helpers and
-- argv-only mentions (`playerctl -p fooyin`, `.../steamwebhelper`) no longer
-- count as the application running.
local function cmdline_pattern(name)
  return "^([^ ]*/)?" .. ere_escape(name) .. "( |$)"
end

local function is_running(name, callback)
  local user = GLib.get_user_name()
  awful.spawn.easy_async({ 'pgrep', '-u', user, '-x', '--', name }, function(_, _, _, code)
    if code == 0 then
      return callback(true)
    end
    awful.spawn.easy_async({ 'pgrep', '-u', user, '-f', '--', cmdline_pattern(name) },
      function(_, _, _, code2)
        callback(code2 == 0)
      end)
  end)
end

M.run_once = function(cmd, proc)
  local bin = (proc or cmd:match("^%s*(%S+)")):match("[^/]+$")
  is_running(bin, function(running)
    if not running then
      awful.spawn.with_shell(cmd)
    end
  end)
end

-- Resolve a tag on `screen` by name, tolerating the "<index>:" prefix default
-- tags carry: both "browser" and "2:browser" match a tag named "2:browser".
-- Used by rules.lua and restore_windows so the index prefix (or a rename)
-- never breaks tag references.
local function tag_base(name)
  return (name:gsub("^%d+:", ""))
end

M.find_tag = function(screen, name)
  if not screen or not name then return nil end
  local exact = awful.tag.find_by_name(screen, name)
  if exact then return exact end
  local base = tag_base(name)
  for _, t in ipairs(screen.tags) do
    if tag_base(t.name) == base then return t end
  end
  return nil
end

-- Serialize each screen's tags and every tagged client to CACHE_PATH.
-- One record per line; the first field is the record type:
--   tag|||role|||index|||layout|||selected|||name
--   client|||role|||tag|||class|||instance|||floating|||x|||y|||width|||height|||name
-- `name` is last so tag names/titles containing the separator still parse.
-- Missing strings are written as "nil"; geometry only for floating clients.
M.save_open_windows = function()
  local f = io.open(CACHE_PATH, "w")
  if not f then return end
  local seen = {}
  for screen_role, output in pairs(displays) do
    local s = output.screen
    if s then
      for i, tag in ipairs(s.tags) do
        f:write(table.concat({
          "tag",
          screen_role,
          tostring(i),
          tag.layout and tag.layout.name or "nil",
          tag.selected and "1" or "0",
          tag.name,
        }, SEP) .. "\n")
      end
      for _, tag in ipairs(s.tags) do
        for _, c in ipairs(tag:clients()) do
          if not seen[c] then
            seen[c] = true
            local g = c.floating and c:geometry() or nil
            f:write(table.concat({
              "client",
              screen_role,
              tag.name,
              c.class or "nil",
              c.instance or "nil",
              c.floating and "1" or "0",
              g and tostring(g.x) or "nil",
              g and tostring(g.y) or "nil",
              g and tostring(g.width) or "nil",
              g and tostring(g.height) or "nil",
              c.name or "nil",
            }, SEP) .. "\n")
          end
        end
      end
    end
  end
  f:close()
end

local CLIENT_PATTERN = "^" .. table.concat({ "(.-)", "(.-)", "(.-)", "(.-)",
  "(.-)", "(.-)", "(.-)", "(.-)", "(.-)", "(.*)" }, SEP) .. "$"
local TAG_PATTERN = "^" .. table.concat({ "(.-)", "(.-)", "(.-)", "(.-)", "(.*)" },
  SEP) .. "$"

-- Parse CACHE_PATH into { clients = {...}, tags = { role = { rec, ... } } }.
-- Lines with an unknown type (including the old 4-field format) are ignored.
local function read_cache()
  local data = { clients = {}, tags = {} }
  local f = io.open(CACHE_PATH, "r")
  if not f then return data end
  for line in f:lines() do
    local kind, rest = line:match("^(%w+)" .. SEP .. "(.*)$")
    if kind == "client" then
      local role, tag_name, class, instance, floating, x, y, width, height, name =
          rest:match(CLIENT_PATTERN)
      if role then
        table.insert(data.clients, {
          role = role, tag = tag_name, class = class, instance = instance,
          floating = floating, x = x, y = y, width = width, height = height,
          name = name,
        })
      end
    elseif kind == "tag" then
      local role, index, layout, selected, name = rest:match(TAG_PATTERN)
      if role and name then
        data.tags[role] = data.tags[role] or {}
        table.insert(data.tags[role], {
          index = tonumber(index) or 0,
          layout = layout,
          selected = selected == "1",
          name = name,
        })
      end
    end
  end
  f:close()
  return data
end

-- Rebuild ruled.client rules from CACHE_PATH so clients return to their saved
-- screen/tag (and floating geometry) when the rules are re-applied. Matching
-- uses class/instance; `name` is added only when the cache holds more than one
-- entry with the same class+instance, because window titles change between
-- sessions (Wayland gives no per-instance id). Entries with neither class nor
-- instance are skipped so a rule can never become a catch-all. Bottom-monitor
-- clients are left to functions.bottom_windows, which owns their placement.
M.restore_windows = function()
  local data = read_cache()

  -- Entries that can produce a rule, counted by class+instance so `name` is
  -- only used as a tie-breaker between windows of the same app.
  local eligible = {}
  local key_count = {}
  for _, entry in ipairs(data.clients) do
    if entry.role ~= "bottom"
        and displays[entry.role] and displays[entry.role].screen
        and (entry.class ~= "nil" or entry.instance ~= "nil") then
      table.insert(eligible, entry)
      local key = entry.class .. "|" .. entry.instance
      key_count[key] = (key_count[key] or 0) + 1
    end
  end

  for index, entry in ipairs(eligible) do
    local rule = {}
    if entry.class ~= "nil" then rule.class = entry.class end
    if entry.instance ~= "nil" then rule.instance = entry.instance end
    if entry.name ~= "nil" and key_count[entry.class .. "|" .. entry.instance] > 1 then
      rule.name = entry.name
    end

    local wanted_tag = entry.tag
    local properties = {
      screen = displays[entry.role].screen,
      tag = function(c) return M.find_tag(c.screen, wanted_tag) end,
    }
    if entry.floating == "1" and entry.x ~= "nil" then
      properties.floating = true
      properties.x = tonumber(entry.x)
      properties.y = tonumber(entry.y)
      properties.width = tonumber(entry.width)
      properties.height = tonumber(entry.height)
    end

    ruled.client.append_rule {
      id = "persisted_" .. index,
      rule = rule,
      properties = properties,
    }
  end
end

-- Recreate screen `s`'s tags from the persisted tag records — names, order,
-- layout and selection — so runtime renames survive a reload. Returns false
-- when nothing is persisted for this screen's role, so the caller can fall
-- back to the profile defaults (layouts.default_tags).
M.restore_tags = function(s)
  local role
  for r, o in pairs(displays) do
    if o.screen == s then role = r; break end
  end
  if not role then return false end

  local records = read_cache().tags[role]
  if not records or #records == 0 then return false end

  local layouts = require("layouts")
  local layout_by_name = {}
  for _, layout in ipairs(layouts.list) do
    layout_by_name[layout.name] = layout
  end

  table.sort(records, function(a, b) return a.index < b.index end)

  local any_selected = false
  local tags = {}
  for i, rec in ipairs(records) do
    any_selected = any_selected or rec.selected
    tags[i] = awful.tag.add(rec.name, {
      screen = s,
      layout = layout_by_name[rec.layout] or layouts.list[1],
      selected = rec.selected,
    })
  end
  if not any_selected and tags[1] then
    tags[1].selected = true
  end
  return true
end

-- Single source of truth for bottom-monitor window positions.
-- Used by both ruled.client spawn rules (rules.lua) and DPMS realignment.
M.bottom_windows = {
  {
    rule = { class = "app.minimeters.MiniMeters", name = "MiniMeters" },
    geometry = { x = 3995, y = 1687, width = 827, height = 245 },
  },
  {
    rule = { class = "app.minimeters.MiniMeters", name = "Stereometer" },
    geometry = { x = 4461, y = 1440, width = 361, height = 247 },
  },
  {
    rule = { class = "app.minimeters.MiniMeters", name = "Waveform" },
    geometry = { x = 3992, y = 1440, width = 467, height = 245 },
  },
  {
    rule = { class = "app.minimeters.MiniMeters", name = "Spectrogram" },
    geometry = { x = 4824, y = 1443, width = 294, height = 490 },
  },
  {
    rule = { class = "Rolling Sampler", instance = "Rolling Sampler" },
    geometry = { x = 3200, y = 1440, width = 787, height = 247 },
  },
}

-- Snap all bottom-monitor clients back to their defined coordinates.
-- Iterates every live client, matches against bottom_windows rules via
-- ruled.client.match(), and forces screen/tag/geometry assignment.
M.align_bottom_windows = function()
  local bottom_output = displays and displays["bottom"]
  local target_screen = bottom_output and bottom_output.screen
  if not target_screen then return end

  local target_tag = M.find_tag(target_screen, "minimeters")

  for _, c in ipairs(client.get()) do
    if c.valid then
      for _, item in ipairs(M.bottom_windows) do
        if ruled.client.match(c, item.rule) then
          if c.screen ~= target_screen then
            c:move_to_screen(target_screen)
          end
          if target_tag then
            c:tags({ target_tag })
          end
          c.floating = true
          c:geometry(item.geometry)
          break
        end
      end
    end
  end
end

-- Run align_bottom_windows immediately, then again at 0.5s and 1.5s to
-- handle the race where kanshi hasn't finished repositioning the Wisecoco
-- output yet when dpms::on fires.
M.schedule_bottom_realign = function()
  M.align_bottom_windows()
  for _, delay in ipairs({ 0.5, 1.5 }) do
    gears.timer.start_new(delay, function()
      M.align_bottom_windows()
      return false
    end)
  end
end

return M
