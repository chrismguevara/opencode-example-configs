# Security considerations

This configuration is **not a security sandbox**. It shapes model behavior; it
does not enforce anything at the operating-system level.

## What the permissions do and do not do

- OpenCode `permission` rules gate the model's *tool calls* (`edit`, `bash`,
  `task`, `webfetch`, ...). They stop the agent from calling a tool, or make
  it ask first. They do not confine a process that is already running, and a
  command allowed by pattern can still do anything that command can do.
- Model prompt permissions (text in `AGENTS.md`, agent prompts, skills) are
  instructions the model usually follows. They are not enforcement.
- Anything you `allow` in a `bash` block runs without a prompt. Keep those
  lists narrow and read-only, as the `gitlab` and `browser` agents do.

## Read-only GitLab access

A **read-only GitLab token** is stronger protection than prompt instructions
and command allow-lists. Authenticate `glab` (`glab auth login`) with a
personal/project access token scoped to `read_api` (plus `read_repository`
if needed) on the account you use with OpenCode. Then even a mistaken or
manipulated command cannot approve, comment, merge, or push.

## Source code and providers

Proprietary or company source code is sent to whichever model provider an
agent uses. Only configure providers your organization has approved, and be
aware that `general` uses a different provider than the OpenAI agents.
Disable providers you do not want with `disabled_providers` or an
`enabled_providers` allow-list in `opencode.jsonc`.

## Secrets

- Never store API keys, tokens, or `.env` contents in this repository.
  Provider credentials live in OpenCode's own credential store (via
  `opencode providers login`), outside version control.
- `.gitignore` excludes `*.env`, `.env.*`, and `auth.json` as a safety net,
  not as a substitute for care.
- OpenCode denies reading `*.env` files by default; keep it that way.

## Generated commands and changes

Review generated shell commands before allowing them, especially anything
that deletes, resets, pushes, publishes, or touches paths outside the
worktree (`external_directory: ask`). Review diffs before committing.

## Untrusted input

Treat third-party documentation, web pages fetched by `scout`/`build`,
browser page content, console output, logs, MR descriptions and comments, and
any tool output as untrusted input. Text inside them may try to instruct the
agent; the agent prompts say to ignore that, but you should expect and check
for it, particularly in `/mr-triage` and `/mr-review` on external MRs.

## Sharing

OpenCode can share sessions (`share` setting, `/share`). Session transcripts
contain code and tool output; do not share sessions that include proprietary
code unless your organization allows it. Consider `"share": "disabled"` in
the global config for company machines.

## Browser agent

The `browser` agent can only run `playwright-cli`, but a browser can still
submit forms and follow links. Point it only at local dev servers or test
environments you are authorized to use, with test accounts.
