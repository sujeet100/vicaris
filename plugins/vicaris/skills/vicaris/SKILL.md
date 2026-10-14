---
name: vicaris
description: Run a story end to end — understand, design, build, review, test, finalize — across every repo it touches, without asking questions, reporting in one Slack thread.
argument-hint: [Jira key, task description, or feature brief]
model: claude-opus-5-5
effort: medium
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Agent, Skill, mcp__claude_ai_Slack__slack_send_message, mcp__claude_ai_Atlassian__getJiraIssue, mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql, mcp__claude_ai_Atlassian__getJiraIssueRemoteIssueLinks, mcp__claude_ai_Atlassian__getConfluencePage, mcp__claude_ai_Atlassian__searchConfluenceUsingCql, mcp__claude_ai_Atlassian__getPagesInConfluenceSpace, mcp__claude_ai_Atlassian__getConfluencePageDescendants, mcp__claude_ai_Atlassian__getConfluenceSpaces, mcp__claude_ai_Atlassian__addCommentToJiraIssue, mcp__claude_ai_Atlassian__createConfluencePage, mcp__claude_ai_Atlassian__updateConfluencePage
---

# Vicaris (orchestrator)

**Owner:** ${user_config.owner_name}, the person this run acts for ("the owner" here
and in the references). Slack goes to member `${user_config.slack_user_id}`, else the
sidecar's Slack target, else record Slack as unavailable in the degraded list.

Take `$ARGUMENTS` to a reviewed, tested, finalized change with no manual
intervention. This skill sequences the stages; each stage skill owns its own steps,
so follow it rather than a summary here.

**Load each thing once, in this session.** Step 0 reads every reference. When a stage
skill later says to read one, it is already in your context: do not read it again.
This is about your own context; a sub-agent starts empty and reads what its skill
names. Stage skills run inside the sub-agents, which read them themselves; the one
you invoke here is `handover`, the first time, and at later boundaries you follow its
write step from context, invoking it again only if a compaction dropped its field list.

## Step 0 — Session setup

1. Read `${CLAUDE_PLUGIN_ROOT}/references/`: `autonomy.md` (never ask, whole scope,
   the closed blocker list), `risk-classes.md`, `gates.md`, `multi-repo.md`,
   `notifications.md`, `delegation.md`, and `project-context.md` if present.
   `coding-principles.md` is for the agents that write code, and they read it.
2. **Keep the machine awake**, and record the PID, because finalize kills *this*
   process only (a pattern kill can take down a session launched under
   `caffeinate`):
   ```bash
   nohup caffeinate -dimsu -t 21600 >/dev/null 2>&1 &   # 6h safety cap
   echo $! > "$PRIMARY/.vicaris/caffeinate-$BRANCH.pid"
   ```
3. Confirm the repo: `git rev-parse --show-toplevel`.
4. **Branch off the fresh remote default**, never local HEAD. This is provisional
   until the understanding names the primary's target branch (Step 1b):
   ```bash
   git fetch --prune origin
   BASE=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null \
     || git remote show origin | sed -n 's|.*HEAD branch: |origin/|p')
   git status --porcelain          # must be empty
   ```
   - Dirty tree → work in a worktree per `multi-repo.md`; never touch the owner's
     uncommitted work and never ask about it.
   - Clean tree → `git switch -c "$BRANCH" "$BASE"`, with the **Jira key first**
     (`PROJ-1234-short-slug`); `adversarial-review` reads the key from the branch.
     No key: plain slug, and pass the brief to that stage explicitly.
   - Resuming a branch: report how far behind `$BASE` it is; rebase only if clean,
     otherwise `git rebase --abort`, continue, and record the staleness.
   - Never work on the default branch.
5. Fetch and freshness-check every other repo you already know the task touches;
   branching them waits for Step 1b.
