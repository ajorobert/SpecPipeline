# Knowledge Homes and the Project Profile
Framework-owned block, referenced by path. It says where every kind of project knowledge lives, who
writes it, how a skill loads it, and which project facts come from `.specify/profile.yaml`.

## Principles
1. **One home per fact.** Each fact below has exactly one file. No skill keeps a summary, index copy or
   registry of a fact that lives elsewhere; it reads the home.
2. **The framework owns process; the project owns knowledge.** sk.* skills read and write the homes in
   the project's own format. They never impose a structure on a file that already has one.
3. **Load where the work happens.** Coding rules are path-scoped and load with the files they govern.
   Decisions stay in ADRs as prose. Only the active unit's folder is loaded from `specs/intents/`.

## The homes

| Fact | Home (fixed path) | Written by | Loaded by |
|---|---|---|---|
| Why the system exists, actors, domain map | `specs/knowledge-base.md` (tier 1, `@import`ed by CLAUDE.md) | sk.knowledge-base, promotion (sk.ship) | every session |
| Fixed core principles | `.specify/memory/constitution.md` | sk.init (team-stated only) | design, plan, review, verify |
| Architecture decisions | `specs/adr/NNNN-kebab-title.md` | sk.adr | through the index (below) |
| Which ADRs apply to which work | `specs/adr/adr-index.md` — a **router**: an ALWAYS block, task-signal blocks, loading rules | sk.adr (registers in the matching blocks) | every design / plan / review / verify / implement |
| Bounded contexts and their relations | `specs/domain/bounded-contexts.md` | sk.design_sub_architecture, sk.knowledge-base, promotion | design, plan, story (architect probe) |
| One context's rules, invariants, rationale (tier 2) | `specs/domain/{module}.md` | sk.design_sub_datamodel, sk.knowledge-base, promotion | the phase working in that module |
| HTTP contract (canonical) | `specs/openapi/{audience}.yaml` | sk.design_sub_contracts, on the feature branch | plan, implement, test, review, uat |
| Async contract (canonical) | `specs/asyncapi/{module}.yaml` | sk.design_sub_contracts | same |
| Entities and schema | the code | sk.implement | code reading |
| Projects: name, type, code root, role | `.specify/memory/projects/index.md` (the router) | sk.init | every per-project skill |
| One project's stack snapshot | `.specify/memory/projects/{Project}/tech-stack.md` | sk.init, refreshed by sk.plan when stale | plan, implement, test, uat, migrate |
| Coding rules | `.claude/rules/{stack}/<topic>.md` (Claude Code `paths:` frontmatter, < 200 lines each) | the team, promotion (sk.ship), sk.adr (when the user accepts) | Claude Code by path; implement / review / test read the stack folder |
| Capability packs (project skills) | `.claude/skills/<pack>/SKILL.md`, registered in the **Registry** table of `.claude/skills/README.md` | the team | `governance/pack-resolution.md` only |
| In-flight work | `specs/intents/{intent}/units/{unit}/` (`governance/phase-layout.md`) | the unit pipeline | the active unit only |
| Unit-local non-derivable context (tier 3) | `specs/intents/{intent}/units/{unit}/knowledge-base.md` | sk.knowledge-base, sk.review, sk.investigate | the active unit only |
| Prompt history | `history/prompts/{feature}/PHR-NNN-{date}.md` | sk.phr | on request |
| Per-developer runtime state | `.specify/state/` (session.yaml, active skill, audit log, tracker outbox) — gitignored | hooks, sk.session, `story-status.sh` | hooks, sk.session |

A home that does not exist yet is created by its writer the first time it has something to hold. A
reader that finds a home missing logs `{home} not present — skipped` and continues; it never creates a
placeholder.

## Precedence
On conflict, the higher source wins and the conflict is flagged in the skill's output:

`constitution.md` → ADRs (as routed by `adr-index.md`) → `.claude/rules/` → capability packs →
the unit's `02-design/` → existing code.

An ADR that disagrees with the code wins: the AI follows the ADR and reports the disagreement.

