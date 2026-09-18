---
name: accessibility-standards
description: "Load when: implementing or reviewing any frontend UI for accessibility compliance. WCAG 2.2 AA, semantic HTML, keyboard navigation, ARIA, colour contrast, focus management, form accessibility."
---

# Accessibility Standards (WCAG 2.2 AA)

## Purpose
Production accessibility requirements for all web frontends (customer portal and admin SPA). Enforces WCAG 2.2 Level AA compliance — the legal and ethical baseline. Covers semantic HTML, keyboard navigation, ARIA implementation, colour contrast, focus management, form accessibility, and testing methodology.

## Core Rules

### WCAG 2.2 Compliance Target
* Level AA is the minimum for all production features. Level AAA targets where feasible (especially for core user journeys).
* POUR principles — every UI must be:
  * **Perceivable**: all information is available to all senses (not colour-only, alt text, captions).
  * **Operable**: all functionality is keyboard-accessible; no traps; adequate time.
  * **Understandable**: content is readable; inputs are labelled; errors are clear.
  * **Robust**: works with current and future assistive technologies.

### Semantic HTML — First Defence
* Use the correct HTML element for the job: `<button>` for actions, `<a>` for navigation, `<nav>`, `<main>`, `<header>`, `<footer>`, `<section>`, `<article>` for landmarks.
* Heading hierarchy: one `<h1>` per page; `<h2>–<h6>` follow logical document order. Never skip levels (h1 → h3).
* Lists: `<ul>/<ol>` for groups of related items. Never fake lists with `<div>` + CSS.
* Tables: `<thead>`, `<tbody>`, `<th scope="col|row">` for data tables. Do not use tables for layout.
* Never use `<div>` or `<span>` where a semantic element exists. Divs are for grouping with no semantic meaning.

### Keyboard Navigation — All Functionality Must Be Keyboard-Accessible
* Tab order follows visual reading order. Never use `tabindex > 0` — it disrupts natural tab flow.
* `tabindex="0"`: add to non-focusable elements that need programmatic focus. `tabindex="-1"`: for elements that receive programmatic focus only.
* Every interactive element must be reachable and operable by keyboard alone.
* Keyboard shortcuts for key UI patterns:
  * `Tab`/`Shift+Tab`: move between interactive elements.
  * `Enter`/`Space`: activate buttons and links.
  * `Arrow keys`: navigate within menus, tabs, radio groups, listboxes.
  * `Escape`: close dialogs, dropdowns, tooltips.
* **No keyboard traps**: users must always be able to move focus away from any component. Exception: modal dialogs — focus is intentionally trapped inside and released on close.

### Focus Management
* Never remove focus outlines: `outline: none` is forbidden. Provide a custom `:focus-visible` style instead.
* Minimum focus indicator: 2px solid with 3:1 contrast ratio between indicator colour and background.
* When opening a modal/dialog: move focus to the modal (first focusable element or the dialog element itself).
* When closing a modal: return focus to the trigger element that opened it.
* Route navigation (SPA): move focus to the page `<h1>` or a skip-to-content landmark after navigation.
* Skip links: `<a href="#main-content" class="sr-only focus:not-sr-only">Skip to main content</a>` — first focusable element on every page.

### ARIA — Use Sparingly, Correctly
* First rule of ARIA: use the native HTML element if one exists. ARIA is for cases where HTML semantics are insufficient.
* Required attributes:
  * `aria-label`: names an element when visible text label is absent (icon buttons, search inputs).
  * `aria-labelledby`: references a visible heading/label by ID.
  * `aria-describedby`: links additional descriptive text (hint text, error messages).
  * `aria-live="polite"`: announces dynamic content updates (toast notifications, status messages). `assertive` only for critical alerts.
  * `aria-hidden="true"`: removes decorative elements from the accessibility tree (icons inside labelled buttons).
  * `aria-expanded`, `aria-haspopup`, `aria-controls`: for disclosure widgets (dropdown, accordion).
  * `aria-current="page"`: for active navigation links.
  * `aria-invalid="true"` + `aria-describedby` pointing to error message: for invalid form fields.
* Never use `role="presentation"` or `aria-hidden` on focusable elements.
* Never add ARIA roles that duplicate the element's native semantics (`role="button"` on `<button>`).

### Colour Contrast
| Text type | AA minimum | AAA |
|---|---|---|
| Normal text (< 18pt / < 14pt bold) | 4.5:1 | 7:1 |
| Large text (≥ 18pt / ≥ 14pt bold) | 3:1 | 4.5:1 |
| UI components and graphical objects | 3:1 | — |

