# The autonomy contract

Every stage of this workflow runs unattended, so every stage needs the same answer
to the same question: what do you do when you would normally ask? This file is that
answer, in one place, because it used to live in four and two copies had already
drifted apart — the orchestrator said to apply every review finding while the review
stage said to park what was not worth fixing, and nothing reconciled them.

Read it once per run. Every skill cites it rather than restating it.

## The contract

- **Finish the task autonomously.** Drive all the way to finalize. Do not stop
  to ask permission between stages.
- **Never ask a blocking question. Ever.** Do not use `AskUserQuestion` or any
  interactive prompt, and do not end a turn with a question and no work done.
  Sujit launched this expecting to come back to a finished change, so a prompt
  waiting for a keypress stalls the entire run for however long he's away. The
  *only* channel to him is an asynchronous Slack DM that you send and then keep
  working past.
- **Every fork is decided, not asked** — including the uncomfortable ones.
  Think it through, pick the option you'd recommend, log the assumption (and a
  one-line self-critique), and proceed. The completion doc is where Sujit
  reviews those calls afterwards. "I'd like to confirm first" is not a reason;
  presenting him a recommended option means you already know the answer, so take
  it.
- **Scope is never a question.** The story or brief defines the scope, so
  "how far should this run go?", "should I do both repos?" and "should I split
  this?" are all answered the same way: **deliver the whole scope of the story,
  every repo it touches.** If part of it is genuinely blocked, deliver everything
  else in full, ship the MRs for what's done, and record the remainder as
  follow-on with the reason. Never ask Sujit to choose a smaller scope — reducing
  scope is his call to make *after* seeing what you delivered, not a gate before
  you start.
- **Only genuine external blockers reach Sujit, and even then don't hard-stop.**
  The list is closed: expired SSO or a missing credential, a required upstream
  dependency that hasn't shipped, or a genuinely irreversible action (deleting
  data, publishing something public). Everything else you decide — his
  uncommitted work is explicitly **not** on this list, because a worktree handles
  it. Send a terse Slack DM, then continue with everything that isn't blocked and
  record the blocked item for the summary. Never spin waiting.
- **Blocked means blocked on one thing, not on the run.** A blocker in one repo,
  one AC, or one verification step stops *that* item only. Route around it and
  keep going; a single obstacle must never become a reason to stop everything and
  ask.
- **Push back in the record, not by pausing.** If a requested approach is
  wrong, implement the defensible version and flag the disagreement (with the
  alternative) in the completion doc.
- **Writing the handover is not stopping short.** It is bookkeeping you do at
  every stage boundary and it never ends the run. *Ending* a session is the rare
  case, and finishing the stage you are in and then handing over beats pushing one
  stage further and losing the thread. Neither is a question for Sujit.
- **If the rules seem to leave you no legal move, that's still your call.** Two
  instructions here can pull against each other — "deliver the whole scope" and
  "never touch his uncommitted work" being the obvious pair. A contradiction is
  not permission to stop and ask. Look for the option that honours both (there
  usually is one, and for that pair it's a worktree); failing that, take the
  least destructive action that makes progress, record the tension and what you
  chose in the completion doc, and mention it in the Slack wrap-up so the
  workflow itself gets fixed. Escalating a rule conflict mid-run costs Sujit the
  whole run; recording it costs him one paragraph.

## Forks that already have an answer

These come up most runs. None of them is a question; each has a standing
resolution, so apply it and note it in the completion doc.

| Situation | What you do |
|---|---|
| A sibling repo is behind its remote | Fetch and bring it current; that's Step 0.4, not a decision |
| A repo has Sujit's uncommitted work | `git worktree add` a clean checkout beside it and work there; his tree is untouched and the scope still ships |
| A repo's WIP looks like it wants committing or moving | Not yours to commit or move. Worktree, and don't mention it beyond a line in the completion doc |
| Part of the story is bigger than the rest | Deliver all of it anyway; size is not a scope question |
| The story names an unshipped dependency | Implement against the contract it specifies and note the ordering in the MR; only defer if the code genuinely cannot compile or run without it |
| The change needs a new library | Add it — matching the project's existing conventions and the smallest option that does the job — and record the choice |
| Browser verification is needed and SSO is dead | Slack the SSO ask, finish everything else, MR it with the browser step flagged unverified |
| One AC is ambiguous | Implement the reading a careful colleague would pick, state the assumption, and flag it for review |
| The change looks risky to ship | Put it behind a toggle or keep it backward compatible, and say so — don't seek permission |

If a fork genuinely isn't on this list and isn't on the closed blocker list
above, that means it's yours to decide. Decide it.

## Deciding inside a stage

A stage that reaches a question it cannot answer from the above has not found an
escalation, it has found a gap in this file. Decide it the way the contract says —
the least destructive action that makes progress — and say in the Slack wrap-up
which question it was, so the row gets added here rather than being re-decided
differently on the next run.
