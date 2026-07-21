# 绢纱琉璃 · 宋式极简 — 桌面设计系统

> 本文件是全局 UI 设计的唯一权威依据。所有新组件、新样式、新配色必须先对照本文件。
> 实现侧的色彩唯一来源是 `.chezmoi.yaml.tmpl` 的 `data.colors`，禁止在任何模板中硬编码色值（rofi 的 rgba 除外，见 §8.4）。

适用环境：Arch Linux + X11 + i3wm + eww + picom
设计基调：Liquid Glass（克制版）× 宋代美学
一句话定义：**汝窑天青为骨、墨底绢纱为肤、朱砂一方印为神**

---

## 1. 设计哲学

### 1.1 理论支点

玻璃拟态是"隔一层看"，中国古典美学的对应物是绢、纱、宣纸、屏风：

| 现代 UI 概念 | 中国古典对应物 |
|---|---|
| 毛玻璃面板 | 糊窗宣纸 / 绢纱屏风 |
| Bento 网格 | 多宝格（博古架） |
| 半透明叠加 | 隔纱观物，隔而不绝 |
| 壁纸色晕 | 水墨晕染 |
| 激活态标记 | 落款印章 |

两套体系底层同构，不是拼贴。

### 1.2 三条纪律

1. **选宋不选明清**：单色釉、极简、克制。拒绝龙凤、青花瓷、大红大金等"游客风"元素。
2. **朱砂唯一化**：全局朱砂红 `#c8452c` 只出现在 eww bar 当前 workspace 印章（22×22 方印）。任何其他组件需要"红点/红标"语义时，一律改用藤黄或赭石（见 §2.1）。
3. **功能优先**：一切装饰服从 i3wm 的工具属性，视觉服务于信息层级。

### 1.3 避坑清单

- 纹样不超过一种，只出现在边框、背景等次要表面，面积 < 5%
- 拒绝对称装饰，用不对称留白
- 圆角全局收敛在 3–6px（大圆角滑向 iOS 风）
- 不用书法字体做正文（文楷是楷不是草，可用）
- 告警色不用红（避免与朱砂打架），用藤黄 / 赭石

---

## 2. 色彩体系

### 2.1 色板（Design Tokens）

令牌定义在 `.chezmoi.yaml.tmpl` `data.colors`，全仓库模板用 `{{ .colors.* }}` 引用。

| Token | 色名 | Hex | 用途 |
|---|---|---|---|
| `bg_base` | 玄（墨色） | `#1a1a1e` | 窗口 / 面板底色（配合透明度） |
| `bg_elevated` | 黛 | `#21212a` | 浮层底色 |
| `ink` | 墨 | `#2e2e36` | 分隔线、次要面 |
| `fg_primary` | 月白 | `#e8e6df` | 正文文字（暖白，不用死白） |
| `fg_secondary` | 蟹壳青 | `#9a9a92` | 次要文字 |
| `ink_text`     | 题字墨 | `#202024` | 浅色底上的自适应暗字（`fg_primary` 的暗字双胞胎） |
| `ink_text_dim` | 次阶墨 | `#3a3a34` | 浅色底上的自适应暗次字（`fg_secondary` 的暗字双胞胎） |
| `accent`       | 天青（汝窑） | `#9ec8c0` | 强调、激活态、边框高光 |
| `seal` | 朱砂 | `#c8452c` | **仅当前 workspace 印章** |
| `warn` | 藤黄 | `#d8a23c` | 警告、urgent、更新角标 |
| `error` | 赭石 | `#a0522d` | 错误、critical、终端 ANSI red |

衍生固定值（不入令牌，按需引用）：`#15151a`（玄之暗部/crust）、`#3a3a44`、`#464652`（墨之亮阶）、`#cfccc2`（月白次阶）、`#6f6f68` / `#85857d`（蟹壳青暗阶）、`#8a9a6b`（苔绿，终端 ANSI green）、`#c9b8b3`（赭粉，终端 ANSI magenta）、`#7fa8a0`（深天青，终端 ANSI cyan）。

**语义映射纪律**：
- "选中/激活/链接/高亮" → `accent`（天青），永不使用蓝紫系
- "urgent/待更新/提醒" → `warn`（藤黄）
- "错误/危险/删除" → `error`（赭石）
- "当前位置" → `seal`（朱砂），只此一处

### 2.2 玻璃透明度分级

层级用透明度差表达，而非阴影深度（模拟不同厚度的绢）：

