# BOLT & SPROCKET — Redesigned Arsenal (`BS_WEAPONS.md`)

This is the design spec for the B&S arsenal in TERMS & CONDITIONS: 16 guns, 4 mallets and the K.A.R.E.N. gadget. It implements brief §5 and links to §4.2, §4.3, §5.4 and §10.3.

**Sources.** Every "original" number below comes from the v14 web build: `data/bs_source/*.json` (`WEAPONS`, `AMMO_BASE`, `AMMO_PER_TIER`, `W_BASE_DMG`, `OMEGA_DESC`, `UPG_TRACKS`, `SHOP_TRADE_VALUE`, `MALLET_NAMES`, `CONFIG.melee`) and the fire functions in `reference/bs_web/index.html` (`fireBlaster` L4552, `releaseRipper` L4729, `fireZap` L4783, `fireBoomBox` L4574 / `detonateRave` L4614, `fireLawnDart` L4637, `firePatent` L4684, `fireCease` L4711, `fireBuzzkill` L5617, `fireGrav` L5635 / `spawnSingularity` L5648, `fireMiddleman` L5689, `updateFrostbyte` L5735, `fireRoot` L5783 / `plantAt` L5795, `meleeHit` L4969, `slamImpact` L3184, `shopStock` L11956, `fireKaren` L13668). When a code number disagrees with a table or an ad line, the code wins. Disagreements are listed in §14.

**Tuning lives in data.** Every number here becomes a field in `data/bs/weapons/<id>.tres` (a `WeaponData` resource) or `data/bs/weapons/progression.json`. Nothing is hardcoded.

**Units.** Damage is in HP (Bolt has 100 max HP; Nanotech Boosts add 20 each). "Interval" means seconds between shots. Distances are in metres (1 web-build unit = 1 m). "Splash" is a radius.

---

## 1. Global rules carried over from the web build

| Rule | Original (source) | Remake |
|---|---|---|
| Damage mod | `wDmg = base × (1 + 0.25 × dTier)` | Kept. +25% per tier, +75% at tier 3. |
| Fire-rate mod | `wRate = interval × (1 − 0.15 × rTier)` | Kept. −15% interval per tier, −45% at tier 3. |
| Ammo mod | `ammoCap = AMMO_BASE + AMMO_PER_TIER × aTier` | Kept. The Blaster's ammo slot becomes **Heat Sink** (see #1). |
| Visual tier | `tierMul = 1 + 0.18 × dTier` (shots get bigger and brighter) | Kept, and stacks with the V-level model details. |
| Crit | 2.5× damage on a weak-point hit (within 0.75 m of `weakPos`) | Kept. Marked weak points (THE FINE PRINT) widen this (§4, §9.2). |
| Boss armour | Bosses take 45% damage unless the hit is a weak-point crit | Kept. CLEARANCE RACK can lower it (§9.4). |
| Fragile projectiles | Any player shot that touches a fragile enemy projectile destroys it ("DENIED") | Kept for every gun. |
| Super Sprocket | All damage ×2 for 30 s; damage dealt charges the meter (`+dmg × 0.0006`) | Kept (brief §4.2 adds modes). |
| NG+ | Enemies HP ×1.6, bosses ×1.4, damage to Bolt ×1.35 | Kept. The arsenal and all progress carry over. |
| Omega | Auto-evolve when every mod track is at tier 3 | **Replaced** by §2 (V5 + full mods + the Omega Forge). |

---

## 2. Progression model

Each weapon has three layers: **use-XP levels (V1→V5)**, **Blartz Mods** (bought), and **Omega Evolution** (at the Forge). The mallets are separate (§12).

### 2.1 Use-XP levels V1 → V5

A weapon earns XP only while it is the weapon that dealt the damage.

| XP source | XP |
|---|---|
| Damage dealt to an enemy (HP actually removed; overkill doesn't count) | 1 XP per HP |
| Kill | +10 |
| Elite kill | +25 |
| Damage to a boss | 0.5 XP per HP |
| **Assist:** another source damages an enemy that carries this weapon's status (SERVED, frozen, dancing, rooted, gravity-clumped, marked, marked down, acquired) | 25% of that damage as XP to the weapon that applied the status |
| Damage dealt by this weapon's deployables (Middleman drones, Root Canal plants, Hostile Takeover subsidiaries, Patent hazard spheres) | Counts as the weapon's own damage |
| Firing Range | 0 (no farming) |
| Colosseum, Boss Rush, Zonga, NG+ | Normal rate |

**Thresholds (cumulative XP):**

| Level | XP to reach | Kills at ~40 HP each (rough guide) | Stat bump | Behaviour change |
|---|---|---|---|---|
| V1 | 0 | — | Base | — |
| V2 | 600 | ~12 | +6% damage, +10% max ammo | — |
| V3 | 1,800 | ~36 | +6% damage | **Yes** (small) |
| V4 | 4,000 | ~80 | +6% damage, +10% max ammo | — |
| V5 | 8,000 | ~160 | +6% damage | **Yes** (signature) |

V5 totals +24% damage and +20% max ammo (rounded up) on top of the Blartz Mods.

**Catch-up rule.** While a weapon's V-level is below the average V-level of your other owned weapons (rounded down), it earns **×2 XP**. This keeps late-game guns (Clearance Rack, Patent Pending) viable without grinding.

**Pacing check.** One campaign run has about 25,000 XP of enemy health on offer (7 planets × ~70 enemies × ~40 HP, plus about 3,800 boss HP at half rate). A player who favours 2–3 guns gets them to V5 by the Core Foundry. Getting all 16 to V5 (128,000 XP) is the post-game and NG+ chase, which is where the Omega Forge lives.

**Visibility.** Each level adds a model detail (listed per weapon), a level pip on the HUD weapon card, and a short Sprocket bark on level-up (`bs.weapon.levelup.<nn>`, §11).

### 2.2 Blartz Mods (bolts)

The original three upgrade tracks become three mod slots per weapon, at the original prices and with their original flavour text (`UPG_TRACKS`):

| Slot | Effect per tier | Prices (tier 1 / 2 / 3) | Flavour (kept verbatim) |
|---|---|---|---|
| **Damage** | +25% damage | 60 / 110 / 170 | "Makes the hurty end hurtier. Science!" |
| **Fire Rate** | −15% interval (for beams: −15% ammo drain; for deployables: −15% redeploy cooldown) | 50 / 90 / 140 | "Shoots faster than Blartz dodges taxes." |
| **Ammo Cap** | +`AMMO_PER_TIER` max ammo (Blaster: +20 heat capacity) | 40 / 70 / 110 | "Now holds more boom per bag. Pockets sold separately." |

- One weapon's three slots cost **840 bolts** in total. The Blaster's Ammo slot is now **Heat Sink**, so all 16 guns have three slots. (Originally the Blaster had only two, because its ammo was infinite.)
- Mods are permanent and carry into NG+.
- The original shop rule stays: you can't buy Patent Pending mods until Blartz is rescued (he's the only one who understands it).
- **Behaviour changes from the original mods.** In the web build, maxing the Damage track also unlocked behaviours (Buzzkill blades split, Grav crush, Middleman self-destruct, Frostbyte frost-spread, Root Canal spores, extra Zap strands, Cease & Desist ricochets). In the remake those behaviours move to the **V-levels**, so mods are pure stats and the V-levels carry the identity. Each one is listed per weapon as "(was Damage tier 3)".

### 2.3 Signature Mods (one per weapon, a choice of two)

- Unlocks when the weapon reaches **V3**. Installing it costs **200 bolts** once.
- You pick **A** or **B**. You can swap between them for free at any Blartz kiosk.
- A Signature Mod changes behaviour, not just numbers. Each pair is a real trade-off. Neither option is a strict upgrade.
- The chosen Signature Mod stays active after the Omega evolution.

### 2.4 Omega Evolution at BLARTZ'S OMEGA FORGE

| Rule | Value |
|---|---|
| Requirements | V5, all three Blartz Mods at tier 3, and a Signature Mod installed |
| Cost | **2,000 bolts** |
| Where | **BLARTZ'S OMEGA FORGE.** It unlocks after the Blartz rescue in the Core Foundry (story beat `blartzRescue`). From then on, every Blartz kiosk on every planet has a Forge bolted to its side. |
| What you get | An evolution cutscene (about 8 s, skippable after the first time); a gold **Ω** on the HUD card, the wheel slot and the gun model; a new name ("Ω OVERTIME"); and the Omega signature behaviour, built on the original `OMEGA_DESC` and upgraded |
| Total per weapon | 840 (mods) + 200 (Signature) + 2,000 (Forge) = **3,040 bolts** |
| Undo | None. You can't un-evolve. "Refunds imply error." (`blartz.buy.02`) |
| NG+ | Omega weapons carry over. In NG+, Blartz's stock also adds Omega-tier cosmetic paint for each evolved gun (brief §8). |

Because Blartz is only rescued on the last planet, Omega is mostly an endgame, post-game and NG+ chase. That's intended.

**The Forge (look).** It's a squat, Blartz-green furnace with gold trim, exposed coils and taped warnings, the same design language as the Patent Pending. A heat-glass window shows the gun floating inside, and a hand-cranked bellows sits on the side. The brass plaque reads:

> **BLARTZ'S OMEGA FORGE · MOD. Ω-1 · PAT. PEND. BLZ-40417**

This deliberately rhymes with Gravelight's Crucible plaque, **"MOD. R-E · PAT. PEND. BLZ-40417"**. Darkmatter later buys Blartz's confiscated schematics in OmniScrap's fire sale and "localizes" the Forge into the Crucible Mod. R-E (brief §10.3). The Forge is green and gold. The Crucible is violet. Blartz will have opinions about that in The Fine Print Ch. 4.

**Evolution cutscene beats.**
1. The gun goes in, the door slams, and Blartz cranks the bellows.
2. The window flares gold, and the gun's silhouette reshapes.
3. A gold Ω stamps onto the receiver, and the new name appears as a banner.
4. Blartz says the per-weapon line (§2.5).

### 2.5 Forge dialogue (new lines)

**First visit** (plays at the first Blartz kiosk after `blartzRescue`). It plants the confiscated schematics per brief §5.1 and §10.3.

| ID | Speaker | Line |
|---|---|---|
| `bs.forge.blartz.01` | blartz | Before you ask: yes, that's a forge. No, you can't afford it. Yes, you'll pay anyway. |
| `bs.forge.blartz.02` | blartz | When OmniScrap arrested me, they seized the prototype schematics. Every page. Even the doodles. ESPECIALLY the doodles. |
| `bs.forge.blartz.03` | sprocket | So why is there a forge bolted to your kiosk? |
| `bs.forge.blartz.04` | blartz | I re-built this one from memory, which is better than the original, which was also perfect. |
| `bs.forge.blartz.05` | blartz | Bring me a weapon at V5 with every mod installed, plus two thousand bolts. I'll teach it things its manufacturer never did. The manufacturer was me. I was holding back. |
| `bs.forge.blartz.06` | bolt | And then what happens to it? |
| `bs.forge.blartz.07` | blartz | It EVOLVES. Gold Omega, new name, new tricks, a very small amount of screaming. From the weapon. Mostly. |
| `bs.forge.blartz.08` | blartz | And the patent is PENDING. B-L-Z, four-oh-four-one-seven. If you ever see this design anywhere else in the universe, call me. Then call a lawyer. Then call me back so I can gloat. |
| `bs.forge.blartz.09` | sprocket | Where else would it show up? |
| `bs.forge.blartz.10` | blartz | Nowhere! The schematics are in an OmniScrap vault, and OmniScrap is about to stop existing. What's the worst that can happen to confiscated paperwork in a fire sale? |
| `bs.forge.blartz.11` | sprocket | I'm writing that down. For later. For a reason. |

