# sk.ff — Fast Forward (Orchestrator)
Runs the SDLC pipeline from story capture through planning in one invocation.
Role: lead (orchestrator) | Level: story

This skill orchestrates other skills in sequence. Each sub-skill runs with its own
isolated context — state is passed via the file system (session.yaml + spec artifacts).

## Mode Detection
- `sk.ff` → [FEATURE MODE] full pipeline: sk.story → design → plan
- `sk.ff --bug` → [BUG MODE] fix pipeline: sk.story --bug → plan
  Architecture step is skipped in bug mode — the unit architecture already exists.
  If the bug fix requires a data model or contract change, stop and run
  `sk.design --datamodel` or `sk.design --contracts` manually.

## Pre-flight
1. Verify system-context.md and tech-stack.md are populated
   system-context.md missing: STOP — run sk.init first
   tech-stack.md missing: STOP — run sk.init first

## Orchestration: [FEATURE MODE]

### Phase 1 — Story Capture
Invoke skill: sk.story
- Context injected: session.yaml, system-context.md, architecture-decisions.md, domain-model.md
- Waits for: `01-story/` written and clarified, with checkpoint_mode set in `story.md` frontmatter
- Reads back: active_unit_id / active_story_id from session.yaml (updated by sk.story → sk.specify)
- Reads back: checkpoint_mode from `01-story/story.md` frontmatter

### Phase 2 — Design [FEATURE MODE only]
Condition: checkpoint_mode = validate or confirm → invoke sk.design
           checkpoint_mode = autopilot → invoke sk.design only if `02-design/architecture.md` is missing;
           otherwise skip to Phase 3

If invoked:
- Invoke skill: sk.design
- sk.design auto-detects FRESH or RESUME mode and runs only phases needed for this unit
  (architecture always; data model and contracts only if the story signals the need)
- Gates inside sk.design are governed by checkpoint_mode per its own gate schedule
- Waits for: all needed design artifacts written (02-design/architecture.md at minimum)
- On sk.design completion: set `01-story/story.md` frontmatter checkpoint_status: approved

### Phase 3 — Implementation Plan
Invoke skill: sk.plan
- Context injected: session.yaml, tech-stack.md
- Waits for: sk.plan to complete (it manages its own checkpoint gate internally).

## Orchestration: [BUG MODE]

### Phase 1 — Bug Report Capture
Invoke skill: sk.story --bug
- This will run the specify phase --bug and then clarify the buggy behavior conditions.

### Phase 2 — Implementation Plan (no architecture step)
Invoke skill: sk.plan
- Waits for: sk.plan to complete (it manages its own checkpoint gate).
- Verify story_type: bug in `01-story/story.md` frontmatter before proceeding

## Checkpoint Pause Protocol
Pauses follow `.claude/skills/governance/review-gate.md`. Before pausing, make sure session.yaml holds the
active focus so the pipeline can resume.

## Completion Report
After all phases complete, display:
```
Fast Forward complete.
Story: {story-id} — {story title}
Mode: {FEATURE | BUG}

Artifacts created:
  ✓ 01-story/                (sk.story)
  ✓ 02-design/               (sk.design — if run)
  ✓ 03-plan/{Project}/       (sk.plan)

Next step: /sk.implement
```

## Output Artifacts
All artifacts from each invoked sub-skill.

## Quality Bar
- Checkpoint pauses respected — never skip an approval gate
- All artifacts created in correct locations
- Story frontmatter updated throughout (status, checkpoint_status)
- Bug mode: story_type: bug confirmed in frontmatter before plan proceeds
- Each sub-skill invocation is self-contained — no state leaks between phases
