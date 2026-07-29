#!/usr/bin/env bash
# Robust show/hide toggle for the pi dropdown (bound to $mod+backslash).
#
# Handles every case:
#   - window visible on a workspace   -> hide it (move to scratchpad)
#   - window hidden in the scratchpad -> show it
#   - window gone (closed/killed)     -> relaunch (reattaches the persistent
#                                        pi-dropdown tmux session) and show it
#
# A bare `i3-msg scratchpad show` only works while the window exists; this
# wrapper recreates it when it doesn't, so the key always does something useful.
set -euo pipefail

CLASS="dropdown-pi"
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Print one of: none | visible | scratchpad
state() {
    i3-msg -t get_tree 2>/dev/null | CLASS="$CLASS" python3 -c '
import json, os, sys
cls = os.environ["CLASS"]
tree = json.load(sys.stdin)
result = "none"
def walk(node, in_scratch):
    global result
    if node.get("name") == "__i3_scratch":
        in_scratch = True
    props = node.get("window_properties") or {}
    if cls in (props.get("class"), props.get("instance")):
        result = "scratchpad" if in_scratch else "visible"
    for child in node.get("nodes", []) + node.get("floating_nodes", []):
        walk(child, in_scratch)
walk(tree, False)
print(result)
'
}

show() { i3-msg "[class=\"$CLASS\"] scratchpad show" >/dev/null; }

case "$(state)" in
    visible|scratchpad)
        # i3 toggles visible <-> scratchpad for a scratchpad-eligible window
        show
        ;;
    none)
        # (re)launch detached (setsid) so the new window survives even if this
        # script's process group is signalled; the for_window rule parks it
        # hidden in the scratchpad
        setsid "$HERE/pi-dropdown.sh" >/dev/null 2>&1 &
        disown 2>/dev/null || true
        s=""
        for _ in $(seq 1 100); do
            s=$(state)
            [ "$s" != "none" ] && break
            sleep 0.05
        done
        # show it, unless the for_window rule race left it already visible
        [ "$s" = "scratchpad" ] && show
        ;;
esac
