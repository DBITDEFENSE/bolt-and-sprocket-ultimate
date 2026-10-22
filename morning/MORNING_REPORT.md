# Morning report — overnight run, 2026-10-21 → 22

Tonight added The Cousins round on Map 0, bots with a Thompson + Ironhide + Second Wind, one bot that runs on your
local Gemma model and does the easter egg itself, the committed zombie animation upgrade, and a dev launcher.

## Play it
Double-click **`Play.bat`** → the dev launcher opens.
1. **"Boss test — The Cousins (Crossroads Inn, round 10)"**: tick God mode if you just want to watch. The lamps go
   out, the Hammer comes down the stairs, the Reach 30 s later, Alix climbs out of a trapdoor behind the bar.
2. **"GRAVELIGHT — Crossroads Inn"** with Bots = 2 and "One bot on local AI" ticked: Peg (the first bot) goes and does
   the radio easter egg on her own, opening doors with her own Scrip, and talks in subtitles. Every bot spawns with a
   Tommy gun, Ironhide Stout and Second Wind. (Needs Ollama, already installed; the game starts it. First decision
   takes ~20–50 s while the model loads; until then she uses her built-in plan.)
3. "Start at round" + God mode for late-round stuff; `Play.bat --menu` opens the normal hub.

## What's done
| Item | Status |
|---|---|
| Bots spawn with Thompson + Ironhide Stout (Juggernog) + Second Wind (Quick Revive); perks return after a revive | **works** |
| Local-AI bot (Ollama gemma3:27b) doing tasks + easter egg | **works** on Map 0 (egg done alone in ~84 s); **partly** on Map 1 (power, 6 doors, Totenglocke built; the rest of the Requiem needs you) |
| MZ zombie animation upgrade + 8 review fixes | **works** (committed, tag `mz`) |
| v3 Homage Bosses design docs | **done** (`docs/HOMAGE_BOSSES.md`) |
| HB1 The Cousins (Map 0 round 10) | **partly works**: full round, all 3 cousins with core moves, rewards, toggles; missing extras below |
| HB2 PAUL, HB3 THE SLENDER | **not started** (designed) |
| Dev launcher, screenshot tool, smoke runner | **works** |
| M0 / M1 / M2 from the brief | already done before tonight (tags m0–m2) |

Tests at the end: 546/546 unit tests, all 21 smoke tests pass, 0 script errors. Everything is merged into `master`.

## Screenshots (local, not in git)
- `morning/screenshots/hb1_cousins/` — cousins_1_trio, cousins_2_third_hand, cousins_3_title_card, cousins_4_hammer_and_bars
- `morning/screenshots/overnight/` — map00/map01/map02 spawn + combat, the Screamer and the Foreman, Scrapheap, Verdant

## Decisions I made for you
1. The local AI only picks the bot's *objective* every 4 s; aiming, moving and fighting stay in the normal bot code (a 1 s model can't aim, and a bad answer must never get the bot killed). If Ollama is off, it falls back to its own plan.
2. Model order: gemma3:27b → gemma3:4b → gemma4:31b (27b ≈ 1.2 s a decision on your 5090).
3. The AI bot won't start a Resonance Pylon unless you're near it (alone it died there and the pylon held the round open forever).
4. Bots can still buy 2 more perks on top of the kit (perk limit raised 2 → 4).
5. Cousins: the trapdoor is behind the bar (the canon ice cellar); bots count as "watching" Alix; Blackout/kill-all only take 25 % of a cousin's HP.
6. Homage boss tuning is JSON (`data/gravelight/bosses/`), not `.tres`, like every other GRAVELIGHT table.
7. `Play.bat` now opens the dev launcher (the old hub is one button away, or `Play.bat --menu`).
8. Skipping to a later round also gives late-round Scrip, so round 10+ is playable from a skip.
9. `master` is the main branch here (there is no `main`).

## Needs you
- **Paul's unit (D4):** the 82nd Airborne only reached the Ardennes on 18–19 Dec 1944, but Kaltenbrunn falls on 20 Dec. Pick: keep the 82nd and move his capture to Holland (Sept 1944), keep the Ardennes with a generic engineer unit, or tell me his unit.
- **Likeness placeholders (8):** COUSIN_1_NAME (using "Mara"), COUSIN_2_NAME (using "Jo"), PAUL_SIGNATURE, PAUL_LASTNAME, PAUL_UNIT, PAUL_LETTER_DETAILS, DEVIN_SIGNATURE, DEVIN_LASTNAME. Edit `data/gravelight/bosses/likeness.json` or just tell me.
- **HUMOR-REVIEW yes/no list:** `docs/M0_REVIEW.md` §A (6 items), if you haven't answered it yet.
- Nothing is blocked.

## Known bugs
- Cousins in online co-op: clients see a plain zombie body, no title card; remote players are held but not dragged.
- During the Cousins round the lamp meshes keep glowing while their lights are off; the taproom is very dark.
- On Map 0, Peg says a "Kaltenbrunn" line (squad dialogue picks a Map 1 line).
- The local-AI bot roams alone and can go down far from help on later rounds; Map 1's Requiem isn't finished without you.
- Older: the Map 0 stair-head idle zombie; the Screamer has no head look-at / foot IK on the host.

## Next up
HB1 extras (the Kinderhammer drop, the chalk room + free crate pull, the Reach's ceiling crawl / Window Spider / arm
regrowth, the rhyme stems, co-op client visuals), then **HB2 PAUL** on Kaltenbrunn.
