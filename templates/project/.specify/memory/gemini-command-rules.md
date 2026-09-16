# Skill Rules
Apply on every sk.* skill.

## System-Level Context Loading
@imports in CLAUDE.md are not processed in this environment.
Explicitly read the following files at the start of every sk.* skill,
before any other work, if they exist:
1. `specs/guide.yaml` — Tier 1 system routing index
2. `specs/knowledge-base.md` — Tier 1 system knowledge base
3. `.specify/memory/command-rules.md` — skill rules and role behavior
4. `.specify/project-config.md` — project identity and overrides (if exists)

## Session Resolution
Every skill resolves context from .claude/session.yaml and the paths in
`.claude/skills/governance/phase-layout.md`.

Unit-level skills (sk.design and its sub-skills, sk.plan, sk.implement, sk.test, sk.uat, sk.security-audit):
- Require active_unit_id set in session.yaml
- If null: instruct user to run sk.session focus --unit {unit-id}

Story-level skills (sk.clarify, sk.architect-probe, sk.review, sk.investigate, sk.verify, sk.ship):
- Require active_story_id set in session.yaml
- If null: instruct user to run sk.session focus --story {story-id}

checkpoint_mode is read from `01-story/story.md` frontmatter — never from session.yaml.

## Test Routing
sk.test runs per impacted project and branches on the project type (not the session role):
- Backend → provider contract tests + integration tests + unit tests
- Frontend / Mobile → consumer contract tests + component tests (+ E2E where the platform runs it)

## Security Role
sk.security-audit runs as the Security Agent persona regardless of session role.

## Capability Packs
Load packs only as `.claude/skills/governance/pack-resolution.md` directs, from
`.specify/memory/skill-routing.md`. Never browse `.claude/skills/` to discover packs.

## Idempotency
- Artifact exists → [REFINE MODE] update, never overwrite
- Artifact missing → [CREATE MODE]
- Declare mode at start of every execution

## Post-Execution Memory Updates
sk.plan, sk.architecture → update service-registry.md, domain-model.md if changed
sk.datamodel             → update domain-model.md
sk.contracts             → update service-registry.md
sk.adr                   → update architecture-decisions.md index

## ADR Triggers
Suggest (never create without confirmation) when:
- Decision spans more than one service
- Real alternatives were considered
- Involves auth, payments, or security
- Consistency model changes (strong ↔ eventual, or introducing eventual consistency for the first time)
- New partitioning or replication strategy adopted for a service or collection

## PHR Triggers
Create automatically after:
- sk.architecture
- sk.implement when novel tradeoffs resolved

## Context Loading Order
For sk.implement, sk.test, sk.security-audit, sk.investigate:
1. Read session.yaml — know what you are doing
2. Read specs/guide.yaml (tier 1) — know where to look
3. Read specs/domains/{domain}/guide.yaml (tier 2) if exists — narrow to units
4. Read unit guide.yaml (tier 3) if exists — narrow to modules/files
5. Read specs/domains/{domain}/knowledge-base.md (tier 2) if exists — understand why
6. Read unit knowledge-base.md (tier 3) if exists — understand unit decisions
7. Then read code and detail files
Knowledge bases contain non-derivable context only.
They complement code reading — do not treat them as
a substitute for reading the actual implementation.

## Safety Restrictions (Pre-Tool Equivalents)
1. **No Direct Deletion:** Never directly delete files or use destructive shell commands (like `rm`, `del`, `Remove-Item`). If a file must be removed, use the archive workflow instead:
   `bash .claude/hooks/archive-file.sh "<relative-path>" "<reason for removal>"`
2. **Path Confinement:** All file modifications (edits/writes) MUST stay within the project root. Never attempt to read or modify external system directories (e.g., `/etc/`, `/usr/`, `C:\Windows`) or user home directories under any circumstances.
