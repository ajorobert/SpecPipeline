# AGENTS.md
This project uses SpecKit-SSD-SDLC. Agent instructions live in CLAUDE.md — read it first (@CLAUDE.md).
Skills: `.claude/skills/sk.*/SKILL.md` + `prompt.md` — load only the `inject_files` listed in the SKILL.md frontmatter.
Personas: `.claude/agents/{role}.md` · Session: `.specify/state/session.yaml` · Profile: `.specify/profile.yaml` · Specs: `specs/`
Knowledge homes, precedence and loading rules: `.claude/skills/governance/profile.md`.
Project skills are registered in the Registry table of `.claude/skills/README.md` and resolved via `.claude/skills/governance/pack-resolution.md`.
