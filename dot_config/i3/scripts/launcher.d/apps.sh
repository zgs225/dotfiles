#!/usr/bin/env bash

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/rofi-launcher"
APPS_CACHE="$CACHE_DIR/apps.list"
APPS_MAP="$CACHE_DIR/apps.map"

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

apps_launch() {
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

apps_init() {
    printf '\0prompt\x1fLaunch\n'
    apps_rebuild_if_stale
    cat "$APPS_CACHE" 2>/dev/null || true
}

apps_select() {
    local info="$1"
    case "$info" in
        app:*)
            apps_launch "${info#app:}"
            return 0
            ;;
    esac
    return 1
}
