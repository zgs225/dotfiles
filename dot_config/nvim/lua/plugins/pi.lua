-- pi.nvim: pi coding agent as a vertical split (side layout, 50% width).
--   <leader>ap  toggle the pi side panel in the current tab
--   <leader>aP  open pi in a new tab (also as a 50% vertical split)
-- The chat is a single global session; showing it somewhere recreates its
-- windows in the current tab, so it effectively follows the last request.

local function get_chat()
  local session = require("pi.sessions.manager").get()
  return session and session.chat or nil
end

-- True when the pi chat windows currently live in the active tabpage.
local function chat_in_current_tab()
  local chat = get_chat()
  if not chat or not chat:is_visible() then
    return false
  end
  local pwin = chat:prompt_win()
  if not pwin then
    return false
  end
  return vim.api.nvim_win_get_tabpage(pwin) == vim.api.nvim_get_current_tabpage()
end

-- (Re)create the side-layout windows in the current tab and focus the prompt.
local function show_pi_here(pi)
  local chat = get_chat()
  if chat then
    -- set_layout hides any existing windows and reopens them in the current
    -- tab, which is exactly the "bring pi here" behaviour we want.
    chat:set_layout "side"
  else
    pi.show { layout = "side" }
  end
  pi.focus_chat_prompt()
end

local function toggle_pi()
  local pi = require "pi"
  if chat_in_current_tab() then
    -- Keep the session alive; just hide the panels.
    get_chat():hide()
  else
    show_pi_here(pi)
  end
end

local function pi_new_tab()
  local pi = require "pi"
  vim.cmd "tabnew"
  show_pi_here(pi)
end

-- ---------------------------------------------------------------------------
-- Double-<Esc> abort confirm
-- ---------------------------------------------------------------------------

-- Double-<Esc> abort confirm state (shared across pi buffers).
local esc_armed = false
local esc_timer = nil

local function pi_is_busy()
  local chat = get_chat()
  if not chat then
    return false
  end
  return chat:is_streaming() or chat:is_compacting()
end

local function disarm_esc()
  esc_armed = false
  if esc_timer then
    vim.fn.timer_stop(esc_timer)
    esc_timer = nil
  end
end

-- First <Esc> arms and warns; a second <Esc> within the window aborts the turn.
local function esc_abort()
  if not pi_is_busy() then
    return -- idle: keep <Esc> a no-op, no misleading hint
  end
  if esc_armed then
    disarm_esc()
    require("pi").abort()
    return
  end
  esc_armed = true
  esc_timer = vim.fn.timer_start(1500, disarm_esc)
  vim.notify("再按一次 <Esc> 中断当前回合", vim.log.levels.WARN, {
    title = "π",
    id = "pi-esc-confirm",
    timeout = 1500,
  })
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
      -- Side layout: 50%-width vertical split on the right.
      -- Switch side/float on the fly with :PiToggleLayout.
      layout = {
        default = "side",
        side = { position = "right", width = 0.5 },
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
      {
        "<leader>aP",
        pi_new_tab,
        desc = "Pi (new tab)",
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
      -- too: <Esc><Esc> in normal mode aborts (double press to avoid mistaps),
      -- <C-c> while typing clears the draft.
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("PiBufferKeys", { clear = true }),
        pattern = { "pi-chat-history", "pi-chat-prompt" },
        callback = function(args)
          -- Abort the current turn with a double-<Esc> confirm (see esc_abort):
          -- a lone <Esc> in normal mode is too easy to hit by accident.
          vim.keymap.set("n", "<Esc>", esc_abort, {
            buffer = args.buf,
            desc = "Abort current pi turn (press <Esc> twice)",
          })

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

          -- <C-h>/<C-j>/<C-k>/<C-l>: standard window navigation, kept working
          -- inside pi buffers. pi auto-enters insert mode on the prompt, so
          -- bind insert mode too and drop back to normal mode before moving
          -- (same UX as the terminal-nav helper in mappings.lua). Panel focus
          -- stays available via <C-g>h (history) / <C-g>p (prompt).
          local function win_nav(dir)
            if vim.api.nvim_get_mode().mode ~= "n" then
              vim.cmd "stopinsert"
            end
            vim.cmd("wincmd " .. dir)
          end
          for _, dir in ipairs { "h", "j", "k", "l" } do
            vim.keymap.set({ "n", "i" }, "<C-" .. dir .. ">", function()
              win_nav(dir)
            end, { buffer = args.buf, desc = "Window " .. dir })
          end

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
