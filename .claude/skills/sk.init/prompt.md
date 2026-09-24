# sk.init — adopt SpecKit in this repository

sk.init detects what the repository already has, proposes values, and records the confirmed result.
It adopts the repository's existing homes and conventions; it never imposes a structure on them.

Resolve `TEMPLATES_DIR` / `SCRIPTS_DIR` / `FRAMEWORK_DIR` per `.claude/skills/governance/framework-paths.md`.
The knowledge homes, their fixed paths and every profile key with its default are defined in
`.claude/skills/governance/profile.md` — this prompt never restates or relocates them.

## What sk.init writes — and nothing else
| Output | When |
|---|---|
| `.specify/profile.yaml` | always (from `{TEMPLATES_DIR}/project/.specify/profile.yaml`) |
| `.specify/memory/projects/index.md` | always — one row per project; a single-project repository has one row (`{TEMPLATES_DIR}/artifacts/projects-index-template.md`) |
| `.specify/memory/projects/{Project}/tech-stack.md` | one per project (`{TEMPLATES_DIR}/artifacts/tech-stack-template.md`) |
| `.specify/memory/constitution.md` | only principles the team states (`{TEMPLATES_DIR}/project/.specify/memory/constitution.md`) |
| `specs/knowledge-base.md` | home absent **and** confirmed **and** not in `install.scaffold_skip` (`system-knowledge-base-template.md`) |
| `specs/adr/adr-index.md` | same condition (`adr-index-template.md`), routing every ADR found |
| `specs/domain/bounded-contexts.md` | same condition (`bounded-contexts-template.md`) |
| `## Registry` table in `.claude/skills/README.md` | same condition for the table (`skills-registry-template.md`); the rest of the README is never touched |

sk.init never creates rules files, memory summaries, pointer files, empty placeholder homes, ADRs or
domain module files. It proposes **no** principles and **no** architecture defaults: layering, aggregates,
command/query separation, idempotency, messaging, logging, tracing, metrics, health endpoints, error
shapes, API versioning and migration direction are the team's decisions, recorded in their constitution,
ADRs and `.claude/rules/` — never by sk.init.

## Inputs
- `--answers <file>` — non-interactive mode (below). Without it, sk.init is interactive.
- `[section ...]` — UPDATE only: limit the run to `profile`, `projects`, `constitution` and/or `registry`.

## Step 0 — Mode
- `.specify/profile.yaml` absent → **INIT**.
- `.specify/profile.yaml` present → **UPDATE**. Read it first; its `knowledge.never_autoload` globs apply
  to detection.

In INIT, any other output that already exists (for example `projects/index.md` or `constitution.md`) is
handled as in UPDATE: diffed and confirmed, never overwritten.

## Step 1 — Detect
Scan before asking anything. Every finding becomes a **proposed value with its evidence** (the file,
command or count it came from). Detection only lists paths under `docs/**` and under paths matched by
`never_autoload`; it never opens files there. Skip `node_modules`, `vendor`, build output, `.git`,
`.archive` and `.speckit`/`{FRAMEWORK_DIR}`.

**Knowledge homes**
- **ADRs** — `specs/adr/NNNN-*.md` files and `specs/adr/adr-index.md`. Read only each ADR's title and
  status line. Propose `knowledge.adr.exemplar` = the most recent ADR whose status is accepted (highest
  number); none → `null`. `knowledge.adr.guard`: `true`.
  ADR-like files outside `specs/adr/` are reported only: the framework reads `specs/adr/`; moving them is
  the team's call.
- **Domain** — `specs/domain/*.md` and `specs/domain/bounded-contexts.md`. If module files exist and share
  one heading structure, propose `knowledge.domain.template` = the path of the most complete one;
  otherwise `default`.
- **Contracts** — `specs/openapi/*.yaml` (each stem is an audience) and `specs/asyncapi/*.yaml` (each stem
  a module). Propose `contracts.verify` / `contracts.codegen` only from a command the repository already
  runs against those files (manifest scripts, Makefile targets, CI workflow steps); otherwise `null`.
  Propose `contracts.compat_rules` = an ADR that defines contract compatibility classes, if one exists.
- **System knowledge base** — does `specs/knowledge-base.md` exist?
- **Skills registry** — does `.claude/skills/README.md` have a `## Registry` table whose header is exactly
  `Skill | Status | Defers to | Always | Signals | Phases | Applies to | Weight`
  (`governance/pack-resolution.md`)? List the project skills present: each `.claude/skills/<dir>/SKILL.md`
  whose directory is not framework-owned (not `sk.*`, not `governance`, not an owned path in
  `.claude/.speckit-manifest`). This inventory is sk.init's only listing of `.claude/skills/`.
  A table in another column order is reported as a mismatch for the team to fix; sk.init does not
  rewrite it.
