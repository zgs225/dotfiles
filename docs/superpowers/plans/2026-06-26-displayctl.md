# displayctl Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Go CLI tool that manages xrandr display modes and DPI settings across XRDP, Sunshine, and local monitor scenarios, with a daemon that auto-refreshes DPI on RandR resolution changes.

**Architecture:** Single Go binary with cobra subcommands (`apply`, `list`, `current`, `daemon`). TOML-based profiles define output name, mode, and DPI. The daemon uses xgb to listen for RandR events and auto-refresh DPI. Event-driven profile selection — callers explicitly specify the profile rather than auto-detecting environment.

**Tech Stack:** Go 1.26, cobra, xgb, go-toml/v2

## Global Constraints

- Go module name: `github.com/yuez/displayctl`
- Config dir default: `~/.config/display`, overridable by `DISPLAYCTL_DIR` env var
- DPI tiers: >=3000→192, >=2700→168, >=2000→144, <2000→96
- Exit codes: 0=success, 1=general error, 2=profile not found, 3=xrandr failed, 4=no default profile
- Profile mode `"current"` means skip xrandr --mode, only set DPI
- `dpi.value` takes priority over `dpi.tiers`; if neither set, skip DPI
- Source repo is independent from dotfiles; compiled binary deploys to `~/.bin/displayctl`

---

## File Structure

```
displayctl/
├── main.go
├── go.mod
├── go.sum
├── cmd/
│   ├── root.go
│   ├── apply.go
│   ├── list.go
│   ├── current.go
│   └── daemon.go
├── internal/
│   ├── xrandr/
│   │   └── xrandr.go
│   ├── dpi/
│   │   └── dpi.go
│   ├── profile/
│   │   └── profile.go
│   ├── hook/
│   │   └── hook.go
│   └── randr/
│       └── randr.go
├── config/
│   └── defaults.go
```

---

### Task 1: Project Scaffolding and Go Module Init

**Files:**
- Create: `main.go`
- Create: `go.mod`
- Create: `cmd/root.go`
- Create: `config/defaults.go`

**Interfaces:**
- Produces: `config.ConfigDir()` returning `string`, `cmd.NewRootCmd()` returning `*cobra.Command`

- [ ] **Step 1: Create project directory and init Go module**

```bash
mkdir -p /tmp/displayctl/cmd /tmp/displayctl/config /tmp/displayctl/internal/xrandr /tmp/displayctl/internal/dpi /tmp/displayctl/internal/profile /tmp/displayctl/internal/hook /tmp/displayctl/internal/randr
cd /tmp/displayctl
git init
go mod init github.com/yuez/displayctl
```

- [ ] **Step 2: Write config/defaults.go**

```go
package config

import (
	"os"
	"path/filepath"
)

func ConfigDir() string {
	if dir := os.Getenv("DISPLAYCTL_DIR"); dir != "" {
		return dir
	}
	home, err := os.UserHomeDir()
	if err != nil {
		panic(err)
	}
	return filepath.Join(home, ".config", "display")
}

func ProfilesDir() string {
	return filepath.Join(ConfigDir(), "profiles")
}

func PostSwitchDir() string {
	return filepath.Join(ConfigDir(), "post-switch.d")
}
```

- [ ] **Step 3: Write cmd/root.go**

```go
package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
)

func NewRootCmd() *cobra.Command {
	root := &cobra.Command{
		Use:   "displayctl",
		Short: "Manage xrandr display modes and DPI settings",
	}
	return root
}

func Execute() {
	root := NewRootCmd()
	if err := root.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
```

- [ ] **Step 4: Write main.go**

```go
package main

import "github.com/yuez/displayctl/cmd"

func main() {
	cmd.Execute()
}
```

- [ ] **Step 5: Add cobra dependency and verify build**

```bash
cd /tmp/displayctl
go get github.com/spf13/cobra
go build ./...
```

- [ ] **Step 6: Commit**

```bash
cd /tmp/displayctl
git add -A
git commit -m "feat: project scaffolding with cobra root command"
```

---

### Task 2: internal/xrandr — xrandr CLI Wrapper

**Files:**
- Create: `internal/xrandr/xrandr.go`

