<!-- SPECKIT-SSD-SDLC MANAGED -->
<!-- Managed by .speckit/setup.sh (SpecKit-SSD-SDLC v1.0.0). This region is replaced on framework updates — put project instructions below the END marker. -->

# SpecKit-SSD-SDLC

## Identity
Spec-driven development framework for full-stack multi-service systems.
Project identity, custom rules, overrides: .specify/project-config.md
Skills: .claude/skills/sk.*/SKILL.md (process) · Agents: .claude/agents/ · Session: .claude/session.yaml
Roles: po | architect | lead | backend | frontend | backend-qa | frontend-qa | security

> **[PLACEHOLDER CONVENTION]** Framework skills never hardcode project facts. `{Project}`, `{CodeRoot}`, `{ProjectType}`, `{IdP}` and similar placeholders resolve from project memory: `.specify/memory/projects/index.md`, per-project `tech-stack.md`, and the unit's `unit-brief.md` → Impacted Projects. Capability packs (stack and pattern skills) are project-owned and registered in `.specify/memory/skill-routing.md`; sk.* skills load them only through `.claude/skills/governance/pack-resolution.md`.

## System Prompt Inclusions
<!-- specs/knowledge-base.md is inlined at session start via @import. Editing it mid-session leaves the
     system prompt stale; a PostToolUse hook warns you — restart Claude Code to reload. -->
@specs/knowledge-base.md

## Rules
1. Each sk.* skill declares its own inject_files and subagent_type; execute its prompt.md.
2. Artifact paths follow .claude/skills/governance/phase-layout.md. checkpoint_mode lives in the active story's frontmatter.

## Security Rules
3. Never use `rm`, `rmdir`, `del`, or `unlink` — these commands are blocked by policy.
4. To remove a file, use the archive script: `bash .claude/hooks/archive-file.sh "<relative-path>" "<reason for removal>"` — it moves the file to `.archive/YYYY-MM-DD/` and logs it in `.archive/ARCHIVE_LOG.md` for human review.
5. Never edit or write files outside the project root directory.
6. The `.archive/` folder is human-review territory — never delete files from it.

## Knowledge Bases (non-derivable context)
Tier 1 — system: specs/knowledge-base.md · Tier 2 — domain: specs/domains/{domain}/knowledge-base.md · Tier 3 — unit: specs/intents/{intent}/units/{unit}/knowledge-base.md
Read tier 1 before any work, tier 2 when working within a domain, tier 3 before implementing or testing a unit. They complement code reading — they hold only what code cannot tell you.

<!-- END SPECKIT-SSD-SDLC MANAGED -->

## Framework repository notes
This repository is the framework itself. Framework-owned assets are listed in `setup.sh` (`FRAMEWORK_SKILL_DIRS`, `FRAMEWORK_AGENTS`, `sk.*`, `.claude/hooks/*.sh`).
- The managed region above is a rendered copy of `templates/root/CLAUDE.md` — edit the template, then re-render.
- `skills_archive/` holds capability packs for projects to copy. They are not loaded here and must never be referenced by a `sk.*` skill.
- Keep stack names out of framework files. The verification grep is in `ai_reports/framework-project-skills-separation-plan.md` §6.
