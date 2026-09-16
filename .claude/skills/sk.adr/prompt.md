# sk.adr
Creates an Architecture Decision Record.
Role: architect | Level: unit or intent

## Input Artifacts
.specify/memory/architecture-decisions.md
.specify/project-config.md (`adr_dir` override, if present)
session.yaml (active_intent_id, active_unit_id)

## Resolve paths
- `ADR_DIR` = `adr_dir:` from `.specify/project-config.md` → default `history/adr`
- `SCRIPTS_DIR` = `scripts_dir:` from `.claude/.speckit-manifest` (written by setup.sh, e.g. `.speckit/scripts`)
  → if the manifest is absent (you are inside the framework repository itself) use `scripts`

## Steps
1. Determine next ADR number from architecture-decisions.md (and the highest existing file in `ADR_DIR`)
2. Collect: title, context, decision, alternatives, consequences
3. Run `bash {SCRIPTS_DIR}/create-adr.sh {number} "{title}" "{ADR_DIR}"`
4. Write ADR using `templates/artifacts/adr-template.md` (under the framework dir when installed)
   Include intent, unit, affected story IDs in frontmatter
5. Update architecture-decisions.md index

## Output Artifacts
{ADR_DIR}/ADR-{NNN}-{title}.md
.specify/memory/architecture-decisions.md (index updated)
knowledge-base.md (relevant tier updated if decision is significant)

## Knowledge Base Update
After writing ADR, evaluate:
- System-level decision → append to specs/knowledge-base.md
  Evolution History section
- Domain-level decision → append to relevant
  specs/domains/{domain}/knowledge-base.md
  What Was Tried and Rejected OR Evolution History section
- Unit-level decision → append to unit knowledge-base.md
  Key Decisions and Their Reasons section

Append only the non-derivable essence:
decision made, why, what was rejected.
Do not duplicate the full ADR content.

## Quality Bar
- Alternatives table populated with at least 2 options
- Consequences has both positive and negative entries
- Affected stories listed in frontmatter
- ADR written to the resolved ADR_DIR