* Never convey information by colour alone. Always pair colour with text, icon, or pattern.
* Error states: red colour + error icon + error message text (three channels, not one).
* Verify contrast ratios for all shadcn/ui token combinations in both light and dark mode.
* Use browser DevTools or axe-core to check programmatically — do not rely on visual judgement.

### WCAG 2.2 Additions (New Requirements)
* **Target size**: minimum 24×24 CSS pixels for all interactive targets. Preferred: 44×44 pixels.
* **Dragging alternatives**: any UI that uses dragging must have a non-drag alternative (e.g., button to move items in a sortable list).
* **Focus not obscured**: focused element must not be fully hidden by sticky headers, cookie banners, or other fixed elements. Use `scroll-margin-top` to account for sticky headers.
* **Accessible authentication**: support paste on all password fields. Provide alternatives to cognitive tests (puzzles, image CAPTCHAs).
* **Consistent help**: if help/support UI appears on multiple pages, it must appear in the same location each time.
* **Redundant entry**: do not make users re-enter information within a session. Pre-fill when possible.

### Form Accessibility
* Every input has a visible `<label>` associated via `for`/`id` or wrapping. No placeholder-only labels.
* Required fields: `required` attribute + visual indicator. Never rely only on colour to mark required.
* Error messages:
  * Appear below the relevant input.
  * Described via `aria-describedby` on the input pointing to the error element's ID.
  * `aria-invalid="true"` set on the input when invalid.
  * Error text is specific: "Email must include @" not "Invalid email".
* Form submission errors: focus moves to the error summary at the top of the form, or to the first errored field.
* Success messages: announced via `aria-live="polite"` region.

### Images & Media
* Informative images: descriptive `alt` attribute (describes what the image conveys, not what it looks like).
* Decorative images: `alt=""` (empty string). Never omit `alt` entirely.
* Icon buttons: `aria-label` on the button element. `aria-hidden="true"` on the icon itself.
* Complex images (charts, diagrams): `alt` with brief description + long description via `aria-describedby` or adjacent text.
* Video: captions required for all spoken content. Transcript for all audio-only content.

### Testing Methodology
* **Automated** (catches ~35% of issues): axe-core (via `@axe-core/react` in dev, Playwright axe in CI), Lighthouse accessibility audit.
* **Keyboard** (manual): navigate the entire feature using Tab, Shift+Tab, Arrow keys, Enter, Escape only. Every interaction must complete.
* **Screen reader** (manual): NVDA + Chrome (Windows), VoiceOver + Safari (macOS/iOS). Verify all content is announced correctly.
* **Zoom**: test at 200% and 400% browser zoom — no horizontal scrolling, no overlapping content.
* **Reduced motion**: test with `prefers-reduced-motion: reduce` media query active. All animations must stop or simplify.
* Accessibility review is part of user acceptance testing — the story is not shippable with blocking a11y issues.

## Patterns / Examples

### Icon button (correct)
```tsx
<Button variant="ghost" size="icon" aria-label="Save listing">
  <Heart className="size-4" aria-hidden="true" />
</Button>
```

### Form field with error
```tsx
<FormField control={form.control} name="email" render={({ field, fieldState }) => (
  <FormItem>
    <FormLabel>Email address <span aria-hidden="true">*</span></FormLabel>
    <FormControl>
      <Input
        type="email"
        aria-required="true"
        aria-invalid={fieldState.invalid}
        aria-describedby={fieldState.invalid ? 'email-error' : undefined}
        {...field}
      />
    </FormControl>
    {fieldState.invalid && (
      <FormMessage id="email-error" role="alert">{fieldState.error?.message}</FormMessage>
    )}
  </FormItem>
)} />
```

### Skip link
```tsx
// _app.tsx or root layout
<a
  href="#main-content"
  className="sr-only focus:not-sr-only focus:fixed focus:top-4 focus:left-4 focus:z-50 focus:px-4 focus:py-2 focus:bg-background focus:text-foreground focus:rounded-md focus:shadow-lg"
>
  Skip to main content
</a>
<main id="main-content">{children}</main>
```

### Live region for toast announcements
```tsx
// Announce toasts to screen readers
<div aria-live="polite" aria-atomic="true" className="sr-only" id="toast-announcer">
  {latestToastMessage}
</div>
```

### Reduced motion
```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
```

## When to Use
* Implementing any frontend UI — accessibility is not an afterthought
* User acceptance testing — blocking issues prevent ship
* Quality gate verification — accessibility audit is mandatory
* Frontend code review — WCAG 2.2 AA items are on the checklist

## When NOT to Use
* Backend code, API design, or database schema
* React Native mobile app (different accessibility API — use React Native's `accessibilityLabel`, `accessibilityRole` instead)
