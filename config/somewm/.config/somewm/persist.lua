-- Persisted window/tag cache.
--
-- On exit the live state is written to CACHE_PATH; on startup restore_windows()
-- turns the client records into ruled.client rules (or into claim groups, see
-- below) and restore_tags() rebuilds each screen's tags.

local awful = require("awful")
local gears = require("gears")
local ruled = require("ruled")

local tags = require("tags")
local profile = require("profile")

local M = {}

-- Cache location. SOMEWM_PERSIST_WINDOWS overrides it explicitly; a nested
-- test compositor (somewm-client test exports SOMEWM_TEST_NAME and
-- SOMEWM_TEST_STATE_DIR) keeps its cache in its own state directory, so it
-- cannot overwrite the live file when it exits or reloads. Otherwise the
-- config-dir file is used.
local CACHE_PATH = os.getenv("SOMEWM_PERSIST_WINDOWS")
    or (os.getenv("SOMEWM_TEST_NAME")
        and ((os.getenv("SOMEWM_TEST_STATE_DIR") or "/tmp") .. "/persist_windows"))
    or (os.getenv("HOME") .. "/.config/somewm/.persist_windows")

local SEP = "|||"

-- Serialized spelling of "no value": each record is a flat line, so a missing
-- field still needs a slot. Maps to nil on read, so callers never compare
-- against this sentinel.
local NIL = "nil"

-- Field names in write order. The record type is the first field on every line
-- and is split off before the rest is matched, so it is not listed here. The
-- last field (name) is greedy: tag names and window titles containing SEP
-- still parse.
local RECORDS = {
  tag = { "role", "index", "layout", "selected", "name" },
  client = { "role", "tag", "class", "instance", "floating",
             "x", "y", "width", "height", "name" },
}

