# T-247: the world text and its font (UPDATE 18)

**T-247, 2026-11-14, the owner** (eight screenshots of the Inn, mostly the Helvetia cellar and its late-delivery bay):
"WE NEED TO DO SOMETHING ABOUT THIS CRAPPY FONT AND TEXT ON STUFF, REMOVE OR MAKE IT MORE SUBTLE."

**What read badly.** Almost every word painted in the world was a bare `Label3D` with Godot's defaults: the clean UI
sans, *unshaded* (so it ignored the cellar's lamps and glowed in the dark like a HUD overlay), bright cream at 0.7-0.95
alpha over dark stone, and on every interactable (`Interactable.add_label`) a 6 px black outline on top. The perk
machines' names were tinted HDR (x1.6) when the power was on. Map 0's cellar alone carried twenty-odd decorative lines:
company names on walls, crate consignment stencils, a chalked cellar book, vintages on casks, VORSICHT STUFEN, and a
real place name (GROOM LAKE) on a crate.

## The one look: `SurfaceText` (gravelight/world/surface_text.gd)

Every generator and world script styles its surface text through one helper, so a sign on the Inn's wall, a wall-buy's
chalk and a perk machine's board are the same paint on every map:

- **A period face from the repo's own fonts** (assets/third_party/google_fonts, already shipped and licensed; no new
  asset): `PAINT` Stardos Stencil Regular (SIL OFL 1.1) for stencilled or brushed paint, `CHALK` Special Elite (Apache
  2.0, the rough, uneven typewriter face) for chalk, `PRINT` Old Standard TT (SIL OFL 1.1) for ink on paper and engraved
  brass or enamel plates. `FLOAT` (Special Elite, unshaded, no outline) is kept for the one label that hangs in a glow:
  the rolled weapon's name over the Crucible and the crate.
- **Lit by the scene** (`shaded`), no outline, never an HDR colour; fixed to its surface (never billboard, never
  fixed-size, depth-tested); casts no shadow.
- **Low contrast**: the colour is pulled toward its own grey (35 % paint, 50 % chalk, 15 % print), a light colour is
  dimmed to 84 %, and alpha is capped (paint 0.72, chalk 0.66, print 0.9), so the surface shows through.
- **A hand-made wobble**: up to 0.9 degrees off true, seeded from the text (no RNG state, so the generators stay
  byte-stable).
- **Distance fade**: text fades out over 6 m around 22 m (`visibility_range`, fade self): the room you are in
  still reads, the rest of the map is not a wall of words.

Routed through it: `Interactable.add_label` (every door price, wall-buy, perk, switch, trap lever, quest object on every
map; a new `look` argument), `Props.stencil` / `Props.crate` / `Props.signpost`, `GenDetail.poster` / `enamel_sign`
(print), the label helpers of gen_map01, gen_map02 (and its floor chalk), gen_map04_lib, gen_map04b's intercom plate,
detail_map04b's chalk, the Crucible rooms' notices (print), the bank branch sign, the Inn's hanging sign
(landscape.gd), the perk machines' maker's plate (print). The callers that re-added an outline after `add_label`
(aux bus, decompression, wing chest, wing hatch, power switch lamps, trap levers) no longer do. detail_map04d's own
house face and its deliberately lit Darkmatter signage, paper_decor's printed sheets, the cinema sets and the purple
Plan stencil that fades in when a machine is shot (a fine-print reveal) are left as they were.

## Made subtle (kept: the text players need)

- **Wall-buys**: name and price chalked over the board in Special Elite, 17 px (was 20 px stencil bold, pale green,
  6 px black outline, unshaded), lit by the board's buy lamp. The HUD prompt ("Hold F to buy ...") is unchanged.
