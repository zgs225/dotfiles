local function get_chat()
  local session = require("pi.sessions.manager").get()
  return session and session.chat or nil
end

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

local function show_pi_here(pi)
  local chat = get_chat()
  if chat then
    chat:set_layout "side"
  else
    pi.show { layout = "side" }
  end
  pi.focus_chat_prompt()
end

local function toggle_pi()
  local pi = require "pi"
  if chat_in_current_tab() then
    get_chat():hide()
  else
    show_pi_here(pi)
  end
end

return {
  {
    "https://github.com/zgs225/pi2.nvim.git",
    -- Dev escape hatch: point lazy at a feature worktree by launching nvim
    -- with PI_DEV_DIR set (nil = normal installed path). See pi.nvim G23.
    dir = vim.env.PI_DEV_DIR or nil,
    dependencies = {
      { "HakonHarnes/img-clip.nvim", opts = { default = { drag_and_drop = { enabled = false } } } },
    },
    opts = {
      vision = { model = "kimi-coding/kimi-for-coding", status_message = "描影…" },
      title = {
        enabled = true,
        max_chars = 20,
        model = "commandcode/deepseek/deepseek-v4-flash",
      },
      show_thinking = true,
      expand_startup_details = false,
      abort = { enabled = true, timeout = 1500, message = "再按一次 <Esc> 中断当前回合" },
      render = { engine = "render-markdown" },
      sessions_list = { auto_open = true },
      layout = {
        default = "side",
        side = { position = "left", width = 0.6 },
        float = { width = 120, height = 0.85, border = "rounded" },
      },
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
        "<Cmd>PiNewTab<CR>",
        desc = "Pi (new tab)",
      },
    },
    init = function()
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
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("PiBufferKeys", { clear = true }),
        pattern = { "pi-chat-history", "pi-chat-prompt" },
        callback = function(args)
          local leaders = {
            s = {
              function()
                require("pi").resume_session()
              end,
              "Pi: resume session",
            },
            n = {
              function()
                require("pi").new_session()
              end,
              "Pi: new session",
            },
            m = {
              function()
                require("pi").select_model()
              end,
              "Pi: select model",
            },
            M = {
              function()
                require("pi").select_model_all()
              end,
              "Pi: select all models",
            },
            h = {
              function()
                require("pi").focus_chat_history()
              end,
              "Pi: focus history",
            },
            p = {
              function()
                require("pi").focus_chat_prompt()
              end,
              "Pi: focus prompt",
            },
            t = {
              function()
                require("pi").tree()
              end,
              "Pi: session tree (:PiTree)",
            },
            c = { "<Cmd>PiNewTab<CR>", "Pi: open in new tab" },
          }
          for key, spec in pairs(leaders) do
            vim.keymap.set({ "n", "i" }, "<C-g>" .. key, spec[1], { buffer = args.buf, desc = spec[2] })
          end

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
