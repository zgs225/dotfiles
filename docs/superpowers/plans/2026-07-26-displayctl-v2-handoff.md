# displayctl v2 多屏重构 — 交接文档（重开窗口用）

> 状态快照时间：2026-07-26。本文档自包含，供新窗口无缝接续。
> 涉及两个仓库：**Go 工具** `~/Workspace/Golang/displayctl`（分支 `v2-multimonitor`）与 **dotfiles** `~/.local/share/chezmoi`。

---

## 1. 目标与目的

重构 Linux i3wm 下的显示器管理。用户（=displayctl 作者 zgs225）的 7 条需求：

1. 自动显示器发现
2. 可调分辨率和 DPI（持久化）；显示器**位置**（鼠标跨屏）
3. 记住不同显示器组合的设置
4. `DISPLAY` 变量注册
5. fcitx 正常工作
6. 其他依赖 `DISPLAY` 的程序正常工作
7. 设置显示模式：mirror / extend / 只用一块屏

**关键决策：扩展自研 displayctl 到 v2，而非换 autorandr。** 原因：用户当初造 displayctl 就是因为 autorandr 的 EDID 匹配在 `Virtual-1`（XRDP/Sunshine 虚拟输出，EDID 恒定）下失效。用户需要**物理多屏 + 虚拟客户端两者都支持**，所以让 displayctl 成为超集：物理屏用 EDID 指纹（需求 1/3），虚拟会话保留原有「事件源显式调用 profile」模型。

需求 4/5/6 **基本已在 `dot_xprofile` 满足**（`systemctl --user import-environment DISPLAY PATH` + 全套 fcitx IM 环境变量）。重构集中在 1/2/3/7。

---

## 2. 硬件环境（实测）

- 内屏 `eDP-1`：BOE 面板，2560×1600，344×215mm（16"），**189 DPI**，primary。
- 外接 `DP-1`：**Dell U2720QM**，27" 4K 3840×2160，597×336mm，**163 DPI**。当前 **connected 但 inactive**（扩展坞插着但只用内屏）。
- `DP-2` / `HDMI-1-0`：disconnected。
- **混合 GPU**：dGPU 断电，`/sys/class/drm/*/edid` 全是 **0 字节**。
  → **EDID 必须从 `xrandr --verbose` 解析，绝不能读 sysfs。**
- 两屏密度差 ~16%（189 vs 163）。X11 只有一个全局 DPI，相对大小差硬件注定、躲不掉。
  → **决策：全局 DPI 锚定主屏（内屏→144），不上 per-output `--scale`（会糊，16% 可接受）。** schema 保留 `scale` 字段作可选逃生舱，默认不用。

---

## 3. 设计（已全部与用户确认）

### 3.1 v2 profile 格式（TOML，命名子表）
```toml
default = false
layout = "extend"            # 信息性标签：extend|mirror|single|custom
manage = "full"              # full=关掉未列出的 connected 输出；partial=只动列出的（虚拟用）

[match]
id = "9f2a7c1bdeadbeef"      # 指纹，save 写入，别手改
outputs = ["DP-1:ab12cd34", "eDP-1:ef56ab78"]   # 人读/调试用

[outputs.eDP-1]              # 每屏一个表，key=xrandr 输出名
mode = "2560x1600"           # "WxH" | "current" | "preferred"/"auto" | "off"
rate = 120                   # 可选
pos = "0x0"                  # 几何位置（鼠标跨屏）
primary = true               # 主屏=DPI 参考+i3 主屏
# rotate = "normal"          # 可选：normal|left|right|inverted（存）
# scale = 1.0                # 可选 xrandr --scale（存但默认不用）

[outputs.DP-1]
mode = "3840x2160"
pos = "2560x0"

[dpi]                        # X11 全局单 DPI
tiers = true                 # 或 value = 144
reference = "eDP-1"          # tiers 参考哪个输出；省略=primary
```
- **向后兼容**：旧单 `[output]` profile（xrdp/sunshine/monitor）继续可读（`IsLegacy()`）。解析器：有 `[outputs]`→v2，否则有 `[output]`→legacy。

