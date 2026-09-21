---
name: backend-architecture
description: "Load when: implementing or reviewing ANY backend feature. The canonical source for the seam catalog, building-blocks + module structure, Contracts primitives, the comment-marker index, the domain/integration event model, and the NetArchTest invariants. Every backend pattern skill references this — it never restates them."
---

# Backend Architecture (canonical)

This is the **single source of truth** for backend structure and invariants. Pattern skills
(`backend-feature-patterns`, `api-endpoint-patterns`, `data-access-patterns`, `caching-patterns`,
`search-patterns`, `authorization-patterns`, `orchestration-patterns`, `file-pipeline-patterns`,
`integration-adapter-patterns`, `feature-management-patterns`, `observability-backend`) and the
review skill (`design-code-review`) **reference** this file; they do not restate it. When a rule
here changes, it changes in one place.

**Code targets seams, never the backing library.** Swap the library → the seam holds. The library
name is an implementation detail confined to `BuildingBlocks.Infrastructure` and the wiring covered
by `infrastructure-wiring`. No feature code names Wolverine / EF / Redis / Keycloak types directly.

---

## 1. Skills carry grammar, project memory carries vocabulary

Test for any token you are about to write into a skill OR generated code:
*"Would this be byte-identical in a different SaaS built on this framework?"*

- **Yes → it's a pattern.** Framework seam types (`IAppCommandBus`, `Result<T>`, `IIntegrationEvent`,
  `StronglyTypedId`), the marker grammar (`// AUTH:`), the invariant shapes. These are named here.
- **No → it's a project fact.** The bounded-context names, the tenancy scope-marker names
  (e.g. `IOrgScoped`), the concrete IDs (`ListingId`), the permission catalog, schema names, the
  cache-key prefix, the RLS tenant column. These live in `.specify/memory/` and the `authorization/`
  catalog; skills reference them through the `YourContext.*` placeholder + a memory pointer.

Pointers: context/module names → `.specify/memory/system-context.md`; auth shapes → `.specify/memory/auth_contract.md`;
permission catalog → the repo's `authorization/` folder.

---

## 2. Seam catalog

Every seam hides one library. Feature code depends on the **Seam** column; the **Hides** column is the implementation detail.

| Seam | Hides | Rule |
|---|---|---|
| `IAppCommandBus.Send` / `IAppQueryBus.Execute` | Wolverine | All dispatch. Owns idempotency replay + query-cache short-circuit; turns pipeline failures into `Result`. Never inject Wolverine `IMessageBus`/`IMessageContext` into a module. |
| `Result<T>` / `Error` | exceptions across boundaries | Boundary methods return `Result`; they do not throw for expected failures. |
| Repository interfaces (`I…WriteRepository`, `I…ReadService`) | EF Core (writes) / Dapper (reads) | Application declares the interface; `Infrastructure` implements it. |
| Domain events / Integration events | in-process (same txn) vs cross-module (outbox, eventual) | See §6. |
| `HybridCache` + caching behavior | Redis L2 | Read-through + tag invalidation; see `caching-patterns`. |
| `IUserContext` | Keycloak / `ClaimsPrincipal` | The only identity surface a handler sees; see §5 + `authorization-patterns`. |

---

## 3. building-blocks — one-way dependency chain

Shared kernel. Each layer depends only on the ones to its left:

```
Contracts → Application → Domain → Infrastructure → Testing
```

- **`BuildingBlocks.Contracts`** — lingua franca, zero infra deps. `ICommand<TResult>` / `IQuery<TResult>`,
  `Result` / `Result<T>` + `Error`, `StronglyTypedId`, paging, authz scope-marker base + `RequiresPermissionAttribute` /
  `RunsAsAttribute`, `IIntegrationEvent`, `SensitiveAttribute`.
- **`BuildingBlocks.Application`** — the dispatch seam: `IAppCommandBus` / `IAppQueryBus`, plus pipeline behaviors
  (validation, caching, idempotency, domain-event collection, erasure, observability).
- **`BuildingBlocks.Domain`** — base aggregate/entity, auditing, authorization primitives.
- **`BuildingBlocks.Infrastructure`** — **the only place Wolverine lives** (`Wolverine/ApplicationBus.cs` + middleware),
  persistence base, identity, validation runners. Covered by `infrastructure-wiring`.
- **`BuildingBlocks.Testing`** — shared test kit.

---

## 4. Module — the 4-project clean-architecture slice

A bounded context (`modules/<context>/`) is exactly four projects. Placeholder namespace `YourContext.*`
(substitute the real context name from `system-context.md`):

