# Picom Glassmorphism Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current picom config with the full glassmorphism design from the spec.

**Architecture:** Single-file config replacement. The spec already contains the complete target config — replace `dot_config/picom/picom.conf` with the target config and validate that picom accepts it.

**Tech Stack:** picom v13 (native corner-radius support), dual_kawase blur backend, glx backend.

## Global Constraints

- Only modify `dot_config/picom/picom.conf` — no other files
- Must preserve existing excludes for Polybar, i3bar, Dunst
- picom v13 must accept the config without errors
- Per AGENTS.md: never run `chezmoi apply`; edit source files only

---

### Task 1: Replace picom.conf with glassmorphism config

**Files:**
- Modify: `dot_config/picom/picom.conf`

**Interfaces:**
- Consumes: Full target config from spec at `docs/superpowers/specs/2026-07-06-picom-glassmorphism-design.md`
- Produces: Updated picom.conf with all glassmorphism parameters

- [ ] **Step 1: Replace the entire picom.conf with the target config**

Write the following content to `dot_config/picom/picom.conf`:

```conf
# Picom compositor config — glassmorphism

backend = "glx";
vsync = true;

# Shadows — soft floating effect
shadow = true;
shadow-radius = 25;
shadow-offset-x = -15;
shadow-offset-y = -15;
shadow-opacity = 0.15;
shadow-clipping = true;
shadow-exclude = [
    "class_g = 'Polybar'",
    "class_g = 'i3bar'",
    "name = 'Notification'",
    "class_g = 'Dunst'",
    "class_g = 'slop'",
];

# Fading — snappy
fading = true;
fade-in-step = 0.06;
fade-out-step = 0.06;
fade-delta = 4;

# Opacity — frosted glass layering
inactive-opacity = 0.85;
active-opacity = 1.0;
frame-opacity = 0.80;
inactive-opacity-override = false;

opacity-rule = [
    "90:class_g = 'i3bar'",
    "90:class_g = 'Polybar'",
    "100:class_g = 'Rofi'",
    "85:class_g = 'WezTerm'",
];

# Blur — heavy frosted glass
blur-background = true;
blur-method = "dual_kawase";
blur-strength = 8;
blur-background-frame = false;
blur-background-fixed = false;

blur-background-exclude = [
    "class_g = 'Polybar'",
    "class_g = 'i3bar'",
    "class_g = 'Dunst'",
    "class_g = 'slop'",
    "window_type = 'dock'",
    "window_type = 'desktop'",
];

# Rounded corners
corner-radius = 10;
detect-rounded-corners = true;

rounded-corners-exclude = [
    "class_g = 'slop'",
    "window_type = 'dock'",
    "window_type = 'desktop'",
];

corner-radius-rules = [
    "0:class_g = 'Rofi'",
];

# Misc
unredir-if-possible = false;
no-fading-openclose = false;
no-fading-destroyed-argb = true;
detect-client-opacity = true;
detect-transient = true;

# Window type settings
wintypes:
{
    tooltip = { fade = true; shadow = true; opacity = 0.90; focus = true; full-shadow = false; };
    dock = { shadow = false; };
    dnd = { shadow = false; };
    popup_menu = { opacity = 0.95; };
    dropdown_menu = { opacity = 0.95; };
};
```

- [ ] **Step 2: Validate config syntax**

Run: `picom --config /home/yuez/.local/share/chezmoi/dot_config/picom/picom.conf --benchmark 2>&1 | head -5`
Expected: No parse errors. Picom may fail to start (no display in this session) but should not report config syntax errors.

- [ ] **Step 3: Commit**

```bash
git add dot_config/picom/picom.conf
git commit -m "feat(picom): glassmorphism — rounded corners, soft shadows, frosted blur, snappy fades"
```
