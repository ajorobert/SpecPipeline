---
name: sk.ff
description: "Fast forward a small unit from story to plan in one session: sk.story, then sk.design (feature) and sk.plan, each with its own gates. --bug skips design."
role: lead
---

# sk.ff
Runs story → design → plan in one window, for small scope: a contained change, few clarifications, one
or two projects. A large unit, or one under `validate`, runs the three commands in separate sessions.

## Pre-flight
`.specify/memory/projects/index.md` must have at least one project row (Type Backend, Frontend or
Mobile): otherwise STOP — `Run /sk.init first`.

## Steps
1. `Skill(sk.story)` (`--bug` in bug mode). Then read `checkpoint_mode` from the story.
2. Feature mode: `Skill(sk.design)` — in autopilot only when `02-design/architecture.md` is missing. Bug
   mode skips design; a fix that needs a data-model or contract change stops here and says to run
   `/sk.design --datamodel` or `--contracts`.
3. `Skill(sk.plan)`.
Each command runs its own gates; none is skipped.

## Completion report
```
sk.ff complete — {story-id}: {title} ({feature | bug})
Written: 01-story/, {02-design/,} 03-plan/{Projects}
Next: /sk.implement --projects {first project in sequence} — in a fresh session (this window now holds three phases)
```
