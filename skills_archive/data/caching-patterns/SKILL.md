---
name: caching-patterns
description: |
  HybridCache as the cache seam's public surface for .NET 10 with L1 in-process + L2 Redis. Covers GetOrCreateAsync, tag-based invalidation, cross-instance invalidation via integration events, TTL conventions, key naming, and escape hatches for distributed locks (RedLock.net), rate limiting, and Redis Streams. Use whenever a feature reads or invalidates cached data.
when_to_load:
  - Task mentions: cache, caching, invalidate, ttl, hybrid cache, distributed lock, rate limit, redis
  - Files touched: any *ReadService.cs / *QueryHandler.cs with read paths, any handler that mutates state and should invalidate
co_loads_with:
  - backend-architecture (canonical seams, structure, markers, events model — read first)
  - backend-feature-patterns (cache-aside in query handlers, CacheKeys helper)
  - data-access-patterns (Dapper read sits inside the GetOrCreateAsync factory)
---

# Caching Patterns

Read `backend-architecture` first — it owns the seam catalog (`HybridCache` is the cache seam, §2),
the comment-marker index, and the domain/integration event model. This skill applies caching to a
feature. `HybridCache` is the .NET cache API that *is* the seam's public surface — handlers depend on
it directly. The L2 backing (Redis) and `AddHybridCache` wiring are implementation details confined to
`infrastructure-wiring`.

## 1. Mental model

```
Application code → HybridCache.GetOrCreateAsync (primary path)
                  │
                  ├── L1 in-process (microseconds, per-instance)
                  └── L2 Redis (millis, shared across instances)

Tag-based invalidation: HybridCache.RemoveByTagAsync(tag)
Cache-coherent invalidation across instances: integration event (outbox)
  → handler on each instance calls HybridCache.RemoveAsync / RemoveByTagAsync

Escape hatches (NOT via HybridCache):
  - Distributed locks → RedLock.net
  - Rate limiting → Redis sorted-set sliding window (or AspNetCore.RateLimiting)
  - Redis Streams → only when ordered partitioned consumption is required
```

**Why HybridCache, not raw `StackExchange.Redis`:** stampede protection (a single concurrent factory call per key), source-generated serializers, two-tier L1+L2 semantics, and tag-based bulk invalidation — all built in. Raw `IDatabase` access is reserved for the three escape hatches; everything else routes through `HybridCache`.

## 2. Key naming convention

Format: `<prefix>:<aggregate>:<id>[:<projection>]` — lowercase, colon-separated, no spaces.

| Pattern | Example |
|---|---|
| Entity by id | `<prefix>:listing:123` |
| Projection | `<prefix>:listing:123:summary` |
| Paged query | `<prefix>:search:active:page:1` |
| User session | `<prefix>:session:<sessionId>` |

**Tag naming**: `<prefix>:<aggregate>` (e.g. `<prefix>:listing`) — tags are the bulk-invalidation handle. Every cache entry that backs a queryable aggregate must carry the aggregate tag.

The `<prefix>` is **project vocabulary** — the concrete cache-key prefix is declared in `.specify/memory/` (per `backend-architecture §1/§10`), never hardcoded in a skill. Build keys through a `CacheKeys` helper (`backend-feature-patterns §5`) so the prefix lives in one place: `CacheKeys.Listing(id)`, `CacheKeys.ListingTag`.

## 3. TTL conventions

| Data shape | TTL (L2 / `Expiration`) | L1 (`LocalCacheExpiration`) |
|---|---|---|
| Hot read (per-request reuse) | 30s | 30s |
| Reference data (rarely changes) | 1h | 5m |
| User session data | 15m | 1m |
| Search results page | 60s | 30s |
| Single aggregate by ID | 5m | 1m |

**Rule:** `LocalCacheExpiration` ≤ `Expiration`. Never invert — L1 outliving L2 produces phantom hits after L2 eviction. TTL > 1 hour requires a documented bulk-invalidation strategy (anti-pattern §8).

## 4. GetOrCreateAsync — the canonical read pattern

```csharp
namespace YourContext.Application.Handlers.Listings.GetDetail;

public sealed class GetListingDetailQueryHandler(HybridCache cache, IListingsReadService reads)
{
    private static readonly HybridCacheEntryOptions Options = new()
    {
        Expiration            = TimeSpan.FromMinutes(5),
        LocalCacheExpiration  = TimeSpan.FromMinutes(1),
    };

    public async Task<Result<ListingDetailDto>> Handle(GetListingDetailQuery q, CancellationToken ct)
    {
        // CACHE-TAG: <prefix>:listing — bulk-invalidated on any listing write
        var dto = await cache.GetOrCreateAsync(
            $"{CacheKeys.Listing(q.ListingId)}:detail",
            async token => await reads.GetDetailAsync(q.ListingId, token),
            Options,
            tags: [CacheKeys.ListingTag],
            cancellationToken: ct);

        return dto is null ? Error.NotFound("Listing.NotFound") : dto;
    }
}
```

