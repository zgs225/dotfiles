# eww 状态采集重构 — 跨窗口交接文档

> 本文自包含。另一个窗口的 agent 读完即可零上下文接手，**无需回看历史对话**。
> 最后更新：2026-07-24。当前进度 **U0–U9 完成（25 topic 已迁 daemon）**，剩 8 个单元（12 topic）。

---

## 0. 目标 & 接手第一件事

**目标**：把 eww bar/popup 的所有 `defpoll`/`deflisten` 状态获取脚本，重构为**一个常驻 asyncio daemon（`ewwstate`）**。采集与获取**彻底异步解耦**：daemon 异步采集写 tmpfs 镜像；eww 侧 `ewwstate get` 只 `cat` 文件，永不触发采集、永不阻塞。框架要**方便注册扩展**（丢一个 collector 文件即自动发现）。用户选定**方案 C**。

**接手第一件事 — 复位环境**（上个窗口可能留着 popup 开着 / daemon 在跑）：

```bash
eww update popup_open="none" 2>/dev/null
eww close bluetooth-popup 2>/dev/null   # 上个窗口验证 U9 时手动开过
~/.config/eww/scripts/ewwstate status   # 看 daemon 是否在跑（在跑就接着用，不必重启）
```

**重载循环（铁律，顺序不可颠倒）**：

```bash
cd /home/yuez/.local/share/chezmoi
chezmoi apply --force ~/.config/eww          # 只 apply eww 子树！见踩坑 #12
i3-msg exec ~/.config/eww/scripts/launch.sh  # 绝不直接跑 launch.sh（会挂住 agent shell）
```

---

## 1. 架构总览

```
collectors/*.py ──(各自独立 asyncio task，崩溃由 supervisor 指数退避重启)──▶ StateStore
   · PollCollector  定时 collect() -> {topic: value}        {topic: str}
   · EventCollector 常驻 run()，await 事件源后 store.set()   · 内存 dict
                                                            · 变更时原子写 $XDG_RUNTIME_DIR/ewwstate/<topic>
                                                                        │
              eww defpoll  →  ewwstate get <topic> [fallback]   = cat tmpfs 文件（瞬时，不需 daemon 存活）
              eww deflisten→  ewwstate listen <topic>           = cat + inotifywait（事件驱动）
```

**文件清单**（源在 `dot_config/eww/ewwstate/`，安装到 `~/.config/eww/ewwstate/`）：

| 文件 | 作用 |
|---|---|
| `framework.py` | `PollCollector`/`EventCollector` 基类 + `@collector` 装饰器 + `registered()` |
| `store.py` | `StateStore`：`set()` 去重+原子写+通知；`get()` 纯读永不阻塞 |
| `util.py` | `run(cmd)`/`shell(cmd)` 异步子进程；`read_sysfs`/`sysfs_glob`；`running(*names)`（async `pgrep -x`） |
| `daemon.py` | `discover_collectors()` 自动 import `collectors/` 全包 + `_supervised` 每采集器独立 task |
| `main.py` | CLI：`daemon`/`get`/`listen`/`dump`/`status` |
| `collectors/<name>.py` | 一个采集器一文件，`@collector` 注册 |
| `scripts/executable_ewwstate` | 安装为 `~/.config/eww/scripts/ewwstate`，yuck 的稳定调用入口（`exec python3 .../main.py "$@"`） |
| `scripts/executable_launch.sh` | 已加 daemon 启动块：`pkill` 旧的 → 等死 → `nohup env PYTHONDONTWRITEBYTECODE=1 python3 .../main.py daemon`（`9>&-` 关继承锁 fd） |

**两条让迁移=纯换命令的约定**：
1. **topic 名 == eww 变量名**。
2. **采集器产出的值 == 旧脚本打印的字符串**（标量/JSON/yuck-literal 原样），故 yuck 渲染逻辑零改动。

**添加 collector 模板**：

```python
from framework import PollCollector, collector   # 或 EventCollector
from util import run, shell, read_sysfs, sysfs_glob, running

@collector
class Foo(PollCollector):
    name = "foo"                       # 日志/refresh 用唯一 id
    topics = ("foo_var",)              # == eww 变量名
    interval = 3.0
    async def collect(self):
        return {"foo_var": "value"}    # 值 == 旧脚本字符串
```

