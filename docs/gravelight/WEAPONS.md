# GRAVELIGHT — Weapons

All numbers here are first-pass tuning. They will live in `/data/weapons/*.tres` (one `WeaponData` resource per weapon, plus one per upgraded variant). Code reads from data and never hardcodes them. If this doc and the data files disagree, the data files win, and this doc gets updated at the end of the milestone. Names and IDs follow `docs/CANON.md`.

---

## 1. Balance targets

Zombie health per round (canon): `r ≤ 9: 150 + 100·(r−1)`; `r ≥ 10: floor(950 · 1.1^(r−9))`. Player movement for reference: walk 4.5 m/s, sprint 6.8 m/s (weapon `move_mult` scales both).

| Round | 1 | 5 | 9 | 10 | 15 | 20 | 25 | 30 | 40 | 50 |
|---|---|---|---|---|---|---|---|---|---|---|
| Gänger HP | 150 | 550 | 950 | 1045 | 1682 | 2710 | 4365 | 7030 | 18234 | 47295 |

Design intent:
- **Rounds 1–5:** starting pistol + knife is enough. Knife = 1-hit kill at round 1, 2 hits at round 2.
- **Rounds 6–12:** wall-buys carry. A wall rifle headshot still kills in 1–2 shots at round 10.
- **Rounds 13–25:** you want a Crate weapon or a Crucible upgrade. Unupgraded SMGs need 25–50 body shots at round 20, which is uncomfortable on purpose.
- **Rounds 25+:** upgraded weapons + wonder weapons + traps. Wonder weapons fall off around round 35–40, then you lean on traps, explosives, and training.
- Upgraded weapons deal **~2.2–2.6× base damage** (×4 for bolt-actions), with bigger mags and one bonus property.

---

## 2. Default limb multipliers

Applied to every weapon unless a weapon overrides them.

| Hitbox | Multiplier | Notes |
|---|---|---|
| Head | 4.0 | Headshot kill = +100 Scrip |
| Neck | 2.0 | Neck kill = +60 Scrip |
| Torso | 1.0 | Body kill = +50 Scrip |
| Arms | 0.9 | Can sever an arm (cosmetic, slower swipe) |
| Legs | 0.9 | Accumulated leg damage ≥ 40% of max HP → **crawler** (once per zombie, 35% chance per qualifying hit) |

