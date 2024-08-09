local neotest = require "neotest"

vim.api.nvim_create_user_command("TestNearest", function()
  require("neotest").run.run()
end, { desc = "Test: Nearest" })

vim.api.nvim_create_user_command("TestFile", function()
  require("neotest").run.run(vim.fn.expand "%")
end, { desc = "Test: File" })

vim.api.nvim_create_user_command("TestDebugNearest", function()
  require("neotest").run.run { strategy = "dap" }
end, { desc = "Test: Debug nearest" })

vim.api.nvim_create_user_command("TestToggleSummaryPannel", function()
  require("neotest").summary.toggle()
end, { desc = "Test: Toggle summary pannel" })

local map = vim.keymap.set

map("n", "<leader>tt", "<cmd>TestNearest<CR>", { desc = "Test Nearest" })
map("n", "<leader>tf", "<cmd>TestFile<CR>", { desc = "Test File" })
map("n", "<leader>td", "<cmd>TestDebugNearest<CR>", { desc = "Test Debug nearest" })
map("n", "<leader>ts", "<cmd>TestToggleSummaryPannel<CR>", { desc = "Test Toggle summary pannel" })

neotest.setup {
  adapters = {
    require "neotest-golang",
  },
}
