return {
  {
    "SUSTech-data/neopyter",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "AbaoFromCUG/websocket.nvim",
    },
    opts = {
      mode = "direct",
      remote_address = "127.0.0.1:9093",
      file_pattern = { "*.ju.*" },
      on_attach = function(bufnr)
        -- do some buffer keymap
      end,
    },
  },
}
