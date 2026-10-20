# BOLT & SPROCKET — Redesigned Enemies & Bosses (`BS_ENEMIES.md`)

This is the design spec for every B&S enemy and boss in TERMS & CONDITIONS. It implements brief §7, plus the boss rows of §6 and the Retention Specialist line from §5.4. The weapon and status references point to `docs/BS_WEAPONS.md`.

**Sources.**
- `data/bs_source/ENEMY_DEFS.json` and `ENEMY_DEFS_V9.json` give HP, speed, damage, drops, flags and the `dieSfx` source.
- `reference/bs_web/index.html` gives the behaviour:
  - Factories `makeScrapMutt` … `makeCouponCrier` (L5839–6226), `spawnEnemy` (L6257) and `updateEnemies` (L6382–6818).
  - Bosses: `updateAlgorithm` L6840, `updateCompostKing` L6900, `updateGreeter` L6968, `updateRepoTron` L7072, `updateRetention` L7221, `updateMiniBoss` L7337, `updateFinalBoss` L7421.
  - Support: `addBeam`, `addShockwave`, `updateHazards` (L7536–7608), `bossStart`, `bossBarUpdate`, `bossBreak` (L7610–7648).
- Line IDs come from `data/bs/story/lines_index.json`.

**Baseline rule.** The original HP, speed, damage and drops are the starting tuning. Where the defs leave a number out (turrets and flyers have no `dmg` field), the number in the code is quoted and used.

**Units.** HP and damage are in hit points (Bolt has 100). Speed is in m/s. Times are in seconds.

---

## 1. Global rules

### 1.1 Carried over from the web build

| Rule | Original (source) | Remake |
|---|---|---|
| Chaser aggro | Chases within 14 m (or once hit); leashed to 9 m from home (`opts.range`, default 9) | Kept. Arena and boss adds get a 30 m leash, as in the source. |
| Pounce | Within 5 m (not under 1.4 m): a 0.32 s crouch telegraph and growl, then a 0.38 s leap in a 1.5 m arc; 1.4 s contact cooldown | Telegraph raised to **0.45 s** (rule §1.2). The leap is unchanged. |
| Contact damage | Non-pouncers hit on touch; 1.1 s cooldown | Kept |
| Turret | Tracks within 24 m, fires within 20 m every 2.2 s: a 12-damage shot at 11 m/s, with the muzzle glowing for the last 0.55 s | Kept |
| Ambush turret | Hidden until the player is within 11 m, then rises for 0.55 s | Kept |
| Legacy flyer shot | Within 17 m every 2.4 s: 10 damage at 10 m/s, with the gun glowing for the last 0.45 s | Kept for flyers without a bespoke attack |
| Heavy | `heavy: true` → can't be launched or gravity-clumped, thumps the ground every 0.55 s while walking | Kept; heavies also need 2.0 frost to freeze |
| Plated | Guns ping off ("ARMORED"); each mallet hit strips one plate (dealing 40% chip damage) | Kept. Buzzkill, Clearance Rack and Late Fee stagger are the new gun paths (BS_WEAPONS §4). |
| Kill drops | `def.drops` bolts plus anything stolen; a 22% chance of a purple or cyan ammo orb | Kept |
| Hit flash | 0.12 s white flash | Kept |
| Combo stun | A mallet finisher stuns non-boss enemies for 0.8 s | Kept |
| NG+ | HP ×1.6 (bosses ×1.4); damage to Bolt ×1.35; 22% roster bleed on Scrapheap, Rustvane and Core Foundry | Kept. Roster bleed extends to every planet (§5). |
| Rim shell | Every non-prop enemy gets a rim shell (`addRimShell`) | Kept. Elites get a coloured, pulsing rim (§1.3). |

### 1.2 Telegraph contract (new, hard rule)

Every attack goes through a **TELEGRAPH** state before **ATTACK**, with three channels: a **pose**, a **sound** and a **light**.

- Anything that deals **14+ damage**, applies a control effect (freeze, grab, LIEN, steal, blind), or is a boss attack must telegraph for **at least 0.4 s**.
- Light chip attacks (under 14 damage, no control) still need a pose and sound, and at least 0.25 s.
- Ground-targeted attacks also draw a **ground decal** (the original `telegraphRing`) for the full telegraph time.
- Attacks in the source that were too fast are listed per enemy and raised. Most were 0.16–0.32 s.

### 1.3 Elites

Elites appear:
- in **NG+** (25% of non-boss spawns), and
- in the campaign, for any enemy type on a planet later than its home planet (10% of those spawns).

| Elite rule | Value |
|---|---|
| Read | A coloured rim shell that pulses at 1 Hz, plus a small gold "PREMIUM" tag on the health bar |
| HP | ×1.8 |
| Drops | ×1.5 (rounded up), and a guaranteed ammo orb |
| Speed | Unchanged unless the trick says otherwise |
| Trick | One new behaviour per enemy (listed per enemy) |
| XP | +25 to the weapon that kills it (BS_WEAPONS §2.1) |

---

## 2. AI architecture

### 2.1 Archetypes (shared with Gravelight's enemy framework, brief §1)

