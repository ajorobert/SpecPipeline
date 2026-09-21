# Skill Audit — 2026-04-30

Scope: every directory under `.claude/skills/` containing a `SKILL.md`. Audited against the stack reference: C# .NET 10, FastEndpoints v6+, Wolverine + EF outbox, MediatR, EF Core writes / Dapper reads, Elasticsearch, Hangfire, Elsa v3, PostgreSQL, Redis sentinel, Keycloak, OTel→Loki/Jaeger/Prometheus/GlitchTip, Next.js portal, React+Vite admin SPA, React Native+Expo vendor app, BFF, MinIO/Cloudflare R2.

Skills audited: 41 (28 tech-stack/context + 13 sk.* orchestration).

---

## Summary — top issues ranked by impact on consistency

1. **`messaging-patterns` is entirely MassTransit, but the stack uses Wolverine + EF Core outbox.** `messaging-patterns/SKILL.md:3,9,21,27,54,68,74,83,102,109,125,128` and 14+ other lines all teach `MassTransit` / `IConsumer<T>` / `MassTransitStateMachine` / `AddMassTransit` / `AddEntityFrameworkOutbox`. This is *load-bearing drift* — every adjacent skill (`csharp-clean-arch`, `file-storage-patterns`, `elasticsearch-patterns`, `redis-patterns`, `workflow-patterns`, `observability-backend`, `design-code-review`) cross-references "see messaging-patterns for outbox / consumer mechanics" and `observability-backend` even has a Wolverine outbox-propagation middleware. AI-generated code will mix Wolverine consumers with MassTransit registration and produce non-compiling hybrids. **Highest-priority fix.**

2. **`bounded-context-patterns` is referenced 6 times in `csharp-clean-arch` (lines 12, 27, 85, 159, 383) but the skill does not exist.** Anything cross-context — integration events, `Shared.Contracts/`, project structure across services, schema-break handling — is left to the agent's imagination. Given 13 bounded contexts in the system, this is the single biggest hole.

3. **`auth-patterns` and `file-storage-patterns` use ASP.NET Core MVC controllers (`[ApiController]` / `ControllerBase`)**, but the stack uses FastEndpoints. `auth-patterns/SKILL.md:117–132` shows a full `ListingsController : ControllerBase`. `file-storage-patterns/SKILL.md:144–156` shows `UploadsController : ControllerBase`. `design-code-review/SKILL.md:21,67,101–112` reviews "Controllers contain no business logic" and uses controller examples. `fastendpoints-patterns` correctly forbids MVC but the other backend skills haven't been migrated.

4. **`design-code-review` (CQRS section) is excellent — but the rest of it teaches outdated controller-based patterns** (ProblemDetails/`ToActionResult`, `IRequest<Result<T>>`). It's now both correct (CQRS rules) and wrong (controller examples) in the same file.

