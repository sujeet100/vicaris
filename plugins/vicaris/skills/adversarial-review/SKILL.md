---
name: adversarial-review
description: Review a change across every repo it touches before an MR exists — passes bought by risk class, one acceptance-criteria pass, one ranked report.
argument-hint: [Jira key or base branch override]
allowed-tools: Bash, Read, Write, Glob, Grep, Agent, Skill, mcp__claude_ai_Slack__slack_send_message, mcp__claude_ai_Atlassian__getJiraIssue, mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql, mcp__claude_ai_Atlassian__getJiraIssueRemoteIssueLinks, mcp__claude_ai_Atlassian__getConfluencePage, mcp__claude_ai_Atlassian__searchConfluenceUsingCql, mcp__claude_ai_Atlassian__getPagesInConfluenceSpace, mcp__claude_ai_Atlassian__getConfluencePageDescendants, mcp__claude_ai_Atlassian__getConfluenceSpaces
---

# Adversarial review

**Owner:** ${user_config.owner_name}, the person this run acts for ("the owner" here
and in the references). Slack goes to member `${user_config.slack_user_id}`, else the
sidecar's Slack target, else record Slack as unavailable in the degraded list.

Review the change before anyone else has to. Depth comes from the `mr-review`
plugin's `review-changes` skill, which grades against the MR bot's charter with
one reviewer per question — craft, architect, integration. This skill owns what is
true of *the change* rather than one repo: the repo set, the acceptance criteria,
the seam between repos, and the single ranked list. Reviewers run on **opus** at
high effort; nothing here asks the owner anything (`references/autonomy.md`).

## Step 1 — Establish the change, not the repo

Load the manifest per `${CLAUDE_PLUGIN_ROOT}/references/multi-repo.md`
(`<primary-repo>/.vicaris/repos-<branch>.txt`; none means just the current repo).
Skip a plugin reference only if it is already in your context (the orchestrator's
Step 0 loads them in its own session; a sub-agent has not seen them). Per repo, resolve the base and the
changed-file list — `--stat`, not the patch:

```bash
for repo in $REPOS; do
  git -C "$repo" fetch --prune origin
  BASE=$(git -C "$repo" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null \
    || git -C "$repo" remote show origin | sed -n 's|.*HEAD branch: |origin/|p')
  git -C "$repo" diff "$BASE"...HEAD --stat
  git -C "$repo" log "$BASE"..HEAD --oneline
done
```

The base is each repo's *remote* default, never the local branch; the three-dot
form diffs from the merge-base. `$ARGUMENTS` may override `BASE`.

**Do not read the diffs into this context** — every reviewer fetches its own.
Extract the Jira key from the branch name (or `$ARGUMENTS`) and fetch the story and
acceptance criteria; Step 3 needs them.

Record which repos have commits. A manifest repo with none is fine; a repo with
commits that no pass covers is a failure.

## Step 2 — Buy the passes the change earns

Read `<primary-repo>/.vicaris/risk-<branch>.txt`; the class decides the invocation
(`references/risk-classes.md`):

| Class | Invocation, per repo |
|---|---|
| `mechanical` | **none** — Step 2a's parity check replaces it |
| `tiny` | `/review-changes --base <BASE> --quick --yes --also-repo <siblings>` |
| `normal` | `/review-changes --base <BASE> --yes --also-repo <siblings>` |
| `elevated` · `production` | `/review-changes --base <BASE> --yes --architect --integration --also-repo <siblings>` |

With no risk file, treat the change as `normal` and say so in the report.

- **Never `--only`.** It replaces the default pass set and switches off the
  mapper's `signals.architect` / `signals.integration`. `--architect` and
  `--integration` force a pass on without disabling them.
- **Every flag explicit, always.** Invoked bare, `review-changes` asks which passes
  to run and the unattended run stalls. `--yes` says nobody is watching.
- **`--also-repo` is not optional with more than one repo.** It lets the mapper
  grep callers across repos; without it each repo reviews clean while the seam is
  broken.
- **Run the repos in parallel** — one invocation per repo, in a single message;
  each run writes to its own `mktemp -d` directory. Check that `review-changes`'
  Step 2 creates one before parallelising; an older version on fixed `/tmp` paths
  must run one at a time, or concurrent runs silently read each other's briefs.

Passes run on `opus`, except that `--quick` downgrades craft to sonnet and caps the
agents. Keep findings tagged with the repo name — the fix pass routes by that tag.

**Keep the reducer's JSON, not only its prose.** Note each repo's `merged.json`
path in its run directory: it carries every finding by id with severity, quotes and
location, plus a `dropped` array of what the caps suppressed. The fix pass and
ledger need that structure, and the `dropped` list answers "was this considered"
when the MR reviewer raises it again at finalize.

If `mr-review` is not installed or the skill is unavailable, say so in the report
and use Step 2b. Do not skip the review.

### Step 2a — Parity, for a mechanical change