## Loading rules
- **ADRs.** Read `specs/adr/adr-index.md`. Load the ALWAYS block's ADRs, then the ADRs of every block
  whose signals match the work (story tags, the unit's text, the files in scope). Follow the index's
  own loading rules. Never glob `specs/adr/`.
- **Domain.** Read `specs/domain/bounded-contexts.md`, then only the `specs/domain/{module}.md` files of
  the contexts the unit touches (from `unit-brief.md` and `02-design/architecture.md`).
- **Contracts.** Read only the `specs/openapi/{audience}.yaml` / `specs/asyncapi/{module}.yaml` files the
  unit's change list (`02-design/contract-changes.md`) names, and only the operations it lists.
- **Rules.** For each project in scope, the stack folders mapped to it by `rules.stacks`. Claude Code
  already loads a rule when a matching file is opened; a skill reads the folder explicitly only when it
  must judge code against the rules (implement, review, test). No skill restates a rule.
- **Never loaded unless a human names it:** every glob in `knowledge.never_autoload`, and every shipped
  unit except the active one. `guard-read.sh` enforces this for Read/Grep/Glob with a path; a skill
  must not reach such a path by any other route (for example a repo-wide search whose hits it then opens).

## Writing rules
- Write into the home, in the home's existing format and sections. When a home file has no section
  that fits, add the smallest heading that does.
- A new `specs/domain/{module}.md` uses `knowledge.domain.template` (`default` =
  `{TEMPLATES_DIR}/artifacts/domain-template.md`; `none` = headings only as needed; a path = that file).
  Register the new module in `bounded-contexts.md` in the same change.
- A new rule file is self-contained, under 200 lines, carries `paths:` frontmatter, cites its ADR as
  provenance only (`Source: ADR-NNNN`), and never `@import`s anything.
- A skill never writes a home outside its row above. Durable knowledge produced by a unit reaches its
  home through promotion (`governance/promotion.md`).

## Profile keys
`.specify/profile.yaml` is project-owned (template: `{TEMPLATES_DIR}/project/.specify/profile.yaml`).
Every key is optional; an absent key means the default below. Read it once per skill run.

| Key | Default | Used by |
|---|---|---|
| `knowledge.never_autoload` | `[]` | guard-read.sh, every skill's loading |
| `knowledge.adr.exemplar` | `null` (framework ADR template) | sk.adr |
| `knowledge.adr.guard` | `true` | sk.adr, sk.verify |
| `knowledge.domain.template` | `default` | sk.design_sub_datamodel, sk.knowledge-base, promotion |
| `contracts.verify` | `null` | sk.design_sub_contracts, sk.test, sk.verify |
| `contracts.compat_rules` | `null` → `additive \| deprecating \| breaking` | sk.design_sub_contracts, sk.review |
| `contracts.codegen` | `null` | sk.implement_sub_scaffolding |
| `rules.stacks` | `backend: [Backend]`, `web: [Frontend]`, `mobile: [Mobile]` | implement, review, test, promotion |
| `skills.max_packs` | `8` | pack-resolution.md |
| `vcs.base_branch` | `dev` | sk.session, sk.ship |
| `vcs.hotfix_base` | `vcs.base_branch` | sk.hotfix |
| `vcs.create_branch` | `on-request` | sk.session |
| `vcs.branch` | `{kind}/{topic}` | sk.session, sk.hotfix |
| `vcs.commit` | `conventional` | sk.session end, sk.ship, sk.hotfix |
| `vcs.pr_title` | `[{ticket}] {Kind} / {title}` | sk.ship, sk.hotfix |
| `vcs.no_ticket` | `NO TICKET` | sk.ship, sk.hotfix |
| `tracker.kind` / `project` / `mode` / `transitions` | `none` / `null` / `mirror` / `{}` | `governance/tracker-mirror.md` |
| `install.scaffold_skip` | `[]` | sk.init (never creates a listed home) |
| `install.gemini` | `false` | setup.sh |

Placeholders in `vcs.*`: `{kind}` (`feature` \| `fix`), `{Kind}` (`Feature` \| `Fix`), `{topic}` (kebab
title), `{title}`, `{ticket}` (the story's `jira_id`, else `vcs.no_ticket`), `{story}` (story ID).