collector **必须非阻塞**：用 `util.run`/`shell`（async 子进程），绝不用 `subprocess.run`。

---

## 2. 已完成工作（U0–U9，25 topic，全部验证通过）

| 单元 | collector 文件 | 迁的 topic | 验证截图 |
|---|---|---|---|
| U0 | `battery.py` | battery_percent/charging/icon | bar |
| U1 | `clock.py` | clock_time, calendar_monthday/month/year | bar + calendar-popup |
| U2 | `nightlight.py` | night_light | control-center（伪造 redshift 翻转 on/off） |
| U3 | `airplane.py` | airplane_on | control-center |
| U4 | `powerinfo.py` | power_info | power-popup |
| U5 | `powerprofile.py` | power_profile | control-center + power-popup |
| U6 | `sysinfo.py` | sysinfo | profile-card |
| U7 | `audio.py` | volume, muted, audio_devices/sinks/sources | control-center + audio-popup |
| U8 | `network.py` | network_status, wifi_on/name/networks, wired_detail | bar + network-popup + control-center |
| U9 | `bluetooth.py` | bt_on, bt_discoverable, bt_devices | bluetooth-popup |

**已删除的旧脚本**（全树 grep 确认无 onclick 引用）：
`shichen.sh`、`sysinfo.sh`、`network-status.sh`、`network-wired-detail.sh`
（git 状态：shichen/sysinfo 为 ` D`（工作区删未 staged），network-* 为 `D `（已 staged）。接手者提交时 `git add -A` 即可统一。）

**保留的旧脚本**（onclick 乐观更新/链引用，**只迁了 defpoll，脚本本身必须留**）：
- `night-light-on.sh`（cc-action.sh:23）
- `airplane-on.sh`（toggle-airplane.sh:15）
- `power-info.sh`（power-admin.sh:38）
- `power-profile.sh`（power-popup set×3 + control-center cycle）
- `audio-devices.sh` / `audio-sinks.sh` / `audio-sources.sh`（open-popup.sh:253 + audio-devices 内部互调）
- `network-wifi-on.sh` / `network-wifi-name.sh` / `network-wifi-networks.sh` / `network-common.sh`（toggle-wifi / wifi-connect / toggle-airplane 乐观更新链）
- `bt-on.sh` / `bt-devices.sh` / `bt-discoverable-on.sh`（toggle-bt / toggle-airplane / toggle-bt-discoverable / bt-action 乐观更新链）

**git 状态快照**（未提交）：
```
 M .chezmoiignore                       # 加了 **/__pycache__/ **/*.pyc
 M dot_config/eww/components/common.yuck
 M dot_config/eww/scripts/executable_launch.sh
D  dot_config/eww/scripts/executable_network-status.sh
D  dot_config/eww/scripts/executable_network-wired-detail.sh
 D dot_config/eww/scripts/executable_shichen.sh
 D dot_config/eww/scripts/executable_sysinfo.sh
?? dot_config/eww/ewwstate/             # 框架 + 10 个 collector
?? dot_config/eww/scripts/executable_ewwstate
```

---

## 3. 剩余工作（8 单元，12 topic）

未迁清单（已用「合并多行块」的准确方法核对，**别用只匹配 defpoll 起始行的 grep，会假阴性**）：

**defpoll 旧/内联（9）**：`workspaces` `dnd` `brightness` `notif_count` `notifications` `media` `events` `weather` `countdown`
**deflisten 旧（3）**：`updates_checking` `updates` `update_list`

