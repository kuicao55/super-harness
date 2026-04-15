# super-harness 全面优化改进计划 v3.0

> 创建日期：2026-04-08
> 状态：待执行
> 版本目标：v2.0.2 → v3.0.0

---

## Context

super-harness v2.0.2 是一个强制执行 Orchestra/Executor/Reviewer 三角色分离的 Claude Code 插件。当前系统能验证**输出质量**（代码通过审查、测试通过），但无法验证**过程合规性**（TDD 循环是否真实执行、上下文是否健康、Orchestra 是否遵守了自己的 HARD-GATE）。

两份改进文档（`TDD-enforcement-improvements.md` 和 `Anthropic-Harness-Engineering-Improvements.md`）分别从不同角度识别了同一根本问题：**规则定义了但没有执行机制**（"病态乐观"）。

本计划将 12 项改进融合为 3 个执行阶段，按风险梯度排序：

- **阶段 1（内容添加）**：向已有文件添加内容，零回归风险
- **阶段 2（新建文件）**：创建新 Skill/Agent 文件，不影响现有流程
- **阶段 3（流程插入）**：在执行流中插入新决策点，需验证向后兼容性

---

## 改进条目索引

| ID  | 来源 | 优先级 | 描述 | 阶段 |
|-----|------|--------|------|------|
| T1  | TDD  | P1 | 在执行流中插入 TDD Process Audit 决策点 | 3 |
| T2  | TDD  | P1 | 新建 `harness-tdd-audit` Skill | 2 |
| T3  | TDD  | P2 | 扩展 Code Quality Reviewer 含 TDD 过程审查 | 1 |
| T4  | TDD  | P2 | 为 Executor 添加 PROCESS_VIOLATION 状态 | 1 |
| T5  | TDD  | P2 | Plan-writing 要求 TDD 证据字段 | 1 |
| T6  | TDD  | P3 | 添加合理化反驳表 (Rationalization Counter-Tables) | 1 |
| T7  | TDD  | P3 | 添加 Red Flags STOP 规则 | 1 |
| T8  | TDD  | P2 | 添加"证据先于声明"门控 | 1 |
| T9  | TDD  | P3 | 添加回归测试验证模式 | 1 |
| A1  | ANT  | P1 | 添加上下文重置触发规则 | 3 |
| A2  | ANT  | P1 | 新建 Initializer Agent（Handoff Document） | 2 |
| A3  | ANT  | P2 | 细粒度 PROGRESS.md + Orchestrator 自检 | 3 |

---

## 阶段 1：向已有文件添加内容（零风险）

### 目标文件清单

1. `skills/harness-tdd/SKILL.md`
2. `skills/harness-execution/executor-prompt.md`
3. `agents/executor.md`
4. `skills/harness-execution/code-quality-reviewer-prompt.md`
5. `agents/code-quality-reviewer.md`
6. `skills/harness-plan-writing/SKILL.md`

### TODO List — 阶段 1

- [ ] **1.1** `[T6]` 在 `skills/harness-tdd/SKILL.md` 末尾添加「合理化反驳表」章节
  - 列举常见 TDD 违规借口（"测试稍后再补"、"逻辑太简单不需要测试"等）
  - 每条借口对应一条强制反驳论据
  - 参照 superpowers 项目的 Rationalization Tables 格式

- [ ] **1.2** `[T7]` 在 `skills/harness-tdd/SKILL.md` 添加「Red Flags — STOP and Restart」章节
  - 定义触发立即停止的红旗场景（先写实现、测试在实现后创建、测试故意设计为通过等）
  - 每条红旗对应明确的重启指令

- [ ] **1.3** `[T9]` 在 `skills/harness-tdd/SKILL.md` 添加「回归测试验证模式」章节
  - 写入 Write→Pass→Revert→Fail→Restore→Pass 的六步验证序列
  - 说明每步的目的和预期输出

- [ ] **1.4** `[T8]` 在 `skills/harness-execution/executor-prompt.md` 和 `agents/executor.md` 添加「证据先于声明」门控
  - Executor 在报告 DONE 前，必须粘贴实际测试输出（非自述）
  - 格式：`TEST_OUTPUT: <实际命令输出>`
  - 无 TEST_OUTPUT 的报告视为无效，自动降级为 IN_PROGRESS

- [ ] **1.5** `[T4]` 在 `agents/executor.md` 和 `skills/harness-execution/executor-prompt.md` 添加 PROCESS_VIOLATION 状态
  - 定义：Executor 自行发现 TDD 顺序违规时使用
  - 格式：`Status: PROCESS_VIOLATION`
  - 触发条件：发现实现代码在测试文件之前创建、测试因为"方便通过"而设计
  - Orchestra 收到 PROCESS_VIOLATION → 强制重启该 Task，不进入 Spec Review

- [ ] **1.6** `[T3]` 在 `agents/code-quality-reviewer.md` 和 `skills/harness-execution/code-quality-reviewer-prompt.md` 扩展 TDD 过程审查
  - 新增攻击向量：「TDD Process」
  - 检查项：实现文件的 git 创建时间 vs 测试文件创建时间；测试是否为非 hollow 测试；每个公开函数是否有对应测试
  - TDD 过程违规 → 自动 FAIL（无 Minor 选项）

