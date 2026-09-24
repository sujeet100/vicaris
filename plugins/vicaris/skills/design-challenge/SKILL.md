---
name: design-challenge
description: Hold the design note against a second design built independently from the acceptance criteria alone, before any code is written. One fable agent designs blind at the base commit, one opus agent compares the two, and the divergences are decided and recorded. Runs on cross-repo, structural and production-risk changes; skipped with a reason on everything else.
argument-hint: [Jira key or brief, if the session does not already hold it]
allowed-tools: Bash, Read, Write, Glob, Grep, Agent, mcp__claude_ai_Slack__slack_send_message, mcp__claude_ai_Atlassian__getJiraIssue, mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql, mcp__claude_ai_Atlassian__getJiraIssueRemoteIssueLinks, mcp__claude_ai_Atlassian__getConfluencePage, mcp__claude_ai_Atlassian__searchConfluenceUsingCql
---

# Design challenge

Every other pass in this workflow inspects code that exists and asks whether it
is correct, well shaped and readable. None of them can see a wrong root
decision, because a wrong root decision does not look like a smell — it looks
like clean, well-named code implementing the wrong thing, and it is invisible
without something to compare against. This stage builds that something.

The comparison the design note already makes is not this one. Its Q2 sets a
fresh design against the existing code and its Q3 names a simpler design that
was rejected, both written by the pass that had already chosen, after it chose.
That catches over-building and it is worth keeping. What it cannot catch is the
approach itself, because the approach came from the plan and the plan is not one
of the two things being compared. Here both designs are produced independently,
neither knows the other exists, and only then are they held together.

**It runs before the first edit.** Two designs compared cost a paragraph to
resolve; a design compared against a finished diff costs a rework.

## When it runs

**The risk class decides, and the class is in one file.** Read
`<primary-repo>/.vicaris/risk-<branch>.txt` against
`${CLAUDE_PLUGIN_ROOT}/references/risk-classes.md`: this stage runs at `elevated`
and `production`, and is skipped at `mechanical`, `tiny` and `normal`. With no risk
file, fall back to the triggers below, which are what the class is derived from
anyway.

Those triggers, for the fallback and for understanding what the class encodes — run
it when any of these is true of the change:

- it **crosses a repo boundary** — the manifest has more than one entry with work
  planned in each;
- it **adds or reshapes a structural unit** — a module, class, node, tool, agent,
  endpoint or persisted type;
- it **changes a contract** another component or team consumes;
- it touches **schema or migrations, authentication or authorisation, money or
  quantities, or concurrency and shared state**;
- the plan recorded a fork where two approaches were genuinely close.

Skip it, and say so in one line with the reason, when the change is a bug fix
with a local root cause, a rename, a typo, a config edit, a behaviour-preserving
refactor, or an addition that follows an established pattern in the repo with no
new concept in it. Those changes have no design contest to hold, and running one
produces an alternative invented for the occasion.

**Skip it too when there are no usable acceptance criteria.** The blind design
is built from the requirement and nothing else, so a thin brief produces a
sketch that is really a guess, and comparing against a guess is worse than not
comparing. Say that plainly rather than designing from the plan, which would
defeat the independence this stage exists for.

**Once per change, never a loop.** The output is a decision, not a round of
negotiation.

## Step 1 — Assemble the brief, and nothing else

The blind designer gets the requirement and the codebase as it stands before the
change. It gets no part of your reasoning, and the discipline about what to
withhold is the entire value of the pass:

| Give it | Withhold |
|---|---|
| The story summary, description and acceptance criteria, verbatim | The plan, in any form |
| The Confluence pages the plan cited, by path or content | Every repo's `design-notes-<branch>.md` |
| Each repo at its **base commit**, extracted | The branch name and any commit messages |
| `coding-principles.md` and `project-context.md` | Your assumptions, your rejected alternatives, your framing of the problem |

