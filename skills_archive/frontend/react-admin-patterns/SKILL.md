---
name: react-admin-patterns
description: "Load when: implementing or reviewing the internal Admin SPA (React + Vite + Tanstack Router + Tanstack Query + keycloak-js PKCE). Covers project structure, file-based routing, loader-driven prefetch, re-render hygiene, bundle discipline, error boundaries, PKCE authentication with in-memory tokens, the outbound backend fetch contract (traceparent + Idempotency-Key), view transitions, and observability marker placement."
when_to_load:
  - Any Admin SPA route, layout, or feature module
  - Tanstack Router route file or loader work
  - TanStack Query hook authoring or mutation
  - keycloak-js PKCE integration or auth-guarded routes
  - Outbound fetch from the Admin SPA to a backend service
  - Bundle, re-render, or error-boundary review
  - Presigned-upload flows initiated from the Admin SPA
  - Observability marker placement on Admin SPA code
co_loads_with:
  - frontend-design-system
  - react-component-patterns
  - accessibility-standards
  - observability-frontend
references:
  - .specify/memory/auth_contract.md
---

# React Admin SPA Patterns (Vite + Tanstack Router + Tanstack Query)

## 1. Purpose
Production patterns for the internal Admin SPA built with React, Vite, Tanstack Router, TanStack Query, and keycloak-js PKCE. Covers route structure and lazy loading, query-key discipline, loader-driven prefetch, re-render hygiene, bundle splitting, error boundaries, in-memory token handling, the universal backend fetch contract (traceparent + Idempotency-Key), and the marker landing zone for observability. Excludes wiring (Vite config, Tanstack Router instantiation, keycloak-js init, Sentry/PostHog/OTel init) — those live in `.specify/memory/` or deploy docs. Component decomposition, prop typing, form handling, and Tailwind/shadcn rules live in their own skills (see §6).

## 2. Core Rules

### 2.1 Project Structure & Routing
File-based routing with Tanstack Router. One file per route segment under `@/routes/`. Layouts via `_layout.tsx`; route groups via `_groupName` prefix (no URL segment); dynamic segments via `$param`.

```
src/
├── routes/
│   ├── __root.tsx              # Root layout; global error boundary; auth gate via beforeLoad
│   ├── index.tsx               # Dashboard (redirect/landing)
│   ├── listings/
│   │   ├── index.tsx           # List view
│   │   └── $id.tsx             # Detail
│   └── _auth/                  # Group: routes inside require authentication
│       └── settings.tsx
├── features/
│   └── listings/
│       ├── api.ts              # queryOptions + mutations (TanStack Query)
│       ├── components/
│       └── types.ts
├── lib/
│   ├── api-client.ts           # fetch wrapper with traceparent + idempotency + bearer attachment
│   ├── auth.ts                 # keycloak-js instance + AdminSession derivation
│   └── query-client.ts         # QueryClient defaults
├── stores/                     # Zustand stores (cross-route UI state only)
└── components/                 # shadcn-derived UI components
```

* **Lazy route loading**: every non-root route uses Tanstack Router code-splitting (`createLazyFileRoute` or `loader`-based dynamic imports). Never import a route component eagerly from another route.
* **Route context vs loader data**: route `context` holds long-lived dependencies (queryClient, auth) — set once in `__root.tsx`. `loader` returns per-navigation prefetched data. Do not stuff per-navigation data into context.
* **Auth guard belongs in `beforeLoad`**, not `loader`: `beforeLoad` runs before the loader and can throw a `redirect(...)`. Loader assumes auth is settled.
* Use `Link`, `Navigate`, and `useNavigate` from Tanstack Router — never `window.location` or `history.push`.

### 2.2 Data Fetching — TanStack Query
TanStack Query is the only sanctioned data layer. No raw `useEffect + fetch`. No SWR. No Axios global instance — use the `apiFetch` wrapper (§2.8) inside `queryFn`/`mutationFn`.

* **Query keys are typed constants** in `features/{feature}/api.ts`. Never inline key arrays at the call site.
* **`queryOptions(...)` everywhere** — never `useQuery({ queryKey, queryFn })` inline. The same `queryOptions` object feeds both the loader (`ensureQueryData`) and the component (`useQuery`), guaranteeing key parity.
* **Defaults at the `QueryClient`:** `staleTime: 60_000` (60s) for typical reads; `gcTime: 5 * 60_000`; `retry: (failureCount, err) => err.status >= 500 && failureCount < 2` (no retry on 4xx). Reference-data queries override to `staleTime: 5 * 60_000`.
* **Suspense mode** is opt-in per query via `useSuspenseQuery` — required for loader-prefetched data so the component renders synchronously after navigation. Non-loader queries use plain `useQuery` to keep the fallback UX controllable.
* **Mutations invalidate by key prefix**, not by enumerating every related key:
  ```ts
  onSuccess: () => queryClient.invalidateQueries({ queryKey: ['listings'] })
  ```
