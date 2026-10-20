# Playtest review: GRAVELIGHT Map 0 (Crossroads Inn), rounds 1-10

**Date:** 2026-10-20
**Build:** TERMS & CONDITIONS, `main` after T-025
**Tester:** the playtest bot, `tools_src/playtest_gl.gd`

## How it was played

`tools_src/playtest_gl.gd` plays a real solo match through the real `Player`. It doesn't call internals: it presses the same input actions a person would (move, fire, reload, use, melee, swap), aims at a human-capped turn rate (7 rad/s) with aim noise, and reacts after a 0.18 s delay. It:
- shoots heads
- reloads, swaps to a loaded gun when something is close, and melees when empty
- backs away from crowds along the navmesh, avoiding dead ends and closed doors
- rebuilds barricades
- buys wall guns, ammo and doors

While it plays it watches for stuck or fallen zombies, stalled rounds, a stuck player, failed purchases and frame time.

```
godot --headless --audio-driver Dummy --fixed-fps 60 --path . res://tools_src/playtest_gl.tscn -- --rounds=10 [--god] [--seed=N] [--debug] [--trace]
godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . res://tools_src/playtest_gl.tscn -- --rounds=10 --shots=<dir>
```

**Runs made:**
- Ten-plus headless runs, used to debug the bot itself.
- Two god-mode runs: seed 7 (before the fixes) to round 10, and seed 11 (after them) to round 8. God mode switches off damage, so these test the systems rather than survival.
- Four real-difficulty runs.
- One rendered run with screenshots.

## Results

**God-mode run to round 10 (seed 7, before the fixes): reached and cleared round 10 in 12.1 game minutes.**

| Round | Time | Kills | Scrip after | Max alive | Notes |
|---|---|---|---|---|---|
| 1 | 40 s | 6 | 1,100 | 5 | Kar98k bought before the first zombie |
| 2 | 54 s | 9 | 1,740 | 7 | M1 Garand |
| 3 | 81 s | 11 | 210 | 7 | Stable door + Trench Gun |
| 4 | 62 s | 14 | 2,520 | 9 | |
| 5 | 43 s | 8 | 2,990 | 5 | special (Bellringer) round |
| 6 | 66 s | 20 | 7,090 | 12 | Upstairs door |
| 7 | 81 s | 23 | 10,150 | 15 | |
| 8 | 117 s | 26 | 12,840 | 22 | |
| 9 | 118 s | 30 | 16,850 | 22 | |
| 10 | 58 s | 11 | 18,530 | 7 | special round |

- **Totals:** 158 kills, 75 % headshots, 2.7 rounds fired per kill.
- **Power-ups seen:** Double Scrip, Resupply, Fortify, Death's Door, Blackout.
- **Script errors:** none in the whole match.
- **Frame time** (headless simulation, including the bot): p50 1.06 ms, p99 3.4 ms, worst 28 ms.
- **Rendered run:** a single 133 ms hitch the first time combat effects appeared, almost certainly a one-time shader compile. The other spikes in that run came from the screenshot capture itself.

**Real difficulty (no god mode):** the bot went down in round 2, 3, 4 and 5 across its runs. Every down came the same way: two zombie hits (50 damage each, 100 HP). Map 0 has no perks, so there's no way to raise that.

## Bugs found and fixed

1. **Zombies hit through walls and closed doors.**
   - **Cause:** melee attacks never checked line of sight, either to start or to land. A Bellringer (2.4 m reach, plus 0.5 m when the hit lands) could hit the player through a wall or the closed Upstairs door.
   - **Fix:** `Zombie._clear_to()` requires a clear line, ignoring world and door geometry within 0.35 m of either body so wall-huggers still connect. It's checked when the attack starts and when it lands.
2. **The window swipe reached far into the room.**
   - **Cause:** reach was measured from a point 1 m inside the window, with 1.7 m reach plus 0.3 m grace. A zombie still outside the boards hit the player 3.1 m away.
   - **Fix:** reach is now measured from the window opening: `world.json` `barricade.window_attack_reach` 1.5, plus 0.2 m grace. Only a player standing right at the boards gets swiped.
