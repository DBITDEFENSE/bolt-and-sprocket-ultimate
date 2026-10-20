# GRAVELIGHT — Enemies

All numbers here are **starting tuning values**. The live values belong in `data/enemies.tres` and `data/rounds.tres`, and those files win once they exist. Names and IDs follow `docs/CANON.md`.

---

## 1. Round scaling
Canonical formulas. These are mirrored in `data/rounds.json`, and if the two ever differ the data file wins.

### 1.1 Health (Gänger base health per round)
```
health(r) = 150 + 100 × (r − 1)                 for r ≤ 9
health(r) = floor( 950 × 1.1^(r − 9) )          for r ≥ 10     (r10 = 1045)
```
Each enemy type then applies its own multiplier to this base (see §2).

### 1.2 Zombie count, cadence, and damage
```
count(r, p)     = ceil( (6 + 2.2·(r−1) + 0.09·(r−1)²) × player_mult[p] )
player_mult     = [1.0, 1.6, 2.2, 2.8]      # 1–4 players
spawn_interval  = max(0.25, 2.0 × 0.95^(r−1))   seconds   (r1 = 2.0 s)
```
- **Max active:** 24 at once, across all types, for any player count. The rest wait in the **spawn queue**. A spawn waits while active == 24.
- **Zombie hit on player:** 50 damage, **attack cooldown 1.2 s** (Gänger baseline; other types override it in §2).
- **Special-round counts** (Bellringers) use their own formula (§2.3).
- **Round end:** the queue is empty and active == 0. If one zombie is left for 20 s, it gets a "last zombie" flag and is boosted to the jogger tier at minimum, so players can't stall forever. A last-zombie crawler keeps crawler speed and is never auto-culled, because keeping a crawler alive is a classic player choice.

### 1.3 Round table (rounds 1–30)
| Round | Gänger HP | Solo | 2P | 3P | 4P |
|---|---|---|---|---|---|
| 1 | 150 | 6 | 10 | 14 | 17 |
| 2 | 250 | 9 | 14 | 19 | 24 |
| 3 | 350 | 11 | 18 | 24 | 31 |
| 4 | 450 | 14 | 22 | 30 | 38 |
| 5 | 550 | 17 | 26 | 36 | 46 |
| 6 | 650 | 20 | 31 | 43 | 54 |
| 7 | 750 | 23 | 36 | 50 | 63 |
| 8 | 850 | 26 | 42 | 57 | 73 |
| 9 | 950 | 30 | 47 | 65 | 83 |
| 10 | 1,045 | 34 | 53 | 73 | 93 |
| 11 | 1,149 | 37 | 60 | 82 | 104 |
| 12 | 1,264 | 42 | 66 | 91 | 116 |
| 13 | 1,390 | 46 | 73 | 100 | 128 |
| 14 | 1,529 | 50 | 80 | 110 | 140 |
| 15 | 1,682 | 55 | 88 | 120 | 153 |
| 16 | 1,851 | 60 | 95 | 131 | 166 |
| 17 | 2,036 | 65 | 103 | 142 | 180 |
| 18 | 2,240 | 70 | 112 | 153 | 195 |
| 19 | 2,464 | 75 | 120 | 165 | 210 |
| 20 | 2,710 | 81 | 129 | 177 | 225 |
| 21 | 2,981 | 86 | 138 | 190 | 241 |
| 22 | 3,279 | 92 | 148 | 203 | 258 |
| 23 | 3,607 | 98 | 157 | 216 | 275 |
| 24 | 3,968 | 105 | 167 | 230 | 292 |
| 25 | 4,365 | 111 | 178 | 244 | 310 |
| 26 | 4,801 | 118 | 188 | 258 | 329 |
| 27 | 5,281 | 125 | 199 | 273 | 348 |
| 28 | 5,810 | 132 | 210 | 289 | 367 |
| 29 | 6,391 | 139 | 222 | 304 | 387 |
| 30 | 7,030 | 146 | 233 | 321 | 408 |

On rounds where special enemies spawn, they **replace** Gängers in the count rather than adding to it. The exception is the Foreman, who spawns *in addition* to the count.

### 1.4 Speed tiers
Player reference: **walk 4.5 m/s, sprint 6.8 m/s**.

| Tier | ID | Base move speed (m/s) | Anim set | Notes |
|---|---|---|---|---|
| Shambler | `shamble` | 1.3 | drag-foot walk, arms low | Reads as "safe" |
| Walker | `walk` | 2.0 | upright stagger | |
| Jogger | `jog` | 3.4 | loping, arms up | |
| Runner | `run` | 4.8 | full sprint, head forward | Slightly faster than player walk. You must sprint or shoot |
| Sprinter | `sprint` | 5.6 | frantic, low, limbs flailing | Still under player sprint. Must be telegraphed by audio (§2.1) |

Each spawn gets its tier's base speed with a ±5% random jitter, so a crowd never moves in lockstep.

### 1.5 Speed-tier mix by round (percent of Gänger spawns)
| Round | Shamble | Walk | Jog | Run | Sprint |
|---|---|---|---|---|---|
| 1 | 100 | – | – | – | – |
| 2 | 90 | 10 | – | – | – |
| 3 | 70 | 30 | – | – | – |
| 4 | 30 | 50 | 20 | – | – |
| 5 | 15 | 50 | 35 | – | – |
| 6 | 10 | 40 | 45 | 5 | – |
| 7 | 5 | 30 | 50 | 15 | – |
| 8 | – | 15 | 40 | 45 | – |
| 9 | – | 10 | 30 | 60 | – |
| 10–11 | – | 5 | 20 | 75 | – |
| 12 | – | 5 | 15 | 75 | 5 |
| 13–14 | – | – | 15 | 75 | 10 |
| 15–19 | – | – | 10 | 70 | 20 |
| 20–24 | – | – | 5 | 65 | 30 |
| 25–29 | – | – | 5 | 55 | 40 |
| 30+ | – | – | 5 | 50 | 45 (cap) |

