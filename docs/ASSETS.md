# TERMS & CONDITIONS: Asset manifest

Every third-party file in the project is listed here with its source and license. A file without a row here does not ship. M0 contains no third-party art or audio at all: everything visible or audible is procedural or original.

## 1. Policy

### 1.1 Allowed licenses
| License | Allowed? | Conditions |
|---|---|---|
| CC0 / Public Domain | ✅ | None. Credit anyway as a courtesy. |
| CC-BY 3.0/4.0 | ✅ | Attribution in the credits and in this file, with the exact author string. |
| CC-BY-SA | ⚠️ Avoid | Share-alike can reach derived assets. Needs sign-off logged in DECISIONS.md. |
| CC-BY-NC / any NC | ❌ | Non-commercial. Never. |
| SIL OFL 1.1 (fonts) | ✅ | Keep the license text beside the font. Don't sell the font by itself. |
| MIT / Apache 2.0 (code, fonts) | ✅ | Keep the license (and NOTICE for Apache). |
| Mixamo (Adobe) | ✅ with care | Royalty-free in games. Never redistribute the raw FBX on its own. |
| Sonniss GDC bundles | ✅ | Royalty-free, commercial. Raw files can't be redistributed on their own. |
| Kenney, Quaternius, Poly Haven, ambientCG | ✅ | CC0. |
| Freesound | ✅ only CC0 (or CC-BY with attribution) | Re-check the license on each sound page. |
| "Free for personal use", unknown, ripped, AI-generated from unknown sources, or anything from a commercial game | ❌ | Never. |

### 1.2 Hard rules
- **Nothing from Ratchet & Clank, Call of Duty or any other commercial game:** no assets, audio, names, characters, logos or lore. That includes "lookalike" assets whose description names a commercial game or character.
- **Owning a game does not license its files.** Never extract assets from installed games.
- **User-supplied assets** go in `/assets/user_supplied/`, each with a `LICENSE.txt` or `<file>.license.txt` beside it saying where it came from and under what terms. The lead reviews each one before it's referenced from a scene.

### 1.3 Swap-friendly structure
Gameplay scenes never reference art directly. Each actor or prop has a `Visual` child (a subscene or a procedural builder), so an art swap never touches logic. This is the same rule as GRAVELIGHT D-025 and D-057.

## 2. Third-party files in the repo (M0)

| Path | What | Source | License | Status |
|---|---|---|---|---|
| `addons/gut/` | GUT 9.6.1 unit-test framework | github.com/bitwes/Gut | MIT (`addons/gut/LICENSE.md`) | in use (dev only, not shipped) |
| `tools/node_modules/acorn/` | acorn 8.14.0 JavaScript parser, used by the extraction tool | npmjs.com/package/acorn | MIT | dev tool, git-ignored |
| `tools/dl_godot/` | Godot 4.7.2-stable editor binary | godotengine.org | MIT | dev tool, git-ignored |

## 3. Original content (owned)

