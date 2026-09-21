---
name: frontend-design-system
description: "Load when: implementing or reviewing web UI styling — Tailwind v4 CSS-first config, HSL design tokens, @theme inline, shadcn/ui primitives, CVA variants, dark mode via .dark class, layout, typography, and animation primitives. Web-only (Portal + Admin SPA); NativeWind shares conceptual tokens but the design-system skill is web-specific."
when_to_load:
  - Any web styling decision (Portal or Admin SPA)
  - Tailwind v4 configuration, @theme blocks, design-token authoring
  - Adding or customising shadcn/ui components, CVA variants
  - Dark mode work or contrast token verification
  - Layout, typography, or animation primitive selection
co_loads_with:
  - react-component-patterns
  - accessibility-standards
  - nextjs-patterns
  - react-admin-patterns
---

# Frontend Design System (Tailwind v4 + shadcn/ui)

## 1. Purpose
Production styling system for web frontends (customer portal + admin SPA). Covers Tailwind v4 CSS-first configuration, the canonical HSL four-step token pattern, dark mode, shadcn/ui component rules, CVA variant composition, layout primitives, typography, and animation rules. Excludes React Native styling (NativeWind has different constraints), component decomposition and form composition, and accessibility compliance details beyond contrast tokens — those live in their own skills (see §6). Wiring (shadcn CLI installation, `next-themes` provider mounting, font loading registration) lives in deploy docs and root-layout setup files, not here.

> **Design aesthetic — decide once, then stay consistent.** Before styling a new surface, read the `Design Direction` seed, brand colour, and dark-mode preference from `project-config.md` (captured by `/sk.init`), then pick a concrete design style + component library from the catalogue in [design-styles.md](design-styles.md). Encode the decision in the design tokens (`globals.css` / theme) — those tokens are the single source of truth for the chosen aesthetic. When adding further UI, match the established tokens and style. Do not introduce a different visual style unless the user explicitly asks to change it.

## 2. Core Rules

### 2.1 Tailwind v4 — CSS-First Configuration
Tailwind v4 moves configuration out of JS into CSS. There is no `tailwind.config.js`.

* **All configuration lives in the global stylesheet** (`src/global.css` for Vite, `app/globals.css` for Next.js).
* **Single import**: `@import "tailwindcss";` — replaces `@tailwind base/components/utilities`.
* **Vite uses `@tailwindcss/vite` plugin**; Next.js has built-in v4 integration. Never PostCSS for new web projects.
* **Delete any legacy `tailwind.config.ts` after migration.** Its presence conflicts with v4 — v4 scans CSS-declared `@theme` blocks; a stale config file becomes confusing dead code.

### 2.2 Design Tokens — HSL Four-Step Pattern
The canonical token pattern for the codebase. Four steps, in order, every time.

```css
/* Step 1 — raw HSL components (NO hsl() wrapper, comma-less) at :root */
:root {
  --background:        0 0% 100%;
  --foreground:        240 10% 3.9%;
  --primary:           240 5.9% 10%;
  --primary-foreground:0 0% 98%;
  --secondary:         240 4.8% 95.9%;
  --secondary-foreground: 240 5.9% 10%;
  --muted:             240 4.8% 95.9%;
  --muted-foreground:  240 3.8% 46.1%;
  --accent:            240 4.8% 95.9%;
  --accent-foreground: 240 5.9% 10%;
  --destructive:       0 84.2% 60.2%;
  --border:            240 5.9% 90%;
  --input:             240 5.9% 90%;
  --ring:              240 5.9% 10%;
  --radius:            0.5rem;
}

/* Step 2 — dark-mode overrides on .dark */
.dark {
  --background:        240 10% 3.9%;
  --foreground:        0 0% 98%;
  --primary:           0 0% 98%;
  --primary-foreground:240 5.9% 10%;
  /* … remaining dark overrides */
}

/* Step 3 — expose to Tailwind utilities via @theme inline */
@theme inline {
  --color-background:        hsl(var(--background));
  --color-foreground:        hsl(var(--foreground));
  --color-primary:           hsl(var(--primary));
  --color-primary-foreground:hsl(var(--primary-foreground));
  --color-secondary:         hsl(var(--secondary));
  --color-muted:             hsl(var(--muted));
  --color-muted-foreground:  hsl(var(--muted-foreground));
  --color-accent:            hsl(var(--accent));
  --color-destructive:       hsl(var(--destructive));
  --color-border:            hsl(var(--border));
  --color-input:             hsl(var(--input));
  --color-ring:              hsl(var(--ring));
  --radius-DEFAULT:          var(--radius);
}

/* Step 4 — base layer applies token-driven defaults */
@layer base {
  *    { @apply border-border; }
  body { @apply bg-background text-foreground; }
}
```

