---
id: {INTENT-CODE}-{UNIT-CODE}-{NNN}
intent: {INTENT-CODE}
unit: {INTENT-CODE}-{UNIT-CODE}
title: {title}
status:
  current: draft        # draft | ready | in-progress | testing | review | review-rejected | verify | security-review | done | shipped | rolled-back
  entered_at: {date}    # ISO 8601 datetime when current state was entered (set by story-status.sh / hooks)
  completed_at: null    # ISO 8601 datetime when story reached 'done'
  blocked_by: null      # task id, story id, or free-text reason if blocked
owner: null
story_type: feature     # feature | bug | hotfix
tags: []                # keywords from the Signals column of .claude/skills/README.md ## Registry (drive pack resolution)
checkpoint_mode: null   # autopilot | confirm | validate — single source of truth for every gate
checkpoint_status: null # null | approved
architecture-ref: null  # relative path to ../02-design/architecture.md
test-status: null       # null | pass | fail
security-status: null   # null | clear | conditional | blocked
verify-status: null     # null | PASS | FAIL  (set by sk.verify via Stop hook)
jira_id: null           # tracker issue key; every status transition mirrors to it (governance/tracker-mirror.md)
created: {date}
updated: {date}
branch: null
---

# Story: {title}

## User Story
<!-- REQUIRED FORMAT:
As a [role],
I want to [action],
So that [value or reason].
-->

## Acceptance Criteria
<!-- REQUIRED FORMAT: Use checklist format with BDD (Given/When/Then) syntax where applicable.
Example:
- [ ] **Scenario**: User logs in
  - Given the user is on the login page
  - When they enter valid credentials
  - Then they are redirected to the dashboard
-->

## Out of Scope
<!-- List explicit features, edge cases, or optimizations that are NOT part of this story to prevent scope creep. -->

## Notes
<!-- Any implementation hints, references to ADRs, linking to upstream specs, or open questions. -->
