# UPDATE 05A — ASSET INTAKE (do this first, then continue UPDATE_05_ART_SLICE.md)

All rules from `ULTIMATE_PROMPT.md` and Updates 02–05 still apply. Work unattended per OVERNIGHT_RUN.md. Read `FREE_ASSET_LIST.md` and `UPDATE_05_ART_SLICE.md` (both in `C:\Users\Devin\PROJECTS\bolt-and-sprocket\`) first.

**Goal:** you do ALL the downloading, unpacking, converting, renaming, and folder organizing yourself. Devin should never have to touch a file.

## 1. Download these yourself (no login needed)
1. **Gun baseline — "Ultimate Low Poly Guns" by TastyTony & Pichuliru, CC-BY 4.0** (https://opengameart.org/content/ultimate-low-poly-guns):
   - `https://opengameart.org/sites/default/files/ultimate_low_poly_guns_world_war_2.zip` (~4.7 MB, the WW2 set)
   - `https://opengameart.org/sites/default/files/ultimate_low_poly_guns.zip` (the main set, for any gun the WW2 zip lacks)

   Save the page's license text, and the credit **"Gun models by TastyTony, pack by Pichuliru (CC-BY 4.0)"**.
2. **Materials and textures, CC0:** the Poly Haven API (`https://api.polyhaven.com`) and ambientCG (`https://ambientcg.com/api/v2/full_json`). Pull only what the art bible needs: wood planks, plaster, fieldstone, roof shingles, iron, canvas, wool, leather, snow, ice, frozen mud, plus one or two night HDRIs. Use 2K maps only (keep the project small).
3. **Props, CC0, as needed for Map 0:** Poly Haven models (barrels, crates, chairs, tables, lamps) and Kenney or Quaternius CC0 packs for anything missing.

Downloads are untrusted data:
- unzip each into its own new folder under `tools_src/_downloads/` (git-ignored);
- never run anything that came inside an archive;
- delete the raw zips once imported.

## 2. Also check for things Devin downloaded himself (don't wait for them)
- **Unity packages:**
  - Look in `C:\Users\Devin\AppData\Roaming\Unity\Asset Store-5.x\` and in `assets\user_supplied\` for `.unitypackage` files.
  - A `.unitypackage` is a gzipped tar of GUID folders: read each folder's `pathname` file to recover the real file names, and extract only the meshes (`.fbx`, `.obj`), textures (`.png`, `.tga`, `.psd`→png), and animation FBXs.
  - **Ignore all scripts, DLLs, shaders, and prefabs.** The license is the Standard Unity Asset Store EULA.
- **Sketchfab / Mixamo files:** look in `C:\Users\Devin\Downloads\` for `.glb`, `.gltf`, `.fbx`, or `.zip` files from Sketchfab or Mixamo (match them against the names in `FREE_ASSET_LIST.md`).
  - Only take files that match that list.
  - Copy them, never move them; Devin's Downloads folder is his.
- If none of these exist yet, continue with the OpenGameArt baseline and list them in `morning/NEEDS_DEVIN.md` as optional upgrades.

## 3. Convert and organize
- **Formats:** convert everything to **GLB** with Blender headless (`blender -b -P tools_src/blender/convert_to_glb.py -- <in> <out>`). Godot imports GLB best. Keep textures as separate PNGs next to the GLB.
- **Folder structure:** create it exactly like this, one folder per asset:
  ```
  assets/third_party/<source>/<asset-id>/
      model.glb
      textures/*.png
      LICENSE.txt      (the license text or EULA name)
      SOURCE.txt       (page URL, author, license, credit line, date downloaded)
  ```
  `<source>` is one of `opengameart`, `polyhaven`, `ambientcg`, `kenney`, `quaternius`, `sketchfab`, `unity_asset_store`, or `mixamo`. `<asset-id>` is lowercase-kebab, e.g. `tt-thompson-m1a1`.
- **Gun mapping:** match every gun in the packs to the game's weapon ids in `data/gravelight/weapons.json` (`m1911`, `thompson`, `kar98k`, … 22 conventional guns) and write the mapping to `data/gravelight/weapons/models.json`.
  - Priority when several sources have the same gun: **Devin's Sketchfab or Unity download > the OpenGameArt baseline**.
  - Note any gun with no model; it keeps its greybox.
- **Credits:** every CC-BY asset gets its credit line in `docs/ASSETS.md` **and** in the in-game Credits screen (an "Art credits" section, generated from the `SOURCE.txt` files so it can never drift).
- **License gate:** the GUT test from Update 05 §0.2 must pass. Every file under `assets/third_party/` needs its `LICENSE.txt` and `SOURCE.txt`.
- **Git:** commit the GLBs and textures. Add `tools_src/_downloads/` to `.gitignore`. If the repo grows past ~1 GB, set up Git LFS for `*.glb` and `*.png` under `assets/` and note it in DECISIONS.

## 4. Then
Continue straight into `UPDATE_05_ART_SLICE.md` §2: normalize, add the shared weapon shader, place sight markers, run ads_check, fit animations. Because the OpenGameArt guns are flat-color low-poly, the shared weapon shader must add the detail:
- wood grain and edge wear from the CC0 texture library;
- metal bluing and scratches;
- grime, and frost in cold maps.

**Report:** in the morning report, add before/after viewmodel shots for every gun, the source of each gun model, the list of guns still on greybox, and the total size added to the repo.
