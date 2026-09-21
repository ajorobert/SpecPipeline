.claude/skills/
Framework-owned (synced by setup.sh — do not edit in a consuming project):
  sk.*/                    process skills (SKILL.md + prompt.md); the sk. namespace is reserved
  sk.{parent}_sub_{leaf}/  internal sub-skills of an orchestrator, e.g. sk.design_sub_architecture.
                           Flat because skill discovery is one level deep — a nested folder is never
                           registered and `Skill(...)` on it fails. Grouped by the name prefix so the
                           pipeline they belong to is obvious when browsing. Their `description:`
                           forbids direct invocation; only the parent orchestrator calls them.
                           They deliberately do NOT set `disable-model-invocation: true` — that flag
                           stops ALL model invocation, orchestrators included, so it would break the
                           pipeline. The description is the guard instead. Reserve the flag for
                           user-run entry points (sk.init, sk.session, sk.ship, sk.hotfix, sk.rollback).
  governance/              checkpoint rules, quality gates, status model, pack resolution, framework
                           paths, and the shared prompt blocks every sk.* skill references by path
  system-context/ service-registry/ domain-model/ architecture-decisions/ standards/
                           pointer stubs into .specify/memory/

SKILL.md frontmatter: `name` (must equal the folder name), `description`, `subagent_type`,
`inject_files`, optional `rubric`, and optional `preconditions` — the only block with machine
enforcement (check-skill-preconditions.sh). Keep `description` a valid YAML double-quoted scalar: a
stray backslash escape such as `\|` breaks frontmatter parsing silently. Use `[|]` in a regex instead.

Anything else in this folder is project-owned (for example capability packs) and is never touched by
setup.sh. Register project packs in .specify/memory/skill-routing.md so sk.* skills can load them.
