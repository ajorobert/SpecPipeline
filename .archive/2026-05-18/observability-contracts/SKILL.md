---
name: observability-contracts
description: "Load when: any work touches observability — every observability-{backend,frontend,infra} skill references this. Canonical source for resource attribute schema, W3C trace context rules, runtime-config JSON shape, PII deny-list, Loki label allow-list, span naming, error-tracking conventions. Stable, changes require ADR."
---

# Observability Contracts

## Purpose
The seams that make backend, frontend, and infra observability one mental model instead of three. Every other `observability-*` skill is an implementation of these contracts. **Change here → ADR required**, because frontend, backend, and collector all depend on these shapes matching.

If you only load one observability skill, load this one — it tells you the contract; the others tell you how to implement it on a specific surface.

## Pipeline (one-line summary)
```
SDKs (front + back) ─OTLP─► OTel Collector ─► Jaeger | Loki | Prometheus
                       └──────► GlitchTip (errors, Sentry-compatible DSN)
```

* **OTel SDK is the only instrumentation API.** Never call Jaeger/Prometheus/Loki client libraries directly from application code.
* **OTel Collector is the only egress point.** Services and frontends never talk to Jaeger/Loki/Prometheus directly. This lets PII redaction, sampling, and batching happen once, in one place.
* **Errors go to GlitchTip via Sentry SDK.** GlitchTip is Sentry-API-compatible; the destination is GlitchTip, the SDK is `Sentry.*`.

## Resource Attribute Schema (mandatory on every signal)
Every service and every frontend MUST emit these resource attributes via OTel SDK. Missing values fail-fast at startup.

| Attribute | Source | Example | Notes |
|---|---|---|---|
| `service.name` | env / config | `listings-api` / `customer-portal` | Bounded; becomes Loki `service` label |
| `service.namespace` | bounded context | `directory` | Optional but encouraged |
| `service.version` | build metadata | `2026.04.29-a3f2c1d` | Same string as GlitchTip release ID |
| `service.instance.id` | hostname / pod | `listings-api-7d9c8-x4kp2` | High-cardinality — resource attr only, **never** a Loki label |
| `deployment.environment` | env var | `prod` / `preprod` / `dev` | Becomes Loki `env` label |

**Without `service.name` + `deployment.environment`, dashboards break** — every implementation skill enforces a startup check.

## W3C Trace Context (the only propagation format)
Use **W3C Trace Context** (`traceparent`, `tracestate`) everywhere. Never B3, never Jaeger native — they don't survive cleanly across .NET/JS/RN boundaries.

| Hop | Who is responsible |
|---|---|
| Browser → BFF | OTel JS auto-instrumentation injects `traceparent` on `fetch`/`XHR` |
| BFF → service (HTTP) | `HttpClient` auto-instrumentation propagates |
| HTTP → MediatR/in-process | Activity flows through async context — no work needed |
| Command handler → Wolverine outbox → consumer | Wolverine envelope must carry `traceparent` header (see `observability-backend`) |
| MassTransit producer → consumer | OTel MassTransit instrumentation propagates automatically |
| Anywhere → Hangfire job | Capture context at enqueue, restore inside job filter (see `observability-backend`) |
| Service → Serilog log line | `TraceId`/`SpanId` enriched as structured fields, not labels |

**Every log line MUST include `TraceId` and `SpanId` as structured fields when an Activity is active.** They are log-line fields, not Loki labels (see Loki Label Allow-List).

## Span Naming Conventions
Follows OTel semantic conventions; the Hangfire/Wolverine entries are project conventions where no semconv exists.

| Surface | Span name format | Example |
|---|---|---|
| HTTP server | `<METHOD> <route-template>` | `POST /api/v1/listings/{id}/activate` |
| HTTP client | `<METHOD>` (target on `server.address` attr) | `GET` |
| Database | `<db.operation> <db.collection>` | `SELECT listings`, `INSERT outbox_messages` |
| Messaging consumer | `<messaging.destination> receive` | `listing.activated.v1 receive` |
| Messaging producer | `<messaging.destination> publish` | — |
| Wolverine handler | `wolverine.handle <MessageType>` | `wolverine.handle ActivateListingCommand` |
| Hangfire job | `hangfire.job <JobName>` | `hangfire.job ListingExpiryJob` |

