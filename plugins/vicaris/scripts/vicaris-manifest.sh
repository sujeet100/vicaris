#!/usr/bin/env bash
#
# vicaris-manifest.sh — the one place that knows what the repo manifest says and
# what "changed" means. Every other script sources it.
#
# The manifest is <primary>/.vicaris/repos-<branch>.txt, one repo per line:
#
#     <absolute path> TAB <base ref> TAB <role>
#
#   base   the ref this branch was cut from and its MR targets, e.g. origin/us-qa.
#          Left blank, it is the remote's default branch.
#   role   change — the run edits this repo, so it is built, verified, reviewed
#                   and gets an MR
#          read   — the run reads it for context and must leave it untouched
#
# A bare path on its own line still works and means "default base, change", which
# is what every manifest written before this format was.
#
# Two facts this file exists to keep straight, because the run got both wrong:
#
#   - The base is per repo. A deployment repo cut from origin/us-qa and diffed
#     against origin/HEAD shows every commit on us-qa that main lacks, and the risk
#     check then tags someone else's pricing and RBAC files as this change's.
#   - Work is not only commits. Nothing commits until finalize, so a check that
#     reads `base...HEAD` sees nothing before then, and a new file is invisible to
#     `git diff` until it is staged. Changed files here are the merge-base against
#     the working tree, staged, unstaged and untracked alike.
#
# Usage as a command (sourcing it gives the same functions, prefixed vm_):
#   vicaris-manifest.sh list <manifest-or-repo> [change|read|all]   path TAB base TAB role
#                                                                   (base `-` when unresolvable)
#   vicaris-manifest.sh base <repo>                                 resolved base ref
#   vicaris-manifest.sh changed <repo> [base]                       changed paths
#   vicaris-manifest.sh fingerprint <repo>                          tree hash of the working state

vm_default_base() {
  local repo="$1" b
  b=$(git -C "$repo" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null) \
    || b=$(git -C "$repo" remote show origin 2>/dev/null | sed -n 's|.*HEAD branch: |origin/|p')
  [ -n "$b" ] || b=$(git -C "$repo" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null) || b=""
  printf '%s' "$b"
}

vm_realpath() { (cd "$1" 2>/dev/null && pwd -P); }

# Normalised manifest lines. A directory instead of a manifest is a one-repo run.
vm_list() {
  local target="$1" want="${2:-all}" path base role
  if [ -d "$target" ]; then
    local b; b=$(vm_default_base "$target")
    printf '%s\t%s\tchange\n' "$target" "${b:--}"
    return
  fi
  [ -f "$target" ] || return 1
  local line rest
  # Split by hand: tab is IFS whitespace, so `read` would collapse the two tabs
  # around a blank base and shift the role into its place.
  while IFS= read -r line || [ -n "$line" ]; do
    path="${line%%$'\t'*}"; rest=""; [ "$path" = "$line" ] || rest="${line#*$'\t'}"
    base="${rest%%$'\t'*}"; role=""; [ "$base" = "$rest" ] || role="${rest#*$'\t'}"
    role="${role%%$'\t'*}"
    path="${path%"${path##*[![:space:]]}"}"; base="${base//[[:space:]]/}"; role="${role//[[:space:]]/}"
    [ -n "$path" ] || continue
    case "$path" in \#*) continue;; esac
    [ -n "$role" ] || role=change
    [ -n "$base" ] || base=$( [ -d "$path" ] && vm_default_base "$path" )
    [ "$want" = all ] || [ "$want" = "$role" ] || continue
    printf '%s\t%s\t%s\n' "$path" "${base:--}" "$role"
  done < "$target"
}

# The base for one repo: the manifest line that names it, wherever the manifest is,
# then the remote default. Looks in the caller's repo and in the repo itself, since
# either may be the primary that holds the manifest.
vm_base() {
  local repo="$1" real branch top m path base role
  real=$(vm_realpath "$repo") || return 1
  branch=$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null)
  for top in "$(git rev-parse --show-toplevel 2>/dev/null)" "$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null)"; do
    m="$top/.vicaris/repos-$branch.txt"
    [ -n "$top" ] && [ -f "$m" ] || continue
    while IFS=$'\t' read -r path base role; do
      [ "$(vm_realpath "$path")" = "$real" ] && { [ "$base" = - ] || printf '%s' "$base"; return 0; }
    done < <(vm_list "$m")
  done
  vm_default_base "$repo"
}

# Every path this branch has changed against its base, committed or not.
vm_changed() {
  local repo="$1" base="${2:-}" mb
  [ -n "$base" ] && [ "$base" != - ] || base=$(vm_base "$repo")
  [ -n "$base" ] || return 1
  mb=$(git -C "$repo" merge-base "$base" HEAD 2>/dev/null) || return 1
  {
    git -C "$repo" diff --name-only "$mb" -- . ':(exclude).vicaris'
    git -C "$repo" ls-files --others --exclude-standard -- . ':(exclude).vicaris'
  } 2>/dev/null | grep -v '^$' | sort -u
}

# Commits on the branch since the base.
vm_commits() {
  local repo="$1" base="${2:-}"
  [ -n "$base" ] && [ "$base" != - ] || base=$(vm_base "$repo")
  [ -n "$base" ] || { echo "?"; return; }
  git -C "$repo" rev-list --count "$base..HEAD" 2>/dev/null || echo "?"
}

# What a verify result is a result about: the content of the working tree, as the
# git tree hash it would have if every change, untracked files included, were
# committed. It is content only, so committing the verified tree (which finalize
# does) leaves it unchanged, and any edit to the code changes it. Computed through a
# scratch copy of the index, so the real index and staging are never touched.
vm_fingerprint() {
  local repo="$1" dir idx tree
  idx=$(git -C "$repo" rev-parse --path-format=absolute --git-path index 2>/dev/null) || return 1
  dir=$(mktemp -d "${TMPDIR:-/tmp}/vicaris-fp-XXXXXX") || return 1
  [ -f "$idx" ] && cp "$idx" "$dir/index"
  tree=$( export GIT_INDEX_FILE="$dir/index"
          { [ -f "$dir/index" ] || git -C "$repo" read-tree HEAD; } 2>/dev/null
          git -C "$repo" add -A -- . ':(exclude).vicaris' 2>/dev/null
          git -C "$repo" write-tree 2>/dev/null )
  rm -rf "$dir"
  [ -n "$tree" ] && printf '%s' "$tree"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  set -uo pipefail
  cmd="${1:-}"; shift || true
  case "$cmd" in
    list)        vm_list "${1:?manifest or repo}" "${2:-all}" ;;
    base)        vm_base "${1:?repo}"; echo ;;
    changed)     vm_changed "${1:?repo}" "${2:-}" ;;
    fingerprint) vm_fingerprint "${1:?repo}"; echo ;;
    *) echo "usage: vicaris-manifest.sh list|base|changed|fingerprint ..." >&2; exit 2 ;;
  esac
fi
