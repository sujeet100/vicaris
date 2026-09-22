#!/usr/bin/env bash
#
# mr-review-root.sh — print the mr-review plugin root, or exit 1.
#
# The design-challenge stage reads two charter files that live in the separate
# `mr-review` plugin (blind_design.md and blind_compare.md). That plugin knows
# where it is; from outside it, the path has to be discovered. Resolution order:
#
#   1. $VICARIS_MR_REVIEW_ROOT            — explicit override, wins over everything
#   2. the installed plugin cache         — highest version when several are present
#   3. a sibling checkout beside Vicaris — for working on both plugins at once
#
# Prints an absolute path on success. Prints nothing and exits 1 when the plugin
# is not installed, which is a supported state: the caller falls back.

set -uo pipefail

has_charter() { [ -f "$1/charter/blind_design.md" ] && [ -f "$1/charter/blind_compare.md" ]; }

if [ -n "${VICARIS_MR_REVIEW_ROOT:-}" ] && has_charter "$VICARIS_MR_REVIEW_ROOT"; then
  printf '%s\n' "$VICARIS_MR_REVIEW_ROOT"
  exit 0
fi

# Installed plugin cache. Layouts seen in the wild: <marketplace>/mr-review/<version>/
# and the flat <marketplace>/mr-review/. `sort -V` picks the newest version directory.
for candidate in $(ls -d "$HOME"/.claude/plugins/cache/*/mr-review*/*/ \
                          "$HOME"/.claude/plugins/cache/*/mr-review*/ 2>/dev/null | sort -Vr); do
  candidate="${candidate%/}"
  if has_charter "$candidate"; then
    printf '%s\n' "$candidate"
    exit 0
  fi
done

# A sibling checkout, for when both plugins are being edited together.
here=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
for candidate in "$here/../mr-review" "$here/../../mr-reviewer/plugins/mr-review"; do
  if [ -d "$candidate" ] && has_charter "$candidate"; then
    ( cd "$candidate" && pwd )
    exit 0
  fi
done

exit 1
