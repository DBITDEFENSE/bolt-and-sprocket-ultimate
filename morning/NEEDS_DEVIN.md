# NEEDS DEVIN

Short, phone-readable. Nothing here blocks the build.

## MAPS 1-2 PRODUCTION PASS (2026-11-09): look before merging. Nothing blocks the build.
- [ ] **Eyeball the four new areas** (I had no renderer: everything was checked by geometry, navmesh and smokes only).
  `DevLauncher.bat` into Map 0 / Map 1, or capture them: `tools_src/capture.gd --set=u05 --only=attic_stairhead,attic_east,bar_counter,bar_service`
  and `--set=u10_map01 --only=A_kaue_inside,A_kaue_front,I_skyhook,I_crucible_corner`. What to judge: the attic's
  scale and clutter, the bar's proportions (is it "bigger" enough?), the Kaue's baskets and light before the power, the
  Core corner's density. Tell me what to push further.
- [ ] **Merge `claude/maps-1-2-production` to master** when happy (it carries the Fernflug plane pass; the full unit
  suite passed on this branch after two test updates). `git checkout master && git merge claude/maps-1-2-production && git push`.
- [ ] **Perf glance on your GPU:** the attic adds ~60 colliders and ~600 dressing primitives to the Inn, the Kaue and the
  Core about 300 to Kaltenbrunn. `tools/perf_census.sh` or just the FPS counter in the taproom and the Kaue.

## UPDATE 12 (2026-11-08): only you can do these. Nothing blocks the game: each has a stand-in.
- [ ] **The real C-47 for GRAVELIGHT ONE:** on Sketchfab, download "C47" by manilov.ap (CC-BY 4.0), https://sketchfab.com/3d-models/c47-c4fb0f24d55f4866a9669aa952dceaf3 , as **glTF Binary (.glb)**. Save it as `assets/user_supplied/u12/c47/c47-manilov-ap/model.glb` with a `SOURCE.txt` holding that link. Optional: "Douglas C-47B Dakota IV KN645" by mgg8 (CC0), https://sketchfab.com/3d-models/35da2958566f421593bcc2dac9c3b762 , into `assets/user_supplied/u12/c47/c47-dakota-kn645-mgg8/` the same way. Then run `sh tools/c47/build.sh`. It builds the crashed and intact planes and adds the artist to the credits. Until then the game uses our own C-47 built from the real dimensions. After the swap, check the model's own markings (it may carry USAAF stars or a real serial).
- [ ] **Higgsfield commercial terms:** check that your Higgsfield plan allows commercial use of the clips. Write the plan and the date you checked into each `assets/user_supplied/cutscenes/<scene>/LICENSE.txt`, and the model and dates into each `SOURCE.txt`. Until then, treat the clips as private and development use only.
- [ ] **Generate the archive-reel clips:** 49 shots in `docs/cutscenes/SHOT_PROMPTS.md` (Lazarus Saturday 21, Fourth Day 15, Staub 13), priority 1 first. Save each as `assets/user_supplied/cutscenes/<scene>/shot_NN.mp4`, then run `python -I tools/cinema/archive_reel.py build` (`... report` shows what's left; on Windows it uses WSL Ubuntu's ffmpeg, already installed). Any shot without a clip plays the in-engine version through the same film look.
- [ ] **Motion capture with friends:** `docs/MOCAP_GUIDE.md` has 27 shots and 100 takes, about 4.8 hours of filming (two phones nearly halve it). No free app tier covers it: Rokoko Vision free is 30 s/month and allows commercial use; DeepMotion (60 s/month) and QuickMagic (30 s) free tiers ban commercial use. Pick one app and pay for one month. Rokoko's free 30 s is enough to try one shot first. Drop the files in `assets/user_supplied/mocap/<scene>/`, then run `sh tools/mocap.sh report` and `sh tools/mocap.sh build`.
- [ ] **ElevenLabs:** about 1,400 characters left until the 2026-12-07 reset. After the reset, run `tools/voice.sh elevenlabs bake` again; it resumes The Fine Print at `fp.c3.outro.09`, then Bolt & Sprocket, and fills the reels' empty narration slots.
- [ ] **Look with your own eyes (no setup):** Play.bat's dev launcher (`DevLauncher.bat`) has "Look test — every map's style frame", "Map 0 — walk the wreck" and the three reel cutscenes. Voices: turn Settings > Audio > Room acoustics on and off in the inn's taproom and the cellar, and listen to the Russian accents in Fourth Day.

