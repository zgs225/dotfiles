# 绢纱琉璃 · 宋式极简 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 Catppuccin Mocha 全局主题替换为「玄底绢纱 × 汝窑天青 × 朱砂一方印」宋式极简体系，覆盖 i3 / eww / picom / dunst / rofi / GTK4 / Kvantum / WezTerm / tmux / 锁屏。

**Architecture:** 色彩令牌单一来源 `.chezmoi.yaml.tmpl data.colors`，全部模板从此取值。先换令牌根，再逐组件改造，每步截图/日志验证通过后才进下一步。

**Tech Stack:** chezmoi templates, eww 0.5.0 (yuck+SCSS, 纯ASCII), i3 4.25.1 (原生gaps), picom (dual_kawase), Kvantum, WezTerm Lua。

## Global Constraints

- 圆角全局 5px（eww 内 pill/999px 全部收敛到 3-6px）
- 朱砂 `#c8452c` 仅当前 workspace 印章；urgent→藤黄 `#d8a23c`；error/critical→赭石 `#a0522d`
- 色板：bg_base `#1a1a1e` / bg_elevated `#21212a` / ink `#2e2e36` / fg_primary `#e8e6df` / fg_secondary `#9a9a92` / accent `#9ec8c0` / seal `#c8452c` / warn `#d8a23c` / error `#a0522d`
- 透明度分级：L1 bar 0.75 / L2 弹层 0.65 / L3 重点格 0.55 / L4 通知菜单 0.60
- eww SCSS 必须纯 ASCII（非ASCII使 grass 输出 @charset UTF-8 导致 GTK3 丢弃整个样式表）；中文字形只出现在 yuck/脚本层
- `dot_config/gtk-3.0/gtk.css` 保持为空（USER优先级污染 eww）
- eww 几何尺寸走 `.chezmoitemplates/eww-sizes` 三档DPI烘焙
- i3 gaps inner 8；间距阶梯 4/8/12/16/24

**设计决策（对原设计文档的修订，已与用户确认）：**
1. 篆体SVG十天干 → CJK字形直接入朱砂方印
2. 「申时三刻」→ 「申时 · 15:42」格式
3. 壁纸维持 betterlockscreen 机制，默认生成色改玄色
4. GTK3 主题保留 catppuccin-glass（妥协点，gtk.css 保持空）

---

### Task 0: 字体安装（eos-bootstrap）

**Files:** Modify `~/Workspace/Misc/eos-bootstrap/ansible/roles/packages/defaults/main.yml`
- [ ] 官方源段加 `adobe-source-han-serif-cn-fonts`；AUR段加 `ttf-lxgw-wenkai`
- [ ] 安装两字体
- [ ] 验证：`fc-list | grep -ciE 'lxgw wenkai'` ≥1 且 `fc-list | grep -ci 'source han serif'` ≥1

### Task 1: 令牌根

**Files:** Modify `.chezmoi.yaml.tmpl:17-43`
- [ ] data.colors 重写为宋式语义令牌 + 保留旧键别名（临时兼容，Task 13 清理）
- [ ] 验证：`chezmoi execute-template` 输出新令牌；`chezmoi apply --dry-run` 无模板错误

### Task 2: picom

**Files:** Modify `dot_config/picom/picom.conf:6-18,53-66`
- [ ] corner-radius 10→5；shadow radius 12/opacity 0.35/offset 0,4
- [ ] 验证：pgrep picom 存活；截图确认圆角变小

### Task 3: i3

**Files:** Modify `dot_config/i3/config.tmpl:8-22`
- [ ] font pango:LXGW WenKai 10；gaps inner 8；focused→accent；unfocused→ink；urgent→error
- [ ] 验证：`i3-msg reload` success；get_tree 含 gaps；截图确认

### Task 4: eww 令牌与基座

**Files:** Modify `dot_config/eww/styles/colors.scss.tmpl`、`styles/base.scss.tmpl`、`eww.scss.tmpl:10`、全部样式表圆角
- [ ] 26变量→宋式令牌+`$seal/$warn/$error/$hairline`；.popup radius 20→5；999px pill 收敛；字体栈加 LXGW WenKai；$blue accent 引用→$accent
- [ ] 验证：`eww reload`；`eww logs` 无SCSS错误；截图无破版

### Task 5: eww Bar 卷轴+印章

**Files:** Modify `components/bar.yuck.tmpl`、`styles/bar.scss.tmpl`、`scripts/executable_workspaces.sh`、`.chezmoitemplates/eww-sizes`
- [ ] bar 顶/底发丝线；分隔符 `·`；工作区→天干印章三态（active朱砂底/occupied天青框/empty蟹壳青40%）；urgent→藤黄；bar高 38/54/78→32/44/64
- [ ] 验证：三态截图；当前workspace是唯一红色元素

### Task 6: 时辰时钟

**Files:** Create `scripts/executable_shichen.sh`；Modify `components/common.yuck`、`bar.yuck.tmpl`
- [ ] 十二时辰映射，输出「申时 · 15:42」
- [ ] 验证：脚本直接运行输出正确；bar 截图

### Task 7: 弹层多宝格

**Files:** Modify profile-card / control-center / calendar / notification 的 yuck+scss
- [ ] 透明度分级 L1-L4；格子标题 Source Han Serif Heavy+天青；hover 2px 天青竖条
- [ ] 验证：逐 popup 截图；eww logs 无错

### Task 8: Dunst

**Files:** Modify `dot_config/dunst/dunstrc.tmpl`
- [ ] corner_radius 5；icon 3；字体 LXGW WenKai；frame 天青发丝；critical→赭石；normal bg L4
- [ ] 验证：notify-send normal/critical 截图

### Task 9: Rofi

**Files:** Modify `rofi/themes/palette.rasi.tmpl:17-26`、`launcher.rasi.tmpl`、`display/post-switch.d/executable_20-rofi-dpi:31-33`
- [ ] glass rgba 字面量→宋式；圆角 5/5/3；字体加文楷
- [ ] 验证：`rofi -show drun` 截图，选中态天青

### Task 10: GTK4 + Kvantum

**Files:** Modify `gtk-4.0/gtk.css.tmpl`、`Kvantum/catppuccin-glass/catppuccin-glass.kvconfig.tmpl`、`dot_xprofile`
- [ ] GTK4 @define-color 换宋式令牌；Kvantum GeneralColors 换色；gtk-3 gtk.css 保持空
- [ ] 验证：gtk4-widget-factory + Qt 应用截图

### Task 11: WezTerm + tmux

**Files:** Modify `wezterm/colors/palette.lua:7-63`、`config/appearance.lua`
- [ ] 新增 'Song Ink' 配色（ANSI red→赭石避免朱砂冲突）；tmux_mapping 同步；overlay 0.96→0.975
- [ ] 验证：重开 wezterm 截图；tmux 状态栏截图

### Task 12: 锁屏与壁纸

**Files:** Modify `betterlockscreen/betterlockscreenrc`、`.chezmoiscripts/common/run_once_after_generate-default-wallpaper.sh:12-14`
- [ ] 默认壁纸色 #1a1a1e；ring 天青/赭石；时间字体 Source Han Serif SC
- [ ] 验证：锁屏截图

### Task 13: 全局终审

- [ ] 全屏截图对照设计 checklist；清理 .chezmoi.yaml.tmpl 旧键别名；`chezmoi apply --dry-run` 全绿
