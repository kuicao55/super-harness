---
name: harness-finishing
description: "Development branch completion for claude-codex-harness. Verifies tests, presents 4 integration options, and cleans up worktrees. Use when all tasks in a plan are complete."
---

# Harness Finishing — Development Branch Completion

Guide the completion of implementation work: verify everything passes, decide how to integrate the work, and clean up the git worktree.

**Announce at start:** "I'm using the harness-finishing skill to complete this development branch."

## When to Invoke This Skill

Invoked automatically by `claude-codex-harness:harness-execution` after all tasks complete and Code Quality Review has passed for each task.

Also invoke directly when the user wants to wrap up a development branch.

---

## Phase 1: Verify Tests Pass

Before considering any merge or PR, confirm the complete test suite passes:

```bash
cd <worktree-path>
<run full test suite>
```

**If tests fail:**

Stop. Do NOT proceed to integration options. Invoke `claude-codex-harness:harness-debugging` to investigate.

> "⚠️ Tests are failing before merge. Cannot proceed with integration until tests pass."

**If tests pass:**

Display verification summary:

> "✅ All tests passing: N/N passed, 0 failed
>
> Branch `<branch-name>` is ready for integration."

---

## Phase 2: Identify the Base Branch

Determine the target branch for integration:

```bash
git branch -a | grep -E "main|master|develop"
git log --oneline <branch-name>..main  # commits unique to this branch
```

Ask the user if unclear: "What is the base branch for this work? (main/master/develop)"

Summarize what's on the branch:

> "Branch `harness/<name>` contains N commits since `<base>`:
>
> - [commit summaries]
> - Files changed: <count>
> - Tests: N/N passing"

---

## Phase 3: Integration Decision (4 Options)

Present the integration options:

> "All N tasks complete and verified. How would you like to integrate this work?
>
> 1. **Merge locally** — merge `<branch>` into `<base>` right now (good for solo work)
> 2. **Push and create PR** — push branch and open a pull request (good for team review)
> 3. **Keep branch open** — leave the worktree as-is, continue later (no integration yet)
> 4. **Discard** — abandon this branch and worktree (throw away all work)"

Wait for user selection.

### Option 1: Merge Locally

```bash
cd <main-checkout>
git checkout <base-branch>
git merge --no-ff <branch-name> -m "harness: merge <milestone> — <description>"
```

Verify the merge:

```bash
git log --oneline -5
<run full test suite on base branch>
```

If merge tests fail: `git merge --abort` (if still in merge state) or discuss with user.

After successful merge, proceed to Phase 4 (Worktree Cleanup).

### Option 2: Push and Create PR

```bash
cd <worktree-path>
git push -u origin <branch-name>
```

Then create the PR (using gh CLI or display instructions):

```bash
gh pr create \
  --title "<milestone/feature title>" \
  --body "$(cat <<'EOF'
## Summary
- [bullet point summary of what was built]
- [N tasks completed, all Code Quality Review approved]

## Test Plan
- [ ] All unit tests passing (N/N)
- [ ] All integration tests passing (N/N)
- [ ] Code Quality Review passed for all tasks

## Harness log
Activity log: logs/activity-<date>.jsonl
EOF
)"
```

Display the PR URL when created.

After pushing and creating PR, ask: "Proceed with worktree cleanup? (yes/no)"

### Option 3: Keep Branch Open

> "Branch `<name>` and worktree `<path>` preserved. Resume with `/harness:resume` when ready."

Update `claude-progress.json` if applicable (don't mark milestone as passed — it's still open).

No cleanup.

### Option 4: Discard

Confirm with user before discarding:

> "⚠️ This will discard ALL work on branch `<name>`. This cannot be undone. Are you sure? (type 'DISCARD' to confirm)"

Only proceed if user types `DISCARD`.

```bash
cd <main-checkout>
git worktree remove --force <worktree-path>
git branch -D <branch-name>
git worktree prune
```

---

## Phase 4: Worktree Cleanup

After Option 1 (merge) or Option 2 (PR, if user agreed):

```bash
# From the main checkout directory
git worktree remove <worktree-path>
git worktree prune
```

If the branch was merged and is no longer needed:

```bash
git branch -d <branch-name>
```

Confirm cleanup:

```bash
git worktree list
git branch
```

---

## Phase 5: Mark Milestone Complete

After successful merge or PR creation:

1. Invoke `claude-codex-harness:progress-management` to mark the current milestone as passed:
   - Set `passed: true`
   - Set `session_date` to today
   - Update `updated_at` timestamp

2. Invoke `claude-codex-harness:activity-logging` to record the branch completion event.

3. Display completion summary:

> "### Development Branch Complete 🎯
>
> **Branch:** `<branch-name>`
> **Tasks:** N completed (all Code Quality Review approved)
> **Integration:** <Merged locally / PR #N created / Kept open / Discarded>
> **Milestone:** \<title\> — marked as passed
>
> Next milestone: \<next milestone title and description\> (if applicable)"

---

## Red Flags — STOP

- Merging while tests are failing
- Discarding without explicit `DISCARD` confirmation
- Merging to `main`/`master` on a team project without a PR
- Cleaning up worktree before confirming successful merge/push
- Marking milestone as passed before merge/PR is confirmed
