# Terminal Window Navigation with Ctrl+hjkl Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `t` (terminal) mode keymaps so `<C-h/j/k/l>` switch Neovim windows directly from terminal mode without pressing `<C-x>` first.

**Architecture:** Four global `t` mode keymaps added to `lua/mappings.lua`, each combining `<C-\><C-n>` (exit terminal mode) with `<C-w>` window navigation. No new files, no new dependencies.

**Tech Stack:** Neovim Lua API (`vim.keymap.set`)

---

### Task 1: Add terminal-mode window-switching keymaps

**Files:**
- Modify: `config/nvim/lua/mappings.lua` (append 4 lines at end)

- [ ] **Step 1: Add the `t` mode mappings**

Append after line 23 in `config/nvim/lua/mappings.lua`:

```lua
-- Terminal mode window navigation
map("t", "<C-h>", "<C-\\><C-n><C-w>h", { desc = "terminal switch window left" })
map("t", "<C-l>", "<C-\\><C-n><C-w>l", { desc = "terminal switch window right" })
map("t", "<C-j>", "<C-\\><C-n><C-w>j", { desc = "terminal switch window down" })
map("t", "<C-k>", "<C-\\><C-n><C-w>k", { desc = "terminal switch window up" })
```

- [ ] **Step 2: Verify the file loads without errors**

Run: `nvim --headless -c "lua require('mappings')" -c "qa" 2>&1`
Expected: No Lua errors.

- [ ] **Step 3: Commit**

```bash
git add config/nvim/lua/mappings.lua
git commit -m "feat: add Ctrl+hjkl window navigation in terminal mode"
```
