# Neovim Config Migration: NvChad → snacks.nvim

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace NvChad framework with snacks.nvim, preserving all functionality and keybinding habits.

**Architecture:** Remove NvChad/NvChad as the base framework. Add folke/snacks.nvim (priority=1000) alongside craftzdog/solarized-osaka.nvim (colorscheme) and nvim-lualine/lualine.nvim (statusline). Expose all plugins previously provided by NvChad as explicit lazy.nvim specs. Rewrite init.lua to remove base46 cache loading and nvchad.* dependencies.

**Tech Stack:** Neovim 0.12, lazy.nvim, snacks.nvim, lualine.nvim, solarized-osaka.nvim

**Files to delete:**
- `lua/chadrc.lua`
- `lua/plugins/notify.lua`

**Files to create:**
- `lua/configs/lualine.lua`
- `lua/configs/snacks.lua`
- `lua/plugins/snacks.lua`
- `lua/autocmds.lua`

**Files to modify:**
- `init.lua`
- `lua/options.lua`
- `lua/mappings.lua`
- `lua/configs/lazy.lua`
- `lua/configs/lsp.lua`
- `lua/configs/treesitter.lua`
- `lua/configs/java.lua`
- `lua/plugins/init.lua`
- `lua/plugins/appearance.lua`
- `lua/plugins/devtools.lua`

---

### Task 1: Create `lua/configs/lualine.lua`

**Files:**
- Create: `lua/configs/lualine.lua`

- [ ] **Step 1: Write lualine config**

```lua
return {
  options = {
    theme = "auto",
    globalstatus = true,
    section_separators = { left = "", right = "" },
    component_separators = { left = "", right = "" },
    disabled_filetypes = {
      statusline = { "snacks_dashboard", "alpha", "dashboard", "NvimTree", "neo-tree", "aerial" },
    },
  },
  sections = {
    lualine_a = { "mode" },
    lualine_b = { "branch", "diff", "diagnostics" },
    lualine_c = {
      {
        "filename",
        file_status = true,
        path = 1,
      },
    },
    lualine_x = { "encoding", "fileformat", "filetype" },
    lualine_y = { "progress" },
    lualine_z = { "location" },
  },
  inactive_sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = { "filename" },
    lualine_x = { "location" },
    lualine_y = {},
    lualine_z = {},
  },
  tabline = {},
  extensions = { "nvim-dap-ui", "mason", "quickfix", "fzf", "lazy" },
}
```

- [ ] **Step 2: Commit**

```
git add lua/configs/lualine.lua
git commit -m "feat: add lualine.nvim config"
```

---

### Task 2: Create `lua/autocmds.lua`

**Files:**
- Create: `lua/autocmds.lua`

- [ ] **Step 1: Write autocmds replacement for nvchad.autocmds**

```lua
local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd
local general = augroup("General", { clear = true })

-- Highlight on yank
autocmd("TextYankPost", {
  group = general,
  callback = function()
    vim.hl.range("Yank", vim.fn.getpos("'["), vim.fn.getpos("']"), { regtype = vim.fn.regtype(), inclusive = true, priority = 2048 })
  end,
})

-- Go to last location on open
autocmd("BufReadPost", {
  group = general,
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Resize splits on window resize
autocmd("VimResized", {
  group = general,
  callback = function()
    vim.cmd("wincmd =")
  end,
})

-- Close some filetypes with q
autocmd("FileType", {
  group = general,
  pattern = { "qf", "help", "man", "lspinfo", "checkhealth", "lazy", "mason" },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = event.buf, silent = true })
  end,
})

-- Terminal settings
local term_group = augroup("TermSettings", { clear = true })
autocmd("TermOpen", {
  group = term_group,
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = "no"
    vim.cmd("startinsert")
  end,
})

-- Wrap and spell for markdown and text files
autocmd("FileType", {
  group = general,
  pattern = { "markdown", "text", "gitcommit" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
  end,
})
```

- [ ] **Step 2: Commit**

```
git add lua/autocmds.lua
git commit -m "feat: add custom autocmds replacing nvchad.autocmds"
```

---

### Task 3: Rewrite `lua/options.lua`

**Files:**
- Modify: `lua/options.lua`

- [ ] **Step 1: Remove nvchad.options dependency, write options directly**

Replace the entire file content with:

```lua
local o = vim.o
local wo = vim.wo
local bo = vim.bo
local opt = vim.opt

o.cursorlineopt = "both"
o.swapfile = false
o.cmdheight = 0
o.autoread = true

o.number = true
o.relativenumber = true
o.mouse = "a"
o.showmode = false
o.clipboard = "unnamedplus"
o.breakindent = true
o.undofile = true
o.ignorecase = true
o.smartcase = true
o.updatetime = 250
o.timeoutlen = 300
o.signcolumn = "yes"
o.termguicolors = true
o.splitright = true
o.splitbelow = true

opt.fillchars = {
  foldopen = "",
  foldclose = "",
  fold = " ",
  foldsep = " ",
  diff = "╱",
  eob = " ",
}

wo.cursorline = true
wo.number = true
wo.relativenumber = true

-- file type detects
local detect_gotmpl = {
  function()
    if vim.fn.search("{{.+}}", "nw") then
      return "gotmpl"
    end
  end,
  { priority = 200 },
}

vim.filetype.add {
  extension = {
    gotmpl = "gotmpl",
  },
  pattern = {
    [".*/templates/.*%.tmpl"] = detect_gotmpl,
    [".*/templates/.*%.yaml"] = detect_gotmpl,
    [".*%.yaml.tmpl"] = detect_gotmpl,
  },
}

if vim.fn.exists("&messagesopt") == 1 then
  o.messagesopt = "wait:150,history:500"
end

-- Makefile settings
vim.api.nvim_create_autocmd("FileType", {
  pattern = "make",
  callback = function()
    vim.opt_local.expandtab = false
    vim.opt_local.tabstop = 4
    vim.opt_local.shiftwidth = 4
    vim.opt_local.list = true
    vim.opt_local.listchars = { tab = "→ ", trail = "·" }
  end,
})
```

