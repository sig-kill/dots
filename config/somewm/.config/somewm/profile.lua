local function get_hostname()
  local f = io.open("/proc/sys/kernel/hostname", "r")
  if f then
    local name = f:read("*l")
    f:close()
    if name and #name > 0 then
      return name:gsub("%s+", "")
    end
  end
  return ""
end

local hostname = get_hostname()
local is_work = hostname:find("corp%.google%.com") ~= nil

local profiles = {
  work = {
    name = "work",
    terminal = "alacritty",
    accel_speed = -0.4,
    tags = {
      left = { "chat", "cider", "3", "4", "5", "6", "7", "8", "9" },
      middle = { "work", "2", "3", "4", "5", "6", "7", "8", "9" },
      center = { "work", "2", "3", "4", "5", "6", "7", "8", "9" },
      right = { "work", "2", "3", "4", "5", "6", "7", "8", "9" },
    },
  },
  personal = {
    name = "personal",
    terminal = "ghostty",
    tags = {
      left = { "plex", "music", "3", "4", "5", "6", "7", "8", "9" },
      middle = {
        { name = "steam", layout = "float" },
        { name = "browser", layout = "vsplit", selected = true },
        "3", "4", "5", "6", "7", "8",
        { name = "carla", layout = "float" },
      },
      right = {
        default_layout = "hsplit",
        tags = { "discord", "2", "3", "4", "5", "6", "7", "8", "9" },
      },
      bottom = {
        { name = "minimeters", layout = "float", selected = true },
        "2", "3", "4", "5", "6", "7", "8", "9",
      },
    },
  },
}

local active = is_work and profiles.work or profiles.personal
active.hostname = hostname
active.is_work = is_work

return active
