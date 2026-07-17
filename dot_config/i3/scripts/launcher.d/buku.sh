#!/usr/bin/env bash

register_module buku "b" filter

buku_init() {
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
}

buku_select() {
    local info="${ROFI_INFO:-}"
    case "$info" in
        open:*) open_target "${info#open:}" ;;
    esac
}
