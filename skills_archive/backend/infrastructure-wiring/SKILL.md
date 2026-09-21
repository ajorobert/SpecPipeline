---
name: infrastructure-wiring
description: |
  Rarely loaded. One-time composition-root and Infrastructure plumbing that implements the backend seams: the IAppCommandBus/IAppQueryBus + outbox impl over Wolverine, transports/retry/DLQ, EF Core + Dapper + TenantInterceptor registration, HybridCache + Redis, Keycloak AuthN (JwtBearer + claim mapping + M2M), Hangfire/Elsa hosts + dashboards, and host wire-up order. Load ONLY when authoring or modifying BuildingBlocks.Infrastructure or hosts/ — NOT for feature work.
when_to_load:
  - Task mentions: composition root, Program.cs, host setup, service registration, DI wiring, ApplicationBus, outbox setup, transport, JwtBearer, AddHybridCache, dashboard, ServiceDefaults, Aspire
  - Files touched: BuildingBlocks.Infrastructure/**, hosts/**, Program.cs, *ServiceCollectionExtensions.cs, *Setup.cs, ApplicationBus.cs
co_loads_with:
  - backend-architecture (the seams this skill implements — read first)
---

# Infrastructure Wiring (the plumbing behind the seams)

Read `backend-architecture` first — it owns the seam catalog (§2), the building-blocks chain (§3),
the domain/integration event model (§6), and the tech-per-edge table (§9). **This skill is the *one*
place those seams are bound to libraries.** Wolverine, EF Core, Dapper, Redis, Keycloak, Hangfire,
Elsa — their names appear *here* and nowhere in any module's `Application`/`Api`. Library names are
expected in this file.

## 1. Mental model

Feature code targets seams: `IAppCommandBus`, `IAppQueryBus`, `Result<T>`, repository interfaces,
`HybridCache`, `IUserContext`. None of those name a library. This skill lives in two places only:

```
BuildingBlocks.Infrastructure/   ← seam implementations (ApplicationBus, pipeline, interceptor, providers)
hosts/{Api,Worker}/Program.cs    ← composition roots that register those impls + set pipeline order
```

The contract: **a change in this skill must not change one line of feature code.** Swap RabbitMQ for
another transport, Redis for another L2, Keycloak for another IdP — the seam holds, modules recompile
untouched. If a wiring change forces a module edit, the seam is leaking (§9, anti-patterns). Everything
project-specific here (realm, connection strings, schema names, cache prefix, RLS column) is **config**,
read from `.specify/memory/` and `IConfiguration` — never hardcoded in this skill.

## 2. The dispatch seam impl — `ApplicationBus` over Wolverine

`IAppCommandBus`/`IAppQueryBus` are declared in `BuildingBlocks.Application`; the single implementation
lives in `BuildingBlocks.Infrastructure/Wolverine/ApplicationBus.cs`. Module handlers return `Result<T>`
directly (`backend-feature-patterns §6`); the bus dispatches them through Wolverine and turns any
**infrastructure** fault into a `Result.Failure`, so a boundary never throws (`backend-architecture §2`).
Modules never see Wolverine.

```csharp
namespace BuildingBlocks.Infrastructure.Wolverine;

public sealed class ApplicationBus(IMessageBus bus) : IAppCommandBus, IAppQueryBus
{
    // CONFIGUREAWAIT: infrastructure adapter — handlers omit ConfigureAwait (backend-architecture §7).
    public async Task<Result<TResult>> Send<TResult>(ICommand<TResult> command, CancellationToken ct = default)
    {
        try
        {
            // Handler returns Result<T>; the command pipeline (below) owns the transaction + outbox.
            return await bus.InvokeAsync<Result<TResult>>(command, ct).ConfigureAwait(false);
        }
        catch (ValidationException vex)         { return Error.Validation("Validation.Failed", vex.Message); }
        catch (DbUpdateConcurrencyException)    { return Error.Conflict("Concurrency.Conflict"); }
        catch (Exception)                       { return Error.Failure("Dispatch.Failure", "An unexpected error occurred"); }
    }

    public async Task<Result<TResult>> Execute<TResult>(IQuery<TResult> query, CancellationToken ct = default)
    {
        try   { return await bus.InvokeAsync<Result<TResult>>(query, ct).ConfigureAwait(false); }
        catch (Exception) { return Error.Failure("Dispatch.Failure", "An unexpected error occurred"); }
    }
}

// Registration (host or an Infrastructure extension):
services.AddScoped<ApplicationBus>();
services.AddScoped<IAppCommandBus>(sp => sp.GetRequiredService<ApplicationBus>());
services.AddScoped<IAppQueryBus>(sp => sp.GetRequiredService<ApplicationBus>());
```

### The command pipeline — `[Transactional]` by convention

Module handlers stay **pure**: no `[Transactional]`, no `IMessageContext`, no `bus`. The transactional
envelope is applied **by convention** in a Wolverine command-pipeline policy in
`BuildingBlocks.Infrastructure`, so every command flows through the same steps
(`backend-architecture §6`):

```csharp
// BuildingBlocks.Infrastructure/Wolverine/CommandPipelinePolicy.cs
// Applied to every command chain at bootstrap (opts.Policies.Add<CommandTransactionPolicy>()).
// Per command, in order:
//   (a) open the module DbContext transaction (Wolverine.EntityFrameworkCore ambient tx)
//   (b) run FluentValidation (.UseFluentValidation() — validators auto-discovered)
//   (c) run the handler  → Result<T>
//   (d) collect domain events raised on tracked aggregates; run in-process
//       DomainEventHandlers in the SAME transaction
//   (e) map returned IIntegrationEvents → EF-Core outbox rows (same transaction)
//   (f) SaveChanges + commit; the relay publishes outbox rows AFTER commit
// If any step returns an error / throws, the transaction rolls back and NO outbox row is written.
```

This is the `[Transactional]`-equivalent that `backend-architecture §8` invariant #1 enforces: no module
type carries `[Transactional]` or names `IMessageBus`/`IMessageContext` — the policy owns it. The outbox
invariant (state change + event publication commit atomically) is a property of this pipeline, not of any
handler.

## 3. Wolverine setup

```csharp
// hosts/Api/Program.cs  (Worker mirrors this minus HTTP)
builder.Host.UseWolverine(opts =>
{
    // Transport: RabbitMQ topic exchange (integration-event naming in backend-architecture §6; routing keys are project vocabulary).
    opts.UseRabbitMq(builder.Configuration.GetConnectionString("rabbitmq")!)
        .AutoProvision()
        .UseConventionalRouting();

    // Durability: EF-Core outbox + inbox dedup in PostgreSQL.
    opts.PersistMessagesWithPostgresql(
        builder.Configuration.GetConnectionString("postgres")!,
        schemaName: "wolverine");                 // schema name is project config
    opts.UseEntityFrameworkCoreTransactions();    // Wolverine.EntityFrameworkCore — binds outbox to DbContext tx
    opts.Policies.UseDurableInboxOnAllListeners();   // inbox: dedupe brokered msgs by Envelope.Id
    opts.Policies.UseDurableOutboxOnAllSendingEndpoints();

    // Retry / backoff → DLQ. Exhausted retries land on RabbitMQ DLQ / wolverine_dead_letter.
    opts.OnException<DbUpdateConcurrencyException>().RetryWithCooldown(50.Milliseconds(), 200.Milliseconds());
    opts.OnException<TransientException>().RetryWithCooldown(1.Seconds(), 5.Seconds(), 30.Seconds());
    opts.Policies.OnAnyException().Discard();       // anything else → DLQ, no infinite redelivery

    // Apply the by-convention command transaction policy from §2.
    opts.Policies.Add<CommandTransactionPolicy>();
    opts.UseFluentValidation();
});
```

Scheduled messages (`bus.ScheduleAsync`) are durable in `wolverine_scheduled` via the same Postgres
persistence and survive restart — no extra wiring. **Worker host** registers the same Wolverine block so
brokered consumers + the outbox relay run there; the API host may disable local listeners if the Worker
owns consumption (`opts.Policies.DisableConventionalLocalRouting()` per topology — see
`.specify/memory/system-context.md`).

## 4. Persistence wiring

DbContext is registered **per module** (one schema each, `backend-architecture §4` /
`data-access-patterns §3a`). Dapper reads go through an `IDbConnectionFactory`. The `TenantInterceptor`
(authored in `data-access-patterns §10`) is registered for **both** paths.

```csharp
// Per-module DbContext — schema is project config from .specify/memory/system-context.md.
services.AddDbContext<YourContextDbContext>((sp, o) =>
{
    o.UseNpgsql(cfg.GetConnectionString("postgres"), npg => npg.UseNetTopologySuite())
     .AddInterceptors(sp.GetRequiredService<TenantInterceptor>());   // (1) EF write path
});

// Dapper read path — same connection string, separate factory.
services.AddSingleton<IDbConnectionFactory>(_ => new NpgsqlConnectionFactory(cfg.GetConnectionString("postgres")!));

// The interceptor is request-scoped (it reads IUserContext) and used by BOTH registrations.
services.AddScoped<TenantInterceptor>();
```

```csharp
// The Dapper factory applies the SAME tenant session var the EF interceptor sets, so RLS holds on reads.
public sealed class NpgsqlConnectionFactory(string connString, IUserContext user) : IDbConnectionFactory
{
    public async Task<DbConnection> OpenAsync(CancellationToken ct)
    {
        var conn = new NpgsqlConnection(connString);
        await conn.OpenAsync(ct).ConfigureAwait(false);        // CONFIGUREAWAIT: infra adapter
        if (user.TenantId != Guid.Empty)                       // (2) Dapper read path
        {
            await using var cmd = conn.CreateCommand();
            cmd.CommandText = "SELECT set_config('app.current_tenant_id', @tid, false)";
            var p = cmd.CreateParameter(); p.ParameterName = "tid"; p.Value = user.TenantId.ToString();
            cmd.Parameters.Add(p);
            await cmd.ExecuteNonQueryAsync(ct).ConfigureAwait(false);
        }
        return conn;
    }
}
// Register with IUserContext injected: services.AddScoped<IDbConnectionFactory, NpgsqlConnectionFactory>(...).
```

**RLS reminder.** The interceptor / factory only *sets the session variable*; the actual isolation is the
RLS policy on each tenant-scoped table (`data-access-patterns §10`). Wiring without RLS policies is not
isolation. Replica/read connections enforce RLS independently — apply the same factory there. Session-var
name + RLS column are project config (`.specify/memory/`).

## 5. Cache wiring

```csharp
services.AddHybridCache(o =>
{
    o.DefaultEntryOptions = new()
    {
        Expiration           = TimeSpan.FromMinutes(5),    // L2 default; per-call options override
        LocalCacheExpiration = TimeSpan.FromMinutes(1),    // L1 ≤ L2 (caching-patterns §3)
    };
});

// L2 = Redis (Sentinel for HA). Connection/Sentinel endpoints are project config.
services.AddStackExchangeRedisCache(o =>
{
    o.ConfigurationOptions = new ConfigurationOptions
    {
        ServiceName    = cfg["Redis:SentinelServiceName"],          // Sentinel master name
        EndPoints      = { /* sentinel endpoints from cfg["Redis:Sentinels"] */ },
        CommandMap     = CommandMap.Sentinel,
        TieBreaker     = "",
        AbortOnConnectFail = false,
    };
});
// Escape hatches (RedLock.net, raw IDatabase rate-limit adapter) register their own IConnectionMultiplexer
// here — they are the only place application code may touch StackExchange.Redis directly (caching-patterns §9-10).
```

## 6. AuthN wiring (Keycloak)

This is **only the wiring**. The *usage* — RBAC policy checks, ABAC handlers, reading `IUserContext`
inside handlers — lives in `authorization-patterns`. Authority, audience, realm,
and M2M client are project config (`.specify/memory/auth_contract.md`).

```csharp
builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(opt =>
    {
        opt.Authority = cfg["Keycloak:Authority"];   // https://auth.../realms/<realm>
        opt.Audience  = cfg["Keycloak:ClientId"];
        opt.MapInboundClaims = false;                 // preserve Keycloak claim names verbatim
        opt.TokenValidationParameters = new()
        {
            ValidateIssuer = true, ValidateAudience = true, ValidateLifetime = true,
            ValidateIssuerSigningKey = true,          // RS256, JWKS-backed (Keycloak default)
            ClockSkew     = TimeSpan.FromSeconds(30),
            NameClaimType = "preferred_username",
            RoleClaimType = "realm_access.roles",
        };
    });

