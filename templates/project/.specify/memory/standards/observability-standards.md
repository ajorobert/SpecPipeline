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

## Health Check

[REQUIRED] GET /health
  200: { "status": "ok",       "service": "{name}", "version": "{version}" }
  503: { "status": "degraded", "service": "{name}", "checks": { "{dep}": "fail" } }

[Advisory] Separate /health/live and /health/ready for Kubernetes deployments.
