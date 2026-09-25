# Delegation — what runs in the orchestrator, and what does not

The orchestrator's context is the run's most expensive resource, because every call
it makes re-reads all of it. Measured on real runs, the main session made 300–400
calls while its context grew to 600–750k, and those re-reads were 60–90% of the
run's spend; the sub-agents, even 27 of them, cost less. So anything added to the
orchestrator early is paid again on every call after it, and a stage that works
inline at high context is the costliest thing a run can do.

The rule that follows: **the orchestrator sequences, decides and fans out; every
stage that reads code, edits it, runs it or drives a browser runs in one sub-agent
with an explicit model.** It keeps paths, the risk class, the manifest and each
sub-agent's short report, and reads results from the files a stage writes rather
than from its summary.

## Where each stage runs

| Stage | Runs in | Model |
|---|---|---|
| `understand` | sub-agent | opus |
| Design (`implement` Steps 1–2b) | sub-agent | opus |
| `design-challenge` | orchestrator — it spawns the blind designer and the comparer | fable, opus |
| Build (`implement` Steps 3–6b) | sub-agent | the class's build model |
| `adversarial-review` | orchestrator — `review-changes` spawns its reviewers | opus |
| Deciding findings and divergences | orchestrator | opus |
| Fix pass (review, test, MR review) | sub-agent, one per pass | the class's build model |
| `test` | sub-agent | the class's build model |
| `finalize` | orchestrator — its fix loop re-enters review | opus |

The build model per class is in `risk-classes.md`: sonnet at `mechanical`, `tiny`
and `normal`, opus at `elevated` and `production`. The orchestrator itself stays on
opus, since it makes the calls that need the whole run in view.

**A sub-agent cannot spawn sub-agents**, which is why the stages that fan out stay
in the orchestrator. Never give one a stage that does.

**Never `fork`.** A fork inherits the parent's model and its whole context, which is
both of the costs this file exists to avoid. Use `subagent_type: general-purpose`
with `model:` set, unless the stage names a shipped agent.

## What every stage sub-agent's prompt carries

A sub-agent starts empty and reads skills as files, so its placeholders are not
filled in. Give it facts and paths, never content it can read itself:

- the skill path and the steps to run, in auto mode;
- the owner's name and Slack member ID as plain text, and the Slack thread ts from
  `<primary>/.vicaris/slack-thread-<branch>.txt`, so its pings thread correctly;
- the manifest path, the branch, the dependency order and the risk class;
- the artifacts the stage builds on — understanding, design notes, fix ledger,
  verify files — by path;
- where to write its result, and that its report back is a few lines: what it did,
  per repo, and anything it could not do.

When it returns, check the files it was meant to write, not its report. A stage that
came back red or with an unexplained departure goes to a fresh fix sub-agent with
the failure, never to an inline repair in the orchestrator.

## Waiting is not work

Never poll from the orchestrator. A check on a pipeline, an eval job or a slow
command re-reads the whole context to learn "still running". Wait with one
background loop instead — `Bash` with `run_in_background: true` running an `until`
over the status command, or the Monitor tool — and act when it notifies. When
reading the result needs judgement, such as an eval that moved, hand the job's
output to a short sub-agent rather than pulling it into the orchestrator.
