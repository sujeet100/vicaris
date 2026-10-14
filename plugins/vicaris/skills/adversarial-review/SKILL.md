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

## Who runs what

Review waits on its reviewers and then on its fix passes, so it is split where it
waits, and the orchestrator holds every wait. An agent idle past the five-minute
prompt cache pays to rewrite its whole context when it resumes, and the lead that
used to run all of this did that at 260–290K tokens a time; the orchestrator's
context is the smallest in the run.

| Part | Runs on | Steps |
|---|---|---|
| Set-up: stage, scope, pass directory | the orchestrator | 1 |
| Reviewers, one `review-changes` per repo | `review-runner` (Haiku 5.5; the passes it launches pin their own models) | 2 |
| The acceptance-criteria pass, and the seam where needed | `acceptance-criteria`; a `lead` for the seam | 2b, 3 |
| Deciding: parity, synthesis, the ledger, the notes | one `lead` (Opus 5.5), spawned once every reviewer has reported | 2a, 4–6 |
| The one fix pass | the orchestrator spawns it (`vicaris` Step 3) | — |

The review writes under `<primary-repo>/.vicaris/review/pass-1/`, one file per
reviewer, so the decider reads files rather than reports and a resumed session can
see what ran. There is no second local round: the gate checks the fix pass, and the
MR review is the second review (`references/gates.md`, *Loop caps*).

## Step 1 — Establish the change, not the repo

Load the manifest per `${CLAUDE_PLUGIN_ROOT}/references/multi-repo.md`
(`<primary-repo>/.vicaris/repos-<branch>.txt`; none means just the current repo).
Skip a plugin reference only if it is already in your context (the orchestrator's
Step 0 loads them in its own session; a sub-agent has not seen them). Per repo, resolve the base and the
changed-file list — `--stat`, not the patch:

```bash
VM="${CLAUDE_PLUGIN_ROOT}/scripts/vicaris-manifest.sh"
bash "$VM" list "$MANIFEST" change | while IFS= read -r line; do
  repo=$(printf '%s' "$line" | cut -f1); BASE=$(printf '%s' "$line" | cut -f2)
  git -C "$repo" fetch --prune origin
  git -C "$repo" status --porcelain           # must be empty: the build committed
  git -C "$repo" diff "$BASE"...HEAD --stat
done
```

The base is each repo's manifest base, the branch its MR targets, never the local
branch and not necessarily the remote default. Every builder commits its repo when
its gate is green (`multi-repo.md`, *Commits*), so the change is `base...HEAD`. A repo
with uncommitted work at this point is a build that did not finish: send it back to
its builder rather than reviewing a tree a reviewer's `--base` diff would only partly
see. `$ARGUMENTS` may override `BASE`. `read` repos are context for the reviewers,
not a diff to review.

**Do not read the diffs into this context** — every reviewer fetches its own. The
acceptance criteria come from the understanding, which quotes them verbatim; Step 3
reads them there, so nobody fetches the story again.

Record which repos have changes. A `change` repo with none is fine; a repo with
changes that no pass covers is a failure.

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
- **`--also-repo` is not optional with more than one repo,** where the installed
  `review-changes` has it. It lets the mapper grep callers across repos; without it
  each repo reviews clean while the seam is broken. Check before the first
  invocation (`grep -c -- '--also-repo' "$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/mr-review-root.sh")"/skills/review-changes/SKILL.md`):
  a version without it (0.8.0 has none) ignores the flag silently, so drop it, and
  run Step 2b's **integration reviewer** once over every repo for the seam alone.
  Say which you did in the report.
- **One `review-runner` per repo**, given the invocation, the repo, its base and
  the pass directory. Run them in parallel only if `review-changes` writes to a
  per-run directory: 0.8.0 uses fixed `/tmp/review-*` paths (`grep -c mktemp` on its
  SKILL.md finds only the MAKER's), so its runs go one at a time, or concurrent runs
  silently read each other's briefs. The acceptance-criteria agent and the seam
  reviewer share nothing with it and go alongside the first runner.

Passes run on `opus`, except that `--quick` downgrades craft to sonnet and caps the
agents. Keep findings tagged with the repo name — the fix pass routes by that tag.

**Keep the reducer's JSON, not only its prose.** The runner copies
`/tmp/review-merged.json` and `/tmp/review-merged.txt` to
`review/pass-1/<repo>.json` and `.txt` before the next run overwrites them: the
JSON carries every finding by id with severity, quotes and location, plus a
`dropped` array of what the caps suppressed. The fix pass and
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

The orchestrator spawns three `lead` sub-agents (opus, high effort) in a single message, each writing to `review/pass-1/<role>.md` and getting instructions rather
than content: the repo list with paths and manifest `BASE`, the changed-file stat,
and the paths to `${CLAUDE_PLUGIN_ROOT}/references/coding-principles.md`,
`references/multi-repo.md` and `project-context.md`. Each pulls its own diffs
(`git -C "$repo" diff "$BASE"...HEAD`) across **every** `change` repo.

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
pinned to Sonnet 5.5). With no definition, use `general-purpose` on `model: sonnet`.

Give it the repo list with each base, the understanding's path for the criteria,
and `review/pass-1/acceptance.md` as the one file it writes; it pulls the diffs
itself. Point it at `<mr-review>/charter/stage_po.md` (resolve with
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
with and why. Write the review doc to `<primary-repo>/.vicaris/review-<branch>.md`
in the owner's preferred shape — scratch, don't commit it:

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

## Step 6 — Decide, and leave the fix list on disk

Ping Slack per `${CLAUDE_PLUGIN_ROOT}/references/notifications.md` when the review
starts (over which repos) and when it lands (counts by severity plus the headline
of anything non-trivial, never the full list).

Before handing anything over, take every decided finding that changes a design
decision (a rule, a contract's shape, an accepted limit, new behaviour the note does
not describe) and rewrite the section of that repo's note that states it, in place
(`design-note.md`, *Keeping it current*). You hold the decision; the builder carries
it out, and with no review over the fix pass, a decision formed inside it would ship
unexamined.

Then write the fix list as the ledger's `## review pass 1` section at
`<primary>/.vicaris/fix-ledger-<branch>.md` (`${CLAUDE_PLUGIN_ROOT}/references/gates.md`),
grouped by repo, blockers and should-fixes first and the suggestions you decided to
apply last, each line `apply` or `declined — reason`. A suggestion not worth a line
of the builder's time goes under *Skip for now*, not into the list. There is one fix
pass and nothing reviews it but the gate, so an `apply` should be a change the
builder can make without deciding anything.

Do not spawn the builders. Report, per repo, how many findings are `apply`. The
orchestrator spawns one `builder` per repo with the ledger path, so no single agent
carries the whole list through a growing context, and none of them waits on another.

## Deciding, not asking

`references/autonomy.md` holds the contract. The rows specific to this stage:

| Situation | What you do |
|---|---|
| `review-changes` would ask which passes to run | Never let it. Pass the flags in Step 2 and `--yes` |
| A `change` repo has no changes | Record it as having no changes and move on |
| The branch has no Jira key | Take the brief from `$ARGUMENTS`; with neither, skip Step 3 and say so |
| The story has no usable acceptance criteria | Skip the PO pass with the reason, rather than grading against a guess |
| The `mr-review` plugin is missing | Step 2b, and name the fallback in the report |
| Two reviewers contradict each other | Pick one, say which and why; do not report both and let the owner arbitrate |
| A finding is real but not worth fixing now | Park it under "Skip for now" — that is what the section is for |
| The review is enormous | Rank harder and report the ceiling you applied; never quietly truncate |
