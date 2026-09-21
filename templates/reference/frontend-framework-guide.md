# Frontend Framework Guide
Reference read on demand by `/sk.init` (NEW PROJECT / WORKSPACE INIT) when the user has not already
chosen a framework for a frontend surface. It is a recommendation aid only. Whatever the user picks
is recorded verbatim in the project's `tech-stack.md`, and the framework never assumes these choices
anywhere else.

## Framework by use case

| Use Case | Recommended Framework | Key Reason |
|---|---|---|
| SEO-critical marketing site or content portal (React preference) | **Next.js (App Router)** | SSR + SSG + ISR, built-in SEO metadata API |
| SEO-critical marketing site or content portal (Vue preference) | **Nuxt 3** | SSR + SSG with Vue syntax, file-based routing |
| Customer portal with auth, forms, dynamic pages (React) | **Next.js (App Router) + an auth library** | SSR + server actions + auth integration |
| Customer portal with auth, forms, dynamic pages (Vue) | **Nuxt 3 + nuxt-auth-utils** | SSR + Vue composition API + auth module |
| Admin dashboard / internal tool / data tables (React) | **React + Vite + a file-based router** | SPA simplicity, no SSR overhead, fast dev |
| Admin dashboard / internal tool / data tables (Vue) | **Vue 3 + Vite + Vue Router** | Lightweight SPA, easy learning curve |
| Enterprise app — large team, strict conventions, strong typing | **Angular 17+ (standalone components)** | Opinionated full framework: DI, routing, forms, state built-in |
| Simple personal tool or prototype | **Next.js (minimal)** or **Vanilla JS** | Low ceremony; Next.js if you want structure |
| iOS + Android mobile app | **React Native + Expo** | Managed workflow, cross-platform |
| Embedded widget or micro-frontend | **Vanilla JS + Web Components** | Minimal footprint, framework-agnostic |

How to use it: say "Based on your use case, I recommend **[X]** because [one-sentence reason].
Would you like to go with that, or do you have a different preference?"

## Language by framework

| Framework chosen | Recommendation | Reason |
|---|---|---|
| Angular 17+ | **TypeScript (strict)** — effectively mandatory | Angular's DI, decorators, and tooling are built for TS |
| Next.js (App Router) | **TypeScript (strict)** — strongly recommended | App Router types require TS for correctness |
| Nuxt 3 | **TypeScript (strict)** — strongly recommended | Auto-imports and composables are fully typed |
| React + Vite | **TypeScript** — recommended, JS acceptable | TS catches prop mismatches early |
| Vue 3 + Vite | **TypeScript** — recommended, JS acceptable | `<script setup lang="ts">` is the modern default |
| Vanilla JS | **Plain JS** — default; JSDoc optional | No build step required |

If TypeScript is chosen, ask "Strict mode or standard?" and record `TypeScript (strict)`,
`TypeScript (standard)` or `JavaScript`.
