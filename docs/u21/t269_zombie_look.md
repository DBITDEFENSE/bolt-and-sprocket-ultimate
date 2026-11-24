# T-269: the zombies look like zombies

The owner: "what the zombies are wearing, they need to have more color. Right now they're all just gray ... They walk
like zombies and stuff, but they need to look like zombies now."

Branch `claude/zombie-look`. Renders in `docs/captures/t269/` (`before/` is master's zombie code, `after/` this
branch; same tool, same cameras, same seed). All renders were made under WSL + Xvfb on Forward+ (Vulkan on lavapipe),
never in a window on the PC.

## 1. Why they read grey

Measured, not guessed. Four causes, in order of weight:

1. **The clothes were grey in the data.** `ZombieBody.KIT_CLOTH` gave every kit two cloth colours and all fourteen of
   them were greys: as display colours their mean saturation is **0.096** (soldier 0.09 / 0.05, villager 0.17 / 0.03,
   lab staff 0.03 / 0.04, technician 0.02 / 0.04, dock worker 0.10 / 0.09; only the sailor's navy reached 0.25). The
   colour was baked into the mesh per kit, so every soldier was the same swatch; the only variation was a +-8 % tint.
2. **The skin was grey too, and had no face.** The kits' skin tones are cool greys (display saturation about 0.05)
   over a painted map that is itself neutral grey. In the taproom render a walker's face is a pale blank.
3. **The map's grade takes half of what colour there is.** `data/look/<map>.json` runs a LUT with `mono` 0.45 to 0.70
   on every map (Map 0: 0.5, Groom Lake 0.7, the Moon 1.0) that fades everything toward grey except Nachtglas violet
   and blood red, then a split tone. That is the art bible's "30 % saturation box" and it is right for walls; it
   turns a cloth of saturation 0.1 into nothing.
4. **Outside at night they were black.** In the yard the moon is the only light; a walker seen against it was a
   silhouette (mean brightness of the crowd's pixels 0.065 of 1, median saturation 0.000). Colour cannot read on
   something that is not lit.

On Map 0 a fifth: the default variant table made **six in ten walkers soldiers**, in one uniform.

What it was not: there is no desaturation term in the zombie shaders, the two materials are shared by design (and
stay shared), and the lamps are not at fault indoors (the taproom's lamps light them well; they were simply cream
figures in cream light).

## 2. What changed

### The wardrobe (data/gravelight/zombie_wardrobe.json)

An outfit is three colours and an optional pattern: `a` the kit's main cloth, `b` its second cloth, `c` the accent
(scarf, shawl, cap, hood, oilskin). 49 outfits, per map and kit a weighted table (`maps.<map>.<kit>`, falling back to
`maps.default.<kit>`), so the mix is tuned in data. Period cloth colours that survive the grade: madder red, ochre,
mustard, forest and bottle green, indigo and workwear blue, rust, plum, cream and off-white, brown leather, with a
few loud accents (a red scarf, a yellow oilskin, a striped shirt, a dotted dress).

| Map | Who walks there now |
|---|---|
| Crossroads (inn, village) | villagers 50 % (was 20 %): farmhands in ochre, blue and red check, the cook, the barmaid (dotted), the postman in indigo with a mustard cap, the priest in black with a pale stole, a railwayman, a hunter in forest green, Sunday plum / bottle green / a red dotted dress, striped nightshirts, a mustard jacket; soldiers 32 % (was 60 %) in an invented field green in four states (issue, faded, greatcoat, shirtsleeves); miners 12 % in ochre and rust; lab staff 6 % |
| Kaltenbrunn (mine town) | miners in ochre, rust, blue drill and mustard overalls, overseers in shirt and waistcoat; technicians in blue / rust / mustard / olive coveralls; lab coats white, pale green, stained, pale blue; soldiers |
| Totenhafen (harbour) | sailors in navy, in yellow and orange oilskins, in striped shirts, in whites; dockers and fishermen in madder, green, indigo, cream and mustard wool under yellow / orange oilskin; soldiers |
| Thalbach (the Werk) | factory hands in coveralls, townspeople (the village wardrobe), the guard |
| Kranich (the flight) | ground crew in blue / mustard / olive coveralls, flight crew in brown leather and blue with a pale scarf; soldiers |
| Groom Lake (test site) | lab coats, coveralls bleached mustard / blue / rust; soldiers; a few townspeople |
| Mondlicht (the Moon) | pressure suits pale, tan and dark; lab coats. The variant table is new (the default one put villagers and miners on the Moon). **The map's grade is black and white by rule** (`mono` 1.0, violet the only colour), so here the outfits differ in value, not hue: that rule is the art bible's and was not touched |

Uniforms carry no insignia; nothing here adds an emblem, a brand or a real unit's colours. Nobody is sexualised:
an outfit is a colour set on the existing kits. Jakub and the named people are not in the wardrobe (below).

### How a colour gets onto a zombie without costing anything

- The body is still one mesh per kit / build / sex with two surfaces on two shared materials. `_merge_glb` now writes
  a **colour slot** per clothes vertex into `CUSTOM0.a` (detail class + 8 x slot; 1 = `a`, 2 = `b`, 3 = `c`, 0 = the
  part keeps its own colour: boots, belts, buttons, the face) and the vertex's baked AO into `COLOR.a`.
- The kit shader takes the slot's colour from **per-instance parameters** (`instance uniform`): `inst_cloth`,
  `inst_cloth2`, `inst_accent`, `inst_pattern` (stripes / check / dots, drawn on the rest position so they stay on
  the cloth), `inst_wear` (blood, layout). With the parameters at their defaults the shader draws the old baked
  colour, so everything that does not set them is unchanged: the living people, the relief squads, the named risen,
  the drowned, the menu's and the reels' figures.
- The instance-uniform slots of the two shaders are now explicit (`instance_index`): one instance has one parameter
  buffer for both surfaces.
- **Gear** (cap, scarf, hood, oilskin, helmet, lamp cap ...) was one StandardMaterial3D surface per material key.
  For walkers `ZombieBody.zombie_gear_mesh` merges a piece into **one surface on the kit material**: it takes the
  outfit's colours (the scarf is the accent, the oilskin too) and is one draw call instead of one to three. The
  armband's textured mark stays its own surface. `gear_mesh` itself is unchanged for its other users.
- Which outfit: `ZombieWardrobe.look_seed(net_id, max_hp)`, an integer hash of the pool slot and the spawn health.

### Dead skin (the skin shader, the same instance mechanism)

- `inst_skin` / `inst_mottle`: four skins, weighted in data: pallid (waxy), grey-green, bruised purple, ashen; each
  a tone and a blotch colour over the existing painted map.
- Dark veins under the skin along the same cells the Nachtglas veins glow on; sunken dark sockets and mouth, and
  blood on the mouth and the hands, from the painted map's existing alpha (it already marked eyes, mouth and hands).
- Dried blood on the clothes, thickest down the chest, a different layout per zombie.
- The eyes keep the Nachtglas violet the project already had; nothing new glows.
- Not done: torn cloth (it needs geometry or an alpha cut; the stains and the dirt carry "worn").

### Light on the figures (the zombie materials only; no map light was changed)

`light.min_light` (a walker shows 11 % of its own colour with no light on it at all; divided by the map's
exposure, so the floor looks the same on a map graded at 1.7 as on Map 0) and `light.rim` (a soft edge
light tinted by the cloth or skin under it). Both live in the two zombie materials; `-- --zombie-look=norim` switches
them off for an A/B, `-- --zombie-look=off` the whole look.

### Standing rime

Map 0's walkers carried 10 to 45 % frost, tuned when the cloth was pale and it did not show. On a colour it reads as
white mould, so a dressed walker keeps `wear.frost_scale` (0.45) of the map's standing rime. A weapon's freeze is
not scaled.

## 3. Specials and bosses

Only plain Gangers are dressed. A Glasshide, the Bellringer, a Kielholer, the suited and the other kinds get the
neutral parameters and keep their kit's baked look, so against a crowd in colour they are the grey / dark ones with
their own part (crystal plates, lantern, suit, brass helmet). The Soviet risen keep their frost-white skin and their
own cloth. The Foreman and the other bosses have their own bodies and are untouched.

## 4. Dismemberment, corpses, ragdolls

A corpse and a ragdoll are the body's own MeshInstance: nothing to carry. A severed piece is a separate mesh cut from
the body with the same two materials; `ZombieGore._throw_piece` now copies the body's instance parameters onto it
(before T-269 a piece did not even carry the body's tint or dirt).

## 5. Co-op

The spawn event already carried the kit. The outfit, the skin and the wear are derived on each peer from the net id
and the spawn health, both in that event: nothing new is sent. In a session the body's other rolls (build, sex,
height, gear pieces, tint, dirt, rime), which used to be rolled separately on every peer, now come from the same
seed, so a client no longer sees a man where the host sees a woman. Alone, those rolls use the global generator as
before (no change to seeded runs). Posture and gait clip are still per peer.

## 6. Cost per zombie

Counted on the 24 walkers of each Map 0 crowd scene by the look tool (`look.json`: visible MeshInstances, their
surfaces, the distinct materials they use; the renderer's draw calls in the frame with and without the crowd).

| | Before | After |
|---|---|---|
| Body | 1 mesh, 2 surfaces, 2 shared materials | the same |
| Gear pieces | 0 to 3 meshes, one surface **per material key** (a lamp cap is 3), a StandardMaterial3D each | the same meshes, **one surface each** on the shared kit material (the armband keeps its emblem surface) |
| Surfaces per walker (mean of 24) | 5.3 to 6.1 | 4.4 to 4.8 |
| Distinct materials per walker (mean) | 5.1 to 5.8 | 3.1 to 3.3 |
| Draw calls per walker in the frame (shadow and depth passes included) | taproom 14.8, yard 8.6 | taproom 14.75, yard 8.9 (level: the mix now has more villagers, who carry more gear pieces, each cheaper than before) |
| Material instances per zombie | 0 | 0 (instance uniforms on the shared materials) |
| Textures | skin albedo / normal / ORM, fabric and leather detail sets | **none added**; no texture memory change |
| Meshes in memory | one per kit / build / sex | the same count (the colour slot and the AO ride in existing vertex attributes: `CUSTOM0.a`, `COLOR.a`) plus one merged mesh per gear piece and sex |
| Shader | | the kit shader gains one branch for slotted vertices and one for stains (no texture fetch); the skin shader two mixes on samples it already took (the ridge and vein textures are fetched once, earlier, instead of later) and the alpha it already read; both gain one `pow` for the rim |
| Instance uniforms | 6 | 11 on the kit shader, 9 on the skin shader (limit 16) |

Not measured: frame time on a real GPU (the renders are software), and the cost of the extra instance uniforms on
the Compatibility renderer.

## 7. Tools

- `gravelight/tools_src/shots_zombie_look.tscn` (`tools/wsl_zombie_look.sh <tag> --map=<id> [--only=...]`,
  `tools/wsl_zombie_look_all.sh` for several maps one after another): per scene an empty view, the crowd of 24 from
  the map's own variant table, a close-up; on Map 0 also `gore`, `special` and `gallery` (every outfit, eight to a
  picture at noon; `look.json` lists who stands where). Maps without fixed scenes get the crowd along the longest
  clear line from the player's spawn.
- `tools/zombie_look_stats.py <dir>`: the crowd's pixels are the difference to the empty view (blurred, so the film
  grain does not count); prints saturation, the share of coloured pixels, hue bins and spread, and `ab_spread`
  (the spread of the crowd's pixels in the CIELAB a*b* plane: colour variety, which a lamp tinting everything one
  way does not raise). Caveat: outdoors the mask also holds the crowd's shadows on the snow.
- Switches: `-- --zombie-look=off` (the look before T-269 from the same build), `-- --zombie-look=norim`.

## 8. Results

### The numbers (Map 0, 24 walkers, `tools/zombie_look_stats.py`; `before/` is master's zombie code)

| Scene | | sat mean | coloured px | hue bins (of 12) | hue spread | a*b* spread | brightness |
|---|---|---|---|---|---|---|---|
| taproom (lamp light) | before | 0.443 | 94.5 % | 2 | 9.1 deg | 6.52 | 0.464 |
| | after | 0.539 | 88.3 % | 2 | 12.4 deg | 9.16 | 0.308 |
| taproom close | before | 0.397 | 98.5 % | 2 | 5.2 deg | 4.77 | 0.530 |
| | after | 0.507 | 91.3 % | 2 | 10.1 deg | 9.47 | 0.348 |
| yard at night | before | 0.187 | 18.3 % | 1 | 16.9 deg | 4.07 | 0.065 |
| | after | 0.276 | 23.3 % | 5 | 55.0 deg | 4.61 | 0.087 |
| yard close | before | 0.099 | 9.1 % | 2 | 15.1 deg | 3.06 | 0.028 |
| | after | 0.285 | 23.9 % | 6 | 93.0 deg | 4.88 | 0.064 |
| noon close | before | 0.220 | 25.5 % | 2 | 11.3 deg | 4.03 | 0.373 |
| | after | 0.337 | 46.8 % | 6 | 62.4 deg | 8.22 | 0.226 |

With and without the floor light and the rim (the yard close-up, the same build, `after_norim/`): without them
saturation 0.077, coloured pixels 4.9 %, a*b* spread 2.63, brightness 0.020: the outfits are there and nobody can
see them (the figures are black against the snow, as before); with them 0.285, 23.9 %, 4.88, 0.064. Outside at
night the wardrobe needs this term to exist at all. Its price: the figures are a little flat, lit from nowhere.

How to read it. In the taproom the lamps tint everything orange, so even the old cream crowd measured "saturated"
(0.44) in one hue; what changed there is the variety (a*b* spread 4.8 -> 9.5 close up) and that the figures are no
longer the brightest pale things in the room. Under the lamps the hue stays inside two warm bins: a blue coat reads
slate, not blue; that is the lamp and the grade, and was left alone. Outside the hue count goes from 1 or 2 bins to
5 or 6. The yard numbers include the crowd's shadows on the snow (median saturation 0). The wide noon picture is not
in the table: the before mask caught moving cloud shadow (488 000 pixels), so only the close-up is comparable.
Outfits worn by the 24: 1 look per kit before; 15, 15 and 12 different outfits in the three after crowds.

Albedo level (the data, before any light): mean display saturation of the kit cloth colours 0.096 -> 0.48 for the
outfits' main colour (capped at 0.72, reds 0.60).

Other maps (after only; their before was not rendered, see "not verified"): a*b* spread of the crowd close up
Kaltenbrunn 7.9, Totenhafen 12.6, Thalbach 12.3, Kranich 14.9, Groom Lake 6.6 (its grade's mono is 0.7),
Mondlicht 1.0 (black and white by rule).

### Renders to look at first (docs/captures/t269/)

1. `before/map00_crossroads/taproom_close.jpg` against `after/map00_crossroads/taproom_close.jpg`: the complaint and
   the answer in one pair.
2. `before/.../noon_close.jpg` against `after/.../noon_close.jpg`: white mannequins against people.
3. `before/.../yard.jpg` against `after/.../yard.jpg`, and `after_norim/map00_crossroads/yard.jpg` (the same build
   without the floor light and the rim): silhouettes against readable figures at night.
4. `after/map00_crossroads/special_00.jpg`: a Glasshide and the Bellringer among walkers; `gore_02b_piece_close.jpg`
   (the severed forearm in the sleeve's red check), `gore_04_corpse.jpg`.
5. `after/map00_crossroads/gallery_00..06.jpg`: every outfit, in the order of `look.json` scenes.gallery.pages.
6. One crowd per other map: `after/<map>/start.jpg` and `start_close.jpg`.

### Tests

- Script check: 977 scripts, 0 failed.
- GUT, full suite twice on the branch: 2470 and 2472 tests (12 new in `test_zombie_wardrobe.gd`: every map has a
  palette for every kit it spawns, weights valid and summing to one, outfits are valid colours and patterns, the
  choice is the same from the same net id and health and spreads over the weights, 24 walkers wear at least eight
  outfits, kits outside the wardrobe keep their colours, no surface / material / mesh is added, gear is one surface
  on the kit material in its old colour, the light values stay small and only on the zombie materials). Each run
  had one failure, a different one each time, both outside this work and both passing when run alone:
  `test_bs_level.test_collect_quest_items_show_only_while_active` (run 1; alone 1 fail in 2 tries) and
  `test_npc_life.test_warm_hands_meet_under_the_chin` (run 2; alone 2 passes in 2). The machine was running eight
  to eleven software renders for six workers at the time. The known risky `test_neural_lines_are_loudness_normalised`
  as on master.
- Smokes (`.smoke_logs/t269/`): `smoke_map00`, `_alive`, `_cellar_bay`, `_loop`, `smoke_coop`, `smoke_bots`,
  `smoke_bots_shop`, `smoke_bots_u10`, `smoke_ee_bots`, `smoke_jakub`, `smoke_zombie_anim`, `smoke_hard_truth`,
  `smoke_map04d`, `smoke_map04d_world` PASS; `smoke_marks` fails 'an empty spot: collect, go' as on master;
  `smoke_bots_shop_m0` failed once on 'bench' (the known intermittent) and passed on the second run. The Map 0
  smokes, `smoke_coop` and `smoke_zombie_anim` were run again on the final code: PASS.
- The severed piece's instance parameters equal the body's (look tool, `look.json` piece_vs_body).

### Not verified

- **Other maps before / after pairs.** Only Map 0 has a real before. The other six have the after crowd only.
- **Co-op by eye.** `smoke_coop` passes and the look is a pure function of values both peers hold (unit-tested), but
  no host and client were rendered side by side.
- **Frame time.** Counts only (section 6).
- **Motion, the Compatibility renderer, real-GPU tone** (section 9).
- **Mondlicht** has little value variety in the render: most of the crowd wears the dark suits. Tunable in the
  json; left as rendered.
- **The specials' own colours** were not changed and were looked at in one scene only (Glasshide, Bellringer; the
  Foreman was spawned but is not clearly in frame).
- The menu's, the reels' and the landscape column's figures build bodies without instance parameters and still wear
  the old baked greys (the menu and the reels are black and white by design).

## 9. What only the owner's eye on the real GPU can judge

The renders are Forward+ on lavapipe (software Vulkan) at 1280x720 with the 3D drawn at two thirds: the same
renderer, shaders, grade LUT and post chain as the PC, so colour and value relations hold. What can differ:

- **SDFGI / SSIL / volumetric fog quality and glow** follow the settings preset; the tool runs a fresh profile's
  defaults. Bounce light on the real preset can lift or tint the figures differently, above all indoors.
- **The floor light (`light.min_light` 0.11) and the rim (0.5)** were chosen on these renders. On a real monitor in
  a dark room a walker in a pitch-black corner may read as faintly self-lit: if so, lower `min_light` first (only 0.045, 0.11 and
  off were rendered; 0.045 left the yard's soldiers near black); `--zombie-look=norim` shows the look without both.
- **Saturation.** The outfit colours are capped at 0.72 (reds 0.60) so the grade's blood-red keep does not make a
  red jumper as loud as blood. If the crowd still reads muted in play, raise the caps in the json (a first pass
  at 0.86 made Kaltenbrunn's coveralls look like costume); if it reads loud, lower them. This is taste, and the owner's call.
- **The skins.** Grey-green and bruised faces read clearly in every render; whether the ashen / bruised ones are
  too blue under the moon fill in the taproom's doorway is a judgement call (`skins.*.tone`).
- **Motion.** Stripes, checks and dots are fixed to the cloth at rest and fade when under a pixel wide, but nothing
  was seen in motion: shimmer at mid distance on a real display is unchecked.
- **Compatibility renderer (web build, old laptops):** not rendered. It has no LUT (a plain saturation of 0.72
  instead), so colours will be stronger there than in these pictures. The zombie shaders already used instance
  uniforms there before this change, but the five new ones were not run on that renderer.
- **Steam Deck / Apple laptops:** no frame time was measured anywhere; the cost table is counts, not milliseconds.
