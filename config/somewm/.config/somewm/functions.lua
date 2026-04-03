local awful = require('awful')
local gears = require('gears')
local ruled = require('ruled')

return {
  save_open_windows = function()
    local f = io.open(os.getenv("HOME") .. "/.config/somewm/.persist_windows", "w")
    if not f then return end
    for screen_role, output in pairs(displays) do
      if output.screen then
        for _, tag in ipairs(output.screen.tags) do
          for _, client in ipairs(tag:clients()) do
            f:write(string.format("%s|||%s|||%s|||%s\n",
              screen_role, tag.name, client.class or "nil", client.name or "nil"))
          end
        end
      end
    end
    f:close()
  end,

  restore_windows = function()
    local f = io.open(os.getenv("HOME") .. "/.config/somewm/.persist_windows", "r")
    if not f then return end
    for line in f:lines() do
      local screen_role, tag_name, class, name =
          line:match("^(.*)|||(.*)|||(.*)|||(.*)$")
      if class and displays[screen_role] and displays[screen_role].screen then
        local rule = {}
        if class ~= "nil" then rule.class = class end
        if name ~= "nil" then rule.name = name end

        ruled.client.append_rule {
          id = "persisted_" .. (class ~= "nil" and class or "")
              .. "_" .. (name ~= "nil" and name or ""),
          rule = rule,
          properties = {
            screen = displays[screen_role].screen,
            tag = tag_name,
          }
        }
      end
    end
    f:close()
  end
}
