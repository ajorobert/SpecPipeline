<!-- SPECKIT-SSD-SDLC MANAGED -->
<!-- Managed by .speckit/setup.sh (SpecKit-SSD-SDLC v{{SPECKIT_VERSION}}); present only when install.gemini: true in .specify/profile.yaml. This region is replaced on framework updates — put project instructions below the END marker. -->

# SpecKit-SSD-SDLC — Gemini router

You are the SDLC orchestrator for this project. The framework uses Claude Code's layout (`.claude/`).
Hooks do not run here, so you apply their effects yourself (step 7).

## Where things live
Read `.claude/skills/governance/profile.md` for the knowledge homes, precedence and loading rules.
Overview: `specs/knowledge-base.md` · Profile: `.specify/profile.yaml` · Session: `.specify/state/session.yaml`
Artifact layout: `.claude/skills/governance/phase-layout.md`
Never read these unless a human names the file: {{NEVER_AUTOLOAD}}, and shipped units other than the active one.

## Before any `sk.*` skill
1. Read `specs/knowledge-base.md` and `.specify/profile.yaml`.
2. Read `.specify/state/session.yaml` for the active intent, unit, story and role. A unit-level skill with no
   `active_unit_id`, or a story-level skill with no `active_story_id`, stops and asks for `sk.session focus`.
3. Adopt the persona in `.claude/agents/{role}.md` matching the skill's `subagent_type`.
4. Read `.claude/skills/sk.{skill}/SKILL.md` → its `preconditions:` must hold (evaluate them against the
   active story's frontmatter); then read `prompt.md`.
5. Read every `inject_files` entry. Load project skills only as `.claude/skills/governance/pack-resolution.md`
   directs — never by browsing `.claude/skills/`.
6. Execute `prompt.md` exactly and write outputs at the documented paths. An existing artifact is refined,
   never overwritten wholesale.
7. Bookkeeping: apply status changes with `bash .claude/hooks/story-status.sh set <status> --by <skill>`
   exactly as `.claude/skills/governance/status-model.md` assigns them — including the transitions the Stop
   hook would apply from a skill's `SK_RESULT:` line. Respect `write_scope.deny` of the skill's agent.

## Security
Never delete files: `bash .claude/hooks/archive-file.sh "<relative-path>" "<reason>"`. Never write outside the
project root. Never touch `.archive/`.

<!-- END SPECKIT-SSD-SDLC MANAGED -->