- **Rules** — each `.claude/rules/{stack}/` folder. Propose `rules.stacks` mapping each folder to the
  projects (names or types) whose files its rules' `paths:` frontmatter matches. No folders → keep the
  template default.
- **Humans-only paths** — candidate folders under `docs/**` (architecture write-ups, archives, generated
  or vendored prose). Propose them for `knowledge.never_autoload`; never add one unconfirmed.

**Conventions**
- `CONTRIBUTING.md` (and a pull-request template, if any): branch naming, commit style, PR title format,
  base branch, and any principles it states.
- **Base branch** — `git symbolic-ref --short refs/remotes/origin/HEAD`, and the most common base of merged
  PRs (`gh pr list --state merged --limit 50 --json title,baseRefName,headRefName` when `gh` is available;
  otherwise `git log --merges --format=%s -n 100`). A distinct base for `hotfix/*` heads → `vcs.hotfix_base`.
- **Branch pattern** — from `git branch -r` and merged head names: the prefixes in use (`feature/`, `fix/`,
  …) and whether a ticket key precedes the topic → `vcs.branch` using `{kind}`, `{Kind}`, `{ticket}`,
  `{topic}`, `{story}`. `vcs.create_branch`: `on-request`.
- **Commit style** — `git log --no-merges --format=%s -n 200`: `conventional` when at least 80% of subjects
  match `^[a-z]+(\([^)]+\))?!?: `, otherwise `free`.
- **PR title** — the common shape of merged PR titles → `vcs.pr_title`; a recurring no-ticket marker →
  `vcs.no_ticket`.
- **Tracker** — keys matching `[A-Z][A-Z0-9]+-[0-9]+` in branch names and PR titles. A dominant key →
  propose `tracker.kind: jira`, `tracker.project: {KEY}`; none → `none`.
- `GEMINI.md` present → propose `install.gemini: true`.

**Projects** — find manifests (`package.json`, `*.csproj`, `go.mod`, `pyproject.toml`, `Cargo.toml`,
`pom.xml`, `build.gradle*`, `pubspec.yaml`, …). A workspace manifest (solution file, workspace list) groups
its members. For each deployable candidate propose:
- **Name** (manifest name, else folder name), **Code Root** (its folder; `.` for a repository-root
  project), **Role** (one line, from the manifest description or the folder README).
- **Type** from evidence: a server/HTTP runtime or hosting dependency → `Backend`; a browser bundler or UI
  framework → `Frontend`; a native or cross-platform mobile SDK → `Mobile`. Libraries and shared packages
  are not projects; ask when unclear.
- **Tech-stack snapshot** — runtime, framework and key library versions from the manifest (the lockfile
  for resolved versions), each `verified {today} against {manifest path}`; **Platform**; **Test Layout**
  from where test files actually live; **Test Runner** from manifest scripts or test config; **Forbidden
  Skip Idioms** — the skip/focus syntax of the detected test framework; **E2E Tooling** from its config
  or dependency; **Coverage Thresholds** from config. For a project that owns a schema (a migrations
  folder or migration tool dependency): **Migrations** tool, location and tests from what exists;
  rollback policy is asked, never assumed. `none` is a valid value for every field.

**Candidate principles** — statements of fixed principle already written by the team: in the ADRs of the
index's ALWAYS block (or, with no index, accepted ADRs' `## Rules` / decision sections) and in
`CONTRIBUTING.md`. Each candidate carries its source (`ADR-NNNN`, `CONTRIBUTING.md §…`). These are the
team's own words, offered back for acceptance; sk.init adds none of its own.

## Step 2a — Confirm (interactive)
Present the proposal one section at a time, each value with its evidence, and ask the team to confirm or
correct it. A value neither detected nor given stays at the profile default (`governance/profile.md`).

1. **Profile** — `knowledge`, `contracts`, `rules`, `skills`, `vcs`, `tracker`, `install`. Only the keys
   whose proposed value differs from the default need an answer.
2. **Projects** — the rows (Name, Type, Code Root, Role), then each project's snapshot. Ask only for what
   detection left open (for example a rollback policy); accept `none`.
3. **Constitution** — "Which principles are fixed for this project — ones that do not change as the system
   evolves?" Offer the candidate principles for accept / reject / reword, and take any the team adds.
   Each is declarative and checkable; where an ADR elaborates it, reference the ADR instead of restating
   it. No principle stated → no constitution is written.
