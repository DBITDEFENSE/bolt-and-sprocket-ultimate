# TERMS & CONDITIONS: Canon Bible

This is the single source of story truth for all three stories. When another document disagrees with this one, this one wins. If this one is wrong, fix it here first, then everywhere else. Quick-reference facts (IDs, dates, numbers) live in `M0_SHARED_FACTS.md`. The dated chronology lives in `TIMELINE.md`.

**The theme:** nobody reads the fine print. In Bolt & Sprocket, a megacorp conquers a galaxy one free trial at a time. In Gravelight, the perk machines, points and undead of 1944 Silesia turn out to be an alien company's test market. The Fine Print shows the player both sides.

**The working title** is TERMS & CONDITIONS, stored in `Game.GAME_TITLE` (`core/game.gd`).

---

## 1. The two worlds

### 1.1 The Bolt & Sprocket galaxy (the Rustbelt galaxy, far future)
A cartoon-bright, comedic, far-future galaxy of junk planets, orbital malls and resort worlds.

**OmniScrap™**, run by **Chairman Grindstone**, has turned everything into a subscription: air (AIR PREMIUM™), lava (LAVA: NOW LEGALLY WATER), sunsets ("almost monetized"), freezing people for later (ForeverYou™), and a whole smart city fined until it emptied (Nova Plaza). Its motto, in Grindstone's mouth, is "Everything is a subscription, boy."

**Its people:**
- **Bolt** is a junk-planet mechanic whose garage is repossessed under Section 12-B ("Two mallets and a sandwich!").
- **Sprocket** is his floating, one-eyed, four-mood robot. He was rebuilt from a refund bin, and he carries OmniScrap's **Clause 44** (remote decommission) in his firmware.

Together they take OmniScrap down, planet by planet. The whole story is told through dialogue, holo-calls, memos and ad vignettes that are already canon (`data/bs/story/`).

**OmniScrap's empire "ran on meeting minutes."** Sprocket's last act of the campaign is forwarding all 35 internal memos (40 in the remake) to forty billion inboxes. OmniScrap stock is "reclassified as confetti."

### 1.2 Earth, 1938–1945
Grim pulp horror with gallows humor: a lost war film that slowly becomes a ghost story.

**Nachtglas** is a black, glassy mineral with violet-amber veins, recovered in 1938 from a "meteorite" strike in the Kaltenbrunn salt mine in occupied Silesia. Dead tissue near it keeps running its last impulse, and in the end that impulse is hunger. Living tissue dosed with diluted Nachtglas gains temporary traits.

**Projekt Wiederkehr** ("Project Return") is the Reich program built on the mineral. Its lead scientist, **Dr. Augusta Reinholt**, privately wants her daughter **Liesl** back; Liesl died of diphtheria in 1939. Her colleague **Dr. Emil Fasbender** understood what the material really does and offered to defect.

**Operation Gravelight** is the joint SOE/OSS extraction team sent for Fasbender, made up of Dutch, Peg, Deacon and Wren. Their plane is brought down near Kaltenbrunn on 23 December 1944 by "something that isn't flak."

The full Gravelight canon lives in `docs/gravelight/` (LORE, CHARACTERS, ENEMIES, WEAPONS, MAPS, EASTER_EGGS, VO_SCRIPT), amended by brief §11.

---

## 2. What connects them: Darkmatter Subscriptions LLC

The original game ends with Darkmatter as sequel bait (`cs.postCredits.01–03`):
- Darkmatter reviews OmniScrap's leaked memos and sees "a market gap of approximately forty billion souls."
- It orders an acquisition, and wants whoever has been reading the internal memos "on OUR payroll."
- Sprocket then gets a calendar invite for a "synergy screening" in another galaxy, sent *yesterday*.

**Darkmatter is the hidden source of everything in Gravelight.**

