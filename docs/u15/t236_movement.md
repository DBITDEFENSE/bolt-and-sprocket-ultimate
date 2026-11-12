# T-236: movement feel

The owner: "go through and make the movement feel better."

Nothing more was said, so the first job was to find what feels bad. I read the player's movement end to end
(`gravelight/player/player.gd`, `move_intent.gd`, the camera, the viewmodel's motion in
`gravelight/weapons/weapon_holder.gd`, `data/gravelight/movement.json` and `player.json`, T-046 and T-133 in
`docs/DECISIONS.md`) and wrote a probe that drives the real player through its input actions on a bare arena
and measures it: `gravelight/tools_src/smoke_move_feel.tscn` (about 80 s headless under load, no map, no
zombies). Every number below is from that probe, at 60 physics ticks a second.

## What felt wrong, ranked by how much a player feels it

1. **Anything between 11 cm and 50 cm high stopped you dead.** The capsule rolls over a lip up to about 10 cm;
   a mantle starts at 50 cm. A kerb, a door sill, a plank, a low crate or a pipe in between was a wall: full
   speed to zero, and the only way over was a jump. The probe walked into kerbs of 15, 25 and 35 cm and never
   got up any of them. This is the "stuck on props" feeling, and it is everywhere a map has small dressing with
   a collider. (Zombies already had a step-up of their own since T-057; the player did not.)
2. **Jumps were lost at ledges and on landings.** There was no coyote time and no jump buffer: a jump pressed
   one tick after the feet left a ledge did nothing (you fell), and a jump pressed one tick before landing did
   nothing (you landed and stood there). In a game where you run from a horde and hop gaps, these read as "the
   game ate my jump".
3. **A short drop was a fall.** Walking off a 35 cm step put the body in the air for 12 ticks (0.2 s): air
   control instead of ground control, a landing dip, a landing footstep, and no jump or slide until it landed.
   Sprinting down a stepped surface was 24 ticks in the air out of the run.
4. **Strafe reversals were soft.** Left to right at walk speed took 15 ticks (0.25 s) to reach 95 % the other
   way. Dodging a swipe is a reversal; this is the part of "mushy" that the numbers show.
5. **At a high refresh rate, parts of the camera still moved at 60 Hz.** T-133 moved the camera to the render
   rate and interpolates the body's position, but three things the camera reads were still stepped per physics
   tick: the eye height while crouching, standing or sliding (up to 11 cm in one tick at the start of a
   crouch), the head-bob phase, and the slide's dip and tilt blend. On the owner's 240 Hz screen that is four
   identical frames and then a jump. Found by reading the code; it cannot be measured headless.

What measured fine and was left alone: start (7 ticks to 95 % of walk or sprint speed), stop (walk 11 ticks,
0.35 m; sprint 15 ticks, 0.70 m), diagonal speed (exactly 1.000 of straight), sliding along a wall met at
45 degrees (0.71 of walk speed, the geometric value), a wall corner or a door jamb clipped by 10 cm (5 ticks
lost, no stick), sprinting over the crest of a ramp and down it (0 ticks in the air), chained sprint jumps
(no speed gained), mouse look (applied per event, no smoothing), the pad (radial dead zones 0.2 move and 0.15
look, a squared response curve).

## What changed

All of it is in `Player._update_movement` and a new section "steps and falls (T-236)" in
`gravelight/player/player.gd`, with the numbers in `data/gravelight/movement.json`.

1. **Step assist** (`Player._step_assist`, `step_up_spot`, `step_down_spot`). A body on the floor that walks
   into something up to 40 cm high, squarely enough, with head room, room on top and a floor there, is put on
   top of it. A body that walks off an edge with a floor up to 40 cm below is put down on it without a fall.
   The body moves at once; the eye does not: it keeps walking forward at the walking speed and eases up or
   down (`Player._view_off`), so there is no camera jolt. A step has to put the capsule's middle past the edge
   (up to 40 cm ahead), so the body then waits exactly as long as walking that far would have taken
   (`_step_hold`): a kerb costs one tick and gives no head start, on a staircase or anywhere else. Never onto a
   zombie, a teammate, a barricade, a door or a `no_mantle` collider. A level "step" is allowed too: that
   frees the capsule from a seam between two floor pieces.
2. **Coyote time and a jump buffer.** A jump still counts as from the floor for 0.1 s after the feet leave it
   (walked off, not jumped), and a jump press is remembered for 0.12 s, so one pressed just before landing
   jumps on the landing. Neither gives a second jump in the air, and Skyhook Sekt's air hop, the slide-jump
   and the mantle each spend the press themselves.
3. **Turn boost.** While the stick points against the current motion, the ground acceleration is multiplied
   by 1.6: a reversal brakes faster than it starts. Starting, stopping and top speeds are unchanged.
4. **Render-rate camera.** With smooth motion on, the eye height, the bob phase and the slide blend are read
   blended between the last two physics ticks, like the body's position already was (`Player._view_frac`,
   `step_phase`). The step assist's eased eye goes through the same tick blend.
5. **A fall-gravity switch, shipped off** (`jump.fall_gravity_mult` = 1.0). See "not changed".

Bots and companions share `_update_movement`, so they get the jump forgiveness and the turn boost (a bot only
presses jump on the floor, so the forgiveness does nothing for it). The step assist is **off for bots**
(`step.bots` false): their paths, stuck timers and soak numbers were tuned on the plain slide, and another
worker is on their performance now. Turning it on is one flag once that work has landed.

## Before and after

