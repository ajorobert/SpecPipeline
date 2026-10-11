.claude/agents/
Specialized subagent definitions (framework-owned, synced by setup.sh).
Each agent has its own context, system prompt, and tool permissions.

| Agent file | `name:` (matched by a skill's `subagent_type`) | `role:` |
|---|---|---|
| po.md | SpecKit PO Agent | po |
| architect.md | SpecKit Architect Agent | architect |
| lead.md | SpecKit Lead Agent | lead |
| backend-engineer.md | SpecKit Backend Engineer Agent | backend |
| frontend-engineer.md | SpecKit Frontend Engineer Agent | frontend |
| backend-qa.md | QA Backend Agent | backend-qa |
| frontend-qa.md | QA Frontend Agent | frontend-qa |
| security.md | Security Agent | security |

Frontmatter:
- `name:` and `role:` are read by the hooks — keep them stable. `skill-start.sh` maps the starting skill's
  `subagent_type` to the agent whose `name:` matches and records that agent's `role:` as the active role
  (`.specify/state/active-skill-role`). `validate-path.sh` maps a role to its file (`backend` →
  backend-engineer.md, `frontend` → frontend-engineer.md, otherwise `{role}.md`).
- `write_scope.deny` — project-relative globs the role may not Edit/Write. It is evaluated against the
  running skill's role, falling back to `.specify/state/session.yaml` `role` outside any skill
  (`.claude/skills/governance/status-model.md` → Active-skill role). An agent without `write_scope` has no deny set.
- `tool_scope.allow` — tools the agent uses.

Body sections: Role, Expertise, Commands You Run, Files You Write, Files You Read. Paths name the knowledge
homes in `.claude/skills/governance/profile.md` and the unit tree in `.claude/skills/governance/phase-layout.md`.

Ownership of the homes:
- architect — `specs/adr/**` (through sk.adr), `specs/domain/**`, `specs/openapi/**`, `specs/asyncapi/**`,
  `specs/knowledge-base.md`, the unit's `02-design/**`
- po — `intent.md`, `unit-brief.md`, the unit's `01-story/`
- lead — `03-plan/`, `planning-brief.md`, `promotion.md` and the promotion targets (sk.ship), `rollback-plan.md`
- engineers — each project's `{CodeRoot}`, `04-implementation/{Project}/`
- QA — runnable tests at the project's Test Layout, `05-test/{Project}/`, `06-uat/`
- security — `07-security-audit/`

Nobody edits `status.current` or a roll-up field by hand: transitions run through
`bash .claude/hooks/story-status.sh` or the Stop hook's `SK_RESULT:` handling.
