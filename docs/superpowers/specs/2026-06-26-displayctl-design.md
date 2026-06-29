# displayctl Design Spec

## Problem

A single X11 `:0` session on `Virtual-1` is shared across multiple remote clients (XRDP, Sunshine) and local physical monitors. The same `Virtual-1` output needs different modes depending on the client, but EDID never changes — so autorandr's EDID-matching profiles are useless. Additionally, XRDP dynamically resizes `Virtual-1` to match the connecting client's resolution, requiring automatic DPI refresh on every resize.

## Solution

A single Go binary (`displayctl`) with two modes of operation:

1. **`apply`** — one-shot command to apply a profile (set xrandr mode + DPI)
2. **`daemon`** — long-running process that monitors RandR events and auto-refreshes DPI when resolution changes

## CLI

```
displayctl apply <profile|WxH|auto>    # Apply a named profile, a temporary WxH mode, or the default profile
displayctl list                        # List available profiles with summary
displayctl current                     # Show current xrandr mode + DPI
displayctl daemon                      # Long-lived: watch RandR events, auto-refresh DPI
```

### `apply` subcommand

| Argument | Behavior |
|----------|----------|
| `auto` | Find and apply the profile with `default = true` |
| `<profile-name>` | Load `profiles/<name>.toml` and apply |
| `<WxH>` (e.g. `2560x1440`) | Recognized as resolution; auto-detect active output via `xrandr GetActiveOutput()`, apply mode with `dpi.tiers = true` |

### Exit codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Profile not found |
| 3 | xrandr execution failed |
| 4 | No default profile found (only for `auto`) |

## Profile Format (TOML)

```toml
# xrdp.toml — XRDP sets the mode itself, don't override
default = false

[output]
name = "Virtual-1"
mode = "current"     # "current" = skip xrandr --mode, only set DPI

[dpi]
tiers = true         # Auto-calculate DPI from current resolution width
```

```toml
# sunshine.toml
default = false

[output]
name = "Virtual-1"
mode = "3840x2160"
rate = 60

[dpi]
value = 192          # Fixed DPI value; takes priority over tiers
```

```toml
# monitor.toml
default = true

[output]
name = "Virtual-1"
mode = "3840x2160"

[dpi]
value = 192
```

### Fields

| Field | Required | Description |
|-------|----------|-------------|
| `default` | No | `true` marks this as the profile for `apply auto`. Default: `false` |
| `output.name` | Yes | xrandr output name (e.g. `Virtual-1`) |
| `output.mode` | Yes | `WxH` string or `"current"` (skip mode change) |
| `output.rate` | No | Refresh rate. If omitted, xrandr picks default |
| `dpi.value` | No* | Fixed DPI value. Priority over `tiers` |
| `dpi.tiers` | No* | `true` = calculate DPI from resolution width |

*At least one of `dpi.value` or `dpi.tiers` should be set. If neither, DPI is not changed.

### DPI tiers logic

| Screen width | DPI |
|-------------|-----|
| >= 3000 | 192 (retina) |
| >= 2700 | 168 |
| >= 2000 | 144 (hidpi) |
| < 2000 | 96 (normal) |

## Event-Driven Profile Selection

Profiles are **not** auto-detected by environment sniffing. Instead, the caller explicitly specifies the profile:

| Scenario | Trigger | Command |
|----------|---------|---------|
| i3 startup | i3 `exec_always` autostart | `displayctl apply auto` |
| XRDP login | XRDP `startwm.sh` | `displayctl apply xrdp` |
| XRDP client resize | `displayctl daemon` (RandR event) | Auto DPI refresh |
| Sunshine connect | Sunshine `on_connect` hook | `displayctl apply sunshine` |
| Manual switch | User terminal | `displayctl apply 2560x1440` |

Rationale: environment detection (checking env vars, processes) is unreliable. XRDP env vars may not be set; Sunshine is always running regardless of client connection state. Explicit invocation by the event source is more robust.

## `daemon` subcommand

- Uses `github.com/Burntsush/xgb` + `xgb/randr` to subscribe to `RRScreenChangeNotify` events
- On event: read current mode width from xrandr → compute DPI via tiers → update `Xft.dpi` via xrdb → update `/tmp/rofi-dpi.rasi` → execute `post-switch.d/` hooks
- Never changes xrandr mode — only refreshes DPI and downstream
- Started by i3 autostart: `exec displayctl daemon`

## Hooks

### `post-switch.d/`

Directory: `~/.config/display/post-switch.d/`