Readability rules:
- At least 5% slow (walk or jog) zombies at every round, so a horde always has a "tail" for training.
- Never spawn more than 3 sprinters back-to-back. Insert a slower spawn after them.
- A crawler always moves at 0.8 m/s (±10%), whatever its tier.

---

## 2. Enemy types

### Data-ready summary
| id | HP formula | Speed | Melee dmg | Attack rate | Scrip (body/neck/head/melee) | Round gate | Spawn source | Weight / cap |
|---|---|---|---|---|---|---|---|---|
| `ganger` | `health(r)` | tier mix §1.5 | 50 | 1 swing / 1.2 s, 0.45 s windup | 50 / 60 / 100 / 130 (+10/hit) | r1+ | windows, ground-emerge, ceiling drops (Map 1 caverns) | default fill |
| `glasshide` | `health(r) × 1.5`, torso takes 50% | walk/jog only (2.0 / 3.4) | 60 | 1 / 1.4 s, 0.6 s windup | 75 / 90 / 150 / 180 | r15+ | ground-emerge only | 4% of spawns at r15, +0.5%/round, cap 12%. Max 3 active |
| `bellringer` | `health(r) × 0.6` (min 300) | 5.4 | 35 | 1 / 0.8 s, 0.3 s windup | 60 / 70 / 110 / 140 | special rounds only | fog portals | whole round. See §2.3 |
| `foreman` | `2500 × r × P_hp[p]` | 2.4 walk, 9.0 charge | 90 slam / 75 charge / 40 drill | see §2.4 | 500 on kill (+10/hit) | r12–14 first, then every 5–7 | dedicated boss spawn point | max 1 active (2 during Heartstorm) |
| `screamer` | `health(r) × 0.8` | 2.6 walk, 4.2 reposition | 30 claw | scream every 9–12 s | 150 / 160 / 250 / 280 | r20+ (Map 1) | ceiling/wall emerge | 1 per round at 35% chance, +5%/round, max 1 active |

`P_hp` (Foreman health by player count) = [1.0, 1.75, 2.5, 3.25].

**(§11 amendment)** Helvetia Works adds Basel Gänger variants, **Audit Rounds** with the **Repossessor**, and **the Underwriter** boss. See §5.

**Limb damage multipliers** (all humanoid enemies unless overridden):
| Hitbox | Multiplier | Scrip on kill |
|---|---|---|
| head | ×3.0 (×2.0 for pistols, ×4.0 for bolt rifles; set per weapon) | 100 |
| neck | ×2.0 | 60 |
| torso | ×1.0 | 50 |
| arms | ×0.8 | 50 |
| legs | ×0.8 | 50 |

---

### 2.1 Gänger (`ganger`)
**Soldier slang, short for *Wiedergänger* ("one who walks again").** These are the standard undead, built to be read instantly.

**Visual variants.** All variants share the same skeleton, hitboxes, and animation set. Only the mesh and material change.
| Variant ID | Who they were | Silhouette | Spawn weighting |
|---|---|---|---|
| `ganger_soldier` | Wehrmacht guard garrison, Volkssturm call-ups | Stahlhelm and greatcoat, wide at the shoulders. Some still wear rifle slings. | Map 0: 60%. Map 1: 30% |
| `ganger_miner` | Salt miners, the civilian workforce from before the war | Soft cap with carbide lamp (unlit, cracked lens), leather apron, hunched | Map 0: 15%. Map 1: 30% |
| `ganger_labstaff` | Projekt Wiederkehr technicians, orderlies | Long coat (stained grey, not white), rubber gloves, some wear gas-mask goggles pushed up | Map 0: 5%. Map 1: 15% (Lab Wing 40%) |
| `ganger_laborer` | Forced laborers (Polish, Soviet POW, others) | Thin, striped or patched work clothes, wooden-soled shoes, a stencilled ID tag on the chest | Map 0: 20%. Map 1: 25% |

**Common features.** Every Gänger has violet eye-glow (emissive, blooms in fog). Violet-amber hairline cracks run from the eyes and the hands, because Nachtglas spreads along the last nerves to fire. The cracks brighten as the round number climbs (a material parameter `crack_intensity = clamp(r/30, 0.1, 1.0)`), which also tells the player the round is getting harder.

**Audio tells.**
- Idle/chase: a wet, low "hum-groan" pitched to sit *under* the Nachtglas hum. They are droning at the same frequency as the stone.
- Each tier has its own vocal set: shamblers moan, joggers make clipped huffs, runners give a ragged rhythmic snarl, and sprinters give a high, rattling shriek played on spawn and every 2–3 s. The sprinter shriek is the mandatory readability tell.
- Attack windup: a short inhale-snarl 0.45 s before the swing.
- Barricade tearing: a board-creak and wrench, and a "rip" when a board comes off.

**AI state machine.**
```
SPAWN → (window spawn?) CLIMB/EMERGE → PATH_TO_BARRICADE → TEAR_BARRICADE → ENTER
      → (ground spawn) EMERGE → CHASE
CHASE ⇄ ATTACK
CHASE/ATTACK → STAGGER (on heavy hit, explosive, melee) → CHASE
any → CRAWL (on leg loss) → CRAWL_CHASE ⇄ CRAWL_ATTACK
any → DIE
```
- **Window spawns** path to their assigned barricade's *outside* node first. They tear one board every 1.2 s (0.8 s from round 15). When they reach the window, they target the nearest player.
- **Re-boarding.** A player repairing a board pushes a tearing zombie back into TEAR_BARRICADE.
- **Path update budget.** In CHASE, each zombie re-paths on a staggered timer: 0.25 s within 15 m of a player, 0.75 s at 15–40 m, and 2.0 s beyond that. A global budget caps re-paths at 6 per physics frame, and the queue is round-robin.
- **LOD.** Beyond 40 m with no line of sight, a zombie uses simplified movement (straight-line nav-point hops, no avoidance, animation at 15 Hz).
- **Pooling.** 32 instances are pre-instantiated per map and recycled on death.