| 单元 | topic | 采集器类型 | 旧脚本/内联 | onclick 删留预判 | 所在窗口 | 注意 |
|---|---|---|---|---|---|---|
| **U10** | notif_count, notifications, dnd | Poll（dnd 可 Event: dbus/inotify dunst） | notif-count.sh, notif-yuck.sh；dnd 内联 `dunstctl is-paused` | 全树 grep `notif-count.sh`/`notif-yuck.sh`/`dunstctl`（clear-notifs.sh? toggle-dnd.sh?） | notification-popup + bar(notif_count badge) | notif-yuck 是 yuck-literal（每行多次 jq，迁后改纯 python 拼）；notify-send 发一条实测 badge |
| **U11** | brightness | Poll | **内联** `brightnessctl info`（无独立脚本，无旧脚本可删） | grep `brightnessctl`（osd.sh? brightness-auto.sh? 动作脚本保留） | control-center + osd | 解析 `(NN)%`；async `brightnessctl -m info` 或 `g` 更稳 |
| **U12** | media | Poll→可 Event（playerctl 无原生订阅，先 Poll） | media.sh | grep `media.sh`/`playerctl`（media-ctl.sh 动作保留） | control-center | JSON `{has,title,artist,status,icon}` |
| **U13** | workspaces | **Event**（i3 ipc socket 订阅 workspace 事件，零轮询） | workspaces.sh | grep `workspaces.sh`（onclick 是 yuck literal 内联 `i3-msg workspace N`，无脚本引用 → **可删**） | **bar（始终可见，非懒加载）** | 当前 500ms poll 是最大进程源；改 i3 ipc 事件驱动收益大；yuck-literal 拼天干地支 seal |
| **U14** | weather | Poll（保留 /tmp 30min 缓存逻辑） | weather.sh | grep `weather.sh`（应无 onclick → 可删） | calendar-popup | `curl wttr.in` 慢，async + 缓存 |
| **U15** | countdown | Poll | countdown.sh | grep `countdown.sh`（应无 → 可删） | calendar-popup | 读 `countdown.txt` 或算周末 |
| **U16** | events | Poll 或 inotify Event | events.sh | grep `events.sh`（应无 → 可删） | calendar-popup | 读 `events.json` 拼 yuck-literal |
| **U17** | updates_checking, updates, update_list | **listen 一致性迁移**（保留 inotify 模型，或并入 daemon 的 EventCollector 监听同一缓存目录） | update-listen-checking/updates/list.sh | grep 三者 + `check-updates.sh`/`update-trigger.sh`/`update-apply.sh`（动作保留） | updates-popup | **最复杂**：`update_list` 脚本里 `eww get updates_filter` 交叉读 eww 变量——迁时这个交叉读要保留或改由 daemon 维护 filter 状态；trigger 一次实测整链 |
| **U18** | 收尾 | — | 清除所有遗留死代码 | — | bar 全量回归 | 全量 `chezmoi diff` 应只剩 `.pi` 无关冲突；逐 popup 截图回归 |

> 单元编号可微调，但**一次只做一个单元、做完验证再下一个**（用户硬性要求）。

---

## 4. 验证方案（每个单元强制 7 步，缺一不可）

1. **写采集器** `collectors/<name>.py`（topic==变量名，值==旧脚本字符串）。
2. **离线对等校验**（apply 前）：`asyncio.run(Collector(store).collect())` 的每个 topic 与旧脚本/旧命令输出比对。**不一致就改采集器，绝不带病上线。** 比对三策略：
   - **标量** → 逐字节相等。
   - **JSON** → `json.loads` 后比 dict（PUA 图标 `\uXXXX` 转义 vs 原始 UTF-8 对 eww 等价，逐字节会假阴性）。
   - **yuck-literal** → 比结构 + 关键 token（如提取 `bt-action.sh <act> <mac>` 集合、SSID 列表、connected class），**不强求逐字节**（信号强度/cpu/watts 等实时量采样窗口不同本就不等，瞬时不等反而证明变量是活的）。
3. **改 `common.yuck`** 对应 defpoll/deflisten 的命令为 `ewwstate get <t> '<fallback>'` / `ewwstate listen <t>`。**含括号/`$`/空格的 fallback 必须单引号**（踩坑 #8）。interval 保持原值。
4. **apply + reload**：`chezmoi apply --force ~/.config/eww` → `i3-msg exec launch.sh`。
5. **自动化校验**：`ewwstate status` 存活 + 该 collector 出现在 `starting N collector(s)` 日志；daemon 日志无 exception/traceback；每个 topic `eww get == ewwstate get`（**popup-only 变量必须先打开 popup**，踩坑 #1）。
6. **视觉校验**：`maim` 截 bar；**凡组件在某 popup，必须打开该 popup 再截一张**，肉眼确认 widget 正常。**截图 read 前必压缩**（踩坑 #13）。
7. **清理旧脚本**：**先全树 grep**（`grep -rn "<脚本名>" dot_config/eww`，含 `scripts/`！踩坑 #4）；仅被 defpoll/deflisten 引用且无 onclick → `git rm 源 + rm 目标`（踩坑 #3）；有 onclick 引用 → **保留**。

