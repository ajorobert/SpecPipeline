---
name: sk.session
description: "Invoke when: starting, ending, switching role, focusing, restoring, or checking status of a development session. Role: any. Reads: .specify/state/session.yaml, .specify/profile.yaml (vcs.*, tracker.*), story frontmatter, story-status.sh show. Writes: .specify/state/session.yaml; branch, commit, push and PR per vcs.*. Subcommands: start, end, switch, focus, restore, status, list."
disable-model-invocation: true
inject_files:
  - .specify/state/session.yaml
---

Manages local development session state. No subagent — runs inline.
Subcommands: start [--role] [--branch], end, switch --role, focus --unit|--story, restore, status, list [--intent] [--status].

Read and execute the full workflow in `prompt.md` in this directory.
