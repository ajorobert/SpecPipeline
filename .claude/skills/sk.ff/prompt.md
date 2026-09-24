# sk.ff — Fast Forward (Orchestrator)
Runs the SDLC pipeline from story capture through planning in one invocation.
Role: lead (orchestrator) | Level: story

This skill orchestrates other skills in sequence, invoking each with the **Skill tool**
(`Skill(sk.story)`, `Skill(sk.design)`, `Skill(sk.plan)`) so `skill-start.sh` runs their preconditions
and sets the active role (`.claude/skills/governance/status-model.md`). Those three orchestrators run
in this context; sk.design and sk.plan dispatch their own workers as subagents, while sk.story stays
interactive throughout (`.claude/skills/governance/worker-dispatch.md`). State is passed via the file
system (`.specify/state/session.yaml` + spec artifacts), so the pipeline resumes after any phase.

**Scope.** Running three phases in one window is deliberate, and it is the right trade only when the
work is small: a contained change, few clarifications, `checkpoint_mode` of `autopilot` or `confirm`.
For a large unit under `validate` — many clarification loops and a pause at every design gate — run
`sk.story`, `sk.design` and `sk.plan` as separate sessions instead
(`.claude/skills/governance/session-boundaries.md`). This skill does not refuse the large case; it
just stops being the cheaper way to do it.

## Mode Detection
- `sk.ff` → [FEATURE MODE] full pipeline: sk.story → design → plan
- `sk.ff --bug` → [BUG MODE] fix pipeline: sk.story --bug → plan
  Architecture step is skipped in bug mode — the unit architecture already exists.
  If the bug fix requires a data model or contract change, stop and run
  `sk.design --datamodel` or `sk.design --contracts` manually.

## Pre-flight
1. Verify the system context is not empty — "the file exists" is not the check, real content is:
   - `specs/knowledge-base.md` has at least one non-comment line of content under
     `## Why This System Exists` (HTML comments and blank lines do not count).
   - `.specify/memory/projects/index.md` has at least one project row in its table (a row whose Type
     is Backend, Frontend or Mobile — the header, separator and placeholder rows do not count).
   Any check failing: STOP with `Run /sk.init first — {file} {what is missing}.` Name every file that
   failed, so one sk.init run can fix them all.
2. Read `.specify/profile.yaml` once (defaults in `.claude/skills/governance/profile.md`).

## Orchestration: [FEATURE MODE]

### Phase 1 — Story Capture
`Skill(sk.story)`
- sk.story loads its own knowledge (system knowledge base, ADR index, bounded contexts, project router)
- Waits for: `01-story/` written and clarified, with checkpoint_mode set in `story.md` frontmatter
- Reads back: active_unit_id / active_story_id from `.specify/state/session.yaml` (updated by sk.story → sk.story_sub_specify)
- Reads back: checkpoint_mode from `01-story/story.md` frontmatter

### Phase 2 — Design [FEATURE MODE only]
Condition: checkpoint_mode = validate or confirm → invoke sk.design
           checkpoint_mode = autopilot → invoke sk.design only if `02-design/architecture.md` is missing;
           otherwise skip to Phase 3

If invoked:
- `Skill(sk.design)`
- sk.design auto-detects FRESH or RESUME mode and runs only phases needed for this unit
  (architecture always; data model and contracts only if the story signals the need)
- Gates inside sk.design are governed by checkpoint_mode per its own gate schedule
- Waits for: all needed design artifacts written (02-design/architecture.md at minimum)
- On sk.design completion: set `01-story/story.md` frontmatter checkpoint_status: approved

### Phase 3 — Implementation Plan
`Skill(sk.plan)`
- sk.plan reads each impacted project's `.specify/memory/projects/{Project}/tech-stack.md` itself
- Waits for: sk.plan to complete (it manages its own checkpoint gate internally).

## Orchestration: [BUG MODE]

### Phase 1 — Bug Report Capture
`Skill(sk.story)` with args `--bug`
- This will run the specify phase --bug and then clarify the buggy behavior conditions.

### Phase 2 — Implementation Plan (no architecture step)
`Skill(sk.plan)`
- Waits for: sk.plan to complete (it manages its own checkpoint gate).
- Verify story_type: bug in `01-story/story.md` frontmatter before proceeding

## Checkpoint Pause Protocol
Pauses follow `.claude/skills/governance/review-gate.md`. Before pausing, make sure `.specify/state/session.yaml` holds the
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
  Strongly recommended: start a fresh session first (`.claude/skills/governance/session-boundaries.md`).
  This one window now holds all three phases — story Q&A, design gates and the plan reports.
  Reorient there with /sk.session status.
```

## Output Artifacts
All artifacts from each invoked sub-skill.

## Quality Bar
- Checkpoint pauses respected — never skip an approval gate
- All artifacts created in correct locations
- Story frontmatter updated throughout (`status.current` only through `story-status.sh` / the hooks; checkpoint_status)
- Bug mode: story_type: bug confirmed in frontmatter before plan proceeds
- Each sub-skill invocation is self-contained — no state leaks between phases