- [ ] **1.7** `[T5]` 在 `skills/harness-plan-writing/SKILL.md` 的 Task 格式中新增 TDD 证据字段
  - 每个 Task 必须含 `TDD_EVIDENCE:` 字段（写计划时填写预期证据格式）
  - 示例：`TDD_EVIDENCE: 运行 pytest tests/test_foo.py::test_bar 应先 FAIL，实现后 PASS`
  - Plan Reviewer 需检查此字段是否存在

### 阶段 1 验证

- 检查所有修改文件是否可正常被 Claude Code 读取
- harness-tdd Skill 内容人工审阅：合理化表、红旗规则、回归模式是否清晰
- executor-prompt 改动：确认 TEST_OUTPUT 要求不干扰现有报告结构

---

## 阶段 2：新建 Skill/Agent 文件（不影响现有流程）

### 新建文件清单

1. `skills/harness-tdd-audit/SKILL.md`（新 Skill）
2. `skills/harness-initializer/SKILL.md`（新 Skill）
3. `agents/initializer.md`（新 Agent 定义）

### TODO List — 阶段 2

- [ ] **2.1** `[T2]` 新建 `skills/harness-tdd-audit/SKILL.md`
  - **Skill 名称：** `harness:tdd-audit`
  - **触发时机：** Executor 报告 DONE 后，由 Orchestra 显式调用
  - **核心检查项：**
    1. 测试文件是否在实现文件之前（或同时）创建 → `git log --diff-filter=A -- <file>` 时间对比
    2. 第一次测试运行是否为 FAIL（检查 Executor 报告中 TEST_OUTPUT 是否包含 FAIL→PASS 序列）
    3. 测试覆盖率：公开接口是否全部有测试
    4. 测试是否为 hollow（仅 assert True / pass）
  - **输出格式：** `TDD_AUDIT: PASS | FAIL | CANNOT_VERIFY`
  - **CANNOT_VERIFY 处理：** 升级为 FAIL（默认不信任）
  - **引用：** `harness-tdd/SKILL.md` 中的合理化反驳表和红旗规则

- [ ] **2.2** `[A2]` 新建 `skills/harness-initializer/SKILL.md`
  - **Skill 名称：** `harness:initialize`
  - **触发时机：**
    1. 每个 Milestone 完成时自动调用
    2. Orchestra 连续执行超过 5 个 Task 后提示用户
    3. 用户手动调用 `/harness:resume`
  - **核心职责：** 将当前会话状态打包为 Handoff Document，然后触发 `/clear`
  - **Handoff Document 结构（写入 `docs/harness/handoffs/YYYY-MM-DD-HH-MM.md`）：**
    ```
    # Handoff Document — <timestamp>
    ## 当前 Milestone
    ## 已完成 Tasks（含 activity log 引用）
    ## 待执行 Tasks（含优先级）
    ## 失败/阻塞 Tasks（含阻塞原因）
    ## 活跃 Worktree 信息
    ## 下一步建议行动
    ## 重要决策记录
    ```
  - **重置流程：** 写入 Handoff Document → 提示用户确认 → `/clear` → 下一个 session 通过 `/harness:resume` 自动加载

- [ ] **2.3** `[A2]` 新建 `agents/initializer.md`
  - Initializer Agent 定义文件
  - 核心原则：Initializer 只读状态、不修改代码、不发出工程判断
  - 职责范围：读取 claude-progress.json + 最近 activity log + 当前 worktree 状态 → 生成 Handoff Document

- [ ] **2.4** 在 `skills/harness-entry/SKILL.md` 注册新 Skill 路由
  - 添加 `/harness:initialize` → `harness-initializer` 的路由条目
  - 添加 `/harness:tdd-audit` → `harness-tdd-audit` 的路由条目（通常由 Orchestra 内部调用，但支持手动触发）

### 阶段 2 验证

- 两个新 SKILL.md 文件格式符合现有 Skill 模板（含 frontmatter、Announce 语句、步骤列表）
- `agents/initializer.md` 格式与 `agents/executor.md` 一致
- `harness-entry/SKILL.md` 路由条目可正确触发新 Skill

---

## 阶段 3：在执行流中插入新决策点（需验证兼容性）

### 目标文件清单

1. `skills/harness-execution/SKILL.md`（插入 TDD Audit 决策点 + 上下文重置规则 + Orchestrator 自检）
2. `skills/harness-entry/SKILL.md`（插入上下文重置触发逻辑）
3. `skills/progress-management/SKILL.md`（添加细粒度步骤级追踪）

### TODO List — 阶段 3