- [ ] **Step 2: Commit**

```
git add lua/options.lua
git commit -m "refactor: remove nvchad.options dependency, write options directly"
```

---

### Task 4: Simplify `lua/configs/lazy.lua`

**Files:**
- Modify: `lua/configs/lazy.lua`

- [ ] **Step 1: Simplify lazy config, remove NvChad-specific disabled_plugins list**

Replace the entire file content with:

```lua
return {
  defaults = { lazy = true },
  install = { colorscheme = { "solarized-osaka" } },
  performance = {
    rtp = {
      disabled_plugins = {
        "2html_plugin",
        "tohtml",
        "getscript",
        "getscriptPlugin",
        "gzip",
        "logipat",
        "netrw",
        "netrwPlugin",
        "netrwSettings",
        "netrwFileHandlers",
        "tar",
        "tarPlugin",
        "rrhelper",
        "vimball",
        "vimballPlugin",
        "zip",
        "zipPlugin",
        "tutor",
        "rplugin",
        "syntax",
        "synmenu",
        "optwin",
        "compiler",
        "bugreport",
      },
    },
  },
}
```

Changes from current:
- colorscheme: `"nvchad"` → `"solarized-osaka"`
- Removed from disabled: `matchit`, `ftplugin`, `spellfile_plugin`

- [ ] **Step 2: Commit**

```
git add lua/configs/lazy.lua
git commit -m "refactor: simplify lazy config, switch colorscheme to solarized-osaka"
```

---

### Task 5: Rewrite `lua/configs/lsp.lua`

**Files:**
- Modify: `lua/configs/lsp.lua`

- [ ] **Step 1: Remove nvchad.configs.lspconfig dependency, define on_attach/on_init/capabilities locally**

Replace the entire file content with:

```lua
vim.diagnostic.config { virtual_text = false }

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)

local on_attach = function(client, bufnr)
  local keymap = vim.keymap.set
  local opts = { buffer = bufnr, noremap = true, silent = true }

  keymap("n", "gd", vim.lsp.buf.definition, opts)
  keymap("n", "K", vim.lsp.buf.hover, opts)
  keymap("n", "gi", vim.lsp.buf.implementation, opts)
  keymap("n", "gr", vim.lsp.buf.references, opts)
  keymap("n", "<leader>ca", vim.lsp.buf.code_action, opts)
  keymap("v", "<leader>ca", vim.lsp.buf.code_action, opts)
  keymap("n", "<leader>rn", vim.lsp.buf.rename, opts)
  keymap("n", "<leader>cl", vim.lsp.codelens.run, opts)

  vim.lsp.inlay_hint.enable(true)
end

local on_init = function(client, _)
  if client.supports_method("textDocument/formatting") then
    vim.notify("LSP: " .. client.name .. " attached", vim.log.levels.INFO)
  end
end

local servers = { "html", "cssls", "gopls", "bashls", "basedpyright", "ts_ls", "yamlls", "astro", "tailwindcss" }
local lsp_settings = {
  gopls = {
    hints = {
      compositeLiteralFields = true,
      constantValues = true,
      parameterNames = true,
      assignVariableTypes = true,
      functionTypeParameters = true,
      rangeVariableTypes = true,
    },
    codelenses = {
      test = true,
    },
  },
  basedpyright = {
    ["analysis.inlayHints.genericTypes"] = true,
  },
  yamlls = {
    schemas = {
      ["https://json.schemastore.org/chart.json"] = "Chart.yaml",
      ["https://json.schemastore.org/chart-lock.json"] = "Chart.lock",
      ["https://json.schemastore.org/kustomization.json"] = "kustomization.yaml",
      ["https://gitlab.com/gitlab-org/gitlab/-/raw/master/app/assets/javascripts/editor/schema/ci.json"] = ".gitlab-ci.yml",
    },
  },
}

for _, lsp in ipairs(servers) do
  local settings = lsp_settings[lsp]
  vim.lsp.config(lsp, {
    on_attach = on_attach,
    on_init = on_init,
    capabilities = capabilities,
    settings = {
      [lsp] = settings,
    },
  })
  vim.lsp.enable(lsp)
end

-- rust_analyzer
vim.lsp.config("rust_analyzer", {
  on_attach = on_attach,
  on_init = on_init,
  capabilities = capabilities,
})
vim.lsp.enable("rust_analyzer")

-- rust-protobuf-analyzer
vim.api.nvim_create_autocmd("FileType", {
  pattern = "proto",
  callback = function(args)
    local cargo_file = vim.fn.expand("~") .. "/Workspace/Development/Rust/rust-protobuf-analyzer/Cargo.toml"
    vim.lsp.set_log_level("debug")
    vim.lsp.start({
      name = "rust-protobuf-analyzer",
      cmd = {
        "cargo",
        "run",
        "--package",
        "rust-protobuf-analyzer",
        "--manifest-path",
        cargo_file,
      },
      cmd_env = { RPA_LOG = "debug", RUST_BACKTRACE = "full" },
      root_dir = vim.fs.root(args.buf, { ".git" }),
    })
  end,
})
```

Key changes:
- Removed `require("nvchad.configs.lspconfig").defaults()` and its on_attach/on_init/capabilities
- Defined on_attach locally with expanded LSP keymaps (gd, K, gi, gr, <leader>ca, <leader>rn, <leader>cl)
- `vim.diagnostic.config { virtual_text = false }` called once globally at top
- `vim.lsp.inlay_hint.enable(true)` kept in on_attach (needs bufnr context)

- [ ] **Step 2: Commit**