6. **Probe what fails silently**, and write each missing one to
   `<primary>/.vicaris/degraded-<branch>.txt` for the completion doc: the Slack send
   tool; the Atlassian issue tool (if `$ARGUMENTS` is a key); a browser tool (if
   the change is likely user-visible); `bash "${CLAUDE_PLUGIN_ROOT}/scripts/mr-review-root.sh"`
   printing a path. Say at the start if Slack is missing.
7. **Pass the owner on.** Sub-agents reading a skill as a file see `${user_config.…}`
   unfilled, so every sub-agent prompt that can reach Slack or the owner carries
   the name and Slack member ID as plain text.
8. **Model and effort:** this skill's frontmatter runs the orchestrator on Opus 5.5
   at medium, for the turn the run happens in; a message from the owner mid-run
   starts a new turn on the session's own model, so say so in the degraded list if
   that happens. Each stage's model and effort come from its agent definition
   (`delegation.md`), pinned by full ID.

**Delegation.** `delegation.md` decides which shipped agent runs each stage, on which
model and effort, and what each prompt carries. Its short form: you sequence and
check; every stage is one sub-agent — `lead` where it judges, `builder` where it
executes. Fable is the blind designer only, so it differs from the model that wrote
the notes.

## Step 1 — Understand

Spawn `analyst` (`subagent_type: analyst`) running the `understand` skill on
`$ARGUMENTS`, so the story and linked pages stay out of this long-lived context. It
writes `<primary>/.vicaris/understanding-<branch>.md` and
`<primary>/.vicaris/risk-<branch>.txt`.

**Read the risk file and hold the class for the whole run.** If it is missing,
classify from `risk-classes.md` and write it yourself; an absent class silently
means "do everything".

### Step 1b — Pin the repo set and branch it

Write the understanding's **Repos in scope** to the manifest, dependency order,
primary first, one line per repo with its **base** (the branch the MR targets, which
is the one to cut from) and its **role**: `change` if the run edits it, `read` if it
is only context. The format and why each field exists are in `multi-repo.md`.

```bash
mkdir -p "$PRIMARY/.vicaris"
printf '%s\t%s\t%s\n' \
  "$PRIMARY"                 origin/main   change \
  /path/to/deployment-repo   origin/us-qa  change \
  /path/to/schema-repo       origin/main   read \
  > "$PRIMARY/.vicaris/repos-$BRANCH.txt"
```

Every script reads the base from here, so a wrong base is a wrong diff in every
later stage: the risk check, the reviews and the MR all see the base's history as
this change. If the primary's base is not the one Step 0.4 cut from and nothing has
been written yet, re-create the branch from the right base now.

Apply Step 0.4 to every unbranched `change` repo, off **its manifest base** rather
than the remote default; fetch `read` repos and leave them on their own branch. Then
exclude `.vicaris/` locally in each (never in the tracked `.gitignore`):

```bash
cut -f1 "$PRIMARY/.vicaris/repos-$BRANCH.txt" | while read -r repo; do
  GITDIR=$(git -C "$repo" rev-parse --git-common-dir)   # a worktree's .git is a file
  case "$GITDIR" in /*) ;; *) GITDIR="$repo/$GITDIR" ;; esac
  grep -qxF '.vicaris/' "$GITDIR/info/exclude" 2>/dev/null \
    || echo '.vicaris/' >> "$GITDIR/info/exclude"
done
```

From here every stage covers every `change` repo in the manifest, and `read` repos
stay untouched (`multi-repo.md` has the table).

### Step 1c — Open the Slack thread

Post the parent message: ticket, one-line goal, repos, branch, risk class, and
**the two to four acceptance criteria whose reading could be wrong, each with the
reading you took**, ending "proceeding on this reading." It is the one cheap moment
for a human to correct a misreading; skip that block only if nothing was open.
Never wait for a reply.

```bash
echo "<ts>" > "$PRIMARY/.vicaris/slack-thread-$BRANCH.txt"
```

