# Terminal Window Navigation with Ctrl+hjkl

Date: 2026-05-08

## Goal

Allow `<C-h>`, `<C-j>`, `<C-k>`, `<C-l>` to switch between Neovim windows while in terminal mode (`t`), without first pressing `<C-x>` to exit terminal input mode.

## Background

Currently, Neovim terminal buffers (NvChad terminal, OpenCode, Claude Code) are in terminal mode (`t`), which sends all keystrokes to the terminal's running program. The existing `<C-x>` mapping (`<C-\><C-n>`) exits terminal mode into normal mode, after which the existing normal-mode `<C-h/j/k/l>` window-switching mappings work. The goal is to skip the intermediate step.

## Design

Add global `t` (terminal) mode keymaps in `lua/mappings.lua`:

```lua
map("t", "<C-h>", "<C-\\><C-n><C-w>h", { desc = "terminal switch window left" })
map("t", "<C-l>", "<C-\\><C-n><C-w>l", { desc = "terminal switch window right" })
map("t", "<C-j>", "<C-\\><C-n><C-w>j", { desc = "terminal switch window down" })
map("t", "<C-k>", "<C-\\><C-n><C-w>k", { desc = "terminal switch window up" })
```

Each mapping: exit terminal mode → perform window switch.

## Scope

- Affects all terminal buffers globally (NvChad terminal, OpenCode, Claude Code, etc.)
- Does NOT affect normal insert mode (`i`) — `<C-h/j/k/l>` remain bound to cursor movement there
- The existing `<C-x>` terminal escape mapping is preserved

## File Changed

`config/nvim/lua/mappings.lua` — add 4 lines in the terminal section after the existing `<C-x>` mapping.
