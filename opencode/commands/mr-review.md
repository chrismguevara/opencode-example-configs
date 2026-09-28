---
description: Read-only code review of a GitLab merge request with file/line findings. Usage /mr-review <MR number> [--repo group/project]
agent: build
---
Review GitLab merge request **$1** (extra arguments, if any: `$ARGUMENTS`).

Delegate fetching the MR metadata, diff, discussions, and pipeline status to the
`gitlab` subagent (read-only). If deeper context is needed for a changed file,
delegate to `explore` for callers/usages or `scout` for library behavior. Do not
modify GitLab, do not push, and do not change files in this repository.

Review the diff for:

- Correctness
- Regressions in existing behavior
- Security and authorization (auth checks, tenant/ownership boundaries, injection, secrets)
- API contracts (OpenAPI/AsyncAPI changes, generated clients/stubs, compatibility)
- Type safety
- Error handling (including partial failures and double writes of HTTP responses)
- Performance (N+1, unbounded loops, unnecessary re-renders or re-subscriptions)
- Tests (missing, weak, or not covering the changed behavior)

Return findings ordered by severity. For each finding include: severity,
file and line, the issue, evidence from the diff, a suggested fix, and whether it
is a confirmed defect or a possible concern. Finish with a short overall verdict
(approve / approve with nits / request changes) and a list of anything you could
not verify. The verdict is advice for me; do not submit it to GitLab.
