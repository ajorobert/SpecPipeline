# Design Styles & Component Library Reference

Consumed at **design time** by `/sk.design` (to choose and record a per-surface aesthetic) and at **implementation time** by the frontend engineer (to stay consistent with the recorded style). This is reference data, not an interview script — `/sk.init` deliberately does **not** present these tables; it only captures a one-line `Design Direction` seed in `project-config.md`.

## How it is used
1. `/sk.init` records a high-level `Design Direction` (one line) + dark-mode + brand colour + any Figma link in `project-config.md`.
2. `/sk.design`, for each frontend surface, expands that seed into a concrete style using the tables below, then records the chosen **Design Style** and **Component Library** in the surface's design output (architecture.md / design notes) and in `tech-stack.md`.
3. The frontend engineer reads the recorded style and matches it. New UI must not drift from it unless the user explicitly asks to change it.

## Component Library (pick once per frontend surface)
Recommend based on the surface's framework (from `tech-stack.md`):

| Component Library | Best For | Key Trait |
|---|---|---|
| **shadcn/ui** (Tailwind v4 + Radix) | Next.js, React, Nuxt | You own the code; composable; no version lock-in |
| **Ant Design (antd)** | React admin / enterprise dashboards | Rich data components (tables, forms, charts) |
| **Material UI (MUI)** | React | Google Material look and feel; large ecosystem |
| **PrimeNG / PrimeVue** | Angular / Vue 3 | Comprehensive component set; enterprise-ready |
| **Angular Material** | Angular | Official Google library; matches Angular conventions |
| **daisyUI** | Any Tailwind project | Pure CSS classes; no JS runtime overhead |
| **None / custom Tailwind** | Vanilla JS or minimal projects | Full control; no third-party dependency |

If not decided: recommend **shadcn/ui** for React/Next.js/Nuxt, **Angular Material** for Angular, **PrimeVue** for Vue 3.

## Design Aesthetic — Trending in 2026
| Style | Best For | Key Trait |
|---|---|---|
| Minimalism | Any project | Clean, whitespace-driven, nothing unnecessary |
| Glassmorphism | Dashboards, fintech, modern SaaS | Frosted glass panels, blur backdrops, subtle borders |
| Bento Grid | Portfolios, dashboards, landing pages | Card-based asymmetric grid layout |
| Neo-Brutalism | Startups, creative tools, dev tools | Bold borders, high contrast, intentional roughness |
| Aurora UI | SaaS, AI products | Soft gradient blobs, ambient glow backgrounds |
| Claymorphism | Consumer apps, mobile-first | Puffy 3D soft shadows, pastel tones |
| Corporate SaaS Design | B2B, admin, internal tools | Professional, data-dense, trust-signalling |
| AI-First Interface Design | AI/ML products | Conversational, streaming-text, dynamic components |
| Dark Mode Design | Developer tools, creative apps | Dark background as primary, not secondary |
| Swiss / International Typographic | Editorial, content-heavy sites | Grid-strict, typography-led, minimal decoration |

## Design Aesthetic — Classic / Established
| Style | Best For |
|---|---|
| Flat Design | Simple apps, mobile |
| Material Design | Google-ecosystem apps, Android |
| Fluent Design | Microsoft-ecosystem, Windows apps |
| Neumorphism (Soft UI) | Health, lifestyle apps |
| Card-Based Design | Feeds, e-commerce, news |
| Dashboard-Centric | Analytics, operations tools |
| Landing Page Design | Marketing, SaaS homepages |
| Retro / Y2K / Vaporwave | Niche creative / brand |

The user may also describe a custom aesthetic in plain language (e.g. "dark, techy, cyberpunk with green accents"). Record it verbatim.

## Recommended Combinations by Project Type
| Project Type | Recommended Style Combination | Why |
|---|---|---|
| Admin / internal tool | Minimalism + Corporate SaaS + Card-Based | Data-dense, low distraction |
| SaaS dashboard | Minimalism + Bento Grid + Glassmorphism accents + Dark Mode | Modern SaaS standard in 2026 |
| Marketing / landing page | Minimalism + Aurora UI or Glassmorphism | High-polish, conversion-focused |
| E-commerce / consumer | Flat Design + Card-Based + Minimalism | Product-forward, trust-building |
| Developer tool / CLI companion | Neo-Brutalism or Dark Mode + Swiss Design | Dev-native aesthetic |
| AI product | AI-First Interface + Aurora UI + Dark Mode | Familiar to AI-native users |
| Content / editorial | Swiss Design + Magazine Style | Typography-led, content-first |
| Creative / portfolio | Bento Grid + Glassmorphism or Neo-Brutalism | Attention-grabbing, memorable |
| Personal tool / prototype | Minimalism | Fast to build, no distraction |
