#!/usr/bin/env bash
# Offline regression test for the WezTerm tab-title remote indicator.
#
# What it does
#   * Drives the deployed WezTerm Lua config with `wezterm --config-file … ls-fonts`,
#     i.e. the real wezterm runtime, real `wezterm.nerdfonts` glyph table, real
#     `format-tab-title` handler — but no GUI and no ssh.
#   * Runs scripts/tests/wezterm-tab-title-test.lua, which asserts:
#       a) ssh-family argv parsing: destination is the first positional, so
#          `-J <jump>`, `-p 2222`, `-i <key>` and `host <remote cmd>` all resolve
#          to the right host, and `-p22` (attached value) still works
#       b) mosh / autossh are recognised; zsh, kubectl exec, docker exec are not
#       c) host -> os mapping (verified against /etc/os-release on the hosts) and
#          the fallback to md_ssh for anything unknown
#       d) the exact rendered cells: [jie-yin ▎] [glyph] [host], no glyph local
#       e) pane.title == nil and pane.foreground_process_name == nil, which is
#          what real panes actually return (both were live-found bugs)
#       f) max_width still bounds the label once a glyph is added
#       g) the per-pane cache: TTL hit, probe() bypass, and "keep the last
#          identity while the pane's process is unreadable, clear it as soon as a
#          non-ssh process is read"
#
# Exit codes: 0 all checks passed, 1 an assertion failed, 2 wezterm is missing.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
lua_test="$here/wezterm-tab-title-test.lua"
config_dir="${WEZTERM_CONFIG_DIR:-$HOME/.config/wezterm}"

command -v wezterm >/dev/null || { echo "SKIP: wezterm not installed" >&2; exit 2; }
[ -f "$config_dir/wezterm.lua" ] || { echo "FAIL: no config at $config_dir" >&2; exit 1; }

# The Lua report is emitted through error(), so it arrives on stderr and the
# process exits non-zero by design.
raw="$(WEZTERM_CONFIG_DIR="$config_dir" wezterm --config-file "$lua_test" ls-fonts 2>&1 || true)"

report="$(printf '%s\n' "$raw" | grep -E '^(PASS|FAIL) |^ALL CHECKS|CHECK\(S\) FAILED' || true)"

if [ -z "$report" ]; then
    echo "FAIL: the test harness produced no report" >&2
    printf '%s\n' "$raw" | tail -20 >&2
    exit 1
fi

printf '%s\n' "$report"

if printf '%s\n' "$report" | grep -q 'ALL CHECKS PASSED'; then
    printf '\n%s\n' "tab-title remote indicator: OK"
    exit 0
fi

printf '\n%s\n' "tab-title remote indicator: FAILED" >&2
exit 1
