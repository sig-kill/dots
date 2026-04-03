local awful = require('awful')
awful.screen.set_auto_dpi_enabled(true)

local dpi                      = require('beautiful.xresources').apply_dpi

local theme                    = {}

-- Font
theme.font                     = "Hack Nerd Font 10"
theme.hotkeys_font             = "Hack Nerd Font 11"
theme.hotkeys_description_font = "Hack Nerd Font 11"
-- Colors
theme.fg_normal                = "#D7D7D7"
theme.fg_focus                 = "#F6784F"
theme.fg_urgent                = "#CC9393"
theme.bg_normal                = "#060606"
theme.bg_focus                 = "#060606"
theme.bg_urgent                = "#2A1F1E"
-- Border
theme.border_width             = dpi(1)
theme.useless_gap              = dpi(4)
theme.border_color_normal      = "#0E0E0E"
theme.border_color_marked      = "#8E0E0E"
theme.border_color_active      = "#93f69f"
theme.taglist_fg_focus         = "#F6784F"
theme.taglist_bg_focus         = "#060606"
theme.tasklist_fg_focus        = "#F6784F"
theme.tasklist_bg_focus        = "#060606"
theme.wibar_bg                 = "#282828"
theme.wibar_fg                 = "#EBDBB2"
--theme.wibar_border_color  = "#134141"
--theme.wibar_border_width  = dpi(1)
theme.wibar_height             = dpi(20)

--theme.menu_bg             = "#060606"
--theme.menu_fg             = "#F6784F"
--theme.menu_height         = dpi(400)
--theme.menu_width          = dpi(300)
-- Layouts
--theme.layout_machi          = machi.get_icon()
--theme.layout_centerwork     = gears.filesystem.get_dir('config') .. '/bling/icons/layouts/centered.png'
-- local recolor             = gears.color.recolor_image
-- theme.layout_tile         = recolor(themes_path .. "default/layouts/tilew.png", "#D7D7D7"

local wallpapers_path          = os.getenv("HOME") .. "/Pictures/Wallpapers/"
theme.wallpaper                = wallpapers_path .. "wallhaven-x1z2jz.jpg"

return theme
