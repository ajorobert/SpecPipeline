# Migration (schema-owning project)
From the project's tech-stack.md → Migrations: **Tool**, **Location**, **Rollback** policy, **Tests**
(`required` | `none`). A field that is missing: ask the human for it, use the answer for this run, and say
it belongs in tech-stack.md. Never assume one.

## Expand (default)
The database-design.md changes that add: tables, columns, indexes, constraints.
- One migration at the Location, in the Tool's format and naming (no convention: `{timestamp}_{story-id}_{name}`).
- Add-only: no drop, no destructive alter. Any guard the Tool, ADRs or rules require.
- Each change annotated with its database-design.md entity.

## Contract
Removing what an earlier expand deprecated — only after the human confirms every consumer has moved off
it. Note the expand migration it completes. It cannot be rolled back automatically: say so.

## Rollback
Per the Rollback policy: a reverse migration for each change, or — forward-only — a compensating
migration described step by step. Write `UNIT_DIR/rollback-plan.md`: the steps in dependency order, each
marked `SAFE` or `DATA LOSS: {what}`.

## Tests
`Tests: required` — at the Test Layout: applies cleanly from the prior state; the rollback restores it
(expand only); re-applying changes nothing where the Tool supports it. `none` — log `SKIP — Migrations
Tests: none`.
