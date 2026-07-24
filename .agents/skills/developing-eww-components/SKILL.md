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
- **daemon 卡死，launch.sh 的等待循环超时** — `pkill -9 -f 'eww daemon'`，再重载。
- **点击没弹出 popup** — 确认 `(defwidget ...)` 的 `:name` 和你 `eww open <name>` 用的名字一致，看 log 里那条 open 调用有没有失败。
- **`maim -i` 截错了窗口** — 重新拿 WID：`wmctrl -l | grep eww`，daemon 每次重启后 hex ID 都会变。

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

**参考实现**：`open-popup.sh`、`storage-eject.sh`、`storage-open.sh` 均使用此模式。

**注意**：detached 进程可能丢失 `DBUS_SESSION_BUS_ADDRESS` 等环境变量。如果脚本里需要发 D-Bus 通知（如 `dunstify`），确保环境变量被继承——`setsid nohup` 会保留当前环境，但如果 i3 启动时没 export 该变量，detached 进程也拿不到。验证方法：在脚本里 `echo $DBUS_SESSION_BUS_ADDRESS >> /tmp/probe`。

---

## SCSS 非 ASCII 注释 = 全样式表丢弃

**为什么**：eww 用 grass（Rust SCSS 编译器）编译样式。如果编译输出含任何非 ASCII 字节，grass 会在头部插入 `@charset "UTF-8"`。GTK3 的 CSS 解析器把 `@charset` 当无效规则，**整个样式表被丢弃**——bar 和所有 popup 瞬间变无样式裸窗。

**怎么做**：
- SCSS 文件里**只允许 ASCII 注释**（`/* -- section -- */`），禁止 box-drawing 字符（`──`）、中文、emoji。
- 图标字符（PUA）只能出现在 `.yuck` 文件的 `:text` 属性里，**绝不**出现在 SCSS 的 `content` 或注释里。
- 每次 apply 后验证：`LC_ALL=C grep -P '[^\x00-\x7F]' ~/.config/eww/styles/*.scss` 应无输出。

**踩坑实录**：storage-popup.scss.tmpl 的注释用了 `/* ── Device card ── */`（box-drawing `──`），导致全桌面样式丢失、bar 变白底黑字。

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
