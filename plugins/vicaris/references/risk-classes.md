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
or ticks any non-functional row in the understanding document. It earns the design
challenge.

**`production`** — data can be destroyed, access can be widened, money can move, or
rolling back needs a deploy. Everything `elevated` gets, plus the parity and
migration checks, plus a completion doc with a rollback plan.

## What each class runs

| Stage | mechanical | tiny | normal | elevated | production |
|---|---|---|---|---|---|
| Understand — full NFR table | short form | short form | ✓ | ✓ | ✓ |
| Design note (`implement` 2b) | skip | skip | ✓ | ✓ | ✓ |
| Design challenge | skip | skip | skip | ✓ | ✓ |
| Build model (`implement` 3–6b) | sonnet | sonnet | sonnet | opus | opus |
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
| Completion doc | five lines | short | ✓ | ✓ | ✓ + rollback plan |
| MR + standalone MR review | ✓ | ✓ | ✓ | ✓ | ✓ |

**Build model.** At `normal` and below the build's shape is already decided on
opus — in the design note, or in the rules and exemplars named before it — so
sonnet executes it, at half the price, in the stage that uses the most tokens. At `elevated`
and `production` the contract still firms up while the producer is written, and a
wrong call crosses a repo boundary before any reviewer sees it, so the build stays
on opus. Design, review and the design comparison run on opus at every class.

The review row becomes `review-changes` flags in `adversarial-review` Step 2.

## Classified twice, and only ever upward

**Predicted**, by `understand`, from the story and its non-functional answers. It
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
