# sk.ship
Quality-gated release: promote, gate, PR.
Role: lead | Level: story

## Mode
- `sk.ship` → [SHIP] promote, run the Ship Gate, commit, push, open the PR.
- `sk.ship --dry-run` → [DRY RUN] show the promotion list and the PR title/base. Writes nothing, commits
  nothing, pushes nothing, and emits no `SK_RESULT:` line (so the story does not move).
Declare the mode at start.

## Pre-flight
1. Run the story pre-flight in `.claude/skills/governance/preflight.md` (active story → `01-story/story.md`).
2. Read `.specify/profile.yaml` keys `vcs.*`, `rules.stacks`, `knowledge.adr.guard`, `knowledge.domain.template`,
   `tracker.kind` (defaults in `.claude/skills/governance/profile.md`).
3. `git branch --show-current` → `{branch}`. If `{branch}` equals `vcs.base_branch` (default `dev`): STOP —
   promotion and the PR happen on the feature branch.

## Hard blocks
Enforced by `skill-start.sh` from the SKILL.md preconditions and re-checked here:
- story verify-status ≠ PASS → STOP: run sk.verify until PASS
- story security-status = blocked → STOP: resolve security-audit findings first
- story test-status ≠ pass → STOP: run sk.test (and sk.uat for user-facing units) until pass
- story checkpoint_mode unset → STOP: classify the story (sk.story) first

## Context loading
- UNIT_DIR/01-story/story.md → id, title, `story_type`, `jira_id`; UNIT_DIR/01-story/acceptance-criteria.md → summary
- UNIT_DIR/unit-brief.md → Impacted Projects
- UNIT_DIR/02-design/contract-changes.md → changed operations and compatibility classes (PR description)
- The promotion sources listed in `.claude/skills/governance/promotion.md` → What to promote
Never read another shipped unit, or any path in `knowledge.never_autoload`.

## Step 1 — Promotion (`.claude/skills/governance/promotion.md`)
1. Read the active unit's `knowledge-base.md`, `02-design/architecture.md`, `02-design/contract-changes.md`,
   `investigation-report.md` (if any) and `04-implementation/{Project}/review-*.md`.
2. Classify each non-derivable item to exactly one target per promotion.md → What to promote. Skip anything
   derivable from the code, the contracts or git history. Do not copy unit prose.
3. Show the promotion list: `| Item | Target | Change |`. [DRY RUN] stop here and go to Step 5.
   `checkpoint_mode` `confirm` or `validate` → ask "Apply this promotion? (y/n)"; on n, revise the list.
4. Apply each item:
   - **ADR** → invoke `Skill(sk.adr)` with the decision, its context and the alternatives from the unit. sk.adr
     creates `specs/adr/NNNN-kebab-title.md` and routes it in `specs/adr/adr-index.md`.
   - **Domain rule / invariant / rationale** → write into the existing section of `specs/domain/{module}.md`
     that fits (the smallest new heading when none does). A new module file uses `knowledge.domain.template`
     and is registered in `specs/domain/bounded-contexts.md` in the same change.
   - **Checkable coding rule** → `.claude/rules/{stack}/<topic>.md`, where `{stack}` is the folder
     `rules.stacks` maps to the project the rule governs. Add to an existing topic file when one fits.
     Per the writing rules in `.claude/skills/governance/profile.md`: self-contained, under 200 lines,
     `paths:` frontmatter scoped to the files it governs, provenance only as `Source: ADR-NNNN` (when an ADR
     exists), never an `@import`.
   - **System-level context** (why the system exists, a new actor, a new domain) → invoke
     `Skill(sk.knowledge-base)` with `--tier system`.
5. Write `UNIT_DIR/promotion.md` in the format of promotion.md → Record, or the single line
   `Nothing to promote — {reason}.`

## Step 2 — Ship Gate (`.claude/skills/governance/quality-gates.md` → Ship Gate)
- [ ] `UNIT_DIR/promotion.md` exists and every row's target was changed on this branch.
- [ ] ADR guard: `bash {SCRIPTS_DIR}/check-adr-index.sh` passes (`SCRIPTS_DIR` per
      `.claude/skills/governance/framework-paths.md`; SKIP when `knowledge.adr.guard: false`).
- [ ] Tracker mirror (when `tracker.kind` is not `none`): `bash .claude/hooks/story-status.sh show` lists no
      pending or failed entry for this story. Pending → process them per
      `.claude/skills/governance/tracker-mirror.md`; failed → offer `story-status.sh mirror-retry`, then re-check.
Any FAIL → STOP, report the failing item, emit `SK_RESULT: FAIL`.

## Step 3 — Commit and push
1. `git status --porcelain`. Stage by name, never `git add -A` / `git add .`: the promotion targets,
   `UNIT_DIR/promotion.md`, and any other unit or code change the user confirms. Never stage `.specify/state/`.
2. Commit message per `vcs.commit`:
   - `conventional` (default): `type(scope): subject` — for the promotion commit
     `docs({unit-id}): promote unit knowledge`; `type` `feat` / `fix` for any remaining work of the story.
   - `free`: a one-line summary.
3. `git push -u origin {branch}`.

## Step 4 — PR
Fill `vcs.pr_title` (default `[{ticket}] {Kind} / {title}`):
`{Kind}` = `Fix` when `story_type` is `bug` or `hotfix`, else `Feature`; `{ticket}` = the story's `jira_id`,
else `vcs.no_ticket` (default `NO TICKET`); `{title}` = the story title; `{story}` = the story ID.

```
gh pr create --base {vcs.base_branch} --head {branch} --title "{pr_title}" --body "{body}"
```
Body:
```
## Summary
{acceptance criteria summary}

Story: {story-id}
Impacted projects: {projects from unit-brief.md}

## Contract changes
{operations and compatibility class from 02-design/contract-changes.md, or "none"}

## Promotion
{rows of UNIT_DIR/promotion.md}

## Quality gates
- sk.verify: PASS
- test-status: pass
- security-status: {clear | conditional}
```
If a PR for `{branch}` already exists (`gh pr view`), update its title and body (`gh pr edit`) instead.
If `gh` is unavailable: STOP, print the title, base and body for the user to open by hand, and emit
`SK_RESULT: FAIL` (the PR was not created).

## Step 5 — Report
- [SHIP] PR URL, promotion summary, and: "On PASS the Stop hook sets `status.current: shipped`; the unit folder
  is then frozen (only sk.rollback and sk.hotfix may write there). New work on this feature starts a new unit."
- [DRY RUN] the promotion list, PR title, base branch and head branch. No `SK_RESULT:` line.

## Quality Bar (hard blocks — no exceptions)
- verify-status must be PASS, security-status not blocked, test-status pass
- Promotion recorded in `UNIT_DIR/promotion.md` before the PR
- Promotion writes only to the homes in `.claude/skills/governance/profile.md`; nothing kept twice
- This skill never edits `status.current`; the Stop hook applies `shipped`

## Completion Signal
[SHIP] — last line of output must be exactly one of (see `.claude/skills/governance/status-model.md`):
`SK_RESULT: PASS` — promotion recorded and the PR created
`SK_RESULT: FAIL` — a hard block or the Ship Gate stopped the ship (the story status is not advanced)
[DRY RUN] — no `SK_RESULT:` line.
