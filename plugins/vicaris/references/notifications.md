# Slack notifications

Slack is the only window into an unattended run. Two hard rules: **send and keep working**
(never wait for a reply, never treat a ping as a question), and **stay terse** (one
or two lines; the completion doc holds the detail).

## One thread per run

The first ping is the parent message; everything else replies to it. Persist the
parent's `ts` for sub-stages and resumed sessions:

```
<primary-repo>/.vicaris/slack-thread-<branch>.txt
```

Every later ping passes that value as `thread_ts`. If the file is missing (a stage
run standalone), post un-threaded rather than skipping the ping. The final wrap-up
also sets `reply_broadcast: true` so the outcome surfaces in the DM list.

## The milestones

Ping at **every** milestone below, so a stalled run is noticeable.

| Milestone | Content |
|---|---|
| **Understanding done** | Ticket + one-line goal, repos in scope, branch, risk class, and **the two to four acceptance criteria whose reading could be wrong, each with the reading taken**, closing with "proceeding on this reading". **This is the parent message** — post it once the understanding lands and the repo set is pinned. It blocks nothing, and it is the one point where a misread criterion is still free to correct, so never hold it back |
| **Risk raised at the gate** | Only when `vicaris-risk.sh` raised the class from what was predicted: the old class, the new one, the path that triggered it, and what now runs that would not have |
| **Design decided** | Only when the design challenge found something: the decision, the alternative that lost, and one line on what it would have cost. Skip it when the challenge was skipped or came back clean |
| **Implementation done, per repo** | One reply *per repo as it finishes* (`service-api (1/2) done — filter aggregation, 41 tests green`), not one summary at the end |
| **Review started** | That the three reviewers are running, and over which repos |
| **Review findings** | Counts by severity, plus the headline of anything non-trivial |
| **Review comments resolved** | What was fixed and that verify is green again. If anything is still outstanding after the fix pass, say what |
| **Testing started** | Units first, then whether the browser pass is happening or is being skipped (and why) |
| **Testing done** | What was tested, what worked, what didn't, evidence for failures |
| **MR raised, per repo** | The MR link as each one goes up, rather than all of them at the end |
| **MR review done, per MR** | The bot's verdict per MR, and what you fixed in response |
| **Handover written** | That the session is handing over, and the doc path |
| **Run complete** | Every MR link + review result, merge order if it matters, completion-doc path. `reply_broadcast: true` |
| **Any blocker, any time** | What's blocked and what you're doing instead. Never a question |

Never skip a ping because the next one is coming soon. If a single stage will run
for a while (a big implement, a slow eval), say so when it starts.

## What never goes to Slack

- **Questions.** Slack is one-way here; a ping that asks for a decision is the
  blocking-question failure in another form.
- **Secrets.** Never a password, token, or credential, and no secrets in link
  query params.
- **Walls of text.** No diffs, no full findings lists, no stack traces. Link or
  cite the path instead.
- **AI-writing tells.** Draft anything the owner reads in their own voice (the
  `my-voice` skill in the `byline` plugin, if installed). Status pings stay
  clipped and factual.
