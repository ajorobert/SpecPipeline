---
name: backend-feature-patterns
description: |
  Backend feature implementation pattern for .NET 10 Clean Architecture with the IAppCommandBus/IAppQueryBus dispatch seam, Result<T>/Error, Mapperly, FluentValidation. Covers layer boundaries, command/query handler shape, the domain-event → integration-event flow, validation pipeline, idempotency, and Mapperly mapping. Use for every backend feature that touches business logic.
when_to_load:
  - Task mentions: feature, handler, command, query, application layer, domain, mapping, validation, idempotency
  - Files touched: any *Handler.cs, *Command.cs, *Query.cs, *Validator.cs, *Mapper.cs, aggregate roots
co_loads_with:
  - backend-architecture (canonical seams, structure, markers, events model — read first)
  - api-endpoint-patterns (HTTP entry to handlers)
  - data-access-patterns (EF write + Dapper read inside handlers)
  - caching-patterns (cache-aside in query handlers)
---

# Backend Feature Patterns

Read `backend-architecture` first — it owns the seam catalog, the building-blocks/module structure,
the comment-marker index, the domain/integration event model, and the NetArchTest invariants. This
skill applies them to a single feature.

## 1. Where a feature lives

One use case = one folder under the module's Application project (`YourContext.Application/Handlers/<Aggregate>/<UseCase>/`):

```
Command.cs     // record : ICommand<TResult>
Handler.cs     // plain class — no bus, no [Transactional]
Validator.cs   // : AbstractValidator<Command>
Mapper.cs      // optional [Mapper] partial (Mapperly)
```

Layer dependencies and the ban table are in `backend-architecture §3–4`. The rule that matters most here:
**the handler depends on seams, never on a library** — no `DbContext`, no Wolverine `IMessageBus`/`IMessageContext`,
no `HybridCache` internals beyond the documented seam.

## 2. Domain rules

- Aggregate root: private setters, factory method, invariants checked in the factory/constructor.
- State-mutating methods return `Result` / `Result<T>` for expected refusals; they **raise domain events** for
  things that happened (`RaiseEvent(...)`). They do not throw for business failures.
- Allowed dependencies inside Domain: only port interfaces declared in Domain (e.g. `IClock`, `IIdGenerator`).
  Never inject `DbContext`, a bus, a cache, `HttpClient`, `IConfiguration`, or logger types into entities.
- Identifiers are `StronglyTypedId`s (`backend-architecture §5`).

```csharp
namespace YourContext.Domain.Listings;

public sealed class Listing : AggregateRoot
{
    public ListingId Id { get; }
    public OwnerId OwnerId { get; }
    public ListingStatus Status { get; private set; }
    public Money Price { get; private set; }

    private Listing(ListingId id, OwnerId owner, Money price)
    { Id = id; OwnerId = owner; Price = price; Status = ListingStatus.Draft; }

    public static Result<Listing> Create(OwnerId owner, Money price)
    {
        if (price.Amount <= 0) return Error.Validation("Listing.PriceInvalid", "Price must be > 0");
        var l = new Listing(ListingId.New(), owner, price);
        l.RaiseEvent(new ListingCreatedEvent(l.Id, owner));
        return l;
    }

    public Result Activate()
    {
        if (Status != ListingStatus.Draft)
            return Error.Conflict("Listing.AlreadyActive", "Listing is already active");
        Status = ListingStatus.Active;
        RaiseEvent(new ListingActivatedEvent(Id));   // domain event — promoted to integration event in §4
        return Result.Success;
    }
}
```

## 3. Command handler shape

A command handler is a **plain class**. It loads an aggregate through a write-repository interface, calls a
domain method, persists, and returns `Result<T>`. It does **not** open a transaction and does **not** publish —
the command pipeline behavior in `BuildingBlocks.Application` wraps the handler in a transaction and flushes the
outbox (`backend-architecture §6`).

- Return type is `Result` / `Result<T>` — **never throw for business failures**.
- MAY inject: write/read repository interfaces, ports, the Mapperly mapper, `IUserContext`, `HybridCache`.
- MUST NOT inject: `DbContext`, Wolverine `IMessageBus`/`IMessageContext`. MUST NOT carry `[Transactional]`.
- MUST NOT catch exceptions to convert them to errors — unexpected exceptions are the pipeline's job.

```csharp
namespace YourContext.Application.Handlers.Listings.Activate;

public sealed record ActivateListingCommand(ListingId ListingId, Guid ActorId, string? IdempotencyKey = null)
    : ICommand<Result>, IVendorOwned;   // scope marker per backend-architecture §5 — name is project vocabulary

public sealed class ActivateListingHandler(IListingsRepository repo)
{
    public async Task<Result> Handle(ActivateListingCommand cmd, CancellationToken ct)
    {
        var listing = await repo.GetByIdAsync(cmd.ListingId, ct);
        if (listing.IsError) return listing.Errors;

        var activated = listing.Value.Activate();        // raises ListingActivatedEvent on success
        if (activated.IsError) return activated.Errors;

        await repo.SaveChangesAsync(ct);                 // pipeline commits this + outbox atomically
        return Result.Success;
    }
}

public sealed class ActivateListingValidator : AbstractValidator<ActivateListingCommand>
{
    public ActivateListingValidator() => RuleFor(x => x.ListingId).NotEmpty();
}
```

