# The design note

Line-level rules fire while a function is being typed, never at the moment a shape
is being chosen — whether a class should exist, where a rule lives, what gets
deleted. That is the moment this note covers. Each question demands a named thing:
a file, a rejected alternative, a concrete requirement. A question that can be
answered "yes, it's fine" costs nothing and is not asked here.

One line per answer. If an answer is genuinely "none", write `none` and the reason
— a blank is a finding, not a pass. Other skills cite these lines by number, so
keep the numbering.

```
Design note
1. Requirement: <one sentence, no class / file / pattern names>
2. Fresh design: <what you'd build in an empty repo> · Existing: <closest file> · Verdict: <matches | differs — which is right, and whether this change fixes it>
3. Rejected simpler design: <not building it / config / the platform's own capability / a smaller mechanism> · Breaks because: <the specific input, state or caller>
4. Added: <n> new named things, each → the criterion or constraint that forces it · Deleted: <file / function / branch> or none because <reason>
5. Tested by: <the pure function or contract under test, no mocks> or impure because <the I/O, clock or global it reads>
6. Nouns → types: <noun: Type | primitive> for each noun in line 1 · Verbs → owners: <verb: OwningType>
7. Repeated knowledge: <file:line, file:line — the unnamed abstraction> or none
8. Next change: <the most plausible next change to this area> · Touches: <the files it would edit under this design>
```

Then the rows of the table below that the change touches.

## The eight, always

**1. State the requirement in one sentence without naming a class, file, or
pattern.** "Planners can exclude frames by keyword" is a requirement. "Add
`KeywordExclusionFilter` to `InventoryExtractor`" is a design that skipped the
requirement. If the sentence will not come, you are designing before you
understand the problem.

**2. Sketch what you would build in an empty repo, and only then read the
existing code.** The repo is empty, the constraints are not: design within the
understanding's non-functional constraints and rejected readings, or the sketch
is elegant and unshippable. Existing code is evidence of what exists, not of what is right,
and most codebases have shapes in them that should not be repeated. So design
first, then find the closest existing implementation and name it. Where yours
differs, say which is right. If the existing one is wrong, say whether this change
fixes it or leaves it and why — but never adopt its shape because it is already
there. House conventions are the exception: where one decides the *form*, follow
it rather than relitigating it here, though a convention never justifies a root
choice on its own.

**3. Name the simpler design you rejected and the specific thing that breaks
under it.** The cheapest mechanism is the one you do not build, so start the search
there: can the requirement be met by deleting something, by configuration, or by
a capability the datastore, framework or library already has? Only then a smaller
mechanism of your own. Not "it would be less flexible" — the input, state, or
caller it fails for. A simpler design you cannot name is one you never considered.

**4. Count what this change adds, and name what it deletes.** Every new module,
class, config field, key, job or state maps to the acceptance criterion or
constraint that forces it; one you cannot map comes out of the design. On the
other side, a file, a function, a branch, a duplicate. A change that only adds is
usually one that should have modified something. If nothing is deleted, say so and
why that is right here.

**5. Name how the behaviour is tested without mocks.** The pure function or the
contract the test will assert on. If it cannot be tested without mocking, name the
I/O, clock, or global state it reads — that impurity is the design problem, and
moving it to the edge usually is the fix.

**6. Nouns become types; verbs find owners.** Take the requirement sentence from
Q1. For each noun, name the type that represents it, or write `primitive: str /
dict / list`. A primitive is a missing type when invalid values are representable,
units or meanings can be confused, or rules travel with the value — a closed set is
always an enum; an opaque label that nothing interprets can stay a string. For each
verb, name what owns the decision: a rule that reads one model's fields belongs on
that model, and one spanning several models or external policy is a pure function,
never logic left in the service that orchestrates it.

**7. Repeated knowledge is an unnamed abstraction; repeated shape is not.** While
reading the existing code in Q2, cite every place this change's *decision* already
occurs — the same dict key set, an `if` chain over the same enum, a parallel pair
of functions encoding the same rule. The test is whether the sites would *have to*
change together. If they would, that is the abstraction, unnamed; name it and
retire the loser in this change. If they merely look alike — a shared
find-loop-transform-write skeleton, two validators that happen to match today —
leave them apart, because duplication is far cheaper than the wrong abstraction.
This is the mirror of the indirection row below: that one stops abstractions with
one instance, this one catches concepts with several instances and no name.

