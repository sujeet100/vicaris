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
   ├─ understand      (fable)         acceptance criteria + the reading rejected for each
   │                                  ambiguous one · contradictions · gaps · NFRs · repos ·
   │                                  test surface · → RISK CLASS, which gates everything below
   ├─ implement       (opus, auto)    design note per repo → design challenge → build in slices →
   │                                  tests → simplification pass; clean, small, typed,
   │                                  declarative, domain-modelled
   │  └─ design-challenge (fable+opus) blind design from the ACs alone, compared against the
   │                                  design note, before the first edit. elevated+ only
   ├─ GATE            (scripts)       per-repo verify recorded · risk re-derived from the paths
   │                                  actually touched (can only raise) · integrated smoke.
   │                                  No reviewer is spawned until this is green
   ├─ adversarial-review (opus)       passes bought by risk class: parity only at mechanical,
   │                                  --quick at tiny, signals at normal, forced at elevated+.
   │                                  --also-repo for the seam + one AC pass. Fix loop caps at 2
   ├─ test                            reads the gate's verify results · browser leg risk-gated ·
   │                                  logs/traces → Slack summary
   └─ finalize        (opus)          completion doc (length by class) + MR per repo +
                                      MR reviewer + status check + Slack wrap-up
```

Every loop — review, test, MR review — stops after two fix passes and declares what
is outstanding rather than starting a third. A review still multiplying findings
after two passes is repairing a design, and patches will not settle that.

Each stage is also a standalone skill: `/understand`, `/implement`,
`/design-challenge`, `/adversarial-review`, `/test`, `/handover`, `/finalize`.

The design challenge answers the one question no review pass can: was this the
right thing to build? Craft, architect and integration all start from the diff, so
all three inherit the decision the diff embodies. The challenge builds a second
design from the acceptance criteria alone — blind to the plan, the design note and
the branch — and holds the two together before any code exists, where a divergence
costs a paragraph rather than a rework. It runs on cross-repo, structural and
production-risk changes, and skips a local bug fix with a reason.

Review depth comes from the separate `mr-review` plugin, whose `review-changes`
skill grades against the same charter the MR bot uses. `adversarial-review`
drives it once per repo in the manifest and owns what is true of the change
rather than of one repo: the repo set, the acceptance criteria and the seam
between repos. Without that plugin the stage falls back to three inline
reviewers and says so in the report.

Prose cleanup lives in the separate `byline` plugin, which owns `/de-ai` and the
writing-voice skills. `dev-flow` works without it; the doc-generating stages
apply a short inline prose bar and defer to `/de-ai` when it is available.

## The references

- **`references/risk-classes.md`** — the five classes (`mechanical`, `tiny`,
  `normal`, `elevated`, `production`), what puts a change in each, and the matrix of
  which stages each one buys. `understand` predicts the class; the gate re-derives
  it from the paths actually touched and can only raise it. This is what stops a
  field addition costing what a migration costs, and what stops a migration being
  treated like a field addition.
- **`references/gates.md`** — what must be green before a reviewer is spawned, the
  two-pass cap on every fix loop, the rule that findings are decided rather than
  applied, and the ledger that makes a cap survive a compaction.
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
- **Context discipline.** The handover doc is refreshed at every stage boundary,
  unconditionally, plus on four observable tripwires — a model cannot see its own
  window usage, so a rule keyed to a percentage fails silently. A `PreCompact` hook
  nudges when the doc is missing or stale, and a `SessionStart` hook re-injects the
  manifest, the handover path and the Slack thread after a compaction.
- **Secrets.** The browser login never routes a password through the
  assistant's context (trufflehog-safe): Chrome autofill by default, with a
  keychain→keystroke helper (`scripts/browser-login-helper.sh`) as a
  sign-off-gated fallback.

## The scripts

Four small deterministic pieces, because the invariants that matter should be able
to fail a run rather than be repeated in prose:

- **`dev-flow-risk.sh`** — observed risk class from the changed paths. Raises only,
  never lowers, and refuses to classify from an absent diff.
- **`dev-flow-gate.sh`** — runs a repo's verify and records the verdict in
  `<repo>/.dev-flow/verify-<branch>.txt`, so later stages read a result instead of
  re-running a suite.
- **`dev-flow-parity.sh`** — for a mechanical change, every existing instance of a
  pattern marked TOUCHED or UNTOUCHED. Catches the fourth consumer nobody updated,
  which is how these changes actually fail.
- **`dev-flow-status.sh`** — one row per repo with commits, verify and MR, exiting
  non-zero on work that has no MR. The per-repo checklist, generated rather than
  recalled.

## Prerequisites

- Slack MCP, Atlassian MCP, and a browser MCP (chrome-devtools) connected.
- The `mr-review` plugin, for review depth and for the design challenge's two
  charters. Without it both fall back to inline prompts and say so in the report.
  Override the lookup with `DEVFLOW_MR_REVIEW_ROOT` if it lives somewhere unusual.
- For MR review: the standalone reviewer installed with `GITLAB_TOKEN` set
  (see `project-context.md`).
- Set session reasoning effort to high.