* **Why HSL** — the lightness channel makes light/dark variants and hover/active states tunable by single-axis arithmetic. RGB and OKLCH work but break the shadcn convention; stick with HSL for compatibility with generated component code.
* **`@theme inline`** for single-theme light/dark systems (current project). Use plain `@theme` only when CSS variables must remain reactive across multi-theme runtime switches.
* **Never double-wrap** `hsl()`: `hsl(hsl(var(--foo)))` is an error.
* **Never use arbitrary colour values** (`bg-[#aabbcc]`, `text-[rgb(...)]`) for anything that should track the theme. Hardcoded colours bypass dark mode and contrast verification.

```tsx
// Acceptable escape hatch for a one-off brand asset that explicitly must not theme-track:
// COLOR: non-token hex; documented exception for partner-brand badge that must render in brand colours regardless of theme
<div className="bg-[#FF5A1F] text-white p-1 rounded">Featured Partner</div>
```

* **Contrast verification** — every token pair used together (`bg-primary` + `text-primary-foreground`, `bg-muted` + `text-muted-foreground`, etc.) must hit WCAG 2.2 AA minimum (4.5:1 normal text, 3:1 large) in both `:root` and `.dark`. Contrast rules and ratio details live in `accessibility-standards`.

### 2.3 Dark Mode
* **Toggle via `.dark` class on `<html>`** — never the `prefers-color-scheme` media strategy alone. The class lets users override the OS preference, which is required for accessibility (some users need light at night, dark by day).
* **Token swap, utilities unchanged.** Components use `bg-background text-foreground` regardless of mode. Adding dark support to a component is usually a no-op once the tokens are right.
* **`next-themes` is the canonical mode-controller** for the Next.js portal (`attribute="class"`); the Admin SPA toggles the class directly on `document.documentElement`. Mounting the provider is wiring — out of scope here. The patterns this skill cares about are how components consume the tokens, not how the toggle is wired.
* **Test both modes for every component.** A "dark mode bug" almost always means a hardcoded colour leaked past the four-step pattern.

### 2.4 shadcn/ui Rules
* **You own the code.** `npx shadcn@latest add <component>` writes files into `components/ui/`. Read them; customise them; commit them. They are NOT a dependency.
* **Customise via CSS variables and CVA, not by editing every component file.** When you need a new variant, add a CVA variant; don't fork the file.
* **Replace `space-x-*` / `space-y-*` with `flex gap-*` / `grid gap-*`.** Gap is consistent at the container boundary and works with wrapped layouts; `space-*` doesn't.
* **`size-N` for square dimensions**: `size-10` instead of `w-10 h-10`. Reads better, fewer chances of mismatch.
* **`cn()` (from `clsx` + `tailwind-merge`)** for ALL conditional class composition. Never string-concatenate Tailwind classes — `tailwind-merge` resolves conflicts (`p-2 p-4` → `p-4`) that naive concatenation breaks.
* **Semantic tokens everywhere.** `bg-background`, `text-foreground`, `text-muted-foreground`, `bg-primary`, `text-primary-foreground`, `border-border`, `ring-ring`. Never raw Tailwind colours (`bg-white`, `text-gray-500`) on UI components.
* **Overlay stacking is shadcn's job.** Never set `z-index` on `Dialog`, `Sheet`, `Drawer`, `DropdownMenu`, `Popover`, `Tooltip`. shadcn manages the stack internally; manual `z-*` breaks it.
* **Composite-component completeness:**
  * `Avatar` — always include `AvatarFallback`.
  * `Dialog` / `Sheet` / `Drawer` — always include `DialogTitle` / `SheetTitle` / `DrawerTitle` (accessibility requirement; visually-hidden if necessary).
  * `Card` — full structure: `Card > CardHeader > CardTitle [+ CardDescription] > CardContent > CardFooter`.
  * `Form` — `Form > FormField > FormItem > FormLabel + FormControl + FormMessage`. Never skip levels.
