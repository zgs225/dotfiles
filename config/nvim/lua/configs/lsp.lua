-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md
require("nvchad.configs.lspconfig").defaults()

local keymap = vim.keymap.set
local opts = { noremap = true, silent = true }

local on_attach = require("nvchad.configs.lspconfig").on_attach
local on_init = require("nvchad.configs.lspconfig").on_init
local capabilities = require("nvchad.configs.lspconfig").capabilities

local servers = { "html", "cssls", "gopls", "bashls", "basedpyright", "ts_ls", "yamlls", "astro", "tailwindcss" }
local lsp_settings = {
  gopls = {
    hints = {
      compositeLiteralFields = true,
      constantValues = true,
      parameterNames = true,
      assignVariableTypes = true,
      functionTypeParameters = true,
      rangeVariableTypes = true,
    },

    codelenses = {
      test = true,
    },
  },

  basedpyright = {
    ["analysis.inlayHints.genericTypes"] = true,
  },

  -- yamlls
  -- To use a schema for validation, there are two options:
  --    1. Add a modeline to the file. A modeline is a comment of the form:
  --    `# yaml-language-server: $schema=<urlToTheSchema|relativeFilePath|absoluteFilePath}>`
  --    2. Associated a schema url, relative , or absolute path
  -- Most schema files can found at https://www.schemastore.org/json/
  yamlls = {
    schemas = {
      ["https://json.schemastore.org/chart.json"] = "Chart.yaml",
      ["https://json.schemastore.org/chart-lock.json"] = "Chart.lock",
      ["https://json.schemastore.org/kustomization.json"] = "kustomization.yaml",
      ["https://gitlab.com/gitlab-org/gitlab/-/raw/master/app/assets/javascripts/editor/schema/ci.json"] = ".gitlab-ci.yml",
    },
  },
}

for _, lsp in ipairs(servers) do
  local settings = lsp_settings[lsp]

  vim.lsp.config(lsp, {
    on_attach = function(client, bufnr)
      on_attach(client, bufnr)
      -- use plugin to display diagnostic messages
      vim.diagnostic.config { virtual_text = false }
      vim.lsp.inlay_hint.enable(true)

      keymap("n", "<leader>ca", vim.lsp.buf.code_action, opts)
      keymap("v", "<leader>ca", vim.lsp.buf.code_action, opts)
    end,
    on_init = on_init,
    capabilities = capabilities,
    settings = {
      [lsp] = settings,
    },
  })

  vim.lsp.enable(lsp)
end

--- rust
--- vim.lsp.set_log_level "debug"
vim.lsp.config("rust_analyzer", {
  on_attach = function(client, bufnr)
    on_attach(client, bufnr)
    vim.lsp.inlay_hint.enable(true)
  end,
  on_init = on_init,
  capabilities = capabilities,
})

-- rust-protobuf-analyzer
vim.api.nvim_create_autocmd("FileType", {
  pattern = "proto",
  callback = function(args)
    local cargo_file = vim.fn.expand "~" .. "/Workspace/Development/Rust/rust-protobuf-analyzer/Cargo.toml"
    vim.lsp.set_log_level "debug"
    vim.lsp.start {
      name = "rust-protobuf-analyzer",
      cmd = {
        "cargo",
        "run",
        "--package",
        "rust-protobuf-analyzer",
        "--manifest-path",
        cargo_file,
      },
      cmd_env = { RPA_LOG = "debug", RUST_BACKTRACE = "full" },
      root_dir = vim.fs.root(args.buf, { ".git" }),
    }
  end,
})
