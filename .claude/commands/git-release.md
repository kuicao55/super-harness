# 版本发布：更新 README、版本号、GitHub Release、Marketplace

这个 command 会执行完整的版本发布流程。

## 前置条件

- 在 feature branch 上完成开发
- 所有改动已 commit 和 push
- 测试通过

## 步骤

### 0. 前置检查

- 检查当前分支：必须在 feature branch，不能在 main
  - 如果在 main：提示用户先切换到 feature branch
- 检查 uncommitted 改动：有则提示先 commit
- 检查是否已 push 到 remote：未 push 则提示先 push
- 检查 worktree：提示确认无残留 worktree

```bash
git branch --show-current
git status --short
git worktree list
```

### 1. 分析变更内容 + 合并到 main

#### 1.1 分析分支 diff

```bash
git diff main..HEAD --stat
git log main..HEAD --oneline
```

#### 1.2 创建 PR 并合并

```bash
# 创建 PR 并获取 PR number
PR_URL=$(gh pr create --title "Release vX.Y.Z" --body "Release notes" --base main)
gh pr merge --squash --delete-branch
```

或者手动合并后删除分支：
```bash
gh pr create --title "Release vX.Y.Z" --body "Release notes" --base main
# 在 GitHub 网页上手动 merge
# 然后继续执行后续步骤
```

#### 1.3 切换到 main 并分析真正要 release 的变更

```bash
git checkout main && git pull
git diff HEAD~1 --stat
git diff HEAD~1
```

### 2. 更新 README.md

- 读取 `./README.md`
- 根据 git diff 的变更内容，找出 README 中需要同步更新的地方：
  - 流程图的变更
  - 目录结构的变更
  - 新增功能的描述
- 直接修改 README.md 中对应的部分

### 3. 确定新版本号

- 读取当前版本号（从 `.claude-plugin/plugin.json` 中获取）
- 自动去掉 `-devNNN` 后缀得到正式版本（如 `3.5.0-dev002` → `3.5.0`）
- 根据变更类型自动判断版本号递增：
  - **Patch** (x.x.N+1): bug 修复、小改动、文档更新
  - **Minor** (x.N+1.0): 新功能、新脚本、流程变更
  - **Major** (N+1.0.0): 架构变更、不兼容改动
- 告知用户新版本号

### 4. 更新所有文件中的版本号

- 在整个项目中搜索当前的 dev 版本号（如 `3.5.0-dev001`）
- 将所有出现的地方替换为新正式版本号（如 `3.5.1`）
- 使用全局替换：`sed -i '' 's/<old-version>/<new-version>/g' <files>`
- 常见位置：`.claude-plugin/plugin.json`、`.claude-plugin/marketplace.json`、`README.md`、`hooks/session-start`
- **必须**更新 `.claude-plugin/marketplace.json` 中的 version 字段

### 5. 提交并推送

- `git add` 所有修改的文件（**包括** `.claude-plugin/marketplace.json`，不要 add .DS_Store 等无关文件）
- 确保 `.claude-plugin/marketplace.json` 不是 untracked 状态
- 生成 commit message，格式：`chore: bump version to vX.Y.Z — <简要描述主要变更>`
- `git push origin main`

### 6. 创建 GitHub Release

- 使用 `gh release create` 创建新 release
- Title: `vX.Y.Z`
- Body: 列出本次所有变更，分为 New / Changed / Fixed 三类
- Tag: `vX.Y.Z`

### 7. 验证 tag 和版本一致性

- 运行 `git rev-parse vX.Y.Z` 确认 tag 指向的 commit 与版本 bump commit 相同
- 运行 `git show vX.Y.Z:.claude-plugin/plugin.json | grep version` 确认版本号正确
- 如果不一致：必须 `git push origin vX.Y.Z --force` 修正

### 8. 更新 claude-plugins marketplace

- 更新 `/Users/kuicao/Applications/claude-plugins/.claude-plugin/marketplace.json` 中的版本号
- 更新 `/Users/kuicao/Applications/claude-plugins/README.md` 中的版本号描述
- `cd /Users/kuicao/Applications/claude-plugins && git add && git commit -m "chore: bump super-harness to vX.Y.Z" && git push origin main`

### 8.5 最终清理检查

```bash
git status          # 确认工作目录干净
git worktree list   # 确认无残留 worktree
git fetch + git status  # 确认本地远端一致
```

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
