Checkpoint Rules
Read by: sk.story_sub_specify (to classify), sk.impact (to recommend), and every gated skill via
`.claude/skills/governance/review-gate.md`.

Source of truth
`checkpoint_mode` lives in the active story's frontmatter, `specs/intents/{intent}/units/{unit}/01-story/story.md`.
It is written once by sk.story_sub_specify and changed only by an explicit escalation. session.yaml never
holds it. Valid values: autopilot | confirm | validate. Any other value is invalid; treat it as
validate and flag it.

Classification
Evaluate the work item against these criteria and write the result to story frontmatter.

Autopilot (0 checkpoints)
- Change isolated to one project
- No contract changes
- No new domain entities
- UI-only change, or a bug fix that touches no service boundary or data model

Confirm (1 checkpoint — after sk.plan, before sk.implement)
- New feature within an existing bounded context
- New endpoints on an existing service
- Non-breaking schema additions
- Bug fix that touches a service boundary or data model

Validate (2 checkpoints — after sk.design AND after sk.plan)
- New service or bounded context
- Breaking API contract changes
- Cross-service data model changes
- Auth, payments, or security-adjacent work
- Multi-frontend impact

Checkpoint Behaviour
Autopilot: proceed without stopping (engineering-review hard stops still apply)
Confirm:   stop after sk.plan, show plan summary, wait for explicit approval
Validate:  stop after sk.design, wait for approval
           stop again after sk.plan, wait for approval
           only then proceed to sk.implement

Enforcement
- skill-start.sh (on both the typed and the Skill-tool path) blocks sk.implement and sk.ship when `checkpoint_mode` is unset.
- For confirm | validate it also blocks sk.implement until at least one
  `03-plan/{Project}/plan.md` carries `status: approved`.