- **Perk machines**: the name on the sign board is paint on the board, toned (no x1.6 HDR when powered; the machine's
  own neon tube and PerkGlow light still light it), no outline; the name/price plate keeps the typewriter face, lit;
  the maker's plate is engraved print, no outline. The tube round the name board (the cabinets' Neon part and the
  shaped machines' sign tubes) glows soft in the tonic's colour (`glow_soft`, energy 1.4, was the full `neon` at 4.5 that bloomed into the white box of the owner's 133444/133450); dark glass
  before the power, as before.
- **Directional signs on Map 0**: KELLER, AUSGANG · KELLER (smaller), the hanging enamel plate in the vault now just
  "NACHLIEFERUNG →" (the tonic names on it are gone) and KELLER · TREPPE on its back, "→ KELLER II" in the Old
  Cellar's breach (was "→ HELVETIA / KELLER II" at 30 px: chalked, 24 px, lower), DARLEHENSKASSE over the bank shed,
  STRASSE GESPERRT on the sawhorse, the Inn's hanging sign, the signposts.
- **Story text kept** (CANON: Jakub): the miner's greeting SZCZESC BOZE and its tally chalked in the coal cage, the tag
  on his cage, the husband's KRAUSE 1916 trunk in the attic, FANNY over the horse's stall.
- **Ammo box** (every map): one AMMUNITION stencil through a card, 24 px, toned. **The crate**: its lot number only.

## Removed (decorative, no clue, nothing points at it)

Checked first against the quest, intel, objectives, VO and map data (`data/`, every `*.json`): no quest, note or
line refers to any of them.

- **Map 0, the Helvetia cellar and the bay (13)**: HELVETIA AUTOMATEN AG / MONTAGE 7 over the fuse box; the glass
  crates' HELVETIA AUTOMATEN AG and ZERBRECHLICH; the chalk tally over the bench; NACHLIEFERUNG in big letters on the
  bay's lintel; HELVETIA AUTOMATEN AG / NACHLIEFERUNG · 2 STÜCK on the far wall; the delivery note's typed lines (the
  sheet and its pin stay); the HELVETIA stencil and ZWEIGWERK THALBACH W.T. · AUFRECHT on Skyhook's crate; THIS SIDE
  UP and RANGE SUPPLY / GROOM LAKE on Magpie's olive crate and lid (a real place, and English on a Swiss delivery); the
  second line of the hanging plate.
- **Map 0, the Old Cellar (10)**: VORSICHT STUFEN; the three cask vintages 1937 / 1941 / 1943; the chalked cellar
  book (RIESLING / ROTWEIN / SCHNAPS); EIS; KREUZWEG HAUSWEIN and 1942 on the barrel stack; KAMIN.
- **Map 0, the yard (1)**: the bank shed's small print plate (the cream panel stays).
- **Map 0, crate stencils elsewhere (5)**: SALZ (hayloft), 7.92 (the yard), WH (the guard's crate by the cage), WH
  Nachr. (the taproom), WEIHNACHT (the attic). Map 0 went from 54 Label3D to 28.
- **Every map, scripts (8)**: the ammo box's three lines of small print, its lot plate and its two end stencils; the
  crate's NICHT KIPPEN small print, maker's plate and the lid's AUSGABE stamp.
- **Map 1 (5)**: the timetable small print under the shift board, the mine plan's 12 px caption, the notice board's
  12 px heading, SALZ on two crates.
- **Map 2 (5)**: ZERLEGUNG · LOS 44-209 on the pen wall, the ledger's 10 px title, the tally sheet's 12 px lines, the
  log book's 9 px title, the small warning under PUMPENSCHALTER.
- **Map 4c (3)**: SAMPLES on the three sample crates.
- **Kept on purpose**: Map 4c's GROOM LAKE signs and its consignee stencil: Groom Lake is the act's setting (the owner's beats, T-102,
  T-110: the intro card, the campaign title), so the world agrees with the story there; Map 2's tide board (an intel
  document quotes its times); the Inn's signposts (KALTENBRUNN, WILCZA GÓRA, BRESLAU: road signs of the setting,
  1944 Silesia, restyled only).

## The waypoint marker

The world marks' label (core/map/world_marks.gd; "The Old Cellar · 22 m" over the arrow sign in the owner's 133435)
is smaller (24 px, was 30), its outline thinner (5, was 9), capped at alpha 0.7, fades out over the 4 m after
`near_hide_m` as you walk up to it, and drops to 0.3 within 220 px (at 1080p) of the screen centre, so it never sits
over what you are looking at. Tuning in data/maps/marks.json "world" (label_alpha, label_font_px, near_fade_m,
center_fade_px, center_alpha). Nothing else in the HUD changed.

## The crate in 133457

The "detached top board" is the smaller crate (0.5 m) stacked on Skyhook's 0.95 m crate, turned 10 degrees off it; it
sits on the big crate's top at y = 0.95 (no gap). Without the white stencils on both it reads as two crates.

## Unchanged

Gameplay, timings, hitboxes, navmesh, prompts, the positions of every perk machine and wall-buy. The maps were
regenerated by their generators (their headers: `godot --headless --path . --script res://gravelight/tools_src/gen_mapNN.gd`);
the scene diffs are the text plus the usual per-run `unique_id` / sub-resource id churn. Per map the navmesh
(vertices and polygons) and every collision box are byte-identical to master's (checked by hash).

## Renders

docs/captures/u18_text/: the owner's spots on Map 0 before (master) and after, WSL Xvfb software GL (darker than the
owner's GPU), camera set `u18_text` in data/gravelight/capture_cams.json.

Pairs (before | after): `00_bay_arch` (lintel name, far-wall name gone; the plate reads "NACHLIEFERUNG →" in print;
the boards' names toned), `02_bay_far_wall` (the maker's name gone; SKYHOOK / MAGPIE MEAD painted, the box softer),
`03/04_bay_crates` (the stencils were the only thing visible in the dark; now the crates are just crates),
`10/11_wall_buy_kar98k` (chalk, lit by the buy lamp, no outline), `12_ammo_box` (one stencil), `07_keller_ii` (under
WSL's software light the breach is black: the old unshaded sign floated alone in it; the chalked arrow is lit only
by what reaches that wall, so on the owner's GPU it reads faintly where the old one glowed), and the waypoint labels
in every frame (smaller, dimmer). sheet__before_vs_after.jpg is the contact sheet.

## Verified

check_scripts (917 scripts, 0 failed); the whole GUT suite (2289 tests, 2288 passing, 1 risky that does not assert,
as on master), then test_world_objects and test_perk again after the tube change (16 + 66 passing); smokes map00,
map00_alive, map00_cellar_bay, map00_loop, map01, map01_systems, map01_world, menus, ammo_box, interact: all PASS.
Each map's navmesh and collision boxes hashed equal to master's after the regeneration.

## Left

- A look in a real window on the owner's GPU (the WSL renderer is darker): is "→ KELLER II" readable enough from the
  breach, and are the perk boards' names readable from the vault's middle walk.
- detail_map04d's lit Darkmatter signage keeps its own glow (designed as lit signs); the cinema sets' text is untouched.

