-- pi.nvim: pi coding agent in a dedicated tab, toggled with <leader>ap.
-- Mirrors the opencode toggle UX: first press opens a tab with the chat
-- filling the whole tab, pressing again switches back to the previous tab
-- (session stays alive), pressing once more jumps back in.

local pi_tab = nil
local prev_tab = nil

local pi_filetypes = {
  ["pi-chat-history"] = true,
  ["pi-chat-prompt"] = true,
  ["pi-chat-attachments"] = true,
}

-- Close leftover non-pi windows (e.g. the [No Name] buffer from :tabnew)
-- so the chat panels fill the entire tab.
local function close_non_pi_windows()
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(w)
    if not pi_filetypes[vim.bo[buf].filetype] then
      pcall(vim.api.nvim_win_close, w, true)
    end
  end
end

local function leave_pi_tab()
  if prev_tab and prev_tab ~= pi_tab and vim.api.nvim_tabpage_is_valid(prev_tab) then
    vim.api.nvim_set_current_tabpage(prev_tab)
  elseif #vim.api.nvim_list_tabpages() > 1 then
    vim.cmd "tabprevious"
  else
    vim.cmd "tabnew"
  end
end

local function toggle_pi()
  local pi = require "pi"
  local cur = vim.api.nvim_get_current_tabpage()

  if pi_tab and vim.api.nvim_tabpage_is_valid(pi_tab) then
    if cur == pi_tab then
      -- Keep the session alive; just switch back.
      leave_pi_tab()
      return
    end
    prev_tab = cur
    vim.api.nvim_set_current_tabpage(pi_tab)
    if not pi.is_visible() then
      pi.show()
      vim.schedule(close_non_pi_windows)
    end
    pi.focus_chat_prompt()
    return
  end

  prev_tab = cur
  vim.cmd "tabnew"
  pi_tab = vim.api.nvim_get_current_tabpage()
  pi.show()
  vim.schedule(function()
    close_non_pi_windows()
    pi.focus_chat_prompt()
  end)
end

return {
  {
    "alex35mil/pi.nvim",
    dependencies = {
      -- Required only for :PiPasteImage (clipboard image paste).
      { "HakonHarnes/img-clip.nvim", opts = {} },
    },
    opts = {},
    keys = {
      {
        "<leader>ap",
        toggle_pi,
        desc = "Toggle Pi",
      },
    },
    init = function()
      -- Abort the current agent turn, matching the opencode terminal mapping.
      -- NOTE: in side layout pi.nvim auto-redirects focus from the history
      -- window to the prompt, so the binding must live on the prompt buffer
      -- too: <Esc> in normal mode aborts, <C-c> while typing clears the draft.
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("PiBufferKeys", { clear = true }),
        pattern = { "pi-chat-history", "pi-chat-prompt" },
        callback = function(args)
          local abort = function()
            require("pi").abort()
          end
          vim.keymap.set("n", "<Esc>", abort, { buffer = args.buf, desc = "Abort current pi turn" })
          if vim.bo[args.buf].filetype == "pi-chat-prompt" then
            -- Clear the draft while typing; stays in insert mode.
            vim.keymap.set("i", "<C-c>", function()
              vim.api.nvim_buf_set_lines(args.buf, 0, -1, false, { "" })
              vim.api.nvim_win_set_cursor(0, { 1, 0 })
            end, { buffer = args.buf, desc = "Clear pi prompt" })
          end
        end,
      })
    end,
  },
}
