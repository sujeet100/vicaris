---
name: dev-flow
description: Run the full autonomous dev workflow end to end — plan, implement, parallel adversarial review, browser test, then finalize — grounded in Sujit's coding principles. Drives the task to completion without manual intervention, pinging Slack only on genuine external blockers.
argument-hint: [Jira key, task description, or feature brief]
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Agent, Skill, mcp__claude_ai_Slack__slack_send_message, mcp__claude_ai_Atlassian__getJiraIssue, mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql, mcp__claude_ai_Atlassian__getJiraIssueRemoteIssueLinks, mcp__claude_ai_Atlassian__getConfluencePage, mcp__claude_ai_Atlassian__searchConfluenceUsingCql, mcp__claude_ai_Atlassian__getPagesInConfluenceSpace, mcp__claude_ai_Atlassian__getConfluencePageDescendants, mcp__claude_ai_Atlassian__getConfluenceSpaces, mcp__claude_ai_Atlassian__addCommentToJiraIssue, mcp__claude_ai_Atlassian__createConfluencePage, mcp__claude_ai_Atlassian__updateConfluencePage
---

# dev-flow (orchestrator)

Take `$ARGUMENTS` from intake to a reviewed, tested, finalized change **without
manual intervention**. The individual stages (`plan`, `implement`,
`adversarial-review`, `test`, `handover`, `finalize`) also run standalone; this
skill sequences them.

## The autonomy contract

Read `${CLAUDE_PLUGIN_ROOT}/references/autonomy.md` in full before Step 0. It holds
the contract and the standing resolutions for the forks that come up most runs, and
it is the same file every other stage reads, so a fork answered there is answered
identically everywhere.

Three lines from it govern this skill specifically, and they are the ones a long run
drifts from:

- **Never ask a blocking question.** Not `AskUserQuestion`, not an interactive
  prompt, not a turn that ends in a question with no work done. The only channel is
  an asynchronous Slack DM you send and keep working past.
- **Deliver the whole scope of the story, every repo it touches.** If part is
  genuinely blocked, ship everything else in full and record the remainder as
  follow-on. Reducing scope is Sujit's call after seeing what landed.
- **Only genuine external blockers reach him, and even then don't hard-stop.** The
  list is closed and his uncommitted work is not on it, because a worktree handles
  that.

## Step 0 — Session setup

1. Load the standard: read `${CLAUDE_PLUGIN_ROOT}/references/coding-principles.md`,
   `${CLAUDE_PLUGIN_ROOT}/references/risk-classes.md` (what ceremony this change
   earns — every stage below branches on it),
   `${CLAUDE_PLUGIN_ROOT}/references/gates.md` (what must be green before a
   reviewer is spawned, and where the fix loops stop),
   `${CLAUDE_PLUGIN_ROOT}/references/multi-repo.md` (cross-repo changes are the
   norm here), `${CLAUDE_PLUGIN_ROOT}/references/notifications.md` (when to ping
   Slack — an unattended run must stay visible) and
   `${CLAUDE_PLUGIN_ROOT}/references/project-context.md` (skip the sidecar
   silently if absent).
2. **Keep the machine awake** so sleep can't stall a long run. Start a capped
   keep-awake in the background and remember it for finalize:
   ```bash
   nohup caffeinate -dimsu -t 21600 >/dev/null 2>&1 &   # 6h safety cap
   echo $! > "$PRIMARY/.dev-flow/caffeinate-$BRANCH.pid"
   ```
   **Record the PID**, because finalize must kill *this* process and not every
   `caffeinate` on the machine. If Sujit launched the whole session under
   `caffeinate -dimsu claude`, a pattern kill matches that too — and killing it
   takes the session down with it, which is a long unattended run ending three
   minutes before it would have finished.
