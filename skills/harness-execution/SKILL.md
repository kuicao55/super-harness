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

- **First execution (from `/super-harness:execute`):** Complete Step 0 → Step 1 → Step 2 → Step 3 → Step 4 in order.
- **Resume execution (from `/super-harness:resume`, `setup_required=true`):** Complete Step 0 (change to worktree), then Step 2 → Step 3 → Step 4. Engine configuration is per-session — it MUST be re-collected after every `/clear`.
</HARD-GATE>

### Step 0: Worktree Setup

**Announce:** "Setting up worktree for isolated development..."

This step establishes a **version branch** and a **per-milestone worktree** for isolated development. The model is:

```
main ──→ <version-branch> (accumulates all milestones, human reviews this branch)
              │
              ├── worktree: milestone-3 → merge back, delete worktree
              ├── worktree: milestone-4 → merge back, delete worktree
              └── ...
```

#### Step 0a: Version Branch Setup

Check current branch:
```bash
git branch --show-current
```

**If on `main`/`master`:**
1. Determine the version branch name. Check `status/claude-progress.json` for a saved `version_branch`:
   ```bash
   python3 -c "import json; d=json.load(open('status/claude-progress.json')); print(d.get('version_branch', ''))"
   ```
2. If `version_branch` exists → checkout that branch
3. If no `version_branch` → ask the user:
   > "You're on `main`. What version branch should I create for this project's work?
   > Example: `v3.0.0`"
4. Create and checkout the version branch:
   ```bash
   git checkout -b <version-branch>
   ```
5. Save version branch to progress.json (add a `version_branch` key)

**If already on a non-main branch:**
> "Already on version branch `<branch-name>`. Continuing."
- Save branch as `version_branch` in progress.json if not already saved

#### Step 0b: Per-Milestone Worktree Setup

Each milestone gets its own worktree. After a milestone completes, the worktree is merged back into the version branch and deleted.

Read `status/claude-progress.json` to check for an existing worktree for the current milestone:

```bash
python3 -c "import json; d=json.load(open('status/claude-progress.json')); wt=d.get('worktree'); print(wt['path'] + '|' + wt['branch'] if wt else '')"
```

**If `worktree` field exists in progress.json AND the worktree directory exists:**
> "Resuming in existing worktree at `<path>` (branch: `<branch>`)"
1. `cd` into the worktree path
2. Verify: `git worktree list` shows the worktree
3. Verify: `git branch --show-current` matches the saved branch
4. Proceed to Step 1 (or Step 2 for resume)

**If `worktree` field does NOT exist or the directory is gone (new milestone):**
1. Update version branch with any changes: `git status` — ensure clean
2. Create a per-milestone worktree:
   ```bash
   # Determine worktree path and branch name
   # Branch: harness/<milestone-id>-<short-description>
   # Path: read from harness.config.json worktrees_dir, or default to "worktrees"
   WORKTREES_DIR=$(python3 -c "import json; d=json.load(open('harness.config.json')); print(d.get('worktrees_dir', 'worktrees'))" 2>/dev/null || echo "worktrees")
   MILESTONE_ID=$(python3 -c "import json; d=json.load(open('status/claude-progress.json')); ms=[m for m in d['milestones'] if not m.get('passed')]; print(ms[0]['id'] if ms else 'unknown')")
   MILESTONE_TITLE=$(python3 -c "import json; d=json.load(open('status/claude-progress.json')); ms=[m for m in d['milestones'] if not m.get('passed')]; print(ms[0]['title'].split()[0].lower() if ms else 'work')")

   BRANCH_NAME="harness/${MILESTONE_ID}-${MILESTONE_TITLE}"
   WORKTREE_PATH="${WORKTREES_DIR}/${MILESTONE_ID}"

   git worktree add "${WORKTREE_PATH}" -b "${BRANCH_NAME}"
   ```
3. Run baseline tests in the worktree:
   ```bash
   cd "${WORKTREE_PATH}" && <run test suite>
   ```
4. Save worktree info to progress.json:
   ```bash
   harness-milestone set-worktree "${WORKTREE_PATH}" "${BRANCH_NAME}"
   ```
5. `cd` into the worktree path
6. Proceed to Step 1

