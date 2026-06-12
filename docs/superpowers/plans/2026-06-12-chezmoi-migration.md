# Chezmoi Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate dotfiles from rcm to chezmoi with full chezmoi naming conventions, template-based config generation, and age-encrypted secrets.

**Architecture:** Rename all dotfiles to chezmoi `dot_`/`executable_`/`literal_` prefix convention, convert `gitconfig` and `ssh/config` to Go templates, replace `hooks/post-up` with chezmoi `run_` scripts, encrypt SSH keys with age.

**Tech Stack:** chezmoi CLI, Go templates, age encryption

---

### Task 1: Create chezmoi infrastructure files

**Files:**
- Create: `.chezmoi.yaml.tmpl`
- Create: `.chezmoiignore`
- Create: `.chezmoiremove`

- [ ] **Step 1: Create `.chezmoi.yaml.tmpl`**

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

- [ ] **Step 2: Create `.chezmoiignore`**

```
README*.md
LICENSE
CODE_OF_CONDUCT.md
.gitignore
.git/
.worktrees/
.opencode/
.DS_Store
*.swp
docs/
cursor/
scripts/
```

- [ ] **Step 3: Create `.chezmoiremove`**

```
.zshenv
.zshrc
.zshrc.local
.gitconfig
.gitignore
.gitmessage
.gemrc
.rspec
.psqlrc
.myclirc
.hushlogin
.aliases
.rcrc
.tmux.conf
.tmux.conf.local
.zsh/functions
.zsh/completions
.zsh/configs
.git_template
.config/nvim
.config/wezterm
.config/opencode
.config/pgcli
.bin/tat
.bin/git-co-pr
.bin/git-up
.bin/replace
.bin/roundrobin-execute
.bin/bundler-search
.bin/antigen.zsh
.bin/git-rename-branch
.bin/git-ctags
.bin/git-trust-bin
.bin/git-merge-branch
.bin/max-cpu-temperature
.bin/mp42gif.sh
.bin/fan-rpm
.bin/git-delete-branch
.bin/git-current-branch
.bin/git-create-branch
.bin/git-ca
```

- [ ] **Step 4: Verify chezmoi can read the source dir**

Run: `chezmoi execute-template '{{ .user.name }}'`
Expected: `yuez`

- [ ] **Step 5: Commit**

```bash
git add .chezmoi.yaml.tmpl .chezmoiignore .chezmoiremove
git commit -m "feat: add chezmoi infrastructure files"
```

---

### Task 2: Rename top-level static dotfiles

**Files:**
- Rename: `zshenv` → `dot_zshenv`
- Rename: `zshrc` → `dot_zshrc`
- Rename: `zshrc.local` → `dot_zshrc.local`
- Rename: `gitignore` → `dot_gitignore`
- Rename: `gitmessage` → `dot_gitmessage`
- Rename: `tmux.conf` → `dot_tmux.conf`
- Rename: `tmux.conf.local` → `dot_tmux.conf.local`
- Rename: `gemrc` → `dot_gemrc`
- Rename: `rspec` → `dot_rspec`
- Rename: `psqlrc` → `dot_psqlrc`
- Rename: `myclirc` → `dot_myclirc`
- Rename: `hushlogin` → `dot_hushlogin`
- Rename: `aliases` → `dot_aliases`
- Modify: `dot_zshrc:9` — update function loading path

- [ ] **Step 1: Rename all top-level static dotfiles**

```bash
git mv zshenv dot_zshenv
git mv zshrc dot_zshrc
git mv zshrc.local dot_zshrc.local
git mv gitignore dot_gitignore
git mv gitmessage dot_gitmessage
git mv tmux.conf dot_tmux.conf
git mv tmux.conf.local dot_tmux.conf.local
git mv gemrc dot_gemrc
git mv rspec dot_rspec
git mv psqlrc dot_psqlrc
git mv myclirc dot_myclirc
git mv hushlogin dot_hushlogin
git mv aliases dot_aliases
```

