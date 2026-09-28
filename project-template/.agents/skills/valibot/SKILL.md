---
name: valibot
description: Runtime validation with Valibot - trust boundaries, schema composition, inferred TypeScript types, parse failure handling, reuse of shared schemas, and tests for malformed, missing, and invalid input.
---

# Valibot

Use this skill when validating data at any trust boundary in a TypeScript
project that uses `valibot`. Do not introduce another validation library
(Zod, Yup, io-ts, ...) when Valibot is already present.

## Before you start

- Check the installed `valibot` version. Valibot's API changed significantly
  at 0.31 (pipeline/`v.pipe`, actions like `v.minLength`); use the installed
  version's style, which you can confirm from existing schemas in the repo.
- Find shared schema locations (a `schemas/` package, generated schemas from
  the API contract, route search schemas) and reuse them before writing new ones.

## Trust boundaries

Validate where untrusted data enters:

- URL params and search params (TanStack Router `validateSearch`)
- API responses (unless a generated client already validates them)
- WebSocket / realtime messages
- form input, file uploads, `localStorage`, `postMessage`
- environment variables at startup

Do not re-validate data that is already typed and produced internally.

## Writing schemas

- Compose: build small schemas and combine them with `v.object`, `v.array`,
  `v.union`, `v.variant`, `v.picklist`, `v.pipe(...)`.
- Prefer `v.picklist`/`v.literal` unions over free strings for enums.
- Use `v.optional` / `v.nullable` / `v.nullish` deliberately; they are not
  interchangeable and affect the inferred type.
- Transform at the boundary (`v.transform`) so the rest of the code works
  with the final type (numbers, dates, branded ids).
- Keep schemas next to the type they describe; export the schema and derive the
  type with `v.InferOutput<typeof Schema>` (and `v.InferInput` when input and
  output differ). Never maintain a hand-written type alongside a schema.

## Handling failures

- Use `v.safeParse` when failure is an expected path (user input, URL);
  handle `result.issues` and map them to user-facing messages.
- Use `v.parse` only where a failure is a programming error or should abort
  the operation; let the surrounding layer convert it to an error response.
- Format issues with `v.flatten` (or the project's helper) for forms.
- Never swallow validation errors silently; log or surface them.

## Reuse

- Shared request/response schemas belong in the shared package used by both
  frontend and backend code generation, when the project has one.
- If schemas are generated from OpenAPI (see the `api-contracts` skill), do not
  hand-edit them; regenerate.

## Tests

For each new schema or boundary add focused tests covering:

- valid input -> expected output (including transforms)
- missing required fields
- wrong types and out-of-range values
- malformed strings (empty, whitespace, unicode, injection-like content)
- extra/unknown keys (confirm the strictness the project expects)
