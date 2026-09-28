---
name: tanstack-router
description: Conventions for TanStack Router SPAs - typed routes, validated search params, navigation that preserves unrelated URL state, and handling absent/invalid/cleared/default values, refresh, back/forward, and bad URLs.
---

# TanStack Router

Use this skill when adding or changing routes, links, navigation, loaders, or
URL search state in a React app that uses `@tanstack/react-router`.

## Before you start

- Check the installed version: `node_modules/@tanstack/react-router/package.json`
  (or the lockfile). API details differ across versions; do not rely on docs
  for a different major/minor.
- Find how routes are defined here: file-based (`routes/` + generated
  `routeTree.gen.ts`) or code-based (`createRoute`). Follow the existing style.
  `routeTree.gen.ts` is generated: never hand-edit it.
- Check whether the app uses TanStack Start. Router alone is a client-side
  router; Start-only APIs (server functions, server routes) do not apply.

## Typed routing

- Define routes with `createFileRoute` / `createRoute` so params, search, and
  loader data are typed end to end.
- Use typed `Link` / `useNavigate` with `to`, `params`, and `search`; never
  build URLs by string concatenation.
- Use `getRouteApi` or route-scoped hooks (`Route.useParams`, `Route.useSearch`,
  `Route.useLoaderData`) rather than untyped global hooks.

## Search parameter validation

- Every route that reads search params declares `validateSearch` (Valibot via
  the project's adapter when the project uses Valibot).
- Distinguish, when behavior requires it:
  - **missing**: key absent from the URL -> apply the default
  - **invalid**: key present but unparsable -> fail closed (default or error),
    never silently pass garbage through
  - **cleared**: key explicitly removed by the user -> remove it from the URL
  - **defaulted**: value equals the default -> decide (and keep consistent)
    whether it is stripped from the URL or written explicitly
- Keep the parsed type narrow (union literals, numbers, dates) and convert at
  the boundary; do not carry strings deeper than the route.

## Navigation and preserving state

- When updating one search key, spread the previous search:
  `search: (prev) => ({ ...prev, page: 2 })`. Never replace the whole object
  unless clearing everything is the intent.
- Use `replace: true` for transient UI state (filters typed live) and push
  navigation for user-meaningful steps so back/forward behaves as expected.
- Keep unrelated params (sort, filters, map viewport, selected id) intact
  across navigations and redirects.
- Use `useBlocker`/`beforeLoad` redirects sparingly and only per existing
  patterns.

## Refresh, back/forward, invalid URLs

- Every route must render correctly from a cold load (browser refresh): state
  needed to render must come from the URL, loaders, or persisted stores, not
  from in-memory state set by a previous page.
- Back/forward must restore the previous search state; avoid effects that
  rewrite the URL on mount, which breaks history.
- Invalid params or search: rely on `validateSearch`/`parseParams` errors and
  the route's `errorComponent` / `notFoundComponent`; do not throw uncaught
  errors from components.
- Do not add a second URL-state layer (custom query-string hooks, manual
  `window.history` calls).

## Verification

- `tsc --noEmit` for the app (typed routes catch most mistakes).
- Existing route tests, if any.
- Ask the `browser` subagent to verify: cold load of the URL, back/forward,
  and that unrelated params survive a navigation.
