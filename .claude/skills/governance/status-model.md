# Story Status Model
Framework-owned block. It is the single source of truth for `status.current` in the active story's
frontmatter, for the `SK_RESULT:` completion signal, and for how a skill's role is resolved at write
time. The hooks (`post-skill.sh`, `post-response.sh`, `validate-path.sh`) implement exactly this.

## The enum
`draft → ready → in-progress → testing → review → verify → security-review → done → shipped`
plus two off-path states: `review-rejected` (sk.review found blocking findings) and `rolled-back`.
No other value is valid.

## Who writes what

| Transition | Written by | When |
|---|---|---|
| → `draft` | post-skill.sh | `sk.story_sub_specify` is invoked |
| → `ready` | sk.story (Phase 6) | the validation gate passes |
| → `in-progress` | sk.implement prompt | before the first project worker runs |
| → `testing` | post-response.sh | `sk.implement` emits `SK_RESULT: PASS` |
| → `review` | post-response.sh | `sk.test` emits `SK_RESULT: PASS` |
| → `verify` / `review-rejected` | post-response.sh | `sk.review` emits PASS / FAIL |
| → `security-review` | post-response.sh | `sk.security-audit` emits `SK_RESULT: PASS` |
| → `done` | post-response.sh | `sk.verify` emits `SK_RESULT: PASS` |
| → `shipped` | post-response.sh | `sk.ship` emits `SK_RESULT: PASS` |
| → `rolled-back` | sk.rollback prompt | the rollback completes |

A skill prompt never writes a status the table assigns to a hook, and vice versa. `sk.plan` does not
move the story at all — plan approval lives in `03-plan/{Project}/plan.md` front-matter `status:`.

## Roll-up fields (independent of `status.current`)
| Field | Written by | Values |
|---|---|---|
| `test-status` | post-response.sh (from `sk.test`), sk.uat | `pass` \| `fail` |
| `verify-status` | post-response.sh (from `sk.verify`) | `PASS` \| `FAIL` |
| `security-status` | sk.security-audit | `clear` \| `conditional` \| `blocked` |
| `checkpoint_mode` | sk.story_sub_specify | `autopilot` \| `confirm` \| `validate` |

## The `SK_RESULT:` contract
Every skill in the conditional set — `sk.implement`, `sk.test`, `sk.review`, `sk.security-audit`,
`sk.verify`, `sk.ship` — MUST end its output with a line that is exactly:

```
SK_RESULT: PASS
```
or
```
SK_RESULT: FAIL
```

`post-skill.sh` writes `.claude/.last-skill` when one of these is invoked; the Stop hook
(`post-response.sh`) reads the last assistant message, finds the verdict and applies the transition.
No `SK_RESULT:` line means no transition — the story silently stays where it was, so omitting it is a
defect, not a soft failure. `FAIL` persists the roll-up field (so `sk.ship` preconditions can see it)
but advances the status only where the table above defines a FAIL state.

Meaning of PASS per skill:
- `sk.implement` — every targeted project reached validation, nothing left blocked.
- `sk.test` — every in-scope project's suite is green.
- `sk.review` — no BLOCKING findings.
- `sk.security-audit` — the audit ran to completion with no open CRITICAL finding. The graded verdict
  lives in `security-status`, not here.
- `sk.verify` — every applicable quality gate passed.
- `sk.ship` — the PR was created.

## Active-skill role
`write_scope.deny` in `.claude/agents/*.md` is evaluated against the role of the skill that is
running, never against `session.yaml` `role`. An orchestrator delegates phases to other roles — a
lead running `sk.ff` must not be denied the architect's `02-design/` output.

1. `post-skill.sh` reads the invoked skill's `subagent_type`, finds the agent whose `name:` matches,
   and writes that agent's `role:` to `.claude/.active-skill-role`.
2. `validate-path.sh` prefers that file; it falls back to `session.yaml` `role` for ad-hoc work
   outside any skill.
3. `post-response.sh` deletes the marker at the end of every turn, so a crashed skill cannot leave a
   stale role behind.

The marker is per-developer runtime state and is gitignored.
