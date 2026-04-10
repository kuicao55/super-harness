---
name: harness-entry
description: "Command routing and session resume logic for super-harness. Use when processing any /super-harness: command invocation."
---

# Harness Entry — Command Router and Session Resumption

This skill handles the entry point for all `/super-harness:` commands. It establishes cross-cutting concerns and routes to the correct phase.

**Announce at start:** "I'm using the harness-entry skill to route this command."

## Pre-flight Check

Before routing, establish project state with these Bash commands:

```bash
# Check if git repository
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "WARNING: Not a git repository. Activity logging and handoffs require git."
fi

# Check if progress file exists
if [[ -f "status/claude-progress.json" ]]; then
  # Existing project - read current milestone
  CURRENT_MILESTONE=$(grep -o '"id"' status/claude-progress.json | head -1)
  echo "Existing project detected. Current milestone: $CURRENT_MILESTONE"
else
  # Fresh project - create directory structure
  echo "Fresh project detected. Creating directory structure..."
  mkdir -p status docs/harness/specs docs/harness/plans docs/harness/handoffs logs
  echo "Created: status/, docs/harness/specs/, docs/harness/plans/, docs/harness/handoffs/, logs/"
  echo "Ready to start. Run /super-harness:brainstorm or /super-harness:plan to begin."
fi
```

**Interpretation:**

| Scenario | What it means | User message |
|----------|---------------|--------------|
| Fresh project (no progress file) | First time using harness | "First time using harness in this project. Directory structure created. Ready to start." |
| Existing project | Resuming or adding milestones | Display current milestone and status |
| Git not initialized | Warning | "WARNING: This is not a git repository. Git is required for activity logging and handoffs to work properly." |
| Missing directories | Auto-created | "Created missing directories: ..." |

**Do NOT proceed with any routing until pre-flight check completes.**

## Cross-Cutting Concerns

Before routing, establish these two skills as active cross-cutting concerns for this session:

- `progress-management` — will be invoked whenever `claude-progress.json` must be read or written
- `activity-logging` — will be invoked after every completed task

## Chain-Call Shortcut

When one skill directly invokes another (e.g., brainstorming → plan-writing, plan-writing → handoff), **skip harness-entry** and route directly to the target skill. harness-entry only runs on the *initial* user command (`/super-harness:brainstorm`, `/super-harness:plan`, etc.). Do not re-run pre-flight or announce routing for chain calls.

## Routing Logic

### If invoked via `/super-harness:brainstorm`

If the user has not already provided the concrete feature/problem context, ask first:

> "这次要 brainstorm 的具体功能或问题是什么？请尽量描述目标、当前现象和期望结果。"

Then route to `harness-brainstorming` with that context. No state check needed.

### If invoked via `/super-harness:plan`

**Pre-check:** Check if any design spec exists at `docs/harness/specs/`:
- If **no spec exists**: Tell the user:
  > "No design spec found. You should brainstorm first to create a spec.
  > Run `/super-harness:brainstorm` to start."
  Do not route further — wait for user to choose brainstorm.
- If spec exists: Route directly to `harness-plan-writing`. The plan-writing skill handles scale assessment internally.

### If invoked via `/super-harness:execute`

> **Recommendation:** Start from `/super-harness:brainstorm` for new features. Direct execution is only for resuming an existing plan.

**Execution gate:** Orchestrator does not implement or review code directly. Route to `harness-execution` and follow its HARD-GATE: dispatch Executor and both reviewers (subagent or Codex), confirm engine with the user every stage, maintain TodoWrite from the start, and only close a task after Code Quality Review **PASS**.

Check if a plan file exists. Ask the user: "Which plan file should I execute? (Provide the path, or press Enter if there's only one plan in `docs/harness/plans/`)"

Then route to `harness-execution` with the specified plan.

### If invoked via `/super-harness:status`

Display status as defined in the `commands/status.md` command. Do not route further.

### If invoked via `/super-harness:handoff`

Route to `harness-handoff`. This skill packages the current session state into a Handoff Document and triggers `/clear` for a fresh context. Supports plan completion, milestone completion, and manual invocation.

### If invoked via `/super-harness:tdd-audit`

Route to `harness-tdd-audit`. This skill is typically called by Orchestrator internally after Executor reports DONE. It can also be triggered manually to audit a completed task. Requires Executor report + file list as input.

### If invoked via `/super-harness:init`

Route to `harness-init`. This skill reads the entire codebase and generates `status/PROJECT.md`. Run once per project to establish project context for future sessions.

### If invoked via `/super-harness:resume`

Follow the full resume flow below.

---

## Resume Flow

**Announce:** "Loading handoff document to resume..."

### Step 1: Locate Handoff Document

Read `docs/harness/handoffs/handoff.md` — this is the single, always-current handoff file.

- If found: proceed to Step 2.
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

### Step 2b: Validate Referenced Files Exist

After displaying the handoff summary, verify that all referenced files in the Context Index actually exist on disk:

1. Read the plan file path from the handoff → verify it exists
2. Read the spec file path from the handoff → verify it exists
3. Read `status/claude-progress.json` → verify it exists

**If any file is missing:**

> "WARNING: Referenced files are missing:
> - \<missing file path\>
>
> The project may be in an inconsistent state.
>
> Options:
> 1. Continue anyway (may fail later)
> 2. Run `/super-harness:status` to see what's available
> 3. Start fresh with `/super-harness:brainstorm`"

Wait for user choice and act accordingly.

**If all files exist:** Proceed to Step 3.

### Step 3: Load Context from Index Pointers

Based on the context index in the handoff:

1. Read `status/claude-progress.json` — milestone state, current task
2. Read the plan file — full task list with completion status
3. Read the spec file — full specification for reference

Inject all relevant context into the Orchestrator's initial context.

### Step 4: Route Based on State

**If state is PLANNING:**
> "Plan was written in the previous session. Ready to start execution."
Route to `harness-execution` with the plan, **with `setup_required=true`** (must run Engine Pre-Configuration before any task).

**If state is IN_PROGRESS:**
> "Resuming from Task \<N\>. Ready to continue execution."
Route to `harness-execution` with the plan and current task context, **with `setup_required=true`** (must run Engine Pre-Configuration before any task).

**If state is MILESTONE_DONE:**
> "Milestone complete! Starting next milestone."
The next milestone's plan was already written during the planning session. Route directly to `harness-execution` with the next milestone's plan, **with `setup_required=true`** (must run Engine Pre-Configuration before any task).

**If state is ALL_DONE:**
> "All milestones are complete. Project is finished!
>
> Proceeding to `harness-finishing` to finalize the project."

Route to `harness-finishing`.

## Key Rules

- The handoff document is the SOLE source of truth for session state
- Always read the full plan file to know exact task completion status
- Always read the spec file for context on requirements
- Always display deferred items and key decisions from handoff
- The `/super-harness:resume` command is the only entry point — never skip it
