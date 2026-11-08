# Morning report: UPDATE 11 "LAZARUS" + UPDATE 12 "THE LOOK", 2026-11-08

**The game opens straight to the menu. Every map has one shared film look (graded colour, grain, darker nights).
The history cutscenes play as archive film. GRAVELIGHT ONE is now a real crashed C-47, and the Russian characters
speak English with a Russian accent.** Everything is merged on `master` and pushed.

## Start here
- **Play:** double-click `Play.bat` or `build\windows\ClaudeZombies_0.0.1-m0\ClaudeZombies.exe` (rebuilt with
  everything below; also zipped as `build\ClaudeZombies_0.0.1-m0.zip`). Both open the CLAUDE ZOMBIES menu, with no
  cutscene first. The exe reached the menu in 5.4 s on your GPU.
- **Cutscenes:** they play only in Campaign. Solo and online go straight into the match. Rewatch any of them from
  Extras > Cutscenes.
- **Dev buttons:** `DevLauncher.bat` has the Update 12 buttons:
  - Look test: every map's style frame
  - the three archive reels (Lazarus Saturday, Fourth Day, Staub)
  - Map 0: GRAVELIGHT ONE crash intro
  - Map 0: walk the wreck (no zombies, god mode)

## What to watch first
1. **Campaign > new game.** You get LAZARUS SATURDAY (1930, sepia archive film), then FOURTH DAY (1944,
   black-and-white), then the GRAVELIGHT ONE crash. The animation was cleaned up shot by shot:
   - feet no longer slide;
   - poses blend instead of snapping;
   - people look at whoever is talking;
   - hands actually reach the props.
2. **Map 0 at night.** It's colder and darker, with warm windows and the new C-47 burning in the field. Walk into
   its cabin and up to Selwyn in the cockpit.
3. **Voices.** The Russian speakers (Serafim, Volkov and the others) now speak English in their own Russian voices;
   the Russian takes are kept for a future language option. Every voice picks up the room it's in: the inn, the
   cellar, the mine, the plane cabin. Settings > Audio > Room acoustics turns that off.

## The look, map by map (before/after in `docs/look/post/sheet.jpg`)
One post pass on every map: film grain, vignette, soft edges, a little colour fringing at the edges, filmic tone,
and a colour grade per map from `data/look/`. Settings > Video turns each piece on or off. The rules are in
`docs/ART_BIBLE.md`: greys, browns, cold blues and heavy fog, with Nachtglas violet the only bright colour and blood
red the second.
- **Crossroads Inn:** a frozen blue-grey night; the windows and the wreck fire are the only warm things.
- **Kaltenbrunn:** cold steel on the surface; salt white and sodium amber below.
- **Totenhafen:** storm green-grey and wet black concrete, with red battle lanterns.
- **Thalbach:** ochre and soot.
- **der Kranich:** dawn blue, with cold aluminium inside.
- **Groom Lake:** bleached dust-brown desert (it was lavender).
- **Mondlicht:** hard black and white, with violet the only colour.
- **Menu:** archive black-and-white.
- **Materials:** a material check found 2,370 materials off the bible (plastic-shiny, over-saturated, too clean).
  2 are left, both explained in `docs/look/material_audit.md`. The rest got rougher surfaces, muted colour and a
  shared layer of grime, so assets from different artists sit together.
- **Blind review:** a reviewer who saw none of the work rated the maps as one game 5/10 before, 7/10 after. A fix
  pass then dealt with its findings:
  - Mondlicht's violet flood is gone (69% of the frame down to 1%; violet only on the tubes and signs).
  - The Kaltenbrunn barracks and the inn's taproom read again (a pink cast and heavy indoor haze removed).
  - Thalbach is finally ochre and soot, and Groom Lake no longer looks like a sepia filter.
  - Kranich's violet spill is halved, the snow is cold grey instead of lavender, and a glowing smoke "ghost" in
    Totenhafen's cannery is fixed.
- **Not fixed:** a blown-out white streak in the sky in one Thalbach view, and a few white slivers seen through the
  torn skin inside the C-47 cabin.

