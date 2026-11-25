# T-279: the V2 site's second detail pass

The owner (2026-11-25): "the rocket area needs another pass for details and stuff too".

Branch `claude/rocket-detail` (from origin/master 8c4741e9, which has T-276, the open_zones minimap fix and the review
fix in `RocketLaunch._on_round_started`, kept). Renders `docs/captures/t279/` (`*_before.png` are T-276's frames from
the same cameras; `*_after.png` this build).

## What the T-276 renders showed

Big empty snow between a few boxy props; the trailers and the tanker plain boxes and cylinders under nets that read as
flat dark roofs; no ground detail; a bare gantry and bunker.

## What was added

All of it is dressing in a new module, `gravelight/tools_src/gen_map00_rocket_detail.gd` (`MapRocketDetail`), called
at the end of `MapRocketGen.build_dressing`. **No collider is added, moved or resized**, so the navmesh, the zones,
the spawns, Rocket Man's spot and footprint, the gate and every prompt and timing are T-276's.

| | |
|---|---|
| perimeter | a wire fence drawn on the line of every invisible edge wall: posts every 3 m leaning out, three strands, a SPERRGEBIET plate every fifth post; at each of the seven spawn pockets the wire is cut, its end posts askew, strands lying in the snow (the dead come in there) |
| telephone line | ten poles outside the wire along the track's north side, up the clearing's west side and along its north side, two wires on porcelain insulators, the drop onto the dugout's roof, a FERNSPRECHLEITUNG plate |
| slit trench | a zig-zag outside the north wire (x 100..112, z 15..16): a dark cut with duckboards, earth parapets both sides under snow, revetment stakes, sandbags on the far side (drawn on the slab; nobody can reach it) |
| guard post | a sandbag ring three high with a plank roof under snow outside the track's north wire by the clearing's mouth (80, 32), a field telephone box, a lantern |
| revetments | earth berms with a course of sandbags along both long sides of the two propellant trailers and the generator; a sandbag skirt on the guard hut's north and west walls; the dugout's earth faces under old snow with a cap of fresh snow |
| bowsers | a ladder up the flank, a catwalk and handrails on top, manhole domes, the delivery manifold (a header, three valve wheels, two gauges), a hose reel, mudguards, a tool box; the oxidiser's frost bands and frost on its valves; drip stains |
| erector trailer | the arm's rest cradle (its pad meets the lowered arm's rails), the pump set and its oil tank with pipes to the rams and a valve wheel, side lockers, tail lamps, a chain; rust and grime along the frame; the arm itself gets riveted gusset plates, rust at the joints and grime down the rails |
| generator | three cables out to the table, the floodlight and the fuel trailer, a cable drum, its switch panel, soot over the exhaust; a camouflage net of its own on four poles at its corners |
| nets | rebuilt (`MapRocketGen.net_canopy`): 0.8 m patches of net, scrim and cut boughs at jittered heights and tilts with holes the sky shows through, a ragged skirt down every side, boughs and snow lying on it, top rails between the poles |
| the table | its nets rolled onto four corner poles that stand inside the table's footprint, lashed, a bough caught in each; no beams across the top (the fins span 3.56 m on the axes and pass between the poles at lift-off: render `22_launch_5_lift_after`) |
| firing cables | three cables in a bundle from the dugout to the table on stakes, a plank cover where the path crosses, a junction box on the table's leg |
| dugout | timber facing boards each side of the doorway, grime round it, the FEUERLEITSTAND board over the door, a stove pipe with soot, a tool rack (shovels, a pick, an axe) on the north face, firewood on the east face |
| hut | a water butt, a fire bucket rack, grime along its south wall, the WACHE board |
| clutter (in the clear bands along the wire) | drums of alcohol, jerrycans, stacked duckboards, a cable drum on its rim, empties, a timber pile, a tool rack, stacked planks; tarps lashed over two crate stacks. T-276's five drums and the extinguisher that stood in the walk with no collider moved into the bands |
| signs (plain German, no names) | FEUERGEFÄHRLICH! RAUCHEN VERBOTEN (fuel), VORSICHT! FLÜSSIGER SAUERSTOFF (oxidiser), LEBENSGEFAHR! ABSTAND HALTEN (the floodlight mast, facing the mouth), FEUERLEITSTAND, WACHE, VORSICHT! STARKSTROM (generator) |
| ground | tyre ruts from the mouth to the towbar, both trailers and the generator; a half-track's tread loop round the south of the table to the dugout; trodden footpaths between the hut, the table, the dugout and the generator (all 1-2 cm flat); snow banked against the dugout, the hut and the bands, drifted against the wire outside |

