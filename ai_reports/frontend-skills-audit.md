# Frontend Skills Audit — SpecKit-SSD-SDLC

**Date:** 2026-06-26
**Scope:** The 8 frontend skills under `.claude/skills/` and the `sk.*` command wiring that loads them.
**Lens:** Does this produce production-grade, *consistent* code with minimal context bloat and minimal hallucination? Do the skills compose — referenced right, not too much, not missing?
**Philosophy applied:** Skills = grammar (the *how*, project-neutral). Project memory = vocabulary (the *what/where*, per-project). A grammar skill that hardcodes vocabulary, or a vocabulary fact that lives in a skill, is a defect.
**Assumes:** `ai_reports/monorepo-adaptation-analysis.md` is accepted (per-surface manifest + `active_surface` + per-project pack selection in `project.md`).

Skills in scope:
`accessibility-standards` · `frontend-design-system` · `react-component-patterns` · `zustand-state-management` · `nextjs-patterns` · `react-admin-patterns` · `react-native-patterns` · `observability-frontend`

---

## 1. Verdict

**The skill *content* is strong and consistent. The skill *loading wiring* is not — and that is where production consistency actually breaks.**

The eight skills are well-authored: tight scope, explicit "When NOT to use", owned-marker tables, and disciplined deferral (e.g. `react-component-patterns` hands a11y wiring to `accessibility-standards` and store design to `zustand-state-management` instead of restating them). Read in isolation, each is close to production grade and low-hallucination.

The problem is the **seam between the skills and the `sk.*` commands that inject them**. There are effectively *three* competing sources of truth for "which frontend skills load for surface X":

1. each skill's `co_loads_with` frontmatter,
2. each `sk.*` command's hardcoded load list (`sk.codegen`, `sk.scaffolding`, `sk.review`, `sk.test`, `sk.uat`, `sk.verify`, `sk.refactor`, `sk.perf`),
3. (incoming) the monorepo manifest's per-surface "always-load skill packs" in `project.md`.

They disagree with each other. The result is that **the same surface gets a different rule-set at generation time than at review time**, the **mobile surface is systematically under-loaded**, and **`observability-frontend` is never loaded by any command at all**. None of this is visible reading a single skill — it only surfaces when you trace composition, which is exactly the lens you asked for.

Severity summary:

| # | Finding | Severity | Class |
|---|---------|----------|-------|
| F1 | `observability-frontend` is injected by **zero** `sk.*` commands — fully orphaned | **P1** | Missing |
| F2 | Mobile is under-loaded at codegen: only `react-native-patterns`; no `react-component-patterns`, no a11y, no `zustand`, no observability | **P1** | Missing |
| F3 | Generate-time vs review-time load lists diverge (esp. mobile) → code reviewed against rules it was never generated under | **P1** | Inconsistent |
| F4 | `accessibility-standards` + `frontend-design-system` are web-only by self-declaration, yet loaded for **mobile** in `sk.review`/`sk.verify` → bloat + cross-stack hallucination risk | **P1** | Too much / wrong |
| F5 | Dangling pack path `auth-patterns/SKILL.md` in `sk.codegen`/`sk.scaffolding` (real skills: `authorization-patterns`, `keycloak-patterns`) | **P2** | Broken ref |
| F6 | `co_loads_with` frontmatter is decorative — not honoured by the loader, and contradicts the command lists | **P2** | Inconsistent |
| F7 | Cross-reference drift to `observability-frontend §11/§13` (wrong/absent sections); unfinished "Phase 6 will fill section refs" TODO | **P2** | Drift |
| F8 | Vocabulary leaks into grammar: "vendor mobile app" / `vendor_signup_completed`; inline `PortalSession` with `tenantId` claim | **P2** | Grammar/vocab |
| F9 | `zustand-state-management` & `accessibility-standards` lack the `when_to_load`/`co_loads_with` frontmatter the other 6 carry | **P3** | Metadata |
| F10 | `// FETCH:` marker owned by `nextjs-patterns` but emitted on all three surfaces; canonical marker index lives in `backend-architecture §7` (not loaded for FE-only work) | **P3** | Coupling |

