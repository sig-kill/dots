-- Centered floating fsearch popup, toggled by Alt+Space.

local awful = require("awful")
local popup = require("widgets.popup")

return popup.new {
  id      = "fsearch",
  class   = { "io.github.cboxdoerfer.FSearch", "Fsearch", "fsearch" },
  cmd     = "fsearch",
  on_show = function()
    -- Re-trigger GApplication activate so fsearch grabs focus on its search entry.
    awful.spawn("fsearch", false)
  end,
}
