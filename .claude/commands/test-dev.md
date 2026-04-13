# 本地测试：更新开发版本号

在本地测试 plugin 时使用。每次执行会自动递增开发版本号（如 `3.5.0-dev001` → `3.5.0-dev002`），方便确认 Claude Code 加载的是最新代码。

## 步骤

### 1. 读取当前版本

```bash
python3 -c "import json; print(json.load(open('.claude-plugin/plugin.json'))['version'])"
```

### 2. 解析并递增 dev 版本号

版本号格式：`X.Y.Z` 或 `X.Y.Z-devNNN`

处理规则：
- 如果当前版本有 `-devNNN` 后缀：递增 NNN（`3.5.0-dev001` → `3.5.0-dev002`）
- 如果当前版本没有 `-dev` 后缀：从 `-dev001` 开始（`3.5.0` → `3.5.0-dev001`）

### 3. 更新版本号

更新以下文件：
- `.claude-plugin/plugin.json`
- `.claude-plugin/marketplace.json`
- `hooks/session-start`（两处：CONTEXT 字符串和 fallback echo 字符串）

### 4. 输出测试指令

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
当前开发版本：<new-version>

本地测试方法：

1. 在另一个 terminal 运行：
   claude --plugin-dir /Users/kuicao/Applications/super-harness

2. 修改代码后，在 Claude Code 里执行：
   /reload-plugins

3. 确认版本已更新：
   /help 或 /plugin

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 注意

- **不自动 commit** — dev 版本只在本地，用于测试
- 如果需要保留 dev 版本改动：手动 `git add` + `git commit`
