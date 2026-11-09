# Gun shopping list (for Devin)

## Zombie overhaul additions (2026-11-08)

- RECEIVED 2026-11-09: MoCap Online Zombie Starter 2.7 from Devin's Downloads folder;
  26 root-motion clips plus 26 in-place versions of the same recordings. These are not 52
  distinct motions. Source files are now in the zombie worktree's ignored `assets/user_supplied/`.
- Remaining motion coverage: additional distinct locomotion variants (especially upright walks
  suited to the preserved 1.3/2.0 m/s tiers and a 0.8 m/s crawl), barricade tears/vaults, climbs,
  ground emerges, directional hit reacts, knockdown/get-up pairs, crawler bite/armless attacks,
  and at least six more distinct death performances. The Starter pack has two death clips.
- Archive the purchase receipt/license with the local pack when available; the official Standard
  License and owner-supplied provenance are recorded in ASSETS.md. Do not buy this pack again.
- The supplied arm loop now covers two reviewed single swipes; both supplied deaths are integrated.
  Two additional distinct swipes, a runner lunge and sprinter grab remain source gaps. The supplied
  rapid multi-swipe barrage is preview-only: it is not a single hit at the game's existing windup.
- Close-up review found the current soldier head and uniform too simplified for the art bible.
  Needed: an original artist-authored zombie head/body and distressed WW2-style clothing set
  (or a commercially licensed source with editable meshes), PBR albedo/normal/roughness, clean
  deformation weights, and LOD0-2. Fictional markings only; no prisoner/forced-laborer enemies.
  Fit it to the shared rig and validate one soldier before commissioning the rest of the roster.


Claude Code models only the wonder weapons. These are the conventional guns you download or buy, then drop into:
`C:\Users\Devin\PROJECTS\bolt-and-sprocket-ultimate\assets\user_supplied\weapons\<pack-name>\`
Put the license text, or a screenshot of the license and receipt, in the same folder. Claude Code handles everything after that: unpacking, scaling, sight alignment, the shared materials, Crucible camo, and fitting animations.

## What to look for in a pack
1. **The license allows commercial use in ANY engine.** That's usually fine for third-party packs on Fab (Epic's store), the Unity Asset Store, itch.io, ArtStation, and Gumroad, but check each listing. **Avoid** anything "Unreal Engine only," Epic's own content, "editorial use only," and CC-NC licenses.
2. **Source files included:** FBX, GLB, or Blend. On Fab, check that the listing offers FBX/GLB downloads, not only Unreal-format files. A Unity `.unitypackage` is fine; Claude can unpack it.
3. **First-person arms and animations are a big bonus** (idle, fire, reload, sprint, ADS). That's most of the work saved.
4. **Style:** realistic or stylized-realistic, PBR textures, roughly 5k–30k triangles per gun. Skip voxel and super-low-poly packs; they won't match.
5. **One big pack beats many small ones**, because matching style matters. Claude will run a shared material pass to blend packs anyway.
6. **Red flag:** Sketchfab or other uploads described as "from Call of Duty," "ripped," "WaW model," etc. Those are illegal game rips even when they're labelled "free." Skip them.

## Priority order (the 22 conventional guns in the game)
**Get first** (what players hold most): M1911 · Thompson M1A1 · Kar98k · M1 Garand · MP40 · Trench Gun (Winchester M1897) · STG-44 · BAR

**Then:** Gewehr 43 · M1 Carbine · PPSh-41 · MG42 · Browning M1919 · Double-Barrel Sawed-Off · Springfield M1903 (scoped) · Panzerschreck · M2 Flamethrower

**Then the newer additions:** Walther P38 · Webley Mk VI · Luger P08 · Type 100 · PTRS-41

**Also useful if a pack has them:** Mk 2 frag grenade, a stick grenade, a trench knife or KA-BAR, and loose ammo, clips, and magazines (for ammo boxes and pickups).

## Where to look
- **Fab** (fab.com): search "WW2 weapons" or "WWII FPS weapons." Many listings have first-person animations; filter for FBX/GLB formats.
- **Unity Asset Store:** search "WWII weapons FPS." Standard-EULA packs generally work in other engines; avoid any marked "Companion License."
- **Sketchfab:** filter to Downloadable plus a CC0 or CC-BY license, good for filling single gaps. CC-BY just needs a credit line, which Claude will add.
- **itch.io:** mostly low-poly or stylized, but cheap.

Not everything is on hand: if a gun is missing, Claude keeps the greybox for that one and lists it in the morning report. You can grab it later.
