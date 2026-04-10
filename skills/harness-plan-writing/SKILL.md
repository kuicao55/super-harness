---
name: harness-plan-writing
description: "Implementation planning for super-harness. Creates milestone plans with TDD discipline. Every project must have at least one milestone — milestone is the structural foundation for long-term tracking."
---

# Harness Plan-Writing

Write implementation plans with full TDD discipline. All projects use milestone tracking — there is no "small project" exception. A milestone is the structural foundation for long-term tracking + short-term execution, regardless of size.

**Announce at start:** "I'm using the harness-plan-writing skill to create the implementation plan."

<HARD-GATE>
## Milestone ≠ Task

- **Milestone** = a deliverable chunk that can be completed in ONE session (contains 3-6 tasks). Every project has at least one milestone.
- **Task** = a single unit of implementation work (one file or a few closely related files). Tasks are steps WITHIN a milestone.
- **ONE plan = ONE milestone.** A plan document lists tasks, NOT milestones.
- If a single-session project has 6 pieces of work, that is 1 milestone with 6 tasks — NOT 6 milestones.
- Multiple milestones only exist when a project genuinely spans multiple sessions (e.g., "core engine" session + "UI layer" session).

**Wrong:** 6 milestones for a single-session project
**Right:** 1 milestone with 6 tasks for a single-session project
</HARD-GATE>

## Step 1: Project Scope Assessment

Before writing any plan, assess the milestone scope:

**Ask yourself (or confirm with the user if unclear):**

- How many implementation tasks does this project have in total?
- How many sessions will this project reasonably require?

**Milestone Splitting Rule:**

Every milestone should be completable within one session. Estimate:
- Each task needs ~1-2 Executor runs in the best case
- Account for failures and retries
- **Recommended: 3-5 tasks per milestone, up to 6 is acceptable**
- If a milestone has >6 tasks, suggest splitting into two milestones
- If a milestone has only 1 task, that is fine — every project must have at least one milestone

**Decision:**

| Condition | Action |
|-----------|--------|
| 1-6 tasks | One milestone is fine |
| >6 tasks | Split into multiple milestones |
| Unsure | Ask user: "Would you like to split this into multiple milestones?" |

Every plan represents ONE milestone. A project may have multiple milestones.

**All-Milestone Plans Rule:**

When a project has multiple milestones, you MUST write a plan for EVERY milestone in this session — not just the first one. After the brainstorm session, you have full context about the project. Once you /clear, that context is gone and you cannot write good plans. So:

1. Create ALL milestones in `claude-progress.json` (using `harness-milestone add` for each)
2. Write a plan file for EACH milestone (using the format below)
3. Link each plan to its milestone (using `harness-milestone set-plan`)
4. Only then invoke handoff

This ensures that when a milestone is complete and the user resumes, the next milestone's plan already exists and execution can start immediately — no re-planning needed.

---

## Step 2: Detect Project Name

Before initializing, determine the project name:

1. Try `git remote -v` — extract project name from the remote URL
2. Fall back to `basename "$(pwd)"` — use the directory name as-is
3. Confirm with user: "Project name detected as **\<name\>**. Use this? (yes/enter new name)"

This mirrors the logic in `harness-init` Step 3 so both skills behave consistently.

---

## Step 3: Initialize Milestones

**Use the `harness-milestone` script for all milestone operations.** Do NOT manually edit `status/claude-progress.json`.

1. Run: `harness-milestone init "<project-name>" --spec docs/harness/specs/YYYY-MM-DD-<topic>-design.md`

   Example: `harness-milestone init "PocketMon" --spec docs/harness/specs/2026-04-09-pocketmon-design.md`

2. Add the first milestone:
   ```
   harness-milestone add "<milestone-1 title>" --spec docs/harness/specs/YYYY-MM-DD-<topic>-design.md
   ```

3. If Step 1's assessment determined multiple milestones are needed, add them now:
   ```
   harness-milestone add "<milestone-2 title>" --spec docs/harness/specs/YYYY-MM-DD-<topic>-design.md
   # ... add as many as determined
   ```

4. Show milestone list: `harness-milestone list`

---

## Step 3b: Milestone Decomposition — MANDATORY USER GATE

<HARD-GATE>
**Do NOT write any plan file until this step is complete and user has confirmed the decomposition.**

