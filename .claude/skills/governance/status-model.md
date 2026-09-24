# Story Status Model
Framework-owned block. It is the single source of truth for `status.current` in the active story's
frontmatter, for the `SK_RESULT:` completion signal, and for how a skill's role is resolved at write
time. The hooks (`skill-start.sh`, `post-response.sh`, `validate-path.sh`) and the status command
(`story-status.sh`) implement exactly this.

## The enum
`draft → ready → in-progress → testing → review → verify → security-review → done → shipped`
plus two off-path states: `review-rejected` (sk.review found blocking findings) and `rolled-back`.
No other value is valid. `shipped` also freezes the unit (`governance/promotion.md`).

## The one status command
Every transition goes through `sk_transition` in `.claude/hooks/lib-story.sh`. It validates the value,
writes `status.current` + `entered_at`, appends to `.specify/state/skill-audit.log`, and queues the
tracker mirror (`governance/tracker-mirror.md`). Hooks call it directly; a skill calls it through

```
bash .claude/hooks/story-status.sh set <status> --by <skill>
bash .claude/hooks/story-status.sh field <test-status|verify-status|security-status|uat-status|jira_id|checkpoint_status|branch> <value>
```

A skill never edits `status.current` or a roll-up field with Edit/Write.

## Who writes what

| Transition | Written by | When |
|---|---|---|
| → `draft` | skill-start.sh | `sk.story_sub_specify` starts |
| → `ready` | sk.story (Phase 6) via story-status.sh | the validation gate passes |
| → `in-progress` | sk.implement via story-status.sh | before the first project worker runs |
| → `in-progress` | sk.hotfix via story-status.sh | a hotfix starts on a `draft` or `ready` story |
| → `testing` | post-response.sh | `sk.implement` emits `SK_RESULT: PASS` |
| → `review` | post-response.sh | `sk.test` emits `SK_RESULT: PASS` |
| → `verify` / `review-rejected` | post-response.sh | `sk.review` emits PASS / FAIL |
| → `security-review` | post-response.sh | `sk.security-audit` emits `SK_RESULT: PASS` |
| → `done` | post-response.sh | `sk.verify` emits `SK_RESULT: PASS` |
| → `shipped` | post-response.sh | `sk.ship` emits `SK_RESULT: PASS` |
| → `rolled-back` | sk.rollback via story-status.sh | the rollback completes |

A skill never writes a status the table assigns to a hook, and vice versa. `sk.plan` does not move the
story — plan approval lives in `03-plan/{Project}/plan.md` front-matter `status:`.

## Roll-up fields (independent of `status.current`)
| Field | Written by | Values |
|---|---|---|
| `test-status` | post-response.sh (from `sk.test`), sk.uat via story-status.sh | `pass` \| `fail` |
| `verify-status` | post-response.sh (from `sk.verify`) | `PASS` \| `FAIL` |
| `security-status` | sk.security-audit via story-status.sh | `clear` \| `conditional` \| `blocked` |
| `checkpoint_mode` | sk.story_sub_specify | `autopilot` \| `confirm` \| `validate` |
| `jira_id` | sk.story via story-status.sh | the tracker issue key |
| `checkpoint_status` | sk.ff / gates via story-status.sh | `approved` |
| `branch` | sk.session start via story-status.sh | the working branch (used by `sk.session restore`) |

## The `SK_RESULT:` contract
Every skill in the conditional set — `sk.implement`, `sk.test`, `sk.review`, `sk.security-audit`,
`sk.verify`, `sk.ship` — MUST end its output with a line that is exactly `SK_RESULT: PASS` or
`SK_RESULT: FAIL`.

`skill-start.sh` writes `.specify/state/last-skill` when one of these starts; the Stop hook
(`post-response.sh`) reads the last assistant message, finds the verdict and applies the transition.
No `SK_RESULT:` line means no transition, and the Stop hook reports it — omitting it is a defect.
`FAIL` persists the roll-up field (so `sk.ship` preconditions can see it) but moves the status only
where the table above defines a FAIL state.

Meaning of PASS per skill:
- `sk.implement` — every targeted project reached validation, nothing left blocked.
- `sk.test` — every in-scope project's suite is green.
- `sk.review` — no BLOCKING findings.
- `sk.security-audit` — the audit ran to completion with no open CRITICAL finding. The graded verdict
  lives in `security-status`, not here.
- `sk.verify` — every applicable quality gate passed.
- `sk.ship` — promotion recorded and the PR was created.

## How a skill starts (both entry paths)
A skill starts either as a tool call (`Skill(sk.x)` — how orchestrators run sub-skills) or as a
user-typed command (`/sk.x …`, which expands without any tool call). `skill-start.sh` is wired to
both — `PreToolUse(Skill)` and `UserPromptSubmit` — so preconditions and start bookkeeping run on
every path. Orchestrators therefore always invoke sub-skills with the **Skill tool**, never by reading
a sub-skill's prompt.md.

## Active-skill role
`write_scope.deny` in `.claude/agents/*.md` is evaluated against the role of the skill that is
running, never against `session.yaml` `role`. An orchestrator delegates phases to other roles — a
lead running `sk.ff` must not be denied the architect's `02-design/` output, and a po session that
types `/sk.design` writes as the architect.

1. `skill-start.sh` reads the starting skill's `subagent_type`, finds the agent whose `name:` matches,
   and writes the skill to `.specify/state/active-skill` and that agent's `role:` to
   `.specify/state/active-skill-role`. Each skill start overwrites both.
2. `validate-path.sh` prefers the active role; it falls back to `session.yaml` `role` for ad-hoc work
   outside any skill.
3. `post-response.sh` clears both at the end of every turn, so a crashed skill cannot leave a stale
   role behind.

A nested skill (for example sk.ship calling `Skill(sk.adr)` during promotion) takes over the active
role until the turn ends; the parent's remaining writes in that turn are judged by the nested skill's
role. The deny lists are written so that every such pairing the framework uses is allowed.
`last-skill` is written only by the conditional skills, so a nested non-conditional skill never
displaces the parent's SK_RESULT marker.

All of `.specify/state/` is per-developer runtime state and is gitignored.