The factory delegate carries the cancellation token. If the factory throws, the exception propagates and nothing is cached — that is intentional.

## 5. Invalidation — same-instance

```csharp
// Single key
await cache.RemoveAsync($"{CacheKeys.Listing(id)}:detail", ct);      // CACHE-INVALIDATE

// Bulk by tag (clears every entry carrying the tag on THIS instance only)
await cache.RemoveByTagAsync(CacheKeys.ListingTag, ct);             // CACHE-INVALIDATE
```

Call sites: in a command handler, invalidate **after** `repo.SaveChangesAsync(ct)`. The command pipeline owns the unit of work (`backend-architecture §6`) — invalidation runs after the handler returns successfully, never if the transaction rolls back. Handlers carry no `[Transactional]`. For cross-instance coherence, see §6.

## 6. Invalidation — cross-instance (critical rule)

> **Rule:** `HybridCache` L1 lives per process. Removing a key on instance A does **not** clear instance B's L1 — instance B keeps serving stale until its L1 TTL expires. To invalidate L1 across the fleet, the state mutation emits an integration event and every instance subscribes to it.

The publish uses the **outbox / integration-event flow** (`backend-architecture §6` — the outbox guarantees the event commits atomically with the DB write). The handler **never references a bus**: the aggregate raises a domain event, a `DomainEventHandler` returns the cache-invalidation integration event, and the pipeline writes it to the outbox in the same transaction. The subscriber side belongs to this skill:

```csharp
namespace YourContext.Contracts.Listings.IntegrationEvents;
public sealed record ListingUpdatedIntegrationEvent(Guid ListingId) : IIntegrationEvent;

namespace YourContext.Application.DomainEventHandlers.Listings;
public sealed class OnListingUpdated
{
    // OUTBOX: returned integration event is written to the outbox in the command's transaction
    public IEnumerable<IIntegrationEvent> Handle(ListingUpdatedEvent e)
    {
        yield return new ListingUpdatedIntegrationEvent(e.ListingId.Value);
    }
}

namespace YourContext.Application.Handlers.Listings.CacheInvalidation;
public sealed class OnListingUpdatedInvalidateCache(HybridCache cache)
{
    public Task Handle(ListingUpdatedIntegrationEvent evt, CancellationToken ct)
        // CACHE-INVALIDATE: clears every cached projection of this listing on this instance
        => cache.RemoveByTagAsync(CacheKeys.ListingTag, ct).AsTask();
}
```

Every app instance hosts the invalidation handler. The brokered event fans out to all subscribers; each instance clears its own L1 and the shared L2 entry. TTL is the safety net if a broker outage drops a notification.

## 7. Cache-aside in query handlers

The handler injects `HybridCache` and the read-side abstraction (Dapper-backed, see `data-access-patterns`). The cache layer is explicit — no decorator magic — so the call site reads top-to-bottom and the factory delegate is the single read.

```csharp
public sealed class SearchListingsQueryHandler(HybridCache cache, IListingSearchReadService reader)
{
    public async Task<Result<IReadOnlyList<ListingCardDto>>> Handle(SearchListingsQuery q, CancellationToken ct)
    {
        var key = CacheKeys.SearchPage(q.Region, q.Page);
        // CACHE-TAG: tag enables bulk invalidation when any listing in the region changes
        var page = await cache.GetOrCreateAsync(
            key,
            token => reader.SearchAsync(q.Region, q.Page, token).AsTask(),
            new() { Expiration = TimeSpan.FromSeconds(60), LocalCacheExpiration = TimeSpan.FromSeconds(30) },
            tags: [CacheKeys.ListingTag],
            cancellationToken: ct);

        return page.ToList();
    }
}
```

Search reads from Elasticsearch are not entity-keyed; they get a short TTL and the aggregate tag so any write invalidates them in bulk.

## 8. Anti-patterns

- Caching write-side commands. Cache read-side queries only.
- Storing EF Core aggregate entities in cache. Cache projections / DTOs.
- Tagless entries on data that needs bulk invalidation.
- Calling `IDatabase` or `ConnectionMultiplexer` directly in application code (only inside an escape-hatch adapter — see §10).
- TTL > 1 hour without a documented bulk-invalidation strategy.
- Caching paged search results without a coherent invalidation tag scheme.
- `LocalCacheExpiration > Expiration` (must be ≤).
- Invalidating from inside a transaction or by injecting a bus to publish. Invalidate after commit (§5), or via the outbox-driven integration-event handler in §6.

## 9. Escape hatch: distributed locks (RedLock.net)

