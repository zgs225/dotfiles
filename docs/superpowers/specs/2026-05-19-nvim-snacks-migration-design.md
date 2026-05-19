# Neovim Config Migration: NvChad → snacks.nvim

## Goal

Complete replacement of NvChad framework with `folke/snacks.nvim`, preserving all functionality and keybinding habits.

## Decisions

| Topic | Decision |
|-------|----------|
| Picker | **Snacks.picker** replaces telescope.nvim entirely |
| Statusline | **lualine.nvim** with solarized-osaka theme |
| Tab/buffer line | **None** — use `snacks.picker.buffers` (`<leader>,`) |
| Theme | **craftzdog/solarized-osaka.nvim** standalone |
| Command UI | **Keep noice.nvim** (cmdheight=0) |
| Dashboard | snacks.dashboard **`files` style** (keys + recent files column) |
| Git worktree | Custom **snacks.picker** integration |

## Plugin Migration Map

### REMOVED (NvChad + NvChad-replaced plugins ~12)

```
NvChad/NvChad               → framework removed
nvim-telescope/telescope.*   → snacks.picker
nvim-tree/nvim-tree.lua       → snacks.explorer
rcarriga/nvim-notify          → snacks.notifier
stevearc/dressing.nvim        → snacks.input
lukas-reineke/indent-blankline → snacks.indent
NvChad nvdash (built-in)      → snacks.dashboard
NvChad base46 theme engine    → craftzdog/solarized-osaka.nvim
NvChad autocommands           → custom autocmds.lua
```

### ADDED (~5)

```
folke/snacks.nvim            → core (picker, explorer, notifier, indent,
                                dashboard, scroll, terminal, toggle,
                                statuscolumn, words, scope, input,
                                bigfile, quickfile, zen, gitbrowse,
                                lazygit, bufdelete, rename, dim,
                                animate, image)
craftzdog/solarized-osaka.nvim → colorscheme
nvim-lualine/lualine.nvim    → statusline
```

### KEPT (unchanged, ~30)

```
lazy.nvim, nvim-cmp + cmp-*, LuaSnip, Comment.nvim,
nvim-autopairs, which-key.nvim, gitsigns.nvim,
conform.nvim, nvim-lspconfig, nvim-treesitter,
mason.nvim, noice.nvim, nvim-dap/dap-ui/dap-go,
neotest + neotest-golang, flash.nvim,
todo-comments.nvim, aerial.nvim, dropbar.nvim,
treesitter-context, render-markdown.nvim,
vim-surround, nvim-web-devicons,
claude-code.nvim, opencode.nvim, nvim-java,
gomodifytags.nvim, git-worktree.nvim (modified),
neopyter, avante.nvim, tiny-inline-diagnostic.nvim
```

## Directory Structure

```
~/.config/nvim/
├── init.lua                  # Rewritten: no NvChad bootstrap
├── .stylua.toml              # KEEP
├── lua/
│   ├── options.lua           # Rewritten: direct vim.opt, no nvchad.options
│   ├── mappings.lua          # Rewritten: snacks/lualine-based
│   ├── autocmds.lua          # NEW: replaces nvchad.autocmds
│   ├── chadrc.lua            # REMOVED
│   ├── configs/
│   │   ├── lazy.lua          # Simplified: remove disabled_plugins
│   │   ├── lsp.lua           # Rewritten: no nvchad.configs.lspconfig
│   │   ├── mason.lua         # KEEP
│   │   ├── conform.lua       # KEEP
│   │   ├── treesitter.lua    # Modified: no nvchad.configs.treesitter
│   │   ├── debug.lua         # KEEP
│   │   ├── neotest.lua       # KEEP
│   │   ├── aerial.lua        # KEEP
│   │   ├── dropbar.lua       # KEEP
│   │   ├── java.lua          # Modified: no nvchad.configs.lspconfig
│   │   ├── avante.lua        # KEEP
│   │   ├── lualine.lua       # NEW: lualine config
│   │   └── snacks.lua        # NEW: snacks default config (minimal,
│   │                            most config in plugin spec)
│   └── plugins/
│       ├── init.lua          # Modified: remove nvim-tree, add snacks
│       ├── appearance.lua    # Rewritten: remove nvim-tree/dressing
│       ├── devtools.lua      # Rewritten: remove telescope, add lualine
│       ├── flash.lua         # KEEP
│       ├── notify.lua        # REMOVED (→ snacks.notifier)
│       ├── jupyter.lua       # KEEP
│       └── snacks.lua        # NEW: snacks.nvim plugin spec + config
```

