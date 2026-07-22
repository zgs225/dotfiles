# eww 交互设计 · 反馈纪律

> 本文件是 eww 组件**交互行为**（点击响应、状态刷新、异步操作、弹层进出）的唯一权威依据。
> 视觉规范（配色 / 圆角 / 透明度 / 字体）见 `song-liquid-glass.md`；本文件只管「点了之后发生什么」，不管「长什么样」。两份文档互不重叠：前者管"宋式克制"的皮相，本文件管"即时响应"的筋骨。
> 由来：2026-07-22 全量排查"点击后卡几秒没反应"的实录沉淀，并对照 Apple《Designing Fluid Interfaces》(WWDC 2018) 与《Principles of Great Design》的交互哲学。

适用环境：Arch Linux + X11 + i3wm + eww 0.5.0

---

## 0. 一句话

eww 的点击天生"慢半拍"——`onclick` 有 200ms 死刑、界面状态靠 1–5s 轮询刷新——于是每一次点击都在和"卡死感"赛跑。**交互设计的全部工作，就是把"用户点了"到"界面回应"之间的每一毫秒都抢回来**：长操作立刻甩到后台、状态当场乐观翻转、真实结果事后校准。Apple 把这叫"kill latency"，我们把它落成一套可复用的脚本范式。

---

## 1. 设计哲学：克制的皮相 ≠ 沉默的交互

`song-liquid-glass.md` 定下"宋式极简"：单色釉、拒弹跳、动效只是"墨色深浅的呼吸"。这条纪律约束的是**视觉装饰**，绝不约束**反馈**。两者必须分清，否则会把"克制"误做成"点了没反应"：

| 该克制的（视觉） | 该保证的（交互） |
|---|---|
| 不加弹跳 / 位移 / 阴影动画 | 点击 100ms 内必有状态回应 |
| 不堆循环动效（仅 urgent 印章豁免） | 长操作必有"进行中"指示 |
| 色彩服从令牌纪律 | 成功 / 失败必有明确结局反馈 |

> **裁定**：宋式的"静"是去掉花哨动画，不是去掉反馈。一个安静地、即时地翻转高亮的开关，比一个弹跳三下才亮的开关更合宋意，也更合 Apple 的"响应"原则。

取 Apple 交互哲学中**与 eww 相关的四条**，作为本文件的上位原则（eww 是声明式 GTK bar/弹层系统，不是手势系统——Apple 的弹簧 / 动量 / 橡皮筋 / 速度交接在此**不适用**，我们不搬其手势机制，只取其交互观）：

1. **响应（Response）**——延迟一出现，"跟手感"就悬崖式崩塌。响应是一切的地基。
2. **可打断（Interruptibility）**——Apple 称之为"最重要的单一原则"：任何操作期间都不得锁死输入，用户随时能再次点击、改主意。
3. **空间一致（Spatial consistency）**——从哪来，回哪去；弹层锚定在触发它的组件下方。
4. **反馈四态（Feedback kinds）**——状态（进行中）、完成、警告、错误，各归其位；只在有意义的时刻打扰用户。

这四条服务 Apple 归纳的四种人的需求：**安全可预期、可理解、可达成、愉悦**。点击有回应＝安全可预期；进行中指示＝可理解；一键达成＝可达成；安静即时＝愉悦。

---

## 2. eww 交互的物理定律（不可违背，附实测）

设计前必须接受这套底层机制，所有范式都是对它的顺应：

