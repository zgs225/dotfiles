#!/usr/bin/env bash
# Eww bar launch — start daemon and open the bar.
#
# DPI-dependent sizes (bar height, icon/font sizes, workspace dots, popups) are
# baked into eww.yuck/eww.scss at `chezmoi apply` time via the shared
# .chezmoitemplates/eww-sizes partial, because eww 0.5.0 cannot resolve
# variables inside a window :geometry and GTK will not size empty boxes from
# runtime CSS variables. Re-run `chezmoi apply` after changing the display DPI.

exec 9>/tmp/eww-launch.lock
flock -n 9 || exit 0

eww kill 2>/dev/null

# Stop the bluetooth agent daemon from the previous session.
[ -f /tmp/eww-bt-agent.pid ] && kill "$(cat /tmp/eww-bt-agent.pid)" 2>/dev/null
rm -f /tmp/eww-bt-agent.pid

wait=0
while pgrep -f 'eww daemon' > /dev/null 2>&1 && [ $wait -lt 30 ]; do
  sleep 0.1
  wait=$((wait + 1))
done

if pgrep -f 'eww daemon' > /dev/null 2>&1; then
  pkill -9 -f 'eww daemon' 2>/dev/null
  sleep 0.2
fi

eww daemon 9>&-
# `eww daemon` double-forks and returns before its IPC socket is bound (GTK
# init + SCSS compile still pending). Wait for a ping so `eww open bar` below
# never hits the "can't connect → auto-spawn a second daemon" branch — that
# race is what produced the duplicate bar on cold boot.
for _ in $(seq 1 50); do
  eww ping >/dev/null 2>&1 && break
  sleep 0.1
done
eww update popup_open="none"
eww close popup-scrim 2>/dev/null
# Daemon restart orphans any bluetooth scan holder from the previous session —
# with no popup open nothing polls bt-devices.sh, so stop it explicitly here.
~/.config/eww/scripts/bt-scan.sh off 2>/dev/null
eww open bar

# Start the bluetooth pairing agent daemon (handles both active and passive
# SSP authentication via the eww bt-pair-dialog window). Close the launch lock
# fd first — otherwise nohup inherits it and holds the flock for the whole
# session, silently blocking every later launch.sh (i3 restart / reload).
nohup python3 ~/.config/eww/scripts/bt-agent-daemon.py >/dev/null 2>&1 9>&- &
echo $! > /tmp/eww-bt-agent.pid
