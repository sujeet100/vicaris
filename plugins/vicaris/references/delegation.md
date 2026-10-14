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
| Orchestrator | the main session, set by the `vicaris` skill | Opus 5.5 · medium |
| `understand` | `analyst` | Opus 5.5 · medium |
| Design and its challenge (`implement` Steps 1–2c) | `lead`, which spawns the blind designer and the comparer | Opus 5.5 · high; `blind-designer` Fable 5.1 · high; comparer `lead` |
| Build (`implement` Steps 3–6b) | `builder`, one per `change` repo, in dependency order | Sonnet 5.5 · high |
| Review runs, one `review-changes` per repo | `review-runner`, spawned by the orchestrator | Sonnet 5.5 · medium; the passes it launches pin their own |
| Deciding the review's findings | `lead`, spawned by the orchestrator once every reviewer has reported | Opus 5.5 · high |
| Fix pass (review, MR review) | `builder`, one per repo, spawned by the orchestrator | Sonnet 5.5 · high |
| Fix pass (test) | `builder`, spawned by the test stage | Sonnet 5.5 · high |
| Acceptance-criteria pass | `acceptance-criteria` | Sonnet 5.5 · high |
| `test` | `builder` | Sonnet 5.5 · high |
| Repair of a stage that came back red | `builder-opus` | Opus 5.5 · high |
| Answering a builder's decision request | a short `lead`, spawned by the orchestrator | Opus 5.5 · high |
| `finalize` publish (Step 1) and wrap (Steps 4–7) | `builder`, one for each | Sonnet 5.5 · high |
| Pipelines, evals and the MR reviewers (`finalize` Steps 2–3) | the orchestrator, through `vicaris-wait.sh` | — |
| Deciding the MR review's findings (`finalize` Step 3) | a short `lead`, spawned by the orchestrator | Opus 5.5 · high |

**Opus decides, Sonnet builds.** Every execution stage runs on `builder` (Sonnet
5.5) at every risk class, because what it executes was decided on Opus
(`risk-classes.md`, *Build model*). Where the build reaches a choice that was not
decided, it files a decision request rather than deciding, and the orchestrator has
a short `lead` answer it. `builder-opus` (Opus 5.5) only repairs a stage that came
back red or departed from its note. Pass no `model:` at the call: every
definition pins a full model ID, and an alias passed at the call would override it.

**Models are pinned by full ID, never by alias.** The aliases mean different models
on different providers: on the Anthropic API `sonnet` is Sonnet 5.5, but on Bedrock
and Google Cloud it is Sonnet 4.5, and on Foundry `opus` is Opus 4.6. So every agent
names `claude-opus-5-5`, `claude-sonnet-5-5` or `claude-fable-5-1`, and moving to a
new generation is a deliberate edit to `agents/`, with the effort levels below
re-checked, since each generation recalibrates them.

**Effort lives in the agent definitions**, because the effort of a plain
`general-purpose` spawn is undocumented. The orchestrator runs at medium: Opus 5.5
at medium beats Opus 5 at high, it thinks more per turn at any level than its
predecessor, and most orchestrator calls sequence rather than judge. Understand runs
at medium too: it reads and classifies more than it weighs alternatives, and Opus
5.5 at medium still beats Opus 5 at high. The stages that weigh designs and findings
run at high, and so does the build, where high is Sonnet 5.5's default.

**Sub-agents can spawn sub-agents**, three levels below the main session by default
(Claude Code 2.1.219 and later; `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` raises it).
The deepest chain in a run is the orchestrator → a `review-runner` → the passes it
launches, or design → the challenge's two agents, which fits. On a Claude Code that cannot nest, run design, review and
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
came back red or with an unexplained departure goes to a fresh `builder-opus` with the failure, never to an inline repair in the orchestrator.

## Waiting is not work, and it belongs to the orchestrator

A wait costs whatever context resumes after it. An agent idle past the five-minute
prompt cache rewrites its whole context on its next call: on one run the review
lead did that three times at 260–290K tokens and the finalize lead twice at
200–250K, about $9 of a $104 run spent on nothing happening. So no stage agent
waits. Every spawn that is followed by a wait (reviewers, the fix pass, pipelines, the
MR reviewers) is made by the orchestrator, and each agent starts with its inputs on
disk, does its part, and returns.

That does not make the orchestrator's context the place for the work. What it gains
from holding the waits is a spawn, a one-line wait result and a short report each,
never a diff, a review or a log: those go to files, and a `lead` reads them.

- **Waiting on agents:** spawn them in one message and in the foreground
  (`run_in_background: false` where the Agent tool offers it), and act when they
  return.
- **Waiting on anything else:** `scripts/vicaris-wait.sh`, in the foreground. It
  blocks up to nine minutes per call, polls without printing, and returns one line
  per thing waited for; call it again on exit 124. `start` runs a slow command
  detached, `files` waits for it, `pipeline` waits for GitLab pipelines or named
  jobs.
- **Never a background loop or Monitor for a run's waits.** Either ends the turn,
  and the notification that resumes it starts a new turn on the session's own model,
  not the orchestrator's pinned one.
- **Never poll from a model.** Each check re-reads the context to learn "still
  running"; the script's loop re-reads nothing.

When reading a result needs judgement, such as an eval that moved, hand the file
the script wrote to a short `lead` rather than pulling it into the orchestrator.