```
git add lua/configs/lsp.lua
git commit -m "refactor: remove nvchad.configs.lspconfig dependency from LSP config"
```

---

### Task 6: Update `lua/configs/treesitter.lua`

**Files:**
- Modify: `lua/configs/treesitter.lua`

- [ ] **Step 1: Remove nvchad.configs.treesitter dependency**

Replace the entire file content with:

```lua
return {
  ensure_installed = {
    "astro",
    "bash",
    "cpp",
    "css",
    "csv",
    "dockerfile",
    "git_config",
    "git_rebase",
    "gitattributes",
    "go",
    "goctl",
    "gomod",
    "gosum",
    "gotmpl",
    "gowork",
    "html",
    "java",
    "javascript",
    "json",
    "lua",
    "luadoc",
    "make",
    "printf",
    "proto",
    "pymanifest",
    "python",
    "rust",
    "starlark",
    "tmux",
    "toml",
    "typescript",
    "vim",
    "vimdoc",
    "xml",
    "yaml",
  },
  auto_install = true,
  highlight = {
    enable = true,
    additional_vim_regex_highlighting = false,
  },
  indent = { enable = true },
  incremental_selection = {
    enable = true,
    keymaps = {
      init_selection = "<CR>",
      scope_incremental = "<CR>",
      node_incremental = "<TAB>",
      node_decremental = "<S-TAB>",
    },
  },
}
```

- [ ] **Step 2: Commit**

```
git add lua/configs/treesitter.lua
git commit -m "refactor: remove nvchad.configs.treesitter dependency"
```

---

### Task 7: Update `lua/configs/java.lua`

**Files:**
- Modify: `lua/configs/java.lua`

- [ ] **Step 1: Remove nvchad.configs.lspconfig dependency from java config**

Replace lines 34-36 with local definitions:

```lua
require("java").setup {
  jdtls = {
    version = "v1.43.0",
  },
  lombok = {
    version = "nightly",
  },
  java_test = {
    enable = true,
    version = "0.40.1",
  },
  java_debug_adapter = {
    enable = true,
    version = "0.58.1",
  },
  spring_boot_tools = {
    enable = true,
    version = "1.55.1",
  },
  jdk = {
    auto_install = true,
    version = "17.0.2",
  },
}

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)

local on_attach = function(client, bufnr)
  vim.opt_local.tabstop = 4
  vim.opt_local.shiftwidth = 4

  if client.server_capabilities.inlayHintProvider then
    vim.lsp.buf.inlay_hints(bufnr, true)
  end
end

local on_init = function(client, _)
  if client.supports_method("textDocument/formatting") then
    vim.notify("LSP: " .. client.name .. " attached", vim.log.levels.INFO)
  end
end

require("nvim.lsp").config("jdtls", {
  on_attach = on_attach,
  on_init = on_init,
  capabilities = capabilities,
  settings = {
    java = {
      runtimes = {
        {
          name = "OpenJDK-21",
          path = "/opt/homebrew/Cellar/openjdk@21/21.0.7/libexec/openjdk.jdk/Contents/Home",
          default = true,
        },
      },
      eclipse = {
        downloadSources = true,
      },
      implementationsCodeLens = {
        enabled = true,
      },
      referencesCodeLens = {
        enabled = true,
      },
      inlayHints = {
        parameterNames = {
          enabled = "all",
        },
        typeHints = {
          enabled = true,
        },
      },
      saveActions = {
        organizeImports = true,
      },
      format = {
        enabled = true,
        settings = {
          profile = "GoogleStyle",
        },
      },
    },
  },
})
```

- [ ] **Step 2: Commit**

```
git add lua/configs/java.lua
git commit -m "refactor: remove nvchad.configs.lspconfig dependency from java config"
```

---

### Task 8: Rewrite `lua/plugins/init.lua` (Core Plugins)

**Files:**
- Modify: `lua/plugins/init.lua`

- [ ] **Step 1: Add all plugins previously provided by NvChad**

Replace the entire file content with:

```lua
return {
  -- Completion
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-nvim-lua",
      "saadparwaiz1/cmp_luasnip",
      "FelipeLema/cmp-async-path",
      "L3MON4D3/LuaSnip",
      "rafamadriz/friendly-snippets",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")
      require("luasnip.loaders.from_vscode").lazy_load()

      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "buffer" },
          { name = "async_path" },
          { name = "nvim_lua" },
        }),
      })
    end,
  },

  -- Auto pairs
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = function()
      require("nvim-autopairs").setup()
      local cmp_autopairs = require("nvim-autopairs.completion.cmp")
      require("cmp").event:on("confirm_done", cmp_autopairs.on_confirm_done())
    end,
  },

  -- Comment
  {
    "numToStr/Comment.nvim",
    event = "User FilePost",
    config = function()
      require("Comment").setup()
    end,
  },

  -- Surround
  {
    "tpope/vim-surround",
    event = "User FilePost",
  },

  -- Render markdown
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = "markdown",
    cmd = { "RenderMarkdown" },
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    opts = {
      file_types = { "markdown" },
    },
  },

  -- Mason
  {
    "williamboman/mason.nvim",
    version = "1.11.0",
    cmd = { "Mason", "MasonInstall", "MasonInstallAll", "MasonUpdate" },
    opts = function()
      return require("configs.mason")
    end,
  },
}
```

Key changes:
- Removed `pbrisbin/vim-mkdir` (replaced by `:wall ++p` in 0.12)
- Added nvim-cmp with all completion sources (was implicitly provided by NvChad)
- Added LuaSnip (was implicitly provided by NvChad)
- Added nvim-autopairs (was implicitly provided by NvChad)
- Added Comment.nvim (was implicitly provided by NvChad)
- Kept tpope/vim-surround (was in custom plugins)
- Kept render-markdown.nvim (was in custom plugins)
- Kept mason.nvim (was in custom plugins)

- [ ] **Step 2: Commit**

