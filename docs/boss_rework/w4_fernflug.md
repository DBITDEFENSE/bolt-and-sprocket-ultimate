# W4: the Fernflug four (T-234; docs/BOSS_REWORK.md section 4.1 "The Fernflug four")

Branch `w4-fernflug-bosses` from `claude/boss-rework` at 5c4987bb (the kit). Files: `gravelight/enemies/map04/*.gd`,
`data/gravelight/bosses/map04.json` (version 2: a `dread` block and a `rework` block per boss), `smoke_act_bosses.gd`,
`gravelight/tests/unit/test_fernflug_rework.gd`, the `u14_act_bosses` camera set, MAP4_FERNFLUG.md 3.8 / 4.7 / 5.7 /
6.7. Nothing in the kit, `audio.json`, `homage_boss.gd`, the generators or the act controller was touched. The rules
held: every big attack keeps its telegraph (pose + sound + light, 0.5 s or more; the new squad pricing has 1.4 s), no
grab chains into a grab, the Pilot's drag still breaks in solo, every fail-safe (`failsafe_seconds`, the retreat's
double release, the Manager's escalation) is as it was, and nobody dies in the finale but the dead. The paragraphs
below are written for DECISIONS.

**T-234a — DER KRANFÜHRER (map04a): the crane that puts the lights out.** The model: the cab keeps its yellow blocks and
gains rust where the water ran (six plates on the sides and the roof, `mat_ex` rust), oil down its face and floor (two
glossy runs and a `drips` emitter under the floor), a violet gauge on its front (its own material, pulsing at 0.6 Hz in
phase 1 and faster each phase, pinned bright through a telegraph, with a weak violet OmniLight), the seat he is fused
into and two levers under his hands; the hook hangs from a real chain (torus links through `_chain_run`, a 1.6 m run
while he runs the rail and an 11 m run for the sweep, toggled rather than stretched, each ending in a shank-and-bill
hook with a rust plate); the man wears a cap and gloves, two violet `cable` tubes from his spine into the seat and a
third dark one from his chest, `cracks` on the chest where the metal meets him, `wet` for the oil sheen and `eye_glow`
(pale violet, blinking every 4.5 s). Effects: `dread` iron (hits spark, `boss_hit_iron`), no footfalls (he never
walks); `kran_rail_screech` as a 3D loop that plays while the trolley moves and stops when it stands (pitch 1.25 when he
hunts someone alone, 0.7 under the sweep); `kran_casing_drop` at the start of a fall (the whistle lasts the 0.9 s) and
again over the ring; an impact is `boss_stomp` + `boss_hit_iron`, sparks and dust bursts, a scorch and the kit's view
shake (0.5 within 20 m, as before, now through `fx.shake_all`); `fx.tele` on every telegraph (amber for a casing, violet
for the sweep, red-amber for the ring); `boss_breath` from the cab every ~5 s between moves instead of the Cousins' hum
(the base's `_update_audio` played `screamer_hum` under every Fernflug boss: overridden in all four); a death kills the
gauge and the loop with a spark-and-smoke burst before the kit's toll. The beat: the hangar's work lights (the
`power_lights` of H_HALLE, sorted farthest-from-the-ramp first) die one by one as his phases advance: at phase 2 and
again at phase 3 `lights_to_drop` takes 35 % of them (rounded up), never below the 3 nearest the ramp, one every 1.1 s,
each with a quick flare-gutter-out tween, sparks and chips, a `boss_hit_glass` pop and a small shake; they come back
over 2.5 s on his death (if the power is on) and at once on a retreat. The squad rule (`is_alone`): in a squad of two
or more, a target with no teammate within 12 m is found faster: the trolley at 3.0 -> 3.9 m/s and the casing cooldown
5.0 -> 3.75 s; a squad of one is never "alone" (nothing to be apart from), so solo balance is unchanged. Numbers: rail
speed 3.0 (x1.3 alone, new), casing cooldown 5.0 (x0.75 alone, new); damage, radii, telegraphs, phases unchanged.
Open: the hangar's lights are only there with the power on (the smoke runs him with the power off, so it checks the
queue and the pure rule, and the drop itself only when lights are lit); the rail screech id is a one-shot file looped by
`make_loop_3d` (a seamless `kran_rail_loop` would be better: asked of the lead).

