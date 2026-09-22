---
name: adversarial-review
description: Review the current change from independent angles before an MR exists — craft, structure and cross-file behaviour per repo via the mr-review plugin's review-changes, plus a PO pass over the whole change — then synthesise into one short, ranked, scannable report. Runs unattended, deciding every question rather than asking it.
argument-hint: [Jira key or base branch override]
allowed-tools: Bash, Read, Glob, Grep, Agent, Skill, mcp__claude_ai_Slack__slack_send_message, mcp__claude_ai_Atlassian__getJiraIssue, mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql, mcp__claude_ai_Atlassian__getJiraIssueRemoteIssueLinks, mcp__claude_ai_Atlassian__getConfluencePage, mcp__claude_ai_Atlassian__searchConfluenceUsingCql, mcp__claude_ai_Atlassian__getPagesInConfluenceSpace, mcp__claude_ai_Atlassian__getConfluencePageDescendants, mcp__claude_ai_Atlassian__getConfluenceSpaces
---

# Adversarial review

Review the change the way a careful team would before anyone else has to look at it. The depth
comes from the `mr-review` plugin's `review-changes` skill, which grades against the same charter
the MR bot uses and splits the work so each reviewer answers one question — craft (is the
implementation locally good), architect (is the structure right), integration (does it work as a
system). What this skill owns is everything that is true of *the change* rather than of one
repository: the repo set, the acceptance criteria, the seam between repos, and the single ranked
list that comes out.

Reviewers run on **opus** at high effort, and nothing here asks Sujit anything — see "Deciding,
not asking" at the end.

## Step 1 — Establish the change, not the repo

Read `${CLAUDE_PLUGIN_ROOT}/references/multi-repo.md` and load the manifest
(`<primary-repo>/.dev-flow/repos-<branch>.txt`); with no manifest the set is just the current
repo. Then, per repo, resolve the base and the changed-file list — `--stat`, not the patch:

```bash
for repo in $REPOS; do
  git -C "$repo" fetch --prune origin
  BASE=$(git -C "$repo" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null \
    || git -C "$repo" remote show origin | sed -n 's|.*HEAD branch: |origin/|p')
  git -C "$repo" diff "$BASE"...HEAD --stat
  git -C "$repo" log "$BASE"..HEAD --oneline
done
```

Each repo's base is its *remote* default (`origin/main`), never the local branch name — a stale
local `main` pads the diff with other people's merged work and the review is spent on it. The
three-dot form is deliberate: it diffs from the merge-base, so only this branch's work is
reviewed. `$ARGUMENTS` may override `BASE`.

**Do not read the diffs into this context.** Every reviewer below fetches its own, and the report
is the only part you need to hold. Extract the Jira key from the branch name (or take it from
`$ARGUMENTS`) and fetch the story and acceptance criteria — that much is small enough to keep, and
Step 3 needs it.

Record which repos have commits on the branch. A repo in the manifest with nothing on it is not a
failure; a repo with commits that no pass below covers is.

## Step 2 — Buy the passes the change earns

Read `<primary-repo>/.dev-flow/risk-<branch>.txt` and
`${CLAUDE_PLUGIN_ROOT}/references/risk-classes.md` before spending anything. The class
decides the invocation, and a fixed pass set is how a field addition ends up costing what a
migration costs:

| Class | Invocation, per repo |
|---|---|
| `mechanical` | **none** — Step 2a's parity check replaces it |
| `tiny` | `/review-changes --base <BASE> --quick --yes --also-repo <siblings>` |
| `normal` | `/review-changes --base <BASE> --yes --also-repo <siblings>` |
| `elevated` · `production` | `/review-changes --base <BASE> --yes --architect --integration --also-repo <siblings>` |

With no risk file, treat the change as `normal` and say so in the report.

Four things about those command lines matter more than they look.

**Never `--only`.** It replaces the default pass set outright, which switches off the
conditionality the mapper computes from the diff — its `signals.architect` and
`signals.integration` exist precisely to skip a pass that would return nothing, and the table
above is doing the same job one level up. `--architect` and `--integration` *force* a pass on
without disabling the mechanism, which is what the top two rows want.

**Every flag is explicit, always.** Invoked bare, `review-changes` asks which passes to run and
how deep, and an unattended run that reaches that question stalls until Sujit comes back. The
flags are what make it decide instead. `--yes` says nobody is watching.

**`--also-repo` is what makes a split change reviewable.** The mapper greps callers and tests
across the repositories it is given, so a producer whose signature changed and whose only callers
live in the consumer is reported as changing a contract under three call sites rather than as
changing a function nothing calls. Without it, each repo's review comes back clean while the seam
between them is broken — which is the defining failure of reviewing a cross-repo change, and the
reason this flag is not optional when the manifest has more than one entry.

