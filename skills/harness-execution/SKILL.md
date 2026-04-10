---
name: harness-execution
description: "Execute implementation plans using the Orchestrator / Executor / Reviewer architecture. Orchestrator coordinates Executor (implementation) and two-stage Reviewer (Spec Review then Code Quality Review). Each role can use Claude subagent or Codex as the engine. Only Code Quality Review PASS closes a task."
---

# Harness Execution — Orchestrator Architecture

Execute a plan task by task. Orchestrator coordinates: Executor implements (TDD), Spec Reviewer verifies requirements, Code Quality Reviewer attacks the code adversarially. Each role can use Claude subagent or Codex engine. Only Code Quality Review PASS closes a task.

**Announce at start:** "I'm using the harness-execution skill with Orchestrator / Executor / Reviewer architecture."

## Setup — MUST complete BEFORE any task execution

<HARD-GATE>
The following Setup steps MUST be completed before dispatching any Executor. Do NOT skip to task execution without completing all required steps.

- **First execution (from `/super-harness:execute`):** Complete Step 1 → Step 2 → Step 3 → Step 4 in order.
- **Resume execution (from `/super-harness:resume`, `setup_required=true`):** Skip Step 1 (plan already loaded by resume flow), complete Step 2 → Step 3 → Step 4. Engine configuration is per-session — it MUST be re-collected after every `/clear`.
</HARD-GATE>

### Step 1: Load the Plan

Read the plan file. If not specified, ask: "Which plan file should I execute? (path to the `.md` file in `docs/harness/plans/`)"

Review critically — identify questions or concerns. If the plan has critical gaps, raise them with the user before starting.

### Step 1.x: Validate Plan File Exists

After reading the plan file:
1. Verify the plan file path exists on disk
2. If not found → error:
   > "Plan file not found: `<path>`
   > The plan may have been deleted or moved.
   > Options:
   > 1. Run `/super-harness:plan` to re-create the plan
   > 2. Check `/super-harness:status` to see current state"
3. Verify all referenced spec files in the plan exist
4. If spec missing → warn but allow proceed

### Step 2: Check Codex Availability

Run `/codex:setup` to check if Codex is installed and authenticated.

- If Codex is ready → set `codex_available = true`
- If Codex is missing but npm is available → inform user: "Codex is not installed. `/codex:setup` can install it. Would you like to install now?"
- If unavailable → set `codex_available = false`

### Step 3: Engine Pre-Configuration (Per-session — MUST re-collect after every /clear)

**Announce:** "Collecting engine preferences for this execution session..."

Collect these preferences ONCE before starting. These apply to all subsequent tasks.

```
Engine Configuration:

1. Executor 引擎：
   → 只能使用 Claude subagent（/codex:rescue 作为救援方案）
   [无需选择，直接继续]

2. Executor 失败超过 N 次后切换 /codex:rescue：
   → (1) 2 次  (2) 3 次  (3) 不切换（纯 Claude 模式）
   → 默认：(1)

3. Spec Review 引擎：
   → (1) Claude subagent  (2) Codex review
   → 默认：(2)

4. Code Quality Review 引擎：
   → (1) Claude subagent  (2) Codex adversarial-review
   → 默认：(2)

5. Codex 调用失败时：
   → (1) Auto-fallback to Claude  (2) 询问用户
   → 默认：(1)
```

**MUST confirm with user before proceeding.** Display the configuration above and ask: "Engine 配置确认？（直接 Enter 使用默认值，或输入数字修改）"

**When `codex_available = false`:** Q3 and Q4 must fall back to Claude subagent. Show user the modified defaults and confirm.

### Step 4: Create Task List

Create a TodoWrite entry for every task in the plan. **Create tasks ONE AT A TIME, sequentially, in plan order.** Do NOT create multiple tasks in a single parallel call — this causes TodoWrite ID misalignment with plan task numbers.

Mark the first task as `in_progress`.

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

## The Iron Law

```
NO TASK IS COMPLETE UNTIL CODE QUALITY REVIEW GIVES AN EXPLICIT PASS.
```

Executor self-review does not count. Spec Review alone does not count. Only the Code Quality Reviewer's explicit PASS closes a task.

**Separation mandate:** The Executor writes code. The Reviewers review it. These are never the same agent instance.

**Dispatch mandate (hard requirement):**

```
ORCHESTRATOR MUST NEVER IMPLEMENT OR REVIEW CODE DIRECTLY.
EXECUTOR AND REVIEWER WORK MUST ALWAYS BE DISPATCHED TO A SUBAGENT OR CODEX.
```