**Interfaces:**
- Produces: `xrandr.GetActiveOutput() (string, error)`, `xrandr.GetCurrentMode(output string) (string, error)`, `xrandr.SetMode(output, mode string, rate int) error`, `xrandr.ValidateMode(output, mode string) (bool, error)`, `xrandr.GetScreenSize() (int, int, error)`

- [ ] **Step 1: Write internal/xrandr/xrandr.go**

```go
package xrandr

import (
	"fmt"
	"os/exec"
	"regexp"
	"strconv"
	"strings"
)

func runXrandr(args ...string) (string, error) {
	cmd := exec.Command("xrandr", args...)
	out, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("xrandr %s: %w: %s", strings.Join(args, " "), err, string(out))
	}
	return string(out), nil
}

func GetActiveOutput() (string, error) {
	out, err := runXrandr("--current")
	if err != nil {
		return "", err
	}
	re := regexp.MustCompile(`^(\S+)\s+connected\s+primary\s+\d+x\d+`)
	for _, line := range strings.Split(out, "\n") {
		if m := re.FindStringSubmatch(line); m != nil {
			return m[1], nil
		}
	}
	re2 := regexp.MustCompile(`^(\S+)\s+connected\s+\d+x\d+`)
	for _, line := range strings.Split(out, "\n") {
		if m := re2.FindStringSubmatch(line); m != nil {
			return m[1], nil
		}
	}
	return "", fmt.Errorf("no connected output found")
}

func GetCurrentMode(output string) (string, error) {
	out, err := runXrandr("--current")
	if err != nil {
		return "", err
	}
	pattern := fmt.Sprintf(`^%s\s+connected\s+(?:primary\s+)?(\d+x\d+)`, regexp.QuoteMeta(output))
	re := regexp.MustCompile(pattern)
	for _, line := range strings.Split(out, "\n") {
		if m := re.FindStringSubmatch(line); m != nil {
			return m[1], nil
		}
	}
	return "", fmt.Errorf("output %s not found or not active", output)
}

func SetMode(output, mode string, rate int) error {
	args := []string{"--output", output, "--mode", mode}
	if rate > 0 {
		args = append(args, "--rate", strconv.Itoa(rate))
	}
	_, err := runXrandr(args...)
	return err
}

func ValidateMode(output, mode string) (bool, error) {
	out, err := runXrandr("--current")
	if err != nil {
		return false, err
	}
	inOutputBlock := false
	for _, line := range strings.Split(out, "\n") {
		if strings.HasPrefix(line, output+" ") {
			inOutputBlock = true
			continue
		}
		if inOutputBlock {
			if line == "" || (!strings.HasPrefix(line, "   ") && !strings.HasPrefix(line, "\t")) {
				break
			}
			fields := strings.Fields(line)
			if len(fields) > 0 && fields[0] == mode {
				return true, nil
			}
		}
	}
	return false, nil
}

func GetScreenSize() (int, int, error) {
	output, err := GetActiveOutput()
	if err != nil {
		return 0, 0, err
	}
	mode, err := GetCurrentMode(output)
	if err != nil {
		return 0, 0, err
	}
	parts := strings.SplitN(mode, "x", 2)
	if len(parts) != 2 {
		return 0, 0, fmt.Errorf("invalid mode format: %s", mode)
	}
	w, err := strconv.Atoi(parts[0])
	if err != nil {
		return 0, 0, fmt.Errorf("invalid width: %s", parts[0])
	}
	h, err := strconv.Atoi(parts[1])
	if err != nil {
		return 0, 0, fmt.Errorf("invalid height: %s", parts[1])
	}
	return w, h, nil
}
```

- [ ] **Step 2: Verify build**

```bash
cd /tmp/displayctl && go build ./...
```

- [ ] **Step 3: Commit**

```bash
cd /tmp/displayctl && git add -A && git commit -m "feat: internal/xrandr wrapper for xrandr CLI"
```

---

### Task 3: internal/dpi — DPI Calculation and xrdb/Rofi Integration

**Files:**
- Create: `internal/dpi/dpi.go`

**Interfaces:**
- Consumes: `xrandr.GetScreenSize()` from Task 2
- Produces: `dpi.CalculateFromTiers(width int) int`, `dpi.SetXftDPI(dpi int) error`, `dpi.WriteRofiDPI(dpi int) error`, `dpi.GetCurrentDPI() (int, error)`

- [ ] **Step 1: Write internal/dpi/dpi.go**