## Still waiting on you (`morning/NEEDS_DEVIN.md` has the exact steps)
- **49 archive-reel shots to generate** with Higgsfield: the prompts are in `docs/cutscenes/SHOT_PROMPTS.md`
  (Lazarus Saturday 21, Fourth Day 15, Staub 13; priority 1 first). Drop each in as
  `assets/user_supplied/cutscenes/<scene>/shot_NN.mp4` and run `python -I tools/cinema/archive_reel.py build`.
  Until then, every shot plays the in-engine scene through the same film look. Please check Higgsfield's
  commercial-use terms first.
- **Motion capture with friends:** 27 shots, about 100 takes, around 4 to 5 hours of filming with one phone (about
  half that with two). Each person acts their character on tape marks while the phone films the whole body. The
  guide, `docs/MOCAP_GUIDE.md`, lists each shot's marks, moves and line, with its length. The free tiers of the
  phone-mocap apps are too small (30 to 60 s a month), so pay for one month of one app (Rokoko allows commercial
  use). The pipeline then retargets the takes, fixes foot sliding and drops them into the cutscenes. Lip sync from
  the voice takes already works.
- **The real C-47:** download it from Sketchfab (your login). Until then the game uses our own C-47, built from the
  real dimensions.
- **ElevenLabs:** about 1,400 characters left until 7 December. After the reset, the bake picks up The Fine Print
  and then Bolt & Sprocket.

## Tests
- **Unit tests:** 2,074 of 2,075 pass; the other one is a placeholder that makes no checks. 853 scripts check
  clean.
- **Smokes:** 95 of 97 pass. Three more failed once under load and passed when rerun alone (bot_loco, lf_start,
  milestone_r5). The two still failing did so before this update: smoke_letzte_fahrt hits the runner's 20-minute
  cap, and smoke_marks has a pause-map check.
- **Egg guard:** green (the quest files are unchanged).

## What's not working / not checked
- **FPS targets not confirmed.** Every frame-rate run was made with other jobs loading the CPU. The post pass
  itself costs about 0.13 ms on your GPU. Please run `--frame-log` on Low with nothing else open.
- **Rare crashes in capture runs.** Three of the post-processing worker's off-screen capture runs died with a heap
  error (one after errors on a Map 0 to Kaltenbrunn switch). Reruns were clean, and the cause is not found yet.
- **A rare hang.** One test run froze inside Godot on exit (every test had passed); it didn't happen again in 3
  reruns.
- **Staub drops a few subtitles.** Overlapping lines queue up and 2 or 3 of its 12 subtitles get dropped.
- **No ElevenLabs narration in the reels yet:** each reel has an empty narration slot for the December bake.

---

# Morning report — UPDATE 10 "BEYOND THE INN", 2026-11-02

**Totenhafen now has its own Easter egg (LETZTE FAHRT), its own boss (DER KIELHOLER), its own wonder weapon (THE
UNDERTOW), a tide that floods the aprons on spring rounds, a sailing finale where U-1047 leaves the pen, and a living
harbour. All four Fernflug acts have a set-piece each (the air raid, the wing walk, the dust storm, the terminator)
and a living world. PAUL guards Kaltenbrunn's round 15 and THE SLENDER walks Totenhafen's round 25. Kaltenbrunn got
a living world too.** Everything is merged on `master` and pushed. The scorecard target was **not** met (below) and
the two bot targets were **not** met; both are reported straight.

