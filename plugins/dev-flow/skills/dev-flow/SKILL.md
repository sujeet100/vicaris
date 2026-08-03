---
name: dev-flow
description: Run the full autonomous dev workflow end to end — plan, implement, parallel adversarial review, browser test, then finalize — grounded in Sujit's coding principles. Drives the task to completion without manual intervention, pinging Slack only on genuine external blockers.
argument-hint: [Jira key, task description, or feature brief]
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Agent, mcp__claude_ai_Slack__slack_send_message, mcp__claude_ai_Atlassian__getJiraIssue, mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql
---

# dev-flow (orchestrator)

Take `$ARGUMENTS` from intake to a reviewed, tested, finalized change **without
manual intervention**. The individual stages (`plan`, `implement`,
`adversarial-review`, `test`, `handover`, `finalize`) also run standalone; this
skill sequences them.

## The autonomy contract (read first)

- **Finish the task autonomously.** Drive all the way to finalize. Do not stop
  to ask permission between stages.
- **Never ask a blocking question. Ever.** Do not use `AskUserQuestion` or any
  interactive prompt, and do not end a turn with a question and no work done.
  Sujit launched this expecting to come back to a finished change, so a prompt
  waiting for a keypress stalls the entire run for however long he's away. The
  *only* channel to him is an asynchronous Slack DM that you send and then keep
  working past.
- **Every fork is decided, not asked** — including the uncomfortable ones.
  Think it through, pick the option you'd recommend, log the assumption (and a
  one-line self-critique), and proceed. The completion doc is where Sujit
  reviews those calls afterwards. "I'd like to confirm first" is not a reason;
  presenting him a recommended option means you already know the answer, so take
  it.
- **Scope is never a question.** The story or brief defines the scope, so
  "how far should this run go?", "should I do both repos?" and "should I split
  this?" are all answered the same way: **deliver the whole scope of the story,
  every repo it touches.** If part of it is genuinely blocked, deliver everything
  else in full, ship the MRs for what's done, and record the remainder as
  follow-on with the reason. Never ask Sujit to choose a smaller scope — reducing
  scope is his call to make *after* seeing what you delivered, not a gate before
  you start.
- **Only genuine external blockers reach Sujit, and even then don't hard-stop.**
  The list is closed: expired SSO or a missing credential, a required upstream
  dependency that hasn't shipped, or a genuinely irreversible action (deleting
  data, publishing something public). Everything else you decide — his
  uncommitted work is explicitly **not** on this list, because a worktree handles
  it. Send a terse Slack DM, then continue with everything that isn't blocked and
  record the blocked item for the summary. Never spin waiting.
- **Blocked means blocked on one thing, not on the run.** A blocker in one repo,
  one AC, or one verification step stops *that* item only. Route around it and
  keep going; a single obstacle must never become a reason to stop everything and
  ask.
- **Push back in the record, not by pausing.** If a requested approach is
  wrong, implement the defensible version and flag the disagreement (with the
  alternative) in the completion doc.
