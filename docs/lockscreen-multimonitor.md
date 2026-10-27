# 锁屏多显示器 · 虚拟屏拼接

> 本文件记录「外接副屏锁屏后整块灰 `#a3a3a3`」的根因、源码证据与选定方案。
> 视觉设计语言仍以 `design/lockscreen.md`（立轴）为准；本文件只谈**画幅几何**与**图像消费者语义**。
> 完整设计与验收方案：`superpowers/plans/2026-10-27-lockscreen-multimonitor.md`。
> 代码：`dot_config/i3/scripts/lock-render.py.tmpl`、`dot_config/i3/scripts/executable_lock.sh.tmpl`。
> 调研日期 2026-10-27。勘验对象 `i3lock-color 2.13.c.5`、`lightdm-gtk-greeter 2.0.9`（lightdm 1.33.1）。

---

## 0. 一句话

i3lock 默认（`bg_type == NONE`）把 `-i` 的图**按原始像素画在 root 原点、不缩放**，而它先在整个虚拟屏画布上铺了默认底色 `#a3a3a3`。渲染器只产主屏尺寸的图 → 副屏那片区域无人落笔，露出底色。解法不是给 i3lock 加参数，而是让渲染器产一张**与虚拟屏包围盒等大的拼接图**。

---

## 1. 症状

双屏布局（`xrandr --listmonitors`）：

| 显示器 | 几何 | 角色 |
|---|---|---|
| `eDP-1` | `2560x1600+0+0` | primary（笔记本内屏） |
| `DP-1-1` | `3840x2160+2560+0` | 扩展（外接） |
| root window | `6400x2160` | 两屏并集包围盒 |

`$mod+Shift+L` 锁定后：

- **主屏**正常：模糊壁纸 + 竖排诗句 + 干支印 + 时辰 + 竖款 + 闲章 + 居中偏下的解锁环，与单屏时无差别；
- **外接副屏**整块纯灰，实测采样 `srgb(163,163,163)` = `#a3a3a3`（i3lock 的默认底色）。无壁纸、无文字、无环；
- **登录界面反而两屏都有壁纸** —— 这个对比最容易让人误判成「锁屏脚本没适配多屏」，实际是两个程序对图片的消费方式不同（§2 vs §3）。

---

## 2. 根因

### 2.1 `draw_image()` 默认分支：原尺寸、画在 (0,0)、不缩放

`i3lock-color 2.13.c.5`，`unlock_indicator.c:1208`：

```c
void draw_image(uint32_t* root_resolution, cairo_surface_t *img, cairo_t* xcb_ctx) {

    if (bg_type == NONE) {
        // Don't do any image manipulation
        cairo_set_source_surface(xcb_ctx, img, 0, 0);
        cairo_paint(xcb_ctx);
        return;
    }
```

三个要点：

1. 形参 `root_resolution` 在这个分支里**一次都没被读**；
2. 全程没有 `cairo_scale`；`cairo_set_source_surface` 隐式创建的 pattern 默认 `CAIRO_EXTEND_NONE`，`cairo_paint` 只在图片覆盖范围内落笔，图外一个像素都不改；
3. 只有显式给了 `-C/-F/-M/-L/-t`（`bg_type != NONE`）才进入 `unlock_indicator.c:1221-1263` 的 per-monitor 循环，按 `xr_resolutions[i]` 逐屏居中／裁切／拉伸／平铺。

### 2.2 `render_lock()` 先按 root 尺寸铺底色

`unlock_indicator.c:763-783` 按 `resolution[0] x resolution[1]` 建 cairo surface，而 `resolution` 就是 **root window**（整个虚拟屏），取自 `i3lock.c:2510-2511` 的 `screen->width_in_pixels/height_in_pixels`。随后 `unlock_indicator.c:803-814` 先铺底色、再画图：

```c
cairo_set_source_rgba(xcb_ctx, background.red, background.green, background.blue, background.alpha);
cairo_rectangle(xcb_ctx, 0, 0, resolution[0], resolution[1]);   /* 整个 root 尺寸 */
cairo_fill(xcb_ctx);
...
if (img) {
    draw_image(resolution, img, xcb_ctx);                        /* 之后才画图 */
}
```

