---
name: react-component-patterns
description: "Load when: designing or reviewing React component structure across any frontend surface. Component decomposition, TypeScript prop interfaces, custom hooks, react-hook-form + Zod forms, presentational vs container split, controlled vs uncontrolled inputs, the component-local vs cross-component state boundary, composition over configuration, and lucide-react as the canonical icon library."
when_to_load:
  - Any new component, hook, or feature module across portal/admin/mobile
  - Form design and validation (react-hook-form + Zod)
  - Custom hook extraction or review
  - Reviewing component structure, decomposition, or TypeScript props
  - Icon usage on web (lucide-react)
co_loads_with:
  - frontend-design-system
  - accessibility-standards
  - nextjs-patterns
  - react-admin-patterns
  - react-native-patterns
---

# React Component Patterns

## 1. Purpose
Production patterns for React component design across every frontend surface (customer portal, admin SPA, mobile). Covers decomposition rules, TypeScript prop interfaces, custom hook extraction, react-hook-form + Zod form composition, the presentational vs container split, controlled vs uncontrolled inputs, the boundary between component-local state and cross-component shared state, composition-over-configuration, and the canonical icon library. Excludes surface-specific data fetching, styling tokens and Tailwind/shadcn primitives, and a11y compliance rules beyond form-field wiring — those live in their own skills (see §5).

## 2. Core Rules

### 2.1 Component Decomposition
* **One component, one visual concern or one interaction.** If a component owns layout + fetching + form state + rendering, split it. ~150 lines is the soft heuristic — past that, almost always more than one concern is bundled.
* **Co-locate** the component, its types, its tests, and (if non-Tailwind) its styles. Move to a shared `components/` folder only when reused in 3+ places — speculative shared abstractions rot fast.
* **No barrel exports** for primitives. `import { Button } from '@/components/ui/button'` — never `from '@/components/ui'`. Tree-shaking and grep-ability both win.
* **`asChild` (Radix / shadcn pattern)** for behaviour-on-arbitrary-element: `<Button asChild><Link to="/">Home</Link></Button>` renders the link with button styling and semantics. Use when behaviour and element type must vary independently.

```
features/listings/
├── components/
│   ├── ListingCard.tsx          # Presentational
│   ├── ListingCard.test.tsx
│   ├── ListingFilters.tsx       # Controlled form
│   └── ListingStatusBadge.tsx   # Pure display
├── hooks/
│   ├── useListingFilters.ts     # Filter-state hook
│   └── useListingMap.ts         # Map-interaction hook
└── types.ts
```

### 2.2 TypeScript Prop Interfaces
* **Every component has an explicit `{ComponentName}Props` interface** with `readonly` props. Required props have no `?`; optional have `?`. Defaults via destructuring, not `defaultProps`.
* **No `any`, no `object`, no bare `{}`.** Every prop is typed. `unknown` is fine when the shape is genuinely deferred to the consumer.
* **`React.ReactNode` for children** — not `JSX.Element` (too narrow), not `React.ReactElement` (excludes strings/numbers/fragments).
* **Extend native HTML element props** for wrapper components: `interface ButtonProps extends React.ComponentProps<'button'>` — picks up every native attribute including refs, ARIA, and event handlers. Prefer over `ButtonHTMLAttributes<HTMLButtonElement>` when you don't need to discriminate.
* **Discriminated unions for variant props** when a prop's presence implies others:
  ```tsx
  type DialogProps =
    | { variant: 'controlled';   open: boolean; onOpenChange: (open: boolean) => void }
    | { variant: 'uncontrolled'; defaultOpen?: boolean };
  ```
* **Export prop interfaces** for compound components — consumers building composition need them.

```tsx
interface ListingCardProps {
  readonly listing:    ListingSummary;
  readonly onSave?:    (id: string) => void;
  readonly className?: string;
}

export function ListingCard({ listing, onSave, className }: ListingCardProps) { /* ... */ }
```

