---
name: harness-plan-writing
description: "Scale-aware implementation planning for claude-codex-harness. Assesses project scope, manages claude-progress.json for large projects, and generates detailed session plan.md files following TDD discipline."
---

# Harness Plan-Writing

Write implementation plans with full TDD discipline. For large projects, manage cross-session milestone tracking via `claude-progress.json`. For small projects, produce a single plan.md using the standard superpowers approach.

**Announce at start:** "I'm using the harness-plan-writing skill to create the implementation plan."

## Step 1: Scale Assessment

Before writing any plan, evaluate the project scope:

**Ask yourself (or confirm with the user if unclear):**

- How many distinct features or components need to be built?
- How many implementation tasks are roughly required?
- Does this cross multiple modules, services, or layers?
- Will this realistically require more than one Claude session to complete?

**Decision:**

| Criteria                                                      | Classification    |
| ------------------------------------------------------------- | ----------------- |
| Single feature, <10 tasks, one session                        | **Small project** |
| Multiple features, 10+ tasks, multiple sessions, cross-module | **Large project** |

If unsure, ask the user: "This looks like it could span multiple sessions. Would you like to track this as a multi-milestone project? (yes/no)"

---

## Path A: Small Project

Skip `claude-progress.json` entirely.

1. Write a single `plan.md` following the full superpowers-style format (see Task Structure below)
2. Save to `docs/harness/plans/YYYY-MM-DD-<feature-name>.md`
3. Offer execution: invoke `claude-codex-harness:harness-execution` when ready

---

## Path B: Large Project — Milestone Management

### B1: Initialize or Update `status/claude-progress.json`

**If the file does NOT exist (new large project):**

1. Decompose the project into milestones. Each milestone should:
   - Represent approximately one session's worth of work
   - Deliver working, testable software on its own
   - Have clearly defined inputs (what must exist before) and outputs (what it delivers)

2. Create `status/claude-progress.json` with the full milestone list:

```json
{
  "project": "<project-name>",
  "created_at": "<ISO-8601-timestamp>",
  "updated_at": "<ISO-8601-timestamp>",
  "spec_file": "docs/harness/specs/YYYY-MM-DD-<topic>-design.md",
  "milestones": [
    {
      "id": "milestone-1",
      "title": "<short title>",
      "description": "<what this milestone delivers>",
      "depends_on": [],
      "passed": false,
      "plan_file": null,
      "session_date": null,
      "notes": null
    }
  ]
}
```

Show the milestone list to the user and confirm before proceeding.

**If the file EXISTS (resuming a large project):**

1. Read it
2. Find the first milestone where `passed: false`
3. Confirm with user: "Next milestone is: **<title>** — <description>. Ready to write the plan for this milestone?"

### B2: Write the Session Plan

For the current milestone (the first `passed: false` entry):

1. Write a detailed `plan.md` for THIS MILESTONE ONLY using the Task Structure below
2. Save to `docs/harness/plans/YYYY-MM-DD-<milestone-id>.md`
3. Update `claude-progress.json`: set `plan_file` and `session_date` for this milestone

```json
{
  "plan_file": "docs/harness/plans/YYYY-MM-DD-milestone-N.md",
  "session_date": "YYYY-MM-DD"
}
```

4. Commit both the plan file and updated `claude-progress.json`

---

## Plan Document Format

Every plan — small or large — MUST start with this header:

```markdown
# <Milestone/Feature Name> Implementation Plan

> **Harness note:** This plan is executed via `claude-codex-harness:harness-execution` using the Orchestra / Executor / Reviewer architecture. Each task goes through Executor (TDD implementation) → Spec Reviewer (compliance check) → Code Quality Reviewer (adversarial review). Only Code Quality Review PASS closes a task.

**Goal:** [One sentence describing what this builds]

**Milestone ref:** [milestone-N from claude-progress.json, or "standalone" for small projects]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

---
```

## Task Structure

Each task in the plan follows this format exactly:

````markdown
### Task N: <Component Name>

**Files:**

- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py`
- Test: `tests/exact/path/to/test_file.py`

- [ ] **Step 1: Write the failing test**

```<language>
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

- [ ] **Step 2: Run test to verify it fails**

Run: `<exact command>`
Expected: FAIL with "<expected error message>"

- [ ] **Step 3: Write minimal implementation**

```<language>
def function(input):
    return expected
```

- [ ] **Step 4: Run test to verify it passes**

Run: `<exact command>`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add <files>
git commit -m "<type>: <description>"
```
````

## No Placeholders Rule

Every step must contain the actual content an engineer needs. These are **plan failures** — never write them:

- "TBD", "TODO", "implement later", "fill in details"
- "Add appropriate error handling" (without showing the code)
- "Write tests for the above" (without actual test code)
- "Similar to Task N" (always repeat the code — tasks may be read out of order)
- Steps that say what to do without showing how (code blocks required for all code steps)

## File Structure

Before defining tasks, list all files to be created or modified and their responsibilities:

```markdown
## File Structure

| File                    | Action | Responsibility              |
| ----------------------- | ------ | --------------------------- |
| `src/foo/bar.py`        | Create | Single sentence description |
| `tests/foo/test_bar.py` | Create | Tests for bar.py            |
| `src/foo/existing.py`   | Modify | What changes and why        |
```

## Self-Review

After writing the complete plan:

1. **Spec coverage:** Skim each requirement in the spec/milestone description. Can you point to a task that implements it? List any gaps.
2. **Placeholder scan:** Search for "TBD", "TODO", missing code blocks. Fix them.
3. **Type/name consistency:** Do method names, types, and property names match across tasks? A function `clearItems()` in Task 2 but `removeItems()` in Task 5 is a bug.

Fix issues inline.

## Execution Handoff

After saving the plan and self-review:

> "Plan complete and saved to `docs/harness/plans/<filename>.md`.
>
> Spec approved. I suggest we move to execution now. Continue? (yes/no)
>
> If yes, I'll use the Orchestra / Executor / Reviewer architecture: each task goes through Executor (implements with TDD) → Spec Reviewer (verifies requirements) → Code Quality Reviewer (adversarial verification). Only Code Quality Review PASS closes a task."

Wait for user confirmation before invoking `claude-codex-harness:harness-execution`.