Where the pieces stand: inside an existing solid's footprint, in the 0.5 m band the bake keeps clear round a solid or
along an edge wall, or beyond the walls. The forest leaves room for the trench, the guard post and the poles
(`MapRocketDetail.forest_keep`), so the site's own trees (not the grounds' tree line) were re-drawn.

## Cost

| east of the old fence (x > 60.5) | before (master) | after |
|---|---|---|
| draw surfaces (static) | 171 | 77 |
| triangles | 48.5 k | 106.2 k |
| of them shadow-casting | 28.9 k | 52.5 k |
| lights | 9 | 9 |

The surfaces fall although the pass adds a great deal: the whole site's dressing (T-276's and this) is now merged into
one mesh per material and shadow setting (`MapRocketDetail.bake_site`, called by `MapRocketGen.bake_dressing`, one
line in `gen_map00._process` after the perk-spot and wall-buy audits, which look at every drawn mesh, and before
`merge_static_meshes`, which still files the merged meshes into StaticBatches by their position at the clearing's
middle, so the T-266 shadow proxies and occluders see them and they never join the inn's batches). The price is
coarser culling: when any of the site is in the frustum, all of it draws (it was cut into 12 m cells by material).
For a CPU-bound frame that is the right trade; the site is behind the trees from the inn. The many small round
things (bags, boughs, snow lumps) use an 8 x 4 sphere (56 triangles; Props.ball's is 144); small parts cast no
shadow. Whole map: 1245 -> 1149 meshes, 438.7 k -> 496.4 k triangles.

## Checks

- Navmesh fingerprints (`test_map00_art`): byte-for-byte T-276's after every regeneration; 738 collision boxes as
  before. Scene diff against master's: gone 0, moved 0 (added: the detail; one decor collision shape: the guard
  post's lantern takes shots like every lantern).
- `MapRocketDetail.audit` (printed by the generator): the 21 tall pieces' footprints against the baked navmesh, 0 on it.
- The minimap was not rebaked: the layout, the zones and the POIs are unchanged (`test_mapdata` passes).

## For the owner's eye

- Everything is seen in the software Compatibility renderer, where nights are very dark; please look at the site on
  the GPU at night and at noon.
- The merged site draws as one piece: if a frame-rate check on a weak GPU shows the site costly from the grounds,
  split `bake_site` into two or three regions.
- The rocket's black-and-white quarters still read weakly in daylight in the software renderer.

## A DECISIONS paragraph, ready

**T-279, 2026-11-25: the V2 site's second detail pass (the owner: "the rocket area needs another pass for details and
stuff too").** Branch `claude/rocket-detail`, notes `docs/u21/t279_rocket_detail.md`, before/after renders
`docs/captures/t279/` (T-276's cameras). All dressing, in `gen_map00_rocket_detail.gd` (`MapRocketDetail`): no collider
added or moved, so the navmesh is byte-for-byte T-276's (fingerprints unchanged), and the zones, spawns, Rocket Man's
spot, the gate and every timing and prompt with it; the pieces stand inside existing solids, in the 0.5 m bands the
bake keeps clear, or beyond the walls, and an audit in the generator checks the tall ones against the navmesh (0 on
it). Added: a wire fence drawn on the invisible edge walls (cut at the spawn pockets), a field telephone line on poles
to the dugout, a slit trench and a sandbagged guard post outside the wire, earth-and-sandbag berms round the trailers
and the generator, detailed bowsers (ladders, catwalks, manifolds, valves, frost) and erector chassis (rest cradle,
pump set, lockers), the gantry's gusset plates and weathering, the nets rebuilt as mottled draped patches with holes,
a skirt and boughs (they read as flat dark roofs), a net over the generator, the table's nets rolled on corner poles,
cable runs, clutter in the bands (drums, jerrycans, duckboards, timber, tool racks, tarps; T-276's walk-blocking drums
moved there), plain German notices, ruts, tread marks, footpaths and snow banks. Cost: the whole site's dressing is
merged into one mesh per material after gen_map00's audits (`MapRocketGen.bake_dressing`, still filed into
StaticBatches), so its static draw surfaces fall 171 -> 77 while its triangles go 48.5 k -> 106 k (shadow-casting
28.9 k -> 52.5 k); no light added; coarser culling of the site is the trade. Verified: full GUT 2650 tests, 2649
passing, 1 risky (known); smokes rocket_site, rocket_man, rocket_launch, map00 x4, ladders, map_detail, bots_shop_m0
PASS. Honest state: seen only in the software renderer; not played.
