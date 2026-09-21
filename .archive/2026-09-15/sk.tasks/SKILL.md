---
name: sk.tasks
description: "Legacy/optional sub-skill. Generates a story-level task breakdown (tasks.yaml). SUPERSEDED in the multi-project flow: sk.plan now produces a per-project task list at 03-plan/{Project}/tasks.md, which sk.implement consumes directly — so sk.implement no longer calls sk.tasks by default. Kept for ad-hoc story-level task generation. Role: lead."
subagent_type: SpecKit Lead Agent
inject_files:
---

> **Status: legacy / optional.** In the current multi-project architecture, the per-project task list is
> produced by `sk.plan` (via `sk.planproject`) at `03-plan/{Project}/tasks.md` and consumed directly by
> `sk.implement` → `sk.implementproject`. This skill is no longer in the default implementation pipeline;
> it remains available for ad-hoc story-level task generation.

Generates phased task breakdown for a story. TDD order: tests before implementation.
Requires plan.md and approved checkpoint (if confirm/validate mode).

Not in the default sk.implement flow — invoke explicitly only when a standalone story task list is needed.

Read and execute the full workflow in `prompt.md` in this directory.
