# Plan: Separate the SpecKit-SSD-SDLC framework from project skills, then deploy into tagin-platform

**Date:** 2026-09-15
**Status:** Approved plan — ready to execute in this repo (step 1), then in `tagin-platform` (steps 2–3)
**Supersedes:** the proposal on branch `origin/claude/framework-project-skills-separation-j5rc2e` (2026-08-23), which put project skills in a separate marketplace repo. This plan puts them directly in the project repo.
**Related analyses (reuse, do not redo):** `ai_reports/frontend-skills-audit.md`, `ai_reports/monorepo-adaptation-analysis.md`, `ai_reports/ai-native-sdlc-playbook-gap-analysis.md`, `.archive/**/SKILL_AUDIT.md`

---

## 1. Context

This framework is consumed by projects as a git subtree at `.speckit/`, followed by `bash .speckit/setup.sh` (rsync of `.claude/` into the project root) and `/sk.init`.

Over the last months the framework absorbed one project's tech stack. Today `.claude/skills/` holds two unrelated families:

| Family | Count | Lines | True owner |
|---|---|---|---|
| `sk.*` process skills + `governance/` + `design-principles/` + 5 memory-pointer stubs | 23 (+sub-skills) | ~6.4k | Framework |
| Capability packs (`backend-architecture`, `data-access-patterns`, `nextjs-patterns`, `react-native-patterns`, …) | 22 | ~5.9k | Project (tagIN stack: .NET 10, Wolverine, FastEndpoints, Keycloak, Strapi, Next.js, RN/Expo) |

Coupling that binds them (all confirmed by file reads):

1. A **"Step 0 — Capability Pack Selection" block duplicated 6×** (near-verbatim, ~30 lines each) in `sk.design/sk.architecture`, `sk.design/sk.datamodel`, `sk.design/sk.ui-design`, `sk.implement/sk.scaffolding`, `sk.implement/sk.codegen`, `sk.review`, plus condensed copies in `sk.refactor`, `sk.perf`, `sk.verify`, `sk.uat`. They route keywords to literal `.claude/skills/<pack>/SKILL.md` paths.
2. Root `CLAUDE.md` managed block carries a hardcoded `[STACK NOTE]` and a 45-line "Tech Stack Context Skills" table.
3. Six `sk.*` skills have stack facts in their **body**: `sk.ui-design`, `sk.uat`, `sk.test/sk.testproject`, `sk.migrate`, `sk.design/sk.contracts` (test-plan headings), `sk.init` (framework recommendation matrices).
4. `setup.sh` Phase 1 runs `rsync -a --delete` over the whole `.claude/`, so any project-owned skill, `.claude/commands/`, or `settings.json` customisation is destroyed on every framework update. This is the single largest blocker to project-owned skills.
5. Stack-specific memory shipped from the framework: `.specify/memory/auth_contract.md`, `.specify/memory/observability-stack.md`; leaks in `templates/artifacts/impact-analysis-template.md` (botched rename, `Lucent.*`) and `ui-model-template.md`; machine path in `.claude/settings.json` `additionalDirectories`.

The framework's own audits already state the target principle: **skills carry grammar (project-neutral how), project memory carries vocabulary (per-project what/where)**.

### Decisions taken

- Distribution stays **git subtree + setup.sh**. Plugin packaging is deferred; the layout is made plugin-ready.
- Scope is **separation + fix all known wiring defects**.
- The six stack-bound `sk.*` skills are **made generic** by externalising their facts to project memory.
- Project skills live **directly in the project repo**, copied from a committed `skills_archive/` folder in this repo.
- **Nothing opinionated stays in the framework.** `design-principles` (DDD/DDIA) and `accessibility-standards` move out with the packs. The framework is process only.
- `setup.sh` syncs **framework-owned paths only** and never reads, writes, or archives anything else under `.claude/`.

### Ownership model after the split

