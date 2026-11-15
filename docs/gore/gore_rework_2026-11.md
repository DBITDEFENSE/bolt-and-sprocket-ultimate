# The gore rework, November 2026

Branch `claude/gore-rework`, cut from master at `4a527f4f`. Not merged, not pushed.

## The order

The owner, 2026-11-15: "also re work the blood and gore make it scarier."

## Read this first: what the frames do and do not show

The rework is a real gain on **walls** and in **lit stone rooms**, and for **headshots**. It is **not** a
visible gain on the taproom's dark floorboards, in the **close-range rifle scene against a wall**, or on **snow**.
Several things below are built and tested but were never seen in a picture. Each claim in this document says
which kind it is.

Frames: `docs/captures/gore_rework/`

- `before/` the code at `4a527f4f` (52 frames, `gore.mp4`)
- `after/` this branch as committed (56 frames, `gore.mp4`)
- `after_gorefx_pools_only/` four frames of an experiment that was reverted (see "A change that was reverted")

Frames are JPEGs (`<scene>_<nn>.jpg`); `marks.txt` in each folder holds the mark counts the run logged per scene. All were rendered invisibly under WSL + Xvfb on Forward+ (Vulkan on lavapipe), 3D at two thirds of 1920x1080, by
`tools/wsl_gore_shots.sh` and `gravelight/tools_src/shots_gore.gd`. Software rendering; a real GPU will differ.

| Scene | Before | After | Verdict |
|---|---|---|---|
| headshot (`headshot_03..05`) | a burst of bright red cubes, the wall clean | a dark ragged spatter with thrown rays on the plaster; when the head comes off, the neck spurts for a few seconds | clear gain |
| cellar, lamp light (`lamp_03..05`) | a body on a clean floor by a clean wall | spatter with a long run down the brick, blood on the stone under the body | clear gain |
| pile of ten (`pile_08_floor`, `pile_09_wall`) | large pools on the floor (the horror layer's decals, see the inventory) | the same pools, plus spatters and runs on the far wall | the floor is about the same; the wall is new |
| shotgun (`shotgun_06`) | a visible pool under the body | a fainter pool | no gain |
| rifle, body shots, a metre from a wall (`wall_*`) | no blood on the wall | no blood visible on the wall | **not demonstrated** (four attempts; the log counts wall marks that the frame does not show) |
| snow (`snow_06`) | a dark patch | a dark patch | **no visible difference** |
| the player's view (`lens_01..03`, after only) | n/a | a few faint dark drops at the edges that fade in about 3 s, a dark stain on the hand; crosshair, ammo and money stay clear | works, subtle |

## Inventory: what existed

- `Effects.blood()` / `Effects.zombie_hit()` (`gravelight/autoload/effects.gd`): per hit, a pooled burst of 4 cm red
  cubes, an unshaded red mist and droplets (`ImpactFx`). Gated by the Gore setting ("full" only). No mark was left
  on the world by a hit.
- `ZombieGore` (`gravelight/enemies/zombie_gore.gd`, T-041): limbs, head and jaw come off, a stump cap (a dark collar
  and a red disc), thrown pieces capped at `anim.json gore.max_pieces`.
- Wounds: up to six quads per zombie with a soft red radial texture (`ZombieBody.blood_material`).
- **Blood pools under the dead already existed**: `HorrorLayer` (`gravelight/world/horror_layer.gd`, UPDATE 11,
  T-192) projects a blood `Decal` at every kill (24 at high quality, a small stain on "low", none on the
  Compatibility renderer). **I missed this in the first inventory** and only found it when the "before" frames
  showed pools. It is unchanged by this branch.
- Settings: `gore` off / low / full (`menu_settings.gd`), `vfx_quality` low / medium / high, the web profile
  (`WebProfile.PARTICLE_RATIO` halves particle counts on the Compatibility renderer).
- Sounds: `impact_flesh`, `zombie_gib`, `zombie_death`.
- The HUD's red damage vignette (`hud.gd`), unchanged.
- No dismemberment was added or removed: the severable bones and their chances are as they were.

## What was built

All of it is presentation, local to each peer, driven by calls every peer already makes. No damage number, hitbox,
collider, zombie timing, spawn count, navmesh or prompt changes. No new network message.

**`GoreFx`** (`gravelight/world/vfx/gore_fx.gd`, a child of `Effects`, data in `vfx.json` "gore"):

- **Marks on the world**: spatter, pool, run down a wall, boot print, crawler smear. Every mark is an instance of
  one MultiMesh quad shaped by `blood_decal.gdshader` from a noise texture, so all of them are one draw call. A
  mark's age (a pool spreading, a run creeping down, wet blood drying) is its birth time against a clock uniform:
  nothing about a mark is ticked on the CPU.
- **Per weapon class** (`gore.classes`): mist, drops and bits of meat per hit; the chance that a round goes through
  and marks what is behind the body, how far, how large; the chance of drops on the floor and of a run.
- **Where marks may go**: only plain static world geometry (`Effects.persists_on`, the rule bullet holes use). Not
  doors, machines, props or characters. A mark whose corners would hang over an edge is shrunk or dropped.
- **A death**: about a second later a pool is laid under the body (beside it when it lies on a prop), with two
  cast-off spatters. This lies **on top of** the horror layer's decal at Gore "full".
- **A head coming off**: the neck spurts in pulses for 2.2 to 3.4 s and spatters the floor (3 at once at most).
- **Tracks**: whoever stands in a pool younger than 35 s leaves nine boot prints; a zombie that loses its legs
  drags a smear. **Counted in tests only; never seen in a frame.**
- **The player's view**: `GoreScreen` (drops near the screen's edges, the middle always clear) and blood on the
  first-person hands (`arms.gdshader`, a runtime global `gl_hand_blood`).
