---
name: activity-logging
description: "Mandatory post-task activity logging for super-harness. Prevents session memory loss by recording every completed task to a JSONL log file. Must be invoked after every task completion."
---

# Activity Logging

Record every completed task to a structured JSONL log. This prevents "memory loss" across sessions — when `/super-harness:resume` is invoked in a new session, the log provides precise context about what happened before.

**Announce at start:** "I'm using the activity-logging skill to record this task."

## The Iron Law

```
LOG EVERY TASK AFTER CODE QUALITY REVIEW PASS. NO EXCEPTIONS.
```

Skipping a log entry means a future session cannot reconstruct what happened. The activity log is the harness's long-term memory.

---

## When to Invoke This Skill

Invoke immediately after every task that receives a Code Quality Review PASS verdict. Also invoke for:

- Brainstorming session completion (phase: `brainstorming`)
- Plan-writing session completion (phase: `planning`)
- A task marked as BLOCKED (to record the blockage)
- Code Quality Review escalation after 3 failures (to record the escalation decision)

---

## Log File Location and Format

**File:** `logs/activity-YYYY-MM-DD.jsonl` (one file per calendar day, in the project repo)

**Format:** JSONL — one JSON object per line, newline-delimited. Append only.

**Directory:** Ensure `logs/` exists: `mkdir -p logs`

---

## Session ID Generation

Before writing the first entry of a session, generate the `session_id`:

1. Check if `logs/activity-YYYY-MM-DD.jsonl` exists for today
2. If the file EXISTS:
   - Read all existing lines and extract the `session_id` field from each
   - Find the highest `NNN` suffix (e.g. `session-2026-04-07-003` → NNN = 3)
   - New session_id = `session-YYYY-MM-DD-{NNN+1:03d}` (e.g. `session-2026-04-07-004`)
3. If the file does NOT exist:
   - New session_id = `session-YYYY-MM-DD-001`
4. Reuse the same `session_id` for all entries within a single Claude session

---

## Log Entry Schema

Each entry is a single JSON object on one line:

```json
{
  "timestamp": "2026-04-02T14:32:15Z",
  "session_id": "session-2026-04-02-001",
  "milestone_id": "milestone-2",
  "task_id": "task-3",
  "task_title": "Implement task assignment endpoint",
  "phase": "execution",
  "action": "Implemented POST /tasks/:id/assign with auth check and validation",
  "executor_status": "DONE",
  "spec_review_status": "SPEC_COMPLIANT",
  "code_quality_status": "PASS",
  "executor_engine": "claude-subagent",
  "reviewer_engine": "claude-subagent",
  "codex_session_id": null,
  "codex_model": null,
  "codex_effort": null,
  "files_changed": ["src/routes/tasks.py", "tests/routes/test_tasks.py"],
  "notes": "Code Quality Reviewer flagged missing rate limiting — added as Minor, deferred to later milestone"
}
```

**Field definitions:**

| Field                 | Type           | Description                                                                                                          |
| --------------------- | -------------- | -------------------------------------------------------------------------------------------------------------------- |
| `timestamp`           | ISO 8601       | When the log entry was written                                                                                       |
| `session_id`          | string         | `"session-YYYY-MM-DD-NNN"` — see Session ID Generation above                                                         |
| `milestone_id`        | string or null | The milestone ID from `claude-progress.json`, or `null` for small projects                                           |
| `task_id`             | string         | `"task-N"` matching the task number in the plan                                                                      |
| `task_title`          | string         | Short description of the task                                                                                        |
| `phase`               | enum           | `"brainstorming"` \| `"planning"` \| `"execution"`                                                                   |
| `action`              | string         | 1-2 sentences describing what was actually done                                                                      |
| `executor_status`     | enum           | `"DONE"` \| `"DONE_WITH_CONCERNS"` \| `"BLOCKED"` \| `"SKIPPED"`                                                     |
| `spec_review_status`  | enum           | `"SPEC_COMPLIANT"` \| `"SPEC_ISSUES_THEN_COMPLIANT"` \| `"SKIPPED"`                                                  |
| `code_quality_status` | enum           | `"PASS"` \| `"FAIL_THEN_PASS"` \| `"SKIPPED"` \| `"BLOCKED"`                                                         |
| `executor_engine`     | enum           | `"claude-subagent"` \| `"codex-rescue"` — which engine ran the Executor                                              |
| `reviewer_engine`     | enum           | `"claude-subagent"` \| `"codex-review"` \| `"codex-adversarial-review"` \| `"both"` — which engine ran the Reviewers |
| `codex_session_id`    | string or null | Session ID from `/codex:result` — allows `codex resume <id>` later                                                   |
| `codex_model`         | string or null | Codex model used (e.g. `"gpt-5.4-mini"`, `"spark"`)                                                                  |
| `codex_effort`        | string or null | Codex effort level used (e.g. `"medium"`, `"high"`, `"xhigh"`)                                                       |
| `files_changed`       | array          | List of file paths modified by this task                                                                             |
| `notes`               | string or null | Important context for next session — Reviewer concerns, deferred items, blocking issues                              |

