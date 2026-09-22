---
name: test
description: Verify a change end-to-end — fast unit suite plus real browser testing of the app, checking logs and traces — then post a Slack summary of what was tested, what worked, and what didn't. Sends a Slack ping if blocked on SSO.
argument-hint: [what to exercise, or the feature under test]
allowed-tools: Bash, Read, Glob, Grep, mcp__claude_ai_Slack__slack_send_message, mcp__plugin_chrome-devtools-mcp_chrome-devtools__navigate_page, mcp__plugin_chrome-devtools-mcp_chrome-devtools__new_page, mcp__plugin_chrome-devtools-mcp_chrome-devtools__take_snapshot, mcp__plugin_chrome-devtools-mcp_chrome-devtools__take_screenshot, mcp__plugin_chrome-devtools-mcp_chrome-devtools__click, mcp__plugin_chrome-devtools-mcp_chrome-devtools__fill, mcp__plugin_chrome-devtools-mcp_chrome-devtools__fill_form, mcp__plugin_chrome-devtools-mcp_chrome-devtools__wait_for, mcp__plugin_chrome-devtools-mcp_chrome-devtools__list_console_messages, mcp__plugin_chrome-devtools-mcp_chrome-devtools__list_network_requests, mcp__plugin_chrome-devtools-mcp_chrome-devtools__evaluate_script, mcp__claude_ai_Atlassian__getJiraIssue, mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql, mcp__claude_ai_Atlassian__getJiraIssueRemoteIssueLinks, mcp__claude_ai_Atlassian__getConfluencePage, mcp__claude_ai_Atlassian__searchConfluenceUsingCql, mcp__claude_ai_Atlassian__getPagesInConfluenceSpace, mcp__claude_ai_Atlassian__getConfluencePageDescendants, mcp__claude_ai_Atlassian__getConfluenceSpaces
---

# Test

Verify the change for real. Read `${CLAUDE_PLUGIN_ROOT}/references/project-context.md`
first — it carries the verify command, the app + login details, SSO handling,
observability, and the Slack target. If no sidecar is present, do the unit-test
step and skip the app-specific steps.

## Step 1 — Fast unit suite, in every repo

**Ping Slack that testing has started** (`references/notifications.md`), naming
whether a browser pass is happening or being skipped and why — the browser leg is
slow, and an unannounced one looks like a stall.

Load the repo set per `${CLAUDE_PLUGIN_ROOT}/references/multi-repo.md` (manifest
at `<primary-repo>/.vicaris/repos-<branch>.txt`; no manifest means the current
repo alone).

**Read each repo's `.vicaris/verify-<branch>.txt` rather than re-running its
suite.** The gate before review already ran it and recorded a `RESULT:` line
(`${CLAUDE_PLUGIN_ROOT}/references/gates.md`). Re-run a repo only when its tree has
moved since — a fix pass touched it, or the file is missing or older than the last
commit — and then through the same script, so the record stays true:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/vicaris-gate.sh" "$repo" "$VERIFY_CMD"
```

Running a green suite twice is not free on a large repo, and it is the kind of
waste that looks like diligence. Fall back to the project's standard unit-test command where
the sidecar doesn't name one. Don't run eval or integration suites to verify.

## Step 2 — Is the app worth driving?

The risk class answers most of this before you look
(`${CLAUDE_PLUGIN_ROOT}/references/risk-classes.md`). `mechanical` skips the browser
leg — a field threaded through an existing pattern is proven by the parity check and
the unit suites, and driving a UI to watch it appear is an hour spent confirming a
grep. `tiny` and `normal` earn it when the change is user-visible. `elevated` and
`production` always get it.

Within that, if the change is backend-only and fully covered by units, note that and
skip to Step 6. If it has a user-visible effect, drive the real UI.

**A change spanning repos always earns a run through the app**, even when every
repo's units are green, because the units are exactly what can't see the seam
between them. Make sure the local stack is running the branch build of each repo
in the set, not a stale or released artifact — otherwise you are testing the old
producer against the new consumer and the result means nothing either way.

## Step 3 — SSO / stack readiness

- Check whether SSO is already valid (per the sidecar, e.g.
  `aws sts get-caller-identity`). **If valid, skip re-auth.**
- Start / confirm the local stack per the sidecar.
- If the stack can't come up because SSO is expired or interactive login is
  needed, **do not attempt an interactive login.** Send a Slack DM (Step 7
  format, "blocked" variant) asking Sujit to run SSO, then **continue with
  everything that doesn't need the stack** (unit results, static checks, code
  review of the UI change) and record the browser step as blocked in the
  summary. Don't spin waiting; the run finalizes with the browser step flagged.

## Step 4 — Log in (no secret through the assistant)

Follow the sidecar's login section. **Never read, type, echo, or otherwise
route the password through your context** — trufflehog hooks block it and that
is intentional.

- **Primary:** navigate to the login page, enter the username, focus the
  password field, and accept Chrome's saved-password autofill, then submit.
- **Fallback (only with Sujit's prior sign-off):** the keychain→keystroke
  helper at `${CLAUDE_PLUGIN_ROOT}/scripts/browser-login-helper.sh` (configured
  via the env vars in the sidecar), which injects the password into the focused
  field without printing it.

## Step 5 — Exercise the feature

Drive the real flows the change affects with the browser tools. Take snapshots
/ screenshots at the key states. On any failure, capture console messages and
network requests. Note exactly what you did so the summary is reproducible.

## Step 6 — Logs and traces

Inspect service logs and the tracing platform (per the sidecar) for the
requests you just made. Confirm the behaviour end-to-end, not just the UI
surface. If something looks wrong, capture the trace / log evidence.

## Step 7 — Slack summary (DM to Sujit)

Post to the Slack target in the sidecar (default: self-DM) via
`mcp__claude_ai_Slack__slack_send_message`, threaded under the run's parent
message per `references/notifications.md`. Two variants:

- **Blocked:** one terse line — what's blocked and that it needs SSO / his
  input.
- **Results:** what was tested, what worked, what didn't, and any trace/log
  evidence for failures. For a multi-repo change, list the unit result **per
  repo** plus the integrated end-to-end result, so a green line can't be mistaken
  for whole-change coverage. Draft this in Sujit's voice (see the `my-voice`
  skill); keep it scannable.

## Step 8 — Fix and re-test

**Capped at two passes**, like every loop in this workflow, with each outcome in
`<primary>/.vicaris/fix-ledger-<branch>.md`
(`${CLAUDE_PLUGIN_ROOT}/references/gates.md`). A third failure of the same thing is
telling you the implementation is wrong rather than incomplete; record it as
outstanding, carry it into the completion doc and the MR, and let a human see it
rather than patching toward green.

If something failed, make the fix (back through implement / review as needed) in
**whichever repo the fault lives in** — for a cross-repo failure decide whether
the producer or the consumer is wrong rather than patching whichever side is
easier to reach — then re-run that repo's verify and the integrated path. Update
the Slack thread with the outcome.
