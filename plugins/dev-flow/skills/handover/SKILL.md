---
name: handover
description: Write or refresh the handover document so a fresh session (or a compacted one) resumes the work with no loss of state. Autonomous runs refresh it at every stage boundary rather than trying to judge remaining context.
argument-hint: [optional note on where things stand]
allowed-tools: Bash, Read, Write, Glob, Grep, mcp__claude_ai_Slack__slack_send_message
---

# Handover

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
`<primary-repo>/.dev-flow/handover-<branch>.md` (create `.dev-flow/` if absent; it
is scratch) or the session scratchpad. Keep it dense and factual:

- **Task** — the goal and acceptance criteria, and the Jira key / branch.
- **Repos in scope** — every repo in the manifest
  (`<primary-repo>/.dev-flow/repos-<branch>.txt`, see
  `${CLAUDE_PLUGIN_ROOT}/references/multi-repo.md`), in dependency order, each
  with its branch, whether it is branched yet, its verify result, and whether it
  has an MR. Losing a sibling repo across the session boundary is the easiest way
  for half a change to be abandoned, so make this list explicit even when the
  manifest exists.
- **Stage** — where in plan → implement → review → test → finalize things are,
  and **per repo** where they differ.
- **Done** — what's implemented and verified, with the verify result.
- **In flight** — the exact next action, mid-edit files (repo-qualified), and any
  partial state.
- **Decisions + assumptions** — every fork resolved so far and the assumption
  behind it, so the next session doesn't re-litigate. Include the cross-repo
  contract and any required merge order.
- **Open items** — review findings not yet fixed (repo-qualified), tests not yet
  added, anything parked.
- **Environment** — every repo path and branch, stack/SSO state, whether
  `caffeinate` is running, relevant PIDs.
- **Resume command** — the exact `/dev-flow` (or stage) invocation to continue.

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
