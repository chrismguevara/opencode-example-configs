#!/usr/bin/env bash
# Copy the project template (AGENTS.md, opencode.jsonc, .agents/skills/*) into
# a target repository WITHOUT overwriting anything that already exists.
#
# Usage:
#   ./scripts/install-project-template.sh /path/to/project [--dry-run] [--force] [--cline-symlink]
#
#   --dry-run         show what would be copied/skipped, change nothing
#   --force           replace conflicting files after backing them up (<name>.bak.<timestamp>)
#   --cline-symlink   also create .cline/skills -> ../.agents/skills for teammates using Cline
#                     (Cline reads .cline/skills, .clinerules/skills, .claude/skills; not .agents/skills)
#
# Conflict rule: an existing file that differs from the template is reported as
# CONFLICT and left untouched unless --force is given. Identical files are skipped.

set -euo pipefail

DEST=""
DRY_RUN=0
FORCE=0
CLINE=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --force) FORCE=1 ;;
    --cline-symlink) CLINE=1 ;;
    -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "unknown option: $arg" >&2; exit 2 ;;
    *) DEST="$arg" ;;
  esac
done
[ -n "$DEST" ] || { echo "usage: $0 /path/to/project [--dry-run] [--force] [--cline-symlink]" >&2; exit 2; }
[ -d "$DEST" ] || { echo "error: destination is not a directory: $DEST" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
SRC="$REPO_ROOT/project-template"
DEST="$(cd "$DEST" && pwd -P)"
STAMP="$(date +%Y%m%d-%H%M%S)"

run() { if [ "$DRY_RUN" -eq 1 ]; then echo "  [dry-run] $*"; else "$@"; fi; }

# Files to install, relative to project-template/.
mapfile -t FILES < <(cd "$SRC" && find . -type f \( -name 'AGENTS.md' -o -name 'opencode.jsonc' -o -path './.agents/skills/*/SKILL.md' \) | sed 's#^\./##' | sort)

copied=0; skipped=0; conflicts=0
echo "Template : $SRC"
echo "Project  : $DEST"
[ "$DRY_RUN" -eq 1 ] && echo "Mode     : dry-run"
echo

for rel in "${FILES[@]}"; do
  src="$SRC/$rel"
  dst="$DEST/$rel"
  if [ -e "$dst" ]; then
    if cmp -s "$src" "$dst"; then
      printf '  %-9s %s\n' "SKIP" "$rel (identical)"
      skipped=$((skipped + 1))
      continue
    fi
    if [ "$FORCE" -eq 1 ]; then
      printf '  %-9s %s -> %s\n' "BACKUP" "$rel" "$rel.bak.$STAMP"
      run mv "$dst" "$dst.bak.$STAMP"
    else
      printf '  %-9s %s (exists and differs; use --force to replace after backup)\n' "CONFLICT" "$rel"
      conflicts=$((conflicts + 1))
      continue
    fi
  fi
  printf '  %-9s %s\n' "COPY" "$rel"
  run mkdir -p "$(dirname "$dst")"
  run cp "$src" "$dst"
  copied=$((copied + 1))
done

if [ "$CLINE" -eq 1 ]; then
  link="$DEST/.cline/skills"
  if [ -L "$link" ]; then
    printf '  %-9s %s -> %s (symlink exists)\n' "SKIP" ".cline/skills" "$(readlink "$link")"
  elif [ -e "$link" ]; then
    printf '  %-9s %s exists and is not a symlink; not touching it\n' "CONFLICT" ".cline/skills"
    conflicts=$((conflicts + 1))
  else
    printf '  %-9s %s -> %s\n' "LINK" ".cline/skills" "../.agents/skills"
    run mkdir -p "$DEST/.cline"
    run ln -s "../.agents/skills" "$link"
  fi
fi

echo
echo "copied=$copied skipped=$skipped conflicts=$conflicts"
if [ "$conflicts" -gt 0 ]; then
  echo "Resolve conflicts manually (diff the files) or re-run with --force."
  exit 3
fi
cat <<NEXT

Next steps in $DEST:
  - Review AGENTS.md and opencode.jsonc; remove sections that do not apply.
  - Ensure oxfmt is a devDependency if the project has JS/TS (see docs/INSTALL.md).
  - Run: opencode debug skill   (skills should be listed)
NEXT
