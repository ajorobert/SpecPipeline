---
name: observability-infra
description: "Load when: editing OTel Collector config, deploying or replacing Loki/Jaeger/Prometheus/GlitchTip, building Grafana dashboards, tuning tail sampling, or planning a backend swap. Canonical otel-collector-config.yaml lives in infra/observability/. Read observability-contracts first."
---

# Observability — Infrastructure

## Purpose
Deployment, configuration, and operations of the observability backends — OTel Collector, Loki, Jaeger, Prometheus, GlitchTip — and the Grafana dashboards that sit on top of them. Owns the canonical collector config, the Loki label allow-list enforcement, the tail-sampling block, the PII redaction backstop, and "what changes if you swap a backend."

**Read `observability-contracts` first.** The contracts (resource attrs, deny-list, label allow-list) constrain what this skill can deploy.

## Core Rules

### Topology
```
                      ┌─────────────────────────┐
                      │      OTel Collector     │
                  ────►  receivers → processors │
                      │           → exporters   │
                      └──┬──────┬────────┬──────┘
                         │      │        │
                  traces ▼  metrics ▼  logs ▼
                     Jaeger  Prometheus  Loki

  Errors (separate path):  Sentry SDKs → GlitchTip
```

* **OTel Collector is the only egress point** for traces/metrics/logs. Services and frontends do not connect to Jaeger/Loki/Prometheus directly.
* **GlitchTip runs separately** with its own Sentry-compatible ingest. It is not behind the collector.
* **No vendor lock-in.** Every component (Loki, Jaeger, Prometheus, GlitchTip) is on-prem, open-source, and swappable. Swap notes below.

### Repository Layout (canonical)
The collector config lives **in the source repo**, not just in deployment infra. Pre-prod and prod must run byte-identical configs so prod issues reproduce in pre-prod.

```
infra/
  observability/
    otel-collector-config.yaml          # canonical, env-templated — source of truth
    otel-collector-config.preprod.yaml  # generated, do not edit
    otel-collector-config.prod.yaml     # generated, do not edit
    grafana-dashboards/
      service-red.json                  # request rate / errors / duration per service
      messaging-overview.json           # consumer lag, retries, dead-letters
      logs-overview.json                # log volume by service/level
      slo-overview.json                 # service SLO burn rate
    prometheus-rules/
      service-slo.yaml                  # recording + alerting rules
    loki/
      retention.yaml                    # retention policy
    jaeger/
      sampling-strategies.json          # only relevant if not using OTel tail sampling
    glitchtip/
      README.md                         # rate limits, project setup, source-map upload
    README.md
```

**Deviations between pre-prod and prod require an ADR.** The canonical config is the reference; deployment infra (Helm, Terraform) renders the env-specific files from it.

### Loki Label Allow-List Enforcement
The collector config is the enforcement point for the label allow-list defined in `observability-contracts`. The Loki exporter MUST hardcode only `service`, `env`, `level` as labels. The banner comment at the top of the config is non-negotiable:

> `# NEVER add anything to this list without checking cardinality first.`
> `# Each new label multiplies the index size; we have killed Loki ingesters at 3am over a single innocent-looking label. Trace/user/request IDs go IN the log line, not on it.`

Any PR that adds a label must:
1. Justify cardinality bound in the PR description
2. Carry an ADR
3. Include a Loki query showing the new label's distinct-value count over 7 days

### PII Redaction Backstop
The collector applies PII redaction as a **second layer** behind in-process redaction (Serilog destructuring + `beforeSend` hooks). This catches:
* Misconfigured services (someone forgot the destructuring policy)
* Third-party libraries that log directly to OTel without going through Serilog
* Future services not yet onboarded to the in-process layer

Use the `attributes` processor with the canonical deny-list. Treat the collector layer as defense-in-depth — never as the primary line.

### Tail Sampling
Default: **off** (commented out). Head sampling at the SDK is the cheaper-to-reason-about default. Uncomment tail sampling when:
* Trace volume × storage cost makes head sampling at 100% impractical, AND
* You have observed that tail-sampling decisions (keep all errors, all slow, X% normal) would materially reduce volume without losing diagnostic value.

