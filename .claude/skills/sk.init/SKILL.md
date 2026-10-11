---
name: sk.init
description: "Adopt SpecKit in a repository, or re-detect an adopted one: detect projects, commands, conventions and knowledge homes, confirm them with the team (or read --answers <file>), and write the profile, the projects router and per-project tech stacks."
role: any
---

# sk.init
Detects what the repository has, proposes values with evidence, and records what the team confirms. It
adopts the repository's own homes and conventions and imposes no structure on them. It proposes no
principle and no architecture default: those are the team's, in their principles file, ADRs and rules.

## What it writes — and nothing else
| Output | When |
|---|---|
| `.specify/profile.yaml` | always, from `{templates_dir}/project/.specify/profile.yaml` |
| `.specify/memory/projects/index.md` | always — one row per project (`projects-index-template.md`) |
| `.specify/memory/projects/{Project}/tech-stack.md` | one per project (`tech-stack-template.md`) |
| `.claude/rules/principles.md` (the `knowledge.principles` path) | absent, and the team states principles or accepts the default `## Starting work` (`{templates_dir}/project/.claude/rules/principles.md`) |
| `specs/adr/adr-index.md`, `specs/domain/bounded-contexts.md`, the `## Registry` table of `.claude/skills/README.md` | absent, confirmed, not in `install.scaffold_skip` |
| the work-pipeline ADR and its adr-index block | offered once, written only when accepted (`{templates_dir}/artifacts/work-pipeline-adr-template.md`) |

A file that already exists is diffed and confirmed, never overwritten. `templates_dir` comes from
`.claude/.speckit-manifest` (framework repo: `templates`).

## Inputs
- `--answers <file>` — no questions (below). `[section …]` — re-detect only `profile`, `projects`, `principles`, `registry`.
- `.specify/profile.yaml` present → re-detect mode: its `never_autoload` globs apply to detection.

## Step 1 — Detect
Scan before asking. Every finding is a proposed value with its evidence (file, command, count). Only list
paths under `never_autoload` and `docs/**`; never open them. Skip dependency and build folders, `.git`,
`.archive` and the framework subtree.

- **Projects** — manifests (`package.json`, `*.csproj`, `go.mod`, `pyproject.toml`, `Cargo.toml`, `pom.xml`,
  `build.gradle*`, `pubspec.yaml`, …); a workspace manifest groups its members. Per deployable candidate:
  Name, Code Root (`.` at the root), Role (one line), Type from evidence (server runtime → Backend; browser
  bundler or UI framework → Frontend; native or cross-platform mobile SDK → Mobile). A library folder shared
  by several apps may be its own project, typed as its consumers. Ask when unclear.
- **Tech stack (commands, not versions)** — from manifest scripts and CI workflow steps: Build, Test,
  Lint / Typecheck, Test Runner, Test Layout (where tests actually live), Forbidden Skip Idioms (the test
  framework's skip/focus syntax), Platform, E2E Tooling, Coverage Thresholds; for a schema-owning project,
  Migrations — tool, location, tests (the rollback policy is asked, never assumed). `none` is valid.
- **ADRs** — `specs/adr/NNNN-*.md` (title and status line only) and `adr-index.md`. Propose
  `knowledge.adr.exemplar` = the latest accepted ADR. ADR-like files elsewhere are reported only.
- **Domain** — `specs/domain/*.md`; a template file, or module files sharing one heading structure →
  `knowledge.domain.template`.
- **Contracts** — `specs/openapi/*.yaml` (audiences), `specs/asyncapi/*.yaml` (modules). `contracts.verify` /
  `contracts.codegen` only from a command the repository already runs (scripts, Makefile, CI); an ADR
  defining compatibility classes → `contracts.compat_rules`.
- **Principles** — a rule file under `.claude/rules/` with no `paths:` that states decision principles →
  propose it as `knowledge.principles`. Otherwise, candidate principles the team already wrote (the ADR
  index's ALWAYS ADRs, CONTRIBUTING, the README), each with its source, offered back for acceptance.
- **Rules** — each `.claude/rules/{area}/` folder → `rules.stacks`: the projects whose files its rules' `paths:` match.
- **Review commands** — project commands or skills (`.claude/commands/*.md`, non-`sk.*` skills) whose
  description reviews one project's change → `review.commands.{Project}`.
- **Skills registry** — a `## Registry` table with the header
  `Skill | Status | Defers to | Always | Signals | Phases | Applies to | Weight`, and the project skills
  present (any `.claude/skills/<dir>/SKILL.md` not framework-owned). A table in another column order is
  reported, never rewritten.
- **Conventions** — base branch (`origin/HEAD`, bases of merged PRs), a distinct hotfix base, branch
  pattern, commit style (`conventional` when ≥ 80% of 200 subjects match `^[a-z]+(\([^)]+\))?!?: `), PR
  title shape, a no-ticket marker, a dominant tracker key (`tracker.kind: jira`, `tracker.project`),
  human-only doc folders → `never_autoload` candidates (never added unconfirmed).

## Step 2 — Confirm
Interactive: one section at a time — profile (only keys that differ from the default), projects and their
tech stacks (only what detection left open), principles, then each absent home ("create it now?"; a
declined home is offered for `install.scaffold_skip`), then the work-pipeline ADR: "Record that
`specs/intents/` is a work record, that shipped units reach the knowledge homes only through promotion,
and that unit artifacts rank below ADRs and rules?".

`--answers <file>`:
```yaml
profile: { vcs: { base_branch: main }, knowledge: { never_autoload: ["docs/architecture/**"] },
           review: { commands: { api: review-api } } }
projects:   [ { name: api, type: Backend, code_root: src/api, role: "public API" } ]   # replaces detection
principles: [ "{principle} — ADR-NNNN" ]   # verbatim; omitted → no principles file change
homes:      [ adr-index, bounded-contexts, registry ]
pipeline_adr: true
```
Per value: the file → detection → the default. Candidate principles are never adopted without
`principles`. A tech-stack field detection cannot settle is written `none` and reported. A malformed file
or unknown `type`: STOP and name the entry.

## Step 3 — Write
- **Profile** — the template with its comments; set only non-default values (re-detect: edit changed keys in place).
- **Projects** — the router, each project linked to its `tech-stack.md`; each tech stack filled or `none`.
- **Principles** — from the template: `## Principles` numbered exactly as confirmed; `## Starting work` as
  the template has it unless the team changed it; the other sections only with what the team gave.
- **ADR index** — route every ADR found: ALWAYS holds only what the team names always-applicable; the rest
  under signal blocks from their titles and decisions (confirm the grouping); a superseded ADR only from
  its successor.
- **Bounded contexts** — one row per module file. **Registry** — append the table (create the README only
  when absent): one `active` row per project skill, Signals proposed from its description, as confirmed.
- **Work-pipeline ADR** — through `bash {scripts_dir}/create-adr.sh`, in the project's ADR shape, routed
  in a block whose signals cover `specs/intents`, units and phases.

## Step 4 — Report
Run `bash {scripts_dir}/check-adr-index.sh` when ADRs exist and the guard is on. Then:
```
sk.init {adopt | re-detect} — {date}
Written: {file: created | updated}      Skipped: {home or section: why}
Detected, not adopted: {…}              Written as none — check: {Project: field}
ADR guard: {PASS | FAIL + output | not run}
Next: bash {framework_dir}/setup.sh — renders the CLAUDE.md region from the new profile
```
