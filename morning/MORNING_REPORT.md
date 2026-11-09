# Morning report: TOUCH-UP after your look, 2026-11-09 (evening)

**You said the stairs looked bad and the new building on Map 2 looked bad. I rendered the same views here (under WSL,
off your screen) and saw it: the attic flight's under-stair was open to the hall and its panels had gaps, the attic
was nearly unlit, and the Waschkaue was a black brick box with two black holes.** All three are redone on branch
`claude/maps-1-2-production`; the shots below are from this machine, so I have now seen them.

## What changed
**The Inn's attic flight.** Solid steps with a nosing on every tread, a footboard at the ramp's start, a closed string
over a panelled under-stair whose panels now tuck behind the string, the little cupboard door framed, and the
under-stair's east end, which was never drawn (you looked straight into the cavity from the hall), is a wainscoted
wall floor to ceiling with skirting, chair rail and cornice. Fascia boards cap the attic floor's cut edges round the
well. The wainscot, a wall rail and a sconce follow the flight up the south wall. The hall runner and the ceiling beam
that crossed the open well are cut back. The attic's lamps are stronger and three more hang (over the well, mid-room,
mid-flight): the room reads now.

**Kaltenbrunn's Waschkaue.** A lean-to roof against the yard wall (zinc sheets under snow, rafter tails, a fascia, a
gutter and downpipes, barge boards, the stove's brick stack through it), a plinth and corner pilasters, one lintel band
with WASCHKAUE on a board over the pier, steel sliding doors slid back over the pier on their rail, a lantern on a
bracket at each corner, the night shift's brazier in front of the pier, a lit barred window in each gable end. Inside:
the boarded underside of the lean-to on its rafters, wire baskets on the chains, numbered lockers, duckboards.

## Shots (this machine, software renderer: darker than your GPU, no fog or bounce light)
- `morning/screenshots/u05/touchup2/` attic_stairhead, attic_flight (the flight from the hall), attic_well (down it).
- `morning/screenshots/u10_map01/touchup2/` A_kaue_front (from the headframe), A_kaue_corner (from the north-east);
  `touchup1/00_A_kaue_inside.png` for the inside.
- The `touchup0` folders are the "before" renders of the same cameras.

## Checked
- Both generators save, WALLBUY_AUDIT clear (7 + 9). Facing runner unchanged (Map 0 63 OK; Map 1 70 OK + the 3 desk
  pickups as before). probe_invisible_walls unchanged.
- Unit: test_map00 (60), test_map01 (24), test_map01_edges, test_capture_cams PASS.
- Smokes: map01, map01_systems, map01_world, map00, map00_alive, map00_cellar_bay, map00_loop PASS.
