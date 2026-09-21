---
name: keycloak-patterns
description: |
  Keycloak OIDC/JWT authentication and authorization for .NET 10 with FastEndpoints. Covers JWT bearer validation, claim mapping, IUserContext canonical contract, RBAC via policies, ABAC via authorization handlers, M2M client-credentials, and the request-pipeline integration. Use for every protected endpoint, every handler that reads identity, every audit log.
when_to_load:
  - Task mentions: auth, authentication, authorization, jwt, bearer, keycloak, oidc, mfa, otp, policy, role, claim, user context, m2m, service-to-service
  - Files touched: any *Endpoint.cs with auth requirements, any *Handler.cs reading IUserContext, Program.cs (only for auth-pipeline review)
co_loads_with:
  - fastendpoints-patterns (endpoint-side policy/role syntax)
  - backend-feature-patterns (IUserContext used inside handlers)
references:
  - wolverine-patterns (M2M token forwarding on outbound integration events — one-line note in §8)
---

# Keycloak Patterns

## 1. Mental model

```
Identity provider (Keycloak)
    │ issues JWT (RS256) signed with realm keypair
    ▼
HTTP request with `Authorization: Bearer <jwt>`
    │
    ▼
FastEndpoints endpoint
    │ JwtBearer middleware validates signature, expiry, issuer, audience
    │ → ClaimsPrincipal on HttpContext.User
    ▼
ClaimsToUserContext middleware
    │ → flattens into IUserContext (request-scoped DI)
    ▼
Handler / service code
    └─ injects IUserContext  (NEVER HttpContext.User)
```

The app is stateless with respect to auth — no session table, no token cache, no refresh logic. Keycloak issues; this app only validates. Why `IUserContext`: type-safe, no string-key claim lookups inside handlers, trivially testable without a JWT fixture.

## 2. IUserContext contract

This skill owns the contract that `backend-feature-patterns §3` depends on. Request-scoped DI; claim-derived in middleware; never mutated downstream.

```csharp
namespace YourContext.Application.Auth;

public interface IUserContext
{
    Guid UserId { get; }
    Guid TenantId { get; }
    IReadOnlySet<string> Roles { get; }
    IReadOnlySet<string> Permissions { get; }   // fine-grained, claim-derived
    bool IsViaM2M { get; }
    string? PreferredUsername { get; }
    bool IsInRole(string role);
    bool HasPermission(string permission);
}
```

In tests, substitute a fake `IUserContext` directly — no JWT, no Keycloak. Production code obtains it through constructor injection only; never resolves it from `IHttpContextAccessor` or static state.

## 3. JWT validation rules

The canonical configuration contract — every protected service uses this shape.

```csharp
builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(opt =>
    {
        opt.Authority = config["Keycloak:Authority"]; // e.g. https://auth.example.com/realms/<realm>
        opt.Audience  = config["Keycloak:ClientId"];
        opt.MapInboundClaims = false;                 // preserve Keycloak claim names as-is
        opt.TokenValidationParameters = new()
        {
            ValidateIssuer           = true,
            ValidateAudience         = true,
            ValidateLifetime         = true,
            ValidateIssuerSigningKey = true,
            ClockSkew                = TimeSpan.FromSeconds(30),
            NameClaimType            = "preferred_username",
            RoleClaimType            = "realm_access.roles",
        };
    });
```

| Setting | Value | Why |
|---|---|---|
| Token algorithm | RS256 (Keycloak default) | Asymmetric; JWKS-based |
| Access-token lifespan | 5–15 min | Short; refresh handled by clients |
| Clock skew | 30s max | Tolerates NTP drift, no more |
| JWKS refresh | 5–10 min (middleware default) | Survives realm key rotation without app restart |
| `MapInboundClaims` | `false` | Preserve Keycloak claim names verbatim |

Token refresh is the client's responsibility. The backend never refreshes, stores, or tracks tokens.

## 4. Claim mapping

