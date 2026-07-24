# 踩坑铁律

每条带**为什么**和**怎么做**。按严重程度排序。

---

## 1. eww 0.5 defpoll 可见性懒加载

**为什么**：变量只在被*当前可见窗口*引用时才轮询。只被 popup 引用的变量，popup 关闭时永远停 `:initial`，打开后才轮询。这是正常行为不是 bug。

**怎么做**：验证 popup-only 变量**必须打开 popup 测**；在 bar 态测到 initial 不算失败。bar 始终可见的变量（workspaces/clock/battery/network_status/notif_count badge）才会一直轮询。

---

## 2. `eww list-windows` 列定义窗口非打开窗口

**为什么**：它返回所有 `(defwindow ...)` 定义，不管是否 `eww open` 过。

**怎么做**：用 `eww get popup_open` 判断开关（值==popup 名；`none`=全关）。

---

## 3. 删旧脚本 = `git rm <源>` + `rm <目标>`

**为什么**：`chezmoi apply ~/.config/eww`（子树）不删源已移除的孤儿目标（删除无 target 映射，不在子树匹配集）。

**怎么做**：两步都做。

---

## 4. 删前必须全树 grep（含 scripts/）

**为什么**：onclick 动作脚本（`*-action.sh`/`toggle-*.sh`/`cc-action.sh`/`open-popup.sh`）常在「乐观更新」里当场调用状态脚本做点击瞬间反馈（daemon 3s 异步采集做不到即时性）→ 该状态脚本必须保留，即使其 defpoll 已迁 daemon。

**怎么做**：`grep -rn "<脚本名>" dot_config/eww`（含 `scripts/`，不只 `components/`）。U2 曾因只 grep `components/` 漏掉 `cc-action.sh:23` 误删 `night-light-on.sh`。

---

## 5. pyc 治理

**为什么**：运行时 pyc 一旦进 chezmoi 记录会反复触发无 TTY 的 apply 冲突。

**怎么做**：
- daemon 启动带 `PYTHONDONTWRITEBYTECODE=1`（已加进 launch.sh）
- `.chezmoiignore` 用 `**/__pycache__/` + `**/*.pyc`
- **每次 apply 前** `find dot_config/eww/ewwstate -name __pycache__ -exec rm -rf {} +`

---

## 6. 无 TTY 下 `eww logs` 抓不到

**为什么**：`eww logs` 是流式订阅者，在 agent 里无限阻塞。连 `script` 伪 TTY 也会把 agent 会话带乱。

**怎么做**：调试 defpoll 是否执行用「probe 副作用」：临时把命令改成 `echo "$(date +%s)" >> /tmp/probe; <原命令>`，看文件是否生成。daemon 侧看 `/tmp/ewwstated.log`。

---

## 7. `pkill -f '<模式>'` 会杀自身

**为什么**：命令串含该字面模式，整段命令静默无输出。

**怎么做**：用字符类排除自身：`pkill -f '[e]wwstate/main.py daemon'`。

---

## 8. defpoll 命令里含括号的 fallback 必须单引号

**为什么**：`ewwstate get <t> (box)` 时 eww 用 `sh -c` 执行，裸 `(box)` 被当子 shell 语法 → exit 2 → 变量永远 initial。

**怎么做**：写 `ewwstate get <t> '(box)'`。同理含 `()`/`$`/空格的 fallback 都要引号。

---

## 9. 实时抖动量瞬时不等是正常的

**为什么**：`watts`/`cpu`/`mem`/`temp` 采样窗口不同。

**怎么做**：校验脚本里对这类字段断言「类型+范围+量级」而非相等。瞬时不等恰恰证明变量在更新。

---

## 10. `open-popup.sh` 的 anchor 依赖鼠标坐标

**为什么**：agent 无鼠标移动环境下 `$mouse_x` 偶发算空 → `eww open` 缺 `pos_x` 失败。这是既有脆弱性，与迁移无关。

