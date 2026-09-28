---
name: go-backend
description: Go HTTP backend conventions - Go version awareness, handlers, middleware, error handling, request context, concurrency, cleanup, generated interfaces from OpenAPI, gofmt, focused tests, linting, and race tests when appropriate.
---

# Go backend

Use this skill when changing Go services in this repository.

## Before you start

- Read `go.mod` for the Go version and the module layout; use only language
  and stdlib features available in that version (`go version` locally must
  match or exceed it).
- Identify the router/framework in use (`net/http` with `ServeMux`, chi, echo,
  gin, ...), the middleware chain, the error-response helper, and the logging
  library. Follow them; do not add a second framework.
- Find generated code (oapi-codegen output, protobuf, mocks) and the
  `go:generate` / Makefile targets that produce it.

## Handlers

- Keep handlers thin: decode/validate input, call the service layer, encode
  the response.
- Write headers before the body, and write the response exactly once. After
  writing an error response, `return`.
- Use the generated OpenAPI interface (oapi-codegen) as the contract; implement
  it in handler packages and never edit the generated package.
- Set explicit status codes; do not rely on defaults for errors.

## Middleware

- Compose middleware in the existing order (recovery, request id, logging,
  auth, then handlers). Authentication and authorization checks belong in
  middleware or the service layer per existing patterns, not scattered in handlers.

## Errors

- Return errors; do not panic for expected failures. Wrap with context
  (`fmt.Errorf("...: %w", err)`) and use `errors.Is`/`errors.As` at decision points.
- Map domain errors to HTTP status codes in one place.
- Never leak internal error text or stack traces to clients; log them
  server-side with the request id.

## Request context

- Pass `ctx` from the request into every downstream call (DB, HTTP, queues).
- Respect cancellation: check `ctx.Err()` in loops, use `ctx`-aware APIs, and
  do not spawn goroutines that outlive the request unless they are explicitly
  detached with their own context and lifecycle.
- Apply timeouts consistently (`context.WithTimeout`) where the project does.

## Concurrency and cleanup

- Follow existing patterns (worker pools, errgroup, channels). Every goroutine
  needs an owner and a way to stop.
- Protect shared state with the existing mutex/atomic conventions; avoid
  data races on maps and slices.
- `defer` cleanup (`Close`, `Rollback`, cancel funcs) immediately after
  acquisition.

## Verification

- `gofmt -l ./...` (or `gofmt -w` on changed files) must report nothing.
- `go vet ./...` on affected packages.
- Focused tests: `go test ./path/to/pkg/... -run TestName`.
- Run the repository's configured linter: `golangci-lint run` if
  `.golangci.yml`/`.golangci.yaml` exists, `staticcheck ./...` if the project
  uses it, or the Makefile lint target. The project's configuration wins over
  any personal preference; do not add a new linter config.
- Add `-race` for tests touching concurrency: `go test -race ./pkg/...`.
- Regenerate OpenAPI code after contract changes and confirm the generated
  diff is limited to the intended change.
