---
name: implement
description: Implement an approved plan in auto mode, writing to Sujit's coding principles — clean, small, typed, declarative, well-tested. Designs on opus; builds on sonnet through the normal risk class and on opus above it, at high effort.
argument-hint: [path to plan, or the task if planning already happened in-session]
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Skill, Agent, mcp__claude_ai_Slack__slack_send_message, mcp__claude_ai_Atlassian__getJiraIssue, mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql, mcp__claude_ai_Atlassian__getJiraIssueRemoteIssueLinks, mcp__claude_ai_Atlassian__getConfluencePage, mcp__claude_ai_Atlassian__searchConfluenceUsingCql, mcp__claude_ai_Atlassian__getPagesInConfluenceSpace, mcp__claude_ai_Atlassian__getConfluencePageDescendants, mcp__claude_ai_Atlassian__getConfluenceSpaces
---

# Implement

Build the change described by the plan (`$ARGUMENTS`, or the in-session plan).

**Model / mode:** high reasoning effort, **auto mode** — proceed through the
implementation without stopping for confirmation at each step. Stop only for a
genuine fork the plan didn't settle, or a discovery that invalidates the plan.

The stage runs on two models, split where the kind of work changes. **Steps 1–2c
are design and run on opus**: naming the rules, choosing the shape, and holding it
against the challenge are the decisions everything after them inherits. **Steps
3–6b are the build and run on the model the risk class names** — sonnet at
`mechanical`, `tiny` and `normal`, opus at `elevated` and `production`
(`${CLAUDE_PLUGIN_ROOT}/references/risk-classes.md` has the reasoning). Step 2d is
the handoff between them. Run standalone on another model, do Steps 1–2c on an opus
sub-agent or switch to opus first; don't design on the build model because it
happens to be the session's.

## Step 1 — Name the bar for *this* change

Read `${CLAUDE_PLUGIN_ROOT}/references/coding-principles.md` and
`${CLAUDE_PLUGIN_ROOT}/references/project-context.md` (if present), plus the
project's `CLAUDE.md` **and the project's own convention docs** — whatever the
sidecar names, or the coding and testing conventions the repo keeps under `docs/`
— whose rules are narrower and more specific than the plugin's principles. These are the
standard the review stage grades you against.

Then do the part that actually changes the code you write. Having the rules in
context is not the same as reasoning against them: "declarative over
imperative" has sat in `coding-principles.md` through changes that shipped
accumulate-and-`continue` loops anyway. So before you edit a file, write out —
briefly, in the run, not in a file:

1. **Applicable rules.** The five to ten that bear on *this* change, named
   (`§3.9 same input same output`, `§5.6 one concept one implementation`), not
   "the conventions". A rule you can't name you won't apply.
2. **Exemplars.** One to three places in this repo that already do the thing
   well, and which you'll pattern-match against. Grep for them.
3. **Rule per decision.** For each planned change, the one rule that shapes it,
   and where a rule pulls against another, which wins and why.

Keep this list where you can see it; Step 3's self-check grades against it.
Don't edit anything until it exists. When Step 2d hands the build to another
model, this list goes with it verbatim — it is the design at `mechanical` and
`tiny`, where no note is written.

## Step 2 — Load the repo set

Cross-repo changes are the norm here. Read
`${CLAUDE_PLUGIN_ROOT}/references/multi-repo.md` and load the manifest
(`<primary-repo>/.vicaris/repos-<branch>.txt`); with no manifest, the set is
just the current repo. Confirm each repo is on the task branch, not its default —
if one isn't, branch it per the reference before editing it.

Then work the set **in dependency order**, producer before consumer, using
`git -C "$repo"` rather than `cd` so you can't lose track of where you are. Do
not commit or push unless asked.

## Step 2b — Design the change before the first edit

Step 1 named the rules; this names the *shape*, which is the decision they cannot
reach. Line-level rules fire while a function is being typed and never at the
moment you choose whether a class should exist, where a rule lives, or what gets
deleted — and by the time a diff exists, that choice is expensive to revisit.

**If the repo has its own `design-change` skill** (`.claude/skills/design-change/`),
run it and use its output — it cites that repo's numbered conventions and its own
routing table, which is what makes the answers concrete. Otherwise answer the seven
below against the rules you named in Step 1.