| # | 定律 | 后果 | 实测（本机） |
|---|------|------|------|
| 1 | **`onclick` 有 200ms SIGKILL**：eww 跑完 onclick 命令的时限是 200ms，超时直接杀进程（`crates/eww/src/widgets/mod.rs`） | 任何 >200ms 的 onclick 会被腰斩，里面的 `eww update` 永远跑不到 | 硬上限 200ms |
| 2 | **状态由 `defpoll`/`deflisten` 驱动**：点击**不会**自动刷新界面，要等下一次轮询 | 动作完成后界面干等一个轮询周期才变 | 轮询间隔 1–5s |
| 3 | **`defpoll` 按需运行**：没有任何打开的窗口引用某变量时，该轮询停摆 | 弹层关闭时其变量停在 `:initial`；打开后才开始刷 | — |
| 4 | **`eww update <var>` 是即时反馈通道**：直接改变量，绑定它的窗口立即重绘 | 这是绕开轮询、做即时反馈的唯一手段 | 往返 **3ms** |
| 5 | **`eww open`/`close` 异步**：命令返回 ≠ 窗口已存在/消失（GTK 主线程异步执行） | 基于陈旧状态做决策会让 close 落在 queued open 之前，留下孤儿窗口 | — |

**人感延迟阈值**（Nielsen，Apple 亦引为"延迟悬崖"）：

| 延迟 | 感受 | 本文件红线 |
|---|---|---|
| ≤ 100ms | 即时，"跟手" | **点击反馈必须落在此区间** |
| ~1s | 流程不断但可察觉卡顿 | 长操作的"进行中"指示须先于此出现 |
| ~10s | 注意力涣散，以为死了 | 任何操作不得无反馈超过此值 |

原始 bug 的本质：点击 → 后台动作 → 状态绑定 1–5s 轮询 → **数秒落在 1s–10s 的"以为死了"区间**。

---

## 3. 核心失败模式（病根，两种亚型）

所有"点了没反应"都归到两类：

- **A. 反馈被杀**：脚本里写了 `eww update` 即时刷新，但脚本没 detach，总耗时 >200ms 被 eww 杀掉 → `eww update` 根本没执行 → 只能等轮询。
  - 实例（修复前）：`toggle-wifi.sh`（`sleep 0.5` + 3 次 update 必超 200ms）、`toggle-airplane.sh`（**完全没写 update**，且轮询是 5s）。
- **B. 慢操作无即时反馈**：动作 detach 了（点击本身秒回），但 UI 状态绑在轮询上，动作完成后没有主动 `eww update` → 干等一个周期。
  - 实例（修复前）：电源模式切换（`power-profile.sh set`，绑定 3s 轮询）、充电阈值（`sudo + tlp start` ≈ 628ms 之后才刷新）。

> 反面教材的正面范本：`bt-action.sh` 早已用对——detach + 即时 `bt_notice`"正在连接…" + 完成后 refresh。本次修复就是把这套范式推广到全部交互。

---

## 4. 四条反馈纪律

### 4.1 响应：100ms 内必给反馈，且反馈在"过程中"

- 点击的物理响应（高亮翻转 / 开关切换 / "进行中"出现）必须 ≤100ms。
- eww 的 `onclick` 在**抬起**时触发（无法做到 Apple 的 pointer-down 即响应），这是平台天花板；正因如此，onclick 一触发就必须**立刻**给反馈，不能再叠加任何同步等待。
- 长操作的反馈不能只在终点：连接 Wi-Fi 的 5–15s 里，必须**全程**显示"连接中…"，而非结束才变——呼应 Apple"反馈要在交互过程中持续，而非仅在末尾"。

### 4.2 可打断：长操作必 detach，绝不锁死输入

- 任何可能 >200ms 的 onclick 脚本，开头立即 detach（§7.1），让 eww 杀不到它，点击本身瞬间返回。
- 用户连点 / 改主意必须被尊重：乐观更新从**当前意图**出发即时改写状态（§4.3），后一次点击立即覆盖前一次——Apple"动画从当前值出发、随时可被重定向"在 eww 的对应物。
- 不得在操作期间禁用点击（除非该操作物理上不可重入，如 `eww open/close` 需串行锁——见 §6.8 的 fd 纪律）。

### 4.3 乐观更新 + 事后校准（poll 是安全网）

慢操作的标准三段式：

1. **乐观翻转**：点击瞬间，用"点击意图"直接改写状态变量（不读慢源），高亮即时落位。
2. **执行真实动作**：后台跑慢命令（`tlpctl set` / `sudo` / `nmcli connect`）。
3. **事后校准**：动作完成后用真实查询刷新；**成功则把乐观字段钉住**（见下），失败则还原真实值并报错。

