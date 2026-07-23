-- blink.cmp configuration, following the official NvChad v3.0 recipe
-- (nvchad.blink.config) adapted for v2.5, plus the pi.nvim source.

dofile(vim.g.base46_cache .. "blink")

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
