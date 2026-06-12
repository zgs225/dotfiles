return {
  -- File explorer
  {
    "nvim-tree/nvim-tree.lua",
    cmd = { "NvimTreeToggle", "NvimTreeFocus" },
    opts = function()
      return require "nvchad.configs.nvimtree"
    end,
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function(_, opts)
      dofile(vim.g.base46_cache .. "nvimtree")

      for k, v in pairs(require "configs.nvimtree") do
        opts[k] = v
      end

      require("nvim-tree").setup(opts)
    end,
  },
  -- Code structure
  {
    "stevearc/aerial.nvim",
    cmd = { "AerialToggle" },
    keys = {
      { "<F6>", "<cmd>AerialToggle!<CR>", desc = "Toggle outline" },
    },
    -- Optional dependencies
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      require "configs.aerial"
    end,
  },
  -- Breadcrumbs
  {
    "Bekaboo/dropbar.nvim",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = {
      "nvim-telescope/telescope-fzf-native.nvim",
    },
    config = function()
      require "configs.dropbar"
    end,
  },
  {
    "stevearc/dressing.nvim",
    event = "VeryLazy",
    config = function()
      require("dressing").setup()
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter-context",
    event = "User FilePost",
    cmd = { "TSContextEnable", "TSContextDisable", "TSContextToggle" },
    config = function()
      require("treesitter-context").setup()
    end,
  },
  -- TODO
  {
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    event = "BufReadPre",
    keys = {
      {
        "]t",
        function()
          require("todo-comments").jump_next()
        end,
        desc = "Next todo comment",
      },
      {
        "[t",
        function()
          require("todo-comments").jump_prev()
        end,
        desc = "Previous todo comment",
      },
    },
    opts = {},
  },
}
