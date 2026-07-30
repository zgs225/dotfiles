#!/usr/bin/env bash
# apply-tmux-palette.sh — Update tmux statusline colors to match a wezterm backdrop palette.
#
# Usage:
#   apply-tmux-palette.sh <bg> <fg> <dim> <accent> <accent2> <accent3> <warm> <alert> <border>
#
# Each argument is a hex color like #1a1b26.
#
# The script replaces colors in the running tmux format strings. It tracks the
# previous palette in a state file, and ALSO always replaces the hardcoded
# Tokyo Night defaults — so it works correctly even right after a tmux re-source
# (which resets the running formats back to Tokyo Night).

set -uo pipefail   # NOTE: no -e; conditional replacements must not abort the script

# Exit silently if tmux is not running
if ! tmux has-session 2>/dev/null; then
  exit 0
fi

STATE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/wezterm-tmux-palette"

# ── Arguments ────────────────────────────────────────────────────────────────
if [ $# -lt 9 ]; then
  echo "Usage: $0 <bg> <fg> <dim> <accent> <accent2> <accent3> <warm> <alert> <border>" >&2
  exit 1
fi

NEW_BG="$1";      NEW_FG="$2";     NEW_DIM="$3"
NEW_ACCENT="$4";  NEW_ACCENT2="$5"; NEW_ACCENT3="$6"
NEW_WARM="$7";    NEW_ALERT="$8";  NEW_BORDER="$9"

# ── Tokyo Night defaults (must match dot_tmux.conf.local) ────────────────────
TN_BG="#1a1b26";     TN_FG="#c0caf5";    TN_DIM="#a9b1d6"
TN_ACCENT="#7aa2f7"; TN_ACCENT2="#bb9af7"; TN_ACCENT3="#9ece6a"
TN_WARM="#e0af68";   TN_ALERT="#f7768e"; TN_BORDER="#414868"

# ── Load previous palette from state file (else = Tokyo Night) ───────────────
if [ -f "$STATE_FILE" ]; then
  # shellcheck disable=SC1090
  . "$STATE_FILE"
else
  OLD_BG="$TN_BG";     OLD_FG="$TN_FG";     OLD_DIM="$TN_DIM"
  OLD_ACCENT="$TN_ACCENT"; OLD_ACCENT2="$TN_ACCENT2"; OLD_ACCENT3="$TN_ACCENT3"
  OLD_WARM="$TN_WARM"; OLD_ALERT="$TN_ALERT"; OLD_BORDER="$TN_BORDER"
fi

# ── Build sed expression ─────────────────────────────────────────────────────
# add_replace OLD NEW TN  →  emit OLD→NEW, and TN→NEW when TN differs from both.
# All guards live INSIDE the function so a false condition never trips `set -e`
# (and we dropped -e anyway for belt-and-braces safety).
SED_EXPR=""
add_replace() {
  local old="$1" new="$2" tn="$3"
  if [ -n "$old" ] && [ "$old" != "$new" ] && [ "$old" != "default" ]; then
    SED_EXPR="${SED_EXPR}s|${old}|${new}|g;"
  fi
  if [ -n "$tn" ] && [ "$tn" != "$old" ] && [ "$tn" != "$new" ] && [ "$tn" != "default" ]; then
    SED_EXPR="${SED_EXPR}s|${tn}|${new}|g;"
  fi
}

add_replace "$OLD_BG"      "$NEW_BG"      "$TN_BG"
add_replace "$OLD_FG"      "$NEW_FG"      "$TN_FG"
add_replace "$OLD_DIM"     "$NEW_DIM"     "$TN_DIM"
add_replace "$OLD_ACCENT"  "$NEW_ACCENT"  "$TN_ACCENT"
add_replace "$OLD_ACCENT2" "$NEW_ACCENT2" "$TN_ACCENT2"
add_replace "$OLD_ACCENT3" "$NEW_ACCENT3" "$TN_ACCENT3"
add_replace "$OLD_WARM"    "$NEW_WARM"    "$TN_WARM"
add_replace "$OLD_ALERT"   "$NEW_ALERT"   "$TN_ALERT"
add_replace "$OLD_BORDER"  "$NEW_BORDER"  "$TN_BORDER"

# Nothing to do?
if [ -z "$SED_EXPR" ]; then
  exit 0
fi

# ── Apply to tmux format strings ─────────────────────────────────────────────
apply_format() {
  local option="$1"
  local scope="${2:-g}"
  local current=""
  if [ "$scope" = "gw" ]; then
    current=$(tmux show-option -gw "$option" 2>/dev/null | sed "s/^${option} //; s/^\"//; s/\"$//") || true
  else
    current=$(tmux show-option -g "$option" 2>/dev/null | sed "s/^${option} //; s/^\"//; s/\"$//") || true
  fi
  if [ -n "$current" ]; then
    local updated
    updated=$(printf '%s' "$current" | sed "$SED_EXPR")
    if [ "$scope" = "gw" ]; then
      tmux set-option -gw "$option" "$updated" 2>/dev/null || true
    else
      tmux set-option -g "$option" "$updated" 2>/dev/null || true
    fi
  fi
}

# Status bar formats
apply_format "status-left"
apply_format "status-right"

# Window status formats
apply_format "window-status-format" "gw"
apply_format "window-status-current-format" "gw"

# Global styles
apply_format "status-style"
apply_format "message-style"
apply_format "message-command-style"
apply_format "mode-style"
apply_format "pane-border-style"
apply_format "pane-active-border-style"
apply_format "display-panes-colour"
apply_format "display-panes-active-colour"

# Window styles
apply_format "window-status-style" "gw"
apply_format "window-status-current-style" "gw"
apply_format "window-status-activity-style" "gw"
apply_format "window-status-bell-style" "gw"
apply_format "window-status-last-style" "gw"
apply_format "window-style" "gw"
apply_format "window-active-style" "gw"

# ── Save new palette as state ────────────────────────────────────────────────
mkdir -p "$(dirname "$STATE_FILE")"
cat > "$STATE_FILE" << EOF
OLD_BG="$NEW_BG"
OLD_FG="$NEW_FG"
OLD_DIM="$NEW_DIM"
OLD_ACCENT="$NEW_ACCENT"
OLD_ACCENT2="$NEW_ACCENT2"
OLD_ACCENT3="$NEW_ACCENT3"
OLD_WARM="$NEW_WARM"
OLD_ALERT="$NEW_ALERT"
OLD_BORDER="$NEW_BORDER"
EOF