```go
package dpi

import (
	"fmt"
	"os/exec"
	"regexp"
	"strconv"
	"strings"
)

func CalculateFromTiers(width int) int {
	switch {
	case width >= 3000:
		return 192
	case width >= 2700:
		return 168
	case width >= 2000:
		return 144
	default:
		return 96
	}
}

func SetXftDPI(dpi int) error {
	cmd := exec.Command("xrdb", "-merge")
	cmd.Stdin = strings.NewReader(fmt.Sprintf("Xft.dpi: %d", dpi))
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("xrdb -merge: %w", err)
	}
	return nil
}

func WriteRofiDPI(dpi int) error {
	scale := float64(dpi) / 96.0
	fontSize := int(12 * scale)
	padding := int(8 * scale)
	border := int(2 * scale)
	windowWidth := int(35 * scale)

	content := fmt.Sprintf(`// Auto-generated by displayctl — do not edit
* {
    rofi-padding: %dpx;
    rofi-border: %dpx;
    rofi-font-size: %dpx;
    rofi-window-width: %d%%;
}
`, padding, border, fontSize, windowWidth)

	if err := writeFile("/tmp/rofi-dpi.rasi", content); err != nil {
		return fmt.Errorf("write rofi-dpi.rasi: %w", err)
	}
	return nil
}

func GetCurrentDPI() (int, error) {
	out, err := exec.Command("xrdb", "-query").Output()
	if err != nil {
		return 0, fmt.Errorf("xrdb -query: %w", err)
	}
	re := regexp.MustCompile(`Xft\.dpi:\s+(\d+)`)
	m := re.FindSubmatch(out)
	if m == nil {
		return 0, fmt.Errorf("Xft.dpi not found in xrdb")
	}
	return strconv.Atoi(string(m[1]))
}

func writeFile(path, content string) error {
	return exec.Command("sh", "-c", fmt.Sprintf("cat > %s << 'DISPLAYCTL_EOF'\n%s\nDISPLAYCTL_EOF", path, content)).Run()
}
```

- [ ] **Step 2: Verify build**

```bash
cd /tmp/displayctl && go build ./...
```

- [ ] **Step 3: Commit**

```bash
cd /tmp/displayctl && git add -A && git commit -m "feat: internal/dpi — DPI tiers, xrdb, rofi-dpi.rasi"
```

---

### Task 4: internal/profile — TOML Profile Loading

**Files:**
- Create: `internal/profile/profile.go`

**Interfaces:**
- Produces: `profile.Profile` struct, `profile.OutputConfig` struct, `profile.DPIConfig` struct, `profile.ProfileSummary` struct, `profile.Load(dir, name string) (*Profile, error)`, `profile.LoadDefault(dir string) (*Profile, error)`, `profile.List(dir string) ([]ProfileSummary, error)`

- [ ] **Step 1: Add go-toml dependency**

```bash
cd /tmp/displayctl && go get github.com/pelletier/go-toml/v2
```

- [ ] **Step 2: Write internal/profile/profile.go**

```go
package profile

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	toml "github.com/pelletier/go-toml/v2"
)

type OutputConfig struct {
	Name string `toml:"name"`
	Mode string `toml:"mode"`
	Rate int    `toml:"rate,omitempty"`
}

type DPIConfig struct {
	Value *int `toml:"value,omitempty"`
	Tiers *bool `toml:"tiers,omitempty"`
}

type Profile struct {
	Default bool         `toml:"default"`
	Output  OutputConfig `toml:"output"`
	DPI     DPIConfig    `toml:"dpi"`
}

type ProfileSummary struct {
	Name    string
	Mode    string
	DPI     string
	Default bool
}

func Load(dir, name string) (*Profile, error) {
	path := filepath.Join(dir, "profiles", name+".toml")
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("profile %s not found: %w", name, err)
	}
	var p Profile
	if err := toml.Unmarshal(data, &p); err != nil {
		return nil, fmt.Errorf("parse profile %s: %w", name, err)
	}
	return &p, nil
}

func LoadDefault(dir string) (*Profile, error) {
	entries, err := os.ReadDir(filepath.Join(dir, "profiles"))
	if err != nil {
		return nil, fmt.Errorf("read profiles dir: %w", err)
	}
	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".toml") {
			continue
		}
		name := strings.TrimSuffix(entry.Name(), ".toml")
		p, err := Load(dir, name)
		if err != nil {
			continue
		}
		if p.Default {
			return p, nil
		}
	}
	return nil, fmt.Errorf("no default profile found")
}

func List(dir string) ([]ProfileSummary, error) {
	entries, err := os.ReadDir(filepath.Join(dir, "profiles"))
	if err != nil {
		return nil, fmt.Errorf("read profiles dir: %w", err)
	}
	var summaries []ProfileSummary
	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".toml") {
			continue
		}
		name := strings.TrimSuffix(entry.Name(), ".toml")
		p, err := Load(dir, name)
		if err != nil {
			continue
		}
		dpiStr := "none"
		if p.DPI.Value != nil {
			dpiStr = fmt.Sprintf("%d", *p.DPI.Value)
		} else if p.DPI.Tiers != nil && *p.DPI.Tiers {
			dpiStr = "tiers"
		}
		summaries = append(summaries, ProfileSummary{
			Name:    name,
			Mode:    p.Output.Mode,
			DPI:     dpiStr,
			Default: p.Default,
		})
	}
	return summaries, nil
}
```

