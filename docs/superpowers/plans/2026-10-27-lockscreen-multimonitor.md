# 锁屏多显示器铺满 · 设计与验证方案

**日期**: 2026-10-27
**范围**: `dot_config/i3/scripts/lock-render.py.tmpl`（核心）、`executable_lock.sh.tmpl`（如需要）、`scripts/tests/`（新增验收脚本）、`docs/design/lockscreen.md`（文档）
**症状**: 外接显示器（DP-1-1 3840x2160+2560+0）锁屏后整块灰色，主屏（eDP-1 2560x1600+0+0）正常显示锁屏壁纸与题诗/纪时。开机登录界面两块屏都有壁纸。

---

## 1. 根因（已用源码 + Xvfb 实测双重确认）

`i3lock-color 2.13.c.5`：

1. `unlock_indicator.c: render_lock()` 在**整块虚拟屏分辨率**（root window 6400x2160）的 pixmap 上先铺底色，再调 `draw_image()`。
2. `unlock_indicator.c: draw_image()` 在默认模式（未传 `-C/-F/-M/-L/-t`，即 `bg_type == NONE`）下执行：

   ```c
   if (bg_type == NONE) {
       cairo_set_source_surface(xcb_ctx, img, 0, 0);
       cairo_paint(xcb_ctx);
       return;
   }
   ```

   即**按图片原始像素尺寸、画在虚拟屏左上角 (0,0)，完全不缩放**。只有 `-C/-F/-M/-L/-t` 才会用 `xr_resolutions[i]` 逐屏居中/裁切/拉伸。
3. 图片没覆盖到的区域保留底色 → 默认灰 `#a3a3a3`（实测 `gray(163,163,163)`）。
4. `i3lock.c` 中图片只有**单个** `char *image_path`，本版本**不支持每屏一张图**（`-i` 重复只会覆盖）。

现状：渲染器 `lock-render.py` 只按**主屏**尺寸合成 `_compose.jpg`（2560x1600，`get_screen_geometry()` 只取 primary），所以 i3lock 把 2560x1600 画在 6400x2160 画布左上角 → eDP-1 铺满、DP-1-1 区域（x≥2560）全是灰。

Xvfb 实测（root 6400x2160，无 Xinerama 分屏）：

| 传入图片 | (10,10) | (1400,10) | (3000,100) | (6300,2100) |
|---|---|---|---|---|
| 1280x800 | red | gray(163) | gray(163) | gray(163) |
| 3840x2160 | green | green | green | gray(163) |
| 6400x2160 | red | red | red | red |

**结论：传一张与 X root window 等大（6400x2160）的拼接图，默认参数即可 1:1 铺满，不需要改 i3lock 参数，不需要 -C/-F/-L。**

## 2. 方案比较

| 方案 | 说明 | 结论 |
|---|---|---|
| **A. 单张拼接画布（采用）** | 合成图尺寸 = **X root window 尺寸**（`xrandr --current` 的 `current W x H`，即 i3lock 建 pixmap 用的尺寸；未知时回退到显示器包围盒 `max(x+w)-min x` × `max(y+h)-min y`），每台显示器各自的壁纸按 cover 贴合（不拉伸）后贴到自己的偏移处；一次 `-i` | ✅ 唯一干净方案；i3lock 天然 1:1 贴图；与显示器顺序无关，支持负偏移/上下排列 |
| B. 每屏一张图（`-i` × N） | 需要 i3lock 支持多图 | ❌ 本版本不支持（单 `image_path`），需换 locker |
| C. `-C` 居中模式 + 单图 | i3lock 逐屏居中 | ❌ 单图无法同时匹配两种分辨率，且居中会裁切重复 |
| D. 换 locker（swaylock/hyprlock/自绘 X client） | — | ❌ 成本高，收益为零 |
| E. `freeze-overlay`（每屏 override-redirect 窗口） | 仓库里 `freeze-overlay.c` 已有同款机制（截图冻结用） | ❌ 需要自己实现认证 UI；仅作最后兜底思路 |

**采用 A。** 顺带说明：登录界面（lightdm-gtk-greeter）之所以两屏都有壁纸，是因为它**为每台显示器各建一个 GTK 窗口、各自 cover 裁切同一张背景图**（与 A 的视觉结果一致：每屏独立 cover 壁纸）。因此镜像给 greeter 的背景仍应是**主屏尺寸的合成图**（greeter 自己逐屏 cover），不能把 6400x2160 拼接图丢给它（否则每屏都显示整张拼接图被裁切的局部）。

## 3. 实现设计（lock-render.py）

### 3.1 几何

