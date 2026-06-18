# Mise Dev Tool Manager Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `mise` as the dev tool version manager to the chezmoi dotfiles, installing python 3.13, node 22, rust (latest), golang (latest), and lua 5.1, with shell integration via the existing `dot_zsh/configs/` auto-load mechanism. LuaRocks is auto-bundled by the vfox-lua plugin alongside lua 5.1, not installed as a separate mise tool.

**Architecture:** Static TOML config files under `dot_config/mise/` (one base + one per tool) symlinked by chezmoi. A single new zsh config file (`97-mise.zsh`) sources `mise activate zsh`, auto-loaded by the existing zshrc loop. The legacy `. "$HOME/.cargo/env"` source in `dot_zshenv` is removed since mise now owns the rust shims.

**Tech Stack:** mise (installed on target device, not on the control machine used to author the dotfiles), chezmoi, zsh, TOML.

**Important execution context:** The user is authoring these dotfiles on a control machine that does *not* have mise installed. mise lives on the target device. Therefore this plan does **not** include a local `mise install` step or a local end-to-end verification. Local validation is limited to:
- TOML syntax checks (python `tomllib`)
- `chezmoi apply --dry-run --source .` to confirm the source tree is well-formed
- A `chezmoi apply` to the local `~/.config/mise/` to confirm files deploy

