# Root Cause Tracing Patterns

Reference patterns for systematic root cause identification. Use during Phase 2 of `harness-debugging`.

---

## Tracing by Error Type

### Python: AttributeError / TypeError

**Pattern:** `AttributeError: 'NoneType' object has no attribute 'X'`

```
1. Find where the None-returning expression is
2. Trace back: why does it return None?
   - Function doesn't return in all branches
   - Dictionary key missing (use .get() returns None)
   - ORM query returns None (object not found)
3. Fix: add None guard, raise appropriate error, or ensure object always exists
```

**Pattern:** `TypeError: X() takes N positional arguments but M were given`

```
1. Count the parameters in the function signature
2. Count the arguments at the call site
3. Look for: missing self, extra positional arg, mismatched API
```

---

### JavaScript/TypeScript: TypeError / ReferenceError

**Pattern:** `Cannot read properties of undefined (reading 'X')`

```
1. Find which object is undefined
2. Trace the data flow backward to where it was assigned
3. Check: async timing (awaited?), API response shape, conditional rendering
```

**Pattern:** `ReferenceError: X is not defined`

```
1. Check import statements at the top of the file
2. Check if the variable is declared in the right scope
3. Check for circular imports
```

---

### Test Failures: "Expected X but got Y"

```
1. Print the actual value of what's being compared
2. Is the actual value a Promise/async result that wasn't awaited?
3. Is the test checking the wrong property?
4. Is there test pollution (shared mutable state between tests)?
5. Does the expected value reflect the actual spec?
```

**Test isolation check:**

```bash
# Run only the failing test in isolation
pytest tests/path/test_file.py::test_name -v
# vs run the whole suite
pytest tests/ -v
# If isolation passes but suite fails: test pollution
```

---

### Database / ORM Errors

**Pattern:** `IntegrityError: NOT NULL constraint failed`

```
1. Which field is null?
2. Where is that field supposed to be set?
3. Is a factory/fixture missing a required field?
4. Did a migration add a required column without a default?
```

**Pattern:** `DoesNotExist` / `RecordNotFound`

```
1. What ID/filter is being used to look up the record?
2. Does that record actually exist in the test database?
3. Is the test creating the record before querying it?
4. Is the test using the wrong database fixture?
```

---

### Import / Module Resolution Errors

```
1. Check sys.path / NODE_PATH / PYTHONPATH
2. Check if the package is installed: pip list / npm list
3. Check for typos in the import path
4. Check if it's a relative vs absolute import issue
5. Check for circular imports (A imports B, B imports A)
```

---

### Async / Concurrency Errors

**Pattern:** Intermittent test failures

```
1. Look for: shared mutable state, race conditions
2. Are tests running in parallel that shouldn't?
3. Are async operations properly awaited?
4. Are there time-dependent tests (sleep, datetime.now())?
```

**Pattern:** `asyncio.CancelledError` / `RuntimeError: Event loop is closed`

```
1. Check event loop lifecycle in test setup/teardown
2. Are you mixing sync and async code?
3. Is cleanup happening before all async operations complete?
```

---

## Tracing by Layer

### "The test was passing and now it fails"

```
1. git log --oneline -10 (what changed recently?)
2. git diff HEAD~1 (what's different?)
3. Did a dependency update change behavior?
4. Did a schema migration change the data model?
5. Is the test environment different from before?
```

### "The code looks correct but doesn't work"

```
1. Add explicit type printing: print(type(x), repr(x))
2. Simplify: can you reproduce the bug in a 5-line script?
3. Check assumptions: is the function actually being called?
4. Add a log at function entry: confirm it's reached
5. Binary search: comment out half the code to isolate where behavior diverges
```

### "It works locally but fails in CI"

```
1. Environment variables missing in CI?
2. Different Python/Node version?
3. Missing system dependency (OS packages)?
4. Test database not seeded?
5. Parallel test execution causing race conditions?
6. File paths (relative vs absolute)?
```

---

## The 5-Why Technique

When stuck, apply 5-Why to peel back layers:

```
Why did the test fail?
  → Because assert result == expected returned False

Why was result wrong?
  → Because the function returned None instead of a list

Why did the function return None?
  → Because the early return at line 42 triggers when input is empty

Why does empty input trigger the early return?
  → Because the guard clause `if not items: return None` was added in task-5

Why was that guard clause added?
  → Because task-5 spec said "return None for empty input" but we're now calling it differently

Root cause: Spec changed in task-7 but guard clause from task-5 wasn't updated.
Fix: Update the guard clause to match the new spec.
```
