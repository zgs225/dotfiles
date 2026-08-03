# Bitwarden tray 问题记录(X11/i3 环境)

> 本文自包含:症状、根因、已生效的 workaround、未采纳方案与调试手法一次讲清。
> 环境:EndeavourOS + i3 + X11,eww bar(SNI tray host),Bitwarden 2026.3.1(Arch,Electron 39),keyd + keyd-application-mapper。

---

## 1. 症状

1. **Alt+w($mod+w)关闭 Bitwarden 时整个应用退出**,即使设置了 close-to-tray。
2. **tray 菜单点 Show/Hide 无法唤回窗口**:窗口收进托盘后,点 tray 的 "Show / Hide" 无任何效果,只能重启 Bitwarden 恢复。

## 2. 根因

### 2.1 Alt+w 退出应用(keyd 全局映射,已修)

`/etc/keyd/default.conf`(eos-bootstrap 管理)的全局 `[alt]` 层把 `w = C-w`。
Bitwarden(Electron)收到 **Ctrl+W** 走菜单加速器路径,直接退出应用,
**不经过** close-to-tray 拦截——后者只拦截 `WM_DELETE_WINDOW`(WM 层关闭)。

对照实验证实:`WM_DELETE_WINDOW` → 窗口隐藏进托盘、进程存活;`Ctrl+W` → 进程退出。

**修复**(本仓库 `dot_config/keyd/app.conf`):

```ini
[bitwarden]
alt.w = command(xclose-active-window)
```

`xclose-active-window` 由 eos-bootstrap 部署到 `/usr/local/bin`(不在本仓库):
运行时通过 `loginctl` 发现 seat0 活跃 X11 会话的 DISPLAY/XAUTHORITY(keyd 守护进程
是 root 系统服务、无 X 环境,不能硬编码),再 `xdotool getactivewindow windowclose`
发送真正的 WM 关闭。

⚠️ keyd 语法坑:`command()` 是**顶层 action**,不能嵌套进 `macro()`。
`macro()` 里的未知 token 会被当作 unicode 字符组**原样敲进焦点窗口**
(曾因此把绑定文本打进窗口)。

另外 `dot_config/i3/scripts/executable_quit-app.sh`($mod+q)对 Bitwarden 豁免了
"进程存活但无可见窗口 → SIGTERM" 的升级逻辑,否则 Cmd+Q 风格退出也会误杀托盘实例。

### 2.2 tray Show/Hide 唤不回(Electron/Chromium X11 上游 bug,未修)

用 D-Bus 精确复现 tray 点击(eww 是 SNI host;Bitwarden 以唯一连接名注册
`org.kde.StatusNotifierItem`,menu 在 `/com/canonical/dbusmenu`,
对 "Show / Hide" 项发 `Event(id,'clicked',...)`),结合 root 窗口 X 事件监控
(python-xlib,SubstructureNotify)与 `--enable-logging=stderr` 主进程日志,因果链:

1. **hide 方向**:close-to-tray 调 `BrowserWindow.hide()`。Chromium 在 X11 上 hide 时
   **直接销毁顶层 X 窗口**;同时 GPU 进程在 unmapped 窗口上 `eglSwapBuffers` 失败
   (`Failed to retrieve the size of the parent window`)并崩溃重启。
2. **show 方向**:tray 菜单走 `toggleWindow()` → `BrowserWindow.show()`,但 native
   窗口对象持有**已死 XID**,日志连续报
   `DeletePropertyRequest / UnmapWindowRequest BadWindow, bad_value=<窗口ID>`;
   X 层**从无 MapRequest/MapNotify** 发往 i3 → 窗口永远无法重新映射。
3. 结论:上游 bug(hide 销毁 X 窗口、show 无法重建),与本机 WM/键位配置无关。
   第一次 hide 正常,之后 show 必坏。

## 3. 未采纳的 workaround(仅供参考)

思路:不让 Electron 碰 hide/show,把可见性委托给 i3 scratchpad(窗口始终由 WM 管理):
patch `app.asar` 的 `main.js`,将 `win.hide()` / `windowMain.show()` 等调用点替换为
`child_process`(webpack 模块 id 35317)`exec` 一个 toggle 脚本
(`i3-msg '[class="Bitwarden"] move scratchpad' / 'scratchpad show'` 二选一),
并配 pacman hook 在升级后自动重补丁。

曾实现并实测到 asar 重打包环节,因**超出"只排查原因"的范围被用户撤销**。
草稿曾暂存于 `/tmp/bitwarden-workaround/`(tmp,可能已清空)。若日后启用,注意:

- asar preamble 是 Chromium pickle:`[4][u1][u2=4+ceil4(jsonlen)][u3=jsonlen]`,
  **数据段起点 = 8 + u1**(不是 16+header)。
- 重打包必须重算 main.js 的 `integrity`(SHA256 + 4MiB blocks)与所有后续文件 offset。
- `__webpack_require__` 在 tray_main 模块作用域内可用。

## 4. 调试手法备忘

```bash
# tray 菜单程序化点击(SNI dbusmenu)
busctl --user list                      # 找 Bitwarden 的唯一连接名 :1.xxx
# GetLayout 找 "Show / Hide" 的 id,再 Event(id,'clicked','',0)
# (python-gi Gio.bus_get_sync + call_sync;注意 RegisteredStatusNotifierItems
#  在 org.kde.StatusNotifierWatcher 接口下,eww 未实现 org.freedesktop 变体)

# X 层事件监控(python-xlib root.change_attributes(SubstructureNotifyMask))
# 注意:只能看到 root 直接子窗口的事件;i3 frame 的 Unmap/Destroy 可间接观察 client 撤管

# Electron 主进程日志
ELECTRON_ENABLE_LOGGING=1 bitwarden-desktop --enable-logging=stderr

# 坑:pgrep -f / pkill -f 的模式会匹配到执行命令的 shell 自身 cmdline,
# 用 'app[.]asar' 字符类或先取 PID 再 kill
```
