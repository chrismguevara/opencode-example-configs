#!/usr/bin/env bash
# Install (symlink by default) the reusable OpenCode configuration from this
# repository into ~/.config/opencode/.
#
# Safe and idempotent:
#   - entries that already point at this repository are skipped
#   - any other existing file/dir/symlink at a target path is BACKED UP with a
#     timestamped name (<name>.bak.YYYYmmdd-HHMMSS) before being replaced
#   - nothing else in ~/.config/opencode is touched
#   - no secrets or provider keys are written
#
# Usage:
#   ./scripts/install.sh [--dry-run] [--copy] [--dest <dir>]
#
#   --dry-run   print what would happen, change nothing
#   --copy      copy instead of symlink (updates to the repo will NOT propagate)
#   --dest DIR  install somewhere other than ${XDG_CONFIG_HOME:-~/.config}/opencode

set -euo pipefail

DRY_RUN=0
MODE="link"
DEST="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --copy) MODE="copy" ;;
    --dest)
      shift
      [ $# -gt 0 ] || { echo "error: --dest requires a directory" >&2; exit 2; }
      DEST="$1"
      ;;
    -h|--help)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "error: unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

# 1. Repository root (resolve symlinks so the links we create are stable).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
SRC="$REPO_ROOT/opencode"

# 2. Entries to install. Everything under opencode/ that OpenCode reads from
#    the global config directory.
ENTRIES=(opencode.jsonc AGENTS.md agents commands prompts)

log() { printf '%s\n' "$*"; }
run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    log "  [dry-run] $*"
  else
    "$@"
  fi
}

for entry in "${ENTRIES[@]}"; do
  if [ ! -e "$SRC/$entry" ]; then
    echo "error: required source missing: $SRC/$entry" >&2
    exit 1
  fi
done

STAMP="$(date +%Y%m%d-%H%M%S)"

log "Repository : $REPO_ROOT"
log "Source     : $SRC"
log "Destination: $DEST"
log "Mode       : $MODE$( [ "$DRY_RUN" -eq 1 ] && printf ' (dry-run)')"
log ""

# 3. Create the destination directory if needed.
if [ ! -d "$DEST" ]; then
  log "Creating $DEST"
  run mkdir -p "$DEST"
fi

backup() {
  local target="$1"
  local bak="${target}.bak.${STAMP}"
  log "  backup  : $target -> $bak"
  run mv "$target" "$bak"
}

# 4. Install each entry.
for entry in "${ENTRIES[@]}"; do
  src="$SRC/$entry"
  target="$DEST/$entry"
  log "$entry"

  if [ -L "$target" ]; then
    current="$(readlink -f "$target" 2>/dev/null || true)"
    if [ "$MODE" = "link" ] && [ "$current" = "$src" ]; then
      log "  ok      : already linked to this repository"
      continue
    fi
    if [ -z "$current" ] || [ ! -e "$current" ]; then
      log "  note    : existing symlink is broken ($(readlink "$target"))"
    else
      log "  note    : existing symlink points elsewhere ($current)"
    fi
    backup "$target"
  elif [ -e "$target" ]; then
    if [ "$MODE" = "copy" ] && [ -f "$target" ] && cmp -s "$src" "$target"; then
      log "  ok      : identical copy already present"
      continue
    fi
    log "  note    : existing $( [ -d "$target" ] && echo directory || echo file ) is not managed by this repository"
    backup "$target"
  fi

  if [ "$MODE" = "link" ]; then
    log "  link    : $target -> $src"
    run ln -s "$src" "$target"
  else
    log "  copy    : $src -> $target"
    run cp -R "$src" "$target"
  fi
done

# 5. Warn about a sibling opencode.json: OpenCode loads BOTH opencode.json and
#    opencode.jsonc from the global directory and merges them (jsonc last).
if [ -e "$DEST/opencode.json" ]; then
  log ""
  log "warning: $DEST/opencode.json also exists. OpenCode merges it with opencode.jsonc"
  log "         (opencode.jsonc wins on conflicting keys). Review it to avoid surprises."
fi

# 6. Next steps (no secrets are installed by this script).
cat <<NEXT

Done. Next steps:
  1. Authenticate providers (never stored in this repo):
       opencode providers login      # or /connect inside the TUI
  2. Pick a GPT-OSS-120B provider and replace REPLACE_WITH_GPT_OSS_120B_MODEL_ID
     in $SRC/opencode.jsonc (see docs/MODELS.md; run scripts/check-models.sh).
  3. Verify:
       $REPO_ROOT/scripts/validate.sh
       opencode debug config
       opencode agent list
  4. Optional tools: playwright-cli, glab (glab auth login), oxfmt per project.
     See docs/INSTALL.md.
NEXT
