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

## popup 意图队列 + 单 worker 架构（2026-08 重写，取代 per-click flock 队列）

**为什么重写**：旧设计中每次点击 fork 一个进程，抢全局 flock 后同步执行 ~20 次 IPC（含锁内 D-Bus）。单次 ~0.4s → 吞吐上限 ~2 ops/s，连点即排队，`flock -w 10` 超时**静默丢弃点击**（压测丢弃率 32%），队列期间 popup 表现为「卡死、无法关闭、点击没反馈」，且看门狗只杀 >30s 持锁者、对「大量年轻等待者」型拥塞完全无效。

**新架构**（`open-popup.sh`）：
1. **意图先行**：点击先把 `目标 + 点击时鼠标 x` 原子追加到 `/tmp/eww-popup.intents`（<1ms），**永不等待、永不丢失**。
2. **单 worker**：`flock -w 10` 只用于选举唯一消费者。抢不到 → 立即退出（在跑的 worker 会读到意图）；抢到 → 循环 `mv intents intents.work`（rename 原子，无丢失窗口）逐条执行，末尾 `reconcile` 让 `popup_open` 始终镜像 `active-windows`。
3. **事务瘦身**：同一 worker 内时序可控，close/open 连续下发、末尾只 `wait_state` 一次（CURRENT≠NEW 保证同窗口无 open/close 顺序冒险）。
4. **慢后端移出关键路径**：蓝牙扫描改为 fire-and-forget `bt-scan.sh sync`（自读 popup_open 决定 on/off，自有锁串行合并；bluetoothd 卡 5s 对 worker 零影响）。
5. **自愈**：daemon 两次 probe 超时 → 自动 `i3-msg exec launch.sh` 重启；settle 后 `orphan_gc` 用 `xdotool windowclose`（**禁止 windowkill**——XKillClient 会杀掉 eww daemon 的 X 连接）清除注册表外的孤儿窗口。
6. **settle 必须意图可中断**：收尾的 settle 睡眠以 0.1s 粒度轮询意图文件，新意图到达立即回 drain 循环。首版用了整段 `sleep 2`，导致 worker 休眠期间（每次交互后 2s 窗口）的点击要等 1-2s 才被看到——「点击后 popup 出现明显变慢」的回归。**worker 持锁不是问题，睡着才是问题**：任何收尾等待都必须能被新意图打断。

**调试**：`EWW_POPUP_DEBUG=1` 后触发点击，查 `/tmp/popup-debug.log`：
| 日志行 | 含义 |
| --- | --- |
| `intent queued: X mx=…` | 意图已落盘 |
| `worker busy (...); intent queued, exiting` | 正常——在跑的 worker 会消费 |
| `exec NEW=X CURRENT=…` | worker 开始执行该意图 |
| `reconcile FINAL=…` | 状态已镜像 |
| `watchdog: killing wedged worker` | 有 worker 卡死 >60s 被清理 |
| `daemon unresponsive — restarting` | daemon 失能，已自动重启 |
| `orphan-gc: closing orphan window` | 清除了注册表外孤儿窗口 |

**对账命令**（验证零丢失）：`grep -c "intent queued:" /tmp/popup-debug.log` vs `grep -c "exec NEW="` —— 必须相等。

**残余约束（历史踩坑，仍然有效）**：
- worker 持 fd 9 期间，其启动的一切长寿命子进程**必须显式关闭继承的锁 fd**（`9>&-`），否则锁被永久持有（2026-07 bluetoothctl 年活扫描进程实证）。
- worker 关键路径上**禁止无 timeout 的外部调用**（D-Bus/socket/IPC 都可能偶发阻塞）；「即时刷新」一律读 ewwstate tmpfs 快照，不跑 pactl/bluetoothctl 链。
- 诊断锁问题：`fuser -v /tmp/eww-popup.lock` + `ps -o etimes= -p <pid>`；worker 持续排水是正常持锁，>60s 才是毒化（看门狗会自动清理）。
- **踩坑实录**：2026-07 wifi/电源/控制中心 popup 有概率卡死——bluetoothctl 扫描进程继承 fd 9 永久持锁；2026-08 压测实证拥塞崩溃（连点 → 队列 → `flock -w 10` 静默丢弃 32%）→ 促成本次架构重写。

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

**daemon 窗口注册表脱同步**（与锁无关的卡死路径，2026-08 起由 worker 自愈）：
- 症状：`eww active-windows` 为空，但 `xdotool search --name "Eww"` 能看到窗口；`eww open` 客户端进程挂死数百秒（PPID=1）；`eww ping`/`get` 正常。
- **自动修复**：worker 启动时两次 `eww get popup_open` 超时 → 自动 `i3-msg exec launch.sh` 重启 daemon；settle 后 `orphan_gc` 自动 `windowclose` 清除注册表外的孤儿窗口。手动诊断仍可参考本文档。

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