**Crawler state rules.**
- A leg hitbox keeps its own damage pool of 35% of max HP. When the pool is exhausted, there is a 60% chance (or 100% from an explosive) to sever the leg, and the zombie goes to CRAWL. The remaining HP is kept.
- Explosive damage under 100% of remaining HP has a 40% chance to cause a crawler.
- Crawlers move at 0.8 m/s (±10%), deal 50 damage, and can't climb windows. They count as alive for round-end.
- Crawlers are what make "save a crawler" strategies possible. **They are never auto-culled.**

**Lore.** These are the people of Kaltenbrunn: guards, miners, the scientists' own staff, and the forced laborers who dug the deep galleries. Nachtglas keeps the last impulse running in dead tissue. For most of them that impulse was cold and hunger, and so they come.

---

### 2.2 Glasshide (`glasshide`)
**A Gänger that lay too long near raw Nachtglas, until the mineral grew through it.**

- **Gate:** round 15+. Make up 4% of spawns at r15, +0.5% per round, capped at 12%. Never more than 3 active at once.
- **HP:** `health(r) × 1.5`.
- **Armor:** the torso and upper-arm hitboxes are a crystal plate that takes **×0.5** damage. Head and legs take normal damage, and the head multiplier is ×3.0. Explosives ignore the plate (×1.0). The plate chips visibly (3 states) as it soaks damage, but its multiplier stays the same.
- **Movement:** walk or jog only (they are heavy). Never runner or sprinter.
- **Damage:** 60 per hit, with a slower 0.6 s windup. A hit applies a 0.5 s slow (−20% move speed) from glass shards.
- **Death:** shatters into a burst of violet glass (VFX plus a crystal-shatter sound). The shards are harmless to players. Shards hit within 1.5 m of a Gänger deal 50 damage to it, so a shatter can be a small bonus.
- **Silhouette:** asymmetrical. One shoulder is crowned with a jagged violet crystal cluster that juts above head height, so it reads at 30 m in fog. The chest is a glassy carapace. It walks with a heavy limp.
- **Audio tells:** a constant faint *glassy ringing* (tinnitus-like, spatialized) and crunching footsteps. It groans in a deeper register, with a "clink" layer.
- **AI:** Gänger state machine, except it never goes to STAGGER from bullets (only from explosives and melee). It can't become a crawler, because its legs are crystallized past the knee.
- **Lore:** Reinholt's early storage protocol kept failed test subjects in the raw-ore galleries. Some of them stopped moving and *grew*. Fasbender's notes call them "Verglaste" (the glazed). Soldiers just call them glasshides.

---

### 2.3 Bellringer (`bellringer`), special round
**Emaciated miners carrying lanterns. They answer the bell.**

**Special round rules**
- **First special round:** randomly round 5 or 6. **Interval:** a random 5–7 rounds after the previous special. Map data can disable special rounds (Map 0 has them).
- **Warning (6 s before the round starts):** the chapel bell tolls three times (on maps without a chapel, a distant bell). Ground fog rolls in, lights flicker and dim to 40%, and the round stinger is replaced with the "bell" stinger. The Operator delivers a line (`OPR_SPECIAL_BELL_xx`).
- **Spawn source:** **fog portals**, never windows. Each map defines 6–10 portal markers, and 3–4 are active per wave, chosen near players but never within 8 m of one.
- **Count:** `bell_count(r, p) = 6 × p + floor(r / 2)`, capped at 24 + 6p. They come in **packs of 3–5** (3 in solo r≤10, otherwise 4–5), spaced 3.5 s apart, with 18 active at most during a special round.
- **HP:** `health(r) × 0.6`, minimum 300. They are fragile but fast.
- **Speed:** 5.4 m/s (±5%) from the first special round on. That beats player walk (4.5) but loses to sprint (6.8), so you can outrun a pack only by committing to a sprint. They lunge-attack: a 2 m leap with a 0.3 s windup.
- **Damage:** 35 per hit.
- **Death:** they burst into harmless shards and their lantern clatters to the ground and goes out.
- **Reward:** clearing the round **guarantees a Resupply drop** at the location of the last kill. It doesn't count toward the 4-drops-per-round limit.
- **Silhouette:** tall, stick-thin, and bent almost double, with a swinging lantern held out front at waist height. The **lantern glow is the read**: a moving amber light in fog means a Bellringer. They have no helmet, a gaunt bald head, and a violet glow inside the ribcage that shows through the torn shirt.
- **Audio tells:** a lantern-chain *jingle* on every step, a hollow wheezing "hhhaaa" call-and-response between pack members, and a sharp bell-like *ting* on lunge. The fog portal opens with a reversed bell swell.
- **AI:** SPAWN (from portal) → CHASE → LUNGE/ATTACK → DIE. They skip barricades, never stagger from bullets, and never crawl (leg loss = death).
- **Lore:** the bell is the facility's *resonance alarm*. Miners in the deep galleries in 1943 were trained to drop tools and walk to the chapel when it rang, because the Nachtglas was "breathing" and the galleries were about to fill with gas. Most never made it. The impulse they died with is *walk toward the bell, bring the light*. Now the bell rings by itself.

---

