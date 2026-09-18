# sk.ship
Quality-gated release.
Role: lead | Level: story
gstack: optional — if installed, use `gstack /ship`; otherwise use `gh pr create`

## Pre-flight
Run the story pre-flight in `.claude/skills/governance/preflight.md` (active story → `01-story/story.md`).

## Hard quality gate
Run sk.verify before proceeding.
sk.verify result must be PASS.
ANY failing gate → STOP. Report the failing gate. Do not invoke gstack /ship.

Additional hard blocks (also enforced by check-skill-preconditions.sh):
- story security-status = blocked → STOP: resolve security-audit findings first
- story test-status ≠ pass → STOP: run sk.test (and sk.uat for user-facing units) until pass
- story checkpoint_mode unset → STOP: classify the story (sk.story) first

## Context loading
- UNIT_DIR/01-story/story.md → title, branch, and UNIT_DIR/01-story/acceptance-criteria.md summary
- UNIT_DIR/unit-brief.md → impacted projects
- .specify/memory/service-registry.md → affected services for PR description

## Context surface
Before invoking gstack /ship:

"Shipping story: {story-id} — {story title}
Branch: {branch}
Affected projects/services: {services}
Quality gates: sk.verify PASS, test-status = pass, security-status = {clear | conditional}"

## Invoke
If gstack is installed (`command -v gstack`):
  gstack /ship
Else:
  git push -u origin {branch}
  gh pr create --title "[lead] {story-id}: {story title}" --body "## Summary\n{acceptance criteria summary}\n\n## Quality Gates\n- sk.verify: PASS\n- test-status: pass\n- security-status: {clear | conditional}" --base dev

## Post-execution
On successful ship:
- Report PR URL or deployment reference from gstack output
- The PostToolUse hook sets `status.current: shipped` in `01-story/story.md`

## Quality Bar (hard blocks — no exceptions)
- sk.verify must be PASS
- security-status must not be blocked
- test-status must be pass

## Completion Signal
Last line of output must be exactly one of (see `.claude/skills/governance/status-model.md`):
`SK_RESULT: PASS` — the PR was created
`SK_RESULT: FAIL` — a hard block stopped the ship (the story status is not advanced)
