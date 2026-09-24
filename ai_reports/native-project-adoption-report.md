# Native project adoption — decided changes for SpecPipeline

**Status:** decisions confirmed with the owner, point by point, 2026-09-22. **Implemented natively in framework v2.0.0 (2026-09-22):** the host shape is the framework's only layout; homes are fixed paths, and `.specify/profile.yaml` carries project facts only. Acceptance: `tests/hooks-test.sh`, `tests/install-test.sh`.
**Framework version examined:** `v1.0.0` (`2a7c2aa`; this working tree at `3f075cb` has an identical tree outside `ai_reports/`).
**Host examined:** `tagin-platform`, install PR #73 (branch `sdd-kit-install`, parked as draft until this plan ships).
**Companion evidence:** `tagin-platform/ai_reports/2026-09-21-speckit-install.md` (install account, 21 seams, smoke run).
**Host-side work** (the decisions' consequences inside tagin-platform) lives in that repo: `tagin-platform/ai_reports/2026-09-22-knowledge-layer-restructure-plan.md`. This file holds only framework changes and the contract a host must meet (§7).

File:line references are to this repository unless prefixed `host:`.

---

## 1. Why this exists

The v1.0.0 install into tagin-platform worked only because the host was patched in 17 places: pointer files, a
`project-config.md` that existed just to carry `adr_dir`, gitignore entries against re-created scaffolding,
CLAUDE.md prose contradicting the managed block, a pinned permission mode, and a generator copying the host's skill
registry into a second manifest. Each patch maps to one framework behaviour that hardcodes a location or convention.

The goal: **installation feels native, with no clash, and one place for each piece of information.** The review
went both ways. Where the host's method is better, the framework adopts it. Where the framework's is better, the
host adopts it. Where the host itself held duplicates, the host fixes them.

## 2. Principles the decisions follow

1. **One home per fact.** No summary copies, no pointer files, no generated second registries.
2. **The framework owns process; the host owns knowledge.** Where the host has an established home, format or
   method, the framework reads and writes that — through one project profile (§5).
3. **Keep what the framework does better:** the unit workflow for in-flight work, explicit loading by phase and
   signal, a machine-readable project router, enforced gates, and an always-loaded entry point.
4. **Load rules where the work happens.** Coding rules are path-scoped so Claude sees them exactly when editing
   matching files. Decisions stay in ADRs as prose.
5. **Humans-only content stays outside AI scope** unless a human points to it.
6. **The framework ships no architecture rules.** A project's fixed principles come from the project.

## 3. The sixteen decisions

The Framework column names the change in §6. Decisions that only affect the host (5b CONTRIBUTING, the ADR split, the domain-spec format) are carried out in the host repo.

| # | Topic | Decision | Framework |
|---|---|---|---|
| 1 | ADRs | **Host model:** `specs/adr/NNNN-kebab.md`, AI-first format, `adr-index.md` as a signal router. **Plus a drift guard:** fail if an ADR file isn't routed from the index, or the index routes a missing file. | A2 |
| 2 | Domain knowledge | **Home:** `specs/domain/{module}.md` + `bounded-contexts.md` — the only domain home. No `specs/domains/`, no central entity list, no tier-2 `guide.yaml`. **Content/template:** deferred to the owner's own plan (handled in the host repo). | A3, A4 |
| 3 | API contracts | **Canonical only.** Design edits `specs/openapi/{audience}.yaml` / `specs/asyncapi/{module}.yaml` on the feature branch; the gate reviews that diff. `02-design/` holds only a change list (operations added/changed/removed + ADR-0026 compatibility class). No `api-spec.json`, no `api-contract.md`. Verification is the host's check. | A5 |
| 4 | Service registry | **None.** The contract directories are the registry; the audience → SDK → app mapping is ADR-0014 + ADR-0017; the break check is ADR-0026's COMPAT rules. | A4 |
| 5 | Constitution & standards | **Keep `constitution.md` for the project's fixed core principles only** — content that never changes; may reference ADRs. No standards files: API/data/observability/coding bind to the host's rule files (decision 12). | A6, B1 |
| 5b | CONTRIBUTING | Its "Key invariants" list becomes pointers; the human workflow parts stay. | — |
| 6 | Tech stack | **Dated version snapshot:** `projects/{P}/tech-stack.md` records versions with "verified <date> against <manifest>", plus test layout, skip idioms, platform, E2E tooling (`none` allowed). No workspace-level `tech-stack.md`. | A7, G3, G4 |
| 7 | Skill registration | **One row + one allow.** One table in `.claude/skills/README.md`, one row per skill: Skill, Status, Defers to, Always, Signals, Phases, Applies to, Weight. No "Use when" column (the SKILL.md description is the trigger). No permission entry per skill — invoking a project skill needs no approval (verified 2026-09-22 in a fresh session with and without an allow rule). The framework reads this table directly; no `skill-routing.md`. | A7 |
| 8 | Review | **The framework keeps its own `sk.review`,** loading the host's skills through routing for `phase=review`, alongside the host's `/self-review-*` and `review-*-pr` flows. `gstack` is removed. The report stays at `04-implementation/{Project}/review-{story}.md`. | B2 |
| 9 | Branch/commit/PR | **Host conventions, from the profile:** base `dev`; branch `{feature\|fix}/<topic>`; conventional commits; PR title `[TDVP1-NNN\|NO TICKET] {Feature\|Fix} / <title>`. `sk.session` creates a branch only when asked; by default it records the current one. `sk.ship` and `sk.hotfix` take base and title from the profile. | C1, C2 |
| 10 | Entry point & overview | **`specs/knowledge-base.md` is the single overview** (why the system exists, actors), `@import`ed by CLAUDE.md. `system-context.md` is dropped (its slot binds to the knowledge base + project router). CLAUDE.md is a router only. | A4, D4 |
| 11 | Pack resolution | **Weighted and project-scoped.** Score = Weight × (3 × tag matches + 1 × context matches); negated mentions never count. Resolution runs per project: a frontend project never loads backend skills and vice versa; `any` rows are eligible everywhere; a multi-project phase gives each project its own share of the cap. Always rows come first, then the highest scores. Every score is logged. | A8 |
| 12 | Project memory & coding rules | **Router** `projects/index.md` + a role column; drop `project.md`; keep `tech-stack.md`. **Coding rules are path-scoped per stack** in `.claude/rules/{backend,web,mobile,api}/<topic>.md`, under 200 lines each. **ADRs are split:** decisions + rationale stay as prose; checkable rules move to rule files; rules cite ADRs as provenance only. | A6, A9 |
| 13 | Unit lifecycle | **Promote, then freeze.** At ship, knowledge the code can't give goes to its one home (ADR / domain spec / rule file). The unit folder stays, marked shipped and frozen, and is excluded from AI loading except while it's the active unit. Promotion is a ship gate. | A10 |
| 14 | Tracker | **The framework owns ID and status; Jira mirrors it** (one-way, on every transition; the Jira key is stored as `jira_id`). Framework-managed work is moved through the framework, not by editing Jira. | A11 |
| 15 | Gates | **Hook-enforced, fixed:** entry-independent preconditions, one status command that also drives the Jira mirror, `write_scope` kept, Windows paths fixed, delete guard on PowerShell. Tested in a real session on Linux and Windows. | E1–E5 |
| 16 | docs/architecture | **Humans only, outside all AI scope.** No AI loads it on its own: not the framework, not the host's skills. The AI opens a doc only when a human names it. The 20 "Conflicts with current code" notes stay there (accepted risk: where an ADR disagrees with the code, the AI follows the ADR). | A12 |

## 4. Host conventions the framework must adopt (tagin-platform, verified 2026-09-21)

| Concern | Convention | Source |
|---|---|---|
| ADR location & name | `specs/adr/NNNN-kebab-title.md`; numbers of deleted ADRs are not reused | host: `specs/adr/` |
| ADR format | `# ADR-NNNN: Title`, `## Status`, `## Rules`/`## Decision`, `## Context`, `## Consequences`, `## Alternatives rejected` | host: `specs/adr/0027-ai-skill-layer.md` |
| ADR index | `specs/adr/adr-index.md`: ALWAYS block + task-signal blocks + loading rules (a router, not a table) | same |
| Precedence (AI) | ADR → rules → skills → code (after decisions 12 and 16) | host: ADR-0027, to be amended |
| Domain home | `specs/domain/{module}.md`, `specs/domain/bounded-contexts.md` | host: ADR-0015 |
| HTTP contract | `specs/openapi/{admin,customer,vendor,webhooks}.yaml`, canonical; parity enforced by `SpecOpenApiParityTests` | host: ADR-0014 |
| Async contract | `specs/asyncapi/{module}.yaml` (documentation in V1) | host: ADR-0014 |
| Codegen | decided, **not implemented** (`tools/codegen/scripts/generate-all.sh` prints "not yet implemented") | host: code |
| Skill registry | `.claude/skills/README.md` (becomes the one table of decision 7) | host: ADR-0027 |
| Coding rules | `.claude/rules/{backend,web,mobile,api}/` (to be created, decision 12) | — |
| Humans-only | `docs/architecture/**` | host: knowledge map (to be amended) |
| VCS | base `dev`; `feature/<topic>`, `fix/<topic>`; conventional commits; PR titles `[TDVP1-NNN] Fix / …` | host: git history, merged PRs |
| Tracker | Jira `TDVP1` (mirror target) | host: PR titles |
| Host review | `/self-review-{backend,console,customer-portal,vendor}`; reports in `ai_reports/self-review/` | host: `CONTRIBUTING.md` |
| E2E / test runners | none on any surface; vendor-app has no runner | host: package.json files |
| Migrations | EF Core per module, `modules/{M}/TagIn.{M}.Infrastructure/Persistence/Migrations/`; no per-migration tests; forward-only not mandated | host: ADR-0007, code |
| Permission mode | none set by the team | host: `.claude/settings.json` |

## 5. The contract: one project profile

Replaces `.specify/project-config.md`'s `## Paths` block and every pointer file. Valid in single-project and
workspace mode. Every key is optional; an absent key means today's default, so greenfield projects see no change.
Values shown are tagin-platform's.

```yaml
# .specify/profile.yaml — PROJECT-OWNED. Binds SpecPipeline's slots to this repo's homes and conventions.
version: 1

knowledge:
  precedence: [adr, rules, skills, code]
  never_autoload:                               # the framework never reads these unless a human names a file
    - "docs/architecture/**"                    # decision 16: humans only
    - "specs/intents/**"                        # decision 13: frozen units; the active unit is exempt
  adr:
    mode: external
    dir: specs/adr
    filename: "{NNNN}-{kebab-title}.md"
    exemplar: specs/adr/0027-ai-skill-layer.md
    index: specs/adr/adr-index.md
    index_kind: router                          # register via the index's own blocks; never append a row
    guard: true                                 # decision 1: every ADR routed, every route resolves
  domain:
    kb: "specs/domain/{module}.md"
    index: specs/domain/bounded-contexts.md
    template: null                              # decision 2: owner's plan pending
  system_kb: specs/knowledge-base.md            # decision 10: the single overview, @imported
  constitution: .specify/memory/constitution.md # decision 5: fixed core principles only
  entities: code
  service_registry: none                        # decision 4

rules:                                          # decision 12: path-scoped coding rules, one folder per stack
  root: .claude/rules
  stacks:
    backend:  { projects: [backend] }
    api:      { projects: [backend] }           # specs/openapi/** + endpoint code
    frontend: { projects: [tagin-console, customer-portal, vendor-app] }   # platform-wide web + mobile conventions
    # web / mobile folders appear only when a rule applies to one kind of app alone

contracts:                                      # decision 3
  mode: external
  http: "specs/openapi/{audience}.yaml"
  async: "specs/asyncapi/{module}.yaml"
  design_record: change-list
  verify: "dotnet test src/backend/tests/TagIn.Architecture.Tests --filter SpecOpenApiParityTests"
  codegen: none

skills:                                         # decisions 7 and 11
  registry: .claude/skills/README.md
  table: Registry
  scoring: { tag: 3, context: 1, negation_aware: true, scope: per-project }
  max_packs: 8

projects:
  router: .specify/memory/projects/index.md     # name, type, code root, role
  tech_stack: "projects/{P}/tech-stack.md"      # decision 6: dated snapshot

vcs:                                            # decision 9
  base_branch: dev
  create_branch: on-request
  branch: "{kind}/{topic}"
  commit: conventional
  pr_title: "[{ticket|NO TICKET}] {Kind} / {title}"

tracker:                                        # decision 14
  kind: jira
  project: TDVP1
  mode: mirror                                  # framework is the record; Jira follows transitions

lifecycle:                                      # decision 13
  promote_on_ship: true
  after_ship: freeze

runtime:
  state_dir: .specify/state

install:
  scaffold_skip: [GEMINI.md]
  impose_permission_mode: false
```

## 6. Framework changes

### A. Slots and knowledge

| # | Change | Where today |
|---|---|---|
| A1 | **Profile file**, read by every skill, hook and setup.sh; written by `sk.init` in every mode. Mode detection stops keying on `project-config.md`: pre-creating it today flips a workspace into single-project `[UPDATE]`. | `templates/project/.specify/project-config.md:20`; `sk.init/prompt.md:14-28, 152-156, 369-371, 595-597`; `setup.sh:281-287, 311` |
| A2 | **ADR slot.** `sk.adr` takes dir, filename pattern, exemplar/template and index from the profile. With `index_kind: router`, it registers the new ADR in the matching signal block(s) by the index's own rules and never appends a table row. `create-adr.sh` takes the pattern instead of hardcoding `ADR-%03d-`. The 16 `inject_files` entries for `architecture-decisions.md` resolve to the index. **Guard (decision 1):** ship `scripts/check-adr-index.sh` (every `dir/*` routed from the index, every routed path exists), run by `sk.adr` after writing and by `sk.verify`; hosts may also run it in CI. | `sk.adr/prompt.md:7, 11, 17-23`; `scripts/create-adr.sh`; `templates/artifacts/adr-template.md:1`; `templates/artifacts/README.md:19`; `agents/architect.md:46`; `sk.knowledge-base/prompt.md:7`; 16 SKILL.md `inject_files` |
| A3 | **Domain slot.** Tier-2 path, index and template come from the profile; preflight, codegen, scaffolding, sk.adr, sk.knowledge-base and sk.design Phase 5 resolve it. No tier-2 `guide.yaml` when the host has none. A null template means the framework writes into the file's existing sections and never imposes its own structure. | `governance/preflight.md:19`; `sk.adr/prompt.md:32`; `sk.design/prompt.md:192`; `sk.implement_sub_codegen/prompt.md:19`; `sk.implement_sub_scaffolding/prompt.md:19`; `sk.knowledge-base/prompt.md:15, 43-52, 74`; `templates/artifacts/guide-template.yaml:19` |
| A4 | **Remove the memory summaries when bound:** `domain-model.md` (entities = code), `service-registry.md` (none), `system-context.md` (→ `system_kb` + router), `architecture-decisions.md` (→ ADR index). `sk.design_sub_datamodel` / `_contracts` / `_architecture` stop "updating" them; domain changes go into the owning domain file. The five memory-pointer skills are deleted: sk.* skills resolve slots themselves, and today those skills fire globally in non-SDLC work. | `sk.design_sub_datamodel/SKILL.md:3`; `sk.design_sub_contracts/prompt.md:22, 30, 73`; `agents/architect.md` Files You Write; `.claude/skills/{system-context,service-registry,domain-model,architecture-decisions,standards}/`; 23 + 21 + 37 references |
| A5 | **Contracts, external mode.** Design edits the canonical spec file(s) for the affected audience(s); `02-design/` gets a change list (operations + compatibility class). No `api-spec.json`, no `api-contract.md`. Plan, implement and test read the canonical file through the slot. Provider-test generation is replaced by `contracts.verify` when set. **The worst clash not yet hit in a smoke run:** today the contracts phase would fork the host's contract into an unchecked copy labelled "canonical". | `governance/phase-layout.md:27`; `sk.design_sub_contracts/prompt.md:14, 32, 50-56, 67, 72-77`; `sk.implement_sub_implementproject/prompt.md:27`; `sk.plan_sub_planproject/prompt.md:34`; `sk.test_sub_testproject/prompt.md:26`; 37 files mention `api-spec.json` |
| A6 | **Constitution = fixed principles only; standards come from rules.** `sk.init` asks for the project's fixed core principles, with no framework defaults (B1), and allows references to ADRs. Nothing changeable goes in: no versions, module lists or status. No `standards/*.md` files when `rules` is bound: API/data/observability/coding resolve to the stack's rule folder for the project in scope. Pack resolution's precedence comes from `knowledge.precedence`. | `templates/project/.specify/memory/constitution.md`; `templates/project/.specify/memory/standards/*`; `governance/pack-resolution.md:53-56`; `sk.init/prompt.md:196-248, 501-576` |
| A7 | **Read the host's registry directly.** Pack resolution and the story tag vocabulary read the one table named in `skills.registry` / `skills.table`. Columns: Always, Signals, Phases, Applies to, Weight. Delete the `skill-routing.md` template. Surfaces and migrations come from `projects/{P}/tech-stack.md` (Platform, E2E Tooling, and a new Migrations section). `tech-stack.md` accepts a dated snapshot per version and `none` values. | `governance/pack-resolution.md:23-50`; `templates/project/.specify/memory/skill-routing.md`; `sk.story_sub_specify/prompt.md:17, 118-124`; `sk.init/prompt.md:252-262, 456-481, 617-627`; Surfaces/Migrations readers: `sk.uat`, `sk.migrate:17`, `sk.rollback:19`, `sk.design:203`, `sk.design_sub_ui-design:24-27`, `sk.design_sub_contracts:24, 40`, `sk.test_sub_testproject:120` |
| A8 | **Weighted, project-scoped resolution (decision 11).** For each project in scope, separately: its Always rows first; then candidate rows whose Applies-to covers that project's type (or `any`), scored Weight × (3 × tag matches + 1 × context matches). A tag match is an exact story tag; a context match is a signal found in the working text, where negated mentions ("no", "without", "not") never count. The project's share of `max_packs` fills by score. The log lists every candidate with its score and reason. Replaces the table-order cut and whole-word prose matching. | `governance/pack-resolution.md:17-50` |
| A9 | **Know the rules home.** Implement, review, refactor and test read the project's stack rules (Claude Code also auto-loads them by path). Nothing in the framework restates them. The promotion step (A10) writes new coding rules there, following the host's rule-writing rule (self-contained, ADR cited as provenance only, never `@import`). | new; no `.claude/rules` awareness today |
| A10 | **Promote, then freeze (decision 13).** `sk.ship` gains a promotion step: system decisions → ADR via `sk.adr`; domain rationale → the domain file; new coding rules → the stack rules folder; or record "nothing to promote". `sk.verify` gates on it. The unit's status becomes `shipped` and the folder is read-only from then on; `never_autoload` keeps frozen units out of all loading except as the active unit. | `sk.ship/prompt.md`; `sk.verify/prompt.md`; `governance/quality-gates.md`; `governance/status-model.md` |
| A11 | **Jira mirror (decision 14).** Every status transition, through the single status command (E1), also transitions the linked Jira issue (`jira_id`) via the Atlassian MCP when `tracker.mode: mirror`. A failed mirror is reported and retried, never silently dropped. Framework IDs and `status.current` remain the record. | `hooks/lib-story.sh` (`sk_set_status`); `governance/status-model.md`; `sk.story` / `sk.session` Jira seeding |
| A12 | **Honour `never_autoload`.** No skill, agent or preflight reads a matching path unless a human names the file in the conversation. The framework has no `docs/` references today, so this is a guard for hosts, not a cleanup. | `governance/preflight.md`; agents' Files You Read |

### B. Remove opinions and leaks

| # | Change | Where today |
|---|---|---|
| B1 | **No architecture defaults in `sk.init`:** layering, one aggregate per command, no queries outside repositories, commandId-UUID dedup, outbox wording, JSON log fields, traceparent, RED metric names, `GET /health`, Problem Details, 4xx→WARN, forward-only migrations, `/v{n}`. Four of these contradict tagin ADRs, and the constitution outranks packs. Record only what the team names as fixed principles (A6). | `sk.init/prompt.md:93-131, 196-248, 507-576`; constitution template comments |
| B2 | **Remove `gstack`** from review, investigate, hotfix and ship (decision 8 keeps the framework's own review, without it). | `sk.review/prompt.md:4, 39, 118, 126`; `sk.investigate/prompt.md:4, 35, 44`; `sk.hotfix/prompt.md:74`; `sk.ship/prompt.md:4` |
| B3 | **Don't set `defaultMode: acceptEdits`** on install; `install.impose_permission_mode` defaults to false. | `templates/root/settings.speckit.json:13`; `setup.sh:152` |

### C. VCS conventions (decision 9)

| # | Change | Where today |
|---|---|---|
| C1 | `sk.session start` creates a branch only when asked, in `vcs.branch`'s pattern; by default it records the current branch. Branch parsing tolerates host branch names. | `sk.session/prompt.md:43-47, 65` |
| C2 | `sk.ship` and `sk.hotfix` take base, PR title and commit style from `vcs.*` and the ticket from `tracker.*`. Today ship uses `--base dev` and hotfix `--base main`. | `sk.ship/prompt.md:28-37`; `sk.hotfix/prompt.md:74` |

### D. Install hygiene

| # | Change | Where today |
|---|---|---|
| D1 | Scaffold only unbound slots, plus `install.scaffold_skip`. Today create-if-absent has no opt-out, so a declined file returns on every run. | `setup.sh:282-303` |
| D2 | Stop scaffolding files nothing reads: `auth_contract.md`, `observability-stack.md`, `standards/modules/README.md`, `command-rules.md` (framework reference docs belong in the framework dir; in project space, create-if-absent means they never update). | `templates/project/.specify/memory/*` |
| D3 | `GEMINI.md` and `gemini-command-rules.md` become opt-in. | `setup.sh:257` |
| D4 | Render the managed CLAUDE.md block from the profile: knowledge homes, ADR home, the `@import` of `system_kb`. It must never state a path the host has rebound. | `templates/root/CLAUDE.md` |
| D5 | `disableBypassPermissionsMode` goes under `permissions`; today it's written top-level and is inert. | `templates/root/settings.speckit.json:80`; `setup.sh:153` |
| D6 | README install steps: add the remote with `--no-tags`. | `README.md` |

### E. Gates and hooks (decision 15)

| # | Defect | Evidence (tagin) | Fix | Where |
|---|---|---|---|---|
| E1 | **Skill-matched hooks never fire on the primary path.** `/sk.*` expands as a command and orchestrators read sub-skill prompts, so there is no Skill call: no preconditions, no status transitions, no `.active-skill-role`. §6.1 tested with piped JSON only. | story session: 0 Skill calls; no `.last-skill` / `skill-audit.log` / `.active-skill-role`; status written by the model | `UserPromptSubmit` hook matching `^/sk\.`; orchestrators invoke sub-skills via the Skill tool; **one status command** in `lib-story.sh` that every skill calls, which also triggers the Jira mirror (A11) | `hooks/check-skill-preconditions.sh:25`; `hooks/post-skill.sh:17`; `settings.speckit.json` hooks |
| E2 | **`validate-path.sh` fails open on Windows.** Drive-letter paths skip the root guard and `write_scope`. | `C:\Windows\…\hosts`, `C:/Users/…` → exit 0; po + `D:\…\02-design\…` → exit 0; relative → exit 2 | Normalise `\`→`/`; treat `^[A-Za-z]:/` as absolute; `cygpath -m` when available | `hooks/validate-path.sh:50, 108`; `hooks/archive-file.sh:29` |
| E3 | E1 + E2 combine: without `.active-skill-role`, the plan's own recipe (po session → `/sk.design`) has its design writes blocked on POSIX, and they pass on Windows only through E2. | design session wrote `02-design/` as po | fixed by E1 | — |
| E4 | Runtime state under `.claude/` is refused under `acceptEdits`/headless. | "declined by the permission layer as a sensitive file" | `runtime.state_dir` (default `.specify/state/`, gitignored) | `hooks/lib-story.sh:16`; `hooks/log-cache-metrics.sh:39`; `setup.sh:184-202`; 57 files |
| E5 | The delete guard only matches Bash; `Bash(Remove-Item *)` targets the wrong tool. | hooks docs | matcher `Bash\|PowerShell`; deny `PowerShell(Remove-Item *)` | `settings.speckit.json:18`; `hooks/hooks.json:6`; `hooks/intercept-delete.sh` |

### G. `sk.init` adopts instead of interviewing

| # | Change |
|---|---|
| G1 | **Detect before asking:** scan for existing homes (ADR dir + index, domain dir, contract dirs, a skills registry, `.claude/rules`, `CONTRIBUTING.md`, branch and commit history) and propose a profile. The interview confirms it. |
| G2 | **Non-interactive mode** (`--answers <file>`). Today `sk.init` is interview-only and `disable-model-invocation`, so an agent cannot drive it. |
| G3 | **`none` is a valid answer** (E2E tooling, test runner, codegen), and `sk.test` / `sk.uat` handle it. |
| G4 | **Versions as a dated snapshot:** each version cites its manifest and verification date (decision 6). |

## 7. Host contract — what a host provides for a native install

The framework reads these shapes; a host produces them. tagin-platform is the first host and the fixture for §8.

| Contract | Shape the framework reads | Decision |
|---|---|---|
| Project profile | `.specify/profile.yaml` as in §5; every key optional | A1 |
| ADR home | `knowledge.adr`: dir, filename pattern, exemplar or template, index + `index_kind`; with `router`, every ADR file must be routed from the index and every route must resolve (checked by `check-adr-index.sh`) | 1 |
| Domain home | `knowledge.domain`: one file per context (`kb` pattern), an index file, optional template | 2 |
| Contracts | `contracts.http` / `contracts.async` patterns; optional `verify` command; `codegen: none` allowed | 3 |
| Overview & principles | `knowledge.system_kb` (the single overview, `@import`ed); `knowledge.constitution` (fixed principles only) | 5, 10 |
| Skill registry | **one table** in the file named by `skills.registry`, heading `skills.table`, one row per skill, columns in this order: `Skill` (backticked name = directory) · `Status` · `Defers to` · `Always` (comma-separated scopes or `—`) · `Signals` (comma-separated, lower case, or `—`) · `Phases` (subset of design, plan, implement, review, test, uat, perf, refactor, or `—`) · `Applies to` (`any` or Backend/Frontend/Mobile) · `Weight` (number, default 1) | 7, 11 |
| Coding rules | `rules.root` (e.g. `.claude/rules`) with one folder per stack named in `rules.stacks`, each mapped to projects; files carry Claude Code `paths:` frontmatter; the framework reads, never restates | 12 |
| Project router | `projects/index.md` columns: Project (link) · Type · Code Root · Role | 12 |
| Tech stack | `projects/{P}/tech-stack.md`: dated snapshot per version (manifest + date), Test Layout, Forbidden Skip Idioms, Platform, E2E Tooling (`none` allowed), Migrations section for schema owners | 6 |
| Humans-only paths | `knowledge.never_autoload` globs | 16 |
| VCS / tracker | `vcs.*`, `tracker.*` as in §5 | 9, 14 |

## 8. Definition of native (acceptance test)

Add a tagin-shaped fixture to the framework: an ADR dir + router index, a domain dir, contract dirs, a skills
registry table, `.claude/rules/`, `docs/architecture/`. Installing into it must satisfy:

1. **Host-side files after install are only:** `.specify/profile.yaml`, `.specify/memory/projects/**`,
   `.specify/memory/constitution.md`, and the host's CLAUDE.md section. No pointer files, gitignore workarounds or
   generators.
2. After `setup.sh`, `git status` shows only framework-owned paths, the CLAUDE.md managed region and the settings
   hook/deny merge. Nothing appears under `specs/domains/`, `history/adr/`, `.specify/memory/{domain-model,
   service-registry,system-context,architecture-decisions,skill-routing}.md` or `standards/`.
3. **Fresh-session smoke, on Linux and Windows,** intent → `sk.story` → `sk.design` through contracts → `sk.review`
   → `sk.ship` (dry run):
   - the precondition hook fires for a user-typed `/sk.design`; po cannot write `02-design/**` on either OS;
   - pack resolution logs per-project scores; a frontend project loads no backend skill; negated mentions select nothing;
   - `sk.adr` writes `specs/adr/0028-….md` in the exemplar's format, routes it in `adr-index.md`, and the guard passes;
   - contracts edits `specs/openapi/admin.yaml`, records a change list, and runs `contracts.verify`; no `api-spec.json`;
   - no file under `docs/architecture/` or a frozen unit is read unless the prompt names it;
   - every status transition mirrors to the Jira issue;
   - ship runs the promotion step and freezes the unit.
4. A second `setup.sh` run and a no-op `git subtree pull` stay byte-identical (already true in v1.0.0).

## 9. Suggested order

1. **E1, E2, E5** — the gates and path guard are bugs regardless of everything else, and the Jira mirror depends on E1.
2. **A1, then A5** — the profile first; then contracts, the worst clash still unhit.
3. **A2, A3, A4, A6, A7, A8, A9** — the slots, rules awareness and scoring; each removes a named host patch.
4. **A10, A11, A12** — lifecycle, tracker mirror, exclusion list.
5. **D, E4, B, C, G** — install hygiene, runtime state, opinions, conventions, init.
6. Host-side work runs in parallel in the host repo against §7; the tagin reinstall waits for steps 1–3.
