# T-261: the Sherman fights with judgement, uses its 75 mm, and a player can drive it

The owner (2026-11-22): "Make the tank on round 30 smarter and make it use its cannon. I want the player to be able to
drive the tank around if needed."

Branch `claude/tank` (from `master` at d10738ef). Builds on T-249 (`docs/u18/t249_sherman.md`); everything there
still holds unless this note says otherwise. Nothing here has been seen rendered (section 8).

## 1. What the tank did before (measured)

`gravelight/tools_src/sherman_bench.tscn` (new, headless, `--fixed-fps 60`) plays the round-30 assault and 150 s of
round 31 on the Inn with one human standing still in god mode and no bots, and counts what the tank fires. On the
T-249 code, three runs a case (the unopposed assault once: it cannot vary, the guns are off):

| Case | 75 mm shells | Machine-gun rounds | Tank's kills | Outcome |
|---|---|---|---|---|
| Round-30 assault, nobody helps | **0** | **0** | 0 | lost after 46 s |
| Round-30 assault, a "team" (one of the wave killed every 2.5 s) | **0, 0, 0** | **0** | 0 | held with 1,580 to 2,060 of 8,000 health |
| Round 31, the human in the yard | 9, 1, 3 | 343 to 348 | 28, 2, 5 | |
| Round 31, the human on the road 12 m in front of it | 8, 6, 8 | 341 to 348 | 4, 5, 5 | |
| Round 31, the human in the taproom | 2, 2, 2 | 35 to 45 | 0 | |

Why:

- **In the assault it never fired at all.** `_assist_step` ran only while `assisting`, and that flag was set when the
  assault was already beaten off. For the whole fight the owner watches, the tank was a target with a health bar.
- **In the assist rounds the 75 mm waited 11 s between shells**, wanted two of the dead within 4 m of each other (or
  one beyond 18 m), and was only chosen in the last 1.5 s of that wait; the turret (28 degrees a second) often arrived
  after the pack had moved on, and the target was a fixed point taken once.
- **With the squad indoors it sees almost nothing.** From its parking place the yard's walls, the stable and the inn
  hide most of the dead on their way to the windows (the taproom case: 0 in its sight for most of the 150 s). That is
  the usual state of a real round, and it is the owner's "rarely or never fired".
- The machine gun fired from the coax at whatever was nearest whichever way the turret pointed (tracers leaving the
  mantlet sideways), including the dead at a player's elbow. The 75 mm's only safety rule was 5 m between the
  target and a player: nothing looked at a player standing on the shell's line, at where the shell would really
  burst, or at a burning zombie in the blast that would then burst beside someone.

## 2. What it does now

### The gunner (`ShermanRules`, `ShermanTank._assist_step` / `_choose_targets`)

- **It fights in the assault** (`defending`), from the moment the dead rise, at `assault_damage_mult` 0.7 of its
  damage (a shell still kills a burning one outright; the team still has to hold the tank: unopposed it is still lost).
- **The 75 mm** reloads in `gun_reload_s` 6.5 s (was 11). In the last `gun_lay_lead_s` 3.5 s of the reload the turret
  is laid for it; before that the machine gun has the turret. A shell goes where it is worth `gun_min_score` 2 or more:
  each of the dead in the blast counts 1 (whole within 4 m of the centre, a quarter at 6 m), **a burning one 2.5, the
  round's boss 3, one going for the hull 2**; or at one alone beyond 14 m. So: packs before singles, a burning one or
  the boss alone is worth a shell, one ordinary zombie close in is left to the machine gun.
- **A pack coming up out of the ground is laid on while it rises** and fired at when the first is up; a target once
  taken is followed as it moves (within 5 m) instead of being a point in the snow.
- **Safety, checked when it picks and again at the moment of firing against where the shell will really burst** (a
  fence post short of the target moves the burst): never within 5 m of a player (downed players count), never with a
  player within 1.5 m of the shell's line, never within 6.5 m of its own hull, never where a burning zombie in the blast
  would burst within 5 m of a player or against the hull. A shell that fails the last look is held (`shots_held`).
- **The machine gun** fires only with the turret within 8 degrees of its target, never at one of the dead within 1.5 m
  of a player or with a player within 1 m of its line, and never at a burning one that would burst on a player or on
  the hull. Among the rest: the nearest, but a burning one still far from everyone first (+6), then the one going for
  the hull (+3), the one closing on a player (+3), the one already hurt (+4 x health lost), the boss (+2); it stays
  on the one it is on (+2) rather than flit.
