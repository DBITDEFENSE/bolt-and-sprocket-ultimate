# FERNFLUG: "IT'S A PLANE" exterior pass + facing fix (2026-11-08)

Branch `claude/fernflug-plane` (from master 91ae5a0d). Decisions: T-219 (facing), T-220 / T-220 b (the plane pass).
Design notes: docs/MAP4_FERNFLUG.md section 4.10. Layout is untouched: every collider, the navmesh, the spawns and
windows, the buy spots, the egg steps and the round flow are the same (checked by diffing the generated scenes,
below). Codex's zombie work was not touched.

## 1. What changed

### Interactables face the right way (T-219, all four acts)
Acts II, III and IV were authored with the yaw sign flipped: nearly every perk machine, wall buy and ammo box faced
the wall it stands against. Act I was right except the Armorer's Bench. **56 objects were turned to face the room**
(1 on Werk Thalbach, 18 on the Kranich, 20 at Groom Lake, 17 on Mondlicht); each is a plain 180° (or 90°) turn in
place, except the Lodestone workbench at Groom Lake, which also moved 0.7 m onto its bench (its parts used to float
0.9 m off it). Prompts, use boxes and the bots' stand points are children of each object and turned with it.
**The Crucible was left exactly as it was** on every act.

- Every object, its old and new yaw: `docs/captures/fernflug/facing_after.md` (the before list: `facing_before.md`).
- The check: `tools/tests/test_interactable_facing.gd` (headless; reads the scene's navmesh and colliders; fails on
  any interactable whose front faces a wall or whose use box can't be reached from the navmesh). Fernflug: **PASS**
  on all four acts. GUT: `gravelight/tests/unit/test_interactable_facing.gd`.
  `godot --headless --audio-driver Dummy --path . --script res://tools/tests/test_interactable_facing.gd`
  (`-- --maps=map00,... --report-only` for other maps).
- On the Kranich the painted backing plates behind the wall buys were removed (with the buys turned round they
  would have covered the chalk outlines).

### The Kranich looks like a plane (T-220, Act II)
Seen from the wing walk, the blisters, the flight-deck glass, the bay and the breaches:
- **The hull**: a swept flying wing 268 m tip to tip built at load (`KranichExterior`, data `map04b_plane.json`):
  rounded leading edge, thin trailing edge, wingtip caps, fairings over every room roof and the engines, the skin
  dropped behind the gun blisters so the gunners still see out. The hull shader paints riveted panels with seams that
  stay visible at any distance, per-sheet tint and sheen, access hatches, oil streaks, soot fans, frost, a worn
  bare-metal leading edge, dark non-skid strips under the catwalk and a light walk-limit line round it. Fictional
  markings only: the unit code "KR + 01" (26 m, each outer wing), "01" at the tips, "NICHT BETRETEN" along the walk,
  "HEISS" by the nozzles, "NOTAUSSTIEG" at the hatch. No emblems. A cold fill light on the hull's own render layer
  makes the metal read at night without brightening the walk, the squad or the zombies.
- **The engines**: four, each with an intake, a top fairing, a nozzle with heat shimmer and a warm glow at night,
  soot behind it.
- **Structure**: dorsal and wingtip masts with aerial wires, a dorsal gun turret, the navigator's astrodome, crew-size
  hatches, nav-light pods (steady red/green, white double-flash strobes at the tips), a warm lamp on every tether
  post; the formation's bombers re-skinned as the same wing.
- **The sky**: a moonlit cloud deck far below to the horizon with the sea through its gaps and haze; the near cloud
  sheets scroll past; cloud banks (puffs + a fog volume) stream through and over the wing every 55-120 s; at dawn the
  key light swings from the moon to a low sun behind the wing (matching the act's night-to-dawn clock).
- 56k triangles, nothing collides, every face is invisible from inside the plane.

### The Kranich feels like a plane (T-220)
- **Wind audio**: two loops (wind roar, the engines heard from outside) follow how exposed you are, through audio
  zones: silent inside, about a third at the blisters and the flight-deck glass, full on the wing walk, more with the
  bay doors open or by a blown breach. The engine drone everywhere is the map's existing bed. New synthesised sounds:
  wind roar, engine outside, three airframe groans.
- **Motion**: tarps, ropes and streamers flutter; a lashed crate and a jerrycan buzz on the skin; hanging lamps and
  straps vibrate. The sky, clouds and key light bank up to 2.6° and recover (the world moves, not the floor); it
  pauses while the gameplay tilt runs.
- **Turbulence** (`KranichAir`): every 70-150 s a light shake, a rattle, a groan and a flicker of nearby lamps, only
  in a quiet moment (no boss alive, no cutscene, no egg holdout, no tilt, decompression, bomb run or London window,
  at most 2 zombies within 12 m, no hit in the last 5 s, no quest step in the last 25 s); skipped if none comes.
- **Comfort setting**: Settings > Gameplay > **Camera Sway / Turbulence: Full / Reduced / Off** (default Full). It
  scales every flight camera motion: the tilt's roll (8° / 3.2° / 0°) and the bank and turbulence shakes. Off keeps
  all visuals and audio. The tilt's gameplay push is unchanged; weapon and explosion shake stay on Screen Shake.
- Collision and the navmesh never move; all of this is cosmetic.

## 2. Screenshots

- Catwalk and edge views (15, Forward+ on the GPU, off-screen): `docs/captures/fernflug/before/`, `after/`,
  `after_dawn/` (4 dawn views incl. a cloud bank over the wing), side-by-sides in `side_by_side/` and
  `side_by_side/sheet__before_vs_after.jpg`. Capture set `fernflug_plane` / `fernflug_plane_dawn` in
  data/gravelight/capture_cams.json.
- In front of every interactable (210 cameras on the four acts, on the open side, WSL software render so it looked
  flat and dark): `before/interactables/<act>/`, `after/interactables/<act>/`, and 56 side-by-sides of the turned
  ones in `side_by_side/interactables/`. Capture sets `facing_map04a..d`.

## 3. Facing report

| Act | OK after | Turned | Left as is (listed below) |
|---|---|---|---|
| Werk Thalbach (map04a) | 52 | 1 | 1 |
| Der Kranich (map04b) | 66 | 18 | 1 |
| Groom Lake (map04c) | 52 | 20 | 3 |
| Mondlicht (map04d) | 35 | 17 | 0 |

Left as is (they need a move, which is a layout call):
- **Werk Thalbach, AmmoBox_Halle**: buried under the hangar's west catwalk ramp; usable only from the ramp's foot.
- **Kranich, AmmoBox_Galley**: turned like the others, but it overlaps the end of the Bordfunk desk by about
  0.4 x 0.5 m (players reach it from the north). Moving it to z 50.6 would clear the desk.
- **Groom Lake, the generator's power switch**: its front still faces the wall; it stands in a 1.45 m strip with no
  navmesh between the generator shed and the north wall, so bots can't reach it. Its own comment says it belongs on
  the shed's south face.
- **Groom Lake, the Lodestone gimbal part**: sits inside the radar mast's collider (players take it from the tower
  base). A quest position, not a facing.
- **Groom Lake, the exfil beacon**: free-standing in the silo, no side clearly right.
- For information (not changed): the Kranich's perk machines stand 0.65-0.95 m off their walls (Act I's 0.3-0.55 m);
  three objects hang off their walls a little (WallBuy_springfield on Mondlicht 0.35 m, WallBuy_m1_garand on Werk
  Thalbach 0.15 m, ShaftGrateLever on Mondlicht 0.75 m); Groom Lake's AmmoBox_Motorpool stands in the middle of the
  Door_Lab doorway (it always did).