// IUserContext seam: request-scoped holder, populated by the middleware below.
services.AddScoped<UserContextHolder>();
services.AddScoped<IUserContext>(sp => sp.GetRequiredService<UserContextHolder>().Current);

// RBAC policies (catalog is project vocabulary; the builder mechanism is wiring).
builder.Services.AddAuthorizationBuilder().AddYourContextAuthorization();   // policy catalog usage: authorization-patterns
```

**Claim → `IUserContext` mapping** runs once in `ClaimsToUserContextMiddleware` (authored here),
registered **after** `UseAuthentication()` and **before** `UseAuthorization()`
(§8). It maps `sub`→`UserId`, `tenant_id`→`TenantId`, `realm_access.roles`→`Roles`,
`resource_access.<client>.roles`→`Permissions`, and handles M2M tokens (`azp` present, no `sub` →
`IsViaM2M`, `UserId = Guid.Empty`).

**M2M outbound.** Client-credentials token provider (cached for `expiresIn − 30s` via `HybridCache`) +
its `DelegatingHandler`, registered **before** Polly resilience handlers so retries replay the attached
header instead of re-acquiring a token (handler-chain-order joint rule: `integration-adapter-patterns §4`).

```csharp
services.AddSingleton<IM2MTokenProvider, KeycloakM2MTokenProvider>();
services.AddTransient<M2MTokenHandler>();
services.AddHttpClient("keycloak", c => c.BaseAddress = new(cfg["Keycloak:BaseUrl"]!));

