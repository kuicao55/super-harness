---
name: harness-entry
description: "Command routing and session resume logic for super-harness. Use when processing any /super-harness: command invocation."
---

# Harness Entry — Command Router and Session Resumption

This skill handles the entry point for all `/super-harness:` commands. It establishes cross-cutting concerns and routes to the correct phase.

**Announce at start:** "I'm using the harness-entry skill to route this command."

## Cross-Cutting Concerns

Before routing, establish these two skills as active cross-cutting concerns for this session:

- `harness:progress-management` — will be invoked whenever `claude-progress.json` must be read or written
- `harness:activity-logging` — will be invoked after every completed task

## Routing Logic

### If invoked via `/super-harness:brainstorm`

If the user has not already provided the concrete feature/problem context, ask first:

> "这次要 brainstorm 的具体功能或问题是什么？请尽量描述目标、当前现象和期望结果。"

Then route to `harness:harness-brainstorming` with that context. No state check needed.

### If invoked via `/super-harness:plan`

Route directly to `harness:harness-plan-writing`. No state check needed. The plan-writing skill handles scale assessment internally.

### If invoked via `/super-harness:execute`

**Execution gate (same as `commands/execute.md` and `harness-execution`):** Orchestrator does not implement or review code directly. Route to `harness:harness-execution` and follow its HARD-GATE: dispatch Executor and both reviewers (subagent or Codex), confirm engine with the user every stage, maintain TodoWrite from the start, and only close a task after Code Quality Review **PASS**.

Check if a plan file exists. Ask the user: "Which plan file should I execute? (Provide the path, or press Enter if there's only one plan in `docs/harness/plans/`)"

Then route to `harness:harness-execution` with the specified plan.

### If invoked via `/super-harness:status`

Display status as defined in the `commands/status.md` command. Do not route further.

### If invoked via `/super-harness:handoff`

Route to `harness:harness-handoff`. This skill packages the current session state into a Handoff Document and triggers `/clear` for a fresh context. Supports plan completion, milestone completion, and manual invocation.

### If invoked via `/super-harness:tdd-audit`

Route to `harness:harness-tdd-audit`. This skill is typically called by Orchestrator internally after Executor reports DONE. It can also be triggered manually to audit a completed task. Requires Executor report + file list as input.

### If invoked via `/super-harness:resume`

Follow the full resume flow below.

---

## Resume Flow

**Announce:** "Loading handoff document to resume..."

### Step 1: Locate Handoff Document

Look for the most recent file in `docs/harness/handoffs/` directory.

- If NOT found: Tell the user:

  > "No handoff document found. This is a fresh start.
  >
  > What would you like to do?
  >
  > 1. Start brainstorming a new project (`/super-harness:brainstorm`)
  > 2. Jump directly to planning (`/super-harness:plan`)
  > 3. Execute an existing plan (`/super-harness:execute`)"

  Wait for user choice and route accordingly.

- If found: read the handoff document and proceed to Step 2.

### Step 2: Display Handoff Summary

Read the handoff document and display:

```
## Resuming from Handoff — <YYYY-MM-DD HH:MM>

**Status:** <PLANNING | IN_PROGRESS | MILESTONE_DONE | ALL_DONE>

### Context Index
- Spec: <path>
- Plan: <path>
- Progress: status/claude-progress.json

### Current Position
<state-specific information>

### Deferred Items
<if any>

### Key Decisions
<if any>

### Next Action
<command>
```

### Step 3: Load Context from Index Pointers

Based on the context index in the handoff:

1. Read `status/claude-progress.json` — milestone state, current task
2. Read the plan file — full task list with completion status
3. Read the spec file — full specification for reference

Inject all relevant context into the Orchestrator's initial context.

### Step 4: Route Based on State

**If state is PLANNING:**
> "Plan was written in the previous session. Ready to start execution."
Route to `harness:harness-execution` with the plan.

**If state is IN_PROGRESS:**
> "Resuming from Task \<N\>. Ready to continue execution."
Route to `harness:harness-execution` with the plan and current task context.

**If state is MILESTONE_DONE:**
> "Milestone complete! What's next?
>
> 1. Start the next milestone (create plan)
> 2. Run `/super-harness:handoff` to finalize project
> 3. Something else"

Wait for user choice.

**If state is ALL_DONE:**
> "All milestones are complete. Project is finished!
>
> 1. Run `/super-harness:finish` to complete the project
> 2. Start a new project"

Wait for user choice.

## Key Rules

- The handoff document is the SOLE source of truth for session state
- Always read the full plan file to know exact task completion status
- Always read the spec file for context on requirements
- Always display deferred items and key decisions from handoff
- The `/super-harness:resume` command is the only entry point — never skip it
