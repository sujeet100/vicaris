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

Read `${CLAUDE_PLUGIN_ROOT}/references/de-ai-guide.md`. It holds the concrete
**Avoid** tells and the **Prefer** rules for flowing prose. That guide is the
standard; apply it literally.

## Step 2 — Resolve the target

- A **file path** → read it; rewrite the prose in place (Edit), leaving code
  blocks, commands, quotes, tables, and data untouched.
- **Pasted text** in `$ARGUMENTS` → rewrite it and return the result.
- **"last"** (or no argument) → rewrite the prose you most recently produced in
  this session.

## Step 3 — Rewrite

Hold the whole guide live, but these carry the most weight:

- **Flow over fragments.** Connect sentences so each one follows from the last
  and sets up the next. Merge choppy standalone lines into sentences joined by
  natural connectives. Vary sentence length and rhythm. No staccato bursts, no
  one-line-per-thought stacking for emphasis.
- **Kill the stock AI phrasing** — the "it's not just X, it's Y" construction,
  rule-of-three padding, "it's important to note," "plays a crucial role,"
  "stands as a testament," "rich tapestry," "in the realm of," "moreover /
  furthermore" pile-ups, and hollow summarising ("In conclusion").
- **Cut puffery and inflated importance.** Say the thing plainly; drop
  editorial adjectives and marketing tone.
- **Fix the punctuation tells** — remove em-dash overuse (recast the sentence
  or use a comma / full stop), curly quotes, stray emoji, and bolding used for
  emphasis.
- **Undo over-structuring** where prose should just be prose — collapse
  needless bullet lists and over-sectioning into paragraphs (keep bullets only
  for genuine lists or steps).

## Step 4 — Preserve, don't invent

Keep the meaning, the facts, and the author's intent exactly. Don't add claims,
don't inflate, don't pad. Aim for the same length or tighter — de-AI-ing almost
always shortens.

## Step 5 — Self-check

Grep the result for the worst offenders and confirm they're gone:

```bash
grep -niE "it'?s not just|rich tapestry|crucial role|testament to|in the realm of|moreover|furthermore|it'?s important to note|in conclusion|—" <file>
```

Read the rewrite once more top to bottom for flow. If any line still reads as a
disconnected fragment, join it in. Report what you changed (or show the diff).
