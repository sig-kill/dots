-- local machi = require("layout-machi")
-- local lain = require("lain")
local awful = require("awful")
local profile = require("profile")
local centerwork = require("layout_centerwork")

-- Disable jumping cursor to corner on resize
awful.layout.suit.tile.resize_jump_to_corner = false
awful.layout.suit.floating.resize_jump_to_corner = false

-- Table of layouts to cover with awful.layout.inc, order matters.
local layouts = {}

local change_layout_name = function(l, name)
  local layout = l
  layout.name = name
  return layout
end
local layouts_list = {
  change_layout_name(awful.layout.suit.tile, "vsplit"),
  change_layout_name(awful.layout.suit.tile.top, "hsplit"),
  change_layout_name(awful.layout.suit.floating, "float"),
  centerwork,
}
layouts.list = layouts_list

local layout_map = {
  vsplit     = layouts_list[1],
  hsplit     = layouts_list[2],
  float      = layouts_list[3],
  centerwork = centerwork,
}

local function apply_tag_list(s, tag_def, fallback_layout)
  fallback_layout = fallback_layout or layouts_list[1]
  local tags_to_add = tag_def
  local default_layout = fallback_layout

  if type(tag_def) == "table" and tag_def.tags then
    tags_to_add = tag_def.tags
    if tag_def.default_layout and layout_map[tag_def.default_layout] then
      default_layout = layout_map[tag_def.default_layout]
    end
  end

  local has_selected = false
  for _, item in ipairs(tags_to_add) do
    if type(item) == "table" and item.selected then
      has_selected = true
      break
    end
  end

  for i, item in ipairs(tags_to_add) do
    if type(item) == "string" or type(item) == "number" then
      awful.tag.add(tostring(item), {
        layout   = default_layout,
        screen   = s,
        selected = (not has_selected and i == 1) or false,
      })
    elseif type(item) == "table" then
      local l = (item.layout and layout_map[item.layout]) or item.layout or default_layout
      awful.tag.add(tostring(item.name), {
        layout   = l,
        screen   = s,
        selected = item.selected or (not has_selected and i == 1) or false,
      })
    end
  end
end

layouts.default_tags = function(s)
  local role = nil
  if displays then
    for r, o in pairs(displays) do
      if s.output and s.output == o then
        role = r
        break
      end
    end
  end

  local tag_def = nil
  if profile and profile.tags then
    if role then
      tag_def = profile.tags[role]
      if not tag_def then
        if role == "middle" or role == "center" then
          tag_def = profile.tags["middle"] or profile.tags["center"]
        elseif role == "right" then
          tag_def = profile.tags["right"] or profile.tags["middle"] or profile.tags["center"]
        end
      end
    end
    if not tag_def then
      tag_def = profile.tags["default"] or profile.tags["middle"] or profile.tags["center"] or profile.tags["right"]
    end
  end

  if type(tag_def) == "function" then
    tag_def(s)
  elseif tag_def then
    apply_tag_list(s, tag_def, layouts_list[1])
  else
    awful.tag(
      { "1", "2", "3", "4", "5", "6", "7", "8", "9" },
      s, layouts_list[1]
    )
  end
end

return layouts
