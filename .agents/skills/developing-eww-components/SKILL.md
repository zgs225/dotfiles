---
name: developing-eww-components
description: Use when modifying/testing/debugging/creating eww components in dot_config/eww/.
---

# 开发 eww 组件

## 概述

eww 的 bar 和 popup 配置在 `dot_config/eww/` 下以声明式 yuck/SCSS 编写。改完源码后,agent 容易在三个地方挂起:直接跑 `launch.sh` 会把脚本挂在 agent 的 shell 上;`eww logs` 是长连接;改 `.tmpl` 文件后忘了跑 `chezmoi apply`。本 skill 给出每一步的安全变体,加上截图与点击验证的命令。

## 重载循环

每次改完 eww 源码必须依次执行两步 — 顺序不可颠倒:

```bash
# 1. 从 .tmpl 重新渲染到 ~/.config/eww/
chezmoi apply

# 2. 通过 i3 重载 eww(立即返回,进程由 i3 接管)
i3-msg exec ~/.config/eww/scripts/launch.sh
```

**绝对不要直接跑 `launch.sh`。** launch.sh 内部的 `eww kill` → 等待 daemon 死亡 → `eww daemon` → `eww open bar` 全部跑在 agent 的 bash 进程组里:要么阻塞(脚本不退出),要么与下一条命令竞态(你不知道到底谁先跑完)。`i3-msg exec` 把进程交给 i3 监管,agent 的 bash 立即返回。

**为什么 `chezmoi apply` 是循环的一部分,不能省略:** `.tmpl` 文件(eww.yuck.tmpl、eww.scss.tmpl、所有 `*popup.yuck.tmpl`)只有 chezmoi 跑过才会重新渲染。如果只跑 `i3-msg exec launch.sh`、没跑 `chezmoi apply`,daemon 重新加载的是 `~/.config/eww/` 里已经过时的渲染产物。

## 查看日志

`eww logs` 是 daemon 日志的流式订阅者,在 agent 里会无限阻塞。两种安全模式:

```bash
# 后台写入文件(迭代调试时首选)
nohup eww logs > /tmp/eww.log 2>&1 &
disown

# 另一个 shell 里 tail
tail -f /tmp/eww.log
```

```bash
# 一次性看最近输出
eww logs 2>&1 | tail -100
```

**`/tmp/eww.log` 里要 grep 的关键信号:**

| 信号 | 含义 |
| --- | --- |
| `error in yuck file` | yuck 语法错误,含文件:行号 |
| `failed to parse CSS` | SCSS 编译错误 |
| `Window not found` | `(defwindow ...)` 名字或 `:class` 不匹配 |
| `gtk` 警告 | 通常无害,可忽略 |

## 视觉验证

```bash
mkdir -p /tmp/eww-screenshots

# 全屏,带时间戳
maim /tmp/eww-screenshots/$(date +%Y%m%d-%H%M%S).png

# 交互式区域选择
maim -s /tmp/eww-screenshots/region.png

# 截指定的 eww 窗口
WID=$(wmctrl -l | awk '/eww-bar/ {print $1; exit}')
maim -i "$WID" /tmp/eww-screenshots/bar.png
```

验证 popup 定位的标准流程:截一张 bar → 通过 bar 按钮触发 popup → 再截一张 → 视觉对比位置。bar 窗口用 `:class` 匹配(一般是 `eww-bar`)。

## 驱动 bar 交互

```bash
# 1. 列出 eww 窗口
wmctrl -l | grep eww
#   0x04000038  0 yuez:eww-bar  eww bar

# 2. 聚焦 bar
WID=0x04000038
wmctrl -ia "$WID"

# 3. 在 bar 内点击坐标
xdotool mousemove --window "$WID" 250 12 click 1
```

bar 的 on-click 处理器是 i3 命令;用 `xdotool` 模拟点击等价于用户真实点击。坐标默认是绝对屏幕像素,加 `--window` 后是窗口内相对坐标。

## 常见失败模式

