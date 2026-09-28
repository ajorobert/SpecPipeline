---
name: sk.hotfix
description: "P0 fast path for a hotfix story: minimal confirmed plan, the fix and its tests in one project, then commit, push and a PR — full verify and promotion deferred to post-incident review."
role: engineer
disable-model-invocation: true
---

# sk.hotfix
One session, one project, one fix. Say at the start: `[HOTFIX] P0 fast path — design and plan phases bypassed.`

## Pre-flight
1. Run `.claude/skills/governance/preflight.md` with command `hotfix --projects <name>` (ask for the project
   when the unit has several). No active story: STOP — `/sk.story --bug` with `story_type: hotfix` first.
2. `story_type` is not `hotfix` and the human has not confirmed a P0 override: STOP — use the normal pipeline.
3. Base = `vcs.hotfix_base`, else `vcs.base_branch` (default `dev`). Branch = `vcs.branch` with `{kind}` =
   `fix`, `{topic}` = the story title in kebab case. On it already: keep it. Otherwise, with pending
   changes, ask how to proceed (never stash or discard unasked); then checkout base, `git pull --ff-only`
   (skip without a remote), and create the branch. Say which.
4. A shipped (frozen) unit: sk.hotfix may write its `hotfix-plan.md` there; nothing else changes in it.

## Gate 1 — Plan
Write `03-plan/{Project}/hotfix-plan.md`: the root-cause hypothesis (1–3 sentences), the exact files to
change inside {CodeRoot}, the blast radius (projects and consumers at risk, from the router and the spec
files touched), the rollback method, and each acceptance criterion with how it is verified. Show it and ask
"Confirm and implement?"; revise until yes.

## Gate 2 — Fix
Status `draft` or `ready`: `bash .claude/hooks/story-status.sh set in-progress --by sk.hotfix`. Open the
files you change first (their rules load), change only the planned files, add or update the test covering
the broken criterion, and report each file changed. No refactors, no cleanup. Run the targeted tests; fix
until they pass.

## Gate 3 — Ship
Stage the fix, its tests and hotfix-plan.md by name (never `.specify/state/`). Commit per `vcs.commit`
(`fix({scope}): {subject}`); `git push -u origin {branch}`. PR to the base with the `vcs.pr_title` title
(`{Kind}` = Fix) and body: root cause, fix, blast radius, rollback, tests added, and "Full sk.verify and
promotion deferred to post-incident review." No `gh`: print them for the human.

## Completion report
```
sk.hotfix — {story-id}: {PR url}
Deferred: sk.verify and promotion — schedule them after the incident window
```
