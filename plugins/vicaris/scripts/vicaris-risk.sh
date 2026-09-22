#!/usr/bin/env bash
#
# vicaris-risk.sh — observed risk class, from the paths a change actually touched.
#
# The understanding stage predicts a class from the story. This re-derives one from
# the diff, at the gate before review, and can only raise it. A story that reads
# small and turns out to touch a migration is the case a predicted class gets wrong
# and nobody notices; a false positive here costs one review pass, a false negative
# costs the review that would have caught it.
#
# Usage:  vicaris-risk.sh <manifest-or-repo> [predicted-class]
#         Prints:  RISK: <class> · tags: <...>
#                  why:  <trigger>
#         Exit 0  the prediction held
#         Exit 3  the class was RAISED — say so in the thread and run what it earns
#         Exit 4  could not observe (no base, or no changes) — prediction kept, and
#                 the caller must not read that as a clean result

set -uo pipefail

TARGET="${1:?usage: vicaris-risk.sh <manifest-or-repo> [predicted-class] [--write <risk-file>]}"
PREDICTED="${2:-normal}"
WRITE=""
[ "${3:-}" = "--write" ] && WRITE="${4:?--write needs a path}"

# --write makes the raise stick. Without it the new class lives only in this output,
# and every later stage reads the file — so a forgotten rewrite silently restores the
# ceremony the raise was meant to buy.

if [ -f "$TARGET" ]; then REPOS=$(cat "$TARGET"); else REPOS="$TARGET"; fi

changed=""
observed_repos=0
for repo in $REPOS; do
  [ -d "$repo" ] || continue
  base=$(git -C "$repo" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null \
    || git -C "$repo" remote show origin 2>/dev/null | sed -n 's|.*HEAD branch: |origin/|p')
  [ -n "$base" ] || base=$(git -C "$repo" rev-parse --abbrev-ref HEAD@{upstream} 2>/dev/null) || base=""
  [ -n "$base" ] || continue
  observed_repos=$((observed_repos + 1))
  changed+=$'\n'$(git -C "$repo" diff "$base"...HEAD --name-only 2>/dev/null)
  changed+=$'\n'$(git -C "$repo" diff --name-only 2>/dev/null)
done
changed=$(printf '%s\n' "$changed" | grep -v '^$' | sort -u)

# No resolvable base, or nothing changed anywhere, means the observation did not
# happen. Reporting `mechanical` from an absent diff would lower the class on
# missing data, which is the one direction this script must never move — so keep
# the prediction and say the check could not run. Exit 4 distinguishes that from
# a real result, because a caller must not read silence as reassurance.
if [ "$observed_repos" -eq 0 ] || [ -z "$changed" ]; then
  printf 'RISK: %s · tags: unknown\n' "$PREDICTED"
  if [ "$observed_repos" -eq 0 ]; then
    printf 'why: no upstream base resolved in any repo — observed class unavailable, prediction kept\n'
  else
    printf 'why: no changed files against the base — observed class unavailable, prediction kept\n'
  fi
  exit 4
fi

# Each pattern is a heuristic and is meant to over-trigger: raising the class costs
# one pass, missing the signal costs the pass that would have found the problem.
#
# They match path SEGMENTS, not substrings, and that boundary was learned the hard
# way: an unanchored `login` tagged `browser-login-helper.sh` as an authorisation
# change and pushed a documentation edit to `production`. Over-triggering is the
# right bias; firing on every file whose name happens to contain a keyword is not
# over-triggering, it is noise that trains you to ignore the signal.
tag_if() { printf '%s\n' "$changed" | grep -qiE "$1" && TAGS+=("$2"); }

TAGS=()
tag_if '(^|/)(migrations?|alembic|flyway|liquibase)/|\.sql$|(^|/)schema\.(rb|sql|prisma)$' schema
tag_if '(^|/)(auth|authz|authn|permissions?|polic(y|ies)|rbac|roles?|sessions?|tokens?|credentials?|tenants?|tenancy)([/._-]|$)' authz
tag_if '(payment|billing|invoice|pricing|price|charge|refund|currency|ledger|tax|money)'      money
tag_if '(^|/)(locks?|mutex|semaphores?|concurren[a-z]*|threadpool|celery|workers?|queues?)([/._-]|$)' concurrency
tag_if '(Dockerfile|docker-compose|\.tf$|\.tfvars$|(^|/)(k8s|helm|charts?|deploy|infra)/|\.github/workflows/)' infra
tag_if '(package(-lock)?\.json|pnpm-lock|yarn\.lock|pyproject\.toml|uv\.lock|poetry\.lock|requirements.*\.txt|go\.(mod|sum)|Cargo\.(toml|lock)|pom\.xml|build\.gradle)' dependency
tag_if '(openapi|swagger|\.proto$|schema\.graphql|(^|/)(api|contracts?)/)'                    public-contract
tag_if '(^|/)prompts?/|\.prompt\.md$'                                                         prompt

rank() { case "$1" in mechanical) echo 0;; tiny) echo 1;; normal) echo 2;; elevated) echo 3;; production) echo 4;; *) echo 2;; esac; }

# schema, authz and money can destroy data, widen access or move money. The rest
# raise to elevated: they are boundaries worth a design challenge, not emergencies.
observed=mechanical; why="no risk patterns in the changed paths"
for t in "${TAGS[@]:-}"; do
  case "$t" in
    schema|authz|money)                observed=production; why="changed paths match $t"; break;;
    concurrency|infra|dependency|public-contract|prompt)
      [ "$(rank "$observed")" -lt 3 ] && { observed=elevated; why="changed paths match $t"; };;
  esac
done

# Breadth is its own signal, independently of what was touched.
files=$(printf '%s\n' "$changed" | grep -c . || true)
repos=$(printf '%s\n' "$REPOS" | grep -c . || true)
if [ "$repos" -gt 1 ] && [ "$(rank "$observed")" -lt 3 ]; then
  observed=elevated; why="the change spans $repos repositories"
elif [ "$files" -gt 12 ] && [ "$(rank "$observed")" -lt 2 ]; then
  observed=normal; why="$files files changed"
fi

final="$PREDICTED"; raised=0
if [ "$(rank "$observed")" -gt "$(rank "$PREDICTED")" ]; then
  final="$observed"; raised=1
else
  why="predicted class kept; observed would have been $observed"
fi

line1="RISK: $final · tags: $( [ ${#TAGS[@]} -eq 0 ] && echo none || (IFS=,; echo "${TAGS[*]}") )"
printf '%s\n' "$line1"
printf 'why: %s\n' "$why"

if [ -n "$WRITE" ]; then
  mkdir -p "$(dirname "$WRITE")"
  printf '%s\nwhy: %s\n' "$line1" "$why" > "$WRITE"
  printf 'written: %s\n' "$WRITE"
fi

[ "$raised" -eq 1 ] && exit 3
exit 0