* **AbortSignal forwarding**: `queryFn: ({ signal }) => apiFetch(path, { signal })`. Required for cancellation on rapid navigation.
* **Optimistic updates**: `onMutate` snapshots previous data, sets next data; `onError` rolls back; `onSettled` invalidates. Use only when the UX benefit justifies the rollback complexity — most admin tables are fine without it.

### 2.3 Loader Prefetch & Parallel Fetch
The loader is where you eliminate waterfalls. A waterfall = component A mounts → fetches → renders → component B mounts → fetches. By the time the route component renders, all data it needs must already be in the query cache.

* **Loader pattern**: `Promise.all` over `queryClient.ensureQueryData(...)` for every query the route component will read. Return nothing (or just whatever needs to be in `Route.useLoaderData()`).
* **Never `await` sequentially** unless the second call genuinely depends on the first's result.
* **Component reads via `useSuspenseQuery`** with the same `queryOptions`. Loader guarantees the data; component renders without loading state.
* **Pagination and infinite-scroll** are the exception: triggered by user action, not on mount — `useInfiniteQuery` handles them; loader prefetches only page 1.
* **Background refresh**: TanStack Query revalidates automatically after `staleTime`; the loader does not need to refetch on every visit.

```tsx
// CSR: route component runs in browser only
// @/routes/listings/$id.tsx
import { createFileRoute } from '@tanstack/react-router';
import { listingQuery, listingActivityQuery } from '@/features/listings/api';

export const Route = createFileRoute('/listings/$id')({
  beforeLoad: ({ context }) => requireAuth(context),
  loader: ({ context: { queryClient }, params }) =>
    Promise.all([
      queryClient.ensureQueryData(listingQuery(params.id)),
      queryClient.ensureQueryData(listingActivityQuery(params.id)),
    ]),
  errorComponent: ListingErrorBoundary,
  pendingComponent: ListingDetailSkeleton,
  component: ListingDetailPage,
});
```

### 2.4 Re-render Hygiene
Re-render bugs in admin tables come from three sources: subscribing to too much state, unstable references, and ignored memoisation contracts.

* **Tanstack Router `useSearch` / `useParams` always with a selector**: `useSearch({ from: '/listings/', select: (s) => s.status })` returns a primitive and subscribes only to that field. Bare `useSearch()` re-renders on any search-param change.
* **TanStack Query `select`**: `useQuery({ ...listingQuery(id), select: (data) => data.title })` — same principle; subscribe to the slice the component renders, not the whole row.
* **Zustand store hygiene is owned by `zustand-state-management`** — selector-form, `useShallow`, and never-subscribe-to-whole-store rules live there. This section does NOT duplicate them; verify against that skill when authoring a store consumer.
* **`React.memo` only at meaningful boundaries**: list row components, expensive chart wrappers, header bars. Wrapping every leaf is anti-value.
* **Stable callbacks via `useCallback`** for props handed to memoised children — without this the memo is defeated by reference inequality on every parent render.
* **No new object/array literals in JSX** when the consumer is memoised: `<Row data={row} className={cn('row', row.active && 'active')} />` is fine; `<Row data={{ ...row, computed: x }} />` re-renders every parent tick.

