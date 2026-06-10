# Unify DAP Keymaps Under `,d` Prefix

## Changes

### 1. `lua/plugins/devtools.lua` — Replace DAP keys block (lines 62-83)

Replace the old 3-key block:
```
<F5>           → DAP Continue
<leader>b (`,b`)  → Toggle Breakpoint (conflicts with NvChad)
<leader>du (`,du`) → Toggle DAP UI
```

With 11 new `,d`-prefixed keys:

| Key | Action | Function |
|-----|--------|----------|
| `,dc` | Continue | `dap.continue()` |
| `,db` | Toggle Breakpoint | `dap.toggle_breakpoint()` |
| `,dB` | Conditional Breakpoint | `dap.set_breakpoint(condition)` with input prompt |
| `,du` | Toggle DAP UI | `dapui.toggle()` (keep) |
| `,dr` | Restart Session | `dap.restart()` |
| `,dt` | Terminate Session | `dap.terminate()` |
| `,do` | Step Over | `dap.step_over()` |
| `,di` | Step Into | `dap.step_into()` |
| `,dO` | Step Out | `dap.step_out()` |
| `,dR` | Run to Cursor | `dap.run_to_cursor()` |
| `,dh` | Evaluate/Hover | `dap.ui.widgets.hover()` |

### 2. `lua/configs/debug.lua` — Remove obsolete code

Remove:
- `map` variable (line 2) — no longer used
- `<M-r>` Restart keymap (lines 39-41) — replaced by `,dr`
- `<M-s>` Terminate keymap (lines 43-45) — replaced by `,dt`
- `dap.listeners.after.event_initialized["dap_keys"]` block (lines 47-51) — F10-F12 replaced by `,do`/`,di`/`,dO`
- `clear_dap_keys()` function (lines 53-57) — no longer needed
- `event_terminated` and `event_exited` listeners (lines 59-60) — no longer needed

Keep:
- `nvim-dap-virtual-text` setup
- `dap-go` setup
- `mason-nvim-dap` setup
- `codelldb` adapter
- DAP UI auto-open/close listeners
- DAP UI layout config
