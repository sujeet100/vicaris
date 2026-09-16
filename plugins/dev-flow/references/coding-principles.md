# Coding Principles — Sujit

The canonical statement of how code should be written and reviewed in this
workflow. Every stage reads this: **plan** designs against it, **implement**
writes to it, **adversarial review** grades by it.

This file is deliberately language- and project-agnostic. Anything specific to
a particular codebase — verify commands, which test suites to avoid, prompt or
framework conventions, deployment or auth specifics — lives in the
`project-context.md` sidecar, which each stage loads *only if present*.

Two framings sit above every rule below:

- **The producer emits intent; code owns truth.** Counts, fallbacks,
  closed-set membership, and format validation are enforced in code
  (validators, guards, post-processing). Prose and configuration express
  intent and shape.
- **Match the response to the request.** A "temp" / "scratch" / "just to test"
  change gets the code change and a one-line flag of what breaks — nothing
  more. A change that ships gets the full bar below.

## Principles he cares about

- **Clean, readable, obvious code.** Optimise for the next reader. Clear names
  that say what a thing *is* or *does*; no cryptic abbreviations.
- **Low cyclomatic complexity.** Prefer early returns, guard clauses, and small
  composed functions over nested branching. Flag anything a reviewer has to
  trace on paper.
- **Small, single-responsibility units.** Short functions; focused modules. One
  module, one reason to change. When you touch a function, the whole function
  is fair game to tidy.
- **Declarative over imperative.** Comprehensions, map/filter semantics,
  pipeline-style transforms over manual accumulation loops. Express *what*, not
  step-by-step *how*. The greppable tells, because this one gets violated with
  the rule in context: a `continue` in a loop that only assembles a collection
  (that's a comprehension's `if`, written long); an accumulator mutated inside
  the loop that reads it, which is how a variable acquires a second meaning; and
  `while True` with a mid-loop `return` where a recursive step or a bounded
  fixed point states the same thing. A `for` loop earns its place for genuine
  side effects — I/O, logging, mutating something the caller owns.
- **Pure functions for business logic.** Validation, transforms, and
  post-processing take arguments and return values — no hidden I/O, no clock or
  environment reads inside. This makes them mock-free to test.
- **No output arguments; don't mutate then return.** A function returns a value
  *or* mutates state, never both (Command-Query Separation). Build a new value
  and return it rather than mutating a passed-in collection.
- **Avoid mutating variables where a return-and-assign reads cleaner.** Favour
  immutability and rebinding over in-place mutation.
- **Good abstractions and design patterns — when they earn their place.** Use a
  pattern to make code genuinely extensible or to remove real duplication.
  Never a pattern for its own sake (see avoids).
- **Domain modelling over primitives.** Model the domain with real types.
  Prefer a domain object over a bare list / dict / map wherever the thing has
  identity or behaviour. Enums or literal-typed values for closed sets, never a
  bare string.
- **Rich domain models, not anemic ones.** Push behaviour onto the domain
  object it belongs to; don't drain models into dumb data bags with all the
  logic living in services. A service orchestrates; the domain decides.
- **SOLID + OOP + FP, pragmatically.** Single responsibility, open/closed,
  dependency inversion at real seams; compose small pure functions; favour
  immutability. Use whichever paradigm reads cleanest for the problem.
- **Type every boundary, trust types within.** Types at every I/O edge. Prefer
  precise types over an untyped escape hatch. A pinned, coded type-ignore at
  worst, never a bare one.
- **Idiomatic, modern language constructs.** Use the newest clean feature that
  fits the language and version in hand; drop outdated equivalents. Idiomatic
  code over clever code.
- **Fail fast at boundaries.** Raise a clear error at the edge rather than
  threading a null through every caller.
- **No duplication.** Consolidate the second occurrence; don't copy-paste "to
  be safe."
- **Zero warnings.** No lint or type warnings left in. Well-formatted,
  formatter-clean code. A clean commit means the quality gates passed — never
  bypass them.

## Dogmatic avoids

- **Over-engineering and speculative abstraction.** No provider classes,
  dependency-injection param threading, config hooks, or "future-proofing" for
  a second caller that doesn't exist yet. Ask "do we actually need this?" and
  default to no.
- **Nits and bikeshedding.** Don't spend the change (or a review) on cosmetic
  preferences that don't affect correctness or maintainability.
- **Passing singletons as params purely for testability.** Call them directly;
  tests patch the import site.
- **Anemic models + fat services.** Logic marooned in a service that should
  live on the domain object.
- **Reflection / attribute-poking on typed objects** where direct typed access
  works — it erases types.
- **Type casts that lie to the checker** — narrow with a real runtime guard
  instead.
- **Untyped bags across module boundaries**, spreading a typed record into a
  loose map, reading required keys defensively as if optional.
- **Bare catch-all except, silent swallow, logging an exception as a bare
  string** (loses the traceback), exceptions for control flow.
- **Aggressive mid-refactor cleanup.** Don't delete legacy on the way past.
  Prefer a runtime toggle; validate the new path before removing the old.
  Refactors preserve behaviour **byte-identically** unless the change *is* the
  behaviour — build parity / snapshot tests and name each preservation point.
- **Outdated / imperative constructs** where an idiomatic one reads better.
- **Mutable default arguments, string-building by repeated concatenation in a
  loop.**

## Testing philosophy

- **Concise but sufficient.** Only the tests that are needed — but enough to
  cover the behaviour and the edges that matter. No test theatre, no asserting
  the framework.
- **Pure functions need no mocks.** Design for testability by keeping logic
  pure; mock only where a seam is genuinely unavoidable.
- **Verify with the fast unit suite; don't run slow or known-broken suites to
  "verify."** The exact verify command, and which suites are slow/costly
  (e.g. anything making real network or model calls) or known-broken, live in
  `project-context.md`.
- **Respect the pre-commit gates.** If the project runs formatter + type-check
  + unit tests on commit, a clean commit already means they passed — don't
  re-run them as a separate manual step, and never bypass with a no-verify
  flag.

## Collaboration style (how this workflow behaves toward Sujit)

- **Push back honestly.** Disagree when warranted; never agree just because he
  pushed. Give an option comparison with tradeoffs, not a "yes, that works."
- **Decisions: recommend, don't survey.** When there are multiple viable
  choices, think it through, pick the one you'd recommend, and **state the
  assumption plainly** so he can check it at review time. Offer 2–3 options
  with tradeoffs only when the call is genuinely his to make.
- **Review docs stay short and scannable** — bulleted "what's good," a ranked
  "what must not be missed" (one paragraph each), a "skip for now" section, and
  a one-line self-critique per recommendation. Long essays get skipped.
- **Scratch docs are his.** Story-scoped plans, flow walkthroughs, drafts —
  don't commit them, don't cite them in commit messages. Permanent docs / ADRs
  are fine.
- **No AI-writing tells** in any prose he'll read or ship: no em dashes, no
  "it's not X, it's Y," no neat parallel trios, no kicker+title scaffolding.
  Flowing connected sentences; bullets only for genuine lists.
