local awful = require("awful")
local profile = require("profile")
local centerwork = require("layout_centerwork")

-- Disable jumping cursor to corner on resize
awful.layout.suit.tile.resize_jump_to_corner = false
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
    if type(item) == "string" or type(item) == "number" then
      awful.tag.add(i .. ":" .. tostring(item), {
        layout   = default_layout,
        screen   = s,
        selected = (not has_selected and i == 1) or false,
      })
    elseif type(item) == "table" then
      local layout = (item.layout and layout_map[item.layout]) or item.layout or default_layout
      awful.tag.add(i .. ":" .. tostring(item.name), {
        layout   = layout,
        screen   = s,
        selected = item.selected or (not has_selected and i == 1) or false,
      })
    end
  end
end

-- Which display role owns `screen`. Mirrors persist.role_of, which cannot be
-- shared: persist.lua requires this module.
local function role_of(s)
  if not displays then return nil end
  for role, output in pairs(displays) do
    if s.output and s.output == output then return role end
  end
  return nil
end

-- Profile tag definitions are keyed by display role, with fallbacks for roles
-- that have no entry of their own. The "default" and "center" keys are unused
-- today: no profile defines the former, and no output maps to the latter role.
local function resolve_tag_def(role)
  if not (profile and profile.tags) then return nil end

  if role then
    local tag_def = profile.tags[role]
    if tag_def then return tag_def end
    if role == "middle" or role == "center" then
      return profile.tags["middle"] or profile.tags["center"]
    elseif role == "right" then
      return profile.tags["right"] or profile.tags["middle"] or profile.tags["center"]
    end
  end
  return profile.tags["default"] or profile.tags["middle"] or profile.tags["center"]
      or profile.tags["right"]
end

layouts.default_tags = function(s)
  local tag_def = resolve_tag_def(role_of(s))
  if type(tag_def) == "function" then
    tag_def(s)
  elseif tag_def then
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
