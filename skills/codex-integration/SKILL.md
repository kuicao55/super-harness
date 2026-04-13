---
name: codex-integration
description: "Orchestrator's Codex operations manual. Full command reference for codex-plugin-cc, availability detection, dispatch workflow, output parsing, and token cost guidance. Use when Orchestrator needs to operate Codex as Executor or Reviewer engine."
---

# Codex Integration — Orchestrator Operations Manual

Orchestrator can delegate tasks to Codex as an alternative engine for Executor and Reviewer roles. This manual covers everything needed to operate Codex correctly from within an Orchestrator session.

All commands are provided by the `codex-plugin-cc` plugin (v1.0.2+): [https://github.com/openai/codex-plugin-cc](https://github.com/openai/codex-plugin-cc)

**IMPORTANT:** Codex commands must be invoked via `codex-companion.mjs` using the Bash tool — NOT as slash commands. Slash commands only work in the main session; Orchestrator runs as a sub-agent where they are not intercepted.

**Companion script path:**
```
CLAUDE_PLUGIN_ROOT="${HOME}/.claude/plugins/marketplaces/openai-codex/plugins/codex"
node "${CLAUDE_PLUGIN_ROOT}/scripts/codex-companion.mjs" <command> [args]
```

---

## A. Availability Detection and Initialization

Before using any Codex engine, check availability:

```bash
Bash: node "${CLAUDE_PLUGIN_ROOT}/scripts/codex-companion.mjs" setup --json
```

- If Codex is ready → set `codex_available = true`
- If Codex is missing but npm is available → offer: "Codex is not installed. Run `npm install -g @openai/codex` to install it."
- If installed but not authenticated → prompt: "Please run `!codex login` to complete authentication"
- If unavailable for any reason → set `codex_available = false`. Orchestrator must **still** present each stage's Decision Point to the user; Codex options are omitted or marked unavailable, and the user confirms Claude subagent (or cancels). Do not silently skip asking.

Set `codex_available` once at session start. Do not re-check during the session unless explicitly needed.

### Review Gate (Advanced, Optional)

`codex-plugin-cc` supports an automatic Review Gate that runs Codex after every Claude response:

```bash
# Enable
Bash: node "${CLAUDE_PLUGIN_ROOT}/scripts/codex-companion.mjs" setup --enable-review-gate --json

# Disable
Bash: node "${CLAUDE_PLUGIN_ROOT}/scripts/codex-companion.mjs" setup --disable-review-gate --json
```

**Warning:** This creates a Claude/Codex loop that can rapidly consume usage limits.
**Recommendation:** Only enable when actively monitoring the session. Not recommended as a default.

---

## B. Full Command Reference

All commands use `codex-companion.mjs` via Bash. Companion script path:
```
CLAUDE_PLUGIN_ROOT="${HOME}/.claude/plugins/marketplaces/openai-codex/plugins/codex"
```

### Executor Engine Commands

#### `task` — Delegate implementation to Codex

```bash
# Basic usage (dispatch via Bash with run_in_background: true)
node "${CLAUDE_PLUGIN_ROOT}/scripts/codex-companion.mjs" task --background [prompt]

# With model selection
node "${CLAUDE_PLUGIN_ROOT}/scripts/codex-companion.mjs" task --background --model gpt-5.4-mini [prompt]
node "${CLAUDE_PLUGIN_ROOT}/scripts/codex-companion.mjs" task --background --model spark --effort medium [prompt]

# With effort level
node "${CLAUDE_PLUGIN_ROOT}/scripts/codex-companion.mjs" task --background --effort high [prompt]
node "${CLAUDE_PLUGIN_ROOT}/scripts/codex-companion.mjs" task --background --effort xhigh [prompt]

# Resume a previous task session (same repo)
node "${CLAUDE_PLUGIN_ROOT}/scripts/codex-companion.mjs" task --background --resume [prompt]

# Fresh start (ignore history)
node "${CLAUDE_PLUGIN_ROOT}/scripts/codex-companion.mjs" task --background --fresh [prompt]

# Wait for completion (short tasks only)
node "${CLAUDE_PLUGIN_ROOT}/scripts/codex-companion.mjs" task --wait [prompt]
```

**Parameters:**

| Parameter          | Values                    | Description                                                                    |
| ------------------ | ------------------------- | ------------------------------------------------------------------------------ |
| `--background`     | flag                      | Run without blocking Claude session. Recommended for all non-trivial tasks.    |
| `--wait`           | flag                      | Block until complete. Use only for very short tasks.                           |
| `--model <model>`  | `gpt-5.4-mini`, `spark`   | Model selection. `spark` maps to `gpt-5.3-codex-spark` (fastest, lowest cost). |
| `--effort <level>` | `minimal`, `low`, `medium`, `high`, `xhigh` | Reasoning intensity. Higher = better results, more tokens. |
| `--resume`         | flag                      | Continue previous task in same repo.                                           |
| `--fresh`          | flag                      | Ignore history, start entirely fresh.                                          |

---

### Reviewer Engine Commands

#### `review` — Standard spec compliance review (Stage 1 Reviewer)

```bash
# Basic review (all changes since last commit)
Bash: node "...codex-companion.mjs" review --background

# Compare against a specific branch (recommended when working in a worktree)
Bash: node "...codex-companion.mjs" review --background --base main

# Wait for result (smaller changesets)
Bash: node "...codex-companion.mjs" review --wait --base main
```

**Key characteristics:**

- Read-only — cannot modify code
- Not directable — does not accept focus text
- Best for: standard spec compliance checking

---

#### `adversarial-review` — Adversarial code quality review (Stage 2 Reviewer)

```bash
# Basic adversarial review
Bash: node "...codex-companion.mjs" adversarial-review --background

# With branch comparison
Bash: node "...codex-companion.mjs" adversarial-review --background --base main

# With focus text (directable)
Bash: node "...codex-companion.mjs" adversarial-review --background look for authentication bypass and injection vectors
Bash: node "...codex-companion.mjs" adversarial-review --background --base main challenge the caching design and look for race conditions
Bash: node "...codex-companion.mjs" adversarial-review --background focus on N+1 query patterns and unbounded memory growth
```

**Key characteristics:**

- Directable with focus text — append after all flags
- Higher token cost than standard review
- Best for: security-sensitive, performance-critical, or auth/payment code

---

### Task Management Commands

#### `status` — Check job status

```bash
Bash: node "...codex-companion.mjs" status [job-id] --json
```

Returns: job state (`running`, `completed`, `failed`), elapsed time, brief summary.

#### `result` — Retrieve job output

```bash
Bash: node "...codex-companion.mjs" result [job-id] --json
```

Returns: full output + `session-id` which can be used to continue in Codex app:
```
codex resume <session-id>
```

#### `cancel` — Cancel a running job

```bash
Bash: node "...codex-companion.mjs" cancel [job-id] --json
```

---

## C. Standard Orchestrator Workflow for Codex Operations

```
Phase 1: Dispatch (via Bash with run_in_background: true)
  → Bash: node "...codex-companion.mjs" <command> --background [args]
  → Note the job-id from the command response

Phase 2: Poll
  → Bash: node "...codex-companion.mjs" status <job-id> --json
  → Wait until state shows "completed" or "failed"

Phase 3: Retrieve
  → Bash: node "...codex-companion.mjs" result <job-id> --json
  → Save the session-id from the output for activity log

Phase 4: Parse
  → Map Codex output to standard Executor/Reviewer report format
  → See section D below

Phase 5: Continue
  → Proceed with workflow based on parsed verdict
  → If task needs continuation: task --background --resume

Phase 6: Cancel (if needed)
  → Bash: node "...codex-companion.mjs" cancel <job-id> --json
  → Then retry or fallback to Claude subagent
```

**Companion script path (use in all Bash calls):**
```
CLAUDE_PLUGIN_ROOT="${HOME}/.claude/plugins/marketplaces/openai-codex/plugins/codex"
```

**Polling Interval Guidance:**

| Task Type                     | Initial Poll | Max Wait |
| ----------------------------- | ------------ | -------- |
| `review` (small changeset)    | 30s          | 3 min    |
| `review` (large changeset)    | 60s          | 10 min   |
| `adversarial-review`          | 60s          | 10 min   |
| `task` (simple task)          | 60s          | 15 min   |
| `task` (complex task)         | 120s         | 30 min   |

If a task exceeds max wait: cancel and fall back to Claude subagent or escalate to user.

---

## D. Output Mapping to Standard Executor/Reviewer Formats

### Codex task → Executor Report

```
Codex task completed → map to Executor report:

Extract from Codex output:
  - Implementation description → "What I implemented"
  - Files modified → "Files changed"
  - Test results (if run) → "Test results"

Map status:
  - Success, all tests passing → Status: DONE
  - Success, but with caveats noted → Status: DONE_WITH_CONCERNS
  - Partial completion or errors → Status: BLOCKED
  - Could not start / environment error → Status: BLOCKED

Record in activity log:
  - executor_engine: "codex-task"
  - codex_session_id: <session-id from result output>
  - codex_model: <model used, if specified>
  - codex_effort: <effort level, if specified>
```

### Codex review → Spec Reviewer Report

```
Codex review completed → map to Spec Reviewer report:

Map verdict:
  SPEC_COMPLIANT when:
    - No missing requirements mentioned
    - No "expected to implement" or "should have" language about missing features
    - No unrequested scope creep flagged

  SPEC_ISSUES when:
    - Codex mentions missing requirements ("this doesn't handle X")
    - Codex flags extra features ("this adds Y which wasn't requested")
    - Codex notes implementation doesn't match stated intent

Record in activity log:
  - reviewer_engine: "codex-review"
  - codex_session_id: <session-id from result output>
```

### Codex adversarial-review → Code Quality Reviewer Report

```
Codex adversarial-review completed → map to Code Quality Reviewer report:

Map severity:
  Critical issues → block PASS (security vulnerabilities, broken core functionality)
  Important issues → block PASS (significant performance, test integrity, integration problems)
  Minor issues → do not block PASS (note for future improvement)

Map verdict:
  PASS when:
    - No Critical issues found
    - No Important issues found
    - Only Minor observations (acceptable)

  FAIL when:
    - Any Critical issue found
    - Any Important issue found

Record in activity log:
  - reviewer_engine: "codex-adversarial-review"
  - codex_session_id: <session-id from result output>
```

---

## E. Token Cost Reference

Display relevant rows at Decision Points to help user choose:

| Command                                             | Relative Cost | Best For                                        |
| --------------------------------------------------- | ------------- | ----------------------------------------------- |
| `task --model spark --effort medium`                | Lowest        | Simple/mechanical tasks (1-2 files, clear spec) |
| `review`                                            | Moderate      | Standard spec compliance check                  |
| `task` (default)                                    | Moderate-High | General implementation delegation                |
| `adversarial-review`                                | Higher        | Security/performance-sensitive code              |
| `task --model gpt-5.4-mini --effort xhigh`          | Highest       | Complex architecture or deeply stuck tasks       |

---

## F. Model Selection Guide

| Scenario                                           | Recommended                                                |
| -------------------------------------------------- | ---------------------------------------------------------- |
| Simple mechanical task (rename, format, small fix)  | `--model spark --effort medium`                            |
| Standard feature implementation                     | Omit `--model` (use Codex default)                         |
| Complex multi-file feature                         | `--model gpt-5.4-mini`                                     |
| Deeply stuck task needing reasoning                | `--model gpt-5.4-mini --effort xhigh`                      |
| Security-focused adversarial review                 | `--effort high` (or `--effort xhigh` for critical systems) |

---

## G. Decision Point Presentation Template

When Orchestrator presents a Codex Decision Point to the user, use this format:

```
[Decision Point: Executor / Spec Reviewer / Code Quality Reviewer]

Task N: <task name>. Choose engine:
1. Claude subagent (default) — [brief description of what this does]
2. Codex — [brief description] (token cost: <level>)
   [If applicable: suggested flags: --model X --effort Y]
3. [Additional options if applicable]

Enter choice (1-3, default: 1):
```

---

## H. Fallback Strategy

If Codex fails or produces unusable output:

1. Log the failure: note `codex_session_id` and error in activity log `notes`
2. Fallback to Claude subagent for the same role
3. Optionally: retry with `task --fresh --background` (ignore previous session state)
4. If Codex is consistently failing: set `codex_available = false` for the rest of the session and skip all Codex Decision Points

---

## Quick Reference Card

```
CHECK      Bash: node "...codex-companion.mjs" setup --json
EXECUTE    Bash: node "...codex-companion.mjs" task --background [--model X] [--effort Y] [prompt]
REVIEW     Bash: node "...codex-companion.mjs" review --background [--base <ref>]
ATTACK     Bash: node "...codex-companion.mjs" adversarial-review --background [--base <ref>] [focus text]
STATUS     Bash: node "...codex-companion.mjs" status [job-id] --json
RESULT     Bash: node "...codex-companion.mjs" result [job-id] --json
CANCEL     Bash: node "...codex-companion.mjs" cancel [job-id] --json
RESUME     codex resume <session-id>   (in Codex app, not in Claude)
```

**Companion script path prefix (use in all Bash calls):**
```
CLAUDE_PLUGIN_ROOT="${HOME}/.claude/plugins/marketplaces/openai-codex/plugins/codex"
```
