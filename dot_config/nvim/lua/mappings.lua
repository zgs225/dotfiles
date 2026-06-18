require "nvchad.mappings"

-- add yours here
local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("n", "<leader>q", ":q<CR>", { desc = "General quit current buffer" })
map("n", "<leader>w", ":w<CR>", { desc = "General save current buffer" })
map("n", "<C-p>", ":Telescope find_files<CR>", { desc = "Find files" })

map("n", "<leader>fT", "<cmd>Telescope terms<CR>", { desc = "Pick Terminal" })

map("n", "<leader>ft", function()
  local pickers = require "telescope.pickers"
  local finders = require "telescope.finders"
  local conf = require("telescope.config").values
  local actions = require "telescope.actions"
  local action_state = require "telescope.actions.state"

  local tabs = {}
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local wins = vim.api.nvim_tabpage_list_wins(tab)
    local name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(wins[1]))
    name = name == "" and "[No Name]" or vim.fn.fnamemodify(name, ":t")
    tabs[#tabs + 1] = { tab = tab, display = "Tab " .. tab .. ": " .. name }
  end

  pickers
    .new({}, {
      prompt_title = "Switch Tab",
      finder = finders.new_table {
        results = tabs,
        entry_maker = function(entry)
          return { value = entry.tab, display = entry.display, ordinal = entry.display }
        end,
      },
      sorter = conf.generic_sorter {},
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if selection then
            vim.api.nvim_set_current_tabpage(selection.value)
          end
        end)
        return true
      end,
    })
    :find()
end, { desc = "Switch Tab" })

-- Tab navigation
map("n", "tp", ":tabprevious<CR>", { desc = "Tab previous" })
map("n", "tn", ":tabnext<CR>", { desc = "Tab next" })
map("n", "tm", ":tabmove", { desc = "Tab move" })

map("n", "<leader>n", "<cmd>NvimTreeFocus<CR>", { desc = "nvimtree focus" })
map("n", "<leader>e", "<cmd>NvimTreeToggle<CR>", { desc = "nvimtree toggle" })
-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")

-- Show Diagnostics under the line in popup window
map("n", "<leader>dp", function()
  vim.diagnostic.open_float { scope = "l" }
end, { desc = "LSP Diagnostics under the line" })

-- Terminal mode window navigation with state restore
local term_nav_group = vim.api.nvim_create_augroup("TermNavRestore", {})
local restore_on_enter = {}

local function terminal_navigate(dir)
  local bufnr = vim.api.nvim_get_current_buf()
  local was_term_mode = (vim.api.nvim_get_mode().mode == "t")
  if was_term_mode then
    restore_on_enter[bufnr] = true
    vim.cmd("stopinsert")
  end
  vim.cmd("wincmd " .. dir)
end

vim.api.nvim_create_autocmd("BufEnter", {
  group = term_nav_group,
  callback = function()
    local bufnr = vim.api.nvim_get_current_buf()
    if restore_on_enter[bufnr] then
      restore_on_enter[bufnr] = nil
      vim.schedule(function() vim.cmd("startinsert") end)
    end
  end,
})

map("t", "<C-h>", function() terminal_navigate("h") end, { desc = "terminal switch window left" })
map("t", "<C-l>", function() terminal_navigate("l") end, { desc = "terminal switch window right" })
map("t", "<C-j>", function() terminal_navigate("j") end, { desc = "terminal switch window down" })
map("t", "<C-k>", function() terminal_navigate("k") end, { desc = "terminal switch window up" })

-- Disable tab buffer switching in terminal buffers
vim.api.nvim_create_autocmd("TermOpen", {
  group = term_nav_group,
  callback = function(args)
    local opts = { buffer = args.buf, silent = true }
    vim.keymap.set("n", "<Tab>", "<Nop>", opts)
    vim.keymap.set("n", "<S-Tab>", "<Nop>", opts)
  end,
})
