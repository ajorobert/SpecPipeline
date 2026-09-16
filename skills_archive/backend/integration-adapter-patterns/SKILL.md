---
name: integration-adapter-patterns
description: |
  Authoring patterns for external integration adapters in .NET 10: port-and-adapter split, typed HttpClient registration, DelegatingHandler chain order with M2M token attachment, Polly v8 resilience via Microsoft.Extensions.Http.Resilience, idempotency-aware retry, transient-vs-permanent error mapping, OTel auto-instrumentation. Loaded only when authoring or modifying an external integration adapter project — NOT for regular feature work that injects existing ports.
when_to_load:
  - Task mentions: adapter, integration, vendor api, external service, httpclient registration, DelegatingHandler, resilience, polly, retry, circuit breaker, timeout, idempotency-aware retry
  - Files touched: any project under `*.Adapters.*`, any `AddHttpClient<...>` call, any custom `DelegatingHandler` class
co_loads_with:
  - backend-architecture (canonical seams, structure, markers, events model — read first)
  - infrastructure-wiring (registers the M2M token provider + handler; M2M DelegatingHandler attach is a joint rule)
references:
  - backend-architecture §6 (handler-level redelivery vs HTTP retry boundary)
  - backend-feature-patterns (handlers depend on ports; this skill produces the adapters)
  - search-patterns, file-pipeline-patterns (concrete adapter examples)
  - observability-backend (OTel auto-instrumentation — Phase 5 placeholder)
---

# Integration Adapter Patterns

## 1. Mental model

Two boundaries at play, two retry layers.

```
Application layer            Adapter layer              Wire
───────────────────         ───────────────             ─────
   Handler / Saga              port impl                 HTTP
      │                          │                       │
      │ injects port             │ uses HttpClient        │
      │ (knows nothing about     │ (DelegatingHandlers,   │
      │  HttpClient or Polly)    │  resilience pipeline)  │
      ▼                          ▼                       ▼

Retry layer                  Retry layer
───────────                  ───────────
dispatch-seam handler-level  HTTP-level (Polly)
(message redelivery)         (per-call transient)
```

The contract: app code knows the port. The adapter knows the wire. They never mix. **If you find Polly, `HttpClient`, or a vendor SDK leaking into Application-layer code, that's a bug — push it into an adapter behind a port.**

## 2. Port and adapter split

- Port lives in Application: `YourContext.Application.Ports.IFooService`.
- Implementation lives in adapter project: `YourContext.Adapters.<Vendor>.FooService : IFooService`.
- Adapter project depends on Application (for the port interface) and the vendor SDK / `HttpClient`.
- Application project does **NOT** reference any adapter project — only `YourContext.Api` (composition root) wires them via DI.
- Naming: `IFooService` for the port; `<Vendor>FooService` only when multiple impls exist; otherwise just match the adapter project name.

```csharp
namespace YourContext.Application.Ports;
public interface INotificationService
{
    Task<Result> SendAsync(NotificationRequest req, CancellationToken ct);
}

namespace YourContext.Adapters.Sendgrid;
public sealed class SendgridNotificationService(HttpClient http, IOptions<SendgridOptions> opts)
    : INotificationService                                                       // PORT-IMPL: Sendgrid → INotificationService
{
    public async Task<Result> SendAsync(NotificationRequest req, CancellationToken ct)
    {
        var resp = await http.PostAsJsonAsync("v3/mail/send", req.ToWire(opts.Value), ct);
        return resp.IsSuccessStatusCode ? Result.Success : Error.Failure("Sendgrid.Failed", resp.ReasonPhrase ?? "");
    }
}
```

## 3. Typed HttpClient registration

**Rule:** use `services.AddHttpClient<TPort, TImpl>("name")` over `IHttpClientFactory.CreateClient(name)` inside the adapter. Type-safe, DI-friendly, registration scope clearer. The composition root wires the adapter via a single extension method living **in the adapter project**, called from `Program.cs`.

