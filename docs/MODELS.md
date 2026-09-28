# Models

Model IDs were verified against the model catalog bundled with OpenCode 1.18.32
(`opencode models`, see `VALIDATION.md`). Run `scripts/check-models.sh` on your
machine to confirm what your authenticated providers expose.

| Role                | Configured ID                          | Status                                   |
| ------------------- | -------------------------------------- | ---------------------------------------- |
| Terra               | `openai/gpt-5.6-terra`                 | exact ID confirmed                       |
| Luna                | `openai/gpt-5.6-luna`                  | exact ID confirmed                       |
| Sol                 | `openai/gpt-5.6-sol` (not configured)  | exact ID confirmed; optional escalation  |
| GPT-OSS-120B        | `REPLACE_WITH_GPT_OSS_120B_MODEL_ID`   | placeholder: provider must be chosen     |

The catalog also exposes `-fast` and `-pro` variants (for example
`openai/gpt-5.6-terra-fast`, `openai/gpt-5.6-terra-pro`). They are not used
by default; `-pro` is a candidate for intentional escalation alongside Sol.

## Model calls go direct

No LiteLLM, no OpenAI-compatible routing proxy, no gateway. OpenCode talks to
each provider with the credentials you register via `opencode providers login`
(or `/connect` in the TUI). Provider credentials are stored by OpenCode outside
this repository and are never written here.

## GPT-5.6 Terra: primary driver

Use for architecture, implementation, integration, difficult debugging,
coordinating other agents, code review, and final decisions.

Reasoning effort: **high** by default (`reasoningEffort: "high"`,
`textVerbosity: "low"` on the `build` agent).

## GPT-5.6 Luna: frequent, cheap worker

Use for repository search, symbol tracing, documentation research, browser
tests, GitLab inspection, bounded analysis, and repetitive-but-intelligent
investigations. It also runs the hidden `compaction`, `title`, and `summary`
agents and is the `small_model`.

Reasoning effort:

- **low** for exploration (`explore`)
- **medium** for research, browser, and GitLab work (`scout`, `browser`, `gitlab`)
- **high** only as the temporary primary fallback (see `QUOTA-FALLBACK.md`)

## GPT-OSS-120B: alternate-provider worker

Used by the `general` subagent for large bounded analysis, logs,
transformations, second opinions, and workloads where expensive cloud tokens
are unnecessary. It never delegates (`task: deny`) and has no write access by
default (`edit: deny`, `bash: ask`). Do not make it the primary coding driver.

### Choosing the provider

The catalog lists GPT-OSS-120B under several providers. The ID depends on the
account you have; none is assumed:

| Provider       | Model ID                                             |
| -------------- | ---------------------------------------------------- |
| OpenRouter     | `openrouter/openai/gpt-oss-120b`                     |
| Groq           | `groq/openai/gpt-oss-120b`                           |
| Cerebras       | `cerebras/gpt-oss-120b`                              |
| Fireworks      | `fireworks-ai/accounts/fireworks/models/gpt-oss-120b` |
| Together       | `togetherai/openai/gpt-oss-120b`                     |
| DeepInfra      | `deepinfra/openai/gpt-oss-120b`                      |
| Baseten        | `baseten/openai/gpt-oss-120b`                        |
| Nebius         | `nebius/openai/gpt-oss-120b`                         |
| Vercel AI GW   | `vercel/openai/gpt-oss-120b`                         |
| Amazon Bedrock | `amazon-bedrock/openai.gpt-oss-120b`                 |

A locally hosted copy (Ollama, vLLM, llama.cpp) is also possible through a
custom `provider` entry in `opencode.jsonc`; see the OpenCode providers docs
for the `@ai-sdk/openai-compatible` npm setup. That is still a direct
connection, not a gateway.

To finish the setup:

1. `opencode providers login` for the chosen provider.
2. `./scripts/check-models.sh` and copy the exact `gpt-oss-120b` line.
3. Replace `REPLACE_WITH_GPT_OSS_120B_MODEL_ID` in `opencode/opencode.jsonc`.
4. `./scripts/validate.sh`.

## GPT-5.6 Sol: optional escalation

Not the default anywhere. Use intentionally for exceptionally hard problems:

- very difficult architecture decisions
- complex debugging after Terra fails
- large cross-cutting reasoning problems

Switch the `build` agent's model to `openai/gpt-5.6-sol` for that session in
the TUI model picker, or temporarily in `opencode.jsonc`, then switch back.

## Updating model IDs

1. `opencode models --refresh && opencode models` (or `scripts/check-models.sh`).
2. Edit `opencode/opencode.jsonc` (`model`, `small_model`, every `agent.*.model`)
   and the `model:` line in `opencode/agents/browser.md` and `gitlab.md`.
3. `./scripts/validate.sh` runs `opencode debug config` and resolves every agent.
4. Provider-specific options (`reasoningEffort`, `textVerbosity`) are passed
   through to the provider; if you move an agent to a provider that does not
   accept them, remove or rename those keys.
