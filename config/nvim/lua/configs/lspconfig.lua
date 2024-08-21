-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md
local on_attach = require("nvchad.configs.lspconfig").on_attach
local on_init = require("nvchad.configs.lspconfig").on_init
local capabilities = require("nvchad.configs.lspconfig").capabilities

local lspconfig = require "lspconfig"
local servers = { "html", "cssls", "gopls", "bashls", "pyright", "tsserver" }

for _, lsp in ipairs(servers) do
  lspconfig[lsp].setup {
    on_attach = on_attach,
    on_init = on_init,
    capabilities = capabilities,
  }
end

-- yamlls
-- To use a schema for validation, there are two options:
--    1. Add a modeline to the file. A modeline is a comment of the form:
--    `# yaml-language-server: $schema=<urlToTheSchema|relativeFilePath|absoluteFilePath}>`
--    2. Associated a schema url, relative , or absolute path
-- Most schema files can found at https://www.schemastore.org/json/
lspconfig.yamlls.setup {
  settings = {
    yaml = {
      schemas = {
        ["https://json.schemastore.org/chart.json"] = "Chart.yaml",
        ["https://json.schemastore.org/chart-lock.json"] = "Chart.lock",
        ["https://json.schemastore.org/kustomization.json"] = "kustomization.yaml",
      },
    },
  },
}

--- rust
--- vim.lsp.set_log_level "debug"
lspconfig.rust_analyzer.setup {
  on_attach = function(client, bufnr)
    on_attach(client, bufnr)
    vim.lsp.inlay_hint.enable(true)
  end,
  on_init = on_init,
  capabilities = capabilities,
}

--- rust-protobuf-analyzer
vim.api.nvim_create_autocmd("FileType", {
  pattern = "proto",
  callback = function(args)
    vim.lsp.set_log_level "debug"
    vim.lsp.start {
      name = "rust-protobuf-analyzer",
      cmd = {
        "cargo",
        "run",
        "--package",
        "rust-protobuf-analyzer",
        "--manifest-path",
        "/Users/lucky/Development/Rust/rust-protobuf-analyzer/Cargo.toml",
      },
      cmd_env = { RPA_LOG = "debug", RUST_BACKTRACE = "full" },
      root_dir = vim.fs.root(args.buf, { ".git" }),
    }
  end,
})
