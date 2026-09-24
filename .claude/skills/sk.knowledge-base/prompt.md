# sk.knowledge-base
Generates or updates a knowledge base at the specified tier.
Role: architect | Level: system | domain | unit

## Homes
Each tier has one fixed home (`.claude/skills/governance/profile.md` → The homes):

| Tier | Home | Template (only when the file is created) |
|---|---|---|
| system (1) | `specs/knowledge-base.md` | `{TEMPLATES_DIR}/artifacts/system-knowledge-base-template.md` |
| domain (2) | `specs/domain/{module}.md`, registered in `specs/domain/bounded-contexts.md` | `knowledge.domain.template` (below) |
| unit (3) | `specs/intents/{intent}/units/{unit}/knowledge-base.md` | `{TEMPLATES_DIR}/artifacts/unit-knowledge-base-template.md` |

There is no routing file at the system or domain tier: `bounded-contexts.md` is the domain map. Only
the unit tier has a `guide.yaml`, and sk.design writes it.

**What does not belong here.** A knowledge base holds only what neither the code nor another home can
tell. Never write a fact whose home is:
- an **ADR** — a decision with system or cross-module reach → offer `sk.adr` instead;
- a **rule file** — a checkable coding rule → `.claude/rules/{stack}/<topic>.md` (promotion in sk.ship);
- a **contract** — an operation, payload or event shape → `specs/openapi/{audience}.yaml` / `specs/asyncapi/{module}.yaml`.
A knowledge base may point to those homes (`ADR-NNNN`, a spec path); it never restates them.

## Pre-flight
1. Resolve `TEMPLATES_DIR` per `.claude/skills/governance/framework-paths.md`.
2. Read `.specify/state/session.yaml` (active_intent_id, active_unit_id).
3. Read `.specify/profile.yaml` once (defaults in `.claude/skills/governance/profile.md`). Never read a
   path matched by `knowledge.never_autoload`, or a shipped unit other than the active one.
4. ADRs are loaded through `specs/adr/adr-index.md` per its own loading rules — never by globbing
   `specs/adr/`. A missing home is logged `{home} not present — skipped`.

## Input Artifacts

### If --tier system
specs/knowledge-base.md (if exists — REFINE MODE; already in context through CLAUDE.md)
.specify/memory/projects/index.md (the projects the system consists of)
specs/domain/bounded-contexts.md (the domain map)
specs/adr/adr-index.md → the ALWAYS block's ADRs (system-level decisions and rejections)

### If --tier domain
specs/domain/bounded-contexts.md (which module; whether it is registered)
specs/domain/{module}.md (if exists — REFINE MODE)
specs/adr/adr-index.md → the ADRs of the ALWAYS block and of every signal block matching the module
The active unit's `02-design/architecture.md` and `knowledge-base.md`, when the work comes from a unit

### If --tier unit
specs/intents/{intent}/units/{unit}/knowledge-base.md
  (if exists — REFINE MODE)
specs/intents/{intent}/units/{unit}/02-design/architecture.md
specs/adr/adr-index.md → the ADRs of the blocks matching the story's tags and the unit's text

## Steps

### Tier: system
1. [REFINE MODE] if specs/knowledge-base.md exists
   [CREATE MODE] if not
2. Read the projects router and `bounded-contexts.md` for the system's shape
3. Read the ALWAYS-routed ADRs — note system-level decisions and rejections as pointers only
4. Interview user for non-derivable content:
   - Why does this system exist as a product?
   - Who are the core actors and what is their business intent?
   - What are the domain boundaries and why drawn that way?
   - What system-wide invariants exist?
   - What has been tried at system level and changed?
5. Write or update specs/knowledge-base.md
   CREATE MODE: from `system-knowledge-base-template.md`. REFINE MODE: write into the file's existing
   sections; add the smallest heading that fits only when no section does. The Domain Map section
   points to `specs/domain/bounded-contexts.md` rather than copying it.

### Tier: domain
1. Ask user: which module? (or read --domain argument). Use the module name as it appears in
   `bounded-contexts.md` when it is registered there.
2. [REFINE MODE] if specs/domain/{module}.md exists — write into its existing sections, in its own
   format; never impose the template's structure on it.
   [CREATE MODE] if not — create it from `knowledge.domain.template`:
   `default` → `{TEMPLATES_DIR}/artifacts/domain-template.md`; `none` → headings only as needed;
   a path → that file. In the same change, add the module's row (and any relation) to
   `specs/domain/bounded-contexts.md` in that file's own format; create `bounded-contexts.md` from
   `{TEMPLATES_DIR}/artifacts/bounded-contexts-template.md` only if it is absent.
3. Read the routed ADRs that concern this module
4. Interview user for non-derivable content:
   - Why is this a separate bounded context?
   - What are the business invariants that span multiple units?
   - What relations to other contexts exist, and which contract carries each?
   - What has been tried at domain level and why changed?
   - What are safe vs dangerous change patterns?
5. Write or update specs/domain/{module}.md

### Tier: unit
1. Read `.specify/state/session.yaml` active_unit_id
   NULL → ask user for unit
2. [REFINE MODE] if unit knowledge-base.md exists
   [CREATE MODE] if not
3. Read 02-design/architecture.md for this unit
4. Read the ADRs the index routes to this unit's work
5. Interview user for non-derivable content:
   - What decisions look arbitrary but aren't?
   - What was tried and rejected for this unit?
   - What external constraints exist that aren't in the code?
   - What invariants span multiple files in this unit?
   - How should future engineers safely extend this?
6. Write or update knowledge-base.md
   Use unit-knowledge-base-template.md in CREATE MODE
   Location: specs/intents/{intent}/units/{unit}/knowledge-base.md
   Items that must outlive the unit reach their home at ship (`.claude/skills/governance/promotion.md`).

## Output Artifacts
specs/knowledge-base.md (tier system)
specs/domain/{module}.md, and specs/domain/bounded-contexts.md when the module is new (tier domain)
specs/intents/{intent}/units/{unit}/knowledge-base.md (tier unit)

## Quality Bar
- Zero content derivable from reading code
- Zero content whose home is an ADR, a rule file or a contract — pointers only
- Every section answers "why" not "what"
- Business invariants stated as rules not descriptions
- Rejected approaches include reason for rejection
- Safe change patterns are specific not generic
- An existing file keeps its own format and sections

## Size Advisory
Knowledge bases that grow too large defeat the context budget and cause sk.implement to
load too much at once. Apply these limits strictly:

| Tier | Soft limit | Hard limit | Action when exceeded |
|------|-----------|------------|----------------------|
| system (tier 1) | 200 lines | 300 lines | Extract context-specific content to the owning `specs/domain/{module}.md` |
| domain (tier 2) | 150 lines | 250 lines | Extract unit-specific content to the relevant tier 3 unit knowledge base; move decisions to ADRs |
| unit (tier 3) | 100 lines | 150 lines | Split into multiple sections; remove any content derivable from code |

**Extraction rule:** If a section in tier 1 is only relevant to one bounded context, move it to tier 2.
If a section in tier 2 is only relevant to one unit, move it to tier 3.
Content that appears in two tiers is a duplication error — keep it at the most specific tier only.

When REFINE MODE: check current line count. If over soft limit, prompt user before adding content:
"This knowledge base is at {N} lines (soft limit: {limit}). Should we extract some content
to a lower tier before adding more?"
