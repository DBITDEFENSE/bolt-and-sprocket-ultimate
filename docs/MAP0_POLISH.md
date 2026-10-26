# Map 0 — small-detail polish pass (Update 02 §8, DECISIONS T-053)

Room by room checklist for the Crossroads Inn, from `UPDATE_02_POLISH.md` §8. `[x]` = built and seen in the
screenshots; `[~]` = partly; `[ ]` = not done. Source of truth for the dressing is `gravelight/tools_src/gen_map00.gd`
(`_dress_polish()`, `build_reactive()`, `_window()`, `_dress_bar()`, `_dress_taproom()`); the reactive pieces are
generic components in `gravelight/world/reactive/` that other maps can reuse.

**Rules kept:** buyables, doors and windows read first (nothing in front of a wall-buy, a door, a window or a crate
spot; the Room 1 door is hinged so it never hides the MP40); all decor is non-colliding dressing, nothing new in a
walk path; **the navmesh is byte-identical to master** (both bakes, compared in the .tscn). The cousins' things follow
`docs/HOMAGE_BOSSES.md` §1.2: modest period clothes (buttoned, long-sleeved, high-necked, ankle-length), and their
drawings are childhood drawings.

Screenshots: `morning/screenshots/u02/s8_polish/<view>_before.png` / `_after.png`
(`tools_src/shots_map00_rooms.tscn`, fixed free-camera views, HUD off; `close_*` views are the story close-ups).

---

## Every room

- [x] **Bullet holes persist** for the match, pooled and capped: one MultiMesh per surface kind, 96 each, oldest reused
  (`Effects.HOLES_PER_SURFACE`). Holes only persist on plain static world geometry (`Effects.persists_on`); doors,
  seals, machines and invisible stand-in colliders (tables, rail panels, fences, the great doors: `decal_persist`
  meta from `gen_map00.box()`) keep the old 8 s quads, so nothing floats when a door rises. Holes in snow fill in
  after 6 s. Wiped on `GLBus.match_started`.
- [x] **Scorch marks** under real explosions (radius ≥ 1.2): pooled `Decal`s, 16, oldest reused, projected down.
- [x] **Cobwebs** in the high corners of every room (taproom, the three guest rooms, the hall, the stable roof).
- [x] **Snow blown in** at every broken window: a rime on the inside sill, a soft fan on the floor, a little drift at
  the wall foot (taproom ×4, upstairs ×2, stable ×3).
- [x] **Wind howls** at each of those 9 windows (`AudioZone` loop, `wind_howl`), louder in the gusts (MapAmbience's
  wind) and louder as the window's barricade loses boards.
- [x] **Curtains move in the draught** (`DraftCurtain`, all 12): they billow with the wind, harder as the boards come
  off, and flutter when shot.
- [x] **Frost** on the panes is §7's `FrostCreep` (unchanged).

## Taproom

Story props
- [x] **Half-eaten meals**: the patrol's table (cold soup, a mess tin, the bread), the table by the hearth (two
  suppers, a bowl, a loaf), the signals table (a crust and a mug by the logbook).
- [x] **An overturned chair** knocked back from the patrol's table as they got up.
- [x] **The calendar on December 1944** on the north wall behind the bar: days crossed off to the 22nd, Christmas Eve
  ringed (`PaperDecor` "calendar"; 1 Dec 1944 was a Friday).
- [x] **The aunt's apron on a hook** (Lene's, faded blue) at the bar end of the north wall, a cloth on the peg beside it.
- [x] **The patrol's abandoned gear and the map with a circle around Kaltenbrunn**: the map sheet spread on their
  table (roads, the rail line to the works, the crossroads pencilled, a hard red circle round Kaltenbrunn),
  a Stahlhelm, a mess tin, a greatcoat on the bench, the gas-mask canister and the open map case under the table.
