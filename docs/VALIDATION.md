# Validation and schema notes

## How the configuration was validated

Target: OpenCode **1.18.32** (npm `opencode-ai@latest` at the time of writing;
the config is meant for 1.18.x and compatible 1.x releases).

Sources used, in order of authority:

1. The 1.18.32 source: `packages/core/src/v1/config/{config,agent,permission,formatter,command}.ts`
   and `packages/opencode/src/{agent/agent,skill,format}.ts` (tag `v1.18.32`).
2. The 1.18.32 documentation (`packages/web/src/content/docs/*.mdx`: agents,
   permissions, config, commands, skills, formatters, models, cli, rules).
3. The installed binary: `opencode --version`, `opencode models`,
   `opencode debug config`, `opencode debug agent <name>`.

`scripts/validate.sh` repeats the live checks on your machine.

## Validation commands

```bash
bash -n scripts/*.sh                       # shell syntax
./scripts/validate.sh                      # everything below, PASS/WARN/FAIL
./scripts/check-models.sh                  # model IDs FOUND/MISSING
opencode --version
OPENCODE_CONFIG_DIR=$PWD/opencode opencode debug config     # resolved config (copy the dir first; see note)
OPENCODE_CONFIG_DIR=$PWD/opencode opencode debug agent gitlab
opencode agent list
opencode debug skill                       # run inside a project that has .agents/skills
playwright-cli --help
glab --version && glab auth status
go version
node --version
```

Note: OpenCode may create helper files (`.gitignore`, `package.json`) in
whatever directory `OPENCODE_CONFIG_DIR` points at. `validate.sh` therefore
copies `opencode/` to a temp dir before running `opencode debug ...`.

`opencode debug config` prints `Configuration is invalid at <file>` with the
offending key when a value has the wrong type. Unknown top-level keys are
accepted silently, so keep an eye on typos.

## Schema findings (1.18.32)

| Item in the specification                | Status in 1.18.32 | How it is configured here |
| ---------------------------------------- | ----------------- | ------------------------- |
| `subagent_depth`                         | supported (non-negative int, default 1) | `"subagent_depth": 1` |
| `default_agent`, `model`, `small_model`  | supported         | as specified |
| `agent.<name>.steps`                     | supported (`maxSteps` is deprecated) | `steps` |
| `agent.<name>.reasoningEffort` / `textVerbosity` | not first-class keys; unknown agent keys are folded into `options` and passed through to the provider (documented "Additional" options) | kept at agent level as the docs show |
| nested `permission.task` object          | supported (`task` accepts an action or a pattern map matched against the subagent name) | allow-list on `build`, `deny` on subagents |
| `permission.skill`, `external_directory` | supported         | as specified |
| `permission.websearch` / `webfetch`      | supported (action only, no pattern map) | as specified |
| `agent.compaction` / `title` / `summary` | supported hidden system agents | model set to Luna |
| `compaction.auto` / `prune` / `reserved` | supported         | as specified |
| Markdown agents with `permission.bash` pattern map | supported | `browser.md`, `gitlab.md` |
| Markdown commands with `agent`, `$ARGUMENTS`, `$1` | supported | `mr-triage.md`, `mr-review.md` |
| Skills in `.agents/skills/<name>/SKILL.md` | supported natively (also `.opencode/skills`, `.claude/skills`) | project template |
| `formatter` map with `disabled` / `command` / `extensions` | supported | project template |

## Deviations from the specification

1. **`explore` and `general` are built-ins.** OpenCode ships `explore` and
   `general` with their own defaults (`explore` allows `bash`, `webfetch`,
   `websearch` by default). The config overrides those permissions to `deny`;
   `opencode debug agent explore` confirms the resolved rules. `general` keeps
   the built-in `todowrite: deny`.
2. **Prompts for `scout` and `general`.** The specification defined them only
   in JSON. They now also get a role prompt via `"prompt": "{file:./prompts/<name>.md}"`
   (`opencode/prompts/`), so their read-only role is instructed, not just
   permission-enforced. `install.sh` links `prompts/` alongside the config.
3. **`scout` bash.** The specification left `scout`'s `bash` unspecified
   (which would inherit the global `ask`). It now has a narrow allow-list of
   read-only package/toolchain commands (`go doc`, `go list`, `npm ls`,
   `npm view`, `pnpm ls`, `pnpm why`, version prints) with `"*": deny`.
4. **Formatter "ignore" list.** OpenCode's formatter config has no ignore
   option. The project template instead denies `edit` under
   `node_modules`, `dist`, `.next`, `coverage`, and `.git`, which also prevents
   formatting there (formatters only run on files OpenCode writes).