services.AddHttpClient<ISomeExternalPort, SomeExternalAdapter>()
        .AddHttpMessageHandler<M2MTokenHandler>()   // BEFORE resilience — handler-chain order matters
        .AddStandardResilienceHandler();             // Polly v8 — outermost retry replays the token header
```

## 7. Jobs / workflow hosts

Hangfire and Elsa persist to PostgreSQL in **distinct schemas** (`hangfire.*`, `elsa.*` —
`orchestration-patterns §6`). Both dashboards are admin-only. Schema names + cron values are project
config.

```csharp
// Hangfire — PG storage in hangfire.* schema.
services.AddHangfire(c => c
    .UsePostgreSqlStorage(o => o.UseNpgsqlConnection(cfg.GetConnectionString("postgres")),
                          new PostgreSqlStorageOptions { SchemaName = "hangfire" }));
services.AddHangfireServer();
GlobalConfiguration.Configuration.AddYourContextRecurringJobs();   // orchestration-patterns §9

// Elsa v3 — PG persistence in elsa.* schema.
services.AddElsa(elsa => elsa
    .UseWorkflowManagement(m => m.UseEntityFrameworkCore(ef => ef.UsePostgreSql(cfg.GetConnectionString("postgres"))))
    .UseWorkflowRuntime()
    .AddWorkflowsFrom<ListingApprovalWorkflow>());
