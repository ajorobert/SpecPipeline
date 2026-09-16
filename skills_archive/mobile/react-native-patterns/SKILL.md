---
name: react-native-patterns
description: "Load when: implementing or reviewing the mobile app (React Native + Expo managed workflow, Expo Router, NativeWind v5, FlashList, Reanimated 3, expo-auth-session PKCE, expo-secure-store, expo-file-system). Covers project structure, file-based routing, native styling, list rendering, animations, state, native APIs, Keycloak PKCE auth, the backend fetch contract, presigned uploads with progress, mobile accessibility, and observability marker placement."
when_to_load:
  - Any mobile screen, layout, navigator, or feature module
  - Expo Router route file or layout
  - FlashList / list rendering performance work
  - Reanimated 3 / gesture work
  - keycloak PKCE auth via expo-auth-session
  - Outbound fetch from the mobile app to a backend service
  - File upload from the mobile app (presigned PUT to R2)
  - Mobile accessibility implementation or review
  - Observability marker placement on RN code
co_loads_with:
  - frontend-design-system
  - react-component-patterns
  - accessibility-standards
  - observability-frontend
references:
  - .specify/memory/auth_contract.md
---

# React Native Patterns (Expo Managed + Expo Router + NativeWind v5)

## 1. Purpose
Production patterns for the vendor mobile app built with React Native, Expo managed workflow, Expo Router, NativeWind v5 (Tailwind v4 CSS-first), FlashList, Reanimated 3, and Keycloak PKCE auth via expo-auth-session. Covers managed-workflow boundaries, file-based routing with deep linking, native styling, list and animation performance, native API permission UX, in-memory access + secure-store refresh token handling, the universal backend fetch contract (traceparent + Idempotency-Key), presigned uploads with progress on `fetch`-incompatible APIs, mobile-specific accessibility, and the observability marker landing zone. Excludes wiring (`app.json` config, Expo plugins, AuthRequest project singleton instantiation, Sentry/OTel/PostHog init) — those live in `.specify/memory/` or deploy docs. Component decomposition and web-only design-system rules live in their own skills (see §6).

## 2. Core Rules

### 2.1 Expo Managed Workflow
* **Stay in managed workflow.** Do not eject unless a native module is genuinely unavailable as an Expo SDK module, an `expo-modules-core` config plugin, or a community Expo module. Ejecting breaks EAS Update OTA delivery and adds native maintenance burden.
* **Development with `expo-dev-client`**: lets you use custom native modules without bare workflow. The Expo Go app does not load custom native modules — never test against Expo Go for production behaviour.
* **EAS Update for OTA**: JS-only changes ship via OTA; native dependency changes require a new build. Keep the JS bundle slim — large bundles defeat OTA value.
* **Config is `app.config.ts` (or `app.json`)**: permission strings, deep link scheme, splash, icons. No manual `Info.plist` / `AndroidManifest.xml` edits in managed workflow.
* **Pin the Expo SDK version explicitly** (`"expo": "~52.0.0"`, not `*`). Each SDK upgrade is intentional and tested.

### 2.2 Expo Router
File-based routing under `app/`. Mirrors Next.js App Router conventions but renders native navigators.

```
app/
├── _layout.tsx                 # Root layout; auth provider; global error boundary
├── (auth)/                     # Group: routes that require authenticated session
│   ├── _layout.tsx             # Auth guard; redirects to /sign-in if no session
│   ├── (tabs)/                 # Nested group: bottom tab bar
│   │   ├── _layout.tsx         # <Tabs> navigator
│   │   ├── index.tsx           # Tab 1
│   │   └── profile.tsx         # Tab 2
│   └── listings/
│       └── [id].tsx            # Dynamic route
├── sign-in.tsx                 # Public; auth entry
└── +not-found.tsx              # 404
```

* **Stack vs Tabs**: `<Stack>` for hierarchical screens (list → detail → edit); `<Tabs>` for peer top-level destinations. Combine via nested layouts — never stack tabs inside tabs.
* **Native navigators**: use the native option (`<Stack screenOptions={{ headerShown: true }}>`) — UINavigationController on iOS, Fragment-based on Android. Avoids JS-thread hitches on transitions.
* **Deep linking**: register the URL scheme in `app.config.ts` (`scheme`). Expo Router maps the URL path to the file structure automatically; no manual linking config in feature code.
* **Auth callback deep link**: the Keycloak redirect URI is a deep link into the app (`<scheme>://auth-callback`). Expo Router routes it; the auth screen reads `useLocalSearchParams` for the `code` + `state` params.
* **Per-group auth guard** in the group's `_layout.tsx`:
  ```tsx
  // app/(auth)/_layout.tsx
  // AUTH: group-wide gate; backend re-checks on every request
  if (!session.isAuthenticated) return <Redirect href="/sign-in" />;
  return <Stack />;
  ```
