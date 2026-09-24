# sk.session
Manages local development session.
Role: any

Roles (the single enum used by session.yaml, agents and every skill):
`po | architect | lead | backend | frontend | backend-qa | frontend-qa | security`

Session file: `.specify/state/session.yaml` — per-developer runtime state, gitignored. No `git add` in
this skill ever lists `.specify/state/`.

Stories live at `specs/intents/*/units/*/01-story/story.md` (`.claude/skills/governance/phase-layout.md`);
their ID is the frontmatter `id`, their status is `status.current`. Status moves only through
`bash .claude/hooks/story-status.sh` (`.claude/skills/governance/status-model.md`); this skill never
edits a story's status.

Profile: read `.specify/profile.yaml` once per run (every key optional; defaults in
`.claude/skills/governance/profile.md`). Keys used here: `vcs.base_branch` (default `dev`),
`vcs.create_branch` (`on-request`), `vcs.branch` (`{kind}/{topic}`), `vcs.commit` (`conventional`),
`vcs.pr_title` (`[{ticket}] {Kind} / {title}`), `vcs.no_ticket` (`NO TICKET`), `tracker.kind`.

Placeholders: `{kind}` = `fix` when the story's `story_type` is `bug` or `hotfix`, else `feature`;
`{Kind}` = `Fix` | `Feature`; `{topic}` = the story title in kebab case (lowercase, non-alphanumerics →
`-`, trimmed); `{title}` = the story title; `{ticket}` = the story's `jira_id`, else `vcs.no_ticket`;
`{story}` = the story ID.

## Subcommands

### sk.session start [--role <role>] [--branch]

1. **Pre-flight** — Verify session.yaml `role` is null (or the file is absent).
   NOT null → report the active session, suggest `sk.session end` first.

2. **Role**
   - If `--role <role>` is provided (e.g. `/sk.session start --role backend`), use it.
   - Otherwise ask the user to select one: **Product Owner | Architect | Lead | Backend Developer | Frontend Developer | Backend QA | Frontend QA | Security**.
   - Map the selection to the role key: `po | architect | lead | backend | frontend | backend-qa | frontend-qa | security`.

3. **Story focus**
   - The current `active_story_id` (if any) stays the session focus. Do NOT ask for story input.
   - If the user names a different story, locate it by frontmatter `id` and set `active_story_id`,
     `active_unit_id`, `active_intent_id` from its path.

4. **Branch** — record by default; create only when asked.
   - `git branch --show-current` → `{current_branch}`.
   - **Record (default).** Unless the user asked for a new branch (`--branch`, or said so) or
     `vcs.create_branch: always`, use `{current_branch}` as the session branch. Do not check out,
     create or rename anything.
   - **Create (on request, or `vcs.create_branch: always`).**
     - Resolve `{kind}`, `{topic}`, `{ticket}`, `{story}` from the focused story (placeholders above).
       No focused story → ask the user for the topic and kind (`feature` | `fix`).
     - Branch name = `vcs.branch` with the placeholders filled in (default `{kind}/{topic}`).
     - Run the uncommitted-changes guard (see `end`, step 3) before switching.
     - `git checkout {vcs.base_branch}` → `git pull --ff-only` (skip the pull if there is no remote) →
       `git checkout -b {branch_name}`.
     - If the branch already exists: ask whether to switch to it (`git checkout {branch_name}`) instead.

5. **session_id**: `{role}-{YYYYMMDD}` (or `session-{YYYYMMDD}` if no role).

6. **Write `.specify/state/session.yaml`** (create `.specify/state/` if absent): role, session_id,
   branch, base_branch (`vcs.base_branch`), story_id, jira_id, active_intent_id, active_unit_id,
   active_story_id, stories_touched, units_touched.
   If a story is focused, record the branch on it too, so `restore` can find it later:
   `bash .claude/hooks/story-status.sh field branch {branch}`.

7. **Report**: session started, branch (recorded or created), base branch, role, active focus story.
   - If role set: list natural commands for that role (from the matching `.claude/agents/*.md` → Commands You Run).
   - If no role: note that most skills self-assert their persona; skills that branch on backend/frontend
     (sk.review, sk.investigate) use the resolved project type, falling back to role.

### sk.session restore
Use when `.specify/state/session.yaml` is missing but work is already under way on a branch. Any branch
name is valid; the branch is never renamed.
1. `git branch --show-current` → `{branch}`.
2. Find the story, first match wins:
   a. **Story ID in the branch** — search `{branch}` for a `{INTENT}-{UNIT}-{NNN}` token that equals a
      story frontmatter `id` under `specs/intents/*/units/*/01-story/story.md`.
   b. **Branch recorded in a story** — a story whose frontmatter `branch:` equals `{branch}`.
   c. Neither, or more than one candidate → list the candidates (if any) and ask the user for the story ID.
