---
name: test
description: Verify a change end to end — reuse the gate's unit results, browser-test anything user-visible, check logs and traces, report in Slack.
argument-hint: [what to exercise, or the feature under test]
allowed-tools: Bash, Read, Glob, Grep, mcp__claude_ai_Slack__slack_send_message, mcp__plugin_chrome-devtools-mcp_chrome-devtools__navigate_page, mcp__plugin_chrome-devtools-mcp_chrome-devtools__new_page, mcp__plugin_chrome-devtools-mcp_chrome-devtools__take_snapshot, mcp__plugin_chrome-devtools-mcp_chrome-devtools__take_screenshot, mcp__plugin_chrome-devtools-mcp_chrome-devtools__click, mcp__plugin_chrome-devtools-mcp_chrome-devtools__fill, mcp__plugin_chrome-devtools-mcp_chrome-devtools__fill_form, mcp__plugin_chrome-devtools-mcp_chrome-devtools__wait_for, mcp__plugin_chrome-devtools-mcp_chrome-devtools__list_console_messages, mcp__plugin_chrome-devtools-mcp_chrome-devtools__list_network_requests, mcp__plugin_chrome-devtools-mcp_chrome-devtools__evaluate_script, mcp__claude_ai_Atlassian__getJiraIssue, mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql, mcp__claude_ai_Atlassian__getJiraIssueRemoteIssueLinks, mcp__claude_ai_Atlassian__getConfluencePage, mcp__claude_ai_Atlassian__searchConfluenceUsingCql, mcp__claude_ai_Atlassian__getPagesInConfluenceSpace, mcp__claude_ai_Atlassian__getConfluencePageDescendants, mcp__claude_ai_Atlassian__getConfluenceSpaces
---

# Test

**Owner:** ${user_config.owner_name}, the person this run acts for ("the owner" here
and in the references). Slack goes to member `${user_config.slack_user_id}`, else the
sidecar's Slack target, else record Slack as unavailable in the degraded list.

Read `${CLAUDE_PLUGIN_ROOT}/references/project-context.md` first (verify command,
app + login, SSO, observability); with no sidecar, do the unit step only. Skip a plugin reference only if it is already in your context (the orchestrator's
Step 0 loads them in its own session; a sub-agent has not seen them).

## Step 1 — Fast unit suite, in every repo

**Ping Slack that testing has started** (`references/notifications.md`), saying
whether a browser pass will run and why. Load the repo set per
`references/multi-repo.md`.

**Check each `change` repo's recorded verify rather than re-running its suite.**
`--check` compares the recorded result's fingerprint with the tree as it stands, so
it tells you whether a fix pass moved the code since; re-run only a repo it reports
as failing or stale:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/vicaris-gate.sh" --check "$repo" \
  || bash "${CLAUDE_PLUGIN_ROOT}/scripts/vicaris-gate.sh" "$repo" "$VERIFY_CMD"
```

With no verify command in the sidecar, use the project's standard unit tests.
Don't run eval or integration suites.

## Step 2 — Is the app worth driving?

The risk class decides (`references/risk-classes.md`); a backend-only change
fully covered by units skips to Step 6. **A change spanning repos always earns a
run through the app**, on a local stack running the branch build of every repo in
the set, not a stale or released artifact.

## Step 3 — SSO / stack readiness

- Check whether SSO is already valid (per the sidecar, e.g.
  `aws sts get-caller-identity`). **If valid, skip re-auth.**
- Start / confirm the local stack per the sidecar.
- If SSO is expired or needs interactive login, **don't attempt it.** Send the
  Step 7 "blocked" DM, **continue with everything that doesn't need the stack**,
  and record the browser step as blocked. Don't spin waiting.

## Step 4 — Log in (no secret through the assistant)

Follow the sidecar's login section. **Never read, type, echo, or otherwise route
the password through your context** — trufflehog hooks block it, intentionally.

- **Primary:** navigate to the login page, enter the username, focus the password
  field, accept Chrome's saved-password autofill, then submit.
- **Fallback (only with the owner's prior sign-off):** the keychain→keystroke
  helper at `${CLAUDE_PLUGIN_ROOT}/scripts/browser-login-helper.sh` (configured via
  the env vars in the sidecar), which injects the password into the focused field
  without printing it.

## Step 5 — Exercise the feature

Drive the affected flows in the browser, snapshotting key states and
capturing console and network on any failure. Note what you did so it's
reproducible.

## Step 6 — Logs and traces

Check service logs and traces (per the sidecar) for those requests, confirming
end-to-end behaviour and capturing evidence for anything wrong.

## Step 7 — Slack summary (DM to the owner)

Post to the Slack target (default: self-DM) via
`mcp__claude_ai_Slack__slack_send_message`, threaded under the run's parent
message (`references/notifications.md`). Two variants:

- **Blocked:** one terse line — what's blocked and that it needs SSO / their input.
- **Results:** what was tested, worked and failed (with evidence); for a
  multi-repo change, units **per repo** plus the integrated result. Owner's voice
  (see `my-voice`), scannable.

## Step 8 — Fix and re-test

**Capped at two passes**, each outcome in
`<primary>/.vicaris/fix-ledger-<branch>.md` (`references/gates.md`); at the cap,
carry it as outstanding into the completion doc and the MR.

Fix in **the repo the fault lives in**. For a cross-repo failure, the design notes
settle which side is wrong: the side that departs from the contract they describe is
the one to fix, never the easier one to patch. Where the notes do not describe that
part of the contract, or describe it in a way the failure shows is wrong, the side
is a design decision: file a decision request
(`<primary>/.vicaris/decision-requests-<branch>.md`, format in the builder agent's
definition), carry on with the rest, and report it. Re-run that repo's gate and the
integrated path, and update the Slack thread.
