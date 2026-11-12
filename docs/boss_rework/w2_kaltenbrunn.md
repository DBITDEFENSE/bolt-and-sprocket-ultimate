# Boss rework, worker W2: Kaltenbrunn (PAUL, THE FOREMAN, the Screamer's effects)

Branch: the W2 worktree off `claude/boss-rework` at 5c4987bb (the kit). Brief: `docs/BOSS_REWORK.md` sections 1-4, 4.1
"PAUL" and "THE FOREMAN". The rules that bound the work: HOMAGE_BOSSES 1.2 (PAUL powerful, heroic, never a joke; iron-red,
never green; no "smash"; no joke about his size), every big attack a 0.5-1.0 s telegraph of pose + sound + light, no grab
chaining into a grab, every grab breaking in solo. The paragraphs below are written for DECISIONS (T-232), one per boss.

## T-232a: PAUL (gravelight/enemies/homage/paul.gd, paul_rage.gd, paul_encounter.gd, data/gravelight/bosses/map01.json)

**Model (the kit's helpers).** The costume pass was rebuilt on `mat_ex` / `cable` / `eye_glow` / `wet` and the kit's emitters:
iron-red skin (the `inst_tint` stays) with a wet sheen on the chest; the seven riveted plates in rust-rough iron (rough 0.78,
metal 0.35) with a darker rim where they push out of the skin, rivets in polished brass-tin with a shadow disc under each
and rust streaks running down from the lower pair, every plate one group that still extrudes 12 % per stage; the six Helvetia
bottles **lit from inside** (his own emissive amber glass material, 1.6x, a tin cap, a paper label, an amber OmniLight on the
rack) that **dim as each breaks** (`_update_bottle_glow`: 0.3 + 0.7 x bottles left / 6; the rack light with it); the IV lines
as `cable` tubes from each bottle's neck over the shoulder into the back of the neck with a faint violet emission (the
Nachtglas in the stout); `drips` at the neck where they go in (the kit's emitter, on from the spawn); `steam` off the plates
(the kit's emitter replaces the hand-made one); eyes that read (`eye_glow`, warm amber 1.0, a 4.5 s blink, brighter and
redder per stage, dimming through the death and out when he falls); the tin cup and the dog tags in polished tin. The
Likeness Sheet silhouette and the scale (1.38 x 1.00 / 1.15 / 1.30) are unchanged; nothing jokes.

**Effects.** `map01.json` grew a `dread` block (radius 20, near 5, surface flesh, `boss_stomp` footfalls, shake 0.45, radius
16, look cone 35) plus `stage_step_shake` 0.2 / `stage_step_radius` 4 that `_apply_stage_look` writes into `fx.cfg` on every
stage change (Calm 0.45 / 16 m, Angry 0.65 / 20 m, BERSERK 0.85 / 24 m). The old 0.55 s stomp timer (`foreman_stomp`) is gone:
the kit's footfall fires from the rig's real steps (`HomageBoss._footstep`); at BERSERK each step also leaves a **ground
crack decal** (a dark quad with four crack lines at the foot, 25 s fade, at most 24 on the ground, oldest first), and the
Ground Pound, the landings, the Rip & Throw impact and the guard slam leave bigger ones. `fx.tele` runs every telegraph in
the stout's amber-red (`_tele_glow` hands the light to the kit's shape while a telegraph or the headframe perch runs; the
violet is kept for a bottle breaking). Sounds: `paul_roar` on the stage-ups, the landing, the grab, the dive, the shaft, the
vault wait, the retreat and the floods beat; `paul_plate_grind` on growth and the rip; `paul_bottle_break` when a bottle goes
(`boss_hit_glass` + motes on a bottle hit, a `drips` splash and motes on the break); `boss_breath` on the breath clock (every
2.2-3.4 s at Calm, faster per stage, a puff of steam with it; constant steam at BERSERK), the Thunderclap's inhale and the
shrink's hiss; `boss_roar_low` for the grunts and the roar in a held player's face; `boss_stomp` for the knuckles pawing the
ground, the chest beat, the wall hit and every landing; `boss_bone_crack` for the knee-down, the haymaker landing and the
bowled zombie's end. Every `foreman_*` and `impact_flesh` placeholder is gone from his script. The kit's `fx.hit` (flesh
mist, `boss_hit_flesh`, the dread punch on a heavy hit) runs through the base `_on_damaged`. **The floods beat:** entering
BERSERK dims every light within 32 m of him to 12 % over 1 s and gutters them 2.5 s (`fx.lights_dim` + `lights_flicker`),
gutters them again every 18 s while he stays BERSERK (with a roar), and the encounter shakes the headframe 2.5 s and swings
its floodlights on their brackets for 7 s (`PaulEncounter.swing_lamps`: the generator's `*Flood*` brackets within 30 m of
the headframe and the spot lights hung on them, a damped 0.26 rad sin). The light comes back over 5 s when he shrinks out of
BERSERK, over 3 s when he leaves, over 6 s as the rage drains out of him on his knees.

