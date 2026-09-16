---
name: data-access-patterns
description: |
  PostgreSQL persistence for .NET 10 with EF Core (write path) and Dapper (read path). Covers DbContext conventions, per-aggregate write repositories, Dapper read services, migrations, JSONB mapping, PostGIS geo, schema-per-context, optimistic concurrency, indexing, Row-Level Security with TenantInterceptor, and read/write separation per CQRS.
when_to_load:
  - Task mentions: persist, persistence, database, postgres, postgresql, ef core, dapper, migration, jsonb, postgis, geo, repository, read model, projection, rls, tenant isolation
  - Files touched: any *DbContext.cs, *Repository.cs, *ReadService.cs, Migrations/*, *.sql, *EntityConfiguration.cs
co_loads_with:
  - backend-architecture (canonical seams, structure, markers, events model, outbox rule — read first)
  - backend-feature-patterns (write-repo + read-service boundary from §10)
  - caching-patterns (cache-aside wraps Dapper reads)
references:
  - authorization-patterns (IUserContext provides TenantId for the interceptor)
  - search-patterns (geo-search denormalizes from PostGIS write side)
---

# Data Access Patterns

Read `backend-architecture` first — it owns the seam catalog, the building-blocks/module structure,
the comment-marker index, the domain/integration event model, and the outbox invariant. This skill
applies them to the persistence edge: EF Core on the write path, Dapper on the read path.

## 1. Mental model

```
Write path:                                Read path:
   Handler                                    Handler
     │ injects per-aggregate write repo         │ injects per-family read service
     ▼                                          ▼
   IListingsRepository                       IListingsReadService
     │ wraps DbContext                          │ wraps Dapper IDbConnection
     │ change-tracked aggregate ops             │ projections, paged queries
     ▼                                          ▼
   DbContext (EF Core)                       Dapper SQL
     │ SaveChangesAsync                         │ SELECT ... mapped to DTO
     │   participates in the ambient tx         │
     ▼                                          ▼
       ─────────── PostgreSQL ──────────────────
                       │
                       │ RLS policies enforce tenant isolation
                       │ TenantInterceptor sets app.current_tenant_id per session
                       │ PostGIS for geo on write side; Elasticsearch denormalizes for search
```

EF for write — change-tracked aggregate operations through the DbContext. Dapper for read — projections, paged queries, hot reads. **Never the other way.** Write needs invariants + transaction + outbox; read needs speed + flexibility + cache-friendly DTOs.

## 2. DbContext conventions

One `DbContext` per bounded context — not one per aggregate. Lives in `YourContext.Infrastructure.Persistence`. The Application layer never sees `DbContext` directly; it depends on write-repository interfaces (§3).

Configuration is split into one `IEntityTypeConfiguration<T>` class per aggregate root, in a `Configurations/` folder, discovered by assembly scan.

```csharp
namespace YourContext.Infrastructure.Persistence;

public sealed class YourContextDbContext(DbContextOptions<YourContextDbContext> options) : DbContext(options)
{
    public DbSet<Listing> Listings => Set<Listing>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.HasDefaultSchema(Schema.Name);   // schema-per-context (§3a) — name is project vocabulary
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(YourContextDbContext).Assembly);
    }
}

internal sealed class ListingConfiguration : IEntityTypeConfiguration<Listing>
{
    public void Configure(EntityTypeBuilder<Listing> b)
    {
        b.ToTable("listings");
        b.HasKey(x => x.Id);
        b.Property(x => x.Id).HasColumnName("listing_id").HasConversion(id => id.Value, v => new ListingId(v));
        b.Property(x => x.Status).HasConversion<string>().IsRequired();
        b.OwnsOne(x => x.Price, p => { p.Property(m => m.Amount).HasColumnType("numeric(14,4)"); p.Property(m => m.Currency); });
        b.Property(x => x.RowVersion).IsRowVersion();
        b.Property(x => x.TenantId).HasColumnName("tenant_id");   // RLS column name is project vocabulary (.specify/memory/)
        b.HasIndex(x => new { x.TenantId, x.Status }).HasFilter("deleted_at IS NULL");
    }
}
```

### 3a. Schema-per-context

Each module owns exactly one PostgreSQL schema; the `DbContext` sets it as the default schema via
`HasDefaultSchema(...)`. The schema name is project vocabulary (`.specify/memory/system-context.md`),
never hardcoded in this skill. **Cross-schema foreign keys are forbidden** — a module's tables never
FK to another module's schema. Cross-module relationships are carried by `Contracts` (IDs) and
integration events (`backend-architecture §6`), not by database joins.

## 3. Write repository shape

This skill owns the contract that `backend-feature-patterns §10` references.

- Interface in `YourContext.Application`; implementation in `YourContext.Infrastructure.Persistence`.
- Naming: `I<Aggregate>sRepository` (plural). One typed repository per aggregate root.
- Methods: `GetByIdAsync(id, ct)`, `AddAsync(aggregate, ct)`, `Remove(aggregate)`, `SaveChangesAsync(ct)`.
- `GetByIdAsync` returns `Result<TAggregate>` with `Error.NotFound` when missing.
- `SaveChangesAsync` does **not** open or commit a transaction — it just flushes change-tracked work into the **ambient unit of work** owned by the command pipeline (§5).
- Aggregates use private setters + factory methods (`backend-feature-patterns §2`).

```csharp
namespace YourContext.Application.Handlers.Listings;

public interface IListingsRepository
{
    Task<Result<Listing>> GetByIdAsync(ListingId id, CancellationToken ct);
    Task AddAsync(Listing listing, CancellationToken ct);
    void Remove(Listing listing);
    Task SaveChangesAsync(CancellationToken ct);
}

namespace YourContext.Infrastructure.Persistence.Repositories;

public sealed class ListingsRepository(YourContextDbContext db) : IListingsRepository
{
    public async Task<Result<Listing>> GetByIdAsync(ListingId id, CancellationToken ct)
    {
        var listing = await db.Listings.FindAsync([id], ct);
        return listing is null ? Error.NotFound("Listing.NotFound", "Listing not found") : listing;
    }

    public Task AddAsync(Listing listing, CancellationToken ct) =>
        db.Listings.AddAsync(listing, ct).AsTask();

    public void Remove(Listing listing) => db.Listings.Remove(listing);

    public Task SaveChangesAsync(CancellationToken ct) => db.SaveChangesAsync(ct);
}
```

## 4. Read service shape

- Interface in `YourContext.Application`; Dapper implementation in `YourContext.Infrastructure.Persistence.Reads`.
- Naming: `I<Aggregate>ReadService` for aggregate-keyed reads; `I<QueryFamily>ReadService` for a coherent query family.
- Methods return DTOs/records — **never** entities (those live in the write path only).
- Pagination uses a `PagedResult<T>` record carrying `Items` + `TotalCount` + `Page` + `PageSize`.

```csharp
namespace YourContext.Application.Handlers.Listings;

public sealed record ListingSummaryDto(Guid Id, string Title, decimal Price, string Currency, string Status);
public sealed record PagedResult<T>(IReadOnlyList<T> Items, int TotalCount, int Page, int PageSize);

public interface IListingsReadService
{
    Task<ListingDetailDto?> GetDetailAsync(Guid id, CancellationToken ct);
    Task<PagedResult<ListingSummaryDto>> SearchAsync(Guid tenantId, string? status, int page, int pageSize, CancellationToken ct);
}

namespace YourContext.Infrastructure.Persistence.Reads;

public sealed class ListingsReadService(IDbConnectionFactory factory) : IListingsReadService
{
    // CONFIGUREAWAIT: adapter library code — see backend-architecture §7.
    public async Task<ListingDetailDto?> GetDetailAsync(Guid id, CancellationToken ct)
    {
        await using var conn = await factory.OpenAsync(ct).ConfigureAwait(false);
        return await conn.QuerySingleOrDefaultAsync<ListingDetailDto>(new CommandDefinition(
            "SELECT public_id AS Id, title AS Title, price_amount AS Price, price_currency AS Currency, status AS Status " +
            "FROM listings WHERE public_id = @id AND deleted_at IS NULL",
            new { id }, cancellationToken: ct)).ConfigureAwait(false);
    }

    public async Task<PagedResult<ListingSummaryDto>> SearchAsync(Guid tenantId, string? status, int page, int pageSize, CancellationToken ct)
    {
        await using var conn = await factory.OpenAsync(ct).ConfigureAwait(false);
        var sql = "SELECT public_id AS Id, title AS Title, price_amount AS Price, price_currency AS Currency, status AS Status " +
                  "FROM listings WHERE tenant_id = @tenantId AND deleted_at IS NULL " +
                  "AND (@status IS NULL OR status = @status) " +
                  "ORDER BY created_at DESC LIMIT @take OFFSET @skip";
        var items = (await conn.QueryAsync<ListingSummaryDto>(new CommandDefinition(
            sql, new { tenantId, status, take = pageSize, skip = (page - 1) * pageSize }, cancellationToken: ct)).ConfigureAwait(false)).AsList();
        var total = await conn.ExecuteScalarAsync<int>(new CommandDefinition(
            "SELECT COUNT(*) FROM listings WHERE tenant_id = @tenantId AND deleted_at IS NULL AND (@status IS NULL OR status = @status)",
            new { tenantId, status }, cancellationToken: ct)).ConfigureAwait(false);
        return new(items, total, page, pageSize);
    }
}
```

Wrap the read-service call in `HybridCache.GetOrCreateAsync` at the query-handler call site — see `caching-patterns` for the cache-aside pattern and `backend-feature-patterns §5` for handler shape.

## 5. Transaction + outbox — owned elsewhere

The **command pipeline owns the transaction and the outbox** (`backend-architecture §6`): the pipeline
behavior wraps the handler in a transaction, flushes raised domain events, and writes integration
events to the EF outbox in that same transaction. Repositories **never** open, commit, or roll back a
transaction; `SaveChangesAsync` only flushes change-tracked work into that ambient unit of work. There
is no `// TX:` marker — the transaction boundary is the pipeline's, not the persistence layer's.

## 6. Migrations

EF Core migrations, code-first. One migration per merged PR that touches schema.

- Naming: `YYYYMMDD_<aggregate>_<change>` (e.g. `20260518_Listings_AddGeoPoint`).
- Generation: `dotnet ef migrations add 20260518_Listings_AddGeoPoint --project YourContext.Infrastructure --startup-project YourContext.Api`.
- **Forward-only** — never edit a migration after it has been applied to staging or higher.
- `Down` methods MUST be implemented for rollback safety, even if rarely run in prod.
- Seed data does NOT live in migrations — a separate seeder runs at deploy time.
- `CREATE INDEX CONCURRENTLY` and other non-transactional DDL: emit via `migrationBuilder.Sql(..., suppressTransaction: true)`.
- Never add a `NOT NULL` column without a `DEFAULT` to a populated table — that triggers a full table rewrite. Backfill in steps: add nullable → backfill → add `NOT NULL`.

## 7. JSONB mapping

Use JSONB for schemaless metadata, settings blobs, variable-shape audit payloads. **Do NOT** use JSONB for foreign-key relationships (use real columns) or for queryable filter fields (promote to a column).

```csharp
public sealed class Listing
{
    public ListingMetadata Metadata { get; private set; } = new();   // JSONB: schemaless metadata
}

internal sealed class ListingConfiguration : IEntityTypeConfiguration<Listing>
{
    public void Configure(EntityTypeBuilder<Listing> b)
    {
        // JSONB: stored as PostgreSQL jsonb; converted via System.Text.Json
        b.Property(x => x.Metadata)
         .HasColumnType("jsonb")
         .HasConversion(
             v => JsonSerializer.Serialize(v, JsonOptions.Default),
             v => JsonSerializer.Deserialize<ListingMetadata>(v, JsonOptions.Default)!);
        b.HasIndex(x => x.Metadata).HasMethod("gin");
    }
}

// Query — JsonContains pushes down to PostgreSQL @> operator
var hot = await db.Listings
    .Where(l => EF.Functions.JsonContains(l.Metadata, """{"tags":["featured"]}"""))
    .ToListAsync(ct);
```

For nested value-object shapes whose fields are queried independently, prefer `OwnsOne` with separate columns over JSONB.

## 8. PostGIS — geo on the write side

```csharp
public sealed class Listing
{
    public Point? Location { get; private set; }    // NetTopologySuite Point, SRID 4326
}

internal sealed class ListingConfiguration : IEntityTypeConfiguration<Listing>
{
    public void Configure(EntityTypeBuilder<Listing> b)
    {
        b.Property(x => x.Location).HasColumnType("geometry(Point, 4326)");
        b.HasIndex(x => x.Location).HasMethod("gist");
    }
}

// Within-5km query via EF (Npgsql translates ST_DWithin)
var nearby = await db.Listings
    .Where(l => l.Location != null
                && l.Location.IsWithinDistance(new Point(lng, lat) { SRID = 4326 }, 5_000))
    .ToListAsync(ct);
```

**SRID rule:** 4326 (WGS84) for lat/lng; switch to 3857 only when computing distances on a flat projection.

**PostGIS for transactional geo (single-row read/write); Elasticsearch for search-side queries** (polygon, radius, sort-by-distance, faceted geo) — see `search-patterns`. The write side owns the source of truth; ES denormalizes for search.

## 9. Concurrency control

Optimistic concurrency via a `RowVersion` `byte[]` property mapped with `IsRowVersion()` — EF Core maps that onto PostgreSQL's `xmin` system column. On conflict, `DbUpdateConcurrencyException` propagates to the handler.

```csharp
public sealed class Listing { public byte[] RowVersion { get; private set; } = []; }

// Handler
try { await repo.SaveChangesAsync(ct); }
catch (DbUpdateConcurrencyException) { return Error.Conflict("Listing.ConcurrentUpdate", "Listing was modified by another request"); }
```

## 10. Row-Level Security + TenantInterceptor

RLS policies enforce tenant isolation at the database level — defence-in-depth devs author per table.
The application sets a session variable (`app.current_tenant_id`) per connection via a
`DbConnectionInterceptor` that pulls `TenantId` from `IUserContext` (see `authorization-patterns` for
the contract and `backend-architecture §5` for how identity reaches the handler). The RLS column name
and tenant session-variable name are project vocabulary (`.specify/memory/`).

**Policy (migration template):**

```sql
-- RLS: enable + define policy on every tenant-scoped table
ALTER TABLE listings ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON listings
    USING (tenant_id = current_setting('app.current_tenant_id')::uuid);
```

**Interceptor (authored here; registered in infrastructure-wiring):**

```csharp
public sealed class TenantInterceptor(IUserContext user) : DbConnectionInterceptor
{
    // CONFIGUREAWAIT: interceptor adapter code — see backend-architecture §7.
    public override async Task ConnectionOpenedAsync(
        DbConnection connection, ConnectionEndEventData eventData, CancellationToken ct = default)
    {
        if (user.TenantId == Guid.Empty) return;        // unauthenticated → RLS denies all rows
        await using var cmd = connection.CreateCommand();
        cmd.CommandText = "SELECT set_config('app.current_tenant_id', @tid, false)";
        var p = cmd.CreateParameter(); p.ParameterName = "tid"; p.Value = user.TenantId.ToString();
        cmd.Parameters.Add(p);
        await cmd.ExecuteNonQueryAsync(ct).ConfigureAwait(false);
    }
}
```

The **same interceptor must be registered for both EF Core and the Dapper connection factory** (and for
replica connections, which enforce RLS independently). That DI registration lives in
`infrastructure-wiring` — reference it; do not wire it here. M2M tokens (`IsViaM2M == true`): the
interceptor either sets the M2M's authorized tenant or a project-specific service sentinel that RLS
policies recognise — pick one per project and document.

## 11. Indexing rules of thumb

- Always index: primary keys, **foreign keys** (PostgreSQL does NOT auto-index them), columns used in WHERE on hot reads.
- JSONB columns queried by predicate: **GIN** (`jsonb_path_ops` variant for containment-only — smaller).
- Geometry columns: **GIST**.
- Composite `(tenant_id, <hot_filter>)` on tenant-scoped tables — usually with `WHERE deleted_at IS NULL` partial filter.
- Time-series append-only tables where disk order tracks the query column: **BRIN** (tiny, low selectivity).
- Expression indexes (`LOWER(email)`) must match the WHERE clause expression exactly to be used.
- Indexes are written in **migrations** — never via raw SQL on prod.
- Anti-pattern: indexing every column "just in case" — index maintenance is paid on every write.

## 12. Anti-patterns

- Generic `IRepository<T>` — loses Include, change-tracking, query composition. Use per-aggregate typed write repositories.
- Dapper on the write path — no change-tracking, no outbox integration.
- EF on the read path for hot queries — LINQ-to-SQL overhead, N+1 risk. Use Dapper.
- `DbContext` injected into the Domain layer — Domain doesn't know about persistence.
- Raw `connection.ExecuteAsync` for state mutation in app code — EF only on the write path.
- A repository opening or committing a transaction — the command pipeline owns the unit of work (`backend-architecture §6`).
- Cross-schema foreign keys — modules relate via Contracts/events, not joins (§3a).
- Tenant-scoped table without an RLS policy — interceptor + audit alone is not enough; RLS is defence-in-depth.
- Bypassing the interceptor via `IDbContextFactory<T>` without setting the tenant context manually.
- Editing migrations after staging-apply — forward-only.

## 13. Testing

Integration tests use Testcontainers (`Testcontainers.PostgreSql`) — one container per test class or shared fixture. Migrations run against the container at fixture startup. Do NOT substitute in-memory SQLite for tests that exercise PostgreSQL-specific features (JSONB, PostGIS, RLS) — coverage there must hit a real PG instance. SQLite is acceptable only for read-service interface tests that touch nothing PG-specific.

Dispatch through the command seam (`IAppCommandBus.Send`) so the pipeline's transaction + outbox run,
then assert the outbox through the seam — never inject Wolverine types into the test.

```csharp
public sealed class ListingsRepositoryTests : IClassFixture<PostgresFixture>
{
    private readonly PostgresFixture _pg;
    public ListingsRepositoryTests(PostgresFixture pg) => _pg = pg;

    [Fact]
    public async Task Creating_listing_persists_aggregate_and_enqueues_integration_event()
    {
        await using var host = await TestHost.CreateAsync(_pg.ConnectionString);
        var commands = host.Services.GetRequiredService<IAppCommandBus>();

        var result = await commands.Send(new CreateListingCommand(Guid.NewGuid(), "T", 100m, "USD"));
        result.IsError.ShouldBeFalse();

        // assert the persisted aggregate via the read service (repo-level assertion)
        var reads = host.Services.GetRequiredService<IListingsReadService>();
        var saved = await reads.GetDetailAsync(result.Value, default);
        saved.ShouldNotBeNull();

        // outbox is asserted through the test seam, not a Wolverine type
        host.Outbox.ShouldContainIntegrationEvent("ListingCreated");
    }
}
```

Full pipeline/outbox harness shape is integration-tested per `infrastructure-wiring`.

## 14. Comment markers emitted by this skill

- `// JSONB:` — annotates an entity property persisted as JSONB.
- `// RLS:` — annotates a migration line that enables RLS or defines a policy.

The cross-skill marker registry and the `// CONFIGUREAWAIT:` rule live in `backend-architecture §7`.

## 15. References

- `backend-architecture` — seams, structure, marker index, the domain/integration event model, the outbox invariant (§6), identity (§5) (read first).
- `backend-feature-patterns §10` — write-repo and read-service boundary; this skill owns the contracts.
- `caching-patterns` — cache-aside wraps the Dapper read service.
- `authorization-patterns` — `IUserContext` provides `TenantId` for the TenantInterceptor.
- `infrastructure-wiring` — DI registration of the DbContext, the TenantInterceptor (EF + Dapper factory), and the pipeline transaction/outbox machinery.
- `search-patterns` — geo-search denormalizes from the PostGIS write side.
- `.specify/memory/system-context.md` — project-specific schema, connection, RLS-column, and tenant-marker conventions.
