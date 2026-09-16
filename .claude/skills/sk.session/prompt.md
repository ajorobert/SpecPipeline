# sk.session
Manages local development session.
Role: any

Roles (the single enum used by session.yaml, agents and every skill):
`po | architect | lead | backend | frontend | backend-qa | frontend-qa | security`

Stories live at `specs/intents/*/units/*/01-story/story.md` (`.claude/skills/governance/phase-layout.md`);
their ID is the frontmatter `id`, their status is `status.current`.

## Subcommands

### sk.session start [--role <role>]

1. **Pre-flight** — Verify session.yaml role is null.
   NOT null → report active session, suggest `sk.session end` first.

2. **Role**
   - If `--role <role>` is provided in the command (e.g. `/sk.session start --role backend`), use the specified role.
   - If no role is provided, ask the user to select one: **Product Owner | Architect | Lead | Backend Developer | Frontend Developer | Backend QA | Frontend QA | Security**.
   - Map the selection to the role key: `po | architect | lead | backend | frontend | backend-qa | frontend-qa | security`.

3. **Base branch**
   - Automatically detect the current git branch: `git branch --show-current` → `{current_branch_name}`.
   - Present these options:
     1. If the current branch is `dev`, use `dev` as the base branch **(default)**.
     2. Use the current branch `{current_branch_name}` as the base branch.
     3. Other — let the user specify a custom branch name.
   - If the user skips the selection, default to `dev`.

4. **Feature name** (auto-generated — do NOT ask the user unless it cannot be determined)
   - Determine the feature name by this priority:
     1. Use the **Jira issue title** if a Jira ticket is linked.
     2. Otherwise, use the **active story title**.
   - Ask the user only if the feature name cannot be determined automatically by either source.
   - Convert to a branch-friendly format: lowercase, replace whitespace with hyphens (e.g. "Login page" → "login-page").

5. **Story Id**
   - If a story is already focused (`active_story_id`), use it.
   - Otherwise scan every `specs/intents/*/units/*/01-story/story.md` frontmatter `id`, take the highest
     `{INTENT}-{UNIT}-{NNN}` number for the target unit, and increment it to form the next story ID.

6. **Checkout base + create feature branch**
   - `git checkout {base_branch}`
   - Generate the branch name: `feature/{story-id}-{jira-id}-{feature-name}-{YYYYMMDD}` (omit `{jira-id}` when none)
     - Sanitize each segment: lowercase, replace whitespace with hyphens. Use today's date for `{YYYYMMDD}`.
   - `git checkout -b {generated_branch_name}`

7. **session_id**: `{role}-{YYYYMMDD}` (or `session-{YYYYMMDD}` if no role).

8. **Active story handling**
   - The current active story is the session focus by default. Do NOT request additional story input from the user — continue with the existing focused story throughout the session.
   - If a story change is required: allow the user to explicitly switch or provide a different story, and update the session focus (`active_story_id`, and the derived `active_unit_id` / `active_intent_id`) to the newly selected story.

9. **Write session.yaml**: role, session_id, branch (`{generated_branch_name}`), story_id, jira_id, active_intent_id, active_unit_id, active_story_id, stories_touched, units_touched.

10. **Report**: session started, feature branch, base branch, role, and active focus story.
    - If role set: list natural commands for that role (from `.claude/agents/{role}.md` → Commands You Run).
    - If no role: note that most skills self-assert their persona; skills that branch on backend/frontend
      (sk.review, sk.investigate, sk.refactor, sk.perf) use the resolved project type, falling back to role.

### sk.session restore
Use when session.yaml is missing but the working branch already exists.
1. Read current git branch name
2. Parse the branch — format: `feature/{story-id}-{jira-id?}-{feature-name}-{YYYYMMDD}`
   - `{story-id}` = the leading `{INTENT}-{UNIT}-{NNN}` segment; `{YYYYMMDD}` = the trailing date
   - Cannot parse → ask user to provide the story ID, role and session_id manually
3. Locate the story by frontmatter `id` → derive active_unit_id and active_intent_id
4. Ask the user for the role; derive session_id: {role}-{YYYYMMDD}
5. Write session.yaml with recovered values (stories_touched: [story-id], units_touched: [unit-id])
6. Report: session restored on branch {branch}, focus {story-id}

### sk.session switch --role <role>
1. Read current session.yaml — verify session active
2. Validate the role against the enum above; update role field
3. Report: role switched, available commands for new role

### sk.session end

> **Safety principle:** NEVER automatically stash or discard user changes without confirmation.
> Always ask the user before taking any action that could affect unfinished or uncommitted work.

1. Show session.yaml stories_touched and units_touched.
2. Ask user to confirm complete.
3. **Uncommitted-changes guard** — before committing or any branch switch, check the working tree:
   `git status --porcelain`.
   - **No pending changes** → continue with the end process.
   - **Pending changes detected** → PAUSE the workflow and ask the user how they want to proceed:
     - **Commit changes** — stage and commit the current work as part of ending the session (steps 4–5).
     - **Stash changes and continue** — `git stash` the current changes, then proceed.
     - **Cancel session end** — stop the workflow without committing, stashing, or changing the current branch.
   - NEVER stash or discard without explicit confirmation.
4. git add specs/ .specify/memory/ history/
5. Commit: "[{role or 'mixed'}] {session_id}: worked on {units_touched}, {stories_touched}"
6. git push
7. If gh CLI available: open PR to dev branch
8. Reset session.yaml all fields to null
9. Report: session ended, branch pushed

### sk.session focus --unit <id> | --story <id>
1. If --unit: set active_unit_id, derive active_intent_id from the unit folder
   (`specs/intents/{intent}/units/{unit}/`); set active_story_id from that unit's `01-story/story.md` id (null if none)
2. If --story: locate the story by frontmatter `id`
   Set active_story_id, active_unit_id, active_intent_id
3. Add the ids to stories_touched / units_touched, write session.yaml, report current focus

### sk.session status
1. Read session.yaml
2. If active_story_id: read the story frontmatter
3. Report:
   - Role (if set), branch, session_id
   - Active: intent, unit, story
   - Story `status.current`, `checkpoint_mode`, test-status / security-status / verify-status
   - If role set: natural commands for that role

### sk.session list [--intent <id>] [--status <status>]
1. Scan `specs/intents/*/units/*/01-story/story.md`
2. Read frontmatter from each
3. Display table:
   | ID | Title | Status (status.current) | Owner | Checkpoint | Branch |
4. Apply filters if provided (`--intent` matches frontmatter `intent`; `--status` matches `status.current`)
