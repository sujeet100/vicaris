---
name: implement
description: Design and build a change to Sujit's coding principles — design notes on Opus 5.5, build on Sonnet 5.5, tests, simplification pass.
argument-hint: [path to the understanding doc, or the task]
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Skill, Agent, mcp__claude_ai_Slack__slack_send_message, mcp__claude_ai_Atlassian__getJiraIssue, mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql, mcp__claude_ai_Atlassian__getJiraIssueRemoteIssueLinks, mcp__claude_ai_Atlassian__getConfluencePage, mcp__claude_ai_Atlassian__searchConfluenceUsingCql, mcp__claude_ai_Atlassian__getPagesInConfluenceSpace, mcp__claude_ai_Atlassian__getConfluencePageDescendants, mcp__claude_ai_Atlassian__getConfluenceSpaces
---

# Implement

**Owner:** ${user_config.owner_name}, the person this run acts for ("the owner" here
and in the references). Slack goes to member `${user_config.slack_user_id}`, else the
sidecar's Slack target, else record Slack as unavailable in the degraded list.

Build the change described by `<primary>/.vicaris/understanding-<branch>.md` (or `$ARGUMENTS`).

**Model / mode:** high reasoning effort, **auto mode** — don't stop for
confirmation. Stop only for a fork the understanding didn't settle, or a discovery that
invalidates it.

**Steps 1–2c are design and run on Opus 5.5.** **Steps 3–6b are the build and run on
Sonnet 5.5 at every class**, carrying out what design decided
(`${CLAUDE_PLUGIN_ROOT}/references/risk-classes.md`, *Build model*). Step 2d is the
handoff. In an orchestrated run the design is a `lead` sub-agent that runs Steps
1–2c and stops, and the orchestrator runs 2d
(`${CLAUDE_PLUGIN_ROOT}/references/delegation.md`). Run standalone on another model,
do Steps 1–2c on an opus sub-agent or switch to opus first.

## Step 1 — Name the bar for *this* change

Read `${CLAUDE_PLUGIN_ROOT}/references/coding-principles.md`,
`${CLAUDE_PLUGIN_ROOT}/references/project-context.md` (if present), the project's
`CLAUDE.md`, and the project's own convention docs (whatever the sidecar names, or
the coding and testing conventions under `docs/`), which are narrower than the
plugin's principles and win where they differ. Skip a plugin reference only if it is already in your context (the orchestrator's
Step 0 loads them in its own session; a sub-agent has not seen them). Always
read each repo's `CLAUDE.md` and convention docs; Step 0 never loads those.

Having the rules in context is not reasoning against them, so before any edit write
out, briefly, at the top of `<primary-repo>/.vicaris/design-notes-<branch>.md` under
`## Rules` — on disk, because the build runs in another context:

1. **Applicable rules.** The five to ten that bear on this change, named
   by the repo's own id where its conventions number them, otherwise by the
   principle's title (`Pure functions for business logic`), not "the conventions".
2. **Exemplars.** One to three places in this repo that already do it well. Grep
   for them.
3. **Rule per decision.** For each planned change, the rule that shapes it, and
   which wins where two conflict.

Step 3's self-check grades against this list. Don't edit anything until it exists.
The build reads it from there; at `mechanical` and `tiny` it is the whole design.

## Step 2 — Load the repo set

Load the manifest (`<primary-repo>/.vicaris/repos-<branch>.txt`; none means just
the current repo) per `${CLAUDE_PLUGIN_ROOT}/references/multi-repo.md`, and confirm
each repo is on the task branch before editing it; if one isn't, branch it off
its own remote default per `multi-repo.md`. Work **in dependency order**,
producer before consumer, with `git -C "$repo"` rather than `cd`. Do not commit or
push unless asked.

## Step 2b — Design the change before the first edit

Step 1 named the rules; this names the *shape* — whether a class should exist,
where a rule lives, what gets deleted — which is expensive to revisit once a diff
exists.

