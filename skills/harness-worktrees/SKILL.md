---
name: harness-worktrees
description: "Git worktree isolation for super-harness. Create isolated worktrees before feature work to prevent accidental changes to main/master. Use at the start of execution or plan phases."
---

# Harness Worktrees — Git Isolation for Feature Work

Create isolated git worktrees before starting implementation work. This prevents accidental changes to `main`/`master` and makes branch management, PR creation, and cleanup straightforward.

**Announce at start:** "I'm using the harness-worktrees skill to set up git isolation."

## The Iron Law

```
DO NOT IMPLEMENT ON MAIN/MASTER WITHOUT EXPLICIT USER CONSENT.
```

All implementation work should happen in a dedicated branch. A git worktree provides an isolated working directory that won't interfere with the main checkout.

---

## When to Invoke This Skill

- At the start of `harness:harness-execution` (Orchestra will call this)
- When `harness:harness-brainstorming` or `harness:harness-plan-writing` ends and the user is about to begin execution
- When the user asks to work in isolation
- When resuming an existing worktree for continued work

**Skip this skill if:**

- The user explicitly says to work on the current branch
- The project is not a git repository
- A worktree already exists for this feature

---

## Step 1: Check Repository Status

```bash
git status
git branch --show-current
git log --oneline -5
```

Confirm:

- Which branch is currently active
- Whether there are uncommitted changes (warn user if so)
- Whether a suitable worktree already exists

---

## Step 2: Choose Worktree Directory

Priority order for selecting the worktree location:

**Priority 1:** Check if there's an existing worktree for this feature:

```bash
git worktree list
```

If an existing worktree matches the current task/milestone, offer to use it.

**Priority 2:** Check for a configured worktrees directory in `CLAUDE.md`, `harness.config.json`, or `.claude-plugin/config.json`:

```
worktrees_dir: /path/to/worktrees/
```

**Priority 3:** Ask the user:

> "Where should I create the worktree?
>
> - Default: `../worktrees/<project-name>-<feature-name>/`
> - Custom: [enter path]"

---

## Step 3: Choose Branch Name

Suggest a branch name based on the current task or milestone:

```
harness/<milestone-id>-<short-description>
harness/milestone-3-user-auth
harness/feature-payment-integration
```

Ask for confirmation: "Branch name: `harness/<name>`. OK? (yes/change)"

---

## Step 4: Create the Worktree

```bash
# Create new branch + worktree in one command
git worktree add <worktree-path> -b <branch-name>

# Example:
git worktree add ../worktrees/myproject-user-auth -b harness/milestone-3-user-auth
```

Confirm creation:

```bash
git worktree list
```

---

## Step 5: Verify Baseline Tests

Before any implementation work, run the test suite in the new worktree to establish a clean baseline:

```bash
cd <worktree-path>
<install deps if needed>
<run test suite>
```

If tests fail at baseline:

> "⚠️ Tests are failing before any implementation. This is the baseline state — document it and continue. The failures must be pre-existing."

Ask user: "Continue with failing baseline? (yes/no)"

---

## Step 6: Update .gitignore

Check that `../<worktree-path>` is not accidentally tracked. Verify:

```bash
cat .gitignore | grep worktree
```

If worktrees directory is not gitignored, add it:

```bash
echo "worktrees/" >> .gitignore
```

---

## Step 7: Hand Off to Execution

After worktree is set up and baseline verified:

> "Worktree ready at: `<worktree-path>` on branch `<branch-name>`.
>
> Baseline: <N tests pass / tests failing — pre-existing>.
>
> All implementation work will happen in this worktree."

Provide the worktree path to `harness:harness-execution` as the working directory for all Executor subagents.

---

## Worktree Cleanup (After Finishing)

This is handled by `harness:harness-finishing`. But if manual cleanup is needed:

```bash
# Remove the worktree (must be done from main checkout)
git worktree remove <worktree-path>

# Or force remove if there are uncommitted changes
git worktree remove --force <worktree-path>

# Clean up any worktree metadata
git worktree prune
```

---

## Multiple Worktrees (Parallel Work)

When `harness:harness-parallel-dispatch` is used for parallel Executor instances:

- Create one worktree per parallel branch
- Use naming: `harness/<milestone>-<task-group>-N`
- After all parallel work completes, merge into a single integration worktree

```bash
git worktree add ../worktrees/project-parallel-a -b harness/parallel-a
git worktree add ../worktrees/project-parallel-b -b harness/parallel-b
```

---

## Troubleshooting

**"fatal: '<path>' is not a git repository"**
→ Run from the root of the git repository

**"fatal: '<path>' already exists"**
→ Check `git worktree list` — the worktree may already exist; use it or remove and recreate

**"error: cannot checkout '<branch>' in worktree: already checked out"**
→ The branch is already checked out in another worktree; choose a different branch name

**Tests fail in worktree but not in main checkout**
→ Check if dependencies were installed in the worktree (`npm install`, `pip install`, etc.)