底色来源是硬编码的 `char color[9] = "a3a3a3ff"`（`i3lock.c:74`），`colorgen()` 每两个 hex 字符 ÷255 → `0xa3/255` = 163（`unlock_indicator.c:655-665`、`692-693`）。`xcb.c:139-153` 的 `create_bg_pixmap()` 注释把用途写得明明白白：*"fill the pixmap with background color (for images that are smaller than your screen)"*。

→ **未覆盖区域 = 底色灰**。图放在 (0,0) 且只有 2560 宽时，x ≥ 2560 的整片（正是 DP-1-1）就是灰的。

### 2.3 本版本只支持单个 `-i`，不能每屏一张图

```c
// i3lock.c:246
char *image_path = NULL;
// i3lock.c:1768-1770
            case 'i':
                image_path = strdup(optarg);
                break;
```

单个 `char *`，解析处**直接覆盖**，既无数组也无「重复指定」检查（实测 `-i A.png -i B.png` 整屏 B 生效，stderr 无输出）。互斥检查只针对背景**类型**（`i3lock.c:1771-1796`：「Only one background type can be used.」），与图片张数无关。图片只在 `i3lock.c:2520-2531` 加载**一次**。唯一的多图功能是「路径指向目录 = 幻灯片」（`i3lock.c:2524-2528`、`unlock_indicator.c:786-801`），与分屏无关。

→ **「每台显示器喂自己那张图」在本版本不可能实现**，除非换 locker。

### 2.4 渲染器为什么只产主屏尺寸（改造前）

改造前的 `lock-render.py`，`get_screen_geometry()` 只认 `xrandr --query` 里 `connected` 且带 `primary` 的那一行，取 `WxH` 返回主屏几何（兜底 2560x1600）。`build_surface()` 据此建画布、`write_jpeg()` 写出 `_compose.jpg`，`lock.sh` 原样 `-i "$COMPOSE"`。

于是：2560x1600 的图被 i3lock 原尺寸画在 6400x2160 画布的 (0,0)，eDP-1 铺满，DP-1-1 全灰。

改造后（§4）由 `get_monitors()`（解析 `xrandr --listmonitors`）、`virtual_box()`、`primary_rect()`、`layout_key()` 取代这个单屏假设；`get_screen_geometry()` 仅作为降级路径保留。

### 2.5 Xvfb 实测（root 6400x2160，默认参数，无 `-C/-F/-M/-L/-t`）

| 传入 `-i` 图片 | (10,10) | (1400,10) | (3000,100) | (6300,2100) |
|---|---|---|---|---|
| 2560x1600 | 红 | 红 | `gray(163)` | `gray(163)` |
| 3840x2160 | 绿 | 绿 | 绿 | `gray(163)` |
| 6400x2160 | 红 | 红 | 红 | 红 |

对照实验：同一张 2560x1600 图加 `-F` → (3000,100)/(6300,2100) 全被铺满，证明确实是「走了 per-monitor 拉伸分支」而不是「图本身够大」。

**结论：图尺寸 == 虚拟屏包围盒 → 默认参数 1:1 铺满，不需要改 i3lock 参数。** 注：Xvfb 无法真正造出并排双 head（`+xinerama` 把两个 head 都放在 0,0，`xrandr --setmonitor` 不生效），但 `NONE` 分支完全不读 `xr_resolutions`/`xr_screens`，所以「root = 6400x2160 的单 head」与「双 head 并排」在该分支下行为完全等价。

---

## 3. 为什么登录界面正常

`lightdm-gtk-greeter 2.0.9`（二进制 `/usr/bin/lightdm-gtk-greeter`，配置 `/etc/lightdm/lightdm-gtk-greeter.conf` 的 `[greeter] background = /usr/share/backgrounds/default.png`）**为每台显示器各建一个 GtkWindow**，各自把同一张图 cover 裁切铺满：

