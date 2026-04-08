# Anthropic Harness Engineering — Alignment & Improvement Proposal

## Status

Draft | 2026-04-08

---

## Reference Sources

This document analyzes the harness project against Anthropic's published principles for long-running agent systems:

1. **"Effective harnesses for long-running agents"** — Context Reset, external memory, performance maintenance
2. **"Harness design for long-running application development"** — GAN architecture, Planner/Generator/Evaluator separation

---

## Overview: The Three Core Pillars

Anthropic观察到，随着任务时长从10分钟延长到6小时，制约AI Agent的不再仅仅是模型能力，而是**上下文堆叠导致的"系统性疲劳"**。

| Pillar | Core Problem | Solution |
|--------|-------------|----------|
| **Context Reset** | 上下文堆叠导致"Context Anxiety"，模型变得敷衍、急于收尾 | 完全清空对话，Initializer Agent 封装交接文档 |
| **External Memory** | 对话历史不是可靠的状态存储 | 结构化文件（PROGRESS.md/CLAUDE.md）作为外部硬盘 |
| **GAN Architecture** | Agent的"病态乐观"导致自测盲点 | Planner/Generator/Evaluator 三角色强制分离 |

---

## Pillar 1: Context Reset — Alignment Analysis

### What the Article Recommends

- 当对话历史接近上下文窗口上限时，模型表现"焦虑感"：变得敷衍、省略细节、逻辑混乱
- **Context Reset**：与其使用摘要压缩（compaction），不如直接彻底清空当前对话
- **Initializer Agent**：将上一阶段的任务产物、当前进度、下一步计划封装成轻量级"交接文档"
- 新Agent拿着交接文档从零开始，无历史包袱

### Harness Project Status

| Mechanism | Status | Notes |
|-----------|--------|-------|
| Context Reset trigger | ❌ **Missing** | 无显式触发条件，无重置流程 |
| Initializer Agent | ❌ **Missing** | 无此角色定义 |
| Handoff document template | ⚠️ **Partial** | `harness:resume` 读取 `claude-progress.json` 和 activity log，但无结构化交接文档 |
| Zero-start guarantee | ⚠️ **Partial** | resume 时读取状态，但新会话仍有历史包袱 |

### Gap Analysis

**`harness:resume` 现有实现（harness-entry/SKILL.md 第 51-149 行）：**
- ✅ 读取 `claude-progress.json` 显示 milestone 进度
- ✅ 读取 activity log 展示最近活动
- ✅ 检查依赖项是否满足
- ✅ 根据 `plan_file` 是否存在决定路由

**缺失的关键机制：**
1. **无 Context Reset 触发条件** — 何时应该重置上下文？没有定义
2. **无 Initializer Agent** — 谁来封装交接文档？无此角色
3. **交接文档不够轻量** — `claude-progress.json` 是 milestone 级别，不包含"当前进度具体到哪一步"

---

## Pillar 2: External Memory — Alignment Analysis

### What the Article Recommends

- 将任务状态从对话历史中剥离，存放在**磁盘上的结构化文件**
- `PROGRESS.md` / `CLAUDE.md`：动态更新，Agent 每完成小步骤必须打勾并记录架构变更
- 充当 Agent 的"外部硬盘"：崩溃或需要重置时，Agent 只需读取文件即可瞬间恢复状态
- 比在几万字对话历史里翻找"我刚才改了哪个变量"高效得多

### Harness Project Status

| File | Status | Notes |
|------|--------|-------|
| `status/claude-progress.json` | ✅ **Exists** | Milestone 级别跟踪（好） |
| `logs/activity-*.jsonl` | ✅ **Exists** | 事后活动记录（好，但不够实时） |
| `docs/harness/plans/*.md` | ✅ **Exists** | 计划文件含 checkboxes（好，但只在任务级别） |
| `CLAUDE.md` (root) | ❌ **Missing** | 无架构文档文件 |
| `PROGRESS.md` (细粒度) | ⚠️ **Partial** | plan checkboxes 存在，但无实时外部状态更新要求 |

### Gap Analysis

**Harness 的外部状态是 milestone 级别的，但 Anthropic 要求的是 step 级别的实时外部状态。**