**为什么乐观更新安全**：`defpoll` 是兜底安全网——即便乐观值短暂失真，下一个轮询周期（1–5s）必把它拉回真实状态。乐观更新是"先给确定性反馈，让轮询纠错"，不是"赌它成功"。

**为什么校准要"钉住"乐观字段**：某些慢源**写后读会滞后**——`tlpctl get` 比 `tlpctl set` 慢约 0.3s 才反映新值；`/sys/.../charge_control_end_threshold` 滞后 `tlp start` 约 1s。若校准此刻去读它，会读到**旧值**，把已经翻对的高亮又打回去（"落后一档"/闪烁）。故成功时强制保留目标值，只刷新其它字段，让轮询去确认最终态。

### 4.4 空间一致：从哪来回哪去，锚定触发源

- 弹层必须**锚定在触发它的组件正下方**（`open-popup.sh` 的 `compute_popup_left`：取鼠标位置 + 组件宽度推算左缘，靠右不够则向左展开）。
- 进出同路：同一弹层的打开与关闭走同一几何路径（picom fade 兜底），不"右进下出"。
- 单一弹层纪律：任一时刻只开一个弹层（`popup_open` + `POPUPS` 归并），点 scrim 或返回键关闭——Apple"永不困住用户"（Wayfinding：我在哪 / 能去哪 / 怎么出去）。

---

## 5. 常见场景配方（按动作类型）

| 场景 | 范式 | 参考实现 |
|---|---|---|
| **快速开关**（勿扰、静音、discoverable） | detach + 动作后 `eww update` 真实查询值 | `toggle-dnd.sh`（110ms 翻转） |
| **慢速开关 / 模式切换**（Wi-Fi/蓝牙/飞行、电源模式） | detach + **乐观翻转** + 事后校准（钉住目标） | `power-profile.sh`（`emit_for_mode` + `show_mode`，30ms） |
| **特权操作**（sudo 阈值 / 充满） | 包装脚本 detach + 乐观翻转 + 成功钉住 + **失败 notify**（绝不静默） | `power-admin.sh`（83ms） |
| **长异步操作**（Wi-Fi 连接、蓝牙配对） | detach + **即时"进行中"指示** + 完成刷新 + **timeout 上限** + 失败回退 | `wifi-connect.sh`（`wifi_connecting`→"连接中…"）、`bt-action.sh`（`bt_notice`） |
| **滑杆**（音量 / 亮度） | `onchange` 每 tick 触发，命令必须快；数值 label 绑轮询 | control-center `cc-scale`（`pamixer`/`brightnessctl`） |
| **一次性动作**（截图、锁屏、关机） | 仅 detach，无状态可翻；有意义的结局给 notify | `cc-action.sh screenshot`、`power.sh` |
| **无可观测状态的按钮**（护眼模式） | **必须补一个轮询**暴露状态，按钮绑它显示 on/off——不得做"点了看不出开没开"的按钮 | `night-light-on.sh` + `night_light` defpoll |

**反馈四态落地**（Apple §16）：

- **状态**（进行中）：`bt_notice`"正在连接…"、Wi-Fi 行"连接中…"。
- **完成**：高亮 / 开关 / 勾选即时翻转。
- **警告 / 错误**：`notify-send`——sudo 缺 NOPASSWD、截图已保存、配对失败。**只在有意义时刻发**（Apple"Utility：过度反馈会让用户无视一切反馈"）。

**Agency / 容错**（Apple §16）：可逆操作（一切开关、模式切换）**不得**弹确认框——确认只留给真正不可逆的破坏性动作（关机 / 重启），且它们已下沉到需要主动打开的 power-popup，本身就是缓冲。

---

## 6. 绝对要避免的设计（反模式清单）