* **Navigation**: use `router.push`/`router.replace`/`<Link>` from `expo-router`. Never `Linking.openURL` for in-app navigation. `router.back()` is fine for explicit back actions; do not rely on it for required navigation paths.

### 2.3 NativeWind v5 + Tailwind v4
NativeWind v5 brings Tailwind v4 CSS-first config to RN. Tokens flow from `global.css` to native style props at build time.

* **Import platform-aware components** from `react-native-css/components` (or the equivalent NativeWind v5 export): `View`, `Text`, `Pressable`, `ScrollView`, `TextInput`, `Image`. Their `className` prop accepts the same Tailwind classes used on web — but RN does not have the full CSS surface.
* **`global.css` defines tokens** with `@theme` blocks. Share the token set with web where it makes sense (typography scale, spacing, radii). Colours diverge by necessity: native apps want `platformColor()` for system semantic colours.
* **`platformColor('systemBlue', '#3b82f6')`** resolves at runtime to the iOS system colour (or Android equivalent), falling back to the hex on unsupported platforms. Use for: primary accents, separators, fill backgrounds, anything that should track OS theme.
* **Dark mode** via `useColorScheme()` from `react-native` (NOT NativeWind's web `dark:` hack alone). The `dark:` variant works for NativeWind classes; the hook is needed when imperative logic must branch on theme.
* **No `StyleSheet.create` mixed with NativeWind on the same component** — pick one approach. NativeWind for declarative styling; `StyleSheet` only for cases NativeWind can't express (rare; usually only `transform` matrices in complex animations).
* **Tailwind subset**: web-only utilities (`grid`, `aspect-ratio` until RN 0.74+, container queries) don't apply. Verify any unusual utility against the NativeWind v5 supported list before relying on it.

### 2.4 List Rendering — FlashList
The single biggest source of mobile jank is `ScrollView` + `.map()` or unmemoised `FlatList`. FlashList from `@shopify/flash-list` is mandatory for any scrolling list whose length isn't tiny and known.

* **Always use FlashList** for any list of more than ~10 items, any list of unknown length, and any list with images. Use plain `View` + map only for fixed, known-tiny lists (e.g. a 3-item action menu).
* **`estimatedItemSize` is mandatory** — set it to a measured average (`px` height). Wrong estimates blow recycling; do not guess.
* **`keyExtractor`** returns a stable string ID — never the index. Index-based keys break recycling on filter/sort.
* **Memoise the row component** (`React.memo`) and stabilise props: callbacks via `useCallback`, no inline objects in row props.
* **Images in lists use `expo-image`** (NOT `Image` from `react-native`): caches, recycles, supports `blurhash` placeholders, manages memory across recycled cells.
* **`renderItem` is stable** — declare outside the component or wrap with `useCallback`. Anonymous `renderItem={({ item }) => <Row ... />}` re-creates the function each parent render and defeats FlashList's recycling optimiser.

```tsx
// @/screens/listings/list.tsx
const renderItem = useCallback(({ item }: { item: Listing }) => (
  <ListingRow listing={item} onPress={handlePress} />
), [handlePress]);

return (
  <FlashList
    data={listings}
    renderItem={renderItem}
    estimatedItemSize={88}
    keyExtractor={(item) => item.id}
  />
);
```

### 2.5 Reanimated 3
Animations run on the UI thread via worklets. Anything that crosses the bridge per frame kills the animation budget (16 ms at 60 Hz).

* **Worklet boundary**: animation logic inside `useDerivedValue`, `useAnimatedStyle`, and gesture callbacks runs on the UI thread. Don't call regular JS functions from inside a worklet — wrap with `runOnJS` when you need to.
* **GPU-friendly properties only**: `transform` (`translateX`, `translateY`, `scale`, `rotate`), `opacity`. Never animate `width`, `height`, `top`, `left`, `margin`, `padding` — those trigger layout on every frame and produce visible stutter.
* **`useSharedValue`** for the animated state; **`useAnimatedStyle`** to map shared values to style.
* **Gestures via `react-native-gesture-handler`** with `Gesture.Pan()` / `GestureDetector`. Don't put `onPress` on `Animated.View`; use `Pressable` or compose a `Gesture.Tap()`.
* **Animation primitives**: `withSpring`, `withTiming`, `withDecay`, `withRepeat`. Avoid the legacy `Animated.loop` API.
* **Reduced motion**: read `useReducedMotion()` from `react-native-reanimated` and fast-path animations to their end state when true (or skip the spring entirely).

### 2.6 State
* **Zustand** for cross-screen UI state (offline queue, current session derived data, UI theme overrides). Store-selector hygiene, `useShallow`, persist-middleware patterns live in `zustand-state-management` — this section defers there rather than duplicating.
* **`react-native-mmkv` as the Zustand persist storage backend** on mobile (faster than AsyncStorage, synchronous). Wire via `createJSONStorage(() => mmkvStorage)`.
* **TanStack Query** for server state. Use `networkMode: 'offlineFirst'` so cached data renders without network and mutations queue.
* **Local component state (`useState`)** for UI state that does not escape the component.
* **Never use Context for high-frequency updates** — Context propagation on RN is more expensive than on web. Zustand selectors are the rule.

### 2.7 Native APIs (permissions UX)
* Permission-gated APIs: camera (`expo-camera`), location (`expo-location`), notifications (`expo-notifications`), media library (`expo-media-library`), contacts (`expo-contacts`), biometrics (`expo-local-authentication`).
* **Request-on-use, not request-on-launch.** Show an in-app explainer screen describing why the permission is needed BEFORE calling the system prompt. iOS denies twice → permanently blocked, no second-chance prompt; Android behaves similarly on modern versions. The explainer is the only chance to convert.
* **Handle all three states**: `granted`, `denied`, `undetermined`. The `denied`-with-`canAskAgain: false` case must surface a "open Settings" deep link via `Linking.openSettings()` — the only path back.
* **Permission strings in `app.config.ts`** (e.g. `ios.infoPlist.NSCameraUsageDescription`). The system prompt displays this text verbatim; vague strings → App Store rejection.
* **Background tasks**: `expo-background-fetch` / `expo-task-manager` have strict OS-imposed limits. Long-running background work (large uploads, heavy sync) needs careful design — see §2.10 for upload-specific constraints.

### 2.8 Authentication — Keycloak PKCE via expo-auth-session
Universal OAuth 2.1 PKCE flow, applied to the mobile app via `expo-auth-session`. The library generates the verifier/challenge, opens the system browser (ASWebAuthenticationSession on iOS, Custom Tabs on Android), and returns the authorization code via the deep-link callback.

* **PKCE mandatory** (`codeChallenge: 'S256'`). Never the implicit flow.
* **System browser, not WebView** — `expo-auth-session` uses ASWebAuthenticationSession / Custom Tabs by default. Embedded WebView for OAuth violates RFC 8252 and is rejected by Keycloak's `pkce` enforcement and by app store review.
* **Redirect URI** is the app's deep-link scheme (`<scheme>://auth-callback`). Registered in `app.config.ts`; matched in Keycloak client config.
* **Access token: in-memory only.** Lives in a Zustand store slice, an in-memory module variable, or the auth provider's state — never persisted to disk.
* **Refresh token: `expo-secure-store` ONLY.** Encrypted at rest by iOS Keychain / Android Keystore. **Never AsyncStorage** (plaintext on Android). **Never MMKV** for the refresh token (MMKV is fast but not encrypted by default).

```tsx
// @/lib/auth/store-refresh-token.ts
import * as SecureStore from 'expo-secure-store';

const KEY = 'kc.refresh';

export async function storeRefreshToken(token: string) {
  // TOKEN: encrypted at rest (iOS Keychain / Android Keystore); never AsyncStorage / MMKV
  await SecureStore.setItemAsync(KEY, token, {
    keychainAccessible: SecureStore.AFTER_FIRST_UNLOCK_THIS_DEVICE_ONLY,
  });
}

export async function readRefreshToken() {
  // TOKEN: read encrypted refresh token; access token never persists here
  return SecureStore.getItemAsync(KEY);
}

export async function clearRefreshToken() {
  await SecureStore.deleteItemAsync(KEY);
}
```

* **Foreground refresh**: when the app comes to foreground (`AppState` listener), if the access token is within 60 s of expiry, refresh it before the next request. The apiClient (§2.9) also refreshes opportunistically.
* **Refresh failure** → clear the refresh token, sign the user out, redirect to `/sign-in`. Do not silently retry indefinitely.
* **Deep-link callback handling** lives in the sign-in screen — read `code` and `state` from `useLocalSearchParams`, exchange via `expo-auth-session`'s `exchangeCodeAsync`, store refresh token via the helper above, set access token in memory, redirect into the authenticated group.
* **`MobileSession` shape** (what the app consumes from the token at the application layer) and **token storage details** for this project live in `.specify/memory/auth_contract.md`.
* **Role-driven UI**: roles come from the parsed access token. Treat as a UI affordance; never as a security control — the backend re-checks on every request.

### 2.9 Backend Fetch Contract
Every outbound call to a backend service goes through a single `apiClient` wrapper. The wrapper enforces three contracts; feature code never bypasses it.

* **Authorization** attached by the wrapper from the in-memory access token. Feature code never reads the token directly.
* **`traceparent` header (W3C Trace Context)** forwarded on every request. The OTel JS RN instrumentation generates the context when absent.
* **`Idempotency-Key` header on mutations** — every `POST`/`PUT`/`PATCH`/`DELETE` carries a UUID v4 that is **stable per user action, NOT per network retry**. Critical on mobile because flaky networks retry implicitly inside fetch / native HTTP layers. The wrapper requires the caller (or mutation hook) to supply `idempotencyKey`; absent on a mutating verb → throws in development.
* **401 handling**: try one refresh via `expo-auth-session.refreshAsync`; on success retry original; on refresh failure trigger sign-out. Never surfaces to feature code.
* **403 / 4xx with details**: typed error to the call site → inline UI.
* **5xx / network failure**: typed error → user-facing retry, plus optional offline queue (see below).

```ts
// @/lib/api-client.ts — shape only
export type ApiOptions = RequestInit & {
  signal?:         AbortSignal;
  idempotencyKey?: string;
};

export async function apiFetch(path: string, opts: ApiOptions = {}): Promise<Response> {
  const isMutation = opts.method && opts.method !== 'GET';
  if (isMutation && !opts.idempotencyKey && __DEV__) {
    throw new Error('apiFetch: mutating call requires idempotencyKey');
  }
  await ensureAccessTokenFresh(60);
  // FETCH: bearer + traceparent + idempotency-key composed here
  const headers = buildHeaders(opts);
  return fetch(getApiUrl() + path, { ...opts, headers });
}
```

```ts
// @/features/listings/api.ts — mutation supplying idempotencyKey
export function useDeactivateListing() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) =>
      // IDEMPOTENCY: generated once at queue time, reused across all network retries
      apiFetch(`/api/v1/listings/${id}/deactivate`, {
        method:         'POST',
        idempotencyKey: crypto.randomUUID(),
      }),
    onSuccess: (_, id) => qc.invalidateQueries({ queryKey: ['listings'] }),
  });
}
```

* **Offline queue**: mutations issued while offline persist to MMKV-backed Zustand slice. **Idempotency keys are generated when the mutation is queued, NOT when the network retry fires** — otherwise the same user action gets multiple server-side commits. Replay on reconnect; drop the entry on 2xx response.

### 2.10 Uploads (presigned PUT to R2)
The portal pattern (presigned PUT to the private R2 bucket) applies on mobile too — but with two RN-specific complications: `fetch` does not report upload progress, and background uploads need OS cooperation.

* **Universal flow**: client `POST /presign` → backend returns `{ url, fields, headers, key }` → client `PUT` to `url` with file body → optional client confirm `POST /uploads/{key}/complete`.
* **`Content-Type` on the PUT MUST match the value the backend signed for.** R2 includes Content-Type in the signature; mismatch → `403 SignatureDoesNotMatch`. Use the same value the `/presign` request declared.
* **No `Authorization` header on the PUT to R2.** The presigned URL has auth in the query string; adding a bearer header invalidates the signature.
* **Upload progress: use `expo-file-system.uploadAsync`** with `uploadType: BINARY_CONTENT` and a `progress` callback. `fetch` on RN does not expose `XMLHttpRequest`-style upload events reliably; `expo-file-system` does:

```ts
// @/lib/upload.ts
import * as FileSystem from 'expo-file-system';

export async function uploadFile(
  presigned: { url: string; contentType: string },
  fileUri:   string,
  onProgress?: (frac: number) => void,
): Promise<void> {
  const task = FileSystem.createUploadTask(presigned.url, fileUri, {
    httpMethod:   'PUT',
    uploadType:   FileSystem.FileSystemUploadType.BINARY_CONTENT,
    headers:      { 'Content-Type': presigned.contentType }, // MUST match signed value
    // NO Authorization header on PUT — presigned URL carries auth
  }, (e) => onProgress?.(e.totalBytesSent / e.totalBytesExpectedToSend));
  const result = await task.uploadAsync();
  if (!result || result.status >= 300) throw new Error(`upload failed: ${result?.status}`);
}
```

* **Background uploads**: iOS allows ~30 s of background execution by default; longer uploads need `expo-task-manager` + `BackgroundTask` registration AND user-perceived value (Apple rejects "always-on" abuse). Android requires a foreground service for reliable long uploads (notification visible to user). For UX simplicity: keep large uploads foreground-only; show progress; resume from scratch on app return if interrupted.
* **Multipart**: R2 single-PUT limit is 5 GB; for mobile, typical assets (photos, short video) fit single-PUT. Multipart is more code, more failure modes — only add when files genuinely exceed the limit.
* **Resume**: R2 does NOT support resuming a single PUT. On failure, restart the upload with the **same `Idempotency-Key` on the original `/presign` request** so the backend recognises the retry as the same user action (not a duplicate upload).

### 2.11 Accessibility (mobile-specific)
RN uses a different a11y API surface than the DOM. VoiceOver (iOS) and TalkBack (Android) consume these props directly.

* **`accessibilityLabel`** is mandatory on any interactive element without visible text (icon buttons, image-only links). Concise — the screen reader reads it verbatim.
* **`accessibilityHint`** describes the action's result, not what the element is. ("Submits the form" — not "this is a button").
* **`accessibilityRole`** classifies the element: `'button'`, `'link'`, `'header'`, `'image'`, `'imagebutton'`, `'switch'`, `'checkbox'`, `'radio'`, `'tab'`, `'menu'`, `'alert'`. Wrong role confuses screen readers.
* **`accessibilityState`** for stateful elements: `{ disabled, selected, checked, busy, expanded }`. Update on state change; screen readers re-announce.
* **Touch target ≥ 44 × 44 pt (iOS HIG) / 48 × 48 dp (Material).** Wrap small visual elements in larger `Pressable` to extend the hit area without resizing the visual:
  ```tsx
  // A11Y: 44pt minimum hit area enforced via hitSlop
  <Pressable hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }} onPress={onPress}>
    <CloseIcon size={28} />
  </Pressable>
  ```
* **`accessibilityLiveRegion`** (Android) / `AccessibilityInfo.announceForAccessibility` (iOS) for dynamic updates (e.g. toast, loading complete). Use sparingly — over-announcement is hostile.
* **Focus management**: `AccessibilityInfo.setAccessibilityFocus(reactTag)` to move VoiceOver/TalkBack focus after navigation or modal open. Return focus to the trigger on close.
* **Reduced motion**: `useReducedMotion()` from Reanimated drives animation skipping (§2.5). Also respect `AccessibilityInfo.isReduceMotionEnabled` for non-Reanimated animation gates.
* **Testing**: VoiceOver (iOS Settings → Accessibility → VoiceOver) and TalkBack (Android Settings → Accessibility → TalkBack) walk-through is mandatory before story sign-off — emulators don't replicate the experience. A real device is required.

### 2.12 Performance
* **Bridge thrash**: minimise JS↔native message volume. Animation loops, list scroll handlers, gesture callbacks must run on the UI thread (Reanimated worklets). Don't `console.log` per frame.
* **Memo list rows** (§2.4) — non-negotiable. The single biggest source of mobile jank.
* **Images via `expo-image`** with `cachePolicy: 'memory-disk'` and explicit `width`/`height`. Decode work blocks the UI thread on first render of large images; size them down on the server (presigned upload + ImageSharp on backend already produces variants — request the right variant).
* **No `console.log` in production builds.** Either gate behind `if (__DEV__)` or strip via Metro config / Hermes minification.
* **Avoid anonymous functions in JSX for list items** (defeats `React.memo`). Extract named handlers; `useCallback` with stable deps.
* **`useFocusEffect`** (from `expo-router`) instead of `useEffect` for screen-level data refresh — fires when the screen gains focus, not on every render of an out-of-focus screen in the stack.
* **`InteractionManager.runAfterInteractions`** for expensive non-urgent work that should defer past navigation animations.
* **Bundle size**: dynamic `import()` for code splitting works on Hermes but RN does not split routes the way web does. The whole JS bundle ships at once. Trim dependencies aggressively; audit with `npx expo-doctor` and Metro bundle visualiser.

## 3. Comment markers

### Owned by this skill
| Marker | Emit on | Semantics |
|---|---|---|
| `// TOKEN:` | Every `expo-secure-store` call that reads/writes/clears the refresh token | Asserts the refresh-token-in-secure-store rule; CI greps for misuse (e.g. `AsyncStorage` or `MMKV` around the refresh token) |

### Used but not owned
| Marker | Owner | Where it appears here |
|---|---|---|
| `// FETCH:` | `nextjs-patterns` | Outbound `apiFetch` call site (§2.9) |
| `// AUTH:` | `authorization-patterns` | Group `_layout.tsx` auth guard (§2.2); mutation handlers assuming authenticated context |
| `// IDEMPOTENCY:` | `backend-feature-patterns` | Mutating `apiFetch` calls supplying `idempotencyKey` (§2.9) |
| `// A11Y:` | `accessibility-standards` | Non-obvious a11y annotations (§2.11), e.g. enforced 44pt hit area via `hitSlop` |
| `// EVENT:` | `observability-frontend` | Analytics emission sites (§4) |
| `// CONSENT:` | `observability-frontend` | Consent gate at root layout (§4) |

### Recognised but NOT emitted
| Marker | Reason |
|---|---|
| `// MASK:` | Microsoft Clarity is not supported on React Native; the PII-redaction obligation that `// MASK:` represents does not apply on this surface. Feature code does not insert this marker. |

## 4. Surface integration for observability-frontend §13
The mobile app is the landing zone for the frontend observability markers on the native surface. Place them at these sites — emission internals, SDK init, source-map upload, and the PII deny-list live in `observability-frontend`.

* **`// CONSENT:`** — emitted at the root `_layout.tsx` before any analytics SDK is allowed to start. Mobile consent is OS-platform-aware: iOS App Tracking Transparency (`expo-tracking-transparency`) gates IDFA-bearing telemetry; Android privacy disclosure happens at first launch. PostHog is anonymous (no IDFA), but the gate exists for consistency.
* **`// EVENT:`** — emitted on meaningful user actions: mutation success branches, screen views (auto-instrumented or manual), background sync results, sign-in completion. PostHog is the sink; events fired before consent are dropped or queued depending on the project's privacy stance.
* **`// MASK:` is NOT emitted on this surface** (Clarity not supported on RN — see §3). The PII deny-list still applies to PostHog event payloads and Sentry breadcrumbs, but enforcement is centralised in the observability SDK wrappers, not per-call.
* **Sentry RN error boundary integration**: the root `_layout.tsx` wraps the app in a Sentry `ErrorBoundary` (or equivalent) that reports caught errors and route context. Expo Router's `+not-found.tsx` and any per-segment error boundary also report. The skill's contract: every error boundary emits one report, exactly once.
* **Source maps**: every release build uploads JS source maps + native dSYM/ProGuard mapping files to Sentry as part of EAS Build hooks. Without these, crashes are unreadable. This skill describes the contract; the upload step itself is wiring.

## 5. When to use
* Any mobile screen, layout, navigator, or feature module.
* Expo Router route file or layout.
* FlashList performance work, Reanimated 3 animations, gesture composition.
* `expo-auth-session` PKCE auth, deep-link callbacks, in-memory + secure-store token handling.
* Outbound backend fetch contract from the mobile app — `apiClient` rules.
* Presigned uploads with progress; mobile-specific upload constraints (background, multipart, retry).
* Mobile a11y implementation or review (VoiceOver / TalkBack).

## 6. When NOT to use
* **Customer Portal** (Next.js App Router) — see `nextjs-patterns`.
* **Admin SPA** (React + Vite + Tanstack Router) — see `react-admin-patterns`.
* **Component decomposition, prop typing, form handling, custom hooks** — see `react-component-patterns`.
* **Web design-system rules** (Tailwind v4 web setup, shadcn/ui, CVA, web dark mode) — see `frontend-design-system`. NativeWind shares tokens conceptually but the web rules don't all transfer.