If Orchestrator edits code directly (instead of dispatching), that task run is invalid and must be re-run with proper dispatch.

<HARD-GATE>
Until Code Quality Review returns an explicit PASS for the current task, Orchestrator MUST NOT:

- Edit application/source code, tests, or config (no `Update`, `Write`, `StrReplace`, or equivalent on product files)
- Perform Spec Review or Code Quality Review inline (no "I'll review the code myself")
- Skip Executor/Reviewer dispatch because the project is "small" or "simple"
- Claim a task or milestone complete without both review stages and explicit verdicts

Orchestrator ONLY: load plan, dispatch Task/Subagent or Codex, merge results, update TodoWrite, update plan checkboxes after PASS, invoke activity-logging.

Violating this gate invalidates the run; stop and restart the task with proper dispatch.
</HARD-GATE>

---

## Per-Task Execution Flow

Repeat this flow for each task in the plan.

### ORCHESTRATOR SELF-CHECK (run before each Decision Point)

Before entering **Executor Decision Point**, **Spec Review Decision Point**, or **Code Quality Review Decision Point**, Orchestrator must run this self-check:

```
ORCHESTRATOR SELF-CHECK:

□ I am NOT writing or modifying application/source code, tests, or config files
□ I am NOT performing work that should be done by the Executor (implementation)
□ I am NOT reviewing code inline — all reviews are dispatched to Reviewer subagent or Codex
□ I am NOT skipping any Decision Point or retry limit
□ I have received all required reports for this stage (including TEST_OUTPUT for Executor DONE)

If ANY box is unchecked: STOP. Log the violation to activity log as PROCESS_VIOLATION.
Do not proceed. Correct the violation before continuing.
```

If self-check fails:
1. Report PROCESS_VIOLATION in activity log
2. Stop current task workflow
3. Correct the violation (e.g., re-dispatch via proper channel instead of doing inline)
4. Resume from the failed point

### Step 1: Executor Decision Point

**Using pre-configured engine:** Claude subagent (as configured in Step 3)

Dispatch using Task/Subagent tooling with `executor-prompt.md` template. Provide:
- Full task text (never make Executor read the plan file)
- Scene-setting context: prior tasks built, architecture decisions, key files
- Working directory

Handle Executor status:

| Status               | Action                                                                                            |
| -------------------- | ------------------------------------------------------------------------------------------------- |
| `DONE`               | Proceed to Decision Point 1.5: TDD Audit                                                         |
| `DONE_WITH_CONCERNS` | Read concerns. If they affect correctness or scope, address before proceeding. Otherwise proceed to Decision Point 1.5: TDD Audit |
| `NEEDS_CONTEXT`      | Provide missing information and re-dispatch Executor                                              |
| `BLOCKED`            | **Immediately** show /codex:rescue as Option 2 (no waiting for N failures)                     |

**BLOCKED: Always show rescue option (regardless of N setting):**

> "**Executor is blocked on Task N:** \<reason\>
>
> Options:
>
> 1. Retry with Claude subagent (provide more context)
> 2. Use `/codex:rescue` — **always available when BLOCKED**, no need to wait for N failures"
>
> - Option 1: gather context, re-dispatch Claude subagent
> - Option 2: output `/codex:rescue <task> --background [--model X] [--effort Y]` (do NOT use Bash(codex ...))

**N consecutive failures (non-BLOCKED):** After N consecutive `DONE_WITH_CONCERNS` or re-dispatch failures, prompt:
> "Task N has had N executor failures. Switch to `/codex:rescue` for a fresh perspective?"

### Decision Point 1.5: TDD Audit

**Announce:** "Running TDD Audit on Executor output before Spec Review."

This decision point is MANDATORY. It cannot be skipped even if the task is "simple" or the Executor is "trusted."

Orchestrator calls `harness:tdd-audit` with:
- Executor's full report (including TEST_OUTPUT)
- List of files created/modified

**Handling TDD Audit verdict:**

| TDD_AUDIT Result | Action |
| ---------------- | ------ |
| `PASS`           | Proceed to Step 2: Spec Review Decision Point |
| `FAIL`           | Report `Status: PROCESS_VIOLATION` to Executor. Return to Executor for re-implementation. Do not proceed to Spec Review. |
| `CANNOT_VERIFY`  | Treat as FAIL. Return to Executor for re-implementation with PROCESS_VIOLATION. |

