# Mise Dev Tool Manager Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `mise` as the dev tool version manager to the chezmoi dotfiles, installing python 3.13, node 22, rust (latest), golang (latest), lua 5.1, and luarocks, with shell integration via the existing `dot_zsh/configs/` auto-load mechanism.

**Architecture:** Static TOML config files under `dot_config/mise/` (one base + one per tool) symlinked by chezmoi. A single new zsh config file (`97-mise.zsh`) sources `mise activate zsh`, auto-loaded by the existing zshrc loop. The legacy `. "$HOME/.cargo/env"` source in `dot_zshenv` is removed since mise now owns the rust shims.

**Tech Stack:** mise (pre-installed), chezmoi, zsh, TOML.

---

## File Structure

| File | Type | Responsibility |
|------|------|----------------|
| `dot_config/mise/config.toml` | new | Base mise config (empty / shared settings) |
| `dot_config/mise/conf.d/python.toml` | new | `python = "3.13"` |
| `dot_config/mise/conf.d/node.toml` | new | `node = "22"` |
| `dot_config/mise/conf.d/rust.toml` | new | `rust = "latest"` |
| `dot_config/mise/conf.d/go.toml` | new | `go = "latest"` |
| `dot_config/mise/conf.d/lua.toml` | new | `lua = "5.1"` |
| `dot_config/mise/conf.d/luarocks.toml` | new | `luarocks = "latest"` |
| `dot_zsh/configs/97-mise.zsh` | new | `eval "$(mise activate zsh)"` hook |
| `dot_zshenv` | modify | Remove trailing `. "$HOME/.cargo/env"` line |

Each per-tool TOML contains a single `[tools]` block with one entry. This matches mise's `conf.d/` split convention so adding/removing/re-pinning a single tool is a one-file change.

---

## Task 1: Verify mise is installed and create the mise config directory

**Files:**
- Create: `dot_config/mise/.keep` (placeholder so the directory is tracked by git before any real files are added; will be removed in Task 2)

- [ ] **Step 1: Verify mise is installed and on PATH**

Run:
```bash
command -v mise && mise --version
```

Expected: a path to `mise` is printed (e.g. `/Users/yuez/.local/bin/mise`) and a version string like `2026.x.x`. If `command -v mise` fails, stop and ask the user to install mise before continuing.

- [ ] **Step 2: Create the mise config directories**

Run:
```bash
mkdir -p dot_config/mise/conf.d
```

Expected: no output. Verify with `ls -la dot_config/mise/` — should show `conf.d/` directory exists.

- [ ] **Step 3: Commit the directory scaffolding**

```bash
git add dot_config/mise/conf.d
git commit -m "chore(mise): create config directory scaffolding"
```

---

## Task 2: Write the mise base config and per-tool config files

**Files:**
- Create: `dot_config/mise/config.toml`
- Create: `dot_config/mise/conf.d/python.toml`
- Create: `dot_config/mise/conf.d/node.toml`
- Create: `dot_config/mise/conf.d/rust.toml`
- Create: `dot_config/mise/conf.d/go.toml`
- Create: `dot_config/mise/conf.d/lua.toml`
- Create: `dot_config/mise/conf.d/luarocks.toml`

- [ ] **Step 1: Write the base config file**

Create `dot_config/mise/config.toml` with the following contents:

```toml
# mise base config
# Per-tool versions live in conf.d/*.toml (mise merges these on top of this file).
```

The file is intentionally minimal — YAGNI. If shared env vars or settings are needed later, they go here.

- [ ] **Step 2: Write the python tool config**

Create `dot_config/mise/conf.d/python.toml` with:

```toml
[tools]
python = "3.13"
```

- [ ] **Step 3: Write the node tool config**

Create `dot_config/mise/conf.d/node.toml` with:

```toml
[tools]
node = "22"
```

- [ ] **Step 4: Write the rust tool config**

Create `dot_config/mise/conf.d/rust.toml` with:

```toml
[tools]
rust = "latest"
```

- [ ] **Step 5: Write the go tool config**

Create `dot_config/mise/conf.d/go.toml` with:

```toml
[tools]
go = "latest"
```

- [ ] **Step 6: Write the lua tool config**

Create `dot_config/mise/conf.d/lua.toml` with:

```toml
[tools]
lua = "5.1"
```

- [ ] **Step 7: Write the luarocks tool config**

Create `dot_config/mise/conf.d/luarocks.toml` with:

```toml
[tools]
luarocks = "latest"
```

- [ ] **Step 8: Verify all config files are present**

Run:
```bash
ls -1 dot_config/mise/config.toml dot_config/mise/conf.d/*.toml
```

Expected output (filename order may vary):
```
dot_config/mise/config.toml
dot_config/mise/conf.d/go.toml
dot_config/mise/conf.d/lua.toml
dot_config/mise/conf.d/luarocks.toml
dot_config/mise/conf.d/node.toml
dot_config/mise/conf.d/python.toml
dot_config/mise/conf.d/rust.toml
```

- [ ] **Step 9: Validate the TOML files parse correctly**