- [ ] **Step 3: Verify build**

```bash
cd /tmp/displayctl && go build ./...
```

- [ ] **Step 4: Commit**

```bash
cd /tmp/displayctl && git add -A && git commit -m "feat: internal/profile — TOML profile loading and listing"
```

---

### Task 5: internal/hook — Post-Switch Hook Execution

**Files:**
- Create: `internal/hook/hook.go`

**Interfaces:**
- Produces: `hook.RunPostSwitch(dir string, env map[string]string) error`

- [ ] **Step 1: Write internal/hook/hook.go**

```go
package hook

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
)

func RunPostSwitch(dir string, env map[string]string) error {
	hookDir := filepath.Join(dir, "post-switch.d")
	entries, err := os.ReadDir(hookDir)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return fmt.Errorf("read post-switch.d: %w", err)
	}

	var names []string
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		info, err := entry.Info()
		if err != nil {
			continue
		}
		if info.Mode()&0111 == 0 {
			continue
		}
		names = append(names, entry.Name())
	}
	sort.Strings(names)

	for _, name := range names {
		path := filepath.Join(hookDir, name)
		cmd := exec.Command(path)
		cmd.Env = os.Environ()
		for k, v := range env {
			cmd.Env = append(cmd.Env, fmt.Sprintf("%s=%s", k, v))
		}
		if out, err := cmd.CombinedOutput(); err != nil {
			fmt.Fprintf(os.Stderr, "hook %s failed: %s: %s\n", name, err, strings.TrimSpace(string(out)))
		}
	}
	return nil
}
```

- [ ] **Step 2: Verify build**

```bash
cd /tmp/displayctl && go build ./...
```

- [ ] **Step 3: Commit**

```bash
cd /tmp/displayctl && git add -A && git commit -m "feat: internal/hook — post-switch.d hook execution"
```

---

### Task 6: cmd/apply — Apply Subcommand

**Files:**
- Create: `cmd/apply.go`

**Interfaces:**
- Consumes: `profile.Load()`, `profile.LoadDefault()`, `xrandr.SetMode()`, `xrandr.GetActiveOutput()`, `xrandr.GetScreenSize()`, `xrandr.ValidateMode()`, `dpi.CalculateFromTiers()`, `dpi.SetXftDPI()`, `dpi.WriteRofiDPI()`, `hook.RunPostSwitch()`, `config.ProfilesDir()`, `config.PostSwitchDir()`
- Produces: registers `apply` subcommand on cobra root

- [ ] **Step 1: Write cmd/apply.go**

