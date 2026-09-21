---
name: sk.ship
description: "Invoke when: creating a PR and shipping a story after all quality gates pass. Role: lead. Reads: session.yaml, 01-story/story.md, service-registry.md. Requires: sk.verify PASS, test-status=pass, security-status not blocked, checkpoint_mode set."
subagent_type: SpecKit Lead Agent
disable-model-invocation: true
inject_files:
  - .specify/memory/service-registry.md
preconditions:
  - story.verify-status == PASS
  - story.test-status == pass
  - story.security-status != blocked
  - "story.checkpoint_mode in [autopilot, confirm, validate]"
---

Quality-gated release. Runs sk.verify before proceeding.
Hard blocks: sk.verify FAIL, security-status=blocked, test-status≠pass, checkpoint_mode unset.

Read and execute the full workflow in `prompt.md` in this directory.
