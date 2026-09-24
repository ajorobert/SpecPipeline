---
name: sk.ship
description: "Invoke when: promoting a unit's durable knowledge and creating the PR after all quality gates pass. Role: lead. Reads: .specify/state/session.yaml, .specify/profile.yaml (vcs.*, rules.stacks, knowledge.*, tracker.*), 01-story/, unit-brief.md, knowledge-base.md, 02-design/architecture.md, 02-design/contract-changes.md, investigation-report.md, review reports. Writes: promotion targets (via sk.adr / sk.knowledge-base, specs/domain/{module}.md, .claude/rules/{stack}/), UNIT_DIR/promotion.md, PR. Requires: sk.verify PASS, test-status=pass, security-status not blocked, checkpoint_mode set. Flag: --dry-run."
subagent_type: SpecKit Lead Agent
disable-model-invocation: true
inject_files:
  - .specify/profile.yaml
  - .claude/skills/governance/promotion.md
preconditions:
  - story.verify-status == PASS
  - story.test-status == pass
  - story.security-status != blocked
  - "story.checkpoint_mode in [autopilot, confirm, validate]"
---

Quality-gated release: promote, pass the Ship Gate, open the PR. On `SK_RESULT: PASS` the Stop hook sets
`shipped`, which freezes the unit.
Hard blocks: verify-status≠PASS, security-status=blocked, test-status≠pass, checkpoint_mode unset, Ship Gate FAIL.
`--dry-run` shows the promotion list and the PR title/base without writing or pushing.

Read and execute the full workflow in `prompt.md` in this directory.
