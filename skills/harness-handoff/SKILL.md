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

**Use the `harness-handoff` script.** Do NOT manually write the handoff file.

The script reads structured fields (spec, plan, milestone) from `status/claude-progress.json` automatically. You only need to provide the state and free-text content.

**Single file:** The handoff document is always `docs/harness/handoffs/handoff.md` — overwritten each time. No timestamped filenames.

```bash
scripts/harness-handoff <state> \
  --task-id <id> \
  --tasks-completed <comma-separated-list> \
  --deferred "<deferred items text>" \
  --decisions "<key decisions text>" \
  --next-action "<command>"
```

**Examples:**

```bash
# After plan confirmed
scripts/harness-handoff PLANNING \
  --next-action "/super-harness:execute --plan docs/harness/plans/2026-04-09-milestone-1.md"

# Mid-execution
scripts/harness-handoff IN_PROGRESS \
  --task-id task-3 \
  --tasks-completed task-1,task-2 \
  --deferred "None" \
  --decisions "Switched to Codex review engine after Task 2" \
  --next-action "/super-harness:resume"

# Milestone complete
scripts/harness-handoff MILESTONE_DONE \
  --tasks-completed task-1,task-2,task-3,task-4,task-5,task-6 \
  --decisions "Canvas rendering with chain-following algorithm" \
  --next-action "/super-harness:plan (next milestone)"

# All done
scripts/harness-handoff ALL_DONE \
  --tasks-completed task-1,task-2,task-3,task-4,task-5,task-6 \
  --decisions "Single HTML file, no external dependencies" \
  --next-action "Project complete — open index.html in browser"
```

**What the script does automatically:**
- Reads `status/claude-progress.json` for spec_file, plan_file, milestone_id
- Checks if `status/PROJECT.md` exists → includes in Context Index if so
- Writes `docs/harness/handoffs/handoff.md`
- Updates `current_session_handoff` in `claude-progress.json`
- On `MILESTONE_DONE`: runs `harness-milestone complete <milestone-id>`
- On `ALL_DONE`: completes any remaining uncompleted milestones
- Git commits the changes

**Key principle:** The handoff is an envelope, not the source of truth. It references `claude-progress.json` and plan files — it does not duplicate their content.

### Step 3b: Create or Update PROJECT.md (on MILESTONE_DONE or ALL_DONE)

If state is `MILESTONE_DONE` or `ALL_DONE`, update `status/PROJECT.md` to record new project knowledge. Note: single-milestone projects skip MILESTONE_DONE and go directly to ALL_DONE, so both states must trigger this step.

**Detect project name:**
1. Try `git remote -v` — extract project name from remote URL
2. Fall back to `basename "$(pwd)"` — use directory name

**Extract milestone knowledge:**
- From the spec file (read `docs/harness/specs/<spec-name>.md`): extract tech stack, architecture, functional modules
- From the plan file (read `docs/harness/plans/<plan-name>.md`): extract task list and what each task implements
- From completed tasks in `claude-progress.json`: infer which modules/files were created

---

**If PROJECT.md does NOT exist (new project):**

Generate a complete PROJECT.md from scratch:

```markdown
# Project Context

> Auto-generated by super-harness. Read this first in every session.

## Project Identity

**Project Name:** <name>
**Harness Version:** 3.4.0
**Generated:** <YYYY-MM-DD>
**Last Updated:** <YYYY-MM-DD>

## Tech Stack

<from spec: languages, frameworks, test framework, package manager>

## Functional Modules

| Module | Purpose | Source Location |
|--------|---------|----------------|
| <name> | <1-line purpose> | <path> |
| ... | ... | ... |

## Key Architectural Decisions

- <from spec: architecture section>

## Project Structure

```
<top-level tree of project>
```

## Harness Reference

**Commands:** `/super-harness:brainstorm`, `/super-harness:plan`, `/super-harness:execute`, `/super-harness:resume`, `/super-harness:init`, `/super-harness:status`, `/super-harness:handoff`

**Key Files:**
- `status/claude-progress.json` — Milestone tracker
- `status/PROJECT.md` — This file
- `docs/harness/specs/` — Design specs
- `docs/harness/plans/` — Implementation plans
- `docs/harness/handoffs/` — Session handoffs
- `logs/activity-YYYY-MM-DD.jsonl` — Activity logs
```

---

**If PROJECT.md EXISTS:**

1. Read existing `status/PROJECT.md`
2. Extract new functional modules introduced by this milestone (from spec/plan — modules not already in PROJECT.md)
3. Append new modules to Functional Modules table (do not delete existing)
4. Update `Last Updated` field to today's date
5. Write updated PROJECT.md

---

**After both paths:**

Commit: `git add status/PROJECT.md && git commit -m "harness: update project context after milestone-N"`

**Note:** This grows the project knowledge base over time. Existing entries are preserved.

## Step 4: Confirm with User

Show the handoff document summary and ask:

**If state is PLANNING, IN_PROGRESS, or MILESTONE_DONE:**

> "Handoff prepared:
> - State: **\<state\>**
> - Milestone: **\<id\>**
> - Next action: **\<command\>**
>
> Clear session context? Your next session can resume with `/super-harness:resume`."

- **yes** → proceed to Step 5
- **no** → abort. Do not write the handoff document. Continue the session.

**If state is ALL_DONE:**

> "All milestones complete! Handoff document prepared.
> - State: **ALL_DONE**
>
> Proceeding to harness-finishing in this session (no context reset needed)."

Do NOT /clear. Proceed directly to `harness-finishing` after writing the handoff document.

## Step 5: Reset Context

Only executed when state is PLANNING, IN_PROGRESS, or MILESTONE_DONE and user confirmed.

1. Announce: "Clearing session context for fresh resume..."
2. Execute `/clear` via Claude Code's built-in command
3. The next session's `/super-harness:resume` will find the handoff document

## Key Constraints

- **Read-only except for handoff and progress file:** Never modifies spec, plan, or code files
- **Minimal:** Handoff only contains pointers and state — actual content lives in the source files
- **User confirms:** Never auto-resets without explicit user confirmation
- **Single handoff file:** Always `docs/harness/handoffs/handoff.md`, overwritten each time
- **Script-managed:** Always use `scripts/harness-handoff` to write — never manually edit the handoff file

## Integration

Referenced by:
- `harness-entry/SKILL.md` — `/super-harness:handoff` route
- `harness-plan-writing/SKILL.md` — after plan confirmation
- `harness-execution/SKILL.md` — after task transitions and milestone completion