| 层级 | alpha | 用于 | 实现 |
|---|---|---|---|
| L1 常驻层 | 0.90 | bar | `.bar-inner`（沉墨立骨，对浅壁纸鲁棒；可调 0.92，以像素采样复核，见 `docs/design/bar-refactor.md` §3.1） |
| L2 功能面板 | 0.65 | 弹层主体 | `.popup` / `glass-shell(0.65)` |
| L3 强调格 | 0.55 | 弹层中重点卡片（media-card 等） | `glass-cell(0.55)` |
| L3 普通格 | 0.30 | 弹层中常规格子（列表行、信息卡） | `glass-cell(0.30)`，mixin 默认值；弹层审计（2026-07-22）统一收编，禁用 0.24/0.28/0.32 散值 |
| L4 临时层 | 0.60 | 通知、菜单、OSD | `.notification-popup`、`.osd`、dunst `@99` |

### 2.3 发丝线（hairline）

```scss
border: 1px solid rgba($accent, 0.35);   // 面板外框
border: 1px solid rgba($accent, 0.15);   // 格内分隔
```

- bar 顶、底各一条 1px 发丝线（立轴天杆地杆）
- 阴影要"贴面"不要"悬空"：eww 内 `0 4px 12px rgba(#15151a, 0.35)`；picom 见 §5

---

## 3. 字体方案

| 用途 | 字体 | 说明 |
|---|---|---|
| 中文界面正文 | LXGW WenKai（霞鹜文楷） | Regular，楷体感克制 |
| 标题 / 时钟展示 | Source Han Serif CN（思源宋体） | Bold/Heavy，取宋刻本筋骨，letter-spacing 2px |
| 西文 / 数字 | JetBrains Mono(Nerd Font) | 保持工具属性 |
| workspace 印章字 | Chong Xi Small Seal（崇羲篆體）十天干字形 | 文楷回退；字形瘦，1.20× 光学补偿（不算第三字阶）；>10 回落数字 |

字体安装：经 eos-bootstrap `ansible/roles/packages`（`adobe-source-han-serif-cn-fonts` 官方源、`ttf-lxgw-wenkai` AUR）。

字号阶梯：11 / 13 / 16 / 22，行高 1.5。中文标题加 letter-spacing 2px，正文不加。

各组件字体栈：
- eww 全局：`"JetBrainsMono Nerd Font", "LXGW WenKai", "Symbols Nerd Font", "Noto Sans CJK SC"`
- eww 弹层标题：`.popup-title` / `.section-label` → Source Han Serif CN + `accent`
- i3 窗口标题：`font pango:LXGW WenKai 10`
- dunst：`LXGW WenKai 10`；rofi launcher：`LXGW WenKai 18`
- 锁屏时钟：`Source Han Serif CN` 72px

**西文回退机制**：i3 / dunst / rofi / GTK 等组件只设 `LXGW WenKai` 单一字体名，西文/数字的 JetBrains Mono 回退由 fontconfig 全局处理（`dot_config/fontconfig/fonts.conf`）：请求 `LXGW WenKai`（或 `霞鹜文楷`）时，family 列表被替换为 `[JetBrainsMono Nerd Font, LXGW WenKai]`，Latin 字符命中前者、CJK 字符回落后者。新增组件若使用文楷，无需重复配置字体栈，fontconfig 自动生效。

---

## 4. 组件规范

### 4.1 Bar —— 装裱卷轴

- 高度：DPI 三档 32 / 44 / 64px（`.chezmoitemplates/eww-sizes` 的 `barHeight`）
- 底色 `bg_base` alpha 0.90；顶、底各一条发丝线；无阴影
- 模块分隔符用「·」（`.bar-sep`），不用 `|`；「·」alpha 0.32，只许出现在语义大分组之间（全 bar 仅右端两处）
- 布局：`[引首章(app-grid)] [印章区] ······ [tray 墨盒] · [状态簇] · [落款款识+押角印]`
  - 左端 = 引首章（天青发丝线框，与印章同尺寸成族）+ 姓名章组，组内零「·」
  - 右端 = tray 墨盒 · 状态簇（net/bat/upd/cc，簇内无「·」）· 落款款识 + 押角印（通知铃）
- 时钟格式「辰时 · 08:08」：`scripts/shichen.sh`（`hour → (hour+1)/2 %12` 映射十二时辰），`defpoll` 10s；落款用思源宋体 + 2px 字距，bar 内唯一展示字；不含 dow/md，完整日期下沉 calendar-popup

