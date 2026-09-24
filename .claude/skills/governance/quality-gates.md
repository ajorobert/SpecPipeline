Quality Gates
Used by: sk.verify (Spec through Security gates) and sk.ship (Ship Gate — sk.verify runs before promotion, so it reports the Ship Gate as SKIP)

Gate Definitions
Each gate is PASS, FAIL, or SKIP (with a reason). sk.verify reports every result.
A single FAIL blocks progression to the next phase.
Paths follow `.claude/skills/governance/phase-layout.md` (UNIT_DIR = specs/intents/{intent}/units/{unit}/);
knowledge homes follow `.claude/skills/governance/profile.md`.
The framework ships no architecture rules: every rule-level check below judges the project's own
constitution, ADRs and `.claude/rules/`, never a framework default.

Spec Gate (before sk.plan)
- [ ] Intent exists: specs/intents/{intent}/intent.md
- [ ] Active unit and story set in .specify/state/session.yaml; UNIT_DIR/01-story/story.md exists
- [ ] UNIT_DIR/01-story/acceptance-criteria.md present; every criterion testable
- [ ] Impacted Projects recorded in UNIT_DIR/unit-brief.md, each a row of .specify/memory/projects/index.md
- [ ] No undefined external dependencies

Architecture Gate (before sk.implement)
- [ ] UNIT_DIR/02-design/architecture.md and impact-analysis.md exist
- [ ] Every bounded context the unit creates or changes is in specs/domain/bounded-contexts.md, with its
      specs/domain/{module}.md updated on this branch
- [ ] ADR raised (sk.adr) for every decision the architecture marks as cross-module or ADR-worthy
- [ ] ADR guard: `bash {SCRIPTS_DIR}/check-adr-index.sh` passes (skip only if knowledge.adr.guard is false)
- [ ] checkpoint_mode set in story.md frontmatter (autopilot | confirm | validate)
- [ ] Consistency requirement declared per write path (strong / eventual / causal)
- [ ] Failure modes documented per external dependency (timeout, fallback, circuit breaker)

Plan Gate (before sk.implement)
- [ ] UNIT_DIR/03-plan/{Project}/plan.md exists for every impacted project (or skipped with reason)
- [ ] Every new or changed operation is in the canonical spec (specs/openapi/*.yaml, specs/asyncapi/*.yaml)
      on this branch and listed in UNIT_DIR/02-design/contract-changes.md with its compatibility class
- [ ] Every `breaking` change has a versioned replacement or an ADR accepting the break
- [ ] Data model changes documented (02-design/database-design.md)
- [ ] Confirm/Validate checkpoint approved if required (plan.md status: approved)

Implementation Gate (before merge)
- [ ] Every task in UNIT_DIR/03-plan/{Project}/tasks.md is done in 04-implementation/{Project}/progress.md (or blocked with reason)
- [ ] 04-implementation/{Project}/validation.md status PASS for every implemented project
- [ ] No violation of constitution.md, the routed ADRs, or the project's .claude/rules/{stack}/ files
      (sk.review reports; a BLOCKING finding fails this gate)
- [ ] PHR created if novel tradeoffs were resolved
- [ ] No new persisted entity introduced outside sk.design (datamodel phase)

Test Gate (before story moves to security-review)
- [ ] Contract verification: `contracts.verify` (from .specify/profile.yaml) exits 0, or — when unset —
      provider contract tests exist and pass for every changed operation (05-test/{BackendProject}/contract-test.md)
- [ ] Consumer contract tests exist for every consumed changed operation (05-test/{Frontend|MobileProject}/contract-test.md)
- [ ] Every acceptance criterion has a mapped integration, component, or E2E test
      (E2E only where the project's tech-stack.md E2E Tooling is not `none`)
- [ ] Integration tests cover service + database interactions
- [ ] Coverage thresholds met, where the project's tech-stack.md declares Coverage Thresholds
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

Ship Gate (sk.ship, before the PR)
- [ ] UNIT_DIR/promotion.md exists: every promotable item has reached its home on this branch
      (`governance/promotion.md`), or it records "Nothing to promote — {reason}"
- [ ] ADR guard passes after promotion (skip only if knowledge.adr.guard is false)
- [ ] Tracker mirror: no pending or failed entries for this story (`story-status.sh show`), when a tracker is configured
