# eww 状态采集重构 — 交接文档

> 最后更新：2026-07-24 21:25
> 当前 daemon：10 collectors 运行中，pid 见 `ewwstate status`

---

## 一、工作目标

将 eww bar/popup 的 **33 个 defpoll + 3 个 deflisten** 从「每个变量各自 fork bash 脚本轮询」重构为 **统一 Python asyncio daemon（ewwstated）** 集中采集，eww 侧只读 tmpfs 文件（`ewwstate get <topic>`），实现：

1. **采集与获取彻底解耦**：慢采集器不阻塞读取，读取不触发采集。
2. **消除同源重复读取**：bluetoothctl show 3×→1×、pactl 3×→1×、nmcli 4×→1×、sysfs battery 3×→1×。
3. **消除进程风暴**：sysinfo 的 `sleep 0.25` 阻塞采样改 async；每秒 fork 数从 ~6 降到 ~1（daemon 内部 async gather）。
4. **框架化扩展**：新采集器 = 往 `collectors/` 丢一个 `@collector` 装饰的类，daemon 自动发现。

---

## 二、架构概览

```
collectors/*.py ─(各自独立 asyncio task + 崩溃指数退避重启)─▶ StateStore
                                                              │
                                                              ├─ 内存 dict（get 纯读，永不阻塞）
                                                              └─ 原子写 $XDG_RUNTIME_DIR/ewwstate/<topic>
                                                                      │
                       eww defpoll  → ewwstate get <topic> [fallback]   = cat 文件（瞬时）
                       eww deflisten→ ewwstate listen <topic>           = cat + inotifywait
```

**关键文件**：
- `dot_config/eww/ewwstate/framework.py` — PollCollector / EventCollector 基类 + @collector 注册
- `dot_config/eww/ewwstate/store.py` — StateStore（内存 + tmpfs 原子写）
- `dot_config/eww/ewwstate/util.py` — run/shell（async subprocess）、read_sysfs、sysfs_glob、running
- `dot_config/eww/ewwstate/daemon.py` — discover_collectors + supervised task runner
- `dot_config/eww/ewwstate/main.py` — CLI 入口（daemon/get/listen/dump/status）
- `dot_config/eww/ewwstate/collectors/*.py` — 各采集器
- `dot_config/eww/scripts/executable_ewwstate` — 安装为 `~/.config/eww/scripts/ewwstate`（yuck 调用入口）
- `dot_config/eww/ewwstate/README.md` — 框架文档 + 验证要点（踩坑沉淀）

---

## 三、已完成的工作

### 3.1 框架（U0）
- 全套 framework/store/util/daemon/main 已实现并验证。
- launch.sh 已集成 daemon 启动（`PYTHONDONTWRITEBYTECODE=1`，无条件重启以加载新 collector）。
- `.chezmoiignore` 已加 `**/__pycache__/` + `**/*.pyc`。

### 3.2 已迁移的 topic（25 / 36）

| 单元 | collector 文件 | topics | 验证截图 | 旧脚本处置 |
|------|---------------|--------|----------|-----------|
| U0 | battery.py | battery_percent, battery_charging, battery_icon | bar ✓ | **保留**（onclick 无引用但暂留回滚） |
| U1 | clock.py | clock_time, calendar_monthday, calendar_month, calendar_year | bar + calendar-popup ✓ | shichen.sh **已删** |
| U2 | nightlight.py | night_light | control-center ON/OFF ✓ | night-light-on.sh **保留**（cc-action.sh 乐观更新） |
| U3 | airplane.py | airplane_on | control-center ✓ | airplane-on.sh **保留**（toggle-airplane.sh 乐观更新） |
| U4 | powerinfo.py | power_info | power-popup ✓ | power-info.sh **保留**（power-admin.sh 乐观更新） |
| U5 | powerprofile.py | power_profile | control-center + power-popup ✓ | power-profile.sh **保留**（onclick set/cycle） |
| U6 | sysinfo.py | sysinfo | profile-card ✓ | sysinfo.sh **已删** |
| U7 | audio.py | volume, muted, audio_sinks, audio_sources, audio_devices | control-center + audio-popup ✓ | audio-*.sh **保留**（open-popup.sh onclick 链） |
| U8 | network.py | network_status, wifi_on, wifi_name, wifi_networks, wired_detail | network-popup + control-center ✓ | network-status.sh + network-wired-detail.sh **已删**；wifi-*.sh + network-common.sh **保留** |
| U9 | bluetooth.py | bt_on, bt_discoverable, bt_devices | bluetooth-popup ✓ | bt-*.sh **保留**（toggle-bt/toggle-airplane/bt-action 乐观更新） |

