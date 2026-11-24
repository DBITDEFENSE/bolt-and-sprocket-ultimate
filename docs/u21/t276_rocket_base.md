# T-276: the V2 site east of Map 0, and Rocket Man

The owner (2026-11-24): "make the initial map larger add a v2 rocket base on the right side of the map past the
trees, with a new perk rocket man."

Branch `claude/rocket-base` (from master a15b7146). Map 0 is generated: everything about the site is
`gravelight/tools_src/gen_map00_rocket.gd` (`MapRocketGen`), called from `gen_map00.gd` by one hook per pass and
three one-line filters; the moving parts are runtime nodes in `gravelight/world/rocket/`. Regenerate with

    "$GODOT" --headless --audio-driver Dummy --path . --script res://gravelight/tools_src/gen_map00.gd

## Where and what

"The right side" is east: the squad spawns facing north in the taproom, so right is +X. The grounds' east fence
is x 60; beyond it, past the T-093 tree line, the map now goes on to x 126.

| piece | where | notes |
|---|---|---|
| the gate `Door_Rocket` | east fence x 60, z 38..42 | a two-leaf plank gate (GateDoor), 1500, "The Forest Track"; opens FORSTWEG and STELLUNG; swings east |
| zone FORSTWEG "The Forest Track" | x 60..84, z 36.5..43.5 | a trodden track with ruts, a field-telephone cable on stakes, a lantern post, a felled spruce, the forest both sides |
| zone STELLUNG "The Launch Site" | x 84..126, z 18..62 | the clearing, open ground (roam) like GROUNDS |
| firing table | (108, 0, 40) | four splayed legs, the ring the fins stand on at 1.45 m, the blast deflector, a scorched steel plate |
| the V2 | on the table | runtime `V2Model.rocket()`: 14 m, 1.65 m across, four fins, the trials' black-and-white quarters; no markings, no text, no numbers |
| erector trailer | x 95..105.9 along z 40 | chassis, twin wheels, rams, towbar, outriggers; the arm is runtime `V2Model.erector_arm()` hinged at (106.1, 1.75, 40) |
| oxidiser trailer | (97.5, 0, 28.5) | lagged white tank, vent stack, valve, a hose toward the table; under a camouflage net on four poles |
| fuel trailer | (97.5, 0, 51.5) | olive tank, filler dome, drums of alcohol beside it; under a net |
| generator trailer | (116.5, 0, 54) | louvred box, exhaust, fuse box, a lantern; its engine is the site's sound |
| firing-control dugout | outer x 114.4..120.6, z 23.4..28.6, 2.6 m inside | sandbag faces on a timber revetment, log roof under earth and snow, doorway in the west wall (z 25.1..26.9), a slit toward the table, desk with switch panel, gauges, field telephone, periscope through the roof, bench, bulb |
| guard hut | x 86.4..90.4, z 26.6..30 | plank walls, pent roof, a shut door, a lit window, stove pipe, lantern, bench (solid: not entered) |
| raised barrier | the clearing's mouth (85.1, 36) | red and cream boom, up |
| crates, stumps | four stacks, five stumps | solid crates (no mantle); stumps 0.55 m (cover) |
| floodlight | mast at (100.2, 33.6), 7.4 m | aimed at the rocket; the site's one shadowed light |
| the forest | round the clearing and the track | 164 trees (135 spruces, 29 birches), 41 bushes, 17 rocks, rows to 14 m deep (NatureRows: built at load, no shadows) |

Prices: the gate 1500 (Map 0's dearest single door with the cellar's; it is the only way to a perk, a wall gun and an ammo box,
and a long walk). STG-44 1200 (its own wall price). Ammo box as everywhere.

