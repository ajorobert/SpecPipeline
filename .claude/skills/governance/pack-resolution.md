# Capability Pack Resolution
Framework-owned procedure. Every sk.* prompt that needs stack or pattern knowledge references this
file with one line:

> Resolve capability packs per `.claude/skills/governance/pack-resolution.md`; phase = `<phase>`.

Capability packs are **project-owned** skills (for example `.claude/skills/<pack>/SKILL.md`). The
framework never names a pack and never globs `.claude/skills/` to discover one. Projects register
their packs in `.specify/memory/skill-routing.md`, the only bridge between the framework and the
project's skills. Rule of thumb: skills carry grammar (the project-neutral "how"); project memory
carries vocabulary (the per-project "what" and "where").

## Inputs
- **phase**: given by the caller. One of `design | implement | review | test | uat | perf | refactor`.
- **in-scope projects**: the `{Project}` / `{ProjectType}` passed by the orchestrator. If none was
  passed, use every row of `unit-brief.md` → Impacted Projects. If there is no unit, map session.yaml
  `role`: `backend` → Backend, `frontend` → Frontend, `mobile` → Mobile.
- **signals**: the active story's `tags[]` (from `01-story/story.md` frontmatter), plus the text of
  the artifacts the caller is working from (story, requirement, plan, design slice, or the
  user-supplied scope statement for sk.refactor / sk.perf).

## Procedure
1. Read `.specify/memory/skill-routing.md`.
   If it is missing, log `Pack resolution (phase={phase}): no skill-routing.md — no packs loaded.`
   and continue the skill without packs. Never STOP because of a missing manifest.
2. **`## Always`**: select every row whose Scope matches. A Scope is one of:
   - a phase name (for example `design`)
   - a project type (`Backend | Frontend | Mobile`) of an in-scope project
   - the exact name of an in-scope project
   - `{type-or-project}@{phase}`, which matches only when both parts match (for example `Backend@review`)
3. **`## By signal`**: select every row that meets all three conditions:
   - its Phases column contains the phase
   - its Applies-to column is `any` or matches an in-scope project type
   - at least one Signal matches, either exactly against a story tag or as a case-insensitive
     whole-word match in the signal text
4. De-duplicate paths, keeping the first occurrence.
5. Order the selection (the canonical inject order, which keeps the cacheable prefix stable):
   a. Always rows scoped to the phase alone (for example a design principles pack for `design`)
   b. Always rows scoped to a project type or project name, in table order. A project lists its
      canonical pack first.
   c. By-signal rows, in table order
6. Budget: load at most `max_packs` (from the manifest header; default 6). Drop entries from the end
   of the order and log each dropped pack.
7. For each selected path, Read the file in full if it exists. Otherwise log `missing` and skip it.
8. Log the result before continuing:
   ```
   Pack resolution (phase={phase}, projects={names}):
     loaded:  {path}  ← Always:{scope} | signal:{keyword}
     dropped: {path}  (budget)
     missing: {path}
   ```

## Precedence
Loaded packs are pattern guidance. On conflict, apply the higher source and flag the conflict:
`architecture-decisions.md` (ADRs) > `.specify/memory/constitution.md` > `.specify/memory/standards/`
> `02-design/` artifacts > capability packs.

## Rules
- Resolve once per skill invocation, before reading or writing code.
- Orchestrators (`sk.design`, `sk.plan`, `sk.implement`, `sk.test`) do not resolve packs. Each
  sub-skill resolves for its own phase and project.
- A phase with no matching rows is normal. Proceed without packs.
- A pack's own `co_loads_with` / `when_to_load` hints are informational only. Only
  manifest-registered paths are loaded.
