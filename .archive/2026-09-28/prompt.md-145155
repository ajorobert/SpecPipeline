# sk.investigate
Spec-aware root-cause debugging — knows what correct behavior looks like.
Role: backend, frontend | Level: story

Resolve `TEMPLATES_DIR` per `.claude/skills/governance/framework-paths.md` before reading any template.

## Pre-flight
1. Run the story pre-flight in `.claude/skills/governance/preflight.md` (active story, UNIT_DIR,
   Impacted Projects, knowledge, `.specify/profile.yaml`).
2. Resolve `REPORT = UNIT_DIR/investigation-report.md`. Identify the suspected `{Project}` (from the user's
   description or session.yaml role) so the right plan is loaded.
3. Declare mode:
   REPORT exists → [REFINE MODE]
     Read frontmatter only — get session_count, increment by 1, update frontmatter
     Never scan the report body to determine the session number
   Missing → [CREATE MODE]
     Create from {TEMPLATES_DIR}/artifacts/investigation-report-template.md
     Set session_count: 1, first session is INV-001

## Context loading (cacheable — load first)
Homes and loading rules per `.claude/skills/governance/profile.md`:
- specs/adr/adr-index.md → the ADRs it routes for the area under investigation
  → decided behaviour the code must follow (Tier A)
- UNIT_DIR/02-design/contract-changes.md → the operations this unit touched, and the canonical
  `specs/openapi/{audience}.yaml` / `specs/asyncapi/{module}.yaml` definitions of those operations
  → expected contract shapes (Tier B — stable across iterations)
- specs/domain/{module}.md of the contexts involved → domain invariants (Tier B)

## Story context (tail — load LAST)
Emit at end of user-input block, after all cacheable context:
```
<story id="{story-id}">
  <story-md>…UNIT_DIR/01-story/story.md + acceptance-criteria.md…</story-md>
  <plan-md>…UNIT_DIR/03-plan/{Project}/plan.md…</plan-md>
</story>
```

## Context surface
Surface to the agent, then investigate:

"Investigating story: {story-id} — {story title}
Expected behavior: see <story-md> acceptance criteria
Contract shape (relevant operations): {the canonical operations from contract-changes.md}
Decided constraints: {routed ADRs + domain invariants that bear on the failure}
Intended approach: see <plan-md>"

## Investigate
Reproduce the failure, read the code on the failing path in the project's `{CodeRoot}`, form a
hypothesis, and confirm it with evidence (a failing test, a log line, a traced call) before recording
it as a root cause.

## Post-execution

### Classify findings
Classify each finding as one of:
- **Implementation bug**: behavior deviates from correct implementation of the spec → fix in the project's {CodeRoot}
- **Spec/contract mismatch**: spec or contract needs updating → flag to architect;
  may require sk.design --contracts (REFRESH — edits the canonical spec and contract-changes.md) or
  sk.story --clarify before implementation changes

No spec files may be modified based on investigation findings without architect confirmation.

### Write investigation-report.md
CREATE MODE: create from {TEMPLATES_DIR}/artifacts/investigation-report-template.md.
  Write first session block as `## Investigation INV-001 — {date}`.

REFINE MODE: prepend a new session block immediately below the file header (above all prior
  sessions). Never modify or remove prior session blocks.

Each session block is fully self-contained. Findings within a session are numbered locally
(Finding-001, Finding-002, ...) — scoped to that session only. Cross-references use the full
`INV-NNN / Finding-NNN` pair. Every finding must be classified — unclassified findings are a
quality bar failure.

### Append candidate invariants to unit knowledge-base
For each finding in the current session, derive the invariant the bug revealed — a rule that
must hold and is not obvious from reading the code.

Skip obvious invariants (null checks, input validation, etc.) and note the skip with a brief
reason in the report's Candidate Invariants section.

KB_PATH = UNIT_DIR/knowledge-base.md

If KB_PATH exists:
  Append to `## Candidate Invariants` section.
  If the section does not yet exist, create it at the bottom of the file.
If KB_PATH does not exist:
  Create from {TEMPLATES_DIR}/artifacts/unit-knowledge-base-template.md.
  Populate only the `## Candidate Invariants` section; leave other sections as placeholders.

Format:
  `- [INV-NNN] {rule} — story {story-id} ({date})`

These are unreviewed staging entries in the unit knowledge base. The investigation never writes a
domain spec, ADR or rule file itself. At ship, promotion (`.claude/skills/governance/promotion.md`)
moves each invariant that survives review to its home — `specs/domain/{module}.md`, an ADR, or a rule
file under `.claude/rules/{stack}/` — or drops it as derivable.

### Next-step instructions
Display after writing the report and updating the knowledge base.

#### If ALL findings in this session are Implementation Bug:
---
Investigation INV-{NNN} complete.
Report: {UNIT_DIR}/investigation-report.md

All findings are Implementation Bugs.

Next steps:
1. Run /sk.phr — record root cause so future AI sessions don't repeat it.
2. Fix the bug in the project's code root.
3. Run /sk.test to verify the fix.

Candidate invariant(s) from this session appended to the unit knowledge base; promotion at ship moves them to their home.
---

#### If ANY finding in this session is Spec/Contract Mismatch:
---
Investigation INV-{NNN} complete.
Report: {UNIT_DIR}/investigation-report.md

One or more findings are Spec/Contract Mismatch — do not modify code yet.

Next steps:
1. Update the affected acceptance criteria in 01-story/acceptance-criteria.md
   (or ask the PO/lead if scope is unclear).
2. If the contract shape (operation, field, response code) needs to change:
   run /sk.design "<change>" (REFRESH mode, architect role recommended) — it edits the canonical
   spec and records the change in 02-design/contract-changes.md.
3. Once spec is corrected, resume /sk.implement.

Candidate invariant(s) from this session appended to the unit knowledge base; promotion at ship moves them to their home.
---

## Quality Bar
- Every finding classified: implementation bug vs. spec/contract mismatch
- No spec or contract files modified without architect sign-off
- Root cause documented for each finding, confirmed with evidence
- investigation-report.md written to UNIT_DIR; session block prepended, prior sessions untouched
- session_count updated in frontmatter (read frontmatter only — never scan report body)
- Candidate invariant derived per finding (written to the unit knowledge base only), or skip explicitly noted with reason
- Next-step instructions displayed, matching the current session's finding classifications
