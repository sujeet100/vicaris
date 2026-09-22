# Gates and loops — where the workflow refuses to spend more

Two mechanisms, and they solve the same problem from opposite ends. A gate stops
expensive work from starting on a change that has not earned it. A loop cap stops
expensive work from continuing once it has stopped producing new information.

## The gate before review

Nothing costly runs until the cheap deterministic checks are green. On a cross-repo
change that is three opus review passes per repo plus an acceptance-criteria pass,
and spending them on code that does not compile, does not pass its own unit suite,
or has never been exercised end to end is money spent to be told what a build would
have said in ninety seconds.

Run, in this order, and stop at the first failure:

1. **Per repo, the project's verify command** — build, format, type check, lint and
   the fast unit suite, whatever `project-context.md` names. Use the script, which
   captures the output where every later stage expects to find it:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/vicaris-gate.sh" "$repo" "$VERIFY_CMD"
   ```

   It writes `<repo>/.vicaris/verify-<branch>.txt` with a `RESULT:` first line, so
   `test`, `handover` and `finalize` read a result rather than re-running a suite,
   and a resumed session can tell a repo that passed from one that was never run.

2. **Observed risk** — `scripts/vicaris-risk.sh`, which re-derives the class from
   the paths actually touched and can raise it. See `references/risk-classes.md`.

3. **Migration rehearsal**, at `production` with a `schema` tag — apply, reverse,
   re-apply, against a scratch database per the sidecar. A migration that will not
   reverse is a one-way door and this is the cheapest place to learn it. With no
   migration command in the sidecar, record it as not run rather than skipping it
   silently, and carry that into the MR.

4. **Integrated smoke**, where the class calls for it — the stack up on each repo's
   *branch* build, one happy path through the change end to end. Not the full
   browser pass, which stays after review; one path, to prove the seam exists. A
   cross-repo change is exactly what each repo's green unit suite cannot see.

A gate failure is not a blocker in the escalation sense. Fix it and re-run the gate;
the reviewers have not been spawned yet, so nothing is wasted.

## Loop caps

Three loops can run: review → fix → re-verify, test → fix → re-test, and MR review →
fix. Each is capped at **two fix passes**. The third is not run.

This is not a compromise with quality, it is what the evidence says. A review whose
findings are still multiplying after two passes is not converging on a better
implementation; it is repairing a design, and a third round of patches will not
settle what a design decision has to. The autonomy contract already prefers
delivering and declaring over stopping and asking, and a capped loop is the same
move: ship what is done, name what is not.

**At the cap**, do all of this and then move on:

- record the outstanding findings in `<primary>/.vicaris/fix-ledger-<branch>.md`,
  each with the repo, the finding, and why it was not applied;
- carry them into the completion doc and into every affected MR description, under
  a heading a reviewer will see, not buried in prose;
- ping the Slack thread saying the loop was capped and with what outstanding;
- continue to the next stage. A capped loop never ends the run.

**Stop before the cap** when a fix reverses a fix from an earlier pass. Two passes
disagreeing about the same line is oscillation, and one more pass picks a side
arbitrarily. Keep the earlier version, record both positions in the ledger, and
raise it as the one thing in the change that needs a human eye.

## Findings are decided, not applied

A reviewer that ran without the author's rationale can be right about the code and
wrong about the change. Every blocker and should-fix therefore ends in one of two
states, and "noted" is not one of them:

- **Applied** — with the repo's verify re-run, and the seam's contract tests re-run
  if the seam moved.
- **Declined** — with the reason named as a thing rather than a preference: the
  input, the caller, the state, the constraint you can cite, or the line in the
  design note or design challenge that already weighed it and said why. "The
  reviewer said so" is not a reason to apply one, and "ours is cleaner" is not a
  reason to decline one.

Both outcomes go in the ledger. That file is what makes the second and third
reviewers cheap: a suggestion the local review already considered and parked does
not get relitigated because a later pass raised it again, it gets answered with the
line that parked it.

## The ledger

```
<primary-repo>/.vicaris/fix-ledger-<branch>.md
```

One section per pass, one line per finding: `repo · file:line · [source] · applied |
declined — reason`. Seed it from `review-changes`'s `merged.json` rather than from its rendered
report — the JSON carries each finding's id, severity and quotes, plus the `dropped` array of what
the caps suppressed, which is exactly what answers "did we already consider this" when a later
reviewer raises the same point. It exists for three readers. The next fix pass, so a finding is
not applied twice. The standalone MR reviewer's fix step, so an old argument is not
had again. And a resumed session, which otherwise cannot tell whether it is entering
pass one or pass three — and a loop cap that a compaction can reset is not a cap.
