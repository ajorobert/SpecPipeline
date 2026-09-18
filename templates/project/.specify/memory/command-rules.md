# Skill Rules

## Session
Every sk.* skill reads .claude/session.yaml for active focus (intent/unit/story IDs).
Session focus required for story/unit skills — run sk.session focus if null.
Roles: po | architect | lead | backend | frontend | backend-qa | frontend-qa | security.
sk.session start --role is optional; most skills self-assert their persona.

## Role Behavior

### Group A — Project-type driven (backend vs frontend)
sk.review, sk.investigate, sk.refactor, sk.perf
These branch on backend vs. frontend. They use the resolved project's type (`--projects` or the unit's
Impacted Projects); session role is the fallback when no project resolves.
Project type determines subagent_type: Backend → SpecKit Backend Engineer Agent; Frontend/Mobile → SpecKit Frontend Engineer Agent.

### Group B — Self-asserting (no session role needed)
sk.story (po), sk.design, sk.adr, sk.impact, sk.knowledge-base (architect),
sk.plan, sk.implement, sk.test, sk.ff, sk.hotfix, sk.ship, sk.rollback (lead),
sk.security-audit (security), sk.uat (frontend-qa), sk.migrate (backend)
Skill declares its own subagent_type — session role not consulted.
MUST NOT write session.yaml role field. MUST NOT prompt user to switch role.
Read session.yaml for active_intent_id, active_unit_id, active_story_id only.

### Group C — Self-asserting with defined default
sk.plan_sub_analyze → SpecKit Lead Agent
sk.verify → SpecKit Architect Agent

### Group D — Role-agnostic (no subagent)
sk.phr, sk.session, sk.init — no subagent_type, run inline in main conversation.

## Idempotency
Artifact exists → [REFINE MODE] update, never overwrite.
Artifact missing → [CREATE MODE] create from template.
Declare mode at start of every execution.

## Skills Architecture
sk.* skills live in .claude/skills/sk.*/ (framework-owned; synced by setup.sh).
Each skill has:
  SKILL.md  — frontmatter (name, description, subagent_type, inject_files, preconditions) + brief description
  prompt.md — full workflow
Shared blocks: .claude/skills/governance/ (phase-layout, preflight, project-resolution, review-gate,
pack-resolution, checkpoint-rules, quality-gates).

inject_files declares static file dependencies injected before agent execution.
Dynamic paths (01-story/story.md, 02-design/architecture.md) are resolved by the agent after reading session.yaml.
Capability packs are project-owned and loaded only through .specify/memory/skill-routing.md.
checkpoint_mode is read from the active story's frontmatter, never from session.yaml.
