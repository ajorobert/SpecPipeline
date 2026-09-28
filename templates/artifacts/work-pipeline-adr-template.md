# ADR-{NNNN}: Work pipeline and in-flight units

## Status
{Proposed | Accepted} — {date}

## Decision
Work on a change runs through the SpecKit pipeline — story, design, plan, implement, test, review,
verify, ship — one command per session, with the artifacts of each unit under
`specs/intents/{intent}/units/{unit}/`.

- A unit folder is a **work record**, not a knowledge home. It holds the reasoning of one change while
  the change is in flight, and it freezes when the unit ships.
- The only route from a unit into the knowledge homes (ADRs, rules, domain specs, contracts) is
  **promotion at ship**: each durable, non-derivable item moves to its one home; nothing is kept twice.
- Contracts are edited in place in their canonical files on the feature branch; a unit holds only the
  change list.
- On a conflict, unit artifacts lose to ADRs, rules and skills, in that order, and win only over
  existing code.

## Context
{Why the team adopts a structured pipeline: the size of the change set, the number of projects a
change touches, the need for reviewable intermediate steps.}

## Consequences
- Positive: each phase starts from written artifacts in a fresh session; knowledge reaches its home once.
- Negative: a unit carries per-phase documents that are discarded as knowledge after ship.
- Follow-up: {…}

## Alternatives rejected
- Unit documents as a knowledge home — they would duplicate ADRs and rules and drift from them.
- No pipeline, ad-hoc sessions per change — no reviewable handoff between design, plan and code.