```python
def get_monitors():
    # 解析 `xrandr --listmonitors`
    #  " 0: +*eDP-1 2560/344x1600/215+0+0  eDP-1"
    #  → [{"name","primary","x","y","w","h"}, ...]
    # 正则: ^\s*(\d+):\s+([+*]+)(\S+)\s+(\d+)/\d+x(\d+)/\d+\+(-?\d+)\+(-?\d+)
    # 失败回退：解析 `xrandr --query` 里**所有** connected 行（每行一项），
    # 再回退单个 2560x1600@0,0 并打标记 fallback=True（monitors_reliable() 用它判断）

def root_geometry():
    # `xrandr --current` 的 current W x H → (W, H)；失败再用 `xdpyinfo` 的 dimensions；
    # 都不行返回 None

def canvas_size(mons):
    # 返回 (minx, miny, W, H)。已知 root 尺寸时 W/H = max(root, 包围盒)，
    # 且 minx/miny = min(0, 该轴最小偏移) 保证偏移非负；root 未知时退化为 virtual_box(mons)
```

- `virtual_box(mons)` → `(minx, miny, VW, VH)`，`VW = max(x+w) - minx`，`VH = max(y+h) - miny`（保留，仍表示包围盒）。
- `canvas_size(mons)` → 画布几何，优先 root 尺寸（i3lock 真正用的尺寸），`build_base_canvas()` / `ensure_base()` 的兜底纯色块都用它。
- `layout_key(mons)` → `"eDP-1:2560x1600+0+0|DP-1-1:3840x2160+2560+0"` 的 `sha256` 前 8 位。
- `primary_rect(mons, minx, miny)` → 主屏（`primary` 为真）否则 `mons[0]`，坐标相对画布原点。

### 3.2 缓存

`ensure_base()` 的 base 文件名从 `base-<壁纸hash>.png` 改为 `base-<壁纸hash>-<layout hash>.png`，尺寸 = **X root 尺寸**（`canvas_size()`；root 不可知时才退化为包围盒），内容 = 各显示器区域 cover+blur 壁纸。

- 若 `get_monitors()` 走的是硬回退（`monitors_reliable()` 为假）且缓存里已有任意 `base-*.png`，**直接复用最新那份、不重建**——否则一次 xrandr 抖动就会把 6400x2160 的 base 换成 2560x1600 单屏画布，锁屏满屏灰。只有完全没有缓存时才建 fallback 单屏画布。

- 一次 `magick` 调用完成拼接：
  ```
  magick -size VWxVH xc:#1a1a1e \
    \( SRC -resize W0xH0^ -gravity center -extent W0xH0 -blur 0x20 \) -geometry +X0+Y0 -composite \
    \( SRC -resize W1xH1^ -gravity center -extent W1xH1 -blur 0x20 \) -geometry +X1+Y1 -composite \
    out.png
  ```
  （`X0 = x0-minx`，`Y0 = y0-miny`）
- 无壁纸时 `magick -size VWxVH xc:#1a1a1e`。
- 顺手清理旧 base：按 mtime 只保留最新 8 个 `base-*.png`（可选，低风险）。

### 3.3 绘制（build_surface）

- 画布 = base 的**真实像素尺寸**（`cairo.ImageSurface.create_from_png` 的 W/H），不用另外再问一次几何。
- 随后再取 `get_monitors()` + `canvas_size()`：只有算出来的 `(vw, vh) == (W, H)` 才用 `primary_rect()`；否则说明 base 建好之后布局变了（热插拔），此时退化为「整张画布当主屏」（`px,py,pw,ph = 0,0,W,H`），保证装饰一定落在画布内，不会画到画布外。
- 所有装饰坐标改为**相对主屏矩形**：`px0 = primary.x - minx`，`py0 = primary.y - miny`：
  - `poem_cx = px0 + int(pw*0.88)`，`poem_top = py0 + int(ph*0.10)`
  - `shichen_x = px0 + int(pw*0.06)`，`shichen_y = py0 + int(ph*0.82)`
  - 其余（字号、行距、印章、自适应墨色采样）不变；自适应采样的 `bg` 仍用整张画布（区域内坐标不受影响）。
- 副屏只有模糊壁纸（无文字），保持「立轴」只存在于主屏的构图。

### 3.4 输出与镜像

- `_compose.jpg` 尺寸 = root 尺寸（lock.sh 无需改动，仍是 `-i "$COMPOSE"`）。
- **原子写**：`write_jpeg()` 先写 `out_path` 同目录的 `.‹name›.tmp‹pid›.jpg`（文件名仍以 `.jpg` 结尾，否则 magick 无法推断输出格式），成功后 `os.replace()` 原子替换；异常时删临时文件。lock.sh 永远不会读到半张 JPEG。
- greeter 镜像**不阻塞锁定**：`compose_to()` 在 `_compose.jpg` 更新后 fork 一个 detached 子进程跑 `--mirror-greeter _compose.jpg`，子进程用 `magick -crop` 裁出主屏矩形写 `_greeter.jpg`，再 `sudo -n cp` 到 `/usr/share/backgrounds/default.png`，整个过程失败也静默。
- daemon 协议不变（`L` → `ok`）；`--lock-image OUT` 语义不变（输出 root 尺寸图）。