## 4. Domain event → integration event

Cross-module notification never happens by injecting a bus into the handler. The aggregate raises a **domain
event**; a `DomainEventHandler` reacts and **returns** the integration event(s) — pure return values, no bus
reference. The pipeline writes returned `IIntegrationEvent`s to the EF outbox inside the same transaction
(`backend-architecture §6`). Same-transaction in-process side effects are also done here.

```csharp
namespace YourContext.Application.DomainEventHandlers.Listings;

public sealed class OnListingActivated
{
    // OUTBOX: returned integration events are written to the outbox in the command's transaction
    public IEnumerable<IIntegrationEvent> Handle(ListingActivatedEvent e)
    {
        yield return new ListingActivatedIntegrationEvent(e.ListingId.Value);   // lives in YourContext.Contracts
    }
}
```

Integration-event type + naming + versioning: `backend-architecture §6`. Consumers are idempotent.

## 5. Query handler shape

Query handlers read through a Dapper-backed read service and cache-wrap with `HybridCache.GetOrCreateAsync`
(see `data-access-patterns` and `caching-patterns`). They return `Result<TDto>` and never touch the write path.

```csharp
namespace YourContext.Application.Handlers.Listings.GetDetail;

public sealed record GetListingDetailQuery(ListingId ListingId) : IQuery<Result<ListingDetailDto>>, IVendorOwned;

public sealed class GetListingDetailHandler(HybridCache cache, IListingsReadService reads)
{
    private static readonly HybridCacheEntryOptions Options =
        new() { Expiration = TimeSpan.FromMinutes(5), LocalCacheExpiration = TimeSpan.FromMinutes(1) };

    public async Task<Result<ListingDetailDto>> Handle(GetListingDetailQuery q, CancellationToken ct)
    {
        // CACHE-TAG: <prefix>:listing — see caching-patterns; prefix is project vocabulary
        var dto = await cache.GetOrCreateAsync(
            $"{CacheKeys.Listing(q.ListingId)}:detail",
            token => reads.GetDetailAsync(q.ListingId, token).AsTask(),
            Options,
            tags: [CacheKeys.ListingTag],
            cancellationToken: ct);

        return dto is null ? Error.NotFound("Listing.NotFound", "Listing not found") : dto;
    }
}
```

## 6. Result / Error contract

`Result` / `Result<T>` (from `BuildingBlocks.Contracts`) is the only boundary return shape. Exceptions are for
programmer errors and impossible states only. The five `Error` kinds and their HTTP projection:

| Kind | Use for | HTTP (api-endpoint-patterns) |
|---|---|---|
| `Error.Validation(code, desc)` | input shape, ranges, format | 400 |
| `Error.NotFound(code, desc)` | identifier resolves to nothing | 404 |
| `Error.Conflict(code, desc)` | state-machine refusal, optimistic-concurrency clash | 409 |
| `Error.Forbidden(code, desc)` | authenticated caller lacks the right | 403 |
| `Error.Failure(code, desc)` | genuine infra/unexpected, but caught | 500 |

Code convention: `<Aggregate>.<Symbol>` (e.g. `Listing.AlreadyActive`); ASCII description. Construct errors in the
aggregate (factories/state methods) and thread them in the handler with `.Then` / `.Match` rather than `if (x.IsError) return` ladders when the chain exceeds two steps.

```csharp
public async Task<Result<Guid>> Handle(CreateListingCommand cmd, CancellationToken ct)
{
    return await Money.Create(cmd.Amount, cmd.Currency)                  // Result<Money>
        .Then(m => Listing.Create(new OwnerId(cmd.OwnerId), m))          // Result<Listing>
        .ThenAsync(async listing =>
        {
            await repo.AddAsync(listing, ct);
            await repo.SaveChangesAsync(ct);
            return listing.Id.Value;
        });
}
```

## 7. FluentValidation

The validator lives next to the command. The validation pipeline behavior (`BuildingBlocks.Application`)
auto-discovers validators by assembly scan and runs them **before** the handler; failures short-circuit to
`Error.Validation` — the handler never calls the validator.

- **Per-property** rules (`NotEmpty`, `MaximumLength`, `Matches`) on `RuleFor(x => x.Field)`.
- **Cross-field** rules on `RuleFor(x => x)` with a custom predicate + `.WithErrorCode("<Aggregate>.<Symbol>")`.