Non-lethal hit = +10 Scrip. Overrides: snipers use head 5.0. Shotguns use head 1.5 / neck 1.25 (pellets spread). The PTRS-41 uses head 2.0 (it's already enormous). Explosives, fire, and wonder weapons ignore hitboxes (×1.0 everywhere).

**Glasshides:** a torso hit deals ×0.5 (armor), unless the weapon has `armor_piercing` or the damage is explosive/wonder.

---

## 3. Base weapons: core stats

Legend: **Dmg** = per bullet/pellet. **Rel** = reload partial / empty (s). **ADS** = time to aim (s). **Sway** = 0 (rock steady) to 1 (drunk). **Pen** = extra targets a bullet passes through. **Move** = movement speed multiplier while held.

| ID | Weapon | Class | Source / price | Dmg | RPM | Mode | Mag | Reserve | Rel (p/e) | ADS | Sway | Pen | Move |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `m1911` | M1911 | Pistol | Start | 40 | 450 | Semi | 8 | 80 | 1.4 / 1.8 | 0.15 | 0.20 | 0 | 1.00 |
| `kar98k` | Kar98k | Bolt rifle | Wall 200 | 100 | 50 | Bolt | 5 | 50 | 0.6/rnd · 2.6 clip | 0.30 | 0.35 | 1 | 0.95 |
| `m1_garand` | M1 Garand | Semi rifle | Wall 600 | 105 | 350 | Semi | 8 | 96 | — / 2.2 (en bloc) | 0.28 | 0.30 | 1 | 0.95 |
| `gewehr43` | Gewehr 43 | Semi rifle | Wall 900 | 115 | 320 | Semi | 10 | 120 | 2.4 / 3.0 | 0.30 | 0.30 | 1 | 0.95 |
| `m1_carbine` | M1 Carbine | Carbine | Wall 600 | 70 | 450 | Semi | 15 | 150 | 1.9 / 2.4 | 0.22 | 0.22 | 0 | 0.98 |
| `mp40` | MP40 | SMG | Wall 1000 | 50 | 500 | Auto | 32 | 192 | 2.0 / 2.6 | 0.20 | 0.25 | 0 | 1.00 |
| `thompson` | Thompson M1A1 | SMG | Wall 1200 | 55 | 700 | Auto | 30 | 210 | 2.2 / 2.9 | 0.22 | 0.30 | 0 | 0.98 |
| `stg44` | STG-44 | Assault rifle | Wall 1200 | 65 | 550 | Auto | 30 | 210 | 2.3 / 2.9 | 0.25 | 0.28 | 1 | 0.96 |
| `trench_gun` | Trench Gun (M1897) | Shotgun | Wall 1500 | 40 ×8 | 60 | Pump | 6 | 54 | 0.5/shell | 0.25 | 0.25 | 0 | 0.96 |
| `bar` | BAR | LMG | Wall 1800 | 100 | 500 | Auto | 20 | 180 | 2.6 / 3.2 | 0.35 | 0.40 | 1 | 0.92 |
| `ppsh41` | PPSh-41 | SMG | Crate | 45 | 1000 | Auto | 71 | 284 | 3.0 / 3.6 | 0.24 | 0.35 | 0 | 0.97 |
| `mg42` | MG42 | LMG | Crate | 90 | 1200 | Auto | 125 | 500 | 5.5 / 6.5 | 0.45 | 0.55 | 1 | 0.88 |
| `m1919` | Browning M1919 | LMG | Crate | 110 | 500 | Auto | 125 | 500 | 5.8 / 6.8 | 0.45 | 0.50 | 1 | 0.88 |
| `sawed_off` | Double-Barrel Sawed-Off | Shotgun | Crate | 60 ×10 | 400 | Semi (2) | 2 | 60 | — / 2.4 | 0.20 | 0.30 | 0 | 1.00 |
| `type100` | Type 100 | SMG | Crate | 55 | 800 | Auto | 30 | 240 | 2.1 / 2.7 | 0.20 | 0.25 | 0 | 1.00 |
| `ptrs41` | PTRS-41 | Anti-tank rifle | Crate | 1000 | 120 | Semi | 5 | 50 | — / 4.2 | 0.55 | 0.60 | 5 | 0.85 |
| `springfield` | Springfield M1903 (scoped) | Sniper | Crate | 200 | 45 | Bolt | 5 | 60 | 0.7/rnd · 3.0 | 0.40 | 0.45 | 2 | 0.93 |
| `panzerschreck` | Panzerschreck | Launcher | Crate | 1000 splash | 30 | Single | 1 | 10 | — / 3.5 | 0.50 | 0.45 | — | 0.88 |
| `flamethrower` | M2 Flamethrower | Special | Crate | 40/tick (20 tick/s) | — | Stream | 160 fuel | 480 | — / 3.8 | — | — | ∞ (cone) | 0.90 |
| `gramophone` | Siren Gramophone | Tactical | Crate | 1500 blast | — | Throw | 1 | 2 (3 max) | — | — | — | — | 1.00 |
| `ashlight` | Ashlight | Wonder | Crate (low weight) | 900 + 600 splash | 180 | Semi | 20 | 160 | 2.0 / 2.5 | 0.20 | 0.15 | 0 | 1.00 |
| `totenglocke` | Totenglocke | Wonder | Map 1 build | toll: kill / 35% max HP (cone) | crank | Tap / wind | 12 charges | 48 | 2.4 / 3.0 (the crank) | — | 0.20 | ∞ (cone) | 0.94 |

Melee and equipment are in §6.

---

## 4. Range falloff and limb overrides

Falloff: full damage up to **Start**, linear down to **Min ×** at **End**, then flat. Hitbox columns are blank where the defaults in §2 apply.

| ID | Start m | End m | Min × | Head | Neck | Torso | Arms | Legs | Notes |
|---|---|---|---|---|---|---|---|---|---|
| `m1911` | 10 | 30 | 0.60 | | | | | | |
| `kar98k` | 60 | 150 | 0.85 | | | | | | |
| `m1_garand` | 45 | 120 | 0.80 | | | | | | |
| `gewehr43` | 45 | 120 | 0.80 | | | | | | |
| `m1_carbine` | 30 | 80 | 0.70 | | | | | | |
| `mp40` | 12 | 35 | 0.55 | | | | | | |
| `thompson` | 12 | 35 | 0.55 | | | | | | |
| `stg44` | 25 | 60 | 0.65 | | | | | | |
| `trench_gun` | 6 | 18 | 0.20 | 1.5 | 1.25 | | | | 8 pellets, 6° spread hip / 4° ADS |
| `bar` | 35 | 80 | 0.70 | | | | | | |
| `ppsh41` | 10 | 30 | 0.50 | | | | | | |
| `mg42` | 30 | 70 | 0.70 | | | | | | |
| `m1919` | 30 | 70 | 0.70 | | | | | | Overheats after 8 s of firing; cools in 3 s |
| `sawed_off` | 4 | 12 | 0.15 | 1.5 | 1.25 | | | | 10 pellets, 9° spread |
| `type100` | 12 | 35 | 0.55 | | | | | 1.0 | |
| `ptrs41` | 100 | 200 | 0.90 | 2.0 | 1.5 | | | | Kicks the player back slightly |
| `springfield` | 100 | 200 | 0.90 | 5.0 | 2.5 | | | | Scope 4×, hold breath to cut sway 80% for 4 s |
| `panzerschreck` | — | — | — | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | 5 m radius, falloff to 25% at edge; self-damage 75 (none with Blastproof Bock) |
| `flamethrower` | 7 | 7 | — | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | 7 m reach, 15° cone, ignites for 25 dmg/s for 3 s |
| `ashlight` | — | — | — | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | See §7 |
| `totenglocke` | — | — | — | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | See §8 |

---

## 4.1 Handling: sprint-out, ADS, recoil and bloom (Update 02 §1, T-046)

- **Sprint-out** (time from leaving a sprint until the gun fires; the sprint-out pose plays meanwhile), `data/gravelight/movement.json` `sprint_out`: pistol 0.15 s, SMG 0.2, rifle / bolt / assault / shotgun 0.3, sniper 0.35, LMG 0.45, flamethrower 0.45, launcher 0.5; wonder weapons: Ashlight 0.2, Elmsfeuer 0.25, Totenglocke 0.35. Fire or ADS input cancels a sprint at once and a fire press is buffered until the sprint-out ends, so it is never lost.
- **Reload on the run** (T-083, `movement.json` `sprint_reload`): **SMGs and pistols** (machine pistols, revolvers, the Webley's break) start and keep a reload while sprinting; the viewmodel keeps about a third of the sprint pose (`feel` `sprint_reload_pose`, 0.35) under the reload so nothing snaps, and the sprint-out above still gates the first shot. Every other class has its reload interrupted by a sprint (a reload asked for while sprinting waits for the sprint to end) unless the gun wears the **Paratrooper Sling** from the Armorer's Bench (§26: grip slot `quick_sling`, `props.sprint_reload`; 1000 Scrip, LMGs 1250). Per-weapon overrides go in `sprint_reload.weapons`. `WeaponHolder.sprint_reload_allowed(w)`.
- **ADS time** (`ads_time`, per weapon): SMG 0.18 s, rifles 0.25, LMG 0.4 (pistol 0.15, shotguns 0.2–0.25, snipers 0.4–0.55, launcher 0.5 unchanged). **ADS-walk** is 60% of the walk speed (`movement.json ads_move_mult`; a weapon row may set its own `ads_move_mult`).
- **Recoil pattern** (`weapons.json` `recoil`: classes, then per weapon, then a row's own `recoil`): each shot moves the aim up `v × min(v_max_mult, 1 + v_growth × shot index)` degrees (the same climb every burst) and sideways along a per-weapon swing `h_swing × sin(i × h_freq + phase)` plus a small random `±h`. After `recover_delay` without a shot, `1 − keep` of the burst drifts back at `recover` (1/s). The camera punch (feel `cam_*` × `punch`) springs fully back and the viewmodel kick (`vm_*`) is separate again. ADS × `ads_recoil`, crouched × `crouch_mult`.
- **Hip bloom**: + `bloom` degrees a shot (pellet guns 35%), up to `bloom_max`; it holds while you fire, then shrinks at `bloom_still` deg/s standing still, `bloom_move` on the move, ×1.4 crouched. Walking adds up to `walk_spread_deg` (2.2°) at walk speed; crouched hip spread ×0.8. The crosshair ticks sit on the real cone edge.
- **Slides**: hip fire is allowed from 50% through a slide (`slide_fire_from`); an earlier press is buffered. No firing while mantling.
- **Last round**: firing the last round of a magazine plays `last_round_click`.

## 5. Upgraded variants (The Crucible)

Every upgraded weapon gets: the **Nachtglas camo** (violet veins with amber cracks), an extra firing-sound layer (a low glassy hum under the shot), a new display name, and **one bonus property**. Upgrading refills all ammo.

| Base ID | Upgraded ID | Name | Dmg | RPM | Mag | Reserve | Rel (p/e) | Pen | Bonus property (data key) |
|---|---|---|---|---|---|---|---|---|---|
| `m1911` | `m1911_up` | **Last Rites** | 120 | 450 | 12 | 120 | 1.2 / 1.6 | 0 | `ricochet: 1`: each round bounces once toward the nearest zombie within 8 m at 50% damage |
| `kar98k` | `kar98k_up` | **Final Verdict** | 400 | 60 | 8 | 80 | 0.5/rnd · 2.2 | 4 | `penetration: 4`: passes through 4 targets with no damage loss |
| `m1_garand` | `m1_garand_up` | **Eight-Ping Benediction** | 260 | 380 | 12 | 144 | — / 2.0 | 2 | `underbarrel: rifle_grenade`: 6 rifle grenades (300 dmg, 3.5 m radius), toggled with the alt-fire key |
| `gewehr43` | `gewehr43_up` | **Stille Nacht** | 280 | 340 | 16 | 160 | 2.2 / 2.7 | 2 | `head_mult: 8.0` (2× default) + `quiet_kills`: headshot kills don't pull nearby zombies' aggro |
| `m1_carbine` | `m1_carbine_up` | **Reveille** | 150 | 750 | 30 | 300 | 1.7 / 2.2 | 1 | `fire_modes: [semi, auto]`: a full-auto selector |
| `mp40` | `mp40_up` | **Grabesgesang** | 120 | 550 | 40 | 280 | 1.5 / 1.9 | 0 | `reload_mult: 0.75`: faster reload (stacks with Trigger Tonic) |
| `thompson` | `thompson_up` | **Chicago Lament** | 120 | 720 | 50 | 350 | 2.4 / 3.0 | 2 | `armor_piercing`: ignores Glasshide armor and Foreman plate |
| `stg44` | `stg44_up` | **Sturmwind** | 140 | 600 | 40 | 320 | 2.1 / 2.6 | 2 | `fire_modes: [auto, burst3]`: 3-round burst at 900 RPM with tighter spread |
| `trench_gun` | `trench_gun_up` | **Gravedigger's Due** | 90 ×8 | 70 | 10 | 80 | 0.4/shell | 1 | `incendiary`: pellets ignite for 60 dmg/s for 3 s |
| `bar` | `bar_up` | **Ironmonger** | 210 | 520 | 30 | 300 | 2.4 / 3.0 | 2 | `stagger: 0.35`: each hit has a 35% chance to stagger (interrupts attacks) |
| `ppsh41` | `ppsh41_up` | **Red Winter** | 100 | 1000 | 115 | 460 | 2.8 / 3.4 | 0 | `frost: {slow: 0.3, dur: 2.0}`: hits slow the target 30% for 2 s (doesn't stack) |
| `mg42` | `mg42_up` | **Bone Saw** | 180 | 1200 | 200 | 800 | 5.0 / 6.0 | 2 | `mag_bonus`: a bigger belt plus a 15% chance per hit to sever a limb |
| `m1919` | `m1919_up` | **The Long Amen** | 200 | 550 | 250 | 750 | 5.2 / 6.2 | 3 | `no_overheat` + `penetration: 3` |
| `sawed_off` | `sawed_off_up` | **Twin Coffins** | 140 ×10 | 400 | 4 | 80 | — / 2.2 | 1 | `volley: 4`: four barrels; alt-fire dumps all four at once |
| `type100` | `type100_up` | **Hollow Blossom** | 130 | 850 | 40 | 320 | 1.8 / 2.3 | 0 | `hollow_point`: limb mult ×1.5 and crawler chance 35% → 70% |
| `ptrs41` | `ptrs41_up` | **Bear Tax** | 2000 | 130 | 8 | 80 | — / 3.6 | ∞ | `armor_ignore` + unlimited penetration |
| `springfield` | `springfield_up` | **Long Goodbye** | 600 | 50 | 8 | 96 | 0.6/rnd · 2.6 | 3 | `headshot_pop: {dmg: 300, r: 2.0}`: headshot kills burst in a Nachtglas pop |
| `panzerschreck` | `panzerschreck_up` | **Stovepipe Sermon** | 1500 splash | 30 | 2 | 20 | — / 3.2 | — | `cluster: {count: 6, dmg: 400, r: 2.5}`: bomblets scatter on impact |
| `flamethrower` | `flamethrower_up` | **Furnace Warrant** | 80/tick | — | 240 fuel | 720 | — / 3.4 | ∞ | `reach: 10` + `burning_ground: {dps: 150, dur: 4}` |
| `ashlight` | `ashlight_up` | **Ashlight Corona** | 1400 + 900 splash | 200 | 40 | 200 | 1.8 / 2.2 | 0 | `chain: 3`: each bolt arcs to 3 more targets within 6 m at 70% damage |
| `totenglocke` | `totenglocke_up` | **Totenglocke: Mitternacht** | toll (cone) | crank | 16 charges | 64 | 2.0 / 2.6 | ∞ | cones +30%, Great Toll costs 2, shatters chain-ring to 3, 12 s pulling Bell Dome, midnight chime (§8) |

Not upgradable: Trench Knife, Sharpened E-Tool, Mk 2 Frag, Siren Gramophone. Holding one of these up to the Crucible shows: "The Crucible has nothing to teach this."

---

## 6. Melee and equipment

### Trench Knife (`trench_knife`), always equipped
| Stat | Value |
|---|---|
| Damage | 150 (one-hit kill at round 1, two at round 2) |
| Swing time | 0.55 s (0.45 s with Dutch's trait for animation feel; the trait itself is +10% damage) |
| Lunge | When aiming at a zombie within 3.5 m, the player lunges up to 2.5 m. Cooldown is shared with the swing. |
| Hit arc | 70° in front, 2 m reach |
| Melee kill | +130 Scrip |

### Sharpened E-Tool (`etool`), wall 3000
Replaces the knife permanently for that player.
| Stat | Value |
|---|---|
| Damage | 1000 (kills through round 9; still a 2-hitter at round 11) |
| Swing time | 0.60 s, with a wide 100° arc that can hit 2 targets |
| Lunge | 3.0 m |

### Mk 2 Frag (`frag`)
| Stat | Value |
|---|---|
| Damage | 1200 at center, falling off to 20% at the edge |
| Radius | 6 m kill / 9 m stagger |
| Fuse | 4.0 s. Cooking is supported, and the fuse starts when the pin is pulled. Peg's trait shows the remaining cook time on the HUD. |
| Capacity | 4 (5 with Peg's trait). Start with 2. You get +2 at the start of each round, up to the cap. |
| Refill | Wall 250, refills to the cap |
| Self-damage | 100 within 3 m, 50 within 6 m. None with Blastproof Bock. |

### Siren Gramophone (`gramophone`), Crate-only tactical
| Stat | Value |
|---|---|
| Behavior | Thrown like a grenade, it lands upright, and a scratchy record plays "Come Along, Little Soldier." |
| Lure | Every zombie within 25 m (and anything pathing within 40 m) retargets to it for **8 s**. Bosses ignore it. |
| Detonation | At 8 s: 1500 damage, 7 m radius, no falloff in the inner 3 m |
| Capacity | 2 per pickup, 3 max. Refills +1 at the start of each round. |
| Slot | Replaces frags in the tactical slot while held. Frags come back when gramophones run out. |
| Flavor | *"Reinholt's orderlies wound it, set it in the yard, and stepped back. The subjects always came."* |

---

## 7. Ashlight (`ashlight`)

A brass-and-glass pistol with a Nachtglas capsule in the grip. Fasbender's "resonance projector" prototype.

| Stat | Value |
|---|---|
| Projectile | A visible bolt at 45 m/s. Gravity 0. |
| Direct damage | 900 to the target hit |
| Splash | 600 within 2.5 m, falling off to 30% |
| Ricochet | The bolt bounces **once** off world geometry (not zombies). Splash triggers on each impact, so one shot can deliver 2 splashes. |
| Self-damage | 40 per splash if the player is within 2.5 m. That's 80 if the ricochet comes back. None with Blastproof Bock. |
| Kills to | 1-shot through round ~12, 2 shots to round ~20, about 5 at round 30 |
| Crate weight | 3 (lowest). Bad-luck protection in §10. |
| Flavor | *"Fasbender called it a resonance projector. The men called it the Ashlight, after what was left."* |
| Upgrade flavor (Ashlight Corona) | *"Now it doesn't stop at one."* |

---

## 7.1 Sankt-Elmsfeuer (`elmsfeuer`), the third wonder weapon (T-037)

A ship's arc projector rebuilt as a carbine by U-1047's electrician: a copper induction coil in a glass sleeve over a brass bore, a navy-grey magneto breech with a hand crank, a wooden stock, porcelain insulators for sights, and a violet discharge gap at the muzzle. Crate-only, every map.

| Stat | Value |
|---|---|
| Projectile | A crackling bolt at 70 m/s, gravity 0; one ricochet off world geometry |
| Direct damage | 1100 to the target hit |
| Chain | Arcs to **3** more zombies within 6 m of the first hit, at 70% damage (`chain` property, the Ashlight Corona rule) |
| Splash | 350 within 2 m, falling off to 40% |
| Self-damage | 30 per splash within 2 m |
| Mag / reserve / RPM | 8 / 48 / 100, semi |
| Crate weight | 3 (tier A), shares the wonder bad-luck protection with the Ashlight |
| Upgrade: **Kugelblitz** (`elmsfeuer_up`) | 1600 direct, chain **6**, splash 600 / 2.6 m, two ricochets, 12 / 72, and every arc frosts (35% slow for 2 s) |
| Flavor | *"The pens' arc lamp, rewired by a boat's electrician who had stopped sleeping. It jumps from one of them to the next, the way the stories said the saint's fire jumped from mast to mast."* |
| Upgrade flavor | *"Ball lightning. It goes where it likes, and it likes company."* |

---

## 8. Totenglocke (`totenglocke`), Map 1 buildable

A handheld bell-cannon: a bronze bell bolted into a firing frame, with a hand crank.

### Build parts (Map 1)
| Part | ID | Location | How |
|---|---|---|---|
| Small bronze bell | `tg_part_bell` | Rail Yard (`B_RAILYARD`), one of 3 random spots (boxcar, signal box, locomotive cab) | Pick up |
| Firing frame | `tg_part_frame` | Barracks (`D_BARRACKS`), one of 3 (top bunk, quartermaster's cage, under the mess-hall stage) | Pick up |
| Crank assembly | `tg_part_crank` | Salt Chapel (`F_CHAPEL`), one of 3 (bell tower base, sacristy, confessional) | Pick up |
| Workbench | `tg_workbench` | Generator Hall (`G_GENERATOR`) | Hold [F] 3 s with all parts (Deacon builds 15% faster). Then anyone can pick it up for free; one per player. |

Parts are shared in co-op and shown on the HUD (a small parts strip under the Scrip counter).

### Diagnosis (Update 02, before the rebuild)

Why the M4 Totenglocke felt bad, measured against `RoundManager.zombie_health` (150 + 100/round to round 9,
then x1.1 per round: r15 = 1683, r16 = 1851, r20 = 2710, r21 = 2981, r25 = 4364, r30 = 7029 HP):

1. **The input ate taps.** Fire had to be *held* for 0.6 s before a release did anything; a tap or a short
   hold was silently discarded (no ring, no dry click, no sound until the 0.6 s ratchet). The crank's spin was
   also reset every frame by the viewmodel's part reset, so the wind-up showed nothing.
2. **The kill line was at 4 m.** 3000 damage only inside 4 m, falling to 60% (1800) at the 8 m edge: the edge of a
   train survived from round 16 (1851 > 1800), the whole cone from round 21. 8 m x 60 deg is barely past melee
   range for a gun you build in three zones.
3. **Survivors were barely touched.** The doc promised a 3 m knockback and "shatter" deaths; neither existed.
   Damage kind `wonder` is not in the knockdown list, so survivors only flinched (or staggered when the hit
   was over 40% of their HP). Kills played the ordinary death clips.
4. **Weak feedback.** One bell sample, an `Effects.explosion` puff 3 m ahead, a 2.0 viewmodel kick and a 3 deg
   recoil. No bell vibration, no screen effect, no rumble, nothing in the world reacted.
5. **Too few charges, long reloads.** 6 per mag, 3.0 s reload: a reload every six rings, 30 rings per refill.
6. **Mitternacht was the same gun with bigger numbers.** Its boss stagger (1.5 s) existed only in the data; the
   "double ring" was the same sample played twice. Bots fired the bell as a single-target 3000-damage hitscan.

### The rebuild: wind and toll (T-048, `gravelight/weapons/totenglocke.gd`)

| | Totenglocke | Mitternacht |
|---|---|---|
| **Tap** (released before the 1.5 s wind completes) | Quick toll: 8 m, 50 deg cone, no falloff; anything within 2.5 m is hit whatever the angle | 10.4 m, 65 deg |
| Tap damage | Kills outright any zombie with max HP <= 2750 (through round 20); above that 35% of max HP | same |
| **Hold** (wind 1.5 s: the crank speeds up, the bell hums rising in pitch) | Release for the **Great Toll**: 14 m, 70 deg, **shatters** every non-boss in the cone; costs 3 | 18.2 m, 91 deg; costs 2 |
| Hold with too few charges | The wind stops at "not enough" (a dull clunk); release is a quick toll | same |
| **Resonance mark** | A toll's survivors are *tolled* (a ringing bronze halo for 20 s); a second toll always shatters them | violet halo |
| Survivors | Knocked down / staggered (explosive-kind hit) | same |
| **Chain-ring** | — | Each shattered zombie rings the 3 nearest (5 m) with a quick toll |
| **Alt-fire: Bell Dome** | Plant a 6 m field for 8 s: zombies inside move at 40% speed and take +25% damage; crossing in staggers each zombie once. One at a time, 2 charges | 12 s, pulls zombies toward the bell (0.9 m/s) |
| Toll cooldown | 0.45 s (Great Toll 0.9 s) | same |
| Charges | 12 per mag, 48 reserve | 16 / 64 |
| Reload = **the crank** | 2.4 s partial / 3.0 s empty: the Crank part winds six turns with a ratchet | 2.0 / 2.6 |
| Bronze shards | Every 5th Totenglocke kill drops a shard: +1 charge to whoever holding a Totenglocke walks over it (25 s) | same |
| Bosses (Foreman, Screamer, the Cousins) | Never shattered or marked. Tap 3% / Great Toll 10% of max HP; stagger per `stagger_bosses` (0 / 1.5, unchanged) | same |
| Feel | Layered toll (sub body + bell partials + metallic shimmer + 3 s ring-out); Great Toll: bigger strike, screen ring distortion, dust/snow blown off every surface in the cone, a delayed echo off the nearest walls, a world shockwave ring, hitstop slow-mo (0.2x for 0.16 s, solo only) on 6+ shatters; the viewmodel bell vibrates after every toll; camera kick; controller rumble | Midnight chime layered on every toll, violet shockwave and dome |

Shatter = a lethal explosive-kind hit (ragdoll launch) plus the head and three limbs blown off with ZombieGore
(pieces only for the first five zombies of a toll, so the 12-piece cap never culls them mid-flight) and a burst
of bronze/frost shards. Ammo boxes (§4) refill it through `WeaponHolder.refill_weapon(&"totenglocke")`.

Numbers live in `data/gravelight/weapons.json` (`bell` block). Pure rules (outcome, cone, cost, shard rate) are
static in `Totenglocke` and covered by `gravelight/tests/unit/test_totenglocke.gd`.

| | |
|---|---|
| Audio | `totenglocke_toll`, `_great`, `_echo`, `_hum` (loop), `_wind`, `_midnight`, `_shatter`, `_shard`, `_dome`, `_dome_plant` (gen_audio.py `gen_wonders`) |
| Flavor | *"Ring it once for the living. They've had enough of that."* |
| Upgrade flavor | *"Midnight. Every bell in Silesia, all at once."* |

---

## 9. Wall-buys and ammo rules

| Weapon | Price | Ammo (half) | Upgraded ammo from wall | Map 0 | Map 1 zone |
|---|---|---|---|---|---|
| Kar98k | 200 | 100 | 4500 | Taproom | `A_MINEHEAD` |
| M1 Garand | 600 | 300 | 4500 | Taproom | — |
| M1 Carbine | 600 | 300 | 4500 | — | `A_MINEHEAD` |
| Gewehr 43 | 900 | 450 | 4500 | — | `C_ADMIN` |
| MP40 | 1000 | 500 | 4500 | Upstairs | `B_RAILYARD` |
| Thompson M1A1 | 1200 | 600 | 4500 | — | (reserved for Map 2) |
| STG-44 | 1200 | 600 | 4500 | — | `G_GENERATOR` |
| Trench Gun | 1500 | 750 | 4500 | Stable | `D_BARRACKS` |
| BAR | 1800 | 900 | 4500 | — | `F_CHAPEL` |
| Sharpened E-Tool | 3000 | — | — | — | `G_GENERATOR` tool rack by the workbench (see MAPS.md) |
| Frag refill | 250 | — | — | Taproom | `B_RAILYARD` |

Rules:
1. **Buying a weapon you don't own** takes your current weapon's slot when your slots are full. The weapon comes with full ammo.
2. **Ammo for a weapon you own** costs half its price and refills mag + reserve.
3. **Upgraded ammo from the wall** costs 4500 (the wall chalk outline glows violet when you hold that weapon's upgraded variant).
4. **Crate weapons** can't be refilled at walls. Use an **ammo box** (§9.1), Resupply drops, or buy a new one. The Crucible sells no ammo (T-083).
5. The prompt always tells you which case you're in: "Hold [F] for Ammo [500]" / "Hold [F] for Upgraded Ammo [4500]".

### 9.1 Ammo boxes (Update 02 §4, T-049; the taught gun's counter since T-083)

`gravelight/world/ammo_box.gd`, prices in `economy.json` `ammo_box`: hold Use to refill the gun in your hands (mag + reserve, a rifle's grenades) and your lethal grenades. **Normal 250, Crucible-taught 2500 (any tier), wonder 1000, taught wonder 4000**, grenades only 250; a 3 s per-player cooldown. Packmule II halves it, the Scrounger Field Habit discounts it. Since T-083 the boxes (and a gun's own wall chalk at 4500) are the only places a taught gun refills: the Crucible teaches and nothing else. Every map places boxes (Map 0: the taproom and the Grounds; Map 1: the Rail Yard; Map 2: the harbour), bots refill there (`BotEconomy._ammo_candidate`, upgraded guns at the upgraded price).

---

## 10. Lost Requisition Crate (Mystery Crate), 950

### Pool and weights
Tier A = feels great. Tier B = solid. Tier C = "dud" (classic disappointment, still usable).

| Weapon | Tier | Weight |
|---|---|---|
| PPSh-41 | A | 10 |
| MG42 | A | 10 |
| Browning M1919 | A | 8 |
| Panzerschreck | A | 6 |
| PTRS-41 | A | 6 |
| Ashlight | A (wonder) | 3 (+ bad-luck protection) |
| Double-Barrel Sawed-Off | B | 8 |
| Type 100 | B | 8 |
| Springfield M1903 | B | 6 |
| M2 Flamethrower | B | 5 |
| Siren Gramophone | B | 6 |
| Thompson M1A1 | B | 5 |
| STG-44 | B | 5 |
| Trench Gun | B | 5 |
| BAR | B | 5 |
| MP40 | C | 4 |
| M1 Carbine | C | 3 |
| M1 Garand | C | 3 |
| Gewehr 43 | C | 3 |
| Kar98k | C | 3 |

Total base weight: 112 (A 43, B 53, C 16). The Totenglocke is never in the Crate.

### Rules
1. **Exclusions:** you can't roll a weapon you already hold, base or upgraded (a held `mp40_up` excludes `mp40`). In co-op, the Ashlight is excluded while any player holds one (one per match on the map, classic scarcity).
2. **Gentle start (pity system):** each player's **first 3 pulls** of the match come from tiers A+B only.
3. **Dud breaker:** after **2 Tier C results in a row**, your next pull is guaranteed Tier A or B. After **5 pulls without Tier A**, your next pull is guaranteed Tier A.
4. **Wonder-weapon bad-luck protection:** the Ashlight's weight gets +1 for every 6 of your pulls without it (max weight 9). It resets when you get it.
5. **Cycling:** the crate shows weapon models cycling for 4.5 s (slowing down), then the result floats for 12 s. If it isn't taken, the crate closes and the weapon is gone (no refund).
6. **The drummer (Herr Tamtam):** when the crate arrives at a location, it rolls a hidden `uses_until_move` from **4–12** (uniform). The pull that reaches that count produces Herr Tamtam instead: he drums a cadence, the crate sinks, the player gets **950 back**, and the crate reappears at a random different location (a violet beam marks it for 20 s). Herr Tamtam never appears on a player's first pull of the match, and never during the first 2 pulls at a new location. During Easter egg step 7 he walks away instead (see GDD/Easter egg).
7. **Clearance power-up:** all crate locations open at 10 Scrip for 30 s. Pity and dud-breaker rules still apply. The drummer counter keeps counting, but the drummer is suppressed during Clearance.
8. **Start location:** random between 2 designated start spots per map (Map 0: Taproom or Stable; Map 1: Rail Yard boxcar or Barracks mess hall. See MAPS.md).
9. **(§11 amendment) Anomalous Inventory.** When the Anomalous Inventory setting is on, five Bolt & Sprocket items join the pool at very low weight, with their own Operator line. The pool, stats and rules are in §18. Helvetia Works uses its own crate table (§19.4).

---

## 11. The Crucible, 5000

| Rule | Value |
|---|---|
| Location | Core Vault (`I_CORE`), Map 1 |
| Cost | 5000 to upgrade (7500 / 10000 for the second and third teaching, §11.1). **It sells no ammo** (T-083): a taught weapon refills at an ammo box (§9.1, 2500) or its wall chalk (4500). |
| Process | Feed the weapon in (you're left holding nothing). The forge roars for **5 s**, then presents the weapon for **15 s**. If no one takes it, it's lost. |
| Stealing | In co-op, any player can take the presented weapon (classic behavior). The Operator comments. |
| Ammo | Every teaching hands the weapon back full (mag + reserve). |
| Not allowed | Melee, frags, Siren Gramophone. A taught weapon, full or not, is offered its next teaching (§11.1); at the top tier the prompt says it has learned all the Crucible can teach. |
| Lockout | One weapon in the forge at a time. A second player sees "The Crucible is occupied." |
| Death's Door / Double Scrip | Don't affect the price. |
| Flavor | *"The Crucible doesn't improve a weapon. It reminds it what it was for."* |
| **Plaque (§11 amendment)** | A brass plate riveted to the feed door reads **"MOD. R-E · PAT. PEND. BLZ-40417"**. Hold Interact at 1.5 m to read it (free, no power needed; Archive card `crucible_plaque`). Truth (players only): this is Crucible Mod. R-E (Re-Education), built by Darkmatter from Blartz's confiscated Omega Forge schematics. BLZ-40417 is Blartz's patent number and the PATENT PENDING gun's serial. **Upgraded weapons keep their Appendix A names.** |
| **Other locations (§11 amendment)** | Helvetia Works has a second Crucible Mod. R-E: a crated "next shipment" unit on **the Barge** (`HW_BARGE`), with identical rules, cost and plaque. The Barge also holds the **Original Omega Forge** (§17), the second upgrade tier. |

---

### 11.1 Second and third teaching ("double and triple Pack-a-Punch", T-037)

Any Crucible (Map 0 cellar, Map 1 Core, Map 2 U-1047) teaches a weapon up to **three times**. The first teaching is the §5 variant; the second and third are the same variant scaled (`weapons.json "crucible_tiers"`), with the name suffixed **II** / **III**, an amber then white-hot Nachtglas glow on the viewmodel, and the Operator's TWICE / THRICE lines at the forge. This is not the Omega Forge (§17), which stays Helvetia Works' single prototype with its own names and properties.

| Teaching | Cost (`economy.json`) | Damage | Mag / reserve | Reload | Name |
|---|---|---|---|---|---|
| I (the §5 variant) | 5000 `crucible_upgrade` | §5 | §5 | §5 | §5 name |
| II | 7500 `crucible_upgrade_tiers.2` | ×1.5 | ×1.25 (rounded up) | ×0.9 | *name* II |
| III | 10000 `crucible_upgrade_tiers.3` | ×2.0 | ×1.5 (rounded up) | ×0.8 | *name* III |

Rules: a taught weapon is offered the next teaching whatever its ammo (T-083: the Crucible's old 2500 refill is gone; the user kept being asked for ammo when they came to re-teach a gun, and the ammo boxes do that job); the tier rides with the kit through co-op mirroring and the campaign exfil (`WeaponHolder.to_net` entry 7); wall-buy and Crucible ammo prices don't change with the tier; bots re-teach when their Scrip covers the next price (`BotConfig.crucible_wanted`). Flavor: *"The second time it remembers. The third time it won't forget."*

## 12. Shots-to-kill sanity table (torso hits, no perks, no falloff)

Gänger HP: r1 = 150, r10 = 1045, r20 = 2710, r30 = 7030. Headshots (default ×4) cut every count to roughly a quarter. The Kar98k rows show this.

| Weapon | Dmg | r1 | r10 | r20 | r30 | Read |
|---|---|---|---|---|---|---|
| M1911 | 40 | 4 | 27 | 68 | 176 | Fine early, useless by round 8 |
| Last Rites | 120 (+ricochet) | 2 | 9 | 23 | 59 | Emergency sidearm |
| Kar98k | 100 | 2 | 11 | 28 | 71 | |
| Kar98k (head ×4) | 400 | 1 | 3 | 7 | 18 | Rewards aim through round 12 |
| Final Verdict (head ×4) | 1600 | 1 | 1 | 2 | 5 | Line them up: 4-target penetration |
| MP40 | 50 | 3 | 21 | 55 | 141 | |
| Grabesgesang | 120 | 2 | 9 | 23 | 59 | |
| Thompson | 55 | 3 | 19 | 50 | 128 | |
| Chicago Lament | 120 | 2 | 9 | 23 | 59 | Armor-piercing makes up for it |
| STG-44 | 65 | 3 | 17 | 42 | 109 | |
| Sturmwind | 140 | 2 | 8 | 20 | 51 | |
| Trench Gun (all 8 pellets) | 320 | 1 | 4 | 9 | 22 | |
| Gravedigger's Due (all 8) | 720 + burn | 1 | 2 | 4 | 10 | |
| BAR | 100 | 2 | 11 | 28 | 71 | |
| Ironmonger | 210 | 1 | 5 | 13 | 34 | |
| MG42 | 90 | 2 | 12 | 31 | 79 | A 125 belt holds about 4 kills at round 20 |
| Bone Saw | 180 | 1 | 6 | 16 | 40 | |
| Ashlight (direct + splash) | 1500 | 1 | 1 | 2 | 5 | Plus splash on the crowd |
| Ashlight Corona | 2300 + chain | 1 | 1 | 2 | 4 | |
| Totenglocke (≤4 m) | 3000 | 1 | 1 | 1 | 3 | Whole cone |
| Mitternacht (≤4 m) | 6000 | 1 | 1 | 1 | 2 | |

Perk modifiers to keep in mind: Twin Barrel Bitters +50% fire rate (T-082; was +33%), Hawkeye Brandy +headshot damage (+40% head multiplier; was +25%) and less sway, Death's Door = every hit kills (bosses take 10× damage instead).

---

## 13. Weapon Mastery (meta progression)

Per weapon. Kills with the upgraded variant count toward the base weapon.

| Camo | Requirement | Look |
|---|---|---|
| **Olive Drab** | 100 kills | Matte army olive with stenciled serials |
| **Winter** | 250 kills | Whitewash, chipped at the edges |
| **Bronze** | 500 kills + 50 headshots | Hammered bronze furniture |
| **Silver** | 1000 kills + 150 headshots | Engraved silver, scrollwork |
| **Gold** | 2000 kills + 300 headshots + 50 kills while upgraded | Polished gold with ivory grips |
| **Nachtglas** | Gold on **every weapon in that class** | Animated violet glass with slow-moving amber cracks |
| **Nachtglas Absolute** (meta) | Nachtglas on every class | Unlocks the Nachtglas camo on ALL weapons, including melee and wonder weapons, plus a calling card |

Wonder weapons and melee use kill-only tracks (no headshot requirement). Upgraded weapons always show the Crucible camo in a match unless the player toggles "Show Mastery Camo on Upgraded" in settings.

---

## 14. Flavor lines

Shown on the wall chalk outline, in the Crate result tooltip, and in the Archive weapon page.

| Weapon | Flavor | Upgraded name | Upgraded flavor |
|---|---|---|---|
| M1911 | *"Issued to every officer, trusted by every sergeant."* | Last Rites | *"Every round gets a second word in."* |
| Trench Knife | *"Knuckles, blade, and bad intentions."* | — | — |
| Sharpened E-Tool | *"Dig a hole. Fill a hole. Same tool."* | — | — |
| Mk 2 Frag | *"Pull, count, throw. Don't skip a step."* | — | — |
| Kar98k | *"Five rounds, five arguments, five settlements."* | Final Verdict | *"No appeal. No stay. Four at a time."* |
| M1 Garand | *"Eight rounds and a ping that tells everyone you're empty."* | Eight-Ping Benediction | *"The ping is a blessing now. So is the grenade."* |
| Gewehr 43 | *"German engineering, ten polite rounds at a time."* | Stille Nacht | *"Silent night. Holy night. Head shot."* |
| M1 Carbine | *"Light enough for a cook, good enough for a cook."* | Reveille | *"Up and at 'em. All of 'em."* |
| MP40 | *"Stamped steel and a long, dull rattle."* | Grabesgesang | *"The grave sings back."* |
| Thompson M1A1 | *"It came to Europe to settle accounts."* | Chicago Lament | *"Nobody in Chicago would recognize what it's shooting."* |
| STG-44 | *"Somebody in Berlin finally had a good idea."* | Sturmwind | *"A storm, in three-round sentences."* |
| Trench Gun | *"Made for the last war. Perfect for this one."* | Gravedigger's Due | *"Fire and buckshot. The digger always gets paid."* |
| BAR | *"Twenty rounds of opinion, delivered firmly."* | Ironmonger | *"Iron in, iron out, nobody standing."* |
| PPSh-41 | *"Seventy-one rounds and no time to count them."* | Red Winter | *"Every round brings the snow inside."* |
| MG42 | *"They called it Hitler's buzzsaw. It's ours now."* | Bone Saw | *"A longer belt for a shorter argument."* |
| Browning M1919 | *"Bolt it to a jeep, a boat, or a very strong man."* | The Long Amen | *"It finishes the prayer for you. All of it."* |
| Double-Barrel Sawed-Off | *"Two barrels, no manners."* | Twin Coffins | *"Four barrels. Room for everyone."* |
| Type 100 | *"Came a long way to end up in a Silesian crate."* | Hollow Blossom | *"It blooms where it lands."* |
| PTRS-41 | *"Built to stop tanks. Overqualified."* | Bear Tax | *"Everyone pays. In full."* |
| Springfield M1903 | *"One rifle, one shot, one less problem."* | Long Goodbye | *"Some goodbyes take the room with them."* |
| Panzerschreck | *"The stovepipe. Mind the backblast."* | Stovepipe Sermon | *"The sermon runs long and splits into chapters."* |
| M2 Flamethrower | *"Warm hands for a cold winter."* | Furnace Warrant | *"Authorized to burn everything on the premises."* |
| Siren Gramophone | *"Wind it, set it down, walk away. Don't look back."* | — | — |
| Ashlight | *"Fasbender called it a resonance projector. The men called it the Ashlight, after what was left."* | Ashlight Corona | *"Now it doesn't stop at one."* |
| Totenglocke | *"Ring it once for the living. They've had enough of that."* | Totenglocke: Mitternacht | *"Midnight. Every bell in Silesia, all at once."* |

---

## 15. WeaponData resource schema (for M1/M2)

```gdscript
class_name WeaponData extends Resource
@export var id: StringName
@export var display_name: String
@export var weapon_class: StringName        # pistol, smg, rifle, bolt, shotgun, lmg, sniper, launcher, special, wonder, melee, tactical
@export var damage: float
@export var pellets: int = 1
@export var rpm: float
@export var fire_modes: Array[StringName] = [&"semi"]
@export var mag_size: int
@export var reserve_max: int
@export var reload_partial: float
@export var reload_empty: float
@export var per_round_reload: bool = false  # bolt rifles / shotguns
@export var ads_time: float
@export var sway: float
@export var penetration: int = 0
@export var move_mult: float = 1.0
@export var falloff_start: float
@export var falloff_end: float
@export var falloff_min_mult: float
@export var limb_mults: Dictionary = {}      # overrides: {&"head": 3.0, ...}
@export var spread_hip_deg: float
@export var spread_ads_deg: float
@export var properties: Dictionary = {}      # bonus properties: ricochet, chain, incendiary...
@export var wall_price: int = 0
@export var crate_weight: int = 0
@export var crate_tier: StringName = &""     # A / B / C
@export var upgraded: WeaponData             # null if not upgradable
@export var flavor: String
```

---

# §11 AMENDMENTS (TERMS & CONDITIONS)

Everything below this line is new: brief §10.3, §10.6, §11.4 and §11.8. Each amendment is marked **(§11 amendment)**. All numbers are first-pass tuning and go to `data/gravelight/weapons/*.json` with the rest.

---

## 16. The Crucible plaque (§11 amendment)

See §11. The plaque text is locked: **"MOD. R-E · PAT. PEND. BLZ-40417"**.
- It is visible on every Crucible from the start. Players can read it long before they understand it.
- After `fp_ch5_done`, its Archive card gains a "see also" link to The Fine Print Ch. 4 and to the B&S PATENT PENDING weapon page.
- The Crucible's own VO (`OPR_CRUCIBLE_*`) is unchanged.

---

## 17. The Original Omega Forge: second upgrade tier (§11 amendment)

**What it is.** Blartz's own **Omega Forge prototype**, shipped to Basel as a "reference unit" for Crucible production, stands in the **Forge Chamber of the Barge** on Helvetia Works (`HW_BARGE`, see MAPS.md).
- **Look:** a squat, riveted, far-future forge in scuffed gold and gunmetal, with hazard decals in an alphabet no one in 1945 can read. Blartz's hand-lettered sign is still taped to it: *"PROTOTYPE 6 · DO NOT TOUCH · I MEAN IT · — B."*
- **What it does:** it takes a **Crucible-upgraded** weapon and upgrades it once more, to its **Omega variant**.

| Rule | Value |
|---|---|
| Location | Helvetia Works only, `HW_BARGE` Forge Chamber. *(It doesn't exist on other maps. That's canon: there is one prototype.)* |
| Input | A **Crucible-upgraded** firearm (`*_up`). Base weapons get "It wants something that's already been taught." Wonder weapons (Ashlight, Totenglocke, The Return Policy) and melee/tacticals are refused (see Blartz line .04). The OMNI-BLASTER and the Anomalous Inventory items are accepted. |
| Cost | **15,000 Scrip**. *Clause Zero step 5 grants one free cycle (EASTER_EGGS.md §7).* |
| Limit | **One Omega weapon in play per match, across the whole lobby.** While an Omega weapon exists, the Forge shows "The Forge is resting. One masterpiece at a time." If the Omega weapon leaves play (swapped away, lost on a down with Packmule, or left uncollected), the Forge unlocks again after 60 s. |
| Process | Feed the weapon in. The Forge hammers for **8 s** (Blartz's line .01 or .05 plays), then presents the weapon for **20 s**. If no one takes it, it is lost *and* the slot unlocks. In co-op it can be stolen, as with the Crucible. |
| Ammo | Omega-forging refills mag and reserve. **Refill at the Forge: 5000.** Wall-buy ammo for an Omega weapon: **6000**. The Crucible can't refill an Omega weapon ("Not my design," the Operator, `gl.helvetia.opr.crucible_refuse_omega.01`). |
| Stats | **Damage ×1.5** of the Crucible variant, **mag and reserve ×1.25** (rounded up), **reload ×0.9**. Keeps the Crucible bonus property and **adds a second one** (table below). |
| Camo | **"Patent Gold"**: gold-leaf filigree laid over the violet Nachtglas camo, with the violet veins still showing through the cracks of the gold. It's animated: the gold slowly creeps over the violet and is pushed back. An extra brassy *ka-ching* ring layers onto every shot. The Mastery camo toggle is ignored. Omega always shows Patent Gold. |
| Kill credit | Omega kills count toward the base weapon's Mastery and toward the profile stat `omega_kills`. |

**Blartz's voice through the Operator's speakers.** The prototype has a demonstration voice-chip that Blartz recorded for trade shows. On the Barge it routes to the nearest PA, which the Operator controls. **The Operator does not approve**, and follows each Blartz line with a disclaimer after 0.8 s. Channel `PA`, tier 3, cooldown 0. Speaker `blartz` (VOManager code `BLZ`).

| ID | When | Line |
|---|---|---|
| `gl.helvetia.blartz.forge.01` | Forge starts (default) | "BLARTZ OMEGA FORGE, PROTOTYPE SIX! Hands and tentacles clear of the chamber, please. If this unit is not in my workshop, it has been STOLEN, and I want you to know I am VERY disappointed in you." |
| `gl.helvetia.blartz.forge.02` | Forge done | "Omega complete! Gold trim, because some of us have TASTE. Not violet. *Never* violet." |
| `gl.helvetia.blartz.forge.03` | Forge done (alt) | "THERE. That's what a weapon looks like when somebody who actually CARES upgrades it!" |
| `gl.helvetia.blartz.forge.04` | A wonder weapon or base weapon is refused | "Not my work. Not touching it. I have standards. And a lawyer. ...Had a lawyer." |
| `gl.helvetia.blartz.forge.05` | First Forge start in a match (replaces .01) | "Patent number B-L-Z four-oh-four-one-seven. Write it down. Write it on EVERYTHING. Especially the violet ones." |
| `gl.helvetia.opr.forge_disapprove.01` | after any Blartz line | "We apologise for that unscheduled announcement. The voice you have just heard is not affiliated with the Ledger." |
| `gl.helvetia.opr.forge_disapprove.02` | after any Blartz line | "Please disregard the gentleman. Gold is not a market-appropriate colour." |
| `gl.helvetia.opr.forge_disapprove.03` | after any Blartz line | "An unlicensed product has been operated on the premises. The Ledger has made a note. The Ledger always makes a note." |
| `gl.helvetia.opr.forge_disapprove.04` | after .02/.03 only | "Lovely craftsmanship, I'm sure. *[splice]* {Confiscated} craftsmanship." |
| `gl.helvetia.opr.crucible_refuse_omega.01` | Omega weapon offered to a Crucible | "Oh, no, no. We don't service *that* model. Not anymore." |

### 17.1 Omega variants

The second property **adds to** the Crucible property. The Omega for the five B&S Anomalous items and the OMNI-BLASTER reuses their B&S Ω names: the Forge stamps its own designs with their original names.

| Base ID | Crucible name | Omega ID | **Omega name** | Second property (data key) |
|---|---|---|---|---|
| `m1911` | Last Rites | `m1911_om` | **Ω Final Encore** | `ricochet: 3` (replaces 1) |
| `kar98k` | Final Verdict | `kar98k_om` | **Ω Supreme Court** | `kill_splash: {dmg_pct: 0.5, r: 2.0}`: kills burst for 50% damage |
| `m1_garand` | Eight-Ping Benediction | `m1_garand_om` | **Ω Eight-Ping Jubilee** | `grenade_cluster: 3`: rifle grenades split in three |
| `gewehr43` | Stille Nacht | `gewehr43_om` | **Ω Silent Partner** | `headshot_refund: 1`: headshot kills return 1 round to the mag |
| `m1_carbine` | Reveille | `m1_carbine_om` | **Ω Rise and Shine** | `auto_rpm: 900` + `ricochet_chance: 0.2` |
| `mp40` | Grabesgesang | `mp40_om` | **Ω Grave Chorus** | `kill_arc: {dmg: 300, targets: 1, r: 4}` |
| `thompson` | Chicago Lament | `thompson_om` | **Ω Chicago Overtime** | `mag: 100` (drum) + `stagger: 0.15` |
| `stg44` | Sturmwind | `stg44_om` | **Ω Sturmflut** | `burst_penetration: +2` |
| `trench_gun` | Gravedigger's Due | `trench_gun_om` | **Ω Undertaker's Bonus** | `fire_spread: {r: 2.0}`: burning targets ignite neighbours |
| `bar` | Ironmonger | `bar_om` | **Ω Ironworks** | `stagger: 0.6` + `knockback: 1.5` |
| `ppsh41` | Red Winter | `ppsh41_om` | **Ω Permafrost** | `freeze_on_stacks: {hits: 3, dur: 2.0}` (non-boss) |
| `mg42` | Bone Saw | `mg42_om` | **Ω Bone Mill** | `sever_chance: 0.25` (replaces 0.15) + `no_overheat` |
| `m1919` | The Long Amen | `m1919_om` | **Ω Amen Again** | `kill_refund_rounds: 3` |
| `sawed_off` | Twin Coffins | `sawed_off_om` | **Ω Family Plot** | `volley: 6` + `volley_knockback: 3` |
| `type100` | Hollow Blossom | `type100_om` | **Ω Full Bloom** | `crawler_burst: {dmg: 400, r: 2}` |
| `ptrs41` | Bear Tax | `ptrs41_om` | **Ω Inheritance Tax** | `pen_ramp: +0.10` damage per target passed |
| `springfield` | Long Goodbye | `springfield_om` | **Ω Farewell Tour** | `headshot_pop_chain: 1` |
| `panzerschreck` | Stovepipe Sermon | `panzerschreck_om` | **Ω Stovepipe Revival** | `cluster.count: 10`, `mag: 3` |
| `flamethrower` | Furnace Warrant | `flamethrower_om` | **Ω Foundry Permit** | `burning_ground_spread` + `fuel_regen: 5/s` |
| `k31` | Neutral Ground | `k31_om` | **Ω Numbered Account** | `headshot_kill_bonus_scrip: 50` |
| `mp43_44` | Uhrwerk | `mp43_44_om` | **Ω Kuckucksuhr** | `on_the_hour`: every 12th round fires a 6-round 2× burst |
| `bs_lawn_dart` | Keep Off the Grass | `bs_lawn_dart_om` | **Ω DOUBLE FAULT** | `bomblet_split: 3` on detonation |
| `bs_grav_grenade` | Sinking Fund | `bs_grav_grenade_om` | **Ω EVENT HORIZON** | `hold_max: 9 s`, `crush_from_open` |
| `bs_cease_desist` | Final Notice | `bs_cease_desist_om` | **Ω INJUNCTION** | `served_silence: 2.0 s` (SERVED non-bosses can't attack) |
| `bs_frostbyte` | Long Frost | `bs_frostbyte_om` | **Ω DEEP FREEZE** | `statue_dur: 12`, `beam_range: 20` |
| `bs_buzzkill` | Graveyard Shift | `bs_buzzkill_om` | **Ω MOOD KILLER** | `bounces: 7`, `split_on_every_bounce` |
| `omni_blaster` | Field Promotion | `omni_blaster_om` | **Ω OVERTIME** | `every_3rd_hot: {fork: 2, r: 5}` |

**Omega flavor (Archive):** *"Blartz built it to make tools better. Darkmatter built a copy to make them obedient. This is the original."*

---

## 18. Anomalous Inventory: the rare Bolt & Sprocket crate pool (§11 amendment)

**Lore.** The Lost Requisition Crate is Darkmatter's Loot Allocation Unit, drawing "returned inventory" from across times and places. Very rarely it reaches far enough to pull a Bolt & Sprocket item, rebuilt by the unit to "local scale."

**Setting.** `Settings → Gameplay → Anomalous Inventory`.
- Hidden until `fp_ch5_done` (profile unlock `gl_anomalous_inventory`). Once unlocked it **defaults to ON**.
- It controls Maps 0–1 (and later 2–3).
- **On Helvetia Works the pool is always active** whatever the setting, because the map is the crossover, and at higher weights (§19.4).
- Classic Rules doesn't change it.

**Rules.**
1. **Weight:** each of the five items has **weight 0.5** on standard maps. That's 2.5 of a ~114.5 total, so about **2.2%** of pulls give *some* Anomalous item.
2. **Never on a player's first 3 pulls** (the pity window stays predictable). **Not affected by the dud breaker or bad-luck protection.**
3. **One Anomalous item held per player.** In co-op, each item can exist **once per match** (like the Ashlight).
4. **Tier:** all five are Tier A for the "5 pulls without Tier A" breaker. They *count* as the guaranteed Tier A result only on Helvetia Works.
5. **On roll:** the crate's Nachtglas light flickers violet-amber, the cycling models glitch for the last 0.5 s, and the Operator plays `gl.all.opr.anomalous.*` (VO_SCRIPT.md §9.1): *"This item is not from your era. Please enjoy responsibly."*
6. Anomalous items can't be refilled at walls. Refill them at the Crucible (2500, once upgraded), from Resupply, or by re-rolling. They **can** be Crucible-upgraded (5000) and Omega-forged on Helvetia Works.
7. Their projectiles and effects use **Gravelight art direction**: no bright B&S colors. Each item is "rebuilt" in brass, steel, wood and enamel, with a period stencil (*"FUNDSACHE · HERKUNFT UNBEKANNT"*, "found item, origin unknown").

### 18.1 Stats

The columns follow §3. Upgraded variants follow §5 (they get the Nachtglas camo plus one bonus property).

| ID | Item (crossover look) | Class | Dmg | RPM | Mode | Mag | Reserve | Rel (p/e) | ADS | Sway | Pen | Move |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `bs_lawn_dart` | **Lawn Dart**: a brass garden-dart launcher on a rifle stock | Launcher | 1200 splash | 90 | Single | 3 | 18 | 2.6 / 3.2 | 0.35 | 0.30 | — | 0.93 |
| `bs_grav_grenade` | **Grav Grenade**: a stubby enamel lobber firing "ball-bearing" singularity rounds | Launcher | 1500 pop | 40 | Single | 2 | 12 | — / 3.0 | 0.30 | 0.30 | — | 0.92 |
| `bs_cease_desist` | **Cease & Desist**: a bakelite pistol that fires folded stamped notices | Pistol | 90 | 240 | Semi | 10 | 100 | 1.6 / 2.0 | 0.16 | 0.18 | ricochet 3 | 1.00 |
| `bs_frostbyte` | **Frostbyte**: a ribbed steel beam projector with a frosted glass tank | Special | 30/tick (20 tick/s) + freeze | — | Beam | 160 cold | 480 | — / 3.4 | 0.30 | — | ∞ (beam) | 0.92 |
| `bs_buzzkill` | **Buzzkill**: a hand-cranked saw-blade launcher made from a sawmill guard | Launcher | 400 | 120 | Semi | 6 | 48 | 2.4 / 3.0 | 0.25 | 0.30 | ∞ (−10%/target) | 0.95 |

**Behavior notes**
- **Lawn Dart:** a slow homing dart (28 m/s, 90°/s turn) that sticks to its target and **detonates 0.8 s later**: 1200 dmg in 3.5 m, falling off to 30%. Self-damage 60 (none with Blastproof Bock). **Alt (Paint):** while ADS, hold on up to **3** targets within 40 m (0.35 s each) to mark them, then fire to release one dart per mark. Darts stuck in a **SERVED** target (Cease & Desist) detonate at 1.5× radius.
- **Grav Grenade:** the round opens a **4 m singularity** where it lands. It pulls non-boss enemies to its centre for **3.0 s**, then **pops** for 1500 in 4 m. Enemies held in it take **+50%** from all other sources. **Alt (Hold):** keep the trigger held to keep it open for up to **6 s**, which drains reserve 1 per 2 s. Bosses are slowed 40% instead of pulled. It doesn't pull Repossessors that are tagging a zombie.
- **Cease & Desist:** each notice **ricochets** to 3 targets within 8 m and stamps them **SERVED** for **6 s**. SERVED enemies take **+40%** damage from every source (bosses +20%). SERVED doesn't stack; re-stamping refreshes it. **Alt (Class Action):** a heavy notice that spends 3 rounds and stamps everything within **5 m** of the target. Visual: a red-ink *ZUGESTELLT* ("served") stamp decal that fades.
- **Frostbyte:** a 15 m beam. 1.5 s of continuous beam **freezes** a non-boss enemy into an ice statue for **4 s**. Frozen enemies **shatter** on any hit ≥ 10% of their max HP, or on any melee, and shattering pays **+30 bonus Scrip** (the "bolt fountain," as Scrip). Bosses are never frozen; the beam slows them 40%. Frozen Glasshides shatter normally. **Alt (Ice Wall):** spend 30 cold to raise a 4 m wide, 2 m tall ice barrier for **8 s** (600 HP, and zombies attack it like boards).
- **Buzzkill:** blades **bounce off world geometry up to 3 times** and pass through every zombie they meet, losing 10% damage per zombie. They **ignore Glasshide plate**, Repossessor chassis armor and Foreman plate (anti-armor). **Alt (Manual Override):** hold to steer the last blade fired with the camera for up to 2 s.

### 18.2 Upgraded (Crucible) variants: crossover names

| Base ID | Upgraded ID | **Crucible name** | Dmg | Mag | Reserve | Bonus property |
|---|---|---|---|---|---|---|
| `bs_lawn_dart` | `bs_lawn_dart_up` | **Keep Off the Grass** | 2000 splash (4.5 m) | 6 | 36 | `double_dart`: each trigger fires 2 darts locking different targets |
| `bs_grav_grenade` | `bs_grav_grenade_up` | **Sinking Fund** | 3000 pop | 3 | 18 | `crush: 400/s` while open |
| `bs_cease_desist` | `bs_cease_desist_up` | **Final Notice** | 200 | 16 | 160 | `ricochet: 6`, SERVED **+70%** (bosses +35%) |
| `bs_frostbyte` | `bs_frostbyte_up` | **Long Frost** | 70/tick | 240 cold | 720 | freeze in **0.8 s**, statues last **9 s**, shatter AoE 2 m (300 dmg) |
| `bs_buzzkill` | `bs_buzzkill_up` | **Graveyard Shift** | 900 | 10 | 80 | `bounces: 5`, blades split in two on the first bounce |

**Flavor lines**

| Item | Flavor | Upgraded flavor |
|---|---|---|
| Lawn Dart | *"Found in a sealed crate marked 'garden supplies.' There is no garden."* | *"Keep off the grass. Keep off everything."* |
| Grav Grenade | *"The ball bearing is heavier than the world it's in."* | *"Everything sinks. Eventually, everything."* |
| Cease & Desist | *"Nobody in 1945 can read the notice. The dead obey it anyway."* | *"No further correspondence will be entered into."* |
| Frostbyte | *"Cold enough to stop a heart that already stopped."* | *"Winter, sold by the yard."* |
| Buzzkill | *"Somebody's sawmill, somebody's century, somebody's very bad idea."* | *"The night shift never ends. Neither do the blades."* |

---

## 19. Helvetia Works weapons (§11 amendment)

### 19.1 Swiss wall-buys (new)

| ID | Weapon | Class | Source / price | Dmg | RPM | Mode | Mag | Reserve | Rel (p/e) | ADS | Sway | Pen | Move |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `k31` | Karabiner 31 (Schmidt–Rubin, straight-pull) | Bolt rifle | Wall 400 (Helvetia Works) | 110 | 70 | Bolt | 6 | 60 | 0.55/rnd · 2.2 clip | 0.28 | 0.30 | 1 | 0.95 |
| `mp43_44` | MP 43/44 (Swiss licence SMG) | SMG | Wall 1100 (Helvetia Works) | 50 | 800 | Auto | 50 | 250 | 2.4 / 3.0 | 0.22 | 0.28 | 0 | 0.98 |

- **Falloff:** `k31` 60 / 150 / 0.85. `mp43_44` 12 / 35 / 0.55.
- **Flavor:** K31: *"Neutral, accurate, and fast. Switzerland in a nutshell."* MP 43/44: *"Fifty rounds, made under licence, ticking like a good watch."*
- **Upgraded variants:**
  - **`k31_up` "Neutral Ground":** 440 dmg, 80 RPM, mag 10, reserve 100, rel 0.45/rnd · 2.0, pen 3. `quick_cycle`: 100 RPM while ADS. *"Takes no sides. Takes every head."*
  - **`mp43_44_up` "Uhrwerk":** 115 dmg, 850 RPM, mag 70, reserve 420, rel 2.0 / 2.6, pen 1. `clockwork`: every 12th round in a mag deals ×3 and *chimes*. *"Every hour, on the hour."*
- **Crate:** on Helvetia Works only, both are Tier C, weight 3.

### 19.2 Wonder weapon: THE RETURN POLICY (`return_policy`)

A Darkmatter **refund gun**: a sleek violet-enamel handset like a cross between a ticket punch and a telephone receiver, with a receipt roll in its grip. It "returns" zombies to sender: they fold up into a violet seam and vanish, leaving no corpse. **Helvetia Works crate only**, rare. It never appears in Anomalous Inventory on other maps.

| Stat | Base | **"No Questions Asked"** (`return_policy_up`, Crucible) |
|---|---|---|
| Fire | Hitscan "refund beam," 40 m, semi | Same |
| RPM | 100 | 110 |
| Mag / reserve | 8 / 40 | 12 / 72 |
| Reload (p/e) | 2.2 / 2.8 (it tears off a receipt) | 2.0 / 2.5 |
| **Return** | A non-boss target with **current HP ≤ 6000** is **returned** instantly. Otherwise it takes **6000** damage. | Threshold **12,000**, and the 12,000 damage applies above it. **Chains:** each return arcs to up to **4** more enemies within **7 m**, each checked against the threshold. |
| One-shot range (Gänger) | through **round 28** (r28 = 5,810) | through **round 35** (r35 = 11,319) |
| Bosses | **3000** damage and a red *RÜCKGABE ABGELEHNT* ("RETURN REFUSED") stamp VFX. Never returned. | 6000, never returned |
| Repossessors | Returned at the same threshold. They drop any Scrip they seized (ENEMIES.md §5.2). | Same |
| Scrip | A return pays a **flat 60** ("refund"). No headshot bonus. | Same |
| Self/team damage | None | None |
| ADS / sway / move | 0.20 / 0.15 / 1.00 | Same |
| Crate weight | 3, with bad-luck protection identical to the Ashlight (§10 rule 4) | — |
| Scarcity | One in play per match on the map (co-op), like the Ashlight | — |
| Omega | Refused (wonder weapon) | — |
| Audio | A cash-register *ding*, a paper-tear, and a soft reversed-whoosh fold | Plus a chain of descending *dings* |
| Flavor | *"Unsatisfied? Return it. No receipt required."* | *"No questions asked. None answered, either."* |

### 19.3 Buildable: Blartz's Field-Kit OMNI-BLASTER (`omni_blaster`)

A WW2-scale field build of the Bolt & Sprocket starting sidearm. The parts come from a dented courier case labelled *"BLARTZ — FIELD KIT — IF FOUND, RETURN TO BLARTZ (REWARD: GRATITUDE)"*, which burst open across the factory when Blartz's delivery pad misfired.

| Part | ID | Location (one of 3 seeded spots each, see MAPS.md) | How |
|---|---|---|---|
| Blaster grip | `ob_part_grip` | `HW_DOCK`: forklift seat / dispatch desk / pallet stack | Pick up |
| Heat coil | `ob_part_coil` | `HW_LAB`: distillation rig / cold cabinet / fume hood | Pick up |
| Emitter barrel | `ob_part_emitter` | `HW_QUAY`: crane cab / bollard by the barge beam / bargee's hut | Pick up |
| Workbench | `ob_workbench` | `HW_ASSEMBLY`, the QA bench at the end of the line | Hold [F] 3 s with all parts (Deacon −15%). Then free pickup, one per player. |

Parts are shared in co-op and shown on the parts strip under the Scrip counter, like the Totenglocke's.

| Stat | Base | **"Field Promotion"** (`omni_blaster_up`, Crucible) |
|---|---|---|
| Fire | Hitscan bolt, semi (fast) | Same |
| Damage | 220 | 520 |
| RPM | 360 | 400 |
| Ammo | **Infinite; a heat bar replaces it.** +6% heat per shot. At 100%: **overheat**, a 1.0 s vent with no fire. Cools 35%/s after 0.4 s without firing. | +4% per shot, 0.8 s vent |
| **Alt: Hot Round** | Needs heat ≥ 40%. Consumes all heat. A piercing shot dealing **5000 × heat fraction**, unlimited penetration, igniting for 100/s for 3 s. | **10,000 × heat fraction** |
| Bonus property | — | `overtime_lite`: every 5th shot forks a spark to 1 bystander within 5 m at 50% |
| ADS / sway / pen / move | 0.18 / 0.15 / 0 / 1.00 | Same |
| Omega | — | **Ω OVERTIME** (§17.1) |
| Overclock Cordial | A vent from overheat counts as a full-empty reload (e = 1.0, §20.2) | Same |
| Flavor | *"Somebody's sidearm from a very long way off. It runs hot. So did he."* | *"Promoted in the field. Nobody signed the paperwork."* |

### 19.4 Helvetia Works crate pool

This is Helvetia's own table. It replaces §10's table on this map only; §10's rules 1–8 still apply.

| Weapon | Tier | Weight |
|---|---|---|
| PPSh-41 | A | 9 |
| MG42 | A | 9 |
| Browning M1919 | A | 7 |
| Panzerschreck | A | 6 |
| PTRS-41 | A | 5 |
| **The Return Policy** | A (wonder) | 3 (+ bad-luck protection) |
| Ashlight | A (wonder) | 2 |
| **Lawn Dart / Grav Grenade / Cease & Desist / Frostbyte / Buzzkill** | A (anomalous) | **2 each** (10) |
| Double-Barrel Sawed-Off | B | 8 |
| Type 100 | B | 7 |
| Springfield M1903 | B | 6 |
| M2 Flamethrower | B | 5 |
| Siren Gramophone | B | 6 |
| Thompson M1A1 | B | 5 |
| STG-44 | B | 5 |
| BAR | B | 5 |
| MP 43/44 | C | 3 |
| K31 | C | 3 |
| M1 Carbine | C | 3 |
| Gewehr 43 | C | 3 |

Total weight 120. Each Anomalous item is about 1.7%, all five together 8.3%, and the Return Policy 2.5% before bad-luck protection. A player can hold only one wonder weapon at a time (the Return Policy or the Ashlight). The OMNI-BLASTER is never in the crate.

---

## 20. New perk tonics: effects and numbers (§11 amendment)

Neither new perk raises the cap (6 on every map since T-081, 4 under Classic Rules). The Map 1 main egg's permanent extra slot still applies on Map 1 only. Both perks need power like all others, and both are lost on down under classic rules. Machines, jingles and panels are in `docs/JINGLES.md` §9–§10. Data: `data/gravelight/perks/fine_print_fernet.json`, `overclock_cordial.json`.

### 20.1 Fine Print Fernet (`fine_print_fernet`), 2000

"Lets you see the truth."

| Effect | Number / rule |
|---|---|
| **Power-up timers** | The HUD shows a ring timer on every active timed power-up icon (Death's Door, Double Scrip, Clearance). Uncollected drops show a shrinking despawn ring, visible to the holder in world-space within 40 m. |
| **Drops last 50% longer** | Uncollected drops last **45 s** instead of 30, and blink from 33 s. This applies to **all players** while **any** living player holds Fernet ("the offer waits for someone who can read it"). Timed effects collected by a Fernet holder last **45 s** instead of 30 **for that holder** (per-player timers for Death's Door and Double Scrip). Clearance stays global at 30 s, or **45 s** if the player who collected it holds Fernet. |
| **Easter-egg glint** | Quest objects, quest pickups, intel spawns and hidden panels within **25 m** and line of sight give a faint amber **glint** every **4 s** (a 0.3 s screen-space sparkle with a soft paper-rustle tick). It never reveals randomized *answers* (codes, melody order, target machine) or the crate drummer's hidden counter. Herr Tamtam stays the one true mystery. |
| **Underwriter readout** | When the Underwriter is active, the holder sees their own current **pricing tier and multiplier** (ENEMIES.md §5.3) under the Scrip counter, e.g. `TIER 3 · ×2.50`, plus the Scrip left before the next tier boundary. |
| Stencils | No extra effect (see `docs/JINGLES.md` §0.2) |
| Accessibility | The glint can be switched to "outline" or "audio only" in accessibility settings. |

### 20.2 Overclock Cordial (`overclock_cordial`), 2500

"Reloading releases a static burst that scales with how empty the mag was."

| Rule | Value |
|---|---|
| Trigger | The **start** of any reload (manual or automatic), when the spent fraction **e = 1 − rounds_in_mag / mag_size ≥ 0.25**. Burst lands 0.15 s after the reload starts. Bolt and shell-by-shell reloads trigger once, on the first round loaded. Beam/fuel weapons use the tank's empty fraction. The OMNI-BLASTER triggers on an overheat vent (e = 1.0). |
| Radius | **2.5 + 4.0 × e** m (6.5 m at a fully empty mag; T-082, was 3.5 e / 6.0 m) |
| Damage (non-boss) | **0.66 × health(r) × e** per target, max **12** targets (T-082; was 0.6 and 10). That's 99 at r1 empty, 1789 at r20 empty, and 4640 at r30 empty. **Repossessors take ×2.** Electrical damage **ignores Glasshide plate**. |
| Damage (bosses) | Flat **1700 × e** (Foreman, Underwriter; was 1500) |
| Stagger | All non-boss enemies in radius are staggered when **e ≥ 0.75** |
| Cooldown | **3.0 s** internal. Trigger Tonic speeds the reload, not the cooldown. |
| Safety | No self, team, or barricade damage |
| Scrip | Kills pay body-kill value (50). Non-lethal hits pay the usual +10 once per burst per target. |
| Feedback | A teal-violet ring pulse and a fat electric *ZAP*. The Overclock cabinet's gauge needle twitches if it's within 6 m. With Bolt on the team, Sprocket comments (Ch. 5 quote pack, topic `perk_overclock`). |

---

## 21. Weapon ID additions for the canon sheet (§11 amendment)

New IDs: `k31`, `mp43_44`, `return_policy`, `omni_blaster`, `bs_lawn_dart`, `bs_grav_grenade`, `bs_cease_desist`, `bs_frostbyte`, `bs_buzzkill`; each has an `_up` (Crucible) and, where allowed, an `_om` (Omega) variant.
- Buildable IDs: `ob_part_grip`, `ob_part_coil`, `ob_part_emitter`, `ob_workbench`.
- New status: `served` (Cease & Desist).
- New WeaponData fields: `omega: WeaponData` (null when not Omega-able), `anomalous: bool`, `heat_per_shot`, `heat_cool_rate`, `vent_time` (OMNI-BLASTER), `return_threshold`, `return_chain` (Return Policy).

---

## 22. Morgenrot weapons (Map 3, ULTIMATE PROMPT v2 §3; design only, built in M8.5)

### 22.1 Wonder weapon: DIE LANGE NACHT (`lange_nacht`), buildable
Parts: a **LOX flask** (Treibstofflager), a **nozzle** (Assembly Hall), a **pressure regulator** (Dam); built at the Leitstand workbench (the Totenglocke's buildable rules, `buildable: true`).

| Stat | Value |
|---|---|
| Archetype | `stream` (the flamethrower's cone), `frost` instead of `ignite`: reach 9 m, cone 30°, 20 ticks/s |
| Freeze | a zombie in the cone for **1.2 s** freezes solid (`frozen` status: no movement, no attack, 8 s); frozen zombies **shatter** to one melee hit or 150 bullet damage (the Glasshide shatter shockwave, 60 in 2 m, which also damages zombies) |
| Damage | 18 per tick while in the cone (so a frozen zombie taken out by bullets still counts a kill for the lance) |
| Fuel | 80 units, 8 s continuous; refills at the Crucible (2500) or by the LOX flask part respawning every 3 rounds at the depot |
| Bosses | the Startmeister's arcs are put out by the cone; Reinholt's shield is the only thing it freezes in step 9 |
| Crucible: **Polarnacht** (`lange_nacht_up`) | reach 12 m, cone 40°, freeze in 0.9 s, and a frozen target **spreads the freeze** to zombies within 3 m (`freeze_spread`); 120 fuel |
| Flavor | *"The rocket's own fuel, turned against it."* / Polarnacht: *"Nothing moves at the pole. Nothing needs to."* |

### 22.2 Crate additions (Morgenrot pool, tier A unless noted)

| Base ID | Name | Archetype | Crucible name | Notes |
|---|---|---|---|---|
| `panzerfaust` | Panzerfaust | single-shot `projectile` rocket (1 / 6, slow reload 3.2 s), 1400 + 900 splash in 3.5 m | **Late Postage** (`panzerfaust_up`): 2 / 10, `cluster: 4` bomblets | tier A, weight 5 |
| `g1_lance` | Gewehr 1-Lance | a fictional lance-pattern anti-tank rifle: bolt, 5 / 30, 520 dmg, `penetration: 6` | **Point of Order** (`g1_lance_up`): 820 dmg, `pen_ramp: +0.10`, `stagger: 0.5` | tier A, weight 5 |
| `fsg_rifle` | Fallschirm-pattern automatic rifle (fictional) | auto 550 RPM, 20 / 200, 110 dmg, `fire_modes: [auto, semi]` | **Second Descent** (`fsg_rifle_up`): 160 dmg, 30 / 300, `headshot_refund: 1` | tier B, weight 6 |
| `gramophone` | Siren Gramophone, new record "Lili vom Berg" | as §6 | — | tier B |

All names are invented; no real manufacturer or unit is named on the models (ART_FACTIONS.md).

### 22.3 Freeze family (shared data, `enemies.json status`)
`frost_vent` (players: move ×0.6; from depot vents, Frostbiss hits, the Spillway Gate) and `frozen` (zombies: Die Lange Nacht) sit beside Totenhafen's `wading` and `ballast`. The Crucible tiers (§11.1) apply to every Morgenrot weapon.

## 23. Homage boss rewards and the flare gun (ULTIMATE PROMPT v3; design only, built in HB1–HB3; `docs/HOMAGE_BOSSES.md`)

### 23.1 The KINDERHAMMER (`kinderhammer`), melee, the Hammer's drop (HB1, Map 0)
The Hammer's splitting maul, dropped where she topples. **The first player to pick it up keeps it for the rest of the match.** If that player bleeds out in co-op, it drops at their body for someone else.

| Stat | Value |
|---|---|
| Slot | Replaces the melee (trench knife, E-Tool or Bolt's mallet) while held; the old melee comes back if it is lost |
| Swing | `max(1500, 0.5 × health(r))` damage, a 0.75 s swing, 100° arc, 2.4 m reach, up to 3 targets, the knife's lunge |
| Throw (**hold melee**, 0.4 s wind-up) | A boomerang arc up to 20 m that **curves round one corner** toward the aim point, hits on the way out **and** back, up to 5 targets per pass at `max(600, 0.6 × health(r))` each, then returns to the hand (a 3 s cooldown before the next throw). It is caught automatically, unless the thrower is downed (then it lands at their feet). |
| Bosses | ×0.5, like Super Sprocket |
| Bolt | If Bolt holds it, it replaces his mallet for the match and keeps his mallet's Classic Rules fallback. On pickup: *"...Oh, that's mine. Kind of."* (`BLT_KINDERHAMMER_01`) |
| Classic Rules | Trench knife stats, no throw |
| Crucible | Refused (melee) |
| Flavor | *"Wood for Auntie."* |

### 23.2 Leuchtpistole (`leuchtpistole`), crate tactical, Morgenrot only (HB3)
A single-shot signal pistol, a new tier-B crate tactical in the Morgenrot pool (weight 5). It sits in the tactical slot, as the Siren Gramophone does.

| Stat | Value |
|---|---|
| Ammo | 4 flares (6 max), +2 per Resupply |
| Shot | A slow arcing flare (40 m/s, gravity), 150 direct + `burning` 3 s |
| Light | **A landed flare lights a 12 m radius for 20 s**; a flare that hits the Slender sticks and lights him for 8 s. Everything in its light counts as **lit** for the Slender's damage rule (`HOMAGE_BOSSES.md` §6.5). |
| LOGGED | Standing in flare light drains a player's LOGGED meter like the floodlights (−15/s) |
| Crucible | **Morgenstern** (`leuchtpistole_up`): 6 flares (9 max), 24 m light for 30 s, 400 direct |
| Flavor | *"Light one for the watchman."* / Morgenstern: *"The morning star, in your pocket."* |

### 23.3 PAUL'S LAST ROUND (`pauls_last_round`), Paul's drop (HB2, Map 1)
A battered Ironhide bottle at his body, **one per player**, personal (`HOMAGE_BOSSES.md` §13 D7). Hold Use to drink.
- **Without Ironhide:** the Ironhide Stout effect (275 max health since T-082) **for free, without using a perk slot**, until you are downed.
- **With Ironhide:** a one-time **+100 overshield** that takes damage first and doesn't regenerate.
- It isn't a perk: it doesn't count toward the cap, Second Wind doesn't restore it, and Vendelin's Service Call can't refill it.
- In data it is a power-up-like pickup with `kind: "bottle"`.

### 23.4 OVERWATCH (`overwatch`), the Slender's reward (HB3, Morgenrot)
Squad-wide, for the rest of the match, and it uses no perk slot.
- **Zombies within 12 m are outlined through walls in faint violet** (a depth-ignoring rim on the MZ infection shader, at most 24).
- It is shown as a small violet eye beside the perk caps.
- "Reduce screen effects" thins the rim; it never removes it.

## 24. Aiming down sights: sight markers, ADS zoom, the alignment check (Update 02 §2, T-047)

- **Sights are markers, not numbers.** Every weapon model carries a `SightPoint` Marker3D (rear notch, peep
  aperture, shotgun receiver groove, or scope eyepiece) and a `FrontSight` Marker3D (front post tip, bead, or
  scope objective). The `WeaponModels` sight helpers place them (`rear_notch`, `rear_aperture`, `rear_groove`,
  `front_post`, `front_blade`, `front_bead`, `scope_sight`), so a new gun built with them aims correctly.
- **ADS pose.** `WeaponHolder._compute_ads_pose()` puts `SightPoint` on the camera's center ray at the weapon's
  eye relief and turns the gun so `FrontSight` is on the same ray. There are no hand-tuned ADS offsets. The
  viewmodel FOV scale and the anti-clipping compression scale about the eye, which leaves the center ray where it
  is. Aimed, the rig follows the shaken eye, so screen shake can't knock the sights off the center either.
- **Data** (`weapons.json`, the row's `feel`; upgraded rows inherit it): `eye_relief` is the distance in metres
  from the eye to `SightPoint`; `ads_zoom` is the camera FOV multiplier at full aim (Thompson 0.9, about a 10% zoom;
  Springfield 0.3 with the scope picture). Each class in `feel.classes` has an `ads_zoom` that serves as the
  fallback. The row's `sway` stat scales ADS sway: the turning lag, a slow figure-8 drift while idle and a
  stride-paced figure-8 while walking. `ads_sway_mult` in `feel` scales it further.
- **Check after any weapon change:** `tools/ads_check.sh`. It aims every gun (base and upgraded) with sway off,
  prints where each one's rear and front sights land on screen (in pixels from the center, at 1280x720) as
  PASS/FAIL within 1.5 px, and saves `morning/screenshots/ads/<weapon>.png` with a center-dot overlay. The exit
  code is the number of failures. GUT `test_ads_alignment.gd` checks the same projection with math only: several
  FOVs and compressions, a wall pull, and screen shake.
- **By hand:** `AdsRange.launch(get_tree(), [ids])` starts the Test Range with those guns. Press `]` / `[` to cycle
  through them; a center dot shows while you're fully aimed.

## 25. The Armorer's Bench: M1911 attachments (Update 04 §6, DECISIONS T-068)

The starting M1911 (and Last Rites, and its II / III teachings) takes attachments at an **Armorer's Bench**: a
gunsmith's bench with a vise holding a display pistol, a pegboard of files and drifts, a parts tray, an oil can and a
gooseneck lamp (`gravelight/world/armorers_bench.gd`, art built procedurally like the other interactables). One per
map near spawn: the Crossroads Inn's stable (its tack corner on the west wall, under the tack rail: the inn has no
walled tack room), Kaltenbrunn's gatehouse (east face), Totenhafen's harbourmaster's hut (south face, facing the spawn).
Helvetia Works and Morgenrot will just place the node. The B&S OMNI-BLASTER is untouched.

All numbers are in `data/gravelight/weapons/attachments.json` under `weapons.m1911` (moved there unchanged by T-074; JSON, the project's data convention, instead of
the order's `.tres`). Five slots, **one option per slot**: buying another option in a slot replaces the fitted one.

| Slot | Option | Scrip | Effect | On Last Rites |
|---|---|---|---|---|
| Magazine | Extended Mag | 750 | 12 rounds (96 reserve); the box sticks out of the grip | **Penitent's Magazine**: 18 / 144 |
| | Drum Mag | 1500 | 30 rounds (150), reload ×1.45, ADS ×1.35, move ×0.97, draw ×1.15; hangs under the grip | **Rosary Drum**: 40 / 200, reload ×1.3, ADS ×1.25, a string of brass beads |
| Barrel | Match Barrel | 1000 | damage ×1.15, range (falloff) ×1.5; stands proud of the slide | **Vesper Match**: ×1.25, range ×1.8, +1 penetration |
| | Compensator | 1000 | recoil −40%, RPM ×1.1; ported, its flash jets out of the ports | **Censer Compensator**: −50%, ×1.15; the violet flare ignites zombies hit within 6 m (80/s, 3 s) |
| | Suppressor | 1000 | the OSS trials "can" (stencilled EXPERIMENTAL): shots don't reveal on the minimap, damage ×0.9, a muffled report, a tiny flash | **Vow of Silence**: no damage loss, head ×1.15 |
| Sights | Radium Night Sights | 600 | ADS ×0.75; three glowing dots | **Vigil Sights**: ADS ×0.65, aimed spread ×0.8, violet dots |
| | Raised Target Sight | 600 | aimed spread ×0.5, ADS zoom 0.86; a tall adjustable rear and high blade | **Steeple Sight**: aimed spread ×0.35, sway ×0.85, zoom 0.82 |
| Grip / Stock | Detachable Shoulder Stock | 900 | ADS sway −60%, recoil ×0.8, aimed spread ×0.85, move ×0.98, draw ×1.25; a walnut board stock on the heel | **Pallbearer Stock**: sway ×0.3, recoil ×0.65, draw ×1.15 |
| | Checkered Grips | 500 | hip spread ×0.7, draw ×0.75; black checkered panels | **Confessor's Grips**: hip ×0.6, draw ×0.65, move ×1.03 |
| Ammo | Hollow-Points | 1200 | head ×1.35; a dark cavity in the top round, a red band on the magazine | **Last Word Hollow-Points**: head ×1.5, neck ×1.2 |
| | Nachtglas-Tipped | 2000 | **after the power is on** ("under the counter"); damage ×1.2, 6% of hits slow 30% for 1.5 s; violet noses and band | **Nachtglas Benediction**: ×1.3, 12%, 35% for 2 s |

**Rules.** The kit lives on the pistol (`WeaponInstance.kit`): it stays for the match; the Crucible keeps it and every
part becomes its upgraded version (the forge carries it to whoever takes the weapon); a wall-buy that takes the
pistol's slot takes the kit with it; giving the pistol to Jakub gives him the kit (and his gun handed back keeps its
own); the campaign carry and co-op inventory carry it (`WeaponHolder.to_net` entries 7–8). Jakub refuses the
Nachtglas rounds: the bench won't load them for him, and he won't take a pistol loaded with them. Stat multipliers
act through `WeaponInstance.f()`, so they stack with the Crucible tiers.

**The bench screen** (`gravelight/ui/armorers_bench_ui.gd`): your pistol in the vise under the lamp with the camera
orbiting it, rebuilt live for the option you are looking at; the slot tabs; the options with prices; six bars
(damage, range, recoil, ADS speed, mobility, capacity) with the change in green or red; BUY. Each survivor has a
"Gunsmith" line (VO_SCRIPT §17).

**On the gun.** Every part is on the model (`gravelight/weapons/m1911_kit_models.gd`): first person, third person
(RemoteBody reads the owner's kit) and the bench. The sights are built with the sight helpers, so `tools/ads_check.sh`
checks every sights × stock combination of the M1911 and Last Rites (16 builds; all centred, 0.00 px). Under the
default hip and aim poses the grip's base sits below the frame, so the Drum and the magazine bands show in the reload,
in third person and at the bench rather than at the hip.

**Meta.** Lifetime M1911 kills (Last Rites counts) unlock cosmetic finishes: Blued 25, Battle-Worn 100, Nickel 250,
Engraved 500, Nachtglas Inlay 1000 (Last Rites always shows the Crucible's Nachtglas); and at 75 kills one **Loadout
Pick**, Extended Mag or Checkered Grips only, fitted to your starting pistol every match. Both are chosen in Settings
→ Gameplay (`MenuSettings.m1911_rows`), stored in the profile (`equipped.m1911_finish`, `equipped.m1911_pick`).

**APIs.** `ArmorersBench.buy(player, slot, option) -> {ok, reason, price}`, `ArmorersBench.options_for(player)`,
`ArmorersBench.nearest / in_reach / stand_point` (bots and map marks); `M1911Kit.loadout_rows(player)` (the LOADOUT
tab); `WeaponInstance.is_suppressed()` and `GLBus.shot_is_suppressed(pid)` during `weapon_fired` (the minimap's
firing reveal). Dev console: `kit list | <slot> <option> | free <slot> <option> | clear [slot] | finish <id>`.
Sounds: `python gravelight/tools_src/gen_audio_kit.py`. Captures: `kit_shots.tscn`, `bench_shots.tscn`
(`-- --play` is the launcher's bench test).

## 26. The Armorer's Bench for any gun (DECISIONS T-074)

The bench now works on **whatever gun is in your hands** (`gravelight/weapons/weapon_kit.gd`, `WeaponKit`). Data:
`data/gravelight/weapons/attachments.json`. Each gun's table = its weapons.json class's table (`classes`, a class may
be `like` another) + the per-weapon entry in `weapons` (keyed by base id: null removes an option, a dict's keys
replace the class option's keys). The M1911 keeps its §25 table verbatim (`own_table`), with its finishes and the
Loadout Pick. Upgraded (Crucible) guns use their base gun's table and each part's `upgraded` block: its own name and
text; numbers it leaves out are the base part's, with benefits ×`upgrade_boost` (1.35) and drawbacks ×0.6.

| Class (guns) | Magazine | Barrel | Sights | Grip / stock | Ammo |
|---|---|---|---|---|---|
| smg (MP40, Thompson, PPSh-41, Type 100) | Extended 1250, Drum 2250 (Thompson: 50-rd L drum → C drum 100 on Chicago Lament; MP40: MP40/II twin slide; PPSh: 35-rd box instead) | Cutts comp 1000, Suppressor 1500, Long barrel 1000 | Radium 600, Peep insert 750 | Vertical foregrip 900, Sling 600 (reloads on the run by class) | Hollow-points 1200, AP 1200, Nachtglas 2500 |
| assault (STG-44) | as smg, twin-pack mags, no drum | as smg | + ZG 1229 "Vampir" scope 2000 | as smg + Paratrooper Sling 1000 | as smg |
| rifle (Garand, G43, Carbine) | Extended 1250 (Garand: T20 20-rd box; Carbine: 30-rd banana) | Flash hider 900, National Match 1000, Suppressor 1500 | Scope 1500 (M84 / ZF4 / Weaver), Radium 600 | Paratrooper Sling 1000, Sling 600, Cheek pad 700 | AP 1200, Incendiary 1500, Nachtglas 2500 |
| bolt (Kar98k) / sniper (Springfield, PTRS-41) | Stripper pouch 750 (Kar98k: 25-rd trench magazine 1500) | Match 1000, Flash hider 900, Suppressor 1500 (PTRS: muzzle brake 1250) | Scope 1500 (Kar: ZF39; PTRS: PE; Springfield: Unertl 8x glass 1250), Radium 600 | Paratrooper Sling 1000, Sling, Cheek pad | AP, Incendiary, Nachtglas |
| shotgun (Trench Gun, Sawed-Off) | Shell bandolier 750, Extended tube 1250 | Full choke 900, Cutts comp 1000 | Ivory bead & rib 500, Radium 600 | Paratrooper Sling 1000, Recoil pad 700, Sling 600 | Magnum buck 1250, Dragon's Breath 1750, Nachtglas 2500 |
| lmg (BAR, MG42, M1919) | Extended 1750 (BAR 40-rd; MG42/M1919 250-rd belt box) | Flash hider 1000, Heavy barrel 1250 (M1919: spare barrel, runs cooler) | Radium 600, Spider-web AA sight 900 | Paratrooper Sling 1250, Bipod 1250 (BAR A2; MG42 Heavy Zweibein; M1919 M2), Assault sling 900 | Tracer belt 1000, AP 1250, Incendiary 1750, Nachtglas 3000 |
| launcher (Panzerschreck) | Ready-rack 1500 (+50% rockets) | Muzzle ring (54/1) 1000 | Ranging sight 750, Radium 600 | Paratrooper Sling 1000, Shoulder pad 600 | Hollow-charge 2000, Nachtglas 3000 |
| special (M2 flamethrower) | Third tank 1750 | Long nozzle 1250 (reach 9 / 11 m) | — | Paratrooper Harness 1000, Pack harness 750 | Thickened fuel 2000 |
| wonder (Ashlight, Totenglocke, Sankt-Elmsfeuer), melee, tacticals | refused in character (`refuse`, `refuse_classes`) | | | | |

**The Paratrooper Sling** (T-083, grip slot `quick_sling`; the flamethrower's is a Paratrooper Harness; taught: Pilgrim's Sling / Harness): an airborne quick-release sling whose one job is `props.sprint_reload` (§4.1: the gun reloads while you sprint, as SMGs and pistols do by class) plus a slightly quicker raise (`draw` 0.92). It takes the grip slot, so it costs you the foregrip / bipod / cheek pad / recoil pad in that slot: a mobility choice. Pistols and SMGs don't list it (they have it already). It uses the leather sling's model on the long guns; the tube and the flamethrower show no part.

**Rules.** The kit lives on the WeaponInstance of any gun: Crucible (and tiers II/III) keep it; Jakub, the campaign
carry and the co-op inventory carry it (`net_entry` 7, decoded against the gun's own table); a wall-buy or **Mystery
Crate result that takes the gun's slot loses it** (the new gun comes plain; re-buying the same gun only refills).
Every suppressor sets `props.suppressed` (`WeaponInstance.is_suppressed`, `GLBus.shot_is_suppressed`). The bench
targets `WeaponKit.gun_of(player, slot, option)`: the gun in hand, else the first gun in your slots offering that part
(bots sent by a mark for a part). The bench screen shows that gun's slots; a long gun lies in two padded rests instead
of the vise. Map marks: slot → "Bot's pick" or the options on the squad's guns; a part the bot's gun doesn't take
becomes its own pick in that slot (refusal "no_fit" when the gun has nothing there).

**On the gun** (`gravelight/weapons/weapon_kit_models.gd`): parts built from the model's own markers and outline:
muzzle parts (can, comp, hider, choke, brake, longer barrel, crown, nozzle) move the Muzzle; magazines (extension,
drum, twin, trench box, belt box, shotgun tube, shell carrier); scopes move SightPoint/FrontSight to the eyepiece /
objective (level, centred) and set meta `scope` (HUD scope picture); radium dots, ivory bead, AA ring stay off the
sight line; bipod (MG42/M1919 replace their own `BipodLeg` nodes), foregrip, sling, cheek pad, recoil pad; ammo bands.
`tools/ads_check.sh` checks `WeaponKit.sight_stock_builds()` (`-- --kits-only`); headless it is the pure ADS math.
