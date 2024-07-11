local dap, dapui = require "dap", require "dapui"

local utils = require "configs.utils"
local map = vim.keymap.set

local opts = {
  ensure_installed = {
    "delve",
  },
  automatic_installation = true,

  adapters = {
    delve = {
      type = "server",
      port = "${port}",
      executable = {
        command = "dlv",
        args = { "dap", "-l", "127.0.0.1:${port}" },
        detached = vim.fn.has "win32" == 0,
      },

      options = {
        initialize_timeout_sec = 30,
      },
    },
  },

  configurations = {
    go = {
      {
        type = "delve",
        name = "Debug",
        request = "launch",
        program = "${file}",
      },
      {
        type = "delve",
        name = "Debug (Arguments)",
        request = "launch",
        args = utils.get_arguments,
        program = "${file}",
      },
      {
        type = "delve",
        name = "Debug Workspace",
        request = "launch",
        program = "${workspaceFolder}",
      },
      {
        type = "delve",
        name = "Debug Workspace (Arguments)",
        request = "launch",
        program = "${workspaceFolder}",
        args = utils.get_arguments,
      },
      {
        type = "delve",
        name = "Debug test", -- configuration for debugging test files
        request = "launch",
        mode = "test",
        program = "${file}",
      },
      -- works with go.mod packages and sub packages
      {
        type = "delve",
        name = "Debug test (go.mod)",
        request = "launch",
        mode = "test",
        program = "./${relativeFileDirname}",
      },
    },
  },
}

map("n", "<M-r>", function()
  vim.api.nvim_echo({ { "Restarting debugger...", "None" } }, false, {})
  dap.restart()
end, { desc = "Debugger: Restart" })

map("n", "<M-s>", function()
  dap.terminate()
end, { desc = "Debugger: Terminate" })

require("mason-nvim-dap").setup {
  ensure_installed = opts.ensure_installed,
  automatic_installation = opts.automatic_installation,
}

dap.adapters = opts.adapters
dap.configurations = opts.configurations

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

dapui.setup {
  layouts = {
    {
      elements = {
        {
          id = "scopes",
          size = 0.25,
        },
        {
          id = "breakpoints",
          size = 0.25,
        },
        {
          id = "stacks",
          size = 0.25,
        },
        {
          id = "watches",
          size = 0.25,
        },
      },
      position = "left",
      size = 40,
    },
    {
      elements = {
        {
          id = "repl",
          size = 1,
        },
      },
      position = "bottom",
      size = 10,
    },
  },
}
