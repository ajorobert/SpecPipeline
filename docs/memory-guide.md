# Memory Guide

SpecKit separates what the framework owns from what your project owns. Three tiers:

| Tier | Owner | Lives in | Changed by |
|---|---|---|---|
| 1 — Framework | SpecKit-SSD-SDLC | `.claude/skills/sk.*`, `.claude/skills/governance/`, the five memory-pointer skills, the framework agents, `.claude/hooks/*.sh`, `.claude/.speckit-manifest` | `bash .speckit/setup.sh` after a subtree pull. Never edit these in a project. |
| 2 — Project skills | Your team | Everything else under `.claude/skills/` (capability packs), `.claude/commands/`, extra agents | You. setup.sh never reads, writes, or lists them. Starting points: `.speckit/skills_archive/`. |
| 3 — Project memory | Your team | `.specify/**`, `specs/**`, `history/**`, `CLAUDE.md` outside the managed block, `.claude/settings.json` (setup.sh only merges hooks/deny), `.claude/settings.local.json` | `/sk.init` generates it once; skills update specific files; you edit the rest. |

Tier 2 and tier 1 are joined by one Tier 3 file: **`.specify/memory/skill-routing.md`**. The framework never
names a pack; it resolves packs through that manifest (`.claude/skills/governance/pack-resolution.md`).

## `.specify/` — project memory

```
.specify/
├── project-config.md            identity, custom rules, overrides, adr_dir        (sk.init)
└── memory/
    ├── system-context.md        high-level system map                             (sk.init)
    ├── service-registry.md      service contracts                                 (sk.design_sub_contracts)
    ├── domain-model.md          canonical entities — check before adding new ones (sk.design_sub_datamodel)
    ├── architecture-decisions.md ADR index                                         (sk.adr)
    ├── constitution.md          principles, error + observability contracts        (sk.init)
    ├── skill-routing.md         capability packs, surfaces, migration layouts      (sk.init, then you)
    ├── auth_contract.md         identity shapes packs point at (optional)          (you)
    ├── observability-stack.md   one-time telemetry wiring packs point at (optional)(you)
    ├── command-rules.md / gemini-command-rules.md   agent behaviour rules
    ├── projects/                workspace mode: index.md router + {Project}/{project,tech-stack,coding-standards}.md
    └── standards/               tech-stack, coding, api, data, observability standards
```

## Runtime state (not memory)

| File | Holds | Notes |
|---|---|---|
| `.claude/session.yaml` | role, branch, active intent/unit/story focus | gitignored; managed by `/sk.session` |
| `01-story/story.md` frontmatter | `status.current`, `checkpoint_mode`, `test-status`, `security-status`, `verify-status` | the single source of truth for gates; hooks update it |

## Editing rules
- Memory files hold structured data only — no narrative that code can tell you.
- Standards change via ADR.
- `skill-routing.md` is yours: register a pack only once it exists under `.claude/skills/`.
- Do not edit `.claude/session.yaml` by hand during an active session; use `/sk.session`.
- Do not edit framework-owned paths in a project; changes there are overwritten on the next `setup.sh`.