## Key Mapping Migration

Mappings that change ground (leader = `,`):

```
CURRENT → NEW                        REASON
─────────────────────────────────────────────────────────
<C-p>   → <leader>ff                Telescope → snacks.files
,q      → <leader>bd                quit → snacks.bufdelete
,n      → <leader>e                 nvimtree → snacks.explorer
,th     → <leader>uC                themes → snacks.colorschemes
,ch     → <leader>sk                cheatsheet → snacks.keymaps
,fo     → <leader>fr                oldfiles → snacks.recent
,fw     → <leader>/ or <leader>fw   live_grep → snacks.grep
,fa     → <leader>sm                marks → snacks.marks
,fn     → <leader>n                 notify history → snacks.notifier
NONE    → <leader>,                 NEW: snacks.picker.buffers
NONE    → <leader>z                 NEW: snacks.zen
NONE    → <leader>gg                NEW: snacks.lazygit
NONE    → <leader>gB                NEW: snacks.gitbrowse
NONE    → <leader>cR                NEW: snacks.rename
NONE    → <leader>.                 NEW: snacks.scratch
NONE    → <C-/>                     NEW: snacks.terminal
```

Mappings that stay the same:
`,w` `;` `tp/tn/tm` `<leader>dp` `<leader>ca` `<C-h/j/k/l>` (term nav)
`s/S/r/R/<C-s>` (flash) `<F5>/<F10>/<F11>/<F12>` `<M-r>/<M-s>`
`<leader>b` `<leader>du` `<leader>tt/tf/td/ts` `<F6>` `<leader>cc`
`<leader>aa/as/aA` `]t/[t` `<leader>gw/gW`

## snacks.nvim Features Enabled

| Feature | Enabled | Notes |
|---------|---------|-------|
| picker | yes | replaces telescope |
| explorer | yes | replaces nvim-tree |
| notifier | yes | replaces nvim-notify |
| indent | yes | replaces indent-blankline |
| dashboard | yes | replaces nvdash (`files` style) |
| scroll | yes | smooth scrolling |
| terminal | yes | floating/split terminals |
| toggle | yes | option toggles |
| statuscolumn | yes | git signs + fold column |
| words | yes | LSP references navigation |
| scope | yes | text objects + scope jumping |
| input | yes | replaces dressing.nvim |
| bigfile | yes | big file protection |
| quickfile | yes | fast file rendering |
| zen | yes | distraction-free mode |
| gitbrowse | yes | open in GitHub |
| lazygit | yes | lazygit integration |
| bufdelete | yes | smart buffer delete |
| rename | yes | LSP file rename |
| dim | yes | dim unfocused windows |
| animate | yes | smooth animations |
| image | yes | image viewer (kitty/wezterm) |
| git | no | overlaps with gitsigns.nvim |
| gh | no | not used |
| scratch | no | not used |
| debug | no | not used |
| profiler | no | not used |

## LSP / Treesitter / Options Decoupling

### LSP (`configs/lsp.lua`)

Remove `require("nvchad.configs.lspconfig")` dependency. Define `on_attach`, `on_init`, `capabilities` locally:

```lua
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)

local on_attach = function(client, bufnr)
  -- LSP keymaps (gd, K, gi, <leader>ca, etc.)
  vim.lsp.inlay_hint.enable(true)
end
```

`vim.diagnostic.config { virtual_text = false }` called once globally (already done in previous optimization).

### Treesitter (`configs/treesitter.lua`)

Remove `require "nvchad.configs.treesitter"`. Directly call:

```lua
require("nvim-treesitter.configs").setup({
  ensure_installed = { ... },  -- keep current parser list
  auto_install = true,
  highlight = { enable = true },
  indent = { enable = true },
})
```