**打开 popup 的方法**：优先 `~/.config/eww/scripts/open-popup.sh <name>`；若它因鼠标 anchor 算空而失败（踩坑 #10），用显式坐标兜底：
```bash
eww open <name> --arg pos_x=1850px --arg pos_y=40px
eww update popup_open="<name>"     # 触发懒加载
# 若该 popup 有 scan-on-open 等副作用（如 bluetooth），按需复刻，如 ~/.config/eww/scripts/bt-scan.sh on
```
**判断 popup 是否打开**：`eww get popup_open`（值==popup 名；`none`=全关）。**别用 `eww list-windows`**（它列所有*定义*的窗口，踩坑 #2）。

---

## 5. 工作经验 / 踩坑铁律（最值钱，逐条带「为什么+怎么做」）

1. **eww 0.5 defpoll 可见性懒加载**：变量只在被*当前可见窗口*引用时才轮询。只被 popup 引用的变量，popup 关闭时**永远停 `:initial`**，打开后才轮询。**这是正常行为不是 bug**（旧脚本也一样）。→ 验证 popup-only 变量**必须打开 popup 测**；在 bar 态测到 initial 不算失败。bar 始终可见的变量（workspaces/clock/battery/network_status/notif_count badge）才会一直轮询。
2. **`eww list-windows` 列定义窗口非打开窗口** → 用 `eww get popup_open` 判断开关。
3. **删旧脚本 = `git rm <源>` + `rm <目标>`**。`chezmoi apply ~/.config/eww`（子树）**不删**源已移除的孤儿目标（删除无 target 映射，不在子树匹配集）；全量 apply 又被 `.pi` 冲突阻塞（#12），故手动删目标。
4. **删前必须全树 grep（含 `scripts/`，不只 `components/`）**：`grep -rn "<脚本名>" dot_config/eww`。onclick 动作脚本（`*-action.sh`/`toggle-*.sh`/`cc-action.sh`/`open-popup.sh`）常在「乐观更新」里**当场调用状态脚本**做点击瞬间反馈（daemon 3s 异步采集做不到即时性）→ **该状态脚本必须保留**，即使其 defpoll 已迁 daemon。U2 曾因只 grep `components/` 漏掉 `cc-action.sh:23` 误删 `night-light-on.sh`，已 `git restore` 恢复。
5. **pyc 治理**：daemon 启动带 `PYTHONDONTWRITEBYTECODE=1`（永不写 pyc，已加进 launch.sh）；`.chezmoiignore` 用 `**/__pycache__/` + `**/*.pyc`（doublestar 需 `**/` 前缀才匹配嵌套目录，已加）。运行时 pyc 一旦进 chezmoi 记录会反复触发无 TTY 的 apply 冲突 → 用 `chezmoi apply --force` 清残留。**每次 apply 前** `find dot_config/eww/ewwstate -name __pycache__ -exec rm -rf {} +`（在源目录跑过 python import 会生成 pyc）。
6. **无 TTY 下 `eww logs` 抓不到**（连 `script` 伪 TTY 也会把 agent 会话带乱，整段命令无回显）。→ 调试 defpoll 是否执行用「probe 副作用」：临时把命令改成 `echo "$(date +%s) HOME=$HOME" >> /tmp/probe; <原命令>`，看文件是否生成。
7. **`pkill -f '<模式>'` 会杀执行该命令的 bash 自身**（命令串含该字面模式，整段命令静默无输出）。→ 用字符类排除自身：`pkill -f '[e]wwstate/main.py daemon'`。
8. **defpoll 命令里含括号的 fallback 必须单引号**：`ewwstate get <t> (box)` 时 eww 用 `sh -c` 执行，裸 `(box)` 被当子 shell 语法 → exit 2 → 变量永远 initial。→ 写 `ewwstate get <t> '(box)'`。同理含 `()`/`$`/空格的 fallback 都要引号。U8 的 wifi_networks/wired_detail 踩过。
9. **对等校验的「实时抖动量」瞬时不等是正常的**：`watts`/`cpu`/`mem`/`temp` 采样窗口不同，校验脚本里 eww 值与 daemon 值差一点，恰恰证明变量在更新，**不是迁移错误**。对这类字段断言「类型+范围+量级」而非相等。
10. **`open-popup.sh` 的 anchor 依赖鼠标坐标 `$mouse_x`**，agent 无鼠标移动环境下偶发算空 → `eww open` 缺 `pos_x` 失败，popup 打不开（`popup_open` 仍 none）。**这是既有脆弱性，与迁移无关**（没改 open-popup 的 anchor 逻辑）。→ 验证时用 #4 节的显式坐标兜底。
11. **JSON 型 topic 对等用解析后比 dict**，不要逐字节（PUA/转义/键序差异会假阴性）。但采集器**手拼 JSON 时键序要与旧 printf 模板一致**（eww 按字段取，键序其实不影响，但便于人眼 diff）。
12. **`chezmoi apply`（无参）会卡在无关的 `.pi/agent/settings.json` 冲突**（外部改动+无 TTY 无法提示，exit 1）。→ **永远只 apply eww 子树**：`chezmoi apply --force ~/.config/eww`。`.pi` 冲突是历史遗留，需用户单独处理（`chezmoi re-add` 或 `--force` 全量），**不在本重构范围**。
13. **截图超体积**：`maim` 全屏 PNG ~1.5MB，read 会超上下文体积限制。→ read 前先压缩：`convert <in> -resize 1280x -strip <out>`（或 `magick`/`ffmpeg`），read 压缩版。IMv7 下 `convert` 会有 deprecation 警告但能用。
14. **多行 defpoll 的 grep 陷阱**：`grep "^\(defpoll"` 只匹配起始行，命令在续行 → 判断「是否已迁」会假阴性。→ 统计已迁/未迁用 `grep -oE "ewwstate (get|listen) [a-z_]+"` 取已迁 topic 集，与 `grep -oE "\(defpoll [a-z_]+"` 全集做差集；或用 awk 把多行块合并再看命令。

