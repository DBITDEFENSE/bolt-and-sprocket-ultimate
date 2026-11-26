# Morning report: 2026-11-25/26 (tank view, explosions, rocket site, U-boats, frame rate, scarier zombies)

**Seven jobs merged and pushed to master.** Nothing was shown on your screen: pictures came from software renders under
WSL, everything else ran headless. Last full unit run on master: 2,703 tests, 2,702 passing, 1 risky (the known one);
smoke tests pass on every map with the new physics engine.

## 1. Tank: World of Tanks view (T-278)
- Climb into the Sherman: the camera sits behind and above it and orbits with the mouse; the turret follows where you
  look at its own speed (it lags, like WoT), a marker shows where the gun really points, a ring shows the reload.
- Wheel: zoom 5-16 m; wheel all the way in or Shift: the gunner's sight (x4). Tab cycles three distances.

## 2. Explosions (T-280)
- Every blast in the game: a flash, a fireball rolling into dark smoke, a drifting column, dirt or snow thrown up,
  debris, sparks, a dust ring, a scorch, screen shake, and a crack + boom + distant rumble. Small pops stay small.
- About 0.1 ms a blast; built once at load.

## 3. Rocket site, second pass (T-279)
- Camo nets, sandbag walls, detailed fuel and launch trailers, wire with warning plates, a phone line, a slit trench,
  a guard post, cables, clutter, tyre tracks. Paths and the launch are unchanged.

## 4. U-boats no longer see-through (T-282)
- The hulls were drawn inside out. Both U-boats, their towers, the patrol boat and the cutter are solid now.

## 5. Lag with many zombies (T-281, T-283)
- Cause: each zombie's own engine work (animation, skeleton, 18 hit areas, movement, physics), growing with the count;
  the crowd at the inn windows made physics grow faster than that.
- Fixed: the Jolt physics engine (about 20 % faster frames, worst frames halved), skeletons update only when the
  animation moves, far zombies animate at a lower rate (full within 12 m), a grenade into a pack no longer spikes
  (the kill frame 32-42 ms -> about 20 ms).
- Kaltenbrunn hits the target; Map 0 with 48 zombies is close. **Real 60 FPS on your PC is not measured** (see list).

## 6. Scarier zombies (T-284)
- Glowing violet eyes (some amber), rot and wet skin, a head snap and scream when one first spots you, twitches,
  breathing up close, a death gurgle, and horde moments (fog thickens, lamps flicker, a swell of voices).
- No change to speed, damage or AI. Off switch: `CZ_T284_OFF=1`.

## 7. Also done (2026-11-26)
- **Trailers (T-285):** `build/trailers/teaser_1080p.mp4` (67 s, slow dread, mostly Higgsfield footage made in the game's
  places) and `gameplay_1080p.mp4` (86 s, all real gameplay). 443 credits spent, 521 left. Not watched with sound yet.
- **Launcher 1.2.0 (T-289):** the "game doesn't start" was most likely its window opening behind other programs; the
  launcher now waits for it, logs every start, explains an early exit (safe mode / repair), never starts it twice, and
  plays the trailers in its news. **Install it by hand:** `build\launcher\ClaudeZombiesLauncher-Setup-1.2.0.exe`.
- **Grenade throw (T-288):** pin, draw back, cook pose with a tremor, release, follow-through; same timing as before.
- **U-boat plating (T-287):** riveted, seamed, rust-streaked steel instead of stripes.
- **Bots on Totenhafen (T-286):** bot squads could not buy the signal tower door since Nov 15 (players were fine); fixed.
- **Jolt physics back (T-291):** it had been rolled back because players could not climb stairs under it; fixed for
  both engines (stairs are smoother than before on either), Jolt back on.

Nothing is running. Details: `docs/DECISIONS.md` T-278 to T-291. Your list: `morning/NEEDS_DEVIN.md`.
