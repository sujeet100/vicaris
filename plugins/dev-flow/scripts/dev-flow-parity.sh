#!/usr/bin/env bash
#
# dev-flow-parity.sh — for a mechanical change, list every existing instance of the
# pattern and mark which ones this branch touched.
#
# A mechanical change fails by being incomplete, not by being ugly: the field that
# reaches three of four consumers, the enum value with no `match` arm, the prompt
# updated for US and not UK. Craft review barely sees that; this does, and it is a
# grep rather than an agent.
#
# The judgement stays with the caller. This answers "where does the pattern live and
# what did you touch", which is mechanical. Whether an untouched instance is
# correctly untouched is the part worth a model's attention, and every UNTOUCHED row
# below needs an answer before the change is called complete.
#
# Usage:  dev-flow-parity.sh <repo> <pattern> [path-filter]
#           <pattern>      an extended regex naming the shape (a field, an enum
#                          member, a call site, a filename stem)
#           [path-filter]  optional glob restricting the search, e.g. 'prompts/*'
#
# Exit 0 when every instance was touched, 3 when some were not, 2 on misuse.

set -uo pipefail

repo="${1:-}"; pattern="${2:-}"; filter="${3:-}"
[ -n "$repo" ] && [ -n "$pattern" ] || { echo "usage: dev-flow-parity.sh <repo> <pattern> [path-filter]" >&2; exit 2; }
[ -d "$repo" ] || { echo "not a directory: $repo" >&2; exit 2; }

base=$(git -C "$repo" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null \
  || git -C "$repo" remote show origin 2>/dev/null | sed -n 's|.*HEAD branch: |origin/|p')
[ -n "$base" ] || base=$(git -C "$repo" rev-parse --abbrev-ref HEAD@{upstream} 2>/dev/null) || base=""
[ -n "$base" ] || { echo "no upstream base resolved for $repo — cannot tell touched from untouched" >&2; exit 2; }

touched=$( { git -C "$repo" diff "$base"...HEAD --name-only; git -C "$repo" diff --name-only; } 2>/dev/null | sort -u )

if [ -n "$filter" ]; then
  instances=$(git -C "$repo" grep -lE "$pattern" -- "$filter" 2>/dev/null | sort -u)
else
  instances=$(git -C "$repo" grep -lE "$pattern" 2>/dev/null | sort -u)
fi

[ -n "$instances" ] || { echo "no file matches /$pattern/ in $(basename "$repo") — check the pattern before concluding the change is complete" >&2; exit 2; }

printf 'parity · %s · /%s/%s\n\n' "$(basename "$repo")" "$pattern" "${filter:+ under $filter}"
missed=0
while IFS= read -r f; do
  if printf '%s\n' "$touched" | grep -qxF "$f"; then
    printf '  TOUCHED    %s\n' "$f"
  else
    printf '  UNTOUCHED  %s\n' "$f"; missed=$((missed + 1))
  fi
done <<< "$instances"

total=$(printf '%s\n' "$instances" | grep -c .)
printf '\n%s of %s instances touched.\n' "$(( total - missed ))" "$total"
[ "$missed" -eq 0 ] && { echo "Every instance of the pattern is in this change."; exit 0; }
echo "Account for each UNTOUCHED file: either it needs the change too, or say why it correctly does not."
exit 3
