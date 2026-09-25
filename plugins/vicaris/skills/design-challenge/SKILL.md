---
name: design-challenge
description: Before any code, compare the design note against a design built blind from the acceptance criteria, and decide each divergence.
argument-hint: [Jira key or brief, if the session does not already hold it]
allowed-tools: Bash, Read, Write, Glob, Grep, Agent, mcp__claude_ai_Slack__slack_send_message, mcp__claude_ai_Atlassian__getJiraIssue, mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql, mcp__claude_ai_Atlassian__getJiraIssueRemoteIssueLinks, mcp__claude_ai_Atlassian__getConfluencePage, mcp__claude_ai_Atlassian__searchConfluenceUsingCql
---

# Design challenge

**Owner:** ${user_config.owner_name}, the person this run acts for ("the owner" here
and in the references). Slack goes to member `${user_config.slack_user_id}`, else the
sidecar's Slack target, else record Slack as unavailable in the degraded list.

Every other pass inspects code that exists. None can see a wrong root decision,
because it looks like clean code implementing the wrong thing. The design note's
Q2 and Q3 compare alternatives the author chose between, after choosing; they
catch over-building, not a wrong approach. This stage builds a second design
independently, from the acceptance criteria alone, and only then holds the two
together — **before the first edit**, where a divergence costs a paragraph rather
than a rework.

## When it runs

Read `<primary-repo>/.vicaris/risk-<branch>.txt` against
`${CLAUDE_PLUGIN_ROOT}/references/risk-classes.md`: run at `elevated` and
`production`, skip at `mechanical`, `tiny` and `normal`. Skip a plugin reference only if it is already in your context (the orchestrator's
Step 0 loads them in its own session; a sub-agent has not seen them). With no risk file, run it when any of these holds:

- it **crosses a repo boundary** — the manifest has more than one entry with work
  planned in each;
- it **adds or reshapes a structural unit** — a module, class, node, tool, agent,
  endpoint or persisted type;
- it **changes a contract** another component or team consumes;
- it touches **schema or migrations, authentication or authorisation, money or
  quantities, or concurrency and shared state**;
- the plan recorded a fork where two approaches were genuinely close.

Skip it, with the reason in one line, for a bug fix with a local root cause, a
rename, a typo, a config edit, a behaviour-preserving refactor, or an addition
following an established pattern with no new concept — there is no contest to hold.

**Skip it too when there are no usable acceptance criteria**, and say so. A blind
design from a thin brief is a guess, and designing from the plan instead would
defeat the independence.

**Once per change, never a loop.**

## Step 1 — Assemble the brief, and nothing else

What you withhold is the entire value of the pass:

| Give it | Withhold |
|---|---|
| The story summary, description and acceptance criteria, verbatim | The plan, in any form |
| The Confluence pages the plan cited, by path or content | Every repo's `design-notes-<branch>.md` |
| Each repo at its **base commit**, extracted | The branch name and any commit messages |
| `coding-principles.md` and `project-context.md` | Your assumptions, your rejected alternatives, your framing of the problem |

Resolve the repo set and bases per `references/multi-repo.md`, then extract each
repo as it stood before the branch. `git archive` drops `.git` (no branch to read)
and everything untracked, including `.vicaris/` (no design notes to find):

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

**Confirm neither `.git` nor `.vicaris/` exists under `$WORK` before you spawn
anything.** Nothing downstream will tell you the agent read the notes.

Locate the charter in the `mr-review` plugin:

```bash
MRR=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/mr-review-root.sh") || MRR=""
```

Empty means the plugin is not installed: use Step 2b and name the fallback in the
output.

## Step 2 — Design it blind (one **fable** sub-agent, fresh context)

Spawn one agent with `subagent_type: blind-designer` (shipped in `agents/`).
**Never `fork`**: a fork inherits the author's context, which is the contamination
the extract removes. The definition makes the isolation structural — it pins fable
and grants only Read, Grep and Glob, so the agent cannot run `git` or leave the
extract. Keep it on a different model from whoever wrote the notes: a second design
from the same model tends to make the same root choices.