**The risk class decides whether this section runs at all.** Read
`<primary-repo>/.vicaris/risk-<branch>.txt` and
`${CLAUDE_PLUGIN_ROOT}/references/risk-classes.md`: at `mechanical` and `tiny` the
change repeats a shape the repo already has or fixes one line, there is no shape to
choose, and writing a design note for it produces ceremony rather than a decision.
At `normal` and above, write one. One line per answer, and `none` plus the reason is an
answer — a blank is a finding.

**Write every repo's note before the first `Edit` or `Write` in any of them**, not
merely before the first edit in each. Two things depend on that ordering. The
cross-repo row below settles the contract, and deciding it once the producer is
already written means the consumer inherits whatever the producer happened to do
rather than what anyone chose. And Step 2c holds the change against a design built
independently of yours, which it can only do once the whole change has been
designed. The contract's *detail* will still move while you write the producer;
when it does, amend the note, because a note describing a shape that no longer
exists is worse than no note — `finalize` quotes these as the reasoning behind
what shipped.

```
Design note
1. Requirement: <one sentence, no class / file / pattern names>
2. Fresh design: <what you'd build in an empty repo> · Existing: <closest file> · Verdict: <matches | differs — which is right, and whether this change fixes it>
3. Rejected simpler design: <what it was> · Breaks because: <the specific input, state or caller>
4. Deleted: <file / function / branch> or none because <reason>
5. Tested by: <the pure function or contract under test, no mocks> or impure because <the I/O, clock or global it reads>
6. Nouns → types: <noun: Type | primitive> for each noun in line 1 · Verbs → owners: <verb: OwningType>
7. Repeated shapes: <file:line, file:line — the unnamed abstraction> or none
```

Three of those carry most of the weight. **Design in an empty repo first, then
read the existing code** (Q2) — existing code is evidence of what exists, not of
what is right, and adopting a shape because it is already there is how a codebase
keeps its mistakes. **Name the simpler design you rejected and the specific thing
that breaks under it** (Q3) — not "less flexible", the input or caller it fails
for, because a simpler design you cannot name is one you never considered.
**Name what the change deletes** (Q4) — a change that only adds is usually one
that should have modified something.

Then answer only the rows that apply:

| The change… | Answer |
|---|---|
| **Adds a class or module** | Its one reason to change, in one sentence — two sentences means two units. Which object owns the data each new rule reads, because the rule goes on that object. Each invariant and the *single* place that enforces it; one checked at three call sites is enforced nowhere. |
| **Adds a parameter, flag, hook, base class or indirection** | The present caller or requirement that forces it. "A second caller later" is not one — the indirection arrives with the second caller. For an abstraction, the two or three existing instances it unifies; one instance means inline it. Then trace one request through the change and list the files a reader opens in order, with a concrete requirement for each hop past three. |
| **Branches on a kind, mode, region or entity type** | The mapping that replaces it — a dict keyed by the enum, a `match` over the closed set with an exhaustiveness check, a pipeline of pure transforms — or the reason control flow is genuinely required. A chain of `if`/`elif` over a closed set is data written as code. |
| **Adds a boundary** (HTTP, LLM structured output, file, external client, config) | The type at that edge and the concept each primitive crossing it stands for. When it fails, where the error surfaces and who acts on it — a swallowed failure is a future incident. |
| **Crosses a repo boundary** | The contract's shape, which repo owns it, and what the consumer does with an absent or unknown value while the producer is unmerged. This is the one row `plan` cannot have settled. Its shape is decided here, before either side is written; only its detail firms up as you write the producer, and when it moves you amend the note. |

Every answer is a noun — a path, a type, a caller, a rejected sketch. "Cleaner",
"simpler" and "more idiomatic" each need the concrete thing behind them or they are
dropped, and the size of the change does not waive the seven.

**Write each note to `<that repo>/.vicaris/design-notes-<branch>.md`** — the repo
the note is about, not the primary one — rather than leaving it in the response.
Two reasons, and the second is the one that bites. A long autonomous run gets
compacted, and reasoning left in a response is exactly what a summariser flattens,
while this is the raw material for the completion doc's assumptions: Q2 and Q3 are
an alternative and the reason it lost, recorded while the decision was live. And a
note explaining why the consumer's class looks the way it does belongs beside that
consumer, where it is still there when that repo is next worked on alone. See
`${CLAUDE_PLUGIN_ROOT}/references/multi-repo.md` for the placement rule and the
one-line local exclude that keeps `.vicaris/` out of every repo's `git status`.

## Step 2c — Challenge the design, before the first edit