5. **CLAUDE.md routing table contradicts skill content.** CLAUDE.md says `messaging-patterns | RabbitMQ, MassTransit, MediatR, Hangfire work` (MassTransit name baked in) and `auth-patterns | Firebase/Keycloak auth` (Firebase isn't in `auth-patterns/SKILL.md` at all — the skill says "Keycloak is the sole identity provider"). `nextjs-patterns/SKILL.md:80` mentions Firebase as a v1 fallback in a comment. Either drift or unfinished migration.

6. **No `bounded-context-patterns` skill, and `csharp-clean-arch` punts cross-context concerns there.** Adding it is high-leverage — one skill picks up `Shared.Contracts/`, integration event versioning, schema ownership, and the modular-monolith → microservice split rules.

7. **`observability-patterns/` directory still exists as an empty folder** — the SKILL.md was archived 2026-04-29 (per ARCHIVE_LOG.md) but the parent dir was not removed. Causes confusion for tooling that walks `.claude/skills/*/` looking for SKILL.md.

8. **Scope overlap on rate limiting + idempotency between three skills** — `fastendpoints-patterns` (idempotency-key contract, throttle keys), `redis-patterns` (rate-limit key naming + sliding window snippet), `bff-patterns` (BFF rate-limit per `sub`). All three rules are *compatible*, but the example code is duplicated and the contract source is unclear. Pick one owner per concept and cross-reference.

9. **Convention drift on auth comment markers between `fastendpoints-patterns` and `csharp-clean-arch`.** `fastendpoints-patterns:118–130` mandates the exact string `// AUTH: Anonymous — REASON: <reason>` (em-dash, exact spacing) and adds parallel `// ENDPOINT: Untyped — REASON:`, `// STREAM: <reason>`, `// IDEMPOTENCY: Not required — REASON:`. No other skill references these markers — there's no canonical list.

10. **Per-skill bloat in `auth-patterns` (547 lines) and `fastendpoints-patterns` (451 lines).** Both contain implementation code (`PropagatedUserContextMiddleware`, `KeycloakM2MTokenService`, `RuntimeRatioSampler`-equivalent boilerplate, full `Program.cs` JWT setup with `MapInboundClaims`, full claim-extension methods). This belongs in `src/Shared.Web/` referenced by path, not embedded.

---

## Per-skill assessment

Skills grouped: **Tech-stack context (alphabetical)**, **Cross-cutting context**, **sk.* orchestration**.

### accessibility-standards
- Length: 176
- Purpose alignment: Yes — directly supports consistency for WCAG 2.2 AA across portal + admin SPA.
- Stack drift: None observed. WCAG 2.2 references are current.
- Scope overlap: Form a11y rules (`accessibility-standards:81–90`) overlap with `react-component-patterns` form section (`react-component-patterns:78–98`); both prescribe `aria-invalid` + `aria-describedby` on errors. Not a contradiction — recommend `accessibility-standards` owns the contract, `react-component-patterns` cross-references with one bullet.
- Bloat: None — all rules.
- Over-prescription: "Never use `outline: none`" (`:41`) is correct but rigid; soften to "must provide a `:focus-visible` replacement of equal or better contrast." It already says this; consider tightening the wording to avoid sounding contradictory.
- Missing rules: No mention of accessibility for React Native (mentions `accessibilityLabel` only in "When NOT to use"). Either add a "see react-native-patterns" cross-reference or expand `react-native-patterns` (which has zero a11y content right now — see that skill).
- Cross-skill consistency: Uses ARIA names consistently. Good.
- CI enforceability: axe-core / Lighthouse stated (`:100`) — mechanically checkable.
- Description routing: Description is precise. SHOULD-load: "implement focus management for the listing card", "review WCAG AA contrast on dark mode", "add aria-live to toast container". SHOULD-NOT: "make the cron job idempotent", "tune Hangfire retries".
- Recommended actions:
  1. Add a "for React Native, see `react-native-patterns` accessibility section" pointer (and add that section in `react-native-patterns`).
  2. None other.

### architecture-decisions
- Length: 8
- Purpose alignment: Yes — pointer skill into `.specify/memory/architecture-decisions.md`.
- Stack drift: n/a (passive memory pointer).
- Scope overlap: None.
- Bloat: None.
- Over-prescription: None.
- Missing rules: Could state "ADR is required when X" inline (currently delegates to memory).
- Cross-skill consistency: Identical pattern to `system-context`, `service-registry`, `domain-model`, `standards`. Consistent.
- CI enforceability: n/a.
- Description routing: Clear — loads only when ADRs are involved.
- Recommended actions: none. Acceptable as-is for a memory pointer.

### auth-patterns
- Length: 547 (largest skill)
- Purpose alignment: Strong — covers the central authn/authz model.
- Stack drift: **MVC controllers used in examples** (`:117–132`: `[ApiController][Route(...)] public class ListingsController : ControllerBase`). The stack uses FastEndpoints (`fastendpoints-patterns:23` forbids `MVC controllers in this stack`). Either remove the controller example entirely (the policies/claims/handlers carry the message) or rewrite as a FastEndpoints `Configure() { Policies(...) }` example consistent with `fastendpoints-patterns:108–116`.
- Scope overlap:
  - Propagated header handling (`:374–501`) overlaps materially with `bff-patterns:60–109`. Both define how `X-User-Id` / `X-Tenant-Id` / `X-User-Roles` flow. Recommend `auth-patterns` owns "service-side validation + synthetic principal" and `bff-patterns` owns "BFF-side issuance + when to use which flow." Cross-reference each direction.
  - `IUserContext` (`:459–500`) duplicates the same pattern referenced in `auth-patterns` PostgreSQL section (`postgresql-patterns:117–151` refers back to `auth-patterns` for `ITenantContext` — which isn't quite the same as `IUserContext`; one carries `TenantId` the other carries the full principal). This is mildly confusing — clarify whether the canonical name is `IUserContext` (this skill) or `ITenantContext` (postgresql-patterns reference at `:148`). Pick one and standardize.
- Bloat: Heavy. The full `Program.cs` JWT setup (`:33–51`), the full `ClaimsPrincipalExtensions` (`:57–81`), the `KeycloakM2MTokenService` (`:343–367`), the `PropagatedUserContextMiddleware` (`:418–446`), and the `HttpUserContext` (`:472–482`) are **infrastructure code** belonging in `src/Shared.Auth/` (or similar). Reference by path; keep only the contracts (claim names, comment markers, policy registry rules, token lifespan policy).
- Over-prescription: 5-minute access token lifespan (`:510`) is rigid but justified by ADR; flagged as ADR-level. Acceptable.
- Missing rules: 
  - No statement on when `X-User-Roles` should be a comma string vs JSON array (the example uses comma-split which is fragile under role names containing commas — extremely unlikely but flag).
  - No mention of how `IUserContext.IsViaM2M` should be logged (audit trail).
  - No coordinate with `observability-backend` PII deny-list — `Authorization` header redaction is mentioned at `:528` but the deny-list field name `authorization` is in the `observability-contracts` deny-list. Cross-reference.
- Cross-skill consistency: `IUserContext` vs `ITenantContext` naming inconsistent across skills (see overlap above).
- CI enforceability: 
  - "No `Roles(...)` / `Permissions(...)` calls" is enforceable — already covered in `fastendpoints-patterns:430` CI list. Good — single owner.
  - "All policies registered in `AuthorizationPolicies.cs`" — enforceable via grep.
  - "`MapInboundClaims = false`" — enforceable.
  - But the skill itself doesn't enumerate its CI checks the way `fastendpoints-patterns` does.
- Description routing: SHOULD-load: "add a CanEditListing policy", "implement ABAC for vendor bookings", "review the Keycloak claim mapping". SHOULD-NOT: "design the geo polygon search query", "add a Hangfire recurring job".
- Recommended actions (prioritized):
  1. Replace the MVC controller example at `:117–132` with the FastEndpoints `Policies(...)` form from `fastendpoints-patterns:108–116`.
  2. Move `Program.cs` JWT setup, `KeycloakM2MTokenService`, `PropagatedUserContextMiddleware`, `HttpUserContext` to `src/Shared.Auth/` (referenced by path). Keep contracts.
  3. Resolve `IUserContext` vs `ITenantContext` naming with `postgresql-patterns:148` — pick one canonical name.
  4. Add explicit CI Enforcement section mirroring `fastendpoints-patterns:425–438`.

### bff-patterns
- Length: 207
- Purpose alignment: Yes — names the decision (BFF vs direct) which is the load-bearing concern.
- Stack drift: None — uses Polly + ASP.NET Core RateLimiter, both correct. M2M token cache pattern (`:170–183`) duplicates `auth-patterns:343–367` with cosmetic differences (`KeycloakM2MTokenProvider` vs `KeycloakM2MTokenService`, `bff_m2m_token` vs `keycloak_m2m_token`). Pick one canonical name.
- Scope overlap:
  - **Significant overlap with `auth-patterns`** on user-context propagation (`bff-patterns:60–109` ↔ `auth-patterns:374–501`). They are not contradictory but they teach the same flow twice. Recommend `bff-patterns` owns the BFF *decision* and aggregation; `auth-patterns` owns service-side validation. Drop the BFF-side middleware code from this skill — keep only the conceptual flow.
  - DTO layering (`:136–148`) is good and sits cleanly next to `csharp-clean-arch`'s read-shape DTOs. No conflict.
- Bloat: M2M token cache snippet (`:170–183`) — see overlap above.
- Over-prescription: None — explicitly says BFF is not mandatory (good guideline framing).
- Missing rules:
  - No statement on `traceparent` propagation (covered in `observability-contracts:36–50` — should cross-reference).
  - No idempotency-key forwarding rule. If the client sends `Idempotency-Key` to the BFF, what happens — does the BFF forward, generate its own, or wrap? `fastendpoints-patterns:250–281` defines the contract on the service side; BFF should state the forwarding rule.
  - No request size limit at BFF entry. Service has 256KB / 1MB rules in `fastendpoints-patterns:307–313`; BFF needs equivalent or "passthrough."
- Cross-skill consistency: Uses `IsM2MClient()` (`:100`) — same name as `auth-patterns:389`. Good.
- CI enforceability: "BFF DTOs not in any backend service spec" — checkable via OpenAPI introspection.
- Description routing: SHOULD-load: "decide whether the listing-detail page goes through BFF", "design the dashboard fan-out aggregation", "set up M2M token cache". SHOULD-NOT: "implement the indexer consumer", "add a database migration."
- Recommended actions (prioritized):
  1. Remove M2M token cache snippet; replace with `// see auth-patterns Service-to-Service section` reference.
  2. Add `Idempotency-Key` forwarding rule (forward client header verbatim, do not generate).
  3. Add `traceparent` propagation cross-reference to `observability-contracts`.
  4. Add request-size-limit rule (or "passthrough to service" statement).

### csharp-clean-arch
- Length: 387
- Purpose alignment: Excellent. Single best skill in the set — the consistency anchor for backend code.
- Stack drift: 
  - **References `bounded-context-patterns`** (`:12, 27, 85, 159, 383`) — *the skill doesn't exist*. Either create it or stop pretending it does.
  - "MediatR may move to Wolverine" disclaimer (`:90`) is honest and the marker-interface design is dispatcher-neutral. Good.
  - All other tech (EF Core writes, Dapper reads, ES search, Result, FluentValidation, Scrutor) is current.
- Scope overlap:
  - Aggregate / domain rules cleanly owned here. No overlap.
  - Output of `IListingReadRepository` shape (`:115–127`) duplicates `postgresql-patterns:14–28` CQRS table. Fine — both reference each other.
- Bloat: Some example code (`:213–325`) is example, not infrastructure boilerplate. Acceptable — these are *patterns*, not infra.
- Over-prescription:
  - "Do NOT use `ConfigureAwait(false)` in application/API code" (`:183`) is correct for ASP.NET Core but rigid. Could soften slightly — `// CONFIGUREAWAIT: <reason>` marker for library-author exceptions. Currently no escape hatch.
  - "30 line method limit" (`:205`) is already framed as a guideline. Good.
- Missing rules:
  - No rule on `[GeneratedRegex]` source-generators for value-object validation in .NET 10 — minor.
  - The "No Wolverine, no MediatR" Domain rule (`:20`) is good but doesn't address Wolverine handlers in Application — Wolverine has handler discovery patterns (e.g., `Handle()` method by convention) that conflict with the marker interfaces shown. If/when the dispatcher swap happens, this skill needs an update plan.
- Cross-skill consistency: Cross-references `fastendpoints-patterns`, `messaging-patterns`, `observability-backend`, `redis-patterns`, `elasticsearch-patterns`, `bff-patterns`, `bounded-context-patterns` (broken). Solid graph except the broken one.
- CI enforceability: 
  - "Domain has zero infra references" — Roslyn-checkable.
  - "Handler injecting both write and read repo" — Roslyn-checkable.
  - "`IQueryable` exposed from repo interface" — Roslyn-checkable. Good — `design-code-review` already lists these as blocking.
- Description routing: SHOULD-load: "implement ActivateListing aggregate method", "split the read repo from the write repo", "review the validator vs aggregate-invariant placement". SHOULD-NOT: "deploy the OTel collector", "add tailwind dark-mode tokens".
- Recommended actions (prioritized):
  1. **Create `bounded-context-patterns` skill** OR remove the 6 references and inline what's needed (the latter is worse — see Cross-skill A).
  2. Add an Application-layer rule for the Wolverine swap path: "if/when Wolverine becomes the dispatcher, the marker interfaces stay; only `Program.cs` and the base `IRequestHandler` change." (Already implicit at `:90` — make it explicit.)
  3. Add `// CONFIGUREAWAIT: <reason>` escape-hatch marker for the `:183` rule.

### design-code-review
- Length: 139
- Purpose alignment: Yes — code-review checklist for backend.
- Stack drift: 
  - **Uses MVC controllers** in the "Incorrect: Business logic in controller" example (`:101–112`) — the example is teaching the right lesson but the *vehicle* is wrong (the stack has no MVC controllers). Replace with FastEndpoints `Endpoint<>.HandleAsync` doing the same wrong thing.
  - Section 1 (`:21`): "Controllers contain no business logic" — wrong noun. Should be "endpoints."
  - Section 2 (`:24`): `IRequest<Result<T>>` — should reference the marker interfaces from `csharp-clean-arch` (`ICommand` / `IQuery`). The CQRS section at `:50–58` does this correctly; the design-patterns section at `:24` is inconsistent with itself.
- Scope overlap: Substantial overlap with `csharp-clean-arch` (CQRS rules, layer rules). Reasonable for a review checklist — but it should reference, not redefine. E.g., `:38–42` "Async correctness" duplicates `csharp-clean-arch:178–186` verbatim concepts. Recommend `design-code-review` becomes a thin index of "review against rules in [csharp-clean-arch / fastendpoints-patterns / auth-patterns]" plus the *blocking* list — not a re-explanation.
- Bloat: Moderate — the duplicated rule text.
- Over-prescription: 30-line method limit + 3-param limit are guidelines (`:75–76`) — flagged as advisory. Good.
- Missing rules:
  - No CI enforcement enumeration (`fastendpoints-patterns:425` has one — would be useful here too).
  - No FastEndpoints-specific review rules (no `Roles(...)`, mandatory `Summary` class) — refer to `fastendpoints-patterns` CI list.
  - No observability review (every span/log has TraceId — see `observability-backend`).
- Cross-skill consistency: Inconsistent with self (controller vs endpoint). Inconsistent with `csharp-clean-arch` on marker interfaces.
- CI enforceability: Most listed items are enforceable (Roslyn) — good.
- Description routing: SHOULD-load: "review the new Listings.Activate handler PR", "audit the Identity service for SOLID violations", "pre-merge backend code review". SHOULD-NOT: "review the Tailwind tokens", "review the Strapi schema migration."
- Recommended actions (prioritized):
  1. Replace controller example at `:101–112` with FastEndpoints equivalent.
  2. Replace "controllers" terminology globally (`:21, :42`).
  3. Replace `IRequest<Result<T>>` (`:24`) with `ICommand<>` / `IQuery<>` markers.
  4. Convert duplicated rule sections into "review against [skill] §[section]" pointers.
  5. Add CI Enforcement section enumerating mechanical checks.

### design-principles
- Length: 59
- Purpose alignment: Yes — DDD + DDIA principles for design phase.
- Stack drift: None — principle-level, stack-agnostic.
- Scope overlap: Light overlap with `csharp-clean-arch` (DDD aggregate invariants), but at a different abstraction level (principles vs implementation rules). Acceptable.
- Bloat: None — concise.
- Over-prescription: `[REQUIRED]` vs `[Advisory]` distinction is good and unique to this skill — recommend other skills adopt the same convention.
- Missing rules:
  - DDIA Ch 11 (stream processing) referenced (`:53`) but not Ch 5 (replication) or Ch 7 (transactions). Minor — would only add if expanding.
  - No statement on naming consistency (bounded context vs module vs service — see Convention drift D).
- Cross-skill consistency: This is the canonical home of "consistency requirement declared per write path" (`:34`). Quality gates `quality-gates.md:21` references this.
- CI enforceability: Most items require human review. Acceptable — design phase.
- Description routing: SHOULD-load: "design the listing data model access patterns", "decide consistency model for reservation writes". SHOULD-NOT: "implement the listing aggregate factory", "deploy the OTel collector."
- Recommended actions (prioritized):
  1. Add a one-line glossary fixing terminology (bounded context = service = module — see drift D).
  2. None other — this is one of the better-shaped skills.

### domain-model
- Length: 9
- Purpose alignment: Yes — pointer to memory.
- Stack drift: n/a.
- Other dimensions: identical pattern to `architecture-decisions`, `system-context`, `service-registry`. Consistent.
- Recommended actions: none.

### elasticsearch-patterns
- Length: 186
- Purpose alignment: Yes — owns search-shaped reads and the geo concern.
- Stack drift: 
  - Uses `Elastic.Clients.Elasticsearch` correctly (`:84`) — the current official .NET 10 client.
  - Uses MassTransit consumers (`:24, 92, 161–172`) — drift via `messaging-patterns` propagation. When `messaging-patterns` is fixed to Wolverine, fix here too.
- Scope overlap: 
  - "PostgreSQL is source of truth, ES is derived" (`:23, 92`) is correctly stated and matches `postgresql-patterns:14–28` and `csharp-clean-arch:115–127`.
  - "Consistency model: eventual" (`:98`) overlaps with `redis-patterns:31–39`'s eventual-consistency section. Both are correct; both should cross-reference `design-principles:34`.
- Bloat: None — examples are illustrative.
- Over-prescription: "Search query handlers must never fall back to PostgreSQL" (`:19`) — appropriately rigid. Good.
- Missing rules:
  - No rule on index-template management (vs creating per-version indexes manually). Minor.
  - No rule on cluster-restart behavior (during reindex, what happens to in-flight queries?).
  - Trace propagation through indexer consumer — should reference `observability-backend` Wolverine middleware.
- Cross-skill consistency: References `csharp-clean-arch`, `postgresql-patterns`, `messaging-patterns`. Good graph.
- CI enforceability: "No raw JSON strings in app code" (`:86`) — grep-checkable.
- Description routing: SHOULD-load: "design the listings index mapping", "implement geo polygon search", "tune the search query for facets". SHOULD-NOT: "implement the activate command", "add Redis cache decorator."
- Recommended actions (prioritized):
  1. Replace MassTransit consumer references with Wolverine consumer terminology when `messaging-patterns` is fixed.
  2. Add cross-reference to `observability-backend` for indexer trace propagation.

### fastendpoints-patterns
- Length: 451
- Purpose alignment: Excellent. Owns HTTP surface.
- Stack drift: None — FastEndpoints v6 contracts correctly identified at `:8`.
- Scope overlap:
  - **Idempotency-Key contract** (`:250–281`) is the canonical statement. `redis-patterns:55` mentions `idem:{service}:{user_or_tenant}:{uuid}` keys — consistent. Good.
  - Throttle key conventions (`:160–174`) duplicate Redis section (`redis-patterns:55–67`); both name `bff:rate-limit:{user_id}:{window}`. Consistent.
  - `bff-patterns` says "rate limit at BFF" and `fastendpoints-patterns` says "rate limit at service for sensitive endpoints" — these are *complementary*, not duplicate. Good, but worth a one-line clarification in either skill.
- Bloat: Moderate.
  - Full `Configure()` ordering example (`:319–339`) is fine.
  - Caching headers section (`:228–248`) is forward-looking — flagged in the skill itself as "if your stack handles caching at gateway today, this is forward-looking" — acceptable.
  - The IDoR-style rule list in CI Enforcement (`:425–438`) is great — *should be the model for other skills*.
- Over-prescription: 
  - "The bare `Endpoint` class is forbidden" — has explicit `// ENDPOINT: Untyped — REASON:` escape (`:39`). Good.
  - "No FastEndpoints `Mapper<,,>` base class" (`:178–182`) — rigid but architecturally justified (Clean Arch leak). Good.
  - "MaxRequestBodySize required" (`:296–314`) — rigid. Good — the table provides clear defaults.
- Missing rules:
  - **No rule on `traceparent` propagation through the endpoint** (auto-instrumentation handles it but worth one sentence pointing to `observability-backend`). 
  - No rule on file-upload streaming endpoints (the `// STREAM:` marker exists at `:435` but the file-upload case is described in `file-storage-patterns` as a presigned URL — not a streaming endpoint. Reconcile.).
  - No rule on `IRequestPipeline` ordering (validators run automatically, but if multiple FluentValidation validators exist, what's the order?).
- Cross-skill consistency:
  - `// AUTH: Anonymous — REASON:` exact format mandated (`:128`) — *no other skill mentions this marker*. Should be in a shared "comment markers" reference (see Convention drift D).
  - References `csharp-clean-arch`, `auth-patterns`, `observability-backend`, `redis-patterns`, `messaging-patterns`. Solid graph.
- CI enforceability: **Best in the set** — explicit numbered list of mechanical checks at `:425–438`.
- Description routing: SHOULD-load: "add the activate endpoint with policy + throttle", "review the Idempotency-Key contract", "design the v2 of the listings API". SHOULD-NOT: "review the Wolverine consumer", "design the search index mapping."
- Recommended actions (prioritized):
  1. Move filter implementations / registration boilerplate (`SendResultAsync`, throttle storage adapter, idempotency filter, `Shared.Web/Hosting/FastEndpointsHost.cs`) out of inline references into `src/Shared.Web/` path comments. Already mostly done — the rules say "implementation lives in src/Shared.Web/..." — verify nothing else got embedded.
  2. Reconcile streaming-endpoint (`STREAM:`) story with `file-storage-patterns` (which uses presigned URLs, not streaming).
  3. Add a one-line traceparent cross-reference.

### file-storage-patterns
- Length: 249
- Purpose alignment: Yes — file aggregate + saga + buckets.
- Stack drift: 
  - **Uses MVC controller** (`UploadsController : ControllerBase`, `:144–156`). Drift — should be FastEndpoints. Replace with `Endpoint<PresignUploadRequest, PresignedUploadResponse>` form.
  - Uses MassTransit consumer (`VirusScanConsumer : IConsumer<FileUploaded>`, `:212–238`) — drift via `messaging-patterns`. Fix when that skill is fixed.
  - References `IPublishEndpoint.Publish` directly inside a consumer (`:227, 234`) — the rule at `:60` correctly forbids this ("Any direct `Publish` call in their `Consume` method is a bug"). The example at `:212–238` *violates the rule it teaches*. Fix to use outbox-publish from within the consumer's transactional unit of work.
  - Says "MassTransit state-machine saga" (`:44`) — should be Wolverine equivalent if migrating.
  - "S3-compatible API" (`:47`) — the stack uses MinIO + Cloudflare R2; explicitly state that.
- Scope overlap: 
  - Owns the file-storage bounded context cleanly. No overlap with other skills except shared-outbox concept (correctly delegated to `messaging-patterns`).
- Bloat: 
  - The full `RequestPresignedUploadHandler` (`:163–201`) is illustrative — acceptable as a pattern.
  - The `VirusScanConsumer` (`:212–238`) embeds the bug above — fix or move to repo path reference.
- Over-prescription: 
  - "Files never move from quarantine to public in one step — always quarantine → private → public" (`:51`) — good, justified.
  - 30-day grace period for soft delete (`:127`) — could vary by entity. Soften to "default 30-day, configurable per entity."
- Missing rules:
  - No mention of CDN purge on `FileScanInfected` after publish (if a public asset somehow got there). Edge case.
  - No virus-scan vendor neutrality — locks to ClamAV (`:86`); should be "ClamAV by default, replaceable behind `IVirusScanService`."
  - No mention of `traceparent` propagation through the consumer.
- Cross-skill consistency: References `messaging-patterns`, `csharp-clean-arch`, `workflow-patterns` (correctly says "use saga not Elsa here"), `redis-patterns` not referenced (could mention idempotency-key on the presign endpoint).
- CI enforceability: "MIME type read from magic bytes, not extension" (`:79`) — testable but not greppable.
- Description routing: SHOULD-load: "design the file upload pipeline", "implement the virus scan consumer", "add image-pipeline image processing step". SHOULD-NOT: "design the listing search index", "set up the BFF aggregation."
- Recommended actions (prioritized):
  1. Replace MVC controller with FastEndpoints endpoint (`:144–156`).
  2. Replace MassTransit consumer with Wolverine consumer (when messaging-patterns is fixed).
  3. Fix the `VirusScanConsumer` example — it currently teaches one rule and breaks another (`:60` vs `:212–238`).
  4. Name MinIO + Cloudflare R2 explicitly at `:47` instead of generic "S3-compatible."
  5. Add "saga implementation lives in src/Shared.Files/Sagas/" path reference instead of leaving it implicit.

### frontend-design-system
- Length: 219
- Purpose alignment: Yes — Tailwind v4 + shadcn + tokens.
- Stack drift:
  - Tailwind v4 + `@import "tailwindcss"` (`:15`) is current.
  - shadcn/ui patterns are current.
  - HSL token strategy is current.
- Scope overlap: 
  - `react-component-patterns:81–98` shows shadcn `Form` structure; `frontend-design-system:95–96` *also* shows shadcn `Form` structure rule. Recommend one owns the form-skeleton rule and the other cross-references. Currently both are correct — pick `react-component-patterns` (closer to component design) and reduce here to "see react-component-patterns for Form structure."
  - Dark mode toggle pattern (`:191–207`) overlaps with `zustand-state-management:78–102` persisted theme. Both are correct (next-themes here, persist there) but a coordinated reading order would help — add a "if you need persisted user preference, see zustand-state-management" pointer.
- Bloat: The four-step token pattern (`:21–73`) is necessary — keep. The button CVA example (`:103–123`) is illustrative — keep. The card example (`:151–181`) is borderline; it's *example*, not infra — acceptable.
- Over-prescription: 
  - "Never use `tailwind.config.ts`" (`:15`) — rigid but correct for v4.
  - "Never use raw colour classes (`bg-white`)" (`:81`) — could soften to "for product UI; marketing surfaces with brand-fixed color may opt out via `// COLOR: BrandFixed — REASON:`" Currently no escape hatch.
- Missing rules:
  - No rule on container-query escape hatch when tokens don't fit (rare).
  - No rule on icon-library standardization (lucide-react in example at `:194` but never declared).
  - No mention of Tailwind v4 `@variant` for custom variants.
- Cross-skill consistency: References `react-component-patterns`, `react-native-patterns`. Good.
- CI enforceability: "No `bg-[#aabbcc]`" — grep-checkable. "No `tailwind.config.ts` present" — file-existence check. Good.
- Description routing: SHOULD-load: "add a new shadcn variant", "implement dark mode toggle", "configure HSL tokens for the brand color". SHOULD-NOT: "implement the React Native swipe gesture", "design the Wolverine consumer."
- Recommended actions (prioritized):
  1. Reduce form skeleton rules to a pointer to `react-component-patterns`.
  2. Declare canonical icon library (lucide-react) in a one-liner.
  3. Add `// COLOR: BrandFixed — REASON:` escape-hatch marker for marketing use cases.

### messaging-patterns
- Length: 200
- Purpose alignment: Critical — but currently teaches the wrong stack.
- Stack drift: **Pervasive.** This is the worst drift in the skill set.
  - `:3` description: "RabbitMQ + MassTransit topology" — drift.
  - `:9, 21, 22, 27, 32, 33, 47, 54, 55, 68, 74, 83, 85, 102, 105, 109, 125, 128, 193`: every reference uses MassTransit terminology, types (`IConsumer<T>`, `MassTransitStateMachine<TState>`, `Fault<T>`), registration (`AddMassTransit`, `AddEntityFrameworkOutbox`), and conventions.
  - The stack uses **Wolverine** (per audit prompt) — Wolverine has different handler discovery (`Handle()` by convention, no `IConsumer<T>`), different outbox API (`UseDurableOutboxOnAllSendingEndpoints`, transactional middleware), different saga shape (Wolverine sagas use `[StateAction]` attributes, not `MassTransitStateMachine`). Cross-reference: `observability-backend:228–262` already wires Wolverine middleware (`AddSource("Wolverine")`, `TracePropagationOutgoingMiddleware : IOutgoingMiddleware`) — *it knows the stack uses Wolverine*. The two skills contradict.
  - CLAUDE.md `:39` reinforces the drift: "RabbitMQ, MassTransit, MediatR, Hangfire."
- Scope overlap: 
  - The "Message Taxonomy" table at `:14–24` is excellent and the right home for it. Keep that — but rename "MassTransit" to "Wolverine" entries.
  - In-process MediatR rules (`:77–82`) duplicate `csharp-clean-arch:88–106` — recommend `csharp-clean-arch` owns the marker interfaces and this skill cross-references.
- Bloat: Some — `ValidationBehavior` snippet (`:150–166`) probably belongs in `csharp-clean-arch` if anywhere.
- Over-prescription: "Default delivery is at-least-once. Every consumer must be idempotent." (`:63`) — appropriately rigid. Good.
- Missing rules: Once corrected to Wolverine:
  - Wolverine outbox tx coordination across sagas.
  - Wolverine handler-method discovery rules (single-method or `Handle`/`Handles`).
  - Hangfire ↔ Wolverine boundary (when to use which) — partially present at `:91–99`.
- Cross-skill consistency: Loaded by every other backend skill — drift here propagates.
- CI enforceability: "No direct `Publish` outside outbox" — Roslyn-checkable but currently anchored on `IPublishEndpoint` (MassTransit). Will need rewrite for Wolverine `IMessageBus`.
- Description routing: Description doesn't say "Wolverine" — that's the loadable token a model would key on. Once corrected, will load on the right keywords.
- Recommended actions (prioritized — HIGHEST):
  1. **Full rewrite to Wolverine.** Replace `IConsumer<T>` → Wolverine handler shapes; `AddMassTransit` → `UseWolverine`; `AddEntityFrameworkOutbox` → Wolverine durable outbox; `MassTransitStateMachine` → Wolverine sagas. Keep the Message Taxonomy and outbox concept structure — only the *implementation* changes.
  2. Update CLAUDE.md `:39` to read `RabbitMQ, Wolverine, MediatR, Hangfire`.
  3. Update description frontmatter to load on Wolverine keywords.
  4. Coordinate update with all dependent skills: `csharp-clean-arch`, `file-storage-patterns`, `elasticsearch-patterns`, `redis-patterns`, `workflow-patterns`, `observability-backend` (already Wolverine), `design-code-review`.

### nextjs-patterns
- Length: 190
- Purpose alignment: Yes — Next.js App Router for the customer portal.
- Stack drift: 
  - NextAuth v5 + Server Actions + ISR — current.
  - "Keycloak provider (v2) or Firebase provider (v1)" (`:80`) — Firebase appears as a v1 fallback. CLAUDE.md `:41` lists "Firebase/Keycloak" but `auth-patterns` says Keycloak only. Pick the truth and align all three. (Audit assumes Keycloak is current; Firebase is legacy.)
  - Strapi v2 — verify (Strapi v5 was current as of 2026; "v2" may be a project-internal CMS instance version, not Strapi major version). Mark "verify."
- Scope overlap: 
  - Auth section (`:75–82`) cross-references `auth-patterns`. Good.
  - Performance rules overlap slightly with `react-component-patterns` re memo/`useMemo`. Acceptable.
- Bloat: None.
- Over-prescription: "Never use `<Head>` from `next/head`" (`:69`) — correct for App Router; rigid; acceptable.
- Missing rules:
  - No mention of Next.js OpenTelemetry integration (covered in `observability-frontend` — fine).
  - No mention of `traceparent` propagation through Server Actions to BFF.
  - No idempotency-key rule for Server Actions calling BFF/services.
- Cross-skill consistency: Cross-references `frontend-design-system`, `auth-patterns`, `react-admin-patterns`, `react-native-patterns`, `bff-patterns`. Good graph.
- CI enforceability: "Always set `width`/`height`/`fill` on `next/image`" (`:97`) — ESLint plugin exists.
- Description routing: SHOULD-load: "implement the listing detail SSR page", "add a Server Action for save listing", "configure ISR on the search route". SHOULD-NOT: "implement the admin SPA route", "build the React Native swipe gesture."
- Recommended actions (prioritized):
  1. Resolve Firebase vs Keycloak truth-claim with `auth-patterns` and CLAUDE.md.
  2. Verify Strapi version label.
  3. Add idempotency-key forwarding rule for Server Actions calling BFF.

### observability-contracts
- Length: 205
- Purpose alignment: Excellent. Single source of truth for the seams.
- Stack drift: None — OTel + Sentry SDKs + GlitchTip + Loki/Jaeger/Prometheus + W3C trace context. All current.
- Scope overlap: This is the contract; the three implementation skills reference it. Clean.
- Bloat: None — all contract.
- Over-prescription: Loki label allow-list (`:151–169`) is rigidly enforced — appropriately. Has its own banner comment requirement.
- Missing rules:
  - No statement on `service.namespace` for the 13 bounded contexts (what's the canonical value? `marketplace`? `directory`? `csharp-clean-arch:25` uses `Listing.Application.*` namespace; `observability-backend:107` uses `serviceNamespace: "marketplace"`). Pick a canonical scheme.
  - No statement on attribute conflicts between OTel semconv and project conventions.
- Cross-skill consistency: Used by all three implementation skills. Consistent.
- CI enforceability: "Every service emits service.name + deployment.environment" — startup-check, mechanically enforceable.
- Description routing: Routes correctly via "any observability work."
- Recommended actions (prioritized):
  1. Add a one-line canonical `service.namespace` mapping for the 13 bounded contexts.
  2. None other.

### observability-backend
- Length: 349
- Purpose alignment: Yes — .NET implementation of contracts.
- Stack drift: 
  - References Wolverine middleware — correctly anticipates the stack (`:228–262`). This is the *correct* skill.
  - `:42` "Sentry .NET" — current.
  - `:34` Serilog OTel sink — current.
- Scope overlap: 
  - PII destructuring policy (`:194–223`) duplicates the deny-list from `observability-contracts:135–148`. Necessary — implementation reads contract list. Acceptable.
  - `MassTransit` source added (`:120`) alongside Wolverine — MassTransit is included in trace sources but the stack uses Wolverine. Either both are present (transitional) or only Wolverine — clarify.
- Bloat: 
  - Full `Program.cs` startup (`:84–166`) — heavy. Belongs in `src/Shared.Observability/Hosting/`. Keep contracts (required ConfigMap fields, sampler interface, `LoggingLevelSwitch` pattern); reference path for the wiring code.
  - `RuntimeRatioSampler` (`:170–191`), `PiiDestructuringPolicy` (`:194–223`), Wolverine middlewares (`:227–262`), Hangfire filter (`:265–305`) are all infra implementation. **All belong in `src/Shared.Observability/`**, referenced by path.
- Over-prescription: "Fail fast on missing config" (`:38–43`) — correctly rigid. Good.
- Missing rules: None observed.
- Cross-skill consistency: Aligned with `observability-contracts`.
- CI enforceability: Some startup checks; in-process redaction mandated.
- Description routing: Precise.
- Recommended actions (prioritized):
  1. Move ~70% of the inline code (`Program.cs`, `RuntimeRatioSampler`, `PiiDestructuringPolicy`, Wolverine middlewares, Hangfire filter) to `src/Shared.Observability/` referenced by path. Keep contracts (required fields, public surfaces).
  2. Resolve MassTransit-vs-Wolverine source registration (`:120`) — pick canonical.

### observability-frontend
- Length: 450 (second-largest)
- Purpose alignment: Yes — three frontends + BFF runtime-config endpoint.
- Stack drift: None — OTel JS, Sentry, PostHog, Clarity, RN equivalents. All current. Verified SDK runtime-mutability matrix at `:118–127`.
- Scope overlap: BFF endpoint implementation duplicates BFF concerns from `bff-patterns` — but this is the runtime-config endpoint specifically, owned here. Acceptable.
- Bloat:
  - The four full bootstrap implementations (Next.js `:158–294`, Vite `:298–331`, RN `:334–379`) are heavy.
  - Recommend: keep one canonical example (Next.js — most complex), reference path for the other two with one-line config differences.
  - `piiScrub` implementation (`:382–411`) is shared infra — `packages/observability-shared/src/pii.ts` reference is correct, but the full source is embedded. Keep contract (deny-list, function signature); move impl to package.
- Over-prescription: "Failure mode is OFF" (`:31–38`) — appropriately rigid.
- Missing rules: 
  - No source-map upload command examples (just "use sentry-cli" — could specify the exact build hook).
  - No statement on PostHog feature-flag usage if the BFF uses it (mentioned in `:432` future-proofing as a consideration).
- Cross-skill consistency: Aligned with `observability-contracts`.
- CI enforceability: "Source maps uploaded on every release" — checkable in CI.
- Description routing: Precise.
- Recommended actions (prioritized):
  1. Move ~50% of inline code to `packages/observability-shared/` and `apps/{portal,admin,mobile}/src/observability/` references. Keep contracts.
  2. None other — this is a strong skill structurally.

### observability-infra
- Length: 268
- Purpose alignment: Yes — collector, Loki, Jaeger, Prometheus, GlitchTip.
- Stack drift: None.
- Scope overlap: Owns deployment alone. Backend swap section at `:222–243` cleanly demarcates ADR-level decisions.
- Bloat: The full canonical `otel-collector-config.yaml` at `:108–206` is appropriate — *that's the artifact this skill owns*. Keep.
- Over-prescription: "Pre-prod and prod must run byte-identical configs" (`:34`) — rigid; ADR-justified.
- Missing rules: None observed.
- Cross-skill consistency: Aligned with `observability-contracts` deny-list at `:135–157`.
- CI enforceability: "Loki labels are exactly service/env/level" — config-file-checkable.
- Description routing: Precise.
- Recommended actions: none of substance.

### observability-patterns (legacy folder, no SKILL.md)
- Status: SKILL.md archived 2026-04-29 per `.archive/ARCHIVE_LOG.md:82–86`. Folder still exists empty.
- Recommended action: Archive the empty folder (use `bash .claude/hooks/archive-file.sh`). Tooling that walks `.claude/skills/*/` may emit warnings.

### postgresql-patterns
- Length: 216
- Purpose alignment: Yes.
- Stack drift: None. EF Core + Dapper + PostGIS + JSONB + RLS are all current.
- Scope overlap: 
  - CQRS data access table (`:14–28`) — same content as `csharp-clean-arch:115–127`. Both reference each other; acceptable but verify they don't drift.
  - `ITenantContext` interceptor (`:117–151`) overlaps with `auth-patterns:459–500` `IUserContext`. Recommend reconciling names — see `auth-patterns` action #3.
- Bloat: 
  - `TenantConnectionInterceptor` impl (`:127–146`) — infra code; could be `src/Shared.Persistence/` reference.
- Over-prescription: 
  - "Never modify existing migrations after applied" (`:114`) — rigid; correct.
  - "Use `BIGINT GENERATED ALWAYS AS IDENTITY` as default" (`:30`) — rigid; could soften with "use UUID v7 for entities exposed in URLs" (already covered).
- Missing rules:
  - No statement on connection-string-vs-RLS interaction with PgBouncer transaction pooling (briefly mentioned at `:149` but not full guidance).
  - No statement on extension management (PostGIS, pg_partman) — partial at `:73, 87`.
- Cross-skill consistency: Cross-references `csharp-clean-arch`, `elasticsearch-patterns`, `redis-patterns`, `auth-patterns`. Good graph.
- CI enforceability: "No `VARCHAR(n)` / `TIMESTAMP` / `MONEY`" — grep-checkable on migrations.
- Description routing: Precise.
- Recommended actions (prioritized):
  1. Reconcile `ITenantContext` naming with `auth-patterns` (`IUserContext`).
  2. Move `TenantConnectionInterceptor` impl to `src/Shared.Persistence/` reference.

### react-admin-patterns
- Length: 181
- Purpose alignment: Yes.
- Stack drift: 
  - Tanstack Router file-based routing — current.
  - TanStack Query — current.
  - keycloak-js direct integration (`:81–87`) — verify against any project standard for OIDC PKCE flow. `auth-patterns` doesn't address SPA OIDC at all. (See Cross-skill A — `auth-patterns` lacks SPA OIDC content; either add there or keep here with a clearer cross-reference.)
- Scope overlap: 
  - View transitions (`:89–95`) is unique here — appropriate.
  - Bundle optimization (`:67–73`) overlaps with `nextjs-patterns:97–106` performance section. Both are correct — different stacks.
- Bloat: None.
- Over-prescription: "No `useEffect` for fetching" (`:53`) — appropriately rigid for TanStack Query stack.
- Missing rules:
  - No accessibility rules (refer to `accessibility-standards` — implicit).
  - No observability instrumentation hook in API client (refer to `observability-frontend`).
- Cross-skill consistency: Cross-references `nextjs-patterns`, `react-native-patterns`, `frontend-design-system`. Good.
- CI enforceability: "Bundle size < 250KB" (`:72`) — measurable in CI.
- Description routing: Precise.
- Recommended actions:
  1. Add explicit references to `accessibility-standards` and `observability-frontend` in "When to Use" or relevant sections.
  2. Coordinate Keycloak-JS section with `auth-patterns` to clarify the SPA OIDC flow ownership.

### react-component-patterns
- Length: 198
- Purpose alignment: Yes.
- Stack drift: None — react-hook-form + Zod are current.
- Scope overlap: Form rules overlap with `frontend-design-system:95–96` and `accessibility-standards:81–90`. Recommend this skill owns Form structure; others cross-reference.
- Bloat: None.
- Over-prescription: "Never use `useState` for form state" (`:79`) — rigid; appropriate.
- Missing rules: None observed.
- Cross-skill consistency: Good.
- CI enforceability: TypeScript prop interfaces — type-checkable.
- Description routing: Precise.
- Recommended actions: none.

### react-native-patterns
- Length: 162
- Purpose alignment: Yes — vendor mobile.
- Stack drift: 
  - Expo managed workflow + NativeWind v5 + Reanimated 3 + FlashList + Expo Router — all current.
  - "expo@latest SDK" (`:18`) — flexible; acceptable.
- Scope overlap: List rendering rules unique here.
- Bloat: None.
- Over-prescription: "Always use `FlashList`" (`:21`) — rigid; appropriate.
- Missing rules:
  - **No accessibility section.** `accessibility-standards` says "see react-native-patterns" but this skill has zero a11y content. Add: `accessibilityLabel`, `accessibilityRole`, `accessibilityHint`, `accessibilityState`, focus management with `AccessibilityInfo`, screen reader announcements via `AccessibilityInfo.announceForAccessibility`.
  - No deep-link handling beyond schema mention (`:42`).
  - No offline-storage-of-tokens rule beyond `expo-secure-store` mention (`:74`).
  - No observability cross-reference (covered by `observability-frontend`).
- Cross-skill consistency: Good.
- CI enforceability: "No `console.log` in production" — grep-checkable.
- Description routing: Precise.
- Recommended actions (prioritized):
  1. **Add accessibility section** matching the cross-reference promised by `accessibility-standards`.
  2. Add observability cross-reference one-liner.

### redis-patterns
- Length: 250
- Purpose alignment: Yes — caching, sessions, rate-limit, locks.
- Stack drift: 
  - StackExchange.Redis primary/replica/sentinel — current.
  - `RedLock.net` reference (`:108`) — current.
- Scope overlap: 
  - Cache-aside as decorator over `IListingReadRepository` (`:142–202`) is the canonical home — good. Cross-references `csharp-clean-arch` correctly.
  - Rate-limit key (`:55`) consistent with `fastendpoints-patterns:160–174`.
  - Idempotency key (`:55`) consistent with `fastendpoints-patterns:255`.
- Bloat: 
  - Full `CachedListingReadRepository` impl (`:160–202`) is illustrative — acceptable as a pattern.
  - Singleton registration boilerplate (`:130–140`) — could be `src/Shared.Redis/` reference.
- Over-prescription: "Every key MUST have a TTL" (`:79`) — rigid; correct.
- Missing rules:
  - No statement on Redis cluster-mode (vs sentinel) — sentinel is stated as the topology; OK.
  - No mention of Redis Streams (used elsewhere?). Likely not in scope.
  - No coordinator for "which Redis logical DB does what" (`:106` mentions DB 0–15 but doesn't enumerate).
- Cross-skill consistency: References `csharp-clean-arch`, `elasticsearch-patterns`, `messaging-patterns`. Good.
- CI enforceability: "No key without TTL" — Roslyn-checkable for `StringSetAsync` calls without `expiry`.
- Description routing: Precise.
- Recommended actions:
  1. Move singleton registration to path reference.
  2. Add canonical "logical DB allocation" table (DB 0=session, 1=cache, 2=rate-limit, 3=idempotency, 4=locks).

### workflow-patterns
- Length: 166
- Purpose alignment: Yes — Elsa v3.
- Stack drift: 
  - Elsa v3 embedded — current.
  - References MassTransit at `:29` ("Activities never call ... `MassTransit IPublishEndpoint`") — the *rule* is right (no direct broker calls from activities); the *vehicle name* is MassTransit. Update when `messaging-patterns` migrates.
- Scope overlap: 
  - Workflow-vs-saga decision is in `file-storage-patterns:44` and here at `:163` (When NOT to use). Consistent.
- Bloat: None.
- Over-prescription: "Activities dispatch through MediatR — never call repos directly" (`:23`) — rigid; correct.
- Missing rules:
  - No statement on Elsa Studio dashboard auth (mentioned at `:17` but not policy).
  - No `traceparent` propagation through workflow bookmarks.
- Cross-skill consistency: Good.
- CI enforceability: "Activities don't inject DbContext" — Roslyn-checkable.
- Description routing: Precise.
- Recommended actions:
  1. Replace MassTransit reference at `:29` once `messaging-patterns` migrates.
  2. Add traceparent-across-bookmark rule cross-referencing `observability-backend`.

### zustand-state-management
- Length: 171
- Purpose alignment: Yes.
- Stack drift: 
  - Zustand v5 — current.
  - "React 18–19, TypeScript 5+" (`:9`) — current.
  - "Firebase token validation" mention (`:163`) — drift consistent with auth-patterns confusion. Replace with Keycloak or remove.
- Scope overlap: Theme persist (`:78–102`) overlaps with `frontend-design-system:191–207` toggle. Coordinate via cross-reference (see `frontend-design-system` action #1).
- Bloat: None.
- Over-prescription: "Double parentheses syntax mandatory" (`:18–28`) — rigid; correct for v5+TS5.
- Missing rules: None observed.
- Cross-skill consistency: Good.
- CI enforceability: "No `const store = useStore()`" — ESLint-rule-able.
- Description routing: Precise.
- Recommended actions:
  1. Remove Firebase reference at `:163` (or reconcile with `auth-patterns`).

### standards
- Length: 9
- Purpose alignment: Pointer skill — specifies "load only the file you need."
- Recommended actions: none.

### system-context, service-registry, domain-model, architecture-decisions
- Length: 8–9 each
- All identical pointer-skill pattern. Consistent.
- Recommended actions: none.

### governance/checkpoint-rules.md and governance/quality-gates.md
- Not skills (no SKILL.md frontmatter). Loaded by `sk.design`, `sk.plan`, `sk.impact`, `sk.ff`, `sk.verify` via `inject_files`.
- Quality-gates.md correctly references DDIA-derived gates (consistency declaration, idempotency-key, outbox).
- One concern: quality-gates.md `:36–39` references "messaging_context = true" / "if outbox in use" — the gates themselves are stack-neutral; good.
- Recommended actions: none.

### sk.adr, sk.design, sk.ff, sk.hotfix, sk.impact, sk.implement, sk.init, sk.investigate, sk.knowledge-base, sk.migrate, sk.perf, sk.phr, sk.plan, sk.refactor, sk.review, sk.rollback, sk.security-audit, sk.session, sk.ship, sk.story, sk.test, sk.uat, sk.verify

These are orchestration skills (subagent_type frontmatter, prompt.md sibling). All under 25 lines. Audit dimensions per skill:

- **Length**: All correctly minimal (10–24 lines). The verbosity is in `prompt.md` siblings (not audited line-by-line per audit scope).
- **Purpose alignment**: Each names a distinct lifecycle phase. No two duplicate each other's job.
- **Stack drift**: 
  - `sk.implement/SKILL.md:4` declares `subagent_type: SpecKit Backend Engineer Agent` regardless of role — but the description says "Role: backend or frontend (required — determines agent)". The frontmatter and the description contradict — frontmatter is fixed at backend, but description claims runtime role-switching. Same pattern in `sk.review`, `sk.refactor`, `sk.investigate`, `sk.perf`. Either the frontmatter is the default-and-overridable, or the description is aspirational. Clarify.
  - `sk.migrate/SKILL.md:7` injects `.claude/skills/postgresql-patterns/SKILL.md` directly. Good — explicit dependency. (Other `sk.*` skills don't inject pattern skills, relying on the agent to load via routing.)
  - `sk.test/SKILL.md:4` `subagent_type: QA Backend Agent` but description says backend or frontend. Same issue.
  - `sk.uat/SKILL.md:4` `subagent_type: QA Frontend Agent` matches the frontend-only scope. Consistent.
- **Scope overlap**:
  - `sk.story` and `sk.ff` both invoke `sk.specify`/`sk.clarify`. `sk.ff` is the orchestrator-of-orchestrators. Acceptable.
  - `sk.refactor` and `sk.implement` both write `src/**`. Boundary is whether spec artifacts exist. Clear.
  - `sk.hotfix` and `sk.implement` overlap; hotfix bypasses sk.design. Clear.
- **Bloat**: None — all minimal.
- **Over-prescription**: Preconditions on `sk.ship`, `sk.rollback`, `sk.migrate` are appropriate hard gates.
- **Missing rules**: 
  - `sk.review/SKILL.md:6` injects `coding-standards.md` and `observability-standards.md` but **does not** inject the matching pattern skills (`csharp-clean-arch`, `fastendpoints-patterns`, `design-code-review`). The review agent must load these via description routing — risk of inconsistent loading. Recommend explicit `inject_files` for `csharp-clean-arch/SKILL.md` + `fastendpoints-patterns/SKILL.md` + `design-code-review/SKILL.md` for backend reviews.
  - `sk.implement` similarly does not inject the implementation pattern skills.
  - `sk.test` doesn't inject any test-relevant patterns.
- **Cross-skill consistency**: All use the same prompt.md indirection pattern. Consistent.
- **CI enforceability**: Rubrics on `sk.story`, `sk.test`, `sk.security-audit` are checkable.
- **Description routing**: All start with "Invoke when:" pattern. Good.
- **Recommended actions** (across sk.* skills):
  1. Reconcile fixed `subagent_type` vs role-switching description in `sk.implement`, `sk.review`, `sk.refactor`, `sk.investigate`, `sk.perf`, `sk.test`. Either declare two skills (sk.implement.backend / sk.implement.frontend) or document the dispatch mechanism.
  2. Add explicit `inject_files` for relevant pattern skills in `sk.implement`, `sk.review`, `sk.refactor`, `sk.test`. Without this, the orchestration relies on description-routing — possibly correct in practice but fragile.

---

## Cross-skill reports

### A. Missing skills

1. **`bounded-context-patterns` — REQUIRED.** Referenced 6× in `csharp-clean-arch` (`:12, 27, 85, 159, 383`). What it should contain:
   - Project layout for the 13 bounded contexts (`{Context}.Domain` / `.Application` / `.Infrastructure` / `.Api` per BC).
   - `Shared.Contracts/` versioned integration event ownership and folder structure.
   - Modular monolith → microservices migration rules (one host vs many).
   - Schema ownership (one schema per BC; never modify another BC's schema).
   - Cross-context call rules (no direct DB access; HTTP through BFF or async events).
   - Naming canonicalization (bounded context = service = module — see drift D).
   - Without this skill: AI-generated code will create cross-BC DB queries, share aggregates, or place events in the wrong project.

2. **No other missing skills.** The listed candidates from the audit prompt — `messaging-patterns`, `redis-patterns`, `auth-patterns`, `elasticsearch-patterns`, `workflow-patterns`, `bff-patterns` — all exist.

### B. Skills to split

1. **`design-code-review`** is doing two jobs: (a) backend-design checklist (mostly duplicating `csharp-clean-arch`); (b) PR-review process. Split into:
   - `design-code-review` → keep as a **review-process** skill; delegate rule definitions to `csharp-clean-arch` / `fastendpoints-patterns` / `auth-patterns` via "review against [skill] §[section]" pointers.
   - The review-process content is small enough (~50 lines) that it might also fold into `sk.review/prompt.md` — assess.

2. **`auth-patterns`** at 547 lines is doing four jobs:
   - Keycloak JWT validation (could live in a leaner `auth-patterns` skill).
   - RBAC policy registry (could be a sub-section).
   - ABAC handler shape (could be a sub-section).
   - **BFF-propagation + dual-caller support** (`:374–501`, ~130 lines) — this overlaps so heavily with `bff-patterns:60–109` that it should split into `auth-propagation-patterns` (or merge fully into `bff-patterns`). Pick one home.

### C. Skills to merge

1. None mandatory. Consider:
   - The four `system-context` / `service-registry` / `domain-model` / `architecture-decisions` pointer skills are each 8–9 lines and identical in shape. Merging into one `memory-pointers` skill would be cleaner — but the description-routing per skill is what makes them load correctly when needed, so keep separate.

### D. Convention drift

1. **Terminology: bounded context vs module vs service.**
   - `csharp-clean-arch:5` "one bounded context"
   - `csharp-clean-arch:69` "bounded context"
   - CLAUDE.md `:7` "multi-service systems"
   - `messaging-patterns:21` "Cross-service"
   - `bff-patterns:24` "more than one backend service"
   - In a modular monolith with future microservices, "bounded context" and "service" are *not yet* the same. Pick one canonical term per phase and document the mapping. Recommend `bounded-context-patterns` (when created) defines this.

2. **Comment markers — no canonical reference.**
   - `// AUTH: Anonymous — REASON:` (`fastendpoints-patterns:128`)
   - `// ENDPOINT: Untyped — REASON:` (`fastendpoints-patterns:39`)
   - `// STREAM: <reason>` (`fastendpoints-patterns:435`)
   - `// IDEMPOTENCY: Not required — REASON:` (`fastendpoints-patterns:436`)
   - Audit prompt mentions `// MARKER: <reason>` as an "escape hatch used elsewhere" — *no skill uses this exact name.*
   - Recommend a one-page "Comment markers" reference (could live in `csharp-clean-arch` as a section, or in a tiny new skill / governance doc) listing every marker, its exact format, where it's enforced, and what manifest CI generates from it.

3. **PII deny-list — duplicated three times.**
   - `observability-contracts:135–148` (canonical)
   - `observability-backend:197–203` (HashSet literal in C#)
   - `observability-frontend:384–389` (Set literal in TS)
   - `observability-infra:138–157` (collector YAML)
   - This is *defense-in-depth* by design (per `observability-contracts:131–134`), so duplication is intentional. But: if the canonical list changes, four files must be updated. Recommend a generated-from-source approach (script generates the C# / TS / YAML constants from a single source) or a CI rule that diffs them and fails on mismatch.

4. **Service naming — `directory-prod` vs `marketplace` vs `directory`.**
   - `auth-patterns:38` — `https://auth.example.com/realms/directory-prod`
   - `auth-patterns:354` — `/realms/directory/protocol/...`
   - `csharp-clean-arch:25` — `Listing.Application.*`
   - `observability-backend:107` — `serviceNamespace: "marketplace"`
   - `observability-contracts:31` — `service.namespace = marketplace` example
   - Pick one canonical project-level namespace (`marketplace` or `directory`). Reflect in all skills.

5. **`IUserContext` vs `ITenantContext`.**
   - `auth-patterns:464` — `IUserContext { UserId, TenantId, Roles, IsViaM2M }`
   - `postgresql-patterns:128` — `ITenantContext` with `TenantId` only
   - Either rename to `IUserContext` everywhere (and have `IUserContext.TenantId` flow into the connection interceptor), or keep two interfaces with clearly distinct purposes documented in both skills.

6. **`Result<T>` library/pattern — Ardalis vs in-house.**
   - `csharp-clean-arch:153` — "Ardalis.Result is the chosen library"
   - `auth-patterns:283` — `Result.Failure(new ForbiddenError("..."))` — the `new ForbiddenError(...)` shape doesn't match Ardalis.Result API; Ardalis uses `Result.Forbidden()` / `.Invalid(...)`. Drift between skills.
   - `fastendpoints-patterns:132–146` — uses `ResultStatus` mapping, consistent with Ardalis.
   - Verify and align `auth-patterns` examples to Ardalis.Result API.

### E. Reference graph (incoming/outgoing)

Outgoing (X references Y):
- `csharp-clean-arch` → bounded-context-patterns (BROKEN — skill missing), fastendpoints-patterns, messaging-patterns, redis-patterns, elasticsearch-patterns, observability-backend, bff-patterns, workflow-patterns
- `fastendpoints-patterns` → csharp-clean-arch, auth-patterns, observability-backend, messaging-patterns, redis-patterns, file-storage-patterns
- `messaging-patterns` → csharp-clean-arch, workflow-patterns
- `auth-patterns` → nextjs-patterns, react-admin-patterns, react-native-patterns
- `bff-patterns` → auth-patterns
- `redis-patterns` → csharp-clean-arch, elasticsearch-patterns, messaging-patterns
- `elasticsearch-patterns` → csharp-clean-arch, postgresql-patterns, messaging-patterns
- `postgresql-patterns` → csharp-clean-arch, elasticsearch-patterns, redis-patterns, auth-patterns
- `file-storage-patterns` → messaging-patterns, csharp-clean-arch, workflow-patterns
- `workflow-patterns` → csharp-clean-arch, messaging-patterns
- `nextjs-patterns` → auth-patterns, react-admin-patterns, react-native-patterns, bff-patterns, frontend-design-system, react-component-patterns
- `react-admin-patterns` → nextjs-patterns, react-native-patterns
- `react-component-patterns` → react-native-patterns, frontend-design-system, zustand-state-management
- `react-native-patterns` → nextjs-patterns, react-admin-patterns
- `frontend-design-system` → react-component-patterns, react-native-patterns
- `zustand-state-management` → (none)
- `accessibility-standards` → react-component-patterns, nextjs-patterns, react-native-patterns (last is BROKEN — react-native-patterns has no a11y section)
- `observability-backend` → observability-contracts, auth-patterns
- `observability-frontend` → observability-contracts, bff-patterns
- `observability-infra` → observability-contracts
- `observability-contracts` → design-principles

**Broken references:**
1. `csharp-clean-arch` → `bounded-context-patterns` — skill missing.
2. `accessibility-standards` → `react-native-patterns` (a11y section) — section missing.

**Missing references that should exist:**
1. `bff-patterns` should reference `observability-contracts` for `traceparent` propagation.
2. `nextjs-patterns` should reference `observability-frontend` (it doesn't — only mentions Sentry indirectly).
3. `workflow-patterns` should reference `observability-backend` for trace context across bookmarks.
4. `elasticsearch-patterns` should reference `observability-backend` for indexer consumer trace propagation.
5. `react-native-patterns` should reference `accessibility-standards` and `observability-frontend`.
6. `design-code-review` should reference `csharp-clean-arch`, `fastendpoints-patterns`, `auth-patterns` instead of duplicating their rules.

**Circular references:** None observed.

---

## Open questions for the user

1. **Wolverine vs MassTransit migration status.** `observability-backend:228–262` already wires Wolverine middleware. `messaging-patterns` is entirely MassTransit. CLAUDE.md `:39` says MassTransit. Has the Wolverine migration started? Is `messaging-patterns` in transition (then we should mark drift but plan the rewrite as scheduled) or stale (then rewrite immediately)? `csharp-clean-arch:90` says "MediatR is the current dispatcher; Wolverine swap survives the marker interfaces" — implying MediatR is in-process and Wolverine would replace it for messaging, not MediatR? Clarify the target architecture.

2. **`bounded-context-patterns` — should we author it?** `csharp-clean-arch` references it 6×. It's a real gap. Confirm this should be created (vs inlining the content in `csharp-clean-arch`).

3. **Firebase auth — legacy or removed?** `nextjs-patterns:80` mentions Firebase as a v1 fallback; CLAUDE.md `:41` says "Firebase/Keycloak"; `auth-patterns` is Keycloak-only; `zustand-state-management:163` mentions Firebase. If Firebase is fully removed, scrub all four. If retained as a legacy mode, document the migration path explicitly.

4. **Strapi version.** `nextjs-patterns:84` says "Strapi v2" — is this a project-internal version or a Strapi major version? (Strapi v5 is the current Strapi major as of late 2025.)

5. **MVC controllers in examples.** `auth-patterns` and `file-storage-patterns` have controller-shaped examples. Confirm: rewrite to FastEndpoints? Or are some legacy services still on MVC?

6. **`IUserContext` vs `ITenantContext` canonical naming.** Pick one — I see both with overlapping responsibilities.

7. **Comment markers — single canonical reference?** Should there be a "Comment markers used by CI" page (or section in `csharp-clean-arch` / `fastendpoints-patterns`) listing every `// AUTH:`, `// ENDPOINT:`, `// STREAM:`, `// IDEMPOTENCY:`, `// CONFIGUREAWAIT:`, etc., with exact formats?

8. **`subagent_type` mismatch in role-switching `sk.*` skills.** Frontmatter declares one agent; description says "role: backend or frontend (required)." How is the dispatch actually working today?

9. **Service namespace canonicalization.** `marketplace` vs `directory` — is the project named one or the other? Multiple skills use both.
