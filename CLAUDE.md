<!-- SPECKIT-SSD-SDLC MANAGED -->
<!-- Managed by .speckit/setup.sh (SpecKit-SSD-SDLC v2.0.0), rendered from .specify/profile.yaml. This region is replaced on framework updates — put project instructions below the END marker. -->

# SpecKit-SSD-SDLC

## Overview
@specs/knowledge-base.md

## Where things live
One home per fact — full table and precedence: `.claude/skills/governance/profile.md`.
- Decisions: `specs/adr/` — load through the router `specs/adr/adr-index.md`, never by listing the folder
- Domain: `specs/domain/bounded-contexts.md` → `specs/domain/{module}.md`
- Contracts (canonical): `specs/openapi/{audience}.yaml`, `specs/asyncapi/{module}.yaml`
- Coding rules: `.claude/rules/{stack}/` (loaded by path)
- Projects: `.specify/memory/projects/index.md` · Principles: `.specify/memory/constitution.md` · Profile: `.specify/profile.yaml`
- Project skills: `.claude/skills/README.md` → Registry · Process skills: `.claude/skills/sk.*` · Agents: `.claude/agents/`
- In-flight work: `specs/intents/{intent}/units/{unit}/` (`.claude/skills/governance/phase-layout.md`); only the active unit is loaded
- Precedence on conflict: constitution → ADRs → rules → project skills → unit design → code

## Rules
1. Each sk.* skill declares its own inject_files and subagent_type; execute its prompt.md. Orchestrators run sub-skills with the Skill tool.
2. Story status changes only through `bash .claude/hooks/story-status.sh`. checkpoint_mode lives in the active story's frontmatter.
3. Never read these unless a human names the file in this conversation: (no humans-only paths declared), and shipped units other than the active one.

## Security Rules
4. Never use `rm`, `rmdir`, `del`, `unlink` or `Remove-Item` — these commands are blocked by policy.
5. To remove a file, use the archive script: `bash .claude/hooks/archive-file.sh "<relative-path>" "<reason for removal>"` — it moves the file to `.archive/YYYY-MM-DD/` and logs it in `.archive/ARCHIVE_LOG.md` for human review.
6. Never edit or write files outside the project root directory.
7. The `.archive/` folder is human-review territory — never delete files from it.

<!-- END SPECKIT-SSD-SDLC MANAGED -->

## Framework repository notes
This repository is the framework itself. Framework-owned assets are listed in `setup.sh` (`FRAMEWORK_SKILL_DIRS`, `FRAMEWORK_AGENTS`, `sk.*`, `.claude/hooks/*.sh`).
- The managed region above is a rendered copy of `templates/root/CLAUDE.md` — edit the template, then re-render.
- `skills_archive/` holds capability packs for projects to copy. They are not loaded here and must never be referenced by a `sk.*` skill.
- Keep stack names out of framework files. The verification grep is in `ai_reports/framework-project-skills-separation-plan.md` §6.