| 环节 | 源码位置（`src/greeterbackground.c`，tag 2.0.9） | 行为 |
|---|---|---|
| 建窗 | `greeter_background_connect()`，`for` 循环每台显示器，`gtk_window_new(GTK_WINDOW_TOPLEVEL)` L601 | N 屏 = N 窗；`gtk_window_move(geometry.x, y)` + `size_request(geometry.width, height)`；hint = `DESKTOP` + `keep_below` |
| 取图 | `background_new()` L1243-1247 | 把**该显示器**的 `geometry.width/height` 传给 `scale_image()` |
| 缩放 | `scale_image()` L1581-1605，默认 `SCALING_MODE_ZOOMED` | `scale = max(W/pw, H/ph)` + 居中偏移 → `gdk_pixbuf_composite()`，即 CSS `background-size: cover`；`images_cache` key 含目标宽高，两屏各得一份结果 |
| 绘制 | `monitor_draw_background()` L1448-1466 | pixbuf 已等于该屏尺寸，`gdk_cairo_set_source_pixbuf(cr, img, 0, 0)` + `cairo_paint(cr)`，无 translate／无 scale |

没提到的一个细节容易误读：整块虚拟屏确实出现过一次，但那是在 `greeter_background_save_xroot()`（L1076）——登录成功时把**各屏已经缩放好的结果**按 `monitor->geometry.x/y` 平移到 `screen_width x screen_height` 的 pixmap 上设成 root，只服务 `background = #default`（走主题背景）的屏。这条路径是「先每屏 cover，再按屏坐标拼」，与「把一张大图整块铺一次」是两件完全不同的事。

→ greeter 的「两屏都有壁纸」并不证明它会消费一张虚拟屏大图；**正相反，它证明它对每屏各自 cover**。

---

## 4. 方案

### 4.1 采用：单张虚拟屏拼接画布

渲染器合成**一张**图，尺寸 = 所有显示器在 root 坐标系的**并集包围盒**；每台显示器的壁纸各自 cover（等比贴合、不拉伸）+ 模糊后，贴到自己的偏移处。默认 `-i` + 无背景参数即可 1:1 铺满（§2.5 实测）。

几何：

- `virtual_box(mons)` → `(minx, miny, VW, VH)`，`VW = max(x+w) - minx`，`VH = max(y+h) - miny` —— 天然支持负偏移（左接屏 `+-3840+0`）与上下排列；
- 贴图偏移 = `(x - minx, y - miny)`，即每屏在自己的包围盒坐标里归位；
- 缓存文件名 = `base-<壁纸 hash>-<布局 hash8>.png`（`ensure_base()` 里 `f"base-{h}-{lk}.png"`）：壁纸 hash 取壁纸内容 md5 前 12 位，布局 hash 即 `layout_key()` 对显示器列表取的 `sha256[:8]`；插拔屏后布局变 → 文件名变，不会残留旧尺寸的 base；`prune_bases()` 按 mtime 只保留最近 8 份；
- 合成一次 `magick` 完成：`-size VWxVH xc:#1a1a1e`，然后每屏 `\( SRC -resize WxH^ -gravity center -extent WxH -blur 0x20 \) -geometry +X+Y -composite`；
- `_compose.jpg` 尺寸 = 包围盒；`lock.sh` 无需改动（仍是 `-i "$img"`、仍是 `--ind-pos`）。

**装饰只画在主屏矩形内。** 画布是包围盒，但所有装饰坐标以主屏矩形为基准（`px0 = primary.x - minx`，`py0 = primary.y - miny`），字号／行距／印章形制／自适应取色全部不变；副屏只有模糊壁纸。理由：`design/lockscreen.md` 的「立轴」是一幅画，构图关系（右上竖诗 + 左下题识 + 中偏下环）只在单一比例的画面上成立；把它横跨两台长宽比不同的显示器，等于把一幅立轴裱成了通景屏，失去不对称构图的意义。

### 4.2 方案比较