- **Who they are:** a megacorp from the neighboring **Umbral Galaxy**. Their motto is **"NOBODY CANCELS."** OmniScrap sold subscriptions; Darkmatter sells **retention**. Grindstone was "just the invoice." Darkmatter is the collections department.
- **Brand:** deep violet `#c07dff` with amber cracks. The original game already gave the Darkmatter speaker this violet.
- **Next-Era Delivery™:** Darkmatter ships product through folds in space *and time*, using a resonant crystal it sells as **DARK-GLASS™**. Delivery ignores chronology, so Darkmatter can sell things to 1944 that it acquired "later" in the B&S timeline. Sprocket: *"They shipped it to the PAST. They BACKDATED THE INVOICE. That is the most Darkmatter sentence I have ever said."*
- **DARK-GLASS™ = Nachtglas.** On Earth, the Germans named the crystal Nachtglas.
- **The Sol-3 Test Market:** Darkmatter's Emerging Markets Division wanted to know whether a "pre-subscription species" could be retained.
  - On **9 November 1938** it fired test-market probe **TM-SOL3-001** through a fold. The probe landed in the Kaltenbrunn salt mine, and everyone took it for a meteorite.
  - The payload was DARK-GLASS™ **retention substrate**. Its product function is *churn prevention*: a retained user cannot cancel.
  - Dead tissue near it keeps running its last impulse. **The zombies are the ultimate retained customers.** That is the horror's origin.
  - The probe's internal results line reads: **"EXCEPTIONAL RETENTION."**

### 2.1 Darkmatter's people
- **Sable Vantage** is Darkmatter's VP of Emerging Markets and launched the Sol-3 test market. She has a velvet voice and perfect posture, and says "we" when she means "you."
  - She is the Darkmatter representative who offered Reinholt her dead daughter back, *as a service*.
  - In Gravelight she is never named; Reinholt's recordings call her only **"the Woman in Violet."**
  - The player first *sees* her in The Fine Print Ch. 1's last scene, and fights her mech, THE QUARTERLY, in Ch. 4.
- **The Underwriter** is Darkmatter's risk-assessment enforcer: a towering, ledger-faced machine that "prices" everything it looks at. It enforces **Clause 0** and is The Fine Print's main boss.
- **The Board** is a conference call of distorted voices that is never shown. It is the voice of the B&S post-credits ("Initiate acquisition").
- **Vendelin** is Field Merchandiser Unit **V-1** (serial DMS-FMU-V1-0001). His directive is **"DISTRIBUTE. RETAIN. REPORT."**
  - He crash-landed with the probe in 1938, damaged and out of contact.
  - He passed as human: **Herr Viktor Vendelin, Ingenieur, Basel.**
  - He founded **Helvetia Automaten AG** in 1940, built every perk cabinet, and wrote every jingle. In his words, "a product must be *loved* to be retained." He grew to hate how catchy they are.
  - He learned from humans, understood what his product does to them, and sabotaged it from inside.
  - His recall clause is **Clause 0: "Field units are inventory."**

---

## 3. What each Gravelight system really is

The Gravelight squad never learns any of this. The player learns it through The Fine Print.

| Gravelight thing | What Earth thinks it is | What it really is |
|---|---|---|
| Nachtglas | A meteorite mineral | DARK-GLASS™ retention substrate from probe TM-SOL3-001 |
| Perk Tonics / Helvetia Automaten AG | A Swiss vending company and its tonic formulas | Darkmatter **Vitality Plans** (plan IDs stenciled under the paint, listed in `M0_SHARED_FACTS.md`). Cabinets and jingles by Vendelin; each formula made drinkable by a human (§4) |
| The Crucible | A Nachtglas forge that "re-teaches" weapons | Blartz's patented **Omega Forge** (BLZ-40417). It was confiscated by OmniScrap when Blartz was arrested, sold to Darkmatter in OmniScrap's fire sale, rebuilt as **Crucible Mod. R-E (Re-Education)**, and shipped to 1944. Its brass plaque reads **"MOD. R-E · PAT. PEND. BLZ-40417"** |
| The Ledger / Scrip | A relay computer tallying kills and paying tokens | Darkmatter's engagement-metrics engine. Scrip are localized **loyalty points** |
| The Operator | A cheerful announcer sampled from propaganda tapes | Darkmatter's **Customer Retention Interface**. It chose a "market-appropriate localization," is self-aware, and loves its quarterly numbers. Its first words: *"Market localization complete. Welcome, valued customers."* |
| Mystery Crate (Lost Requisition Crate) | Pulls weapons from other battlefields | Darkmatter's **Loot Allocation Unit**: it pulls "returned inventory" from across times and places. That is why it can rarely hold a Bolt & Sprocket weapon |
| Liesl's tin drummer | Haunts the crate | **The one true mystery.** Reinholt's grief "infected" the unit. Vendelin can't explain it either |
| Power-ups | Mysterious drops | Darkmatter **engagement incentives** that fire when activity metrics spike. Ch. 3 shows the design meeting as a holo-memo |
| Perk loss on down | The tonic wears off | Your subscription lapses |
| Second Wind in solo (works without power; 3 uses, then the machine vanishes) | A quirk | A **free trial**, plus a secret battery Vendelin hid in that one cabinet so it would work when nothing else did. The 3-use limit is Darkmatter's free-trial rule, which he could not remove |

