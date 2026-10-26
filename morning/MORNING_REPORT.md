# Morning report — UPDATE 07: Map 4 "Fernflug" + a QA pass on every map, 2026-10-26

Map 4 is in and playable from start to finish: four acts, two new perks, a gravity wonder weapon, four bosses, a four-act Easter egg and two endings. Everything is merged into `master`. Final checks: all 1,321 unit tests pass and all 45 smoke tests pass.

## How to play Map 4
Double-click **`Play.bat`**. The dev launcher has a new **Map 4 — Fernflug** block:
- **"Map 4 — Fernflug (full run)"** starts Act I at round 1.
- **"skip to Act II / III / IV"** drops you into that act at round 15 / 21 / 30 with a fair starting kit (a Crucible gun, a few perks, Scrip for the round).
- In a normal campaign the chain also goes on from Totenhafen: hold out to round 40 and take the rail siding.

**The four acts.** Each one is a full zombies map with its own wall guns, perks, ammo boxes, crate, Crucible and minimap. The HUD shows the act under the round number ("ACT II · 3").
1. **Werk Thalbach** (a factory town). Turn the power on in the assembly halls, read the three Fernflug files, open the Great Hangar. Allied air raids drop bombs on lit circles; use them on the horde. Boss: **Der Kranführer**, the crane driver riding the hangar crane. At act round 15 (or early through the egg) the bomb-bay ramp lights: board the Kranich.
2. **Der Kranich** (inside the flying wing, in flight). The floor banks in turbulence, fighters strafe the hull, panels blow out and suck things through (zombies die; seal them). At act round 3 the aft blister shows London. At act round 5 the bomb run starts: jam the racks before they drop. Chalk-marked racks are duds; rack 1 always falls. Boss: **Der Bordwart**, fused to the port engine. Rip out the autopilot and the wing crashes.
3. **Groom Lake, Nevada** (a desert test range at dawn). New dead: **Burrowers** come up through the salt (watch for the ripple), **Canaries** in hazmat hoods (shoot the body; a head shot breaks the hood and gasses you), **Jumpjockeys** leap across the range, **Backorders** walk through walls and are only solid when they strike. Find Dee on the hangar radio. Carry the engine core to the hangar and choose **Peg's choice**. Build the **Lodestone** from three parts. Boss: **The Test Pilot**. Turn the key in the silo, enter Fasbender's burn numbers, ride the rocket.
4. **Mondlicht** (a relay station on the Moon). Low gravity: jumps go much higher and you fall slowly. The yard has no air: watch the AIR gauge and refill at the posts or indoors. The Earth hangs overhead and darkens city by city. Read the terms on the three columns, open the Account, face **the Account Manager**, then turn the key: **CANCEL**. If the renewal clock runs out first, you get the bad ending, **AUTO-RENEWAL**, and the match goes on in a "Retained" state until you fall.

**New perks** (both have tiers II and III like every perk):
- **Skyhook Sekt** (2500): better air control, a mid-air hop, soft landings, faster slides, and turbulence barely moves you. Tier III stomps zombies when you land from a hop.
- **Magpie Mead** (3000): kills sometimes drop ammo, Scrip or a grenade. Tier III shares the drops with the team and turns every 25th drop into a power-up.

**The Lodestone** (Act III buildable, carries into Act IV): tap fire to **lift** a group and tap again to **slam** them; hold alt-fire to **fling**. On the Moon, a fling over the rim sends them into space. Crucible version: **Escape Velocity**.

**Things to try first:** "skip to Act II" and ride out a bomb run; "skip to Act IV" and fling a suited zombie off the yard.

## What's new on the old maps (the QA pass)
Full list with before/after numbers: `docs/QA_REPORT_U07.md`.
- **Totenhafen:** zombies no longer fall off the quay's landing stages, and the BAR and Thompson wall guns can actually be reached.
- **Crossroads Inn:** bots no longer climb onto the taproom tables and get stuck there (42 stuck moments → 3).
- **Kaltenbrunn:** bots playing without you now open the doors and head for the power (they used to buy nothing and die in the yard at round 9; now round 12 with four doors open). The Admin stairs no longer trap bots on their side.
- **All maps, bots:** a bot carrying a full gun from the crate now still refills its empty Crucible gun at an ammo box (it used to ignore the empty one).
- **All maps:** a zombie that can't reach anyone for 45 s is moved near the players, and a round with nowhere to spawn falls back to any spawn, so a round can't hang forever any more (one Kaltenbrunn round had hung for 140 minutes).
- Tooling: the minimaps were re-baked, the test suite runs clean in the cloud, and the ADS check runs without a screen (322/322 sights aligned).