3. From the story's path derive `active_unit_id` and `active_intent_id`.
4. Ask the user for the role; derive session_id: `{role}-{YYYYMMDD}`.
5. Write `.specify/state/session.yaml` with the recovered values (branch = `{branch}`,
   base_branch = `vcs.base_branch`, jira_id from the story, stories_touched: [story-id], units_touched: [unit-id]).
6. Report: session restored on branch `{branch}`, focus `{story-id}`, and how the story was found (a / b / c).

### sk.session switch --role <role>
1. Read `.specify/state/session.yaml` — verify a session is active.
2. Validate the role against the enum above; update the `role` field.
3. Report: role switched, available commands for the new role.

### sk.session end

> **Safety principle:** NEVER automatically stash or discard user changes without confirmation.
> Always ask the user before taking any action that could affect unfinished or uncommitted work.

1. Show session.yaml stories_touched and units_touched.
2. Ask the user to confirm the session is complete.
3. **Uncommitted-changes guard** — `git status --porcelain`.
   - **No pending changes** → skip to step 6.
   - **Pending changes** → PAUSE and ask the user how to proceed:
     - **Commit changes** — stage and commit the current work (steps 4–5).
     - **Stash changes and continue** — `git stash`, then continue at step 6.
     - **Cancel session end** — stop without committing, stashing or switching branch.
   - NEVER stash or discard without explicit confirmation.
4. **Stage** — show the changed paths and stage them by name, never with `git add -A` / `git add .`:
   `specs/`, `history/`, `.specify/memory/`, `.specify/profile.yaml`, `.claude/rules/`, and the
   `{CodeRoot}` of each impacted project (from `unit-brief.md`) that has changes. Never stage
   `.specify/state/`. Paths outside this list are staged only if the user confirms them.
5. **Commit** — message per `vcs.commit`:
   - `conventional` (default): `type(scope): subject`. `type` from the work (`feat` for a feature story,
     `fix` for a bug/hotfix story, `docs` for spec/knowledge-only changes, `test`, `refactor`, `chore`);
     `scope` = the active unit ID (or the topic when there is no unit); `subject` = imperative, lower
     case, no trailing period, e.g. `feat(checkout-u1): add saved card selection`. Put the stories
     touched in the body.
   - `free`: a one-line summary of the units and stories touched.
   Show the message and commit after the user confirms.
6. **Push** — `git push -u origin {branch}`.
7. **PR** — if `gh` is available and no PR exists for `{branch}` (`gh pr view` fails), ask whether to open one:
   `gh pr create --base {vcs.base_branch} --head {branch} --title "{vcs.pr_title filled in}" --body "{stories touched, acceptance-criteria summary}"`.
   Title placeholders from the focused story (`{ticket}` = `jira_id`, else `vcs.no_ticket`). A story that
   is ready to ship goes through `sk.ship` instead, which also runs promotion.
8. Reset every field in `.specify/state/session.yaml` to null.
9. Report: session ended, commit, branch pushed, PR URL (if opened).

### sk.session focus --unit <id> | --story <id>
1. If --unit: set active_unit_id, derive active_intent_id from the unit folder
   (`specs/intents/{intent}/units/{unit}/`); set active_story_id from that unit's `01-story/story.md` id (null if none).
2. If --story: locate the story by frontmatter `id`.
   Set active_story_id, active_unit_id, active_intent_id.
3. Add the ids to stories_touched / units_touched, write `.specify/state/session.yaml`, report current focus.

### sk.session status
1. Read `.specify/state/session.yaml`.
2. Run `bash .claude/hooks/story-status.sh show` — active story, `status.current`, pending and failed
   tracker mirror entries.
3. If active_story_id: read the story frontmatter.
4. Report:
   - Role (if set), branch (and whether it matches `git branch --show-current`), session_id
   - Active: intent, unit, story
   - Story `status.current`, `checkpoint_mode`, test-status / security-status / verify-status / uat-status, `jira_id`
   - Tracker mirror (when `tracker.kind` is not `none`): pending and failed entries from `show`.
     Pending → handle them per `.claude/skills/governance/tracker-mirror.md`. Failed → list each with its
     reason and offer `bash .claude/hooks/story-status.sh mirror-retry` to re-queue them.
   - If role set: natural commands for that role

### sk.session list [--intent <id>] [--status <status>]
1. Scan `specs/intents/*/units/*/01-story/story.md`.
2. Read frontmatter from each.
3. Display table:
   | ID | Title | Status (status.current) | Owner | Checkpoint | Branch |
4. Apply filters if provided (`--intent` matches frontmatter `intent`; `--status` matches `status.current`).