### 2.4 The Foreman (`foreman`), Map 1 boss
**Obersteiger Gustav Mahlknecht, the mine overseer who ran the forced-labor galleries, fused with his own equipment.**

- **Gate:** first appears on a random round from 12–14. After that, every 5–7 rounds (never on a Bellringer round). He spawns in addition to the round count.
- **Spawn:** a dedicated "rock-burst" spawn in the zone *adjacent* to the highest-population player zone, never the player's own zone. The wall cracks with a 4 s audio tell, then bursts.
- **HP:** `2500 × r × P_hp[p]` (r12 solo = 30,000). **Weak point:** the glowing Nachtglas drill core on his right arm takes **×3.0**. His head takes ×1.5 (he wears a riveted mining helmet). The body takes ×1.0, and explosives deal ×1.0 to the body.
- **Movement:** a ponderous 2.4 m/s walk. **Charge:** 9.0 m/s.
- **Attacks:**
  | Attack | Tell | Damage | Cooldown | Notes |
  |---|---|---|---|---|
  | Drill jab | Drill spins up (0.5 s whine) | 40 + knockback | 2.5 s | Melee, 2.5 m reach |
  | Ground slam | Raises the drill overhead, 0.9 s | 90 in a 4 m radius, 45 at 4–6 m | 8 s | Knocks the player down for 0.6 s. Can be jumped over at the edge |
  | Charge | Plants his feet, scrapes the chain, roars, 1.2 s | 75 + big knockback | 12 s | Straight line up to 18 m. Hitting a wall stuns him for 2.5 s (core exposed, ×4 damage) |
  | Chain whip | Chain rattles behind him | 30 + 1 s slow | 6 s | Used when a player is 3–7 m away behind him (anti-circle-strafing) |
- **Drops:** **500 Scrip** to every player on kill, plus a guaranteed random power-up (counts toward the cap). On specific quest steps, he drops a quest item: the **Overseer's Key** (Easter egg step 4: killed inside the Salt Chapel while the Bell is lit).
- **Silhouette:** 3.2 m tall and massively top-heavy. His right arm is a pneumatic drill with a pulsing violet core, and his left fist is wrapped in an ore chain that drags behind him (a sound and a visual trail). He wears an overseer's peaked cap welded into a miner's helmet and a leather greatcoat. You can spot him in silhouette at any range.
- **Audio tells:** a pneumatic hiss and clank with every step, the *chain drag* (looping, spatialized, audible from 40 m), a guttural German shouted cadence (shift-count orders: "*Schicht! Weiter!*") distorted through Nachtglas resonance, and a unique boss music layer while he's alive.
- **AI states:** `EMERGE → STALK → (select attack by range/cooldowns) → ATTACK → RECOVER → STALK`, plus `STUNNED` (after a wall hit or a weak-point burst of 15% max HP within 3 s) and `ENRAGED` below 30% HP (+25% speed, −30% cooldowns). He ignores barricades and smashes small props.
- **Lore:** Mahlknecht drove the forced-labor shifts in the deep galleries and kept a tally of "productive units." When the galleries flooded with Nachtglas resonance in 1943, he refused to evacuate the laborers and locked the gallery gates. Reinholt used his body as a test of large-scale reanimation and *integration with machinery*. He kept his last impulse: keep them working.

---

### 2.5 The Screamer (`screamer`), Map 1, rare
**Schwester Ilse Brandauer, a field nurse from the facility infirmary, saturated with Nachtglas.**

- **Gate:** Map 1, round 20+. Each round there's a 35% chance (+5% per round, capped at 75%) that one spawns, partway through the round (30–70% of the count spawned). Max 1 active.
- **HP:** `health(r) × 0.8`. The head takes ×3.0 as usual.
- **Behavior:** she keeps a 10–16 m distance from the nearest player and repositions between cover nodes (4.2 m/s). She claws only if cornered (30 damage).
- **Scream:** a 1.5 s windup (she inhales and her throat glows violet), then a scream in a 20 m line-of-sight cone. Effects on each affected player last 3.0 s:
  - Screen distortion (chromatic aberration + radial blur, scaled by the accessibility "reduce screen effects" setting)
  - Audio muffled and low-passed, with tinnitus
  - −35% move speed, ADS disabled
  - Cooldown 9–12 s. Breaking line of sight during the windup avoids the scream.
- **Death:** a choked final note that rings out and fades, plus a small violet pop. **Scrip:** 150/160/250/280.
- **Silhouette:** a nurse's cape and a winged wimple-style headdress (rigid and triangular, the read). She drifts too smoothly, almost gliding, and her jaw is unnaturally long. She is lit from within at the throat.
- **Audio tells:** soft, constant *humming of a lullaby* (the "Lanterns Down Below" melody, played wrong), so players learn to dread a melody. The windup is a sharp intake of breath and a rising tone.
- **AI states:** `EMERGE → REPOSITION ⇄ SCREAM_WINDUP → SCREAM → REPOSITION`, plus `FLEE` (when a player is within 5 m) and `CORNERED_ATTACK`.
- **Lore:** Ilse nursed both soldiers and prisoners, and she kept singing to patients long after it was useless. Reinholt dosed infirmary staff to test whether Nachtglas could carry *voice*, because she wanted to know if it could carry Liesl's. In Ilse the resonance found a voice and amplified it. Her scream is the Nachtglas hum given a throat.

---

## 3. Spawning rules summary
- **Spawn points** belong to **zones**. A spawn point is active only if its zone is open and is the player's zone or one adjacent to it. Map data defines adjacency.
- **Window spawns** are preferred (70%) while the player is in a zone with intact windows. Ground-emerge spawns (30%) add variety and make camping less reliable.
- **Special enemies** (Glasshide, Screamer) roll at spawn time. A roll that would exceed a cap falls back to a Gänger.
- **Co-op:** spawns are weighted toward the player with the fewest zombies chasing them, so one player can't hold all the aggro.
- **The debug console** can spawn any type: `spawn <id> [count]`, `set_round <n>`, `special_round now`, `foreman now`.

