# Core Domains

One knowledge base per core domain.
Core domains are stable bounded contexts that feature modules depend on.

## Structure
specs/domains/{domain-name}/knowledge-base.md

## What Belongs Here vs Unit Knowledge Bases
Domain knowledge base: business invariants that span multiple units,
  boundary rationale, cross-domain contracts not in any API spec,
  evolution history that constrains domain-level design.

Unit knowledge base: unit-specific decisions, what was rejected
  for this unit, external constraints specific to this unit,
  safe change patterns for this unit.

## Creating a New Domain Knowledge Base
Run: sk.knowledge-base --tier domain --domain {name}
