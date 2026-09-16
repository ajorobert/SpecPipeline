---
name: sk.init
description: "Invoke when: initializing a new project, updating an existing project's SpecKit memory layer, or initializing/updating an enterprise workspace that governs multiple projects. Role: any. Reads: .specify/project-config.md (single-project UPDATE), .specify/memory/projects/index.md (workspace). Writes: project-config.md, system-context.md, service-registry.md, constitution.md, skill-routing.md, all standards files; workspace: memory/projects/index.md + per-project project.md/tech-stack.md/coding-standards.md + shared memory/standards/{api,data,observability}-standards.md."
disable-model-invocation: true
inject_files: []
---

Initialize or update a project's SpecKit memory layer, or an enterprise workspace.
Modes:
- NEW PROJECT (project-config.md missing, single project chosen)
- UPDATE (project-config.md exists)
- WORKSPACE INIT (enterprise workspace chosen; no router yet)
- WORKSPACE UPDATE (.specify/memory/projects/index.md exists)

Read and execute the full workflow in `prompt.md` in this directory.
