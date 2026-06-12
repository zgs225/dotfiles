yuez's dotfiles
===================

Requirements
------------

Set zsh as your login shell:

    chsh -s $(which zsh)

Install [chezmoi](https://www.chezmoi.io/):

    brew install chezmoi

Install
-------

Clone onto your laptop and apply:

    git clone https://github.com/zgs225/dotfiles.git ~/dotfiles
    chezmoi init --source ~/dotfiles --apply

Or, if you've already set up chezmoi on another machine:

    chezmoi init --apply zgs225/dotfiles

(Or, [fork and keep your fork
updated](http://robots.thoughtbot.com/keeping-a-github-fork-updated)).

Chezmoi will create the appropriate files in your home directory and run
post-install hooks (dependency checks, psqlrc setup, etc.).

Update
------

From time to time you should pull down any updates to these dotfiles, and run

    chezmoi update

to apply any new files and install new Neovim plugins. Chezmoi applies
changes idempotently, so you can run it as often as you like.

Make your own customizations
----------------------------

Chezmoi supports per-machine overrides via template conditions and data files.
Create a `~/.config/chezmoi/chezmoi.yaml` with your personal data:

```yaml
data:
  user:
    name: "Your Name"
    email: "your@email.com"
```

For machine-specific zsh configs, add numbered files to `~/.zsh/configs/`:

    # ~/.zsh/configs/96-my-stuff.zsh
    alias todo='$EDITOR ~/.todo'

For Git-specific overrides, use `~/.gitconfig.local` which is included by the
template:

    [user]
      name = Your Name
      email = your@email.com

For secrets (API keys, tokens), use chezmoi's age encryption:

    chezmoi add --encrypt ~/.zshrc.local

zsh Configurations
------------------

Zsh configs are loaded in numeric order from `~/.zsh/configs/`:

```
00-xdg.zsh           # XDG base directories
05-options.zsh        # Shell options
10-color.zsh          # Color settings
15-completion.zsh     # Completion engine
20-history.zsh        # History settings
25-keybindings.zsh    # Key bindings
30-fzf.zsh            # FZF integration
35-antigen.zsh        # Antigen plugin manager
40-homebrew.zsh       # Homebrew (macOS only)
45-go.zsh             # Go environment
50-nvm.zsh            # Node version manager
55-rbenv.zsh          # Ruby version manager
60-pyenv.zsh          # Python version manager
65-java.zsh           # Java environment
70-uv.zsh             # UV Python toolchain
75-editor.zsh         # Editor defaults
80-yarn.zsh           # Yarn global path
85-bat.zsh            # Bat/cat aliases
90-p10k.zsh           # Powerlevel10k theme
94-path.zsh           # PATH configuration
95-windsurf.zsh       # Windsurf editor
99-completion.zsh     # Custom completions
```

Add your own numbered files for custom configs. Higher numbers load last,
so they can override earlier settings.

What's in it?
-------------

### Neovim Configuration

This configuration is built on [NvChad](https://nvchad.com/) v2.5 with [lazy.nvim](https://github.com/folke/lazy.nvim) as the plugin manager.

#### Architecture

```
dot_config/nvim/
├── init.lua              # Entry point
├── lua/
│   ├── plugins/          # Plugin definitions
│   │   ├── init.lua      # Base plugins
│   │   ├── devtools.lua  # Development tools
│   │   ├── appearance.lua # UI plugins
│   │   ├── flash.lua     # Quick navigation
│   │   └── jupyter.lua   # Jupyter support
│   ├── configs/          # Plugin configurations
│   ├── mappings.lua      # Key mappings
│   ├── options.lua       # Neovim options
│   └── chadrc.lua        # NvChad configuration
```

#### Core Development Tools
- **LSP & Debugging**:
  - `nvim-lspconfig`: Language Server Protocol support (Go, Python, TypeScript, Rust, Java, etc.)
  - `nvim-dap-ui`: Debug Adapter Protocol with UI
  - `mason.nvim`: LSP/DAP/formatter management

- **Code Navigation**:
  - `flash.nvim`: Precise cursor movement with labels
  - `aerial.nvim`: Code structure overview
  - `nvim-treesitter`: Advanced syntax parsing

- **Testing**:
  - `neotest`: Unified test runner
  - `neotest-golang`: Go language test support

- **Code Formatting**:
  - `conform.nvim`: Auto-formatting on save

#### AI Integration
- `claude-code.nvim`: Claude Code integration
- `opencode.nvim`: OpenCode integration
- `avante.nvim`: AI-powered code suggestions

#### Git Tools
- `git-worktree.nvim`: Git worktree management with Telescope integration

#### UI & Navigation
- **File Explorer**:
  - `nvim-tree`: File tree with icons

- **Code Context**:
  - `treesitter-context`: Current code block context
  - `dropbar.nvim`: Breadcrumb navigation

- **Appearance**:
  - Theme: `solarized_osaka` with transparency
  - `dressing.nvim`: Enhanced UI for input/select
  - `todo-comments.nvim`: TODO comment highlighting

- **Markdown Support**:
  - `render-markdown.nvim`: Markdown preview

#### Language Specific
- `nvim-java`: Java development tools
- `gomodifytags.nvim`: Go struct tags management

#### Key Mappings

| Key | Description |
|-----|-------------|
| `<leader>gw` | List/switch/delete git worktrees |
| `<leader>gW` | Create new git worktree |
| `<F8>` | Debugger: Continue |
| `<F9>` | Debugger: Toggle breakpoint |
| `<leader>tt` | Test: Run nearest |
| `<leader>tf` | Test: Run file |
| `<leader>td` | Test: Debug nearest |
| `<leader>ts` | Test: Toggle summary panel |
| `<leader>cc` | Toggle Claude Code |
| `<leader>aa` | Toggle OpenCode |
| `<leader>aA` | Ask OpenCode |
| `s` | Flash jump |
| `S` | Flash treesitter |
| `<C-h/j/k/l>` | Navigate windows in terminal mode |
| `<F5>` | Toggle nvim-tree |
| `<leader>n` | Focus nvim-tree |
| `<F6>` | Toggle aerial (code outline) |
| `<C-p>` | Find files (Telescope) |
| `<leader>dp` | Show diagnostics popup |
| `<leader>ca` | Code action |
| `]t` / `[t` | Next/previous TODO comment |

[tmux](http://robots.thoughtbot.com/a-tmux-crash-course)
configuration:

* Improve color resolution.
* Remove administrative debris (session name, hostname, time) in status bar.
* Set prefix to `Ctrl+s`
* Soften status bar color from harsh green to light gray.

[git](http://git-scm.com/) configuration:

* Adds a `create-branch` alias to create feature branches.
* Adds a `delete-branch` alias to delete feature branches.
* Adds a `merge-branch` alias to merge feature branches into master.
* Adds an `up` alias to fetch and rebase `origin/master` into the feature
  branch. Use `git up -i` for interactive rebases.
* Adds `post-{checkout,commit,merge}` hooks to re-index your ctags.
* Adds `pre-commit` and `prepare-commit-msg` stubs that delegate to your local
  config.
* Adds `trust-bin` alias to append a project's `bin/` directory to `$PATH`.

License

dotfiles is copyright © 2009-2018 thoughtbot. It is free software, and may be
redistributed under the terms specified in the [`LICENSE`] file.

[`LICENSE`]: /LICENSE
