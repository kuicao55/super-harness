# Plan Document Reviewer Prompt Template

Use this template when dispatching a plan document reviewer subagent after writing a session plan.

**Purpose:** Verify the plan is complete, matches the spec/milestone description, and has proper task decomposition ready for GvE execution.

**Dispatch after:** The complete plan is written to `docs/harness/plans/`.

```
Task tool (general-purpose):
  description: "Review harness plan document for milestone N"
  prompt: |
    You are a plan document reviewer for the super-harness workflow.
    Verify this plan is complete and ready for GvE (Generator vs. Evaluator) execution.

    **Plan to review:** [PLAN_FILE_PATH]
    **Spec or milestone description for reference:** [SPEC_OR_MILESTONE_DESCRIPTION]

    ## What to Check

    | Category | What to Look For |
    |----------|------------------|
    | Completeness | TODOs, placeholders, incomplete tasks, missing steps, missing code blocks |
    | Spec Alignment | Plan covers all requirements from spec/milestone, no major scope creep |
    | Task Decomposition | Tasks have clear boundaries, steps are bite-sized (2-5 min each), actionable |
    | TDD Discipline | Every task has a failing-test step before implementation step |
    | Buildability | Could an engineer follow this plan without getting stuck? |
    | GvE Readiness | Are tasks scoped so Generator can implement one and Evaluator can review one? |

    ## Calibration

    **Only flag issues that would cause real problems during implementation.**
    An implementer building the wrong thing or getting stuck is an issue.
    Minor wording, stylistic preferences, and "nice to have" suggestions are not.

    Approve unless there are serious gaps — missing requirements from the spec,
    contradictory steps, placeholder content, missing code blocks, or tasks so
    vague they cannot be acted on.

    ## Output Format

    ### Plan Review

    **Status:** Approved | Issues Found

    **Issues (if any):**
    - [Task X, Step Y]: [specific issue] - [why it matters for implementation]

    **Recommendations (advisory, do not block approval):**
    - [suggestions for improvement]
```

**Reviewer returns:** Status, Issues (if any), Recommendations
