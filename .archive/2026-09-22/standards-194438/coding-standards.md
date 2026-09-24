Implementation Standards
Loaded by: sk.implement, sk.review

## Pre-Generation Protocol
# REQUIRED before writing any code in an existing module:
# 1. Read existing code in the target area. Match the established patterns.
# 2. Before introducing a new abstraction (interface, utility, base class):
#    search the codebase — if an equivalent exists, use it.
# These two steps prevent session-to-session drift, the primary AI failure mode.

## Formatter / Linter
# Declare the formatter and linter for your project here.
# AI-generated code is formatted by the tool, not by convention.
# [Fill in — e.g. "Go: gofmt + golangci-lint | Python: Black + Ruff | TS: Prettier + ESLint"]
# sk.implement runs the formatter after completing each task phase.

## Implementation Rules
# Purpose: allow AI to safely regenerate any module without breaking the system.
# [REQUIRED] items are checked in sk.review. Module Boundary violations block story progression.

# --- Module Boundaries (blocking) ---
# [REQUIRED] Method signatures must match the declared interface exactly.
# [REQUIRED] API response shape must match api-spec.json exactly — no undocumented fields.
# [REQUIRED] DTOs must be explicit typed structures — no `any`, no raw maps, no untyped dicts.
# [REQUIRED] Public method names: verb-noun, describe intent (createOrder not process).
# [REQUIRED] A module may only depend on its own internals or declared external interfaces.
#   No direct access to another module's internal classes.

# --- Domain Logic (enforced at review) ---
# [REQUIRED] No business logic in controllers.
#   Controllers: validate input → call service → return response. Nothing else.
# [REQUIRED] State changes, DB writes, external calls, event publishes: only through injected
#   interfaces. No direct DB queries outside repositories.
# [REQUIRED] A command may modify only one aggregate.
#   Cross-aggregate changes must go through domain events or orchestration.
# [REQUIRED] Functions must perform a single logical operation. Max 30 lines as secondary limit.
# [REQUIRED] Max 3 parameters per function. Use a parameter object beyond that.

# --- Command Handler Idempotency (blocking) ---
# [REQUIRED] Every command object must carry a commandId field (UUID v4, client-generated).
# [REQUIRED] Command handlers must check commandId against a dedup store before executing.
#   On duplicate: return the cached result. Do not re-execute side effects.
#   Dedup store TTL: minimum 24h, or match message broker retention window.
# [REQUIRED] If messaging_context = true: no direct event publish inside a command handler
#   without outbox pattern (state write + outbox row in same transaction; relay publishes).
# [REQUIRED] Duplicate detection: log at WARN with commandId.
#   Metric per observability-standards.md (commands_duplicate_total).
# [Advisory] Natural idempotency (pure computation, no state change) does not require
#   dedup store — document as "naturally idempotent" in handler code comment.
# Note: HTTP Idempotency-Key (api-standards.md) is API-layer. commandId is handler-layer.
#   Both are required. They serve different audiences (HTTP clients vs internal command bus).

## Error Handling Pattern
# Declare the project's error handling pattern here — AI will follow it consistently.
# [Fill in — e.g. "Go: errors.Wrap + sentinel errors | TypeScript: Result<T,E> | Python: typed exceptions"]
# Rules that apply regardless of pattern:
# - Never swallow errors silently
# - Expected errors (invalid input, not found): structured response + log WARN
# - Unexpected errors (bugs, infrastructure): log ERROR with full context; never expose to caller

## Observability in Code
# [REQUIRED] All logs: structured JSON with trace_id and span_id
# Business events: INFO | Degraded state: WARN | Failures: ERROR
# No sensitive data in logs (passwords, tokens, PII)
# External call duration + error count: instrumented
# See observability-standards.md for full requirements

## Test Coverage Thresholds
Backend unit/integration: 80% minimum
Frontend components: 70% minimum
Critical paths (auth, payments, data mutations): 95% minimum
Contract tests (provider + consumer): 100% of endpoints
E2E tests: 100% of acceptance criteria