## 4. Data file shape (`data/enemies.tres`, one `EnemyData` resource per type)
```
id: StringName
display_name: String
health_mult: float          # × health(r)
health_override_expr: String # e.g. foreman "2500*r*php"
min_health: float
speed_tiers_allowed: Array[StringName]
melee_damage: int
attack_interval: float
attack_windup: float
hitbox_mults: Dictionary    # {head:3.0, neck:2.0, torso:1.0, arm:0.8, leg:0.8}
armor_hitboxes: Dictionary  # glasshide {torso:0.5, arm_upper:0.5}
scrip: Dictionary           # {hit:10, body:50, neck:60, head:100, melee:130}
round_gate: int
spawn_weight_start: float
spawn_weight_per_round: float
spawn_weight_cap: float
max_active: int
can_crawl: bool
can_stagger_from_bullets: bool
spawn_sources: Array[StringName]  # window, ground, ceiling, portal, boss
```

---

## 5. Helvetia Works enemies (§11 amendment)

Helvetia Works (`docs/gravelight/MAPS.md`) uses the canon round scaling in §1 unchanged: same health, count, cadence and speed mix.
- **Bellringers, the Foreman and the Screamer don't appear** on this map.
- The map's special round is the **Audit Round**, its boss is **the Underwriter**, and its Gängers are Basel locals.
- Glasshides follow §2.2 and arrive in crates (§5.1).
- New IDs: `ganger_dockworker`, `ganger_assembly`, `ganger_bargeman`, `ganger_patrol` (variants of `ganger`), `repossessor`, `underwriter`.
- New item: `recall_tag`.

### Data-ready summary (Helvetia Works)
| id | HP formula | Speed | Melee dmg | Attack rate | Scrip (body/neck/head/melee) | Round gate | Spawn source | Weight / cap |
|---|---|---|---|---|---|---|---|---|
| `ganger` (Basel variants) | `health(r)` | tier mix §1.5 | 50 | as §2.1 | 50 / 60 / 100 / 130 (+10/hit) | r1+ | windows, river-climb (Quay), ground | default fill |
| `glasshide` | as §2.2 | as §2.2 | 60 | as §2.2 | as §2.2 | r15+ | **crate-burst** (Quay KALTENBRUNN crates) + ground | as §2.2 |
| `repossessor` | `health(r) × 1.2` (min 600) | 4.2 glide, 9 m Lien Dash | 40 + **Seize** | 1 / 1.4 s, 0.5 s windup | 150 / 170 / 250 / 280 (+10/hit) | Audit Rounds (and Underwriter summons) | beam drop-pods at audit markers | see §5.2 |
| `underwriter` | `3000 × r × P_hp[p]` | 2.0 walk, 7 m Reassign blink | 45 base × **assessment** | see §5.3 | 750 to every player on kill (+10/hit) | r15–17 first, then every 6–8 | beam descent | max 1 active |

---

### 5.1 Basel Gängers (`ganger` variants)

**These are the people of the Helvetia district.** Hours ago they were alive. On the night of 17–18 March 1945, retention substrate leaked out of the fulfillment barge's fold as a fine violet mist and settled over the factory, the quay and the street. The night shift, the dockers and the bargemen breathed it. Most of them still wear their name badges. The Helvetia staff list in Vendelin's Office (Intel) names every one. **Vendelin's own night shift** spawn as six unique, named `ganger_assembly` Gängers (one each per match, from round 2; name badges legible within 3 m): **Brodbeck, Gysin, Schaub, Stöcklin, Wirz, Thommen.** Vendelin's lines about them are the Ch. 5 writer's (`gl.qp.vendelin.*`).

Same skeleton, hitboxes, animation set, AI and stats as §2.1. Only the mesh and material change, plus the crack pattern: **Basel cracks start at the mouth and nostrils** (they *inhaled* it), unlike Kaltenbrunn's eyes and hands. This is a deliberate readability change, so a player can tell where they are from a single Gänger.

| Variant ID | Who they were | Silhouette | Spawn weighting (Helvetia Works) |
|---|---|---|---|
| `ganger_dockworker` | Rhine port dockers of the Basel harbour | Flat cap, leather shoulder pad, a cargo hook still in one fist (cosmetic, same swipe) | 35% |
| `ganger_assembly` | Helvetia Automaten AG night-shift staff | Grey dustcoat with the Helvetia shield patch, sleeve garters, some in white cotton QA gloves, one in five with a clipboard | 30% (Assembly Hall 50%) |
| `ganger_bargeman` | Rhine bargemen tied up at the quay | Oilskin coat, sou'wester, coil of rope over a shoulder, soaked and dripping | 20% (Quay 45%). Can use **river-climb** spawns |
| `ganger_patrol` | A Swiss border-guard night patrol on the riverbank | Long grey-green greatcoat, peaked cap or steel helmet, empty rifle sling. No national insignia is modelled | 15% |

**River-climb spawns** (Quay only): two points on the quay wall where bargemen haul themselves up out of the Rhine. They behave like a window with **no boards**: the zombie climbs for 2.2 s (vulnerable, head exposed) and then enters CHASE. They are active from round 3. In the rain, a wet slap and a chain-rattle play 1 s before each climb as the tell.

**Crate-burst spawns** (Quay only, round 15+): Glasshides break out of stacked Helvetia shipping crates stencilled **KALTENBRUNN**. The crate lid buckles with a 3 s glassy-ringing tell, then bursts. There are 3 crate stacks with 2 bursts each per match. Burst crates stay open as cover.