## 2026-11-07 (merged, pushed)
- **Cellar (Map 0):** a new vault off the cellar with Skyhook Sekt and Magpie Mead, the two tonics no early map sold.
- **Totenhafen:** 41 invisible walls gone, the sub's bulkheads, hull and deck finished, black slabs removed (shots: morning/screenshots/t180_map02).
- **Bells / Easter egg:** the Requiem is easier (bigger bells, a rung bell stays rung, longer Chapel light, radios heard further); bots alone finish it 3 of 5. **Easter Egg Mode** (Settings > Gameplay, or map select): Few Crawlers / No Zombies, practice only.
- **Iron sights:** 11 guns' sights lined up at ADS; a test keeps every gun within 2 px.
- **HUD:** the squad list shows names, down state and tiny tonic caps; your caps are 40 px (were 54); every tonic icon redrawn; hold Ctrl for the scoreboard.
- **Cutscenes:** all 12 rebuilt as camera shots with letterbox, grades, title cards, the squad acting, hold to skip (clips: morning/clips/t184_after). Please watch one on your GPU: depth of field and brightness were only checked in software rendering.
- **The airplane launch:** pushes added up every frame (the Kranich's lash threw you 56 m up); fixed on every map, plus a net that puts anyone far out of bounds back on safe ground.
- **Bots from round 30:** every tonic and a Crucible-taught gun (companions not included; one flag to turn on).

## 2026-11-06 follow-up (merged)
- **Review fixes (T-176):** all 10 bugs from the review of the bot-egg merge fixed (holds, the hunt, egg doors, scouting, shop cost).
- **Bots and companions shop (T-177):** squad bots and Jakub / Trudi / Gustl / Hinnerk / Jette use the bank (their own savings for the match, never yours), the Armorer's Bench, tonics and the Crucible with their own Scrip. Companions shop between rounds only. Relief soldiers don't (no Scrip; they pass through).
- **Map 1 performance:** no script slowdown since UPDATE 10. Two per-tick log floods fixed (a bot retrying the power switch, a relief-squad error); frame time 4.65 to 4.2 ms in a bot soak. The GPU side (new landscape, Crucible room light) needs your `--frame-log` run.

## Follow-up, 2026-11-03 (after your play-test)
- **Totenhafen graphics:** the glowing green edge lines, the black flood water, the floating white "discs" (snow domes),
  the backwards searchlight cone, U-1047's red wash and the harsh cannery checker are fixed (T-173).
- **LETZTE FAHRT is easy to find now:** the Operator points at the crane hook and coffins in rounds 2 and 4, an amber
  lamp pulses on the empty hook, the egg's objects go on the minimap, and a banner names each next step.
- **Better egg rewards (T-174):** Kaltenbrunn's egg gives every perk and pours each to its top tier (tier IV,
  permanent). Totenhafen's pays 7,500 Scrip and raises every perk you hold one tier.
- **Pack-a-Punch rooms (T-175):** the Crucible's room on all seven maps is dressed as a shrine to the machine
  (pipes, tanks, a bench, notices, a key light, the violet glow, a hum, steam and sparks on use); the act Crucibles
  now face their rooms.
- **Bots on the eggs (T-172):** bots now spend their Scrip in shopping breaks before the fights and hold together.
  Totenhafen: 2 of 7 bot runs finished LETZTE FAHRT (the latest in 28 game minutes); Kaltenbrunn: 0 of 5, the best
  reached step 7 of 10 (before: step 5). Neither reached the 3-of-5 target. What still stops Kaltenbrunn: a radio the
  bots never hear, the shard placement at the Crucible, a stuck Foreman (docs/QA_REPORT_U10.md section 5).

## The scorecard (docs/THE_BAR.md)
The bar moved: Kaltenbrunn's new living world lifted it from 68 to 77 (of 84), so the target became 77, not the 71
the sections were planned to. Re-scored at FINISH by a separate scorer from the data, tests, smokes and captures:

| Column | Before | After | Target | Verdict |
|---|---|---|---|---|
| Crossroads Inn (the bar) | 71 | 71 | — | — |
| Kaltenbrunn (the bar) | 68 | 77 | — | — |
| Totenhafen | 45 | 69 | 77 | not met (8 short) |
| Fernflug I | 43 | 59 | 77 | not met |
| Fernflug II | 37 | 59 | 77 | not met |
| Fernflug III | 43 | 60 | 77 | not met |
| Fernflug IV | 39 | 61 | 77 | not met |

Every new column passes the other two tests (three "only here" features a player can act on: 7–10 each; no seed row
at 0). Against the owner's 18 seed rows alone Totenhafen (48) beats both references' baseline (44). The acts gain
16–22 points each but stay 10–12 under the old target and 16–18 under the new one: a greybox act does not become
a Map 1 in one night. The scores above are from before the last fixes, which were not re-scored: Totenhafen got two
people with favours, the teller's reactions, Hinnerk's stair scene, Jakub's lines and an arrival beat; Groom Lake got
four story props; every act boss now has a smoke. The rows sent back are in THE_BAR.md §3.3.