- **bar 消失但日志没报错** — daemon 在跑，但 bar open 失败了。看 `eww logs` 找 `defwindow` 报错，再重载。
- **改了不生效** — 你跑 `chezmoi apply` 了吗？`i3-msg exec launch.sh` 只重启 daemon，**不会**重新渲染 `.tmpl`。
- **bar 突然换了一套「陌生主题」（模块变 pill 按钮、时辰字重/字体回退）** — 不是谁改了配置，是 eww 样式表 grass 编译失败、GTK 掉回 THEME 优先级（catppuccin-glass）兜底。与 @charset 丢弃的区别：@charset 是 GTK 收到表但全表拒收 → 裸窗白底；编译失败是 eww 根本没给出表 → 主题 pill 兜底。查 SCSS 注释/括号结构，见「SCSS 注释结构断裂」条。
- **daemon 卡死，launch.sh 的等待循环超时** — `pkill -9 -f 'eww daemon'`，再重载。
- **点击没弹出 popup** — 确认 `(defwidget ...)` 的 `:name` 和你 `eww open <name>` 用的名字一致，看 log 里那条 open 调用有没有失败。
- **`maim -i` 截错了窗口** — 重新拿 WID：`wmctrl -l | grep eww`，daemon 每次重启后 hex ID 都会变。
- **`eww update` 成功但 `eww get` 返回空** — daemon 内部变量存储损坏（长时间运行后的已知脆弱性）。`eww ping` 正常、`eww open/close` 正常，但 `eww state` 输出为空或残缺。修复：`i3-msg exec ~/.config/eww/scripts/launch.sh` 重启 daemon。排查方法：截图后立刻 `eww get screenshot_path`，如果为空就是此问题。

---

## eww onclick 200ms 超时与 detach 守卫

**为什么**：eww 的 `:onclick` 处理器用 `sh -c` 执行命令，200ms 后 SIGKILL 仍在运行的进程（源码：`crates/eww/src/widgets/mod.rs`）。任何涉及 D-Bus 往返、子进程 fork、sleep 的脚本（如 `udisksctl unmount`、`bluetoothctl`、`nmcli`）几乎必然超 200ms，被 eww 砍掉后表现为"按钮点了没反应"。

**怎么做**：脚本头部加 detach 守卫，eww 调用立即返回，真工作在断连进程里跑：

```bash
#!/usr/bin/env bash
set -euo pipefail

# Detach guard — eww SIGKILLs onclick commands after 200ms.
if [ -z "${EWW_MYSCRIPT_DETACHED:-}" ]; then
    EWW_MYSCRIPT_DETACHED=1 setsid nohup "$0" "$@" >/dev/null 2>&1 &
    exit 0
fi

# ... real work below (can take seconds) ...
```

**参考实现**：`open-popup.sh`、`storage-eject.sh`、`storage-open.sh`、`screenshot-action.sh` 均使用此模式。

**踩坑实录**：`screenshot-action.sh` 的 annotate 分支直接在前台跑 `satty`（GUI 标注工具，阻塞到用户关闭），没有 detach guard。eww 在 200ms 后 SIGKILL `/bin/sh`，satty 作为子进程被连带杀死，表现为"点击标注没反应"。

**注意**：detached 进程可能丢失 `DBUS_SESSION_BUS_ADDRESS` 等环境变量。如果脚本里需要发 D-Bus 通知（如 `dunstify`），确保环境变量被继承——`setsid nohup` 会保留当前环境，但如果 i3 启动时没 export 该变量，detached 进程也拿不到。验证方法：在脚本里 `echo $DBUS_SESSION_BUS_ADDRESS >> /tmp/probe`。

---

## popup 全局 flock 毒化——popup 卡死无法关闭但 eww ping 正常

**为什么**：`open-popup.sh` 是所有 popup 开关的唯一入口（bar 按钮、scrim 点击都走它），所有调用串行在全局锁 `/tmp/eww-popup.lock`（fd 9）上；`flock -w 10` 拿不到锁会**静默丢弃本次点击**。两类持锁毒化会让所有 popup 点击永久失效：

1. **锁持有区内的无超时外部调用**。任何 D-Bus/socket 调用（`pactl`/`bluetoothctl`/`nmcli`）都可能偶发阻塞。旧逻辑在持锁时同步跑 `audio-devices.sh`（4 次无 timeout 的 pactl 往返），PipeWire 一卡顿脚本就挂在锁内。
2. **fd 9 泄漏给长寿命子进程**。bash 后台子进程默认继承所有 fd，而 flock 要等最后一个持 fd 的进程关闭才释放。`bt-scan.sh on` 启动的 `bluetoothctl --timeout 31536000 scan on`（故意活一年的扫描保持进程）继承了 fd 9 → **开过一次 bluetooth-popup 后锁被永久持有**（用 `fuser -v` 实证）。

**症状识别**（关键鉴别特征）：popup 开着、怎么点都关不掉，但 `eww ping` 正常、bar 其它部分活着 → 几乎一定是锁毒化而非 eww daemon 卡死。诊断：

