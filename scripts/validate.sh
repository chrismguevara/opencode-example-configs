#!/usr/bin/env bash
# Validate this repository's OpenCode configuration and the local toolchain.
#
# Usage: ./scripts/validate.sh [--no-tools] [--no-refresh]
#
#   --no-tools    skip external tool checks (opencode, playwright-cli, glab, go, node, oxfmt)
#   --no-refresh  do not run `opencode models --refresh`
#
# Prints PASS / WARN / FAIL per check. Exit code is 1 when any FAIL occurred
# (a real configuration error); optional/missing tools only WARN.

set -uo pipefail

CHECK_TOOLS=1
REFRESH_FLAG=""
for arg in "$@"; do
  case "$arg" in
    --no-tools) CHECK_TOOLS=0 ;;
    --no-refresh) REFRESH_FLAG="--no-refresh" ;;
    -h|--help) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
cd "$REPO_ROOT"

PASS=0; WARN=0; FAIL=0
pass() { PASS=$((PASS + 1)); printf 'PASS  %s\n' "$*"; }
warn() { WARN=$((WARN + 1)); printf 'WARN  %s\n' "$*"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$*"; }
section() { printf '\n== %s ==\n' "$*"; }

PLACEHOLDER="REPLACE_WITH_GPT_OSS_120B_MODEL_ID"

# ---------------------------------------------------------------------------
section "Required files"
# ---------------------------------------------------------------------------
REQUIRED=(
  README.md
  docs/INSTALL.md docs/ARCHITECTURE.md docs/MODELS.md docs/QUOTA-FALLBACK.md docs/VALIDATION.md
  opencode/opencode.jsonc opencode/AGENTS.md
  opencode/agents/browser.md opencode/agents/gitlab.md
  opencode/commands/mr-triage.md opencode/commands/mr-review.md
  opencode/prompts/scout.md opencode/prompts/general.md
  project-template/opencode.jsonc project-template/AGENTS.md
  scripts/install.sh scripts/validate.sh scripts/check-models.sh scripts/install-project-template.sh
)
for f in "${REQUIRED[@]}"; do
  [ -f "$f" ] && pass "exists: $f" || fail "missing: $f"
done
for s in tanstack-router tanstack-start valibot shadcn cesium turf api-contracts playwright go-backend; do
  f="project-template/.agents/skills/$s/SKILL.md"
  [ -f "$f" ] && pass "exists: $f" || fail "missing: $f"
done

# ---------------------------------------------------------------------------
section "Shell scripts"
# ---------------------------------------------------------------------------
for f in scripts/*.sh; do
  if bash -n "$f" 2>/dev/null; then pass "bash -n $f"; else fail "syntax error: $f"; fi
  [ -x "$f" ] && pass "executable: $f" || warn "not executable: $f (chmod +x)"
done
if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck -S warning scripts/*.sh; then pass "shellcheck"; else warn "shellcheck reported issues"; fi
fi

# ---------------------------------------------------------------------------
section "JSONC syntax"
# ---------------------------------------------------------------------------
# Strip // and /* */ comments outside strings, then JSON.parse. Node first, python3 fallback.
jsonc_check() {
  local file="$1"
  if command -v node >/dev/null 2>&1; then
    node -e '
      const fs = require("fs");
      const src = fs.readFileSync(process.argv[1], "utf8");
      let out = "", i = 0, inStr = false;
      while (i < src.length) {
        const c = src[i], n = src[i + 1];
        if (inStr) { out += c; if (c === "\\") { out += n; i += 2; continue; } if (c === "\"") inStr = false; i++; continue; }
        if (c === "\"") { inStr = true; out += c; i++; continue; }
        if (c === "/" && n === "/") { while (i < src.length && src[i] !== "\n") i++; continue; }
        if (c === "/" && n === "*") { i += 2; while (i < src.length && !(src[i] === "*" && src[i + 1] === "/")) i++; i += 2; continue; }
        out += c; i++;
      }
      out = out.replace(/,(\s*[}\]])/g, "$1"); // tolerate trailing commas like OpenCode does
      const obj = JSON.parse(out);
      if (!obj.$schema) { console.error("missing $schema"); process.exit(2); }
    ' "$file"
    return $?
  elif command -v python3 >/dev/null 2>&1; then
    python3 - "$file" <<'PY'
import json, re, sys
src = open(sys.argv[1], encoding="utf-8").read()
out, i, in_str = [], 0, False
while i < len(src):
    c = src[i]; n = src[i+1] if i+1 < len(src) else ""
    if in_str:
        out.append(c)
        if c == "\\": out.append(n); i += 2; continue
        if c == '"': in_str = False
        i += 1; continue
    if c == '"': in_str = True; out.append(c); i += 1; continue
    if c == "/" and n == "/":
        while i < len(src) and src[i] != "\n": i += 1
        continue
    if c == "/" and n == "*":
        i += 2
        while i < len(src) and not (src[i] == "*" and src[i+1:i+2] == "/"): i += 1
        i += 2; continue
    out.append(c); i += 1
