---
name: implement
description: Implement an approved plan in auto mode, writing to Sujit's coding principles — clean, small, typed, declarative, well-tested. Runs on opus at high effort.
argument-hint: [path to plan, or the task if planning already happened in-session]
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, mcp__claude_ai_Slack__slack_send_message
---

# Implement

Build the change described by the plan (`$ARGUMENTS`, or the in-session plan).

**Model / mode:** opus, high reasoning effort, **auto mode** — proceed through
the implementation without stopping for confirmation at each step. Stop only
for a genuine fork the plan didn't settle, or a discovery that invalidates the
plan.

## Step 1 — Name the bar for *this* change

Read `${CLAUDE_PLUGIN_ROOT}/references/coding-principles.md` and
`${CLAUDE_PLUGIN_ROOT}/references/project-context.md` (if present), plus the
project's `CLAUDE.md` **and the project's own convention docs** — in this
codebase `docs/conventions/coding-conventions.md` and `testing.md`, whose rules
are narrower and more specific than the plugin's principles. These are the
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
Don't edit anything until it exists.

## Step 2 — Load the repo set

Cross-repo changes are the norm here. Read
`${CLAUDE_PLUGIN_ROOT}/references/multi-repo.md` and load the manifest
(`<primary-repo>/.dev-flow/repos-<branch>.txt`); with no manifest, the set is
just the current repo. Confirm each repo is on the task branch, not its default —
if one isn't, branch it per the reference before editing it.

Then work the set **in dependency order**, producer before consumer, using
`git -C "$repo"` rather than `cd` so you can't lose track of where you are. Do
not commit or push unless asked.

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
the prompt conventions in `project-context.md`: read the whole stitched prompt
first, no patchwork (consolidate into the canonical home), keep region and
agency prompts in sync and note what you checked, no internal references in
anything the model sees, and never hard-code a system prompt in code. Do not
run evals locally — the component eval is mandatory but runs as a manual job on
the MR pipeline at finalize (see the sidecar).

## Step 6 — Verify every repo you touched

Run the fast verify command from `project-context.md` (fall back to the
project's standard unit-test command) **in each repo of the set** — each has its
own toolchain and its own command, so one repo's green suite says nothing about
the next. Verify a repo before moving to the one downstream of it. Do **not** run
eval or integration suites to verify. Leave zero lint / type warnings. Respect
the pre-commit gates; never bypass them.

Where the change spans a contract between repos, add the test that pins the
contract on **both** sides — the producer's output shape and the consumer's
handling of it. That seam is where cross-repo changes actually break, and it is
invisible to each repo's own suite.

Report per repo: what changed, tests added, verify result.

**Ping Slack as each repo finishes**, not once at the end — see
`${CLAUDE_PLUGIN_ROOT}/references/notifications.md` for the thread mechanics
(parent `ts` in `<primary-repo>/.dev-flow/slack-thread-<branch>.txt`). One line per
repo, e.g. `service-api (1/2) done — filter aggregation, 41 tests
green`. Implementation is the longest silent stretch of a run, so this is where a
per-repo drumbeat matters most: it's the difference between Sujit seeing progress
and wondering whether the run died. If a single repo's work is going to take a
while, say so when you start it.

Then hand off to the adversarial review stage, which reviews the whole set.