**Note:** Each milestone creates its own worktree based on the current version branch (which already contains previous milestones' merged work). When a milestone completes, its worktree is merged back and cleaned up (see Post-Milestone Cleanup below).

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

Run Codex availability check:

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/codex-companion.mjs" setup --json
```

- If Codex is ready → set `codex_available = true`
- If Codex is missing but npm is available → inform user: "Codex is not installed. Run `npm install -g @openai/codex` to install it."
- If unavailable → set `codex_available = false`

### Step 3: Engine Pre-Configuration (Per-session — MUST re-collect after every /clear)

**Announce:** "Collecting engine preferences for this execution session..."

Ask the user one question to collect all engine preferences at once:

```
Ask the user:
"本次执行使用哪种引擎配置？"

Options:
1. **Claude 模式** — 纯 Claude，无 Codex
   - Executor rescue: 不切换（纯 Claude）
   - Spec Review: Claude subagent
   - Code Quality Review: Claude subagent
   - Codex fallback: auto

2. **Codex 模式** — Codex 负责所有 review 阶段
   - Executor rescue: 2 次失败后切换
   - Spec Review: Codex review
   - Code Quality Review: Codex adversarial-review
   - Codex fallback: auto

3. **均衡模式** — Claude 做 Spec Review，Codex 做 Code Quality Review
   - Executor rescue: 2 次失败后切换
   - Spec Review: Claude subagent
   - Code Quality Review: Codex adversarial-review
   - Codex fallback: auto

Multi-select: false
```

Wait for the user's selection before proceeding.

**When `codex_available = false`:** If the user selected Codex模式 or 均衡模式, automatically substitute Claude subagent for the unavailable Codex engines and inform the user.

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

### Engine Dispatch Rule — HARD-GATE

The dispatch mechanism depends on the engine selected in Step 3:

**Claude engines (Claude subagent):**
→ Use `Agent` tool (Task/Subagent) with the corresponding prompt template

**Codex engines (Codex review, Codex adversarial-review, Codex rescue):**
→ Use `Bash` tool to call `codex-companion.mjs` directly. The companion script is the actual implementation behind slash commands and works from sub-agent contexts.
→ Codex availability detection sets `CLAUDE_PLUGIN_ROOT`. If not set, use:
  `CLAUDE_PLUGIN_ROOT="${HOME}/.claude/plugins/marketplaces/openai-codex/plugins/codex"`
→ Examples:
  - Spec Review (Codex): `Bash(node "${CLAUDE_PLUGIN_ROOT}/scripts/codex-companion.mjs" review --background --base main)`
  - Code Quality Review (Codex): `Bash(node "${CLAUDE_PLUGIN_ROOT}/scripts/codex-companion.mjs" adversarial-review --background --base main [focus text])`
  - Executor rescue (Codex): `Bash(node "${CLAUDE_PLUGIN_ROOT}/scripts/codex-companion.mjs" task --background [--model X] [--effort Y] [prompt])`

→ After dispatch:
   1. Note the **Claude Code task ID** from the Bash response (e.g., `btxsezqf1`)
   2. Poll using `TaskOutput` tool: `TaskOutput(task_id: "<task-id>", block: false)` — repeat until status is "completed"
   3. When complete, the `output` field contains the full Codex result (including session-id for logging)

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

Use `Agent` tool with `executor-prompt.md`. Provide:
- Full task text (never make Executor read the plan file)
- Scene-setting context: prior tasks built, architecture decisions, key files
- Working directory

Handle Executor status:

| Status               | Action                                                                                            |
| -------------------- | ------------------------------------------------------------------------------------------------- |
| `DONE`               | Proceed to Decision Point 1.5: TDD Audit                                                         |
| `DONE_WITH_CONCERNS` | Read concerns. If they affect correctness or scope, address before proceeding. Otherwise proceed to Decision Point 1.5: TDD Audit |
| `NEEDS_CONTEXT`      | Provide missing information and re-dispatch Executor                                              |
| `BLOCKED`            | **Immediately** show Codex rescue as Option 2 (no waiting for N failures)                     |

**BLOCKED: Always show rescue option (regardless of N setting):**

> "**Executor is blocked on Task N:** \<reason\>
>
> Options:
>
> 1. Retry with Claude subagent (provide more context)
> 2. Use Codex rescue — **always available when BLOCKED**, no need to wait for N failures"
>
> - Option 1: gather context, re-dispatch Claude subagent
> - Option 2: dispatch Codex rescue via Bash

**N consecutive failures (non-BLOCKED):** After N consecutive `DONE_WITH_CONCERNS` or re-dispatch failures, prompt:
> "Task N has had N executor failures. Switch to Codex rescue for a fresh perspective?"

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

Dispatch using `codex-companion.mjs` via Bash. Set `CLAUDE_PLUGIN_ROOT` if not available:

```
Bash:
command: node "${CLAUDE_PLUGIN_ROOT:-${HOME}/.claude/plugins/marketplaces/openai-codex/plugins/codex}/scripts/codex-companion.mjs" task --background [--model X] [--effort Y] [prompt]
run_in_background: true
```

1. Note the `job-id` returned in the command output
2. Poll: `Bash(node "...codex-companion.mjs" status [job-id] --json)` — wait for `"state": "completed"`
3. Retrieve: `Bash(node "...codex-companion.mjs" result [job-id] --json)`
4. Map Codex output to Executor report format (see `codex-review-prompt.md`) and continue as dispatched Executor output
5. Proceed to Spec Review Decision Point

### Step 2: Spec Review Decision Point

**Using pre-configured Spec Review engine:**
- Claude subagent → use `Agent` tool with `spec-reviewer-prompt.md`
- Codex review:
  1. Dispatch: `Bash(node "...codex-companion.mjs" review --background --base main)` with `run_in_background: true`
  2. Note the Claude Code task ID from the response
  3. Poll: `TaskOutput(task_id: "<task-id>", block: true, timeout: 300000)` — wait for completion
  4. Parse the `output` field for verdict (look for "Reviewer finished" = SPEC_COMPLIANT, or issues found = SPEC_ISSUES)

Provide to the dispatched reviewer:

- Full task requirements text
- Executor's implementation report
- Working directory

Handle Spec Reviewer verdict:

| Verdict          | Action                                                               |
| ---------------- | -------------------------------------------------------------------- |
| `SPEC_COMPLIANT` | Proceed to Step 3: Code Quality Review Decision Point               |
| `SPEC_ISSUES`    | Return to Step 1 — use `Agent` tool to re-dispatch Executor, then re-run Spec Review |

**Spec Review re-try limit:** If Spec Review has failed 3 times, assess whether the reviewer clearly identified a root cause:

- **Root cause clear** (e.g., reviewer pinpointed the exact bug, missing condition, or logic error): Return to Step 1 — use `Agent` tool to re-dispatch Executor, then re-run Spec Review. Do NOT ask the user.
- **Root cause unclear** (e.g., reviewer timed out, returned vague/inconsistent findings, or same issue persists after 3 distinct fixes): escalate to user:

> "Task N has failed Spec Review 3 times. Issues: \<summary\>. Options:
>
> 1. Switch to other engine and retry
> 2. Simplify task scope with user guidance
> 3. Skip and flag for later"

### Step 3: Code Quality Review Decision Point

**Using pre-configured Code Quality Review engine:**
- Claude subagent → use `Agent` tool with `code-quality-reviewer-prompt.md`
- Codex adversarial-review:
  1. Dispatch: `Bash(node "...codex-companion.mjs" adversarial-review --background --base main [focus text])` with `run_in_background: true`
  2. Note the Claude Code task ID from the response
  3. Poll: `TaskOutput(task_id: "<task-id>", block: true, timeout: 300000)` — wait for completion
  4. Parse the `output` field for verdict (look for Critical/Important issues = FAIL, only Minor = PASS)

Provide to the dispatched reviewer:

- Full task requirements text
- Executor's implementation report
- Working directory

Handle verdict:

| Verdict | Action                                                                      |
| ------- | --------------------------------------------------------------------------- |
| `PASS`  | Task complete — proceed to Post-Task                                        |
| `FAIL`  | Return to Step 1 — use `Agent` tool to re-dispatch Executor, then re-run both review stages |

**Codex fallback (Codex failure):**
- Auto-fallback: automatically use Claude subagent without prompting
- Ask: prompt user "Codex failed. Retry with Claude subagent?"

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

- **Root cause clear** (e.g., reviewer pinpointed the exact security issue, performance bug, or edge case failure): Return to Step 1 — use `Agent` tool to re-dispatch Executor, then re-run both review stages. Do NOT ask the user.
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
   - `codex_session_id`: session-id from Codex companion result output (if Codex was used)
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
   - **Post-Milestone Cleanup:** Merge the milestone worktree back into the version branch and clean up:
     1. Return to the main checkout (not the worktree):
        ```bash
        cd <project-root>
        ```
     2. Ensure we're on the version branch:
        ```bash
        git checkout <version-branch>
        ```
     3. Merge the milestone branch (fast-forward preferred):
        ```bash
        git merge --ff-only <milestone-branch>
        ```
        If fast-forward not possible, use `--no-edit`:
        ```bash
        git merge <milestone-branch> --no-edit
        ```
     4. Remove the worktree:
        ```bash
        git worktree remove <worktree-path>
        ```
     5. Optionally delete the milestone branch (it's been merged):
        ```bash
        git branch -d <milestone-branch>
        ```
     6. Clear the worktree field in progress.json:
        ```bash
        harness-milestone clear-worktree
        ```
     7. Mark milestone as complete:
        ```bash
        harness-milestone complete <milestone-id>
        ```
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

- Starting implementation on `main`/`master` without going through Step 0 worktree setup
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
