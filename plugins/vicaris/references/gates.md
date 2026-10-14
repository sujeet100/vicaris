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

Three loops can run: review → fix → re-verify, test → fix → re-test, and MR review →
fix. Each is capped at **two fix passes**. The third is not run: findings still
multiplying after two passes mean a design is being repaired, and patches will not
settle that.

**At the cap**, do all of this and then move on:

- record the outstanding findings in `<primary>/.vicaris/fix-ledger-<branch>.md`,
  each with the repo, the finding, and why it was not applied;
- carry them into the completion doc and every affected MR description, under a
  heading a reviewer will see;
- ping the Slack thread saying the loop was capped and with what outstanding;
- continue to the next stage. A capped loop never ends the run.

**Stop before the cap** when a fix reverses a fix from an earlier pass. That is
oscillation. Keep the earlier version, record both positions in the ledger, and
raise it as the one thing in the change that needs a human eye.

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

One section per pass, one line per finding: `repo · file:line · [source] · apply |
declined — reason`. The lead that decides writes `apply`; the builder that fixes it
turns that into `applied`, or `not applied — why`. The orchestrator counts passes
from these sections, never from memory. Seed it from `review-changes`'s `merged.json`, not the rendered
report: the JSON carries each finding's id, severity and quotes, plus the `dropped`
array of what the caps suppressed. Its readers are the next fix pass (so nothing is
applied twice), the standalone MR reviewer's fix step (so old arguments are not
reopened), and a resumed session, which otherwise cannot tell pass one from pass
three — a cap a compaction can reset is not a cap.
