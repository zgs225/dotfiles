local dap, dapui = require "dap", require "dapui"

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

