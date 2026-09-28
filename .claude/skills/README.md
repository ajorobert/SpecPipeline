.claude/skills/
Framework-owned (synced by setup.sh — do not edit in a consuming project):
  sk.*/          one folder per command; the sk. namespace is reserved. SKILL.md holds the command's
                 procedure; `steps/*.md` hold its steps, read when the command reaches them.
  governance/    what the commands share: preflight and run model, roles (write scope), status model,
                 phase layout, review gates, checkpoint rules, quality gates, promotion, tracker mirror,
                 pack resolution and the knowledge-homes reference

SKILL.md front-matter: `name` (equals the folder name), `description` (the trigger only — keep it a valid
YAML double-quoted scalar; write `[|]`, never `\|`, in a regex), `role` (a role of governance/roles.yaml,
or `engineer` / `qa` — resolved from the `--projects` project type — or `any`), optional `rubric`,
optional `preconditions` (evaluated by skill-start.sh on both the typed and the Skill-tool path), and
`disable-model-invocation: true` for commands only a human starts (sk.session, sk.ship, sk.hotfix).

In a consuming project this README is project-owned: its `## Registry` table is the project's one skill
registry (template: templates/artifacts/skills-registry-template.md), and setup.sh never touches it.
