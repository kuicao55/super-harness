# TDD Enforcement Mechanism — Improvement Proposal

## Status

Draft | 2026-04-08

---

## Problem Statement

The current TDD implementation in `harness-execution` is **advisory, not enforceable**. It defines what TDD is and what an Executor should do, but provides no mechanism to verify the Red-Green-Refactor cycle was actually followed. This creates a gap between the stated discipline and its enforcement.

---

## Root Cause

The Orchestra / Executor / Reviewer architecture validates **outputs**, not **process**:

| What is verified | What is NOT verified |
|------------------|----------------------|
| Final code matches spec | Test file was created before implementation file |
| Tests pass | Test actually failed before implementation |
| Test quality (hollow or real) | Implementation was minimal for the passing test |
| — | Git commit/file creation order confirms TDD sequence |

---

## Cross-Validation: What Superpowers Does Right

Reference: `/Users/kuicao/Applications/superpowers` — "superpowers" project TDD implementation.

### Superpowers Has, Harness Lacks

| Superpowers Mechanism | Harness Status | Notes |
|-----------------------|----------------|-------|
| **Rationalization Tables** — explicit excuses + reality counters | ❌ Missing | Prevents self-deception |
| **Red Flags STOP rule** — explicit list of violations that mean "delete and restart" | ❌ Missing | Clear trigger for restart |
| **"Evidence Before Claims" gate** — 5-step verification function before any claim | ❌ Missing | Closes "I trust myself" gap |
| **Regression Test Pattern** — "Write→Pass→Revert→Must Fail→Restore→Pass" | ❌ Missing | Proves test is real, not hollow |
| **Violations framed as "lying/dishonesty"** | ⚠️ Advisory only | Superpowers treats this as a core value violation |
| **Meta-TDD for skill creation** — TDD applied to building skills themselves | ❌ Not applicable | Different scope |

### Key Insight from Superpowers

The most critical gap is **not technical, it's psychological**:

> Superpowers: "Violating the letter of the rules is violating the spirit of the rules."
> Harness: "If you write production code before a failing test: delete it and start over."

Superpowers treats TDD violations as **dishonesty** (a character/value issue), not just **suboptimal behavior** (a skill issue). This framing dramatically changes how an agent responds to temptation to shortcut.

**Recommended framing for `harness-tdd/SKILL.md` and `executor-prompt.md`:**

```
VIOLATION = LYING, NOT JUST MISTAKING

When you claim "tests pass" but didn't watch them fail first:
- You are not "skipping a step"
- You are claiming verification you did not perform
- This is the same as claiming "build succeeded" without running the build

Evidence before claims. Always. No exceptions.
```

---

## Proposed Improvements

### 1. Add TDD Process Audit Step (Enforcement Gate)

**Location:** After Executor reports DONE, before Spec Review Decision Point.

**New Step in `harness-execution/SKILL.md`:**

```
### Step 1.5: TDD Process Audit (Mandatory)

Before accepting Executor's report, verify:

□ Test file created before first implementation file (git log or file mtime)
□ Test failed at least once before implementation was added
□ Commit/message history contains evidence of Red → Green → Refactor sequence

If TDD sequence cannot be verified:
  → Flag as PROCESS_VIOLATION
  → Do not proceed to Spec Review
  → Return to Executor with: "TDD process not verified. Show evidence or re-run."

If verified:
  → Proceed to Spec Review Decision Point
```

**Why:** Closes the enforcement gap. Executor cannot skip Red phase without detection.

**Source:** Inspired by superpowers "verification-before-completion" gate — "evidence before claims, always."

---

### 2. Create `harness-tdd-audit` Skill

**New skill:** `skills/harness-tdd-audit/SKILL.md`

Responsibilities:
- Accept Executor report + working directory
- Run git log analysis to confirm file creation order
- Run a "blank test" verification: comment out implementation, run test, confirm it fails (proves test is not hollow)
- Report PROCESS_AUDIT: PASS | FAIL

**Verification commands to run:**

```bash
# 1. Check file creation order
git log --oneline --format="%H %s" --name-only | grep -E "\.py$|\.test\." | head -20

# 2. Confirm test fails without implementation
# (Implementation temporarily commented, run test, verify failure)

# 3. Check for "Red" commits (test file only, no implementation)
# and "Green" commits (implementation that makes test pass)
```

**Why:** Provides a dedicated, automated verification mechanism independent of Spec Reviewer and Code Quality Reviewer.

---

### 3. Extend Code Quality Reviewer to Include TDD Process Review

**File to modify:** `skills/harness-execution/code-quality-reviewer-prompt.md`

**Add to Attack Vectors:**

