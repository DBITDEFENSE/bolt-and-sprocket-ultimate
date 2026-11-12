# Morning report: UPDATE 15, 2026-11-12

**Your five asks are built on branch `claude/boss-rework`, with the boss rework from the night before finished on
the same branch. Not merged to master: look first.** Nothing was seen on your screen; the pictures below are
software renders.

## 1. Movement
- You walk up and down anything up to 40 cm (kerbs, sills, low props) instead of stopping dead. The view eases.
- A jump pressed just after a ledge (0.1 s) or just before landing (0.12 s) counts.
- Strafe reversals are quicker. Crouch, head bob and slide no longer step at 60 Hz on a fast display.
- Walk and sprint speeds are unchanged. Bots do not use the step assist.
- Numbers and knobs: `docs/u15/t236_movement.md` (`data/gravelight/movement.json`).

## 2. Lag with bots: better on hitches, barely on the average
- Hitches on the Inn: frames over 16.7 ms 31 -> 11 of 1800, over 20 ms 9 -> 0 (headless, no renderer).
- The average frame moved 0-3 %. A squad still costs about 3 ms of CPU a frame.
- Fixed: sounds, voice lines and gun models loading on the frame that first used them; several bots thinking on
  one tick; the bots asking the navmesh about every machine each second.
- The AI-brain bot's model ran about a quarter of the time on your graphics card (your log: an answer in about 1 s
  every 4 s). It is asked far less often now. This is the change you are most likely to feel; I could not measure it.
- Not fixed: the biggest spikes left are in zombie code (an explosion in a pack 9-35 ms), which the zombie
  overhaul owns. `docs/u15/t237_bot_perf.md`.

## 3. Map 1, the Inn
- The crowded cellar was the Helvetia vault: floor-standing things 18 -> 8, the lever's approach 1.8 -> 2.6 m.
  Twelve machines still stand there (their positions were off limits). If it still feels crowded, moving some
  machines is the next step: say so.
- Hay: real bales with twine, stacks laid in courses, a loose mound, straw on the boards, a pitchfork. The bales
  you could walk through in the stable's doorway are a solid stack on the wall now.
- Taproom crates against the wall, the till modelled, the yard's loose things out of the open ground.
- Pictures: `morning/screenshots/u05/u15_before/` and `u15_after/` (same file names; start with `52_stable_hay`,
  `55_loft_stack`, `41_cellar_vault_n`).

## 4. Map 2, Kaltenbrunn
- Not cluttered; the fault was the opposite. You could walk through most floor props (ore carts, drums, desks, the
  lab's gurneys, the pylons). 65 are solid now.
- Every pine piece was drawn bright green; brown again. Sixteen door trims hung in bought doorways; fixed.
- The Admin stairs' bare black sides are a panelled wall with a shift board, a plan and a clock.
- Lanterns in eight places that were black before the power.
- Pictures: `morning/screenshots/u10_map01/u15_before/` and `u15_after/`.

## 5. Horses
- **The horse** stands tied in the Carters' Yard, east of the Thompson chalk. Hold Use to mount; forward urges it
  on (walk, trot, gallop), back reins it in, left / right turn it; hold Use or Jump to get down. You can shoot from
  the saddle up to a trot, not at a gallop. Zombies ignore it and it cannot die. A gallop flings an ordinary zombie
  aside and costs the gallop. It stays in the yard (and the grounds once the gate is bought).
- **Round 20, DAS TOTENROSS:** a dead dray horse, skull bare, violet light in the ribs. Charge (sidestep it: a wall
  staggers it), stomp, a kick if you stand behind it, a trample of anyone knocked down.
- **Round 30, DER FUHRMANN:** the same horse with its dead carter riding and lashing a whip; he is thrown at half
  health and fights on foot.
- On at the Inn (yard, grounds, stable) and on Kaltenbrunn's surface. Indoors it does not follow; it sends the
  nearby dead at you.
- Pictures: `morning/screenshots/t240_horse/v3/` (the model) and `morning/screenshots/u15_horse/a3/` (the bosses in
  the yard).

## The boss rework (from the 10th)
- All ten bosses' reworks are merged, and the ten faults your /code-review found in the shared kit are fixed
  (lights left dim after a fight, hit effects firing on burn ticks, blood ignoring the gore setting, and the rest).
- PAUL was getting wedged in the Waschkaue's back corner; fixed on the map.

## Checked
- Scripts: 903, 0 failed. Unit suite: 2254 of 2255 pass, 1 risky (the old loudness test that asserts nothing).
- A second code review of the new code found ten more faults, all fixed: the worst was a co-op horse left "ridden"
  for everyone when a client rider went down.
- Smokes: see the last section of `morning/NEEDS_DEVIN.md`.

## Known and open
- Co-op clients see a plain zombie where a boss horse is (the limit every homage boss has had).
- Whether bots get out of a charge's line is not measured.
- `smoke_npc_walls` fails on the Inn as it did before this work: a bot presses behind the bar toward the shut cellar.
- Sixteen extra boss sounds the boss workers asked for are not made; stand-ins play.