| 方案 | 做法 | 结论 |
|---|---|---|
| **A. 单张拼接画布（采用）** | 合成图尺寸 = 虚拟屏包围盒，每屏各自 cover + blur 后按偏移贴图；一次 `-i` | ✅ 唯一干净方案：i3lock 默认分支天然 1:1 贴图，与显示器顺序无关，支持负偏移／上下排列／异分辨率；与 greeter 的视觉结果（每屏独立 cover）一致 |
| B. 每屏一张图（`-i` × N） | 指望 i3lock 分屏消费 | ❌ 本版本 `image_path` 是单个 `char *`（§2.3），重复 `-i` 后者覆盖；要支持必须换 locker 或自绘 X client |
| C. `-C` 居中 + 单图 | 让 i3lock 逐屏居中 | ❌ `-C` 只居中不缩放：2560x1600 的图在 3840x2160 屏上留一圈灰边，内容还在两屏重复出现 |
| D. `-F`／`-L` 拉伸填充 + 单图 | 让 i3lock 把单屏图铺满每屏 | ❌ 2560x1600 → 3840x2160 比例不同，`-F` 裁掉上下／`-L` 拉伸变形，文字与印章形制全错，违反设计纪律 |
| E. 换 locker（swaylock／hyprlock／自绘） | 换掉认证前端 | ❌ 成本与风险（PAM、键盘 grab、`lock.sh` 全链路重写、与 i3 的 dialogs 语义）远大于收益 |
| F. `freeze-overlay`（每屏 override-redirect 窗口） | 仓库已有同款机制（`dot_config/i3/scripts/freeze-overlay.c`，截图冻结用）：每屏一个贴截图的窗口 | ❌ 视觉上最「每屏原生」，但要自己实现锁屏认证 UI 与输入 grab，等于自研 locker。仅作最后兜底思路记录，不实施 |

**采用 A。** 它的额外好处是语义干净：图是「桌面在一张画布上的样子」，i3lock 只是把这张画布原样贴上去；将来基座屏／竖屏／三屏都只是包围盒和偏移变了，渲染逻辑不分叉。

### 4.3 为什么不是「让 i3lock 帮我缩放」

因为那要放弃默认分支：`-F/-L` 的 per-monitor 分支（`unlock_indicator.c:1221-1263`）语义是「同一张图在每块屏上重复、按各屏几何独立缩放」。我们想要的是「画面在虚拟屏上连续、每屏显示自己那一段」，这在逐屏缩放的模型里无法表达 —— 除非图已经是拼接好的。所以缩放必须发生在渲染器里，用 `cover` + `-extent` 而非 `stretch`。

---

## 5. greeter 镜像策略

**仍镜像主屏裁切图（2560x1600）**，不镜像 6400x2160 拼接图。

推演（`scale_image()` 的 cover 公式）：把拼接图丢给 greeter，每块屏都只看整图中间一条 ——

- eDP-1（2560x1600）：`scale = max(2560/6400, 1600/2160) = 0.7407`，`offset_x = (2560 - 6400×0.7407)/2 ≈ -1090` → 可见源区间 x ≈ 1090–3651（整图中间约 40% 宽）；
- DP-1-1（3840x2160）：`scale = max(3840/6400, 2160/2160) = 1.0`，`offset_x = (3840-6400)/2 = -1280` → 可见源区间 x ≈ 1280–5120。

→ 两块屏都看不到「自己那一半」，题诗／纪时／印章**重复出现且被放大裁切**，观感是「同一幅画错位并排、比例不同」。**不可接受。**

镜像主屏裁切的效果（实测）：eDP-1 像素级 1:1 相同；DP-1-1 按 1.5x 放大、上下各裁 120px（约 5%），题诗与纪时完整 —— 是**有意的**取舍：登录界面上一幅放大的同一张画，立轴依然成立，而变形的拼接图不成立。

实现：镜像走**独立子进程**，绝不占用锁屏关键路径。`compose_to()` 把完整拼接图写到 `_compose.jpg` 之后，立即 `subprocess.Popen([sys.executable, lock-render.py, "--mirror-greeter", <compose>], start_new_session=True, close_fds=True)` 起一个 detached 子进程就返回；子进程里 `mirror_greeter_to_greeter(src)` 用 `get_monitors()` / `virtual_box()` / `primary_rect()` 取主屏矩形，执行

```bash
magick <SRC> -crop <pw>x<ph>+<px>+<py> +repage -quality 92 ~/.cache/lockscreen/_greeter.jpg
sudo -n cp ~/.cache/lockscreen/_greeter.jpg /usr/share/backgrounds/default.png
```

