# Skill Routing Manifest — tagIN worked example
<!-- EXAMPLE ONLY. This is the routing that the packs in skills_archive/ were written for (tagIN
     platform: .NET 10 modular monolith, Next.js console + customer portal, Expo vendor app).
     Copy it to .specify/memory/skill-routing.md, then fix project names, surfaces and layouts against
     your real repo. Rows marked "verify" are assumptions carried over from the packs. -->

max_packs: 6

## Always
| Scope | Skill path(s) |
|---|---|
| design | .claude/skills/design-principles/SKILL.md |
| Backend | .claude/skills/backend-architecture/SKILL.md, .claude/skills/backend-feature-patterns/SKILL.md |
| Backend@review | .claude/skills/design-code-review/SKILL.md |
| Frontend | .claude/skills/frontend-design-system/SKILL.md, .claude/skills/react-component-patterns/SKILL.md, .claude/skills/accessibility-standards/SKILL.md |
| CustomerPortal | .claude/skills/nextjs-patterns/SKILL.md |
| Console | .claude/skills/react-admin-patterns/SKILL.md |
| VendorApp | .claude/skills/react-native-patterns/SKILL.md |

## By signal
| Signals | Skill path | Phases | Applies to |
|---|---|---|---|
| endpoint, api, http entry, openapi, bff, aggregation | .claude/skills/api-endpoint-patterns/SKILL.md | design, implement, review, refactor | Backend |
| messaging, events, queue, command, handler, publish, subscribe, outbox, saga, integration event, workflow, elsa, job, scheduled, recurring, cron, background, sla, timer | .claude/skills/orchestration-patterns/SKILL.md | design, implement, review, test, refactor | Backend |
| auth, authorization, role, policy, rbac, abac, permission, user context, resource ownership, audit identity | .claude/skills/authorization-patterns/SKILL.md | design, implement, review, test, refactor | Backend |
| authentication, jwt, bearer, oidc, keycloak, claim mapping, m2m, composition root, wiring, transport, dlq | .claude/skills/infrastructure-wiring/SKILL.md | design, implement, review, refactor | Backend |
| db, persistence, database, postgres, ef core, dapper, migration, schema, jsonb, postgis, repository, read model, rls, tenant isolation, concurrency | .claude/skills/data-access-patterns/SKILL.md | design, implement, review, test, perf, refactor | Backend |
| cache, caching, redis, hybrid cache, tag invalidation, distributed lock, rate limit | .claude/skills/caching-patterns/SKILL.md | design, implement, review, test, perf | Backend |
| search, elasticsearch, geo, full-text, reindex | .claude/skills/search-patterns/SKILL.md | design, implement, review, perf | Backend |
| file, upload, attachment, image, blob, storage, presigned, virus, scan, thumbnail | .claude/skills/file-pipeline-patterns/SKILL.md | design, implement, review | any |
| adapter, integration adapter, vendor api, external integration, delegatinghandler, typed httpclient, polly, resilience | .claude/skills/integration-adapter-patterns/SKILL.md | design, implement, review, test, refactor | Backend |
| feature flag, feature toggle, rollout, percentage rollout, a/b test, variant, gating, sunset | .claude/skills/feature-management-patterns/SKILL.md | design, implement, review, test, refactor | Backend |
| logging, tracing, metrics, telemetry, observability, serilog | .claude/skills/observability-backend/SKILL.md | implement, review, perf | Backend |
| telemetry, analytics, observability, posthog, sentry, web vitals, clarity | .claude/skills/observability-frontend/SKILL.md | design, implement, review | Frontend, Mobile |
| state, zustand, global state, shared state, store | .claude/skills/zustand-state-management/SKILL.md | design, implement, review | Frontend |

## Surfaces
| Surface | Project | Framework | Platform | E2E tooling |
|---|---|---|---|---|
| customer-portal | CustomerPortal | Next.js App Router | browser | Playwright |
| tagin-console | Console | Next.js + NextAuth (verify — react-admin-patterns still describes React + Vite) | browser | Playwright |
| vendor-app | VendorApp | React Native + Expo | native | Maestro |

## Migrations
| Project | Tool | Migration layout | Migration test layout |
|---|---|---|---|
| Backend.API | EF Core | src/backend/modules/{Module}/{Module}.Infrastructure/Persistence/Migrations/{timestamp}_{name}.cs (verify) | src/backend/tests/{Module}.IntegrationTests/Migrations/{name}Tests.cs (verify) |
