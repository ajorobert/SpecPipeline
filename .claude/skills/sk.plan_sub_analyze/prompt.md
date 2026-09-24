# sk.plan_sub_analyze
Cross-artifact consistency check for the active unit.
Role: lead | Level: unit
READ-ONLY — no files written, analysis report only.

Internal sub-skill — invoked by sk.plan orchestrator. Do not invoke directly.

**When to run:** As Phase 2 of the sk.plan orchestrator.
Validates all generated plans against the unit architecture and global models to catch conflicts
and spec drift before implementation.
CRITICAL, HIGH, or MEDIUM findings must be resolved before implementation may proceed.

## Pre-flight
Run the unit pre-flight in `.claude/skills/governance/preflight.md` (session focus, UNIT_DIR / DESIGN_DIR /
PLAN_DIR, Impacted Projects). This skill is READ-ONLY; it never writes status or gates.

## Context loading
Load these artifacts (report MISSING if required artifact absent). Knowledge homes are loaded per the
loading rules in `.claude/skills/governance/profile.md`:
- DESIGN_DIR/architecture.md (required)
- DESIGN_DIR/impact-analysis.md (required — per-project blast radius; source of impacted projects)
- UNIT_DIR/unit-brief.md (Impacted Projects + Stories tables)
- UNIT_DIR/01-story/ (story.md, requirement.md, acceptance-criteria.md)
- DESIGN_DIR/contract-changes.md (if exists — change list, compatibility classes, consumers)
- The branch diff of the canonical contract files (committed and uncommitted):
  `git diff $(git merge-base {vcs.base_branch} HEAD) -- specs/openapi specs/asyncapi`
  (`vcs.base_branch` from `.specify/profile.yaml`, default `dev`). Read only the hunks of the files and
  operations contract-changes.md names, plus the file list of the diff to detect unlisted changes.
- DESIGN_DIR/database-design.md (if exists)
- DESIGN_DIR/projects/{Project}.md (per impacted project, if exists)
- PLAN_DIR/{Project}/plan.md (for each impacted project that has been planned)
- `specs/domain/bounded-contexts.md` and the `specs/domain/{module}.md` of each context the unit touches
- `specs/adr/adr-index.md` → the ALWAYS ADRs plus the ADRs of every signal block matching this unit
- `.specify/memory/constitution.md`
- `.specify/memory/projects/index.md` (Role column — who consumes which audience)

## Consistency checks

### A. Stories coverage
- Every story in UNIT_DIR/01-story/ must appear in architecture.md stories-covered section
- Every story listed in architecture.md stories-covered must have a corresponding story file
- Missing stories: CRITICAL finding

### B. Contract consistency
- Every operation added, changed or removed in the canonical spec diff must have a row in
  contract-changes.md, and every row must match a hunk of the diff (same file, operation, change kind)
- Each row carries a compatibility class from `contracts.compat_rules` (default
  `additive | deprecating | breaking`); the class must fit the diff (a removed field or operation is not `additive`)
- A `breaking` row must name its versioned replacement or the ADR that accepts the break
- Consumers listed per row must be impacted projects of this unit or be named as out of scope, and must
  agree with the consuming projects' Role in `projects/index.md` and the routed ADRs
- A non-empty canonical diff with no contract-changes.md, or contract-changes.md rows with an empty diff:
  HIGH finding. Both absent: check B passes (`no contract change in this unit`)
- Diff/change-list mismatch or an unclassified change: HIGH finding; an unjustified `breaking` change: CRITICAL finding

### C. Data model alignment
- Every entity in DESIGN_DIR/database-design.md must belong to a bounded context registered in
  `specs/domain/bounded-contexts.md`
- Entities, invariants and ownership must not contradict the owning `specs/domain/{module}.md`
- An existing entity (in the code) redefined with conflicting attributes: HIGH finding
- Conflicts with a domain file, or an entity in no registered context: HIGH finding

### D. Project-plan alignment
- For each impacted project: PLAN_DIR/{Project}/plan.md tech choices must not contradict
  architecture.md or its DESIGN_DIR/projects/{Project}.md slice
- A plan may not claim work owned by another project (scope creep across the project boundary): HIGH finding
- Dependency on an external service not listed in architecture.md / impact-analysis.md dependencies: HIGH finding
- Implementation Sequence must not contradict impact-analysis.md → Sequencing & Dependencies: MEDIUM finding
- For a Frontend/Mobile plan: every consumed operation/claim must exist in the canonical spec on this
  branch (no invented contract): HIGH finding

### D2. Project-plan coverage
- Every project in unit-brief.md → Impacted Projects must have a PLAN_DIR/{Project}/plan.md
  (unless this is a TARGETED run; the orchestrator reports which were intentionally skipped)
- Each plan folder must contain all five artifacts (plan.md, tasks.md, checklist.md,
  jira-subtask.md, estimation.md); a missing artifact is a MEDIUM finding
- Files Affected, tasks.md, and estimation.md within a project must be mutually consistent
  (every affected file has a task and an estimate): MEDIUM finding
- Unplanned impacted project (no plan folder, not reported skipped): HIGH finding

### E. Bounded context integrity
- No entity defined in this unit may be owned by another bounded context (check
  `specs/domain/bounded-contexts.md` and the owning `specs/domain/{module}.md`)
- Cross-context access must go through a contract operation or a relation declared in
  bounded-contexts.md, not direct coupling
- Boundary violations: CRITICAL finding

### F. ADR and constitution compliance
- Check each ADR routed by `specs/adr/adr-index.md` for this unit (ALWAYS block + matching signal blocks)
- Check `.specify/memory/constitution.md` principles
- Flag any story, design or plan element that violates an ADR decision or a constitution principle
- ADR or constitution violations: CRITICAL finding

## Report format
Output a Markdown report with:

| ID | Check | Severity | Location | Finding | Recommendation |
|----|-------|----------|----------|---------|----------------|

Severity scale: CRITICAL | HIGH | MEDIUM | LOW

Followed by:
- **Summary**: total findings by severity
- **Story coverage map**: {story-id} → in architecture.md (yes/no)
- **Project plan coverage map**: {Project} → plan folder present (yes/no), all five artifacts (yes/no)
- **Next actions**: if any MEDIUM, HIGH, or CRITICAL findings exist, list all findings. The user must resolve them and re-run sk.plan --analyze-only before proceeding to implementation. LOW findings are reported but do not block.

If no findings: report "All consistency checks passed" with coverage metrics.

## Quality Bar
- All stories covered by architecture
- Every impacted project has a complete plan folder (or is reported as intentionally skipped)
- No project plan contradicts architecture.md or its design slice; no cross-project scope creep
- No bounded context violations
- No ADR or constitution violations
- Contract change list matches the canonical spec diff; every change classified
- No entity conflicts with the owning domain file