---

## 2. What is strong — do not regress

These are the consistency assets. Preserve them through any refactor.

- **Deferral discipline / no duplication.** `react-component-patterns §2.7` names the state boundary then defers store design to `zustand`; `§2.4` writes form *composition* and defers form *a11y* to `accessibility-standards`; surface skills defer tokens to `frontend-design-system` and decomposition to `react-component-patterns`. Each rule has exactly one owner. This is the single biggest anti-hallucination property in the set.
- **Owned-marker tables.** Every surface skill carries an "Owned by this skill" vs "Used but not owned" marker table. The intent (one marker, one owning skill, CI-greppable) is excellent and rare.
- **Explicit "When NOT to use".** Each skill bounds itself and points at the right neighbour. This is what keeps a single skill from sprawling.
- **`observability-frontend` placeholder hygiene** (`yourcontext.portal`, `your_context.region`) is the *correct* grammar-vs-vocabulary model — the rest of the set should imitate it (see F8).
- **Backend fetch contract is genuinely uniform** across portal/admin/mobile (traceparent + bearer + Idempotency-Key, single wrapper, throw-on-missing-key in dev). Three surfaces, one contract, three idiomatic implementations. Textbook.
- **The skills self-document the seams** they don't own (auth claim contract → `authorization-patterns`/`auth_contract.md`, idempotency semantics → `api-endpoint-patterns`, PII deny-list duplicated deliberately for independence). Cross-refs resolve to real files (`auth_contract.md`, `observability-stack.md` both exist).

---

## 3. Detailed findings

### F1 — `observability-frontend` is orphaned (P1, Missing)
`grep -rn "observability-frontend" sk.*` returns **nothing**. No command injects it — not `sk.codegen`, `sk.scaffolding`, `sk.review`, `sk.test`, `sk.uat`, `sk.verify`, `sk.refactor`, or `sk.perf`.

Yet all three surface skills carry a `## Surface integration for observability-frontend` section and emit its markers (`// EVENT:`, `// MASK:`, `// CONSENT:`). So at codegen the agent is told *where* to place observability markers but never receives the skill that defines *what they mean*, the PII deny-list, the consent-gate rule, or the "no Clarity on admin/RN" rule. Net effect: telemetry, PII redaction and consent gating are silently absent from generated frontend code, or improvised (hallucinated). For a directory listing service handling user PII, this is a correctness-and-compliance hole, not a style nit.

**Fix:** add `observability-frontend` to the "Always" frontend list in `sk.codegen`, `sk.scaffolding`, `sk.review`, and the frontend branch of `sk.verify`/`sk.test`. Its own `when_to_load` already declares the trigger; the loader just never consulted it.

### F2 — Mobile under-loaded at generation (P1, Missing)
In `sk.codegen` and `sk.scaffolding`, the **Mobile** branch loads only:
```
Always: react-native-patterns
auth → auth-patterns   (also broken — see F5)
file/upload → file-pipeline-patterns
```
The Portal and Admin branches always add `react-component-patterns` + `accessibility-standards` (+ `frontend-design-system`) and conditionally `zustand`. Mobile gets **none** of those at codegen — despite:
- `react-component-patterns §1` explicitly claiming scope "across portal/admin/**mobile**" and `§2.9` giving mobile icon rules;
- `react-native-patterns §2.6` deferring store hygiene to `zustand-state-management`;
- `react-native-patterns.co_loads_with` listing all four.

So mobile component/hook/form/state code is generated with no component-pattern rules and no store rules. Consistency with web is impossible by construction.

**Fix:** Mobile "Always" should be `react-native-patterns` + `react-component-patterns` + `observability-frontend`, with `zustand` on the state trigger — **and a *mobile* a11y source** (see F4; do not just bolt on the web `accessibility-standards`).