---

## popup 关闭闪屏:picom destroy 期规则失效,修法是 close 前 prehide

**为什么**:picom 在窗口 destroy 帧里重新求值 name/class 规则,但此时 `WM_NAME`/`WM_CLASS`/`_NET_WM_WINDOW_TYPE` 已不可读(trace 实证 `client = 0000000000`)。`popup-scrim` 活着时靠 `name = 'Eww - popup-scrim'` 豁免 shadow/blur,濒死时豁免失配,于是 2560×1600 的濒死窗口被加上全屏 blur-background + 0.35 全屏 shadow;若此刻它被 i3 restack 抬到栈顶(popup 先 destroy 时必现),就是对整屏已合成画面再糊一遍 = 关 popup 时 ~50ms 的全屏闪。单独关 scrim 不闪,popup+scrim 一起关才闪,就是这个组合条件。

**怎么做**:`open-popup.sh` 的 `close_win()` 在 `eww close` 前先 `xprop -set _NET_WM_WINDOW_OPACITY 0`(`prehide`)。picom 对 client opacity 是缓存的,destroy 帧里 `opacity == 0` 让 renderer 直接跳过该 layer(blur/shadow/窗口全不画)。与分辨率、picom 版本无关,对任何 eww 窗口统一生效。前提:`detect-client-opacity = true`(picom.conf 已开)。orphan_gc 走 `prehide` + `windowclose` 同样处理。验证基线:60fps 录屏帧间差峰值 8.62(闪)→ 0.04(修复后)。

**被否掉的方案**(调研结论,别再走):① picom 几何条件(`argb && width>=…`)——销毁期只有几何存活,条件必然带分辨率数字,不通用;② 常驻 scrim 不销毁——eww 0.5 和 master 的 defwindow 几何都只在 open 时烘焙一次(`eww update` 不生效,master 的 configure_event 钩子还会扳回),全屏常驻又会偷焦点吃点击,无解。

---

## 截图/录屏可能是捕获侧假象——用户肉眼才是 ground truth

**为什么**:GLX 合成下 `maim`/`x11grab` 偶尔读到「只有糊化背景、没有任何窗口」的帧(特征:全图 stddev ≈ 0.063),用户物理屏幕完全正常。2026-08 排查闪屏时,这个假象先后被误判成「picom 卡死」「修复引入回退」,浪费数小时。

**怎么做**:截图只用于量组件位置/颜色等静态验证;涉及「闪、卡、消失」类动态问题,必须用户肉眼佐证 + picom `--log-level trace` 日志交叉验证。录屏帧间差(YDIF/stddev)做自动化回归可以,但出现「整屏空白」读数时先怀疑捕获,别先怀疑会话。

---

## 事件驱动后台脚本:防抖绝不能丢事件,必须周期回查自愈（brightness-auto.sh, 2026-08）

**为什么**:udev/D-Bus 事件循环和轮询有本质区别——**事件不会重发**。`(( now - last < DEBOUNCE )) && continue` 吞掉窗口内的事件后,脚本内部状态可能与 sysfs 永久脱节。对"按状态记忆/恢复"类脚本（如亮度、电源策略）表现为偶发"记忆错乱、切换不恢复",且 polling 模式下每轮重读 sysfs 能自愈、事件模式不能——只在生产的事件模式偶现,极易当玄学放过。连锁污染:脱节后下一次真实切换 `new_state == current_state` 直接 return,再下一次切换把错状态下使用的值存进错误的偏好文件,错误持久化。

**怎么做**:
1. **防抖是"抑制"不是"丢弃"**:状态检查函数每次调用都重读 sysfs 比对(幂等),被吞的事件靠下一次检查自愈;同状态事件不刷新防抖计时,否则连续同状态事件会无限延长窗口。
2. **事件循环加 `read -t N` 超时回查**(默认 30s):空闲零 CPU,被吞事件最多 N 秒自愈。bash 细节:`read -t` 超时返回 exit >128,EOF 返回 1,以此区分"该回查"和"udevadm 死了该退出重启";EOF 时注意最后半行数据也要先处理再 break。
3. **启动防抖计时初始化为 0**(或首次检查豁免),否则服务启动 N 秒内的第一次真实切换被吞——开机立刻拔电源必中。
4. **持久化传感器读数前先校验**:空/非数字/0 一律跳过保存保留旧偏好;`... || echo 0` 式 fallback 尤其危险——一次解析失败就把 0 写进偏好,以后每次切换恢复到 0。
5. **bash 陷阱**:`if ! cmd; then rc=$?` 里 `$?` 是被 `!` 反转后的状态(恒 0)。要拿真实退出码必须 `cmd; rc=$?` 再判断。

