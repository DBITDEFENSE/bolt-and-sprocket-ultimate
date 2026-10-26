# GRAVELIGHT: The Machines on the Walls (perk upgrades, cabinets, the Crucible, the chalk)

Update 04, DECISIONS T-075. This file is the **source** for two things:

1. the design of the **perk upgrades** (tiers II and III for every Helvetia tonic; data in `data/gravelight/perks.json`
   `"tiers"` and `"upgrades"`), and why, in the world, a cabinet can pour a stronger measure;
2. the **in-world reasons** the perk machines, the Crucible and the wall guns are where they are on every built map.
   The per-map sections (§4–§6) are parsed by `tools/build_perk_lore.py` into `data/gravelight/machine_lore.json`,
   which the game reads (maker's plates, the Crucible's brass plate, the chalk lines under a wall gun's prompt, and the
   Intel Archive).

Canon sources: `docs/CANON.md`, `docs/gravelight/LORE.md` (§2 Nachtglas, §4.2 the Crucible, §7 the Ledger, §8 Helvetia,
§13 the Archive), `docs/JINGLES.md` (each cabinet's plan, formula, human, jingle and fine-print panel: **not repeated
here**), `docs/FINEPRINT_LORE.md`. Writer rules from LORE.md §2.4 hold: no Gravelight character learns the word
"subscription", or that Nachtglas is anyone's product. The plates and Archive entries below are in-world objects and
documents; the truth reaches the player only sideways (a "V." note, a stencil, a turn of phrase).

---

## 1. Perk upgrades: design

### 1.1 The loop

- **In the match (the main path).** Walk up to a machine whose tonic you already carry and hold Use: *"Hold [F] to brew
  Ironhide Stout II [3500]"*. Same drink beat, same jingle. Tier II from **round 8**, tier III from **round 15**
  (`upgrades.min_round`), **power on** for every tier (Second Wind's solo standby cell pours the free trial only).
  Tier III needs tier II. No extra cap slot: tiers never use one (the cap is **6** since T-081, 4 under Classic Rules); upgrading is how late
  Scrip turns into power once the slots are full.
- **Across matches (the gate).** Each tier is unlocked once, for the whole profile, by **mastery** with that tonic:
  **1 point per kill** made with it in your system, **20 per round** you finish holding it (`upgrades.mastery`).
  **Tier II at 250, tier III at 1,200.** A first careful game with Ironhide from round 4 to 15 earns about 500 (tier II
  opens mid-match, and can be bought the same match); tier III takes two or three long games with the same tonic. The
  machine prompt shows the count when a tier is still locked (*"Ironhide Stout II · mastery 120 / 250"*) and the pause
  menu's LOADOUT tab lists every carried tonic with its tier and the points to the next.
- **Why the meta path is the gate and not the main path:** buying power in the match is what round-based zombies is
  about (the Crucible works the same way), and a permanent stat bonus would flatten the rounds curve for veterans.
  Mastery only opens the door; every match still starts at tier I and the upgrades cost the same. It rewards loyalty to
  a tonic, which is also exactly what the cabinets were built to do (§1.3).
- **Losing them.** A tier lives in the tonic: lose the perk (a down in co-op, or solo without Second Wind) and the
  tier goes with it. Solo Second Wind's self-revive uses the tonic up but the cabinet remembers you: buy it again and
  it comes back at the tier you had. A bot's bonus perk keeps its tier through a down, like the perk itself.
- **Carry.** Tiers carry with their perks through the campaign exfil (`Campaign` carry `"perk_tiers"`) and are in the
  co-op state snapshot. **Co-op gate:** the host's profile decides what is unlocked for the whole squad (the snapshot
  sends it to the clients so their prompts agree).
- **HUD:** the bottle cap gets a tier mark (II / III in Roman numerals on a brass band under the tonic's glyph, and
  the crimp turns gold at III), and the cap pops whenever one of its tier effects fires.
- **Bots** buy tiers too (`data/gravelight/ai/economy.json` `"perk_upgrades"`): only once their perk plan has nothing
  left to buy (cap full, or everything on the plan drunk), from round 10, in their plan's order, never dipping under
  the usual reserve (one revive-critical rebuy plus an ammo box), and not while a gun upgrade at the Crucible would be
  the better buy. They are gated by the host's profile like everybody else.

### 1.1a The base measures (T-082)

The user's call after Update 03 ("the perks in general need just a slight buff"): every tonic's first pour is about
**10–15% stronger** than it was, and tiers II / III moved with it so the ladder keeps its proportions. The pause menu's
LOADOUT tab lists all nine with these one-line descriptions (`perks.json "desc"`), held or not.

| Tonic | Base measure now | Was |
|---|---|---|
| **Ironhide Stout** | **275 health**: a zombie's swipe is 50, so you stand **six hits** (the sixth downs you) | 250 (five hits) |
| **Second Wind Schnapps** | revives **×2.3**; three solo self-revives | ×2.0 |
| **Trigger Tonic** | reload **×0.45** | ×0.5 |
| **Twin Barrel Bitters** | fire rate **×1.5** | ×1.33 |
| **Marathon Malt** | unlimited sprint; move **×1.10** | ×1.07 |
| **Hawkeye Brandy** | sway ×0.45, sights up in ×0.7 of the time, headshots **×1.4** | 0.5 / 0.75 / 1.25 |
| **Packmule Porter** | a third gun **and one more grenade** carried (the slot was the perk; the grenade is the buff) | 3 slots only |
| **Blastproof Bock** | self-explosive and fall immunity; slide shockwave **450** in **3.3 m** | 400 in 3.0 m |
| **Overclock Cordial** | burst radius **2.5 + 4.0 e** m (6.5 m empty), damage **0.66 × health(r) × e**, bosses **1700 e**, **12** targets | 3.5 e / 0.6 / 1500 / 10 |

### 1.2 The tier table

Tier II and III effects **merge over** the tonic's own (`effects`), so a key the tier sets replaces the base value.
Costs are the same solo and co-op.

