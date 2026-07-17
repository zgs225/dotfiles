#!/usr/bin/env bash

set -euo pipefail

THEME="$HOME/.config/rofi/launcher.rasi"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/rofi-launcher"
APPS_CACHE="$CACHE_DIR/apps.list"
APPS_MAP="$CACHE_DIR/apps.map"
SELF="$HOME/.config/i3/scripts/launcher.sh"

msg_row() {
    printf '%s\0icon\x1f%s\x1fnonselectable\x1ftrue\n' "$1" "${2:-dialog-information}"
}

row() {
    printf '%s\0icon\x1f%s\x1finfo\x1f%s\n' "$1" "$2" "$3"
}

chain() {
    local mode="$1" q="$2" filter="" hotkey=""
    case "$mode" in
        find|buku) filter="$q" ;;
    esac
    [ "$mode" = find ] && hotkey="Alt+Return"
    setsid -f bash -c \
        'while pgrep -x rofi >/dev/null 2>&1; do sleep 0.05; done; exec env LAUNCHER_Q="$1" rofi -show "$2" -modi "$2:$3 --mode-$2" -theme "$4" -filter "$5" ${6:+-kb-custom-1 "$6"}' \
        _ "$q" "$mode" "$SELF" "$THEME" "$filter" "$hotkey" >/dev/null 2>&1
}

open_target() {
    setsid -f xdg-open "$1" >/dev/null 2>&1
}

urlencode() {
    /usr/bin/python3 -c 'import sys,urllib.parse;print(urllib.parse.quote_plus(sys.argv[1]))' "$1"
}

apps_rebuild_if_stale() {
    local dirs=() d need=0
    dirs+=("${XDG_DATA_HOME:-$HOME/.local/share}/applications")
    local IFS=':'
    for d in ${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do
        dirs+=("$d/applications")
    done
    unset IFS
    [ -s "$APPS_CACHE" ] || need=1
    for d in "${dirs[@]}"; do
        [ -d "$d" ] || continue
        if [ "$d" -nt "$APPS_CACHE" ]; then need=1; fi
    done
    [ "$need" -eq 1 ] || return 0
    mkdir -p "$CACHE_DIR"
    DIRS="${dirs[*]}" OUT_LIST="$APPS_CACHE" OUT_MAP="$APPS_MAP" /usr/bin/python3 <<'PYEOF'
import os

dirs = os.environ["DIRS"].split(" ")
out_list = os.environ["OUT_LIST"]
out_map = os.environ["OUT_MAP"]

lang_full = os.environ.get("LANG", "").split(".")[0]
lang_short = lang_full.split("_")[0]
name_keys = [k for k in (f"Name[{lang_full}]", f"Name[{lang_short}]") if k != "Name[]"] + ["Name"]

seen = {}
order = []
for base in dirs:
    if not os.path.isdir(base):
        continue
    for root, _sub, files in os.walk(base):
        for f in sorted(files):
            if not f.endswith(".desktop"):
                continue
            path = os.path.join(root, f)
            rel = os.path.relpath(path, base)
            app_id = rel.replace("/", "-")[:-len(".desktop")]
            if app_id in seen:
                continue
            try:
                with open(path, encoding="utf-8", errors="replace") as fh:
                    lines = fh.read().splitlines()
            except OSError:
                continue
            section = False
            kv = {}
            for ln in lines:
                ln = ln.strip()
                if ln.startswith("["):
                    section = ln == "[Desktop Entry]"
                    continue
                if not section or "=" not in ln or ln.startswith("#"):
                    continue
                k, v = ln.split("=", 1)
                kv[k] = v
            if kv.get("Type", "Application") != "Application":
                continue
            if kv.get("NoDisplay", "false").lower() == "true":
                continue
            if kv.get("Hidden", "false").lower() == "true":
                continue
            tryexec = kv.get("TryExec")
            if tryexec:
                from shutil import which
                if os.path.sep not in tryexec and not which(tryexec):
                    continue
                if os.path.sep in tryexec and not os.path.exists(tryexec):
                    continue
            name = ""
            for k in name_keys:
                if kv.get(k):
                    name = kv[k]
                    break
            if not name:
                continue
            icon = kv.get("Icon") or "application-x-executable"
            term = "1" if kv.get("Terminal", "false").lower() == "true" else "0"
            seen[app_id] = (name, icon, term, kv.get("Exec", ""))
            order.append(app_id)

with open(out_list, "w", encoding="utf-8") as fl, open(out_map, "w", encoding="utf-8") as fm:
    for app_id in order:
        name, icon, term, execline = seen[app_id]
        fl.write(f"{name}\0icon\x1f{icon}\x1finfo\x1fapp:{app_id}\n")
        fm.write(f"{app_id}\t{term}\t{execline}\n")
PYEOF
}

launch_app() {
    local id="$1" line term execline
    line=$(grep -F -m1 "$id	" "$APPS_MAP" 2>/dev/null || true)
    term=$(printf '%s' "$line" | cut -f2)
    execline=$(printf '%s' "$line" | cut -f3-)
    if [ "$term" = "1" ] && [ -n "$execline" ]; then
        execline=$(printf '%s' "$execline" | sed 's/%%/%/g; s/%[a-zA-Z]//g')
        setsid -f wezterm -e sh -c "$execline" >/dev/null 2>&1
    else
        setsid -f gtk-launch "$id" >/dev/null 2>&1
    fi
}

mode_main() {
    if [ "$#" -eq 0 ]; then
        printf '\0prompt\x1fLaunch\n'
        apps_rebuild_if_stale
        cat "$APPS_CACHE" 2>/dev/null || true
        return 0
    fi
    local input="$1" info="${ROFI_INFO:-}"
    case "$info" in
        app:*)
            launch_app "${info#app:}"
            return 0
            ;;
    esac
    case "$input" in
        "find "*|"find")
            chain find "${input#find }" ;;
        "g "*|"g")
            local q="${input#g }"
            [ "$q" = "g" ] && q=""
            [ -n "$q" ] && open_target "https://www.google.com/search?q=$(urlencode "$q")"
            ;;
        "= "*|"=")
            chain calc "${input#= }" ;;
        "b "*|"b")
            chain buku "${input#b }" ;;
        *)
            setsid -f bash -c 'while pgrep -x rofi >/dev/null 2>&1; do sleep 0.05; done; exec rofi -show drun -filter "$1" -theme "$2"' _ "$input" "$THEME" >/dev/null 2>&1 ;;
    esac
}

