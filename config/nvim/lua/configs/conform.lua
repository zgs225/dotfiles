local options = {
  formatters_by_ft = {
    lua = { "stylua" },
    go = { "goimports", "gofumpt", "golines" },
    css = { "prettier" },
    html = { "prettier" },
    javascript = { "prettier" },
    typescript = { "prettier" },
    python = { "isort", "black" },
    rust = { "rustfmt" },
    proto = { "buf" },
  },

  format_on_save = {
    -- These options will be passed to conform.format()
    timeout_ms = 500,
    lsp_fallback = true,
  },
}

require("conform").setup(options)