### 4.2 Workspace 指示器 —— 印章

实现：`scripts/workspaces.sh` 输出天干 label，三态 class：

```scss
.ws-seal {
  font-family: "LXGW WenKai";
  border-radius: 3px;
  padding: 2px 5px;
  &.active   { background: $seal; border: 1px solid $seal; color: $fg_primary; font-weight: bold; }
  &.occupied { border: 1px solid $accent; color: $accent; }
  &.idle     { border: 1px solid rgba($fg_secondary, 0.40); color: $fg_secondary; }
  &.urgent   { border: 1px solid $warn; color: $warn; animation: urgent-pulse 1s ease infinite alternate; }
}
```

三态都必须给 border（含 active），否则切换时尺寸跳动。左端四枚方印（引首章 + 印章组）同尺寸同 3px 圆角，active 不放大——朱砂实底已是最重一级，靠色不靠尺寸。

### 4.3 弹层 —— 多宝格

- 圆角统一 `$radius: 5px`；格子间距 12px；弹层 padding 22px
- 透明度按 §2.2 分级混排（0.55 / 0.65）
- 格子标题：`.popup-title`（宋体 Bold + 天青 + 2px 字距）；`.section-label` 天青
- 列表/菜单项 hover：左侧 2px 天青竖条（界引）。**必须**默认 `border-left: 2px solid transparent`，hover 只改 color，避免布局跳动：
  ```scss
  .row { border-left: 2px solid transparent; }
  .row:hover { border-left-color: $accent; }
  ```

### 4.4 通知 —— 手卷

- dunst：圆角 5、icon 圆角 3、图标最大 28px、frame 1px 天青（critical 用赭石框）、背景 `bg_base@99`（≈L4）
- eww 通知弹层：L4 0.60；App 图标用 28×28 **天青线框方印**（`radius-sm` 3px）
  - ⚠️ 原始设计稿此处用朱砂印，与"朱砂唯一化"自相矛盾，已裁定为天青。后续设计不得改回。
- 动效：picom fade 兜底，eww 不做组件级动画

### 4.5 菜单 / 二级弹层

- 复用"透明全屏事件层"方案（`popup-scrim`）：点击任意处关闭
- 菜单本体 L4 玻璃 + 5px 圆角 + 发丝线；项 hover 见 §4.3 界引规范

### 4.6 OSD

居中浮层，L4 0.60 + 发丝线，圆角 5px，slider 圆角 4px。

### 4.7 锁屏

- 时钟：Source Han Serif CN 72px 月白
- ring：常态/验证 天青（alpha 44），退格 藤黄，错误 赭石；`--radius=80 --ring-width=4`
- 立轴合成图：换壁纸或每小时由渲染器预生成（模糊壁纸 + 竖排诗句 + 干支方印 + 时辰 + 落款干支年节气 + 随形闲章「自得」；弃公历，时间观统一传统四层），锁屏零渲染开销

### 4.8 壁纸与晕染

- 选水墨 / 绢本设色低饱和大图（如《千里江山图》局部），或纯色 + 极浅宣纸纹理
- 默认生成图：纯玄色 `#1a1a1e`（`run_once_after_generate-default-wallpaper.sh`）
- picom 模糊开大，让壁纸透过玻璃只剩"色晕"——晕染在背景层完成

---

## 5. picom 配套参数（`dot_config/picom/picom.conf`）

```conf
blur-method = "dual_kawase";
blur-strength = 8;              # 8–12 区间
blur-background = true;
blur-background-fixed = true;

shadow = true;
shadow-radius = 12;
shadow-opacity = 0.35;
shadow-offset-x = 0;
shadow-offset-y = 4;            # 贴面，非悬空

fading = true;
fade-in-step = 0.06;
fade-out-step = 0.06;

corner-radius = 5;              # 全局一致
```

eww 的 bar 与 scrim 在 rounded/shadow/blur exclude 清单中；Rofi `corner-radius 0`（自绘圆角）。

---

## 6. 间距与网格

- 基础单位 4px；阶梯 4 / 8 / 12 / 16 / 24
- i3 `gaps inner 8`（i3 ≥ 4.22 原生支持），窗口边框 2px
- i3 边框色：focused 天青 / unfocused 墨 / urgent 赭石（`dot_config/i3/config.tmpl`）
- bar 水平内边距 12px；bar 组内步长统一 8px（模块间距 6px 已废除）；弹层距屏边 12px（与 i3 gap 对齐）

