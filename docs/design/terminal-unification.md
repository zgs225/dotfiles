# 终端收编 · 书房入境

> 上游：`song-liquid-glass.md` §2.1（令牌）§7 末（暂未统一登记）§9.6（妥协登记）。
> 本文件只立**设计目标与裁定**——收编后终端域的目标态、色彩纪律、验证判据。实施方案与步骤不在本文件。
> 状态：目标已定（2026-07-22），未实施。

---

## 0. 一句话

桌面已入裱，终端还是租界。wezterm / tmux / nvim / pgcli / mycli / opencode 各自挂着 Tokyo Night、Solarized、OneHalfDark 三面外国旗，wezterm 内部还嵌着两块连国旗都不是的硬编码野飞地。收编的目标不是换皮，是让**令牌所至之处，色彩飞地归零**——终端里只剩两种时刻：绢纱琉璃（i3 机器），或原样保留（他机）。

---

## 1. 诊断：终端域的飞地清单（带证据）

| 面 | 现状色 | 证据 | 病 |
|---|---|---|---|
| wezterm | Tokyo Night，蓝紫 accent `#7aa2f7` | `appearance.lua:26` | 蓝紫系，犯 §2.1「选中/激活永不蓝紫」 |
| wezterm tab 栏 | 硬编码 Kanagawa `#7FB4CA` | `tab-title.lua:19-23` | 野飞地：不属于任何在册主题 |
| wezterm leader 指示 | 硬编码 Catppuccin `#fab387` | `left-status.lua:13` | 同上 |
| tmux | Tokyo Night（同步自 wezterm） | `dot_tmux.conf.local:87-105` | 随行租界 |
| nvim | NvChad tokyonight | `chadrc.lua:58` | 蓝紫同病 |
| pgcli / mycli | **Solarized**（`#002b36`/`#268bd2`/`#859900`） | `pgcli/config` [colors]、`dot_myclirc` | 第二面国旗，连 Tokyo 都不是 |
| opencode TUI | tokyonight | `opencode/tui.json:3` | 随行租界 |
| bat | OneHalfDark | `dot_zsh/configs/85-bat.zsh:1` | 第三面国旗 |

**免费继承者**：git 别名 `%Cred/%Cgreen/bold blue`（`dot_gitconfig.tmpl:35`）、ls、less 等一切 ANSI 语义色 CLI——它们不持外国旗，只读终端地基。地基换，则自动入境。

病根：§7 末的"暂未统一"登记把这些飞地合法化至今。systray 之外，终端域是全系统最大的在册逃税者。

---

## 2. 隐喻：书房入境

窗口 = 画心（`window-mounting.md` 已定）。终端是画心里墨迹最密的一处——批注、题跋、警示皆在其内。收编即书房换用本朝笔墨：

- **ANSI 六色 = 书房六色墨**：批误用赭（僭越朱砂者斩）、苔绿、藤黄、天青、赭粉、深天青——§2.1 衍生固定值早已为终端备好这套墨，只差启用。
- **tmux 当前窗口 = 印章语义延伸**（§7 末已登记）：朱砂题名、玄底、粗体。面积最小化的钤印——是落款，不是横幅。
- **wezterm active tab = 界引**：天青底、玄字。"当前"的两种身份分开：workspace 归属（tmux 窗）用印，终端页签聚焦用界引。朱砂在一屏之内不重复落。

---

## 3. 设计目标（目标态，不含实现）

- **G1 飞地归零**：i3 桌面内，终端生态（wezterm / tmux / nvim / pgcli / mycli / opencode；bat 见 §6）全部色值出自 §2.1 令牌与已登记衍生固定值，无第三方主题色残留、无硬编码野色。
- **G2 门禁**：收编只在 `useI3` 机器生效。macOS 与他机保持 Tokyo Night 原样——收编是入境换帖，不是全球换旗。SSH 到他机，从该机器之俗。
- **G3 朱砂纪律延伸**：终端域内朱砂仅一处——tmux 当前窗口名（朱砂字、玄底、粗体）。wezterm active tab 用天青界引，不僭印。全屏朱砂唯二：eww active 印章 + tmux 当前窗口名。
- **G4 ANSI 地基优先**：先收 wezterm ANSI 十六色，令 git / ls 等语义色 CLI 免费入境；再收各应用主题。地基不正，上层白裱。
- **G5 手感不动**：wezterm 背景图、0.96 overlay、`inactive_pane_hsb`、键位、布局全部保留。只换色，不换习惯。
- **G6 语法高亮入裱**：nvim 以自建主题落令牌，diagnostics 语义 = Error 赭石 / Warn 藤黄 / Info·Hint 天青系；pgcli / mycli 的 SQL 语法色与补全菜单同纪律。