```csharp
namespace YourContext.Adapters.Sendgrid;

public static class SendgridAdapterRegistration
{
    public static IServiceCollection AddSendgridAdapter(this IServiceCollection services, IConfiguration cfg)
    {
        services.AddOptions<SendgridOptions>().Bind(cfg.GetSection("Sendgrid")).ValidateDataAnnotations().ValidateOnStart();
        services.AddHttpClient<INotificationService, SendgridNotificationService>("sendgrid", (sp, c) =>
        {
            c.BaseAddress = new Uri(sp.GetRequiredService<IOptions<SendgridOptions>>().Value.BaseUrl);
        })
        .AddStandardResilienceHandler();   // RESILIENCE: standard pipeline — see §5
        return services;
    }
}
```

## 4. DelegatingHandler chain order (joint rule with infrastructure-wiring)

> **Rule:** When attaching an M2M bearer token via a custom `DelegatingHandler`, register it BEFORE the resilience handler in the pipeline. Retries replay the request; replays must carry a fresh (or cached) token. If the resilience handler runs first, retried requests can fire with stale or missing auth headers.

Order: `M2MTokenAttachHandler` → `Http.Resilience` standard handler → outbound socket. The `M2MTokenHandler` and its M2M token provider are registered by `infrastructure-wiring`; this skill owns the chain-order rule.

```csharp
services.AddTransient<M2MTokenHandler>();
services.AddHttpClient<IPricingApiClient, PricingApiClient>("pricing", c => c.BaseAddress = new Uri("https://pricing.internal/"))
        // HANDLER-ORDER: M2M token attach FIRST — replays carry the cached token
        .AddHttpMessageHandler<M2MTokenHandler>()
        // RESILIENCE: resilience pipeline runs second — retries replay through the token handler
        .AddStandardResilienceHandler();
```

## 5. Resilience pipeline — standard handler (default)

`AddStandardResilienceHandler()` covers 90%+ of outbound calls — 3 retries with jittered exponential backoff, 30s per-attempt timeout, 100s total timeout, circuit breaks at 10% failure rate. Override defaults via `options =>`:

```csharp
services.AddHttpClient<IFooClient, FooClient>("foo")
        // RESILIENCE: standard pipeline with adapter-specific overrides
        .AddStandardResilienceHandler(o =>
        {
            o.Retry.MaxRetryAttempts          = 5;
            o.AttemptTimeout.Timeout           = TimeSpan.FromSeconds(60);
            o.TotalRequestTimeout.Timeout      = TimeSpan.FromMinutes(5);
            o.CircuitBreaker.SamplingDuration  = TimeSpan.FromSeconds(60);
        });
```

## 6. Resilience pipeline — custom (when standard doesn't fit)

```csharp
services.AddHttpClient<IClamScanClient, ClamScanClient>("clamav")
        .AddResilienceHandler("clamav-pipeline", builder => builder
            // RESILIENCE: total timeout MUST be outermost — caps entire pipeline
            .AddTimeout(TimeSpan.FromMinutes(2))
            .AddConcurrencyLimiter(permitLimit: 8, queueLimit: 4)
            .AddCircuitBreaker(new HttpCircuitBreakerStrategyOptions
            {
                FailureRatio = 0.20, SamplingDuration = TimeSpan.FromSeconds(60),
                MinimumThroughput = 10, BreakDuration = TimeSpan.FromSeconds(30),
            })
            .AddRetry(new HttpRetryStrategyOptions { MaxRetryAttempts = 3, BackoffType = DelayBackoffType.Exponential, UseJitter = true })
            .AddTimeout(TimeSpan.FromSeconds(30)));   // per-attempt
```

## 7. Idempotency-aware retry (critical)

> **Rule:** Retry on POST/PATCH/DELETE only when the target endpoint contract supports an `Idempotency-Key`. The default `ShouldHandle` predicate in `Http.Resilience` excludes mutating verbs from retry — do not override this except for endpoints documented to accept idempotency keys.