### 2.5 Bundle Discipline
* **Route-level splitting is automatic** — Tanstack Router lazy routes produce per-route chunks. Do not pre-bundle them via static imports.
* **Vendor chunking**: leave to Vite defaults until a real cohesion problem surfaces (Rollup's `manualChunks` is a last resort, not a default).
* **Direct imports beat barrels**: `import { Button } from '@/components/ui/button'` — never `import { Button } from '@/components'`. Barrel imports break tree-shaking even with side-effect-free flags.
* **Modular library imports**: `import { debounce } from 'lodash-es'` not `import _ from 'lodash'`. Same for `date-fns`, `lucide-react`, `radix-ui` — all already modular when imported by named subpath.
* **Lazy-import heavy features** with `React.lazy` + `Suspense`: maps, charts, rich-text editors, PDF viewers. Anything > 50 KB minified that isn't on the first render path.
* **Bundle budget**: alert when the main entry chunk exceeds 250 KB gzipped. CI runs `vite-bundle-visualizer` (or equivalent) on every PR.

### 2.6 Error Boundaries & Suspense
* **Every route declares `errorComponent`** — never let a render error crash the whole SPA.
* **Global error boundary** in `__root.tsx`'s `errorComponent` catches anything a route boundary misses (e.g. errors during `beforeLoad`).
* **Network errors ≠ render errors**: TanStack Query routes errors into `error` state on the hook; only errors thrown during render reach the route boundary. Don't try to handle both with one boundary.
* **Auth-expired (401)**: handled in the `apiFetch` wrapper (§2.8) — triggers silent refresh, then re-tries or redirects. Never lets a 401 reach an error boundary.
* **Forbidden (403)**: shown as inline UI ("you don't have access"), not a boundary — boundaries are for unexpected failures, 403 is expected.
* **Validation errors (4xx with field details)**: rendered inline on the form, never as a boundary.
* **Suspense placement**: wrap independently-slow data sections, not whole routes. A whole-route Suspense defeats streaming UX; many small Suspense boundaries let UI flush above-the-fold first.

### 2.7 Authentication — keycloak-js PKCE
Universal OAuth 2.1 PKCE flow, applied to the Admin SPA via keycloak-js. The library handles the authorization code exchange, refresh, and silent SSO; the skill describes how the SPA consumes it.

* **PKCE is mandatory**: `keycloak.init({ pkceMethod: 'S256', ... })`. Never the implicit flow; never the password grant.
* **Tokens live in memory only**: keycloak-js holds them on its instance. The SPA never copies them into `localStorage`, `sessionStorage`, or any persisted store. Refresh on reload happens via the OIDC `prompt=none` silent SSO request to Keycloak — not from local storage.
* **Silent refresh**: keycloak-js refreshes the access token in the background before expiry. The SPA's `apiFetch` wrapper (§2.8) calls `keycloak.updateToken(30)` before every request — refreshes if the access token has < 30 s remaining, otherwise no-op.
* **Refresh failure** (refresh token expired / revoked) → redirect to login. `apiFetch` catches the `updateToken` rejection and triggers the redirect; feature code never handles it.
* **Per-route auth guard**: `beforeLoad` checks the keycloak instance and throws `redirect({ to: '/login', search: { from: location.href } })` when unauthenticated. Group routes that need auth under a `_auth` route group with the guard on the group's `beforeLoad`.
* **`AdminSession` shape** (what the SPA actually consumes from the token at the application layer) and **token storage details** for this project live in `.specify/memory/auth_contract.md`. The skill defines the pattern; the memory doc holds the project-specific contract.
* **Role-driven UI** reads roles from the parsed token (`keycloak.tokenParsed?.realm_access?.roles`). Hide/show UI based on roles, but never assume the UI hide is a security control — the backend re-checks on every request.

```ts
// CSR: client-only auth guard wired into route context
// @/routes/__root.tsx — pattern only; full wiring in @/lib/auth
export const Route = createRootRouteWithContext<{ auth: AdminAuth; queryClient: QueryClient }>()({
  beforeLoad: ({ context, location }) => {
    // AUTH: PKCE-validated session; backend re-validates on every fetch
    if (!context.auth.isAuthenticated) {
      throw redirect({ to: '/login', search: { from: location.href } });
    }
  },
  component: RootLayout,
});
```

### 2.8 Backend Fetch Contract
Every outbound call from the SPA to a backend service goes through a single `apiFetch` wrapper. The wrapper enforces three universal contracts; feature code never bypasses it.

* **Authorization header**: attached by the wrapper from the keycloak instance. Feature code never reads the token directly, never builds the header manually.
* **`traceparent` header (W3C Trace Context)**: forwarded on every request. Generated by the OTel JS instrumentation when absent; never built ad-hoc in feature code.
* **`Idempotency-Key` header on mutations**: every `POST`, `PUT`, `PATCH`, `DELETE` carries a UUID v4 that is **stable per user action, NOT per network retry**. The wrapper requires the caller (or the mutation hook) to supply `idempotencyKey`; if absent on a mutating verb, the wrapper throws in development.
* **401 (auth-expired)**: interceptor calls `keycloak.updateToken(0)`; on success retries the original request once; on failure redirects to login. Never surfaces to feature code.
* **403 (forbidden)**: surfaces to feature code as a typed error — render an inline "no access" affordance.
* **5xx and network failures**: surface to feature code as a typed error — TanStack Query's error state renders the UI; the route error boundary catches render-time throws only.

```ts
// @/lib/api-client.ts — shape only; full implementation in repo
export type ApiOptions = RequestInit & {
  signal?:         AbortSignal;
  idempotencyKey?: string;
};

export async function apiFetch(path: string, opts: ApiOptions = {}): Promise<Response> {
  const isMutation = opts.method && opts.method !== 'GET';
  if (isMutation && !opts.idempotencyKey && import.meta.env.DEV) {
    throw new Error('apiFetch: mutating call requires idempotencyKey');
  }
  await keycloak.updateToken(30);
  // FETCH: bearer + traceparent + idempotency-key composed here
  const headers = buildHeaders(opts);
  return fetch(import.meta.env.VITE_API_URL + path, { ...opts, headers });
}
```

```ts
// @/features/listings/api.ts — mutation supplying idempotencyKey
export function useDeactivateListing() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) =>
      // IDEMPOTENCY: one key per user action (generated at hook call site)
      apiFetch(`/api/v1/listings/${id}/deactivate`, {
        method:         'POST',
        idempotencyKey: crypto.randomUUID(),
      }),
    onSuccess: (_, id) => qc.invalidateQueries({ queryKey: ['listings'] }),
  });
}
```

### 2.9 View Transitions
The browser's native View Transition API gives spatial continuity for admin navigation (list → detail, list → filtered list). Tanstack Router supports it via `<Link viewTransition>`.

* **Apply for**: list → detail, detail → list (back), sibling tab switches inside a layout. Not for: background data refreshes, filter changes that don't change route shape.
* **Opt-in per `Link`**: `<Link to="/listings/$id" params={{ id }} viewTransition>`. Don't enable it globally — some routes look worse with transitions.
* **`prefers-reduced-motion`**: the SPA's global CSS sets `@media (prefers-reduced-motion: reduce) { ::view-transition-group(*) { animation: none !important; } }`. No per-component handling needed.
* **Keep transitions ≤ 300 ms**. Cross-fade for lateral navigation; directional slide only for true depth changes.

## 3. Comment markers

### Owned by this skill
| Marker | Emit on | Semantics |
|---|---|---|
| `// CSR:` | Top of any route component, root layout, or browser-only entry (route file body, `__root.tsx`) | Asserts the code runs in the browser only; the SPA has no SSR boundary, but the marker pins reviewer expectation and catches accidental Node-only imports |

### Used but not owned
| Marker | Owner | Where it appears here |
|---|---|---|
| `// FETCH:` | `nextjs-patterns` | Outbound `apiFetch` call site inside `queryFn`/`mutationFn` (§2.8) |
| `// AUTH:` | `authorization-patterns` | Route `beforeLoad` guards (§2.7); mutation handlers that assume authenticated context |
| `// IDEMPOTENCY:` | `backend-feature-patterns` | Mutating `apiFetch` calls supplying `idempotencyKey` (§2.8) |
| `// EVENT:` | `observability-frontend` | Analytics emission sites (§4) |
| `// MASK:` | `observability-frontend` | Recognised but NOT emitted on this surface — see §4 |
| `// CONSENT:` | `observability-frontend` | Consent gate at root layout (§4) |

## 4. Surface integration for observability-frontend §13
The Admin SPA is the landing zone for the frontend observability markers on the internal surface. Place them at these sites — emission internals, SDK init, and the PII deny-list live in `observability-frontend`.

* **`// CONSENT:`** — emitted at the root layout (`__root.tsx`) before any analytics SDK is allowed to start. Internal-tool consent is simpler than public-portal consent (a one-time admin-policy acceptance, no per-visit banner), but the gate exists.
* **`// EVENT:`** — emitted on meaningful admin actions: mutation success branches, filter applies, bulk-operation submits. PostHog is the sink; events fired before consent are dropped.
* **`// MASK:`** — recognised but **NOT emitted** on the Admin SPA. Microsoft Clarity is disabled on this surface (per stack rule — Clarity runs on the Customer Portal only), so the PII-redaction obligation that `// MASK:` represents does not apply here. Feature code does not need to insert this marker.
* **Error boundary integration** — every `errorComponent` (route-level and root-level) calls the observability sink to report the caught error with the route path as context. This skill's contract is "every errorComponent emits one report, exactly once"; the sink module is owner territory.

## 5. When to use
* Any Admin SPA route, layout, or feature module (Tanstack Router + Tanstack Query).
* Loader/prefetch design, query-key conventions, mutation patterns.
* keycloak-js PKCE integration, in-memory token handling, auth-guarded routes.
* Outbound backend fetch contract for the SPA — `apiFetch` rules.
* Bundle and re-render reviews on the SPA.

## 6. When NOT to use
* **Customer Portal** (Next.js App Router, RSC, NextAuth v5) — see `nextjs-patterns`.
* **Mobile app** (React Native + Expo) — see `react-native-patterns`.
* **Component decomposition, prop typing, form handling, custom hooks** — see `react-component-patterns`.
* **Tailwind v4 setup, shadcn/ui rules, design tokens, CVA, dark mode** — see `frontend-design-system`.
