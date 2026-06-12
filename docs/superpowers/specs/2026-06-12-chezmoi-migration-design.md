# Chezmoi 迁移设计

> 将 dotfiles 仓库从 rcm 迁移到 chezmoi，实现全平台差异化配置、模板化管理、秘密加密。

## 上下文

当前使用 [rcm](https://github.com/thoughtbot/rcm) 管理 dotfiles，采用 thoughtbot 风格。迁移动机：

- 跨平台支持（macOS / Linux / Windows WSL）
- 模板化配置生成（gitconfig、ssh config 等）
- 敏感信息加密管理（SSH 私钥、API tokens）
- 替换维护不活跃的 rcm

## 目标环境

- macOS（主力开发机）
- Linux（服务器）
- Windows（WSL）

## 目录结构

```
~/dotfiles/                          # chezmoi source dir (git repo)
├── .chezmoi.yaml.tmpl               # 全局模板数据定义
├── .chezmoiignore                   # 忽略规则
├── .chezmoiremove                   # 清理旧 rcm symlink
├── dot_zshenv                       # → ~/.zshenv
├── dot_zshrc                        # → ~/.zshrc
├── dot_zshrc.local                  # → ~/.zshrc.local
├── dot_zsh/                         # → ~/.zsh/
│   ├── functions/
│   ├── completions/
│   └── configs/
│       ├── 00-xdg.zsh
│       ├── 05-options.zsh
│       ├── 10-color.zsh
│       ├── 15-completion.zsh
│       ├── 20-history.zsh
│       ├── 25-keybindings.zsh
│       ├── 30-fzf.zsh
│       ├── 35-antigen.zsh
│       ├── 40-homebrew.zsh           # {{ if .isMacOS }}
│       ├── 45-go.zsh
│       ├── 50-nvm.zsh
│       ├── 55-rbenv.zsh
│       ├── 60-pyenv.zsh
│       ├── 65-java.zsh
│       ├── 70-uv.zsh
│       ├── 75-editor.zsh
│       ├── 80-yarn.zsh
│       ├── 85-bat.zsh
│       ├── 90-p10k.zsh
│       └── 95-windsurf.zsh
│
├── dot_gitconfig.tmpl               # → ~/.gitconfig (模板化)
├── dot_gitignore                    # → ~/.gitignore
├── dot_gitmessage                   # → ~/.gitmessage
├── dot_git_template/                # → ~/.git_template/
│   ├── literal_HEAD                 #    literal copy (非 symlink)
│   └── hooks/
│
├── dot_tmux.conf                    # → ~/.tmux.conf
├── dot_tmux.conf.local              # → ~/.tmux.conf.local
├── dot_gemrc                        # → ~/.gemrc
├── dot_rspec                        # → ~/.rspec
├── dot_psqlrc                       # → ~/.psqlrc
├── dot_myclirc                      # → ~/.myclirc
├── dot_hushlogin                    # → ~/.hushlogin
├── dot_aliases                      # → ~/.aliases
│
├── private_dot_ssh/
│   ├── config.tmpl                  # → ~/.ssh/config (模板)
│   ├── encrypted_id_ed25519.age     # → ~/.ssh/id_ed25519 (age 加密)
│   └── id_ed25519.pub               # → ~/.ssh/id_ed25519.pub (明文)
│
├── dot_config/
│   ├── nvim/                        # → ~/.config/nvim/
│   ├── wezterm/                     # → ~/.config/wezterm/
│   ├── opencode/                    # → ~/.config/opencode/
│   └── pgcli/                       # → ~/.config/pgcli/
│
├── dot_bin/                         # → ~/.bin/
│   ├── executable_tat
│   ├── executable_git-co-pr
│   ├── executable_git-up
│   └── ...
│
├── run_before_install.sh            # pre-install 钩子
├── run_after_install.sh             # 替代原 hooks/post-up
└── run_onchange_after_p10k.sh       # p10k 配置变化时重新加载
```

### rcm → chezmoi 概念映射

| rcm 概念 | chezmoi 等效 |
|----------|-------------|
| `rcrc EXCLUDES` | `.chezmoiignore` |
| `rcrc COPY_ALWAYS` | `literal_` 前缀 |
| `rcrc DOTFILES_DIRS` | `chezmoi data` 模板变量 |
| `hooks/post-up` | `run_before_install.sh` + `run_after_install.sh` |
| `~/dotfiles-local` 分层 | chezmoi 模板条件 |

## 数据模型

### 全局模板数据 (`.chezmoi.yaml.tmpl`)

```yaml
sourceDir: {{ .chezmoi.sourceDir | quote }}

{{- if eq .chezmoi.os "darwin" }}
isMacOS: true
{{- else if eq .chezmoi.os "linux" }}
isLinux: true
{{- else if eq .chezmoi.os "windows" }}
isWindows: true
{{- end }}

user:
  name: "yuez"
  email: "i@yuez.me"

defaultEditor: "nvim"
```

身份信息固定，不做 hostname 分叉；zsh configs 全量加载。平台差异仅通过 `isMacOS` / `isLinux` / `isWindows` 模板变量处理。

### gitconfig 模板 (dot_gitconfig.tmpl)

```ini
[user]
  name  = {{ .user.name }}
  email = {{ .user.email }}

[core]
  editor = {{ .defaultEditor }}
{{- if .isMacOS }}
  autocrlf = input
{{- end }}

[init]
  defaultBranch = main
  templatedir = ~/.git_template
# ... 其余静态配置
```

### SSH config 模板 (private_dot_ssh/config.tmpl)

```
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519
```

## 秘密管理

使用 chezmoi age 加密：

| 秘密类型 | 方式 | 说明 |
|----------|------|------|
| SSH 私钥 | age 加密存储 | `private_dot_ssh/encrypted_id_ed25519.age` → `~/.ssh/id_ed25519` (0600) |
| SSH 公钥 | 明文 | `private_dot_ssh/id_ed25519.pub` |
| gitconfig 敏感项 | 模板变量 | 固定值无需加密 |

**age 密钥管理**：age 私钥不进入仓库，每台机器通过 `chezmoi init` 时提供（如 1Password CLI 注入或手动密钥交换）。

## 脚本 & 钩子

### `run_before_install.sh`

- 检查操作系统类型
- 检查依赖工具（zsh、nvim、tmux、git）是否安装
- 检查 age 加密工具可用性
- 不做自动安装，只做检查和提醒

### `run_after_install.sh`

- 继承原 `hooks/post-up` 逻辑：
  - `touch ~/.psqlrc.local`
  - 清理旧 `~/.git_template/HEAD`
  - 检测 `/etc/zshenv` 问题并提醒
- 不再包含 `install_package` 等自动安装逻辑

### `run_onchange_after_p10k.sh`

- p10k 配置文件变化时触发生成/刷新

## 迁移步骤

1. **准备**：`chezmoi init` 将当前仓库设为 source dir
2. **预览**：`chezmoi diff` 检查所有文件变更
3. **试运行**：`chezmoi apply --dry-run`
4. **执行**：`chezmoi apply` 执行正式迁移
5. **清理**：`.chezmoiremove` 自动移除旧 rcm symlink
6. **日常使用**：`chezmoi update` 替代 `rcup`

## 回退

所有变更均可通过 git revert 回退。chezmoi 不会删除被管理的文件。
