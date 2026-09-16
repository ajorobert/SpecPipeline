---
name: sk.session
description: "Invoke when: starting, ending, switching role, focusing, restoring, or checking status of a development session. Role: any. Reads/writes: session.yaml. Subcommands: start, end, switch, focus, restore, status, list."
disable-model-invocation: true
inject_files:
  - .claude/session.yaml
---

Manages local development session state. No subagent — runs inline.
Subcommands: start [--role], end, switch --role, focus --unit|--story, restore, status, list [--intent] [--status].

Read and execute the full workflow in `prompt.md` in this directory.
