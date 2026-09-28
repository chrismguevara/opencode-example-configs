# Manual quota fallback

There is **no automatic failover** in this setup. When a model or account
quota is exhausted you change the configuration by hand, then change it back.

## Normal state

| Agent     | Model                | Reasoning |
| --------- | -------------------- | --------- |
| `build`   | GPT-5.6 Terra        | high      |
| `explore` | GPT-5.6 Luna         | low       |
| `scout`   | GPT-5.6 Luna         | medium    |
| `browser` | GPT-5.6 Luna         | medium    |
| `gitlab`  | GPT-5.6 Luna         | medium    |
| `general` | GPT-OSS-120B         | default   |

## Two different failure modes

1. **Model-specific rate limit** (for example Terra's tokens-per-minute or
   daily cap): other models on the same OpenAI project keep working. Errors
   typically mention the model or `rate_limit_exceeded`.
2. **Account/project billing quota** (`insufficient_quota`, hard spend cap,
   suspended key): *every* OpenAI model fails, including Luna and Sol.

Check which one you hit before changing anything; the fix differs.

## Case 1: Terra quota reached

Temporarily run the lead on Luna with high reasoning.

Option A, no file changes: in the TUI select the `build` agent and switch the
model to `openai/gpt-5.6-luna` for the current session (model picker), and
pick a high-reasoning variant if the picker offers one.

Option B, persistent until you revert: edit `opencode/opencode.jsonc`:

```jsonc
"build": {
  "model": "openai/gpt-5.6-luna",   // was openai/gpt-5.6-terra
  "reasoningEffort": "high",
  ...
}
```

Optionally lower explore/scout/browser/gitlab load while Luna is also the
lead, or leave them as is. Revert when the Terra window resets.

## Case 2: whole OpenAI account/project unavailable

Use a separately hosted GPT-OSS model as the temporary main model. Use the
same provider/model ID you chose for `general` (see `MODELS.md`), for example
`openrouter/openai/gpt-oss-120b`:

```jsonc
"model": "<provider>/<gpt-oss-120b id>",
"small_model": "<provider>/<gpt-oss-120b id>",
"agent": {
  "build":   { "model": "<provider>/<gpt-oss-120b id>", ... },
  "explore": { "model": "<provider>/<gpt-oss-120b id>", ... },
  "scout":   { "model": "<provider>/<gpt-oss-120b id>", ... },
  "compaction": { "model": "<provider>/<gpt-oss-120b id>" },
  "title":      { "model": "<provider>/<gpt-oss-120b id>" },
  "summary":    { "model": "<provider>/<gpt-oss-120b id>" }
}
```

Also update `model:` in `opencode/agents/browser.md` and `gitlab.md`.
Remove the `reasoningEffort`/`textVerbosity` keys if the substitute provider
rejects them (they are passed through to the provider unchanged).

Expect lower quality on architecture and multi-file changes; keep tasks
smaller and review diffs more carefully until you switch back.

## Escalation is not fallback

GPT-5.6 Sol is an optional escalation model for exceptionally hard problems,
not a fallback target. Do not switch to Sol because of a quota issue; it lives
on the same OpenAI project and costs more.

## Reverting

Because the global config is a symlink into this repository, `git diff`
shows exactly what you changed and `git checkout -- opencode/` restores the
normal state. Do not commit the temporary fallback configuration.