- [ ] **Step 2: Update function loading path in `dot_zshrc` line 9**

Edit `dot_zshrc`, change line 9:
```zsh
for function in ~/.zsh/functions/*; do
```

No change needed — the path `~/.zsh/functions/*` is correct since chezmoi deploys to the same location. Skip this step.

- [ ] **Step 3: Verify files moved correctly**

```bash
ls -la dot_zshenv dot_zshrc dot_zshrc.local dot_gitignore dot_gitmessage dot_tmux.conf dot_tmux.conf.local dot_gemrc dot_rspec dot_psqlrc dot_myclirc dot_hushlogin dot_aliases
```

Expected: all files exist with content intact.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: rename top-level dotfiles to chezmoi dot_ prefix"
```

---

### Task 3: Restructure zsh/ directory with numeric prefixes

**Files:**
- Rename: `zsh/` → `dot_zsh/`
- Rename: `zsh/configs/*.zsh` → `dot_zsh/configs/NN-*.zsh` (numeric prefix)
- Move: `zsh/configs/post/completion.zsh` → `dot_zsh/configs/99-completion.zsh`
- Move: `zsh/configs/post/path.zsh` → `dot_zsh/configs/95-path.zsh`
- Modify: `dot_zshrc:42` — update config loading to simple numeric-order glob

- [ ] **Step 1: Rename zsh/ to dot_zsh/**

```bash
git mv zsh dot_zsh
```

- [ ] **Step 2: Merge post/ files into main configs with numeric prefixes**

```bash
git mv dot_zsh/configs/post/path.zsh dot_zsh/configs/94-path.zsh
git mv dot_zsh/configs/post/completion.zsh dot_zsh/configs/99-completion.zsh
rmdir dot_zsh/configs/post
```

- [ ] **Step 3: Rename all configs with numeric prefixes**

```bash
cd dot_zsh/configs
git mv xdg.zsh 00-xdg.zsh
git mv options.zsh 05-options.zsh
git mv color.zsh 10-color.zsh
git mv completion.zsh 15-completion.zsh
git mv history.zsh 20-history.zsh
git mv keybindings.zsh 25-keybindings.zsh
git mv fzf.zsh 30-fzf.zsh
git mv antigen.zsh 35-antigen.zsh
git mv homebrew.zsh 40-homebrew.zsh
git mv go.zsh 45-go.zsh
git mv nvm.zsh 50-nvm.zsh
git mv rbenv.zsh 55-rbenv.zsh
git mv pyenv.zsh 60-pyenv.zsh
git mv java.zsh 65-java.zsh
git mv uv.zsh 70-uv.zsh
git mv editor.zsh 75-editor.zsh
git mv yarn.zsh 80-yarn.zsh
git mv bat.zsh 85-bat.zsh
git mv p10k.zsh 90-p10k.zsh
git mv 94-path.zsh 94-path.zsh
git mv windsurf.zsh 95-windsurf.zsh
git mv 99-completion.zsh 99-completion.zsh
```

- [ ] **Step 4: Simplify config loading in `dot_zshrc` lines 13-42**

Replace the `_load_settings` function and its call with:

```zsh
# load custom executable functions
for function in ~/.zsh/functions/*; do
  source $function
done

# load zsh configs in numeric order
for config in ~/.zsh/configs/*.zsh(N); do
  source "$config"
done
```

Delete lines 8-42 (original function loading through `_load_settings("$HOME/.zsh/configs")`) and replace with the above block.

- [ ] **Step 5: Verify files**

```bash
ls dot_zsh/configs/
ls dot_zsh/functions/
ls dot_zsh/completion/
```

Expected: all configs have numeric prefixes, no `post/` directory.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: restructure zsh configs with numeric prefix ordering"
```

---

### Task 4: Move bin/ scripts to dot_bin/executable_*

**Files:**
- Create: `dot_bin/executable_*` for each script in `bin/`

- [ ] **Step 1: Create dot_bin/ directory and move scripts**

```bash
mkdir -p dot_bin
for script in bin/*; do
  name=$(basename "$script")
  git mv "$script" "dot_bin/executable_${name}"
done
rmdir bin
```

- [ ] **Step 2: Verify scripts**

```bash
ls dot_bin/
```

Expected: all scripts prefixed with `executable_`.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: move bin scripts to dot_bin/executable_*"
```

---

### Task 5: Move config/ to dot_config/ and handle ssh/ as private_dot_ssh/

**Files:**
- Rename: `config/` → `dot_config/`
- Rename: `ssh/` → `private_dot_ssh/`

- [ ] **Step 1: Rename config/ to dot_config/**

```bash
git mv config dot_config
```

- [ ] **Step 2: Rename ssh/ to private_dot_ssh/**

```bash
git mv ssh private_dot_ssh
```

- [ ] **Step 3: Verify structure**

```bash
ls dot_config/
ls private_dot_ssh/
```

Expected: `dot_config/nvim/, dot_config/wezterm/, dot_config/opencode/, dot_config/pgcli/` and `private_dot_ssh/config`.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: rename config/ to dot_config/ and ssh/ to private_dot_ssh/"
```

---

### Task 6: Handle git_template/ with literal copy for HEAD

**Files:**
- Rename: `git_template/` → `dot_git_template/`
- Rename: `dot_git_template/HEAD` → `dot_git_template/literal_HEAD`

- [ ] **Step 1: Rename directory and mark HEAD as literal copy**

```bash
git mv git_template dot_git_template
git mv dot_git_template/HEAD dot_git_template/literal_HEAD
```

- [ ] **Step 2: Verify**

```bash
ls dot_git_template/
ls dot_git_template/hooks/
```

Expected: `literal_HEAD`, `hooks/`, `info/`.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: rename git_template with literal_HEAD for chezmoi copy mode"
```

---

### Task 7: Create dot_gitconfig.tmpl template

**Files:**
- Replace: `gitconfig` (already renamed to `dot_gitconfig.tmpl`) — create new template
- Read: old gitconfig content for static sections

Note: `gitconfig` was not yet renamed to chezmoi format since it needs to become a template. Create `dot_gitconfig.tmpl` from scratch.

- [ ] **Step 1: Create `dot_gitconfig.tmpl` with template variables**

```ini
[user]
  name  = {{ .user.name }}
  email = {{ .user.email }}

[init]
  defaultBranch = main
  templatedir = ~/.git_template

[push]
  default = current

[color]
  ui = auto

[alias]
  aa = add --all
  ap = add --patch
  branches = for-each-ref --sort=-committerdate --format=\"%(color:blue)%(authordate:relative)\t%(color:red)%(authorname)\t%(color:white)%(color:bold)%(refname:short)\" refs/remotes
  ci = commit -v
  co = checkout
  br = branch
  create-branch = !sh -c 'git push origin HEAD:refs/heads/$1 && git fetch origin && git branch --track $1 origin/$1 && cd . && git checkout $1' -
  delete-branch = !sh -c 'git push origin :refs/heads/$1 && git branch -D $1' -
  merge-branch  = !git checkout master && git merge --no-ff @{-1}
  pr = !hub pull-request
  st = status
  up = !git fetch origin && git rebase origin/master
  l  = log --pretty=colored
  pl = !sh -c 'git pull origin $(git rev-parse --abbrev-ref HEAD)'
  ps = !sh -c 'git push origin $(git rev-parse --abbrev-ref HEAD)'
  sm = submodule
  cp = cherry-pick

[pretty]
  colored = format:%Cred%h%Creset %s %Cgreen(%cr) %C(bold blue)%an%Creset

[core]
  editor = {{ .defaultEditor }}
{{- if .isMacOS }}
  autocrlf = input
{{- end }}
  excludesfile = ~/.gitignore

[merge]
  ff = only

[commit]
  template = ~/.gitmessage

[fetch]
  prune = true

[credential]
  helper = osxkeychain

[github]
  user = zgs225

[filter "lfs"]
  clean = git-lfs clean -- %f
  smudge = git-lfs smudge -- %f
  required = true
  process = git-lfs filter-process

[rebase]
  autosquash = true

[include]
  path = ~/.gitconfig.local

[diff]
  colorMoved = zebra

[pull]
  rebase = false
  ff = only

[safe]
  directory = *
```

- [ ] **Step 2: Write the file**

Write the above template content to `dot_gitconfig.tmpl`.

- [ ] **Step 3: Verify template compiles**

```bash
chezmoi execute-template < dot_gitconfig.tmpl | grep -E "^  name =|^  email =|^  editor ="
```

Expected output:
```
  name = yuez
  email = i@yuez.me
  editor = nvim
```

- [ ] **Step 4: Commit**

```bash
git add dot_gitconfig.tmpl
git commit -m "feat: convert gitconfig to chezmoi template"
```

---

### Task 8: Convert SSH config to template

**Files:**
- Replace: `private_dot_ssh/config` → `private_dot_ssh/config.tmpl`

- [ ] **Step 1: Rename config to template**

```bash
git mv private_dot_ssh/config private_dot_ssh/config.tmpl
```

The current SSH config has no per-machine variance in the spec. It remains a static file but with `.tmpl` extension for future templating. No template variables needed yet.

- [ ] **Step 2: Verify content preserved**

```bash
chezmoi execute-template < private_dot_ssh/config.tmpl | head -3
```

Expected: `Include conf.d/*` as first line.

- [ ] **Step 3: Commit**

```bash
git add private_dot_ssh/config.tmpl
git commit -m "feat: rename ssh config to template"
```

---

### Task 9: Create run_before_install.sh

**Files:**
- Create: `run_before_install.sh`

- [ ] **Step 1: Create run_before_install.sh**

```bash
#!/bin/sh

set -e

echo "==> Checking system dependencies..."

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

missing=0

check_cmd() {
  if command -v "$1" >/dev/null 2>&1; then
    printf "  ${GREEN}✓${NC} %s\n" "$1"
  else
    printf "  ${RED}✗${NC} %s ${YELLOW}(missing)${NC}\n" "$1"
    missing=1
  fi
}

echo "Required tools:"
check_cmd zsh
check_cmd git
check_cmd nvim
check_cmd tmux

echo ""
echo "Optional tools:"
check_cmd age

echo ""
echo "OS: $(uname -s)"
echo "Arch: $(uname -m)"

if [ "$missing" -eq 1 ]; then
  echo ""
  printf "${YELLOW}Some dependencies are missing. Please install them before running 'chezmoi apply'.${NC}\n"
else
  printf "${GREEN}All required dependencies found.${NC}\n"
fi
```

- [ ] **Step 2: Make executable**

```bash
chmod +x run_before_install.sh
```

- [ ] **Step 3: Test script runs**

```bash
./run_before_install.sh
```

Expected: lists installed/missing tools.

- [ ] **Step 4: Commit**

```bash
git add run_before_install.sh
git commit -m "feat: add chezmoi run_before_install dependency check script"
```

---

### Task 10: Create run_after_install.sh (replaces hooks/post-up)

**Files:**
- Create: `run_after_install.sh`
- Delete: `hooks/post-up`

- [ ] **Step 1: Create run_after_install.sh**

```bash
#!/bin/sh

set -e

echo "==> Running post-install tasks..."

touch "$HOME/.psqlrc.local"

if [ -f "$HOME/.git_template/HEAD" ] && \
  [ "$(cat "$HOME/.git_template/HEAD")" = "ref: refs/heads/main" ]; then
  echo "Removing ~/.git_template/HEAD in favor of defaultBranch"
  rm -f ~/.git_template/HEAD
fi

if grep -qw path_helper /etc/zshenv 2>/dev/null; then
  cat <<MSG
Warning: /etc/zshenv configuration file on your system may cause unexpected
PATH changes on subsequent invocations of the zsh shell. The solution is to
rename the file to zprofile:
  sudo mv /etc/{zshenv,zprofile}
MSG
fi

echo "Done."
```

- [ ] **Step 2: Make executable**

```bash
chmod +x run_after_install.sh
```

- [ ] **Step 3: Commit**

```bash
git add run_after_install.sh
git commit -m "feat: add chezmoi run_after_install hook"
```

---

### Task 11: Create run_onchange_after_p10k.sh

**Files:**
- Create: `run_onchange_after_p10k.sh`

- [ ] **Step 1: Create run_onchange_after_p10k.sh**

```bash
#!/bin/sh

echo "p10k configuration changed. Restart your shell or run 'exec zsh' to reload."
```

- [ ] **Step 2: Make executable**

```bash
chmod +x run_onchange_after_p10k.sh
```

- [ ] **Step 3: Commit**

```bash
git add run_onchange_after_p10k.sh
git commit -m "feat: add p10k onchange reload hook"
```

---

### Task 12: Remove old rcm files and cleanup

**Files:**
- Delete: `rcrc`
- Delete: `hooks/post-up`

- [ ] **Step 1: Remove old rcm files**

```bash
git rm rcrc hooks/post-up
rmdir hooks 2>/dev/null || true
```

- [ ] **Step 2: Stage and commit**

```bash
git add -A
git commit -m "chore: remove rcm files (replaced by chezmoi)"
```

---

### Task 13: Update .gitignore for chezmoi

**Files:**
- Modify: `.gitignore`

- [ ] **Step 1: Update .gitignore**

Remove stale entries referencing old paths. Write the cleaned `.gitignore`:

```
.vim/bundle/
yarn.lock
settings.local.json
.worktrees/
```

- [ ] **Step 2: Write the cleaned .gitignore**

Write the above content to `.gitignore`.

- [ ] **Step 3: Commit**

```bash
git add .gitignore
git commit -m "chore: clean up .gitignore for chezmoi structure"
```

---

### Task 14: Encrypt SSH private keys (manual step)

**Files:**
- Action: Encrypt `~/.ssh/id_ed25519` with age and add to source dir

This task cannot be automated (requires access to the actual SSH key on the machine). Document the manual steps.

- [ ] **Step 1: Ensure age is installed**

```bash
which age || brew install age
```

- [ ] **Step 2: Encrypt the SSH private key**

```bash
chezmoi add --encrypt ~/.ssh/id_ed25519
```

This creates `private_dot_ssh/encrypted_id_ed25519.age` in the source dir, which decrypts to `~/.ssh/id_ed25519` with 0600 permissions.

- [ ] **Step 3: Add the SSH public key (plaintext)**

```bash
cp ~/.ssh/id_ed25519.pub private_dot_ssh/id_ed25519.pub
```

- [ ] **Step 4: Verify encryption**

```bash
chezmoi state dump | grep id_ed25519
```

Expected: shows the encrypted entry.

- [ ] **Step 5: Commit**

```bash
git add private_dot_ssh/encrypted_id_ed25519.age private_dot_ssh/id_ed25519.pub
git commit -m "feat: add age-encrypted SSH private key and public key"
```

---

### Task 15: Final verification — chezmoi diff dry run

- [ ] **Step 1: Run chezmoi diff to preview all changes**

```bash
chezmoi diff
```

Expected: shows diff between current home files and what chezmoi would deploy. Review for correctness.

- [ ] **Step 2: Run chezmoi apply --dry-run**

```bash
chezmoi apply --dry-run --verbose
```

Expected: lists all files that would be created/modified. No errors.

- [ ] **Step 3: Check for any remaining old-style files**

```bash
ls zshenv 2>/dev/null && echo "WARNING: zshenv still exists (unrenamed)" || echo "OK: no old-style files"
ls hooks 2>/dev/null && echo "WARNING: hooks/ still exists" || echo "OK: hooks/ removed"
```

- [ ] **Step 4: Full file listing sanity check**

```bash
git ls-files | sort
```

Expected: all files follow chezmoi naming convention (`dot_`, `executable_`, `literal_`, `private_dot_`, `run_`, `.chezmoi`).
