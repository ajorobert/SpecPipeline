---
name: wolverine-patterns
description: |
  Wolverine in-process command/query dispatch and brokered messaging on .NET 10 with PostgreSQL outbox. Applies to: command handlers, query handlers, event publishing, sagas, scheduled messages, retry policies, cross-context integration events. Use whenever a feature emits or handles a message.
when_to_load:
  - Task mentions: command, query, handler, event, publish, subscribe, saga, outbox, integration event, message bus, scheduled message
  - Files touched: any *Handler.cs, *Command.cs, *Query.cs, *Event.cs, *Saga.cs
co_loads_with:
  - backend-feature-patterns (every command/query handler)
  - persistence-patterns (outbox shares EF transaction)
  - observability-backend (span propagation)
---

# Wolverine Patterns

## 1. Mental model

One bus, two modes.

| Mode | Method | Use for |
|---|---|---|
| In-process | `bus.InvokeAsync<T>(msg, ct)` | Commands and queries handled inside this service. Caller awaits result. |
| Brokered fire-and-forget | `bus.PublishAsync(msg)` | Events to zero-to-many handlers, integration events crossing bounded contexts. Routed via RabbitMQ. |
| Brokered with outbox | `MessageContext.EnqueueAsync(msg)` inside a `[Transactional]` handler | Any publish from a handler that also mutates state. Commits with the EF transaction. |

**Message taxonomy**

| Kind | Handlers | Returns | Transport |
|---|---|---|---|
| Command (`*.Command`) | exactly one | `ErrorOr<T>` | in-process |
| Query (`*.Query`) | exactly one | `ErrorOr<T>` | in-process |
| Event (`*.Event`) | zero-to-many | void | in-process or brokered |
| Integration event (`*.IntegrationEvent`) | zero-to-many across services | void | brokered (RabbitMQ) only |

## 2. Command handler shape

Command + Handler colocated in one file under the feature folder. Handler is a plain class — Wolverine discovers `Handle`/`Consume`/`HandleAsync` by convention.

```csharp
namespace YourContext.Application.Listings.Activate;

public sealed record ActivateListingCommand(Guid ListingId, Guid ActorId);

public sealed class ActivateListingCommandHandler(YourContextDbContext db, IClock clock)
{
    // CONFIGUREAWAIT: handlers omit ConfigureAwait — Wolverine controls the sync context.
    // Library code outside handlers still uses ConfigureAwait(false).
    [Transactional]
    public async Task<ErrorOr<Success>> Handle(ActivateListingCommand cmd, IMessageContext bus, CancellationToken ct)
    {
        var listing = await db.Listings.FindAsync([cmd.ListingId], ct);
        if (listing is null) return Error.NotFound("Listing.NotFound");
        if (!listing.CanActivate(out var rule)) return Error.Validation(rule);

        listing.Activate(cmd.ActorId, clock.UtcNow);
        // OUTBOX: enqueued, not published — commits with the EF transaction below.
        await bus.EnqueueAsync(new ListingActivatedEvent(listing.Id, clock.UtcNow));
        await db.SaveChangesAsync(ct);
        return Result.Success;
    }
}

public sealed class ActivateListingCommandValidator : AbstractValidator<ActivateListingCommand>
{
    public ActivateListingCommandValidator()
    {
        RuleFor(x => x.ListingId).NotEmpty();
        RuleFor(x => x.ActorId).NotEmpty();
    }
}
```

FluentValidation runs as Wolverine middleware via `.UseFluentValidation()` on the chain — validators are auto-discovered by assembly scan, no per-handler wiring.

**Idempotency.** Wolverine deduplicates incoming brokered messages by `Envelope.Id` against the inbox table. In-process `InvokeAsync` does not dedupe — the caller is responsible. Never re-derive an idempotency key inside the handler.

## 3. Query handler shape

Queries do not bind to a transaction. Read through Dapper or a read repository (cross-ref persistence-patterns §4).

```csharp
namespace YourContext.Application.Listings.GetDetail;

public sealed record GetListingDetailQuery(Guid ListingId) : IQuery<ErrorOr<ListingDetailDto>>;

public sealed class GetListingDetailQueryHandler(IListingReadRepository repo)
{
    public async Task<ErrorOr<ListingDetailDto>> Handle(GetListingDetailQuery q, CancellationToken ct)
    {
        var dto = await repo.GetDetailAsync(q.ListingId, ct);
        return dto is null ? Error.NotFound("Listing.NotFound") : dto;
    }
}
```

Endpoints call `bus.InvokeAsync<ErrorOr<ListingDetailDto>>(query, ct)` and map the result to HTTP.

## 4. Event publishing — outbox pattern (the critical rule)