When enabled, the policy MUST keep:
* All traces with status `ERROR`
* All traces above the latency threshold (default 2000ms)
* A probabilistic sample of normal traffic (default 10%)

### Backend Retention
Set explicit retention per backend; don't rely on defaults.

| Backend | Default retention | Rationale |
|---|---|---|
| Loki | 30 days hot, 90 days archive | Logs are volume-heavy; older logs are rarely queried |
| Jaeger | 7 days | Traces are volume-heaviest; pair with sampling |
| Prometheus | 15 days local, 1 year via remote write to Mimir/Thanos | Metrics are cheapest, longest history justified |
| GlitchTip | 90 days | Errors should be triaged and closed within this window |

### Health Checks
Every backend exposes a health endpoint scraped by Prometheus. Alert on:
* OTel Collector pipeline drops > 0 for > 5 min
* Loki ingester memory > 80%
* Jaeger collector queue depth > threshold
* Prometheus scrape failures > 1% over 10 min
* GlitchTip ingestion lag > 1 min

## Canonical Collector Config

```yaml
# =============================================================================
# OTel Collector — canonical config. Pre-prod and prod render from this file.
# Deviations require an ADR.
#
# LOKI LABEL ALLOW-LIST: service, env, level
# NEVER add anything to this list without checking cardinality first.
# Each new label multiplies the index size; we have killed Loki ingesters at
# 3am over a single innocent-looking label. Trace/user/request IDs go IN the
# log line, not on it.
# =============================================================================

receivers:
  otlp:
    protocols:
      grpc: { endpoint: 0.0.0.0:4317 }
      http: { endpoint: 0.0.0.0:4318 }

processors:
  batch:
    timeout: 5s
    send_batch_size: 1000

  resourcedetection:
    detectors: [env, system]

  # PII backstop — services should redact in-process; this catches misses.
  attributes/pii:
    actions:
      - { key: password,        action: delete }
      - { key: passwd,          action: delete }
      - { key: pwd,             action: delete }
      - { key: token,           action: delete }
      - { key: authorization,   action: delete }
      - { key: api_key,         action: delete }
      - { key: apikey,          action: delete }
      - { key: secret,          action: delete }
      - { key: ssn,             action: update, value: "[REDACTED]" }
      - { key: sin,             action: update, value: "[REDACTED]" }
      - { key: email,           action: update, value: "[REDACTED]" }
      - { key: email_address,   action: update, value: "[REDACTED]" }
      - { key: phone,           action: update, value: "[REDACTED]" }
      - { key: phone_number,    action: update, value: "[REDACTED]" }
      - { key: credit_card,     action: update, value: "[REDACTED]" }
      - { key: card_number,     action: update, value: "[REDACTED]" }
      - { key: cvv,             action: update, value: "[REDACTED]" }
      - { key: pan,             action: update, value: "[REDACTED]" }
      - { key: ip_address,      action: update, value: "[REDACTED]" }

  # Tail sampling — uncomment when trace volume justifies the collector cost.
  # Keeps: all errors, all slow traces (>2s), 10% of normal traffic.
  # tail_sampling:
  #   decision_wait: 10s
  #   policies:
  #     - { name: errors,  type: status_code, status_code: { status_codes: [ERROR] } }
  #     - { name: slow,    type: latency,     latency: { threshold_ms: 2000 } }
  #     - { name: sample,  type: probabilistic, probabilistic: { sampling_percentage: 10 } }

exporters:
  otlp/jaeger:
    endpoint: jaeger-collector:4317
    tls: { insecure: true }

  prometheusremotewrite:
    endpoint: http://prometheus:9090/api/v1/write
    resource_to_telemetry_conversion: { enabled: true }

  loki:
    endpoint: http://loki:3100/loki/api/v1/push
    # Allow-list — see banner above. DO NOT EXTEND WITHOUT CARDINALITY REVIEW.
    default_labels_enabled:
      exporter: false
      job: false
    labels:
      attributes:
        service.name:           service
        deployment.environment: env
        level:                  level

service:
  pipelines:
    traces:
      receivers:  [otlp]
      processors: [resourcedetection, attributes/pii, batch]
      exporters:  [otlp/jaeger]
    metrics:
      receivers:  [otlp]
      processors: [resourcedetection, batch]
      exporters:  [prometheusremotewrite]
    logs:
      receivers:  [otlp]
      processors: [resourcedetection, attributes/pii, batch]
      exporters:  [loki]

  telemetry:
    logs:    { level: info }
    metrics: { level: detailed }
```

