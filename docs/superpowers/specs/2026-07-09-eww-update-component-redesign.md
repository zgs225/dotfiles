# Eww 软件更新组件优化设计

**日期**: 2026-07-09

## 目标

优化 eww 软件更新指示器，解决三个问题：

1. 弹窗布局拥挤，难以看清哪些包需要更新。
2. 点击「检查更新」后没有任何反馈，无法知道检查是否开始。
3. 使用「打开更新终端」完成更新后，列表仍显示过期数据，需要等待下一次定时检查。

## 当前问题

- 现有布局使用左右分栏：左侧 Official / AUR 分组、右侧列表。列表区域被挤占，信息密度高。
- 包名和版本号在同一行但没有明显分隔，行高紧凑。
- 检查按钮没有加载状态，无法感知正在检查。
- `update-apply.sh` 只打开 `paru` 终端，更新完成后不会刷新缓存。

## 设计决策

### 1. 布局：合并列表 + 顶部筛选 + 按钮垂直

- 取消左侧分组栏，改为**合并列表**。
- 列表顶部放置 **chip** 切换：全部 / 官方 / AUR，默认「全部」。
- 每行左侧用徽标区分来源：
  - `O` → Official（pacman）
  - `A` → AUR（paru）
- 每行右侧显示 `旧版本 → 新版本`。
- 底部两个按钮改为**垂直排列**，每行一个按钮：
  - 检查更新（或检查中…）
  - 打开更新终端
- 弹窗宽度根据内容自适应：实现时把 `updateW` 减小约 20–40px，同时为列表行设置 `min-width` 与内容截断策略，避免过宽或过窄。
- 移除不再使用的 `updates_active_group` 变量。

### 2. 检查状态反馈

- 新增状态文件：`~/.cache/eww/updates.checking`。
- `check-updates.sh` 开始时创建该文件，结束时（或任何退出路径）删除。
- eww 通过 `defpoll` 每 500ms 轮询一次检查状态。
- 当检查中时，「检查更新」按钮文案变为「检查中…」，并进入禁用状态。
- 检查完成后，按钮恢复为「检查更新」。

### 3. 更新后自动刷新

- `update-apply.sh` 启动的终端命令改为：`paru; ~/.config/eww/scripts/check-updates.sh`。
- 用户完成更新、终端命令退出后，自动运行一次检查脚本，刷新 `updates.json`。
- 为让刷新更快反映到弹窗，将 `updates` 的 eww 轮询间隔从 30s 缩短到 **10s**。
- 若未安装 paru，回退到 `sudo pacman -Syu; check-updates.sh`。

## 数据与状态

### 缓存文件

- `~/.cache/eww/updates.json`：现有结构，包含 `last_check`、`total`、`official_count`、`aur_count`、`official`、`aur`、`error`。
- `~/.cache/eww/updates.checking`：临时状态文件，存在表示正在检查。

### eww 状态

- `updates_filter`：当前列表筛选，值 `all` | `official` | `aur`，默认 `all`。
- `updates_checking`：布尔，由 `update-checking-state.sh` 返回 `true` / `false` 字符串。eww 表达式直接按布尔使用。

### 新增/修改脚本

| 脚本 | 职责 |
|------|------|
| `check-updates.sh` | 抓取官方和 AUR 更新，写入 `updates.json`；管理 `updates.checking` 状态文件。 |
| `update-status.sh` | 读取并返回 `updates.json`。 |
| `update-list-yuck.sh` | 根据 `updates_filter` 渲染过滤后的列表，包含 O/A 徽标和版本箭头。 |
| `update-trigger.sh` | 启动 `update-check.service`（保持不变）。 |
| `update-apply.sh` | 打开终端运行 `paru` / `pacman -Syu`，退出后自动刷新缓存。 |
| `update-checking-state.sh` | 返回 `true` 或 `false`，基于 `updates.checking` 文件是否存在。 |

### 配置与样式

- `eww.yuck.tmpl`：
  - 新增 `defvar updates_filter "all"`。
  - 新增 `defpoll updates_checking`（500ms）。
  - 修改 `updates-popup` 窗口：顶部 chip、合并列表、底部垂直按钮。
  - 将 `updates` 的 `defpoll` 间隔从 30s 改为 10s。
- `eww.scss.tmpl`：
  - 新增 chip、来源徽标、列表行、垂直按钮的检查状态样式。
  - 调整 `updateW` 尺寸，让弹窗更紧凑。
- `.chezmoitemplates/eww-sizes`：
  - 因按钮改为垂直、列表不再受左右分栏挤压，适度减小 `updateW` 和 `updateH`。

## 流程

### 检查流程

```
用户点击「检查更新」
  → update-trigger.sh
  → systemctl --user start --no-block update-check.service
  → update-check.service 运行 check-updates.sh
    → 创建 updates.checking
    → 抓取官方和 AUR 更新
    → 写入 updates.json
    → 删除 updates.checking
  → eww 轮询到 updates_checking=false，按钮恢复
```

### 更新后刷新流程

```
用户点击「打开更新终端」
  → update-apply.sh
  → wezterm start -- bash -c "paru; ~/.config/eww/scripts/check-updates.sh"
  → 用户完成更新、终端命令退出
  → 自动运行 check-updates.sh
  → 刷新 updates.json
  → eww 在 10s 内反映到列表
```

## 错误处理

- `check-updates.sh` 使用 `trap ... EXIT` 确保 `updates.checking` 在脚本退出时删除，避免按钮卡死。
- 如果检查失败，将错误信息写入 `updates.json` 的 `error` 字段。
- eww 在弹窗顶部显示错误行（例如「检查失败：网络超时」），不影响其他功能。
- `update-check.service` 的 `TimeoutStartSec=180` 保证即使脚本异常，systemd 也会清理。

## 测试与验证

1. 运行 `chezmoi apply` 并重启 eww。
2. 打开 updates-popup，确认：
   - 列表显示合并后的包，带 O/A 徽标和版本箭头。
   - 顶部 chip 可以切换全部 / 官方 / AUR。
   - 底部两个按钮垂直排列。
3. 点击「检查更新」：
   - 按钮立即变为「检查中…」并禁用。
   - 服务完成后按钮恢复，列表数据刷新。
4. 点击「打开更新终端」：
   - 终端正常打开，paru 运行。
   - 退出后等待片刻，确认列表数据已刷新（10s 内）。
5. 模拟检查失败：
   - 手动让 `check-updates.sh` 报错，确认 `updates.checking` 被清理。
   - 确认弹窗显示错误信息。

## 相关文件

- `dot_config/eww/eww.yuck.tmpl`
- `dot_config/eww/eww.scss.tmpl`
- `.chezmoitemplates/eww-sizes`
- `dot_config/eww/scripts/executable_check-updates.sh`
- `dot_config/eww/scripts/executable_update-status.sh`
- `dot_config/eww/scripts/executable_update-list-yuck.sh`
- `dot_config/eww/scripts/executable_update-trigger.sh`
- `dot_config/eww/scripts/executable_update-apply.sh`
- `dot_config/eww/scripts/executable_update-checking-state.sh`（新增）
- `dot_config/systemd/user/update-check.service`
- `.gitignore`（已加入 `.superpowers/`）
