---
name: orchestration-patterns
description: |
  Stateful-process orchestration for .NET 10: Wolverine sagas (in-process choreography), Elsa v3 long-running workflows, and Hangfire background jobs. Covers the decision rule between the three engines; saga state-machine authoring; Elsa activity authoring, bookmarks and signals; Hangfire recurring/scheduled/fire-and-forget jobs; dashboard auth; OTel propagation; PostgreSQL persistence. Use whenever a feature needs scheduled, recurring, or long-lived stateful work that isn't a single command/query.
when_to_load:
  - Task mentions: saga, workflow, elsa, activity, signal, bookmark, human in the loop, hangfire, job, scheduled, recurring, cron, background, batch, dashboard, timeout, compensation, orchestration
  - Files touched: any *Saga.cs, *Workflow.cs, *Activity.cs, *Job.cs, recurring jobs registration, Elsa workflow definitions (JSON or builders)
co_loads_with:
  - backend-architecture (canonical seams, structure, markers, events model — read first)
  - backend-feature-patterns (saga/job/activity bodies dispatch commands that follow handler-shape rules)
  - infrastructure-wiring (saga + Hangfire + Elsa runtime registration, PG schema setup, dashboard auth wiring)
references:
  - data-access-patterns (Dapper streaming reads for reindex/batch jobs)
  - search-patterns (SearchReindexJob is referenced by that skill — defined here)
  - file-pipeline-patterns (QuarantineCleanupJob is referenced by that skill — defined here)
  - observability-backend (OTel propagation through saga/Elsa/Hangfire)
---

# Orchestration Patterns

Read `backend-architecture` first — it owns the seam catalog, the building-blocks/module structure,
the comment-marker index, the domain/integration event model, and the NetArchTest invariants. This
skill is the **single home for stateful-process orchestration**: Wolverine sagas, Elsa v3 workflows,
and Hangfire jobs.

**One rule binds all three engines:** they never name the dispatch library. A saga, an activity, or a
job that needs business work done **sends a command through the dispatch seam** — `IAppCommandBus.Send`
(or reads via `IAppQueryBus.Execute`). The command handler does the transactional work and the outbox
publishes follow-on integration events (`backend-architecture §6`). No orchestration code injects
Wolverine `IMessageBus`/`IMessageContext`, opens a DbContext, or carries `[Transactional]` — the saga
base, the saga/job/workflow runtime, and the outbox machinery live in `infrastructure-wiring`.

## 1. Mental model + decision rule