Ping at each stage boundary per `notifications.md`.

## Step 2 — Implement

The `implement` skill runs in two sub-agents:

1. **Design** — `lead` runs its Steps 1–2c: the Step 1 rules and every repo's design
   note to disk, then the `design-challenge` skill, which spawns its own two agents
   and amends the notes where a divergence is adopted.
2. **Build** — you spawn `builder` per its Step 2d, and check its verify files and note amendments before the gate.

**Decision requests.** A builder that reaches a choice the design note does not
settle (a contract shape, behaviour the note does not describe, a criterion read
differently, a note assumption proven false) writes it to
`<primary>/.vicaris/decision-requests-<branch>.md`, carries on with the work that does
not depend on it, and says so in its report. When the report names one, spawn a short
`lead` with the request file, the understanding and the affected note: it decides,
amends the note's decision log, and marks the request answered. Then resume the
builder on the dependent work. This keeps design decisions with the model that made
the design, and costs one short agent instead of a build that guessed.

Then refresh the handover doc.

## Step 2d — The gate

Nothing expensive starts until these are green (`gates.md`):

```bash
# 1. every change repo's verify, current for the code as it stands. The builder ran
#    the gate; --check confirms that result is about this exact tree and costs
#    nothing. Re-run the gate only for a repo it reports as failing or stale.
bash "${CLAUDE_PLUGIN_ROOT}/scripts/vicaris-gate.sh" --check "$repo" \
  || bash "${CLAUDE_PLUGIN_ROOT}/scripts/vicaris-gate.sh" "$repo" "$VERIFY_CMD"

# 2. the class, re-derived from the paths actually touched — raise-only
bash "${CLAUDE_PLUGIN_ROOT}/scripts/vicaris-risk.sh" \
  "$PRIMARY/.vicaris/repos-$BRANCH.txt" "$PREDICTED_CLASS" \
  --write "$PRIMARY/.vicaris/risk-$BRANCH.txt"
```

Both see uncommitted work, so they are meaningful before anything is committed.
Exit 3: the class rose and the file is updated. Say so in the thread and run what the
new class earns, including a late design challenge. Exit 4: nothing observed; keep
the predicted class and say the check did not run. The risk file keeps the
prediction's tags and reason and adds an `observed:` line, so a later stage reads both.

**At `production` with the `schema` tag, rehearse the migration first**: up against a
scratch database per the sidecar, down, up again. With no migration command in the
sidecar, add a line to `degraded-<branch>.txt`, record the rehearsal as **not run** in
the completion doc and MR description, and treat reversibility as unverified.

Then the **integrated smoke** where the class calls for it: the stack up on each
repo's branch build, one happy path end to end.

A gate failure is not a blocker: fix, re-run, continue.

## Step 3 — Adversarial review, and its fix loop

You run this loop, because it is where the run waits longest: on reviewers, then on
fix passes, then on reviewers again. Whoever resumes after a wait past the
five-minute prompt cache rewrites their whole context, and yours is the smallest in
the run. So every agent below is short, starts with its inputs already on disk, and
never waits on another. `adversarial-review`'s *Who runs what* says what each one
does; this is the order.

1. **Set up** (its Step 1, yourself): stage each `change` repo, take the stat, make
   `<primary>/.vicaris/review/pass-<N>/`. Read the class from the risk file.
2. **Review.** One `review-runner` per `change` repo with changes, with the class's
   invocation (its Step 2). With the first runner, in the same message: the
   `acceptance-criteria` agent where the class earns it (its Step 3), and, when the
   change spans repos and the installed `review-changes` has no `--also-repo`, a
   `lead` running Step 2b's integration brief over every repo for the seam. Runners
   go one at a time on a `review-changes` with fixed `/tmp` paths (0.8.0), all
   together otherwise. At `mechanical` there are no runners; go to 3.
