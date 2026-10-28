local awful = require("awful")
local profile = require("profile")
local centerwork = require("layout_centerwork")
local persist = require("persist")

-- Enable jumping cursor to corner on tile resize
awful.layout.suit.tile.resize_jump_to_corner = true
awful.layout.suit.floating.resize_jump_to_corner = false

-------------
-- Layouts --
-------------

-- Renaming the shared layout objects is a global side effect: every consumer of
-- awful.layout.suit.* sees the new names, and the names are what gets persisted
-- per tag (persist.lua) and resolved again on reload.
local vsplit = awful.layout.suit.tile
vsplit.name = "vsplit"
local hsplit = awful.layout.suit.tile.top
hsplit.name = "hsplit"
local float = awful.layout.suit.floating
float.name = "float"

-- Table of layouts to cover with awful.layout.inc, order matters.
local layouts = {}
layouts.list = { vsplit, hsplit, float, centerwork }

-- Profile tag definitions name a layout; this resolves those names.
local layout_map = {
  vsplit     = vsplit,
  hsplit     = hsplit,
  float      = float,
  centerwork = centerwork,
}
layouts.by_name = layout_map

--------------------
-- Tag creation --
--------------------

-- Create the tags described by one profile tag definition. `tag_def` is either
-- a plain list of names, or { default_layout = <name>, tags = { ... } } whose
-- entries are strings/numbers (plain names) or tables
-- { name = ..., layout = ..., selected = ... }.
local function apply_tag_list(s, tag_def, fallback_layout)
  fallback_layout = fallback_layout or vsplit
  local tags_to_add = tag_def
  local default_layout = fallback_layout

  if type(tag_def) == "table" and tag_def.tags then
    tags_to_add = tag_def.tags
    if tag_def.default_layout and layout_map[tag_def.default_layout] then
      default_layout = layout_map[tag_def.default_layout]
    end
  end

  -- A definition may mark one tag as selected; otherwise the first tag is.
  local has_selected = false
  for _, item in ipairs(tags_to_add) do
    if type(item) == "table" and item.selected then
      has_selected = true
      break
    end
  end

  -- Names carry an "<index>:" prefix (matching the rename binding in
  -- keybindings.lua). Rule references resolve the base name, so "2:browser"
  -- still matches a rule asking for "browser" (see tags.find_tag).
  for i, item in ipairs(tags_to_add) do
    local is_tbl = type(item) == "table"
    local name = is_tbl and item.name or item
    local layout = (is_tbl and item.layout and layout_map[item.layout]) or default_layout
    local selected = (is_tbl and item.selected) or (not has_selected and i == 1) or false
    awful.tag.add(i .. ":" .. tostring(name), {
      layout   = layout,
      screen   = s,
      selected = selected,
    })
  end
end

local function resolve_tag_def(role)
  if not (profile and profile.tags) then return nil end
  return (role and profile.tags[role]) or profile.tags["middle"] or profile.tags["right"]
end

layouts.default_tags = function(s)
  local tag_def = resolve_tag_def(persist.role_of(s))
  if tag_def then
    apply_tag_list(s, tag_def, vsplit)
  else
    local names = {}
    for i = 1, 9 do
      names[i] = i .. ":" .. i
    end
    awful.tag(names, s, vsplit)
  end
end

return layouts
