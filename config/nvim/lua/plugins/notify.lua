return {
  {
    "rcarriga/nvim-notify",
    lazy = false,
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
      vim.schedule(function()
        pcall(require("telescope"), "load_extension", "notify")
      end)
    end,
  },
}
