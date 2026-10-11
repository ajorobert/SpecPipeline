# Capability Pack Resolution
Framework-owned reference. `.claude/hooks/context.sh` implements this procedure and prints the packs a
command loads; commands never run it by hand. It is written down here so a team can predict and tune
what loads.

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
| `Phases` | a subset of `design, plan, implement, review, test, uat`, or `—` (any phase). Other words (a project's own phases) are allowed and ignored by the framework |
| `Applies to` | `any`, or comma-separated `Backend`, `Frontend`, `Mobile` |
| `Weight` | a number, default `1` |

There is no "Use when" column: the skill's own `description:` is its trigger in ad-hoc work.

## Inputs
- **phase**: the command's phase — `design | plan | implement | review | test | uat` (security-audit and verify use `review`).
- **projects in scope**: the project `--projects` selects, else every row of `unit-brief.md` → Impacted Projects.
- **tags**: the active story's `tags[]` (from `01-story/story.md` frontmatter).
- **working text**: `story.md` and `requirement.md`, plus the project's `plan.md` when `--projects` is given.

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
4. **Output**, per project in Impacted Projects order: its Always rows in table order, then its scored
   rows by descending score —
   ```
   packs (phase={phase}, max_packs={n}):
     {Project} ({Type}, share {k}):
       load  .claude/skills/{skill}/SKILL.md  (Always: {scope}[, over budget])
       load  .claude/skills/{skill}/SKILL.md  (score {s} = {w} x (3x{t} tag [{tags}] + {c} context [{signals}]))
       skip  {skill}  ({why}, below share)
   ```
   The command reads each `load` line's SKILL.md in full.

## Precedence
Packs are pattern guidance. They lose to ADRs and rules (`governance/profile.md` → Precedence) and win over
the unit's design and existing code only where they carry a rule the design did not decide. Report every conflict.

## Rules
- A phase with no eligible rows is normal: no packs load.
- A pack's own `co_loads_with` / `when_to_load` hints are informational; only registry rows load.
- The story tag vocabulary (sk.story) is the union of the registry's Signals column.
