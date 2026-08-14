# mise npm: 后端的坑（aube 安装器）

记录通过 mise 的 `npm:` 后端安装全局 Node 工具的踩坑经验。
案例：`@deepseek-ai/dsh`（DeepSeek Harness，`dsh`），2026-08 安装。

## 最终配置

`~/.config/mise/conf.d/node.toml`（chezmoi 管理，源文件 `dot_config/mise/conf.d/node.toml`）：

```toml
[tools]
node = "22"
pnpm = "latest"
"npm:@deepseek-ai/dsh" = { version = "latest", allow_low_downloads = true }

[settings]
minimum_release_age_excludes = ["npm:@deepseek-ai/dsh"]

[settings.npm]
package_manager = "pnpm"
```

要点：

- **`"npm:@deepseek-ai/dsh"` 键必须加引号** —— TOML 裸键只允许 `[A-Za-z0-9_-]`，`npm:` 前缀和 `@scope` 都要引号包裹。
- **`npm.package_manager = "pnpm"`** —— 这是绕开下面坑 2/3 的关键；`pnpm` 必须是已安装的工具（`pnpm = "latest"` 已有）。
- 保持 `version = "latest"` 能正常工作，`mise install` / `mise upgrade` 即升级。

## 坑 1：`minimum_release_age`（默认 24h）挡掉新版本

mise 2026.6+ 默认 `minimum_release_age = "24h"`（env: `MISE_MINIMUM_RELEASE_AGE`）：
解析**模糊版本请求**（`latest`、`node@22` 这类）时，发布不足 24h 的版本会被过滤。
dsh 的 `0.1.0-rc.6` 发布仅 12h，报错：

```
no versions found for npm:@deepseek-ai/dsh matching date filter
```

注意：**精确 pin（`@0.1.0-rc.6`）不受此过滤影响**，但用户要求保持 `latest`，所以用排除项：

```toml
[settings]
minimum_release_age_excludes = ["npm:@deepseek-ai/dsh"]
```

`excludes` 支持 backend 通配（`npm:*`）、工具短名（`trivy`）、完整 backend ID（`npm:prettier`）。
只排除这一个工具，其他工具保留 24h 供应链保护。

## 坑 2：aube 防抢注挑战（新包名，非 TTY 直接 abort）

mise 嵌入式 aube 安装器有 **slopsquatting mitigation**：包名注册时间 < `minimumPackageAge`
（默认 30 天）时 `aube add` 会挑战确认 —— 交互式会话 prompt，非交互式直接失败：

```
aube install failed: user aborted `mise add @deepseek-ai/dsh`
```

dsh 的包名 2026-08-10 才注册（< 30 天）。伪 TTY 下命令会**挂起等确认**（等了 600s 无响应）。

尝试 `AUBE_MINIMUM_PACKAGE_AGE=0`（aube 官方 env）**在嵌入式模式下不生效**，只能换安装器绕开。

## 坑 3：aube 解析器 bug（mutually recursive peers）

绕过坑 2 后（`allow_low_downloads` 工具选项 + env），aube 解析 dsh 的 1247 个依赖时崩溃：

```
peer-context fixed-point did not converge after 16 iterations.
mutually recursive peers, lockfile would be incomplete
```

这是 aube（新项目，迭代快）解析器对互相递归 peer 依赖的限制，无配置可解 —— **换 pnpm 走 shell-out**：

```toml
[settings.npm]
package_manager = "pnpm"
```

pnpm 11.15.1 一次成功（38.7s）。`allow_low_downloads = true` 是应对 aube 低下载量挑战
（默认 1000 周下载阈值）的工具选项，pnpm 路径下无副作用，保留以防切回 aube。

## 相关行为备忘

- `npm.package_manager` 选项：`auto`（嵌入式 aube，默认）/ `aube_cli` / `npm` / `bun` / `pnpm`；
  shell-out 模式要求对应包管理器已安装（mise 管着 pnpm，天然满足）。
- mise 的 `minimum_release_age` 会转发给 shell-out 的包管理器（pnpm ≥ 10.16 用
  `--config.minimumReleaseAge=<分钟>`）；被 `excludes` 排除的工具不转发。
- `npm.shell_out = true` 是另一个开关（走 npm CLI，读 `~/.npmrc` 的 cafile/证书等），
  与显式 `package_manager` 互斥，显式选择优先。
- aube 的 `allow_low_downloads` / `trust_policy_excludes` 等是 mise 工具选项，不是 settings。
- 若某 npm 工具安装失败，先区分阶段：**版本解析失败**（坑 1）→ **挑战/确认失败**（坑 2）→
  **依赖解析失败**（坑 3）。非 TTY 环境下交互式挑战一律表现为 "user aborted"。
