# Observability Stack — Wiring & Deployment

This memory doc holds the one-time setup for the observability stack. Rules for what to emit, at what level, with what properties, live in `.claude/skills/observability-backend/SKILL.md` and `.claude/skills/observability-frontend/SKILL.md`.

## Stack components

| Layer | Tool | Status in V1 |
|---|---|---|
| Trace export (backend) | OTel SDK → OTel Collector → Tempo | live |
| Trace export (frontend) | OTel JS / RN → OTel Collector → Tempo | live |
| Log export (backend) | Serilog → OTel Collector → Loki | live |
| Metric export (backend + jobs) | OTel SDK → OTel Collector → Prometheus | live |
| Error capture (backend) | Sentry SDK → GlitchTip | **deferred from V1** |
| Error capture (frontend) | Sentry JS / RN SDK → GlitchTip | **deferred from V1** |
| Continuous profiles | Pyroscope | **deferred from V1** |
| Visualization | Grafana | live |
| Alerting | Prometheus rules → Alertmanager → Platform-Notifications | live |
| Uptime probing | Blackbox Exporter → Prometheus | **deferred from V1** |
| On-call escalation | Grafana OnCall | **not in V1** |
| User behavior | PostHog (anonymous) | live |
| Heatmaps (web) | Microsoft Clarity | live |

## Backend OTel SDK wiring (.NET 10)

High-level shape, not a copy-pasteable config. Pointers to the actual config files in `deploy/`.

**Packages:** `OpenTelemetry.Extensions.Hosting`, `OpenTelemetry.Exporter.OpenTelemetryProtocol`, `Serilog.AspNetCore`, `Serilog.Sinks.OpenTelemetry`, `Serilog.Enrichers.Span`, `Sentry.AspNetCore` (when GlitchTip lands).

**Registration:** `AddOpenTelemetry()` in `Program.cs` → `WithTracing(...)` + `WithMetrics(...)`.

**Sources to instrument:**

- FastEndpoints (HTTP server spans) — auto via `AddAspNetCoreInstrumentation`.
- HttpClient (HTTP outbound) — auto via `AddHttpClientInstrumentation`.
- EF Core (DB) — auto via `AddEntityFrameworkCoreInstrumentation`.
- Wolverine — `AddSource("Wolverine")`.
- Elsa — `AddSource("Elsa.Workflows")`.
- Hangfire — auto via `Hangfire.OpenTelemetry` filter (`OnCreating`/`OnPerforming` propagate `traceparent` across the job boundary).
- HybridCache — auto via `AddHybridCacheInstrumentation`.
- Polly via `Microsoft.Extensions.Http.Resilience` — auto-emitted (no extra registration).

**Startup validation (fail fast):** the host throws on startup if any of these are unset — `Observability:ServiceName`, `Observability:Environment`, `Observability:OtlpEndpoint`. Without `service.name` + `deployment.environment`, Loki labels become useless.

**Resource attributes (every signal carries these):**

| Attribute | Source | Example |
|---|---|---|
| `service.name` | env / config | `listings-api` |
| `service.namespace` | bounded context | `directory` |
| `service.version` | build metadata | `2026.05.18-a3f2c1d` (matches GlitchTip release id) |
| `service.instance.id` | hostname / pod | `listings-api-7d9c8-x4kp2` — resource attr only, never a Loki label |
| `deployment.environment` | env var | `prod` / `preprod` / `dev` |

## Serilog backend wiring

- **Sinks:** Console (local dev) + `Serilog.Sinks.OpenTelemetry` → Collector.
- **Enrichers:** `WithMachineName()`, `WithEnvironmentName()`, `WithSpan()` (attaches `TraceId` + `SpanId` from `Activity.Current`).
- **Level switch:** `LoggingLevelSwitch` bound to `IOptionsMonitor<ObservabilityOptions>.OnChange` so log level changes apply live without restart.
- **PII property scrubber:** custom `IDestructuringPolicy` applies the deny-list from `observability-backend §6`. Allow-list overrides via `Observability:PiiAllowFields` require a one-line PR justification (audited annually).

## Sentry trace-id alignment (deferred wiring — when GlitchTip lands)

- Sentry SDK config `BeforeSend` callback sets `event.contexts.trace.trace_id = Activity.Current?.TraceId.ToString()`.
- Effect: error issues link back to the Tempo trace via the shared trace_id. One click moves between an error and the full request span tree.
- Sentry release identifier matches `service.version` resource attribute — same string in OTel and GlitchTip so you can pivot between them.
- `BeforeSend` also applies the PII deny-list (defense in depth — collector also redacts).
- Use `UseSentry()` on the host; `o.TracesSampleRate = 0` (tracing handled by OTel — Sentry only captures errors).

## OTel Collector

