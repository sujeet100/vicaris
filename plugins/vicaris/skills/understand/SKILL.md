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

**Model:** opus, high effort. Run directly on another model, delegate to an opus
sub-agent.

## Step 1 — Load the bar

Read `${CLAUDE_PLUGIN_ROOT}/references/` `autonomy.md`, `coding-principles.md`,
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

## Step 3 — Non-functional constraints

Answer only the rows that apply, one line each; `n/a` plus reason is an answer,
a blank is a finding.

| The change touches… | State |
|---|---|
| Persisted data or a schema | The migration, whether it reverses, and what happens to rows written by the old code during the deploy window |
| An API or event another component consumes | Who consumes it today, and whether old and new can coexist for one release |
| Authentication, authorisation or tenancy | The rule being changed, who gains access, and the test that proves nobody else did |
| Money, billing or quantities | The unit, the rounding, and the idempotency of anything retryable |
| Concurrency or shared state | The shared thing, and the interleaving that must not lose a write |
| A new dependency | What it replaces, its size and licence, and what writing it ourselves would cost |
| User-visible behaviour | Before and after, and whether anything existing breaks |
| Performance on a hot path | The current cost, the expected cost, and how you would know if it regressed |
| Anything with a blast radius | How this is turned off without a deploy |

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

**Default upward** between two classes. **Say `mechanical` only when you can
point at the instances the change copies** — it drops the craft pass.

## Step 5 — Repos in scope

List every repo the change reads from or touches, in **dependency order**,
producer before consumer, each with its freshness (`current` /
`behind, not synced because …`):

```bash
git fetch --prune origin && git status -sb   # look for "behind"
```

This becomes the manifest; an omitted repo gets no branch, review or MR. Across
repos, name the **contract** — who owns it, what it carries — and whether the MRs
can merge in any order, without designing it. A repo you cannot bring current is
reported, not reasoned about.

## Step 6 — The test surface

Name the tests the change needs, one line each, **derived from the acceptance
criteria and the Step 3 failure modes, not from a design**. Where a criterion
cannot be tested, say why.

## Step 7 — Emit the understanding

Write `<primary-repo>/.vicaris/understanding-<branch>.md` (the hooks look
there). Scratch — never committed or cited in a commit message.

Sections, in this order: Goal · Acceptance criteria with rejected readings ·
Contradictions · Gaps · Non-functional constraints · Risk class and why · Repos
in scope, contract, merge order · Test surface · Sources.

**Do not list the files to change.** Keep it short: it feeds the run's opening
Slack message.