Resolve the repo set and each base the usual way
(`${CLAUDE_PLUGIN_ROOT}/references/multi-repo.md`), then extract each repo as it
stood before the branch. The extract matters: it removes `.git`, so there is no
branch to read, and it leaves `.vicaris/` behind, so the design notes cannot be
found by an agent that goes looking:

```bash
PRIMARY=$(git rev-parse --show-toplevel)
BRANCH=$(git rev-parse --abbrev-ref HEAD)
MANIFEST="$PRIMARY/.vicaris/repos-$BRANCH.txt"
REPOS=$( [ -f "$MANIFEST" ] && cat "$MANIFEST" || echo "$PRIMARY" )

WORK=$(mktemp -d "${TMPDIR:-/tmp}/vicaris-blind-XXXXXX")
for repo in $REPOS; do
  name=$(basename "$repo")
  BASE=$(git -C "$repo" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null \
    || git -C "$repo" remote show origin | sed -n 's|.*HEAD branch: |origin/|p')
  mkdir -p "$WORK/$name"
  git -C "$repo" archive "$BASE" | tar -x -C "$WORK/$name"
done
```

The extract is doing two jobs, and the second is the one to check before launching:
it gives the agent the code as it stood before the branch, and it strips `.git` and
everything untracked, which is what puts `.vicaris/` — the plan, the design notes,
the manifest — out of reach. Confirm neither exists under `$WORK` before you spawn
anything. An agent that can read the design notes is not a blind designer, and
nothing downstream will tell you that it read them.

Locate the charter, which lives in the `mr-review` plugin:

```bash
MRR=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/mr-review-root.sh") || MRR=""
```

If that comes back empty the plugin is not installed. Fall back to Step 2b, and
name the fallback in the output — a challenge that quietly ran without the
charter is worth less than one that says it did.

## Step 2 — Design it blind (one **fable** sub-agent, fresh context)

Spawn a single agent with `subagent_type: blind-designer`, the definition this
plugin ships in `agents/`. Never `fork`: a fork inherits this session's context,
which is the author's context, and reintroduces exactly the contamination the
extract was built to remove.

Use the definition rather than an inline prompt, because it is what makes the
isolation structural. It pins the model to fable and grants **only Read, Grep and
Glob** — no Bash, so the agent cannot run `git`, cannot reach outside the extract,
and cannot go looking for the branch, the plan or the design notes even if it
decides to. Withholding by instruction and withholding by capability look the same
right up until an agent drifts, and nothing downstream reports that it read what
you asked it not to.

The model is part of the same isolation. The design notes were written on opus, and
a second design from the same model tends to make the same root choices for the
same reasons, which turns the comparison into agreement with itself. Fable makes
different mistakes, and that is what makes it worth comparing against. So keep
the blind designer on a different model from whoever wrote the notes, even where
it costs more than the pass it is checking.

Its prompt then carries only facts: the acceptance criteria, the extracted paths
under `$WORK`, and `$MRR/charter/blind_design.md` as the path to follow.

With no definition available, fall back to `general-purpose` on `model: fable` and
add the two lines the definition otherwise makes unnecessary:

> Work only inside `$WORK`. Do not read the original repositories, do not run
> `git`, and do not search for a branch, a plan or a design note. Design the
> change; do not try to reconstruct what someone else built.

> Where the brief leaves something open, record it as an assumption. A stated
> assumption is information the comparison can use; a silent one is a guess
> wearing a design's clothes.

Keep its output as written — the seven-section sketch the charter specifies,
400–700 words. Do not summarise it before the comparison sees it, and do not
correct it where you disagree. Your disagreement is one of the two inputs to
Step 3, not a filter on the other one.

### Step 2b — Fallback when the charter is unavailable

Same agent, same isolation, same extract. Tell it: you are a senior engineer on
this service, you have been handed this story, produce the design you would
build before writing any code. Seven sections — problem, approach, root
decisions, concepts introduced, proofs, assumptions, existing design friction.
Every decision carries a proof: the concrete input, caller or state that makes
it necessary. Real file paths and real type names, no hedging toward what
someone else might have chosen.

