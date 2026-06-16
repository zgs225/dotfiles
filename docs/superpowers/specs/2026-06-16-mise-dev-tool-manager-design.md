# Mise Dev Tool Manager Design

**Date:** 2026-06-16
**Status:** Draft

## Overview

Adopt [mise](https://mise.jdx.dev/) (formerly rtx) as the dev tool version manager for the dotfiles, replacing the ad-hoc tool installs. Mise manages python, node, rust, golang, lua, and luarocks via a chezmoi-managed config so tool versions stay in sync across machines.

## Context

- **Tool manager:** mise (already pre-installed on target systems; no bootstrap step in this spec)
- **Platforms:** macOS + Linux
- **dotfiles manager:** chezmoi
- **Shell:** zsh (with `p10k` instant prompt; configs auto-sourced from `~/.zsh/configs/*.zsh`)

### Current state

- No existing mise / rtx / asdf / `.tool-versions` config
- `dot_zshenv` ends with `. "$HOME/.cargo/env"` — rustup's shim, which puts `~/.cargo/bin` on PATH
- `dot_zsh/configs/50-nvm.zsh` and `60-pyenv.zsh` exist for nvm and pyenv (kept; mise can co-exist or supersede per tool)
- `dot_zsh/configs/45-go.zsh` handles go via system install or gvm (superseded by mise)

### Non-goals

- Bootstrapping mise itself (handled out-of-band; the spec assumes mise is already on `PATH`)
- Migrating existing projects to use `mise.toml` per-project (only the global default config is in scope)
- Removing nvm / pyenv / gvm configs (kept for backward compat; mise takes precedence via PATH order)
- Migrating cargo-installed binaries from `~/.cargo/bin` to mise (address only if a concrete need arises)

## Tools and Versions

| Tool    | Version spec         | Rationale                                          |
|---------|----------------------|----------------------------------------------------|
| python  | `3.13`               | Pinned minor — latest stable, current dev default  |
| node    | `22`                 | Pinned minor — current Node.js LTS                 |
| rust    | `latest`             | Always track stable (rust release cadence is fast) |
| golang  | `latest`             | Always track stable (go release cadence is fast)   |
| lua     | `5.1`                | Neovim 0.10 lua/luarocks ecosystem                  |
| luarocks| `latest`             | Tracks lua 5.1 (matched automatically by mise)     |

## File Structure

```
dot_config/
└── mise/
    ├── config.toml              # base config (shared env, settings — currently empty/minimal)
    └── conf.d/
        ├── python.toml          # python = "3.13"
        ├── node.toml            # node = "22"
        ├── rust.toml            # rust = "latest"
        ├── go.toml              # go = "latest"
        ├── lua.toml             # lua = "5.1"
        └── luarocks.toml        # luarocks = "latest"

dot_zsh/
└── configs/
    └── 97-mise.zsh              # mise activate zsh hook
```

### Existing files to update

| File           | Change                                                      |
|----------------|-------------------------------------------------------------|
| `dot_zshenv`   | Remove the trailing `. "$HOME/.cargo/env"` line             |

`dot_zshrc` is **not** modified — the existing `for config in ~/.zsh/configs/*.zsh(N)` loop auto-sources any new file dropped into `~/.zsh/configs/`.

## Component Design

### 1. `dot_config/mise/config.toml` (base)

Empty or contains only shared settings (e.g. `[env]` block if needed later). Per mise convention, `config.toml` is the base config and `conf.d/*.toml` files are merged on top.

### 2. `dot_config/mise/conf.d/*.toml` (per-tool)

Each file contains a single `[tools]` block with one entry, following mise's split config convention. Example `python.toml`:

```toml
[tools]
python = "3.13"
```

This makes adding/removing/re-pinning a single tool a one-file change.

### 3. `dot_zsh/configs/97-mise.zsh`

```zsh
# mise: dev tool version manager (rust, go, node, python, lua, luarocks)
if command -v mise &>/dev/null; then
  eval "$(mise activate zsh)"
fi
```

**Position `97`** — late in the load order, after legacy tool configs (`45-go`, `50-nvm`, `60-pyenv`, `70-uv`) and before final `99-completion.zsh`. This lets mise's shim path be added after the legacy tool paths so mise takes precedence on PATH.

**`command -v mise` guard** — mirrors the pattern in `60-pyenv.zsh`. If mise isn't installed or isn't on PATH yet (e.g. fresh machine before bootstrap completes), the file is a no-op rather than erroring.

**`eval "$(mise activate zsh)"` form** — mise docs canonical pattern. The activate command emits shell hooks (chpwd, preexec) that need to be eval'd; the eval runs them in the current shell.

### 4. `dot_zshenv` (cargo/env removal)

Remove the final line `. "$HOME/.cargo/env"`. The rest of the file (PATH-warn-on-edit block, `local _old_path` guard) stays untouched.

**Rationale:** rustup's `.cargo/env` adds `~/.cargo/bin` to PATH. Once mise owns the rust toolchain, mise's shims (registered via `97-mise.zsh`) provide `cargo` / `rustc` / `rustup` on PATH automatically, so the rustup shim is redundant and can be removed.

## chezmoi Template Strategy

- **No `.tmpl` suffix** on the new mise config files — the contents are static (no per-machine substitution needed). The TOML values are deliberately portable.
- **`config.toml`** and **`conf.d/*.toml`** are managed as plain files. chezmoi will symlink/copy them to `~/.config/mise/`.
- **`97-mise.zsh`** is a plain file under `dot_zsh/configs/`, picked up by the existing zshrc sourcing loop.

## Verification

Manual checks after `chezmoi apply` and a fresh interactive shell:

1. `mise --version` — mise itself on PATH
2. `mise ls` — all six tools listed with their resolved versions
3. `which python node cargo rustc go lua luarocks` — each resolves to a mise shim
4. `python --version` → `Python 3.13.x`
5. `node --version` → `v22.x.x`
6. `rustc --version` → `rustc 1.xx.x (...)`
7. `go version` → `go1.xx.x`
8. `lua -v` → `Lua 5.1.x`
9. `luarocks --version` → installed and reports a version
10. `echo $PATH | tr ':' '\n' | grep mise` — mise shims dir present in interactive shell PATH
11. `zsh -c 'echo $PATH'` (non-interactive) — mise shims dir **absent** (mise activate only runs interactively, which is correct — scripts should use system or explicit tools)
12. `grep -q 'cargo/env' ~/.zshenv && echo FAIL || echo OK` — cargo/env line is gone

## Out of Scope / Future Work

- **Per-project `mise.toml`** — projects can opt-in to their own pinned versions by adding a `mise.toml`; not part of this spec
- **Cargo-installed binaries** — anything in `~/.cargo/bin` from prior `cargo install` calls will lose PATH access. Reinstall via `mise use cargo:<name>` or move to a different location if a concrete need arises
- **Removing nvm/pyenv/gvm legacy configs** — they remain in `dot_zsh/configs/` but are shadowed by mise on PATH. Can be deleted in a follow-up once the user confirms no project depends on them
