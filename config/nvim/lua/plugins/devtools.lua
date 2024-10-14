return {
  -- 代码格式化
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    config = function()
      require "configs.conform"
    end,
  },
  -- LSP 配置
  {
    "neovim/nvim-lspconfig",
    event = "User FilePost",
    config = function()
      require("nvchad.configs.lspconfig").defaults()
      require "configs.lspconfig"
    end,
  },

  -- 语法解析
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

  -- DAP 调试
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

  -- 测试
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "antoinemadec/FixCursorHold.nvim",
      "nvim-treesitter/nvim-treesitter",
      "fredrikaverpil/neotest-golang",
    },

    cmd = {
      "TestNearest",
      "TestFile",
      "TestDebugNearest",
      "TestToggleSummaryPannel",
    },

    keys = {
      "<leader>tt",
      "<leader>tf",
      "<leader>td",
      "<leader>ts",
    },

    config = function()
      require "configs.neotest"
    end,
  },

  -- 代码诊断展示
  {
    "rachartier/tiny-inline-diagnostic.nvim",
    event = "User FilePost",
    config = function()
      vim.diagnostic.config { virtual_text = false }
      require("tiny-inline-diagnostic").setup()
    end,
  },
}
