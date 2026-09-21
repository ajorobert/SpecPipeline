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
Load these artifacts (report MISSING if required artifact absent):
- DESIGN_DIR/architecture.md (required)
- DESIGN_DIR/impact-analysis.md (required — per-project blast radius; source of impacted projects)
- UNIT_DIR/unit-brief.md (Impacted Projects + Stories tables)
- UNIT_DIR/01-story/ (story.md, requirement.md, acceptance-criteria.md)
- DESIGN_DIR/contracts/api-spec.json (if exists)
- DESIGN_DIR/database-design.md (if exists)
- DESIGN_DIR/projects/{Project}.md (per impacted project, if exists)
- PLAN_DIR/{Project}/plan.md (for each impacted project that has been planned)
- .specify/memory/service-registry.md
- .specify/memory/domain-model.md
- .specify/memory/architecture-decisions.md

## Consistency checks

### A. Stories coverage
- Every story in UNIT_DIR/01-story/ must appear in architecture.md stories-covered section
- Every story listed in architecture.md stories-covered must have a corresponding story file
- Missing stories: CRITICAL finding

### B. Contract consistency
- Every endpoint in DESIGN_DIR/contracts/api-spec.json must be referenced or consistent with service-registry.md
- No endpoint in api-spec.json may contradict a registered service boundary
- Contract changes not reflected in service-registry.md: HIGH finding

### C. Data model alignment
- Every entity in DESIGN_DIR/database-design.md must be present in .specify/memory/domain-model.md
- Entity attributes must not conflict between unit and global domain model
- Conflicts or missing entities: HIGH finding

### D. Project-plan alignment
- For each impacted project: PLAN_DIR/{Project}/plan.md tech choices must not contradict
  architecture.md or its DESIGN_DIR/projects/{Project}.md slice
- A plan may not claim work owned by another project (scope creep across the project boundary): HIGH finding
- Dependency on an external service not listed in architecture.md / impact-analysis.md dependencies: HIGH finding
- Implementation Sequence must not contradict impact-analysis.md → Sequencing & Dependencies: MEDIUM finding
- For a Frontend/Mobile plan: every consumed endpoint/claim must exist in api-spec.json /
  api-contract.md (no invented contract): HIGH finding

### D2. Project-plan coverage
- Every project in unit-brief.md → Impacted Projects must have a PLAN_DIR/{Project}/plan.md
  (unless this is a TARGETED run; the orchestrator reports which were intentionally skipped)
- Each plan folder must contain all five artifacts (plan.md, tasks.md, checklist.md,
  jira-subtask.md, estimation.md); a missing artifact is a MEDIUM finding
- Files Affected, tasks.md, and estimation.md within a project must be mutually consistent
  (every affected file has a task and an estimate): MEDIUM finding
- Unplanned impacted project (no plan folder, not reported skipped): HIGH finding

### E. Bounded context integrity
- No entity defined in this unit may be owned by another unit (check service-registry.md)
- Cross-unit access must go through a defined contract endpoint, not direct coupling
- Boundary violations: CRITICAL finding

### F. ADR constraint compliance
- Check each ADR in architecture-decisions.md that applies to this unit
- Flag any story or plan element that violates an ADR decision
- ADR violations: CRITICAL finding

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
- No ADR constraint violations
- No entity conflicts with global domain model