**Blind review: not done.** The reviewer ran out of credits mid-scoring and was not restarted, to save usage. The clips and capture sets it needs are ready on this PC (morning/clips/u10_blind/, morning/screenshots/u10_before and u10_after).

## 5 things to try first on Totenhafen (Play.bat → the "Update 10" buttons)
1. **Spring Tide (round 9):** the aprons go under, the piers stay dry, the drowned climb out at the pier edges, a
   cable sparks in the water. Find the Pumpenschalter crank at the head of the pump stair and hold it 30 s under
   double spawns to shorten the flood.
2. **Letzte Fahrt (watch bots):** three Full Partner bots run the whole egg: the coffin on the hook, the power, the
   three radios and the rotor cipher, the four log pages, the three diesel holds, the ignition key, the curtain, the
   sail. Press F6 to take over.
3. **The sailing finale:** pull the curtain lever in the pen hall, take U-1047's helm, and she leaves the pen: the
   searchlight tracks her, boarders climb the saddle tanks, the dive at the depth mark and the Hale telegram card.
4. **THE UNDERTOW:** three ballast dumps at the sea stairs leave the shard; the bench builds it. Harpoon pierce and
   reel, a whirlpool in water, MAELSTROM on land.
5. **The Slender:** round 25 with the power on. Keys from everywhere, "Evening.", the lantern at the end of the west
   catwalk. Stay in the lamp pools; he locks doors as he passes.

## 5 things to try first on Fernflug
1. **Act I air raid** (button): sirens, flak, the bomb walk, the roof bay comes down, the breach into the test stands
   opens; then the rivet line and the wind tunnel.
2. **Act II wing walk** (button): the breach panel tears off; climb out of the hatch UNCLIPPED, clip to a tether post
   before the next tilt; the wingtip locker pays a discount token.
3. **Act III dust storm** (button): the fog closes to 15 m; the stalkers hunt by sound: walk, don't sprint; a shot is
   heard three times as far.
4. **Act IV terminator** (button): the line crosses the yard; the night side drains the suit heater faster; the
   heater switch wakes the domes one by one. Watch the earthrise and the meteor warning.
5. **PAUL** (button, Kaltenbrunn round 15): the headframe shakes, he arrives; bottles cool him; past 6:00 on the
   clock he leaves and comes back later, bigger.

## What's new per map (short)
- **Totenhafen:** Tide v2 (stages, spring tide every 9th round, the crank holdout, floating power-ups, sparking
  cables), Ballast v2 (hook or sea stairs; +1 Glasshide after a dump; the shard on the third), the Kielholer (drowned
  that surface only while flooded and drag you to the water), the searchlight station, the Crane Drop trap, THE
  UNDERTOW, LETZTE FAHRT (16 steps, every one with a bot task), DER KIELHOLER, the living harbour (T-154), the
  Hafenwächter THE SLENDER, the bank in the crane office. Pays about 1,200 Scrip a round by round 8 against
  Kaltenbrunn's 1,000.
- **Fernflug I:** the air raid, the rivet line, the wind tunnel, the living Werk (searchlights, the train, the
  lookout to the Kranich, the cellar family).
- **Fernflug II:** turbulence and the tilt, the decompression breach, the wing walk, the aux bus, the galley photo,
  Ruhland the teller with a favour.
- **Fernflug III:** the dust storm, the wreck collapse, the radar perch, the jukebox, the burning hull.
- **Fernflug IV:** the terminator, the earthrise, low-g jump pads, the meteor warning, the heaters and the visor, Pohl
  (his own body now), the field units.
- **Kaltenbrunn:** a living world (the yard ridges, the rail yard, the cable car, the chapel, the generator, the
  vault), PAUL at round 15.