- Single Collector deployment receives OTLP from all backend services + frontend surfaces.
- Routes: traces → Tempo; logs → Loki; metrics → Prometheus.
- **Same S3 bucket** for Tempo, Loki, and Pyroscope (when deferred items land).
- Prometheus uses local storage (not S3).
- Tail sampling is a commented-out block in the Collector config — uncomment when trace volume justifies it.
- Loki label allow-list is enforced via a Collector attribute-filter processor (see `observability-backend §7`).

## Frontend wiring shapes

| Surface | OTel JS init | Sentry init | PostHog | Clarity |
|---|---|---|---|---|
| Next.js portal | `instrumentation.ts` + `afterInteractive` lazy register | `sentry.client.config.ts` (deferred until GlitchTip live) | Lazy-load via dynamic import **after consent** | Lazy-load via dynamic import **after consent** |
| Admin SPA (Vite) | App-entry `requestIdleCallback` lazy init | App-entry, synchronous, before React mounts | Lazy-load after consent | **NOT loaded** — admin sees PII |
| RN (Expo) | OTel RN with explicit `traceparent` on fetch wrappers | `Sentry.ReactNativeTracing` integration | PostHog RN SDK after consent | n/a (Clarity not supported on RN) |

- **Runtime config delivery:** the BFF exposes `GET /api/runtime-config` returning the canonical `RuntimeConfig` JSON shape. Cache-Control: `public, max-age=60, s-maxage=60`. Failure mode is OFF — on error, return a fully-disabled config. Never 5xx (a config outage must not break the frontend).
- **Mutable holder pattern:** `runtimeHolder: { current: RuntimeConfig }` shared object. OTel custom `Sampler.shouldSample()` reads `runtimeHolder.current.otel.sampleRate`; Sentry `tracesSampler: () => runtimeHolder.current.sentry.tracesSampleRate`.
- **Source-map upload:** every production build uploads via `sentry-cli` (web) or `@sentry/react-native` Expo plugin (RN). Release identifier = `service.version`.

## Loki label allow-list (governance)

Allow-list lives verbatim in `observability-backend §7`. Enforced in the Collector config via an attribute-filter processor. **Forbidden as labels** (must be log-line fields, queryable via `| json`): `trace_id`, `span_id`, `user_id`, `tenant_id` (when high-card), `aggregate_id`, `idempotency_key`, `route` (with parameters), `error_code`.

## Grafana datasources

- Tempo (traces), Loki (logs), Prometheus (metrics) — three Grafana datasources.
- Cross-correlation: TraceQL → LogQL via shared `trace_id` field. Loki "Derived fields" config extracts `trace_id` from log lines and links to Tempo.

## Alertmanager rules

- Live in `deploy/prometheus/alerts/*.yaml`.
- Categories: SLO burn, error-rate spike, dependency unavailability, queue depth, saga failure rate.
- Route via Platform-Notifications integration.
- OnCall escalation: not in V1; alerts land in the Platform-Notifications channel for triage.

## Operational controls (live-tunable knobs)

All apply via ConfigMap reload; no pod restart required.

| Knob | Field | Effect | Propagation |
|---|---|---|---|
| Disable tracing | `Observability:TracingEnabled=false` | Custom `Sampler` returns `Drop` | ~5s |
| Throttle trace sample rate | `Observability:TraceSampleRate=0.01` | Per-span decision uses new rate | ~5s |
| Adjust Serilog level | `Observability:LogMinimumLevel=Warning` | `LoggingLevelSwitch` applies live | ~5s |
| Add PII deny entries | `Observability:AdditionalPiiDenyFields=[...]` | Destructuring policy reads new list per event | ~5s |
| Allow specific PII field | `Observability:PiiAllowFields=[...]` | Bypass redaction (PR-justified) | ~5s |

What you cannot change at runtime in .NET OTel: provider composition (instrumentations, exporters). That's a deploy.

Frontend knobs apply via BFF env-var change → next runtime-config fetch (~60s). Mobile changes apply on next app cold start (config cached in AsyncStorage).

## Deferred-from-V1 follow-up tasks

- GlitchTip deployment + Sentry SDK trace-id alignment wiring (backend + frontend).
- Pyroscope deployment + profiling enablement.
- Blackbox Exporter for external dependency probes.
- Grafana OnCall integration.

## What's NOT in this doc

- Rules for what to emit / at what level / what properties — see `.claude/skills/observability-backend/SKILL.md` and `.claude/skills/observability-frontend/SKILL.md`.
- Per-stack-component observability cross-refs — those live in each relevant stack skill (`orchestration-patterns`, `data-access-patterns`, etc.).
- Working Collector YAML / Grafana provisioning JSON — those live in `deploy/observability/`. This doc is the architectural shape, not the deploy artifacts.
