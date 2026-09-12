local awful = require("awful")
local profile = require("profile")
local GLib = require("lgi").GLib
local home = os.getenv("HOME") or GLib.get_home_dir()

local common_autorun = function()
  awful.spawn.with_shell("zsh-patina restart")
  awful.spawn.with_shell("pkill wlsunset; wlsunset -l 37.7 -L -121.4 -t 3500")
  awful.spawn.with_shell("sleep 1; dbus-update-activation-environment --systemd --all")
end

common_autorun()

if not profile.is_work then
  --awful.spawn.with_shell("pkill carla; carla ~/.config/carla/default.carxp")
  awful.spawn.single_instance("firefox-developer-edition")
  awful.spawn.single_instance("steam")
  awful.spawn.single_instance("pkill Plex; env QT_QPA_PLATFORM=xcb QT_QUICK_CONTROLS_STYLE=Material Plex")
  awful.spawn.single_instance("vesktop")
  awful.spawn.single_instance("fooyin")
  awful.spawn.with_shell("pkill Rolling\\ Sampler; " .. home .. "/bin/rolling_sampler")
  awful.spawn.with_shell("pkill MiniMeters; " .. home .. "/bin/minimeters")
  awful.spawn.with_shell("sleep 3; raysession -s Default")
end