### 3.2 指纹
- `fingerprint.Compute(refs)` = 对排序后的 `name:edidhash` 标签集合做 sha256，取前 16 hex。**顺序无关**；同口换不同屏→不同指纹。
- 虚拟输出（无 EDID）→ label 退化为裸名字；`HasVirtual()` 检测虚拟会话。

### 3.3 `apply auto` 算法
```
发现 connected 输出（xrandr --verbose 含 EDID）
├─ 有输出无 EDID（Virtual-1）→ 应用 default=true profile（保留虚拟行为）
└─ 全有 EDID（物理屏）
   ├─ 指纹命中某 profile → 应用它（完整状态，manage=full 关掉未列出）
   └─ 未命中（未知组合）→ 自动排布 extend（内屏 primary@0x0，其余右排，preferred 模式）
                          + 提示 `displayctl save <name>`；临时布局不落盘
```

### 3.4 同硬件多意图（如 dock-extend vs dock-clamshell 指纹相同）
**方案甲**：auto 按 profile 名字排序选第一个命中的；手动 `displayctl apply <name>` 覆盖意图。

### 3.5 daemon
监听 RandR 事件，防抖 300ms。每次重算指纹：
- **变了**（插拔）→ `resolveAuto` + apply（完整自动选择）
- **没变**（XRDP resize）→ 只刷新全局 DPI（取 primary 活动输出宽度算 tiers）
- apply 不改 connected 集合 → 指纹不变 → **天然防死循环**。

### 3.6 rofi 集成（需求：`$mod+space` 下 `display` 前缀）
- 启动器是模块化 rofi 系统：`$mod+space` 打开主界面，输入「前缀+空格」进模块。
- 已用前缀：`g`(google) `=`(calc) `find` `b`(buku)。**`display` 空闲。**
- **不需要新 i3 绑定**——加一个模块文件即可。
- 模块契约（见 `dot_config/i3/scripts/launcher.d/common.sh`）：
  - `register_module display "display" plain`
  - `display_init`：用 `row "文本" "图标" "info"` / `msg_row` 输出菜单行
  - `display_select`：按 `ROFI_INFO` 分发
  - 可用 helper：`row` `msg_row` `open_target`；`THEME` 变量；`chain` 用于二级菜单
- 菜单 UX：状态行（不可选）/ 布局快捷（扩展·镜像·仅内屏·仅外接，动态生成）/ 已存配置（★=匹配当前，排前）/ 管理（自动检测·保存当前布局…）。
- 「保存当前布局…」选中后弹 `rofi -dmenu -p "保存为"` 输名字 → `displayctl save <name>`。
- 内屏判定：名字前缀 `eDP-`/`LVDS-`。
- 动作执行用 `setsid -f` + `notify-send` 反馈。
- **依赖 displayctl v2 的 CLI 契约**（已实现）：
  - `list --json` → `[{"name","layout","outputs":[...],"dpi","default","match"}]`（match=指纹是否匹配当前）
  - `current --json` → `{"layout","dpi","outputs":[{"name","mode","pos","primary"}]}`

---

## 4. 当前进度

### 阶段 1（Go v2）—— ✅ 已完成
分支 `v2-multimonitor`，按 TDD 实现，7 个增量全部提交、测试全绿、真机冒烟通过：
```
28c496f feat(daemon): fingerprint-gated hotplug re-apply + DPI refresh
913dec2 feat(cmd): apply-auto via ResolveAuto, save, layout, list/current --json
3c67a32 feat(layout): Capture, Mirror, Single generators
90a4517 feat(layout): plan builder, auto-arrange, auto-selection decision
6014280 feat(profile): v2 multi-output schema with legacy compat
fcf6415 feat(fingerprint): stable order-independent hardware combo id
f418382 feat(xrandr): add pure Parse/ScreenSize for multi-output state
+ README 已重写并提交
```
新增包/文件：`internal/xrandr/parse.go`、`internal/fingerprint/`、`internal/layout/`（layout.go + generators.go）、`cmd/save.go`、`cmd/layout.go`；改造 `internal/profile/profile.go`、`cmd/apply.go`、`cmd/apply_v2.go`、`cmd/list.go`、`cmd/current.go`、`cmd/daemon.go`、`cmd/root.go`。
测试固件在 `internal/xrandr/testdata/`（真机采集）。