For exactly-once cross-instance operations that a saga cannot model (rare). Not for command deduplication (the dispatch seam's inbox handles that) or event debouncing (saga timeout handles that).

```csharp
public sealed class NightlyReportRunner(RedLockFactory redlock, IReportService reports)
{
    public async Task RunAsync(DateOnly day, CancellationToken ct)
    {
        await using var heldLock = await redlock.CreateLockAsync(
            resource: $"{CacheKeys.Lock("nightly-report")}:{day:yyyyMMdd}",
            expiryTime: TimeSpan.FromMinutes(10),
            waitTime:   TimeSpan.FromSeconds(2),
            retryTime:  TimeSpan.FromMilliseconds(200),
            cancellationToken: ct);

        if (!heldLock.IsAcquired) return;          // another instance is running it
        await reports.GenerateAsync(day, ct);
    }
}
```

Lock expiry must exceed expected operation duration. Always pass `expiryTime` — never infinite locks.

## 10. Escape hatch: rate limiting

Two options. Pick (a) when per-instance is acceptable; pick (b) when the limit must be shared across instances.

**(a) `Microsoft.AspNetCore.RateLimiting`** — preferred default, no Redis dependency.

**(b) Redis sorted-set sliding window** — when shared counters are required. The raw `IDatabase` access here is the **only** place in application code that touches it, and only inside an adapter behind `IRateLimiter` (port-and-adapter convention). This adapter line keeps `ConfigureAwait(false)` — the `// CONFIGUREAWAIT:` rule and its single home are in `backend-architecture §7`.

```csharp
public sealed class RedisSlidingWindowRateLimiter(IConnectionMultiplexer redis) : IRateLimiter
{
    private const string Script = """
        redis.call('ZREMRANGEBYSCORE', KEYS[1], 0, ARGV[1] - ARGV[2])
        redis.call('ZADD', KEYS[1], ARGV[1], ARGV[3])
        redis.call('PEXPIRE', KEYS[1], ARGV[2] * 2)
        return redis.call('ZCARD', KEYS[1])
        """;

    public async Task<bool> TryAcquireAsync(string bucket, int limit, TimeSpan window, CancellationToken ct)
    {
        // CONFIGUREAWAIT: adapter (library-style) code — see backend-architecture §7
        var db = redis.GetDatabase();
        var now = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
        var count = (long)await db.ScriptEvaluateAsync(
            Script,
            new RedisKey[] { CacheKeys.Rate(bucket) },
            new RedisValue[] { now, (long)window.TotalMilliseconds, Guid.NewGuid().ToString("N") })
            .ConfigureAwait(false);
        return count <= limit;
    }
}
```

## 11. Escape hatch: Redis Streams

Use only when ordered, partitioned consumption is required and the messaging transport cannot model the partitioning. This is almost never the right answer — validate the design against the integration-event and saga model (`backend-architecture §6`) before reaching for Streams. No code example: if you need one, the design needs review first.

## 12. Testing

`HybridCache` ships with a real in-memory composition suitable for handler tests — prefer it over hand-rolled doubles so stampede protection and tag semantics are covered.

```csharp
[Fact]
public async Task GetDetail_caches_and_invalidates_by_tag()
{
    var services = new ServiceCollection().AddHybridCache().Services.BuildServiceProvider();
    var cache = services.GetRequiredService<HybridCache>();
    var reads = Substitute.For<IListingsReadService>();
    reads.GetDetailAsync(Arg.Any<ListingId>(), Arg.Any<CancellationToken>())
         .Returns(new ListingDetailDto(Guid.NewGuid(), "title"));

    var handler = new GetListingDetailQueryHandler(cache, reads);
    var id = ListingId.New();

    _ = await handler.Handle(new GetListingDetailQuery(id), default);
    _ = await handler.Handle(new GetListingDetailQuery(id), default);
    await reads.Received(1).GetDetailAsync(id, Arg.Any<CancellationToken>());   // hit on second call

    await cache.RemoveByTagAsync(CacheKeys.ListingTag);                         // CACHE-INVALIDATE
    _ = await handler.Handle(new GetListingDetailQuery(id), default);
    await reads.Received(2).GetDetailAsync(id, Arg.Any<CancellationToken>());   // miss after tag clear
}
```

## 13. Comment markers emitted by this skill

- `// CACHE-TAG:` — annotates the tag(s) a cache entry is filed under.
- `// CACHE-INVALIDATE:` — annotates an invalidation call (`RemoveAsync` / `RemoveByTagAsync`).

The cross-skill marker registry and the `// CONFIGUREAWAIT:` rule live in `backend-architecture §7`.

## 14. References

- `backend-architecture` — cache seam (§2), outbox / integration-event model for cross-instance invalidation (§6), marker registry + ConfigureAwait rule (§7). Read first.
- `backend-feature-patterns` — cache-aside in query handlers; the `CacheKeys` helper (§5) that owns the project-vocabulary prefix.
- `data-access-patterns` — the Dapper read sits inside the `GetOrCreateAsync` factory delegate.
- `infrastructure-wiring` — Redis L2 / Sentinel composition, `AddHybridCache` registration, connection multiplexer setup.