### 2.3 Custom Hooks
* **Extract event handlers, state, and side effects** out of components into `use{Concern}` hooks when the logic is non-trivial or reused.
* **Hooks return a stable object** with named values and callbacks. Stabilise callbacks with `useCallback` if the hook's consumer is memoised.
* **Hooks must not render JSX.** Components must not own complex business logic — split until both halves are simple.
* **Cleanup discipline**: if a hook subscribes to anything (event listeners, observers, timers, network), it returns a dispose function OR uses `useEffect` cleanup. No fire-and-forget subscriptions.
* **Don't extract a hook used once.** Inline use of `useState` + `useEffect` in a component is fine. Hooks earn their existence by reuse or by separating a genuinely complex concern from a simple render.

```ts
// hooks/useListingFilters.ts
export function useListingFilters(initial: ListingFilters) {
  const [filters, setFilters] = useState(initial);

  const updateFilter = useCallback(
    <K extends keyof ListingFilters>(key: K, value: ListingFilters[K]) =>
      setFilters((prev) => ({ ...prev, [key]: value })),
    [],
  );

  const resetFilters = useCallback(() => setFilters(initial), [initial]);

  return { filters, updateFilter, resetFilters };
}
```

### 2.4 Forms — react-hook-form + Zod
All forms use `react-hook-form` + Zod schema validation. Never build form state with `useState` chains.

* **Schema-first.** Define the Zod schema; derive the form type via `z.infer<typeof schema>`. The schema is the single source of truth for shape, validation, and TypeScript types.
* **`useForm({ resolver: zodResolver(schema) })`** — validation runs on submit and re-validates on field change after first submit attempt.
* **On web, compose with shadcn `<Form>`**: `<Form>` → `<FormField>` → `<FormItem>` → `<FormLabel>` + `<FormControl>` + `<FormMessage>`. `<FormMessage>` auto-renders the Zod validation error from `formState.errors`.
* **Server-side errors** map back via `form.setError('fieldName', { message })` after the API call. Never throw plain `Error` from a server action / mutation handler — return a typed result.
* **Pending state** comes from `form.formState.isSubmitting`. Never manage pending separately.
* **Form a11y** — required-field markers, `aria-describedby` linking errors, `aria-invalid` on the invalid input, error live-region announcement — lives in `accessibility-standards`. This skill writes the form composition; that skill owns the a11y wiring contract.

```tsx
const CreateListing = z.object({
  title:       z.string().min(5, 'Title must be at least 5 characters').max(120),
  price:       z.number().positive('Price must be greater than 0'),
  description: z.string().optional(),
});
type CreateListing = z.infer<typeof CreateListing>;

export function CreateListingForm({ onSuccess }: { onSuccess: () => void }) {
  // FORM: zodResolver attachment; schema is canonical source of shape + validation
  const form = useForm<CreateListing>({
    resolver:      zodResolver(CreateListing),
    defaultValues: { title: '', price: 0, description: '' },
  });
  const mutation = useCreateListing();

  async function onSubmit(data: CreateListing) {
    const result = await mutation.mutateAsync(data);
    if (result.ok) onSuccess();
    else form.setError('title', { message: result.error });
  }

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
        <FormField control={form.control} name="title" render={({ field }) => (
          <FormItem>
            <FormLabel>Title</FormLabel>
            <FormControl><Input placeholder="Listing title" {...field} /></FormControl>
            <FormMessage />
          </FormItem>
        )} />
        <Button type="submit" disabled={form.formState.isSubmitting}>
          {form.formState.isSubmitting ? 'Saving…' : 'Create Listing'}
        </Button>
      </form>
    </Form>
  );
}
```

