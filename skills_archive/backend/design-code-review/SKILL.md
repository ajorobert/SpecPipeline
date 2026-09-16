---
name: design-code-review
description: "Load when: reviewing C# .NET 10 backend code. Thin review checklist that DERIVES its architecture checks from backend-architecture markers + NetArchTest invariants (it does not restate them), plus stack-neutral async/security/SOLID/testability checks."
co_loads_with:
  - backend-architecture (canonical seams, structure, markers, events model, invariants — the gate this skill checks against)
  - backend-feature-patterns (handler/command/query/mapping shape — the per-feature application of the canonical)
---

# Backend Code Review (derived)

## 1. Purpose

Read-only review of C# .NET 10 backend code. **Produces findings; never modifies code.**

This skill is a **thin checklist**. It does **not** restate architecture rules — it derives every
architecture check from the canonical (`backend-architecture`) and the per-feature shape
(`backend-feature-patterns`). When the canonical changes, this checklist follows automatically because it
points at the canonical rather than copying it. The reviewer's job: confirm code matches what those skills
generate, and flag where it does not.

---

## 2. Architecture & seam checks (DERIVED — point at the canonical, do not re-argue)

### (a) The 4 NetArchTest invariants hold — `backend-architecture §8`

`tests/Architecture` (NetArchTest + xUnit) mechanically encodes these. **If those tests exist, they are the
gate** — the reviewer flags anything the tests would catch (and flags the *absence* of the test project as
itself a finding). The four:

1. **Dispatch seam.** No type in any `*.Application` or `*.Api` references Wolverine `IMessageBus` /
   `IMessageContext`, and none carries `[Transactional]`. All dispatch goes through
   `IAppCommandBus` / `IAppQueryBus`.
2. **Module encapsulation.** A module references another module **only** through its `*.Contracts` —
   never its `Domain` / `Application` / `Infrastructure`.
3. **Result at boundaries.** Public handler/endpoint methods return `Result` / `Result<T>`; boundaries do
   not throw for expected failures.
4. **Contract markers.** Every `ICommand` / `IQuery` carries a `StronglyTypedId`-typed identifier **and** an
   authz scope marker; mutating commands and protected queries carry `[RequiresPermission]`
   (or `[RunsAs]` for system principals). The marker/permission *catalog* is project vocabulary in
   `authorization/` — the *shape* is fixed.

### (b) Comment markers present where required — `backend-architecture §7`

Markers are CI-greppable; their absence at a required site is a finding. Spot-check the §7 index, including:

- Endpoints carry `// ENDPOINT:` (route + verb) **and** `// AUTH:` (authorization policy / permission).
- Integration-event emission sites carry `// OUTBOX:`.
- Cached reads carry `// CACHE-TAG:`; invalidation sites carry `// CACHE-INVALIDATE:`.
- Mapperly custom mappings carry `// MAP:`; HTTP idempotency dedup sites carry `// IDEMPOTENCY:`.
- `// CONFIGUREAWAIT:` appears **only** on library/adapter lines (`*.Infrastructure`, shared utilities) —
  never in module handlers (§7 `// CONFIGUREAWAIT:` rule).

(Full owner table in §7 — do not duplicate it here; consult it.)

### (c) Seam-usage spot checks — `backend-feature-patterns §3–8`, `backend-architecture §2/§6`

| Check | Derived from | Looks like a failure when |
|---|---|---|
| Command handler is a **plain class** returning `Result` / `Result<T>` and **raises** domain events | feat §3, arch §6 | handler injects a bus, carries `[Transactional]`, opens a transaction, or publishes events itself |
| Integration events emitted from a **`DomainEventHandler`** that **returns** `IIntegrationEvent`(s) | feat §4, arch §6 | integration event published directly from the command handler (dual-write — arch §6 outbox invariant) |
| Mapping via a Mapperly **`[Mapper]` partial** | feat §8 | hand-written property copies or reflection mapping in the handler |
| Query handlers cache-wrap via the **HybridCache seam** (`GetOrCreateAsync`) | feat §5, caching | query touches the write path, or caches inside a command handler |
| Identity read **only** via `IUserContext` | arch §5, authorization-patterns | handler reads `ClaimsPrincipal` / Keycloak types, or threads raw claims |

---

## 3. Stack-neutral checks (KEEP — not stack-specific)

### Async correctness (.NET 10)
- No `.Result`, `.Wait()`, or `.GetAwaiter().GetResult()` — deadlock / sync-over-async risk.
- No `async void` except unavoidable event handlers.
- No `Task.Run` wrapping I/O-bound work.
- `CancellationToken` accepted and forwarded through every async call in the chain.

### Security
- No hardcoded secrets, credentials, or connection strings.
- Input validation present (FluentValidation validator next to the command — `backend-feature-patterns §7`).
- Parameterised SQL only — no string concatenation / interpolation into queries.
- No secrets / tokens / PII in log output (mark PII with `[Sensitive]` — `observability-backend`).
- Authorization checked **before** the domain operation, not only at the route — and via the contract markers
  (§2a invariant 4), not ad-hoc branches.