- **The watch.** With nothing to shoot the turret turns to the heaviest 30-degree sector of the dead within 60 m (the
  ones still rising and the ones behind a wall count: the crew hears them; nearer counts more, burning double); with
  nobody about it turns between the gate ahead and the road behind every 7 s. It no longer sits wherever it last fired.
- The turret traverses at 40 degrees a second (was 28).
- Unchanged: damage is a share of the round's zombie health, to the dead only; no Scrip; the dead hugging the hull are
  under its guns; it cannot be hurt in rounds 31..39 (unless a player drives it into the dead, section 3).

### Measured after (same bench, three runs a case)

| Case | 75 mm shells | Machine-gun rounds | Tank's kills | Outcome |
|---|---|---|---|---|
| Round-30 assault, nobody helps | **1, 1, 6** | 68 to 77 | 0 to 2 | still lost, after 42 to 48 s |
| Round-30 assault, the "team" | **3, 4, 5** | 42 to 56 | 2 to 4 | held with 3,440 to 3,890 of 8,000 health |
| Round 31, the human in the yard | 11, 11, 11 | 308 to 315 | 19 to 22 | |
| Round 31, the human on the road | 13, 16, 16 | 314 to 323 | 20 to 27 | |
| Round 31, the human in the taproom | 2, 3, 4 | 21 to 63 | 0 to 3 | |

Honest reading:

- **In the assault the guns are on now, but the 75 mm is still a small part of it**: one to six shells in the 45 s
  the wave lasts (it was none), with 40 to 80 machine-gun rounds. The dead rise 10..16 m out at scattered points and
  are on the hull, under the guns, two or three seconds later; the turret (40 degrees a second) is often still
  swinging. The tank alone still loses; with the same help as before it holds with about twice the health left.
  Making the 75 mm count for more here would mean changing how the wave rises (real packs at one place) or letting
  it shell its own hull; neither was done.
- **With the dead in the open the 75 mm is regular**: 11 to 16 shells in 150 s (4.4 to 6.4 a minute) where the old
  code fired 1 to 9, and they land on packs: 19 to 27 kills against 2 to 28.
- **With the squad indoors it is still mostly blind from its parking place** (2 to 4 shells in 150 s, as before). No
  rule fixes that from where it stands; the answer is the third part of the request: drive it to where it can see.
- The numbers come from a bench with an idle, invulnerable human, not from play.

## 3. Driving it