Its prompt carries only facts: the acceptance criteria, the extracted paths under
`$WORK`, and `$MRR/charter/blind_design.md` as the path to follow.

With no definition available, use `general-purpose` on `model: fable` and add:

> Work only inside `$WORK`. Do not read the original repositories, do not run
> `git`, and do not search for a branch, a plan or a design note. Design the
> change; do not try to reconstruct what someone else built.

> Where the brief leaves something open, record it as an assumption.

Keep its output as written — the charter's seven-section sketch, 400–700 words.
Do not summarise or correct it before Step 3; your disagreement is an input to the
comparison, not a filter on it.

### Step 2b — Fallback when the charter is unavailable

Same agent, same isolation, same extract. Tell it: you are a senior engineer on
this service, handed this story; produce the design you would build before writing
any code. Seven sections — problem, approach, root decisions, concepts introduced,
proofs, assumptions, existing design friction. Every decision carries a proof: the
concrete input, caller or state that makes it necessary. Real file paths and type
names, no hedging toward what someone else might have chosen.

## Step 3 — Compare the two (one **opus** sub-agent, fresh context)

Spawn one `lead` (`subagent_type: lead`, opus at high effort). It receives both designs as text — the blind
sketch and every repo's design note — and reads `$MRR/charter/blind_compare.md`,
told this:

> Skip the charter's "Reconstruct before you read the sketch closely" section.
> Both sides are already designs, so compare decisions directly.

The rest of the charter applies unchanged. Without the charter, tell it: classify
differences rather than list them, dismiss wording-only and house-convention
differences, and count a divergence only with a named consequence and a proof. One adaptation to its evidence rule,
since nothing is built yet: the author's side may claim a constraint the blind
designer could not reach only by citing it — a file and line, a migration, a DTO,
a client call, or a shipped contract in a sibling repo. A constraint asserted from
the story, a ticket's tech notes or the plan does not count, and one written down
nowhere is itself the finding.

Ask it for, in order: the material divergences, each with the decision at stake,
the side it favours and the concrete consequence of getting it wrong; the
dismissed differences, one line each; and one sentence on whether the two designs
agree about the **problem**.

## Step 4 — Decide, and record the decision

Every material divergence ends in one of two states; "noted" is not one:

- **Adopted** — amend the affected repo's `design-notes-<branch>.md` in place.
  Where this invalidates the plan's approach, the design note wins; say so and
  carry on rather than re-planning.
- **Declined** — name the failure case the blind design does not survive: the
  input, caller, state or citable constraint. "Ours is cleaner" and "the plan
  already decided this" are not reasons.

Nothing material is a real result; say it in one line.

## Step 5 — One artifact, one ping

Write `<primary-repo>/.vicaris/design-challenge-<branch>.md` (scratch, never
committed; `finalize` reads it for the assumptions section). Keep it short:

- **Ran / skipped** — which, and the trigger or the reason.
- **The blind design** — its approach and root decisions in a few lines, plus
  the path to the full sketch if you kept it.
- **Divergences** — one short paragraph each: the decision, which design won,
  the consequence named, and adopted or declined with the citation.
- **Agreement on the problem** — one line; flag it hard if the two designs were
  solving different problems.
- **Design notes amended** — the repos and what changed in each.

Then ping the Slack thread once, per `${CLAUDE_PLUGIN_ROOT}/references/notifications.md`:
the decisions that shape the change, the alternative that lost, and one line on
what it would have cost. Skip the ping when the challenge was skipped or found
nothing.

## Deciding, not asking

Divergences are resolved and recorded here, never handed back as questions;
`references/autonomy.md` governs the rest. When the blind design is clearly better
and adopting it discards work the plan specified, adopt it — nothing has been
built yet. On a late challenge (the class rose at the gate), weigh the rework
against the named consequence instead, and record the call either way.
