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

**Visual variants (outfit kits).** Every kit is built on the same shared rig, hitboxes and animation set (§2.1.1); only the clothes, gear pieces and skin tone change. Kits per map: `enemies.json ganger.variants_by_map` (default `variants` = Map 0); the kit geometry is `anim.json kits` + `zombie_body.gd`.
| Variant ID | Who they were | Silhouette | Spawn weighting |
|---|---|---|---|
| `ganger_soldier` | Wehrmacht guard garrison, Volkssturm call-ups | Stahlhelm and greatcoat, wide at the shoulders. Some still wear rifle slings. | Map 0: 60%. Map 1: 30% |
| `ganger_miner` | Salt miners, the civilian workforce from before the war | Soft cap with carbide lamp (unlit, cracked lens), leather apron, hunched | Map 0: 15%. Map 1: 30% |
| `ganger_labstaff` | Projekt Wiederkehr technicians, orderlies | Long coat (stained grey, not white), rubber gloves, some wear gas-mask goggles pushed up | Map 0: 5%. Map 1: 15% (Lab Wing 40%) |
| `ganger_villager` (Map 0) | Crossroads villagers: the innkeeper's people, carters, a farm wife | Wool jacket and waistcoat or a long skirt and shawl, flat cap, scarf, apron; men and women | Map 0: 20% |
| `ganger_technician` (Map 1) | Projekt Wiederkehr fitters and gallery technicians | Grey coverall with a tool belt, rubber boots, a plain P·W·K armband, cap, tool pack | Map 1: 25% |
| `ganger_sailor` / `ganger_dockworker` (Map 2) | Kriegsmarine ratings; Totenhafen dock hands | Navy pea jacket with brass buttons and the collar flap, round cap; knit jumper, oilskin and hood, rubber boots, a rope over the shoulder | Map 2: 40% / 35% (soldiers 25%) |
| ~~`ganger_laborer`~~ | **Retired (MZ, T-041; v2 §0.1): forced laborers are never zombies.** The Map 1 Intake keeps them as story only. | | |

**Common features.** Every Gänger has violet eye-glow (emissive, blooms in fog). Violet-amber hairline cracks run from the eyes and the hands, because Nachtglas spreads along the last nerves to fire. The cracks brighten as the round number climbs (a material parameter `crack_intensity = clamp(r/30, 0.1, 1.0)`), which also tells the player the round is getting harder.

**The Marke, the weak point (UPDATE 09 §1, T-137; `enemies.json "marke"`, `docs/U09_CONTRACTS.md` C1).** The dead are not a sickness: every one of them was *marked*. Darkmatter's chip under the skin (CANON §2.2, LORE §2.5) shows on every Gänger as a small violet glint, pulsing with the infection shader's hum (`glow_min 0.25 .. glow_max 1.0` with `gl_hum`, brighter with `gl_round_k`), in the **right hand** between thumb and forefinger (`hand_chance` 60%) or the **forehead** above the right brow (40%). The site is picked from the zombie's `net_id` (`ZombieBody.marke_site_for`), so a co-op puppet shows the same one as the host without anything being sent. It is a `"marke"` hitbox (limb `&"marke"`), a `hitbox_m` 0.07 m cube on bone `RightHand` or the front of `Head`, outside the limb layout (`ZombieBody.HITBOXES` is untouched; the Marke box joins `hitbox_rids()` so a shot never lands twice on one body). A hit on it does **×1.5** (`damage_mult`) on top of the weapon's multiplier for the host limb (a hand mark is an arm hit, a forehead mark a head hit: armour, wounds, flinch, the death clips and the headshot path all follow that limb). A kill from a Marke hit emits `GLBus.marke_kill`, counts in `GameState.stats[&"marke_kills"]`, tints the hitmarker violet, and pays **25 Scrip** (`scrip_bonus`) through `Economy.award` with a "THE MARK" slip (Double Scrip applies; **none in Classic Rules**, the weak point stays). A severed right arm takes the hand's mark with it. **No Marke:** the bosses (the Foreman has no rig, the Screamer and the homage bosses are `"marke": false`), the Account Manager's shield cells and the Backorder construct (Darkmatter's own inventory was never a customer). The Suited keep theirs on the hand (the visor stays the head's weak point). Forced labourers were never marked and are never zombies (v2 §0.1). Tests: `test_marke.gd`.

