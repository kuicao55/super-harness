---
name: harness-debugging
description: "Systematic debugging methodology for claude-codex-harness. 4-phase root cause investigation before any fix. Use when encountering any bug, test failure, or unexpected behavior during execution."
---

# Harness Debugging — Systematic Root Cause Investigation

A structured 4-phase debugging methodology. Always investigate root cause before writing a fix. Guessing wastes time and compounds problems.

**Announce at start:** "I'm using the harness-debugging skill. Investigating root cause before attempting any fix."

## The Iron Law

```
NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST.
```

If you jump straight to a fix:

- You might fix a symptom while the real bug remains
- You might introduce new bugs while patching the wrong thing
- You will definitely waste time if the fix doesn't work

**A fix is only valid if you can explain exactly why the bug occurred and exactly why the fix addresses it.**

---

## When to Invoke This Skill

- A test fails unexpectedly during `claude-codex-harness:harness-execution`
- An Executor reports BLOCKED with a confusing error
- The full test suite fails after all tasks complete
- Code Quality Review flags an error you can't immediately explain
- You have attempted a fix and it didn't work

---

## Phase 1: Root Cause Identification

**Objective:** Understand precisely what is failing and why.

### 1.1 Reproduce the Failure

- Run the exact failing command
- Capture the complete error message and stack trace
- Do NOT make any changes yet

### 1.2 Characterize the Failure

Answer these questions:

- **What fails?** (specific test, specific line, specific assertion)
- **When does it fail?** (always, sometimes, only in certain conditions)
- **What was changed most recently?** (git log, diff)
- **What is the error message saying literally?**

### 1.3 Read the Root Cause Tracing File

Consult `root-cause-tracing.md` in this skill directory for tracing patterns specific to common failure types.

### 1.4 Form a Hypothesis

Write out your hypothesis in one sentence:

> "I believe the failure is caused by [X] because [Y]."

Do NOT proceed to Phase 2 until you have a hypothesis.

---

## Phase 2: Pattern Analysis

**Objective:** Find where and why the bug exists in the code.

### 2.1 Locate the Failure Point

- Read the exact file and line where the error occurs
- Read 30 lines above and below for context
- Follow the call stack upward if needed

### 2.2 Look for These Common Patterns

**Logic errors:**

- Off-by-one in loops or array indices
- Wrong conditional (== vs ===, < vs <=)
- Missing base case in recursion
- Incorrect boolean logic (AND/OR confusion)

**State errors:**

- Mutable state shared between tests (test pollution)
- Initialization order dependencies
- Race conditions in async code
- Stale cache or config values

**Type errors:**

- Null/None/undefined not handled
- Type coercion producing unexpected values
- Wrong type passed to a function

**Integration errors:**

- Interface mismatch between components
- Missing import or dependency
- Environment variable not set
- File path wrong for the execution context

### 2.3 Check Test Quality

If the error is in a test:

- Is the test actually testing the right thing?
- Would the test pass with a completely wrong implementation?
- Is the test relying on implementation details instead of behavior?
- Is the test order-dependent?

---

## Phase 3: Hypothesis Testing

**Objective:** Confirm root cause before writing a fix.

### 3.1 Validate Your Hypothesis

Add temporary debug output or assertions to confirm the hypothesis:

```python
# Temporary: confirm the actual value at the failure point
print(f"DEBUG actual_value={actual_value!r}")
assert actual_value == expected_value, f"Expected {expected_value!r}, got {actual_value!r}"
```

**Do NOT write the fix yet.** Confirm the root cause first.

### 3.2 Prove You Can Reproduce It Consistently

Run the failing code multiple times to confirm:

- The bug is deterministic (or understand its non-determinism)
- Your hypothesis correctly predicts when it fails

### 3.3 If Hypothesis is Wrong

If your hypothesis doesn't explain the failure:

- Return to Phase 2 with new information
- Expand the search radius (look higher in the call stack)
- Consider that the bug may be in a dependency, not your code

---

## Phase 4: Implementation

**Objective:** Fix precisely and verify completely.

### 4.1 Write the Fix

The fix should:

- Address exactly the root cause identified in Phase 3
- Change the minimum code necessary
- Not introduce new behavior beyond fixing the bug

### 4.2 Remove Debug Code

Remove all temporary `print`, `debug`, or `assert` statements added in Phase 3.

### 4.3 Verify the Fix

```bash
# Run the originally failing test/command
<exact original failing command>

# Run the full test suite
<full test command>
```

Both must pass. If the originally failing test now passes but other tests break, you have a regression — return to Phase 1.

### 4.4 Write a Regression Test

If the bug was not caught by existing tests, write a test that specifically catches this failure mode:

```python
def test_regression_<bug_description>():
    """Regression: <brief description of what failed and why>"""
    # Setup that triggers the bug
    # Assert the bug is fixed
```

---

## Three-Strike Rule

If you have attempted the same fix 3 times and it still fails:

1. **Stop**
2. Re-read the complete error from scratch (not your memory of it)
3. Expand your hypothesis: the bug may be in a different layer than you thought
4. Consider: is this an architectural issue, not a bug fix?

If 3+ attempts at different hypotheses all fail:

> "This bug may indicate a deeper architectural issue. The root cause may not be in the code being modified."

**Escalate to the user with:**

- All 3 hypotheses tried and why each was wrong
- What you currently believe the root cause is
- A proposed architectural change (not a band-aid fix)

---

## Red Flags — STOP Debugging and Escalate

- You're making "maybe this will work" changes without a hypothesis
- You've changed 5+ files while fixing what sounded like a 1-line bug
- The stack trace points to a library you don't understand
- You've been debugging for 45+ minutes without a clear theory
- Tests are passing but for the wrong reason (you disabled assertions)

---

## Integration

This skill is invoked by `claude-codex-harness:harness-execution` when:

- Full test suite fails after all tasks complete
- An Executor reports BLOCKED with an error
- The user explicitly requests debugging assistance

After debugging is resolved, return to the calling context (harness-execution or the original Executor task).