**PROCESS_VIOLATION retry limit:** If the same task receives PROCESS_VIOLATION 2 times, escalate to user:

> "Task N has received PROCESS_VIOLATION 2 times (TDD discipline violations). Options:
>
> 1. Review the TDD violation details and retry with Executor
> 2. Simplify or re-scope this task
> 3. Skip and flag for later"

After escalation, invoke `activity-logging` with the PROCESS_VIOLATION count.

**If Codex rescue chosen:**

**IMPORTANT: Do NOT use `Bash(codex ...)`**. The `/codex:rescue` command is a **slash command** provided by the codex-plugin-cc plugin — it must be output as text for Claude Code to dispatch internally. Never invoke it as a bash command.

Format and send using `codex-review-prompt.md` rescue template. Then:

1. Output the slash command directly: `/codex:rescue <task description> --background [--model X] [--effort Y]`
2. Poll with `/codex:status` until complete
3. Retrieve with `/codex:result`
4. Map Codex output to Executor report format (see `codex-review-prompt.md`) and continue as dispatched Executor output
5. Proceed to Spec Review Decision Point

### Step 2: Spec Review Decision Point

**Using pre-configured engine from Q3:**
- Claude subagent → dispatch Task/Subagent with `spec-reviewer-prompt.md`
- Codex review → **output `/codex:review --background "<task description>"` as text directly in main session** (Claude Code dispatches it internally). Do NOT use `Bash(codex review ...)` CLI — the slash command handles async dispatch and polling internally.

Dispatch using Task/Subagent tooling and `spec-reviewer-prompt.md` template. Provide:

- Full task requirements text
- Executor's implementation report
- Working directory

Handle Spec Reviewer verdict:

| Verdict          | Action                                                               |
| ---------------- | -------------------------------------------------------------------- |
| `SPEC_COMPLIANT` | Proceed to Step 3: Code Quality Review Decision Point               |
| `SPEC_ISSUES`    | Return to Step 1 — dispatch Executor to fix, then re-run Spec Review |

**Spec Review re-try limit:** If Spec Review has failed 3 times, assess whether the reviewer clearly identified a root cause:

- **Root cause clear** (e.g., reviewer pinpointed the exact bug, missing condition, or logic error): Return to Step 1 — dispatch Executor to fix the specific issue, then re-run Spec Review. Do NOT ask the user.
- **Root cause unclear** (e.g., reviewer timed out, returned vague/inconsistent findings, or same issue persists after 3 distinct fixes): escalate to user:

> "Task N has failed Spec Review 3 times. Issues: \<summary\>. Options:
>
> 1. Switch to other engine and retry
> 2. Simplify task scope with user guidance
> 3. Skip and flag for later"

### Step 3: Code Quality Review Decision Point

**Using pre-configured engine from Q4:**
- Claude subagent → dispatch Task/Subagent with `code-quality-reviewer-prompt.md`
- Codex adversarial-review → **output `/codex:adversarial-review --background "<task description>"` as text directly in main session**. Do NOT use `Bash(codex adversarial-review ...)` CLI — `adversarial-review` has no CLI equivalent, only the slash command works.

Dispatch using Task/Subagent tooling and `code-quality-reviewer-prompt.md` template. Provide:

- Full task requirements text
- Executor's implementation report
- Working directory

Handle verdict:

| Verdict | Action                                                                      |
| ------- | --------------------------------------------------------------------------- |
| `PASS`  | Task complete — proceed to Post-Task                                        |
| `FAIL`  | Return to Step 1 — dispatch Executor to fix, then re-run both review stages |

**Codex note:** The slash commands `/codex:review` and `/codex:adversarial-review` handle async dispatch and polling internally when output as text in the main session. Do NOT attempt to replicate this via Bash CLI calls.

**Q5 Fallback (Codex failure):**
- If Q5 = Auto-fallback: automatically use Claude subagent without prompting
- If Q5 = Ask: prompt user "Codex failed. Retry with Claude subagent?"

### Dispatch Validation Checklist (Run per task)

Before marking a task complete, Orchestrator must verify:

- Executor was dispatched (Claude subagent Task OR Codex rescue), not run inline
- Spec Reviewer was dispatched (Claude subagent Task OR Codex review), not run inline
- Code Quality Reviewer was dispatched (Claude subagent Task/Codex/both), not run inline

If any stage was done inline by Orchestrator, mark task invalid and re-run that stage via proper dispatch.

### User-visible Progress Requirement

If only plan checkboxes are being updated and TodoWrite is not visible/updating, treat it as a process failure and correct immediately:

1. Rebuild TodoWrite from current plan status
2. Mark current task/sub-step as `in_progress`
3. Continue execution with live TodoWrite updates

**Code Quality Review re-try limit:** If Code Quality Review has failed 3 times, assess whether the reviewer clearly identified a root cause:

- **Root cause clear** (e.g., reviewer pinpointed the exact security issue, performance bug, or edge case failure): Return to Step 1 — dispatch Executor to fix the specific issue, then re-run both review stages. Do NOT ask the user.
- **Root cause unclear** (e.g., reviewer timed out, returned vague/inconsistent findings, or same issue persists after 3 distinct fixes): escalate to user:

> "Task N has failed Code Quality Review 3 times. Issues: \<summary\>. Options:
>
> 1. Switch to other engine and retry
> 2. Simplify task scope with user guidance
> 3. Skip and flag for later"

Update activity log with failure count and final decision regardless of outcome.

### Post-Task: Log and Update Progress

After Code Quality Review PASS:

1. **Invoke `activity-logging`** — record task completion with:
   - `executor_engine`: `claude-subagent` or `codex-rescue`
   - `reviewer_engine`: `claude-subagent`, `codex-review`/`codex-adversarial-review`
   - `codex_session_id`: session-id from `/codex:result` (if Codex was used)
2. **Update plan file** — mark task checkbox: `- [ ]` → `- [x]`
3. **Update handoff document** — use the `harness-handoff` script:
   ```bash
   scripts/harness-handoff IN_PROGRESS \
     --task-id <next-task-id> \
     --tasks-completed <comma-separated> \
     --deferred "<any deferred items>" \
     --decisions "<any key decisions>" \
     --next-action "/super-harness:resume"
   ```
4. **Check if milestone is complete** — if ALL tasks in current milestone are `- [x]`:
   - Invoke `harness-handoff` with state=`MILESTONE_DONE` + /clear
   - Session ends. User runs `/super-harness:resume` to start next milestone.
   - Do NOT continue to next task in the same session.
5. If milestone is NOT complete:
   - Announce: "Task N complete. Moving to Task N+1."
   - Mark current task `completed` and next task `in_progress` in TodoWrite

### Per-Step Todo Updates (Superpowers-style behavior)

Within each task, Orchestrator must also maintain sub-step progress in TodoWrite so the user sees continuous progress, not just plan checkbox edits.

Recommended sub-steps per task:

1. `Task N — Executor dispatched`
2. `Task N — TDD Audit`
3. `Task N — Spec Review`
4. `Task N — Code Quality Review`
5. `Task N — Post-task logging and plan update`

As each sub-step starts/completes:

- Update TodoWrite immediately
- Keep exactly one `in_progress` sub-step
- Close sub-steps in order

---

## After All Tasks Complete

1. **Run full project test suite:**

   > "Running full test suite to verify all tasks integrate correctly..."

   If tests fail: stop and debug using `harness-debugging` before claiming completion.
   Apply `harness-verification` before marking work done.

2. **Invoke `harness-handoff`** with state=`ALL_DONE` — this writes the handoff document and creates/updates PROJECT.md. It does NOT /clear for ALL_DONE.

3. **Invoke `harness-finishing`** — in the SAME session (no /clear between handoff and finishing). Finishing handles:
   - Verifies tests pass
   - Presents 4 options: merge locally / push + PR / keep / discard
   - Handles worktree cleanup

4. Announce summary:
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

- Starting implementation on `main`/`master` without explicit user consent (use `harness-worktrees`)
- Proceeding to next task while Code Quality Review has open issues
- Trusting Executor self-review instead of running both Reviewers
- Letting Executor write production code before a failing test exists
- Skipping activity logging after task completion
- Marking a milestone passed without all tasks being Code Quality Review approved
- Using the same agent instance for Executor and any Reviewer role
- Orchestrator directly editing code or directly performing review work

---

## Integration

**Skills used by this skill:**

- `activity-logging` — mandatory after every task
- `progress-management` — to mark milestones passed
- `harness-handoff` — session boundary handoff (on milestone complete, all done, or context threshold)
- `harness-debugging` — when full test suite fails after all tasks complete
- `harness-verification` — before marking work complete
- `harness-finishing` — after all tasks complete, to handle branch and worktree
- Subagent templates: `executor-prompt.md`, `spec-reviewer-prompt.md`, `code-quality-reviewer-prompt.md`
- Codex templates: `codex-review-prompt.md`
