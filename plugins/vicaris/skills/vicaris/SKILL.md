---
name: vicaris
description: Run a story end to end — understand, design, build, review, test, finalize — across every repo it touches, without asking questions, reporting in one Slack thread.
argument-hint: [Jira key, task description, or feature brief]
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
names. Invoke each stage skill
once; for `handover`, invoke it the first time and at later boundaries follow its
write step from context, invoking it again if a compaction dropped its field list.

## Step 0 — Session setup

1. Read `${CLAUDE_PLUGIN_ROOT}/references/`: `autonomy.md` (never ask, whole scope,
   the closed blocker list), `risk-classes.md`, `gates.md`, `multi-repo.md`,
   `notifications.md`, `coding-principles.md`, and `project-context.md` if present.
2. **Keep the machine awake**, and record the PID, because finalize kills *this*
   process only (a pattern kill can take down a session launched under
   `caffeinate`):
   ```bash
   nohup caffeinate -dimsu -t 21600 >/dev/null 2>&1 &   # 6h safety cap
   echo $! > "$PRIMARY/.vicaris/caffeinate-$BRANCH.pid"
   ```
3. Confirm the repo: `git rev-parse --show-toplevel`.
4. **Branch off the fresh remote default**, never local HEAD:
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
8. **Effort:** high on every stage, set explicitly (Opus 5.5 defaults to `medium`).

**Models.** Opus: understanding, design notes, design comparison, review, finalize.
Sonnet: the build at `mechanical`–`normal`, and the acceptance-criteria pass. Fable:
the blind designer only, so it differs from the model that wrote the notes.

## Step 1 — Understand (opus sub-agent)

Spawn an **opus** sub-agent (`model: opus`) running the `understand` skill on
`$ARGUMENTS`, so the story and linked pages stay out of this long-lived context. It
writes `<primary>/.vicaris/understanding-<branch>.md` and
`<primary>/.vicaris/risk-<branch>.txt`.

**Read the risk file and hold the class for the whole run.** If it is missing,
classify from `risk-classes.md` and write it yourself; an absent class silently
means "do everything".

### Step 1b — Pin the repo set and branch it

Write the understanding's **Repos in scope** to the manifest, dependency order,
primary first:

```bash
mkdir -p "$PRIMARY/.vicaris"
printf '%s\n' /path/to/producer-repo /path/to/consumer-repo \
  > "$PRIMARY/.vicaris/repos-$BRANCH.txt"
```

Apply Step 0.4 to every unbranched repo in it, off **that repo's own** remote
default, and exclude `.vicaris/` locally in each (never in the tracked
`.gitignore`):

```bash
while read -r repo; do
  GITDIR=$(git -C "$repo" rev-parse --git-common-dir)   # a worktree's .git is a file
  case "$GITDIR" in /*) ;; *) GITDIR="$repo/$GITDIR" ;; esac
  grep -qxF '.vicaris/' "$GITDIR/info/exclude" 2>/dev/null \
    || echo '.vicaris/' >> "$GITDIR/info/exclude"
done < "$PRIMARY/.vicaris/repos-$BRANCH.txt"
```

From here every stage covers the whole manifest (`multi-repo.md` has the table).

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

Run the `implement` skill in **auto mode**. Design (Steps 1–2c) is yours, on opus.
The build (Steps 3–6b) goes to one sonnet sub-agent at `mechanical`, `tiny` and
`normal` per its Step 2d, and stays with you on opus at `elevated` and
`production`. Check a sonnet build's verify results and note amendments before the
gate; a red build comes to you, not back to sonnet. Then refresh the handover doc.

## Step 2d — The gate

Nothing expensive starts until these are green (`gates.md`):

```bash
# 1. every repo's own verify, recorded where every later stage reads it
bash "${CLAUDE_PLUGIN_ROOT}/scripts/vicaris-gate.sh" "$repo" "$VERIFY_CMD"

# 2. the class, re-derived from the paths actually touched — raise-only
bash "${CLAUDE_PLUGIN_ROOT}/scripts/vicaris-risk.sh" \
  "$PRIMARY/.vicaris/repos-$BRANCH.txt" "$PREDICTED_CLASS" \
  --write "$PRIMARY/.vicaris/risk-$BRANCH.txt"
```

Exit 3: the class rose and the file is updated. Say so in the thread and run what the
new class earns, including a late design challenge. Exit 4: nothing observed; keep
the predicted class and say the check did not run.

**At `production` with the `schema` tag, rehearse the migration first**: up against a
scratch database per the sidecar, down, up again. With no migration command in the
sidecar, add a line to `degraded-<branch>.txt`, record the rehearsal as **not run** in
the completion doc and MR description, and treat reversibility as unverified.

Then the **integrated smoke** where the class calls for it: the stack up on each
repo's branch build, one happy path end to end.

A gate failure is not a blocker: fix, re-run, continue.

## Step 3 — Adversarial review

Run the `adversarial-review` skill. Findings are decided, not applied, and the fix
loop caps at two passes, both recorded in `<primary>/.vicaris/fix-ledger-<branch>.md`
(`gates.md`). At the cap, carry what is outstanding into the completion doc and
every affected MR description, ping the thread, and move on. Refresh the handover
doc before the second fix pass.

## Step 4 — Test

Run the `test` skill. Fix and re-test what fails, capped at two passes. If blocked on
SSO, Slack the owner and continue with the rest. Refresh the handover doc when the
stage closes and before the second fix pass.

## Step 5 — Finalize

Run the `finalize` skill: completion doc, one MR per repo, MR review on each, Slack
wrap-up, stop the `caffeinate`. A finding the local review already parked is answered
with its ledger line, not relitigated. The task is not done until this exits zero:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/vicaris-status.sh"
```

Fix what it names rather than reporting it. Refresh the handover doc one last time.

## Context discipline

**Refresh the handover doc at every stage boundary, unconditionally**, via the
`handover` skill's *write* step, so `<primary>/.vicaris/handover-<branch>.md` is
always current. Do not try to judge remaining context as a percentage; you cannot
see it. Compaction is automatic but lossy, and the handover doc is what survives it.

Refresh it now, and say so in the thread, when any of these fire:

- the review fix loop reaches a third pass
- a verification loop (evals, CI, browser) reaches a third iteration
- more than about six sub-agents have run (the design challenge's two and a
  sonnet build are expected)
- every stage has run and the task is still not finished

End the session only when a fresh one is genuinely cheaper, never mid-stage; say so
in Slack and the terminal and give the resume command.

## Throughout

- Keep a running list of decisions and assumptions for the completion doc.
- Scratch docs are the owner's working material: never commit or cite them. They
  live in the primary repo.
- Use `git -C "$repo"`, not `cd`, and tag every file, finding and result with its
  repo name.
- Before declaring any stage complete, run `scripts/vicaris-status.sh`.
