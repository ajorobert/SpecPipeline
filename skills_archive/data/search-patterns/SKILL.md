---
name: search-patterns
description: |
  Elasticsearch 8.x for .NET 10 search with Elastic.Clients.Elasticsearch. Covers index modeling, mapping, geo search (polygon, radius, bounding-box, sort-by-distance), tenant-isolated queries, event-driven indexing from PostgreSQL/PostGIS source of truth, alias-based zero-downtime reindex, PIT + search_after deep pagination, HybridCache for stable search results. Use whenever a feature reads or writes the search index.
when_to_load:
  - Task mentions: search, elasticsearch, full-text, geo, polygon, radius, bounding-box, near, distance, index, mapping, reindex, alias, search service
  - Files touched: any *SearchService.cs, *IndexConsumer.cs, *Mapping.cs in a search-related folder
co_loads_with:
  - backend-architecture (canonical seams, structure, markers, events model — read first)
  - backend-feature-patterns (query handler injects the search service via the seam)
  - caching-patterns (cache stable search results)
  - orchestration-patterns (reindex job runner)
references:
  - data-access-patterns (PostGIS source of truth read service)
  - infrastructure-wiring (Elastic client, cluster, alias connection setup)
---

# Search Patterns

Read `backend-architecture` first — it owns the seam catalog, the building-blocks/module structure,
the comment-marker index, and the domain/integration event model. Search is an **edge**: Elasticsearch
is named legitimately (it is the search engine, not a hidden library), but feature code still reaches it
only through an Application-declared service interface — never the raw client.

## 1. Mental model

```
Source of truth (write side)        Search side (denormalized)
   PostgreSQL + PostGIS                Elasticsearch index
        │                                    ▲
        │ aggregate state mutation           │ index update
        │ raises domain event                │
        │ → integration event (outbox)       │
        ▼                                    │
   EF-Core outbox  ─── integration event ────┘
        │                  (cross-module, eventual)
        ▼
   integration-event CONSUMER (backend-architecture §6)
       reads source projection, writes the denormalized doc

Query path:
   Endpoint → query handler → search service → Elasticsearch query
                                                       │
                                                       │ filter: tenant_id (enforced in the service)
                                                       │ + business filters
                                                       │ + geo (polygon/radius/bbox)
                                                       ▼
                                                  PagedResult<TDto>  →  Result<…>
```

Elasticsearch is a **projection**, not a source. The truth lives in PostgreSQL — if the index is wrong,
rebuild it from the source. Indexing happens only inside the integration-event consumer; nothing else
writes to ES.