The mapping happens once in `ClaimsToUserContextMiddleware`, registered **after** `UseAuthentication()` and **before** `UseAuthorization()`. Downstream code reads `IUserContext`, never the raw principal.

| Keycloak claim | Maps to | Notes |
|---|---|---|
| `sub` | `UserId` (Guid) | Parse; throw on invalid for non-M2M |
| `tenant_id` (custom) | `TenantId` (Guid) | Required for non-M2M tokens |
| `realm_access.roles` | `Roles` | Realm-level roles |
| `resource_access.<client>.roles` | `Permissions` | Client-level fine-grained |
| `preferred_username` | `PreferredUsername` | Optional |
| `azp` == client_id (M2M) | `IsViaM2M = true` | Sets when no `sub` present |

```csharp
public sealed class ClaimsToUserContextMiddleware(RequestDelegate next)
{
    public async Task Invoke(HttpContext ctx, UserContextHolder holder, IConfiguration cfg)
    {
        // CONFIGUREAWAIT: middleware library code; handlers omit ConfigureAwait.
        if (ctx.User.Identity?.IsAuthenticated == true)
        {
            var p = ctx.User;
            var azp = p.FindFirstValue("azp");
            var isM2M = !string.IsNullOrEmpty(azp) && string.IsNullOrEmpty(p.FindFirstValue("sub"));
            // CLAIM-MAP: M2M tokens have no `sub`; identity is the client's `azp`.
            var userId = isM2M ? Guid.Empty : Guid.Parse(p.FindFirstValue("sub")!);
            var tenantId = Guid.TryParse(p.FindFirstValue("tenant_id"), out var t) ? t : Guid.Empty;
            var roles = p.FindAll("realm_access.roles").Select(c => c.Value).ToHashSet();
            var perms = p.FindAll($"resource_access.{cfg["Keycloak:ClientId"]}.roles")
                         .Select(c => c.Value).ToHashSet();
            holder.Set(new UserContext(userId, tenantId, roles, perms, isM2M, p.FindFirstValue("preferred_username")));
        }
        await next(ctx).ConfigureAwait(false);
    }
}
```

`UserContextHolder` is a request-scoped class that backs `IUserContext`; downstream code injects `IUserContext` and reads from it. Registration: `services.AddScoped<UserContextHolder>(); services.AddScoped<IUserContext>(sp => sp.GetRequiredService<UserContextHolder>().Current);`.

## 5. RBAC: policies via authorization builder

Modern .NET pattern — `AddAuthorizationBuilder()`. Policy naming: `<aggregate>.<verb>`. Endpoints reference policies by name; never role strings.

```csharp
public static AuthorizationBuilder AddYourContextAuthorization(this AuthorizationBuilder authz) => authz
    .AddPolicy("listings.read",     p => p.RequireAuthenticatedUser())
    .AddPolicy("listings.write",    p => p.RequireRole("vendor", "admin"))
    .AddPolicy("listings.activate", p => p.RequireRole("vendor", "admin")
                                          .RequireClaim("vendor_verified", "true"))
    .AddPolicy("vendors.admin",     p => p.RequireRole("admin"))
    .AddPolicy("CanEditListing",    p => p.Requirements.Add(new ResourceOwnerRequirement()));

// Registration
builder.Services.AddAuthorizationBuilder().AddYourContextAuthorization();
```

The endpoint side declares `.Policies("listings.write")` inside `Configure()` — see `fastendpoints-patterns §3` for the `// AUTH:` marker convention. CI parses `// AUTH:` lines to manifest the policy → endpoint matrix.

## 6. ABAC: authorization handlers

RBAC answers "can this role access this area?". ABAC answers "can *this user* act on *this resource*?". ABAC handlers receive a pre-loaded resource — they do **not** call the database. The endpoint (or feature handler) loads the resource once.

```csharp
namespace YourContext.Application.Auth.Requirements;

public sealed class ResourceOwnerRequirement : IAuthorizationRequirement { }

public sealed class ListingOwnerHandler(IUserContext user)
    : AuthorizationHandler<ResourceOwnerRequirement, Listing>
{
    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext ctx, ResourceOwnerRequirement req, Listing listing)
    {
        if (listing.OwnerId.Value == user.UserId || user.IsInRole("admin"))
            ctx.Succeed(req);
        return Task.CompletedTask;
    }
}
```

