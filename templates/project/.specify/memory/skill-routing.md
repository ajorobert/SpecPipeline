# Skill Routing Manifest
<!-- PROJECT-OWNED. Generated once by /sk.init, then edited by the team. setup.sh never reads or writes it.

     This is the only bridge between the framework's sk.* process skills and your project's
     capability packs. The framework ships no packs and never names one; the sk.* skills read this
     file through .claude/skills/governance/pack-resolution.md.

     To add a pack:
       1. Put it at .claude/skills/<pack>/SKILL.md. Write your own, or copy a starting point:
            cp -r .speckit/skills_archive/<group>/<pack> .claude/skills/
       2. Register it in a table below.
     Paths are relative to the project root. An unregistered pack is never loaded by sk.* skills. -->

max_packs: 6

## Always
<!-- Loaded whenever the Scope matches. Scope is one of:
       - a phase: design | plan | implement | review | test | uat | perf | refactor
       - a project type: Backend | Frontend | Mobile
       - an exact project name from .specify/memory/projects/index.md
       - {type-or-project}@{phase}, e.g. Backend@review
     List a project type's canonical pack first. Separate multiple paths with ", ".
     Example rows:
     | design | .claude/skills/<design-pack>/SKILL.md |
     | Backend | .claude/skills/<backend-canonical-pack>/SKILL.md, .claude/skills/<backend-feature-pack>/SKILL.md | -->
| Scope | Skill path(s) |
|---|---|

## By signal
<!-- Loaded when a signal matches a story tag (exact) or the working text (whole word, case-insensitive).
     Signals: comma-separated keywords. sk.story_sub_specify offers the union of all signals as the story tag vocabulary.
     Phases: comma-separated subset of design, plan, implement, review, test, uat, perf, refactor.
     Applies to: any | Backend | Frontend | Mobile (comma-separated).
     Example row:
     | cache, caching, invalidation | .claude/skills/<caching-pack>/SKILL.md | design, implement, review | Backend | -->
| Signals | Skill path | Phases | Applies to |
|---|---|---|---|

## Surfaces
<!-- One row per user-facing surface (every Frontend/Mobile project). Read by sk.design_sub_ui-design, sk.design_sub_contracts
     (consumer test-plan sections), sk.design (frontend signal detection) and sk.uat (tooling).
     Platform: browser | native. Native surfaces never use browser E2E tooling.
     Example row:
     | customer-web | Customer.Web | <framework + version> | browser | <e2e tool> | -->
| Surface | Project | Framework | Platform | E2E tooling |
|---|---|---|---|---|

## Migrations
<!-- One row per project that owns a database schema. Read by sk.migrate and sk.rollback.
     Layouts are paths under the project's Code Root; use {name} for the migration name.
     Example row:
     | Backend.API | <migration tool> | <code-root>/Migrations/{timestamp}_{name} | <code-root>/tests/Migrations/{name} | -->
| Project | Tool | Migration layout | Migration test layout |
|---|---|---|---|