```
**TDD Process Integrity:**
- Did Executor actually write tests before implementation?
- Do commits show test-first pattern (small test commit, then implementation commit)?
- Were tests run and observed to fail before green phase?
- Did Green phase commits stay minimal (no feature additions)?
- Is there evidence of actual Refactor phase, or just "Green then done"?
```

**New Verdict Category:**

```
### TDD_PROCESS_FAIL

Return TDD_PROCESS_FAIL when:
- Test file was created after implementation file
- No evidence of test failure before implementation
- Implementation contains more than minimal code to pass test

A TDD_PROCESS_FAIL returns the task to Executor with explicit instructions to re-run the Red-Green-Refactor cycle, not just "fix the test."
```

**Why:** CQR already has "run tests yourself if possible" — formalizing this and adding process order checks makes it enforceable.

---

### 4. Add Process Violation to Executor Status

**File to modify:** `agents/executor.md`, `executor-prompt.md`, `harness-execution/SKILL.md`

**New status:** `PROCESS_VIOLATION`

```
Status: DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT | PROCESS_VIOLATION

PROCESS_VIOLATION: Task completed but TDD sequence was not followed.
- TDD Process Audit or CQR detected process deviation
- Executor must re-run from Red phase, not from current state
```

**Why:** Distinguishes between "code has problems" and "process was violated" — these require different corrections.

---

### 5. Plan-Writing: Require TDD Evidence in Task Description

**File to modify:** `skills/harness-plan-writing/SKILL.md`

**Add to task template:**

```markdown
- [ ] **Step N: [Task name]**
  - Test file: `tests/exact/path/to/test_file.py`
  - Implementation: `path/to/implementation.py`
  - TDD sequence:
    1. Write failing test in `tests/...`
    2. Confirm failure: expected error message: "[X]"
    3. Write minimal implementation in `path/...`
    4. Confirm test passes
    5. Refactor (if needed)
```

**Why:** Forces plan author to think about TDD steps upfront, making the sequence explicit rather than implied.

---

### 6. Add Rationalization Counter-Tables

**File to modify:** `skills/harness-tdd/SKILL.md`

**Add after "Common TDD Failures" table:**

Superpowers has an explicit "Rationalization Tables" section that counters common self-deceptions. Harness should add the same.

**Add to `harness-tdd/SKILL.md`:**

```
## Rationalization Counter-Tables

These excuses are **rationalizations**, not reasons. When you catch yourself thinking these, recognize it as a signal to apply TDD strictly:

| Excuse | Reality |
|-------|---------|
| "I'll write tests after to verify it works" | Tests written after pass immediately. Passing immediately proves nothing. |
| "I already manually tested all the edge cases" | Manual testing is ad-hoc, no record, can't re-run. |
| "Deleting X hours of work is wasteful" | Sunk cost fallacy. Keeping unverified code is technical debt. |
| "This is different because [reason]" | TDD applies to all code. "Different" = rationalizing. |
| "The test is too hard to write" | Hard to test = hard to use. Listen to the test. |
| "I know this works, I'll add tests later" | Later = often never. And later tests miss edge cases. |
| "It's just a small change" | Small changes break. Every change needs a test. |

**Anti-rationalization rule:**
If you find yourself explaining why TDD doesn't apply, that's the signal to apply it more strictly.
```

---

### 7. Add Red Flags — STOP and Restart Rule

**File to modify:** `skills/harness-tdd/SKILL.md`

**Add after Rationalization Tables:**

```
## Red Flags — STOP and Restart

These are **process violations**, not merely suboptimal behavior. If any of these occur, the task must be **restarted from the Red phase**, not patched:

- Code committed before any test file was created
- Test passes immediately after being written (before implementation)
- Executor reports "tests pass" but cannot describe why the test failed first
- Implementation added incrementally without corresponding test-driven steps
- Executor uses phrases like: "should work", "probably fine", "I'm confident"
- Claims of completion before verification commands have been run

**When any Red Flag is detected:**
→ Do not proceed to Spec Review
→ Return task to Executor with: "TDD process violated. Delete implementation, restart from Red phase."
→ Not "fix the test" — restart the cycle
```

**Source:** Directly adapted from superpowers `test-driven-development/SKILL.md` "Red Flags — STOP and Start Over" section.

---

### 8. Add "Evidence Before Claims" Gate to Executor Prompt

**File to modify:** `skills/harness-execution/executor-prompt.md`

**Add as a new section before "Before You Begin":**

```
## Evidence Before Claims

**The Iron Rule:**

You cannot claim any verification passed without running the verification.

```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```

When you report "all tests pass":
- You must have run `npm test` or `pytest` in this session
- You must have read the output showing 0 failures
- "Previous run passed" ≠ "this run passes"

When you report "test failed for the right reason":
- You must have run the test and observed the specific failure message
- "It should fail here" ≠ "I watched it fail here"

**The 5-step verification function (before any claim):**

1. IDENTIFY: What command proves this claim?
2. RUN: Execute the FULL command (fresh, complete)
3. READ: Full output, check exit code, count failures
4. VERIFY: Does output confirm the claim?
5. ONLY THEN: Make the claim with the evidence

Skip any step = lying, not verifying.
```