| Archetype | Navigation | Enemies |
|---|---|---|
| **chaser** | `NavigationAgent3D` with ground avoidance; slope-aware steering (the source contoured around faces steeper than 1.2 m per 1.6 m) | Scrap Mutt, Ambassadog, Lifeguard Bot (heavy), Slag Golem (heavy), Meter Maid, Premium Waker, Picket Corn (neutral) |
| **turret** | Static; aims a head bone (or the whole body when there's no head) | Tinker Turret, HOA Enforcer, Popsicle, Spore Lobber, Zoning Board pylons |
| **flyer** | 3D steering around an anchor (the player within ~18 m, otherwise home) with an altitude band | Vulture Drone, Selfie Sentry, HR Drone, Weld Wasp, Surge Drone, Frost Peddler, Review Bomber |
| **burrower** | Navmesh underground with a visible surface trail; surfaces to attack | Chillsplitter, Lien Crawler |
| **stalker** | Chaser movement gated by perception rules (seen or unseen, cloaked or revealed) | Mannequin, Gloomstalker |
| **support** | Keeps a stand-off distance behind allies; buffs or commands | Pollinator, Coupon Crier, Middle Manager |
| **ambusher** | A turret-like disguise that becomes a chaser once triggered | Return Desk Mimic |
| **prop** | No AI; destructible | Statue |
| **boss** | A bespoke state machine on the shared boss base (§4.0) | All 8 bosses |

The archetype is data (`arch` in the def). Each enemy's quirks are behaviour **modules** added on top: `pounce`, `ambush`, `dive_steal`, `flash_burst`, `lob`, `plated`, `paper_homing`, `swarm`, `surge`, `freeze_bolt`, `cloak`, `burrow`, `buffer`, `rally`, `stalker_los`, `spore`, plus the new `lien`, `star_bomb`, `zone_link`, `pod_hatch`, `neutral_faction`, `review_fire` and `mimic`. That mirrors the original flag style (`pounce: true`, `lob: true`, …).

> **Source note.** Five v9 flags were declared but never implemented in v14: `surge`, `freeze`, `cloak`, `burrow` and `buffer`. Surge Drones, Frost Peddlers and Pollinators actually used the legacy flyer shot. Chillsplitters and Gloomstalkers were plain pouncers. The remake implements all five as described below.

### 2.2 Base state machine (every non-boss)

```
SPAWN → (ambush/burrow/disguise?) HIDDEN → REVEAL → ALERT
      → IDLE/PATROL → ALERT (sees player within aggro radius, or is damaged)
ALERT → POSITION (chaser: CHASE · turret: TRACK · flyer: ORBIT · support: HOLD_BACK)
POSITION ⇄ TELEGRAPH → ATTACK → RECOVER → POSITION
any → STATUS  (FROZEN · DANCING · ROOTED · LAUNCHED · STUNNED · CLUMPED · ACQUIRED)
STATUS → POSITION (when the status ends)
any → STAGGER (finisher, Collections, Late Fee full-interest on a heavy) → POSITION
POSITION → LEASH_RETURN (beyond leash and not aggro'd) → IDLE
any → DIE (dieSfx, chunkDeath, drops)
```

- **TELEGRAPH can be interrupted** by STUNNED, FROZEN, DANCING, LAUNCHED or a boss BREAK. The attack is cancelled, not delayed.
- **ACQUIRED** (Hostile Takeover) swaps the unit's target team. It keeps its own TELEGRAPH and ATTACK modules.
- Status precedence follows BS_WEAPONS §4.

### 2.3 Attack tokens (readability)

- **Melee tokens:** at most **2** enemies may be in TELEGRAPH or ATTACK against Bolt at once. Others circle (Scrap Mutt packs feint while they wait).
- **Ranged tokens:** at most **3** enemy shots may *begin* in any 1 s window, so telegraphs never stack into a wall.
- **Boss adds** use the same pool, and the boss always has its own reserved token.
- Tokens prefer enemies in front of the camera. An off-screen enemy needs a token *and* plays a directional audio sting (the same 0.45 s minimum).

### 2.4 Perception

| Sense | Rule |
|---|---|
| Sight | Line-of-sight raymarch at 10 Hz per unit, skipped beyond 42 m (the source's Mannequin rule, applied to everyone) |
| Hearing | Gunfire alerts enemies within 20 m; the mallet alerts within 8 m |
| Aggro share | When one enemy alerts, packmates within 10 m alert after 0.3 s |
| Target selection | Nearest valid target among Bolt, Middleman drones, subsidiaries, K.A.R.E.N. and Picket Corn (hostile only), weighted by taunt rules (BS_WEAPONS §8.10) and the LIEN debuff (§3.1) |

### 2.5 LOD, pooling and budgets

| System | Rule |
|---|---|
| AI LOD 0 | Within 30 m, or the current target: full tick (physics rate), full animation |
| AI LOD 1 | 30–60 m: AI ticks at 10 Hz, animation at 15 Hz, no local avoidance |
| AI LOD 2 | Beyond 60 m, or no LOS and not aggro'd: asleep; only timers and status decay run |
| Path budget | Re-path every 0.25 s within 15 m, 0.75 s at 15–40 m, 2.0 s beyond; a global cap of 6 re-paths per physics frame, round-robin (same as Gravelight `ENEMIES.md`) |
| Pools | Per planet, pre-instantiate: 12 per chaser type, 8 per flyer type, 6 per turret type, 4 per support type, 4 Weld Wasps per swarm slot. Bosses and their adds are pre-warmed at the arena checkpoint. |
| Projectile pools | 128 enemy projectiles, 256 player projectiles, 64 damage numbers (the source already pooled damage numbers in `dmgPool`) |
| Death debris | 3–5 chunks in the def's `chunk` colour (`chunkDeath`), pooled, scaled by `QUALITY.particles` |
| Cap | Planet encounters are designed for at most 18 active enemies; the Colosseum caps at 24 |

### 2.6 Data schema

`data/bs/enemies/<id>.tres` (an `EnemyData` resource) holds:
- `hp`, `speed`, `dmg`, `drops`, `chunk_color`, `arch`, `modules[]` and module parameters;
- `aggro_radius`, `leash`, `telegraph` (pose id, sfx id, light colour, duration), `weak_point` (bone, crit multiplier, breakable HP);
- `elite` (rim colour, trick module, multipliers);
- `die_sfx` (a synth recipe ported from the source's `beep`/`noiseBurst` calls);
- `satire_note` (design-only).

All numbers below map 1:1 to these fields.

---

## 3. Enemies by planet

**Field legend.**
- **Orig** is the source baseline: HP / speed / damage / drops, then flags.
- **Role** is the combat job.
- **Telegraph** lists pose + sound + light and the duration.
- **Counter** lists the weak point and the counterplay.
- **dieSfx** is the original synth, described as intent.

### 3.1 SCRAPHEAP JUNCTION

#### Scrap Mutt — pack chaser
| | |
|---|---|
| Orig | 30 HP / 4.2 / 10 / 6 bolts · `chaser`, `pounce` |
| Role | Pack pressure. Teaches dodging. |
| Silhouette | A low, four-legged junk-dog: a boxy head with a heavy underbite and a tooth strip, teal ear fins, a tire tail that wags faster while hunting |
| Behaviour | Packs of 3–5 **circle** Bolt at 5–7 m. The pack leader (the one holding the melee token) **pounces**; the others **feint**, a half-lunge that stops short at 0.25 s with no damage, to sell the fake. After a pounce, the mutt retreats to the circle. A lone mutt pounces straight in. |
| Telegraph | Crouch with the body squashed to 72% height · rising growl · eye glow flicker · **0.45 s** (was 0.32) |
| Counter | Dash through the pounce (i-frames). A finisher stagger scatters the pack for 1.5 s. A slam launches the whole circle. |
| Satire | Repossessed guard dogs. OmniScrap took them in a foreclosure and is now leasing them back to the junkyard. |
| Elite | **Rust rim (#c06a2e).** *Alpha Lease:* the pounce chains into a second pounce if the first misses. |
| dieSfx | A descending sawtooth "dying whine" (600 → 90 Hz, 0.35 s). Keep it pathetic, not gory. |

#### Tinker Turret — ambush turret
| | |
|---|---|
| Orig | 55 HP / — / 12 per shot (code) / 8 bolts · `turret`, `ambush` |
| Role | Area lock-down from cover. Teaches looking for tells. |
| Silhouette | A kettle-bodied turret hidden under a junk-mound lid, with a periscope and a teal lamp poking out; the lid flips aside when it pops |
| Behaviour | **Hidden** under a junk pile (the lid jitters slightly) until Bolt is within 11 m. Then it **rises** (0.55 s) and fires 12-damage shots every 2.2 s. **Remake:** after every 3 shots it **reloads** for 1.6 s, and its coil is exposed. |
| Telegraph | Barrel lowers, muzzle glows (the source's 0.55 s ramp) · a rising whine · orange muzzle light · **0.55 s** |
| Counter | **Weak point:** the coil, exposed during reload (crit ×2.5; three crits break it and the turret dies). The periscope gives away the hiding spot. A mallet-boomerang throw at a suspicious pile wakes it from safe range. |
| Satire | Built by OmniScrap's "Tinker Program", which hires junkyard kids for exposure and stickers. |
| Elite | **Brass rim (#d8b04a).** *Union Rules:* it fires a 3-round spread instead of one shot, but reloads every 2 bursts. |
| dieSfx | A square-wave drop with a scrap-noise burst (a kettle blowing its lid). |

#### Vulture Drone — bolt thief flyer
| | |
|---|---|
| Orig | 26 HP / — / 8 on dive (code) / 6 bolts · `flyer`, `dive`, `steal: 5` |
| Role | Economy threat. It punishes ignoring the sky. |
| Silhouette | A hunched brown drone with a beak, two dish eyes, angled wings and a little **cage** slung underneath, which fills with stolen bolts |
| Behaviour | Circles at 5 m above Bolt (orbit radius 5). Every 5 s (within 14 m) it **dives** at 15 m/s. A hit deals 8 and **steals 5 bolts** (`-5 BOLTS!`), and the bolts become visible in its cage. It then climbs for 1.2 s. **Remake:** after a successful steal it **flees** toward the map edge at 9 m/s for 6 s and despawns with the bolts if it escapes. Killing it before then drops everything it stole plus its own drops (the source's `e.stolen`). |
| Telegraph | Wings tuck, beak points down · the 0.5 s dive screech (1500 → 380 Hz, from the source) · red eye flare · **0.5 s** |
| Counter | Shoot it during the climb (slowest), or during the flee (the cage glows gold so you can track it). Lawn Darts and Zap are ideal. Dashing through the dive makes it miss. |
| Satire | OmniScrap's "Automated Collections" division. It's not theft if there's a terms-of-service. |
| Elite | **Gold rim (#ffd23e).** *Compound Theft:* it steals 10 and splits into two smaller drones when it flees. Each carries half the loot. |
| dieSfx | A long sawtooth "screech out" (1200 → 200 Hz, 0.4 s). |

#### Lien Crawler — NEW (burrower)
| | |
|---|---|
| Tuning | **36 HP / 5.0 underground, 3.0 surfaced / 6 bite / 7 bolts** |
| Role | Marks Bolt as the priority target. Teaches cleaning up the tagger first. |
| Silhouette | A flat, armoured legal-clerk bug about the size of a manhole cover, with a notary-seal back plate and a rubber-stamp head. When underground, its trail is a line of popping rivets. |
| Behaviour | Travels **underground** toward Bolt (a visible rivet trail). It surfaces within 3 m and **stamps**: 6 damage plus the **LIEN** debuff. Then it re-burrows after 1.2 s on the surface. At most one LIEN is active at a time; a new stamp refreshes it. |
| LIEN (player debuff) | 8 s. While it's active: every enemy prioritises Bolt (Middleman, subsidiary and K.A.R.E.N. taunts fail on enemies that can see him); turrets fire 30% faster at him; he takes +15% damage; and 1 in 5 bolts he picks up is "garnished" (it flies to the crawler instead, and comes back as part of its drops when it dies). The HUD shows a red "LIEN" stamp on Bolt's health bar. |
| Telegraph | The trail stops and the ground bulges · a chain-rattle and notary "clunk" · a red seal glow under the dirt · **0.5 s** |
| Counter | **Smash it to clear the lien:** killing the crawler that placed it, or hitting it with any slam, removes LIEN instantly. A slam on its trail forces it up, stunned for 1.5 s. Root Canal plants on its lane root it as it surfaces. |
| Satire | Liens on the junkyard's shacks. It's the bureaucracy of foreclosure, crawling under your floorboards. |
| Elite | **Crimson rim (#d42f2f).** *Second Mortgage:* LIEN lasts 14 s, and each stamp also spawns a Vulture Drone "to collect." |
| dieSfx (new) | A rubber-stamp *thunk*, then a descending paper-tear noise (square 400 → 120 Hz 0.15 s + noise 0.2 s at 2.5 kHz). |

### 3.2 RUSTVANE CANYON

#### Ambassadog — fast polite pouncer
| | |
|---|---|
| Orig | 26 HP / 5.6 / 9 / 6 bolts · `chaser`, `pounce` |
| Role | Fast flanker. |
| Silhouette | A pale resort hound in a tiny corporate vest, with a visor band for eyes and pink ear cones |
| Behaviour | Runs a wide arc to flank (it approaches from the side or behind the camera when it can). It **bows** before it pounces ("polite pounce"). **Remake:** after a successful pounce it hands Bolt a "loyalty card" (a cosmetic sticker on screen for 1 s) and trots back. |
| Telegraph | Formal bow, head dip · a two-note "ding-dong" chime · the visor glows pink · **0.45 s** |
| Counter | The bow is the tell: dash or swing on the chime. Low HP, so Zap chains clear groups. |
| Satire | Brand ambassadors. Paid in exposure, enthusiastic about everything, biting you anyway. |
| Elite | **Pink rim (#ff4d9d).** *Referral Bonus:* when it dies, the nearest Ambassadog gets +50% speed for 5 s. |
| dieSfx | Two falling sine tones (880 → 440, then 660 → 220), a sad doorbell. |

#### Selfie Sentry — flash-blinder flyer
| | |
|---|---|
| Orig | 30 HP / — / 7 × 3 burst (code) / 7 bolts · `flyer`, `flash` |
| Role | Ranged harasser that punishes staring. |
| Silhouette | A white flying **ring light** with a lens in the centre and two small props |
| Behaviour | Orbits at 4 m radius, 3 m up. Every 2.7 s within 16 m it **flashes** (the source's `flashT` screen flash), then fires a 3-shot burst (7 damage each, 0.13 s apart, 13 m/s). **Remake:** if Bolt's camera is facing the lens within 25° when the flash fires, he is **BLINDED**: a 1.2 s white-out with a vignette. Looking away, or being behind cover, avoids it. |
| Telegraph | The ring light swells · a shutter click (1900 Hz) · ring-light glow to max · **0.5 s** |
| Counter | **Weak point:** the lens (crit). Shooting the lens during the 0.5 s telegraph cancels the flash and burst. Turning away cancels the blind. |
| Satire | It photographs guests and auto-posts one-star reviews of their faces (quest q2a, `q.q2a.intro.01`). |
| Elite | **White rim (#f2ebe0).** *Going Viral:* each successful blind spawns a "like" drone (8 HP) that orbits it and absorbs one hit. |
| dieSfx | A shutter click, then a crunching sawtooth drop (1800 Hz blip → 90 → 40 Hz). |

#### Lifeguard Bot — heavy lobber
| | |
|---|---|
| Orig | 85 HP / 2.3 / 14 contact; ring 12 (code) / 11 bolts · `chaser`, `lob`, `heavy` |
| Role | Slow area denial. It splits up groups. |
| Silhouette | Tall and stocky, with a red visor cap, a yellow whistle, one arm stacked with red-and-white flotation rings, and stumpy feet |
| Behaviour | Lumbers toward Bolt. At 4–16 m, every 3.4 s it **lobs an exploding flotation ring** (an arc with gravity 13; 12 damage, r2.6 blast). Up close: 14 contact damage. **Remake:** the ring leaves a 3 s "NO RUNNING" puddle (r2.6) that SLOWS Bolt by 30%. |
| Telegraph | Arm raises fully back · a **sustained whistle blast** (2100 → 2350 Hz, extended from the source's 0.16 s chirp) · the ring glows red · **0.5 s**, plus a landing decal |
| Counter | Heavy, so it can't be launched or clumped. Frostbyte (it needs 2.0 frost) and Late Fee staggers work. The whistle is the tell to move. |
| Satire | The resort's lifeguard, who has never saved anyone but has issued 4,000 "no running" violations. |
| Elite | **Red rim (#d42f2f).** *Adult Swim:* it lobs 3 rings in a fan. |
| dieSfx | A last long whistle (2200 → 2400 Hz) collapsing into a low sawtooth groan. |

#### Review Bomber — NEW (flyer)
| | |
|---|---|
| Tuning | **30 HP / 6.0 / 12 per bomb / 7 bolts** |
| Role | Area-pattern bomber. A readable "bullet-hell lite" for the canyon. |
| Silhouette | A chubby drone with a megaphone beak and a belly bay full of fat star-shaped bombs; a lit "★☆☆☆☆" display on its side |
| Behaviour | Cruises at 8 m altitude between fixed perches. Every 4.5 s it picks Bolt's position and **"posts a review"**: 5 bombs land on the five points of a star (each point 4 m from the centre; bomb r1.6, 12 damage). The **centre of the star is safe**. On even cycles it alternates to a **ring of 5** (the centre is unsafe, and the gaps between bombs are safe). |
| Telegraph | Hovers still, bay opens · a notification ping, then a descending "boo" · the star or ring decals glow on the ground · **0.8 s** before impact |
| Counter | It's slowest while posting (it hovers for 0.6 s): shoot it then. Stand in the star's centre. The bombs are fragile in flight: shooting one makes it pop harmlessly ("DENIED"). |
| Satire | One-star reviews for a resort, written by people who never visited. Its display flickers "Would not die here again." |
| Elite | **Amber rim (#ffb02e).** *Verified Purchaser:* it posts two patterns back to back (star then ring) with 0.6 s between them. |
| dieSfx (new) | An "unsubscribe" chime played backwards, then a crumpling pop (sine 600 → 1200 Hz 0.15 s reversed + noise 0.2 s). |

### 3.3 NOVA PLAZA

#### Meter Maid — ticketing pouncer
| | |
|---|---|
| Orig | 34 HP / 6.2 / 10 / 7 bolts · `chaser`, `pounce` |
| Role | Fast chaser that punishes standing still. |
| Silhouette | A blue-uniformed walker with a hi-vis badge, a flat cap with a brim, and a bright orange **boot clamp** held in one hand |
| Behaviour | Chases and pounces (10 damage). **Remake:** if Bolt has stood still (moved under 1 m) for 1.5 s while she's within 8 m, her pounce becomes a **boot clamp**: 10 damage, and Bolt can't move (he can still aim and shoot) for 1.0 s, or until he mashes free. |
| Telegraph | Clamp raised overhead, the pen clicks · a ticket-printer chatter · amber badge light · **0.45 s** |
| Counter | Keep moving. A slam scatters her. Finishers stun her before she clamps. |
| Satire | She writes tickets for loitering in a city with no residents. |
| Elite | **Hi-vis rim (#ffd23e).** *Double Parked:* the clamp also tickets nearby allies' targets: any enemy within 6 m of the clamped Bolt gets +20% damage for 3 s. |
| dieSfx | Two falling square blips (700 → 200, 400 → 120 Hz), the sound of a printer giving up. |

#### HOA Enforcer — plated turret
| | |
|---|---|
| Orig | 70 HP / — / 12 per shot (code) / 11 bolts · `turret`, `plated` (a riot shield as its single plate), `heavy` |
| Role | Shielded anchor. Teaches the anti-armour tools. |
| Silhouette | A broad turret on a bolted base with a tall **riot shield** (an HOA crest), a head with a glowing weak-point lamp, and a clipboard |
| Behaviour | Fires 12-damage shots every 2.2 s from behind the shield. **Remake:** every 8 s it **issues a VIOLATION**: the 4 m ground ring around a random nearby walkway glows, and if Bolt is on that walkway, it **reverses direction** (the Nova walkway mechanic). |
| Telegraph | Shield braced, head lifts · a gavel knock · the crest glows red · **0.55 s** for the shot; **0.8 s** for a VIOLATION |
| Counter | The shield ignores guns. Mallet hits strip it (as in the source). Buzzkill pops it in 4 hits (2 at V5), and Clearance Rack marks it down. **Weak point:** the head lamp (crit), visible above the shield when it fires. |
| Satire | The Homeowners' Association for a city with no homeowners. It still enforces the paint colour of the fountains. |
| Elite | **Slate rim (#3a4658).** *Special Assessment:* it has two shields (front and back), and a VIOLATION fines Bolt 10 bolts. |
| dieSfx | A noise burst and a square drop (200 → 60 Hz), a filing cabinet falling over. |

#### Surge Drone — surge-pricing flyer
| | |
|---|---|
| Orig | 26 HP / — / 10 per shot (legacy flyer in v14) / 6 bolts · `flyer`, `surge` (not implemented in the source) |
| Role | A priority target that scales with the crowd. |
| Silhouette | A small rotor drone with a **price-ticker eye** and an underslung gun |
| Behaviour | Legacy flyer orbit and shot (10 damage every 2.4 s). **Surge pricing (implemented):** for every other enemy alive within 15 m, it gets +15% damage and +8% fire rate (up to 6 others: +90% and +48%). Its ticker shows the current surge ("1.6×"). |
| Telegraph | The gun glows (the source's 0.45 s ramp) · a cash-register "ding" · the ticker flashes its multiplier · **0.45 s** |
| Counter | Kill it first in big fights, or thin the crowd. Zap chains reach it. |
| Satire | Surge pricing on violence. "High demand in your area." |
| Elite | **Magenta rim (#ff4d9d).** *Peak Hours:* the surge also applies to all other enemies within 15 m (+5% per enemy). |
| dieSfx | A falling sawtooth (1800 → 400 Hz), a price crash. |

#### Zoning Board — NEW (support/turret, three linked pylons)
| | |
|---|---|
| Tuning | **3 pylons × 40 HP / — / 6 per 0.5 s zone tick; 10 for touching a beam / 4 bolts per pylon (12)** |
| Role | Space denial that forces repositioning. A puzzle-turret. |
| Silhouette | Three waist-high civic pylons with clipboard heads and permit-stamp tops, linked by humming yellow light beams in a triangle |
| Behaviour | The pylons project a **NO-GO zone** inside their triangle (up to 14 m a side). Bolt inside the zone is "unpermitted": he takes 6 damage every 0.5 s and is SLOWED (−20%). Touching a beam deals 10 damage. Every 8 s the board **re-zones**: the pylons slide up to 5 m along rails to a new triangle. |
| Telegraph | Re-zone: the permit stamps rise · a council-chamber gavel triple-knock · the new triangle's floor paints with a yellow permit grid · **1.0 s** |
| Counter | **Break the link:** destroying any one pylon collapses the triangle. Each remaining pylon then projects only a small r3 circle until destroyed. **Weak point:** the permit stamp on top, exposed during re-zone (crit). Beams are low, so you can jump them. |
| Satire | Zoning laws for a city that never got built. Bolt is in violation of the planning commission's dreams. |
| Elite | **Yellow rim (#ffe84d).** *Variance Denied:* destroyed pylons rebuild after 10 s unless all three die within 6 s of each other. |
| dieSfx (new) | A rubber-stamp "DENIED" thunk, then a falling square chord (300/240 Hz → 60 Hz, 0.3 s). |

### 3.4 GLACIUS VAULT

#### Chillsplitter — ice burrower
| | |
|---|---|
| Orig | 30 HP / 5.0 / 11 / 6 bolts · `chaser`, `burrow` (not implemented in the source; it was a plain chaser) |
| Role | Ambush chaser that punishes standing on open ice. |
| Silhouette | A low, finned ice-borer with a single tall **ice horn** |
| Behaviour (implemented) | Travels **under the ice** (a visible crack line). It **erupts** under Bolt: 11 damage and a knock-up of 6. It stays surfaced for 2.0 s, chasing at 5.0 m/s, then dives again. It can't burrow through metal floors, so on platforms it's a normal chaser. |
| Telegraph | The crack line stops and the ice bulges and frosts · an ice-creak rising to a crack · pale blue glow under the ice · **0.5 s** |
| Counter | Keep moving across open ice, or stand on metal grating. Slam the crack line to force it up (stunned 1.5 s). Frozen Chillsplitters shatter for extra bolts. |
| Satire | Thaw-Queue "line management." It keeps people from cutting ahead in a queue that never moves. |
| Elite | **Glacier rim (#5a9ac8).** *Fast Lane:* it erupts twice in a row at the same spot. |
| dieSfx | A falling sawtooth (500 → 90 Hz) plus an ice-crack noise burst at 2 kHz. |

#### Popsicle — pod-disguised ambush turret
| | |
|---|---|
| Orig | 48 HP / — / 12 per shot (code) / 8 bolts · `turret`, `ambush` (its ice shell cracks off when it pops) |
| Role | Ambush in the pod rows. It makes the player read the pods. |
| Silhouette | Looks exactly like a cryo-pod with a frosted ice shell, until its legs unfold and the shell cracks off to show a pale turret body |
| Behaviour | Hidden as a pod until Bolt is within 11 m. Then it **thaws out** (0.55 s; the shell's opacity drops to 0) and fires 12-damage shots every 2.2 s. **Remake:** every third shot is a **frost slug** (8 damage + 0.4 frost on Bolt; at 1.0 frost Bolt is FROZEN 1.1 s, the same player-freeze as the source's Retention breath). |
| Telegraph | Shell frost brightens, a pod-hiss · the source's 1200 Hz pop · a blue muzzle glow · **0.55 s** |
| Counter | Tell: real pods have a name tag and a thaw-panel light. Popsicles have a blank tag and no panel light. The Fine Print marks reveal it. A mallet-boomerang throw at a pod wakes it safely. |
| Satire | A cryo-pod that "sold" its occupant's slot. Even the furniture has a subscription. |
| Elite | **Frost rim (#8ad0e8).** *Brain Freeze:* every shot is a frost slug. |
| dieSfx | An ice-shatter noise (3 kHz) plus a falling sine (1200 → 300 Hz). |

#### Frost Peddler — freeze flyer salesman
| | |
|---|---|
| Orig | 30 HP / — / 10 per shot (legacy flyer in v14) / 7 bolts · `flyer`, `freeze` (not implemented in the source) |
| Role | Ranged debuffer. |
| Silhouette | A hovering vending-cart drone with a fur-trimmed awning, a "WARMTH UPGRADES" sign and a frost nozzle |
| Behaviour (implemented) | Orbits and fires **frost bolts**: 6 damage + 0.35 frost every 2.4 s (3 hits freeze Bolt for 1.1 s; mash to thaw, as in the source). **Remake:** while Bolt has 0.5+ frost, it pitches a "warmth upgrade" bark and hovers closer. In Glacius fights it also tries to **hack pod thaw panels** to "Premium" (§ Premium Waker). |
| Telegraph | The nozzle frosts over · a sales-chime jingle · a blue nozzle glow · **0.45 s** |
| Counter | Kill it before you're frozen. Fire and Magma patches clear frost. Interrupting its hack makes it flee for 3 s. |
| Satire | It sells you warmth while it freezes you. The exact business model of the whole planet. |
| Elite | **Ice-blue rim (#7ab8d8).** *Annual Plan:* its frost bolts home gently (turn rate 1.1). |
| dieSfx | A rising sine (900 → 1600 Hz), like a sale ending. |

#### Premium Waker — NEW (chaser/heavy)
| | |
|---|---|
| Tuning | **60 HP / 4.5 / 15 smash / 9 bolts · heavy** |
| Role | A mid-fight escalation that the player can prevent. A moral choice in miniature. |
| Silhouette | A thawed customer in a heated gold "PREMIUM" cryo-suit, steaming, with frost-burned hands and a glowing subscription chip on the back of the neck |
| Trigger | During Glacius encounters, 1–2 pods per fight get **hacked to PREMIUM THAW** (by a Frost Peddler, or on a 20 s timer). The pod's thaw panel turns violet and counts down **6 s**. |
| Protect (success) | Mallet-hit the panel or interact with it (0.8 s) to revert it to standard thaw, or kill the hacking Frost Peddler. The person inside is **freed safely**: they stumble out, thank Bolt, and run to the exit. Pays **15 bolts**, and it counts toward the "Nobody Gets Recalled" Glacius tally. |
| Fail | The panel hits 0 and a **Premium Waker** bursts out. |
| Behaviour | Frenzied heavy chaser. Its **UPGRADE SMASH** is an overhead two-handed slam: 15 damage, r2.5, knockback. Every third attack is a 6 m **charge** at 7 m/s. |
| Telegraph | Arms overhead, chip flares · a heater-coil whine into a scream · gold suit glow · **0.6 s** (smash), **0.7 s** (charge, with a lane decal) |
| Counter | **Weak point:** the neck chip (crit ×2.5). Breaking the chip (30 damage to it, or one marked crit) **downgrades** the Waker: it collapses, stops fighting, and survives as a freed customer for **10 bolts**. Killing it the normal way pays its 9 bolts and no rescue. |
| Satire | The customer who paid to thaw first, and woke up as the product. |
| Elite | **Gold rim (#ffd23e).** *Platinum Tier:* the chip is shielded until the Waker finishes a charge. |
| dieSfx (new) | Downgrade: a deflating heater hiss and a confused human "...huh?" grunt (VO). Kill: a heater-coil pop (noise 0.3 s at 900 Hz + sine 400 → 100). |

### 3.5 VERDANT SINK

#### Gloomstalker — cloaked pouncer
| | |
|---|---|
| Orig | 32 HP / 6.0 / 12 / 7 bolts · `chaser`, `pounce`, `cloak` (not implemented in the source) |
| Role | Stealth threat. Teaches audio reads and the Fine Print. |
| Silhouette | A lean, moss-dark quadruped with a long head and a low profile; when cloaked, it's a heat-haze shimmer |
| Behaviour (implemented) | **Cloaked** (90% transparent with a refraction shimmer) while moving more than 6 m from Bolt. It **decloaks** to pounce (12 damage). After a pounce it re-cloaks after 2 s. Taking any damage decloaks it for 3 s. |
| Telegraph | Decloak shimmer then a crouch · a wet clicking purr · two green eye-points light up · **0.5 s** |
| Counter | **The Fine Print marks reveal it for 6 s** (BS_WEAPONS §4). Its footsteps splash in murk pools. Zap chains hit cloaked units. Glow-marsh light silhouettes it. |
| Satire | OmniScrap's "brand safety" team. You never see them, but they're always there. |
| Elite | **Bog-green rim (#2a4a3a), visible even when cloaked.** *Ghost Account:* it leaves a decoy shimmer that pounces for 0 damage. |
| dieSfx | A rising triangle (300 → 900 Hz), a confused chirp. |

#### Spore Lobber — arcing turret
| | |
|---|---|
| Orig | 40 HP / — / 10 + r2.2 blast (code) / 8 bolts · `turret`, `spore` |
| Role | Indirect fire that punishes camping behind cover. |
| Silhouette | A plant on a rooted stalk with a swollen purple bulb and an open "spore mouth" |
| Behaviour | Every 2.2 s, it lobs a toxic glob (10 damage, r2.2 blast). **Remake:** each glob leaves a 2 s spore cloud (r2.2) that ticks 3 damage every 0.5 s. Globs arc over cover. |
| Telegraph | The bulb swells and the mouth puckers · a wet inhale · green mouth glow (the source's 0.55 s ramp) · **0.55 s**, plus a landing decal |
| Counter | It's rooted in place, so close the distance. Its weak point is the bulb (crit). Globs are fragile in flight. |
| Satire | Pesticide-resistant crops that OmniScrap tried to monetize as "artisanal spores." |
| Elite | **Violet rim (#6a3a6a).** *Organic Certified:* globs split into 3 on landing. |
| dieSfx | A soft noise burst plus a falling triangle (400 → 100 Hz), a deflating pod. |

#### Pollinator — tiny buffer
| | |
|---|---|
| Orig | 10 HP / — / 5 / 3 bolts · `flyer`, `buffer` (not implemented in the source; it used the legacy flyer shot) |
| Role | Priority-kill support. |
| Silhouette | A tiny striped bee-drone with an oversized pollen sac |
| Behaviour (implemented) | Flies between allies. Every 3 s it **dusts** the nearest non-buffed ally: +30% damage and +20% speed for 6 s (a gold pollen aura). It flees from Bolt to stay 8+ m away. Weak sting: 5 damage. |
| Telegraph | Sac pulses · a buzzing crescendo · a gold dust puff · **0.4 s** (buff) |
| Counter | Kill it first: it's 10 HP, so any weapon works. Zap chains reach it. Quest q7a ("Picket line") makes them the scabs. |
| Satire | Scab labour. They cross the corn's picket line to buff management's goons. |
| Elite | **Honey rim (#ffcf4d).** *Swarm Pricing:* it travels in threes, and a buff from two or more stacks to +45%. |
| dieSfx | A short falling sawtooth (1400 → 500 Hz), a popped bubble. |

#### Picket Corn — NEW (neutral faction, chaser)
| | |
|---|---|
| Tuning | **50 HP each / 2.5 / 8 sign-bash (only when hostile) / 5 bolts each** |
| Role | A neutral faction that rewards care with your splash damage. |
| Silhouette | Tall corn stalks with googly eyes, hard hats and hand-painted picket signs ("LOCAL 404", "DENTAL NOW", "WE ARE NOT A CROP") |
| Behaviour | Groups of 3–5 **march in a loop**, chanting. They're **neutral**: enemies attack them (Pollinators, Gloomstalkers and Spore Lobbers treat corn as targets). **Hitting** a corn (any damage, including splash) makes *that group* hostile for 20 s. They sign-bash for 8 damage and chant angrier. |
| Exceptions | B.O.O.M. Box makes them dance happily: no hostility, and they call it a solidarity rally. Hostile Takeover refuses them ("We don't cross picket lines."). K.A.R.E.N. never targets them. Frostbyte makes them "a little chilly" (a slow, no freeze, no hostility). |
| Telegraph (hostile) | Sign raised overhead · the chant cuts to a shout · a red glow on the hard-hat lamp · **0.5 s** |
| Reward | If 3 or more corn in a group survive an encounter: **+60 bolts** ("strike fund") and 1 tally mark. 5 tallies earn the cosmetic **Local 404 Union Card** (a Sprocket hat badge) and a corn bark. |
| Counter | Aim carefully. Prefer single-target weapons near them. Protect them from Pollinators. |
| Satire | The terraforming crops unionized (`memo.26`, `st.verdantIntro.01`). They're the only reasonable people on the planet. |
| Elite | **Union-red rim (#d42f2f).** *Shop Steward:* the group's steward. If it's hit, *every* corn group on screen turns hostile. If it survives, the reward doubles. |
| dieSfx (new) | A popcorn *pop* and a sad kazoo note (noise 0.08 s at 3 kHz + triangle 500 → 300 Hz). Never gory. |

### 3.6 CORE FOUNDRY

#### Slag Golem — plated heavy
| | |
|---|---|
| Orig | 75 HP / 1.9 / 16 / 12 bolts · `chaser`, `plated` (3 plates), `heavy` |
| Role | The armour exam. It forces mallet play or the anti-armour guns. |
| Silhouette | A hulking basalt brute with glowing magma seams and three stone plates (front, left and right) that crack hotter as they're stripped |
| Behaviour | Lumbers forward and thumps the ground (every 0.55 s). 16 contact damage. **Remake:** a **SLAG SLAM** every 6 s within 4 m: a two-fist ground pound (16 damage, r3 shockwave, jumpable). |
| Telegraph | Fists raised, seams flare · a rising magma rumble · orange seam glow · **0.7 s**, plus a ground decal |
| Counter | Guns ping until the plates are stripped: the mallet (as in the source), Buzzkill, Clearance Rack markdown. Once a plate is off, the hot core behind it is a weak point. |
| Satire | Grindstone's "legacy hardware": too expensive to replace, so they made it security. |
| Elite | **Magma rim (#ff5a12).** *Hostile Workplace:* each plate stripped makes it faster (+0.4 m/s per plate). |
| dieSfx | A heavy noise burst (400 Hz) plus a deep sawtooth (70 → 30 Hz), a collapsing kiln. |

#### HR Drone — paperwork flyer
| | |
|---|---|
| Orig | 34 HP / — / 8 per notice (code) / 7 bolts · `flyer`, `paper`, `hoverHome` |
| Role | Slow homing pressure that teaches shooting down projectiles. |
| Silhouette | A grey drone with a cyan **halo** ring and a paper tray, which flutters with termination notices |
| Behaviour | Hovers near its post (1.2 m wobble). Every 2.8 s within 22 m, it files a **homing termination notice**: 8 damage, 5.5 m/s, homing 1.1, **fragile** (shootable, "DENIED"). **Remake:** a notice that hits applies **PAPERWORK**: −20% dash distance for 4 s ("pending approval"). |
| Telegraph | Tray tilts forward · the source's dot-matrix printer chatter · the halo pulses white · **0.4 s** |
| Counter | Shoot the notices out of the air. Every gun works on fragile shots. Cease & Desist documents shred them extra hard. |
| Satire | HR, hovering above the factory floor, promising it's there for you. |
| Elite | **Cyan rim (#3ee6ff).** *Performance Improvement Plan:* it files three notices in a spread. |
| dieSfx | A rising square (500 → 1500 Hz) with a 3 kHz noise burst, a printer jam. |

#### Weld Wasp — swarm flyer
| | |
|---|---|
| Orig | 8 HP / — / 6 / 3 bolts · `flyer`, `wasp` |
| Role | Swarm chip damage. It punishes ignoring the crowd. |
| Silhouette | A tiny striped wasp drone with a glowing welding-tip sting |
| Behaviour | A fast, erratic orbit around Bolt (1.8 m radius, bobbing). Stings for 6 on contact (1.2 s cooldown). Buzzes every 0.5 s within 12 m. Swarms of 4–8. **Remake:** in swarms, wasps take turns (melee tokens), so only 2 sting at once. |
| Telegraph | Sting glows white-hot · a buzz pitch-up · sting flare · **0.3 s** (light chip, under the 14 threshold) |
| Counter | Zap chains, Buzzkill Hedge Trimmer, the B.O.O.M. Box. Any splash. |
| Satire | Contract welders paid per weld, so they weld everything, including you. |
| Elite | **Yellow rim (#ffc02e).** *Overtime:* each wasp death makes the swarm 10% faster. |
| dieSfx | A falling sawtooth (1400 → 300 Hz), a tiny fizzle. |

#### Statue — bolt piñata prop
| | |
|---|---|
| Orig | 40 HP / — / — / 22 bolts · `prop` |
| Role | Catharsis and a bolt piñata. |
| Silhouette | A marble statue of Chairman Grindstone, cigar in hand, on a plinth in the Foundry lobby |
| Behaviour | No AI. Each hit chips a piece off (the cigar first). At 0 HP it bursts into 22 bolts. **Remake:** a smashed statue plays a PA line (`bs.foundry.statue.01`: "Please do not damage the Chairman. The Chairman has been damaged. Please do not enjoy this.") |
| Counter | It's a statue. Hit it. |
| Satire | Grindstone commissioned 400 statues of himself for a lobby nobody visits. |
| Elite | None (props don't get elites). In NG+, one statue per lobby is **gold** (60 HP, 3 gold bolts, no XP). |
| dieSfx | A noise burst (600 Hz) plus a falling square (200 → 60 Hz), crumbling plaster. |

#### Middle Manager — NEW (support/commander)
| | |
|---|---|
| Tuning | **90 HP / 3.2 / 10 clipboard swipe / 14 bolts** |
| Role | A commander that makes the fight about target priority. |
| Silhouette | A pear-shaped bot in a short-sleeved shirt and tie, a lanyard and a clipboard, with a **"WORLD'S BEST BOSS" mug** clamped to its back. It stands on a small hover-plinth labelled "OPEN DOOR POLICY." |
| Behaviour | Stays 8–12 m behind allies. |
| Performance review | Every **6 s**, up to 4 allies within 12 m get a **performance review**: a gold star, +25% damage and +25% speed for 6 s. |
| Firing | Every **15 s**, it **fires the worst performer**: the lowest-HP ally within 12 m is instantly killed ("PINK SLIP"; that ally drops no bolts), and the Manager gains +30 shield and +20% damage permanently (stacks up to 3). |
| Melee | A clipboard swipe (10) if Bolt gets close, then it backs off. |
| Telegraph | Review: clipboard raised, pen tapping · a two-tone "meeting reminder" chime · gold light on the targets · **0.6 s**. Firing: holds up a **pink slip**, and a pink spotlight lands on the victim · a stapler-thunk countdown · **1.0 s**. |
| Counter | **Interrupt:** any stagger (finisher, Collections, Late Fee stagger, a Dart bullseye) cancels a review or a firing. **SERVED Managers can't issue reviews** (it's an ability; Ω INJUNCTION blocks everything). Kill weak allies yourself first to deny the firing buff. **Weak point:** the mug on its back (crit; breaking it, 25 damage, cancels its shield stacks). An acquired (Hostile Takeover) Manager reviews *your* subsidiaries. |
| Satire | It improves morale by firing people. It calls it "right-sizing the team." |
| Elite | **Pink rim (#ff7ab8).** *Reorg:* at 50% HP it promotes the nearest ally to "Assistant Manager" (that ally gives reviews too). |
| dieSfx (new) | A mug shatter, then a falling "out-of-office" chime (noise 0.2 s at 4 kHz + square 660 → 220 Hz). |

### 3.7 GRAND GALLERIA

#### Mannequin — moves only when unseen
| | |
|---|---|
| Orig | 44 HP / 7.2 / 14 / 8 bolts · `chaser`, `stalker` |
| Role | Fear and attention management. |
| Silhouette | A tall, featureless display mannequin (a torso column, a smooth head with a dark face strip), arms frozen mid-reach, a pink SALE sash, on a round display base |
| Behaviour | **Perfectly still while seen.** Seen means within 42 m, in the camera's forward cone (dot > 0.35) and with line of sight (a 10 Hz check, kept from the source). **Horribly fast (7.2 m/s) when unseen.** It deals 14 on contact. Its eyes glow red only while it moves. The source's faint creak (when it freezes) and skitter (when it moves) are kept. **Remake:** mannequins re-pose every time they freeze, so the pose itself tells you one moved. |
| Telegraph | Arms lower into a grab · a plaster-crack creak · a red face strip · **0.45 s** (it still has to wind up in view to hit; it can't hit from fully unseen) |
| Counter | Keep it in view and back away. Frozen, rooted or dancing mannequins count as seen (they can't move anyway). Its plaster body breaks fast (44 HP), so a swing-around Lawn Dart or Zap chain behind you is the classic answer. |
| Satire | Mall staff. Never helpful when you're looking, everywhere when you're not. |
| Elite | **Bone-white rim (#e8e2d8).** *Window Display:* it travels in pairs that swap places while one is seen. |
| dieSfx | A plaster shatter (noise 900 Hz) plus a square drop (140 → 50 Hz). |

#### Coupon Crier — rally flyer
| | |
|---|---|
| Orig | 28 HP / — / 7 per coupon (code) / 9 bolts · `flyer`, `rally` |
| Role | Area buffer and bullet-sponge maker. |
| Silhouette | A floating bell-shaped body with a rotor ring, a **megaphone** and a "% OFF" ticker |
| Behaviour | Hovers 3.2 m over its post. Every 5.5 s (within 30 m) it **rallies**: a 10 m ring, and every ally within 13 m gets +40% move speed for 4 s. Every 3.2 s it fires a slow **fragile coupon** (7 damage, 6 m/s). **Remake:** the rally also gives +20% damage, and its ticker shows the "sale". |
| Telegraph | Megaphone raised · the source's two-tone "attention shoppers" chime · the ticker flashes gold · **0.5 s** |
| Counter | It's a priority kill. Coupons are shootable. Silence it with SERVED (no rallies). |
| Satire | The mall PA, given a body and a megaphone. It's announcing a sale on your life. |
| Elite | **Gold rim (#ffd23e).** *Doorbuster Event:* a rally also heals allies for 15 HP. |
| dieSfx | Two falling square tones (880 → 220, 1760 → 440 Hz), the PA's final markdown. |

#### Return Desk Mimic — NEW (ambusher)
| | |
|---|---|
| Tuning | **80 HP / 5.0 (hopping) / 25 chomp + 5 per 0.5 s hold / 18 bolts** |
| Role | A bait-and-punish ambusher. It rewards attention to detail. |
| Silhouette (disguised) | A bright "RETURNS — 100% REFUND" kiosk with a hologram deal floating over it ("FREE GOLD BOLT!") and a "NOW SERVING: 47" ticket display |
| Silhouette (revealed) | The kiosk counter splits into a mouth; the receipt-printer slot is a long paper tongue; it has stubby cart-wheel legs |
| Behaviour | Disguised until Bolt comes within 3 m, or until it's hit or marked. Then it **chomps**: 25 damage, and Bolt is **held** for 1.5 s (5 damage every 0.5 s; mash to escape in 0.8 s). After that it **hops** after Bolt at 5 m/s and spits fragile **receipts** (6 damage) every 2 s. |
| Tells (fair-play) | Real kiosks (Gilda's Kiosk #7 and Blartz's) never float a deal hologram. The Mimic's "NOW SERVING" number never changes. Its sign has a typo ("REFUNDS GAURANTEED"). It hums very faintly within 6 m. |
| Telegraph | The counter shudders and the lid lifts · a receipt-printer whirr rising to a gulp · the "OPEN" light flickers red · **0.5 s** |
| Counter | The Fine Print marks it out from range. A mallet-boomerang throw wakes it safely. **Weak point:** the tongue, exposed while chomping or spitting (crit ×2.5). Shooting the tongue during the hold frees Bolt instantly. |
| Satire | The return desk that never gives refunds. It eats the customer instead. |
| Elite | **Neon-pink rim (#ff4dd2), visible only once revealed.** *Store Credit:* after the chomp, it spits Bolt out with −30 bolts "store credit" (he gets them back when it dies). |
| dieSfx (new) | A long receipt-printer death rattle into a cash-drawer slam (noise 0.4 s at 3 kHz + square 300 → 60 Hz). |

---

## 4. Bosses

### 4.0 Shared boss rules

**BREAK meter (the v13 system, kept).** These are the exact source numbers from `damageEnemy` and `bossBreak`:

| BREAK rule | Value |
|---|---|
| Fill | Damage poured into the boss fills the meter. Weak-point (crit) hits count **double**. |
| Threshold | **12% of the boss's max HP** |
| Decay | 3.5% of max HP per second when you aren't hitting it |
| On BREAK | The boss staggers for **3.2 s**: helpless, any windup cancelled, takes **+50% damage from everything**. There's a 0.28 s slow-mo, a flash, the "BREAK!" banner and a Sprocket bark. |
| Cooldown | **14 s** before the meter can fill again ("a reward, not a loop") |
| Armour | Bosses take 45% damage except on weak-point crits (CLEARANCE RACK markdown can raise it) |
| Immunities | Freeze, dance (70% damage instead), root, grav clump, launch, Hostile Takeover. SERVED, MARKED and MARKED DOWN all work. |
| K.A.R.E.N. | 120 damage plus 10% of max HP added to the BREAK meter |
| HUD | The boss bar, plus a cyan BREAK sub-bar that shows meter fill, or the remaining stagger time while broken |

Every remake boss also has **BREAK feeders**: arena or mechanic actions that add meter directly (listed per boss). The source had one: Repo-Tron's press added 3%.

**Boss-start flow.**
1. The arena checkpoint saves.
2. The boss music pushes.
3. The **GLAMBOT title card** plays once per save (an existing `intro*` cutscene, or a new `bs.boss.<boss>.intro.<nn>` card).
4. The banner shows "<NAME> — DESTROY THE GLOWING CORE!" (the source's banner subtitle, kept).

**Phases.** Each boss has 3 HP-gated phases. A phase change plays a banner and a bark, cancels the current attack, and grants 1.2 s of boss invulnerability (to stop phases being skipped by burst damage).

**No-damage trophies.** Beating a boss without taking any damage awards its trophy. Fall-out respawns count as damage. Damage taken during the title card doesn't count.

**Barks.** Original lines with existing IDs are referenced by ID. Original lines that live only in code (`speak` / `showBark` / `showBanner` calls in the boss functions) have no ID in `lines_index.json` yet, so they get a **proposed ID** under `code.<function>.<nn> (tools/extract_code_lines.mjs)`, with the text verbatim. New lines are `bs.boss.<boss>.<topic>.<nn>`.

**Shared BREAK barks (original, proposed IDs):**
- `code.bossBreak.03` (sprocket): "STAGGERED! Hit it! HIT IT!"
- `code.bossBreak.04` (sprocket): "It’s wide open — go go go!"
- `code.bossBreak.05` (sprocket): "Weak point exposed. Like, aggressively exposed."
- Banner: "BREAK!" / "It’s staggered — unload everything!"

---

### 4.1 REPO-TRON — Scrapheap Junction (Exit Yard compactor arena)

**What the original fight did** (`updateRepoTron`):
- **Stats:** 380 HP, 40 bolts. The weak point is the PAST DUE stamp core.
- **Look:** tank treads, a magnet crane arm, a hydraulic-press face (top and bottom jaws), and a PAST DUE stamp heart.
- **It holds mid-range** (closes in at 2.4 m/s when farther than 7 m away). It picks one of these attacks:
  - **Press Swipe:** under 7.5 m, a 0.62 s telegraph ring in front; then a frontal arc for 18 damage with knockback.
  - **Magnet:** over 6 m, a 0.75 s telegraph (the arm raises and the magnet glows). Then a 1.5 s tractor pull (26 m/s² toward it; a dash breaks it). During the pull, crushed cars drop on Bolt every 0.5 s (14 damage, r2.2, each with a 0.55 s ring).
  - **Compact:** a 0.95 s ring of r9; a hydraulic slam sends out a jumpable shockwave (16 damage). It adds **3% to the BREAK meter** ("press windows favour a BREAK").
- **Phase 2 (under 50%), "REPOSSESSION MODE":**
  - **Tread Charge:** a 0.6 s telegraph, then a 14–17 m/s ram for 20 damage. It stops on walls.
  - It's faster.
  - **Scrap Mutt adds:** 2 every 11 s, at most 3 alive.

**Remake — three phases** (arena: the Exit Yard, a 30 × 30 m compactor pit with car stacks for cover and a magnet crane rail overhead):

| Phase | HP | New idea | Attacks (telegraph) |
|---|---|---|---|
| **1 · FORECLOSURE** | 100–66% | The original kit | Press Swipe (0.62 s ring); Magnet pull + car drops (0.75 s + 0.55 s rings); Compact shockwave (0.95 s, r9) |
| **2 · REPOSSESSION MODE** | 66–33% | **The magnet steals your weapon.** A Magnet that connects (Bolt is pulled within 4 m) **repossesses your equipped gun**. It hangs from the crane hook, its wheel slot shows "REPOSSESSED", and you fall back to the last weapon. Smash the **crane hook** (60 HP, mallet or guns, weak point) to drop the gun back and add **+30% of the BREAK threshold**. | Everything from phase 1, plus Tread Charge (0.6 s, a lane decal); Scrap Mutt adds (2 every 11 s, at most 3) |
| **3 · COMPACTION** | 33–0% | **The compactor walls close in.** The two side walls advance 1 m every 10 s (from 30 m apart to a 14 m minimum), and car stacks get crushed into new cover blocks. Hitting the PAST DUE stamp during the Compact recovery window (1.2 s after a slam) **pushes the walls back 2 m** and adds 3% BREAK (the source's press bonus, now doubled into a goal). | Faster swipe (0.5 s); a Magnet that chains into a Compact; Tread Charge into the walls (it **stuns itself for 1.5 s** if it hits a wall: a BREAK feeder worth +40% of the threshold) |

- **Weak point:** the PAST DUE stamp (the chest core). It's most exposed after a Compact slam and during a self-stun.
- **BREAK feeders:**
  - The press recovery hit (+3% of max HP, from the source).
  - Smashing the hook (+30% of the threshold).
  - A wall self-stun (+40% of the threshold).
- **Arena use:**
  - Car stacks block car drops.
  - The crane rail shows where the magnet will swing: the hook's shadow is the aim reticle.
  - The walls shrink the fight over time.
- **Title card (new, GLAMBOT on the Billing Mast broadcast screens).** This is before his defection, so he's reading OmniScrap's cue cards:
  - `bs.boss.repotron.intro.01` (glambot): "LIVE from the Scrapheap, it's REPOSSESSION OF THE WEEK! In the compactor corner — eleven tonnes of PAST DUE — it's REPO-TROOOON!"
  - `bs.boss.repotron.intro.02` (sprocket): "He's reading off cue cards. You can see them. OmniScrap is paying him by the exclamation point."
- **Story lines kept:** `st.l1_repo.01–03` play on arena approach.
- **No-damage trophy:** **"Paid In Full"**.

**Barks.**

| ID | Speaker | Line | Trigger |
|---|---|---|---|
| `code.updateRepoTron.02` | pa | ATTENTION OCCUPANT. THIS PROPERTY HAS BEEN FORECLOSED. PLEASE HOLD STILL FOR COMPACTION. | Aggro (original) |
| `code.updateRepoTron.05` | pa | ESCALATING. YOUR BELONGINGS ARE NOW OUR BELONGINGS. | Phase 2 (original) |
| `code.updateRepoTron.06` | pa | ASSETS DETECTED. | Magnet (original) |
| `code.updateRepoTron.07` | pa | COME HERE, COLLATERAL. | Magnet (original) |
| `code.updateRepoTron.08` | pa | THIS IS A COURTESY GRAB. | Magnet (original) |
| `code.updateRepoTron.13` | sprocket | It’s calling the DOGS. The dogs it repossessed. | Mutt adds (original) |
| `code.onDeath.03` | sprocket | Repo THIS. | Defeat (original) |
| — | banner | "REPOSSESSION MODE" / "Treads engaged. Nothing is off the table. Including the table." | Phase 2 (original) |
| — | banner | "FORECLOSURE REVERSED" / "The junkyard stays yours" | Defeat (original) |
| — | hint | "MAGNET PULL — DASH to break free!" · "Shockwave — JUMP it, then hit the PAST DUE stamp!" | Original hints |
| `bs.boss.repotron.steal.01` | pa | ITEM REPOSSESSED. YOU MAY REPURCHASE IT AT A REASONABLE MARKUP. | Gun stolen |
| `bs.boss.repotron.steal.02` | bolt | Hey! I was USING that! | Gun stolen (first time) |
| `bs.boss.repotron.steal.03` | sprocket | The hook, Bolt. Smash the hook. It's literally hanging your stuff in front of you. | 4 s after a steal |
| `bs.boss.repotron.compact.01` | pa | COMPACTION IN PROGRESS. PLEASE REMAIN FLAT. | Phase 3 |
| `bs.boss.repotron.compact.02` | sprocket | The walls are moving. I'd like to file a complaint with the walls. | Phase 3, first wall advance |
| `bs.boss.repotron.compact.03` | pa | PROCESSING ERROR. ASSET HAS RESISTED COMPACTION. | Walls pushed back |

---

### 4.2 RUSTVANE SENTINEL — Rustvane Canyon mini-boss (the Strip Mine quarry floor)

**What the original did.** The web build had **no separate Sentinel**. The Rustvane boss type `miniboss` (`makeMiniBoss`, 420 HP) was a treaded turret tank with bolt-on armour plates, a beam cannon and a ring light. Its boss bar read "THE CONTENT CREATOR", but its phase banner said "DEMONETIZED! / The Sentinel sheds its armor!". "Sentinel" was the tank's older name.

The remake splits that one fight into two:
- **The Sentinel** is the resort's security tank. It keeps the original *tank chassis* attacks (beam with a guide line, twin mortars, plates that blow off).
- **The Content Creator** becomes its own streamer boss (§4.3).

**Tuning:** **300 HP** (new; a mini-boss sized at about 70% of the original 420), **30 bolts**. The weak point is the reactor core under the turret.

| Phase | HP | Attacks (telegraph) |
|---|---|---|
| **1 · SECURITY CHECK** | 100–66% | **Charge Beam** (from the source): the turret tracks slowly (rate 0.6 while telegraphing); a thin red guide line shows the exact lane for **1.25 s**; then the beam fires for 0.9 s (14 damage per 0.3 s tick, r0.45, 30 m). **Mortar Lob**: 2 shells every 3.6 s (14 damage each), lobbed with spread; each landing spot gets a 0.6 s ring (new). |
| **2 · LOCKDOWN** | 66–33% | Plates blow off (the source's 50% moment, moved). **Twin Beam**: a second beam 35° off (from the source), so strafing one way is wrong; telegraph 0.95 s. **Searchlight sweep** (new): a cone sweeps the quarry, and if it catches Bolt, the next mortar pair homes on him (0.5 s "SPOTTED" chime). |
| **3 · RESORT POLICY** | 33–0% | Faster cycles (the source's sponsored timing: 1.1–1.8 s idle). Treads engage: it **rams** across the quarry floor between beam cycles (0.7 s lane decal, 18 damage). 2 Ambassadog adds at the start of the phase. |

- **BREAK feeders:**
  - A shot down the barrel during a beam telegraph (a muzzle crit) adds +25% of the threshold and cancels that beam.
  - A ram into a quarry pillar stuns it for 1.5 s (+40%).
- **Arena use:**
  - The Strip Mine's gravel mounds are cover against beams but not mortars.
  - Zip-line cables cross overhead, so the Tether-Hook (earned on Rustvane) gives escape routes.
- **Title card (new):**
  - `bs.boss.sentinel.intro.01` (glambot): "Pool-deck security, darlings! It checks wristbands, it checks IDs, it checks your PULSE — the RUSTVANE SENTINELLL!"
  - `bs.boss.sentinel.intro.02` (bolt): "Do we have wristbands?"
  - `bs.boss.sentinel.intro.03` (sprocket): "We have a mallet. It's like a wristband, but for its face."
- **No-damage trophy:** **"Wristband Optional"**.

**Barks (new):**

| ID | Speaker | Line | Trigger |
|---|---|---|---|
| `bs.boss.sentinel.bark.01` | pa | GUEST, YOU ARE IN A STAFF-ONLY QUARRY. PLEASE RETURN TO THE FUN. | Aggro |
| `bs.boss.sentinel.bark.02` | pa | LOCKDOWN. THE RESORT IS NOW CLOSED FOR YOUR SAFETY. YOUR SAFETY IS NOW CLOSED. | Phase 2 |
| `bs.boss.sentinel.bark.03` | sprocket | It's got a searchlight. Of course it does. Everything on this planet wants to be looked at. | First searchlight |
| `bs.boss.sentinel.bark.04` | pa | RESORT POLICY: NO RUNNING. NO SWIMMING. NO SURVIVING. | Phase 3 |
| `bs.boss.sentinel.bark.05` | sprocket | Security's down. The Content Creator's pool deck is open. I hope it doesn't want to collab. | Defeat |

---

### 4.3 THE CONTENT CREATOR — Rustvane Canyon boss (the Infinity Lava Pool deck)

**What the original fight did** (`updateMiniBoss` + `makeMiniBoss`, 420 HP, 45 bolts). It's the same tank as §4.2:
- A charge beam: 1.25 s telegraph with a guide line; the beam is 14 damage per tick for 0.9 s.
- Twin mortar lobs every 3.6 s (14 each).
- **At 50%:** the armour plates and ring light blow off ("DEMONETIZED!"); 2 Selfie Sentry adds spawn as a "camera crew" (Frost Peddlers if fought on Glacius in Boss Rush); a **twin beam** joins in; the telegraph shortens to 0.95 s.
- **On death:** `st.l2_glambot` (GLAMBOT defects).
- **Intro scene:** `ccIntro`; title card `introCC`.

**Remake.** The Content Creator is now a streamer bot: a lanky chrome influencer in a ring-light halo, riding a hover-gimbal over the pool deck. It still wields the **"industrial charge beam"** it promised in `cs.ccIntro.02`. **420 HP** (kept), **45 bolts** (kept). Its armour is a **SPOTLIGHT SHIELD** projected by **3 camera drones** (25 HP each). While any drone is filming, the CC takes 25% damage everywhere, even on the weak point. Destroying all three **breaks its armour**: a guaranteed BREAK, then 8 s of normal boss armour. After that, the drones respawn (one per 6 s) at the start of each new phase.

| Phase | HP | Theme | Attacks (telegraph) |
|---|---|---|---|
| **1 · UNBOXING** | 100–66% | It unboxes "mystery boxes" on stream | **Unboxing:** it drops a giant box on the deck (0.8 s shadow decal). After 1.5 s the box opens on one of: 2 Selfie Sentries, a Lifeguard Bot, or a "SPONSORED" bomb (r4, 20 damage, 1.0 s fuse with a jingle). **Charge Beam** (the source's 1.25 s guide line). |
| **2 · COLLAB** | 66–33% | A collab with "a very special guest" | **Twin Beam** (from the source; the second beam comes from a hologram "collab partner", 35° off; 0.95 s). Ambassadog "fans" (3) rush in. **Duet Mortar:** the CC and its hologram lob 2 shells each (14), with landing rings at 0.6 s. |
| **3 · GOING LIVE** | 33–0% | It goes live and chat takes over | **Live Chat:** comment bubbles fall as fragile projectiles (6 damage, shootable) in readable lanes for 4 s (1.0 s "chat is typing…" warning). **LIKE-button floor:** pool tiles light up gold (0.8 s) and then blast upward (16 damage); the dark tiles are safe. **Charge Beam** sweeps across the pool water: the beam boils the pool, and standing in water during the sweep doubles its damage. |

- **Weak point:** the ring-light core (its "face").
- **BREAK feeders:**
  - Destroying all 3 camera drones gives a full BREAK.
  - Each drone kill adds 20% of the threshold on its own.
  - Shooting the falling SPONSORED bomb before it lands detonates it on the CC (+25%).
- **Arena use:**
  - The pool deck is a ring around the Infinity Lava Pool.
  - Cabanas and parasols are cover (from the source's deck dressing).
  - The water is a hazard in phase 3.
  - Ammo orbs spawn at the two cabanas (as in the source).
- **Title card (kept):** `introCC`: `cs.introCC.01` (glambot): "AND NOW — a content creator with FOUR followers and ZERO chill — give it up for THE CONTENT CREATOR!"
- **Intro scene (kept):** `cs.ccIntro.01–05`.
- **Defeat (kept):** `st.l2_glambot.01–05`. GLAMBOT defects and becomes GLAMBOT PRIME.
- **No-damage trophy:** **"Unsubscribed"**.

**Barks.**

| ID | Speaker | Line | Trigger |
|---|---|---|---|
| — | banner | "DEMONETIZED!" / "The Sentinel sheds its armor!" → see the line-change list (the subtitle now reads "The Content Creator sheds its armor!") | All 3 drones destroyed, first time (original banner, moved) |
| `code.updateMiniBoss.04` | sprocket | It brought a CAMERA CREW. Of course it did. | Camera drones spawn (original) |
| `bs.boss.cc.unbox.01` | cc | Okay chat, what's in the box?! Smash that like if you think it's DANGER! | Unboxing |
| `bs.boss.cc.unbox.02` | cc | Oh my GOD it's a bomb. This is SO sponsored. | SPONSORED bomb |
| `bs.boss.cc.collab.01` | cc | Collab time! Say hi to my co-host, who is also me, but with better lighting! | Phase 2 |
| `bs.boss.cc.collab.02` | sprocket | It collabed with a hologram of itself. That's the most honest thing it's done. | Phase 2, first twin beam |
| `bs.boss.cc.live.01` | cc | We are LIVE, scrap-fam! Chat, do your thing! | Phase 3 |
| `bs.boss.cc.live.02` | cc | Chat says "boil the pool." Chat is never wrong. | Pool sweep |
| `bs.boss.cc.drones.01` | cc | My CREW! Who's filming me?! If nobody's filming me, do I even EXIST?! | Drones destroyed |
| `bs.boss.cc.drones.02` | sprocket | No cameras, no shield. It's like a vampire, but for engagement. | Drones destroyed, first time |

---

### 4.4 THE ALGORITHM — Nova Plaza boss (FineTree plaza)

**What the original fight did** (`updateAlgorithm`):
- **Stats:** 520 HP, 45 bolts. A 3 × 4 wall of server racks with blinking LEDs and a smiley face (eye panels plus a segmented mouth); the weak point is the core.
- **Violation zones:** every 3.4 s, it stamps a **VIOLATION zone** under Bolt (a pink ring, r3.4). The ring shrinks over a **1.2 s** telegraph, then fires for 18 damage ("UNPAID FINE!").
- **Summons:** every 8 s, it summons **Meter Maid + HOA Enforcer** pairs (at most 3 adds).
- **At 50%, "TRENDING":** the face turns red; zones come every 2 s; summons every 5 s with up to 5 adds; all its timers run ×0.62.

**Remake.** A smiley-faced server wall at the foot of the FineTree. **520 HP** (kept), **45 bolts** (kept). The brief's hook: fines rain down as attacks, its "recommendations" summon enemies, and you **overload** it by feeding it Cease & Desist notices.

| Phase | HP | Theme | Attacks (telegraph) |
|---|---|---|---|
| **1 · FOR YOU** | 100–66% | Its personalized feed | **Violation Zone** (from the source: under Bolt, 1.2 s shrinking ring, 18 damage, every 3.4 s). **Recommended For You:** a holo-card appears over a spawn pad for 1.0 s ("Because you killed a Meter Maid…") and summons that pair (Meter Maid + HOA Enforcer; at most 3 adds). |
| **2 · TRENDING** | 66–33% | Going viral (the source's TRENDING, moved) | The face goes red and timers run ×0.62 (from the source). **Fine Rain:** paper fines fall from the FineTree in 3 lanes (0.8 s lane glow, 10 damage each, fragile). The walkways reverse every 6 s (a 0.8 s HOA chime). Adds cap at 5. |
| **3 · VIRAL** | 33–0% | The feed runs out of sky (`memo.17`) | **Doomscroll:** the floor becomes a scrolling feed (a conveyor at 3 m/s toward the wall; the walkways stop). **Engagement Bait:** homing "LIKE" orbs (9 damage, homing 1.4, fragile; 0.6 s pre-glow). **Mega-Fine:** one huge zone (r7) with a 1.6 s telegraph, which forces you onto the platforms. |

**OVERLOAD (BREAK feeders).**
- Each Cease & Desist hit on its core adds 4% of max HP to the BREAK meter, and a Class Action adds 10%.
- **Return to Sender:** you don't need Cease & Desist, because Nova might be your first core planet. A mallet hit or a mallet throw on a falling fine (phase 2+) bats it into the wall, adding 4%. Fines shot down near the wall add 1%.
- SERVED adds that die within 6 m of the wall "file a complaint", adding 2%.
- A BREAK here plays as **OVERLOAD**: the screens fill with error text and the smiley turns into a spinning loading wheel for 3.2 s.

- **Weak point:** the core between the racks. The Fine Print marks show its exact spot through the server racks.
- **Arena use:**
  - The plaza's reversing walkways (the Nova traversal mechanic).
  - Lamp-post grapple points.
  - The FineTree hologram is the fine source in phase 2.
  - Platforms around the fountains are the escape in phase 3.
- **Title card (kept):** `introAlgorithm`:
  - `cs.introAlgorithm.01` (glambot): "LADIES, GENTS, AND LEGALLY-DISTINCT ENTITIES! In THIS corner — weighing in at FORTY THOUSAND UNPAID FINES — THE ALGORITHM!"
  - `cs.introAlgorithm.02` (sprocket): "It has a smiley face. On a wall of servers. I hate that it has a smiley face."
- **Defeat:** `coreNova` plays (`cs.coreNova.01–02`).
- **No-damage trophy:** **"Shadowbanned"**.

**Barks.**

| ID | Speaker | Line | Trigger |
|---|---|---|---|
| `code.updateAlgorithm.04` | sprocket | It's SPAWNING them. Classic engagement farming. | Summon (original) |
| `code.updateAlgorithm.05` | sprocket | UNPAID FINE! That is SO not fair! | Hit by a zone (original) |
| — | banner | "TRENDING" / "The Algorithm is going viral!" | Phase 2 (original) |
| `bs.boss.algorithm.feed.01` | pa | RECOMMENDED FOR YOU: MORE OF THIS. | Recommendation |
| `bs.boss.algorithm.feed.02` | pa | BASED ON YOUR INTERESTS: PAIN. | Recommendation |
| `bs.boss.algorithm.feed.03` | pa | YOU MAY ALSO LIKE: A FINE. | Fine Rain |
| `bs.boss.algorithm.overload.01` | sprocket | Feed it paperwork! It can't process legal documents. Nothing can! | First C&D on the core |
| `bs.boss.algorithm.overload.02` | pa | ERROR: CONTENT POLICY VIOLATES CONTENT POLICY. | OVERLOAD (BREAK) |
| `bs.boss.algorithm.viral.01` | pa | YOU HAVE REACHED THE END OF THE FEED. GENERATING MORE FEED. | Phase 3 |
| `bs.boss.algorithm.viral.02` | sprocket | The floor is a timeline now. Don't look at it too long, you'll start agreeing with it. | Phase 3, the Doomscroll starts |

---

### 4.5 THE RETENTION SPECIALIST — Glacius Vault boss (the Master Freezer)

**What the original fight did** (`updateRetention`):
- **Stats:** 520 HP, 45 bolts. A cryo-suit account manager on a floating podium, with a headset, a big pink **RENEW?** button and an ice fringe; the weak point is the core.
- **Movement:** it hovers 1.2 m up, keeps 7–11 m away and strafes.
- **Attacks:**
  - **Frost Breath:** a 0.7 s telegraph (arms out); then a 1.3 s cone (11 m, a dot of 0.6) that builds player frost at 0.9/s and deals 5 every 0.35 s. At full frost, Bolt is **FROZEN** for 1.1 s ("Mash any direction to thaw").
  - **Ice Spikes:** a 0.85 s telegraph. 5 spots (7 in phase 2): one under Bolt plus random ones within 6 m; r2.3 each, 15 damage and a knock-up.
  - **The Pitch:** 3 homing "special offers" (5 in phase 2): 9 damage each, homing 1.6.
- **Phase 2 (under 50%), "CANCELLATION FEE":**
  - A ring of 10 fragile ice shards (10 damage each).
  - A blizzard gust.
  - **Chillsplitter adds:** 2 every 12 s, at most 2. (The code comment says "popsicle adds", but the code spawns Chillsplitters.)

**Remake.** **520 HP** (kept), **45 bolts** (kept). The arena is the Master Freezer: an icy round chamber ringed by occupied cryo-pods, with a floating central podium.

| Phase | HP | Theme | Attacks (telegraph) |
|---|---|---|---|
| **1 · RETENTION OFFER** | 100–66% | Please don't go | Frost Breath (0.7 s); Ice Spikes (0.85 s, 5 spots); The Pitch (3 homing offers, plus a new 0.4 s headset-tap telegraph). **Ice-spike patterns** (new readable sets): **Line** (a row of 6 toward Bolt), **Cross** (on Bolt), **Ring** (around Bolt, with the centre safe). The pattern name flashes on its podium screen. |
| **2 · CANCELLATION FEE** | 66–33% | Fine, there's a fee (the source's 50% moment, moved) | A ring of 10 fragile shards (from the source; 0.6 s pre-glow added). The Pitch goes to 5. 7-spot spike patterns. Chillsplitter adds (2 every 12 s). A blizzard gust every 15 s (the Glacius rotating wind). |
| **3 · CANCELLATION FLOW** | 33–0% | The cancellation menu as a maze | Ice walls rise and **reroute the arena into a maze** made of the cancellation flow: walls stencilled "ARE YOU SURE?", "WAIT! SPECIAL OFFER", "TELL US WHY YOU'RE LEAVING", "CONNECTING YOU TO AN AGENT". He floats above the maze, pitching offers and dropping spike patterns into its corridors. Every 12 s the maze **reroutes** (walls slide; a 1.0 s frost-crack telegraph, and any wall about to move glows). The **"CONFIRM CANCELLATION" pad** sits at the maze's current exit. |

- **Weak point:** the core behind the RENEW? button. In phase 3, the button itself is the target from below.
- **BREAK feeders:**
  - Reaching and slamming the **CONFIRM CANCELLATION** pad in phase 3 forces a full BREAK: he drops to floor level, stunned, and the maze walls lower for 3.2 s. After that, a new maze builds with a new exit.
  - Shattering the 10-shard ring (each shard shot adds 3% of the threshold).
  - Freeing a pod occupant during the fight (the Premium Waker rules apply here) adds 15% of the threshold. It's a "retention failure."
- **Arena use:**
  - The ice-slip floor (about 72% acceleration cut, from Glacius).
  - Metal grates stop Chillsplitters.
  - Pods with thaw panels can be hacked by his Frost Peddler "assistants" in phase 2.
- **Title card (new):**
  - `bs.boss.retention.intro.01` (glambot): "Coming to you LIVE from minus forty! He has never lost a customer — mostly because they're FROZEN — THE RETENTION SPECIALIST!"
  - `bs.boss.retention.intro.02` (sprocket): "His RENEW button is bigger than his head. That's not a feature. That's a cry for help."
- **Defeat:** `coreGlacius` plays (`cs.coreGlacius.01–04`, RECALL).
- **No-damage trophy:** **"Cancellation Confirmed"**.

**Barks.**

| ID | Speaker | Line | Trigger |
|---|---|---|---|
| `code.updateRetention.02` | retention | Hi there! I see you're trying to LEAVE. Before you go, can I interest you in staying? Forever? | Aggro (original) |
| `code.updateRetention.05` | retention | You know what? FINE. Enjoy the EARLY TERMINATION FEE. | Phase 2 (original) |
| `code.updateRetention.06` | retention | Have you considered our ANNUAL plan? | The Pitch (original) |
| `code.updateRetention.07` | retention | Just three easy payments! | The Pitch (original) |
| `code.updateRetention.08` | retention | This offer expires when YOU do. | The Pitch (original) |
| `code.updateRetention.11` | sprocket | He’s pulling in the SUBSCRIBERS. They look cold and angry. | Adds (original) |
| — | banner | "CANCELLATION FEE" / "He is taking this personally" · "FROZEN!" / "Mash any direction to thaw" | Original banners |
| **`bs.boss.retention.dm.01`** | retention | **Nobody cancels. I learned that from the best.** | Phase 3 start, as the maze rises (brief §5.4, the Darkmatter seed) |
| `bs.boss.retention.flow.01` | retention | To cancel, please navigate to the cancellation page. The cancellation page has been moved. | Phase 3, first reroute |
| `bs.boss.retention.flow.02` | retention | Are you SURE? Are you sure you're sure? Let me transfer you to someone who's even surer. | The player nears the exit pad |
| `bs.boss.retention.flow.03` | retention | Your call is important to us. Please hold. Forever. | A maze reroute |
| `bs.boss.retention.flow.04` | sprocket | He turned the cancellation menu into an actual maze. I've seen this before. On every website ever. | Phase 3, 10 s in |
| `bs.boss.retention.flow.05` | retention | ...Cancellation confirmed?! That button wasn't supposed to WORK! | Exit-pad BREAK |

---

### 4.6 COMPOST KING — Verdant Sink boss (under the leaking Mega-Harvester), with the mercy ending

**What the original fight did** (`updateCompostKing`):
- **Stats:** 560 HP, 45 bolts. A mound of mossy rot with a junk crown, two eyes, two arms, and a core.
- **Movement:** it lumbers toward Bolt (3.2 m/s; 5 enraged) and stops at 6 m.
- **Attacks:**
  - **Slam:** under 8 m, every 3 s (1.8 s enraged). A 20-damage hit if Bolt is within 7 m, with knockback. It had **no real telegraph**: the arm raised for 0.22 s and the damage landed on the same frame.
  - **Spore Volley:** 3 globs in a 0.28 rad fan (12 damage each, r2 blast) every 3.6 s (2 s enraged). Also no telegraph.
- **NEGOTIATION at 30%:**
  - He stops and becomes invulnerable for 4.2 s.
  - Corn-voice: "WAIT. WAIT. Let us be reasonable. I am not a monster. I am a COMMUNITY. We could... unionize?"
  - Damage shows "let’s talk!".
  - Then "NEGOTIATION FAILED" / "He composts you out of SPITE" and "Fine. FINE! Then you get the ROT!", and he's enraged until death.
- **There was no mercy option.** The `coreVerdant` scene afterwards says the swamp handed the core over "once I patched the machine's coolant leak." The leak itself was a separate side quest (q7b, the coolant sealant cores).

**Remake.** **560 HP** (kept), **45 bolts** (kept). The fight is a **plumbing puzzle under pressure**. The arena is the flooded pit under the Mega-Harvester (HR-9). Three **coolant leaks** spray from cracked pipes on the arena walls (a glowing coolant jet; standing in it deals 4 every 0.5 s). Every open leak **heals the King 1% of max HP per second**, and it makes him thrash. To **seal** a leak, hit its valve wheel with the mallet three times (it's a big readable wheel; a mallet throw counts) while he attacks.

| Phase | HP | Theme | Attacks (telegraph) |
|---|---|---|---|
| **1 · ROTTING** | 100–60% | He's upset | **Slam** (now **0.6 s**: arm raised high, a wet rumble, a green glow at the impact point, then 20 damage in r5 at 3 m in front). **Spore Volley** (now a **0.5 s** chest-puff telegraph, then 3 globs). **Leak 1** is open. |
| **2 · THRASHING** | 60–30% | The leaks burst | **Leaks 2 and 3** open (each one he's near re-opens if it's already sealed: the pipe cracks with a 1.0 s hiss telegraph). **Thrash:** a 360° arm sweep (0.7 s wind-up, 16 damage, jumpable). **Murk Wave:** a slow water wave across the pit (0.8 s, 10 damage, plus SLOWED). |
| **3 · NEGOTIATION** | at 30% | He wants to talk (the source's moment, kept) | He stops, becomes invulnerable and pleads (`code.updateCompostKing.02`). **The plea lasts 8 s** (it was 4.2 s), so there's time to choose. What happens next depends on the leaks and on what the player does. |

**The mercy rule (resolves brief §6 "mercy ending kept"):**

| Condition at the negotiation | Player action during the 8 s plea | Result |
|---|---|---|
| All 3 leaks sealed | **Lower your weapon:** holster (hold the quick-swap input for 1 s) and interact with the King ("SHAKE HANDS", 1.5 s hold) | **MERCY ENDING.** He stands down. The swamp calms (the glow dims, frogs sing), and he hands over the Keystone Core. `coreVerdant` plays, and its line "once I patched the machine's coolant leak" now describes exactly what you did. Reward: 45 bolts + 60 strike-fund bolts, the **"Collective Bargaining"** trophy, and the King appears later as an NPC at the Union Hall (Local 404). |
| All 3 leaks sealed | Keep attacking, or let the plea time out | "NEGOTIATION FAILED" (from the source). He's **enraged** for the rest of the fight (the source's ×0.6 timers, 5 m/s), but no longer heals. Kill him: `coreVerdant` plays. |
| Any leak still open | Anything | The plea times out into "NEGOTIATION FAILED", because he won't trust you while the swamp is still being poisoned. While enraged, every open leak heals him **2%/s**. Seal them, then finish him. (Mercy is no longer possible.) |

- **Weak point:** the core in his chest mound. It flares when he slams.
- **BREAK feeders:**
  - Sealing a leak gives +35% of the threshold and staggers him (he flinches at the pressure drop).
  - A Root Canal plant or Ice Wall placed in front of a leak jet briefly plugs it (counts as +10%).
- **Arena use:**
  - Murk pools (slow + ticks).
  - Bounce mushrooms for reaching the high valve (leak 3).
  - Picket Corn watch from the rim and cheer for sealing. If you're in the mercy path they chant "DEAL, DEAL, DEAL."
- **Title card (kept):** `introCompost`:
  - `cs.introCompost.01` (glambot): "In the swamp corner — six years of moss, one very good attitude — THE COMPOST KING!"
  - `cs.introCompost.02` (sprocket): "He looks less like a boss and more like a misunderstanding that got big."
- **No-damage trophy:** **"Zero Waste"**. The mercy trophy is separate: **"Collective Bargaining"**.

**Barks.**

| ID | Speaker | Line | Trigger |
|---|---|---|---|
| `code.updateCompostKing.04` | corn | WAIT. WAIT. Let us be reasonable. I am not a monster. I am a COMMUNITY. We could... unionize? | Negotiation (original) |
| `code.updateCompostKing.07` | corn | Fine. FINE! Then you get the ROT! | Negotiation failed (original) |
| — | banner / dmg-num | "NEGOTIATION" / "The Compost King would like to talk" · "NEGOTIATION FAILED" / "He composts you out of SPITE" · "let’s talk!" (when hit while pleading) | Original |
| `bs.boss.compost.leak.01` | sprocket | Those pipes are poisoning him. He's not attacking us — he's in PAIN. Seal the leaks! | Leak 1, 5 s in |
| `bs.boss.compost.leak.02` | corn | ...That. Felt. Better. | A leak sealed |
| `bs.boss.compost.leak.03` | corn | NO! The pipes! THE PIPES! | Phase 2, the leaks burst |
| `bs.boss.compost.mercy.01` | sprocket | Bolt. Put the mallet down. He just wants the leaking to stop. | Plea start, all leaks sealed |
| `bs.boss.compost.mercy.02` | corn | You... sealed it. All of it. Nobody has ever sealed it. | Mercy accepted |
| `bs.boss.compost.mercy.03` | corn | Take the core. Take it! And tell the harvester's owners the swamp sends its regards. Rudely. | Mercy ending, before `coreVerdant` |
| `bs.boss.compost.mercy.04` | bolt | Best negotiation I've ever been in. Also the only one. | Mercy ending |
| `bs.boss.compost.enrage.01` | corn | You talk peace with the pipes still OPEN?! | Plea while any leak is open |

---

### 4.7 GREETER PRIME — Grand Galleria boss (Guest Services / the Anchor Store vault)

**What the original fight did** (`updateGreeter`):
- **Stats:** 540 HP, 45 bolts. A huge blue doorman bot with a yellow face, waving arms, a **shopping cart welded to its front** as a ram, and a core.
- **Movement:** clamped to the Anchor Store interior. Its arms wave at all times (faster when enraged, under 45%).
- **Attacks:**
  - **Cart charge:** at more than 7 m, a 0.7 s telegraph (0.45 s enraged; it rears back with the cart rattling). Then a 0.9 s ram at 15 m/s (19 enraged) for 18 damage.
  - **WELCOME WAVE:** under 10 m, an instant ground shockwave (14 damage, jumpable).
  - **Coupon Storm:** a radial burst of 7 fragile coupons (10 enraged), 8 damage each.
  - **PA barks:** "WELCOME!", "VALUED GUEST DETECTED.", "HAVE A DAY!".
- **On death:** "CUSTOMER SERVICE, CONCLUDED", and the **Clause 44 ledger** appears (`galleriaLedger`).
- **Intro:** `cs.galleriaGreeter.01–04` ("UNGREETED. Correcting."). It had no GLAMBOT card.

**Remake.** **540 HP** (kept), **45 bolts** (kept). Per the brief: an eternal doorman greeting you to death, "UNGREETED → CORRECTING", waving-arm sweeps, and breaking the "WELCOME" sign generators.

**The HOSPITALITY FIELD.** Three neon **"WELCOME" sign generators** (50 HP each) hang high on the Anchor Store walls. While at least one is lit, Greeter Prime has a hospitality field: it takes 25% damage everywhere, including its core. Breaking all three drops the field and forces a BREAK. The signs are high, so a mallet boomerang throw, the Tether-Hook (to reach the catwalk), or any gun can hit them. The signs reboot at each phase change.

| Phase | HP | Theme | Attacks (telegraph) |
|---|---|---|---|
| **1 · WELCOME** | 100–66% | Greeting is mandatory | **Cart Charge** (0.7 s, from the source). **Welcome Wave** (now a **0.6 s** telegraph: arms spread wide, a "WELCOME!" PA line, a gold ground ring; then the shockwave, 14 damage). **Coupon Storm** (0.4 s jingle; 7 coupons). |
| **2 · CORRECTING** | 66–45% | You are UNGREETED, and it's correcting that | **Waving-Arm Sweeps:** alternating low and high arm sweeps across the floor. The **low** sweep (0.6 s, the arm drops to the floor with a whoosh-up sound) means jump. The **high** sweep (0.6 s, the arm rises to head height with a whoosh-down sound) means slide under. 16 damage. A **Charge Chain:** two cart charges back to back. |
| **3 · HAVE A DAY** | 45–0% | Enraged (the source's 45% threshold, kept) | The source's enraged speeds (a 0.45 s charge telegraph, 19 m/s, 10 coupons, faster waves). Two of the three signs reboot. **Grand Opening:** every 20 s, a confetti-cannon barrage of 3 lanes (0.8 s lane glow, 12 damage) while it waves frantically. **Politeness Lock** (new): it will always stop to greet a **Middleman drone** or **subsidiary** first, for 1.5 s ("VALUED GUEST DETECTED"), which is a free punish window. |

- **Weak point:** the core behind the cart (exposed when it rears back to charge, and during sweeps).
- **BREAK feeders:**
  - Breaking all lit signs (a full BREAK).
  - A charge into a wall stuns it for 1.0 s (+30% of the threshold).
  - Each coupon shot down within 4 m of it (+2%).
- **Arena use:**
  - The Anchor Store vault interior (the source clamps it to x ±21, z −116…−85).
  - Display racks are cover, and its charges destroy them.
  - Escalator catwalks reach the signs.
  - Mannequins line the walls but **can't move during the boss fight** ("store policy").
- **Intro scene (kept):** `cs.galleriaGreeter.01–04` plays first.
- **Title card (new):**
  - `bs.boss.greeter.intro.01` (glambot): "The Galleria's longest-serving employee, darlings! Eleven years, zero breaks, one unbroken wave — GREEEETER PRIIIIME!"
  - `bs.boss.greeter.intro.02` (bolt): "It's still waving. Why is it still waving?"
  - `bs.boss.greeter.intro.03` (sprocket): "Because nobody ever told it to stop. That's the saddest sentence in this mall."
- **Defeat:** the banner "CUSTOMER SERVICE, CONCLUDED" / "The vault is open. Grab the ledger!" (from the source), then `galleriaLedger`.
- **No-damage trophy:** **"Ungreeted"**.

**Barks.**

| ID | Speaker | Line | Trigger |
|---|---|---|---|
| `code.updateGreeter.01` | pa | WELCOME! | Charge / wave (original) |
| `code.updateGreeter.02` | pa | VALUED GUEST DETECTED. | Charge (original); Politeness Lock |
| `code.updateGreeter.03` | pa | HAVE A DAY! | Charge (original) |
| `bs.boss.greeter.correct.01` | pa | GUEST REMAINS UNGREETED. ESCALATING GREETING. | Phase 2 |
| `bs.boss.greeter.correct.02` | pa | PLEASE ACCEPT THIS WAVE. PLEASE ACCEPT THIS WAVE. PLEASE ACCEPT THIS WAVE. | A sweep chain |
| `bs.boss.greeter.signs.01` | sprocket | The WELCOME signs are powering its shield. Break the welcome. I can't believe I said that. | Fight start, after 6 s |
| `bs.boss.greeter.signs.02` | pa | WELCOME SIGNAGE OFFLINE. GUESTS MAY NOW FEEL UNWELCOME. | All signs down |
| `bs.boss.greeter.day.01` | pa | GRAND OPENING. GRAND OPENING. THIS STORE HAS BEEN CLOSED FOR ELEVEN YEARS. GRAND OPENING. | Phase 3 |
| `bs.boss.greeter.defeat.01` | pa | ...THANK YOU FOR VISITING. COME AGAIN. ...PLEASE. | Defeat |

---

### 4.8 EXCAVATRON PRIME → CHAIRMAN GRINDSTONE — Core Foundry final boss (the Executive Bridge)

**What the original fight did** (`updateFinalBoss`):
- **Stats:** 950 HP, 0 bolts (the ending follows). A multi-phase mining mech: legs, a swaying torso, shoulder arm cannons, chest plates and shoulder spikes as armour, an angry eye, and a chest core. Grindstone pilots it.
- **Phase 1:**
  - **Rockets:** 3 homing rockets (13 damage each, homing 1.4, 9 m/s, 0.45 s apart). No telegraph.
  - **Stomp:** 1.0 s (the torso rises, with a ground warning ring of r8.5). The shockwave (18 damage) is jumpable, and the **core is exposed for 3 s** afterwards.
  - It alternates the two.
- **Phase 2 (under 50%), "EXCAVATRON ENRAGED! / Armor plating destroyed!":**
  - The armour blows off.
  - 4 rockets (homing 2.2).
  - A double shockwave (18 + 14).
  - **Sweep:** a 3.5 s rotating mining beam (24 m, 10 per tick).
  - **Weld Wasp adds:** 2 every 11 s, at most 3.
- **Phase 3 (under 25%), "LIQUIDATION MODE / Grindstone is selling the planet out from under you":**
  - A ring burst of 8 shells (12 damage).
  - A **perpetual orbiting beam** that never stops (22 m, 8 per tick).
  - 6 rockets (0.32 s apart).
  - The stomp telegraph shortens to 0.7 s.
- **Story:** `gsIntro` (before), `l3_brick` (Clause 44, before), title card `introGrindstone`, then `startEnding` → `cs.ending.01` "This isn't over! I'll pivot! I'll REBRAND! Grindstone 2.0 — now with LESS mercy and MORE ads!"

**Remake.** **950 HP** (kept), and the original 50% / 25% thresholds are kept. The brief asks for armour plates, an enrage, and a final **"Grindstone 2.0 rebrand"** phase. Phase 3 is the *public beta* of that rebrand. When it fails, `cs.ending.01` still works as written: he promises the real launch.

| Phase | HP | Theme | Attacks (telegraph) |
|---|---|---|---|
| **1 · EXCAVATION** | 100–50% | The mech runs on burned venture capital | **Rockets** ×3 (new **0.5 s** telegraph: the shoulder pods open and glow red, with a lock-on beep). **Stomp** (1.0 s, r8.5 ring; the core is exposed for 3 s afterwards, from the source). **Armour plates:** 2 chest plates + 2 shoulder spikes. The **core** only takes boss-armour damage while the chest plates are on. Plates can be stripped early: the mallet in the post-stomp window, Buzzkill, or Clearance Rack markdown. Each stripped plate adds +20% BREAK. |
| **2 · ENRAGED** | 50–25% | "EXCAVATRON ENRAGED!" (from the source) | All remaining plates blow off. Rockets ×4 (homing 2.2). A double shockwave (18 + 14). **Sweep Beam** (new **0.8 s** pre-light: the emitter glows and a thin guide arc paints the floor), 3.5 s, 10 per tick. Weld Wasp adds (2 every 11 s, at most 3). **Shareholder Call** (new): the bridge screens show The Board's stock graph, and if it goes up (when Bolt takes damage), the mech gains +10% speed for 5 s. |
| **3 · GRINDSTONE 2.0 (PUBLIC BETA)** | 25–0% | A mid-fight rebrand: the source's LIQUIDATION MODE, plus the brief's rebrand | The hull **repaints** live (a wipe from grey to a garish 2.0 palette with a new logo), and **ad billboards slam down** into the arena (1.0 s shadow decal, 20 damage). They become new cover, and they show ads. **Liquidation sweep** (from the source): a perpetual orbiting beam (22 m, 8 per tick), and it always has a visible guide arc. **Rockets ×6** (0.32 s apart, 0.5 s pod-open telegraph). **Stomp** at a 0.7 s telegraph. **Ring burst** of 8 shells (now with a 0.6 s pre-glow). **The cockpit opens:** Grindstone is visible and shouting. **His seat is a second weak point** (crit ×2.5, and it can't be broken). |

- **Weak points:**
  - The chest core: always, through the boss armour; exposed for 3 s after each stomp.
  - In phase 3, the open cockpit too.
- **BREAK feeders:**
  - Each plate stripped: +20% of the threshold.
  - **Billboard Crash** (phase 3): luring a rocket volley into an ad billboard (the rockets home onto Bolt and hit the billboard if he's behind it) drops the billboard on the mech's leg, adding +40%.
  - A stomp-window core hit counts double, as in the shared rules.
- **Arena use:**
  - The Executive Bridge: a long deck over the Foundry with crushers at the edges (Foundry traversal).
  - Vent updrafts that GLAMBOT jammed open (`st.l3_vent`) to dodge shockwaves vertically.
  - Billboards in phase 3.
- **Pre-fight (kept):** `cs.gsIntro.01–07` and `cs.l3_brick.01–06`.
- **Title card (kept):** `introGrindstone`: `cs.introGrindstone.01` (glambot): "And the MAIN EVENT! The final invoice! The convenience that conquered a galaxy — CHAIRMAN GRINDSTOOOONE!"
- **Rebrand phase card (new):**
  - `bs.boss.grindstone.rebrand.01` (glambot): "BREAKING NEWS, darlings! A MID-FIGHT REBRAND! Please welcome — in public beta — GRINDSTONE TWO-POINT-OHHH!"
  - `bs.boss.grindstone.rebrand.02` (grindstone): "New logo. Same me. Now with ad space on the armour. Q4 is going to be EXTRAORDINARY."
  - `bs.boss.grindstone.rebrand.03` (sprocket): "He rebranded in the MIDDLE of the fight. That is the most Grindstone thing that has ever happened."
- **Defeat:** `startEnding` → `cs.ending.01–08` (unchanged).
- **No-damage trophy:** **"Clean Audit"**.

**Barks.**

| ID | Speaker | Line | Trigger |
|---|---|---|---|
| — | banner | "EXCAVATRON ENRAGED!" / "Armor plating destroyed!" · "LIQUIDATION MODE" / "Grindstone is selling the planet out from under you" · hint "Shockwave — JUMP! Then blast the glowing core!" | Original (the LIQUIDATION banner plays as the phase 3 subtitle under the 2.0 card) |
| `bs.boss.grindstone.p1.01` | grindstone | Every stomp you dodge is a stomp I'll bill you for. | Phase 1, a dodged stomp |
| `bs.boss.grindstone.p1.02` | grindstone | Those plates cost more than your planet. Stop TOUCHING them. | A plate stripped |
| `bs.boss.grindstone.p2.01` | grindstone | The shareholders are WATCHING, mechanic. Do try to bleed on camera. | Phase 2 |
| `bs.boss.grindstone.p2.02` | sprocket | His stock goes up when you get hit. Stop getting hit! I'm not paying for his yacht! | The first Shareholder Call |
| `bs.boss.grindstone.p3.01` | grindstone | Everything must go! The planet! The workforce! YOU! | Phase 3, after the card |
| `bs.boss.grindstone.p3.02` | grindstone | Do you like the new logo? It tested very well with people who were paid to like it. | Billboards drop |
| `bs.boss.grindstone.p3.03` | bolt | Nice logo. Shame about the product. | First cockpit crit |
| `bs.boss.grindstone.p3.04` | sprocket | Billboard on the leg! He's being held back by his own advertising! | Billboard Crash |

---

## 5. Enemy roster per planet

The planet order follows `CAMPAIGN = [0,1,5,6,7,9,2]`. Nova, Glacius and Verdant can be played in any order.

| Planet | Original enemies (kept) | NEW enemy | Mini / boss | Elites appear (campaign) | NG+ bleed-ins (22% of spawns) |
|---|---|---|---|---|---|
| **Scrapheap Junction** | Scrap Mutt, Tinker Turret, Vulture Drone | Lien Crawler | **Repo-Tron** | None (home planet of all) | Ambassadog, Lifeguard Bot, Selfie Sentry, HR Drone, Weld Wasp, Slag Golem (the source's NG+ pool) |
| **Rustvane Canyon** | Ambassadog, Selfie Sentry, Lifeguard Bot | Review Bomber | **Rustvane Sentinel** (mini), **The Content Creator** | Scrapheap types | The source's NG+ pool + Lien Crawler |
| **Nova Plaza** | Meter Maid, HOA Enforcer, Surge Drone | Zoning Board | **The Algorithm** | Scrapheap, Rustvane | Review Bomber, Lien Crawler, Coupon Crier |
| **Glacius Vault** | Chillsplitter, Popsicle, Frost Peddler | Premium Waker | **The Retention Specialist** | Scrapheap, Rustvane (plus Nova and Verdant if already cleared) | Meter Maid, Selfie Sentry, HR Drone |
| **Verdant Sink** | Gloomstalker, Spore Lobber, Pollinator | Picket Corn (neutral) | **Compost King** | Scrapheap, Rustvane (plus Nova and Glacius if already cleared) | Chillsplitter, Ambassadog, Weld Wasp |
| **Grand Galleria** | Mannequin, Coupon Crier | Return Desk Mimic | **Greeter Prime** | All earlier planets | Meter Maid, HOA Enforcer, Surge Drone, Gloomstalker |
| **Core Foundry** | Slag Golem, HR Drone, Weld Wasp, Statue (prop) | Middle Manager | **Excavatron Prime → Chairman Grindstone** | All earlier planets | Everything except the neutral Picket Corn |

**Boss adds:**

| Boss | Adds |
|---|---|
| Repo-Tron | Scrap Mutts |
| Rustvane Sentinel | Ambassadogs |
| The Content Creator | Selfie Sentries, a Lifeguard Bot from a box, Ambassadog "fans" |
| The Algorithm | Meter Maid + HOA Enforcer |
| The Retention Specialist | Chillsplitters, Frost Peddler assistants |
| Compost King | None (the leaks are the pressure) |
| Greeter Prime | None (the coupons and confetti are the pressure) |
| Excavatron Prime | Weld Wasps |

**Boss Rush (GLAMBOT Colosseum, brief §8)** now includes every campaign boss, in campaign order:

| Order | Boss |
|---|---|
| 1 | Repo-Tron |
| 2 | Rustvane Sentinel |
| 3 | The Content Creator |
| 4 | The Algorithm |
| 5 | The Retention Specialist |
| 6 | Compost King |
| 7 | Greeter Prime |
| 8 | Excavatron Prime |

The source's `BOSS_RUSH` was only `['miniboss', 'algorithm', 'compostking']`. The Compost King's mercy path is unavailable in Boss Rush: he's always "too far gone for the bracket." The Content Creator's Glacius-adds swap (Frost Peddlers instead of Selfie Sentries, from the source's `levelIndex === 6` check) is kept as a Boss Rush variant.

---

## 6. Player debuffs applied by enemies

| Debuff | Source enemy | Effect | Duration | Cleared by |
|---|---|---|---|---|
| **LIEN** | Lien Crawler | Taunts fail; turrets fire 30% faster at Bolt; +15% damage taken; 1 in 5 bolts is garnished | 8 s (elite 14 s) | Killing the crawler, or slamming it |
| **BLINDED** | Selfie Sentry | A white-out with a vignette | 1.2 s | Turning away before the flash |
| **FROZEN (player)** | Retention Specialist breath, Popsicle frost slug, Frost Peddler | Can't act; mash a direction to thaw (thaw is 2.4× faster with input, from the source) | 1.1 s | Mashing; fire and Magma patches |
| **CLAMPED** | Meter Maid (vs a stationary Bolt) | Can't move; can aim and shoot | 1.0 s | Mashing (0.6 s) |
| **HELD** | Return Desk Mimic | Can't act; takes 5 every 0.5 s | 1.5 s | Mashing (0.8 s), or shooting the tongue |
| **PAPERWORK** | HR Drone notice | −20% dash distance | 4 s | Expires |
| **SLOWED (player)** | Lifeguard puddle, Zoning Board zone, Compost Murk Wave | −20 to −30% move speed | While inside / 3 s | Leaving the area |
| **REPOSSESSED** | Repo-Tron magnet | The equipped gun is taken | Until the hook is smashed | Smashing the crane hook |

All debuffs show as stamps on Bolt's health bar, using the same visual language as SERVED on enemies. Sprocket barks the first time each one lands.

---

## 7. Source notes and decisions in this doc

| Topic | Source | This doc |
|---|---|---|
| Unimplemented v9 flags | `surge`, `freeze`, `cloak`, `burrow` and `buffer` were declared but not coded | Implemented as designed |
| Sentinel vs Content Creator | One `miniboss` tank, named THE CONTENT CREATOR, with the banner "The Sentinel sheds its armor!" | Split into the Rustvane Sentinel (mini, 300 HP, the tank kit) and the Content Creator (the streamer, 420 HP, camera drones) |
| Retention adds | The comment says "popsicle adds"; the code spawns `chillsplit` | Chillsplitters (the code wins) |
| Fast telegraphs | Mutt/Dog/Maid pounce 0.32 s, Lifeguard whistle 0.16 s, Compost slam ~0.22 s, Compost spores 0 s, Greeter wave 0 s, Excavatron rockets 0 s, sweep beam 0 s | Raised to 0.4–0.8 s per §1.2 |
| Two-phase bosses | Repo-Tron, Retention, CC, Greeter and Algorithm had 1 threshold; Excavatron had 2 | All bosses have 3 phases; the original thresholds are reused where possible |
| Boss-rush roster | 3 bosses | All 8 |
| Compost mercy | Not a mechanic in v14 | The 8 s plea + all leaks sealed + holster-and-handshake |
| In-code boss lines | Not in `lines_index.json` | Given proposed IDs `code.<function>.<nn> (tools/extract_code_lines.mjs)`, text verbatim |
