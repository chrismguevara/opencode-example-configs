---
name: shadcn
description: Working with shadcn/ui and Tailwind in this codebase - reuse existing components, accessibility and semantic HTML, Tailwind conventions, responsive behavior, component API design, Storybook where present, and visual verification via the browser subagent.
---

# shadcn/ui

Use this skill when building or changing UI components in an app that uses
shadcn/ui (copied component source under `components/ui/` or the project's
equivalent) with Tailwind CSS.

## Before you start

- Locate the component directory and the `components.json` configuration.
  Note the style, base color, and alias paths; follow them.
- shadcn components are **owned source**, not a dependency. Assume they may be
  customized. Never overwrite an existing component with a fresh upstream copy
  (`npx shadcn add <name> --overwrite`) without diffing and confirming; local
  customizations would be lost.
- Check the installed Tailwind major version (v3 vs v4 configuration and class
  differences) and the installed `radix-ui`/`@base-ui` primitives.

## Reuse first

- Search for an existing component (`Button`, `Dialog`, `Form`, `DataTable`,
  ...) and existing composed patterns before creating anything.
- Extend via props/variants (`class-variance-authority` variants, `asChild`)
  rather than forking.
- Put app-specific compositions outside `components/ui/`; keep `components/ui/`
  close to upstream so future updates remain diffable.

## Accessibility and semantics

- Use semantic elements (`button`, `nav`, `main`, `label`, `table`), not
  clickable `div`s.
- Every interactive element needs an accessible name (visible label,
  `aria-label`, or `sr-only` text).
- Keep the primitive's keyboard behavior; do not intercept keys unless required.
- Preserve focus management in dialogs, menus, and comboboxes; do not remove
  focus rings, only restyle them (`focus-visible:`).
- Respect `prefers-reduced-motion` for animations where relevant.

## Tailwind conventions

- Use the design tokens (`bg-background`, `text-muted-foreground`, ...) instead
  of raw colors so themes and dark mode keep working.
- Merge classes with the project's `cn()` helper; do not concatenate strings.
- Keep responsive behavior explicit (`sm:`, `md:`, ...) and test at least
  mobile and desktop widths.
- Avoid arbitrary values unless there is no token; if you must, comment why.

## Component API design

- Small, composable components with typed props; forward `className` and
  `ref` where the wrapped primitive supports it.
- Prefer controlled/uncontrolled patterns consistent with the primitive
  (`value`/`defaultValue`, `onValueChange`).
- Do not add global state for local UI concerns.

## Storybook

- If the project has Storybook, add or update a story for new variants and
  states (default, loading, disabled, error, long content).
- Keep stories free of app data fetching; use static fixtures.

## Verification

- Typecheck, lint, format (`oxfmt`), and unit tests for the package.
- Ask the `browser` subagent to load the page or story, snapshot the component,
  exercise keyboard interaction, check the console for errors, and capture
  screenshots at a mobile and a desktop viewport.
