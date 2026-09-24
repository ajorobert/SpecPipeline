---
story-id: {INTENT-CODE}-{UNIT-CODE}-{NNN}
intent: {INTENT-CODE}
unit: {INTENT-CODE}-{UNIT-CODE}
session_count: 1
---

# Investigation Report — {story title}
<!-- Sessions are prepended newest-first. Do not edit prior sessions. -->

---

## Investigation INV-001 — {date}
**Investigated by**: {role}
**Acceptance criteria in scope**:
<!-- Snapshot of relevant AC from 01-story/acceptance-criteria.md at time of this investigation -->

### Findings

#### Finding-001
**Classification**: Implementation Bug | Spec/Contract Mismatch
**Expected** (per spec): <!-- quote the relevant AC, or the canonical operation (specs/openapi/{audience}.yaml / specs/asyncapi/{module}.yaml) listed in 02-design/contract-changes.md -->
**Actual** (observed): <!-- what the system actually does -->
**Root cause**: <!-- specific code-level cause for impl bug; or why spec doesn't match required behavior for mismatch -->
**Affected artifact**: <!-- {CodeRoot}/file:line for impl bug; story AC# or the canonical spec file + operation for mismatch -->

<!-- Repeat Finding-002, Finding-003 etc. for each additional bug found in this session -->

### Classification Summary
| Finding | Classification | Affected Artifact |
|---------|---------------|-------------------|
| Finding-001 | Implementation Bug \| Spec/Contract Mismatch | {artifact} |

**Verdict for this session**:
- [ ] All Implementation Bugs → run /sk.phr, fix in the project's code root, run /sk.test
- [ ] Spec/Contract Mismatch present → update AC in 01-story/acceptance-criteria.md, run /sk.design --contracts if contract shape changed

### Candidate Invariants (this session)
<!-- Unreviewed staging entries, also appended to the unit knowledge-base.md. Promotion at ship (governance/promotion.md) moves each surviving one to its home: specs/domain/{module}.md, an ADR, or a .claude/rules/{stack}/ file -->
<!-- Skip and note reason for obvious invariants (null checks, input validation, etc.) -->
- [INV-001] {rule that must hold, not obvious from reading code} — story {story-id} ({date})

---
<!-- Prior sessions appear below this line, prepended newest-first -->
