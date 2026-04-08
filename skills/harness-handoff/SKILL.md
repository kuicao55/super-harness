---
name: harness-handoff
description: "Session boundary handoff for super-harness. Packages current state into a Handoff Document, then triggers /clear for a fresh context. Used at the end of every session (plan complete, milestone complete, or all done)."
---

# Harness Handoff — Session Boundary Packaging

Packages the current session state into a Handoff Document, then triggers `/clear` to start a fresh context. This is the only mechanism for transferring context across sessions.

**Announce at start:** "I'm using the harness-handoff skill to package session state and clear the context."

## When to Invoke This Skill

Invoke at the end of every meaningful session boundary:

| Event | Handoff State | Next Action After Resume |
|-------|--------------|-------------------------|
| Plan confirmed after plan-writing | `PLANNING` | `/super-harness:execute` |
| First task of milestone starts | `IN_PROGRESS` | continue execution |
| Milestone's last task passes CQR | `MILESTONE_DONE` | next milestone or finish |
| All milestones done | `ALL_DONE` | project complete |

## State Machine

```
PLANNING → IN_PROGRESS → MILESTONE_DONE → ALL_DONE
    ↑           ↑             ↑
    └───────────┴─────────────┘  (on resume without completion)
```

## Step 1: Determine Current State

Before writing the handoff, determine the state:

**PLANNING:** Plan was just written, execution has not started yet.
- Read the plan file path from `status/claude-progress.json` current milestone
- No task has been started yet

**IN_PROGRESS:** Milestone execution is underway.
- Read current task from `status/claude-progress.json`
- Track which tasks are completed

**MILESTONE_DONE:** All tasks in current milestone passed Code Quality Review.
- The milestone is complete but not marked passed yet (user confirms)

**ALL_DONE:** All milestones in the project are complete.

## Step 2: Gather State

1. Read `status/claude-progress.json` — current milestone, completed tasks, pending tasks
2. Read recent activity log — `logs/activity-*.jsonl` for current session's entries
3. Check active git worktree — `git worktree list`
4. Note deferred items from activity log notes field
5. Note significant technical decisions made during this session

## Step 3: Write Handoff Document

Save to: `docs/harness/handoffs/YYYY-MM-DD-HH-MM.md`

```markdown
# Handoff — <YYYY-MM-DD HH:MM>

## State
**Status:** <PLANNING | IN_PROGRESS | MILESTONE_DONE | ALL_DONE>

## Context Index
- **spec:** <path/to/spec.md>
- **plan:** <path/to/plan.md>
- **progress:** status/claude-progress.json

## Current Position
- milestone_id: <id or null>
- task_id: <id or null> (for IN_PROGRESS state)
- tasks_completed: [<task-1>, <task-2>, ...] (for MILESTONE_DONE)

## Deferred Items
<only if any deferred items from activity log>
- <item 1>
- <item 2>

## Key Decisions
<only if significant decisions were made>
- <decision>: <rationale>

## Next Action
<command to resume, e.g. /super-harness:execute --plan docs/harness/plans/...>
```

**Key principle:** This is an envelope, not the source of truth. It references `claude-progress.json` and plan files — it does not duplicate their content.

## Step 4: Update progress-management

After writing the handoff, update `status/claude-progress.json`:
- Set `current_session_handoff` to the path of the new handoff document
- If state is `MILESTONE_DONE`: set the milestone's `passed: true`
- If state is `ALL_DONE`: no additional changes needed
- If state is `IN_PROGRESS`: update `current_task` fields

## Step 5: Confirm with User

Show the handoff document summary and ask:

> "Handoff prepared:
> - State: **\<state\>**
> - Milestone: **\<id\>**
> - Next action: **\<command\>**
>
> Clear session context? Your next session can resume with `/super-harness:resume`."

- **yes** → proceed to Step 6
- **no** → abort. Do not write the handoff document. Continue the session.

## Step 6: Reset Context

After user confirmation:

1. Announce: "Clearing session context for fresh resume..."
2. Execute `/clear` via Claude Code's built-in command
3. The next session's `/super-harness:resume` will find the handoff document

## Key Constraints

- **Read-only except for handoff and progress file:** Never modifies spec, plan, or code files
- **Minimal:** Handoff only contains pointers and state — actual content lives in the source files
- **User confirms:** Never auto-resets without explicit user confirmation
- **One handoff per session:** Overwrites previous session's handoff with latest state

## Integration

Referenced by:
- `harness-entry/SKILL.md` — `/super-harness:handoff` route
- `harness-plan-writing/SKILL.md` — after plan confirmation
- `harness-execution/SKILL.md` — after task transitions and milestone completion
