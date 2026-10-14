---
name: finalize
description: Wrap up a run — one MR per repo, pipelines and MR review (waited on by the orchestrator), then the completion doc and Slack wrap-up.
argument-hint: [optional MR URL or project/iid for the MR review]
allowed-tools: Bash, Read, Write, Glob, Grep, Skill, mcp__claude_ai_Slack__slack_send_message, mcp__claude_ai_Atlassian__getJiraIssue, mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql, mcp__claude_ai_Atlassian__getJiraIssueRemoteIssueLinks, mcp__claude_ai_Atlassian__getConfluencePage, mcp__claude_ai_Atlassian__searchConfluenceUsingCql, mcp__claude_ai_Atlassian__getPagesInConfluenceSpace, mcp__claude_ai_Atlassian__getConfluencePageDescendants, mcp__claude_ai_Atlassian__getConfluenceSpaces, mcp__claude_ai_Atlassian__addCommentToJiraIssue, mcp__claude_ai_Atlassian__createConfluencePage, mcp__claude_ai_Atlassian__updateConfluencePage
---

# Finalize

**Owner:** ${user_config.owner_name}, the person this run acts for ("the owner" here
and in the references). Slack goes to member `${user_config.slack_user_id}`, else the
sidecar's Slack target, else record Slack as unavailable in the degraded list.

## Who runs what

Finalize waits on pipelines, evals and reviewers, so it runs in parts, and the
orchestrator holds every wait. An agent idle past the five-minute prompt cache pays
to rewrite its whole context when it resumes; the orchestrator's is the smallest in
the run, so waiting there costs least, and no agent here is alive while nothing is
happening.

| Part | Runs on | Steps |
|---|---|---|
| Publish | `builder` (Sonnet 5.5) | 1 |
| Pipelines and evals | the orchestrator, through `scripts/vicaris-wait.sh` | 2 |
| MR review | the orchestrator runs the reviewers; a short `lead` (Opus 5.5) decides; one `builder` per repo fixes | 3 |
| Wrap | `builder` (Sonnet 5.5) | 4–7 |

