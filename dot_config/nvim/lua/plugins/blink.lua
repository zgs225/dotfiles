-- blink.cmp as the completion engine, replacing NvChad's nvim-cmp stack.
-- Follows the official NvChad v3.0 recipe (nvchad.blink.lazyspec, BETA)
-- adapted for v2.5. When upgrading to NvChad v3.0, replace this file with
-- { import = "nvchad.blink.lazyspec" }.

return {
  { "hrsh7th/nvim-cmp", enabled = false },

  {
    "saghen/blink.cmp",
    version = "1.*",
    event = { "InsertEnter", "CmdlineEnter" },

    dependencies = {
      "rafamadriz/friendly-snippets",
      {
        -- snippet plugin
        "L3MON4D3/LuaSnip",
        dependencies = "rafamadriz/friendly-snippets",
        opts = { history = true, updateevents = "TextChanged,TextChangedI" },
        config = function(_, opts)
          require("luasnip").config.set_config(opts)
          require "nvchad.configs.luasnip"
        end,
      },

      {
        "windwp/nvim-autopairs",
        opts = {
          fast_wrap = {},
          disable_filetype = { "TelescopePrompt", "vim" },
        },
        -- v2.5's NvChad spec wires autopairs into cmp's confirm_done event;
        -- that hook breaks without cmp, so override with a clean config.
        -- blink's auto_brackets (enabled by default) covers function-call
        -- bracket completion instead.
        config = function(_, opts)
          require("nvim-autopairs").setup(opts)
        end,
      },
    },

    opts_extend = { "sources.default" },

    opts = function()
      return require "configs.blink"
    end,
  },
}
