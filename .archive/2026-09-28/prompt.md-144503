# sk.story_sub_clarify
Resolves business ambiguities in the active story using a structured 5-question loop.
Role: po | Level: story

## Mode Detection
- `sk.story_sub_clarify` → Focuses on business rules, value proposition, user interaction flows, data inputs/outputs, and functional edge cases. Framing uses PO/user language.

## Pre-flight
1. Read `.specify/state/session.yaml` active_story_id
   NULL → STOP: run sk.session focus --story {id} first
2. Load the active story folder (`.claude/skills/governance/phase-layout.md`):
   specs/intents/{intent}/units/{unit}/01-story/
   Read `story.md`, `requirement.md`, and `acceptance-criteria.md`.

## Ambiguity scan
Perform a structured coverage scan across these categories.
For each category mark status: Clear / Partial / Missing. If an orchestrator passed you specific seeds, prioritize those.

**Business Scope Categories:**
- Functional scope: user goals, success criteria, explicit out-of-scope
- Interaction & UX: critical user journeys, error/empty/loading states
- Edge cases: negative scenarios, user-facing conflict resolution
- Acceptance criteria: testability of each criterion, measurable Definition of Done
- Placeholders: TODO markers, ambiguous adjectives ("robust", "intuitive") lacking quantification

## Question loop (max 5 questions)
Generate an internal prioritized queue of up to 5 questions from Partial/Missing categories.
Prioritize business impact, user flow, and functional validation. Ensure language is business-friendly.

For each question:
1. Present EXACTLY ONE question at a time — never reveal the queue
2. For multiple-choice: state **Recommended:** option with 1-2 sentence rationale, then list options as table
3. For short-answer: state **Suggested:** answer with brief reasoning
4. After user answers: record in working memory, then immediately:
   - Append `- Q: <question> → A: <answer>` under `## Clarifications / ### Session YYYY-MM-DD` in `requirement.md`
   - Apply the clarification to the appropriate file in the story folder (`acceptance-criteria.md` for criteria, `story.md` for scope, `requirement.md` for rules/constraints)
   - Save the affected file after each integration
5. Stop early if: all critical ambiguities resolved, user signals "done"/"proceed", or 5 questions reached

## After loop completes
- Final pass: confirm no business [NEEDS CLARIFICATION] markers remain in the story folder
- If scope changed: flag it to the user. Never edit `status.current`; the story moves only through
  `bash .claude/hooks/story-status.sh` (sk.story Phase 6 sets `ready`).

## Output Artifacts
01-story/ — `requirement.md`, `acceptance-criteria.md`, and/or `story.md` updated with clarifications inline

## Quality Bar
- All business ambiguities resolved or explicitly deferred before moving to technical stages
- No contradictory statements remain in the story
- Each clarification bullet is testable (no vague language)
- Total questions asked ≤ 5