Every part carries out what was already decided, except the call on the MR review's
findings, which is Opus's. Each agent reads
`${CLAUDE_PLUGIN_ROOT}/references/project-context.md` (MR flow, MR-reviewer
command, eval jobs, Slack target) and `${CLAUDE_PLUGIN_ROOT}/references/multi-repo.md`
(the repo set). Skip a plugin reference only if it is already in your context (the
orchestrator's Step 0 loads them in its own session; a sub-agent has not seen them).
Every `change` repo in the manifest (`<primary-repo>/.vicaris/repos-<branch>.txt`)
needs its own MR and its own MR review; no manifest means the current repo is the
whole set.

## Step 1 — Publish: create and announce an MR for every repo

The work is already committed: one commit per stage per repo, made locally as each
stage ended (`references/multi-repo.md`, *Commits*). Publishing pushes those commits
as they are, without squashing them, so the MR shows the build and the review fix
pass apart. A repo with uncommitted work here is a stage that did not finish: commit
it as that stage's commit only if its gate is current, otherwise re-run the gate
first.

Create (or refresh) an MR **in each `change` repo with work on the branch**, via the
project's MR flow, targeting **that repo's manifest base** (`bash
"${CLAUDE_PLUGIN_ROOT}/scripts/vicaris-manifest.sh" base "$repo"`, minus its `origin/`
prefix), never an assumed `main`. Every one of them:

- carries the **same Jira key** in title and description;
- **cross-links the sibling MRs** ("part of PROJ-1234, with <other MR>"), so no
  one approves half a contract change blind;
- states the **merge order** if the MRs can't land in any order;
- carries any **outstanding findings** the review fix pass left open, under a
  visible heading (`references/gates.md`).

Record each MR's URL where the status check reads it:

```bash
echo "<mr-url>" > "$repo/.vicaris/mr-$BRANCH.txt"
```

If the sidecar defines a team MR-review channel, **announce the set there in the
team's format** (link + purpose + ticket, optional `cc:`), **together in one
message**, one line per MR under the shared ticket, in plain wording.

Ping the run's Slack thread with each MR link as it goes up
(`references/notifications.md`).

Then run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/vicaris-status.sh" --final`; it exits
non-zero on a repo with work and no MR, uncommitted changes, or a verify result older
than the code.

**If the change touched prompts and the sidecar names an eval gate**, play the eval
job for each affected component on each MR's pipeline before you report, and name
the job pattern in your report; the orchestrator waits for it. With no eval named,
record in `<primary-repo>/.vicaris/degraded-<branch>.txt` that the prompt change went
unevaluated.

Report the MR links and stop. Do not wait for a pipeline or a reviewer.

## Step 2 — Pipelines and evals (the orchestrator)

Wait on every `change` repo's pipeline, and separately on the eval jobs if Step 1
named a pattern:

```bash
W="${CLAUDE_PLUGIN_ROOT}/scripts/vicaris-wait.sh"
bash "$W" pipeline --manifest "$MANIFEST"                              # every repo with an MR
bash "$W" pipeline --manifest "$MANIFEST" --job "$EVAL_JOB_PATTERN"     # its eval jobs
```

Exit 124 means still running: call it again. Each call blocks for up to nine minutes
and returns one line per repo, so waiting costs one short result per call rather
than a poll's worth of output in a growing context. Exit 3 means an eval job was
never played; play it and wait again:

```bash
(cd "$repo" && glab ci trigger "$(glab ci get --branch "$BRANCH" --output json \
  | jq -r --arg re "$EVAL_JOB_PATTERN" '.jobs[] | select(.name | test($re)) | select(.status == "manual") | .id' | head -1)")
```

Exit 1 names each failing repo and the file holding its failed jobs' log tails. A
failed build or test job is execution: one `builder` per failing repo, given that
file, fixes, re-runs the gate, commits and pushes. An eval that moved needs judgement
first: a short `lead` reads the log file and the prompt change and decides whether it
is a regression to fix or noise to record, and a builder applies what it decides.
Then wait again. A pipeline still red after two fixes is recorded as outstanding in
the ledger and carried into the MR description and the completion doc; it does not
end the run.

## Step 3 — MR review, on every MR (the orchestrator)

This is the change's second review, and the only one over the review fix pass
(`references/gates.md`, *Loop caps*). Run the standalone reviewer from
`project-context.md` on **every MR at once**,
detached, so no Bash timeout cuts a slow review off, then wait for all of them:

```bash
# MR_REVIEWER_DIR and the command come from project-context.md
bash "${CLAUDE_PLUGIN_ROOT}/scripts/vicaris-manifest.sh" list "$MANIFEST" change | cut -f1 \
  | while read -r repo; do
      [ -s "$repo/.vicaris/mr-$BRANCH.txt" ] || continue
      bash "$W" start "$repo/.vicaris/mr-review-$BRANCH.txt" -- \
        bash -c 'cd "$1" && .venv/bin/mr-reviewer review --url "$2"' _ "$MR_REVIEWER_DIR" "$(cat "$repo/.vicaris/mr-$BRANCH.txt")"
    done
bash "$W" files --manifest "$MANIFEST" --suffix ".vicaris/mr-review-$BRANCH.txt"
```

With no standalone reviewer in the sidecar, run one `review-runner` per MR's repo
against its pushed branch, as review does, writing to the same file.

This checks the *pushed* state (the fix pass, any rebase and conflict resolution)
and gives the team a visible verdict; the depth already happened in
`adversarial-review`. A blocker from it means the local review missed something
under the same charter: fix it, and say in the completion doc what the earlier pass
should have caught. It sees one MR at a time, so clean single-MR verdicts don't
add up to a clean review of the whole change. Do not read the review output into
your own context; its verdict line is enough for the Slack ping.

Ping the thread with each MR's verdict, and again once its comments are resolved.

**Hand the verdicts to a short `lead` to decide** (`subagent_type: lead`, Opus 5.5):
it gets each MR's review file, the ledger path, and each repo's review fix commit
(the `<repo> commit:` line under the ledger's `## review pass 1`, if there is one). It
decides apply or decline for each finding with its reason in the ledger's
`## mr-review pass 1` section, marks a finding whose lines the review fix commit
wrote with `· fix-pass code` (`git -C "$repo" blame` on the lines, or the commit's
diff), and rewrites in place the design-note section any applied finding changes
(`design-note.md`, *Keeping it current*). An applied finding can change a design
decision, and that call is Opus's. A suggestion the local review already parked does
not come back: the lead answers it with the ledger line that parked it. A finding
that undoes a local fix is oscillation (`gates.md`).

Then the fix: one `builder` per repo with findings to apply, spawned together, each
applying its repo's findings, re-running its gate and the integrated path where the
seam moved, committing and pushing. Then back to Step 2 for those repos' pipelines.
**One fix pass, and no second MR review** (`references/gates.md`): what is still
open is outstanding.

## Step 4 — Wrap: completion document

Written last, so it records what actually shipped: the MRs, the pipelines, the MR
review and every fix pass are already in the artifacts it reads.

Write **one** completion doc for the whole change at
`<primary-repo>/.vicaris/completion-<branch>.md` (scratch; don't commit unless the
owner asks). Carry every line of `<primary-repo>/.vicaris/degraded-<branch>.txt`
into it: what the run could not do is part of what it delivered.

The doc exists to save the owner a review, so it is read top-down and most readers
stop after its first section. A doc too long to read sends the owner back to the
diff, and then it cost a stage and saved nothing.

**Open with *What to check*,** one screen, before anything else:

- **The calls most worth a second look**, at most three, ranked by how much
  behaviour each would change if it were wrong: the reading of a criterion, a
  contradiction resolved, a design choice. One line each: what was decided, the
  alternative, and what changes if the alternative was right.
- **Behaviour changed outside what the story names**: every entity, region, client
  or path whose behaviour moves although the story does not mention it, or `none`.
  A change that does more than it was asked to is the thing an MR reviewer finds
  last and a rework costs most.
- **Outstanding**: every finding still open, every pipeline still red, every check
  that did not run, one line each.
- **Size**: each MR's link with its files changed and lines added and removed.

**Match its scope to the risk class** (`references/risk-classes.md`): `mechanical`
covers what was threaded where, the parity result and the verify result; `tiny`
adds the decisions; `normal` and above carry every section below; and `production`
adds a rollback plan: how this is turned off, by whom, and whether it needs a deploy.
Write each section once, as its content needs, from the artifacts it names, and
point at the design notes, the challenge doc and the ledger rather than restating
them; the owner can open those for the reasoning.

Then these sections:

- **Summary of changes** — what was built, which files/modules, and why, keyed to
  the acceptance criteria, with the verify result and tests added. Group it **by
  repo**; where the change spans repos, describe the contract and the required
  merge order (or state that the MRs can land in any order).
- **Assumptions** — every meaningful decision with the **alternatives considered**
  and the **reason** the chosen one won, honest about tradeoffs and anything the
  owner might revisit. Build it from the artifacts, not from memory, since
  reasoning reconstructed at the end comes out as justification:
  - read **every** repo's `.vicaris/design-notes-<branch>.md` (line 3 is the
    rejected alternative and what broke under it), walking the manifest so no
    repo's decisions go unreviewed;
  - then read `<primary-repo>/.vicaris/design-challenge-<branch>.md` and lead the
    section with it: each divergence as the decision, which design won, the
    consequence named, and adopted or declined with the citation. Say plainly
    when the challenge was skipped and why, or found nothing material.
- **Testing notes** — what was tested (unit + browser + traces/logs), what worked,
  what didn't (with evidence), carried over verbatim from the test stage.

Write it plainly and save it. It is the owner's scratch record and nobody else
reads it, so it gets no prose-cleaning pass; the text other people read (the MR
descriptions, the Jira comment, the channel post) is where that care goes.

Refresh each MR's description with any finding still outstanding after the MR-review
loop, under the same visible heading as the review loop's.

## Step 5 — Jira and Confluence, only where the sidecar says so

Write to the team's ticket and space only where `project-context.md` says to:

- **A comment on the Jira issue** — the MR links, the merge order if it matters,
  and the AC scorecard in one short block. Never the completion doc, which is the
  owner's working record.
- **A Confluence page** — only when the sidecar names a space, as an update to the
  feature's existing page rather than a new one.

With nothing in the sidecar, skip both silently.

## Step 6 — Slack summary (DM to the owner)

Post the wrap-up to the Slack target (default self-DM) via
`mcp__claude_ai_Slack__slack_send_message`, leading with the completion doc's *What
to check* (the calls worth a second look, behaviour changed outside the story, what
is outstanding), then what shipped, the testing outcome, and **every MR link with
its size and review result** (plus the merge order, if it matters). Thread it under the run's parent message with
`reply_broadcast: true` (`references/notifications.md`). Draft it in the owner's
voice (see `my-voice`); keep it tight.

## Step 7 — Stop keep-awake, and point at the doc

Stop the keep-awake this run started, **by its PID**:

```bash
PIDFILE="$PRIMARY/.vicaris/caffeinate-$BRANCH.pid"
[ -f "$PIDFILE" ] && kill "$(cat "$PIDFILE")" 2>/dev/null; rm -f "$PIDFILE"
```

Never `pkill -f 'caffeinate -dimsu'`: it also matches a session the owner launched
as `caffeinate -dimsu claude`, and killing that ends the run. With no pidfile,
leave it; the `-t 21600` cap expires on its own.

Print the completion-doc path and **every** MR link, then close with the per-repo
checklist, generated rather than recalled:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/vicaris-status.sh" --final
```

It exits non-zero on a repo with work and no MR, no current verify, or uncommitted
changes, and on a `read` repo the run edited. Fix whatever it names
before the wrap-up rather than reporting it.
