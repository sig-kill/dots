-- Centered floating notes popup (Kate), toggled by Super+`.

local popup = require("widgets.popup")

return popup.new {
  id    = "notes",
  class = "org.kde.kate",
  cmd   = "kate",
}