**Source:** Adapted from superpowers `verification-before-completion/SKILL.md`.

---

### 9. Add Regression Test Verification Pattern

**File to modify:** `skills/harness-tdd/SKILL.md`

**Add to "Writing Tests That Actually Test" section:**

```
### The Regression Test Proof (Proving Tests Are Not Hollow)

A hollow test passes even when the implementation is completely wrong. Prove your test is real:

1. Write test → Run → PASS (implementation exists)
2. **Revert implementation** (comment out or delete the fix)
3. Run test → **MUST FAIL** (proves test catches missing behavior)
4. Restore implementation
5. Run test → PASS (proves restoration works)

If the test passes in step 2, the test is hollow — it tests implementation, not behavior.

**Why this matters:** CQR checks for hollow tests. This pattern provides evidence that tests are real before CQR even runs.
```

---

## Implementation Priority

| Priority | Change | Effort |
|----------|--------|--------|
| 1 (Critical) | Add TDD Process Audit step to `harness-execution` | Low — new step in existing flow |
| 2 (High) | Create `harness-tdd-audit` skill | Medium — new skill file |
| 3 (High) | Extend CQR to include TDD process review | Low — add to existing prompt |
| 4 (Medium) | Add PROCESS_VIOLATION status | Low — add to status enum |
| 5 (Low) | Update plan-writing template | Low — add fields to template |
| 6 (High) | Add Rationalization Counter-Tables | Low — add to existing TDD SKILL |
| 7 (High) | Add Red Flags STOP rule | Low — add to existing TDD SKILL |
| 8 (High) | Add "Evidence Before Claims" gate to Executor prompt | Low — add to existing prompt |
| 9 (Medium) | Add Regression Test Proof pattern | Low — add to TDD SKILL |

---

## Alternative Approach: Automated TDD Verification

Instead of (or in addition to) manual audit, consider adding a CI-level check:

```bash
#!/bin/bash
# pre-commit or pre-merge hook: tdd-sequence-check.sh

# For each test file changed in this branch:
TEST_FILES=$(git diff --name-only main...HEAD | grep test_)
for test_file in $TEST_FILES; do
    impl_file=$(echo $test_file | sed 's|tests/||' | sed 's|test_||')
    test_commit=$(git log --oneline --format="%H" -- $test_file | tail -1)
    impl_commit=$(git log --oneline --format="%H" -- $impl_file | tail -1 2>/dev/null || echo "none")

    if [ "$impl_commit" != "none" ] && git log --oneline $test_commit..$impl_commit | grep -q .; then
        echo "VIOLATION: Implementation committed before test for $impl_file"
        exit 1
    fi
done
echo "TDD sequence verified."
```

**Trade-off:** This catches file creation order but not "test was written but implementation was added before test failed." The Process Audit (approach #1) is still needed for behavioral verification.

---

## Open Questions

1. **Who performs the Process Audit?** Is it Orchestra (main agent), a dedicated subagent, or an automated script?

2. **Should Process Violation be retried or fatal?** If an Executor skips TDD, should it retry the entire task, or just the process step?

3. **How to handle Codex rescues?** If `/codex:rescue` is used, can it be TDD-enforced? The codex-integration SKILL would need parallel changes.

4. **Cost vs. benefit for small tasks?** TDD audit adds overhead. Should it be required for all tasks, or only tasks above a complexity threshold?

5. **Framing choice:** Should harness adopt the "lying/dishonesty" framing from superpowers, or keep the current advisory tone? This is a design decision about agent psychology.

---

## References

### Harness Project
- Current TDD skill: `skills/harness-tdd/SKILL.md`
- Current execution flow: `skills/harness-execution/SKILL.md`
- Executor prompt template: `skills/harness-execution/executor-prompt.md`
- Code Quality Reviewer prompt: `skills/harness-execution/code-quality-reviewer-prompt.md`
- Plan-writing skill: `skills/harness-plan-writing/SKILL.md`

### Superpowers Project (Reference/Benchmark)
- TDD skill: `/Users/kuicao/Applications/superpowers/skills/test-driven-development/SKILL.md`
- Verification-before-completion: `/Users/kuicao/Applications/superpowers/skills/verification-before-completion/SKILL.md`
- Testing anti-patterns: `/Users/kuicao/Applications/superpowers/skills/test-driven-development/testing-anti-patterns.md`
- Subagent workflow: `/Users/kuicao/Applications/superpowers/skills/subagent-driven-development/SKILL.md`
