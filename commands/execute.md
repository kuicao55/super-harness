---
description: "Execute an existing plan using the Orchestrator / Executor / Reviewer architecture with TDD enforcement and optional Codex integration."
---

Invoke the `harness-entry` skill with context: this is a `/super-harness:execute` invocation.

Tell the user: "Starting harness execution with Orchestrator / Executor / Reviewer architecture. Each task goes through Executor (implementation with TDD) → Spec Reviewer (compliance check) → Code Quality Reviewer (adversarial review). Only Code Quality Review PASS closes a task."

Then immediately read and follow the `harness-entry` skill, passing the context that this is a `/super-harness:execute` invocation.