|                  | Wolverine saga                | Elsa workflow                  | Hangfire job                  |
|---|---|---|---|
| **Lifespan**     | seconds-to-hours              | hours-to-months (with human waits) | milliseconds-to-minutes (no waiting) |
| **State**        | correlation-id keyed; saga state in PostgreSQL | full workflow state in DB; resumable across deploys | job arguments only (no persisted state between executions) |
| **Human in loop?** | no                          | yes (signals, bookmarks, forms) | no |
| **Cron / recurring?** | no                       | no (schedule via activity)     | yes (cron, Hangfire's primary use case) |
| **Branching logic** | code only                  | designer + code                | code only |
| **Compensation**  | saga timeouts + compensating commands | workflow exceptions             | manual via retry filter |
| **Best fit**     | "scan → process → publish" (event-driven choreography) | "approval chain that waits 7 days for human action" | "every night at 2am, purge orphan quarantine blobs" |

**Decision rule (skim):**

- Event-driven coordination, short-lived, no human → **Wolverine saga** (§2)
- Human waits, long-lived, durable form/signal → **Elsa workflow** (§3–§5)
- Recurring or scheduled background work, no event waiting → **Hangfire job** (§6–§10)

When in doubt: a saga-with-a-timer-that-waits-for-a-human is really an Elsa workflow. A Hangfire job
whose body sends a command is correct — the job is just the scheduler; the handler does the work (§7).

## 2. Wolverine sagas

A saga is a **message-driven state machine**: it reacts to domain/integration events and yields
commands and timeout messages until the process completes. Use a saga for a multi-step business process
with branches, compensation, or timeouts that does **not** warrant an Elsa workflow (§5).

**Authoring shape (the part this skill owns):**

- Saga state holds **IDs and a step enum — never entity references**. State is persisted in PostgreSQL;
  it must be a serializable record of *where the process is*, not a graph of loaded aggregates.
- Each persisted field is annotated `// SAGA-STATE:`. Correlation is by the saga's `Id`.
- A **`Start` method** opens the saga on the first event; **`Handle` methods** advance it on subsequent
  events. Each yields zero-or-more **messages** — commands to do the next step, or delayed timeout
  messages for SLAs.
- **Timeouts** are self-scheduled delayed messages (one-shot future delivery, §8). On timeout the saga
  emits a **compensating command** (cancel/refund/rollback) and completes.
- The saga yields *messages*; it does **not** call the bus. The hosting runtime publishes what the saga
  yields and routes timeout messages back to it. That base class + runtime registration is
  `infrastructure-wiring`'s concern — not application code.

```csharp
namespace YourContext.Application.Orders.Fulfillment;

public sealed class OrderFulfillmentSaga
{
    public Guid Id { get; set; }                                // SAGA-STATE: correlation id
    public OrderId OrderId { get; set; }                        // SAGA-STATE: id only, never the Order aggregate
    public FulfillmentStep Step { get; set; }                   // SAGA-STATE: where the process is

    // Start: first event opens the saga; yields the next command + a timeout guard.
    public IEnumerable<object> Start(OrderPlacedIntegrationEvent evt)
    {
        Id = evt.OrderId; OrderId = new OrderId(evt.OrderId); Step = FulfillmentStep.AwaitingPayment;
        yield return new ReservePaymentCommand(OrderId, evt.Amount);
        yield return new PaymentTimeout(evt.OrderId).DelayedFor(TimeSpan.FromMinutes(15));
    }

    public IEnumerable<object> Handle(PaymentReservedIntegrationEvent evt)
    {
        Step = FulfillmentStep.AwaitingShipping;
        yield return new RequestShipmentCommand(OrderId);
    }

    // Compensation on timeout: emit the cancel command and end the saga.
    public IEnumerable<object> Handle(PaymentTimeout _)
    {
        if (Step != FulfillmentStep.AwaitingPayment) yield break;
        yield return new CancelOrderCommand(OrderId, Reason: "PaymentTimeout");
        MarkCompleted();
    }
}

public enum FulfillmentStep { AwaitingPayment, AwaitingShipping, Shipped, Cancelled }
```

The yielded commands (`ReservePaymentCommand`, `CancelOrderCommand`) are ordinary commands dispatched
through the seam; their handlers follow `backend-feature-patterns §3` and own the transaction + outbox.
The saga itself never mutates an aggregate or publishes directly. Saga storage (PG schema, the `Saga`
base/runtime, `MarkCompleted` / `DelayedFor` plumbing) is registered in `infrastructure-wiring`.

## 3. Elsa workflows: structure

A workflow is a composition of **Activities** — .NET classes implementing `IActivity` (or inheriting
`CodeActivity` for synchronous one-shot work). Workflows are persisted to PostgreSQL (`elsa.*` schema)
and **resumable across app restarts**.

Two definition styles:

| Style | When |
|---|---|
| **Programmatic** (C# builder, `WorkflowBase`) | Code-first workflows under source control — the default for engineering-owned workflows. |
| **JSON / designer** | Business-user-composed workflows. Out of scope for this skill (deployment + designer hosting concern → `infrastructure-wiring`). |

```csharp
namespace YourContext.Application.Workflows.Approval;

public sealed class ListingApprovalWorkflow : WorkflowBase
{
    public static readonly string DefinitionId = nameof(ListingApprovalWorkflow);

    protected override void Build(IWorkflowBuilder builder)
    {
        builder.WithDefinitionId(DefinitionId).WithVersion(1);
        builder.Root = new Sequence
        {
            Activities =
            [
                new SetVariable<Guid> { VariableName = "ListingId", Value = new(ctx => ctx.GetInput<Guid>()) },
                // Bookmark: pauses here until an external signal arrives (see §4)
                new Event<ApprovalDecision>("listing-approval-decided"),
                new If(ctx => ctx.GetVariable<ApprovalDecision>("decision")!.Approved)
                {
                    Then = new PublishApproved(),
                    Else = new PublishRejected(),
                },
            ]
        };
    }
}
```

Recommendation: programmatic for everything except designer-driven business workflows.

## 4. Elsa activities

This skill owns the activity authoring shape.

- Activity = .NET class with the `[Activity]` attribute (display name, category).
- Inputs and outputs declared as `Input<T>` / `Output<T>` properties.
- Inject services via constructor — DI works inside activities.
- **Critical rule:** activities do cross-context side effects by **sending a command through the
  dispatch seam** (`IAppCommandBus.Send`), NOT by reaching into other bounded contexts' repositories.
  An activity is a workflow primitive; it does not own business logic.
- Activities return success or set output values; throw `WorkflowFaultException` for unrecoverable faults.
- Unit-test by instantiating the activity, setting inputs, and calling `ExecuteAsync` with a mocked
  `ActivityExecutionContext`.

```csharp
[Activity("YourContext", "Notifications", "Raise an SLA-breach alert via a command")]
public sealed class TriggerSlaBreachAlert(IAppCommandBus commandBus) : CodeActivity
{
    // ACTIVITY-INPUT: BookingId — the booking that breached SLA
    [Input(Description = "Booking ID to alert on")]
    public Input<Guid> BookingId { get; set; } = default!;

    [Output] public Output<bool> AlertSent { get; set; } = default!;

    protected override async ValueTask ExecuteAsync(ActivityExecutionContext ctx)
    {
        var id = ctx.Get(BookingId);
        // The command handler raises the domain event; the outbox publishes the integration event.
        var result = await commandBus.Send(new RaiseSlaBreachAlertCommand(new BookingId(id)), ctx.CancellationToken);
        ctx.Set(AlertSent, !result.IsError);
    }
}
```

## 5. Bookmarks and signals (human-in-the-loop)

A **bookmark** is a workflow pause point waiting for an external signal. The `Event<TPayload>` activity
creates the bookmark; an outside caller resumes the workflow by invoking the runtime with a matching
activity input.

```csharp
// Inside the workflow definition
new Event<ApprovalDecision>("listing-approval-decided"),

// Signal sender — a FastEndpoints endpoint resumes the bookmark
public sealed class SubmitApprovalDecisionEndpoint(IWorkflowRuntime runtime)
    : Endpoint<Request, Response>
{
    public override void Configure()
    {
        Post("/api/v1/listings/{ListingId}/approval");
        // AUTH: listings.approve — see api-endpoint-patterns + authorization-patterns
        Policies("listings.approve");
    }

    public override async Task HandleAsync(Request req, CancellationToken ct)
    {
        // Owner/reviewer ABAC is enforced on the endpoint — see authorization-patterns.
        await runtime.ResumeWorkflowsAsync(
            new BookmarkPayload("listing-approval-decided", req.ListingId),
            new ApprovalDecision(req.Approved, req.Reason),
            ct);

        await SendOkAsync(new Response(Accepted: true), ct);
    }
}
```

**Bookmark TTL** — workflows enforce a timeout by racing a `Timer` activity against the bookmark via
`Fork`; whichever fires first wins. Never hardcode durations — read from configuration or a domain
policy service. Never hold DB connections or locks open across a bookmark.

## 5b. Workflow vs saga decision

> **Rule:** If the coordination is pure event-driven choreography with bounded duration and no human
> input, write a **Wolverine saga** (§2). If the coordination waits on human action, has stages spanning
> hours/days, or needs a visual representation for non-developers, write an **Elsa workflow**.

**Failure modes.** Mis-choosing Elsa for short-lived event coordination → bloat, designer overhead,
harder testing. Mis-choosing a saga for long-running human-wait → state-bleed across saga timeouts; the
saga either expires too early or holds correlation state indefinitely.

**The two engines must not coordinate with each other directly.** If a saga needs an Elsa workflow to
start, it yields a command/integration event; an Elsa "Listen for event" activity picks it up. The
reverse is the same — an Elsa activity sends a command through the dispatch seam; it never subscribes to
Wolverine events directly.

## 6. Hangfire: structure

Jobs persisted to PostgreSQL (`hangfire.*` schema, distinct from `elsa.*`); workers pulled from a
connection pool. Schema + worker registration is `infrastructure-wiring`. Four job kinds:

| Kind | API | When |
|---|---|---|
| **Recurring** | `RecurringJob.AddOrUpdate` with cron | nightly purges, daily rollups |
| **Scheduled** | `BackgroundJob.Schedule(...)` | one-shot future code execution with retries + dashboard visibility |
| **Fire-and-forget** | `BackgroundJob.Enqueue(...)` | run ASAP on a free worker; out-of-band work |
| **Continuation** | `BackgroundJob.ContinueJobWith(...)` | run after another job succeeds |

**When to choose vs a Wolverine scheduled message:** a scheduled message (§8) is for one-shot future
**message delivery** (deliver this event in 10 minutes). Hangfire is for one-shot future **code
execution** with retries, dashboard visibility, and persistence (rebuild the search index tonight at
2am). The line: are you delivering a message or running a piece of code?

## 7. Hangfire job class shape

This skill owns the job authoring shape.

- Plain .NET class with at least one public method; DI works.
- Job arguments must be JSON-serializable (Hangfire stores them in the `hangfire.job` table).
- Long-running methods accept a `CancellationToken` — honored on worker shutdown or manual abort.
- Inject `IAppCommandBus`; the **job body is a single `commandBus.Send(command, ct)` call**. A Hangfire
  job is not inside a transaction, so it must not mutate state and publish directly — it dispatches a
  command and the handler owns the transaction + outbox (§8).
- Naming: `<Aggregate><Purpose>Job` (e.g. `QuarantineCleanupJob`, `SearchReindexJob`).

```csharp
namespace YourContext.Application.Files.Jobs;

public sealed class QuarantineCleanupJob(IAppCommandBus commandBus)
{
    // CRON: 0 2 * * *  — daily at 02:00 UTC, registered in §9
    public Task Run(CancellationToken ct) =>
        commandBus.Send(new PurgeAbandonedQuarantineUploadsCommand(OlderThan: TimeSpan.FromHours(24)), ct);
}
```

This is the canonical shape — the body is one `commandBus.Send` call. The business logic lives in
`PurgeAbandonedQuarantineUploadsCommandHandler` and follows `backend-feature-patterns §3`.
`QuarantineCleanupJob` is **defined here** and referenced by `file-pipeline-patterns`.

## 8. Hangfire transaction & outbox interaction

> **Rule:** A Hangfire job is NOT inside a transactional dispatch scope. If the job needs state mutated
> AND events published, it MUST dispatch a command via `IAppCommandBus.Send(command, ct)` — which runs
> the handler inside the command pipeline's transaction and binds the outbox (`backend-architecture §6`).

**Failure mode.** A job that mutated state and then published directly would be a dual-write: if the
broker is down between the DB commit and the publish, the state is committed but the event is lost.
Dispatching a command avoids this entirely — the outbox commits with the state change. This is the same
outbox invariant called out in `backend-architecture §6`; orchestration code never re-implements it.

**Preferred pattern: the job's body is one line.**

```csharp
public sealed class SearchReindexJob(IAppCommandBus commandBus)
{
    public Task Run(string aliasName, CancellationToken ct) =>
        commandBus.Send(new RunSearchReindexCommand(aliasName), ct);
}
```

The command handler does the real work — write path, outbox-bound follow-on events. The Hangfire layer
is just the scheduler. `SearchReindexJob` is **defined here** and referenced by `search-patterns`.

## 9. Recurring jobs registration

Registered at startup via an extension method on the host (the host wiring lives in
`infrastructure-wiring`). Cron format: standard 5-field cron; prefer `Cron.Daily(2)` for readability.

```csharp
public static void AddYourContextRecurringJobs(this IRecurringJobManager jobs)
{
    // JOB-IDEMPOTENT: the purge command checks "already-purged" by quarantine-bucket key; safe on overlap
    // CRON: daily at 02:00 UTC
    jobs.AddOrUpdate<QuarantineCleanupJob>("uploads.quarantine-cleanup", j => j.Run(default!), Cron.Daily(2));
    jobs.AddOrUpdate<SearchReindexJob>("search.listings-reindex", j => j.Run("listings", default!), Cron.Weekly(DayOfWeek.Sunday, 3));
}
```

Job ID convention: `<aggregate>.<purpose>` (kebab-case in the ID, PascalCase for the class). **Recurring
jobs MUST be idempotent** — running the same job twice on overlap is a no-op (annotate the dedup site
with `// JOB-IDEMPOTENT:`).

## 10. Reindex example

The Elasticsearch alias-based reindex (see `search-patterns`) is the canonical heavy Hangfire job. The
job is a thin shell; the command handler streams source-of-truth records via Dapper (see
`data-access-patterns`), batches them through a bulk indexer, then swaps the alias. Progress is persisted
in a small per-job-instance table so a restart picks up at the next batch.

```csharp
// Job is a thin shell; the command handler owns the reindex pipeline
public sealed class SearchReindexJob(IAppCommandBus commandBus)
{
    public Task Run(string aliasName, CancellationToken ct) =>
        commandBus.Send(new RunSearchReindexCommand(aliasName, BatchSize: 1_000), ct);
}

// In the handler (Application layer) — plain class, no [Transactional], no bus injection
public sealed class RunSearchReindexHandler(IListingsReindexReader reads, IBulkIndexer indexer, IReindexProgressStore progress)
{
    public async Task<Result> Handle(RunSearchReindexCommand cmd, CancellationToken ct)
    {
        var newIndex = $"{cmd.AliasName}_{DateTime.UtcNow:yyyyMMddHHmm}";
        var checkpoint = await progress.GetOrCreateAsync(cmd.AliasName, ct);
        await foreach (var batch in reads.StreamSinceAsync(checkpoint.LastId, cmd.BatchSize, ct))
        {
            await indexer.BulkAsync(newIndex, batch, ct);
            await progress.SaveAsync(cmd.AliasName, batch[^1].Id, ct);
        }
        await indexer.SwapAliasAsync(cmd.AliasName, checkpoint.PreviousIndex, newIndex, ct);
        return Result.Success;
    }
}
```

## 11. Dashboards (Hangfire + Elsa)

> **Rule:** both dashboards are **admin-only** — reserved for Keycloak-authenticated platform admins
> holding the `platform.admin` role, never exposed via the customer portal. The Hangfire dashboard lives
> under `/hangfire`, the Elsa dashboard under `/elsa-studio`, both behind the same JWT + role-gate.

The dashboard authorization filter, JWT middleware order, and route registration are **wiring** — see
`infrastructure-wiring` for the `IDashboardAuthorizationFilter` implementation and the `platform.admin`
policy registration. This skill states only the rule, not the wiring.

## 12. OTel propagation

- **Saga:** the trace-id is part of the saga correlation state for cross-correlation across steps.
- **Elsa:** each activity execution becomes a span; the workflow instance id is carried as a span attribute.
- **Hangfire:** `traceparent` is captured at enqueue and restored on execute, so the job runs in the same
  trace as the enqueuer.

What to emit, at what level, and the exact instrumentation/filter wiring live in `observability-backend`.

## 13. Anti-patterns

- Hangfire job that mutates state and publishes directly — dual-write risk. Send a command via
  `IAppCommandBus.Send(command, ct)` instead (§8).
- Saga state holding entity references — hold IDs + a step enum only (§2).
- Saga or activity injecting Wolverine `IMessageBus`/`IMessageContext`, or a handler carrying
  `[Transactional]` — orchestration yields/sends commands; the pipeline owns the transaction.
- Elsa activity that reaches into another bounded context's repository directly — send a command and let
  the owning context's handler do the work.
- Long-running work inside a command handler — push it into a Hangfire job; the job sends the command.
- Hangfire job that takes hours — split into chunked recurring (`BatchSize`) or escalate to Elsa.
- Mutable state held in an Elsa workflow variable when the workflow is supposed to be stateless between
  bookmarks — use external persistence.
- Recurring jobs without an idempotency check — overlapping runs create duplicate side effects.
- Hangfire/Elsa dashboard exposed without the admin role-gate — information disclosure (§11).
- `BackgroundJob.Enqueue` from inside a handler that already emits an integration event — pick one
  channel. Events for downstream choreography; jobs for scheduled work.
- Cron expressions with sub-minute granularity — use a Wolverine scheduled message instead.

## 14. Testing

**Sagas.** A saga is a plain class — drive it by calling `Start`/`Handle` and asserting on the yielded
messages and the resulting state fields. No bus or DB needed for the state-machine logic.

**Elsa.** Workflow tests use the Elsa testing harness — instantiate the runtime in-memory, dispatch the
trigger, advance bookmarks programmatically via `IWorkflowRuntime.ResumeWorkflowsAsync`.

**Hangfire.** Jobs are plain classes — unit-test them directly against a fake `IAppCommandBus`.

```csharp
[Fact]
public async Task QuarantineCleanupJob_sends_purge_command()
{
    var bus = Substitute.For<IAppCommandBus>();
    var job = new QuarantineCleanupJob(bus);
    await job.Run(default);
    await bus.Received(1).Send(
        Arg.Is<PurgeAbandonedQuarantineUploadsCommand>(c => c.OlderThan == TimeSpan.FromHours(24)),
        Arg.Any<CancellationToken>());
}
```

## 15. Comment markers emitted by this skill

- `// SAGA-STATE:` — saga state field requiring persistence (id/step only).
- `// ACTIVITY-INPUT:` — Elsa activity input binding.
- `// CRON:` — Hangfire recurring job cron expression annotation.
- `// JOB-IDEMPOTENT:` — the dedup/skip check inside a recurring job (or the rationale at registration).

The canonical cross-skill marker index lives in `backend-architecture §7`.

## 16. References

- `backend-architecture` — seams, structure, marker index, events/outbox model, invariants (read first).
- `backend-feature-patterns §3` — command handler shape (commands sent by sagas/jobs/activities follow these).
- `infrastructure-wiring` — saga base + runtime registration, Hangfire/Elsa host registration, PG schema
  setup (`elsa.*`, `hangfire.*`), dashboard auth filter + `platform.admin` policy.
- `data-access-patterns` — Dapper streaming reads for reindex/batch jobs.
- `search-patterns` — `SearchReindexJob` is referenced there; defined here.
- `file-pipeline-patterns` — `QuarantineCleanupJob` is referenced there; defined here.
- `observability-backend` — OTel propagation through saga/Elsa/Hangfire.
- `.specify/memory/system-context.md` — project-specific recurring jobs / workflow inventory.
