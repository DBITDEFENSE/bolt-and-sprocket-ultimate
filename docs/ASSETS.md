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
| Voice | Placeholder text-to-speech using the operating system's installed voices at runtime. No voice files ship | Recorded VO will replace it per line ID |

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
