---
description: "Resume a previous project session. Reads handoff document to find the next incomplete milestone and picks up where you left off."
---

Invoke the `harness:harness-entry` skill with resume mode.

Tell the user: "Resuming harness session. Loading handoff document to find where we left off..."

Then immediately read and follow the `harness:harness-entry` skill, passing the context that this is a `/super-harness:resume` invocation.