```
Tier 1  FRAMEWORK (subtree .speckit/, synced by setup.sh into fixed paths)
        .claude/skills/sk.*  .claude/skills/governance
        .claude/skills/{system-context,service-registry,domain-model,architecture-decisions,standards}
        .claude/agents/*  .claude/hooks/*.sh  templates/  scripts/
        Process only. No architectural opinion (no DDD/DDIA), no stack, no a11y standard.
Tier 2  PROJECT SKILLS (project repo, never touched by setup.sh)
        .claude/skills/<pack>/  .claude/commands/  .claude/skills/<anything not framework-owned>
        Seeded by copying from the framework's committed skills_archive/ folder, then customised.
Tier 3  PROJECT MEMORY (project repo, generated once by sk.init, then hand-edited)
        .specify/**  specs/**  history/**  CLAUDE.md outside the managed block  .claude/settings.json
```

The bridge between tiers is one new project-owned file, **`.specify/memory/skill-routing.md`**, which replaces every hardcoded pack path in the framework.

Target project for steps 2 and 3: **`tagin-platform`** (branch `dev`). It has no framework installed yet, but already has `specs/adr`, `specs/domain`, `docs/architecture`, `.claude/commands/self-review-*`, and a tuned `.claude/settings.json` that must survive installation.

---

## 2. Step 1 — This repo: separate and fix (new branch `feat/skills-separation` off `dev`)

### 1.1 Introduce the routing manifest contract

- Add `templates/project/.specify/memory/skill-routing.md` (starter, project-owned). Shape:
  - `## Always` table: `scope (project type Backend|Frontend|Mobile, or phase design|implement|review|test|uat) → skill path(s)`. This is where a project registers its "canonical SSOT" pack per project type and, if it wants one, a design-principles pack for the design phase.
  - `## By signal` table: `keywords/tags → skill path → phases (design|implement|review|test|uat|perf|refactor)`.
  - `## Surfaces` table: `surface name → project → framework → e2e tooling` (feeds sk.uat / sk.contracts / sk.ui-design).
  - `## Migrations` block: `migration layout, migration test layout, tool` (feeds sk.migrate).
  - Instructions header: paths are relative to project root; skills listed here are project-owned; the framework never lists packs.
- Add `.claude/skills/governance/pack-resolution.md` (framework-owned, loaded by path like `checkpoint-rules.md`): the single procedure "read `skill-routing.md`, match story `tags[]` + design keywords + impacted-project types, Read the selected SKILL.md files in the canonical inject order, log which packs were loaded". This is the one copy that replaces the six.
- `sk.init` (`prompt.md`): in `[NEW PROJECT]` and `[WORKSPACE INIT]` generate `skill-routing.md` from the interview (project types + declared frameworks), leaving `## By signal` empty with a comment telling the team to register their packs. `[UPDATE]` menu gets an item for it.

### 1.2 Decouple the `sk.*` skills

- Replace each of the six full "Step 0 — Capability Pack Selection" blocks and the four condensed variants with one line: *"Resolve capability packs per `.claude/skills/governance/pack-resolution.md`; phase = `<phase>`."* Files: `sk.design/sk.architecture/prompt.md`, `sk.design/sk.datamodel/prompt.md`, `sk.design/sk.ui-design/prompt.md`, `sk.implement/sk.scaffolding/prompt.md`, `sk.implement/sk.codegen/prompt.md`, `sk.review/prompt.md`, `sk.refactor/prompt.md`, `sk.perf/prompt.md`, `sk.verify/prompt.md`, `sk.uat/prompt.md`.
- `sk.migrate/SKILL.md`: remove `.claude/skills/data-access-patterns/SKILL.md` from `inject_files` (resolve via manifest instead); fix `preconditions` to `02-design/database-design.md`.
- `sk.design/sk.architecture`, `sk.datamodel`, `sk.contracts`, `sk.ui-design`: remove `.claude/skills/design-principles/SKILL.md` from `inject_files`; their quality bars that cite `[REQUIRED]`/`[Advisory]` DDD/DDIA rules become "apply the design-principles pack registered for phase `design` in `skill-routing.md`, if any". A project that does not want DDD/DDIA simply registers nothing.
- Externalise the six stack-bound bodies:
  - `sk.design/sk.ui-design`: replace "Next.js / React+Vite / React Native / Zustand / shadcn / TanStack / 'use client' / ISR" with references to the surface's framework from `skill-routing.md ## Surfaces` + `projects/{P}/tech-stack.md`; the framework-specific checklist moves into the project's frontend pack (step 2).
  - `sk.uat`: surface table becomes a loop over `## Surfaces` rows (tooling per row); keep the generic rule "mobile never uses browser tooling" as a manifest column, not prose.
  - `sk.test/sk.testproject`: replace "EF Core + Dapper paths", `tests/contract/...test.{ext}` conventions, and `.skip/xit/it.only/fdescribe` with "test layout and forbidden-skip idioms per `projects/{P}/tech-stack.md`"; add those two fields to the `tech-stack.md` template.
  - `sk.migrate`: `src/{service}/Migrations/` etc. → `## Migrations` block of the manifest; `{CodeRoot}` everywhere.
  - `sk.design/sk.contracts`: test-plan consumer headings `### web (Next.js)` etc. → one heading per row of the unit-brief Impacted Projects table.
  - `sk.init`: move the frontend-framework and TS-vs-JS recommendation matrices out of the prompt into `templates/reference/frontend-framework-guide.md` (read on demand); remove tool-name defaults ("MediatR", "Serilog", "Jaeger") in favour of "record what the user names".