Run from the repo root (or copy the files to `~/.config/mise/` first — see Step 10 for the proper test path):

```bash
for f in dot_config/mise/config.toml dot_config/mise/conf.d/*.toml; do
  echo "==> $f"
  mise config ls --no-header 2>/dev/null | head -1
done
```

Simpler validation: use python to parse each file:
```bash
python3 -c "
import tomllib, glob, sys
ok = True
for p in sorted(glob.glob('dot_config/mise/**/*.toml', recursive=True)):
    try:
        with open(p, 'rb') as f:
            tomllib.load(f)
        print(f'OK  {p}')
    except Exception as e:
        print(f'ERR {p}: {e}')
        ok = False
sys.exit(0 if ok else 1)
"
```

Expected: every file prints `OK ...` and exit code is 0.

- [ ] **Step 10: Apply the config with chezmoi and verify mise sees it**

Run:
```bash
chezmoi apply --source . --destination "$HOME"
```

Then verify mise loads the config (it looks in `~/.config/mise/`):
```bash
mise ls --current 2>&1 | head -20
```

Expected: mise lists at least `python`, `node`, `rust`, `go`, `lua`, `luarocks` with their resolved versions (or shows "missing" for tools not yet installed — that's fine, the next task installs them).

If `mise ls` errors with "no config found", confirm the files actually exist at `~/.config/mise/config.toml` and `~/.config/mise/conf.d/*.toml`:
```bash
ls -la ~/.config/mise/ ~/.config/mise/conf.d/
```

- [ ] **Step 11: Commit the new config files**

```bash
git add dot_config/mise/config.toml dot_config/mise/conf.d/
git commit -m "feat(mise): add python, node, rust, go, lua, luarocks config"
```

---

## Task 3: Install the tools via mise and verify they resolve

**Files:** none (verification + installation only)

- [ ] **Step 1: Install all configured tools**

Run:
```bash
mise install
```

Expected: mise downloads and installs python 3.13.x, node 22.x, rust stable, go latest, lua 5.1.x, and luarocks. Output will look something like:

```
python 3.13.x        installed
node 22.x.x          installed
rust 1.xx.x          installed
go 1.xx.x            installed
lua 5.1.x            installed
luarocks 3.x.x       installed
```

This step may take several minutes (rust alone is ~250MB).

- [ ] **Step 2: Verify mise lists all installed tools**

Run:
```bash
mise ls
```

Expected: all six tools appear with a green checkmark (or "installed" status). Example:

```
python  3.13.x
node    22.x.x
go      1.xx.x
lua     5.1.x
luarocks 3.x.x
rust    1.xx.x
```

- [ ] **Step 3: Verify each tool resolves to a mise shim (without shell activation)**

Without sourcing `97-mise.zsh`, the mise shim dir is not yet on PATH. The shims live at `~/.local/share/mise/shims/`. Verify:

```bash
ls ~/.local/share/mise/shims/ | grep -E '^(python[0-9.]*|node|cargo|rustc|go|lua|luarocks)$'
```

Expected: a non-empty list including the tool shims mise created (e.g. `python`, `python3`, `node`, `cargo`, `rustc`, `go`, `lua`, `luarocks`).

Note: the user's shell won't see these shims yet — that requires the `97-mise.zsh` hook from Task 4. The point of this step is to confirm mise actually built the shims; the next task wires them into the shell.

- [ ] **Step 4: Test each shim runs (using its absolute path)**

```bash
~/.local/share/mise/shims/python --version
~/.local/share/mise/shims/node --version
~/.local/share/mise/shims/cargo --version
~/.local/share/mise/shims/rustc --version
~/.local/share/mise/shims/go version
~/.local/share/mise/shims/lua -v
~/.local/share/mise/shims/luarocks --version
```

Expected output (versions will vary):
```
Python 3.13.x
v22.x.x
cargo 1.xx.x (...)
rustc 1.xx.x (...)
go version go1.xx.x darwin/amd64
Lua 5.1.x
<x.x.x>
```

If any command fails, run `mise install <tool>` for that specific tool to retry, then re-run the check.

(No commit in this task — no files changed.)

---

## Task 4: Add the zsh hook (`dot_zsh/configs/97-mise.zsh`)

**Files:**
- Create: `dot_zsh/configs/97-mise.zsh`

- [ ] **Step 1: Write the zsh hook file**

Create `dot_zsh/configs/97-mise.zsh` with:

```zsh
# mise: dev tool version manager (rust, go, node, python, lua, luarocks)
if command -v mise &>/dev/null; then
  eval "$(mise activate zsh)"
fi
```

Notes:
- The `command -v mise` guard mirrors the pattern in `60-pyenv.zsh` — if mise is not on PATH, this is a no-op rather than an error.
- `eval "$(mise activate zsh)"` is mise's documented activation form. The activate command emits shell hooks (`chpwd_functions`, `preexec_functions`) that must be eval'd in the current shell.
- File position `97` (between `95-windsurf.zsh` and `99-completion.zsh`) puts mise late in the load order so its shims take precedence on PATH over legacy tool configs (nvm, pyenv, gvm).

- [ ] **Step 2: Verify the file is in the right place and matches the existing naming convention**

```bash
ls -1 dot_zsh/configs/ | grep -E '^[0-9]+-.*\.zsh$' | tail -5
```

Expected: the listing includes `97-mise.zsh` somewhere before `99-completion.zsh`.

- [ ] **Step 3: Commit the new zsh hook**

```bash
git add dot_zsh/configs/97-mise.zsh
git commit -m "feat(zsh): add 97-mise.zsh hook for mise activation"
```

---

## Task 5: Remove `~/.cargo/env` source from `dot_zshenv`

**Files:**
- Modify: `dot_zshenv` (remove last line)

- [ ] **Step 1: Read the current `dot_zshenv` to confirm its structure**

Run:
```bash
tail -5 dot_zshenv
```

Expected output (the very last line should be `. "$HOME/.cargo/env"`):
```
unset _old_path
. "$HOME/.cargo/env"
```

- [ ] **Step 2: Remove the cargo/env source line**

Use the `edit` tool to remove the final `. "$HOME/.cargo/env"` line. Replace:

```
unset _old_path
. "$HOME/.cargo/env"
```

with:

```
unset _old_path
```

The `unset _old_path` line must stay (it's the cleanup for the PATH warning at the top of the file).

- [ ] **Step 3: Verify the result**

```bash
tail -5 dot_zshenv
```

Expected output (the `. "$HOME/.cargo/env"` line is gone):
```
  MSG
fi

unset _old_path
```

And confirm there's no `.cargo/env` reference left in the file:
```bash
grep -n 'cargo/env' dot_zshenv || echo "no cargo/env reference — OK"
```

Expected: `no cargo/env reference — OK`

- [ ] **Step 4: Commit the change**

```bash
git add dot_zshenv
git commit -m "refactor(zshenv): drop .cargo/env source; mise owns rust shims"
```

---

## Task 6: End-to-end verification

**Files:** none (verification only)

- [ ] **Step 1: Apply all dotfiles with chezmoi**

```bash
chezmoi apply --source . --destination "$HOME"
```

Expected: no errors. If chezmoi prints a diff, review it and confirm the changes match the spec.

- [ ] **Step 2: Open a fresh interactive zsh shell**

```bash
exec zsh
```

This replaces the current shell with a new one that sources all dotfiles.

- [ ] **Step 3: Verify mise is on PATH**

```bash
command -v mise && mise --version
```

Expected: a path to mise (e.g. `/Users/yuez/.local/bin/mise`) and a version string.

- [ ] **Step 4: Verify all six tools resolve to mise shims**

```bash
for tool in python node cargo rustc go lua luarocks; do
  path=$(command -v "$tool" 2>/dev/null) || { echo "MISSING: $tool"; continue; }
  case "$path" in
    *mise/shims*) echo "OK  $tool -> $path" ;;
    *)            echo "WRONG SHIM: $tool -> $path (expected mise shim)" ;;
  esac
done
```

Expected: every line starts with `OK`. If any line shows `WRONG SHIM`, the legacy tool config (nvm, pyenv, gvm) is shadowing mise — check load order in `dot_zsh/configs/`.

- [ ] **Step 5: Verify each tool reports the correct version**

```bash
python --version    # Python 3.13.x
node --version      # v22.x.x
rustc --version     # rustc 1.xx.x (...)
go version          # go version go1.xx.x ...
lua -v              # Lua 5.1.x
luarocks --version  # <x.x.x>
```

- [ ] **Step 6: Confirm mise shims are absent from non-interactive shells**

```bash
zsh -c 'echo $PATH' | tr ':' '\n' | grep -q mise && echo "FAIL: mise in non-interactive PATH" || echo "OK: mise absent from non-interactive PATH"
```

Expected: `OK: mise absent from non-interactive PATH`. This confirms mise only activates for interactive shells (correct — scripts should use system or explicit tools).

- [ ] **Step 7: Confirm cargo/env is no longer sourced**

```bash
grep -q 'cargo/env' ~/.zshenv && echo "FAIL: cargo/env still in ~/.zshenv" || echo "OK: cargo/env removed"
```

Expected: `OK: cargo/env removed`.

- [ ] **Step 8: Confirm rust still works after cargo/env removal**

```bash
cargo --version && rustc --version
```

Expected: both report versions. If they fail, check `mise ls` and `mise install rust` to repair the toolchain.

---

## Self-Review Notes

- **Spec coverage:** every requirement from `docs/superpowers/specs/2026-06-16-mise-dev-tool-manager-design.md` is implemented (file structure, version specs, shell integration, cargo/env removal, verification steps).
- **No placeholders:** all code blocks and commands are complete; expected output is specified for every verification step.
- **Type/name consistency:** tool names, config file paths, and commit messages are consistent across tasks.
- **Out of scope:** nvm/pyenv/gvm removal, per-project `mise.toml`, cargo-installed binaries migration — explicitly noted as future work in the spec and not touched here.
