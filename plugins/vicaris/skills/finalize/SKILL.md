---
name: finalize
description: Wrap up a run — completion doc, one MR per repo, MR review on each, Slack wrap-up.
argument-hint: [optional MR URL or project/iid for the MR review]
allowed-tools: Bash, Read, Write, Glob, Grep, Skill, mcp__claude_ai_Slack__slack_send_message, mcp__claude_ai_Atlassian__getJiraIssue, mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql, mcp__claude_ai_Atlassian__getJiraIssueRemoteIssueLinks, mcp__claude_ai_Atlassian__getConfluencePage, mcp__claude_ai_Atlassian__searchConfluenceUsingCql, mcp__claude_ai_Atlassian__getPagesInConfluenceSpace, mcp__claude_ai_Atlassian__getConfluencePageDescendants, mcp__claude_ai_Atlassian__getConfluenceSpaces, mcp__claude_ai_Atlassian__addCommentToJiraIssue, mcp__claude_ai_Atlassian__createConfluencePage, mcp__claude_ai_Atlassian__updateConfluencePage
---

# Finalize

**Owner:** ${user_config.owner_name}, the person this run acts for ("the owner" here
and in the references). Slack goes to member `${user_config.slack_user_id}`, else the
sidecar's Slack target, else record Slack as unavailable in the degraded list.

Close out the task. Read `${CLAUDE_PLUGIN_ROOT}/references/project-context.md`
(MR-reviewer command, Slack target) and `${CLAUDE_PLUGIN_ROOT}/references/multi-repo.md`
(the repo set). Skip a plugin reference only if it is already in your context (the orchestrator's
Step 0 loads them in its own session; a sub-agent has not seen them). Every repo in the manifest
(`<primary-repo>/.vicaris/repos-<branch>.txt`) needs its own MR and its own MR
review; no manifest means the current repo is the whole set.

## Step 1 — Completion document

Write **one** completion doc for the whole change at
`<primary-repo>/.vicaris/completion-<branch>.md` (scratch; don't commit unless the
owner asks). Carry every line of `<primary-repo>/.vicaris/degraded-<branch>.txt`
into it: what the run could not do is part of what it delivered.

**Match its length to the risk class** (`references/risk-classes.md`): `mechanical`
gets five lines (what was threaded where, the parity result, the verify result),
`tiny` a short version, `normal` and above all of it, and `production` adds a
rollback plan: how this is turned off, by whom, and whether it needs a deploy.

Scannable sections:

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

Before saving, clean the prose: connected sentences, varied length, no em dashes,
no "it's not X, it's Y", no forced trios, no puffery, no stray one-sentence
paragraphs. If the `byline` plugin is installed, run `/de-ai` over the doc instead.

## Step 2 — Create + announce an MR for every repo

Create (or refresh) an MR **in each repo with commits on the branch**, via the
project's MR flow. Every one of them:

- carries the **same Jira key** in title and description;
- **cross-links the sibling MRs** ("part of PROJ-1234, with <other MR>"), so no
  one approves half a contract change blind;
- states the **merge order** if the MRs can't land in any order;
- carries any **outstanding findings** the fix loop capped on, under a visible
  heading (`references/gates.md`).

Record each MR's URL where the status check reads it:

```bash
echo "<mr-url>" > "$repo/.vicaris/mr-$BRANCH.txt"
```

If the sidecar defines a team MR-review channel, **announce the set there in the
team's format** (link + purpose + ticket, optional `cc:`), **together in one
message**, one line per MR under the shared ticket, in plain wording.

Ping the run's Slack thread with each MR link as it goes up
(`references/notifications.md`).

Then run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/vicaris-status.sh"`; it exits
non-zero on a repo with commits and no MR.

**If the change touched prompts and the sidecar names an eval gate**, run it where
the sidecar says (typically a job on **each MR's** pipeline) and wait for it with a
background loop, never by polling (`references/delegation.md`); fold any regression
back through implement → review. With no eval named,
say in the completion doc that the prompt change went unevaluated.

## Step 3 — MR review, on every MR

Run the standalone reviewer from `project-context.md` once **per MR**:

```
cd <mr-reviewer path>
.venv/bin/mr-reviewer review <project-path> <mr-iid>     # repeat for each MR
```

This checks the *pushed* state (the fix pass, any rebase and conflict resolution)
and gives the team a visible verdict; the depth already happened in
`adversarial-review`. A blocker from it means the local review missed something
under the same charter: fix it, and say in the completion doc what the earlier pass
should have caught. It sees one MR at a time, so clean single-MR verdicts don't
add up to a clean review of the whole change.

Ping the thread with each MR's verdict, and again once its comments are resolved.

Feed blocker/should-fix findings back through implement → review → test, each fix
pass one sub-agent on the class's build model, applying each finding in its own repo and re-running that repo's verify (through
`scripts/vicaris-gate.sh`) plus the integrated path. Apply and re-review rather
than stopping; only genuine external blockers pause the run.

**Two passes, then stop** (`references/gates.md`), each outcome in the ledger. A
suggestion the local review already parked does not come back: answer it with the
ledger line that parked it.

## Step 3b — Jira and Confluence, only where the sidecar says so

Write to the team's ticket and space only where `project-context.md` says to:

- **A comment on the Jira issue** — the MR links, the merge order if it matters,
  and the AC scorecard in one short block. Never the completion doc, which is the
  owner's working record.
- **A Confluence page** — only when the sidecar names a space, as an update to the
  feature's existing page rather than a new one.

With nothing in the sidecar, skip both silently.

## Step 4 — Slack summary (DM to the owner)

Post the wrap-up to the Slack target (default self-DM) via
`mcp__claude_ai_Slack__slack_send_message`: what shipped, the assumptions worth
their eyes, the testing outcome, and **every MR link with its review result** (plus
the merge order, if it matters). Thread it under the run's parent message with
`reply_broadcast: true` (`references/notifications.md`). Draft it in the owner's
voice (see `my-voice`); keep it tight.

## Step 5 — Stop keep-awake

Stop the keep-awake this run started, **by its PID**:

```bash
PIDFILE="$PRIMARY/.vicaris/caffeinate-$BRANCH.pid"
[ -f "$PIDFILE" ] && kill "$(cat "$PIDFILE")" 2>/dev/null; rm -f "$PIDFILE"
```

Never `pkill -f 'caffeinate -dimsu'`: it also matches a session the owner launched
as `caffeinate -dimsu claude`, and killing that ends the run. With no pidfile,
leave it; the `-t 21600` cap expires on its own.

## Step 6 — Point at the doc

Print the completion-doc path and **every** MR link, then close with the per-repo
checklist, generated rather than recalled:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/vicaris-status.sh"
```

It exits non-zero on a repo with work and no MR or no verify. Fix whatever it names
before the wrap-up rather than reporting it.
