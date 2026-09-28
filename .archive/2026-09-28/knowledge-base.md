---
tier: system
last-updated:
---

# System Knowledge Base
Non-derivable system-wide context.
Read this before working on any module.

## Why This System Exists
<!-- Business purpose and core value proposition.
     Not what it does technically — why it exists as a product. -->

## Core Actors and Their Intent
<!-- Who uses this system and why.
     Not permissions — those are in code.
     The business reason behind each actor's existence.

Format:
### {Actor}
- Intent: why they use this system
- Key constraints: business rules that govern their behavior
- What they must never be able to do and why
-->

## Domain Map
The bounded contexts and how they relate: `specs/domain/bounded-contexts.md`.

## System-Wide Invariants
<!-- Rules that apply across all domains.
     Things that must be true regardless of which module you change.
     If you break these, the system breaks in non-obvious ways. -->

## Non-Obvious Cross-Domain Constraints
<!-- Dependencies between domains that aren't visible
     from any single service's code or API spec. -->

## Evolution History
<!-- Significant system-level decisions that constrain future design.
     What was tried at system level and why it was changed. -->
