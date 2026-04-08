---
name: harness-plan-writing
description: "Scale-aware implementation planning for super-harness. Assesses project scope, manages claude-progress.json for large projects, and generates detailed session plan.md files following TDD discipline."
---

# Harness Plan-Writing

Write implementation plans with full TDD discipline. For large projects, manage cross-session milestone tracking via `claude-progress.json`. For small projects, produce a single plan.md using the standard superpowers approach.

**Announce at start:** "I'm using the harness-plan-writing skill to create the implementation plan."

## Step 1: Project Scope Assessment

Before writing any plan, assess the project scope:

**Ask yourself (or confirm with the user if unclear):**

- How many distinct features or components need to be built?
- How many implementation tasks are roughly required?
- Does this cross multiple modules, services, or layers?
- Will this realistically require more than one session to complete?

Every plan represents ONE milestone. A project may have multiple milestones.

**Decision:**

| Criteria                                                     | Classification |
| ------------------------------------------------------------ | -------------- |
| Single milestone, one session                                 | One milestone  |
| Multiple milestones, multiple sessions                       | Multi-milestone |

If unsure, ask the user: "Would you like to split this into multiple milestones? (yes/no)"

---

## Step 2: Initialize or Update Progress File

**If `status/claude-progress.json` does NOT exist (new project):**

1. Create `status/claude-progress.json` with initial structure:

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

2. Show milestone list to user and confirm before proceeding.

**If the file EXISTS (resuming a project):**

1. Read it
2. Find the first milestone where `passed: false`
3. Confirm with user: "Next milestone is: **<title>** — <description>. Ready to write the plan?"

---

## Step 3: Write the Plan

For the current milestone (the first `passed: false` entry):

1. Write a detailed `plan.md` for THIS MILESTONE using the Task Structure below
2. Save to `docs/harness/plans/YYYY-MM-DD-<milestone-id>.md`
3. Update `claude-progress.json`: set `plan_file` and `session_date` for this milestone
4. Commit: `git add status/claude-progress.json docs/harness/plans/ && git commit -m "harness: plan for milestone-1"`

---

## Plan Document Format

Every plan — small or large — MUST start with this header:

```markdown
# <Milestone/Feature Name> Implementation Plan

> **Harness note:** This plan is executed via `harness:harness-execution` using the Orchestrator / Executor / Reviewer architecture. Each task goes through Executor (TDD implementation) → Spec Reviewer (compliance check) → Code Quality Reviewer (adversarial review). Only Code Quality Review PASS closes a task.

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

**TDD_EVIDENCE:** `<expected evidence format — describe what TEST_OUTPUT should show at each step>`

Example: `TDD_EVIDENCE: Step 2 (RED): pytest tests/test_foo.py::test_bar should FAIL with AssertionError. Step 4 (GREEN): same command should PASS.`

Note: Plan Reviewer will verify this field is present and meaningful. An empty or placeholder TDD_EVIDENCE fails plan review.

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
> Ready to move to execution. After confirming, I'll invoke handoff to clear the session context before starting execution.
>
> Proceed? (yes/no)"

Wait for user confirmation.

**If user confirms:**

1. Invoke `harness:harness-handoff` with state=`PLANNING`:
   - milestone_id: current milestone id
   - task_id: null (no task started yet)
   - Next action: `/super-harness:execute --plan docs/harness/plans/<filename>.md`

2. After the session clears and user resumes, route to `harness:harness-execution`

**If user declines:**

- Save the plan and progress file
- User can resume later with `/super-harness:resume`
