# Step 1 — Architecture and impact
Outputs: `02-design/architecture.md`, `02-design/impact-analysis.md`; `specs/domain/` for a new bounded context.
Present outputs are refined in place: keep what is still valid, change what the story changes.

For code reconnaissance on a large codebase — where a capability already lives, which pattern the
nearest module uses — dispatch an Explore subagent with a narrow question and use its summary.

## Architecture
From `{templates_dir}/artifacts/architecture-template.md`, covering the whole story:
- the bounded context, named as in `specs/domain/bounded-contexts.md` (a name not listed there is new);
- responsibilities, internal components, communication patterns and data flow;
- the consistency requirement of every write path (strong / eventual / causal) and its transaction boundary;
- the failure mode of every external dependency (timeout, fallback, retry, circuit breaker);
- the security approach (who may do what; data isolation);
- open questions, and every decision marked `ADR required` (see the command's ADR rule).

## Impact analysis
From `{templates_dir}/artifacts/impact-analysis-template.md`. Every row of `unit-brief.md` → Impacted
Projects appears exactly once, with a change type (new | modified | config-only | none) and what changes
in it. Add the contracts between projects and the **Sequencing & Dependencies** between them (what must
land first); plan and implement follow this order.

## New bounded context
- Add its row and relations to `specs/domain/bounded-contexts.md` in that file's format (create it from
  `{templates_dir}/artifacts/bounded-contexts-template.md` when absent).
- Create `specs/domain/{module}.md` from the template `knowledge.domain.template` names (`default` =
  `{templates_dir}/artifacts/domain-template.md`; `none` = only the headings needed; a path = that file),
  holding only what the architecture establishes: purpose, language, relations.

## Engineering review
Judge the written design against the routed ADRs, the principles file, `bounded-contexts.md` and the
touched domain files, the projects router, and the loaded design packs:
- **BLOCKING** — another context owns what this unit claims; a routed ADR or a principle is contradicted.
- **MEDIUM** — a write path without a consistency requirement or transaction boundary; an external
  dependency without a failure mode; a design that forces code to break a project rule; a pack's
  `[REQUIRED]` rule violated.
- **ADVISORY** — an `ADR required` decision not yet raised.

Fix BLOCKING and MEDIUM before the gate. Report "Engineering review passed", "passed with advisories"
(list them) or "FAILED" (list all).

## Gate 1 — Architecture
Show: architecture.md, impact-analysis.md, the `specs/domain/` diff, the review result. Check for:
- the context is correct and scoped to this unit; a new one is registered and has its domain file;
- every impacted project has a row with a change type;
- no BLOCKING or MEDIUM finding left;
- every `ADR required` is raised now or listed with a reason;
- the open questions are acceptable to carry into the data model.
On cancel: the later steps do not run.
