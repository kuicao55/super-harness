---
name: harness-execution
description: "Execute implementation plans using the Orchestra / Executor / Reviewer architecture. Orchestra coordinates Executor (implementation) and two-stage Reviewer (Spec Review then Code Quality Review). Each role can use Claude subagent or Codex as the engine. Only Code Quality Review PASS closes a task."
---

# Harness Execution — Orchestra Architecture

Execute a plan task by task. Orchestra coordinates: Executor implements (TDD), Spec Reviewer verifies requirements, Code Quality Reviewer attacks the code adversarially. Each role can use Claude subagent or Codex engine. Only Code Quality Review PASS closes a task.

**Announce at start:** "I'm using the harness-execution skill with Orchestra / Executor / Reviewer architecture."

<HARD-GATE>
Until Code Quality Review returns an explicit PASS for the current task, Orchestra MUST NOT:

- Edit application/source code, tests, or config (no `Update`, `Write`, `StrReplace`, or equivalent on product files)
- Perform Spec Review or Code Quality Review inline (no "I'll review the code myself")
- Skip Executor/Reviewer dispatch because the project is "small" or "simple"
- Claim a task or milestone complete without both review stages and explicit verdicts

Orchestra ONLY: load plan, ask user for engine choice each stage, dispatch Task/Subagent or Codex, merge results, update TodoWrite, update plan checkboxes after PASS, invoke activity-logging.

Violating this gate invalidates the run; stop and restart the task with proper dispatch.
</HARD-GATE>

## The Iron Law

```
NO TASK IS COMPLETE UNTIL CODE QUALITY REVIEW GIVES AN EXPLICIT PASS.
```

Executor self-review does not count. Spec Review alone does not count. Only the Code Quality Reviewer's explicit PASS closes a task.

**Separation mandate:** The Executor writes code. The Reviewers review it. These are never the same agent instance.

**Dispatch mandate (hard requirement):**

```
ORCHESTRA MUST NEVER IMPLEMENT OR REVIEW CODE DIRECTLY.
EXECUTOR AND REVIEWER WORK MUST ALWAYS BE DISPATCHED TO A SUBAGENT OR CODEX.
```

If Orchestra edits code directly (instead of dispatching), that task run is invalid and must be re-run with proper dispatch.

---

## Setup

### Step 1: Load the Plan

Read the plan file. If not specified, ask: "Which plan file should I execute? (path to the `.md` file in `docs/harness/plans/`)"

Review critically — identify questions or concerns. If the plan has critical gaps, raise them with the user before starting.

### Step 2: Check Codex Availability

Run `/codex:setup` to check if Codex is installed and authenticated.

- If Codex is ready → set `codex_available = true`
- If Codex is missing but npm is available → inform user: "Codex is not installed. `/codex:setup` can install it. Would you like to install now?"
- If unavailable → set `codex_available = false`

**When `codex_available = false`:** Do NOT silently skip user interaction. At each Decision Point (Executor, Spec Review, Code Quality Review), still ask the user explicitly, for example:

> "Codex is not available for this session. For this stage, proceed with **Claude subagent only**? (yes/no)"

If the user says no, pause and resolve (install Codex, or abort the stage). Never infer "no Codex → skip asking" or "small project → run inline."

**Project size:** Few tasks or a single session does **not** relax O/E/R. Every plan task still runs Executor → Spec Review → Code Quality Review with dispatch and user engine confirmation per stage.

### Step 3: Engine Confirmation Policy (Mandatory)

For every task stage (Executor, Spec Review, Code Quality Review), Orchestra MUST explicitly ask the user whether to use Codex or Claude subagent. No silent defaults.

You may remember the user's previous preference, but still ask for confirmation:

> "Last stage used <engine>. Keep this choice for this stage? (yes/no)"

### Step 4: Create Task List

Create a TodoWrite entry for every task in the plan. Mark the first task as `in_progress`.

**TodoWrite mandate (hard requirement):**

```
ORCHESTRA MUST MAINTAIN A LIVE TODO LIST DURING EXECUTION.
```

At all times:

- Exactly one task is `in_progress`
- Completed tasks are immediately marked `completed`
- Blocked/deferred tasks are marked `pending` (or `cancelled` if explicitly dropped)
- The visible todo list is the source of truth for in-session progress

---

## Per-Task Execution Flow

Repeat this flow for each task in the plan:

### Step 1: Executor Decision Point

Present to user (mandatory, no skip).

**When `codex_available = true`:**

> "**Task N: \<task name\>**
>
> Choose Executor engine:
>
> 1. Claude subagent — dispatches fresh subagent with TDD discipline
> 2. Codex rescue — `/codex:rescue` with optional `--model`/`--effort`
>    (best for: previous BLOCKED, need faster/cheaper, late-session context degradation)"

**When `codex_available = false`:** Codex is not offered, but you MUST still ask:

> "**Task N: \<task name\>** — Codex is unavailable. Proceed with **Claude subagent** Executor only? (yes/no)"

**If Claude subagent chosen (or user confirms subagent-only):**

Dispatch using Task/Subagent tooling with `executor-prompt.md` template. Provide:

