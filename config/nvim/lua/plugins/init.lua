return {
  {
    "tpope/vim-surround",
    event = "User FilePost",
  },

  {
    "pbrisbin/vim-mkdir",
    event = "BufNewFile",
  },

  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = "markdown",
    cmd = { "RenderMarkdown" },
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    opts = {
      file_types = { "markdown" },
    },
  },

  {
    "williamboman/mason.nvim",
    version = "1.11.0",
    cmd = { "Mason", "MasonInstall", "MasonInstallAll", "MasonUpdate" },
    opts = function()
      return require "configs.mason"
    end,
  },
}
