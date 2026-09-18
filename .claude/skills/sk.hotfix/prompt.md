# sk.hotfix
P0 incident fast path — 3-gate: plan → implement → ship.
Role: lead | Level: story

## Mode declaration
Declare at start: `[HOTFIX MODE] P0 fast path active — spec artifacts bypassed.`

## Pre-flight
1. Run the story pre-flight in `.claude/skills/governance/preflight.md`.
   No active story → STOP: create a hotfix story first (sk.story --bug, set story_type: hotfix)
2. Verify `01-story/story.md` frontmatter has story_type: hotfix OR user explicitly confirmed P0 override
   MISSING → STOP: this skill is for P0 incidents only; use sk.plan + sk.implement for normal stories
3. Identify the affected project(s) from the Impacted Projects table (or ask); record `{Project}` / `{CodeRoot}`.
4. Create hotfix branch: hotfix/{story-id} from main (not dev)
   Report branch name before proceeding

## Context loading
1. UNIT_DIR/01-story/ — expected behavior, actual behavior, reproduction steps, acceptance criteria
2. UNIT_DIR/02-design/architecture.md (if exists — read for blast radius)
3. .specify/memory/architecture-decisions.md
4. The project's coding-standards.md

## Gate 1 — Plan (abbreviated)
Write a minimal plan covering:
- Root cause hypothesis (1–3 sentences)
- Exact files/components to change (list paths within {CodeRoot})
- Blast radius: services affected, dependent consumers at risk
- Rollback method: what to revert if the fix makes things worse
- Acceptance criteria mapping: each criterion → how it will be verified

Write to: UNIT_DIR/03-plan/{Project}/hotfix-plan.md
Pause and display plan. Ask: "Confirm plan and proceed to implement? (y/n)"
On n → revise until confirmed.

## Gate 2 — Implement
Resolve capability packs per `.claude/skills/governance/pack-resolution.md`; phase = `implement`,
in-scope project = `{Project}` (hotfix scope is narrow: at most 3 packs).
Execute the fix:
- Change only files listed in the plan's blast radius
- Write or update tests covering the broken acceptance criterion
- No refactors, no cleanup, no opportunistic changes outside the fix scope
- After each file changed: report file path and what changed

Verify locally:
- Run the targeted test(s)
- If tests pass: proceed
- If tests fail: diagnose and fix before gate 3

Set `status.current` → in-progress (and `status.entered_at` → now) in `01-story/story.md` frontmatter.

## Gate 3 — Ship
Hard blocks (same as sk.ship, but scoped to hotfix):
- Targeted tests must pass
- Blast radius services must be identified and noted in PR description

Skip: sk.verify full suite, sk.uat, sk.plan_sub_analyze (not applicable for P0 speed)
Record skip rationale in PR description: "P0 hotfix — full verify deferred to post-incident review"

Create PR:
- Base: main (not dev)
- Title: `[hotfix] {story-id}: {story title}`
- Body:
  ```
  ## P0 Hotfix
  **Root cause:** {root cause}
  **Fix:** {what changed}
  **Blast radius:** {affected services}
  **Rollback:** {rollback method from plan}
  **Tests added:** {test names}

  > Full sk.verify deferred to post-incident review.
  ```

If gstack installed: `gstack /ship --base main`
Else: `git push -u origin hotfix/{story-id}` then `gh pr create` as above.

## Post-ship
After merge:
1. Ask the user: "Create rollback-plan.md (sk.rollback --plan) now or after the incident window closes?"
2. Recommend scheduling post-incident sk.verify to close the deferred gate

## Output Artifacts
UNIT_DIR/03-plan/{Project}/hotfix-plan.md
{CodeRoot}/** (fix files)
PR (base: main)

## Quality Bar
- Plan confirmed before any code written
- Fix scope limited to plan blast radius — no opportunistic changes
- Targeted tests pass
- PR base is main, not dev
- Rollback method documented in PR body
