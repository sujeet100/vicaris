---
name: plan
description: Produce an implementation plan grounded in Sujit's coding principles — recommend the best option for every fork and state assumptions plainly. Run the planning model (fable) for this stage.
argument-hint: [Jira key, task description, or feature brief]
allowed-tools: Bash, Read, Glob, Grep, Agent, mcp__claude_ai_Atlassian__getJiraIssue, mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql
---

# Plan

Design an implementation plan for `$ARGUMENTS`. This stage thinks; it does not
edit code.

**Model:** planning runs on **fable**. When the orchestrator invokes this
stage it spawns a planning agent with `model: fable`. If you run `/plan`
directly on another model, do the planning on fable (switch model, or delegate
the planning to a `fable` sub-agent via the Agent tool) so plans stay cheap and
fast. Use high reasoning effort.

## Step 1 — Load the bar

Read, in this order:

1. `${CLAUDE_PLUGIN_ROOT}/references/coding-principles.md` — the design bar.
2. `${CLAUDE_PLUGIN_ROOT}/references/multi-repo.md` — cross-repo changes are the
   norm here, and this stage is what determines the repo set every later stage
   fans out over.
3. `${CLAUDE_PLUGIN_ROOT}/references/project-context.md` if present — verify
   commands, prompt/framework conventions, region + agency symmetry, testing
   and observability specifics.
4. The project's own `CLAUDE.md` / conventions.

## Step 2 — Understand the ask

- If `$ARGUMENTS` is a Jira key, fetch the story (summary, description,
  acceptance criteria, status) via the Atlassian MCP. Pull out the ACs
  explicitly — the PO review later grades against them.
- Otherwise treat `$ARGUMENTS` as the brief and restate the goal and the
  acceptance criteria you infer, so they can be corrected.
- Read the code the change touches. Map the seams, the domain, and the current
  behaviour before proposing anything.
- **Plan against current code, not a stale checkout.** List every repo the
  change reads from or touches, and for each one confirm it is fetched and not
  behind its upstream before you read it:
  ```bash
  git fetch --prune origin && git status -sb   # look for "behind"
  ```
  Name that repo list in the plan (see Step 5) so a multi-repo change can't
  quietly skip one. If a repo is behind and you can't bring it current
  (uncommitted work, no access), say so in the plan rather than planning around
  code you haven't seen — a plan built on a stale tree fails review, not
  implementation.

## Step 3 — Design against the principles

Shape the plan so the implementation lands clean the first time:

- Model the domain properly — real types, behaviour on the domain object, no
  anemic bag + fat service.
- Smallest change that is still clean. No speculative abstraction, no pattern
  without a concrete reason. If a pattern genuinely buys extensibility or kills
  duplication, name it and say why.
- Pure functions for logic; enforce counts / fallbacks / closed sets in code,
  express intent in prose.
- Call out the test surface: the few unit tests that actually cover the
  behaviour and its edges.
- If the change touches prompts, follow the prompt conventions in
  `project-context.md` — read the whole stitched prompt first, no patchwork,
  keep region + agency prompts in sync.

## Step 4 — Decide the forks, state the assumptions

For every meaningful fork, **pick the option you would recommend** and record a
one-line assumption behind it — do not hand back an open menu. Only surface a
2–3 option table when the call is genuinely Sujit's to make (product behaviour,
scope, irreversible choices). Each recommendation carries a one-line
self-critique (what would make it the wrong call).

## Step 5 — Emit the plan

Write a **scratch** plan (this is Sujit's working material — do not commit it,
do not cite it in commit messages). Keep it short and scannable:

- **Goal + acceptance criteria** being satisfied.
- **Approach** — the design in a few bullets, keyed to the principles.
- **Repos in scope** — each repo the change reads from or touches, in
  **dependency order** (producer before consumer), with its freshness state
  (`current` / `behind, not synced because …`). This list becomes the manifest
  every later stage fans out over, so getting it wrong drops work silently:
  a repo you omit gets no branch, no review, and no MR. Where the change spans
  repos, also state the **contract** between them and whether the MRs can merge
  in any order.
- **Change set** — files/modules to touch, in dependency order.
- **Assumptions** — each decision + the assumption + one-line self-critique.
- **Test plan** — the specific tests to add, nothing more.
- **Risks / rollback** — toggle or parity strategy if behaviour changes.

Save it under the project's scratch/plan area (or the scratchpad dir), not in a
tracked path. Hand the plan to the implement stage.
