return {
  -- 代码格式化
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    config = function()
      require "configs.conform"
    end,
  },
  {
    "nvim-java/nvim-java",
    ft = "java",
    keys = {
      "JavaBuildBuildWorkspace",
      "JavaBuildCleanWorkspace",
      "JavaRunnerRunMain",
      "JavaSettingsChangeRuntime",
    },
    config = function()
      require "configs.java"
    end,
  },
  -- LSP 配置
  {
    "neovim/nvim-lspconfig",
    event = "User FilePost",
    config = function()
      require("nvchad.configs.lspconfig").defaults()
      require "configs.lsp"
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
      dofile(vim.g.base46_cache .. "treesitter")
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
      dofile(vim.g.base46_cache .. "dap")
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
      {
        "fredrikaverpil/neotest-golang",
        dependencies = {
          "leoluz/nvim-dap-go",
        },
      },
    },

    cmd = {
      "TestNearest",
      "TestFile",
      "TestDebugNearest",
      "TestToggleSummaryPannel",
    },

    keys = {
      { "<leader>tt", "<cmd>TestNearest<CR>", { desc = "Test Nearest" } },
      { "<leader>tf", "<cmd>TestFile<CR>", { desc = "Test File" } },
      { "<leader>td", "<cmd>TestDebugNearest<CR>", { desc = "Test Debug nearest" } },
      { "<leader>ts", "<cmd>TestToggleSummaryPannel<CR>", { desc = "Test Toggle summary pannel" } },
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
      require("tiny-inline-diagnostic").setup()
    end,
  },

  -- Claude Code 集成
  {
    "greggh/claude-code.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = { "ClaudeCode", "ClaudeCodeVersion" },
    keys = {
      { "<leader>cc", "<cmd>ClaudeCode<CR>", { desc = "Toggle Claude Code" } },
    },
    init = function()
      -- 当 Claude Code 是唯一窗口时自动退出
      vim.api.nvim_create_autocmd("WinClosed", {
        callback = function()
          if #vim.api.nvim_list_wins() == 1 then
            local winid = vim.api.nvim_get_current_win()
            local bufnr = vim.api.nvim_win_get_buf(winid)
            if vim.api.nvim_buf_get_name(bufnr):match "^Claude Code" then
              vim.cmd "qa"
            end
          end
        end,
      })
    end,
    opts = {
      window = { position = "vertical", split_ratio = 0.40 },
      refresh = { enable = true, updatetime = 100 },
    },
  },

  -- OpenCode 集成
  {
    "nickjvandyke/opencode.nvim",
    version = "*",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      {
        "<leader>aa",
        function()
          require("opencode").toggle()
        end,
        { desc = "Toggle OpenCode" },
      },
      {
        "<leader>aA",
        function()
          require("opencode").ask("@this: ", { submit = true })
        end,
        mode = { "n", "x" },
        { desc = "Ask opencode" },
      },
    },
    init = function()
      vim.g.opencode_opts = {
        server = {
          start = function()
            require("opencode.terminal").open("opencode --port", {
              split = "right",
              width = math.floor(vim.o.columns * 0.40),
            })
          end,
          toggle = function()
            require("opencode.terminal").toggle("opencode --port", {
              split = "right",
              width = math.floor(vim.o.columns * 0.40),
            })
          end,
        },
      }
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
  },

  {
    "zgs225/gomodifytags.nvim",
    cmd = { "GoAddTags", "GoRemoveTags", "GoInstallModifyTagsBin" },
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
    },
    config = function()
      require("gomodifytags").setup()
    end,
  },
}