You MUST break down each milestone into specific tasks and show the task count before writing any plan.
</HARD-GATE>

For each milestone, list the tasks it will contain. Present the full decomposition to the user for confirmation before proceeding.

**For each milestone:**

1. **List the tasks** for this milestone — be specific:
   ```
   Milestone 1: <title>
   - Task 1: <specific component>
   - Task 2: <specific component>
   ...
   Total: N tasks
   ```

2. **Enforce the 6-task limit:**
   - If any milestone has > 6 tasks: you MUST split it into two milestones before proceeding. Show the proposed split and ask for confirmation.
   - Recommended range: 3-6 tasks per milestone
   - Ask the user to confirm or adjust the decomposition.

**Present the full decomposition table:**

```
| Milestone | Task Breakdown | # |
|-----------|---------------|---|
| milestone-1 | Task 1, Task 2, ... | 5 |
| milestone-2 | Task 1, Task 2, ... | 4 |

Total: 2 milestones, 9 tasks
```

> "Here is the milestone breakdown. Please review and confirm before I write the plans."

**If user requests changes** — adjust the decomposition and re-present.

**Once confirmed:**

1. Run `harness-milestone add` for any newly created milestones
2. Proceed to Step 4

---

## Step 4: Write Plans for ALL Milestones

For EACH milestone (iterate through all milestones in order):

1. Write a detailed `plan.md` for THIS MILESTONE using the Task Structure below
2. Save to `docs/harness/plans/YYYY-MM-DD-<milestone-id>.md`
3. Link the plan to the milestone:
   ```
   harness-milestone set-plan <milestone-id> docs/harness/plans/YYYY-MM-DD-<milestone-id>.md
   ```
   Example: `harness-milestone set-plan milestone-1 docs/harness/plans/2026-04-09-milestone-1.md`
4. Commit: `git add docs/harness/plans/ && git commit -m "harness: plan for milestone-N"`
5. Move to the next milestone and repeat

**Only proceed to the Execution Handoff after ALL milestones have their plans written and linked.**

## Step 4b: Deprecate Old Plan (if re-planning)

If the milestone already has a `plan_file` in `status/claude-progress.json`, you are **re-planning** it. The old plan file must be deprecated to avoid confusion:

1. Read the old plan path from `status/claude-progress.json`
2. Check if the old file exists — if not, skip deprecation
3. If the old file exists:
   - Rename it: `mv old-plan.md old-plan.md.deprecated-YYYY-MM-DD`
   - Add deprecation header to the renamed file:
     ```markdown
     ---
     deprecated: YYYY-MM-DD
     replaced_by: docs/harness/plans/YYYY-MM-DD-<milestone-id>.md
     ---
     ```
   - Commit: `git add docs/harness/plans/ && git commit -m "harness: deprecate old plan for milestone-N"`

---

## Plan Document Format

Every plan — small or large — MUST start with this header:

```markdown
# <Milestone/Feature Name> Implementation Plan

> **Harness note:** This plan is executed via `harness-execution` using the Orchestrator / Executor / Reviewer architecture. Each task goes through Executor (TDD implementation) → Spec Reviewer (compliance check) → Code Quality Reviewer (adversarial review). Only Code Quality Review PASS closes a task.

**Goal:** [One sentence describing what this builds]

**Milestone ref:** milestone-N from claude-progress.json

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

## Execution Handoff — MANDATORY

<HARD-GATE>
After ALL plans are saved and self-reviewed, you MUST invoke `harness-handoff`. Do NOT proceed directly to `harness-execution`. The execution phase always starts in a fresh session (via `/super-harness:resume`) so the Orchestrator has clean context.
</HARD-GATE>

After saving ALL plans and self-review:

> "All plans complete and saved.
>
> Ready to move to execution. After confirming, I'll invoke handoff to clear the session context before starting execution.
>
> Proceed? (yes/no)"

Wait for user confirmation.

**If user confirms:**

1. Invoke `harness-handoff` with state=`PLANNING`:
   - milestone_id: first milestone id
   - task_id: null (no task started yet)
   - Next action: `/super-harness:resume` (which will route to harness-execution)

2. After the session clears, user must run `/super-harness:resume` to start execution.

**If user declines:**

- Save all plans and progress file
- User can resume later with `/super-harness:resume`
