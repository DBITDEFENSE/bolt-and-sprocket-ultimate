# M0 review list

Answer yes or no (or "edit: …") for each item. Nothing in section A is wired until you approve it.

## A. HUMOR-REVIEW.md (the unwired joke pack): yes/no

| # | Item | My recommendation |
|---|---|---|
| A1 | **Commander Rex Tremendous**: the cameo NPC (meet dialogue, "The Highlight Reel" side quest, 6 barks, 2 Grand Prix lobby lines) | **Yes, with one change.** The file calls him "an archetype homage." The writing and name are original, but a vain, merch-hawking washed-up galactic hero is closely tied to one specific commercial franchise. To stay well clear of hard rule 5, keep him and make him less of a copy: give him one trait that's his alone, e.g. he's a retired *game-show host* hero from GLAMBOT's old network, so his jokes run through the broadcast satire the game already has. |
| A2 | **6 escalating Blartz ad pitches** ("The Mk. III holds a GRUDGE"…) → `blartz.pitches` | Yes |
| A3 | **10 travel-screen "tips"** under SPACE TO SKIP | Yes |
| A4 | **12 trophy names that undercut the achievement** ("Participation Foreseen", "Adequate.", "Read The Fine Print"…) | Yes, and the remake has a trophy panel planned for M6. "Read The Fine Print" must change from "all 35 memos" to **all 40**. |
| A5 | **8 deadpan Sprocket "plan" reactions** → new `BARKS.plan` bucket | Yes |
| A6 | **6 hoverboard warranty disclaimers** for the Grand Prix lobby and countdown | Yes |

## B. Story changes I'm proposing (old → new, already applied in data; revert any)
1. **`cs.galleriaLedger.02`**, Galleria continuity: "tries that clause **again**" → "**on you**." (STORY_CHANGES §1)
2. **Duplicate quest IDs** get unique IDs: `q9a`/`q9b`, `q7a`/`q7b`, `q3c`. This is an ID change only; the text is unchanged.
3. *(Proposed, not applied)* **Banner "The Sentinel sheds its armor!" → "The Content Creator sheds its armor!"**. The source's one Rustvane mini-boss is labelled THE CONTENT CREATOR but its banner says Sentinel. The remake splits them into two fights, so the banner moves to the Content Creator. *(`code.updateMiniBoss.*`)*
4. *(Proposed, not applied)* **K.A.R.E.N.'s acronym.** The shop says "Kinetic Annihilation & Retribution Emitter Node," while her ad and your brief say "Kinetic Automated Retail Enforcement Nanny." Either unify on the brief's version, or keep both as a Blartz joke ("I renamed her. She didn't notice."). Your call.

5. *(Proposed, not applied)* **`st.l3_waves.02`**: "Relax. I've beaten **TWO** bosses." → "Relax. I've beaten **SIX** bosses." By that point the remake has six required bosses behind you (REPO-TRON, the Sentinel, the Content Creator, the Algorithm, the Retention Specialist, Compost King). The original count was already stale. Alternative: keep "TWO" as Bolt being bad at counting, with a Sprocket correction line.
6. **Older Gravelight LORE dates are moved to fit the locked landing date** (applied in `docs/gravelight/`): the Gallery 7 deaths go from Mar 1938 to 11 Nov 1938, and the Amt seizure from Sep 1938 to 2 Mar 1939. Helvetia's 1921 founding becomes "Imhof & Cie., 1921, re-founded by Vendelin in 1940," so every existing "since 1921" line still holds.
7. **One sensitive beat to review:** Ch. 2 marks the 9 November 1938 pogrom with a single restrained moment (a wireless bulletin, then the miners' silence; `fp.c2.shift.25–31`), with a writer's note never to expand it. Keep it, cut it, or reword it.

## C. Decisions I'd like you to confirm
1. **The Return Trip** (DECISIONS T-006). Helvetia Works happens in Basel on 17–18 March 1945, as the brief says. The squad reaches it through the collapsing heart's fold at the end of Map 1, and the fold returns them to late December 1944, so the existing Map 2 and Map 3 dates hold. The alternative is moving Helvetia Works to January 1945.
2. **Bring in the built GRAVELIGHT project rather than rebuild it** (T-007). Its Maps 0–1, Easter egg, progression and art/audio pass are already done. M2 becomes a migration plus the §11 features.
3. **Placeholder TTS** using the original voice profiles until recorded VO exists (T-009).
4. **The 5 new memo placements** (T-012).