**Audio tells:** as §2.1, plus a **wet, rattling breath** layer (they're breathing the mist). The hum-groan sits under the barge's own drone, a fifth above Kaltenbrunn's 19 cps: they hum in the barge's key, not the mine's.

**Lore line for the Archive:** *"They were on shift. Somebody has to be."*

---

### 5.2 Audit Rounds and the Repossessor (`repossessor`)

**The Audit Round** replaces the Bellringer round on Helvetia Works.

**Special-round rules**
- **Cadence:** the first Audit comes on round 5 or 6 (random), then every 5–7 rounds, using the same cadence logic as §2.3. It is never on the round the Underwriter arrives. If they would collide, the Audit moves one round later.
- **Warning (6 s before the round starts):**
  - **The barge's chime** sounds: three falling notes, like a shop door's bell slowed to a dirge, on the clean `BARGE` channel. The chime is tuned to the substrate, so **every Gänger on the map stops for 1.0 s and looks up** (a free window, and the tell).
  - Violet searchlights sweep down from the barge across every outdoor zone. Interior lights drop to 60% and take a faint violet cast.
  - The round stinger is replaced by the Audit stinger (§5.4). The Operator plays a `gl.helvetia.opr.audit_warn.*` line (VO_SCRIPT.md §9.4).
- **Composition:** an Audit Round has **both** Gängers and Repossessors. The Repossessors need something to repossess.
  - **Gängers** run at **60%** of the normal `count(r, p)`, with the usual spawn sources.
  - **Repossessors:** `repo_count(r, p) = 3 + 2p + floor(r / 5)`, capped at `10 + 3p`. They drop in **pairs** every **8 s**, at 2–3 active **audit markers** out of the map's 8 (never within 8 m of a player).
  - **Max active Repossessors:** 4 solo, 6 in co-op. Counted inside the global cap of 24.
- **Round end:** every Gänger and Repossessor is cleared.
- **Reward:** a guaranteed **Resupply** at the last Repossessor kill. It doesn't count toward the 4-drop cap.
- **Recall Tags:** until the team has inserted 3 Recall Tags at the Loading Dock's returns desk (MAPS.md, Cargo-Lift Beam), **every** Repossessor kill drops one `recall_tag` (a violet enamel token stamped *RÜCKRUF*, "recall"). Tags are shared in co-op and shown on the parts strip. After that, Repossessors stop dropping them.

**The Repossessor**

**A Darkmatter collections robot, here to recover "inventory": you, and your dead.**

- **HP:** `health(r) × 1.2`, minimum 600.
- **Hitboxes:**
  | Hitbox | Multiplier | Notes |
  |---|---|---|
  | Scanner lens (head) | ×3.0 | a single round lens on a gooseneck; headshot kill pays the head value |
  | Inventory hopper (back) | ×2.5 | the glowing slot on its back; hitting it from behind is the skill shot |
  | Chassis (torso) | ×0.75 | armor. `armor_piercing`, Buzzkill, explosives and electrical damage (Overclock, Super Sprocket) count it as ×1.0 |
  | Arms / legs | ×0.8 | |
- **Movement:** a hovering glide at **4.2 m/s**, under player walk only with Marathon Malt. **Lien Dash:** a 9 m straight dash toward its current target every 6 s. Tell: a 0.6 s rising servo whine and its lens turning amber.
- **Who it hunts: players AND zombies.** Every 0.5 s it scores each candidate target and picks the highest. It only switches when a new score beats the current one by 30%.
  ```
  score = value / max(distance_m, 2)
  value(player)   = 1.0 + held_scrip / 1000      # downed players: 0 (ignored)
  value(ganger)   = 2.0                          # "retained inventory", recall priority
  value(glasshide)= 3.0
  value(boss / other repossessor) = 0
  ```
  In practice, a Repossessor near a crowd of Gängers goes for the Gängers first, and a rich player standing close is a magnet. **Gängers ignore Repossessors**: they never attack them and path around them.
- **Recall (vs zombies):** it clamps a zombie for **1.5 s** (both stationary) and folds it out of existence in a violet seam.
  - The zombie **counts as killed** for round progress. **No Scrip** is paid to anyone.
  - Each recall **heals** the Repossessor by 10% of its max HP.
  - While it is recalling, the Repossessor is **exposed and takes ×1.5 damage** from all sources. That's the moment to shoot it, or to let it thin the horde and pay for that with Scrip.
- **Lien Clamp + Seize (vs players):** a melee clamp for **40 damage**, 0.5 s windup, 1.4 s cooldown, 2.2 m reach.
  - On hit it **seizes 10% of the victim's held Scrip** (minimum 0, maximum 300) into its hopper. The HUD shows `SEIZED −ǂ240` in violet and a small hopper icon over the Repossessor.
  - Seized Scrip is **returned in full** to each owner when the Repossessor dies, whether it's killed, returned (The Return Policy), or caught in a Blackout. The killer also gets a **+100** bonus.
  - Because the round can't end with a Repossessor alive, seized Scrip is never lost, only withheld. *"Spend it or it gets repossessed"* is a tempo pressure, not a tax.
- **Stagger:** never from bullets. It staggers from explosives, melee, Overclock bursts at e ≥ 0.75, and Grav Grenade pops. It can't crawl.
- **Death:** it folds at the joints and its hopper bursts in a shower of tally tokens (the seized Scrip, visibly). It drops a Recall Tag while tags are still needed.
- **Silhouette:** 2.4 m tall, narrow and stooped like a bailiff, in **violet enamel with amber hazard cracks**. It has one long clamp arm and one short arm holding a stamp. The rectangular hopper on its back has a glowing slot. A small stencil on the hopper reads **"NOBODY CANCELS."** The squad can see it and never comments on it. Its outline is unmistakable at 40 m: the gooseneck lens bobs as it glides.
- **Audio tells:** a small version of the barge's three-note chime on drop-in. A servo whine on the move. Flat, polite synthetic speech with a delivery-van reversing beep under every line (`fp.c5.repo_*`, written in The Fine Print Ch. 5 script; positional `WORLD` channel). A cash-drawer *clunk* on every recall and every seize, and a coin-cascade on death.
- **AI states:** `DROP_IN → SCAN ⇄ PURSUE → (LIEN_DASH) → RECALL | CLAMP → RECOVER → SCAN`, plus `EXPOSED` (during RECALL) and `STAGGER`.
- **Lore (players only):** collections units of Darkmatter's Sol-3 retention audit. To Darkmatter, the Gängers are retained customers to be recalled for "quality review," and the living are delinquent accounts. What the squad makes of them follows The Fine Print Ch. 5 script §0.3 (to Dutch they're repo men, to Deacon "the Collectors").