## Grafana Dashboards (required)
At minimum the repo ships these dashboards as JSON. Each is service-name templated so adding a service auto-populates panels.

| Dashboard | Panels | Data source |
|---|---|---|
| `service-red.json` | Request rate, error %, duration p50/p95/p99 per service | Prometheus |
| `messaging-overview.json` | Consumer lag, retry count, dead-letter depth, processing duration | Prometheus + Loki |
| `logs-overview.json` | Log volume by service/level, error log spikes | Loki |
| `slo-overview.json` | SLO burn rate, error budget remaining | Prometheus recording rules |

Recording and alerting rules live in `prometheus-rules/service-slo.yaml`. Alerts route via Alertmanager — that wiring is environment infra and not part of this skill.

## Backend Swap Notes
Every backend is replaceable. Document what changes for each.

### Replace Loki with Elasticsearch
* Swap collector exporter `loki` → `elasticsearch` (`opentelemetry-collector-contrib`).
* Index strategy: one index per service per day (`logs-<service>-<yyyy-mm-dd>`).
* Loki label allow-list constraint disappears (ES indexes everything) but ingest cost rises sharply — establish field-level mapping discipline instead.
* Grafana data source changes from Loki to Elasticsearch — dashboards need rewriting (LogQL → Lucene/ES|QL).
* Retention is enforced via ILM policies, not Loki retention config.

### Replace Jaeger with Tempo
* Swap exporter `otlp/jaeger` → `otlp/tempo`.
* Tempo integrates more naturally with Grafana (single pane).
* Tail sampling stays in collector — same block.
* No application-side changes.

### Replace Prometheus with VictoriaMetrics or Mimir
* Remote-write endpoint changes; OTLP exporter stays.
* No application-side changes.
* PromQL is supported by both — dashboards stay.

### Replace GlitchTip with another Sentry-compatible backend
* Change `SENTRY_DSN` env vars per service. Same SDK code.
* Source-map upload endpoint changes — update CI scripts.
* No application code changes.

## Operational Controls (infra knobs)
| Knob | Where | Effect | Propagation |
|---|---|---|---|
| Enable tail sampling | Uncomment block in `otel-collector-config.yaml` | Reduces trace volume to backends | Collector restart |
| Adjust tail-sampling thresholds | `latency.threshold_ms`, `probabilistic.sampling_percentage` | Tunes what's kept | Collector restart |
| Add PII deny entry (collector layer) | `attributes/pii` actions | Backstop redaction includes new field | Collector restart |
| Increase Loki retention | `loki/retention.yaml` | More storage, longer query horizon | Loki rollout |
| Increase Jaeger retention | Jaeger config | Longer trace horizon, more storage | Jaeger rollout |
| Throttle inbound (collector) | `receivers.otlp` rate limits | Protects backends from spike | Collector restart |

**What you cannot change without redeploy:** pipeline composition (which processors run), backend choice (Loki vs ES), exporter targets.

## When to Use
* Editing `infra/observability/otel-collector-config.yaml`
* Onboarding a new service to existing dashboards
* Adding/changing Grafana dashboards or Prometheus alert rules
* Planning or executing a backend swap (Loki ↔ ES, Jaeger ↔ Tempo, etc.)
* Investigating "telemetry not arriving" or backend ingest issues

## When NOT to Use
* Application instrumentation (.NET or frontend) — see `observability-backend` / `observability-frontend`
* Defining new contracts — see `observability-contracts`, requires ADR
* Application-specific dashboards owned by a single service team — keep those out of `infra/observability/grafana-dashboards/`; put them next to the service code