```bash
fuser -v /tmp/eww-popup.lock        # 列出所有持 fd 进程（打开就算，不只是 flock 持有者）
ps -o etimes= -p <pid>              # 持锁多久了（健康调用 <2s）
```

**怎么做**：
- 锁持有区内每个外部命令都必须有 `timeout`，并给子进程 `9>&-`；长寿命后台进程（`nohup`/`setsid`）**必须显式关闭继承的锁 fd**：`nohup cmd >/dev/null 2>&1 8>&- 9>&- &`。
- popup 打开时的「即时刷新」不要同步跑状态脚本链，改读 daemon 快照：`timeout 3 ewwstate get <topic>` + 空值守卫 + `eww update`（见 ewwstate-collector-dev gotcha #26）。
- 兜底看门狗（已内置于 open-popup.sh）：`flock -w 10` 失败后枚举持锁者，有进程存活 >30s 即 SIGKILL 全部持锁者（排除自身）并重试一次；年轻持锁者维持丢弃点击、不误杀。
- 调试：`EWW_POPUP_DEBUG=1` 后触发点击，查 `/tmp/popup-debug.log` 里的 `watchdog: killing...` / `lock busy...` 记录。

**踩坑实录**：2026-07 用户报告 wifi/电源/控制中心 popup 有概率卡死无法关闭。先用开关压测/竞态/浸泡/update 风暴实测排除 eww daemon（ping/CPU/线程全程健康）；人为持锁 1:1 复现症状；最终 `fuser` 实证 bluetoothctl 扫描进程永久持锁——只要会话中开过蓝牙菜单，后续所有 popup 点击全失效，表象上分不清是哪个 popup 卡住的。

---

## i3 焦点管理与 eww popup——no_focus 杀死点击，正确修法是 focus_on_window_activation none

**为什么**：eww popup 在 i3 下有两个焦点相关的坑，且直觉修法（`no_focus`）会引入更严重的问题：

1. **eww `:focusable false` 是 GTK 层假象**。实测 `xprop WM_HINTS` 始终显示 `Client accepts input or input focus: True`。不能依赖这个 yuck 属性做 WM 层焦点判断。
2. **周期 `eww update`（每 2-3s）触发 GTK re-render → 发送 `_NET_ACTIVE_WINDOW` 客户端消息**。i3 的 `focus_on_window_activation smart` 会把这解读为「窗口请求激活」并聚焦它——表现为 popup 打开后每 3s 抢一次焦点，用户无法稳定操作其他窗口。
3. **`no_focus [class="Eww"]` 会彻底杀死 popup 的鼠标点击**。i3 对 no_focus 窗口不投递 button 事件，所有 onclick 失效。这是比抢焦点更严重的回归。

**怎么做**：
- **禁止使用 `no_focus`** 来解决 eww 焦点问题。
- 正确修法：i3 config 中 `focus_on_window_activation none`。这阻断 activation 事件引发的聚焦，但 `focus_follows_mouse yes` 仍正常工作——鼠标移入 popup 时聚焦（用户正在操作它，这是正确行为），鼠标离开后不再被周期 update 抢回。
- 如果「抢焦点」伴随「popup 关不掉」，先查 daemon 脱同步（见下条），孤儿窗口 + 周期 update 是复合病因。

**daemon 窗口注册表脱同步**（与 flock 毒化不同的卡死路径）：
- 症状：`eww active-windows` 为空，但 `xdotool search --name "Eww"` 能看到窗口；`eww open` 客户端进程挂死数百秒（PPID=1）；`eww ping`/`get` 正常。
- 诊断：`ps -eo pid,etimes,cmd | grep "eww open"` 找挂死客户端；`xdotool search --name "Eww" getwindowname` 对比 `eww active-windows`。
- 修复：`kill -9 <挂死PID>` + `i3-msg exec ~/.config/eww/scripts/launch.sh` 重启 daemon。
- 这是 eww 上游已知脆弱性（长时间运行后窗口管理层脱节），无法在配置层完全避免。

**踩坑实录**：2026-07-30 用户报告电源 popup 卡住 + 不停抢焦点。诊断发现 daemon `active-windows` 为空但 X11 窗口存在（脱同步），`eww open` 客户端挂死 300+s。重启 daemon 解决卡死。随后尝试 `no_focus [class="Eww"]` 防抢焦点 → popup 所有按钮点击失效（回归）。最终改为 `focus_on_window_activation none`，既阻断周期 activation 抢焦点，又保留 focus_follows_mouse 的正常交互。

