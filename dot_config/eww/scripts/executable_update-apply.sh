#!/bin/bash
# Update widget launcher.
#
# Runs the full system upgrade in a wezterm window, teeing output to
# ~/.cache/eww/update.log so failures survive the window closing, then
# keeps the window open until the user acknowledges it.
#
# Usage:
#   update-apply.sh          # repo + AUR + local packages (paru -Syu)
#   update-apply.sh aur      # AUR only (paru -Sua)
#   update-apply.sh repo     # official repos only (pacman -Syu)
#
# "Local packages" are ones repacked outside both the repos and the AUR — today
# just arto-bin (eos-bootstrap: ansible/roles/packages/tasks/arto.yml). The
# update check sees them via /usr/local/bin/arto-check-update, and they are
# upgraded by /usr/local/bin/arto-upgrade, which runs that role.

CACHE_DIR="$HOME/.cache/eww"
LOG_FILE="$CACHE_DIR/update.log"
CHECK="$HOME/.config/eww/scripts/check-updates.sh"
mkdir -p "$CACHE_DIR"

mode="${1:-all}"

if command -v paru > /dev/null 2>&1; then
    case "$mode" in
        aur)  upgrade_cmd="paru -Sua --noconfirm" ;;
        repo) upgrade_cmd="paru -Sy --noconfirm && sudo pacman -Syu --noconfirm" ;;
        *)    upgrade_cmd="paru -Syu --noconfirm" ;;
    esac
    label="paru ($mode)"
else
    upgrade_cmd="sudo pacman -Syu --noconfirm"
    label="pacman (repo)"
fi

# Append the local packages when one is pending. Chained with && so a broken
# repo transaction leaves them alone; `arto-upgrade` escalates by itself.
if [ "$mode" != "repo" ] && command -v arto-upgrade > /dev/null 2>&1 \
        && [ -n "$(arto-check-update 2>/dev/null)" ]; then
    upgrade_cmd="$upgrade_cmd && arto-upgrade"
    label="$label + 本地包"
fi

if ! command -v wezterm > /dev/null 2>&1; then
    # No wezterm: run in-place so output still lands in the log.
    echo "===== $(date '+%F %T') $label =====" >> "$LOG_FILE"
    eval "$upgrade_cmd" 2>&1 | tee -a "$LOG_FILE"
    rc=${PIPESTATUS[0]}
    echo "[$label] exit=$rc" | tee -a "$LOG_FILE"
    "$CHECK"
    exit "$rc"
fi

echo "===== $(date '+%F %T') $label =====" >> "$LOG_FILE"

# Command executed inside the terminal window. Kept as a single quoted string
# because wezterm re-parses it via the shell.
read -r -d '' inner <<EOF
set -o pipefail
echo "=== $label @ $(date '+%F %T') ==="
echo "=== 命令: $upgrade_cmd ==="
{ ${upgrade_cmd}; } 2>&1 | tee -a "$LOG_FILE"
rc=\${PIPESTATUS[0]}
echo
if [ "\$rc" -eq 0 ]; then
    echo "=== 更新完成 (exit=0) ==="
else
    echo "=== 更新失败 (exit=\$rc) 见 $LOG_FILE ==="
fi
"$CHECK" >/dev/null 2>&1
echo "--- 按任意键关闭窗口 ---"
read -r -n 1 -s
EOF

wezterm start -- bash -c "$inner" &
disown