* **Validation state markers**: `aria-invalid` on the input control; `data-invalid` on the `<FormItem>` (CSS targets it for styling). Both required for full keyboard + screen-reader UX.

### 2.5 CVA — Variant Composition
`class-variance-authority` is the canonical pattern for multi-variant components. Define variants as full Tailwind class strings; merge with `cn()`.

```tsx
import { cva, type VariantProps } from 'class-variance-authority';

const buttonVariants = cva(
  'inline-flex items-center justify-center rounded-md text-sm font-medium transition-colors ' +
  'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring ' +
  'disabled:pointer-events-none disabled:opacity-50',
  {
    variants: {
      variant: {
        default:     'bg-primary text-primary-foreground hover:bg-primary/90',
        destructive: 'bg-destructive text-white hover:bg-destructive/90',
        outline:     'border border-input bg-background hover:bg-accent hover:text-accent-foreground',
        ghost:       'hover:bg-accent hover:text-accent-foreground',
        link:        'text-primary underline-offset-4 hover:underline',
      },
      size: {
        default: 'h-10 px-4 py-2',
        sm:      'h-9 px-3',
        lg:      'h-11 px-8',
        icon:    'size-10',
      },
    },
    compoundVariants: [
      { variant: 'outline', size: 'icon', class: 'bg-transparent' },
    ],
    defaultVariants: { variant: 'default', size: 'default' },
  },
);

export interface ButtonProps
  extends React.ComponentProps<'button'>,
          VariantProps<typeof buttonVariants> {}
```

* **Variants are full Tailwind class strings** — never CVA-referenced token names. The strings are what `tailwind-merge` resolves.
* **`defaultVariants` always set.** Components without defaults force every caller to specify every variant — friction without benefit.
* **`compoundVariants`** for cross-variant rules (e.g. "outline + icon = transparent background"). Keep the list short — if it grows, the component probably wants splitting.
* **Export `VariantProps<typeof X>`** when consumers need to compose variants externally.