**怎么做**：验证时用显式坐标兜底：`eww open <name> --arg pos_x=1850px --arg pos_y=40px`。

---

## 11. JSON 型 topic 对等用解析后比 dict

**为什么**：PUA/转义/键序差异会逐字节假阴性。

**怎么做**：`json.loads` 后比 dict。但采集器手拼 JSON 时键序要与旧 printf 模板一致（便于人眼 diff）。

---

## 12. `chezmoi apply`（无参）会卡在 `.pi` 冲突

**为什么**：外部改动+无 TTY 无法提示，exit 1。

**怎么做**：**永远只 apply eww 子树**：`chezmoi apply --force ~/.config/eww`。

---

## 13. 截图超体积

**为什么**：`maim` 全屏 PNG ~1.5MB，read 会超上下文体积限制。

**怎么做**：read 前先压缩：`convert <in> -resize 1100x -strip <out>`。IMv7 下 `convert` 有 deprecation 警告但能用。

---

## 14. 多行 defpoll 的 grep 陷阱

**为什么**：`grep "^\(defpoll"` 只匹配起始行，命令在续行 → 判断「是否已迁」会假阴性。

**怎么做**：用 `grep -oE "ewwstate (get|listen) [a-z_]+"` 取已迁 topic 集做差集；或用 awk/python 把多行块合并再看命令。

---

## 15. i3 IPC 消息对齐

**为什么**：i3 可能在 `get_workspaces` 回复（payload=list）前插入 workspace 事件（payload=dict）。朴素的「发一条读一条」模式会把 dict 误当 list 喂给 `_build_yuck` → `AttributeError: 'dict' object has no attribute 'sort'`。

**怎么做**：用 high-bit（`0x80000000`）区分事件/回复 + pending 请求跟踪 + 合并去重。见 [collector-patterns.md](collector-patterns.md) 的 i3 IPC 节。

---

## 16. bash `$(...)` strip 尾部换行

**为什么**：bash 的 `$(cmd)` 会 strip 尾部 `\n`，Python `json.loads` 不会。如果旧脚本用 `$(dunstctl history)` 再传给 jq，而 collector 直接 `json.loads(raw)`，body 文本可能多一个 `\n`。

**怎么做**：对从 JSON 提取的文本字段 `.rstrip("\n")`。

---

## 17. JSON 紧凑格式

**为什么**：旧脚本用 `jq -c .` 输出紧凑 JSON（无空格）。Python `json.dumps` 默认 `", "` / `": "` 带空格。

**怎么做**：`json.dumps(data, ensure_ascii=False, separators=(",", ":"))`。

---

## 18. EventCollector 的 inotifywait 进程泄漏

**为什么**：如果 `run()` 里的 `while True` 在 `create_subprocess_exec` 后异常退出但没 kill 子进程，inotifywait 会泄漏。

**怎么做**：daemon 的 `_supervised` 会在 crash 后重启 collector，但旧 inotifywait 进程不会自动死。确保 `run()` 的异常路径能走到下一次循环的 `create_subprocess_exec`（旧 proc 被 GC 时 fd 关闭 → inotifywait 收到 SIGPIPE 退出），或在 `teardown()` 里显式 kill。

---

## 19. 乐观更新脚本必须保留

**为什么**：daemon 采集有 interval 延迟（1-3s），用户点击 toggle 按钮后需要**即时**反馈。动作脚本（如 `toggle-dnd.sh`）里 `eww update dnd="$(dunstctl is-paused)"` 提供零延迟反馈，daemon 随后异步校正。

**怎么做**：迁 defpoll/deflisten 时，只改 `common.yuck` 的命令；动作脚本里调用的状态脚本（如 `media.sh`、`power-profile.sh`）**必须保留**。

---

## 20. PUA 图标码位禁止手猜——用 fonttools 查 cmap

