local wk = require "which-key"

-- Groups + root-level
wk.add {
  { "<leader>d", group = "+debug", icon = { icon = "", color = "orange" } },
  { "<leader>f", group = "+find", icon = { icon = "", color = "blue" } },
  { "<leader>g", group = "+git", icon = { icon = "", color = "orange" } },
  { "<leader>t", group = "+test", icon = { icon = "", color = "green" } },
  { "<leader>a", group = "+agent", icon = { icon = "", color = "magenta" } },
  { "<leader>c", group = "+code", icon = { icon = "", color = "cyan" } },
  { "<leader>w", group = "+workspace", icon = { icon = "", color = "white" } },

  -- root-level
  { "<leader>q", desc = "Quit", icon = { icon = "", color = "red" } },
  { "<leader>n", desc = "NvimTree Focus", icon = { icon = "", color = "blue" } },
  { "<leader>b", desc = "New Buffer", icon = { icon = "", color = "green" } },
  { "<leader>x", desc = "Close Buffer", icon = { icon = "", color = "red" } },
  { "<leader>e", desc = "NvimTree Toggle", icon = { icon = "", color = "blue" } },
  { "<leader>/", desc = "Comment", icon = { icon = "", color = "yellow" } },
  { "<leader>wK", desc = "WhichKey", icon = { icon = "", color = "cyan" } },
  { "<leader>wk", desc = "WhichKey Query", icon = { icon = "", color = "cyan" } },
  { "<leader>ds", desc = "Diag Loclist", icon = { icon = "", color = "yellow" } },
  { "<leader>dp", desc = "Diag Float", icon = { icon = "", color = "blue" } },
  { "<leader>fm", desc = "Format", icon = { icon = "", color = "green" } },
  { "<leader>th", desc = "Themes", icon = { icon = "", color = "magenta" } },
  { "<leader>D", desc = "Type Definition", icon = { icon = "", color = "cyan" } },
  { "<leader>rn", desc = "Relative Number", icon = { icon = "#", color = "grey" } },

  { "<leader>ma", desc = "Marks", icon = { icon = "", color = "cyan" } },
  { "<leader>h", desc = "Toggle horizontal terminal", icon = { icon = "", color = "green" } },
  { "<leader>v", desc = "Toggle vertical terminal", icon = { icon = "", color = "green" } },
}

-- +debug children
wk.add {
  { "<leader>dc", desc = "Continue", icon = { icon = "", color = "green" } },
  { "<leader>db", desc = "Toggle Breakpoint", icon = { icon = "", color = "red" } },
  { "<leader>dB", desc = "Conditional Breakpoint", icon = { icon = "", color = "red" } },
  { "<leader>du", desc = "Toggle UI", icon = { icon = "", color = "blue" } },
  { "<leader>dr", desc = "Restart Session", icon = { icon = "", color = "yellow" } },
  { "<leader>dt", desc = "Terminate Session", icon = { icon = "", color = "red" } },
  { "<leader>do", desc = "Step Over", icon = { icon = "", color = "cyan" } },
  { "<leader>di", desc = "Step Into", icon = { icon = "", color = "cyan" } },
  { "<leader>dO", desc = "Step Out", icon = { icon = "", color = "cyan" } },
  { "<leader>dR", desc = "Run to Cursor", icon = { icon = "", color = "green" } },
  { "<leader>dh", desc = "Evaluate/Hover", icon = { icon = "", color = "blue" } },
}

-- +find children
wk.add {
  { "<leader>ff", desc = "Find Files", icon = { icon = "", color = "blue" } },
  { "<leader>fa", desc = "Find All Files", icon = { icon = "", color = "blue" } },
  { "<leader>fw", desc = "Live Grep", icon = { icon = "", color = "blue" } },
  { "<leader>fb", desc = "Find Buffers", icon = { icon = "", color = "blue" } },
  { "<leader>fh", desc = "Help Tags", icon = { icon = "", color = "blue" } },
  { "<leader>fo", desc = "Oldfiles", icon = { icon = "", color = "blue" } },
  { "<leader>fz", desc = "Fuzzy Find Buffer", icon = { icon = "", color = "blue" } },
  { "<leader>fn", desc = "Notifications", icon = { icon = "", color = "yellow" } },
  { "<leader>ft", desc = "Switch Tab", icon = { icon = "", color = "blue" } },
  { "<leader>fT", desc = "Select Terminal", icon = { icon = "", color = "green" } },
}

-- +git children
wk.add {
  { "<leader>gt", desc = "Git Status", icon = { icon = "", color = "orange" } },
  { "<leader>gw", desc = "Worktree Switch", icon = { icon = "", color = "orange" } },
  { "<leader>gW", desc = "Worktree Create", icon = { icon = "", color = "orange" } },
}

-- +test children
wk.add {
  { "<leader>tt", desc = "Test Nearest", icon = { icon = "", color = "green" } },
  { "<leader>tf", desc = "Test File", icon = { icon = "", color = "green" } },
  { "<leader>td", desc = "Test Debug", icon = { icon = "", color = "green" } },
  { "<leader>ts", desc = "Toggle Summary", icon = { icon = "", color = "green" } },
}

-- +agent children (opencode / pi)
wk.add {
  { "<leader>aa", desc = "Toggle", icon = { icon = "", color = "magenta" } },
  { "<leader>aA", desc = "Ask", icon = { icon = "", color = "magenta" } },
  { "<leader>as", desc = "Select Server", icon = { icon = "", color = "magenta" } },
  { "<leader>ap", desc = "Toggle Pi", icon = { icon = "π", color = "magenta" } },
}

-- +code children
wk.add {
  { "<leader>ca", desc = "Code Action", icon = { icon = "", color = "cyan" } },
  { "<leader>cc", desc = "Claude Code", icon = { icon = "", color = "magenta" } },
  { "<leader>cr", desc = "Rename", icon = { icon = "", color = "yellow" } },
  { "<leader>cm", desc = "Git Commits", icon = { icon = "", color = "orange" } },
  { "<leader>ch", desc = "Cheatsheet", icon = { icon = "", color = "cyan" } },
}

-- +workspace children
wk.add {
  { "<leader>wa", desc = "Add Folder", icon = { icon = "", color = "white" } },
  { "<leader>wr", desc = "Remove Folder", icon = { icon = "", color = "white" } },
  { "<leader>wl", desc = "List Folders", icon = { icon = "", color = "white" } },
}
