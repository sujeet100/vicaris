#!/usr/bin/env bash
# PreCompact: make sure a current handover doc exists before context gets summarised.
#
# Why this hook exists. Vicaris used to ask the orchestrator to hand over at "~50%
# context", but the model cannot see its context-window usage: no hook fires on a
# window threshold and nothing reports live usage to it, so the rule failed silently
# on every long run. The harness, however, *can* see it — that is precisely what
# triggers auto-compaction. So this is the right place to hook: compaction is the
# system's own signal that context is nearly full.
#
# Compaction is lossy. The session survives, but a summariser decides what detail
# survives with it. A handover doc written deliberately is how the run keeps the
# reasoning it worked for.
#
# IMPORTANT — this hook is BEST EFFORT, not the guarantee.
#
# Whether exit code 2 actually blocks compaction on PreCompact is **undocumented**.
# PreCompact is not listed among the blockable hook events (those are PreToolUse,
# UserPromptSubmit, UserPromptExpansion, Stop, PreModelSwitch, WorktreeCreate), and
# two passes over the docs disagreed about it. So treat a block here as a bonus: if
# it works, the model is nudged while it still has context to write from; if it is
# ignored, nothing breaks and the reliable path still fires.
#
# The reliable path is session-start-resume.sh, which runs on the confirmed
# SessionStart "compact" matcher whose output *is* injected into the model's
# context. That one reports a missing or stale handover doc after compaction, and
# it is what this pair actually depends on.
#
# To settle the question, run `/compact` manually in a Vicaris worktree whose
# handover doc you have deleted, and see whether compaction proceeds.
#
# Behaviour: if a run is in progress (a .vicaris manifest, plan or handover exists
# for the current branch) and the handover doc is missing or stale, ask once via exit
# 2. Then get out of the way — a marker file makes any retry proceed, so this can
# never wedge a session. Everything else exits 0.
#
# Escape hatch: VICARIS_PRECOMPACT_OFF=1 skips it entirely.

set -uo pipefail   # deliberately not -e: this hook fails open, never breaks a session

[ "${VICARIS_PRECOMPACT_OFF:-0}" = "1" ] && exit 0

# shellcheck source=handover-stale.sh
source "$(dirname "${BASH_SOURCE[0]}")/handover-stale.sh" 2>/dev/null \
  || handover_is_stale() { return 1; }   # fail open

repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
branch=$(git -C "$repo_root" rev-parse --abbrev-ref HEAD 2>/dev/null) || exit 0
[ -z "$branch" ] || [ "$branch" = "HEAD" ] && exit 0

vicaris_dir="$repo_root/.vicaris"
[ -d "$vicaris_dir" ] || exit 0          # no Vicaris run here; nothing to guard

manifest="$vicaris_dir/repos-$branch.txt"
handover="$vicaris_dir/handover-$branch.md"

# Only guard an actual run: a manifest, a plan, or an existing handover for this branch.
if [ ! -f "$manifest" ] && [ ! -f "$vicaris_dir/understanding-$branch.md" ] && [ ! -f "$handover" ]; then
  exit 0
fi

# Block at most once per branch per compaction cycle.
marker="$vicaris_dir/.precompact-nudged-$branch"
if [ -f "$marker" ]; then
  rm -f "$marker"                          # consumed: let this compaction through
  exit 0
fi

needs_write=""
if [ ! -f "$handover" ]; then
  needs_write="no handover doc exists for this branch"
elif handover_is_stale "$handover" "$repo_root" "$manifest"; then
  needs_write="the handover doc predates the latest work on this branch"
fi

[ -z "$needs_write" ] && exit 0

: > "$marker" 2>/dev/null || true

cat >&2 <<EOF
Vicaris: context is about to be compacted and $needs_write.

Compaction keeps the session but not the detail — a summariser chooses what
survives. Write the handover doc NOW, while you still have the context to write
it from, then continue; this guard will not block again.

  $handover

Include: stage reached, the risk class, per-repo state from $manifest, what is done
and verified, the exact next action, decisions and assumptions already settled, which
fix pass each loop is on, open review findings, and the resume command. See the
handover skill.
EOF

exit 2
