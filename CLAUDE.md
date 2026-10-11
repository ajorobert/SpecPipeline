<!-- SPECKIT-SSD-SDLC MANAGED -->
<!-- Managed by .speckit/setup.sh (SpecKit-SSD-SDLC v3.0.0), rendered from .specify/profile.yaml. This region is replaced on framework updates — put project instructions below the END marker. -->
# SpecKit
- Work runs through `/sk.*` commands, one per session: story → design → plan → implement → test → review → uat → security-audit → verify → ship. `/sk.session status` shows where the active unit stands; each command's report names the next.
- A command's steps and gates run in its own session; subagents only read and report.
- Story status changes only through `bash .claude/hooks/story-status.sh`.
- Never read these unless a human names the file: (no humans-only paths declared), and shipped units other than the active one.
- Never use `rm`, `rmdir`, `del`, `unlink` or `Remove-Item`. To remove a file: `bash .claude/hooks/archive-file.sh "<path>" "<reason>"`; `.archive/` is for human review only.
- Never write outside the project root.
<!-- END SPECKIT-SSD-SDLC MANAGED -->

## Framework repository notes
This repository is the framework itself. Framework-owned assets are listed in `setup.sh` (`FRAMEWORK_SKILL_DIRS`, `FRAMEWORK_AGENTS`, `sk.*`, `.claude/hooks/*.sh`).
- The managed region above is a rendered copy of `templates/root/CLAUDE.md` — edit the template, then re-render.
- `skills_archive/` holds capability packs for projects to copy. They are not loaded here and must never be referenced by a `sk.*` skill.
- Framework files name no adopting project and no stack; they match a project by the shape of its knowledge layer. Write them in current-state language (what is, never "replaces" or "no longer").
- Keep stack names out of framework files. The verification grep is in `ai_reports/framework-project-skills-separation-plan.md` §6.
