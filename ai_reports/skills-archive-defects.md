# skills_archive — known defects

**Date:** 2026-09-17
**Found by:** executing step 2 of `framework-project-skills-separation-plan.md` (adopting the packs into `tagin-platform`).
**Scope:** defects in the packs themselves, wrong for **any** adopter. Nothing here is specific to tagIN.
**Status:** recorded, not fixed. Fix before the next project adopts, or the next adopter re-discovers them.

The archive is a library, not a work queue — it is not "used up" by a project adopting from it. But an adopter
reads these packs as a starting point, and the items below will mislead them.

---

## 1. `react-admin-patterns` describes a stack that was reversed

The pack teaches **React + Vite + TanStack Router + keycloak-js** (6 mentions of Vite). The admin surface it was
written for moved to **Next.js + NextAuth**; there is no Vite in that repo at all. The pack was **not adopted**
in step 2 — the ~20% that survives (query-hook conventions, `staleTime` bands, retry policy) folded into
`nextjs-patterns`.

`skill-routing.example.md` already flags this in its Surfaces row — *"Next.js + NextAuth (verify —
react-admin-patterns still describes React + Vite)"* — but the pack itself is unaware, and the README's intro
("Next.js web surfaces") contradicts the pack a third way.

**Fix:** either retarget the pack at Next.js admin surfaces, or retitle it as a generic SPA-admin pack and stop
implying it matches this stack.

## 2. Two different object stores for one pipeline

- `data/file-pipeline-patterns/SKILL.md` — **SeaweedFS** (S3-compatible), with `*.Adapters.SeaweedFs/` project conventions.
- `frontend/nextjs-patterns/SKILL.md` §2.8 and `mobile/react-native-patterns/SKILL.md` §2.10 — **Cloudflare R2**, quoting R2-specific limits as rules (5 GB single-PUT ceiling, no resume on a single PUT, Content-Type inside the signature).

Same presigned-upload flow, two backends, no reconciling note anywhere.

**Fix:** pick one per the reference stack, or make the storage backend an explicit placeholder in all three.

## 3. Three broken cross-skill section pointers

Every "Surface integration" anchor points at the wrong section of `observability-frontend`:

| Pointer | Points at | Actually is |
|---|---|---|
| `nextjs-patterns:253` → `observability-frontend §11` | §11 | "RN-specific differences from web" |
| `react-admin-patterns:224` → `observability-frontend §13` | §13 | "Comment markers emitted by this skill" |
| `react-native-patterns:296` → `observability-frontend §13` | §13 | "Comment markers emitted by this skill" |

**Fix:** repoint, or drop the numbers — section numbers are a brittle cross-file contract.

## 4. Build-order leftovers presented as current state

- `backend/integration-adapter-patterns/SKILL.md` lines 15, 198, 270 — *"Phase 5 placeholder"* ×3, referring to `observability-backend`, which is fully written in this archive.
- `frontend/observability-frontend/SKILL.md` line 212 — *"Phase 6 will fill section refs."*

**Fix:** delete both; the phases they refer to are done.

## 5. Expired example

`backend/feature-management-patterns/SKILL.md:151` — `// SUNSET: 2026-09-15`, a date now in the past, in a pack
whose whole point is sunset discipline.

**Fix:** use a relative example (`// SUNSET: <ISO date, ~1 quarter out>`), not a literal that rots.

## 6. `memory/auth_contract.md` is a hard reference target but is unfinished

8 unfilled markers (`fill 6f`, `unknown — confirm with team`), including the entire Portal session and token-storage
rows. It is a `references:` target of **four** packs: `backend-architecture`, `infrastructure-wiring`,
`react-admin-patterns`, `react-native-patterns`.

**Fix:** make it a clearly-labelled skeleton with headings and no half-facts, or finish it. A half-filled file
reads as fact.

## 7. `system-context.md` is referenced 9 times and does not exist

Nine packs point at `.specify/memory/system-context.md` for project vocabulary — `api-endpoint-patterns`,
`backend-architecture`, `feature-management-patterns`, `infrastructure-wiring`, `integration-adapter-patterns`,
`orchestration-patterns`, `data-access-patterns`, `file-pipeline-patterns`, `search-patterns`. The archive ships
only `auth_contract.md` and `observability-stack.md`.

This is the single most load-bearing gap: the grammar-vs-vocabulary rule in the README depends on that file
existing, and every pointer to it currently dangles.

**Fix:** ship a `memory/system-context.md` skeleton alongside the other two.

---

## Structural notes (not defects, but they cost the adopter time)

- **Frontmatter is inert outside the `sk.*` router.** `when_to_load`, `co_loads_with` and `references` are custom
  SpecKit fields; a plain Claude Code install reads only `name` + `description`. Three packs —
  `observability-backend`, `data-access-patterns`, `observability-frontend` — have descriptions with **no trigger
  clause**, so they will not be model-invoked at all. The README's suggestion to add native `paths:` frontmatter
  should be verified against the current SKILL.md schema before being repeated; it is not a confirmed field.
- **Four placeholder conventions across the archive** — `YourContext.*` and `modules/<context>/` in backend packs,
  `{Module}` and `src/backend/modules/{Module}/…` in `skill-routing.example.md`, `apps/portal/src/…` in
  `observability-frontend`, and real-looking names (`listings-api`, `directory`) in `observability-stack.md`.
- **Governance data duplicated three ways.** The PII deny-list is copied from `observability-backend` §6 into
  `observability-frontend` §6 "for skill independence", and `observability-stack.md` says the Loki allow-list
  "lives verbatim" in `observability-backend` §7. Three copies of the same governance rules.
- **One project's V1 rollout state is baked into two packs.** `observability-backend` and `observability-frontend`
  carry "deferred from V1" / GlitchTip / Blackbox status that belongs in the project memory file — and is
  duplicated there already.
- **`design-styles.md` is off-stack and framework-coupled.** It catalogues Angular Material, PrimeNG/PrimeVue,
  Nuxt, daisyUI, MUI and antd in an otherwise React/Next/Expo-only archive, and is the only file coupled to
  `/sk.init`, `/sk.design`, `project-config.md`, `tech-stack.md` and `architecture.md`.
- **The flat-install assumption is undocumented in the packs.** The README's `cp -r`, every path in
  `skill-routing.example.md`, and `observability-stack.md`'s opening line all assume
  `.claude/skills/<name>/SKILL.md` with no group folder. Keeping `backend/`, `data/` etc. on install breaks all
  of them.
- **`design-principles` cites a file that does not exist** — *"see api-standards.md Idempotency section"*.
