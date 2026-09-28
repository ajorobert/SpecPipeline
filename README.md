# SpecKit-SSD-SDLC

> A spec-driven SDLC for teams that build with AI coding agents.

SpecKit runs every change through the same pipeline — story, design, plan, implement, test, review, UAT,
security audit, verify, ship — as `/sk.*` commands in Claude Code. Each command reads what the previous
one wrote to disk, does its work with you in one session, and writes its own artifacts. The framework owns
the **process**; your project owns the **knowledge** (ADRs, rules, domain specs, contracts). SpecKit ships
no stack or architecture opinion: it checks work against *your* ADRs, *your* rules and *your* principles.

## Contents
- [How it runs](#how-it-runs)
- [Install](#install)
- [The pipeline](#the-pipeline)
- [Where knowledge lives](#where-knowledge-lives)
- [A unit's artifacts](#a-units-artifacts)
- [Status, gates and the tracker](#status-gates-and-the-tracker)
- [Updating the framework](#updating-the-framework)
- [Testing the framework](#testing-the-framework)

## How it runs
- **One command per session.** Start each command in a fresh session. Nothing downstream reads a
  conversation — only artifacts — so a new session costs nothing and keeps the window small. `/sk.session
  status` tells a new session where the unit stands; every command's report names the next command.
- **One project per session for heavy phases.** On a unit that touches several projects (say an API, a web
  app, an admin console and a mobile app), `sk.implement`, `sk.test` and `sk.review` run once per project:
  `/sk.implement --projects api`, then a fresh session for `--projects web`, and so on.
- **The command does its own work, with you.** Its steps run in the session; review gates, clarifying
  questions and ADR decisions happen inline. Subagents are used only to read — code reconnaissance, and a
  fresh-eyes reviewer (`sk-reviewer`) that checks plans and diffs — and never write or ask.
- **Re-running resumes.** A step whose output already exists (and is approved, where a gate applies) is
  skipped; implementation resumes from the first open task.
- **Loading is deterministic.** `bash .claude/hooks/context.sh <command> [--projects <name>]` prints exactly
  what a command reads: the unit's files (present or missing), the capability packs selected for the phase,
  and — for review and verify — the rule files whose `paths:` match the diff. Everywhere else, coding rules
  load by path as Claude Code opens files.

## Install
SpecKit lives as a git subtree under `.speckit/`.
```bash
git remote add --no-tags framework git@github.com:ajorobert/SpecPipeline.git
git subtree add --prefix=.speckit framework main --squash
bash .speckit/setup.sh                 # --gemini also maintains GEMINI.md
/sk.init                               # or: /sk.init --answers <file>
```
`/sk.init` detects what the repository already has — projects and their build/test commands, ADRs and their
index, bounded contexts, OpenAPI/AsyncAPI specs, `.claude/rules/`, the skills Registry, project review
commands, branch and commit conventions — proposes values with evidence, and writes what you confirm:
`.specify/profile.yaml`, the projects router `.specify/memory/projects/index.md`, one `tech-stack.md` per
project, and (when absent) `.claude/rules/principles.md`. It offers an ADR that records how the pipeline's
unit folders relate to your knowledge homes.

**Capability packs.** Copy packs from `.speckit/skills_archive/` (or write your own) into
`.claude/skills/<pack>/` and add a row to the `## Registry` table of `.claude/skills/README.md`. The row's
routing columns decide when a command loads it (`.claude/skills/governance/pack-resolution.md`).

## The pipeline
| Command | Session | Writes | Role |
|---|---|---|---|
| `/sk.story [--bug] [--jira KEY]` | one, interactive | `01-story/`, unit-brief Impacted Projects | po |
| `/sk.design [--architecture\|--datamodel\|--contracts\|--ui] [--refresh "…"]` | one, gated | `02-design/`, canonical contracts (in place), `specs/domain/`, ADRs | architect |
| `/sk.plan [--projects X] [--check]` | one, gated | `03-plan/{Project}/plan.md, tasks.md` | lead |
| `/sk.implement --projects X [--refine]` | one per project, gated | code under the project's root; `04-implementation/{Project}/` | the project's engineer |
| `/sk.test --projects X` | one per project, gated | tests at the project's Test Layout; `05-test/{Project}/test-report.md` | the project's QA |
| `/sk.review --projects X` | one per project | `04-implementation/{Project}/review.md` | the project's engineer |
| `/sk.uat` | one, gated | `06-uat/uat-report.md` | frontend QA |
| `/sk.security-audit` | one, gated | `07-security-audit/security-report.md` | security |
| `/sk.verify` | one | nothing — the verdict | architect |
| `/sk.ship [--dry-run]` | one | promotion, commit, PR | lead |

Also: `/sk.ff` (story → design → plan in one window, for small scope), `/sk.adr`, `/sk.investigate`,
`/sk.hotfix` (P0 fast path), `/sk.session`, `/sk.init`.

A project can hand review to its own command: `review.commands: { api: my-api-review }` in the profile
makes `/sk.review --projects api` run it and adopt its findings.

## Where knowledge lives
One home per fact. The full table and the profile keys: `.claude/skills/governance/profile.md`.

| Fact | Home | Loaded |
|---|---|---|
| Principles, loading order, working style | `.claude/rules/principles.md` (no `paths:`) | every session |
| Decisions | `specs/adr/NNNN-*.md`, routed by `specs/adr/adr-index.md` | per task, through the router |
| Coding and authoring rules | `.claude/rules/{area}/*.md` with `paths:` | when a matching file is read |
| Domain rationale | `specs/domain/bounded-contexts.md`, `specs/domain/{module}.md` | per task |
| Contracts | `specs/openapi/{audience}.yaml`, `specs/asyncapi/{module}.yaml` | the operations a unit changes |
| Projects, commands, layout | `.specify/memory/projects/` | by `context.sh` |
| Procedure (capability packs) | `.claude/skills/<pack>/` + the Registry | by phase and signals |
| In-flight work | `specs/intents/{intent}/units/{unit}/` | the active unit only |

**Precedence on conflict:** ADRs → rules (principles first) → packs → the unit's design → existing code.

At ship, a unit's durable knowledge is **promoted** to its home — decisions to ADRs, domain rules to
`specs/domain/`, checkable rules to `.claude/rules/` — recorded in `promotion.md`, and the unit folder
**freezes**. New work starts a new unit.

## A unit's artifacts
```
specs/intents/{intent}/units/{unit}/
├── unit-brief.md, knowledge-base.md, promotion.md
├── 01-story/          story.md, requirement.md, acceptance-criteria.md
├── 02-design/         architecture.md, impact-analysis.md, database-design.md, contract-changes.md,
│                      ui-model.md, projects/{Project}.md
├── 03-plan/{Project}/ plan.md, tasks.md
├── 04-implementation/{Project}/  progress.md, delivery.md, review.md
├── 05-test/{Project}/ test-report.md
├── 06-uat/            uat-report.md
└── 07-security-audit/ security-report.md
```
Canonical tree: `.claude/skills/governance/phase-layout.md`. Code and runnable tests live under each
project's code root, never under `specs/`.

## Status, gates and the tracker
- The story's `status.current` moves `draft → ready → in-progress → testing → review → verify →
  security-review → done → shipped` (plus `review-rejected`), only through `bash .claude/hooks/story-status.sh`
  and the hooks. Commands that decide a phase end with `SK_RESULT: PASS | PARTIAL | FAIL`; PARTIAL means
  "this project is done, others are still open". See `.claude/skills/governance/status-model.md`.
- `checkpoint_mode` (autopilot | confirm | validate, set by `/sk.story`) decides which gates pause for you.
- Each command runs with one role, and `.claude/skills/governance/roles.yaml` limits what that role may
  write (a frontend engineer cannot rewrite the plan; a product owner cannot touch code roots).
- With a tracker configured (`tracker.kind: jira`), every transition is queued and mirrored to the issue
  through your tracker connector (`.claude/skills/governance/tracker-mirror.md`).

## Updating the framework
```bash
git subtree pull --prefix=.speckit framework main --squash
bash .speckit/setup.sh
```
`setup.sh` mirrors the framework-owned paths (`.claude/skills/sk.*`, `.claude/skills/governance/`,
`.claude/agents/sk-reviewer.md`, `.claude/hooks/*.sh`), removes any path a previous version installed that
this one no longer ships (from `.claude/.speckit-manifest`), replaces the framework's hook entries in
`.claude/settings.json` (your own hooks, `allow` and `defaultMode` are untouched; deny rules are unioned), and
re-renders the managed region of `CLAUDE.md`. Everything else — your rules, packs, commands, agents, the
profile, the principles file and `specs/` — is never touched. A second run with no change is byte-identical.

## Testing the framework
Framework-only suites (never synced into a project); Linux, macOS and Windows (Git Bash); need `git` and `jq`.
```bash
bash tests/hooks-test.sh     # hooks, context.sh and verify-evidence.sh against a throw-away fixture
bash tests/install-test.sh   # install, re-run, and upgrade from version N to N+1 into the fixture
```
A `Stop` hook also logs prompt-cache telemetry per turn to `.specify/state/cache-metrics.jsonl`;
`bash .claude/hooks/cache-metrics-report.sh` summarises it.
