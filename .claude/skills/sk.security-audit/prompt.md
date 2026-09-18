# sk.security-audit — Security Audit (Unit)
Security audit of a unit's implementation across every impacted project.
Role: security | Level: unit

The security audit is cross-cutting: it covers the whole unit, spanning every impacted project's code
root, not a single service. Its output is a single flat `07-security-audit/` folder for the unit (NOT
one folder per project), splitting the audit into four artifacts.

## Invocation Forms
- `sk.security-audit`                       — audit the whole unit (all impacted projects)
- `sk.security-audit --projects {key}`      — scope the audit to ONE impacted project's code root

`--projects` narrows the source scope only; the OWASP/STRIDE reasoning and verdict remain unit-level.

## Pre-flight
1. Run the unit pre-flight in `.claude/skills/governance/preflight.md` (session focus, UNIT_DIR/DESIGN_DIR,
   Impacted Projects, `checkpoint_mode` from `01-story/story.md`, knowledge bases).
2. Resolve `AUDIT_DIR = UNIT_DIR/07-security-audit/`.
3. From the Impacted Projects table collect each project's `{CodeRoot}` — these code roots (plus their
   tests) are the in-scope source for the audit. `--projects {key}` resolves per
   `.claude/skills/governance/project-resolution.md`.

## Input Artifacts
- UNIT_DIR/unit-brief.md                              (Impacted Projects → the {CodeRoot} set to scan)
- {CodeRoot}/** for each impacted project             (implementation + tests under audit)
- DESIGN_DIR/contracts/api-spec.json                  (endpoints + error contract; input-validation surface)
- DESIGN_DIR/architecture.md                          (trust boundaries, IdP, data flows)
- DESIGN_DIR/projects/{Project}.md                    (per-project Security sections, if present)
- .specify/memory/architecture-decisions.md           (auth ADR + security-relevant constraints)
- UNIT_DIR/knowledge-base.md                          (non-derivable invariants — e.g. PII deny-list,
                                                        mandatory tenant claim, no-enumeration rules)
- UNIT_DIR/01-story/ acceptance-criteria.md           (security-relevant acceptance criteria)

## Audit Scope
Determine scope from the unit and its impacted projects. The audit reasons about the unit as a whole
(cross-project trust boundaries, identity flow, data exposure) while grounding each finding in a
specific file + line within one of the impacted `{CodeRoot}`s. If a project has no code yet (planned
roots only), audit the design slice and record code-level checks as "pending implementation".

## Steps
1. Build the in-scope file set: every impacted project's `{CodeRoot}` (and tests), filtered to what
   this unit changed. Note any project still at planned-root stage.
2. Evaluate each **OWASP Top 10** category against the implementation → `owasp-report.md`.
3. Verify **authentication** boundaries against the auth ADR in architecture-decisions.md and the
   IdP model in architecture.md (token validation, issuer/audience, signature, claim mapping).
4. Verify **authorization** boundaries: RBAC/ABAC policies, the mandatory-claim / tenant-isolation
   invariant from knowledge-base.md, and that 403 paths reject rather than leak.
5. Scan for **secrets and hardcoded credentials** across the in-scope file set → record in
   `dependency-scan.md` (Secrets section).
6. Review the **dependency list** for known CVEs (name the scan tool used) → `dependency-scan.md`.
7. Check **API input validation** coverage against api-spec.json (every input validated; error
   contract does not over-disclose).
8. Review **logging / telemetry** for sensitive-data exposure (honor the knowledge-base PII deny-list).
9. Perform **STRIDE** threat modeling → `stride-review.md`.
10. Write `security-signoff.md` with the rolled-up verdict and set the unit story `security-status`.

## Output Artifacts
Write the flat unit-level audit folder `UNIT_DIR/07-security-audit/`. Every file starts with
front-matter (`unit`, `intent`, `created`, `updated`).

### owasp-report.md
OWASP Top 10 evaluation for the unit.
```
# OWASP Top 10 Report: {unit name} ({unit-id})

| # | Category | Verdict | Scope (project / file:line) | Finding | Severity | Remediation |
|---|----------|---------|-----------------------------|---------|----------|-------------|
| A01 | Broken Access Control | PASS/FAIL/NA | … | … | CRITICAL/HIGH/MEDIUM/LOW | … |
… all 10 categories …

## Auth Verification
- Authentication: {how verified against the auth ADR} — verdict + evidence.
- Authorization: {RBAC/ABAC + tenant-isolation invariant} — verdict + evidence.

## Summary
Findings by severity; categories PASS/FAIL/NA count.
```
Every OWASP category MUST have a documented verdict (PASS / FAIL / NA). Every CRITICAL and HIGH finding
MUST carry a `project / file:line` reference and specific (not generic) remediation.

### stride-review.md
STRIDE threat model for each service/component in scope.
```
# STRIDE Review: {unit name} ({unit-id})

| Threat | Evaluation focus | Verdict | Evidence (project / file:line) | Severity |
|--------|------------------|---------|--------------------------------|----------|
| Spoofing | Impersonation of a user/service? Auth mechanism sufficient? | PASS/FAIL/NA | … | … |
| Tampering | Data modified in transit/at rest without detection? Integrity checks? | … | … | … |
| Repudiation | Can a user deny an action? Audit logs sufficient/tamper-evident? | … | … | … |
| Information Disclosure | Sensitive data exposed? Over-broad errors? PII in logs? | … | … | … |
| Denial of Service | Service made unavailable? Rate/resource limits present? | … | … | … |
| Elevation of Privilege | Gain permissions beyond authorized? Escalation vectors? | … | … | … |

## Summary
Findings by severity. STRIDE CRITICAL findings block progression (same rule as OWASP CRITICAL).
```
All 6 categories evaluated with evidence; severity on the same scale as OWASP.

### dependency-scan.md
```
# Dependency & Secrets Scan: {unit name} ({unit-id})

## Dependencies
Scan tool used: {tool}. Table: | Package | Version | Advisory/CVE | Severity | Status (addressed/open) |.
State "no unaddressed critical CVEs" explicitly when clean.

## Secrets
Scan tool/method used. Findings: hardcoded secrets/credentials/tokens in the in-scope file set —
or "CLEAN — no hardcoded secrets in scope". Honor the knowledge-base PII deny-list.
```

### security-signoff.md
```
---
unit: {unit-id}
intent: {intent-id}
security-status: {clear | conditional | blocked}
verdict: {CLEAR | CONDITIONAL | BLOCKED}
created: {today}
updated: {today}
---

# Security Sign-off: {unit name} ({unit-id})

## Verdict
{CLEAR | CONDITIONAL | BLOCKED} — one-line justification.
- BLOCKED → unit cannot proceed to review/ship (any CRITICAL finding — OWASP or STRIDE).
- CONDITIONAL → HIGH findings acknowledged with tracking references; proceed with tracking.
- CLEAR → no CRITICAL or HIGH findings.

## Findings Roll-up
Counts by severity across owasp-report.md + stride-review.md + dependency-scan.md.
CRITICAL and HIGH findings listed with their project / file:line and remediation owner.

## Conditions / Follow-ups
Tracking references for accepted HIGH findings; required fixes before ship for any BLOCKED item.
```

## Status Roll-up
Set `security-status` in the unit's `01-story/story.md` frontmatter:
- `blocked` if any CRITICAL finding is open (OWASP or STRIDE).
- `conditional` if HIGH findings exist but are acknowledged/tracked and no CRITICAL is open.
- `clear` if no CRITICAL or HIGH findings.
`security-status` is the field sk.ship reads (BLOCKED stops ship).

## Sign-off Gate
Protocol: `.claude/skills/governance/review-gate.md`. Active for `confirm` and `validate`: display the
verdict + CRITICAL/HIGH findings and request acknowledgement before writing the `security-status` roll-up.
If `autopilot`: roll up automatically per the rules above and log it. A BLOCKED verdict is never auto-cleared.

## Quality Bar
- All OWASP Top 10 items documented as PASS/FAIL/NA across the unit's impacted code roots.
- STRIDE table present with all 6 threat categories evaluated, each with evidence.
- Every CRITICAL and HIGH finding (OWASP + STRIDE) has a `project / file:line` reference and specific
  remediation.
- Authentication and authorization boundaries explicitly verified against the auth ADR and the
  tenant-isolation / mandatory-claim invariant.
- Secrets scan run (CLEAN or findings listed); dependency scan names the tool and flags CVEs.
- The four flat artifacts written under `07-security-audit/` (owasp-report.md, stride-review.md,
  dependency-scan.md, security-signoff.md).
- Overall verdict CLEAR | CONDITIONAL | BLOCKED, and `security-status` rolled up to match.
- The audit reports findings only — it does not modify implementation code to resolve them.

## Completion Signal
Last line of output must be exactly one of (see `.claude/skills/governance/status-model.md`):
`SK_RESULT: PASS` — the audit ran to completion with no open CRITICAL finding
`SK_RESULT: FAIL` — the audit could not complete, or a CRITICAL finding is open