---

## 4. 色彩裁定（终端语义映射）

| ANSI | 色 | 来源 | 理由 |
|---|---|---|---|
| background / foreground | 玄 `#1a1a1e` / 月白 `#e8e6df` | 令牌 | 墨底绢纱 |
| red | **赭石 `#a0522d`** | 令牌 error | 朱砂唯一化；终端红 = 错误语义，赭不僭朱 |
| green | 苔绿 `#8a9a6b` | §2.1 衍生（已登记 ANSI green） | — |
| yellow | 藤黄 `#d8a23c` | 令牌 warn | — |
| blue | **天青 `#9ec8c0`** | 令牌 accent | 禁蓝紫纪律；终端蓝 = 强调/链接语义，归天青 |
| magenta | 赭粉 `#c9b8b3` | §2.1 衍生（已登记 ANSI magenta） | — |
| cyan | 深天青 `#7fa8a0` | §2.1 衍生（已登记 ANSI cyan） | 与天青成明暗一对 |
| white / bright white | 月白次阶 `#cfccc2` / 月白 | 衍生 / 令牌 | — |
| black / bright black | 玄之暗部 `#15151a` / 蟹壳青暗阶 `#6f6f68` | 衍生 | bright black 须托起注释可读性 |

**bright 组与基色同值**（bright_black / bright_white 除外）——Tokyo Night 现状即此，零新发明色。

**应用层裁定**：

| 处 | 色 | 语义 |
|---|---|---|
| tmux 当前窗口名 | 朱砂字 + 玄底 + 粗体 | 印章（§7 末登记的唯一延伸） |
| tmux 其余 16 色 | 沿 tmux_mapping 语义槽位换令牌值 | 随行收编 |
| wezterm active tab | 天青底 + 玄字 | 界引，不僭印 |
| wezterm tab default / hover | 墨底蟹壳青字 / 墨亮阶底月白字 | 静默档 |
| wezterm leader 指示 | 藤黄底 + 玄字 | 提醒语义，归 warn |
| wezterm cursor / selection / split | 月白·玄 / 墨底月白 / 墨亮阶 | chrome 三件套 |
| nvim diagnostics | Error 赭 / Warn 藤黄 / Info·Hint 天青系 | §2.1 语义映射原样 |
| pgcli / mycli 菜单·工具栏 | 令牌 hex 替换 Solarized 全段 | 飞地归零 |

---

## 5. 各面目标态

- **wezterm**：ANSI 十六色入裱；tab 栏三态（active 天青 / default 墨 / hover 墨亮阶）与 leader 藤黄全部出自色表，硬编码野色清除；背景图与 overlay 不动。
- **tmux**：状态栏随令牌换色；当前窗口名朱砂题名——屏内除 eww 印章外的唯一朱砂，两处成呼应而不成对撞。
- **nvim**：自建主题（非第三方主题换装），base 色全部可溯源到令牌；transparency 保留。
- **pgcli / mycli**：[colors] 段 Solarized 全灭，菜单、滚动条、选中、工具栏、事务指示皆令牌色；SQL 语法色服从 §4 映射。
- **opencode TUI**：主题入境（具体支持机制实施时查明）。
- **git / ls / less**：零改动，随 ANSI 地基自动入境——收编的红利面。

---

## 6. 边界与非目标

- **bat 缓议**：tmTheme 自写成本高，OneHalfDark 暂不碍眼——登记观察项，不入本轮目标。
- **不改行为**：任何应用的键位、布局、交互逻辑不动（G5）。
- **right-status.lua 是死代码**（`wezterm.lua:8` 已注释），不收不删。
- **门禁按机器不按人**（G2）：本文件一切目标态仅描述 `useI3` 机器。
- **实施与步骤另录**：模板机制、分期顺序、逐步验证不在本文件。

---

## 7. 验证判据（设计侧）

1. 终端域截图像素采样：无 `#7aa2f7` / `#f7768e` / `#bb9af7` / `#7FB4CA` / `#fab387` / `#268bd2` / `#002b36` 残留。
2. 全屏朱砂唯二：eww active workspace 印章 + tmux 当前窗口名（呼应 `song-liquid-glass.md` §10 既有判据的终端延伸）。
3. nvim 内触发 Error / Warn / Hint 各一，目视 = 赭石 / 藤黄 / 天青系。
4. 他机渲染零变化（else 分支构造保证 + 与 git HEAD 比对）。
