return {
  {
    "nickjvandyke/opencode.nvim",
    version = "*",
    keys = {
      {
        "<leader>aa",
        function()
          vim.g.opencode_opts.server.toggle()
        end,
        mode = { "n", "t" },
        desc = "Toggle OpenCode",
      },
      {
        "<leader>as",
        function()
          require("opencode").select()
        end,
        desc = "OpenCode select",
      },
      {
        "<leader>aA",
        function()
          require("opencode").ask("@this: ", { submit = true })
        end,
        mode = { "n", "x" },
        desc = "Ask opencode",
      },
      {
        "<leader>ao",
        function()
          return require("opencode").operator "@this " .. "_"
        end,
        mode = { "n", "x" },
        desc = "Add range to opencode",
        expr = true,
      },
      {
        "<leader>aoo",
        function()
          return require("opencode").operator "@this " .. "_"
        end,
        desc = "Add line to opencode",
        expr = true,
      },
    },
    init = function()
      local opencode_buf = nil
      local opencode_tab = nil

      vim.o.autoread = true

      local function find_opencode_tab()
        if opencode_buf and vim.api.nvim_buf_is_valid(opencode_buf) then
          for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
            for _, w in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
              if vim.api.nvim_win_get_buf(w) == opencode_buf then
                return tab
              end
            end
          end
        end
        return nil
      end

      vim.api.nvim_create_autocmd("TermOpen", {
        callback = function(args)
          if not vim.api.nvim_buf_get_name(args.buf):match "opencode" then
            return
          end
          opencode_buf = args.buf
          opencode_tab = vim.api.nvim_get_current_tabpage()
          local buf = args.buf

          local pid ---@type integer?
          local ok, raw_pid = pcall(vim.fn.jobpid, vim.b[buf].terminal_job_id)
          if ok then
            pid = raw_pid
          end

          local opts = { buffer = buf }
          vim.keymap.set("n", "<C-u>", function()
            require("opencode").command "session.half.page.up"
          end, vim.tbl_extend("force", opts, { desc = "Scroll up half page" }))
          vim.keymap.set("n", "<C-d>", function()
            require("opencode").command "session.half.page.down"
          end, vim.tbl_extend("force", opts, { desc = "Scroll down half page" }))
          vim.keymap.set("n", "gg", function()
            require("opencode").command "session.first"
          end, vim.tbl_extend("force", opts, { desc = "Go to first message" }))
          vim.keymap.set("n", "G", function()
            require("opencode").command "session.last"
          end, vim.tbl_extend("force", opts, { desc = "Go to last message" }))
          vim.keymap.set("n", "<Esc>", function()
            require("opencode").command "session.interrupt"
          end, vim.tbl_extend("force", opts, { desc = "Interrupt current session (esc)" }))

          vim.api.nvim_create_autocmd("TermClose", {
            buffer = buf,
            once = true,
            callback = function()
              if pid then
                if vim.fn.has "unix" == 1 then
                  os.execute("kill -TERM -" .. pid .. " 2>/dev/null")
                else
                  pcall(vim.uv.kill, pid, "SIGTERM")
                end
              end
              opencode_buf = nil
              opencode_tab = nil
              vim.schedule(function()
                if vim.api.nvim_buf_is_valid(buf) then
                  for _, w in ipairs(vim.fn.win_findbuf(buf)) do
                    pcall(vim.api.nvim_win_close, w, true)
                  end
                  pcall(vim.api.nvim_buf_delete, buf, { force = true })
                end
              end)
            end,
          })

          vim.schedule(function()
            if not vim.api.nvim_buf_is_valid(buf) then
              return
            end
            local wins = vim.fn.win_findbuf(buf)
            if #wins > 0 then
              vim.api.nvim_set_current_win(wins[1])
              vim.cmd "startinsert"
            end
          end)
        end,
      })

      vim.g.opencode_opts = {
        server = {
          toggle = function()
            local tab = find_opencode_tab()
            if tab then
              if vim.api.nvim_get_current_tabpage() == tab then
                vim.cmd "tabclose"
              else
                vim.api.nvim_set_current_tabpage(tab)
                vim.cmd "startinsert"
              end
            else
              vim.cmd "tabnew"
              local buf = vim.api.nvim_create_buf(false, false)
              vim.api.nvim_win_set_buf(0, buf)
              opencode_tab = vim.api.nvim_get_current_tabpage()
              vim.fn.jobstart("opencode --port", { term = true })
            end
          end,
        },
      }

      vim.api.nvim_create_autocmd("WinClosed", {
        callback = function()
          if #vim.api.nvim_list_tabpages() == 1 then
            local wins = vim.api.nvim_tabpage_list_wins(0)
            if #wins == 1 then
              local bufnr = vim.api.nvim_win_get_buf(wins[1])
              if vim.api.nvim_buf_get_name(bufnr):match "opencode" then
                vim.cmd "qa"
              end
            end
          end
        end,
      })
    end,
  },
}