#### 2.1.1 Animation and body (MZ, T-041; `docs/ZOMBIE_ANIM_SPEC.md`, `data/gravelight/anim.json`)
- **Rig:** one shared humanoid `Skeleton3D` (`zombie_rig.gd`, 19 bones named after `SkeletonProfileHumanoid` with a `BoneMap`, identity rests) for every Gänger kind, the Bellringer, the Glasshide and the Screamer; the Foreman keeps his own body. The body is one skinned mesh per kit/build/sex (`ZombieBody.build_skinned`; modelled since T-091, §2.1.3): surface 0 skin (the infection shader), surface 1 everything else (vertex-coloured, one shared shader), so a body is two draw calls. Gear (helmets, caps, goggles, armbands, packs...) hangs on bone attachments and is rolled per spawn. Base bodies: thin / medium / heavy × two heights, male and female.
- **Clips:** all procedural, baked in-engine by `zombie_clips.gd` into one shared `AnimationLibrary` (no imported animation). Locomotion per tier: shamble ×3, walk ×3, jog ×2, run ×3, sprint ×2, crawler ×2 (belly drag, four-limb scuttle), each with lean-left/right variants; turn-in-place ×2; idle, window wait; tears ×3 (grab-and-rip, two-hand wrench, shoulder slam); vault ×2 and a drop-down; emerges ×5 (dig-out, roll-up, portal step, chute drop, wade-up); climb loop + mantle; attacks: 4 swipes, lunge, sprinter grab, crawler bite, headbutt, window swipe; stagger, knockdown front/back, get-up front/back, fall-into-crawler; 9 deaths (headshot snap, gut collapse, spin, knee-drop, backward fall, face-plant, sit-down, sprint tumble, headless walk) + a crawler death; 8 posture traits; 7 directional flinches.
- **Tree:** `AnimationTree` state machine Spawn / Emerge / Climb / Barricade / Locomotion (BlendSpace2D speed × turn) / Attack (BlendSpace1D variant) / React / Crawl / Death, plus an additive posture layer (Add2) and an additive OneShot for flinches. Locomotion clips carry root motion on a Root bone whose speed equals the tier speed; the zombie sets the time scale from its nav velocity (and its height scale), so **root motion = nav speed, no foot-sliding** (`smoke_zombie_anim` compares the stride distance with the body travel over half-second windows and requires 5%; measured worst 0.8–1.3%). Every zombie keeps its own stride phase (random start, transitions into Locomotion do not reset) and rolls one posture trait.
- **Senses and IK:** foot IK (two rays per physics step within 15 m, hips drop to the lower foot, analytic two-bone legs, off beyond 25 m) and head look-at toward the nearest player (`LookAtModifier3D`, 60° cone, 0.2 s), both in `zombie_modifier.gd` / `_update_senses`. Hit springs on the arm chains and the head stand in for the partial ragdoll on flinches.
- **Reactions:** directional additive flinch by hit zone and side (the hitbox bone the weapon reports), stagger (melee / explosive / ≥ 40% of max HP), knockdown + get-up (explosives and the Glasshide shatter, interruptible), fall-into-crawler on a leg loss at speed.
- **Deaths and corpses:** the clip plays to its key pose (0.55 s), then a `PhysicalBoneSimulator3D` ragdoll takes over (pin joints, damped; explosive deaths throw the trunk). At most 6 live ragdolls (`ragdoll.max_live`; rigs freeze after 3 s; a death at the cap holds its authored pose). Corpses stay 8–12 s then dissolve (the shader's `inst_dissolve`), sooner when the pool runs low.
- **Dismemberment:** forearms, upper arms, lower legs, head (pops on a headshot kill, sometimes on an explosive one) and jaw come off as physics pieces with stump caps (4 s, at most 12 live). An arm lost removes that arm's swipes; both gone → headbutt; the legs at the hip → crawler (with the fall transition). **Gore setting** (Settings → Video): Off (limbs stay on, no blood; the shatter VFX stays), Low (severs, no spray), Full.
- **Look:** the Nachtglas shader: violet veins pulsing with the map hum (`gl_hum`, AudioDirector's envelope), cracks whose density grows with the round (`gl_round_k`), glowing eyes; per-instance tint / dirt / frost (per map), burn char while burning, frost crust while frosted; fuel / LOX uniforms reserved for Morgenrot.
- **LOD and audio:** the tree advances every frame within 15 m, every 2nd to 35 m, every 4th beyond; IK and look-at off beyond 25 m. Footsteps fire from the locomotion cycle (surface-aware by collider metadata / name hints, culled at 18 m, rate-capped across the horde), rip grunts from the tear cycle, snarls on the attack windup.

#### 2.1.2 Rising from the ground (T-085; `enemies/zombie_emerge.gd`, `enemies.json` "emerge")
Ground spawns are the thing players watch, so the rise is a staged dig-out rather than a body sliding up. Every ground rise is one of five **variants**, authored as keyframes on the shared rig and baked like every other clip (`emerge_<variant>`), with the **stage times** in data so the clip, the particles, the sounds and the gameplay switches all read one table:

| Variant | Length (r1) | Weight | Stages (normalized time) | Character |
|---|---|---|---|---|
| `fast` | 1.4 s | 0.30 (×3 run, ×6 sprint, ×0.4 shamble) | bulge 0 · hand .10 · hand2 .18 · head_out .32 · shoulders .42 · elbow .52 · knee .64 · stand .86 · done 1 | both hands almost together, one heave, a lunge out of the hole |
| `standard` | 2.1 s | 0.40 | bulge 0 · hand .10 · hand2 .26 · head_out .40 · shoulders .50 · elbow .60 · knee .72 · stand .92 · done 1 | one hand claws, the second, head and shoulders heave out twisting, elbow plant, knee up, a lurch to standing with a stagger step |
| `slow` | 3.0 s | 0.15 (×1.6 shamble, ×0.3 run, 0 sprint) | bulge 0 · hand .08 · hand2 .24 · head_out .36 · shoulders .44 · **pause .50 · heave2 .60** · elbow .66 · knee .78 · stand .94 · done 1 | hangs at the rim, head lolling and shuddering, then tears free with a second heave |
| `roll` | 2.3 s | 0.15 (×0.5 sprint) | bulge 0 · hand .08 · hand2 .16 · head_out .28 · shoulders .36 · **flat .52 · roll .68** · knee .80 · stand .94 · done 1 | face first: drags itself flat onto its belly, rolls onto its side, comes up on a knee at the rim |
| `crawler` | 2.4 s | never rolled (crawlers only) | bulge 0 · hand .10 · hand2 .22 · head_out .36 · elbow .48 · **flat .80** · done 1 | elbows planted, drags out onto its belly and stays down (ends in the crawl pose) |

- **Pick:** per zombie from a pool RNG seeded by the match seed (`QuestManager.match_seed`), the table weights times the tier multipliers, so a seeded match replays the same rises. Crawlers (spec `"crawler": true`, or legs lost mid-rise) take the crawler variant at the same progress.
- **Round scaling:** every ground rise is multiplied by a ramp from 1.0 at round 1 to 0.7 at round 20 (`emerge.round_scale`); the weighted mean is ~2.0 s at round 1 and ~1.4 s (the old constant) by round 20. The director's spawn pacing does not read the rise, so the game is not slowed; the rise only delays when a spawn becomes a threat. Window, portal, chute and wade emerges keep their old timings (`anim.json emerge`).
- **Stages on the ground:** the ground bulges and trembles (a mound mesh at the spawn, snow / earth / stone by the surface under it: a `ZombieSpawn` meta `surface`, else the floor collider's surface meta / name hints, else the map default in `emerge.surface_by_map`; Map 0 snow, Map 1 earth, Map 2 stone); the first hand bursts the crust (spray + `emerge_burst_*`, the dark broken ring shows), each raking hand scrapes (`emerge_dig_*`, rate-capped horde-wide), the head tears free (big spray + a groan), clumps fall off the shoulders, small sprays at the elbow and knee plants, a dust puff and a settle crunch at the stagger step. Nothing pokes through the ground before its stage (the GUT test samples the baked poses). Particles are one pooled `CPUParticles3D` set in `Effects` (`dirt_burst`, `dust_puff`, 24 emitters, no per-burst allocation beyond a mesh swap); effects are culled beyond 24 m of the zombie's target.
- **Gameplay rules:** the **hitboxes are off until `head_out`** and on from then (a rising zombie can be shot the moment its head shows, never through the ground before); any early exit from the rise (a risen patron's get-up, the opening's attackers) turns them back on. Navigation starts at `done`. A zombie **killed before `stand`** slides back into the ground (the rise clip in reverse at 1.6×, mound kept, no ragdoll or corpse) and returns to the pool. The head look-at runs from `head_out`. Bots keep ignoring rising zombies as targets.
- **Capture:** `shots_zombie_anim.tscn -- --only=emerge` (rendered): one row per variant at eight stage times, the three surfaces, and a live row.

#### 2.1.3 Art: the modelled bodies (T-091, UPDATE_05 §3; `docs/CHARACTER_PIPELINE.md`)
- **Bodies:** six base bodies (thin / medium / heavy × male / female) built by script in headless Blender
  (`tools_src/blender/characters/`, `tools/build_characters.sh`) and skinned to the ZombieRig bone names:
  `assets/ours/characters/zombie_base/char_zombie_base_<m|f>_<build>.glb`. ~7 200 triangles each with the face parts
  (≤ 8 000, ART_BIBLE §5). Faces: deep sunken sockets with a flattened violet glow lens in each, a real mouth opening
  on the Jaw bone (teeth on Head and Jaw), gaunt cheeks, brow, nose, ears; clawed hands. Weights are computed (bone
  segments, side masks) in an A-pose and unposed onto the rig's rest.
- **Skin:** one shared 1K set (`tex_zombie_skin_albedo / normal / orm.png`, the six bodies share one UV layout):
  pale mottled skin, blue-violet veins, frostbite at the fingers, toes, nose, ears and lips, bruised sockets,
  lividity in the legs; the albedo's alpha marks where the Nachtglas starts (eyes, mouth, hands) and the shader opens
  the round's cracks there first. Everything the infection shader did stays (veins on `gl_hum`, cracks on
  `gl_round_k`, tint, dirt, frost, char, fuel, dissolve).
- **Kits as clothing:** the nine kits are real garments fitted to every body (greatcoat with its skirt, belt,
  pouches, double buttons, collar and tabs over trousers and jackboots; villager jacket and trousers or blouse, long
  skirt, shawl and stockings; miner jacket, braces, ties; lab coat, gloves, pockets; technician coverall, tool belt,
  rubber boots and gloves; sailor's pea jacket, brass buttons, bell-bottoms; dockworker's jumper, roll neck, rubber
  boots; the Bellringer's ragged bound tunic, barefoot; the nurse's dress, white apron, collar, stockings), ≤ 3 000
  triangles each, coloured per kit from `KIT_CLOTH` / `KEY_LOOK` with a wool / leather detail texture (the T-088
  library). The skin they cover is dropped from the draw. Gear rolled per spawn stays on bone attachments; the
  soldiers' optional armband (30%) and the Projekt Wiederkehr armbands carry the fictional Sunburst-and-Split-Bell
  (ART_FACTIONS.md). No real insignia anywhere.
- **Gameplay is untouched:** `ZombieBody.HITBOXES` are unchanged (GUT checks the meshes sit inside them), as are
  the ragdoll shapes, clips, timings and the gore rules. Dismemberment pieces are cut from the body itself by
  dominant bone (a sleeve comes off with the arm), the stump caps are sized per joint and build.
- **LODs:** Godot's mesh LODs generated on the merged mesh (`characters.json lod.mode "auto"`), measured against no
  LODs and the pre-T-091 bodies in `docs/gravelight/PERFORMANCE.md`.
- **Crawlers:** the crawl pose's hips were under the floor (T-085's open item: rendered crawlers were invisible);
  it now lies on its belly on the floor.
- **Kind parts:** the Glasshide's crystal plates and arm, the Bellringer's lantern and the Foreman's own body are
  unchanged; the Cousins (homage) use the villager thin female body until the people builder's models land.

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
- **Relief squads (T-142, UPDATE 09 section 4):** living soldiers (`data/gravelight/squads.json`, docs/BOT_AI.md section 12) hold one slot of `max_active` each while they live (`ZombieDirector.actor_budget() = max_active - soldiers alive`; the round's queue waits, it is never cut). Zombies hunt them through the `prey` hook. A dead soldier rises 4-8 s later through `ZombieDirector.rise_at(position, tag)`: a pooled zombie outside the round queue (it must die before the round ends) dressed as that soldier; marked factions (Volkssturm, Kriegsmarine) keep a Marke, unmarked Allied soldiers (risen by the substrate) have none.
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

---

## 6. Morgenrot enemies (Map 3, ULTIMATE PROMPT v2 §3; design only, built in M8.5 on the MZ animation framework)

Rule (v2 §0): **no laborer appears as a zombie, ever.** The Morgenrot Gänger outfit kit is rocket troops, white-coat technicians, cable-car staff and mountain troops; the existing `laborer` variant is retired in MZ (ZOMBIE_ANIM_SPEC.md).

### Data-ready summary (Morgenrot)
| id | HP formula | Speed | Melee dmg | Attack rate | Scrip | Round gate | Spawn source | Weight / cap | Tell |
|---|---|---|---|---|---|---|---|---|---|
| `ganger` (Morgenrot kits) | `health(r)` | tier mix §1.5 | 50 | as §2.1 | as §2.1 | r1+ | windows, ground, chutes | default fill | — |
| `treibstoff` | `health(r) × 1.1` | walk / jog | 55 | 1 / 1.2 s | 70 / 80 / 120 / 150 | r8+ | ground (depot, lanes, Kessel) | 8% of spawns, cap 4 active | dripping, sloshing footsteps; a fuel sheen |
| `frostbiss` | `health(r) × 1.6`, shatters at 0 like a Glasshide | shamble / walk (1.3 / 2.0) | 85, hit = `frost_vent` slow on the player 2 s | 1 / 1.6 s, 0.7 s windup | 90 / 100 / 160 / 200 | r12+ | ground near the depot and dam | 5% of spawns, cap 3 | ice creak, breath fog |
| `bergwacht` | `health(r) × 1.2` | jog / run; climb 1.8 m/s | 60 (axe) | 1 / 1.1 s | 75 / 85 / 130 / 160 | r15+ | **climb volumes** (crater wall, dam face, netting poles, dome) | 6% of spawns, cap 5 | crampon scrape, axe clink; they drop from above |
| `faller` (LUFTALARM) | `health(r) × 0.7` | run after landing | 40 + landing shockwave 60 in 3 m | 1 / 0.9 s | 60 / 70 / 110 / 140 | special rounds only | searchlight-marked impact circles | whole round, packs of 4–8 | siren wind-up, searchlights, a whistle before impact |
| `startmeister` | `3200 × r × P_hp[p]` | 2.2 walk, bowser ram 7.5 | 70 arc burn + 15/s, 110 ram | phases below | 600 on kill | r14–16 first, then every 6–8 | the Kessel ring (boss point) | max 1 | the bowser's chains, the valve-wheel hiss |
| `reinholt_wiederkehr` | 3 phases, egg only | floats / clings | shield, summons, engine light | see MAP3 §4.2 step 9 | — | egg step 9 | the Kessel storm | 1 | her voice on every speaker |

### 6.1 Treibstoff-Gänger (`treibstoff`)
Launch crew in rubberized fuel suits, dripping alcohol. **Killed by fire or an explosive they burst into a burning puddle** (the flamethrower's burning-ground rules: 2.2 m, 5 s, 45 dps to anyone, zombies included). Shot normally they just die. Use them.

### 6.2 Frostbiss (`frostbiss`)
LOX-burned, frost-crusted, slow and hard-hitting; a hit frost-slows the player (`frost_vent`, move ×0.6, 2 s). Armour like a Glasshide (torso ×0.5); they **shatter** at death with the Glasshide shockwave, and a frozen one (Die Lange Nacht) shatters to a single melee.

### 6.3 Bergwacht (`bergwacht`)
Mountain troops with crampons and ice axes. New spawn behaviour: **they climb** cliff faces, the dam, the netting poles and the dome via authored climb volumes (`NavigationLink3D` links that trigger the Climb state; ZOMBIE_ANIM_SPEC §3) and drop in from above. On a climb they cannot attack and take ×1.5 damage; they lunge on landing.

### 6.4 LUFTALARM (special round, replaces Bellringers on Morgenrot)
Every 5–7 rounds: sirens wind up (8 s), searchlights sweep and settle on **impact circles** (3 m rings on the ground, 2.5 s before impact); **Fallers** — burnt test-launch casualties glowing hot — plunge out of the night sky into the circles with a 60-damage shockwave, then run. Stay out of the lit circles. Roofed zones (the Stollen, the depot) get none. Clearing the round guarantees a Resupply drop at the last impact.

### 6.5 DER STARTMEISTER (`startmeister`), Morgenrot boss
The launch officer fused into a pressure suit and a towed fuel bowser. **Phase 1:** sprays burning alcohol in 70° arcs (ignites players 15/s for 3 s). **Phase 2** (bowser at 60%): drags the bowser round the ring to ram (110, knockdown). **Phase 3** (bowser breached): he runs, trailing fire (burning ground behind him). Weak point: the **valve wheel on his back** (×4). Drops **Schlüssel I** when killed inside the Kessel with the gantry floodlights on (egg step 6). Scrip 600.

### 6.6 REINHOLT, "WIEDERKEHR" (final boss, egg step 9 only)
Dosed with her fragment she floats in the Kessel inside a violet storm, shielded by the Liesl apparition (Nachtglas light; the tin drummer at her feet). **Phase 1:** freeze the shield with Die Lange Nacht and shatter it. **Phase 2:** she summons the dead of Kaltenbrunn (Map 1 variants, the Foreman). **Phase 3:** she clings to the gantry as the Sonnenspeer's engines light; the fight ends with the two keys, not her death. Her lines are grief (VO_SCRIPT §11.3).

### 6.7 Spawning additions (Morgenrot)
- Climb volumes are a third spawn source beside windows and ground: a `ZombieSpawn` of kind `climb` with a link path; only the Bergwacht use them.
- LUFTALARM impact circles are placed by the director on open-sky zones only (`zone.roofed = false`).
- The Launch Clock's fueling surge raises the Kessel's spawn weight ×1.5 while players are away from it (so the crater is never quiet).

---

## 7. Homage bosses (ULTIMATE PROMPT v3; design only, built in HB1–HB3 on the MZ framework)

Three bosses are homages to real people: Devin's cousins, his friend Paul, and Devin. They are love letters: terrifying in the game, flattering out of it. **The full design is `docs/HOMAGE_BOSSES.md`**: moves, telegraphs, animation lists, VO, rewards and the Likeness Sheet. Canon is in LORE.md §15, and the tuning will be `data/gravelight/bosses/*.json`.

**Rules:**
- **Settings → Gameplay:** "Homage Bosses: On / Off" (default On; Off plays a normal round) and "Homage Names: Real / In-World".
- **HP:** `base × S(p)`, `S(p) = 1 + 0.75 × (p − 1)` (the Foreman's `P_hp`).
- **Rounds:** a boss round is never a special round or a Foreman / Startmeister round (those move +1), and the normal horde keeps coming at a reduced rate.
- **Bosses:** they ignore barricades, never crawl, are never last-zombie culled, and take Death's Door as double damage, not instant death.

### Data-ready summary (homage bosses)
| id | HP (solo base) | Speed | Key damage | Round gate | Spawn | Weak points | Scrip | Tell |
|---|---|---|---|---|---|---|---|---|
| `cousin_hammer` | 6,000 | 3.4 skip-walk, +20% per cousin death | maul 50; Mallet Throw 45 per pass (out and back); Overhead Split 80 + splinter slow | Map 0 **r10** (replaces the round; 40% horde) | the stairwell (maul thrown down first) | **×1.5 to everything while the maul is in the air**, a melee hit staggers; head ×2 | 400 / player | sparks of the dragged maul; **she stops humming one beat before a throw** |
| `cousin_reach` | 5,000 | 3.0 hunched, ceiling crawl 2.6 | swipe 45; Long Reach Grab to 12 m → Hug-Crush 120; Through-the-Wall 60; Window Spider 40 | r10, +30 s | the stable hayloft (arms through the taproom windows first) | **wrists ×2 while extended**; a severed arm (Gore Low/Full) regrows in 20 s | 300 / player + Fortify + 500 | counting fingers; **dust and creaking 0.6 s** before a punch-through; every barricade rattles before Window Spider |
| `cousin_alix` | 7,500 | 1.8 within 8 m; **ObservedFreeze** beyond (frozen when seen, 6.0 unseen) | **2× zombie damage**: swipe 100; Holding Hand 30/s; Lash 90 (crouch under) | when a cousin is < 50% (or dies, or 3:00) | **the trapdoor behind the bar** (this round only) | **the Third Hand's palm ×2**; ×2 while she holds a dead cousin's hand (3 s) | 500 / player | silent steps, only the dress rustling; **arms rise to her ears 0.9 s** before a Lash |
| `paul` | 30,000 (+35% per return) | 2.6 / 3.6 / 6.2 by rage stage | haymaker 70; zombie throw 60; squeeze 25/s; ground pound 50; rip-throw 90; leap 100; thunderclap 40 + strips boards; charge 90; dive 130 | Map 1 **r15**, then returns every 8–10 rounds **until beaten** (60% horde) | the headframe (PA roar, then the leap and crater) | **the 6 IV bottles** (−20 rage each); **back of the neck ×2 facing away**; a big blast = knee-down ×1.5 | 2,000 / player + Double Scrip + Paul's Last Round | the dog tags, the chest beat; his shadow growing before a leap or dive |
| `slender` | 35,000 | 1.6 walk (never runs); 15 m teleport only while unobserved | Key Ring Lash 85 + stagger; quarantine → downed on failure | Morgenrot **r20** (needs power; never during the Heartstorm / Reinholt; 50% horde) | the Meiller Lanes forest | **can only be hurt while lit** (floodlights, truck headlights, flares, muzzle flash < 5 m, Die Lange Nacht's freeze); the lantern ×2 (break = 6 s stun); the book shot loose = 4 s ×1.5 | 2,500 / player + Overwatch | **the keys go silent before he attacks**; the LOGGED tiers (grain → violet static → dropouts → behind you) |

### 7.1 The Cousins (`cousin_hammer`, `cousin_reach`, `cousin_alix`), Map 0 round 10
- **Setup:** at the end of round 9 the lamps go out one by one, the fire dies, a child's handprint smears across a taproom window from outside, then there is clapping upstairs.
- **Arrival:** the Hammer, then the Reach 30 s later, then Alix from a cellar trapdoor nobody knew was there.
- **While all three live** they hum in harmony. **Each death removes a voice** and enrages the survivors (+20% speed and a new move: Ricochet Throw, Both Hands, Double Lash). The last one sings alone. One lamp group relights per death.
- **Fail-safe:** at 6:00 they "get bored", retreat laughing, and return on round 15 at full HP.
- **Clear:** Death's Door, Resupply, 1,500 Scrip per player, "The Game Is Over" card, "Three Ribbons" charm, the aunt's letter.
- **Drops:** the Hammer drops the **Kinderhammer** (WEAPONS §23.1).
- **Their deaths are authored** (no ragdoll), and they are never sexualized (HOMAGE_BOSSES §1.2).

### 7.2 PAUL (`paul`), Map 1 round 15
**Pvt. Paul**, a US combat engineer dosed past the limit with Ironhide Stout. Last impulse: protect my guys.

**The rage meter (0–100, a stout bottle on his bar)**:
- **Fills from:** damage taken, players fleeing, and the sight of downed players.
- **Stages:**
  - Calm 0–33: stomp, haymakers, zombie throws.
  - Angry 34–66: ×1.15 size, ripping ore carts and rails.
  - BERSERK 67–100: ×1.30, steam, Leap Slam across zones, Thunderclap, Charge through doors, the Headframe Climb and Dive.
- **Cooling:** shooting the six IV bottles cools him −20 each.

**Never on a Foreman round.**

**Death and the twist:**
- On his knees, he recognizes an Allied soldier and gives a per-character last line ("...Hey. You found me. Tell the guys I carried my share."), hands over his crushed tin cup, and falls forward slowly.
- Rewards: Paul's Last Round (WEAPONS §23.3), 2,000 Scrip per player, Double Scrip, "Carried My Share".

### 7.3 THE SLENDER (`slender`), Morgenrot round 20
The Hohe Wacht's night watchman, still on his rounds. He has a face, a greatcoat and a lantern: **not** Slender Man (HOMAGE_BOSSES §6.2).

**The LOGGED meter:** every player has a hidden LOGGED meter.
- **Fills:** his lantern light, staring at him, standing still in the dark, unsuppressed fire in the forest.
- **Drains:** breaking line of sight, floodlight or flare light, staying near teammates.
- **At 100 he quarantines you into the Watch Room:** find and tear out your page within 25 s (35 s solo) or be downed. Teammates' lantern hits release you early.

**Phases:**
- **Shift Change** (< 50%): three Watchmen; the steady lantern is the real one, and shooting a decoy logs you.
- **End of Shift** (< 20%): 30 s of total darkness and the floodlights fail until a generator lever is held for 5 s.

**Death:** he sets down the book and the lantern, blows it out, and sits against a pine for the rest of the match; zombies leave him be.

**Rewards:** Overwatch (WEAPONS §23.4), the generated Watch-Book Archive entry, 2,500 Scrip per player, "Night Shift", "Violet Lantern".

### 7.4 Spawning additions (homage bosses)
- Boss spawns are scripted entrances, not spawn points:
  - Map 0: the stair head, the hayloft, the bar trapdoor (a hidden prop in round 10 only);
  - Map 1: the headframe top;
  - Morgenrot: the Meiller Lanes' far end.
- **ObservedFreeze** (Alix, the Slender's teleport) is a shared component, shared later with B&S's Galleria mannequins. **AnimJitter** steps animation at 12 fps for short bursts (the Hammer's hitch, the Reach's retract).
- The campaign: on Map 0 with Homage Bosses On, the exfil beacon opens on round 11, after the Cousins (HOMAGE_BOSSES §4.2).

## 8. Totenhafen: the drowned (Map 2, UPDATE 10 contract C2 "Kielholer" and C5; built, DECISIONS T-153)
The Kielholer ("keel-haulers") are U-1047's ratings and the harbour's dead, who took the Marke the week the detachment was marked. They are sailors and are shown as sailors: the sailor's cut, waterlogged, weed on the shoulders. They are not gore props. They rise only while the docks are flooded and pull the living toward the water they came out of.

### Data-ready summary (the drowned)
| id | kind | kit | HP | the point |
|---|---|---|---|---|
| `kielholer` | tagged Gänger (`ganger_variant`) | `drowned` | ×1.2 | a grabber at the pier edges |
| `kielholer_diver` | tagged Gänger | `drowned_diver` (brass helmet) | ×1.6 | a helmet that soaks until its glass breaks; the glow behind it ×2.0 |
| `der_kielholer` | boss (`HomageBoss`) | `drowned_diver` + his own costume | 28,000 solo (×3.25 at 4P) | Kptlt. Arvid Lenz, the pen hall's boss (HOMAGE_BOSSES §4b) |

### 8.1 Where they rise (`KielholerController`, `gravelight/world/map02/kielholer_controller.gd`)
- Eight `Surface_<i>` spawn points on the pier edges (`map02.json "kielholer".surface_points`, zone D_PENHALL). They rise with the "water" emerge style (anim.json `emerge_by_spawn_prefix`), and are live only while the GameState flag `flooded` is on (Tide v2).
- On the host, a Gänger that rises at a surface point is tagged a Kielholer. So is `surface_share` (35%) of the Pen Hall's other spawns while the docks are flooded, and `diver_share` (25%) of those are divers.
- At most `max_active` (6) are up at once, or `max_active_spring` (10) on a spring tide.

### 8.2 The grab
- **Taking hold:** within `grab_range` (2 m) of a player, a Kielholer takes hold and pulls him toward the nearest water edge at `pull_mps` (1.2 m/s). The water edges are the pier and apron edges over the dock basins (`KielholerController.EDGES`).
- **While held:** the player moves at ×0.25 (status `kielholer_grab`) and takes `hold_dps` 6, or `edge_dps` 16 within 1.6 m of the edge. A full 6 s hold at the edge is 96 damage: dangerous, never an instant kill. The railings keep everyone out of the water itself.
- **Breaking free** (whichever comes first):
  - the held player's melee;
  - 60 damage to its `arm_grab` hitbox (the right forearm), from anyone;
  - 150 damage from teammates (half weight off the arm, so bot fire at the body still frees him);
  - `max_hold` (6 s).
- **After a release:** that Kielholer won't re-grab the same player for 4 s, and a freed grabber staggers. The rules are HOMAGE_BOSSES §3.6's.

### 8.3 The diver
- The brass salvage helmet (gear `diver_helmet`) has a `helmet_glass` hitbox on its front port. The glass and the head take ×0.5 until 30% of the diver's max HP has gone into the helmet.
- Then the glass breaks and a violet glow shows behind it. That glow is the Marke he wears (U09 C1), so his hand carries no mark. From then on, hits on the glass take ×2.0.

### 8.4 Engineering notes
- **The kits:** `drowned` and `drowned_diver` are anim.json kits drawn with the sailor geometry (`ZombieBody.KIT_ALIAS`), recoloured with `DROWNED_PALETTE` and a cold skin tone.
- **Never rolled:** they are not in `ZombieBody.KITS` and never come from `variants_by_map`.
- **Gear:** `diver_helmet` and `weed` are new gear pieces.
- **Zombie hooks:**
  - `Zombie.damaged(amount, limb, by_player, kind)` is a per-zombie hit signal.
  - The meta `limb_mults` is a tagged kind's own limb table.
- **Co-op:** the host tags, grabs and breaks free. A client sees the Gänger puppet in its rolled kit (the drowned look is host-side for now).
- **Tests:** `gravelight/tests/unit/test_kielholer.gd`.
- **Smoke:** `gravelight/tools_src/smoke_kielholer.tscn`.
