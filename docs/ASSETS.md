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
- **User-supplied assets** (Devin's own downloads: Sketchfab, Unity Asset Store, Mixamo) go in `/assets/user_supplied/<kind>/<name>/` with a `LICENSE.txt` and a `SOURCE.txt` beside them. That folder is git-ignored and is only a drop box: nothing references it. The **intake** (UPDATE 05A, T-087) copies each download out, converts it with Blender headless (`tools_src/blender/convert_to_glb.py`) into `assets/third_party/<source>/<asset-id>/` (`model.glb`, `textures/*.png`, `LICENSE.txt`, `SOURCE.txt`), and only that copy is used by scenes. Guns: `python -I tools/intake_guns.py` (table of pack files, parts and real lengths) -> `data/gravelight/weapons/models.json`, `docs/WEAPON_MODELS.md`.

### 1.3 Paperwork, generated credits and the gate (UPDATE 05, T-087)
- Every third-party folder `assets/third_party/<source>/<asset-id>/` holds `LICENSE.txt` (the licence text, or the EULA name) and `SOURCE.txt` in this format, one `Key: value` per line: `Title`, `Author`, `Source` (the page URL), `License`, `Credit line`, then `File`, `Format`, `Downloaded` (date, by whom), `Files used`, `Game use`, `Notes` as needed. `<source>` is one of opengameart, polyhaven, ambientcg, kenney, quaternius, sketchfab, unity_asset_store, mixamo, google_fonts; `<asset-id>` is lowercase-kebab.
- `python -I tools/assets_manifest.py` regenerates the **Third-party files (generated)** block below and `data/credits_art.json`; the in-game Credits screen builds its "Art credits" section from that JSON at runtime. Run it before committing an asset; never edit the generated block by hand. `--check` only reports.
- GUT: `test_license_gate` fails on any file under `assets/` (outside `assets/user_supplied/`) whose nearest `SOURCE.txt`/`LICENSE.txt` pair is missing or whose licence is not CC0, CC-BY 3.0/4.0, OFL, MIT, Apache 2.0, the Unity Asset Store EULA or "Ours"; `test_assets_manifest` fails when the generated block or the JSON is stale. Raw downloads live in `tools_src/_downloads/<name>/` (git-ignored) and are deleted once imported; nothing from an archive is ever executed.
- The `*.import` files under `assets/third_party/` are committed (an exception to the global ignore) so a fresh clone imports every third-party asset with the same presets.

### 1.4 Swap-friendly structure
Gameplay scenes never reference art directly. Each actor or prop has a `Visual` child (a subscene or a procedural builder), so an art swap never touches logic. This is the same rule as GRAVELIGHT D-025 and D-057.

## 2. Third-party files in the repo (M0)

| Path | What | Source | License | Status |
|---|---|---|---|---|
| `addons/gut/` | GUT 9.6.1 unit-test framework | github.com/bitwes/Gut | MIT (`addons/gut/LICENSE.md`) | in use (dev only, not shipped) |
| `addons/webrtc/` | webrtc-native 1.2.2-stable GDExtension (WebRTC on desktop; libdatachannel, libjuice, usrsctp, libsrtp, mbedTLS, plog) | github.com/godotengine/webrtc-native | MIT (`addons/webrtc/LICENSE.txt`; bundled: MPL-2.0 / BSD-3 / Apache-2.0 / MIT, `LICENSE.<name>.txt`) | in use (shipped, online co-op, T-138) |
| `tools/node_modules/acorn/` | acorn 8.14.0 JavaScript parser, used by the extraction tool | npmjs.com/package/acorn | MIT | dev tool, git-ignored |
| `tools/dl_godot/` | Godot 4.7.2-stable editor binary | godotengine.org | MIT | dev tool, git-ignored |

<!-- assets:begin -->
## Third-party files (generated)

Generated by `python -I tools/assets_manifest.py` from every `assets/third_party/**/SOURCE.txt`; do not edit by hand. Each folder also holds its `LICENSE.txt`. The same data drives the in-game Credits ("Art credits", from `data/credits_art.json`). Guns: `docs/WEAPON_MODELS.md`; intake flow: `tools/intake_guns.py`.

| Folder | Title | Author | Licence | Credit line | Files |
|---|---|---|---|---|---|
| `assets/third_party/ambientcg/diamond-plate-008a` | Diamond Plate 008 A | ambientCG.com (Lennart Demes) | CC0 | "Diamond Plate 008 A" from ambientCG.com, CC0. Modified: converted to 8-bit PNG, resized, AO/roughness/metal channel-packed. | 3 files, 4669 KB |
| `assets/third_party/ambientcg/fabric-031` | Fabric 031 | ambientCG.com (Lennart Demes) | CC0 | "Fabric 031" from ambientCG.com, CC0. Modified: converted to 8-bit PNG, resized, AO/roughness/metal channel-packed. | 3 files, 4769 KB |
| `assets/third_party/ambientcg/fabric-066` | Fabric 066 | ambientCG.com (Lennart Demes) | CC0 | "Fabric 066" from ambientCG.com, CC0. Modified: converted to 8-bit PNG, resized, AO/roughness/metal channel-packed. | 3 files, 6360 KB |
| `assets/third_party/ambientcg/ice-003` | Ice 003 | ambientCG.com (Lennart Demes) | CC0 | "Ice 003" from ambientCG.com, CC0. Modified: converted to 8-bit PNG, resized, AO/roughness/metal channel-packed. | 3 files, 3126 KB |
| `assets/third_party/ambientcg/leather-014` | Leather 014 | ambientCG.com (Lennart Demes) | CC0 | "Leather 014" from ambientCG.com, CC0. Modified: converted to 8-bit PNG, resized, AO/roughness/metal channel-packed. | 3 files, 4533 KB |
| `assets/third_party/ambientcg/snow-015` | Snow 015 | ambientCG.com (Lennart Demes) | CC0 | "Snow 015" from ambientCG.com, CC0. Modified: converted to 8-bit PNG, resized, AO/roughness/metal channel-packed. | 4 files, 6665 KB |
| `assets/third_party/ambientcg/wood-siding-012` | Wood Siding 012 | ambientCG.com (Lennart Demes) | CC0 | "Wood Siding 012" from ambientCG.com, CC0. Modified: converted to 8-bit PNG, resized, AO/roughness/metal channel-packed. | 4 files, 5349 KB |
| `assets/third_party/google_fonts/ibm-plex-mono` | IBM Plex Mono | Mike Abbink, Bold Monday (IBM) | OFL 1.1 | "IBM Plex Mono" by Mike Abbink and Bold Monday for IBM, licensed under the SIL Open Font License 1.1. | 3 files, 404 KB |
| `assets/third_party/google_fonts/ibm-plex-sans` | IBM Plex Sans | Mike Abbink, Bold Monday (IBM) | OFL 1.1 | "IBM Plex Sans" by Mike Abbink and Bold Monday for IBM, licensed under the SIL Open Font License 1.1. | 1 files, 525 KB |
| `assets/third_party/google_fonts/special-elite` | Special Elite | Brian J. Bonislawsky (Astigmatic) | Apache 2.0 | "Special Elite" by Astigmatic (Brian J. Bonislawsky), licensed under the Apache License 2.0. | 1 files, 162 KB |
| `assets/third_party/google_fonts/stardos-stencil` | Stardos Stencil | Vernon Adams | OFL 1.1 | "Stardos Stencil" by Vernon Adams, licensed under the SIL Open Font License 1.1. | 2 files, 74 KB |
| `assets/third_party/kenney/survival-kit` | Kenney Survival Kit | Kenney (kenney.nl) | CC0 | Assets from "Survival Kit" by Kenney (kenney.nl), CC0. | 3 files, 23 KB |
| `assets/third_party/opengameart/beach-ocean-waves` | Beach Ocean Waves | jasinski (recording, freesound.org sound 18363 "alkaibeach"); submitted to OpenGameArt by qubodup | CC0 | "Beach Ocean Waves" by jasinski (freesound / OpenGameArt, submitted by qubodup), CC0 | 4 files, 1943 KB |
| `assets/third_party/opengameart/pichuliru-cartridges` | Ultimate Low Poly Guns: Cartridges (main set) | TastyTony (gun models); Pichuliru (pack, palette, rigs) | CC-BY 4.0 | Gun models by TastyTony, pack by Pichuliru (CC-BY 4.0) | 2 files, 267 KB |
| `assets/third_party/opengameart/sea-and-river-wave-sounds` | Sea and River Wave Sounds | RandomMind | CC0 | "Sea and River Wave Sounds" by RandomMind (OpenGameArt), CC0 | 1 files, 1600 KB |
| `assets/third_party/opengameart/tt-bar-m1918` | Ultimate Low Poly Guns: BAR (World War 2 set) | TastyTony (gun models); Pichuliru (pack, palette, rigs) | CC-BY 4.0 | Gun models by TastyTony, pack by Pichuliru (CC-BY 4.0) | 2 files, 229 KB |
| `assets/third_party/opengameart/tt-double-barrel` | Ultimate Low Poly Guns: Double Barrel (main set) | TastyTony (gun models); Pichuliru (pack, palette, rigs) | CC-BY 4.0 | Gun models by TastyTony, pack by Pichuliru (CC-BY 4.0) | 2 files, 144 KB |
| `assets/third_party/opengameart/tt-gewehr-43` | Ultimate Low Poly Guns: Gewehr 43 (World War 2 set) | TastyTony (gun models); Pichuliru (pack, palette, rigs) | CC-BY 4.0 | Gun models by TastyTony, pack by Pichuliru (CC-BY 4.0) | 2 files, 132 KB |
| `assets/third_party/opengameart/tt-kar98k` | Ultimate Low Poly Guns: Kar 98K (World War 2 set) | TastyTony (gun models); Pichuliru (pack, palette, rigs) | CC-BY 4.0 | Gun models by TastyTony, pack by Pichuliru (CC-BY 4.0) | 2 files, 153 KB |
| `assets/third_party/opengameart/tt-m1-carbine` | Ultimate Low Poly Guns: M1 Carbine (World War 2 set) | TastyTony (gun models); Pichuliru (pack, palette, rigs) | CC-BY 4.0 | Gun models by TastyTony, pack by Pichuliru (CC-BY 4.0) | 2 files, 156 KB |
| `assets/third_party/opengameart/tt-m1-garand` | Ultimate Low Poly Guns: M1 Garand (World War 2 set) | TastyTony (gun models); Pichuliru (pack, palette, rigs) | CC-BY 4.0 | Gun models by TastyTony, pack by Pichuliru (CC-BY 4.0) | 2 files, 259 KB |
| `assets/third_party/opengameart/tt-m1897-trench-gun` | Ultimate Low Poly Guns: M1897 (trench gun) (World War 2 set) | TastyTony (gun models); Pichuliru (pack, palette, rigs) | CC-BY 4.0 | Gun models by TastyTony, pack by Pichuliru (CC-BY 4.0) | 2 files, 295 KB |
| `assets/third_party/opengameart/tt-m1911` | Ultimate Low Poly Guns: M1911 (World War 2 set) | TastyTony (gun models); Pichuliru (pack, palette, rigs) | CC-BY 4.0 | Gun models by TastyTony, pack by Pichuliru (CC-BY 4.0) | 2 files, 146 KB |
| `assets/third_party/opengameart/tt-mg42` | Ultimate Low Poly Guns: MG 42 (World War 2 set) | TastyTony (gun models); Pichuliru (pack, palette, rigs) | CC-BY 4.0 | Gun models by TastyTony, pack by Pichuliru (CC-BY 4.0) | 2 files, 579 KB |
| `assets/third_party/opengameart/tt-mp40` | Ultimate Low Poly Guns: MP 40 (World War 2 set) | TastyTony (gun models); Pichuliru (pack, palette, rigs) | CC-BY 4.0 | Gun models by TastyTony, pack by Pichuliru (CC-BY 4.0) | 2 files, 286 KB |
| `assets/third_party/opengameart/tt-ppsh41` | Ultimate Low Poly Guns: PPSH 41 (World War 2 set) | TastyTony (gun models); Pichuliru (pack, palette, rigs) | CC-BY 4.0 | Gun models by TastyTony, pack by Pichuliru (CC-BY 4.0) | 2 files, 260 KB |
| `assets/third_party/opengameart/tt-springfield-m1903` | Ultimate Low Poly Guns: Springfield M1903 (World War 2 set) | TastyTony (gun models); Pichuliru (pack, palette, rigs) | CC-BY 4.0 | Gun models by TastyTony, pack by Pichuliru (CC-BY 4.0) | 2 files, 105 KB |
| `assets/third_party/opengameart/tt-stg44` | Ultimate Low Poly Guns: STG 44 (World War 2 set) | TastyTony (gun models); Pichuliru (pack, palette, rigs) | CC-BY 4.0 | Gun models by TastyTony, pack by Pichuliru (CC-BY 4.0) | 2 files, 364 KB |
| `assets/third_party/opengameart/tt-thompson-m1a1` | Ultimate Low Poly Guns: M1A1 Thompson (World War 2 set) | TastyTony (gun models); Pichuliru (pack, palette, rigs) | CC-BY 4.0 | Gun models by TastyTony, pack by Pichuliru (CC-BY 4.0) | 2 files, 213 KB |
| `assets/third_party/opengameart/tt-walther-p38` | Ultimate Low Poly Guns: Walther P38 (World War 2 set) | TastyTony (gun models); Pichuliru (pack, palette, rigs) | CC-BY 4.0 | Gun models by TastyTony, pack by Pichuliru (CC-BY 4.0) | 2 files, 136 KB |
| `assets/third_party/opengameart/tt-webley-mkiv` | Ultimate Low Poly Guns: Webley MkIV (World War 2 set) | TastyTony (gun models); Pichuliru (pack, palette, rigs) | CC-BY 4.0 | Gun models by TastyTony, pack by Pichuliru (CC-BY 4.0) | 2 files, 163 KB |
| `assets/third_party/polyhaven/barrel-03` | Barrel 03 | Serhii Khromov | CC0 | "Barrel 03" by Serhii Khromov (Poly Haven), CC0. Modified: glTF packed to GLB, textures converted to PNG and resized. | 4 files, 3608 KB |
| `assets/third_party/polyhaven/barrel-stove` | Barrel Stove | MP | CC0 | "Barrel Stove" by MP (Poly Haven), CC0. Modified: glTF packed to GLB, textures converted to PNG and resized. | 4 files, 1042 KB |
| `assets/third_party/polyhaven/beige-wall-001` | Beige Wall 001 | Dimitrios Savva (Photography), Rico Cilliers (Processing) | CC0 | "Beige Wall 001" by Dimitrios Savva (Photography), Rico Cilliers (Processing) (Poly Haven), CC0. Modified: converted to 8-bit PNG, resized, AO/roughness/metal channel-packed. | 4 files, 8823 KB |
| `assets/third_party/polyhaven/brown-mud-03` | Brown Mud 03 | Rob Tuytel | CC0 | "Brown Mud 03" by Rob Tuytel (Poly Haven), CC0. Modified: converted to 8-bit PNG, resized, AO/roughness/metal channel-packed. | 3 files, 5837 KB |
| `assets/third_party/polyhaven/concrete-floor-worn-001` | Concrete Floor Worn 001 | Dimitrios Savva (Photography), Rico Cilliers (Processing) | CC0 | "Concrete Floor Worn 001" by Dimitrios Savva (Photography), Rico Cilliers (Processing) (Poly Haven), CC0. Modified: converted to 8-bit PNG, resized, AO/roughness/metal channel-packed. | 3 files, 2746 KB |
| `assets/third_party/polyhaven/concrete-wall-004` | Concrete Wall 004 | Dario Barresi (Processing), Charlotte Baglioni (Photography) | CC0 | "Concrete Wall 004" by Dario Barresi (Processing), Charlotte Baglioni (Photography) (Poly Haven), CC0. Modified: converted to 8-bit PNG, resized, AO/roughness/metal channel-packed. | 3 files, 4443 KB |
| `assets/third_party/polyhaven/corrugated-iron` | Corrugated Iron | Jenelle van Heerden (Processing), Dimitrios Savva (Photography) | CC0 | "Corrugated Iron" by Jenelle van Heerden (Processing), Dimitrios Savva (Photography) (Poly Haven), CC0. Modified: converted to 8-bit PNG, resized, AO/roughness/metal channel-packed. | 3 files, 4188 KB |
| `assets/third_party/polyhaven/dark-paneled-wood` | Dark Paneled Wood | Dimitrios Savva | CC0 | "Dark Paneled Wood" by Dimitrios Savva (Poly Haven), CC0. Modified: converted to 8-bit PNG, resized, AO/roughness/metal channel-packed. | 3 files, 4796 KB |
| `assets/third_party/polyhaven/dark-wood` | Dark Wood | Dario Barresi (Baking), Dimitrios Savva (Photography), Rico Cilliers (Tiling) | CC0 | "Dark Wood" by Dario Barresi (Baking), Dimitrios Savva (Photography), Rico Cilliers (Tiling) (Poly Haven), CC0. Modified: converted to 8-bit PNG, resized, AO/roughness/metal channel-packed. | 3 files, 3236 KB |
| `assets/third_party/polyhaven/dirty-concrete` | Dirty Concrete | Rob Tuytel | CC0 | "Dirty Concrete" by Rob Tuytel (Poly Haven), CC0. Modified: converted to 8-bit PNG, resized, AO/roughness/metal channel-packed. | 3 files, 5229 KB |
| `assets/third_party/polyhaven/green-metal-rust` | Green Metal Rust | Rob Tuytel | CC0 | "Green Metal Rust" by Rob Tuytel (Poly Haven), CC0. Modified: converted to 8-bit PNG, resized, AO/roughness/metal channel-packed. | 3 files, 2193 KB |
| `assets/third_party/polyhaven/grey-plaster` | Grey Plaster | Rob Tuytel | CC0 | "Grey Plaster" by Rob Tuytel (Poly Haven), CC0. Modified: converted to 8-bit PNG, resized, AO/roughness/metal channel-packed. | 3 files, 5643 KB |
| `assets/third_party/polyhaven/hessian-230` | Hessian 230 | colormass (Photography), Rico Cilliers (Processing) | CC0 | "Hessian 230" by colormass (Photography), Rico Cilliers (Processing) (Poly Haven), CC0. Modified: converted to 8-bit PNG, resized, AO/roughness/metal channel-packed. | 3 files, 5890 KB |
| `assets/third_party/polyhaven/jug-01` | Jug 01 | Kuutti Siitonen | CC0 | "Jug 01" by Kuutti Siitonen (Poly Haven), CC0. Modified: glTF packed to GLB, textures converted to PNG and resized. | 4 files, 662 KB |
| `assets/third_party/polyhaven/kloppenheim-02-puresky` | Kloppenheim 02 (Pure Sky) | Greg Zaal (Original), Jarod Guest (Sky edits) | CC0 | "Kloppenheim 02 (Pure Sky)" by Greg Zaal (Original), Jarod Guest (Sky edits) (Poly Haven), CC0. | 1 files, 5433 KB |
| `assets/third_party/polyhaven/lantern-01` | Lantern 01 | Rajil Jose Macatangay | CC0 | "Lantern 01" by Rajil Jose Macatangay (Poly Haven), CC0. Modified: glTF packed to GLB, textures converted to PNG and resized. | 4 files, 1216 KB |
| `assets/third_party/polyhaven/lifebuoy` | Lifebuoy | Hank Kaamura | CC0 | "Lifebuoy" by Hank Kaamura (Poly Haven), CC0. Modified: glTF packed to GLB, textures converted to PNG and resized. | 4 files, 1274 KB |
| `assets/third_party/polyhaven/metal-grate-rusty` | Metal Grate Rusty | Rob Tuytel (Processing), Dimitrios Savva (Photography) | CC0 | "Metal Grate Rusty" by Rob Tuytel (Processing), Dimitrios Savva (Photography) (Poly Haven), CC0. Modified: converted to 8-bit PNG, resized, AO/roughness/metal channel-packed. | 3 files, 5336 KB |
| `assets/third_party/polyhaven/metal-jerrycan` | Metal Jerrycan | Sean Buckley | CC0 | "Metal Jerrycan" by Sean Buckley (Poly Haven), CC0. Modified: glTF packed to GLB, textures converted to PNG and resized. | 4 files, 1292 KB |
| `assets/third_party/polyhaven/metal-plate` | Metal Plate | Rob Tuytel | CC0 | "Metal Plate" by Rob Tuytel (Poly Haven), CC0. Modified: converted to 8-bit PNG, resized, AO/roughness/metal channel-packed. | 3 files, 4833 KB |
| `assets/third_party/polyhaven/metal-toolbox` | Metal Toolbox | Mateusz Sadek | CC0 | "Metal Toolbox" by Mateusz Sadek (Poly Haven), CC0. Modified: glTF packed to GLB, textures converted to PNG and resized. | 4 files, 1213 KB |
| `assets/third_party/polyhaven/moonlit-golf` | Moonlit Golf | Greg Zaal | CC0 | "Moonlit Golf" by Greg Zaal (Poly Haven), CC0. | 1 files, 1685 KB |
| `assets/third_party/polyhaven/old-bed-frame` | Old Bed Frame | Luca B | CC0 | "Old Bed Frame" by Luca B (Poly Haven), CC0. Modified: glTF packed to GLB, textures converted to PNG and resized. | 4 files, 4783 KB |
| `assets/third_party/polyhaven/painted-wooden-bench` | Painted Wooden Bench | Kirill Sannikov | CC0 | "Painted Wooden Bench" by Kirill Sannikov (Poly Haven), CC0. Modified: glTF packed to GLB, textures converted to PNG and resized. | 4 files, 4082 KB |
| `assets/third_party/polyhaven/painted-wooden-chair-02` | Painted Wooden Chair 02 | Kirill Sannikov | CC0 | "Painted Wooden Chair 02" by Kirill Sannikov (Poly Haven), CC0. Modified: glTF packed to GLB, textures converted to PNG and resized. | 4 files, 1221 KB |
| `assets/third_party/polyhaven/painted-wooden-nightstand` | Painted Wooden Nightstand | Kirill Sannikov | CC0 | "Painted Wooden Nightstand" by Kirill Sannikov (Poly Haven), CC0. Modified: glTF packed to GLB, textures converted to PNG and resized. | 4 files, 1088 KB |
| `assets/third_party/polyhaven/pine-bark` | Pine Bark | Dimitrios Savva | CC0 | "Pine Bark" by Dimitrios Savva (Poly Haven), CC0. Modified: converted to 8-bit PNG, resized, AO/roughness/metal channel-packed. | 3 files, 5355 KB |
| `assets/third_party/polyhaven/plastered-stone-wall` | Plastered Stone Wall | Rob Tuytel | CC0 | "Plastered Stone Wall" by Rob Tuytel (Poly Haven), CC0. Modified: converted to 8-bit PNG, resized, AO/roughness/metal channel-packed. | 4 files, 14693 KB |
| `assets/third_party/polyhaven/portable-welding-cart` | Portable Welding Cart | Georgii Gorbunov | CC0 | "Portable Welding Cart" by Georgii Gorbunov (Poly Haven), CC0. Modified: glTF packed to GLB, textures converted to PNG and resized. | 4 files, 1204 KB |
| `assets/third_party/polyhaven/propane-tank` | Propane Tank | Slinc | CC0 | "Propane Tank" by Slinc (Poly Haven), CC0. Modified: glTF packed to GLB, textures converted to PNG and resized. | 4 files, 1174 KB |
| `assets/third_party/polyhaven/red-brick-03` | Red Brick 03 | Rob Tuytel | CC0 | "Red Brick 03" by Rob Tuytel (Poly Haven), CC0. Modified: converted to 8-bit PNG, resized, AO/roughness/metal channel-packed. | 3 files, 5489 KB |
| `assets/third_party/polyhaven/reed-roof-04` | Reed Roof 04 | Rob Tuytel | CC0 | "Reed Roof 04" by Rob Tuytel (Poly Haven), CC0. Modified: converted to 8-bit PNG, resized, AO/roughness/metal channel-packed. | 3 files, 6210 KB |
| `assets/third_party/polyhaven/rock-boulder-dry` | Rock Boulder Dry | Dimitrios Savva (Photography), Rico Cilliers (Processing) | CC0 | "Rock Boulder Dry" by Dimitrios Savva (Photography), Rico Cilliers (Processing) (Poly Haven), CC0. Modified: converted to 8-bit PNG, resized, AO/roughness/metal channel-packed. | 3 files, 4879 KB |
| `assets/third_party/polyhaven/round-wooden-table-01` | Round Wooden Table 01 | Ulan Cabanilla | CC0 | "Round Wooden Table 01" by Ulan Cabanilla (Poly Haven), CC0. Modified: glTF packed to GLB, textures converted to PNG and resized. | 4 files, 1895 KB |
| `assets/third_party/polyhaven/rusted-spade-01` | Rusted Spade 01 | Blemonade | CC0 | "Rusted Spade 01" by Blemonade (Poly Haven), CC0. Modified: glTF packed to GLB, textures converted to PNG and resized. | 4 files, 1199 KB |
| `assets/third_party/polyhaven/rustic-stone-wall` | Rustic Stone Wall | Dimitrios Savva | CC0 | "Rustic Stone Wall" by Dimitrios Savva (Poly Haven), CC0. Modified: converted to 8-bit PNG, resized, AO/roughness/metal channel-packed. | 3 files, 5405 KB |
| `assets/third_party/polyhaven/rusty-metal-04` | Rusty Metal 04 | Amal Kumar | CC0 | "Rusty Metal 04" by Amal Kumar (Poly Haven), CC0. Modified: converted to 8-bit PNG, resized, AO/roughness/metal channel-packed. | 3 files, 5201 KB |
| `assets/third_party/polyhaven/rusty-painted-metal` | Rusty Painted Metal | Amal Kumar | CC0 | "Rusty Painted Metal" by Amal Kumar (Poly Haven), CC0. Modified: converted to 8-bit PNG, resized, AO/roughness/metal channel-packed. | 3 files, 2934 KB |
| `assets/third_party/polyhaven/snow-01` | Snow 01 | Rob Tuytel | CC0 | "Snow 01" by Rob Tuytel (Poly Haven), CC0. Modified: converted to 8-bit PNG, resized, AO/roughness/metal channel-packed. | 3 files, 15125 KB |
| `assets/third_party/polyhaven/stone-floor` | Stone Floor | Dimitrios Savva | CC0 | "Stone Floor" by Dimitrios Savva (Poly Haven), CC0. Modified: converted to 8-bit PNG, resized, AO/roughness/metal channel-packed. | 3 files, 5082 KB |
| `assets/third_party/polyhaven/stone-wall` | Stone Wall | Dario Barresi (Processing), Charlotte Baglioni (Photography) | CC0 | "Stone Wall" by Dario Barresi (Processing), Charlotte Baglioni (Photography) (Poly Haven), CC0. Modified: converted to 8-bit PNG, resized, AO/roughness/metal channel-packed. | 4 files, 5423 KB |
| `assets/third_party/polyhaven/tree-stump-01` | Tree Stump 01 | Rob Tuytel | CC0 | "Tree Stump 01" by Rob Tuytel (Poly Haven), CC0. Modified: glTF packed to GLB, textures converted to PNG and resized. | 4 files, 5789 KB |
| `assets/third_party/polyhaven/vintage-oil-lamp` | Vintage Oil Lamp | Monsta3D | CC0 | "Vintage Oil Lamp" by Monsta3D (Poly Haven), CC0. Modified: glTF packed to GLB, textures converted to PNG and resized. | 8 files, 1107 KB |
| `assets/third_party/polyhaven/vintage-suitcase` | Vintage Suitcase | Maximilian Schuster | CC0 | "Vintage Suitcase" by Maximilian Schuster (Poly Haven), CC0. Modified: glTF packed to GLB, textures converted to PNG and resized. | 7 files, 2213 KB |
| `assets/third_party/polyhaven/weathered-brown-planks` | Weathered Brown Planks | Dimitrios Savva (Photography), Rico Cilliers (Processing) | CC0 | "Weathered Brown Planks" by Dimitrios Savva (Photography), Rico Cilliers (Processing) (Poly Haven), CC0. Modified: converted to 8-bit PNG, resized, AO/roughness/metal channel-packed. | 4 files, 12781 KB |
| `assets/third_party/polyhaven/wine-barrel-01` | Wine Barrel 01 | James Ray Cock | CC0 | "Wine Barrel 01" by James Ray Cock (Poly Haven), CC0. Modified: glTF packed to GLB, textures converted to PNG and resized. | 4 files, 3320 KB |
| `assets/third_party/polyhaven/wine-bottles-01` | Wine Bottles 01 | Rico Cilliers (modeling), Jurita Burger (graphic design) | CC0 | "Wine Bottles 01" by Rico Cilliers (modeling), Jurita Burger (graphic design) (Poly Haven), CC0. Modified: glTF packed to GLB, textures converted to PNG and resized. | 13 files, 1614 KB |
| `assets/third_party/polyhaven/wood-floor-worn` | Wood Floor Worn | Dimitrios Savva | CC0 | "Wood Floor Worn" by Dimitrios Savva (Poly Haven), CC0. Modified: converted to 8-bit PNG, resized, AO/roughness/metal channel-packed. | 4 files, 12396 KB |
| `assets/third_party/polyhaven/wood-table-001` | Wood Table 001 | Dimitrios Savva (Photography), Rico Cilliers (Processing) | CC0 | "Wood Table 001" by Dimitrios Savva (Photography), Rico Cilliers (Processing) (Poly Haven), CC0. Modified: converted to 8-bit PNG, resized, AO/roughness/metal channel-packed. | 3 files, 2570 KB |
| `assets/third_party/polyhaven/wooden-axe-03` | Wooden Axe 03 | Ulan Cabanilla | CC0 | "Wooden Axe 03" by Ulan Cabanilla (Poly Haven), CC0. Modified: glTF packed to GLB, textures converted to PNG and resized. | 4 files, 1213 KB |
| `assets/third_party/polyhaven/wooden-bucket-01` | Wooden Bucket 01 | James Ray Cock | CC0 | "Wooden Bucket 01" by James Ray Cock (Poly Haven), CC0. Modified: glTF packed to GLB, textures converted to PNG and resized. | 4 files, 1211 KB |
| `assets/third_party/polyhaven/wooden-crate-01` | Wooden Crate 01 | James Ray Cock | CC0 | "Wooden Crate 01" by James Ray Cock (Poly Haven), CC0. Modified: glTF packed to GLB, textures converted to PNG and resized. | 4 files, 4339 KB |
| `assets/third_party/polyhaven/wooden-crate-02` | Wooden Crate 02 | James Ray Cock (modeling), Jurita Burger (graphic design) | CC0 | "Wooden Crate 02" by James Ray Cock (modeling), Jurita Burger (graphic design) (Poly Haven), CC0. Modified: glTF packed to GLB, textures converted to PNG and resized. | 4 files, 4240 KB |
| `assets/third_party/polyhaven/wooden-lantern-01` | Wooden Lantern 01 | James Ray Cock | CC0 | "Wooden Lantern 01" by James Ray Cock (Poly Haven), CC0. Modified: glTF packed to GLB, textures converted to PNG and resized. | 7 files, 1999 KB |
| `assets/third_party/polyhaven/wooden-military-crate` | Wooden Military Crate | Prabhjinder Singh | CC0 | "Wooden Military Crate" by Prabhjinder Singh (Poly Haven), CC0. Modified: glTF packed to GLB, textures converted to PNG and resized. | 4 files, 4732 KB |
| `assets/third_party/polyhaven/wooden-stool-01` | Wooden Stool 01 | Kuutti Siitonen | CC0 | "Wooden Stool 01" by Kuutti Siitonen (Poly Haven), CC0. Modified: glTF packed to GLB, textures converted to PNG and resized. | 4 files, 1170 KB |
| `assets/third_party/polyhaven/wooden-table-02` | Wooden Table 02 | Serhii Khromov | CC0 | "Wooden Table 02" by Serhii Khromov (Poly Haven), CC0. Modified: glTF packed to GLB, textures converted to PNG and resized. | 4 files, 3151 KB |
| `assets/third_party/sketchfab/kar98k-dsamuta` | Kar98k Free Model | Danya (@dsamuta) | CC-BY 4.0 | "Kar98k Free Model" by Danya (https://sketchfab.com/3d-models/kar98k-free-model-e88c90c8e203401fa28e8f4ef03e657f), licensed under CC-BY 4.0. Modified. | 16 files, 38175 KB |
| `assets/third_party/sketchfab/m1-garand-sky-hunter` | M1 Garand ( US Rifle, Caliber .30, M1) | Sky_Hunter (@Sky_Hunter) | CC-BY 4.0 | "M1 Garand ( US Rifle, Caliber .30, M1)" by Sky_Hunter (https://sketchfab.com/3d-models/m1-garand-us-rifle-caliber-30-m1-1be4bb0f8c05423abdccb50b779de6e6), licensed under CC-BY 4.0. Modified. | 7 files, 12728 KB |
| `assets/third_party/sketchfab/thompson-artem-goyko` | Thompson submachine gun | Artem Goyko (@Artem.Goyko) | CC-BY 4.0 | "Thompson submachine gun" by Artem Goyko (https://sketchfab.com/3d-models/thompson-submachine-gun-5fe11dfebf734b4aa49c43545397abd1), licensed under CC-BY 4.0. Modified. | 37 files, 22640 KB |

91 third-party folders, 354537 KB in all.
<!-- assets:end -->

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
