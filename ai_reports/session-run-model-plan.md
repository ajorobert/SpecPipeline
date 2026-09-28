# SpecKit run model: one command, one session, one main loop

## Context
The framework has two execution models layered on top of each other:
1. **Session per command.** Each main command (story, design, plan, implement…) is self-contained: it starts in a fresh session, reads the previous phase's artifacts from disk, and writes its own.
2. **Isolated sub-commands.** This was added later (PR 35): each command dispatches its `_sub_` skills as Agent subagents to keep its own window small.

The two conflict. A subagent cannot talk to the user, so the gates, questions and ADRs had to be pulled back into the orchestrator. That required role-marker juggling (`set-worker-role.sh`), nested-dispatch rules, and a rule that `implementproject` stays on the Skill tool. Each worker also re-loads the context its orchestrator already loaded.

The review of PR 35 also found real defects in this machinery:
- Gate pauses lose the `SK_RESULT` marker and the active role.
- Orchestrators run `clear` and then keep writing under the session role.
- Some prompts still say "Skill tool", others say "Agent tool".

The goal is one coherent model that suits a large backend + web + admin + app codebase.

**Decisions (confirmed with the user):**
- Heavy multi-project phases run one session per project.
- Re-running a command skips finished steps.
- PR 35 is superseded: close it and branch fresh from `dev`.
- No project has adopted the framework yet, so nothing needs a migration path from today's layout (constitution, sub-skills, role agents). From the first install on, re-running `setup.sh` must update an installed project in place (§9).
- Every framework file is written in current-state language: what it is and does, never "replaces", "was", "retired", "no longer" or "amended". History lives in git.

## Direction from the field
- **Anthropic, Claude Code best practices:**
  - The context window is the resource to manage.
  - Have Claude interview you, write a spec to a file, then "start a fresh session to execute it".
  - Use subagents for investigation and for an adversarial review of the diff, and keep them "cheap on the lead's context".
  - Use `/clear` between tasks.
- **Anthropic, context engineering:**
  - Keep system prompts to "the minimal set of information".
  - Retrieve context just in time.
  - Use structured notes and artifacts outside the window for long-horizon work.
  - Subagents return "a condensed, distilled summary".
- **Anthropic, long-running agent harnesses:** incremental progress per session, with clear artifacts (a progress file, git) for the next session. Not one ever-growing window.
- **Cognition, "Don't build multi-agents":**
  - Use a single-threaded main loop.
  - Parallel writing subagents are fragile, because "actions carry implicit decisions".
  - Their 2026 follow-up: the setups that work have "one main loop carrying state with subagents being stateless workers with narrow scope".
- **OpenAI Codex ExecPlans:** one self-contained plan file is the ground truth; the agent re-reads it and resumes from it, not from chat history.
- **Spec Kit, Kiro, AWS AI-DLC:** spec → plan → tasks → implement as separate human-gated steps, with the human deciding at each step.

All of these point to the same model: **the session is the unit of isolation, disk artifacts are the handoff, and the main loop does the work and talks to the human.** Subagents are only read-only helpers.

Sources:
- https://code.claude.com/docs/en/best-practices
- https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
- https://anthropic.com/engineering/effective-harnesses-for-long-running-agents
- https://cognition.com/blog/dont-build-multi-agents
- https://x.com/walden_yan/status/2047054554433462360
- https://github.com/openai/openai-cookbook/blob/main/articles/codex_exec_plans.md
- https://intuitionlabs.ai/articles/spec-driven-development-spec-kit
- https://github.com/aws-samples/sample-specship

## The model (three rules)
1. **Session = one command (× one project for heavy phases).**
   - Handoff happens only through files on disk.
   - Every completion report ends with `Next: /sk.<cmd> [--projects X] in a fresh session`.
   - `sk.ff` remains the one-window path for small scope.