**Only at `normal` and above** (read `<primary-repo>/.vicaris/risk-<branch>.txt`);
`mechanical` and `tiny` skip it.

**Read `${CLAUDE_PLUGIN_ROOT}/references/design-note.md` and answer it** against the
Step 1 rules: the eight questions, the rows the change touches, and the sections
after them. **If the repo has its own `design-change` skill**
(`.claude/skills/design-change/`), run it instead — it carries that repo's rows and
rule citations — and still answer the reference's *Crosses a repo boundary* row when
the manifest has more than one repo, since a repo's own skill cannot see the others.

**Write every repo's note before the first `Edit` or `Write` in any of them**, so
the contract is chosen rather than inherited from whatever the producer happened to
do, and so Step 2c can compare a whole design. When the contract's detail moves
while you write the producer, amend the note — `finalize` quotes these as the
reasoning behind what shipped.

**Write each note to `<that repo>/.vicaris/design-notes-<branch>.md`** — the repo
it describes, not the primary — never only in the response, which compaction
flattens. Placement and the local `.vicaris/` exclude are in
`${CLAUDE_PLUGIN_ROOT}/references/multi-repo.md`.

## Step 2c — Challenge the design, before the first edit

Your note's comparisons were made by the pass that already chose, so they catch
over-building but not a wrong approach. Run the `design-challenge` skill: it builds
a second design from the acceptance criteria alone and compares the two, and it
decides its own gate (cross-repo, new structural units, contract changes, schema,
authorisation, money or concurrency run it; a local fix or pattern-following
addition skips with a reason).

It amends the design notes in place where a divergence is adopted, so **re-read
them after it returns**. Running as the design sub-agent, stop after this step and
report the note paths; the orchestrator spawns the build. A declined divergence keeps its reason in the note, which
review weighs if a reviewer proposes the same thing.

## Step 2d — Hand the build to the build model

Read the class from `<primary-repo>/.vicaris/risk-<branch>.txt` and spawn **one**
sub-agent with `subagent_type: builder` (Sonnet 5.5, at every class) to run Steps
3–6b across the whole manifest. The definition pins its model and holds its effort
at high; pass no `model:`. Do not build inline at any class — every build turn in
this context re-reads all of it. Never `fork`: a fork always runs on the parent's
model.

Its prompt carries what `${CLAUDE_PLUGIN_ROOT}/references/delegation.md` lists for
every stage sub-agent, plus everything the build must not re-decide:

- the instruction to follow Steps 3–6b, including the per-repo Slack pings and the
  gate script in Step 6;
- the path `${CLAUDE_PLUGIN_ROOT}/references/coding-principles.md`, to read before
  the first slice, plus each repo's convention docs from Step 1;
- every repo's `design-notes-<branch>.md` path, as amended by the challenge — the
  primary's opens with the Step 1 rules — with the rule that the note is the
  design: where building shows a decision is wrong, rewrite that section in place
  and say why in the report (`design-note.md`, *Keeping it current*), rather than
  drifting from it silently or appending a log of the build;
- the test surface from `<primary-repo>/.vicaris/understanding-<branch>.md` and
  any prompt-change constraints from the sidecar.

When it returns, read each repo's `verify-<branch>.txt` rather than trusting the
summary, and re-read the design notes for amendments. A build that came back red or
with an unexplained departure from its note is not handed to review: spawn a fresh `builder-opus` with the failure and the note, rather than repairing it here.

## Step 3 — Build it, one slice at a time

Work in **coherent slices** — one behaviour end to end, e.g. request through to
persistence, or one rule plus its post-processing and tests — not file by file or
function by function, which optimises locally and loses the design.

After each slice, run the self-check before starting the next:

```
git diff            # the slice, not the whole change
```

