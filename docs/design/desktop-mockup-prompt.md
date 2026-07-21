# Desktop Mockup Prompt

整套「绢纱琉璃 · 宋式极简」系统的最终出图 brief：整屏为主，bar 顶条特写作为裁剪变体见注记 1。先前仅画 bar 顶条的稿件与上一版整屏稿均已废弃，合并并取代于此一份。bar 的形制严格遵循 `bar-refactor.md` 终态，色彩与组件纪律遵循 `song-liquid-glass.md`。

局限：模型大概率把天干「甲乙丙」、时辰「巳时」画成近似或乱码，nerd 图标画成"某种符号"。**只看形制、配色、留白、层次与气质，不验收文字正确性。**

## 主提示词

```text
Begin the frame on the single most charged detail, then pull back: a 22-pixel square of cinnabar seal-red #c8452c pressed onto a field of near-black ink, a hair of dusty celadon #9ec8c0 running along its top like the rod of a mounted scroll — hold that tension for a beat, then reveal it is one tiny chop inside a thin status bar pinned flush to the top edge of a working X11/i3 tiling desktop, 16:10, and that the desktop is a quiet scholar's studio at dusk. This is NOT a website, NOT a landing page, NOT a poster, NOT a hero with a centered headline: it is a machine someone is mid-thought inside.

Build the image in FIVE distinct depths so it has air, never a flat fill. (1) Deepest: a heavily compositor-blurred ink-wash / silk-painting wallpaper — misted mountains, desaturated to a warm-grey haze — so soft that only color remains, and at the edges of the glass panels above it a faint warm bleed of that haze shows through, proof there is a painting behind the silk. (2) Recessed: two tiled terminal panes, near-opaque dark, 2px ink/celadon borders, 8px gutter, monospace text dimmed and secondary, a text cursor parked mid-line on an unfinished command — the room's quiet machinery, pushed back so the eye does not rest here. (3) Mid-ground, the focal glass: a frosted ink-glass "curio-shelf" popup and, stacked just below it, a "handscroll" notification, both floating with a soft shadow that lies flat against the surface (0 4px 12px, low), never hovering, never glowing. (4) Foreground top: the hanging-scroll bar. (5) The living layer on top of all of it — the interaction states, described below.

Make it ALIVE with several small, specific, simultaneous moments, each expressed only as a shift of ink-depth or a hair of celadon light — never bounce, never neon: inside the popup one list row is caught mid-hover, its left edge lit by a 2px celadon vertical "boundary lead" while the rows above and below keep that same 2px bar transparent (so nothing shifts); in the bar one status module is under the pointer, its seat faintly washed celadon; the corner-press bell seal carries a single ochre-yellow dot that reads as seal-paste still wet, just pressed; the popup's Song-serif title seems to breathe through its 2px letter-spacing; the terminal cursor waits. Five heartbeats, one frame.

Compose ASYMMETRICALLY — this is a hard requirement, do not "correct" it toward balance. The popup sits high-right, the notification tucks under it and slightly inboard, the two terminals occupy the left and lower-center, and the bar's entire middle third is left as one long empty breath of ink. The negative space is off-center and deliberate, like the unpainted silk of a hanging scroll; a centered or mirrored arrangement would be wrong.

EXACT PALETTE, no substitutions: ink base #1a1a1e, elevated #21212a, divider #2e2e36, primary text warm off-white #e8e6df, secondary muted grey-green #9a9a92, accent dusty Ru-kiln celadon #9ec8c0, cinnabar #c8452c, warning ochre-yellow #d8a23c, error umber #a0522d. The cinnabar appears in EXACTLY ONE 22px square on the whole screen — the active workspace chop — and nowhere else; the celadon stays muted and dusty, never bright.

THE TOP BAR — the scroll's mounting border: full width, flush, corner radius 0, the DARKEST thing on screen, a near-opaque frosted ink strip at ~90% so the blurred wallpaper is NOT readable through it (only a faint cool undertone); it must sit visibly darker than the wallpaper. Top and bottom edges each carry ONE 1px celadon hairline at 35% alpha — the rods; no drop shadow, no outer glow, the bar stands by the lines. Three zones across wide empty ink. LEFT: four same-size square chops, 3px micro-corners, even 8px gaps, NO dots between them — a celadon-hairline square with a pale 3x3 grid glyph (leading idle seal), then three CJK seal-tiles: occupied = celadon outline + celadon glyph, active = SOLID cinnabar + off-white bold glyph (the only red), idle = faint grey-green outline + grey-green glyph. CENTER: pure empty ink, the unpainted silk. RIGHT: tray icons corralled inside a darker ink "ink-box" (rgba ink 30%, 3px corner, 4px padding) that tames their color; one faint middle-dot; a status cluster of small grey-green line icons at 8px with NO dots (wifi, battery + small %, an update glyph with a tiny ochre square dot top-right, a control glyph); one faint middle-dot; the time as a calligraphy colophon — a Song-serif off-white string with wide letter-spacing, then a small bell glyph as the corner-press seal. Only TWO text sizes in the whole bar: the colophon one notch larger in a Song serif, all else one quiet size.

THE POPUP — frosted ink-glass ~65% opacity, 5px corner, 1px celadon hairline, 22px padding, a quiet grid of cells; title in heavy Song serif, celadon, 2px letter-spacing; the hover row's boundary-lead as above; line icons in muted grey-green; one tile with a tiny ochre square badge.

THE NOTIFICATION — frosted ink-glass ~60% opacity, 5px corner, 1px celadon hairline, app icon a 28px celadon line-drawn square seal with 3px corners (NOT red), body in a calm regular kai face.

TYPOGRAPHY — four deliberate roles, strong contrast: Latin/digits in a technical monospace (JetBrains-Mono character); CJK body in a calm regular kai (LXGW WenKai character); CJK display, panel titles and the bar clock in a heavy Song serif (Source Han Serif character) with letter-spacing; symbol glyphs in a nerd/symbol face. The serif display should feel markedly larger and heavier than the whisper-quiet body — a real hierarchy, not a timid one. NO Inter, NO Roboto, NO Arial, NO Geist, NO single-family look, NO gradient-painted text.

SURFACE & LIGHT — austere and flat; the only gloss a barely-there 1px inset top highlight on each glass panel; soft photographic studio light grazing the frosted glass from one side. Micro 3–5px corners on every panel and chip — NO pills, NO large rounding, NO rounded-2xl. The restraint IS the attitude: bold in what it refuses. 4k, razor-sharp UI mockup, portfolio-grade but meditative — crafted, not templated.
```

