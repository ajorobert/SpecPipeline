---
tier: unit
unit-id: {INTENT-CODE}-{UNIT-CODE}
intent: {INTENT-CODE}
last-updated: {date}
---

# {Unit} — Non-Derivable Context

## Why This Unit Exists
<!-- Business reason for this unit's existence.
     Why it is a separate unit with these boundaries. -->

## Key Decisions and Their Reasons
<!--
Format:
| Decision | Why | What breaks if you change this |
|----------|-----|-------------------------------|
-->

## What Was Tried and Rejected
<!-- Approaches considered for this unit and why rejected. -->

## Business Invariants
<!-- Rules specific to this unit that must never be violated.
     May not be obvious from any single file. -->

## External Constraints
<!-- Third-party limits, regulatory, contractual, or operational facts an agent can't derive from code.
     Format: - {constraint}: {source or reason}
     Example:
     - Payment provider retries each webhook up to 3 times over 24h: handling must tolerate repeats
     - Card-data compliance scope: card data must never touch this project; tokenization happens in the payments context only
     - Hosting runtime: 15-minute max execution; batch jobs must be chunked accordingly -->

## Safe Change Patterns
<!-- How to safely extend this unit. Be specific — generic advice ("write tests") is not useful here.
     Format:
     - Safe: {what you can change without cross-team impact or ADR}
     - Requires ADR: {what needs an architectural decision record before changing}
     - Requires coordination: {what needs sign-off or communication beyond this unit}
     Example:
     - Safe: adding new optional fields to order response payload (non-breaking)
     - Safe: adding new ORDER_STATUS values not referenced in consumer contracts
     - Requires ADR: changing the inventory reservation strategy (optimistic → pessimistic locking)
     - Requires coordination: modifying OrderPlaced event schema — billing-service is a consumer -->

## Evolution Notes
<!-- Significant refactors or pivots in this unit's history
     that constrain future changes. -->
