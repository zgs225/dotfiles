-- pi.nvim: pi coding agent as a vertical split (side layout, 60% width).
--   <leader>ap  toggle the pi side panel in the current tab
--   <leader>aP  open pi in a new tab (also as a 60% vertical split)
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

return {
  {
    "https://github.com/zgs225/pi2.nvim.git",
    -- Dev escape hatch: point lazy at a feature worktree by launching nvim
    -- with PI_DEV_DIR set (nil = normal installed path). See pi.nvim G23.
    dir = vim.env.PI_DEV_DIR or nil,
    dependencies = {
      -- Required only for :PiPasteImage (clipboard image paste); π uses just
      -- its clipboard module. Disable img-clip's own drag-and-drop vim.paste
      -- override: it treats every short text paste in terminal mode as a
      -- potential image drop and warns "Content is not an image." π handles
      -- prompt drag-and-drop itself, so this global hook is pure noise.
      -- NB: must nest under `default` — img-clip resolves `default.<key>`
      -- before the unscoped top level, so a flat `drag_and_drop` is shadowed.
      { "HakonHarnes/img-clip.nvim", opts = { default = { drag_and_drop = { enabled = false } } } },
    },
    opts = {
      -- Curated model list for <C-g>m (pi.select_model). Without this the
      -- picker falls back to the backend's full model list (get_available_models
      -- ignores pi's enabledModels setting), so we keep an explicit shortlist.
      -- Provider-qualified first entry pins the default (opencode-go/deepseek-v4-flash);
      -- bare IDs still match every provider copy in the picker.
      models = { "opencode-go/deepseek-v4-flash", "k3", "kimi-for-coding", "deepseek-v4-pro", "deepseek-v4-flash", "qwen3.8-max", "k3-256k" },
      -- Vision fallback: when the current main model cannot see images,
      -- attachments are described by this vision-capable model first and the
      -- description replaces the images (pi.nvim feat/vision-fallback).
      vision = { model = "kimi-coding/kimi-for-coding", status_message = "描影…" },
      title = {
        enabled = true,
        max_chars = 20,
        model = "opencode-go/deepseek-v4-flash",
      },
      -- Render thinking blocks in chat history (default: hidden).
      show_thinking = true,
      -- Keep the startup block (skills/extensions/announcements) collapsed.
      expand_startup_details = false,
      -- Double-<Esc> aborts the running turn (native pi.nvim feature; replaces
      -- the old hand-rolled esc_abort confirm). First <Esc> shows a gentle
      -- command-line hint, a second within `timeout` ms aborts (:PiAbort).
      abort = { enabled = true, timeout = 1500, message = "再按一次 <Esc> 中断当前回合" },
      -- Richer markdown rendering of the chat history via render-markdown.nvim
      -- (already installed). Falls back to pi's builtin renderer if absent.
      render = { engine = "render-markdown" },
      -- Sessions overview (:PiSessions): live list of all active sessions.
      -- auto_open shows it together with the chat; mode "follow" mirrors the
      -- tab's chat layout (side here), pinned to the left edge like the chat.
      sessions_list = { auto_open = true },
      -- Side layout: 60%-width vertical split on the left (position = "left"
      -- is honored natively by pi.nvim now). Switch side/float on the fly
      -- with :PiToggleLayout.
      layout = {
        default = "side",
        side = { position = "left", width = 0.6 },
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
      -- Extra buffer-local keys for the pi chat panels: a <C-g> leader prefix
      -- (session/model/panel actions), <C-h/j/k/l> window navigation, and
      -- <C-c> to clear the draft while typing. (Double-<Esc> abort is native
      -- to pi.nvim now — see the `abort` option — so it is not bound here.)
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("PiBufferKeys", { clear = true }),
        pattern = { "pi-chat-history", "pi-chat-prompt" },
        callback = function(args)
          -- NOTE: double-<Esc> to abort is now provided natively by pi.nvim
          -- (see the `abort` option above), so no local <Esc> mapping is needed
          -- here. The native version also works from insert mode on the prompt.

          -- <C-g> prefix inside pi chat buffers (mirrors the pi TUI leader).
          -- s: resume session via telescope (vim.ui.select -> ui-select ext)
          -- n: new session, m: pick from the curated model list, M: all models
          -- h/p: move focus between the history and prompt panels
          -- c: open pi in a new tab (same as <leader>aP)
          local leaders = {
            s = { function() require("pi").resume_session() end, "Pi: resume session" },
            n = { function() require("pi").new_session() end, "Pi: new session" },
            m = { function() require("pi").select_model() end, "Pi: select model" },
            M = { function() require("pi").select_model_all() end, "Pi: select all models" },
            h = { function() require("pi").focus_chat_history() end, "Pi: focus history" },
            p = { function() require("pi").focus_chat_prompt() end, "Pi: focus prompt" },
            t = { function() require("pi").tree() end, "Pi: session tree (:PiTree)" },
            c = { pi_new_tab, "Pi: open in new tab" },
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
