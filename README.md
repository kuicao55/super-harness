# claude-codex-harness

A Claude Code skill plugin for structured, long-running software development projects. Built on the philosophy of [superpowers](https://github.com/obra/superpowers) but adds cross-session progress tracking, mandatory activity logging, and a Generator vs. Evaluator (GvE) adversarial execution architecture with optional Codex integration.

**Mac / Claude Code only.** No cross-platform support.

---

## What This Plugin Does

| Feature                     | Description                                                                                                                                            |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Command-driven workflow** | `/harness:brainstorm`, `/harness:plan`, `/harness:resume`, `/harness:execute`, `/harness:status` — you control when each phase starts                  |
| **Cross-session progress**  | `status/claude-progress.json` tracks milestones across sessions for large projects. Each session creates its own plan.md.                              |
| **Activity logging**        | Every completed task is logged to `logs/activity-YYYY-MM-DD.jsonl`. Resume a session days later with full context.                                     |
| **Generator vs. Evaluator** | Every task goes through Generator (implement with TDD) → optional Codex review → Evaluator (adversarial attack). Only Evaluator PASS completes a task. |
| **Codex integration**       | Optional `/codex:review`, `/codex:adversarial-review`, and `/codex:rescue` prompts at each task's decision points. You decide per-task.                |

---

## Installation

### 1. Install this plugin

This plugin is distributed via [kuicao55/claude-plugins](https://github.com/kuicao55/claude-plugins), a central marketplace for all of kuicao55's Claude Code plugins.

| | |
|---|---|
| **Plugin name** | `claude-codex-harness` |
| **Marketplace** | `kuicao-plugins` |

**Step 1 — Add the marketplace** (one-time, inside a Claude Code session):

```
/plugin marketplace add kuicao55/claude-plugins
```

**Step 2 — Install this plugin:**

```
/plugin install claude-codex-harness@kuicao-plugins
```

> Tip: run `/plugin` to open the UI and browse all available plugins in the **Discover** tab.

**Step 3 — Reload:**

```
/reload-plugins
```

To manage the plugin later:

```
/plugin disable   claude-codex-harness@kuicao-plugins
/plugin enable    claude-codex-harness@kuicao-plugins
/plugin uninstall claude-codex-harness@kuicao-plugins
```

**Alternative: per-session load without installing**

Clone the repo, then launch Claude Code with `--plugin-dir`:

```bash
git clone https://github.com/kuicao55/claude-codex-harness.git
claude --plugin-dir ./claude-codex-harness
```

### 2. (Optional) Install Codex integration

To enable `/codex` commands:

```bash
# Install the official Claude Code plugin (run in claude code)
/plugin marketplace add openai/codex-plugin-cc
```

Requires a ChatGPT subscription. After installation, restart Claude Code — `/codex` commands are auto-discovered.

---

## Commands

| Command               | Phase     | Description                                  |
| --------------------- | --------- | -------------------------------------------- |
| `/harness:brainstorm` | Phase 2   | Start with idea exploration → design spec    |
| `/harness:plan`       | Phase 3   | Write implementation plan (scale-aware)      |
| `/harness:resume`     | Entry     | Resume a previous session from progress file |
| `/harness:execute`    | Phase 4   | Execute a plan with GvE architecture         |
| `/harness:status`     | Read-only | Display current milestone progress           |

---

## Workflow

### New small project (single session)

```
/harness:brainstorm
  → explore idea, propose approaches, write spec
  → (auto-transitions to) /harness:plan
  → scale assessment: "small project"
  → generate single plan.md
  → (auto-transitions to) /harness:execute
  → GvE execution: Generator → Codex? → Evaluator per task
```

### New large project (multi-session)

```
Session 1:
  /harness:brainstorm
  → spec written to docs/harness/specs/
  → /harness:plan
  → scale assessment: "large project"
  → status/claude-progress.json created with N milestones
  → plan for Milestone 1 generated
  → /harness:execute
  → GvE execution of Milestone 1's plan
  → Milestone 1 marked passed

Session 2:
  /harness:resume
  → reads claude-progress.json
  → finds Milestone 2 (passed: false)
  → generates plan for Milestone 2 (fresh session plan.md)
  → /harness:execute
  → GvE execution of Milestone 2's plan
  → Milestone 2 marked passed

... repeat for each milestone
```

### Resuming after interruption

```
/harness:resume
  → reads claude-progress.json
  → finds current milestone
  → checks plan file: exists? tasks done?
  → Case A: no plan → generate one
  → Case B: plan exists, partial → resume from next unchecked task
  → Case C: all tasks done but not passed → confirm or re-evaluate
```

---

## File Structure (in your project repo)

The harness creates these files in your project repo (not the plugin):

```
your-project/
  status/
    claude-progress.json        # Milestone tracker (large projects only)
  docs/
    harness/
      specs/
        YYYY-MM-DD-<topic>-design.md    # Design specs from brainstorming
      plans/
        YYYY-MM-DD-milestone-N.md       # Session plan for each milestone
  logs/
    activity-YYYY-MM-DD.jsonl   # Daily activity log
```

All of these should be committed to git.

---

## Generator vs. Evaluator Architecture

The core of `harness-execution`. For each task in a plan:

```
1. Generator subagent
   → Implements with TDD (failing test first, minimal code, verify pass)
   → Reports: DONE / DONE_WITH_CONCERNS / BLOCKED / NEEDS_CONTEXT

2. [If Generator BLOCKED and Codex available]
   → Ask user: use /codex:rescue?

3. [If Codex available]
   → Ask user: /codex:review, /codex:adversarial-review, or skip?
   → Codex findings passed to Evaluator as supplementary context

4. Evaluator subagent
   → Adversarial review: assume code is broken, prove otherwise
   → Checks: boundary cases, security, performance, spec compliance, test quality
   → Verdict: PASS or FAIL (with specific file:line issues)

5. If FAIL → back to Generator with specific feedback
   If PASS → log activity, update progress, next task
```

Only the Evaluator's PASS closes a task. No exceptions.

---

## Codex Integration

Codex is always optional and always user-driven:

| Mode                        | When shown             | What it does                                      |
| --------------------------- | ---------------------- | ------------------------------------------------- |
| `/codex:review`             | After Generator DONE   | Read-only second opinion on architecture/patterns |
| `/codex:adversarial-review` | After Generator DONE   | Aggressive hunt for bugs, security, performance   |
| `/codex:rescue`             | When Generator BLOCKED | Hand off stuck task to Codex for execution        |

The harness never auto-invokes Codex. It asks you at each task's decision point. If Codex is not installed, the prompts are silently skipped.

---

## Relationship to superpowers

This plugin does **not** modify superpowers. Both can be installed simultaneously.

| superpowers                    | claude-codex-harness                  |
| ------------------------------ | ------------------------------------- |
| Hook-triggered (session start) | Command-triggered (explicit)          |
| Single-session focus           | Multi-session milestone tracking      |
| Manual activity tracking       | Automatic JSONL activity log          |
| Single reviewer                | GvE: Generator + Evaluator separation |
| No Codex integration           | Interactive Codex decision points     |

The brainstorming and plan-writing phases are philosophically identical to superpowers (YAGNI, TDD, no placeholders, atomic steps, exact file paths). The execution phase is where this harness diverges significantly.

---

## Skills Reference

| Skill                           | Purpose                                    |
| ------------------------------- | ------------------------------------------ |
| `harness:harness-entry`         | Command routing, resume logic              |
| `harness:harness-brainstorming` | Phase 2: design spec creation              |
| `harness:harness-plan-writing`  | Phase 3: scale assessment, plan generation |
| `harness:harness-execution`     | Phase 4: GvE execution loop                |
| `harness:progress-management`   | CRUD for claude-progress.json              |
| `harness:activity-logging`      | Post-task JSONL logging                    |
| `harness:codex-integration`     | Codex setup and usage reference            |
