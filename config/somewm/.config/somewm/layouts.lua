-- local machi = require("layout-machi")
-- local lain = require("lain")
local awful = require("awful")

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
  change_layout_name(awful.layout.suit.floating, "float")
}
layouts.list = layouts_list

layouts.default_tags = function(s)
  if s.output == displays["left"] then
    awful.tag(
      { "plex", "music", "3", "4", "5", "6", "7", "8", "9" },
      s, layouts_list[1]
    )
  elseif s.output == displays["middle"] then
    awful.tag.add("steam", {
      layout = layouts_list[3],
      screen = s,
    })
    awful.tag.add("browser", {
      layout = layouts_list[1],
      screen = s,
      selected = true
    })
    for tagname = 3, 8 do
      awful.tag.add(tostring(tagname), {
        layout = layouts_list[1],
        screen = s,
      })
    end
    awful.tag.add("carla", {
      layout = layouts_list[3],
      screen = s,
    })
  elseif s.output == displays["right"] then
    awful.tag(
      { "discord", "2", "3", "4", "5", "6", "7", "8", "9" },
      s, awful.layout.layouts[2]
    )
  elseif s.output == displays["bottom"] then
    awful.tag.add("minimeters", {
      layout = layouts_list[3],
      screen = s,
      selected = true,
    })
    for tagname = 2, 9 do
      awful.tag.add(tostring(tagname), {
        layout = layouts_list[1],
        screen = s,
      })
    end
  end
end

return layouts
