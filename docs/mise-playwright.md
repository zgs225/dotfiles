# mise 管理 Playwright

通过 mise 全局安装 Playwright CLI，以及它与项目内 `@playwright/test` 的分工。
搭建：2026-09。

## 最终配置

`~/.config/mise/conf.d/playwright.toml`（chezmoi 源：`dot_config/mise/conf.d/playwright.toml`）：

```toml
[tools]
"npm:playwright" = "latest"
```

要点：

- **键必须加引号** —— TOML 裸键不允许 `npm:` 前缀（同 `npm:@deepseek-ai/dsh`）。
- 安装器沿用 `conf.d/node.toml` 的 `[settings.npm] package_manager = "pnpm"`。
- `mise install` 后 shim `~/.local/share/mise/shims/playwright` 全局可用，替代 `npx playwright`。
- **mise 只装 CLI，不装浏览器。** 浏览器由 `playwright install` 下载到 `~/.cache/ms-playwright`；
  mise/pnpm 安装时不会执行 playwright 的 postinstall（pnpm 默认不跑包自身的 build script），
  所以 `mise install` 不会顺带拉几百 MB 浏览器 —— 这正是我们想要的职责分离。

## 职责划分

| 用途 | 命令 | 用哪一份 |
|------|------|---------|
| 下载浏览器 | `playwright install [chromium]` | mise 全局 CLI |
| 装系统依赖 | `playwright install-deps` | mise 全局 CLI（需 root） |
| codegen / open / screenshot / show-report / show-trace | `playwright <cmd>` | mise 全局 CLI |
| **跑项目测试** | `pnpm exec playwright test` | **项目内那份**（见坑 1） |

## 坑 1：全局 `playwright test` 跑不了项目测试

全局 CLI 是 1.63.0，项目 `node_modules` 里是 `@playwright/test@1.56.1`。在项目目录直接执行
`playwright test`（命中 mise shim）时，spec 文件 import 到的是**项目内**的 1.56.1，而 runner 是
全局 1.63.0，两个版本打架：

```
Error: Playwright Test did not expect test.describe() to be called here.
Most common reasons include:
- You have two different versions of @playwright/test. ...
```

`--list` 也一样，结果是 `Total: 0 tests in 0 files`。

**结论：项目里一律 `pnpm exec playwright test`**（用 package.json script / Makefile 包一层更保险），
`playwright` 这个 shim 只当「浏览器安装 + 周边工具」的入口。

## 坑 2：浏览器按 playwright 版本分 revision 目录，不共用

`~/.cache/ms-playwright/<browser>-<revision>` 按 revision 隔离，revision 由 playwright 版本决定：

| playwright | chromium | firefox | webkit | ffmpeg |
|-----------|----------|---------|--------|--------|
| 1.63.0（mise 全局） | chromium-1243 | firefox-1543 | webkit-2359 | ffmpeg-1011 |
| 1.56.1（ai-writing-report 项目） | chromium-1194 | — | — | ffmpeg-1011 |

所以磁盘上同时存在多份浏览器是正常的，全局 CLI 与项目各取所需。注意升级代价：

- `mise upgrade` 升了全局 playwright → 要重新 `playwright install`；
- 项目升 `@playwright/test`（pnpm catalog：`'@playwright/test': 1.56.1`）→ 要
  `pnpm exec playwright install`。

想省磁盘就让两者版本一致，把全局 pin 到项目版本：

```toml
"npm:playwright" = "1.56.1"
```

此时缓存目录完全复用，代价是升级要两边一起动。

## 坑 3：系统依赖是系统层

`playwright install-deps` 走 pacman、需要 root —— 属于 eos-bootstrap 的地盘，
不要写进 chezmoi/mise。

## 坑 4：冷启动安装超时（默认 20s）

npm registry 冷拉取时实测 `pnpm add --global playwright` 要 36.5s，会报：

```
mise ERROR Failed to install npm:playwright@latest: timed out after 20.00s
```

pnpm store 预热后重试即可（第二次 605ms）。

## 验证

```bash
$ which playwright
/home/yuez/.local/share/mise/shims/playwright
$ playwright --version
Version 1.63.0
$ playwright install --dry-run | grep "Install location"
  Install location:    /home/yuez/.cache/ms-playwright/chromium-1243
  Install location:    /home/yuez/.cache/ms-playwright/firefox-1543
  Install location:    /home/yuez/.cache/ms-playwright/webkit-2359
```

## 相关

- npm: 后端本身的坑（aube 安装器、`minimum_release_age`）见 [mise-npm-backend.md](mise-npm-backend.md)
