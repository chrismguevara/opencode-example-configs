---
name: tanstack-start
description: Rules for applications that actually use TanStack Start - server functions, server/client boundaries, middleware, server routes, authorization, server-only secrets, and deployment conventions. Not for plain TanStack Router SPAs.
---

# TanStack Start

**TanStack Router is not automatically TanStack Start.** Use this skill only
when the application depends on `@tanstack/react-start` (check `package.json`
and the Vite/Start config). Do not introduce Start into a Router-only SPA.

## Before you start

- Confirm the installed `@tanstack/react-start` version and the router version.
  Start's APIs have changed across releases; follow the installed version.
- Find the existing entry points (client/server entries, `app.config` or Vite
  config), how server functions are organized, and the deployment target.

## Server functions

- Define server functions with `createServerFn` per the project's pattern
  (method, input validation, handler).
- Validate inputs at the boundary with the project's validation library
  (Valibot where used). Treat all inputs as untrusted.
- Keep server functions small and typed; return plain serializable data.
- Errors: throw/return in the project's established style so the client can
  distinguish expected failures (validation, not found, forbidden) from bugs.

## Server/client boundaries

- Code imported by a server function can run only on the server; do not leak
  server modules (DB clients, secrets, Node APIs) into client bundles.
- Use the project's `server-only`/`client-only` conventions or Start's
  boundary helpers; verify the client bundle does not include server code.
- Anything rendered on the server must be deterministic for hydration.

## Middleware

- Use Start middleware for cross-cutting concerns (auth context, logging,
  request IDs) following the existing composition order.
- Middleware that authenticates must run before any handler that needs the
  identity; do not re-implement auth checks ad hoc in handlers.

## Server routes (API endpoints)

- Put HTTP endpoints in server routes with explicit methods.
- Set status codes and content types deliberately; never write a response body twice.
- Respect request cancellation and time limits of the deployment target.

## Authorization

- Authorize on the server for every server function and server route, even if
  the UI already hides the action.
- Check ownership/tenancy on the resource, not only the user's role.
- Return the same response shape for "not found" and "forbidden" when leaking
  existence would matter.

## Server-only secrets

- Secrets come from server environment variables only; never expose them via
  `VITE_`/public env prefixes, loader data, or serialized props.
- Never log secrets or full request bodies containing credentials.

## Deployment / runtime

- Follow the repository's chosen adapter/runtime (Node, edge, container) and
  its constraints (no filesystem writes on edge, cold starts, streaming).
- Keep build configuration changes minimal and consistent with the existing
  deployment pipeline.

## Verification

- Typecheck, unit tests, and a production build of the app.
- Confirm no server-only module appears in the client bundle.
- Use the `browser` subagent for a cold load, a server-function call, and an
  unauthorized access attempt against a local/test environment.
