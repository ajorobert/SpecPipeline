---
name: authorization-patterns
description: |
  Authorization usage for .NET 10 backend: reading IUserContext in handlers, the RequiresPermission/RunsAs permission contract, RBAC policy usage on endpoints, ABAC authorization handlers (resource-ownership), predicate-scoped reads, audit identity, and trusting propagated context from internal callers. AuthN wiring (JWT validation, claim mapping, M2M token acquisition) lives in infrastructure-wiring. Use for every protected endpoint, every handler that reads identity, every audit log.
when_to_load:
  - Task mentions: authorization, authz, permission, role, policy, ABAC, RBAC, IUserContext, resource owner, audit identity, ownership check
  - Files touched: any *Endpoint.cs with auth, any *Handler.cs reading IUserContext, *AuthorizationHandler.cs, *Requirement.cs
co_loads_with:
  - backend-architecture (IUserContext contract + permission markers — read first)
  - api-endpoint-patterns (policy declaration on endpoints)
  - backend-feature-patterns (IUserContext in handlers)
---

# Authorization Patterns

Read `backend-architecture` first — it owns the `IUserContext` contract (§5), the permission-marker
mechanism (§5), the comment-marker index (§7), and NetArchTest invariant #4. This skill is the
**feature-facing usage** of authorization: how a handler reads identity, how an endpoint declares a
policy, how an ABAC handler authorizes a resource, and how reads scope to the caller.

This skill is **security-critical**. AuthN *wiring* — JWT bearer validation, Keycloak claim mapping into
`IUserContext`, M2M client-credentials token acquisition — is **not** here; it lives in
`infrastructure-wiring`. This skill assumes a populated `IUserContext` already exists on the request and
governs how feature code *uses* it.

---

## 1. The model: RBAC vs ABAC

Two questions, two mechanisms. Both apply — they are not alternatives.

| Question | Mechanism | Where it runs |
|---|---|---|
| "Can this **role** reach this area?" | **RBAC** — an endpoint policy (`.Policies("…")`) | At the HTTP edge, before the handler |
| "Can **THIS user** act on **THIS resource**?" | **ABAC** — an `AuthorizationHandler<TReq, TResource>` over a loaded resource | At the edge or in the feature handler, against a loaded aggregate/DTO |

RBAC is coarse and stateless (role membership). ABAC is fine-grained and stateful (does *this* caller own
*this* row). A route that passes RBAC can still fail ABAC, and that is the common case for any
owner-scoped resource.

**Identity is read only through `IUserContext`** (the contract in `backend-architecture §5`:
`UserId`, `TenantId`, `Roles`, `Permissions`, `IsViaM2M`, `IsInRole(...)`, `HasPermission(...)`).
A handler, an ABAC handler, or an audit call **NEVER** touches `ClaimsPrincipal`, `HttpContext.User`,
or `IHttpContextAccessor`. Those are wiring-layer types; the mapping from claims to `IUserContext`
happens once, in `infrastructure-wiring`. Inside a module you inject `IUserContext` by constructor and
read typed properties — no string-keyed claim lookups.

---

## 2. The permission contract

Every mutating command/query (and the endpoint that fronts it) declares the permission it requires as an
attribute on the contract type:

```csharp
namespace YourContext.Application.Handlers.Listings.Activate;

[RequiresPermission("<permission>")]   // permission string is project vocabulary — see the catalog
public sealed record ActivateListingCommand(ListingId ListingId)
    : ICommand<Result>, IVendorOwned;   // scope marker per backend-architecture §5
```

System-initiated work (a scheduled job, a domain-event reaction, a saga step) that has no end-user
identity declares the principal it runs as:

```csharp
[RunsAs(<systemPrincipal>)]            // system principal is project vocabulary
public sealed record ExpireStaleListingsCommand(DateOnly AsOf) : ICommand<Result>, ITenantScoped;
```

**The permission CATALOG is project data**, not skill content. The set of valid permission strings, the
system-principal names, and the scope-marker names live in the repo's `authorization/` folder and
`.specify/memory/`. This skill teaches the *grammar* (`[RequiresPermission]` / `[RunsAs]`); it does not
enumerate the *vocabulary* (the actual permission strings) — that is the grammar-vs-vocabulary rule from
`backend-architecture §1`. Never invent or hardcode a permission string in a skill or in copied example
code; pull it from the catalog at code-gen time.

