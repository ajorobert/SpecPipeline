# sk.hotfix
P0 incident fast path — 3-gate: plan → implement → ship.
Role: lead | Level: story

## Mode declaration
Declare at start: `[HOTFIX MODE] P0 fast path active — spec artifacts bypassed.`

## Pre-flight
1. Run the story pre-flight in `.claude/skills/governance/preflight.md`.
   No active story → STOP: create a hotfix story first (sk.story --bug, set story_type: hotfix)
2. Verify `01-story/story.md` frontmatter has story_type: hotfix OR the user explicitly confirmed a P0 override.
   MISSING → STOP: this skill is for P0 incidents only; use sk.plan + sk.implement for normal stories
3. Identify the affected project(s) from the Impacted Projects table (or ask); record `{Project}` / `{CodeRoot}`
   (`.claude/skills/governance/project-resolution.md`).
4. Read `.specify/profile.yaml` keys `vcs.*` (defaults in `.claude/skills/governance/profile.md`):
   base = `vcs.hotfix_base`, else `vcs.base_branch` (default `dev`).
5. **Fix branch** — branch name = `vcs.branch` (default `{kind}/{topic}`) with `{kind}` = `fix`,
   `{topic}` = the story title in kebab case, `{ticket}` = `jira_id` or `vcs.no_ticket`, `{story}` = the story ID.
   - Already on that branch → keep it.
   - Otherwise run `git status --porcelain`; with pending changes, ask the user how to proceed (never stash or
     discard without confirmation). Then `git checkout {base}` → `git pull --ff-only` (skip if no remote) →
     `git checkout -b {branch_name}`.
   Report the branch name and base before proceeding.
6. If the unit is shipped (frozen): note it. sk.hotfix may write `hotfix-plan.md` into it (`validate-path.sh`
   allows sk.hotfix); every other artifact stays in its home.

## Context loading
1. UNIT_DIR/01-story/ — expected behavior, actual behavior, reproduction steps, acceptance criteria
2. UNIT_DIR/02-design/architecture.md (if it exists — read for blast radius)
3. `specs/adr/adr-index.md` → the ALWAYS ADRs and those whose signals match the fix
   (loading rules in `.claude/skills/governance/profile.md`); `.specify/memory/constitution.md`
4. The project's coding rules: the `.claude/rules/{stack}/` folders mapped to `{Project}` by `rules.stacks`
5. `.specify/memory/projects/{Project}/tech-stack.md` — test framework, Test Layout, Forbidden Skip Idioms
Never read a path in `knowledge.never_autoload`, or another shipped unit.

## Gate 1 — Plan (abbreviated)
Write a minimal plan covering:
- Root cause hypothesis (1–3 sentences)
- Exact files/components to change (list paths within {CodeRoot})
- Blast radius: projects affected, dependent consumers at risk (consumers from `.specify/memory/projects/index.md`
  Role and the canonical `specs/openapi/*.yaml` / `specs/asyncapi/*.yaml` the change touches)
- Rollback method: what to revert if the fix makes things worse
- Acceptance criteria mapping: each criterion → how it will be verified

Write to: UNIT_DIR/03-plan/{Project}/hotfix-plan.md
Pause and display the plan. Ask: "Confirm plan and proceed to implement? (y/n)"
On n → revise until confirmed.

## Gate 2 — Implement
Resolve capability packs per `.claude/skills/governance/pack-resolution.md`; phase = `implement`,
in-scope project = `{Project}` (hotfix scope is narrow: at most 3 packs).
If `status.current` is `draft` or `ready`: `bash .claude/hooks/story-status.sh set in-progress --by sk.hotfix`.
Execute the fix:
- Change only files listed in the plan's blast radius
- Follow the constitution, the routed ADRs and the project's `.claude/rules/{stack}/` files
- Write or update tests covering the broken acceptance criterion
- No refactors, no cleanup, no opportunistic changes outside the fix scope
- After each file changed: report file path and what changed

Verify locally:
- Run the targeted test(s)
- If tests pass: proceed
- If tests fail: diagnose and fix before gate 3

## Gate 3 — Ship
Hard blocks (same as sk.ship, but scoped to hotfix):
- Targeted tests must pass
- Blast radius projects must be identified and noted in the PR description

Skip: sk.verify full suite, sk.uat, sk.plan_sub_analyze, promotion (not applicable for P0 speed)
Record the skip rationale in the PR description: "P0 hotfix — full verify and promotion deferred to post-incident review"

Commit — stage the fix files, their tests and `hotfix-plan.md` by name (never `git add -A`, never `.specify/state/`).
Message per `vcs.commit`: `conventional` (default) → `fix({scope}): {subject}` (`scope` = the unit ID or
project; imperative, lower-case subject); `free` → a one-line summary.
`git push -u origin {branch_name}`.

Create the PR:
- Base: `{base}` (`vcs.hotfix_base`, else `vcs.base_branch`)
- Title: `vcs.pr_title` (default `[{ticket}] {Kind} / {title}`) with `{Kind}` = `Fix`, `{ticket}` = `jira_id`
  or `vcs.no_ticket`, `{title}` = the story title
- Body:
  ```
  ## P0 Hotfix
  **Root cause:** {root cause}
  **Fix:** {what changed}
  **Blast radius:** {affected projects and consumers}
  **Rollback:** {rollback method from plan}
  **Tests added:** {test names}

  > Full sk.verify and promotion deferred to post-incident review.
  ```
`gh pr create --base {base} --head {branch_name} --title "{title}" --body "{body}"`.
If `gh` is unavailable: print title, base and body for the user to open the PR by hand.

## Post-ship
After merge:
1. Ask the user: "Create rollback-plan.md (sk.rollback --plan) now or after the incident window closes?"
2. Recommend scheduling post-incident sk.verify to close the deferred gate, and promotion of any durable
   knowledge from the fix through the next sk.ship.

## Output Artifacts
UNIT_DIR/03-plan/{Project}/hotfix-plan.md
{CodeRoot}/** (fix files and tests)
Fix branch and PR (base: `vcs.hotfix_base`, else `vcs.base_branch`)

## Quality Bar
- Plan confirmed before any code written
- Fix scope limited to plan blast radius — no opportunistic changes
- Targeted tests pass
- PR base and title come from `vcs.*`, with Kind `Fix`
- Rollback method documented in PR body
- Status moves only through `story-status.sh`