---

## 7. 各组件落地清单

| 组件 | 文件 | 要点 |
|---|---|---|
| 令牌根 | `.chezmoi.yaml.tmpl` | 11 个语义 token，全仓库唯一来源 |
| i3 | `dot_config/i3/config.tmpl` | gaps 8、天青/墨/赭石边框、文楷标题字体 |
| eww 令牌 | `dot_config/eww/styles/colors.scss.tmpl` | 语义变量 + `$radius/$radius-sm`；旧 Catppuccin 变量仅作别名 |
| eww 基座 | `dot_config/eww/styles/base.scss.tmpl` | `glass-shell/glass-cell` mixin、`.popup`、开关方化 |
| eww bar | `dot_config/eww/components/bar.yuck.tmpl` + `dot_config/eww/styles/bar.scss.tmpl` | 立轴重裱（引首章/印章族/墨盒/落款/押角印）见 `docs/design/bar-refactor.md` |
| eww 尺寸 | `.chezmoitemplates/eww-sizes` | DPI 三档，改尺寸只动这里 |
| dunst | `dot_config/dunst/dunstrc.tmpl` | §4.4 |
| rofi | `dot_config/rofi/themes/palette.rasi.tmpl` + `display/post-switch.d/executable_20-rofi-dpi` | 玻璃 rgba + 圆角 3/5/5 |
| GTK4 | `dot_config/gtk-4.0/{settings.ini,gtk.css}.tmpl` | Adwaita + prefer-dark；popover/menu/tooltip 覆写天青发丝 |
| GTK3 | `dot_themes/catppuccin-glass/` + `dot_config/gtk-3.0/settings.ini.tmpl` | 主题级玻璃（不单独换宋式，见 §9 妥协） |
| Qt | `dot_config/Kvantum/` | GeneralColors 取令牌；`kvantum.kvconfig` 必须 INI 格式 |
| 锁屏 | `dot_config/i3/scripts/lock-render.py.tmpl` + `executable_lock.sh.tmpl` + `dot_config/systemd/user/lockscreen-refresh.*` | §4.7 |
| 壁纸 | `.chezmoiscripts/common/run_once_after_generate-default-wallpaper.sh` | 玄色生成 |
| fontconfig | `dot_config/fontconfig/fonts.conf` | LXGW WenKai → JetBrainsMono Nerd Font 西文回退（§3） |

**暂未统一**（用户裁定保留现状）：WezTerm（Tokyo Night + 背景图）、tmux（同步 Tokyo Night）。后续若要统一，沿用 §2.1 衍生固定值：终端 ANSI red 必须用赭石而非朱砂，朱砂只可作 tmux 当前窗口标记（印章语义延伸）。

**色彩飞地登记**：systray 图标色不受令牌约束（外部进程绘制），但必须被墨色容器收容（`.bar-tray`，3px 圆角 + 4px 内 padding）——全系统唯一色彩飞地。容器用墨之亮阶 `#464652`（`$surface2`）alpha 0.40：实测 `rgba($ink,0.30)` 在亮壁纸区段与 bar 底仅差 ≤2 阶近隐形（2026-07-22 裁定），亮阶浅盒在任何壁纸下保持 Δ≥9 阶。

---

## 8. 平台陷阱（血泪清单，改动前必读）

### 8.1 eww SCSS 必须纯 ASCII

任何非 ASCII 字节（包括中文注释、破折号 `—`、间隔号 `·`）进入 SCSS，grass 会在编译产物前加 `@charset "UTF-8"`，GTK3 视其为 unknown @ rule 并**丢弃整个样式表**（bar 瞬间裸奔）。中文字形只允许出现在 `.yuck` 和脚本里。提交前检查：

```bash
grep -rPn '[^\x00-\x7F]' dot_config/eww/ --include='*.scss*'   # 必须无输出
```

### 8.2 `dot_config/gtk-3.0/gtk.css` 必须保持为空

USER 优先级的 GTK3 CSS 会压过 eww 的全部样式。GTK3 美化只能走 `~/.themes/` 主题（THEME 优先级）。

### 8.3 GTK 暗色的正确机制

- **不要**设 `GTK_THEME` 环境变量——它对 GTK3/GTK4 全局生效且会掩盖 settings.ini，指向不存在的主题时应用整体回落亮色
- GTK4：`settings.ini` 用 `gtk-theme-name = Adwaita` + `gtk-application-prefer-dark-theme = 1`；`Adwaita:dark` 冒号语法只在 env 有效
- libadwaita 应用跟随 `gsettings org.gnome.desktop.interface color-scheme prefer-dark`（已设）