```
git add lua/plugins/init.lua
git commit -m "feat: add explicit plugin specs for NvChad-provided plugins (cmp, autopairs, comment)"
```

---

### Task 9: Create `lua/plugins/snacks.lua`

**Files:**
- Create: `lua/plugins/snacks.lua`

- [ ] **Step 1: Write full snacks.nvim plugin spec with all enabled features**

```lua
return {
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    ---@type snacks.Config
    opts = {
      animate = { enabled = true },
      bigfile = { enabled = true },
      bufdelete = { enabled = true },
      dashboard = {
        enabled = true,
        preset = {
          pick = function(cmd, opts)
            return require("snacks").picker[cmd](opts)
          end,
          keys = {
            { icon = " ", key = "f", desc = "Find File", action = ":lua Snacks.dashboard.pick('files')" },
            { icon = "󰈚 ", key = "r", desc = "Recent Files", action = ":lua Snacks.dashboard.pick('oldfiles')" },
            { icon = "󰈭 ", key = "g", desc = "Find Word", action = ":lua Snacks.dashboard.pick('live_grep')" },
            { icon = " ", key = "m", desc = "Marks", action = ":lua Snacks.dashboard.pick('marks')" },
            { icon = " ", key = "t", desc = "Themes", action = ":lua Snacks.dashboard.pick('colorschemes')" },
            { icon = " ", key = "k", desc = "Keymaps", action = ":lua Snacks.dashboard.pick('keymaps')" },
            { icon = "󰒲 ", key = "L", desc = "Lazy", action = ":Lazy", enabled = package.loaded.lazy ~= nil },
            { icon = " ", key = "q", desc = "Quit", action = ":qa" },
          },
        },
        sections = {
          { section = "header" },
          { section = "keys", gap = 1, padding = 1 },
          { icon = " ", title = "Recent Files", section = "recent_files", indent = 2, padding = 2 },
          { section = "startup" },
        },
      },
      dim = { enabled = true },
      explorer = { enabled = true },
      gitbrowse = { enabled = true },
      image = { enabled = true },
      indent = { enabled = true },
      input = { enabled = true },
      lazygit = { enabled = true },
      notifier = {
        enabled = true,
        timeout = 3000,
      },
      picker = { enabled = true },
      quickfile = { enabled = true },
      rename = { enabled = true },
      scope = { enabled = true },
      scroll = { enabled = true },
      statuscolumn = { enabled = true },
      terminal = { enabled = true },
      toggle = { enabled = true },
      words = { enabled = true },
      zen = { enabled = true },
      styles = {
        notification = {
          wo = { wrap = true },
        },
      },
    },
    keys = {
      -- Picker: find
      { "<leader><space>", function() Snacks.picker.smart() end, desc = "Smart Find Files" },
      { "<leader>,", function() Snacks.picker.buffers() end, desc = "Buffers" },
      { "<leader>/", function() Snacks.picker.grep() end, desc = "Grep" },
      { "<leader>:", function() Snacks.picker.command_history() end, desc = "Command History" },
      { "<leader>ff", function() Snacks.picker.files() end, desc = "Find Files" },
      { "<leader>fw", function() Snacks.picker.grep() end, desc = "Live Grep" },
      { "<leader>fr", function() Snacks.picker.recent() end, desc = "Recent" },
      { "<leader>fb", function() Snacks.picker.buffers() end, desc = "Buffers" },
      { "<leader>fc", function() Snacks.picker.files({ cwd = vim.fn.stdpath("config") }) end, desc = "Find Config File" },
      { "<leader>fg", function() Snacks.picker.git_files() end, desc = "Find Git Files" },
      -- Picker: search
      { "<leader>sb", function() Snacks.picker.lines() end, desc = "Buffer Lines" },
      { "<leader>sB", function() Snacks.picker.grep_buffers() end, desc = "Grep Open Buffers" },
      { "<leader>sg", function() Snacks.picker.grep() end, desc = "Grep" },
      { '<leader>s"', function() Snacks.picker.registers() end, desc = "Registers" },
      { "<leader>s/", function() Snacks.picker.search_history() end, desc = "Search History" },
      { "<leader>sa", function() Snacks.picker.autocmds() end, desc = "Autocmds" },
      { "<leader>sc", function() Snacks.picker.command_history() end, desc = "Command History" },
      { "<leader>sC", function() Snacks.picker.commands() end, desc = "Commands" },
      { "<leader>sd", function() Snacks.picker.diagnostics() end, desc = "Diagnostics" },
      { "<leader>sD", function() Snacks.picker.diagnostics_buffer() end, desc = "Buffer Diagnostics" },
      { "<leader>sh", function() Snacks.picker.help() end, desc = "Help Pages" },
      { "<leader>sH", function() Snacks.picker.highlights() end, desc = "Highlights" },
      { "<leader>sj", function() Snacks.picker.jumps() end, desc = "Jumps" },
      { "<leader>sk", function() Snacks.picker.keymaps() end, desc = "Keymaps" },
      { "<leader>sl", function() Snacks.picker.loclist() end, desc = "Location List" },
      { "<leader>sm", function() Snacks.picker.marks() end, desc = "Marks" },
      { "<leader>sM", function() Snacks.picker.man() end, desc = "Man Pages" },
      { "<leader>sq", function() Snacks.picker.qflist() end, desc = "Quickfix List" },
      { "<leader>sR", function() Snacks.picker.resume() end, desc = "Resume" },
      { "<leader>uC", function() Snacks.picker.colorschemes() end, desc = "Colorschemes" },
      -- LSP
      { "gd", function() Snacks.picker.lsp_definitions() end, desc = "Goto Definition" },
      { "gD", function() Snacks.picker.lsp_declarations() end, desc = "Goto Declaration" },
      { "gr", function() Snacks.picker.lsp_references() end, nowait = true, desc = "References" },
      { "gI", function() Snacks.picker.lsp_implementations() end, desc = "Goto Implementation" },
      { "gy", function() Snacks.picker.lsp_type_definitions() end, desc = "Goto Type Definition" },
      { "<leader>ss", function() Snacks.picker.lsp_symbols() end, desc = "LSP Symbols" },
      { "<leader>sS", function() Snacks.picker.lsp_workspace_symbols() end, desc = "LSP Workspace Symbols" },
      -- Other
      { "<leader>e", function() Snacks.explorer() end, desc = "File Explorer" },
      { "<leader>z", function() Snacks.zen() end, desc = "Toggle Zen Mode" },
      { "<leader>Z", function() Snacks.zen.zoom() end, desc = "Toggle Zoom" },
      { "<leader>.", function() Snacks.scratch() end, desc = "Toggle Scratch Buffer" },
      { "<leader>n", function() Snacks.notifier.show_history() end, desc = "Notification History" },
      { "<leader>bd", function() Snacks.bufdelete() end, desc = "Delete Buffer" },
      { "<leader>cR", function() Snacks.rename.rename_file() end, desc = "Rename File" },
      { "<leader>gB", function() Snacks.gitbrowse() end, desc = "Git Browse", mode = { "n", "v" } },
      { "<leader>gg", function() Snacks.lazygit() end, desc = "Lazygit" },
      { "<leader>un", function() Snacks.notifier.hide() end, desc = "Dismiss All Notifications" },
      { "<c-/>", function() Snacks.terminal() end, desc = "Toggle Terminal" },
      { "<c-_>", function() Snacks.terminal() end, desc = "which_key_ignore" },
      { "]]", function() Snacks.words.jump(vim.v.count1) end, desc = "Next Reference", mode = { "n", "t" } },
      { "[[", function() Snacks.words.jump(-vim.v.count1) end, desc = "Prev Reference", mode = { "n", "t" } },
    },
    init = function()
      vim.api.nvim_create_autocmd("User", {
        pattern = "VeryLazy",
        callback = function()
          _G.dd = function(...)
            Snacks.debug.inspect(...)
          end
          _G.bt = function()
            Snacks.debug.backtrace()
          end

          if vim.fn.has("nvim-0.11") == 1 then
            vim._print = function(_, ...)
              dd(...)
            end
          else
            vim.print = _G.dd
          end

          Snacks.toggle.option("spell", { name = "Spelling" }):map("<leader>us")
          Snacks.toggle.option("wrap", { name = "Wrap" }):map("<leader>uw")
          Snacks.toggle.option("relativenumber", { name = "Relative Number" }):map("<leader>uL")
          Snacks.toggle.diagnostics():map("<leader>ud")
          Snacks.toggle.line_number():map("<leader>ul")
          Snacks.toggle.option("conceallevel", { off = 0, on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2 }):map("<leader>uc")
          Snacks.toggle.treesitter():map("<leader>uT")
          Snacks.toggle.option("background", { off = "light", on = "dark", name = "Dark Background" }):map("<leader>ub")
          Snacks.toggle.inlay_hints():map("<leader>uh")
          Snacks.toggle.indent():map("<leader>ug")
          Snacks.toggle.dim():map("<leader>uD")
        end,
      })
    end,
  },
}
```