- Full task text (never make Executor read the plan file)
- Scene-setting context: prior tasks built, architecture decisions, key files
- Working directory

Handle Executor status:

| Status               | Action                                                                                            |
| -------------------- | ------------------------------------------------------------------------------------------------- |
| `DONE`               | Proceed to Spec Review Decision Point                                                             |
| `DONE_WITH_CONCERNS` | Read concerns. If they affect correctness or scope, address before proceeding. Otherwise proceed. |
| `NEEDS_CONTEXT`      | Provide missing information and re-dispatch Executor                                              |
| `BLOCKED`            | Go to Codex Rescue Decision Point (if `codex_available`) or escalate to user                      |

**If Codex rescue chosen:**

Format and send using `codex-review-prompt.md` rescue template. Then:

1. Execute `/codex:rescue <task description> --background [--model X] [--effort Y]`
2. Poll with `/codex:status` until complete
3. Retrieve with `/codex:result`
4. Map Codex output to Executor report format (see `codex-review-prompt.md`) and continue as dispatched Executor output
5. Proceed to Spec Review Decision Point

### Codex Rescue Decision Point (Claude Executor BLOCKED)

Only shown when `codex_available = true` and Claude subagent Executor reports BLOCKED:

> "**Executor is blocked on Task N:** \<reason\>
>
> Options:
>
> 1. Provide more context and retry with Claude subagent
> 2. Use `/codex:rescue` to delegate to Codex
>    - Default model: `--background`
>    - Faster/cheaper: `--model spark --effort medium --background`
>    - Deeper reasoning: `--model gpt-5.4-mini --effort xhigh --background`
> 3. Skip this task and flag as BLOCKED (not recommended)"

- Option 1: gather context, re-dispatch Claude subagent Executor
- Option 2: execute rescue using `codex-review-prompt.md` blocked rescue template, treat result as Executor output
- Option 3: log task as BLOCKED in activity log, continue to next task

### Step 2: Spec Review Decision Point

Present to user after Executor completes (mandatory, no skip).

**When `codex_available = true`:**

> "**Executor completed Task N.** Choose Spec Reviewer engine:
>
> 1. Claude subagent — fresh subagent verifies spec compliance
> 2. Codex review — `/codex:review` (standard read-only, not directable)
>    Token cost: moderate
> 3. Skip Spec Review (not recommended)"

**When `codex_available = false`:** Still ask; do not default to inline review:

> "**Executor completed Task N.** Codex is unavailable. Proceed with **Claude subagent** Spec Review only? (yes/no)"

**If Claude subagent chosen:**

Dispatch using Task/Subagent tooling and `spec-reviewer-prompt.md` template. Provide:

- Full task requirements text
- Executor's implementation report
- Working directory

Handle Spec Reviewer verdict:

| Verdict          | Action                                                               |
| ---------------- | -------------------------------------------------------------------- |
| `SPEC_COMPLIANT` | Proceed to Code Quality Review Decision Point                        |
| `SPEC_ISSUES`    | Return to Step 1 — dispatch Executor to fix, then re-run Spec Review |

**If Codex review chosen:**

1. Execute `/codex:review --background` (or `--base main --background` if in worktree)
2. Poll with `/codex:status` → retrieve with `/codex:result`
3. Map output to SPEC_COMPLIANT / SPEC_ISSUES (see `codex-review-prompt.md`)
4. Continue accordingly

**Spec Review re-try limit:** If Spec Review has failed 3 times, escalate to user:

> "Task N has failed Spec Review 3 times. Issues: \<summary\>. Options:
>
> 1. Switch to other engine and retry
> 2. Simplify task scope with user guidance
> 3. Skip and flag for later"

### Step 3: Code Quality Review Decision Point

Present to user after Spec Review passes (mandatory, no skip).

**When `codex_available = true`:**

> "**Spec Review passed. Task N ready for Code Quality Review.** Choose engine:
>
> 1. Claude subagent — adversarial attack on security, performance, tests
> 2. Codex adversarial — `/codex:adversarial-review` (directable, higher token cost)
>    Good for: security-sensitive code, auth, payments, data access
> 3. Both — Claude subagent + Codex dual review (maximum quality)"

**When `codex_available = false`:** Still ask:

> "**Spec Review passed. Task N ready for Code Quality Review.** Codex is unavailable. Proceed with **Claude subagent** Code Quality Review only? (yes/no)"

**If Claude subagent chosen:**

Dispatch using Task/Subagent tooling and `code-quality-reviewer-prompt.md` template. Provide:

- Full task requirements text
- Executor's implementation report
- Working directory

Handle verdict:

| Verdict | Action                                                                      |
| ------- | --------------------------------------------------------------------------- |
| `PASS`  | Task complete — proceed to Post-Task                                        |
| `FAIL`  | Return to Step 1 — dispatch Executor to fix, then re-run both review stages |

**If Codex adversarial-review chosen:**

1. Execute `/codex:adversarial-review --background [focus text if applicable]`
2. Poll with `/codex:status` → retrieve with `/codex:result`
3. Map output to PASS / FAIL (see `codex-review-prompt.md`)
4. Continue accordingly