3. Confirm the repo: `git rev-parse --show-toplevel`.
4. **Start from current code.** Fetch, then branch off the *remote* default
   branch — never off whatever local HEAD happens to be:
   ```bash
   git fetch --prune origin
   BASE=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null \
     || git remote show origin | sed -n 's|.*HEAD branch: |origin/|p')
   git status --porcelain          # must be empty
   ```
   - **Dirty tree → work in a worktree.** Uncommitted work is Sujit's: never
     stash, reset, commit, move, or pull over it, and never ask him to clear it.
     Instead take a pristine checkout beside it and work there, which leaves his
     tree and index untouched and still delivers the full scope:
     ```bash
     git -C "$repo" worktree add -b "$BRANCH" \
       "../$(basename "$repo")-$BRANCH" "$BASE"
     ```
     Put that path in the manifest in place of the original, expect to redo the
     install step there, and see `references/multi-repo.md` for the details and
     the narrow fallback if a worktree truly can't work. This is a standing
     resolution — never a question.
   - Clean tree, new task: `git switch -c "$BRANCH" "$BASE"`. **Put the Jira key
     first in the branch name** (`PROJ-1234-short-slug`) — `adversarial-review`
     recovers the key from the branch to fetch the ACs, and a branch without it
     silently costs you the PO review. No key (ad-hoc brief): use a plain slug
     and pass the key/brief to that stage explicitly.
   - Resuming an existing task branch (handover, re-run): report how far behind
     `$BASE` it is. Rebase only if it goes through cleanly
     (`git rebase "$BASE"`); on conflict, `git rebase --abort`, continue on the
     branch as-is, and record the staleness for the completion doc.
   - Never work on the default branch directly.
5. **Every repo the task touches gets the same treatment.** In this multi-repo
   workspace, fetch and freshness-check each one before planning — a stale
   sibling repo is invisible until the design is already wrong. You can only
   branch the repo you start in this early; the rest wait for Step 1b, which is
   where the set first exists.
6. **Probe the capabilities this run depends on, and say what is missing.**
   Every one of them fails into silence rather than an error, which is the worst
   shape a dependency can have in an unattended run: a missing Slack tool looks
   exactly like a run that chose not to ping, and a missing browser tool looks
   like a change that did not need testing. So check, once, and record it:

   - the **Slack** send tool resolves — without it the run is invisible for its
     whole length, and that is worth saying in the terminal at the start rather
     than discovering at the wrap-up;
   - the **Atlassian** issue tool resolves, if `$ARGUMENTS` is a ticket key;
   - a **browser** tool resolves, if the change is likely user-visible;
   - `bash "${CLAUDE_PLUGIN_ROOT}/scripts/mr-review-root.sh"` prints a path —
     without it, review depth and the design challenge both fall back.

   Write what is missing into `<primary>/.dev-flow/degraded-<branch>.txt`, one
   line each, and carry every line into the completion doc. A run that could not
   ping, could not read the story, or reviewed without the charter is still a
   useful run; one that did those things silently is not.
7. **Effort:** run every stage at high reasoning effort.

## Step 1 — Understand (model: fable)

Delegate to a **fable** sub-agent (Agent tool, `model: fable`) running the
`understand` skill's method on `$ARGUMENTS`. Reading a story closely is exactly
the work the planning model is cheap and fast at; implementation and review are
not.

It returns, and writes to `<primary>/.dev-flow/understanding-<branch>.md`: the
acceptance criteria with the reading rejected for each ambiguous one, the
contradictions and gaps in the story, the non-functional constraints, the repos
in scope with the contract between them, and the test surface derived from the
criteria rather than from a design.

It also writes `<primary>/.dev-flow/risk-<branch>.txt`. **Read that file before
Step 2 and hold the class for the rest of the run** — it decides whether the
design note is written, whether the design challenge runs, which review passes
are bought, and whether the browser leg happens
(`${CLAUDE_PLUGIN_ROOT}/references/risk-classes.md`). If the file is missing, the
stage did not finish its job: classify it yourself from that reference and write
the file rather than proceeding unclassified, because every gate below reads it
and an absent class silently means "do everything".

Note what this stage no longer produces. There is no file-by-file change set: it
was stale by the second slice and it locked the implementation before the shape
had been designed. The shape is decided in `implement` Step 2b and challenged in
`design-challenge`.

### Step 1b — Pin the repo set and branch it

The understanding's **Repos in scope** section is the first point at which you
know the full set. Write it to the manifest that every later stage reads
(`references/multi-repo.md`), in dependency order, primary repo first:

```bash
mkdir -p "$PRIMARY/.dev-flow"
printf '%s\n' /path/to/producer-repo /path/to/consumer-repo \
  > "$PRIMARY/.dev-flow/repos-$BRANCH.txt"
```

Then apply Step 0.4 to every repo in it you haven't branched yet: fetch, require
a clean tree, `git switch -c "$BRANCH" "$BASE"` off **that repo's own** remote
default. A sibling repo left on its default branch is the failure this catches —
implementation would otherwise commit straight to its `main`.

While you are walking the set, exclude `.dev-flow/` locally in each repo. Every
repo gets its own scratch folder now — `implement` leaves that repo's design and
simplification notes beside its code — and an excluded folder can't ride along in a
commit or clutter the clean-tree check the next stage runs:

```bash
while read -r repo; do
  GITDIR=$(git -C "$repo" rev-parse --git-common-dir)   # a worktree's .git is a file
  case "$GITDIR" in /*) ;; *) GITDIR="$repo/$GITDIR" ;; esac
  grep -qxF '.dev-flow/' "$GITDIR/info/exclude" 2>/dev/null \
    || echo '.dev-flow/' >> "$GITDIR/info/exclude"
done < "$PRIMARY/.dev-flow/repos-$BRANCH.txt"
```

This goes in `.git/info/exclude`, never in the repo's tracked `.gitignore` — that
file is the team's, and nothing outside this workflow creates the folder.

From here on, **every stage fans out over the manifest**: implement, review,
test, fix passes, MRs and MR-review all cover all of it. Half-covered is worse
than not started, because the run reports done.

### Step 1c — Open the Slack thread

Post the run's parent Slack message now and persist its `ts` so every later ping
threads under it. It carries the ticket, the one-line goal, the repos, the branch
and the risk class — and then the part that makes it worth reading: **the two to
four acceptance criteria whose reading could be wrong, each with the reading you
took**, closing with "proceeding on this reading."

Nothing about that blocks. You send it and keep working, exactly as with every
other ping. But it is the only point in the run where a human can correct a
misunderstanding while correcting it is still free, and a misread criterion that
first surfaces in the completion doc has by then cost the whole implementation.
Skip the assumptions block only when the story left nothing open.

```bash
echo "<ts>" > "$PRIMARY/.dev-flow/slack-thread-$BRANCH.txt"
```

Then ping at each stage boundary per `references/notifications.md`. Sujit is not
watching the terminal, so a stage that finishes silently is indistinguishable from
a stage that hung. Send and move on; never wait for a reply.

## Step 2 — Implement (model: opus, auto mode)

Implement the change yourself on **opus** at high effort, in **auto mode**,
following the `implement` skill: clean, small, typed, declarative, domain-
modelled, concise-but-sufficient tests, zero warnings, fast verify. Do not run
eval / integration suites to verify. Respect pre-commit gates.

Three gates inside that stage are the ones most easily skipped under time pressure,
and **the risk class decides which of them this change earns** — `mechanical` and
`tiny` changes skip the design note and the challenge outright, and forcing a
pattern-repeating field addition through a design contest invents an alternative
for the occasion. A **design note** for every repo before the first edit in any of
them, at `normal` and above, because the plan settles the approach while the shape is chosen at the
keyboard; the **design challenge** on top of it, because a design note is written by
the pass that already chose and cannot catch a wrong approach on its own; and a
**simplification pass** once each repo is green, because a mechanical smell removed
by its author costs nothing and the same smell costs an opus reviewer plus a fix
loop. Where a repo ships its own `design-change` or `simplify-implementation` skill,
that one wins — it cites the repo's numbered conventions. The notes land in **that
repo's** `.dev-flow/design-notes-<branch>.md`, beside the code they describe, and
finalize reads all of them.

The challenge runs at `elevated` and `production` only. It is the one stage that
can catch the change being built on the wrong decision, so it runs **before the
first edit**, where a divergence costs a paragraph
rather than a rework. It spends two agents — one fable designing from the acceptance
criteria alone, blind to the plan and the notes, and one opus holding the two designs
together — and it decides its own gate, so an ordinary bug fix skips it with a reason
rather than inventing an alternative for the occasion. Read the design notes again
after it returns: it amends them in place where a divergence is adopted.

