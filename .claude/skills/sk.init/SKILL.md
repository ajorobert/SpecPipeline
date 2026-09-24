---
name: sk.init
description: "Invoke when: adopting SpecKit in a repository (INIT, no .specify/profile.yaml yet) or re-detecting and updating an adopted one (UPDATE). Detects existing homes and conventions and proposes values; the interview — or an answers file (--answers <file>) — confirms them. Role: any. Reads: .specify/profile.yaml, .claude/.speckit-manifest, specs/adr/ (adr-index.md, ADR status lines), specs/domain/bounded-contexts.md, specs/openapi/*.yaml, specs/asyncapi/*.yaml, .claude/skills/README.md, .claude/rules/, CONTRIBUTING.md, git history and PR titles, project manifests. Writes: .specify/profile.yaml, .specify/memory/projects/index.md, .specify/memory/projects/{Project}/tech-stack.md, .specify/memory/constitution.md (team-stated principles only); only when absent and confirmed: specs/knowledge-base.md, specs/adr/adr-index.md, specs/domain/bounded-contexts.md, the ## Registry table in .claude/skills/README.md."
inject_files:
  - .claude/skills/governance/profile.md
---

Adopt SpecKit in this repository, or update an adopted one.
Modes (keyed on `.specify/profile.yaml`):
- INIT (profile absent): detect → propose → confirm → write
- UPDATE (profile present): re-detect → show a diff → apply only the confirmed sections
  (profile, projects, constitution, registry)

`/sk.init --answers <file>` runs either mode without questions.

Read and execute the full workflow in `prompt.md` in this directory.
