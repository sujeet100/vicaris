#!/usr/bin/env bash
#
# dev-flow-gate.sh — run one repo's verify command and record the verdict where
# every later stage looks for it.
#
# The recording is the point. Without it `test` re-runs a suite `implement` already
# ran, `handover` narrates a result it half remembers, and a resumed session cannot
# tell a repo that passed from one that was never verified at all. With it, the
# result is a file: one line to read instead of a suite to re-run.
#
# Usage:  dev-flow-gate.sh <repo> "<verify command>"
#         Exit 0 pass · 1 fail · 2 misuse
#
# Writes <repo>/.dev-flow/verify-<branch>.txt, first line `RESULT: pass|fail`.

set -uo pipefail

repo="${1:-}"; cmd="${2:-}"
[ -n "$repo" ] && [ -n "$cmd" ] || { echo "usage: dev-flow-gate.sh <repo> \"<verify command>\"" >&2; exit 2; }
[ -d "$repo" ] || { echo "not a directory: $repo" >&2; exit 2; }

branch=$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null) || { echo "not a git repo: $repo" >&2; exit 2; }
out_dir="$repo/.dev-flow"; mkdir -p "$out_dir"
out="$out_dir/verify-$branch.txt"
log=$(mktemp "${TMPDIR:-/tmp}/devflow-verify-XXXXXX")

started=$(date +%s)
( cd "$repo" && eval "$cmd" ) >"$log" 2>&1
status=$?
elapsed=$(( $(date +%s) - started ))

[ $status -eq 0 ] && result=pass || result=fail

{
  printf 'RESULT: %s\n' "$result"
  printf 'repo: %s\nbranch: %s\ncommand: %s\nexit: %s\nseconds: %s\nat: %s\n\n' \
    "$(basename "$repo")" "$branch" "$cmd" "$status" "$elapsed" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  # Keep the tail on success and the whole thing on failure: a passing run needs
  # only its summary line, and a failing one is about to be read closely.
  if [ "$result" = pass ]; then tail -n 30 "$log"; else cat "$log"; fi
} > "$out"
rm -f "$log"

printf '%s: %s (%ss) → %s\n' "$(basename "$repo")" "$result" "$elapsed" "$out"
[ "$result" = pass ] || { echo "verify failed — fix it before spending a reviewer on this" >&2; exit 1; }
exit 0