**T-234b — DER BORDWART (map04b): Overspeed is darkness and one white light.** The model: the station is built as a
top-level node at the station point (so it no longer swings when he turns): a machine-grey cabinet between him and the
core with four lit dials (amber and green, pulsing, brighter under the pull and the Overspeed), rust plates, two vent
pipes breathing `steam`, a boom post and a boom over his head, violet trunk cables from the boom down to his back and
on to the core (sagging `Props.cable` runs in `nachtglas`); the man carries the cable spine up his back (three `cable`
tubes with violet emission into the boom), `cracks` on the spine and neck where it enters, a panel with two lit dials at
his hips (the gauges that are his weak point in Overspeed), an engineer's cap, `wet` sweat and `eye_glow` (pale,
blinking every 5 s). The lash's cable is a `cable` whip built once on the spine and shown taut-and-low through the
telegraph, full through the lash. The old `_build_costume` spine cylinder and the scaled tether are gone. Effects:
`dread` iron; `bordwart_impeller_loop` as a 3D loop at the core from the spawn (pitch +0.15 under the pull, 1.35 in
Overspeed, falling to 0.5 and stopping on his death); `bordwart_cable_sing` at the lash telegraph and at the lash (the
old `chain` sfx is gone); a vent is `boss_stomp` + `boss_roar_low`, steam, motes and sparks at the core, the core light
flared to 9 and the kit's shake (0.5 within 16 m, as before); `fx.tele` on the vent (white), the lash (violet) and the
pull (dim); `boss_breath` over the intercom every ~6 s between moves; the hit on a lashed player rings iron. The beat:
Overspeed banks the engine room into darkness through the kit: `fx.lights_dim` captures every light within 28 m of the
station and `lights_flicker(2.2, 0.9)` gutters them for 2.2 s while they fade to 0 over 3.2 s (the zone's power lights
are tweened to 0 over 3 s too, instead of the old instant cut), a white OmniLight at the core comes up to 3.0 (its only
light, wavering), and every bank flares the core to 9, flickers what is left and vents steam; death restores the lights
over 3 s (the base's `_vanish` restores them on a retreat). The squad rule (`pull_mps`): the pull takes a player under
50 % health at x1.4 (2.5 -> 3.5 m/s; the impeller takes the weak first; the pull is its own tell and the rib frames still
block it). Numbers: pull 2.5 m/s (x1.4 under 50 % health, new); Overspeed lights instant-off -> 2.2 s gutter + 3.2 s
fade, radius 28 m (new); everything else unchanged. Open: no vent sound of its own (`boss_stomp` + `boss_roar_low`
stand in; a `bordwart_vent` burst is asked of the lead); the impeller loop is parented to the station node, which
is freed with the boss.

**T-234c — THE TEST PILOT (map04c): the Stall is dark and the dead come up.** The model: the helmet keeps its sphere
and gets a glossy visor plate (`mat_ex` roughness 0.06, metal 0.75: it catches light) with a steel rim and a faint amber
lamp behind it (`eye_glow` at the visor, never blinking); the rig is a pack with a shoulder yoke, two nozzle cylinders
with violet emissive rings and an `embers` emitter at each mouth blowing down (the heat; lit from the crouch to the
landing, and again through the Stall), a `smoke` emitter for the misfire, an amber rig light, two cables over the
shoulders and four hanging `strips` from the harness; `cracks` in violet on the left upper arm, the right forearm and the
neck (the program kept him), `wet` sweat, salt dust on the skin. Effects: `dread` flesh (hits mist); no footfalls
through the base but the landings stomp through `fx.stomp` directly (`dread.land_sound` boss_stomp, `land_shake` 0.5,
`land_radius` 22 m: the old 20 m); `pilot_rig_whine` as a 3D loop that starts at the crouch at pitch 0.8, climbs to 1.2
through the telegraph and 1.3 in the arc, and stops at the landing; `pilot_rig_misfire` at the Stall, every 0.9 s of it
with sparks, at the catch and at his death; a landing bursts dust and chips and leaves a dark cracked patch on the floor
(`_floor_crack`: a 2.6 m quad and six radiating splits, faded after 40 s); the launch bursts dust and embers with a low
roar; `fx.tele` amber on the crouch; `boss_breath` through the dead radio every ~5 s; the old `grenade_explode` landing
is gone. The beat: the Stall is the one window and it is dark: when the rig misfires, `fx.lights_dim` takes every light
within 40 m down to 12 % with a 1.4 s gutter (his rig the only light) and, when he is on the lakebed, 3 Burrowers (+1 per
extra player) come up 6-11 m round the squad (Gängers in the technician kit through the director, tagged "burrower" for
the GroomController when it is there, a salt burst each); the lights come back over 4 s when he rises. The squad rule
(`watching`, `leap.prefer_unwatching`): at the crouch he picks the nearest living player whose camera does not hold him
(the view's half-plane, cos >= 0.1) and leaps at them; when everyone is watching he takes the nearest as before. The
whine is the tell from behind (1.1 s), so nobody is hit without one; the local human picked gets a dread spike. Numbers:
landing shake radius 20 -> 22 m; Stall lights 12 % within 40 m (new); Burrowers 3 + 1/extra (new); the catch's shake
0.5 -> 0.6; damage, cooldowns, phases unchanged. Open: the Burrowers rise round the squad wherever it stands on the
lakebed (not the GroomController's burrow points, which it moves on its own clock); the floor crack is a mesh, not a
Decal, so it sits 3 cm over the floor and would float over a slope.

**T-234d — THE ACCOUNT MANAGER (map04d): she prices the squad when nobody stands in her light.** The model: the ledger
face keeps its plate and gains five brass rulings and nine lit violet signature lines (her script; its own material,
dimmed to a quarter when she folds), a brass cap, and the two lenses as her "eyes" (`eye_glow` at the lens points, never
blinking); the chest plate is now a real plate on a hinge at its top edge (`_plate_piv`) that swings open 1.9 rad over
0.45 s when a contract is presented and shuts when it ends, with a dark cavity, the brass signature line lit violet and
a violet light behind it; the welcome arms get brass joints; the cabinet gets brass trim and ledger `cracks`; and her
light is a violet SpotLight3D over the console (range 10 m, 38 degrees, energy 3) pooling on the floor in front of her.
Effects: `dread` glass (hits are motes and `boss_hit_glass`); `manager_servo` on every move and phase and now and then
while she waits (no hum, no breath: she is a machine); `manager_stamp` on a pricing (the old `board_slam` is gone);
`manager_field_hum` as a 3D loop while the field is up (phases 1-2), stopped when the field drops; `fx.tele` violet on
every telegraph; the shield-cells hum (each its own `manager_field_hum` loop) and spark on every hit (`ShieldCell.
take_damage`: sparks and motes, `boss_hit_glass`, the glow flares), and go out with motes and glass instead of a gib. The
beat: at COLLECTIONS the Account's lamps within 22 m die to 10 % through the kit (a 2 s gutter; her light stays, it is
hers), and when nobody alive has stood in her light (`in_light`: within 7 m and acos(0.35) of her facing) for 6 s she
prices the whole squad at once (`PRICE_ALL_TELE`, 1.4 s: the servo, the hum back up at +6 dB, her light tweened to 9,
the telegraph light, her second pricing line; then `_stamp_all`: 60 damage and 5 % of the account to every living
player wherever they stand, the stamp at each, a 20 s cooldown); standing in her light, where the arms sweep, is the
way to stop it. The squad rule (`present_seconds`): with one human standing the presented contract stays open 3.0 ->
4.5 s (x1.5; she is polite to a squad of one; bots alone get it too). Escalation restores the lights, shuts the plate,
dims the face and her light, stops the hum. Numbers: present 3.0 s -> 4.5 s with one human (new); price_all 60 damage,
5 % Scrip, 20 s cooldown, 1.4 s telegraph, 6 s dark (new); the Account's lamps 10 % within 22 m at COLLECTIONS (new);
the single stamp, the arms, the trial, the crew and the cells unchanged. Open: the hinge opens the plate upward through
the arms' idle pose (it reads as a lid; a sideways door would need the arms moved).

## Verification

- `check_scripts`: 881 scripts, 0 failed (after the rewrite).
- GUT: see the table below.
- `smoke_act_bosses` alone: see below.
- Renders: `morning/screenshots/u14_act_bosses/w4/` (WSL, software GL, `override.cfg` copied from the main checkout).

| Check | Result |
|---|---|
| `check_scripts` | 881 scripts, 0 failed (every pass) |
| `smoke_act_bosses` (alone, headless; three runs) | PASS, 71 checks ok, 0 script errors in the last two runs (the first run passed with 266 kit errors from a captured light freed mid-fight: the shield-cells' glows; fixed by capturing the Account's lamps before the cells spawn and marking the cells' glows and the trial tray's lamp `no_dim`) |
| GUT `test_fernflug_rework` | 6 / 6, 79 asserts |
| GUT `test_kranfuehrer` / `test_testpilot` / `test_account_manager` | 4 / 4 / 6 tests, all passed |
| GUT `test_flight`, `test_bot_u10`, `test_map04a..d`, `test_boss_fx`, `test_suited`, `test_marke`, `test_kuendigung` | 18, 55, 13 + 8 + 8 + 8, 4, 3, 12, 26 tests, all passed |

What the smoke saw: the Kranführer's phase 2 queues the work-light drops and brings the hook down for the sweep
within 20 s (the hangar's work lights are 0 with the power off, so the drop itself runs only in play with the power
on); the Bordwart's Overspeed captured 30 lights within 28 m, the core came up and flared twice; the Test Pilot
stalled on his next landing with the lights dimmed, 1 floor crack and 3 Burrowers raised, and rose with the lights
restored; the Account Manager's COLLECTIONS darkened the Account, and with the player 10 m off (outside her light)
the squad pricing fired after 6 s and cut the account 2500 -> 2137 (a 5 % cut on 2500 plus the stamp's 90-damage
path through god mode: the Scrip is the visible consequence).

Renders (pass 1, kept in `morning/screenshots/u14_act_bosses/w4_pass1/`; pass 2 in `w4/`): pass 1 showed the cab
15 m off and unlit from the catwalk and 25 m off from the floor (too far, the hangar dark with the power's lights
off), a second boss summoned by every second camera (the map persists between cameras on the same map, so the
second camera of each pair now reuses the posed boss with `"do": []`), the Bordwart's station reading right in the
violet (the man at the cabinet, the boom, the trunk to the core) but its dials blooming into headlights (emission
1.2 -> 0.45, radius 0.11 -> 0.08; the hip dials 1.4 -> 0.5) and the thin boom cables too bright (`nachtglas` ->
`nachtglas_dim`), the Pilot 8 m off in the lab's bright wash with his embers visible, and the Manager's plate and
cabinet blooming white in the Account's hard light (plate emission 0.5 -> 0.12, the face lines 2.2 -> 1.2, her spot
3.0 -> 1.8). Pass 2 moved every camera to 4-8 m and lit the hangar frames with the work light. RENDER2_PLACEHOLDER

Kit note for the lead: `boss_fx.gd` lines 106 and 229 assign `e[0]` to a typed `Light3D` before `is_instance_valid`
runs, so a captured light freed mid-fight (a shot shield-cell's glow, a trial tray freed at a phase change, in
general anything transient within the dim radius) prints "Trying to assign invalid previously freed instance" every
frame of a flicker or fade. A `Variant` local or the validity check first would make the kit safe for every boss.

## Sound ids wanted from the lead
- `kran_rail_loop` (a seamless rail screech loop; the one-shot `kran_rail_screech` is looped by `make_loop_3d` for now).
- `bordwart_vent` (the core's burst: a steam slam with a violet tail; `boss_stomp` + `boss_roar_low` stand in).
- `pilot_land` (a rig landing: the thud with the turbine's cut-out; `boss_stomp` stands in).
- `manager_plate` (the chest plate's hinge; the servo stands in).
- `manager_price_all` (the squad pricing's stamp slam, bigger than `manager_stamp`, which plays at +6 dB for it now).
