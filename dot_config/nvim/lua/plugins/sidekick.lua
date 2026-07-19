return {
  {
    "folke/sidekick.nvim",
    opts = {
      nes = { enabled = false },
      cli = {
        win = {
          split = {
            width = 0.5,
          },
        },
        mux = {
          enabled = true,
          backend = "tmux",
          create = "terminal",
        },
        tools = {
          opencode = {
            keys = {
              files = false,
              buffers = false,
              scroll_page_down = { "<c-u>", "<pagedown>" },
              scroll_page_up = { "<c-d>", "<pageup>" },
            },
          },
          kimi = {
            cmd = { "kimi", "-y" },
          },
        },
      },
    },
    keys = {
      {
        "<leader>aa",
        function()
          require("sidekick.cli").toggle()
        end,
        desc = "AI Toggle",
      },
      {
        "<leader>as",
        function()
          require("sidekick.cli").select()
        end,
        desc = "AI Select Tool",
      },
      {
        "<leader>ao",
        function()
          require("sidekick.cli").toggle { name = "opencode", focus = true }
        end,
        desc = "AI OpenCode",
      },
      {
        "<leader>ak",
        function()
          require("sidekick.cli").toggle { name = "kimi", focus = true }
        end,
        desc = "AI Kimi Code",
      },
      {
        "<leader>at",
        function()
          require("sidekick.cli").send { msg = "{this}" }
        end,
        mode = { "n", "x" },
        desc = "AI Send This",
      },
      {
        "<leader>af",
        function()
          require("sidekick.cli").send { msg = "{file}" }
        end,
        desc = "AI Send File",
      },
      {
        "<leader>ap",
        function()
          require("sidekick.cli").prompt()
        end,
        mode = { "n", "x" },
        desc = "AI Select Prompt",
      },
      {
        "<leader>ad",
        function()
          require("sidekick.cli").close()
        end,
        desc = "AI Detach Session",
      },
      {
        "<c-.>",
        function()
          require("sidekick.cli").focus()
        end,
        mode = { "n", "t", "i" },
        desc = "AI Focus CLI",
      },
    },
  },
}
