#!/usr/bin/env bash

# Bitwarden module backed by rbw. Enter copies the primary secret,
# Alt+Return opens a per-entry action menu (rofi multi-level script mode).
# Secrets never appear in rows, ROFI_INFO or process arguments: rows carry
# only entry UUIDs; copies flow rbw -> shell variable -> xclip, and the
# clipboard is cleared unconditionally 30s later. The master password is
# entered via pinentry-rofi straight into rbw — this script never sees it.
# First-time setup is terminal-only: rbw register && rbw sync.

register_module bw "bw" filter "Alt+Return" "密码"

BW_CLEAR_AFTER=30

bw_headers() {
    printf '\0prompt\x1f%s\n' "$1"
    printf '\0no-custom\x1ftrue\n'
    printf '\0use-hot-keys\x1ftrue\n'
}

bw_notify() {
    command -v notify-send >/dev/null 2>&1 || return 0
    setsid -f notify-send -i "${2:-dialog-password}" "Bitwarden" "$1" >/dev/null 2>&1 || true
}

bw_to_clipboard() {
    printf '%s' "$1" | xclip -selection clipboard >/dev/null 2>&1
    # Unconditional timed clear: no secret (or its hash) on any command line.
    setsid -f bash -c \
        'sleep "$1"; printf "" | xclip -selection clipboard >/dev/null 2>&1' \
        _ "$BW_CLEAR_AFTER" >/dev/null 2>&1
}

# Run unlock/sync after rofi has fully closed (pinentry steals focus
# otherwise), then reopen the bw modi with the original filter preserved.
# The wait loop must run BEFORE rbw spawns pinentry-rofi, whose window
# also counts as a rofi process.
bw_bg_flow() {
    local action="$1" q="${LAUNCHER_Q:-}"
    setsid -f bash -c '
        action="$1"; q="$2"; self="$3"; theme="$4"; hotkey="$5"
        while pgrep -x rofi >/dev/null 2>&1; do sleep 0.05; done
        ok=""
        case "$action" in
            unlock)
                # login no-ops when already authenticated; on a fresh
                # device it performs the initial login (pinentry prompts)
                # so the unlock row works for first-time setup too.
                if rbw login </dev/null >/dev/null 2>&1 && rbw unlock </dev/null >/dev/null 2>&1; then
                    rbw sync </dev/null >/dev/null 2>&1 || true
                    notify-send -i dialog-password "Bitwarden" "保险库已解锁" >/dev/null 2>&1 || true
                    ok=1
                else
                    notify-send -i dialog-error "Bitwarden" "解锁失败或已取消" >/dev/null 2>&1 || true
                fi
                ;;
            sync)
                if rbw sync </dev/null >/dev/null 2>&1; then
                    notify-send -i view-refresh "Bitwarden" "同步完成" >/dev/null 2>&1 || true
                    ok=1
                else
                    notify-send -i dialog-error "Bitwarden" "同步失败（网络或会话问题）" >/dev/null 2>&1 || true
                fi
                ;;
        esac
        [ -n "$ok" ] || exit 0
        exec env LAUNCHER_Q="$q" rofi -show bw -modi "bw:$self --mod bw" \
            -theme "$theme" -filter "$q" -kb-cancel "Escape,Alt+space" \
            ${hotkey:+-kb-custom-1 "$hotkey"}
    ' _ "$action" "$q" "$SELF" "$THEME" "${MOD_HOTKEY[bw]}" >/dev/null 2>&1
}

bw_init() {
    bw_headers "密码"
    if ! command -v rbw >/dev/null 2>&1; then
        msg_row "未安装 rbw — sudo pacman -S rbw" dialog-warning
        return 0
    fi
    if ! timeout 5 rbw unlocked </dev/null >/dev/null 2>&1; then
        printf '\0message\x1f保险库已锁定\n'
        row "解锁保险库…" dialog-password "unlock"
        return 0
    fi
    printf '\0message\x1f回车=复制密码；Alt+回车=更多操作\n'
    local json
    json=$(timeout 10 rbw list --raw </dev/null 2>/dev/null || true)
    case "$json" in
        \[*) ;;
        *) json="" ;;
    esac
    if [ -z "$json" ] || [ "$json" = "[]" ]; then
        msg_row "本地数据库为空 — 请执行底部「同步」" dialog-information
    else
        printf '%s' "$json" | /usr/bin/python3 -c '
