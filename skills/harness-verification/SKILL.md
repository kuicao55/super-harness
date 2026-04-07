---
name: harness-verification
description: "Verification before completion for claude-codex-harness. Run fresh evidence before claiming work is done. Use before marking any task, milestone, or project as complete."
---

# Harness Verification — Evidence Before Completion Claims

Before claiming any work is complete, verified, or passing — run the actual checks and confirm with evidence. Claims without evidence are unreliable.

**Announce at start:** "I'm using the harness-verification skill. Running verification before claiming completion."

## The Iron Law

```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE.
```

This means:

- Do NOT say "tests should pass" — run them and show the output
- Do NOT say "this is fixed" — confirm with a test run
- Do NOT say "all tasks complete" — verify with a full suite run
- Do NOT trust previous test results if code has changed since they ran

---

## When to Invoke This Skill

- Before marking a task complete in `claude-codex-harness:harness-execution`
- Before claiming a milestone is done
- Before marking a project as complete
- After applying any fix (to confirm the fix works)
- Before creating a PR or merging a branch
- When asked "is this done?" by the user

---

## Gate Function: IDENTIFY → RUN → READ → VERIFY → CLAIM

### Gate 1: IDENTIFY — What needs to pass?

Before running anything, identify all verification targets:

```
□ Unit tests — which test file(s) cover this task?
□ Integration tests — which test file(s) test the whole flow?
□ Type checking — if applicable (mypy, tsc, etc.)
□ Linting — if project has a linter configured
□ Specific test for this task — can you point to the test that proves the requirement is met?
```

List them explicitly before running.

### Gate 2: RUN — Execute fresh

Run each identified check fresh:

```bash
# Example: Python project
python -m pytest tests/ -v 2>&1

# Example: Node/TypeScript project
npm test 2>&1

# Example: type check
mypy src/ 2>&1
tsc --noEmit 2>&1
```

**Key rules:**

- Must be a fresh run — not a remembered result
- Must run from the correct working directory
- Must include full output (not truncated)

### Gate 3: READ — Read the actual output

Read the complete test output. Do not skim. Check:

- Total test count
- Pass count
- Failure count
- Any warnings that might indicate problems
- Any skipped tests (are they intentionally skipped?)

### Gate 4: VERIFY — Confirm expectations are met

Verify each item from Gate 1:

```
□ Unit tests: N/N passed, 0 failed
□ Integration tests: N/N passed, 0 failed
□ Type checking: 0 errors
□ Linting: 0 errors (warnings acceptable if pre-existing)
□ Task-specific test: identified test is passing and actually tests the right behavior
```

If any item fails, STOP. Do NOT claim completion. Invoke `claude-codex-harness:harness-debugging` if needed.

### Gate 5: CLAIM — State what was verified

Only after all gates pass, make the completion claim with evidence:

> "Verification complete. Evidence:
>
> - Unit tests: 47/47 passed (0 failed)
> - Integration tests: 12/12 passed (0 failed)
> - Type check: 0 errors
> - Task-specific test `test_user_assignment` is passing
>
> Task N is verified complete."

---

## What "Fresh" Means

A verification is **fresh** if:

- You ran the command yourself in this session
- No code changes occurred between this run and the claim
- You can show the actual output (not paraphrase it)

A verification is **NOT fresh** if:

- You're relying on a test run from earlier in the session
- You're relying on the Executor's report of what passed
- You're relying on the Code Quality Reviewer's report
- You changed code after the last test run

---

## Partial Verification is Not Verification

Do NOT claim "tests pass" if you only ran a subset:

```
❌ "The unit tests pass" (if integration tests weren't run)
❌ "All tests pass" (if type checking wasn't run)
❌ "The new test passes" (if you didn't run the full suite to check for regressions)
```

Run everything every time.

---

## Integration

This skill is invoked by `claude-codex-harness:harness-execution` before:

- Marking a milestone as passed
- Claiming all tasks are complete
- Invoking `claude-codex-harness:harness-finishing`

After verification passes, return the evidence to the calling context.
