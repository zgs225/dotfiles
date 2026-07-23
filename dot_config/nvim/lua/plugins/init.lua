return {
  {
    "folke/which-key.nvim",
    lazy = false,
    config = function()
      require "configs.which-key"
    end,
  },

  {
    "akinsho/toggleterm.nvim",
    version = "*",
    keys = { "<c-\\>" },
    cmd = { "ToggleTerm", "TermSelect", "TermNew", "TermExec" },
    config = function()
      require("toggleterm").setup(require "configs.toggleterm")
    end,
  },

  {
    "tpope/vim-surround",
    event = "User FilePost",
  },

  {
    -- Route vim.ui.select through telescope (dropdown theme). Benefits
    -- pi.nvim's :PiResume session picker, LSP code actions, etc.
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-telescope/telescope-ui-select.nvim" },
    opts = function(_, opts)
      opts.extensions = opts.extensions or {}
      opts.extensions["ui-select"] = { require("telescope.themes").get_dropdown() }
      return opts
    end,
    config = function(_, opts)
      require("telescope").setup(opts)
      require("telescope").load_extension "ui-select"
    end,
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
    cmd = { "Mason", "MasonInstall", "MasonInstallAll", "MasonUpdate" },
    opts = function()
      return require "configs.mason"
    end,
  },

  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = {
      "williamboman/mason.nvim",
      "neovim/nvim-lspconfig",
    },
    event = "User FilePost",
    opts = function()
      return require "configs.mason-lspconfig"
    end,
  },

  {
    "elkowar/yuck.vim",
    ft = "yuck",
  },
}
