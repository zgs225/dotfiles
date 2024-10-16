-- https://github.com/folke/noice.nvim
require("noice").setup {
  lsp = {
    -- override markdown rendering so that **cmp** and other plugins use **Treesitter**
    override = {
      ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
      ["vim.lsp.util.stylize_markdown"] = true,
      ["cmp.entry.get_documentation"] = true, -- requires hrsh7th/nvim-cmp
    },

    signature = {
      enabled = false,
    },

    hover = {
      enabled = true,
    },
  },

  routes = {
    {
      filter = {
        event = "msg_show",
        any = {
          { find = "written" },
          { find = "no parser for" },
        },
      },
      opts = { skip = true },
    },
    {
      filter = {
        event = "notify",
        kind = "info",
        find = "was properly",
      },
      opts = { skip = true },
    },
    {
      filter = {
        event = "notify",
        kind = "error",
        any = {
          { find = "rust_analyzer: -32603" },
        },
      },
      view = "mini",
    },
    { -- send annoying msgs to mini
      filter = {
        event = "msg_show",
        any = {
          { find = "; after #%d+" },
          { find = "; before #%d+" },
          { find = "fewer lines" },
        },
      },
      view = "mini",
    },
  },

  -- you can enable a preset for easier configuration
  presets = {
    bottom_search = true, -- use a classic bottom cmdline for search
    command_palette = true, -- position the cmdline and popupmenu together
    long_message_to_split = true, -- long messages will be sent to a split
    inc_rename = false, -- enables an input dialog for inc-rename.nvim
    lsp_doc_border = false, -- add a border to hover docs and signature help
  },
}
