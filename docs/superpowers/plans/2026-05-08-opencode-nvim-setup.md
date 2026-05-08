# Add opencode.nvim Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add opencode.nvim plugin with `<leader>aa` toggle keymap, matching claude-code.nvim window layout.

**Architecture:** Single lazy.nvim plugin spec inserted into `lua/plugins/devtools.lua`, alongside existing claude-code.nvim entry. Uses opencode.nvim's built-in terminal with right vertical split at 35% width. Auto-quits when opencode is the last window.

**Tech Stack:** lazy.nvim, opencode.nvim, plenary.nvim

---

### Task 1: Add opencode.nvim plugin spec

**Files:**
- Modify: `lua/plugins/devtools.lua:141` (insert after claude-code block, before gomodifytags block)

- [ ] **Step 1: Insert plugin spec**

Insert the following plugin spec block between line 141 (closing `},` of claude-code.nvim) and line 143 (start of gomodifytags block). The insertion goes after the blank line at line 142, right before line 143's `{`.

```lua
  -- OpenCode 集成
  {
    "nickjvandyke/opencode.nvim",
    version = "*",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>aa", function() require("opencode").toggle() end, { desc = "Toggle OpenCode" } },
    },
    init = function()
      -- 当 opencode 是唯一窗口时自动退出
      vim.api.nvim_create_autocmd("WinClosed", {
        callback = function()
          if #vim.api.nvim_list_wins() == 1 then
            local winid = vim.api.nvim_get_current_win()
            local bufnr = vim.api.nvim_win_get_buf(winid)
            if vim.api.nvim_buf_get_name(bufnr):match "^opencode" then
              vim.cmd "qa"
            end
          end
        end,
      })
    end,
    opts = {
      server = {
        start = function()
          require("opencode.terminal").open("opencode --port", {
            split = "right",
            width = math.floor(vim.o.columns * 0.35),
          })
        end,
        stop = function()
          require("opencode.terminal").close()
        end,
        toggle = function()
          require("opencode.terminal").toggle("opencode --port", {
            split = "right",
            width = math.floor(vim.o.columns * 0.35),
          })
        end,
      },
    },
  },
```

- [ ] **Step 2: Verify file syntax**

Run: `nvim --headless -c "luafile lua/plugins/devtools.lua" -c "q" 2>&1`
Expect: no errors or warnings.

- [ ] **Step 3: Commit**

```bash
git add lua/plugins/devtools.lua
git commit -m "feat(nvim): add opencode.nvim with <leader>aa toggle keymap"
```