### 2.6 Layout
* **Mobile-first responsive.** Base styles target mobile; add `sm:`, `md:`, `lg:`, `xl:`, `2xl:` for larger breakpoints. Don't write desktop-first then override down.
* **Grid for two-dimensional layouts** (`grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4`); flex for one-dimensional groups (`flex items-center gap-2`). `gap-*` not `space-*`.
* **`min-w-0` on flex children that contain truncated text.** Without it, `truncate` doesn't work inside flex — the child won't shrink below its content width.
* **Container queries** (Tailwind v4's `@container`) for components that adapt to their container rather than the viewport. Use when a component renders at multiple widths (sidebar vs main panel).
* **Sticky headers**: `sticky top-0 z-50 bg-background/80 backdrop-blur-sm` — the translucent + blur pattern. Solid sticky breaks visual context.
* **Sidebar layouts**: CSS Grid with explicit columns — `grid grid-cols-[240px_1fr]`. Never absolute positioning for sidebars; it doesn't reflow.

### 2.7 Typography
* **Font tokens via `@theme`** (`--font-sans`, `--font-display`, `--font-mono`). Bind to `next/font` on Next.js (zero CLS, self-hosted); on Vite, preload critical fonts via `<link rel="preload">`.
* **Type scale only** — `text-xs`, `text-sm`, `text-base`, `text-lg`, `text-xl`, `text-2xl`, `text-3xl`, `text-4xl`. Arbitrary sizes (`text-[15px]`) are a rule violation outside of display headings.
* **Fluid type for display headings only**: `text-[clamp(1.5rem,5vw,3rem)]`. Body text stays on the discrete scale — variable body sizes hurt readability.
* **`max-w-prose`** (≈65ch) on long-form text blocks. Lines longer than 75ch are measurably harder to read.
* **Heading hierarchy follows semantics, not size.** `<h1>` once per page; styling is independent of level. Visual emphasis ≠ heading level.

### 2.8 Animations
* **Tailwind `animate-*` for primitives** (`animate-spin`, `animate-pulse`, `animate-bounce`). Custom animations via `@keyframes` in the global stylesheet + a `--animate-*` token in `@theme`.
* **Transition durations** — micro-interactions 150 ms; layout transitions 200–300 ms. Longer than 300 ms feels sluggish; shorter than 100 ms reads as snap.
* **Respect `prefers-reduced-motion`.** Pair every animated element with `motion-reduce:transition-none` (or equivalent) — Tailwind's `motion-reduce:` variant flips on the media query.
* **`@starting-style`** (CSS) for enter animations on newly-rendered elements — no JS, no library. Pair with `transition-*` on the steady-state.
* **Framer Motion is non-canonical.** Only reach for it when a design genuinely requires spring physics, gesture-driven animation, or layout-id transitions that CSS can't express. The default is CSS.

## 3. Comment markers

### Owned by this skill
| Marker | Emit on | Semantics |
|---|---|---|
| `// COLOR:` | Any non-token colour usage (arbitrary hex, named colour, hardcoded rgba) | Flags an intentional escape hatch from the token system. CI greps for this — every emit must carry a one-line justification (e.g. brand asset, third-party widget, debug overlay) |

### Used but not owned
| Marker | Owner | Where it appears here |
|---|---|---|
| `// A11Y:` | `accessibility-standards` | Contrast-verification commentary on token pairs (§2.2), focus-visible style discussions |

## 4. Patterns / Examples

### Custom-themed shadcn card

```tsx
// components/listing-card.tsx
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";

interface ListingCardProps {
	listing: ListingSummary;
	className?: string;
}

export function ListingCard({ listing, className }: ListingCardProps) {
	return (
		<Card className={cn("hover:shadow-md transition-shadow", className)}>
			<CardHeader className="pb-2">
				<div className="flex items-start justify-between gap-2">
					<CardTitle className="text-base leading-snug line-clamp-2">
						{listing.title}
					</CardTitle>
					<Badge
						variant={
							listing.status === "active" ? "default" : "secondary"
						}>
						{listing.status}
					</Badge>
				</div>
			</CardHeader>
			<CardContent>
				<p className="text-2xl font-bold text-primary">
					{listing.formattedPrice}
				</p>
				<p className="text-sm text-muted-foreground mt-1">
					{listing.location}
				</p>
			</CardContent>
		</Card>
	);
}
```

### Responsive grid layout

```tsx
<div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
	{listings.map((l) => (
		<ListingCard key={l.id} listing={l} />
	))}
</div>
```

### Dark mode toggle (Next.js)

```tsx
"use client";
import { useTheme } from "next-themes";
import { Button } from "@/components/ui/button";
import { Sun, Moon } from "lucide-react";

export function ThemeToggle() {
	const { theme, setTheme } = useTheme();
	return (
		<Button
			variant="ghost"
			size="icon"
			onClick={() => setTheme(theme === "dark" ? "light" : "dark")}
			aria-label="Toggle theme">
			<Sun className="size-4 rotate-0 scale-100 transition-all dark:-rotate-90 dark:scale-0" />
			<Moon className="absolute size-4 rotate-90 scale-0 transition-all dark:rotate-0 dark:scale-100" />
		</Button>
	);
}
```

## 5. When to use
* Any web styling decision on Portal or Admin SPA.
* Adding or customising shadcn/ui components.
* Defining new design tokens (colour, spacing, typography, radius).
* Dark-mode implementation and verification.
* CVA variant authoring.
* Layout, typography, or animation primitive selection.

## 6. When NOT to use
* **React Native / NativeWind styling** — see `react-native-patterns`. NativeWind v5 shares tokens conceptually but the rules diverge (no `space-*` issues, no CSS-only `@starting-style`, platform colours via `platformColor()`).
* **Component composition, prop interfaces, form composition** — see `react-component-patterns`.
* **WCAG compliance** (keyboard, ARIA, focus management, screen-reader testing) — see `accessibility-standards`.
* **Surface-specific styling concerns** (RSC streaming considerations on Portal, view transitions on Admin SPA) — see `nextjs-patterns`, `react-admin-patterns`.