5. **Built-in oxfmt is experimental** in 1.18 (`OPENCODE_EXPERIMENTAL_OXFMT`).
   The template supplies an explicit `command` for `oxfmt`; a custom command
   bypasses the experimental gate (verified in `format.ts`).
6. **`gitlab` allow-list extended** with `glab ci get`, `glab repo view`,
   `glab auth status`, `glab --version`, all read-only, and both bare and
   `*` forms because OpenCode matches `git status` and `git status *` separately.
7. **`browser` agent** additionally allows bare `playwright-cli` (for `--help`).
8. **`general` model** stays `REPLACE_WITH_GPT_OSS_120B_MODEL_ID` because the
   provider depends on your account; the `general` agent will fail to resolve
   a model until replaced. `validate.sh` warns while the placeholder remains.
9. **`OPENCODE_EXPERIMENTAL_SCOUT`.** 1.18.32 documents an experimental
   built-in "Scout" subagent behind that env flag. It is not enabled here; the
   custom `scout` agent in this config would merge over a built-in of the same
   name if you enable the flag.

## Model IDs

Verified with `opencode models` against the catalog bundled in 1.18.32
(dummy provider keys were used only to make the catalog listing include those
providers; no requests were made):

- `openai/gpt-5.6-terra`, `openai/gpt-5.6-luna`, `openai/gpt-5.6-sol`: present
  (plus `-fast` and `-pro` variants).
- `gpt-oss-120b`: present under openrouter, groq, cerebras, fireworks-ai,
  togetherai, deepinfra, baseten, nebius, vercel, amazon-bedrock (IDs in `MODELS.md`).

`opencode models` lists only providers that are configured/authenticated on
your machine, so run `scripts/check-models.sh` after `opencode providers login`.

## Cline compatibility

Cline's current documentation lists project skill locations `.cline/skills/`
(recommended), `.clinerules/skills/`, and `.claude/skills/`; it does not read
`.agents/skills/`. The canonical directory stays `.agents/skills`; teammates
using Cline can add the symlink `.cline/skills -> ../.agents/skills`
(`scripts/install-project-template.sh --cline-symlink`). Re-check Cline's
docs if its discovery paths change; whether Cline follows symlinked
directories on your platform should be confirmed once in a real project.

## Results of the initial validation run

Environment: Linux container, OpenCode 1.18.32 (installed from npm into a
scratch directory for validation only), Node v22, Go 1.24, `@playwright/cli`
0.1.21, no `glab`, no `oxfmt` project, no provider credentials.

| Check                                                              | Result |
| ------------------------------------------------------------------ | ------ |
| `bash -n scripts/*.sh`                                             | pass |
| `scripts/validate.sh` (files, JSONC, frontmatter, skills, scripts) | PASS=91 WARN=8 FAIL=0 |
| `opencode debug config` on `opencode/`                             | accepted, resolved config printed |
| `opencode debug agent build/explore/scout/general/browser/gitlab`  | all resolve; `explore` ends with `bash * deny`, `webfetch * deny`, `websearch * deny`; `build.task` is the allow-list; `gitlab.bash` is `* deny` plus the read-only list; `scout` prompt loads via `{file:./prompts/scout.md}` through a symlinked install; `general` resolves to the placeholder (expected until replaced) |
| `opencode debug skill` inside a project created from the template  | all 9 skills discovered from `.agents/skills/` |
| `scripts/check-models.sh` (catalog only, dummy key, no requests)   | `openai/gpt-5.6-terra` FOUND, `openai/gpt-5.6-luna` FOUND, `gpt-5.6-sol` FOUND, `gpt-oss` FOUND (provider-specific) |
| `scripts/install.sh` (`--dry-run`, install, re-run, conflict, `--copy`) | links created; re-run reports "already linked"; conflicting file backed up as `.bak.<timestamp>`; sibling `opencode.json` warning printed |
| `scripts/install-project-template.sh` (dry-run, install, re-run, conflict, `--force`, `--cline-symlink`) | copies 11 files; identical files skipped; differing file reported as CONFLICT (exit 3) until `--force` backs it up; `.cline/skills` symlink created |
| `playwright-cli --help`                                            | pass (0.1.21) |
| `glab --version`                                                   | not installed in the validation environment (WARN) |
| `go version`, `node --version`                                     | pass |

Warnings that remain by design until you act: GPT-OSS placeholder, global
config not yet installed on your machine, `glab` not installed, no
`package.json` in this repository for the oxfmt check.
