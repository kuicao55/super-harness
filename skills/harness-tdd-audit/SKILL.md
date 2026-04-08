---
name: harness-tdd-audit
description: "TDD Process Audit skill for super-harness. Verifies Executor completed tasks with genuine TDD discipline. Called by Orchestrator after Executor reports DONE and before Spec Review."
---

# Harness TDD Audit

Verifies that the Executor applied genuine TDD discipline on a completed task. Called by Orchestrator as a mandatory gate between Executor DONE and Spec Review. TDD_AUDIT: PASS is required to proceed; FAIL returns the task to Executor for re-implementation.

**Announce at start:** "I'm using the harness-tdd-audit skill to verify TDD process compliance."

## Trigger

This skill is invoked by Orchestrator after:
1. Executor reports `Status: DONE` or `Status: DONE_WITH_CONCERNS`
2. Orchestrator has received the Executor's report including `TEST_OUTPUT`

**Input required from Orchestrator:**
- Executor report (status + TEST_OUTPUT)
- List of files created/modified during the task (implementation files + test files)

## The Audit

Run these checks in order. Stop at the first FAIL.

### Check 1: File Creation Order

Use `git log --diff-filter=A --format="%H %ad %s" --date=iso -- <file>` to get each file's creation commit time.

Compare test file(s) vs. implementation file(s):

- ✅ Test file created at or before implementation file → proceed
- ❌ Implementation file created before test file → **TDD_AUDIT: FAIL**

If files are not yet committed (no git history), check with `ls -la` timestamps and note it as CANNOT_VERIFY (treated as FAIL).

### Check 2: First Test Run Was RED

Examine the Executor's `TEST_OUTPUT` in the report:

- Does the TEST_OUTPUT show a FAIL before any implementation? (look for FAIL→PASS sequence)
- Or did the Executor report running tests and seeing FAIL first?

✅ First recorded test run was FAIL → proceed
❌ First test run was PASS without any implementation → **TDD_AUDIT: FAIL** (test is hollow or not testing behavior)
❓ No TEST_OUTPUT present → **TDD_AUDIT: CANNOT_VERIFY** (treated as FAIL)

### Check 3: Tests Are Not Hollow

Read the test file(s) created during this task:

- ✅ Each test has a real assertion (not just `assert True`, `pass`, or no assertion)
- ✅ Each test would FAIL if the implementation were reverted/deleted

❌ Any test is hollow (`assert True`, `pass`, no real check) → **TDD_AUDIT: FAIL**
❌ Any test would PASS even with wrong implementation → **TDD_AUDIT: FAIL**

### Check 4: Public Interface Coverage

For each public function/method/API in the implementation files:

- ✅ There is at least one test that exercises it
- ❌ A public function has no corresponding test → **TDD_AUDIT: FAIL** (coverage gap)

If the task only implements internal/private logic (no public API), verify the private functions are tested and note the constraint.

## Output

After all checks, report:

```
### TDD Audit Result: PASS | FAIL | CANNOT_VERIFY

Checks completed:
1. File creation order: PASS | FAIL
2. First test run was RED: PASS | FAIL | CANNOT_VERIFY
3. Tests not hollow: PASS | FAIL
4. Public interface coverage: PASS | FAIL | N/A

Overall: TDD_AUDIT: PASS

Notes (if any checks had caveats):
[brief notes]
```

### CANNOT_VERIFY Handling

If any check returns CANNOT_VERIFY (e.g., git history unavailable, TEST_OUTPUT missing):

- Treat as **TDD_AUDIT: FAIL** by default (do not trust unverified claims)
- Orchestrator: return task to Executor with `Status: PROCESS_VIOLATION` for re-implementation

## Referenced Rules

This skill enforces the constraints defined in `harness-tdd/SKILL.md`:

- **Rationalization Counter-Tables** — common TDD violations and their mandatory counter-arguments
- **Red Flags — STOP and Restart** — scenarios that require immediate halt and restart from Red phase
- **Regression Test Validation Pattern** — the Write→Pass→Revert→Fail→Restore→Pass sequence

When a TDD_AUDIT FAIL matches a Red Flag condition, include the Red Flag restart protocol in the Orchestrator's guidance.
