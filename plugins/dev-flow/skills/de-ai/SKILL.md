---
name: de-ai
description: Rewrite text so it stops reading as AI-generated — strip the tell-tale phrasing, punctuation, and structure, and turn choppy staccato sentences into flowing prose where each statement connects to the ones around it. Use on any drafted prose (docs, messages, summaries) before it ships.
argument-hint: [file path, pasted text, or "last" for the previous thing you wrote]
allowed-tools: Read, Edit, Write, Grep
---

# de-ai

Make prose read like a person wrote it. Target is natural, connected, flowing
writing (the ChatGPT-style register Sujit prefers) — not Claude's clipped,
staccato, one-idea-per-line word-salad.

## Step 1 — Load the guide

Read `${CLAUDE_PLUGIN_ROOT}/references/de-ai-guide.md`. Part 1 holds the generic
AI tells, Part 2 the register and flow rules, and **Part 3 the measured
Claude-specific tells** — Claude's own vocabulary and structural habits, with
frequency counts from real transcripts. Part 3 is the one that catches output
that already passed a generic AI-writing check. That guide is the standard;
apply it literally.

## Step 2 — Resolve the target

- A **file path** → read it; rewrite the prose in place (Edit), leaving code
  blocks, commands, quotes, tables, and data untouched.
- **Pasted text** in `$ARGUMENTS` → rewrite it and return the result.
- **"last"** (or no argument) → rewrite the prose you most recently produced in
  this session.

## Step 3 — Rewrite

Hold the whole guide live, but these carry the most weight:

- **Flow over fragments.** Connect sentences so each one follows from the last
  and sets up the next, joining choppy standalone lines with the logical
  connective that was implied but never written (because, so, which meant, even
  though, since). Vary sentence length and rhythm. No staccato bursts, no
  one-line-per-thought stacking for emphasis.
- **Build paragraphs, not stacks.** A paragraph should develop one complete idea
  over roughly five to eight sentences and then stop. A one-sentence paragraph is
  almost always a sentence that belongs in the paragraph above or below it, so
  merge it in. Introduce an idea in prose before listing anything beneath it, and
  transition into the next section instead of restarting cold.
- **Write for a reader, not a scanner.** Optimise for readability over
  scanability: cut headings that only exist to separate two paragraphs, and cut
  bullet lists that are really sentences someone declined to join up. Keep
  bullets for genuine lists and steps. (Ranked review findings, status pings and
  tables are exempt — see the guide's scope note.)
- **Kill the stock AI phrasing** — the "it's not just X, it's Y" construction,
  rule-of-three padding, "it's important to note," "plays a crucial role,"
  "stands as a testament," "rich tapestry," "in the realm of," "moreover /
  furthermore" pile-ups, and hollow summarising ("In conclusion").
- **Kill Claude's own phrasing** (guide Part 3), which survives a generic pass:
  padding adverbs (`actually`, `genuinely`, `precisely`, `deliberately`,
  `cleanly`, `silently`, `exactly`), stock frames (`load-bearing`, `the honest
  answer`, `the real question`, `worth noting`, `here's why`, `reads as`, `doing
  a lot of work`, `earns its place`, `the crux`, `caveat`, `non-trivial`),
  stakes-raising first person ("the part I'd defend hardest"), concessive
  throat-clearing ("to be fair", "that said", "to be clear"), and the
  `rather than` / `instead of` contrast reflex.
- **Vary the openers.** Claude starts one sentence in eight with "Let me", and
  leans on "Now", "So", "This" and "That's". Counted openers ("Two things worth
  noting…") are the same habit; start with the first item instead.
- **Cut puffery and inflated importance.** Say the thing plainly; drop
  editorial adjectives and marketing tone.
- **Fix the punctuation tells** — remove em-dash overuse (recast the sentence
  or use a comma / full stop), curly quotes, stray emoji, and bolding used for
  emphasis.

## Step 4 — Preserve, don't invent

Keep the meaning, the facts, and the author's intent exactly. Don't add claims,
don't inflate, don't pad. Aim for the same length or tighter — de-AI-ing almost
always shortens.

## Step 5 — Self-check

Two passes, because the phrasing tells and the structural tells fail
independently — prose can be free of every banned phrase and still read as a
stack of fragments.

**Phrasing.** Grep for the generic offenders and Claude's own:

```bash
# generic AI tells
grep -niE "it'?s not just|rich tapestry|crucial role|testament to|in the realm of|moreover|furthermore|it'?s important to note|in conclusion|—" <file>

# Claude's tells (guide Part 3)
grep -niE "load-bearing|the honest (answer|version)|the real question|the short answer|worth (noting|flagging)|here'?s (what|why|how)|reads (as|like)|doing a lot of work|earns? its (place|keep)|the crux|caveat|non-trivial|table stakes|boils down to|comes down to|to be (fair|clear)|that said|i'?ll be honest|for what it'?s worth|defend .{0,15}hardest" <file>

# padding adverbs and the contrast reflex — judge in context, don't blanket-delete
grep -noiE "actually|genuinely|precisely|deliberately|cleanly|silently|exactly|effectively|essentially|ultimately|rather than|instead of" <file> | sort -t: -k2 | uniq -cf1 | sort -rn | head
```

**Structure.** Measure it rather than eyeballing it, against the targets in the
guide's Part 3 table (under 10% very-short sentences, under 15% one-or-two
sentence paragraphs):

```bash
perl -0777 -ne 's/\n+/ /g; s/([.!?])\s+/$1\n/g; print' <file> \
  | awk 'NF>2{t++; s+=NF; if(NF<=8)a++} END{printf "short sentences: %.0f%% (target <10%%), mean %.1f words\n", a*100/t, s/t}'

perl -0777 -ne 'for (split /\n\s*\n/) { next unless /\w/; next if /^\s*[-*\d#|`]/;
  my $c = () = /[.!?](?:\s|$)/g; print "$c\n" if $c }' <file> \
  | awk '{t++; if($1<=2)a++} END{printf "1-2 sentence paragraphs: %.0f%% (target <15%%)\n", a*100/t}'
```

The paragraph figure only means something on continuous prose. A reference
document that is mostly lists will score badly for legitimate reasons, since
every list lead-in ("The three figures to move:") counts as a one-sentence
paragraph, so read the number as a prompt to look rather than a defect to fix.
The sentence-length figure is reliable everywhere.

Then read the rewrite once more top to bottom for flow. If any line still reads
as a disconnected fragment, join it in. Report what you changed (or show the
diff), including the two structural numbers before and after.
