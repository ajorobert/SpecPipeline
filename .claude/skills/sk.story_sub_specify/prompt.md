# sk.story_sub_specify
Captures intent, decomposes to units and stories.
Role: po | Level: intent → unit → story

## Mode Detection
- `sk.story_sub_specify --bug` → [BUG MODE] bug report interview framing
- `sk.story_sub_specify` (no flag) → [FEATURE MODE] user story interview framing
Declare mode at start of execution.

**Jira-seeded capture:** When the orchestrator passes tracker seed data (from `sk.story --jira {Jira_Id}`), use it to PRE-FILL the interview matrix (Actor, Action, Value, Trigger, Input, Output, Happy Path, Error Cases) and the acceptance criteria. Only ask the PO about dimensions the issue left genuinely empty or ambiguous — do not re-ask what the issue already answers. Do not write `jira_id` or `jira.md`: sk.story links the issue afterwards through `story-status.sh` (its Phase 5b).

Resolve `TEMPLATES_DIR` per `.claude/skills/governance/framework-paths.md` before reading any template.

## Input Artifacts
specs/knowledge-base.md (system overview — already in context through CLAUDE.md)
.specify/memory/projects/index.md (project router)
specs/adr/adr-index.md (router → the ADRs it routes, per `.claude/skills/governance/profile.md` Loading rules)
specs/domain/bounded-contexts.md (+ `specs/domain/{module}.md` for the contexts the story touches)
.claude/skills/README.md → `## Registry` (Signals column — the tag vocabulary; optional)
.specify/state/session.yaml (active_intent_id, active_unit_id)
{TEMPLATES_DIR}/artifacts/intent-template.md, unit-brief-template.md, story-template.md

A missing knowledge home is logged `{home} not present — skipped`; this skill never creates one.
Never read a path matched by `knowledge.never_autoload` in `.specify/profile.yaml`, or a shipped unit.

## Steps

### Step 1 — Resolve Intent
Read active_intent_id from `.specify/state/session.yaml`.
NULL → ask user for intent title and code (e.g. CHK)
Create specs/intents/{NNN}-{name}/intent.md if new, from `{TEMPLATES_DIR}/artifacts/intent-template.md`.

### Step 2 — Resolve Unit
Read active_unit_id from `.specify/state/session.yaml`.
NULL → ask user for unit title and code (e.g. PAY)
Create specs/intents/{intent}/units/{unit}/unit-brief.md if new, from
`{TEMPLATES_DIR}/artifacts/unit-brief-template.md`. Leave the Impacted Projects table empty here —
`sk.story_sub_architect-probe` owns it and always fills it before sk.story reports complete.
If the unit already has `01-story/story.md`: this is [REFINE MODE] for that story — update it in place.
A genuinely separate story belongs in a new unit; ask the PO to name one.