### F3 — Generate-time ≠ review-time rule-sets (P1, Inconsistent)
The load lists are inconsistent *across commands* for the same surface:

| Surface | `sk.codegen`/`scaffolding` (generate) | `sk.review` | `sk.verify` (FE) |
|---|---|---|---|
| Portal | nextjs + design + component + a11y (+zustand/auth/file) | design + component + a11y + nextjs (+zustand) | design + a11y only |
| Admin | admin + design + component + a11y (+zustand) | design + component + a11y + admin (+zustand) | design + a11y only |
| Mobile | **react-native only** | design + component + a11y + react-native (+zustand) | design + a11y only |

Three commands, three different subsets. Mobile is the worst case: generated under 1 skill, reviewed under 5 (two of which are web-only). Reviewing code against rules it was never generated under produces review churn and non-deterministic outcomes — the opposite of the consistency goal. `sk.verify`'s frontend set (design + a11y, no surface skill, no component skill) is a third, narrower variant again.

**Root cause = F6:** there is no single definition of "the frontend pack for surface X"; each command re-invents it. This is precisely gap C / §4.1 of the monorepo analysis — the fix is to centralise pack selection (see §4).

### F4 — Web-only skills loaded for native; native a11y has no canonical owner (P1)
`accessibility-standards` declares *"When NOT to use: React Native mobile app (different accessibility API)"* and is entirely DOM/ARIA. `frontend-design-system` declares *"Web-only (Portal + Admin SPA)"* and is entirely Tailwind/shadcn/CVA. Both are correct to self-scope.

But `sk.review` (Role = frontend "Always") and `sk.verify` load **both** for *every* frontend story including Mobile. Consequences:
- **Context bloat:** ~390 lines of web Tailwind/shadcn/DOM-ARIA injected into mobile reviews where almost none applies.
- **Hallucination risk:** an agent holding `frontend-design-system` during RN review may "correct" RN toward shadcn `<Dialog>`/`data-clarity-mask`/CSS `@starting-style`, or apply DOM `aria-*` to native components — all wrong for RN, which uses `accessibilityRole`/`accessibilityLabel` (`react-native-patterns §2.11`).
- **A real gap underneath it:** mobile a11y *rules* live only inside `react-native-patterns §2.11`, but the cross-cutting WCAG truths (POUR, 44px target, contrast, reduced-motion) live in `accessibility-standards` framed as web-only. There is no project-neutral a11y core both surfaces can share, so the framework either over-loads web a11y onto mobile or under-loads a11y entirely.

**Fix (structural):** split `accessibility-standards` into a small **cross-cutting core** (POUR, target size, contrast ratios, reduced-motion, the "blocking issue = not shippable" gate) + a **web-DOM implementation** appendix. RN references the core; `react-native-patterns §2.11` remains the native implementation. Stop loading `frontend-design-system` for mobile anywhere; if mobile needs token *concepts*, extract a tiny shared `design-tokens` note (see F8) rather than loading the web skill.

### F5 — Dangling `auth-patterns` path (P2, Broken ref)
`sk.codegen`/`sk.scaffolding` frontend branches route `auth → .claude/skills/auth-patterns/SKILL.md`. No such folder exists — the real skills are `authorization-patterns` and `keycloak-patterns`. A frontend auth story therefore resolves a non-existent pack (silent miss or improvised auth). Fix the path; for the portal/admin/mobile PKCE+session story the right target is likely `keycloak-patterns` (+ `authorization-patterns` for the claim contract).

### F6 — `co_loads_with` is decorative (P2, Inconsistent)
Six skills declare `co_loads_with`; the loader (`sk.*`) ignores it and hardcodes its own lists, which then disagree with it (e.g. RN co-loads `react-component-patterns`+a11y+observability+design; `sk.codegen` mobile loads none of them). Two sources of truth that contradict. The monorepo manifest is about to add a **third** (`project.md` "always-load skill packs"). Pick **one** SSOT. Recommended: the manifest's per-surface pack list (it's data, per the audit philosophy), and demote `co_loads_with` to documentation-only or delete it.

