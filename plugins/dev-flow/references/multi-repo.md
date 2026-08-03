# Multi-repo changes

This workspace is multi-repo and cross-repo changes are the norm, not the
exception: a single task routinely touches the agent service, the UI, and shared
libraries together. Every stage that acts on "the change" must act on **every
repo in scope**, because a stage that silently handles only the repo you started
in produces the worst possible outcome — a task that looks finished, reviewed and
green while half of it sits unreviewed on a `main` branch or has no MR at all.

## The repo set is an artifact, not a memory

The `plan` stage determines which repos the change touches and records them in
its **Repos in scope** section. Step 1b of the orchestrator then writes that list
to a manifest so that later stages, sub-agents, and resumed sessions all read the
same set rather than re-deriving it:

```
<primary-repo>/.dev-flow/repos-<branch>.txt
```

One absolute repo path per line, in **dependency order** — producers before
consumers, so a contract change lands before the code that consumes it. The
first line is the primary repo, which owns the scratch docs (plan, review,
handover, completion) and the manifest itself. `.dev-flow/` is scratch: never
commit it.

Reading the set, in any stage:

```bash
PRIMARY=$(git rev-parse --show-toplevel)
BRANCH=$(git rev-parse --abbrev-ref HEAD)
MANIFEST="$PRIMARY/.dev-flow/repos-$BRANCH.txt"
REPOS=$( [ -f "$MANIFEST" ] && cat "$MANIFEST" || echo "$PRIMARY" )
```

**No manifest means single-repo**, so standalone `/implement`, `/review` or
`/finalize` on an ordinary one-repo change stays frictionless — the fallback is
just the current repo. If you are running a stage standalone on a change you know
spans repos and no manifest exists, write one first.

## Per-repo invariants

Each repo in the set gets the identical treatment, resolved against **its own**
remote, since default branch names and remotes differ between repos:

```bash
git -C "$repo" fetch --prune origin
BASE=$(git -C "$repo" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null \
  || git -C "$repo" remote show origin | sed -n 's|.*HEAD branch: |origin/|p')
git -C "$repo" status --porcelain     # must be empty
```

- **Same branch name in every repo.** One task, one branch name, N repos — that
  is what makes the MR set recognisable as a single change, and it is what lets
  every stage recompute the manifest path and the diff without being told.
- **Uncommitted work in any repo is untouchable** — never stash, reset, commit,
  move, or pull over it, and never ask Sujit to clear it. Work in a **separate
  worktree** instead (below). It is not a blocker, and never a reason to ask what
  the scope should be.
- A repo that turns out not to need changes after all stays in the set with a
  note; drop it from the set only once you're sure, and say so in the plan.

## A dirty repo is not a blocked repo — use a worktree

This is the most common obstacle in this workspace and it has a standing answer,
so **never ask about it**. Sujit routinely has work in progress in a repo your
task also needs. A `git worktree` gives you a pristine checkout in a different
directory while his working tree, staged index and untracked files stay exactly as
he left them:

```bash
git -C "$repo" fetch --prune origin
git -C "$repo" worktree add -b "$BRANCH" "../$(basename "$repo")-$BRANCH" "$BASE"
```

Work there for the whole task — implement, verify, commit, push, MR — and use that
path in the manifest in place of the original, so every later stage follows you
there. Nothing is stashed, nothing is committed on his behalf, nothing waits on
him, and the full story scope still gets delivered. Note the worktree path in the
completion doc, and remove it at finalize once the MR is up
(`git -C "$repo" worktree remove <path>`) or leave it and say so if the branch
still needs work.

Per-checkout setup doesn't carry over, so a fresh worktree usually needs its
install step (`npm ci`, `uv sync`) plus any gitignored config (`.env`, local
certs) copied across. That's a few minutes of setup, not a reason to escalate.

**Only if a worktree genuinely won't work** — tooling that hard-codes the primary
checkout path, a build that can't run outside it — does the repo count as blocked.
Then deliver every *other* repo completely (implement, review, test, MR,
MR-review, exactly as if they were the whole change) and record the blocked one as
follow-on work, naming the blocker, in the completion doc, the shipped MRs'
descriptions, and the Slack wrap-up.

Either way, decide it yourself and keep moving. Do not ask which repos to include,
whether to split the delivery, or how to clear the way. Don't hold back a finished
repo's MR to keep the change "together" — a reviewable MR sitting unopened helps
nobody, and a partial delivery that is *declared* partial is honest work. Sujit
can always narrow it once he sees what landed; he cannot un-waste the hours a
blocking question costs.

## Fan-out rules per stage

| Stage | Must cover every repo |
|---|---|
| `plan` | Read code from all of them; name the set + freshness in the plan |
| Step 1b | Fetch, clean-check and branch each one off its own base |
| `implement` | Edit in dependency order; run each repo's own verify command |
| `adversarial-review` | Diff **every** repo; reviewers see the union, plus the cross-repo contract |
| `test` | Unit-verify each repo; exercise the integrated behaviour once, end-to-end |
| Fix passes | Apply findings in whichever repo they landed in, then re-verify that repo |
| `finalize` | One MR per repo, cross-linked; MR-review bot on every MR; fixes back through every repo |
| `handover` | Record every repo, its branch, and its state |

## Attribute everything to a repo

Whenever a stage reports a file, finding, test result or MR, prefix it with the
repo name (`service-api: src/foo.py:42`). Bare `file:line` across a multi-repo
change is ambiguous and sends fix passes into the wrong tree.

## The cross-repo contract is its own review surface

The failure mode unique to these changes is not inside any one diff, it is
*between* them: a field renamed in the producer but not the consumer, an endpoint
whose request shape moved, an enum extended on one side only, a migration that
has to land before the code that reads it. Each per-repo diff can be perfectly
clean while the change as a whole is broken. Review the seam explicitly, and
treat a mismatch as a blocker rather than a note.

## Deploy order and interim compatibility

Repos merge and deploy independently, so a cross-repo change is live in a broken
in-between state unless it is designed not to be. Prefer backward-compatible
producer changes (add before remove, tolerate both shapes for one release) so
the MRs can merge in any order. When that is impossible, state the required merge
order in the completion doc and in every MR description.