> **Rule:** Inside a handler that mutates state, **never** call `bus.PublishAsync` directly. Use `IMessageContext.EnqueueAsync` inside a `[Transactional]` handler so the publish commits with the EF transaction (via `Wolverine.EntityFrameworkCore`). Direct publish is a dual-write: the broker may receive the message before — or instead of — the DB commit, leaving observers ahead of truth.

**Right pattern.**

```csharp
[Transactional]
public async Task<ErrorOr<Success>> Handle(CompletePaymentCommand cmd, IMessageContext bus, CancellationToken ct)
{
    var payment = await db.Payments.FindAsync([cmd.PaymentId], ct);
    if (payment is null) return Error.NotFound("Payment.NotFound");

    payment.MarkCompleted();
    // OUTBOX: persists to wolverine_outgoing in the same tx as the payment update.
    await bus.EnqueueAsync(new PaymentCompletedEvent(payment.Id, payment.Amount));
    await db.SaveChangesAsync(ct);
    return Result.Success;
}
```

**Wrong pattern.**

```csharp
public async Task<ErrorOr<Success>> Handle(CompletePaymentCommand cmd, IMessageBus bus, CancellationToken ct)
{
    var payment = await db.Payments.FindAsync([cmd.PaymentId], ct);
    payment!.MarkCompleted();
    await db.SaveChangesAsync(ct);
    // WRONG: dual-write risk. If the broker is down or the process dies here,
    // the DB commit happened but no event is sent — observers stay stale forever.
    await bus.PublishAsync(new PaymentCompletedEvent(payment.Id, payment.Amount));
    return Result.Success;
}
```

## 5. Event handler shape

Event handlers receive in-process or brokered events. They are idempotent by `Envelope.Id` for brokered delivery (Wolverine inbox). If the handler itself mutates state and emits a follow-on message, the same outbox rule applies — annotate with `[Transactional]` and use `EnqueueAsync`.

```csharp
namespace YourContext.Application.Listings.Search;

public sealed class IndexListingOnActivatedHandler(IListingSearchIndexer indexer)
{
    public Task Handle(ListingActivatedEvent evt, CancellationToken ct)
        => indexer.IndexAsync(evt.ListingId, ct);
}

[Transactional]
public sealed class WriteAuditOnPaymentCompletedHandler(YourContextDbContext db)
{
    public async Task Handle(PaymentCompletedEvent evt, IMessageContext bus, CancellationToken ct)
    {
        db.AuditLog.Add(new AuditEntry("payment.completed", evt.PaymentId));
        // OUTBOX: follow-on integration event committed with the audit row.
        await bus.EnqueueAsync(new PaymentCompletedIntegrationEvent(evt.PaymentId, evt.Amount));
        await db.SaveChangesAsync(ct);
    }
}
```

## 6. Integration events (cross-context)

Cross bounded contexts via RabbitMQ only. Never `InvokeAsync` across contexts — that creates a synchronous hard coupling.

**Naming.** `<Context>.<Aggregate><PastTenseVerb>IntegrationEvent` — e.g. `Listings.ListingActivatedIntegrationEvent`.

**Versioning.** Additive only. A breaking change is a new class `…V2IntegrationEvent` published alongside the original until consumers migrate.

**Routing.** Topic exchange `yourcompany.integration`. Routing key = `<context>.<aggregate>.<verb>` (lowercase, dot-delimited).

```csharp
// Publisher (in the context that owns the aggregate)
namespace YourContext.Contracts.Listings;
public sealed record ListingActivatedIntegrationEvent(Guid ListingId, DateTimeOffset ActivatedAt, string Region);

[Transactional]
public sealed class PublishListingActivatedHandler(YourContextDbContext db)
{
    public async Task Handle(ListingActivatedEvent evt, IMessageContext bus, CancellationToken ct)
    {
        var l = await db.Listings.FindAsync([evt.ListingId], ct);
        // OUTBOX: brokered integration event committed with the read-side projection write.
        await bus.EnqueueAsync(new ListingActivatedIntegrationEvent(l!.Id, l.ActivatedAt!.Value, l.Region));
        await db.SaveChangesAsync(ct);
    }
}

// Consumer (in a different bounded context)
namespace OtherContext.Application.SearchIndex;
public sealed class OnListingActivatedHandler(ISearchIndexer indexer)
{
    public Task Handle(ListingActivatedIntegrationEvent evt, CancellationToken ct)
        => indexer.UpsertAsync(evt.ListingId, evt.Region, ct);
}
```

## 7. Sagas

Use a Wolverine saga for a multi-step business process with branches, compensation, or timeouts that does **not** warrant an Elsa workflow. Decision: human-visible SLAs and breach alerts → Elsa (see `workflow-and-jobs-patterns`); pure message-driven state machine → saga.