```csharp
public sealed class CreateBookingValidator : AbstractValidator<CreateBookingCommand>
{
    public CreateBookingValidator()
    {
        RuleFor(x => x.StartsAt).NotEmpty();
        RuleFor(x => x.EndsAt).NotEmpty();
        RuleFor(x => x).Must(c => c.EndsAt > c.StartsAt)
            .WithMessage("EndsAt must be after StartsAt")
            .WithErrorCode("Booking.RangeInvalid");
    }
}
```

## 8. Mapping — Mapperly

Mapping configs live in the feature folder as a `[Mapper]` partial class (Mapperly, compile-time source-gen,
AOT-friendly). Register the generated mapper in DI and inject it — never hand-map in the handler, never reflect.

```csharp
namespace YourContext.Application.Handlers.Listings.Mappings;

[Mapper]
public partial class ListingMapper
{
    // MAP: Listing → ListingDetailDto — flattens Owner + Price for the read DTO
    [MapProperty(nameof(Listing.OwnerId), nameof(ListingDetailDto.OwnerId))]
    [MapProperty([nameof(Listing.Price), nameof(Money.Amount)], [nameof(ListingDetailDto.Price)])]
    public partial ListingDetailDto ToDto(Listing source);
}
```

Mapperly generates the body at compile time; a missing/ambiguous mapping is a **build error**, not a runtime
surprise — which is exactly the consistency property we want. Map only Domain→DTO and Request→Command; never map
into entities.

## 9. Idempotency

Two layers, both from `backend-architecture`:

1. **Inbox** dedupes brokered messages automatically (the dispatch seam owns this).
2. **HTTP idempotency-key** dedupes user retries. The endpoint reads `Idempotency-Key` and forwards it as
   `Command.IdempotencyKey` (`api-endpoint-patterns`). For sensitive operations (charges, external notifications),
   the handler treats the key as part of the dedup tuple via the `IIdempotencyStore` seam.

```csharp
public async Task<Result<OrderPlacedResponse>> Handle(PlaceOrderCommand cmd, CancellationToken ct)
{
    if (cmd.IdempotencyKey is null) return Error.Validation("Order.IdempotencyKeyRequired");

    // IDEMPOTENCY: replay protection on (idempotencyKey, fingerprint)
    var replay = await idempotency.TryReplayAsync<OrderPlacedResponse>(cmd.IdempotencyKey, cmd, ct);
    if (replay is not null) return replay;

    var order = Order.Place(cmd.CustomerId, cmd.Items);
    if (order.IsError) return order.Errors;
    await repo.AddAsync(order.Value, ct);
    await repo.SaveChangesAsync(ct);

    var response = new OrderPlacedResponse(order.Value.Id.Value);
    await idempotency.RecordAsync(cmd.IdempotencyKey, cmd, response, ct);
    return response;
}
```

## 10. Repositories (the boundary)

This skill states the boundary; `data-access-patterns` owns the implementation.

- **Write repository per aggregate** — interface in Application, EF implementation in Infrastructure. Methods:
  `GetByIdAsync` (returns `Result<TAggregate>`), `AddAsync`, `Remove`, `SaveChangesAsync`. No `BeginTransaction` —
  the pipeline owns the unit of work.
- **Read service per query family** — interface in Application, Dapper implementation in Infrastructure.
- **No generic `IRepository<T>`** — typed per aggregate.

```csharp
namespace YourContext.Application.Handlers.Listings;

public interface IListingsRepository
{
    Task<Result<Listing>> GetByIdAsync(ListingId id, CancellationToken ct);
    Task AddAsync(Listing listing, CancellationToken ct);
    void Remove(Listing listing);
    Task SaveChangesAsync(CancellationToken ct);
}
```

## 11. Anti-patterns

- Injecting `DbContext`, Wolverine `IMessageBus`/`IMessageContext`, or putting `[Transactional]` on a handler —
  use repositories + the pipeline (NetArchTest invariant #1).
- Throwing for business failures — return `Result` (invariant #3).
- Generic `IRepository<T>`; `static class` business logic; anemic aggregates (logic in handlers that belongs on the aggregate).
- Publishing integration events from a command handler — raise a domain event; emit from a `DomainEventHandler` (§4).
- Hand-mapping or reflection mapping — use the Mapperly `[Mapper]` partial.
- `if (entity.Status == X)` branches in handlers — that's a domain invariant; move it onto the aggregate.

## 12. Testing

Unit-test handlers in isolation with fake repositories + a `FakeUserContext` (`authorization-patterns`). Validators
test via `FluentValidation.TestHelper` (`.TestValidate(command)`). Mappers are compile-time verified; cover them
through the handler integration tests. Full pipeline/outbox behavior is integration-tested per `infrastructure-wiring`.

## 13. References

- `backend-architecture` — seams, structure, marker index, events model, invariants (read first).
- `api-endpoint-patterns` — HTTP entry, Result→HTTP, idempotency-key header.
- `data-access-patterns` — EF write repositories, Dapper read services.
- `caching-patterns` — cache-aside in query handlers, invalidation.
- `authorization-patterns` — `IUserContext`, `RequiresPermission`, ABAC handlers.