即镜像的永远是主屏那 2560x1600，与画布尺寸无关。镜像慢或失败（如 `sudo -n` 未配置免密）都不影响本次锁定：greeter 背景只在下次登录（或 greeter 重绘）时才被读，最坏情况是落后一版。

> **备选（未采用，留作未来）**：给 greeter 加每屏分组，各喂一张原生尺寸图，两屏都 1:1 ——
> ```ini
> [greeter]
> # GKeyFile 不支持行内注释，注释必须整行
> background = /usr/share/backgrounds/default.png
> [monitor: eDP-1]
> background = /usr/share/backgrounds/lock-eDP-1.png
> [monitor: DP-1-1]
> background = /usr/share/backgrounds/lock-DP-1-1.png
> ```
> 源图尺寸 == 该屏尺寸时 cover 系数恒为 1.0，无裁切。为什么不现在做：`/etc/lightdm/lightdm-gtk-greeter.conf` 由 eos-bootstrap 的 ansible 部署（**不在 chezmoi 范围**），且 greeter 那个 X 会话的显示器名来自 X 自动配置、可能是别的名字，匹配失败会**静默**回落默认组；为此引入两份额外产物与一处系统级配置，收益不抵复杂度。显示器名对不上时还可补 `[monitor: 0]` / `[monitor: 1]` 序号兜底（查找顺序：名字 → 序号）。

---

## 6. 验收

三层，从离线到实机：

### 6.1 离线自动化（无硬件依赖，可反复跑）

`scripts/tests/verify-lock-multimonitor.sh`（仓库内、`.chezmoiignore` 忽略的 `scripts/` 下，不部署；退出码 `0` 全绿 / `1` 有断言失败 / `77` 环境缺件跳过）。手法：造一个假 `xrandr` 前置到 `PATH`（只负责打印 `--listmonitors`），`HOME` 指向临时目录并写入假 `~/.fehbg` 与渐变测试壁纸，从而完全离线控制几何与壁纸；每个 fixture 跑一次同步路径 `lock-render.py --lock-image <tmp>/out-<fixture>.jpg`（不经 daemon socket），再对输出的 JPEG 断言。三组 fixture：

| fixture | 布局 | 期望输出尺寸 |
|---|---|---|
| F1 | `eDP-1 2560x1600+0+0(primary)` + `DP-1-1 3840x2160+2560+0` | 6400x2160 |
| F2 | `eDP-1 2560x1600+0+0(primary)` + `DP-1-1 3840x2160+-3840+0`（负偏移） | 6400x2160 |
| F3 | 仅 `eDP-1` | 2560x1600 |

断言：

- 输出尺寸 == fixture 包围盒；
- 每块屏区域内 4 个采样点都**不是** `gray(163,163,163)`（F1/F2 的副屏区域尤其）；
- 副屏区域像素非纯色（渐变壁纸 → 证明真的铺了壁纸而非底色）；
- 赭石 `#a0522d`（`{{ .colors.error }}`，印章色）像素**只出现在主屏矩形内** —— 同时证明「文字只画在主屏」与「坐标已按包围盒偏移」；
- 换 fixture 后 base 缓存名不同（layout hash 生效）且尺寸随布局变化。

### 6.2 真实 i3lock 截图采样（需用户在场，约 2 秒）

```bash
i3lock -n -i <合成图> & sleep 1.5; import -window root /tmp/live.png; kill -9 %1
```

断言 `/tmp/live.png` 中 (3000,100) 等副屏采样点 != `gray(163)`，并目视确认两屏都是壁纸、文字只在主屏。**必须在用户明确同意时执行**（会抢输入焦点 1~2 秒）。离线侧的可复现脚本见调研产物 `/tmp/lock-mm/repro.sh`（独立 Xvfb，绝不用 `:0`；i3lock 会 fork raise_loop 子进程，必须整组 `kill -9`）。

### 6.3 实机端到端

`$mod+Shift+L` 锁定 → 两块屏都显示各自 cover 的模糊壁纸、无灰块 → 主屏题诗／干支印／时辰／款／闲章齐全，环在正确位置 → 输密码解锁成功。再插拔外接屏（或 `xrandr --output` 切换）后重新锁定，画布随布局变化、无旧尺寸残留。

