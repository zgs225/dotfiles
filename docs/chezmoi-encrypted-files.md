# Chezmoi 加密文件（age）的修改流程

仓库里带 `encrypted_*.age` 后缀的文件（如 `dot_pi/encrypted_web-search.json.age`、
`dot_pi/agent/encrypted_private_auth.json.age`）用 age 加密，密钥在
`~/.config/chezmoi/key.txt`，recipient 在 `.chezmoi.yaml.tmpl`。

**铁律：不要直接写目标文件（如 `~/.pi/web-search.json`）当作最终变更。**
目标文件只是 apply 的产物，source of truth 是 repo 里的 `.age` 文件。
直接改目标文件，下次 `chezmoi apply` 会被覆盖回去。

## 标准修改流程（re-add）

```bash
# 1. 看当前明文（chezmoi 自动解密）
chezmoi cat ~/.pi/web-search.json

# 2. 修改目标文件（可用任何方式，如 python/jq/编辑器）
#    例：python3 -c '...' 改 ~/.pi/web-search.json

# 3. 重新加密入库 —— re-add 检测到源条目已是 encrypted_*，会自动重新加密
chezmoi re-add ~/.pi/web-search.json

# 4. 验证：diff 应为空，cat 能解密出预期内容
chezmoi diff ~/.pi/web-search.json
chezmoi cat ~/.pi/web-search.json

# 5. 提交 .age 文件，然后 apply（此时是 no-op，仅作确认）
git add -A && git commit -m "..."
chezmoi apply
```

注意事项：

- `chezmoi cat <源路径>`（如 `dot_pi/encrypted_web-search.json.age`）会报
  `not managed`——要用**目标路径**（`~/.pi/web-search.json`）。
- 改 JSON 时用 `json.load` + `indent=2` 保持与现有格式一致，避免无谓的密文噪音
  （虽然 `.age` 每次加密结果必然不同，但明文 diff 可通过 `chezmoi diff` 核对）。
- 已运行的程序（如 pi）可能需要重启才能读到新配置；部分工具会每次调用时重读文件。

## 案例：pi web_search 关闭 curator 手动 approve

`web_search` 工具来自 pi-web-access 包（`https://github.com/nicobailon/pi-web-access`）。
默认 `summary-review` workflow 会打开 curator 网页，要求手动 approve summary 才回传结果。

改法：在 `~/.pi/web-search.json`（即 `dot_pi/encrypted_web-search.json.age`）中设置：

```json
{
  "workflow": "auto-summary"
}
```

- `"auto-summary"`：模型直接生成 summary，不弹浏览器（2026-08 已配置）。
- `"none"`：不总结，直接返回原始结果。
- `"summary-review"`：默认值，打开 curator 手动 approve。
- 运行时切换：pi 内执行 `/curator off|on|summary-review`（会写回该文件，
  写回后记得 `chezmoi re-add` 同步入库，否则下次 apply 被覆盖）。
- 其他相关项：`autoOpenBrowser`、`curatorTimeoutSeconds`（默认 20s，超时会
  自动提交确定性 summary）。

### auto-summary 的模型怎么定？（已读源码确认，2026-08）

配置项 `"summaryModel": "provider/model-id"`（已在仓库中设为
`deepseek/deepseek-v4-flash`）。**只接受单个字符串，不能配多个**（`summaryModel?: string`）。
源码（`summary-review.ts`）的候选链/解析顺序是写死的：

1. config 里的 `summaryModel`；
2. 硬编码 fallback：`anthropic/claude-haiku-4-5` → `openai-codex/gpt-5.3-codex-spark`；
3. 都不可用 → **确定性模板 summary，不调 LLM**。

生成时按此顺序逐个尝试、第一个成功的生效。但后两级同样要过白名单，
本机 enabledModels 里没有 Anthropic/OpenAI 模型，所以 fallback 链实际永远
只剩配置的那一个。

**不能自动跟随当前聊天模型**——当前会话模型只会出现在 curator 下拉菜单里供手动选。

每个候选要过三道检查才可用：在 pi 模型注册表中、在 `enabledModels`
（`~/.pi/agent/settings.json`）白名单内、有 API key。因此：

- 不设 `summaryModel` 且偏好模型不在你的白名单里时（本机就是这种情况，
  白名单只有 qwen/kimi/deepseek/k3），auto-summary 会静默退化为确定性
  summary——必须显式指定白名单内的模型。
- 指定了白名单之外的模型同样静默退化，不报错。
- 模型选择变化后要重新 apply；扩展每次调用时读 `~/.pi/web-search.json`。
