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

      -- Custom stages: bottom-left anchored (SW), slide-in from left
      local function stage_open(state)
        local m = state.message
        local w = math.min(m.width, vim.o.columns - 2)
        local h = math.min(m.height, vim.o.lines - 2)
        return {
          relative = "editor",
          anchor = "SW",
          width = w,
          height = h,
          row = vim.o.lines,
          col = -w,
          style = "minimal",
          border = "rounded",
          zindex = 50,
          noautocmd = true,
          opacity = 0,
        }
      end

      local function stage_slide_in(state, win)
        local m = state.message
        local h = math.min(m.height, vim.o.lines - 2)

        local row_offset = 0
        for _, open_win in ipairs(state.open_windows or {}) do
          if open_win ~= win then
            local cfg = vim.api.nvim_win_get_config(open_win)
            row_offset = row_offset + (cfg.height or h) + 1
          end
        end

        return {
          row = { vim.o.lines - row_offset, damping = 0.6 },
          col = { 0, damping = 0.6, frequency = 1 },
          opacity = { 100, damping = 0.6 },
        }
      end

      local function stage_timeout()
        return { time = true }
      end

      local function stage_slide_out(state, win)
        local cfg = vim.api.nvim_win_get_config(win)
        return {
          col = { -(cfg.width or state.message.width), damping = 0.6 },
          opacity = { 0, damping = 0.8 },
        }
      end

      notify.setup({
        timeout = 3000,
        max_width = 80,
        max_height = 20,
        background_colour = "#000000",
        render = "wrapped-default",
        top_down = false,
        stages = { stage_open, stage_slide_in, stage_timeout, stage_slide_out },
      })
      vim.notify = notify
    end,
  },
}