**Enforcement is mechanical.** NetArchTest invariant #4 (`backend-architecture §8`) fails the build if a
mutating command or protected query carries neither `[RequiresPermission]` nor `[RunsAs]`. The test reads
the *declared* catalog from `authorization/`; presence is enforced, the values are project facts.

---

## 3. RBAC policy usage on endpoints

An endpoint declares its RBAC policy inside `Configure()` with the `// AUTH:` marker. Policy **names** are
project vocabulary (declared in `authorization/`); the **declaration shape** is the pattern.

```csharp
public override void Configure()
{
    // ENDPOINT: PATCH /api/v1/listings/{ListingId}
    Patch("/api/v1/listings/{ListingId}");
    // AUTH: policy listings.write (RBAC)
    Policies("listings.write");
}
```

- Endpoints reference **policies by name**, never role strings inline — role-to-policy mapping is wiring
  (`infrastructure-wiring`), so the endpoint stays decoupled from the role vocabulary.
- An ABAC requirement that rides on top of a policy is noted in the same `// AUTH:` line so the
  CI manifest captures both (see §4):
  `// AUTH: policy listings.write (RBAC) + CanEditListing (ABAC via resource handler)`.
- **Anonymous endpoints are explicit.** A deliberately unauthenticated route carries the exact form
  `// AUTH: Anonymous — REASON: <reason>` over its policy declaration. CI manifests every anonymous
  endpoint for review — there is no silent "no policy".

The marker grammar is shared with `api-endpoint-patterns`; the canonical marker registry is
`backend-architecture §7`. This skill emits `// AUTH:`; it does not own the registry.

---

## 4. ABAC: resource-ownership authorization handlers

The pattern: **load the resource ONCE, then authorize against it.** The component that has the resource
in hand (the endpoint, or a feature handler that already loaded the aggregate) calls
`IAuthorizationService.AuthorizeAsync(...)`. An `AuthorizationHandler<TRequirement, TResource>` compares
the resource's ownership/scope against `IUserContext`.

**The ABAC handler does NOT hit the database.** It receives a pre-loaded resource and makes a pure
in-memory decision. A handler that queries inside `HandleRequirementAsync` is the anti-pattern in §9 — it
duplicates the load, double-charges latency, and hides the data dependency.

```csharp
namespace YourContext.Application.Auth.Requirements;

public sealed class ResourceOwnerRequirement : IAuthorizationRequirement;

public sealed class ListingOwnerHandler(IUserContext user)
    : AuthorizationHandler<ResourceOwnerRequirement, Listing>
{
    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext ctx, ResourceOwnerRequirement req, Listing resource)
    {
        // Pure comparison — no DB, no HttpContext. Identity from IUserContext only.
        if (resource.OwnerId.Value == user.UserId || user.IsInRole("admin"))
            ctx.Succeed(req);
        return Task.CompletedTask;   // not failing explicitly leaves the requirement unmet → 403
    }
}
```

The caller loads once and authorizes; on failure it returns `Error.Forbidden(...)`, which
`api-endpoint-patterns` maps to 403:

```csharp
public override async Task HandleAsync(Request req, CancellationToken ct)
{
    var listing = await reads.GetByIdAsync(req.ListingId, ct);
    if (listing is null) { await this.ToResponseAsync(Error.NotFound("Listing.NotFound"), ct); return; }

    var decision = await authz.AuthorizeAsync(HttpContext.User, listing, "CanEditListing");
    if (!decision.Succeeded) { await this.ToResponseAsync(Error.Forbidden("Listing.NotOwner"), ct); return; }

    var result = await commandBus.Send(Map.ToCommand(req), ct);   // dispatch seam — backend-architecture §2
    await this.ToResponseAsync(result, ct);
}
```

> `AuthorizeAsync` takes `HttpContext.User` as the *principal carrier* at the edge — that is framework
> plumbing, not a claim read. The ownership decision itself is made against `IUserContext` inside the
> handler. Feature/handler code never reaches into `HttpContext.User` for identity.