1. ❌ **onclick 同步跑慢命令**（>200ms）——被 SIGKILL 腰斩，动作做一半或根本没做。
2. ❌ **`eww update` 放在 >200ms 操作之后却不 detach**——update 永远跑不到，界面干等轮询（修复前的 `toggle-wifi.sh`）。
3. ❌ **点击反馈只靠 `defpoll`**——天生 1–5s 死区，必然落在"以为死了"区间。
4. ❌ **写后立刻读慢源做校准**（`tlpctl get`/sysfs 滞后）——读到旧值，高亮"落后一档"或闪烁；成功时必须钉住乐观值（§4.3）。
5. ❌ **静默失败**——`sudo -n` 失败不报错，用户以为点了没用。失败必 `notify-send`。
6. ❌ **无可观测状态的开关**——按钮永远不显示开/关，点了看不出结果（修复前的护眼模式）。
7. ❌ **长操作无"进行中"指示、无 timeout 上限**——5–15s 无反馈，或卡死时"连接中"永远挂着。
8. ❌ **长生命周期子进程继承锁 fd**——`flock` 的 fd 被子进程继承会导致锁泄漏，后续每次点击都死锁。子进程必须 `8>&-`/`9>&-` 关闭继承的锁 fd；每条 IPC 调用都要套 `timeout`（`open-popup.sh`/`bt-action.sh` 血泪教训）。
9. ❌ **`eww open`/`close` 返回即假设窗口已就绪**——异步执行，必须 `wait_state` 轮询 `active-windows` 确认可观测后再决策（`open-popup.sh`）。
10. ❌ **把"宋式克制"做成"无反馈"**——克制的是动画，不是响应（§1 裁定）。

---

## 7. 规范代码片段

### 7.1 detach 头（一切慢 onclick 的第一行）

```bash
#!/usr/bin/env bash
# eww 200ms SIGKILL 杀不到 detached 进程；点击瞬间返回，真活在后台干。
if [ -z "$EWW_<NAME>_DETACHED" ]; then
    EWW_<NAME>_DETACHED=1 setsid nohup "$0" "$@" >/dev/null 2>&1 &
    exit 0
fi
# ……以下才是真正的工作……
```

### 7.2 乐观更新 + 钉住校准（慢开关 / 特权操作）

```bash
# 1) 乐观翻转：从当前状态出发，只改目标字段（即时，不读慢源）
cur=$(timeout 3 eww get power_info 2>/dev/null)
[ -n "$cur" ] && eww update power_info="$(printf '%s' "$cur" \
    | sed -e "s/\"threshold\":\"[0-9]*\"/\"threshold\":\"$target\"/")" 2>/dev/null

# 2) 执行真实动作
rc=0
sudo -n "$ADMIN" threshold "$target" >/dev/null 2>&1 || rc=$?

# 3) 校准：刷新其它字段；成功则钉住目标字段（慢源滞后，别让它打回旧值）
fresh=$(~/.config/eww/scripts/power-info.sh)
[ "$rc" -eq 0 ] && fresh=$(printf '%s' "$fresh" \
    | sed -e "s/\"threshold\":\"[0-9]*\"/\"threshold\":\"$target\"/")
eww update power_info="$fresh"
[ "$rc" -ne 0 ] && notify-send "电源" "操作未执行：缺少免密 sudo 权限" 2>/dev/null
```

### 7.3 长操作"进行中"指示 + timeout + 回退

```bash
eww update wifi_connecting="$ssid"                       # 即时进入"连接中…"
eww update wifi_networks="$("$S/network-wifi-networks.sh")"
timeout 30 nmcli device wifi connect "$ssid" 2>/dev/null || nm-connection-editor &
eww update wifi_connecting=""                            # 清进行中
eww update wifi_on="$("$S/network-wifi-on.sh")"          # 即时刷新真实态
```

### 7.4 锁 + IPC 超时（串行化不可重入操作）

```bash
exec 9>/tmp/eww-popup.lock
flock -w 10 9 || exit 0                 # 有界等待，锁被毒化也不永久冻死
ewwc() { timeout 8 eww "$@" 9>&- 2>/dev/null; }   # 子进程不继承锁 fd(9>&-)，IPC 套 timeout
```

---

## 8. 验证闭环（改完必跑）

