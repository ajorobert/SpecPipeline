---
name: zustand-state-management
description: "Load when: implementing or reviewing Zustand stores for global/shared UI state in any frontend. TypeScript patterns, hydration safety, persist middleware, slice composition."
---

# Zustand State Management

## Purpose
Production patterns for Zustand v5 (React 18–19, TypeScript 5+) managing global and shared UI state across the customer portal and admin SPA. Covers correct TypeScript syntax, hydration safety, persist middleware, slice composition, and the boundary between Zustand state and server state (TanStack Query).

## Core Rules

### What Belongs in Zustand
* **Yes**: auth session claims (in-memory), user preferences (UI theme, locale, saved filters), offline queue, cross-route UI state (sidebar open/closed, active modal), app-wide notification queue.
* **No**: server data (listings, users, API responses) → TanStack Query. Form state → react-hook-form. Component-local UI state → `useState`.
* Rule: if only one component needs the state, use `useState`. If two or more components need it and they are not parent/child, use Zustand.

### TypeScript — Mandatory Double-Parentheses Syntax
```typescript
// ✅ CORRECT — double parentheses required for TypeScript + middleware type inference
const useStore = create<MyStore>()((set, get) => ({
  // store definition
}));

// ❌ WRONG — single parentheses breaks middleware type compatibility
const useStore = create<MyStore>((set) => ({ ... }));
```
This is a Zustand v5 TypeScript requirement. All stores must use the curried form.

### Store Structure
* One store per domain concern (`useAuthStore`, `usePreferencesStore`, `useNotificationStore`).
* Export the hook — never the store instance (`useStore` not `store`).
* Keep stores flat when possible. Nested objects require `immer` middleware for ergonomic updates.
* Actions defined inside the store — never mutate state from outside.
* Immutable updates: always use the functional form: `set(state => ({ count: state.count + 1 }))`.
* Never mutate state directly: `state.count++` is wrong even with immer unless using immer middleware explicitly.

```typescript
interface AuthStore {
  userId: string | null;
  roles:  string[];
  setSession: (userId: string, roles: string[]) => void;
  clearSession: () => void;
}

export const useAuthStore = create<AuthStore>()((set) => ({
  userId: null,
  roles:  [],
  setSession: (userId, roles) => set({ userId, roles }),
  clearSession: () => set({ userId: null, roles: [] }),
}));
```

### Selectors — Prevent Unnecessary Re-renders
* Select primitive values directly: `const userId = useAuthStore(state => state.userId)`.
* For object/array selectors use `useShallow`: prevents re-render when reference changes but value is equal.
  ```typescript
  import { useShallow } from 'zustand/react/shallow';
  const { userId, roles } = useAuthStore(useShallow(state => ({ userId: state.userId, roles: state.roles })));
  ```
* Never do `const store = useAuthStore()` — subscribes to all state changes, re-renders on any update.
* Never create new objects in selectors: `useStore(s => ({ a: s.a, b: s.b }))` without `useShallow` causes infinite re-renders.

### Persist Middleware (SSR-Safe)
```typescript
import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';

interface PreferencesStore {
  theme: 'light' | 'dark' | 'system';
  locale: string;
  _hasHydrated: boolean;
  setTheme: (theme: PreferencesStore['theme']) => void;
  setHasHydrated: (v: boolean) => void;
}

export const usePreferencesStore = create<PreferencesStore>()(
  persist(
    (set) => ({
      theme:         'system',
      locale:        'en',
      _hasHydrated:  false,
      setTheme:      (theme) => set({ theme }),
      setHasHydrated:(v) => set({ _hasHydrated: v }),
    }),
    {
      name:    'user-preferences',                          // unique key per store
      storage: createJSONStorage(() => localStorage),
      onRehydrateStorage: () => (state) => {
        state?.setHasHydrated(true);                       // flag hydration completion
      },
    }
  )
);

// In component — guard on hydration to prevent SSR mismatch
export function ThemeToggle() {
  const hasHydrated = usePreferencesStore(s => s._hasHydrated);
  const theme       = usePreferencesStore(s => s.theme);
  if (!hasHydrated) return null; // or skeleton
  return <>{/* render with correct theme */}</>;
}
```
* Always use `_hasHydrated` pattern for persisted stores rendered in SSR contexts (Next.js).
* Every persisted store needs a unique `name`. Duplicate names = shared, overwriting storage.
* `createJSONStorage(() => localStorage)` — the lambda prevents access during SSR (localStorage is undefined on server).

### DevTools Middleware
```typescript
import { devtools } from 'zustand/middleware';

export const useListingStore = create<ListingStore>()(
  devtools(
    (set) => ({ ... }),
    { name: 'ListingStore', enabled: process.env.NODE_ENV === 'development' }
  )
);
```
* Always gate `enabled` on `NODE_ENV` — never ship DevTools in production.

### Immer Middleware (Complex Nested Updates)
```typescript
import { immer } from 'zustand/middleware/immer';

export const useOfflineQueueStore = create<OfflineQueueStore>()(
  immer((set) => ({
    queue: [] as PendingAction[],
    enqueue: (action) => set(state => { state.queue.push(action); }),
    dequeue: (id) =>     set(state => { state.queue = state.queue.filter(a => a.id !== id); }),
  }))
);
```
* Use Immer only when state shape is deeply nested and spread updates become unreadable. Flat stores do not need Immer.

### Slice Composition (Large Stores)
```typescript
import { StateCreator } from 'zustand';

interface AuthSlice { userId: string | null; setUserId: (id: string) => void; }
interface UISlice   { sidebarOpen: boolean; toggleSidebar: () => void; }
type AppStore = AuthSlice & UISlice;

const createAuthSlice: StateCreator<AppStore, [], [], AuthSlice> = (set) => ({
  userId: null,
  setUserId: (id) => set({ userId: id }),
});

const createUISlice: StateCreator<AppStore, [], [], UISlice> = (set) => ({
  sidebarOpen: false,
  toggleSidebar: () => set(state => ({ sidebarOpen: !state.sidebarOpen })),
});

export const useAppStore = create<AppStore>()(...(set, get, api) => ({
  ...createAuthSlice(set, get, api),
  ...createUISlice(set, get, api),
}));
```
* `StateCreator` type annotation is required on each slice when using middleware — TypeScript inference breaks without it.

## When to Use
* Global auth session claims (after Keycloak token validation)
* User preferences (theme, locale, saved search filters)
* Offline action queue for mobile
* App-wide notification/toast queue
* Cross-route UI state (sidebar, active modal, wizard step)

## When NOT to Use
* Server data from the API (listings, users, search results) → TanStack Query
* Form state → react-hook-form
* Component-local ephemeral state → `useState`
* Server-side state in Next.js Server Components — Zustand is client-only