**Reads are NOT exempt from ABAC.** Authorization applies to queries exactly as to commands:

- **Single-resource query** (one draft listing, one booking) → authorize the loaded resource the same
  way a command does. Returning a resource the caller may not see is a leak, not a "read".
- **Collection query** → enforce ABAC by **SCOPING THE PREDICATE** in the read service:
  `WHERE owner_id = @callerId` (or the tenant column) is added to the SQL/Dapper query so the database
  never returns rows the caller cannot see. **Never** fetch the full set and filter in memory afterward —
  post-fetch filtering leaks via counts, paging totals, and timing, and is the anti-pattern in §9.

```csharp
// Read service — predicate is scoped to the caller; rows the caller can't see never leave the DB.
public Task<IReadOnlyList<ListingSummaryDto>> ListForCallerAsync(Guid callerId, CancellationToken ct)
    => connection.QueryAsync<ListingSummaryDto>(
        "SELECT id, title, status FROM listings WHERE owner_id = @callerId",
        new { callerId }, ct);   // owner_id = caller — ABAC enforced in the predicate
```

The caller id passed in comes from `IUserContext.UserId` (or `TenantId` for tenant-scoped reads) at the
handler boundary — the read service receives a scope value, it does not read identity itself.

---

## 5. Audit identity

Every state-mutating handler emits an audit record identifying *who did what to which aggregate*. The
fields are written through the observability seam (structured log / span attributes) using the property
conventions and PII deny-list owned by `observability-backend` — this skill does not restate property
formats or wiring.

| Field | Source |
|---|---|
| `user.id` | `IUserContext.UserId` (or M2M client id when `IsViaM2M`) |
| `user.tenant_id` | `IUserContext.TenantId` |
| `user.via_m2m` | `IUserContext.IsViaM2M` |
| `operation` | the command type name (or a stable slug) |
| `aggregate.id` | the mutated aggregate's id |

`preferred_username` is **redacted** from audit by default (it is on the PII deny-list); include it only
when the audit story explicitly requires a human-readable actor. The identity in an audit record always
comes from `IUserContext`, never from a re-read of claims.

---

## 6. Trusting propagated context from internal callers

A request can arrive from an end user (user JWT) **or** from a trusted internal caller — a BFF or
aggregating endpoint that already validated the user JWT and now calls this service with an **M2M token**
plus propagated user-context headers (`X-User-Id`, `X-Tenant-Id`, `X-User-Roles`).

The non-negotiable rules:

1. **The service still applies RBAC + ABAC.** Being called by a trusted BFF does not skip authorization —
   the service never assumes the caller already authorized. Same policy on the endpoint, same ABAC handler
   over the loaded resource.
2. **Never trust propagated user-context headers unless the caller holds a valid M2M token.** The
   propagated headers are *internal only*. The wiring layer accepts them **only** when the request bears a
   valid M2M token (validated upstream in `infrastructure-wiring`); an external caller presenting
   `X-User-Id` with no M2M token is ignored. From the feature's perspective: whether identity arrived via
   user JWT or via M2M-gated propagation, it surfaces uniformly as `IUserContext` — and the feature
   authorizes against it the same way.
3. **Cross-context integration events carry metadata, never a JWT.** A cross-module integration event
   carries `tenant_id` + `originating_user_id` as message metadata (see `backend-architecture §6`). The
   receiving context **authorizes fresh** against its own boundary using that metadata — it does not
   replay the originator's token, because there is no propagated token on the async path.

The takeaway: trust is established by the *transport credential* (a valid M2M token), and authorization is
*always* re-applied by the receiver. There is no "already-checked, skip it" path.

---

## 7. Idempotency + auth

The HTTP idempotency dedup tuple includes the caller's identity. The dedup key is
`(Idempotency-Key, request fingerprint, UserId)` — using the M2M client id in place of `UserId` when
`IsViaM2M`. Consequence: a replay presenting the **same** `Idempotency-Key` from a **different** identity
is **not** a replay — it is a `409 Conflict`, never a silent return of the first caller's response.