The endpoint loads the resource and authorizes against the policy — replacing the old MVC + `[Authorize]` pattern:

```csharp
namespace YourContext.Api.Features.Listings.Update;

public sealed class UpdateListingEndpoint(IMessageBus bus, IAuthorizationService authz, IListingReadService reads)
    : Endpoint<Request, Response>
{
    public override void Configure()
    {
        // ENDPOINT: PATCH /api/v1/listings/{ListingId}
        Patch("/api/v1/listings/{ListingId}");
        // AUTH: policy listings.write (RBAC) + CanEditListing (ABAC via resource handler)
        Policies("listings.write");
    }

    public override async Task HandleAsync(Request req, CancellationToken ct)
    {
        var listing = await reads.GetByIdAsync(req.ListingId, ct);
        if (listing is null) { await this.ToHttpResultAsync<Response>(Error.NotFound("Listing.NotFound"), ct); return; }

        var authz1 = await authz.AuthorizeAsync(HttpContext.User, listing, "CanEditListing");
        if (!authz1.Succeeded) { await this.ToHttpResultAsync<Response>(Error.Forbidden("Listing.NotOwner"), ct); return; }

        var result = await bus.InvokeAsync<ErrorOr<UpdateListingResult>>(Mapper.ToCommand(req), ct);
        await this.ToHttpResultAsync(result, Mapper.ToResponse, ct);
    }
}
```

Reads are not exempt from ABAC. A query handler returning a single resource (e.g. a draft listing) authorizes the same way; a query handler returning a collection enforces ABAC by **scoping the predicate** (`WHERE owner_id = @callerId`) rather than per-row filtering after fetch.

## 7. Token validation failures and error responses

Most auth failures happen at middleware before the handler runs — they are mapped by ASP.NET Core directly.

| Failure | HTTP | Header |
|---|---|---|
| Missing / malformed token | 401 Unauthorized | `WWW-Authenticate: Bearer` |
| Expired token | 401 Unauthorized | `WWW-Authenticate: Bearer error="invalid_token"` |
| Valid token, missing policy | 403 Forbidden | — |

When auth fails inside a handler (e.g. ABAC fails on a resource), the handler returns `Error.Forbidden(...)` and `fastendpoints-patterns §7` maps it to 403.

## 8. M2M (service-to-service)

Keycloak client-credentials grant. Each service has one Keycloak service account with minimal scopes. No shared credentials.

```csharp
namespace YourContext.Application.Auth;

public interface IM2MTokenProvider
{
    ValueTask<string> GetAccessTokenAsync(CancellationToken ct);
}

// Adapter: caches per-service token for (expiresIn − 30s).
public sealed class KeycloakM2MTokenProvider(IHttpClientFactory httpFactory, IOptions<KeycloakOptions> opts, HybridCache cache)
    : IM2MTokenProvider
{
    public async ValueTask<string> GetAccessTokenAsync(CancellationToken ct)
        => await cache.GetOrCreateAsync(
            $"yourcontext:m2m:{opts.Value.ServiceClientId}",
            async token =>
            {
                // CONFIGUREAWAIT: adapter library code.
                var http = httpFactory.CreateClient("keycloak");
                var resp = await http.PostAsync($"/realms/{opts.Value.Realm}/protocol/openid-connect/token",
                    new FormUrlEncodedContent(new Dictionary<string, string>
                    {
                        ["grant_type"]    = "client_credentials",
                        ["client_id"]     = opts.Value.ServiceClientId,
                        ["client_secret"] = opts.Value.ServiceClientSecret,
                    }), token).ConfigureAwait(false);
                var body = await resp.Content.ReadFromJsonAsync<TokenResponse>(token).ConfigureAwait(false);
                return body!.AccessToken;
            },
            new() { Expiration = TimeSpan.FromMinutes(4) }, // tune via TokenResponse.ExpiresIn − 30s
            cancellationToken: ct);
}
```