Work the manifest **in dependency order** — producer repo before consumer — and
run each repo's own verify before moving on, so a broken contract surfaces at the
seam rather than three repos later.

Ping the thread when the challenge settles something worth knowing — the decision,
the alternative that lost, and what it would have cost — and again when
implementation is done: per repo, what changed in a phrase and the verify result. **Then refresh the handover doc** (Context discipline,
below) — implement is the stage whose state is most expensive to reconstruct.

## Step 2d — The gate, before anything expensive

Nothing costly starts until the cheap deterministic checks are green
(`${CLAUDE_PLUGIN_ROOT}/references/gates.md`). On a cross-repo change the review
is three opus passes per repo plus an acceptance-criteria pass, and spending them
on code that does not compile buys you an expensive way to be told what a build
would have said in ninety seconds.

```bash
# 1. every repo's own verify, recorded where every later stage reads it
bash "${CLAUDE_PLUGIN_ROOT}/scripts/dev-flow-gate.sh" "$repo" "$VERIFY_CMD"

# 2. the class, re-derived from the paths actually touched — it can only go up,
#    and --write makes the raise stick rather than leaving it for you to remember
bash "${CLAUDE_PLUGIN_ROOT}/scripts/dev-flow-risk.sh" \
  "$PRIMARY/.dev-flow/repos-$BRANCH.txt" "$PREDICTED_CLASS" \
  --write "$PRIMARY/.dev-flow/risk-$BRANCH.txt"
```

Exit 3 from the risk script means the prediction was wrong and the class has
**risen**. The file is already updated; say so in the Slack thread, and run what
the new class earns — including the design challenge, late and out of order,
because a change that turned out to touch a migration is exactly the one that
needed it. Exit 4 means it could not observe anything; that is not a clean result,
so keep the predicted class and say the check did not run.

**Where the class is `production` and the tags include `schema`, rehearse the
migration before anything else in this gate.** Apply it against a scratch database
per the sidecar, then apply its down step, then apply it again — a migration that
cannot be reversed and re-applied is a one-way door, and finding that out here
costs minutes where finding it out in production costs an incident. If the sidecar
names no migration command, say so in `degraded-<branch>.txt`, record the rehearsal
as **not run** in the completion doc and in the MR description, and treat the
reversibility claim in the understanding as unverified rather than true. Do not
quietly skip it: an unrehearsed migration that nobody flagged is exactly what this
class exists for.

Then the **integrated smoke**, where the class calls for it: the stack up on each
repo's *branch* build, one happy path end to end. Not the browser pass, which
stays in Step 4 — one path, to prove the seam exists, because each repo's green
unit suite is exactly what cannot see it.

A gate failure is not a blocker in the escalation sense. Fix it, re-run the gate,
carry on; no reviewer has been spawned, so nothing is wasted.

## Step 3 — Adversarial review

Run the `adversarial-review` skill, which reads the risk class and buys the passes
that class earns rather than a fixed set
(`${CLAUDE_PLUGIN_ROOT}/references/risk-classes.md`). At `mechanical` that is a
parity check and no craft pass at all — a field threaded through an existing
pattern fails by being incomplete, not by being ugly, and three opus passes report
that it is fine while missing the fourth consumer. At `normal` the mapper's own
signals decide architect and integration. At `elevated` and above both are forced
on. Across every class it runs `--also-repo` for each sibling, so the contract
between repos is reviewed against its real callers, and adds one
acceptance-criteria pass over the whole change.

**Findings are decided, not applied**, and the fix loop is capped at **two
passes** — both per `references/gates.md`, both recorded in
`<primary>/.dev-flow/fix-ledger-<branch>.md`. At the cap, record what is
outstanding, carry it into the completion doc and every affected MR description,
ping the thread, and move on. A review still multiplying findings after two passes
is repairing a design, and a third round of patches will not settle what a design
decision has to.

Ping the thread when the review lands (counts by severity, plus the headline of
anything non-trivial), and again at the cap. Refresh the handover doc before the
second fix pass, recording the findings still outstanding.

## Step 4 — Test

Run the `test` skill. The unit suites already ran at the gate, so it reads each
repo's `verify-<branch>.txt` rather than re-running them, and only re-runs where
the tree has moved since. What it adds is what a unit suite cannot reach: real
browser testing of any user-visible change (SSO-aware, no secret through your
context), plus logs and traces.

