# Memory Guide

SpecKit separates what the framework owns from what your project owns, and gives every project fact one
home. The full table of homes, precedence and profile keys is `.claude/skills/governance/profile.md`; this
page is the overview.

| Tier | Owner | Lives in | Changed by |
|---|---|---|---|
| Framework | SpecKit | `.claude/skills/sk.*`, `.claude/skills/governance/`, `.claude/agents/sk-reviewer.md`, `.claude/hooks/*.sh`, `.claude/.speckit-manifest` | `bash .speckit/setup.sh` after a subtree pull — never edited in a project |
| Project skills and rules | your team | other skills under `.claude/skills/` + the Registry table; `.claude/rules/`; `.claude/commands/`; your agents | you — setup.sh never reads or writes them |
| Project knowledge | your team | `specs/**`, `.specify/**`, `CLAUDE.md` outside the managed region, `.claude/settings.json` (setup.sh replaces only its own hook entries and unions deny rules) | `/sk.init` seeds the profile, projects router and principles; commands write the homes they own; you edit the rest |

## Knowledge homes
```
.claude/rules/principles.md       principles, loading order, working style — loaded every session (sk.init seeds)
.claude/rules/{area}/<topic>.md   path-scoped coding and authoring rules, < 200 lines
.claude/skills/README.md          the Registry table of project skills

specs/
├── adr/adr-index.md              router: ALWAYS block + signal blocks + loading rules     (sk.adr)
├── adr/NNNN-kebab-title.md       one decision each                                         (sk.adr)
├── domain/bounded-contexts.md    the contexts and their relations                          (sk.design)
├── domain/{module}.md            one context: language, invariants, rationale             (sk.design, promotion)
├── openapi/{audience}.yaml       canonical HTTP contract, edited on the feature branch     (sk.design)
├── asyncapi/{module}.yaml        canonical async contract                                   (sk.design)
└── intents/{intent}/units/{unit}/  in-flight work; promoted, then frozen, at ship

.specify/
├── profile.yaml                  project facts: vcs, tracker, contracts, review commands, never_autoload (sk.init)
├── memory/projects/index.md      router: Project · Type · Code Root · Role                 (sk.init)
├── memory/projects/{Project}/tech-stack.md   build/test commands, test layout, E2E, migrations (sk.init)
└── state/                        per-developer runtime state — gitignored
```
Entities and schema live only in the code. Nothing keeps a summary copy of the ADRs, the domain or the
contracts: a command reads the home.

## Runtime state (not memory)
| File | Holds | Notes |
|---|---|---|
| `.specify/state/session.yaml` | role, branch, active intent/unit/story | `/sk.session` |
| `.specify/state/active-skill`, `active-skill-role`, `last-skill` | the running command, its role, a pending verdict | set at command start; kept across a gate's turns; cleared by the next command or a new session |
| `.specify/state/skill-audit.log` | every status transition | appended by the one status command |
| `.specify/state/tracker-outbox/` | transitions waiting to mirror to the tracker | `story-status.sh mirror-*` |

## Editing rules
- A home holds what the code cannot tell you — never narrative the code already carries.
- A decision changes through an ADR; a principle changes in the principles file, by the team.
- Register a project skill in the Registry once it exists under `.claude/skills/`.
- Human-only paths go in `knowledge.never_autoload`; no AI opens them unless a person names the file.
- A shipped unit is frozen: new work starts a new unit.
- Never edit framework-owned paths in a project; `setup.sh` replaces them.
