# sk.knowledge-base
Generates or updates a knowledge base at the specified tier.
Role: architect | Level: system | domain | unit

## Input Artifacts

`ADR_DIR` = `adr_dir:` from `.specify/project-config.md` → default `history/adr`.

### If --tier system
specs/knowledge-base.md (if exists — REFINE MODE)
.specify/memory/system-context.md
{ADR_DIR}/ (all ADRs — extract system-level decisions)

### If --tier domain
specs/domains/{domain}/knowledge-base.md (if exists — REFINE MODE)
{ADR_DIR}/ (ADRs tagged to this domain)
specs/intents/ (scan for units belonging to this domain)

### If --tier unit
specs/intents/{intent}/units/{unit}/knowledge-base.md
  (if exists — REFINE MODE)
specs/intents/{intent}/units/{unit}/02-design/architecture.md
{ADR_DIR}/ (ADRs tagged to this unit)

## Steps

### Tier: system
1. [REFINE MODE] if specs/knowledge-base.md exists
   [CREATE MODE] if not
2. Read system-context.md for system overview
3. Scan all ADRs — extract system-level decisions and rejections
4. Interview user for non-derivable content:
   - Why does this system exist as a product?
   - Who are the core actors and what is their business intent?
   - What are the domain boundaries and why drawn that way?
   - What system-wide invariants exist?
   - What has been tried at system level and changed?
5. Write or update specs/knowledge-base.md
   Use system-knowledge-base-template.md

### Tier: domain
1. Ask user: which domain? (or read --domain argument)
2. [REFINE MODE] if specs/domains/{domain}/knowledge-base.md exists
   [CREATE MODE] if not — create specs/domains/{domain}/ directory
3. Scan ADRs tagged to this domain
4. Interview user for non-derivable content:
   - Why is this a separate bounded context?
   - What are the business invariants that span multiple units?
   - What cross-domain contracts exist that aren't in API specs?
   - What has been tried at domain level and why changed?
   - What are safe vs dangerous change patterns?
5. Write or update specs/domains/{domain}/knowledge-base.md
   Use domain-knowledge-base-template.md

### Tier: unit
1. Read session.yaml active_unit_id
   NULL → ask user for unit
2. [REFINE MODE] if unit knowledge-base.md exists
   [CREATE MODE] if not
3. Read 02-design/architecture.md for this unit
4. Scan ADRs tagged to this unit
5. Interview user for non-derivable content:
   - What decisions look arbitrary but aren't?
   - What was tried and rejected for this unit?
   - What external constraints exist that aren't in the code?
   - What invariants span multiple files in this unit?
   - How should future engineers safely extend this?
6. Write or update knowledge-base.md
   Use unit-knowledge-base-template.md
   Location: specs/intents/{intent}/units/{unit}/knowledge-base.md

## Output Artifacts
specs/knowledge-base.md (tier system)
specs/domains/{domain}/knowledge-base.md (tier domain)
specs/intents/{intent}/units/{unit}/knowledge-base.md (tier unit)

## Quality Bar
- Zero content derivable from reading code
- Every section answers "why" not "what"
- Business invariants stated as rules not descriptions
- Rejected approaches include reason for rejection
- Safe change patterns are specific not generic

## Size Advisory
Knowledge bases that grow too large defeat the context budget and cause sk.implement to
load too much at once. Apply these limits strictly:

| Tier | Soft limit | Hard limit | Action when exceeded |
|------|-----------|------------|----------------------|
| system (tier 1) | 200 lines | 300 lines | Extract domain-specific content to a tier 2 domain knowledge base |
| domain (tier 2) | 150 lines | 250 lines | Extract unit-specific content to the relevant tier 3 unit knowledge base |
| unit (tier 3) | 100 lines | 150 lines | Split into multiple sections; remove any content derivable from code |

**Extraction rule:** If a section in tier 1 is only relevant to one domain, move it to tier 2.
If a section in tier 2 is only relevant to one unit, move it to tier 3.
Content that appears in two tiers is a duplication error — keep it at the most specific tier only.

When REFINE MODE: check current line count. If over soft limit, prompt user before adding content:
"This knowledge base is at {N} lines (soft limit: {limit}). Should we extract some content
to a lower tier before adding more?"