---

## SCSS 非 ASCII 注释 = 全样式表丢弃

**为什么**：eww 用 grass（Rust SCSS 编译器）编译样式。如果编译输出含任何非 ASCII 字节，grass 会在头部插入 `@charset "UTF-8"`。GTK3 的 CSS 解析器把 `@charset` 当无效规则，**整个样式表被丢弃**——bar 和所有 popup 瞬间变无样式裸窗。

**怎么做**：
- SCSS 文件里**只允许 ASCII 注释**（`/* -- section -- */`），禁止 box-drawing 字符（`──`）、中文、emoji。
- 图标字符（PUA）只能出现在 `.yuck` 文件的 `:text` 属性里，**绝不**出现在 SCSS 的 `content` 或注释里。
- 每次 apply 后验证：`LC_ALL=C grep -P '[^\x00-\x7F]' ~/.config/eww/styles/*.scss` 应无输出。

**踩坑实录**：storage-popup.scss.tmpl 的注释用了 `/* ── Device card ── */`（box-drawing `──`），导致全桌面样式丢失、bar 变白底黑字。

---

## SCSS 注释结构断裂 = 编译失败 = 主题兜底（不是裸窗）

**为什么**：grass 是编译器，不光查字节还查语法——注释提前 `*/` 闭合后，下半段注释变成游离在规则外的裸文本（或括号不配对），**整个编译失败**，eww 不给 GTK 挂任何样式表。此时 widget 回落到 THEME 优先级的 catppuccin-glass：模块按钮集体变 pill（主题 button 边框）、`.time-main` 宋体/粗体丢失。症状是「换了一套陌生主题」，不是 @charset 陷阱的白底裸窗，第一眼极易误判成「谁把样式改坏了」。

**怎么做**：改完 SCSS `.tmpl`，`chezmoi apply` 后、重启前做三件事：

```bash
# 1. ASCII（§8.1 老规矩）
LC_ALL=C grep -Pn '[^\x00-\x7F]' ~/.config/eww/styles/*.scss   # 无输出

# 2. 注释剥离后括号平衡 + 无断裂注释残片（'*/' 提前闭合后,下半段
#    注释变成规则外的 '* text' 裸行——误报为零的特征签名)
python3 - <<'EOF'
import re, glob
for f in glob.glob('/home/yuez/.config/eww/styles/*.scss') + ['/home/yuez/.config/eww/eww.scss']:
    s = re.sub(r'/\*.*?\*/', '', open(f).read(), flags=re.S)
    assert s.count('{') == s.count('}'), f'{f}: brace mismatch'
    stray = [l.strip() for l in s.splitlines()
             if re.match(r'^\s*\*+\s+\S', l) and '{' not in l]
    assert not stray, f'{f}: broken comment fragment {stray[:2]}'
print('scss structure ok')
EOF

# 3. 重启后【先截一张 bar 全图】确认样式表活着，再开始量组件——不要只盯着你改的那个部件
```

**踩坑实录**：2026-08-04 写 tray-menu.scss.tmpl 时头部注释在中间 `*/` 提前闭合，后半段 NOTE 成了规则外游离文本 → grass 编译失败 → 全桌面 bar 掉回 catppuccin pill 主题。因为重启后只截图了菜单没看 bar，排查绕了一个小时才定位到这一行。

---

## 禁止直接编辑渲染产物 `~/.config/eww/**`——热重载读到中间态 + 双 bar

**为什么**：eww daemon 监视配置目录、文件一变就热重载。直接 `sed -i` 渲染产物做 A/B 实验有三连坑：① sed 写到一半被 watcher 读到中间态，编译出你不想要的版本；② 热重载有已知 bug——bar 窗口被**复制而不是替换**（两个 bar 叠罗汉，看到的未必是 daemon 注册的那个）；③ 绕开 chezmoi 造成源/渲染漂移，下次 `chezmoi apply` 静默覆盖你的实验。

**怎么做**：任何实验都走完整循环——改源 `.tmpl` → `chezmoi apply` → `i3-msg exec ~/.config/eww/scripts/launch.sh` → `eww ping` → 截 bar。快速试色也一样，不碰 `~/.config/eww/`。

**重启静默失败三形态**（重启后必须 `eww ping` + 截图裁决，再相信后续测量）：
- launch.sh 的 `flock -n 9 || exit 0`：锁被持有时**静默退出什么都不做**（查 `fuser -v /tmp/eww-launch.lock`）；
- `setsid nohup launch.sh &` 挂在复合命令里，agent shell 偶发整链死亡、无任何输出；
- `i3-msg exec` 返回 `success:true` 但 daemon 实际没起来（原因未明，重放一次即可）。

