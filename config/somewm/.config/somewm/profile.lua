-- Active profile, selected by hostname.
--
-- The module returns one profile (see `profiles` below) to customize behavior based
-- on which profile is active.
--   terminal        - terminal emulator (rc.lua)
--   accel_speed     - pointer acceleration, optional (rc.lua)
--   tags            - tags per display role (layouts.lua)
--   pinned_windows  - windows pinned to a fixed geometry (rules.lua, persist.lua)
--   wibar_config    - wibar options per display role, absent = defaults (rc.lua)
--   autostart       - { command, process } pairs started once (autorun.lua)
--   hostname        - set by this module, for logs

local home = os.getenv("HOME") or ""

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

local profiles = {
  work = {
    terminal = "alacritty",
    accel_speed = -0.4,
    media_player = "%any",
    tags = {
      left = { "chat", "cider", "3", "4", "5", "6", "7", "8", "9" },
      middle = { "work", "2", "3", "4", "5", "6", "7", "8", "9" },
    },
  },
  personal = {
    terminal = "ghostty",
    media_player = "fooyin",
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
    wibar_config = {
      left   = { position = "top" },
      middle = { position = "top" },
      bottom = { position = "top", tray = false, clock = false },
      right  = { position = "bottom", tray = false, media = false },
    },
    -- Windows pinned to a fixed geometry: `role` is the display role that owns
    -- the window, `tag` the tag base name on that screen (see tags.find_tag).
    -- persist.lua turns these into spawn rules (via rules.lua) and re-applies
    -- them after DPMS wake or a geometry change; they are excluded from the
    -- window cache.
    pinned_windows = {
      {
        role = "bottom",
        tag = "minimeters",
        rule = { class = "app.minimeters.MiniMeters", name = "MiniMeters" },
        geometry = { x = 3995, y = 1707, width = 825, height = 245 },
      },
      {
        role = "bottom",
        tag = "minimeters",
        rule = { class = "app.minimeters.MiniMeters", name = "Stereometer" },
        geometry = { x = 4461, y = 1460, width = 361, height = 244 },
      },
      {
        role = "bottom",
        tag = "minimeters",
        rule = { class = "app.minimeters.MiniMeters", name = "Waveform" },
        geometry = { x = 3992, y = 1460, width = 467, height = 244 },
      },
      {
        role = "bottom",
        tag = "minimeters",
        rule = { class = "app.minimeters.MiniMeters", name = "Spectrogram" },
        geometry = { x = 4824, y = 1463, width = 294, height = 490 },
      },
      {
        role = "bottom",
        tag = "minimeters",
        rule = { class = "Rolling Sampler", instance = "Rolling Sampler" },
        geometry = { x = 3200, y = 1460, width = 787, height = 247 },
      },
    },
    -- { command, process to look for } — started once, if not already running.
    autostart = {
      { "firefox-developer-edition", "firefox" },
      { "steam" },
      { "env QT_QPA_PLATFORM=xcb QT_QUICK_CONTROLS_STYLE=Material Plex", "Plex" },
      { "vesktop" },
      { "fooyin" },
      { home .. "/bin/rolling_sampler", "rolling_sampler" },
      { home .. "/bin/minimeters", "MiniMeters" },
      { "sleep 3; raysession -s Default", "raysession" },
    },
  },
}

local function select_profile(hostname)
  if hostname:find("corp%.google%.com") then
    return profiles.work
  end
  return profiles.personal
end

local hostname = get_hostname()
local active = select_profile(hostname)
active.hostname = hostname

return active
