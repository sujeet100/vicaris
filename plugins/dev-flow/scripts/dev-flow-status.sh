#!/usr/bin/env bash
#
# dev-flow-status.sh — one table showing where every repo in the run stands.
#
# "Every stage must cover every repo" was enforced by repeating it in seven files,
# which is the least reliable mechanism available: prose cannot fail a run. This
# can. It reads the artifacts the stages already write and exits non-zero when a
# repo has commits but no verify result, or commits but no MR.
#
# Usage:  dev-flow-status.sh [manifest]     (default: <this repo>/.dev-flow/repos-<branch>.txt)
#         Exit 0 complete · 3 gaps found · 2 misuse

set -uo pipefail

primary=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "not in a git repo" >&2; exit 2; }
branch=$(git -C "$primary" rev-parse --abbrev-ref HEAD)
manifest="${1:-$primary/.dev-flow/repos-$branch.txt}"
repos=$( [ -f "$manifest" ] && grep -v '^$' "$manifest" || echo "$primary" )

risk_file="$primary/.dev-flow/risk-$branch.txt"
[ -f "$risk_file" ] && sed -n '1p' "$risk_file" || echo "RISK: unclassified — the understand stage never wrote $risk_file"
printf 'branch: %s\n\n' "$branch"

printf '%-26s %-8s %-9s %-7s %s\n' REPO COMMITS VERIFY MR NOTE
gaps=0
for repo in $repos; do
  name=$(basename "$repo")
  [ -d "$repo" ] || { printf '%-26s %-8s %-9s %-7s %s\n' "$name" "-" "-" "-" "MISSING path"; gaps=$((gaps+1)); continue; }

  base=$(git -C "$repo" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null \
    || git -C "$repo" remote show origin 2>/dev/null | sed -n 's|.*HEAD branch: |origin/|p')
  if [ -n "$base" ]; then commits=$(git -C "$repo" rev-list --count "$base"..HEAD 2>/dev/null || echo "?"); else commits="?"; fi

  vfile="$repo/.dev-flow/verify-$branch.txt"
  verify=$( [ -f "$vfile" ] && sed -n 's/^RESULT: //p' "$vfile" || echo none )

  mrfile="$repo/.dev-flow/mr-$branch.txt"
  mr=$( [ -s "$mrfile" ] && echo yes || echo no )

  note=""
  if [ "$commits" = "0" ]; then
    note="no changes — fine if the plan said so"
  else
    [ "$verify" = none ] && { note="NOT VERIFIED"; gaps=$((gaps+1)); }
    [ "$verify" = fail ] && { note="VERIFY FAILING"; gaps=$((gaps+1)); }
    [ "$mr" = no ] && { note="${note:+$note · }NO MR — this work never ships"; gaps=$((gaps+1)); }
  fi
  printf '%-26s %-8s %-9s %-7s %s\n' "$name" "$commits" "$verify" "$mr" "$note"
done

ledger="$primary/.dev-flow/fix-ledger-$branch.md"
if [ -f "$ledger" ]; then
  printf '\nfix passes recorded: %s · outstanding: %s\n' \
    "$(grep -ci '^## pass' "$ledger" || echo 0)" "$(grep -ci 'declined\|outstanding' "$ledger" || echo 0)"
fi

for doc in design-challenge handover completion; do
  f="$primary/.dev-flow/$doc-$branch.md"
  [ -f "$f" ] || printf '%s doc: not written\n' "$doc"
done

[ "$gaps" -eq 0 ] && { printf '\nEvery repo accounted for.\n'; exit 0; }
printf '\n%s gap(s) above. A stage that quietly did one repo is this workflow'"'"'s defining failure.\n' "$gaps"
exit 3
