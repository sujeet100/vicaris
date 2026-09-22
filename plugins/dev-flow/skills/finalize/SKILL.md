---
name: finalize
description: Wrap up a completed task — generate the completion document (summary of changes, assumptions with alternatives and reasons, testing notes), run the standalone MR reviewer, and post a Slack summary to Sujit.
argument-hint: [optional MR URL or project/iid for the MR review]
allowed-tools: Bash, Read, Write, Glob, Grep, Skill, mcp__claude_ai_Slack__slack_send_message, mcp__claude_ai_Atlassian__getJiraIssue, mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql, mcp__claude_ai_Atlassian__getJiraIssueRemoteIssueLinks, mcp__claude_ai_Atlassian__getConfluencePage, mcp__claude_ai_Atlassian__searchConfluenceUsingCql, mcp__claude_ai_Atlassian__getPagesInConfluenceSpace, mcp__claude_ai_Atlassian__getConfluencePageDescendants, mcp__claude_ai_Atlassian__getConfluenceSpaces, mcp__claude_ai_Atlassian__addCommentToJiraIssue, mcp__claude_ai_Atlassian__createConfluencePage, mcp__claude_ai_Atlassian__updateConfluencePage
---

# Finalize

Close out the task. Read `${CLAUDE_PLUGIN_ROOT}/references/project-context.md`
for the MR-reviewer command and the Slack target, and
`${CLAUDE_PLUGIN_ROOT}/references/multi-repo.md` for the repo set — every repo in
the manifest (`<primary-repo>/.dev-flow/repos-<branch>.txt`) needs its own MR and
its own MR review. No manifest means a single-repo change; treat the current repo
as the whole set.

## Step 1 — Completion document

Write **one** completion doc covering the whole change, in the primary repo —
`<primary-repo>/.dev-flow/completion-<branch>.md` (scratch; don't commit unless
Sujit asks). One doc, not one per repo: the change is one thing and Sujit reviews
it in one place.

**Match its length to the risk class** (`references/risk-classes.md`). A
`mechanical` change gets five lines — what was threaded where, the parity result,
the verify result — and padding that out to the full shape below produces a
document nobody reads on a change nobody needed to read about. `tiny` gets a short
version. `normal` and above get all of it, and `production` adds a rollback plan:
how this is turned off, by whom, and whether it needs a deploy.

Scannable sections:

- **Summary of changes** — what was built, which files/modules, and why, keyed
  to the acceptance criteria. Note the verify result and tests added. Group it
  **by repo**, and where the change spans repos, describe the contract between
  them and the required merge order (or state that the MRs can land in any
  order, if the change was designed to be backward compatible).
- **Assumptions** — every meaningful decision, each with the **alternatives
  considered** and the **reason** the chosen option won. This is the record
  Sujit reviews the implementation against, so be explicit and honest about
  tradeoffs and anything he might want to revisit. Build it from two artifacts
  rather than reconstructing it here, because reasoning reconstructed at the end
  comes out as justification for what was built.

  Read **every** repo's `.dev-flow/design-notes-<branch>.md` — line 3 of each is a
  rejected alternative and the specific thing that broke under it, written when the
  decision was live. Walk the manifest for them; a repo whose notes you never opened
  is a repo whose decisions go unreviewed.

  Then read `<primary-repo>/.dev-flow/design-challenge-<branch>.md`, and lead the
  section with what it found. A decision that survived a contest against a design
  built independently from the acceptance criteria is evidence; the same decision
  backed only by its author's self-critique is an argument. Give each divergence the
  form it had there — the decision, which design won, the consequence named, and
  whether it was adopted or declined with the citation — and say plainly when the
  challenge was skipped and why, or when it found nothing material, since two
  independent designs agreeing on the shape is the strongest signal this workflow
  produces.
- **Testing notes** — what was tested (unit + browser + traces/logs), what
  worked, and what didn't (with evidence). Carry over the testing results from
  the test stage verbatim rather than re-summarising loosely.

Before saving, clean up the doc's prose: flowing connected sentences that each
follow from the last, varied sentence length, no em dashes, no "it's not X, it's
Y," no forced trios, no puffery, and no one-sentence paragraphs that belong in the
paragraph above. If the `byline` plugin is installed, run `/de-ai` over the doc
instead — it applies the full standard and measures the result.

## Step 2 — Create + announce an MR for every repo

Walk the manifest and create (or refresh) an MR **in each repo that has commits
on the branch**, via the project's MR flow. Every one of them:

- carries the **same Jira key** in title and description;
- **cross-links the sibling MRs** ("part of PROJ-1234, with <other MR>"), so a
  reviewer landing on one knows the rest exist and can't approve half a contract
  change blind;
- states the **merge order** if the MRs can't land in any order;
- carries any **outstanding findings** the fix loop hit its cap on, under a heading
  a reviewer will see rather than buried in prose (`references/gates.md`).

Record each MR's URL where the status check reads it, one line, so a repo whose MR
silently never went up is visible rather than assumed:

```bash
echo "<mr-url>" > "$repo/.dev-flow/mr-$BRANCH.txt"
```

