# herdr 插件管理

herdr（terminal workspace manager for AI coding agents）的配置与插件的 chezmoi 边界说明。
搭建：2026-10。

## 边界划分

| 内容 | 路径 | 归谁管 |
|------|------|--------|
| 主配置 | `~/.config/herdr/config.toml` | **chezmoi**（`dot_config/herdr/config.toml`） |
| 插件声明 | 本仓库 `.chezmoiscripts/linux/run_onchange_after_herdr-plugins.sh` | **chezmoi**（声明式，见下） |
| 插件安装记录 | `~/.config/herdr/plugins.json` | 不管 —— herdr CLI 自写，含机器绝对路径 |
| 插件 checkout | `~/.config/herdr/plugins/github-installations/**` | 不管 —— 约 143 MB 的 git checkout + build 产物 |
| 运行状态 | `~/.config/herdr/*.sock`、`*.log`、`session*.json`、`sessions/`、`session-snapshots/`、`.plugins.lock` | 不管 —— 运行时状态 |
| 其他状态 | `~/.local/state/herdr/**` | 不管 |

「不管」的意思是：这些路径**不在 chezmoi source 里**，因此 `chezmoi apply` 不会创建也不会覆盖它们
（chezmoi 只管理 source 中存在的文件，无需额外 `.chezmoiignore`）。唯一要避免的动作是
`chezmoi add ~/.config/herdr/plugins.json` 或对 `~/.config/herdr` 整体 `chezmoi re-add`。

## 插件声明式安装

插件清单写在 `.chezmoiscripts/linux/run_onchange_after_herdr-plugins.sh` 的 `PLUGINS` 变量里：

```
<plugin_id>:<OWNER/REPO[/SUBDIR]>:<ref>
```

- 脚本是 `run_onchange_after_*`：内容一变，`chezmoi apply` 后自动执行一次。
- 幂等：先 `herdr plugin list --json` 判断 `"plugin_id"` 是否已存在，已装则跳过；
  未装才 `herdr plugin install OWNER/REPO[/SUBDIR] --ref REF -y`。
- 单个插件安装失败不中断其余插件，但脚本最终以非零码退出（chezmoi 会报错提示）。
- 当前只有 heeler（`ZingerLittleBee/Heeler/plugin`），ref pin 在安装时解析出的 commit
  `3e6d3269c0ef2146087e655faf43a06cfcdd198d`（而非 `main`），保证可复现、不受上游漂移影响。

**增加插件**：在 `PLUGINS` 里加一行 → `chezmoi apply` → 脚本自动安装。
**删除插件**：`herdr plugin uninstall <id>`，并从 `PLUGINS` 里删掉该行（chezmoi 不做卸载，避免误删）。
**升级插件**：改 `PLUGINS` 里的 ref 并 `chezmoi apply`，或 `herdr plugin update <id>` 后再同步 ref 到新解析出的 commit。

注意 herdr 的插件来源语法是 `owner/repo/subdir`（无 `github:` 前缀）；
heeler 的 manifest 在仓库的 `plugin/` 子目录，且构建需要 node >= 20（`npm ci`）。

## 常用命令

```bash
herdr config check              # 校验 config.toml
herdr server reload-config      # 让运行中的 server 重新读取 config.toml
herdr plugin list --json        # 已装插件（脚本判断依据）
herdr plugin install ZingerLittleBee/Heeler/plugin --ref main -y   # 手动重装示例
herdr plugin uninstall heeler
```
