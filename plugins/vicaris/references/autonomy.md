# The autonomy contract

Every stage runs unattended; this is what to do when you would normally ask.
Read it once per run.

## The contract

- **Finish the task autonomously.** Drive all the way to finalize without
  stopping to ask permission between stages.
- **Never ask a blocking question. Ever.** No `AskUserQuestion`, no interactive
  prompt, no turn that ends in a question with no work done. The *only* channel
  to the owner is an asynchronous Slack DM you send and keep working past; a
  prompt waiting for a keypress stalls the whole run for as long as they're away.
- **Every fork is decided, not asked** — including the uncomfortable ones. Pick
  the option you'd recommend, log the assumption with a one-line self-critique,
  and proceed. The owner reviews those calls in the completion doc. "I'd like to
  confirm first" is not a reason: if you can present a recommended option, you
  already know the answer, so take it.
- **Scope is never a question.** "How far should this go?", "both repos?" and
  "should I split this?" all get the same answer: **deliver the whole scope of the
  story, every repo it touches.** If part is genuinely blocked, deliver everything
  else in full, ship the MRs for what's done, and record the remainder as
  follow-on with the reason. Never ask the owner to choose a smaller scope;
  reducing scope is their call *after* seeing what you delivered.
- **Only genuine external blockers reach the owner, and even then don't hard-stop.**
  The list is closed: expired SSO or a missing credential, a required upstream
  dependency that hasn't shipped, or a genuinely irreversible action (deleting
  data, publishing something public). Their uncommitted work is **not** on it,
  because a worktree handles it. Send a terse Slack DM, continue with everything
  that isn't blocked, and record the blocked item for the summary. Never spin
  waiting.
- **Blocked means blocked on one thing, not on the run.** A blocker in one repo,
  AC or verification step stops *that* item only. Route around it.
- **Push back in the record, not by pausing.** If a requested approach is wrong,
  implement the defensible version and flag the disagreement, with the
  alternative, in the completion doc.
- **Writing the handover is not stopping short.** It is bookkeeping at every
  stage boundary. *Ending* a session is rare; finish the current stage first.
  Neither is a question for the owner.
- **If the rules seem to leave no legal move, that's still your call.** Two rules
  pulling against each other is not permission to stop and ask: escalating costs
  the owner the whole run, recording it costs one paragraph. Look for the option
  that honours both rules (for "whole scope" vs "never touch their
  uncommitted work", a worktree); failing that, take the least destructive action that makes progress, record the
  tension and your choice in the completion doc, and mention it in the Slack
  wrap-up so the workflow gets fixed.

## Forks that already have an answer

None of these is a question. Apply the resolution and note it in the completion
doc.

| Situation | What you do |
|---|---|
| A sibling repo is behind its remote | Fetch and bring it current; that's Step 0.4, not a decision |
| A repo has the owner's uncommitted work | `git worktree add` a clean checkout beside it and work there; their tree is untouched and the scope still ships |
| A repo's WIP looks like it wants committing or moving | Not yours to commit or move. Worktree, and don't mention it beyond a line in the completion doc |
| Part of the story is bigger than the rest | Deliver all of it anyway; size is not a scope question |
| The story names an unshipped dependency | Implement against the contract it specifies and note the ordering in the MR; only defer if the code genuinely cannot compile or run without it |
| The change needs a new library | Add it — matching the project's existing conventions and the smallest option that does the job — and record the choice |
| Browser verification is needed and SSO is dead | Slack the SSO ask, finish everything else, MR it with the browser step flagged unverified |
| One AC is ambiguous | Implement the reading a careful colleague would pick, state the assumption, and flag it for review |
| The change looks risky to ship | Put it behind a toggle or keep it backward compatible, and say so — don't seek permission |

A fork on neither this list nor the closed blocker list is yours to decide.

## Deciding inside a stage

A question none of the above answers is a gap in this file, not an escalation.
Decide it by the contract — the least destructive action that makes progress —
and name the question in the Slack wrap-up so a row gets added here.
