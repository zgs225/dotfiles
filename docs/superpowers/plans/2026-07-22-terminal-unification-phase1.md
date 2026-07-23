# 终端收编 · 第一期（WezTerm + tmux）Implementation Plan

> **For agentic workers:** 逐里程碑执行，每里程碑的「验证」全部通过且**用户视觉确认**后方可进入下一里程碑。Steps use checkbox (`- [ ]`) syntax for tracking.
> 设计目标与裁定：`docs/design/terminal-unification.md`（本计划不重复设计语言，只落执行）。

**Goal:** wezterm + tmux 在 i3 机器收编为宋式令牌色（ANSI 十六色 + tab 三态 + leader + tmux 17 色 + 朱砂当前窗名），macOS/他机 Tokyo Night 逐字节不变。

**Architecture:** 三文件模板化（`{{ if and .isLinux .useI3 }}` 守卫），else 分支冻结为现状原文；`custom.lua` 条件发射（palette 存在子表才输出，Tokyo 分支无子表走原路）；events 带硬编码 fallback 改读 `colors.custom`。tmux 色值直接渲染进 tmpl，废除已失效的 sync 脚本。

**Tech Stack:** chezmoi templates, WezTerm Lua, gpakosz/.tmux, ImageMagick（像素判据）, xdotool。

## Global Constraints

- **else 分支铁律**：任何里程碑结束后，else 分支渲染结果与 git HEAD 原文件逐字节一致（`git show` 比对）。macOS 零影响由构造保证。
- 色值来源：令牌经 `{{ .colors.* }}` 引用；衍生固定值（`#15151a`/`#464652`/`#6f6f68`/`#cfccc2`/`#8a9a6b`/`#c9b8b3`/`#7fa8a0`）以字面量写入并注释出处，零新发明色。
- 朱砂 `#c8452c` 全屏唯二：eww active 印章 + tmux 当前窗口名。wezterm 域内（含 tab）禁朱砂。
- wezterm 背景图、0.96 overlay、`inactive_pane_hsb`、键位、布局不动（G5）。
- `right-status.lua` 是死代码（`wezterm.lua:8` 已注释），不碰。
- **截图判据的混色陷阱**：picom `opacity-rule` 强制 wezterm 85% 不透明度（`picom.conf:36`），普通窗口截图像素是混色后的值，**不能**做精确 hex 匹配。像素校验一律用 `wezterm start --class songcheck` 开无混色校验窗（class 不匹配 opacity-rule，100% 不透明）；真实观感截图另开普通窗口。
- 用户的 tmux 真服务器**永不重启**（会杀会话）；tmux 验证一律用独立 socket `tmux -L songtest`。真服务器换色由用户择时 `tmux kill-server` 自行执行，不在本计划内。
- git commit 仅在用户明确同意后执行；每里程碑一个 commit，天然回滚点。

## 验证工具箱（全里程碑复用）

```bash
TU=/tmp/terminal-unification

# 16 色校验脚本（M0 生成一次，全程复用）
cat > $TU/ansi-colors.sh <<'EOF'
#!/usr/bin/env bash
row() { for i in "$@"; do printf '\033[48;5;%sm        \033[0m' "$i"; done; printf '\n'; }
clear
printf '\n  ANSI 0-7:\n\n';  row 0 1 2 3 4 5 6 7; row 0 1 2 3 4 5 6 7
printf '\n  ANSI 8-15:\n\n'; row 8 9 10 11 12 13 14 15; row 8 9 10 11 12 13 14 15
printf '\n'
EOF
chmod +x $TU/ansi-colors.sh

# 开无混色校验窗（新进程读新配置，不扰动现有窗口）→ 截窗口图
check_win() {  # $1=输出png  $2=可选启动命令
  nohup wezterm start --class songcheck -- bash -c "${2:-$TU/ansi-colors.sh}; exec bash" >/dev/null 2>&1 &
  sleep 2
  import -window "$(xdotool search --class songcheck | tail -1)" "$1"
}

# hex 存在/缺席断言（无混色窗截图专用）
has_hex() { magick "$1" -format %c histogram:info:- | grep -qi "#$2"; }                 # 期望 exit 0
no_hex()  { ! magick "$1" -format %c histogram:info:- | grep -qi "#$2"; }               # 期望 exit 0
TOKYO_HEXES="7aa2f7 f7768e bb9af7 9ece6a e0af68 7dcfff a9b1d6 c0caf5 414868 1a1b26"
no_tokyo() { for h in $TOKYO_HEXES; do magick "$1" -format %c histogram:info:- | grep -qi "#$h" && { echo "FAIL: $h"; return 1; }; done; }

# 两图同一性判据（光标闪烁容差：RMSE ≤ 2%）
same_pic() { [ "$(compare -metric RMSE -fuzz 3% "$1" "$2" null: 2>&1 | sed 's/.*(//;s/)//')" \< "0.02" ]; }
```