- **Colour**: wet `[0.42, 0.03, 0.035]`, dry `[0.15, 0.028, 0.02]` (sRGB), low roughness when wet, nothing emissive.
  The old hit mist read its colour as linear and came out bright red; that is fixed.
- **Stumps and wounds** (`zombie_body.gd`): a stump is torn meat round a snapped bone end; a wound is a ragged dark
  hole. **Never looked at close up in a frame.**
- **Sounds**, synthesized in `gen_audio.py` (our own work): `gore_splat`, `gore_spurt`, `gore_bone`, `gore_drip`,
  13 files under `gravelight/audio/sfx/zombies/`. **Never listened to** (every run is silent).

## Budgets

`data/gravelight/vfx.json` "gore":

- Marks, hard caps, oldest reused first: spatter 192, pools 28, runs 48, prints 64, smears 40.
- Scaled by `quality.<level>.gore` (low 0.5, medium 0.75, high 1) and halved on the Compatibility renderer.
- Per physics frame: at most 12 raycasts and 6 new marks.
- In a horde: chances and particle counts fall linearly from 12 live zombies to 0.35 at 40. Zombies leave boot
  prints only while 16 or fewer are alive.
- Particle emitters are pooled and their counts fixed when built. No node is added at run time (tested).
- The gore code draws from its own random stream, not the one gameplay uses.

## Measured cost

Tool: `tools/bot_perf.sh` (headless, `--fixed-fps 60`, Map 0, round 15, 24 zombies, 3 bots and the companions
firing, 30 s a run). Mean frame wall time in ms. Logs: `.smoke_logs/t237/gore_*` (not in git).

| Scenario | Base `4a527f4f` | This branch |
|---|---|---|
| zombies kept alive (hits only) | 9.77, 10.56, 10.44 | 10.72, 11.56, 9.74 |
| the round running (kills, pools) | 8.02, 9.05 | 8.59, 9.32 |

**What this supports**: no cost can be shown. **What it does not**: it cannot rule out a cost below about 1 ms;
three runs of one build differ by up to 1.8 ms on this machine, which other sessions share. Nothing was measured on
a GPU, so the fill cost of the transparent marks and of the stacked pool is unknown.

A mistake worth knowing about: my first comparison used `master` as the "before" and showed the branch 14 % slower.
That was wrong. `claude/movement-perf` had been merged into master after this branch was cut, so the gap was that
work's saving in the zombie tick, not a cost of this one.

## Settings

- Gore **off**: nothing new appears (tested).
- Gore **low**: nothing new appears (tested); the horror layer's small stain is as before.
- Gore **full**: everything above.
- `vfx_quality` and the web profile cut the mark budget and particle counts (tested by count, not rendered: no
  Compatibility-renderer frame was made for this work).

## A change that was reverted

Commit `485ee71d` made GoreFx the only owner of the pool under a body at Gore "full" by silencing the horror
layer's decal. The frames of that build (`after_gorefx_pools_only/pile_08_floor.jpg`) show the taproom floor after
ten kills nearly clean: GoreFx's pools, once dried, do not read on the dark boards. `52e7e5b2` reverts it. The
consequence stands: two systems draw a pool for each death.

## Verification

All headless (`--headless --audio-driver Dummy`), on this branch as committed unless a line says otherwise.

- `check_scripts`: 956 scripts, 0 failed.
- `python -I tools/assets_manifest.py --check`: current (117 folders). No file was added under `assets/` except the hunk in `arms.gdshader`.
- New tests, `gravelight/tests/unit/test_gore_fx.gd`: 12, all pass. They cover: the data is dark and has a profile
  for every weapon class that reports bullet hits; a hit in front of a wall marks it; budgets hold under a burst
  (marks per kind, marks and rays per frame, no node added); the oldest pool is reused first; Gore off and low leave
  nothing; the web profile and `vfx_quality` cut the budget; a horde cuts the marks; nothing sticks to a door or
  hangs over a ledge; a body pools and whoever treads in it leaves a fixed number of prints; a match start wipes
  everything; the lens spatter and the hands fade; damage numbers are the same with gore off and full.
  They run on the dummy renderer: they count marks, they cannot see them.
