# BOSS REWORK (T-231, 2026-11-10): every boss battle reworked, the models and effects better, scarier

The owner: "re work all the boss battles and make their models and effects better. make them scarier".
Branch `claude/boss-rework` (from `claude/maps-1-2-production`, which carries T-224..T-230). The lead builds the
shared kit (section 2) and the sound pack (section 3), then four workers rework the bosses in worktrees (section 4),
each in its own files, and the lead merges, verifies and reports (section 5).

## 0. What exists (the survey)

| Map | Boss | Script | Director | Data | Smoke |
|---|---|---|---|---|---|
| 0 Crossroads Inn | THE COUSINS: the Hammer, the Reach, Alix (round 10) | `enemies/homage/cousin_hammer.gd`, `cousin_reach.gd`, `cousin_alix.gd` | `cousins_round.gd` | `bosses/cousins.json` | `smoke_cousins` (69) |
| 1 Kaltenbrunn | PAUL (round 15) | `homage/paul.gd`, `paul_rage.gd` | `paul_encounter.gd` (HomageEncounter) | `bosses/map01.json` | `smoke_paul` (57) |
| 1 Kaltenbrunn | THE FOREMAN (round 12-14, every 5-7) | `enemies/foreman.gd` (extends Zombie, own body) | ZombieDirector | `enemies.json` | `smoke_map01*` |
| 1 Kaltenbrunn | the Screamer (rare special, not a boss) | `enemies/screamer.gd` | ZombieDirector | `enemies.json` | |
| 2 Totenhafen | THE SLENDER, the Hafenwächter (round 25) | `homage/slender.gd`, `slender_decoy.gd`, `watch_meter.gd` | `slender_encounter.gd` | `bosses/map02.json` | `smoke_slender` (51) |
| 2 Totenhafen | DER KIELHOLER (summoned; the drowned) | `homage/kielholer.gd`, `world/map02/kielholer_controller.gd` | the controller | `bosses/map02.json` | `smoke_kielholer` (35) |
| 4a Thalbach | DER KRANFÜHRER (act round 13) | `enemies/map04/kranfuehrer.gd` | ActController | `bosses/map04.json` | `smoke_act_bosses` (18) |
| 4b der Kranich | DER BORDWART (act round 18) | `enemies/map04/bordwart.gd` | ActController | `bosses/map04.json` | `smoke_act_bosses` |
| 4c Groom Lake | THE TEST PILOT (act round 26) | `enemies/map04/testpilot.gd` | ActController | `bosses/map04.json` | `smoke_act_bosses` |
| 4d Mondlicht | THE ACCOUNT MANAGER (the finale; never dies) | `enemies/map04/account_manager.gd` | MondlichtController | `bosses/map04.json` | `smoke_act_bosses` |

Every boss but the Foreman and the Screamer extends `HomageBoss` (`enemies/homage/homage_boss.gd`): the MZ body on
the shared `ZombieRig`, costume pieces as primitive groups on bone attachments (`costume()`), a `HomagePoseMod` layer
for poses, the move clock (`bstate`, `_bt`, `cd_ready`), the grab helper, authored deaths, the title card and bars
(`BossHud`), lines through `say()`. The Cousins wear modelled doll bodies (`PeopleBodies "cousin_*"`), the others
tinted zombie kits (`ZombieBody.build_skinned`) with scale and pose tricks.

What the renders and the code say is weak, and what "scarier" must fix:
- **Sound.** The bosses play the horde's and the world's generic ids (`board_slam`, `grenade_explode`, `impact_flesh`).
  Only the Foreman and the Kielholer own sounds. No boss has a presence drone, a breath, a footfall or a hit sound of
  its own. Fear is mostly sound; this is the biggest gap.
- **Effects.** Paul has one steam emitter and the arrival shake; the others have the telegraph light and the HUD. No
  dust under a footfall, nothing on a hit, no weak-point flash, nothing when the light changes, no screen response.