- **In.** Once it has parked (and until round 40's dive bomber) the hull is a Use point: "Hold [Use] to climb into the
  Sherman". One driver at a time; bots, the downed and anyone on a ladder or a horse cannot. 0.9 s to climb into the
  commander's hatch (the view is from the cupola, eye 0.5 m over its rim).
- **Keys** (the horse's own actions, so a gamepad works exactly as far as it does on the horse): move forward / back =
  throttle, move left / right = steer; the view lays the turret and the gun; **fire** = the 75 mm; **aim** = hold
  the coaxial machine gun; **hold Use again or jump** = climb out (0.6 s), set down at the first free place beside
  the hull. The keys are shown for the first 8 s of the first three drives; a line at the bottom of the screen shows
  "75 MM READY" / "75 MM LOADING 3.4" with a bar.
- **How it moves.** Tank steering: 3.2 m/s forward (the speed it came up the road at), 1.6 back, 1.6 m/s2, brakes at 3;
  it pivots on the spot at 34 degrees a second and turns at 24 at full speed; a full turn costs 35% of the speed. The
  two tracks and their wheels now run at their own speeds (a pivot runs one forward and one back), the tracks' sound
  and the engine's pitch follow whichever is faster.
- **The guns.** The turret and gun follow the view at their own rates (40 and 12 degrees a second), so the shell goes
  where the barrel is, not where the eye is. The shell is the gunner's shell (same reload, same blast, the round's
  full damage scale) and bursts on the first thing on the barrel's line, the world or one of the dead. The machine gun
  fires along the barrel at 9 rounds a second while aim is held; a round hits the first of the dead within 0.5 m of
  the line. No Scrip from either, or from the tracks. The driver's own weapons are put away while in the hatch.
- **Decision: the gunner stands down while a player is in.** Both turret guns are the driver's; nothing fires by
  itself. Two hands on one turret would fight over where it points, and a tank that shoots on its own while you aim it
  is confusing. It takes over again the moment the driver is out.
- **Where it may go** (`map00.json` `sherman_event`: `drive_zones`, `drive_boxes`, `drive_no_go`;
  `ShermanRules.may_stand`): the road and the meadow south of the yard's fence and the fields east and west of the
  yard up to the stable's line: a horseshoe round the yard, 11 m wide or more everywhere. Every point of the hull's
  footprint must be in the GROUNDS zone, inside one of three boxes and outside a 3 m disc at the mouth of the yard's
  gate. **Never the yard, the stable or the inn, never past the map's edge.** On top of that the hull stops for
  anything solid from 0.6 m up (walls, fences, carts, doors, barricades, the map's edge, the horse) and for ground
  more than 0.45 m off its level. It tries the whole move, then the run without the turn, then the turn alone; what
  it cannot do it does not (a clank). **The navmesh, the zombie paths and the hull's collision layer are unchanged.**
- **Decision: why not the yard.** The hull stops players and bots (T-249's rule). A hull left in the gate, against the
  taproom door or between the stable and the wall, or its wreck after round 40, could close the way for the rest of
  the match. The horseshoe is wide enough that a 6 m hull closes nothing, and the gate's mouth is kept clear.
- **Decision: it stops for players and bots, it does not push them.** A moving hull cannot crush or shove a teammate.
  While it moves the bots are told about the ground ahead of it as well as the hull (a danger disc 5 m ahead).
- **The dead under the tracks.** At 1 m/s or more, the dead under the leading end of the hull are run down one every
  0.35 s (120% of the round's health; each costs 30% of the hull's speed, so a crowd slows it to a crawl). Bosses are
  not run down. A burning one run down bursts under the hull by the fire zombie's own rules (600 off the tank, the
  burst's damage to the driver); that case was not run.
- **Decision: the driver is protected from the dead's hands, and the hull pays for it.** The dead that come for the
  driver cannot reach the hatch; within 6 m of the hull they are given one of the tank's attack points (the assault's
  own hook) and beat on the hull instead, 30 a swipe. **In the assault** that is the boss bar as before: at 0 it
  brews up and the round is lost as in T-249. **Outside the assault the dead cannot wreck it** (rounds 31..39 and
  round 40's bomber need it): at 1 health the driver is put out ("THE DEAD ARE ALL OVER THE SHERMAN / ITS CREW IS
  MAKING REPAIRS"), the hatch stays shut for 30 s, and the crew repairs it (all of it back in 60 s with nobody
  driving). So driving into a horde is not a free invulnerable ride: about a dozen of the dead on the hull empty it
  in under half a minute. The driver is **not** protected from a fire zombie's burst, a burning patch, a boss or the
  bombs: someone downed in the hatch is put out beside the hull, where a teammate can reach them.
- **Put out safely.** The driver is set down beside the hull, never inside it: (a) when it brews up, before the blast
  (the wreck does no damage to players); (b) when round 40 begins, with "GET CLEAR OF THE SHERMAN", about eleven
  seconds before the bomb, and nobody can climb in from then on; (c) when the dead empty it outside the assault; (d)
  when the driver goes down. (If the tank itself is removed with someone in it, a lost tank towed off or a dev
  command, they are released where they are, which is then open ground.) The place is the first of eight beside the hull
  and twelve farther out that has floor at the hull's level, room for a body, a clear line to the hull, an open zone
  and the navmesh within a metre.
- **The assault on a moved tank.** The attack points are children of the hull and move with it. The ring the dead
  rise from is laid round the tank where it stands when the assault begins and laid again whenever it has moved 3 m
  (the old ring is kept if the new place has none). The Resupply for holding is thrown where it always was, before
  the gate. Round 40's bomber dives on the tank wherever it stands; the wreck stays there (always in the horseshoe).

## 4. Co-op

Host-authoritative for everything that matters, with the horse's pattern for the body:

- The host decides who is in and when they are out (`ShermanUse.interact` runs on the host, as `HorseUse` does) and
  mirrors `net_board` / `net_leave`; it owns the reload, every shell's and machine-gun round's damage, the dead under
  the tracks, the dead on the hull, the hatch's lock and the repairs.
- The driver's own machine moves the hull (no input lag) and reports place, heading, turret, gun and speed ten times a
  second (`net_by_drive_state`, through the existing whitelisted client call, which passes who asked). The host takes
  a report when it is from the driver, the step is one the tracks could have made and the place is one it may stand
  in; otherwise its own stands and the driver's machine is pulled back once the two are 4 m apart. The host mirrors
  the state to everyone at 10 Hz while it is driven (it was 2 Hz parked); other peers lerp as before.
- A client driver's shell and machine gun are requests (`net_by_fire_main`, `net_by_mg`); the host checks the reload
  and fires. The flash and burst come back mirrored, so a client driver sees its own shell one round trip late.
- Not handled: a client driver's hull does not lose speed when the host runs one of the dead down (the host's copy
  does); a peer joining mid-drive learns who drives at the next board / leave.

## 5. The numbers (`data/gravelight/sherman.json`)

`tank.turret_rate_deg` 28 -> 40. `assist`: `gun_interval` 11 replaced by `gun_reload_s` 6.5; `gun_cluster` 2 replaced
by `gun_min_score` 2.0 with `gun_weight_fire` 2.5, `gun_weight_boss` 3.0, `gun_weight_on_hull` 2.0; `gun_lone_m` 18 ->
14; `range` 45 -> 50; new `gun_lay_lead_s` 3.5, `gun_hold_s` 1.0, `gun_follow_m` 5.0, `gun_min_m` 6.5, `gun_lane_m`
1.5, `fire_clear_m` 5.0, `fire_hull_clear_m` 2.5, `mg_aim_tolerance_deg` 8.0, `mg_player_clear_m` 1.5, `mg_lane_m`
1.0, the `mg_bonus_*` and `mg_stick` weights, `scan_s` 0.3, `watch_m` 60, `watch_sectors` 12, `watch_yaws_deg`
[0, 180], `watch_dwell_s` 7.0, `assault_damage_mult` 0.7. Unchanged: `gun_player_clear_m` 5.0, the damage fractions,
the blast radius, the machine gun's burst, rate, gap and damage. New block `drive` (every number in section 3, with
its own `_doc`). `map00.json` `sherman_event`: `drive_zones`, `drive_boxes`, `drive_no_go`, `_doc_drive`.