- Full GUT, run twice: 2378 tests (master's 2366 + these 12).
  - Run 1: 2376 passing, **1 failing**, 1 risky.
  - Run 2: 2377 passing, 0 failing, 1 risky.
  - The risky one is `test_neural_lines_are_loudness_normalised`, known on master.
  - The failure was `test_hud_stamp_perks.gd :: test_round_stamp_fits_high_rounds` with the engine error "Lambda
    capture at index 0 was freed": a callback left by an earlier test firing during this one. **The same error
    line appears twice in both runs**, in the same stretch of the suite; in run 2 it fell where the runner did not
    count it. This branch adds no lambda, timer callback or tween to the game. The HUD test passes alone; the
    twelve scripts around it pass with and without the new test. Its source was not found, and master's suite was
    not run here to see whether the line is there too.
- Smokes (`tools/run_smokes.sh .smoke_logs/gore <name>`), no script errors in any:
  - PASS: `smoke_coop`, `smoke_sherman` (41 checks), `smoke_zombie_anim`, `smoke_bots`, `smoke_bots_shop`,
    `smoke_bots_u10`, `smoke_map00`, `smoke_map00_alive`, `smoke_map00_cellar_bay`, `smoke_map00_loop`.
  - **FAIL: `smoke_bots_shop_m0`, 0 passes in 4 runs on this branch** ("no squad bot did 'bench'" three times,
    "the companion bought no tonic" once). On the code this branch was cut from: **2 passes in 3** (the failure
    there: "the companion bought no tonic"). So the smoke is unreliable on the base too, and the branch looks
    worse, but 0 of 4 against 2 of 3 does not settle it. No cause was found: the branch touches no bot or economy
    code and adds no gameplay randomness. **If the branch does change what the bots do, it is not presentation
    only; this is the first thing to check after a merge.**
  - Not run: `smoke_marks` (known to fail on master) and every other smoke.
- Co-op: `smoke_coop` passes. No new network message was added, so there was nothing new to test in it; what a
  second peer sees was not looked at.

## Files

New: `gravelight/world/vfx/gore_fx.gd`, `gore_screen.gd`, `blood_decal.gdshader`;
`gravelight/tests/unit/test_gore_fx.gd`; `gravelight/tools_src/shots_gore.gd` and `.tscn`;
`tools/wsl_gore_shots.sh`; 13 WAVs `gravelight/audio/sfx/zombies/gore_*.wav`; this document; the captures.

**Shared files touched** (each a small hunk unless noted):

| File | What |
|---|---|
| `gravelight/enemies/zombie.gd` | 3 hunks: the neck spurt in `_pop_head`, the smear in `become_crawler`, the pool in `_start_death` |
| `gravelight/enemies/zombie_gore.gd` | 1 hunk: a sever's burst goes through `Effects.gore_burst` |
| `gravelight/enemies/zombie_body.gd` | the stump mesh, three material rows, the wound texture |
| `gravelight/autoload/effects.gd` | the old cube pool removed, `blood()` and `zombie_hit()` hand over to GoreFx, `gore_burst()`, `clear_marks()` |
| `gravelight/world/vfx/impact_fx.gd` | the mist and drop emitters |
| `assets/materials/shaders/arms.gdshader` | the hands' blood. **Outside the gore/vfx set the brief named**; the only way to put blood on the hands |
| `data/gravelight/vfx.json` | the "gore" block, a "gore" factor per quality row |
| `data/gravelight/audio.json` | four keys inserted, nothing else touched |
| `gravelight/tools_src/gen_audio.py` | the four sounds |

`gravelight/world/horror_layer.gd` was changed and reverted; it is as on the base.

## For the merge

- The branch is behind master. Since `4a527f4f` master changed `zombie.gd` (30 lines) and `zombie_body.gd`
  (237 lines), both touched here. Expect conflicts in those two. I did not merge or rebase.
- New WAVs need an import pass.
- `gen_audio.py` run in full rewrites all of `audio.json` (about 11,000 lines of drift, not from this work). The
  four keys were inserted by hand instead.
- `gl_hand_blood` is added at run time by GoreFx (as `ZombieBody.ensure_globals` does for its globals), not in
  `project.godot`.

## Open items

0. **`smoke_bots_shop_m0` fails 4 of 4 on this branch and 1 of 3 on its base** (see Verification). Unexplained.
1. **Dried blood on dark wood.** The order asks for near-black when dry; on this map's boards that is invisible.
   Unresolved, and the reason two pool systems still overlap.
2. **Two pools per death** at Gore "full" (the horror layer's decal and GoreFx's). Pick one owner once (1) is
   settled.
3. **The rifle-against-a-wall scene shows no wall blood in a frame.** Marks are counted there; whether they land
   out of view, on the dark wainscot, or do not draw is not established.
4. **Snow.** Marks outdoors are flagged as snow (counted), but the frame looks the same before and after.
5. **A floor spot indoors with no ceiling collider above it is treated as snow** (one mark in one run). Not fixed.
6. **Never seen in a picture**: boot prints, crawler smears, stumps and wounds up close, the Compatibility
   renderer, co-op.
7. **Never heard**: the four sounds.
8. **Not built** from the order's list: blood on the gun itself, drag trails other than a crawler's, footprints
   from the player's real footfalls (prints are laid by distance walked).
9. **Needs the owner's eye on a real GPU**: every colour and gloss value, the lens spatter's strength, the hands.
