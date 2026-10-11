# Step 2 — Data model
Output: `02-design/database-design.md`; invariants and rationale into the owning `specs/domain/{module}.md`.

1. Conflict check first: `bounded-contexts.md` (who owns what), the owning domain files, and the existing
   entity and schema code of those contexts. Flag any entity this unit would create or change that another
   context owns, or that already exists under another name.
2. Design the entities, relationships and the access strategy for every query pattern in
   architecture.md, judged against the routed ADRs, the project rules and the loaded packs. Declare the
   transaction boundary and isolation of every write path.
3. Classify every schema change as additive or breaking. A breaking change needs the human's
   confirmation and a migration strategy (expand/contract steps, backfill, rollback).
4. Refining: keep existing entities, mark removed ones deprecated with a revision note — never delete.
5. An invariant, business rule or rationale that holds for the whole bounded context (not only this unit)
   goes into the owning `specs/domain/{module}.md`, into its existing sections; add the smallest heading
   that fits only when none does. Write the non-derivable essence only — never field lists.

## Gate 2 — Data model
Show: database-design.md and the diff of every domain file changed. Check for:
- no entity conflicts with another context's ownership;
- breaking changes are intended and have a migration strategy;
- every query pattern has an access strategy; every write path a transaction boundary;
- nothing contradicts a routed ADR or a principle.
On cancel: contracts and UI do not run.