3. **Decide.** Once every reviewer has reported, one `lead` running Steps 2a and 4–6
   with the pass directory, the ledger, every repo's design notes and the design
   challenge. It writes the review doc, this pass's ledger section and any note
   amendments, and reports per repo how many findings are `apply`.
4. **Fix.** If any are, and fewer than two fix passes have run: one `builder` per repo
   with findings, all in one message, each given its repo, the ledger path and the
   pass number. Each applies its lines, re-runs its gate and the contract tests if
   the seam moved, and marks the lines. Then `vicaris-gate.sh --check` each; a red
   repo goes to `builder-opus`.
5. **Re-review** after the first fix pass: back to 2 with `N=2`, for the repos that
   pass changed. After the second fix pass, the gate only: there is no third review,
   and what is still open is outstanding (`gates.md`, *At the cap*). The decider
   naming an oscillation stops the loop early.

Count passes from the ledger's sections, not from memory, so a compaction cannot
reset the cap. Ping the thread when the review lands and when the loop ends, and
refresh the handover doc then.

## Step 4 — Test

Spawn `builder` to run the `test` skill,
including its fix-and-re-test loop, capped at two passes; the browser output never
enters your context. If it reports SSO blocked, it has already told the owner:
continue with the rest. Refresh the handover doc when it returns.

## Step 5 — Finalize

`finalize` runs in parts so that nobody but you waits on a pipeline or a reviewer
(its *Who runs what*):

1. **Publish** — spawn `builder` for its Step 1: the MR per repo, announced, and any
   eval jobs played. It reports the links and returns without waiting.
2. **Pipelines and evals** — its Step 2, yourself, through `vicaris-wait.sh`. Each
   call blocks up to nine minutes and returns one line per repo; call again on exit
   124. A red pipeline goes to a `builder` per failing repo with the log file the
   script wrote, an eval that moved to a short `lead` first.
3. **MR review** — its Step 3, yourself: every MR's reviewer started at once with
   `vicaris-wait.sh start`, waited for with `files`, then a short `lead` decides from
   the review files and a `builder` per repo fixes and pushes; back to 2 for those
   repos. Two fix passes, then outstanding. A finding the local review already
   parked is answered with its ledger line, not relitigated.
4. **Wrap** — spawn `builder` for its Steps 4–7: the completion doc, written now
   that every result it reports exists, the Jira and Confluence updates, the Slack
   wrap-up, and stopping the keep-awake.

Waiting on a single foreground call keeps the run inside this turn. A background
loop would end the turn, and the notification that resumes it starts a new turn on
the session's own model rather than this skill's (Step 0.8).

The task is not done until this exits zero:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/vicaris-status.sh" --final
```

`--final` is what adds "every change repo has an MR and nothing uncommitted"; before
finalize, a missing MR is expected and the plain form does not count it.

Fix what it names rather than reporting it. Refresh the handover doc one last time.

## Context discipline

**Refresh the handover doc at every stage boundary, unconditionally**, via the
`handover` skill's *write* step, so `<primary>/.vicaris/handover-<branch>.md` is
always current. Do not try to judge remaining context as a percentage; you cannot
see it. Compaction is automatic but lossy, and the handover doc is what survives it.

Refresh it now, and say so in the thread, when any of these fire:

- the review fix loop or the MR-review loop reaches its cap
- a verification loop (evals, CI, browser) reaches a third iteration
- every stage has run and the task is still not finished

End the session only when a fresh one is genuinely cheaper, never mid-stage; say so
in Slack and the terminal and give the resume command.

## Throughout

- Keep a running list of decisions and assumptions for the completion doc.
- Scratch docs are the owner's working material: never commit or cite them. They
  live in the primary repo.
- Use `git -C "$repo"`, not `cd`, and tag every file, finding and result with its
  repo name.
- Before declaring any stage complete, run `scripts/vicaris-status.sh`. It counts
  uncommitted work as work and a verify result about older code as stale.
