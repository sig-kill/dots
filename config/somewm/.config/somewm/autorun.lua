local awful = require("awful")
local profile = require("profile")
local GLib = require("lgi").GLib
local home = os.getenv("HOME") or GLib.get_home_dir()
local run_once = require("functions").run_once

local common_autorun = function()
  awful.spawn.with_shell("zsh-patina restart")
  run_once("wlsunset -l 37.7 -L -121.4 -t 3500", "wlsunset")
  awful.spawn.with_shell("sleep 1; dbus-update-activation-environment --systemd --all")
end

common_autorun()

if not profile.is_work then
  --awful.spawn.with_shell("pkill carla; carla ~/.config/carla/default.carxp")
  run_once("firefox-developer-edition", "firefox")
  run_once("steam")
  run_once("env QT_QPA_PLATFORM=xcb QT_QUICK_CONTROLS_STYLE=Material Plex", "Plex")
  run_once("vesktop")
  run_once("fooyin")
  run_once(home .. "/bin/rolling_sampler", "rolling_sampler")
  run_once(home .. "/bin/minimeters", "MiniMeters")
  run_once("sleep 3; raysession -s Default", "raysession")
end