```

**Dashboard authorization filters** (admin-only, `platform.admin` role — `orchestration-patterns §11`):

```csharp
// /hangfire — JWT already validated by the middleware; filter requires platform.admin.
app.UseHangfireDashboard("/hangfire", new DashboardOptions
{
    Authorization = [new HangfireDashboardAuthFilter()]   // checks realm_access.roles contains platform.admin
});
// /elsa-studio — same role gate, wired via Elsa's dashboard auth options. Never exposed via the portal.
```

## 8. Composition roots — wire-up order

Order is load-bearing: the auth middleware must populate the principal before the claim→context mapping,
which must run before authorization, which must run before endpoints.

```csharp
// hosts/Api/Program.cs
var builder = WebApplication.CreateBuilder(args);
builder.AddServiceDefaults();                       // Aspire: OTel + health (see note below)

// ── Registrations (order among these does not matter) ──
builder.Host.UseWolverine(/* §3 */);
builder.Services.AddScoped<IAppCommandBus, ApplicationBus>();      // §2 (and IAppQueryBus)
builder.Services.AddModulePersistence(builder.Configuration);     // §4 — DbContexts, factory, interceptor
builder.Services.AddHybridCache(/* §5 */);                         // §5 — cache + Redis L2
builder.Services.AddAuthentication(/* §6 */).AddJwtBearer(/* §6 */);
builder.Services.AddScoped<UserContextHolder>();                  // §6 — IUserContext seam
builder.Services.AddAuthorizationBuilder().AddYourContextAuthorization();
builder.Services.AddHangfire(/* §7 */); builder.Services.AddElsa(/* §7 */);
builder.Services.AddFastEndpoints();                              // api-endpoint-patterns

