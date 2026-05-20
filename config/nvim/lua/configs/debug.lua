local dap, dapui = require "dap", require "dapui"
local map = vim.keymap.set

require("nvim-dap-virtual-text").setup()

vim.api.nvim_set_hl(0, "debugPC", { bg = "#2a3158", default = true })

require("dap-go").setup({
  delve = {
    args = { "--check-go-version=false" },
  },
  dap_configurations = {
    {
      type = "go",
      name = "Debug Workspace (Arguments)",
      request = "launch",
      program = "${workspaceFolder}",
      args = require("dap-go").get_arguments,
    },
  },
})

require("mason-nvim-dap").setup({
  ensure_installed = { "delve", "codelldb" },
  automatic_installation = true,
})

dap.adapters.codelldb = {
  type = "server",
  port = "${port}",
  executable = {
    command = "codelldb",
    args = { "--port", "${port}" },
    detached = vim.fn.has "win32" == 0,
  },
  options = { initialize_timeout_sec = 30 },
}

map("n", "<M-r>", function()
  dap.restart()
end, { desc = "Debugger: Restart" })

map("n", "<M-s>", function()
  dap.terminate()
end, { desc = "Debugger: Terminate" })

dap.listeners.after.event_initialized["dap_keys"] = function()
  map("n", "<F10>", dap.step_over, { desc = "Step Over" })
  map("n", "<F11>", dap.step_into, { desc = "Step Into" })
  map("n", "<F12>", dap.step_out, { desc = "Step Out" })
end

local function clear_dap_keys()
  pcall(vim.keymap.del, "n", "<F10>")
  pcall(vim.keymap.del, "n", "<F11>")
  pcall(vim.keymap.del, "n", "<F12>")
end

dap.listeners.after.event_terminated["dap_keys"] = clear_dap_keys
dap.listeners.after.event_exited["dap_keys"] = clear_dap_keys

dap.listeners.before.attach.dapui_config = function()
  dapui.open()
end
dap.listeners.before.launch.dapui_config = function()
  dapui.open()
end
dap.listeners.before.event_terminated.dapui_config = function()
  dapui.close()
end
dap.listeners.before.event_exited.dapui_config = function()
  dapui.close()
end

dapui.setup({
  layouts = {
    {
      elements = {
        { id = "scopes", size = 0.25 },
        { id = "breakpoints", size = 0.25 },
        { id = "stacks", size = 0.25 },
        { id = "watches", size = 0.25 },
      },
      position = "left",
      size = 40,
    },
    {
      elements = {
        { id = "console", size = 0.5 },
        { id = "repl", size = 0.5 },
      },
      position = "bottom",
      size = 10,
    },
  },
})
