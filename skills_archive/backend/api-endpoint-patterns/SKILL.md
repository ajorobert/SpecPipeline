---
name: api-endpoint-patterns
description: |
  FastEndpoints v6 HTTP-entry patterns for .NET 10 with Scalar OpenAPI, the IAppCommandBus/IAppQueryBus dispatch seam, Result<T>/Error → HTTP (RFC 7807) mapping, FluentValidation request-shape split, idempotency-key contract, request size + rate limits, and BFF/aggregation endpoints. Use for every HTTP entry point.
when_to_load:
  - Task mentions: endpoint, route, http, api, openapi, scalar, bff, aggregation, fan-out
  - Files touched: any *Endpoint.cs, *Endpoint*.cs, *ScreenResponse.cs, BFF aggregation handlers
co_loads_with:
  - backend-architecture (canonical seams, structure, markers, events model — read first)
  - backend-feature-patterns (handler the endpoint dispatches to)
  - authorization-patterns (endpoint policy + IUserContext)
  - integration-adapter-patterns (typed downstream clients for BFF fan-out)
---

# API Endpoint Patterns

Read `backend-architecture` first — it owns the seam catalog, the building-blocks/module structure,
the comment-marker index, the domain/integration event model, and the NetArchTest invariants. This
skill applies them at the **HTTP edge**.

HTTP is an edge, not a seam — FastEndpoints v6 and Scalar are legitimately named here. The edge's job
is to bind the request, **dispatch through `IAppCommandBus`/`IAppQueryBus`**, and project the resulting
`Result<T>`/`Result` to HTTP. Endpoints never name Wolverine, a `DbContext`, a cache, or build a
`ProblemDetails` by hand.

> Assumes FastEndpoints v6 or later. APIs referenced below (typed bases, throttle hooks, Summary class form) are v6 contracts.

## 1. Mental model

An endpoint is a thin HTTP adapter — it binds the request, dispatches to a handler **via the dispatch
seam**, and maps the `Result` to HTTP. Business logic lives in the handler (see `backend-feature-patterns §3`).
One endpoint class = one HTTP operation.

This stack does **not** use MVC controllers — there is no `: ControllerBase`, no `[ApiController]`, no
`[Authorize]` attribute. Reflexes from those patterns must be unlearned. FastEndpoints uses
class-per-endpoint plus `Configure()` for policy declaration.

| Base class | Use for | HTTP shape |
|---|---|---|
| `Endpoint<TRequest>` | Mutations with no response body | POST/PUT/PATCH/DELETE → 204 (or 202) |
| `Endpoint<TRequest, TResponse>` | Mutations or queries with parameters and a response body | POST/PUT/GET → 200/201 |
| `EndpointWithoutRequest<TResponse>` | Queries with no parameters | GET → 200 |
| `EndpointWithoutRequest` | Health/ping endpoints with neither | GET → 200/204 |

The bare `Endpoint` class is forbidden unless the line above carries `// ENDPOINT: Untyped — REASON: <reason>`
(file proxy, raw stream pass-through). CI parses these and emits a manifest of untyped endpoints.

## 2. File and folder layout

The HTTP edge of a module lives in its `*.Api` host slice. Placeholder namespace `YourContext.*`
(substitute the real context name from `system-context.md`).

```
src/YourContext.Api/
  Features/
    Listings/
      Activate/
        ActivateListingEndpoint.cs   // : Endpoint<Request, Response>
        Request.cs                   // record with [FromRoute]/[FromBody]
        Response.cs                  // record (omit for 204 endpoints)
        Validator.cs                 // : Validator<Request> (request-shape only)
        Mapper.cs                    // static — Request → Command, command-result → Response
        Summary.cs                   // : Summary<Endpoint> — Scalar reads this
  Validation/
    CommonRules.cs                   // shared FluentValidation extensions for THIS bounded context
  Http/
    ResultHttpExtensions.cs          // Result<T>/Result → HTTP (this skill, §7)
  YourContextEndpointsMarker.cs      // empty class, used for assembly scanning
```

One `*.Api` slice per bounded context — `YourContext.Api`, `Auth.Api`, `Search.Api`. Each exposes an empty
marker class so the host registers FastEndpoints by referencing the marker types (modular monolith today,
microservice split tomorrow — endpoint code never changes). FastEndpoints/Scalar/host **wiring** (DI, OpenAPI
registration, CORS policy registration) lives in `infrastructure-wiring`, not here.

