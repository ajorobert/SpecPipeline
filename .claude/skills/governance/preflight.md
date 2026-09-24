# Pre-flight
Framework-owned block, referenced by path. A prompt says "Run the unit pre-flight" or "Run the story
pre-flight" and then lists only its own extra checks.

## Unit pre-flight
0. Resolve `TEMPLATES_DIR` / `SCRIPTS_DIR` per `.claude/skills/governance/framework-paths.md`.
1. Read `.specify/state/session.yaml`. Verify `active_unit_id` and `active_intent_id` are set.
   If either is missing: STOP. Run `sk.session focus --unit {unit-id}` first.
2. Resolve directories per `.claude/skills/governance/phase-layout.md`:
   `UNIT_DIR = specs/intents/{intent}/units/{unit}/`, `STORY_DIR = UNIT_DIR/01-story/`,
   `DESIGN_DIR = UNIT_DIR/02-design/`, `PLAN_DIR = UNIT_DIR/03-plan/`,
   `IMPL_DIR = UNIT_DIR/04-implementation/`, `TEST_DIR = UNIT_DIR/05-test/`.
3. Read `UNIT_DIR/unit-brief.md` → Impacted Projects.
   If it is missing or empty: STOP. Run sk.story (sk.story_sub_specify / sk.story_sub_architect-probe) first.
4. Read **`checkpoint_mode` from `STORY_DIR/story.md` frontmatter**. That frontmatter is the single
   source of truth, written by sk.story_sub_specify; session.yaml does not hold it.
   If it is missing: use `validate` and log `checkpoint_mode missing in story.md — defaulting to validate`.
5. Knowledge (non-derivable context), per the loading rules in `.claude/skills/governance/profile.md`:
   `specs/knowledge-base.md` (tier 1, already in context through CLAUDE.md), then
   `specs/domain/bounded-contexts.md` and the `specs/domain/{module}.md` file of each context the unit
   touches (tier 2), then `UNIT_DIR/knowledge-base.md` (tier 3, if one exists).
6. Read `.specify/profile.yaml` once (every key optional; defaults in `governance/profile.md`).
   Never read a path matched by `knowledge.never_autoload`, or a shipped unit other than this one.

## Story pre-flight
1. Read `.specify/state/session.yaml`. Verify `active_story_id` is set.
   If it is missing: STOP. Run `sk.session focus --story {story-id}` first.
2. Locate the story file per the phase-layout rules. Derive `{intent}` and `{unit}` from its path.
3. Continue with unit pre-flight steps 2–6.

## Role
Pre-flight never prompts for a role. Skills that branch on backend/frontend use the resolved
`{ProjectType}` first; session.yaml `role` is used only when no project is resolvable.