### 2.5 Presentational vs Container
* **Presentational components** receive all data via props. No fetching, no direct store access, no router calls. Trivially testable in isolation.
* **Container / feature components** fetch data (via the surface's data layer — TanStack Query, Next.js Server Component, etc.), read shared stores, and pass primitives down to presentational children.
* **Rule of thumb**: if you can test it with props alone, it's presentational. If it needs mocks for hooks or stores, it's a container — integration-test it.
* Data fetching lives in containers, **never** in presentational children. The presentational layer doesn't know whether data came from cache, network, or a fixture.

### 2.6 Controlled vs Uncontrolled
* **Default to controlled** (`value` + `onChange`) for any input that participates in form state, validation, or cross-component coordination. React 19's automatic batching keeps controlled inputs cheap.
* **Uncontrolled** (refs, `defaultValue`) only for: very large lists with per-row inputs where every keystroke re-render is measurable, focus management, scroll containers, third-party libraries that own DOM internals.
* **Never mix controlled and uncontrolled on the same field.** React warns; behaviour is unpredictable across renders. Pick one per input.

### 2.7 State Boundary
* **Component-local UI state** (`useState`, `useReducer`) — state that no other component reads and that resets when the component unmounts. Form-internal toggles, hover/focus tracking, expand/collapse, inline edits.
* **Cross-component shared state** (Zustand) — state needed by two or more components that are not in a parent/child relationship. Auth session, theme preference, sidebar open/closed, offline action queue. **Selector hygiene, persist, hydration safety, and the "what belongs" decision rule** live in `zustand-state-management` — this section names the boundary; that skill owns the store-design contract.
* **Server state** (TanStack Query on Admin SPA / Mobile, Next.js fetch on Portal) — never in `useState` or Zustand. The surface skill owns this rule.
* **Form state** (react-hook-form) — never duplicate into `useState`. Read via `form.watch` / `form.getValues` / `form.formState` instead.

### 2.8 Composition over Configuration
* **Compose with `children`, slot props, and `asChild`** — not boolean configuration props.
* **More than 2 boolean `show*` / `hide*` / `with*` props** on a component is a refactor signal — replace with a compound component, named slots, or render props.
* **Named slots** for layout primitives: `<Card header={<...>} footer={<...>}>{body}</Card>` — clearer than `<Card showHeader showFooter headerText="..." />`.
* **Render props sparingly** — they're powerful but obscure. Reach for them when the parent must control rendering inside the child (virtualised lists, popover positioning); otherwise prefer composition.

### 2.9 Icons — lucide-react (web canonical)
* **`lucide-react` is the canonical icon library on web** (Portal + Admin SPA). On mobile, the Lucide RN port (`lucide-react-native`) is the equivalent — same iconography, native primitive.
* **Tree-shakeable import**: `import { CheckIcon } from 'lucide-react'`. Never the default-export object or barrel re-exports.
* **Size and colour via Tailwind classes**, not props: `<CheckIcon className="size-4 text-primary" />`. The Lucide `size` and `color` props exist but bypass the design system tokens.
* **Icon-only interactive elements** need an accessible name. Wrap with the right ARIA: `<Button aria-label="Save"><HeartIcon aria-hidden="true" className="size-4" /></Button>`. The icon is decorative; the button carries the name.
* **Inline SVGs only for custom one-off icons** that Lucide doesn't ship. Inline SVG components live in `@/components/icons/` and follow the same `size-*` className contract.

## 3. Comment markers

### Owned by this skill
| Marker | Emit on | Semantics |
|---|---|---|
| `// FORM:` | The `useForm({ resolver: zodResolver(...) })` call | Marks the schema-to-form attachment point. Reviewers and CI verify that every form's source of truth is a Zod schema, not ad-hoc validation |

### Used but not owned
| Marker | Owner | Where it appears here |
|---|---|---|
| `// A11Y:` | `accessibility-standards` | Form-field error wiring, required-field semantics, icon-only button labelling — written here, contract owned there |

## 4. When to use
* Any new React component or feature module on any frontend surface.
* Form implementation (react-hook-form + Zod).
* Custom hook extraction or review.
* Reviewing component structure, prop typing, decomposition, or composition.
* Icon usage on web (lucide-react sizing, accessibility wrapping).

## 5. When NOT to use
* **Surface-specific data fetching** (Server Components / Server Actions on Portal, TanStack Query loaders on Admin / Mobile) — see `nextjs-patterns`, `react-admin-patterns`, `react-native-patterns`.
* **Styling tokens, Tailwind v4 config, shadcn primitives, CVA, dark mode** — see `frontend-design-system`.
* **WCAG compliance details** (keyboard navigation, focus management, screen-reader testing, contrast verification) — see `accessibility-standards`.
* **Cross-component state design** (store shape, persist middleware, selectors) — see `zustand-state-management`.
