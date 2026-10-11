---
name: sk.knowledge-base
description: "Invoke when: generating or updating non-derivable context at system, domain, or unit tier. Use --tier system|domain|unit. Role: architect. Reads: .specify/state/session.yaml, .specify/profile.yaml (knowledge.*), the existing tier file, specs/adr/adr-index.md → routed ADRs, specs/domain/bounded-contexts.md, .specify/memory/projects/index.md. Writes: specs/knowledge-base.md (system), specs/domain/{module}.md + bounded-contexts.md registration (domain), specs/intents/{intent}/units/{unit}/knowledge-base.md (unit)."
subagent_type: SpecKit Architect Agent
inject_files:
  - specs/adr/adr-index.md
  - specs/domain/bounded-contexts.md
---

Generates or updates knowledge bases. Zero tolerance for content derivable from code.
Tier 1 (system, `specs/knowledge-base.md`): 300 line hard limit. Tier 2 (domain, `specs/domain/{module}.md`): 250 lines. Tier 3 (unit): 150 lines.
Never writes a fact whose home is an ADR, a rule file or a contract.

Read and execute the full workflow in `prompt.md` in this directory.