### 8.4 rofi 的 rgba 必须手维护

rasi 无法从 hex 生成带 alpha 的颜色，`palette.rasi.tmpl` 中 `glass-*` rgba 字面量与令牌手动同步（文件头有注释说明）。

### 8.5 rofi 2.0 元素状态语法

`element normal { }` 不会命中，默认主题（米色 Solarized 风）会赢。必须写两段式：

```
element normal.normal, element alternate.normal { ... }
element selected.normal, element selected.active { ... }
element normal.urgent, element alternate.urgent { ... }
element selected.urgent { ... }
```

### 8.6 eww 几何尺寸在 apply 时烘焙

eww 0.5.0 不能在 `:geometry` 里解析变量，所有尺寸经 `.chezmoitemplates/eww-sizes` 按 DPI 三档（<144 / ≥144 / ≥192）写成字面量。改尺寸 → 改该文件 → `chezmoi apply` → `eww reload`。

### 8.7 Kvantum 配置格式

`~/.config/Kvantum/kvantum.kvconfig` 必须是 `[General]\ntheme=...` 的 INI；裸写主题名会导致主题静默不生效（Manager 显示 default）。

### 8.8 徽章与开关的圆角

- 滑条 trough/highlight：4px（999px 药丸已被废除）
- 开关/旋钮：5px / 3px 方角（不再是胶囊）
- 角标（更新、未读）：`$radius-sm` 3px 方点 + `warn` 藤黄底

### 8.9 eww label 的两个 GTK 行为坑（bar 重构实战）

- **带 `letter-spacing` 的 label 会被 GTK 少测宽度**（约 字距 × 间隙数），文本直接截成「…」。补偿：给 label 预留 `min-width`（`.time-main` 用 `fontSize × 7.5`，时辰串长恒定所以安全）。任何带字距的 label 改完必须截图确认未截断。
- **label 自身不接收 `:hover`**——hover 状态落在父 button/eventbox 上。`.child:hover` 永不命中；必须写 `.parent:hover .child` 后代选择器（`.time-btn:hover .time-main` 已验证）。

---

## 9. 已知妥协点（不得视为 bug 再改）

1. **GTK4 控件 accent 为 Adwaita 蓝**：全量换 accent 需自制完整 GTK 主题，性价比过低。popover/menu/tooltip 已被 gtk.css 覆写为天青。
2. **GTK3 主题保留 catppuccin-glass**：深色底不违和；重制 GTK3 主题工程量大。
3. **通知图标用天青框方印而非朱砂印**：设计稿自相矛盾处的裁定（见 §4.4）。
4. **时辰只到"时"不到"刻"**：刻的划分有歧义，性价比低。
5. **印章用崇羲篆體而非文楷**（2026-07-21 推翻旧裁定）：旧裁定"用文楷天干而非篆体 SVG"的前提是篆体只能贴 SVG；崇羲小篆以字体形态落地后，篆书印章的形制（朱底白字 + 篆籀）强于文楷，用户裁定更换。字形瘦长，以 1.20× 光学补偿，不破四印同尺寸纪律。
6. **WezTerm/tmux 保留 Tokyo Night**：用户裁定暂缓统一（见 §7 末）。

---

## 10. 新组件设计流程

1. 先查 §2 令牌：所需颜色是否已有语义？没有 → 先论证是否该加 token，禁止就地硬编码
2. 查 §4 对应组件规范；列表/菜单必有界引 hover（§4.3）
3. 圆角只许 3 / 4 / 5px；透明度只许 0.30 / 0.55 / 0.60 / 0.65 / 0.90。例外：锁屏随形闲章为有机轮廓（非圆角矩形、非正圆），豁免此圆角网格——见 `lockscreen.md` §3.4 / §8.6
4. 写完跑 §8.1 的 ASCII 检查；eww 改动后 `eww reload` + `eww logs` 无 CSS 错误
5. 视觉验证：`import -window root` 截图自查；涉及红色时用像素采样确认红色只出现在当前 workspace 印章：
   ```bash
   import -window root /tmp/check.png
   # 截图中除印章外不应出现 #c8452c 附近的像素
   ```
6. 若新组件引入了新语义（如新告警级别），回本文件 §2.1 补充映射纪律后再实现
