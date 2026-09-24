.claude/skills/
Framework-owned (synced by setup.sh — do not edit in a consuming project):
  sk.*/                    process skills (SKILL.md + prompt.md); the sk. namespace is reserved
  sk.{parent}_sub_{leaf}/  internal sub-skills of an orchestrator, e.g. sk.design_sub_architecture.
                           Flat because skill discovery is one level deep — a nested folder is never
                           registered and `Skill(...)` on it fails. Grouped by the name prefix so the
                           pipeline they belong to is obvious when browsing. Their `description:`
                           forbids direct invocation; only the parent orchestrator calls them, always
                           with the Skill tool so the skill-start hook runs.
                           They deliberately do NOT set `disable-model-invocation: true` — that flag
                           stops ALL model invocation, orchestrators included, so it would break the
                           pipeline. The description is the guard instead. Reserve the flag for
                           user-run entry points (sk.session, sk.ship, sk.hotfix, sk.rollback).
  governance/              knowledge homes and profile, status model, pack resolution, phase layout,
                           quality gates, promotion, tracker mirror, and the shared prompt blocks every
                           sk.* skill references by path

SKILL.md frontmatter: `name` (must equal the folder name), `description`, `subagent_type`,
`inject_files`, optional `rubric`, and optional `preconditions` — the only block with machine
enforcement (skill-start.sh, on both the Skill-tool and the typed `/sk.*` path). Keep `description` a
valid YAML double-quoted scalar: a stray backslash escape such as `\|` breaks frontmatter parsing
silently. Use `[|]` in a regex instead.

In a consuming project this README is project-owned: its `## Registry` table is the project's one
skill registry (template: templates/artifacts/skills-registry-template.md), and setup.sh never touches it.
