# sk.story — Unified Story Capture Orchestrator
Runs the complete story capture and clarification pipeline.
Role: po (orchestrator) | Level: story

This skill orchestrates `sk.story_sub_specify`, `sk.story_sub_clarify`, and `sk.story_sub_architect-probe` in sequence, running completeness checks and looping clarification as needed for both business and technical aspects.
Every sub-skill is invoked with the **Skill tool** (`Skill(sk.story_sub_specify)`, with any flags as its args), never by reading its prompt.md — that is how `skill-start.sh` runs preconditions and sets the active role (`.claude/skills/governance/status-model.md`).

This pipeline is deliberately NOT dispatched as subagents, and must not be. Every sub-skill here
converses with a human — the clarify and architect-probe loops present one question at a time and
wait for the answer — and a subagent has no channel to the user
(`.claude/skills/governance/worker-dispatch.md` → A worker can never talk to a human). Story capture
is cheap in context anyway: it reads the routers and the story folder, not a source tree.

## Mode Detection
Evaluate in this order:
**TARGETED**
- `sk.story --specify` → run Phase 1 only (standalone intent/unit/story capture).
  The Impacted Projects table is NOT written in this mode. Downstream phases will STOP until
  `sk.story --probe` (or a full `sk.story` run) has filled it — say so in the completion report.
- `sk.story --clarify` → run Phase 3 only (standalone business ambiguity resolution)
- `sk.story --probe` → run Phase 5 only (technical constraints + Impacted Projects table)

**FULL PIPELINE**
- `sk.story` (no flag) → [FEATURE MODE]
- `sk.story --bug` → [BUG MODE]

**SOURCE MODIFIER** (combines with FULL PIPELINE; default is manual)
- `sk.story --jira {Jira_Id}` → [JIRA MODE] — ingest the tracker issue through the tracker connector and auto-seed the pipeline (still pairs with FEATURE/BUG framing; `--bug` may be added).
- No `--jira` flag → [MANUAL MODE] — capture the story via the interactive interview.

## Pre-flight
1. Read `.specify/state/session.yaml`.
2. Read `.specify/profile.yaml` once (every key optional; defaults in `.claude/skills/governance/profile.md`).
   Note `tracker.kind` (default `none`) and `tracker.project`. Never read a path matched by
   `knowledge.never_autoload`.
3. Knowledge, per the loading rules in `.claude/skills/governance/profile.md`:
   - `specs/knowledge-base.md` — the system overview (already in context through CLAUDE.md).
   - `specs/adr/adr-index.md` — load the ALWAYS block's ADRs now; signal blocks are loaded by
     `sk.story_sub_architect-probe` once the story's tags and text exist.
   - `specs/domain/bounded-contexts.md` — the context map.
   A missing home is logged `{home} not present — skipped`; it is never created here.
4. Load `.specify/memory/projects/index.md` as the **project router** (available projects + their types). It is used by `sk.story_sub_architect-probe` to record the **impacted projects** into `unit-brief.md`. The story itself is NOT split per project.

## Story Layout
A unit has exactly one story, in the fixed phase folder `01-story/` (`.claude/skills/governance/phase-layout.md`).
It is NOT split per project:
```
specs/intents/{intent}/units/{unit}/01-story/
    story.md                # user story (frontmatter + As-a/I-want/So-that + scope)
    requirement.md          # business + non-functional requirements, clarifications, architecture constraints
    acceptance-criteria.md  # testable acceptance criteria (GWT)
    jira.md                 # only when tracker-seeded — the issue description as seeded
```
- Story ID stays `{INTENT}-{UNIT}-{NNN}` in `story.md` frontmatter.
- Work that needs a second story belongs in a new unit.
- Whenever a phase below says "the story", it means this folder; assessments read across `story.md` + `requirement.md` + `acceptance-criteria.md`.
- `status.current` and `jira_id` are written only through `bash .claude/hooks/story-status.sh`, never by Edit/Write.

## Phase 0 — Jira Ingestion (only in [JIRA MODE])
Runs before Phase 1 when `--jira {Jira_Id}` is supplied. Skipped entirely in [MANUAL MODE].
1. Load the tracker connector's tool schemas first (they are deferred): `ToolSearch` for the issue-read
   tool (for Jira, the Atlassian MCP `getJiraIssue`; also its JQL search tool if the parent/epic must be resolved).
2. Fetch the issue `{Jira_Id}`. If the fetch fails (auth missing, unknown ID, connector not available): STOP and report — do not silently fall back to manual.
3. Map issue fields → pipeline seed data:
   - **Summary** → story title + action.
   - **Description / acceptance-criteria field / checklist** → requirement, happy path, and seed acceptance criteria.
   - **Issue type** (`Bug` → also engage [BUG MODE] framing) and **labels/components** → tags + project-impact hints.
   - **Epic / parent** → candidate Intent; the issue itself → candidate Unit + Story.
