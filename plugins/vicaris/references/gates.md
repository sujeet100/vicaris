# Gates and loops — where the workflow refuses to spend more

A gate stops expensive work from starting on a change that has not earned it. A
loop cap stops it from continuing once it has stopped producing new information.

## The gate before review

Nothing costly runs until the cheap deterministic checks are green.

Run, in this order, and stop at the first failure:

1. **Per repo, the project's verify command** — build, format, type check, lint and
   the fast unit suite, whatever `project-context.md` names, through the script:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/vicaris-gate.sh" "$repo" "$VERIFY_CMD"
   ```

   It writes `<repo>/.vicaris/verify-<branch>.txt` with a `RESULT:` first line and
   the fingerprint of the tree it ran against. `vicaris-gate.sh --check "$repo"`
   says whether that result is about the code as it stands, which is how `test`,
   `handover` and `finalize` reuse it instead of re-running a suite, and how a pass
   recorded before a fix pass edited the code shows up as stale.

2. **Observed risk** — `scripts/vicaris-risk.sh` re-derives the class from the
   paths actually touched, committed or not, in the manifest's `change` repos
   against each one's own base, and can raise it. See `references/risk-classes.md`.

3. **Migration rehearsal**, at `production` with a `schema` tag — apply, reverse,
   re-apply, against a scratch database per the sidecar. With no migration command
   in the sidecar, record it as not run, never skip it silently, and carry that
   into the MR.

4. **Integrated smoke**, where the class calls for it — the stack up on each repo's
   *branch* build, one happy path through the change end to end. Not the full
   browser pass, which stays after review; one path, to prove the seam exists.

A gate failure is not a blocker in the escalation sense. Fix it and re-run the
gate; no reviewer has been spawned, so nothing is wasted.

## Loop caps

Three loops can run, and each is capped where it stops buying information:

| Loop | Fix passes | What checks the fix |
|---|---|---|
| Review → fix | **one** | the gate, then the MR review over the pushed change |
| MR review → fix | **one** | the gate and the pipeline |
| Test → fix → re-test | **two** | the re-test, which is evidence rather than opinion |

**No review round runs over a review fix pass.** The MR review is already a second
review, over the pushed state with the fix commits in it, under a reviewer built
differently from the local one; a local re-review in between was the third round of
four over the same change. On the run that settled this, the local re-review and the
second fix pass it fed cost about a ninth of the run, and the defects it found were in
code the corrected story later removed, while the bug that mattered came from the MR
review. What a fix can break that a test or type check can see, the gate still catches
before anything is pushed. Fix commits are kept separate (`multi-repo.md`, *Commits*),
so the MR decider can tell a finding in fix-pass code from one in the build, and the
ledger records which it was. If findings in fix-pass code keep turning up, that is the
evidence for adding a review of the fix commits back.

**After the last pass**, do all of this and then move on:

- record what is still open in `<primary>/.vicaris/fix-ledger-<branch>.md`, each
  with the repo, the finding, and why it was not applied;
- carry it into the completion doc and every affected MR description, under a
  heading a reviewer will see;
- ping the Slack thread saying what is outstanding;
- continue to the next stage. An outstanding finding never ends the run.

**Oscillation** is a fix that reverses an earlier one, typically an MR-review finding
that undoes a local review's fix. Keep the earlier version, record both positions in
the ledger, and raise it as the one thing in the change that needs a human eye.

## Findings are decided, not applied

A reviewer without the author's rationale can be right about the code and wrong
about the change. Every blocker and should-fix ends in one of two states; "noted"
is not one:

- **Applied** — with the repo's verify re-run, and the seam's contract tests re-run
  if the seam moved.
- **Declined** — with the reason named as a thing: the input, caller, state or
  constraint, or the line in the design note or design challenge that already
  weighed it. "The reviewer said so" is not a reason to apply, and "ours is
  cleaner" is not a reason to decline.

Both outcomes go in the ledger, so a finding already parked is answered with the
line that parked it rather than relitigated when a later reviewer raises it.

## The ledger

```
<primary-repo>/.vicaris/fix-ledger-<branch>.md
```

One section per pass, headed `## <loop> pass <N>`, where the loop is `review`, `test`
or `mr-review`; one line per finding: `repo · file:line · [source] · apply | declined —
reason`. The lead that decides writes `apply`; the builder that fixes it turns that
into `applied` with the test that proves it, or `not applied — why`, on the same line
and never as a paragraph: the ledger is read by the next decider and by the owner,
and the reasoning already lives in the design note or the review doc. A builder that
commits a pass adds `<repo> commit: <sha>` under that pass's heading, which is how
the MR decider finds the fix commits after a compaction. The MR decider
adds `· fix-pass code` to a finding whose lines a review fix commit wrote. The
orchestrator counts passes from these headings, never from memory. Seed the review section from `review-changes`'s `merged.json`, not the rendered
report: the JSON carries each finding's id, severity and quotes, plus the `dropped`
array of what the caps suppressed. Its readers are the fix pass (so nothing is
applied twice), the MR review's decider (so old arguments are not reopened), and a
resumed session, which otherwise cannot tell a pass that ran from one that did not —
a cap a compaction can reset is not a cap.