### 3.3 已删除的旧脚本（4 个）
- `shichen.sh`（U1，无 onclick 引用）
- `sysinfo.sh`（U6，无 onclick 引用）
- `network-status.sh`（U8，无 onclick 引用）
- `network-wired-detail.sh`（U8，无 onclick 引用）

### 3.4 git 状态（未 commit）
```
 M .chezmoiignore
 M dot_config/eww/components/common.yuck
 M dot_config/eww/scripts/executable_launch.sh
 D dot_config/eww/scripts/executable_shichen.sh
 D dot_config/eww/scripts/executable_sysinfo.sh
 D dot_config/eww/scripts/executable_network-status.sh
 D dot_config/eww/scripts/executable_network-wired-detail.sh
?? dot_config/eww/ewwstate/          (整个框架目录)
?? dot_config/eww/scripts/executable_ewwstate
```

---

## 四、剩余工作

### 4.1 未迁移的 defpoll（9 个 topic）

| 单元 | topic | 当前命令 | 类型 | 出现位置 | 备注 |
|------|-------|---------|------|---------|------|
| U10 | notif_count | notif-count.sh | Poll | notification-popup | dunstctl count |
| U10 | notifications | notif-yuck.sh | Poll | notification-popup | yuck-literal，dunstctl history |
| U10 | dnd | 内联 dunstctl is-paused | Poll | notification-popup + control-center | |
| U11 | media | media.sh | Poll→Event | control-center | playerctl |
| U12 | workspaces | workspaces.sh | **Event（i3 ipc）** | bar（始终可见） | 500ms 轮询→改 i3 subscribe |
| U13 | weather | weather.sh | Poll | calendar-popup | curl wttr.in + /tmp 缓存 |
| U14 | countdown | countdown.sh | Poll | calendar-popup | 纯 date 计算 |
| U15 | events | events.sh | Poll/inotify | calendar-popup | 读 events.json |
| — | brightness | 内联 brightnessctl | Poll | control-center | 简单，可顺手迁 |

### 4.2 未迁移的 deflisten（3 个 topic）

| 单元 | topic | 当前命令 | 备注 |
|------|-------|---------|------|
| U16 | updates_checking | update-listen-checking.sh | inotifywait ~/.cache/eww/ |
| U16 | updates | update-listen-updates.sh | 同上 |
| U16 | update_list | update-listen-list.sh | 同上 + eww get updates_filter 交叉读 |

### 4.3 收尾（U17）
- 删除所有已无引用的旧脚本（battery-percent/charging/icon.sh 等——需全树 grep 复核）。
- 全量 bar + 每个 popup 回归截图。
- `git add` + commit。

### 4.4 可选后续（不在本重构范围）
- **方案 D（渲染分离）**：把 yuck-literal 拼接从采集器挪到 yuck 模板。
- **控制 socket**：daemon 暴露 unix socket，onclick 动作脚本可 `ewwstate refresh <collector>` 触发即时刷新。
- **brightness 迁移**：简单内联命令，随时可做。

---

## 五、工作经验 / 踩坑沉淀

### 5.1 eww 0.5 defpoll 可见性懒加载
**变量只在被当前可见窗口引用时才轮询。** 只被 popup 引用的变量，popup 关闭时永远停在 `:initial`。这是正常行为（旧脚本也一样），不是迁移 bug。

→ **验证 popup-only 变量必须打开对应 popup 再测。**

### 5.2 `eww list-windows` 列定义窗口，不是打开窗口
判断 popup 是否打开用 `eww get popup_open`（值 = popup 名；`none` = 全关）。

### 5.3 删旧脚本前必须全树 grep（含 scripts/）
onclick 动作脚本（cc-action.sh / toggle-*.sh / *-action.sh / open-popup.sh）常在「乐观更新」里当场调用状态脚本。这种当场同步判断是 daemon 3s 异步采集做不到的，**该状态脚本必须保留**。

→ U2 曾因只 grep `components/` 漏掉 `cc-action.sh:23` 而误删 night-light-on.sh，已恢复。

### 5.4 含括号的 fallback 必须加单引号
`(box)` 作为 `ewwstate get <t> (box)` 的 fallback 时，eww 用 `sh -c` 执行，裸 `(box)` 被 shell 当子 shell 语法 → exit 2 → 变量永远 initial。写成 `ewwstate get <t> '(box)'`。

→ U8 的 wifi_networks/wired_detail 踩过。

### 5.5 pyc 污染治理
- daemon 启动带 `PYTHONDONTWRITEBYTECODE=1`。
- `.chezmoiignore` 用 `**/__pycache__/` + `**/*.pyc`（doublestar 需 `**/` 前缀匹配嵌套目录）。
- 运行时 pyc 一旦进 chezmoi 记录，用 `chezmoi apply --force` 清残留。
- 每次 apply 前先 `find dot_config/eww/ewwstate -name __pycache__ -exec rm -rf {} +`。

