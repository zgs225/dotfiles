return {
  {
    "rcarriga/nvim-notify",
    lazy = false,
    keys = {
      {
        "<leader>fn",
        function()
          require("telescope").load_extension("notify")
          require("telescope").extensions.notify.notify()
        end,
        desc = "Notification history",
      },
    },
    config = function()
      local notify = require("notify")
      notify.setup({
        timeout = 3000,
        max_width = 80,
        max_height = 20,
        background_colour = "#000000",
        render = "default",
        stages = "fade_in_slide_out",
        top_down = false,
      })
      vim.notify = notify
    end,
  },
}
