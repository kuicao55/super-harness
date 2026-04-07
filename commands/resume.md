---
description: "Resume a previous project session. Reads claude-progress.json to find the next incomplete milestone and picks up where you left off."
---

Invoke the `claude-codex-harness:harness-entry` skill with resume mode.

Tell the user: "Resuming harness session. Reading progress file to find where we left off..."

Then immediately read and follow the `claude-codex-harness:harness-entry` skill, passing the context that this is a `/harness:resume` invocation.