**If both chosen:**

1. Dispatch Claude subagent with `code-quality-reviewer-prompt.md` simultaneously
2. Execute `/codex:adversarial-review --background`
3. Collect both results
4. If either returns FAIL → combined verdict is FAIL
5. Merge all findings into consolidated report
6. Both PASS → proceed to Post-Task

### Dispatch Validation Checklist (Run per task)

Before marking a task complete, Orchestra must verify:

- Executor was dispatched (Claude subagent Task OR Codex rescue), not run inline
- Spec Reviewer was dispatched (Claude subagent Task OR Codex review), not run inline
- Code Quality Reviewer was dispatched (Claude subagent Task/Codex/both), not run inline

If any stage was done inline by Orchestra, mark task invalid and re-run that stage via proper dispatch.

### User-visible Progress Requirement

If only plan checkboxes are being updated and TodoWrite is not visible/updating, treat it as a process failure and correct immediately:

1. Rebuild TodoWrite from current plan status
2. Mark current task/sub-step as `in_progress`
3. Continue execution with live TodoWrite updates

**Code Quality Review re-try limit:** If Code Quality Review has failed 3 times, escalate to user:

> "Task N has failed Code Quality Review 3 times. Issues: \<summary\>. Options:
>
> 1. Switch to other engine and retry
> 2. Simplify task scope with user guidance
> 3. Skip and flag for later"

Update activity log with failure count and final decision regardless of outcome.

### Post-Task: Log and Update Progress

After Code Quality Review PASS:

1. **Invoke `harness:activity-logging`** — record task completion with:
   - `executor_engine`: `claude-subagent` or `codex-rescue`
   - `reviewer_engine`: `claude-subagent`, `codex-review`/`codex-adversarial-review`, or `both`
   - `codex_session_id`: session-id from `/codex:result` (if Codex was used)
2. **Update plan file** — mark task checkbox: `- [ ]` → `- [x]`
3. **If large project** — check if ALL tasks in current milestone are `- [x]`:
   - If yes: prompt user "All tasks in this milestone are complete and Code Quality Review approved. Mark milestone **\<title\>** as passed? (yes/no)"
   - If confirmed: invoke `harness:progress-management` to set `passed: true`
4. Announce: "Task N complete. Moving to Task N+1."
5. Mark current task `completed` and next task `in_progress` in TodoWrite

### Per-Step Todo Updates (Superpowers-style behavior)

Within each task, Orchestra must also maintain sub-step progress in TodoWrite so the user sees continuous progress, not just plan checkbox edits.

Recommended sub-steps per task:

1. `Task N — Executor dispatched`
2. `Task N — Spec Review`
3. `Task N — Code Quality Review`
4. `Task N — Post-task logging and plan update`

As each sub-step starts/completes:

- Update TodoWrite immediately
- Keep exactly one `in_progress` sub-step
- Close sub-steps in order

---

## After All Tasks Complete

1. **Run full project test suite:**

   > "Running full test suite to verify all tasks integrate correctly..."

   If tests fail: stop and debug using `harness:harness-debugging` before claiming completion.
   Apply `harness:harness-verification` before marking work done.

2. **Invoke `harness:harness-finishing`** — guides branch completion:
   - Verifies tests pass
   - Presents 4 options: merge locally / push + PR / keep / discard
   - Handles worktree cleanup

3. Announce summary:
   > "All N tasks complete and Code Quality Review approved.
   >
   > - Tasks completed: N
   > - Executor engines used: Claude subagent (X tasks), Codex rescue (Y tasks)
   > - Spec Review iterations: X total
   > - Code Quality Review iterations: X total (Y re-implementations required)
   > - Codex session IDs: [list if any, for Codex app resume]"

---

## Model Selection Strategy

| Task Type                          | Claude subagent | Codex                                 |
| ---------------------------------- | --------------- | ------------------------------------- |
| Mechanical (1-2 files, clear spec) | fast model      | `--model spark --effort medium`       |
| Standard integration               | standard model  | default                               |
| Architecture/review                | capable model   | `--model gpt-5.4-mini --effort xhigh` |

---

## Red Flags — STOP

- Starting implementation on `main`/`master` without explicit user consent (use `harness:harness-worktrees`)
- Proceeding to next task while Code Quality Review has open issues
- Trusting Executor self-review instead of running both Reviewers
- Letting Executor write production code before a failing test exists
- Skipping activity logging after task completion
- Marking a milestone passed without all tasks being Code Quality Review approved
- Using the same agent instance for Executor and any Reviewer role
- Orchestra directly editing code or directly performing review work

---

## Integration

**Skills used by this skill:**

- `harness:activity-logging` — mandatory after every task
- `harness:progress-management` — to mark milestones passed
- `harness:harness-debugging` — when full test suite fails after all tasks complete
- `harness:harness-verification` — before marking work complete
- `harness:harness-finishing` — after all tasks complete, to handle branch and worktree
- Subagent templates: `executor-prompt.md`, `spec-reviewer-prompt.md`, `code-quality-reviewer-prompt.md`
- Codex templates: `codex-review-prompt.md`