3. **Special-round packs spawned behind closed doors and stalled the round.**
   - **Cause:** Bellringer fog portals pick any reachable navmesh point 8-18 m from a player. On Map 0 the navmesh runs under closed doors, because doors are colliders, not navmesh cuts. Packs spawned in the locked Stable or Upstairs, pressed against the door, and the round could not end. One bot run sat in round 3 for an hour of game time.
   - **Fix:** a portal point must be in an open zone (`ZoneVolume`), and the path to it must not cross a closed door (`ZombieDirector._crosses_closed_door`).
4. **Zombies snagged near the player were never recycled.**
   - **Cause:** the stuck-zombie check only fired when the player was more than 8 m away. Zombies snagged on the stair corner or the Stable stalls, or blocked by a door 2 m from the player, stood there forever.
   - **Fix:** a zombie in CHASE that hasn't moved 1 m in 15 s is recycled if it isn't within attack reach, or has no clear line to its target. It re-enters through a window. Crowding zombies queued behind others within reach are left alone.
5. **GRAVELIGHT's Quit closed the whole game** (T-025, found earlier the same day).

After the fixes:
- All 259 unit tests pass, 256 scripts compile, and the Scrapheap smoke run still passes.
- The verification god-mode run (seed 11) on the fixed code got through round 7, including special round 6, with no stuck zombies or stalls.
- I stopped it in round 8: the bot was out of ammo and boxed into a corner of the Stable. In god mode it can't die, so the round could never end. That's the bot's weakness, not the game's; the zombies there were crowding within reach, as they should.
- Round 10 itself was reached and cleared in the seed-7 run, on the code before these fixes.

## Review

**What's working well:**
- **Combat reads clearly.** Head hitboxes are generous enough that a deliberate player lands headshots (75-100 % of the bot's kills). The Kar98k → Garand → Trench Gun climb feels like progress.
- **The round loop is solid.** Spawning, window tearing, climbing, chasing, the special-round fog packs, power-ups and round transitions ran through round 10 with no errors.
- **The economy flows early.** Barricade repairs and kills fund a gun by round 1 and a door by round 3.
- **Performance has a lot of headroom,** even with 22 zombies alive.
- **Look and feel:** the warm interior with cold blue windows makes the threat points obvious. The HUD (round stamp, scrip, ammo) is legible.

**What I'd change next.** These are design calls, so they're flagged rather than done:
1. **The early game is harsh for solo players.** Two hits down, with no perk machines on Map 0 to raise it. Options:
   - 150 HP on Map 0 only (3 hits)
   - an Ironhide machine in the Stable
   - slower round 1-3 zombies
2. **Nothing to spend on late.** Scrip piles up (18k by round 10) with only the crate left to buy. A Map 0 perk, or a Crucible (upgrade) spot, would give it a goal.
3. **Stair navigation is tight.** The baked navmesh hugs the stair stringer closer than a player-sized body fits at (2.9, 1.6, 14.9), so zombies snag briefly. The recycle fix covers the symptom; a re-bake with a 0.4 m agent radius in `gen_map00.gd` would fix the cause.
4. **The zone boxes are approximate.** The TAPROOM volume runs past the Upstairs door (z = 16), and the UPSTAIRS stair box sits on the taproom side. Spawning no longer depends on them (fix 3), but stats and hint text still do. Worth correcting in `gen_map00.gd`.
5. **First-use shader hitch.** Pre-warm the muzzle flash, blood and impact materials during the round 1 intro, to remove the one-time 133 ms stall.

## Bot limitations (not game issues)

- The bot doesn't kite in loops the way a good human does.
- It doesn't use the mystery crate, grenades or ADS.
- When cornered it backs into walls.

Its survival numbers are a floor, not a measure of how hard the map is for a person.
