---
unit: {unit-id}
intent: {intent-id}
status: draft | approved
surfaces: []            # one entry per impacted Frontend/Mobile project, e.g. [{WebProject}, {MobileProject}]
stories-covered: []
created: {date}
updated: {date}
---

# UI Model: {unit-name}

## Target Surface
<!-- Which surfaces this unit renders on — one line per impacted Frontend/Mobile project, with the framework
     and Platform from the project's .specify/memory/projects/{Project}/tech-stack.md.
     Example:
     - {WebProject} ({framework}, browser) — primary
     - {AdminProject} ({framework}, browser) — read-only moderation view -->

## Route & Page Tree
<!-- The navigation structure per surface, in the framework's terms: route segments, SPA routes, or native
     screens — including layouts/navigators and loading, error and not-found boundaries.
     Example:
     /listings                 # search/browse — rendered on the server, revalidated every 60s
       ├── (loading boundary)  # grid skeleton
       ├── (error boundary)    # search error fallback
       └── /listings/{id}      # detail — server-rendered for SEO -->

## Component Architecture
<!-- Decompose each page into components. One row per component.
     boundary: the render boundary categories the surface's framework defines
       (e.g. server | client, or container | presentational).
     scope: shared (reused 3+ places) | unit-local.
     Format:
     | Component | Boundary | Responsibility | Scope |
     |---|---|---|---|
     | ListingGrid | server | render listing cards from props | unit-local |
     | FilterBar | client | controlled filter form, updates URL params | unit-local |
     | MapView | client | geo map interaction | shared |
     REQUIRED: every component declares boundary + single responsibility. -->

## State Architecture
<!-- Classify every piece of state into exactly ONE home, with rationale.
     server cache: server-owned data, held by the surface's data-fetching layer.
     global client store: cross-component UI state only — never server snapshots.
     URL / navigation: shareable view state.
     local: single-component concern.
     Format:
     | State | Home | Rationale |
     |---|---|---|
     | listing results | server cache (key: listing) | server-owned, revalidate on mutation |
     | active filters | URL params + local | shareable, drives server refetch |
     | theme (dark/light) | global client store | cross-component UI preference |
     REQUIRED: server-owned data must NOT appear under the global client store. -->

## Data Consumption Contracts
<!-- Typed interfaces (in the surface's language) that map consumed API responses to frontend types.
     Reference the operation in the canonical spec (listed in 02-design/contract-changes.md) — do NOT restate
     operation ownership.
     Declare the fetch/rendering strategy per route using the modes the framework supports
     (e.g. static, revalidated, per-request, client-fetched).
     Example:
     - getListing (GET /listings/{id})  →  revalidated every 60s, cache key: listing-{id}
       ListingDetail { id: string; title: string; price: number; location: GeoPoint }
     REQUIRED: every field consumed must exist in the canonical spec. Missing fields → Open Questions. -->

## Design System Usage
<!-- Component-library primitives used, custom components required (with reason), feature-specific token notes.
     Reuse existing tokens — do not introduce a new visual style.
     Example:
     - library: Card, Badge, Dialog, Form, Input, Button
     - custom: ListingMapPin (no library equivalent — wraps map marker)
     - tokens: reuse existing; no new colours -->

## Performance Strategy
<!-- Rendering mode per route, bundle/code split points, image and asset strategy, performance targets.
     Example:
     - Detail page: server-rendered for SEO; MapView loaded lazily (heavy, client-only)
     - Images: optimised responsive images from the asset CDN, priority on hero + first card row
     - Target: LCP < 2.5s, CLS < 0.1 on listing grid (browser); cold start < 2s (native) -->

## Accessibility Requirements
<!-- The project's accessibility target (WCAG 2.2 AA when it sets none; platform guidelines for native
     surfaces), keyboard/switch navigation paths, focus management, accessibility-API decisions.
     Example:
     - FilterBar: full keyboard operable; focus returns to trigger on close
     - MapView: provide non-map list alternative for screen-reader users
     - All interactive elements: visible focus ring, min 44x44 touch target -->

## Error & Loading States
<!-- Per async surface: loading UI, empty state, error fallback.
     Example:
     - Listing grid: skeleton (loading) / "No results — adjust filters" (empty) / retry banner (error)
     - Detail page: not-found view on 404; error boundary on fetch failure -->

## Stories Coverage
<!-- Every story delivered by this unit, mapped to its frontend surface.
     Format: - [{story-id}] {title}: {route/component path, or "no UI — backend only"}
     Example:
     - [INV-001-LST-001] Browse listings: /listings page + ListingGrid, FilterBar -->

## Open Questions
<!-- Unresolved UI decisions, and any endpoints/fields needed but absent from the contract.
     Missing-contract items must name the operation and be flagged for sk.design --contracts. -->