- [ ] **Step 2: Commit**

```
git add lua/plugins/snacks.lua
git commit -m "feat: add snacks.nvim plugin spec with all enabled features"
```

---

### Task 10: Rewrite `lua/plugins/appearance.lua`

**Files:**
- Modify: `lua/plugins/appearance.lua`

- [ ] **Step 1: Remove nvim-tree/dressing, add which-key/noice/nui**

Replace the entire file content with:

```lua
return {
  -- Which-key
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "helix",
      delay = 500,
      spec = {
        { "<leader>c", group = "code" },
        { "<leader>f", group = "find" },
        { "<leader>g", group = "git" },
        { "<leader>s", group = "search" },
        { "<leader>u", group = "toggle" },
      },
    },
  },

  -- Noice (command-line UI)
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = {
      "MunifTanjim/nui.nvim",
    },
    opts = {
      lsp = {
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
          ["cmp.entry.get_documentation"] = true,
        },
      },
      presets = {
        bottom_search = true,
        command_palette = true,
        long_message_to_split = true,
        inc_rename = false,
        lsp_doc_border = true,
      },
    },
  },

  -- Git signs
  {
    "lewis6991/gitsigns.nvim",
    event = "User FilePost",
    opts = {
      signs = {
        add = { text = "▎" },
        change = { text = "▎" },
        delete = { text = "" },
        topdelete = { text = "" },
        changedelete = { text = "▎" },
        untracked = { text = "▎" },
      },
      signs_staged_enable = true,
    },
  },

  -- Code structure
  {
    "stevearc/aerial.nvim",
    cmd = { "AerialToggle" },
    keys = {
      { "<F6>", "<cmd>AerialToggle!<CR>", desc = "Toggle outline" },
    },
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      require("configs.aerial")
    end,
  },

  -- Breadcrumbs
  {
    "Bekaboo/dropbar.nvim",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = {
      "nvim-telescope/telescope-fzf-native.nvim",
    },
    config = function()
      require("configs.dropbar")
    end,
  },

  -- Treesitter context
  {
    "nvim-treesitter/nvim-treesitter-context",
    event = "User FilePost",
    cmd = { "TSContextEnable", "TSContextDisable", "TSContextToggle" },
    config = function()
      require("treesitter-context").setup()
    end,
  },

  -- TODO comments
  {
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    event = "BufReadPre",
    keys = {
      {
        "]t",
        function()
          require("todo-comments").jump_next()
        end,
        desc = "Next todo comment",
      },
      {
        "[t",
        function()
          require("todo-comments").jump_prev()
        end,
        desc = "Previous todo comment",
      },
    },
    opts = {},
  },
}
```

