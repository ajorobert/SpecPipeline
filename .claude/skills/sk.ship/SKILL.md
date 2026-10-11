---
name: sk.ship
description: "Ship a verified unit: promote its durable knowledge to ADRs, domain specs and rules, pass the ship gate, commit, push and open the pull request. --dry-run shows the promotion list and PR without changing anything."
role: lead
disable-model-invocation: true
preconditions:
  - story.verify-status == PASS
  - story.test-status == pass
  - story.security-status != blocked
  - "story.checkpoint_mode in [autopilot, confirm, validate]"
---

# sk.ship
Promotes, gates and opens the PR for the active unit, in one session. On PASS the Stop hook sets
`shipped` and the unit folder freezes (`.claude/skills/governance/promotion.md`).

## Pre-flight
1. Run `.claude/skills/governance/preflight.md` with command `ship`. Read `.specify/profile.yaml` → `vcs.*`,
   `rules.stacks`, `knowledge.adr.guard`, `knowledge.domain.template`, `tracker.kind`.
2. On `vcs.base_branch` (default `dev`): STOP — promotion and the PR happen on the feature branch.
3. The preconditions above are enforced at start; re-state any that fails and STOP.

## Steps
1. **Promote** — per promotion.md, from the unit's knowledge base, architecture, contract changes,
   investigation report and each project's review.md. Show `| Item | Target | Change |` (`--dry-run`
   stops here and goes to the report). Confirm or validate: ask "Apply this promotion?" and revise on no.
   Then apply each item:
   - decision with cross-module reach → `Skill(sk.adr)` with the decision, context and alternatives;
   - domain rule, invariant or rationale → the fitting section of `specs/domain/{module}.md` (a new module
     file from `knowledge.domain.template`, registered in `bounded-contexts.md`);
   - checkable coding rule → `.claude/rules/{area}/<topic>.md` (area per `rules.stacks`), added to an
     existing topic when one fits; self-contained, under 200 lines, `paths:` front-matter scoped to what
     it governs, `Source: ADR-NNNN` when an ADR exists, no `@import`.
   Write `promotion.md`, or the single line `Nothing to promote — {reason}.`
2. **Ship gate** — promotion.md exists and every row's target changed on this branch; ADR guard
   `bash {scripts_dir}/check-adr-index.sh` passes (SKIP when `knowledge.adr.guard: false`); tracker
   configured → `bash .claude/hooks/story-status.sh show` has no pending or failed entry for this story
   (pending → process them per `.claude/skills/governance/tracker-mirror.md`; failed → offer
   `mirror-retry`). Any failure: report it and emit `SK_RESULT: FAIL`.
3. **Commit and push** — stage by name (never `git add -A` / `.`, never `.specify/state/`): the promotion
   targets, promotion.md, and the unit or code changes the human confirms. Message per `vcs.commit`
   (`conventional`: `docs({unit-id}): promote unit knowledge`, `feat`/`fix` for remaining work).
   `git push -u origin {branch}`.
4. **PR** — title from `vcs.pr_title` (`{Kind}` = Fix for a bug or hotfix story, else Feature; `{ticket}`
   = `jira_id` or `vcs.no_ticket`; `{title}` = the story title). `gh pr create --base {vcs.base_branch}`,
   or `gh pr edit` when a PR for the branch exists. Body: summary of the acceptance criteria; story id;
   impacted projects; contract changes with compatibility classes (or none); the promotion rows; the
   quality gates (verify PASS, test pass, security status). No `gh`: print title, base and body for the
   human, and emit `SK_RESULT: FAIL`.

## Completion report and signal
```
sk.ship — {unit-id}: {PR url | dry run}
Promoted: {rows | nothing}
```
`--dry-run` prints the promotion list, PR title and branches, and no `SK_RESULT` line. Otherwise the last
line is `SK_RESULT: PASS` (promotion recorded and PR created) or `SK_RESULT: FAIL`.
