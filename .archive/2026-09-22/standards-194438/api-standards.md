API Standards
Loaded by: sk.contracts

URL Structure:

Versioning:

Response Envelope:

Error Format:

Authentication:

Pagination:
# Default: cursor-based for any collection that grows unbounded.
# Offset-based is acceptable only for small, bounded datasets (e.g. lookup lists < 1000 items).
# Cursor format: opaque token (base64-encoded position), not a raw offset or timestamp.
# Response must include: next_cursor (null if no more pages), has_more flag.

Idempotency:
# DDIA Ch 11 — all mutation endpoints (POST / PUT / PATCH / DELETE) must support Idempotency-Key header.
# Server stores result keyed by Idempotency-Key for minimum 24 hours.
# Duplicate request with same key: return cached result, do not re-execute.
# Key format: client-generated UUID v4.
# If key conflicts with a different request payload: return 422 Unprocessable Entity.
# REQUIRED: every mutation endpoint in api-spec.json must declare Idempotency-Key in parameters.