| Project | Contains | Public? |
|---|---|---|
| `YourContext.Contracts` | `Commands/ Queries/ Dtos/ IntegrationEvents/ Permissions/` | **The module's only public surface.** Other modules reference this and nothing else. |
| `YourContext.Domain` | `Aggregates/ Events/ ValueObjects/ Repositories/ Exceptions/` | no |
| `YourContext.Application` | `Handlers/ DomainEventHandlers/ Validators/ Jobs/ Workflows/ Abstractions/` | no |
| `YourContext.Infrastructure` | `Persistence/ ExternalServices/ BackgroundServices/` | no |

Composition roots (`hosts/Api`, `hosts/Worker`) wire everything; see `infrastructure-wiring`.

---

## 5. Contracts primitives — the pattern, not the instances

Teach the **framework-stable base types** and the **categories**. Do **not** enumerate project-specific
instance names — those are declared in memory / the `authorization/` catalog.

- **Strongly-typed IDs.** Every aggregate identifier is a `StronglyTypedId` (`readonly record struct …Id(Guid Value)`),
  never a bare `Guid` on a contract. The *set* of IDs (`ListingId`, `VendorId`, …) is project vocabulary.
- **Authz scope markers.** Every command/query contract carries a scope marker interface declaring its tenancy
  dimension (the framework requires *a* marker; the *names* — e.g. an org-scoped or vendor-owned marker — are
  declared in `.specify/memory/` and live in `BuildingBlocks.Contracts`/`authorization/`). Used by the dispatch
  pipeline + RLS to scope every operation.
- **Permission contract.** `[RequiresPermission("<permission>")]` on a command/query/endpoint; `[RunsAs(<principal>)]`
  for system-initiated work. The attribute *mechanism* is framework; the *permission catalog* is project data in
  `authorization/`. See `authorization-patterns`.
- **`IIntegrationEvent`** — marker for cross-module events (see §6). **`[Sensitive]`** — marks PII fields for the
  observability deny-list (see `observability-backend`).
- **`IUserContext`** — the canonical identity seam injected into handlers that need identity:
  `UserId`, `TenantId`, `Roles`, `Permissions`, `HasPermission(...)`. Implementation maps Keycloak claims in
  `infrastructure-wiring`; handlers and audit logs read only this interface.

---

## 6. The domain / integration event model (the critical rule)

A handler **never references Wolverine** to publish. The flow:

1. The handler mutates an aggregate; the **aggregate raises domain events** (`RaiseEvent(...)`).
2. A **command pipeline behavior** in `BuildingBlocks.Application` runs the handler inside a transaction,
   then flushes raised domain events: in-process domain-event handlers run in the **same transaction**;
   any mapped **integration events** (`IIntegrationEvent`) are written to the **EF-Core outbox** in that same
   transaction. The `IAppCommandBus` impl (`infrastructure-wiring`) owns the Wolverine + outbox machinery.
3. The relay publishes outbox rows after commit — eventual, at-least-once, cross-module.

> **Outbox invariant (single home).** State change + event publication commit atomically via the outbox.
> Never dual-write (mutate state then publish directly) — a crash between the two loses the event or leads
> observers ahead of truth. This is enforced by NetArchTest invariant #1 + #3 (§8). `data-access-patterns`,
> `orchestration-patterns`, and `file-pipeline-patterns` reference this rule; they do not restate it.

| Kind | Scope | Handlers | Delivery |
|---|---|---|---|
| Domain event (`*Event`) | same module, same transaction | 0..n in-process | synchronous, exactly-once-in-txn |
| Integration event (`*IntegrationEvent`, in `Contracts`) | cross-module | 0..n across modules | outbox → broker, eventual, at-least-once (consumers idempotent) |

Integration-event naming: `<Aggregate><PastTenseVerb>IntegrationEvent`. Versioning is additive; a breaking change is a new `…V2` type.

---

## 7. Comment-marker index (canonical home)

Markers are CI-greppable. Each owner skill emits and documents its own; **this table is the only cross-skill registry.**