A mechanical change fails by being **incomplete**: the field that reaches three of
four consumers, the enum value with no `match` arm, the prompt updated for two
locales but not the third. The defect is in the file nobody touched, so for
`mechanical` no craft, architect or integration pass is bought and this runs
instead:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/vicaris-parity.sh" "$repo" '<pattern>' '<optional path glob>'
```

Run it **once per shape the change touches** — typically where the field is
declared, where it is consumed, and where its siblings are enumerated. It prints
TOUCHED / UNTOUCHED per file and exits 3 when anything was missed.

**Every UNTOUCHED row needs an answer**: make the change there now, or give a
one-line reason it correctly does not need it. "Probably fine" is not one. Exit 2
means the pattern matched nothing — fix the pattern and re-run.

Report the shapes checked, instances per shape, and anything added. `mechanical`
skips Step 3.

If the diff shows the change is not mechanical after all — a new concept, a branch
on a new kind, a moved contract — raise the class in `risk-<branch>.txt` and run
the `normal` invocation instead.

### Step 2b — Fallback when `review-changes` is unavailable

Spawn three `lead` sub-agents (opus, high effort) in a single message, each getting instructions rather
than content: the repo list with paths and resolved `BASE`, the changed-file stat,
and the paths to `${CLAUDE_PLUGIN_ROOT}/references/coding-principles.md`,
`references/multi-repo.md` and `project-context.md`. Each pulls its own diffs
(`git -C "$repo" diff "$BASE"...HEAD` plus `git -C "$repo" diff` for uncommitted
work) across **every** repo.

- **Clean-code reviewer** — grade against `coding-principles.md` *and the repo's own convention
  docs* (whatever `project-context.md` names, or the coding and testing conventions under
  `docs/`), citing the rule in each finding — the repo's own id where its conventions number them, otherwise the principle's title (`Clean, readable, obvious code`). Readability, naming,
  complexity, function and module size, declarative over imperative, pure functions, duplication,
  typing at boundaries, zero warnings. Over-engineering and nits-that-shipped are findings too.
- **Design reviewer** — SOLID at real seams, DDD and domain modelling, abstraction quality,
  coupling and cohesion, and speculative abstraction that should go.
- **Integration reviewer** — contracts under their callers, behaviour spread across files,
  transaction and failure paths, idempotency, and changed behaviour with no test.

## Step 3 — The acceptance criteria, once, over the whole change

Run only where `risk-classes.md`'s acceptance-criteria row is ✓, so skip it at
`mechanical` and `tiny`.

`review-changes`' PO pass sees one repo and would call everything the other side
delivers missing. Run the criteria review here instead, as **one** sub-agent over
the whole change with `subagent_type: acceptance-criteria` (shipped in `agents/`,
pinned to sonnet). With no definition, use `general-purpose` on `model: sonnet`.

Give it the repo list with each base and the story with its criteria; it pulls the
diffs itself. Point it at `<mr-review>/charter/stage_po.md` (resolve with
`bash "${CLAUDE_PLUGIN_ROOT}/scripts/mr-review-root.sh"`) rather than restating it.
Without the charter, tell it to classify the change FULL or PARTIAL, map every
criterion to addressed / partial / missing with evidence, treat scope creep and
silent behaviour changes as findings, and roll addressed criteria into one line.

On a **single-repo** change with a story, add `--maker` to Step 2's flags instead
and let `review-changes` own this. Leave it off on a split change, where it would
read the other repo's half as a divergence. **Skip `--maker` entirely when
`<primary-repo>/.vicaris/design-challenge-<branch>.md` exists** — the challenge
already asked the same question earlier. Say in the report which ran.

## Step 4 — The seam, if the change spans repos

With `--also-repo`, the integration pass owns the contract between repos — field
and enum agreement, request and response shape, consumer-side error and null
handling, and whether each interim merge state is safe. Treat its cross-repo
findings as blockers.

What remains yours, one line each: whether each piece sits in the right repo, and
the merge order.

## Step 5 — Synthesise (short, ranked, scannable)

Merge, de-duplicate, and resolve contradictions, saying which reviewer you sided
with and why. Write the review doc in the owner's preferred shape — scratch, don't
commit it:

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

**The design notes are read here and by no reviewer** — handing a reviewer the
author's rationale tells it what to conclude. Use each repo's
`.vicaris/design-notes-<branch>.md` only to resolve: a finding that proposes the
design line 3 rejected is a disagreement, so weigh the reviewer's failure case
against the author's and say which held; a finding the note is silent on is worth
a line. The design challenge doc weighs more: a reviewer reopening a divergence it
decided has to beat a named consequence, not a preference. Say which it did.

## Step 6 — Hand back the fix list

Ping Slack per `${CLAUDE_PLUGIN_ROOT}/references/notifications.md` when the review
starts (over which repos) and when it lands (counts by severity plus the headline
of anything non-trivial, never the full list).

Hand the ranked fix list to a fix pass — **one `builder` per pass**, on the class's
build model, given the decided list and the ledger path
(`${CLAUDE_PLUGIN_ROOT}/references/delegation.md`) — **applying each finding in the
repo it names**, re-verifying that repo with `scripts/vicaris-gate.sh`, and re-running the
contract tests if the seam moved. Findings are decided, not applied, with the
two-pass cap and the ledger at `<primary>/.vicaris/fix-ledger-<branch>.md`, all per
`${CLAUDE_PLUGIN_ROOT}/references/gates.md`. Stop early if a fix reverses one from
the previous pass: that is oscillation, and it wants a human eye.

## Deciding, not asking

`references/autonomy.md` holds the contract. The rows specific to this stage:

| Situation | What you do |
|---|---|
| `review-changes` would ask which passes to run | Never let it. Pass the flags in Step 2 and `--yes` |
| A repo in the manifest has no commits | Record it as having no changes and move on |
| The branch has no Jira key | Take the brief from `$ARGUMENTS`; with neither, skip Step 3 and say so |
| The story has no usable acceptance criteria | Skip the PO pass with the reason, rather than grading against a guess |
| The `mr-review` plugin is missing | Step 2b, and name the fallback in the report |
| Two reviewers contradict each other | Pick one, say which and why; do not report both and let the owner arbitrate |
| A finding is real but not worth fixing now | Park it under "Skip for now" — that is what the section is for |
| The review is enormous | Rank harder and report the ceiling you applied; never quietly truncate |