4. Carry the seed data forward so sub-skills PRE-FILL answers instead of re-asking. The key is linked to the story in Phase 5b.

## Orchestration

### Phase 1 — Story Capture
`Skill(sk.story_sub_specify)` (args `--bug` in bug mode). `skill-start.sh` moves the story to `draft` when it starts.
- In [JIRA MODE]: pass the Phase 0 seed data to `sk.story_sub_specify`. It pre-fills intent/unit/story fields from the issue and only asks for fields the issue left genuinely empty — it does not re-run the full interview.
- In [MANUAL MODE]: `sk.story_sub_specify` runs the interactive interview as normal.
- Wait for specify phase to complete and write the story folder (`story.md`, `requirement.md`, `acceptance-criteria.md`)
- Read back `active_unit_id` / `active_story_id` from `.specify/state/session.yaml`

### Phase 2 — Business Completeness Assessment
Run a structural coverage check on the generated story folder (`story.md` + `acceptance-criteria.md`).
Score each item below as ✅ Clear, ⚠️ Partial, or ❌ Missing.

**Business Checklist:**
- Story Structure
  - [ ] User story follows "As a / I want / So that" format
  - [ ] Actor is a specific role, not generic ("user")
  - [ ] Action is a concrete verb, not abstract ("manage")
  - [ ] Value connects to a business outcome
- Acceptance Criteria
  - [ ] Minimum 3 criteria present
  - [ ] At least 1 negative/error scenario covered
  - [ ] All criteria are testable (GWT or condition-based)
  - [ ] No vague qualifiers without metrics
- Scope
  - [ ] Out-of-scope section is populated (not empty)
  - [ ] No implicit scope assumptions

Gather all items marked ⚠️ Partial or ❌ Missing as seeds for Phase 3.
If all items are ✅ Clear, skip Phase 3 and go to Phase 4.

### Phase 3 — Iterative Business Clarification
Loop `Skill(sk.story_sub_clarify)` up to 3 times to resolve the gaps identified in Phase 2.

**Round 1:**
- Present the ⚠️/❌ items to the clarify sub-skill.
- Clarify phase asks up to 5 questions.
- Integrate user answers into the story folder (`requirement.md` / `acceptance-criteria.md`).
- Re-run Phase 2 Assessment. If all ✅, exit loop.
- **Round 2 & 3:** Repeat, adjusting questions to remaining gaps. Exit loop after Round 3 regardless.

### Phase 4 — Technical Completeness Assessment
Run an engineering readiness check on the story folder (`requirement.md` + `acceptance-criteria.md`).
Score each item below as ✅ Clear, ⚠️ Partial, or ❌ Missing.

**Technical Checklist:**
- Integration & Data
  - [ ] Entities involved are identified and data inputs/outputs are concrete.
  - [ ] External dependencies and downstream failure modes addressed.
- NFRs & Scale
  - [ ] Performance targets, request volume, or scale expectations defined.
- Security boundaries
  - [ ] Tenant isolation or explicitly restricted actors defined.
- Observability
  - [ ] Business value telemetry/tracking metrics defined.
- UX & Design Constraints
  - [ ] Design references (Figma/assets) documented if frontend.

Gather all items marked ⚠️ Partial or ❌ Missing as seeds for Phase 5.
Phase 5 runs either way — see below. A clean technical assessment shortens it, it never skips it.

### Phase 5 — Project Impact (ALWAYS) + Iterative Technical Clarification
`sk.story_sub_architect-probe` is the only writer of the `unit-brief.md` → **Impacted Projects**
table, and every downstream phase (`02-design/projects/`, `03-plan/{Project}/`,
`04-implementation/{Project}/`, `05-test/{Project}/`) is driven by that table. The unit pre-flight of
sk.design / sk.plan / sk.implement / sk.test STOPs when it is empty. **This phase therefore always
runs**, in one of two modes:

- **All Phase 4 items ✅ Clear** → `Skill(sk.story_sub_architect-probe)` with args `--impact-only`.
  It performs the Impact Analysis and writes the Impacted Projects table, and asks no questions.
- **Any ⚠️ Partial or ❌ Missing** → `Skill(sk.story_sub_architect-probe)` in full, looping up to 2
  times. The full mode does the same Impact Analysis plus the question loop.

**Round 1:**
- Present the ⚠️/❌ items to the architect-probe sub-skill.
- Probe phase asks up to 3 questions translating technical needs to business context.
- Integrate user answers into `requirement.md` (and impacted projects into `unit-brief.md`).
- Re-run Phase 4 Assessment. If all ✅, exit loop.
- **Round 2:** Repeat if needed. Exit loop after Round 2 regardless.