The browser leg is risk-gated. `mechanical` skips it; `tiny` and `normal` earn it
when the change is user-visible; `elevated` and `production` always, because a
cross-repo change is only proven by exercising the integrated path and green units
on both sides are exactly what cannot see the seam.

Post the Slack results summary. Fix and re-test what failed, **capped at two
passes** like every other loop, with the outcomes in the ledger. If blocked on
SSO, Slack Sujit and continue with the rest. Refresh the handover doc when the
stage closes and before the second fix pass — a long verification loop is where
runs overrun, and its reasoning is the first thing a compaction flattens.

## Step 5 — Finalize

Run the `finalize` skill: write the completion doc (summary of changes;
assumptions with alternatives and reasons; testing notes — what worked, what
didn't), then **one MR per repo in the manifest**, cross-linked to each other and
carrying the same Jira key, announced together in the team channel. Run the
standalone MR reviewer **on every MR** and fold each one's findings back into its
own repo, then post the Slack wrap-up and stop the `caffeinate` you started.

The MR-review fix loop is capped at two passes like the others, and a finding the
local review already parked does not come back: answer it with the ledger line
that parked it rather than relitigating it because a second reviewer raised it.

The task is not done while any repo in the manifest lacks an MR or an MR review,
and that is checkable rather than remembered:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/dev-flow-status.sh"
```

It prints the risk class and one row per repo — commits, verify result, MR — and
exits non-zero on a repo with work that has no verify result or no MR. Run it
before the wrap-up and paste nothing; just fix what it names. A stage that quietly
did one repo is this workflow's defining failure, and this is the one mechanism in
the run that can actually fail because of it.

Refresh the handover doc one last time before the wrap-up, so the open items and
follow-ons outlive the session even though the run itself is over.

## Context discipline — write the handover, don't predict the budget

**Refresh the handover doc at every stage boundary, unconditionally.** After plan,
after implement, after review, after test, after finalize: run the `handover`
skill's *write* step (not its hand-off step) so
`<primary>/.dev-flow/handover-<branch>.md` is always current. It costs a couple of
minutes against state you already hold, and it is what makes losing context a
non-event.

Do **not** try to judge your remaining context as a percentage. You cannot see it.
The figure in your context is a budget total that barely moves across a long run,
while the context *window* fills independently; there is no hook that fires on a
window threshold and no mechanism that reports live usage to you. A rule keyed to
that number fails silently, which is exactly what it did before this was written.

Two things to know about what actually happens. Auto-compaction is automatic and
needs nobody: the harness summarises and the session continues, so a run does not
die of context exhaustion. But compaction is **lossy** — a summariser keeps what it
judges important, and the hard-won detail of a long run (why a number moved, which
findings you declined and why) is exactly what gets flattened. The handover doc is
how you choose what survives.

**Observable tripwires**, since you can count these even though you cannot measure
context. Any of them means refresh the handover doc now and say so in the Slack
thread, because the run has exceeded its expected shape:

- the review fix loop reaches a third pass
- a verification loop (evals, CI, browser) reaches a third iteration
- more than about six sub-agents have run (the design challenge spends two of
  them, so an `elevated` change reaches this sooner and legitimately)
- you have been through every stage and are still not finished

**Ending the session** is a separate decision from writing the doc, and a rarer
one: take it only when a fresh session is genuinely cheaper than a compacted one,
and never mid-stage. Hooks cannot end or start a session, so say plainly in Slack
and in the terminal that you are handing over, and give the resume command.

## Throughout

- Keep a running list of decisions + assumptions as you go; it becomes the
  completion doc's assumptions section.
- Scratch docs (plan, review, handover) are Sujit's working material — don't
  commit them, don't cite them in commit messages. They live in the primary repo.
- Re-confirm the repo before any git op (`git -C "$repo"` beats `cd`), and tag
  every file, finding and result with its repo name — bare `file:line` is
  ambiguous once more than one repo is in play.
- Before declaring any stage complete, check it covered every repo in the
  manifest. A stage that quietly did one repo is the defining failure of this
  workflow.
