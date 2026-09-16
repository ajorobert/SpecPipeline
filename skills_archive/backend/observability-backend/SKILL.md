---
name: observability-backend
description: |
  Backend observability rules for .NET 10: traces, logs (Serilog structured), metrics, error sink (GlitchTip via Sentry SDK). Covers what to emit, at what level, with what properties, and the PII deny-list. Per-component conventions for the dispatch seam, EF, Hangfire, Elsa, HybridCache, FastEndpoints, and Polly. Wiring/deployment lives in `.specify/memory/observability-stack.md`, not here.
when_to_load:
  - Task mentions: log, logging, trace, tracing, span, metric, error, observability, instrumentation, telemetry, sentry, glitchtip, serilog
  - Files touched: any code that emits ILogger calls, ActivitySource calls, or metric increments
co_loads_with:
  - backend-architecture (canonical seams, structure, markers, events model — read first)
  - backend-feature-patterns (handler observability)
references:
  - infrastructure-wiring, data-access-patterns, caching-patterns, search-patterns, authorization-patterns, file-pipeline-patterns, orchestration-patterns, integration-adapter-patterns, api-endpoint-patterns (each has a §observability note)
  - .specify/memory/observability-stack.md (one-time wiring / deployment)
---

# Observability — Backend Rules

## 1. Mental model — three signals + one error sink

| Signal | Destination | What it answers |
|---|---|---|
| **Traces** (OTel) | Tempo | What HAPPENED — request path through services, with timings and parent-child relationships |
| **Logs** (Serilog structured) | Loki | What was OBSERVED at a point in time — discrete events with structured properties |
| **Metrics** (OTel) | Prometheus | COUNTS over time — for dashboards, alerting, SLO measurement |
| **Errors** (Sentry SDK) | GlitchTip *(deferred from V1)* | UNEXPECTED exceptions — for incident triage |

Rule of thumb: one event → all four signals possible, but choose what's USEFUL. Over-instrumentation has cost. Spans propagate trace-id via the W3C `traceparent` header; Sentry SDK is configured so `sentry.trace_id == OTel trace ID` for cross-correlation.

Wiring (`AddOpenTelemetry`, Serilog sinks, Sentry SDK init, Collector endpoints) lives in `.specify/memory/observability-stack.md`. This skill answers WHAT to emit. The memory doc answers HOW to wire it up.

## 2. Trace rules