Final tool installation and shell verification happen on the target device (documented in the spec's Verification section).

---

## File Structure

| File | Type | Responsibility |
|------|------|----------------|
| `dot_config/mise/config.toml` | new | Base mise config (empty / shared settings) |
| `dot_config/mise/conf.d/python.toml` | new | `python = "3.13"` |
| `dot_config/mise/conf.d/node.toml` | new | `node = "22"` |
| `dot_config/mise/conf.d/rust.toml` | new | `rust = "latest"` |
| `dot_config/mise/conf.d/go.toml` | new | `go = "latest"` |
| `dot_config/mise/conf.d/lua.toml` | new | `lua = "5.1"` (vfox-lua plugin auto-bundles LuaRocks) |
| `dot_zsh/configs/97-mise.zsh` | new | `eval "$(mise activate zsh)"` hook |
| `dot_zshenv` | modify | Remove trailing `. "$HOME/.cargo/env"` line |

Each per-tool TOML contains a single `[tools]` block with one entry. This matches mise's `conf.d/` split convention so adding/removing/re-pinning a single tool is a one-file change.

---

## Task 1: Create the mise config directory scaffolding

**Files:**
- Create: `dot_config/mise/conf.d/.gitkeep` (placeholder so git tracks the empty directory; matches the existing repo convention used in `dot_local/share/wallpapers/.gitkeep`. The file will be removed in Task 2 once real content is added.)

- [ ] **Step 1: Create the mise config directories and placeholder**

Run:
```bash
mkdir -p dot_config/mise/conf.d
touch dot_config/mise/conf.d/.gitkeep
```

Expected: no output. Verify with `ls -la dot_config/mise/` — should show `conf.d/` directory exists. Verify with `ls -la dot_config/mise/conf.d/` — should show `.gitkeep` file.

- [ ] **Step 2: Commit the directory scaffolding**

```bash
git add dot_config/mise/conf.d/.gitkeep
git commit -m "chore(mise): create config directory scaffolding"
```

Note: we use `.gitkeep` (the existing repo convention) rather than `.keep` so the placeholder is consistent with the rest of the dotfiles.

---

## Task 2: Write the mise base config and per-tool config files

**Files:**
- Create: `dot_config/mise/config.toml`
- Create: `dot_config/mise/conf.d/python.toml`
- Create: `dot_config/mise/conf.d/node.toml`
- Create: `dot_config/mise/conf.d/rust.toml`
- Create: `dot_config/mise/conf.d/go.toml`
- Create: `dot_config/mise/conf.d/lua.toml`

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

- [ ] **Step 7: Verify all config files are present**

Run:
```bash
ls -1 dot_config/mise/config.toml dot_config/mise/conf.d/*.toml
```

Expected output (filename order may vary):
```
dot_config/mise/config.toml
dot_config/mise/conf.d/go.toml
dot_config/mise/conf.d/lua.toml
dot_config/mise/conf.d/node.toml
dot_config/mise/conf.d/python.toml
dot_config/mise/conf.d/rust.toml
```

- [ ] **Step 8: Validate the TOML files parse correctly**

Use python to parse each file:
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

- [ ] **Step 9: Apply the config with chezmoi (dry-run first)**

The target device will run `chezmoi apply` to install the files. From the control machine, validate that the source tree is well-formed:

```bash
chezmoi apply --source . --dry-run 2>&1 | head -30
```

Expected: a diff showing the files that *would* be created at `~/.config/mise/config.toml` and `~/.config/mise/conf.d/*.toml`. No errors.

- [ ] **Step 10: (Optional) Apply locally to test the deployment**

If you have a non-production `~/.config/mise/` (e.g. this is your primary machine but you don't mind the test files appearing), run:

```bash
chezmoi apply --source . --destination "$HOME"
```

This is purely a smoke test of the deployment mechanism. The actual `mise install` and runtime use happens on the target device.

- [ ] **Step 11: Commit the new config files**

```bash
git add dot_config/mise/config.toml dot_config/mise/conf.d/
git commit -m "feat(mise): add python, node, rust, go, lua config"
```

---

## Task 3: Validate the mise config statically (control-machine local check)

**Files:** none (validation only; tool installation happens on the target device)

> **Note:** This task replaces what would have been "run `mise install`" on the target device. From the control machine (which does not have mise installed), we can only do static checks on the TOML config. The actual `mise install` + shell integration verification happens on the target device after the dotfiles are deployed there.

- [ ] **Step 1: Confirm all five per-tool TOML files plus the base config exist and parse**

Run the python-based TOML validator from Task 2, Step 8 — it should already have been run. Re-run for a final check:

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

Expected: all five per-tool files plus the base `config.toml` print `OK`. Exit code 0.

- [ ] **Step 2: Confirm every tool listed in the spec has a config file**

```bash
for tool in python node rust go lua; do
  if [ -f "dot_config/mise/conf.d/${tool}.toml" ]; then
    echo "OK  ${tool}.toml"
  else
    echo "MISSING  ${tool}.toml"
  fi
done
[ ! -f dot_config/mise/conf.d/luarocks.toml ] && echo "OK: luarocks.toml absent (luarocks bundled by vfox-lua)" || echo "FAIL: luarocks.toml should be absent"
```

Expected: every line starts with `OK`.

- [ ] **Step 3: Confirm version specs match the spec**

```bash
for tool in python node rust go lua; do
  printf '%-10s ' "$tool:"
  grep -E "^\s*${tool}\s*=" "dot_config/mise/conf.d/${tool}.toml"
done
```

Expected output (versions come from the spec, file is the one in the repo):
```
python:    python = "3.13"
node:      node = "22"
rust:      rust = "latest"
go:        go = "latest"
lua:       lua = "5.1"
```

(No commit in this task — no files changed.)

---

## Task 4: Add the zsh hook (`dot_zsh/configs/97-mise.zsh`)

**Files:**
- Create: `dot_zsh/configs/97-mise.zsh`

- [ ] **Step 1: Write the zsh hook file**

Create `dot_zsh/configs/97-mise.zsh` with:

```zsh
# mise: dev tool version manager (rust, go, node, python, lua; luarocks bundled)
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

## Task 6: Document manual verification for the target device

**Files:** none (this task is documentation only; the actual verification happens on the target device after `chezmoi apply`)

> **Note:** End-to-end verification requires a working shell on the target device where mise is installed. This task packages the verification steps for the user to run on the target device.

- [ ] **Step 1: Run the verification checklist on the target device**

After `chezmoi apply` on the target device and opening a fresh interactive zsh shell (`exec zsh`), run the full verification list from the spec (`docs/superpowers/specs/2026-06-16-mise-dev-tool-manager-design.md` → "Verification" section):

1. `command -v mise && mise --version` — mise itself on PATH
2. `mise install` — install all configured tools (first run only; takes several minutes)
3. `mise ls` — all five configured tools listed with their resolved versions
4. `for tool in python node cargo rustc go lua; do command -v "$tool"; done` — every tool resolves to a path containing `mise/shims`
5. `python --version; node --version; rustc --version; go version; lua -v; luarocks --version` — each tool reports the correct version (note: `luarocks` works because the vfox-lua plugin auto-installs it alongside lua 5.1)
6. `zsh -c 'echo $PATH' | tr ':' '\n' | grep -q mise && echo "FAIL" || echo "OK: mise absent from non-interactive PATH"` — confirms mise is interactive-only
7. `grep -q 'cargo/env' ~/.zshenv && echo "FAIL" || echo "OK"` — confirms cargo/env line was removed
8. `cargo --version && rustc --version` — confirms rust works without the rustup shim

- [ ] **Step 2: No commit in this task**

This task is purely procedural. The verification steps are already documented in the spec.

---

## Self-Review Notes

- **Spec coverage:** every requirement from `docs/superpowers/specs/2026-06-16-mise-dev-tool-manager-design.md` is implemented in the dotfiles (file structure, version specs, shell integration, cargo/env removal). Tasks that would have run on the target device (`mise install`, full shell verification) are documented in the spec and Task 6 for the user to run after deploying.
- **No placeholders:** all code blocks and commands are complete; expected output is specified for every verification step.
- **Type/name consistency:** tool names, config file paths, and commit messages are consistent across tasks.
- **Control-vs-target device split:** clearly called out in the new "Important execution context" block at the top of the plan. The original plan's Task 3 (local `mise install`) and Task 6 (local end-to-end shell verification) are replaced with static checks and documentation, respectively.
- **Out of scope:** nvm/pyenv/gvm removal, per-project `mise.toml`, cargo-installed binaries migration — explicitly noted as future work in the spec and not touched here.