```go
package cmd

import (
	"fmt"
	"os"
	"regexp"
	"strconv"

	"github.com/spf13/cobra"
	"github.com/yuez/displayctl/config"
	"github.com/yuez/displayctl/internal/dpi"
	"github.com/yuez/displayctl/internal/hook"
	"github.com/yuez/displayctl/internal/profile"
	"github.com/yuez/displayctl/internal/xrandr"
)

var modePattern = regexp.MustCompile(`^\d+x\d+$`)

func newApplyCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "apply <profile|WxH|auto>",
		Short: "Apply a display profile, temporary mode, or the default profile",
		Args:  cobra.ExactArgs(1),
		RunE:  runApply,
	}
}

func runApply(cmd *cobra.Command, args []string) error {
	arg := args[0]
	cfgDir := config.ConfigDir()

	var p *profile.Profile
	var err error

	switch {
	case arg == "auto":
		p, err = profile.LoadDefault(cfgDir)
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(4)
		}
	case modePattern.MatchString(arg):
		p = buildTempProfile(arg)
	default:
		p, err = profile.Load(cfgDir, arg)
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(2)
		}
	}

	return applyProfile(cfgDir, p)
}

func buildTempProfile(mode string) *profile.Profile {
	tiers := true
	return &profile.Profile{
		Output: profile.OutputConfig{
			Name: "",
			Mode: mode,
			Rate: 0,
		},
		DPI: profile.DPIConfig{
			Tiers: &tiers,
		},
	}
}

func applyProfile(cfgDir string, p *profile.Profile) error {
	outputName := p.Output.Name
	if outputName == "" {
		name, err := xrandr.GetActiveOutput()
		if err != nil {
			return fmt.Errorf("detect active output: %w", err)
		}
		outputName = name
	}

	if p.Output.Mode != "current" {
		valid, err := xrandr.ValidateMode(outputName, p.Output.Mode)
		if err != nil {
			return fmt.Errorf("validate mode: %w", err)
		}
		if !valid {
			return fmt.Errorf("mode %s not supported on %s", p.Output.Mode, outputName)
		}
		if err := xrandr.SetMode(outputName, p.Output.Mode, p.Output.Rate); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(3)
		}
	}

	var dpiValue int
	if p.DPI.Value != nil {
		dpiValue = *p.DPI.Value
	} else if p.DPI.Tiers != nil && *p.DPI.Tiers {
		w, _, err := xrandr.GetScreenSize()
		if err != nil {
			return fmt.Errorf("get screen size: %w", err)
		}
		dpiValue = dpi.CalculateFromTiers(w)
	}

	if dpiValue > 0 {
		if err := dpi.SetXftDPI(dpiValue); err != nil {
			return fmt.Errorf("set xft dpi: %w", err)
		}
		if err := dpi.WriteRofiDPI(dpiValue); err != nil {
			fmt.Fprintf(os.Stderr, "warning: write rofi-dpi.rasi: %v\n", err)
		}
		fmt.Printf("output=%s mode=%s dpi=%d\n", outputName, p.Output.Mode, dpiValue)
	} else {
		fmt.Printf("output=%s mode=%s dpi=unchanged\n", outputName, p.Output.Mode)
	}

	hookEnv := map[string]string{
		"DISPLAYCTL_OUTPUT": outputName,
		"DISPLAYCTL_MODE":   p.Output.Mode,
		"DISPLAYCTL_DPI":    strconv.Itoa(dpiValue),
	}
	if err := hook.RunPostSwitch(cfgDir, hookEnv); err != nil {
		fmt.Fprintf(os.Stderr, "warning: post-switch hooks: %v\n", err)
	}

	return nil
}
```

- [ ] **Step 2: Update cmd/root.go to register apply subcommand**

Add to `NewRootCmd()`:

```go
root.AddCommand(newApplyCmd())
```

- [ ] **Step 3: Verify build**

```bash
cd /tmp/displayctl && go build ./...
```

- [ ] **Step 4: Commit**

```bash
cd /tmp/displayctl && git add -A && git commit -m "feat: cmd/apply — apply profile, WxH, or auto"
```

---

### Task 7: cmd/list — List Subcommand

**Files:**
- Create: `cmd/list.go`

**Interfaces:**
- Consumes: `profile.List()`, `config.ProfilesDir()`
- Produces: registers `list` subcommand on cobra root

- [ ] **Step 1: Write cmd/list.go**

```go
package cmd

import (
	"fmt"
	"text/tabwriter"

	"github.com/spf13/cobra"
	"github.com/yuez/displayctl/config"
	"github.com/yuez/displayctl/internal/profile"
)

func newListCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "list",
		Short: "List available display profiles",
		RunE:  runList,
	}
}

func runList(cmd *cobra.Command, args []string) error {
	summaries, err := profile.List(config.ConfigDir())
	if err != nil {
		return err
	}
	w := tabwriter.NewWriter(cmd.OutOrStdout(), 0, 0, 2, ' ', 0)
	fmt.Fprintln(w, "NAME\tMODE\tDPI\tDEFAULT")
	for _, s := range summaries {
		defMark := ""
		if s.Default {
			defMark = "*"
		}
		fmt.Fprintf(w, "%s\t%s\t%s\t%s\n", s.Name, s.Mode, s.DPI, defMark)
	}
	return w.Flush()
}
```

