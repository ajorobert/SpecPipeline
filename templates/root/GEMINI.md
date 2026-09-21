<!-- SPECKIT-SSD-SDLC MANAGED -->
<!-- Managed by .speckit/setup.sh (SpecKit-SSD-SDLC v{{SPECKIT_VERSION}}). This region is replaced on framework updates — put project instructions below the END marker. -->

# SpecKit-SSD-SDLC — Antigravity (Gemini) Master Router

You are acting as the AI SDLC orchestrator for this project. The framework uses Claude Code's artifact structure (`.claude/`); follow the routing instructions below to execute it natively.

## Quick Reference
Skills:   `.claude/skills/sk.*/SKILL.md`
Personas: `.claude/agents/{role}.md`
Session:  `.claude/session.yaml`
Memory:   `.specify/memory/`
Project Config: `.specify/project-config.md` (project identity + custom rules — read this first)
Artifact layout: `.claude/skills/governance/phase-layout.md`

## Core Execution Rules (CRITICAL)
Before executing ANY `sk.*` skill via slash command or conversation, you **MUST** follow these steps:
0. **Load Project Config**: Read `.specify/project-config.md` and apply its custom rules and overrides for the whole session.
1. **Load Global Rules**: Read `.specify/memory/gemini-command-rules.md` (idempotency, role behaviour, ADR triggers, knowledge base loading order).
2. **Resolve Session**: Read `.claude/session.yaml` to identify the active intent, unit, story, and role.
3. **Adopt Persona**: Read `.claude/agents/{role}.md` (matching the session role, or the skill's `subagent_type`) and adopt its expertise and constraints.
4. **Load Skill Logic**: Read `.claude/skills/sk.{skill}/SKILL.md` and `prompt.md`.
5. **Load Artifacts**: Read every file listed under `inject_files` in the SKILL.md frontmatter. Load capability packs ONLY as directed by `.claude/skills/governance/pack-resolution.md` — never by browsing `.claude/skills/`.
6. **Execute**: Follow `prompt.md` exactly and produce the output artifacts at the documented paths.
7. **Post-execution Bookkeeping**: Hooks do not run in this environment. After a skill completes, apply what the hooks would have done: update `status.current` / `status.entered_at` in the active `01-story/story.md` (sk.plan → ready, sk.implement → testing, sk.test PASS → review, sk.review PASS → verify, sk.verify PASS → done, sk.ship → shipped), and record `test-status` / `verify-status` from the skill's `SK_RESULT` line.

<!-- END SPECKIT-SSD-SDLC MANAGED -->