text = re.sub(r",(\s*[}\]])", r"\1", "".join(out))
obj = json.loads(text)
if not obj.get("$schema"):
    print("missing $schema", file=sys.stderr); sys.exit(2)
PY
    return $?
  else
    return 99
  fi
}
for f in opencode/opencode.jsonc project-template/opencode.jsonc; do
  jsonc_check "$f"; rc=$?
  case $rc in
    0) pass "valid JSONC with \$schema: $f" ;;
    99) warn "cannot parse $f (neither node nor python3 available)" ;;
    *) fail "invalid JSONC: $f" ;;
  esac
done
if grep -q "$PLACEHOLDER" opencode/opencode.jsonc; then
  warn "opencode/opencode.jsonc still contains $PLACEHOLDER (agent.general has no usable model yet; see docs/MODELS.md)"
else
  pass "GPT-OSS placeholder replaced in opencode/opencode.jsonc"
fi
for key in '"subagent_depth": 1' '"default_agent": "build"' '"websearch": "deny"'; do
  grep -qF "$key" opencode/opencode.jsonc && pass "global config has $key" || fail "global config missing $key"
done
tr -d '\n' < project-template/opencode.jsonc | grep -qE '"prettier":[[:space:]]*\{[[:space:]]*"disabled":[[:space:]]*true' \
  && pass "project template disables prettier" || warn "project template does not disable prettier"

# ---------------------------------------------------------------------------
section "Markdown frontmatter (agents, commands, skills)"
# ---------------------------------------------------------------------------
# frontmatter FILE -> prints the YAML block between the first two '---' lines
frontmatter() { awk 'NR==1 && $0!="---"{exit 1} NR>1 && $0=="---"{exit} NR>1{print}' "$1"; }
fm_value() { frontmatter "$1" | awk -v k="$2" -F': *' '$1==k{sub(/^[^:]*: */,""); print; exit}'; }