State is persisted in PostgreSQL via Wolverine's saga storage. Hold IDs in saga state — never entity references.

```csharp
namespace YourContext.Application.Orders.Fulfillment;

public sealed class OrderFulfillmentSaga : Saga
{
    public Guid Id { get; set; }                                // SAGA-STATE: correlation
    public Guid OrderId { get; set; }                           // SAGA-STATE
    public FulfillmentStep Step { get; set; }                   // SAGA-STATE

    public IEnumerable<object> Start(OrderPlacedEvent evt)
    {
        Id = evt.OrderId; OrderId = evt.OrderId; Step = FulfillmentStep.AwaitingPayment;
        yield return new ReservePaymentCommand(evt.OrderId, evt.Amount);
        yield return new PaymentTimeout(evt.OrderId).DelayedFor(TimeSpan.FromMinutes(15));
    }

    public IEnumerable<object> Handle(PaymentReservedEvent evt)
    {
        Step = FulfillmentStep.AwaitingShipping;
        yield return new RequestShipmentCommand(OrderId);
    }

    public IEnumerable<object> Handle(PaymentTimeout _)
    {
        if (Step != FulfillmentStep.AwaitingPayment) yield break;
        yield return new CancelOrderCommand(OrderId, "PaymentTimeout");
        MarkCompleted();
    }
}

public enum FulfillmentStep { AwaitingPayment, AwaitingShipping, Shipped, Cancelled }
```

## 8. Scheduled messages

One-shot future delivery. For recurring background jobs (cron-style), use Hangfire — that lives in `workflow-and-jobs-patterns`.

```csharp
await bus.ScheduleAsync(new SendReminderCommand(userId), TimeSpan.FromHours(24));
// Or at an absolute time:
await bus.ScheduleAsync(new ExpireSessionCommand(sessionId), sessionExpiresAt);
```

The scheduled envelope is durable in `wolverine_scheduled` and survives process restart.

## 9. Retry policies

Per-handler attribute or global on-exception policy. Wolverine applies exponential backoff and dead-letters after the configured attempts.

```csharp
[RetryNow(typeof(DbUpdateConcurrencyException), 3)]
[RetryLater(typeof(HttpRequestException), 5, 10, 30)]   // seconds: 5, 10, 30 between attempts
public sealed class ChargeCardCommandHandler(IPaymentGateway gw)
{
    public Task<ErrorOr<Success>> Handle(ChargeCardCommand cmd, CancellationToken ct)
        => gw.ChargeAsync(cmd.Token, cmd.Amount, ct);
}
```

Anything that exhausts retries lands on the broker DLQ (RabbitMQ) or `wolverine_dead_letter` (in-process).

## 10. Testing handlers

Use Wolverine's test host. Drive the handler through the bus, then assert on outbox contents and side effects.

```csharp
[Fact]
public async Task Activating_listing_enqueues_integration_event()
{
    await using var host = await AlbaHost.For<Program>(x => x.ConfigureServices(s =>
        s.AddSingleton<IClock>(new FakeClock(DateTimeOffset.Parse("2026-05-18T00:00:00Z")))));

    var bus = host.Services.GetRequiredService<IMessageBus>();
    var listingId = await SeedActiveListingAsync(host);

    var result = await bus.InvokeAsync<ErrorOr<Success>>(new ActivateListingCommand(listingId, Guid.NewGuid()));
    Assert.False(result.IsError);

    var outbox = host.Services.GetRequiredService<IMessageStore>();
    var pending = await outbox.Admin.AllOutgoingAsync();
    Assert.Contains(pending, e => e.MessageType.Contains("ListingActivated"));
}
```

## 11. Anti-patterns

- Direct `PublishAsync` inside a state-mutating handler without `[Transactional]` + `EnqueueAsync`.
- Saga state holding entity references — hold IDs only.
- Synchronous `InvokeAsync` across bounded contexts — emit an integration event instead.
- Throwing exceptions for business failures — return `ErrorOr<T>` with a typed error.
- Catching exceptions in handlers to "fix" them — let the Wolverine retry policy handle it.

## 12. Comment markers emitted by this skill

- `// OUTBOX:` — the line where an outbox-bound enqueue happens.
- `// SAGA-STATE:` — saga state fields requiring persistence.
- `// CONFIGUREAWAIT:` — explains why handlers omit `ConfigureAwait(false)`.
- `// WRONG:` — counter-example marker for anti-pattern illustration.

## 13. References

- `backend-feature-patterns` — handler lives inside a feature; `ErrorOr<T>` contract lives there.
- `persistence-patterns` — outbox shares the EF DbContext transaction; saga state storage.
- `observability-backend` — Wolverine span propagation is automatic; PII redaction is not.
