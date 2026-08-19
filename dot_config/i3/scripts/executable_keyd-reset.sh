#!/usr/bin/env bash
# keyd per-app 按键映射重置
# 用途:Alt+v / Alt+[ / Alt+] 等快捷键突然失效时,从 rofi 运行本工具
# (或直接执行)。原理:
#   1. keyd bind reset 清空所有临时绑定,立即恢复全局层
#   2. 重启 keyd-application-mapper,使其重新检测激活窗口并推送
#      正确的 per-app 豁免(app.conf)
set -euo pipefail

# 1. 清空 keyd 临时绑定
keyd bind reset 2>/dev/null || true

# 2. 重启 keyd-application-mapper(补丁版位于 /usr/local/bin)
pkill -f keyd-application-mapper 2>/dev/null || true
sleep 0.3
rm -f "${HOME}/.config/keyd/app.lock"
setsid nohup env PYTHONUNBUFFERED=1 /usr/local/bin/keyd-application-mapper -d </dev/null >/dev/null 2>&1 &
sleep 0.5

# 3. 触发一次窗口激活事件,让 mapper 立即推送当前焦点窗口的绑定
win="$(xdotool getactivewindow 2>/dev/null || true)"
if [ -n "${win}" ]; then
    xdotool windowactivate "${win}" 2>/dev/null || true
fi

notify-send "keyd 已重置" "按键映射已刷新 (${HOME}/.config/keyd/app.conf)" 2>/dev/null || true