### F7 — Cross-reference drift (P2, Drift)
- `nextjs-patterns §4` titled *"Surface integration for observability-frontend §11"* — but `observability-frontend §11` is "RN-specific differences". Wrong target.
- `react-admin-patterns §4` and `react-native-patterns §4` both cite *"§13"* — which is "Comment markers", not a surface-integration section.
- `observability-frontend` has **no** "surface integration" section at all, and its `§14 References` literally say *"Phase 6 will fill section refs"* — an unfinished TODO shipped into the skill.

These broken section anchors are low-impact for a human but exactly the kind of stale pointer an agent will faithfully chase or fabricate around. Fix the anchors or make the references section-less ("see `observability-frontend`").

### F8 — Grammar/vocabulary leaks (P2)
- **App identity disagreement + leak:** `react-native-patterns §1` calls it *"the vendor mobile app"* and `observability-frontend §5` uses `vendor_signup_completed`, but `monorepo-adaptation-analysis` index.md calls mobile *"Customer mobile app"*. "vendor"/"customer" is project vocabulary and must not live in a grammar skill — and the two disagree. Replace with a neutral phrase ("the mobile app") and move any audience naming to `projects/mobile/project.md`.
- **Inline session shape:** `nextjs-patterns §2.6` hardcodes `PortalSession` including the project-specific `tenantId` custom claim, while `react-admin-patterns`/`react-native-patterns` correctly defer `AdminSession`/`MobileSession` to `.specify/memory/auth_contract.md`. Asymmetric, and it embeds a tenancy fact into grammar (violates CLAUDE.md's placeholder convention). Make the portal defer to `auth_contract.md` like the other two.
- The running `listing*` examples are fine as illustrative grammar (consistent across all skills); leave them.

### F9 — Frontmatter shape inconsistency (P3, Metadata)
`zustand-state-management` and `accessibility-standards` carry only `name` + `description`; the other six carry `when_to_load` + `co_loads_with` (+ `references`). Whatever the chosen loading SSOT (F6), normalise the frontmatter schema across all eight so tooling can read it uniformly. `observability-frontend` also uses a block-scalar `description:` while others use a quoted string — pick one.

### F10 — Marker ownership coupling (P3)
`// FETCH:` is "owned by `nextjs-patterns`" yet emitted in `react-admin-patterns` and `react-native-patterns` too. For a *mobile-only* or *admin-only* change, the marker's owning skill isn't loaded, so its contract is absent. Similarly the *canonical* marker index sits in `backend-architecture §7`, never loaded for FE-only work. Consider a small shared "frontend fetch contract" owner (or move `// FETCH:` ownership to a surface-neutral place) and mirror the marker index into a frontend-reachable location.

---

## 4. Recommended fixes (prioritised, and how they ride the monorepo manifest)

The monorepo adaptation is the right vehicle for the P1s — most of them are the same disease it already diagnoses (surface guessed, pack selection scattered).

**Now (P1 — blocks consistency):**
1. **Define the frontend pack per surface in ONE place** = `projects/{web,admin,mobile}/project.md` "always-load skill packs" (manifest §4.1). Every command reads that list via the shared surface-resolution preamble (analysis §4.3). This single change resolves F1, F2, F3, and F6 at once. Proposed canonical sets:
   - **web:** `nextjs-patterns`, `react-component-patterns`, `frontend-design-system`, `accessibility-standards`, `observability-frontend` (+`zustand` on state, +`keycloak-patterns`/`authorization-patterns` on auth, +`file-pipeline-patterns` on upload)
   - **admin:** `react-admin-patterns`, `react-component-patterns`, `frontend-design-system`, `accessibility-standards`, `observability-frontend` (+`zustand`, +auth/file as above)
   - **mobile:** `react-native-patterns`, `react-component-patterns`, `accessibility-standards` *(core only — F4)*, `observability-frontend` (+`zustand`, +auth/file) — **no `frontend-design-system`**
2. **Split `accessibility-standards`** into cross-cutting core + web-DOM appendix; point `react-native-patterns §2.11` at the core (F4). Until split, at minimum stop loading `frontend-design-system` for mobile in `sk.review`/`sk.verify`.
3. **Fix the `auth-patterns` path** (F5).

**Next (P2 — drift/leaks):**
4. Demote/delete `co_loads_with` once the manifest is the SSOT (F6).
5. Fix observability section anchors and remove the "Phase 6" TODO (F7).
6. De-leak vocabulary: neutralise "vendor", move audience naming to memory, make portal session defer to `auth_contract.md` (F8).

**Polish (P3):**
7. Normalise frontmatter schema across all eight (F9).
8. Reconsider `// FETCH:` ownership + mirror the marker index for FE-only reach (F10).

---

## 5. Answers to your three lens questions

**Does this produce production-level, *consistent* code?**
*Per skill, yes; per pipeline, not reliably.* The content is production grade, but because generate-time and review-time load different rule-sets (F3) and mobile is under-loaded (F2), two runs of the "same" frontend story can diverge — and mobile diverges from web by construction. Centralising pack selection (fix #1) is what turns the strong content into consistent output.

**Without context bloat?**
*Mostly, with two leaks.* The skills are well-sized and defer instead of restate (no internal bloat). The bloat is at the wiring: web-only `frontend-design-system` (211 lines) + DOM `accessibility-standards` (176 lines) loaded into *mobile* review/verify where they don't apply (F4). Fixing #1/#2 removes ~390 lines of irrelevant context from every mobile run.

**Minimal hallucination?**
*Good foundations, two real risks.* Deferral discipline and owned-marker tables minimise it. The risks: (a) `observability-frontend` orphaned (F1) — markers placed with no defining rules → improvised telemetry/PII handling; (b) web skills on native (F4) → agent applies shadcn/DOM-ARIA to RN. Both are wiring-level, both fixed by the same recommendations. Stale section anchors (F7) and the dangling `auth-patterns` path (F5) are smaller fabrication invitations.

**Do they compose — referenced right, not too much, not missing?**
*The skills reference each other correctly; the commands do not.* Inter-skill cross-refs are accurate and resolve to real files. The composition failures are entirely in the command→skill injection layer: **missing** (observability everywhere; component/zustand on mobile), **too much** (web skills on mobile), and **inconsistent** (per-command subsets, decorative `co_loads_with`). One manifest-driven pack list per surface fixes the bulk of it.

---

## 6. Per-skill scorecard

| Skill | Content quality | Scope hygiene | Wiring status | Top issue |
|---|---|---|---|---|
| `react-component-patterns` | High | Excellent (defers a11y, store) | Loaded web+admin; **missing on mobile codegen** | F2 |
| `frontend-design-system` | High | Web-only, well-bounded | **Over-loaded onto mobile** in review/verify | F4 |
| `accessibility-standards` | High (web) | Web-only by declaration, but treated as universal | Loaded for mobile despite self-exclusion; no shared core | F4, F9 |
| `zustand-state-management` | High | Good | **Missing on mobile**; thin frontmatter | F2, F9 |
| `nextjs-patterns` | Very high | Excellent | Well-wired for web | F8 (inline `PortalSession`), F7 |
| `react-admin-patterns` | Very high | Excellent | Well-wired for admin | F7 |
| `react-native-patterns` | Very high | Excellent (owns native a11y/styling) | Best skill, **worst-wired surface** (F2/F3) | F2, F8 ("vendor") |
| `observability-frontend` | High | Good; correct placeholder model | **Never loaded by any command** | F1, F7 |

---

*Bottom line: you don't have a skills-content problem, you have a skills-loading problem. The frontend grammar is solid. Make the per-surface pack list a single piece of manifest data (which the monorepo work is already building), give mobile and observability their missing seats, and stop seating the web-only skills at the mobile table — and the consistency, bloat, and hallucination goals all fall out of that one structural change.*