| Measure | Before | After |
| --- | --- | --- |
| Kerb 15 cm, walked into | blocked | climbed, 1 tick lost |
| Kerb 25 cm | blocked | climbed, 1 tick lost |
| Kerb 35 cm | blocked | climbed, 1 tick lost |
| Kerb 45 cm | blocked | blocked (jump, or mantle from 50 cm) |
| Largest eye move in one tick on a 35 cm kerb | (never climbed) | 5.7 cm |
| Step down 35 cm: ticks in the air | 12 | 0 |
| Stepped stairs (18 cm rise, 30 cm run), walking up | impossible | 2.81 m/s (62 % of walk) |
| The same, sprinting up | impossible | 5.41 m/s (80 % of sprint) |
| The same, sprinting down: ticks in the air | 24 | 0 |
| Jump pressed after leaving a ledge: latest that jumps | 0 ticks | 5 ticks (0.08 s) |
| Jump pressed before landing: earliest that jumps | 0 ticks | 6 ticks (0.10 s) |
| Strafe reversal to 95 % the other way | 15 ticks (0.25 s) | 12 ticks (0.20 s) |
| Time to 95 % walk / sprint speed | 7 / 7 ticks | 7 / 7 ticks |
| Walk stop | 11 ticks, 0.35 m | 11 ticks, 0.35 m |
| Sprint stop | 15 ticks, 0.70 m | 15 ticks, 0.70 m |
| Standing jump: apex / time in the air | 0.67 m / 38 ticks | 0.67 m / 38 ticks |
| Sprint jump length | 4.42 m | 4.42 m |
| Wall at 45 degrees: speed along it | 0.71 of walk | 0.71 of walk |
| Wall corner clipped by 10 cm: ticks for 8 m | 112 | 112 |
| Low crate (30 cm) clipped by 10 cm: ticks for 8 m | 112 (slid round) | 113 (stepped over its corner) |
| Ramp crest and ramp down at a sprint: ticks in the air | 0 / 0 | 0 / 0 |

The maps build their stairs as ramps, so the stepped staircase is a stress case, not something in the game
today. The raw logs of both runs are in `.smoke_logs/t236/` on the PC (git-ignored).

## The tunables (all in `data/gravelight/movement.json`)

| Key | Value | Meaning |
| --- | --- | --- |
| `turn_boost` | 1.6 | Ground acceleration multiplier while braking against the stick. 1 = as before. |
| `jump.coyote_time` | 0.1 | Seconds a jump still works after walking off a floor. 0 = off. |
| `jump.buffer_time` | 0.12 | Seconds a jump press is remembered. 0 = off. |
| `jump.fall_gravity_mult` | 1.0 | Gravity multiplier on the way down. Off. |
| `step.max_h` | 0.4 | Highest step walked up, deepest drop walked down (m). 0 = off. Keep it under `mantle.min_h` (0.5). |
| `step.min_facing` | 0.5 | How squarely you must walk into a step (1 = head on only). |
| `step.view_rate` | 11.0 | How fast the eye catches up in height (1/s). Higher = snappier, lower = floatier. |
| `step.view_max` | 0.6 | The eye is never further than this from the body (m). |
| `step.bots` | false | Squad bots and companions use the step assist too. |

Unchanged and still where they were: `accel_time` 0.12, `decel_time` 0.17, `air_accel` 5.0, the speeds in
`player.json` (walk 4.5, sprint 6.8, crouch 2.4, jump velocity 4.2), gravity in `world.json` (14).

## What I chose not to change

- **Walk and sprint speeds, and so the zombie chase balance.** No speed moved. The step assist gives no head
  start (pinned by the probe and a unit test), so a player is exactly as fast as before on every surface it
  could already cross.
- **Gravity and the jump.** A hop is 0.67 m and 0.63 s in the air. That is a low, slightly floaty jump, but it is a
  matter of taste rather than a fault, and falling faster would shorten the sprint jump from 4.4 m to about
  3.9 m, which could close a gap a map relies on. The switch is there
  (`jump.fall_gravity_mult`, try 1.3) and it leaves a launch plate's arc alone; it is off.
- **Air control** (5 m/s^2, capped at take-off speed). Weak on purpose since T-046, and the no-bunny-hop rule
  depends on it.
- **The sprint stop** (0.70 m). On the long side of crisp, but it is what makes a sprint feel like weight.
  `decel_time` is the number if it should be shorter.
- **The capsule.** A flat-bottomed collider would climb stairs more evenly, but every map, bot path and
  mantle was built against the capsule.
- **Zombies and bodies.** Zombies block the player and the player cannot be shoved by them; that is enemy
  code and was not touched. Nothing in `gravelight/bots/`, `gravelight/enemies/` or the map generators changed.
- **No new flourishes.** Head bob, strafe roll, landing dip, FOV kick and the viewmodel's sway were already
  there and already tunable; none of them measured as a fault.

## Three things to try by hand

1. **On Map 0, walk (don't jump) straight at low things:** door sills, planks, low crates, rubble, the foot
   and head of the staircase. You should go over anything up to knee height without the view snapping, and
   walk off it without a drop. If any spot now lets you somewhere it should not, lower `step.max_h`.
2. **Any ledge:** sprint off it and press jump a moment late; then jump on the flat and press jump again just
   before you land. Both should jump. If it feels too generous, lower `coyote_time` / `buffer_time`.
3. **Strafe left-right-left** in front of a zombie, then crouch and stand a few times with smooth motion on
   (240 Hz). The dodge should feel tighter and the crouch should glide rather than tick. If the dodge feels
   twitchy, set `turn_boost` to 1.3.

## Not verified

- Nothing was looked at on a screen (headless only on this PC). The 240 Hz camera blend (item 5) and the look
  of the eased eye on a step are from the code and the probe's per-tick numbers, not from a rendered run.
- The step assist was not walked by hand on the real maps. `smoke_feel` drives the real player on the Test
  Range with it on (PASS); the bots in the map smokes do not use it.
