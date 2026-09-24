# Session Boundaries
Framework-owned block, referenced by path from every orchestrator's completion report.
It says when a developer should start a fresh session, and why.

## The rule
Start a new session at a phase boundary. Never inside a phase.

A phase's output is its artifacts, not its conversation. Nothing downstream reads the transcript that
produced them: `sk.design` reads `story.md`, `requirement.md` and `acceptance-criteria.md` — never the
clarification exchange that filled them in. Carrying that history forward costs context and buys
nothing.

## Why it is only ever a recommendation
No skill can clear its own context; there is no tool for it. `/clear` and starting a new session are
the developer's to do. A skill can only say so in its completion report — which is what these reports
do. The alternative is automatic compaction, which does not fail but does summarize lossily. The
artifacts do not, so prefer the artifacts.

## Why interactive phases accumulate the most
A worker dispatched as a subagent has no channel to the human
(`.claude/skills/governance/worker-dispatch.md`), so every question, every review gate and every
approval lands in the orchestrator's own window. That material is spent the moment the artifact is
written and the gate is passed.

| Boundary | What is left behind | Fresh session |
|---|---|---|
| after `sk.story` | three worker prompts, up to five Q&A loops, the routers | **strongly recommended** |
| after `sk.ff` | all of the above plus design gates and plan reports | **strongly recommended** |
| after `sk.implement` | implementproject once per project, its gates, its worker reports | **recommended** |
| after `sk.design` | four gates' deliberation, four worker reports, ADR raising | recommended |
| after `sk.plan` | a few short reports and one gate | optional |
| after `sk.test` | one gate and the per-project reports | optional |
| inside a phase | — | **never** — the orchestrator's own state would be lost |

## Resuming
Nothing is held in volatile state across a boundary. The per-turn `active-skill` markers are cleared by
the Stop hook; everything else is on disk (`.specify/state/session.yaml` and the phase artifacts, per
`governance/phase-layout.md`).

In the new session:
```
/sk.session status     → role, branch, active intent/unit/story, status.current, checkpoint_mode
/sk.<next phase>
```
If `session.yaml` is gone entirely (new machine, cleaned state), `sk.session restore` recovers the
focus from the git branch alone.

## It does not cost prompt cache
Caching keys on content prefix, not on session identity. A new session re-sends the same system
prompt, `CLAUDE.md` and skill index, so that prefix still hits cache within its TTL. What is discarded
is the long variable tail — the part that was never cacheable and that pushed everything else around.

## sk.ff is the deliberate exception
`sk.ff` runs story → design → plan in one window on purpose. Use it when the scope is small enough
that the interaction is minimal — a contained change, few clarifications, `checkpoint_mode` of
`autopilot` or `confirm`. For a large unit under `validate`, run the phases separately instead.
Either way, start a fresh session **after** sk.ff finishes, before `sk.implement`: by then one window
holds three phases.