2. **Inside a session, the main loop does everything.**
   - Sub-commands become **step files** inside the command's folder (`.claude/skills/sk.design/steps/architecture.md`, …), loaded when that step is reached.
   - The command loads the shared context once; steps never re-list inputs.
   - Gates, questions and ADRs happen inline.
   - One role per command.
3. **Subagents only for read-only, narrow jobs that return a summary:**
   - Codebase recon (built-in `Explore`).
   - A fresh-eyes check (one read-only `sk-reviewer` agent: plan consistency, "diff vs plan" at the end of implement).
   - Never a writer, never asks the user. So they need no role markers.

Resume rule, once, in `governance/preflight.md`:
- A step whose output exists (and is `status: approved` when gated) is skipped.
- `sk.implement` resumes from `progress.md`.
- This replaces the per-skill RESUME/REFRESH/TARGETED prose. Keep only the `--projects` and `--refresh "<change>"` flags.

### Command shapes
| Command | Session scope | Steps (were `_sub_` skills) | Subagent use |
|---|---|---|---|
| sk.story | 1 session, interactive | specify → clarify (one assessment, one question cap) → impact / Impacted Projects | none |
| sk.design | 1 session, gates inline | architecture → datamodel → contracts → ui (when a Frontend/Mobile row exists) | optional `Explore` recon |
| sk.plan | 1 session; all projects (plans are small), or `--projects` for large units | per-project plan (plan.md + tasks.md) | `sk-reviewer` consistency check (was analyze) |
| sk.implement | **1 session per project** (`--projects X`); small units may omit the flag | single build step (scaffolding and codegen merged); optional scaffold checkpoint in `validate` mode | optional `Explore`; `sk-reviewer` diff-vs-plan before the gate |
| sk.test / sk.review | 1 session per project | — | none (a fresh session is already fresh eyes) |
| sk.verify | 1 session | evidence script + judgment of the remaining items | none |

## Implementation (new branch `feat/session-run-model` from `dev`; close PR 35)

### 1. Hooks: markers that survive gates, role from the command
- `lib-story.sh`:
  - `sk_on_skill_start` takes the role from a new SKILL.md `role:` field. It replaces `sk_skill_role`'s `subagent_type` → agent-name lookup.
  - For `sk.implement`, `sk.test` and `sk.review`, the role comes from the `--projects` type (Backend → backend, Frontend → frontend, Mobile → mobile; QA roles for sk.test). Parse the args with the existing `sk_skill_from_input` input, and resolve the type from `.specify/memory/projects/index.md` the way `project-resolution.md` does.
- `post-response.sh`:
  - Stop clearing `active-skill`/`active-skill-role` on every turn.
  - Delete `last-skill` only when an `SK_RESULT` line is found.
  - Clear the markers on the next skill start instead, plus a new `SessionStart` hook.
- Add the `SessionStart` entry to `.claude/settings.json` and `templates/root/settings.speckit.json`.
- Carry over from PR 35: the mobile role and the QA write_scope deny sets. Skip `set-worker-role.sh`.

### 2. Roles without role agents
- Under this model no role runs as an agent; roles exist only for `write_scope`.
- Move the deny sets into `.claude/skills/governance/roles.yaml` (synced dir), keyed by role. `validate-path.sh` reads it instead of `agents/{role}.md` (same deny-glob loop).
- Delete the role agents from `.claude/agents/`.
- Add one read-only `sk-reviewer.md` (tools: Read, Grep, Glob, Bash; system prompt of about 100 words).
- Update `setup.sh`: set `FRAMEWORK_AGENTS` to `(sk-reviewer.md)`.

