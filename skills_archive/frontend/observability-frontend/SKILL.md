---
name: observability-frontend
description: |
  Frontend observability rules for Next.js (portal), React+Vite (admin SPA), React Native Expo (mobile): OTel JS / RN telemetry, Sentry SDK to GlitchTip, PostHog anonymous behavior, Microsoft Clarity heatmaps. Covers what to capture, error-boundary integration, source-map upload, PII redaction, opt-in/opt-out conventions. Wiring/deployment lives in `.specify/memory/observability-stack.md`.
when_to_load:
  - Task mentions: log, trace, telemetry, sentry, glitchtip, posthog, clarity, error boundary, user behavior, heatmap, web vitals
  - Files touched: any client-side code that captures user events, errors, or performance metrics
co_loads_with:
  - nextjs-patterns, react-admin-patterns, react-native-patterns (one per surface)
references:
  - observability-backend (server-side correlation via traceparent)
  - .specify/memory/observability-stack.md (one-time wiring)
---

# Observability — Frontend Rules

## 1. Mental model

Four stacks on each frontend surface:

| Stack | Purpose | Surfaces |
|---|---|---|
| **OTel JS / OTel RN** | Traces + minimal metrics (web vitals, route-change timings) | All |
| **Sentry SDK → GlitchTip** | Error capture; trace-id matches backend for cross-correlation | All (GlitchTip deferred from V1) |
| **PostHog (anonymous)** | User behavior analytics; anonymized by default; consent-gated for identification | All |
| **Microsoft Clarity** | Heatmaps + session recordings | **Web only — NOT on RN, NOT on admin SPA** |

**Rule:** each stack has its own purpose. Don't use Sentry for behavior analytics, don't use PostHog for error capture, don't use Clarity for performance metrics.

Wiring (`Sentry.init`, `posthog.init`, Clarity script bootstrap, OTel JS provider construction) lives in `.specify/memory/observability-stack.md`. This skill answers WHAT to capture.

## 2. Trace correlation with backend

> **Rule:** every outbound HTTP call from a frontend surface MUST attach the W3C `traceparent` header to propagate the trace into the backend span tree.

OTel JS / RN does this automatically once the fetch instrumentation is registered (wiring concern). What you do in code: nothing manual — use standard `fetch` / `axios` / TanStack Query; never bypass to a raw `XHR` or skip the fetch instrumentation.

## 3. Error boundary integration (web)

Wrap top-level route components in a React Error Boundary that captures via Sentry SDK. On error: show fallback UI; the SDK captures the error with route + user-action context (NOT PII).

Sentry `trace_id` matches the OTel trace ID for cross-correlation with backend (wiring in memory doc).

**What you do:** use the project's standard `<ErrorBoundary>` component. Don't write per-component error boundaries unless a specific component needs custom fallback UI.

```tsx
// apps/portal/src/app/(routes)/listings/page.tsx
import { ErrorBoundary } from "@/components/observability/ErrorBoundary";

export default function ListingsPage() {
  return (
    <ErrorBoundary fallback={<ListingsErrorState />}>
      <ListingsClient />
    </ErrorBoundary>
  );
}
```

## 4. Error capture on RN

`Sentry.ReactNativeTracing` integration handles navigation tracking; unhandled JS errors auto-capture; unhandled native errors caught via the Sentry native handler.

**What you do:** wrap async screens in try/catch and call `Sentry.captureException(err, { extra: { screen: "foo" } })` for known recoverable errors that are still worth tracking. Don't double-capture: if the error already bubbles to an Error Boundary, let the boundary capture it.

## 5. PostHog — behavior analytics

- **Anonymous by default:** PostHog tracks an anonymous `distinct_id` from first session; no PII attached.
- **Identification:** ONLY after user explicit consent. Call `posthog.identify(userId)` only inside the consent-accepted code path.
- **Event naming:** `<noun>_<verb>` (e.g. `listing_viewed`, `search_executed`, `vendor_signup_completed`).
- **Capture business-meaningful actions only.** Don't track every click, keystroke, scroll, or hover.
- **Property conventions:** snake_case property names; the same PII deny-list as §6 applies.

```tsx
import posthog from "posthog-js";

function ListingCard({ listing }: { listing: ListingSummary }) {
  return (
    <article onClick={() => {
      // EVENT: business-meaningful action; user_id only after consent + identify
      posthog.capture("listing_viewed", { listing_id: listing.id, region: listing.region });
    }}>
      {/* ... */}
    </article>
  );
}
```

## 6. PII deny-list (critical — duplicated from observability-backend §6)

> **Rule:** Never include the following in PostHog events, Sentry breadcrumbs, Clarity instrumentation, or OTel attributes: email, phone, full name, exact date-of-birth, payment data (PAN, CVV), government IDs, full street address, JWT tokens, API keys, passwords, OAuth tokens, IP for residents, session IDs.

| Category | Rule |
|---|---|
| Always allowed | `user_id` (Guid only, after consent + identify), `aggregate_id`, error codes, page slug |
| Always denied | Listed above |

