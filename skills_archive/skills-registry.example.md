# Project skills — worked example
<!-- EXAMPLE ONLY. The registry the packs in skills_archive/ were written for (.NET modular monolith,
     Next.js console + customer portal, Expo vendor app). Copy the table into the `## Registry` section of
     your .claude/skills/README.md, keep only the skills you copied, and fix project names against
     .specify/memory/projects/index.md. Surfaces and migration layouts are not registry rows: they live in
     each project's .specify/memory/projects/{Project}/tech-stack.md (Platform, E2E Tooling, Migrations). -->

## Registry
| Skill | Status | Defers to | Always | Signals | Phases | Applies to | Weight |
|---|---|---|---|---|---|---|---|
| `design-principles` | active | — | design | — | design | any | 1 |
| `backend-architecture` | active | — | Backend | — | — | Backend | 1 |
| `backend-feature-patterns` | active | `backend-architecture` | Backend | — | — | Backend | 1 |
| `design-code-review` | active | `backend-architecture` | Backend@review | — | review | Backend | 1 |
| `api-endpoint-patterns` | active | `backend-architecture` | — | endpoint, api, http entry, openapi, bff, aggregation | design, implement, review | Backend | 1 |
| `orchestration-patterns` | active | `backend-architecture` | — | messaging, events, queue, command, handler, publish, subscribe, outbox, saga, integration event, workflow, job, scheduled, recurring, cron, background, sla, timer | design, implement, review, test | Backend | 1 |
| `authorization-patterns` | active | `backend-architecture` | — | authorization, role, policy, rbac, abac, permission, user context, resource ownership, audit identity | design, implement, review, test | Backend | 2 |
| `infrastructure-wiring` | active | `backend-architecture` | — | authentication, jwt, bearer, oidc, claim mapping, m2m, composition root, wiring, transport, dlq | design, implement, review | Backend | 1 |
| `data-access-patterns` | active | `backend-architecture` | — | db, persistence, database, postgres, ef core, dapper, migration, schema, jsonb, postgis, repository, read model, rls, tenant isolation, concurrency | design, implement, review, test | Backend | 1 |
| `caching-patterns` | active | `data-access-patterns` | — | cache, caching, redis, hybrid cache, tag invalidation, distributed lock, rate limit | design, implement, review, test | Backend | 1 |
| `file-pipeline-patterns` | active | — | — | file, upload, attachment, image, blob, storage, presigned, virus, scan, thumbnail | design, implement, review | any | 1 |
| `integration-adapter-patterns` | active | `backend-architecture` | — | adapter, integration adapter, vendor api, external integration, delegatinghandler, typed httpclient, polly, resilience | design, implement, review, test | Backend | 1 |
| `feature-management-patterns` | active | — | — | feature flag, feature toggle, rollout, percentage rollout, a/b test, variant, gating, sunset | design, implement, review, test | Backend | 1 |
| `observability-backend` | active | — | — | logging, tracing, metrics, telemetry, observability, serilog | implement, review | Backend | 1 |
| `frontend-design-system` | active | — | Frontend | — | — | Frontend | 1 |
| `react-component-patterns` | active | `frontend-design-system` | Frontend | — | — | Frontend | 1 |
| `accessibility-standards` | active | — | Frontend | — | — | Frontend | 1 |
| `nextjs-patterns` | active | `react-component-patterns` | CustomerPortal, Console | — | — | Frontend | 1 |
| `react-native-patterns` | active | — | VendorApp | — | — | Mobile | 1 |
| `observability-frontend` | active | — | — | telemetry, analytics, observability, posthog, sentry, web vitals, clarity | design, implement, review | Frontend, Mobile | 1 |
| `zustand-state-management` | active | `react-component-patterns` | — | state, zustand, global state, shared state, store | design, implement, review | Frontend | 1 |
