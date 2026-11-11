#!/usr/bin/env python3
"""Helper script for somewm withdrawn window widget.

Subcommands:
  list                 - prints `<wid>\t<title>` for each withdrawn window
  unwithdraw <wid>     - sends XMapRaised to restore the window
"""

import sys
import subprocess
import re
import ctypes

def list_withdrawn():
    try:
        out = subprocess.check_output(["xprop", "-root", "_NET_CLIENT_LIST"], timeout=1).decode()
    except Exception:
        return

    for wid in re.findall(r"0x[0-9a-fA-F]+", out):
        try:
            p = subprocess.check_output(["xprop", "-id", wid, "WM_STATE", "WM_NAME", "_NET_WM_NAME"], timeout=1).decode()
            if "window state: Withdrawn" in p:
                m = re.search(r'(?:_NET_WM_NAME|WM_NAME)\([^)]*\) = "(.*)"', p)
                title = m.group(1) if m else wid
                print(f"{wid}\t{title}")
        except Exception:
            pass

def unwithdraw(wid_str):
    try:
        wid = int(wid_str, 0)
    except ValueError:
        return

    x11 = ctypes.cdll.LoadLibrary("libX11.so.6")
    x11.XOpenDisplay.restype = ctypes.c_void_p
    x11.XMapRaised.argtypes = [ctypes.c_void_p, ctypes.c_ulong]
    x11.XFlush.argtypes = [ctypes.c_void_p]
    x11.XCloseDisplay.argtypes = [ctypes.c_void_p]

    d = x11.XOpenDisplay(None)
    if d:
        x11.XMapRaised(d, wid)
        x11.XFlush(d)
        x11.XCloseDisplay(d)

def main():
    if len(sys.argv) < 2:
        return
    cmd = sys.argv[1]
    if cmd == "list":
        list_withdrawn()
    elif cmd == "unwithdraw" and len(sys.argv) >= 3:
        unwithdraw(sys.argv[2])

if __name__ == "__main__":
    main()
