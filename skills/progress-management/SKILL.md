---
name: progress-management
description: "Cross-session project progress tracking for super-harness. Manages claude-progress.json: creating, reading, updating milestones, and marking them passed. Only used for large multi-session projects."
---

# Progress Management

Manages `status/claude-progress.json` — the cross-session milestone tracker for large projects.

**Announce at start:** "I'm using the progress-management skill."

## When This Skill Is Used

This skill is invoked by other harness skills whenever they need to read or write `claude-progress.json`. It is a cross-cutting concern, not a standalone workflow.

Do NOT use this skill for small projects. Small projects (single session, <10 tasks) have no progress file.

---

## Schema Reference

The full schema for `status/claude-progress.json`:

```json
{
  "project": "string — project name",
  "created_at": "ISO-8601 timestamp",
  "updated_at": "ISO-8601 timestamp",
  "spec_file": "path to design spec — docs/harness/specs/...",
  "milestones": [
    {
      "id": "milestone-N",
      "title": "Short title for this milestone",
      "description": "What this milestone delivers — 1-2 sentences",
      "depends_on": ["milestone-id", "..."],
      "passed": false,
      "plan_file": null,
      "session_date": null,
      "notes": null
    }
  ]
}
```

**Field rules:**

- `milestones` is an ordered array. Order matters: milestones are worked in sequence unless `depends_on` indicates otherwise.
- `passed` is the only completion flag. `true` = this milestone's session plan is fully executed and Evaluator-approved.
- `plan_file` is `null` until a session begins work on that milestone and creates its plan.
- `session_date` is the date the session plan was created (format: `YYYY-MM-DD`).
- `notes` is free text for context about what happened in this milestone's session.

---

## Operations

### CREATE — Initialize a new progress file

Called by: `harness-plan-writing` when starting a new large project.

1. Ensure the `status/` directory exists: `mkdir -p status`
2. Write `status/claude-progress.json` with the milestone list
3. Set all milestones to `passed: false`, `plan_file: null`, `session_date: null`, `notes: null`
4. Commit: `git add status/claude-progress.json && git commit -m "harness: initialize project progress tracking"`

### READ — Load current state

Called by: `harness-entry` (resume), `harness-plan-writing` (find next milestone).

1. Read `status/claude-progress.json`
2. Return:
   - List of all milestones with their status
   - First milestone where `passed: false` (the "current" milestone)
   - Dependency warnings if current milestone has unmet `depends_on`

### UPDATE — Link a plan file to a milestone

Called by: `harness-plan-writing` after creating a session plan.

1. Find the milestone by `id`
2. Update its `plan_file` and `session_date` fields
3. Update `updated_at` timestamp
4. Write the updated file
5. Commit: `git add status/claude-progress.json && git commit -m "harness: link plan for milestone-N"`

### MARK PASSED — Complete a milestone

Called by: `harness-execution` when all tasks in a milestone's plan are Evaluator-approved.

1. Find the milestone by `id`
2. Set `passed: true`
3. Update `notes` with a brief summary: "Completed <YYYY-MM-DD>. <N> tasks, all Evaluator-approved."
4. Update `updated_at` timestamp
5. Write the updated file
6. Commit: `git add status/claude-progress.json && git commit -m "harness: milestone-N passed"`
7. Display:
   > "✅ Milestone N marked as passed: **<title>**
   >
   > Progress: X/N milestones complete.
   > Next milestone: **<next title>** — <description>"

---

## Dependency Validation

When reading the current milestone, check its `depends_on` list:

```
For each dep in current_milestone.depends_on:
  dep_milestone = find milestone by id
  if dep_milestone.passed == false:
    warn user: "⚠️ Milestone N depends on [dep_title] which is not yet passed."
```

This is a warning, not a blocker. The user may choose to proceed anyway (e.g., working in parallel branches).

---

## File Location

The progress file always lives at `status/claude-progress.json` relative to the **project root** (the current working directory when the harness commands are invoked).

This file belongs in the user's project repository. It should be committed to git so it persists across machines and sessions. Do NOT put it in the plugin directory.

---

## Example: Full Progress File

```json
{
  "project": "my-task-manager",
  "created_at": "2026-04-01T09:00:00Z",
  "updated_at": "2026-04-03T14:30:00Z",
  "spec_file": "docs/harness/specs/2026-04-01-task-manager-design.md",
  "milestones": [
    {
      "id": "milestone-1",
      "title": "Auth and user model",
      "description": "JWT authentication, user CRUD, role-based access control",
      "depends_on": [],
      "passed": true,
      "plan_file": "docs/harness/plans/2026-04-01-milestone-1.md",
      "session_date": "2026-04-01",
      "notes": "Completed 2026-04-01. 8 tasks, all Evaluator-approved. Minor: password complexity validation deferred."
    },
    {
      "id": "milestone-2",
      "title": "Task CRUD API",
      "description": "REST endpoints for creating, reading, updating, deleting tasks with assignment and status transitions",
      "depends_on": ["milestone-1"],
      "passed": false,
      "plan_file": "docs/harness/plans/2026-04-02-milestone-2.md",
      "session_date": "2026-04-02",
      "notes": "In progress. 4/7 tasks complete."
    },
    {
      "id": "milestone-3",
      "title": "Frontend dashboard",
      "description": "React dashboard with task list, filters, drag-and-drop priority, real-time updates via WebSocket",
      "depends_on": ["milestone-2"],
      "passed": false,
      "plan_file": null,
      "session_date": null,
      "notes": null
    }
  ]
}
```
