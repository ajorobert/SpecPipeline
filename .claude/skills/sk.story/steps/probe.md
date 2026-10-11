# Step 3 — Probe (technical) and Impacted Projects
Read the story folder (including `tags`) and route the ADRs by them. For each project the story plausibly
touches, read its `.specify/memory/projects/{Project}/tech-stack.md` when present.

## Assess once
Mark each ✅ / ⚠️ / ❌:
- **Scale** — volume, latency, retention or performance targets
- **Security** — who may and may not act; tenant or user data isolation
- **Observability** — how the business value is measured
- **Integration** — failure modes of downstream or external dependencies ("what does the user see when X is down?")
- **UX** — design references and accessibility constraints, for a user-facing story

## Impacted Projects (always)
Decide which projects the story changes, with a concrete reason each. Write the `## Impacted Projects`
table of `unit-brief.md`: `| Project | Type | Code Root | Role in this unit |`, with Project, Type and Code
Root copied verbatim from `.specify/memory/projects/index.md`. At least one row — a story that changes no
project is a defect to report, not an empty table. Every later phase runs off this table.

Under `## Architecture Constraints` in requirement.md, note what affects this story's scope: API changes
(name the audience or module), database impact, integration impact, security impact, breaking changes for
existing consumers, and ordering between projects. Cite an ADR or principle that constrains the story
(`ADR-NNNN`, `principles §N`) instead of restating it.

## Ask (at most 5, one at a time; none when every item is ✅, or with `--probe` on a clear story)
Translate each technical gap into a question a product owner can answer ("How quickly must other users see
this change?", not "What TTL?"), with one line on why it matters and a **Recommended:** or **Suggested:**
answer. Record each as `- Q: … → A: …` under `## Architecture Constraints / ### Session {date}` and apply it.

A constraint that conflicts with an ADR or a principle: say so, name the winning source, and suggest a
new ADR (`/sk.adr`) or a narrower story. Never edit an ADR or a rule here.
