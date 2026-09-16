# sk.phr
Records a Prompt History Record for significant decisions.
Role: any | Level: story or unit

## Input Artifacts
session.yaml (active focus for context)

## Resolve paths
- `SCRIPTS_DIR` = `scripts_dir:` from `.claude/.speckit-manifest` (written by setup.sh, e.g. `.speckit/scripts`)
  → if the manifest is absent (you are inside the framework repository itself) use `scripts`

## Steps
1. Collect: related command, decision, context, outcome, alternatives
2. Determine feature name from active_unit_id or active_story_id
3. Run `bash {SCRIPTS_DIR}/create-phr.sh "{feature-name}"`
4. Write PHR using `templates/artifacts/phr-template.md` (under the framework dir when installed)

## Output Artifacts
history/prompts/{feature}/PHR-{NNN}-{date}.md

## Quality Bar
- Outcome and rationale clearly distinct
- Alternatives rejected section populated
- Lessons section contains actionable insight
