yuez's dotfiles
===================

Requirements
------------

Set zsh as your login shell:

    chsh -s $(which zsh)

Install
-------

Clone onto your laptop:

    git clone https://github.com/zgs225/dotfiles.git ~/dotfiles

(Or, [fork and keep your fork
updated](http://robots.thoughtbot.com/keeping-a-github-fork-updated)).

Install [rcm](https://github.com/thoughtbot/rcm):

    brew install rcm

Install the dotfiles:

    env RCRC=$HOME/dotfiles/rcrc rcup

After the initial installation, you can run `rcup` without the one-time variable
`RCRC` being set (`rcup` will symlink the repo's `rcrc` to `~/.rcrc` for future
runs of `rcup`). [See
example](https://github.com/thoughtbot/dotfiles/blob/master/rcrc).

This command will create symlinks for config files in your home directory.
Setting the `RCRC` environment variable tells `rcup` to use standard
configuration options:

* Exclude the `README.md`, `README-ES.md` and `LICENSE` files, which are part of
  the `dotfiles` repository but do not need to be symlinked in.
* Give precedence to personal overrides which by default are placed in
  `~/dotfiles-local`
* Please configure the `rcrc` file if you'd like to make personal
  overrides in a different directory


Update
------

From time to time you should pull down any updates to these dotfiles, and run

    rcup

to link any new files and install new Neovim plugins. **Note** You _must_ run
`rcup` after pulling to ensure that all files in plugins are properly installed,
but you can safely run `rcup` multiple times so update early and update often!

Make your own customizations
----------------------------

Create a directory for your personal customizations:

    mkdir ~/dotfiles-local

Put your customizations in `~/dotfiles-local` appended with `.local`:

* `~/dotfiles-local/aliases.local`
* `~/dotfiles-local/git_template.local/*`
* `~/dotfiles-local/gitconfig.local`
* `~/dotfiles-local/psqlrc.local` (we supply a blank `.psqlrc.local` to prevent `psql` from
  throwing an error, but you should overwrite the file with your own copy)
* `~/dotfiles-local/tmux.conf.local`
* `~/dotfiles-local/zshrc.local`
* `~/dotfiles-local/zsh/configs/*`

For example, your `~/dotfiles-local/aliases.local` might look like this:

    # Productivity
    alias todo='$EDITOR ~/.todo'

Your `~/dotfiles-local/gitconfig.local` might look like this:

    [alias]
      l = log --pretty=colored
    [pretty]
      colored = format:%Cred%h%Creset %s %Cgreen(%cr) %C(bold blue)%an%Creset
    [user]
      name = Dan Croak
      email = dan@thoughtbot.com

Your `~/dotfiles-local/zshrc.local` might look like this:

    # load pyenv if available
    if which pyenv &>/dev/null ; then
      eval "$(pyenv init -)"
    fi

zsh Configurations
------------------

Additional zsh configuration can go under the `~/dotfiles-local/zsh/configs` directory. This
has two special subdirectories: `pre` for files that must be loaded first, and
`post` for files that must be loaded last.

For example, `~/dotfiles-local/zsh/configs/pre/virtualenv` makes use of various shell
features which may be affected by your settings, so load it first:

    # Load the virtualenv wrapper
    . /usr/local/bin/virtualenvwrapper.sh

Setting a key binding can happen in `~/dotfiles-local/zsh/configs/keys`:

    # Grep anywhere with ^G
    bindkey -s '^G' ' | grep '

Some changes, like `chpwd`, must happen in `~/dotfiles-local/zsh/configs/post/chpwd`:

    # Show the entries in a directory whenever you cd in
    function chpwd {
      ls
    }

This directory is handy for combining dotfiles from multiple teams; one team
can add the `virtualenv` file, another `keys`, and a third `chpwd`.

The `~/dotfiles-local/zshrc.local` is loaded after `~/dotfiles-local/zsh/configs`.

What's in it?
-------------

### Neovim Configuration

This configuration is built on [NvChad](https://nvchad.com/) v2.5 with [lazy.nvim](https://github.com/folke/lazy.nvim) as the plugin manager.

#### Architecture

```
config/nvim/
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