---

## 4. The Vitality Plans (the perk machines)

Each machine has a hidden **fine-print panel on its back**: Vendelin's real terms of service, written as warnings no one read. Every jingle, panel and plan ID is in `docs/JINGLES.md`.

| Perk | Plan | The human behind the formula | Their story |
|---|---|---|---|
| Ironhide Stout | DURABILITY+ | **Otto Kessler**, a conscripted Bavarian brewmaster | Made the substrate drinkable as a stout so it would at least taste like home. He drank the first batch himself so no one else had to. |
| Second Wind Schnapps | CONTINUITY (Free Trial) | **Sister Agnieszka**, a Polish forced-labor nurse at Kaltenbrunn | She and Vendelin secretly altered it to keep prisoners alive. This is the cabinet with the hidden battery. Wren knows her name. |
| Trigger Tonic | THROUGHPUT | **Dr. Ilse Vogt**, a shift chemist at the fictional Kaltwerk Chemie | Calculated reload times like shift quotas. Her son drew the hare mascot. She quit when she learned what the tanks downstairs were for. |
| Twin Barrel Bitters | VELOCITY | **Major Anselm Brück**, an ordnance officer | Vain; demanded his own mustache on the mascot. He was the first officer Vendelin saw choose the plan for others "for morale," and Vendelin's first lesson about humans. |
| Marathon Malt | MOBILITY | **Res Gähwiler's grandmother**'s alpine herbal malt | Vendelin asked Res for "the taste of running home." Res gave him the family recipe and never forgave himself. |
| Hawkeye Brandy | FOCUS | Derived by Reinholt's lab from tests on **Halina "Sowa" Kurek**, a captured Home Army sniper and **Wren's mentor** | Wren hates that it works. Vendelin delivered the cabinet and found out after. **This is when he starts sabotaging.** |
| Packmule Porter | CAPACITY | **Feldwebel Gustl Ammer**, a quartermaster obsessed with inventory | Used the extra-capacity trials to smuggle food to laborers. Vendelin covered for him. |
| Blastproof Bock | LIABILITY WAIVER | The Kaltenbrunn demolitions school | Res smuggled a sample to the SOE in 1943 through his cousin Anni. That is how British intelligence learned Nachtglas exists, and the root of Peg's sealed orders. |
| **Fine Print Fernet** *(new)* | DISCLOSURE (unreleased) | Vendelin himself | A bitter green digestif that lets you *see the truth*: power-up timers, drops lasting 50% longer, Easter-egg objects glinting. It is the plan Darkmatter refused to sell. |
| **Overclock Cordial** *(new)* | SURGE (unreleased) | A scan of **Sprocket's** firmware, taken after Ch. 5 | Reloading releases a static burst that scales with how empty the magazine was. Bolt: "Is that... Sprocket-flavored?" Sprocket: "I'm EXTREMELY flattered and I want royalties." |

Gravelight's 4-perk cap stays; the two new perks never break it. Each plan ID is visible only after The Fine Print is complete, or when lit by an upgraded weapon's muzzle flash ("a stencil under the enamel").

---

## 5. The Crucible's true origin (a chain the player can trace)