**视觉验证规程**（每里程碑）：截图存 `$TU/<里程碑>/`；agent 先 Read 图自查自动判据覆盖不到的项，再把图路径交付用户；**用户目视确认 = 进入下一里程碑的闸门**。

---

### M0: 基线

- [x] `mkdir -p $TU/{baseline,M1,M2,M3,M4,M5}`；备份 deployed 原文：`~/.config/wezterm/colors/palette.lua`、`~/.config/wezterm/config/appearance.lua`、`~/.tmux.conf.local` → `$TU/baseline/`
- [x] 生成 `$TU/ansi-colors.sh`（工具箱）
- [x] `check_win $TU/baseline/ansi.png`；新开 2 个 tab 截 tab 栏 `$TU/baseline/tabs.png`；`tmux -L songtest new -d \; new-window \; new-window` + attach 截 `$TU/baseline/tmux.png`，随后 `tmux -L songtest kill-server`
- [x] `chezmoi apply --dry-run` 全绿
- [x] **验证**：三个备份文件存在且与源一致（`diff`）；三张基线图可读；dry-run 无 pending
- [x] **视觉验证（用户）**：确认基线图反映了当前真实状态
- [x] **回滚**：无需（纯读取）

### M1: 模板骨架化（零行为变化）

**Files:** `git mv`：`dot_config/wezterm/colors/palette.lua`→`.tmpl`、`dot_config/wezterm/config/appearance.lua`→`.tmpl`、`dot_tmux.conf.local`→`.tmpl`
- [x] 三文件内容改为：`{{ if and .isLinux .useI3 }}` + 原文 + `{{ else }}` + 原文 + `{{ end }}`（两分支此刻完全相同，均为 Tokyo 原文）
- [x] `chezmoi apply`
- [x] **验证（自动）**：
  - `chezmoi cat` 三目标文件 vs `$TU/baseline/` 备份，`diff` **必须为空** ×3
  - `chezmoi apply --dry-run` 无 pending
  - 静态审查：三文件 else 分支块与 `git show HEAD:<path>` 逐字节一致
- [x] **验证（视觉 agent）**：`check_win $TU/M1/ansi.png` → `same_pic baseline/ansi.png M1/ansi.png`；新窗无 Lua 错误浮层
- [x] **视觉验证（用户）**：M1 图与基线无可见差异
- [x] **回滚**：`git checkout -- <三文件>` + `chezmoi apply`

### M2: 机制——条件发射与 events 收编（Tokyo 仍零变化）