**Deny lines** (when you try to evolve before you're ready):

| ID | Condition | Line |
|---|---|---|
| `bs.forge.deny.01` | Below V5 | "That weapon is a CHILD. Use it until it's seen things. Then bring it back." |
| `bs.forge.deny.02` | Mods missing | "You want me to evolve a gun with EMPTY MOD SLOTS? That's like icing a cake you haven't baked. Buy the mods." |
| `bs.forge.deny.03` | No Signature Mod | "It has no signature. Every masterpiece needs a signature. Mine is on the invoice." |
| `bs.forge.deny.04` | Under 2,000 bolts | "Two thousand. Not 'around' two thousand. Not 'emotionally' two thousand. TWO. THOUSAND." |

**Evolution lines** (one per weapon, played at cutscene step 4):

| ID | Weapon → Omega | Line |
|---|---|---|
| `bs.forge.evolve.blaster` | Omni-Blaster → Ω OVERTIME | "OVERTIME. It works late, it never asks for a raise, and it sets things on fire. Ideal employee." |
| `bs.forge.evolve.void` | Void Ripper → Ω SECOND OPINION | "SECOND OPINION. Hits once, thinks about it, hits again. Very thorough. Very medical." |
| `bs.forge.evolve.zap` | Sprocket Zap → Ω FULL CHARGE | "FULL CHARGE. Your robot is now legally a power station. Don't tell the utility board." |
| `bs.forge.evolve.boom` | B.O.O.M. Box → Ω HEADLINER | "HEADLINER! Bigger floor, bigger drop, and the crowd pays double. That's showbiz." |
| `bs.forge.evolve.dart` | Lawn Dart → Ω DOUBLE FAULT | "DOUBLE FAULT. Two darts, two targets, zero sportsmanship." |
| `bs.forge.evolve.patent` | Patent Pending → Ω PATENT GRANTED | "...It's GRANTED. My patent is GRANTED. Somebody get me a frame. And a tissue. A frame first." |
| `bs.forge.evolve.cease` | Cease & Desist → Ω INJUNCTION | "INJUNCTION. Now they can't even fight back while they read it. Legally that's called 'winning'." |
| `bs.forge.evolve.buzz` | Buzzkill → Ω MOOD KILLER | "MOOD KILLER. Five bounces, and every blade has a twin. A very angry twin." |
| `bs.forge.evolve.grav` | Grav Grenade → Ω EVENT HORIZON | "EVENT HORIZON. Physics filed a complaint. I filed it under 'later'." |
| `bs.forge.evolve.mid` | The Middleman → Ω MIDDLE MANAGEMENT | "MIDDLE MANAGEMENT. Two of them now. They've already scheduled a meeting about each other." |
| `bs.forge.evolve.frost` | Frostbyte → Ω DEEP FREEZE | "DEEP FREEZE. Nine seconds of ice. Put a hat on the statue. Sell it as art." |
| `bs.forge.evolve.root` | Root Canal → Ω ORTHODONTIST | "ORTHODONTIST. Five gardens, faster chewing, and the bill arrives in installments." |
| `bs.forge.evolve.latefee` | Late Fee → Ω COMPOUND INTEREST | "COMPOUND INTEREST. The longer you wait, the more it hurts them. Just like a real bank!" |
| `bs.forge.evolve.fineprint` | The Fine Print → Ω TERMS APPLY | "TERMS APPLY. Nobody reads them. That's what makes them so EFFECTIVE." |
| `bs.forge.evolve.hostile` | Hostile Takeover → Ω GOLDEN PARACHUTE | "GOLDEN PARACHUTE. When the contract ends, they leave rich. In the sense that they explode into money." |
| `bs.forge.evolve.clearance` | Clearance Rack → Ω EVERYTHING MUST GO | "EVERYTHING MUST GO. Including their armour. Including their dignity. Final sale!" |

---

## 3. Original stats at a glance (from source)

The twelve web-build weapons, with numbers read from code (the `W_BASE_DMG` column is the shop's stat-bar value):

| # | Name (`WEAPONS`) | Direct damage (code) | `W_BASE_DMG` | Interval | Ammo base / per tier | Price | Trade-in (`SHOP_TRADE_VALUE`) | Original unlock |
|---|---|---|---|---|---|---|---|---|
| 0 | BLASTER | 8 (Hot Round 16, pierce 2, every 5th shot) | 8 | 0.13 | ∞ / 0 | start | 0 | Owned at start |
| 1 | VOID RIPPER | 30 + 35 × charge (30–65), splash 3.5 + 2 × charge | 30 | charge 0.87 s | 12 / 6 | start | 0 | Owned at start |
| 2 | SPROCKET ZAP | 18 / 14 / 11 down the chain | 18 | 0.5 | 30 / 12 | start | 0 | Owned at start |
| 3 | B.O.O.M. BOX | 45 (delivered on the beat after a 1.6 s dance) | 45 | 0.95 | 8 / 4 | 150 | 90 | Always in stock |
| 4 | LAWN DART | 55, splash 3 + 0.5 × dTier, 1.0 s stick fuse | 55 | 1.15 | 5 / 3 | 250 | 150 | Always in stock |
| 5 | PATENT PENDING | 70, splash 5 + 0.6 × dTier; forks 10-damage lawsuits every 0.45 s | 70 | 2.2 | 4 / 2 | gift | 180 | Blartz rescue (Core Foundry) |
| 6 | CEASE & DESIST | 24, ricochets 2 + dTier, SERVED 6 s (+40%) | 24 | 0.5 | 6 / 3 | 300 | 180 | After the first Keystone Core |
| 7 | BUZZKILL | 14 per pass, 3 bounces, pierces | 14 | 0.24 | 20 / 8 | 160 | 96 | Always in stock |
| 8 | GRAV GRENADE | 0 direct; 3 s singularity, r6.5 | 30 | 1.1 | 5 / 2 | 240 | 144 | After clearing Scrapheap |
| 9 | THE MIDDLEMAN | Drone fires 8 every 0.35 s for 12 s | 8 | 0.6 | 3 / 1 | 320 | 192 | After the Nova core |
| 10 | FROSTBYTE | 6 per second (beam), freeze at frost 1.0 | 6 | drain 1 per 0.12 s | 40 / 16 | 320 | 192 | After the Glacius core |
| 11 | ROOT CANAL | Plant chews 8 every 0.5 s for 6 s, roots within 3.2 | 8 | 0.7 | 8 / 3 | 300 | 180 | After the Verdant core |

**Ammo pickups (original):** a purple orb gives +6 Void Ripper and +2 B.O.O.M. Box. A cyan orb gives +10 Zap and +1 Lawn Dart. Each non-crate kill has a 22% chance to drop one. The Ammo Grab-Bag (30 bolts) refills everything.

**Remake ammo families.** All 16 guns join an orb family. An orb gives the listed amount to every owned gun in its family.

| Orb | Guns (amount per orb) |
|---|---|
| Purple ("void stock") | Void Ripper +6, B.O.O.M. Box +2, Grav Grenade +1, Patent Pending +1, Late Fee +3, Hostile Takeover +1 |
| Cyan ("charge stock") | Sprocket Zap +10, Lawn Dart +1, Frostbyte +12, Root Canal +2, The Fine Print +2, Clearance Rack +40 |
| Paper (new; drops from Foundry and Galleria office enemies) | Cease & Desist +2, The Middleman +1 |

The Omni-Blaster uses heat, not ammo.

---

## 4. Status effects

| Status | Applied by | Effect | Duration | Exploited by | Immune |
|---|---|---|---|---|---|
| **SERVED** | Cease & Desist (every hit), Class Action (r6 area), Patent Pending lawsuits | Takes +40% damage from everything (Ω INJUNCTION: +70%, and abilities are blocked for 2 s on each stamp) | 6 s (refreshes) | Hot Rounds ignite SERVED targets; stuck Lawn Darts explode +50% wider; SERVED subsidiaries become stronger allies; Middle Managers can't give reviews while SERVED | None. Bosses can be SERVED (as in the original). |
| **FROZEN** | Frostbyte (frost meter reaches 1.0; heavies need 2.0) | Helpless ice statue. A mallet hit shatters it: 2.5× crit, plus 5 bolts. | 6 s (Ω DEEP FREEZE: 9 s) | Mallet shatter; Zap deals ×2 (frozen counts as double-conductive); Fine Print shots crit anywhere on the statue | Bosses, armoured, Picket Corn (it gets "a little chilly") |
| **SLOWED** | Frostbyte frost build-up (speed falls with frost), Late Fee full-interest blast, Cease & Desist "Desist" mod | −40% move and attack speed (frost build-up: −50% × frost meter) | 3 s | Root Canal roots slowed targets 2× faster; Lawn Darts never miss them | Bosses take half the effect |
| **DANCING** | B.O.O.M. Box | Helpless dance; takes the box's damage on the next music beat | 1.6 s, then the drop (up to 2.5 s waiting for the beat, as in the original) | Mallet hits on dancers always crit (×2); Grav pulls whole dance floors together | Bosses (they take 70% of the box's damage instead, as in the original) |
| **ROOTED** | Root Canal plant (within 3.2 m) | Can't move, dodge, pounce, burrow, blink or leap. It can still shoot. | Refreshed every 0.3 s while in range | Lawn Darts always bullseye a rooted target; mallet launchers can't pop them (they're held) | Bosses, flyers above 3 m |
| **GRAVITY-CLUMPED** | Grav Grenade (r6.5), Void Ripper Rift (r5, pull only) | Dragged to the centre. The collapse launches it (11 m/s up). | Refreshed every 0.4 s | Slam ×1.6 ("GRAV BONUS", kept); a Rift inside a singularity doubles crush damage; Late Fee pellets pierce through clumps | Heavies, bosses (as in the original) |
| **BURNING** | Magma Mallet patches, Hot Rounds on SERVED targets, Spore Lobber self-fire (elite) | 5 damage per second; standing in a Magma patch adds 4 every 0.4 s (as in the original) | 3 s | Thunder Mallet arcs ignite nothing (no double-dipping) | Glacius enemies take half; water and murk pools put it out |
| **CONDUCTIVE** | Sprocket Zap residue and hits (V3+), Thunder Mallet hits | Zap chains reach +3 m further to it and deal ×1.25 | 4 s | Frozen targets count as double-conductive (Zap ×2) | None |
| **MARKED** | The Fine Print | Weak point revealed (it glows through walls for 6 s). The crit radius on it doubles (0.75 → 1.5 m), and crits on it deal 3.0× instead of 2.5×, from every source including Sprocket. Cloaked enemies (Gloomstalkers) are uncloaked; a disguised Return Desk Mimic is outed. | 6 s | Lawn Darts and Super Sprocket target marked weak points first; Ω TERMS APPLY adds +25% from all sources | None |
| **MARKED DOWN** | Clearance Rack (1 stack per hit) | Each stack: plated enemies take +5% gun damage through their plates (a plate pops every 12 stacks); bosses lose 2 points of armour (0.45 → up to 0.65 damage taken outside the weak point at 10 stacks) | Stacks decay 1 per 0.5 s after 2 s without a hit | The mallet strips a plate in one hit at 5+ stacks and deals full damage instead of 40% chip; Ω EVERYTHING MUST GO: 20 stacks = armour 0 | None |
| **ACQUIRED** | Hostile Takeover | Fights for you as a "subsidiary". Enemies within 15 m target it. | 10 s contract | SERVED subsidiaries deal +40% damage and gain +4 s on their contract | Bosses, Picket Corn ("We don't cross picket lines."), Statues |
| **STUNNED** | Mallet combo finisher (0.8 s, as in the original), Collections pull (0.6 s), boss BREAK (3.2 s) | Can't act | As listed | Everything | Armoured bosses (except BREAK) |
| **LAUNCHED** | Mallet launcher, slam, Grav collapse, Ω HEADLINER, Riot Mallet | Airborne and helpless | Until it lands | Air string; Riot Mallet spike | Heavies, turrets, flyers, bosses (as in the original) |

**Priority rules.**
- Frozen overrides dancing and rooted.
- Dancing overrides rooted (the plant lets go to watch).
- Launching cancels rooted.
- A boss BREAK cancels any windup, as in the original.

---

## 5. Combo matrix

Each row lists what that weapon contributes to its partner's column. "—" means no special interaction.

| ↓ applies / → exploits | Mallet | Sprocket / Super | Zap | Lawn Dart | Grav | Blaster | Others |
|---|---|---|---|---|---|---|---|
| **Cease & Desist** (SERVED) | +40% on everything | +40% | +40% | Bigger blast | +40% crush | Hot Round ignites | Strengthens Hostile Takeover subsidiaries; silences Middle Managers |
| **Frostbyte** (FROZEN) | SHATTER 2.5× + 5 bolts | — | ×2 (conducts double) | — | — | — | Fine Print crits anywhere on the statue |
| **B.O.O.M. Box** (DANCING) | Always crits ×2 | — | — | — | Clumps the dance floor | — | Picket Corn dance happily (no hostility) |
| **Root Canal** (ROOTED) | Can't escape the string | — | — | Guaranteed bullseye | — | — | Late Fee: Collections fails on rooted targets (they're held) |
| **Grav Grenade** (CLUMPED) | Slam ×1.6 | — | Arcs hop the clump for free | — | — | — | Void Rift doubles crush; Late Fee pellets pierce |
| **Sprocket Zap** (CONDUCTIVE) | Thunder Mallet arcs +1 hop | Amplify mode | — | — | — | — | Middleman drones and subsidiaries relay arcs |
| **The Fine Print** (MARKED) | Crits on the marked spot | Super targets marked spots first | — | Locks marked spots first, always bullseye | — | Hot Round crits the marked spot | Ω: +25% from everyone |
| **Clearance Rack** (MARKED DOWN) | One-hit plate strip at 5+ stacks | — | — | — | — | — | Buzzkill blades pop plates twice as fast on 5+ stacks |
| **Late Fee** (Collections pull) | Pulled target arrives stunned 0.6 s: free combo | — | — | — | Pull into a clump | — | — |
| **Void Ripper** (Rift) | — | — | — | — | Rift + singularity = double crush | — | Pulls dancers into one floor |
| **The Middleman** (drone) | — | Super Sprocket "Overclock" mode gives drones +50% fire rate | Relay node | — | — | — | Reassign + Lawn Dart Paint target the same enemy |
| **Hostile Takeover** (ACQUIRED) | — | — | Relay node | — | — | — | Ω GOLDEN PARACHUTE: explodes into bolts |
| **Patent Pending** (lawsuits) | — | — | — | — | — | — | Every fork stamps SERVED |
| **Buzzkill** (plate shred) | Plates already gone means full mallet damage | — | — | — | — | — | — |

**Named combos** (the Firing Range "Combo Card" lists these, and the Colosseum challenges reference them):

| Combo name | Recipe | Payoff |
|---|---|---|
| **Due Process** | Cease & Desist → Blaster Hot Round | The Hot Round ignites the SERVED target (BURNING 3 s) and pierces 3 |
| **Cold Call** | Frostbyte → Sprocket Zap | ×2 arc damage on the frozen target; the chain carries on from it |
| **Ice Breaker** | Frostbyte → mallet | SHATTER: 2.5× crit and a bolt fountain (V3: the frost spreads to the crowd) |
| **Floor Filler** | B.O.O.M. Box → mallet | Every mallet hit on a dancer crits ×2 |
| **Collections Agency** | Late Fee Collections → mallet string | The pulled enemy arrives stunned 0.6 s; the full ground string lands |
| **Gravity Bonus** | Grav Grenade → slam | ×1.6 slam on every clumped enemy (kept from the original) |
| **Black Hole Sun** | Grav Grenade + Void Ripper Rift | Crush damage ×2 inside the overlap |
| **Read The Room** | The Fine Print → Lawn Dart | The dart locks the marked weak point and bullseyes it (×1.35, no fuse), with the marked crit on top |
| **Hostile Work Environment** | Hostile Takeover → Cease & Desist on the subsidiary | Ally +40% damage, contract +4 s |
| **Chain of Command** | The Middleman + Sprocket Zap | Arcs relay through the drone without spending a hop |
| **Markdown Smash** | Clearance Rack (5 stacks) → mallet | A plate strips in one hit with full damage |
| **Weed Whacker** | Root Canal → Lawn Dart | A rooted target can't dodge, so it's always a bullseye |
| **Legal Precedent** | Patent Pending sphere passing a Cease & Desist ricochet | The ricochet copies onto the sphere: every fork bounces once more |

---

## 6. Role uniqueness check

Brief §5.2: no two weapons may share a role at the same tier. "Tier" is checked two ways: by **unlock bracket** (when you get it) and by **evolution stage** (V1, V5, Ω). Each stage has 16 distinct roles.

| # | Weapon | Unlock bracket | Role at V1 | Role at V5 (sharpened) | Role at Ω |
|---|---|---|---|---|---|
| 1 | Omni-Blaster | A (start) | Reliable sidearm | Sidearm + igniter | Sidearm that forks sparks |
| 2 | Void Ripper | A (start) | Charge burst | Piercing charge burst | Double-impact burst |
| 3 | Sprocket Zap | A (start) | Chain crowd damage | 5-target chain | Relay-network chain |
| 4 | B.O.O.M. Box | A (Scrapheap) | Crowd-control grenade | Crowd control + knock-up | Crowd control + launcher |
| 5 | Lawn Dart | A (Scrapheap) | Homing burst | Re-acquiring homing | Twin-lock homing |
| 6 | Patent Pending | C (Foundry gift) | Signature spectacle | Spectacle + residual zone | Fast-fork spectacle |
| 7 | Cease & Desist | B (first core) | Debuff support | 4-ricochet debuff | Debuff + silence |
| 8 | Buzzkill | A (Scrapheap) | Geometry skill shot | Anti-armour skill shot | 5-bounce splitting skill shot |
| 9 | Grav Grenade | A (Scrapheap clear) | Grouping | Grouping + collapse damage | Instant-crush grouping |
| 10 | The Middleman | B (Nova core) | Deployable aggro | Shielded aggro | Two-drone aggro |
| 11 | Frostbyte | B (Glacius core) | Freeze + bolt farming | Piercing freeze | 9 s deep freeze |
| 12 | Root Canal | B (Verdant core) | Area denial | Wide, long denial | Five-garden denial |
| 13 | Late Fee | B (Rustvane) | Close-range shotgun | Staggering shotgun | Self-refunding shotgun |
| 14 | The Fine Print | B (Nova) | Marksman | Wall-sight marksman | Team-amp marksman |
| 15 | Hostile Takeover | B (Verdant) | Conversion | Faster conversion | Explosive conversion |
| 16 | Clearance Rack | B (Galleria) | Sustained DPS | Sustained DPS + crit rounds | No-spin-up armour breaker |

Bracket A has 7 distinct roles, bracket B has 8, and bracket C has 1. Two overlaps were checked and resolved:
- **Buzzkill and Clearance Rack** both touch armour. Buzzkill's role is the *geometry skill shot*: plate shredding is its status identity, not its role. Clearance Rack's role is *sustained DPS*: markdown is its status.
- **B.O.O.M. Box and Grav Grenade** are both lobbed. One disables (dance). The other relocates (clump).

---

## 7. Weapon wheel and inputs

**Wheel.** The radial wheel stays (it was `openWheel`/`buildWheelDOM` in the original).

- **Pages of 8.** Page 1 holds slots 1–8 and page 2 holds slots 9–16. The default order follows the numbering in this doc.
- In the pause menu → **Loadout**, the player can drag any gun to any slot on either page.
- Unowned slots show a dark silhouette and a one-line unlock hint, such as "Blartz stocks this on Rustvane."
- While the wheel is open, time slows to 30%. (The original didn't slow time. The remake has twice as many guns, so it needs the breathing room.)
- The hub shows the highlighted gun's name, V-level pips, mod pips, Ω status and ammo.

**Quick-swap last weapon.**
- **Tap** the swap input to switch to the previously equipped gun.
- **Hold** it to open the wheel. The 0.18 s tap/hold threshold is kept from the original RB logic.

**Default bindings.**

| Action | Keyboard / mouse | Pad | Original |
|---|---|---|---|
| Fire | LMB | RT | Same |
| Alt-fire | RMB-click while aiming, or **V** | **LB** | New. Originally LB cycled to the previous weapon, which quick-swap now covers. |
| Quick-swap (tap) / wheel (hold) | **Q** tap / **Tab** or Q hold | **RB** tap / RB hold | Originally RB tap = next weapon, Tab = wheel, Q/E = cycle |
| Wheel page | Mouse wheel, or Q/E while the wheel is open | LB/RB while the wheel is open | New |
| Direct select | 1–8 (current page) | — | Originally 1–7 |
| Gadget (K.A.R.E.N.) | K | D-pad Down | Originally K only |
| Super Sprocket | T | D-pad Up | Same |

Everything can be remapped (brief §12).

---

## 8. The arsenal — originals (1–12)

Each entry has the same blocks: **Role · Unlock · Original stats · Remake baseline · Primary · Alt-fire · Status identity · Combos · Levels (V1/V3/V5/Ω) · Signature Mods · Model by level · Brand pitch**.

### 8.1 OMNI-BLASTER (slot 1)

- **Role:** reliable sidearm. It's the gun that is always correct, never optimal.
- **Unlock:** owned at the start.
- **Original stats:** 8 damage, 0.13 s interval, projectile speed 46, infinite ammo. Every 5th shot is a Hot Round: 16 damage, pierce 2, bigger and louder.

**Remake baseline.**

| Stat | Value |
|---|---|
| Damage | 8 per bolt (Hot Round 16) |
| Interval | 0.13 s (about 7.7 shots/s) |
| Delivery | Hitscan with a visible tracer (the original was a 46 m/s projectile; the tracer keeps that look). Range 60 m; falls to 60% damage beyond 30 m. |
| Heat | +6 per shot, 100 max (+20 per Heat Sink tier). Vents at 40/s after 0.35 s without firing. At 100 heat: **overheat**, a forced 1.0 s vent with a steam burst. |
| Hot Round (auto) | Every 5th shot: 16 damage, pierce 2 (as in the original) |

- **Primary:** rapid hitscan bolts. A full-heat burst is about 17 shots (2.2 s) before overheat.
- **Alt-fire — HOT ROUND:** a charged piercing shot that consumes the heat bar.
  - Needs at least 25 heat.
  - Damage is 16 + 0.5 × heat (up to 66), pierce 3. Heat drops to 0 with no overheat penalty.
  - So the rhythm is: spray, then cash the heat in for a big shot.
- **Status identity:** **BURNING** via SERVED. A Hot Round that hits a SERVED target ignites it.
- **Combos:** Due Process (Cease & Desist → Hot Round). Hot Rounds crit a Fine Print–marked weak point. A Hot Round on a stunned (post-finisher) enemy always crits.

| Level | Behaviour |
|---|---|
| V1 | As above |
| V3 | Vent rate 40 → 55/s, and the auto Hot Round comes every 4th shot |
| V5 | A Hot Round alt fired at 90+ heat becomes a **MAX HOT ROUND**: it ignites everything it pierces, SERVED or not |
| **Ω OVERTIME** | Every 3rd shot is a Hot Round (`OMEGA_DESC[0]`). Hot Rounds fork 2 sparks (6 damage each) at bystanders within 6 m. Upgrade over the original: the sparks also apply CONDUCTIVE. |

**Signature Mods.**
- **A — Cool Customer:** no overheat lockout. At 100 heat, the fire rate halves until heat drops below 70. Built for players who never let go of the trigger.
- **B — Thermal Debt:** the Hot Round alt works at any heat, and its scaling doubles (16 + 1.0 × heat, up to 116). But it puts you straight into a 1.0 s overheat.

**Model by level:** V2 copper heat-fins along the barrel · V3 a glowing heat gauge on top · V4 a second ejection port · V5 an orange-hot muzzle ring · Ω gold fins and a "Ω OVERTIME — NO BREAKS" stencil.

**Brand pitch** (ad vignette `ad_blaster`, kept):
- `cs.ad_blaster.01` (blartz): "It's a sunny day at the picnic! But what's this? UNLICENSED geese! Introducing the OMNI-BLASTER — infinite ammo, zero remorse!"
- `cs.ad_blaster.02` (pa): "The Omni-Blaster. Because a picnic is only as safe as its overwhelming firepower."

"Infinite ammo" is still true. The heat bar isn't ammo, and Blartz will argue that point.

### 8.2 VOID RIPPER (slot 2)

- **Role:** charge burst.
- **Unlock:** owned at the start.
- **Original stats:** hold to charge (charge reaches 1.0 after 0.87 s). Damage 30 + 35 × charge, splash 3.5 + 2 × charge, speed 20 + 6 × charge, slight gravity (4). An implosion pulls nearby non-boss enemies inward (9 m/s knock) before the blast, and drags bolt pickups within 4.5 m. Ammo 12 (+6 per tier).

**Remake baseline.**

| Stat | Value |
|---|---|
| Damage | 30–65 (by charge) |
| Splash | 3.5–5.5 m |
| Charge time | 0.87 s to full |
| Ammo | 12 (+6 per tier) |

- **Primary:** hold to charge an implosion orb, release to fire. Fully charged orbs pull bolts along their flight path.
- **Alt-fire — RIFT:** plants a tear at the aim point (within 15 m) for 3 s.
  - Pulls non-heavy enemies within 5 m toward its centre at 6 m/s. No damage.
  - Costs 2 ammo, 6 s cooldown.
  - A charged orb fired into a Rift gets +50% splash ("RIFT COLLAPSE").
- **Status identity:** **GRAVITY-CLUMPED** (pull).
- **Combos:** Black Hole Sun (a Rift inside a Grav singularity doubles crush damage). A Rift pulls dancing enemies onto one floor for a mallet crowd-crit.

| Level | Behaviour |
|---|---|
| V1 | As above |
| V3 | Charge time −25% (0.65 s); bolt drag radius 4.5 → 8 m |
| V5 | A fully charged orb pierces the first enemy, then implodes on the second (or on terrain) |
| **Ω SECOND OPINION** | The impact triggers a delayed second implosion: 0.4 s re-collapse, then a 0.22 s blast at splash + 1.5 for 70% damage, labelled "AFTERSHOCK" (`OMEGA_DESC[1]`, original timings). Upgrade over the original: it works at any charge above 50%, and the aftershock also pulls loose bolts to Bolt. |

**Signature Mods.**
- **A — Pocket Universe:** the Rift lasts 5 s and has a 7 m radius, but pulls at only 4 m/s.
- **B — Quick Collapse:** a tap fires an instant 50% orb with +20% damage, so no full charge is ever needed. Holding still charges, but caps at 75%.

**Model by level:** V2 a second containment ring · V3 a violet coolant line · V4 floating shield shards · V5 a slow-turning event-horizon disc at the muzzle · Ω gold rings and a stethoscope-shaped coil (the "second opinion").

**Brand pitch** (`ad_void`, kept):
- `cs.ad_void.01` (blartz): "Ants at the picnic? Not for long! The VOID RIPPER opens a tasteful little hole in reality. The ants go... somewhere. We don't ask."
- `cs.ad_void.02` (sprocket): "Where do they GO, Blartz."
- `cs.ad_void.03` (blartz): "AWAY. They go away. Buy the Void Ripper!"

### 8.3 SPROCKET ZAP (slot 3)

- **Role:** chain crowd damage.
- **Unlock:** owned at the start.
- **Original stats:**
  - 0.5 s interval. First target within 11 m, roughly in front.
  - Chains to the nearest unhit enemy within 6.5 m, up to 2 more (3 total).
  - Damage 18 / 14 / 11 down the chain.
  - The last target leaves an electric residue patch (r1.4, 1.6 s; it ticks like a fire patch, 4 damage every 0.4 s).
  - Higher damage tiers added strands.
  - Ammo 30 (+12 per tier).
  - Sprocket himself points, fires and recoils.

**Remake baseline.**

| Stat | Value |
|---|---|
| Chain damage | 18 / 14 / 11 (then 10 / 9 for targets 4 and 5) |
| Interval | 0.5 s |
| Targets | 3 (first within 11 m, each hop within 6.5 m) |
| Residue | r1.4, 1.6 s, 4 damage per 0.4 s |
| Ammo | 30 (+12 per tier) |

- **Primary:** Sprocket fires an arc that chains between enemies. It fizzles with no ammo cost if nothing is in range (as in the original).
- **Alt-fire — AMPLIFY** (hold): Sprocket stops following you and hovers in place as a pylon.
  - Chains get +1 target and hop range 6.5 → 9 m. Damage ×1.3. Ammo drain ×1.5.
  - He complains the whole time (`bs.weapon.zap.amp.<nn>`, §11).
  - Releasing, or moving more than 12 m away, ends it.
- **Status identity:** **CONDUCTIVE** (from V3).
- **Combos:** Cold Call (frozen targets take ×2 and carry the chain). Middleman drones and Hostile Takeover subsidiaries relay arcs without spending a hop (Chain of Command). Thunder Mallet hits make targets conductive for the Zap.

| Level | Behaviour |
|---|---|
| V1 | 3 targets |
| V3 | 4 targets; a third strand (was Damage tier 1); every target hit becomes CONDUCTIVE 4 s; residue radius 1.4 → 2.0 |
| V5 | 5 targets |
| **Ω FULL CHARGE** | 5 targets, double-width residue (r2.8 for 2.2 s, `OMEGA_DESC[2]`'s original numbers). Upgrade over the original: each relay node (drone or subsidiary) re-forks the arc into two branches, and chain damage never drops below 11. With Amplify that's 6 targets, which finally makes the ad's "up to six wrongdoers" true. |

**Signature Mods.**
- **A — Surge Protector:** residue patches last 4 s and stack (two overlapping patches tick twice).
- **B — Long Distance:** first-target range 11 → 18 m, but one fewer chain target.

**Model by level:** V2 Sprocket's antenna gets a copper coil · V3 a spark-gap crown · V4 insulated cable "sleeves" · V5 his eyes go white-blue while firing · Ω a gold lightning-bolt decal on his chassis, and he insists it's "a birthmark."

**Brand pitch** (`ad_zap`, kept):
- `cs.ad_zap.01` (blartz): "Grandma's lemonade needs CHILLING and your enemies need CHAINING! The ZAPINATOR arcs between up to six wrongdoers. Refreshing!"

Blartz calls it the "ZAPINATOR" because that's what he tried to trademark. The HUD name stays SPROCKET ZAP. See §14 for the "six".

### 8.4 B.O.O.M. BOX (slot 4)

- **Role:** crowd-control grenade.
- **Unlock:** Blartz's stock from the start, **150 bolts** (trade-in 90).
- **Original stats:**
  - 0.95 s interval. Lobbed at 15 m/s forward plus 5 up, gravity 16.
  - On impact, every non-boss enemy within 5.5 m dances for 1.6 s, then takes 45 damage on the next music beat.
  - Bosses take 70% damage immediately instead.
  - Ammo 8 (+4 per tier). "Includes 8 complimentary mixtapes."

**Remake baseline.**

| Stat | Value |
|---|---|
| Damage | 45 per dancer, on the beat |
| Dance radius | 5.5 m |
| Dance time | 1.6 s (then up to 2.5 s more waiting for the beat) |
| Interval | 0.95 s |
| Ammo | 8 (+4 per tier) |

- **Primary:** lob a subwoofer. On landing it projects a light-grid dance floor, and enemies on it are forced to DANCE.
- **Alt-fire — DROP THE BASS:** remote detonate early. Every enemy currently dancing to your most recent box takes the drop immediately at 80% damage. Use it when the beat is too far away or a dancer is about to be knocked off the floor.
- **Status identity:** **DANCING.**
- **Combos:** Floor Filler (mallet hits on dancers always crit ×2). A Grav Grenade on a dance floor clumps the dancers. Picket Corn aren't angered by it; they think it's a solidarity rally.

| Level | Behaviour |
|---|---|
| V1 | As above |
| V3 | Radius 5.5 → 6.5 m; each dancer drops +1 bolt |
| V5 | The drop also knocks dancers up 6 m/s (a mini launch for the air string) |
| **Ω HEADLINER** | Radius 7.5 m and every raver drops double bolts (`OMEGA_DESC[3]`, original numbers). Upgrade over the original: the drop is a full launch (11 m/s), and the box keeps playing one encore beat later at 50% damage. |

**Signature Mods.**
- **A — Extended Mix:** the dance lasts 3 s and the drop deals ×1.3. Slower, bigger.
- **B — Radio Edit:** the box drops 0.8 s after landing with no beat wait, but the radius is 20% smaller.

**Model by level:** V2 a chrome speaker grille · V3 LED strips that pulse to the music engine · V4 a second woofer · V5 a tiny glitter ball on top · Ω gold-plated woofers and a "HEADLINER" marquee.

**Brand pitch** (`ad_boom`, kept):
- `cs.ad_boom.01` (blartz): "Is the barbecue not lit? IT IS NOW. The BOOM BOX — lob it, love it, live at a safe distance from it!"
- `cs.ad_boom.02` (pa): "OmniScrap is not liable for the barbecue, the yard, or the concept of the yard."

### 8.5 LAWN DART (slot 5)

- **Role:** homing burst.
- **Unlock:** Blartz's stock from the start, **250 bolts** (trade-in 150).
- **Original stats:**
  - 1.15 s interval. Locks the nearest enemy roughly in front within 26 m. Flies at 14 m/s, homing at a turn rate of 2.2.
  - 55 damage, splash 3 + 0.5 × dTier.
  - It sticks into the target and detonates after a 1.0 s beeping fuse.
  - A weak-point hit ("BULLSEYE") skips the fuse for ×1.35.
  - A pitch-dropping whistle plays in flight. Ammo 5 (+3 per tier).

**Remake baseline.**

| Stat | Value |
|---|---|
| Damage | 55 (bullseye ×1.35) |
| Splash | 3 m |
| Fuse | 1.0 s |
| Interval | 1.15 s |
| Lock range | 26 m |
| Ammo | 5 (+3 per tier) |

- **Primary:** fire a slow, patient homing dart that sticks, then detonates.
- **Alt-fire — PAINT:** hold alt and sweep the reticle across up to 3 targets (0.35 s on each paints it). Then fire to launch a volley: one dart per painted target at 75% damage, costing 1 ammo each.
- **Status identity:** detonations on **SERVED** targets are 50% wider.
- **Combos:** Read The Room (Fine Print marks are locked first and always bullseye). Weed Whacker (rooted targets are always a bullseye). Middleman Reassign plus Paint focuses everything on one target.

| Level | Behaviour |
|---|---|
| V1 | As above |
| V3 | Fuse 1.0 → 0.7 s |
| V5 | If a dart's target dies before impact, the dart re-locks the nearest enemy within 12 m |
| **Ω DOUBLE FAULT** | Two darts per trigger, each locking a different target; the second deals 40 (`OMEGA_DESC[4]`, original numbers). Upgrade over the original: both darts deal the full 55, and Paint volleys fire two darts per painted target. |

**Signature Mods.**
- **A — Lawn Ordinance:** darts that detonate inside SERVED or rooted targets split into 3 bomblets of 15 damage (r1.5).
- **B — Express Delivery:** speed 14 → 22, turn rate 2.2 → 3.5. Darts never stick; they always detonate on impact (no fuse, no bullseye bonus).

**Model by level:** V2 striped fins · V3 a lawn-flamingo hood ornament · V4 a second launch tube · V5 a "KEEP OFF THE GRASS" sign used as a sight · Ω gold tips and a tennis-net pattern on the tubes.

**Brand pitch** (`ad_dart`, kept):
- `cs.ad_dart.01` (blartz): "Lawn games! Wholesome! The LAWN DART sticks in ANYTHING — the fence, the grill, that guy. Then it goes off. FUN for the whole family unit!"

### 8.6 PATENT PENDING (slot 6)

- **Role:** signature spectacle.
- **Unlock:** Blartz's gift at the rescue (story beat `blartzRescue`, `cs.blartzRescue.03–04`) in the Core Foundry. Free (trade-in 180, but Blartz takes it personally: the trade-in confirm reads "You'd sell my MASTERPIECE?").
- **Serial:** **BLZ-40417**, stamped on the receiver. (Shared fact: it's the same number as the Omega Forge patent and the Crucible plaque.)
- **Original stats:**
  - 2.2 s interval. A 0.55-size orb at 8 m/s, lasting 4.5 s.
  - It forks a 10-damage homing lawsuit bolt at the nearest enemy within 13 m every 0.45 s, then detonates: 70 damage, splash 5 + 0.6 × dTier.
  - The cooling fan pops off and bounces away after each detonation.
  - Ammo 4 (+2 per tier).
  - Mods were locked until the rescue.

**Remake baseline.**

| Stat | Value |
|---|---|
| Detonation | 70, splash 5 m |
| Fork | 10 damage + **SERVED 3 s**, every 0.45 s, range 13 m |
| Interval | 2.2 s |
| Ammo | 4 (+2 per tier) |

- **Primary:** a slow sphere of litigation that forks smaller lawsuits at bystanders, then detonates.
- **Alt-fire — FILE EARLY:** hold to grow the sphere (up to 1.5 s: size ×1.8, detonation ×1.5). Release to place it as a slow hazard drifting at 2 m/s for 6 s, forking the whole time, then detonating. 1 ammo.
- **Status identity:** **SERVED.** Every lawsuit stamps it.
- **Combos:** Legal Precedent (a Cease & Desist ricochet that passes through the sphere makes every fork bounce once more). Forks prime targets for Due Process.

| Level | Behaviour |
|---|---|
| V1 | As above |
| V3 | Fork interval 0.45 → 0.35 s |
| V5 | The detonation leaves a "PENDING" zone (r4, 4 s) that forks one lawsuit per second |
| **Ω PATENT GRANTED** | Forks twice as fast (0.22 s) with a bigger splash (+2 m) (`OMEGA_DESC[5]`, original numbers). Upgrade over the original: lawsuits apply SERVED for the full 6 s, and the ejected cooling fan becomes a bouncing 20-damage saw (Blartz: "As designed."). The receiver stamp changes from PATENT PENDING to **PATENT GRANTED · BLZ-40417**. |

**Signature Mods.**
- **A — Provisional:** sphere speed 8 → 14 m/s, splash −1 m. Less hazard, more cannon.
- **B — Prior Art:** each enemy hit by a fork becomes a fork source once (a 6-damage lawsuit to its nearest neighbour), which builds a web.

**Model by level:** V2 extra taped warnings · V3 a second cooling fan (it also refuses to be explained) · V4 exposed coil glow · V5 a pending-stamp turret that spins when firing · Ω gold coils and a framed patent certificate riveted to the side.

**Brand pitch** (`ad_patent`, kept):
- `cs.ad_patent.01` (blartz): "PATENT PENDING! I can't tell you what it does — that's PENDING — but legally it's AMAZING and you should give me bolts NOW!"
- `cs.ad_patent.02` (sprocket): "That's just a gun with paperwork."
- `cs.ad_patent.03` (blartz): "It's a gun with a FUTURE."

**Plot:** Darkmatter's legal team later claims this patent (The Fine Print Ch. 4).

### 8.7 CEASE & DESIST (slot 7)

- **Role:** debuff support.
- **Unlock:** Blartz's stock after the first Keystone Core (Nova, Glacius or Verdant), **300 bolts** (trade-in 180).
- **Original stats:**
  - 0.5 s interval, 30 m/s.
  - 24 damage; stamps **SERVED** (6 s, +40% damage taken from everything).
  - Ricochets to the nearest unserved enemy within 16 m, 2 + dTier times.
  - The impact is a flurry of documents. Ammo 6 (+3 per tier).

**Remake baseline.**

| Stat | Value |
|---|---|
| Damage | 24 |
| Ricochets | 2 (range 16 m) |
| SERVED | 6 s, +40% |
| Interval | 0.5 s |
| Ammo | 6 (+3 per tier) |

- **Primary:** a ricocheting legal document stamps each target SERVED.
- **Alt-fire — CLASS ACTION:** one heavy notice. 60 damage to the target, and everything within 6 m of it is SERVED for 8 s. No ricochet. 2 ammo, 1.5 s cooldown.
- **Status identity:** **SERVED.** It enables every other weapon.
- **Combos:** Due Process, Hostile Work Environment. It silences Middle Managers (they can't review while SERVED). It overloads The Algorithm (each notice on its core adds 4% of its max HP to the BREAK meter; Class Action adds 10%; see BS_ENEMIES).

| Level | Behaviour |
|---|---|
| V1 | 2 ricochets |
| V3 | +1 ricochet (was the Damage-tier ricochet bonus); ricochet range 16 → 20 m |
| V5 | +1 ricochet (4 total); SERVED stamps also mark the paper trail: the document leaves a 1 s line between targets that SERVES anything walking through it |
| **Ω INJUNCTION** | Ricochets to 6 defendants; SERVED = +70% instead of +40% (`OMEGA_DESC[6]`, original numbers; it also lasts 3.4 s in flight, as in the original). Upgrade over the original: each stamp also blocks abilities for 2 s (no pounce, burrow, review, rally, summon, cloak or blink). |

**Signature Mods.**
- **A — Cease:** SERVED lasts 10 s.
- **B — Desist:** SERVED targets are also SLOWED (−25%), but SERVED gives +30% instead of +40%.

**Model by level:** V2 a rubber-stamp hammer · V3 a dot-matrix feed tray · V4 a wax-seal stamper · V5 a tiny gavel that strikes on every shot · Ω a gold seal reading "SO ORDERED."

**Brand pitch** (`ad_cease`, kept):
- `cs.ad_cease.01` (blartz): "Rude relatives at the reunion? Serve them! CEASE AND DESIST fires a legal document that bounces between wrongdoers, stamping each one SERVED. Litigation: now a spectator sport!"

### 8.8 BUZZKILL (slot 8)

- **Role:** geometry skill shot.
- **Unlock:** Blartz's stock from the start, **160 bolts** (trade-in 96).
- **Original stats:**
  - 0.24 s interval. A saw blade at 34 m/s, lasting 2.2 s.
  - 14 damage to every enemy it passes through (once each per pass).
  - Bounces off geometry 3 times.
  - At Damage tier 3, it splits into two on the first bounce (the second blade: 70% damage, 2 bounces).
  - Ammo 20 (+8 per tier).

**Remake baseline.**

| Stat | Value |
|---|---|
| Damage | 14 per pass |
| Bounces | 3 |
| Interval | 0.24 s |
| Ammo | 20 (+8 per tier) |

- **Primary:** saw blades that ricochet off walls up to 3 times, shredding everything in the path.
- **Alt-fire — MANUAL OVERRIDE:** hold to steer the most recent blade with the camera for up to 1.5 s. It slows to 22 m/s while steered, and bounces still count.
- **Status identity:** **plate shred** (anti-armour).
  - Blades deal 50% damage *through* plating instead of pinging off. Other guns ping off, as in the original.
  - Every 4 blade hits on a plated enemy pops one plate (Slag Golem plates, the HOA riot shield, Excavatron chest plates).
- **Combos:** stripped plates mean full mallet damage. On MARKED DOWN targets (5+ stacks), plates pop every 2 hits.

| Level | Behaviour |
|---|---|
| V1 | As above |
| V3 | Blades split on the first bounce (70% damage, 2 bounces) (was Damage tier 3) |
| V5 | A plate pops every 2 blade hits; split blades keep 100% damage |
| **Ω MOOD KILLER** | Five bounces, and every blade splits on the first one (`OMEGA_DESC[7]`). Upgrade over the original: each split blade splits once more on its own first bounce (4 blades per shot). |

**Signature Mods.**
- **A — Hedge Trimmer:** each blade orbits Bolt at 1.5 m for 1.2 s before launching. It's a close-range shredder that punishes swarms (Weld Wasps).
- **B — Bank Shot:** each bounce adds +25% damage (+75% by the third bounce). Skill rewarded.

**Model by level:** V2 a serrated guard · V3 a spare blade riding on top (as in the original model) · V4 a blade magazine wheel · V5 a sparking grinder wheel · Ω gold teeth on every blade and a smiley-face sticker that has been scratched out.

**Brand pitch** (`ad_buzz`, kept):
- `cs.ad_buzz.01` (blartz): "Trim the hedges! Trim the MOOD! BUZZKILL saws bounce off walls THREE times. Ricochet responsibly. Or don't. I'm a salesman, not a cop."

### 8.9 GRAV GRENADE (slot 9)

- **Role:** grouping.
- **Unlock:** Blartz's stock after clearing Scrapheap Junction (defeating Repo-Tron), **240 bolts** (trade-in 144).
- **Original stats:**
  - 1.1 s interval, lobbed.
  - A micro-singularity lasting 3 s (5 s at Damage tier 3), r6.5.
  - It drags non-heavy, non-boss enemies to the centre and pulls bolts within 8 m. At tier 3, it crushes for 6 damage every 0.5 s.
  - The collapse launches everything at 11 m/s.
  - A slam on clumped enemies deals ×1.6 ("GRAV BONUS"). Ammo 5 (+2 per tier).

**Remake baseline.**

| Stat | Value |
|---|---|
| Duration | 3 s |
| Radius | 6.5 m |
| Pull | 1.6 × distance per second |
| Crush | none at V1 |
| Interval | 1.1 s |
| Ammo | 5 (+2 per tier) |

- **Primary:** a micro-singularity vacuums enemies and loose bolts into a clump, then pops them skyward.
- **Alt-fire — HOLD:** keep the most recent singularity open while alt is held. Each extra 2 s costs 1 ammo, up to +4 s. It collapses on release.
- **Status identity:** **GRAVITY-CLUMPED.**
- **Combos:** Gravity Bonus (slam ×1.6, kept). Black Hole Sun (with a Void Rift). Zap arcs hop a clump for free. Late Fee pellets pierce clumps.

| Level | Behaviour |
|---|---|
| V1 | As above |
| V3 | 5 s duration; crush 6 every 0.5 s, starting 1 s after opening (was Damage tier 3) |
| V5 | The collapse deals 20 damage to everything launched, and bolt pull radius 8 → 12 m |
| **Ω EVENT HORIZON** | Singularities last 6.5 s and crush from the moment they open (`OMEGA_DESC[8]`). Upgrade over the original: heavies (not bosses) inside are SLOWED instead of ignored. |

**Signature Mods.**
- **A — Tidy Up:** radius 6.5 → 9 m, no crush. Pure grouping.
- **B — Compactor:** radius 4.5 m, crush ×2.

**Model by level:** V2 a gyroscope cage · V3 an orbiting debris ring · V4 a lensing glass shell · V5 a tiny accretion disk that spins in the hand · Ω a gold cage and an "OBJECTS IN GRENADE ARE CLOSER THAN THEY APPEAR" label.

**Brand pitch** (`ad_grav`, kept):
- `cs.ad_grav.01` (blartz): "Tidying up? The GRAV GRENADE vacuums the whole picnic — ants, enemies, potato salad — into one convenient CLUMP. Then slam it! Physics: finally on YOUR payroll!"

### 8.10 THE MIDDLEMAN (slot 10)

- **Role:** deployable aggro.
- **Unlock:** Blartz's stock after the Nova Plaza core, **320 bolts** (trade-in 192).
- **Original stats:**
  - 0.6 s interval. Deploys one hovering drone 3 m ahead for 12 s.
  - It auto-fires 8 damage every 0.35 s at the nearest enemy within 22 m.
  - At Damage tier 3, it explodes at contract end (45 damage, r5, "OUTSOURCED!").
  - One at a time ("Union rules"); two at Ω ("SUBCONTRACTED"). Ammo 3 (+1 per tier).
  - *In the source the drone never actually pulled enemy aggro; enemies always targeted Bolt. The remake implements the aggro the shop text promised.*

**Remake baseline.**

| Stat | Value |
|---|---|
| Duration | 12 s |
| Drone damage | 8 every 0.35 s, range 22 m |
| Drone HP | 120 (it can now be destroyed) |
| Aggro | Each non-boss enemy within 15 m has a 70% chance to switch its target to the drone; it re-rolls every 3 s |
| Interval | 0.6 s |
| Ammo | 3 (+1 per tier) |

- **Primary:** deploy a hovering turret drone that draws aggro and fires for 12 s.
- **Alt-fire — REASSIGN:** point at an enemy. Every drone focuses it for 4 s, and enemies within 10 m of it are taunted onto the nearest drone. 4 s cooldown.
- **Status identity:** **taunt** (aggro redirect). Bosses ignore taunts, except that Greeter Prime is helplessly polite to drones (see BS_ENEMIES).
- **Combos:** Chain of Command (drones relay Zap arcs). Super Sprocket's Overclock mode gives drones +50% fire rate. Reassign plus Lawn Dart Paint.

| Level | Behaviour |
|---|---|
| V1 | As above |
| V3 | At contract end the drone explodes for 45 damage, r5, "OUTSOURCED!" (was Damage tier 3) |
| V5 | The drone gets a 60-point shield, and Reassign has no cooldown |
| **Ω MIDDLE MANAGEMENT** | Two Middlemen at once, and they won't get along (`OMEGA_DESC[9]`). Upgrade over the original: the two argue in barks (`bs.weapon.middleman.argue.<nn>`, §11), and whichever drone has more kills when its contract ends explodes for double damage. |

**Signature Mods.**
- **A — Consultant:** the contract lasts 20 s, but the drone draws no aggro at all. A pure turret.
- **B — Scapegoat:** aggro radius 25 m, 100% retarget chance, the drone takes 50% less damage, and it fires half as often.

**Model by level:** V2 a lanyard ID badge · V3 a clipboard arm · V4 a second rotor · V5 a tiny desk fan and a "WORLD'S OKAYEST CONTRACTOR" mug · Ω a gold tie, and the second drone's tie is a clip-on (it knows).

**Brand pitch** (`ad_mid`, kept):
- `cs.ad_mid.01` (blartz): "Too much to DO at the cookout? Delegate! THE MIDDLEMAN deploys a little drone that takes the heat AND the credit for twelve whole seconds. Management made simple!"
- `cs.ad_mid.02` (pa): "The Middleman is a contractor, not an employee. It has no benefits and no feelings. Probably."

### 8.11 FROSTBYTE (slot 11)

- **Role:** freeze + bolt farming.
- **Unlock:** Blartz's stock after the Glacius Vault core, **320 bolts** (trade-in 192).
- **Original stats:**
  - A held beam. Range 18 m, in a narrow cone (dot > 0.9). Drains 1 ammo every 0.12 s.
  - 6 damage per second. The frost meter builds at 1.4 + 0.25 × dTier per second; at 1.0 (about 0.7 s) a non-armoured enemy freezes for 6 s.
  - A mallet hit on a frozen enemy SHATTERS it: 2.5× crit and 5 bolts.
  - At Damage tier 3, a shatter spreads freeze to everything within 5 m.
  - Ammo 40 (+16 per tier).

**Remake baseline.**

| Stat | Value |
|---|---|
| Beam | 6 per second, range 18 m |
| Freeze | at frost 1.0 (heavies need 2.0); lasts 6 s |
| Frost build | 1.4 per second |
| Drain | 1 ammo per 0.12 s |
| Ammo | 40 (+16 per tier) |

- **Primary:** a coolant beam that freezes enemies into ice statues. Shatter them for a fountain of bolts. Targets building frost are SLOWED in proportion.
- **Alt-fire — ICE WALL:** raises a 4 m × 2.5 m barrier at the aim point (within 10 m).
  - 150 HP, 6 s. It blocks enemy projectiles and pathing.
  - Enemies touching it gain 0.5 frost per second.
  - 8 ammo, 5 s cooldown.
- **Status identity:** **FROZEN** (and SLOWED while building).
- **Combos:** Ice Breaker (mallet SHATTER). Cold Call (Zap ×2). The Fine Print crits anywhere on a statue.

| Level | Behaviour |
|---|---|
| V1 | As above |
| V3 | A SHATTER spreads freeze to everything within 5 m (was Damage tier 3) |
| V5 | The beam passes through the first frozen target to keep freezing the next one |
| **Ω DEEP FREEZE** | Longer beam (26 m), faster freeze (×1.6), statues stay iced 9 s (`OMEGA_DESC[10]`, original numbers). Upgrade over the original: ice walls are 2× wider, and enemies that touch them freeze instantly. |

**Signature Mods.**
- **A — Cold Storage:** a SHATTER drops 8 bolts instead of 5. The bolt farmer's choice.
- **B — Flash Freeze:** a narrower beam (dot 0.95) but freeze rate ×1.5, and heavies freeze at 1.0 like everyone else.

**Model by level:** V2 a frosted coolant tank · V3 icicles on the barrel · V4 a second tank · V5 a little snow-globe sight with a tiny OmniScrap HQ inside · Ω gold frost-lines and an ice-sculpture swan hood ornament.

**Brand pitch** (`ad_frost`, kept):
- `cs.ad_frost.01` (blartz): "Keep the drinks cold AND the goons colder! FROSTBYTE freezes enemies into darling ice statues — then SHATTER them for a fountain of bolts! Chores have never paid so well!"

### 8.12 ROOT CANAL (slot 12)

- **Role:** area denial.
- **Unlock:** Blartz's stock after the Verdant Sink core, **300 bolts** (trade-in 180).
- **Original stats:**
  - 0.7 s interval. A seed at 22 m/s.
  - On impact a snapping bio-plant sprouts for 6 s. It roots the nearest non-armoured enemy within 3.2 m and chews 8 damage every 0.5 s.
  - Up to 3 plants; the oldest dies when a 4th is planted.
  - At Damage tier 3, plants spit spore globs at other enemies within 12 m every 1.5–2.5 s (6 damage, splash 1.5).
  - Ammo 8 (+3 per tier).

**Remake baseline.**

| Stat | Value |
|---|---|
| Plant | 6 s life, roots within 3.2 m, 8 damage every 0.5 s |
| Max gardens | 3 |
| Interval | 0.7 s |
| Ammo | 8 (+3 per tier) |

- **Primary:** plant a seed that sprouts a snapping biter, rooting enemies.
- **Alt-fire — UPROOT & REPLANT:** aim at a spot and press alt. Your oldest garden burrows underground to it (12 m/s) and keeps its remaining life +2 s. Free, 2 s cooldown.
- **Status identity:** **ROOTED.**
- **Combos:** Weed Whacker (rooted targets can't dodge Lawn Darts). Slowed targets are rooted twice as fast. Plants deny Lien Crawler burrow lanes (a crawler surfacing under a plant is rooted and stunned).

| Level | Behaviour |
|---|---|
| V1 | As above |
| V3 | Plants spit spore globs: 6 damage, splash 1.5, every 1.5–2.5 s, range 12 m (was Damage tier 3) |
| V5 | Plant life 6 → 9 s, root radius 3.2 → 4 m |
| **Ω ORTHODONTIST** | Five gardens at once, chewing 40% faster (bite interval 0.5 → 0.3 s) (`OMEGA_DESC[11]`). Upgrade over the original: the gardens link with vine tripwires when within 8 m of each other, and the vines root anything that crosses them for 1 s. |

**Signature Mods.**
- **A — Braces:** rooted targets also take +20% damage from all sources.
- **B — Wisdom Teeth:** each plant roots up to 2 targets, at half bite damage each.

**Model by level:** V2 a terracotta pot magazine · V3 a watering-can muzzle · V4 a seed hopper · V5 a little garden gnome sight · Ω a gold dental mirror on the barrel and braces on every biter.

**Brand pitch** (`ad_root`, kept):
- `cs.ad_root.01` (blartz): "Gardening for the WHOLE family! Plant a ROOT CANAL seed and watch a snapping bio-pal sprout to root your enemies in place! Up to three gardens of pain! Water twice weekly!"

---

## 9. The arsenal — new guns (13–16)

New guns follow the same structure. Their ad vignettes are new, with line IDs `bs.ad.<weapon>.<nn>`. They play on first equip, like the originals (`playWeaponAd`), and appear in the Gallery under AD.

### 9.1 LATE FEE (slot 13) — new, Rustvane Canyon

- **Role:** close-range shotgun.
- **Unlock:** Blartz's stock on first landing at Rustvane Canyon, **280 bolts** (trade-in 168, which is 60% like every original).

**Baseline.**

| Stat | Value |
|---|---|
| Pellets | 8 × 7 damage (56 total) in a 9° cone |
| Falloff | Full damage to 4 m, down to 50% at 12 m, nothing past 16 m |
| Interval | 0.85 s |
| Interest | +12.5% damage per second you **don't** fire this gun, up to **×2.0** (8 s). The HUD shows a % ticker: "LATE FEE +62%". Firing resets it. |
| Ammo | 10 (+4 per tier) |

- **Primary:** a spread blast whose damage accrues interest while you wait.
- **Alt-fire — COLLECTIONS:** a short-range pull-shot (9 m).
  - It yanks one non-heavy enemy to 2 m in front of Bolt for 10 damage, and the enemy arrives **stunned 0.6 s**.
  - Heavies are staggered for 0.5 s instead. Bosses and rooted targets can't be pulled.
  - 1 ammo, 3 s cooldown. Collections does **not** reset interest.
- **Status identity:** **SLOWED.** A blast at ×1.75 interest or more garnishes the targets: −40% speed for 3 s.
- **Combos:** Collections Agency (pull into the mallet string). Pellets pierce one clumped enemy, so it's devastating into a Grav clump. Pairs with the Blaster: spray with the Blaster while Late Fee accrues, then swap and cash out.

| Level | Behaviour |
|---|---|
| V1 | As above |
| V3 | Interest keeps accruing while the gun is holstered |
| V5 | Max interest ×2.5; a full-interest blast staggers non-boss heavies for 0.8 s |
| **Ω COMPOUND INTEREST** | Kills refund half your accrued interest. If a ×2.0 blast kills, the gun goes straight back to ×1.5. Pellets go to 10. |

**Signature Mods.**
- **A — Penalty APR:** interest accrues 2× faster (+25% per second) but caps at ×1.6.
- **B — Grace Period:** after 3 s idle, the next shot is a single slug instead of a spread: 80 × interest damage, pierce 2, accurate to 30 m.

**Model by level:** V2 a brass coin-slot on the stock · V3 a paper-tape interest ticker · V4 a second barrel shaped like a piggy bank's snout · V5 a red "PAST DUE" stamp on the pump · Ω a gold abacus pump-grip and an "APR: YES" engraving.

**Brand pitch — new ad vignette `bs.ad.latefee` ("Ad: Late Fee").** FX: a cash-register *ka-ching* and a red flash.

| ID | Speaker | Line |
|---|---|---|
| `bs.ad.latefee.01` | blartz | Book club running LATE? Neighbour still hasn't returned your casserole dish? Introducing the LATE FEE! |
| `bs.ad.latefee.02` | blartz | The longer you DON'T pull the trigger, the more it hurts when you DO. That's not a weapon. That's a financial instrument! |
| `bs.ad.latefee.03` | sprocket | So it rewards you for not shooting. You're selling us patience. |
| `bs.ad.latefee.04` | blartz | I'm selling you INTEREST. Patience is free, and I don't stock free things. |
| `bs.ad.latefee.05` | blartz | And if they run? COLLECTIONS. One little tug and they're back in your life, where they belong. |
| `bs.ad.latefee.06` | pa | Late Fee™ interest compounds per second. Rates may change without notice. Notice may change without rates. Past-due accounts will be pursued across state lines, star systems and the afterlife. |

### 9.2 THE FINE PRINT (slot 14) — new, Nova Plaza

- **Role:** marksman.
- **Unlock:** Blartz's stock on first landing at Nova Plaza, **300 bolts** (trade-in 180).

**Baseline.**

| Stat | Value |
|---|---|
| Damage | 42 per shot (crit ×2.5; on a marked weak point ×3.0) |
| Delivery | Hitscan, scoped (2.5× zoom), effective to 70 m |
| Interval | 0.9 s (bolt-action) |
| Mark | Every hit **MARKS** the target for 6 s (§4) |
| Read Carefully meter | 3 s, refills at 0.5 s per second after a 1.5 s delay |
| Ammo | 8 (+3 per tier) |

- **Primary:** a scoped rifle firing tiny bullets of tiny text. Hits reveal and mark weak points for 6 s.
- **Alt-fire — READ CAREFULLY:** while scoped, hold alt to slow time to 50% for as long as the meter lasts. Bolt still moves at full speed.
- **Status identity:** **MARKED.**
  - It reveals cloaked Gloomstalkers and outs disguised Return Desk Mimics.
  - It shows boss weak points through walls.
- **Combos:** Read The Room (the Lawn Dart locks and bullseyes marked spots). Super Sprocket targets only marked weak points while any exist. The Blaster's Hot Round crits a marked spot. Frozen statues can be crit anywhere.

| Level | Behaviour |
|---|---|
| V1 | As above |
| V3 | Rounds pierce one non-heavy enemy (both get marked) |
| V5 | Marked weak points also glow through walls for Sprocket; during Super, Sprocket's shots on marked spots count as weak-point hits for the boss BREAK meter |
| **Ω TERMS APPLY** | Marked enemies take +25% from everyone. A marked weak point **explodes when broken** (60 damage, r4): this covers breakable spots like a Tinker Turret's coil, a Middle Manager's mug, Repo-Tron's crane hook and Greeter Prime's sign generators, and also a boss BREAK while the core is marked. |

**Signature Mods.**
- **A — Footnote:** each mark also spreads to the nearest enemy within 6 m.
- **B — Asterisk:** a kill on a marked target refunds 1 ammo and 1 s of Read Carefully.

**Model by level:** V2 a magnifying-glass scope cap · V3 a line of microtext engraved along the barrel (readable in Photo Mode; it's this gun's own terms of service) · V4 a reading-lamp underbarrel · V5 a quill-shaped bolt handle · Ω gold-leaf microtext and an asterisk-shaped muzzle brake.

**Brand pitch — new ad vignette `bs.ad.fineprint` ("Ad: The Fine Print").** FX: a soft page-turn and a lens flare.

| ID | Speaker | Line |
|---|---|---|
| `bs.ad.fineprint.01` | blartz | Signing a lease at the family reunion? Don't sign ANYTHING until you've read... THE FINE PRINT! |
| `bs.ad.fineprint.02` | blartz | Every bullet is a tiny paragraph of tiny text. It finds the weak point, it highlights the weak point, and then everybody else gets to read it too! |
| `bs.ad.fineprint.03` | sprocket | A gun that makes people read the terms. That's the cruellest thing you've ever built. |
| `bs.ad.fineprint.04` | blartz | And with READ CAREFULLY, time slows down so you can really take it all in. Nobody has ever done that. Not once. In history. |
| `bs.ad.fineprint.05` | pa | The Fine Print™ is subject to the following terms: [THE NEXT FOUR SECONDS OF THIS ANNOUNCEMENT ARE PLAYED AT SIX TIMES SPEED] |
| `bs.ad.fineprint.06` | sprocket | ...Did anyone catch that? |
| `bs.ad.fineprint.07` | blartz | Nobody ever does. That's the beauty of it. |

### 9.3 HOSTILE TAKEOVER (slot 15) — new, Verdant Sink

- **Role:** conversion.
- **Unlock:** Blartz's stock on first landing at Verdant Sink, **340 bolts** (trade-in 204).

**Baseline.**

| Stat | Value |
|---|---|
| Acquisition beam | Hold on a non-boss enemy for 0.6 s + 0.01 s per point of its max HP (a Scrap Mutt takes 0.9 s; a Lifeguard Bot 1.45 s). Elites take ×1.5, heavies ×2. The beam deals 4 damage per second. |
| Contract | The target becomes an allied **subsidiary** for **10 s**: it keeps its own attacks, wears a gold tie, and enemies within 15 m target it |
| Max subsidiaries | 2 |
| Interval | 1.0 s after each acquisition |
| Ammo (contracts) | 6 (+2 per tier) |
| On contract end | The unit becomes an enemy again at its current HP, stunned for 1 s ("restructuring") |

- **Primary:** a beam that "acquires" a non-boss enemy as a temporary ally (subsidiary) for 10 s.
- **Alt-fire — MERGER:** aim at one subsidiary while another is within 8 m.
  - They fuse into one bigger ally: combined HP ×1.25, damage ×1.5, size ×1.3, and the contract resets to 10 s. 1 contract.
  - A merged unit can't merge again.
- **Status identity:** **ACQUIRED.**
- **Combos:** Hostile Work Environment (a SERVED subsidiary deals +40% damage and gains +4 s; Cease & Desist shots can hit your own subsidiaries for this). Subsidiaries relay Zap arcs. An acquired Middle Manager gives *your* subsidiaries performance reviews.
- **Refusals:** Picket Corn refuse ("We don't cross picket lines."). Statues refuse ("I am a statue."). Bosses show "ACQUISITION BLOCKED — ANTITRUST."

| Level | Behaviour |
|---|---|
| V1 | As above |
| V3 | Subsidiaries get +20% max HP and a gold tie that's visible from across the map |
| V5 | Acquisition time −30%, and contracts last 12 s |
| **Ω GOLDEN PARACHUTE** | When a contract ends, the acquired unit explodes into bolts: 50 damage at r4 to enemies, plus bolts equal to its normal drop. It doesn't come back as an enemy. |

**Signature Mods.**
- **A — Hostile Bid:** acquisition time halved, but contracts last 6 s.
- **B — Non-Compete Clause:** any enemy that damages your subsidiary is automatically SERVED.

**Model by level:** V2 a briefcase-shaped emitter · V3 a gold-tie antenna · V4 a pen-shaped targeting laser · V5 a stock ticker scrolling along the side · Ω a gold briefcase and a tiny parachute that pops out when you holster.

**Brand pitch — new ad vignette `bs.ad.hostile` ("Ad: Hostile Takeover").** FX: a boardroom gavel and a stock-ticker chime.

| ID | Speaker | Line |
|---|---|---|
| `bs.ad.hostile.01` | blartz | Is the neighbour's lemonade stand doing better than yours? Don't compete — ACQUIRE! |
| `bs.ad.hostile.02` | blartz | HOSTILE TAKEOVER! One beam, one signature, and that goon who was trying to kill you is now a valued member of YOUR team! |
| `bs.ad.hostile.03` | bolt | For how long? |
| `bs.ad.hostile.04` | blartz | Ten seconds! Which is longer than most corporate mergers, and FAR more honest. |
| `bs.ad.hostile.05` | sprocket | And when the ten seconds are up? |
| `bs.ad.hostile.06` | blartz | Then they're LET GO. It's nothing personal. It's restructuring. |
| `bs.ad.hostile.07` | pa | Hostile Takeover™ does not work on bosses, unions, or anyone with a good lawyer. Subsidiaries are not entitled to benefits, severance, or an explanation. |

### 9.4 CLEARANCE RACK (slot 16) — new, Grand Galleria

- **Role:** sustained DPS.
- **Unlock:** Blartz's stock on first landing at the Grand Galleria, **360 bolts** (trade-in 216).

**Baseline.**

| Stat | Value |
|---|---|
| Damage | 5 per price-tag round |
| Spin-up | 0.6 s (holding alt spins the barrels without firing) |
| Rate | One round every 0.06 s once spun (about 83 damage per second) |
| Spread | 3°, rising to 5° after 2 s of continuous fire |
| Markdown | Each hit adds 1 **MARKED DOWN** stack (§4); max 10 |
| Ammo | 150 (+50 per tier) |

- **Primary:** a spin-up minigun firing price-tag rounds. Each hit marks down armour.
- **Alt-fire — DOORBUSTER:** after at least 1 s of spin-up, alt releases a burst.
  - A 6 m, 60° cone for 25 damage and knockback 10, applying 3 stacks.
  - 15 ammo, 4 s cooldown.
  - Movement while spun up is −30% (the barrels are heavy).
- **Status identity:** **MARKED DOWN.**
- **Combos:** Markdown Smash (at 5+ stacks, a mallet hit strips a plate in one hit with full damage). Buzzkill pops plates twice as fast on marked-down targets. On bosses, markdown raises the 45% non-weak-point damage, which helps every other gun.

| Level | Behaviour |
|---|---|
| V1 | As above |
| V3 | The barrels stay spun for 1.5 s after you release |
| V5 | Every 25th round is a "50% OFF" round: ×3 damage and 3 stacks |
| **Ω EVERYTHING MUST GO** | No spin-up. Stack cap 20. At 20 stacks, armour reaches 0%: every plate falls off, and a boss takes full damage outside its weak point for 4 s (then the stacks reset). |

**Signature Mods.**
- **A — Final Sale:** slower fire (0.09 s), but each hit adds 2 stacks.
- **B — Buy One Get One:** every 2nd hit fires a free ricochet tag at a second target within 8 m.

**Model by level:** V2 a tag-gun trigger guard · V3 a rotating SALE placard · V4 coat-hanger barrel shrouds · V5 a flashing "CLEARANCE" light bar · Ω gold barrels and a "FINAL FINAL FINAL SALE" banner that unrolls when it spins up.

**Brand pitch — new ad vignette `bs.ad.clearance` ("Ad: Clearance Rack").** FX: a mall chime and an air-horn.

| ID | Speaker | Line |
|---|---|---|
| `bs.ad.clearance.01` | glambot | Darlings, it's the garage sale of the CENTURY and EVERYTHING must go! |
| `bs.ad.clearance.02` | blartz | Introducing the CLEARANCE RACK! Six spinning barrels of price-tag rounds. Every tag marks down your enemy's armour. Ten percent! Twenty! FIFTY PERCENT OFF! |
| `bs.ad.clearance.03` | sprocket | What happens at a hundred percent off? |
| `bs.ad.clearance.04` | blartz | Nobody knows! No customer has ever survived long enough to check out! |
| `bs.ad.clearance.05` | blartz | And for the early birds: the DOORBUSTER. Clears a path to the deals. And through the people standing near the deals. |
| `bs.ad.clearance.06` | pa | All sales final. No returns, exchanges, or survivors. Clearance Rack™ is not responsible for trampling, stampedes, or what happens on Black Friday. Price-tag rounds may not be combined with other offers. |

GLAMBOT appears in this vignette because the Clearance Rack unlocks at the Grand Galleria, long after GLAMBOT's defection on Rustvane, and the Galleria is his kind of venue.

---

## 10. Gadget slot — K.A.R.E.N.

- **Unlock:** Blartz's stock, **2,500 bolts**.
  - It's available after the campaign ending (post-game) and in NG+. The original was NG+ only.
  - It sits in the shop's GEAR tab.
- **Slot:** Gadget (K / D-pad Down). It doesn't take a wheel slot.
- **Original behaviour** (`fireKaren`, `karenSweep`, `updateDoodads` L9076):
  1. 45 s cooldown ("composing a complaint").
  2. She scans everything within 20 m and paints red lock-on lines ("🎯 LOCKED").
  3. 0.55 s later, a 10-ray grievance sweep fires. Each enemy shows "I DEMAND A MANAGER", then explodes after 0.3–1.1 s for **500 damage**.
  4. Armoured bosses take 120 damage instead.

**Remake: a summon.** She materialises at Bolt's shoulder: a hovering retail-enforcement drone with a lanyard, a clipboard and a speaker grille that's always mid-sigh.

| Stat | Value |
|---|---|
| Cooldown | 45 s (kept) |
| Scan radius | 20 m (kept) |
| Lock delay | 0.55 s (kept) |
| Damage | 500 per non-boss victim after 0.3–1.1 s (kept); 120 to bosses, plus 10% of the boss's max HP added to its BREAK meter (new) |
| Exclusions | Picket Corn are never targeted ("Unionized. Not my department."). Subsidiaries are spared. |
| Barks | Each summon plays one of her lines (`bs.karen.summon.<nn>`) |

**Brand pitch** (`ad_karen`, kept):
- `cs.ad_karen.01` (glambot): "Introducing K DOT A DOT R DOT E DOT N — the Kinetic Automated Retail Enforcement Nanny! She sees a violation and she HANDLES it!"
- `cs.ad_karen.02` (pa): "K.A.R.E.N. is not a manager and cannot be spoken to. Do not attempt to speak to K.A.R.E.N."
- `cs.ad_karen.03` (pa): "Side effects may include: kinetic enforcement, unsolicited feedback, retail-grade trauma, and a strongly-worded aura. Not valid where illegal, moral, or in good taste. Batteries, dignity, and consent not included."
- `cs.ad_karen.04` (sprocket): "I did not follow a single word of that and I want twelve."

**Summon barks (new):**

| ID | Line |
|---|---|
| `bs.karen.summon.01` | "Scanning for policy violations. Oh, there are SO many." |
| `bs.karen.summon.02` | "I'm going to need everyone to step away from the hostility." |
| `bs.karen.summon.03` | "Escalating. Escalating. ESCALATED." |
| `bs.karen.summon.04` | "No, I will not lower my voice. My voice IS the policy." |
| `bs.karen.summon.05` | "This has been documented. All of you have been documented." |

---

## 11. Weapon barks (new lines)

| ID | Speaker | Line | Trigger |
|---|---|---|---|
| `bs.weapon.levelup.01` | sprocket | "Your gun leveled up. It's growing. I'm not crying, you're crying." | Any V-level |
| `bs.weapon.levelup.02` | sprocket | "V3! It's learned a trick. I'd say it was me who taught it, but it wasn't." | V3 |
| `bs.weapon.levelup.03` | sprocket | "V5. That thing has seen more combat than most generals. Blartz will want to touch it." | V5 |
| `bs.weapon.levelup.04` | sprocket | "Level up. The weapon is improving. The wielder remains a work in progress." | Any V-level |
| `bs.weapon.zap.amp.01` | sprocket | "Oh, so I'm a PYLON now. Great. Really living the dream." | Amplify start |
| `bs.weapon.zap.amp.02` | sprocket | "Standing still in a firefight. This is a choice. This is YOUR choice." | Amplify held 3 s |
| `bs.weapon.zap.amp.03` | sprocket | "My capacitors are filing a grievance. With me. About you." | Amplify held 3 s |
| `bs.weapon.zap.amp.04` | sprocket | "Fine! FINE! UNLIMITED POWER! Or, you know, about twelve volts more than usual." | Amplify, 3+ targets hit |
| `bs.weapon.zap.amp.05` | sprocket | "Can I move now? I'm moving. I'm moving now." | Amplify end |
| `bs.weapon.middleman.argue.01` | middleman_a | "I'll take the big one." / middleman_b: "You took the big one LAST time." | Ω deploy |
| `bs.weapon.middleman.argue.02` | middleman_b | "Per my last ping, that kill was mine." | Ω, a kill |
| `bs.weapon.middleman.argue.03` | middleman_a | "Let's circle back on who's aiming where." | Ω, idle |
| `bs.weapon.middleman.argue.04` | middleman_b | "I'm escalating this to the guy holding the gun." | Ω, 10 s in |
| `bs.weapon.middleman.argue.05` | middleman_a | "Great teamwork, everyone. Mostly me." | Ω, contract end |
| `bs.weapon.middleman.argue.06` | sprocket | "They're arguing about KPIs mid-gunfight. I've never felt more at home." | Ω, first time |
| `bs.weapon.hostile.refuse.01` | corn | "We don't cross picket lines." | Picket Corn targeted |
| `bs.weapon.hostile.refuse.02` | pa | "ACQUISITION BLOCKED — ANTITRUST." | Boss targeted |
| `bs.weapon.hostile.refuse.03` | statue | "I am a statue." | Statue targeted |

The two Middleman drones use new speaker ids `middleman_a` and `middleman_b`: a clipped radio voice, two pitches. A `statue` speaker id is also new. Register all three in `speakers.json`.

---

## 12. Mallets (§4.1 / §5.3)

The mallet track is separate from gun progression. Mallets have no XP and no Omega. Mallet seams stay cosmetic (`MSKINS`).

**Base strings** (`CONFIG.melee`, kept 1:1 for parity):

| Attack | Damage |
|---|---|
| Ground 1 / 2 / 3 | 24 / 28 / 55 (the finisher stuns 0.8 s) |
| Air 1 / 2 | 26 / 36 |
| Launcher | 22 (launch 11, pop-jump 7.5) |
| Dash-stab | 38 |
| Punch | 8 |
| Throw | 18 (24 m/s, 1.2 s cooldown) |
| Slam | 30 (r4.2); Super Slam 62 (r6.8) |

Tier scaling is `malletDmg = base × (1 + 0.35 × tier)`, and the slam radius and damage scale ×(1 + 0.15 × tier).

The remake's improvements apply to every mallet (brief §4.1):
- An air combo of 2 hits plus a **spike** (32).
- A **charged ground pound** (hold 0.6 s: 70, r5.5).
- The throw becomes a **boomerang** that hits switches and collects bolts on the way back.
- Combo-meter tiers pay bonus bolts.

| Mallet | Unlock / price | Tier multiplier | Identity (original) | Remake addition | Combos |
|---|---|---|---|---|---|
| **Scrap Mallet** | Start | ×1.0 | The baseline | — | SHATTER on frozen, crits on dancers, GRAV BONUS slam, plate strip |
| **Magma Mallet** | Blartz, **220 bolts** | ×1.35 | Finishers and slams leave burning patches (finisher r1.8 for 3 s, slam r = 0.45 × slam radius for 3.2 s; 4 damage every 0.4 s) | Finisher hits apply **BURNING** 3 s | Late Fee Collections + finisher = an instant burn; burning plus Due Process don't stack (the highest burn wins) |
| **Thunder Mallet** | Blartz, **450 bolts** | ×1.7 | Non-finisher hits arc 12 to the nearest enemy within 7 m; finisher AoE hits arc 14; wider finisher shockwave | Every hit applies **CONDUCTIVE** 4 s | Sprocket Zap chains extend through conductive targets; Middleman relays |
| **Riot Mallet** (new, post-game) | Earned in **Loop Riot**: win the **Unrecalled** league final | ×1.7 | — | **Juggles.** Every ground-string hit pops non-heavy enemies 3 m up (launch 8). The air string gains a 3rd hit. The spike drives juggled enemies into the ground for a 20-damage bounce shockwave (r3). Grind-rail throws: a thrown Riot Mallet rides rails. | B.O.O.M. Box (Ω HEADLINER launches into a Riot juggle); Grav collapse → Riot spike |

**Switching.** Magma and Thunder upgrade the single mallet in sequence (as in the original). The Riot Mallet is a *sidegrade* to Thunder: once you own it, you choose Thunder or Riot at any Blartz kiosk (free), or on the mallet slot at the centre of the weapon wheel.

**Mallet shop text** is kept verbatim from `shopStock`, including "Legally distinct from any mythological hammer." and "Maximum mallet achieved. OSHA has stopped returning Blartz's calls."

New Riot Mallet shop/pickup text (`bs.loopriot.mallet.desc`): "RIOT MALLET — won, not sold. It launches whatever it hits and does not apologize. Dent says it was 'a deck once.' Nobody asked."

---

## 13. Final unlock and price table

The planet order follows `CAMPAIGN = [0,1,5,6,7,9,2]`: Scrapheap → Rustvane → (Nova / Glacius / Verdant, any order) → Grand Galleria → Core Foundry. "Landing" means first arrival on that planet. Trade-in is 60% of price, as in the original.

| Slot | Weapon | Unlock condition | Price | Trade-in | Source of price |
|---|---|---|---|---|---|
| 1 | Omni-Blaster | Start | — | 0 | Original |
| 2 | Void Ripper | Start | — | 0 | Original |
| 3 | Sprocket Zap | Start | — | 0 | Original |
| 4 | B.O.O.M. Box | Blartz stock from the start | 150 | 90 | Original |
| 8 | Buzzkill | Blartz stock from the start | 160 | 96 | Original |
| 5 | Lawn Dart | Blartz stock from the start | 250 | 150 | Original |
| 9 | Grav Grenade | Scrapheap cleared (Repo-Tron down) | 240 | 144 | Original |
| 13 | **Late Fee** | Rustvane landing | 280 | 168 | New, tuned |
| 7 | Cease & Desist | First Keystone Core collected | 300 | 180 | Original |
| 14 | **The Fine Print** | Nova Plaza landing | 300 | 180 | New, tuned |
| 10 | The Middleman | Nova Plaza core | 320 | 192 | Original |
| 11 | Frostbyte | Glacius Vault core | 320 | 192 | Original |
| 12 | Root Canal | Verdant Sink core | 300 | 180 | Original |
| 15 | **Hostile Takeover** | Verdant Sink landing | 340 | 204 | New, tuned |
| 16 | **Clearance Rack** | Grand Galleria landing | 360 | 216 | New, tuned |
| 6 | Patent Pending | Blartz rescue gift (Core Foundry) | Free | 180 | Original |
| Gadget | K.A.R.E.N. | Post-game (after the ending) or NG+ | 2,500 | — | Original price |
| Mallet | Magma Mallet | Blartz stock | 220 | — | Original |
| Mallet | Thunder Mallet | Blartz stock, after Magma | 450 | — | Original |
| Mallet | Riot Mallet | Loop Riot: win the Unrecalled league | Earned | — | New |

**Other shop items** (unchanged from `shopStock`):
- Ammo Grab-Bag: 30.
- Nanotech Boost (+20 HP): 100 + 60 per boost already bought.
- SUPER SPROCKET PROTOCOL: 900.
- Cosmetics: per `PAINTS` / `HATS` / `MSKINS`.

**Blartz progression costs:**
- Mods: 840 per gun.
- Signature Mod: 200 per gun.
- Omega Forge: 2,000 per gun (after `blartzRescue`).

**Firing Range** (brief §8): every owned gun can be trialled. Range scores pay bolts as in the original. The range shows a live combo card (§5) and a dummy for each status.

---

## 14. Source discrepancies and decisions in this doc

| Topic | Source says | This doc does |
|---|---|---|
| Zap target count | The ad (`cs.ad_zap.01`) says "up to six"; the code chains to 3 (Ω 5) | V1 3, V3 4, V5 5, Ω 5. Ω + Amplify reaches 6, so the ad line stays true without a change |
| Zap name | The ad says "ZAPINATOR"; `WEAPONS` says "SPROCKET ZAP" | The HUD keeps SPROCKET ZAP; ZAPINATOR is Blartz's failed trademark (a running joke) |
| Middleman aggro | The shop text promises "draws enemy aggro"; the code never redirects enemies | The remake implements real aggro (§8.10) |
| Grav Grenade damage | `W_BASE_DMG[8] = 30`, but the projectile deals 0 | 0 direct; the 30 was only a shop stat-bar value |
| Blaster Omega | Needed only 2 tracks (no ammo track) | The Heat Sink slot means all 16 guns need 3 |
| K.A.R.E.N. acronym | The ad: "Kinetic Automated Retail Enforcement Nanny"; the shop description: "Kinetic Annihilation & Retribution Emitter Node" | The ad version (also the brief's) is canon. The shop line becomes a Blartz joke: see the report's line-change list |
| Damage-tier behaviours | Maxing the Damage track unlocked behaviours | Moved to V-levels; mods are stat-only |
| Omni-Blaster name | `WEAPONS[0]` = "BLASTER"; the ad = "OMNI-BLASTER" | OMNI-BLASTER (the brief's name) |