## Status
| Part | Status |
|---|---|
| QA pass on Maps 0–2 (soaks, playtests, smokes) and every fix | **works** |
| Map 4 design doc (`docs/MAP4_FERNFLUG.md`) | **done** |
| Acts I–IV, the transitions and their cutscenes | **works** (greybox art) |
| The two perks, the Lodestone, the four bosses | **works** |
| The main egg across all four acts + three side eggs | **works** (tested end to end with dev skips) |
| Both endings | **works** |
| Play.bat buttons (full run, skip to Act II/III/IV) | **works** |
| Full-run soak with bots | **partly**: the whole chain passes with dev skips; bots alone get to Act II |

**The full-run soak.** With the player's dev skips, the whole map plays from Act I to the ending and the egg runs end to end (both tests pass, 0 script errors). Without skips, three bots on their own cleared Act I to round 15, boarded, and died in Act II at round 19. Dropped cold into Act III or IV, bots alone are overrun in the first minute. Map 4 is tuned for you leading the squad, not for bots alone. Details: `docs/QA_REPORT_U07.md` §7.

## Doesn't work yet / known issues
- **No voice audio for Map 4.** All ~310 new lines play as subtitles with timed silence. They need the PC's voices (`gen_vo.py`), or your friends' recordings.
- **Greybox art.** The four acts are blocked out in plain materials. Only the Lodestone and the two perk cabinets have real models.
- **The bots aren't good at Map 4 on their own.** Without you they open doors and train, but alone they die in Act II, and a cold skip into Act III or IV overruns them in the first minute. They also reach the Kaltenbrunn power too late when playing alone.
- **Act III shortcuts.** Burrowers don't bite on the way up, a frag doesn't kill them underground, and Jumpjockeys don't take extra damage in the air.
- **Small gaps.** Dee's alternate goodbye line isn't wired in. Fasbender's burn numbers show on screen rather than being spoken. The air-raid warning still uses the bell sound. The Account Manager's "free trial" strips every perk you hold, which may be too harsh.
- **Not built:** Morgenrot (Map 3) is still design-only, and the Homage-boss slot on Map 4 is reserved but empty until you name a likeness. Bolt and Vendelin's Map 4 lines are written but can't be heard (they aren't playable on Gravelight maps yet).
- **Frame rate not measured.** The cloud can't render. Please check the 60 FPS headroom on your PC.

## Needs you
See `morning/NEEDS_DEVIN.md`, section 0c: allow `lfs.github.com` for the cloud environment. This update's new binaries (about 14 MB) are stored as plain git files until then.

## Get it on your PC
Paste this into Claude Code on your PC:
`git checkout master && git pull origin master && git lfs pull`

---


# Morning report — Update 05 art slice + Update 06 cloud & voice + fixes, 2026-10-26

Crossroads Inn now looks like a game (real guns, people, zombies, textures, VFX, UI), the repo is on GitHub (private,
LFS) and runs in a cloud session, and the voice-acting kit for your friends is ready.
Tests: **1,133 unit tests and all 36 smoke tests pass on Windows and on Linux** (WSL Ubuntu 24.04).

## Play it (Play.bat)
- **Update 05 — art slice**: "Map 0 — art slice (round 1)", "... (round 12, 3 bots)", "Weapon viewer", "Character lineup".
- **Update 06 — voice acting**: "Voice review page", "Map 0 — voice test (round 1–3)".
- Settings → Video → **Aspect: Fill screen** is on by default: your 21:9 monitor fills edge to edge.

## What's done
| Section | Status |
|---|---|
| 05A asset intake (your 3 Sketchfab guns + the OpenGameArt set, licences, credits, licence-gate test) | works |
| §1 pipeline (art bible, CC0 textures/props, shared shaders, import presets, asset report, 28 fixed cameras) | works |
| §2 viewmodel: 16 real guns, per-character arms, ads_check 320/320 | works (6 guns still greybox: Luger, M1919, Type 100, PTRS-41, Panzerschreck, flamethrower) |
| §2 wonder weapons (Ashlight, Totenglocke, Sankt-Elmsfeuer, Gramophone) + design sheets for 4 later ones | works (no inspect animation: there is no inspect system) |
| §3 zombies (6 bodies × 9 outfits, faces, gore, LODs; faster than the boxes) | works |
| §4 people (squad, Jakub, 5 patrons, 3 survivors, the Cousins; faces blink/emote/lip-flap) | works (Bolt, Vendelin, Paul not built: not in this map) |
| §5 environment (all materials, real spruces/birches, furniture, barn dressing) | partly: no window glass (they're boarded), no stone yard wall (it's fenced), no benches/wardrobes/curtains/pictures |
| §5 world objects (9 perk cabinets, crate, ammo crates, barricades, doors + plaques, wall-buy mounts, Crucible, bench, radio, lever, beacon) | works |
| §6 VFX (flashes, real casings, impacts, blood, atmosphere, VFX-quality setting) + 60-s clip | works |
| §7 UI (bundled fonts, HUD grid, crosshair, boss bar, brass minimap bezel, pause-map fit) | works |
| 06 Part A: secrets scan, Git LFS, private GitHub repo, cloud_setup.sh, CLAUDE.md, portable paths | works |
| 06 Part B: voice acting (cast sheet, scripts, guide, release, importer, review page) | works on synthetic recordings; waiting for real takes |
| Fixes you asked for (guns, people, world) + bots aim down sights, Garand clip, bot refills | works |

## Repo (Update 06 A)
- **https://github.com/DBITDEFENSE/bolt-and-sprocket-ultimate** — PRIVATE, all 34 branches and 10 tags.
- **Secrets: none found** (no keys, tokens, passwords, .env or personal files in any commit). Nothing to rotate.
- Size: git history **935 MB → 30 MB**; big files in LFS (685 MB, 3,647 versions). The Kokoro TTS model (312 MB) had been
  committed by mistake; it's out of history now and still on your disk in `tools/tts/`.
- A fresh clone from GitHub gets real files (2,431/2,431, no LFS pointers). The Linux run found two real portability bugs,
  both fixed: Blender inside the project made Godot's Linux import give up (Map 0 never loaded), and the map-data
  fingerprint rounded differently on Linux.
- Full backup of the pre-LFS history: `C:\Users\Devin\AppData\Local\Temp\claude\...\scratchpad\backup\pre_lfs_all.bundle`
  (temp folder; copy it somewhere if you want to keep it).

## Screenshots
- Before/after, 28 fixed cameras: `morning/screenshots/u05/pairs/*__before_vs_after.png` (+ `sheet__before_vs_after.png`).
  The minimap looks oval in the "after" set: the capture tool squashed a 21:9 window to 16:9; in game it's round.
- Per section: `morning/screenshots/u05/{viewmodel,wonder,zombies,people,objects,vfx,ui}/`, fixes in
  `morning/screenshots/batch8/{guns,people,world}/`. 60-s clip: `morning/clips/u05/map00_vfx_r8.mp4` (taken before the
  people/zombie/world passes).
- Asset report: `morning/asset_report.md`. FPS at round 15 with 3 bots: ~68–78 (High, target 60 met).

## Decisions I made for you (details in docs/DECISIONS.md T-087..T-102)
1. Finishing Map 0's easter egg gives everyone all nine perks for the match.
2. Bots help with the egg by default (Full Partner).
3. Classic Rules keeps the 4-perk cap; normal play is 6.
4. Zombies, people, trees and the machines are built by our own Blender scripts (no free download fit the rig).
5. The Map 0 opening now starts round 1 at ~12 s (was 33); three pre-round chat lines rarely play now.
6. Voice: your existing Whisper (large-v3) is reused; loudness matches the game's current voices.

## Needs you (details in morning/NEEDS_DEVIN.md)
1. **Fill in the cast**: `data/voice/cast.json` (who plays DUT, PEG, DEA, WRN, OPR, JAK, FAS, REI, LSL, the patrons and
   survivors, and the B&S cast; the Cousins' slots are for your cousins). Then `tools/voice.sh scripts`.
2. **Send each friend**: `voice_scripts/<name>/<name>_script.pdf`, `voice_scripts/RECORDING_GUIDE.txt`,
   `voice_scripts/VOICE_RELEASE.txt` (they reply "I agree – name – date"). Recordings go in `voice_inbox/<name>/` with a
   `consent.txt`; then `tools/voice.sh import` and open the review page.
3. **Cloud session**: claude.ai/code → connect GitHub → pick `bolt-and-sprocket-ultimate` → paste the next work order.
4. Delete the empty folder `C:\c` (a tool made it by a typo; I don't delete outside the project).
5. Optional downloads (guns still on greybox, Unity zombies/mocap, Mixamo clips): the list in NEEDS_DEVIN.md.

## Known rough spots
- Thompson ADS shows its big receiver block; the pistol hip pose has long arms; Wren shows a little hair under her cap.
- An olive arm holding a gun floats by a pillar in one squad close-up (old, not investigated).
- With bots on, their egg chatter can overlap the patrons before round 1.
- 32:9 screens get a very wide field of view (Godot's default).

## Next up
- Rolling the art pipeline out to Kaltenbrunn and Totenhafen: materials and props are reusable (the generators switch
  key by key in materials.json), people/zombies/guns/VFX/UI carry over as they are; new per map: dressing scripts, its
  wonder weapon, a capture camera set. Estimate: one night per map.
- Recording sessions once the cast is filled in.