var app = builder.Build();

// ── Pipeline (order IS the contract) ──
app.UseAuthentication();                            // 1. validate JWT → ClaimsPrincipal
app.UseMiddleware<ClaimsToUserContextMiddleware>(); // 2. claims → IUserContext  (after authn, before authz)
app.UseAuthorization();                             // 3. policy evaluation
app.UseFastEndpoints().UseScalar();                 // 4. endpoints
app.UseHangfireDashboard("/hangfire", /* §7 */);    //    admin dashboards
app.MapDefaultEndpoints();                          // Aspire health endpoints
app.Run();
```

**Worker host** (`hosts/Worker`) omits the HTTP pipeline (no authn/authz/endpoints): it wires Wolverine
(consumers + outbox relay), persistence, cache, and the Hangfire server — but `IUserContext` for
background work resolves from the message's `tenant_id`/`originating_user_id` metadata
(`backend-architecture §6`; consumed per `authorization-patterns`), not from an HTTP principal.

**Aspire AppHost + ServiceDefaults.** The solution's `AppHost` project composes services + backing
resources (Postgres, RabbitMQ, Redis, Keycloak); `ServiceDefaults` provides `AddServiceDefaults()`
(OTel traces/metrics/logs, health checks, resilience defaults) and `MapDefaultEndpoints()`. The OTel
exporters, Serilog sink, and GlitchTip wiring are detailed in `observability-backend` /
`.specify/memory/observability-stack.md` — referenced here, not restated.

## 9. Anti-patterns

- **Wiring leaking into a module.** Any `AddWolverine`/`AddDbContext`/`AddHybridCache`/`AddJwtBearer`
  call inside a module's `Application` or `Api` — registration lives in `hosts/` +
  `BuildingBlocks.Infrastructure` only.
- **Feature code naming a backing library type.** A handler injecting `IMessageBus`/`IMessageContext`,
  `DbContext` into `Application`/`Domain`, `IConnectionMultiplexer`/`IDatabase`, `ClaimsPrincipal`, or a
  Hangfire/Elsa runtime type. Feature code names the seam (`IAppCommandBus`, repository interfaces,
  `HybridCache`, `IUserContext`) — NetArchTest invariant #1 (`backend-architecture §8`) fails the build
  otherwise.
- **`[Transactional]` on a module handler** — the transaction is applied by the §2 pipeline policy by
  convention; handlers stay pure.
- **Catching Wolverine/infra exceptions outside `ApplicationBus`** — turning infra faults into `Result.Failure`
  is confined to this seam impl; modules see only `Result<T>` and never reference Wolverine.
- **Hardcoding project facts** (realm, connection strings, schema names, cache prefix, RLS column) in
  this skill or in code — they are config from `.specify/memory/` + `IConfiguration`.
- **Reordering the host pipeline** so claim-mapping runs before `UseAuthentication()` or after
  `UseAuthorization()` — `IUserContext` is then empty or authorization sees no roles.
- **A dashboard without its auth filter** — `/hangfire` and `/elsa-studio` are information disclosure if
  the `platform.admin` filter is omitted.

## 10. References

- `backend-architecture` — the seams this skill implements: catalog (§2), building-blocks chain (§3),
  event/outbox model (§6), tech-per-edge (§9), NetArchTest invariants (§8). Read first.
- `backend-feature-patterns` / `orchestration-patterns` — handler-facing dispatch + saga/job usage (this skill wires the host runtime behind them).
- `data-access-patterns` — the `TenantInterceptor` + RLS policy authored there; registered here.
- `caching-patterns §3, §9-10` — TTL rules + escape-hatch adapters that register their own multiplexer.
- `authorization-patterns` — RBAC/ABAC + `IUserContext` usage (this skill wires the AuthN that backs it).
- `orchestration-patterns §6, §9, §11` — Hangfire/Elsa schemas, recurring registration, dashboard filters.
- `observability-backend` + `.specify/memory/observability-stack.md` — OTel/Serilog/GlitchTip wiring.
- `.specify/memory/{system-context,auth_contract}.md` — realm, connection strings, schema names, topology.
