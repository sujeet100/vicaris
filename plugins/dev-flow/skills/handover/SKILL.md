---
name: handover
description: Write a handover document when the session context is getting full (~50%), so a fresh session can resume the work with no loss of state. Autonomous runs invoke this themselves before context exhaustion.
argument-hint: [optional note on where things stand]
allowed-tools: Bash, Read, Write, Glob, Grep, mcp__claude_ai_Slack__slack_send_message
---

# Handover

Capture enough state that a new session resumes seamlessly. A long autonomous
run must not die of context exhaustion mid-task — write this **before** context
runs out (target ~50% usage), then the next session starts from it.

## When to trigger

- Context usage crosses ~50%, or
- A natural stage boundary is reached and remaining work is large, or
- The orchestrator decides a fresh session is cheaper than continuing.

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