Then, if the sidecar defines a team MR-review channel, **announce them there in
the team's format** (link + purpose + ticket, optional `cc:`) — that channel post
is the review request. Post the set **together in one message**, one line per MR
under the shared ticket, rather than as separate posts that look like unrelated
work. Keep the wording plain, no AI-writing tells.

**Ping the run's Slack thread with each MR link as it goes up**, per
`${CLAUDE_PLUGIN_ROOT}/references/notifications.md`, rather than holding them all
for the wrap-up.

Before moving on, confirm every repo in the manifest either has an MR or is
recorded as having no changes. A repo with branch commits and no MR is work that
silently never ships.

**If the change touched prompts**, the component eval is mandatory and runs on
the MR pipeline (never locally). Per the sidecar, trigger the **manual** eval
job for each affected component on **each MR's** pipeline and monitor it to
green; fold any eval regression back through implement → review before the task
is done.

## Step 3 — MR review, on every MR

Run the standalone reviewer from `project-context.md` once **per MR**:

```
cd <mr-reviewer path>
.venv/bin/mr-reviewer review <project-path> <mr-iid>     # repeat for each MR
```

**This is a check on the review, not the review itself.** The depth already
happened at the `adversarial-review` stage, against the same charter, while the
findings were still cheap to act on. What the bot adds is a look at the *pushed*
state rather than the working tree — everything that happened after the local
review, which is the fix pass, the rebase onto a moved base, and whatever the
conflict resolution did — plus a visible verdict in the shared thread, which is
what the team reads.

Read it in that spirit. A clean bot review confirms nothing changed on the way
out. A blocker from it is worth more than its own content, because the local
review had the same charter and missed it: fix it, and say in the completion doc
what the earlier pass should have caught, so the calibration is visible rather
than absorbed silently.

Its one structural limit is unchanged: it sees a single MR, so it cannot judge the
seam between them. That gap is covered at review time now — `review-changes` runs
with `--also-repo` for every sibling, so the contract between repos was reviewed
against the real callers — and clean single-MR verdicts still don't add up to a
clean review of the whole change.

Ping the thread with each MR's verdict as it comes back, and again once you've
resolved its comments.

Feed any blocker/should-fix findings back through implement → review → test,
applying each in the repo it belongs to and re-running that repo's verify (through
`scripts/dev-flow-gate.sh`) plus the integrated path. In an autonomous run, apply
the fixes and re-review rather than stopping — only genuine external blockers pause
the run.

**Two passes, then stop** (`${CLAUDE_PLUGIN_ROOT}/references/gates.md`), with each
outcome in the ledger. And a suggestion the local review already considered and
parked does not come back: answer it with the ledger line that parked it rather
than relitigating it because a second reviewer raised it. That file is what makes
this second review cheap instead of a repeat of the first.

## Step 3b — Jira and Confluence, only where the sidecar says so

The completion doc is Sujit's; the ticket and the space belong to the team, so
this stage writes to them only where `project-context.md` says to and never on its
own initiative. Where it does:

- **A comment on the Jira issue** — the MR links, the merge order if it matters,
  and the AC scorecard in one short block. Not the completion doc: that is a
  working record with self-critique in it, written for one reader.
- **A Confluence page** — only when the sidecar names a space for it, and then as
  an update to the existing page for the feature rather than a new one beside it.

With nothing in the sidecar, skip both silently. An unattended run that starts
posting to shared spaces is worse than one that stays quiet, and the Slack wrap-up
already reaches the person who wanted to know.

## Step 4 — Slack summary (DM to Sujit)

Post the wrap-up to the Slack target (default self-DM) via
`mcp__claude_ai_Slack__slack_send_message`: what shipped, the assumptions worth
his eyes, the testing outcome, and **every MR link with its review result** (plus
the merge order, if it matters). Thread it under the run's parent message with
`reply_broadcast: true` so the outcome surfaces in the DM list instead of staying
buried in the thread (`references/notifications.md`). Draft it in Sujit's voice
(see `my-voice`); keep it tight.

## Step 5 — Stop keep-awake

Stop the keep-awake this run started, **by its PID**:

```bash
PIDFILE="$PRIMARY/.dev-flow/caffeinate-$BRANCH.pid"
[ -f "$PIDFILE" ] && kill "$(cat "$PIDFILE")" 2>/dev/null; rm -f "$PIDFILE"
```

Never `pkill -f 'caffeinate -dimsu'`. That pattern also matches a session Sujit
launched as `caffeinate -dimsu claude`, and killing it ends the session — so the
tidy-up step would be the thing that kills the run. With no pidfile, leave it:
the `-t 21600` cap expires on its own, and a stray keep-awake costs far less than
a killed session.

## Step 6 — Point at the doc

Print the completion-doc path and **every** MR link so Sujit has one place to
review everything. Close with the per-repo checklist, generated rather than
recalled:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/dev-flow-status.sh"
```

It reads the artifacts the stages wrote — commits, verify result, MR — and exits
non-zero on a repo with work and no MR or no verify. A checklist you write from
memory at the end of a long run is the one place a dropped repo hides, and this one
cannot be written from memory. Fix whatever it names before the wrap-up rather than
reporting it.
