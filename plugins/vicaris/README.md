<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/vicaris-sigil-dark.svg">
    <img src="assets/vicaris-sigil.svg" width="104" alt="Vicaris">
  </picture>
</p>

<h1 align="center">VICARIS</h1>
<p align="center"><em>The one you send in your place.</em></p>

Vicaris takes a development story and brings it back as reviewed, tested merge
requests across every repository the story touches, together with a written
record of every decision it made on the way. You give it a ticket key or a brief
and walk away. It does not stop to ask you things; it decides each fork, writes
down the reading it took and the one it rejected, and keeps you informed in a
single Slack thread you can read whenever you like.

It is a Claude Code plugin, and it is opinionated: the code it writes and the
reviews it runs are held to a captured statement of how Sujit likes code written
(`references/coding-principles.md`), not to a generic idea of quality.

```
/vicaris PROJ-1234        # or a free-text brief
```

## What a run looks like

The first thing you see is a Slack message naming the ticket, the repos in scope,
the risk class, and the two to four acceptance criteria whose reading could be
wrong, each with the reading Vicaris took. That message is the one point where
correcting a misunderstanding is still free, so it is worth a glance; nothing
waits for you to reply.

From there the thread ticks along at each stage boundary: understanding done, each
repo built, review findings and how they were settled, test results, each MR as it
goes up. It pings you directly only for the short, closed list of things it cannot
do alone — an expired login, a missing credential, an irreversible product call —
and even then it finishes everything that is not blocked.

What comes back is **the Record**:

- one MR per repo, cross-linked under the same ticket, each already through the
  standalone MR reviewer;
- a completion doc per run: what changed, every assumption with the alternative
  it beat and why, what was tested and what was not;
- the design notes beside the code in each repo, and a ledger of every review
  finding with the decision taken on it.

## How it works

```
/vicaris <task>
   │
   ├─ understand         acceptance criteria, each ambiguous one with the reading
   │                     rejected · gaps and contradictions · repos in scope ·
   │                     non-functional constraints · → RISK CLASS
   ├─ implement          design note per repo → design challenge (elevated+) →
   │                     build in slices → tests → simplification pass
   ├─ gate               every repo's verify green · risk re-derived from the
   │                     paths actually touched · integrated smoke
   ├─ adversarial-review craft, architect and integration passes per repo, plus
   │                     one acceptance-criteria pass over the whole change
   ├─ test               browser run of anything user-visible, logs and traces
   └─ finalize           completion doc · MR per repo · MR review · wrap-up
```

A handful of ideas carry the design, and each exists because the obvious version
failed.

**Ceremony is bought by risk, not applied uniformly.** `understand` puts the change
in one of five classes — `mechanical`, `tiny`, `normal`, `elevated`, `production` —
and every later stage reads the class instead of deciding its own depth. A field
threaded through an existing pattern gets a parity check that finds the fourth
consumer nobody updated; a migration gets a design challenge, forced review passes,
a rehearsed up-and-down and a rollback plan. The class is predicted from the story
and then re-derived from the files actually touched, and it can only go up.

**The design is challenged before any code exists.** Every review pass starts from
the diff, so every review pass inherits the decision the diff embodies. At
`elevated` and above, a second design is built from the acceptance criteria alone,
by an agent that cannot see the plan, the notes or the branch, and the two are
compared while a divergence still costs a paragraph rather than a rework.

**Nothing expensive starts on code that has not earned it.** Reviewers are not
spawned until every repo builds and passes its own suite, and every fix loop —
review, test, MR review — stops after two passes and declares what is outstanding.
A review still multiplying findings after two rounds is repairing a design, and a
third round of patches will not settle that.

**Cross-repo is the normal case.** The repo set is pinned once, and from then on
every stage covers all of it, in dependency order, with the contract between repos
reviewed against its real callers. `scripts/vicaris-status.sh` fails the run if any
repo has work without a verify result or an MR, so coverage is checked rather than
remembered.

**It never asks.** Forks are resolved from `references/autonomy.md`, the same file
every stage reads, so a question answered once is answered the same way everywhere.
Scope is never quietly reduced; if part of the story is blocked, the rest ships in
full and the remainder is recorded as follow-on.

**Losing context is a non-event.** A handover doc is refreshed at every stage
boundary, and hooks re-inject the run's state after a compaction, so a long run
survives both compaction and a fresh session.

### Models

Judgement runs on **Opus**: understanding, design notes, the design comparison,
review and finalize. The build runs on **Sonnet** at `mechanical`, `tiny` and
`normal`, where the shape is already decided and the token volume is highest, and
on Opus at `elevated` and `production`, where the contract is still settling as it
is written. **Fable** runs only the blind designer, so the independent design comes
from a different model than the notes it is checking. Run the session at high
reasoning effort and set it explicitly, since Opus 5.5 defaults to `medium`.

## Setup

```bash
claude plugin marketplace add <path-to-this-repo>
claude plugin install vicaris@sujit-marketplace
```

When you enable the plugin, Claude Code asks for your name and your Slack member
ID. They are kept in your own user settings rather than in this repo, and every
stage uses them for who it reports to and where it sends updates; change them
later with `/config`.

Everything specific to the project you point it at lives in one sidecar. Copy `references/project-context.template.md` to
`references/project-context.md` and fill in the verify command, how to run and log
into the app, observability, the MR reviewer and the Slack target. That file is
gitignored so project detail never lands in this repo, and every stage runs
without it, just with fewer shortcuts.

It expects, and says at the start of a run which of these are missing:

- Slack, Atlassian and a browser MCP (chrome-devtools) connected;
- the `mr-review` plugin, which supplies the review charter and the design
  challenge's two charters (without it both fall back to inline prompts);
- a standalone MR reviewer, if you want MRs reviewed (see the sidecar).

`byline`, if installed, is used for prose cleanup in the generated docs; nothing
depends on it.

## Inside the plugin

Every stage is also a standalone skill, so you can run one on its own.

| | |
|---|---|
| **Skills** | `/vicaris` (the orchestrator), `/understand`, `/implement`, `/design-challenge`, `/adversarial-review`, `/test`, `/handover`, `/finalize` |
| **References** | `autonomy` (the contract and standing resolutions) · `risk-classes` (what each class buys) · `gates` (what must be green, the two-pass cap) · `coding-principles` (the standard) · `multi-repo` (the manifest and per-repo invariants) · `notifications` (the Slack drumbeat) · `project-context.template` |
| **Agents** | `blind-designer` (Fable, read-only, no shell, so it cannot see the branch) · `acceptance-criteria` (Sonnet, read-only) |
| **Scripts** | `vicaris-risk.sh` (observed class, raise-only) · `vicaris-gate.sh` (records each repo's verify) · `vicaris-parity.sh` (every instance of a pattern, touched or not) · `vicaris-status.sh` (per-repo coverage) · `mr-review-root.sh` · `browser-login-helper.sh` (keychain login that keeps passwords out of the model's context) |
| **Hooks** | `SessionStart` re-injects the run's state; `PreCompact` warns when the handover doc is stale |

## The name

*Vicarius* is Latin for the one who acts in another's place, which is the whole
job. The cat in the mark is a familiar, the creature a witch sends out to do her
errands, and that is the relationship too: you hand it the story, it goes, and it
comes back with a record of what it did.
