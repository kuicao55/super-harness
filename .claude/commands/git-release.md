# 版本发布：更新 README、版本号、GitHub Release、Marketplace

这个 command 会执行完整的版本发布流程。

## 步骤

### 1. 分析变更内容
- 运行 `git diff HEAD~1 --stat` 查看最近一次提交的变更统计
- 运行 `git diff HEAD~1` 查看具体变更内容
- 分析变更的文件路径和内容，推断更新主题和范围

### 2. 更新 README.md
- 读取 `./README.md`（只关注根目录）
- 根据 git diff 的变更内容，找出 README 中需要同步更新的地方：
  - 流程图的变更（如去掉 Both 模式、新增脚本等）
  - 目录结构的变更（如新增脚本文件）
  - 配置表格的变更（如默认值修改）
  - 路径引用的变更（如 handoff 文件路径）
  - 新增功能的描述
- 直接修改 README.md 中对应的部分
- 不要改动 README 中与本次变更无关的内容

### 3. 确定新版本号
- 读取当前版本号（从 `.claude-plugin/plugin.json` 中获取）
- 根据变更类型自动判断版本号递增：
  - **Patch** (x.x.N+1): bug 修复、小改动、文档更新
  - **Minor** (x.N+1.0): 新功能、新脚本、流程变更
  - **Major** (N+1.0.0): 架构变更、不兼容改动
- 告知用户新版本号

### 4. 更新所有文件中的版本号
- 在整个项目中搜索当前版本号
- 将所有出现的地方替换为新版本号
- 常见位置：`.claude-plugin/plugin.json`、`.claude-plugin/marketplace.json`、`README.md`、`hooks/session-start`、`skills/*/SKILL.md`
- **必须**更新 `.claude-plugin/marketplace.json` 中的 version 字段（marketplace 下载时读此文件）

### 5. 提交并推送
- `git add` 所有修改的文件（**包括** `.claude-plugin/marketplace.json`，不要 add .DS_Store 等无关文件）
- 确保 `.claude-plugin/marketplace.json` 不是 untracked 状态（`git status` 检查）
- 生成 commit message，格式：`chore: bump version to vX.Y.Z — <简要描述主要变更>`
- `git push origin main`

### 6. 创建 GitHub Release
- 使用 `gh release create` 创建新 release，**确保 tag 指向刚才推送的 commit**
- Title: `vX.Y.Z`
- Body: 列出本次所有变更，分为 New / Changed / Fixed 三类
- Tag: `vX.Y.Z`（`gh release create` 会自动在此 commit 上创建 tag）

### 7. 验证 tag 和版本一致性
- 运行 `git rev-parse vX.Y.Z` 确认 tag 指向的 commit 与版本 bump commit 相同
- 运行 `git show vX.Y.Z:.claude-plugin/plugin.json | grep version` 确认 tag 对应的 plugin.json 版本号正确
- 如果不一致（tag 指向旧 commit），必须 `git push origin vX.Y.Z --force` 修正

### 8. 更新 claude-plugins marketplace
- 更新 `/Users/kuicao/Applications/claude-plugins/.claude-plugin/marketplace.json` 中的版本号
- 更新 `/Users/kuicao/Applications/claude-plugins/README.md` 中的版本号描述
- `cd /Users/kuicao/Applications/claude-plugins && git add && git commit -m "chore: bump super-harness to vX.Y.Z" && git push origin main`

### 9. 输出结果
- 显示 commit 内容
- 显示 GitHub Release URL
- 确认 marketplace 已更新
- 显示 `plugin.json` 中的版本号和 tag 指向的 commit SHA，确认两者一致

## 注意
- 如果没有代码变更（只有未提交的改动），先提示用户确认是否提交
- 版本号更新必须是全局的，不能遗漏任何文件
- Release notes 要详细，涵盖所有本次变更
- 如果 push 或 release 创建失败，提示用户检查 GitHub 状态
