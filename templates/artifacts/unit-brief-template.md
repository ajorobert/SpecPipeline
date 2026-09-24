---
id: {INTENT-CODE}-{UNIT-CODE}
intent: {INTENT-CODE}
title: {title}
status: draft | active | complete
created: {date}
updated: {date}
---

# Unit: {title}

## Owns
<!-- List the specific domains, data structures, and behaviors this unit is responsible for.
Example:
- User schemas and Database tables for Users
- Credential hashing and validation logic
-->

## Bounded Context
<!-- Define the boundaries of this unit. What lives completely inside? What boundary must not be crossed without an API contract?
Example: Auth unit does not know about permissions/billing, it only verifies identity. -->

## Dependencies
<!-- List external systems, databases, or other units this unit relies on to function.
Example:
- Primary relational store
- Email Service (for password resets)
- INTENT-OTHER-01 (API contract reliance)
-->

## Impacted Projects
<!-- Written by sk.story_sub_architect-probe. One row per project this unit changes; names and code roots come from
     .specify/memory/projects/index.md. Every per-project phase (02-design/projects/, 03-plan/, 04-implementation/,
     05-test/) reads this table. Type: Backend | Frontend | Mobile.
Written by sk.story_sub_architect-probe (both [FULL] and [IMPACT-ONLY] modes). It is NEVER left
empty: sk.design / sk.plan / sk.implement / sk.test all STOP on an empty table, and their
preconditions check for a populated row.
Each row: the exact Project name and Code Root from projects/index.md, the Type, and a concrete role
(e.g. "session endpoints + token validation", not "backend work").
-->
| Project | Type | Code Root | Role in this unit |
|---|---|---|---|

## Story
<!-- The unit's story lives in 01-story/ (one story per unit).
- {INTENT}-{UNIT}-{NNN}: {story title}
-->