### 阶段 1 收尾 —— ⏳ 未完成
- [ ] 打 tag `v2.0.0`（当前最新 tag 是 v1.3.0）
- [ ] push 分支 + tag 到 origin（`git@github.com:zgs225/displayctl.git`）

### 阶段 2（dotfiles）—— ⏳ 未开始
在 `~/.local/share/chezmoi`：
- [ ] `dot_config/mise/conf.d/displayctl.toml.tmpl`：版本 `v1.3.0` → `v2.0.0`
- [ ] profiles（`dot_config/display/profiles/`）：
  - 保留/迁移虚拟 legacy profile（xrdp.toml / sunshine.toml / monitor.toml.tmpl）——**必须保持可用**
  - 新增 `laptop-only`（现在就能 capture：单内屏）
  - `dock-extend` 需用户插上 DP-1 后 `displayctl save dock-extend` 生成（现在 DP-1 inactive，无法直接 capture 扩展态）
- [ ] rofi 模块 `dot_config/i3/scripts/launcher.d/display.sh`（见 §3.6）
- [ ] `dot_xprofile` 增强：把 IM 变量也 `systemctl --user import-environment`（加固需求 5/6）
- [ ] i3 autostart（`dot_config/i3/config.tmpl` ~147-148 行）已有 `displayctl apply auto` + `displayctl daemon`，**语义升级即可，无需改**——但需复核

---

## 5. 已做的验证

- `go build ./... && go vet ./... && go test ./...` 全绿。
- 真机冒烟（只读 + 安全路径）：
  - `current` / `current --json`：正确显示 single、eDP-1 primary、DPI 144。
  - `list` / `list --json`：正确解析 legacy profile（monitor 标 default）。
  - `save test`（临时 DISPLAYCTL_DIR）：capture 单内屏、指纹覆盖两个 connected 输出（含 inactive DP-1）、`list` 显示 ★ 匹配。
  - `layout bogus` / `layout single`（缺参数）：错误路径干净。
- **未 live 跑 `apply` / `layout extend|mirror|single <out>`**（会改显示）。

---

## 6. 绝对不要做的事（红线）

1. **绝不改 OS 级配置**（AGENTS.md）：不动 `/etc/`、`/usr/`、`/boot/`、systemd units、polkit 等。本仓库只管用户级 dotfiles。
2. **绝不直接改 `~/.` 下文件**——一律走 chezmoi（`dot_` 前缀、`.tmpl` 模板）。
3. **桌面 UI 必须遵守 `docs/design/song-liquid-glass.md`**（绢纱琉璃·宋式极简）：颜色 token 以 `data.colors` 为唯一来源、朱砂色唯一性、eww SCSS 纯 ASCII、gtk-3.0 gtk.css 保持空、不设 `GTK_THEME` 环境变量、rofi 2.0 两段式 element 状态。改 rofi 主题/新增 UI 组件时尤其注意。
4. **EDID 绝不读 sysfs**（本机混合 GPU 下是 0 字节）——只用 `xrandr --verbose`。
5. **未经用户意图，绝不 live 跑 `displayctl apply` / `layout`**——会改当前显示。注意：DP-1 当前 connected-but-inactive，首次 `apply auto` 会点亮它成 extend（这是设计的预期行为，但会令当前会话意外）。
6. **绝不破坏 legacy 虚拟 profile**（xrdp/sunshine/monitor）——XRDP/Sunshine 依赖它们。
7. **绝不在测试未全绿时打 tag / push。**
8. mise 里 `go:` 前缀必须放在 **key**（不是 value）；固定具体 tag，**不用 `latest`**（避免 Go proxy 伪版本不匹配）。
9. 设计阶段用户已确认的决策（§3）不要推翻重议，除非用户主动提出。

---

## 7. 接续后的建议第一步

1. `cd ~/Workspace/Golang/displayctl && git log --oneline -3 && go test ./...` 确认分支状态。
2. 完成阶段 1 收尾：`git tag v2.0.0 && git push origin v2-multimonitor && git push origin v2.0.0`（push 前先和用户确认）。
3. 进阶段 2：先做 rofi 模块 `display.sh`（用户最想要的新功能），再 bump mise 版本、profiles、xprofile。
4. 阶段 2 涉及 UI，动手前读 `docs/design/song-liquid-glass.md` 和 rofi 现有主题（`dot_config/rofi/launcher.rasi.tmpl`）。

