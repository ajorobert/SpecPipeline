---
unit: {unit-id}
intent: {intent-id}
status: draft | approved
created: {date}
updated: {date}
---

# Impact Analysis: {unit-name}

Per-project blast radius of this unit's design. Source of truth for the impacted
projects is `unit-brief.md` (Impacted Projects table, written by sk.story_sub_architect-probe);
this document records WHAT the design changes in each of those projects.

## Impacted Projects
<!-- One row per project in unit-brief.md → Impacted Projects.
     Change type: new | modified | config-only | none.
     Format:
     | Project | Type | Code Root | Change Type | What Changes |
     |---------|------|-----------|-------------|--------------|
     | {BackendProject} | Backend | {backend-code-root} | modified | Token validation, user context, session endpoints |
     | {WebProject} | Frontend | {web-code-root} | modified | Login UI + identity-provider client |
     REQUIRED: every project from unit-brief.md appears exactly once. -->

## Cross-Project Contracts
<!-- Contracts that cross a project boundary (API, event, shared schema).
     For each: producer project → consumer project(s), and the api-contract.md / api-spec.json reference.
     Example:
     - {BackendProject} exposes POST /api/v1/auth/session → consumed by {WebProject}, {AdminProject}, {MobileProject} -->

## Sequencing & Dependencies
<!-- Build/deploy order implied by the design.
     Example:
     - Backend session endpoints must ship before any frontend identity client can integrate. -->

## Risk & Rollout Notes
<!-- Blast-radius risks, breaking changes, feature-flag or migration coupling.
     If a change is breaking for a downstream project, name it here and link the mitigation. -->

## Per-Project Design Pages
<!-- Index of the detailed per-project design files generated under projects/.
     Format: - [{Project}](projects/{Project}.md) — {one-line scope} -->