**HttpClient handler chain.** M2M token attachment is a `DelegatingHandler` registered **before** Polly resilience policies (see `integration-adapter-patterns` §4 for the chain-order joint rule) — so retries replay the attached header rather than re-acquiring a token per attempt.

```csharp
public sealed class M2MTokenHandler(IM2MTokenProvider provider) : DelegatingHandler
{
    protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage req, CancellationToken ct)
    {
        var token = await provider.GetAccessTokenAsync(ct).ConfigureAwait(false);
        req.Headers.Authorization = new("Bearer", token);
        return await base.SendAsync(req, ct).ConfigureAwait(false);
    }
}
```

**Cross-context integration events do NOT carry the originating user's JWT.** They carry `tenant_id` + `originating_user_id` as message metadata — see `wolverine-patterns §6`. The receiving context resolves authorization fresh against its own boundary.

## 9. Idempotency + auth interaction

The HTTP idempotency-key dedup tuple includes `UserId` (or M2M `client_id` when `IsViaM2M`). A replay from a *different* user with the *same* key is a 409 Conflict — see `backend-feature-patterns §8` for the handler-side store and `fastendpoints-patterns §6` for the HTTP-side contract.

## 10. Audit logging hooks

Every state-mutating handler logs the user context as structured fields using OTel semantic conventions:

```
user.id            → IUserContext.UserId
user.tenant_id     → IUserContext.TenantId
user.via_m2m       → IUserContext.IsViaM2M
http.idem.key      → Command.IdempotencyKey (when present)
aggregate.id       → the mutated aggregate's id
operation          → the command type name (or a slug)
```

See `observability-backend` for the full property convention table and PII deny-list. `preferred_username` is borderline — redact in audit unless the audit story explicitly requires it.

## 11. Testing

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

Unit-test handlers with a fake `IUserContext` — no JWT, no middleware. Endpoint integration tests use either a test-only middleware that synthesizes an identity from test config, or mint a JWT against a Keycloak test realm via `Testcontainers.Keycloak`.

## 12. Anti-patterns

- Injecting `ClaimsPrincipal` or `IHttpContextAccessor` into handlers — use `IUserContext`.
- String-keyed claim lookups outside `ClaimsToUserContextMiddleware`.
- `[Authorize]` MVC attribute — FastEndpoints uses `.Policies()` / `.Roles()` in `Configure()`.
- Loading the resource inside an ABAC handler — the endpoint loads once and passes it.
- Long-lived JWTs (> 1 hour) — refresh tokens exist for a reason.
- Custom JWT signing in this app — Keycloak issues; this app only validates.
- Caching user permissions outside request scope — claims can change; refetch per request.
- Treating M2M tokens as if they have a user identity — no `sub`; check `IsViaM2M` first.

## 13. Comment markers emitted by this skill

- `// AUTH:` — shared with `fastendpoints-patterns`; annotates every policy/role enforcement point. Anonymous endpoints use the exact form `// AUTH: Anonymous — REASON: <reason>` (CI manifests these).
- `// CLAIM-MAP:` — annotates non-obvious claim → `IUserContext` field translations inside the middleware.

The canonical comment-markers index lives in `backend-feature-patterns §10`.

## 14. References

- `fastendpoints-patterns §3` — `.Policies()` / `.Roles()` in endpoint `Configure()`; the `// AUTH:` marker.
- `backend-feature-patterns §3, §8` — `IUserContext` injection into handlers; idempotency tuple includes `UserId`.
- `wolverine-patterns §6` — integration events carry `tenant_id` + `originating_user_id` as metadata, never the JWT.
- `integration-adapter-patterns` §4 — M2M token attachment is a `DelegatingHandler` registered before Polly policies.
- `observability-backend` — audit log property conventions and PII deny-list.
- `.specify/memory/system-context.md` — deployment topology (Keycloak realm, M2M client roster).
