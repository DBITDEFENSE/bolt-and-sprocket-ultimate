# ART_FACTIONS — fictional faction marks (ULTIMATE PROMPT v2 §0.2)

GRAVELIGHT is alternate history told with respect, and it is sold everywhere. **No real Nazi symbols appear anywhere in the game, its docs, stencils, props, or marketing: no swastikas, no SS runes, no real unit, division or ministry insignia, no real eagles-and-wreaths.** Every "Reich" presence in the saga is carried by one fictional mark, defined here, so it is consistent from Map 0's billet crates to Morgenrot's rocket bodies. The same rule applies to the Allies: no real regimental badges; Peg's SOE paperwork uses a plain crown-less cipher.

## 1. Projekt Wiederkehr: the Sunburst-and-Split-Bell

**What it is:** the emblem of the Amt für Sonderforschung's **Projekt Wiederkehr** ("Return"), the programme behind Kaltenbrunn, Totenhafen and Morgenrot. It was drawn in 1942 by a draughtsman in Reinholt's office from her own description of the first resonance photograph: a bell whose note had split it down the middle, lit from behind.

**Construction (vector, monochrome; `assets/gravelight/emblem_wiederkehr.svg` when the art pass draws it):**
- A **black sunburst**: 11 rays of alternating length (long / short), no face, no eagle, no wings, rising from a horizon line. The rays are blunt, squared ends; the sunburst is a half-disc, never a full circle.
- Over the horizon line, a **bell in silhouette, split vertically** by a thin gap that widens toward the mouth. The two halves lean apart 4°.
- Below, the programme's three-letter mark **"P·W·K"** in a plain grotesque (no fraktur), optionally followed by the site: KB (Kaltenbrunn), TH (Totenhafen), HW (Hohe Wacht).
- Proportions: the bell's height equals the sunburst's radius; the gap at the mouth is one tenth of the bell's width.
- Colour: black on raw metal / concrete / canvas; **red** only as a thin ring around the sunburst on launch-crew equipment at Morgenrot; **violet never** (violet is the Nachtglas's own, and the Operator's).

```
            \  \ | /  /
         \  \   |   /  /          sunburst: 11 blunt rays
      ____\__\__|__/__/____       horizon line
            __/ \__
           /   ||   \             the bell, split: two halves leaning apart
          |    ||    |
          |____||____|
           P · W · K
```

**Usage rules:** stencilled on rocket bodies (Morgenrot), crate lids, doors, lab paperwork, armbands of the Gänger outfit kits, the Leitstand's wall; never on a flag larger than a pennant; never animated as a "logo reveal". It can be defaced (chalk, bullet holes) and it is the only such mark; where a period source would show a national emblem, the game shows nothing or the plain words of a ministry ("AMT FÜR SONDERFORSCHUNG").

## 1b. Werk Thalbach's works mark: the crane in a cog (UPDATE 10, DECISIONS T-155)

**What it is:** the house mark of the fictional aircraft works at Thalbach (Fernflug Act I), on its posters, stair
signs and pay slips. A company mark, not a state one: it carries no national emblem and nothing else is ever drawn
into it.

**Construction (procedural, `ThalbachLife.poster_texture("kranich")`):** a black **cog wheel** of 12 square teeth
(ring width one fifth of the radius); across it, left to right, a **crane in flight** (the bird, "Kranich", the works'
pet name for the big plane) as a black silhouette: long neck forward, the beak past the cog's rim, two wings in a
shallow V, the legs trailing behind; under it the words **WERK THALBACH** and, on the propaganda posters, **WIR BAUEN
DEN KRANICH** ("we build the crane") in plain block capitals. Black on old paper; never red, never violet.

**Usage rules:** the works' own posters, signs and paperwork in Act I only; flapping posters (map04a_ambience.json
`act1.posters`) carry either this mark or the P·W·K Sunburst-and-Split-Bell (§1) and nothing else.

## 2. The Kriegsmarine at Totenhafen

No naval ensigns, no eagle, no fouled-anchor-with-eagle. The pen uses **plain stencilled text** (KRIEGSMARINE · U-BUNKER TOTENHAFEN) and invented boat and unit numbers (U-1047, "TOT·HAF·7", unit stencils BLST-nn). Coffins carry the Helvetia Automaten AG plate (a civilian mark) and a Wiederkehr P·W·K stamp on the manifest only.

## 3. Mountain troops and launch crews at Morgenrot

- **Launch crew / technicians:** white coats and rubberized fuel suits with a P·W·K armband and a red-ringed sunburst on the helmet front.
- **Mountain troops (the Bergwacht Gängers):** grey-white anoraks, crampons, ice axes; the only mark is a **stylized snowflake-over-peak** patch (fictional) on the sleeve.
- **Rocket bodies:** the black-and-white roll-pattern (period-accurate in spirit) with the P·W·K sunburst on the fin and the target stencils LONDON · ANTWERPEN · PARIS. The Sonnenspeer carries the bell alone, three metres tall, the gap in it filled with Nachtglas glass.

## 4. The Allies

- **Peg's orders / SOE:** a plain typed cipher "D/LANTERN" and a diamond, no crown, no lion.
- **Gravelight One** (the C-47): a bare serial and a nose name only; no roundel art beyond a plain two-ring disc with no colours named as real.
- **Dutch's Rangers, Deacon's 761st, Wren's Home Army:** named in dialogue and dossiers (they are real units, honoured by name), but **no insignia is drawn**; patches on the character models are plain cloth with the name stitched.

## 5. Darkmatter and Helvetia (for completeness)

Darkmatter's violet mark and the Helvetia Automaten AG plate are the two corporate marks of the saga (FINEPRINT_LORE.md); neither is ever combined with the Wiederkehr emblem on one object except the Totenhafen manifest and the Sonnenspeer's fuel-valve plates ("a Darkmatter part in a Reich rocket": Vendelin's line).
