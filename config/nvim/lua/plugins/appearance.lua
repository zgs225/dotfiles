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
      for k, v in pairs(require "configs.nvimtree") do
        opts[k] = v
      end

      require("nvim-tree").setup(opts)
    end,
  },
  -- Code structure
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
  -- Display frame
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = {
      "MunifTanjim/nui.nvim",
      "rcarriga/nvim-notify",
    },
    config = function()
      require "configs.noice"
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
}
