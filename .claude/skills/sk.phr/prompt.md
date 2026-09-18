# sk.phr
Records a Prompt History Record for significant decisions.
Role: any | Level: story or unit

## Input Artifacts
session.yaml (active focus for context)

## Resolve paths
- `SCRIPTS_DIR` and `TEMPLATES_DIR` per `.claude/skills/governance/framework-paths.md`

## Steps
1. Collect: related command, decision, context, outcome, alternatives
2. Determine feature name from active_unit_id or active_story_id
3. Run `bash {SCRIPTS_DIR}/create-phr.sh "{feature-name}"`
4. Write PHR using `{TEMPLATES_DIR}/artifacts/phr-template.md`

## Output Artifacts
history/prompts/{feature}/PHR-{NNN}-{date}.md

## Quality Bar
- Outcome and rationale clearly distinct
- Alternatives rejected section populated
- Lessons section contains actionable insight