## UPDATE 11: ElevenLabs
<!-- eleven-plan:start (tools/voice.sh elevenlabs plan rewrites this block) -->
- **Estimate 2026-11-07** (`tools/voice.sh elevenlabs plan`, model `eleven_v4`, 1 credit per character): **158,596 characters** still to bake, so **Pro (500,000 credits / month) in one month**.
- Per group, in bake order: 1 the new cutscenes 0; 2 the squad 0; 3 the Operator 0; 4 the map NPCs 18; 5 the bosses 25; 6 barks 0; 7 The Fine Print 101,311; 8 Bolt & Sprocket 57,242.
- Your account now: **creator** tier, 123,965 of 131,000 characters used this period, next reset 2026-12-07. Not enough for the whole bake in one period: upgrade for one month, or stay and bake over about 2 monthly periods (the bake stops cleanly at the quota and resumes after the reset).
<!-- eleven-plan:end -->
- **The bake stopped on purpose (T-201 bake, 2026-11-07):** the account's own counter is at 123,965 of 131,000 (7,035 left; I stopped there to keep your 5,000 reserve, and the counter lags a little). Baked: groups 1-6 complete (cutscenes 113, squad 578, Operator 397, NPCs 438, bosses 68, barks 1,087 lines; 5 lines are only stage directions, such as "[faint giggle under the drum]", which need sound effects, not speech), The Fine Print 1,228 of 2,867 lines, Bolt & Sprocket 0 of 728. Left to bake: 158,596 characters (Fine Print 101,311, Bolt & Sprocket 57,242). The account counter moves only about 0.44 per billed character, so that is about 70,000 of the counter: **one Creator month is enough after the reset on 2026-12-07** (no need for Pro), then run `tools/voice.sh bake` again; it resumes where it stopped.
- **Optional, ElevenLabs key permission:** the key in `.env.local` has no `voices_write`, so nothing could be added to the account or Voice-Designed. The cast therefore uses Voice Library and premade voices by their ids directly (they speak fine without being added). If you want the cast pinned into your account (a library owner can withdraw a voice), make a key with `voices_write` and run `tools/voice.sh elevenlabs assign --char=.. --voice=.. --owner=..` per voice (30 slots on Creator). Nothing needs doing for the bake to run.

## UPDATE 10 (2026-11-02): the steps only you can do, one line each
1. **Vercel and the site password:** unchanged from UPDATE 09 (items 1-2 below); the web build must be rebuilt from this master first: `sh tools/build_web.sh` then `sh tools/deploy_web.sh`.
2. **Likeness (optional):** send Paul's details (a catchphrase, team, item or tattoo; his surname and unit, see HOMAGE_BOSSES D4 for the unit/date clash; what his letter should talk about) and your own (hair, height, glasses, beard, style; your surname for the watch-book) so `data/gravelight/bosses/likeness.json` can be filled; until then both use the defaults and no placeholder ever shows.
3. **Look at it in Forward+ (the renders here were all software):** Totenhafen at the spring tide and the sail (Play.bat > "Totenhafen - Spring Tide" and "sailing finale"), the air raid, the wing walk, the dust storm, the terminator (the four act buttons), PAUL and the Slender. Each button forces its set-piece a few seconds in.
4. **Real FPS:** play each map once with `--frame-log` (Play.bat forwards it) and leave `logs/frame_log_*.csv`; the smooth-zombies toggle (Settings > Video) is the one new per-frame cost.
5. **Cast voices:** every new line is placeholder TTS; the Operator, the PA, Wittkamp, Dee, Hale, the Woman in Violet, the Kielholer's four German lines and the Totenhafen people want recordings (`docs/PLACEHOLDERS_U10.md` lists the keys; the review page in the launcher takes your recordings line by line).
6. **Online, two real machines:** the lobby code path and a browser peer against a desktop host were only run as two processes on this PC; try it once with a friend (TURN is optional, item 4 below).
7. **The bar:** the scorecard target moved to 76 because Kaltenbrunn's living world raised it; Totenhafen and the acts are under it (docs/THE_BAR.md section 3.3). Decide whether the next order keeps 76 as the bar or the seed rows alone.