**为什么**：Nerd Font 的 PUA 区域映射因版本/构建而异。手敲 `\uf1165` 以为是 USB 图标，实际渲染成纸飞机；`\uf01bc` 以为是 eject，实际是 database。肉眼猜码位 = 100% 出错。

**怎么做**：
1. 用 fonttools 查规范 glyph 名对应的精确码位：
   ```python
   from fontTools.ttLib import TTFont
   t = TTFont("/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf")
   cmap = t.getBestCmap()
   for cp, name in sorted(cmap.items()):
       if "eject" in name.lower() or "usb" in name.lower():
           print(f"U+{cp:04X}  {name}")
   ```
2. 在 collector 里用 `chr(0xF0553)` 注入到 JSON 字段（如 `"icon"`、`"eject_icon"`），**yuck 模板里零 PUA 字符**。
3. 如果系统 python 受 PEP 668 限制装不了 fonttools，用 mise 的 python：
   ```bash
   MPY=$(ls -d ~/.local/share/mise/installs/python/*/bin/python3 | tail -1)
   "$MPY" -m pip install --quiet fonttools
   ```

---

## 21. sysfs uevent 不含 ID_FS_TYPE——用 lsblk

**为什么**：`/sys/block/sda/sda1/uevent` 只有 MAJOR/MINOR/DEVNAME/DEVTYPE/PARTN 等内核属性，**不含** udev 数据库里的 `ID_FS_TYPE`。`blkid` 在用户级也可能返回空。启动扫描用 `grep ID_FS_TYPE uevent` 会静默失败。

**怎么做**：用 `lsblk -no FSTYPE /dev/$pname` 读 udev 数据库，用户级可用、零权限问题。同理 `lsblk -no LABEL` 读分区标签。

---

## 22. rotational sysfs 对 USB 闪存盘误报

**为什么**：`/sys/block/sda/queue/rotational` 对某些 USB 闪存盘返回 `1`（内核误判），用它区分 HDD/USB 图标会导致 U 盘拿到机械硬盘图标。

**怎么做**：不要用 rotational 做图标分支。可移动设备统一用一个 USB 图标（`md-usb` U+F0553），或按 fstype/容量做启发式，但**绝不**依赖 rotational。

---

## 23. udevadm monitor 事件过滤——只监听 add

**为什么**：`udevadm monitor --subsystem-match=block` 的 `change` 事件在 mount/unmount 时都会触发。如果自动挂载 daemon 对 `change` 也执行 mount，用户主动弹出（unmount）后 daemon 会**立刻重挂**，弹出被静默撤销，表现为"点弹出没反应"。

**怎么做**：daemon 的事件循环只处理 `ACTION=add`（设备插入创建分区节点），忽略 `change`（mount/unmount 状态变化）。已插入但未挂载的设备由启动时一次性扫描处理。

---

## 24. pkill -f 自杀的深层变体——字符类只保护 pgrep 自身

**为什么**：gotcha #7 说字符类 `[e]wwstate` 排除自身。但这只保护 **pgrep/pkill 自己的参数字符串**。如果你的 bash 脚本里**别处**出现了连续匹配字面（如 `setsid bash .../automount-daemon.sh` 这行路径、echo 文本），当前 bash 的 cmdline 整段含该字面，`$(pgrep -f ...)` 仍会把当前 bash 列进去 → kill 自身 → 缓冲丢失、后续命令全不执行。

**怎么做**：
1. **pidfile 方案**（最可靠）：daemon 启动时 `echo $$ > /tmp/xxx.pid`，清理时按 pid 精确 kill，完全不匹配命令行。
2. **写文件再 bash 执行**：把含匹配字面的逻辑写进 `/tmp/t.sh`，用 `bash /tmp/t.sh` 跑。因为 `bash 文件` 的 cmdline 只有 `bash /tmp/t.sh`，不含脚本内容。
3. 字符类仍作为双保险用在 pgrep 参数上，但**不能**作为唯一防线。
