<!-- SPECKIT-SSD-SDLC MANAGED -->
<!-- Managed by .speckit/setup.sh (SpecKit-SSD-SDLC v{{SPECKIT_VERSION}}); present only when install.gemini: true in .specify/profile.yaml. This region is replaced on framework updates — put project instructions below the END marker. -->

# SpecKit — Gemini router
The framework uses Claude Code's layout (`.claude/`). Hooks do not run here, so you apply their effects yourself.
Read `.claude/rules/principles.md` first. Never read these unless a human names the file: {{NEVER_AUTOLOAD}},
and shipped units other than the active one.

## Running an `sk.*` command
1. Read `.claude/skills/sk.{command}/SKILL.md`. Its `preconditions:` must hold against the active story's
   front-matter; its `role:` scopes your writes by `.claude/skills/governance/roles.yaml`.
2. Run `bash .claude/hooks/context.sh {command} [--projects <name>]` and read what it lists.
3. Follow the SKILL.md, reading each `steps/*.md` when you reach it. Before writing code in an area, read the
   `.claude/rules/` files whose `paths:` cover it.
4. Status: `bash .claude/hooks/story-status.sh set <status> --by <command>` for every transition
   `.claude/skills/governance/status-model.md` assigns, including those the Stop hook applies from `SK_RESULT:`.

## Security
Never delete files: `bash .claude/hooks/archive-file.sh "<relative-path>" "<reason>"`. Never write outside the
project root. Never touch `.archive/`.
<!-- END SPECKIT-SSD-SDLC MANAGED -->
