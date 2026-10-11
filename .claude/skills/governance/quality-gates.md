# Quality Gates
Used by sk.verify (Spec through Security) and sk.ship (Ship). Each item is PASS, FAIL or SKIP with a
reason. *(evidence)* items are computed by `bash .claude/hooks/verify-evidence.sh`; sk.verify judges only
the *(judgment)* items, from the artifact each names. Every rule-level check judges the project's own
ADRs, rules and principles — never a framework default. Paths follow `governance/phase-layout.md`.

## Spec
- *(evidence)* intent.md and acceptance-criteria.md exist; Impacted Projects has rows; `checkpoint_mode` is valid
- *(judgment)* every acceptance criterion is testable; the story-completeness rubric (sk.story) holds
- *(judgment)* no undefined external dependency

## Architecture
- *(evidence)* architecture.md and impact-analysis.md exist; the ADR guard passes (SKIP when `knowledge.adr.guard: false`)
- *(judgment)* every bounded context the unit creates or changes is in bounded-contexts.md, with its domain file updated on this branch
- *(judgment)* every decision marked `ADR required` is an ADR, or listed with a reason
- *(judgment)* a consistency requirement per write path and a failure mode per external dependency are declared

## Plan
- *(evidence)* a plan.md per impacted project; approved in confirm and validate
- *(judgment)* every changed operation is in the spec on this branch and in contract-changes.md with a compatibility class; every `breaking` row has a replacement or an accepting ADR
- *(judgment)* data-model changes are documented in database-design.md

## Implementation
- *(evidence)* every task done in each progress.md; each delivery.md `validation: PASS`; each review.md `verdict: APPROVED`
- *(judgment)* no persisted entity outside the design; no violation of the routed ADRs, the matched rules or the principles (the review reports are the evidence; re-read the matched rules only for an item they leave open)

## Test
- *(evidence)* each test-report.md `result: PASS`; `test-status: pass`; `contracts.verify` exits 0 (SKIP when unset); `uat-status: pass` for units with a Frontend/Mobile project
- *(judgment)* the test-coverage rubric (sk.test) holds for each report: criteria mapped, contract coverage, no unexplained skip, thresholds met where declared

## Security
- *(evidence)* security-report.md exists; `security-status` is clear or conditional
- *(judgment)* the security-coverage rubric (sk.security-audit) holds: all OWASP categories and STRIDE threats have verdicts, no open CRITICAL, HIGH findings tracked

## Ship (sk.ship; sk.verify reports it SKIP before promotion)
- *(evidence)* promotion.md exists; the tracker mirror has nothing pending or failed (when a tracker is configured)
- *(judgment)* every promotion row's target changed on this branch; the ADR guard passes after promotion
