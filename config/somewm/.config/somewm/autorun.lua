-- Autostart, plus the run-once spawn helper it needs.
--
-- rc.lua requires this module early for run_once() (kanshi, before the theme is
-- initialised) and calls run() as its last statement, so the applications
-- started here map only after request::rules has registered the tag and
-- pinned-window rules.

local awful = require("awful")
local profile = require("profile")

local M = {}
local QUIET = " >/dev/null 2>&1"

local function ere_escape(s)
  return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?%{%}%|\\]", "\\%0"))
end

local function shell_quote(s)
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

-- Run `cmd` if and only if `proc` is not already running.
M.run_once = function(cmd, proc)
  local name = (proc or cmd:match("^%s*(%S+)")):match("[^/]+$")
  local exact_cmd = "pgrep -u \"$USER\" -x -- " .. shell_quote(name)
  local argv_cmd = "pgrep -u \"$USER\" -f -- "
      .. shell_quote("^([^ ]*/)?" .. ere_escape(name) .. "( |$)")
  awful.spawn.with_shell(exact_cmd .. QUIET .. " || " .. argv_cmd .. QUIET
      .. " || { " .. cmd .. " ; }")
end

--------------
-- Autostart --
--------------

local run_once = M.run_once

local function common_autorun()
  awful.spawn({ "zsh-patina", "restart" }, false)
  run_once("wlsunset -l 37.7 -L -121.4 -t 3500", "wlsunset")
end

M.run = function()
  common_autorun()

  -- Profile applications: { command, process } pairs.
  for _, app in ipairs(profile.autostart or {}) do
    run_once(app[1], app[2])
  end
end

return M
