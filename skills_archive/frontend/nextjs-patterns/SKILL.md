---
name: nextjs-patterns
description: "Load when: implementing or reviewing the customer portal (Next.js App Router 15+, NextAuth v5, Strapi v5, Cloudflare R2). Covers Server/Client component boundary, SSR + ISR + tag invalidation, Server Actions, route organisation, SEO, Keycloak-backed sessions, Strapi Document Service, R2 image delivery, and the backend fetch contract (traceparent + Idempotency-Key)."
when_to_load:
  - Any customer-portal feature work (pages, layouts, Server Actions)
  - SEO/CMS routing or preview mode
  - Authenticated page or action — session-aware rendering
  - Outbound fetch to backend services from the portal
  - R2 image rendering or upload presign flow
co_loads_with:
  - frontend-design-system
  - react-component-patterns
  - accessibility-standards
  - observability-frontend
references:
  - authorization-patterns
  - file-pipeline-patterns
  - api-endpoint-patterns
  - observability-backend
---

# Next.js Patterns (App Router 15+, Customer Portal)

## 1. Purpose
Production patterns for the customer-facing portal built on Next.js App Router with TypeScript, NextAuth v5 (Keycloak provider), Strapi v5 CMS, and Cloudflare R2 image delivery. Covers the Server/Client component boundary, fetch caching and tag-based invalidation, Server Actions, SEO, authenticated rendering, CMS preview mode, R2 public/private delivery, and the backend fetch contract every outbound call must satisfy. Excludes: framework wiring (`next.config.js`, NextAuth provider registration, OTel/Sentry/PostHog/Clarity init) — those live in `.specify/memory/observability-stack.md` and deploy docs. Component decomposition lives in `react-component-patterns`; tokens and Tailwind setup live in `frontend-design-system`.

## 2. Core Rules

### 2.1 Server vs Client Components
Server Components are the default. `"use client"` is opt-in and applies to the file plus everything it imports — keep client subtrees shallow.

* Use Server Components for data fetching, layout, static content, and SEO-critical markup. Use Client Components only when you need `useState`, `useEffect`, event handlers, browser APIs, or interactivity.
* Pattern: Server parent fetches → passes serialisable props to Client child. Never pass class instances, Date objects, functions, or non-POJO data across the boundary; serialise to primitives first.
* Never put `"use client"` at layout level — it forces the whole subtree client-rendered and kills RSC benefits.
* Auth checks (`auth()` from NextAuth v5) only resolve in Server Components and Server Actions. Client Components read session via `useSession()` from `next-auth/react`, and that hook returns only the safe public claims — never the raw access token.

| Need | Component type |
|---|---|
| Listing detail page (SEO) | Server |
| Search results with filters | Server (initial) + Client (filter UI) |
| Map / geo search interaction | Client |
| Strapi-driven content page | Server |
| Auth-gated dashboard | Server (with `auth()` guard) |
| Form with validation feedback | Client + Server Action |

### 2.2 Data Fetching & Caching
Three caching modes — pick one per route based on the freshness contract:

| Mode | Call | Use for |
|---|---|---|
| Static (build-time) | `fetch(url, { cache: 'force-cache' })` | CMS content that changes via revalidation |
| ISR (time-revalidated) | `fetch(url, { next: { revalidate: 60 } })` | Listing pages, category indexes |
| Dynamic (per-request) | `fetch(url, { cache: 'no-store' })` | Authenticated dashboards, personalised data |

Tagged fetches are the primary invalidation primitive — declare them on every cacheable read:

```ts
// SSR: server-only — runs at build, ISR, or per-request
async function getListing(id: string) {
  // FETCH: outbound to backend; traceparent + auth attached by serverFetch wrapper
  const res = await serverFetch(`/api/v1/listings/${id}`, {
    next: { revalidate: 60, tags: ['listing', `listing:${id}`] },
  });
  if (!res.ok) notFound();
  return res.json() as Promise<ListingDetailDto>;
}
```