The note you just wrote compared a fresh design against the existing code (Q2) and
named a simpler design you rejected (Q3). Both comparisons were produced by the
pass that had already chosen, after it chose, so they catch over-building and they
cannot catch a wrong approach — the approach came from the plan, and the plan was
never one of the two things being compared.

Run the `design-challenge` skill, which builds a second design from the acceptance
criteria alone, blind to your plan and your note, and holds the two together. It
decides its own gate: cross-repo changes, new structural units, contract changes,
and anything touching schema, authorisation, money or concurrency get the
challenge, and a local bug fix or a pattern-following addition is skipped with a
reason in one line.

It amends the design notes in place where a divergence is adopted, so **read them
again after it returns** rather than building from what you wrote before it ran.
Where it declined a divergence, the reason is in the note too, and that is the line
the review stage will weigh if a reviewer proposes the same thing later.

## Step 2d — Hand the build to the build model

Read the class from `<primary-repo>/.vicaris/risk-<branch>.txt`. At `elevated` and
`production`, carry on yourself on opus into Step 3. At `mechanical`, `tiny` and
`normal`, spawn **one** sub-agent with `subagent_type: general-purpose` and
`model: sonnet` to run Steps 3–6b across the whole manifest. Never `fork`: a fork
always runs on the parent's model, so it would quietly keep the build on opus.

The agent starts with none of your context, so its prompt carries everything the
build must not re-decide:

- the path to this skill, and the instruction to follow Steps 3–6b in auto mode,
  including the per-repo Slack pings and the gate script in Step 6;
- the manifest path, the branch, and the dependency order;
- the Step 1 list — applicable rules, exemplars, rule per decision — verbatim;
- every repo's `design-notes-<branch>.md` path, as amended by the challenge, with
  the rule that the note is the design: where building shows it is wrong, amend the
  note and say why in the report rather than drifting from it silently;
- the test surface from `<primary-repo>/.vicaris/understanding-<branch>.md` and
  any prompt-change constraints from the sidecar.

When it returns, read its report and each repo's `verify-<branch>.txt` rather than
taking the summary on trust, then re-read the design notes for amendments before
handing off. A build that came back red or with an unexplained departure from its
note is not handed to review: fix it yourself on opus, since the cheap attempt has
already been spent.

## Step 3 — Build it, one slice at a time

Work in **coherent slices**, not file by file and not function by function. A
slice is one behaviour end to end — request through to persistence, or one rule
plus the post-processing and tests that make it true. Function-by-function is
actively worse: it optimises each function locally and loses the design.

After each slice, before starting the next, run the self-check:

```
git diff            # the slice, not the whole change
```

Read that diff against the rules you named in Step 1 and list what it violates.
Fix the violations now, while the slice is still in your head and nothing
downstream depends on its shape. An empty list is a real answer — but reach it
by reading, not by assuming. The failure this catches is the cheap one: a
`continue`-shaped filter, a name with "and" in it, a docstring citing a caller
you just renamed, a choice that falls out of emission order.

This is a self-check, not the review — you wrote the code and will rationalise
it. The independent pass is the adversarial-review stage, in a fresh context.
Its job is to catch what you couldn't see; yours is to not hand it the
mechanical stuff.

Hold the principles live while writing:

- Clean, readable, obvious. Clear names. Low branching — early returns and
  guard clauses over nesting.
- Small single-responsibility functions and modules. Declarative over
  imperative. Pure functions for logic; no output arguments, no mutate-then-
  return.
- Model the domain — real types and behaviour on the domain object, not an
  anemic bag drained into a service. Closed sets as enums/literals, not bare
  strings. Type every boundary.
- Idiomatic, modern constructs for the language and version in hand. No
  outdated equivalents, no reflection on typed objects, no casts that lie to
  the checker.
- A design pattern only where it earns extensibility or removes real
  duplication. No speculative abstraction. Resist the urge to over-build.
- Consolidate duplication as you go; when you touch a function, the whole
  function is fair game to tidy — but keep unrelated cleanup out of the change.
- Enforce counts / fallbacks / closed-set membership / format in code; express
  intent in prose. Fail fast at boundaries with a clear raise.

If the change is explicitly **temporary / scratch / just-to-test**: make only
the code change, flag in one line what it breaks, and stop — no test chasing,
no new tests, no suite run.

## Step 4 — Test to the plan

