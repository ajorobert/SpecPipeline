---
story: {story-id}
unit: {unit-id}
audited-by: security
date: {date}
verdict: CLEAR | CONDITIONAL | BLOCKED
---

# Security Audit: {story-id}

## Scope
<!-- What was audited: services, endpoints, components -->

## OWASP Top 10 Assessment
| Category | Status | Notes |
|----------|--------|-------|
| A01 Broken Access Control | PASS/FAIL/NA | |
| A02 Cryptographic Failures | PASS/FAIL/NA | |
| A03 Injection | PASS/FAIL/NA | |
| A04 Insecure Design | PASS/FAIL/NA | |
| A05 Security Misconfiguration | PASS/FAIL/NA | |
| A06 Vulnerable Components | PASS/FAIL/NA | |
| A07 Auth Failures | PASS/FAIL/NA | |
| A08 Integrity Failures | PASS/FAIL/NA | |
| A09 Logging Failures | PASS/FAIL/NA | |
| A10 SSRF | PASS/FAIL/NA | |

## Findings

### CRITICAL
<!-- File, line, description, remediation -->

### HIGH
<!-- File, line, description, remediation -->

### MEDIUM
<!-- File, line, description, remediation -->

### LOW
<!-- File, line, description, remediation -->

## Secrets Scan
Tool used:
Result: CLEAN | FINDINGS

## Dependency Scan
Tool used:
Critical CVEs:
High CVEs:

## Verdict
CLEAR | CONDITIONAL | BLOCKED
Reason:

## STRIDE Threat Model
<!-- Evaluate each threat category for each service/component in scope.
     Record: PASS / FAIL / NA with evidence.
     Severity: CRITICAL | HIGH | MEDIUM | LOW (same scale as OWASP findings).
     STRIDE CRITICAL findings block story progression (same rule as OWASP CRITICAL). -->

| Threat | Evaluation Focus | Status | Severity | Evidence / Notes |
|--------|-----------------|--------|----------|-----------------|
| **S**poofing | Can an attacker impersonate a legitimate user or service? Auth mechanism sufficient? | PASS/FAIL/NA | | |
| **T**ampering | Can data be modified in transit or at rest without detection? Integrity checks present? | PASS/FAIL/NA | | |
| **R**epudiation | Can a user deny performing an action? Are audit logs sufficient and tamper-evident? | PASS/FAIL/NA | | |
| **I**nformation Disclosure | Can sensitive data be exposed to unauthorized parties? Over-broad error messages? | PASS/FAIL/NA | | |
| **D**enial of Service | Can the service be made unavailable? Rate limiting and resource limits in place? | PASS/FAIL/NA | | |
| **E**levation of Privilege | Can a user gain permissions beyond what is authorized? Privilege escalation vectors? | PASS/FAIL/NA | | |
