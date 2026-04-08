# Codex Call Templates

Use this file when Orchestrator chooses Codex as the engine for Executor or Reviewer roles.
All Codex commands are provided by the `codex-plugin-cc` plugin (`/codex:*`).

---

## Executor Engine: `/codex:rescue`

Use when Orchestrator selects Codex as the Executor for a task (instead of Claude subagent).
Also use when a Claude subagent Executor reports BLOCKED and the user chooses Codex rescue.

### Task Delegation Template

```
/codex:rescue <task description> --background

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
| Simple/mechanical task (1-2 files, clear spec) | `/codex:rescue <task> --model spark --effort medium --background`       |
| Standard implementation task                   | `/codex:rescue <task> --background`                                     |
| Complex/integration task                       | `/codex:rescue <task> --model gpt-5.4-mini --effort xhigh --background` |
| Continuing a stuck task                        | `/codex:rescue <task> --resume --background`                            |
| Fresh attempt (ignore history)                 | `/codex:rescue <task> --fresh --background`                             |

**Note:** `spark` maps to `gpt-5.3-codex-spark` (fastest, lowest cost). Omitting `--model` lets Codex choose its own defaults.

### Blocked Rescue Template

When Claude subagent Executor is BLOCKED, provide full context to Codex:

```
/codex:rescue --background

Task: [task name and full description]

What Claude attempted:
[Executor's blocked report — what was tried and why it failed]

Specific blocker:
[Precise description of what Claude couldn't resolve]

Context:
[Architecture, key files, relevant interfaces]

Working directory: [DIRECTORY]
```

---

## Reviewer Engine (Stage 1): `/codex:review`

**⚠️ CRITICAL: Do NOT use `Bash(codex ...)` to invoke these commands.**

`/codex:review` and `/codex:adversarial-review` are **slash commands** provided by the codex-plugin-cc plugin. They must be output as plain text for Claude Code to dispatch internally — NOT executed as bash commands. The Codex CLI does not have `adversarial-review` or `review` as subcommands.

Use when Orchestrator selects Codex as the Spec Reviewer (instead of Claude subagent).
This is a read-only standard review — cannot be directed with focus text.

### Standard Spec Review

```
/codex:review --background
```

For branch comparison (recommended when working in a worktree):

```
/codex:review --base main --background
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

## Reviewer Engine (Stage 2): `/codex:adversarial-review`

Use when Orchestrator selects Codex as the Code Quality Reviewer (instead of or alongside Claude subagent).
This review IS steerable — provide focus text for security-sensitive areas.

### Standard Adversarial Review

```
/codex:adversarial-review --background
```

For branch comparison:

```
/codex:adversarial-review --base main --background
```

### Targeted Adversarial Review (with focus text)

For security-sensitive code:

```
/codex:adversarial-review --background look for authentication bypass, injection vulnerabilities, and sensitive data exposure
```

For performance-sensitive code:

```
/codex:adversarial-review --background challenge the algorithmic complexity and look for database queries in loops
```

For concurrent systems:

```
/codex:adversarial-review --background look for race conditions, shared state issues, and question the chosen synchronization approach
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
2. Simultaneously run `/codex:adversarial-review --background [focus text]`
3. Collect Claude subagent verdict
4. Poll with `/codex:status` → get result with `/codex:result`
5. Merge findings:
   - If either returns FAIL → combined verdict is FAIL
   - Include all issues from both parties in the consolidated report
   - If both return PASS → task complete

---

## Task Management Commands

Orchestrator uses these to manage background Codex jobs:

```bash
# Check on a running job
/codex:status
/codex:status <task-id>

# Get the final output when done
/codex:result
/codex:result <task-id>

# Cancel a running job (if timed out or no longer needed)
/codex:cancel
/codex:cancel <task-id>

# Continue a Codex session in the Codex app
# (Use the session-id from /codex:result output)
codex resume <session-id>
```

### Polling Pattern for Background Tasks

```
1. Dispatch: /codex:rescue|review|adversarial-review [args] --background
2. Note the task-id from the response
3. Poll every 15-30 seconds: /codex:status <task-id>
4. When status shows complete: /codex:result <task-id>
5. Parse output and continue workflow
6. If task seems stuck after several minutes: /codex:cancel <task-id>, then retry or fallback to Claude subagent
```

---

## Token Cost Reference

Display to user at Decision Points:

| Command                                             | Cost           | When to Use                          |
| --------------------------------------------------- | -------------- | ------------------------------------ |
| `/codex:review`                                     | Moderate       | Standard spec compliance check       |
| `/codex:adversarial-review`                         | Higher         | Security/performance-sensitive code  |
| `/codex:rescue` (default)                           | Varies by task | General implementation delegation    |
| `/codex:rescue --model spark`                       | Lowest         | Simple/mechanical tasks              |
| `/codex:rescue --model gpt-5.4-mini --effort xhigh` | High           | Complex tasks needing deep reasoning |

---

## Activity Log Fields for Codex Usage

When a task uses Codex, record in the activity log:

```json
{
  "executor_engine": "codex-rescue",
  "reviewer_engine": "codex-adversarial-review",
  "codex_session_id": "<session-id from /codex:result>",
  "codex_model": "gpt-5.4-mini",
  "codex_effort": "high"
}
```

The `codex_session_id` allows resuming the Codex session later with `codex resume <session-id>`.