**Other maps (report only, nothing changed)**: Maps 0, 1, 2 and the test range have no wrongly facing interactables.
Flagged: Kaltenbrunn's Ledger Lager machine overlaps the `FilingA` filing-cabinet collider (worth a look); Kaltenbrunn's
two quest radios and `Cylinder3` show as unreachable (they sit on shelves the check can't see as floor); Totenhafen's
two pen-hall doors show as unreachable (no navmesh inside their 3 m deep doorways; players reach them).
Full table: `docs/captures/fernflug/facing_other_maps.md`.

## 4. Checks

- Scene diff: the regenerated map04b (facing + plane) against the facing-only scene: 408 collision/navigation nodes
  identical, 17 navmesh vertex arrays identical, all 124 gameplay nodes' transforms identical; added only the
  exterior, the turbulence node and dressing. The facing worker diffed all four acts against master: only the 56
  transforms changed.
- Fernflug smokes, 0 script errors: map04_egg, map04_flow, map04_full, map04a/b/c/d and their _world variants,
  turbulence, wing_walk: **all PASS**. Unit tests: test_interactable_facing 15/15, test_kranich_plane 14/14,
  test_ui_polish_t218 9/9 (incl. the Settings row), test_capture_cams, test_map04b_data; full suite: SUITE_RESULT.
- Soaks (bots, headless, x3 speed; `tools/ai_soak.sh --scenario=fernflug`): before (master's scenes) and after,
  interleaved per seed so both saw the same machine load (other sessions held the CPU at ~70 %):

  | Run | Rounds | Bot downs | Stuck events (s) | Teleports | Scrip spent | Doors |
  |---|---|---|---|---|---|---|
  | Act I seed 1, before | 1-11 | 0 | 115 (129) | 7 | 31,950 | 8 |
  | Act I seed 1, after | 1-11 | 0 | 127 (149) | 8 | 41,300 | 8 |
  | Act I seed 2, before | 1-11 | 5 | 186 (239) | 9 | 34,550 | 8 |
  | Act I seed 2, after | 1-11 | 1 | 199 (261) | 13 | 34,250 | 8 |
  | Act II seed 1, before | 15-18 | 5 | 110 (119) | 7 | 76,200 | 4 |
  | Act II seed 1, after | 15-16 | 7 | 13 (27) | 0 | 62,650 | 4 |
  | Act II seed 2, before | 15 | 4 | 1 (2) | 0 | 9,450 | 2 |
  | Act II seed 2, after | 15 | 3 | 6 (9) | 0 | 29,700 | 3 |

  Act I (the order's rounds 1-10) reaches round 11 in every run before and after, every door opens, the bots spend
  their Scrip on the turned perks, guns and boxes as before; stuck events and teleports move within the run-to-run
  spread (seed 2 vs seed 1 differs more than before vs after). Pathing: unchanged by construction (the navmesh is
  byte-identical), and the soak shows no new snag spot. Act II standalone starts the squad at match round 15 with
  the soak's kit, so it wipes within 1-4 rounds either way; it only shows that the act loads, plays and the bots
  shop. An earlier after-run (17.8 min, 201 stuck) ran beside the WSL screenshot renders and is not comparable.
  Use: the facing check proves every perk, wall buy, ammo box and crate spot has a reachable use box on the open
  side, and the bots buy from them in the soaks; I did not try each one by hand in a rendered session.
- Performance (`gravelight/tools_src/perf_marks.tscn`, round 15, ~20-24 zombies kept alive, 3 bots, preset ultra,
  vsync off, RTX 5090, rendered off-screen; `--no-plane` skips building the new exterior and turbulence nodes):
  - **Not confirmed.** Every measurement ran while other sessions held the CPU at 70-90 %, and the same setup swung
    between 47 and 173 FPS. My final three interleaved pairs on the wing walk (-80, 3.4, 21), with / without the plane:
    54.8 / 46.6, 78.5 / 172.7, 152.0 / 149.2 FPS average. No verdict either way.
  - The cleanest earlier reading (the plane worker, before the legibility pass, median of 3): spawn 160.6 vs 163.8 FPS
    (about +0.1 ms), wing walk 160.0 vs 178.2 FPS (about +0.6 ms). The legibility pass then removed 26k triangles and
    added one shadowless light on the hull's own layer, four glow quads and two strobes.
  - To settle it on a quiet machine (close the game and other tools), run each three times and compare the averages:
    `Godot --audio-driver Dummy --position -4000,-4000 --resolution 1920x1080 --path . res://gravelight/tools_src/perf_marks.tscn -- --map=map04b_kranich --pos=-80,3.4,21,90 --no-marks`
    and the same with `--no-plane` added. The budget the order sets is "no meaningful frame-time hit" (about 0.5 ms).

## 5. For you to decide

- **Camera Sway Off and the horizon's slow bank**: Off stops every camera motion but keeps the sky's slow bank (the
  world moving, which the order asked to keep as a visual). Say if Off should hold the horizon still too.
- **The fine-print panels on Acts II-IV** are now on the cabinets' backs against the wall, like everywhere else (the
  lore's "riveted where nobody looks"); before the fix they faced the room and were easy to read. Nothing in the eggs
  needs them (Mondlicht's columns quote the panels themselves).
- **The five objects left as is** (section 3): each needs a small move.
- **The paint** is lighter than a real night bomber so it reads at night; darker is one number in map04b_plane.json.
- **The cockpit glass** looks out at sky only (no nose below it); the bay with its doors open still shows the old flat
  sea plane below rather than the new cloud deck.

## 7. Follow-up: lighting, the sunset bomb run and trailer tools (T-221, T-221 b, T-222)

The owner: "the lighting needs to be improved on the map ... make the sunset look great the bombs dropping, and the
lighting around it, too many dark areas and the textures on some hallways are messed up". Layout untouched on all
four acts (collision, navmesh and gameplay nodes hashed identical); no gameplay timing changed.

**Der Kranich (Act II, T-221 / T-221 b)**
- **The golden hour**: the act's clock still runs night to dawn (the story stays dawn), but from act round 4 into 5
  it turns into a low golden sun and holds it through the bomb run: a big sun disc with glare and rays, an orange-gold
  horizon band going magenta then deep blue overhead, the cloud deck's tops hot orange over violet-blue shadows, thin
  haze, a gold key light streaking the rails and the hull's seams. The U12 grade keeps the saturated sunset colours.
- **The bomb run**: the low sun comes into the bay through the aft ramp seam (god rays through the racks, dust in the
  shafts), each dropped rack's hatch glows from below; outside, the casing falls away under the belly, tumbling, with a
  sun glint and a thick vapour trail, into the cloud deck; a live one ends in a violet flash that lights the clouds from
  below. Visual only: timers, jams, cities and flags are unchanged. The bay doors are not shown open (their aisle is
  walkable floor).
- **Dark areas**: 50 shadowless practical lamps (battery emergency lamps from the start, bulkhead lamps the aux bus
  wakes, the flight deck's instruments, the impeller's violet), per-zone light boosts, a cold ambient fill. Interior
  luminance (20 frames): mean 12 -> 26, near-black pixels 73 % -> 47 %. The big rooms are still under the art bible's
  targets (a look-file number if you want them brighter).
- **Hallways**: the "messed up" walkway floors beside the cockpit were the sky showing through the grating as a white
  grid; dark plates under them fix it.
- **The formation bomber**: a dark rim-lit silhouette with engine glows and nav lights (a stray flat violet card is gone).

**Werk Thalbach, Groom Lake, Mondlicht (T-222)**
- Darkest spots before -> after (mean luminance 0-255, power on): Thalbach's wind-tunnel lane 5 -> 68, Kraftzentrale
  18 -> 49, canteen 10-14 -> 50-62; Groom Lake's hatch 4-6 -> 82-93, trench 7-16 -> 46-61, lab 8-18 -> 40-45, silo
  4 -> 39, hangar 3-8 -> 21-38; Mondlicht's store 12-14 -> 37-66, hall 9-14 -> 27-45. Done with always-on battery
  emergency lamps, more lamps on the power, and exposure zones that open up indoors. GPU cost unchanged (4.57 -> 4.57,
  5.56 -> 5.53, 4.98 -> 4.92 ms).
- Hallway textures fixed: Groom Lake's lab floor and ceilings and the hatch roof used the stone wall texture, the hatch
  and trench ramps smeared, and four places where two walls or floors sat on the same plane and flickered (lab/silo
  wall 97 m², hangar and motor pool vs the salt berm, the trench walls, crossing tyre tracks); Mondlicht's reception /
  hall wall at x 12 flickered white against violet (106 m²).
- Left for you: the Great Hangar from the floor still reads as fog and a grey wing (it wants a moving or high camera);
  Groom Lake's building faces are black against the bright salt at dawn (mood; a brighter outdoor fill is one number).

**Trailer tools** (dev console, any act; `god` and `noclip` first):
- `hud off` hides the HUD, crosshair and viewmodel (`hud off subs` keeps subtitles); `hud on` brings it back.
- `flyspeed 3` slow, eased flying (crouch sinks); `timescale 0.25` slow motion while the camera keeps real-time speed
  (`flyspeed 3 game` slows the camera too).
- `tod golden` (or `night`, `dawn`, `0`-`1`, `auto`) holds the Kranich's time of day.
- `bombrun now` starts the real bomb run; `bombrun drop` releases the next rack now; `bombrun fx 3` replays a rack's
  falling casing as a visual-only take (add `dud` for no flash).
- Staging: the bay drop: `power_on`, `tod golden`, stand at the bay's forward door looking aft, `hud off`, `bombrun now`.
  The wing into the sun: the wing walk near (-75, 3.4, 21) looking aft. The falling casing: the wing-walk corner by the
  nacelle looking aft-starboard and down, then `bombrun fx 2` with `timescale 0.3`. The lit clouds: the aft blister
  looking down. Captured examples: `docs/captures/fernflug/lighting/trailer/` (HUD-free) and a 5.5 s slow-motion drop,
  `trailer/kranich_drop_slowmo.mp4`; the other acts' views in `lighting/<act>/trailer/` (capture sets
  `trailer_kranich`, `fernflug_trailer_a/c/d`).
- Tip: the capture runs used a 110° field of view, which makes subjects small; a narrower FOV frames the drop better.

Left for you on the sunset: the sky still leans purple-magenta overall (warmer is two colours in
`flight_sky_bg.gdshader`); the bomber-crossing-the-sun framing (T04) hides the sun completely at its distance.

## 6. Where to stand

- The wing walk's trailing edge by the port engine, (-75, 3.4, 21), looking along the trailing edge: the nozzle glow,
  the walk-limit lines, the long wing.
- (-80, 3.4, 21.5) looking forward at the nose: the fairings and patchwork catching the moon.
- The wingtip, (-112, 3.4, 24), looking back at the whole wing.
- (-86, 3.4, 20.4) looking aft and down: the nozzles, "HEISS", the cloud deck far below.
- Anything on the wing walk late in the act, at dawn (the low sun behind the wing); wait for a cloud bank to cross.
