#!/usr/bin/env bash
# SessionStart: re-inject the run's own state after a compaction (and on resume).
#
# A compaction can drop the things a Vicaris run cannot afford to lose: the repo
# manifest, the branch, the autonomy contract's shape, and the fact that a handover
# doc exists at all. Half a cross-repo change quietly becoming "the repo I happen to
# be in" is the defining failure of this workflow, and that is exactly what a
# summariser is likely to flatten.
#
# SessionStart output is injected into the model's context, and the "compact" matcher
# makes it fire after every compaction, so this is where the run reminds itself what
# it is doing. It says nothing when there is no Vicaris run in the current repo.
#
# Escape hatch: VICARIS_SESSION_CONTEXT_OFF=1 skips it.

set -uo pipefail   # fails open by design

[ "${VICARIS_SESSION_CONTEXT_OFF:-0}" = "1" ] && exit 0

# shellcheck source=handover-stale.sh
source "$(dirname "${BASH_SOURCE[0]}")/handover-stale.sh" 2>/dev/null \
  || handover_is_stale() { return 1; }   # fail open

repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
branch=$(git -C "$repo_root" rev-parse --abbrev-ref HEAD 2>/dev/null) || exit 0
[ -z "$branch" ] || [ "$branch" = "HEAD" ] && exit 0

vicaris_dir="$repo_root/.vicaris"
[ -d "$vicaris_dir" ] || exit 0

manifest="$vicaris_dir/repos-$branch.txt"
handover="$vicaris_dir/handover-$branch.md"
understanding="$vicaris_dir/understanding-$branch.md"
risk="$vicaris_dir/risk-$branch.txt"
ledger="$vicaris_dir/fix-ledger-$branch.md"
thread="$vicaris_dir/slack-thread-$branch.txt"

if [ ! -f "$manifest" ] && [ ! -f "$understanding" ] && [ ! -f "$handover" ]; then
  exit 0
fi

{
  printf '## Vicaris run in progress\n\n'
  printf 'Branch `%s` in `%s`.\n\n' "$branch" "$repo_root"

  if [ ! -f "$handover" ]; then
    printf '**No handover doc exists for this branch, and context has just been summarised.**\n'
    printf 'Write one now, before doing anything else — the detail it should capture is exactly what\n'
    printf 'a compaction discards:\n`%s`\n\n' "$handover"
  elif handover_is_stale "$handover" "$repo_root" "$manifest"; then
    printf '**The handover doc predates the latest work on this branch, so it is stale.**\n'
    printf 'Refresh it now; work has happened that it does not record:\n`%s`\n\n' "$handover"
  else
    printf 'A handover doc exists and is the authority on where things stand — **read it before acting**:\n`%s`\n\n' "$handover"
  fi

  if [ -f "$manifest" ]; then
    printf 'Repos in scope — every stage covers each `change` repo and leaves `read` repos untouched. `scripts/vicaris-status.sh` checks this rather than you remembering it:\n'
    # cut, not `IFS=$'\t' read`: tab is IFS whitespace and a blank base would collapse.
    while IFS= read -r line; do
      path=$(printf '%s' "$line" | cut -f1); base=$(printf '%s' "$line" | cut -sf2); role=$(printf '%s' "$line" | cut -sf3)
      [ -n "$path" ] && printf -- '- `%s` · %s · base %s\n' "$path" "${role:-change}" "${base:-remote default}"
    done < <(grep -v '^#' "$manifest")
    printf '\n'
  fi

  # The risk class gates every remaining stage, so losing it silently means running
  # either too much ceremony or — the failure that matters — too little.
  if [ -f "$risk" ]; then
    printf 'Risk class (gates design note, design challenge, review passes, browser leg):\n'
    sed -n '1,2p' "$risk" | sed 's/^/- /'
    printf '\n'
  fi

  [ -f "$understanding" ] && printf 'Understanding (acceptance criteria + the readings rejected): `%s`\n' "$understanding"
  if [ -f "$ledger" ]; then
    printf 'Fix ledger: `%s` — %s pass(es) recorded. The loop cap is two; a cap reset by a compaction is not a cap.\n' \
      "$ledger" "$(grep -ci '^## pass' "$ledger" 2>/dev/null || echo 0)"
  fi
  [ -f "$thread" ] && printf 'Slack thread ts: `%s` (thread every ping under it)\n' "$(cat "$thread" 2>/dev/null)"
  printf '\nContext was just compacted or resumed, so detail has been summarised away. Do not re-derive\n'
  printf 'decisions the handover doc already records, and do not re-litigate settled forks.\n'
} > /tmp/vicaris-session-context.$$ 2>/dev/null

ctx=$(cat /tmp/vicaris-session-context.$$ 2>/dev/null)
rm -f /tmp/vicaris-session-context.$$ 2>/dev/null

[ -z "$ctx" ] && exit 0

if command -v jq >/dev/null 2>&1; then
  jq -n --arg ctx "$ctx" '{
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: $ctx
    }
  }'
else
  printf '%s\n' "$ctx"   # plain stdout is read as a system reminder too
fi

exit 0
