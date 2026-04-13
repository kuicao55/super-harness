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

```bash
# 示例：从 3.5.0-dev001 递增到 3.5.0-dev002
OLD_VERSION="3.5.0-dev001"
NEW_VERSION="3.5.0-dev002"

# 更新 .claude-plugin/plugin.json
sed -i '' "s/\"version\": \"$OLD_VERSION\"/\"version\": \"$NEW_VERSION\"/" .claude-plugin/plugin.json

# 更新 .claude-plugin/marketplace.json
sed -i '' "s/\"version\": \"$OLD_VERSION\"/\"version\": \"$NEW_VERSION\"/" .claude-plugin/marketplace.json

# 更新 hooks/session-start（全局替换）
sed -i '' "s/$OLD_VERSION/$NEW_VERSION/g" hooks/session-start
```

验证更新：
```bash
grep -r "$NEW_VERSION" .claude-plugin/ hooks/session-start
```

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