One existing test bound moved with the reload: `test_assist_damage` allowed at most 12 kills a minute with targets
everywhere (one per shell every 11 s plus the machine gun); it is 14 now (12.6 by the same sum).

## 6. Files

- New: `gravelight/world/sherman/sherman_rules.gd` (`ShermanRules`, the pure rules), `gravelight/tools_src/sherman_bench.gd`
  / `.tscn` (the measurement), this note.
- `sherman_tank.gd`: the gunner rewritten on the rules; `defending`; the driver (the Use point, the seat, the keys,
  the ground checks, the driver's guns, the tracks, the dead on the hull, the lock and the repairs, the co-op calls);
  the two tracks running separately.
- `sherman_event.gd`: `defending` on and off with the assault; `drivable` on at the park and off at round 40; the ring
  laid again when the tank moves; the Resupply at the parking place; the driver put out at round 40; the bail banner;
  the bots' disc ahead of a moving hull; `sherman drive|out`; the state line; 10 Hz state while driven.
- `sherman_attack_point.gd` (`holders_now`), `gravelight/ui/sherman_hud.gd` (the driver's line and bar).
- `test_sherman.gd` (+7 tests), `smoke_sherman.gd` (+33 checks).
- Not touched: `zombie*.gd`, `player.gd`, `horse*.gd`, the net code, `map_root.gd`, the navmesh, any other map,
  `project.godot`, PROGRESS, DECISIONS, `morning/`.

## 7. Verification (2026-11-22, headless on the owner's PC)

- `check_scripts.gd`: 966 scripts, 0 failed.
- GUT `test_sherman`: 17 of 17, 270 asserts (10 were T-249's; 7 new: the shell's choice, the machine gun's choice,
  the watch and the reload, the driving rules, the driving ground on the Inn, who may climb in, the rig driven on a
  floor against a wall with its puppet and its host-side checks).
- GUT, the whole suite: **2,430 tests, 2,429 passing, 0 failing, 1 risky** (`test_neural_lines_are_loudness_normalised`
  did not assert: the known one), 85,340 asserts, 570 s. (2,423 on `master` plus the 7 new.) Two earlier full runs
  in this worktree failed 49 and then 22 tests for reasons of the worktree, not the change: it had no `.import`
  sidecars (git-ignored) and no UID cache, so every test that loads a sound or a model reported it missing. The
  sidecars were copied from the main checkout (read only) and `--import` run once; the count above is the run after.
- Smokes through `tools/run_smokes.sh .smoke_logs/tank <filter>`: `smoke_sherman` **PASS, 74 checks** (41 were
  T-249's), 162 s, 0 script errors; `smoke_horse` PASS (67 checks), `smoke_horse_boss` PASS (79 checks).
  The new checks: the prompt at the hull and the player's Use ray on it; a bot cannot climb in; the player in the
  hatch; one driver; 5.6 m backwards in 4 s; driven at the gate it stops with its bow 3.0 m from the gate's mouth;
  a pivot of 67 degrees in 2 s; the turret laid by the driver and the 75 mm fired on the dead in the meadow (3 of 3
  hurt), nothing on the players; "75 MM LOADING 6.5", no second shell before the reload is over, the next one when it
  is; the machine gun while aim is held (11 rounds in 1.2 s) and silent when let go; one of the dead run down; one
  that came for the driver turned onto the hull and its swipe taken from the hull; out beside the hull (0.8 m from
  it) on walkable ground in an open zone, and the dead turn back on the players; driven to its last health outside
  the assault: the driver put out, the hatch shut, not wrecked, repaired at 180 a second; the tank 3.9 m from where it
  parked; a bot set against the moved hull walks clear; **the assault begun on the moved tank** (the ring laid round
  it where it stands, every point 10..16 m from the hull) and then T-249's whole fight as before (the dead on the
  hull, the fire zombie's burst, the hold, the Resupply); round 40: a player in the tank is put out as the bomber
  comes and nobody climbs in after; a second Sherman brewed up with the player in it: out beside it, alive, 100
  health.
- Three of T-249's smoke checks were rewritten because the gunner's new rules made the old arrangement meaningless,
  not to make them pass: (1) "the dead reach the hull" now counts swipes from the assault's start (the drive before
  it leaves swipes on the counter); (2) the machine-gun and 75 mm checks had the dead rise beside the human, where
  the gunner no longer shoots: they now rise in the meadow with the players down the road, the machine gun is
  checked with the 75 mm held empty, the 75 mm on a pack; (3) "nothing on the players" summed the players' damage
  over the window, which the dead themselves fail when they reach the bot: it now measures every shell's burst
  against where each player stands at that moment (5 m or more). The smoke also stands the bot up before round 40
  if the earlier rounds put it down (it is not in god mode; one of the trial runs needed it, the final run did not).
- The bench (section 1 and 2): `.smoke_logs/tank/bench_before_*.log`, `bench_final_*.log` (not committed).

## 8. Not verified, and open

- **Nothing was seen rendered.** Not checked by eye: the view from the hatch (the eye is 0.5 m over the cupola's rim;
  whether the turret roof, the open hatch doors or the .50 on its post crowd the picture), the climb in and out, the
  driver's body standing in the hatch as others see it (a standing body, waist in the turret), the hands put away,
  the driver's line on the HUD and whether it sits clear of the other HUD elements, the two tracks running against
  each other in a pivot, the gun firing from its lowest lay at something close (the tracer leaves the muzzle up to a
  few degrees off the barrel's line).
- **Not played by a person.** Whether 3.2 m/s and a 34 degree-a-second pivot feel right, whether 6.5 s is the right
  reload in the hand, whether 30 s out of the hatch is the right price for driving into a horde, whether the horseshoe
  feels like enough ground.
- **Co-op was not run with two machines.** The host-side checks are unit tested by calling them (a stranger's report
  moves nothing and fires nothing; a puppet follows the host); a real client driving, its 10 Hz reports, the pull-back,
  the shell's one-round-trip delay and a driver disconnecting in the hatch were not exercised.
- **Real keys and a gamepad were not pressed** (the smoke drives through the same code path with an input override;
  the actions are the horse's, `move_*`, `fire`, `ads`, `interact`, `jump`).
- **The bots.** The smoke puts a bot against the moved hull with the human on the other side and it walks away freely;
  that is one position. Bots pathing across the horseshoe with the tank parked across their line rely on the same
  danger discs as T-249 and on the bots' own stuck handling; no census was run with the tank moved to many places.
- **The edges of the driving ground** were checked by rule and by one drive at the gate, not by driving the whole
  outline. A place inside the boxes where the hull fits but a player beside it does not would only cost the exit a
  farther spot.
- **Balance of the assault with the tank fighting back** rests on the bench's two cases, not on play.
- A zombie already in its swing at the driver when they climb in can still land it (the hatch is about 2 m from
  the ground beside the hull, close to a zombie's reach): not measured.
- A boss can still hit the driver in the hatch (a charge, a stomp): untested.
- Three `.uid` files that the import writes for scripts already on `master` (`test_bot_census.gd.uid`,
  `test_bot_stuck_2026_11.gd.uid`, `trench_water.gdshader.uid`) are not part of this work and are left uncommitted.
