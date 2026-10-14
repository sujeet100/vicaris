#!/usr/bin/env bash
# handover-stale.sh — sourced by both Vicaris hooks; defines handover_is_stale.
#
# The handover doc is stale when anything the run produced is newer than it: a
# commit, a file under .vicaris/, or an uncommitted change in any repo in the
# manifest. Comparing against the newest commit alone was not enough, because a
# run does not commit until finalize — so once the doc was first written it never
# looked stale again, and the guard only fired when the doc was missing.
#
# Timestamps rather than `.git/HEAD`: in a git worktree `.git` is a file, so a
# `-ot` test against `.git/HEAD` silently returns false.

handover_is_stale() {
  local doc="$1" root="$2" manifest="${3:-}" doc_mtime commit_ts repo path
  [ -f "$doc" ] || return 1
  doc_mtime=$(stat -f %m "$doc" 2>/dev/null || stat -c %Y "$doc" 2>/dev/null) || return 1

  commit_ts=$(git -C "$root" log -1 --format=%ct 2>/dev/null)
  [ -n "$commit_ts" ] && [ "$doc_mtime" -lt "$commit_ts" ] && return 0

  # Run artifacts: notes, ledger, verify files. The handover itself and the
  # guard's own marker do not count.
  [ -n "$(find "$root/.vicaris" -type f -newer "$doc" \
            ! -name 'handover-*' ! -name '.precompact-*' 2>/dev/null | head -1)" ] && return 0

  # Uncommitted edits in every repo the run touches.
  for repo in "$root" $( [ -f "$manifest" ] && cut -f1 "$manifest" | grep -v '^#' ); do
    [ -d "$repo" ] || continue
    while IFS= read -r path; do
      [ -n "$path" ] && [ "$repo/$path" -nt "$doc" ] && return 0
    done < <(git -C "$repo" status --porcelain --untracked-files=normal 2>/dev/null \
               | sed -E 's/^.. //; s/.* -> //' | grep -v '^\.vicaris/')
  done
  return 1
}