Required span attributes for messaging: `messaging.system`, `messaging.operation` (`receive`/`publish`), `messaging.destination`.

## Runtime Configuration Contract
Single JSON shape, served by the BFF at `GET /api/runtime-config`, consumed by all three frontends. Backend services bind a parallel `ObservabilityOptions` from ConfigMap. **Schema changes require ADR + bumping `schemaVersion`.**

### Frontend JSON shape (canonical)
```ts
type RuntimeConfig = {
  schemaVersion: 1;
  otel: {
    enabled: boolean;
    endpoint: string;          // OTel Collector OTLP HTTP receiver
    sampleRate: number;        // 0..1, applied per-trace at SDK
  };
  sentry: {
    enabled: boolean;
    dsn: string;
    environment: string;
    release: string;
    tracesSampleRate: number;  // mutable via tracesSampler callback
    errorsSampleRate: number;  // applied at init only — change requires re-init (SDK limitation)
  };
  posthog: {
    enabled: boolean;
    apiKey: string;
    host: string;              // self-hosted PostHog URL
    autocapture: boolean;
    sessionRecording: boolean; // recording sample rate is server-side per project
  };
  clarity: {
    enabled: boolean;
    projectId: string;         // empty string when disabled
  };
};
```

### Failure mode is OFF
If the runtime-config endpoint fails, returns malformed JSON, returns the wrong `schemaVersion`, or times out, frontends MUST default every tool to `enabled: false`. A config outage degrades observability, never the user-facing app.

### Backend `ObservabilityOptions` (canonical fields)
```csharp
public sealed record ObservabilityOptions
{
    public bool TracingEnabled { get; init; } = true;
    public double TraceSampleRate { get; init; } = 1.0;     // 0..1
    public bool MetricsEnabled { get; init; } = true;
    public string LogMinimumLevel { get; init; } = "Information";
    public IReadOnlyList<string> AdditionalPiiDenyFields { get; init; } = [];
    public IReadOnlyList<string> PiiAllowFields { get; init; } = [];
}
```

Bound via `IOptionsMonitor<ObservabilityOptions>`. Source priority (later wins): `appsettings.json` → env vars → mounted ConfigMap file (file provider with `reloadOnChange: true`).

### SDK runtime-mutability matrix (verified — do not invent)

| SDK | Disable at runtime | Change sample rate at runtime | Mechanism |
|---|---|---|---|
| OTel JS (web/RN) | ✗ no public detach API | ✗ sampler frozen at `TracerProvider` construction | Workaround: custom sampler reads mutable holder per `shouldSample()` |
| Sentry JS (errors) | ✗ no close-without-reinit | Partial — `tracesSampler` callback is mutable; `sampleRate` (errors) is not | Use `tracesSampler` not `tracesSampleRate`; errors require re-init |
| PostHog JS | ✓ `opt_out_capturing()` / `opt_in_capturing()` | Partial — autocapture via `set_config()`; recording rate is project-side | Document: recording rate is server-side |
| Clarity | ✗ no runtime API once loaded | ✗ no runtime sample-rate control | Conditional `<Script>` load only |
| .NET OTel | ✗ provider built once | ✓ via custom `Sampler` reading `IOptionsMonitor` | See `observability-backend` |
| Serilog | ✓ `LoggingLevelSwitch.MinimumLevel` | n/a (level not rate) | Bind to `IOptionsMonitor.OnChange` |

## PII Redaction Contract (defense in depth)
Two layers, never one:
1. **In-process** (Serilog destructuring + OTel span processor for backend; `beforeSend` / `sanitize_properties` for frontend). Authoritative.
2. **At the collector** (attribute processor). Backstop for misconfigured services and third-party libraries.

