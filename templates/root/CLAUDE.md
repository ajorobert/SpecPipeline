<!-- SPECKIT-SSD-SDLC MANAGED -->
<!-- Managed by .speckit/setup.sh (SpecKit-SSD-SDLC v{{SPECKIT_VERSION}}), rendered from .specify/profile.yaml. This region is replaced on framework updates — put project instructions below the END marker. -->
# SpecKit
- Work runs through `/sk.*` commands, one per session: story → design → plan → implement → test → review → uat → security-audit → verify → ship. `/sk.session status` shows where the active unit stands; each command's report names the next.
- A command's steps and gates run in its own session; subagents only read and report.
- Story status changes only through `bash .claude/hooks/story-status.sh`.
- Never read these unless a human names the file: {{NEVER_AUTOLOAD}}, and shipped units other than the active one.
- Never use `rm`, `rmdir`, `del`, `unlink` or `Remove-Item`. To remove a file: `bash .claude/hooks/archive-file.sh "<path>" "<reason>"`; `.archive/` is for human review only.
- Never write outside the project root.
<!-- END SPECKIT-SSD-SDLC MANAGED -->
