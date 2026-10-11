---
name: sk.security-audit
description: "Security audit a unit's change across its impacted projects: OWASP Top 10, STRIDE, auth boundaries, input validation, secrets and dependency scan — with a signed-off verdict of clear, conditional or blocked."
role: security
rubric:
  name: security-coverage
  checks:
    - every OWASP Top 10 category has a documented verdict
    - STRIDE categories (Spoofing, Tampering, Repudiation, Information disclosure, Denial of service, Elevation) covered
    - no hardcoded secrets or credentials in scope
    - dependencies scanned for known CVEs
    - auth boundaries explicitly verified
    - every finding has a severity (CRITICAL|HIGH|MEDIUM|LOW) and a remediation
    - no CRITICAL finding unresolved
---

# sk.security-audit
Audits the unit's change, in one session. Output: `07-security-audit/security-report.md`;
`security-status` through story-status.sh. It reports; it never changes code.

## Invocation
- `sk.security-audit` — every impacted project. `--projects <name>` narrows the source scanned; the
  verdict stays unit-level.

## Pre-flight
Run `.claude/skills/governance/preflight.md` with command `security-audit`. In scope: what this unit
changed under each impacted project's Code Root (`git diff {vcs.base_branch}...HEAD`), its tests, the
spec operations contract-changes.md lists, the design's trust boundaries and security sections, the
ADRs routed for auth, security and data exposure, the touched domain files' isolation and sensitive-data
invariants, and the security-relevant acceptance criteria. A project with no code yet: audit its design
and mark the code checks "pending implementation". For a large diff, dispatch Explore subagents to
locate auth, input handling and logging sites, and read those.

## Steps
1. **OWASP Top 10** — a verdict (PASS / FAIL / NA) for every category, with evidence.
2. **Authentication** — token validation, issuer, audience, signature, claim mapping, as the routed ADRs
   and architecture.md define them.
3. **Authorization** — the access-control model of the ADRs and design; the isolation invariants of the
   domain files and knowledge base; rejected requests reject rather than leak.
4. **Input validation** — every input of the changed operations validated; error responses do not over-disclose.
5. **Logging and telemetry** — no sensitive data exposed, per the sensitive-data rules the project records.
6. **Secrets** — hardcoded secrets, credentials or tokens in the in-scope files.
7. **Dependencies** — known CVEs, naming the scanner. No scanner: `not run — no scanner available`, and
   review the manifests by hand; never invent a result.
8. **STRIDE** — the six threats for each component in scope.
9. **Verdict and gate** (`.claude/skills/governance/review-gate.md`; pauses in confirm and validate;
   autopilot rolls up by the rules below and logs it). Show the verdict and every CRITICAL and HIGH
   finding; then `bash .claude/hooks/story-status.sh field security-status <clear|conditional|blocked>`:
   - `blocked` — any open CRITICAL (OWASP or STRIDE). Never auto-cleared.
   - `conditional` — HIGH findings acknowledged with tracking references, no CRITICAL.
   - `clear` — no CRITICAL or HIGH.

## security-report.md
```
---
unit: {unit-id}
verdict: clear | conditional | blocked
---
# Security audit: {unit-id}
Scope: {projects, files changed, pending-implementation projects}
## OWASP Top 10 — | # | Category | Verdict | project / file:line | Finding | Severity | Remediation |  (all ten)
## Authentication and authorization — how each was verified, verdict, evidence.
## STRIDE — | Threat | Verdict | Evidence | Severity |  (all six)
## Input validation and logging — findings, or "none".
## Secrets — method; findings or "CLEAN".
## Dependencies — scanner; | Package | Version | Advisory | Severity | Status |; "no unaddressed critical CVEs" when clean.
## Roll-up — counts by severity; each CRITICAL and HIGH with its location, remediation and owner; tracking references.
```
Every CRITICAL and HIGH finding carries a `project / file:line` and a specific remediation.

## Completion report and signal
```
sk.security-audit — {unit-id}: {clear | conditional | blocked} ({counts by severity})
Next: /sk.verify — in a fresh session
```
Last line, exactly one of:
- `SK_RESULT: PASS` — the audit completed with no open CRITICAL finding
- `SK_RESULT: FAIL` — the audit could not complete, or a CRITICAL finding is open
