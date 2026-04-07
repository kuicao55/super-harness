---
name: harness-tdd
description: "Test-Driven Development skill for claude-codex-harness Executors. Red-Green-Refactor cycle with strict discipline. Reference for Executor subagents and plan-writing."
---

# Harness TDD — Test-Driven Development

The Executor's core discipline. No production code without a failing test first. This skill is referenced by `executor-prompt.md` and by plan authors when defining task steps.

**Announce at start (if invoked directly):** "I'm using the harness-tdd skill. Applying strict Red-Green-Refactor discipline."

## The Iron Law

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST.
```

Breaking this rule guarantees untestable code, untested behavior, and integration failures that are painful to debug. There are no exceptions.

---

## The Red-Green-Refactor Cycle

### Red Phase: Write the Failing Test

1. Write a test that describes the **desired behavior** (not the implementation)
2. The test should be as simple as possible while testing exactly one behavior
3. Run the test — it MUST fail. If it passes without implementation, the test is wrong.
4. Confirm the failure is for the **right reason**:
   - ✅ `AssertionError: expected X, got None` — correct failure
   - ❌ `ImportError: No module named 'X'` — fix the import first, this isn't a behavior failure
   - ❌ `SyntaxError` — fix the syntax first

**Good test characteristics:**

- Tests behavior, not implementation details
- Has exactly one assertion (or closely related assertions)
- Has a descriptive name: `test_<what>_when_<condition>_returns_<expected>`
- Is independent of other tests (no shared state)

### Green Phase: Write Minimal Implementation

1. Write the **minimum code** to make the failing test pass
2. Do NOT over-engineer at this stage
3. It's okay if the implementation is ugly — that's what Refactor is for
4. Run the test — it MUST pass

**The "Obvious Implementation" Trap:**

If you think you know the full implementation, resist the urge. Write just enough to pass the current test. Future tests will drive the rest of the implementation.

### Refactor Phase: Improve the Code

1. The test suite must still be green after every change
2. Improve: names, structure, duplication, clarity
3. Do NOT add new functionality during Refactor (that's a new Red phase)
4. Run the tests after every significant change

---

## Writing Tests That Actually Test

A test is **hollow** if it would pass with a completely wrong implementation. Watch for:

**Mocking too much:**

```python
# BAD: Tests that the mock was called, not that the behavior works
def test_send_email():
    mock_mailer = Mock()
    service = UserService(mailer=mock_mailer)
    service.register(user)
    mock_mailer.send.assert_called_once()  # Hollow — says nothing about what was sent
```

```python
# GOOD: Tests actual behavior through real integration or a meaningful assertion
def test_send_email_sends_welcome_to_registered_user():
    captured = []
    service = UserService(mailer=CapturingMailer(captured))
    service.register(User(email="user@example.com", name="Alice"))
    assert len(captured) == 1
    assert captured[0].to == "user@example.com"
    assert "welcome" in captured[0].subject.lower()
```

**Only testing the happy path:**

```python
# Missing: empty input, None input, duplicate email, invalid format
```

---

## Test Organization

### Naming

```python
# Pattern: test_<behavior>_when_<condition>_<expected_result>

def test_user_registration_with_duplicate_email_raises_conflict():
def test_cart_total_with_empty_cart_returns_zero():
def test_order_status_when_payment_fails_remains_pending():
```

### Structure (Arrange-Act-Assert)

```python
def test_assign_task_to_available_user():
    # Arrange
    user = create_user(available=True)
    task = create_task(status="unassigned")

    # Act
    result = assign_task(task.id, user.id)

    # Assert
    assert result.status == "assigned"
    assert result.assignee_id == user.id
```

### Test Isolation

- Each test must be able to run independently
- Use fixtures/factories for setup, not shared global state
- Clean up any side effects in teardown
- Never write tests that depend on run order

---

## TDD for the Executor

The Executor applies TDD task by task:

1. **Before writing any implementation file** — write the test file first
2. **Before implementing any function** — write the test for that function first
3. **After each failing test is confirmed** — write minimal implementation
4. **After each test passes** — run the full suite (not just the new test) to catch regressions
5. **At the end of the task** — run the complete test suite

**The Executor's self-check before reporting:**

- Every production code file has a corresponding test file
- Every function is tested by at least one test
- All tests pass
- No test is obviously hollow

---

## Common TDD Failures

| Failure                        | Symptom                     | Fix                                     |
| ------------------------------ | --------------------------- | --------------------------------------- |
| Writing tests after code       | Tests pass on first run     | Delete implementation, start with test  |
| Testing implementation details | Tests break on refactor     | Rewrite to test behavior                |
| Too many assertions per test   | Hard to know what failed    | Split into focused tests                |
| Test depends on other tests    | Fails when run in isolation | Add independent setup                   |
| Mock replaces everything       | Tests pass, runtime fails   | Use real implementations where possible |

---

## Integration

This skill is referenced by:

- `executor-prompt.md` — Executor subagents apply these principles
- `harness-plan-writing` — Plan authors use this format for step-by-step TDD tasks
- `agents/executor.md` — Core principles for the Executor role definition