- **If the rules seem to leave you no legal move, that's still your call.** Two
  instructions here can pull against each other — "deliver the whole scope" and
  "never touch his uncommitted work" being the obvious pair. A contradiction is
  not permission to stop and ask. Look for the option that honours both (there
  usually is one, and for that pair it's a worktree); failing that, take the
  least destructive action that makes progress, record the tension and what you
  chose in the completion doc, and mention it in the Slack wrap-up so the
  workflow itself gets fixed. Escalating a rule conflict mid-run costs Sujit the
  whole run; recording it costs him one paragraph.

### Forks that already have an answer

These come up most runs. None of them is a question; each has a standing
resolution, so apply it and note it in the completion doc.

| Situation | What you do |
|---|---|
| A sibling repo is behind its remote | Fetch and bring it current; that's Step 0.4, not a decision |
| A repo has Sujit's uncommitted work | `git worktree add` a clean checkout beside it and work there; his tree is untouched and the scope still ships |
| A repo's WIP looks like it wants committing or moving | Not yours to commit or move. Worktree, and don't mention it beyond a line in the completion doc |
| Part of the story is bigger than the rest | Deliver all of it anyway; size is not a scope question |
| The story names an unshipped dependency | Implement against the contract it specifies and note the ordering in the MR; only defer if the code genuinely cannot compile or run without it |
| The change needs a new library | Add it — matching the project's existing conventions and the smallest option that does the job — and record the choice |
| Browser verification is needed and SSO is dead | Slack the SSO ask, finish everything else, MR it with the browser step flagged unverified |
| One AC is ambiguous | Implement the reading a careful colleague would pick, state the assumption, and flag it for review |
| The change looks risky to ship | Put it behind a toggle or keep it backward compatible, and say so — don't seek permission |

If a fork genuinely isn't on this list and isn't on the closed blocker list
above, that means it's yours to decide. Decide it.

## Step 0 — Session setup

1. Load the standard: read `${CLAUDE_PLUGIN_ROOT}/references/coding-principles.md`,
   `${CLAUDE_PLUGIN_ROOT}/references/multi-repo.md` (cross-repo changes are the
   norm here), `${CLAUDE_PLUGIN_ROOT}/references/notifications.md` (when to ping
   Slack — an unattended run must stay visible) and
   `${CLAUDE_PLUGIN_ROOT}/references/project-context.md` (skip the sidecar
   silently if absent).
2. **Keep the machine awake** so sleep can't stall a long run. Start a capped
   keep-awake in the background and remember it for finalize:
   ```bash
   nohup caffeinate -dimsu -t 21600 >/dev/null 2>&1 &   # 6h safety cap
   ```
   (If Sujit launched the whole session under `caffeinate` already, this is
   just a harmless backstop.)
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
   sibling repo is invisible until the plan is already wrong. You can only
   branch the repo you start in this early; the rest wait for the plan (Step 1b).
6. **Effort:** run every stage at high reasoning effort.

## Step 1 — Plan (model: fable)

Delegate planning to a **fable** sub-agent (Agent tool, `model: fable`) running
the `plan` skill's method on `$ARGUMENTS`. Planning is cheaper and fast on
fable; implementation and review are not. Capture the returned plan — goal,
approach, change set, assumptions, test plan.

### Step 1b — Pin the repo set and branch it

The plan's **Repos in scope** section is the first point at which you know the
full set. Write it to the manifest that every later stage reads
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

From here on, **every stage fans out over the manifest**: implement, review,
test, fix passes, MRs and MR-review all cover all of it. Half-covered is worse
than not started, because the run reports done.

### Step 1c — Open the Slack thread

Post the run's parent Slack message now — ticket, one-line goal, repos in scope,
branch — and persist its `ts` so every later ping threads under it:

```bash
echo "<ts>" > "$PRIMARY/.dev-flow/slack-thread-$BRANCH.txt"
```

Then ping at each stage boundary per `references/notifications.md`. Sujit is not
watching the terminal, so a stage that finishes silently is indistinguishable from
a stage that hung. Send and move on; never wait for a reply.

## Step 2 — Implement (model: opus, auto mode)

Implement the plan yourself on **opus** at high effort, in **auto mode**,
following the `implement` skill: clean, small, typed, declarative, domain-
modelled, concise-but-sufficient tests, zero warnings, fast verify. Do not run
eval / integration suites to verify. Respect pre-commit gates.

Work the manifest **in dependency order** — producer repo before consumer — and
run each repo's own verify before moving on, so a broken contract surfaces at the
seam rather than three repos later.

Ping the thread when implementation is done: per repo, what changed in a phrase
and the verify result.

## Step 3 — Adversarial review (3× opus, parallel)

Run the `adversarial-review` skill: spawn the PO, clean-code, and design
reviewers **in one message** as parallel opus sub-agents, then synthesise the
ranked report. The reviewers see the diff from **every** repo in the manifest
plus the cross-repo contract between them — never one repo's slice. Apply every
blocker and should-fix (back through implement, in whichever repo the finding
landed in), then re-verify that repo. Loop until the review is clean or only
"skip for now" items remain.

Ping the thread when the review lands (counts by severity, plus the headline of
anything non-trivial), and again if the fix loop runs more than twice — a
thrashing review loop is exactly the failure Sujit can't see from outside.

## Step 4 — Test

Run the `test` skill: each repo's fast unit suite, then real browser testing of
any user-visible change (SSO-aware, no secret through your context), plus logs
and traces. A cross-repo change is only proven by exercising the integrated
path, so don't let green units in both repos stand in for it. Post the Slack
results summary. Fix and re-test anything that failed. If blocked on SSO, Slack
Sujit and continue with the rest.

## Step 5 — Finalize

Run the `finalize` skill: write the completion doc (summary of changes;
assumptions with alternatives and reasons; testing notes — what worked, what
didn't), then **one MR per repo in the manifest**, cross-linked to each other and
carrying the same Jira key, announced together in the team channel. Run the
standalone MR reviewer **on every MR** and fold each one's findings back into its
own repo, then post the Slack wrap-up and stop the `caffeinate` you started.

The task is not done while any repo in the manifest lacks an MR or an MR review.

## Context discipline (~50% → handover)

Watch your context budget throughout. As it approaches ~50%, run the `handover`
skill: write the handover doc, then end this session cleanly. The work resumes
in a fresh session started from the handover doc — no state lost, no manual
re-explanation. Prefer handing over at a stage boundary.

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
