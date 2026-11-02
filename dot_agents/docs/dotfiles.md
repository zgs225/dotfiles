# Dotfiles — chezmoi

Source: `~/.local/share/chezmoi` (git repo, remote: `zgs225/dotfiles`)

## Rules

- **Never edit `~/.` files directly** — always use chezmoi.
- **Never modify OS-level config** (`/etc/`, systemd units, polkit) — that's eos-bootstrap.
- Desktop UI changes MUST follow `docs/design/song-liquid-glass.md` (绢纱琉璃·宋式极简).
- Before modifying eww/i3 components, read `.agents/skills/` skill files first.

> 路径基准：本文件中 `docs/...` 与 `.agents/...` 引用均为 **chezmoi 仓库根**（`~/.local/share/chezmoi/`）下的相对路径，并非本目录（`~/.agents/docs/`）。

## Conventions

| Prefix / Suffix | Meaning |
|-----------------|---------|
| `dot_` | Becomes `.` in `$HOME` (e.g. `dot_zshrc` → `~/.zshrc`) |
| `dot_config/` | Maps to `~/.config/` |
| `.tmpl` | Go template; vars from `.chezmoi.yaml.tmpl` data block |
| `encrypted_*.age` | age-encrypted; key at `~/.config/chezmoi/key.txt` |
| `private_dot_ssh/` | `~/.ssh/` with `0700` perms |

Lifecycle scripts live in `.chezmoiscripts/` (never repo root):
- `common/` — runs on every OS
- `linux/`, `darwin/`, `windows/` — gated by `.chezmoiignore`

## Key Managed Paths

```
~/.zshrc, ~/.zshenv, ~/.zprofile    Shell entry (zsh + Antigen)
~/.zsh/configs/*.zsh                 Numbered config files (loaded in order)
~/.config/mise/config.toml           mise tool versions (NOT in eos-bootstrap)
~/.config/nvim/                      Neovim (NvChad v2.5 + lazy.nvim)
~/.config/wezterm/                   WezTerm terminal
~/.config/i3/                        i3wm config
~/.config/eww/                       eww widgets
~/.config/picom/                     Compositor
~/.config/rofi/                      Launcher
~/.config/dunst/                     Notifications
~/.config/keyd/app.conf              Per-app key remapping
~/.tmux.conf                         Tmux (prefix Ctrl+s, gpakosz base)
~/.gitconfig                         Git config (template)
~/.ssh/                              SSH keys and config
~/.kube/                             Kubernetes kubeconfig
```

## Commands

```bash
chezmoi update --init       # git pull + apply + regenerate chezmoi.toml (preferred)
chezmoi diff                # preview pending changes
chezmoi apply               # apply without pulling
chezmoi add <file>          # track a new file
chezmoi add --encrypt <f>   # track encrypted
chezmoi edit <target>       # edit source file
chezmoi managed | grep X    # find managed files
```

## Per-machine Customization

- `~/.config/chezmoi/chezmoi.yaml` — machine-specific template data
- `~/.zsh/configs/96-*.zsh` — local shell overrides (numbered, loaded last)
- `~/.gitconfig.local` — git user overrides
- `~/.aliases.local` — local aliases
- `~/.zshrc.local` — encrypted local zsh config (age)

## Gotchas

- `chezmoi update` alone does NOT regenerate `chezmoi.toml` — use `--init`.
- Encryption requires age key pre-placed at `~/.config/chezmoi/key.txt`.
- mise tool versions live here (dotfiles), not in eos-bootstrap.
- i3 `$mod = Alt`; keyd remaps Alt+c/v/x/a → Ctrl equivalents; check `~/.config/keyd/app.log` for WM_CLASS whitelisting.
