# T-249: the Sherman on the first map, rounds 30 to 40

The owner (2026-11-14): "ON THE FIRST MAP ON ROUND 30 CREATE A BOSS BATTLE ADD A SHERMAN TANK COMING TO ASSIST THE TEAM
BUT IT GETS HIT WITH A MASSIVE HORDE AND EXPLOSIVE FIRE ZOMBIES. ADD THE ABILITY THOUGH FOR THE TEAM TO FIGHT OF THE HORDE
AND THEN THE TANK WILL ASSIST FOR ANOTHER 10 ROUNDS WHERE IT GETS HIT BY A STUKA BOMBER. ON ROUND 40 I WANT TO MAKE THE
USER GET BACK IN THE HOUSE FOR COVER BECAUSE THERE WILL BE AIRSTRIKES"

"The first map" is Map 0, the Inn (`map00`; the owner calls it map 1). "The house" is the inn building. Branch
`claude/u18-sherman`, based on `master` at 5e69edda.

## 1. Decision: der Fuhrmann and the Sherman share round 30

Round 30 already belonged to **der Fuhrmann** (T-240, the owner's horse boss on rounds 20 and 30). Both requests are
kept: **der Fuhrmann leads the round-30 horde that hits the tank.** His round runs exactly as T-240 built it (the
reserved round, the horde at 60%, his fight, his rewards, his fail-safe); on the Inn his map row gets its own arrival
beats (`map00.json` `round_bosses[1].arrival`: hooves at 16 s, the scream at 19 s, in at 21 s instead of 0.5 / 3.5 / 6 s),
so he is heard as the tank parks and comes in up the carters' road behind it, a few seconds before the dead rise round
it. Das Totenross stays on round 20 untouched; Kaltenbrunn's round-30 Fuhrmann keeps the block's own beats (the override
is per map row: `HorseRound.attach` merges a row's `arrival` into the block, two lines). The Sherman event is not a
`HomageEncounter` (two of those cannot begin on one round, by the 2026-11-12 review rule), so it runs beside the horse
without touching that rule.

## 2. How it plays, round by round

**Round 30, arriving.** 0.5 s into the round the engine is heard from beyond the south-east edge, at 2 s the banner
("ARMOUR ON THE CARTERS' ROAD / A SHERMAN IS COMING UP TO HELP"), at 2.5 s it drives: in along the road from
(56, 74) past the trees, over the striped sawhorse barrier at the road's exit (the drawing goes flat with a crunch and
splinters; its collider at the map's edge is left alone), up the bend and to a stop on the road outside the yard's
gate at (22.8, 52.8), facing the gate (about 40 m in ~15 s). The turret swings onto the road behind it. Der Fuhrmann
comes in behind it.

**Round 30, the assault** (7 s after it parks). "THE DEAD ARE ON THE SHERMAN / KEEP THEM OFF IT". The tank's health is a
boss bar (the boss kit's `BossHud`; the Fuhrmann's own bar when his is up, so there is one stack of bars); under the
bars a counter: "THE DEAD ON THE SHERMAN: n". **24 of the dead solo, +8 per extra player** rise in packs of four every
3.5 s (at most 12 on it at once) from points 10..16 m round the tank on the grounds, never within 6 m of a player, and
go for it: each is given one of the tank's ten attack points as its `prey` (the hook the Inn's round-1 opening uses for
the fleeing patrons) and beats on the hull (30 per swipe, a clang). **A quarter of them are fire zombies**, spread
through the wave. The team fights them off from the yard (over the fence; shots pass between its upper rails) or out on
the road. The round cannot end while the tank is coming or the wave is still rising (an alive slot held, as the homage
bosses do).
- **It holds** when every one of the wave is dead and the tank still runs: "THE SHERMAN HOLDS / IT WILL COVER YOU", the
  bar is laid down, a Resupply is thrown into the yard, and it starts to help at once.
- **It is lost** if its health runs out: it brews up (the blast, the turret knocked askew, fire, smoke, the ammunition
  cooking off). The rest of the wave turns on the players. The wreck is towed off at the round's end and **a second
  Sherman comes two rounds later** (round 32), the same fight; once (`retries: 1`). Lost twice, there is no help.

**Rounds 31..39, the assist.** From where it stands it covers the yard and the road (45 m, line of sight from the
turret roof): the coaxial machine gun in bursts of 7 at 9 rounds a second every 2.2 s, 3% of the round's zombie health
per hit at 80% hits (a burst takes about a sixth of one of the dead), with tracers, the flash and the M1919's sound;
the 75 mm every 11 s on a pack (two within 4 m) or one farther than 18 m, never within 5 m of a player: 70% of the
round's health within 2 m, falling to 15% at 6 m, with the flash, the smoke, the recoil, the hull rocking, the shell's
burst. The dead hugging the hull (within ~2 m) are under its guns. It never damages players, pays no Scrip, cannot be
hurt in these rounds. With targets everywhere it kills at most about ten a minute; in practice far fewer (the fight is
mostly indoors, out of its sight).

**Round 40, the dive bomber.** The drone high up at 1 s, "AIRCRAFT! / A DIVE BOMBER IS COMING DOWN ON THE SHERMAN" at
3 s; it comes in level from the north-west at 500 m, rolls into a 72-degree dive (its siren wailing up with the speed),
lets the 500 kg bomb go at 110 m (about 11 s in), pulls out over the yard and climbs away. The crew fires the machine
gun up at it. The bomb lands on the tank: it brews up and **burns where it stands for the rest of the match** (fire out of
the turret ring and the engine deck, a column of smoke, a flickering light, the crackle). Anyone outside near it takes
the bomb (the raid's damage).

**Round 40, the air raid** (2.5 s after the bomb). The air-raid siren (repeating every 9 s), the banner "AIR RAID / GET
INSIDE THE INN", the Operator's line OPR_M4A_RAID_01 ("An unscheduled delivery is arriving from above. Please proceed to
the cellars."), and in the middle of the screen the warning with **a 20 s countdown** ("BOMBS IN 12") and a line that
says whether you are under a roof ("YOU ARE UNDER A ROOF" in green, "GET INSIDE THE INN" in red). Then **60 s of bombs**
(OPR_RAID_M2_01 as they start, the bombers' drone overhead): one every 1.6 s (±0.5) on the yard and the grounds. Each
shows **3 s ahead**: a dark shadow on the snow growing to the blast's size and a pulsing red ring at its edge; the
whistle at 2.2 s, the bomb itself falling in the last second. 40% are laid where a player outside stands (within 3 m),
the rest on open ground within 35 m of the squad (so the windows show them). A bomb never lands on the inn or within a
metre of it. Then the all clear (OPR_M4A_RAID_CLEAR_01, "The fires are a feature."); the round goes on as rounds do.

## 3. The numbers

| | |
|---|---|
| Tank health | 8,000 solo, x(1 + 0.35 per extra player) (16,400 for four) |
| A zombie's swipe on it | 30 (12 on it unopposed: 300 a second, ~27 s solo) |
| The wave | 24 solo + 8 per extra player; 25% fire zombies (6 solo, 12 for four); packs of 4 every 3.5 s; 12 at once at most |
| A fire zombie | 45% of the round's health (3,164 at round 30), jog; fuse 0.8 s within 2 m of a player or 1 m of the hull |
| Its burst | 4 m: players 60 at the centre to 20 at the ring (Blastproof: nothing), the dead 35% of the round's health, the tank 600 if it was against the hull; a burning patch 2.2 m for 7 s: 16 a second to a player in it, the dead set alight |
| Machine gun (assist) | bursts of 7 at 9/s every 2.2 s, 3% of the round's health per hit, 80% hits, 45 m |
| 75 mm (assist) | every 11 s, 70% of the round's health within 2 m, 15% at 6 m; never within 5 m of a player |
| Dive bomber | approach 500 m up, 500 m out; 72-degree dive at up to 95 m/s; release at 110 m; the bomb 1.3 s down |
| Air raid | warning + 20 s countdown; 60 s of bombs, one per 1.6 s (±0.5); 3 s telegraph; radius 6.5 m |
| A bomb, outside | 110 at the centre to 30 at the ring (one bomb downs a full-health player only near its centre; two close ones down anyone; Blastproof halves it); inside the inn: nothing |
| A bomb on the dead | 120% of the round's health at the centre, 50% at the ring (round 40: 18,234 health) |

"Inside" is the inn's zones (TAPROOM, UPSTAIRS, CELLAR, OLD_CELLAR), or, where no zone volume claims a point, the inn's
box (x -0.2..24.2, z -0.2..16.2, y -4..10.5). The stable is not the house (a wooden barn): a bomb near it reaches you.

## 4. What was built

- `gravelight/world/sherman/sherman_mesh.gd` (`ShermanMesh`): the M4 in code. Welded hull with the one-piece glacis,
  the three-piece final drive housing with its flanges, sponsons, the rear plate with the air cleaners and the exhaust
  deflector; the driver's and co-driver's hatches and periscopes, the bow machine gun's ball, headlights in their brush
  guards, towing shackles, spare track links on the glacis, the engine deck's grilles and caps, a tarp roll, an ammunition
  box, a jerrycan, the axe and the shovel; the cast turret lofted through eight rounded sections with tumblehome, the
  rotor shield and mantlet, the 75 mm with its sleeve and muzzle, the coax; the commander's cupola with vision blocks and
  its doors open, the loader's hatch, periscopes, the vent, lifting rings, the pistol port, the antenna and its whip,
  the .50 on its post with the ammunition can; vertical-volute bogies (brackets, spring housings, arms, skids, return
  rollers), dual rubber-tyred road wheels with dished spokes, toothed double sprockets with hubs, idlers; the track as
  ~80 links a side (shoe, connectors, guide horn, steel chevron) on the convex hull of the wheels. A plain white star on
  each sponson, the glacis and each side of the turret; no lettering. Olive drab with height grime, local triplanar so
  the paint does not slide on a moving hull; burnt materials for the wreck.
- `sherman_tank.gd` (`ShermanTank`): the rig (it drives a route with steering and speed, the tracks run along their loop,
  the wheels and sprockets turn, the hull rocks when it starts, stops and fires, the turret and gun lay on a point at their
  own rates), the assist's gunnery, the swipes and bursts it takes, the wreck, the co-op puppet. Its collider is on the
  map-edge layer (bit 11): players and bots stop at it; zombies, shots and blasts pass, so the navmesh and every
  zombie's path are untouched (T-240's rail rule).
- `stuka_plane.gd` (`StukaPlane`): the dive bomber in code (inverted gull wings lofted through cambered sections, the
  trousered gear with the sirens, the long glazed canopy and its frames, slatted dive brakes, the tailplane on struts, fin
  and rudder, the three-bladed airscrew, exhaust stubs, the 500 kg bomb on its crutch; dark green over pale blue, a cross
  under each wing and on the fuselage) and its pass (a polyline it follows by time: level, a curve into the dive with a
  roll, the dive, the pull-out, the climb), the bomb's fall.
- `gravelight/enemies/fire_zombie.gd` (`FireZombie`): the burning dead as a node under an ordinary pooled zombie (the
  zombie's own burn-char at 0.9, flames, embers, a light, the crackle); the fuse, the burst, its damage. No edit to
  `zombie*.gd`.
- `fire_patch.gd` (`FirePatch`), `air_raid.gd` (`AirRaid`), `sherman_event.gd` (`ShermanEvent`, the round director),
  `proc_kit.gd` (`ProcKit`, the small mesh kit both models use), `gravelight/ui/sherman_hud.gd` (`ShermanHud`).
- Sounds, synthesized (`gravelight/tools_src/gen_audio_sherman.py`, the horse pack's method, no recordings; licence:
  our own): `sherman_engine` (loop), `sherman_tracks` (loop), `sherman_gun` x2, `sherman_clang` x3, `sherman_cookoff`,
  `stuka_engine` (loop), `stuka_dive`, `firezed_burn` (loop), `firezed_hiss`, `firezed_burst` x2 in
  `gravelight/audio/sherman/`. Reused from the bank: `a1_siren`, `a1_bomb_whistle`, `explosion_large`,
  `war_bomber_drone`, `war_artillery_near`, `fire_m1919`, `fire_crackle`, `horse_boss_crash`.
- Data: `data/gravelight/sherman.json` (every number), `map00.json` `sherman_event` (route, barrier, zones, the inn's box,
  shelter points, the bomber's bearing). A map without the block has no event.

## 5. Co-op

Host-authoritative like the other round bosses: the host decides everything (spawns, damage, bombs). Unlike the homage
bosses (whose clients see the framework's puppet), the event node exists on every peer (`ShermanEvent.attach` from
`MapRoot`, puppet on a client) and the host mirrors what a client must see with `Net.mirror` (world calls by node path):
the tank's spawn and its state (position, yaw, turret, gun, health fraction, mode, speed: 6 Hz while it drives, 2 Hz
parked; the client lerps), its machine-gun shots and 75 mm shells (effects), the barrier, the boss bar on and off and
the counter, the banners, each fire zombie's dressing (by `net_id`) and each burst and patch (effects), the dive bomber
(the client flies the same pass from the same call), the wreck (the state's mode), the raid's phases and every marker
(the client runs its own marker clock; the host's `take_hit` reaches remote players as every boss hit does). Not
mirrored: a peer joining mid-event sees the next state update only.

## 6. Bots

- The squad's bots never shoot it (it is not one of the dead) and are told about it through the public
  `BotBlackboard.add_danger` (the call the horse and the vacuum use): the hull as three low-cost discs, so they walk round
  it rather than into it; every bomb's ring while it falls (cost 8); every burning patch (cost 5).
- The raid: `BotSetPieces._shelter_plan` asks the `air_raid` group's `shelter_for(player)` first (a 7-line hook beside
  the meteor shower's): a bot outside during the warning or the bombing walks (shooting as it goes) to the nearest of
  three shelter points in the taproom, an urgent move the brain lets only a revive outrank; inside, it fights as usual.

## 7. Dev hooks

- `round 30` / `round 40` (the existing console command) jump there; the event starts on the round's start.
- `sherman 30|assist|40|raid|hold|kill|status` (new): start the arrival now, park it covering the yard, the dive bomber
  now, the raid now, beat the assault off, brew it up, the state.

## 8. Every edit outside the new files

| File | Edit |
|---|---|
| `gravelight/maps/map_root.gd` | 1 line: `ShermanEvent.attach(self)` after `HorseRound.attach`. |
| `gravelight/enemies/homage/horse_round.gd` | 2 lines: a map row's `arrival` is merged into the boss block (the Inn's Fuhrmann). |
| `gravelight/bots/bot_setpieces.gd` | 6 lines at the top of `_shelter_plan`: the air raid's shelter point. |
| `data/gravelight/map00.json` | the round-30 row's `arrival` and `_doc`; the `sherman_event` block appended at the end. |
| `data/gravelight/audio.json` | 10 keys appended as one block at the end of `sounds`. |

Not touched: `gravelight/enemies/zombie*.gd`, `homage_boss.gd`, `homage_encounter.gd`, `boss_fx.gd`, `dread_fx.gd`,
`gen_map00.gd`, the navmesh, PROGRESS, DECISIONS.

RESULTS_PLACEHOLDER
