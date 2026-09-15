#!/usr/bin/env bash
# SessionStart: re-inject the run's own state after a compaction (and on resume).
#
# A compaction can drop the things a dev-flow run cannot afford to lose: the repo
# manifest, the branch, the autonomy contract's shape, and the fact that a handover
# doc exists at all. Half a cross-repo change quietly becoming "the repo I happen to
# be in" is the defining failure of this workflow, and that is exactly what a
# summariser is likely to flatten.
#
# SessionStart output is injected into the model's context, and the "compact" matcher
# makes it fire after every compaction, so this is where the run reminds itself what
# it is doing. It says nothing when there is no dev-flow run in the current repo.
#
# Escape hatch: DEVFLOW_SESSION_CONTEXT_OFF=1 skips it.

set -uo pipefail   # fails open by design

[ "${DEVFLOW_SESSION_CONTEXT_OFF:-0}" = "1" ] && exit 0

# Is the handover doc older than the branch's newest commit? Compared as timestamps, not
# via `.git/HEAD`: in a git *worktree* — which is how dev-flow runs whenever Sujit has
# uncommitted work — `$repo_root/.git` is a file rather than a directory, so `.git/HEAD`
# does not exist and a `-ot` test against it silently returns false. That made staleness
# undetectable in exactly the case it matters.
handover_is_stale() {
  local doc="$1" root="$2" doc_mtime commit_ts
  [ -f "$doc" ] || return 1
  doc_mtime=$(stat -f %m "$doc" 2>/dev/null || stat -c %Y "$doc" 2>/dev/null) || return 1
  commit_ts=$(git -C "$root" log -1 --format=%ct 2>/dev/null) || return 1
  [ -n "$doc_mtime" ] && [ -n "$commit_ts" ] && [ "$doc_mtime" -lt "$commit_ts" ]
}

repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
branch=$(git -C "$repo_root" rev-parse --abbrev-ref HEAD 2>/dev/null) || exit 0
[ -z "$branch" ] || [ "$branch" = "HEAD" ] && exit 0

dev_flow_dir="$repo_root/.dev-flow"
[ -d "$dev_flow_dir" ] || exit 0

manifest="$dev_flow_dir/repos-$branch.txt"
handover="$dev_flow_dir/handover-$branch.md"
plan="$dev_flow_dir/plan-$branch.md"
thread="$dev_flow_dir/slack-thread-$branch.txt"

if [ ! -f "$manifest" ] && [ ! -f "$plan" ] && [ ! -f "$handover" ]; then
  exit 0
fi

{
  printf '## dev-flow run in progress\n\n'
  printf 'Branch `%s` in `%s`.\n\n' "$branch" "$repo_root"

  if [ ! -f "$handover" ]; then
    printf '**No handover doc exists for this branch, and context has just been summarised.**\n'
    printf 'Write one now, before doing anything else — the detail it should capture is exactly what\n'
    printf 'a compaction discards:\n`%s`\n\n' "$handover"
  elif handover_is_stale "$handover" "$repo_root"; then
    printf '**The handover doc predates the latest commit on this branch, so it is stale.**\n'
    printf 'Refresh it now; work has happened that it does not record:\n`%s`\n\n' "$handover"
  else
    printf 'A handover doc exists and is the authority on where things stand — **read it before acting**:\n`%s`\n\n' "$handover"
  fi

  if [ -f "$manifest" ]; then
    printf 'Repos in scope (every stage must cover all of them; a stage that quietly did one repo is this workflow'"'"'s defining failure):\n'
    while IFS= read -r line; do
      [ -n "$line" ] && printf -- '- `%s`\n' "$line"
    done < "$manifest"
    printf '\n'
  fi

  [ -f "$plan" ] && printf 'Plan: `%s`\n' "$plan"
  [ -f "$thread" ] && printf 'Slack thread ts: `%s` (thread every ping under it)\n' "$(cat "$thread" 2>/dev/null)"
  printf '\nContext was just compacted or resumed, so detail has been summarised away. Do not re-derive\n'
  printf 'decisions the handover doc already records, and do not re-litigate settled forks.\n'
} > /tmp/devflow-session-context.$$ 2>/dev/null

ctx=$(cat /tmp/devflow-session-context.$$ 2>/dev/null)
rm -f /tmp/devflow-session-context.$$ 2>/dev/null

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
