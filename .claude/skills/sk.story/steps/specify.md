# Step 1 — Specify
Framing: feature by default, bug with `--bug`. Say which at the start.

## Intent and unit
- `active_intent_id` unset in `.specify/state/session.yaml`: ask for the intent title and code, and create
  `specs/intents/{NNN}-{name}/intent.md` from `{templates_dir}/artifacts/intent-template.md`. For a new
  intent, check `specs/intents/*/intent.md` (intent files only) and the routed ADRs for a duplicate or a
  conflict, and report any before continuing.
- `active_unit_id` unset: ask for the unit title and code, and create `units/{unit}/unit-brief.md` from
  `{templates_dir}/artifacts/unit-brief-template.md`, with the Impacted Projects table empty (step 3 fills it).
- The unit already has `01-story/story.md`: refine it in place. A genuinely separate story belongs in a new unit.
- Write `active_intent_id`, `active_unit_id` and `active_story_id` to `.specify/state/session.yaml`.

## Interview (one question at a time)
Ground it first: the projects router (which surfaces exist), `specs/domain/bounded-contexts.md` and the
module file of any context the story plainly lands in (domain language, invariants, ownership). Use them
to ask sharper questions, not more of them. Skip anything the tracker seed already answers.

**Feature** — cover each dimension, following up only when the trigger fires:

| Dimension | Ask | Follow up when |
|---|---|---|
| Actor | who performs it | "admin"/"system" → user-facing or internal? |
| Action | the concrete action | a vague verb ("manage", "handle") |
| Value | the business outcome | only a technical reason is given |
| Trigger | what starts it | event-driven → what produces the event? |
| Input / Output | what goes in; how the user knows it worked | "form data", or no visible result |
| Happy path | the steps | more than 5 steps → suggest splitting the unit |
| Error cases | what can go wrong, and what the user sees | "show an error" without the states |
| Out of scope | what this story does not do | — |

Then the acceptance criteria. Each must be testable (Given/When/Then or a checkable condition),
independent, free of unquantified adjectives; at least one covers an error case and one the core value.
Follow up on any that fails.

**Bug** — expected behaviour (cite the spec or story if known), actual behaviour, numbered reproduction
steps, related story id, and at least 2 criteria that define "fixed". Out of scope defaults to "no new features".

## Write
Into `units/{unit}/01-story/`, from `{templates_dir}/artifacts/story-template.md`:
- `story.md` — frontmatter `id` (`{INTENT}-{UNIT}-{NNN}`), `intent`, `unit`, `story_type` (feature | bug),
  `tags`, `checkpoint_mode`; leave `status` as the hook set it and `jira_id: null`. Body: As a / I want /
  So that, in scope, out of scope. Bug: `expected_behavior`, `actual_behavior`, `reproduction_steps`,
  `related_story`.
- `requirement.md` — functional and non-functional requirements from the interview.
- `acceptance-criteria.md` — the criteria.

## Tags
The vocabulary is the union of the Signals column of the `## Registry` table in `.claude/skills/README.md`.
Set `tags` to the vocabulary words that occur in the title, requirement and criteria (whole word,
case-insensitive, not negated — "no cache" does not tag `cache`). No registry or no match: `tags: []`.
Never invent a tag; note an important unmatched concept in requirement.md.

## checkpoint_mode
Classify with `.claude/skills/governance/checkpoint-rules.md` and write it to `story.md` frontmatter. A bug
defaults to `autopilot` unless the fix touches a service boundary or data model (`confirm`).
