#!/bin/sh

run() {
  if ! pgrep -f "$1" ;
  then
    "$@"&
  fi
}

run "setxkbmap -option caps:super"
run "~/.screenlayout/layout.sh"
run "picom"
