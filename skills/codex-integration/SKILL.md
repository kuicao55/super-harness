---
name: codex-integration
description: "Orchestra's Codex operations manual. Full command reference for codex-plugin-cc, availability detection, dispatch workflow, output parsing, and token cost guidance. Use when Orchestra needs to operate Codex as Executor or Reviewer engine."
---

# Codex Integration — Orchestra Operations Manual

Orchestra can delegate tasks to Codex as an alternative engine for Executor and Reviewer roles. This manual covers everything needed to operate Codex correctly from within an Orchestra session.

All commands are provided by the `codex-plugin-cc` plugin (v1.0.2+): [https://github.com/openai/codex-plugin-cc](https://github.com/openai/codex-plugin-cc)

---

## A. Availability Detection and Initialization

Before using any Codex engine, check availability:

```
1. Execute /codex:setup
2. If setup reports Codex ready → codex_available = true
3. If Codex missing and npm is available → offer: "Codex is not installed. /codex:setup can install it automatically. Install now? (yes/no)"
4. If installed but not authenticated → prompt: "Please run !codex login to complete authentication"
5. If unavailable for any reason → codex_available = false. All Codex Decision Points are silently skipped.
```

Set `codex_available` once at session start. Do not re-check during the session unless explicitly needed.

### Review Gate (Advanced, Optional)

`codex-plugin-cc` supports an automatic Review Gate that runs Codex after every Claude response:

- Enable: `/codex:setup --enable-review-gate`
- Disable: `/codex:setup --disable-review-gate`

**Warning:** This creates a Claude/Codex loop that can rapidly consume usage limits.
**Recommendation:** Only enable when actively monitoring the session. Not recommended as a default.

---

## B. Full Command Reference

### Executor Engine Commands

#### `/codex:rescue <task>` — Delegate implementation to Codex

```bash
# Basic usage
/codex:rescue <task description> --background

# With model selection
/codex:rescue <task description> --model gpt-5.4-mini --background
/codex:rescue <task description> --model spark --effort medium --background

# With effort level
/codex:rescue <task description> --effort high --background
/codex:rescue <task description> --effort xhigh --background

# Resume a previous rescue session (same repo)
/codex:rescue <task description> --resume --background

# Fresh start (ignore history)
/codex:rescue <task description> --fresh --background

# Wait for completion (short tasks only)
/codex:rescue <task description> --wait
```

**Parameters:**

| Parameter          | Values                    | Description                                                                    |
| ------------------ | ------------------------- | ------------------------------------------------------------------------------ |
| `--background`     | flag                      | Run without blocking Claude session. Recommended for all non-trivial tasks.    |
| `--wait`           | flag                      | Block until complete. Use only for very short tasks.                           |
| `--model <model>`  | `gpt-5.4-mini`, `spark`   | Model selection. `spark` maps to `gpt-5.3-codex-spark` (fastest, lowest cost). |
| `--effort <level>` | `medium`, `high`, `xhigh` | Reasoning intensity. Higher = better results, more tokens.                     |
| `--resume`         | flag                      | Continue previous rescue task in same repo.                                    |
| `--fresh`          | flag                      | Ignore history, start entirely fresh.                                          |

**Natural language delegation also works:**

> "Ask Codex to investigate the failing authentication test and suggest a fix"

---

### Reviewer Engine Commands

#### `/codex:review` — Standard spec compliance review (Stage 1 Reviewer)

```bash
# Basic review (all changes since last commit)
/codex:review --background

# Compare against a specific branch (use when working in a git worktree)
/codex:review --base main --background

# Wait for result (smaller changesets)
/codex:review --base main --wait
```

**Key characteristics:**

- Read-only — cannot modify code
- Not directable — does not accept focus text
- Best for: standard spec compliance checking

---

#### `/codex:adversarial-review` — Adversarial code quality review (Stage 2 Reviewer)

```bash
# Basic adversarial review
/codex:adversarial-review --background

# With branch comparison
/codex:adversarial-review --base main --background

# With focus text (directable)
/codex:adversarial-review --background look for authentication bypass and injection vectors
/codex:adversarial-review --background challenge the caching design and look for race conditions
/codex:adversarial-review --background focus on N+1 query patterns and unbounded memory growth
/codex:adversarial-review --base main --background look for authorization failures and sensitive data exposure
```

**Key characteristics:**

- Directable with focus text — append after all flags
- Higher token cost than standard review
- Best for: security-sensitive, performance-critical, or auth/payment code

---

### Task Management Commands

Orchestra uses these to manage background Codex jobs:

#### `/codex:status [task-id]`

Check status of running or recent tasks.

```bash
/codex:status           # List all recent tasks
/codex:status abc123    # Check specific task
```

Returns: task state (`running`, `completed`, `failed`), elapsed time, brief summary.

#### `/codex:result [task-id]`

Retrieve the final output of a completed task.

```bash
/codex:result           # Get most recent completed task
/codex:result abc123    # Get specific task result
```

Returns: full output + `session-id` which can be used to continue in Codex app:

```bash
codex resume <session-id>
```

#### `/codex:cancel [task-id]`

Cancel a running background task.

```bash
/codex:cancel           # Cancel most recent task
/codex:cancel abc123    # Cancel specific task
```

---

## C. Standard Orchestra Workflow for Codex Operations

```
Phase 1: Dispatch
  → /codex:rescue|review|adversarial-review [args] --background
  → Note the task-id from the command response

Phase 2: Poll (every 15-30 seconds)
  → /codex:status <task-id>
  → Wait until status shows "completed" or "failed"

Phase 3: Retrieve
  → /codex:result <task-id>
  → Save the session-id from the output for activity log

Phase 4: Parse
  → Map Codex output to standard Executor/Reviewer report format
  → See section D below

Phase 5: Continue
  → Proceed with workflow based on parsed verdict
  → If task needs continuation: /codex:rescue --resume --background

Phase 6: Cancel (if needed)
  → If task is stuck or no longer needed: /codex:cancel <task-id>
  → Then retry or fallback to Claude subagent
```

**Polling Interval Guidance:**

| Task Type                         | Initial Poll | Max Wait |
| --------------------------------- | ------------ | -------- |
| `/codex:review` (small changeset) | 30s          | 3 min    |
| `/codex:review` (large changeset) | 60s          | 10 min   |
| `/codex:adversarial-review`       | 60s          | 10 min   |
| `/codex:rescue` (simple task)     | 60s          | 15 min   |
| `/codex:rescue` (complex task)    | 120s         | 30 min   |

If a task exceeds max wait: cancel with `/codex:cancel`, then fall back to Claude subagent or escalate to user.

---

## D. Output Mapping to Standard Executor/Reviewer Formats

### Codex rescue → Executor Report

```
Codex rescue completed → map to Executor report:

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
  - executor_engine: "codex-rescue"
  - codex_session_id: <session-id from /codex:result>
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
  - codex_session_id: <session-id from /codex:result>
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
  - codex_session_id: <session-id from /codex:result>
```

---

## E. Token Cost Reference

Display relevant rows at Decision Points to help user choose:

| Command                                             | Relative Cost | Best For                                        |
| --------------------------------------------------- | ------------- | ----------------------------------------------- |
| `/codex:rescue --model spark --effort medium`       | Lowest        | Simple/mechanical tasks (1-2 files, clear spec) |
| `/codex:review`                                     | Moderate      | Standard spec compliance check                  |
| `/codex:rescue` (default)                           | Moderate-High | General implementation delegation               |
| `/codex:adversarial-review`                         | Higher        | Security/performance-sensitive code             |
| `/codex:rescue --model gpt-5.4-mini --effort xhigh` | Highest       | Complex architecture or deeply stuck tasks      |

---

## F. Model Selection Guide

| Scenario                                           | Recommended                                                |
| -------------------------------------------------- | ---------------------------------------------------------- |
| Simple mechanical task (rename, format, small fix) | `--model spark --effort medium`                            |
| Standard feature implementation                    | Omit `--model` (use Codex default)                         |
| Complex multi-file feature                         | `--model gpt-5.4-mini`                                     |
| Deeply stuck task needing reasoning                | `--model gpt-5.4-mini --effort xhigh`                      |
| Security-focused adversarial review                | `--effort high` (or `--effort xhigh` for critical systems) |

---

## G. Decision Point Presentation Template

When Orchestra presents a Codex Decision Point to the user, use this format:

```
[Decision Point: Executor / Spec Reviewer / Code Quality Reviewer]

Task N: <task name>. Choose engine:
1. Claude subagent (default) — [brief description of what this does]
2. Codex <command> — [brief description] (token cost: <level>)
   [If applicable: suggested flags: --model X --effort Y]
3. [Additional options if applicable]

Enter choice (1-3, default: 1):
```

---

## H. Fallback Strategy

If Codex fails or produces unusable output:

1. Log the failure: note `codex_session_id` and error in activity log `notes`
2. Fallback to Claude subagent for the same role
3. Optionally: try `/codex:rescue --fresh --background` (ignore previous session state)
4. If Codex is consistently failing: set `codex_available = false` for the rest of the session and skip all Codex Decision Points

---

## Quick Reference Card

```
CHECK      /codex:setup
EXECUTE    /codex:rescue <task> [--model gpt-5.4-mini|spark] [--effort medium|high|xhigh] [--background|--wait] [--resume|--fresh]
REVIEW     /codex:review [--base <ref>] [--background|--wait]
ATTACK     /codex:adversarial-review [--base <ref>] [--background|--wait] [focus text]
STATUS     /codex:status [task-id]
RESULT     /codex:result [task-id]
CANCEL     /codex:cancel [task-id]
RESUME     codex resume <session-id>   (in Codex app, not in Claude)
```