关键问题：`harness-execution/SKILL.md` 第 303-318 行描述了"Per-Step Todo Updates (Superpowers-style behavior)"，要求子步骤更新 TodoWrite，但这只是**内存中的 TodoWrite 列表**，不是**磁盘上的结构化文件**。

如果 Agent 崩溃，TodoWrite 状态丢失。下次 resume 时，只能回到"上一个完成的任务"，而不是"上一个完成的子步骤"。

---

## Pillar 3: GAN Architecture — Alignment Analysis

### What the Article Recommends

- AI Agent 存在严重的**"病态乐观"**倾向——总认为自己写的代码是完美的
- 三代理架构：
  - **Planner（计划者）**：拆解任务，制定 Sprint
  - **Generator（生产者）**：负责具体干活
  - **Evaluator（评估者）**：独立的怀疑论 Agent，只根据 PRD 和测试用例严格审计
- 核心逻辑：只有通过 Evaluator 审核的工作才会被记录到进度文件中

### Harness Project Status

| Role | Status | Notes |
|------|--------|-------|
| Planner | ✅ **Exists** | Orchestra 承担计划者角色 |
| Generator | ✅ **Exists** | Executor 承担生产者角色 |
| Evaluator | ✅ **Exists** | Spec Reviewer + Code Quality Reviewer 双层评估 |
| 评估结果强制入档 | ⚠️ **Partial** | HARD-GATE 要求 CQR PASS 才能关闭任务，但无 enforcement 检测 |

### Key Observation: Orchestra Violates Its Own HARD-GATE

`harness-execution/SKILL.md` 第 35-42 行：

```
ORCHESTRA MUST NEVER IMPLEMENT OR REVIEW CODE DIRECTLY.
EXECUTOR AND REVIEWER WORK MUST ALWAYS BE DISPATCHED TO A SUBAGENT OR CODEX.
If Orchestra edits code directly (instead of dispatching), that task run is invalid and must be re-run.
```

**但问题在于：没有人验证 Orchestra 是否遵守了这条规则。**

这正是 Anthropic 所说的"病态乐观"——系统规定了自己不能做什么，但没有机制检测是否遵守了规定。

---

## Proposed Improvements

### 10. Add Context Reset Mechanism

**Files to modify:** `hooks/session-start`, `commands/resume.md` (if exists), `skills/harness-entry/SKILL.md`

**New: Context Reset Trigger Rule**

Add to `harness-entry/SKILL.md`:

```
## Context Reset Trigger

When ANY of these conditions is true, Orchestra MUST trigger a Context Reset before continuing:

- Session has been running for more than [X] turns (configurable, default: 50)
- Current message count > [Y] in this session (configurable, default: 100)
- Observable Context Anxiety: Agent starts using vague language ("probably", "should work", "seems fine")
- Agent begins omitting implementation details or summarizing code instead of showing it

When triggered:
1. Do NOT attempt compaction (summarizing old context)
2. Instead: Write a full Handoff Document (see below)
3. Start a fresh session with the Handoff Document as sole context
4. The new session reads external state files independently
```

**Why:** Anthropic explicitly recommends Reset over Compaction. Compaction loses nuance; Reset preserves fidelity.

---

### 11. Create Initializer Agent Role

**New file:** `agents/initializer.md`

**Role definition:**

```markdown
---
name: initializer
description: "The Initializer Agent packages task state into a Handoff Document for Context Reset. Use when a session is about to reset or when resuming a long-running project."
model: inherit
---

# Initializer Agent

Your job is to create a lightweight, complete Handoff Document that allows a new Agent to resume work with zero context history.

## When to Invoke

- Context Reset is triggered (see Context Reset Trigger Rule)
- User invokes /harness:resume after a long gap
- First session start on a large project

## Handoff Document Structure

Create a file: `docs/harness/handoffs/<YYYY-MM-DD>-handoff.md`

```markdown
# Handoff Document — <project name>

**Created:** <ISO timestamp>
**Session:** <N> turns, <M> messages
**Reset reason:** [why this reset was triggered]

## Project State

- Active milestone: <id> — <title>
- Overall progress: <X>/<Y> milestones complete

## Current Task Status

**Task N:** <task name> (<status>)
- What was done: [concise summary]
- What's in progress: [what Executor was doing when reset triggered]
- What's left: [remaining sub-steps]

