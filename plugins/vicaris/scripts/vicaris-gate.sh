#!/usr/bin/env bash
#
# vicaris-gate.sh — run one repo's verify command and record the verdict where
# every later stage looks for it.
#
# The recording is the point. Without it `test` re-runs a suite `implement` already
# ran, `handover` narrates a result it half remembers, and a resumed session cannot
# tell a repo that passed from one that was never verified at all. With it, the
# result is a file: one line to read instead of a suite to re-run.
#
# A result is only worth reading if it is about the code that is there now, so the
# file also records the fingerprint of the tree it ran against: the content of the
# working tree, untracked files included, so a commit of that same code keeps it. `--check` compares that with the
# tree as it stands, which is how a later stage tells "passed" from "passed, then a
# fix pass edited three files".
#
# Usage:  vicaris-gate.sh <repo> "<verify command>"
#         Exit 0 pass · 1 fail · 2 misuse
#         vicaris-gate.sh --check <repo>
#         Exit 0 passed on this exact tree · 1 recorded fail · 3 missing or stale
#
# Writes <repo>/.vicaris/verify-<branch>.txt, first line `RESULT: pass|fail`.

set -uo pipefail
. "$(dirname "$0")/vicaris-manifest.sh"

if [ "${1:-}" = "--check" ]; then
  repo="${2:-}"
  [ -d "$repo" ] || { echo "usage: vicaris-gate.sh --check <repo>" >&2; exit 2; }
  branch=$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null) || { echo "not a git repo: $repo" >&2; exit 2; }
  out="$repo/.vicaris/verify-$branch.txt"
  name=$(basename "$repo")
  [ -f "$out" ] || { echo "$name: no verify result — run the gate"; exit 3; }
  result=$(sed -n 's/^RESULT: //p' "$out")
  recorded=$(sed -n 's/^fingerprint: //p' "$out")
  [ "$result" = pass ] || { echo "$name: recorded fail → $out"; exit 1; }
  [ -n "$recorded" ] && [ "$recorded" = "$(vm_fingerprint "$repo")" ] \
    || { echo "$name: passed on an earlier tree — the code has changed since, run the gate again"; exit 3; }
  echo "$name: pass, current"
  exit 0
fi

repo="${1:-}"; cmd="${2:-}"
[ -n "$repo" ] && [ -n "$cmd" ] || { echo "usage: vicaris-gate.sh <repo> \"<verify command>\"" >&2; exit 2; }
[ -d "$repo" ] || { echo "not a directory: $repo" >&2; exit 2; }

branch=$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null) || { echo "not a git repo: $repo" >&2; exit 2; }
out_dir="$repo/.vicaris"; mkdir -p "$out_dir"
out="$out_dir/verify-$branch.txt"; mkdir -p "$(dirname "$out")"
log=$(mktemp "${TMPDIR:-/tmp}/vicaris-verify-XXXXXX")

before=$(vm_fingerprint "$repo")
started=$(date +%s)
( cd "$repo" && eval "$cmd" ) >"$log" 2>&1
status=$?
elapsed=$(( $(date +%s) - started ))
# Recorded after the run, so files the verify command itself generates (and that
# .gitignore misses) do not make every later check stale. A difference from the
# fingerprint taken before is worth a line, since it can also mean an edit landed
# while the suite was running.
after=$(vm_fingerprint "$repo")

[ $status -eq 0 ] && result=pass || result=fail

{
  printf 'RESULT: %s\n' "$result"
  printf 'repo: %s\nbranch: %s\ncommand: %s\nexit: %s\nseconds: %s\nat: %s\nhead: %s\nfingerprint: %s\n' \
    "$(basename "$repo")" "$branch" "$cmd" "$status" "$elapsed" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    "$(git -C "$repo" rev-parse HEAD 2>/dev/null)" "$after"
  [ "$before" = "$after" ] || printf 'note: the tree changed while verify ran (generated files, or an edit landed mid-run)\n'
  printf '\n'
  # Keep the tail on success and the whole thing on failure: a passing run needs
  # only its summary line, and a failing one is about to be read closely.
  if [ "$result" = pass ]; then tail -n 30 "$log"; else cat "$log"; fi
} > "$out"
rm -f "$log"

printf '%s: %s (%ss) → %s\n' "$(basename "$repo")" "$result" "$elapsed" "$out"
[ "$result" = pass ] || { echo "verify failed — fix it before spending a reviewer on this" >&2; exit 1; }
exit 0