* Deduplicate same-fetch-same-render with `React.cache(fn)`. Required when the same loader is called from a Server Component and its `generateMetadata`.
* Run independent loaders in parallel with `Promise.all` at the Server Component boundary. Never fetch in Client Components — push fetching up to a Server parent or into a Server Action.
* Pass `AbortSignal` from the request when calling slow downstreams so the runtime can cancel on client navigation.
* Never read `cookies()` or `headers()` in a cacheable function; that opts the route into dynamic rendering implicitly. If you need them, make the dynamic intent explicit at the route level.

### 2.3 Server Actions
Server Actions are the only sanctioned mutation path from the portal. Mark with `"use server"`, validate every input with Zod, return a typed discriminated result, and revalidate after success.

```ts
'use server';
import { z } from 'zod';
import { revalidateTag } from 'next/cache';
import { auth } from '@/lib/auth';
import { serverFetch } from '@/lib/server-fetch';

const SaveListing = z.object({ listingId: z.string().uuid() });

export async function saveListingAction(prev: ActionResult, fd: FormData): Promise<ActionResult> {
  // AUTH: server action — mutation must be authenticated
  const session = await auth();
  if (!session) return { ok: false, error: 'UNAUTHENTICATED' };

  const parsed = SaveListing.safeParse({ listingId: fd.get('listingId') });
  if (!parsed.success) return { ok: false, error: 'INVALID_INPUT' };

  // FETCH: mutating call carries Idempotency-Key (key derived from action + user + payload)
  // IDEMPOTENCY: owner: backend-feature-patterns
  const res = await serverFetch('/api/v1/saved-listings', {
    method: 'POST',
    body: JSON.stringify({ listingId: parsed.data.listingId }),
    idempotencyKey: deriveIdempotencyKey('saveListing', session.user.id, parsed.data.listingId),
  });
  if (!res.ok) return { ok: false, error: await translateError(res) };

  // REVALIDATE: invalidate caches that read this user's saved-list
  revalidateTag(`user:${session.user.id}:saved`);
  revalidateTag(`listing:${parsed.data.listingId}`);
  return { ok: true };
}
```

* Pair Server Actions with `useActionState` (React 19) in the Client form — the action returns the discriminated result; the form derives pending / error state from it. Never track pending state with a separate `useState`.
* On success, choose ONE post-action effect: `revalidateTag(...)` (preferred for partial invalidation), `revalidatePath(...)` (whole-route), or `redirect(...)` (navigation). Calling more than one increases coupling and re-fetch surface.
* Server-side validation errors map to field-level errors in the return shape — Client form sets them via `react-hook-form` `setError`. Never throw plain `Error` from a Server Action; throws become opaque framework errors.

### 2.4 Route Organisation
File-based routing with intentional grouping. Pick the right primitive — none of these change URL shape unless you mean to.

* **Route groups `(name)`** — bundle pages with a shared layout (e.g. marketing vs. portal vs. CMS) without leaking the group name into the URL.
* **Parallel routes `@slot`** — independently loadable panels on the same URL (e.g. `@modal` for intercepted modals, `@analytics` for an admin sidebar). Each slot resolves its own loading/error boundary.
* **Intercepting routes `(.)`, `(..)`** — render the same destination URL with a different UI when navigated from within the app (e.g. listing photo as overlay from search results, but full page on direct link).
* **Required files per segment:** `page.tsx` (route), `layout.tsx` (shared chrome), `loading.tsx` (Suspense boundary), `error.tsx` (segment error boundary), `not-found.tsx` (404). Every route with async data needs `loading.tsx`.

```
app/
├── (marketing)/                 # public; no auth
│   ├── page.tsx
│   └── listings/
│       ├── page.tsx             # search + filters
│       └── [id]/
│           ├── page.tsx         # SEO-critical detail
│           └── @modal/(.)photos/[idx]/page.tsx   # intercepted overlay
├── (portal)/                    # authenticated user surface
│   ├── layout.tsx               # auth() guard; redirects to /sign-in
│   └── dashboard/page.tsx
├── (cms)/[...slug]/page.tsx     # Strapi-driven dynamic routes
└── api/auth/[...nextauth]/route.ts
```