**Files:** Modify `dot_config/wezterm/colors/custom.lua`、`dot_config/wezterm/events/tab-title.lua`、`dot_config/wezterm/events/left-status.lua`（均共享非模板）
- [x] `custom.lua`：`build_colors()` 增加条件发射——`palette.ansi`/`palette.brights`（存在才输出）+ `palette.chrome`（cursor_bg/cursor_fg/cursor_border/selection_fg/selection_bg/split，逐键存在才输出）；导出 `M.tab_title = palette.tab_title`、`M.left_status = palette.left_status`（Tokyo 分支为 nil）
- [x] `tab-title.lua:19-23`：`local colors = require('colors.custom').tab_title or { 原硬编码三态表 }`（fallback 逐字节保留原表）
- [x] `left-status.lua:11-14`：同构改法，fallback 保留 `#fab387` 原表
- [x] `chezmoi apply`
- [x] **验证（自动）**：`luac -p` 三文件语法通过；`chezmoi cat` palette/appearance 与基线 `diff` 仍为空（本步没动 tmpl）
- [x] **验证（视觉 agent）**：`check_win $TU/M2/ansi.png` → `same_pic baseline/ansi.png M2/ansi.png`；新窗无 Lua 错误浮层；开 2 tab 截 `$TU/M2/tabs.png` 与基线 tabs.png 同图判据
- [x] **视觉验证（用户）**：M2 与基线无可见差异（机制已换、皮相同）
- [x] **回滚**：`git checkout -- <三 lua>` + `chezmoi apply`

### M3: Song 注值（i3-only 行为变化）

**Files:** Modify `palette.lua.tmpl`（仅 if 分支）、`appearance.lua.tmpl`（仅 if 分支）
- [x] if 分支 palette 换为 Song 全量（18 ANSI 键 + 子表，令牌走 `{{ .colors.* }}`，衍生值字面量+注释）：
  - bg/fg `bg_base`/`fg_primary`；black `#15151a`；red `error`（赭石）；green `#8a9a6b`；yellow `warn`；blue `accent`（天青）；magenta `#c9b8b3`；cyan `#7fa8a0`；white `#cfccc2`；bright_black `#6f6f68`；bright 组同基色；bright_white `fg_primary`
  - `chrome`：cursor_bg/cursor_border/cursor_fg = `fg_primary`/`fg_primary`/`bg_base`；selection_bg `ink`、selection_fg `fg_primary`；split `#464652`
  - `tab_title`：default{bg `ink`, fg `fg_secondary`} / is_active{bg `accent`, fg `bg_base`} / hover{bg `#464652`, fg `fg_primary`}
  - `left_status`：glyph_semi_circle{bg rgba(0,0,0,0.4), fg `warn`}、text{bg `warn`, fg `bg_base`}
  - else 分支**不动**
- [x] `appearance.lua.tmpl`：if 分支删 `color_scheme = 'Tokyo Night'`（colors 表全权驱动）；else 分支保留原行
- [x] `chezmoi apply`
- [x] **验证（自动，无混色窗）**：`check_win $TU/M3/ansi.png`
  - `has_hex M3/ansi.png a0522d && has_hex 8a9a6b && has_hex d8a23c && has_hex 9ec8c0 && has_hex c9b8b3 && has_hex 7fa8a0 && has_hex 6f6f68` 全过
  - `no_tokyo M3/ansi.png` 全过；`no_hex M3/ansi.png c8452c`（wezterm 域禁朱砂）
  - else 分支与 `git show HEAD` 仍逐字节一致
- [x] **验证（视觉 agent）**：ansi 图十六格逐格对值表；开 2 tab 截 `$TU/M3/tabs.png`——active 天青底玄字、inactive 墨底蟹壳青；普通 class 窗口截 `$TU/M3/real.png`（85% 混色真实观感）
- [x] **视觉验证（用户）**：三张图——十六色对、tab 天青、真实观感不脏
- [x] **回滚**：`git checkout -- palette.lua.tmpl appearance.lua.tmpl` + `chezmoi apply`

### M4: tmux Song 块 + 死代码清理

**Files:** Modify `dot_tmux.conf.local.tmpl`（仅 if 分支色块）、`palette.lua.tmpl`（头部注释）、`custom.lua`（删 `M.tmux_mapping` 行）；Delete `scripts/sync-tmux-colors.lua`
- [x] if 分支 17 行换值（else 分支 Tokyo 原样，sentinel 注释两分支保留）：
  1 `#1a1a1e` / 2 `#464652` / 3 `#9a9a92` / 4 `#9ec8c0` / 5 `#d8a23c` / 6 `#e8e6df` / 7 `#e8e6df` / 8 `#1a1a1e` / 9 `#d8a23c` / 10 `#c9b8b3` / 11 `#8a9a6b` / 12 `#cfccc2` / 13 `#e8e6df` / 14 `#1a1a1e` / 15 `#1a1a1e` / **16 `#c8452c`（唯一朱砂）** / 17 `#e8e6df`