---

## 6. 常用命令速查

```bash
# daemon
~/.config/eww/scripts/ewwstate status              # 是否存活
~/.config/eww/scripts/ewwstate dump                # 所有 topic 当前值
tail -f /tmp/ewwstated.log                         # 采集日志（看 starting N / exception）
python3 ~/.config/eww/ewwstate/main.py daemon      # 前台跑看 stderr（调试用）

# 对等校验模板（离线，apply 前）
cd /home/yuez/.local/share/chezmoi/dot_config/eww/ewwstate
python3 -c "import sys,asyncio,json; sys.path.insert(0,'.'); from collectors.<X> import <C>; from store import StateStore; print(asyncio.run(<C>(StateStore('/tmp/_eq')).collect()))"

# 重载
cd /home/yuez/.local/share/chezmoi
find dot_config/eww/ewwstate -name __pycache__ -exec rm -rf {} + 2>/dev/null
chezmoi apply --force ~/.config/eww
i3-msg exec ~/.config/eww/scripts/launch.sh

# 打开 popup 验证（兜底坐标）
eww open <name> --arg pos_x=1850px --arg pos_y=40px; eww update popup_open="<name>"

# 截图+压缩
maim /tmp/eww-screenshots/<tag>-$(date +%H%M%S).png
ls -t /tmp/eww-screenshots/<tag>-*.png | grep -v small | head -1 | xargs -I{} convert {} -resize 1280x -strip /tmp/eww-screenshots/<tag>-small.png

# 全树 grep 决定删留
grep -rn "<脚本名>.sh" /home/yuez/.local/share/chezmoi/dot_config/eww
```

---

## 7. 当前实时状态快照（2026-07-24 21:19）

- daemon：**running**，10 collectors：`airplane, audio, battery, bluetooth, clock, network, nightlight, powerinfo, powerprofile, sysinfo`。
- `popup_open`：上个窗口留为 `bluetooth-popup`（**接手先复位**，见 §0）。
- 已迁 25 topic（见 §2 + §3 顶部准确清单）；未迁 12 topic（见 §3 表）。
- 未提交 git 改动见 §2 末尾。
- 框架本体 + README（`dot_config/eww/ewwstate/README.md`，含本文 §5 的踩坑要点精简版）已就位。

**下一步建议**：从 **U10（notif_count/notifications/dnd）** 或 **U11（brightness，最简单，无旧脚本）** 开始。brightness 风险最低，可先做热身。每个单元严格走 §4 的 7 步，做完一个验证一个，**不要并行**。全部完成后做 U18 收尾回归。
