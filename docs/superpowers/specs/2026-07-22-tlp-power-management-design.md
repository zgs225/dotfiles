# TLP 电量管理设计

日期：2026-07-22
状态：已批准（待实现）

## 背景

笔记本（ASUS,i7-12700H + RTX 3050 Ti,Optimus）电池消耗快。已完成的整治：wezterm 从 dGPU 迁到核显（`IntegratedGpu + Gl`)、移除 sunshine 自启，dGPU 可正常进 D3，空载省约 6W。本设计解决系统级电源策略：当前无任何电源管理工具（无 TLP/PPD/auto-cpufreq/thermald),CPU 侧功耗无策略管控。

硬件前提：

- `/sys/firmware/acpi/platform_profile` 支持 quiet/balanced/performance
- ASUS `asus_wmi` 驱动，TLP 原生支持充电阈值（硬件认可 40/60/80)
- TLP 1.9+ 引入 profiles(performance/balanced/power-saver)、tlp-pd 守护进程与 `tlpctl` 免密 CLI(D-Bus + polkit)

## 目标

1. 插电/用电池自动应用不同电源策略（省心，无需干预）
2. eww 控制中心可手动切换/查看电源模式
3. 系统层（包、/etc、服务）由 eos-bootstrap(Ansible）管理；用户层（eww）由本仓库（chezmoi）管理，边界不越

## 关键决策

| 决策点 | 结论 | 理由 |
|---|---|---|
| 方案 | TLP 1.9+ 原生 profiles + tlp-pd + tlpctl | 免 sudoers、机制零对抗；否决自制覆盖层（重复造轮子）与 PPD（无充电阈值、可调性弱） |
| 三档语义 | 自动 / 省电 / 性能 | `TLP_AUTO_SWITCH=2`(smart，默认）原生实现：跟随电源自动切；用户手动改档后跳过自动切换，直到手动切回 |
| 手动档持久性 | 一直有效直到手动切回 | smart 模式原生行为；跨重启持久性需实测，见「风险」 |
| 电源默认档 | AC=balanced,BAT=power-saver | 省电优先；需要性能时 eww 手动锁 |
| 充电阈值 | `STOP_CHARGE_THRESH_BAT0=80` | 减缓电池老化；`tlp fullcharge` 可临时充满 |
| eww 形态 | 复用控制中心 quick-btn「性能」改为电源模式按钮 | 不新增行、不加 bar 指示器；按钮自身显示当前模式。原「打开任务管理器」功能下线（i3 已有 dropdown-btop) |

## 架构

```
┌─ 用户层 (chezmoi / 本仓库) ─────────────┐
│ eww cc quick-btn「电源」                │
│   ↓ onclick                             │
│ power-profile.sh cycle → tlpctl set ────┼──┐
│ power-profile.sh get  → tlpctl get  ←───┼──┤ (免密, D-Bus/polkit)
└─────────────────────────────────────────┘  │
                                             ↓
┌─ 系统层 (eos-bootstrap / Ansible) ─────────┐
│ tlp-pd.service ── 应用 profile 到 sysfs    │
│ tlp.service    ── 开机应用 + 阈值恢复      │
│ /etc/tlp.d/00-eos.conf ── 映射与阈值       │
└────────────────────────────────────────────┘
```

## eos-bootstrap 变更

1. `ansible/roles/packages/vars/pacman_packages.yml`:加 `tlp`
2. `ansible/roles/services/vars/core_services.yml`:加 `tlp.service`、`tlp-pd.service`（该文件按仓库约定需 code review)
3. 新增 `ansible/roles/power/`:
   - `files/tlp-eos.conf` → `copy` 到 `/etc/tlp.d/00-eos.conf`(root:root 0644),notify handler `Apply tlp`（执行 `tlp start`，官方建议，不用 systemctl restart)
   - `tasks/main.yml`：开头断言 `tlp` 已安装且版本 ≥ 1.9(`tlp --version`)，不满足 fail
   - copy 幂等，handler 仅变更触发，满足 `tests/idempotency.sh`
4. `ansible/playbook.yml`:role 顺序插入 `power`（在 `kernel` 之后）
5. 执行边界：agent 只改仓库文件；用户自行执行 `ansible-playbook ansible/playbook.yml --ask-become-pass --tags power,packages,services`

`/etc/tlp.d/00-eos.conf` 内容（其余全部吃 TLP profiles 内置默认，YAGNI):

```ini
TLP_PROFILE_AC=BAL
TLP_PROFILE_BAT=SAV
STOP_CHARGE_THRESH_BAT0=80
```

## dotfiles 变更（本仓库）

### `dot_config/eww/scripts/executable_power-profile.sh`

