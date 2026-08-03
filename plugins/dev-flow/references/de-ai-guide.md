# De-AI guide — prose that doesn't read as AI-generated

The standard the `de-ai` skill applies, and the bar for any prose this workflow
generates (completion docs, review write-ups, summaries). Part 1 and Part 2 are
drawn from Wikipedia's *Signs of AI writing*, filtered to general prose with the
Wikipedia-process guidance removed; Part 3 is measured from Claude's own output
in this workspace.

The single most important rule sits above the list: **every sentence connects
to its neighbours.** Sujit's recurring complaint is choppy, staccato,
one-idea-per-line output that reads as a salad of disconnected statements.
Prefer flowing, connected phrasing where each sentence picks up a thread from
the one before and sets up the one after.

**Scope.** This guide governs *prose* — explanations, completion docs, summaries,
messages, documentation. It does not govern structured output that is meant to be
scanned rather than read, so review reports keep their ranked findings, status
pings stay clipped and factual, and tables, commands, file lists and diffs are
left exactly as they are. When the two pull against each other, ask whether a
reader consumes the thing top to bottom or jumps into the middle of it looking
for one item; the first is prose and follows this guide, the second is a table
wearing sentences and should probably be an actual table.

## Part 1 — Avoid

### Phrasing

Significance-inflation frames that make ordinary things sound momentous:

- "stands / serves as a testament to"
- "plays a crucial / pivotal / vital / key role"
- "underscores / highlights its importance"
- "leaves an indelible mark", "a key turning point"
- "represents / marks a shift", "setting the stage for", "shaping the"
- "reflects a broader", "deeply rooted"

Abstract-noun clichés:

- "rich / vibrant tapestry"
- "evolving / shifting landscape", "navigating the landscape"
- "in the realm of", "focal point", "interplay of", "intricacies of"

Hedging and filler openers:

- "It's important to note that…", "It's worth mentioning…"

Trailing "-ing" participle clauses that fake analytical depth: "…, highlighting
its significance", "…, ensuring a seamless experience", "…, reflecting broader
trends", "…, fostering innovation."

Words that are fine alone but damning in density: additionally, moreover,
furthermore, delve, boasts, bolstered, robust, showcase, garner, foster,
meticulous, enhance, underscore, testament, valuable insights, align / resonate
with, crucial, pivotal, enduring.

Vague attribution and weasel sourcing: "some critics argue", "experts say",
"observers have cited", "industry reports suggest" — opinions pinned on unnamed
authorities, or a few sources inflated into a consensus.

### Structure

- **Negative parallelism** as a tic: "it's not just X, it's Y", "not only… but
  also…", "no…, no…, just…". It fakes correcting the reader.
- **Rule-of-three padding:** stacked triples of adjectives or phrases used to
  simulate thoroughness.
- **Formulaic intro/body/conclusion** shape and mechanical closing sections
  ("Challenges and Future Prospects", "Legacy and Future Outlook").
- **Canned conclusions:** "Despite its [positives], [subject] faces several
  challenges…" plus vague speculation, or any paragraph that just restates what
  came before.
- **Over-sectioning** and inline-header bullets ("**Overview**: …") where
  flowing prose belongs.
- **Elegant variation:** swapping in awkward synonyms so one concept wears
  three labels in a short span.
- **Choppy staccato:** a run of short, disconnected standalone sentences where
  each stands alone instead of connecting to its neighbours.

### Punctuation and formatting

- **Em-dash overuse** standing in for commas, colons, and parentheses.
- **Curly / smart quotes** instead of straight ones.
- **Emoji used as formatting or bullets.**
- **Excessive boldface** — bolding every instance of a term, "key takeaways"
  treatment, sales-pitch emphasis.
- **Title-Case Headings** instead of sentence case.

### Tone

- **Puffery and promotional diction:** "renowned", "groundbreaking", "boasts",
  "diverse array", "nestled", "in the heart of", "commitment to" — press-release
  register applied to ordinary subjects.
- **Inflated importance:** treating a routine subject as historically momentous.
- **Superficial depth:** participle flourishes and triples that add words, not
  substance.

## Part 2 — Prefer

### The register to write in

Write as an experienced engineer explaining something to another experienced
engineer: professional but conversational, and confident enough not to hedge.
The finished thing should read like a polished article rather than generated
documentation, which mostly comes down to letting ideas develop instead of
filing them. Introduce an idea in prose before you list anything under it, carry
the reader through the reasoning with natural transitions, and let each section
hand off to the next rather than restarting cold. Optimise for readability over
scanability: someone reading top to bottom should never feel they are being
handed fragments to assemble themselves.

Concretely, that means paragraphs of roughly five to eight sentences that
develop one complete idea and then stop, rather than a paragraph per thought.
Aim for a spread of sentence lengths with the bulk in the fifteen-to-thirty-word
range, since a short sentence lands hardest when it follows longer ones and does
nothing at all when every sentence around it is short. Cut headings that only
exist to break up two paragraphs, and cut bullet lists that are really just
sentences someone declined to join up.

### The rules

- **Connect every sentence to its neighbours.** Each sentence should pick up a
  thread from the one before and hand off to the one after, so a paragraph
  reads as one line of thought rather than a list of facts. Use genuine logical
  transitions (because, so, which meant, even though) rather than decorative
  connectors.
- **Prefer medium-length sentences linked with transitions** over short clipped
  standalones. If three consecutive sentences could be reordered without loss,
  they aren't connected — rewrite so the order matters.
- **Say the thing plainly.** State importance with a concrete fact, not an
  adjective: show what changed rather than asserting that it "played a crucial
  role."
- **Repeat the key term** rather than reaching for a synonym; clarity beats
  lexical variety.