Failure mode: retrying a non-idempotent POST after a transient 503 → duplicate side effects on the upstream (the dual-write footgun, HTTP edition).

```csharp
services.AddHttpClient<IPaymentClient, PaymentClient>("payments")
        .AddResilienceHandler("payments-pipeline", builder => builder
            .AddRetry(new HttpRetryStrategyOptions
            {
                MaxRetryAttempts = 3,
                ShouldHandle = args =>
                {
                    // RESILIENCE: POST retry permitted only when the request carries an Idempotency-Key
                    var isMutating = args.Outcome.Result?.RequestMessage?.Method is { } m
                                     && (m == HttpMethod.Post || m == HttpMethod.Patch || m == HttpMethod.Delete);
                    var hasIdem = args.Outcome.Result?.RequestMessage?.Headers.Contains("Idempotency-Key") == true;
                    if (isMutating && !hasIdem) return ValueTask.FromResult(false);
                    return HttpClientResiliencePredicates.IsTransient(args.Outcome);
                },
            }));
```

The idempotency-key contract on the producing side lives in `backend-feature-patterns §9` (handler) and `api-endpoint-patterns` (endpoint); this skill consumes it.

## 8. Transient vs permanent error mapping

The default predicate (`HttpClientResiliencePredicates.IsTransient`) retries on:

| Condition | Retry? |
|---|---|
| HTTP 408, 429, 500, 502, 503, 504 | Yes |
| `HttpRequestException` | Yes |
| `TaskCanceledException` (no user cancellation) | Yes |
| 4xx other than the above | No |
| `OperationCanceledException` (user-cancelled) | No |
| `JsonException` (deserialization) | No |

Custom predicates **extend** the default; don't replace it. Vendor-specific retryable codes (e.g. a 422 with `Retry-After` meaning "queue full, retry later") chain on top of `HttpClientResiliencePredicates.IsTransient`.

## 9. Timeouts (per-attempt vs total)

- **Per-attempt timeout** caps a single HTTP request.
- **Total request timeout** caps the entire pipeline including retries — MUST be the outermost layer.
- **Formula:** `total ≥ per-attempt × (max retries + 1) + sum of backoff intervals`. When in doubt, raise total, not per-attempt.

## 10. Bulkhead / concurrency limiting

Use `AddConcurrencyLimiter` in custom pipelines for upstreams with strict server-side concurrency limits (e.g. a daemon with a small worker pool). The limit is per `HttpClient` name, not process-global. Skip unless you've measured upstream contention or have explicit vendor concurrency quotas.

## 11. The HTTP-retry vs message-redelivery boundary

HTTP retry (this skill) handles in-the-moment transients within a single call. Handler-level redelivery (the dispatch seam, `backend-architecture §6`) handles across-time durability — if a handler's HTTP call exhausts HTTP retries and throws, the dispatch seam decides whether to redeliver the message later.

**They compose; they don't duplicate.** HTTP retry tries hard NOW; message redelivery tries again LATER.

## 12. OTel auto-instrumentation

`Microsoft.Extensions.Http.Resilience` auto-emits `ActivitySource` events for retries, breaks, and timeouts. Spans propagate via `Activity.Current`. Don't manually log retry attempts in user code — that duplicates the OTel events. See `observability-backend` for the export configuration (Phase 5 placeholder).

## 13. Adapter authoring checklist

When adding a new external integration adapter, in order:

