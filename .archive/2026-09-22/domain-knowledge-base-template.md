---
tier: domain
domain: {domain-name}
last-updated: {date}
---

# {Domain} Domain — Non-Derivable Context

## Why This Is a Separate Domain
<!-- Business reason this is a bounded context.
     What would break if merged with another domain. -->

## Boundary Definition
<!-- What this domain owns and why.
     What it explicitly does NOT own and why.
     Who enforces this boundary. -->

## Business Invariants
<!-- Rules that must hold regardless of code changes.
     These may be enforced across multiple files/services. -->

## Cross-Domain Contracts
<!-- Agreements with other domains not visible in any single API spec.
     What other domains can expect from this one.
     What this domain can expect from others. -->

## What Was Tried and Rejected
<!-- Domain-level approaches considered and why rejected.
     Prevents re-litigating settled decisions. -->

## Evolution History
<!-- Significant changes to this domain's design over time.
     What drove those changes. -->

## Safe Change Patterns
<!-- How to safely extend this domain.
     What changes require an ADR.
     What changes require cross-domain coordination. -->
