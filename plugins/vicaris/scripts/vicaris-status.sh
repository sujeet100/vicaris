#!/usr/bin/env bash
#
# vicaris-status.sh — one table showing where every repo in the run stands.
#
# "Every stage must cover every repo" was enforced by repeating it in seven files,
# which is the least reliable mechanism available: prose cannot fail a run. This
# can. It reads the artifacts the stages already write and exits non-zero when a
# repo has work but no verify result, a verify result about older code, or (at the
# end) no MR.
#
# Work means commits or uncommitted changes, untracked files included. Nothing
# commits until finalize, so a table that counted only commits reported every
# repo as "no changes — fine" right up to the moment it mattered.
#
# Usage:  vicaris-status.sh [--final] [manifest]   (default: <this repo>/.vicaris/repos-<branch>.txt)
#           --final  also require an MR and a clean tree in every repo with work;
#                    without it, a missing MR is expected and not a gap
#         Exit 0 complete · 3 gaps found · 2 misuse

set -uo pipefail
. "$(dirname "$0")/vicaris-manifest.sh"

final=0
[ "${1:-}" = "--final" ] && { final=1; shift; }

primary=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "not in a git repo" >&2; exit 2; }
branch=$(git -C "$primary" rev-parse --abbrev-ref HEAD)
manifest="${1:-$primary/.vicaris/repos-$branch.txt}"
[ -f "$manifest" ] || manifest="$primary"

risk_file="$primary/.vicaris/risk-$branch.txt"
[ -f "$risk_file" ] && sed -n '1p' "$risk_file" || echo "RISK: unclassified — the understand stage never wrote $risk_file"
printf 'branch: %s\n\n' "$branch"

row() { printf '%-26s %-6s %-14s %-7s %-6s %-9s %-4s %s\n' "$@"; }
row REPO ROLE BASE COMMITS DIRTY VERIFY MR NOTE
gaps=0
gate="$(dirname "$0")/vicaris-gate.sh"
while IFS=$'\t' read -r repo base role; do
  name=$(basename "$repo")
  [ -d "$repo" ] || { row "$name" "$role" "${base:--}" - - - - "MISSING path"; gaps=$((gaps+1)); continue; }

  commits=$(vm_commits "$repo" "$base")
  changed=$(vm_changed "$repo" "$base" | grep -c . || true)
  dirty=$(git -C "$repo" status --porcelain --untracked-files=normal -- . ':(exclude).vicaris' 2>/dev/null | grep -c . || true)

  vfile="$repo/.vicaris/verify-$branch.txt"
  verify=$( [ -f "$vfile" ] && sed -n 's/^RESULT: //p' "$vfile" || echo none )
  if [ "$verify" = pass ]; then "$gate" --check "$repo" >/dev/null || verify=stale; fi

  mrfile="$repo/.vicaris/mr-$branch.txt"
  mr=$( [ -s "$mrfile" ] && echo yes || echo no )

  note=""
  gap() { note="${note:+$note · }$1"; gaps=$((gaps+1)); }
  if [ "$role" = read ]; then
    [ "$changed" -gt 0 ] && gap "READ-ONLY repo has $changed changed file(s)"
  elif [ "$commits" = "?" ]; then
    gap "base $base not resolvable"
  elif [ "$commits" = "0" ] && [ "$changed" -eq 0 ]; then
    note="no changes — fine if the plan said so"
  else
    case "$verify" in
      none)  gap "NOT VERIFIED";;
      fail)  gap "VERIFY FAILING";;
      stale) gap "VERIFY STALE — code changed since it passed";;
    esac
    if [ "$final" -eq 1 ]; then
      [ "$dirty" -gt 0 ] && gap "UNCOMMITTED changes"
      [ "$mr" = no ] && gap "NO MR — this work never ships"
    fi
  fi
  row "$name" "$role" "${base:--}" "$commits" "$dirty" "$verify" "$mr" "$note"
done < <(vm_list "$manifest")

ledger="$primary/.vicaris/fix-ledger-$branch.md"
if [ -f "$ledger" ]; then
  printf '\nfix passes recorded: %s · outstanding: %s\n' \
    "$(grep -ci '^## pass' "$ledger" || echo 0)" "$(grep -ci 'declined\|outstanding' "$ledger" || echo 0)"
fi

for doc in design-challenge handover completion; do
  f="$primary/.vicaris/$doc-$branch.md"
  [ -f "$f" ] || printf '%s doc: not written\n' "$doc"
done

[ "$gaps" -eq 0 ] && { printf '\nEvery repo accounted for.\n'; exit 0; }
printf '\n%s gap(s) above. A stage that quietly did one repo is this workflow'"'"'s defining failure.\n' "$gaps"
exit 3
