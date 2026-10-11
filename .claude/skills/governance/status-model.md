# Story Status Model
Framework-owned. The single source of truth for `status.current` in the active story's front-matter, for
the `SK_RESULT:` completion signal, and for how the running command's role is resolved. The hooks
(`skill-start.sh`, `post-response.sh`, `session-start.sh`, `validate-path.sh`) and `story-status.sh`
implement exactly this.

## The enum
`draft → ready → in-progress → testing → review → verify → security-review → done → shipped`, plus
`review-rejected` (sk.review found blocking findings). No other value is valid. `shipped` freezes the unit
(`governance/promotion.md`).

## The one status command
Every transition goes through `sk_transition` in `.claude/hooks/lib-story.sh`: validate, write
`status.current` + `entered_at`, append to `.specify/state/skill-audit.log`, queue the tracker mirror
(`governance/tracker-mirror.md`). Hooks call it directly; a command calls it through
```
bash .claude/hooks/story-status.sh set <status> --by <command>
bash .claude/hooks/story-status.sh field <test-status|verify-status|security-status|uat-status|jira_id|branch> <value>
```
A command never edits `status.current` or a roll-up field with Edit/Write.

## Who writes what
| Transition | Written by | When |
|---|---|---|
| → `draft` | skill-start.sh | `sk.story` starts on a story that is new, `draft` or `ready` |
| → `ready` | sk.story via story-status.sh | its ready gate passes |
| → `in-progress` | sk.implement / sk.hotfix via story-status.sh | the unit's first implement run starts |
| → `testing` | post-response.sh | `sk.implement` emits `SK_RESULT: PASS` |
| → `review` | post-response.sh | `sk.test` emits `SK_RESULT: PASS` |
| → `verify` / `review-rejected` | post-response.sh | `sk.review` emits PASS / FAIL |
| → `security-review` | post-response.sh | `sk.security-audit` emits `SK_RESULT: PASS` |
| → `done` | post-response.sh | `sk.verify` emits `SK_RESULT: PASS` |
| → `shipped` | post-response.sh | `sk.ship` emits `SK_RESULT: PASS` |

`sk.plan` never moves the story: plan approval is `status: approved` in `03-plan/{Project}/plan.md`.

## Roll-up fields
| Field | Written by | Values |
|---|---|---|
| `test-status` | post-response.sh (from sk.test PASS/FAIL); sk.uat on reject | `pass` \| `fail` |
| `verify-status` | post-response.sh (from sk.verify) | `PASS` \| `FAIL` |
| `security-status` | sk.security-audit | `clear` \| `conditional` \| `blocked` |
| `uat-status` | sk.uat | `pass` \| `fail` |
| `checkpoint_mode` | sk.story | `autopilot` \| `confirm` \| `validate` |
| `jira_id` | sk.story | the tracker issue key |
| `branch` | sk.session | the working branch (used by `sk.session restore`) |

## The `SK_RESULT:` contract
`sk.implement`, `sk.test`, `sk.review`, `sk.security-audit`, `sk.verify` and `sk.ship` end their output
with one line:
- `SK_RESULT: PASS` — the unit-level condition holds (below). The Stop hook applies the transition.
- `SK_RESULT: PARTIAL` — per-project commands only: this project is done, other impacted projects are not
  yet. No transition, no roll-up write.
- `SK_RESULT: FAIL` — writes the roll-up field (`test-status`, `verify-status`) and moves the status only
  where the table defines a FAIL state (`review-rejected`).

PASS per command: `sk.implement` — every impacted project has `validation: PASS`; `sk.test` — every impacted
project's test report is `result: PASS`; `sk.review` — every impacted project's review is `APPROVED`;
`sk.security-audit` — the audit completed with no open CRITICAL; `sk.verify` — every applicable quality
gate passed; `sk.ship` — promotion recorded and PR created.

`skill-start.sh` writes `.specify/state/last-skill` when one of these starts. The Stop hook reads the last
assistant message: with an `SK_RESULT` line it applies it and clears the marker; without one — a gate
waiting for the human — it leaves the marker for the turn that finishes the command. A new session
clears it (`session-start.sh`).

## How a command starts
As a typed `/sk.x …` (UserPromptSubmit) or as `Skill(sk.x)` from another command (PreToolUse). Both run
`skill-start.sh`: it evaluates the SKILL.md `preconditions:` and records the start. Commands run other
commands only with the Skill tool (sk.ff, sk.design → sk.adr, sk.ship → sk.adr).

## Active role
Write scope (`governance/roles.yaml`) is judged against the running command's role.
1. `skill-start.sh` resolves the role from SKILL.md `role:`. `engineer` and `qa` resolve from the type of the
   project `--projects` selects (engineer → backend | frontend | mobile; qa → backend-qa | frontend-qa); with
   no single project in scope, `lead`. A role `roles.yaml` does not list (`any`) has no deny set.
2. It writes `.specify/state/active-skill` and `active-skill-role`. They stay until the next command starts
   or a new session starts, so a gate that waits across turns keeps its role.
3. `validate-path.sh` uses the active role, else `session.yaml` `role` for work outside any command.

A nested command (sk.ship → `Skill(sk.adr)`) takes over the role for the rest of its parent's run; the deny
sets allow every pairing the framework uses. `last-skill` is written only by the commands above, so a
nested command never displaces its parent's marker.

All of `.specify/state/` is per-developer runtime state and is gitignored.
