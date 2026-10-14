---
name: handover
description: Write or refresh the handover doc so a compacted or fresh session resumes a Vicaris run with no loss of state.
argument-hint: [optional note on where things stand]
allowed-tools: Bash, Read, Write, Glob, Grep, mcp__claude_ai_Slack__slack_send_message, mcp__claude_ai_Atlassian__getJiraIssue, mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql, mcp__claude_ai_Atlassian__getJiraIssueRemoteIssueLinks
---

# Handover

**Owner:** ${user_config.owner_name}, the person this run acts for ("the owner" here
and in the references). Slack goes to member `${user_config.slack_user_id}`, else the
sidecar's Slack target, else record Slack as unavailable in the degraded list.

Capture enough state that a compacted or brand-new session resumes seamlessly.
Compaction keeps the session alive but lets a summariser choose which detail
survives; this doc is where you choose instead. In an orchestrated run, invoke this
skill once; at later stage boundaries follow its write step from context rather
than invoking it again, unless a compaction has dropped its field list, in which
case invoke it again.

## When to trigger

The **write step** is routine: run it at every stage boundary (understand,
implement, review, test, finalize), when an observable tripwire fires (a third
review-fix pass, a third verification iteration, or every stage done and still not
finished), and immediately when a `PreCompact` hook says the doc is missing or
stale. Never key it to a context percentage; you
cannot see one.

The **hand-off step**, actually ending the session, is rarer: only when a fresh
session is genuinely cheaper than a compacted one, and never mid-stage.

## Write step

Write a scratch doc (don't commit it) at
`<primary-repo>/.vicaris/handover-<branch>.md` (create `.vicaris/` if absent), or
the session scratchpad. Dense and factual:

- **Task** — goal, acceptance criteria, Jira key / branch. Point at
  `<primary-repo>/.vicaris/understanding-<branch>.md` rather than restating it.
- **Risk class** — the line from `<primary-repo>/.vicaris/risk-<branch>.txt`, and
  whether the gate's observed check has raised it yet.
- **Repos in scope** — every repo in the manifest
  (`<primary-repo>/.vicaris/repos-<branch>.txt`, see `references/multi-repo.md`),
  in dependency order, each with its branch, whether it is branched yet, its verify
  result and its MR. List them explicitly even when the manifest exists.
- **Stage** — where in understand → design → challenge → implement → review → test
  → finalize things are, and **per repo** where they differ. Inside review and
  finalize, the step of the loop the orchestrator is on (reviewers running, deciding,
  fix pass N, waiting on pipelines or MR reviewers), and any open decision request
  in `<primary-repo>/.vicaris/decision-requests-<branch>.md`. A detached MR reviewer
  started with `vicaris-wait.sh start` keeps running across a compaction: name its
  output file so the resumed session waits for it instead of starting another.
- **Done** — what's implemented and verified, with the verify result.
- **In flight** — the exact next action, mid-edit files (repo-qualified), any
  partial state.
- **Decisions + assumptions** — every fork resolved so far and its assumption,
  including the cross-repo contract and merge order. List each repo's
  `.vicaris/design-notes-<branch>.md` path rather than restating them, and point at
  `<primary-repo>/.vicaris/design-challenge-<branch>.md`, saying whether the
  challenge has run yet.
- **Open items** — unfixed review findings (repo-qualified), missing tests, parked
  items. Point at `<primary>/.vicaris/fix-ledger-<branch>.md` and **say which fix
  pass each loop is on** (caps in `references/gates.md`).
- **Environment** — every repo path and branch, stack/SSO state, whether
  `caffeinate` is running, relevant PIDs.
- **Resume command** — the exact `/vicaris` (or stage) invocation to continue.

## Hand-off step

**Ping Slack** threaded under the run's parent message
(`references/notifications.md`): the session is handing over, the stage reached,
and the doc path.

Print the handover path and the one-line resume instruction. In an autonomous run
the orchestrator then ends the session cleanly, and the next one starts from the
handover doc.