for f in opencode/agents/*.md; do
  if ! frontmatter "$f" >/dev/null 2>&1; then fail "no frontmatter: $f"; continue; fi
  [ -n "$(fm_value "$f" description)" ] && pass "agent has description: $f" || fail "agent missing description: $f"
  [ "$(fm_value "$f" mode)" = "subagent" ] && pass "agent mode=subagent: $f" || fail "agent mode is not subagent: $f"
  [ -n "$(fm_value "$f" model)" ] && pass "agent has model: $f" || fail "agent missing model: $f"
  frontmatter "$f" | grep -qE '^\s+"\*":\s*deny' && pass "agent bash default is deny: $f" || fail "agent bash rules must start with \"*\": deny: $f"
  frontmatter "$f" | grep -qE '^\s+edit:\s*deny' && pass "agent edit=deny: $f" || fail "agent must have edit: deny: $f"
  frontmatter "$f" | grep -qE '^\s+task:\s*deny' && pass "agent task=deny: $f" || fail "agent must have task: deny: $f"
done
# gitlab agent must not allow whole mutating namespaces
if grep -qE '^\s+"glab (mr|ci|repo|api) \*":\s*allow' opencode/agents/gitlab.md; then
  fail "gitlab agent allows a whole glab namespace (mutating commands included)"
else
  pass "gitlab agent uses narrow glab allow-list"
fi
for f in opencode/commands/*.md; do
  if ! frontmatter "$f" >/dev/null 2>&1; then fail "no frontmatter: $f"; continue; fi
  [ -n "$(fm_value "$f" description)" ] && pass "command has description: $f" || fail "command missing description: $f"
  grep -qE '\$(ARGUMENTS|1)' "$f" && pass "command uses arguments: $f" || warn "command has no \$ARGUMENTS/\$1: $f"
done
for dir in project-template/.agents/skills/*/; do
  name="$(basename "$dir")"; f="$dir/SKILL.md"
  [ -f "$f" ] || { fail "missing SKILL.md in $dir"; continue; }
  if ! frontmatter "$f" >/dev/null 2>&1; then fail "no frontmatter: $f"; continue; fi
  n="$(fm_value "$f" name)"; d="$(fm_value "$f" description)"
  if [ "$n" = "$name" ] && [[ "$n" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] && [ ${#n} -le 64 ]; then
    pass "skill name valid and matches directory: $name"
  else
    fail "skill name '$n' invalid or does not match directory '$name'"
  fi
  if [ -n "$d" ] && [ ${#d} -le 1024 ]; then pass "skill description ok: $name"; else fail "skill description missing or >1024 chars: $name"; fi
done

# ---------------------------------------------------------------------------
section "Installed global config (~/.config/opencode)"
# ---------------------------------------------------------------------------
CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
if [ -d "$CFG_DIR" ]; then
  for entry in opencode.jsonc AGENTS.md agents commands prompts; do
    t="$CFG_DIR/$entry"
    if [ -L "$t" ]; then
      target="$(readlink -f "$t" 2>/dev/null || true)"
      if [ -z "$target" ] || [ ! -e "$target" ]; then fail "broken symlink: $t -> $(readlink "$t")"
      elif [ "$target" = "$REPO_ROOT/opencode/$entry" ]; then pass "linked to this repo: $t"
      else warn "symlink points elsewhere: $t -> $target"; fi
    elif [ -e "$t" ]; then
      warn "$t exists but is not a symlink to this repo (copied or unmanaged)"
    else
      warn "not installed: $t (run scripts/install.sh)"
    fi
  done
  [ -e "$CFG_DIR/opencode.json" ] && warn "$CFG_DIR/opencode.json also exists and will be merged with opencode.jsonc"
  # duplicate definitions across json/jsonc are easy to miss
  find "$CFG_DIR" -maxdepth 2 -xtype l 2>/dev/null | while read -r broken; do fail "broken symlink: $broken"; done
else
  warn "$CFG_DIR does not exist (run scripts/install.sh)"
fi

# ---------------------------------------------------------------------------
if [ "$CHECK_TOOLS" -eq 1 ]; then
section "Tools"
# ---------------------------------------------------------------------------
  if command -v opencode >/dev/null 2>&1; then
    ver="$(opencode --version 2>/dev/null | tail -1)"
    pass "opencode $ver"
    case "$ver" in
      1.*) pass "opencode is a 1.x release" ;;
      *) warn "opencode $ver is not a 1.x release; schema may differ" ;;
    esac
    # Validate the repo config with the real binary in an isolated copy of opencode/
    # (OpenCode may create helper files in its config dir; keep the repo clean).
    tmp="$(mktemp -d)"; cp -R "$REPO_ROOT/opencode/." "$tmp/"
    out="$(OPENCODE_CONFIG_DIR="$tmp" OPENCODE_DISABLE_MODELS_FETCH=1 opencode debug config 2>&1)"; rc=$?
    # Strip ANSI colors; OpenCode reports problems as "Error:" / "Configuration is invalid at <file>".
    plain="$(printf '%s' "$out" | sed 's/\x1b\[[0-9;]*m//g')"
    if [ $rc -eq 0 ] && ! printf '%s' "$plain" | grep -qE '^Error:|Configuration is invalid'; then
      pass "opencode debug config accepts opencode/opencode.jsonc"
    else
      fail "opencode debug config rejected the config:"; printf '%s\n' "$plain" | grep -E '^Error:|invalid|↳' | head -20 | sed 's/^/      /'
    fi
    for a in build explore scout general browser gitlab; do
      if OPENCODE_CONFIG_DIR="$tmp" OPENCODE_DISABLE_MODELS_FETCH=1 opencode debug agent "$a" >/dev/null 2>&1; then
        pass "agent resolves: $a"
      else
        fail "agent does not resolve: $a"
      fi
    done
    rm -rf "$tmp"
    if "$SCRIPT_DIR/check-models.sh" $REFRESH_FLAG --quiet >/dev/null 2>&1; then
      pass "check-models.sh: configured models found"
    else
      warn "check-models.sh reported missing models (provider not authenticated, or placeholder unresolved); run it for details"
    fi
  else
    warn "opencode not installed (docs/INSTALL.md); skipped live config validation"
  fi

  if command -v playwright-cli >/dev/null 2>&1; then
    playwright-cli --help >/dev/null 2>&1 && pass "playwright-cli available ($(playwright-cli --version 2>/dev/null | tail -1))" || warn "playwright-cli present but --help failed"
  else
    warn "playwright-cli not installed (npm install -g @playwright/cli@latest)"
  fi
  if command -v glab >/dev/null 2>&1; then
    pass "glab $(glab --version 2>/dev/null | head -1)"
    glab auth status >/dev/null 2>&1 && pass "glab is authenticated" || warn "glab not authenticated (glab auth login)"
  else
    warn "glab not installed (docs/INSTALL.md)"
  fi
  command -v go >/dev/null 2>&1 && pass "$(go version)" || warn "go not installed"
  command -v node >/dev/null 2>&1 && pass "node $(node --version)" || warn "node not installed"
  if [ -f "$PWD/package.json" ] || [ -f "$OLDPWD/package.json" ]; then
    proj="$( [ -f "$PWD/package.json" ] && echo "$PWD" || echo "$OLDPWD")"
    if grep -q '"oxfmt"' "$proj/package.json"; then
      (cd "$proj" && npx --no-install oxfmt --version >/dev/null 2>&1) && pass "oxfmt available in $proj" || warn "oxfmt listed in package.json but not installed (run the package manager install)"
    else
      warn "oxfmt not in $proj/package.json (add it as a devDependency for JS/TS projects)"
    fi
  else
    warn "oxfmt check skipped (no package.json in the current directory)"
  fi
fi

# ---------------------------------------------------------------------------
printf '\nSummary: PASS=%d WARN=%d FAIL=%d\n' "$PASS" "$WARN" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