- All executable files in this directory are run (sorted by filename) after a successful mode/DPI change
- Each hook receives environment variables:
  - `DISPLAYCTL_OUTPUT` — output name (e.g. `Virtual-1`)
  - `DISPLAYCTL_MODE` — new mode (e.g. `3840x2160`)
  - `DISPLAYCTL_DPI` — new DPI value (e.g. `192`)
- No `pre-switch` hooks — xrandr mode changes don't require rollback

### Hook examples

```sh
# post-switch.d/10-polybar
#!/bin/sh
~/.config/polybar/launch.sh &
```

## Configuration Paths

| Path | Default | Override |
|------|---------|----------|
| Config dir | `~/.config/display` | `DISPLAYCTL_DIR` env var |
| Profiles | `<dir>/profiles/*.toml` | — |
| Post-switch hooks | `<dir>/post-switch.d/` | — |

## Go Project Structure

```
displayctl/
├── main.go
├── go.mod
├── go.sum
├── cmd/
│   ├── root.go              # cobra root, persistent flags
│   ├── apply.go             # apply subcommand
│   ├── list.go              # list subcommand
│   ├── current.go           # current subcommand
│   └── daemon.go            # daemon subcommand
├── internal/
│   ├── xrandr/              # xrandr CLI wrapper (get/set mode, list outputs)
│   ├── dpi/                 # DPI calculation (tiers), xrdb write, rofi-dpi.rasi
│   ├── profile/             # TOML profile loading and validation
│   ├── hook/                # post-switch.d/ execution
│   └── randr/               # xgb RandR event listener
├── config/
│   └── defaults.go          # Default paths, DPI tier thresholds
```

### Dependencies

| Library | Purpose |
|---------|---------|
| `github.com/spf13/cobra` | CLI framework |
| `github.com/Burntsushi/xgb` | X11 protocol |
| `github.com/Burntsushi/xgb/randr` | RandR extension |
| `github.com/pelletier/go-toml/v2` | TOML parsing |

### `internal/xrandr/`

- `GetActiveOutput() (string, error)` — return currently connected+active output name
- `GetCurrentMode(output string) (string, error)` — return current mode (e.g. `3840x2160`)
- `SetMode(output, mode string, rate int) error` — execute `xrandr --output <output> --mode <mode>`
- `ValidateMode(output, mode string) (bool, error)` — check if mode is supported
- `GetScreenSize() (int, int, error)` — get current screen width/height

### `internal/dpi/`

- `CalculateFromTiers(width int) int` — width → DPI via tier thresholds
- `SetXftDPI(dpi int) error` — `xrdb -merge` to set `Xft.dpi`
- `WriteRofiDPI(dpi int) error` — write `/tmp/rofi-dpi.rasi`
- `GetCurrentDPI() (int, error)` — read from `xrdb -query`

### `internal/profile/`

- `Load(dir, name string) (*Profile, error)` — parse `profiles/<name>.toml`
- `LoadDefault(dir string) (*Profile, error)` — find `default = true` profile
- `List(dir string) ([]ProfileSummary, error)` — scan profiles dir

### `internal/hook/`

- `RunPostSwitch(dir string, env map[string]string) error` — execute `post-switch.d/*` with env vars

### `internal/randr/`

- `Watch(display string, onChange func()) error` — subscribe to RRScreenChangeNotify, call callback on change

## Dotfiles Integration

### Files to add (chezmoi source)

| Source | Deployed to |
|--------|-------------|
| `dot_config/display/profiles/xrdp.toml` | `~/.config/display/profiles/xrdp.toml` |
| `dot_config/display/profiles/sunshine.toml` | `~/.config/display/profiles/sunshine.toml` |
| `dot_config/display/profiles/monitor.toml` | `~/.config/display/profiles/monitor.toml` |
| `dot_config/display/post-switch.d/` | `~/.config/display/post-switch.d/` |

### Files to modify

| File | Change |
|------|--------|
| `dot_config/i3/config.tmpl` | Replace `exec_always set-dpi.sh` with `exec_always displayctl apply auto`; add `exec displayctl daemon` |
| `dot_config/polybar/executable_launch.sh` | Remove `set-dpi.sh` / `dpi-mode` calls; read DPI from xrdb directly |
| `dot_xinitrc` | Remove hardcoded `xrandr --output Virtual-1 --mode 3840x2160`; add `displayctl apply auto` |

### Files to remove

| File | Reason |
|------|--------|
| `dot_bin/executable_set-dpi.sh` | Replaced by `displayctl` |
| `dot_bin/executable_dpi-mode` | Replaced by `displayctl current` |

## displayctl source repo

The Go source code lives in an **independent repository** (not inside dotfiles). The compiled binary is deployed to `~/.bin/displayctl` (managed by mise or manual install).
