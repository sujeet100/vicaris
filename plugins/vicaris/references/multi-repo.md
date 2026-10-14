# Multi-repo changes

Cross-repo changes are the norm here. Every stage that acts on "the change" must act
on **every repo the run changes**: a stage that silently covers only the repo you
started in leaves a change that looks finished while half of it has no review or no
MR. `scripts/vicaris-status.sh` enforces this, exiting non-zero on a repo with work
(commits or uncommitted changes) and no current verify result, and, with `--final`,
no MR.

## The repo set is an artifact, not a memory

`understand` names the repos in its **Repos in scope** section, and orchestrator
Step 1b writes them to a manifest that later stages, sub-agents and resumed sessions
all read:

```
<primary-repo>/.vicaris/repos-<branch>.txt
```

One repo per line, in **dependency order** (producers before consumers, the primary
first), as three tab-separated fields:

```
/abs/path/inventory-ingestion-service	origin/main	change
/abs/path/deployment	origin/us-qa	change
/abs/path/shared-schemas	origin/main	read
```

- **Base** is the branch this repo's MR targets, which is also the one to cut from
  and the one every diff is taken against. Defaults differ between repos and a
  deployment repo often targets an environment branch, so it is recorded per repo
  rather than resolved from `origin/HEAD`. Diffing a branch cut from `origin/us-qa`
  against `origin/main` shows every us-qa commit main lacks as part of this change;
  that is how a run once tagged another team's pricing and RBAC files as its own and
  classed itself `production`. Blank means the remote default.
- **Role** is `change` for a repo the run edits, and `read` for one it only reads for
  context (a schema it consumes, a neighbour whose behaviour it relies on). A `read`
  repo gets no branch, no design note, no review and no MR, does not count toward the
  risk class's breadth, and must end the run untouched.

A bare path on a line is still read as `<path>  <remote default>  change`.

`scripts/vicaris-manifest.sh` is the one reader. Scripts source it, and a stage
reading the set by hand uses it too, so nobody re-derives the base differently:

## Where a scratch doc lives: with the code it describes

Each working doc goes in the `.vicaris/` folder of the repo it is *about*: one repo's
code → that repo; the change as a whole → the primary.

| Doc | Lives in |
|---|---|
| Design + simplification notes | **that repo** — `<repo>/.vicaris/design-notes-<branch>.md` |
| Verify output worth keeping | **that repo** — `<repo>/.vicaris/verify-<branch>.txt` |
| The manifest | primary — `<primary>/.vicaris/repos-<branch>.txt` |
| The Slack thread `ts` | primary — `<primary>/.vicaris/slack-thread-<branch>.txt` |
| The design challenge | primary — `<primary>/.vicaris/design-challenge-<branch>.md` |
| The risk class | primary — `<primary>/.vicaris/risk-<branch>.txt` |
| The fix ledger | primary — `<primary>/.vicaris/fix-ledger-<branch>.md` |
| The MR url, once raised | **that repo** — `<repo>/.vicaris/mr-<branch>.txt` |
| Understanding, review report, handover, completion doc | primary, one per change |