---

### 5.3 The Underwriter (`underwriter`), Helvetia Works boss

**Darkmatter's risk-assessment enforcer: a towering, ledger-faced machine that prices everything it looks at.** It has come to recall Vendelin under Clause 0, and it will audit anyone in the way. *(It is also the main boss of The Fine Print. This entry is its Gravelight-rules zombies form.)*

- **Gate:** first appears on a random round **15–17** (never an Audit round), then every **6–8** rounds. Clause Zero step 6 summons it on demand (EASTER_EGGS.md §7). Max 1 active. It spawns *in addition* to the round count, like the Foreman.
- **Advance warning, which is the point:** one full round before it arrives, the Operator announces it (`gl.helvetia.opr.underwriter_scheduled.*`, "Your audit has been scheduled for next round"). A violet ledger stamp appears beside the Scrip counter. **Spend before it arrives.**
- **Arrival:** it arrives on a chime and the scratch of a pen nib. It descends the cargo-lift beam onto the open floor of whichever of the Assembly Hall, the Quay or the Barge deck is nearest the most players. 6 s of beam-light tell, then it lands with a filing-cabinet *slam*.
- **HP:** `3000 × r × P_hp[p]` (r15 solo = 45,000). `P_hp` = [1.0, 1.75, 2.5, 3.25].
- **Hitboxes:** **ledger face** (the tall DARK-GLASS™ pane of scrolling figures) **×3.0 while it is Assessing** (the columns stop and flare amber) and ×1.0 otherwise. Body ×1.0. Arms ×0.5 (armored). Explosives ×1.0 body.

**The pricing tiers.** At the moment each hit lands, the Underwriter checks the victim's **held Scrip S** and prices them into one of five tiers. The tier boundaries are locked with The Fine Print Ch. 5 script: **500 / 2,500 / 10,000 / 25,000**.

| Tier | Held Scrip S | **assessment** (damage TO the player ×) | Stamp (base 45) | **valuation** (damage BY the player ×) | HUD price tag |
|---|---|---|---|---|---|
| 0 | < 500 | ×1.00 | 45 | ×1.25 | grey "UNASSESSED" |
| 1 | 500–2,499 | ×1.25 | 56 | ×1.10 | green |
| 2 | 2,500–9,999 | ×1.75 | 79 | ×1.00 | amber |
| 3 | 10,000–24,999 | ×2.50 | 113 | ×0.80 | red |
| 4 | ≥ 25,000 | ×3.50 | **158** | ×0.60 | violet "WRITTEN OFF" |

```
tier(S)     = 0 if S<500, 1 if S<2500, 2 if S<10000, 3 if S<25000, else 4
damage_taken_by_player      = round(base_damage × ASSESS[tier(S)])     # ASSESS = [1.0, 1.25, 1.75, 2.5, 3.5]
damage_dealt_to_underwriter = weapon_damage × VALUE[tier(S)]           # VALUE  = [1.25, 1.1, 1.0, 0.8, 0.6]
# An Omega weapon cannot be priced: hits from an *_om weapon always use VALUE = 1.25,
# and the Assessment Beam cannot lock a player whose held weapon is an Omega weapon.
```

- **What it means:**
  - A player holding under 500 takes base damage (a Stamp downs them in 3 hits, 6 with Ironhide) and hits it 25% harder.
  - A player hoarding 25,000+ is one-shot-downed by a Stamp without Ironhide (2 hits with it) and deals 40% less.
  - **Spending Scrip mid-fight** (ammo, perks, traps, the crate, Omega) drops your tier immediately, because the check happens on each hit. Scrip earned during the fight can push you up a tier.
  - **An Omega weapon can't be priced.** That's why Clause Zero step 5 (the Omega Forge) comes *before* the audit (EASTER_EGGS.md §7).
