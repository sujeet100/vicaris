---
name: understand
description: Establish what a change has to be true of before anyone designs or builds it — acceptance criteria with the readings rejected, contradictions and gaps in the story, the repos in scope and the contract between them, the non-functional constraints, and the risk class that decides how much ceremony the rest of the run earns. Replaces the old plan stage. Runs on fable.
argument-hint: [Jira key, task description, or feature brief]
allowed-tools: Bash, Read, Write, Glob, Grep, Agent, mcp__claude_ai_Atlassian__getJiraIssue, mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql, mcp__claude_ai_Atlassian__getJiraIssueRemoteIssueLinks, mcp__claude_ai_Atlassian__getConfluencePage, mcp__claude_ai_Atlassian__searchConfluenceUsingCql, mcp__claude_ai_Atlassian__getPagesInConfluenceSpace, mcp__claude_ai_Atlassian__getConfluencePageDescendants, mcp__claude_ai_Atlassian__getConfluenceSpaces
---

# Understand

Establish what `$ARGUMENTS` has to be true of, and how much ceremony the rest of
the run earns. This stage reads and decides; it does not design and it does not
edit code.

The design used to live here, and it moved for a reason worth knowing: the plan
settled an approach, then `implement` re-decided the shape at the keyboard
because that is where the shape is actually chosen, and the plan's file list was
stale by the second slice. What the plan was uniquely good at was the part
nothing else does — reading the story properly, finding what it fails to say,
and naming the repos. That is this stage. The shape is decided in `implement`
Step 2b and challenged in `design-challenge`.

**Model:** fable, high reasoning effort. The orchestrator spawns this stage with
`model: fable`; running `/understand` directly on another model should delegate
to a fable sub-agent, because reading a story closely is exactly the work the
planning model is cheap and good at.

## Step 1 — Load the bar

Read, in this order: `${CLAUDE_PLUGIN_ROOT}/references/coding-principles.md`,
`${CLAUDE_PLUGIN_ROOT}/references/risk-classes.md` (this stage sets the class
every later stage reads), `${CLAUDE_PLUGIN_ROOT}/references/multi-repo.md`,
`${CLAUDE_PLUGIN_ROOT}/references/project-context.md` if present, and the
project's own `CLAUDE.md` and convention docs.

## Step 2 — Establish what has to be true

If `$ARGUMENTS` is a Jira key, fetch the story. Then **follow it out to
Confluence**: check the issue's remote links and its description for pages, and
read the ones that bear on this change. The story is usually the thinnest
statement of the requirement and the page is where the reasoning lives, so a
change built on the ticket alone re-derives decisions the team already made.
Search by the ticket key and the feature name when nothing is linked.

Then read the code the change touches — the seams, the domain, the current
behaviour — before concluding anything about what is being asked.

Produce the acceptance criteria as a **numbered list**, each one a statement
that is either true or false of the finished system. Quote the ones the story
states. Say so, and say from what, for the ones you derived.

**For every criterion that admits more than one reading, write the reading you
are taking and the reading you are rejecting, one line each.** This is the most
valuable thing this stage produces and it is not hedging. Nothing downstream can
ask a question, so a misread criterion is invisible until the completion doc,
by which point acting on it costs a rework. A rejected reading sitting next to
the chosen one is what lets a human scan the Slack message and catch the
misunderstanding in ten seconds instead.

Then, in their own short sections:

- **Contradictions** — any two criteria that cannot both hold, or a criterion
  the current code already contradicts. Name both sides and say which you are
  proceeding on.
- **Gaps** — what the story does not say that the implementation must decide
  anyway: empty states, limits, permissions, ordering, what happens to data that
  already exists, what the user sees when it fails.
- **Sources** — every Confluence page and code path you used. "None found" is an
  answer; leaving it ambiguous whether you looked is not.

## Step 3 — Non-functional constraints

Answer only the rows that apply to this change. One line each; `n/a` plus the
reason is an answer, a blank is a finding. These answers feed Step 4 directly,
which is why they come before it rather than after.

