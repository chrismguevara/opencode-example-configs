#!/usr/bin/env bash
# Check which of the desired models the installed OpenCode exposes.
#
# Usage: ./scripts/check-models.sh [--no-refresh] [--quiet]
#
# Runs `opencode models --refresh` (unless --no-refresh) and `opencode models`,
# then reports FOUND / MISSING for:
#   - the exact model IDs used in opencode/opencode.jsonc and opencode/agents/*.md
#   - the desired families: gpt-5.6-terra, gpt-5.6-luna, gpt-5.6-sol, gpt-oss
#
# Notes:
#   - `opencode models` only lists providers that are configured (credentials
#     via `opencode providers login`, /connect, or env vars). A MISSING result
#     may simply mean the provider is not authenticated yet.
#   - No credentials are printed or read by this script.
#
# Exit codes: 0 all essential models found, 2 opencode missing, 3 essentials missing.

set -uo pipefail

REFRESH=1
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --no-refresh) REFRESH=0 ;;
    --quiet) QUIET=1 ;;
    -h|--help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
CFG="$REPO_ROOT/opencode/opencode.jsonc"
PLACEHOLDER="REPLACE_WITH_GPT_OSS_120B_MODEL_ID"

if ! command -v opencode >/dev/null 2>&1; then
  echo "opencode is not installed or not on PATH (see docs/INSTALL.md)" >&2
  exit 2
fi

echo "opencode version: $(opencode --version 2>/dev/null | tail -1)"

if [ "$REFRESH" -eq 1 ]; then
  if ! opencode models --refresh >/dev/null 2>&1; then
    echo "warn: 'opencode models --refresh' failed (offline?); using cached/bundled catalog"
  fi
fi

MODELS_FILE="$(mktemp)"
trap 'rm -f "$MODELS_FILE"' EXIT
if ! opencode models >"$MODELS_FILE" 2>/dev/null; then
  echo "error: 'opencode models' failed" >&2
  exit 2
fi
echo "models listed by configured providers: $(wc -l <"$MODELS_FILE" | tr -d ' ')"
echo

# --- 1. Exact IDs referenced by this configuration --------------------------
echo "Configured model IDs:"
# Pull "model": "<id>" from JSONC and "model: <id>" from agent frontmatter.
mapfile -t CONFIGURED < <(
  {
    grep -oE '"model"[[:space:]]*:[[:space:]]*"[^"]+"' "$CFG" | sed -E 's/.*:[[:space:]]*"([^"]+)"/\1/'
    grep -hoE '^model:[[:space:]]*[^[:space:]]+' "$REPO_ROOT"/opencode/agents/*.md | sed -E 's/^model:[[:space:]]*//'
  } | sort -u
)
MISSING_ESSENTIAL=0
for id in "${CONFIGURED[@]}"; do
  if [ "$id" = "$PLACEHOLDER" ]; then
    printf '  %-9s %s\n' "TODO" "$id  (general agent: choose a GPT-OSS-120B provider, see below)"
    continue
  fi
  if grep -qxF "$id" "$MODELS_FILE"; then
    printf '  %-9s %s\n' "FOUND" "$id"
  else
    printf '  %-9s %s\n' "MISSING" "$id"
    MISSING_ESSENTIAL=1
  fi
done
echo

# --- 2. Desired families ------------------------------------------------------
echo "Desired model families:"
for fam in gpt-5.6-terra gpt-5.6-luna gpt-5.6-sol gpt-oss; do
  matches="$(grep -F -- "$fam" "$MODELS_FILE" || true)"
  if [ -n "$matches" ]; then
    count="$(printf '%s\n' "$matches" | wc -l | tr -d ' ')"
    printf '  %-9s %-14s (%s id(s))\n' "FOUND" "$fam" "$count"
    if [ "$QUIET" -eq 0 ]; then
      printf '%s\n' "$matches" | sed 's/^/             /'
    fi
  else
    printf '  %-9s %-14s\n' "MISSING" "$fam"
  fi
done
echo

# --- 3. GPT-OSS-120B candidates ---------------------------------------------
oss="$(grep -F -- 'gpt-oss-120b' "$MODELS_FILE" || true)"
if [ -n "$oss" ]; then
  echo "GPT-OSS-120B candidates exposed by your configured providers (pick one for agent.general.model):"
  printf '%s\n' "$oss" | sed 's/^/  /'
else
  cat <<'MSG'
No provider exposing gpt-oss-120b is configured. Known IDs in the OpenCode catalog (1.18.32):
  openrouter/openai/gpt-oss-120b
  groq/openai/gpt-oss-120b
  cerebras/gpt-oss-120b
  fireworks-ai/accounts/fireworks/models/gpt-oss-120b
  togetherai/openai/gpt-oss-120b
  deepinfra/openai/gpt-oss-120b
  baseten/openai/gpt-oss-120b
  nebius/openai/gpt-oss-120b
  vercel/openai/gpt-oss-120b
  amazon-bedrock/openai.gpt-oss-120b
Authenticate the provider you use (opencode providers login), re-run this script,
then set agent.general.model in opencode/opencode.jsonc.
MSG
fi

if [ "$MISSING_ESSENTIAL" -eq 1 ]; then
  echo
  echo "Some configured models are MISSING. If the provider is not authenticated yet, run 'opencode providers login' first."
  exit 3
fi
