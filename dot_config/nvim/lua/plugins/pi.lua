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

local function prompt_win_visible()
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(w)].filetype == "pi-chat-prompt" then
      return true
    end
  end
  return false
end

-- pi.nvim considers the chat "visible" when only the history window exists,
-- so a manually closed prompt window is never recreated by pi.show().
-- Hide the partial layout and reopen it fresh.
local function ensure_full_chat(pi)
  -- In float mode the [No Name] base window must stay (it hosts the tab);
  -- only the side layout needs the cleanup to fill the whole tab.
  local function maybe_close_non_pi()
    if pi.layout() == "side" then
      vim.schedule(close_non_pi_windows)
    end
  end

  if not pi.is_visible() then
    pi.show()
    maybe_close_non_pi()
  elseif not prompt_win_visible() then
    pi.toggle_chat()
    pi.show()
    maybe_close_non_pi()
  end
end

local function toggle_pi()
  local pi = require "pi"
  local cur = vim.api.nvim_get_current_tabpage()

  if pi_tab and vim.api.nvim_tabpage_is_valid(pi_tab) then
    if cur == pi_tab then
      if pi.is_visible() then
        -- Keep the session alive; just switch back.
        leave_pi_tab()
      else
        -- Chat hidden via <C-g>t: <leader>ap brings the float back.
        ensure_full_chat(pi)
        pi.focus_chat_prompt()
      end
      return
    end
    prev_tab = cur
    vim.api.nvim_set_current_tabpage(pi_tab)
    ensure_full_chat(pi)
    pi.focus_chat_prompt()
    return
  end

  prev_tab = cur
  vim.cmd "tabnew"
  pi_tab = vim.api.nvim_get_current_tabpage()
  pi.show()
  vim.schedule(function()
    if pi.layout() == "side" then
      close_non_pi_windows()
    end
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
    opts = {
      -- Curated model list for <C-g>m (pi.select_model).
      models = { "k3", "kimi-for-coding", "deepseek-v4-pro", "qwen3.8-max-preview" },
      -- Render thinking blocks in chat history (default: hidden).
      show_thinking = true,
      -- Keep the startup block (skills/extensions/announcements) collapsed.
      expand_startup_details = false,
      -- Float layout: centered, bounded width for readable line lengths.
      -- Switch side/float on the fly with :PiToggleLayout.
      layout = {
        default = "float",
        float = { width = 120, height = 0.85, border = "rounded" },
      },
      -- Song-style status verb pairs { working, done }, replacing the
      -- built-in programmer jokes.
      verbs = {
        use_defaults = false,
        pairs = {
          { "研墨", "墨成" },
          { "运笔", "笔歇" },
          { "调釉", "釉匀" },
          { "入窑", "窑开" },
          { "烧造", "器成" },
          { "候火", "火温" },
          { "装裱", "裱成" },
          { "铺绢", "绢展" },
          { "题款", "款落" },
          { "钤印", "印定" },
          { "临帖", "帖就" },
          { "刻版", "版成" },
          { "点茶", "茶熟" },
          { "碾香", "香成" },
          { "洗笔", "笔净" },
          { "抚琴", "琴歇" },
          { "听雨", "雨霁" },
        },
      },
    },
    keys = {
      {
        "<leader>ap",
        toggle_pi,
        desc = "Toggle Pi",
      },
    },
    init = function()
      -- Left padding inside pi float/side windows: pi.nvim hardcodes
      -- signcolumn="no" at window open, so override it on the next tick.
      vim.api.nvim_create_autocmd("BufWinEnter", {
        group = vim.api.nvim_create_augroup("PiWindowPadding", { clear = true }),
        callback = function()
          local ft = vim.bo.filetype
          if ft == "pi-chat-history" or ft == "pi-chat-prompt" or ft == "pi-chat-attachments" then
            local win = vim.api.nvim_get_current_win()
            vim.schedule(function()
              if vim.api.nvim_win_is_valid(win) then
                vim.wo[win].signcolumn = "yes:1"
              end
            end)
          end
        end,
      })
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

          -- <C-g> prefix inside pi chat buffers (mirrors the pi TUI leader).
          -- s: resume session via telescope (vim.ui.select -> ui-select ext)
          -- n: new session, m: pick from the curated model list
          -- h/p: move focus between the history and prompt panels
          local leaders = {
            s = { function() require("pi").resume_session() end, "Pi: resume session" },
            n = { function() require("pi").new_session() end, "Pi: new session" },
            m = { function() require("pi").select_model() end, "Pi: select model" },
            h = { function() require("pi").focus_chat_history() end, "Pi: focus history" },
            p = { function() require("pi").focus_chat_prompt() end, "Pi: focus prompt" },
            t = { function() require("pi").toggle_chat() end, "Pi: hide/show chat float" },
          }
          for key, spec in pairs(leaders) do
            vim.keymap.set({ "n", "i" }, "<C-g>" .. key, spec[1], { buffer = args.buf, desc = spec[2] })
          end

          -- <C-k>/<C-j>: move up to history / down to prompt (float stack
          -- order: history on top, prompt below). Newline stays on <S-CR>.
          vim.keymap.set({ "n", "i" }, "<C-k>", function()
            require("pi").focus_chat_history()
          end, { buffer = args.buf, desc = "Pi: focus history" })
          vim.keymap.set({ "n", "i" }, "<C-j>", function()
            require("pi").focus_chat_prompt()
          end, { buffer = args.buf, desc = "Pi: focus prompt" })

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
