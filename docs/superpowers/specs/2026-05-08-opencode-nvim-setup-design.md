# Design: Add opencode.nvim Plugin

## Goal

Install [opencode.nvim](https://github.com/nickjvandyke/opencode.nvim) with `<leader>aa` mapped to toggle the opencode terminal, matching the claude-code.nvim window behavior.

## Scope

Add a new plugin spec to `lua/plugins/devtools.lua`. Keep existing `claude-code.nvim` configuration unchanged.

## Requirements

1. `<leader>aa` toggles the opencode terminal window (open/close)
2. Window layout: vertical split on the right, 35% width (same as claude-code: `position = "vertical", split_ratio = 0.35`)
3. Auto-quit: when the opencode terminal is the last remaining window, run `:qa` (same behavior as claude-code)

## Architecture

- **Plugin manager**: lazy.nvim (already in use)
- **Dependencies**: `nvim-lua/plenary.nvim` (already installed)
- **Terminal**: opencode.nvim's built-in terminal (`require("opencode.terminal")`), no snacks.nvim dependency needed

## Configuration

```lua
{
  "nickjvandyke/opencode.nvim",
  version = "*",
  dependencies = { "nvim-lua/plenary.nvim" },
  cmd = { "Opencode", "OpencodeVersion" },
  keys = {
    { "<leader>aa", function() require("opencode").toggle() end, { desc = "Toggle OpenCode" } },
  },
  init = function()
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
}
```

## Notes

- opencode.nvim's default terminal config already uses the same layout as claude-code.nvim (right split, 35% width)
- `autoread = true` is recommended by opencode.nvim docs for `events.reload` but not strictly needed for basic usage; can be added later if desired
- The `opts` override the defaults explicitly to ensure the window behavior matches claude-code exactly even if defaults change in future versions
