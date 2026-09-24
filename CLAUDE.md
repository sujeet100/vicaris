# Vicaris

Autonomous end-to-end development workflow, packaged as a Claude Code plugin in
`plugins/vicaris/`. Tagline: *The one you send in your place.*

## Visual identity

Use this section whenever you produce anything visual for Vicaris — README
art, slides, social cards, stickers, a site. It records the decisions; the
files are the source of truth for geometry.

**The Familiar.** Vicaris is a compact black feline creature with amber eyes,
drawn in the Dark-type register rather than the cute one. A familiar is the one
you send out to act in your place, so the metaphor needs no explanation. It has
two states, and they map onto the product's idle and running states:

| | At rest | Working |
|---|---|---|
| Posture | Seated three-quarter on, head turned to the viewer, haunch behind, forelegs close under the chest | Identical. The body does not move between states |
| Ears | Up, slight outward rake | Flattened back and out |
| Eyes | Open almonds, V pupil relaxed | Narrowed, V pupil tight |
| Brow | Plain ink | Amber seal (hexagon with a V inside) visible |
| Tail | Swept up behind the haunch in a question-mark curve, nib clear of the body | Identical |

Only the head changes between states, as a real cat signals with ears and
pupils rather than posture. A crouch was tried and rejected: face-on it is all
foreshortening, which five flat shapes cannot show, and it made the two states
look like two different animals.

**The mark** is the Familiar's head alone: two tall outward-raked ears, a
wedge face, two amber wedges for eyes, no pupils, no curves. Five flat shapes.
Below about 48px the body goes and the head is the whole identity; from 32px
up a V may be cut into each eye. The mark was drawn on a 16-unit grid, so the
favicon is the same geometry, not a simplification.

**Assets** live in `plugins/vicaris/assets/`:

| File | Use |
|---|---|
| `vicaris-sigil.svg` | Primary mark, ink + amber, for light grounds |
| `vicaris-sigil-dark.svg` | Same mark with a 0.7-unit bone rim behind the fill, for ink grounds |
| `vicaris-sigil-mono.svg` | One ink via `currentColor`; eyes cut out with a mask so it inverts with the theme |
| `vicaris-sigil-16.svg` | Favicon build, identical geometry at 16×16 |
| `vicaris-familiar-rest.svg`, `-rest-dark.svg` | Mascot at rest; the `-dark` build carries the bone rim |
| `vicaris-familiar-working.svg`, `-working-dark.svg` | Mascot working: the same body with the working head, seal on the brow |

The mascot body is constructed geometry rather than eyeballed linework: one
continuous chest curve, a haunch that is a true arc, a tail swept along a
curve with linear taper, three paws from one template on a common baseline.
Hairlines in the ground colour separate the forelegs, the thigh and the head
from the body, so they read as dark on bone and vanish into the ink build,
where the bone rim does the separating. Change the body in one file and mirror
the change into the other three; the four files share every body path.

**Palette.** One gold only.

| Token | Hex | Role |
|---|---|---|
| Ink | `#15130F` | Fur, text on light grounds. Warm, not pure black |
| Ground | `#0B0A08` | Dark surfaces, slide backgrounds |
| Bone | `#EDE6D6` | Paper, light grounds, the rim on dark |
| Amber | `#C9963A` | Eyes, the seal, every UI accent |

The previous palette (Ink `#0C0C0F`, Bone `#E6E1D5`, Brass `#C9A961`) and the
V-in-hexagon sigil are retired. The hexagon-and-V survives only as the seal on
the working pose's brow.

**On dark grounds** an ink creature vanishes except for its eyes. That is
atmospheric in a hero image and useless anywhere else, so every dark build puts
a bone hairline *behind* the fill: it rims the outer silhouette and never traces
the seams between shapes. Do not outline each shape individually.

**Fixed details.** The concept is the most obvious familiar there is, so these
are what make it ours. Do not vary them:

- The pupil is a vertical V, never a round pupil or a plain slit.
- Ears are tall, narrow and raked outward, never bat-shaped, never tufted.
- No collar, no tag. A familiar is bonded, not owned.
- The seal appears on the brow only while working, is a hexagon (never a
  crescent), and never glows.
- The tail hooks and ends in a flat nib taper, never a spear or diamond.
- Paws are long-toed, not oversized.
- No body markings, rings or gradients. Warm ink fur, amber eyes, nothing else.

**Neighbours to stay clear of:** Umbreon (rings), Luna from Sailor Moon
(crescent brow), Salem and the Halloween cut-out (arched back, bat ears), and
GitHub's Octocat (round and friendly, where this is angular and watchful).

**Type,** as used on the study page and a sensible default for slides:
Fraunces for display, IBM Plex Sans for body, JetBrains Mono for labels and
code. Uppercase labels get letter-spacing; avoid Inter and Space Grotesk.

**Reference.** The silhouette study that settled these decisions:
https://claude.ai/artifact/CeD9uh79PAzy7BLB9tv2KY (private).