1. Define port `IFooService` in `YourContext.Application.Ports` — methods, DTOs, `Result` return semantics.
2. Create adapter project `YourContext.Adapters.<Vendor>` with vendor SDK / HttpClient dependency.
3. Define `<Vendor>Options` POCO; bind from `IConfiguration` with validation.
4. Write the impl class implementing the port (annotate with `// PORT-IMPL:`).
5. Decide: typed `HttpClient` (preferred) or vendor SDK client?
6. Register the typed client with `AddStandardResilienceHandler()` (§5).
7. If auth required: write/reuse `M2MTokenAttachHandler` and register **BEFORE** resilience handler (§4).
8. If the integration includes non-idempotent calls: review the retry predicate (§7).
9. If known-slow or contended upstream: switch to a custom pipeline (§6, §10).
10. Composition root: expose `services.Add<Vendor>Adapter(configuration)` from the adapter project.
11. Verify OTel auto-instrumentation surfaces in local trace export (§12).
12. Test: stub the adapter at the port boundary for unit tests; integration-test against vendor sandbox or testcontainer.

## 14. Anti-patterns

- Application-layer code referencing `HttpClient`, `IHttpClientFactory`, Polly types, or any vendor SDK type — push into an adapter.
- Raw `new HttpClient()` — no resilience, no instrumentation, no DI.
- Custom retry loops in app code — use the pipeline.
- `DelegatingHandler` that attaches auth registered AFTER the resilience handler — replays fire without auth.
- Overriding `ShouldHandle` to retry POST without an idempotency contract — duplicate-side-effect risk.
- Per-attempt timeout > total request timeout — logical inversion; retries impossible.
- Manually logging retry attempts in user code — duplicates OTel.
- Polly v7 wrap-style policies (`Policy.WrapAsync`, `IAsyncPolicy`) — use Polly v8 pipelines via `Http.Resilience`.
- `Microsoft.Extensions.Http.Polly` (the v7 wrapper) — superseded by `Microsoft.Extensions.Http.Resilience`.
- Adapter importing Application's domain types beyond the port DTOs — the adapter must be replaceable in isolation.
- Disabling the circuit breaker — tune sampling and break duration instead.

## 15. Testing

Unit-test the adapter directly using a stub `HttpMessageHandler` to simulate responses. Assert on retry count via OTel `ActivityListener` or by counting handler invocations.

```csharp
[Fact]
public async Task Two_transient_failures_then_success_succeeds()
{
    var calls = 0;
    var stub = new StubHandler(_ => { calls++;
        return calls < 3 ? new HttpResponseMessage(HttpStatusCode.ServiceUnavailable)
                         : new HttpResponseMessage(HttpStatusCode.OK); });
    var sp = new ServiceCollection()
        .AddHttpClient("test").ConfigurePrimaryHttpMessageHandler(() => stub).AddStandardResilienceHandler()
        .Services.BuildServiceProvider();
    var http = sp.GetRequiredService<IHttpClientFactory>().CreateClient("test");
    Assert.Equal(HttpStatusCode.OK, (await http.GetAsync("https://example/health")).StatusCode);
    Assert.Equal(3, calls);
}
```

For integration tests, prefer the vendor's sandbox endpoint or a Testcontainer image where one exists.

## 16. Comment markers emitted by this skill

- `// PORT-IMPL:` — annotates the line where an adapter implements a port.
- `// RESILIENCE:` — annotates a resilience-handler registration or critical pipeline option.
- `// HANDLER-ORDER:` — annotates the `DelegatingHandler`-vs-resilience order at a registration site.

Canonical comment-markers index: `backend-architecture §7`.

## 17. References

- `backend-architecture §6, §7` — events/redelivery model + the marker index; the cross-cutting redelivery boundary in §11.
- `infrastructure-wiring` — registers the M2M token provider + `M2MTokenHandler`; chain-order rule is joint in §4.
- `backend-feature-patterns §9` — idempotency-key handler contract.
- `api-endpoint-patterns` — idempotency-key endpoint contract.
- `search-patterns` — concrete adapter (HTTP, bulk indexing, transient handling).
- `file-pipeline-patterns` — concrete adapters (SeaweedFS via S3-compat, nClam via TCP).
- `observability-backend` — OTel auto-instrumentation (Phase 5 placeholder).
- `.specify/memory/system-context.md` — project-specific upstream SLAs, timeout defaults, vendor inventory.
