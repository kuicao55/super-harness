---
description: "Display the current project progress. Reads claude-progress.json and shows milestone status. Read-only — does not start or resume any workflow."
---

Read-only status display. Do NOT invoke any execution or planning skill.

1. Look for `status/claude-progress.json` in the current working directory.
2. If the file does not exist: Tell the user "No progress file found at `status/claude-progress.json`. This project may be a small single-session project (no progress tracking) or has not been started yet with `/super-harness:brainstorm` or `/super-harness:plan`."
3. If the file exists: Display a formatted summary:

```
## Harness Project Status

Project: <project name>
Created: <created_at>
Last updated: <updated_at>
Spec: <spec_file>

### Milestones

| # | Title | Status | Session Date | Plan File |
|---|-------|--------|--------------|-----------|
| 1 | ...   | ✅ passed | 2026-04-01 | path/to/plan.md |
| 2 | ...   | 🔄 in progress | 2026-04-02 | path/to/plan.md |
| 3 | ...   | ⏳ not started | — | — |

Progress: X/N milestones complete
```

4. After displaying, offer: "Would you like to `/super-harness:resume` the current milestone, or is there anything else you'd like to do?"

Do NOT automatically start any workflow. This command is read-only.
