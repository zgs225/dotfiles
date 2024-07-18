return {
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    config = function()
      require "configs.conform"
    end,
  },

  {
    "neovim/nvim-lspconfig",
    event = "User FilePost",
    config = function()
      require("nvchad.configs.lspconfig").defaults()
      require "configs.lspconfig"
    end,
  },

  {
    "nvim-tree/nvim-tree.lua",
    cmd = { "NvimTreeToggle", "NvimTreeFocus" },
    opts = function()
      return require "nvchad.configs.nvimtree"
    end,
    config = function(_, opts)
      for k, v in pairs(require "configs.nvimtree") do
        opts[k] = v
      end

      require("nvim-tree").setup(opts)
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    event = { "BufReadPost", "BufNewFile" },
    cmd = { "TSInstall", "TSBufEnable", "TSBufDisable", "TSModuleInfo" },
    build = ":TSUpdate",
    opts = function()
      return require "configs.treesitter"
    end,
    config = function(_, opts)
      require("nvim-treesitter.configs").setup(opts)
    end,
  },

  {
    "hedyhli/outline.nvim",
    cmd = { "Outline", "OutlineOpen" },
    keys = {
      { "<F6>", "<cmd>Outline<CR>", desc = "Toggle outline" },
    },
    opts = {},
    config = function()
      require "configs.outline"
    end,
  },

  {
    "tpope/vim-surround",
    event = "User FilePost",
  },
  {
    "pbrisbin/vim-mkdir",
    event = "BufNewFile",
  },

  {
    "toppair/peek.nvim",
    ft = "markdown",
    build = "deno task --quiet build:fast",
    config = function()
      local peek = require "peek"

      peek.setup { app = "browser" }
      vim.api.nvim_create_user_command("MarkdownPreview", peek.open, { desc = "Markdown preview" })
      vim.api.nvim_create_user_command("MarkdownPreviewClose", peek.close, { desc = " Markdown close preview window" })
    end,
  },

  {
    "rcarriga/nvim-dap-ui",
    dependencies = {
      "mfussenegger/nvim-dap",
      "nvim-neotest/nvim-nio",
      "jay-babu/mason-nvim-dap.nvim",
      "williamboman/mason.nvim",
    },
    cmd = {
      "DapToggleBreakpoint",
      "DapContinue",
    },
    keys = {
      { "<F8>", "<cmd>DapContinue<CR>", { desc = "Debugger: Continue" } },
      { "<F9>", "<cmd>DapToggleBreakpoint<CR>", { desc = "Debugger: Toggle Breakpoint" } },
    },
    config = function()
      require "configs.dap"
    end,
  },
}
