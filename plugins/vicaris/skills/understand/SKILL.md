---
name: understand
description: Establish what a change must satisfy before design — acceptance criteria with rejected readings, gaps, repos in scope, constraints — and set its risk class.
argument-hint: [Jira key, task description, or feature brief]
allowed-tools: Bash, Read, Write, Glob, Grep, Agent, mcp__claude_ai_Atlassian__getJiraIssue, mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql, mcp__claude_ai_Atlassian__getJiraIssueRemoteIssueLinks, mcp__claude_ai_Atlassian__getConfluencePage, mcp__claude_ai_Atlassian__searchConfluenceUsingCql, mcp__claude_ai_Atlassian__getPagesInConfluenceSpace, mcp__claude_ai_Atlassian__getConfluencePageDescendants, mcp__claude_ai_Atlassian__getConfluenceSpaces
---

# Understand

**Owner:** ${user_config.owner_name}, the person this run acts for ("the owner" here
and in the references). Slack goes to member `${user_config.slack_user_id}`, else the
sidecar's Slack target, else record Slack as unavailable in the degraded list.

Establish what `$ARGUMENTS` has to be true of, and how much ceremony the rest of
the run earns. Read and decide; do not design or edit code.

**Model:** Opus 5.5, medium effort (the `analyst` agent). Run directly on another
model, delegate to an `analyst` sub-agent.

## Step 1 — Load the bar

Read `${CLAUDE_PLUGIN_ROOT}/references/` `autonomy.md`,
`risk-classes.md`, `multi-repo.md` and `project-context.md` (if present), plus the
project's `CLAUDE.md` and convention docs. This stage runs as a sub-agent, so read
all of them; none is in your context yet.

## Step 2 — Establish what has to be true

If `$ARGUMENTS` is a Jira key, fetch the story and **follow it to Confluence**
(remote links, pages in the description; search by key and feature name if none
are linked). Then read the code the change touches before concluding anything.

Write the acceptance criteria as a **numbered list** of statements true or false
of the finished system; quote stated ones, and mark derived ones with their source.

**For every criterion that admits more than one reading, write the reading you
are taking and the one you are rejecting, one line each.** Nothing downstream can
ask, so this is what lets a human catch a misreading from the Slack message.

Then, in their own short sections:

- **Contradictions** — criteria that cannot both hold, or that current code
  contradicts; name both sides and which you proceed on.
- **Gaps** — what the implementation must decide that the story does not say:
  empty states, limits, permissions, ordering, existing data, failure UX.
- **Sources** — every page and code path used, or "none found".

## Step 3 — What the change could break

This step sets the risk class: every row answered yes carries its tag into Step 4
and its check into Step 6. Answer **every** row in one line, either what is true for
this change or `n/a` with the reason; a blank is a finding. State constraints on the
design, never the design. At `mechanical` and `tiny`, the first row, the last two rows
and any row that is not `n/a` are enough.

| Row | Answer | Yes carries |
|---|---|---|
| Effects that can't be undone | What switching it on writes, sends or moves that switching it off does not take back: downstream copies, messages, external calls, payments | `production`, plus `money` if it moves money |
| Stored data | The migration, whether it reverses, the rows already there, and what rows written by the old code during the deploy window become | `schema` |
| Who can see or do what | The permission or tenancy rule being changed, who gains access, and the test that proves nobody else did | `authz` |
| Contracts | Every consumer of what changes, including a name or id another system uses as a key; whether old and new coexist for one release; the merge order | `public-contract` |
| Shared state and retries | The shared thing and the interleaving that must not lose a write, and what happens when an operation runs twice | `concurrency` |
| Config and environments | The environments it reaches, which one switches first, and what each needs in place before it does | `infra` |
| New dependency | What it replaces, its size and licence, and what writing it ourselves would cost | `dependency` |
| Existing users | Before and after, including stored state (saved searches, bookmarks, settings) that will now behave differently, and who else it reaches: other regions, tenants or clients | a test |
| Hot path | The current cost, the expected cost, and the number that would show a regression | a test |
| Turning it off | How it is turned off without a deploy, by default a runtime toggle that keeps the old path, and what must stay byte-identical while it is off | a parity test |
| Knowing it broke | The log, metric or alert that would show it misbehaving in production, or that none exists | a test, or a gap |

Then answer the rows `project-context.md` adds under *Understand: extra rows*, if
present, the same way: risks only that domain has, such as money arithmetic or
model behaviour, live there rather than here.

## Step 4 — Classify the risk, and write it down

Emit exactly one class from `references/risk-classes.md` — `mechanical`, `tiny`,
`normal`, `elevated` or `production` — to the file every later stage reads:

```bash
PRIMARY=$(git rev-parse --show-toplevel); BRANCH=$(git rev-parse --abbrev-ref HEAD)
mkdir -p "$PRIMARY/.vicaris"
cat > "$PRIMARY/.vicaris/risk-$BRANCH.txt" <<EOF
RISK: <class> · tags: <schema,authz,money,concurrency,infra,dependency,public-contract,prompt or none>
why: <one line — the trigger that set it>
EOF
```

The tags are Step 3's: `schema`, `authz`, `money` or an effect that can't be
undone make it `production`, and any other tag makes it at least `elevated`, as
`scripts/vicaris-risk.sh` will on the diff. **Default upward** between two classes. **Say `mechanical` only when you can
point at the instances the change copies** — it drops the craft pass.

## Step 5 — Repos in scope

List every repo the change reads from or touches, in **dependency order**,
producer before consumer, each with three things the manifest records:

- its **role**: `change` if the change edits it, `read` if it is only read for
  context. A repo whose code you read to understand a contract, but which the
  change leaves alone, is `read`; listing it as `change` would branch it, review
  an empty diff and count it toward the breadth that raises the risk class.
- its **target branch**, the one its MR merges into: the story's, the sidecar's, or
  the remote default when neither names one. Deployment and config repos often
  target an environment branch (`us-qa`, `uat`) rather than `main`, and the base
  decides every diff the run takes.
- its freshness (`current` / `behind, not synced because …`):

```bash
git fetch --prune origin && git status -sb   # look for "behind"
```

This becomes the manifest (`multi-repo.md`); an omitted `change` repo gets no branch,
review or MR. Across
repos, name the **contract** — who owns it, what it carries — and whether the MRs
can merge in any order, without designing it. A repo you cannot bring current is
reported, not reasoned about.

## Step 6 — The test surface

Name the tests the change needs, one line each, **derived from the acceptance
criteria and the Step 3 failure modes, not from a design**. Concise but
sufficient: the behaviour and the edges that matter, no test of the framework.
Behaviour the change must preserve gets a parity test. Where a criterion
cannot be tested, say why.

## Step 7 — Emit the understanding

Write `<primary-repo>/.vicaris/understanding-<branch>.md` (the hooks look
there). Scratch — never committed or cited in a commit message.

Sections, in this order: Goal · Acceptance criteria with rejected readings (each
criterion quoted verbatim first, since the acceptance-criteria pass grades against
that text and reads it here rather than fetching the story) ·
Contradictions · Gaps · What the change could break · Risk class and why · Repos
in scope, contract, merge order · Test surface · Sources.

**Do not list the files to change.** Each section carries what a later stage acts on:
the criteria and the readings rejected, not a retelling of the story or of the code
you read to reach them. The opening Slack message is drawn from it.
