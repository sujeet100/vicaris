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
# Usage:  vicaris-risk.sh <manifest-or-repo> [predicted-class] [--write <risk-file>]
#         Prints:  RISK: <class> · tags: <predicted and observed, together>
#                  why:  <trigger>
#                  observed: <class> · tags: <...>   (what the paths alone said)
#         Exit 0  the prediction held
#         Exit 3  the class was RAISED — say so in the thread and run what it earns
#         Exit 4  could not observe (no base, or no changes) — prediction kept, and
#                 the caller must not read that as a clean result
#
# Reads the manifest's per-repo base and looks only at repos whose role is change.

set -uo pipefail

TARGET="${1:?usage: vicaris-risk.sh <manifest-or-repo> [predicted-class] [--write <risk-file>]}"
PREDICTED="${2:-normal}"
WRITE=""
[ "${3:-}" = "--write" ] && WRITE="${4:?--write needs a path}"

# --write makes the raise stick. Without it the new class lives only in this output,
# and every later stage reads the file — so a forgotten rewrite silently restores the
# ceremony the raise was meant to buy. It also reads that file first, because the
# understand stage wrote its prediction there: tags it saw in the story (a public
# contract nobody's path names) are evidence too, and an observation that overwrote
# them would be the script lowering what it knows.

. "$(dirname "$0")/vicaris-manifest.sh"

pred_tags=""; pred_why=""
if [ -n "$WRITE" ] && [ -f "$WRITE" ]; then
  pred_tags=$(sed -n '1s/.*tags: //p' "$WRITE" | tr ',' '\n' | tr -d ' ' | grep -vxE 'none|unknown' | grep -v '^$' || true)
  pred_why=$(sed -n '2s/^why: //p' "$WRITE")
fi

# Only repos the run edits. A read-only repo is context, and counting it would
# raise every story that reads a neighbour to elevated for breadth it does not have.
changed=""
observed_repos=0
changed_repos=0
while IFS=$'\t' read -r repo base role; do
  [ -d "$repo" ] && [ "$base" != - ] || continue
  files=$(vm_changed "$repo" "$base") || continue
  observed_repos=$((observed_repos + 1))
  [ -n "$files" ] && { changed_repos=$((changed_repos + 1)); changed+=$'\n'"$files"; }
done < <(vm_list "$TARGET" change)
changed=$(printf '%s\n' "$changed" | grep -v '^$' | sort -u)

# No resolvable base, or nothing changed anywhere, means the observation did not
# happen. Reporting `mechanical` from an absent diff would lower the class on
# missing data, which is the one direction this script must never move — so keep
# the prediction and say the check could not run. Exit 4 distinguishes that from
# a real result, because a caller must not read silence as reassurance.
if [ "$observed_repos" -eq 0 ] || [ -z "$changed" ]; then
  printf 'RISK: %s · tags: %s\n' "$PREDICTED" "$(printf '%s\n' "$pred_tags" | grep -v '^$' | paste -sd, - | sed 's/^$/unknown/')"
  if [ "$observed_repos" -eq 0 ]; then
    printf 'why: no base resolved in any repo the run changes — observed class unavailable, prediction kept\n'
  else
    printf 'why: no changed files against the base, uncommitted work included — observed class unavailable, prediction kept\n'
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
# money is two patterns: a lower-case segment (pricing/, refund_job.py, tax-rules.yaml)
# and a CamelCase word (PricingService.kt). Unanchored, it tagged taxonomy, syntax and
# every file with "price" in a variable name as money and sent the change to production.
tag_if '(^|[/._-])(payments?|billing|invoices?|pricing|prices?|charges?|refunds?|currenc(y|ies)|ledgers?|tax(es)?|money)([/._-]|$)' money
printf '%s\n' "$changed" | grep -qE '(^|[/._a-z-])(Payment|Billing|Invoice|Pricing|Price|Charge|Refund|Currenc|Ledger|Tax|Money)[A-Zsy./_-]' \
  && { [[ " ${TAGS[*]:-} " == *" money "* ]] || TAGS+=(money); }
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

# Breadth is its own signal, independently of what was touched. It counts repos
# with changes, not repos in the manifest: a repo listed for reading adds no risk.
files=$(printf '%s\n' "$changed" | grep -c . || true)
if [ "$changed_repos" -gt 1 ] && [ "$(rank "$observed")" -lt 3 ]; then
  observed=elevated; why="the change spans $changed_repos repositories"
elif [ "$files" -gt 12 ] && [ "$(rank "$observed")" -lt 2 ]; then
  observed=normal; why="$files files changed"
fi
obs_tags=$( [ ${#TAGS[@]} -eq 0 ] && echo none || (IFS=,; echo "${TAGS[*]}") )

# The class only ever rises, and the tags are the union: the prediction's tags stay
# because the story can name a risk no path does, and the observed ones join them.
final="$PREDICTED"; raised=0
if [ "$(rank "$observed")" -gt "$(rank "$PREDICTED")" ]; then
  final="$observed"; raised=1
else
  why="${pred_why:-predicted class kept}"
fi
all_tags=$( { printf '%s\n' "$pred_tags"; [ ${#TAGS[@]} -eq 0 ] || printf '%s\n' "${TAGS[@]}"; } \
  | grep -v '^$' | awk '!seen[$0]++' | paste -sd, - )

line1="RISK: $final · tags: ${all_tags:-none}"
line3="observed: $observed · tags: $obs_tags · $files file(s) in $changed_repos repo(s), uncommitted work included"
printf '%s\nwhy: %s\n%s\n' "$line1" "$why" "$line3"

if [ -n "$WRITE" ]; then
  mkdir -p "$(dirname "$WRITE")"
  printf '%s\nwhy: %s\n%s\n' "$line1" "$why" "$line3" > "$WRITE"
  printf 'written: %s\n' "$WRITE"
fi

[ "$raised" -eq 1 ] && exit 3
exit 0
