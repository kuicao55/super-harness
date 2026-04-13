# Codex Call Templates

Use this file when Orchestrator chooses Codex as the engine for Executor or Reviewer roles.
All Codex commands are invoked via `codex-companion.mjs` using the Bash tool.

**Companion script path:**
```
CLAUDE_PLUGIN_ROOT="${HOME}/.claude/plugins/marketplaces/openai-codex/plugins/codex"
node "${CLAUDE_PLUGIN_ROOT}/scripts/codex-companion.mjs" <command> [args]
```

---

## Executor Engine: Codex task

Use when Orchestrator selects Codex as the Executor for a task (instead of Claude subagent).
Also use when a Claude subagent Executor reports BLOCKED and the user chooses Codex rescue.

### Dispatch Template

```bash
Bash:
  command: node "${CLAUDE_PLUGIN_ROOT}/scripts/codex-companion.mjs" task --background [--model spark|gpt-5.4-mini] [--effort minimal|low|medium|high|xhigh] [prompt]
  run_in_background: true
```

After dispatch:
1. Note the **Claude Code task ID** from the Bash response (e.g., `btxsezqf1`)
2. Poll: `TaskOutput(task_id: "<task-id>", block: true, timeout: 300000)` — wait for completion
3. When complete, the `output` field contains the full Codex result
4. Extract the session-id from the output (format: `Thread ready (XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX)`) for activity logging
5. Map output to Executor report format

### Task Delegation Template

When dispatching, include in the prompt:

```
Task to implement:
[FULL TEXT of the task from the plan]

Context:
[Scene-setting: what has been built so far, architecture decisions, key files]

Working directory: [DIRECTORY]

Requirements:
- Implement with TDD (failing test first, minimal code, verify pass)
- Follow YAGNI — build only what the task specifies
- Match the conventions of the existing codebase
- Report: what was built, files changed, test results
```

### Model / Effort Guidance

| Scenario                                       | Recommended Command                                                     |
| ---------------------------------------------- | ----------------------------------------------------------------------- |
| Simple/mechanical task (1-2 files, clear spec) | `task --model spark --effort medium --background`                       |
| Standard implementation task                   | `task --background`                                                     |
| Complex/integration task                       | `task --model gpt-5.4-mini --effort xhigh --background`                 |
| Continuing a stuck task                        | `task --background --resume`                                            |
| Fresh attempt (ignore history)                | `task --background --fresh`                                             |

**Note:** `spark` maps to `gpt-5.3-codex-spark` (fastest, lowest cost). Omitting `--model` lets Codex choose its own defaults.

### Blocked Rescue Template

When Claude subagent Executor is BLOCKED, dispatch with full context:

```bash
Bash:
  command: node "${CLAUDE_PLUGIN_ROOT}/scripts/codex-companion.mjs" task --background [blocked task description + context]
  run_in_background: true
```

---

## Reviewer Engine (Stage 1): Codex review

Use when Orchestrator selects Codex as the Spec Reviewer (instead of Claude subagent).
This is a read-only standard review — cannot be directed with focus text.

### Dispatch Template

```bash
Bash:
  command: node "${CLAUDE_PLUGIN_ROOT}/scripts/codex-companion.mjs" review --background --base main
  run_in_background: true
```

For working-tree review (no base branch):
```bash
Bash:
  command: node "${CLAUDE_PLUGIN_ROOT}/scripts/codex-companion.mjs" review --background
  run_in_background: true
```

### Polling and Retrieval

After dispatch, note the Claude Code task ID from the Bash response, then:
```bash
# Poll — wait for completion
TaskOutput(task_id: "<task-id>", block: true, timeout: 300000)

# The output field contains the full Codex result, including:
# - "Reviewer finished" → SPEC_COMPLIANT
# - Issues found → SPEC_ISSUES
# - Session-id: extract from "Thread ready (SESSION-ID)"
```

### Interpreting Codex Review Output → Spec Reviewer Report

Map Codex output to the standard Spec Review verdict:

```
Codex review output → SPEC_COMPLIANT when:
  - No missing features mentioned
  - No "should have" or "expected to" language about missing items
  - No unrequested features flagged as out of scope

Codex review output → SPEC_ISSUES when:
  - Codex mentions missing requirements ("this doesn't handle X from the spec")
  - Codex flags extra features ("this adds Y which wasn't requested")
  - Codex notes the implementation doesn't match the described intent
```

---

## Reviewer Engine (Stage 2): Codex adversarial-review