**One repo at a time.** `review-changes` writes its plan and briefs to fixed paths under `/tmp`
and clears them on entry, so two runs in parallel overwrite each other's briefs and the second
review silently reads the first one's change context.

Run its passes on `opus`, except where the table above bought `--quick` — that downgrades craft
to sonnet and caps the agents, which is the right trade for a `tiny` change and the wrong one
for anything above it. Take its ranked findings per repo and keep them tagged with the
repo name — bare `file:line` is ambiguous once more than one repo is in play, and the fix pass
routes by that tag.

If the `mr-review` plugin is not installed or the skill is unavailable, say so in the report and
fall back to `Step 2b`. Do not skip the review.

### Step 2a — Parity, for a mechanical change

A mechanical change fails by being **incomplete, not by being ugly**: the field that reaches
three of four consumers, the enum value with no `match` arm, the prompt updated for `US` and
`UK` but not `CA`. A craft pass reads each touched file and reports that all of them are fine,
which is true and useless — the defect is in the file nobody touched. So for `mechanical` the
craft, architect and integration passes are not bought at all, and this runs instead.

Name the pattern the change repeats, then let a grep find every instance of it:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/dev-flow-parity.sh" "$repo" '<pattern>' '<optional path glob>'
```

Run it **once per shape the change touches**, not once per repo — a field addition usually has
two or three: where the field is declared, where it is consumed, and where its siblings are
enumerated. The script prints TOUCHED and UNTOUCHED per file and exits 3 when anything was
missed.

The grep is the mechanical half and the judgement is yours: **every UNTOUCHED row needs an
answer** — either it needs the change too, in which case make it now, or a one-line reason it
correctly does not. "Probably fine" is not one. Exit 2 means the pattern matched nothing, which
means the pattern was wrong rather than the change being complete; fix the pattern and re-run.

Report the parity result where the other classes report findings: the shapes checked, the
instances per shape, and anything added as a result. Then run Step 3's acceptance-criteria pass
only if the class earns it — `mechanical` skips it, because a story whose whole delivery is a
threaded field has nothing for a criteria pass to disagree with.

If the change turns out not to be mechanical once you see the diff — a new concept, a branch on
a new kind, a contract that moved — say so, raise the class in `risk-<branch>.txt`, and run the
`normal` invocation instead. Downgrading ceremony is only safe while the premise holds.

### Step 2b — Fallback when `review-changes` is unavailable

Spawn three opus sub-agents in a single message, each getting the *instructions* rather than the
content: the repo list with each path and resolved `BASE`, the changed-file stat, and the paths to
`${CLAUDE_PLUGIN_ROOT}/references/coding-principles.md`, `references/multi-repo.md` and
`project-context.md`. Each pulls its own diffs (`git -C "$repo" diff "$BASE"...HEAD` plus
`git -C "$repo" diff` for uncommitted work) across **every** repo and reads what it needs.

- **Clean-code reviewer** — grade against `coding-principles.md` *and the repo's own convention
  docs* (`docs/conventions/coding-conventions.md`, `testing.md`, or whatever `project-context.md`
  names), citing the rule id in each finding (`§3.8 names reveal intent`) so a rule nothing grades
  shows up as a finding with nothing to cite. Readability, naming, complexity, function and module
  size, declarative over imperative, pure functions, duplication, typing at boundaries, zero
  warnings. Over-engineering and nits-that-shipped are findings too.
- **Design reviewer** — SOLID at real seams, DDD and domain modelling, abstraction quality,
  coupling and cohesion, and speculative abstraction that should go.
- **Integration reviewer** — contracts under their callers, behaviour spread across files,
  transaction and failure paths, idempotency, and changed behaviour with no test.

## Step 3 — The acceptance criteria, once, over the whole change

`review-changes` grades one repository, so its PO pass would see one repo's share of the story and
report every criterion the other side delivers as missing. Run the acceptance-criteria review here
instead, as **one** opus sub-agent over the whole change: give it the repo list with each base, the
story and its criteria, and let it pull every repo's diff itself.

It classifies the change as FULL or PARTIAL scope, maps every criterion to addressed / partial /
missing, and checks the implementation actually does what each criterion says rather than that
code exists near it. Scope creep and silent behaviour changes are findings. Addressed criteria roll
into one line; only partial and missing get detail.

On a **single-repo** change with a story, add `--maker` to Step 2's flags instead and let
`review-changes` own this — its design pass builds an alternative from the story blind to the diff,
which is stronger than anything here. On a split change leave `--maker` off: it designs the whole
story and would read the half living in the other repo as a divergence. Say in the report which of
the two ran.

**Skip `--maker` entirely when the design challenge already ran** — check for
`<primary-repo>/.dev-flow/design-challenge-<branch>.md`. The two passes ask the same question, and
the challenge asked it earlier and from a better position: it compared two designs before either
was built, where `--maker` compares a design against a finished diff and can only report what the
rework would now cost. Running both spends three agents to reach one conclusion. Where the
challenge was skipped because the change fell below its gate, `--maker` on a single-repo change is
still worth its two agents.

## Step 4 — The seam, if the change spans repos

With `--also-repo` in play, `review-changes`'s integration pass already owns the contract between
repos: field and enum agreement, request and response shape, error and null handling on the
consumer side, and whether each merge order is safe in the interim state where one repo has landed
and the other has not. Read its cross-repo findings as blockers rather than notes — each per-repo
diff can be clean while the change as a whole is broken.

What remains yours is the judgement no pass is asked for: whether each piece sits in the right repo
at all, and what the merge order has to be. State both, in one line each.

## Step 5 — Synthesise (short, ranked, scannable)

Merge everything, de-duplicate overlaps, and resolve contradictions, saying which reviewer you
sided with and why. Write the review doc in Sujit's preferred shape — scratch, don't commit it:

- **Repos reviewed** — each repo with its diffstat and which passes ran on it, so it is obvious
  nothing was skipped (one line; omit for a single-repo change).
- **What's good** — a few bullets.
- **Must not be missed** — blockers and should-fixes, ranked, one short paragraph each, tagged
  `[craft] / [architect] / [integration] / [PO] / [design]` and `repo: file:line`. Each carries a
  one-line self-critique: why this might be a false alarm.
- **Cross-repo contract** — the seam's verdict, any mismatch, and the merge order (skip for a
  single-repo change).
- **AC scorecard** — addressed / partial / missing, one line.
- **Skip for now** — real-but-not-worth-it items, so they are seen and parked.

Keep it tight; a long essay gets skipped.

**The design notes belong to this step and to no reviewer.** `implement` recorded, in each repo's
own `.dev-flow/design-notes-<branch>.md`, the shape it chose there and the simpler design it
rejected. Never put that in a reviewer's prompt — the
independence of the pass is the whole point, and handing a reviewer the author's rationale tells it
what to conclude. Read it here instead, and only to resolve: when a finding proposes exactly the
design line 3 rejected, you have a real disagreement rather than a defect, so weigh the reviewer's
failure case against the author's and say which held. When the note is silent on something a
reviewer found, that silence is itself worth a line — the design pass should have reached it.

The design challenge doc in the primary repo is read the same way and carries more weight, because
a decision that survived a contest against an independently built design was tested rather than
merely defended. A reviewer reopening a divergence the challenge decided is not automatically
wrong — it read the code, and the challenge read only two designs — but it has to beat a named
consequence rather than an author's preference. Say which it did.

## Step 6 — Hand back the fix list

Ping Slack per `${CLAUDE_PLUGIN_ROOT}/references/notifications.md` when the review starts and over
which repos — several opus passes across a large diff is one of the longest silent stretches in a
run, and an unannounced one reads as a hang — and again when it lands, with counts by severity plus
the headline of anything non-trivial, never the full list.

Then hand the ranked fix-list back for a fix pass, **applying each finding in the repo it names**,
re-verifying that repo with `scripts/dev-flow-gate.sh`, and re-running the contract tests if the
seam moved.

**Findings are decided, not applied, and the loop stops after two passes** — both rules and the
ledger format live in `${CLAUDE_PLUGIN_ROOT}/references/gates.md`. A reviewer that ran without the
author's rationale can be right about the code and wrong about the change, so each blocker and
should-fix ends applied or declined with a named reason, never "noted", and every outcome goes in
`<primary>/.dev-flow/fix-ledger-<branch>.md`. At the cap, record what is outstanding, carry it into
the completion doc and the MR descriptions, ping the thread, and move on rather than starting a
third pass. Stop earlier still if a fix reverses a fix from the previous pass: that is oscillation,
one more pass picks a side arbitrarily, and the disagreement is the one thing in the change that
wants a human eye.

## Deciding, not asking

Every question this stage could raise has a standing answer, because it runs unattended and a
prompt waiting for a keypress costs the whole run.

| Situation | What you do |
|---|---|
| `review-changes` would ask which passes to run | Never let it. Pass the flags in Step 2 and `--yes` |
| A repo in the manifest has no commits | Record it as having no changes and move on |
| The branch has no Jira key | Take the brief from `$ARGUMENTS`; with neither, skip Step 3 and say so |
| The story has no usable acceptance criteria | Skip the PO pass with the reason, rather than grading against a guess |
| The `mr-review` plugin is missing | Step 2b, and name the fallback in the report |
| Two reviewers contradict each other | Pick one, say which and why; do not report both and let Sujit arbitrate |
| A finding is real but not worth fixing now | Park it under "Skip for now" — that is what the section is for |
| The review is enormous | Rank harder and report the ceiling you applied; never quietly truncate |