### Step 3 — [FEATURE MODE only] Pre-validation (optional)
If creating a new intent (active_intent_id was NULL before step 1):
  Ask: "Would you like to validate this idea against existing intents and constraints first? (y/n)"
  If yes:
    - Use the system overview in `specs/knowledge-base.md` and list existing intents from `specs/intents/*/intent.md`
      (intent files only — never open a shipped unit's folder)
    - Read `specs/adr/adr-index.md`: load the ALWAYS block's ADRs and the ADRs of every signal block the
      idea's words match. Read `specs/domain/bounded-contexts.md` for the contexts it lands in.
    - Evaluate: does this idea duplicate an existing intent? does it conflict with any routed ADR or with a context's ownership?
    - Report findings. If major concerns: suggest resolving before proceeding.
    - If no concerns: confirm "No conflicts found. Proceeding to story capture."

### Step 3b — Context-Aware Probing (optional)
Before asking questions, load:
- Existing stories in the same intent (`specs/intents/{intent}/units/*/01-story/story.md`) to avoid duplication —
  frontmatter and title only for shipped units.
- `specs/domain/bounded-contexts.md`, then the `specs/domain/{module}.md` of each context the story touches,
  to probe for invariants, ownership and the domain language.
- `specs/knowledge-base.md` (actors, cross-domain constraints) to check if the story touches integration points.
Use this to generate 1-2 proactive questions (e.g. "This story involves the Order context. Does it need to handle state transitions?").

### Step 3c — Load Project Router
Before capturing the story, load `.specify/memory/projects/index.md` as the project router.
Use it to ground the requirement in the actual workspace:
- **Available projects:** enumerate the projects and their types (Backend / Frontend / Mobile) so story capture is aware of which surfaces exist.
- **Existing features:** scan the listed project folders for overlapping capabilities to avoid duplicating an existing feature.
- **Domain context:** cross-reference `specs/domain/bounded-contexts.md` for the contexts the story touches (entities themselves live in the code).
- **Business rules:** carry any project-level constraints into the interview.
The story is NOT split per project. Project impact is resolved later in `sk.story_sub_architect-probe`, which records the **impacted projects** into `unit-brief.md`. This step only ensures the captured requirement is project-router-aware.

### Step 4 — Capture Story

#### [FEATURE MODE]
Use the following structured interview matrix. Ask questions progressively, using follow-ups when triggered:

| Dimension | Required Question | Follow-up Trigger |
|-----------|-------------------|-------------------|
| **Actor** | Who is the primary user? What role/persona? | If "admin" or "system" → ask: is this user-facing or internal? |
| **Action** | What specific action do they perform? | If vague verb ("manage", "handle") → ask for concrete sub-actions |
| **Value** | What business outcome does this enable? | If only technical reason → push for user-facing benefit |
| **Trigger** | What initiates this action? (user click, schedule, event) | If event-driven → ask: what produces the event? |
| **Input** | What data does the user provide or the system receive? | If "form data" → ask for specific fields |
| **Output** | What is the observable result? | If no UI change → ask: how does the user know it worked? |
| **Happy Path**| Walk through the ideal scenario step by step | If > 5 steps → suggest splitting into multiple units |
| **Error Cases**| What can go wrong? How should errors surface? | If "show error message" → ask for specific error states |

**Acceptance Criteria Quality Gate (Inline Check)**
After the PO provides acceptance criteria, verify:
- [ ] Each criterion is **testable** (has a Given/When/Then or clear condition)
- [ ] Each criterion is **independent** (doesn't duplicate another)
- [ ] No **vague adjectives** ("fast", "intuitive", "robust") without quantification
- [ ] At least one **negative/error scenario** is covered
- [ ] At least one criterion addresses **the core value proposition**
If any check fails → ask a targeted follow-up before writing the story.

Ask explicitly: what is explicitly out of scope.

#### [BUG MODE]
- Ask: what is the expected behavior? (reference the relevant spec, story ID, or acceptance criterion if known)
- Ask: what is the actual/broken behavior? (be specific — what happens instead)
- Ask: steps to reproduce (numbered list)
- Ask: affected unit and story ID if known (set as `related_story` in frontmatter)
- Ask: acceptance criteria for the fix — when is this considered resolved? (minimum 2)
- Note: out of scope defaults to "no new features introduced by this fix"

### Step 5 — Write Story
Write the story into the unit's fixed phase folder (the story is NOT split per project):
  specs/intents/{intent}/units/{unit}/01-story/
Story ID format stays `{INTENT}-{UNIT}-{NNN}` and is recorded in `story.md` frontmatter.

Write these files into that folder:
  - `story.md` — from `{TEMPLATES_DIR}/artifacts/story-template.md`: frontmatter (`id`, `intent`, `unit`, `story_type`, `tags`, `checkpoint_mode`; `status.current` stays as `skill-start.sh` set it — `draft` — and `jira_id` stays `null`) + the As-a/I-want/So-that user story + in/out-of-scope.
  - `requirement.md` — the functional + non-functional business requirements derived from the interview.
  - `acceptance-criteria.md` — the testable acceptance criteria (GWT or condition-based).

In [BUG MODE]: set `story_type: bug` in `story.md` frontmatter and populate (in `story.md`):
  - `expected_behavior`
  - `actual_behavior`
  - `reproduction_steps`
  - `related_story` (if provided)

`jira.md` is not written here; sk.story writes it when it seeds the tracker.

Update `.specify/state/session.yaml`: `active_unit_id`, `active_story_id`, `active_intent_id`.

### Step 5b — Tag Story with Domain Keywords
Tags let `.claude/skills/governance/pack-resolution.md` load the right capability packs later.
1. Read `.claude/skills/README.md` → `## Registry`. The tag vocabulary is the union of the Signals column
   (comma-separated, lower case; `—` contributes nothing).
2. Scan the story title, requirement and acceptance criteria for those keywords (whole word or phrase,
   case-insensitive). A negated mention ("no cache", "without auth") does not count.
3. Set `tags` in `story.md` frontmatter to the matched keywords, e.g. `tags: [cache, auth]`.
   Empty array if none match or the registry is missing: `tags: []`.
Never invent tags outside the registry vocabulary; note unmatched but important concepts in requirement.md instead.

### Step 6 — Classify Checkpoint
Read `.claude/skills/governance/checkpoint-rules.md` → set `checkpoint_mode` in `story.md` frontmatter
(`autopilot | confirm | validate`). This frontmatter field is the single source of truth for every later gate.
Bug stories default to `autopilot` unless the fix touches a service boundary or data model (→ `confirm`).

## Output Artifacts
specs/intents/{intent}/intent.md (if new)
specs/intents/{intent}/units/{unit}/unit-brief.md (if new)
specs/intents/{intent}/units/{unit}/01-story/story.md
specs/intents/{intent}/units/{unit}/01-story/requirement.md
specs/intents/{intent}/units/{unit}/01-story/acceptance-criteria.md

## Quality Bar

### Feature mode
- Story has clear user story format
- Minimum 3 acceptance criteria
- checkpoint_mode set in `story.md` frontmatter
- Out of scope items listed

### Bug mode
- Expected vs actual behavior clearly distinguished
- Reproduction steps are numbered and specific
- Minimum 2 acceptance criteria (definition of fixed)
- story_type: bug in frontmatter
- checkpoint_mode set (default: autopilot)