Use when Orchestrator selects Codex as the Code Quality Reviewer (instead of or alongside Claude subagent).
This review IS steerable — provide focus text for security-sensitive areas.

### Dispatch Template

```bash
Bash:
  command: node "${CLAUDE_PLUGIN_ROOT}/scripts/codex-companion.mjs" adversarial-review --background --base main [focus text]
  run_in_background: true
```

### Polling

After dispatch, note the Claude Code task ID from the Bash response, then:
```bash
# Poll — wait for completion
TaskOutput(task_id: "<task-id>", block: true, timeout: 300000)

# The output field contains the full Codex result, including:
# - "[P1]", "[P2]" etc in output → map to Critical/Important/Minor
# - "Reviewer finished" → review complete, check for issues
# - Session-id: extract from "Thread ready (SESSION-ID)"
```

### Targeted Focus Examples

For security-sensitive code:
```
adversarial-review --background --base main look for authentication bypass, injection vulnerabilities, and sensitive data exposure
```

For performance-sensitive code:
```
adversarial-review --background --base main challenge the algorithmic complexity and look for database queries in loops
```

For concurrent systems:
```
adversarial-review --background --base main look for race conditions, shared state issues, and question the chosen synchronization approach
```

### Interpreting Codex Adversarial Review Output → Code Quality Reviewer Report

```
Codex adversarial-review output → PASS when:
  - No Critical or Important issues found
  - Only Minor observations (do not block PASS)

Codex adversarial-review output → FAIL when:
  - Any Critical issue found (security vulnerability, broken functionality)
  - Any Important issue found (significant performance, test quality, integration problem)

Severity mapping:
  Critical → block PASS immediately
  Important → block PASS (fix before task complete)
  Minor → note for later, does not block PASS
```

---

## Dual Review: Claude subagent + Codex (Maximum Quality)

When Orchestrator selects "both" for Code Quality Review:

1. Dispatch Claude subagent with `code-quality-reviewer-prompt.md` (runs immediately)
2. Simultaneously run Codex adversarial-review via Bash with `run_in_background: true`
3. Note the Claude Code task ID
4. Collect Claude subagent verdict
5. Poll Codex: `TaskOutput(task_id: "<task-id>", block: true, timeout: 300000)`
6. Merge findings:
   - If either returns FAIL → combined verdict is FAIL
   - Include all issues from both parties in the consolidated report
   - If both return PASS → task complete

---

## Task Management

**For polling, always use `TaskOutput` tool** — NOT `codex-companion.mjs status`:

```bash
# Non-blocking check
TaskOutput(task_id: "<Claude Code task ID>", block: false)

# Blocking wait for completion
TaskOutput(task_id: "<Claude Code task ID>", block: true, timeout: 300000)

# When status is "completed", the output field contains the full Codex result
```

**Companion script commands** (use for setup and cancellation):

```bash
# Check Codex availability
node "...codex-companion.mjs" setup --json

# Cancel a stuck task (uses Codex session ID, not Claude Code task ID)
node "...codex-companion.mjs" cancel [session-id] --json

# List Codex jobs (uses Codex session IDs)
node "...codex-companion.mjs" status --all --json
```

**Important:** `status`, `result`, and `cancel` commands use Codex session IDs (e.g., `019d7fe5-9c56-74f1-9cb7-3b69510f2ae8` from "Thread ready (SESSION-ID)"), NOT Claude Code task IDs. For polling, always use `TaskOutput` tool with the Claude Code task ID.

---

## Token Cost Reference

| Command                                             | Cost           | When to Use                          |
| --------------------------------------------------- | -------------- | ------------------------------------ |
| `review`                                            | Moderate       | Standard spec compliance check       |
| `adversarial-review`                                | Higher         | Security/performance-sensitive code  |
| `task` (default)                                    | Varies by task | General implementation delegation    |
| `task --model spark`                                | Lowest         | Simple/mechanical tasks              |
| `task --model gpt-5.4-mini --effort xhigh`          | High           | Complex tasks needing deep reasoning |

---

## Activity Log Fields for Codex Usage

When a task uses Codex, record in the activity log:

```json
{
  "executor_engine": "codex-task",
  "reviewer_engine": "codex-adversarial-review",
  "codex_session_id": "<session-id from output (Thread ready SESSION-ID)>",
  "codex_model": "gpt-5.4-mini",
  "codex_effort": "high"
}
```

The `codex_session_id` allows resuming the Codex session later with `codex resume <session-id>`.