**沙盒回归测试配方**(改任何事件驱动脚本前后都跑):stub 掉 `udevadm`/`brightnessctl` 放进 PATH 最前,覆盖 HOME/XDG_CACHE_HOME/sysfs 路径,反复制造"快速插拔(3s 内)"序列:

```bash
env HOME=/tmp/sbx/home XDG_CACHE_HOME=/tmp/sbx/cache \
    BRIGHTNESS_AUTO_AC_PATH=/tmp/sbx/ac_online \
    PATH=/tmp/sbx:$PATH bash script.sh
# stub udevadm: 轮询 ac_online 文件变化,变就 echo 一行含 power_supply/AC0 的伪 uevent
# stub brightnessctl: 用文件存 fake 亮度;info 可注入损坏输出测校验分支
```

**警告**:stub 文件名必须是真实命令名(`brightnessctl` 不是 `stub_brightnessctl`),否则测试会调到真实命令——实测曾把用户真实屏幕亮度改掉。

**踩坑实录**:2026-08 用户报告插电/断电亮度偶尔记错(现场 `ac_level==bat_level==84`)。沙盒复现:拔掉→3s 内插回→事件被防抖吞→脱节→下次拔电不恢复且把 90 存进 bat 偏好(应为 40),错误永久化。修复即上述 1-4 条;修的过程中自己踩了第 5 条(`if ! read` 取 rc 恒 0,循环第一次超时就退出)。

---

## eww client 自动 spawn = socket 劫持:「OSD 卡死不消失」的真正根因,所有 eww 调用必须 --no-daemonize

**为什么**:eww 0.5 的 `eww open`/`open-many`(仅有的两个 `can_start_daemon=true` 命令)连不上 daemon 时——即使 daemon 活着只是卡死不响应——会进入 spawn 分支:`std::fs::remove_file(socket)` **删掉正牌 daemon 的 socket 文件**,再 fork 出第二个 daemon 重新绑定同一路径(源码 main.rs spawn arm,commit d87c2fd)。此后全系统所有 eww 命令都连到这个空壳假 daemon;正牌 daemon 还活着、已打开的窗口还在屏幕上画着,但永远不可达。`eww close/update/get` 不会 spawn,只会报错退出。

**踩坑实录**(2026-08-20,「插拔电源亮度 OSD 卡住不消失」):电源事件 → brightness-auto → osd.sh `eww open osd`。daemon 处理这次 open 时卡死(日志链:`Opening window osd` → `ERROR sending response from main thread` → 之后彻底静默,bar 时钟同刻冻结)。client 收到 Err → spawn 分支 → 假 daemon(cmdline 停留在 `eww open osd`)劫持 socket。osd.sh 的 2s 自动关闭 timer 把 `eww close osd` 发给假 daemon(它上面没有窗口)后「成功」退出、状态文件清理干净——真 daemon 上的 OSD 窗口永远留在屏幕。附带损伤:bar 停更(所有 update 都发给假 daemon)、popup 全部失效。

**取证指纹**(下次遇到「窗口卡住 + active-windows 为空」先看这三样):
1. `ss -lxp | grep eww-server` — 同一路径出现**两个** LISTEN 进程 = 已被劫持。
2. `xprop -id <卡住窗口> _NET_WM_PID` — 指向 active-windows 不承认的那个 daemon。
3. `ps aux | grep eww` — 假 daemon 的 cmdline 是触发它的 client 命令(如 `eww open osd`)而非 `eww daemon`;journal 里能搜到它打的 `Initializing eww daemon` 横幅(亮度事件来源是 brightness-auto.service 的 stdout)。

**怎么做**:
1. 脚本里所有 `eww` client 调用一律 `timeout N eww ... --no-daemonize`。能 spawn 的只有 open/open-many,但全部调用统一加,防后患。
2. 脚本需要 daemon 时先 `eww ping --no-daemonize` 探活;不活就 `i3-msg exec ~/.config/eww/scripts/launch.sh` 重启并限时等待,等不到就放弃本次操作——绝不 fall through 到不带 `--no-daemonize` 的 `eww open`(参考 osd.sh 的探活段)。
3. launch.sh 清场用 `pgrep/pkill -x eww`(按 comm 匹配,能抓到 cmdline 伪装成 client 命令的假 daemon),并 `rm -f $XDG_RUNTIME_DIR/eww-server_*` 清残留 socket。
4. 已卡住的窗口只能整体重启 daemon 恢复(launch.sh);只杀假 daemon 没用——正牌 daemon 的 socket 文件已被删除,无法恢复可达性。
5. osd.sh 防御性重置要用 `eww active-windows`(真正打开的窗口)而非 `list-windows`——后者列出所有**定义过**的窗口,永远包含 osd,旧检查恒为 no-op。