## 负面提示词

```text
neon, glow, bloom, aurora blobs, decorative gradient, gradient text, gradient headline, indigo violet pink gradient, cyberpunk, sci-fi HUD, glossy iOS glass, site-wide glassmorphism, big rounded corners, rounded-2xl, pill shapes, saturated red, multiple red elements, cinnabar used more than once, centered hero, symmetric centered composition, mirrored layout, two equal halves, stacked headline-subtitle-CTA, row of equal feature cards, three-card layout, uniform card grid, flat single-plane layout, cream beige palette, terracotta accent, Inter font, Roboto font, Geist font, single typeface, busy, cluttered, cartoon, 3d render, chrome, gold ornament, dragon, blue-and-white porcelain pattern, decorative calligraphy brush strokes, drop shadow under the top bar, bright white background, website layout, landing page, poster composition, stock-photo symmetry
```

## 使用注记

按需改主提示词，其余段落不动。

1. **只要顶 bar 特写**：把开场两句换成 `A single ultrawide thin horizontal status bar, aspect ~80:1, height ~36px, full-screen crop of just the top strip —` 并删掉 `THE POPUP` / `THE NOTIFICATION` / 终端与五层深度里第 (2)(3) 层的描述。
2. **更透的旧玻璃感对比**：把 bar 段 `near-opaque ... ~90% ... NOT readable through it` 改成 `clearly translucent frosted glass at ~75%, the blurred wallpaper softly readable through the bar`。
3. **想逼模型出准中文**：末尾追加 `render the CJK glyphs exactly as: 甲 乙 丙 and 巳时 09:27`，仍需人工核对。
4. **比例 / 分辨率**：整屏 16:10（如 2560×1600）；bar 特写超宽（2560×40，或先 1600×64 再裁顶条）。
5. **保住"活气"**：那五个同时发生的瞬间（hover 行的界引、悬停模块的天青底染、未读押角的湿印泥、标题字距的呼吸、终端半行命令的光标）是画面唯一的生命来源，删任何一个都会退回死截图——它们是设计系统"贴面级反馈"的视觉证据。
6. **核对朱砂唯一**：出图后目视或像素采样确认 `#c8452c` 只落在 active 印章那一格；模型常忍不住在别处加红，必要时在负面提示词里再压一次。
7. **不对称勿纠偏**：模型本能地把东西摆居中、摆对称、摆成等大卡片网格——本设计的留白是故意偏心的，若它"修正"了对称，就在主提示词的 ASYMMETRICALLY 段后再补一句 `the empty ink in the bar center and the off-center panels are intentional, do not balance them`。