- [x] 删 `scripts/sync-tmux-colors.lua`；`palette.lua.tmpl` 头部注释去掉 "Consumed by ... tmux sync script"（改为 WezTerm 自用说明，两分支同改）；两分支删 `tmux_mapping` 表；`custom.lua` 删 `M.tmux_mapping` 导出行（部署内容变化、行为零变化：该表仅被已死脚本消费）
- [x] `chezmoi apply`
- [x] **验证（自动）**：
  - 静态：colour_16 在全文件仅被 `window_status_current_fg`（:213）引用（`status_right_bg`=15,4,17 / `status_left_bg`=4,10,11 已查实，回归确认）
  - `tmux -L songtest -f ~/.tmux.conf new-session -d \; new-window \; new-window \; select-window -t :1` 无报错
- [x] **验证（视觉 agent）**：songcheck 窗内 `tmux -L songtest attach`，截 `$TU/M4/tmux.png`
  - `has_hex M4/tmux.png c8452c`；`no_tokyo M4/tmux.png`；除 colour_16 区域外无朱砂（目视）
  - 状态栏左三段（天青/赭粉/苔绿）+ 右段、当前窗名朱砂可读
  - `tmux -L songtest kill-server` 清理
- [x] **视觉验证（用户）**：tmux 状态栏整体气质 + 朱砂题名可读性（若嫌暗，唯一允许的调整 = colour_16 改 `error` 赭石，本步内重验，不带入 M5）
- [x] **回滚**：`git checkout -- dot_tmux.conf.local.tmpl palette.lua.tmpl custom.lua && git checkout -- scripts/sync-tmux-colors.lua` + `chezmoi apply`

### M5: 终审 + 文档回写

- [ ] 真实观感终图：普通 class wezterm（85% 混色）开 2 tab + songcheck 窗内 tmux test server，全屏 `import -window root $TU/M5/full.png`
- [ ] **验证（自动）**：全屏图 `#c8452c` 精确匹配仅出现在 eww bar 印章区（bar 100% 不透明，可精确匹配）；songcheck 图朱砂仅在 tmux 当前窗名；`no_tokyo` 全屏过（eww/GTK 面本就不含 Tokyo 色，回归确认）；`chezmoi apply --dry-run` 绿
- [ ] **验证（视觉 agent + 用户）**：全屏终图——bar 印章与 tmux 朱砂题名成呼应、无第三处红；wezterm 真实观感（混色后）不脏不闷
- [ ] 回写：`docs/design/terminal-unification.md` 状态行 → "第一期（wezterm + tmux）已实施（2026-07-22）"；`song-liquid-glass.md` §7 末段标注 wezterm/tmux 已收编、§9.6 收窄为 nvim/pgcli/mycli/opencode 待收编
- [ ] `grep -rn 'sync-tmux-colors' . --exclude-dir=.git` 无残留引用
- [ ] **回滚**：整期 = `git revert` 五个里程碑 commit（或逐里程碑回滚点）

---

## 风险登记

| 风险 | 缓解 |
|---|---|
| else 分支意外走样污染 macOS | 每里程碑 `git show HEAD` 逐字节比对（构造保证 + 自动断言） |
| 混色截图误判色值 | 全部像素判据走 `--class songcheck` 无混色窗；真实观感单独截图 |
| 用户 tmux 会话被杀 | 验证只用 `-L songtest` 独立 socket；真服务器换色用户择机自行 `kill-server` |
| wezterm Lua 语法错导致配置不加载 | 每里程碑新窗目视无错误浮层 + `luac -p` 冒烟 |
| 朱砂可读性不佳（玄底朱砂字） | M4 用户视觉闸门内允许唯一调整：colour_16 → 赭石，步内重验 |