- **Reserve bullet lists for genuine lists or steps.** Anything argumentative
  or explanatory belongs in prose paragraphs.
- **Attribute specifically or not at all.** Name the source or drop the claim.
- **Use straight quotes, sentence-case headings, and em dashes sparingly**, and
  let commas and full stops carry most of the work.
- **End when the point is made.** Skip the summarising conclusion that restates
  the body.
- **Vary sentence rhythm.** A short sentence lands hardest after longer ones,
  not when every sentence is short.

## Part 3 — Claude's own tells (measured)

Part 1 catches generic AI writing. This part catches *Claude's* writing, which
has its own vocabulary and its own structural habits, and the reason to treat it
separately is that none of it looks wrong in isolation — it only becomes a tell
through repetition, at which point a reader who sees a lot of this output starts
recognising the author. The numbers below are counts from 168 Claude Code
transcripts in this workspace, about 188,000 words of assistant prose, expressed
as occurrences per 100,000 words so they are comparable to each other. Re-measure
with the script in Part 4 whenever you want fresh figures.

### Padding adverbs

These carry no information in almost every position Claude uses them. Delete the
word first and only put it back if the sentence changed meaning, which it
usually did not.

`actually` (121) · `genuinely` (52) · `silently` (40) · `cleanly` (37) ·
`precisely` (24) · `deliberately` (24) · `exactly` (56, as "exactly the" /
"exactly what") · `effectively` (6) · `quietly` (5) · `essentially` ·
`fundamentally` · `ultimately` · `notably` · `importantly` · `crucially` ·
`squarely` · `neatly` · `meaningfully` · `materially`

### Stock frames and stock vocabulary

Each of these is a phrase Claude reaches for when it wants to sound like it has
weighed something. Say the thing instead.

- `load-bearing` (10) — "the load-bearing part of the design"
- `the honest answer` / `the honest version` / `the useful version`
- `the real question is` / `the whole point is` / `the interesting part`
- `the short answer` followed by a long answer
- `worth noting` (5) / `worth flagging` (6) — if it were not worth it, you would
  have cut it, so just write the sentence
- `here's what` / `here's why` / `here's how` (15)
- `reads as` / `reads like` (12) — "this reads as templated"
- `doing a lot of work` — "the phrase is doing a lot of work"
- `earns its place` / `earns its keep` (4)
- `what it buys you` / `what that buys`
- `caveat` (16), `non-trivial`, `nuance`, `the crux`, `table stakes`,
  `first-class`, `footgun`, `sharp edges`, `defensible`, `idiomatic`
- `boils down to` / `comes down to` / `at its core`
- `grounded in` (6), `calibrate` (3)
- `the good news` / `the bad news` as a paragraph opener
- **Stakes-raising first person:** "I would defend that hardest", "the part I'd
  fight for", "if there is one thing to take away". State the position without
  dramatising your commitment to it.
- **Concessive throat-clearing:** "to be fair", "to be clear", "that said",
  "for what it's worth", "I'll be honest", "honestly" (5). Either the point
  survives without the disclaimer or it needs a better argument.

### Contrast crutches

`rather than` (121) and `instead of` (57) are Claude's reflex for every
comparison, and the trailing `X, not Y` tail does the same job a third time. One
per few paragraphs is normal writing; three in a paragraph is a tic. Recast into
a plain assertion, or name only the thing you mean and let the alternative go
unmentioned.

### Repetitive openers

Claude opens sentences from a very small set. `Let me` accounts for 1018
sentence starts, roughly one sentence in eight, and after it come `The` (1112),
`Now` (292), `So` (210), `This` (144) and `That's` (89). The counted opener is
its own habit: `Two things worth…`, `One thing to note…`, `Three of these…`
(180 combined). Vary the opening; in particular, a paragraph that starts by
announcing how many items it contains can almost always start with the first
item instead.

### Structural habits, with the numbers to beat

The measured baseline is choppier than it should be, and these are the three
figures to move:

| Measure | Claude's baseline | Target |
|---|---|---|
| Sentences of 8 words or fewer | 19% | under 10%, and used to land a point |
| Prose paragraphs of 1–2 sentences | 42% | under 15%; aim for 5–8 sentences |
| Em dashes per 100k words | 1610 (one every 62 words) | near zero in prose |

A paragraph that is one sentence long is almost always a sentence that belongs
in the paragraph above or below it. A run of three or four such paragraphs is the
staccato failure in its purest form: each line states a fact, none of them leads
anywhere, and the order could be shuffled without the reader noticing. The fix is
mechanical — join them with the logical connective that was implied but never
written (because, so, which meant, even though, since) and the argument becomes
visible.

## Part 4 — Re-measuring

To refresh the counts above against current output:

```bash
find ~/.claude/projects -name '*.jsonl' -print0 | xargs -0 cat \
  | jq -r 'select(.type=="assistant") | .message.content[]?
           | select(.type=="text") | .text' > /tmp/prose.txt

# rate per 100k words for one phrase
total=$(wc -w < /tmp/prose.txt)
n=$(grep -oiE -- 'load-bearing' /tmp/prose.txt | wc -l)
echo "scale=1; $n*100000/$total" | bc

# sentence-length and paragraph-length distribution
perl -0777 -ne 's/\n+/ /g; s/([.!?])\s+/$1\n/g; print' /tmp/prose.txt \
  | awk 'NF>2{t++; s+=NF; if(NF<=8)a++} END{printf "%.0f%% <=8w, mean %.1f\n", a*100/t, s/t}'
```

Note that `sed 's/x/\n/g'` does not insert a newline on macOS/BSD, so use `perl`
for the sentence split.