4. **Homes** — for each absent home (`specs/knowledge-base.md`, `specs/adr/adr-index.md` when ADRs exist,
   `specs/domain/bounded-contexts.md` when module files exist, the Registry table when project skills
   exist) not in `install.scaffold_skip`: "Create it now?" A declined home is offered for
   `install.scaffold_skip` so it is not proposed again. For the knowledge base, ask what to put under
   *Why This System Exists* and *Core Actors*, or leave the headings empty.

## Step 2b — Non-interactive (`--answers <file>`)
Read the YAML answers file and run with no questions:

```yaml
profile:                 # any subset of the keys in {TEMPLATES_DIR}/project/.specify/profile.yaml
  vcs: { base_branch: main, commit: conventional }
  knowledge: { never_autoload: ["docs/architecture/**"] }
projects:                # replaces the detected rows when present
  - { name: "{Project}", type: Backend, code_root: "{path}", role: "{what it serves}" }
principles:              # the team's fixed principles, verbatim; may reference ADRs
  - "{principle} — ADR-NNNN"
registry: create         # create | skip — the ## Registry table, only when absent
homes: [knowledge-base, adr-index, bounded-contexts]   # optional; absent homes to create
```

Resolution per value: the answers file → the detected value → the profile default. Two exceptions:
detected candidate principles are never adopted (omitted `principles` → the constitution is not written
or changed; the candidates are listed in the report), and a home is created only when `homes` or
`registry: create` names it. Tech-stack snapshots always come from detection; a field detection cannot
settle is written `none` and listed in the report for the team to check. A malformed file or an
unknown `type` → STOP and name the entry.

## Step 3 — Write
- **Profile** — copy the template with every comment; set only the values that differ from the default.
  In UPDATE, edit the changed keys in place and keep everything the team added.
- **Projects** — `projects/index.md` from the template, one row per project, Project linked to its
  `tech-stack.md`. Each `tech-stack.md` from the template with every section filled or `none`.
- **Constitution** — the template's header comment plus `## Principles`, numbered, exactly as confirmed.
- **Homes**, when confirmed:
  - `specs/knowledge-base.md` from the template, `last-updated: {today}`, with only what the team gave.
  - `specs/adr/adr-index.md` from the router template. Route every ADR found: the ALWAYS block holds
    only the ADRs the team names as always-applicable; every other ADR goes under a signal block whose
    signals come from its title and decision (confirm the grouping). A superseded ADR is routed only from
    its successor. No ADR stays unrouted.
  - `specs/domain/bounded-contexts.md` from the template, one row per existing module file.
  - The `## Registry` table: create `.claude/skills/README.md` from the template if the file is absent;
    otherwise append only the `## Registry` heading and table at the end. One row per project skill found:
    `active`, Defers to `—`, Always `—`, Signals proposed from the skill's `description:` (lower case),
    Phases `—`, Applies to from the description or `any`, Weight `1` — as confirmed.

## UPDATE mode
1. Re-run Step 1 in full.
2. Build a diff per section and show it before asking anything:
   - **profile** — each key whose detected value differs from the file: `key: current → proposed (evidence)`.
   - **projects** — rows added, removed or changed; per snapshot, changed versions and the new
     `verified {today}` dates, and fields that moved to or from `none`.
   - **constitution** — candidate principles not yet present. Existing principles change or go only when
     the team asks.
   - **registry** — project skills not in the table (rows to append) and rows whose directory is missing
     (reported only). Existing rows are never edited.
3. Ask which sections to apply (all, some, none), then confirm each chosen section as in Step 2.
   With `--answers`, apply the sections the file names plus the detected diffs of `projects`.
4. Apply only the confirmed sections, editing in place. Offer an absent home only when it has content to
   hold and is not in `install.scaffold_skip`.

## Step 4 — After writing
1. If `knowledge.adr.guard` is `true` and `specs/adr/` holds ADRs, run `bash {SCRIPTS_DIR}/check-adr-index.sh`
   and report its output. A failure lists the unrouted ADRs or dangling routes for the team to fix.
2. Report:
   ```
   sk.init {INIT|UPDATE} — {date}
   Written:   {each file, created | updated}
   Skipped:   {each home or section, and why: exists | declined | scaffold_skip | nothing to hold}
   Detected, not adopted: {candidate principles; unregistered or mismatched registry; ADRs outside specs/adr/}
   Written as none — check: {Project}: {field}, …
   ADR guard: {PASS | FAIL + output | not run}
   ```
3. Tell the user: re-run `bash .speckit/setup.sh` (or `bash {FRAMEWORK_DIR}/setup.sh`, using `framework_dir`
   from `.claude/.speckit-manifest`) so the CLAUDE.md managed region renders `never_autoload` from the new
   profile.