import sys, json
for it in json.load(sys.stdin):
    iid = it.get("id") or ""
    if not iid:
        continue
    name = it.get("name") or "(未命名)"
    user = it.get("user") or ""
    display = name + " — " + user if user else name
    print(display + "\0icon\x1fdialog-password\x1finfo\x1fentry:" + iid)
'
    fi
    row "锁定保险库" changes-prevent "lock"
    row "同步" view-refresh "sync"
}

bw_actions() {
    local id="$1" display="$2"
    bw_headers "${display%% — *}"
    printf '\0message\x1f选择要复制的内容\n'
    local json
    json=$(timeout 5 rbw get --raw "$id" </dev/null 2>/dev/null || true)
    case "$json" in
        \{*) ;;
        *) json="" ;;
    esac
    if [ -z "$json" ]; then
        msg_row "读取条目失败" dialog-error
        row "← 返回列表" go-previous "back"
        return 0
    fi
    printf '%s' "$json" | /usr/bin/python3 -c '
import sys, json

it = json.load(sys.stdin)
iid = it.get("id") or ""
# rbw serializes DecryptedData untagged: data is the bare inner struct
# ({"username":..., "password":..., ...} for Login, null for SecureNote).
# Discriminate the entry type by which fields are present.
data = it.get("data")
body = data if isinstance(data, dict) else {}
if not body:
    kind = "SecureNote"
elif "cardholder_name" in body or "number" in body:
    kind = "Card"
elif "first_name" in body or "last_name" in body or "title" in body:
    kind = "Identity"
elif "public_key" in body or "private_key" in body:
    kind = "SshKey"
else:
    kind = "Login"

primary = {"Login": "复制密码", "Card": "复制卡号", "SecureNote": "复制备注",
           "Identity": "复制姓名", "SshKey": "复制公钥"}.get(kind, "复制密码")

def row(text, info, icon):
    print(f"{text}\0icon\x1f{icon}\x1finfo\x1f{info}")

row(primary, f"copy:pass:{iid}", "dialog-password")
user = body.get("username")
if user:
    row(f"复制用户名 — {user}", f"copy:user:{iid}", "dialog-information")
if body.get("totp"):
    row("复制 TOTP", f"copy:totp:{iid}", "dialog-password")
for u in (body.get("uris") or []):
    uri = u.get("uri") if isinstance(u, dict) else u
    if uri:
        row(f"复制 URI — {uri}", f"copy:uri:{uri}", "web-browser")
row("← 返回列表", "back", "go-previous")
'
}

bw_copy() {
    local kind="$1" ref="$2" value="" rc=0
    case "$kind" in
        pass) value=$(timeout 5 rbw get "$ref" </dev/null 2>/dev/null)            || rc=$? ;;
        user) value=$(timeout 5 rbw get -f username "$ref" </dev/null 2>/dev/null) || rc=$? ;;
        totp) value=$(timeout 5 rbw code "$ref" </dev/null 2>/dev/null)            || rc=$? ;;
        uri)  value="$ref" ;;
        *)    return 0 ;;
    esac
    local label
    case "$kind" in
        pass) label="密码" ;; user) label="用户名" ;;
        totp) label="TOTP" ;; uri)  label="URI" ;;
    esac
    if [ "$rc" -ne 0 ] || [ -z "$value" ]; then
        bw_notify "复制${label}失败" dialog-error
        return 0
    fi
    bw_to_clipboard "$value"
    bw_notify "已复制${label}（${BW_CLEAR_AFTER}s 后清空剪贴板）"
}

bw_select() {
    local input="${1:-}" info="${ROFI_INFO:-}" retv="${ROFI_RETV:-1}"
    case "$info" in
        unlock) bw_bg_flow unlock ;;
        sync)   bw_bg_flow sync ;;
        lock)
            timeout 5 rbw lock </dev/null >/dev/null 2>&1 || true
            bw_init
            ;;
        entry:*)
            if [ "$retv" = "10" ]; then
                bw_actions "${info#entry:}" "$input"
            else
                bw_copy pass "${info#entry:}"
            fi
            ;;
        copy:*)
            local spec="${info#copy:}"
            bw_copy "${spec%%:*}" "${spec#*:}"
            ;;
        back) bw_init ;;
        *) : ;;  # unknown/empty info (no-custom blocks most paths): close
    esac
}
