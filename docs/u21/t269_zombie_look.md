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

`light.min_light` (a walker shows 11 % of its own colour with no light on it at all) and `light.rim` (a soft edge
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
