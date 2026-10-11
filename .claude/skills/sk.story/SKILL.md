---
name: sk.story
description: "Capture or refine a unit's story with the product owner: intent, unit, story, acceptance criteria, clarifications and the unit's Impacted Projects. Flags: --bug, --jira <key>, --clarify, --probe."
role: po
rubric:
  name: story-completeness
  checks:
    - every acceptance criterion is independently testable
    - every acceptance criterion uses Given/When/Then or an equivalent observable form
    - the user story follows "As a {role} I want {action} so that {benefit}"
    - the out-of-scope list is present and non-empty
    - at least 3 acceptance criteria (2 for a bug)
    - no undefined external dependencies
---

# sk.story
Captures one unit's story with the product owner, in one interactive session.
Output: `01-story/` (story.md, requirement.md, acceptance-criteria.md, jira.md when tracker-seeded) and
the unit-brief's Impacted Projects table. One story per unit; it is never split per project.

## Invocation
- `sk.story` — feature; `sk.story --bug` — bug report. Either may add `--jira <key>` to seed from a tracker issue.
- `sk.story --clarify` — run step 2 only. `sk.story --probe` — run step 3 only.

## Pre-flight
Run `.claude/skills/governance/preflight.md` with command `story` (no active unit yet is normal here).
Read `.specify/profile.yaml` → `tracker.kind`, `tracker.project`.

## Tracker seed (`--jira <key>` only)
Load the tracker connector's issue-read tool with ToolSearch and fetch the issue. On failure STOP and say
why; never fall back silently. Map summary → title and action; description and acceptance fields →
requirement and seed criteria; issue type Bug → bug framing; labels/components → tag and project hints;
epic/parent → candidate intent. Every later question the issue already answers is pre-filled, not asked.

## Steps
Run in order. Each step's file says how; read it when you reach it.
1. **Specify** — `steps/specify.md`: intent, unit, the interview, the three story files, tags, checkpoint_mode.
2. **Clarify** — `steps/clarify.md`: one business assessment, then up to 5 questions, one at a time.
3. **Probe** — `steps/probe.md`: one technical assessment, the Impacted Projects table (always), then up
   to 5 technical questions in business language (none when the assessment is clear).
4. **Tracker** — when `tracker.kind` is not `none` or `--jira` was given, and the story has no `jira_id`:
   ask "Create a {tracker.kind} issue in {tracker.project}, link an existing key, or skip?". Create or link
   through the connector; write `01-story/jira.md` (key, link, the description as sent — nothing else);
   store the key with `bash .claude/hooks/story-status.sh field jira_id <KEY>`. A connector failure is
   reported and the story continues without a key.
5. **Ready gate** — show the story-completeness rubric (frontmatter above), each check ✅/❌.
   - All ✅: `bash .claude/hooks/story-status.sh set ready --by sk.story`.
   - Any ❌: list them; ask "proceed (recorded as risks in requirement.md) or clarify?". `proceed` sets
     ready; `clarify` runs step 2 once more. The Impacted Projects table must have at least one row either way.

## Completion report
```
sk.story complete — {story-id}: {title}
Status: ready | checkpoint_mode: {mode} | tracker: {key | not seeded — reason}
Impacted projects: {Project (Type), …}
Open risks: {list | none}
Next: /sk.design — in a fresh session (or /sk.ff when the scope is small)
```