### Canonical deny-list (case-insensitive, matched on field name)
```
password, passwd, pwd
secret, token, api_key, apikey, authorization
ssn, sin, tax_id, national_id
email, email_address          (PII; redact unless explicitly allow-listed)
phone, phone_number, mobile
credit_card, card_number, cvv, pan
date_of_birth, dob
address, street, postal_code, zip
ip_address, ip                (regulated as PII in EU)
```

* Redacted values become `[REDACTED]`. **Never hash** (rainbow-table risk on bounded sets like phone numbers).
* Per-service additions go in `Observability:AdditionalPiiDenyFields`.
* Per-service allow-overrides go in `Observability:PiiAllowFields` and **require a one-line PR justification**. Audit annually.

## Loki Label Allow-List (READ THIS BEFORE TOUCHING LABELS)
Loki indexes by label combinations. High-cardinality labels destroy query performance and OOM the ingester. The allow-list is explicit:

**Allowed Loki labels** (bounded cardinality):
* `service` (= `service.name`)
* `env` (= `deployment.environment`)
* `level` (bounded enum: `debug|info|warn|error|fatal`)

**Forbidden as labels** — must be log-line fields, queryable via `| json`:
* `trace_id`, `span_id` — unbounded
* `user_id`, `tenant_id`, `customer_id` — unbounded
* `request_id`, `correlation_id` — unbounded
* `endpoint_path`, `route`, `url` — high cardinality with parameterized routes
* `status_code` — looks bounded but combines multiplicatively
* `host`, `pod`, `instance` — covered by `service.instance.id` resource attr

The forbidden list lives verbatim as a banner comment at the top of `infra/observability/otel-collector-config.yaml`:
> `# NEVER add anything to this list without checking cardinality first.`
> `# Each new label multiplies the index size; we have killed Loki ingesters at 3am over a single innocent-looking label. Trace/user/request IDs go IN the log line, not on it.`

## Sampling Defaults
* **Default: 100% head sampling** (`AlwaysOn`). Storage cost is the constraint, not collection cost; sample down at the collector.
* **Tail sampling** lives in collector config as a commented-out block (see `observability-infra`). Uncomment when trace volume justifies it.
* **Frontend RUM**: 100% for errors, 10% for performance traces (browsers are noisy; head-sample at SDK).
* Sampling is **deterministic on `traceId`** so a sampled trace stays sampled across services.

## Error Tracking Convention (GlitchTip)
* GlitchTip is Sentry-API-compatible — use `Sentry.*` SDKs everywhere.
* DSN per service per environment in env var `SENTRY_DSN` (named for SDK compatibility).
* **Release identifier matches `service.version` resource attribute** — same string in OTel and GlitchTip so you can pivot between them.
* `traceparent` is attached to every GlitchTip event so an error in GlitchTip links to the trace in Jaeger.
* `BeforeSend` hook applies the same PII deny-list as the OTel pipeline.
* **Convention**: GlitchTip = unhandled / fatal; OTel logs = handled / warning. Do **not** log the same error to both.

## Metrics Conventions
* Use OTel `Meter` API only. Never `prometheus-net` directly.
* **Required RED on every HTTP endpoint** (auto-instrumented):
  * `http.server.request.duration` (histogram, seconds)
  * `http.server.request.count` (counter)
  * `http.server.request.errors` (counter, filtered to 5xx)
* **Required for every consumer / job**:
  * `messaging.consumer.duration`, `messaging.consumer.errors`
  * `hangfire.job.duration`, `hangfire.job.failures`
* **Custom business metrics**: prefix with bounded-context name — `directory.listings.activated.count`.
* **Cardinality budget**: max 100 unique label combinations per metric. User/tenant-scoped data goes to logs, not metrics.

## When to Use
* Any observability work — load this first.
* Reviewing whether a proposed implementation matches the contract.
* Writing or updating an ADR that touches observability.

## When NOT to Use
* Hands-on implementation — load `observability-backend`, `observability-frontend`, or `observability-infra` for that.
* Application-specific business metric design — covered by `design-principles`.
* Frontend behavioural analytics design (PostHog/Clarity event taxonomy) — different concern.
