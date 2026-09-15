# dev-flow

An autonomous, end-to-end development workflow packaged as a Claude Code
plugin, grounded in a captured statement of how Sujit likes code written and
reviewed. It runs a task from a Jira key or brief all the way to a reviewed,
tested, finalized change — deciding every fork itself and logging the
assumption, pinging Slack only on a genuine external blocker.

## Pipeline

```
/dev-flow <task>
   │
   ├─ plan            (fable)         design against the principles; recommend + log assumptions
   ├─ implement       (opus, auto)    clean, small, typed, declarative, domain-modelled; concise tests
   ├─ adversarial-review (3× opus ∥)  PO (AC coverage) · clean-code · design → one ranked report
   ├─ test                            fast units + real browser test + logs/traces → Slack summary
   └─ finalize        (opus)          completion doc + MR reviewer + Slack wrap-up
```

Each stage is also a standalone skill: `/plan`, `/implement`,
`/adversarial-review`, `/test`, `/handover`, `/finalize`.

Prose cleanup lives in the separate `byline` plugin, which owns `/de-ai` and the
writing-voice skills. `dev-flow` works without it; the doc-generating stages
apply a short inline prose bar and defer to `/de-ai` when it is available.

## The references

- **`references/coding-principles.md`** — the language- and project-agnostic
  standard (clean code, low complexity, SRP, declarative, pure functions,
  domain modelling over primitives, rich models not anemic, SOLID/OOP/FP,
  idiomatic modern constructs, zero warnings; the dogmatic avoids; testing and
  collaboration style). Every stage reads it. **No product names live here.**
- **`references/multi-repo.md`** — how a change spanning several repos is
  handled, since that is the common case here. Defines the repo-set manifest the
  plan writes and every later stage fans out over, the per-repo git invariants,
  and the rule that binds it together: implement, review, test, fix, MR and
  MR-review all cover **every** repo, one MR per repo, cross-linked. Also names
  the failure unique to these changes, the contract *between* the diffs, and
  keeps deploy-order thinking in scope.
- **`references/notifications.md`** — the Slack drumbeat for an unattended run:
  a milestone ping at every stage boundary (planning done, each repo implemented,
  review started / found / resolved, testing, each MR, handover, complete), all
  threaded under one parent message so the DM stays readable. Send-and-continue
  only; a ping is never a question.
- **`references/project-context.md`** — the *only* place project- and
  product-specific detail lives: verify commands, prompt/framework conventions,
  browser-app + login, SSO, observability, MR-reviewer command, Slack target.
  Edit or replace it per project; the skills load it if present and skip
  gracefully if not.

## Behaviour worth knowing

- **Autonomous.** Forks are decided (recommend + assumption + self-critique),
  not asked. Only expired SSO / a missing credential / an irreversible product
  call triggers a Slack DM, and the run continues with whatever isn't blocked.
- **Models.** Planning runs on **fable**; implementation, review, and finalize
  on **opus**. Run every stage at high reasoning effort.
- **Stays awake.** The orchestrator starts a capped `caffeinate` so display /
  system sleep can't stall a long run, and stops it at finalize. You can also
  launch the whole session under `caffeinate -dimsu claude`.
- **Multi-repo by default.** The plan pins the set of repos a change touches;
  from there every stage covers all of them — branched off each repo's own fresh
  `origin/HEAD`, reviewed as one diff plus the contract between them, one MR per
  repo cross-linked under the same ticket, and the MR-review bot run on each.
- **Context discipline.** Around ~50% context it writes a handover doc and
  hands to a fresh session with no lost state.
- **Secrets.** The browser login never routes a password through the
  assistant's context (trufflehog-safe): Chrome autofill by default, with a
  keychain→keystroke helper (`scripts/browser-login-helper.sh`) as a
  sign-off-gated fallback.

## Prerequisites

- Slack MCP, Atlassian MCP, and a browser MCP (chrome-devtools) connected.
- For MR review: the standalone reviewer installed with `GITLAB_TOKEN` set
  (see `project-context.md`).
- Set session reasoning effort to high.