### 6.4 回归

- 单屏（拔掉外接）锁屏与改造前**逐像素一致**（包围盒 == 屏，坐标偏移为 0）；
- 更换壁纸后锁屏自动跟随（base 缓存 key 含壁纸 hash）；
- greeter 镜像仍是主屏尺寸（`identify /usr/share/backgrounds/default.png` → 2560x1600），登录界面两屏有壁纸、无变形；
- `chezmoi apply` 无 drift。

---

## 7. 边界与坑

- **解锁环**：`--ind-pos` 的 `x`/`y` 是**相对每台显示器**的（`unlock_indicator.c:1020-1044`，`te_variable` 里 `x = xr_resolutions[current_screen].x`），所以 `lock.sh` 按单屏尺寸算出的 `cx:cy` 不用改。环本身会在每块屏各画一份（`-S/--screen` 可限定，现状保留 —— 副屏也有环，与「副屏无文字」不冲突）。
- **`lock.sh` 的 `geom` 取第一条 `connected`**：若外接屏在 `xrandr --current` 里排在前面，`cx/cy` 会按 3840x2160 算。语义仍是「相对每屏」，只是两块屏的环都按大屏的 55% 高度偏下 —— 既有行为，本次不动。
- **负偏移解析**：`xrandr --listmonitors` 的几何写作 `2560/344x1600/215+0+0`，左接屏是 `+-3840+0`。正则写 `\+(-?\d+)\+(-?\d+)` 即可：`+` 后面允许负号，`+2560+0` 与 `+-3840+0` 两种写法都能吃；不能只匹配 `\+\d+`。
- **`base` 缓存清理**：`prune_bases(keep=8)` 按 mtime 只保留最新 8 份 `base-*.png`，否则每次换壁纸／插拔屏都多一份几 MB 的 PNG。
- **`/usr/share/backgrounds/default.png` 实际是 JPEG 数据**（`file` 报 `JPEG image data ... 2560x1600`）。`gdk_pixbuf_new_from_file()` 按内容嗅探，扩展名不符不影响加载，但校验脚本别按扩展名判断格式。
- **`#1a1a1e` 兜底底色**：包围盒内理论上没有不属于任何显示器的像素（包围盒定义保证），仍填 `#1a1a1e` 防止 `minx/miny` 计算偏差时露出 magick 默认黑或 i3lock 的 `#a3a3a3`。
- **不要给 i3lock 加 `-F/-L`** 试图「顺手修好」：那会在每屏重复同一张图并各自缩放，症状从「灰块」变成「内容重复 + 变形」，且比灰块更难察觉。

---

## 8. 交叉索引

| 文档／代码 | 关系 |
|---|---|
| `design/lockscreen.md` | 视觉设计语言（立轴、色彩、字体、留白）；其 §9「多显示器」是本文件的摘要 |
| `superpowers/plans/2026-10-27-lockscreen-multimonitor.md` | 实施与验收方案（几何函数、缓存、绘制坐标、V1-V4 验证清单） |
| `design/song-liquid-glass.md` | 色彩令牌与设计纪律；副屏留白不承载文字即其「留白即装饰」的延伸 |
| `dot_config/i3/scripts/lock-render.py.tmpl` | 渲染器（`get_monitors()` / `virtual_box()` / `primary_rect()` / `layout_key()` / `ensure_base()` / `prune_bases()` / `compose_to()` / `mirror_greeter_to_greeter()`；CLI：`--daemon`、`--lock-image`、`--ensure-base`、`--mirror-greeter`） |
| `dot_config/i3/scripts/executable_lock.sh.tmpl` | 调用方（`-i`、`--ind-pos`、i3lock 参数） |
| `dot_config/i3/scripts/freeze-overlay.c` | 「每屏一个 override-redirect 窗口」的现有同款机制，方案 F 的参考 |
| `scripts/tests/verify-lock-multimonitor.sh` | §6.1 的离线验收脚本（F1–F3 fixture，退出码 0/1/77） |
