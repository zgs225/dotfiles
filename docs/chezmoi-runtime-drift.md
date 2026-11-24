# 运行时漂移清单（chezmoi）

有些文件**由应用自己在运行时改写**，不是人编辑的。`chezmoi status` 里看到它们漂移时，先对照本表，不要当事故处理。

判定与处置原则：

- live 是"事实"（应用已注册/已生效）→ `chezmoi re-add`，让源等于事实；应用再写同样内容是幂等的，漂移不再复发。
- live 是"垃圾"（临时值、无意义噪音）→ `chezmoi apply` 覆盖回去；但若写方会立刻重写，就别白折腾。
- **不要**为了消漂移把整文件移出托管——会丢掉这份配置的版本管理。

## 已登记

| 文件 | 写入方 | 写入内容 | 复发 | 策略 |
|---|---|---|---|---|
| `~/.config/mimeapps.list` | `xdg-mime`（手动）、百度网盘（Electron）、clash-verge（Tauri） | `baidunetdisk` 的 `x-scheme-handler/baiduyunguanjia`；clash-verge 在 `[Added Associations]` 另写一份 `x-scheme-handler/clash{,-verge}` | 每次这两个 app 启动（幂等，re-add 后不再漂） | re-add |
| `~/.pi/agent/settings.json` | pi 自身 | `lastChangelogVersion`（已看过的 changelog 版本） | 每次 pi 升级 | re-add，接受周期性一行漂移 |
| `~/.pi/agent/mcp.json` | pi 的 `/mcp` 面板 | 在面板里改 exposure 或启用/禁用 server 时回写该条目 | 仅在面板里改设置时 | re-add；想保留仓库里的写法就别在面板里改这两项 |
| `~/.config/gtk-3.0/bookmarks` | Thunar 侧栏（Add Bookmark / 拖拽 / rename / remove-bookmark）、GTK 文件对话框（Ctrl+B）、XDG portal 文件框 | XDG 书签行 `file:///path`（可选 `\t名称`），行序即侧栏顺序 | 每次在 Thunar 侧栏或任何 GTK 文件对话框里增删/改书签 | re-add（应用写的即"事实"）；想让仓库做权威就改源文件后 `chezmoi apply` |
| `~/.config/user-dirs.dirs` + `user-dirs.locale` | `xdg-user-dirs-update`（登录时 systemd user unit `xdg-user-dirs.service`，挂在 `graphical-session-pre.target`） | `XDG_*_DIR="$HOME/..."`；仍有默认值的条目会按当前 locale 重新翻译 | 仅当 `user-dirs.locale` 与当前 LANG 不一致时 | re-add；注意本仓库把 Desktop/Music/Templates/Public/Projects 有意设为 `$HOME`（=禁用，GLib 返回 `$HOME`、GTK/Thunar 不展示），不要当错误改回默认路径 |

## 指纹速查

```bash
# app 注册 scheme 时会同批改动这几个文件（mtime 同分钟即可判定）
ls -la ~/.local/share/applications/{mimeinfo.cache,mimeapps.list,*handler.desktop}
stat -c '%y %n' ~/.config/mimeapps.list
```

- `~/.local/share/applications/mimeapps.list` 恒为 0 字节，实际生效的是 `~/.config/mimeapps.list`。
- 源文件里 clash 两行在 `[Default Applications]`（手工维护）；live 里 `[Added Associations]` 的两行是 app 写的，两份并存不冲突。
- `bookmarks` 里的 Downloads/Documents/Pictures/Videos **故意与 XDG 标准目录重合**，不是重复配置：Thunar 4.20 的侧栏（`thunar-shortcuts-model.c: thunar_shortcuts_model_shortcut_places`）只放 Home/Desktop/书签/Trash/Computer/Recent，**从不显示 XDG 用户目录**；而 GTK 文件框（Chrome 的 portal、钉钉的进程内 GTK）用 `GtkPlacesSidebar`，它把 XDG 目录当 place 显示、并对指向同一路径的书签去重（`gtkplacessidebar.c` 里 `_gtk_bookmarks_manager_get_is_builtin()` 为真的书签直接 `continue`）。两边合起来才既不丢条目也不出现双份。

## 待观察

- X / 输入法 / 桌面工具偶发写入的用户级状态文件，确认后补表。
