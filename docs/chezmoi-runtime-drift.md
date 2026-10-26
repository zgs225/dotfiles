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

## 指纹速查

```bash
# app 注册 scheme 时会同批改动这几个文件（mtime 同分钟即可判定）
ls -la ~/.local/share/applications/{mimeinfo.cache,mimeapps.list,*handler.desktop}
stat -c '%y %n' ~/.config/mimeapps.list
```

- `~/.local/share/applications/mimeapps.list` 恒为 0 字节，实际生效的是 `~/.config/mimeapps.list`。
- 源文件里 clash 两行在 `[Default Applications]`（手工维护）；live 里 `[Added Associations]` 的两行是 app 写的，两份并存不冲突。

## 待观察

- X / 输入法 / 桌面工具偶发写入的用户级状态文件，确认后补表。