mode_find() {
    if [ "$#" -eq 0 ]; then
        printf '\0prompt\x1fFind\n'
        printf '\0message\x1fEnter = open; Alt+Enter = open folder; Enter on empty result = new search\n'
        printf '\0use-hot-keys\x1ftrue\n'
        local q="${LAUNCHER_Q:-}"
        if ! command -v fd >/dev/null 2>&1; then
            msg_row "fd not installed — sudo pacman -S fd" dialog-warning
            return 0
        fi
        if [ -z "$q" ]; then
            msg_row "Usage: find <name>"
            return 0
        fi
        local results
        results=$(timeout 5 fd -H -F --max-results 5000 \
            --exclude .git --exclude .cache --exclude node_modules --exclude .local/share/Trash \
            -- "$q" "$HOME" 2>/dev/null || true)
        if [ -z "$results" ]; then
            msg_row "No matches for: $q (press Enter to retry)" dialog-information
            return 0
        fi
        local p display
        while IFS= read -r p; do
            display="${p/#$HOME/\~}"
            if [ -d "$p" ]; then
                row "$display" folder "open:$p"
            else
                row "$display" text-x-generic "open:$p"
            fi
        done <<< "$results"
        return 0
    fi
    local input="$1" info="${ROFI_INFO:-}" retv="${ROFI_RETV:-1}"
    case "$info" in
        open:*)
            local p="${info#open:}"
            if [ "$retv" = "10" ]; then
                [ -d "$p" ] || p="${p%/*}"
            fi
            open_target "$p" ;;
        *)
            [ -n "$input" ] && chain find "$input" ;;
    esac
}

mode_calc() {
    if [ "$#" -eq 0 ]; then
        printf '\0prompt\x1fCalc\n'
        printf '\0no-custom\x1ftrue\n'
        local q="${LAUNCHER_Q:-}"
        if [ -z "$q" ]; then
            msg_row "Usage: = <expression>   (bc -l syntax)"
            return 0
        fi
        local res
        if ! res=$(printf '%s\n' "scale=6; $q" | bc -l 2>/dev/null); then
            msg_row "Invalid expression: $q" dialog-error
            return 0
        fi
        [ -z "$res" ] && { msg_row "Invalid expression: $q" dialog-error; return 0; }
        res=$(printf '%s' "$res" | sed '/\./ s/0*$//; s/\.$//; s/^\./0./; s/^-\./-0./')
        row "$q = $res" accessories-calculator "copy:$res"
        return 0
    fi
    local info="${ROFI_INFO:-}"
    case "$info" in
        copy:*)
            printf '%s' "${info#copy:}" | xclip -selection clipboard >/dev/null 2>&1
            command -v notify-send >/dev/null 2>&1 && \
                setsid -f notify-send "Calculator" "Copied: ${info#copy:}" >/dev/null 2>&1
            ;;
    esac
}

mode_buku() {
    if [ "$#" -eq 0 ]; then
        printf '\0prompt\x1fBookmark\n'
        printf '\0no-custom\x1ftrue\n'
        if ! command -v buku >/dev/null 2>&1; then
            msg_row "buku not installed — yay -S buku" dialog-warning
            return 0
        fi
        local json
        json=$(timeout 5 buku --nostdin --np --sreg . --json </dev/null 2>/dev/null || true)
        case "$json" in "["*) ;; *) json="" ;; esac
        if [ -z "$json" ] || [ "$json" = "[]" ]; then
            msg_row "No bookmarks in buku — import with: buku --ai" dialog-information
            return 0
        fi
        printf '%s' "$json" | /usr/bin/python3 -c '
import sys, json
for b in json.load(sys.stdin):
    url = b.get("uri") or b.get("url") or ""
    if not url:
        continue
    title = (b.get("title") or "").strip() or url
    print(title + "  —  " + url + "\0icon\x1fweb-browser\x1finfo\x1fopen:" + url)
'
        return 0
    fi
    local info="${ROFI_INFO:-}"
    case "$info" in
        open:*) open_target "${info#open:}" ;;
    esac
}

case "${1:-}" in
    "")
        exec rofi -show launcher -modi "launcher:$SELF --mode-main" -theme "$THEME"
        ;;
    --mode-main) shift; mode_main "$@" ;;
    --mode-find) shift; mode_find "$@" ;;
    --mode-calc) shift; mode_calc "$@" ;;
    --mode-buku) shift; mode_buku "$@" ;;
    *) echo "unknown args: $*" >&2; exit 1 ;;
esac
