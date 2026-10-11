---
name: sk.adr
description: "Record an architecture decision: check it against the routed ADRs and principles, write specs/adr/NNNN-*.md in the project's ADR shape, route it from adr-index.md, and supersede an older ADR when it replaces one."
role: architect
---

# sk.adr
Writes one ADR, in the session that made the decision (sk.design and sk.ship call it with `Skill(sk.adr)`).
Any ADR authoring rules the project keeps under `.claude/rules/` load when an ADR file is opened, and win
over this procedure's defaults.

## Paths
`scripts_dir` and `templates_dir` from `.claude/.speckit-manifest` (framework repo: `scripts`,
`templates`). `.specify/profile.yaml` → `knowledge.adr.exemplar`, `knowledge.adr.guard` (default true),
`rules.stacks`. Never glob `specs/adr/`.

## Steps
1. **Collect** (pre-filled from the unit's design when called from one): a title that names the decision;
   the context — forces and constraints; the decision in one paragraph; checkable rules for implementers;
   at least 2 rejected alternatives, each with why it lost; consequences, at least one positive and one
   negative, plus follow-ups; whether it supersedes an ADR; the signals that must load it (story tags,
   file areas, request words). Ask again until the alternatives and a negative consequence exist.
2. **Check** — load what `specs/adr/adr-index.md` routes for these signals. An ADR that already makes the
   decision: offer to amend or supersede it instead. A conflict with a routed ADR: ask whether this one
   supersedes it. A conflict with a principle: say so; the ADR may depart from it only by stating why in
   its Context.
3. **Reserve** — `bash {scripts_dir}/create-adr.sh "<title>"` prints the created path; its number is the
   ADR's number. Never choose either yourself.
4. **Write** — in the shape of `knowledge.adr.exemplar` (its headings, order and heading/status style — not
   its content), else `{templates_dir}/artifacts/adr-template.md`. Status `Proposed` until the human
   accepts, then `Accepted` with the date. Rules first when the shape has a Rules section. Provenance: the
   intent, unit and story ids, and what it supersedes.
5. **Route** — create `adr-index.md` from `{templates_dir}/artifacts/adr-index-template.md` when absent
   (without its placeholder entries). Register by the index's own rules and line format: the ALWAYS
   block when it binds every change (ask first; keep it short), else each matching signal block, else
   one new block headed by lower-case signals (prefer existing story-tag words). Never append a flat row.
6. **Supersede** — the old ADR's Status becomes `Superseded by ADR-NNNN — {date}`, nothing else in it
   changes; its index lines move under the successor's line (`- supersedes [ADR-MMMM: …](MMMM-….md)`).
7. **Rules** — lines a reviewer would check file by file: offer to write them to
   `.claude/rules/{area}/<topic>.md` (from `{templates_dir}/artifacts/rule-template.md` for a new file;
   self-contained, under 200 lines, `paths:` front-matter, `Source: ADR-NNNN`, no `@import`).
8. **Guard** — unless `knowledge.adr.guard` is false, `bash {scripts_dir}/check-adr-index.sh`; fix what it
   reports (route an unrouted ADR, correct a dangling route) until PASS. Never remove a route to an
   existing ADR to make it pass.
9. **Knowledge** — only when the ADR adds something a reader of the ADR would miss: one line (decision,
   why, what was rejected, `ADR-NNNN`) in the owning `specs/domain/{module}.md`'s rationale section, or
   in the unit's `knowledge-base.md`. Never copy the ADR's rules.

## Completion report
```
sk.adr — ADR-NNNN: {title} ({Proposed | Accepted})
File: specs/adr/NNNN-….md   Routed from: {ALWAYS | block | new block}   Supersedes: {ADR | none}
Rules written: {files | none}   ADR guard: {PASS | skipped}
```
