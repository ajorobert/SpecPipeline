# Project skills
Project-owned capability packs. sk.* process skills load them only through this table
(`.claude/skills/governance/pack-resolution.md`); a skill not listed here is never loaded by the pipeline.
Each skill's own `description:` is its trigger for ad-hoc work.

## Registry
| Skill | Status | Defers to | Always | Signals | Phases | Applies to | Weight |
|---|---|---|---|---|---|---|---|
| `{skill-dir}` | active | — | Backend | — | — | Backend | 1 |
| `{skill-dir}` | active | `{other-skill}` | — | {signal}, {signal} | design, implement, review | Backend | 2 |

<!-- Columns:
     Always      comma-separated scopes that load the row unconditionally: a phase, a project type
                 (Backend | Frontend | Mobile), an exact project name, or {type-or-project}@{phase}; or —
     Signals     comma-separated lower-case keywords matched against story tags (×3) and working text (×1,
                 negated mentions never count); or —
     Phases      subset of design, plan, implement, review, test, uat; — = any phase
     Applies to  any | Backend, Frontend, Mobile — a project never loads a row that does not apply to its type
     Weight      multiplies the signal score; default 1 -->