**`.vicaris/` is scratch and is never committed, in any repo.** Don't add it to a
tracked `.gitignore` (that is the team's file). Exclude it locally the first time you
write into a repo, so `git status` stays clean and the clean-tree check still means
something. `--git-common-dir` resolves to the git directory a repo shares with its
worktrees, so one exclude covers both; it can be relative, hence the guard:

```bash
GITDIR=$(git -C "$repo" rev-parse --git-common-dir)
case "$GITDIR" in /*) ;; *) GITDIR="$repo/$GITDIR" ;; esac
grep -qxF '.vicaris/' "$GITDIR/info/exclude" 2>/dev/null \
  || echo '.vicaris/' >> "$GITDIR/info/exclude"
```

Reading the set, in any stage:

```bash
PRIMARY=$(git rev-parse --show-toplevel)
BRANCH=$(git rev-parse --abbrev-ref HEAD)
MANIFEST="$PRIMARY/.vicaris/repos-$BRANCH.txt"
VM="${CLAUDE_PLUGIN_ROOT}/scripts/vicaris-manifest.sh"
bash "$VM" list "$MANIFEST" change     # path TAB base TAB role, change repos only
bash "$VM" changed "$repo"             # every changed path, committed or not
```

"Changed" means against the merge-base with the repo's base: the branch's commits,
plus anything staged, unstaged or untracked, so a stage that stopped before its
commit is still seen.

**No manifest means single-repo** — the set is just the current repo. Running a stage
standalone on a change you know spans repos, write the manifest first.

## Commits: local, at every stage boundary, pushed at finalize

Each stage that changes code commits it in each repo it changed, on the run branch,
when its gate is green: the build once per repo, each fix pass once per repo. Nothing
is pushed before finalize publishes the MRs. The commit is the stage's handoff, so a
diff of the change is `base...HEAD`, what a fix pass did is its own commit, and a
resumed session finds the work in the history rather than in a working tree that
nothing protects.

```bash
git -C "$repo" add -A                    # .vicaris/ is excluded locally
git -C "$repo" commit -m "$KEY <what this stage did, in the repo's commit style>"
```

- **Through the pre-commit hooks, never `--no-verify`.** Where a hook re-runs what the
  gate just ran, that is wall-clock, not tokens. A hook that rewrites files (a
  formatter) leaves them unstaged: stage, commit again, and re-run the gate, since
  the tree moved.
- **One commit per stage per repo**, message in the repo's own style with the Jira
  key. Finalize keeps them: the MR then shows the build and each fix pass apart,
  which is what lets the MR review's decider see which findings sit in fix-pass code.
  A project that wants one commit squashes on merge.
- **Never amend or rebase a pushed commit.** After finalize publishes, a fix is a new
  commit on top.
- **The owner's work is still untouchable.** This commits the run's branch in the
  run's checkout (a worktree when the repo was dirty), never the owner's work.
- The verify fingerprint is the tree's content, so committing the verified tree
  leaves the gate's result current.

## Per-repo invariants

Each repo is resolved against **its own** remote and its manifest base:

```bash
git -C "$repo" fetch --prune origin
BASE=$(bash "$VM" base "$repo")
git -C "$repo" status --porcelain     # must be empty before branching
```

- **Same branch name in every repo.** It makes the MR set recognisable as one change
  and lets every stage recompute the manifest path and diff.
- **Uncommitted work in any repo is untouchable** — never stash, reset, commit,
  move, or pull over it, and never ask the owner to clear it. Work in a **separate
  worktree** instead (below). It is not a blocker, and never a scope question.
- A `change` repo that turns out not to need changes stays in the set with a note;
  drop it only once you're sure, and say so. A `read` repo that turns out to need an
  edit is changed to `change` in the manifest, branched, and given a design note
  before the edit, and the risk check re-run, since breadth just grew.

## A dirty repo is not a blocked repo — use a worktree

This has a standing answer, so **never ask about it**. A `git worktree` gives you a
pristine checkout elsewhere while the owner's working tree, index and untracked files
stay exactly as they left them:

```bash
git -C "$repo" fetch --prune origin
git -C "$repo" worktree add -b "$BRANCH" "../$(basename "$repo")-$BRANCH" "$BASE"
```

Work there for the whole task — implement, verify, commit, push, MR — and put that
path in the manifest in place of the original. Note the worktree path in the
completion doc, and remove it at finalize once the MR is up
(`git -C "$repo" worktree remove <path>`) or leave it and say so if the branch still
needs work.

A fresh worktree usually needs its install step (`npm ci`, `uv sync`) and any
gitignored config (`.env`, local certs) copied across. That is setup, not a reason to
escalate.

**Only if a worktree genuinely won't work** — tooling that hard-codes the primary
checkout path, a build that can't run outside it — is the repo blocked. Then deliver
every *other* repo completely (implement, review, test, MR, MR-review) and record the
blocked one as follow-on, naming the blocker, in the completion doc, the shipped MRs'
descriptions and the Slack wrap-up.

Don't hold back a finished repo's MR to keep the change "together"; a partial
delivery that is *declared* partial is honest work.

## Fan-out rules per stage

| Stage | Must cover every repo |
|---|---|
| `understand` | Read code from all of them; name the set with each repo's role and target branch, and set the risk class |
| Step 1b | Fetch every repo; clean-check and branch each `change` repo off its manifest base |
| `implement` | A design note for **every** repo before the first edit in any; then one builder per repo, in dependency order, each running its repo's verify through `vicaris-gate.sh` and committing |
| The gate | `vicaris-gate.sh` per repo, then `vicaris-risk.sh` over the set |
| `design-challenge` | One blind design over the **whole** change and every repo's base; amends the notes it changes |
| `adversarial-review` | Diff **every** repo; reviewers see the union, plus the cross-repo contract |
| `test` | Unit-verify each repo; exercise the integrated behaviour once, end-to-end |
| Fix passes | Apply findings in whichever repo they landed in, re-verify that repo, and commit there |
| `finalize` | One MR per repo, cross-linked; MR-review bot on every MR; fixes back through every repo |
| `handover` | Record every repo, its branch, and its state |

The table means every `change` repo; `read` repos are inputs to understand, design
and review, and nothing else. Run `scripts/vicaris-status.sh` before any stage claims
to be done.

## Attribute everything to a repo

Prefix every reported file, finding, test result or MR with the repo name
(`service-api: src/foo.py:42`). Bare `file:line` sends fix passes into the wrong tree.

## The cross-repo contract is its own review surface

The failure unique to these changes sits *between* the diffs: a field renamed in the
producer but not the consumer, a request shape that moved, an enum extended on one
side, a migration that must land before the code that reads it. Review the seam
explicitly and treat a mismatch as a blocker.

## Deploy order and interim compatibility

Repos merge and deploy independently. Prefer backward-compatible producer changes
(add before remove, tolerate both shapes for one release) so the MRs can merge in any
order. When that is impossible, state the required merge order in the completion doc
and every MR description.
