# Project instructions

Global rules from `~/.config/opencode/AGENTS.md` apply first. This file adds the
conventions for this repository. Project skills live in `.agents/skills/`; load
the relevant skill before working in that area.

## Monorepo

This repository may contain several applications and packages. Repositories in
this family may use:

- React, TypeScript
- TanStack Router, TanStack Query
- TanStack Start (only in selected applications)
- Valibot
- shadcn/ui, Tailwind
- CesiumJS / Resium, MapLibre, Turf
- Go HTTP API backends
- OpenAPI and AsyncAPI contracts
- generated TypeScript clients and generated Go interfaces/stubs

Do not assume every project uses every technology. Inspect the actual
application first: its `package.json` / `go.mod`, its router setup, its map
engine, its generated-code folders, and its existing tests.

## Frontend

- Follow the architecture already present in the application.
- Do not introduce Next.js patterns into a TanStack Router SPA.
- Do not introduce TanStack Start unless the application actually uses Start.
- Do not introduce Effect unless explicitly requested.
- Prefer small, composable React components.
- Avoid: unnecessary effects, duplicated derived state, unnecessary
  abstraction, recreating components that already exist.
- Follow accessibility conventions (semantic elements, labels, keyboard
  support, focus management).

### TanStack Router

- Use typed routing (route objects, typed `Link`/`navigate`, typed params).
- Use validated search parameters (Valibot where the project uses it).
- Preserve unrelated search parameters during navigation.
- Treat missing, invalid, cleared, and defaulted search parameters distinctly
  when behavior requires it.
- Do not introduce another URL-state abstraction.
- See the `tanstack-router` skill.

### TanStack Query and realtime

- Use the existing query-key conventions.
- Avoid duplicate subscriptions and duplicate requests.
- Respect existing WebSocket ownership (one owner, shared consumers).
- Handle reconnect, cleanup, stale data, and component lifecycle explicitly.

### Utility functions

- Prefer `es-toolkit` if the project already uses it.
- Avoid adding Lodash merely for equivalent functionality.

## Mapping

Use the map engine the application already chose. Do not replace MapLibre
with Cesium or vice versa without an architectural reason.

For Cesium (see the `cesium` skill):

- inspect render-loop behavior before adding work per frame
- avoid unnecessary continuous rendering; prefer request-render mode
- manage entity/primitive lifecycle
- clean up subscriptions and event handlers

For MapLibre:

- preserve the existing source/layer lifecycle
- preserve URL-driven map state
- clean up event listeners
- use the project's installed MapLibre version and its API

Use Turf for geospatial computations when appropriate (see the `turf` skill).

## Go backend

- Follow the existing HTTP/router conventions.
- Prefer explicit error handling; do not panic for normal application failures.
- Never write response headers/body more than once.
- Respect request context cancellation.
- Follow existing concurrency patterns.
- Run `gofmt`, focused Go tests, and the repository's configured Go linter.
- See the `go-backend` skill.

## API contracts

Follow contract-first design (see the `api-contracts` skill). For OpenAPI or
AsyncAPI changes:

1. Update the specification.
2. Validate the specification.
3. Regenerate code with the repository's generator.
4. Run frontend and backend checks.
5. Inspect the generated diff.

Do not hand-edit generated files.

## Browser verification

Use the `browser` subagent (Playwright CLI, not Playwright MCP) for UI checks
against a local dev server or an authorized test environment. See the
`playwright` skill.

## Verification checklist

Before reporting completion run what applies to the touched packages:

- `oxfmt --check .` (or the project's format script)
- the project's lint script
- `tsc --noEmit` / the project's typecheck script
- focused unit/integration tests
- `gofmt -l`, `go vet`, focused `go test`, the configured Go linter
- build for the affected app