### 2.5 SEO & Metadata
* `generateMetadata({ params })` returns the per-page metadata object — never `<Head>` from `next/head` (that's Pages Router). Wrap the same loader the page uses in `React.cache` so the fetch deduplicates.
* Required fields on every public page: `title` (50–60 chars), `description` (150–160 chars), `openGraph.images` with explicit `width`/`height`, `alternates.canonical`.
* Structured data: inject JSON-LD with `<script type="application/ld+json" dangerouslySetInnerHTML={...}>` in the Server Component. Use the Schema.org type that matches the page intent (`Product`, `LocalBusiness`, `Article`).
* Generate `sitemap.xml` and `robots.txt` via `app/sitemap.ts` and `app/robots.ts` — both run on the server and can hit your backend for dynamic entries.
* i18n routes via App Router segment params + `next-intl` for message catalogues. Set `<html lang>` from the segment param in the root layout.

### 2.6 Authentication — NextAuth v5 + Keycloak
NextAuth v5 is the only sanctioned auth library for the portal. The Keycloak provider is configured ONCE in `auth.ts` (wiring — out of scope here). Feature code consumes the exported `auth()`, `signIn()`, `signOut()`, and `handlers` only.

**Session shape (what's in the JWT after Keycloak callback):** the public claim contract — what the backend issues and what the portal can read — is owned by `authorization-patterns`. This skill assumes the session matches that contract:

```ts
// @/lib/auth-types.ts
export type PortalSession = {
  user:  { id: string; email: string; name: string };
  roles: string[];           // realm_access.roles
  tenantId: string;          // custom claim
  expiresAt: number;         // epoch seconds
};
```

* **Page-level guard (Server Component):**
  ```ts
  // SSR: server-only auth gate
  // AUTH: backend also validates on every call
  const session = await auth();
  if (!session) redirect('/sign-in?callbackUrl=' + encodeURIComponent(pathname));
  ```
* **Server Action guard:** call `auth()` at the top, return `{ ok: false, error: 'UNAUTHENTICATED' }` if absent. Never let an unauthenticated action reach `serverFetch` — fail fast.
* **Middleware-level guard** for whole route groups: `middleware.ts` exports `auth` and matches `/(portal)/:path*`. Use this for blanket gates; use per-page `auth()` calls when the rendering depends on the session, not just access.
* **Refresh handling** is owned by the NextAuth `jwt` callback (wiring). Feature code never refreshes manually — if `auth()` returns a session, the access token is fresh; if it returns null, redirect to sign-in.
* **Never** expose the raw `accessToken` to the Client (no passing it as a prop, no putting it in `useSession()` output). The Client receives only safe identity claims; outbound calls happen through Server Components / Server Actions / Route Handlers, which attach the token server-side via `serverFetch`.

### 2.7 Strapi v5 CMS Integration
Strapi v5 runs as a separate service with its own database schema (on the same PG server) and JSON-on-git config. The portal consumes Strapi via the Document Service REST API server-side only.

* All Strapi reads happen in Server Components or Route Handlers — never from Client Components. The Strapi client module imports `server-only` to enforce this at build time.
* **Published vs draft:**
  * Published: fetched without `status`, cached with ISR + tag (`['cms', 'cms:<documentId>']`).
  * Draft preview: route via `/api/preview?token=...&path=...` Route Handler — verifies the token, calls `draftMode().enable()`, redirects to the target path. Fetches downstream check `draftMode().isEnabled` and switch to `status=draft`.
* Document IDs (Strapi v5) are stable string IDs — use them as tag suffixes for revalidation. The legacy numeric `id` is internal and must not be exposed in URLs or tags.
* Webhook-driven invalidation: Strapi → `/api/cms-webhook` Route Handler → verifies shared-secret header → `revalidateTag('cms:<documentId>')`. The route is the ONLY place that trusts the webhook payload; everything downstream re-fetches from Strapi.
* Images referenced from Strapi point at the R2 public bucket (see §2.8) — never inline binary, never proxy through Next.

### 2.8 Cloudflare R2
Two buckets, two delivery paths:

* **Public bucket** — world-readable; serves published images. URLs are stable and versioned by file ID. Render via `next/image` with `remotePatterns` configured (wiring). Always provide `width`/`height` or `fill`; always set `sizes` for responsive images; mark above-the-fold images `priority`.
* **Private bucket** — drafts and user-owned uploads. Access is via short-TTL presigned URLs.
  * **Presigned PUT (upload):** the portal does NOT sign URLs itself. It calls the backend file service to obtain a presigned PUT URL, then `PUT`s the body directly to R2 from the Client. The presign endpoint contract — request shape, returned URL TTL, key derivation — is owned by `file-pipeline-patterns §6`. This skill describes only the portal-side call.
  * **Presigned GET (draft view):** Server Component requests a short-TTL signed URL from the backend, embeds it in the page. Never cache the signed URL beyond its TTL.

```tsx
// SSR: detail page renders signed-GET only on the server
const draftUrl = session ? await getSignedDraftUrl(listing.draftKey) : null;
return <Image src={listing.heroPublicUrl} width={1200} height={630} priority alt={listing.title} />;
```

### 2.9 Backend Fetch Contract
Every outbound call from the portal to a backend service goes through a single `serverFetch` wrapper. The wrapper enforces three contracts; feature code never bypasses it.

1. **Traceparent forwarding** — the wrapper reads the current OTel context and emits a `traceparent` header so backend spans nest under the portal request. Header propagation contract is owned by `observability-backend`.
2. **Authorization** — for user-context calls, the wrapper attaches `Authorization: Bearer <access_token>` from the current NextAuth session. For unauthenticated (CMS, public listing) calls, it omits the header. Never construct the header manually in feature code.
3. **Idempotency-Key on mutations** — every `POST`, `PUT`, `PATCH`, `DELETE` carries an `Idempotency-Key` header. The wrapper requires the caller to supply `idempotencyKey`; if absent, it throws at build-test time. Key derivation rule and server semantics are owned by `api-endpoint-patterns`.

```ts
// @/lib/server-fetch.ts — shape only; full implementation in repo
type Options = RequestInit & {
  next?:           { revalidate?: number; tags?: string[] };
  idempotencyKey?: string;
};

export async function serverFetch(path: string, opts: Options = {}): Promise<Response> {
  const isMutation = opts.method && opts.method !== 'GET';
  if (isMutation && !opts.idempotencyKey) {
    throw new Error('serverFetch: mutating call requires idempotencyKey');
  }
  // FETCH: traceparent, bearer, idempotency-key composed here — never in callers
  const headers = await buildHeaders(opts);
  return fetch(process.env.BACKEND_URL + path, { ...opts, headers });
}
```

* Error translation: 401 → `redirect('/sign-in')` from the call site (the wrapper does not redirect — it returns the response). 403/404/409/422 → typed `ActionResult` error. 5xx and network failures → user-facing "try again" via the route's `error.tsx`.
* Two token modes:
  * **User-session token** (default) — for calls representing the logged-in user. Backend enforces RBAC + ABAC on the user's claims.
  * **M2M token** — for portal-owned background calls (e.g. CMS revalidation webhook handler calling backend to warm a cache). Obtained via client-credentials grant; wiring lives in the M2M token provider module.

### 2.10 Performance
* `next/image` everywhere — never `<img>`. `next/font` for all custom fonts (zero CLS, self-hosted). `next/script` with `strategy="afterInteractive"` for any third-party tag.
* `next/dynamic` (with `ssr: false` only when truly needed) for heavy Client subtrees — map, chart, rich text editor.
* `<Suspense>` boundaries around every independently slow data section so streaming can flush above-the-fold first. Wrap loaders, not whole pages.
* RSC payload hygiene: pass only the props the Client needs. Don't pass full server entities to a Client child — pass a small projected shape. Large RSC payloads tank Time-to-Interactive.
* Avoid client-side waterfalls: parallel-fetch at the Server boundary with `Promise.all`; never chain `useEffect` fetches.
* Bundle: avoid barrel imports from `@/components` — import directly from source files so Next can tree-shake. Audit bundle size in CI; alert on regressions.

## 3. Comment markers

### Owned by this skill
| Marker | Emit on | Semantics |
|---|---|---|
| `// SSR:` | Any function/block that must run server-side (RSC body, route handler, server action) | Asserts server-only execution; CI greps for this when reviewing RSC payload boundaries |
| `// REVALIDATE:` | Every `revalidateTag(...)` or `revalidatePath(...)` call site | Marks the invalidation contract; reviewers and CI verify that every mutation has a paired revalidate |
| `// FETCH:` | Every `serverFetch(...)` call site | Marks an outbound backend call; flags traceparent + auth + idempotency-key responsibilities |

### Used but not owned
| Marker | Owner | Where it appears here |
|---|---|---|
| `// AUTH:` | `authorization-patterns` | Server Component / Server Action authorization checks (§2.3, §2.6) |
| `// IDEMPOTENCY:` | `backend-feature-patterns` | Mutating `serverFetch` call sites that supply `idempotencyKey` (§2.3, §2.9) |
| `// EVENT:` | `observability-frontend` | Portal-side analytics emission (§4) |
| `// MASK:` | `observability-frontend` | PII redaction at telemetry boundary (§4) |
| `// CONSENT:` | `observability-frontend` | Telemetry consent gate (§4) |

## 4. Surface integration for observability-frontend §11
The portal is the landing zone for the frontend observability markers (`// EVENT:`, `// MASK:`, `// CONSENT:` — all owned by `observability-frontend`). This section defines where they attach in Next.js code; emission internals, SDK init, and the PII deny-list live in the owner skill.

* **`// CONSENT:`** — top of the root `layout.tsx` Client subtree (consent provider) and at the entry of any telemetry-emitting hook. The portal must NOT initialise PostHog/Clarity before the consent state resolves; render a no-op telemetry shim until then.
* **`// EVENT:`** — Server Action success branches and meaningful Client interactions (form submit, filter change, listing view). Events fired from Server Actions are queued in the action result and replayed Client-side after navigation — never call the analytics SDK from a Server Action directly.
* **`// MASK:`** — every emit site that touches user-typed strings or backend payloads. The portal applies redaction before handing data to the SDK; the SDK never sees raw email, full name, phone, address, or auth tokens.
* **Error boundary integration** — every `error.tsx` calls the observability sink to report the caught error with the route segment as context. This skill's contract is "every error.tsx emits one report, exactly once"; the sink module is owner territory.

## 5. When to use
* Any customer-portal page, layout, or Server Action (App Router, RSC, NextAuth v5).
* SEO-critical pages: listing detail, category indexes, CMS-driven content.
* Strapi v5 content fetching, preview mode, webhook-driven revalidation.
* Cloudflare R2 image rendering (public) or signed-URL flows (private).
* Any outbound fetch from the portal to a backend service — `serverFetch` contract.

## 6. When NOT to use
* **Admin SPA** (React + Vite + Tanstack Router) — see `react-admin-patterns`.
* **Mobile app** (React Native + Expo) — see `react-native-patterns`.
* **Component decomposition, prop typing, form handling, custom hooks** — see `react-component-patterns`.
* **Tailwind v4 setup, shadcn/ui rules, design tokens, CVA, dark mode** — see `frontend-design-system`.
* **BFF aggregation** — when a screen needs data from 3+ services with cross-cutting concerns, the aggregation belongs in BFF, not in a Next.js Server Component. See `api-endpoint-patterns` for the decision matrix.
* **Backend implementation** — never restate handler, endpoint, validation, or persistence rules here. Cross-ref the owning backend skill instead.