Auto-spans for free: FastEndpoints (HTTP), the dispatch seam (command/query + message handling, produced by `infrastructure-wiring`'s bus impl), EF Core (DB), Polly via `Http.Resilience` (HTTP outbound), HybridCache (cache ops) — all emit spans automatically when the OTel SDK is wired.

**Add a custom span when:**

- The operation is >5ms and not already covered by an auto-span.
- The operation is a meaningful business boundary (e.g. `process.image-variant`, `geo.search-expansion`).
- You need to attach business attributes that auto-spans don't carry.

**Don't add a span for:**

- Trivial CPU work (<1ms).
- Operations already wrapped by an auto-span.
- Tight loops (one span per iteration kills the trace).

**Naming convention:** `<verb>.<noun>` (e.g. `process.image-variant`) or `<aggregate>.<operation>` (e.g. `listing.activate`).

**Attributes:** use OTel semantic conventions (`http.*`, `db.*`, `messaging.*`) where applicable. Custom attributes prefixed `your_context.*` (snake_case, dot-separated).

```csharp
private static readonly ActivitySource Source = new("YourContext.Listings");

public async Task<Result> Handle(GenerateVariantsCommand cmd, CancellationToken ct)
{
    // SPAN: business-meaningful boundary not covered by an auto-span
    using var activity = Source.StartActivity("process.image-variant");
    activity?.SetTag("your_context.aggregate_id", cmd.UploadId);
    activity?.SetTag("your_context.variant_count", cmd.Variants.Count);

    var result = await _processor.ProcessAsync(cmd, ct);
    if (result.IsError) activity?.SetStatus(ActivityStatusCode.Error, result.Errors[0].Code);
    return result;
}
```

## 3. Log rules

Serilog structured logging only via `ILogger<T>` (Microsoft abstraction; Serilog is the sink). Use message templates with structured properties; **never** string interpolation.

```csharp
// WRONG — opaque to Loki; can't filter by UserId
_log.LogInformation($"User {userId} did X");

// RIGHT — UserId indexed as a structured property
// LOG: structured property — UserId is a log-line field, not a Loki label (see §7)
_log.LogInformation("User {UserId} did X", userId);
```

Structured property naming: PascalCase in code (`UserId`, `TenantId`, `AggregateId`); Serilog flattens to `user_id` in Loki/JSON. **Trace correlation auto-attached:** the Serilog `WithSpan` enricher pins `TraceId` and `SpanId` on every log line. Don't log what's already on a span attribute — duplication.

## 4. Log level decision rule

| Level | When | Example |
|---|---|---|
| `Verbose` / `TRACE` | Almost never. Only in tight loops you're actively profiling. Off in production. | "Iterating row 1234 of bulk reindex" |
| `Debug` | Internal state useful during local dev. Off in production. | "Cache miss for key {Key}, falling through to source" |
| `Information` | Significant business events worth keeping in production. **Default level for production.** | "Listing {ListingId} activated by user {UserId}" |
| `Warning` | Recoverable abnormal condition. Worth attention but didn't break anything. | "Retry exhausted on {VendorName} after {Count} attempts; fallback used" |
| `Error` | Operation failed and was NOT recovered. Needs human attention. **Auto-captured by Sentry SDK → GlitchTip.** | "Saga {SagaName} step {Step} failed permanently for {AggregateId}" |
| `Fatal` / `Critical` | Process-level failure imminent. Rare. | "Database connection pool exhausted; service degraded" |

**Critical rule:** if you find yourself logging at ERROR for a recoverable condition (caught and handled), that's a WARN. ERROR means "human, look at this."

## 5. Metric rules

| Kind | Use for |
|---|---|
| **Counter** | Monotonically-increasing count (events, completions, errors) |
| **Histogram** | Distribution (latency, payload size, time-to-process) |
| **Gauge** | Point-in-time measurement (queue depth, connection count) — used sparingly |

**Naming:** `your_context_<aggregate>_<operation>_<unit>_<suffix>` per Prometheus conventions:
- `_total` (counter), `_seconds` (histogram for latency), `_bytes` (histogram for size), `_count` (gauge).
- Example: `your_context_listings_activated_total`, `your_context_listings_geosearch_latency_seconds`.

**Cardinality rule (critical):** label values must be **bounded**. High-cardinality labels (UserId, request URL with params, free-text error messages) break Prometheus.

| Safe label values | Unsafe — never use as a metric label |
|---|---|
| `aggregate_type`, `operation`, `outcome` (success/failure) | `user_id`, `aggregate_id` (per-row) |
| `tenant_id` (only if total tenants ≤ ~100s) | `error_message` (free text) |
| HTTP method, status-code class (2xx/4xx/5xx) | Full request URL with query string |

For per-tenant or per-user breakdowns, aggregate from logs in Grafana — don't pay the per-label-value cardinality cost in Prometheus.

```csharp
public sealed class ListingMetrics(IMeterFactory factory)
{
    private readonly Counter<long> _activated = factory.Create("YourContext.Listings")
        .CreateCounter<long>("your_context_listings_activated_total");
    private readonly Histogram<double> _latency = factory.Create("YourContext.Listings")
        .CreateHistogram<double>("your_context_listings_geosearch_latency_seconds");

    // METRIC: counter + histogram with bounded labels only
    public void RecordActivation(string region, string outcome) =>
        _activated.Add(1, new("region", region), new("outcome", outcome));
    public void RecordSearchLatency(double seconds, string region) =>
        _latency.Record(seconds, new("region", region));
}
```

## 6. PII deny-list (critical)

> **Rule:** Never include the following in log properties, span attributes, or metric labels: email, phone, full name, exact date-of-birth, payment card data (PAN, CVV), government IDs (SSN, passport, etc.), full street address, JWT tokens, API keys, passwords, OAuth tokens, IP for residents (region/country-code only is OK), session IDs.

| Category | Rule |
|---|---|
| Always allowed | `user_id` (Guid), `tenant_id`, `aggregate_id`, error codes (NOT error messages with sensitive content), HTTP status codes, latency, payload sizes |
| Always denied | Listed above — passwords, tokens, secrets, full PII |
| Borderline (case-by-case; default DENY) | `preferred_username` (depends on org policy), partial IP for rate-limiting context (first 3 octets only, last octet zeroed) |

**Cross-stack rule:** the same deny-list applies to frontend (`observability-frontend §6` duplicates this list — both skills load independently). Enforcement: a Serilog property scrubber and an OTel span processor apply the list; wiring lives in the memory doc.

```csharp
public async Task<Result> Handle(CreateAccountCommand cmd, CancellationToken ct)
{
    var result = await _service.CreateAsync(cmd, ct);
    // SENSITIVE: cmd.Email and cmd.Phone deliberately excluded; user_id only
    _log.LogInformation("Account created for user {UserId} in tenant {TenantId}",
        result.Value.UserId, result.Value.TenantId);
    return Result.Success;
}
```

## 7. Loki label allow-list (cardinality protection)

Loki indexes labels but not properties. Wrong label choice → cardinality explosion → ingestion slowdown → cost.

**Allowed labels (5–8 max per log line):** `service.name`, `service.namespace`, `service.version`, `env`, `level`, `tenant_id` (only if bounded tenant count), `aggregate` (only if bounded — listings, vendors, uploads, etc.).

**NOT labels — use structured properties; filter via LogQL:** `user_id`, `aggregate_id` (per-row), `idempotency_key`, `route` (with parameters), `error_code`, `trace_id`, `span_id`.

One-line: if it's high-cardinality OR per-request unique, it's a property, not a label.

## 8. OTel ↔ Sentry trace correlation (the bridge)

> **Rule:** Sentry SDK MUST be configured so `sentry.trace_id == OTel trace ID`. Wiring lives in `.specify/memory/observability-stack.md`. Effect: GlitchTip error issues link back to the originating Tempo trace via the trace_id; one click moves between error and the full request span tree.

What happens on an ERROR-level log with an exception: Serilog's Sentry sink auto-captures the exception, attaches `Activity.Current.TraceId`, fires to GlitchTip.

What you do in code: nothing manual. Log at ERROR with the exception object — `_log.LogError(ex, "Operation failed: {Operation}", op)`. The bridge happens automatically.

**Anti-pattern:** manually calling `SentrySdk.CaptureException(ex)` in a handler — duplicates the auto-capture and breaks the trace correlation.

## 9. Custom span pattern

```csharp
public sealed class IndexerService(/* deps */)
{
    private static readonly ActivitySource Source = new("YourContext.Search");

    public async Task<Result> Reindex(string alias, CancellationToken ct)
    {
        // SPAN: business-meaningful boundary
        using var activity = Source.StartActivity("search.reindex");
        activity?.SetTag("your_context.alias", alias);

        var result = await DoReindexAsync(alias, ct);
        if (result.IsError)
            activity?.SetStatus(ActivityStatusCode.Error, result.Errors[0].Code);
        return result;
    }
}
```

Spans nest automatically inside the parent (caller's span); don't fight that. One `ActivitySource` per bounded context.

## 10. Health checks

**In-app health endpoints:**

| Endpoint | Probes | Failure semantics |
|---|---|---|
| `/health/live` | Process is alive — **don't probe DB or upstreams** | Process is restarted by orchestrator |
| `/health/ready` | Process can serve traffic — may probe DB, Keycloak JWKS | Pod removed from load-balancer rotation |

Rule: don't probe DB from `/live` — a DB hiccup → all pods restart → cascade outage.

**External probes via Blackbox Exporter** for external SaaS dependencies (vendor APIs, Elasticsearch cluster reachability). **Deferred from V1.**

## 11. Dispatch-seam / handler observability

The bus + outbox spans are produced by the dispatch seam (`infrastructure-wiring`'s bus impl); handlers stay library-agnostic.

- **Auto-spans:** a span per command/query/message `Handle` invocation with message type as an attribute.
- **Auto-metrics:** message processing latency, retry count, dead-letter count — all per message type (bounded cardinality).
- **What you add:** log at INFO at the end of a state-mutating handler with `AggregateId` + `Operation` (cross-ref `backend-feature-patterns §3`).
- **Sagas:** each saga step is its own span; saga state changes log at INFO with `SagaId` + `Step` (see `orchestration-patterns`).
- **Outbox publish:** instrumented as a span linked to the parent handler span; consumer-side handler span links back via `traceparent` carried in message headers.

## 12. Hangfire job observability

- **Auto-spans:** Hangfire instruments via OTel `Hangfire.Activity`; each job execution is a span.
- **Custom: cron-job idempotency check** — log at INFO with `JobId` + `Cron` + `Outcome` (`executed` / `skipped-idempotent`).
- **Failures:** job exceptions auto-bubble to ERROR + Sentry capture via the Hangfire exception filter pipeline (wiring; rule is the property name `JobId`).

## 13. Elsa workflow observability

- **Auto-spans:** each activity execution is a span (Elsa emits via `ActivitySource`).
- **Workflow-level metric:** instances started/completed/faulted counters keyed by workflow definition name (bounded cardinality).
- **Bookmark resume:** trace context carried via the resume signal — bookmark-create span and bookmark-resume span share a `workflow_id` attribute.

## 14. HybridCache observability

- **Auto-metrics:** L1 hit / L2 hit / miss counters per cache tag (the bounded part); latency histogram.
- **What you add:** rarely anything. Auto-emission covers the common cases.
- **Cache invalidation events:** log at INFO when an integration-event handler fires `RemoveByTagAsync` (cross-ref `caching-patterns`).

## 15. HTTP-client / Polly observability

- **Auto-spans:** every outbound HTTP via typed `HttpClient` emits a span (covered by `integration-adapter-patterns`).
- **Auto-metrics:** retry count, circuit-breaker state changes, timeout events — all auto-emitted by `Microsoft.Extensions.Http.Resilience`.
- **What you do:** nothing. Don't manually log retries in adapter code — duplicates the auto-emission.

## 16. FastEndpoints observability

- **Auto-spans:** every HTTP request is a span (the root of most server-side traces).
- **Attributes:** `http.method`, `http.route`, `http.status_code` (OTel semconv) auto-set.
- **What you add:** for endpoints that fan out to multiple handlers / external calls, add `your_context.operation` as a span attribute to make Tempo searches easier.

## 17. Anti-patterns

- String-interpolated log messages (kills structured-property indexing).
- Logging PII in any signal (see §6).
- High-cardinality labels in Prometheus or Loki (see §5, §7).
- Manually logging what's auto-spanned (e.g. "called Elasticsearch" inside an HttpClient call).
- Logging at INFO inside a tight loop.
- `Console.WriteLine` anywhere; `Debug.WriteLine` anywhere.
- ERROR level for a recoverable condition (it's a WARN — see §4).
- Probing DB from `/health/live` (cascade failure risk).
- Manually calling `SentrySdk.CaptureException` (breaks auto-correlation — see §8).
- Metric labels that aren't enumerated and bounded.
- Custom spans inside tight loops.
- Logging without the `TraceId` enricher (rule: every log MUST carry `TraceId` + `SpanId`).

## 18. Comment markers emitted by this skill

- `// LOG:` — non-obvious logged property choice.
- `// SPAN:` — custom span start.
- `// METRIC:` — metric emission line.
- `// SENSITIVE:` — annotates a deliberately-excluded property (PII or otherwise).

Canonical comment-markers index: `backend-architecture §7`.

## 19. References

- `backend-architecture §7` — canonical comment-markers index.
- `backend-feature-patterns §3` — handler observability touchpoints.
- `infrastructure-wiring` — the dispatch-seam bus + outbox spans; message + saga auto-emission.
- `data-access-patterns` — DB observability auto-emission.
- `caching-patterns` — cache observability + invalidation events.
- `search-patterns` — ES client observability.
- `authorization-patterns` — audit-log property conventions.
- `file-pipeline-patterns` — scan / upload state-change events worth logging.
- `orchestration-patterns` — Elsa + Hangfire OTel propagation.
- `integration-adapter-patterns §12` — adapter OTel auto-instrumentation.
- `api-endpoint-patterns` — endpoint observability auto-emission.
- `.specify/memory/observability-stack.md` — one-time wiring: `AddOpenTelemetry` builder, Collector config, Tempo/Loki/Prometheus/GlitchTip endpoints, Serilog enricher registration, Sentry SDK trace-id alignment.