呼应 `song-liquid-glass.md` §10 的像素纪律；交互侧用"延迟 + 一致性"双判据。**重载循环**：`chezmoi apply` → `i3-msg exec ~/.config/eww/scripts/launch.sh`（**绝不**直接跑 `launch.sh`，会挂住 shell；详见 `.agents/skills/developing-eww-components`）。

```bash
# 1) 语法 + 渲染
bash -n <script>.sh && chezmoi apply ~/.config/eww

# 2) 解析无错（后台写文件，别直接 eww logs —— 是长连接会挂住）
nohup eww logs >/tmp/eww.log 2>&1 & disown
i3-msg exec ~/.config/eww/scripts/launch.sh
grep -iE 'error|failed to parse|Window not found' /tmp/eww.log   # 必须无输出

# 3) 反馈延迟（核心判据：须 ≤100ms 量级，而非秒级）
t0=$(date +%s%N); ~/.config/eww/scripts/<toggle>.sh
for i in $(seq 1 40); do
  [ "$(eww get <var>)" = "<expected>" ] && { echo "$(( ($(date +%s%N)-t0)/1000000 ))ms"; break; }
  sleep 0.02
done

# 4) 状态一致性（乐观值最终必须 == 系统真实值）
eww get <var>            # 与 tlpctl get / pactl / sysfs / nmcli 核对

# 5) 单击 + 连击都测（连击暴露"落后一档"/闪烁/竞态）
```

**判据**：
1. 点击到界面翻转 ≤ ~100ms（乐观更新），不得是秒级。
2. 稳定后 `eww get` 与系统真实状态一致（无永久错位）。
3. 连击时界面跟随每次意图，无"落后一档"、无闪烁回旧值。
4. `eww logs` 无解析错误；全部弹层可开可关，关闭后只剩 `bar`。
5. **破坏性操作不实测**（Wi-Fi/蓝牙/飞行会断网断连，护眼会改色温）：以 `bash -n` + 范式同构（与已验证的 `bt-action.sh` 同构）+ 非破坏性子路径验证替代。

---

## 9. 实测数据附录（证据，2026-07-22 本机）

| 操作 | 耗时 | 含义 |
|---|---|---|
| `eww update` 往返 | **3ms** | 即时反馈廉价，没有借口不做 |
| `tlpctl get`（完整） | 248ms | `head -1` SIGPIPE 截断后 ≈4ms（轮询用此技巧） |
| `tlpctl set` | ~200ms | 且 `get` 滞后 `set` ~0.3s 才反映新值（§4.3 钉住的原因） |
| `sudo eww-power-admin threshold` | **628ms** | 内部跑 `tlp start`；sysfs 阈值再滞后 ~1s |
| `power-info.sh` | 220ms（dGPU 活跃可达 2s） | 含 `lsof /dev/nvidia*`（`timeout 2`） |
| 各 `defpoll` 脚本 | 5–8ms | 弹层打开卡顿**不是**数据慢，是反馈环路慢 |
| `defpoll` 间隔 | 1–5s | 点击反馈的死区来源 |
| 修复实测 | 电源模式 30ms / 阈值 83ms / 勿扰 110ms | 均从"秒级无反馈"降到 ≤100ms 量级 |

---

## 10. 非目标 / 观察项

- **手势 / 弹簧 / 动量**：eww 非手势系统，Apple 的 §2–§6（1:1 拖拽、速度交接、动量投影、橡皮筋）**不适用**，不引入。本文件只取其交互哲学（§1 四原则）。
- **pointer-down 即响应**：eww `onclick` 只在抬起触发，无法做到 Apple 的按下即反馈；以"onclick 触发即乐观翻转"逼近，已是平台上限。
- **滑杆拖拽 1:1**：`scale` 的 `:value` 绑轮询变量，拖动时与轮询有轻微竞争；当前可接受，若日后明显打架再考虑拖动期暂停轮询。
- **reduced-motion**：eww 动效本就极简（仅 picom fade + urgent 脉冲），`prefers-reduced-motion` 暂无需特判；登记备查。