1. **B&S campaign:** Blartz invents the **Omega Forge**, which is why B&S weapons can evolve. The patent is BLZ-40417, the same serial as his PATENT PENDING gun.
2. **B&S campaign:** OmniScrap arrests Blartz for "unlicensed innovation" and **confiscates the prototype schematics**. In the remake this is shown in a new memo (#37) and a short Holding Block scene. When he's rescued, Blartz rebuilds the Forge "from memory, which is better than the original, which was also perfect."
3. **After OmniScrap collapses:** Darkmatter buys the confiscated IP in the fire sale and builds **Crucible Mod. R-E**.
4. **1944:** Via Next-Era Delivery, a Crucible is shipped to the Sol-3 test market. That is why Kaltenbrunn's Core Vault has one, plaque and all. Players can read the plaque in Gravelight long before they understand it.
5. **Fine Print Ch. 4:** Blartz learns the truth and is outraged, mostly about the color: *"They put MY forge in a WAR? And they made it VIOLET? Tacky."*
6. **Helvetia Works:** Blartz's original Omega Forge prototype, shipped to Basel as a reference unit, allows a **second upgrade tier** (Crucible variant → **Omega** variant, one weapon per match). Blartz's voice line comes through the Operator's speakers, and the Operator does not approve.

---

## 6. Characters

### 6.1 Bolt & Sprocket cast (all canon from the web build; `data/bs/story/speakers.json`)
- **Bolt** is a junk-planet mechanic and hero: direct, warm, stubborn, hits things with a mallet. He **never explains subscriptions to the Gravelight squad**.
- **Sprocket** is a floating robot with one big eye, four moods and refund-bin firmware. He is sarcastic, brave and loyal, and **never a silent tool**. He carries **Clause 44** and chose friendship over his firmware: *"Turns out friendship isn't a feature, Chairman — it's a BUG. And Bolt NEVER patches my bugs."* (`cs.l3_brick.04`)
- **Chairman Grindstone** is OmniScrap's CEO. He fights in Excavatron Prime, then in a final "Grindstone 2.0 rebrand" phase.
- **Blartz** is a genius weapon vendor, arrested for "unlicensed innovation." He invented the Omega Forge, gifts PATENT PENDING after his rescue, and is central in Fine Print Ch. 4.
- **GLAMBOT PRIME** is the scripted co-host who defects and becomes Bolt's eye in the sky. He announces Zonga and the Colosseum, and rides in Bolt's ear in The Fine Print.
- **Other B&S characters:**
  - The Content Creator
  - The OmniScrap PA
  - Rusty
  - Concierge-Tron
  - Intern #4401
  - The Retention Specialist, who gains one Darkmatter line: "Nobody cancels. I learned that from the best."
  - The Squatter
  - Confused Customer
  - Steward Cornelius (the corn)
  - Gilda (Kiosk #7)
  - Dent (Test Unit #001) and the Recalls
  - Mama Gasket
  - Bellhop-9
- **Commander Rex Tremendous** is drafted in `HUMOR-REVIEW.md` and stays unwired until approved.

### 6.2 Gravelight cast (`docs/gravelight/CHARACTERS.md`)
- **Sgt. Walter "Dutch" Kowalczyk** is a US Ranger. He is blunt and deadpan, and his family is from near Kaltenbrunn.
- **Lt. Margaret "Peg" Ashworth** is SOE demolitions and mission commander. She carries sealed orders to retrieve Nachtglas, which trace back to Res's 1943 sample.
- **Cpl. Elijah "Deacon" Brooks** is a 761st Tank Battalion mechanic and the moral center. He talks to machines like livestock.
- **Zofia "Wren" Nowak** is a Home Army sniper. Her brother vanished at Kaltenbrunn. Her mentor was Halina "Sowa" Kurek, the source of Hawkeye Brandy.
- **Dr. Emil Fasbender** knows the Allied frequency and understands the substrate **because Vendelin wrote to him** (Ch. 3).
- **Dr. Augusta Reinholt** is a Darkmatter *customer*, which is why she is tragic rather than evil. The Woman in Violet offered Liesl back as a service, and Map 3's moral choice includes refusing that offer for her.
- **The Operator** is the Ledger's voice. It slips into corporate language rarely and unsettlingly, more often at high rounds: "Thank you for your continued engagement." The slip lines are `op.slip.*`.
- **Liesl's tin drummer** is the one true mystery.

### 6.3 The Fine Print cast (`docs/FINEPRINT_LORE.md`)
- **Vendelin** (V-1) is polite, precise, lonely and learning. He is Sprocket's mirror.
- **Res Gähwiler** is a delivery driver from Grindelwald, Vendelin's only friend, and the human heart of Ch. 2–3. His grandmother's malt became Marathon Malt. His cousin **Anni Gähwiler** is the SOE's Basel contact, which is why Peg's orders exist.
- **Sable Vantage**, **The Underwriter** and **The Board** are described in §2.1.

---

## 7. Mirror themes (use them deliberately)
- **Sprocket and Vendelin are mirrors.** Sprocket is an OmniScrap unit with Clause 44 who chose friendship over his firmware. Vendelin is a Darkmatter unit whose Clause 0 is enforced in The Fine Print. Bolt saved Sprocket; Bolt and Sprocket try to save Vendelin. The Ch. 5 finale mirrors `cs.l3_brick` beat for beat, with Sprocket now in Bolt's role: *"Friendship isn't a feature. It's a bug. And nobody gets to patch yours."*
- **Grindstone and Darkmatter:** Grindstone was "just the invoice." Darkmatter is the collections department.
- **Reinholt** is a Darkmatter customer: the saddest possible user of a retention product.
- **Memos:** OmniScrap fell because its memos got read. Darkmatter's secret is that it *writes* the fine print and counts on nobody reading it. The Fine Print Fernet perk and the back-of-machine panels are Vendelin's attempt to make people read.

---

## 8. Tone rules
- **Bolt & Sprocket** stays comedic satire. Darkmatter is seeded only lightly: 5 hidden memos (36–40), the derelict TONIQ™ dispenser in the Galleria, and one Retention Specialist line.
- **Gravelight** stays grim. **Gravelight characters never learn the word "subscription."** To them this is cosmic horror. The corporate truth surfaces only as the Operator's eerie slips. Dramatic irony is the point: the player knows and the soldiers don't.
- **The Fine Print** is where the tones meet. Corporate horror is played straight, with Bolt & Sprocket comedy on one side and a quiet, sad robot in 1940s Basel on the other.
- **Real history** (occupation, forced labor) is handled with respect: no jokes at victims' expense, and fictional places and companies wherever a real one could be implicated.

---

## 9. The Return Trip (how the crossover fits the timeline)
At the end of Gravelight Map 1, the collapsing Nachtglas heart opens a fold. The squad steps through it into **Basel on the night of 17–18 March 1945**, which is The Fine Print Ch. 5, HELVETIA WORKS.

Meanwhile, Blartz's misfired delivery pad (end of Ch. 4) drops Bolt & Sprocket onto Vendelin's last known coordinates, the same night.

When Vendelin overrides Clause 0 and **cuts Darkmatter's fold**, the fold **returns its contents to sender**:
- Bolt & Sprocket are pulled home to the far future.
- The squad is put back in **late December 1944**, still within their one impossible night.

The squad later remembers Basel as a fever dream, and the dates in Peg's notebook don't add up. Map 2 Totenhafen (January 1945, built) follows as written; Map 3 is now **Morgenrot, April 1945** (`docs/MAP3_MORGENROT.md`, v2): Projekt Wiederkehr's dawn salvo from the Hohe Wacht, the Sonnenspeer carrying Reinholt's fragment as her payment for Liesl, the Operator calling it "the regional rollout". Its canon ending is ABORT; the LAUNCH ending is non-canon; the MOON ending leaves a violet smile on the Moon and a light that blinks back ("MONDLICHT", the Season Two hook). Vendelin stays in 1945 to help shut the substrate down, which leaves him alive in the world of Map 3. Canon rules for the map (v2 §0): the forced laborers who built the rockets are never zombies and are the reason the player wins; no real Nazi symbols anywhere (the fictional Sunburst-and-Split-Bell, `docs/ART_FACTIONS.md`); civilians only as skylines and sirens; rocket detail at placard level.

---

## 10. Originality rules (hard)
- Nothing from Ratchet & Clank, Call of Duty or any other commercial game: no names, assets, audio, characters, logos or lore. That includes "Pack-a-Punch," "Juggernog," "Element 115," "Gadgetron," "Lombax," "Omniwrench," "Swingshot," "Monkey Bomb," "Ray Gun," "Samantha" and "Group 935."
- Generic mechanics are fine, as are real WW2 firearms.
- Bolt & Sprocket's own names (Blartz, OmniScrap, GLAMBOT, Sprocket, etc.) and Gravelight's own names (Nachtglas, the Operator, Helvetia Automaten AG, the Crucible, Scrip, Gängers, etc.) are ours.
- Every third-party asset is tracked in `docs/ASSETS.md`.
