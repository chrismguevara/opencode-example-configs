---
name: api-contracts
description: Contract-first API changes with OpenAPI and AsyncAPI - authentication/authorization semantics in the spec, code generation with Orval, oapi-codegen, or Valibot generators where used, handling generated files, and verifying compatibility.
---

# API contracts

Use this skill for any change to an HTTP API (OpenAPI) or an event/streaming
API (AsyncAPI), and for any change to generated clients, servers, or schemas.

## Before you start

- Locate the specs (`openapi.yaml`/`.json`, `asyncapi.yaml`), the generator
  configs (`orval.config.*`, `oapi-codegen` config or `//go:generate` lines,
  Valibot/TypeScript schema generators), and the generated output folders.
- Identify the generate command (`pnpm generate`, `go generate ./...`, a
  Makefile target) and the validation command (`redocly lint`, `spectral`,
  `openapi-generator validate`, `asyncapi validate`).
- Confirm which spec version the tools support (OpenAPI 3.0 vs 3.1; AsyncAPI
  2.x vs 3.x). Generators do **not** support identical schema features:
  OpenAPI and AsyncAPI generators, and Orval vs oapi-codegen, differ on
  `oneOf`/discriminators, nullable, `format`, and `$ref` handling. Check the
  installed generator versions before using an advanced feature.

## Contract-first workflow

1. Update the specification (schemas, operations, security, examples).
2. Validate the specification with the repository's linter.
3. Regenerate code with the repository's generator command.
4. Run frontend and backend checks (typecheck, tests, build).
5. Inspect the generated diff: only expected files change; no unrelated churn
   (which usually means a generator version or config mismatch).

Never hand-edit generated files. If the output is wrong, fix the spec or the
generator configuration and regenerate.

## Authentication and authorization semantics

- Declare `securitySchemes` and per-operation `security` accurately; generated
  clients and middleware rely on them.
- Document authorization rules in the operation description (who may call it,
  ownership/tenant checks) so backend handlers implement them; the spec alone
  does not enforce authorization.
- Model `401` vs `403` vs `404` responses deliberately and consistently.

## Compatibility

- Additive changes (new optional field, new endpoint, new enum value only if
  clients tolerate unknown values) are backward compatible.
- Breaking changes (removing/renaming fields, changing types, making optional
  required, changing status codes) need a version bump or a migration plan
  agreed with consumers.
- Check consumers: generated TypeScript clients, Go stubs, other services
  subscribing to AsyncAPI channels.
- For events, keep message payload schemas backward compatible; consumers may
  lag producers.

## Generators used in this family

- **Orval** (TypeScript clients, TanStack Query hooks, optionally Valibot
  schemas): keep `orval.config.*` as the single source; regenerate after every
  spec change; do not edit the output folder.
- **oapi-codegen** (Go server interfaces/types/stubs): implement the generated
  interface in handler packages; keep the generated package untouched.
- **Valibot generation** where present: generated schemas are the runtime
  validation for API boundaries; hand-written Valibot schemas should not
  duplicate them.

## Verification

- Spec validation passes.
- Regenerated code compiles; typecheck and tests pass on both sides.
- The generated diff is limited to the intended change.
- For behavioral changes, add a handler/client test exercising the new contract.