**The zone graph.** The site is reached only through `Door_Rocket`, which stands in the grounds' fence: from the
taproom the path crosses `Door_Front` (or the yard's doors and `Door_Gate`) and then `Door_Rocket`; no paid door is
skipped (`smoke_rocket_site` checks both paths on the navmesh). One door opens both zones (`also_opens`): the track
is a corridor with nothing on it.

**Spawns.** The dead come out of the woods: seven spawn pockets beyond the new edge walls (kind "edge", the T-084
pattern: a pocket of navmesh behind a gap in the edge wall filled by an `RktEdgeGate` only bodies collide with), one
north of the track and six round the clearing (north x2, east x2, south, west), and two snow risers in the clearing
from round 4. All `player_zone_only` (as the grounds' edge spawns): used only while a player stands in that zone.
No window barricades: there is no building the dead would come through, and a barricade on the hut would put them
inside it. Wall-buy: the STG-44 on the guard hut's east wall. Of the guns with a wall price the Gewehr 43 is in the
Old Cellar already and the rest are on Map 0's walls, but the M1 Carbine, an American rifle a German firing site
would not hold, so the site has one.

**The ground.** The play space's slab ends at x 70; beyond it the Landscape terrain rises. The terrain now has a
flat annex (`LandscapeTerrain.ANNEX`, x 70..135, z 10..70, on its 5 m lattice; cleared by `use_profile`, so
Kaltenbrunn's landscape is unchanged): no terrain quads there, the slope starts at height 0 round it, the forest
keeps 28 m clear of it as of the slab (the near forest there was a few strays anyway). A visible snow slab covers the
annex; invisible floors only under the walkable rects and the pockets. The grounds' bake-only edge carve has the
site cut out of it (`MapRocketGen.trim_carve`). `MapRoot.drop_extra` keeps a power-up dropped on the site on the
site (it was pulled back to x 58.5 by `drop_bounds`); one dropped in a pocket lands in the clearing.

**Nothing else moved.** Scene diff, old vs new (node path, class, position, multiset): nothing gone or moved west of
the fence; added: the site, the gate, `EdgeGates` for the pockets; changed: the east fence's two drawn pieces by the
gate (the fence is cut there; every other fence keeps its seed: `MapRocketGen.fence_seed`), and the tree line's gap
(the line makes the same random draws, so no other tree moved). Navmesh: 15 polygons gone and 328 new; the ones west
of x 55 are all in the open field in front of the gate (x 39..55, z 32..46: its large polygons are cut differently
now that the field opens through the gate); nothing changed elsewhere. The seed-0 deal of the twelve machines is the
same (see below). A note for T-275 (the watchtower): the hooks are one line each in `build_grounds`,
`build_dressing`, the end of `build_gameplay`, `_cut_pockets`, `_carve_beyond_edge`, `_tree_line`, `PERK_SPOTS` and
`MACHINE_FOOTPRINTS`; a merge should be mechanical, then regenerate.

## Rocket Man

`perks.json` `rocket_man`, 2500, **no power needed** (the site's generator runs it). Pinned to the dugout:
`PerkSpot launch_bunker` (east wall, facing the doorway, flush) and `perk_layout.json` `"fixed": {"rocket_man":
"launch_bunker"}`, a new deal rule (`PerkShuffle.assign`): a fixed tonic and its spot are taken out first and the rest
are dealt exactly as without them, so every seed's deal of the other twelve is what it was before T-276
(`test_rocket_man` checks seven seeds against the old deal).

| tier | price | effect |
|---|---|---|
| base | 2500 | the holder's own explosives deal x1.3 damage over x1.25 radius (a frag's 6 m reaches 7.5 m) and never hurt the holder; the holder's own blast within 3.5 m of them, while they stand on the ground, throws them clear: 7.5 m/s away from it and 5.5 m/s up (about 1.1 m high and 3.4 m away in the smoke; on the ground only, so it never lifts anyone over a 2.3 m fence and past a bought door) |
| II Range Safety | 3500 | what the blast leaves standing staggers (not bosses) |
| III Burn-Through | 7000 | and burns: a fifth of the round's zombie health a second for 3 s; radius x1.35 |
| IV Brennschluss | 13000 | permanent; damage x1.5; the V2 launch's blast cannot hurt the holder |

Why this and not the brief's whole list: Blastproof Bock already makes your own explosives harmless and has the
slide shockwave, Skyhook Sekt has the safe landing and the landing stomp, and the game has no fall damage at all
(Blastproof's `fall_damage_immune` is read by nothing). What no tonic had: more damage and reach for your
explosives, and a way to move with them. Rocket Man shares only the immunity flag with Blastproof (a bool: holding
both changes nothing). Hooks: `PerkManager.explosive_mults` / `explosive_after` / `blast_jump` / `v2_immune`, read
in `Explosion.detonate` (every blast in the game goes through it: frags, the Panzerschreck and its bomblets, the
gramophone) and `RocketLaunch`. Only the owner's blasts (by_player) are boosted.

The machine: a new cabinet shape `rocket` (`InteractableArt._rocket_cab`): a rocket on four fins in gunmetal enamel
`#5c6670` with black quarters that swap halfway up, a cream nose of stacked rings, a scorched ring at its foot; 1.0 x
2.1 x 0.9 m (under the dugout's ceiling); the sign ROCKET MAN in flame-orange neon `#ff9a3c`. HUD cap: the rocket
climbing on a copper flame (`PerkCap._rocket`). Sound: a jingle (a countdown on a woodblock, an ignition thump, a
cornet climbing C major over a timpani roll, a rising engine noise) and the machine's hum, both from
`gen_audio.py`. Lore: `docs/JINGLES.md` section 17 (Plan ESCAPE VELOCITY, the human Ignaz Wolff, a propellant fitter,
the fine-print panel), `perk_lore.json`; the maker's plate in `machine_lore.json` (added by hand: that file has
rows the markdown lacks, T-251) and `PERKS_LORE.md`. Bots: last in both perk plans and the player agent's order (they
buy it when everything before it is drunk and they can walk there). No voice lines (a `PERK_ROCKETMAN` token is
in `PERK_TOKENS`; the category has no lines, so it is silent).

## The launch

`map00.json` `"rocket_launch"`, `RocketLaunch` (`gravelight/world/rocket/rocket_launch.gd`; the node stands on the
table, `Gameplay/RocketLaunch`). A launch on round 6 and every 5th after (6, 11, 16, 21, ...), 20 s into the round,
whether the site is open or not (it is seen over the trees from the grounds). From the siren:

| s | what |
|---|---|
| 0 | the siren (every 9 s until the main stage), the banner "V2 LAUNCH AT THE FOREST CLEARING / Stand clear of the firing table", vapour off the rocket and the oxidiser trailer's vent |
| 6..15 | the erector arm lowers onto its trailer |
| 22..32 | ten counted: a banner per second to players within 60 m, a tick from the dugout |
| 32 | the preliminary stage: a short flame under the table, the roar begins |
| 34 | the main stage: the full jet, smoke and snow thrown out four ways, the ground shakes (within 70 m). Host: the dead within 6 m die (explosive: their bodies fly), 6..13 m are thrown and hurt on landing (60), a player within 7 m takes up to 45 (25 % at the edge; half with Blastproof or Rocket Man, none at Rocket Man IV) and is pushed; the table burns for 7 s (a FirePatch, 5.5 m, 16 a second to players, the dead walking through catch fire) |
| 35 | lift-off: 0.8 t^2 + 0.06 t^3 m along a path straight up for 18 m, then pitching over toward the east (50 degrees by 700 m); out of sight at 380 m (about 15 s), its smoke trail left hanging |
| next round +15 s | a new rocket lies on the lowered arm and is raised over 24 s, ready for the next launch |

Host-driven like the Sherman's dive bomber: the host decides, mirrors `net_begin` / `net_rearm`, each peer plays
the same timeline on its own clock (the climb is a pure function of time); damage on the host only. A late joiner
reads GameState flag `v2_state` (0 ready, 1 gone). Bots get a danger disc round the table from 6 s before the count
to 8 s after lift-off (the squad's blackboard, as the Sherman's fire patches). Console: `v2 launch | rearm | status`.
Sounds are the bank's (no new synth): the siren `a1_siren`, the roar `m4d_vent_roar`, the ignition `m4d_pad_launch`,
`explosion_large`, the tick `ui_tick`; the site's bed is `ambient_map01_generator` at the generator and `wind_howl`.
No Operator voice line: the banners carry the warning (no V2 lines exist; a new line needs the VO script and a
take).

## Costs (Map 0, counted from the scene)

| | before | after | added |
|---|---|---|---|
| triangles (whole map, baked meshes) | 390,724 | 438,712 | 47,988 |
| of them in shadow-casting meshes | 177,920 | 206,168 | 28,248 |
| lights | 140 | 150 | 10 (8 lamps incl. the gate's lantern, the wall-buy lamp, the floodlight) |
| lights that ask for a shadow | 19 | 20 | 1 (the floodlight, a spot: one view) |
| collision shapes | 667 | 744 | 77 |
| draw surfaces east of x 60.5 (static batches) | 2 | 171 | 169 |

(before = master c96e7ffa with T-275's ladders; after = this branch.)

Plus at load: the forest (4 MultiMeshes, no shadows), the rocket (about 8 meshes) and the arm (baked, 3 meshes); during
a launch the jet's light and the fire patch's light. All static geometry is under the generator's batch containers
(StaticBatches), so T-266's shadow proxies, prop shadows and occluders take it like the rest; the lamps fade with
LightRange. The site is behind the tree line from the inn; from the grounds the frustum takes it only looking east.
Bunker: its outer faces are boxes in the sandbag surface with two courses of single bags on top (all bags as spheres
were 46 k shadow-casting triangles).

## Verified, and how

Headless on Windows; renders under WSL + Xvfb only. (Results: see the bottom of this file.)

- `smoke_rocket_site` (30 checks): the gate shuts the way (a body is stopped), the navmesh paths cross Door_Rocket
  and no other door from the grounds, a grounds door and Door_Rocket from the taproom; bought with Scrip it costs
  1500 and opens both zones; the track and the clearing are navmesh and open ground; nothing past the new edge
  walls but the pockets; the wall-buy, ammo box, rocket are there and reachable; drops stay on the site; round 5
  with a player in the clearing: the dead come into the clearing and reach them; the bot follows through the gate
  and stays on the ground.
- `smoke_rocket_man` (13 checks): the machine on launch_bunker whatever the seed, inside the dugout, pouring
  without the power; bought for 2500, held, its cap on the HUD row; the holder's own frag at their feet does no
  damage and throws them 1.1 m up and 3.4 m away (under a fence); a zombie 6.9 m off is hit; tier IV: the V2's
  blast leaves the holder alone.
- `smoke_rocket_launch` (23 checks, a compressed timeline): the round rule, the arm down before the count, the
  count, the kills, the throws, one 21 m off untouched, the player beside the table hurt and not downed, the fire,
  the rise, the climb and the pitch east, gone, the flag, the next round's rearm, the next launch round.
- `smoke_coop`: a new check, the client's RocketLaunch begins the host's sequence.
- Unit: `test_rocket_man` (9), `test_rocket_launch` (9); updated counts (12 -> 13 tonics) in `test_perks`,
  `test_perk_magpie`, `test_perk_layout`, `test_map00_cellar_bay`, `test_mapdata`, `test_gl_m2`; new nav
  fingerprints in `test_map00_art`; `test_map00_grounds` counts the new pocket gates and waits for the bigger
  bake's first sync.

## For the owner's eye

- The look on a real GPU (the renders are the software Compatibility renderer).
- The rocket's paint: the trials' black-and-white quarters swapping per band, no marking. If the owner wants the
  operational green-grey instead, it is two material keys in `V2Model.rocket()`.
- Balance: the gate at 1500; Rocket Man 2500 and no power; the blast jump's height (1.1 m) and distance; the
  launch's 45 damage and 7 s fire. Numbers in `perks.json` and `map00.json`.
- Bots do not use the launch (they avoid its danger disc) and buy Rocket Man last.

## Results (claude/rocket-base after merging master c96e7ffa, T-275's ladders)

- `check_scripts`: 0 failed.
- Full GUT (before the merge, the item 1-3 commits): 2649 tests, 2646 passing, 2 failing, 1 risky. The two failures
  were `test_mapdata`'s POI check and perk-POI count, waiting for the minimap rebake (done since under WSL;
  `test_mapdata` rerun: see below). The risky one is the known `test_neural_lines_are_loudness_normalised`.
- Smokes after the merge and the regeneration: `smoke_ladders`, `smoke_map00`, `_alive`, `_cellar_bay` (now counts
  thirteen machines, Rocket Man pouring without the lever), `_loop`, `smoke_map_detail` (125), `smoke_coop`,
  `smoke_sherman` (74), `smoke_weapon_locker`, `smoke_rocket_site` (30), `smoke_rocket_man` (13),
  `smoke_rocket_launch` (23), `smoke_bots`, `smoke_bots_shop`, `smoke_bots_shop_m0`, `smoke_bots_u10` PASS.
- After the minimap rebake: `test_mapdata` (11), `test_map00_art` (8), `test_capture_cams`, `test_rocket_*` (23),
  `test_perk_layout`, `test_map00_grounds` PASS; check_scripts 1029 scripts, 0 failed.
- The merge: map00.tscn conflicted, master's taken and regenerated with both; scene diff against master's: nothing
  gone or moved; navmesh: 15 polygons gone, 326 new, the ones west of x 55 all in the open field before the gate.
- Renders: `docs/captures/t276/` (26 frames, night and noon, the launch at eight moments), WSL + Xvfb, Compatibility
  renderer, 1280x720. What the first set changed is in the commit "fixes from the first renders": the rocket's
  lathe and fins faced inward, the floodlight too weak, the gate black at night, the dugout's faces, the Rocket Man
  cabinet's front, the ruts, and the launch cameras (they stood behind the fuel trailer).

## A DECISIONS paragraph, ready

**T-276, 2026-11-24: Map 0 grows east: a V2 firing site in a forest clearing, and Rocket Man (the owner: "make the
initial map larger add a v2 rocket base on the right side of the map past the trees, with a new perk rocket
man").** Branch `claude/rocket-base`, notes `docs/u21/t276_rocket_base.md`, renders `docs/captures/t276/`. "The
right side" is east (the squad spawns facing north). A bought gate in the grounds' east fence (`Door_Rocket`,
1500, "The Forest Track", x 60 z 38..42) opens a forest track (zone FORSTWEG, x 60..84) into a clearing (zone
STELLUNG, x 84..126, z 18..62): the V2 on its firing table at (108, 40) with the erector trailer backed up to it,
the oxidiser and fuel trailers under camouflage nets, a generator trailer, a firing-control dugout you walk into,
a guard hut, crates, stumps, cable runs, lamps and one shadowed floodlight; a forest round it all. Own geometry,
no insignia or markings; the rocket wears the trials' black-and-white quarters. All of it is `MapRocketGen`
(`gen_map00_rocket.gd`), one hook per pass in gen_map00 and three one-line filters; the Landscape terrain has a
flat annex under it (`LandscapeTerrain.ANNEX`, cleared on other maps); seven spawn pockets in the woods (edge
kind) and two snow risers, all player-zone-only; the STG-44 on the hut (the only wall-priced gun not on Map 0's
walls but the American M1 Carbine); drops from the site stay on it (`MapRoot.drop_extra`). Nothing west of the
fence moved (scene diff; the navmesh changed only in the field before the gate). Rocket Man (`rocket_man`, 2500,
no power: the site's generator), pinned in the dugout by a new deal rule (`perk_layout.json` "fixed": the others
are dealt exactly as before, every seed): the holder's own explosives x1.3 damage over x1.25 radius and harmless
to them, and their own blast at their feet while they stand throws them clear (7.5 m/s away, 5.5 m/s up: about
1.1 m, never over a fence); II staggers what the blast leaves, III burns it (radius x1.35), IV (permanent)
damage x1.5 and the launch cannot hurt them. Blastproof's slide shockwave and Skyhook's landing are untouched;
the game has no fall damage, so none was added. A "rocket" cabinet, a HUD glyph, a synth jingle and hum, lore
(JINGLES section 17; the maker's plate added to machine_lore.json by hand), bots buy it last. The launch
(`RocketLaunch`, map00.json "rocket_launch"): round 6 and every 5th, 20 s in, open or not: siren and banner,
vapour, the arm down, ten counted, ignition at 32 s, the main stage at 34 s (host: the dead within 6 m die,
6-13 m are thrown, a player within 7 m takes up to 45, a 7 s fire on the table), lift-off at 35 s climbing and
pitching east out of sight in about 15 s; a new rocket raised the next round. Host-driven, mirrored, a flag for
late joiners. Cost: +48.0 k triangles (+28.2 k shadow-casting), +10 lights (one shadowed), +77 colliders, all
static geometry in the generator's batches. Verified: `smoke_rocket_site` (30), `smoke_rocket_man` (13),
`smoke_rocket_launch` (23), a new check in `smoke_coop`, `test_rocket_man` and `test_rocket_launch`; the map00
smokes, ladders, sherman, weapon_locker, map_detail PASS after merging T-275. Honest state: seen only in the
software renderer, nights there are dark; not played by a person; co-op checked only for the start of the
launch; no Operator voice line (banners); the horse bosses' arena and the Sherman's drive zones do not include
the site (a player there during a horse round is not specially handled); the site is hidden behind the trees
from the grounds until the rocket climbs over them.
