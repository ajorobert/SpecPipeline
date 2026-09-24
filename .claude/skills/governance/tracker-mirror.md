# Tracker Mirror
Framework-owned block. Applies when `.specify/profile.yaml` sets `tracker.kind` (for example `jira`)
with `tracker.mode: mirror` (the default mode).

## Ownership
The framework is the record. The story ID and `status.current` in `01-story/story.md` are the truth;
the tracker issue follows them, one way. The issue key is stored in the story frontmatter as
`jira_id`. Work managed by the framework is moved through the framework (sk.* skills and
`story-status.sh`), never by editing the tracker issue.

## How a transition reaches the tracker
1. Every status change runs through the one transition (`sk_transition` in
   `.claude/hooks/lib-story.sh`), whether a hook applies it or a skill calls
   `bash .claude/hooks/story-status.sh set <status> --by <skill>`.
2. The transition queues one entry in `.specify/state/tracker-outbox/` (issue, from, to). A story
   without `jira_id` is reported and not queued.
3. Hooks cannot reach the tracker. The model does, through its tracker connector (for Jira, the
   Atlassian MCP). At the end of the turn the Stop hook blocks once while any entry is pending and
   lists the entries.
4. For each pending entry, in queue order:
   - Read the issue's available transitions (Atlassian MCP: `getTransitionsForJiraIssue`).
   - Pick the transition named in `tracker.transitions.{to}` when set; otherwise the one whose target
     status best matches the framework status (`in-progress` → "In Progress", `review` → "In Review",
     `done`/`shipped` → "Done"). If the issue is already in that status, nothing to do.
   - Apply it (`transitionJiraIssue`), then run
     `bash .claude/hooks/story-status.sh mirror-ack <id>`.
   - If no transition fits, the connector is unavailable, or the call fails, run
     `bash .claude/hooks/story-status.sh mirror-fail <id> "<reason>"` and tell the user.
5. A failed entry is never dropped. `sk.session status` and `story-status.sh show` report it;
   `story-status.sh mirror-retry` re-queues every failed entry.

## Seeding
`sk.story` may create the issue (or link an existing one) and writes its key to `jira_id` through
`bash .claude/hooks/story-status.sh field jira_id <KEY>`. From then on every transition mirrors.