local PATTERNS = {}
for kind, fields in pairs(RECORDS) do
  PATTERNS[kind] = "^" .. ("(.-)" .. SEP):rep(#fields - 1) .. "(.*)$"
end

local function encode_record(kind, values)
  local row = { kind }
  for _, field in ipairs(RECORDS[kind]) do
    row[#row + 1] = values[field] == nil and NIL or tostring(values[field])
  end
  return table.concat(row, SEP) .. "\n"
end

local function parse_record(kind, rest)
  local values = { rest:match(PATTERNS[kind]) }
  if not values[1] then return nil end
  local record = {}
  for i, field in ipairs(RECORDS[kind]) do record[field] = values[i] end
  return record
end

-- `x and nil or v` would return v: `true and nil` is nil, so the `or` wins.
local function opt(v)
  if v == NIL then return nil end
  return v
end

local function opt_num(v)
  if v == NIL then return nil end
  return tonumber(v)
end

local function flag(v) return v == "1" end

-- Raw cache fields to typed records: sentinels become nil, flags become
-- booleans, coordinates become numbers.
local DECODE = {
  tag = function(f)
    return {
      role = f.role,
      index = tonumber(f.index) or 0,
      layout = opt(f.layout),
      selected = flag(f.selected),
      name = f.name,
    }
  end,
  client = function(f)
    return {
      role = f.role,
      tag = f.tag,
      class = opt(f.class),
      instance = opt(f.instance),
      floating = flag(f.floating),
      x = opt_num(f.x),
      y = opt_num(f.y),
      width = opt_num(f.width),
      height = opt_num(f.height),
      name = opt(f.name),
    }
  end,
}

-- Parse CACHE_PATH into { clients = {...}, tags = { role = { rec, ... } } }.
-- Lines whose record type is unknown (including the old 4-field format) are
-- ignored.
local function read_cache()
  local data = { clients = {}, tags = {} }
  local f = io.open(CACHE_PATH, "r")
  if not f then return data end
  for line in f:lines() do
    local kind, rest = line:match("^(%w+)" .. SEP .. "(.*)$")
    local fields = kind and RECORDS[kind] and parse_record(kind, rest)
    if fields then
      local record = DECODE[kind](fields)
      if kind == "client" then
        table.insert(data.clients, record)
      else
        data.tags[record.role] = data.tags[record.role] or {}
        table.insert(data.tags[record.role], record)
      end
    end
  end
  f:close()
  return data
end

-- Cache fields for one client. `tag` is the first tag the client is reached
-- through, so a client visible on several tags is stored once, under the
-- earliest tag in `s.tags` order. Geometry is only recorded when floating.
local function client_fields(role, tag, c)
  -- `or nil` matters: `c.floating and c:geometry()` is `false` for tiled
  -- windows, and encode_record would serialize that as "false" coordinates.
  local g = c.floating and c:geometry() or nil
  return {
    role = role,
    tag = tag.name,
    class = c.class,
    instance = c.instance,
    floating = c.floating and "1" or "0",
    x = g and g.x,
    y = g and g.y,
    width = g and g.width,
    height = g and g.height,
    name = c.name,
  }
end

M.save_open_windows = function()
  local f = io.open(CACHE_PATH, "w")
  if not f then return end
  local seen = {}
  for role, output in pairs(displays) do
    local s = output.screen
    if s then
      for i, tag in ipairs(s.tags) do
        f:write(encode_record("tag", {
          role = role,
          index = i,
          layout = tag.layout and tag.layout.name or nil,
          selected = tag.selected and "1" or "0",
          name = tag.name,
        }))
      end
      for _, tag in ipairs(s.tags) do
        for _, c in ipairs(tag:clients()) do
          if not seen[c] then
            seen[c] = true
            f:write(encode_record("client", client_fields(role, tag, c)))
          end
        end
      end
    end
  end
  f:close()
end

-------------------
-- Pinned windows --
-------------------

-- Windows the profile pins to a fixed geometry on a display role
-- (profile.pinned_windows). rules.lua turns every spec into a spawn rule, and
-- align_pinned_windows re-applies the geometry after DPMS wake or a geometry
-- change on a screen that owns them. restore_windows below skips them: the
-- config owns their placement, not the cache.

local PIN_REALIGN_DELAYS = { 0.5, 2.5 }
local pinned = profile.pinned_windows or {}

-- First spec whose rule matches `c`, which may be a client or a cache record:
-- both carry class/instance/name.
local function pinned_spec(c)
  for _, spec in ipairs(pinned) do
    if ruled.client.match(c, spec.rule) then return spec end
  end
  return nil
end

-- Does `screen` own any pinned window? rc.lua asks this before realigning.
M.screen_has_pinned_windows = function(s)
  for _, spec in ipairs(pinned) do
    local output = displays[spec.role]
    if output and output.screen == s then return true end
  end
  return false
end

-- Snap every pinned client back to its defined coordinates, tag and screen.
M.align_pinned_windows = function()
  for _, spec in ipairs(pinned) do
    local output = displays[spec.role]
    local screen = output and output.screen
    if screen then
      local tag = spec.tag and tags.find_tag(screen, spec.tag) or nil
      for _, c in ipairs(client.get()) do
        if c.valid and ruled.client.match(c, spec.rule) then
          if c.screen ~= screen then c:move_to_screen(screen) end
          if tag then c:tags({ tag }) end
          c.floating = true
          c:geometry(spec.geometry)
        end
      end
    end
  end
end

-- Run align_pinned_windows immediately, then again at PIN_REALIGN_DELAYS to
-- handle the race where kanshi hasn't finished repositioning the output yet
-- when the event fires.
M.schedule_pinned_realign = function()
  M.align_pinned_windows()
  for _, delay in ipairs(PIN_REALIGN_DELAYS) do
    gears.timer.start_new(delay, function()
      M.align_pinned_windows()
      return false
    end)
  end
end

----------------------
-- Restore placement --
----------------------

-- Screen-relative placement described by one persisted record. `geometry` is
-- only present for floating windows that stored an x coordinate.
local function placement(entry)
  local floating = entry.floating and entry.x ~= nil
  return {
    role = entry.role,
    tag = entry.tag,
    floating = floating,
    geometry = floating and {
      x = entry.x, y = entry.y, width = entry.width, height = entry.height,
    } or nil,
  }
end

-- Apply one persisted record to a live client: screen, tag, floating geometry.
local function apply_entry(c, entry)
  local p = placement(entry)
  local output = displays[p.role]
  local screen = output and output.screen
  if not (c.valid and screen) then return end

  c:move_to_screen(screen)
  local tag = tags.find_tag(screen, p.tag)
  if tag then c:tags({ tag }) end

  if p.geometry then
    c.floating = true
    c:geometry(p.geometry)
  end
end

-- Grouping key shared by persisted records and live clients, so a record and
-- the window it describes always land in the same bucket.
local function class_key(class, instance)
  return (class or NIL) .. "|" .. (instance or NIL)
end

local groups = {}
local claimed = setmetatable({}, { __mode = "k" })
local CLAIM_TIMEOUT_S = 10
local CLAIM_TICK_S = 1

-- Ids of the placement rules appended below, so a rescan can drop the previous
-- pass before appending fresh ones (append_rule does not dedup).
local placement_rule_ids = {}

-- Windows that share a class+instance can only be told apart by title, and a
-- title is a poor key: ruled.client matches it once, when the window maps, so
-- it has to be identical at that instant. Firefox maps a window before its tab
-- title arrives, and titles legitimately change between sessions (an unread
-- count, a different page), which leaves those windows on whatever the class
-- rule selected. They therefore get no rule: each group is claimed here by
-- literal title, on every map and title change, until CLAIM_TIMEOUT_S has
-- passed and the remaining entries are handed out in mapping order.
local function claim_group(key, expired)
  local group = groups[key]
  if not group then return end

  -- First persisted entry per title wins.
  local by_name = {}
  for _, entry in ipairs(group.entries) do
    if not entry.claimed and entry.name and not by_name[entry.name] then
      by_name[entry.name] = entry
    end
  end

  -- A client with no title never matches: its absent title is stored as NIL,
  -- which is not a title any window can claim.
  local unclaimed = {}
  for _, c in ipairs(group.clients) do
    if c.valid and not claimed[c] then
      local entry = c.name and by_name[c.name]
      if entry then
        entry.claimed, claimed[c] = true, true
        apply_entry(c, entry)
      else
        unclaimed[#unclaimed + 1] = c
      end
    end
  end

  if not expired then return end

  -- Past the deadline the titles will not get any better: hand the rest out in
  -- mapping order so every window still returns to one of its app's saved tags
  -- and screens instead of all landing on the selected one.
  local remaining = {}
  for _, entry in ipairs(group.entries) do
    if not entry.claimed then remaining[#remaining + 1] = entry end
  end
  for n = 1, math.min(#unclaimed, #remaining) do
    remaining[n].claimed, claimed[unclaimed[n]] = true, true
    apply_entry(unclaimed[n], remaining[n])
  end
  groups[key] = nil
end

-- Entries that can produce placement: rows with a live screen, at least one of
-- class/instance, and not pinned by the profile (pinned windows are placed by
-- rules.lua, not restored from the cache). `key_count` counts class+instance
-- occurrences so the caller can spot ambiguous rows.
local function eligible_entries(clients, key_count)
  local eligible = {}
  for _, entry in ipairs(clients) do
    local output = displays[entry.role]
    if output and output.screen and (entry.class or entry.instance)
        and not pinned_spec(entry) then
      eligible[#eligible + 1] = entry
      local key = class_key(entry.class, entry.instance)
      key_count[key] = (key_count[key] or 0) + 1
    end
  end
  return eligible
end

-- A window whose class+instance is unique in the cache gets a ruled.client
-- rule and is placed the moment it maps. nil rule fields are simply absent, so
-- a rule can never become a catch-all: entries with neither class nor instance
-- were filtered out by eligible_entries.
--
-- The rule is one-shot: the first window it matches is placed, then the rule
-- removes itself. Without that, one cached terminal kept forcing every later
-- terminal onto the tag it was on before the last reload.
local function add_placement_rule(entry, index)
  local output = displays[entry.role]
  local id = "persisted_" .. index

  -- The client that consumed this rule. The property functions below run more
  -- than once per client (screen in the early pass, tag in the high-priority
  -- pass), so the gate answers true for it every time and false afterwards.
  local claimant = nil
  local function first(c)
    if claimant == nil then
      claimant = c
      -- Safe here: the properties for `c` are already built, so removing the
      -- rule only affects clients managed later.
      ruled.client.remove_rule(id)
    end
    return claimant == c
  end

  local properties = {
    screen = function(c)
      if not first(c) then return nil end
      return output and output.screen
    end,
    tag = function(c)
      if not first(c) then return nil end
      return tags.find_tag(c.screen, entry.tag)
    end,
  }
  local p = placement(entry)
  if p.geometry then
    properties.floating = true
    properties.x = p.geometry.x
    properties.y = p.geometry.y
    properties.width = p.geometry.width
    properties.height = p.geometry.height
  end
  ruled.client.append_rule {
    id = id,
    rule = { class = entry.class, instance = entry.instance },
    properties = properties,
  }
end

local function collect_group(key, entry)
  local group = groups[key]
  if not group then
    group = { entries = {}, clients = {}, elapsed_s = 0 }
    groups[key] = group
  end
  group.entries[#group.entries + 1] = entry
end

local function arm_claiming()
  client.connect_signal("request::manage", function(c)
    local key = class_key(c.class, c.instance)
    local group = groups[key]
    if not group then return end
    group.clients[#group.clients + 1] = c
    claim_group(key, false)
  end)
  client.connect_signal("property::name", function(c)
    claim_group(class_key(c.class, c.instance), false)
  end)

  -- Returning true keeps the timer running while a group is outstanding.
  gears.timer.start_new(CLAIM_TICK_S, function()
    local pending = false
    for key, group in pairs(groups) do
      group.elapsed_s = group.elapsed_s + CLAIM_TICK_S
      claim_group(key, group.elapsed_s >= CLAIM_TIMEOUT_S)
      if groups[key] then pending = true end
    end
    return pending
  end)
end

-- Rebuild the persisted placement from CACHE_PATH. Windows pinned by the
-- profile are skipped (see the pinned windows section); config owns them.
M.restore_windows = function()
  local data = read_cache()

  -- If the client list is rescanned this runs again; start from a clean slate
  -- so windows are never claimed against a stale entry twice, and drop the
  -- rules of the previous pass so a rescan cannot arm a second copy.
  for key in pairs(groups) do groups[key] = nil end
  for c in pairs(claimed) do claimed[c] = nil end
  for _, id in ipairs(placement_rule_ids) do ruled.client.remove_rule(id) end
  placement_rule_ids = {}

  local key_count = {}
  for index, entry in ipairs(eligible_entries(data.clients, key_count)) do
    local key = class_key(entry.class, entry.instance)
    if key_count[key] > 1 then
      collect_group(key, entry)
    else
      add_placement_rule(entry, index)
      placement_rule_ids[#placement_rule_ids + 1] = "persisted_" .. index
    end
  end

  if next(groups) then arm_claiming() end
end

-----------------
-- Tag restore --
-----------------

-- Reverse lookup: which display role owns `screen`.
local function role_of(screen)
  for role, output in pairs(displays) do
    if output.screen == screen then return role end
  end
  return nil
end

local LAYOUT_BY_NAME
local function layout_by_name()
  if not LAYOUT_BY_NAME then
    LAYOUT_BY_NAME = {}
    for _, layout in ipairs(require("layouts").list) do
      LAYOUT_BY_NAME[layout.name] = layout
    end
  end
  return LAYOUT_BY_NAME
end

-- Recreate screen `s`'s tags from the persisted tag records — names, order,
-- layout and selection — so runtime renames survive a reload. Returns false
-- when nothing is persisted for this screen's role, so the caller can fall
-- back to the profile defaults (layouts.default_tags).
M.restore_tags = function(s)
  local role = role_of(s)
  if not role then return false end

  local records = read_cache().tags[role]
  if not records or #records == 0 then return false end

  local layouts = require("layouts")
  table.sort(records, function(a, b) return a.index < b.index end)

  local any_selected = false
  local added = {}
  for i, rec in ipairs(records) do
    any_selected = any_selected or rec.selected
    added[i] = awful.tag.add(rec.name, {
      screen = s,
      layout = (rec.layout and layout_by_name()[rec.layout]) or layouts.list[1],
      selected = rec.selected,
    })
  end
  if not any_selected and added[1] then
    added[1].selected = true
  end
  return true
end

return M