Key changes:
- Removed nvim-tree.lua (→ snacks.explorer)
- Removed dressing.nvim (→ snacks.input)
- Added which-key.nvim (was provided by NvChad)
- Added noice.nvim (was provided by NvChad)
- Added nui.nvim (noice dependency)
- Added gitsigns.nvim (was provided by NvChad)
- Kept aerial.nvim, dropbar.nvim, treesitter-context, todo-comments.nvim

- [ ] **Step 2: Commit**

```
git add lua/plugins/appearance.lua
git commit -m "refactor: remove nvim-tree/dressing, add which-key/noice/gitsigns explicitly"
```

---

### Task 11: Rewrite `lua/plugins/devtools.lua`

**Files:**
- Modify: `lua/plugins/devtools.lua`

- [ ] **Step 1: Remove telescope, add solarized-osaka + lualine + dropbar dependency update**

Replace the entire file content with:

```lua
return {
  -- Colorscheme
  {
    "craftzdog/solarized-osaka.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      transparent = true,
    },
  },

  -- Statusline
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = function()
      return require("configs.lualine")
    end,
  },

  -- Formatter
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    config = function()
      require("configs.conform")
    end,
  },

  -- Java
  {
    "nvim-java/nvim-java",
    ft = "java",
    keys = {
      "JavaBuildBuildWorkspace",
      "JavaBuildCleanWorkspace",
      "JavaRunnerRunMain",
      "JavaSettingsChangeRuntime",
    },
    config = function()
      require("configs.java")
    end,
  },

  -- LSP
  {
    "neovim/nvim-lspconfig",
    event = "User FilePost",
    config = function()
      require("configs.lsp")
    end,
  },

  -- Treesitter
  {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    build = ":TSUpdate",
    opts = function()
      return require("configs.treesitter")
    end,
    config = function(_, opts)
      require("nvim-treesitter.configs").setup(opts)
    end,
  },

  -- DAP
  {
    "rcarriga/nvim-dap-ui",
    dependencies = {
      "mfussenegger/nvim-dap",
      "nvim-neotest/nvim-nio",
      "jay-babu/mason-nvim-dap.nvim",
      "williamboman/mason.nvim",
      "theHamsta/nvim-dap-virtual-text",
      "leoluz/nvim-dap-go",
    },
    cmd = {
      "DapContinue",
      "DapToggleBreakpoint",
    },
    keys = {
      { "<F5>", function() require("dap").continue() end, { desc = "Debugger: Continue" } },
      { "<leader>b", function() require("dap").toggle_breakpoint() end, { desc = "Debugger: Toggle Breakpoint" } },
      { "<leader>du", function() require("dapui").toggle() end, { desc = "Debugger: Toggle UI" } },
    },
    config = function()
      require("configs.debug")
    end,
  },

  -- Test
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      {
        "fredrikaverpil/neotest-golang",
        dependencies = {
          "leoluz/nvim-dap-go",
        },
      },
    },
    cmd = {
      "TestNearest",
      "TestFile",
      "TestDebugNearest",
      "TestToggleSummaryPannel",
    },
    keys = {
      { "<leader>tt", "<cmd>TestNearest<CR>", { desc = "Test Nearest" } },
      { "<leader>tf", "<cmd>TestFile<CR>", { desc = "Test File" } },
      { "<leader>td", "<cmd>TestDebugNearest<CR>", { desc = "Test Debug nearest" } },
      { "<leader>ts", "<cmd>TestToggleSummaryPannel<CR>", { desc = "Test Toggle summary pannel" } },
    },
    config = function()
      require("configs.neotest")
    end,
  },

  -- Inline diagnostics
  {
    "rachartier/tiny-inline-diagnostic.nvim",
    event = "User FilePost",
    config = function()
      require("tiny-inline-diagnostic").setup()
    end,
  },

  -- Claude Code
  {
    "greggh/claude-code.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = { "ClaudeCode", "ClaudeCodeVersion" },
    keys = {
      { "<leader>cc", "<cmd>ClaudeCode<CR>", { desc = "Toggle Claude Code" } },
    },
    init = function()
      vim.api.nvim_create_autocmd("WinClosed", {
        callback = function()
          if #vim.api.nvim_list_wins() == 1 then
            local winid = vim.api.nvim_get_current_win()
            local bufnr = vim.api.nvim_win_get_buf(winid)
            if vim.api.nvim_buf_get_name(bufnr):match("^Claude Code") then
              vim.cmd("qa")
            end
          end
        end,
      })
    end,
    opts = {
      window = { position = "vertical", split_ratio = 0.40 },
      refresh = { enable = true, updatetime = 100 },
    },
  },

  -- OpenCode
  {
    "nickjvandyke/opencode.nvim",
    version = "*",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      {
        "<leader>aa",
        function()
          require("opencode").toggle()
        end,
        { desc = "Toggle OpenCode" },
      },
      {
        "<leader>as",
        function()
          require("opencode").select_server()
        end,
        { desc = "OpenCode select server" },
      },
      {
        "<leader>aA",
        function()
          require("opencode").ask("@this: ", { submit = true })
        end,
        mode = { "n", "x" },
        { desc = "Ask opencode" },
      },
    },
    init = function()
      vim.g.opencode_opts = {
        server = {
          start = function()
            require("opencode.terminal").open("opencode --port", {
              split = "right",
              width = math.floor(vim.o.columns * 0.40),
            })
          end,
          toggle = function()
            require("opencode.terminal").toggle("opencode --port", {
              split = "right",
              width = math.floor(vim.o.columns * 0.40),
            })
          end,
        },
      }
      vim.api.nvim_create_autocmd("WinClosed", {
        callback = function()
          if #vim.api.nvim_list_wins() == 1 then
            local winid = vim.api.nvim_get_current_win()
            local bufnr = vim.api.nvim_win_get_buf(winid)
            if vim.api.nvim_buf_get_name(bufnr):match("^opencode") then
              vim.cmd("qa")
            end
          end
        end,
      })
    end,
  },

  -- Go modify tags
  {
    "zgs225/gomodifytags.nvim",
    cmd = { "GoAddTags", "GoRemoveTags", "GoInstallModifyTagsBin" },
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
    },
    config = function()
      require("gomodifytags").setup()
    end,
  },

  -- Git worktree
  {
    "ThePrimeagen/git-worktree.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      {
        "<leader>gw",
        function()
          require("telescope").extensions.git_worktree.git_worktrees()
        end,
        desc = "Git worktree list/switch/delete",
      },
      {
        "<leader>gW",
        function()
          require("telescope").extensions.git_worktree.create_git_worktree()
        end,
        desc = "Git worktree create",
      },
    },
    config = function()
      local Worktree = require("git-worktree")

      Worktree.setup({
        change_directory_command = "cd",
        update_on_change = true,
        update_on_change_command = "e .",
        clearjumps_on_change = true,
        autopush = false,
      })

      Worktree.on_tree_change(function(op, metadata)
        if op == Worktree.Operations.Switch then
          vim.notify(
            string.format("Switched worktree: %s -> %s", metadata.prev_path, metadata.path),
            vim.log.levels.INFO,
            { title = "Git Worktree" }
          )
          pcall(function()
            local dap = require("dap")
            dap.clear_breakpoints()
            if dap.session() then
              dap.close()
            end
          end)
        elseif op == Worktree.Operations.Create then
          vim.notify(
            string.format("Created worktree: %s (branch: %s)", metadata.path, metadata.branch),
            vim.log.levels.INFO,
            { title = "Git Worktree" }
          )
        elseif op == Worktree.Operations.Delete then
          vim.notify(
            string.format("Deleted worktree: %s", metadata.path),
            vim.log.levels.INFO,
            { title = "Git Worktree" }
          )
        end
      end)
    end,
  },
}
```

