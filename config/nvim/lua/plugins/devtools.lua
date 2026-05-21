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
    lazy = false,
    build = ":TSUpdate",
    opts = function()
      return require "configs.treesitter"
    end,
    config = function(_, opts)
      dofile(vim.g.base46_cache .. "treesitter")
      require("nvim-treesitter").setup(opts)
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
      "theHamsta/nvim-dap-virtual-text",
      "leoluz/nvim-dap-go",
    },
    cmd = {
      "DapContinue",
      "DapToggleBreakpoint",
    },
    keys = {
      { "<leader>dc", function() require("dap").continue() end, { desc = "DAP: Continue" } },
      { "<leader>db", function() require("dap").toggle_breakpoint() end, { desc = "DAP: Toggle Breakpoint" } },
      {
        "<leader>dB",
        function()
          local condition = vim.fn.input("Breakpoint condition: ")
          if condition ~= "" then
            require("dap").set_breakpoint(condition)
          end
        end,
        { desc = "DAP: Conditional Breakpoint" },
      },
      { "<leader>du", function() require("dapui").toggle() end, { desc = "DAP: Toggle UI" } },
      { "<leader>dr", function() require("dap").restart() end, { desc = "DAP: Restart Session" } },
      { "<leader>dt", function() require("dap").terminate() end, { desc = "DAP: Terminate Session" } },
      { "<leader>do", function() require("dap").step_over() end, { desc = "DAP: Step Over" } },
      { "<leader>di", function() require("dap").step_into() end, { desc = "DAP: Step Into" } },
      { "<leader>dO", function() require("dap").step_out() end, { desc = "DAP: Step Out" } },
      { "<leader>dR", function() require("dap").run_to_cursor() end, { desc = "DAP: Run to Cursor" } },
      { "<leader>dh", function() require("dap.ui.widgets").hover() end, { desc = "DAP: Evaluate/Hover" } },
    },
    config = function()
      dofile(vim.g.base46_cache .. "dap")
      require "configs.debug"
    end,
  },

  -- 测试
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
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
        "<leader>as",
        function()
          require("opencode").select_server()
        end,
        { desc = "OpenCode select server" },
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
              width = math.floor(vim.o.columns * 0.45),
            })
          end,
          toggle = function()
            require("opencode.terminal").toggle("opencode --port", {
              split = "right",
              width = math.floor(vim.o.columns * 0.45),
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

  -- Git worktree 管理
  {
    "ThePrimeagen/git-worktree.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      -- 列出并切换/删除 worktree
      {
        "<leader>gw",
        function()
          require("telescope").extensions.git_worktree.git_worktrees()
        end,
        desc = "Git worktree list/switch/delete",
      },
      -- 创建新的 worktree
      {
        "<leader>gW",
        function()
          require("telescope").extensions.git_worktree.create_git_worktree()
        end,
        desc = "Git worktree create",
      },
    },
    config = function()
      local Worktree = require "git-worktree"

      Worktree.setup {
        -- 切换 worktree 时使用的目录变更命令
        -- "cd" 为全局, "tcd" 为仅当前 tab, "lcd" 为仅当前窗口
        change_directory_command = "cd",
        -- 切换 worktree 时自动更新当前 buffer 指向新工作树中的文件
        update_on_change = true,
        -- 如果当前文件在新 worktree 中不存在, 执行此命令
        update_on_change_command = "e .",
        -- 切换分支时清除 jumplist, 防止跳回其他分支的文件
        clearjumps_on_change = true,
        -- 创建 worktree 时自动 push 分支并 rebase (建议保持 false)
        autopush = false,
      }

      -- 注册 telescope 扩展
      require("telescope").load_extension "git_worktree"

      -- Hook: 切换 worktree 后的回调
      Worktree.on_tree_change(function(op, metadata)
        if op == Worktree.Operations.Switch then
          vim.notify(
            string.format("Switched worktree: %s -> %s", metadata.prev_path, metadata.path),
            vim.log.levels.INFO,
            { title = "Git Worktree" }
          )

          -- 终止 DAP 调试会话并清除所有断点
          pcall(function()
            local dap = require "dap"
            dap.clear_breakpoints()
            if dap.session() then
              dap.close()
            end
          end)

          -- 自动更新 nvim-tree 根目录到新 worktree
          local ok, api = pcall(require, "nvim-tree.api")
          if ok then
            api.tree.change_root(metadata.path)
          end
        elseif op == Worktree.Operations.Create then
          vim.notify(
            string.format("Created worktree: %s (branch: %s)", metadata.path, metadata.branch),
            vim.log.levels.INFO,
            { title = "Git Worktree" }
          )
        elseif op == Worktree.Operations.Delete then
          vim.notify(
            string.format("Deleted worktree: %s", metadata.path),
            vim.log.levels.INFO,
            { title = "Git Worktree" }
          )
        end
      end)
    end,
  },
}
