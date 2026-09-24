# Memory Guide

SpecKit separates what the framework owns from what your project owns, and gives every project fact
exactly one home. The full table of homes, precedence and loading rules is
`.claude/skills/governance/profile.md`; this page is the overview.

| Tier | Owner | Lives in | Changed by |
|---|---|---|---|
| 1 — Framework | SpecKit-SSD-SDLC | `.claude/skills/sk.*`, `.claude/skills/governance/`, the framework agents, `.claude/hooks/*.sh`, `.claude/.speckit-manifest` | `bash .speckit/setup.sh` after a subtree pull. Never edit these in a project. |
| 2 — Project skills and rules | Your team | Other skills under `.claude/skills/` + the Registry table in `.claude/skills/README.md`; `.claude/rules/{stack}/`; `.claude/commands/`; extra agents | You. setup.sh never reads, writes, or lists them. Starting points: `.speckit/skills_archive/`. |
| 3 — Project knowledge | Your team | `specs/**`, `.specify/**`, `history/**`, `CLAUDE.md` outside the managed block, `.claude/settings.json` (setup.sh only merges hooks/deny) | `/sk.init` writes the profile, project router and constitution; skills write the homes they own; you edit the rest. |

The framework never names a project skill. It reads your one registry — the `## Registry` table in
`.claude/skills/README.md` — through `.claude/skills/governance/pack-resolution.md`.

## Knowledge homes

```
specs/
├── knowledge-base.md             why the system exists, actors (tier 1, @imported by CLAUDE.md)
├── adr/
│   ├── adr-index.md              router: ALWAYS block + signal blocks + loading rules     (sk.adr)
│   └── NNNN-kebab-title.md       one decision each                                         (sk.adr)
├── domain/
│   ├── bounded-contexts.md       the contexts and their relations                          (sk.design, sk.knowledge-base)
│   └── {module}.md               one context: language, invariants, rationale (tier 2)     (sk.design, sk.knowledge-base)
├── openapi/{audience}.yaml       canonical HTTP contract, edited on the feature branch     (sk.design_sub_contracts)
├── asyncapi/{module}.yaml        canonical async contract                                   (sk.design_sub_contracts)
└── intents/{intent}/units/{unit}/  in-flight work; promoted then frozen at ship          (the unit pipeline)

.specify/
├── profile.yaml                  project facts: vcs, tracker, contracts.verify, rules.stacks, never_autoload (sk.init)
├── memory/
│   ├── constitution.md           the team's fixed core principles only                     (sk.init)
│   └── projects/
│       ├── index.md              router: Project · Type · Code Root · Role                 (sk.init)
│       └── {Project}/tech-stack.md  dated version snapshot, test layout, E2E, migrations  (sk.init, sk.plan refresh)
└── state/                        per-developer runtime state — gitignored (see below)

.claude/
├── rules/{stack}/<topic>.md      path-scoped coding rules, < 200 lines, ADR cited as provenance
└── skills/README.md              the Registry table of project skills

history/prompts/                  prompt history records                                    (sk.phr)
```

Entities and schema are not documented anywhere but the code. There is no summary copy of the ADRs,
the domain or the contracts: a skill reads the home.

## Runtime state (not memory)

| File | Holds | Notes |
|---|---|---|
| `.specify/state/session.yaml` | role, branch, active intent/unit/story focus | managed by `/sk.session` |
| `.specify/state/active-skill`, `active-skill-role`, `last-skill` | the running skill, for write-scope checks and SK_RESULT | hooks; cleared every turn |
| `.specify/state/skill-audit.log` | every status transition | appended by the one status command |
| `.specify/state/tracker-outbox/` | status transitions waiting to be mirrored to the tracker | `story-status.sh mirror-*` |
| `01-story/story.md` frontmatter | `status.current`, `checkpoint_mode`, `test-status`, `security-status`, `verify-status`, `jira_id` | the single source of truth for gates; changed only through `.claude/hooks/story-status.sh` and the hooks |

## Editing rules
- Homes hold what the code cannot tell you — never narrative the code already carries.
- A decision changes through an ADR; a version bump only refreshes `tech-stack.md`.
- Register a project skill in the Registry only once it exists under `.claude/skills/`.
- Humans-only paths go in `knowledge.never_autoload`; no AI loads them unless a human names the file.
- A shipped unit is frozen: new work starts a new unit.
- Do not edit framework-owned paths in a project; changes there are overwritten on the next `setup.sh`.