**When NOT to use Elasticsearch:** small datasets (use Dapper + PostGIS), exact-match lookups (use Postgres
+ index), strict ACID joins (not ES's job), audit logs (use partitioned PostgreSQL).

## 2. Index modeling

- One **index alias** per searchable aggregate (e.g. `listings`). Application code always queries the alias.
- Physical index name: `<alias>_<yyyyMMddHHmm>` (e.g. `listings_202605181430`). Reindex creates a new physical
  index and swaps the alias atomically (§9).
- The document is a flattened **denormalized DTO**. Foreign-key relationships are flattened into the document —
  never joined at query time.
- Every document carries `tenant_id` (`keyword`) — non-negotiable (§5 SECURITY INVARIANT).

```csharp
namespace YourContext.Infrastructure.Search.Documents;

public sealed record ListingSearchDocument
{
    public Guid Id { get; init; }                    // keyword (also _id)
    public Guid TenantId { get; init; }              // keyword — tenant filter
    public string Title { get; init; } = "";         // text + keyword sub-field
    public string Description { get; init; } = "";   // text
    public string Status { get; init; } = "";        // keyword
    public string Category { get; init; } = "";      // keyword (facet)
    public decimal Price { get; init; }              // double
    public string Currency { get; init; } = "";      // keyword
    public GeoLocation? Location { get; init; }      // geo_point
    public string Region { get; init; } = "";        // keyword
    public DateTimeOffset CreatedAt { get; init; }   // date
    public DateTimeOffset? ActivatedAt { get; init; }// date
}
```

## 3. Mapping conventions

| Use | Type | Notes |
|---|---|---|
| IDs, tenant_id, status, category | `keyword` | Exact match, facet, filter |
| Full-text searchable | `text` | Pair with `.keyword` sub-field for sort/exact |
| Date | `date` | ISO 8601 with explicit format |
| Single lat/lng | `geo_point` | Radius, distance-sort, bbox |
| Polygons / regions | `geo_shape` | Polygon-intersects queries |
| Numeric facet | `integer`/`long`/`double` | Match source type; no implicit conversion |

Declare mappings explicitly via the typed descriptor — **never rely on dynamic mapping in production**.

```csharp
var resp = await es.Indices.CreateAsync(physicalIndex, c => c
    .Mappings(m => m.Properties<ListingSearchDocument>(p => p
        .Keyword(k => k.Id)
        .Keyword(k => k.TenantId)
        .Text(t => t.Title, tt => tt.Fields(f => f.Keyword("keyword")))
        .Text(t => t.Description)
        .Keyword(k => k.Status).Keyword(k => k.Category).Keyword(k => k.Region).Keyword(k => k.Currency)
        .DoubleNumber(d => d.Price)
        .GeoPoint(g => g.Location)
        .Date(d => d.CreatedAt).Date(d => d.ActivatedAt)))
    .Settings(s => s.NumberOfShards(2).NumberOfReplicas(1)), ct);
if (!resp.IsValidResponse) return Error.Failure("Search.IndexCreateFailed", resp.DebugInformation);
```

## 4. Indexing — integration-event consumer (main write path)

The index is updated by an **integration-event consumer** (`backend-architecture §6`), not from feature
handlers. The write side mutates an aggregate, the aggregate raises a domain event, a `DomainEventHandler`
returns an `IIntegrationEvent`, the pipeline writes it to the outbox in the same transaction, and the relay
delivers it cross-module. The consumer reads the projection from PostgreSQL via the source-of-truth read
service (`data-access-patterns`) — **never** reads from Elasticsearch to update Elasticsearch. The consumer
is idempotent: re-handling the same event re-indexes the same document state.

```csharp
namespace YourContext.Application.Search.Indexing;

public sealed class ListingIndexConsumer(
    ElasticsearchClient es,
    IListingsReadService reads,
    ListingSearchMapper mapper,
    ILogger<ListingIndexConsumer> logger)
{
    public async Task<Result> Handle(ListingActivatedIntegrationEvent evt, CancellationToken ct)
    {
        var projection = await reads.GetSearchProjectionAsync(new ListingId(evt.ListingId), ct);
        if (projection is null)
        {
            // Source row was deleted between event publish and consumer execution — propagate delete.
            // INDEX: delete by document id
            var del = await es.DeleteAsync<ListingSearchDocument>(evt.ListingId, d => d.Index("listings"), ct);
            return del.IsValidResponse || del.Result == Result.NotFound
                ? Result.Success
                : Error.Failure("Search.DeleteFailed", del.DebugInformation);
        }

        var doc = mapper.ToDocument(projection);
        // INDEX: upsert document by aggregate id; idempotent — re-handling re-applies the same state
        var resp = await es.IndexAsync(doc, i => i.Index("listings").Id(doc.Id), ct);
        if (!resp.IsValidResponse)
        {
            logger.LogError("Index write failed for {ListingId}: {Reason}", doc.Id, resp.DebugInformation);
            return Error.Failure("Search.IndexFailed", resp.DebugInformation);
        }
        return Result.Success;
    }
}
```

A `ListingDeletedIntegrationEvent` consumer mirrors the delete branch above with
`es.DeleteAsync<ListingSearchDocument>`. Mapping is Mapperly (`backend-feature-patterns §8`).

## 5. Query handler shape — main read path

The Application layer depends on a search-service interface; the Elasticsearch-backed implementation lives in
Infrastructure. The query handler is a plain handler dispatched via `IAppQueryBus.Execute`
(`backend-feature-patterns §5`) — it injects the service, maps via Mapperly, and returns `Result<TDto>`
through the seam. It never touches the write path.

> **SECURITY INVARIANT — tenant isolation per query (non-negotiable).** Every search query MUST filter on
> `tenant_id`. The filter is **not optional** and is **enforced in the read service implementation**, never
> trusted to the handler — a query that reaches the cluster without a `tenant_id` filter is a tenant-isolation
> breach. The tenant id comes from `IUserContext.TenantId` (identity seam; source per
> `authorization-patterns` / `backend-architecture §5`). For system-initiated indexing/maintenance, the
> principal is supplied via `[RunsAs(...)]` and the tenant scope is explicit. This is the search-edge
> expression of the backend-architecture tenancy invariant (#4 spirit): every operation is scoped to its
> tenancy dimension, mechanically, in the layer that owns the data access.

```csharp
namespace YourContext.Application.Search;

public interface IListingSearchService
{
    Task<Result<PagedResult<ListingCardDto>>> SearchAsync(ListingSearchQuery query, CancellationToken ct);
}

namespace YourContext.Infrastructure.Search;

public sealed class ListingSearchService(ElasticsearchClient es, IUserContext user, ListingSearchMapper mapper)
    : IListingSearchService
{
    public async Task<Result<PagedResult<ListingCardDto>>> SearchAsync(ListingSearchQuery q, CancellationToken ct)
    {
        // Tenant scope is mandatory and enforced HERE — the read service, not the handler.
        if (user.TenantId == Guid.Empty) return Error.Forbidden("Search.NoTenant", "Tenant context required");

        var resp = await es.SearchAsync<ListingSearchDocument>(s => s
            .Index("listings")
            .From((q.Page - 1) * q.PageSize)
            .Size(Math.Min(q.PageSize, 100))
            .Query(qq => qq.Bool(b => b
                .Must(m => string.IsNullOrWhiteSpace(q.Text)
                    ? m.MatchAll()
                    : m.Match(t => t.Field(f => f.Title).Query(q.Text!)))
                .Filter(
                    f => f.Term(t => t.Field(d => d.TenantId).Value(user.TenantId.ToString())),   // tenant_id — non-negotiable
                    f => f.Term(t => t.Field(d => d.Status).Value("active")),
                    f => q.MaxPrice is null ? f.MatchAll() : f.Range(r => r.NumberRange(n => n.Field(d => d.Price).Lte((double)q.MaxPrice)))
                )))
            .Sort(so => so.Field(f => f.CreatedAt, sf => sf.Order(SortOrder.Desc))), ct);

        if (!resp.IsValidResponse)
            return Error.Failure("Search.QueryFailed", resp.DebugInformation);

        var items = resp.Documents.Select(mapper.ToCard).ToList();
        return new PagedResult<ListingCardDto>(items, (int)resp.Total, q.Page, q.PageSize);
    }
}
```

## 6. Geo search patterns

- **Radius** — `geo_distance` on a `geo_point` field with `distance: "5km"` and origin.
- **Polygon** — `geo_shape` filter with `relation: intersects` and a polygon geometry.
- **Bounding box** — `geo_bounding_box` with top-left + bottom-right corners.
- **Sort by distance** — `_geo_distance` sort with origin + unit.
- Always combine geo with the tenant filter and at least one keyword filter to leverage the filter cache.

```csharp
var resp = await es.SearchAsync<ListingSearchDocument>(s => s
    .Index("listings")
    .Size(20)
    .Query(q => q.Bool(b => b
        .Must(m => string.IsNullOrWhiteSpace(text) ? m.MatchAll() : m.Match(t => t.Field(f => f.Title).Query(text!)))
        .Filter(
            f => f.Term(t => t.Field(d => d.TenantId).Value(user.TenantId.ToString())),  // tenant_id
            f => f.Term(t => t.Field(d => d.Status).Value("active")),
            // GEO: 5km radius around (lat, lng) on the geo_point field
            f => f.GeoDistance(g => g.Field(d => d.Location).Distance("5km").Location(GeoLocation.LatitudeLongitude(new(lat, lng)))),
            f => f.Range(r => r.NumberRange(n => n.Field(d => d.Price).Gte(minPrice).Lte(maxPrice)))
        )))
    // GEO: sort by ascending distance from the same origin
    .Sort(so => so.GeoDistance(g => g.Field(d => d.Location).Location(GeoLocation.LatitudeLongitude(new(lat, lng))).Order(SortOrder.Asc).Unit(DistanceUnit.Kilometers))), ct);
```

For polygon / bounding-box variants, swap the `GeoDistance` filter for a `geo_shape` intersects filter or a
`geo_bounding_box` filter respectively; the tenant + keyword filters stay identical.

## 7. Pagination + sort

| Depth | Mechanism | Notes |
|---|---|---|
| Shallow (≤ ~10,000 docs) | `from` + `size` | Default for user-facing pagination with random page jumps |
| Deep user-facing | **PIT + `search_after`** | Point-in-time keeps a consistent snapshot; `search_after` cursors past `from`/`size` limits without deep-paging cost |
| Batch / reindex / export | `scroll` API | **NEVER** for user-facing UI |

Page size: 20–50 default; hard cap at 100. Always specify a `Size(...)` — never return unbounded result sets.

**Deep user-facing pagination — PIT + `search_after`.** `from`/`size` degrades sharply past ~10k docs (every
shard sorts `from + size` hits). For deep, consistent, user-facing paging, open a **point-in-time** (PIT) to
pin a snapshot, then page forward with `search_after` using a stable tiebreaker sort (`_id` last). Carry the
PIT id + last `sort` values in the cursor token the client sends back. `scroll` stays reserved for batch and
reindex (§9–§10) — it holds heavier server-side state and is not for interactive UI.

```csharp
// Open a PIT (keep-alive sized to the paging session), then page with search_after.
var pit = await es.OpenPointInTimeAsync("listings", p => p.KeepAlive("2m"), ct);

var resp = await es.SearchAsync<ListingSearchDocument>(s => s
    .Pit(new PointInTimeReference(pit.Id) { KeepAlive = "2m" })   // PIT replaces .Index(...)
    .Size(50)
    .Query(q => q.Bool(b => b.Filter(
        f => f.Term(t => t.Field(d => d.TenantId).Value(user.TenantId.ToString())))))   // tenant_id — still mandatory
    .Sort(so => so
        .Field(f => f.CreatedAt, sf => sf.Order(SortOrder.Desc))
        .Field(f => f.Id, sf => sf.Order(SortOrder.Asc)))   // stable tiebreaker
    .SearchAfter(lastSort), ct);   // lastSort = the previous page's final hit sort values; omit on first page
// Close the PIT when the paging session ends: es.ClosePointInTimeAsync(...).
```

## 8. Caching stable search results

Cache **only stable filter sets** — facet aggregations, "popular near you" with coarse-grained geo,
configured-filter pages. Do NOT cache arbitrary full-text queries: the key space is huge and the cache hit
rate is near zero.

When caching, wrap the search-service call in `HybridCache.GetOrCreateAsync` at the **query handler** level —
see `caching-patterns`. Do not embed cache logic inside the search-service implementation; the service owns
the query (and the tenant filter), the handler owns the cache decision. The cache key MUST include the tenant
dimension so cached pages never leak across tenants.

```csharp
public async Task<Result<PagedResult<ListingCardDto>>> Handle(SearchPopularNearMeQuery q, CancellationToken ct)
{
    // CACHE-TAG: <prefix>:listing — see caching-patterns; prefix + tenant scoping are project vocabulary
    var key = $"{CacheKeys.SearchPopular(user.TenantId, q.Region, q.Page)}";
    return await cache.GetOrCreateAsync(
        key,
        async token => await service.SearchAsync(q.AsServiceQuery(), token),
        new() { Expiration = TimeSpan.FromSeconds(60), LocalCacheExpiration = TimeSpan.FromSeconds(30) },
        tags: [CacheKeys.ListingTag],   // write-side write invalidates cached search pages
        cancellationToken: ct);
}
```

TTL ≤ 60s for search results (see `caching-patterns`).

## 9. Reindex — alias-based zero downtime

Process:

1. Create a new physical index `<alias>_<timestamp>` with the latest mapping.
2. Bulk-index from PostgreSQL — paged read using a stable order (§10).
3. Swap the alias atomically: one `UpdateAliases` action removing the old physical index and adding the new one.
4. Delete the old physical index after a retention window (e.g. 7 days for emergency rollback).

```csharp
public async Task<Result> SwapAliasAsync(string alias, string oldIndex, string newIndex, CancellationToken ct)
{
    var resp = await es.Indices.UpdateAliasesAsync(a => a
        .Actions(ac => ac
            .Remove(r => r.Alias(alias).Index(oldIndex))
            .Add(ad => ad.Alias(alias).Index(newIndex))), ct);
    return resp.IsValidResponse ? Result.Success : Error.Failure("Search.AliasSwapFailed", resp.DebugInformation);
}
```

The reindex **job runner** (recurring/one-shot scheduling, OTel propagation, idempotent execution) lives in
`orchestration-patterns` — this skill owns the index/alias mechanics, that skill owns the job that drives them.
Reindex on mapping changes or schema drift — never on every deployment. Cluster, alias, and connection setup
(client registration, endpoints, credentials) live in `infrastructure-wiring`.

## 10. Bulk indexing — initial seed + reindex

```csharp
foreach (var batch in docs.Chunk(1_000))
{
    // INDEX: bulk write — resilience pipeline handles transient retries on the HTTP client
    var resp = await es.BulkAsync(b => b.Index(physicalIndex)
        .IndexMany(batch, (op, doc) => op.Id(doc.Id)), ct);
    if (!resp.IsValidResponse || resp.Errors) return Error.Failure("Search.BulkFailed", resp.DebugInformation);
}
```

Bulk index calls are idempotent on document `_id`; transient partial failures are retried by the HTTP-client
resilience stack configured in `infrastructure-wiring` (idempotency-aware retry rules in
`integration-adapter-patterns`).

## 11. Error handling

4xx (mapping conflict, validation) → `Error.Validation`, do NOT retry. 429/503 (backpressure) → retry with
backoff. Connection failure → retry with backoff, circuit-break after threshold. Always check
`response.IsValidResponse` before reading `response.Documents`; on failure surface `Error.Failure` with
`DebugInformation`. The ES HTTP client shares the resilience stack defined in `infrastructure-wiring`
(rules per `integration-adapter-patterns`). All boundary methods return `Result` — never throw for expected
failures (`backend-architecture §2`).

## 12. Testing

Integration tests use Testcontainers (`Testcontainers.Elasticsearch`) — one container per test class or shared
fixture. Mapping creation runs at fixture startup. Use `Refresh.WaitFor` on writes that need immediate
searchability — never `Thread.Sleep`. The tenant-isolation test below is a required test for every searchable
aggregate (§5 invariant).

```csharp
[Fact]
public async Task Search_filters_by_tenant()
{
    var (tenantA, tenantB) = (Guid.NewGuid(), Guid.NewGuid());
    await es.IndexAsync(new ListingSearchDocument { Id = Guid.NewGuid(), TenantId = tenantA, Title = "A", Status = "active" },
        i => i.Index("listings").Refresh(Refresh.WaitFor));
    await es.IndexAsync(new ListingSearchDocument { Id = Guid.NewGuid(), TenantId = tenantB, Title = "B", Status = "active" },
        i => i.Index("listings").Refresh(Refresh.WaitFor));

    var svc = new ListingSearchService(es, new FakeUserContext { TenantId = tenantA }, mapper);
    var result = await svc.SearchAsync(new("", 1, 20, null), default);

    result.IsError.ShouldBeFalse();
    result.Value.Items.ShouldHaveSingleItem();   // tenantB doc never leaks
}
```

`FakeUserContext` comes from `authorization-patterns` / `BuildingBlocks.Testing`.

## 13. Anti-patterns

- Reading from Elasticsearch to update Elasticsearch — always read source of truth.
- Joining indices at query time — denormalize on the write side.
- Dynamic mapping in production — declare types explicitly.
- Missing `tenant_id` filter on a query, or adding it in the handler instead of the read service — tenant-isolation breach (§5).
- `scroll` API for user-facing pagination — use PIT + `search_after` (§7); scroll is batch/reindex only.
- Caching full-text searches indiscriminately, or omitting the tenant dimension from the cache key — low hit rate / cross-tenant leak.
- Storing PII or secrets in indexed documents — redact at denormalization time (`[Sensitive]` deny-list, `observability-backend`).
- Treating Elasticsearch as a primary store — loss-of-data risk.
- Using deprecated clients (`NEST`, `Elasticsearch.Net`) — `Elastic.Clients.Elasticsearch` only.
- Falling back to PostgreSQL `LIKE` / PostGIS scan when ES is down — return `Error.Failure`, do not silently degrade.

## 14. Comment markers emitted by this skill

- `// INDEX:` — annotates an index/delete/bulk call to Elasticsearch.
- `// GEO:` — annotates a geo query parameter (point, polygon, radius, bounding box).

The canonical cross-skill marker index — and the `// CONFIGUREAWAIT:` rule — live in `backend-architecture §7`.
This skill does not restate them.

## 15. References

- `backend-architecture` — seams, structure, marker index, domain/integration event model (§6), invariants (read first).
- `backend-feature-patterns §4, §5, §8` — domain→integration event flow, query handler shape, Mapperly mapping.
- `data-access-patterns` — read service for source-of-truth + PostGIS geo write side.
- `caching-patterns` — cache stable search results, never full-text; tag invalidation.
- `orchestration-patterns` — reindex job runner (recurring/one-shot, OTel propagation, idempotent execution).
- `authorization-patterns` / `backend-architecture §5` — `IUserContext.TenantId` source enforced on every query.
- `infrastructure-wiring` — Elastic client registration, cluster/alias connection setup, HTTP resilience stack.
- `.specify/memory/system-context.md` — project conventions for aliases, retention windows, cache-key prefixes.