| Tonic | Tier II (cost) | Tier III (cost) |
|---|---|---|
| **Ironhide Stout** | **Riveted Hoops** (3500): 330 health (seven hits, not six); health regeneration starts 40% sooner. | **Sunday Best** (7000): a hit that leaves you under 30% health turns your skin to iron for **2 s** (no damage at all); once per 40 s. |
| **Second Wind Schnapps** | **Breathe Again** (2500): revives ×2.9 (was ×2.3); whoever you get up, or you after a solo self-revive, runs **30% faster for 5 s**. | **The Nurse's Count** (5000): the revived are untouchable for **3 s**, and getting up knocks every zombie within **4 m** off its feet. |
| **Trigger Tonic** | **Shift Quota** (4000): weapon swaps **40% faster**; reload ×0.4 (was ×0.45). | **Fresh Clip** (7500): for **2 s** after a reload completes, your shots deal **+30%** damage. |
| **Twin Barrel Bitters** | **The Major's Moustache** (3000): fire rate ×1.6 (was ×1.5); recoil **−30%**. | **Both Barrels** (6500): **one shot in four costs no round** (not wonder weapons). |
| **Marathon Malt** | **Running Home** (3000): move ×1.13; the gun comes up out of a sprint in **35%** of the time. | **Vreni's Step** (6000): sprinting, you **sidestep one swipe every 8 s** (no damage) and get a 1.5 s burst of +15% speed. |
| **Hawkeye Brandy** | **The Owl** (3000): a **headshot kill puts a round back** in the magazine. | **Sowa's Patience** (6500): an **aimed shot taken 1.2 s or more after your last** hits **×1.75**. |
| **Packmule Porter** | **Ammer's Ledger** (4500): **half price** ammo at the chalk and at ammo boxes; **a second extra grenade** carried. | **Training Load** (8500): at the start of every round, every gun you carry gets **20% of its reserve** back, plus a grenade. |
| **Blastproof Bock** | **Liability Waiver** (3000): **explosions that reach you heal you 25**; the slide shockwave hits for 675 (was 450). | **Demolition School** (6500): the slide shockwave **scales with the round** (at least 60% of a zombie's health that round), reaches 3.8 m and **knocks survivors down**. |
| **Overclock Cordial** | **Live Wire** (3500): burst cooldown **2 s** (was 3); **arcs jump to 3 more zombies** out to twice the radius, at half damage. | **Aftershock** (7000): a burst from a magazine **75%+ empty rings again 0.8 s later** at half strength. |
| **Fine Print Fernet** *(not in the game yet: Helvetia Works)* | **Second Reading** (2500): the despawn rings and the egg glint reach twice as far (80 m / 50 m). | **Read It Through** (5500): the holder's timed power-ups last 60 s, not 45. Added to `perks.json` when the Fernet cabinet ships. |

### 1.3 Balance notes

- **Zombie health** is 150 + 100/round to round 9, then ×1.1 a round (≈ 950 at r10, ≈ 3,700 at r25, ≈ 9,600 at r35).
  Flat-damage effects die off with it, so the tier III damage effects are **multipliers** (Fresh Clip ×1.3, Patience
  ×1.75) or **scale with the round** (Demolition School), and the defensive tiers are **time windows** (iron skin,
  revive invulnerability, dodge) that stay worth the same at round 40 as at round 15.
- **Prices** sit between a door and the Crucible's first teaching (5000; re-teaching 7500 / 10000). By round 15 a solo
  player earns roughly 3–4k Scrip a round, so tier II is a round's spending and tier III two; a full set of four
  tier-III tonics is about 28k on top of the base perks, which keeps late-game Scrip meaningful on Totenhafen (where the
  campaign arrives at round 31 with money and nothing left to buy).
- **The strongest tiers** are Sunday Best (it turns the fatal fifth/sixth hit into a 2 s window to get out, once per
  40 s) and Training Load (ammo economy); both are the most expensive of their kind. Both Barrels (25% free rounds) is
  roughly +33% sustained damage per magazine on top of Twin Barrel's rate, deliberately weaker than a Crucible teaching.
- **Co-op:** revive tiers (Second Wind) matter most with a squad; Breathe Again is priced to be the first upgrade a
  co-op player buys. Bots buy tiers only after their perk plan is done, so they never starve themselves of a base perk.

### 1.3a The caps (T-082)

Every place a tonic shows as a bottle cap (the HUD row, a bot's nameplate, the co-op squad ledger, the pause LOADOUT
list) draws it with `PerkCap.draw_cap` (`gravelight/ui/perk_cap.gd`): a crimped cap in the tonic's enamel colour with
a bevelled face, and on it the tonic's **glyph**, embossed (a shadow pass under cream on dark enamel, ink on light).
The glyphs are drawn, not painted, from convex pieces, so they read at 18 px on a plate and 54 px on the HUD, and
they follow the cabinets' art bible (`docs/gravelight/JINGLES.md`, the **Bottle cap** line of each tonic): **Ironhide**
Fassl's flexed arm inside a riveted ring; **Second Wind** a swallow with a thin red rim; **Trigger Tonic** Pauli's hare,
head in profile, motion lines behind; **Twin Barrel** two crossed barrels over the Major's moustache; **Marathon** a
winged boot with a chrome rim; **Hawkeye** a hawk's eye in a crosshair with ticks (the owl stays on the cabinet);
**Packmule** Ammer's mule with three rifle lines fanning behind it; **Blastproof** a ram's head over a black starburst;
**Overclock** the friend's robot, a copper lightning bolt and two round eyes, over a cog. One liberty against the
bible for readability: the silhouette is ink on the pale enamels (Second Wind, Trigger, Twin Barrel, Marathon) and
cream on the dark ones, whichever the bible said. The tier band (II / III) sits under the glyph; a tonic the player
does not hold is drawn greyed. A future cabinet (Fine Print Fernet) without a glyph case falls back to its two letters
until one is drawn.

### 1.4 Why a cabinet can pour a stronger measure (in-world)

Every Helvetia cabinet holds **three chambers**, not one. Abteilung III's formula cards list each tonic in three
*Fassungen* (versions): the field-trial dose the cabinet pours on any token, and two stronger measures that the trial
reports call *Stammgast-Ausschank*, "the regulars' measure". The coin plate will not release the second or third chamber
to a new drinker: a sensor behind the token slot reads the drinker's hand (the Ledger's tally line tells it how much of
that formula the hand has already taken in; the fine-print panels warn that "each enrolment deposits a small quantity
of active material in the Holder's tissue... It is not removed at all"). The more of a tonic you already carry, the
more the cabinet will pour. The facility called it a safety interlock. Vendelin, who designed it to his directive,
called it the **loyalty measure** in his own notes, and fitted it under protest: it is the only part of every cabinet
he could not dilute.

- **Mastery** is the cabinet reading what is already in you. **Tier unlocks are per tonic** because each chamber reads
  only its own formula.
- **The round threshold** is the Ledger: it will not release the regulars' measure on a tally it does not yet trust.
- Players-only: the Plan IDs have premium levels (`DMS-VP-DUR-01/II`, `/III`). Nobody in GRAVELIGHT reads them. The
  Operator calls the upgrade **"the loyalty measure"** on the PA and is delighted every time.

---

## 2. The perk machines: who made them, what is in them, why they are here

Who formulated each tonic, what is in it, the jingle, the human cost and the fine-print panel: `docs/JINGLES.md` §1–§10
and LORE.md §8.1. The short version, per cabinet (for the plates):

| Cabinet | Formula by | In the bottle |
|---|---|---|
| Ironhide Stout | Otto Kessler, brewmaster, Freising | roasted barley, smoked malt to hide the tin, molasses, spite; a few parts per million of night-glass |
| Second Wind Schnapps | Sister Agnieszka Wróbel, forced-labour nurse | juniper, honey, her own reduction; the revival compound, tuned to bring back the collapsed, not the dead |
| Trigger Tonic | Dr. Ilse Vogt, Kaltwerk Chemie | a fizzing citrus tonic with the shift quota worked into it |
| Twin Barrel Bitters | Maj. Anselm Brück, ordnance | gentian and orange bitters, chosen for other men "for morale" |
| Marathon Malt | Verena "Vreni" Gähwiler's family remedy (Grindelwald) | gentian, lady's mantle, honey, malt, cooked slowly: "the taste of running home" |
| Hawkeye Brandy | Abteilung I, from the trials on Halina "Sowa" Kurek | pear brandy from the Aschau estate over what they took from her |
| Packmule Porter | Fw. August "Gustl" Ammer, quartermaster | a heavy porter; the capacity formula, logged like a ration |
| Blastproof Bock | the Pionierschule's Kaltenbrunn detachment | a dark bock; Res smuggled a bottle of it to London |
| Overclock Cordial | nobody; a friend (a reading of a far-future robot) | a violet-teal cordial that crackles |

**Why the cabinets are where they are, in one paragraph:** Helvetia Automaten AG delivered twelve cabinets to the Amt
für Sonderforschung (contract extract `INT_M1_05`). Kaltenbrunn's stand where Abteilung III dosed people: the mess,
the chapel where laborers rested, the generator hall, the specimen room. Eight **replacement units** waited in the
Kreuzweg's cellar on the salt road from 9 October 1944 (`INT_M0_13`). In January 1945 the cabinets that could be moved
went north with Reinholt's crates to Totenhafen, because Helvetia was the forwarding agent and the stone's handlers
were to be dosed. The ninth cabinet, **Overclock Cordial**, is on no docket anywhere: it is simply there, with fresh
solder on it, on every map.

## 3. The Crucible and the chalk, in one paragraph each

**The Crucible (Mod. R-E).** A Nachtglas furnace that re-teaches a weapon (LORE.md §4.2). It came in a Helvetia crate
stencilled *Kühlanlage* (cooling plant) with its drawings already finished in German, and Fasbender signed them. There
were **three crates**, numbered on the stencil *1/3, 2/3, 3/3*: one to the Core Vault (March 1944), one that Res and
Vendelin carried through the installers' tunnel into the Kreuzweg's cellar in October 1944 and that appears on no
docket, and one that went north to the U-boat pens with Reinholt's ballast, consigned to the same buyer as the stone.
The brass plate on each reads `MOD. R-E · PAT. PEND. BLZ-40417`. Nobody in GRAVELIGHT knows what it means.
(Players-only: Darkmatter built the Mod. R-E from Blartz's confiscated Omega Forge schematics; BLZ-40417 is Blartz's
patent, LORE.md §4.2, CANON §119.)

**The chalk.** Every wall gun on every map hangs on a **token clamp** over a chalk outline of itself. That is
**Feldwebel Gustl Ammer's Standing Order 17** (the Packmule quartermaster): every weapon in the Kaltenbrunn district is
to hang on its outline, so a missing gun can be seen from the door, and is released from its clamp only against a
facility token, so the Ledger knows who signed for it. Helvetia made the clamps (Imhof & Cie built railway-station
luggage lockers before the war; the token lock is the same lock). The order followed the Amt's Scrip wherever it went:
the mine, the salt road, the harbour. Some of the guns on the clamps are not German. Those are the ones the
quartermasters found in sealed crates that were never shipped to them (LORE.md §2.1: the stone "moves things"), and Ammer
logged them, as he logged everything, as *Beutewaffe, Herkunft ungeklärt*: captured weapon, origin unexplained.

---

## 4. Map 0: Crossroads Inn (`map00_crossroads`)

<!-- Parsed by tools/build_perk_lore.py. Under a "## N. ... (`map_id`)" heading, each "### <key>" is one entry:
     **Plate:** one line shown under the prompt (and on the reader); **Archive:** the Archive title;
     the paragraphs after it are the text (the first paragraph is the reader's caption: what the object is).
     Keys: perk.<perk_id>, crucible, chalk (the map's chalk entry), chalk.<weapon_id> (only a Plate line). -->

**Archive map:** 0

### perk.ironhide_stout
**Plate:** Replacement unit 1 of 8 · Kessler recipe · held at the Kreuzweg, 9.X.44
**Archive:** Maker's Plate: Ironhide Stout (the Kreuzweg cellar)

A riveted brass plate at the foot of the iron-red barrel cabinet, the first in the west row. Under the maker's line, a paper delivery tag is still wired to the hoop.

HELVETIA AUTOMATEN AG · BASEL · SEIT 1921. Hygienic beverage dispenser, barrel pattern. Formula: O. Kessler. Replacement unit 1 of 8, for the barracks mess at Kaltenbrunn, Abt. III. To be held until called for.

This is the replacement for Kessler's own cabinet in the Kaltenbrunn mess, where the guards drank it before every shift: a stout made by a brewmaster who wanted it to taste like Sunday, over a few parts per million of night-glass that stop a man feeling the cold, and then the shrapnel. It was never called for. On the tag, in the landlord's pencil: "Rolled it off the lorry myself. Heavier than a full cask. It sloshes when nothing is in it. A.V."

### perk.second_wind
**Plate:** Cabinet 2 · please do not disconnect · V.
**Archive:** Maker's Plate: Second Wind (Cabinet 2)

The pale-blue apothecary cabinet beside the barrel. Behind the louvres, under the coin works, a small brass-cased battery glows on its own.

HELVETIA AUTOMATEN AG · BASEL. Hygienic beverage dispenser, cabinet pattern. Formula: Schw. A. W. Replacement unit 2 of 8. Under it, scratched into the brass with the point of a screwdriver, very neat: "Cabinet 2: please do not disconnect. V."

The docket on the pillar says the same thing (INT_M0_13). This is the one cabinet in the cellar that does not wait for the lever: Vendelin fitted a standby cell behind the token slot, as he did in every Second Wind he built after the laborers' barracks pattern, so that the nurse's schnapps could be poured on a night the facility cut the power to punish someone. It still pours. Three times, the free trial says, and no more: he could not take that out.

### perk.trigger_tonic
**Plate:** Replacement unit 3 of 8 · Dr. I. Vogt · for the generator hall
**Archive:** Maker's Plate: Trigger Tonic (the Kreuzweg cellar)

The crate-shaped cabinet at the south end of the west row, its tin hare running across the glass.

HELVETIA AUTOMATEN AG · BASEL. Formula: Dr. I. Vogt, Kaltwerk Chemie. Replacement unit 3 of 8, generator hall, Abt. II/III. Pour-time adjusted to the shift quota.

Ilse Vogt worked reload times out the way her chemical works worked out shift quotas, for the MG crews, and quit when she learned what the tanks downstairs were for. Her son Pauli drew the hare. The landlord has written on the crate's shipping card: "Same name as us. No relation, thank God." The cabinet stands in the Kreuzweg because the Amt wanted every formula one lorry from the works, and the inn was the last stop on the salt road where a lorry could turn round.

### perk.twin_barrel
**Plate:** Replacement unit 4 of 8 · by order of Maj. A. Brück
**Archive:** Maker's Plate: Twin Barrel Bitters (the Kreuzweg cellar)

The twin-barrelled cabinet in the east row, with the Major's moustache in enamel over the dispensing spouts.

HELVETIA AUTOMATEN AG · BASEL. Formula selected by Maj. A. Brück, ordnance, "for the morale of the line". Replacement unit 4 of 8.

The Major chose the bitters for other men and had his own profile painted on the cabinet. His adjutant drank the first glass. A replacement was ordered for the chapel at Kaltenbrunn because the first one, the trial report says, "was struck repeatedly by laborers, without damage". It waited here instead. Somebody has chalked a pair of spectacles on the Major's enamel face, and somebody else has rubbed them half out.

### perk.marathon_malt
**Plate:** Replacement unit 5 of 8 · family recipe, Grindelwald
**Archive:** Maker's Plate: Marathon Malt (the Kreuzweg cellar)

The tall teardrop cabinet in the east row, its runner mascot frozen mid-stride.

HELVETIA AUTOMATEN AG · BASEL. Formula: Gähwiler family (Grindelwald). Replacement unit 5 of 8.

Marathon is Res Gähwiler's grandmother's remedy, gentian and lady's mantle and honey and malt cooked slowly, which Vendelin asked him for as "the taste of running home". Res drove this lorry. He signed the docket A. Gähwiler and stood a long time in front of this one cabinet before he went up for the soup, the landlord remembered, "like a man at a grave he paid for".

### perk.hawkeye_brandy
**Plate:** Replacement unit 6 of 8 · Abt. I · the owl is not on the drawings
**Archive:** Maker's Plate: Hawkeye Brandy (the Kreuzweg cellar)

The periscope cabinet at the end of the east row. Its brass head turns to follow whoever stands in front of it. Painted small under the hawk on the glass, where the enamel is thinnest, is an owl.

HELVETIA AUTOMATEN AG · BASEL. Formula: Abt. I (derived). Replacement unit 6 of 8.

The formula card for this one says "Donor: Kurek, H. (Polish woman). Consent: not applicable." Halina Kurek, called Sowa, the owl, was a Home Army sniper; she taught a girl from Wilcza Góra to shoot. Vendelin delivered the first of these cabinets and read that line afterwards, and painted the owl under the hawk on every one he built from then on. Nobody at the Amt ever noticed. Wren will.

### perk.packmule_porter
**Plate:** Replacement unit 7 of 8 · counted, logged, signed: G. Ammer, Fw.
**Archive:** Maker's Plate: Packmule Porter (the Kreuzweg cellar)

The wagon-shaped cabinet in the south row, its tin sign still swinging when nobody has touched it.

HELVETIA AUTOMATEN AG · BASEL. Formula: Fw. A. Ammer, quartermaster. Replacement unit 7 of 8. Inventory: 1 dispenser, porter pattern; 1 wagon sign (tin); 1 sign chain; 4 castors, of which 3 turn.

Gustl Ammer counted everything, and logged the extra "training loads" of the capacity trials so carefully that nobody noticed the loads were bread for the laborers' galleries. The cabinet's own inventory list is in his hand. So is the chalk on the inn's walls (see the chalk entry): his Standing Order 17 followed his cabinets down the salt road.

### perk.blastproof_bock
**Plate:** Replacement unit 8 of 8 · Pionierschule, Kaltenbrunn detachment
**Archive:** Maker's Plate: Blastproof Bock (the Kreuzweg cellar)

The safe-shaped cabinet at the east end of the south row; its dial gives a quarter turn every few seconds.

HELVETIA AUTOMATEN AG · BASEL. Formula: Pionierschule, Kaltenbrunn field detachment. Replacement unit 8 of 8. Not to be stored near open flame (a joke, the instructors insisted).

The demolitions instructors' favourite. In 1943 Res Gähwiler smuggled a bottle of this bock and its formula card out under a beer label to his cousin Anni in Basel, and that is how London first heard of night-glass, and why four people fell out of the sky into this field. It is the last cabinet on the docket. The docket says eight.

### perk.overclock_cordial
**Plate:** No docket · no delivery · fresh solder
**Archive:** Maker's Plate: Overclock Cordial (the ninth cabinet)

The tall teal cabinet between Packmule and Blastproof, crowned with a copper coil that snaps a violet arc to a brass ball. Its plate is not riveted on: it is held by four new screws, and the stencil under the enamel is crooked.

HELVETIA AUTOMATEN AG · BASEL · Prototyp · Rezeptur: ein Freund.

The docket nailed to the pillar lists eight dispensers. This is the ninth. The landlord's notebook does not mention it, the installers' tunnel was bricked up behind them in October, and the solder on its coil is bright, as if it was finished last week. The gauge over the porthole reads LEER, HALB, VOLL, and the needle swings whenever someone nearby runs a magazine dry. There is a small round robot on the enamel holding a lightning bolt over his head, and he looks extremely pleased with himself.

### crucible
**Plate:** MOD. R-E · PAT. PEND. BLZ-40417 · crate 2/3, off the docket
**Archive:** The Crucible in the Alcove (crate 2/3)

A brass plate riveted to the furnace's feed door, in a brick alcove on the vault's north wall. Behind the furnace, against the bricks, the empty crate it came in: KÜHLANLAGE, and a stencilled 2/3.

MOD. R-E · PAT. PEND. BLZ-40417.

The docket on the pillar does not mention it, and neither does the guest book. The guest book does say that on 3 March 1944 the carter A. Gähwiler and the engineer V. Vendelin stopped here with one crate marked Kühlanlage, for the works: that was crate 1/3, the Crucible in Kaltenbrunn's Core Vault. This is the second of the three. It came in October with the replacement cabinets, by night, through the installers' tunnel, and was set into an alcove built to fit it, then the tunnel was bricked up. The tally line from the works feeds it like the cabinets, so it wakes with the cellar lever. Whoever put it here wanted a forge on the salt road, outside the facility's count, where the first people to come down that road would find it. Pencilled very small on the inside of the crate lid: "For the guests. V."

### chalk
**Archive:** Standing Order 17: the chalk at the Kreuzweg

A quartermaster's printed order, pasted inside the taproom door below the price of beer, and the chalk outlines it explains: every gun at the inn hangs on a brass token clamp over its own outline.

STANDING ORDER 17 (Kaltenbrunn district, all billets). Every weapon not carried is to hang on its outline. The outline is to be drawn in chalk, true to size, so that a missing weapon may be seen from the door. Weapons are released from their clamps against a facility token only. Weapons of unknown origin are to be outlined, clamped and logged like any other. Signed: G. Ammer, Fw., quartermaster.

The Helvetia installers fitted the clamps when they brought the cabinets in October, on the same tally line, so the inn's guns answer to the Ledger like the doors at the works. Not all of the guns are German. Nobody at the inn ordered the American ones; they turned up in the sealed crates on the salt road, the way such things turn up near Kaltenbrunn, and Ammer's clerks chalked them like everything else.

### chalk.kar98k
**Plate:** "Nachrichtentrupp · spare · 1" (the signals section's)

### chalk.m1_garand
**Plate:** "Beutewaffe (amerik.) · origin unexplained" · found in a sealed crate

### chalk.mp40
**Plate:** "Escort, L/Cpl., Rooms 2-3" · left when the gentlemen were recalled

### chalk.trench_gun
**Plate:** Lutz the farmhand's: he chalked it himself, to keep it legal

### chalk.thompson
**Plate:** The carters' outline, with a Swiss cross: "for Z., when she comes"

### chalk.gewehr43
**Plate:** The road patrol's: they clamped it properly, then ran

---

## 5. Map 1: Kaltenbrunn (`map01_kaltenbrunn`)

**Archive map:** 1

### perk.ironhide_stout
**Plate:** Barracks mess · Kessler recipe · "Tonikum: Pflicht"
**Archive:** Maker's Plate: Ironhide Stout (the barracks mess)

The barrel cabinet in the barracks mess, beside the corner where Otto Kessler kept his kettles. The ration board over it still reads "Tonikum: Pflicht" (tonic: mandatory).

HELVETIA AUTOMATEN AG · BASEL. Formula: O. Kessler. Unit 1, barracks mess, Abt. III. Service visits: Mar 41, Sep 41, Feb 42, Oct 42, May 43, Nov 43. V.V.

It stands in the mess because this is where Kessler made it: he brewed the toughness formula into a stout so that the assault engineers would drink it like Sunday beer. The guards had a glass before every shift. His brewing log (INT_M1_07) is in the barracks. The volunteers stopped feeling the cold, and then the shrapnel.

### perk.second_wind
**Plate:** Staff cabinet · Administration · the spare stood in the laborers' barracks
**Archive:** Maker's Plate: Second Wind (the administration block)

The pale-blue apothecary cabinet in the administration block, in the clerks' corridor.

HELVETIA AUTOMATEN AG · BASEL. Formula: Schw. A. W. Staff unit, administration (for officers and staff only). Its sister: the "spare", laborers' barracks.

Abteilung III ordered one cabinet, for staff. Vendelin built two: this one, where officers could see it, and a "spare" for the laborers' barracks, with a standby cell behind the coin works so that Sister Agnieszka could pour it on nights the facility cut the power to punish someone. This cabinet has a cell too. He put one in every Second Wind he built, and he never wrote down why.

### perk.trigger_tonic
**Plate:** Generator hall · pour-time to the shift quota · Dr. I. Vogt
**Archive:** Maker's Plate: Trigger Tonic (the generator hall)

The crate cabinet by the turbines, its tin hare running toward the switchgear.

HELVETIA AUTOMATEN AG · BASEL. Formula: Dr. I. Vogt. Unit 3, generator hall.

The MG crews' tonic stands with the turbines because the generator hall's guard detail drew it on every shift change, at the quota Ilse Vogt calculated for them: reloads timed like a production line. Opitz's maintenance notes complain that it "hums at the same pitch as turbine two, and turbine two has started to sulk".

### perk.twin_barrel
**Plate:** Salt Chapel · "struck repeatedly by laborers, without damage"
**Archive:** Maker's Plate: Twin Barrel Bitters (the Salt Chapel)

The twin-barrelled cabinet in the nave of the Salt Chapel, against a pew carved with miners' names.

HELVETIA AUTOMATEN AG · BASEL. Formula selected by Maj. A. Brück. Unit 4, Salt Chapel (rest station).

The chapel was where laborers were allowed to rest on Sundays, so Abteilung III put two cabinets in it and called it a rest station. The Major's enamel face has been struck so many times that the moustache is down to bare steel. The trial report noted the blows and "no damage". A replacement for this cabinet waits in the Kreuzweg's cellar, nine kilometres up the salt road.

### perk.marathon_malt
**Plate:** Salt Chapel · runner trials · Dr. H. Ostrowski, resigned
**Archive:** Maker's Plate: Marathon Malt (the Salt Chapel)

The teardrop cabinet in the chapel, its runner mascot looking toward the lift.

HELVETIA AUTOMATEN AG · BASEL. Formula: Gähwiler family (Grindelwald). Unit 5, Salt Chapel. Trials: Abt. III, Dr. H. Ostrowski (resigned).

Abteilung III ran its battlefield-runner trials here, between the chapel and the lift: laborers carrying loads up the old ladderway on Res Gähwiler's grandmother's remedy, timed with a stopwatch. Hanne Ostrowski ran the trials for four months and resigned. The remedy was for running home.

### perk.hawkeye_brandy
**Plate:** Laboratory wing · Abt. I · the owl under the hawk
**Archive:** Maker's Plate: Hawkeye Brandy (the laboratory wing)

The periscope cabinet in the laboratory wing, outside the rooms where Abteilung I ran its focus trials. An owl is painted small under the hawk.

HELVETIA AUTOMATEN AG · BASEL. Formula: Abt. I (derived). Unit 6, laboratory wing.

This is the first of them, the cabinet Vendelin delivered in April 1943 before he read the donor line on the formula card: "Kurek, H. (Polish woman). Consent: not applicable." He painted the owl on it at the next service visit, and began to work against his own machines from that day: the panels on the backs, the diluted formulas. Halina "Sowa" Kurek's fate is not recorded.

### perk.packmule_porter
**Plate:** Laboratory wing · capacity trials · "training loads" logged
**Archive:** Maker's Plate: Packmule Porter (the laboratory wing)

The wagon cabinet in the laboratory wing, by the intake room.

HELVETIA AUTOMATEN AG · BASEL. Formula: Fw. A. Ammer. Unit 7, laboratory wing (capacity trials, intake).

The capacity trials weighed laborers at intake, dosed them, and loaded them until they fell. Gustl Ammer logged every "training load" to the gram, and every gram was bread, carried down to the galleries under the trials' own paperwork. Vendelin countersigned the logs on his service visits and never asked what was in the sacks.

### perk.blastproof_bock
**Plate:** Specimen room · Pionierschule tested it here
**Archive:** Maker's Plate: Blastproof Bock (the specimen room)

The safe cabinet in the specimen room, among the tanks.

HELVETIA AUTOMATEN AG · BASEL. Formula: Pionierschule, Kaltenbrunn field detachment. Unit 8, specimen room.

The demolitions school tested its formula here, on the subjects in these tanks, before it was ever poured for an instructor. That is why the cabinet stands among them. The bottle Res Gähwiler carried to Basel under a bock-beer label came from this cabinet's first fill.

### perk.overclock_cordial
**Plate:** No unit number · no service visits · fresh solder
**Archive:** Maker's Plate: Overclock Cordial (the switchgear gap)

The tall teal cabinet in the gap in the generator hall's switchgear, where a relay cabinet should be. Its coil arcs to a brass ball; its stencil is crooked.

HELVETIA AUTOMATEN AG · BASEL · Prototyp · Rezeptur: ein Freund.

Every other cabinet at Kaltenbrunn has a unit number and a list of service visits on its plate. This one has neither. The contract says twelve dispensers; the Amt's inventory counts eleven here and eight on the salt road and none of them is this. Opitz's last maintenance note, 19 December: "The new cabinet in the switchgear gap is not new. Nobody installed it. It has been there, the men say, since the twentieth. Today is the nineteenth." His relays answer it. He did not write down what they say.

### crucible
**Plate:** MOD. R-E · PAT. PEND. BLZ-40417 · crate 1/3, signed E. Fasbender
**Archive:** The Crucible in the Core Vault (crate 1/3)

A small brass plate riveted to the feed door of the furnace in the Core Vault, readable from a step away. The vault's own inventory card is clipped beside it.

MOD. R-E · PAT. PEND. BLZ-40417.

The card reads: "1 Kühlanlage (cooling plant), Helvetia Automaten AG, crate 1/3. Delivered 3.III.44, driver A. Gähwiler, accompanied V. Vendelin, Ing. Drawings: complete. Approved: Dr. E. Fasbender, Abt. II." The facility's papers credit Fasbender with the design because he signed the drawings; he never said where they came from. It stands beside the Heart because Abteilung II had found that weapons fired thousands of times near the Heart began to "learn", and the Crucible does the learning in five seconds. Crates 2/3 and 3/3 are not on this card.

### chalk
**Archive:** Standing Order 17: the Minehead armoury

The first of Ammer's printed orders, in its frame in the gatehouse beside the Scrip issue window, and every gun rack in the facility under it: a brass clamp, a chalk outline, a token slot.

STANDING ORDER 17. Every weapon not carried is to hang on its outline, in chalk, true to size, so that a missing weapon may be seen from the door. Release against a facility token only. Weapons of unknown origin: outline, clamp, log. G. Ammer, Fw., quartermaster.

It began here. Lenz's garrison lost rifles to the deep galleries faster than the Wehrmacht could replace them, and Ammer's answer was a wall where the gap shows. Helvetia, which had built station lockers before the war, built the clamps; Opitz wired them into the Ledger's tally like the cabinets and the doors. After the Gallery Seven Flood the quartermasters began finding guns in sealed crates that nobody had shipped: American, British, Soviet. Ammer logged them as Beutewaffe, Herkunft ungeklärt, origin unexplained, and hung them on the walls with the rest.

### chalk.kar98k
**Plate:** Gatehouse rack · Lenz's guard detail · "1 of 40"

### chalk.m1_carbine
**Plate:** "Beutewaffe (amerik.)" · came up in an ore cart, sealed

### chalk.mp40
**Plate:** Rail guard, Bertha's crew · clamped at the yard office

### chalk.frag
**Plate:** Demolitions crate · "issue to Pionier personnel only"

### chalk.gewehr43
**Plate:** Administration guard · Major Lenz's office

### chalk.trench_gun
**Plate:** Confiscated from a guard · "not regulation; keep it anyway" · G.A.

### chalk.bar
**Plate:** Found in the chapel's sealed reliquary crate after the Flood

### chalk.stg44
**Plate:** Generator hall detail · the newest gun on the mountain

### chalk.etool
**Plate:** Laborers' issue, sharpened in the galleries · three strokes and a hook

---

## 6. Map 2: Totenhafen (`map02_totenhafen`)

**Archive map:** 2

### perk.second_wind
**Plate:** The laborers' barracks spare · brought north on the ore train · for A.W.
**Archive:** Maker's Plate: Second Wind (the cannery infirmary)

The pale-blue cabinet in the cannery's infirmary, between the stove and the end cot. Its paint is scraped from a rail journey, and its standby cell glows behind the louvres.

HELVETIA AUTOMATEN AG · BASEL. Formula: Schw. A. W. Spare unit, laborers' barracks, Kaltenbrunn. Pencilled on the side, in a hand that is not Vendelin's: "Komm mit uns" (come with us).

This is the spare: the cabinet Vendelin built for the laborers' barracks with a battery nobody ordered. When the ore train brought eleven laborers and Sister Agnieszka north to Totenhafen in January, the doctor's crates went in the wagons and so did this, because the nurse would not get on the train without it and the doctor wanted the cargo attended. She nursed six men back on it in a fish hall (INT_M2_01). Then she went down to the pens with the crates.

### perk.marathon_malt
**Plate:** Shipped with the ballast · "for the handlers" · Abt. III
**Archive:** Maker's Plate: Marathon Malt (the cannery)

The teardrop cabinet against the cannery's south wall, its runner looking out at the gutting lines.

HELVETIA AUTOMATEN AG · BASEL. Formula: Gähwiler family. Shipped Kaltenbrunn to Totenhafen, 2.I.45, per Helvetia Automaten AG, forwarding agent. Consignment note: "Dosing station, for the handlers of the ballast units."

Helvetia was the forwarding agent for the ballast, so the cabinets that could be moved went north with it: the men who loaded the lead coffins were to be dosed the way the facility dosed everyone. The cannery's crews carried the coffins down to the pens at a run, on Res Gähwiler's grandmother's remedy, and the harbourmaster's log calls them "the fastest gang on the Baltic".

### perk.ironhide_stout
**Plate:** Torpedo workshop · "for the men who touch the cargo"
**Archive:** Maker's Plate: Ironhide Stout (the torpedo workshop)

The barrel cabinet in the torpedo workshop, a few metres from the caged warhead store where the coffins wait instead of warheads.

HELVETIA AUTOMATEN AG · BASEL. Formula: O. Kessler. Shipped with the ballast, 2.I.45. Instruction card, typed: "Every man who handles a ballast unit is to drink first. The units are cold."

The coffins are cold enough to burn a bare hand, and the workshop crews gutted the eels for their warheads with Kessler's stout in them so they would not feel it. The instruction card is signed for the forwarding agent by someone who has written K. Imhof in a hand that is not Imhof's.

### perk.trigger_tonic
**Plate:** Torpedo workshop · the warhead crews' quota
**Archive:** Maker's Plate: Trigger Tonic (the torpedo workshop)

The crate cabinet by the lathe. A Kriegsmarine shift board hangs beside it, its quota column filled in to the last day.

HELVETIA AUTOMATEN AG · BASEL. Formula: Dr. I. Vogt. Shipped with the ballast, 2.I.45.

The Kriegsmarine took to Ilse Vogt's tonic the way the MG crews had: a workshop that has to empty a torpedo of its warhead and fill it with something else, against a sailing on the morning ebb, runs on quotas. The last line on the shift board, 5 January: "All units loaded. Quota met. Pumps to stop tomorrow, by order."

### perk.hawkeye_brandy
**Plate:** Signal tower · issued to the lamp watch · the owl under the hawk
**Archive:** Maker's Plate: Hawkeye Brandy (the signal tower)

The periscope cabinet in the signal room over the pen hall. Its head turns to the window, then to you. An owl is painted under the hawk.

HELVETIA AUTOMATEN AG · BASEL. Formula: Abt. I (derived). Shipped with the ballast, 2.I.45. Issued: signal tower, lamp watch.

The port's lamp watch was dosed for the dark: the men who sweep the signal lamp over the water had to read a periscope's feather at three thousand metres in a snowstorm. Up here, with the teletype typing the evening tally to itself, it is the only cabinet the Ledger has not learned to talk through. Possibly because of the owl.

### perk.overclock_cordial
**Plate:** No consignment note · on no manifest · fresh solder
**Archive:** Maker's Plate: Overclock Cordial (the signal tower)

The teal cabinet in the signal room, beside the teletype. Its coil arcs to a brass ball every few seconds and the teletype stutters when it does.

HELVETIA AUTOMATEN AG · BASEL · Prototyp · Rezeptur: ein Freund.

The loading manifest in the crane office lists fourteen ballast units, one medical attendant and nothing else. The forwarding agent's consignment notes list the cabinets one by one. Neither lists this. The signal watch's log: "6.I. A Helvetia cabinet in the tower. Nobody carried it up the ramp. The coil sings when the teletype runs. The teletype runs all night now." The little robot on the enamel holds his lightning bolt up toward the window, toward the sea.

### crucible
**Plate:** MOD. R-E · PAT. PEND. BLZ-40417 · crate 3/3, consignee HALE, L.
**Archive:** The Crucible in the Torpedo Room (crate 3/3)

A brass plate on the furnace's feed door, bolted between the torpedo tubes of the boat still in the pen. A consignment tag hangs from the door handle on a loop of wire.

MOD. R-E · PAT. PEND. BLZ-40417. Tag: "1 Kühlanlage, crate 3/3. Forwarding agent: Helvetia Automaten AG, Basel. Consignee: HALE, L., care of the agent. To be installed aboard for the crossing and tested in service."

The third crate came north on the ore train with Reinholt's ballast, and the man who bought the stone bought the forge with it. The boat's engineer bolted it where the eels were loaded, because the forward loading hatch was the only way into the boat that would take its drum. It wakes with the pumps: the boat's own power runs off the pen's. Mr. Hale is the name on Peg's orders. Nobody says so.

### chalk
**Archive:** Standing Order 17: the harbour stores

Ammer's order again, this time pasted to the door of the Kriegsmarine harbour stores in a Kriegsmarine translation, with a naval stamp over the Feldwebel's signature: every gun at the pens hangs on a clamp over its chalk.

STANDING ORDER 17 (extended to the Totenhafen consignment, by request of the forwarding agent). Every weapon not carried is to hang on its outline. Release against a facility token only.

The order came north with the Scrip. Helvetia, as forwarding agent, fitted the harbour's racks with the same token clamps as Kaltenbrunn's so that the stone's handlers would be paid, dosed and armed on one tally; the harbour's own Kriegsmarine stores were emptied onto the walls under it. The navy's clerks drew the outlines with a straight-edge, which no one at Kaltenbrunn ever bothered with. Some of the guns came off the boats. Some came up out of the coffins' wagons, sealed in crates nobody shipped.

### chalk.kar98k
**Plate:** Harbourmaster's hut · the last watch's rifle

### chalk.m1_carbine
**Plate:** Bolted to the cutter's hull plate · it came back with the cutter, nobody aboard

### chalk.trench_gun
**Plate:** Cannery guard · "Beutewaffe (amerik.)" · ruled with a straight-edge

### chalk.frag
**Plate:** Harbour stores · "Stielhandgranaten unavailable; substitute issued"

### chalk.mp40
**Plate:** Torpedo workshop guard · clamped by the warhead store

### chalk.stg44
**Plate:** Torpedo workshop · issued for the loading night

### chalk.etool
**Plate:** Warhead store rack · used to lever the coffin lids, then sharpened

### chalk.bar
**Plate:** Pier 1 bollard · came up sealed in a ballast wagon

### chalk.thompson
**Plate:** Pier 2, by the gangway · the boarding party's, a trophy

---

## 7. Lines (VO_SCRIPT §20)

The squad and the Operator react to the first upgrade of the match and to the first tier effect that saves someone
(`PERK_TIER`, `PERK_PROC`, `OPR_PERK_TIER2/3`), and to reading a Crucible's plate (`PLAQUE_CRUCIBLE`) or a machine's
plate (`PLAQUE`). Texts are in `docs/gravelight/VO_SCRIPT.md` §20; unbaked until the orchestrator's TTS bake, so they
play as subtitles.

## 8. For future maps

A map that adds machines, a Crucible or wall guns adds a `## N. Name (`map_id`)` section here with an `**Archive map:**`
line and one `###` entry per thing it places, then re-runs `python tools/build_perk_lore.py`. `test_machine_lore`
checks that every `Perk_*`, `WallBuy_*` and `Crucible` node in every built map scene has its entry. Helvetia Works
(unpainted prototypes, the Crucible Mod. R-E crated as "next shipment", the Original Omega Forge, all ten cabinets
including Fine Print Fernet) and Morgenrot are not built yet.

## 7. Map 4, Act I: Werk Thalbach (`map04a_thalbach`)

<!-- Parsed by tools/build_perk_lore.py like §4–§6 (UPDATE 07, docs/MAP4_FERNFLUG.md §13.1). The works' cabinets came
     with the engines, in the same consignment, and nobody at Thalbach ever turned one round. -->

**Archive map:** 4a

### perk.second_wind
**Plate:** Consignment W.T. · Cabinet 2 · please do not disconnect · V.
**Archive:** Maker's Plate: Second Wind (the Siedlung)

The pale-blue apothecary cabinet in the courtyard of the workers' housing, under the washing lines, its standby cell glowing behind the louvres as it does everywhere.

HELVETIA AUTOMATEN AG · BASEL. Hygienic beverage dispenser, cabinet pattern. Formula: Schw. A. W. Consignment Werk Thalbach, with engines, 4 (four). Under the maker's line, the same scratched note as on every cabinet of this pattern: "Cabinet 2: please do not disconnect. V."

It arrived on the same flatcars as the four impellers, crated beside them, and the yardmaster's book lists it as "comfort equipment, 8 pcs." The families in the blocks drank from it while the works ran nights. It is the one cabinet in the town that never needed the works' power, which is why it is the one that was still lit on the night the coffin cracked.

### perk.ironhide_stout
**Plate:** Consignment W.T. · Kessler recipe · for the rail yard crews
**Archive:** Maker's Plate: Ironhide Stout (the rail yard)

The iron-red barrel cabinet on the yard side of the housing wall, where the shunters drank between trains.

HELVETIA AUTOMATEN AG · BASEL · SEIT 1921. Hygienic beverage dispenser, barrel pattern. Formula: O. Kessler. Consignment Werk Thalbach. For the loading crews, Bahnhof.

Kessler's stout, made to taste like Sunday, poured for the men who unloaded lead coffins stencilled with a port's name and asked no questions because the stout stopped them feeling the cold, and then everything else. The plate's delivery tag is still wired to the hoop: "with engines, handle as one lot."

### perk.trigger_tonic
**Plate:** Consignment W.T. · Dr. I. Vogt · pour-time set to the shift
**Archive:** Maker's Plate: Trigger Tonic (the canteen)

The crate-shaped cabinet by the canteen's east door, the tin hare running across the glass toward the serving hatch.

HELVETIA AUTOMATEN AG · BASEL. Formula: Dr. I. Vogt, Kaltwerk Chemie. Consignment Werk Thalbach, canteen. Pour-time adjusted to the shift quota.

The canteen poured it with the midday soup. Ilse Vogt worked reload times out like shift quotas and quit when she learned what the tanks downstairs were for; here there were no tanks downstairs, only a banner for a works concert that never happened and a radio set on the stage that Wittkamp used, later, to talk to strangers.

### perk.twin_barrel
**Plate:** Consignment W.T. · by order of Maj. A. Brück · for the parish house
**Archive:** Maker's Plate: Twin Barrel Bitters (the church square)

The twin-barrelled cabinet against the parish house, the Major's moustache in enamel over the spouts, bomb dust on the glass.

HELVETIA AUTOMATEN AG · BASEL. Formula selected by Maj. A. Brück, ordnance, "for the morale of the line". Consignment Werk Thalbach, church square.

The Major chose the bitters for other men. The parish priest, the housekeeper's note says, refused to have it inside and so it stands outside, where the Allied raids that were aimed at a fighter works found the church tower instead, three times.

### perk.marathon_malt
**Plate:** Consignment W.T. · family recipe, Grindelwald · hall 2, north wall
**Archive:** Maker's Plate: Marathon Malt (the assembly halls)

The tall teardrop cabinet at the north end of the assembly halls, between the jig gantries, its runner frozen mid-stride under the chutes.

HELVETIA AUTOMATEN AG · BASEL. Formula: Gähwiler family (Grindelwald). Consignment Werk Thalbach, Montage 2.

The fitters ran the halls' length between the two jigs a hundred times a shift; the works put the malt where the run ended. Res Gähwiler's grandmother's remedy, gentian and lady's mantle and honey, which Vendelin asked for as "the taste of running home". The delivery docket is signed in Res's hand. He drove this lorry too.

### perk.hawkeye_brandy
**Plate:** Consignment W.T. · "FOKUS" · wind tunnel, test section
**Archive:** Maker's Plate: Hawkeye Brandy (the wind tunnel)

The periscope-shaped cabinet beside the wind tunnel's glass wall, where the model Kranich sits on its sting.

HELVETIA AUTOMATEN AG · BASEL. Formula: derived, Kaltenbrunn laboratory. Consignment Werk Thalbach, Windkanal.

The tunnel technicians drank it to read the smoke lines on the model's wing. Its formula was derived from tests on a captured sniper, which the plate does not say and Wren knows; the technician who ran this tunnel, Jette Maurer, drank it once, wrote the model's lift numbers in her log, and then wrote *nein*.

### perk.packmule_porter
**Plate:** Consignment W.T. · Fw. G. Ammer · test-stand stores
**Archive:** Maker's Plate: Packmule Porter (the engine test stands)

The wagon-shaped cabinet against the north wall of the test stands, by the bunker door.

HELVETIA AUTOMATEN AG · BASEL. Formula: Fw. G. Ammer, quartermaster. Consignment Werk Thalbach, Prüfstand stores.

Ammer used the extra-capacity trials to smuggle food to labourers at Kaltenbrunn; here his porter stood beside a store of test-stand parts and nobody carried anything out of it but engines. The stencil under the enamel is the same as on every cabinet of this pattern. Vendelin covered for him. The porter still does.

### perk.blastproof_bock
**Plate:** Consignment W.T. · demolitions pattern · behind the blast wall
**Archive:** Maker's Plate: Blastproof Bock (the engine test stands)

The safe-shaped cabinet behind the test stands' blast wall, between the pits, its door scorched by every engine run.

HELVETIA AUTOMATEN AG · BASEL. Formula: demolitions school, Kaltenbrunn. Consignment Werk Thalbach, Prüfstand.

The one cabinet on the map that was put somewhere sensible: behind the blast wall, where the engine crews stood. A sample of this formula reached the SOE in 1943 through a delivery driver's cousin, which is how Peg's orders exist, which is why she is here.

### crucible
**Plate:** MOD. R-E · PAT. PEND. BLZ-40417 · UNIT 3 · PRÜFSTAND BUNKER
**Archive:** The Crucible at Thalbach (the control bunker)

The third violet forge the squad has seen, bolted to the floor of the test stands' control bunker behind the lead-glass slit, its violet strap still on. Unit 3 of a consignment of four: the works got one for the engine crews' tools and sent one aboard the wing.

MOD. R-E · PAT. PEND. BLZ-40417 · UNIT 3. The same brass plaque as the one in the Kaltenbrunn vault and the one in the U-boat's torpedo room, with a works stencil over it: "Prüfstand, Werkzeug" (test stand, tools). The bunker's log lists what it re-taught: wrenches, a rivet gun, a Flak crew's sidearms, and, on the last page in a different hand, "the engineer's hands. Do not do this again."

### chalk
**Plate:** Three strokes and a hook, in chalk, on a casing in the goods shed
**Archive:** Chalk at Thalbach: the works' standing orders and the labourers' alphabet

Chalked on the goods shed's door: the works' standing order for the rail yard ("all consignments marked W.T. unload under the netting; no lamps"), the shunters' tally, and, lower, in a different chalk, three strokes and a hook. The labourers who were marched west on 2 May left the alphabet on everything they touched: a bomb casing, a jig frame, a crate of valve plates. Three strokes and a hook means "weak, ours, don't trust it." Wall guns chalked in the works: the Kar98k by the cellar, the M1 Carbine on the housing wall, the MP40 on the yard wall, the Thompson over the canteen stage, the M1 Garand on the church tower, the STG-44 in the assembly hall, the BAR by the test stands.

### chalk.kar98k
**Plate:** Kar98k · Hausblock 1, cellar door · "for the warden"

### chalk.m1_carbine
**Plate:** M1 Carbine · Siedlung wall · "found on the road, 2.V."

### chalk.mp40
**Plate:** MP40 · Bahnhof, east wall · "yard guard"

### chalk.thompson
**Plate:** Thompson · canteen, over the stage · "concert cancelled"

### chalk.m1_garand
**Plate:** M1 Garand · church tower, east face · "from the airmen"

### chalk.stg44
**Plate:** STG-44 · Montage 1, east wall · "works guard, hall 1"

### chalk.bar
**Plate:** BAR · Prüfstand, east wall · "test-stand crew, never fired"

## 9. Map 4, Act II: der Kranich (`map04b_kranich`)

<!-- Parsed by tools/build_perk_lore.py like §4–§7 (UPDATE 07, docs/MAP4_FERNFLUG.md §4, §13.1). The wing's
     cabinets were bolted in for a crew that never existed; every plate carries the works' crane-in-a-cog stencil. -->

**Archive map:** 4b

### perk.second_wind
**Plate:** Consignment W.T. · Cabinet 1 of 8 · aft bay · do not disconnect · V.
**Archive:** Maker's Plate: Second Wind (the bomb bay)

The pale-blue apothecary cabinet strapped to the aft bay's forward bulkhead between the rack rows, its standby cell glowing behind the louvres while the bay doors are shut.

HELVETIA AUTOMATEN AG · BASEL. Hygienic beverage dispenser, cabinet pattern. Formula: Schw. A. W. Consignment Werk Thalbach, aircraft fit, 1 of 8. Under the maker's line the scratched note Vendelin leaves on every one of these.

The crew list says "provided." The cabinet was fitted for them anyway: the works' fitters bolted eight machines into a flying wing because the consignment said eight and nobody asked who would drink.

### perk.skyhook_sekt
**Plate:** Consignment W.T. · Cabinet 2 of 8 · ELEVATION · galley, port side · J. Maurer
**Archive:** Maker's Plate: Skyhook Sekt (the galley)

The pale sky-blue glider-nosed cabinet bolted beside the galley's kettle, its little propeller ticking round whenever the deck drops under a jump, Fräulein Kranich's scarf out straight on the enamel.

HELVETIA AUTOMATEN AG · BASEL. Hygienic beverage dispenser, glider pattern. Formula: H. Maurer, Windkanal Thalbach. Consignment Werk Thalbach, aircraft fit, 2 of 8. "Leicht · Lieber · Landen."

Jette Maurer's Sekt, made so a crew at altitude for eleven hours would land well rather than fly; she refused to fly the wing and refused to test it on anyone. The cabinet went aboard without her, with her name on the plate, which is the only part of the Kranich she ever signed.

### perk.trigger_tonic
**Plate:** Consignment W.T. · Cabinet 3 of 8 · galley, starboard · Dr. I. Vogt
**Archive:** Maker's Plate: Trigger Tonic (the galley)

The crate-shaped cabinet across the galley from the Sekt, the tin hare running toward the radio room.

HELVETIA AUTOMATEN AG · BASEL. Formula: Dr. I. Vogt, Kaltwerk Chemie. Consignment Werk Thalbach, aircraft fit, 3 of 8. Pour-time set to the watch.

Ilse Vogt's reload tonic, pour-time set to a flight watch nobody would stand. The galley's kettle beside it is still warm; the hare on the glass has a scratch across its eye from the day the cabinet was strapped down.

### perk.ironhide_stout
**Plate:** Consignment W.T. · Cabinet 4 of 8 · port wing, rib bay 3 · O. Kessler
**Archive:** Maker's Plate: Ironhide Stout (the port wing)

The iron-red barrel cabinet wedged into a rib bay of the port crawlspace, its hoops scraped silver where it was dragged along the spar.

HELVETIA AUTOMATEN AG · BASEL · SEIT 1921. Formula: O. Kessler. Consignment Werk Thalbach, aircraft fit, 4 of 8. "For the gunners."

Kessler's stout for gunners who were never aboard. It was the last cabinet the fitters carried in; the drag marks along the spar are theirs, and so is the chalk arrow on the rib that says "zu schwer" (too heavy).

### perk.marathon_malt
**Plate:** Consignment W.T. · Cabinet 5 of 8 · starboard wing, rib bay 3 · Gähwiler
**Archive:** Maker's Plate: Marathon Malt (the starboard wing)

The tall teardrop cabinet in the starboard crawlspace's third rib bay, the runner on its glass tilted with the wing.

HELVETIA AUTOMATEN AG · BASEL. Formula: Gähwiler family (Grindelwald). Consignment Werk Thalbach, aircraft fit, 5 of 8.

Res Gähwiler's grandmother's malt, "the taste of running home," fitted to a wing whose flight plan has no home on it. The runner on the glass leans with every bank.

### perk.blastproof_bock
**Plate:** Consignment W.T. · Cabinet 6 of 8 · port engine room · LIABILITY
**Archive:** Maker's Plate: Blastproof Bock (the engine room)

The safe-shaped cabinet bolted into the port engine room beside the engineer's station, its enamel blistered by the impeller's heat, the waiver text on its glass gone brown.

HELVETIA AUTOMATEN AG · BASEL. Formula: demolitions school, Kaltenbrunn. Consignment Werk Thalbach, aircraft fit, 6 of 8. Under the maker's line, a second stencil in another hand: "a Darkm— part in a Reich wing" scratched out to "a foreign part".

The flight engineer drank it before every engine run, the station log says, "for the vents." It is the only cabinet aboard with a drinker's name in a log, and the log stops the day the impellers were lit.

### perk.hawkeye_brandy
**Plate:** Consignment W.T. · Cabinet 7 of 8 · gunner gallery · "FOKUS"
**Archive:** Maker's Plate: Hawkeye Brandy (the gun blisters)

The periscope-shaped cabinet at the head of the blister gallery, its lens turned to the aft dome that looks back and down.

HELVETIA AUTOMATEN AG · BASEL. Formula: derived, Kaltenbrunn laboratory. Consignment Werk Thalbach, aircraft fit, 7 of 8. "For the observers."

Derived from tests on a captured sniper, which the plate does not say and Wren knows. It was fitted beside the window through which, on this flight, the squad watches London burn; nobody aboard will ever drink it for the reason it was built.

### perk.packmule_porter
**Plate:** Consignment W.T. · Cabinet 8 of 8 · flight deck · G. Ammer
**Archive:** Maker's Plate: Packmule Porter (the cockpit)

The wagon-shaped cabinet behind the two empty seats on the flight deck, strapped under the autopilot's cradle so the crew could reach it without unbuckling.

HELVETIA AUTOMATEN AG · BASEL. Formula: Fw. G. Ammer, quartermaster. Consignment Werk Thalbach, aircraft fit, 8 of 8.

Gustl Ammer's porter, from the man who used the capacity trials to smuggle food to labourers. It is the last cabinet before the autopilot and the only one with its bottle window scratched, as if someone looked at it for a long time and did not drink.

### crucible
**Plate:** MOD. R-E · PAT. PEND. BLZ-40417 · UNIT 4 · GALLEY, DECK FITTING · VIOLET STRAP
**Archive:** The Crucible aboard the Kranich (the galley)

The fourth violet forge, bolted to the galley's deck plates with the consignment's violet strap, for a crew's weapons that were never carried aboard.

MOD. R-E · PAT. PEND. BLZ-40417 · UNIT 4. The same brass plaque as the vault's, the U-boat's and the bunker's, with a fitter's chalk beside it: "warum?" (why?).

### chalk
**Plate:** Three strokes and a hook, in chalk, on the casings in the aft bay
**Archive:** Chalk aboard the Kranich: the labourers' alphabet on the bombs

Chalked on the bomb casings in the aft bay, low on the shackle side where a fitter would not look: three strokes and a hook, the Kaltenbrunn gangs' mark for "weak, ours, don't trust it." The marked casings are the duds. The men who marked them were marched west on the second of May and are not aboard.

### chalk.kar98k
**Plate:** Chalk by the aft bay's rifle rack: "Ersatz, 1 Stück" (spare, 1 piece)
**Archive:** Chalk: the bay's Kar98k

### chalk.mp40
**Plate:** Chalk on the galley bulkhead: "Bordwaffe · Pistolenmunition hinten" (ship's weapon, pistol ammunition aft)
**Archive:** Chalk: the galley's MP40

### chalk.thompson
**Plate:** Chalk on the port spar: "Beute · funktioniert" (captured, works)
**Archive:** Chalk: the port wing's Thompson

### chalk.stg44
**Plate:** Chalk on the starboard spar: "für die Kanzel" (for the blisters)
**Archive:** Chalk: the starboard wing's STG-44

### chalk.bar
**Plate:** Chalk under the blister gallery's rack: "Reserve, Dom 4" (spare, dome 4)
**Archive:** Chalk: the blister gallery's BAR

## 10. Map 4, Act IV: Mondlicht (`map04d_mondlicht`)

<!-- Parsed by tools/build_perk_lore.py like §4–§9 (UPDATE 07, docs/MAP4_FERNFLUG.md §6, §13.1). The relay's
     cabinets are field-unit issue: bare steel, the plates stamped not engraved, every one a "prototype" because
     the Provider never paid for a finished pattern on the Moon. The writer rule holds: no company name, no
     "subscription"; the Provider is "the Provider", the Plan is "the Plan". -->

**Archive map:** 4d

### perk.second_wind
**Plate:** Relay RR-7 · Cabinet 1 · landing dome · field pattern · "RETURNS ACCEPTED"
**Archive:** Maker's Plate: Second Wind (the landing dome)

The pale-blue apothecary cabinet by the reception desk, its enamel sand-blasted grey by seven years of regolith, a field unit's stamp where Basel's plate should be.

HELVETIA AUTOMATEN AG · BASEL. Hygienic beverage dispenser, cabinet pattern, field issue. Formula: Schw. A. W. Shipped 1939 with the relay's first consignment; the only cabinet in the building the field units were told to fill.

The Provider calls a second wind a "return": the customer comes back. On the Moon it is the one tonic the relay was built to have in stock, because a customer who stays down is a customer who stops engaging, and nothing here is allowed to stop.

### perk.skyhook_sekt
**Plate:** Relay RR-7 · Cabinet 2 · concourse, port · PROTOTYPE · ELEVATION · J. Maurer (by consignment)
**Archive:** Maker's Plate: Skyhook Sekt (the concourse)

A glider-nosed cabinet in bare steel beside the relay's model, no enamel, the little propeller frozen, the terms plate on its back readable from the front because someone turned it round.

HELVETIA AUTOMATEN AG · BASEL. Glider pattern, prototype. Formula: H. Maurer, Windkanal Thalbach. The Provider's shipping note calls it "lift (customer-generated)": the formula came up from Thalbach in the consignment, not down from Legal.

Jette Maurer never knew her Sekt went to the Moon. In a sixth of a gravity it does what she made it for on Earth and more: the floor is a suggestion here anyway; the Sekt makes the landing a decision. The cabinet's back was turned to the room by a hand that wanted the terms read.

### perk.magpie_mead
**Plate:** Relay RR-7 · Cabinet 3 · concourse, starboard · PROTOTYPE · RECOVERY · "repainted by the customer"
**Archive:** Maker's Plate: Magpie Mead (the concourse)

The bandit-striped cabinet across the concourse from the Sekt, its export-pattern paint scraped back to the plate by someone with a knife and time, the bird on the glass looking down as always.

HELVETIA AUTOMATEN AG · BASEL. Export pattern, prototype, field issue. The formula came back up the chain from a range in Nevada with a note the Provider filed as feedback: "nothing on the range goes to waste." The Provider agreed, and meant something else.

Dee's mead, by way of Groom Lake's recovered crates, by way of a fold pad: the Provider ships what the customers bring. On the Moon the Magpie finds what seven years of inventory dropped on the regolith, and the pencil note under the panel, READ THIS, is the first thing in the building written to be read.

### perk.ironhide_stout
**Plate:** Relay RR-7 · Cabinet 4 · fulfillment, west aisle · field pattern · O. Kessler (by consignment)
**Archive:** Maker's Plate: Ironhide Stout (the store)

The armour-plated cabinet at the head of the store's first aisle, bolted to the rack's upright as if it were inventory, its plate stamped on the same tag the suits wear.

HELVETIA AUTOMATEN AG · BASEL. Hygienic beverage dispenser, armour pattern, field issue. Formula: O. Kessler, Prüfstand Thalbach. Consigned with the store's fittings: "for the retention of the retained."

The Provider stocked the stout in the store because the inventory on the racks takes damage in transit, and a Plan that holds the dead upright a little longer is a Plan that renews. The Kessler formula, meant for test-stand crews, does the same for the living, which the Provider calls a feature.

### perk.trigger_tonic
**Plate:** Relay RR-7 · Cabinet 5 · fulfillment, east wall · field pattern · Dr. I. Vogt (by consignment)
**Archive:** Maker's Plate: Trigger Tonic (the store)

The crate-shaped cabinet under the store's east hatches, the tin hare on its glass running toward the conveyor, its pour-time dial set to a watch no one on the Moon keeps.

HELVETIA AUTOMATEN AG · BASEL. Formula: Dr. I. Vogt, Kaltwerk Chemie. Field issue, 5 of 8. The dial reads "fulfillment shift": the Provider timed it to the conveyor, not to a day.

Vogt's reload tonic, set to a conveyor that moves the dead from the pad to the racks and back out to the Earth. The hare has a scratch across its eye here too; someone carried the same cabinet pattern up the chain, scratch and all, which is how patterns travel.

### perk.hawkeye_brandy
**Plate:** Relay RR-7 · Cabinet 6 · retention hall, west · field pattern · "LINE OF SIGHT"
**Archive:** Maker's Plate: Hawkeye Brandy (the retention hall)

The tall narrow cabinet against the nave's west rib, its glass etched with the relay's own symbol, a dish, where the hawk should be.

HELVETIA AUTOMATEN AG · BASEL. Hygienic beverage dispenser, long-sight pattern, field issue. Consigned "for the hall's line of sight to the dish": the Provider wanted its customers to see the columns from the door.

A brandy for seeing far, in a hall built to be looked down. The columns hum at the far end; the sign hangs over the door to the Account. Whoever drinks here sees the terms plates from the threshold, which is the opposite of what the Provider sells and exactly what the plates are for.

### perk.blastproof_bock
**Plate:** Relay RR-7 · Cabinet 7 · retention hall, east · field pattern · "SHOCK TESTED"
**Archive:** Maker's Plate: Blastproof Bock (the retention hall)

The bunker-grey cabinet under the hall's east chutes, its casing dented where something came through the chute and did not stop.

HELVETIA AUTOMATEN AG · BASEL. Shock pattern, field issue. Consigned with the hall: the Provider's note reads "customers may experience turbulence on cancellation."

The Bock for standing in a blast, placed by the Provider where the Backorders come in thickest, because a customer who is knocked down in the hall tends to read the floor and not the plates. The dent is from the first delivery. It still pours.

### perk.packmule_porter
**Plate:** Relay RR-7 · Cabinet 8 · the Account · field pattern · "CARRY-OVER"
**Archive:** Maker's Plate: Packmule Porter (the Account)

The heavy two-door cabinet inside the Account's door, the only cabinet in the room, its plate stamped with the Provider's own motto on the back where a customer would not look.

HELVETIA AUTOMATEN AG · BASEL. Carrier pattern, field issue, 8 of 8. The stamp on the back reads NOBODY CANCELS, and under it, in Vendelin's hand, a smaller stamp: "...except you."

A porter for carrying more, in the one room where what you carry is the point. The Provider installed it for the Account Manager's guests, who were expected to arrive with a great deal and leave with nothing. The small stamp was not on the consignment.

### crucible
**Plate:** MOD. R-E · PAT. PEND. BLZ-40417 · UNIT 001 · CONCOURSE · NEVER LIT
**Archive:** The first Crucible (the concourse)

The original violet forge, the first of the pattern, shipped to the relay in 1939 before Kaltenbrunn, the U-boat, the bunker or the Kranich got theirs, bolted under the concourse's violet strips and never once lit.

MOD. R-E · PAT. PEND. BLZ-40417 · UNIT 001. The same brass plaque as every forge after it, but stamped, not engraved, and with a field unit's tally beside it: one stroke, for the one time someone tried the door and found it locked.

The relay was built to receive, not to make; the forge was shipped so the building would be complete on paper. Seven years of standby cell behind the louvres and nothing ever forged. The Operator asks, for once without a slip, that it be used.

### chalk
**Plate:** Three strokes and a hook, scratched, not chalked, on the rack tags in the store
**Archive:** Scratches on the Moon: the labourers' mark in the store

Scratched into the metal tags of the suited inventory in the store, on the side a fitter would not look, three strokes and a hook: the Kaltenbrunn gangs' mark for "weak, ours, don't trust it." There is no chalk on the Moon. Someone did it with a nail, in a pressure suit, in the dark, on every tag that belonged to a man they knew. Standing Order 17 forbade marking inventory; the order is not in force here, and was not obeyed there either.

### chalk.kar98k
**Plate:** Scratched by the landing dome's rack: "ANOMALOUS INVENTORY · 1 Stück"
**Archive:** Scratches: the dome's Kar98k

### chalk.thompson
**Plate:** Scratched on the concourse rib: "Beute · funktioniert noch" (captured, still works)
**Archive:** Scratches: the concourse's Thompson

### chalk.springfield
**Plate:** Scratched into the rim rock by the yard's rack: "25 s" and a hook
**Archive:** Scratches: the yard's Springfield

### chalk.bar
**Plate:** Scratched under the store's east rack: "Reserve, Lager 7" (spare, store 7)
**Archive:** Scratches: the store's BAR