### 3. Collapse sub-skills into step files
- For each parent (`sk.story`, `sk.design`, `sk.plan`, `sk.implement`, `sk.test`):
  - Move each `_sub_*/prompt.md` into `sk.<parent>/steps/<step>.md`.
  - Strip its Input Artifacts, preflight, pack resolution, Quality Bar, and the "emit at end of user-input block" XML. The parent loads the context once.
  - Remove the `_sub_` directories (via `archive-file.sh`, this repo's removal policy).
- Merge `implement_sub_scaffolding` and `implement_sub_codegen` into `steps/build.md`. `implementproject`'s delivery-doc writing moves into `sk.implement/prompt.md`.
- Parent `prompt.md` shape:
  1. Preflight: run `context.sh`, read its list.
  2. Steps in order, each with a gate line.
  3. Completion report with the next-session line.
- Delete `governance/worker-dispatch.md`.
- Reduce `governance/session-boundaries.md` to the next-session rule, in about 10 lines.

### 4. Deterministic loading (`.claude/hooks/context.sh <command> [--projects X]`)
One script prints the exact files the session should read:
- unit paths and story files;
- the project row and `tech-stack.md`;
- rule files whose `paths:` globs match the project's CodeRoot (or the diff, for review/verify);
- selected packs (the `pack-resolution.md` scoring, implemented in bash/awk);
- the ADR router path. ADR signal matching stays with the model.

Reuse the `sk_profile_get`/`sk_profile_list` helpers in `lib-profile.sh` and `sk_find_story_file` in `lib-story.sh`. `pack-resolution.md` shrinks to the registry format for humans.

Add `.claude/hooks/verify-evidence.sh`: mechanical quality-gate items (files exist, frontmatter statuses, tasks done in `progress.md`, test/security status). `sk.verify` judges only what is left.

### 5. Prune artifacts with no reader
- Remove `guide.yaml` (and sk.design's walk over every code root), `planning-brief.md` (fold into impact-analysis → Sequencing), and `checklist.md` (a DoD section in `plan.md`).
- Create `jira-subtask.md` only when `tracker.kind` is set; make `estimation.md` opt-in.
- `plan.md` keeps Approach, Sequence and Files Affected, and links to the design for everything else.
- Merge `implementation.md` + `validation.md` into `delivery.md`; keep `progress.md`.
- `05-test/{Project}/` becomes a single `test-report.md`.
- Update `governance/phase-layout.md`, `quality-gates.md`, and the templates in `templates/artifacts/`.

### 6. Always-loaded context
- Every SKILL.md `description:` becomes a trigger only (≤ 200 chars). No Reads/Writes lists.
- Drop `inject_files` and `subagent_type` from the frontmatter (unused, or replaced by `role:`).
- Split `governance/profile.md`: a short loading-rules section in `preflight.md`, and a reference file for humans and sk.init.
- Update `CLAUDE.md` rule 1 in `templates/root/CLAUDE.md` and re-render.

### 7. Command set cleanup
The framework drops from 35 skill dirs to 15. Each kept command owns one phase or one clear job.

| Keep | Remove / fold | Why |
|---|---|---|
| sk.init, sk.session | — | adoption; focus/status/restore at every fresh session |
| sk.story, sk.design, sk.plan, sk.implement, sk.test | the 11 `_sub_` skills (become `steps/`) | see §3 |
| sk.review (thin), sk.uat, sk.security-audit (one report instead of four files), sk.verify | — | gated phases; review delegates to the project (§8) |
| sk.ship, sk.hotfix, sk.adr, sk.investigate, sk.ff | — | promotion + PR, urgent path, decisions, bug root cause, small-scope one-window |
| — | **sk.impact** | duplicates the story's architect probe and design's impact-analysis |
| — | **sk.migrate** | becomes a step of `sk.implement` when `database-design.md` changes the schema, using the migration tool declared in the project's tech-stack.md |
| — | **sk.knowledge-base** | unit notes are written inline by design/review; durable facts reach `specs/domain`/ADRs through promotion at ship |
| — | **sk.phr** | ceremony; drop the "PHR created" quality-gate item and the `history/prompts/` home. Decisions go to ADRs, and durable facts reach their home through promotion |
| — | **sk.rollback** | revert via git and open a new unit; the rollback plan is part of the migration step |

## 8. The project knowledge layer the framework expects (by shape)
The framework stays independent: no project names, no stack terms. It matches a project by the shape of its knowledge layer and adds only the **work pipeline**: `specs/intents/`, `.specify/`, gates, status, resume and the scripts. It adds no knowledge home and never restates an ADR or a rule.

### 8.1 The homes and their default paths
All are project-owned. `sk.init` seeds a home only when it is absent, and never overwrites one.

| Home | Default path | Shape the framework relies on | Loaded |
|---|---|---|---|
| Principles | `.claude/rules/principles.md` | a rule file with **no `paths:`**, so Claude Code loads it in every session (§8.2) | automatically, every session |
| Decisions | `specs/adr/NNNN-*.md` + `specs/adr/adr-index.md` | the index is a router: ALWAYS block, task-signal blocks with "also load if", an UNCLEAR → ask-the-user rule | per task, via the router |
| Coding and authoring rules | `.claude/rules/{area}/*.md` | each file carries `paths:` frontmatter | automatically, when a matching file is read |
| Procedure (capability packs) | `.claude/skills/<pack>/SKILL.md` + the `## Registry` table in `.claude/skills/README.md` | registry columns as today; the Phases column may hold phases the framework doesn't use, which are ignored | by trigger; by registry for `sk.*` |
| Domain rationale | `specs/domain/bounded-contexts.md` + `specs/domain/{module}.md` | a template file may exist (`knowledge.domain.template`) | per task |
| Contracts | `specs/openapi/{audience}.yaml`, `specs/asyncapi/{module}.yaml` | canonical, edited in place | only the operations a unit's change list names |
| Human-only folders | any, listed in `knowledge.never_autoload` | — | never, unless a person names the file |

**Precedence (framework default):** ADRs → rules (principles first) → packs → the unit's design → code.
- A specific decision beats a general principle.
- Code that must differ from an ADR supersedes the ADR first.
**Not framework homes.** Remove each of these from the templates, skills, profile keys and setup:
- `.specify/memory/constitution.md`: the principles file is the one home for principles.
- `specs/knowledge-base.md` and its CLAUDE.md `@import`: the principles file and the ADR router cover system-wide context.
- `history/prompts/`: goes with `sk.phr`.

### 8.2 `principles.md`: the default artifact
Path: `templates/project/.claude/rules/principles.md`. It has no `paths:`, so it always loads, and no skill ever reads it explicitly; that is one read saved per phase. `sk.init` writes it from what the team states, and every section is optional except the first.

| Section | Holds | Used by the framework for |
|---|---|---|
| `## Principles` | fixed, checkable principles (numbered) | design and review cite `principles §N`; a violation is BLOCKING unless an ADR decides otherwise |
| `## Before accepting a design` | the questions a design must answer | design gate checklist items (appended to the framework's own) |
| `## Baseline` | capabilities every new project of a type must have (e.g. health checks, structured logging) | bootstrap tasks when a project has no code yet |
| `## Starting work` | the loading order: read the ADR router first; open an existing file in the area before writing (so path rules load); packs load by trigger; human-only folders are never opened | the preflight defers to this section instead of restating loading rules. The template ships this section pre-filled with the default order above, and teams may edit it |
| `## Working style` | how the AI should interact (one question at a time, push back, …) | interactive steps (clarify, gates) follow it |

Rules for the template:
- under 200 lines;
- no versions, module lists or tooling (those live in tech-stack.md and the code);
- no rule that an ADR or another rule file already carries: cite the ADR instead.

### 8.3 Framework adjustments that follow from these shapes
- **Rules are never re-read by the framework.**
  - Implement and test sessions rely on path loading. The build step opens an existing file in the area before writing, per `## Starting work`.
  - `context.sh` lists matching rule files only for review and verify, which start from `git diff` and so trigger no path loading.
- **tech-stack.md holds commands only.** Build, test, lint, typecheck, the migration tool, the test layout, E2E tooling and coverage thresholds. Drop versions and the 90-day refresh; manifests and ADRs already hold them.
- **Review can delegate to the project.**
  - New profile key `review.commands: {<Project>: <skill-or-command-name>}`.
  - `sk.review --projects X` runs the mapped command via the Skill tool, records its verdict, and links its report from `delivery.md`.
  - The framework's own review procedure is the fallback when nothing is mapped.
- **Contract codegen runs once per unit**, at the end of design's contracts step and after its gate. That way generated client packages exist before any consumer's implement session. `contracts.verify` stays optional.
- **Shared-library projects.** A projects-index row may be a library folder shared by several apps (Type = the consumers' type, CodeRoot = the library folder), so every per-project session stays single-root. The Mobile type has its own `mobile` role in `roles.yaml`.
- **Registry matching.**
  - `context.sh` accepts a superset of the phase vocabulary and ignores unknown phases.
  - Always scopes by project name match the projects index exactly, and sk.init warns on a mismatch.
- **ADR authoring.** `knowledge.adr.exemplar` may point to an existing ADR. Any authoring rule the project keeps under `.claude/rules/` loads by path when sk.adr reads an ADR, and outranks the framework's ADR template.
- **CLAUDE.md managed region ≤ 15 lines:** the command list, `story-status.sh`, and the archive rule. A project without a CLAUDE.md gets a file with only this region.
- **In-flight units are records, not knowledge.**
  - `sk.init` offers the adopting project an ADR (from a framework template) stating that `specs/intents/` is a work record, that promotion at ship is the only route into the homes, and that unit artifacts rank below ADRs, rules and packs.
  - It also offers a matching router block for the adr-index. Both are written only if the team accepts.

### 8.4 Where changes live
- **Framework repo (this one):** §1–§8. Templates, sk.init and governance use only the default paths and shapes above.
- **Each adopting project:** runs `sk.init --answers <file>` on an adoption branch. That writes:
  - `.specify/profile.yaml`: `never_autoload`, `review.commands`, `contracts.codegen`, `knowledge.domain.template`, `knowledge.adr.exemplar`;
  - the projects index and per-project tech-stack.md;
  - `.gitignore` for `.specify/state/`, the merged hooks, and the CLAUDE.md region;
  - optionally, the work-pipeline ADR and its router block.

  Project-specific names, commands and paths live only there.
- **Nothing new.** No adapter repo: the profile is the adapter.

### 8.5 Pilot on an adopted project
After the framework lands, run one small real unit in a project that already has this knowledge layer: one Backend project plus one Frontend project.
- `/sk.story` → `/sk.design` → `/sk.plan` → `/sk.implement --projects <backend>` → `/sk.implement --projects <frontend>` → `/sk.test` → `/sk.review` (delegated where mapped) → `/sk.verify`.
- Each command runs in a fresh session. Record `/context` at session start and at each gate.

Success criteria:
- no framework file names the project or restates its ADRs or rules;
- gates pause and resume, and status lands;
- a backend implement session fits comfortably after its auto-loaded rules and routed ADRs.

## 9. Reinstall and update contract
Workflow: change the framework → `git subtree pull --prefix=.speckit …` in the project → `bash .speckit/setup.sh`. The installed project then matches the new framework version exactly, and nothing project-owned changes.

`setup.sh` is idempotent: a second run with no framework change produces no diff. It stays within its ownership contract (the header of `setup.sh`), with three additions so that removals propagate:
- **Manifest-driven pruning.**
  - `.claude/.speckit-manifest` lists every file setup.sh wrote: `sk.*` dirs, governance, agents, hook scripts.
  - On re-run, a path in the previous manifest that the new version no longer ships is removed.
  - Removal goes through the project's archive policy when `archive-file.sh` is present; otherwise it is deleted.
  - Today only `sk.*` dirs are pruned. Agents (named list) and `.claude/hooks/*.sh` are not, so a dropped hook script or agent would linger.
- **Settings merge owns its entries.**
  - Framework hook entries in `.claude/settings.json` are identified by their command path (`$CLAUDE_PROJECT_DIR/.claude/hooks/…`).
  - On re-run they are replaced by the current set, so changed, added (e.g. `SessionStart`) and removed hooks all apply.
  - Project-added hooks, `allow` and `defaultMode` are untouched. `deny` stays a union.
- **Seeded files are seeded once.**
  - `sk.init` (not setup.sh) writes `principles.md`, the profile and the projects index, and only when absent.
  - A framework template change never overwrites them. `sk.init` in re-detect mode reports sections a newer template adds, for the team to adopt by hand.

Version bump: `VERSION` changes with every framework change that setup.sh ships; the manifest records it.

## Critical files
- `.claude/hooks/lib-story.sh`, `post-response.sh`, `skill-start.sh`, `validate-path.sh`
- new: `context.sh`, `verify-evidence.sh`, `governance/roles.yaml`, `agents/sk-reviewer.md`
- `.claude/skills/sk.{story,design,plan,implement,test}/` (prompt.md plus new `steps/`); `sk.verify`, `sk.review`, `sk.ff`
- `.claude/skills/governance/{preflight,phase-layout,quality-gates,pack-resolution,profile,review-gate}.md`
- `setup.sh`, `templates/root/CLAUDE.md`, `templates/root/settings.speckit.json`, `templates/artifacts/*`
- new `templates/project/.claude/rules/principles.md`; remove `templates/project/.specify/memory/constitution.md`, `templates/project/specs/knowledge-base.md` and `templates/project/history/`
- `templates/project/.specify/profile.yaml` (keys: `review.commands`, `knowledge.principles`; drop the constitution and tier-1 keys), `sk.init` (seeds principles when absent, offers the work-pipeline ADR)
- `tests/hooks-test.sh`, `tests/install-test.sh`

## Verification
- **`tests/hooks-test.sh`**, new cases:
  - start `sk.test` → Stop without `SK_RESULT` (gate pause) → Stop with `SK_RESULT: PASS` → status moves to `review`;
  - the role persists across turns and is cleared by SessionStart and by the next skill start;
  - `/sk.implement --projects web` gets role `frontend` and is denied `03-plan/**`;
  - each role in `roles.yaml` is denied its expected paths (engineer and QA roles → `03-plan/**`, architect → `03-plan/**`–`07-security-audit/**`, …).
- **`tests/install-test.sh`:**
  - `_sub_` dirs are gone downstream;
  - no role agent files are installed;
  - `sk-reviewer.md` is installed.
- **Script checks:** `context.sh` and `verify-evidence.sh` against the fixture from `.specify/state/make_fixture.py`, with 2 projects: rules filtered by paths, packs selected deterministically.
- **Framework checks:** the stack-leak grep (`ai_reports/framework-project-skills-separation-plan.md` §6), extended to the adopting project's names as a local, untracked check. No remaining references to `_sub_`, `set-worker-role`, `worker-dispatch`, `inject_files`, `constitution` or `history/prompts`.
- **Install checks:**
  - `principles.md` is seeded when absent and left untouched when present.
  - The CLAUDE.md region is ≤ 15 lines, and a project without a CLAUDE.md gets only the region.
- **Reinstall checks (`tests/install-test.sh`):**
  - Install version N, then re-run setup with no change: no diff.
  - Install N, then N+1 with an agent, a hook script, a governance file and an `sk.*` dir removed and one hook entry changed:
    - all four removed items are gone (archived when `archive-file.sh` exists);
    - the settings hook set equals N+1's;
    - project-added hooks, rules, skills, commands, `principles.md` and the profile are byte-identical.
- **Manual end-to-end** on a scratch repo with Backend + Frontend projects:
  - `/sk.story` → new session `/sk.design` → `/sk.plan` → `/sk.implement --projects api` → `/sk.implement --projects web` → `/sk.test --projects …` → `/sk.verify`;
  - check `/context` at the start of each session and at each gate;
  - confirm gates pause and resume, and that status transitions land.
