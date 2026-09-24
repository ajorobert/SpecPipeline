# Capability Pack Resolution
Framework-owned procedure. Every sk.* prompt that needs stack or pattern knowledge references this
file with one line:

> Resolve capability packs per `.claude/skills/governance/pack-resolution.md`; phase = `<phase>`.

Capability packs are **project-owned** skills at `.claude/skills/<pack>/SKILL.md`. The framework never
names a pack and never globs `.claude/skills/` to find one (the only listing is sk.init's inventory when it
builds the Registry table). The project's one registry is the table under the
`## Registry` heading of `.claude/skills/README.md`; the framework reads it directly.

## The registry table
One row per skill, columns in this order:

| Column | Meaning |
|---|---|
| `Skill` | backticked name = the directory under `.claude/skills/` |
| `Status` | `active` rows are eligible; any other value (`draft`, `deprecated`, …) is skipped |
| `Defers to` | the skill that wins when both load and disagree (informational; `—` for none) |
| `Always` | comma-separated scopes that load the row unconditionally, or `—`. A scope is a phase, a project type (`Backend \| Frontend \| Mobile`), an exact project name, or `{type-or-project}@{phase}` |
| `Signals` | comma-separated lower-case keywords, or `—` |
| `Phases` | subset of `design, plan, implement, review, test, uat`, or `—` (any phase) |
| `Applies to` | `any`, or comma-separated `Backend`, `Frontend`, `Mobile` |
| `Weight` | a number, default `1` |

There is no "Use when" column: the skill's own `description:` is its trigger in ad-hoc work.

## Inputs
- **phase**: given by the caller. One of `design | plan | implement | review | test | uat`.
- **projects in scope**: the `{Project}` / `{ProjectType}` passed by the orchestrator. If none was
  passed, every row of `unit-brief.md` → Impacted Projects. If there is no unit, map session.yaml
  `role`: `backend` → Backend, `frontend` → Frontend, `mobile` → Mobile.
- **tags**: the active story's `tags[]` (from `01-story/story.md` frontmatter).
- **working text**: the artifacts the caller works from (story, requirement, plan, design slice, or the
  scope statement the caller was given).

## Procedure
1. Read `.claude/skills/README.md` → `## Registry`. If the file or the table is missing, log
   `Pack resolution (phase={phase}): no registry — no packs loaded.` and continue without packs.
   Never STOP because of a missing registry.
2. **Budget.** `max_packs` = `skills.max_packs` from `.specify/profile.yaml` (default 8). Split it
   across the projects in scope: each project gets `floor(max_packs / N)`, and the remainder goes to
   the projects in Impacted Projects order. Rows loaded for several projects count once, against the
   first project that selected them.
3. **For each project in scope, separately:**
   a. **Eligible rows:** `Status` is `active`; `Applies to` is `any` or contains the project's type;
      `Phases` is `—` or contains the phase. A Frontend project never considers a Backend-only row
      and vice versa.
   b. **Always rows:** eligible rows with an `Always` scope matching this phase, this project's
      type, this project's name, or `{type-or-project}@{phase}` where both parts match. They are
      selected first, in table order, and are not scored.
   c. **Scored rows:** every other eligible row with Signals. For each signal:
      - *tag match* — the signal equals a story tag (exact, case-insensitive);
      - *context match* — the signal occurs in the working text as a whole word or phrase,
        case-insensitive, **and is not negated**: an occurrence preceded within the same clause by
        `no`, `not`, `without`, `non-`, `never`, `n't`, `excluding` or `out of scope` does not count.
      `score = Weight × (3 × tag matches + 1 × context matches)`. Rows scoring 0 are not selected.
   d. Fill the project's share: Always rows, then scored rows by descending score (ties: table order).
      An Always row that does not fit the share is still loaded and logged as `over budget`.
4. **Load order** (keeps the cacheable prefix stable): phase-only Always rows; then per project, in
   Impacted Projects order, its type/name Always rows, then its scored rows.
5. Read each selected `.claude/skills/<Skill>/SKILL.md` in full. Missing file → log `missing`, skip.
6. **Log every candidate**, selected or not, before continuing:
   ```
   Pack resolution (phase={phase}, max_packs={n}):
     {Project} ({Type}, share {k}):
       loaded   {skill}  Always:{scope}
       loaded   {skill}  score {s} = {w} × (3×{t} tag [{tags}] + {c} context [{signals}])
       skipped  {skill}  score {s} (below share)
       skipped  {skill}  score 0 (negated: "{snippet}")
       n/a      {skill}  applies to {types}
     missing  {skill}
   ```

## Precedence
Loaded packs are pattern guidance. On conflict they lose to the sources above them in
`governance/profile.md` → Precedence (constitution, ADRs, rules), and win over the unit's `02-design/`
and existing code only where they carry a rule the design did not decide. Flag every conflict.

## Rules
- Resolve once per skill invocation, before reading or writing code.
- Orchestrators (`sk.design`, `sk.plan`, `sk.implement`, `sk.test`) do not resolve packs. Each
  sub-skill resolves for its own phase and project.
- A phase with no eligible rows is normal. Proceed without packs.
- A pack's own `co_loads_with` / `when_to_load` hints are informational only. Only registry rows load.
- The story tag vocabulary (sk.story_sub_specify) is the union of the registry's Signals column.