This binds the dedup record to who made the call, so one user cannot replay another user's mutation by
guessing a key. The handler-side store and tuple are owned by `backend-feature-patterns §9`; the HTTP-side
`Idempotency-Key` contract is owned by `api-endpoint-patterns`. This skill states only the **identity
component** of the tuple.

---

## 8. Testing

Authorization logic — handlers reading `IUserContext`, ABAC handlers — is unit-tested with a
`FakeUserContext`, with **no JWT and no middleware**. Construct the identity you need inline:

```csharp
internal sealed class FakeUserContext : IUserContext
{
    public Guid UserId { get; init; } = Guid.NewGuid();
    public Guid TenantId { get; init; } = Guid.NewGuid();
    public IReadOnlySet<string> Roles { get; init; } = new HashSet<string>();
    public IReadOnlySet<string> Permissions { get; init; } = new HashSet<string>();
    public bool IsViaM2M { get; init; }
    public string? PreferredUsername { get; init; }
    public bool IsInRole(string role) => Roles.Contains(role);
    public bool HasPermission(string permission) => Permissions.Contains(permission);
}
```

```csharp
// ABAC: owner succeeds, non-owner is denied — no Keycloak, no HTTP.
var owner = new FakeUserContext { UserId = ownerId };
var handler = new ListingOwnerHandler(owner);
// ... assert ctx.HasSucceeded for the owner, and not for a stranger.
```

Cover both the allow and the deny path for every ABAC handler — a handler that only ever succeeds is a
silent authorization hole. Endpoint-level RBAC (policy → role mapping) is exercised in integration tests
per `infrastructure-wiring`; the unit layer owns the resource-ownership decision.

---

## 9. Anti-patterns

- **Injecting `ClaimsPrincipal` / `IHttpContextAccessor` into a handler or ABAC handler** — read identity
  through `IUserContext` only.
- **String-keyed claim lookups in feature code** (`User.FindFirst("tenant_id")`) — claim mapping happens
  once in wiring; handlers read typed `IUserContext` properties.
- **Loading the resource inside an ABAC handler** — the caller loads once and passes the resource in; the
  handler makes a pure comparison.
- **Caching permissions beyond request scope** — `Permissions`/`Roles` are request-scoped and claim-derived;
  they can change between requests. Never memoize them past the current request.
- **Treating an M2M token as having a user identity** — an M2M caller has no `sub`; check
  `IUserContext.IsViaM2M` before assuming a `UserId`, and key audit/idempotency on the client id.
- **Post-fetch row filtering instead of predicate scoping** — never `SELECT *` then filter in memory;
  scope the WHERE clause so unauthorized rows never leave the database (§4).
- **Skipping authorization because the caller is "the trusted BFF"** — services always re-apply RBAC + ABAC;
  trust is the M2M token, not a free pass (§6).

---

## Markers

This skill emits `// AUTH:` — the endpoint authorization marker, **shared with `api-endpoint-patterns`**.
Every policy/role/ABAC enforcement point carries it; anonymous endpoints carry the exact form
`// AUTH: Anonymous — REASON: <reason>`. CI parses `// AUTH:` lines into the policy→endpoint manifest.
The canonical marker registry is **`backend-architecture §7`** — this skill does not restate it.

## References

- `backend-architecture §1, §5, §7, §8` — grammar-vs-vocabulary, `IUserContext` + permission contract,
  marker registry, NetArchTest invariant #4 (read first).
- `api-endpoint-patterns` — `.Policies()` in `Configure()`, the `// AUTH:` marker, Result→HTTP (403),
  the `Idempotency-Key` HTTP contract.
- `backend-feature-patterns §9` — the idempotency store and dedup tuple (identity component in §7 here).
- `observability-backend` — audit log property conventions and PII deny-list.
- `infrastructure-wiring` — JWT validation, Keycloak claim mapping into `IUserContext`, M2M token
  acquisition, and the M2M-gated acceptance of propagated user-context headers.
- the repo's `authorization/` folder + `.specify/memory/` — the permission catalog, policy names,
  scope-marker names, and system-principal names (project vocabulary).