| Marker | Owner skill | Annotates |
|---|---|---|
| `// AUTH:` | api-endpoint-patterns | Endpoint authorization policy / permission |
| `// ENDPOINT:` | api-endpoint-patterns | Endpoint route + verb |
| `// OUTBOX:` | backend-architecture (rule) / emitted in handlers | Outbox-bound integration event |
| `// SAGA-STATE:` | orchestration-patterns | Saga state field |
| `// ACTIVITY-INPUT:` | orchestration-patterns | Elsa activity input binding |
| `// CRON:` | orchestration-patterns | Recurring job schedule |
| `// JOB-IDEMPOTENT:` | orchestration-patterns | Recurring-job dedup site |
| `// CACHE-TAG:` | caching-patterns | Cache tag(s) for an entry |
| `// CACHE-INVALIDATE:` | caching-patterns | Cache invalidation call |
| `// MAP:` | backend-feature-patterns | Mapperly custom mapping |
| `// IDEMPOTENCY:` | backend-feature-patterns | HTTP idempotency dedup check |
| `// INDEX:` | search-patterns | Search index write |
| `// GEO:` | search-patterns | Geo query |
| `// PORT-IMPL:` `// RESILIENCE:` `// HANDLER-ORDER:` | integration-adapter-patterns | Adapter port impl / resilience / handler chain order |
| `// FLAG:` `// SUNSET:` | feature-management-patterns | Feature flag / sunset date |
| `// LOG:` `// SPAN:` `// METRIC:` `// SENSITIVE:` | observability-backend | Telemetry emission / PII field |
| `// UPLOAD-STATE:` `// BUCKET:` | file-pipeline-patterns | Upload state / storage bucket |
| `// CONFIGUREAWAIT:` | backend-architecture (rule below) | Library/adapter line that keeps `ConfigureAwait(false)` |

**`// CONFIGUREAWAIT:` rule (single home).** Module handlers omit `ConfigureAwait(false)` — the bus controls the
synchronization context. Only library/adapter code (`*.Infrastructure` ports, shared utilities) uses
`ConfigureAwait(false)`, marked once near the top of the file. No other skill restates this.

---

## 8. NetArchTest invariants (mechanical enforcement)

Prose drifts; tests do not. The `tests/Architecture` project (NetArchTest + xUnit) encodes these. `design-code-review`
checks them rather than re-deriving rules:

1. **Dispatch seam.** No type in any `*.Application` or `*.Api` references Wolverine `IMessageBus`/`IMessageContext`
   or carries `[Transactional]`. Dispatch is only `IAppCommandBus`/`IAppQueryBus`.
2. **Module encapsulation.** A module references another module **only** through its `*.Contracts` — never its
   `Domain`/`Application`/`Infrastructure`.
3. **Result at boundaries.** Public handler/endpoint methods return `Result`/`Result<T>`; boundaries do not throw for
   expected failures.
4. **Contract markers.** Every `ICommand`/`IQuery` carries a `StronglyTypedId`-typed identifier and an authz scope
   marker; mutating commands and protected queries carry `[RequiresPermission]` (or `[RunsAs]` for system principals).
   The test reads the project's *declared* marker/permission set from `authorization/` — the pattern is fixed, the
   catalog is project vocabulary.

---

## 9. Tech-per-edge (library = implementation detail)

The chosen implementation behind each seam/edge. Named here once so pattern skills need not repeat the stack.

| Edge / seam | Library | Skill that uses it |
|---|---|---|
| HTTP | FastEndpoints + Scalar | api-endpoint-patterns |
| Validation | FluentValidation | backend-feature-patterns |
| Mapping | Mapperly (source-gen) | backend-feature-patterns |
| Dispatch / outbox / messaging | Wolverine | infrastructure-wiring (impl); seam in §2/§6 |
| Write DB | EF Core, PostgreSQL, schema-per-context | data-access-patterns / infrastructure-wiring |
| Read DB | Dapper | data-access-patterns |
| Search | Elasticsearch | search-patterns |
| Cache | HybridCache + Redis | caching-patterns / infrastructure-wiring |
| Jobs / workflow | Hangfire + Elsa v3 | orchestration-patterns |
| Files | SeaweedFS + ImageSharp + nClam | file-pipeline-patterns |
| AuthN | Keycloak (OIDC/MFA) | infrastructure-wiring; usage in authorization-patterns |
| AuthZ | custom permission catalog (`authorization/` + Contracts markers) | authorization-patterns |
| Observability | Serilog + OTel + Sentry→GlitchTip | observability-backend |
| Feature flags | Microsoft.FeatureManagement | feature-management-patterns |
| Runtime / tests | .NET 10, central package mgmt; xUnit + Shouldly + NetArchTest | — |

---

## 10. Placeholder convention

- `BuildingBlocks.{Contracts,Application,Domain,Infrastructure,Testing}` — the shared kernel (stable name).
- `YourContext.{Contracts,Domain,Application,Infrastructure}` — one module's 4-project slice; substitute the real
  context name at code-gen time from `.specify/memory/system-context.md`.
- Metric / log identifiers use `directory.*` (project label) or `your-service` (URL slugs) — see `observability-backend`.
- Cache keys, schema names, scope-marker names, permission strings, RLS column — **project vocabulary**, from memory /
  `authorization/`, never hardcoded in a skill.
