Observability Standards
Loaded by: sk.implement, sk.review, sk.architecture

Enforcement model: [REQUIRED] items must be present when a service first ships.
sk.planproject generates observability setup tasks in 03-plan/{Project}/tasks.md for the first unit of any new service.
Subsequent stories: sk.review verifies nothing is removed or broken.

## Structured Logging

[REQUIRED] Structured JSON — no unstructured plain text in production.

Required fields per log entry:
  timestamp  — ISO 8601 with milliseconds
  level      — error | warn | info | debug
  service    — name matching service-registry.md
  trace_id   — W3C traceparent trace ID, from inbound request context
  span_id    — current span ID
  message    — imperative description ("order placed", not "placing order")

Levels:
  error  — operation failed; requires attention
  warn   — degraded but continuing (retry, fallback, slow dependency)
  info   — significant business event (state transitions, user actions)
  debug  — development diagnostics; disabled or sampled in production

[REQUIRED] No sensitive data: no passwords, tokens, PII, payment card data.
[REQUIRED] ERROR entries must include: error type, message, request context.

## Distributed Tracing

[REQUIRED] W3C traceparent propagation (RFC 7230).
[REQUIRED] Inbound HTTP request: extract traceparent; create root span if absent.
[REQUIRED] Outbound HTTP call: inject traceparent header.
[REQUIRED] Async jobs / queue messages: embed trace_id in payload.
[Advisory] Name key business spans (e.g. "process_payment", "send_notification").

## Metrics — RED Method

[REQUIRED] For every service endpoint:
  http_requests_total{service, endpoint, method, status_code}    ← Rate
  http_errors_total{service, endpoint, method, error_type}       ← Errors
  http_request_duration_seconds{service, endpoint, method}       ← Duration (histogram)

[REQUIRED] Every external dependency call: duration histogram + error counter.
[Advisory] One domain-level metric per unit (e.g. orders_created_total).
[Advisory] Metric names: snake_case, unit suffix (_total, _seconds, _bytes).

## Command Handler Idempotency Observability

Applies when: the constitution requires command handler idempotency and command handlers perform state mutations.

[REQUIRED] commands_duplicate_total{handler, reason}
  Increment on every duplicate commandId detection before handler executes.
  Labels:
    handler — name of the command handler (e.g. "CreateOrderHandler")
    reason  — "commandId_seen" | "natural_idempotent"

[REQUIRED] Structured log entry on every duplicate detection:
  level: warn
  message: "duplicate command rejected"
  fields: handler, commandId, original_executed_at (timestamp of first execution)
  Must include trace_id and span_id per standard logging requirements.

[Advisory] commands_processed_total{handler, status}
  status: success | failure | duplicate
  Provides full processing funnel visibility per handler.

[Advisory] outbox_relay_lag_seconds (if outbox pattern in use)
  Histogram: time between outbox row written and event published to broker.
  Alert threshold: p99 > 5s warrants investigation.

## Health Check

[REQUIRED] GET /health
  200: { "status": "ok",       "service": "{name}", "version": "{version}" }
  503: { "status": "degraded", "service": "{name}", "checks": { "{dep}": "fail" } }

[Advisory] Separate /health/live and /health/ready for Kubernetes deployments.
