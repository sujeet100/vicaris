#!/usr/bin/env bash
#
# vicaris-wait.sh — wait for slow things without anyone holding a big context.
#
# A wait costs whatever context resumes after it. An agent idle past the five-minute
# prompt cache pays to rewrite its whole context on its next turn, and on one run the
# review lead did that three times at 260–290K tokens, the finalize lead twice at
# 200–250K. So waits belong to the orchestrator, the smallest context in the run, and
# happen here: one call that blocks, polls without printing, and returns one line per
# thing it waited for. Polling from a model re-reads the context to learn "still
# running"; this re-reads nothing.
#
# Usage:
#   vicaris-wait.sh start <out-file> -- <command...>
#       Run a command detached (it outlives this call and the Bash timeout), output
#       to <out-file>, exit code to <out-file>.exit. Returns at once.
#   vicaris-wait.sh files [--max S] <out-file>...
#   vicaris-wait.sh files [--max S] --manifest <manifest> --suffix <path-in-repo>
#       Wait until every started command has finished. With --manifest, the files
#       are <repo>/<path-in-repo> for each repo below.
#   vicaris-wait.sh pipeline [--max S] [--job REGEX] <repo>...
#   vicaris-wait.sh pipeline [--max S] [--job REGEX] --manifest <manifest>
#       Wait for each repo's latest GitLab pipeline on its current branch, or with
#       --job only the jobs whose name matches (an eval job, say). Needs glab, jq.
#       A failed job's log tail goes to <repo>/.vicaris/pipeline-<branch>.txt.
#
# --manifest means the `change` repos that published an MR (<repo>/.vicaris/mr-<branch>.txt
# exists): a repo the run left alone has no pipeline, and waiting on it would only
# ever time out. It also saves the caller a shell-specific array.
#
# --max defaults to 540s, under the ten-minute ceiling on one Bash call. Call again on
# exit 124; each call is one short tool result, not a poll's worth of output.
#
# Exit 0 all succeeded · 1 something failed (named) · 3 a matched job is manual and
# needs playing · 124 still running at --max · 2 misuse

set -uo pipefail

mode="${1:-}"; shift || true
max=540; every=30; job=""; manifest=""; suffix=""

if [ "$mode" = start ]; then
  out="${1:?usage: vicaris-wait.sh start <out-file> -- <command...>}"; shift
  [ "${1:-}" = "--" ] && shift
  [ $# -gt 0 ] || { echo "start: no command" >&2; exit 2; }
  mkdir -p "$(dirname "$out")"; rm -f "$out.exit"
  nohup bash -c '"$@" >"$0" 2>&1; echo $? >"$0.exit"' "$out" "$@" >/dev/null 2>&1 &
  echo "started $! → $out"
  exit 0
fi

while [ $# -gt 0 ]; do
  case "$1" in
    --max) max="$2"; shift 2;;
    --every) every="$2"; shift 2;;
    --job) job="$2"; shift 2;;
    --manifest) manifest="$2"; shift 2;;
    --suffix) suffix="$2"; shift 2;;
    --) shift; break;;
    *) break;;
  esac
done
if [ -n "$manifest" ]; then
  . "$(dirname "$0")/vicaris-manifest.sh"
  targets=()
  while IFS= read -r line; do
    repo="${line%%$'\t'*}"
    branch=$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null) || continue
    [ -s "$repo/.vicaris/mr-$branch.txt" ] || continue
    if [ "$mode" = files ]; then targets+=("$repo/$suffix"); else targets+=("$repo"); fi
  done < <(vm_list "$manifest" change)
  [ ${#targets[@]} -gt 0 ] || { echo "no change repo in $manifest has an MR yet" >&2; exit 2; }
  set -- "${targets[@]}"
fi
[ $# -gt 0 ] || { echo "usage: vicaris-wait.sh files|pipeline [--max S] <targets...>" >&2; exit 2; }
deadline=$(( $(date +%s) + max ))

case "$mode" in
  files)
    while :; do
      pending=0
      for f in "$@"; do [ -f "$f.exit" ] || pending=$((pending+1)); done
      [ "$pending" -eq 0 ] && break
      [ "$(date +%s)" -ge "$deadline" ] && { echo "still running: $pending of $# after ${max}s — call again"; exit 124; }
      sleep "$every"
    done
    failed=0
    for f in "$@"; do
      code=$(cat "$f.exit")
      if [ "$code" = 0 ]; then echo "done  $f"; else echo "FAIL  $f (exit $code)"; failed=1; fi
    done
    exit "$failed"
    ;;

  pipeline)
    command -v glab >/dev/null && command -v jq >/dev/null || { echo "pipeline mode needs glab and jq" >&2; exit 2; }
    # Per repo: the pipeline's status, or with --job the worst status of the jobs that
    # match. Collapsed to one word so the loop below has three outcomes to tell apart.
    state_of() {
      local repo="$1" branch json
      branch=$(git -C "$repo" rev-parse --abbrev-ref HEAD)
      json=$(cd "$repo" && glab ci get --branch "$branch" --output json 2>/dev/null) || { echo pending; return; }
      if [ -z "$job" ]; then
        printf '%s' "$json" | jq -r '.status // "pending"'
      else
        printf '%s' "$json" | jq -r --arg re "$job" '
          [(.jobs // [])[] | select(.name | test($re)) | .status] as $s
          | if ($s | length) == 0 then "pending"
            elif any($s[]; . == "failed" or . == "canceled") then "failed"
            elif any($s[]; . == "manual") then "manual"
            elif all($s[]; . == "success" or . == "skipped") then "success"
            else "running" end'
      fi
    }
    while :; do
      running=0; results=()
      for repo in "$@"; do
        s=$(state_of "$repo")
        case "$s" in success|failed|canceled|manual) ;; *) running=$((running+1));; esac
        results+=("$repo|$s")
      done
      [ "$running" -eq 0 ] && break
      [ "$(date +%s)" -ge "$deadline" ] && { echo "still running in $running of $# repo(s) after ${max}s — call again"; exit 124; }
      sleep "$every"
    done
    rc=0
    for r in "${results[@]}"; do
      repo="${r%%|*}"; s="${r#*|}"; name=$(basename "$repo")
      case "$s" in
        success) echo "pass    $name${job:+ ($job)}";;
        manual)  echo "MANUAL  $name: a job matching /$job/ has not been played"; [ "$rc" -eq 1 ] || rc=3;;
        *)
          branch=$(git -C "$repo" rev-parse --abbrev-ref HEAD)
          log="$repo/.vicaris/pipeline-$branch.txt"; mkdir -p "$(dirname "$log")"
          ( cd "$repo" && glab ci get --branch "$branch" --output json 2>/dev/null ) \
            | jq -r '(.jobs // [])[] | select(.status == "failed") | "\(.id)\t\(.name)"' \
            | while IFS=$'\t' read -r id jname; do
                printf '## %s (job %s)\n' "$jname" "$id"
                (cd "$repo" && glab ci trace "$id" 2>/dev/null | tail -n 80)
              done > "$log"
          echo "FAIL    $name: $s — failed jobs and log tails in $log"; rc=1;;
      esac
    done
    exit "$rc"
    ;;

  *) echo "usage: vicaris-wait.sh start|files|pipeline ..." >&2; exit 2;;
esac
