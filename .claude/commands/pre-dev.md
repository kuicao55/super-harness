# 开发前准备：检查并创建新分支

在开始新功能开发前，确保没有遗留问题，并创建干净的开发分支。

## 使用场景

在 `main` 分支有稳定版本，准备开始新一轮开发时使用。

## 步骤

### 1. 检查当前状态

```bash
git branch --show-current
git status --short
```

- 如果在 `main`：✅ 继续
- 如果在 feature branch：提示用户先检查该分支

### 2. 检查 uncommitted 改动

```bash
git status --short
```

- `M` 开头的行（Modified staged/unstaged）：需要 commit 或 stash
- `??` 开头的行（Untracked）：通常是临时文件，可以忽略或添加到 .gitignore
- 无 `M` 开头的行：✅ 继续

### 3. 检查 remote 一致性

```bash
git log --oneline origin/main..main
```

- 如果有落后：提示先 `git pull`
- 如果有领先：说明本地有未 push 的 commit

检查当前分支是否已 push：
```bash
git log --oneline origin/$(git branch --show-current)..$(git branch --show-current)
```

- 有未 push commit：提示用户 `git push` 或确认要丢弃

### 4. 检查 worktree

```bash
git worktree list
```

- 如果有 worktree：列出并提示是否需要清理
- 如果没有或已清理：✅ 继续

### 5. 询问新分支名称

> "新分支名称？（默认：`user/YYYY-MM-DD-feature`，输入直接回车使用默认）"

如果用户直接回车，使用默认：
```bash
BRANCH_NAME="user/$(date +%Y-%m-%d)-feature"
```

### 6. 创建新分支

```bash
git checkout -b <branch-name>
```

### 7. 输出确认

```
✅ 开发环境已就绪

分支：<branch-name>
状态：无 uncommitted 改动
Worktree：无残留

开始开发！
```
