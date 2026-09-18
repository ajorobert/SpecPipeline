---
name: feature-management-patterns
description: |
  Runtime feature toggles for .NET 10 via Microsoft.FeatureManagement. Covers IFeatureManagerSnapshot (request-scoped) vs IFeatureManager, built-in filters (Percentage, TimeWindow, Targeting), custom filters for ABAC-style targeting, variant features, endpoint/handler gating, flag-naming convention, sunset discipline. Use whenever a feature is rolled out gradually or A/B tested.
when_to_load:
  - Task mentions: feature flag, feature toggle, rollout, gradual release, percentage rollout, a/b test, variant, gating, IFeatureManager, sunset
  - Files touched: any *FeatureFilter.cs, feature flag definitions in appsettings.json, any handler/endpoint with conditional behavior keyed off flags
co_loads_with:
  - backend-architecture (canonical seams, structure, markers, events model — read first)
  - backend-feature-patterns (gating inside handlers)
  - api-endpoint-patterns (gating at the endpoint layer)
references:
  - authorization-patterns (TargetingFilter reads IUserContext for ABAC-style targeting)
---

# Feature Management Patterns

## 1. Mental model

A feature flag is a named boolean (or variant) that gates a code path at runtime. Two consumption shapes:

| API | Scope | Use when |
|---|---|---|
| `IFeatureManagerSnapshot` | **request-scoped** — value locked at first access for the lifetime of the request | **Default.** Consistent evaluation within a single request — handlers, endpoints. |
| `IFeatureManager` | re-evaluates on every call | Long-lived background work, polling loops where re-evaluation IS desired. |

Three flag kinds: **Boolean** (`IsEnabledAsync` returns bool), **Filtered** (boolean evaluated via a registered filter), **Variant** (`GetVariantAsync` returns variant name + payload — A/B and multi-variant rollouts).

## 2. Flag naming convention

- kebab-case.
- Format: `<aggregate>.<intent>` or `<aggregate>.<intent>.<phase>` — e.g. `listings.new-flow`, `listings.geo-search-v2`, `vendors.kyc.beta`.
- **Do NOT** use boolean names like `feature-x-on`, `temp-flag`, `flag-1` — name the FEATURE, not the state.
- Every flag carries a sunset date in metadata (see §8).

## 3. Handler-side gating

Inject `IFeatureManagerSnapshot` into the handler (see `backend-feature-patterns §3` for handler shape). Branch with `IsEnabledAsync`; the new and old paths both return `Result<T>`.

```csharp
namespace YourContext.Application.Features.Listings.Search;

public sealed class SearchListingsHandler(IFeatureManagerSnapshot flags, IListingSearchService legacy, IListingSearchServiceV2 v2)
{
    public async Task<Result<PagedResult<ListingCardDto>>> Handle(SearchListingsQuery q, CancellationToken ct)
    {
        // FLAG: listings.geo-search-v2 — gradual rollout of the v2 search path
        if (await flags.IsEnabledAsync("listings.geo-search-v2"))
            return await v2.SearchAsync(q, ct);
        return await legacy.SearchAsync(q, ct);
    }
}
```

## 4. Endpoint-side gating

Two shapes (see `api-endpoint-patterns` for endpoint shape and the bus dispatch seam):

```csharp
// (a) Inside HandleAsync — preferred when the endpoint exists in both states
public override async Task HandleAsync(Request req, CancellationToken ct)
{
    // FLAG: listings.new-flow
    var result = await _flags.IsEnabledAsync("listings.new-flow")
        ? await _bus.Send(new NewFlowCommand(req), ct)
        : await _bus.Send(new LegacyCommand(req), ct);
    await this.ToHttpResultAsync(result, Mapper.ToResponse, ct);
}

// (b) [FeatureGate] attribute — preferred when the endpoint should not exist at all when off
[FeatureGate("vendors.kyc.beta")]
public sealed class StartKycVerificationEndpoint(IAppCommandBus bus) : Endpoint<Request, Response>
{
    public override void Configure() { Post("/api/v1/vendors/kyc/start"); Policies("vendors.write"); }
    // when off: FeatureGate returns 404 automatically
}
```

## 5. Built-in filters

| Filter | Use |
|---|---|
| `PercentageFilter` | Percentage rollout. Stable per-request via hash — same request gets same answer in repeats. |
| `TimeWindowFilter` | Flag is on within a time range. Useful for launches. |
| `TargetingFilter` | Per-user or per-group targeting via `ITargetingContextAccessor`. |

Configuration via `appsettings.json` (the canonical source for V1):

```json
{
  "FeatureManagement": {
    "listings.geo-search-v2": {
      "EnabledFor": [
        { "Name": "Microsoft.Percentage", "Parameters": { "Value": 25 } },
        { "Name": "Microsoft.TimeWindow", "Parameters": { "Start": "2026-06-01T00:00:00Z", "End": "2026-09-01T00:00:00Z" } },
        { "Name": "Microsoft.Targeting",  "Parameters": { "Audience": { "Groups": [ { "Name": "beta", "RolloutPercentage": 100 } ] } } }
      ],
      "metadata": { "owner": "search-team", "sunset": "2026-09-15" }
    }
  }
}
```

