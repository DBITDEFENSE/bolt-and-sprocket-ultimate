# NEEDS DEVIN (UPDATE 05, art slice)

Short, phone-readable. Everything below needs your accounts or your card; the build continues on CC0 fallbacks
until it arrives. Drop folders are under `assets/user_supplied/` (one folder per download, keep the page URL in a
`SOURCE.txt` next to it). Nothing here blocks tonight's work.

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

## 4. Sketchfab (free account, CC-BY) — guns still on the procedural greybox
Already in: Thompson, M1 Garand, Kar98k. Still wanted (download **glTF**, keep the auto-generated license text):
the picks in `FREE_ASSET_LIST.md` for M1911 (FrenchBaguette), MP40 (Moony_State), STG-44 (Arbuzz747), BAR
(ConnorNielsen), PPSh-41 (Artem.Goyko), Springfield (Gintoki1234), Panzerschreck (Tactical_Beard), M1919
(MelvinEbbuts), Double Barrel (Pepego), Webley (WillemVerheughe), Luger (I_Live), M1 Carbine (roelandvermeulen),
Trench Gun (buh-late), PTRS-41 (Naudaff3D). Each into `assets/user_supplied/weapons/sketchfab-<gun>-<author>/`.
Skip anything tagged NoAI or "(Enlisted)".

## 5. Found missing tonight (no account needed, but a decision from you)
1. **No CC0 wheelbarrow, sack or hay bale model** worth having on Poly Haven / Kenney; the procedural ones stay
   (`Props.sack`, the bale blocks). If you want real ones, Quaternius's packs are CC0 but low-poly cartoon; say
   "ok, Quaternius" and the environment builder uses them, or we model them in Blender.
2. **Poly Haven props are photogrammetry-heavy** (bed frame 50k tris, tree stump 41k, lantern 34k, bottles 29k).
   They are in the library with `over_budget` flags; the plan is a headless Blender decimate pass to the 3k prop
   budget. No action from you unless you'd rather buy a clean period-furniture pack.
3. **The sky**: the two night HDRIs are reference only; the procedural sky dome (landscape.gd) stays until someone
   decides to swap it. No action.