- [ ] **Step 2: Update cmd/root.go to register list subcommand**

Add to `NewRootCmd()`:

```go
root.AddCommand(newListCmd())
```

- [ ] **Step 3: Verify build**

```bash
cd /tmp/displayctl && go build ./...
```

- [ ] **Step 4: Commit**

```bash
cd /tmp/displayctl && git add -A && git commit -m "feat: cmd/list — list available profiles"
```

---

### Task 8: cmd/current — Current Subcommand

**Files:**
- Create: `cmd/current.go`

**Interfaces:**
- Consumes: `xrandr.GetActiveOutput()`, `xrandr.GetCurrentMode()`, `dpi.GetCurrentDPI()`
- Produces: registers `current` subcommand on cobra root

- [ ] **Step 1: Write cmd/current.go**

```go
package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
	"github.com/yuez/displayctl/internal/dpi"
	"github.com/yuez/displayctl/internal/xrandr"
)

func newCurrentCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "current",
		Short: "Show current display mode and DPI",
		RunE:  runCurrent,
	}
}

func runCurrent(cmd *cobra.Command, args []string) error {
	output, err := xrandr.GetActiveOutput()
	if err != nil {
		return err
	}
	mode, err := xrandr.GetCurrentMode(output)
	if err != nil {
		return err
	}
	dpiVal, err := dpi.GetCurrentDPI()
	if err != nil {
		fmt.Fprintf(cmd.OutOrStdout(), "output=%s mode=%s dpi=unknown\n", output, mode)
		return nil
	}
	fmt.Fprintf(cmd.OutOrStdout(), "output=%s mode=%s dpi=%d\n", output, mode, dpiVal)
	return nil
}
```

- [ ] **Step 2: Update cmd/root.go to register current subcommand**

Add to `NewRootCmd()`:

```go
root.AddCommand(newCurrentCmd())
```

- [ ] **Step 3: Verify build**

```bash
cd /tmp/displayctl && go build ./...
```

- [ ] **Step 4: Commit**

```bash
cd /tmp/displayctl && git add -A && git commit -m "feat: cmd/current — show current mode and DPI"
```

---

### Task 9: internal/randr — xgb RandR Event Listener

**Files:**
- Create: `internal/randr/randr.go`

**Interfaces:**
- Produces: `randr.Watch(displayName string, onChange func(width, height int)) error`

- [ ] **Step 1: Add xgb dependency**

```bash
cd /tmp/displayctl && go get github.com/Burntsushi/xgb
```

- [ ] **Step 2: Write internal/randr/randr.go**

```go
package randr

import (
	"fmt"

	"github.com/Burntsushi/xgb"
	"github.com/Burntsushi/xgb/randr"
)

func Watch(displayName string, onChange func(width, height int)) error {
	conn, err := xgb.NewConnDisplay(displayName)
	if err != nil {
		return fmt.Errorf("connect to display %s: %w", displayName, err)
	}
	defer conn.Close()

	if err := randr.Init(conn); err != nil {
		return fmt.Errorf("init randr: %w", err)
	}

	root := conn.DefaultScreen().Root
	_, err = randr.SelectInput(conn, root, randr.NotifyMaskScreenChange)
	if err != nil {
		return fmt.Errorf("select randr input: %w", err)
	}

	for {
		ev, err := conn.WaitForEvent()
		if err != nil {
			return fmt.Errorf("wait for event: %w", err)
		}
		if ev == nil {
			continue
		}
		switch ev.(type) {
		case randr.ScreenChangeNotifyEvent:
			sce := ev.(randr.ScreenChangeNotifyEvent)
			onChange(int(sce.Width), int(sce.Height))
		}
	}
}
```

- [ ] **Step 3: Verify build**

```bash
cd /tmp/displayctl && go build ./...
```

- [ ] **Step 4: Commit**