List what it violates against the Step 1 rules and fix it now. An empty list is a
real answer, reached by reading. Typical catches: a `continue`-shaped filter, a name
with "and" in it, a docstring citing a renamed caller, a choice that falls out of
emission order. This is not the review; its job is to not hand review the
mechanical stuff.

Hold `${CLAUDE_PLUGIN_ROOT}/references/coding-principles.md` and the Step 1 list —
the `## Rules` section of the primary's design notes — live while writing (read the
principles first if they are not in your context). Keep
unrelated cleanup out of the change, and no speculative abstraction.

If the change is explicitly **temporary / scratch / just-to-test**: make only the
code change, flag in one line what it breaks, and stop — no new tests, no suite run.

## Step 4 — Test to the understanding

Add the concise-but-sufficient tests from the understanding's test surface — the behaviour and the edges
that matter, nothing performative. Keep logic pure so tests need no mocks; mock
only unavoidable seams.

## Step 5 — Prompt changes (if any)

If the change touches prompts or structured-output field descriptions, follow the
prompt conventions in `project-context.md`: read the whole assembled prompt first,
no patchwork (consolidate into the canonical home), keep every variant of a prompt
that must move together in sync and note which ones you checked, no internal
references in anything the model sees, and never hard-code a system prompt in code.
Run evals only where and how the sidecar says; if it gates prompt changes on an eval
in CI, that runs at finalize, not here.

## Step 6 — Verify every repo you touched

Run the fast verify command from `project-context.md` (else the project's standard
unit-test command) **in each repo of the set**, before moving downstream, through
the gate script — later stages read its recorded verdict instead of re-running:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/vicaris-gate.sh" "$repo" "$VERIFY_CMD"
```

Do **not** run eval or integration suites to verify. Leave zero lint / type
warnings. Respect the pre-commit gates; never bypass them.

Where the change spans a contract between repos, add the test that pins it on
**both** sides — the producer's output shape and the consumer's handling — since
neither repo's own suite sees the seam.

Report per repo: what changed, tests added, verify result.

## Step 6b — Simplify what you just wrote

Runs once the tests are green, at every risk class including `mechanical`. It is
not over because the tests pass; they passed before it started. Walk the diff: every
smell removed here would otherwise cost an opus reviewer and a fix loop.

**If the repo has its own `simplify-implementation` skill**, run it. Otherwise walk
the diff — not the file — and for each row name a *line* and what you did, or
`none`:

- Loop whose body only appends, sets a key or updates a flag → the comprehension,
  `any`/`all`/`sum` or library call.
- `if`/`elif` or type-check chain over a closed set → mapping or exhaustive `match`.
- Branch nested past two levels → early return or extracted predicate.
- Each function: one sentence of what it does; needing "and" means two functions.
  Past eight names live at its deepest line, extract the group one step consumes
  and yields.
- Function reading something it wasn't handed (clock, environment, singleton,
  global) → a parameter.
- Function that writes through an argument *and* returns a value → a query, or a
  command renamed as one.
- Helper you added → its second caller, or the domain fact its name states; neither
  means inline it, including a wrapper that exists so a test can patch it.
- Lines grouped under a comment header → the function named by the comment.
- Tuple or dict passed between two of your own functions → the record type.
- Second occurrence of a shape you wrote → its name, with the loser retired now.
- Every `except` → the specific type and the caller that acts on it; log-and-continue
  is a hidden branch.

A candidate that stays needs a rule-shaped reason, not "clearer this way". Add it
as one line under `## Kept on purpose` in that repo's
`.vicaris/design-notes-<branch>.md`, so review can weigh it; record nothing for the
candidates you fixed or found absent. Re-run the repo's verify, and only then hand
off.

**Ping Slack as each repo finishes**, not once at the end, per
`${CLAUDE_PLUGIN_ROOT}/references/notifications.md` — one line per repo, e.g.
`service-api (1/2) done — filter aggregation, 41 tests green`. If one repo will
take a while, say so when you start it.

Then hand off to the adversarial review stage, which reviews the whole set.