## UPDATE 09 (2026-11-01): the account steps left for you, one line each
1. **Vercel (publish the browser build):** `npx vercel login` then `sh tools/deploy_web.sh` (the session could not create the Vercel project itself: the permission guard blocks connecting the private repo to an outside service).
2. **The site password:** `cd build/web && npx vercel env add CZ_PASSWORD production` (type the password you will text your friend), then `sh tools/deploy_web.sh` again.
3. **Supabase:** nothing required; the project `claude-zombies` exists and the lobby tables are live (checked twice on 2026-11-01). Optional: enable `pg_cron` (Database > Extensions) so dead lobbies are swept every minute; the game sweeps on its own too.
4. **TURN (optional, for friends on strict networks):** make a free TURN account (Metered.ca Open Relay or Cloudflare TURN) and paste its urls / username / credential into `data/gravelight/online.json` "turn".
5. **Real FPS:** play each map once with `--frame-log` (Play.bat forwards it) and leave `logs/frame_log_*.csv`; and if you have a laptop with Iris Xe / Radeon 680M, open the browser build on it (`sh tools/serve_web.sh`, http://127.0.0.1:8060/) and note the FPS on Map 0.
6. **Look at it in Forward+:** the main menu, Totenhafen's pen hall, Fernflug Act II and the Moon yard were only ever seen through a software renderer here.


## 0. Start a cloud session (UPDATE 06 Part A is done)
The repo is on GitHub, **private**: https://github.com/DBITDEFENSE/bolt-and-sprocket-ultimate
(every branch and tag; big files in Git LFS).
1. Open **claude.ai/code** in a browser.
2. **Connect GitHub** if it asks (allow access to `DBITDEFENSE/bolt-and-sprocket-ultimate`; you can limit it to
   that one repo).
3. **Pick the repo** `bolt-and-sprocket-ultimate`, branch `master`.
4. **Paste the next work order** (e.g. UPDATE 06 Part B). The session reads `CLAUDE.md` and runs
   `tools/cloud_setup.sh` first (about 15 minutes the first time: Godot, Blender, import, tests).
5. When it finishes it pushes a branch; on the PC run `git pull` (or `git fetch` + merge) to get the work.
What can't happen in the cloud: playing (`Play.bat`), screenshots except slowly under a virtual display, the
local-LLM bot (Ollama), re-recording the Windows/Kokoro TTS voices unless it reinstalls Kokoro on Linux.
**GitHub LFS quota:** the repo uses about 0.7 GB of LFS storage; a free account includes enough for that, but
every full clone downloads ~0.7 GB of LFS bandwidth. If GitHub ever emails about LFS bandwidth, that's why.

## 0c. UPDATE 07 (Map 4): five things only you can do
1. **Allow `lfs.github.com` for the cloud environment.** The session's network policy let it clone and pull LFS, but every LFS *upload* was refused ("connect_rejected lfs.github.com"), so the new binaries of this update (the Lodestone model and textures, the two jingle sketches and the perk/weapon sound sketches, about 14 MB) are committed as plain git files, with the override lines at the end of `.gitattributes`. Fix: in the cloud environment's settings (the environment menu in the session's title bar → Edit → Network access) add `lfs.github.com` under Allowed domains (keep "Allow package managers" ticked), or pick a broader access level. Then, on the PC, move those files into LFS with the one-liner in `.gitattributes` and delete the override lines.
2. **Blender's download mirrors are blocked too** (mirrors.ocf.berkeley.edu, ftp.nluug.nl, download.blender.org all 403). `cloud_setup.sh` now falls back to the `bpy` wheel from PyPI (Blender 5.2.3 as a Python module behind `tools/blender_shim.sh`), which built the Lodestone fine. If you would rather have the real 5.1.2, allow one of those hosts the same way.
3. **Bake Map 4's voices on the PC.** About 310 new lines (the Operator, Wittkamp, the Bordfunk, the Bordwart, Dee, Hale, the Test Pilot, the Woman in Violet's machine, and the squad's Map 4 lines) are in `data/gravelight/vo/lines.json` and listed under `missing` in `audio_manifest.json` with "map4: bake on the PC". Run `python gravelight/tools_src/gen_vo.py` there (or hand the scripts to your cast: the per-actor scripts regenerate from the same data).
4. **Check the frame rate on Map 4.** The cloud can't render. Play each act once (Play.bat → "skip to Act II / III / IV") and watch for drops, especially the Great Hangar (Act I) and the Moon yard (Act IV).
5. **Name a likeness for Map 4's homage-boss slot if you want one.** Groom Lake's hangar has room for a fourth homage boss (a range mechanic who fights with the hangar's tools). Nothing is built until you say who it is.

## 0b. One small cleanup only you can do
- Delete the empty folder **`C:\c`** (an empty `C:\c\Users\...` tree a tool created by a typo tonight). I don't
  delete anything outside the project folder. It holds no files.

## Update 05 (art slice) items

## 1. Unity Asset Store (free) — zombies and set dressing
Log in to assetstore.unity.com, click **Add to My Assets** on each, then in Unity Hub / any Unity project open
**Package Manager → My Assets → Download** (no need to import into a scene). The `.unitypackage` files land in
`C:\Users\Devin\AppData\Roaming\Unity\Asset Store-5.x\<publisher>\<category>\`. Copy each `.unitypackage` to
`assets/user_supplied/characters/<short-name>/`.
1. FREE Zombie Male AAB (Studio New Punch) — https://assetstore.unity.com/packages/3d/characters/humanoids/free-zombie-male-aab-336744 — the realistic start point, body-parts version for dismemberment.
2. FREE Shirtless Zombie (Studio New Punch) — https://assetstore.unity.com/packages/package/276762
3. Zombie (Pxltiger) — https://assetstore.unity.com/packages/package/30232 — classic, comes with animations.
4. Free Female Zombie — https://assetstore.unity.com/packages/package/286579
5. WW2 Armed Forces Demo (18 tanks, wrecks for the field) — https://assetstore.unity.com/packages/package/184465
6. Vintage German Guardbooth — https://assetstore.unity.com/packages/package/403776
7. HQ MP40 weapon (free, a 14k-tri MP40 backup) — https://assetstore.unity.com/packages/package/223657

## 2. Unity Asset Store ($4.99 each, about $20 total)
Same download route as above, then `assets/user_supplied/characters/` (soldiers, mocap) or `.../weapons/`.
1. ZOMBIE Starter: MoCap Animation Pack — https://assetstore.unity.com/packages/package/61492 — real zombie mocap; retargets onto the ZombieRig.
2. German soldier WWII (WarArm) — https://assetstore.unity.com/packages/package/191563 — the soldier-zombie base (we swap any real insignia for the P·W·K mark).
3. Soldier russian WWII (WarArm) — https://assetstore.unity.com/packages/package/191185 — optional, Totenhafen/Kaltenbrunn variety.
4. Rifle M98kM1 FPS — https://assetstore.unity.com/packages/package/70908 — optional Kar98k upgrade (the Sketchfab dsamuta one is already in).

## 3. Mixamo (free with your Adobe login) — 12 animations for the people and the zombies
Go to mixamo.com, sign in, pick the **Y Bot** character (or upload nothing: Y Bot is fine, we retarget). For each
animation below: search the name, click it, **Download** with Format **FBX for Unity (.fbx)**, Skin **Without
Skin**, Frames per second **30**, Keyframe reduction **None**. Save all twelve to
`assets/user_supplied/animations/mixamo/` (file names as Mixamo gives them). Also download the **Y Bot** once
**With Skin** (T-pose) into the same folder so the rig comes with it.
1. Zombie Idle
2. Zombie Walk
3. Zombie Running
4. Zombie Crawl
5. Zombie Attack (the one-arm swipe)
6. Zombie Biting
7. Zombie Death (falling forward)
8. Zombie Dying (falling backward)
9. Zombie Stand Up
10. Rifle Idle
11. Rifle Walk (or "Walking With Rifle")
12. Pistol Idle
Nice to have if you are already there: "Zombie Scream", "Zombie Reaction Hit", "Crawling" (human), "Sitting Idle"
(the patrons), "Talking" (the survivors).

## 4. Sketchfab (free account, CC-BY) — the 6 guns still on the procedural greybox
16 guns now have real models (your 3 Sketchfab heroes + the OpenGameArt set). Still greybox: **Luger P08**
(I_Live), **Browning M1919** (MelvinEbbuts; not an "(Enlisted)" upload), **Panzerschreck** (Tactical_Beard),
**PTRS-41** (Naudaff3D), and the **Type 100** and **M2 flamethrower** (no free match). Optional hero upgrades over
the low-poly set: M1911 (FrenchBaguette), MP40 (Moony_State), STG-44 (Arbuzz747). Download **glTF**, keep the
license text, one folder each: `assets/user_supplied/weapons/sketchfab-<gun>-<author>/`. Skip NoAI uploads.
Optional too: a stick grenade (Stielhandgranate 24 by dsamuta).

## 5. Found missing tonight (no account needed, but a decision from you)
1. **No CC0 wheelbarrow, sack or hay bale model** worth having on Poly Haven / Kenney; the procedural ones stay
   (`Props.sack`, the bale blocks). If you want real ones, Quaternius's packs are CC0 but low-poly cartoon; say
   "ok, Quaternius" and the environment builder uses them, or we model them in Blender.
2. **Poly Haven props are photogrammetry-heavy** (bed frame 50k tris, tree stump 41k, lantern 34k, bottles 29k).
   They are in the library with `over_budget` flags; the plan is a headless Blender decimate pass to the 3k prop
   budget. No action from you unless you'd rather buy a clean period-furniture pack.
3. **The sky**: the two night HDRIs are reference only; the procedural sky dome (landscape.gd) stays until someone
   decides to swap it. No action.

## T-125 (2026-10-28): look at Map 0's yard in game
The fences round the barn's yard (and the roadside fence) were never drawn since 2026-10-25: their drawings were
lost when the map was generated headless. They are drawn now, as taller corral fences where they block you. I could
not render it here: please walk out of the stable's south door and check the yard fences show up and look right.

## T-126 (2026-10-28): look at the plane wreck and Selwyn in game
GRAVELIGHT ONE is hollow now: walk in by the cargo door or the torn hole on the starboard (low) side. The pilot,
Flt Lt Selwyn, is pinned in the cockpit: stand in the cabin at the wrecked doorway and hold the interact key to hand
him a second gun (not your only one); he shoots zombies ahead of the nose and asks for ammo when dry. I tested it
headless only: please check the hull reads well from inside and out, that Selwyn sits right in his seat and turns
to his targets, and that his gun sits in his hands. The minimap's wreck outline is unchanged (no re-bake needed).

## UPDATE 08 (2026-10-28): what's left for the egg work
Tier IV perks and the bots' round-25 kit are done and merged. "Bots finish every Easter egg" is partly done: Map 0's
egg completes with bots, and Kaltenbrunn's now gets as far as the power, the parts and the first pylon. The rest
isn't done yet: `docs/QA_REPORT_U08.md` (After) lists every blocker found and the ones still open. The work carries
on from the PROGRESS.md resume line. Nothing for you to do; try the new launcher buttons if you like.

