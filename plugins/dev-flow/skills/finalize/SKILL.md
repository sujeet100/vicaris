---
name: finalize
description: Wrap up a completed task — generate the completion document (summary of changes, assumptions with alternatives and reasons, testing notes), run the standalone MR reviewer, and post a Slack summary to Sujit.
argument-hint: [optional MR URL or project/iid for the MR review]
allowed-tools: Bash, Read, Write, Glob, Grep, mcp__claude_ai_Slack__slack_send_message
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
it in one place. Scannable sections:

- **Summary of changes** — what was built, which files/modules, and why, keyed
  to the acceptance criteria. Note the verify result and tests added. Group it
  **by repo**, and where the change spans repos, describe the contract between
  them and the required merge order (or state that the MRs can land in any
  order, if the change was designed to be backward compatible).
- **Assumptions** — every meaningful decision, each with the **alternatives
  considered** and the **reason** the chosen option won. This is the record
  Sujit reviews the implementation against, so be explicit and honest about
  tradeoffs and anything he might want to revisit.
- **Testing notes** — what was tested (unit + browser + traces/logs), what
  worked, and what didn't (with evidence). Carry over the testing results from
  the test stage verbatim rather than re-summarising loosely.

Before saving, run the `de-ai` pass over the doc's prose (see the `de-ai`
skill and `references/de-ai-guide.md`): flowing connected sentences, no em
dashes, no "it's not X, it's Y," no forced trios, no puffery.

## Step 2 — Create + announce an MR for every repo

Walk the manifest and create (or refresh) an MR **in each repo that has commits
on the branch**, via the project's MR flow. Every one of them:

- carries the **same Jira key** in title and description;
- **cross-links the sibling MRs** ("part of PROJ-1234, with <other MR>"), so a
  reviewer landing on one knows the rest exist and can't approve half a contract
  change blind;
- states the **merge order** if the MRs can't land in any order.

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

The reviewer sees one MR at a time, so it cannot judge the seam between them —
that gap is what Step 3 of `adversarial-review` covers, and it stays your
responsibility here. Don't read N clean single-MR reviews as a clean review of
the whole change.

Ping the thread with each MR's verdict as it comes back, and again once you've
resolved its comments.

Feed any blocker/should-fix findings back through implement → review → test,
applying each in the repo it belongs to and re-running that repo's verify plus the
integrated path. In an autonomous run, apply the fixes and re-review rather than
stopping — only genuine external blockers pause the run.

## Step 4 — Slack summary (DM to Sujit)

Post the wrap-up to the Slack target (default self-DM) via
`mcp__claude_ai_Slack__slack_send_message`: what shipped, the assumptions worth
his eyes, the testing outcome, and **every MR link with its review result** (plus
the merge order, if it matters). Thread it under the run's parent message with
`reply_broadcast: true` so the outcome surfaces in the DM list instead of staying
buried in the thread (`references/notifications.md`). Draft it in Sujit's voice
(see `my-voice`); keep it tight.

## Step 5 — Stop keep-awake

If the orchestrator started `caffeinate`, stop it now
(`pkill -f 'caffeinate -dimsu'` for the one this run started, or kill the
recorded PID).

## Step 6 — Point at the doc

Print the completion-doc path and **every** MR link so Sujit has one place to
review everything. Close with an explicit per-repo checklist — repo, MR, MR-review
result, verify result — so a repo that fell out of the run somewhere is visible at
a glance rather than assumed covered.