## 6. Custom filters (ABAC-style targeting)

Implement `IFeatureFilter` for tenant-aware decisions. Inject `IUserContext` (see `authorization-patterns`) so the filter targets by tenant or role without re-parsing JWT claims. Filters run on every flag check — keep them cheap; no external I/O.

```csharp
namespace YourContext.Infrastructure.FeatureFlags;

[FilterAlias("YourContext.Tenant")]
public sealed class TenantFilter(IUserContext user) : IFeatureFilter
{
    public Task<bool> EvaluateAsync(FeatureFilterEvaluationContext context)
    {
        var allowed = context.Parameters.GetSection("TenantIds").Get<HashSet<Guid>>() ?? [];
        return Task.FromResult(allowed.Contains(user.TenantId));
    }
}
// Registration: services.AddFeatureManagement().AddFeatureFilter<TenantFilter>();
```

## 7. Variant features (A/B and multi-variant rollouts)

`IVariantFeatureManagerSnapshot.GetVariantAsync(name)` returns a `Variant` with a `Name` plus optional `Configuration` payload. Each variant is declared in config with an allocation percentage.

```csharp
public async Task<Result<ListingDetailDto>> Handle(GetListingDetailQuery q, CancellationToken ct)
{
    var dto = await reads.GetDetailAsync(q.ListingId, ct);
    if (dto is null) return Error.NotFound("Listing.NotFound");
    // FLAG: listings.detail-layout — A/B variant; payload selects layout
    var variant = await variants.GetVariantAsync("listings.detail-layout", ct);
    return variant.Name switch
    {
        "compact" => dto with { Layout = "compact" },
        "rich"    => dto with { Layout = "rich" },
        _         => dto,
    };
}
```

## 8. Sunset discipline (critical)

> **Rule:** Every flag MUST carry a `metadata.sunset` date in its `appsettings.json` entry. Flags older than 90 days past sunset are tech debt: the flagged code path either becomes the default or gets deleted. The flag-management process (out of skill scope) reviews sunset flags monthly.

Failure mode: dead flags accumulate, dead code paths multiply, tests bifurcate forever. Annotate retiring branches with `// SUNSET: YYYY-MM-DD` so cleanup sweeps can grep for ripe flags.

```csharp
// FLAG: listings.new-flow
// SUNSET: 2026-09-15 — remove the legacy branch when this date passes if the flag has been 100% rolled
if (await flags.IsEnabledAsync("listings.new-flow")) { /* new path */ }
else { /* legacy path */ }
```

## 9. Anti-patterns

- Injecting `IFeatureManager` into handlers (use the snapshot for request consistency).
- Generic flag names — `feature-1`, `temp-flag`, `experiment-on`. Name the FEATURE semantically.
- A code path that depends on a flag with no sunset date.
- Gating cross-cutting concerns with flags (auth, persistence, observability — these are infrastructure, not toggles).
- A filter that performs external I/O — filters run frequently; expensive filters bottleneck every gated request.
- A/B variant data leaking into business logic that doesn't acknowledge the experiment — causes bias and breaks the test.
- Using flags as runtime config substitutes — use `IConfiguration` / `IOptions` for config, flags for gradual rollout.

## 10. Testing

Substitute `IFeatureManagerSnapshot` directly in unit tests; override `appsettings.Testing.json` for integration tests.

```csharp
[Fact]
public async Task Search_uses_v2_when_flag_on()
{
    var flags = Substitute.For<IFeatureManagerSnapshot>();
    flags.IsEnabledAsync("listings.geo-search-v2").Returns(true);
    var legacy = Substitute.For<IListingSearchService>();
    var v2 = Substitute.For<IListingSearchServiceV2>();
    v2.SearchAsync(Arg.Any<SearchListingsQuery>(), Arg.Any<CancellationToken>())
      .Returns(new PagedResult<ListingCardDto>([], 0, 1, 20));

    _ = await new SearchListingsHandler(flags, legacy, v2)
        .Handle(new SearchListingsQuery("UK", 1, 20, null), default);

    await v2.Received(1).SearchAsync(Arg.Any<SearchListingsQuery>(), Arg.Any<CancellationToken>());
    await legacy.DidNotReceiveWithAnyArgs().SearchAsync(default!, default);
}
```

## 11. Comment markers emitted by this skill

- `// FLAG:` — annotates each flag evaluation call site.
- `// SUNSET:` — annotates the sunset date on a flag-gated branch; greppable for cleanup sweeps.

The canonical comment-markers index lives in `backend-architecture §7`.

## 12. References

- `backend-architecture §7` — canonical comment-markers index.
- `backend-feature-patterns §3` — handler-side gating shape.
- `api-endpoint-patterns` — endpoint-side gating with `[FeatureGate]`.
- `authorization-patterns` — `IUserContext` for custom targeting filters.
- `.specify/memory/system-context.md` — project flag inventory + sunset review cadence.
