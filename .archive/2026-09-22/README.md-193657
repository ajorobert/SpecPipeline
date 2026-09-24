# Intents
Hierarchy: Intent → Unit → Story (one story per unit)
Session focus tracked in .claude/session.yaml (local, gitignored)
Team work status tracked in 01-story/story.md frontmatter (`status.current`)

## ID Format
Intent code: CHK, AUTH, ORD (short uppercase)
Unit ID: {INTENT-CODE}-{UNIT-CODE} e.g. CHK-PAY
Story ID: {INTENT-CODE}-{UNIT-CODE}-{NNN} e.g. CHK-PAY-001 (stored in story.md frontmatter)

## Structure
Canonical tree: .claude/skills/governance/phase-layout.md

specs/intents/{NNN}-{intent-name}/
  intent.md
  units/
    {unit-name}/
      unit-brief.md            ← Impacted Projects table (drives every per-project phase)
      knowledge-base.md        ← tier-3 non-derivable context
      guide.yaml
      01-story/                ← sk.story: story.md, requirement.md, acceptance-criteria.md, jira.md
      02-design/               ← sk.design: architecture, impact analysis, database design, contracts/, projects/
      03-plan/{Project}/       ← sk.plan: plan.md, tasks.md, checklist.md, jira-subtask.md, estimation.md
      04-implementation/{Project}/ ← sk.implement: implementation.md, progress.md, validation.md
      05-test/{Project}/       ← sk.test
      06-uat/                  ← sk.uat
      07-security-audit/       ← sk.security-audit

## Team Coordination
sk.session list            ← kanban view of all stories
sk.session status          ← current session focus
Story status flow: draft → ready → in-progress → testing → review → verify → done → shipped
