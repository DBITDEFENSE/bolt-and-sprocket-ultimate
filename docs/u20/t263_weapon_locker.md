# T-263: the arms locker

The owner, 2026-11-22: "add a weapon locker". Branch `claude/weapon-locker`. Nothing here has been seen rendered
(headless only); see "Not verified" at the end.

## What it is

A steel two-door arms locker on a wall. You walk up and hold [interact]:

| You carry | The locker (your compartment) | The hold does | Scrip |
|---|---|---|---|
| two guns or more | empty | the gun in your hands goes in | 500 (`store_cost`) |
| a free weapon slot, or empty hands | a gun | the stored gun comes out into your hands | 0 (`withdraw_cost`) |
| slots full | a gun | swap: the gun in your hands goes in, the stored one comes out | 500 |
| one gun | empty | nothing ("keep one gun on you") | - |
| a copy of the stored gun in another slot | a gun | nothing until you hold that copy (then it swaps) | - |

The gun is kept exactly as it is: its id (a Crucible name stays), its Crucible tier (I, II, III), its attachments
and finish, the rounds in the magazine and in the reserve, the fire mode, the rifle-grenade count. No refill on the
way in or out.

Prompts (`weapon_locker.json` "text"): "Hold [F] to lock away MP40 [500]", "Hold [F] to take MP40 from the locker",
"Hold [F] to lock away Kar98k and take MP40 [500]", "Arms locker: empty", "Arms locker: empty (keep one gun on
you)", "Arms locker: MP40 inside (you carry one already)". The price shows Ledger Lager III's insider rate like
every other price. A stencil ARMS LOCKER on the doors; a paper card in a brass holder on the right door shows what
*you* have inside (each machine shows its own player's gun, or EMPTY).

## The decisions, and why

- **One compartment per player.** One gun is the insurance; more would be a second inventory. A bought second
  compartment is not built (the contents are one entry per player; it would be a small change in `WeaponLocker`).
- **Per match, not between matches.** The bank keeps Scrip between matches; a tier III gun in round 1 of the next
  match would change the game far more than Scrip does (it skips the Crucible, the crate and three doors). So
  nothing is written to the profile, and because of that the locker is open in Classic Rules, Easter Egg Mode and
  online: the rules that shut the bank are all about the profile and do not apply.
- **It survives the down, the bleed-out and the respawn.** That is its use: in co-op a bleed-out costs everything
  you carry and you come back at the next round with the starting pistol; the gun in the locker is still there.
  A downed (crawling) player cannot use it.
- **Storing costs 500, taking back is free.** Free both ways the locker would be a third weapon slot for nothing
  (Packmule Porter sells that for 4000 and loses it on a down). 500 is two ammo-box refills: cheap as insurance on
  a gun that cost 5000 to teach, not free as a parking place. Taking back is free so the insurance always pays
  out, also to a player who respawned with nothing. Both numbers are data.
- **Never your last gun, never two of a kind.** You keep `keep_on_you` (1) guns after storing; a wall buy of the
  same gun while one is inside does not give you two (the stored one waits until the copy is in your hands, then
  the hold swaps them).
- **Wonder weapons may go in.** There is no one-per-player rule for them that the locker could get round
  (`no_store` in the data takes ids or classes if the owner wants some refused).
- **A campaign hop carries the contents** (`Campaign.snapshot` "locker", restored by `WeaponLocker.attach`). See
  "Open" for what that means while only Map 0 has a locker.
- **Bots and companions leave it alone**: no prompt, `can_interact` false, the locker is in none of the groups the
  bots' errands look through (`weapon_lockers` only). A puppet that became a bot (its owner dropped) is a bot.

## Where it stands

**Map 0 (the Inn): the stable's north-east corner**, on the north wall, doors facing south:
`at [24.25, 0.0, 22.15], yaw 0`. Coming from the taproom through the passage (Door_Stable) and the stable's north
door (x 18.5..21.5), it is 4 m to the left on the same wall: past the bale stack (x 21.6..23.4), in the corner
before the east wall (0.64 m of wall left to the corner). The hayloft stair's foot is 2.9 m south of its doors
(z 25.5), so the stair's approach passes behind a player standing at it, not through them. It is on the armoury side
of the map (the Armorer's Bench, the trench gun, the ammo box and the Tack Room crate spot are in the same room)
and one door from the taproom where everyone respawns.

Measured by `gravelight/tools_src/locker_spot.gd` on the scene file and again on the running map (the smoke):
the wall behind the whole back (9 of 9 probes), a floor under it, no collider in the body box, no navmesh polygon
under it, the standing room free, 4.7 m of free room straight out of the doors, the nearest other machine, door or
spawn 5.8 m away (7.5 m in the scene file; the nearer one on the running map is something built at load), no mesh
without a collider (tack, posters, lamps, story props) in the body box or the standing room, and
interactable_facing's verdict OK with the use box reachable.

**No map was regenerated and no navmesh rebaked.** The locker is built at load from the json row by
`WeaponLocker.attach` (MapRoot), like the bank branch. It is 0.45 m deep and flush on its wall, inside the strip
the navmesh's 0.5 m agent radius already keeps clear, so nothing that paths on the navmesh ever had a polygon
there; players are stopped by its box collider.

Other places on Map 0 the probe found free, and why they were not taken: the taproom's south wall west of the
stable door (the wall is kept for story items: INT_M0_14 hangs at x 17.2); the taproom wall by the Old Cellar
door (beside a door's approach); the stable's east wall at z 23.5..23.75 (in the hayloft stair's approach lane);
the passage's side walls (a walkway); the stable's outside south wall (on the great doors, which fall at the
exfil); the Old Cellar and the guest rooms (free, but out of the way for something you run back to after a
respawn).

**Other maps: none yet (open).** A row in `weapon_locker.json` "lockers" is all a map needs. I did not place them
because I cannot see those rooms and "the measurements pass" is not "the spot makes sense". Spots near each
Armorer's Bench that pass every measurement on the scene file, for whoever picks:
map01 `at [12.02, 0, 4.5] yaw 90` (the bench's own wall, 4.3 m north of it), `[8.0, 0, 3.98] yaw 180`,
`[0.16, 0, 15.0] yaw 90`; map02 `[12.0, 0, 17.17] yaw 0`, `[12.5, 0, 10.17] yaw 0`, `[24.5, 0, 8.01] yaw 0`;
map04a `[39.84, 0, 7.0] yaw 270`. Find more with
`"$GODOT" --headless --audio-driver Dummy --path . --script res://gravelight/tools_src/locker_spot_probe.gd -- --maps=map01 --scan=x0,z0,x1,z1,y`
and check the rows with the same script without `--scan`. The smoke walks every map that has a row.

## How it works

- `gravelight/world/weapon_locker.gd` (`WeaponLocker extends Interactable`): the rules (`plan`, pure), the hold
  (`use`, host / offline), the contents (`_stored`: player id -> one `WeaponHolder.net_entry`), the node (prompt,
  collider, art, the card, a small shadowless lamp over it).
- `data/gravelight/weapon_locker.json`: the numbers, the texts, the sounds, the rows.
- Co-op: host-authoritative like the other machines. A client's hold goes to the host
  (`Player.use_interactable` -> `NetMatch.on_interact`, which first applies the client's current inventory to its
  puppet); the host runs `WeaponLocker.use` with the puppet, whose holder forwards `remove_current` and
  `give_net_entry` to the owner's real holder (the path Jakub's hand-over uses). The contents are mirrored at once
  (`_net_state`) and ride in every state snapshot (NetMatch "wl"), so a client that joins or rejoins late knows
  them; every machine builds its prompt from its own inventory, Scrip and the mirrored contents.
- Sounds: existing ones (`door_creak`, then `crate_close` or `reload_end`); `audio.json` is untouched.
- The model is procedural (`WeaponLocker.locker_art`, merged and cached by `InteractableArt`): olive steel carcass
  on a black plinth, two doors with pressed panels and louvres, hinge barrels, a lever handle, a hasp with a brass
  padlock, the card holder, a cartridge tin on top, a caged lamp on the wall above. 0.92 x 1.9 x 0.45 m.
- `gravelight/tools_src/interactable_facing.gd` knows the locker (RULES row, and the json row in `survey`), so the
  facing test covers it on every map that gets a row.

## Changed outside the new files

`gravelight/autoload/data.gd` (the table), `gravelight/maps/map_root.gd` (attach), `gravelight/net/net_match.gd`
("wl" in the state snapshot), `gravelight/world/campaign.gd` ("locker" in the payload),
`gravelight/tools_src/interactable_facing.gd` (the rule), `gravelight/tools_src/smoke_coop.gd` (the client locks
its Kar98k away after the revive and takes it back after the respawn; the host grants it 1000 Scrip for the rent).

## Verified

All headless, on this PC, 2026-11-22/23.

- `check_scripts.gd`: 972 scripts, 0 failed.
- Full GUT: 2457 tests, 2456 passing, 0 failing, 1 risky (the known `test_neural_lines_are_loudness_normalised`),
  88135 asserts. (A first run in the fresh worktree failed 22 tests on the engine's "invalid UID" warnings and
  nothing else: the worktree had no `.godot/uid_cache.bin`. With the main checkout's cache copied in, the run above.)
- `gravelight/tests/unit/test_weapon_locker.gd`: 18 tests, 106 asserts: store keeps tier / attachments /
  ammunition / fire mode and charges the rent; take is free and gives the very gun back; swap with full slots;
  empty hands and the last gun; no Scrip changes nothing; never two of a kind; the no_store list and busy hands;
  the down, the bleed-out and the respawn; one compartment per player; the snapshot round trip (string keys);
  bots and companions; per match, the profile untouched, open in Classic Rules; the campaign carry; a stale weapon
  id; the prompts; the card; the data rows; Map 0's spot measured on the scene file (and a bad spot caught).
- `smoke_weapon_locker` PASS (27 s): Map 0 loaded for real; the locker on its row; the running map leaves the spot
  free; the navmesh path from the spawn ends at its doors; standing there the player's own use ray finds it and
  the player is not pushed (the collider leaves the standing spot free); a tier II Chicago Lament with an extended
  magazine, 5 + 40 rounds, locked away for 500; `bleed_out()` and `respawn_at()`; the gun still inside; a round
  start; taken back free exactly as it went in; stored again, a Kar98k bought, the swap; nothing in the saved
  profile; a new match starts empty.
- `smoke_coop` PASS (79 s), with two new client steps over the real network path (host + a second headless
  client on 127.0.0.1): "the Kar98k locked away by the host in 0.05 s, the rent paid, the contents mirrored" and,
  after the scripted bleed-out and the round 2 respawn, "the Kar98k survived the bleed-out and came back to the
  respawned client in 0.02 s".
- `tools/run_smokes.sh .smoke_logs/locker map00`: smoke_map00, smoke_map00_alive, smoke_map00_cellar_bay,
  smoke_map00_loop: 4 of 4 PASS, 0 script errors.
- `tools/tests/test_interactable_facing.gd -- --maps=map00`: PASS (0 failing); the WeaponLocker row: front 80 % open, reach yes, "keep".
- `locker_spot_probe.gd` (rows): map00 OK (wall 9/9, room 4.7 m, front 80 % open, nearest 7.5 m, navmesh under it 0).

Not run: the other smokes (bots, squads, campaign, the other maps), since the locker is only on Map 0 and no bot
code changed.

## Not verified, open

- **Nothing was seen.** The model, the stencil, the card's text size and place, the lamp's brightness and whether
  the corner reads well are unchecked on a GPU. The measurements say the spot is free; they do not say it looks
  right. A capture cam for it is not added (`capture_cams.json` untouched).
- **Not on the minimap or the pause map.** The map data is baked (a rendered bake); adding a POI type would change
  the baked signature. Open: add a "locker" POI in `core/map/map_scan.gd` at the next bake.
- **No voice line, no first-time hint, no machine lore plaque.** The prompt is the only teaching.
- **Other maps have no locker.** Until they do, a gun left in Map 0's locker at the campaign exfil travels in the
  payload but cannot be reached on a map without a locker. Either add rows (candidates above) or take the gun out
  before the exfil.
- **The ground spawn in the hay heap** (Spawn_HayPile, round 6+) is 1.9 m from where you stand at the locker. It
  was there first and the heap is not in the standing room; whether that feels unfair is a play question.
- **Balance is a first guess**: 500 to store, free to take, one gun. Not play-tested.
- **Ammunition on a client** is what the client reported with its hold (the host applies the inventory that comes
  with the request), so it is current; the rule was not attacked (a cheating client could report more rounds, as
  it could for any other inventory message).
- **A player who leaves an online match** keeps their compartment under their player id until the match ends (they
  get it back if they rejoin with the same id); nobody else can take it.
- **Solo**: going down in solo is the end of the match or Second Wind (the loadout stays), so there the locker is a
  paid place to park a gun, not insurance.