**踩坑实录**：2026-08-04 上述三连全中——sed 渲染产物触发双 bar；复合命令静默死亡导致 daemon 没换血，拿着旧样式表当新样式量了一轮；flock 残留又让一次重启静默跳过。每一步单看都像「eww 疯了」，串起来全是流程违规。

---

## eww systray 菜单窗口非 ARGB——玻璃失效，用不透明令牌 + inset 发丝线

**为什么**：eww 0.5 的 systray 把 SNI dbusmenu 自己渲染成 GTK menu 窗口，三个平台限制：

1. **窗口非 ARGB visual**：`rgba($bg-base, 0.60)` 不与壁纸合成，而是叠在窗口自身黑底上——实测出来是近黑 `#17171A`，不是设计稿的 L4 玻璃。透明层级语言（§2.2）在这里整体失效。
2. **override-redirect 裁 border**：`menu` 节点的真 `border` 画不出屏幕（左缘像素实测无发丝线）。发丝线要改用 `box-shadow: inset 0 0 0 1px rgba($accent, 0.35)`（内阴影画在背景之上，实测像素 = 0.35 天青叠黛的理论值，分毫不差）。
3. **`all: unset` 的后遗症**：submenu 箭头的 `-gtk-icon-source` 被清零（箭头消失）、`menuitem check/radio` 指示器无样式（fcitx 输入法列表的单选点全灭）。

**怎么做**：菜单面用不透明 `bg_elevated`（黛，浮层底色）代替 L4 alpha；箭头用 border 三角重绘；check/radio 手工给 1px 天青框 + `:checked` 天青填底；tooltip 同理不透明。参考实现 `styles/tray-menu.scss.tmpl`，度量取 GTK 主题 pt 值的像素当量（eww-sizes 烘焙），与原生 GTK/Qt 托盘菜单同物理尺寸。

**验证手法**：右键托盘图标开菜单后 `xdotool mousemove` 悬停 + `maim` 截图，再逐像素扫边缘：发丝线、界引、hover 底都应该是可计算的令牌合成值（见本文件「视觉验证」节的采样命令）。

---

## eww 窗口高度是固定像素——不能随内容自适应

**为什么**：eww 0.5 的 `(defwindow ... :geometry (geometry :height "Xpx" ...))` 在 apply 时烤死为字面量，运行时不能根据列表长度动态调整。GTK 不会自动收缩空窗口。

**怎么做**：popup 高度在 `.chezmoitemplates/eww-sizes` 里按 DPI 档位预设。设计时按"最大常见设备数"定高度（如 3-4 行），少设备时底部留白是固有取舍。如果列表可能很长，用 `(scroll :vscroll true ...)` 包裹内容区。

---

## PUA 图标禁止手敲——collector 用 chr() 注入

**为什么**：Nerd Font 的 PUA 码位因版本/构建而异。手敲 `\uf1165` 以为是 USB 图标，实际渲染成纸飞机；`\uf01bc` 以为是 eject，实际是 database。yuck 模板里写死 PUA = 100% 出错。

**怎么做**：
1. 用 fonttools 查规范 glyph 名对应的精确码位（见 ewwstate-collector-dev/gotchas.md #20）。
2. 在 collector 里用 `chr(0xF0553)` 注入到 JSON 字段（如 `"icon"`、`"eject_icon"`、`"open_icon"`）。
3. yuck 模板用 `${dev.icon}` 引用，**模板里零 PUA 字符**。
4. bar 图标同理：collector 发布 `storage_icon` 变量，bar 用 `${storage_icon}`。

---

## thunar-volman 不是守护进程

**为什么**：`thunar-volman` 是一次性命令，由 udev 规则在设备插入时调用。`Thunar --daemon` 只启动文件管理器后台进程，**不启动** volman。i3 环境下如果缺少对应的 udev 规则（`/usr/lib/udev/rules.d/*thunar*`），插入 USB 不会自动挂载。

**怎么做**：写用户级 `automount-daemon.sh`，用 `udevadm monitor --subsystem-match=block --property --udev` 监听 `add` 事件，检测到可移动分区后调 `udisksctl mount`。由 i3 config 的 `exec --no-startup-id` 启动。关键：只监听 `add`（设备插入），不监听 `change`（mount/unmount 状态变化），否则用户弹出后会被重挂。
