---
name: harness-entry
description: "Command routing and session resume logic for claude-codex-harness. Use when processing any /harness: command invocation."
---

# Harness Entry — Command Router and Session Resumption

This skill handles the entry point for all `/harness:` commands. It establishes cross-cutting concerns and routes to the correct phase.

**Announce at start:** "I'm using the harness-entry skill to route this command."

## Cross-Cutting Concerns

Before routing, establish these two skills as active cross-cutting concerns for this session:

- `harness:progress-management` — will be invoked whenever `claude-progress.json` must be read or written
- `harness:activity-logging` — will be invoked after every completed task

## Routing Logic

### If invoked via `/harness:brainstorm`

If the user has not already provided the concrete feature/problem context, ask first:

> "这次要 brainstorm 的具体功能或问题是什么？请尽量描述目标、当前现象和期望结果。"

Then route to `harness:harness-brainstorming` with that context. No state check needed.

### If invoked via `/harness:plan`

Route directly to `harness:harness-plan-writing`. No state check needed. The plan-writing skill handles scale assessment internally.

### If invoked via `/harness:execute`

**Execution gate (same as `commands/execute.md` and `harness-execution`):** Orchestra does not implement or review code directly. Route to `harness:harness-execution` and follow its HARD-GATE: dispatch Executor and both reviewers (subagent or Codex), confirm engine with the user every stage, maintain TodoWrite from the start, and only close a task after Code Quality Review **PASS**.

Check if a plan file exists. Ask the user: "Which plan file should I execute? (Provide the path, or press Enter if there's only one plan in `docs/harness/plans/`)"

Then route to `harness:harness-execution` with the specified plan.

### If invoked via `/harness:status`

Display status as defined in the `commands/status.md` command. Do not route further.

### If invoked via `/harness:resume`

Follow the full resume flow below.

---

## Resume Flow

**Announce:** "Reading project progress file..."

### Step 1: Locate Progress File

Look for `status/claude-progress.json` in the current working directory.

- If NOT found: Tell the user:

  > "No `status/claude-progress.json` found. This may be a small single-session project without milestone tracking, or the project hasn't been started yet.
  >
  > What would you like to do?
  >
  > 1. Start brainstorming a new project (`/harness:brainstorm`)
  > 2. Jump directly to planning (`/harness:plan`)
  > 3. Execute an existing plan (`/harness:execute`)"

  Wait for user choice and route accordingly.

- If found: proceed to Step 2.

### Step 2: Parse and Display Current State

Read `status/claude-progress.json` and display:

```
## Resuming Project: <project name>

Last updated: <updated_at>

### Milestone Progress
✅ Milestone 1: <title> (completed <session_date>)
✅ Milestone 2: <title> (completed <session_date>)
🔄 Milestone 3: <title> (in progress — plan: <plan_file or "not yet created">)
⏳ Milestone 4: <title> (not started)

Next up: Milestone 3 — <description>
```

### Step 2.5: Read Activity Log

Look for `logs/activity-*.jsonl` files matching the current milestone's session date (or the most recent log file).

If found, display the most recent 5 entries for the current milestone:

```
Recent activity (from logs/activity-<date>.jsonl):
  <time> — task-N <verdict> — <action summary>
  <time> — task-N+1 <verdict> — <action summary>
```

Surface any entries with:

- `evaluator_status: FAIL_THEN_PASS` — flag re-implementation happened
- `notes` containing deferred items — highlight for user awareness
- `generator_status: BLOCKED` — flag tasks that were problematic

> "⚠️ Deferred items from previous session: [list notes from activity log]"

### Step 3: Check Dependency Prerequisites

For the next incomplete milestone, check its `depends_on` list. If any listed milestone has `passed: false`, warn the user:

> "⚠️ Warning: Milestone N depends on [milestone X], which is not yet marked as passed. Proceeding anyway may cause integration issues."

Ask: "Continue anyway? (yes/no)"

### Step 4: Determine Resume Action

Find the first milestone where `passed: false`. Check its `plan_file` field:

**Case A — `plan_file` is `null` (no plan created yet):**

> "No plan exists for this milestone yet. I'll run the plan-writing skill to create one."

Route to `harness:harness-plan-writing` with the milestone context.

**Case B — `plan_file` exists, and the plan has unchecked tasks:**

> "Found an in-progress plan at `<plan_file>`. Let me check task completion status..."

Read the plan file. Count checked `- [x]` vs unchecked `- [ ]` tasks. Display:

> "Plan has X/N tasks completed. Resuming from Task \<next unchecked task\>."

Route to `harness:harness-execution` with the plan file and resume context.

**Case C — `plan_file` exists, all tasks checked, but `passed: false`:**

> "All tasks in the plan appear complete but this milestone hasn't been marked passed. This may mean the Code Quality Review wasn't completed."

Ask: "Would you like to:

1. Mark this milestone as passed and move to the next one
2. Re-run the Code Quality Review on the existing code
3. Create a fresh plan for this milestone and re-execute"

Wait for user choice and act accordingly.

## Key Rules

- NEVER skip the dependency check for milestones with `depends_on`
- ALWAYS read the activity log before resuming to surface deferred items
- ALWAYS show the user the current state before asking what to do
- ALWAYS announce which sub-skill is being invoked
- The resume flow must create a new session-level plan if none exists — never jump straight to execution without a plan
