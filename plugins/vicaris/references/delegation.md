# Delegation — what runs in the orchestrator, and what does not

The orchestrator's context is the run's most expensive resource, because every call
it makes re-reads all of it. Measured on real runs, the main session made 300–400
calls while its context grew to 600–750k, and those re-reads were 60–90% of the
run's spend; the sub-agents, even 27 of them, cost less. So anything added to the
orchestrator early is paid again on every call after it, and a stage that works
inline at high context is the costliest thing a run can do.

The rule that follows: **the orchestrator sequences and checks; every stage runs in
one sub-agent, on a shipped agent that fixes its model and effort.** The orchestrator
keeps paths, the risk class, the manifest and each stage's short report, runs the
gate and the handover, and reads results from the files a stage writes rather than
from its summary. The judgement — which divergences to adopt, which findings to fix —
happens inside the stage that owns it, on opus.

## Where each stage runs

| Stage | Agent | Model · effort |
|---|---|---|
| Orchestrator | the main session | opus · medium |
| `understand` | `analyst` | opus · medium |
| Design and its challenge (`implement` Steps 1–2c) | `lead`, which spawns the blind designer and the comparer | opus · high; `blind-designer` fable · high; comparer `lead` |
| Build (`implement` Steps 3–6b) | `builder` | the class's build model · high |
| `adversarial-review`, deciding its findings | `lead`, which spawns reviewers and fix passes | opus · high |
| Fix pass (review, test, MR review) | `builder`, spawned by the stage that found it | the class's build model · high |
| Acceptance-criteria pass | `acceptance-criteria` | sonnet · high |
| `test` | `builder` | the class's build model · high |
| `finalize` | `lead`, whose fix loop re-enters review | opus · high |

The build model per class is in `risk-classes.md`: sonnet at `mechanical`, `tiny`
and `normal`, opus at `elevated` and `production`. Pass it as `model:` when spawning
`builder`; the call's `model` overrides the definition's, and its `effort` stays.

**Effort lives in the agent definitions**, because the effort of a plain
`general-purpose` spawn is undocumented. The orchestrator runs at medium: Opus 5.5 at
medium beats Opus 5 at high, it thinks more per turn at any level than its
predecessor, and most orchestrator calls sequence rather than judge. Understand runs at medium too: it reads and classifies more than it weighs
alternatives, and Opus 5.5 at medium still beats Opus 5 at high. The stages
that weigh designs and findings run at high, and so does the build, where high is Sonnet 5's
recommended default.

**Sub-agents can spawn sub-agents**, three levels below the main session by default
(Claude Code 2.1.219 and later; `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` raises it).
The deepest chain in a run is `finalize` → the review it re-enters → that review's
reviewers, which fits. On a Claude Code that cannot nest, run design, review and
finalize in the orchestrator instead, and say so in the degraded list.

**Never `fork`.** A fork inherits the parent's model and its whole context, which is
both of the costs this file exists to avoid.

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
came back red or with an unexplained departure goes to a fresh `builder` on **opus**
with the failure, never to an inline repair in the orchestrator.

## Waiting is not work

Never poll from the orchestrator. A check on a pipeline, an eval job or a slow
command re-reads the whole context to learn "still running". Wait with one
background loop instead — `Bash` with `run_in_background: true` running an `until`
over the status command, or the Monitor tool — and act when it notifies. When
reading the result needs judgement, such as an eval that moved, hand the job's
output to a short `lead` rather than pulling it into the orchestrator.
