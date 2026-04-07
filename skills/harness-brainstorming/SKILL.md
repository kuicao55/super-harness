---
name: harness-brainstorming
description: "Structured brainstorming for claude-codex-harness. Explores user intent, requirements and design before implementation. Use before any creative or feature work."
---

# Harness Brainstorming

Turn ideas into fully formed designs and specs through natural collaborative dialogue. This skill is adapted from superpowers:brainstorming for the Claude Code + harness workflow.

**Announce at start:** "I'm using the harness-brainstorming skill."

<HARD-GATE>
Do NOT invoke any implementation skill, write any code, scaffold any project, or take any implementation action until you have presented a design and the user has approved it. This applies to EVERY project regardless of perceived simplicity.
</HARD-GATE>

## Checklist

You MUST create a task for each of these items and complete them in order:

1. **Explore project context** — check existing files, docs, recent git commits
   1.5. **Offer visual companion** (if topic involves visual questions) — see `visual-companion.md`. Only start if topic is visual; skip for conceptual/textual questions.
2. **Ask clarifying questions** — one at a time, understand purpose/constraints/success criteria
3. **Scope assessment** — is this one project or multiple independent subsystems? If multiple, decompose immediately (see Scope Decomposition below)
4. **Propose 2-3 approaches** — with trade-offs and your recommendation
5. **Present design** — in sections scaled to complexity, get user approval after each section
6. **Write design doc** — save to `docs/harness/specs/YYYY-MM-DD-<topic>-design.md`
7. **Spec self-review** — scan for placeholders, contradictions, ambiguity, scope issues (fix inline)
8. **User reviews written spec** — ask user to review before proceeding
9. **Scale assessment** — briefly assess: single session or multi-session project? (feeds into plan-writing)
10. **Transition to plan-writing** — invoke `claude-codex-harness:harness-plan-writing`

## The Process

### Visual Companion

Before asking clarifying questions, consider: does this topic involve visual design, UI layout, or architectural diagrams that would benefit from a browser view?

- **Offer the visual companion** if the topic is visual: "This involves UI design/architecture diagrams. Would you like to see visual options in the browser? (yes/no)"
- Start the server with `skills/harness-brainstorming/scripts/start-server.sh --project-dir <project-path>`
- Follow the `visual-companion.md` guide for the interaction loop
- Fall back to terminal text for conceptual/textual questions even during a visual session

### Scope Decomposition

**Do this BEFORE detailed requirements exploration:**

- Check if the request describes multiple independent subsystems
- Signs of over-scoped requests:
  - "Build me X and also Y and also Z" (multiple distinct systems)
  - Each described component could be a standalone product
  - Dependencies between components are unclear
  - The scope feels like 3+ separate milestones

**When over-scope is detected, immediately:**

1. Flag it: "This request describes multiple independent subsystems. Before going deeper, let me help you decompose this."
2. Identify the systems: "I see at least N distinct components: [list them]"
3. Clarify dependencies: "Which of these must exist before others? Which can be built independently?"
4. Propose build order: "I suggest building in this order: 1→2→3, because [reason]"
5. Confirm: "Each will go through its own brainstorm → spec → plan → execute cycle. Does this structure make sense?"

Don't spend time refining details of Component B if Component A doesn't exist yet.

### Understanding the Idea

- Check current project state first (files, docs, recent commits)
- For appropriately-scoped projects, ask questions one at a time
- Prefer multiple choice questions when possible
- Only one question per message
- Focus on: purpose, constraints, success criteria

### Exploring Approaches

- Propose 2-3 different approaches with trade-offs
- Lead with your recommendation and explain why
- Present conversationally, not as a formal spec dump

### Presenting the Design

- Present design section by section — ask after each whether it looks right
- Scale each section to its complexity
- Cover: architecture, components, data flow, error handling, testing strategy
- Be ready to revise based on feedback

### Design Principles

- Break the system into units with one clear purpose and well-defined interfaces
- YAGNI ruthlessly — remove unnecessary features
- Smaller, well-bounded units are easier to implement and test

### Working in Existing Codebases

- Explore current structure before proposing changes
- Follow existing patterns
- Include targeted improvements only where they serve the current goal

## After the Design

### Write the Spec

Save to: `docs/harness/specs/YYYY-MM-DD-<topic>-design.md`

Spec document structure:

```markdown
# <Feature Name> Design

**Date:** YYYY-MM-DD
**Status:** Draft

## Goal

One sentence.

## Architecture

2-3 sentences about overall approach.

## Components

What are the main units? What does each do?

## Data Flow

How does data move through the system?

## Error Handling

What can go wrong and how is it handled?

## Testing Strategy

What will be tested and how?

## Out of Scope

What explicitly is NOT in this spec?
```

Commit the spec to git after writing it.

### Spec Self-Review

After writing, scan with fresh eyes:

1. **Placeholder scan:** Any "TBD", "TODO", incomplete sections? Fix them.
2. **Internal consistency:** Do sections contradict each other?
3. **Scope check:** Focused enough for a single plan, or needs decomposition?
4. **Ambiguity check:** Any requirement interpretable two ways? Pick one and be explicit.

Fix issues inline. No need to re-review after fixing.

### User Review Gate

Ask the user:

> "Spec written and committed to `<path>`. Please review it and let me know if you want to make any changes before we move to implementation planning."

Wait for response. If changes requested, make them and re-run the self-review. Only proceed when the user approves.

### Scale Assessment Handoff

Before invoking plan-writing, briefly note:

- Estimated number of features/components
- Whether this feels like a single-session or multi-session project
- Any obvious milestone boundaries if multi-session

This assessment is provided as context to `claude-codex-harness:harness-plan-writing`.

> "Spec approved. I suggest we now move to implementation planning. Continue? (yes/no)"

Wait for user confirmation, then **invoke `claude-codex-harness:harness-plan-writing`.**

## Key Principles

- **One question at a time** — never overwhelm
- **Multiple choice preferred** — easier to answer than open-ended
- **YAGNI ruthlessly** — remove unnecessary features
- **Explore alternatives** — always propose 2-3 approaches
- **Incremental validation** — present design, get approval before moving on
