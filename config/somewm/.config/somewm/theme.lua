local awful = require('awful')
awful.screen.set_auto_dpi_enabled(true)

local dpi                      = require('beautiful.xresources').apply_dpi

local theme                    = {}

-- Font
theme.font                     = "Hack Nerd Font 10"
theme.hotkeys_font             = "Hack Nerd Font 11"
theme.hotkeys_description_font = "Hack Nerd Font 11"
-- Colors
theme.fg_normal                = "#A6A69C"
theme.fg_focus                 = "#FFA066"
theme.fg_urgent                = "#E82424"
theme.bg_normal                = "#161414"
theme.bg_focus                 = "#262323"
theme.bg_urgent                = "#31191B"
-- Border
theme.border_width             = dpi(1)
theme.useless_gap              = dpi(4)
theme.border_color_normal      = "#262323"
theme.border_color_marked      = "#E82424"
theme.border_color_active      = "#C0A36E"
theme.taglist_fg_focus         = "#FFA066"
theme.taglist_bg_focus         = "#262323"
theme.tasklist_fg_focus        = "#FFA066"
theme.tasklist_bg_focus        = "#262323"
theme.music_progress_bg        = "#312024"
theme.wibar_bg                 = "#161414"
theme.wibar_fg                 = "#DCD7BA"
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
