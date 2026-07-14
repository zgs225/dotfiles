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

- **bar 消失但日志没报错** — daemon 在跑,但 bar open 失败了。看 `eww logs` 找 `defwindow` 报错,再重载。
- **改了不生效** — 你跑 `chezmoi apply` 了吗?`i3-msg exec launch.sh` 只重启 daemon,**不会**重新渲染 `.tmpl`。
- **daemon 卡死,launch.sh 的等待循环超时** — `pkill -9 -f 'eww daemon'`,再重载。
- **点击没弹出 popup** — 确认 `(defwidget ...)` 的 `:name` 和你 `eww open <name>` 用的名字一致,看 log 里那条 open 调用有没有失败。
- **`maim -i` 截错了窗口** — 重新拿 WID:`wmctrl -l | grep eww`,daemon 每次重启后 hex ID 都会变。
