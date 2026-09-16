---
name: adversarial-review
description: Run three independent reviews of the current change in parallel — PO (acceptance-criteria coverage + implementation accuracy), clean-code (Sujit's principles), and design (SOLID / DDD / patterns) — then synthesise into one short, ranked, scannable report. Reviewers run on opus.
argument-hint: [Jira key or base branch override]
allowed-tools: Bash, Read, Glob, Grep, Agent, mcp__claude_ai_Slack__slack_send_message, mcp__claude_ai_Atlassian__getJiraIssue, mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql
---

# Adversarial review

Three reviewers examine the change from independent angles **in parallel**, so
no single lens dominates. Reviewers run on **opus** at high effort.

## Step 1 — Establish the review inputs (metadata only)

**Do not read the diffs into this context.** Each reviewer is a sub-agent with
its own Bash access and its own context window, so it fetches its own diff. Your
job here is only to assemble the cheap metadata they need — across several repos a
full diff would burn the orchestrator's context on content you never reason about
directly, and the review report is the only part you need to hold.

Read `${CLAUDE_PLUGIN_ROOT}/references/multi-repo.md` and load the manifest
(`<primary-repo>/.dev-flow/repos-<branch>.txt`); with no manifest the set is just
the current repo. Then, per repo, resolve the base and the changed-file list —
`--stat`, not the patch:

```bash
for repo in $REPOS; do
  git -C "$repo" fetch --prune origin
  BASE=$(git -C "$repo" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null \
    || git -C "$repo" remote show origin | sed -n 's|.*HEAD branch: |origin/|p')
  git -C "$repo" diff "$BASE"...HEAD --stat
  git -C "$repo" log "$BASE"..HEAD --oneline
done
```

Each repo's base is its *remote* default (`origin/main`), never the local branch
name — a stale local `main` pads the diff with other people's merged work and the
reviewers waste their pass on it. The three-dot form is deliberate: it diffs from
the merge-base, so the review sees this branch's work only. `$ARGUMENTS` may
override `BASE`.

Extract the Jira key from the branch name (or take it from `$ARGUMENTS`) and
fetch the story + acceptance criteria via the Atlassian MCP — the PO reviewer
needs them, and this is small enough to hold.

## Step 1b — What each reviewer must see

Reviewing one repo's slice of a cross-repo change is the failure mode here. Half
a change reads as incoherent (callers that "don't exist", fields that go nowhere)
and the reviewers burn their pass on phantom findings while the real defect — the
mismatch at the seam — sits in the half they never saw. So every reviewer gets the
**whole repo set**, and each runs, for each repo:

```bash
git -C "$repo" diff "$BASE"...HEAD      # committed work on the branch
git -C "$repo" diff                     # uncommitted
```

## Step 2 — Fan out three reviewers (parallel, opus)

Spawn all three as sub-agents **in a single message** so they run concurrently.
Each sub-agent gets the *instructions*, not the content: the repo list with each
repo's path and resolved `$BASE`, the changed-file stat, the ACs, and the paths to
`${CLAUDE_PLUGIN_ROOT}/references/coding-principles.md`,
`${CLAUDE_PLUGIN_ROOT}/references/multi-repo.md` and `project-context.md`. It then
pulls its own diffs (Step 1b) and reads whatever surrounding code it needs in its
own context.

This is what keeps the orchestrator's context viable on a long autonomous run:
three reviewers each read a large diff plus surrounding code, and only their
ranked findings — a page or two each — come back. Never inline a diff into a
sub-agent prompt that the sub-agent could fetch itself.

**Ping Slack that review has started** and over which repos, before you spawn them
(`references/notifications.md`). Three parallel opus reviewers over a large diff is
one of the longest silent stretches in a run, and an unannounced one reads as a
hang.

Each returns findings ranked by severity (blocker / should-fix / optional), each
finding tied to `repo: file:line` with a concrete failure or gap — no nits. The
repo prefix is required: fix passes route by it, and a bare path is ambiguous
across repos.

- **PO reviewer — AC coverage + accuracy of implementation.** Classify the
  change as FULL or PARTIAL scope against the story. Map every acceptance
  criterion to addressed / partial / missing. Check the implementation
  actually does what each AC says (not just that code exists near it). Flag
  scope creep and silent behaviour changes. Roll addressed ACs into one line;
  detail only partial/missing.

- **Clean-code reviewer — grade against `coding-principles.md` *and the repo's
  own convention docs*** (`docs/conventions/coding-conventions.md`,
  `testing.md`, or whatever `project-context.md` names). Read both: the repo's
  are narrower, numbered, and the ones the team argues about, so a review that
  grades only against the plugin's principles never tests them — and rules the
  reviewer never grades are rules implementation stops following. Cite the rule
  id in each finding (`§3.8 names reveal intent`) so a fix pass can look it up
  and a missing rule is visible as a finding with nothing to cite. Readability,
  naming, cyclomatic complexity, function/module size and single
  responsibility, declarative vs imperative, pure functions / no output args /
  no mutate-then-return, duplication, idiomatic modern constructs, typing at
  boundaries, zero-warnings. Call out over-engineering and nits-that-shipped as
  findings too. Prompt changes: patchwork, whole-prompt coherence, region +
  agency symmetry, internal references, intent-vs-enforcement.

- **Design reviewer — architecture.** SOLID at real seams, DDD and domain
  modelling (anemic model + fat service, primitives where a domain type
  belongs, behaviour in the wrong layer), abstraction quality, extensibility,
  coupling/cohesion, boundaries, and speculative abstraction that should be
  removed. Recommend the pattern only where it earns its place. **When the change
  spans repos this reviewer also owns the contract between them**: field and
  enum agreement across the boundary, request/response shape, error and
  null/absent handling on the consumer side, versioning, and whether the change
  is safe in the interim state where one repo has merged and the other hasn't.
  Also judge whether each piece sits in the right repo at all. Contract
  mismatches are blockers, not notes — each per-repo diff can be clean while the
  change as a whole is broken.

## Step 3 — Synthesise (short, ranked, scannable)

Merge the three, de-duplicate overlaps, and resolve contradictions (say which
reviewer you sided with and why). Produce a review doc in Sujit's preferred
shape — this is a scratch doc, don't commit it:

- **Repos reviewed** — each repo in the set with its diffstat, so it's obvious
  nothing was skipped (one line; omit for a single-repo change).
- **What's good** — a few bullets.
- **Must not be missed** — the blockers/should-fixes, ranked, one short
  paragraph each, tagged `[PO] / [clean-code] / [design]` and
  `repo: file:line`. Each carries a one-line self-critique (why this might be a
  false alarm).
- **Cross-repo contract** — the seam's verdict and any mismatch, plus the merge
  order if the MRs can't land in any order (skip for a single-repo change).
- **AC scorecard** — addressed / partial / missing, one line.
- **Skip for now** — real-but-not-worth-it items, so they're seen and parked.

Keep it tight; a long essay gets skipped.

Ping Slack with the findings — counts by severity plus the headline of anything
non-trivial, never the full list.

Then hand the ranked fix-list back for a fix pass — **applying each finding in the
repo it names**, then re-verifying that repo, and the contract tests if the seam
moved. **Ping again once the comments are resolved** (what was fixed, verify green
again), and say so explicitly if the loop reaches a third pass, since a review that
keeps finding new problems is something Sujit wants to know about while it's
happening rather than from the completion doc.