- [ ] **3.1** `[T1]` 在 `skills/harness-execution/SKILL.md` 的 Per-Task Flow 中插入 TDD Audit 决策点
  - **位置：** Executor 报告 DONE 之后，Spec Review 之前
  - **新步骤（Decision Point 1.5）：**
    ```
    Decision Point 1.5: TDD Audit
    - 调用 harness:tdd-audit（传入 Executor 报告 + 文件列表）
    - TDD_AUDIT: PASS → 继续进入 Decision Point 2（Spec Review）
    - TDD_AUDIT: FAIL → Task 状态设为 PROCESS_VIOLATION，回退给 Executor 重做
    - PROCESS_VIOLATION 重做上限：2 次；超过 → 升级给用户决策
    ```
  - 更新 TodoWrite 步骤以包含 tdd-audit 子步骤

- [ ] **3.2** `[A1]` 在 `skills/harness-execution/SKILL.md` 添加上下文重置触发规则
  - **触发条件：**
    1. 当前 Milestone 的最后一个 Task 完成后 → 触发重置
    2. 连续执行超过 5 个 Task 后 → 提示用户是否重置
  - **重置流程：** Orchestra 调用 `harness:initialize` → 写入 Handoff Document → 等待用户确认 → 清除上下文

- [ ] **3.3** `[A1]` 在 `skills/harness-entry/SKILL.md` 更新 Resume 流程以加载 Handoff Document
  - Resume 时优先检查 `docs/harness/handoffs/` 目录
  - 若存在 Handoff Document：读取并展示上次 session 状态摘要
  - 将 Handoff 内容注入 Orchestra 的初始上下文

- [ ] **3.4** `[A3]` 在 `skills/harness-execution/SKILL.md` 添加 Orchestrator 自检机制
  - 在每个 Decision Point 之前，Orchestra 执行自检：
    ```
    ORCHESTRATOR SELF-CHECK（每个决策点执行）：
    □ 我是否正在编写或修改应用代码？（违反 HARD-GATE → 停止）
    □ 我是否正在执行本应由 Executor 完成的工作？（违反 HARD-GATE → 停止）
    □ 我是否跳过了上一个决策点？（违规 → 回退重做）
    □ 我是否收到了所有必需的报告（含 TEST_OUTPUT）？（不完整 → 要求重提交）
    ```
  - 自检失败 → 记录到 activity log，标记为 PROCESS_VIOLATION，停止当前 Task

- [ ] **3.5** `[A3]` 在 `skills/progress-management/SKILL.md` 添加细粒度步骤追踪
  - 在 `status/claude-progress.json` schema 中新增 Task 级别字段：
    ```json
    "current_task": {
      "id": "task-N",
      "title": "...",
      "step": "executor | tdd-audit | spec-review | quality-review | logging",
      "step_status": "pending | in_progress | passed | failed",
      "last_updated": "ISO-8601"
    }
    ```
  - 同时写入 `status/PROGRESS.md`（人类可读格式），每次步骤变更自动更新
  - PROGRESS.md 内容：Milestone 进度 + 当前 Task + 当前步骤 + 最近 5 条 activity 记录

### 阶段 3 验证

- 手动演练 Per-Task Flow：Executor → TDD Audit → Spec Review → Quality Review → Logging
- 验证 PROCESS_VIOLATION 路径：TDD Audit FAIL → Executor 重做 → 最终 PASS 或升级
- 验证重置流程：Milestone 完成 → Handoff Document 写入 → `/harness:resume` 正确加载
- 验证 Orchestrator 自检：模拟 Orchestra 试图直接编辑代码 → 自检捕获并停止

---

## 文件修改汇总

| 文件路径 | 修改类型 | 涉及改进 |
|---------|---------|---------|
| `skills/harness-tdd/SKILL.md` | 追加内容 | T6, T7, T9 |
| `skills/harness-execution/executor-prompt.md` | 追加内容 | T8, T4 |
| `agents/executor.md` | 追加内容 | T8, T4 |
| `skills/harness-execution/code-quality-reviewer-prompt.md` | 追加内容 | T3 |
| `agents/code-quality-reviewer.md` | 追加内容 | T3 |
| `skills/harness-plan-writing/SKILL.md` | 追加内容 | T5 |
| `skills/harness-tdd-audit/SKILL.md` | **新建** | T2 |
| `skills/harness-initializer/SKILL.md` | **新建** | A2 |
| `agents/initializer.md` | **新建** | A2 |
| `skills/harness-entry/SKILL.md` | 追加路由 + Resume 更新 | A2, A1 |
| `skills/harness-execution/SKILL.md` | 插入决策点 + 重置规则 + 自检 | T1, A1, A3 |
| `skills/progress-management/SKILL.md` | 扩展 schema + PROGRESS.md | A3 |

共涉及：**6 个已有文件修改** + **4 个新建文件** = **10 项文件操作**

---

## 版本更新

改进完成后，版本从 `v2.0.2` 升至 `v3.0.0`（Breaking: 执行流新增必须决策点）：
- 修改 `.claude-plugin/plugin.json`
- 执行 `scripts/bump-version.sh`
- 更新 `README.md` 中的架构图和技能列表

---

## 执行指引

执行时严格按 Todo 逐步完成，每完成一项立即更新状态（`[ ]` → `[x]`）。
阶段内各条目相互独立，可并行执行；阶段间串行，后一阶段依赖前一阶段完成。
