# ewwstate — 统一状态采集框架

一个常驻 asyncio daemon 集中采集所有系统状态，写入 tmpfs 镜像；eww 侧的读取
只是 `cat` 一个文件，**永不触发采集、永不阻塞**。采集与获取彻底解耦。

## 架构

```
collectors/*.py ─(各自独立 asyncio task)─▶ StateStore ─原子写─▶ $XDG_RUNTIME_DIR/ewwstate/<topic>
                                                                      │
                       eww defpoll  → ewwstate get <topic>   (cat 文件，瞬时)
                       eww deflisten→ ewwstate listen <topic> (cat + inotify)
```

- 每个 collector 是独立 task；某个崩溃由 supervisor 指数退避重启，互不影响。
- 慢采集（`tlpctl`、`curl wttr.in`）只占自己的 task，不阻塞别人，更不阻塞读取。
- 文件镜像意味着 daemon 崩了 eww 仍显示最后采集的值。

## 添加一个 collector（扩展注册）

在 `collectors/` 新建文件，用装饰器即可，daemon 启动自动发现，无需其它接线：

```python
from framework import PollCollector, collector   # 或 EventCollector
from util import run, shell, read_sysfs, sysfs_glob

@collector
class Battery(PollCollector):
    name = "battery"                       # 日志 / refresh 用的唯一 id
    topics = ("battery_percent",)          # 发布的 topic（== eww 变量名）
    interval = 5.0

    async def collect(self):
        return {"battery_percent": "87"}   # 值 == 旧脚本打印的字符串
```

事件驱动型（订阅 `pactl subscribe` / i3 ipc / inotify / D-Bus）：

```python
@collector
class Workspaces(EventCollector):
    name = "workspaces"
    async def run(self):
        while True:
            ...                            # await 事件源
            await self.store.set("workspaces", value)
```

## 约定（让迁移 = 纯换命令）

1. **topic 名 == eww 变量名**。
2. **采集器产出的值 == 旧脚本打印的字符串**（标量 / JSON / yuck-literal 原样）。

因此 `common.yuck` 迁移只改命令：

```yuck
;; 旧
(defpoll battery_percent :interval "5s" :initial "100" "~/.config/eww/scripts/battery-percent.sh")
;; 新（fallback 与 :initial 一致，避免 daemon 未就绪时闪空）
(defpoll battery_percent :interval "5s" :initial "100" "~/.config/eww/scripts/ewwstate get battery_percent 100")
```

## 规则

- collector **必须非阻塞**：用 `util.run()` / `util.shell()`（async 子进程），
  绝不用 `subprocess.run()`。
- `util.read_sysfs()` / `sysfs_glob()` 读 sysfs/procfs。

## CLI

```
ewwstate daemon                 前台运行 daemon（由 launch.sh 以 nohup 拉起）
ewwstate get <topic> [fallback] 读 topic 最后值（不依赖 daemon 存活）
ewwstate listen <topic>         输出当前值并在变化时重发（供 deflisten）
ewwstate dump                   打印所有 topic
ewwstate status                 daemon 是否存活
```

## 调试

```bash
python3 ~/.config/eww/ewwstate/main.py daemon     # 前台跑，看 stderr 日志
~/.config/eww/scripts/ewwstate dump               # 看当前所有状态
```

## 验证要点（踩坑沉淀，每个单元必读）

1. **eww 0.5 的 defpoll 是「可见性懒加载」**：一个变量只在被*当前可见窗口*引用时才轮询。
   只被某个 popup 引用的变量，popup 关闭时**永远停在 `:initial`**，打开后才轮询。
   这是*正常行为*（旧脚本也一样），不是迁移 bug。所以验证 popup-only 变量
   **必须打开对应 popup 再测**（`open-popup.sh <name>`），在 bar 态测到 initial 不算失败。
2. **`eww list-windows` 列出的是*所有定义的窗口*，不是*当前打开的窗口***。
   判断某 popup 是否打开用 `eww get popup_open`（值 == popup 名）。
3. **删除已无引用的旧脚本**：`git rm <源文件>` + `rm <目标文件>`。
   `chezmoi apply ~/.config/eww`（子树）**不会删除**源已移除的孤儿目标
   （删除无 target 映射，不在子树匹配集）；全量 apply 又常被无关的 `.pi`
   冲突阻塞，故手动删目标。
   **删除前必须 grep 整个 `dot_config/eww/`（含 `scripts/`，不只 `components/`）**，
   用脚本文件名搜。onclick 动作脚本（`cc-action.sh` / `*-action.sh` /
   `toggle-*.sh`）常在「乐观更新」里**当场调用状态脚本**做点击瞬间反馈
   （例：`cc-action.sh night-light` 切 redshift 后 `sleep 0.3` 再
   `eww update night_light="$(night-light-on.sh)"`）。这种当场同步判断是
   daemon 的 3s 异步采集做不到的，**该状态脚本必须保留**——即使它的 defpoll
   已迁 daemon。只删「仅被 defpoll/deflisten 引用」的脚本。
   （U2 曾因只 grep `components/` 漏掉 `cc-action.sh` 的引用而误删，已恢复。）
4. **pyc 污染**：daemon 启动带 `PYTHONDONTWRITEBYTECODE=1`（永不写 pyc），
   `.chezmoiignore` 用 `**/__pycache__/` + `**/*.pyc`（doublestar 需 `**/` 前缀
   才匹配嵌套目录）。运行时 pyc 一旦进 chezmoi 记录，会反复触发无 TTY 的
   apply 冲突；用 `chezmoi apply --force` 清掉残留记录。
5. **`eww logs` 在无 TTY 环境抓不到**（连 `script` 伪 TTY 也会把 agent 会话带乱）。
   调试 defpoll 是否执行，用「probe 副作用」：临时把命令改成
   `echo "$(date +%s) HOME=$HOME" >> /tmp/probe; <原命令>`，看文件是否生成。
6. **`pkill -f '<模式>'` 会杀掉执行该命令的 bash 自身**（命令串含该字面模式）。
   用字符类技巧排除自身：`pkill -f '[e]wwstate/main.py daemon'`。
7. **defpoll 命令里含括号的 fallback 必须加单引号**：`(box)` 作为
   `ewwstate get <t> (box)` 的 fallback 时，eww 用 `sh -c` 执行，裸 `(box)`
   被 shell 当子 shell 语法 → exit 2 → 变量永远停在 initial。写成
   `ewwstate get <t> '(box)'`。同理任何含 `()`/`$`/空格的 fallback 都要引号。
   （U8 的 wifi_networks/wired_detail 踩过。）