**`code_quality_status` values explained:**

- `PASS` — passed on first Code Quality Review
- `FAIL_THEN_PASS` — failed at least once, then passed after Executor re-implementation
- `SKIPPED` — phase was `brainstorming` or `planning`
- `BLOCKED` — task could not be completed

---

## How to Write a Log Entry

1. Gather the information from the current execution context
2. Generate or reuse the `session_id` (see Session ID Generation)
3. Construct the JSON object (single line, no pretty printing)
4. **Append** to `logs/activity-YYYY-MM-DD.jsonl` using `echo ... >>`:

```bash
echo '{"timestamp":"...","session_id":"...","milestone_id":"...","task_id":"...","task_title":"...","phase":"execution","action":"...","executor_status":"DONE","spec_review_status":"SPEC_COMPLIANT","code_quality_status":"PASS","executor_engine":"claude-subagent","reviewer_engine":"claude-subagent","codex_session_id":null,"codex_model":null,"codex_effort":null,"files_changed":["..."],"notes":null}' >> logs/activity-2026-04-07.jsonl
```

**⚠️ CRITICAL: Do NOT use the `Write` tool on the log file.** The `Write` tool overwrites the entire file, destroying all previous entries. Always use bash `echo ... >>` to append a single new line.

5. Commit: `git add logs/ && git commit -m "harness: log task-N completion"`

---

## How Resume Uses the Log

When `/super-harness:resume` is invoked and a plan file is found but partially executed, the activity log supplements the plan's checkboxes with richer context. The `harness-entry` skill reads the log to:

- Understand which tasks had re-iterations (and why)
- Surface any `notes` about deferred items or concerns
- Confirm the session context before continuing

When displaying the resume summary, the entry skill shows recent log entries:

```
Recent activity (from logs/activity-2026-04-07.jsonl):
  14:32 — task-3 PASS (DONE → SPEC_COMPLIANT → PASS) [engine: claude-subagent / claude-subagent]
  14:55 — task-4 PASS (DONE → SPEC_COMPLIANT → FAIL_THEN_PASS — Reviewer found null check missing at line 42) [engine: claude-subagent / codex-adversarial-review]
  15:20 — task-5 BLOCKED — Codex rescue invoked, session: session-abc123
```

---

## Brainstorming and Planning Log Entries

For non-execution phases, use simplified entries:

```json
{
  "timestamp": "2026-04-01T10:15:00Z",
  "session_id": "session-2026-04-01-001",
  "milestone_id": null,
  "task_id": "brainstorm-session",
  "task_title": "Project brainstorming session",
  "phase": "brainstorming",
  "action": "Completed brainstorming for task-manager project. Spec saved to docs/harness/specs/2026-04-01-task-manager-design.md",
  "executor_status": "SKIPPED",
  "spec_review_status": "SKIPPED",
  "code_quality_status": "SKIPPED",
  "executor_engine": null,
  "reviewer_engine": null,
  "codex_session_id": null,
  "codex_model": null,
  "codex_effort": null,
  "files_changed": ["docs/harness/specs/2026-04-01-task-manager-design.md"],
  "notes": "User prefers REST over GraphQL. Authentication deferred to milestone-1."
}
```
