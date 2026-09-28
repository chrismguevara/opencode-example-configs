# Architecture

This configuration turns OpenCode into a small, fixed team: one lead engineer
that owns every change, and a handful of cheap, read-only specialists it can
call one level down.

```
                         User
                          |
                          v
                  GPT-5.6 Terra
                   build / lead
                          |
             +------------+-------------+
             |            |             |
             v            v             v
          explore       scout        general
           Luna          Luna        GPT-OSS
           low          medium        120B
             |
             +----------------------------+
                          |
                 other specialized
                    Luna agents
                          |
                    +-----+------+
                    |            |
                 browser       gitlab
                  Luna          Luna
                 medium        medium
```

## Agents

| Agent     | Mode     | Model                          | Reasoning | Steps | Writes | Shell                          | Web                 |
| --------- | -------- | ------------------------------ | --------- | ----- | ------ | ------------------------------ | ------------------- |
| `build`   | primary  | `openai/gpt-5.6-terra`         | high      | -     | yes    | ask (git read cmds allowed)    | fetch only          |
| `explore` | subagent | `openai/gpt-5.6-luna`          | low       | 8     | no     | none                           | none                |
| `scout`   | subagent | `openai/gpt-5.6-luna`          | medium    | 12    | no     | `go doc/list`, `npm/pnpm ls`   | fetch only          |
| `general` | subagent | GPT-OSS-120B (provider TBD)    | default   | 12    | no     | ask                            | none                |
| `browser` | subagent | `openai/gpt-5.6-luna`          | medium    | 18    | no     | `playwright-cli *` only        | none                |
| `gitlab`  | subagent | `openai/gpt-5.6-luna`          | medium    | 16    | no     | read-only `glab`/`git` only    | none                |

Hidden system agents (`compaction`, `title`, `summary`) run on Luna.

`build`, `explore`, `scout`, and `general` are configured in
`opencode/opencode.jsonc` (`explore` and `general` are OpenCode built-ins that
are re-pointed and locked down). `browser` and `gitlab` are Markdown agents in
`opencode/agents/`. `scout` and `general` get their role prompts from
`opencode/prompts/`.

## Responsibilities

**Terra (build)** understands the task, makes architectural decisions, decides
when delegation is useful, implements changes, integrates delegated findings,
reviews the resulting diff, runs verification, and reports what changed.

**Luna** handles high-frequency delegated work: repository exploration, symbol
and caller lookup, dependency investigation, documentation research, browser
testing, GitLab inspection, and small bounded investigations.

**GPT-OSS-120B (general)** handles large bounded analysis, log analysis,
repetitive transformations (proposed, not applied), independent second
opinions, and large read-only investigations where cheap inference is enough.
It is never the primary coding driver.

## Delegation policy

Exactly one level: `primary -> subagent`, never `primary -> subagent -> subagent`.
This is enforced twice:

- `"subagent_depth": 1` in the global config (also OpenCode's default).
- every subagent has `"task": "deny"`.

The `build` agent's `task` permission is an allow-list (`explore`, `scout`,
`general`, `browser`, `gitlab`); any other subagent name is denied.

Simple task:

```
Terra -> solve directly
```

Task with independent investigations:

```
Terra
  -> explore  (where is X, who calls it)
  -> scout    (how does library Y behave in the installed version)
  -> general  (analyze these logs / this large module)
  -> integrate findings, implement, verify, report
```

The global `AGENTS.md` tells Terra not to delegate trivial work and how to
phrase a handoff (objective, scope, files, constraints, expected output).

## Permission model

Global defaults (`opencode/opencode.jsonc`):

- `websearch: deny` everywhere. There is no general-purpose web-search agent.
- `webfetch: deny` by default; `build` and `scout` re-enable it for explicitly
  supplied documentation URLs.
- `bash: { "*": ask, git status/diff/log/show: allow }`.
- `external_directory: ask`, `skill: allow`.

Subagents tighten this further (see the table). Rules are wildcard patterns and
the last matching rule wins, which is why every restricted `bash` block starts
with `"*": deny` and lists specific commands afterwards.

`opencode debug agent <name>` prints the fully resolved rule list for any agent.

## Project layer

Each project adds `opencode.jsonc` (formatters, generated-directory
protection), `AGENTS.md` (stack conventions), and `.agents/skills/*/SKILL.md`
(on-demand, version-aware guidance). Project config is merged over the global
config; it never redefines models or agents unless a project really needs to.

## What is deliberately absent

- LiteLLM or any OpenAI-compatible proxy/gateway: models are called directly
  through OpenCode's provider integrations.
- Playwright MCP: the browser agent uses the Playwright CLI.
- Figma MCP.
- Automatic quota failover (see `QUOTA-FALLBACK.md`).
- Large reference/documentation repositories checked into projects.
