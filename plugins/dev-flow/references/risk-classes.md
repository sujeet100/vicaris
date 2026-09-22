# Risk classes — what ceremony a change earns

One workflow for every change is the expensive kind of wrong. A field added to a
response and a migration that drops a column are not the same engineering problem,
and putting both through a design challenge, three opus review passes and a browser
run spends most of the budget on the change that needed least of it — while telling
you nothing extra about the one that needed most.

So the change gets classified once, early, and every later stage reads the class
instead of deciding its own depth. The class lives in one small file that survives
compaction and is re-injected on resume:

```
<primary-repo>/.dev-flow/risk-<branch>.txt
RISK: <class> · tags: <comma-separated, or none>
why: <one line — the trigger that set it>
```

## The five classes

**`mechanical`** — the change repeats a shape the repo already has, and introduces
no new concept. A field added to an existing DTO and threaded to its consumers, a
value added to an enum, a region file mirroring the two beside it, a new row in a
config map, a rename, a dependency version bump. The test is whether you can point
at the existing instances it copies. If you can, and nothing in the change is
novel, it is mechanical.

The failure mode of a mechanical change is **incompleteness, not quality**: the
field that reaches three of four consumers, the enum value with no `match` arm, the
prompt updated for `US` and not `UK`. Craft review is close to worthless here and a
parity check is close to sufficient, which is why the two are swapped for this class
rather than both being run.

**`tiny`** — small, local, but not pattern-repeating: a one-line bug fix with a root
cause you can name, a guard clause, a corrected boundary condition. It has quality
risk that a parity check cannot see, so it keeps a craft pass, and it earns a
regression test that fails without the fix.

**`normal`** — ordinary product work. Several files, real business logic, a design
worth writing down and a shape worth reviewing. This is the default when nothing
else fits, and defaulting up rather than down is deliberate.

**`elevated`** — the change crosses a component or repo boundary, introduces a
structural unit, or ticks any non-functional row in the understanding document.
It earns the design challenge, because these are the changes where a wrong root
decision is both likely and expensive.

**`production`** — data can be destroyed, access can be widened, money can move, or
rolling back needs a deploy. Everything `elevated` gets, plus the parity and
migration checks, plus a completion doc that carries a rollback plan.

## What each class runs

| Stage | mechanical | tiny | normal | elevated | production |
|---|---|---|---|---|---|
| Understand — full NFR table | short form | short form | ✓ | ✓ | ✓ |
| Design note (`implement` 2b) | skip | skip | ✓ | ✓ | ✓ |
| Design challenge | skip | skip | skip | ✓ | ✓ |
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

The MR row is deliberately uniform. Every change gets an MR and the standalone
reviewer runs on it, so even the class that skips local review has one independent
look before a human is asked for theirs.

Translating the review row into flags, since that is where it is applied:

| Class | `review-changes` invocation |
|---|---|
| `mechanical` | not invoked — the parity check replaces it |
| `tiny` | `--quick --yes` |
| `normal` | `--yes` — the mapper's signals decide architect and integration |
| `elevated` | `--yes --architect --integration` |
| `production` | `--yes --architect --integration` |

Never pass `--only`. It replaces the default pass set outright, which switches off
the conditionality the mapper computes from the diff, and that conditionality is
doing the same job as this table one level down.

## Classified twice, and only ever upward

**Predicted**, by the `understand` stage, from the story and its own non-functional
answers. This is what gates the stages that run before there is a diff — the design
note and the design challenge — and it is a judgement, because nothing else is
available yet.

**Observed**, by `scripts/dev-flow-risk.sh`, from the paths the change actually
touched, at the gate before review. It is crude on purpose: path patterns for
migrations, authorisation, money, concurrency, infrastructure, dependency manifests,
public contracts and prompts. It can **raise** the class and never lower it.

That asymmetry is the whole point of running it twice. A story that reads like a
small change and turns out to touch a migration is the exact case where a predicted
class is wrong and nobody notices, and a false positive costs one extra review pass
while a false negative costs the review that would have caught it. When the observed
class is higher, say so in the Slack thread and run the stages the new class earns —
including the design challenge, late and out of order, because late is better than
not at all.