- **Models.** Primitive costumes on tinted kits read as "a big zombie with props" past five metres. Silhouettes are
  right; surfaces are flat (no wear, no wet, no emissive cracks on the Marke'd bosses), nothing moves on the body
  (no chains swinging, no cloth, no drips), eyes do not read.
- **Battles.** Most fights are one loop of two or three moves at one pace. There is little escalation inside a
  phase, few arena interactions, and the player's own state (hurt, alone, watching, in the dark) changes nothing.

## 1. Rules (binding, unchanged)

- `docs/HOMAGE_BOSSES.md` section 1 and 1.2: the Cousins are young women in the doll register, **never sexualized**
  (modest period clothing always intact, no fan-service framing, dignified authored deaths); PAUL is **powerful,
  heroic, never a joke** (iron-red, not green, not the Hulk); THE SLENDER is **a person, just too long** (never
  faceless, never a suit, nothing from his back). Jakub is never a zombie (CLAUDE.md). No real voice is imitated.
- Every big attack keeps a 0.5-1.0 s telegraph of pose + sound + light; nothing lands from off-screen without an
  audio tell; no grab chains into a grab; every grab breaks in solo (section 1.1 there).
- Scarier means dread, not cheapness: the readability rules above are how fear stays fair. Scare with presence
  (sound, light, stillness, the unseen), with consequence (the arena changing, the squad's state mattering), with
  bodies that are wrong in small ways, and with escalation that the player feels coming.
- Gameplay numbers (HP, damage, cooldowns, rounds) may change where a battle's rework needs it: this is a battle
  rework, not an art pass. Record every number change in the boss's data file `_doc` and in DECISIONS.
- Bots must still finish the fights (`bots_alone` scaling stays; smoke timings may be re-tuned, never removed).
- Accessibility: `screen_shake` scales every shake; `camera_sway` "reduced" / "off" halves / removes the dread kit's
  screen effects (DreadFx reads it); anim jitter bursts stay (a gameplay tell).

## 2. The shared kit (the lead; `gravelight/enemies/homage/boss_fx.gd`, `gravelight/ui/dread_fx.gd`)

### 2.1 `BossFx` (a Node3D child of every HomageBoss: `fx`; the Foreman makes its own)
- **Dread (presence).** Each physics frame the kit measures, for the local player, how close the boss is
  (`dread.radius`, default 18 m; `dread.near`, default 5 m), whether it is looking at them and whether they can see
  it, and reports a 0..1 level to `DreadFx`. Subclasses may add to the level (`fx.extra_dread = x` for a telegraph,
  a grab, the Slender's beam on you).
- **Footfalls.** `fx.stomp(at, strength, sound_id, radius)`: a dust burst under the foot (`Effects.dirt_burst`), the
  thud, a view shake on every player within `radius` falling with distance. `HomageBoss._footstep()` calls it with
  the boss's `dread.step_sound` / `dread.step_shake`, so every boss has weight without code.
- **Arena light.** `fx.lights_dim(center, radius, level, seconds)` captures every `Light3D` under the map within
  `radius` (not the boss's own, not those marked `no_dim`), remembers its base (a `FlickerLight`'s `base_energy`,
  else `light_energy`) and eases it to `base * level`; `fx.lights_flicker(seconds, depth)` gutters the captured
  lights; `fx.lights_restore(seconds)` brings them back. LampGlow follows automatically (glass and flames dim with
  their light). The Cousins' setup keeps its own lamp code.
- **Emitters.** `BossFx.emitter(kind, parent, pos, scale)` builds a quality-scaled GPUParticles3D: `dust`, `embers`,
  `motes` (Nachtglas violet), `drips`, `steam`, `frost`, `sparks`, `ash`, `smoke`. Attach to a bone with
  `bone_attachment("Chest").add_child(...)`. `emitter.emitting` is the switch; `BossFx.burst(kind, at, amount)` is
  a one-shot.
- **Hits.** `fx.hit(limb, amount, kind, surface)` from `HomageBoss._on_damaged` (the base calls it; a subclass that
  overrides `_on_damaged` calls `super`): a burst at the limb's hitbox (`surface` from the boss's `dread.surface`:
  `porcelain`, `iron`, `flesh`, `glass`, `cloth`), the matching `boss_hit_<surface>` sound; a weak point
  (`limb_mult > 1.5`) adds a violet flash on the telegraph light and `boss_weakpoint_hit`; a hit of over 2% max HP
  punches `DreadFx` (a chromatic nudge).
- **Death.** `fx.death_burst(at, color)`: motes and light, `boss_death_toll`, the dread released over 2 s.
- **Telegraph.** `fx.tele(color, energy, seconds)` drives the boss's telegraph light with one shape (a quick rise, a
  hold, a snap out) and plays `boss_telegraph_rise` for a wind-up over 0.6 s.

### 2.2 `DreadFx` (one CanvasLayer at layer 9 per local player, created on demand: `DreadFx.of(player)`)
- `report(id, level, seen_by_boss)`: the max over reporters (decayed after 0.6 s) drives: an oval vignette that
  darkens with level (to 0.55), a desaturation (to 0.35), a slow pulse timed to `boss_pulse` whose rate rises
  with level, and a faint violet bloom at the frame edge when the boss is looking at you. `boss_dread_bed` (a loop)
  rises from -40 dB to -12 dB with the level. `punch(k)`: a chromatic split for 0.25 s. `release(id)`.
- Everything is presentation: no gameplay reads DreadFx. Off / halved with `camera_sway` off / reduced.

### 2.3 Model helpers on `HomageBoss`
- `mat_ex(color, rough, metal, emit, emit_color)`: a cached StandardMaterial3D with metallic and a separate
  emission colour (rust, wet brass, porcelain glaze, a violet crack).
- `chain(bone, from, to, links, radius, color)`: a run of torus links between two local points on one attachment.
- `cable(bone, points, radius, color, emit)`: a tube through points (the Bordwart's spine, IV lines).
- `strips(bone, count, length, width, color, seed)`: hanging cloth / bandage strips that sway with a spring in
  `_process` (the kit's `Sway` helper: each strip a thin box whose tilt follows the bone's velocity).
- `cracks(bone, count, length, color, emit, seed)`: thin emissive lines on a limb's surface (Nachtglas cracks).
- `eye_glow(color, energy)`: two small emissive beads at the eye sockets plus a weak OmniLight, blinking off/on
  per the subclass (Alix never blinks).
- `wet(amount)`: the kit's instance uniform for a wet sheen (`inst_dirt` low, roughness down) on the skin.

### 2.4 Data: a `dread` block per boss (in its `bosses/*.json` entry; every key optional)
`{"radius": 18, "near": 5, "surface": "flesh", "step_sound": "boss_stomp", "step_shake": 0.35, "step_radius": 14,
"bed": "boss_dread_bed", "pulse": "boss_pulse", "look_cone_deg": 30}`

## 3. The sound pack (the lead; `gravelight/tools_src/gen_audio_bosses.py`, our own synthesis, Owned)
Shared: `boss_dread_bed` (loop), `boss_pulse` (loop), `boss_stomp_1..3`, `boss_hit_porcelain_1..3`,
`boss_hit_iron_1..3`, `boss_hit_flesh_1..3`, `boss_hit_glass_1..2`, `boss_hit_cloth_1..2`, `boss_weakpoint_hit_1..2`,
`boss_telegraph_rise`, `boss_death_toll`, `boss_roar_low_1..3`, `boss_breath_1..3`, `boss_bone_crack_1..2`.
Per boss: `boss_doll_giggle_1..3` (a music-box tinkle with a detuned wordless "hee": the Cousins), `boss_doll_crack`
(porcelain splitting), `boss_hum_wrong` (a lullaby hummed a quarter-tone flat, loop), `paul_roar_1..2`,
`paul_bottle_break_1..2`, `paul_plate_grind`, `slender_lantern_hum` (loop), `slender_keys_still` (the jingle that
stops), `slender_whisper_1..3`, `kielholer_chain_drag` (loop), `kielholer_water_rise_1..2`, `kielholer_helmet_knock`,
`foreman_drill_spin` (loop), `foreman_chain_whip`, `kran_rail_screech_1..2`, `kran_casing_drop`, `bordwart_cable_sing`,
`bordwart_impeller_loop` (loop), `pilot_rig_whine` (loop), `pilot_rig_misfire`, `manager_servo_1..2`,
`manager_stamp`, `manager_field_hum` (loop). Every id is in `data/gravelight/audio.json` after the run; workers use
these ids and request more from the lead rather than editing audio.json (merge conflicts).

## 4. The workers (worktrees; one branch each; the files they own)

Common brief for every worker: read this doc, `docs/HOMAGE_BOSSES.md` (the rules and your boss's section),
`docs/DECISIONS.md` (your boss's T paragraphs), your boss's script, director and data, and the smoke. Then:
1. **Model.** Rebuild the costume pass with the helpers in 2.3: surfaces with wear, wet and emission where the
   story says; something that moves on the body (chains, strips, cables, a lantern swinging); eyes that read;
   the Marke or the wound site lit. Keep silhouettes and the Likeness Sheet. Check it rendered (section 5).
2. **Effects.** Attach the kit: `dread` block in data, footfalls through `_footstep`, hits through `_on_damaged`
   (call super), `lights_dim` / `lights_flicker` where the fight changes the room, emitters on the body
   (breath, drips, dust, motes), `fx.tele` on every telegraph, `death_burst` on death; your boss's own sounds
   from section 3 on every move (no more `board_slam`).
3. **Battle.** Make it escalate: at least one new phase or move, arena interaction (lights, doors, props, water,
   wind), and a rule that reads the squad's state (alone, hurt, watching, in the dark). Keep every telegraph,
   break-free and the fail-safe. Bots must still finish it: run the smoke, extend it for the new moves.
4. **Verify.** `check_scripts`, the boss's smoke, `test_*` suites that touch your files, and a rendered look:
   `tools_src/capture.gd --set=<your set>` under WSL (`sh tools/wsl_godot.sh --path . res://tools_src/capture.tscn
   -- --set=u14_<boss> --label=<label>`), with a `do: ["boss:<id>:x,y,z"]` camera (the new CaptureDo op) so the
   boss stands in frame. Headless only; never a window on the owner's PC.
5. **Write.** A paragraph for DECISIONS in `docs/boss_rework/<worker>.md` (what, why, numbers changed, what the
   render showed), the boss's design section updated in place (HOMAGE_BOSSES.md / MAP4_FERNFLUG.md / ENEMIES.md),
   and the smoke's header. Commit on your branch with the Co-Authored-By line. Do not touch another worker's files,
   `boss_fx.gd`, `dread_fx.gd`, `audio.json`, or `homage_boss.gd` (ask the lead).

| Worker | Bosses | Owns |
|---|---|---|
| W1 cousins | the Hammer, the Reach, Alix (+ CousinsRound) | `enemies/homage/cousin_*.gd`, `cousins_round.gd`, `bosses/cousins.json`, `smoke_cousins`, cams set `u14_cousins` |
| W2 kaltenbrunn | PAUL, THE FOREMAN (+ the Screamer's effects) | `homage/paul*.gd`, `enemies/foreman.gd`, `enemies/screamer.gd`, `bosses/map01.json`, `enemies.json` foreman / screamer rows, `smoke_paul`, cams `u14_paul`, `u14_foreman` |
| W3 totenhafen | THE SLENDER, DER KIELHOLER | `homage/slender*.gd`, `watch_meter.gd`, `homage/kielholer.gd`, `world/map02/kielholer_controller.gd`, `bosses/map02.json`, `smoke_slender`, `smoke_kielholer`, cams `u14_slender`, `u14_kielholer` |
| W4 fernflug | DER KRANFÜHRER, DER BORDWART, THE TEST PILOT, THE ACCOUNT MANAGER | `enemies/map04/*.gd`, `bosses/map04.json`, `smoke_act_bosses`, cams `u14_act_bosses` |

### 4.1 Per-boss direction (the lead's notes; the worker decides the rest)
- **The Cousins.** The doll register, pushed: porcelain with a glaze, hairline cracks that spread as they take
  damage (the `cracks` helper, count by hp fraction), glass eyes that catch light and never blink (Alix) or blink
  too slowly (the others); the Hammer's braid swings; the Reach's stretched arms show veins and the sleeve tears at
  the elbow only. Sound: the hum goes flat as they enrage, giggles that stop too suddenly, porcelain on every hit.
  Battle: the lamps come back one by one as cousins die but the LAST cousin puts them out again and hunts in the
  dark (Alix's freeze needs light: a lantern the players carry? no: keep it simple: the hearth relights for the
  finale); the Hammer's throw ricochets twice when enraged; the Reach grabs through a window the players boarded;
  Alix's grief window lengthens with each dead cousin (she hesitates longer, hits harder). Never ragdoll; the deaths
  stay dignified.
- **PAUL.** Iron-red skin with a wet sheen, the plates with rust and rivet shadows, the bottles lit from inside,
  the IV lines dripping, steam on every exhale, the ground cracking (a decal) under each stomp at BERSERK.
  Battle: a third-stage "protect my guys" turn: at BERSERK he shields a downed player's body (stands over them,
  anyone near takes the slam); the rage meter spikes when players flee out of his sight; an arena beat where the
  headframe's lamps swing and the yard's floods die under his roar.
- **THE FOREMAN.** His own body (not HomageBoss): rebuild it with the helpers' equivalents (metal with rust and
  oil, the drill core's violet pulsing, the chain dragging with sparks, the cap welded into the helmet), footfall
  shake, the chain-drag loop, the drill spin loop; the rock-burst arrival with dust and a light drop; an enraged
  phase that puts the gallery lamps out while the core glows brighter (he is the light).
- **THE SLENDER.** Keep "a person, just too long": the coat moves (strips), the lantern swings and its violet light
  pools on the catwalk grating; eyes that catch the lantern; the keys' jingle that stops is already the best tell,
  give it the `slender_keys_still` sound. Battle: the beam's Watch tiers get visible consequence (the screen's
  edge goes violet, whispers in your own character's voice? no: wordless `slender_whisper`); at End of Shift the
  only light is his lantern and the fuse boxes spark; a Mirroring move that stands him where you were a second ago.
- **DER KIELHOLER.** Water: he drips for ten seconds after surfacing (drips emitter), the chain drags through the
  water (`kielholer_chain_drag`), the helmet glass fogs from inside and breaks with a crack; a submerge pulls the
  dock lamps' reflections; the ripple telegraph gets a sound; at spring tide the surfacing is faster and closer.
- **The Fernflug four.** Each is a machine fused with a man: give the machine its sound loop (impeller, rig,
  servo, rail) and the man his breath; lights that die with the phase (the hangar's floods, the engine room, the
  lab, the Account); hits spark on metal and mist on flesh; the Account Manager's shield cells hum and her stamp
  slams; the Test Pilot's landing shock cracks the floor; the Kranführer's casings whistle. Battles: one new beat
  each (the lead suggests: the crane drops the hangar's work lights one by one; the Bordwart's overspeed banks the
  deck into darkness with only the core's white; the Pilot's stall is the one window and the Burrowers come up
  during it; the Manager's COLLECTIONS prices the whole squad at once when nobody is in her light).

## 5. Verification and merge (the lead)
- Every worker's smoke alone (load-sensitive), then `tools/run_smokes.sh <dir> map00`, `map01`, `map02`, `map04`,
  `cousins`, `paul`, `slender`, `kielholer`, `act_bosses`, `requiem`, `letzte_fahrt`; GUT suites that touch
  enemies / bosses / hud / audio (`test_homage*`, `test_boss*`, `test_audio*`, `test_map0*`, `test_act*`).
- Renders: each worker's `u14_*` set under WSL; the lead looks at every frame before the report (the T-228 lesson:
  what the owner sees is the render, not the geometry).
- Merge order: W2, W3, W4, W1 (the Cousins touch the most shared text). `audio.json` and `capture_cams.json` are
  merged with `tools/json_merge3.py` if two sides touched them.
- Docs: DECISIONS T-231 (the kit) + T-232..T-235 (the workers' paragraphs folded in), HOMAGE_BOSSES.md,
  MAP4_FERNFLUG.md, ENEMIES.md, this file's status, PROGRESS, the morning report, NEEDS_DEVIN (the owner's look).