**Sentry breadcrumbs** auto-capture form input by default — **disable input capture** in the Sentry SDK config (wiring concern; rule lives here).

**Clarity masking:** mark sensitive form fields with `data-clarity-mask`. Inputs ALWAYS masked: `password`, `email`, `phone`, `name`, `address`, `card_*`.

**PostHog autocapture:** disable autocapture on form elements; only capture explicit business events.

```tsx
<input
  type="email"
  name="email"
  // MASK: Clarity must not record this field
  data-clarity-mask
  className="..."
/>
```

## 7. Clarity heatmaps (web only)

- Bootstrap loads via `<script>` AFTER the consent gate.
- Mask sensitive fields with `data-clarity-mask`.
- **Don't run Clarity on the admin SPA** — admin users see PII; Clarity recording exposes it. **Clarity is for customer portal only.**
- Default rule: every page with form inputs uses `data-clarity-mask` on every input by default; opt INTO unmasked on a per-field basis only when justified.

## 8. Web Vitals + OTel JS metrics

Captured automatically:

- LCP (Largest Contentful Paint), FID/INP (interaction-to-next-paint), CLS (Cumulative Layout Shift).
- Navigation timings (page load, route change).

**What you don't capture manually:** any of the above. **What you DO capture manually:** business-meaningful timings (search-to-results, image-load-to-display) via a custom span.

```tsx
import { trace } from "@opentelemetry/api";

async function executeSearch(query: SearchQuery) {
  const tracer = trace.getTracer("yourcontext.portal");
  return tracer.startActiveSpan("search.execute", async (span) => {
    span.setAttribute("your_context.region", query.region);
    try { return await api.search(query); }
    finally { span.end(); }
  });
}
```

## 9. Source-map upload (operational rule)

> **Rule:** every production build uploads source maps to Sentry/GlitchTip as part of CI/CD. Without source maps, errors are unreadable (minified call stacks).

Source maps are NOT served to users — uploaded to the Sentry-compatible server-side; the client gets only the minified bundle. The CI pipeline includes the source-map upload step. Wiring lives in the memory doc; rule lives here: **it's mandatory**.

## 10. Opt-in / opt-out conventions

**Required consent gate** before:

- PostHog identification (anonymous capture before consent is OK in some jurisdictions; default to consent-required everywhere).
- Microsoft Clarity entirely.
- Any non-error telemetry that includes `user_id`.

**Always allowed (no consent gate):**

- OTel JS traces (no PII; performance only).
- Sentry error capture (no PII; `user_id` only if consent + identify ran).

```tsx
import { useConsentStore } from "@/state/consent";

export function ObservabilityBootstrap() {
  // CONSENT: state lives in the Zustand consent store
  const accepted = useConsentStore((s) => s.analyticsAccepted);

  useEffect(() => {
    if (!accepted) return;
    // Lazy-load PostHog + Clarity bootstraps only after consent.
    // The actual init configuration lives in `.specify/memory/observability-stack.md`.
    void Promise.all([loadPosthogBootstrap(), loadClarityBootstrap()]);
  }, [accepted]);

  return null;
}
```

Consent banner state lives in a Zustand store (cross-ref `zustand-state-management`). Observability bootstraps read from it. **Do not** load Clarity / PostHog SDKs before the consent gate confirms — lazy-load them via dynamic import on consent acceptance.

## 11. RN-specific differences from web

- No Clarity (not supported on RN).
- Sentry RN SDK handles both JS-thread and native errors.
- OTel RN exists but has limited fetch auto-instrumentation; you may need explicit `traceparent` header attachment in API clients.
- PostHog RN SDK exists; same conventions apply.
- Source maps via the Sentry RN integration (different from the web SDK).

## 12. Anti-patterns

- Capturing every click via PostHog autocapture (noise; cost).
- Sentry breadcrumbs with form input enabled (PII leak by default).
- Clarity on the admin SPA (PII leak).
- `posthog.identify(userId)` before consent.
- Custom OTel spans inside tight render loops or scroll handlers.
- `console.log(user)` — PII visible in prod logs.
- Manual `traceparent` header manipulation (use the auto-instrumentation).
- Manual `Sentry.captureException` from inside the Error Boundary (the boundary auto-captures; don't double).
- Hardcoding Sentry DSN / PostHog key / Clarity ID in source (config / env only; memory doc).
- Production builds without source-map upload (errors unreadable).

## 13. Comment markers emitted by this skill

- `// EVENT:` — PostHog business-event capture.
- `// MASK:` — Clarity `data-clarity-mask` attribute.
- `// CONSENT:` — code path that depends on consent state.

Canonical comment-markers index: `backend-architecture §7`.

## 14. References

- `nextjs-patterns` — Customer Portal surface integration (Phase 6 will fill section refs).
- `react-admin-patterns` — Admin SPA surface (**NO Clarity** rule).
- `react-native-patterns` — Mobile surface (NO Clarity, RN-specific patterns).
- `zustand-state-management` — consent state lives here.
- `observability-backend §6` — server-side PII deny-list (duplicated for skill independence).
- `.specify/memory/observability-stack.md` — one-time wiring.
