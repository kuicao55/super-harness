---
name: harness-parallel-dispatch
description: "Parallel agent dispatch for claude-codex-harness Orchestra. Use when multiple independent tasks can be worked on simultaneously. Manages parallel Executor dispatch, conflict resolution, and integration verification."
---

# Harness Parallel Dispatch — Concurrent Executor Coordination

When multiple tasks are truly independent, Orchestra can dispatch them in parallel to different Executor agents (Claude subagents or Codex instances) to save time. This skill handles the decision, dispatch, conflict resolution, and integration.

**Announce at start:** "I'm using the harness-parallel-dispatch skill to coordinate parallel execution."

## The Iron Law

```
ONLY PARALLELIZE TRULY INDEPENDENT TASKS. WHEN IN DOUBT, SERIALIZE.
```

Incorrectly parallelizing tasks with hidden dependencies causes merge conflicts, integration failures, and harder debugging. The time saved is not worth the complexity if you're uncertain.

---

## When to Invoke This Skill

Orchestra invokes this skill when deciding task execution order. Invoke explicitly when:

- A set of plan tasks has no inter-dependencies
- The user asks for faster execution through parallelism
- The tasks target clearly separate parts of the codebase

---

## Step 1: Independence Check

For each pair of candidate tasks, verify ALL of the following:

```
□ Different files — tasks A and B do not modify the same file
□ No shared state — A does not create something B depends on
□ No interface dependency — B does not call functions A is creating
□ No test conflicts — A and B do not modify the same test files
□ No schema dependency — A does not migrate a schema that B queries
□ No sequential requirement — the spec does not say "A must be done before B"
```

**If ANY condition fails: serialize, do not parallelize.**

A good sign that tasks are parallelizable:

- "Implement the frontend component" and "Implement the backend endpoint" (separate files, clear interface boundary)
- "Add user profile feature" and "Add notification feature" (separate modules)

A bad sign:

- "Create the database schema" and "Implement the API" (sequential dependency)
- "Define the interface" and "Implement the service" (interface must exist first)

---

## Step 2: Present Parallel Proposal to User

> "Tasks N and M appear to be independent. I can dispatch them in parallel:
>
> **Task N:** \<title\> — modifies: `\<files\>`
> **Task M:** \<title\> — modifies: `\<files\>`
>
> Parallelizing these would dispatch two Executor agents simultaneously.
>
> Proceed in parallel? (yes/no, default: yes)"

Wait for confirmation before dispatching.

---

## Step 3: Set Up Parallel Worktrees (if not already done)

For each parallel Executor, ensure a separate worktree is available:

```bash
# Worktree A for task N
git worktree add ../worktrees/project-parallel-a -b harness/parallel-task-N

# Worktree B for task M
git worktree add ../worktrees/project-parallel-b -b harness/parallel-task-M
```

Each Executor works in its own isolated worktree. They cannot interfere with each other.

---

## Step 4: Dispatch Parallel Executors

Use the Task tool to dispatch both agents simultaneously (do NOT await one before dispatching the other):

```
Task A: Executor for Task N
  → executor-prompt.md template
  → working directory: ../worktrees/project-parallel-a
  → full task N text

Task B: Executor for Task M
  → executor-prompt.md template
  → working directory: ../worktrees/project-parallel-b
  → full task M text
```

Announce to user: "Both Executors dispatched simultaneously. Waiting for results..."

---

## Step 5: Collect Results

Wait for both Executors to report. Track status for each:

| Task   | Status               | Notes |
| ------ | -------------------- | ----- |
| Task N | DONE / BLOCKED / ... | ...   |
| Task M | DONE / BLOCKED / ... | ...   |

**If one Executor reports BLOCKED:**

- Let the other continue to completion
- Handle the BLOCKED task separately (offer Codex rescue or user guidance)

**If both complete successfully:**

- Proceed to Spec Review for each (can also be parallel)
- Code Quality Review for each (can also be parallel)

---

## Step 6: Spec Review (Parallel)

Run Spec Review for both in parallel, if Reviewers are available:

```
Spec Reviewer A: reviews Task N work
Spec Reviewer B: reviews Task M work
```

Collect both verdicts before proceeding.

---

## Step 7: Code Quality Review (Parallel)

If Spec Review passes for both, run Code Quality Review in parallel:

```
Code Quality Reviewer A: attacks Task N work
Code Quality Reviewer B: attacks Task M work
```

Collect both verdicts.

---

## Step 8: Conflict Check Before Integration

After both tasks pass all reviews, check for conflicts before merging:

```bash
# In worktree A, simulate merge of B
cd ../worktrees/project-parallel-a
git fetch origin harness/parallel-task-M
git merge --no-commit --no-ff harness/parallel-task-M
git merge --abort  # Don't actually merge, just check
```

**If conflicts exist:**

> "⚠️ Merge conflict detected between Task N and Task M changes in: `<conflicting-files>`
>
> Options:
>
> 1. Resolve manually (I'll show the conflicts)
> 2. Dispatch a reconciliation Executor to resolve the conflicts
> 3. Serialize: apply Task M changes on top of Task N's final code"

**If no conflicts:**
→ Proceed to integration.

---

## Step 9: Integration and Full Test Run

After merging the parallel branches (in a temporary integration worktree or staging branch):

```bash
# Create integration branch from base
git checkout -b harness/integration-<milestone>

# Merge parallel branches
git merge harness/parallel-task-N
git merge harness/parallel-task-M

# Run full test suite
<test command>
```

**ALL tests must pass after integration.** If tests fail at this point:

1. The tasks were not actually independent, or
2. There's an integration bug to debug

Invoke `claude-codex-harness:harness-debugging` if needed.

---

## Step 10: Activity Logging

Log each parallel task separately in the activity log, noting they were parallel:

```json
{
  "task_id": "task-N",
  "notes": "Executed in parallel with task-M. Integration test: passed.",
  ...
}
```

---

## Parallel Dispatch Limits

- Maximum 3 simultaneous Executor agents recommended
- Each Executor needs its own worktree (see Step 3)
- Do not parallelize more tasks than you can monitor effectively
- If a parallelized task has an unexpected BLOCKED: serialize the remainder

---

## Decision Flow Summary

```
Candidate tasks for parallel dispatch?
  → Independence check (all 6 conditions pass?)
    → No: serialize
    → Yes: present proposal to user
      → User confirms: create worktrees, dispatch simultaneously
      → Collect results
      → Review in parallel
      → Conflict check
      → Integration test
      → Merge
```