- `get`：输出 JSON `{mode, profile, source}`
  - `source`:AC 在线 → `ac`，否则 `bat`
  - `profile`:`tlpctl get` 原值（performance/balanced/power-saver)
  - `mode` 判定：profile == 当前电源默认档（ac→balanced,bat→power-saver)→ `auto`；否则 profile 为 power-saver → `powersave`，为 performance → `performance`
- `set auto|powersave|performance`:
  - `auto` → `tlpctl set <当前电源默认档>`(smart 切换恢复接管）
  - `powersave` → `tlpctl set power-saver`
  - `performance` → `tlpctl set performance`
- `cycle`：按 auto → powersave → performance → auto 轮转（供按钮单击）
- tlpctl 不存在时（TLP 未装）:`get` 输出 `{"mode":"unavailable"}`,set 空操作，按钮置灰提示

### `dot_config/eww/components/control-center.yuck.tmpl`

- 改动 quick actions 第三键：「性能」→「电源」
  - label 显示当前模式：`自动` / `省电` / `性能`(unavailable 时显示「电源」)
  - icon 随模式变化（Nerd Font，实现时选定）
  - `onclick` → `power-profile.sh cycle`
- 状态源：eww `defpoll`(2~5s，脚本轻量）
- 样式遵守 `docs/design/song-liquid-glass.md`:`data.colors` 取色、朱砂唯一性、eww SCSS 纯 ASCII

## 验证

部署后（用户执行 ansible 后）:

1. `tlp-stat -s` — profile 与电源状态正确
2. `tlp-stat -b` — `charge_control_end_threshold = 80`
3. `tlpctl get` / eww 按钮三态轮转即时生效
4. 插拔电源 → 自动档跟随（AC→balanced,BAT→power-saver)
5. 手动锁性能后插拔电源 → 不被自动切换覆盖
6. 重启 → **实测手动锁定是否保持**（见风险 R1)
7. 电池充至 80% 停止
8. eos-bootstrap:`tests/lint.sh`、`tests/idempotency.sh` 通过

## 风险与回退

- **R1 手动锁定跨重启持久性未明**:TLP 文档未明确 smart 模式的手动标记是否持久。实测若不保持，备选：power-profile.sh set 时写 `~/.local/share/eww/power-mode` 状态文件，i3 `exec` 开机重放 `power-profile.sh set <保存值>`
- **R2 Arch 仓库 tlp < 1.9**：版本断言 fail，退回自制覆盖层方案（另议）
- **R3 ASUS 阈值开机窗口**：硬件开机复位阈值，TLP 启动后恢复，短暂窗口不生效（上游文档明示，接受）
- **R4 USB autosuspend 等 TLP 默认调优的兼容性**：若外设异常（鼠标断连等），按需往 00-eos.conf 加 denylist/排除参数
- 回退：`systemctl disable --now tlp.service tlp-pd.service`，删除 `/etc/tlp.d/00-eos.conf`，重启后系统回到无电源策略状态；eww 按钮 git 还原即恢复原「性能」键

## 不做（YAGNI)

- tlp-rdw、射频设备定时开关、systemd-rfkill mask
- bar 电源指示器（由 cc 按钮自身承担状态显示）
- 自定义 CPU 频率/EPP 细调参数（吃 profiles 内置）
- thermald / auto-cpufreq（与 TLP 职能重叠）

---

## 补充：电源弹窗（2026-07-22 追加，已实现）

bar 电量图标打开 `power-popup`（控制中心电源键保持三态轮转，分工不变）:

- **头部**：电源来源 + 实时功耗（W) + dGPU 徽标（挂起=月亮；活跃=闪电+占用进程名，lsof 读 /dev/nvidia*，不调 nvidia-smi 防唤醒）
- **电源模式**：一行三格（自动/省电/性能），当前档高亮，`power-profile.sh set`（异步防 eww 200ms 点击超时）
- **充电阈值**：一行三格预设 60（寿命）/80（平衡）/100（出行），当前值高亮。持久化写 `/etc/tlp.d/99-user.conf`（覆盖 00-eos.conf 的 80)
- **电池详情**：电量、健康度（energy_full/design)、循环次数、剩余/充满 ETA
- **临时充满**：`tlp fullcharge`（临时提阈值到充满，不改持久配置）

特权收口：单一 helper `/usr/local/sbin/eww-power-admin`(eos-bootstrap power role 部署，仅 `threshold 60|80|100` / `fullcharge` 两个子命令，参数白名单校验）+ sudoers drop(NOPASSWD 仅该 helper,visudo 校验）。

新增文件：`scripts/executable_power-info.sh`(JSON 数据源）、`components/power-popup.yuck.tmpl`、`styles/power-popup.scss.tmpl`;eww-sizes 三档 DPI 加 powerW/powerH;`open-popup.sh` 注册弹窗。