---

## 8. 执行后记（2026-07-26 收尾，与上文的偏差）

本轮已把阶段 1 收尾 + 阶段 2 全部落地并验证。记录与 §3/§4/§7 的偏差，使本文自洽：

- **tag 改走 v1.4.0，v2.0.0 已撤销。** §4/§7 写的 `git tag v2.0.0` 不可行：Go 硬规则要求 major≥2 的 tag 模块路径带 `/v2` 后缀，而 `go.mod` 是 `module github.com/zgs225/displayctl`（无后缀），故 `go install @v2.0.0` / mise 直接拒装（`invalid version: ... must match major version`）。仓库内 `go build` 不受影响，所以阶段 1 测试全绿却掩盖了这点。最终在同一 commit `65befa3` 打 `v1.4.0`（v1 线，mise 装得上、运行时即 v2 全功能），并删远程+本地 `v2.0.0`。若日后真要 `v2.x.x` tag，须走方案 A：`go.mod` 改 `.../displayctl/v2` + 14 文件 46 处 import 加 `/v2`（破坏性）。
- **mise = v1.4.0**（`dot_config/mise/conf.d/displayctl.toml.tmpl`）。中间一度误改 v2.0.0 致 shim 装不上，已及时回滚保护 i3 autostart，再随 v1.4.0 落地。错配窗口期已消除：v1.4.0 运行时下 `apply auto` 会命中 `dock-extend`（指纹 auto 生效），不再退回 default monitor。
- **laptop-only 改手动算指纹。** §4 假设“现在就能 capture”不成立：`save` 的指纹覆盖所有 *connected* 输出，插着坞站时 capture 得到的是 docked 指纹（含 inactive DP-1），非纯笔记本指纹。故用算法 `sha256("eDP-1:686973d4")[:16] = ef2d1cc808d7c811` 手写 `laptop-only.toml`（docked 指纹已用实机 `save` 逐字节复现验证算法可靠）。undock 后才匹配。
- **dock-extend 已 capture 并纳管**（`displayctl layout extend` 点亮 DP-1 后 `save`，指纹 `3e12ee9ba2b37229`，几何实测）。当前 docked 下 `match=★`。
- **rofi `display` 模块已交付并视觉验证**（`dot_config/i3/scripts/launcher.d/display.sh`）：`Alt+space → display␣`，菜单 = 状态行 / 布局快捷 / 已存配置（★ 排前）/ 管理；select 分发 stub 测通；真实 rofi 弹窗截图确认渲染正确、符合 `song-liquid-glass.md`、菜单内无朱砂。
- **xprofile IM 加固**（需求 5/6）：5 个 fcitx IM 变量并入 `systemctl --user import-environment`，需重新登录后生效。
- **i3 autostart 无需改**（`config.tmpl:150-151` 的 `apply auto`/`daemon` 在 v1.4.0 语义升级、命令名不变）。
- **已知 UX 点（未修，超出本阶段范围）**：`display_init` 冷启动 ≈1.9s（串行 3 次 xrandr，`current --json` 读 EDID 最慢），`display␣` 后子菜单约 2s 才出内容。优化方向：让 `current --json` 顺带返回 connected 列表，省掉模块里第三次裸 `xrandr`。
- **验证**：移植 ewwstate-collector-dev 的方法论写 `/tmp/verify-displayctl.sh`（离线对等 + 异常计数 + 三策略 + 真实 rofi 截图），最终 **16/16 全绿**。过程中自动化抓到 4 个测试脚本自身 bug（grep 不认 `\x1f`、`grep -c||echo 0` 双输出、指向未渲染 `.tmpl`、期望集过时），均非交付物问题。
- **环境副作用（已修，非交付物）**：点亮 DP-1 后右屏壁纸未随新几何重铺（`wallpaper.sh` 用 `feh --bg-fill` 一次性设图、无常驻进程、不监听 RandR）。用脚本记录的当前索引重铺同一张图恢复，未换图、未改配置。