```bash
cd /tmp/displayctl && git add -A && git commit -m "feat: internal/randr — xgb RandR event listener"
```

---

### Task 10: cmd/daemon — Daemon Subcommand

**Files:**
- Create: `cmd/daemon.go`

**Interfaces:**
- Consumes: `randr.Watch()`, `dpi.CalculateFromTiers()`, `dpi.SetXftDPI()`, `dpi.WriteRofiDPI()`, `hook.RunPostSwitch()`, `config.ConfigDir()`
- Produces: registers `daemon` subcommand on cobra root

- [ ] **Step 1: Write cmd/daemon.go**

```go
package cmd

import (
	"fmt"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"github.com/spf13/cobra"
	"github.com/yuez/displayctl/config"
	"github.com/yuez/displayctl/internal/dpi"
	"github.com/yuez/displayctl/internal/hook"
	"github.com/yuez/displayctl/internal/randr"
	"github.com/yuez/displayctl/internal/xrandr"
)

func newDaemonCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "daemon",
		Short: "Run daemon that watches RandR events and auto-refreshes DPI",
		RunE:  runDaemon,
	}
}

func runDaemon(cmd *cobra.Command, args []string) error {
	display := os.Getenv("DISPLAY")
	if display == "" {
		return fmt.Errorf("DISPLAY not set")
	}

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)

	debounce := make(chan struct{}, 1)

	go func() {
		for range debounce {
			time.Sleep(200 * time.Millisecond)
			handleScreenChange()
		}
	}()

	go func() {
		<-sigCh
		fmt.Fprintln(os.Stderr, "displayctl daemon: shutting down")
		os.Exit(0)
	}()

	fmt.Fprintln(os.Stderr, "displayctl daemon: watching RandR events on", display)
	return randr.Watch(display, func(width, height int) {
		select {
		case debounce <- struct{}{}:
		default:
		}
	})
}

func handleScreenChange() {
	output, err := xrandr.GetActiveOutput()
	if err != nil {
		fmt.Fprintf(os.Stderr, "daemon: get active output: %v\n", err)
		return
	}
	mode, err := xrandr.GetCurrentMode(output)
	if err != nil {
		fmt.Fprintf(os.Stderr, "daemon: get current mode: %v\n", err)
		return
	}

	w, _, err := xrandr.GetScreenSize()
	if err != nil {
		fmt.Fprintf(os.Stderr, "daemon: get screen size: %v\n", err)
		return
	}

	dpiValue := dpi.CalculateFromTiers(w)
	if err := dpi.SetXftDPI(dpiValue); err != nil {
		fmt.Fprintf(os.Stderr, "daemon: set xft dpi: %v\n", err)
		return
	}
	if err := dpi.WriteRofiDPI(dpiValue); err != nil {
		fmt.Fprintf(os.Stderr, "daemon: write rofi-dpi: %v\n", err)
	}

	fmt.Fprintf(os.Stderr, "daemon: output=%s mode=%s dpi=%d\n", output, mode, dpiValue)

	cfgDir := config.ConfigDir()
	hookEnv := map[string]string{
		"DISPLAYCTL_OUTPUT": output,
		"DISPLAYCTL_MODE":   mode,
		"DISPLAYCTL_DPI":    strconv.Itoa(dpiValue),
	}
	if err := hook.RunPostSwitch(cfgDir, hookEnv); err != nil {
		fmt.Fprintf(os.Stderr, "daemon: post-switch hooks: %v\n", err)
	}
}
```

- [ ] **Step 2: Update cmd/root.go to register daemon subcommand**

Add to `NewRootCmd()`:

```go
root.AddCommand(newDaemonCmd())
```

- [ ] **Step 3: Verify build**

```bash
cd /tmp/displayctl && go build ./...
```

- [ ] **Step 4: Commit**

```bash
cd /tmp/displayctl && git add -A && git commit -m "feat: cmd/daemon — RandR event daemon with DPI auto-refresh"
```

---

### Task 11: Dotfiles Integration — Profile TOMLs and Hook Directory

**Files:**
- Create: `dot_config/display/profiles/xrdp.toml`
- Create: `dot_config/display/profiles/sunshine.toml`
- Create: `dot_config/display/profiles/monitor.toml`
- Create: `dot_config/display/post-switch.d/.gitkeep`

**Interfaces:**
- N/A (configuration files only)