| The change touches… | State |
|---|---|
| Persisted data or a schema | The migration, whether it reverses, and what happens to rows written by the old code during the deploy window |
| An API or event another component consumes | Who consumes it today, and whether old and new can coexist for one release |
| Authentication, authorisation or tenancy | The rule being changed, who gains access, and the test that proves nobody else did |
| Money, billing or quantities | The unit, the rounding, and the idempotency of anything retryable |
| Concurrency or shared state | The shared thing, and the interleaving that must not lose a write |
| A new dependency | What it replaces, its size and licence, and what writing it ourselves would cost |
| User-visible behaviour | Before and after, and whether anything existing breaks |
| Performance on a hot path | The current cost, the expected cost, and how you would know if it regressed |
| Anything with a blast radius | How this is turned off without a deploy |

## Step 4 — Classify the risk, and write it down

Read `references/risk-classes.md` and emit exactly one class:
`mechanical`, `tiny`, `normal`, `elevated` or `production`. Write it to the file
every later stage reads:

```bash
PRIMARY=$(git rev-parse --show-toplevel); BRANCH=$(git rev-parse --abbrev-ref HEAD)
mkdir -p "$PRIMARY/.dev-flow"
cat > "$PRIMARY/.dev-flow/risk-$BRANCH.txt" <<EOF
RISK: <class> · tags: <schema,authz,money,concurrency,infra,dependency,public-contract,prompt or none>
why: <one line — the trigger that set it>
EOF
```

Two habits keep this honest. **Default upward** when a change sits between two
classes: one extra review pass is cheaper than the one that was skipped. And
**say `mechanical` only when you can point at the instances the change copies** —
that class exists for a change that repeats a shape already in the repo, and it
buys a parity check instead of a craft pass, so claiming it for a change that
introduces a new concept removes the review that would have caught it.

The class is checked again after implementation, deterministically, from the
paths actually touched (`scripts/dev-flow-risk.sh`), and that check can only
raise it. So a prediction that is slightly low is recoverable; one that is
confidently low and never revisited is not.

## Step 5 — Repos in scope

List every repo the change reads from or touches, in **dependency order**,
producer before consumer, each with its freshness (`current` /
`behind, not synced because …`):

```bash
git fetch --prune origin && git status -sb   # look for "behind"
```

This list becomes the manifest every later stage fans out over, so a repo you
omit gets no branch, no review and no MR. Where the change spans repos, state
the **contract** between them and whether the MRs can merge in any order. Don't
design the contract here — name that it exists, who owns it, and what it has to
carry. Its shape is settled in `implement` Step 2b, where both sides are in view.

If a repo is behind and you cannot bring it current, say so rather than reasoning
about code you have not read.

## Step 6 — The test surface

Name the tests the change needs, **derived from the acceptance criteria and the
failure modes in Step 3, not from the design**. This ordering is the whole point:
tests written after the implementation, by the pass that wrote it, tend to assert
what the code does rather than what the story asked for, and a test pinned to a
criterion survives the implementation changing shape.

One line each. Where a criterion cannot be tested, say why — that is usually a
sign the criterion is not yet a statement that can be false.

## Step 7 — Emit the understanding

Write `<primary-repo>/.dev-flow/understanding-<branch>.md`. Both hooks look
there, so a resumed or compacted session finds it. Scratch — don't commit it,
don't cite it in a commit message.

Sections, in this order: Goal · Acceptance criteria with rejected readings ·
Contradictions · Gaps · Non-functional constraints · Risk class and why · Repos
in scope, contract, merge order · Test surface · Sources.

**Do not list the files to change.** That list is stale by the second slice, it
locks the implementation before the design stage has run, and its absence has
never once cost a run anything.

Keep it short and scannable. The orchestrator posts the acceptance criteria, the
assumptions that could be wrong, and the risk class as the run's opening Slack
message, so this document is written to be read by someone deciding in fifteen
seconds whether the run has understood the job.
