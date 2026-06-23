# AGENTS.md

chezmoi-based dotfiles repo. Do not edit `~/.` files directly — use chezmoi.

## Rules

- **Never modify OS-level configuration.** Do not edit files under `/etc/`, `/usr/`, `/boot/`, systemd units, polkit rules, or any other system-wide config. This repo only manages user-level dotfiles.
- **Never edit deployed files directly.** Always edit the source files in this repo (`dot_*`, `.tmpl`, etc.) and apply via chezmoi. For example, do not edit `~/.zshrc` or `~/.config/nvim/init.lua` directly; edit `dot_zshrc` or `dot_config/nvim/init.lua` here instead.

## Chezmoi conventions

- `dot_` prefix → becomes `.` in `$HOME` on apply. `dot_config/` → `~/.config/`.
- `.tmpl` extension → Go template; variables come from `.chezmoi.yaml.tmpl` data block.
- `run_before_*`, `run_after_*`, `run_once_after_*`, `run_onchange_after_*` are chezmoi lifecycle scripts — not standalone.
- Apply: `chezmoi init --source ~/dotfiles --apply` or `chezmoi update`
- **Never run `chezmoi apply`.** The working directory is NOT the chezmoi source path. Editing source files in this repo is correct; applying them to `$HOME` is done separately by the user.
- Encryption: age via chezmoi. Key: `~/.config/chezmoi/key.txt`. Receiver in `.chezmoi.yaml.tmpl`.

## OS targeting

- Linux + i3 only: `dot_config/i3/`, `dot_config/polybar/`, `dot_config/picom/`, `dot_config/rofi/`, `dot_config/dunst/`, `dot_xinitrc`, `dot_xprofile` — guarded in `.chezmoiignore`
- macOS: `dot_zsh/configs/40-homebrew.zsh`
- Per-machine overrides: `~/.config/chezmoi/chezmoi.yaml`, `~/.zsh/configs/` (numbered .zsh files), `~/.gitconfig.local`, `~/.aliases.local`

## Key toolchain

- **Shell**: zsh with Antigen plugin manager; `dot_zshrc` sources `~/.zsh/configs/*.zsh` in numeric order
- **Version manager**: mise (`~/.config/mise/config.toml` + `conf.d/*.toml`)
- **Editor**: Neovim (NvChad v2.5 + lazy.nvim). Config: `dot_config/nvim/`
- **Terminal**: WezTerm (`dot_config/wezterm/`)
- **Tmux**: prefix `Ctrl+s`, based on gpakosz/.tmux; local overrides in `~/.tmux.conf.local`

## Git aliases (from `dot_gitconfig.tmpl`)

- `git create-branch <name>`, `git delete-branch <name>`, `git merge-branch`
- `git up` = fetch + rebase origin/master

## OpenCode config

- TUI config at `dot_config/opencode/tui.json`; encrypted settings at `dot_config/opencode/encrypted_opencode.json.age`
- Leader key: `ctrl+g`