Add the concise-but-sufficient tests from the plan — the behaviour and the
edges that matter, nothing performative. Keep logic pure so tests need no
mocks; mock only unavoidable seams.

## Step 5 — Prompt changes (if any)

If the change touches prompts or structured-output field descriptions, follow
the prompt conventions in `project-context.md`: read the whole assembled prompt
first, no patchwork (consolidate into the canonical home), keep every variant of
a prompt that must move together in sync and note which ones you checked, no
internal references in anything the model sees, and never hard-code a system
prompt in code. Run evals only where and how the sidecar says; if it gates prompt
changes on an eval in CI, that runs at finalize, not here.

## Step 6 — Verify every repo you touched

Run the fast verify command from `project-context.md` (fall back to the
project's standard unit-test command) **in each repo of the set** — each has its
own toolchain and its own command, so one repo's green suite says nothing about
the next — through the gate script, which records the verdict where every later
stage reads it:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/vicaris-gate.sh" "$repo" "$VERIFY_CMD"
```

That recording is not bookkeeping. Without it `test` re-runs a suite you already
ran, `handover` narrates a result it half remembers, and a resumed session cannot
tell a repo that passed from one nobody ever verified. Verify a repo before moving
to the one downstream of it. Do **not** run
eval or integration suites to verify. Leave zero lint / type warnings. Respect
the pre-commit gates; never bypass them.

Where the change spans a contract between repos, add the test that pins the
contract on **both** sides — the producer's output shape and the consumer's
handling of it. That seam is where cross-repo changes actually break, and it is
invisible to each repo's own suite.

Report per repo: what changed, tests added, verify result.

## Step 6b — Simplify what you just wrote

Working code is the start of this pass, not the end of the change: complexity can
only be judged against code that exists, so this runs once the tests are green and
before anything hands off. It is also the cheapest pass in the run — every
mechanical smell you remove here is one that would otherwise cost an opus reviewer's
attention and a full fix loop, and the review charter tells reviewers not to spend
their pass on nits in the first place.

This pass is worth its time at every risk class, including `mechanical` — a
threaded field still picks up a loop that should be a comprehension, and this is the
cheapest place in the run to remove it.

**If the repo has its own `simplify-implementation` skill**, run it. Otherwise walk
the diff — the diff, not the file — and for each row name a *line* and what you did,
or `none`:

- Every loop whose body only appends, sets a key or updates a flag → the
  comprehension, `any`/`all`/`sum` or library call that replaces it.
- Every `if`/`elif` or type-check chain over a closed set → the mapping or the
  exhaustive `match` that replaces it.
- Every branch nested past two levels → the early return or extracted predicate.
- Every function: say what it does in one sentence; if the sentence needs "and",
  name the two functions it is. Count the names live at its deepest line, and past
  eight name the group one step consumes and the one it yields — that is the
  extraction.
- Every function that reads something it wasn't handed (clock, environment,
  singleton, global) → the parameter it becomes.
- Every function that writes through an argument *and* returns a value → the query
  it becomes, or the command it is renamed as.
- Every helper you added → its second caller, or the domain fact its name states
  that the inlined expression only implies. Neither means inline it, including a
  wrapper that exists so a test can patch it.
- Every group of lines under a comment header → the function whose name is the
  comment.
- Every tuple or dict handed between two of your own functions → the record type it
  stands for.
- Every second occurrence of a shape you wrote → its name, with the loser retired in
  this change.
- Every `except` → the specific type and the caller that acts on it; a handler that
  only logs and continues is a hidden branch.

A candidate that stays needs a reason shaped like a rule, not an adjective:
"clearer this way" is not a reason. Append the note to that repo's own
`.vicaris/design-notes-<branch>.md`, beneath its design note, re-run the repo's
verify, and only then hand off. The pass is not over because the
tests pass — they passed before it started.

**Ping Slack as each repo finishes**, not once at the end — see
`${CLAUDE_PLUGIN_ROOT}/references/notifications.md` for the thread mechanics
(parent `ts` in `<primary-repo>/.vicaris/slack-thread-<branch>.txt`). One line per
repo, e.g. `service-api (1/2) done — filter aggregation, 41 tests
green`. Implementation is the longest silent stretch of a run, so this is where a
per-repo drumbeat matters most: it's the difference between Sujit seeing progress
and wondering whether the run died. If a single repo's work is going to take a
while, say so when you start it.

Then hand off to the adversarial review stage, which reviews the whole set.
