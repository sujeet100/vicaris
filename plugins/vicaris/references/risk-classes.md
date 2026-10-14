# Risk classes — what ceremony a change earns

The change is classified once, early, and every later stage reads the class
instead of deciding its own depth. The class lives in one file, re-injected on
resume:

```
<primary-repo>/.vicaris/risk-<branch>.txt
RISK: <class> · tags: <comma-separated, or none>
why: <one line — the trigger that set it>
```

## The five classes

**`mechanical`** — repeats a shape the repo already has and introduces no new
concept: a field threaded through an existing DTO's consumers, an enum value, a
locale file mirroring the two beside it, a config-map row, a rename, a dependency
bump. The test: can you point at the existing instances it copies, with nothing
novel? Its failure mode is **incompleteness, not quality** — the field that reaches
three of four consumers, the enum value with no `match` arm, the prompt updated for
one locale and not the other — so a parity check replaces craft review.

**`tiny`** — small and local but not pattern-repeating: a one-line bug fix with a
nameable root cause, a guard clause, a corrected boundary. It keeps a craft pass and
earns a regression test that fails without the fix.

**`normal`** — ordinary product work: several files, real business logic, a design
worth writing down. The default when nothing else fits; default up, not down.

**`elevated`** — crosses a component or repo boundary, introduces a structural unit,
or carries any tag from the understanding's "What the change could break" rows. It earns the design
challenge.

**`production`** — data can be destroyed, access can be widened, money can move, or
rolling back needs a deploy. Everything `elevated` gets, plus the parity and
migration checks, plus a completion doc with a rollback plan.

## What each class runs

| Stage | mechanical | tiny | normal | elevated | production |
|---|---|---|---|---|---|
| Understand — every Step 3 row | short form | short form | ✓ | ✓ | ✓ |
| Design note (`implement` 2b) | skip | skip | ✓ | ✓ | ✓ |
| Design challenge | skip | skip | skip | ✓ | ✓ |
| Build model (`implement` 3–6b, fix passes, `test`) | Sonnet 5.5 | Sonnet 5.5 | Sonnet 5.5 | Sonnet 5.5 | Sonnet 5.5 |
| Parity check | **required** | — | where a part repeats a pattern | where a part repeats a pattern | **required** |
| Deterministic gates | ✓ | ✓ | ✓ | ✓ | ✓ |
| Regression test proving the fix | — | **required** | where a bug is fixed | where a bug is fixed | where a bug is fixed |
| Integrated smoke | skip | if user-visible | if user-visible | ✓ | ✓ |
| Craft pass | **skip** | `--quick` | ✓ | ✓ | ✓ |
| Architect pass | skip | skip | signals decide | force on | force on |
| Integration pass | skip | signals decide | signals decide | force on | force on |
| Acceptance-criteria pass | skip | skip | ✓ | ✓ | ✓ |
| Browser / end-to-end | skip | if user-visible | if user-visible | ✓ | ✓ |
| Migration rehearsal (up + down) | — | — | — | if schema | **required** |
| Completion doc | what was threaded where, parity, verify | plus the decisions | ✓ | ✓ | ✓ + rollback plan |
| MR + standalone MR review | ✓ | ✓ | ✓ | ✓ | ✓ |

**Build model.** Judgement runs on Opus 5.5: understanding, design, the design
comparison, review and the decision on every finding. What reaches the build has
already been decided there, in the design note, the rules and exemplars named before
it, or the fix ledger, so Sonnet 5.5 carries it out at every class, and fix passes
and `test` follow it. The split holds only if a decision never forms inside the
build: where building or a finding shows a design decision is wrong, or reaches a
choice the note does not settle, the builder writes a decision request instead of
choosing, a short Opus `lead` decides it and rewrites the note in place
(`design-note.md`, *Keeping it current*), and Sonnet then builds to the amended note. That covers the
case that once kept `elevated` and `production` builds on Opus, a cross-repo
contract that firms up while the producer is written: the contract's shape is the
design note's to decide, and a change to it is a design change. Sonnet 5.5 halves
every rate, cache reads included ($0.10 per million against Opus's $0.20), so moving
a stage to it roughly halves that stage's bill. Opus 5.5 builds only to repair
a stage that came back red or departed from its note. Where each runs is in
`delegation.md`.

The review row becomes `review-changes` flags in `adversarial-review` Step 2.

## Classified twice, and only ever upward

**Predicted**, by `understand`, from the story and its "what the change could break" answers. It
gates the stages that run before there is a diff — the design note and the design
challenge.

**Observed**, by `scripts/vicaris-risk.sh`, from the paths actually touched, at the
gate before review. Crude on purpose: path patterns for migrations, authorisation,
money, concurrency, infrastructure, dependency manifests, public contracts and
prompts. It can **raise** the class and never lower it: a false positive costs one
review pass, a false negative the review that would have caught it.

When the observed class is higher, say so in the Slack thread and run the stages the
new class earns — including the design challenge, late and out of order. A raise
does **not** re-run a build sonnet already finished; the forced opus review passes
the higher class buys are how that build is held to the bar.
