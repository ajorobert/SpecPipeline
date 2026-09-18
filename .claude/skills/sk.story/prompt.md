# sk.story — Unified Story Capture Orchestrator
Runs the complete story capture and clarification pipeline.
Role: po (orchestrator) | Level: story

This skill orchestrates `sk.story_sub_specify`, `sk.story_sub_clarify`, and `sk.story_sub_architect-probe` in sequence, running completeness checks and looping clarification as needed for both business and technical aspects.

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
- `sk.story --jira {Jira_Id}` → [JIRA MODE] — ingest the Jira task via MCP and auto-seed the pipeline (still pairs with FEATURE/BUG framing; `--bug` may be added).
- No `--jira` flag → [MANUAL MODE] — capture the story via the interactive interview (existing behavior).

## Pre-flight
1. Read `session.yaml`
2. Load `.specify/memory/system-context.md`, `.specify/memory/architecture-decisions.md`, `.specify/memory/domain-model.md`
3. Load `.specify/memory/projects/index.md` as the **project router** (available projects + their types). It is used by `sk.story_sub_architect-probe` to record the **impacted projects** into `unit-brief.md`. The story itself is NOT split per project.

## Story Layout
A unit has exactly one story, in the fixed phase folder `01-story/` (`.claude/skills/governance/phase-layout.md`).
It is NOT split per project:
```
specs/intents/{intent}/units/{unit}/01-story/
    story.md                # user story (frontmatter + As-a/I-want/So-that + scope)
    requirement.md          # business + non-functional requirements, clarifications, architecture constraints
    acceptance-criteria.md  # testable acceptance criteria (GWT)
    jira.md                 # optional — Jira source mapping (only in [JIRA MODE])
```
- Story ID stays `{INTENT}-{UNIT}-{NNN}` in `story.md` frontmatter.
- Work that needs a second story belongs in a new unit.
- Whenever a phase below says "the story", it means this folder; assessments read across `story.md` + `requirement.md` + `acceptance-criteria.md`.

## Phase 0 — Jira Ingestion (only in [JIRA MODE])
Runs before Phase 1 when `--jira {Jira_Id}` is supplied. Skipped entirely in [MANUAL MODE].
1. Load the Atlassian MCP tool schema first (deferred): `ToolSearch` with query `select:mcp__claude_ai_Atlassian_Rovo__getJiraIssue` (also fetch `searchJiraIssuesUsingJql` if the parent/epic must be resolved).
2. Fetch the issue `{Jira_Id}` via `getJiraIssue`. If the fetch fails (auth missing, unknown ID, MCP not connected): STOP and report — do not silently fall back to manual.
3. Map Jira fields → pipeline seed data:
   - **Summary** → story title + action.
   - **Description / acceptance-criteria field / checklist** → requirement, happy path, and seed acceptance criteria.
   - **Issue type** (`Bug` → also engage [BUG MODE] framing) and **labels/components** → tags + project-impact hints.
   - **Epic / parent** → candidate Intent; the issue itself → candidate Unit + Story.
4. Carry the seed data forward so sub-skills PRE-FILL answers instead of re-asking. Record the source `jira_id: {Jira_Id}` in story frontmatter.

## Orchestration

### Phase 1 — Story Capture
Invoke sub-skill: `sk.story_sub_specify` (or `--bug` if in bug mode)
- In [JIRA MODE]: pass the Phase 0 seed data to `sk.story_sub_specify`. It pre-fills intent/unit/story fields from Jira and only asks for fields Jira left genuinely empty — it does not re-run the full interview.
- In [MANUAL MODE]: `sk.story_sub_specify` runs the interactive interview as normal.
- Wait for specify phase to complete and write the story folder (`story.md`, `requirement.md`, `acceptance-criteria.md`)
- Read back `active_unit_id` / `active_story_id` from `session.yaml`

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
Loop `sk.story_sub_clarify` up to 3 times to resolve the gaps identified in Phase 2.

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

- **All Phase 4 items ✅ Clear** → invoke `sk.story_sub_architect-probe --impact-only`.
  It performs the Impact Analysis and writes the Impacted Projects table, and asks no questions.
- **Any ⚠️ Partial or ❌ Missing** → invoke `sk.story_sub_architect-probe` in full, looping up to 2
  times. The full mode does the same Impact Analysis plus the question loop.

Loop `sk.story_sub_architect-probe` up to 2 times to resolve gaps from Phase 4.

**Round 1:**
- Present the ⚠️/❌ items to the architect-probe sub-skill.
- Probe phase asks up to 3 questions translating technical needs to business context.
- Integrate user answers into `requirement.md` (and impacted projects into `unit-brief.md`).
- Re-run Phase 4 Assessment. If all ✅, exit loop.
- **Round 2:** Repeat if needed. Exit loop after Round 2 regardless.

### Phase 6 — Final Validation Gate
Before marking the story as ready:
1. Show a combined summary of the final Business & Technical Assessments.
2. If all items are ✅ across both:
   - Auto-set `status.current: ready` (and `status.entered_at`) in the `story.md` frontmatter.
   - Display success summary.
3. If any ❌ remain:
   - Display the missing items.
   - Ask PO: "Type 'proceed' to accept and proceed (items will be flagged as risk), or 'clarify' to do one more manual round."
   - If 'proceed': set `status.current: ready` in `story.md`.

### Phase 7 — Finalize Story Folder
Once the story is `ready`, finalize the **single** story folder. Do NOT split per project.

**Confirm the folder is complete** at `specs/intents/{intent}/units/{unit}/01-story/`:
- `story.md` — frontmatter (`id`, `intent`, `unit`, `status.current`, `story_type`, `tags`, `checkpoint_mode`, and `jira_id` in [JIRA MODE]) + the As-a/I-want/So-that statement + in/out-of-scope.
- `requirement.md` — business + non-functional requirements, the clarifications log, and architecture constraints (NFRs, security, observability, integration).
- `acceptance-criteria.md` — the testable acceptance criteria.
- `jira.md` — **optional**, written only in [JIRA MODE]: records the source Jira ID `{Jira_Id}`, the issue summary, and a link back to it for traceability. In [MANUAL MODE] this file is not created.

**Impacted projects** stay recorded in `unit-brief.md` (written by `sk.story_sub_architect-probe`) — they are a unit-level fact, not a reason to split the story.

**Traceability chain to preserve in `story.md` frontmatter / body:**
`Intent → Unit → Specification → Clarification → Architecture Probe → Story` (downstream stages: Design → Plan → Implementation → Test → UAT → Security Audit).

## Completion Report
```
sk.story complete.
Story: {story-id} — {story title}
Status: ready
Checkpoint: {checkpoint_mode}

Checklist Summary:
- Business Passed: {X}/{Total}
- Technical Passed: {Y}/{Total}
- Missing: {Z} (listed if any)

Story folder: 01-story/ (story.md, requirement.md, acceptance-criteria.md{, jira.md if --jira})
Impacted projects (in unit-brief.md): {Backend/Frontend/Mobile list}

Next step: /sk.design (or /sk.ff if continuing the pipeline)
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
- ✔ jira.md present only when sourced from Jira