### 5.6 `chezmoi apply` 子树不删孤儿目标
`chezmoi apply ~/.config/eww`（子树）**不会删除**源已移除的目标文件。删旧脚本 = `git rm 源` + `rm 目标`。

### 5.7 `chezmoi apply`（无参数）被无关 .pi 冲突阻塞
`.pi/agent/settings.json` 外部改动 + 无 TTY → abort。解决：只 apply eww 子树 `chezmoi apply --force ~/.config/eww`。

### 5.8 `pkill -f` 自杀
`pkill -f 'ewwstate/main.py daemon'` 会杀执行该命令的 bash 自身。用字符类：`pkill -f '[e]wwstate/main.py daemon'`。

### 5.9 `eww logs` 在无 TTY 环境抓不到
连 `script` 伪 TTY 也会把 agent 会话带乱。调试 defpoll 是否执行用「probe 副作用文件」：临时把命令改成 `echo "$(date +%s)" >> /tmp/probe; <原命令>`。

### 5.10 open-popup.sh 依赖鼠标坐标
`$mouse_x` 在 agent 无鼠标移动环境下可能算空 → `eww open` 缺 `pos_x` 失败。验证时可显式带坐标：`eww open <popup> --arg pos_x=1850px --arg pos_y=40px` + `eww update popup_open="<name>"`。

### 5.11 JSON 型 topic 对等策略
实时抖动量（watts/cpu/temp）采样窗口不同，不应瞬时相等。对等校验用「解析后比 dict」+ 稳定字段严格相等 + 实时字段断言类型+范围+量级。

### 5.12 截图体积控制
全屏 2560×1600 PNG 常 >1MB，read 会超体积限制。截图后用 `convert <src> -resize 1280x -strip <out>` 压缩再 read。

---

## 六、验证方案（每个单元 7 步协议）

1. **写采集器**：`collectors/<name>.py`，topic 名 == eww 变量名，产出值 == 旧脚本字符串。
2. **离线对等校验**（apply 前）：`asyncio.run(collector.collect())` 的每个 topic 与旧脚本/旧命令输出比对。标量逐字节；JSON 解析后比 dict；yuck-literal 比结构+关键 token。不一致就改采集器。
3. **全树 grep 复核删留**：`grep -rn "<script>.sh" dot_config/eww/`（含 scripts/）。有 onclick 引用 → 保留；仅 defpoll/deflisten 引用 → 可删。
4. **改 common.yuck**：对应 defpoll/deflisten 命令换 `ewwstate get/listen`。括号 fallback 加引号。
5. **apply + reload**：`find ... -name __pycache__ -exec rm -rf {} +` → `chezmoi apply --force ~/.config/eww` → `i3-msg exec ~/.config/eww/scripts/launch.sh`。
6. **自动化校验**：daemon status 存活 + 日志无 exception；每个 topic `eww get == ewwstate get`（popup-only 变量需先打开 popup）；bar 在 list-windows。
7. **视觉校验**：`maim` 截 bar；凡组件出现在 popup，打开该 popup 再截一张（压缩到 1280px 宽再 read），肉眼确认 widget 正常。

---

## 七、接手快速上手命令

```bash
# 查看 daemon 状态
~/.config/eww/scripts/ewwstate status
~/.config/eww/scripts/ewwstate dump

# 查看 daemon 日志
cat /tmp/ewwstated.log

# 前台跑 daemon（调试用，Ctrl-C 停）
PYTHONDONTWRITEBYTECODE=1 python3 ~/.config/eww/ewwstate/main.py daemon

# 重载 eww（应用 yuck 改动后）
chezmoi apply --force ~/.config/eww
i3-msg exec ~/.config/eww/scripts/launch.sh

# 打开 popup 验证（agent 环境用显式坐标）
eww open <popup-name> --arg pos_x=1850px --arg pos_y=40px
eww update popup_open="<popup-name>"

# 截图 + 压缩
maim /tmp/eww-screenshots/test.png
convert /tmp/eww-screenshots/test.png -resize 1280x -strip /tmp/eww-screenshots/test-small.png

# 关闭 popup + 复位
eww close <popup-name> 2>/dev/null
eww update popup_open="none"
```

---

## 八、当前环境实时态（接手时参考）

- daemon：running，10 collectors（airplane, audio, battery, bluetooth, clock, network, nightlight, powerinfo, powerprofile, sysinfo）
- popup_open：bluetooth-popup（我验证 U9 后残留，接手前先 `eww update popup_open="none"` + `eww close bluetooth-popup`）
- bar：正常渲染（电池 79%、时钟 申时/酉时）
- 未 commit 的改动见 §3.4
