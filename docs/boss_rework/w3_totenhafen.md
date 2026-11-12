# W3: THE SLENDER and DER KIELHOLER reworked (the boss rework, docs/BOSS_REWORK.md 4.1; branch `claude/boss-rework-w3`)

Two DECISIONS-style paragraphs for the lead to fold in as T-233 (one per boss), then the verification, the open issues
and the sounds this worker wants from the lead. The rules that bound this work: HOMAGE_BOSSES 1.2 (THE SLENDER is a
person, just too long: a calm, tired, kind-faced night watchman, never faceless, never a suit, nothing from his back;
the Kielholer is Kptlt. Lenz in a salvage dress, never a joke, his death quiet), 1.1 (every big attack keeps a 0.5-1.0 s
telegraph of pose + sound + light, no grab chains into a grab, every grab breaks in solo) and the rework's "scarier
means dread and consequence, never cheapness".

## T-233a, THE SLENDER, the Hafenwächter (Totenhafen round 25), reworked on the T-231 kit

**What.** `slender.gd`, `slender_decoy.gd`, `slender_encounter.gd`, `watch_meter.gd`, `bosses/map02.json` (the_slender).
*Model:* the greatcoat moves (the kit's `strips` along the hem at the front, the back and both sides, and the scarf's
two ends; the decoys' hems sway the same way); the lantern now hangs off its pole and swings (a spring pendulum in
`_process` driven by the hand's velocity, settling to plumb; the hitbox, the glass and the lamp ride the swing) and its
violet light pools on the grating under it (a radial additive decal that follows the lantern and scales with the lamp's
energy, since the omni light casts no shadows and the Compatibility renderer never shows a pool otherwise); the brass
(buttons, the lantern's cage, the badge band, the key ring) is `mat_ex` metal at roughness 0.3 so it catches the lantern;
the eyes are the kit's `EyeGlow`, violet: they never blink while he watches his target (facing within 45 deg with line of
sight) and blink slowly (6 s) otherwise, and they go out when he sits down dead. The face is the MZ body's own under the
cap: nothing was added to it (never faceless). *Effects:* the "dread" block (radius 24, near 6: he is felt from far;
surface cloth: dust on hits; step_sound "" and step_shake 0: a quiet step, he is a tall man, not a machine); the kit
is re-pointed at his own block in `_ready` (the base makes it from the Cousins' table, so both Totenhafen bosses
re-copy `fx.cfg` from their own data); `fx.tele` on every telegraph (the sweep's 1.0 s rise, the Lash's 0.6 + 0.4 s
silence, the Mirroring step's 0.8 s silence) and `_tele_glow` returns the light's own energy while a tell runs so the
base's steady level stays out of the kit's shape; `slender_lantern_hum` as a 3D loop on the lantern (off while it is
broken, back when it relights, off when he blows it out); `slender_keys_still` as the tell of every silence (the Lash
and the step); `slender_whisper` close behind the local player by Watch tier (every 9 s at MEDIUM, 5.5 s at HIGH, 3 s at
CRITICAL) and from LOW every 8 s for a hurt player (under half HP); `boss_breath` when he stands still over somebody
(2.6 m) and when he appears behind them at CRITICAL; the Watch tiers push the dread layer (`fx.extra_dread` 0.15 /
0.35 / 0.6 / 0.95 by tier, +0.25 in every silence; HIGH and CRITICAL punch it once), so the screen's edge goes violet
as the meter rises and is near full at CRITICAL; the lantern's break bursts motes and chips, the relight motes, the
book's drop ash (pages), a bullet through smoke a violet puff; End of Shift goes through the kit: `fx.lights_dim` over
220 m to 0 with `lights_flicker` for 1.3 s so the lamps gutter as they die, and the three fuse boxes spark
(`BossFx.burst("sparks")`) every ~3 s while the dark lasts; `fx.lights_restore` when the 30 s are up, and at once if he
dies or walks off in the dark (the old per-light energy list is gone). *Battle:* the **Mirroring step**: in sight,
6-30 m, while you move, the keys go still for 0.8 s and the telegraph light rises, then he stands where you stood one
second ago (a 2.5 s trail of the target's positions, one sample a physics frame, reset when the target changes; never
within 1.5 m of you: a step back along your own path instead), facing you, and holds still 0.6 s (a clean shot);
cooldown 14 s; `SLN_MIRROR_STEP_01` once ("You walked that way. I know. I was just behind you."). The **squad rule**:
`WatchMeter.rate` multiplies every fill source x1.5 (`alone_dark_mult`) when the player is alone (nobody within 6 m,
the new sense "alone") and in the dark; the drains are untouched; and the hurt player's whisper above. The **escalation**:
`phases` in the data, read by `Slender._mvf` / `phase_value` (per-phase overrides of a move's numbers): the Lantern
Sweep's cooldown 12 -> 9 (Shift Change) -> 7 s (End of Shift), the Mirroring step's 14 -> 10 -> 7 s, the Key Ring Lash's
reach 4 -> 4 -> 5 m, his walk 1.6 -> 1.6 -> 1.9 m/s (a walk still: he never runs). Every existing move, the Watch
system, the break-frees, the decoys, End of Shift's fuse boxes and the fail-safe are unchanged in their numbers.

**Why.** The lead's direction (BOSS_REWORK 4.1): the coat, the lantern, the pooled light, the eyes, the keys' tell with
its own sound, the Watch tiers made visible, End of Shift as the only light, a Mirroring move that stands him where you
were. The step is the scariest thing a patient man can do: not an attack, a demonstration that he was behind you the
whole time, and it is fair because the silence tells you first and the hold pays you back. The lone-in-the-dark rule
reads the squad: a watchman notices the one who wandered off. The escalation is small on purpose: a night watchman
whose last round is a little quicker, never a sprint.

**Numbers changed (old -> new).** The Mirroring step is new: silence 0.8 s, delay 1.0 s, hold 0.6 s, min range 6 m,
cooldown 14 / 10 / 7 s by phase. Sweep cooldown 12 -> 12 / 9 / 7 by phase. Lash range 4 -> 4 / 4 / 5 by phase. Walk 1.6
-> 1.6 / 1.6 / 1.9 by phase. Watch fill x1.0 -> x1.5 for a lone player in the dark. End of Shift's lamps died in one
frame -> die over 1.4 s and come back over 2.5 s. Nothing else: HP, the Watch rates, the Lash's 85, the lantern's 3% /
6 s, the book's 2% / 4 s / 30 s, the pools, the doors, the fail-safe's 480 s and the rewards are as T-160 left them.

## T-233b, DER KIELHOLER, the drowned captain (Totenhafen), reworked on the T-231 kit

**What.** `kielholer.gd`, `bosses/map02.json` (der_kielholer); `kielholer_controller.gd` unchanged (its glow node is
reused). *Model:* the brass (the helmet, the corselet, the boots' soles) is wet metal (`mat_ex` roughness 0.28, metal
0.9) with a verdigris bloom (flattened green patches round the rim, the ports and the corselet); the helmet glass is a
translucent port (alpha 0.42, roughness 0.05) with the violet Marke glow dim behind it from the start (the controller's
glow node at scale 0.8, its light 0.35) and an inner shell that fogs from inside (alpha 0 -> 0.8 with the damage taken
toward `helmet_break_fraction`); when the glass breaks the glass and the fog go together with chips and motes and the
glow comes up full (scale 1.3, light 0.9, the x2.0 as before); the anchor chain is a real link chain (`chain`, 10 links)
from the left shoulder across the chest with the stock behind, and a second chain (14 links) drags from the left hip to
the deck under a pivot that yaws against his velocity and lifts with his speed; weed strips off both shoulders and the
helmet's back and rope strips at the belt (`strips`); the kit's wet sheen on the suit. He is named `DerKielholer` in the
tree so the capture cameras and the console find him. *Effects:* the "dread" block (radius 20, near 5, iron: sparks on
hits, `boss_stomp` footfalls with a 0.4 view shake within 14 m); `drips` emitters on the head, chest and hips for
`drip_seconds` (10) after every surfacing, off when he sinks; `kielholer_chain_drag` as a 3D loop that rises from -30 to
-6 dB with his walk and falls silent when he stands or is under; `kielholer_water_rise` on every surfacing and, low and
slow (pitch 0.7, -9 dB), as the ripple's own sound; a wake ring (a torus that spreads x4 and fades over 1.6 s) and spray
where he comes up; `kielholer_helmet_knock` on every glass or head hit before the break (`_on_damaged`, super kept);
`fx.tele` on the sweep (1.2 s), the charge (1.0 s, the lamp's warm colour) and the swipe (0.5 s); the dock lamps within
16 m dip to 30% as he sinks (`fx.lights_dim`) and come back once he is under (`lights_restore`); the chain sweep sparks
where it meets the concrete; `boss_breath` under the hull groan (the man inside, through the valve); the Marke's glow
goes out over 6 s when he dies. *Battle:* at **high and spring tide** he is under for `submerge_seconds` x 0.6 (3.6-6 s
instead of 6-10) and the ripple lasts x 0.75 (1.2 s instead of 1.6, never under 1.0 s) on top of the existing x1.3
speed and the nearest dock, so the tide is felt as "he is on you again before you have turned round". The **dunk** (the
lead's suggested beat): a held player who has been at the water's edge for 1.2 s (`dunk_after`) is pushed under for
1.0 s (`dunk_seconds`): 20 damage once (`dunk_damage`), the wading status for the second, the dread layer full and a
punch for the local player, spray and a muffled splash, and he leans over them; every break-free (the mash, teammates'
damage, the weak points) keeps running through it and `max_hold` stays 5 s, so every grab still breaks in solo; 1.2 +
1.0 < 5. The **squad rule**: he hunts the lone wader: a player within 3 m of a water edge with no teammate within 6 m,
in sight and inside 18 m, is his target over the nearest player (`lone_wader`, a pure rule).

**Why.** The lead's direction (BOSS_REWORK 4.1): water on him, the chain's sound, the fogging glass, the lamps' dip, the
ripple's sound, the faster tide. The dunk is consequence without cheapness: it only happens where the design already
said the grab is strongest (the edge), it is telegraphed by the pull itself, and it can never hold anyone past the 5 s
every grab already had. The lone-wader rule makes the squad's shape matter on the piers (the design's "stay off the
edges" now has teeth) and gives bots a reason to hold the aprons.

**Numbers changed (old -> new).** Under water at high / spring tide 6-10 s -> 3.6-6 s; the ripple at high / spring
1.6 -> 1.2 s; low and half tide unchanged. The dunk is new: after 1.2 s at the edge, 1.0 s, 20 damage once. The grab's
hold, pull, dps and break-frees unchanged (5 s, 1.8 m/s, 12 / 28 dps, 4 melee / 300 team / 400 weak). Nothing else: HP
28000, the sweep, the charge, the swipe, the helmet's 15%, the fail-safe's 420 s, the drops.

## Verification (headless on the owner's PC; the renders under WSL)

- `check_scripts`: (filled in below after the run)
- `smoke_slender` alone: (filled in below)
- `smoke_kielholer` alone: (filled in below)
- GUT: `test_map02*`, `test_slender`, `test_kielholer`, `test_boss_fx`, `test_boss_rework_w3` (new, 7 tests), and the
  suites that name the bosses (`test_bot_u10_eggs`, `test_bot_brain`, `test_citations`): (filled in below)
- Renders: `u14_slender` and `u14_kielholer` (data/gravelight/capture_cams.json), `morning/screenshots/<set>/w3/`:
  (filled in below)

## Open issues

- The lantern's omni light has no shadows (as before), so the "pool on the grating" is the decal, not a lit pool; with
  the Forward+ renderer on the owner's PC a shadowed lamp would read better still (a quality toggle for the lead).
- `summon_boss("the_slender")` returns the encounter and only reserves a round while the rounds are stopped, so the kit's
  `boss:the_slender` capture op cannot pose him; `SlenderEncounter.capture_spawn` (callv) does it instead. The lead may
  want the op to call it.
- Both Totenhafen bosses re-copy `fx.cfg` from their own data block in `_ready` because `HomageBoss._ready` builds the
  kit from the Cousins' table (`cfg()`); a base hook that reads the subclass's table would remove the two copies.
- The End of Shift dim captures every lamp within 220 m including a player's flashlight (as the old code did), the Watch
  Room's lamp and the decoys' lanterns (the decoys set their energy each frame, so they stay lit, which the design wants).
- The dunk reads the held player's HP through `hit_player` (god mode and the bots' scaling apply as everywhere); a
  camera dip for the second would need the Player (not this worker's file).

## Sound ids wanted from the lead

- `slender_fuse_spark`: a fuse box's spark crackle (the bursts are silent now).
- `slender_step_arrive`: the one soft sound of him being behind you after the Mirroring step (a breath of air, a coat
  settling); `keys_jingle` at -8 dB stands in.
- `kielholer_ripple`: the ripple's own slow rise (a pitched-down `kielholer_water_rise` stands in).
- `kielholer_dunk`: the held player's head going under (a muffled splash; `water_splash` at pitch 0.7 stands in) and a
  one-second underwater bed for the dunk.
- VO to bake: `SLN_MIRROR_STEP_01` ("You walked that way. I know. I was just behind you.", speaker SLN; the subtitle
  shows silently until then).
