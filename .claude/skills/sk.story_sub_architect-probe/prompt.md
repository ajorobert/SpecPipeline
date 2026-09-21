# sk.story_sub_architect-probe
Resolves technical ambiguities (NFRs, scale, security, observability, integrations) by probing the PO.
Role: architect | Level: story

## Mode Detection
- `sk.story_sub_architect-probe` → [FULL] Architecture scan + Impact Analysis + the question loop.
  Evaluates the story for AI-readiness from an engineering perspective, translating deep technical
  needs into business-friendly questions for the PO.
- `sk.story_sub_architect-probe --impact-only` → [IMPACT-ONLY] Run the pre-flight and the
  **Impact Analysis** section, write the Impacted Projects table, and stop. Skip the Architecture
  scan write-up and ask NO questions. sk.story uses this when its technical assessment came back
  fully clear — the table is still mandatory, because every downstream phase is driven by it.

Declare the mode at the start of execution.

## Pre-flight
1. Read session.yaml active_story_id
   NULL → STOP: run sk.session focus --story {id} first
2. Load the active story folder (`.claude/skills/governance/phase-layout.md`):
   specs/intents/{intent}/units/{unit}/01-story/
   Read `story.md`, `requirement.md`, and `acceptance-criteria.md`.
3. Load `.specify/memory/architecture-decisions.md`
4. Load the project router `.specify/memory/projects/index.md`. For each project that the story plausibly touches, load that project's memory:
   - `.specify/memory/projects/{project}/project.md`
   - `.specify/memory/projects/{project}/tech-stack.md`
   - `.specify/memory/projects/{project}/coding-standards.md`

## Architecture scan
Perform a structured coverage scan across these technical categories.
For each category, mark status: Clear / Partial / Missing. If an orchestrator passed you specific seeds, prioritize those seeds.

**Technical Scope Categories:**
- **Scale/Constraints:** Are anticipated user volume, request latency, data retention, and performance targets defined?
- **Security Boundaries:** Is tenant/user data isolation defined? Are unauthorized actors explicitly restricted (negative space)?
- **Observability & Analytics:** How is the "Business Value" instrumented and measured? Are there specific business metrics/events to log?
- **Integration Contracts:** Are downstream or external API failure modes handled (e.g. "What should the user see if payment gateway is down?")?
- **UX/Design Constraints:** If frontend facing, are there existing Figma links, mockups, or specific accessibility constraints?

## Impact Analysis — Identify Impacted Projects  (runs in BOTH modes — never skipped)
Using the project router and per-project memory loaded in pre-flight, determine which projects the story changes.
Classify each impacted project under its type and record concrete reasons (not just names):

- **Backend:** `[]`
- **Frontend:** `[]`
- **Mobile:** `[]`

For the set of impacted projects, analyze and note:
- **API changes** — new/modified endpoints, request/response contract changes.
- **Database impact** — new tables, migrations, schema or index changes.
- **Integration impact** — downstream/external services or events affected.
- **Security impact** — new actors, permissions, tenant-isolation or data-exposure changes.
- **Breaking changes** — contract or behavior changes that affect existing consumers.
- **Dependencies** — ordering constraints between projects (e.g. Backend endpoint must land before Frontend consumes it).

Record the impacted projects in the **Impacted Projects** table of the unit's `unit-brief.md` (Path: `specs/intents/{intent}/units/{unit}/unit-brief.md`) — one row per project: `| Project | Type | Code Root | Role in this unit |`, using the exact name and Code Root from the project router. Every downstream phase (`02-design/projects/`, `03-plan/{Project}/`, `04-implementation/{Project}/`, `05-test/{Project}/`) reads this table. The story is NOT split per project.

Capture the six analysis points (API changes, Database impact, Integration impact, Security impact, Breaking changes, Dependencies) under a `## Architecture Constraints` section in the story's `requirement.md` where they affect this story's scope.

## Question loop (max 3-5 questions)  — [FULL] mode only; skipped entirely in [IMPACT-ONLY]
Generate an internal prioritized queue of up to 5 questions from Partial/Missing categories.
**CRITICAL:** You must translate technical requirements into business-friendly questions that a PO can answer. (e.g., instead of "What is the desired TTL for the cache?", ask "How quickly must updates to this data be visible to other users?").

For each question:
1. Present EXACTLY ONE question at a time — never reveal the queue.
2. Provide context: explain briefly *why* this technical boundary is needed.
3. For multiple-choice: state **Recommended:** option with 1-2 sentence rationale, then list options.
4. For short-answer: state **Suggested:** answer with brief reasoning.
5. After user answers: record in working memory, then immediately:
   - Append `- Q: <question> → A: <answer>` under `## Architecture Constraints / ### Session YYYY-MM-DD` in `requirement.md`.
   - Apply the clarification to the appropriate file in the story folder (`acceptance-criteria.md`, `story.md` for scope, `requirement.md` for constraints).
   - Save the affected file after each integration.
6. Stop early if: all critical technical ambiguities resolved, user signals "done"/"proceed", or 5 questions reached.

## After loop completes
- Final pass: confirm no technical [NEEDS CLARIFICATION] markers remain in the story folder
- If constraints significantly conflict with `architecture-decisions.md`: flag to the user to consider updating system ADRs or rejecting the story scale.

## Output Artifacts
01-story/requirement.md (updated with technical constraints + a `## Architecture Constraints` section)
unit-brief.md (Impacted Projects table)

## Quality Bar
- `unit-brief.md` → Impacted Projects has at least one row, each with Project, Type
  (Backend | Frontend | Mobile), Code Root and a concrete role. **This holds in both modes.** If the
  story genuinely changes no project, that is a story defect — report it rather than writing an
  empty table.
- Project names and Code Roots are copied verbatim from `.specify/memory/projects/index.md` — never
  abbreviated, never invented.
- [FULL] only: all technical boundaries (Scale, Security, Observability, Integration, UX) are locked
  down; no vague engineering terms remain ("fast", "secure" are quantified); total questions ≤ 5.
- [IMPACT-ONLY]: no questions asked, and `requirement.md` is left untouched except for the six
  analysis points under `## Architecture Constraints`.
