local awful = require('awful')
awful.screen.set_auto_dpi_enabled(true)

local dpi                      = require('beautiful.xresources').apply_dpi

local theme                    = {}

-- Font
theme.font                     = "Hack Nerd Font 10"
theme.hotkeys_font             = "Hack Nerd Font 11"
theme.hotkeys_description_font = "Hack Nerd Font 11"
-- Colors
theme.fg_normal                = "#DED0B2"
theme.fg_focus                 = "#ACC783"
theme.fg_urgent                = "#F18284"
theme.bg_normal                = "#1A2227"
theme.bg_focus                 = "#2D373C"
theme.bg_urgent                = "#382025"
-- Border
theme.border_width             = dpi(2)
theme.useless_gap              = dpi(4)
theme.border_color_normal      = "#384348"
theme.border_color_marked      = "#F18284"
theme.border_color_active      = "#ACC783"
theme.taglist_fg_focus         = "#ACC783"
theme.taglist_bg_focus         = "#2D373C"
theme.tasklist_fg_focus        = "#ACC783"
theme.tasklist_bg_focus        = "#2D373C"
theme.music_progress_bg        = "#29392D"
theme.wibar_bg                 = "#101518"
theme.wibar_fg                 = "#DED0B2"
--theme.wibar_border_color  = "#134141"
--theme.wibar_border_width  = dpi(1)
theme.wibar_height             = dpi(20)

--theme.menu_bg             = "#060606"
--theme.menu_fg             = "#F6784F"
--theme.menu_height         = dpi(400)
--theme.menu_width          = dpi(300)
-- Layouts
local layout_icons_dir         = os.getenv("HOME") .. "/.config/somewm/theme/icons/layouts/"
theme.layout_centerwork        = layout_icons_dir .. "centerwork.svg"
theme.layout_vsplit            = layout_icons_dir .. "vsplit.svg"
theme.layout_hsplit            = layout_icons_dir .. "hsplit.svg"
theme.layout_float             = layout_icons_dir .. "float.svg"

theme.wallpaper_dir            = os.getenv("HOME") .. "/Pictures/Wallpapers"

return theme
