-- blink.cmp configuration, following the official NvChad v3.0 recipe
-- (nvchad.blink.config) adapted for v2.5, plus the pi.nvim source.

-- base46's blink integration cache may not exist yet (e.g. first sync on a
-- new machine before base46 has rebuilt). Rebuild once, else fall back to
-- blink's default highlights instead of erroring out.
local blink_hl = vim.g.base46_cache .. "blink"
if not vim.uv.fs_stat(blink_hl) then
  pcall(function()
    require("base46").load_all_highlights()
  end)
end
if vim.uv.fs_stat(blink_hl) then
  dofile(blink_hl)
end

return {
  snippets = { preset = "luasnip" },
  cmdline = { enabled = true },
  appearance = { nerd_font_variant = "normal" },
  fuzzy = { implementation = "prefer_rust" },

  sources = {
    default = { "lsp", "snippets", "buffer", "path" },
    per_filetype = {
      -- pi.nvim's official blink source: auto-trigger on @ / .
      ["pi-chat-prompt"] = { "pi" },
    },
    providers = {
      pi = { name = "Pi", module = "pi.completion.blink" },
    },
  },

  keymap = {
    preset = "default",
    ["<CR>"] = { "accept", "fallback" },
    ["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
    ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
  },

  completion = {
    documentation = {
      auto_show = true,
      auto_show_delay_ms = 200,
      window = { border = "single" },
    },
    menu = require("configs.blink-menu").menu,
  },
}
