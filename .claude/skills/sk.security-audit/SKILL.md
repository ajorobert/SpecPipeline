---
name: sk.security-audit
description: "Invoke when: performing a security audit of a unit's implementation across every impacted project. Role: security. Runs at unit level. Reads: session.yaml, unit-brief.md, knowledge-base.md, each impacted project's {CodeRoot}, 02-design/contracts/api-spec.json, architecture-decisions.md, 01-story acceptance criteria. Writes: 07-security-audit/ (owasp-report.md, stride-review.md, dependency-scan.md, security-signoff.md) and the unit story security-status. Evaluates OWASP Top 10 + STRIDE."
subagent_type: Security Agent
inject_files:
  - .claude/skills/governance/checkpoint-rules.md
  - .specify/memory/architecture-decisions.md
rubric:
  name: security-coverage
  checks:
    - every OWASP Top 10 category has a documented verdict
    - STRIDE categories (Spoofing, Tampering, Repudiation, Info-disclosure, DoS, Elevation) covered
    - no hardcoded secrets or credentials in scope
    - dependencies scanned for known CVEs
    - auth boundaries explicitly verified
    - every finding has severity (CRITICAL|HIGH|MEDIUM|LOW) and remediation
    - no CRITICAL findings unresolved
---

Security audit of a unit's implementation across every impacted project: OWASP Top 10 + STRIDE threat
modeling, authentication and authorization verification, secrets scan, and dependency analysis.

Produces the flat `07-security-audit/` folder for the unit (not per-project): `owasp-report.md`,
`stride-review.md`, `dependency-scan.md`, `security-signoff.md`. Verdict: CLEAR | CONDITIONAL | BLOCKED.
CRITICAL findings (OWASP or STRIDE) block the unit's progression.

Read and execute the full workflow in `prompt.md` in this directory.