## Recent Architecture Changes

- [file]: [what changed and why]
- ...

## Open Issues

- BLOCKED items: [what's blocking what]
- Deferred items: [items noted but not implemented]
- Known bugs: [any active bugs in the codebase]

## Next Action

<specific next step> — <who does it (Orchestra/Executor/CQR)>
```

## Output

- Write the Handoff Document to disk
- Commit it: `git add docs/harness/handoffs/... && git commit -m "harness: handoff document"`
- Display the file path to the user as the "resume point"
```

**Why:** Provides the "fresh start with full context" that Context Reset requires. Without this, a reset is just a blind handoff.

---

### 12. Add细粒度PROGRESS.md Tracking

**Files to modify:** `skills/harness-execution/SKILL.md`

**Change:** Replace "Per-Step Todo Updates" with mandatory disk-writes to a `PROGRESS.md` file.

Add to `harness-execution/SKILL.md`:

```
## External State File (PROGRESS.md)

Every sub-step completion MUST be written to `docs/harness/progress/<milestone-id>-progress.md` on disk, not just kept in memory TodoWrite.

```markdown
# Progress — <milestone-id>

**Last updated:** <ISO timestamp>

## Current Task: Task N — <name>

- [ ] Executor dispatched
- [x] Executor completed — Status: DONE
- [ ] Spec Review dispatched
- [ ] Spec Review completed — Verdict: SPEC_COMPLIANT
- [ ] Code Quality Review dispatched
- [ ] Code Quality Review completed — Verdict: PASS

## Architecture Changes This Session

| File | Change | Reason |
|------|--------|--------|
| src/... | Added UserService | New module for auth |

## Open Items

- [BLOCKED] Task M — waiting on database schema migration
```

**Why:** This is the "external hard drive" Anthropic describes. If Agent crashes, resume，只需要读取这个文件即可恢复状态，不需要翻对话历史。
```

---

### 13. Add Orchestrator Enforcement Self-Check

**Files to modify:** `skills/harness-execution/SKILL.md`, `agents/orchestra.md` (if exists)

**Add to HARD-GATE section:**

```
### Orchestrator Self-Check (Before Dispatching)

Before each stage, Orchestra must verify its own compliance:

□ I have NOT edited any application code directly in this session
□ I have NOT run Spec Review or Code Quality Review inline
□ I am about to dispatch [Executor/Spec Reviewer/CQR], not do their work myself
□ I will update PROGRESS.md after this stage completes

If any check fails:
→ This session has violated HARD-GATE
→ Stop immediately and inform user: "Orchestra has violated its own enforcement rules. This run is invalid."
→ Offer: "Restart from the last verified checkpoint, or continue with manual oversight."

**Why:** The hardest constraint to enforce is the one the enforcer places on themselves. Without self-check, HARD-GATE is advisory.
```

---

## Alignment Summary

| Pillar | Harness Current | Gap | Improvement |
|--------|----------------|-----|-------------|
| **Context Reset** | Partial resume flow | No reset trigger, no Initializer Agent, no handoff doc | #10, #11 |
| **External Memory** | Milestone-level JSON | No step-level real-time file, no CLAUDE.md | #12 |
| **GAN Architecture** | Three roles exist | No Orchestrator self-check, HARD-GATE unenforceable | #13 |

---

## Open Questions

1. **Context Reset threshold:** What turn count or message count should trigger a reset? This is project/模型 dependent.

2. **Handoff Document storage:** Keep all handoffs, or only the latest per milestone? Keeping all enables "time travel" debugging.

3. **PROGRESS.md frequency:** Update on every sub-step, or batch at natural boundaries (after each stage)? Real-time = safer but more I/O.

4. **Orchestrator self-check:** Should this be a formal step that Orchestra announces, or a silent background check?

---

## References

### Harness Project
- Resume flow: `skills/harness-entry/SKILL.md`
- Progress management: `skills/progress-management/SKILL.md`
- Activity logging: `skills/activity-logging/SKILL.md`
- Execution flow: `skills/harness-execution/SKILL.md`

### Anthropic Articles (as described by user)
- "Effective harnesses for long-running agents" — Context Reset, external memory
- "Harness design for long-running application development" — GAN architecture
