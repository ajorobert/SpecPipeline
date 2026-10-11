# Unit Phase Layout
Framework-owned. The canonical artifact tree of a unit; commands refer here instead of restating paths.

```
specs/intents/{intent}/
├── intent.md
└── units/{unit}/
    ├── unit-brief.md               # sk.story — Impacted Projects table
    ├── knowledge-base.md           # unit notes: design decisions, pitfalls, candidate invariants
    ├── investigation-report.md     # sk.investigate
    ├── rollback-plan.md            # sk.implement, when a migration is written
    ├── promotion.md                # sk.ship — what moved to its home (governance/promotion.md)
    ├── 01-story/                   # sk.story
    │   ├── story.md                # front-matter: id, status.current, checkpoint_mode, tags[], *-status
    │   ├── requirement.md
    │   ├── acceptance-criteria.md
    │   └── jira.md                 # only when tracker-seeded
    ├── 02-design/                  # sk.design
    │   ├── architecture.md
    │   ├── impact-analysis.md      # per project + Sequencing & Dependencies
    │   ├── database-design.md
    │   ├── contract-changes.md     # change list for specs/openapi|asyncapi + compatibility + test plan
    │   ├── ui-model.md             # units with a Frontend/Mobile project
    │   └── projects/{Project}.md   # one per impacted project
    ├── 03-plan/{Project}/          # sk.plan
    │   ├── plan.md, tasks.md
    │   ├── estimation.md           # plan.estimates: true
    │   ├── jira-subtask.md         # tracker configured
    │   └── hotfix-plan.md          # sk.hotfix
    ├── 04-implementation/{Project}/  # sk.implement, sk.review
    │   ├── progress.md, delivery.md
    │   └── review.md
    ├── 05-test/{Project}/          # sk.test
    │   └── test-report.md
    ├── 06-uat/uat-report.md        # sk.uat — unit-level
    └── 07-security-audit/security-report.md   # sk.security-audit — unit-level
```

## Rules
- The unit folder holds in-flight work only. Contracts are edited in place in `specs/openapi/` and
  `specs/asyncapi/` (never copied into the unit); ADRs, domain specs and rules live in their homes
  (`governance/profile.md`). At ship, durable knowledge is promoted and the folder freezes
  (`governance/promotion.md`).
- One story per unit, at the fixed folder `01-story/`. The story ID (`{INTENT}-{UNIT}-{NNN}`)
  lives in `story.md` frontmatter, not in the path.
- `{Project}` folder names come from `unit-brief.md` → Impacted Projects; never invent or
  abbreviate them.
- Source code and runnable tests live under each project's `{CodeRoot}`, never under `specs/`.
- To locate the active story: `specs/intents/*/units/{active_unit_id}/01-story/story.md`. If no
  folder matches, scan `specs/intents/*/units/*/01-story/story.md` for frontmatter
  `id: {active_story_id}` (or `unit: {active_unit_id}`).
