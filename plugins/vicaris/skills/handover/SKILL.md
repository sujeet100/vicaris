---
name: handover
description: Write or refresh the handover document so a fresh session (or a compacted one) resumes the work with no loss of state. Autonomous runs refresh it at every stage boundary rather than trying to judge remaining context.
argument-hint: [optional note on where things stand]
allowed-tools: Bash, Read, Write, Glob, Grep, mcp__claude_ai_Slack__slack_send_message, mcp__claude_ai_Atlassian__getJiraIssue, mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql, mcp__claude_ai_Atlassian__getJiraIssueRemoteIssueLinks
---

# Handover

**Owner:** ${user_config.owner_name}. This run acts for them, and wherever this skill
or a reference says "the owner", it means them. Slack DMs and pings go to Slack
member `${user_config.slack_user_id}`; if that is blank, use the Slack target in
`project-context.md`, and if neither exists, record Slack as unavailable in the
run's degraded list rather than guessing a recipient.

Capture enough state that a compacted session, or a brand new one, resumes
seamlessly. Auto-compaction will keep the session alive on its own; what it will
not keep is the *detail*, since a summariser decides what matters rather than you.
This doc is where you choose what survives, so it is written early and often
rather than once at the end.

## When to trigger

**Writing** this doc is routine, not exceptional: every stage boundary, always.
There is no context percentage to judge — you cannot see your window usage, and no
hook reports it, so anything keyed to a number fails silently.

Write or refresh it when:

- a stage boundary is reached (plan, implement, review, test, finalize) — always,
- an observable tripwire fires: a third review-fix pass, a third verification
  iteration, more than about six sub-agents, or every stage done and still not
  finished,
- a `PreCompact` hook tells you the doc is missing or stale — write it immediately,
  while there is still context to write it with.

**Handing off** — actually ending the session — is the rarer decision, taken only
when a fresh session is genuinely cheaper than a compacted one, and never
mid-stage. Auto-compaction is automatic and keeps the session alive, so the run
will not die; what compaction costs you is *detail*, chosen by a summariser rather
than by you. That is what this doc defends against.

## What to write

Write a scratch handover doc (do not commit it) at a stable path — prefer
`<primary-repo>/.vicaris/handover-<branch>.md` (create `.vicaris/` if absent; it
is scratch) or the session scratchpad. Keep it dense and factual:

- **Task** — the goal and acceptance criteria, and the Jira key / branch. Point at
  `<primary-repo>/.vicaris/understanding-<branch>.md` rather than restating it; the
  rejected readings in it are what stop a resumed session re-deciding a criterion
  differently from the first one.
- **Risk class** — the line from `<primary-repo>/.vicaris/risk-<branch>.txt`, and
  whether the gate's observed check has raised it yet. Every stage branches on this,
  so a session that resumes without it runs either too much ceremony or too little,
  and the second failure is silent.
- **Repos in scope** — every repo in the manifest
  (`<primary-repo>/.vicaris/repos-<branch>.txt`, see
  `${CLAUDE_PLUGIN_ROOT}/references/multi-repo.md`), in dependency order, each
  with its branch, whether it is branched yet, its verify result, and whether it
  has an MR. Losing a sibling repo across the session boundary is the easiest way
  for half a change to be abandoned, so make this list explicit even when the
  manifest exists.
- **Stage** — where in plan → design → challenge → implement → review → test →
  finalize things are,
  and **per repo** where they differ.
- **Done** — what's implemented and verified, with the verify result.
- **In flight** — the exact next action, mid-edit files (repo-qualified), and any
  partial state.
- **Decisions + assumptions** — every fork resolved so far and the assumption
  behind it, so the next session doesn't re-litigate. Include the cross-repo
  contract and any required merge order. For the per-repo reasoning, point at each
  repo's own `.vicaris/design-notes-<branch>.md` rather than restating it: the
  design and simplification notes `implement` leaves beside each repo's code
  already hold the rejected alternatives and why they lost, which is the part a
  summariser drops first and the part the next session most needs. List the paths,
  one per repo, so none is lost with the session. Point at
  `<primary-repo>/.vicaris/design-challenge-<branch>.md` the same way, and say
  whether the challenge has run yet — a resumed session that re-runs it wastes two
  agents, and one that skips it because nobody said loses the only pass that
  questions the approach.
- **Open items** — review findings not yet fixed (repo-qualified), tests not yet
  added, anything parked. Point at `<primary>/.vicaris/fix-ledger-<branch>.md` and
  **say which fix pass each loop is on**. The caps are two passes
  (`${CLAUDE_PLUGIN_ROOT}/references/gates.md`), and a cap a compaction can reset to
  zero is not a cap.
- **Environment** — every repo path and branch, stack/SSO state, whether
  `caffeinate` is running, relevant PIDs.
- **Resume command** — the exact `/vicaris` (or stage) invocation to continue.

## Hand off

**Ping Slack** (threaded under the run's parent message, per
`${CLAUDE_PLUGIN_ROOT}/references/notifications.md`): that the session is handing
over, the stage it reached, and the doc path. Without this a handover is
indistinguishable from the run dying silently, which is the worst thing an
unattended run can look like.

Print the handover path and the one-line resume instruction. If this is an
autonomous run, the orchestrator ends the current session cleanly; the next
session is started from the handover doc and continues without manual
intervention beyond launching it.
