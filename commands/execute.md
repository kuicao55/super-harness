---
description: "Execute an existing plan using the Orchestrator / Executor / Reviewer architecture with TDD enforcement and optional Codex integration."
---

## HARD-GATE (before any execution work)

Until Code Quality Review returns an explicit **PASS** for the current task, you MUST NOT:

- Edit application/source code, tests, or config yourself (no direct file edits on product code)
- Run Spec Review or Code Quality Review inline in the main session
- Skip Executor/Reviewer dispatch because the project is small or Codex is unavailable

You MUST:

- Dispatch Executor and both review stages via **Task/Subagent** or **Codex** (never implement or review as Orchestrator in this session)
- Ask the user to confirm the engine **every task, every stage** (Executor, Spec Review, Code Quality Review). If Codex is unavailable, still ask: proceed with Claude subagent only? (yes/no)
- Create **TodoWrite** on the first turn of execution and update it through each task and sub-step (Executor → Spec Review → Code Quality Review → post-task)
- Obtain explicit **SPEC_COMPLIANT** (or equivalent) and **PASS** from dispatched reviewers before marking a task complete

If you violate this gate, stop and re-run the task with proper dispatch. Do not claim completion.

---

## Pre-Execution Check

Before starting execution, check for an existing handoff document:

1. Look for the most recent file in `docs/harness/handoffs/`

2. If a handoff exists with **state = IN_PROGRESS or PLANNING**:
   > "Found an active session from a previous handoff:
   > - Status: **\<state\>**
   > - Milestone: **\<milestone_id\>**
   > - Task: **\<task_id or "not started"\>**
   >
   > Would you like to:
   > 1. Resume from the handoff (`/super-harness:resume`)
   > 2. Start fresh with a new plan (this will overwrite the previous handoff)

   Wait for user choice. If user chooses 1, route to `/super-harness:resume`. If user chooses 2, proceed with this execution.

3. If no handoff exists or state is MILESTONE_DONE/ALL_DONE:
   Proceed with normal execution.

---

Invoke the `harness:harness-entry` skill with context: this is a `/super-harness:execute` invocation.

Tell the user: "Starting harness execution with Orchestrator / Executor / Reviewer architecture. Each task goes through Executor (implementation with TDD) → Spec Reviewer (compliance check) → Code Quality Reviewer (adversarial review). Only Code Quality Review PASS closes a task."

Then immediately read and follow the `harness:harness-entry` skill, passing the context that this is a `/super-harness:execute` invocation.
