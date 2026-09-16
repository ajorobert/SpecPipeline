# AGENTS.md
This project uses SpecKit-SSD-SDLC. Agent instructions live in CLAUDE.md — read it first (@CLAUDE.md).
Skills: `.claude/skills/sk.*/SKILL.md` + `prompt.md` — load only the `inject_files` listed in the SKILL.md frontmatter.
Personas: `.claude/agents/{role}.md` · Session: `.claude/session.yaml` · Project memory: `.specify/memory/` · Specs: `specs/intents/`
Capability packs are project-owned, registered in `.specify/memory/skill-routing.md`, and resolved via `.claude/skills/governance/pack-resolution.md`.
