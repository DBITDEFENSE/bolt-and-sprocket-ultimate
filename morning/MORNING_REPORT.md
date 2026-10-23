# Morning report — Update 02 + Update 03, 2026-10-22

Every Update 02 section and the Update 03 bot rewrite are merged into `master` and launch. Bots now train, revive and
stay out of your way, and Jakub breaks out at round 5. The Totenglocke is the strongest thing on Kaltenbrunn, ammo
boxes are on every map, the Thompson's sights line up, and Map 0 has the Old Cellar, a war on the horizon and a
room-by-room detail pass. Since then the Cousins scale for bot-only squads (your call), and bots alone now reach
round 14.7 on average (best 20; the target is 20–25). Revives with the do-nothing test player are at 78%, not above 85%.

## Play it
Double-click **`Play.bat`**. The dev launcher opens; Esc in a match opens the pause menu, ` opens the dev console.

**Try this first**
1. **"Map 0 — round 5 (Jakub)"**. The Old Cellar is open; round 5 is next. Go down when you hear him shouting, kill
   the zombie at the cage, hold [F] on him, and pick *Give him a gun* or *Not yet*. Pick **Wren** in the Survivor box
   for the quiet scene about her brother.
2. **"Bot test — Map 0 round 15 (3 bots, you play)"**. Run the taproom loop and watch them train with you, revive,
   call things out (with a ping on the spot), and step aside in doorways. Hold **T** for the command wheel. The
   dev console command `ai_debug 1` shows what each bot is thinking.
3. **"Kaltenbrunn — Totenglocke test"**. Tap fire for a quick toll, hold 1.5 s for the Great Toll, right-click for
   the Bell Dome.
4. **"Weapon range — ADS check"**. Aim the Thompson. `[` and `]` cycle every gun; a dot shows when you're fully
   aimed.
5. Any Map 0 match: sprint and press fire (it fires now), slide, vault the bar counter, shoot the bottles behind the
   bar, and look out of the east window around round 6.

## What's done
| Section | Status |
|---|---|
| **U02 §1** Movement & gunplay feel (accel/decel, sprint hold/toggle, sprint-out per class, no eaten inputs, vault, slide-fire, recoil patterns, bloom crosshair, hay footsteps, impacts) | **works** |
| **U02 §2** Thompson ADS + SightPoint on every gun + `tools/ads_check.sh` (44/44 aligned) | **works** |
| **U02 §3** Totenglocke "wind and toll" (tap / Great Toll / tolled marks / Bell Dome / shards / Mitternacht) | **works** |
| **U02 §4** Ammo boxes (Map 0 ×3, Kaltenbrunn ×4, Totenhafen ×4; 250 / 2,500 / 1,000 / 4,000) | **works** |
| **U02 §5** Bots: bonus perk, character looks and poses, nameplates, barks, command wheel | **works**; their behaviour moved to U03 |
| **U02 §6.1** The Old Cellar (Door 5, 1250): wine cellar, coal cage, root cellar, ice cellar, barrel loop | **works** |
| **U02 §6.2** Jakub (round-5 breakout, both choices, fights on the bot brain, downs, campaign carry, dossier, 106 lines) | **works**; not in online co-op yet (he stays caged) |
| **U02 §7** Living world (terrain to the mountains, bombers, plane down, artillery, flares, crows, dog, frost, chimney) | **works** |
| **U02 §8** Room-by-room polish (story props, wear, breakable bottles, swinging lamps, curtains, footprints, sound zones) | **works**; grime on window glass not done |
| **U03 §0/§9** Bot metrics logger, scripted soak player, `tools/ai_soak.sh`, baseline | **works** |
| **U03 §1–§8** Utility-AI brain, perception without wallhacks, aim layer, revive claims, economy, personalities, Recruit/Veteran/Elite, `ai_debug` overlay | **works** |
| **U03 §3** Locomotion layer (bots use your movement code), training routes, personal space, stuck ladder | **works**; bots don't ride the Kaltenbrunn lift |
| **U03 §10** Acceptance targets | **partly**: see the table below |
| Bug fixes found along the way | **works**: zombies couldn't climb the Map 0 stairs from below (0/12 → 40/40); special-round zombies spawning on roofs; Peg's "Kaltenbrunn" line at the inn; lamp glass glowing in the Cousins blackout; bots getting a second bonus perk and an extra Thompson on a campaign arrival; a stuck bot that could never recover; two flaky tests |

Tests at the end: 733/733 unit tests (after T-060), all 27 smoke tests pass (the Jakub smoke needed one last fix: his Cousins line was lost if he was down when they arrived), 0 script errors, all 44 guns pass the ADS check. Everything is merged into `master` (tags `u02-sections`, `u02-u03`).

## Bots: before and after (Update 03)
Soak = 3 bots on Map 0, headless, Veteran, local AI off (`tools/ai_soak.sh`; full table in `docs/BOT_AI.md` §7).

| Metric | Before | After |
|---|---|---|
| Highest round, bots alone (mean / best) | 5.7 / 6 | 10.0 / 16; **14.7 / 20** with the Cousins scaling (T-060) |
| Highest round, with a scripted player who throws the power and buys perks | — | **12.7 / 18** |
| Highest round, with the original do-nothing scripted player | 8.0 / 9 | 9.3 / 10 |
| Revive success (realistic player / do-nothing player) | 83% | **96%** / 78% |
| Revive success, bots alone | 0% | 71–91% |
| Time stuck per run | 124 s | **2.4 s** |
| Teleports | 0 | 0 |
| Getting in your way (sustained) | 0 (25.7 short events/run) | **0** (0.5 short events/run) |
| Kar98k bought after round 10 | 0 | 0 |
| Empty-mag moments per minute | 9.5 | **2.9** |
| Time on the pistol with a loaded gun | 683 s/run | **~0** |
| Kills per minute | 14.7 | **26.0** |
| Shots that hit | ~30% | **56%** |
| Brain cost per bot | — | **0.22 ms** (budget 0.5) |

## Clips and screenshots (local, not in git)
- `morning/clips/u02/`: `s1_feel_before_after.mp4`, `s2_thompson_ads.mp4`, `s3_great.mp4` (12-zombie Great Toll,
  round 16), `s3_dome.mp4` (revive under the dome), `s3_chain.mp4` (Mitternacht), `s3_r25.mp4`, `s6_jakub.mp4`,
  `s7_sky.mp4` (bombers, plane down, barrage), `s8_polish.mp4`
- `morning/clips/u03/`: `bots_train_r15.mp4` (training with the player, revive under pressure, ping),
  `bots_cousins.mp4`, `s3_loco_train.mp4`
- `morning/screenshots/ads/` (all 44 guns aimed, with the center dot) · `u02/<section>/` (before/after for §2, §6,
  §8, every ammo box, the landscape from the spawn, the upstairs window, the stable and the field edge, bot bodies and
  nameplates, Jakub) · `u03/` (AI debug overlay) · `u02_u03/` (fresh map shots)

## Decisions I made for you
1. Tuning stays in JSON (`data/gravelight/movement.json`, `data/gravelight/ai/*.json`), not `.tres`, like every other
   GRAVELIGHT table.
2. Godot tools live in `tools_src/`; `tools/ads_check.sh` and `tools/ai_soak.sh` are the wrappers.
3. The Old Cellar has no new perk machines (all 9 are already in the Helvetia cellar); its wall gun is the Gewehr 43
   (the Garand and Thompson are already on Map 0). It connects to the perk cellar through a breach that falls in once
   both cellar doors are bought.
4. Jakub breaks out at round 5 even if nobody opened the Old Cellar, and calls out until someone comes down. In pure
   solo he can't revive you (solo rules stay); with bots or in co-op he can. A bled-out Jakub is out cold, never dead,
   and comes back wounded on the next map.
5. Bots never throw the power while a human is in the match. When bots play alone they lead themselves: they open
   the path, throw the power and buy perks.
6. The bot bonus perk is a trait for the whole campaign: it carries over, and isn't drawn again on the next map.
7. The Totenglocke: the Bell Dome costs 2 charges and staggers each zombie once as it enters, so it visibly holds;
   bosses take 3% / 10% of their health and are never shattered.
8. Command wheel key is **T** (B is alt-fire).
9. The war on the horizon sits to the east (the lore's front), and the midnight bell rings at round 9.
10. Three of Jakub's lines name Kaltenbrunn as the place he escaped from, so they may play on any map.

## Lighting pass (all three maps, T-061..T-063)
Every map got bounce lighting (SDFGI and SSIL on High, SSIL on Medium, the old flat fill on Low) and new light
sources you can see: lanterns, candles, fire barrels, stoves, moonlight through boarded windows, window glow on the
snow. Judged per view by brightness, power off, before → after; no view got darker.
- **Crossroads Inn:** a warm refuge against a cold blue night; the power lever now lights 11 bulbs in the inn; the
  perk cellar isn't pitch black any more; the windows glow from outside; the Cousins blackout still works. 12–56 → 26–71.
- **Kaltenbrunn:** moon-blue surface, salt-grey depths, a violet Core with amber cracks; barracks and mess hall
  went from pitch black to readable; sodium lamps glow in the haze. Low: the Core is a little darker than before.
- **Totenhafen:** no longer too dark (interiors ~8 → 20–50); fire barrels, stoves, dock lanterns, sea light under
  the pen doors, warm/cold floods on power.
- Before / after shots: `morning/screenshots/lighting/<map>/before|after|after_low`. Retake: `tools/light_shots.sh <tag>`.
- Frame rate on High at 1280x720: 117+ fps (Inn), ~221 (Kaltenbrunn), 154+ (Totenhafen).

## Needs you
- ~~Bots alone vs. the Cousins~~ **answered: they scale.** While no human is standing the Cousins drop to half
  health, 60% damage, slower moves and a thinner horde (T-060, `cousins.json "bots_alone"`). Bots alone now clear
  them 5 of 5 times and reach rounds 7–20 (mean 14.7, best 20).
- **Revives with the do-nothing test player** are at 78% (96% with a player who plays normally). Fine to judge it by
  the realistic player?
- Still open from last night: **Paul's unit** (D4), the **8 likeness placeholders**, and the **HUMOR-REVIEW** list
  (`docs/M0_REVIEW.md` §A).
- Jakub's canon (CANON §6.4): born 1901 in Wilcza Góra, tag KB-2210, he led Tomasz Nowak's gang in Gallery Nine, and
  his chalk marks are Morgenrot's Witnesses' Marks. Change anything you don't like.

## Known bugs
- Jakub stays caged in online co-op (companions aren't replicated yet).
- The Bell Dome's +25% damage and pull only apply on the host in co-op.
- Bots don't ride the Kaltenbrunn lift; with the realistic player they sometimes bump each other in the Crucible
  alcove (51 s stuck per run there).
- Bots on Kaltenbrunn still fire on the run at long range sometimes.
- Grime on window glass not done; footprints don't sink into drifts; the falling plane's smoke reads light grey.
- Older: Cousins visuals for online co-op clients; the Screamer has no head look-at.

## Next up
HB1 extras (the Kinderhammer, the chalk room and its free crate pull, the Reach's ceiling crawl), then **HB2 PAUL**
on Kaltenbrunn (needs Paul's unit), then companion replication for online co-op.