## 修正提示词（第二轮 · 针对《墨色书房桌面_4K》的七处偏差）

第一轮的整屏稿（`墨色书房桌面_4K.png`）章法、深度、落款、印章族、朱砂唯一（组件层）均已立住，但有七处偏差。重出图时把下面这段**原样追加到主提示词末尾**，并把负面词条并入负面提示词。

偏差清单：① 壁纸静物是锐利摄影级（笔筒/毛笔/手卷/册页全清晰），违反"糊到只剩色晕"；② 壁纸手卷里有一枚红色小印章，成了全屏第二处红；③ 朱砂印画成了偏粉的三文鱼红（实测 `(178,82,64)`，应为 `#c8452c`）；④ 右端结构错——状态簇被装进墨盒、控制图标自带方框、「·」只画了一个、电池百分比用了衬线；⑤ 落款缺内部间隔号（应为「戌時 · 19:48」）；⑥ 弹层 hover 行除了界引还给了整行浅底 + 全框，违反"只亮界引、零位移"；⑦ 五个心跳少了一个——bar 状态模块悬停的天青底染没画。

```text
CORRECTIONS from the previous render — hold these hard:
1. WALLPAPER BLUR: the wallpaper is UNIFORMLY and heavily compositor-blurred from edge to edge — NO sharp objects anywhere: no brush pot, no brushes, no handscroll, no books, no paper with legible strokes. Only misted mountain haze remains; if any object edge is crisp, the blur has failed. The wallpaper is a painting glimpsed through silk, never a photograph of a desk.
2. NO RED INSIDE THE PAINTING: cinnabar #c8452c appears ONLY in the active workspace chop. Any scroll or seal depicted inside the wallpaper carries NO red seal paste — stamp marks are faded ink-grey or omitted entirely.
3. EXACT CINNABAR: the active chop is deep seal-paste cinnabar #c8452c — not salmon, not brick, not coral, not pinkish; its glyph is bold off-white.
4. RIGHT-END ORDER: the darker ink-box corrals ONLY two or three small foreign third-party tray glyphs, their colors tamed by the box; the status cluster (wifi, battery + small %, update glyph with ochre dot, control glyph) sits OUTSIDE the box as bare grey-green line icons with NO frames of their own; exactly TWO faint middle-dots, placed as: [ink-box] · [status cluster] · [clock colophon + bell]. The battery % uses the same small technical monospace as the terminals, never serif.
5. CLOCK FORMAT: the colophon reads 戌時 · 19:48 — shichen name, a middle dot, then the digits, one Song-serif string with wide letter-spacing.
6. HOVER RESTRAINT: the popup's hovered row shows ONLY its 2px celadon left boundary-lead lighting up — NO row background fill, NO full rectangle outline; every other row keeps an identical transparent 2px lead so nothing shifts.
7. FIVE HEARTBEATS, ALL PRESENT: do not drop the bar hover — one status icon's seat in the bar is faintly washed celadon.
```

负面提示词追加：

```text
sharp photographic wallpaper, crisp desk still-life, brush pot, legible calligraphy on wallpaper objects, red seal stamps inside the painting, salmon red, coral red, pinkish red, extra framed boxes around status icons, hover row background fill, hover row full outline, serif digits in the status cluster
```