| Path | What | Origin |
|---|---|---|
| `reference/bs_web/index.html`, `HUMOR-REVIEW.md` | The original Bolt & Sprocket web build v14 and the unwired joke pack | Ours. Read-only reference copies; the original folder is untouched |
| `data/bs_source/*.json` | Tables extracted from the web build | Ours, derived |
| `data/bs/story/*.json` | Every written line of Bolt & Sprocket, plus the remake additions | Ours |
| `docs/gravelight/*`, `docs/fineprint/*`, `docs/JINGLES.md` | Gravelight and Fine Print writing, perk jingles and lyrics | Ours |
| `icon.svg` | Project icon | Ours (from GRAVELIGHT) |
| Voice (`gravelight/audio/vo/<speaker>/<id>.ogg`) | Placeholder voice files baked offline by `gravelight/tools_src/gen_vo.py` (T-035): every line of `data/gravelight/vo/lines.json` spoken by the Windows offline OneCore text-to-speech voices (Microsoft David, Mark, Zira), then processed with our own numpy/scipy DSP (per-speaker pitch/formant shift, EQ, the Operator's tannoy / Fasbender's radio / phonograph channels), encoded to Ogg Vorbis with ffmpeg. Manifest with text hashes: `data/gravelight/vo/audio_manifest.json`. | **Source:** Windows TTS output of our own original script text (the voices ship with Windows; Microsoft's terms allow use of the synthesized audio in applications, and no Microsoft voice data or binaries are redistributed, only our rendered lines). **License:** the renders are our own derived work of our own script. **Status:** placeholder, to be replaced per line ID by recorded VO; the files are regenerated, never hand-edited. |
| Voice: the squad, Jakub and the Map 0 patrons (`dut`, `peg`, `dea`, `wrn`, `jak`, `rot`, `kub`, `poh`, `tru`, `sob`; T-073) | Re-baked by the same `gen_vo.py` with **Kokoro-82M** v1.0 (offline neural TTS, ONNX on the CPU through kokoro-onnx), cast per character in `data/gravelight/vo/voice_cast.json` (blended Kokoro voice styles, misaki US/GB lexicons, eSpeak NG Polish phonemes, a delivery per category), loudness-normalised (BS.1770) with our own DSP. Setup: `tools/setup_tts.sh` (project-local venv + model, git-ignored). See `docs/gravelight/VOICES.md`. | **Source:** our own script text rendered by Kokoro-82M (weights and voice styles **Apache-2.0**, hexgrad), kokoro-onnx (MIT), onnxruntime (MIT), misaki lexicons (Apache-2.0); eSpeak NG (GPL-3.0) is used only as a build-time phonemizer and nothing of it ships. **License:** the renders are our own output; Apache-2.0 places no restriction on generated audio. **Status:** placeholder, to be replaced per line ID by recorded VO; regenerated, never hand-edited. |

## 4. The Gravelight module's assets
When the GRAVELIGHT code moves in (M2, DECISIONS T-007), its manifest comes with it as section 5 of this file. Everything it currently ships is original or procedural:
- procedural weapon and zombie models, hands and maps
- synthesized audio from `tools_src/gen_sfx.gd`, `gen_audio.py` and the music generator

Its recommended-source tables (characters, props, textures, audio) stay valid for the M10 art pass. Source manifest: `C:\Users\Devin\PROJECTS\New folder\docs\ASSETS.md`.

## 5. Recommended sources for the M10 art and audio pass

| Source | URL | Best for | License |
|---|---|---|---|
| Kenney | kenney.nl | Prototype props, UI packs, input prompts, impact sounds | CC0 |
| Quaternius | quaternius.com | Stylized characters and robots (B&S), low-poly props, animated creatures | CC0 |
| Poly Haven | polyhaven.com | HDRIs, PBR textures, scanned props (Gravelight, Basel) | CC0 |
| ambientCG | ambientcg.com | PBR materials: metal, rust, snow, concrete, marble (Foundry lobby), salt rock | CC0 |
| Mixamo | mixamo.com | Humanoid animation bases (Gravelight squad, zombies, Vendelin's walk retargeted) | Adobe royalty-free |
| Freesound (CC0 filter) | freesound.org | Foley, machinery, bells, organ, radio static, Rhine harbor ambience | CC0 |
| Sonniss GDC bundles | sonniss.com/gameaudiogdc | Weapons, explosions, sci-fi impacts | Sonniss license |
| Google Fonts | fonts.google.com | UI fonts: a bright rounded display face for B&S, a period stencil/typewriter face for Gravelight, a Swiss-poster grotesque for The Fine Print | OFL / Apache |
| Original work | in-house | All characters' designs, perk jingles, songs, ad vignettes, logos (OmniScrap™, Darkmatter, Helvetia Automaten AG) | Owned |

## 6. Per-world art direction (for M10)
- **Bolt & Sprocket:** bright and stylized, orange and cyan, with rim light. The original's per-planet palettes (`LEVELS[].palette`) and `THEMES` are the reference.
- **Gravelight:** desaturated grit; Nachtglas is the only saturated color (violet `#c07dff` with amber cracks).
- **The Fine Print:** 1940s Swiss-poster Basel (flat color fields, grotesque type) against sterile Darkmatter violet interiors.

## GRAVELIGHT module (migrated M2)
Everything under `gravelight/assets` and `gravelight/audio` is original procedural or synthesized work from the GRAVELIGHT project (see its own docs/ASSETS.md in `docs/gravelight/`). No third-party assets.

### Map 0 art pass (cellar, staircase, pictures)
All code-built, nothing downloaded (`gravelight/world/materials.gd` `_build_map0`, `gravelight/world/props.gd` Map 0 section, `gravelight/tools_src/gen_map00.gd`):
- **Stone shader** (`cellar_stone`, `cellar_floor`, `limewash`): world-space coursed rubble / flagstones with ragged joints, a damp band above the floor and wet patches. `brick_cellar` reuses the Map 1 brick shader with cellar tones.
- **Painting shader** (`painting:<style>:<n>`): the framed pictures are procedural canvases (landscape, bust portrait without a face, hunting print with a stag, faded group photograph of figure silhouettes, inn licence, still life) built from gradients, value noise and simple shapes, then aged. No real people, places or logos; the "inn licence" text is bars, not words.
- Cellar props (barrels, preserves shelves, wine rack, coal chute, pendant bulbs, cobwebs, puddles, workbench, Helvetia Automaten AG crates) and the stair furniture (newels, balusters, runner with brass rods, sloped wainscot) are primitives with the library's triplanar materials.

### Starting pistol and the Requisition Crate (art pass)
All code-built (`gravelight/weapons/weapon_models.gd`, `gravelight/world/crate_art.gd`, `gravelight/world/mystery_crate.gd`):
- **M1911 viewmodel**: a 1911-pattern service pistol built at real scale from cross-section extrusions (`xsec`) and profiles. Two-tone parkerized phosphate materials (`park_slide` / `park_frame`, noise-mottled) and checkered walnut grips (`wood_check`: the walnut grain multiplied by a procedural diamond-checker tile, `_checker_tex`). The only marking is an invented arsenal stamp (dash bars and a proof ring), no maker's names.
- **Lost Requisition Crate**: an original ordnance crate on skids (horizontal planks over a dark shell, iron corner brackets and straps with rivets, rope handles, a hasp under a wax seal, an invented "LOS 44-117" stencil, a Helvetia Automaten AG brass plate, a chalk sigil); a planked lid on strap hinges that stands up as a backdrop, its underside lined and cracked with Nachtglas veins; violet light motes (CPUParticles3D) while open. Each spot has a lantern on a hooked iron stake (lit only where the crate is) and a chalk footprint on the floor. No "?" glyph, no teddy bear, nothing from any commercial game.

### Map 2 Totenhafen (first playable, T-036)
All code-built, nothing downloaded (`gravelight/world/materials.gd` `_build_map2`, `gravelight/world/props.gd` Map 2 section, `gravelight/tools_src/gen_map02.gd`):
- **Sea shader** (`sea_water`): a subdivided plane heaved in the vertex shader by three crossing wind-chop waves, dark green-black water with a cold fresnel sheen and foam streaks on the crests. The tide controller only moves the plane.
- Materials: shuttered bunker concrete with damp streaks, wet quay concrete, tide-stained pier faces, the boat's anti-fouling and red-lead hull, grey-green pressure-hull paint, lead (the sealed coffins), hemp rope, matted nets, zinc, the high-water slime band, bladderwrack, shingle, the headland rock, crane yellow.
- Props: bollards, lead coffins on pallets (Helvetia plate, an invented unit stencil, a violet seam), rope coils, life rings, torpedoes on trestles, net heaps, ladders, can stacks, valve wheels, sea grilles, railings, bulkhead lamps. The U-boat is cylinders, cones and plates; the "U 1047" and every stencil are invented. No real boat, port, unit or person is depicted.

### MZ, the zombie animation and design upgrade (built, T-041)
Nothing is imported: every animation, body, kit and shader is generated in-engine (`gravelight/enemies/zombie_rig.gd`, `zombie_clips.gd`, `zombie_body.gd`):
- **Rig:** a hand-defined `Skeleton3D` named after Godot's `SkeletonProfileHumanoid` with a `BoneMap` (ours; the profile and BoneMap are engine resources, MIT).
- **Animation clips (ours):** 70-odd procedural pose functions sampled at 30 Hz into `Animation` resources (locomotion per tier with lean variants, turns, tears, vaults, emerges, climb, attacks, reactions, deaths, posture traits, flinches). No Mixamo, no CC0 pack, nothing from any game. If a licensed pack is ever retargeted onto the rig, its row goes here first.
- **Bodies and kits (ours):** cylinder / sphere / box primitives skinned to the rig; kits soldier, villager, miner, labstaff, technician, sailor, dockworker, bellringer, nurse and the gear pieces. Marks per `ART_FACTIONS.md` only (the technician armband carries a plain light plate, no symbol). The `laborer` kit is retired.
- **Shaders (ours):** the Nachtglas infection skin shader (noise, ridged-noise cracks, cellular veins, dirt / frost / char / fuel / dissolve instance uniforms) and the vertex-colour kit shader.
- **Legacy:** `gravelight/tools_src/legacy_zombie_body.gd` / `legacy_zombie_dummy.gd` are copies of the pre-MZ body and pose code kept only for the before/after capture (`shots_zombie_anim.tscn`).

### Morgenrot (design stage, v2)
Nothing of the map is built yet. Rules for when it is: the faction mark is the fictional Sunburst-and-Split-Bell (`docs/ART_FACTIONS.md`); no real insignia, no real manufacturer names on the rocket, the Panzerfaust, the lance rifle or the Fallschirm-pattern rifle (all three are invented patterns); rocket surfaces use a black-and-white roll pattern "in spirit". The lunar plates, the Moon shots and the London / Antwerp / Paris skylines are procedural (no photographs).

### Homage bosses: the Cousins, PAUL, the Slender (design stage, v3; HB1–HB3, `docs/HOMAGE_BOSSES.md`)
Nothing is built yet. Rules for when it is:
- **Real people, so consent comes first.** The bosses are homages to real people (Devin's cousins, his friend Paul, Devin).
  - The models are **stylized, procedural MZ bodies** (`zombie_body.gd` kits plus boss extras), never photoreal.
  - **No photo, face scan or likeness reference** is used unless it sits in `assets/user_supplied/likeness/` with a `CONSENT.txt` note saying that person agreed. Today that folder doesn't exist, so nothing is used, and `likeness.json` has `consent.photo_scans_allowed: false`.
  - **No real person's voice** is recorded, sampled or imitated without the same written consent. The lines ship as the usual placeholder TTS (T-009, T-035).
- **The look comes from the Likeness Sheet** (`data/gravelight/bosses/likeness.json`): hair, build, signature items. No real body feature is exaggerated for a joke. The Cousins are young women in modest period clothing, never sexualized: the camera and pose rules are in HOMAGE_BOSSES §1.2.
- **Originality:**
  - the Slender is not the internet "Slender Man": he has a face, a grey watchman's greatcoat and a cap, two arms (HOMAGE_BOSSES §6.2);
  - Paul is not Marvel's Hulk: iron-red skin, no green, no purple trousers;
  - the Cousins' rhyme ("Drei Kusinen") and every boss cue are original;
  - Paul's death phrase is an original bugle-like line, not "Taps".
- **Ours, procedural:**
  - the rigs: the MZ humanoid plus appended bones (telescoping arms, the torso arm chain, the bottle rack, coat chains);
  - every boss clip;
  - the Kinderhammer, the Ironhide bottles (the existing Helvetia label art), the brass lantern, the key ring, the watch-book, the Watch Room set, the ice-cellar room and its chalk drawings, the handprint decal, the title-card stamp (the HUD round stamp's font);
  - the charms and calling cards ("Three Ribbons", "Violet Lantern", "The Game Is Over", "Carried My Share", "Night Shift").
  - Unit insignia on Paul's sleeve stay a worn, unreadable patch shape until `[PAUL_UNIT]` is decided. A real US unit patch is a period fact, not a brand, but it is drawn by hand, never traced.

## Bolt & Sprocket: Verdant Sink (first playable, T-039)
- All original procedural greybox-plus (LevelKit / EnemyFx primitives): the boardwalk hub, the silo-barn, the root ridges and giant mushroom caps (four glow colours), the Mega-Harvester shell with its cab and guts, the lagoon's root walls and reactor collar, glow-vines, picket signs, frog-bots, firefly fields. Palette: dark teal fog (35–150 m), bioluminescent emissives (`#5affc8`, `#ff6ad5`, `#4fc3ff`, `#ffd23e`, coolant `#39ff88`).
- Enemies and the King are greybox meshes with emissive eyes/bulb/core; the Glide's sail is a husk-silk box with two ribs and lines.
- For the M10 pass: cap and stalk textures, murk shader, coolant jet particles, the sail cloth, corn husks, the King's moss and junk crown; voiced lines for `bs.verdant.*`, `bs.boss.compost.*`, `bs.gadget.glide.*` (none baked yet).
