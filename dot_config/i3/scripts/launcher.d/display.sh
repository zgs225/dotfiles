#!/usr/bin/env bash

# display — 显示器管理模块（displayctl v2）
# 前缀：display。菜单 = 状态行 / 布局快捷 / 已存配置 / 管理。
# 依赖 displayctl v2 的 CLI 契约：current --json / list --json / layout / apply / save。

register_module display "display" plain "" "显示"

# 内屏判定：名字前缀 eDP- / LVDS-
_display_is_internal() {
    case "$1" in
        eDP-*|LVDS-*) return 0 ;;
        *) return 1 ;;
    esac
}

#  detached 执行 + notify 反馈（长操作不阻塞 rofi）
_display_run() {
    local desc="$1"; shift
    setsid -f bash -c '
        desc="$1"; shift
        if "$@" >/dev/null 2>&1; then
            notify-send "显示" "已应用：$desc"
        else
            notify-send -u critical "显示" "失败：$desc"
        fi
    ' _ "$desc" "$@" >/dev/null 2>&1
}

display_init() {
    printf '\0prompt\x1f显示\n'
    printf '\0no-custom\x1ftrue\n'

    if ! command -v displayctl >/dev/null 2>&1; then
        msg_row "未安装 displayctl" dialog-error
        return 0
    fi

    local cur_json list_json connected
    cur_json=$(timeout 5 displayctl current --json 2>/dev/null || true)
    list_json=$(timeout 5 displayctl list --json 2>/dev/null || true)
    # 连接状态来自 xrandr（只读连接态，不读 sysfs EDID）
    connected=$(xrandr 2>/dev/null | awk '/ connected/ {print $1}' | tr '\n' ' ')

    case "$cur_json" in "{"*) ;; *) cur_json="" ;; esac
    case "$list_json" in "["*) ;; *) list_json="" ;; esac

    CUR_JSON="$cur_json" LIST_JSON="$list_json" CONNECTED="$connected" /usr/bin/python3 <<'PYEOF'
import json, os

def sel(text, icon, info):
    print(text + "\0icon\x1f" + icon + "\x1finfo\x1f" + info)

def label(text):
    print(text + "\0icon\x1f\x1fnonselectable\x1ftrue")

def internal(name):
    return name.startswith(("eDP-", "LVDS-"))

cur = {}
try:
    cur = json.loads(os.environ.get("CUR_JSON") or "{}")
except ValueError:
    cur = {}
profiles = []
try:
    profiles = json.loads(os.environ.get("LIST_JSON") or "[]")
except ValueError:
    profiles = []
connected = (os.environ.get("CONNECTED") or "").split()

# ── 状态行 ──
outs = cur.get("outputs") or []
if outs:
    parts = []
    for o in outs:
        prim = "★" if o.get("primary") else ""
        parts.append(f'{o.get("name","?")} {o.get("mode","?")}{prim}')
    status = f'当前：{cur.get("layout","?")} · ' + " + ".join(parts) + f' · DPI {cur.get("dpi","?")}'
else:
    status = "当前：未知状态"
label(status)

# ── 布局快捷（动态，按 connected 输出）──
internals = [o for o in connected if internal(o)]
externals = [o for o in connected if not internal(o)]

label("布局")
if len(connected) >= 2:
    sel("扩展", "view-dual", "layout:extend")
    sel("镜像", "edit-copy", "layout:mirror")
for o in internals:
    sel(f"仅内屏 · {o}", "view-fullscreen", "layout:single:" + o)
for o in externals:
    tag = "仅外接" if len(externals) == 1 else "仅"
    sel(f"{tag} · {o}", "view-fullscreen", "layout:single:" + o)
if not connected:
    label("未检测到已连接输出")

# ── 已存配置（★=匹配当前硬件，排前）──
if profiles:
    label("已存配置")
    def sort_key(p):
        return (0 if p.get("match") else 1, p.get("name", ""))
    for p in sorted(profiles, key=sort_key):
        name = p.get("name", "?")
        star = "★ " if p.get("match") else ""
        meta = []
        if p.get("layout") and p.get("layout") != "legacy":
            meta.append(p["layout"])
        if p.get("default"):
            meta.append("默认")
        suffix = ("  ·  " + " · ".join(meta)) if meta else ""
        sel(f"{star}{name}{suffix}", "preferences-desktop-display", "profile:" + name)

# ── 管理 ──
label("管理")
sel("自动检测", "view-refresh", "act:auto")
sel("保存当前布局…", "document-save", "act:save")
PYEOF
}

display_select() {
    local info="${ROFI_INFO:-}"
    case "$info" in
        layout:extend)
            _display_run "扩展" displayctl layout extend ;;
        layout:mirror)
            _display_run "镜像" displayctl layout mirror ;;
        layout:single:*)
            local out="${info#layout:single:}"
            _display_run "仅 $out" displayctl layout single "$out" ;;
        profile:*)
            local name="${info#profile:}"
            _display_run "配置 $name" displayctl apply "$name" ;;
        act:auto)
            _display_run "自动检测" displayctl apply auto ;;
        act:save)
            # 等当前 rofi 关闭再弹 dmenu 取名字
            setsid -f bash -c '
                theme="$1"
                while pgrep -x rofi >/dev/null 2>&1; do sleep 0.05; done
                name=$(rofi -dmenu -p "保存为" -theme "$theme" 2>/dev/null)
                name=$(printf "%s" "$name" | sed "s/^[[:space:]]*//; s/[[:space:]]*$//")
                [ -z "$name" ] && exit 0
                if displayctl save "$name" >/dev/null 2>&1; then
                    notify-send "显示" "已保存布局：$name"
                else
                    notify-send -u critical "显示" "保存失败：$name"
                fi
            ' _ "$HOME/.config/rofi/launcher.rasi" >/dev/null 2>&1 ;;
    esac
}