- **HUD:** as its gaze passes, **violet price tags bloom** over players, enemies and objects (`docs/FINEPRINT_LORE.md` §3.4). Each player's own tag and a ledger stamp by their Scrip show their tier (0–4, colors as in the table). **Fine Print Fernet** holders see the exact multiplier (WEAPONS.md §20.1).
- **Attacks** (base damage is multiplied by the hit player's `ASSESS[tier(S)]`):
  | Attack | Tell | Base damage | Cooldown | Notes |
  |---|---|---|---|---|
  | **Stamp** | Raises its stamp-head arm, 0.8 s | 45 + 0.5 s knockdown | 3 s | Melee, 3 m reach |
  | **Assessment Beam** | The ledger face's columns stop and flare, and an amber scan-line locks onto the **richest player in line of sight**, 1.5 s | 10 per tick × 10 ticks (100 total over 1 s) | 10 s | Marks the target **Under Review** for 8 s: their next Stamp is ×1.5. **The face is open (×3) during the whole tell and beam.** Breaking line of sight cancels it. |
  | **Lien** | Flicks its pen-nib arm, 0.6 s | 30 + 1.5 s root | 8 s | A thrown ink-clamp, 18 m range |
  | **Actuarial Table** | Floor tiles (2 × 2 m) in a 12 m radius light amber in a pattern; 1.2 s | 60 per tile hit | 14 s | One tile in three is always dark (safe). The pattern is drawn from 6 authored layouts. |
  | **Repossession Order** | Raises its pen; small barge chime | — | 25 s | Summons 2 Repossessors (max 4 alive from orders). They follow §5.2 targeting. |
  | **Reassign** | Folds out of sight, 0.4 s violet seam | — | 15 s | A 7 m blink to a point behind the player farthest from it (anti-camping) |
- **Phases: three.** **Phase 1, Assessment** (from arrival). Phase 2 and Phase 3 start at the HP thresholds below, or, during the Clause Zero audit, at **1:00 and 2:00** of the 3:00 timer, whichever comes first.
  - **Phase 2, Second Opinion** (below 50% HP): the columns scroll faster, all cooldowns −25%, and the Actuarial Table grows to 16 m.
  - **Phase 3, Final Assessment** (below 20%): +20% move speed, and Assessment Beam targets the two richest players at once.
- **Withdrawal ("files its report"):** if it isn't destroyed within **4:00** of landing (**3:00** during Clause Zero step 6), it stamps the floor, rises back up the beam, and leaves. It comes back on its next scheduled round with full HP. During Clause Zero, surviving to the timer **completes** the step (EASTER_EGGS.md §7). This rule guarantees no stall and no hard fail.
- **Drops:** on destruction, **750 Scrip to every player**, a guaranteed random power-up (counts toward the cap), and a **Darkmatter ledger page** Intel (`INT_HW_UW_*`, flavor) the first time per profile.
- **Movement:** 2.0 m/s, deliberate. It never runs. It ignores barricades and doors' collision (it *steps over* the factory's half-walls).
- **Silhouette:** 4.0 m tall, gaunt and narrow-shouldered, built like a lectern (or a filing cabinet) that learned to walk. Its **face is a ledger**: a tall pane of DARK-GLASS™ where columns of brass-lit figures scroll endlessly upward. Two long arms end in a stamp-head and a fountain-pen nib. A brass rubber stamp inked violet hangs at its hip and reads **WRITTEN OFF**. Coat-tails of punched paper tape trail behind it. Nothing on the map is shaped like it.
- **Audio tells:** a pen-nib scratch on every step. An adding-machine *crank-ka-chunk* and a cash-register *chk* each time it re-prices someone, which happens whenever a player's Scrip changes by ≥ 500 near it, so you can *hear* your price change. A filing-drawer slam on landing. **It speaks** on the `BARGE` channel in itemized valuations ("Assessed." "Depreciated." "Written off."). Those lines are `fp.c5.uw_*` in The Fine Print Ch. 5 script. The Operator comments on its findings too (VO_SCRIPT.md §9.6).
- **AI states:** `DESCEND → ASSESS_ALL (2 s, sets HUD stamps) → STALK ⇄ SELECT_ATTACK → ATTACK → RECOVER`, plus `REASSIGN`, `PHASE_SHIFT`, `FILE_REPORT` (withdraw), `DESTROYED`.
- **Lore:** brief §10.1 and `docs/FINEPRINT_LORE.md` §3.4. In Gravelight the squad never learns what it is. Their names for it belong to the Ch. 5 script.

---

### 5.4 Helvetia Works audio stingers (enemy-related)
- **Audit warning (6 s):** the three falling notes of the barge chime on the clean `BARGE` channel, followed by a long low pipe-organ pedal note from the Jingle Room's Harmonium, the factory "answering." Ambient score cuts to the barge drone.
- **Audit round end:** a single clean chime, then the Harmonium resolving the pedal note to a major chord, which is the only major-key round end in Gravelight.
- **Underwriter arrival:** a typewriter carriage-return *ding*, 2 s of silence, then the boss layer (adding-machine percussion, low brass, a choir singing numbers).

---

### 5.5 Spawning rules (Helvetia Works additions to §3)
- Spawn points belong to Helvetia zones (`HW_*`, MAPS.md). The same active-zone rule applies.
- **Audit markers:** 8 per map (2 Dock, 2 Assembly, 2 Quay, 2 Barge), and 2–3 are active per drop.
- **Barge:** after the beam is open, the Barge's 4 "returns chute" spawns (ground-type) are active whenever a player is on the Barge.
- **Debug:** `audit now`, `underwriter now`, `spawn repossessor [n]`, `give recall_tag [n]`, `assessment show` (overlays every player's S, assessment and valuation).

### 5.6 Data file additions (`EnemyData`)
```
# repossessor
target_values: {player_base: 1.0, player_per_1000_scrip: 1.0, ganger: 2.0, glasshide: 3.0}
recall_time: 1.5
recall_heal_pct: 0.10
exposed_mult: 1.5
seize_pct: 0.10
seize_max: 300
kill_bonus_scrip: 100
# underwriter
tier_bounds: [500, 2500, 10000, 25000]
assess_mult: [1.0, 1.25, 1.75, 2.5, 3.5]
value_mult: [1.25, 1.1, 1.0, 0.8, 0.6]
omega_value_mult: 1.25      # Omega weapons cannot be priced
phase_hp: [0.5, 0.2]
audit_phase_times_s: [60, 120]
withdraw_time: 240        # 180 during map_hw_clausezero step s6
```
