---
name: sk.ff
description: "Invoke when: running the full Fast Forward pipeline from story capture to planning in one shot. Role: lead (orchestrator). Modes: sk.ff (feature) or sk.ff --bug (bug fix). Invokes with the Skill tool: sk.story → sk.design (per checkpoint_mode) → sk.plan in sequence. Reads: .specify/state/session.yaml, specs/knowledge-base.md, .specify/memory/projects/index.md, 01-story/story.md (checkpoint_mode)."
subagent_type: SpecKit Lead Agent
inject_files:
  - .claude/skills/governance/checkpoint-rules.md
  - .specify/memory/projects/index.md
---

Orchestrator skill — Fast Forward pipeline.
Invokes sk.story → [sk.design] → sk.plan in sequence, each with the Skill tool, all in one window.
Intended for small scope (few clarifications; checkpoint_mode autopilot or confirm). For a large unit
under validate, run the three phases as separate sessions (`governance/session-boundaries.md`).
Sub-orchestrators run in this context; each dispatches its own workers where migrated. Checkpoints respected between phases.

Read and execute the full workflow in `prompt.md` in this directory.
