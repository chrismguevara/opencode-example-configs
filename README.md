# opencode-example-configs

A version-controlled [OpenCode](https://opencode.ai) configuration for a
software-engineering workflow: **GPT-5.6 Terra** leads, **GPT-5.6 Luna** does
the frequent cheap work, **GPT-OSS-120B** takes bounded read-only analysis, and
delegation is exactly one level deep. It includes the global config, agent
definitions, slash commands, a per-project template with Agent Skills, and
scripts to install and validate everything.

Targets OpenCode 1.18.x (validated against 1.18.32; see `docs/VALIDATION.md`).

```
You
 |
 v
Terra / build  (high reasoning; owns all changes)
 |
 +-- explore -> Luna low      (files, symbols, callers)
 +-- scout   -> Luna medium   (dependencies, docs)
 +-- browser -> Luna medium   (Playwright CLI)
 +-- gitlab  -> Luna medium   (read-only glab)
 +-- general -> GPT-OSS-120B  (bounded analysis, logs, second opinions)
```

## What is in here

```
.
├── README.md
├── docs/
│   ├── INSTALL.md            Rocky Linux host setup (git, node, go, glab, playwright-cli, oxfmt, opencode)
│   ├── ARCHITECTURE.md       agent hierarchy, permissions, delegation policy
│   ├── MODELS.md             model choices, exact IDs, GPT-OSS provider selection, Sol escalation
│   ├── QUOTA-FALLBACK.md     manual fallback when quotas are hit
│   ├── VALIDATION.md         how the config was validated, schema deviations
│   ├── SECURITY.md           what the permissions do and do not protect
│   └── PROJECT-TEMPLATE.md   copying the template into a project, Cline compatibility
├── opencode/                 -> ~/.config/opencode/ (symlinked by scripts/install.sh)
│   ├── opencode.jsonc        models, permissions, build/explore/scout/general agents, compaction
│   ├── AGENTS.md             global working rules for the lead and subagents
│   ├── agents/browser.md     Playwright CLI subagent
│   ├── agents/gitlab.md      read-only glab subagent
│   ├── commands/mr-triage.md /mr-triage <n>
│   ├── commands/mr-review.md /mr-review <n>
│   └── prompts/              role prompts for scout and general
├── project-template/         copied into each project (see docs/PROJECT-TEMPLATE.md)
│   ├── opencode.jsonc        oxfmt + gofmt formatters, Prettier disabled, generated dirs protected
│   ├── AGENTS.md             monorepo conventions (React, TanStack, Valibot, shadcn, Cesium, MapLibre, Turf, Go, contracts)
│   └── .agents/skills/       tanstack-router, tanstack-start, valibot, shadcn, cesium, turf,
│                             api-contracts, playwright, go-backend
└── scripts/
    ├── install.sh                   symlink opencode/ into ~/.config/opencode (idempotent, backups, --dry-run)
    ├── install-project-template.sh  copy the template into a project without overwriting
    ├── validate.sh                  PASS/WARN/FAIL checks for config, skills, scripts, tools
    └── check-models.sh              FOUND/MISSING for the desired model IDs
```

## Model hierarchy

| Agent     | Model                    | Reasoning | Role                                                        |
| --------- | ------------------------ | --------- | ----------------------------------------------------------- |
| `build`   | `openai/gpt-5.6-terra`   | high      | lead: architecture, implementation, integration, verification |
| `explore` | `openai/gpt-5.6-luna`    | low       | read-only code search                                        |
| `scout`   | `openai/gpt-5.6-luna`    | medium    | read-only dependency/doc research (explicit URLs only)       |
| `browser` | `openai/gpt-5.6-luna`    | medium    | Playwright CLI testing                                       |
| `gitlab`  | `openai/gpt-5.6-luna`    | medium    | read-only MR/pipeline inspection                             |
| `general` | GPT-OSS-120B (placeholder) | default | bounded analysis, logs, transformations, second opinions     |

`openai/gpt-5.6-sol` is documented as an optional, intentional escalation
model and is not configured by default. Details: `docs/MODELS.md`.

## Installation

1. Prepare the host: `docs/INSTALL.md` (Rocky Linux; checks before installing).
2. Install the global config (symlinks, so repo updates propagate):

   ```bash
   ./scripts/install.sh --dry-run
   ./scripts/install.sh
   ```

   Existing unrelated files at a target path are backed up as
   `<name>.bak.<timestamp>`, never silently overwritten. `--copy` copies
   instead of linking; `--dest DIR` installs elsewhere.

3. Authenticate providers yourself (`opencode providers login` or `/connect`).
   No keys are stored in this repository.
4. Pick a GPT-OSS-120B provider and replace `REPLACE_WITH_GPT_OSS_120B_MODEL_ID`
   in `opencode/opencode.jsonc` (`./scripts/check-models.sh` lists candidates).
5. Verify: `./scripts/validate.sh`.

## Project template

```bash
./scripts/install-project-template.sh /path/to/project --dry-run
./scripts/install-project-template.sh /path/to/project
```

Copies `AGENTS.md`, `opencode.jsonc`, and `.agents/skills/` into the project,
reporting conflicts instead of overwriting. `--cline-symlink` adds
`.cline/skills -> ../.agents/skills` for teammates on Cline. See
`docs/PROJECT-TEMPLATE.md`.

## How delegation works

- `subagent_depth: 1` plus `task: deny` on every subagent: the lead delegates,
  subagents never do.
- The lead's `task` permission is an allow-list of the five subagents.
- `opencode/AGENTS.md` tells the lead when to delegate (independent, bounded
  investigations) and when not to (trivial work), and requires a handoff with
  objective, scope, files, constraints, and expected output.
- Subagents return concise findings; the lead integrates, implements, verifies,
  and reports.

Details and the permission table: `docs/ARCHITECTURE.md`.

## Verifying the configuration

```bash
./scripts/validate.sh          # files, JSONC, frontmatter, skills, symlinks, tools, live `opencode debug config`
./scripts/check-models.sh      # opencode models --refresh; FOUND/MISSING per model
opencode debug agent gitlab    # resolved permission rules for any agent
```

`validate.sh` exits nonzero only for real configuration errors; missing
optional tools produce `WARN`.

## Browser agent

`browser` runs only `playwright-cli` commands (no Playwright MCP, no web
fetch, no edits). It opens the URL you supply, snapshots, interacts with
observed element refs, checks the console, screenshots, closes the browser,
and reports expected vs observed behavior. Install with
`npm install -g @playwright/cli@latest`. Skill: `project-template/.agents/skills/playwright`.

## GitLab agent

`gitlab` runs a narrow allow-list of read-only `glab` and `git` commands
(`glab mr list/view/diff`, `glab ci list/status/get`, `git status/diff/log/show`).
It never creates, comments, approves, merges, pushes, or touches pipelines.
`/mr-triage <n>` and `/mr-review <n>` use it through the lead. Use a
read-only token with `glab auth login` for real enforcement (`docs/SECURITY.md`).

## Skills

Nine project skills live in `project-template/.agents/skills/`, one folder per
skill with a `SKILL.md` (`name` + `description` frontmatter). They carry
conventions, version awareness, workflows, and pitfalls, not copied
documentation. OpenCode loads them on demand through the `skill` tool.

## Manual model fallback

There is no automatic failover. If Terra's quota is hit, switch `build` to
`openai/gpt-5.6-luna` with high reasoning; if the whole OpenAI project is
unavailable, run temporarily on your GPT-OSS provider. Model rate limits and
account billing quotas are different failure modes. Steps: `docs/QUOTA-FALLBACK.md`.

## Updating model IDs

`opencode models --refresh && opencode models`, edit `opencode/opencode.jsonc`
and the `model:` lines in `opencode/agents/*.md`, then `./scripts/validate.sh`.
See `docs/MODELS.md`.

## Security

This is not a sandbox: permissions gate tool calls, they do not confine
processes; a read-only GitLab token beats prompt instructions; only send
company code to approved providers; never store secrets here; review
generated commands; treat tool output, pages, logs, and third-party docs as
untrusted. Full notes: `docs/SECURITY.md`.

## Not included, on purpose

LiteLLM or any model gateway, a general web-search agent, Playwright MCP,
Figma MCP, automatic quota failover, and large documentation mirrors.
