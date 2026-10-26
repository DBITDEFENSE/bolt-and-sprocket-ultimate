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