## Step 3 — Compare the two (one **opus** sub-agent, fresh context)

Spawn one agent with `model: opus`. It receives both designs as text — the blind
sketch and every repo's design note — and reads `$MRR/charter/blind_compare.md`,
with one modification it must be told about:

> Skip the charter's "Reconstruct before you read the sketch closely" section.
> It exists because that pass normally holds a design against finished code and
> has to render the code as a design first. Here both sides are already designs,
> so read them in the order given and compare decisions directly.

Everything else in that charter applies unchanged and is what keeps the pass
honest: differences are classified rather than listed, same decision in
different words is dismissed silently, a root disagreement is a finding only
when a concrete consequence can be named, a decision whose proof is missing from
the sketch cannot be a finding however much the sketch prefers it, and house
convention is out of scope because neither side was free.

One adaptation to the charter's evidence rule, since nothing has been built yet.
The author's side may still claim a constraint the blind designer could not
reach, but it has to cite it: a file and line, a migration, a DTO, a client call,
or a shipped contract in a sibling repo. A constraint asserted from the story, a
ticket's tech notes or the plan does not count, and a constraint that turns out
to be written down nowhere is itself the finding.

Ask it for, in this order: the material divergences, each with the decision at
stake, the side it favours, and the concrete consequence of getting it wrong;
then the differences it dismissed, in one line each, so you can see what it
considered; then one sentence on whether the two designs agree about the
**problem**, which is the disagreement that matters most and the one that reads
as agreement until someone checks.

## Step 4 — Decide, and record the decision

This step is yours and it is not a formality. Every material divergence ends in
one of two states, and "noted" is not one of them:

- **Adopted** — amend the affected repo's `design-notes-<branch>.md` in place, so
  what gets built matches what was decided. Where the change invalidates the
  plan's approach, the design note wins; say so and carry on rather than
  re-planning. The plan settled the approach on less information than you now
  have, and that is the ordinary case rather than a failure.
- **Declined** — name the failure case the blind design does not survive: the
  input, the caller, the state, or the constraint you can cite. "Ours is
  cleaner" is not a reason, and neither is "the plan already decided this."

If the comparison returns nothing material, that is a real result and worth one
line. Two independent designs reaching the same shape is the strongest evidence
this workflow can produce that the shape is right, and it costs less to say than
to re-derive later.

## Step 5 — One artifact, one ping

Write `<primary-repo>/.vicaris/design-challenge-<branch>.md` — the primary repo,
because the challenge is about the change rather than about any one repo's code
(`references/multi-repo.md`). Scratch, never committed. Keep it short:

- **Ran / skipped** — which, and the trigger or the reason.
- **The blind design** — its approach and root decisions in a few lines, plus
  the path to the full sketch if you kept it.
- **Divergences** — one short paragraph each: the decision, which design won,
  the consequence named, and adopted or declined with the citation.
- **Agreement on the problem** — one line, and flag it hard if the two designs
  were solving different problems, because that is the finding this stage exists
  to produce.
- **Design notes amended** — the repos and what changed in each.

`finalize` reads this file for the completion doc's assumptions section, which is
the point of writing it down: an assumption backed by a contest between two
independent designs is evidence, where the same assumption backed by a
self-critique reads as justification.

Then ping the Slack thread once, per `${CLAUDE_PLUGIN_ROOT}/references/notifications.md`:
the decision or decisions that shape the change, the alternative that lost, and
one line on what it would have cost. Skip the ping entirely when the challenge
was skipped or found nothing — a milestone with no content in it is noise, and
this is the one stage whose ping is worth reading closely.

## Deciding, not asking

This stage runs unattended like every other. A divergence is resolved here and
recorded, never handed back as a question, and
`${CLAUDE_PLUGIN_ROOT}/references/autonomy.md` governs anything not settled above. One case is worth naming because it feels like an escalation and is not:
when the blind design is clearly better and adopting it means discarding work
the plan specified, adopt it. Nothing has been built yet, which is exactly why
this stage runs where it does.