**Battle (every existing move, the rage system, the fail-safe and the death are unchanged).** (1) **The Guard, "protect my
guys"** (`guard` block): at BERSERK a downed player (not bled out) within 30 m in his sight pulls him off his target; he
walks to the body (`PAU_CALM_03` "Nobody gets left. Nobody.", a roar), stands over it with his arms spread for up to 12 s and
slams anyone who comes within 4.5 m: a 0.6 s wind-up (both fists up, `paul_roar`, the kit's light), then 60 + knockdown in
the **half-circle in front of him** (3.5 m, 180 deg); he faces the comer only when a slam starts and slams at most every
2.5 s, so a teammate can revive from the far side between slams; the guard ends when the body is revived or bleeds out,
after 12 s, or when a blast stagger / wall stun breaks it, and he does not guard again for 8 s. It is a SPECIAL state, never
a grab: nothing chains, and in solo it cannot occur (a downed solo player is the end of the match). (2) **The flee spike**
(`PaulRage.on_flee_break`, data `rage.flee_break` 6, `flee_break_every` 3): a player he could see a moment ago who sprints
out of his sight within 20 m spikes the meter +6 at once (at most every 3 s per player), with `PAU_FLEE_01` and a low roar;
the per-second fleeing fill stays as it was. (3) **The squad rules** (`squad` block): a hurt player (under 35 %, within 25 m,
in his sight) becomes his target while he chooses a move (`PAU_CALM_03` at most every 20 s) and adds 0.25 to the dread layer
of that player; a lone player (one on their feet) gets Haymaker and Zombie Throw back at 0.8x their cooldowns but Grab &
Squeeze holds them at most 3.5 s (was 5) and breaks on 6 presses (was 8): the pressure moves out of the grab, the solo break
stays fair. **Numbers changed, old -> new:** footfall shake none (a timer sound) -> 0.45 / 0.65 / 0.85 by stage; rage +0 ->
+6 on a flee-break; the lone player's grab max 5.0 -> 3.5 s and mash 8 -> 6; the lone player's Haymaker / Zombie Throw
cooldowns 3 / 10 -> 2.4 / 8 s; new: the guard (0.6 s telegraph, 3.5 m, 60, 2.5 s, 12 s max, 8 s again_after); new: the
floods (32 m, 12 %, 2.5 s gutter, every 18 s, 7 s swing, 5 s restore). Nothing else in the move table moved
(`test_move_table_numbers` is unchanged and green).

**Capture.** The CaptureDo `boss:paul` op returns his encounter (a round director: `summon_boss(&"paul")` calls
`start_now()`, which only reserves the next round while the capture has stopped the rounds), so the `u14_paul` set poses him
through `callv:PaulEncounter:pose:x,y,z,yaw,rage` (adopts a Paul at the point with the title card and his bar, applies the
stage's growth at once, holds him still) and re-poses him with `callv:Paul:debug_pose:yaw,rage`.

**Verification.** (filled in below, section "Results".)

## T-232b: THE FOREMAN (gravelight/enemies/foreman.gd, data/gravelight/enemies.json "foreman")

**Model.** His own body (not a HomageBoss) rebuilt in place on `HomageBoss.mat_ex` surfaces through a `_shape(parent, parts,
material)` helper beside the old `_mesh`: rust (rough 0.95) on the pauldron, the helmet, the knee guards, the boots' toe caps,
the drill housing's band, the fist's wrap and every third chain link; oil (rough 0.12, metal 0.55) streaking the apron, the
coat front, the piston and the housing; brass buckles and the cap's badge; the drill core his own emissive instance (4x,
pulsing as before, 13x ENRAGED, flaring to 24x in the vent and on a core hit) with Nachtglas veins through the coat and the
housing in a second instance that pulses with it; the ore chain a real run of ten alternating links dragging behind him with
a `sparks` emitter on the last link that runs while he walks; the Obersteiger cap (crown, visor, badge) welded into the
helmet with ten weld beads along the seam; the greatcoat's hem in seven `BossFx.SwayStrips`; the headlamp a real SpotLight3D
(1.1, 14 m, 28 deg) with an emissive lens; `dust` under his feet while he walks. Silhouette (3.2 m, top-heavy, the right-arm
drill) unchanged.

**Effects.** `fx = BossFx.make(self, dread, &"foreman")` from `enemies.json "dread"` (radius 22, near 5, surface iron,
`boss_stomp`, shake 0.5, radius 16); `has_los()` added for the kit's meter; a `_tele_light` on the torso so `fx.tele` works.
Footfalls: the step timer that plays `foreman_step` also calls `fx.stomp` at the alternating foot (dust, `boss_stomp`, the
view shake). `foreman_drill_spin` loops whenever the drill is up (jab, slam, charge wind-up, charge, vent; pitched up 1.35
through the vent), `foreman_drill` still screams in the jab, `foreman_chain_whip` is the whip (the rattle `foreman_chain` is
its 0.4 s tell), the existing `foreman_step` / `foreman_chain` / `foreman_roar` stay. `fx.tele` on every telegraph (violet;
the charge's in red-violet). Hits through `fx.hit` (iron sparks, `boss_hit_iron`); only the core passes its multiplier, so
the violet weak-point flash and `boss_weakpoint_hit` are the core's (the helmet's x1.5 sparks like iron). The **rock-burst
arrival**: through the 4 s tell dust and chips fall off the wall every 0.7 s with a crack; the burst throws dust, chips and
motes, `boss_stomp` + the roar, shakes every view within 22 m and drops every light within 14 m to 20 % with a 2.2 s gutter
for 2.5 s before `lights_restore` (the puppet does the same on its STALK entry). Death: `fx.death_burst`, the loops stopped,
the lamps back over 3 s, the core and the headlamp fading, the dread released when he sinks away.

**Battle.** (1) **ENRAGED puts the gallery lamps out** (`enrage_lights`: radius 26, level 0.08, follow 16 m): at 30 % every
light within 26 m of him drops to 8 % with a 3 s gutter and stays out; when he has walked 16 m from where they went out they
come back over 1.2 s and 1.4 s later the lamps round his new spot go (the dark walks with him); he is the light: the core at
13x with its light 3.8 at 9 m (1.4 at 4 m), the headlamp 2.4 (1.1). The speed and cooldown multipliers of ENRAGED are as they
were. (2) **Core Vent**, the new ENRAGED move (`vent`: damage 35, radius 6, windup 1.0, cooldown 14, slow 1.5, core_mult 4):
picked when an ENRAGED target stands between jab reach and 6.6 m; he plants the drill in the stone, the core flares for 1.0 s
(the drill-spin loop climbs, `boss_telegraph_rise`, the violet light) **while the core takes x4** (the window: shoot it), then
the Nachtglas bursts: 35 damage, `whip_slow` 1.5 s and a dread punch (`DreadFx.punch(1.0)`) on every player within 6 m, a burst
of motes and sparks, a shake. (3) **The squad rules** (`squad`): a hurt player (under 35 %, within 25 m, in his sight) is his
target while he stalks and hears the cadence (`foreman_roar`) shouted at them every 12 s at most, with 0.25 on their dread
layer; a lone player gets the chain whip from any side, not only from behind (`alone_whip_any_side`). **Numbers changed, old
-> new:** footfall shake none -> 0.5 to 16 m; the whip's "behind him" gate -> any side for a lone player; ENRAGED core glow
9x -> 13x, core light 1.4 / 4 m -> 3.8 / 9 m, headlamp (new) 1.1 -> 2.4; new: Core Vent (1.0 s, 35, 6 m, 14 s, x4 on the core
through it); new: the arrival's light drop (14 m, 20 %, 2.5 s); new: the ENRAGED dark (26 m, 8 %, follows at 16 m). Jab, slam,
charge and whip damage, cooldowns and tells are unchanged. The `F` enum gained `VENT` at the end, so the puppet's sub-states
keep their values.

**Verification.** (filled in below.)

## T-232c: the Screamer (gravelight/enemies/screamer.gd, enemies.json "screamer"; effects only)

Every player the scream reaches takes a dread punch (`DreadFx.of(p).punch(scream_punch 1.0)`; the puppet punches the local
human when it is within the scream's range and sight); Nachtglas `motes` rise from the throat through the 1.5 s wind-up and
burst out with the scream; the throat glow pulses with the lullaby at `throat_pulse_hz` 1.4 (a slow breath at 0.6 + 0.3)
and races as she winds up (the pulse rate to 4x, the glow 0.4 -> 5.0 as before, snapping to 7 on the scream). No timing,
cone, cooldown or damage changed.

## Results

(filled in by the worker after the runs.)

## Open issues and sounds wanted from the lead

(filled in by the worker after the runs.)
