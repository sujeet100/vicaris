# Slack notifications

An autonomous run is unattended by design, so Slack is the only window into it.
The old rule — ping after browser testing and at completion — meant a run could go
an hour or more with no signal at all, and a run that stalled looked identical to a
run that was working. Progress pings fix that.

Two hard rules: **send and keep working** (never wait for a reply, never treat a
ping as a question), and **stay terse** (one or two lines; the completion doc holds
the detail).

## One thread per run

The first ping is the parent message; everything else is a reply to it, so the DM
stays one readable conversation instead of a scattering of updates. Capture the
parent's `ts` and persist it, because sub-stages and resumed sessions need it too:

```
<primary-repo>/.vicaris/slack-thread-<branch>.txt
```

Every later ping passes that value as `thread_ts`. If the file is missing (a stage
run standalone), just post un-threaded rather than skipping the ping. The final
wrap-up also sets `reply_broadcast: true` so the outcome surfaces in the DM list
rather than staying buried in the thread.

## The milestones

Ping at **every** milestone below. The point is not the content of any single
message, it's the drumbeat: the owner should be able to tell from their phone that real
progress is happening, and notice when it stops.

| Milestone | Content |
|---|---|
| **Understanding done** | Ticket + one-line goal, repos in scope, branch, risk class, and **the two to four acceptance criteria whose reading could be wrong, each with the reading taken**, closing with "proceeding on this reading". **This is the parent message** — post it as soon as the understanding lands and the repo set is pinned. It blocks nothing, and it is the only point in the run where a human can correct a misread criterion while correcting it is still free |
| **Risk raised at the gate** | Only when `vicaris-risk.sh` raised the class from what was predicted: the old class, the new one, the path that triggered it, and what now runs that would not have |
| **Design decided** | Only when the design challenge found something: the decision, the alternative that lost, and one line on what it would have cost. Skip it when the challenge was skipped or came back clean — this is the one ping worth reading closely, and padding it with "nothing found" is how it stops being read |
| **Implementation done, per repo** | One reply *per repo as it finishes* (`service-api (1/2) done — filter aggregation, 41 tests green`), not one summary at the end. On a multi-repo change this is the main proof of forward motion |
| **Review started** | That the three reviewers are running, and over which repos |
| **Review findings** | Counts by severity, plus the headline of anything non-trivial |
| **Review comments resolved** | What was fixed and that verify is green again. If a loop hits its two-pass cap, say so with what is outstanding — a capped loop is a decision the owner should see while it is being made, not read about in the completion doc |
| **Testing started** | Units first, then whether the browser pass is happening or is being skipped (and why) |
| **Testing done** | What was tested, what worked, what didn't, evidence for failures |
| **MR raised, per repo** | The MR link as each one goes up, rather than all of them at the end |
| **MR review done, per MR** | The bot's verdict per MR, and what you fixed in response |
| **Handover written** | That the session is handing over, and the doc path — otherwise a handover is indistinguishable from a silent death |
| **Run complete** | Every MR link + review result, merge order if it matters, completion-doc path. `reply_broadcast: true` |
| **Any blocker, any time** | What's blocked and what you're doing instead. Never a question |

Skipping a ping because "the next one is coming soon" defeats the point: the value
is knowing the run is *alive*, which is exactly what a missing ping can't tell you.
A long stage with no ping is the thing to avoid — if a single stage is going to run
for a while (a big implement, a slow eval), say so when it starts.

## What never goes to Slack

- **Questions.** Slack is one-way here. A ping that asks for a decision is the
  blocking-question failure wearing a different hat.
- **Secrets.** Never a password, token, or credential, and no secrets in link
  query params.
- **Walls of text.** No diffs, no full findings lists, no stack traces. Link or
  cite the path instead.
- **AI-writing tells.** Draft anything the owner reads in their own voice (the
  `my-voice` skill in the `byline` plugin, if installed). Status pings stay
  clipped and factual; that's fine and expected.