- Strip project-example vocabulary from framework prompts: `MarketPlace.*`, `Lucent.API`, `Keycloak realm` examples in `sk.plan`, `sk.plan/sk.planproject`, `sk.implement`, `sk.implement/sk.implementproject`, `sk.uat`, `sk.story/sk.specify` (step 5b tag table becomes "tags come from `skill-routing.md ## By signal`"). Use `{Project}`, `{CodeRoot}`, `{IdP}` placeholders.
- Remove the dangling `.claude/skills/auth-patterns/SKILL.md` references in `sk.scaffolding` and `sk.codegen` (covered by the manifest now).
- Fix `sk.verify` to read the routing manifest, not `.claude/skills/CLAUDE.md Tech Stack Context Skills table`.

### 1.3 Move the packs into a committed `skills_archive/` folder

- Create `skills_archive/` at the repo root (committed, clearly named, **not** `.archive/`). It is the copy source for any project: `cp -r .speckit/skills_archive/<group>/<pack> .claude/skills/`. Layout:
  ```
  skills_archive/
    README.md                 # what these are, how to copy, the grammar-vs-vocabulary rule
    backend/                  # backend-architecture, backend-feature-patterns, api-endpoint-patterns,
                              # authorization-patterns, orchestration-patterns, integration-adapter-patterns,
                              # feature-management-patterns, infrastructure-wiring, design-code-review, observability-backend
    data/                     # data-access-patterns, caching-patterns, search-patterns, file-pipeline-patterns
    frontend/                 # nextjs-patterns, react-admin-patterns, react-component-patterns, zustand-state-management,
                              # frontend-design-system (+design-styles.md), observability-frontend, accessibility-standards
    mobile/                   # react-native-patterns
    design/                   # design-principles (DDD/DDIA)
    memory/                   # auth_contract.md, observability-stack.md (project vocabulary examples)
    skill-routing.example.md  # the tagIN routing manifest as a worked example
  ```
- `git mv` the 22 packs **plus `design-principles/` and `accessibility-standards/`** from `.claude/skills/` into the folders above. `governance/` (checkpoint rules, gates, pack resolution, shared blocks) stays: it is process, not opinion.
- `git mv` `.specify/memory/auth_contract.md` and `observability-stack.md` to `skills_archive/memory/`; this repo's own `.specify/memory/` keeps only empty skeletons.
- Add `templates/project/.specify/memory/observability-stack.md` and `auth-contract.md` as **empty skeletons with headings** so skills that reference them still resolve.
- `setup.sh` never copies `skills_archive/`; the README tells the project owner to copy what they want.

### 1.4 Rewrite `setup.sh` to sync framework-owned paths only