**8. Name the next change and count the files it touches.** Not a speculative
feature — the change this area keeps receiving: a new region, a new source, a new
variant. If that routine change would edit several unrelated files under your
design, the boundaries are wrong, and this is the cheapest moment to move them.
It is the strongest evidence a design review has, so answer it before a reviewer
does.

## Then, by what the change touches

Answer only the rows that apply. Each answer names something.

| The change… | Answer |
|---|---|
| **Adds a class or module** | Its one reason to change, in one sentence — two sentences means two units. The secret it hides — a format, a layout, an algorithm — and how many callers change if that secret changes; "all of them" means it hides nothing. Which object owns the data each new rule reads, and the rule goes on that object. Each invariant it holds and the *single* place that enforces it — an invariant checked at three call sites is enforced nowhere. |
| **Adds a parameter, flag, hook, base class, or indirection** | For each one, the present caller or requirement that forces it. "A second caller later" is not one; the indirection is added when the second caller arrives. A parameter every caller must reason about is complexity pushed upward — compute it inside instead. For any abstraction, cite the existing instances it unifies — one instance means inline it. Then trace one request through the change and list the files a reader opens, in order — each hop past three needs the concrete requirement that forces it. |
| **Extends an existing abstraction** | Whether it still fits without special cases. A flag that lets one caller opt out, a branch on *which* caller is calling, or a caller passing `null` for arguments that don't apply to it each mean the abstraction is wrong: inline it back into its callers and let the real shape show, rather than bending it again. |
| **Branches on a kind, mode, region, or entity type** | Is the branching a table? Name the mapping — a dict keyed by the enum, an exhaustive `match` (closed with `assert_never` or the language's equivalent), a pipeline of pure transforms — or the reason control flow is genuinely required. An `if/elif` over a closed set is data written as code. |
| **Adds a boundary** (HTTP, LLM structured output, file, external client, config) | The validated type at that edge, decoded by the layer that knows the wire format, and the concept each primitive crossing it stands for. Which side of the seam each decision sits on — business rules out of transport and storage, storage and wire details out of the domain. When the boundary fails, the place the error surfaces and who acts on it — a swallowed failure is a future incident. |
| **Changes a persisted model, public contract, event schema, or migration** | These are the decisions expensive to reverse, so spend the effort here. Whether the old shape stays readable during rollout, the reverse path, and what happens if the migration or backfill runs twice. Each multi-step write and the transaction that makes it atomic. For each stored value, its single source of truth, and why it is stored rather than derived. |
| **Retries, caches, schedules, runs async, or shares mutable state** | The effect of the operation running twice, and why that is safe. For a cache, everything the key contains — tenant, locale, version — and the write that invalidates it. For shared state, what is shared, who mutates it, and the guard on every path. Any ordering the design assumes — events arriving in sequence, one worker per entity, an event emitted after the commit — and what enforces it. |
| **Checks permissions, identity, or tenancy** | The single place the check sits so that every path to the resource passes it, including new bulk and internal variants. The tenant or owner scope applied in the query, not filtered after it. Identity taken from the session, never from the request body. |
| **Computes money or a rounded figure** | The type (never binary floating point), the rounding rule and the step it applies at, the unit and currency carried in the type or name, and which side is authoritative when per-line rounding disagrees with the total. |
| **Touches a prompt or an LLM-facing schema description** | Prompt or code: intent and shape belong in the prompt; a count, fallback, closed set, or format belongs in a validator or post-processing. The canonical section the rule lives in today, or will — name it, so a third copy is visible. The schema descriptions the LLM sees alongside this rule, and whether they still agree. |
| **Crosses a repo boundary** | The contract's shape, which repo owns it, and what the consumer does with an absent or unknown value while the producer is unmerged. Decide the shape here; amend the note as its detail firms up. |

## What a real answer looks like

Every answer above is a noun: a file path, a type, a caller, a section heading, a
rejected sketch. Adjectives are not answers, and the size of the change does not
waive the eight. "Cleaner", "simpler", "more flexible", "more idiomatic" each need
the concrete thing behind them or they are dropped. A two-file change that adds a
class is exactly the case this exists for.

**Where an answer rests on a capability or an assumption, prove it.** "Let the datastore do
the transform in place" sounds right and may be impossible for this transform. So
write the smallest artifact that shows it is real — the operator expression, the
method signature, the boundary type, two or three lines checked against the version
actually in the repo. The same goes for the assumption the design would fail
without — a cardinality, a volume, an ordering, a closed set, callers that already
carry tenant context: cite the evidence for it, or isolate it so that being wrong
costs one file. If you cannot prove either, the design falls back to the next-best
option, and the note says so.