## 3. Endpoint shape — command-side

Inject `IAppCommandBus` and dispatch via `.Send(command, ct)`, which returns a `Result<T>`. Never inject the
Wolverine `IMessageBus`/`IMessageContext` (NetArchTest invariant #1, `backend-architecture §8`).

```csharp
namespace YourContext.Api.Features.Listings.Activate;

public sealed class ActivateListingEndpoint(IAppCommandBus bus) : Endpoint<Request, Response>
{
    public override void Configure()
    {
        // ENDPOINT: POST /api/v1/listings/{ListingId}/activate
        Post("/api/v1/listings/{ListingId}/activate");
        // AUTH: Policy CanActivateListing — policy name is project vocabulary (authorization-patterns)
        Policies("CanActivateListing");
        Throttle(hitLimit: 30, durationSeconds: 60);
        MaxRequestBodySize(256 * 1024);
        Description(b => b
            .Produces<Response>(200)
            .ProducesProblem(404)
            .ProducesProblem(409));
    }

    public override async Task HandleAsync(Request req, CancellationToken ct)
    {
        // IDEMPOTENCY: header read happens here, forwarded on the command — see §6
        var idem = HttpContext.Request.Headers.TryGetValue("Idempotency-Key", out var v) ? v.ToString() : null;
        var command = Mapper.ToCommand(req, idem);

        // Dispatch seam — backend-architecture §2; returns Result<T>, never throws for expected failures
        var result = await bus.Send(command, ct);
        await this.ToHttpResultAsync(result, Mapper.ToResponse, ct);
    }
}

public sealed record Request
{
    [FromRoute] public Guid ListingId { get; init; }
    [FromBody]  public Body Payload { get; init; } = new();
    public sealed record Body(Guid ActorId);
}

public sealed record Response(Guid ListingId, string Status);

public static class Mapper
{
    public static ActivateListingCommand ToCommand(Request r, string? idem) =>
        new(r.ListingId, r.Payload.ActorId, idem);
    public static Response ToResponse(ActivateListingResult r) =>
        new(r.ListingId, r.Status);
}
```

The endpoint reads the `Idempotency-Key` header, forwards it on the command, dispatches via
`IAppCommandBus.Send`, and maps the `Result<T>` to HTTP through the single extension method defined in §7.
Endpoint code never builds a `ProblemDetails` by hand.

## 4. Endpoint shape — query-side

Inject `IAppQueryBus` and dispatch via `.Execute(query, ct)`, which returns a `Result<T>`.

```csharp
namespace YourContext.Api.Features.Listings.GetDetail;

public sealed class GetListingDetailEndpoint(IAppQueryBus bus) : Endpoint<Request, Response>
{
    public override void Configure()
    {
        // ENDPOINT: GET /api/v1/listings/{ListingId}
        Get("/api/v1/listings/{ListingId}");
        // AUTH: Policy CanReadListing
        Policies("CanReadListing");
        Description(b => b.Produces<Response>(200).ProducesProblem(404));
    }

    public override async Task HandleAsync(Request req, CancellationToken ct)
    {
        var result = await bus.Execute(new GetListingDetailQuery(req.ListingId), ct);
        await this.ToHttpResultAsync(result, Mapper.ToResponse, ct);
    }
}

public sealed record Request { [FromRoute] public Guid ListingId { get; init; } }
```

Query endpoints follow the same dispatch + Result-mapping shape as command endpoints. The only difference is
the verb (`IAppQueryBus.Execute` vs `IAppCommandBus.Send`) and the lack of an idempotency-key read.

## 5. Validators

One validator per endpoint, living next to it. FastEndpoints discovers it via `Validator<TRequest>`.

**Split rule:** request-validator handles input *shape* (non-empty, length, regex); command-validator (lives
in Application — see `backend-feature-patterns §7`) handles *business* rules. Never duplicate a rule across
both — pick a side based on whether the rule is about syntax or semantics.

```csharp
public sealed class ActivateListingValidator : Validator<ActivateListingEndpoint.Request>
{
    public ActivateListingValidator()
    {
        RuleFor(x => x.ListingId).NotEmpty();
        RuleFor(x => x.Payload.ActorId).NotEmpty();
    }
}
```

Cross-cutting rules used by multiple endpoints in the same bounded context go in `Validation/CommonRules.cs`
as FluentValidation extension methods.

## 6. Idempotency-Key contract (HTTP side)

Header: `Idempotency-Key: <ulid-or-uuid>`. Required on every state-mutating endpoint that creates or charges
state (POST, plus PUT/PATCH/DELETE that have business-level retry implications); optional on safe verbs.

**Endpoint duties:**

1. Read the header.
2. Forward it on the command as `IdempotencyKey`.
3. The handler-side dedup logic lives in `backend-feature-patterns §9`.

**Failure modes** (mapped automatically by the Result→HTTP extension in §7):

| Condition | Error | HTTP |
|---|---|---|
| Missing header on a required endpoint | `Error.Validation("Http.IdempotencyKeyRequired")` | 400 |
| Replayed key with different fingerprint | `Error.Conflict("Http.IdempotencyKeyReused")` | 409 |
| In-flight replay (same key, same fingerprint, original still running) | `Error.Conflict("Http.IdempotencyInProgress")` | 409 |

```csharp
public override async Task HandleAsync(Request req, CancellationToken ct)
{
    // IDEMPOTENCY: read header; forward on command; handler enforces dedup
    if (!HttpContext.Request.Headers.TryGetValue("Idempotency-Key", out var key) || string.IsNullOrEmpty(key))
    {
        await this.ToHttpResultAsync<Response>(Error.Validation("Http.IdempotencyKeyRequired"), ct);
        return;
    }
    var result = await bus.Send(Mapper.ToCommand(req, key!), ct);
    await this.ToHttpResultAsync(result, Mapper.ToResponse, ct);
}
```

## 7. Result → HTTP mapping

A single extension method maps every `Result<T>`/`Result` to HTTP + RFC 7807 ProblemDetails. Endpoints call
it; they never construct ProblemDetails by hand. `Result`/`Error` come from `BuildingBlocks.Contracts`. The
extension lives in `src/YourContext.Api/Http/`; this skill specifies the contract.

ProblemDetails `type` URI: `https://errors.yourcompany.com/your-service/<error-code>` — `<error-code>` is the
dotted code from `Error.Code` (e.g. `Listing.AlreadyActive`). The host base and slug are project vocabulary
(`backend-architecture §1`).

```csharp
namespace YourContext.Api.Http;

public static class ResultHttpExtensions
{
    // Use when there is a typed response body to send on success
    public static Task ToHttpResultAsync<TResult, TResponse>(
        this IEndpoint endpoint,
        Result<TResult> result,
        Func<TResult, TResponse> map,
        CancellationToken ct)
    {
        if (!result.IsError)
            return endpoint.HttpContext.Response.SendAsync(map(result.Value), 200, cancellation: ct);
        return endpoint.SendProblemAsync(result.Errors[0], ct);
    }

    // Use when the success path is 204 No Content (Result, no value)
    public static Task ToHttpResultAsync(this IEndpoint endpoint, Result result, CancellationToken ct)
        => result.IsError
            ? endpoint.SendProblemAsync(result.Errors[0], ct)
            : endpoint.HttpContext.Response.SendNoContentAsync(ct);

    // Overload for the early-return error path (no success value to map)
    public static Task ToHttpResultAsync<TResponse>(this IEndpoint endpoint, Error error, CancellationToken ct)
        => endpoint.SendProblemAsync(error, ct);

    private static Task SendProblemAsync(this IEndpoint endpoint, Error error, CancellationToken ct)
    {
        var (status, slug) = error.Type switch
        {
            ErrorType.Validation => (400, "validation"),
            ErrorType.NotFound   => (404, "not-found"),
            ErrorType.Conflict   => (409, "conflict"),
            ErrorType.Forbidden  => (403, "forbidden"),
            _                    => (500, "internal"),   // Error.Failure → 500
        };
        var problem = new ProblemDetails
        {
            Status   = status,
            Title    = error.Description,
            Type     = $"https://errors.yourcompany.com/your-service/{error.Code}",
            Instance = $"urn:trace:{Activity.Current?.TraceId.ToString() ?? "none"}",
        };
        problem.Extensions["code"] = error.Code;
        return endpoint.HttpContext.Response.SendAsync(problem, status, cancellation: ct);
    }
}
```

Five `ErrorType` values cover the surface: `Validation` (400), `NotFound` (404), `Conflict` (409),
`Forbidden` (403), `Failure` (default fall-through → 500). Anything outside this set is a bug. This mapping
matches the `Error`-kind table in `backend-feature-patterns §6`.

## 8. Scalar OpenAPI integration

Scalar is the OpenAPI UI in this stack — there is no Swagger UI. Each endpoint declares a nested `Summary` class
(not the lambda overload). Scalar reads the resulting OpenAPI doc; route grouping comes from FastEndpoints'
`Group()` for OpenAPI tags.

```csharp
public sealed class Summary : Summary<ActivateListingEndpoint>
{
    public Summary()
    {
        this.Summary       = "Activate a listing";
        this.Description   = "Transitions a listing from Draft to Active. Idempotent on (ListingId).";
        this.ExampleRequest = new ActivateListingEndpoint.Request { ListingId = Guid.NewGuid() };
        this.Response<ActivateListingEndpoint.Response>(200, "Listing activated");
        this.Response<ProblemDetails>(400, "Validation failure");
        this.Response<ProblemDetails>(404, "Listing not found");
        this.Response<ProblemDetails>(409, "Listing already active");
    }
}
```

Missing `Summary` class on a non-untyped endpoint is a CI failure. Generated OpenAPI must be usable by
BFF/portal teams without hand-editing.

## 9. Rate limiting

Two options. Pick by whether the limit must be shared across instances.

- **Per-instance throttle** — `Throttle(hitLimit, durationSeconds)` (FastEndpoints built-in, in-memory). Use
  for abuse prevention: login burst, OTP request floods. Effective for "one client cannot hammer one pod";
  ineffective for "tenant cannot exceed N requests/min across the fleet".
- **Shared-across-instances** — `IRateLimiter` adapter backed by a Redis sliding window (see `caching-patterns`).
  Use for fairness and quota — anything advertised as a request rate must be measured against shared counters.

Decision rule: in-memory throttle for *abuse prevention*; `IRateLimiter` for *fairness/quota*. Throttle keys for
the in-memory path follow the auth-aware precedence (`u:<user_id>` for authenticated; `t:<tenant_id>|ip:<ip>`
for anonymous tenant-scoped; `ip:<ip>` last resort). Throttled responses MUST set `Retry-After` (seconds).

## 10. Request size, allowed verbs, CORS

- **Body size** — every endpoint accepting a body declares `MaxRequestBodySize(bytes)` inside `Configure()`.
  Defaults are too generous. Sensitive endpoints (login, OTP, password reset) cap at 10 KB; standard JSON write
  at 256 KB; bulk write at 1 MB (consider messaging instead). File upload sizes are per-endpoint and paired with
  virus scan (see `file-pipeline-patterns` for the presigned-upload endpoint shape).
- **Verb restriction** — explicit in `Configure()` via `Post(...)`, `Put(...)` etc. No catch-all verbs.
- **CORS** — registered as a FastEndpoints policy in the host composition (`infrastructure-wiring`); endpoints
  opt in by policy name.

## 11. BFF / aggregation endpoints

**BFF is not mandatory for all routes** — it is a tool used when a call flow genuinely needs it. Backend
modules/services accept both direct client calls (with user JWT) and BFF calls (with M2M token). The decision is
made per route, documented in the contract spec. Downstream calls use the typed clients from
`integration-adapter-patterns` (typed `HttpClient` + DelegatingHandler chain + Polly v8 resilience).

### Decision — BFF vs direct

Use **BFF** when:
- The response requires data from **more than one** backend module/service (fan-out / aggregation).
- The response shape needs significant **transformation** away from any single service's return.
- The route must **hide internal service topology** from the client.
- Cross-cutting concerns must be **centralised** for a group of routes: consistent error translation,
  per-user rate limiting, request coalescing.
- The client is a **Next.js server component** making multiple backend calls — the BFF hop is server-side
  anyway, so the extra latency is negligible.

Use **direct** when:
- The route touches **exactly one** backend service with no aggregation.
- The service's response shape is already frontend-friendly.
- **Latency** matters more than aggregation (real-time geo search, live availability).
- The API is **public/unauthenticated** (public browse, CMS content).
- The endpoint is **internal** (service-to-service) — never goes through BFF.

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

### User-context propagation

- **Direct flow** (client → service with user JWT): the service owns full auth — validates the JWT, extracts
  claims into `IUserContext`, applies RBAC + ABAC. See `authorization-patterns`.
- **BFF flow** (client → BFF → services with M2M): the BFF validates the user JWT **once**, then calls each
  downstream with an **M2M token** plus the propagated user context. Downstream services still apply RBAC + ABAC
  using the propagated context — they do not blindly trust the BFF.
- Propagated user-context headers (`X-User-Id`, `X-Tenant-Id`, `X-User-Roles`) are **internal only**. A service
  trusts them **only** when the caller presents a valid M2M token — never accept these headers from external
  callers. The M2M-token check (and mapping into `IUserContext`) is `authorization-patterns`; JwtBearer/M2M
  wiring is `infrastructure-wiring`.

```csharp
// In the BFF — after validating the user JWT, forward context as typed headers
private static HttpRequestMessage AddUserContext(HttpRequestMessage req, IUserContext user)
{
    req.Headers.Add("X-User-Id",    user.UserId.ToString());
    req.Headers.Add("X-Tenant-Id",  user.TenantId.ToString());
    req.Headers.Add("X-User-Roles", string.Join(",", user.Roles));
    return req;
}
```

### Credential safety

- The M2M client secret lives **only** in server-side configuration — never in `NEXT_PUBLIC_*`, `VITE_*`, or any
  client bundle.
- **Never log** `Authorization` headers, M2M tokens, or user JWTs. Token redaction is on the observability
  deny-list (`observability-backend`).
- M2M-token acquisition + caching is a downstream-client concern — see `integration-adapter-patterns`
  (M2M token attachment in the DelegatingHandler chain); the BFF endpoint never mints tokens inline.

### Parallel fan-out

Run independent downstream calls with `Task.WhenAll` — never sequential awaits. Per downstream: a **timeout**
and **circuit breaker** (Polly v8, configured on the typed client per `integration-adapter-patterns`). Declare
explicitly per route which downstream failures degrade to a partial response vs fail the whole request.

```csharp
public async Task<ListingDetailScreenResponse> GetListingDetailAsync(
    ListingId listingId, IUserContext user, CancellationToken ct)
{
    // Critical downstream — its failure fails the request (Polly surfaces the exception → §error translation → 502)
    var listingTask = _listingClient.GetAsync(listingId, ct);
    var savedTask   = _savedClient.IsSavedAsync(listingId, ct);

    // Optional downstream — explicitly degradable (see graceful-degradation rule below)
    var reviewsTask = GetReviewsOrEmptyAsync(listingId, ct);

    await Task.WhenAll(listingTask, savedTask, reviewsTask);

    return ScreenMapper.ToScreen(listingTask.Result, reviewsTask.Result, savedTask.Result);
}
```

### Graceful degradation (explicitly-optional downstreams only)

Only an **explicitly optional** downstream may degrade. Never a bare `catch {}` — log the failure through the
observability seam and swallow only the narrow transient failure type. A **critical** downstream's failure
propagates and the request fails (→ 502 via error translation).

```csharp
// Optional downstream — reviews enrich the page but are not required to render it.
// LOG: downstream degradation — emit via the observability seam (observability-backend), never swallow silently.
private async Task<IReadOnlyList<ReviewSummaryDto>> GetReviewsOrEmptyAsync(ListingId id, CancellationToken ct)
{
    try
    {
        return await _reviewClient.GetForListingAsync(id, pageSize: 5, ct);
    }
    catch (DownstreamUnavailableException ex)   // narrow, transient — NOT a bare catch
    {
        _log.LogWarning(ex, "Reviews downstream degraded for {ListingId}; rendering without reviews", id);
        return [];   // page still renders — reviews are explicitly optional for THIS route
    }
}
```

### Error translation

Never expose downstream service names, stack traces, or internal messages to the client. Map to RFC 7807
`ProblemDetails` via the §7 extension:

| Downstream result | Client status |
|---|---|
| 404 (resource not found) | 404 |
| 409 (state conflict) | 409 |
| 5xx / timeout / circuit-open on a **critical** downstream | **502** |

Direct-call routes need no translation layer — the owning service already returns `ProblemDetails`.

### Two-DTO-layer rule

| DTO type | Owner | Shape driven by | Example |
|---|---|---|---|
| **Application DTO** | the owning service's Application layer (query-handler return) | the use case / read model — stable, versioned per the service's API contract | `ListingDetailDto`, returned from a query handler |
| **BFF / screen DTO** | the BFF aggregation handler | the specific frontend screen — composed from one or more Application DTOs; may rename, flatten, drop, merge | `ListingDetailScreenResponse` (combines `ListingDetailDto` + `ReviewSummaryDto[]` + saved flag) |

- The BFF **must not return an Application DTO directly** — even if the shape is identical today. Wrap it in a
  BFF/screen DTO so the frontend contract evolves independently of the service contract. A field rename in a
  service DTO must not ripple to the frontend.
- Application DTOs appear in the owning service's OpenAPI spec; BFF/screen DTOs appear only in the BFF's spec.
- Direct-call routes are the explicit exception: the service's Application DTO is the on-the-wire contract and
  the frontend depends on it directly. Document this choice — it trades coupling for latency.

## 12. Anti-patterns

- Business logic inside `HandleAsync` (anything beyond bind + dispatch + map).
- Injecting Wolverine `IMessageBus`/`IMessageContext` — dispatch is only `IAppCommandBus`/`IAppQueryBus`
  (NetArchTest invariant #1, `backend-architecture §8`).
- Reading `DbContext`, `HybridCache`, or repositories directly from the endpoint.
- Catching exceptions in the endpoint to convert them to errors — the dispatch pipeline turns failures into
  `Result`; ASP.NET Core handles the rest.
- Multiple commands dispatched from one endpoint — split into separate endpoints.
- Sharing a single DTO between the endpoint's `Response` and the Application layer's command/query result — keep
  Api-layer DTOs separate from Application-layer DTOs (and a BFF screen DTO separate from both, §11).
- `[Authorize]` attribute — FastEndpoints uses `.Policies(...)` / `.AllowAnonymous()` inside `Configure()`
  (`authorization-patterns`).
- FastEndpoints `Mapper<TRequest, TResponse, TEntity>` base class — it pulls the domain entity into the Api layer.
- In-memory throttle in production for fairness-style limits (multi-pod = N×limit leak).
- BFF: bare `catch {}` graceful degradation; logging or returning `Authorization`/token values; returning an
  Application DTO directly; sequential awaits across independent downstreams; leaking downstream service names.

## 13. Comment markers emitted by this skill

This skill owns and emits:

- `// ENDPOINT:` — route + verb on the line above `Post(...)` / `Get(...)` / etc. For untyped endpoints use the
  exact form `// ENDPOINT: Untyped — REASON: <reason>` (CI manifest).
- `// AUTH:` — authorization policy/permission on the endpoint. For anonymous endpoints, use the exact form
  `// AUTH: Anonymous — REASON: <reason>` (CI parses this and emits a manifest). Policy/permission *names* are
  project vocabulary (`authorization-patterns`).
- `// IDEMPOTENCY:` — the line that reads the `Idempotency-Key` header (or annotates the dedup contract).

The canonical cross-skill marker index and the `// CONFIGUREAWAIT:` rule live in `backend-architecture §7`.

## 14. References

- `backend-architecture` — seams, structure, marker index, events model, invariants (read first).
- `backend-feature-patterns` §3, §6, §9 — handler shape, Result/Error contract, idempotency handler-side.
- `authorization-patterns` — endpoint policies, `RequiresPermission`, `IUserContext`, M2M-token validation.
- `integration-adapter-patterns` — typed downstream clients, M2M token attachment, Polly v8 resilience for BFF fan-out.
- `caching-patterns` — `IRateLimiter` adapter, idempotency-key storage.
- `observability-backend` — downstream-degradation logging, token/PII deny-list.
- `infrastructure-wiring` — FastEndpoints/Scalar host registration, JwtBearer/M2M config, CORS policy registration.
