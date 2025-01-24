require("java").setup {
  jdtls = {
    version = "v1.43.0",
  },

  lombok = {
    version = "nightly",
  },

  -- load java test plugins
  java_test = {
    enable = true,
    version = "0.43.0",
  },

  -- load java debugger plugins
  java_debug_adapter = {
    enable = true,
    version = "0.58.1",
  },

  spring_boot_tools = {
    enable = true,
    version = "1.59.0",
  },
}

local on_attach = require("nvchad.configs.lspconfig").on_attach
local on_init = require("nvchad.configs.lspconfig").on_init
local capabilities = require("nvchad.configs.lspconfig").capabilities

require("lspconfig").jdtls.setup {
  on_attach = function(client, bufnr)
    on_attach(client, bufnr)
    -- use plugin to display diagnostic messages
    vim.diagnostic.config { virtual_text = false }

    vim.opt_local.tabstop = 4
    vim.opt_local.shiftwidth = 4

    if client.server_capabilities.inlayHintProvider then
      vim.lsp.buf.inlay_hints(bufnr, true)
    end
  end,
  on_init = on_init,
  capabilities = capabilities,
  settings = {
    java = {
      eclipse = {
        downloadSources = true, -- 启用下载源代码功能
      },
      implementationsCodeLens = {
        enabled = true, -- 启用实现的代码透镜
      },
      referencesCodeLens = {
        enabled = true, -- 启用引用的代码透镜
      },
      inlayHints = {
        parameterNames = {
          enabled = "all", -- 启用所有参数名称提示
        },
        typeHints = {
          enabled = true,
        },
      },
      saveActions = {
        organizeImports = true,
      },
      format = {
        enabled = true,
        settings = {
          profile = "GoogleStyle",
        },
      },
    },
  },
}