- [ ] **Step 1: Create profile TOML files**

`dot_config/display/profiles/xrdp.toml`:
```toml
default = false

[output]
name = "Virtual-1"
mode = "current"

[dpi]
tiers = true
```

`dot_config/display/profiles/sunshine.toml`:
```toml
default = false

[output]
name = "Virtual-1"
mode = "3840x2160"
rate = 60

[dpi]
value = 192
```

`dot_config/display/profiles/monitor.toml`:
```toml
default = true

[output]
name = "Virtual-1"
mode = "3840x2160"

[dpi]
value = 192
```

- [ ] **Step 2: Create post-switch.d directory placeholder**

```bash
mkdir -p /home/yuez/workspace/dotfiles/dot_config/display/post-switch.d
touch /home/yuez/workspace/dotfiles/dot_config/display/post-switch.d/.gitkeep
```

- [ ] **Step 3: Commit**

```bash
cd /home/yuez/workspace/dotfiles && git add dot_config/display/ && git commit -m "feat: display profile TOMLs and post-switch.d directory"
```

---

### Task 12: Dotfiles Integration — Update i3, polybar, xinitrc

**Files:**
- Modify: `dot_config/i3/config.tmpl`
- Modify: `dot_config/polybar/executable_launch.sh`
- Modify: `dot_xinitrc`

**Interfaces:**
- N/A (configuration file modifications)

- [ ] **Step 1: Update dot_config/i3/config.tmpl**

Replace the line `exec_always --no-startup-id ~/.bin/set-dpi.sh` with:
```
exec_always --no-startup-id displayctl apply auto
exec --no-startup-id displayctl daemon
```

- [ ] **Step 2: Update dot_config/polybar/executable_launch.sh**

Remove calls to `~/.bin/set-dpi.sh` and `~/.bin/dpi-mode`. Replace DPI detection logic with reading from xrdb directly. The polybar launch script should read `Xft.dpi` from `xrdb -query` instead of calling the removed scripts.

- [ ] **Step 3: Update dot_xinitrc**

Replace:
```
command -v xrandr >/dev/null 2>&1 && \
    xrandr --output Virtual-1 --mode 3840x2160
exec i3
```

With:
```
command -v displayctl >/dev/null 2>&1 && displayctl apply auto
exec i3
```

- [ ] **Step 4: Commit**

```bash
cd /home/yuez/workspace/dotfiles && git add dot_config/i3/config.tmpl dot_config/polybar/executable_launch.sh dot_xinitrc && git commit -m "feat: integrate displayctl into i3, polybar, xinitrc"
```

---

### Task 13: Dotfiles Integration — Remove Old Scripts

**Files:**
- Delete: `dot_bin/executable_set-dpi.sh`
- Delete: `dot_bin/executable_dpi-mode`

**Interfaces:**
- N/A (file removal only)

- [ ] **Step 1: Remove old scripts**

```bash
cd /home/yuez/workspace/dotfiles
git rm dot_bin/executable_set-dpi.sh dot_bin/executable_dpi-mode
```

- [ ] **Step 2: Commit**

```bash
cd /home/yuez/workspace/dotfiles && git commit -m "chore: remove set-dpi.sh and dpi-mode, replaced by displayctl"
```

---

### Task 14: Integration Test — Build and Verify End-to-End

**Files:**
- N/A

**Interfaces:**
- N/A

- [ ] **Step 1: Build the displayctl binary**

```bash
cd /tmp/displayctl && go build -o displayctl . && cp displayctl ~/.bin/displayctl
```

- [ ] **Step 2: Test `displayctl list`**

```bash
displayctl list
```

Expected: table showing xrdp, sunshine, monitor profiles

- [ ] **Step 3: Test `displayctl current`**

```bash
displayctl current
```

Expected: `output=Virtual-1 mode=... dpi=...`

- [ ] **Step 4: Test `displayctl apply monitor`**

```bash
displayctl apply monitor
```

Expected: `output=Virtual-1 mode=3840x2160 dpi=192`

- [ ] **Step 5: Verify DPI was set**

```bash
xrdb -query | grep Xft.dpi
```

Expected: `Xft.dpi: 192`

- [ ] **Step 6: Commit any final fixes**

```bash
cd /tmp/displayctl && git add -A && git commit -m "chore: integration test fixes" || true
```
