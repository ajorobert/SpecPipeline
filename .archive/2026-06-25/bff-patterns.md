---
name: bff-patterns
description: "Load when: designing or implementing BFF (Backend-for-Frontend) API layer, deciding whether a route needs BFF vs. direct service call, or implementing aggregation/fan-out flows."
---

# BFF (Backend-for-Frontend) Patterns

## Purpose
Patterns for the BFF API layer. **BFF is not mandatory for all routes** — it is a tool used when a call flow genuinely needs it. Backend services are designed to accept both direct client calls (with user JWT) and BFF calls (with M2M token). The decision of which flow to use is made per route based on the criteria below.

---

## Call Flow Decision — BFF vs. Direct

Use this to decide how each route should be accessed. Document the decision per route in the contract spec.

### Use BFF when:
* The response requires data from **more than one backend service** (fan-out / aggregation).
* The response shape needs significant **transformation** away from what any single service returns.
* The route needs to **hide internal service topology** from the client (e.g., which service owns what).
* Cross-cutting concerns must be **centralised** for a group of routes: consistent error translation, per-user rate limiting, request coalescing.
* The client is a **Next.js server component** making multiple backend calls — the BFF call happens server-side anyway, so latency of the extra hop is negligible.

### Direct call is appropriate when:
* The route touches **exactly one backend service** with no aggregation.
* The response shape from the service is already frontend-friendly — no transformation needed.
* **Latency is more important** than consistency (e.g., real-time geo search, live availability).
* The API is **public/unauthenticated** (public listing browse, CMS content).
* The endpoint is **internal** (service-to-service) — never goes through BFF.

### Decision matrix

| Scenario | Flow |
|---|---|
| Listing detail page (listing + reviews + saved status) | BFF — 3 services |
| Listing search / geo query | Direct → Search service |
| Create/update listing | Direct → Listing service (single service, owner validates via ABAC) |
| User dashboard (profile + active listings + notifications) | BFF — 3 services |
| Upload presign URL | Direct → File service |
| Admin user management | BFF — aggregates identity + audit data |
| Public listing browse (no auth) | Direct → Listing service |
| Booking flow (availability + payment + notification trigger) | BFF — orchestrates 3 services |

---

## Auth in Each Flow

### Flow A — Direct (client → service with user JWT)
```
Client
  → Authorization: Bearer {keycloak_jwt}
  → Backend Service
      validates JWT (JWKS)
      extracts claims (sub, roles, tenant_id)
      applies RBAC policy
      applies ABAC handler against resource
      executes
```
* The service owns full auth responsibility.
* See `keycloak-patterns` §3 for JWT setup, §5 for RBAC policies, and §6 for ABAC handlers.
* Rate limiting applied at service level (or at infrastructure gateway if present).

### Flow B — Via BFF (client → BFF → services with M2M)
```
Client
  → Authorization: Bearer {keycloak_jwt}
  → BFF
      validates user JWT (JWKS)
      extracts claims — builds typed user context
      calls Service A with M2M token + user context headers
      calls Service B with M2M token + user context headers (parallel)
      aggregates, shapes, returns

Backend Services (called by BFF)
  → Authorization: Bearer {m2m_token}
      validates M2M token (JWKS — same Keycloak, different client)
      trusts propagated user context headers (X-User-Id, X-Tenant-Id, X-User-Roles)
      applies RBAC + ABAC using propagated context
```
* BFF validates the user JWT **once**. Services trust the propagated context from BFF — they do not re-validate the user JWT.
* Services still apply RBAC and ABAC — they are not blindly trusting the BFF to have done it.
* Propagated headers are **internal only** — never accept these headers from external callers. Validate that the caller holds a valid M2M token before trusting propagated headers.

### Propagating user context from BFF to services
```csharp
// In BFF — after validating user JWT, forward context as typed headers
private HttpRequestMessage AddUserContext(HttpRequestMessage req, ClaimsPrincipal user)
{
    req.Headers.Add("X-User-Id",    user.GetUserId().ToString());
    req.Headers.Add("X-Tenant-Id",  user.GetTenantId().ToString());
    req.Headers.Add("X-User-Roles", string.Join(",", user.GetRoles()));
    return req;
}

// In backend service — read propagated context when caller is BFF (M2M token)
public class UserContextMiddleware(RequestDelegate next)
{
    public async Task InvokeAsync(HttpContext ctx)
    {
        if (ctx.User.IsM2MClient()) // caller is BFF, not end user
        {
            ctx.Items["PropagatedUserId"]   = ctx.Request.Headers["X-User-Id"].ToString();
            ctx.Items["PropagatedTenantId"] = ctx.Request.Headers["X-Tenant-Id"].ToString();
            ctx.Items["PropagatedRoles"]    = ctx.Request.Headers["X-User-Roles"].ToString();
        }
        await next(ctx);
    }
}
```

---

## BFF Core Rules (when BFF is used)

