# Nvim DAP Debug Optimization

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 DAP 调试体验升级为 IDE-standard 方案: F5/F10/F11/F12 键位、nvim-dap-go 接管 Go 配置、nvim-dap-virtual-text 行内变量显示、launch.json 支持、session 生命周期自动挂载/卸载步进键。

**Architecture:** 4 个文件变更。`mappings.lua` 释放 F5；`devtools.lua` 扩展 DAP 插件依赖和懒加载键位；`dap.lua` 全面重写；`utils.lua` 删除无引用文件。

**Tech Stack:** nvim-dap, nvim-dap-ui, nvim-dap-go, nvim-dap-virtual-text, mason-nvim-dap, lazy.nvim

---

### Task 1: 释放 F5 — mappings.lua

**Files:**
- Modify: `/Users/yuez/dotfiles/config/nvim/lua/mappings.lua:16`

- [ ] **Step 1: 删除 F5 → NvimTreeToggle 映射**

删除第 16 行:
```lua
map("n", "<F5>", "<cmd>NvimTreeToggle<CR>", { desc = "nvimtree toggle window" })
```

保留 `<leader>n → NvimTreeFocus` 和 NvChad 内置的 `<C-n> → NvimTreeToggle`。

- [ ] **Step 2: 验证文件语法**

Run:
```bash
nvim -l /Users/yuez/dotfiles/config/nvim/lua/mappings.lua -c 'lua print("OK")' -c 'qall!'
```
Expected: prints "OK", no errors.

- [ ] **Step 3: Commit**

```bash
git add /Users/yuez/dotfiles/config/nvim/lua/mappings.lua
git commit -m "fix(dap): release F5 from NvimTree for DAP continue"
```

---

### Task 2: DAP 插件声明更新 — devtools.lua

**Files:**
- Modify: `/Users/yuez/dotfiles/config/nvim/lua/plugins/devtools.lua:48-69`

- [ ] **Step 1: 替换 DAP 插件 spec**

将第 48-69 行（`-- DAP 调试` 注释块）替换为:

```lua
  -- DAP 调试
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
      dofile(vim.g.base46_cache .. "dap")
      require "configs.dap"
    end,
  },
```

变更点:
- 依赖新增 `theHamsta/nvim-dap-virtual-text` 和 `leoluz/nvim-dap-go`
- `cmd` 精简为 `DapContinue` / `DapToggleBreakpoint`
- `keys` 替换: F8/F9 → F5/`<leader>b`/`<leader>du`，使用 lua 函数触发 lazy-load

- [ ] **Step 2: 验证文件语法**

Run:
```bash
nvim -l /Users/yuez/dotfiles/config/nvim/lua/plugins/devtools.lua -c 'lua print("OK")' -c 'qall!'
```
Expected: prints "OK", no errors.

- [ ] **Step 3: Commit**

```bash
git add /Users/yuez/dotfiles/config/nvim/lua/plugins/devtools.lua
git commit -m "feat(dap): add dap-go dap-virtual-text deps, remap keys to IDE-standard scheme"
```

---

### Task 3: DAP 运行配置重写 — dap.lua

**Files:**
- Modify: `/Users/yuez/dotfiles/config/nvim/lua/configs/dap.lua` (full rewrite, 156 → ~80 lines)

- [ ] **Step 1: 写入新 dap.lua**

将整个文件内容替换为:

```lua
local dap, dapui = require "dap", require "dapui"
local map = vim.keymap.set

require("nvim-dap-virtual-text").setup()

require("dap.ext.vscode").load_launchjs(nil, {
  codelldb = { "c", "cpp", "rust" },
  delve = { "go" },
})

require("dap-go").setup({
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
        { id = "repl", size = 1 },
      },
      position = "bottom",
      size = 10,
    },
  },
})
```

- [ ] **Step 2: 验证文件语法**

Run:
```bash
nvim -l /Users/yuez/dotfiles/config/nvim/lua/configs/dap.lua -c 'lua print("OK")' -c 'qall!'
```
Expected: prints "OK", no errors.

- [ ] **Step 3: Commit**

```bash
git add /Users/yuez/dotfiles/config/nvim/lua/configs/dap.lua
git commit -m "feat(dap): rewrite with dap-go, virtual-text, launch.json, session-scoped step keys"
```

---

### Task 4: 删除无引用的 utils.lua

**Files:**
- Delete: `/Users/yuez/dotfiles/config/nvim/lua/configs/utils.lua`

`utils.lua` 仅被旧 dap.lua 的 `get_arguments` 引用，已由 `require("dap-go").get_arguments` 替代，全仓库无其他引用。

- [ ] **Step 1: 删除文件**

```bash
rm /Users/yuez/dotfiles/config/nvim/lua/configs/utils.lua
```

- [ ] **Step 2: 确认无残留引用**

```bash
grep -r "configs\.utils" /Users/yuez/dotfiles/config/nvim/lua/ /Users/yuez/dotfiles/config/nvim/init.lua
```
Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add /Users/yuez/dotfiles/config/nvim/lua/configs/utils.lua
git commit -m "refactor(dap): remove unused utils.lua, replaced by dap-go.get_arguments"
```

---

## Verification

完成所有 Task 后，确认:

1. **语法检查** — 所有 Lua 文件无语法错误:
```bash
for f in /Users/yuez/dotfiles/config/nvim/lua/mappings.lua \
         /Users/yuez/dotfiles/config/nvim/lua/plugins/devtools.lua \
         /Users/yuez/dotfiles/config/nvim/lua/configs/dap.lua; do
  echo "=== $f ==="
  nvim -l "$f" -c 'lua print("OK")' -c 'qall!' 2>&1 || true
done
```

2. **插件安装** — 在 Neovim 中运行 `:Lazy sync` 安装 `nvim-dap-virtual-text` 并确认 `nvim-dap-go` 作为直接依赖加载

3. **功能验证** — 打开 Go 项目，验证:
   - `F5` 弹出 debug configuration 选择列表
   - 选择 Debug 后，dap-ui 自动打开
   - `F10`/`F11`/`F12` 可正常步进
   - 结束调试后 `F10`/`F11`/`F12` 失效
   - 代码行末显示变量当前值
   - `<leader>b` 切换断点
   - `<leader>du` 开关 dap-ui

## Key bindings summary (after all changes)

| Key | Scope | Action |
|-----|-------|--------|
| `F5` | Always | Continue / Start debugging |
| `<leader>b` | Always | Toggle breakpoint |
| `<leader>du` | Always | Toggle DAP UI |
| `F10` | Debug session only | Step Over |
| `F11` | Debug session only | Step Into |
| `F12` | Debug session only | Step Out |
| `<M-r>` | Always | Restart debugger |
| `<M-s>` | Always | Terminate debugger |
| `<C-n>` | Always | NvimTree toggle (NvChad built-in) |
| `<leader>n` | Always | NvimTree focus |
