---
description: "Start a new feature or project with structured brainstorming. Explores intent, requirements, and design before any implementation."
---

Ask the user for the exact feature/problem first:

> "这次要 brainstorm 的具体功能或问题是什么？请尽量描述目标、当前现象和期望结果。"

After the user provides context, invoke the `harness:harness-entry` skill with context: this is a `/harness:brainstorm` invocation and include the user's feature description.

Tell the user: "Starting harness brainstorming session. I'll help you explore your idea, refine requirements, and produce a design spec before any code is written."

Then read and follow the `harness:harness-entry` skill with that context.