- Add a `FRAMEWORK_OWNED` list in `setup.sh` (also written to the project as `.claude/.speckit-manifest` with the VERSION, for humans and for `sk.adr`/`sk.phr` to find `.speckit/scripts`): `.claude/skills/sk.*`, `.claude/skills/governance`, the 5 pointer stubs (`system-context`, `service-registry`, `domain-model`, `architecture-decisions`, `standards`), `.claude/agents/<8 framework agents by file name>`, `.claude/hooks/*.sh`.
- Phase 1 = per-path `rsync -a --delete` **scoped to each owned path only**. `--delete` applies inside an owned path (so a file removed from `sk.story/` upstream is removed in the project) and to the `sk.*` namespace (a `sk.*` directory that no longer exists upstream is removed, since `sk.` is the framework's namespace). **Nothing else under `.claude/` is read, written, archived, or listed**: `settings.json`, `settings.local.json`, `commands/`, every non-`sk.*` skill, `session.yaml`, and any other file are the project owner's responsibility. No manifest-diff logic, no archiving of project files.
- `settings.json`: stop copying. Ship `templates/root/settings.speckit.json` holding only `hooks`, `permissions.deny`, `defaultMode`, `disableBypassPermissionsMode`. setup.sh merges it into the project's existing `settings.json` with `jq` (jq is already a hard requirement of every hook): hooks entries added if absent (matched on command string), deny entries unioned, `allow` never touched. Create the file if absent.
- `CLAUDE.md` / `GEMINI.md`: replace whole-file `cp` with **managed-region splice** between `<!-- SPECKIT-SSD-SDLC MANAGED -->` and `<!-- END SPECKIT-SSD-SDLC MANAGED -->`; content outside the markers is preserved. Phase 3 prompt stays but only for the region.
- `.specify/`, `specs/`, `history/`: change "skip if directory exists" to **create-if-absent per file/subdirectory** so a project that already has `specs/adr` still gets `specs/intents/`, `specs/knowledge-base.md`, `specs/guide.yaml`.
- Fix README/setup.sh branch inconsistency (`master` vs `main`): standardise on `main` and document `dev` as integration.
- Add `VERSION` file at repo root (start `1.0.0`), write it into `.claude/.speckit-manifest` and into the managed CLAUDE.md block; tag the release at the end of step 1.

### 1.5 Clean framework-shipped instruction files

- Root `CLAUDE.md` and `templates/root/CLAUDE.md`: single generic managed block. Remove `[STACK NOTE]`, remove the "Tech Stack Context Skills" table; keep `[PLACEHOLDER CONVENTION]` reworded generically; add "Capability packs are project-owned and registered in `.specify/memory/skill-routing.md`"; fix `Commands: .claude/commands/sk.*.md` and the retracted `command-rules.md` rule in the template. Keep it short (the original design rule was ~15 lines of instructions).
- `AGENTS.md`: rewrite as a 5-line router (`@CLAUDE.md` style). Current content references the deleted `.generic/` layer.
- `GEMINI.md` step 7: drop the reference to archived `.claude/hooks/post-command.md`.
- `.claude/settings.json` in this repo: reduce to the policy surface (hooks, deny, modes); move the ~45 machine-specific `allow` entries to `settings.local.json`; remove `additionalDirectories`; stop committing `cache-metrics.jsonl` and `settings.local.json` (already gitignored; `git rm --cached`).
- Templates: fix `templates/artifacts/impact-analysis-template.md` line 6 (pasted instruction in frontmatter) and `Lucent.*`/`MarketPlace.*` rows → `{Project}` placeholders; `ui-model-template.md` → remove Tanstack/Next.js mentions.
- `docs/memory-guide.md`: rewrite for the three-tier model; remove `state.yaml`.
- README: Quick Start gains "copy the packs you want from `skills_archive/` and register them in `skill-routing.md`"; artifact tree updated; upgrade FAQ notes that project skills survive.

### 1.6 Fix the known wiring defects (canonical decisions)

- **Story path.** Canonical: `specs/intents/{intent}/units/{unit}/01-story/story.md` (fixed phase folder, as the README documents). `sk.story/sk.specify` stops numbering `{NN}-story`. Replace legacy `stories/{story-id}/…`, `story-{ID}.md`, `units/{unit}/architecture.md`, `data-model.md`, `tasks.yaml` in the 19 skills still using them (`sk.review`, `sk.investigate`, `sk.hotfix`, `sk.rollback`, `sk.migrate`, `sk.perf`, `sk.refactor`, `sk.verify`, `sk.ff`, `sk.session list`, `sk.ship` preconditions, `sk.implement`/`sk.test` mixed usage) with the phase-folder paths. Update `specs/intents/README.md` (still documents the old layout).
- **Hooks.** `check-skill-preconditions.sh`, `post-skill.sh`, `post-response.sh`: glob `specs/intents/*/units/${ACTIVE_UNIT_ID}/01-story/story.md` (resolve via `active_unit_id`, fall back to scan); status writes handle the **nested** `status.current` / `status.entered_at` that `story-template.md` defines (awk block update, not `sed '^status:'`).
- **checkpoint_mode.** Single source of truth = story frontmatter (written by `sk.specify`). Every skill that says "read `checkpoint_mode` from session.yaml" changes to "read it from the active story's frontmatter"; `check-skill-preconditions.sh` already reads nested story fields, so wire `checkpoint_mode` into it for `sk.implement`/`sk.ship` gates. Remove `checkpoint_mode: standard` from `sk.ff` (undefined value).
- **session.yaml.** Reconcile the role enum to one list (`po|architect|lead|backend|frontend|backend-qa|frontend-qa|security`) across `setup.sh` heredoc, `sk.session`, `sk.uat`, agents; add `story_id`/`jira_id` that `sk.session start` already writes.
- **Governance drift.** `governance/checkpoint-rules.md`, `quality-gates.md`, `docs/memory-guide.md`: `state.yaml` → story frontmatter/session.yaml; `.specify/intents/` → `specs/intents/`; `sk.specify` → `sk.story`; gate items reference the 7-phase artifacts (`03-plan/{P}/tasks.md`, `07-security-audit/*`), not `tasks.yaml`/`security-audit.md`. Remove `sk.office-hours`, `sk.plan-eng-review`, `sk.qa` from `sdlc-flow` text if still present.
- **Agents.** `write_scope.deny` globs in all 8 `.claude/agents/*.md` → phase-folder paths (`**/02-design/**`, `**/03-plan/**`, …) so `validate-path.sh` binds again; align WCAG wording to 2.2 AA.
- **Dead skills.** Archive `sk.plan/sk.planstory` and `sk.implement/sk.tasks`; remove their references in `sk.verify` and `quality-gates.md`.
- **Script paths.** `sk.adr/prompt.md`, `sk.phr/prompt.md`: `.your-layer/scripts/…` → `.speckit/scripts/…` (setup.sh does not copy `scripts/`; make the skills resolve the framework dir from `.claude/.speckit-manifest`). Add an `adr_dir` override in `project-config.md` while touching `sk.adr` (tagin-platform keeps ADRs in `specs/adr/`).
- **check-system-prompt-files.sh**: list only files actually `@import`ed by the managed block (`specs/knowledge-base.md`) plus `CLAUDE.md`.
- Malformed blank `inject_files:` values in `sk.clarify`, `sk.tasks`, `sk.investigate` → `inject_files: []`.

### 1.7 Deduplicate shared prompt blocks (low risk, do after 1.6)

- Extract the 3× "Project Resolution" block, the 4× "Output Layout" tree, the ~10× "Pre-flight" block and the 5× "Review Gate" protocol into `.claude/skills/governance/{project-resolution,phase-layout,preflight,review-gate}.md`, referenced by path from the orchestrators (`sk.plan`, `sk.implement`, `sk.test`, `sk.uat`, `sk.security-audit`, `sk.design`, `sk.analyze`).

### 1.8 Plugin-readiness (no behaviour change)

- Keep every framework-owned asset under paths that map 1:1 to a future plugin layout (`skills/`, `agents/`, `hooks/hooks.json`). Hooks already take their path from `$CLAUDE_PROJECT_DIR`; add a `hooks/hooks.json` mirror of the settings hooks block so a later `plugin.json` is a pure packaging step. Do **not** add `.claude-plugin/` yet.
- Where cheap, adopt native SKILL.md fields alongside the custom ones: `disable-model-invocation: true` on orchestrators that must be user-run (`sk.init`, `sk.session`, `sk.ship`, `sk.rollback`, `sk.hotfix`); leave `subagent_type`/`inject_files` custom fields as they are (not native, still honoured by prompt text).

---

## 3. Step 2 — Project repo: land and customise the packs (`tagin-platform`, branch `feat/ai-capability-packs` off `dev`)

- Copy the packs from this repo's `skills_archive/{backend,data,frontend,mobile,design}/` to `tagin-platform/.claude/skills/<pack>/` (flat, unchanged names, so routing paths are `.claude/skills/<pack>/SKILL.md`). tagIN keeps `design-principles` and `accessibility-standards` and registers them in `skill-routing.md ## Always` (phase `design`, project type `Frontend`).
- Add native `paths:` frontmatter to each pack so Claude Code can also surface them by file context without the framework (backend packs → `src/backend/**`; `nextjs-patterns` → `src/frontend/apps/customer-portal/**`; `react-admin-patterns` → `src/frontend/apps/tagin-console/**`; `react-native-patterns` → `src/frontend/apps/vendor-app/**`; shared frontend packs → `src/frontend/**`). Keep `when_to_load`/`co_loads_with` for the framework's benefit.
- Create `.specify/memory/skill-routing.md` for tagIN from `skills_archive/skill-routing.example.md`, with `## Surfaces` rows: customer-portal (Next.js, Playwright), tagin-console (Next.js today — verify; the pack says React+Vite), vendor-app (React Native/Expo, Maestro/Detox), and `## Migrations` (EF Core per module, `src/backend/modules/<Module>/…`).
- Copy `skills_archive/memory/{auth_contract,observability-stack}.md` to `tagin-platform/.specify/memory/` (tagIN vocabulary; created now so the framework's references resolve after step 3).
- Customise to tagIN (this is the whole point of project ownership): align pack text with the real repo — `BuildingBlocks.*` naming, module 4-project slice, `specs/adr/00NN-*` references (ADR-0019 arch tests, ADR-0026 REST guidelines), `docs/architecture` as human-primary per `memory/knowledge-three-layer-model.md`, `@tagin/auth`/`@tagin/ui-kit` packages for the frontends. Reconcile the drift items `SKILL_AUDIT.md` flagged (`react-admin-patterns` says React+Vite+Tanstack; the console is Next.js + NextAuth per `review-console-pr`).
- Optional but recommended: move `~/.claude/commands/review-*-pr.md`, `review-api.md`, `review-result-publish.md` and `tagin-platform/.claude/commands/self-review-*.md` into `tagin-platform/.claude/skills/<name>/SKILL.md` so all project-specific AI assets live in one place under git; fix the known stale references there (`docs/reference_prompts/tagin-monorepo-structure.md` no longer exists; `review-portal-pr` name).
- Do not touch `tagin-platform/.claude/settings.json` in this step beyond adding `Skill(...)` allows for the packs if needed.

---

## 4. Step 3 — Integrate the framework into tagin-platform and init

1. In `tagin-platform`: `git remote add framework git@github.com:ajorobert/SpecKit-SSD-SDLC.git`; `git subtree add --prefix=.speckit framework main --squash` (after step 1 is merged and tagged).
2. `bash .speckit/setup.sh` — verify it creates `.claude/skills/sk.*`, agents, hooks, `.claude/.speckit-manifest`, merges hooks/deny into the existing `settings.json`, splices the managed block into a new `CLAUDE.md`, creates `specs/intents/`, `specs/knowledge-base.md`, `specs/guide.yaml`, `history/`, `.specify/` — and leaves `.claude/commands/`, the packs, and the `settings.json` allow list intact.
3. `/sk.init` in **WORKSPACE INIT** mode with four projects: `Backend.API` (`src/backend`, Backend), `Console` (`src/frontend/apps/tagin-console`, Frontend), `CustomerPortal` (`src/frontend/apps/customer-portal`, Frontend), `VendorApp` (`src/frontend/apps/vendor-app`, Mobile). Feed the interview from `docs/architecture/00-overview/tech-stack.md` and `specs/adr/adr-index.md`.
4. Reconcile with the project's existing knowledge layer:
   - ADRs stay in `specs/adr/` (project convention, 26 ADRs). Point `.specify/memory/architecture-decisions.md` at `specs/adr/adr-index.md` and set `adr_dir` in `project-config.md`.
   - `specs/domain/*.md` = Tier 2 domain knowledge bases; `specs/knowledge-base.md` = Tier 1, seeded from `docs/architecture/00-overview` (non-derivable facts only).
   - `docs/architecture` remains human-primary; do not register it in any inject list.
5. Write the project-owned section of `CLAUDE.md` below the managed block: existing self-review workflow, the three-layer knowledge model, and the pack registry pointer.
6. Smoke run: `/sk.session start --role po`, `/sk.story` on a small intent, `/sk.session focus`, `/sk.design` to the first gate, confirm the pack-resolution log lists `backend-architecture` etc. from the project's own `.claude/skills`.
7. Commit on the branch; PR to `dev`.

---

## 5. Critical files

This repo:
- `setup.sh`, `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, `README.md`, `.claude/settings.json`, `docs/memory-guide.md`, new `VERSION`
- `.claude/skills/governance/{checkpoint-rules,quality-gates}.md` (+ new `pack-resolution.md`, shared blocks); new `skills_archive/` tree
- The ten prompts with pack-selection blocks (listed in 1.2) and the six stack-bound skills
- `.claude/hooks/{check-skill-preconditions,post-skill,post-response,validate-path,check-system-prompt-files}.sh`
- `.claude/agents/*.md`, `templates/root/*`, `templates/project/.specify/memory/*`, `templates/artifacts/{impact-analysis,ui-model,story}-template.md`, `specs/intents/README.md`

`tagin-platform`: `.claude/skills/<packs>/`, `.specify/memory/skill-routing.md`, `.claude/settings.json` (merge only), `CLAUDE.md` (new), `memory/knowledge-three-layer-model.md` (read for constraints).

---

## 6. Verification

Step 1, run from this repo:
- `grep -rIn -E "Wolverine|FastEndpoints|Keycloak|Strapi|Next\.js|React Native|Expo|MassTransit|MarketPlace\.|Lucent|SeaweedFS|Hangfire|Elsa" --exclude-dir=.archive --exclude-dir=ai_reports --exclude-dir=skills_archive --exclude-dir=.git .` returns nothing outside `templates/reference/frontend-framework-guide.md`.
- `grep -rn "\.your-layer\|state\.yaml\|stories/story-\|\.specify/intents\|auth-patterns\|data-model\.md\|tasks\.yaml\|design-principles" .claude templates docs` returns nothing.
- `ls .claude/skills` shows only `sk.*`, `governance`, and the 5 pointer stubs; `skills_archive/` holds 24 packs + `memory/` + example manifest.
- `bash -n setup.sh .claude/hooks/*.sh`; `shellcheck` if installed.
- Install test in a scratch dir: create a fake project with a pre-existing `.claude/skills/my-pack/SKILL.md`, `.claude/commands/x.md`, `settings.json` with a custom allow entry, a `CLAUDE.md` with text outside markers, and an existing `specs/adr/`. Run `setup.sh` twice. Assert: all four survive byte-identical; hooks merged once (idempotent); `specs/intents/` and `specs/knowledge-base.md` created; `.claude/.speckit-manifest` present with VERSION; no `skills_archive` content copied. Then add a stray `.claude/skills/sk.obsolete/` and re-run: it is removed (framework namespace), while `my-pack` is still untouched.
- Hook test: scaffold `specs/intents/t/units/u/01-story/story.md` from the template with `status.current: shipped`, set `session.yaml` `active_unit_id`, run `echo '{"tool_name":"Skill","tool_input":{"skill":"sk.rollback"}}' | bash .claude/hooks/check-skill-preconditions.sh` → exit 0; with `status.current: draft` → exit 2. Run `post-skill.sh` for `sk.implement` and confirm nested `status.current` updated without corrupting frontmatter.
- Open Claude Code in this repo: `/sk.design` on a fixture unit reaches Step 0 and reports "no skill-routing.md — no packs loaded" cleanly instead of failing.

Steps 2–3, run from tagin-platform:
- After `setup.sh`: `git status` shows no changes under `.claude/commands/`, the packs, or the `allow` list.
- `/sk.init` workspace mode produces `.specify/memory/projects/index.md` with 4 rows; `skill-routing.md` present.
- `/sk.design` on a fixture unit logs pack resolution naming `.claude/skills/backend-architecture/SKILL.md`.
- Existing `/self-review-backend` still runs.
- Re-run `bash .speckit/setup.sh` after a no-op `git subtree pull` → zero diff.

---

## 7. Out of scope (follow-ups)

- Packaging the framework as a Claude Code plugin / private marketplace (layout is ready after 1.8).
- Evals in CI for the framework, PR-side review (`REVIEW.md`), flow metrics, production→spec loop — per the playbook gap analysis.
- Moving packs to a separate stack-skills repo (the Aug-23 proposal) — only needed if a second project on the same stack appears.
- The `tagIN-demo` prototype repo is untouched; its six generic Tailwind/React/Zustand docs are unrelated to this framework.
