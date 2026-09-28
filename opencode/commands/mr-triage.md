---
description: Triage a GitLab merge request (read-only) and produce a prioritized action plan. Usage /mr-triage <MR number> [--repo group/project]
agent: build
---
Triage GitLab merge request **$1** (extra arguments, if any: `$ARGUMENTS`).

Delegate all GitLab inspection to the `gitlab` subagent. Do not run `glab`
yourself. Do not create, modify, comment on, approve, merge, or otherwise mutate
anything on GitLab or in the remote repository.

Ask the `gitlab` subagent for one concise report containing:

- MR title, description, author, state (open/draft/merged/closed), target branch
- Changed files and a summary of the relevant changes
- Outstanding (unresolved) discussions and any explicitly requested changes
- Pipeline status: failed jobs, incomplete or missing checks, with the failing job names
- Approval status and merge blockers reported by GitLab

Then prepare a **prioritized action plan** for the MR author/reviewer:

1. Blockers (failing pipelines, unresolved requested changes, merge conflicts)
2. Correctness or security concerns visible in the diff
3. Review follow-ups (open discussions that need a reply or a code change)
4. Nice-to-haves

For each item give: what to do, where (file/line or discussion), and why. Mark
anything you could not verify as unverified. Do not change any files unless I
explicitly ask afterwards.
