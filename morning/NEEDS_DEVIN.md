# NEEDS DEVIN

Short, phone-readable. Nothing here blocks the build.

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