### Phase 5b — Tracker Seeding (when `tracker.kind` is set, or in [JIRA MODE])
Skipped when `tracker.kind` is `none` and no `--jira` was given. Runs before Phase 6 so the `ready`
transition already mirrors (`.claude/skills/governance/tracker-mirror.md`).
1. **Link** ([JIRA MODE]): the issue is `{Jira_Id}` from Phase 0.
   **Create** (no `--jira`, `tracker.kind` set, story has no `jira_id` yet): ask the PO
   "Create a {tracker.kind} issue in {tracker.project} for this story, or link an existing key? (create / link {KEY} / skip)".
   On `create`, load the connector's create tool with `ToolSearch` (for Jira, the Atlassian MCP
   `createJiraIssue`) and create the issue in `tracker.project`: summary = story title, description =
   the seeded description (step 2), issue type = Bug for bug stories, else the project's story type.
   On `skip`, record `Tracker seeding skipped by PO` in the completion report and go to Phase 6.
2. Write `01-story/jira.md` — the seeded description only: the issue key, a link to it, and the
   description text as sent to (or ingested from) the tracker. It carries no status and no copy of the
   story frontmatter; the framework is the record and the issue follows it.
3. Store the key: `bash .claude/hooks/story-status.sh field jira_id {KEY}`.
4. If the connector is unavailable or the call fails: do not write `jira_id`; tell the PO, and continue.
   The story works without a tracker issue; `sk.story` can seed it later.

### Phase 6 — Final Validation Gate
Before marking the story as ready:
1. Show a combined summary of the final Business & Technical Assessments.
2. If all items are ✅ across both:
   - Run `bash .claude/hooks/story-status.sh set ready --by sk.story`.
   - Display success summary.
3. If any ❌ remain:
   - Display the missing items.
   - Ask PO: "Type 'proceed' to accept and proceed (items will be flagged as risk), or 'clarify' to do one more manual round."
   - If 'proceed': run `bash .claude/hooks/story-status.sh set ready --by sk.story`.
4. If the command fails, report its output and STOP — never write `status.current` by hand.

### Phase 7 — Finalize Story Folder
Once the story is `ready`, finalize the **single** story folder. Do NOT split per project.

**Confirm the folder is complete** at `specs/intents/{intent}/units/{unit}/01-story/`:
- `story.md` — frontmatter (`id`, `intent`, `unit`, `status.current`, `story_type`, `tags`, `checkpoint_mode`, and `jira_id` when tracker-seeded) + the As-a/I-want/So-that statement + in/out-of-scope.
- `requirement.md` — business + non-functional requirements, the clarifications log, and architecture constraints (NFRs, security, observability, integration).
- `acceptance-criteria.md` — the testable acceptance criteria.
- `jira.md` — **only when tracker-seeded** (Phase 5b): the seeded issue description. Otherwise this file is not created.

**Impacted projects** stay recorded in `unit-brief.md` (written by `sk.story_sub_architect-probe`) — they are a unit-level fact, not a reason to split the story.

**Traceability chain to preserve in `story.md` frontmatter / body:**
`Intent → Unit → Specification → Clarification → Architecture Probe → Story` (downstream stages: Design → Plan → Implementation → Test → UAT → Security Audit).

## Completion Report
```
sk.story complete.
Story: {story-id} — {story title}
Status: ready
Checkpoint: {checkpoint_mode}
Tracker: {jira_id | not seeded — reason}

Checklist Summary:
- Business Passed: {X}/{Total}
- Technical Passed: {Y}/{Total}
- Missing: {Z} (listed if any)

Story folder: 01-story/ (story.md, requirement.md, acceptance-criteria.md{, jira.md if tracker-seeded})
Impacted projects (in unit-brief.md): {Backend/Frontend/Mobile list}

Next step: /sk.design (or /sk.ff if the remaining scope is small)
  Strongly recommended: start a fresh session first (`.claude/skills/governance/session-boundaries.md`).
  The clarification Q&A in this window is already recorded in requirement.md, and no later phase reads it.
  Reorient there with /sk.session status.
```

## Final Validation (before reporting complete)
- ✔ Intent resolved
- ✔ Unit resolved
- ✔ Specification completed (story.md, requirement.md, acceptance-criteria.md written)
- ✔ Clarifications completed
- ✔ Architecture impact checked, and `unit-brief.md` → Impacted Projects has **at least one row**
      with a Project, Type (Backend | Frontend | Mobile) and Code Root. An empty table is a FAIL:
      re-run Phase 5 before reporting complete.
- ✔ Project router loaded
- ✔ Single story folder `01-story/` (NOT split per project)
- ✔ checkpoint_mode set in story.md frontmatter (autopilot | confirm | validate)
- ✔ `status.current: ready`, set by `story-status.sh` (Phase 6)
- ✔ jira.md present only when tracker-seeded, and `jira_id` written by `story-status.sh field`
