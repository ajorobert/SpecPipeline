# Knowledge Homes and the Project Profile
Framework-owned reference, for people and for `sk.init`. Commands do not load it: the loading rules they
need are in `governance/preflight.md`, and `context.sh` resolves the rest.

## Principles
1. **One home per fact.** Each fact below has one file. No command keeps a summary, index copy or registry
   of a fact that lives elsewhere.
2. **The framework owns process; the project owns knowledge.** Commands read and write the homes in the
   project's own format and never impose a structure on a file that already has one.
3. **Load where the work happens.** Rules load with the files they govern; decisions load through the ADR
   router; only the active unit is loaded from `specs/intents/`.

## The homes
| Fact | Home | Written by | Loaded |
|---|---|---|---|
| How decisions are made; fixed principles; the loading order | `.claude/rules/principles.md` (`knowledge.principles`) — a rule file with no `paths:` | sk.init (seed), the team | every session, by Claude Code |
| Architecture decisions | `specs/adr/NNNN-kebab-title.md` | sk.adr | through the router |
| Which ADRs apply to which work | `specs/adr/adr-index.md` — ALWAYS block, signal blocks, loading rules | sk.adr, sk.init | first read of every command |
| Coding and authoring rules | `.claude/rules/{area}/<topic>.md`, `paths:` front-matter, < 200 lines | the team, sk.ship promotion, sk.adr | by Claude Code when a matching file is read; review/verify by `context.sh` |
| Bounded contexts and their relations | `specs/domain/bounded-contexts.md` | sk.design, sk.init | story, design, plan |
| One context's rules, invariants, rationale | `specs/domain/{module}.md` | sk.design (data model), sk.ship promotion | the phase working in that context |
| HTTP / async contracts (canonical) | `specs/openapi/{audience}.yaml`, `specs/asyncapi/{module}.yaml` | sk.design, on the feature branch | only the operations a unit's change list names |
| Entities and schema | the code | sk.implement | code reading |
| Projects: name, type, code root, role | `.specify/memory/projects/index.md` | sk.init | `context.sh`, the hooks |
| One project's commands and layout | `.specify/memory/projects/{Project}/tech-stack.md` | sk.init | plan, implement, test, uat |
| Capability packs (project skills) | `.claude/skills/<pack>/SKILL.md` + the Registry table of `.claude/skills/README.md` | the team | `context.sh` (`governance/pack-resolution.md`) |
| In-flight work | `specs/intents/{intent}/units/{unit}/` (`governance/phase-layout.md`) | the pipeline | the active unit only |
| Unit notes | `units/{unit}/knowledge-base.md` | sk.design, sk.review, sk.investigate | the active unit only |
| Per-developer runtime state | `.specify/state/` (gitignored) | hooks, sk.session, story-status.sh | hooks, sk.session |

A home that does not exist yet is created by its writer when it first has something to hold.

## Precedence
On conflict the higher source wins, and the conflict is reported:
ADRs → `.claude/rules/` (the principles file first) → capability packs → the unit's design → existing code.
A specific decision beats a general principle; code that must differ from an ADR supersedes the ADR first.

## Projects
- `--projects <key>` selects one row of the unit's Impacted Projects: an exact project name, or a type
  alias — `api|backend`, `web|frontend`, `mobile` — when exactly one row has that type.
- A project is Backend, Frontend or Mobile. A library folder shared by several apps may be a project of its
  consumers' type, so every per-project session has one code root.

## Writing rules
- Write into a home in its existing format and sections; add the smallest heading that fits only when none does.
- A new `specs/domain/{module}.md` uses `knowledge.domain.template` (`default` = the framework template;
  `none` = headings as needed; a path = that file) and is registered in `bounded-contexts.md` in the same change.
- A new rule file is self-contained, under 200 lines, has `paths:` front-matter, cites its ADR only as
  `Source: ADR-NNNN`, and never `@import`s anything.
- A command writes only its own homes. Durable knowledge produced by a unit reaches its home through
  promotion at ship (`governance/promotion.md`).

## Profile keys
`.specify/profile.yaml` is project-owned (template `templates/project/.specify/profile.yaml`). Every key is
optional; an absent key means the default.

| Key | Default | Used by |
|---|---|---|
| `knowledge.never_autoload` | `[]` | guard-read.sh, every command |
| `knowledge.principles` | `.claude/rules/principles.md` | sk.init |
| `knowledge.adr.exemplar` | `null` (framework ADR template) | sk.adr |
| `knowledge.adr.guard` | `true` | sk.adr, sk.ship, verify-evidence.sh |
| `knowledge.domain.template` | `default` | sk.design, sk.ship |
| `contracts.verify` | `null` | sk.design, sk.test, verify-evidence.sh |
| `contracts.compat_rules` | `null` → `additive \| deprecating \| breaking` | sk.design, sk.review |
| `contracts.codegen` | `null` | sk.design (once per unit, after the contracts gate) |
| `rules.stacks` | `backend: [Backend]`, `web: [Frontend]`, `mobile: [Mobile]` | where sk.ship and sk.adr place a new rule |
| `skills.max_packs` | `8` | context.sh |
| `review.commands` | `{}` | sk.review |
| `plan.estimates` | `false` | sk.plan |
| `vcs.base_branch` | `dev` | context.sh, sk.review, sk.ship, sk.session |
| `vcs.hotfix_base` | `vcs.base_branch` | sk.hotfix |
| `vcs.create_branch` | `on-request` | sk.session |
| `vcs.branch` | `{kind}/{topic}` | sk.session, sk.hotfix |
| `vcs.commit` | `conventional` | sk.session, sk.ship, sk.hotfix |
| `vcs.pr_title` | `[{ticket}] {Kind} / {title}` | sk.ship, sk.hotfix |
| `vcs.no_ticket` | `NO TICKET` | sk.ship, sk.hotfix |
| `tracker.kind` / `project` / `mode` / `transitions` | `none` / `null` / `mirror` / `{}` | `governance/tracker-mirror.md` |
| `install.scaffold_skip` | `[]` | sk.init |
| `install.gemini` | `false` | setup.sh |

Placeholders in `vcs.*`: `{kind}` (`feature` | `fix`), `{Kind}` (`Feature` | `Fix`), `{topic}` (kebab
title), `{title}`, `{ticket}` (the story's `jira_id`, else `vcs.no_ticket`), `{story}` (story ID).
