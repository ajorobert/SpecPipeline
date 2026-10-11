# Step 2 — Clarify (business)
Read `01-story/` (story.md, requirement.md, acceptance-criteria.md).

## Assess once
Mark each ✅ clear / ⚠️ partial / ❌ missing:
- the actor is a specific role; the action a concrete verb; the value a business outcome
- at least 3 criteria (2 for a bug), each testable, at least one negative case, no unquantified adjective
- out of scope stated; no implicit scope assumption
- critical journeys and their error, empty and loading states
- no TODO or `[NEEDS CLARIFICATION]` marker

All ✅: say so and skip to step 3.

## Ask (at most 5, one at a time)
Queue the ⚠️/❌ items by business impact; never show the queue. For each question:
- multiple choice: give **Recommended:** with a one-line reason, then the options as a table;
- short answer: give **Suggested:** with a one-line reason.

After each answer, append `- Q: … → A: …` under `## Clarifications / ### Session {date}` in
requirement.md, apply it to the file it changes (criteria → acceptance-criteria.md, scope → story.md,
rules → requirement.md) and save. Stop early when the human says done or nothing critical is left.
If the answers changed the scope, say so.
