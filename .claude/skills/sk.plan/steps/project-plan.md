# Step 1 — One project's plan
For `{Project}` (Type, Code Root from the Impacted Projects row). Outputs in `03-plan/{Project}/`:
`plan.md`, `tasks.md`; `estimation.md` when `plan.estimates: true` in the profile; `jira-subtask.md`
when `tracker.kind` is not `none`. A present plan is refined in place.

The slice: `02-design/projects/{Project}.md`, else this project's impact-analysis row plus architecture.md.
Plan only inside it — never work another project owns. A Frontend/Mobile project follows ui-model.md.
Tech-stack.md gives the commands and layout; the project rules give file placement (cite, never restate).

## plan.md
```
---
project: {Project}
type: {Backend | Frontend | Mobile}
code_root: {CodeRoot}
unit: {unit-id}
status: draft
---
# Plan: {Project}

## Approach
How this project realizes its design slice, and the decisions that shape it — each citing the design
section, ADR, rule or pack it follows. Link the design for scope, data, contracts and dependencies;
do not restate them.

## Sequence
Numbered build steps, following impact-analysis.md → Sequencing & Dependencies. Mark what is blocked on
another project or on shared configuration.

## Files Affected
| File | Action (new / modified) | Purpose |
Concrete paths inside {CodeRoot}. This table drives tasks.md.

## Definition of done
- [ ] checkable items: design approved and dependencies available; the project's rules and routed ADRs
  honoured (cited by name); security items of the design slice; tests green; contract operations match
  contract-changes.md; no change outside the slice.

## Risks and open questions
Only those that affect this project's execution.
```

## tasks.md
Build-order tasks grouped by the Sequence, together covering every Files Affected row and every
acceptance criterion this project owns:
```
- [ ] T07 [P] — Add the order summary read model
      files: {paths from Files Affected}
      acceptance: {the test or observable signal}
      depends: T03
      source: ADR-NNNN | principles §N | .claude/rules/{area}/{file}.md   (only when a source requires the task)
```
- `[P]` — may run alongside its `[P]` siblings in the same group: no shared file, no dependency between
  them. When in doubt, leave it off.
- `depends:` lists every blocking task; a task depending on a sibling in its group is never `[P]`.
- **No code yet in {CodeRoot}:** open the first group with one task per baseline the principles file's
  `## Baseline`, a routed ADR or a project rule requires of every project of this type, each with its
  `source:`. None required: say so. Skip what the project already has.

## estimation.md (when enabled)
`| Task | Estimate | Basis |` in one stated unit, a contingency line for the open risks, and a total.

## jira-subtask.md (when a tracker is configured)
One import-ready block per task: summary, scope and acceptance, component `{Project}`, and the parent key
from `01-story/jira.md` (or `{PARENT-KEY}`). A generated file only — no tracker call.