- [x] **The radio with handwritten frequency notes**: two of Käthe's pencilled slips pinned under the wireless
  ("Beromünster 556 / Breslau 950 / "Das Mädchen" / 23 Uhr ??" — deliberately not the radio-note egg's frequencies).
- [x] "Soup kept warm" (the guest book, 21.XII): the iron pot on the hearthstone with its ladle.

Surface and wear
- [x] Worn floorboards: pale scrubbed paths in front of the bar, along its side, the spawn, every doorway.
- [x] Scuffed paint: boot scuffs on the bar front and side, the wainscot by the stable and stair doors.
- [x] Water stains: the ceiling's NW corner and over the east window, streaks under the north windows.
- [x] Soot / grime: the chimney breast, the lintel and the ceiling over the hearth, a smudge over each lantern, grime
  round the door frames at hand height.

Reactive
- [x] **Bottles and glasses shatter when shot**: the 70 on the back shelves and the counter (`ShatterSet`
  "Glass_Bar"), the steins on the tables and the stein shelf ("Glass_Taproom"). Shards, a splash of what was in
  them, `glass_break`. A blast close by breaks what is in reach. The back shelving's stand-in collider is tagged
  `shot_through` so shots reach the bottles.
- [x] **Hanging lamps swing when hit**: every `Props.lantern` carries a decor hit volume; a shot swings that lamp (and
  its light) through `LampSway`, with a tinny `lamp_knock`.
- [x] **Doors creak**: every bought door (`BuyDoor`) creaks as it goes (`door_creak`).

Audio
- [x] **Fireplace crackle** (`AudioZone` loop on the hearth, follows the Hearthfire light: it dies with the fire in the
  Cousins Round).

## Stairs and upstairs

- [x] **Room 1, the cousins' room**: three childhood drawings pinned on the south wall (the inn with "Tante Lene" and
  three girls, Fanny the horse, a girl on tiptoe for the jam: the Reach's nod), a long navy Sunday dress on a hanger
  on the wardrobe, a cardigan folded at the bed's foot, a suitcase open on the bed, the red ribbon and a brush on the
  blanket, three pairs of shoes, a winter coat and a scarf on a peg rail, a straw tick rolled in the corner.
- [x] Room 2 (the works' gentleman): a briefcase by the bed, a hat on the trunk.
- [x] Room 3 (Josef, the letter): his overcoat over the chair, the coffee he didn't finish.
- [x] **Doors creak**: the three guest rooms have old plank doors left ajar (`SwingDoor`); anyone coming through swings
  them out of the way, they drift back in the draught and creak as they move. Non-colliding.
- [x] Wear: water stains on the ceilings (Room 1, Room 2, the hall's east end, over the stairwell), worn boards in
  each room and the hall runner, cobwebs.
- [x] Snow blown in at the two upstairs windows; wind at both.

## Stable and hayloft

- [x] **Hay puffs when you walk through it**: `HayPuffZone`s over the straw on the stable floor, the hay pile and the
  loft (players and zombies kick up chaff while moving).
- [x] **Stable creaks** (`AudioZone` random, the old frame groaning every 12–30 s).
- [x] **A horse whinny early; the horse is gone later; never show what happened**: the horse is heard from her stall in
  rounds 1–2 only (at most three times), never seen. Her stall stays: the name board "FANNY" over the manger (the
  same horse as the cousins' drawing), the halter on its peg, the water bucket, a blanket over the manger, hay
  trodden into the floor. After round 2 it is just empty.
- [x] Loose straw over the loft boards; cobwebs in the roof corners and on a truss.
- [x] Snow blown in at the three stable windows; wind at each.

## Cellars

- [x] **Dripping**: the Old Cellar's drips are §6.1's; the Helvetia cellar gets two more over its puddles.
- [x] Wear in the Helvetia stair hall: a melt-water stain on the ceiling, boots worn into the landing.
- [~] The Old Cellar was dressed in §6.1 (cobwebs, puddles, soot, the patrol's leftovers at the cage); nothing more
  was needed there.

## Exterior

- [x] **Footprints in the snow, players and zombies, fading**: `SnowFootprints` over the open snow (the snowfall's
  areas plus the strip in front of the inn; not over the light wells or in the cellar's stair hall). Boot prints for
  players, dragged shuffling prints for zombies, a print every 0.72 m, filling in over 90 s; one MultiMesh, 384
  prints, oldest reused; faded by a shader from each print's birth time.
- [x] Bullet holes in snow fill in after a few seconds (above).

## Not done / follow-ups

- [ ] Grime *decals* on the window glass: the frost on the panes is §7's; no separate grime layer on the glass.
- [ ] Footprints don't sink into the snow drifts (the drifts are dressing over the flat ground; prints lie on the
  ground plane under a drift's edge).
- [ ] Reactive dressing on Maps 1 and 2: the components are generic, but only Map 0 places them (Props.lantern hit
  volumes appear on the other maps the next time their generators run).

## Tests

- `gravelight/tests/unit/test_map00_polish.gd` (GUT): the decor layer and the shot mask, what keeps holes, the hole and
  scorch caps, glass breaking once, footprints only on open snow, the audio zones' round gates, the sound keys, the
  paper art.
- `gravelight/tools_src/smoke_polish.tscn`: the reactive pieces on the real map react (a bottle shot through the
  shelving, a lamp, a curtain, a persistent hole, a scorch, hay, a room door, footprints, the loops playing).
- `tools_src/soak_map00.tscn`: the whole-map zombie pathing soak (every door open, every spawn live, 20 spots in
  every room, 10 minutes from round 8).

---

## UPDATE 05 art pass (T-093): Crossroads Inn stops reading as untextured shapes

Gameplay geometry did not move: colliders, doors, windows, spawns, prompts and zones are as T-084 left them, and
both navmesh bakes fingerprint byte-for-byte the same as master's (`test_map00_art`).

- **Materials.** Every `Mats` key gen_map00 draws with is on the CC0 library (`data/gravelight/materials.json`
  `generator.enabled`, 27 keys): dark oak beams and half-timbering, worn-oak furniture, panelled wainscot, the
  plasters, planks, shingles, fieldstone, iron, rubble / flagstone / brick / limewash in the cellars, reed straw
  for the hay, olive-over-rust for GRAVELIGHT ONE, clean wind-packed snow (snow_01, 2K) and trodden snow over
  frozen dirt. Grime climbs the skirtings, frost sits on the roofs' and rocks' up faces, the cellars are wet at
  the floor (the shared shader's wear parameters).
- **Props** (`PropScatter`, node `LibraryProps`, built at load time as one MultiMesh per prop mesh): round and
  plank tables over the table colliders (tops at exactly 0.75 m, so the meals and the patrol's map still lie on
  them), farmhouse chairs (the knocked-over ones too), iron bed frames round the beds' mattresses, nightstands, the
  wine casks, the 1937/41/43 casks on their cradles and the KREUZWEG stack in the barrel vault, Fanny's bucket, the
  chopping block and axe in the yard, the guard's stool at the cage.
- **Exterior.** Half-timbered west and east faces (studs and K-braces) to match the north, a soft snow lip along
  every eave, split-rail fences, dead trees in pine bark.
- **Nature.** Scripted spruces and birches (`tools_src/blender/nature/make_trees.py`, LOD0 1.8k / 0.55k tris,
  LOD1 ~150 / ~90) replace the cone pines in the tree line (`EdgeTrees`, a `NatureRows` node) and the Landscape's
  near and mid forests (LOD0 inside 95 m, LOD1 beyond, the impostor cards kept for the far rows); bare bushes and
  boulders on the near swell and the stream banks; the near terrain height-blends the snow into frozen mud on the
  roads with ruts; the far hills' rock faces are textured.

Not done: lamp meshes (the hanging lanterns keep their code mesh: the lit glass, LampGlow and the Cousins'
lamp groups key off it), glass panes in the windows (they are broken and barricaded), a fieldstone yard wall (the
yard is fenced, T-080), benches and bar stools (no library model at seat height), wardrobes and washstands.
