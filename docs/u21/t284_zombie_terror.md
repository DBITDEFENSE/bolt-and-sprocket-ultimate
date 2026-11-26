# T-284: the zombies more terrifying (2026-11-25)

The owner: "MAKE THE ZOMBIES MORE TERRIFYING". Branch `claude/zombie-terror`, cut from master `8310acb3` (T-283 merged).
Not merged, not pushed. Built on the zombie overhaul (licensed mocap, contact lock, springs), T-257 (gore) and T-269
(the zombie look).

**Presentation only.** Speeds, damage, attack timings, hitboxes, navmesh, spawn rules and AI decisions are unchanged.
The scare's own random choices come from `ZombieTerror.rng`, never the game's global generator (tested). Everything
is behind `Zombie.t284_terror` (`CZ_T284_OFF=1`, `perf_marks --flip=t284` / `--ab=t284_off`); switched off, every
body looks, moves and sounds as before (the shader's new terms are exactly zero).

## What changed

| Part | Where | What it does |
|---|---|---|
| **Burning eyes** | `zombie_body.gd` skin shader, `inst_terror.x` | A hot core, the socket and a faint halo, round each eye's centre in the shared rig's rest space (measured on all six base bodies: the same point, ±0.035, 1.721, -0.076 m). Violet like the Nachtglas veins; about one body in six amber (`inst_terror.w`). Breathes with the map hum. Emission only: it reads in the dark at 10+ m and blooms. |
| **Rot and wet** | the same shader, `inst_terror.y/z` | Green-black sores where the ridged noise and the vein cells meet, and a wet sheen (low roughness) on the sores, the mouth, the bloody hands and the eyes. |
| **The look per body** | `ZombieTerror.look_vec`, `Zombie._apply_look` | Rolled from the T-269 look seed (net id + spawn health), so every co-op peer sees the same eyes. Plain walkers and every rigged special; the living never. |
| **First sight** | `Zombie._first_sight` | The first time this life is in a chasing state near the camera (20 m, full-rate LOD): the head spring kicks toward the target, both arm springs jerk up (a lunge that goes nowhere), the look-at snaps at 0.06 s for half a second, and a scream (one at a time across the horde, 2.2 s apart). Springs and look-at are additive on the recorded motion (allowed by the overhaul's rules: no code-generated bone keys). |
| **Twitches** | `Zombie._twitch` | Every 2.2-5.5 s an involuntary jerk of the head or one arm (the hit springs); within 6 m now and then a joint crack. |
| **The barricade queue reaches** | `zombie_mocap.json` `terror_aliases`, `ZombieClips.visual_clip` | A body waiting its turn at a window plays the licensed `Zombie_Reach_1_Loop` take (until now unused) instead of the procedural wait clip. Visual only. |
| **Voice layers** | `Zombie._update_audio`, `ZombieTerror` | A low wet growl under every groan of a body within 12 m; wet mouth sounds within 6 m; the nearest body within 3.6 m breathes at the player (ragged inhale, bubbling exhale), rate-limited. |
| **Death polish** | `Zombie._terror_death_fx`, T-283's death queue | A near death (15 m) gurgles and spits blood from the mouth, a frame or more after the kill (never in the kill's frame). |
| **Horde moments** | `ZombieTerror` (the director's child, every peer its own) | Eight or more bodies within 10 m of the player: a low swell of many throats (once per 25 s), the fog thickens x2.2 over 2.5 s, the six nearest lamps flicker deeper and faster; it ends below five for 3 s. Not over the special round's own fog (it is released first). |
| **29 new sounds** | `gravelight/audio/sfx/terror/`, `gravelight/tools_src/gen_audio_terror.py` | In-house, synthesized with gen_audio.py's DSP core (no recordings, no samples); `LICENSE.txt` / `SOURCE.txt`; keys appended as one block at the end of `audio.json`. Regenerate: `tools/venv` python with numpy + scipy. |

Data: `data/gravelight/zombie_terror.json` (every distance, rate, colour and level).

## The frame cost

All the per-frame work runs only for bodies animated at the full rate (T-283's LOD: within 12 m and in view); the
look is per-instance shader values (no CPU per frame); sounds go through AudioDirector's pools; the horde check is
one loop over the active bodies four times a second. Measured, Map 0, `--flip=t284` (one second a side in one
run), three runs a count, medians, ms a frame of the game thread with no renderer (a quiet evening machine):

| Zombies | Frame p50 off -> on | mean off -> on | 1 % worst off -> on | max off -> on | zombie.gd physics | zombie.gd process | after the process scripts |
|---|---|---|---|---|---|---|---|
| 24 | 7.65 -> 7.81 (+2 %) | 7.82 -> 7.88 (+0.8 %) | 13.88 -> 14.03 | 15.68 -> 16.70 | 1.18 -> 1.18 | 0.93 -> 0.93 | 1.13 -> 1.12 |
| 48 | 10.19 -> 10.21 (+0.2 %) | 10.58 -> 10.46 (-1.1 %) | 17.74 -> 18.09 | 19.77 -> 20.07 | 1.94 -> 1.92 | 1.51 -> 1.52 | 1.46 -> 1.44 |

Within the noise: the zombies' own scripts and the skeleton step are unchanged; the T-281 / T-283 gains stand. What
the scare did in those runs (`[t284]` lines, a 30 s window, half of it switched on): 23-47 first sights, 4-9 screams
(the 2.2 s cap), 39-59 twitches, 6-7 close breaths. The renderer's side: no new mesh, light or particle per zombie;
the eyes add a few shader instructions to the skin pass (draw calls the same in every off / on pair of pictures).
Bench: `BENCH_DIR=t284 sh tools/zombie_count_bench.sh flip_m0 "24 48" m0 3 "--flip=t284 --secs=30"`,
`python -I tools/zombie_flip_table.py .smoke_logs/t284/flip_m0 --parts`.

## Pictures

`docs/captures/t284/after/` (Map 0 at its own night, WSL Xvfb, Forward+ on lavapipe; each scene off then on):

- `faces_off.png` / `faces_on.png`: three walkers close up, their heads turned to the camera. On: the eyes burn violet
  under the helmets; the rot and the wet are faint at this light.
- `taproom_off.png` / `taproom_on.png`: twelve across the lit taproom at 7 m. On: the eyes show as pale violet points;
  in a lit room they are a detail, not a beacon.
- `sight_00.png` .. `sight_07.png`: one walker at 3 m, the first sight played at frame 01: the head jerks, the arms
  come up and settle in about 0.3 s, the look-at swings to the camera.
- `horde_off.png` / `horde_on.png`: sixteen round the player in the yard. The fog (x2.2) is barely visible in a still
  at night; the lamp flicker and the swell are not in pictures at all. (The eyes already burn in `horde_off`: that
  scene switches only the horde moment, not the bodies' look.)
- `t284_run.mp4`: the whole capture run (33 s, every scene in order, 960 px).

## Checks run

All headless on Windows in `.wt/locker` on `claude/zombie-terror` (logs `.smoke_logs/t284/`, git-ignored), pictures under
WSL Xvfb (one render at a time, 30 GB free, no other Xvfb).

- Script check: 1046 scripts, 0 failed. Assets manifest: current (117 folders); the new sound folder has its
  `LICENSE.txt` / `SOURCE.txt`.
- Full GUT: 2703 tests, 2701 passing, 1 risky (the known `test_neural_lines_are_loudness_normalised`), 1 failing:
  `test_npc_life :: test_warm_hands_meet_under_the_chin` (a living person's pose, 0.853 against > 0.9), which passes
  16 of 16 alone three times, with the scare on and off: a load intermittent, not this work.
- `test_t284_zombie_terror` (new, 6): the look from the body's seed and zero switched off; the scare draws nothing from
  the global random generator; a twitch kicks only the springs (the body and its state unchanged); the first sight
  snaps the look-at and lets it go, once a life; the scream cap; the barricade take only switched on; the sounds in
  the bank and on disk.
- Smokes, all PASS with 0 script errors: `smoke_zombie_anim`, `smoke_map00`, `smoke_map00_alive`,
  `smoke_map00_cellar_bay`, `smoke_map00_loop`, `smoke_coop`, `smoke_squads`, `smoke_horse_boss` (81 checks),
  `smoke_sherman` (87).
- The bench: 6 runs with `--flip=t284` (table above).

## Not verified

- Heard: no sound was listened to. The 29 sounds were checked by numbers only (lengths, peaks, no clipping, levels near
  the existing groans); the scream, the breathing and the swell may need a pass by ear (`gen_audio_terror.py` is
  data-driven per sound).
- Seen on a real GPU: only Forward+ on WSL's software renderer. Bloom on the eyes, the wet sheen under real lamps and
  the fog swell may read differently on the owner's card.
- The horde fog and the lamp flicker in motion, and the first sight in a real round (the stills play it by hand).
- Co-op: every peer runs its own horde moment and screams; the eyes agree (from the net id); not run with a client.
- Other maps than Map 0 (the shader and sounds are map-independent; the horde fog uses each map's own fog density).

## Proposals for the owner (not built: they would change how zombies play)

1. **Screamers that alert.** A first-sight scream that pulls the zombies within 15 m toward the screamer's prey
   (an AI change: more pressure when one spots you).
2. **A real lunge.** On first sight, a jog/run zombie closes the first 2 m at sprint speed (a speed change, brief).
3. **Darkness hunters.** Zombies whose eyes glow amber move a tier faster when the player stands in the dark
   (needs a light probe at the player; a speed rule).
4. **Window grabs.** The reaching zombies at a window grab a player within 0.8 m of the boards (damage / a hold: an
   attack rule).
5. **More recordings.** The pack has no second upright gait, no crawler at 0.8 m/s, two deaths, one swipe performance:
   distinct shamble/walk gaits, a lunge, a grab, directional hit reactions and six more deaths would add the most
   variety (an asset purchase: the owner's call; nothing is aliased to fake variety).
