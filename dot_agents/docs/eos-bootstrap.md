# System Bootstrap — eos-bootstrap

Repo: `~/Workspace/Misc/eos-bootstrap`
Purpose: Idempotent bootstrap for EndeavourOS i3wm developer workstation.

## Two-Repo Model (load-bearing)

- **eos-bootstrap** — coarse system layer: packages, systemd services, kernel, network, user groups.
- **Dotfiles repo** (chezmoi) — fine user layer: `~/.config/**`, themes, mise tool versions.

Boundary: Ansible never writes under `~`. chezmoi never installs packages or enables services.

## Entry Points

| File | Purpose |
|------|---------|
| `bootstrap.sh` | Top-level: pacman → paru → ansible-playbook → chezmoi init/update |
| `ansible/playbook.yml` | Single playbook, `hosts: localhost`, `become: true` |
| `ansible/group_vars/all.yml` | Per-machine identity: `target_user`, `user_groups`, `dotfiles_repo`, etc. |

## Ansible Roles (order matters)

```
packages → mise → services → network → kernel → logging → power → fingerprint → user → display
```

| Role | Key files | What it does |
|------|-----------|-------------|
| `packages` | `defaults/main.yml` | pacman + AUR (via paru) package lists; bundled fonts (`wps_fonts`) + best-effort AUR (`aur_packages_interactive`); bluetooth/thunderbolt/keyd auto-detect |
| `mise` | `tasks/main.yml` | Installs mise binary only (tool versions in dotfiles repo) |
| `services` | `vars/core_services.yml` | Enables core systemd services (hardcoded, code-review required) |
| `network` | `files/nmconnection/` | Drop-in NetworkManager profiles → `/etc/NetworkManager/system-connections/` |
| `kernel` | `templates/sysctl.d.conf.j2` | sysctl tunables (file-max, inotify, swappiness, BBR); `defaults/main.yml::kernel_modules` |
| `logging` | `templates/journald.conf.j2`, `templates/logrotate-eos.conf.j2` | journald retention cap + compression + vacuum; logrotate compress + generic rules (`/etc/logrotate.d/eos`) + timer |
| `power` | — | TLP power management |
| `fingerprint` | — | Fingerprint reader (fprintd) |
| `user` | `files/polkit/` | User groups (append-only), sudoers, polkit rules |
| `display` | `tasks/autologin.yml`, `tasks/touchpad.yml` | LightDM, agetty autologin on tty1, touchpad natural scroll |

## Core Services (hardcoded)

```yaml
NetworkManager, docker, fstrim.timer, keyd, rtkit-daemon,
sshd, tailscaled, tlp, tlp-pd
```

Optional services: set `optional_services` in `group_vars/all.yml`.

## Commands

```bash
./bootstrap.sh                                    # full idempotent bootstrap
ansible-playbook ansible/playbook.yml --ask-become-pass  # ansible only
ansible-playbook ansible/playbook.yml --tags packages    # single role
tests/lint.sh                                     # ansible-lint + yamllint + shellcheck
tests/idempotency.sh                              # runs playbook twice, fails on changed
```

## Adding Things

- **Package**: edit `ansible/roles/packages/defaults/main.yml` → `pacman_packages` or `aur_packages`
- **Service**: edit `ansible/roles/services/vars/core_services.yml` (or `optional_services` in group_vars)
- **NM profile**: drop `.nmconnection` file in `ansible/roles/network/files/nmconnection/`
- **Polkit rule**: drop in `ansible/roles/user/files/polkit/`
- **Kernel module**: append to `kernel_modules` in `ansible/roles/kernel/defaults/main.yml`
- **Dotfile**: that's chezmoi, not this repo

## Gotchas

- `dotfiles_repo` must be set in `group_vars/all.yml` before bootstrap runs.
- `dotfiles_use_encryption: true` requires age key at `~/.config/chezmoi/key.txt`.
- VM guest packages auto-detected (`virtualization_role == 'guest'`); removed on bare metal.
- Handler names must be unique across roles (single play, shared namespace).
- `keyd` group membership requires logout/login to take effect.
- No firewall (ufw) by design. Single-machine scope — no multi-host support.
- Tags on `include_tasks` must be duplicated in `apply:` block or `--tags` silently skips inner tasks.