### 3.5 指示环与 socket 超时

`lock.sh` 的 `--ind-pos` 仍按主屏尺寸算：i3lock 的 ind-pos 是**相对每台显示器**的（`xr_resolutions[current_screen]` + `screen_x/screen_y`），所以无需改。指示环本来会在每块屏都画一份（`-S/--screen` 可限定），维持现状。

`lock.sh` 里 daemon socket 的超时是 `settimeout(8)`：daemon 稳态 1.5–2s、冷启动（重算 base）约 4s，8s 已有 2x 余量；再长会让 daemon 卡死时桌面多暴露十几秒（隐私问题）。超时只会退到同步渲染（约 2s），不是致命失败。

## 4. 验证方案

### V1 · 自动化（无硬件依赖，可反复跑）

`scripts/tests/verify-lock-multimonitor.sh`（仓库内、chezmoi 忽略的 `scripts/` 下，不部署）：

1. 造一个假 `xrandr`（PATH 前置），按 fixture 打印 `--listmonitors`、`--query`，并且 `--current` 也要输出与 fixture 一致的 `current W x H`（渲染器现在按 root 尺寸建画布）；`HOME` 指向临时目录，写入假 `~/.fehbg` 与渐变测试壁纸，从而完全离线控制几何与壁纸。被测脚本优先用 `chezmoi execute-template dot_config/i3/scripts/lock-render.py.tmpl` 渲染出的模板结果（失败才退回已部署的 `~/.config` 副本），并在输出里打印实际用的源以及它与部署副本是否一致（`diff -q`）。
2. 三组 fixture：
   - F1 双屏右接：`eDP-1 2560x1600+0+0(primary)` + `DP-1-1 3840x2160+2560+0`
   - F2 双屏左接（负坐标）：`eDP-1 2560x1600+0+0(primary)` + `DP-1-1 3840x2160+-3840+0`
   - F3 单屏：只有 `eDP-1`
3. 对每组跑 `lock-render.py --lock-image /tmp/out.jpg`，断言：
   - 输出尺寸 == X root 尺寸（fixture 的假 `--current` 由包围盒推导，故此处 F1/F2: 6400x2160，F3: 2560x1600，与包围盒断言等价）；
   - 每块屏区域内 4 个采样点都**不是** `gray(163,163,163)`（F1/F2 副屏区域尤其）；
   - 副屏区域像素非纯色（渐变壁纸 → 说明确实铺了壁纸而不是底色）；
   - 印章色（`{{ .colors.error }}` = `#a0522d`）像素只出现在主屏区域内（证明文字只画在主屏、且坐标已按画布偏移）；
   - 换 fixture 后 base 缓存文件名不同（layout hash 生效），且尺寸随布局变化。
4. 输出 PASS/FAIL 明细，失败退出码非 0。

### V2 · 真实显示器集成（需用户在場，约 2 秒）

```bash
i3lock -n -i <合成图> & sleep 1.5; import -window root /tmp/live.png; kill -9 %1
```
断言：`/tmp/live.png` 中 (3000,100) 等副屏采样点 != gray(163)；截图人工目视确认两屏都是壁纸、文字只在主屏。**必须在用户明确同意时执行**（会抢输入焦点 1~2 秒）。

### V3 · 端到端（用户实机验收）

`$mod+Shift+l` 锁定 → 两块屏都显示壁纸（无灰块）→ 主屏有题诗/纪时/印章、环在正确位置 → 输入密码解锁成功。再验证插拔外接屏（或 `xrandr --output` 切换）后重新锁定，画布随布局变化。

### V4 · 回归

- 单屏（无外接）锁屏与改造前完全一致（尺寸、构图、环位置）。
- 壁纸更换（`feh` 设置新壁纸）后锁屏自动跟随（base 缓存 key 含壁纸 hash）。
- greeter 镜像仍是主屏尺寸（`identify /usr/share/backgrounds/default.png`），登录界面两屏仍有壁纸。

## 5. 验收标准

- [ ] 双屏锁屏：两块屏均显示各自 cover 的模糊壁纸，无任何灰色区域
- [ ] 装饰（诗/干支印/时辰/款/闲章）只在主屏出现一次，位置与改造前的主屏构图一致
- [ ] 单屏行为与改造前完全一致
- [ ] 负偏移 / 上下排列 / 不同分辨率布局下不出现错位或灰块（V1 fixture 覆盖）
- [ ] 解锁环位置正确、密码解锁正常
- [ ] base 缓存按「壁纸 hash + 布局 hash」失效，插拔显示器后不出现旧尺寸残留
- [ ] greeter 背景仍为 2560x1600（主屏裁切），登录界面两屏正常
- [ ] `chezmoi apply` 无 drift；V1 脚本全绿