Key changes:
- Added craftzdog/solarized-osaka.nvim (colorscheme, transparent=true, priority=1000)
- Added nvim-lualine/lualine.nvim (statusline)
- Removed telescope integration from treesitter (no more dofile(base46_cache.."treesitter"))
- Removed dap base46 cache loading
- Removed nvim-tree.api reference from git-worktree callback
- Removed FixCursorHold.nvim from neotest dependencies
- Kept everything else unchanged

Note: git-worktree still references `require("telescope").extensions.git_worktree` — this will be updated in Task 14.

- [ ] **Step 2: Commit**

```
git add lua/plugins/devtools.lua
git commit -m "refactor: add solarized-osaka/lualine, remove NvChad telescope/base46 refs"
```

---

### Task 12: Rewrite `lua/mappings.lua`

**Files:**
- Modify: `lua/mappings.lua`

- [ ] **Step 1: Remove nvchad.mappings dependency, rewrite with snacks mappings**

Replace the entire file content with:

```lua
local map = vim.keymap.set

-- General
map("n", ";", ":", { desc = "CMD enter command mode" })
map("n", "<leader>w", ":w<CR>", { desc = "Save current buffer" })

-- Tab navigation
map("n", "tp", ":tabprevious<CR>", { desc = "Tab previous" })
map("n", "tn", ":tabnext<CR>", { desc = "Tab next" })
map("n", "tm", ":tabmove", { desc = "Tab move" })

-- LSP diagnostics popup
map("n", "<leader>dp", function()
  vim.diagnostic.open_float({ scope = "l" })
end, { desc = "LSP Diagnostics under cursor" })

-- Flash (s, S, r, R, <C-s> handled in flash.lua plugin spec)
-- No need to remap here

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
```

Key changes:
- Removed `require "nvchad.mappings"`
- Removed `<leader>q` (replaced by snacks.bufdelete `<leader>bd`)
- Removed `<C-p>` (replaced by snacks.picker.files `<leader>ff`)
- Removed `<leader>n` nvimtree focus (replaced by snacks.explorer `<leader>e`)
- Kept `;`, `<leader>w`, tp/tn/tm, `<leader>dp`, terminal navigation

- [ ] **Step 2: Commit**

```
git add lua/mappings.lua
git commit -m "refactor: remove nvchad.mappings, update for snacks key scheme"
```

---

### Task 13: Rewrite `init.lua`

**Files:**
- Modify: `init.lua`

- [ ] **Step 1: Remove all NvChad references, set up snacks-based bootstrap**

Replace the entire file content with:

```lua
vim.g.mapleader = ","
vim.g.maplocalleader = ","

-- bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.uv.fs_stat(lazypath) then
  local repo = "https://github.com/folke/lazy.nvim.git"
  vim.fn.system({ "git", "clone", "--filter=blob:none", repo, "--branch=stable", lazypath })
end

vim.opt.rtp:prepend(lazypath)

local lazy_config = require("configs.lazy")

require("lazy").setup({
  { import = "plugins" },
}, lazy_config)

vim.cmd.colorscheme("solarized-osaka")

require("options")
require("autocmds")

vim.schedule(function()
  require("mappings")
end)
```

Key changes:
- Removed `vim.g.base46_cache`
- Removed NvChad import block
- Removed `dofile(base46_cache.."syntax")` etc
- Removed `require "nvchad.autocmds"`
- Removed `require "nvchad.options"` from config callback
- Added `vim.cmd.colorscheme("solarized-osaka")`
- Added `require("autocmds")`
- Kept lazy.nvim bootstrap
- Kept `vim.schedule(mappings)` pattern

- [ ] **Step 2: Commit**

```
git add init.lua
git commit -m "refactor: rewrite init.lua to remove NvChad, use snacks-based bootstrap"
```

---

### Task 14: Update git-worktree for snacks.picker

