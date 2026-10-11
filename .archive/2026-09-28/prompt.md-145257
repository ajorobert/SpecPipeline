# sk.rollback
Revert a shipped story — automated or manual rollback plan.
Role: lead | Level: story

## Mode detection
- `sk.rollback --auto`   → [AUTO] generate git revert + migration rollback commands, execute on confirm
- `sk.rollback --plan`   → [PLAN ONLY] produce rollback-plan.md without executing anything
- `sk.rollback` (no flag) → ask user which mode
Declare mode at start.

## Pre-flight
1. Run the story pre-flight in `.claude/skills/governance/preflight.md`.
   No active story → ask user: "Which story ID are you rolling back?", locate its `01-story/story.md`, and run
   `sk.session focus --story {id}` so the status command targets it.
2. Read `01-story/story.md` frontmatter:
   - `status.current` must be `shipped` — enforced by `skill-start.sh` from the SKILL.md precondition. A story
     that is not shipped has nothing to roll back: STOP and report its status.
   - Record: branch, tags, `jira_id`, and the impacted projects from `unit-brief.md`.
3. The unit is frozen (`.claude/skills/governance/promotion.md` → Freeze). sk.rollback may write
   `UNIT_DIR/rollback-plan.md` there (`validate-path.sh` allows sk.rollback); it writes nothing else into the unit.
4. Read `03-plan/{Project}/plan.md` for each impacted project (if present) — identify what was changed.
   Read `02-design/contract-changes.md` (changed operations, compatibility class) and `UNIT_DIR/promotion.md`
   (what reached ADRs, domain specs, rules and the system knowledge base).
5. Migrations: for each impacted project whose `.specify/memory/projects/{Project}/tech-stack.md` has a
   `## Migrations` section, take its Tool, Location and Rollback policy. Inspect Location under `{CodeRoot}` for
   migrations whose name carries the story ID or whose timestamp falls in the story's date range.
   Record: migration_files (may be empty) and the rollback policy per project. A project without a
   `## Migrations` section owns no schema — log `SKIP — {Project}: no ## Migrations`.

## Context loading
1. `.specify/memory/projects/index.md` (Role column), the ADRs routed by `specs/adr/adr-index.md` and the
   canonical `specs/openapi/*.yaml` / `specs/asyncapi/*.yaml` operations named in `contract-changes.md` —
   identify dependent consumers of the changed operations
2. `.specify/memory/constitution.md`, the routed ADRs and the schema-owning project's `.claude/rules/{stack}/` —
   the project's own rules for data safety and migration rollback (the framework states none)
3. `UNIT_DIR/rollback-plan.md` from sk.migrate --rollback (if present)
Never read another shipped unit, or any path in `knowledge.never_autoload`.

## Step 1 — Impact assessment
For each affected project and consumer:
- Is the change backwards-compatible? Can consumers tolerate the revert? (use the compatibility class in
  `contract-changes.md`)
- Are there migration files? (→ data risk assessment required, per the project's rollback policy)
- Are there contract changes? (→ consumer notification required)
- Was knowledge promoted? (→ the promoted ADR, domain spec or rule may need a follow-up change)

Report:
- SAFE: revert is transparent to consumers
- WARN: consumers may need coordinated update
- BLOCK: data has been written in the new schema and rollback would cause data loss, or the project's
  rollback policy does not allow reverting the migration

On BLOCK: do NOT proceed. Report the specific data risk and stop. Suggest a forward-fix (sk.hotfix) instead.

## Step 2 — Rollback plan
Write UNIT_DIR/rollback-plan.md covering:

### Code rollback
- Git revert commands (in order): `git revert {commit-sha} --no-edit`
- If merged via PR: `git revert -m 1 {merge-commit-sha}`
- Branch: a revert branch named by `vcs.branch` (`{kind}` = `fix`) from `vcs.base_branch`, merged through a PR
  titled by `vcs.pr_title` with `{Kind}` = `Fix` (defaults in `.claude/skills/governance/profile.md`)

### Migration rollback (per migration file)
For each migration in migration_files, following the project's `## Migrations` rollback policy:
- Rollback method: the down migration / rollback script (from sk.migrate rollback-plan.md, if it exists), or a
  new forward migration that restores the previous shape when the policy allows no down migrations
- Data loss annotation: SAFE / DATA LOSS: {what is lost}
- Execution order: migrations roll back in reverse apply order

### Config / feature flag rollback (if applicable)
- List any config changes or feature flag toggles to revert

### Promoted knowledge (if `promotion.md` lists items)
- For each promoted item: keep, amend, or supersede (an ADR is superseded through sk.adr, never deleted)

### Consumer coordination (if WARN)
- List the consumers that must be notified or updated concurrently
- Recommended rollout order

### Verification steps
After rollback:
1. Smoke test: {key operation or behaviour to verify}
2. Check: dependent consumers responding normally
3. Confirm: no error spike in logs/observability

## Step 3 — [AUTO mode only] Execute
Display the full rollback-plan.md.
Ask: "Execute this rollback now? This cannot be undone. (yes / no)"
Exact string "yes" required — any other input → STOP.

On "yes":
- Create the revert branch, execute the git revert commands, commit (`vcs.commit`: conventional →
  `revert({scope}): {subject}`), push, open the PR with base `vcs.base_branch`
- Run the migration rollback commands in the planned order
- Report each step as it completes
- STOP immediately on any failure and report state (the story status does not move)

## Step 4 — Post-rollback
1. [AUTO] When every step succeeded: `bash .claude/hooks/story-status.sh set rolled-back --by sk.rollback`.
   [PLAN ONLY] Ask whether the rollback has been carried out; only on an explicit yes, run the same command.
   The command also queues the tracker mirror (`.claude/skills/governance/tracker-mirror.md`).
2. Note: run sk.story --bug to capture a bug story for the root cause, if not already done. Re-delivery
   starts a new unit.

## Output Artifacts
specs/intents/{intent}/units/{unit}/rollback-plan.md
status.current → rolled-back via story-status.sh (when the rollback completes)

## Quality Bar
- Every migration in the story accounted for with explicit DATA LOSS annotation, per the project's rollback policy
- BLOCK condition surfaced before any execution
- [AUTO] mode requires exact "yes" confirmation — no default execution
- Rollback plan includes consumer coordination if WARN
- Verification steps are story-specific, not generic
- Status moves only through `story-status.sh`