### Options (`options.lua`)

Remove `require "nvchad.options"`. Write all options directly:

```lua
vim.o.cursorlineopt = "both"
vim.o.swapfile = false
vim.o.cmdheight = 0
vim.o.autoread = true
-- keep Makefile autocmd, gotmpl detection, messagesopt
```

### Autocommands (`autocmds.lua`)

New file. Port only essential autocommands from NvChad:
- Terminal settings on TermOpen
- Transparency adjustments (if solarized-osaka supports)

## Dashboard Design (`files` style)

```lua
dashboard = {
  preset = {
    pick = function(cmd, opts)
      return require("snacks").picker[cmd](opts)
    end,
    keys = {
      { icon = " ", key = "f", desc = "Find File", action = ":lua Snacks.dashboard.pick('files')" },
      { icon = "󰈚 ", key = "r", desc = "Recent Files", action = ":lua Snacks.dashboard.pick('oldfiles')" },
      { icon = "󰈭 ", key = "g", desc = "Find Word", action = ":lua Snacks.dashboard.pick('live_grep')" },
      { icon = " ", key = "m", desc = "Marks", action = ":lua Snacks.dashboard.pick('marks')" },
      { icon = " ", key = "t", desc = "Themes", action = ":lua Snacks.dashboard.pick('colorschemes')" },
      { icon = " ", key = "k", desc = "Keymaps", action = ":lua Snacks.dashboard.pick('keymaps')" },
      { icon = "󰒲 ", key = "L", desc = "Lazy", action = ":Lazy", enabled = package.loaded.lazy ~= nil },
      { icon = " ", key = "q", desc = "Quit", action = ":qa" },
    },
  },
  sections = {
    { section = "header" },
    { section = "keys", gap = 1, padding = 1 },
    { icon = " ", title = "Recent Files", section = "recent_files", indent = 2, padding = 2 },
    { section = "startup" },
  },
}
```

## Git Worktree (Custom snacks.picker)

Replace telescope-based git-worktree UI with a custom picker:

```lua
-- In git-worktree config:
local function worktree_picker()
  local worktrees = vim.fn.systemlist("git worktree list --porcelain")
  -- Parse worktree list
  -- Open snacks.picker with parsed items
  -- On select: cd to worktree + clear dap sessions + notify
end
```

Use `snacks.win` or `snacks.picker` for the selection UI. Full feature parity:
list, switch, create, delete worktrees.

## Lualine Config (`configs/lualine.lua`)

```lua
return {
  options = {
    theme = "auto",       -- follows colorscheme
    section_separators = { left = "", right = "" },
    component_separators = { left = "", right = "" },
  },
  sections = {
    lualine_a = { "mode" },
    lualine_b = { "branch", "diff", "diagnostics" },
    lualine_c = { "filename" },
    lualine_x = { "encoding", "fileformat", "filetype" },
    lualine_y = { "progress" },
    lualine_z = { "location" },
  },
  inactive_sections = {
    lualine_c = { "filename" },
    lualine_x = { "location" },
  },
}
```

solarized-osaka compatibility: set `theme = "auto"` and lualine reads colors from the active colorscheme.

## Init.lua Rewrite

```lua
vim.g.mapleader = ","
vim.g.maplocalleader = ","

-- bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({ "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  -- snacks.nvim (priority=1000, lazy=false)
  -- solarized-osaka.nvim (colorscheme)
  -- custom plugins (import "plugins")
}, require("configs.lazy"))

vim.cmd.colorscheme("solarized-osaka")
require("options")
require("autocmds")
require("mappings")
```

## Risks

- **solarized-osaka visual match**: NvChad base46 may render slightly different highlights than standalone colorscheme. Acceptable risk; `craftzdog/solarized-osaka.nvim` has extensive customization options.
- **git-worktree rewrite**: ~50 lines of new Lua. Tested after implementation.
- **noice.nvim without NvChad**: noice is standalone; just needs its own plugin spec. Low risk.
- **Key mapping muscle memory**: <leader>ch → <leader>sk, <leader>fo → <leader>fr are the biggest changes. User accepts this tradeoff.