### SOLID / maintainability smells
- **SRP:** one reason to change per class; flag classes spanning multiple concerns.
- **ISP:** narrow interfaces; flag interfaces with 5+ methods or repositories mixing write + projection methods.
- Method length > 30 lines → extract.
- More than 3 constructor parameters → group related dependencies.
- Anemic aggregates: `if (entity.Status == X)` business branches in handlers belong on the aggregate
  (`backend-feature-patterns §11`).

### Testability
- All dependencies constructor-injected — no `new` for services, no static service-locator calls.
- No static mutable state.
- Handlers unit-testable with fake repositories + `FakeUserContext` (`backend-feature-patterns §12`).

---

## 4. Blocking vs advisory

**Blocking (must fix before ship):**
- Any of the 4 NetArchTest invariants violated (§2a) — or the `tests/Architecture` project absent.
- A required comment marker missing at its site (§2b) — e.g. an endpoint with no `// AUTH:`, an integration
  event with no `// OUTBOX:`.
- Integration event published from a command handler / any dual-write of state + event (arch §6 outbox invariant).
- Bus injected or `[Transactional]` on a handler; identity read from `ClaimsPrincipal` instead of `IUserContext`.
- Boundary method throwing for an expected failure instead of returning `Result`.
- Blocking async (`.Result` / `.Wait()` / `.GetAwaiter().GetResult()`) in an async path.
- Hardcoded secret / connection string; missing input validation on a public entry point; non-parameterised SQL;
  PII/secret in logs.

**Advisory (flag and recommend):**
- Method > 30 lines; > 3 constructor parameters; interface with 5+ methods.
- Missing `CancellationToken` propagation on a non-boundary async method.
- `catch (Exception)` without re-throw or structured logging.
- Missing XML docs on public contracts / DTOs.

---

## 5. Examples — CORRECT vs INCORRECT (real stack)

### Correct — plain Wolverine-discovered handler, returns Result, raises a domain event
```csharp
// ✅ plain class (no bus, no [Transactional]); returns Result; aggregate raises the event
public sealed class ActivateListingHandler(IListingsRepository repo)
{
    public async Task<Result> Handle(ActivateListingCommand cmd, CancellationToken ct)
    {
        var listing = await repo.GetByIdAsync(cmd.ListingId, ct);
        if (listing.IsError) return listing.Errors;

        var activated = listing.Value.Activate();   // raises ListingActivatedEvent on success
        if (activated.IsError) return activated.Errors;

        await repo.SaveChangesAsync(ct);             // pipeline commits state + outbox atomically
        return Result.Success;
    }
}
```

### Incorrect — handler injects a bus and dual-writes the event
```csharp
// ❌ bus injected into the module (invariant #1); event published directly from the handler
//    (arch §6 outbox invariant — state + event must commit via the outbox, not dual-written)
public sealed class ActivateListingHandler(IListingsRepository repo, IMessageBus bus)
{
    public async Task<Result> Handle(ActivateListingCommand cmd, CancellationToken ct)
    {
        var listing = await repo.GetByIdAsync(cmd.ListingId, ct);
        listing.Value.Activate();
        await repo.SaveChangesAsync(ct);
        await bus.PublishAsync(new ListingActivatedIntegrationEvent(cmd.ListingId.Value)); // dual-write
        return Result.Success;
    }
}
```
Integration events belong in a `DomainEventHandler` that **returns** `IIntegrationEvent`(s)
(`backend-feature-patterns §4`).

### Correct — endpoint dispatches through the command-bus seam
```csharp
// ENDPOINT: POST /listings/{id}/activate
// AUTH: requires listings:activate
public sealed class ActivateListingEndpoint(IAppCommandBus bus) : Endpoint<ActivateListingRequest>
{
    public override async Task HandleAsync(ActivateListingRequest req, CancellationToken ct)
    {
        Result result = await bus.Send(new ActivateListingCommand(new ListingId(req.Id), req.IdempotencyKey), ct);
        await this.SendResultAsync(result, ct);   // Result → HTTP per api-endpoint-patterns
    }
}
```

### Incorrect — business logic + direct DB + ad-hoc auth in the endpoint
```csharp
// ❌ direct DbContext, identity branch, and domain mutation in the entry point — no seam, no Result
public override async Task HandleAsync(ActivateListingRequest req, CancellationToken ct)
{
    var listing = await _db.Listings.FindAsync(req.Id);            // direct DB access
    if (listing.OwnerId != User.GetId()) { await SendForbiddenAsync(ct); return; } // ad-hoc auth, ClaimsPrincipal
    listing.Status = ListingStatus.Active;                        // domain mutation in endpoint
    await _db.SaveChangesAsync(ct);
}
```

---

## 6. When to use / NOT to use

**Use for:**
- Any backend C# review touching `*.Domain` / `*.Application` / `*.Infrastructure` / `*.Api`.
- Pre-merge PR review and architecture audits of an existing service.

**Do NOT use for:**
- Frontend review (see `react-component-patterns`, `nextjs-patterns`).
- Infrastructure scripts / Terraform / Bicep.
- Database migration review (see `data-access-patterns`).
