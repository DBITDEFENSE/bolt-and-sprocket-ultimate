# Morning report: MAPS 1-2 PRODUCTION PASS, 2026-11-09

**The Inn has a third storey, a bigger bar and a grenade buy. Kaltenbrunn starts you in the miners' changing house,
and its Core Vault got a perk machine and a working corner round the Crucible. Every wall gun on both maps is now
checked by the generator and lit.** Branch `claude/maps-1-2-production` (on top of the Fernflug plane pass), not yet
merged: I could not look at any of it rendered, so please eyeball the views below first.

## What changed, map by map
**Map 1, the Crossroads Inn**
- **The attic.** Up a new flight along the upstairs hall's south wall (where the hall runner was), through a railed
  well, into the roof space over the three guest rooms: trunks, the apple racks, a washing line, the cousins' rocking
  horse and cradle, the Christmas boxes, the chimney breast with their chalk girls on it. Two gable windows with hoist
  ledges feed zombies in, so it is a holdout, not a free camp. The BAR (1800) and a frag box (250) are chalked up there,
  both "off GRAVELIGHT ONE". Minimap floor "Attic".
- **The bar.** The counter is 1.1 m further west and runs further north; the walk behind it is 3.7 x 5.1 m (was
  3.2 x 5), and the floor between the counter and the tables gained 0.6 m. Panelled front, oak top, brass foot rail,
  eight stools, the flap, two taps, the till, a mirror behind three bays of bottles, a cask on its cradle, a price board.
  The walkway to the Old Cellar door is wider than before (1.55 m).

**Map 2, Kaltenbrunn**
- **The start.** You begin inside the WASCHKAUE on the yard's south wall: benches, lockers, a stove burning, the tag
  board, and the miners' clothes baskets hanging from the roof on their chains (the high ones are the men still below).
  Two wide doorways face the headframe. Your sled with the kit from the inn stands outside; your trail runs in from the gate.
- **The Core Vault.** Skyhook Sekt stands under the north wall between the two ramp doors. Round the Crucible: the
  installers' bench and crates, gauge stands on the pit rim cabled to the cage, conduit along the walls, caged lamps on
  the pillars, red lamps at the doors, a jib crane over the apron, salt and puddles, luminous lines from every door.
  Every perk machine on the map now cuts the navmesh (zombies path round them). Ledger Lager no longer stands inside a
  filing cabinet.

**Both maps: the wall guns.** The generators refuse to save a scene if anything drawn stands in front of a chalk
outline or if a chalk floats off its wall. That found three on the Inn (planks over the Kar98k, a hoist bracket over
the Thompson, the new attic's rafters and wardrobe over the BAR), all fixed. Every chalk on both maps has a bracket
lamp and a warm light.

## Checked (headless)
- Generators regenerate both scenes; `WALLBUY_AUDIT` clear on 16 buys.
- Facing runner: Map 0 63 interactables OK; Map 1 70 OK (3 quest pickups on desks unreachable by design, as before).
- Smokes: map00 (+ new attic path checks), map00_alive, map00_cellar_bay, map01, map01_systems, map01_world PASS;
  the longer set is in `.smoke_logs/m12/s4/summary.txt`.
- Unit tests: the Map 0 / Map 1 suites, machine lore, Crucible rooms PASS; navmesh fingerprint re-set (T-224).
- Minimaps re-baked for both maps under WSL; `check_mapdata` PASS.

## Please look (DevLauncher, or `tools_src/capture.gd --set=u05` / `--set=u10_map01`)
- Inn: the attic from the stair head and from its east end; the bar from the taproom and from behind it.
- Kaltenbrunn: the Kaue from inside and from the headframe loop; Skyhook and the Crucible's corner in the Core.
Details and the exact camera names are in `morning/NEEDS_DEVIN.md`.