- **Everywhere:** first-time hints (once per profile, filed to the Archive), 18 Citations (achievements) with a HUD
  toast and a Service Record section, smooth zombies above 60 Hz (Settings > Video), the loading card for online
  travel and match start, every minimap re-baked, the audio mix levelled (the old maps' beds were louder than your
  own footsteps; they are now 8 dB under them, so the Inn and Kaltenbrunn sound quieter than before).

## Bots
- **Kaltenbrunn egg, honest (no god mode), 3 Full Partner bots:** 0 of 5 in each of three batches (target 3 of 5).
  Progress: squads now live to rounds 21–32 and survive PAUL; steps s0–s3 done in most runs, s4–s5 in 4 of 15; the
  stopper is s6 (all four bells must be seen) and s4 (a Crucible gun first). Each step alone, god mode, completes
  (s7 5 min, s8b 8.5 min, s9 the egg). Tables: docs/QA_REPORT_U10.md §1.
- **Q-19 (bots alone through Act II into Act III):** 0 of 3 on the final code (1 of 3 on a mid-tuning build). Every
  run now survives act round 1 (at baseline none did); they die in act rounds 3–5 against sprinters, 17–35 m apart.
- **Letzte Fahrt, bots alone:** 3 of 15 runs completed since the reach fixes (0, 1, 1, 1, 0 per batch); the
  failures are squad wipes in the diesel holds with 7,000–21,000 Scrip unspent (the bots' economy buys nothing during
  the egg's shopping breaks). One run on final master reached 8 of 16 steps in the runner's 20-minute cap.
- The searchlight mark order ("man" on the light) works: a bot mans it (smoke_bots_u10).

## Performance (no GPU here: draw calls and triangles only, software renders)
Browser profile, widest views: Kaltenbrunn 1,567 draw calls / 400k, Crossroads Inn 6,002 / 1.87M (still over the
2,500 budget, as in UPDATE 09; the Inn's forest and village visibility is the lever). Zombie smoothing costs
0.6 µs a zombie a frame; the faces now run at the zombies' animation LOD. Real FPS still needs your `--frame-log`
run (NEEDS_DEVIN). Loading: the card is on screen within 75 ms on every hop; the Inn's cold start holds a 3.5 s frozen
frame under the card (MapRoot's own `_ready`; the fix is to split it across frames, not done).

## Tests
Unit suite 1831/1831 after the Totenhafen fixes; scripts 747, 0 failed on the final master. The full smoke run was
stopped at 28 of 84 to save usage, with 28 passing and none failing; every merge before it ran its own smokes green.
Nothing was checked in a rendered window on this PC; every capture and clip came from an invisible software renderer
(WSL + Xvfb). The seven 2-minute tour clips with sound are in morning/clips/u10_blind/ (local only, not in git).

## Placeholders (docs/PLACEHOLDERS_U10.md)
5 replaced, 16 open. All VO on the new content is placeholder TTS (OneCore/Kokoro); the Operator, PA,
Wittkamp, Dee, Hale and the Woman in Violet want cast voices. DER KIELHOLER has no bespoke animation clips (the generic
puppet; online clients see the generic puppet too), and the Undertow's first-person model is primitives.

## Still not working or not done
- The scorecard target (77) on Totenhafen and the acts; the two bot targets (above); the blind review.
- Four Fernflug fixes are unfinished in a worker's folder, not on master: the tellers' reactions on Acts I, III and
  IV, the Moon's field units fighting, Jakub's act lines, Act II's crates.
- The web and Windows builds were not rebuilt from this master (`sh tools/build_web.sh`, `sh tools/build_windows.sh`).
- The browser link is not deployed (your Vercel login; NEEDS_DEVIN).
- Real FPS unmeasured; Crossroads Inn over the browser draw-call budget.
- The Inn's 3.5 s cold-start freeze under the loading card.
- Act II's five wall-buys still face the wall.
- smoke_npc_walls and a few timing smokes are unreliable on a loaded machine (they pass on a quiet one).
- A browser peer against a desktop host and a real NAT pair were not tried.

## Pull it on the PC
```
cd C:\Users\Devin\PROJECTS\bolt-and-sprocket-ultimate && git pull origin master && git lfs checkout
```