### Request Aggregation
* `Task.WhenAll` for all independent parallel downstream calls — never sequential awaits.
* Per-downstream: timeout policy + circuit breaker (Polly). Critical dependencies fail fast; optional data degrades gracefully.
* Declare explicitly per route: which downstream failures produce partial response vs. full error.

### Credential Safety
* Service-to-service credentials (M2M client secret) live only in server-side env vars — never in `NEXT_PUBLIC_*`, `VITE_*`, or any client bundle.
* Never log Authorization headers, M2M tokens, or user JWTs.

### Rate Limiting (BFF routes only)
* Rate limit per authenticated user identity (`sub` claim), not per IP.
* Token bucket or sliding window via ASP.NET Core `RateLimiterMiddleware`.
* Return `429 Too Many Requests` with `Retry-After` header.
* For direct-call routes: rate limiting responsibility belongs to the service or an infrastructure gateway.

### Error Translation
* Never expose downstream service names, stack traces, or internal error messages to clients.
* Map to RFC 9457 `ProblemDetails`: downstream 404 → 404, downstream 409 → 409, downstream 5xx → 502.
* Direct-call routes: services return `ProblemDetails` themselves — no BFF translation layer needed.

### Response Shaping

**Two distinct DTO layers — do not conflate them:**

| DTO type | Owner | Shape driven by | Example |
|---|---|---|---|
| **Application DTO** | The owning service's Application layer (read repository → query handler return type) | The use case / read model — stable, versioned per the service's API contract | `ListingDetailDto`, `BookingSummaryDto` returned from `IQueryHandler<...>` |
| **BFF DTO** (a.k.a. View Model) | The BFF aggregation handler | The specific frontend screen consuming it — composed from one or more Application DTOs, may rename, flatten, drop, or merge fields | `ListingDetailScreenResponse` (combines `ListingDetailDto` + `ReviewSummaryDto[]` + `IsSavedDto`) |

* Application DTOs are **use-case contracts**: one per query handler, named after the business read model, lifetime tied to the service's API version. They appear in the OpenAPI spec of the owning service.
* BFF DTOs are **client-shaped projections**: one per screen / per call site, named after the screen or interaction (`ListingDetailScreenResponse`, `CheckoutPageResponse`), lifetime tied to the frontend that consumes them. They appear in the BFF's OpenAPI spec, never in any backend service's spec.
* The BFF must not return an Application DTO directly — even if the shape is identical today. Wrap it in a BFF DTO so the frontend contract can evolve independently of the service contract. A field rename in the service DTO must not ripple to the frontend.
* Direct-call routes (no aggregation needed) are an explicit exception: the service's Application DTO is the on-the-wire contract, and the frontend depends on it directly. Document this choice — it trades coupling for latency.

---

## Patterns / Examples

### Parallel aggregation (BFF flow)
```csharp
public async Task<ListingDetailResponse> GetListingDetailAsync(
    Guid listingId, ClaimsPrincipal user, CancellationToken ct)
{
    // All three calls in parallel — user context propagated via headers
    var (listing, reviews, saved) = await (
        _listingClient.GetAsync(listingId, user, ct),
        _reviewClient.GetForListingAsync(listingId, pageSize: 5, user, ct),
        _savedClient.IsListingSavedAsync(listingId, user, ct)
    ).WhenAll();

    return new ListingDetailResponse(listing, reviews, saved);
}
```

### M2M token cache
```csharp
public class KeycloakM2MTokenProvider(IHttpClientFactory factory, IOptions<KeycloakOptions> opts, IMemoryCache cache)
{
    private const string CacheKey = "bff_m2m_token";

    public async Task<string> GetTokenAsync(CancellationToken ct)
    {
        if (cache.TryGetValue(CacheKey, out string? token)) return token!;
        var response = await RequestClientCredentialsTokenAsync(ct);
        cache.Set(CacheKey, response.AccessToken, TimeSpan.FromSeconds(response.ExpiresIn - 30));
        return response.AccessToken;
    }
}
```

### Graceful partial response
```csharp
// Optional downstream — degrade gracefully if unavailable
IReadOnlyList<ReviewSummary> reviews;
try   { reviews = await _reviewClient.GetForListingAsync(listingId, ct); }
catch { reviews = []; } // reviews are optional — page still renders

// Critical downstream — fail the whole request if unavailable
var listing = await _listingClient.GetAsync(listingId, ct);
// throws DownstreamUnavailableException → caught by error translation middleware → 502
```

---

## When to Use This Skill
* Deciding which routes use BFF vs. direct service call for a new unit
* Documenting the chosen flow per route in the API contract
* Implementing a BFF aggregation or fan-out route

## When NOT to Use
* Service-to-service internal calls (always M2M, no BFF involved)
* Deciding how auth works inside a service (see `keycloak-patterns`)
* Infrastructure gateway configuration (Traefik, YARP, nginx)