**Files:**
- Modify: `lua/plugins/devtools.lua` (git-worktree section)

- [ ] **Step 1: Replace telescope-based worktree picker with snacks.picker integration**

Replace the git-worktree keymaps and config in `lua/plugins/devtools.lua`:

First, change the keys section from telescope to local function:

```lua
    keys = {
      {
        "<leader>gw",
        function()
          local worktrees = vim.fn.systemlist("git worktree list --porcelain")
          if vim.v.shell_error ~= 0 then
            vim.notify("Not in a git repository", vim.log.levels.WARN)
            return
          end
          local items = {}
          local current = {}
          for _, line in ipairs(worktrees) do
            if line:match("^worktree ") then
              current = { path = line:gsub("^worktree ", "") }
            elseif line:match("^HEAD ") then
              current.branch = line:gsub("^HEAD ", "")
            elseif line:match("^branch ") then
              current.branch = line:gsub("^branch ", "refs/heads/")
            elseif line:match("^bare$") then
              table.insert(items, {
                text = current.branch or current.path,
                path = current.path,
                branch = current.branch,
              })
              current = {}
            elseif line:match("^detached$") then
              table.insert(items, {
                text = "(detached) " .. current.path,
                path = current.path,
                branch = nil,
              })
              current = {}
            end
          end
          -- Use vim.ui.select for worktree switching
          vim.ui.select(items, {
            prompt = "Select worktree:",
            format_item = function(item)
              return item.text
            end,
          }, function(choice)
            if not choice then
              return
            end
            vim.cmd("cd " .. choice.path)
            vim.notify(string.format("Switched to: %s", choice.path), vim.log.levels.INFO)
            -- Clear DAP
            pcall(function()
              local dap = require("dap")
              dap.clear_breakpoints()
              if dap.session() then
                dap.close()
              end
            end)
            vim.cmd("e .")
          end)
        end,
        desc = "Git worktree list/switch",
      },
      {
        "<leader>gW",
        function()
          vim.ui.input({ prompt = "New worktree path: " }, function(path)
            if not path or path == "" then
              return
            end
            vim.ui.input({ prompt = "Branch name (optional): " }, function(branch)
              local cmd = { "git", "worktree", "add", path }
              if branch and branch ~= "" then
                vim.list_extend(cmd, { "-b", branch })
              end
              local output = vim.fn.system(cmd)
              if vim.v.shell_error ~= 0 then
                vim.notify("Failed to create worktree: " .. output, vim.log.levels.ERROR)
              else
                vim.notify("Created worktree: " .. path, vim.log.levels.INFO)
              end
            end)
          end)
        end,
        desc = "Git worktree create",
      },
    },
```

And simplify the config function to remove telescope dependency:

```lua
    config = function()
      local Worktree = require("git-worktree")

      Worktree.setup({
        change_directory_command = "cd",
        update_on_change = true,
        update_on_change_command = "e .",
        clearjumps_on_change = true,
        autopush = false,
      })

      Worktree.on_tree_change(function(op, metadata)
        if op == Worktree.Operations.Switch then
          vim.notify(
            string.format("Switched worktree: %s -> %s", metadata.prev_path, metadata.path),
            vim.log.levels.INFO,
            { title = "Git Worktree" }
          )
          pcall(function()
            local dap = require("dap")
            dap.clear_breakpoints()
            if dap.session() then
              dap.close()
            end
          end)
        elseif op == Worktree.Operations.Create then
          vim.notify(
            string.format("Created worktree: %s (branch: %s)", metadata.path, metadata.branch),
            vim.log.levels.INFO,
            { title = "Git Worktree" }
          )
        elseif op == Worktree.Operations.Delete then
          vim.notify(
            string.format("Deleted worktree: %s", metadata.path),
            vim.log.levels.INFO,
            { title = "Git Worktree" }
          )
        end
      end)
    end,
```

- [ ] **Step 2: Commit**

```
git add lua/plugins/devtools.lua
git commit -m "refactor: replace telescope-based git-worktree with vim.ui.select"
```

---

### Task 15: Delete legacy files

**Files:**
- Delete: `lua/chadrc.lua`
- Delete: `lua/plugins/notify.lua`

- [ ] **Step 1: Remove NvChad config and notify plugin files**

```
rm lua/chadrc.lua
rm lua/plugins/notify.lua
```

- [ ] **Step 2: Commit**

```
git rm lua/chadrc.lua lua/plugins/notify.lua
git commit -m "chore: remove NvChad chadrc.lua and replaced notify.lua"
```

---

### Task 16: Final verification

**Files:**
- None (read-only verification)

- [ ] **Step 1: Validate file structure**

```
ls -la /Users/yuez/dotfiles/config/nvim/init.lua
ls -la /Users/yuez/dotfiles/config/nvim/lua/autocmds.lua
ls -la /Users/yuez/dotfiles/config/nvim/lua/options.lua
ls -la /Users/yuez/dotfiles/config/nvim/lua/mappings.lua
ls /Users/yuez/dotfiles/config/nvim/lua/configs/
ls /Users/yuez/dotfiles/config/nvim/lua/plugins/
```

Expected: All files exist, `chadrc.lua` and `notify.lua` are gone.

- [ ] **Step 2: Run Neovim headless to verify no startup errors**

```
nvim --headless -c 'lua print("startup ok")' -c 'qa' 2>&1
```

Expected: Output shows "startup ok" with no Lua errors.

- [ ] **Step 3: Verify lazy.nvim plugin loading**

```
nvim --headless -c 'Lazy! check' -c 'qa' 2>&1
```

Expected: All plugins resolved, no missing dependencies.

- [ ] **Step 4: Verify snacks health**

```
nvim --headless -c 'checkhealth snacks' -c 'qa' 2>&1
```

Expected: snacks features report healthy.

- [ ] **Step 5: Commit final verification notes**

No code changes to commit (verification only).
