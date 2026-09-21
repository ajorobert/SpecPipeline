Quality Gates
Used by: sk.verify

Gate Definitions
Each gate is PASS, FAIL, or SKIP (with a reason). sk.verify reports every result.
A single FAIL blocks progression to the next phase.
Paths follow `.claude/skills/governance/phase-layout.md` (UNIT_DIR = specs/intents/{intent}/units/{unit}/).

Spec Gate (before sk.plan)
- [ ] Intent exists: specs/intents/{intent}/intent.md
- [ ] Active unit and story set in .claude/session.yaml; UNIT_DIR/01-story/story.md exists
- [ ] UNIT_DIR/01-story/acceptance-criteria.md present; every criterion testable
- [ ] Impacted Projects recorded in UNIT_DIR/unit-brief.md
- [ ] No undefined external dependencies

Architecture Gate (before sk.implement)
- [ ] UNIT_DIR/02-design/architecture.md and impact-analysis.md exist
- [ ] All new services registered in .specify/memory/service-registry.md
- [ ] All new domain entities added to .specify/memory/domain-model.md
- [ ] ADR raised for any cross-service decision
- [ ] checkpoint_mode set in story.md frontmatter (autopilot | confirm | validate)
- [ ] Consistency requirement declared per write path (strong / eventual / causal)
- [ ] Failure modes documented per external dependency (timeout, fallback, circuit breaker)

Plan Gate (before sk.implement)
- [ ] UNIT_DIR/03-plan/{Project}/plan.md exists for every impacted project (or skipped with reason)
- [ ] API contracts defined for any new endpoints (02-design/contracts/api-spec.json)
- [ ] Data model changes documented (02-design/database-design.md)
- [ ] No conflicts with existing contracts in service-registry.md
- [ ] Confirm/Validate checkpoint approved if required (plan.md status: approved)
- [ ] Idempotency-Key declared on all mutation endpoints

Implementation Gate (before merge)
- [ ] Every task in UNIT_DIR/03-plan/{Project}/tasks.md is done in 04-implementation/{Project}/progress.md (or blocked with reason)
- [ ] 04-implementation/{Project}/validation.md status PASS for every implemented project
- [ ] PHR created if novel tradeoffs were resolved
- [ ] Standards compliance: coding-standards.md and constitution.md
- [ ] No new domain entities introduced outside sk.design (datamodel phase)
- [ ] If the constitution requires command idempotency: every command carries commandId and handlers deduplicate
- [ ] If messaging_context = true in the constitution: no dual-write (event publish without outbox)

Test Gate (before story moves to security-review)
- [ ] Provider contract tests exist for every endpoint (05-test/{BackendProject}/contract-test.md)
- [ ] Consumer contract tests exist for every consumed endpoint (05-test/{Frontend|MobileProject}/contract-test.md)
- [ ] Every acceptance criterion has a mapped integration, component, or E2E test
- [ ] Integration tests cover service + database interactions
- [ ] Idempotency replay test for each non-idempotent command handler (if the constitution requires it)
- [ ] Coverage thresholds met: coding-standards.md Test Coverage Thresholds
- [ ] All tests pass; no forbidden skip idioms (per the project's tech-stack.md) without a documented reason
- [ ] UNIT_DIR/06-uat/signoff.md uat-status: pass (units with a user-facing surface)

Security Gate (before story moves to done)
- [ ] UNIT_DIR/07-security-audit/ contains owasp-report.md, stride-review.md, dependency-scan.md, security-signoff.md
- [ ] All OWASP Top 10 items documented as PASS/FAIL/NA
- [ ] No CRITICAL findings open
- [ ] HIGH findings acknowledged with tracking reference
- [ ] Secrets scan: CLEAN
- [ ] Dependency scan completed — no unaddressed critical CVEs
- [ ] security-status in story.md is clear or conditional (blocked prevents done)
