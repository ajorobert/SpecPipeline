# Unit Phase Layout
Framework-owned block. It is the canonical artifact tree for a unit; every sk.* prompt refers here
instead of restating paths.

```
specs/intents/{intent}/
├── intent.md
└── units/{unit}/
    ├── unit-brief.md               # sk.story_sub_specify / sk.story_sub_architect-probe — Impacted Projects table
    ├── knowledge-base.md           # tier-3 KB (sk.knowledge-base, sk.review, sk.investigate)
    ├── guide.yaml                  # tier-3 routing index (sk.design)
    ├── planning-brief.md           # sk.plan — cross-project synthesis
    ├── investigation-report.md     # sk.investigate
    ├── refactor-plan.md            # sk.refactor (unit-scoped)
    ├── rollback-plan.md            # sk.rollback / sk.migrate --rollback
    ├── 01-story/                   # sk.story (po)
    │   ├── story.md                # frontmatter: id, status.current, checkpoint_mode, tags[], *-status
    │   ├── requirement.md
    │   ├── acceptance-criteria.md
    │   └── jira.md                 # only when Jira-seeded
    ├── 02-design/                  # sk.design (architect)
    │   ├── architecture.md
    │   ├── impact-analysis.md
    │   ├── database-design.md
    │   ├── api-contract.md
    │   ├── ui-model.md             # frontend units only
    │   ├── contracts/              # api-spec.json (canonical), test-plan.md, README.md
    │   └── projects/{Project}.md   # one per impacted project
    ├── 03-plan/{Project}/          # sk.plan → sk.plan_sub_planproject
    │   └── plan.md, tasks.md, checklist.md, jira-subtask.md, estimation.md
    ├── 04-implementation/{Project}/  # sk.implement → sk.implement_sub_implementproject
    │   ├── implementation.md, progress.md, validation.md
    │   ├── review-{story-id}.md    # sk.review (drives REFINE mode)
    │   └── perf-findings.md, perf-tasks.md   # sk.perf
    ├── 05-test/{Project}/          # sk.test → sk.test_sub_testproject
    │   └── Backend: unit-test.md, integration-test.md, contract-test.md
    │       Frontend/Mobile: component-test.md, contract-test.md
    ├── 06-uat/                     # sk.uat — flat, unit-level
    │   └── acceptance-result.md, user-flow-test.md, signoff.md
    └── 07-security-audit/          # sk.security-audit — flat, unit-level
        └── owasp-report.md, stride-review.md, dependency-scan.md, security-signoff.md
```

## Rules
- One story per unit, at the fixed folder `01-story/`. The story ID (`{INTENT}-{UNIT}-{NNN}`)
  lives in `story.md` frontmatter, not in the path.
- `{Project}` folder names come from `unit-brief.md` → Impacted Projects; never invent or
  abbreviate them.
- Source code and runnable tests live under each project's `{CodeRoot}`, never under `specs/`.
- To locate the active story: `specs/intents/*/units/{active_unit_id}/01-story/story.md`. If no
  folder matches, scan `specs/intents/*/units/*/01-story/story.md` for frontmatter
  `id: {active_story_id}` (or `unit: {active_unit_id}`).
