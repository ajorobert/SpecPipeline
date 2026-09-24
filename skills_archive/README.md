# skills_archive — capability pack starting points

This folder holds **capability packs**: stack and pattern skills that tell an agent how to write code
in one particular technology stack. They are **not part of the framework**.

- `setup.sh` never copies, reads, or lists anything in this folder.
- The framework's `sk.*` skills never name a pack. They load whatever a project registers in the
  `## Registry` table of its `.claude/skills/README.md` (see `.claude/skills/governance/pack-resolution.md`).
- Once copied into a project, a pack is owned by that project. Customise it freely; framework
  upgrades never touch it.

The packs here were written for one stack (.NET 10 modular monolith with a seam architecture,
Next.js web surfaces, React Native + Expo mobile). Treat them as worked examples, and as a quick
start when your stack matches.

## The rule: grammar vs vocabulary
- **Skills carry grammar**: the project-neutral how (patterns, invariants, review checks).
- **Project memory carries vocabulary**: the per-project what and where (module names, tenancy
  markers, permission catalog, schema names, cache-key prefixes, auth claim shapes).

A pack references vocabulary through a placeholder plus a pointer into the project's knowledge homes
(`specs/domain/`, `specs/adr/`, `.claude/rules/`). It never hardcodes it. When you customise a pack, keep facts in their homes and patterns in the pack.

## Contents

| Group | Pack | What it covers |
|---|---|---|
| backend | `backend-architecture` | Canonical backend SSOT: seam catalog, module structure, markers, event model, architecture-test invariants |
| backend | `backend-feature-patterns` | Handler shape, `Result<T>`/`Error`, command/query dispatch seam, validation, mapping, idempotency |
| backend | `api-endpoint-patterns` | HTTP entry points, OpenAPI, result → HTTP mapping, idempotency-key, BFF/aggregation |
| backend | `authorization-patterns` | User context, permission contract, RBAC/ABAC, predicate-scoped reads, audit identity |
| backend | `orchestration-patterns` | Sagas, long-running workflows, background jobs and the decision rule between them |
| backend | `integration-adapter-patterns` | Port/adapter split, typed HTTP clients, handler chain, resilience, idempotency-aware retry |
| backend | `feature-management-patterns` | Feature flags, filters, variants, flag naming and sunset discipline |
| backend | `infrastructure-wiring` | Composition root and seam implementations (rare-load: hosts and infrastructure only) |
| backend | `design-code-review` | Backend review checklist derived from `backend-architecture` |
| backend | `observability-backend` | What to emit: traces, logs, metrics, error sink, PII deny-list |
| data | `data-access-patterns` | Write path + read path, repositories, migrations, JSONB, geo, RLS, concurrency |
| data | `caching-patterns` | L1/L2 cache, tag invalidation, cross-instance coherence, escape hatches |
| data | `search-patterns` | Search index modelling, geo search, tenant isolation, event-driven indexing, reindex |
| data | `file-pipeline-patterns` | Object storage, image processing, virus scanning, saga-driven upload state machine |
| frontend | `nextjs-patterns` | Customer portal: App Router, auth sessions, CMS, image delivery |
| frontend | `react-admin-patterns` | Admin SPA: routing, loaders, query hooks, PKCE auth |
| frontend | `react-component-patterns` | Component decomposition, props, hooks, forms |
| frontend | `zustand-state-management` | Global/shared UI state |
| frontend | `frontend-design-system` (+ `design-styles.md`) | Tokens, component library, dark mode, design-style catalogue |
| frontend | `observability-frontend` | Client telemetry, error capture, analytics, consent gating |
| frontend | `accessibility-standards` | WCAG 2.2 AA rules and testing |
| mobile | `react-native-patterns` | Mobile app: routing, native styling, lists, secure storage, PKCE auth |
| design | `design-principles` | DDD bounded-context rules and DDIA access-pattern-first data modelling |
| memory | `auth_contract.md`, `observability-stack.md` | Examples of project vocabulary; in a project this content belongs in an ADR, a domain file or a rule file |
| — | `skills-registry.example.md` | The Registry table these packs were written for |

## Adopting a pack

```bash
# 1. Copy the packs you want (flat, keep the folder name)
cp -r .speckit/skills_archive/backend/backend-architecture .claude/skills/
cp -r .speckit/skills_archive/design/design-principles    .claude/skills/

# 2. Rewrite the vocabulary the packs point at into your own homes
#    (identity shapes → an ADR or specs/domain/{module}.md; telemetry wiring → .claude/rules/backend/)

# 3. Register the packs: add rows to the ## Registry table of .claude/skills/README.md
#    (skills-registry.example.md shows the table these packs were written for)
```

Then customise:
- Replace library names, versions and paths with your real ones.
- Move any project fact you find in a pack into its home (ADR, domain file, rule file) and leave a pointer behind.
- Optionally add native `paths:` frontmatter so Claude Code also surfaces the pack by file context
  outside the sk.* workflow.

## Adding a pack here
Only add packs that are reusable as a starting point. Keep project facts out of them (placeholders
plus pointers), and add a row to the table above and to `skills-registry.example.md`.
