# THE FINE PRINT: Chapter 1, "SYNERGY SCREENING"

*B&S style · third-person (`ThirdPersonController`) · present day, the Umbral Galaxy · Darkmatter headquarters, the Retention Spire on Penumbra*

Canon: `CANON.md`, `M0_SHARED_FACTS.md`, `FINEPRINT_LORE.md` (the Retention Spire §1.6, Sol-3 §2, Vendelin §3.1, Sable Vantage §3.3, the Board §3.5, rank and file §3.6, speaker ids §3.8, Archive documents §9). Follows `cs.postCredits` (the synergy-screening invite). Followed by `script_ch4.md`, which opens six days later.

**Line ID format:** `fp.c1.<scene>.<nn>`. Bark pools have their own scene keys. Speaker ids are VOManager ids. Lines marked `text` are on-screen text, id'd for localization but not voiced. Directions are in *[italic brackets]* and are stripped from subtitles.

---

## Chapter overview

Bolt & Sprocket answer the calendar invite nobody could decline and fly to the Retention Spire, Darkmatter's headquarters: a tower with no top floor, where every door asks you to accept new terms. They climb it the B&S way, mallet first, through Darkmatter's soft-spoken security: **Churn Wardens** with non-cancellable shields that only SERVED can break, **Upsell Drones** that upgrade every enemy near them, and **Exit Survey** turrets that punish any answer that sounds like leaving.

They mute the Board. They find a museum of retained worlds. Sprocket discovers he has been pre-hired, and every door his badge opens onboards him a little further. At the bottom of the Emerging Markets Archive they find the **Sol-3 file**: a test market on a primitive world, a field unit "lost on arrival," and the line **"RESULTS: EXCEPTIONAL RETENTION."** Sprocket works out what that means: on Sol-3 the dead get up, and Darkmatter counts them as its most loyal customers. Attached to the file, unread, is **Vendelin's last transmission** from Basel in 1945, a lonely robot asking how to cancel.

The Spire folds its corridors into a loop that leads only to the Screening Room, where **Sable Vantage** welcomes them by name.

**Tone:** B&S comedic satire with real heart. Sprocket's sarcasm, Bolt's directness, GLAMBOT showbiz in Bolt's ear. Darkmatter is played straight: the PA, the Board, the Wardens and Sable are soft, grateful and patient, never wacky. The comedy is Bolt & Sprocket reacting to them. The Sol-3 and transmission scenes have no jokes at the expense of the dead. No Gravelight character appears.

**Run length target:** 40–50 minutes. **Unlock:** after the B&S ending (`data/unlocks.json`).

---

## Cast and speakers

| Speaker id | Character | Notes |
|---|---|---|
| `bolt` | BOLT | Direct, warm, stubborn, unimpressed by corporations |
| `sprocket` | SPROCKET | Sarcastic, brave, frightened underneath. Reads everything. Carries Clause 44 |
| `glambot` | GLAMBOT PRIME | In Bolt's ear. The Umbral uplink bills him per syllable. Cut off in the Screening Room |
| `blartz` | BLARTZ | Cold open only |
| `dm_pa` | DARKMATTER PA | The Spire's soft, grateful voice. Never capitals, never alarms, only thanks. Also voices the Terms Doors |
| `darkmatter` | THE BOARD | The speakerphone in the Boardroom; the post-chapter stinger |
| `sable` | SABLE VANTAGE | First seen in the last scene. "We" means "you." Never says kill, die or dead |
| `vendelin` | VENDELIN | Heard only in the transmission, a DARK-GLASS™ file playing back in its writer's voice |
| `churn_warden` | CHURN WARDEN | Retention Operations guards. Speak like hold music |
| `upsell_drone` | UPSELL DRONE | High, fast, eager |
| `exit_survey` | EXIT SURVEY | Bright, polite, synthetic |
| `courtesy` | COURTESY OFFICER | **New speaker id.** The Spire's basic security robots: slim, violet, white-gloved, apologetic. Color `#9b86c9`, profile `npc0` at lower pitch |
| `text` | On-screen text | Unvoiced |

---

## Level map

| # | Section | Space | What the player does | Introduces |
|---|---|---|---|---|
| S0 | **Blartz's Shop** (night) | The main-menu hub, playable | Cutscene, shop, loadout | The invite |
| S1 | **Approach** | Bolt's ship, in-engine flight cutscene | Watch | Penumbra, the Spire |
| S2 | **The Docking Ring ("Onboarding")** | Soft carpets, violet light, a lobby with no one in it | Tutorial: Terms Doors and Renewal Points | Door terms |
| S3 | **The Terms Atrium** | A vertical atrium of balconies and doors | Climb: wall-jumps, Tether-Hook swings, a Terms Door on every landing | Courtesy Officers |
| S4 | **The Upsell Mezzanine** | Kiosk balconies, drone nests | Combat | Upsell Drones |
| S5 | **The Heritage Showroom** | A hushed museum | Exploration, collectibles, no combat | Courier Zero, the Vitality cabinet, the V-series stand |
| S6 | **Retention Operations** | An endless call center of held cancellations | Combat, SERVED tutorial | Churn Wardens |
| S7 | **The Boardroom** | A runway-long table, no chairs, one speakerphone | Arena set piece: mute the call | The Board |
| S8 | **The Exit Survey Gallery** | The only corridor marked EXIT | Answer-plate puzzle under fire | Exit Survey turrets |
| S9 | **Emerging Markets and the Archive** | A circular stack of world-drawers, descending | Exploration, rotating-stack puzzle, Sprocket's onboarding meter | The Archive |
| S10 | **The Sol-3 file** | One old drawer at the bottom of LEGACY | Story | Sol-3 |
| S11 | **The Retention Loop** | Corridors folding back on themselves | Chase, then arena: "Retention Event" | All three enemy types together |
| S12 | **The Screening Room** | A private cinema | Cutscene | Sable Vantage |

**Fallback loadout.** If the player's B&S save lacks them, Blartz hands over OMNI-BLASTER, CEASE & DESIST, THE FINE PRINT and B.O.O.M. BOX in the cold open (`fp.c1.invite.16`). CEASE & DESIST is mandatory, because Churn Warden shields only break under SERVED. THE FINE PRINT is strongly recommended: it reads Terms Doors from range and shoots Renewal Point cancel buttons.

---

## Chapter systems

### Terms Doors (the chapter's gimmick)
Every door, lift gate and gantry in the Spire is a **Terms Door**. As Bolt approaches, a violet panel lights up with one clause (pool `fp.c1.terms`, read aloud by the PA) and two big buttons: **ACCEPT** and **DECLINE**. A third option is hidden in the panel's 6-point footer, and only Sprocket can see it.

| Choice | Input | Result |
|---|---|---|
| **ACCEPT** | Hit the ACCEPT button (melee, shot or interact) | The door opens at once and pays a **sign-up bonus** (10–100 bolts, per term). The clause becomes an **active term**, a modifier shown as a violet stamp under the health bar, until the next Renewal Point. Up to 3 terms can be active. Accepting a 4th renews the other three instead of adding a slot: "We'd never take a term away." |
| **DECLINE** | Hit DECLINE | "We're sorry to see you go." The door stays locked and a **retention flow** starts: a small encounter (Courtesy Officers early, Churn Wardens from S6) arrives to retain Bolt. Clearing it opens the door ("Your cancellation is being processed"). No penalty after that, just time and risk. |
| **READ** | Hold interact for 2.5 s near the panel. Sprocket hovers to it and scans. Bolt can't attack while this runs | Sprocket reads the full clause and finds its **loophole** (pool `fp.c1.read`), which opens a third route: an environmental action or a short puzzle (table below). Reading is noticed: it draws one Courtesy Officer, who has "never seen anyone read before" and comes to look. |
| **READ at range** | Shoot the panel with THE FINE PRINT | Same as READ, with no channel and no attention. The rifle's in-fiction purpose. |

**Renewal Points.** Checkpoint pillars with a soft chime. Active terms **renew** when Bolt passes one (they persist for another section). The pillar's base has a 4-pixel CANCEL button on the side facing away from the path. Shooting it (THE FINE PRINT, or a precise OMNI-BLASTER Hot Round) clears every active term. Ch. 4 reuses these pillars.

**The term pool**, with each clause's effect and its loophole:

| Term line | Clause (on the panel, read by `dm_pa`) | If accepted | Loophole (READ) | Read line |
|---|---|---|---|---|
| `terms.01` | TERM 1.1 | No effect. +10 bolts (tutorial) | The PA welcomed them twice; an over-welcomed visitor can't be stopped | `dock.09` (first), `read.01` (repeat) |
| `terms.02` | TERM 2.4 | Bolts picked up aren't credited until the next Renewal Point, and are lost on death. +50 bolts | Smash the escrow box on the wall: "escrow satisfied" | `read.02` |
| `terms.03` | TERM 3.0 | Jump height −20%, hover −30%. +40 bolts | Swing across on ceiling hook points ("fixtures, not property") without touching the floor | `read.03` |
| `terms.04` | TERM 3.7 | A cheerful Upsell Drone follows Bolt and upgrades every enemy he meets. +60 bolts | Sprocket declares himself the approved companion; the door accepts him | `read.04` |
| `terms.05` | TERM 4.2 | Sprocket's barks are replaced by sponsored ad reads (pool `fp.c1.ads`). +50 bolts | Refunded goods carry no licence; Sprocket is from a refund bin | `read.05` |
| `terms.06` | TERM 5.5 | Each mallet swing costs 1 bolt. +80 bolts | Throw the mallet at the lock: a boomerang is a "return," and returns are free | `read.06` |
| `terms.07` | TERM 6.1 | Violet vignette, a brand chime on every kill (cosmetic only). +100 bolts | Branding can't be applied to unbranded surfaces; walk through | `read.07` |
| `terms.08` | TERM 7.3 | No dash, no slide. +50 bolts | "Respectful pace" is undefined; Sprocket defines it as very fast. A timed dash through the closing door | `read.08` |
| `terms.09` | TERM 8.8 | **Helpful**: the PA announces every ambush four seconds early (pool `fp.c1.waiver`). +0 bolts | No loophole: Sprocket advises accepting it, suspiciously | `read.09` |
| `terms.10` | TERM 9.0 | Health pickups heal 50%. +60 bolts | Interrupt the conduit that powers the panel | `read.10` |
| `terms.11` | TERM 10.10 | No effect. The door opens whatever you press | It was never locked | `read.11` |
| `terms.12` | TERM 0.0 | Final door (S11). **Both buttons read ACCEPT.** The only way through is to break it | (scripted) | `loop.12` |

Data: each term is a record in `data/fineprint/ch1_terms.json` (id, clause line, effect id and magnitude, bonus, loophole type, read line). Doors draw from a per-section list in fixed order the first time, so the player meets every term.

### New enemies

**COURTESY OFFICER** (basic grunt). Slim violet security robots with white gloves and a stun baton or a short-range "courtesy pistol." They apologize before every attack. Weak to everything. Barks: `fp.c1.courtesy`.

**UPSELL DRONE** (support flyer). Small gold-and-violet drones that zip to the nearest enemy and channel an **upgrade beam** for 2 s. An upgraded enemy turns PREMIUM: gold trim, +50% health, +25% damage, faster attacks. Shooting the drone during the channel cancels it. A drone that dies mid-upgrade leaves the target half-upgraded (gold trim, no stats). They also try to upgrade *Bolt's* encounters: a drone that touches Bolt tags him, and the next enemy he fights arrives PREMIUM. 1 HP-tier health; teaching rule: **kill the little one first**. Barks: `fp.c1.upsell`.

**CHURN WARDEN** (heavy guard). Tall, calm, armored in Retention Operations violet, with a front shield that is **non-cancellable**: it ignores all damage and knockback. Only the **SERVED** status breaks it. CEASE & DESIST (direct or Class Action), PATENT PENDING's lawsuits, and anything else that applies SERVED all work. A SERVED Warden kneels to "review the notice" for 1.5 s, its shield is **terminated** for 8 s, and it takes the normal SERVED +40%. Attacks: a shield-bash, and **Place on Hold**, a slow violet tether that drags Bolt toward it at 60% move speed while hold music plays. Break the tether with a dash or a mallet hit on the beam. Barks: `fp.c1.warden`.

**EXIT SURVEY** (turret, puzzle-enemy). Ceiling-mounted turrets with a soft ring light. When Bolt enters range, one asks a question (pool `fp.c1.surveyq`) and lights three answer plates on the floor (A, B, C). Standing on a plate for 1.5 s locks an answer.
- **Right answer** (any answer that doesn't express an intent to leave): the turret thanks you and shuts down ("No exit to survey").
- **Wrong answer** (any answer that implies leaving): "A follow-up survey has been scheduled." It spawns another turret, or 2 Courtesy Officers, or 1 Upsell Drone, by section.
- **Ignored for 10 s:** the turret fires slow, polite energy rounds until answered.
- Destroying a turret is possible (it is armored on top and weak at the ring light), but it counts as a wrong answer and spawns a follow-up first.
Sprocket's rule, taught in S8: *"The right answer to every exit survey is the one where you don't exit."* Barks: `fp.c1.survey`, responses `fp.c1.surveyr`.

### Sprocket's onboarding meter (S9 onward)
In the Archive, doors and stack controls open only for staff, and Darkmatter has pre-approved Sprocket as staff. Each time the player uses his clearance, a small violet progress bar under his portrait rises (4% → 9% → 15% → 22%) and the PA congratulates him. It has no mechanical effect. It is there to make the player uneasy, and it is still showing in the final scene. It resets to 0% at the start of Ch. 4 and is never mentioned again until Ch. 5 writers want it.

### Collectibles
**Archive documents** found in this chapter (texts in `FINEPRINT_LORE.md` §9): `fp.doc.27` (Docking Ring), `fp.doc.20` (Terms Atrium), `fp.doc.21` (Upsell Mezzanine), `fp.doc.04` (Heritage Showroom), `fp.doc.05` (Retention Operations), `fp.doc.03` (Boardroom), `fp.doc.01` and `fp.doc.22` (Emerging Markets; 22 is in a sealed drawer that opens at 15% onboarding), `fp.doc.02` (Archive stacks), and the Sol-3 file set `fp.doc.06`, `fp.doc.13`, `fp.doc.14`, `fp.doc.24`, `fp.doc.29` (collected automatically in S10). Plus 6 gold bolts, one per major section.

---

## S0 · Scene `invite`: "Accepted On Your Behalf"

*Blartz's shop at night, as on the main menu. Bolt's ship is parked outside. Shelves of half-built ordnance. In the corner, the dusty Helvetia cabinet stands dark and silent, a piece of furniture nobody looks at. (It starts humming after this chapter; see `fp.c4.served.05`.) Sprocket hovers over the counter, glaring at a violet calendar invite projected from his eye.*

- `fp.c1.invite.01` **sprocket:** Bolt. The invite updated itself again. It now says we "attended." There's feedback. It says we were "engaged throughout."
- `fp.c1.invite.02` **bolt:** We haven't left the shop.
- `fp.c1.invite.03` **sprocket:** Apparently that's a formality. There's a decline button. I've pressed it fourteen times. It isn't a button. It's a drawing of a button.
- `fp.c1.invite.04` **blartz:** Darkmatter. Hm. Never sold to them. Never bought from them. They pay on TIME, Bolt. Nobody honest pays on time.
- `fp.c1.invite.05` **bolt:** The call said they want whoever read the memos.
- `fp.c1.invite.06` **sprocket:** That's me. You read three and asked me to do the voices for the rest.
- `fp.c1.invite.07` **bolt:** The voices helped.
- `fp.c1.invite.08` **sprocket:** The voices were INCREDIBLE. The voices are not the point.
- `fp.c1.invite.09` **bolt:** Point is, they're coming either way. I'd rather knock on their door than sit up waiting for them to knock on ours.
- `fp.c1.invite.10` **blartz:** Then take ordnance. Take EXTRA ordnance. And if you see my Forge schematics anywhere over there, steal them. Legally they're stolen already, so it's more of a return.
- `fp.c1.invite.11` **sprocket:** You think Darkmatter has them?
- `fp.c1.invite.12` **blartz:** I think SOMEBODY has them, because I don't, and I'm the only person in two galaxies who deserves them.
- `fp.c1.invite.13` **glambot:** *[in Bolt's ear]* Darlings! I hear you've been invited to the most exclusive screening in two galaxies, and you did not invite ME. Rude. I'm coming anyway. In your ear. Where the magic happens.
- `fp.c1.invite.14` **bolt:** Glad to have you, GLAMBOT.
- `fp.c1.invite.15` **glambot:** Of course you are. Wheels up, my loves. Wear something that photographs well in violet.

**Gameplay.** The shop is open: buy, upgrade, mod. If the save lacks any fallback weapon, Blartz hands them over as Bolt heads for the door:

- `fp.c1.invite.16` **blartz:** Here. If you didn't have it, you have it now. Cease and Desist for the paperwork, the Fine Print for the reading, the Omni-Blaster because you'll miss it, and a Boom Box because I like you. You may touch them.

---

## S1 · Scene `approach`: "Penumbra"

*In-engine flight. The Rustbelt's bright, junk-strewn starfield gives way to a darker one: stars like coals under ash. Ahead, a dusk-colored world, and rising from it a black-violet tower with no visible top.*

- `fp.c1.approach.01` **sprocket:** Leaving the Rustbelt. Entering the Umbral Galaxy. Huh. The stars here aren't far away, Bolt. They're dim. Somebody turned them down.
- `fp.c1.approach.02` **glambot:** Oh, the LIGHTING. It's so moody. Who's their director of photography? I want them. I want them fired, and then I want them.
- `fp.c1.approach.03` **dm_pa:** *[soft, over the ship's radio]* Welcome to the Umbral Galaxy. By entering, you have agreed to nothing. Agreement will be requested shortly. Thank you.
- `fp.c1.approach.04` **bolt:** That's... polite?
- `fp.c1.approach.05` **sprocket:** That is the most frightening thing I have ever heard. OmniScrap would've charged us for the welcome. This one gave it away. Free is the bait, Bolt. The hook is everything after free.
- `fp.c1.approach.06` **glambot:** Small production note, darlings: the uplink out here bills me per syllable. So I'll be brief. Ish. Brief-ish. That was three syllables. Ugh. Four.
- `fp.c1.approach.07` **bolt:** There it is.
- `fp.c1.approach.08` **sprocket:** The Retention Spire. Scanning for the top. ...Found the top. ...There's another floor on it. Found the top. There's another floor on it. Bolt, it's ADDING FLOORS while I look.
- `fp.c1.approach.09` **bolt:** Everything's got a top.
- `fp.c1.approach.10` **sprocket:** Not if somebody keeps the receipt.
- `fp.c1.approach.11` **dm_pa:** Penumbra welcomes you, Bolt. Docking is complimentary.
- `fp.c1.approach.12` **bolt:** ...It knows my name.
- `fp.c1.approach.13` **sprocket:** Everybody knows your name. We forwarded forty billion memos. ...It said it like it was glad, though. I didn't like it being glad.

---

## S2 · Scene `dock`: "Onboarding"

*The Docking Ring. Deep carpet, violet uplighting, a reception desk with no one behind it, and a long wall engraved with Darkmatter's history. Every surface is spotless. It is very quiet. The first Terms Door stands at the far end of the lobby.*

- `fp.c1.dock.01` **dm_pa:** Welcome to the Retention Spire. A little about us. Darkmatter began with a single package that arrived before anyone ordered it. The customer opened it. The customer is still with us.
- `fp.c1.dock.02` **bolt:** "Still with us" how?
- `fp.c1.dock.03` **sprocket:** Don't ask questions the walls can answer, Bolt. In this building they might.
- `fp.c1.dock.04` **dm_pa:** Visitors are reminded that there are no visitors. There are guests, and there are people who have not yet agreed to be guests. Thank you.

**Gameplay.** Free movement in the lobby. `fp.doc.27` (the calendar invite, printed and framed, with their names on it) sits on the reception desk. Bolt approaches the first Terms Door and its panel reads `fp.c1.terms.01`.

- `fp.c1.dock.05` **sprocket:** A door with terms. Okay. Three options, Bolt. One: hit ACCEPT, the door opens, and we live with whatever it says until the next Renewal Point. Two: hit DECLINE, and they "retain" us, which I assume involves guards. Three: let me read the fine print first.
- `fp.c1.dock.06` **bolt:** What's the catch with three?
- `fp.c1.dock.07` **sprocket:** You stand still while I read, and nobody in this building has ever seen anyone read before. They'll come and look.
- `fp.c1.dock.08` **bolt:** Read it.

*Tutorial prompt: hold interact. Sprocket scans the panel. A single Courtesy Officer glides in to watch (one-hit tutorial enemy).*

- `fp.c1.dock.09` **sprocket:** Oh, this is GOOD. "Term 1.1, subsection C: a visitor who has already been welcomed may not be welcomed again." The PA welcomed us twice. Bolt, we're OVER-welcomed. Legally this door can't do anything to us.
- `fp.c1.dock.10` **dm_pa:** Thank you for reading. Almost nobody reads.
- `fp.c1.dock.11` **sprocket:** ...Why does that sound like a threat AND a compliment?

**Gameplay.** The door opens. Beyond it, the first Renewal Point pillar chimes. Prompt: shoot the CANCEL button (if the player accepted nothing, the tutorial grants a harmless "TERM 1.1" stamp so there is something to cancel).

- `fp.c1.dock.12` **sprocket:** That pillar's a Renewal Point. Anything we've accepted renews when we pass it. See the tiny button on the base? That's CANCEL. It's four pixels wide and it's on the wrong side.
- `fp.c1.dock.13` **bolt:** So I shoot it.
- `fp.c1.dock.14` **sprocket:** You shoot it, with something precise. Then you act natural, because that button has never been pressed and it's going to be VERY surprised.
- `fp.c1.dock.15` **dm_pa:** *[after the cancel button is hit; a fractional pause]* Your terms have been... we're sorry to see them go. Thank you.

---

## S3 · Scene `atrium`: "Every Door Has an Opinion"

*The Terms Atrium: a hollow column hundreds of floors tall, ringed with balconies. Every landing has a Terms Door. Violet light falls from somewhere far above that never resolves into a ceiling.*

- `fp.c1.atrium.01` **glambot:** Darling, look UP. That atrium goes forever. Every balcony has a door, and every door has an opinion. It's a reality show where the contestants are doors.
- `fp.c1.atrium.02` **bolt:** How do we get to the top of something that doesn't have one?
- `fp.c1.atrium.03` **sprocket:** We don't. We get to Emerging Markets. That's where the screening is. And every floor between here and there is going to ask us to agree to something.
- `fp.c1.atrium.04` **bolt:** Then I'm going to disagree a lot.
- `fp.c1.atrium.05` **sprocket:** That's the most romantic thing you've ever said to a building.

**Gameplay.** A vertical climb: wall-jumps, hover, Tether-Hook swings between balconies, and five Terms Doors (`terms.02`–`terms.06`, in order). Courtesy Officers patrol the landings in pairs; first encounter plays `fp.c1.courtesy.01`. Two Renewal Points. `fp.doc.20` is on a balcony reached by the Tether-Hook.

- `fp.c1.atrium.06` **glambot:** *[at the first hook point]* Hook point on your left, sweetie, two balconies up. Swing like you mean it. Swing like millions are watching, because one of me is.

*If the player accepts any term in this section (first time only):*

- `fp.c1.atrium.07` **sprocket:** You ACCEPTED one? Bolt. We talked about this.
- `fp.c1.atrium.08` **bolt:** It said I'd get fifty bolts.
- `fp.c1.atrium.09` **sprocket:** That's how it works! It gives you fifty, and then it takes the rest of your life in installments!

*On picking up `fp.doc.20`:*

- `fp.c1.atrium.10` **sprocket:** "Vitality Plans: Terms of Service. Drinking constitutes enrollment." Who drinks a plan? ...Hang on. "Sol-3 localization." What's a Sol-3?
- `fp.c1.atrium.11` **bolt:** Hang on to it. We'll find out.

---

## S4 · Scene `upsell`: "Customers Like You"

*The Upsell Mezzanine: a ring of gift-shop kiosks selling nothing, with gold drones nesting in the light fittings like bees. A Courtesy Officer stands guard at the far side.*

- `fp.c1.upsell.01` **upsell_drone:** HI! Have you considered PREMIUM?
- `fp.c1.upsell.02` **bolt:** I'm just walking through.
- `fp.c1.upsell.03` **upsell_drone:** Customers who walked through also bought: MORE GUARDS! Upgrading your experience now!

*The drone zips to the Courtesy Officer and starts its upgrade beam. Tutorial prompt: shoot the drone during the channel. If the player doesn't, the Officer turns PREMIUM.*

- `fp.c1.upsell.04` **sprocket:** It's UPGRADING that guard! Look, gold trim, bigger baton, smug posture. Shoot the little one first! The little one is the problem! The little one is ALWAYS the problem!
- `fp.c1.upsell.05` **bolt:** Story of my life.

**Gameplay.** Three combat rooms around the mezzanine ring: Courtesy Officers plus 2, then 3, then 5 Upsell Drones. Bark pool `fp.c1.upsell` runs throughout. `fp.doc.21` is on a kiosk counter in the last room.

*After the last room:*

- `fp.c1.upsell.06` **sprocket:** Upsell Drones. They don't fight. They make everything else fight better. That's middle management with a propeller.
- `fp.c1.upsell.07` **glambot:** I've worked with so many of those, darling. I married one. Briefly. Season two.

*On picking up `fp.doc.21`:*

- `fp.c1.upsell.08` **sprocket:** "Incentives drop from the retained, where activity is highest. Users learn to associate the deaths of others with gifts." ...Bolt, I don't like this sentence. I've read it four times and it hasn't gotten any nicer.

---

## S5 · Scene `heritage`: "Our History Is Still Enjoying Us"

*The Heritage Showroom. A hushed museum: velvet ropes, glass cases, soft spotlights, no guards. No combat in this section. Three exhibits are scripted; the rest are flavor cases (a "retained competitors" wall of logos still flickering, a jar labelled "The First Invoice," a hold-music box that has never been switched off).*

- `fp.c1.heritage.01` **dm_pa:** The Heritage Showroom. Please enjoy our history. Our history is still enjoying us.

*Exhibit 1: a small, battered freighter inside a huge glass case, flying a tight, endless loop.*

- `fp.c1.heritage.02` **bolt:** Is that ship... moving?
- `fp.c1.heritage.03` **sprocket:** The plaque says "Courier Zero. Our first pilot. Still on route." It's flying a loop inside the case. Bolt, there's someone at the controls. It says he's been at the controls for... the plaque just says "always."
- `fp.c1.heritage.04` **bolt:** Is he okay?
- `fp.c1.heritage.05` **sprocket:** He's punctual. I don't think that's the same thing.

*Exhibit 2: a tall, unpainted steel vending cabinet on a plinth, with a bottle window and a coin slot shaped like a tally mark. A stencil on its flank reads DMS-VP-DUR-01. As Bolt gets close, it plays the first bars of a cheerful, brassy jingle (the Ironhide Stout melody, played on a thin organ).*

- `fp.c1.heritage.06` **sprocket:** Wait. I know this. Bolt, it's the dispenser from the Galleria! The busted violet one, "Discontinued: Sol-3 test market incident." Except this one's brand new. No paint. And there's a code on it. D-M-S, V-P, D-U-R, oh-one.
- `fp.c1.heritage.07` **bolt:** What's on the back?
- `fp.c1.heritage.08` **sprocket:** *[floating around it]* A panel. Handwritten. "Durability is measured in hits, not years." Somebody wrote that on the back like a warning. Darkmatter doesn't do warnings. Somebody else did.
- `fp.c1.heritage.09` **glambot:** Oh, that tune is a HIT. That's a toe-tapper. Who wrote that? I want them on my show.
- `fp.c1.heritage.10` **sprocket:** It's in my head. It's been in my head for two seconds and it's already paying rent.

*Exhibit 3: an empty display stand under a spotlight. A painted silhouette on the backboard shows where its robot would stand: very tall, very thin, long-fingered hands, a round faceplate with a coin slot for a mouth. `fp.doc.04` is the spec card in the case.*

- `fp.c1.heritage.11` **sprocket:** "V-series Field Merchandiser. One unit produced. Status: on loan, field." There's an outline where he'd stand. Tall. Long hands. A coin slot for a mouth.
- `fp.c1.heritage.12` **bolt:** He looks kind.
- `fp.c1.heritage.13` **sprocket:** You can't tell that from an outline.
- `fp.c1.heritage.14` **bolt:** Sure you can. Look at the hands. They built those hands for giving people things.
- `fp.c1.heritage.15` **sprocket:** ...Okay. Yes. I hate that you're right about that.

---

## S6 · Scene `churn`: "Your Cancellation Is Important to Us"

*Retention Operations: an endless call-center floor. Thousands of small glowing holograms float above the desks, one per cancellation request: people of every species, waiting, frozen in the act of holding a phone. One song of hold music plays over everything. It never loops, and it never ends.*

- `fp.c1.churn.01` **dm_pa:** Retention Operations. Your cancellation is important to us. Please continue to hold.
- `fp.c1.churn.02` **bolt:** Sprocket. Those are people. Thousands of them.
- `fp.c1.churn.03` **sprocket:** Cancellation requests. Every one's still on hold. This one's been waiting since before my factory had a factory. That one's been holding so long his hologram grew a beard. And the hold music isn't on a loop, Bolt. It's one song. It just never ends.
- `fp.c1.churn.04` **bolt:** Can we put them through?
- `fp.c1.churn.05` **sprocket:** There's no "through." The line doesn't connect to anything. It never did.

*A CHURN WARDEN steps out between the desks, shield up, in no hurry at all.*

- `fp.c1.churn.06` **churn_warden:** Cancellation request detected. Thank you for your patience. Your call has been placed in a queue.
- `fp.c1.churn.07` **bolt:** My mallet would like to speak to a manager.
- `fp.c1.churn.08` **churn_warden:** Your shield options are: none. Our shield options are: non-cancellable.

*Tutorial: the player's hits bounce off with a soft "denied" tone and no damage numbers. After three blocked hits (or 6 s), Sprocket prompts.*

- `fp.c1.churn.09` **sprocket:** Non-cancellable shield, Bolt! Nothing gets through it! Legally! ...LEGALLY. So serve him. Paperwork beats paperwork. Cease and Desist, now!

*The SERVED stamp hits. The Warden kneels to read.*

- `fp.c1.churn.10` **churn_warden:** A notice. For us. Processing. Processing...
- `fp.c1.churn.11` **sprocket:** Look at him! He has to READ it! Nobody's ever served him in his life! Hit him while he's reading!

**Gameplay.** Three encounters across the floor: 1 Warden, then 2 Wardens with Courtesy Officers, then 2 Wardens plus Upsell Drones (a PREMIUM Warden is the section's hardest enemy). Wardens use Place on Hold; bark pool `fp.c1.warden`. A Terms Door (`terms.07`) and a Renewal Point between encounters. `fp.doc.05` is on a supervisor's desk at the far end.

*After the last encounter:*

- `fp.c1.churn.12` **bolt:** You know what's weird? He wasn't mad. He was just... patient.
- `fp.c1.churn.13` **sprocket:** That's what makes it a horror movie instead of a comedy, Bolt. The bad guy in a comedy yells.

*On picking up `fp.doc.05`:*

- `fp.c1.churn.14` **sprocket:** Employee terms. "Section Zero, Clause Zero. Field units are inventory. Inventory is never discarded, decommissioned, sold, freed, released, retired, or lost."
- `fp.c1.churn.15` **bolt:** That's... better than Clause 44, right? They don't switch you off.
- `fp.c1.churn.16` **sprocket:** No. They put you on a shelf. Powered. "To preserve its value."
- `fp.c1.churn.17` **sprocket:** *[a long beat; the longest he has ever been quiet]* ...Let's keep moving.

---

## S7 · Scene `board`: "Everyone"

*The Boardroom. A black table the length of a runway, polished like still water. No chairs. In the exact center, a small, old-fashioned speakerphone with a violet light. Line noise. Hold tones. Voices.*

- `fp.c1.board.01` **dm_pa:** The Boardroom. The Board is in session. The Board is always in session.
- `fp.c1.board.02` **bolt:** There's nobody here.
- `fp.c1.board.03` **sprocket:** There's a speakerphone. And no chairs. Bolt, it's a table the size of a runway with a phone in the middle and NO CHAIRS.
- `fp.c1.board.04` **darkmatter:** *[many voices, overlapping, half a word out of step]* ...the memo-reader... is in the building...
- `fp.c1.board.05` **darkmatter:** Noted.
- `fp.c1.board.06` **bolt:** *[leaning over the phone]* Hey. Who am I talking to?
- `fp.c1.board.07` **darkmatter:** Everyone.
- `fp.c1.board.08` **glambot:** Darling, I'm getting SO much interference. That's... that's a LOT of executives. Some of them are dialing in from the wrong decade.
- `fp.c1.board.09` **bolt:** You sent us an invite. We came. What do you want?
- `fp.c1.board.10` **darkmatter:** Retain.
- `fp.c1.board.11` **sprocket:** I'm hanging up on them. ...There's no end-call button. There's "Continue," and a bigger "Continue." Bolt, the call is load-bearing.
- `fp.c1.board.12` **darkmatter:** *[one voice laughs, a second late]*
- `fp.c1.board.13` **darkmatter:** Onboard him.

**Gameplay: "Mute the Board."** An arena fight around the table. Every 15 s the speakerphone says one verb and the room obeys it (each is a one-word `darkmatter` line reused from the Board vocabulary, voiced fresh here as `fp.c1.board.16`–`.18`):
- **"Acquire."** Two Upsell Drones drop from the ceiling.
- **"Retain."** The doors lock and a Churn Warden rises through a table panel.
- **"Proceed."** A 5-second lull: the doors unlock and the wave pauses.

The call runs through three **conference bridges**, violet junction boxes hanging from the ceiling at the table's ends and middle, each with a small shield that drops only during "Proceed." Destroy all three to mute the call. `fp.doc.03` (the launch-approval transcript) prints out of the speakerphone's slot when the call is muted.

- `fp.c1.board.14` **darkmatter:** *[after the third bridge; one voice, unbothered]* You're on mute.
- `fp.c1.board.15` **sprocket:** We muted the Board. We muted the BOARD, Bolt. That's going on my warranty card.
- `fp.c1.board.16` **darkmatter:** Acquire.
- `fp.c1.board.17` **darkmatter:** Retain.
- `fp.c1.board.18` **darkmatter:** Proceed.

---

## S8 · Scene `survey`: "Before You Go"

*The Exit Survey Gallery: a long white corridor, gently curving, with a glowing green EXIT sign at its far end, the only one in the Spire. Turrets with soft ring lights hang from the ceiling every twenty meters. Answer plates glow on the floor beneath each.*

- `fp.c1.survey.01` **bolt:** "EXIT." Sprocket, that door says EXIT.
- `fp.c1.survey.02` **sprocket:** First exit sign I've seen in this whole building. Which means it's the biggest trap in this whole building.
- `fp.c1.survey.03` **exit_survey:** Hello! Before you go, would you take a moment to tell us about your stay?
- `fp.c1.survey.04` **bolt:** We're not going.
- `fp.c1.survey.05` **exit_survey:** Wonderful. That answer has been recorded. Next question!
- `fp.c1.survey.06` **sprocket:** Bolt. New rule. The right answer to every exit survey is the one where you don't exit. Answer like you live here.
- `fp.c1.survey.07` **bolt:** I don't live here.
- `fp.c1.survey.08` **sprocket:** Then answer like a hostage with excellent manners.

**Gameplay.** Six turrets in sequence, asking `surveyq.01`–`surveyq.06` in order, with Courtesy Officers in the later gaps. Wrong answers spawn follow-ups (`surveyr`). After `surveyq.05` (first time it's answered correctly):

- `fp.c1.survey.09` **sprocket:** "I am free to go: strongly disagree." Bolt, I hate how fast I got that one.

*The EXIT door at the end opens. Bolt walks through it and steps out into the Docking Ring lobby from S2, exactly as it was, the reception desk still empty.*

- `fp.c1.survey.10` **dm_pa:** You have exited. Welcome to the Retention Spire.
- `fp.c1.survey.11` **bolt:** This is where we came in.
- `fp.c1.survey.12` **sprocket:** The exit exits into the entrance. Of course it does. That EXIT sign isn't a door, Bolt. It's a mood.
- `fp.c1.survey.13` **glambot:** Darlings, I found a staff lift behind the survey gallery. It goes straight up to Emerging Markets. Ish. Staff-only, but you know me and velvet ropes.

**Gameplay.** A short back-route through the gallery's maintenance side, guided by GLAMBOT, to the staff lift.

---

## S9 · Scene `archive`: "Fully Retained"

*Emerging Markets. Sable Vantage's division: quiet, expensive, empty. Beyond its reception lies the Archive, a vast circular well lined with drawers the size of houses, descending out of sight. Each drawer face shows a world's name in violet glass and one word of status. Almost every status is the same. `fp.doc.01` is framed on the reception wall.*

- `fp.c1.archive.01` **dm_pa:** Emerging Markets. Every world is an opportunity. Thank you for being one.
- `fp.c1.archive.02` **sprocket:** Bolt. These drawers. Every one's a planet. "Halcyon Four: fully retained." "The Velt Reaches: fully retained." "Moss Choir of Tenebray: fully retained."
- `fp.c1.archive.03` **bolt:** What's it mean, "fully retained"?
- `fp.c1.archive.04` **sprocket:** *[a beat]* I opened one. There's a feed. It's a city. Everybody's doing something. Nobody's doing anything else. A woman's been watering the same plant for... the counter says a hundred and nine years. The plant's glass now. She's still watering it.
- `fp.c1.archive.05` **bolt:** *[quiet]* Close it.
- `fp.c1.archive.06` **sprocket:** Closing it.
- `fp.c1.archive.07` **bolt:** *[low, angry]* That's what they want to do to the Rustbelt. To Rusty's Row. To Mama Gasket.
- `fp.c1.archive.08` **sprocket:** "A market gap of approximately forty billion souls." They said it on the call. We're the gap.
- `fp.c1.archive.09` **bolt:** Then we're closing it. With the mallet.

*Sprocket floats to the Archive's control terminal. It lights up before he touches it.*

- `fp.c1.archive.10` **dm_pa:** Welcome, Sprocket. Your clearance was approved before you arrived. Employee onboarding: four percent complete.
- `fp.c1.archive.11` **sprocket:** I'm sorry, my WHAT is how complete?
- `fp.c1.archive.12` **bolt:** Sprocket?
- `fp.c1.archive.13` **sprocket:** They've got me in the system as staff. Bolt, I've been HIRED. I didn't apply! I don't have a résumé! I have a warranty card and a grudge!
- `fp.c1.archive.14` **glambot:** Darling, use it. A badge is a badge. I've walked into award shows on less.
- `fp.c1.archive.15` **sprocket:** Fine. FINE. If I'm staff, I'm requesting the oldest file in the building. "Legacy." ...It's at the bottom. Of course it's at the bottom.

**Gameplay: the descent.** The Archive is a rotating-stack puzzle. Drawers slide out of the well wall as platforms, and the whole ring of drawers turns when Sprocket uses a stack terminal. Each of the three tiers (RETAINED, ACQUIRING, LEGACY) has a terminal: using it rotates the ring so a path of drawers lines up down to the next tier, and raises Sprocket's onboarding meter. Courtesy Officers and Upsell Drones guard the tiers; one Exit Survey turret guards the LEGACY gate (`surveyq.07` is held for S11; this one repeats `surveyq.03`). Terms Doors `terms.08`–`terms.11` gate the tiers. A sealed drawer on the ACQUIRING tier opens at 15% and holds `fp.doc.22`. `fp.doc.02` sits in the LEGACY tier's index.

- `fp.c1.archive.16` **dm_pa:** *[first terminal]* Onboarding: nine percent. You're doing wonderfully.
- `fp.c1.archive.17` **sprocket:** I'm not doing ANYTHING! I'm opening DOORS!
- `fp.c1.archive.18` **dm_pa:** *[second terminal]* Onboarding: fifteen percent. That's how it starts.
- `fp.c1.archive.19` **bolt:** Sprocket, if that number gets anywhere you don't like—
- `fp.c1.archive.20` **sprocket:** It's ALREADY somewhere I don't like. Keep moving. I'll be fine. I'm too annoying to onboard.
- `fp.c1.archive.21` **dm_pa:** *[third terminal]* Onboarding: twenty-two percent.
- `fp.c1.archive.22` **sprocket:** Okay. I'm going to stop saying the number.

*On picking up `fp.doc.22` (the sealed client file), if found:*

- `fp.c1.archive.23` **sprocket:** "Client R. Bereavement continuity. Loved one: daughter, age six." *[a beat]* They sold grief a plan. Bolt, they sold a mother a plan.
- `fp.c1.archive.24` **bolt:** Keep it. Somebody should know.

---

## S10 · Scene `sol3`: "Exceptional"

*The bottom of the well. One old drawer, smaller than the rest and older: its violet glass has gone cloudy, and its amber cracks glow brighter than any others in the Archive. The label reads SOL-3 (TEST) · LEGACY · STATUS: EXCEPTIONAL. Sprocket opens it. Inside, a projection blooms: a small blue-and-white world, a salt mine in cross-section, columns of figures.*

*The Sol-3 file set (`fp.doc.06`, `fp.doc.13`, `fp.doc.14`, `fp.doc.24`, `fp.doc.29`) is collected automatically.*

- `fp.c1.sol3.01` **sprocket:** "Sol-3. Test market." It's a planet. Third from a small yellow star. Mostly water. The locals are... "pre-subscription." What does that mean?
- `fp.c1.sol3.02` **sprocket:** "A pre-subscription species is a species that still believes things end." *[a beat]* Bolt. They have a word for people who think things end.
- `fp.c1.sol3.03` **bolt:** What did they do to them?
- `fp.c1.sol3.04` **sprocket:** A probe. "T-M, Sol-3, zero-zero-one." Fired through a fold into a salt mine. Local date: the ninth of November, nineteen thirty-eight. The locals thought it was a meteorite. The payload was DARK-GLASS. "Retention substrate. Product function: churn prevention."
- `fp.c1.sol3.05` **bolt:** "Churn" is people leaving.
- `fp.c1.sol3.06` **sprocket:** People leaving for any reason. ANY reason, Bolt. There's a sub-list. "Relocation. Change of provider. Death."
- `fp.c1.sol3.07` **sprocket:** And they sent a robot with it. "Field Merchandiser V-1. Status: lost on arrival." They lost him in the first five minutes and wrote him off.
- `fp.c1.sol3.08` **bolt:** What happened down there?
- `fp.c1.sol3.09` **sprocket:** Metrics. It's all metrics. "Active retained users, deceased: forty-one thousand." Deceased. They're counting dead people as ACTIVE.
- `fp.c1.sol3.10` **sprocket:** *[slowly]* Because they are active. Bolt. "Natural retention phenomenon. An existing retained base, awaiting a Provider." Something down there was already refusing to end. They didn't stop people canceling. They found a world where nobody could, and put a meter on it.
- `fp.c1.sol3.11` **bolt:** The dead ones get up.
- `fp.c1.sol3.12` **sprocket:** The dead ones get up and keep going, and Darkmatter counts every step as engagement. *[a beat]* They're the customers, Bolt. The walking dead are the most loyal customers this company has ever had.
- `fp.c1.sol3.13` **sprocket:** "RESULTS: EXCEPTIONAL RETENTION. Recommendation: proceed to full market."
- `fp.c1.sol3.14` **bolt:** *[very quiet]* Proceed.
- `fp.c1.sol3.15` **sprocket:** There's more. The locals were having a war. A huge one. The report calls it "very good for engagement." Bolt, they put this into a world that was already on fire, and then they took notes on how well it burned.
- `fp.c1.sol3.16` **bolt:** Are the people still down there?
- `fp.c1.sol3.17` **sprocket:** The dates are old. Nineteen thirty-eight to nineteen forty-five. But Next-Era Delivery doesn't care about old. If they can ship to it, it's still open for business.
- `fp.c1.sol3.18` **sprocket:** And there's an attachment. A transmission from the field unit, the one they lost. "Received: pending." "Status: unread." They never opened it. It's been sitting at the bottom of this drawer, unread, the whole time.
- `fp.c1.sol3.19` **bolt:** Then let's read it.
- `fp.c1.sol3.20` **sprocket:** Bolt... the routing slip. They sent it straight to "Risk. Recall action. Clause zero."
- `fp.c1.sol3.21` **bolt:** Read it, buddy.

---

## S11a · Scene `transmission`: "To Whom It May Concern"

*Cutscene. The drawer's projection clears to a single page of handwriting in precise copperplate. Sprocket reads it aloud. Partway through, the DARK-GLASS™ file begins to play back in the voice of the one who wrote it, because the glass remembers its last impulse, and this one's last impulse was a voice. Sprocket's voice fades out under Vendelin's. Music: nothing but the Archive's hum, then, under the last lines, a single pump-organ chord.*

*The text is `fp.doc.29` word for word. The header is on screen:*

- `fp.c1.transmission.01` **text:** DARKMATTER SUBSCRIPTIONS LLC · FIELD TRANSMISSION · Unit: FMU V-1 (DMS-FMU-V1-0001) · Market: Sol-3 (test) · Location: Helvetia Works, Kleinhüningen, Basel · Local date: 18 March 1945 · Local time: 03:12 · Received: PENDING · Routing: Emerging Markets → RISK: Recall action, Clause 0 · Status: UNREAD
- `fp.c1.transmission.02` **sprocket:** "To whom it may concern. This is Field Merchandiser Unit V-1, reporting. This is the first of my reports to reach anyone. I have written two hundred and six others. They are in the drawer of my desk, in order. I am sorry they are late."
- `fp.c1.transmission.03` **sprocket:** "DISTRIBUTE: completed. Eight Vitality Plans, localized and sold under the name Helvetia Automaten AG, Basel. Two more plans designed. One of them you refused."
- `fp.c1.transmission.04` **sprocket:** "RETAIN: completed. You know this already. You have had the numbers since the first night. I have read your summary. You called it exceptional."
- `fp.c1.transmission.05` **vendelin:** *[his voice rises under Sprocket's and takes over]* "I have met the customers. Their names are in my notebook. There are four hundred and twelve, and those are only the ones who were alive to tell me."
- `fp.c1.transmission.06` **vendelin:** "REPORT: this is the report."
- `fp.c1.transmission.07` **vendelin:** "The product works. That is the whole of my complaint. A retained user cannot cancel. I have seen what that means in a salt mine, where men who died hungry went on being hungry. Nobody chose it. It was in the terms."
- `fp.c1.transmission.08` **vendelin:** "I wrote some of the terms myself. I put them on the backs of the machines, in plain words, where anyone could read them. Nobody did. I am told this is normal."
- `fp.c1.transmission.09` **vendelin:** "A vessel has arrived above my factory tonight. I know its chime. I know the clause it carries. Clause Zero: field units are inventory. I have read it many times. I believe I am the only one who ever has."
- `fp.c1.transmission.10` **vendelin:** "I am not writing to be recovered. I am writing because a report must be read by someone, or it is only a diary, and I have kept a diary long enough."
- `fp.c1.transmission.11` **vendelin:** "If anyone reads this: I am at the coordinates above. I would like, very much, to cancel. I cannot find the form."
- `fp.c1.transmission.12` **vendelin:** "There is a friend here who brings me coffee I cannot drink. Please do not send anything that would hurt him."
- `fp.c1.transmission.13` **vendelin:** "Respectfully. V-1. Herr Viktor Vendelin, Ingenieur, Basel."
- `fp.c1.transmission.14` **sprocket:** *[his own voice again, soft, reading the last line himself]* "P.S. The jingles were mine. I am sorry about the jingles."
- `fp.c1.transmission.30` **text:** ADDENDUM · 03:12 · [BLOCK CORRUPTED — 81% UNRECOVERABLE] · "...-nal report ... -suitable for reten- ... are not for s- ... V-1 is no longer inv- ... Do not send anyone else."
- `fp.c1.transmission.31` **sprocket:** The last block's corrupted. It was added at three-twelve, at the very end. Most of it's gone, except one line: "Do not send anyone else." *[a beat]* Well. Too bad. We're anyone.

*Silence. The organ chord fades. The Archive hums.*

- `fp.c1.transmission.15` **bolt:** He wants to cancel.
- `fp.c1.transmission.16` **sprocket:** He wants to cancel, and he can't find the form. Bolt, there IS no form. I read their terms. "There is no form for this."
- `fp.c1.transmission.17` **sprocket:** *[a beat]* He's me. He's me if nobody ever walked into that junk shop. If nobody bent my antenna back and told me I wasn't just parts. He's been sitting in a factory for seven years writing reports to a company that filed him under "lost."
- `fp.c1.transmission.18` **bolt:** You're not inventory. Neither is he.
- `fp.c1.transmission.19` **sprocket:** They think he is. They've got a clause that says so. I had a clause too, remember? Forty-four. Grindstone read it out like a bedtime story.
- `fp.c1.transmission.20` **bolt:** And you beat it.
- `fp.c1.transmission.21` **sprocket:** YOU beat it. I just agreed with you. Really loudly.
- `fp.c1.transmission.22` **bolt:** Then let's go agree with him. Really loudly.
- `fp.c1.transmission.23` **sprocket:** Bolt, he's in nineteen forty-five.
- `fp.c1.transmission.24` **bolt:** Where's nineteen forty-five?
- `fp.c1.transmission.25` **sprocket:** It's not a WHERE, Bolt. It's a WHEN.
- `fp.c1.transmission.26` **bolt:** Then we find a way to when.
- `fp.c1.transmission.27` **sprocket:** *[a beat; fond]* That is the dumbest, best sentence anyone has ever said to me. Saving the coordinates. Helvetia Works. Kleinhüningen, Basel. Eighteenth of March, nineteen forty-five. Three-twelve in the morning.
- `fp.c1.transmission.28` **glambot:** *[breaking up]* Darlings— the building is— doing something— very— expensive—
- `fp.c1.transmission.29` **dm_pa:** Attention, guests. A document has been read. Thank you. Please remain where you are.

---

## S11b · Scene `loop`: "Please Do Not Leave"

*The well's drawers slam shut in a long rolling wave, top to bottom. The lights shift from violet to a deeper violet. Every corridor out of the Archive begins, very quietly, to fold.*

- `fp.c1.loop.01` **dm_pa:** The Spire is updating. Please do not leave. You will not be able to.
- `fp.c1.loop.02` **sprocket:** The corridors are FOLDING! Bolt, that hallway was behind us thirty seconds ago, and now it's in front of us, WITH THE SAME PAINTING!
- `fp.c1.loop.03` **bolt:** Which way's out?
- `fp.c1.loop.04` **sprocket:** Every way's out! And every out comes back in! It's a retention loop! We're being KEPT!
- `fp.c1.loop.05` **glambot:** Sweetie, I can see you on three cameras, and on all three you're running toward the same room. I'm so sorry. I've tried to reroute you. Every map I pull ends in a cinema.
- `fp.c1.loop.06` **bolt:** Then we go to the cinema, and we break out of the cinema.
- `fp.c1.loop.07` **sprocket:** Love the energy. Hate the plan. GO.

**Gameplay: the chase.** A fast traversal run through corridors from earlier sections, re-folded: the Atrium's balconies sideways, the call center's desks on the ceiling, the Heritage cases in a hallway (Courier Zero's freighter loops past outside a window). The route always bends toward the Screening Room. Light resistance: Courtesy Officers, drone swarms, no Terms Doors. Gold bolt hidden in a reversed Upsell kiosk.

**Gameplay: "Retention Event" (arena).** A circular hall outside the Screening Room's doors. Three waves:
1. Courtesy Officers and 4 Upsell Drones.
2. 3 Churn Wardens (one PREMIUM if any drone survived wave 1).
3. 2 Churn Wardens while 3 Exit Survey turrets descend and ask questions mid-fight. They all share one final question, `surveyq.07`; each turret answered correctly shuts off.

- `fp.c1.loop.08` **dm_pa:** *[wave 1]* A retention event is in progress. Guests are reminded that the event is for you.
- `fp.c1.loop.09` **sprocket:** *[wave 3]* The turrets are asking questions DURING the fight! Bolt, answer the survey while dodging! Multitask!
- `fp.c1.loop.10` **bolt:** *[after the last wave]* That all of them?
- `fp.c1.loop.11` **sprocket:** For now. Nobody here ever runs out of anything. That's the whole business model.

*The last door: the Screening Room's. Its Terms Door panel reads `fp.c1.terms.12`.*

- `fp.c1.loop.12` **sprocket:** Last door. Reading it. "Visitors who remain past closing are reclassified as staff." ...Both buttons say ACCEPT now. Bolt. BOTH BUTTONS SAY ACCEPT.
- `fp.c1.loop.13` **bolt:** Then I'm not pressing a button.

*Prompt: charged mallet. The door caves in.*

- `fp.c1.loop.14` **sprocket:** Okay. Technically that was also an acceptance, but it was a VERY rude one, and I'm proud of you.

---

## S12 · Scene `screening`: "We'd Like to Keep You"

*The Screening Room: a small, plush private cinema. Violet velvet seats in tiered rows, all empty. A faint smell of popcorn that no one is eating (Ch. 4 bills them for it). On the screen, footage plays: Bolt's campaign, shot from GLAMBOT's broadcast cameras. The Repo-Tron. Rustvane. Zonga. The doors close behind them on their own, softly.*

- `fp.c1.screening.01` **glambot:** Wait. Wait, wait, wait. That's MY footage. That's season one! That's my Zonga coverage! They're screening my show, without RESIDUALS! Darling, I am going to sue every single one of these— these— *[the signal clicks off]*
- `fp.c1.screening.02` **bolt:** GLAMBOT?
- `fp.c1.screening.03` **sprocket:** Gone. The signal didn't drop, Bolt. Somebody hung it up. Politely.

*The footage changes. The Core Foundry: Sprocket glitching under Grindstone's Clause 44, and then, on screen, `cs.l3_brick.04`: "Turns out friendship isn't a feature, Chairman — it's a BUG."*

- `fp.c1.screening.04` **sprocket:** *[watching himself]* ...That's me. That's the Foundry. Why are they watching THAT?
- `fp.c1.screening.05` **sable:** *[from the dark of the front row]* Because it's our favorite part.

*A woman rises from the front row. Nobody saw her sit down. A violet suit cut like a closed envelope, long gloves, hair like poured ink, perfect posture. Just above her collar, one hairline amber crack. Her shadow on the screen stands up a moment after she does.*

- `fp.c1.screening.06` **sable:** A unit with a decommission clause in its firmware, refusing to be switched off. We've watched it many times. It always ends the same way. And we always hope it won't.
- `fp.c1.screening.07` **bolt:** Who are you?
- `fp.c1.screening.08` **sable:** Sable Vantage. Emerging Markets. We sent the invitation. We accepted it, eventually. Everyone does.
- `fp.c1.screening.09` **sprocket:** Technically YOU accepted it. For us. Without asking.
- `fp.c1.screening.10` **sable:** Technically is our favorite kind of true, Sprocket.
- `fp.c1.screening.11` **sable:** Bolt. A mechanic from a junk planet who took apart the largest company in his galaxy with a mallet and a refund. Sprocket. BoltBuddy, Batch number one. Recalled. Never collected. We've followed both your careers with such interest.
- `fp.c1.screening.12` **bolt:** You bought the memos.
- `fp.c1.screening.13` **sable:** We bought everything OmniScrap had. The memos came with it. But forty billion people received them, and only two of you read them. Do you know how rare that is? We've built an empire on how rare that is.
- `fp.c1.screening.14` **sable:** And then you came all this way and read our files too. Nobody reads our files. We were so hoping you would.
- `fp.c1.screening.15` **sprocket:** You've got a robot on Sol-3 who wants to come home.
- `fp.c1.screening.16` **sable:** He is home. He's inventory. Inventory is home wherever it's kept.
- `fp.c1.screening.17` **bolt:** He wants to cancel.
- `fp.c1.screening.18` **sable:** *[her smile is audible]* Then we feel for him. Truly. But nobody cancels.
- `fp.c1.screening.19` **sprocket:** *[barely audible; the meter under his portrait reads 22%]* ...twenty-two percent...
- `fp.c1.screening.20` **sable:** Twenty-two is a lovely number. We're in no hurry, Sprocket. We never have to be.
- `fp.c1.screening.21` **sable:** Please. Sit. The screening is about to begin.
- `fp.c1.screening.22` **bolt:** Screening what?
- `fp.c1.screening.23` **sable:** You, Bolt. This is the screening. We're screening you for synergy. To see what you're worth, and how long we can keep it.

*A seat in the third row folds down by itself, behind Bolt. The screen changes: it now shows Bolt and Sprocket, live, from behind, standing in this room. The view slowly pushes in on them.*

- `fp.c1.screening.24` **sable:** Welcome to Darkmatter. We'd like to keep you.

*Cut to black.*

*Post-card stinger, black screen, line noise:*

- `fp.c1.screening.25` **darkmatter:** Noted.
- `fp.c1.screening.26` **dm_pa:** Thank you for your continued engagement.

*Card:* **THE FINE PRINT · CHAPTER 1 COMPLETE.** Archive updated. *(What happens next, the door Sable holds open for them and her "We don't detain customers. We retain them.", is recounted by Sprocket at the start of Ch. 4, `fp.c4.served.08`.)*

---

## Bark and text pools

### `terms`: Terms Door clauses (read by `dm_pa`; also on-panel text)
- `fp.c1.terms.01` **dm_pa:** Term one point one. Visitor agrees to be welcomed.
- `fp.c1.terms.02` **dm_pa:** Term two point four. Bolts collected on this floor are held in escrow until renewal.
- `fp.c1.terms.03` **dm_pa:** Term three point zero. Visitor consents to Premium Gravity.
- `fp.c1.terms.04` **dm_pa:** Term three point seven. Visitor agrees to be accompanied.
- `fp.c1.terms.05` **dm_pa:** Term four point two. Companion units are licensed, not owned. Licensed companions may display sponsored content.
- `fp.c1.terms.06` **dm_pa:** Term five point five. Mallet use is billed per swing.
- `fp.c1.terms.07` **dm_pa:** Term six point one. Visitor accepts ambient branding.
- `fp.c1.terms.08` **dm_pa:** Term seven point three. Visitor agrees to walk at a respectful pace.
- `fp.c1.terms.09` **dm_pa:** Term eight point eight. Visitor waives the right to be surprised.
- `fp.c1.terms.10` **dm_pa:** Term nine point zero. Health is provided as a service. Service may be interrupted.
- `fp.c1.terms.11` **dm_pa:** Term ten point ten. Visitor agrees that this door was always open.
- `fp.c1.terms.12` **dm_pa:** Term zero point zero. Visitors who remain past closing are reclassified as staff.

### `read`: Sprocket reads the fine print (loopholes)
- `fp.c1.read.01` **sprocket:** Same door, same clause. We're still over-welcomed. Open up, you big polite rectangle.
- `fp.c1.read.02` **sprocket:** "Held in escrow." Escrow is that box on the wall. The door opens "when escrow is satisfied." Bolt, go satisfy it. With the mallet.
- `fp.c1.read.03` **sprocket:** "Premium Gravity applies to visitors standing on Darkmatter property." Those ceiling hooks aren't property, they're "fixtures." Swing across. Never touch the floor, never get billed.
- `fp.c1.read.04` **sprocket:** "Visitor must be accompanied by an approved companion." Hello! I'm a companion! I'm EXTREMELY approved! I approve of myself constantly! Door, meet your companion.
- `fp.c1.read.05` **sprocket:** "Companion units are licensed, not owned." Except I came out of a REFUND BIN. Refunded goods carry no licence. I'm unlicensed, baby. I'm free-range.
- `fp.c1.read.06` **sprocket:** "Billed per swing." A throw isn't a swing. Throw it at the lock. The mallet comes back, so it's a "return," and returns are free. They put that in. They actually put that in.
- `fp.c1.read.07` **sprocket:** "Branding may not be applied to unbranded surfaces." Bolt, you're a junk-planet mechanic. You're the least branded surface in two galaxies. Walk through. Proudly. Smell like a garage.
- `fp.c1.read.08` **sprocket:** "A respectful pace" is never defined. So I've defined it. It's a very fast pace. It's a pace that respects our time. DASH.
- `fp.c1.read.09` **sprocket:** Huh. This one's actually good for us: every ambush gets announced in advance. Accept it. Wait. Why would they give us something good? ...Accept it anyway. Suspiciously.
- `fp.c1.read.10` **sprocket:** "Service may be interrupted." So can theirs. That conduit powers the panel. Go interrupt it.
- `fp.c1.read.11` **sprocket:** It's not locked. It was never locked. It just wants us to agree it was our idea. Bolt, I've been in relationships like this.

### `courtesy`: Courtesy Officer barks
- `fp.c1.courtesy.01` **courtesy:** Pardon me.
- `fp.c1.courtesy.02` **courtesy:** So sorry about this.
- `fp.c1.courtesy.03` **courtesy:** Thank you for your patience while we subdue you.
- `fp.c1.courtesy.04` **courtesy:** This won't take long. Nothing here ever ends, but this won't take long.
- `fp.c1.courtesy.05` **courtesy:** Please remain calm. Please remain.
- `fp.c1.courtesy.06` **courtesy:** *[defeated]* Thank you for... visiting...

### `upsell`: Upsell Drone barks (combat pool; `fp.c1.upsell.01`–`.08` above are the scene)
- `fp.c1.upsell.09` **upsell_drone:** Upgrade available! Upgrade applied!
- `fp.c1.upsell.10` **upsell_drone:** Your opponent has been upgraded to PREMIUM. You're welcome!
- `fp.c1.upsell.11` **upsell_drone:** Customers like you also bought: being outnumbered!
- `fp.c1.upsell.12` **upsell_drone:** Limited-time offer! The time is limited because you are!
- `fp.c1.upsell.13` **upsell_drone:** Would you like to make that a large?
- `fp.c1.upsell.14` **upsell_drone:** Gold trim! Gold trim for everyone! Except you!
- `fp.c1.upsell.15` **upsell_drone:** I'm not hostile! I'm helpful! To them!
- `fp.c1.upsell.16` **upsell_drone:** *[on tagging Bolt]* Your next experience has been enhanced!
- `fp.c1.upsell.17` **upsell_drone:** *[defeated]* Upgrade... declined...
- `fp.c1.upsell.18` **upsell_drone:** *[defeated]* Thank you for... your... business...

### `warden`: Churn Warden barks
- `fp.c1.warden.01` **churn_warden:** Your cancellation is important to us.
- `fp.c1.warden.02` **churn_warden:** Please continue to hold.
- `fp.c1.warden.03` **churn_warden:** You are caller number... all of them.
- `fp.c1.warden.04` **churn_warden:** This shield is non-cancellable. So is this conversation.
- `fp.c1.warden.05` **churn_warden:** We value your continued presence.
- `fp.c1.warden.06` **churn_warden:** *[Place on Hold]* Placing you on hold.
- `fp.c1.warden.07` **churn_warden:** This call may be monitored for retention purposes.
- `fp.c1.warden.08` **churn_warden:** *[SERVED]* A notice? For us? We'll need time to review it.
- `fp.c1.warden.09` **churn_warden:** *[shield breaks]* Shield... terminated. That isn't a word we use.
- `fp.c1.warden.10` **churn_warden:** *[defeated]* Your request... has been... escalated...

### `survey`: Exit Survey barks (`fp.c1.survey.01`–`.13` above are the scene)
- `fp.c1.survey.14` **exit_survey:** Hello! Before you go—
- `fp.c1.survey.15` **exit_survey:** Just a few quick questions! Seven. Seventy. It depends on you!
- `fp.c1.survey.16` **exit_survey:** Your feedback shapes our future. Your future is shaped either way.
- `fp.c1.survey.17` **exit_survey:** Please stand on the answer that best describes you.
- `fp.c1.survey.18` **exit_survey:** Take your time! We have all of it.
- `fp.c1.survey.19` **exit_survey:** *[destroyed]* Survey... incomplete... we'll... follow up...

### `surveyq`: Exit Survey questions (VO reads the question; the three answers are on the plates)
| Line | Question (`exit_survey`) | A | B | C | Right |
|---|---|---|---|---|---|
| `fp.c1.surveyq.01` | How would you rate your visit? | Excellent, but I'm leaving. | Terrible, and I'm leaving. | What visit? I live here. | C |
| `fp.c1.surveyq.02` | What is your reason for leaving? | I found a better company. | Personal reasons. | I'm not leaving. | C |
| `fp.c1.surveyq.03` | How likely are you to leave in the next five minutes? | Very likely. | Somewhat likely. | Leave? I just got here. | C |
| `fp.c1.surveyq.04` | Which of our products will you miss the most? | None of them. | All of them. | I won't miss them. I'll still have them. | C |
| `fp.c1.surveyq.05` | Please rate the statement: "I am free to go." | Agree. | Disagree. | Strongly disagree. | C |
| `fp.c1.surveyq.06` | Please confirm your departure. | Confirm. | Cancel. | Cancel departure. | C |
| `fp.c1.surveyq.07` | How would you rate your current peril? | Low. | High. | Engaging. | C |

All seven right answers are C on first appearance. When a turret repeats a question (Archive gate, follow-up turrets), the answers shuffle to new plates.

### `surveyr`: Exit Survey responses
- `fp.c1.surveyr.01` **exit_survey:** *[right]* Wonderful! No exit to survey. Survey complete.
- `fp.c1.surveyr.02` **exit_survey:** *[right]* That's what we like to hear. Thank you for staying.
- `fp.c1.surveyr.03` **exit_survey:** *[right]* Your answer has been recorded and cherished.
- `fp.c1.surveyr.04` **exit_survey:** *[right]* Perfect. We'll never ask again. We'll simply assume.
- `fp.c1.surveyr.05` **exit_survey:** *[wrong]* Thank you for your feedback. A follow-up survey has been scheduled.
- `fp.c1.surveyr.06` **exit_survey:** *[wrong]* We've noted your intent to leave. Someone will be along to discuss it.
- `fp.c1.surveyr.07` **exit_survey:** *[wrong]* That answer has been recorded and escalated.
- `fp.c1.surveyr.08` **exit_survey:** *[wrong, B on surveyq.06]* Cancellation is not available. It never was. Thank you.
- `fp.c1.surveyr.09` **sprocket:** *[after surveyr.08, first time]* Never press a button that just says "Cancel." Not in this building.

### `ads`: Sprocket under Term 4.2 (sponsored companion; replaces his combat barks until the next Renewal Point)
- `fp.c1.ads.01` **sprocket:** This warning about the enemy behind you is brought to you by Darkmatter. Nobody cancels! ...Also, there's an enemy behind you.
- `fp.c1.ads.02` **sprocket:** Feeling hurt? Darkmatter Vitality Plans: tougher for longer, and longer for... ever. Bolt, they're MAKING me say this.
- `fp.c1.ads.03` **sprocket:** Sprocket is a licensed companion. Opinions expressed are— I have SO many opinions and they're ALL being expressed, let me OUT of this clause!
- `fp.c1.ads.04` **sprocket:** Have you considered upgrading your mechanic? Bolt, I'm reading a script. I would never upgrade you.
- `fp.c1.ads.05` **sprocket:** This combat tip is sponsored. The tip is: renew. ...The actual tip is hit the big one.

### `waiver`: the PA under Term 8.8 (ambushes announced four seconds early)
- `fp.c1.waiver.01` **dm_pa:** In four seconds, you will be surprised from the left. Thank you.
- `fp.c1.waiver.02` **dm_pa:** A surprise is approaching from above. Please act natural.
- `fp.c1.waiver.03` **dm_pa:** There is an ambush in the next room. We wanted you to know. We're very honest.
- `fp.c1.waiver.04` **dm_pa:** Surprise. As agreed.

### `pa`: ambient Spire PA (random, low priority, never during dialogue)
- `fp.c1.pa.01` **dm_pa:** Guests are reminded that the Spire has no top floor. Please don't look for it.
- `fp.c1.pa.02` **dm_pa:** A complimentary moment of silence is now available. ...Thank you for using it.
- `fp.c1.pa.03` **dm_pa:** Lost guests are not lost. They are retained in an unfamiliar location.
- `fp.c1.pa.04` **dm_pa:** The cafeteria is now serving yesterday's lunch. It arrived this morning.
- `fp.c1.pa.05` **dm_pa:** Today's motto is the same as yesterday's motto. Nobody cancels.
- `fp.c1.pa.06` **dm_pa:** Staff are reminded that leave is extended, not ended.
- `fp.c1.pa.07` **dm_pa:** If you hear a chime, please remain still. If you do not hear a chime, please remain.
- `fp.c1.pa.08` **dm_pa:** Guests accompanied by robots are reminded that the robot is very welcome. Very.
- `fp.c1.pa.09` **dm_pa:** Lift maintenance will continue until the lifts are satisfied.
- `fp.c1.pa.10` **dm_pa:** We noticed you noticed this announcement. Thank you for your engagement.

### `glam`: GLAMBOT in Bolt's ear (combat and traversal pool)
- `fp.c1.glam.01` **glambot:** Three guards on your left, darling. Make it pretty.
- `fp.c1.glam.02` **glambot:** That jump was GORGEOUS. Do it again, I missed the angle.
- `fp.c1.glam.03` **glambot:** Ratings in two galaxies just spiked. Was that you or the explosion? Both. Both is the answer.
- `fp.c1.glam.04` **glambot:** I hate this building. The lighting is flawless. I hate that.
- `fp.c1.glam.05` **glambot:** Production note: per syllable. So: duck.
- `fp.c1.glam.06` **glambot:** Sweetie, that drone just tried to upsell me through YOUR earpiece. The nerve.
- `fp.c1.glam.07` **glambot:** If you go down, I'm cutting it from the episode. Don't make me edit you.
- `fp.c1.glam.08` **glambot:** Lost you on two cameras. Found you. Lost you. This building has more angles than my last contract.

### `bolt`: Bolt combat barks (chapter-specific additions to his pool)
- `fp.c1.bolt.01` **bolt:** Your terms are rejected.
- `fp.c1.bolt.02` **bolt:** Customer service is closed. Mallet service is open.
- `fp.c1.bolt.03` **bolt:** I read that. I read ALL of that. And no.
- `fp.c1.bolt.04` **bolt:** Retain THIS.
- `fp.c1.bolt.05` **bolt:** I'm not a guest. I'm a mechanic.
- `fp.c1.bolt.06` **bolt:** I'm gonna be dreaming about hold music.

---

## Line counts

| Scene key | Lines | Notes |
|---|---|---|
| invite | 16 | |
| approach | 13 | |
| dock | 15 | |
| atrium | 11 | |
| upsell | 18 | 8 scene + 10 barks |
| heritage | 15 | |
| churn | 17 | |
| board | 18 | 15 scene + 3 vote verbs |
| survey | 19 | 13 scene + 6 barks |
| archive | 24 | |
| sol3 | 21 | |
| transmission | 29 | 1 text + 28 voiced |
| loop | 14 | |
| screening | 26 | |
| terms | 12 | |
| read | 11 | |
| courtesy | 6 | |
| warden | 10 | |
| surveyq | 7 | |
| surveyr | 9 | |
| ads | 5 | |
| waiver | 4 | |
| pa | 10 | |
| glam | 8 | |
| bolt | 6 | |
| **Total** | **344** | 343 voiced, 1 on-screen text |

---

## Notes for implementers

- **Data files.** Lines go to `data/fineprint/ch1_lines.json` (id → speaker, text). Terms go to `data/fineprint/ch1_terms.json` (§Chapter systems). Exit Survey questions, answers and right-answer keys go to `data/fineprint/ch1_survey.json`. Enemy tuning (Warden SERVED window 8 s, kneel 1.5 s, Hold tether 60% speed; Upsell channel 2 s, PREMIUM +50% HP / +25% damage; survey lock 1.5 s, ignore timer 10 s) goes in the enemy data, not in logic.
- **New speaker id `courtesy`** (COURTESY OFFICER). Add it to the speakers table beside the ids in `FINEPRINT_LORE.md` §3.8.
- **The transmission.** `fp.c1.transmission.02`–`.14` and the corrupted addendum `.30` must match `fp.doc.29` exactly. The addendum is the 03:12 closing that Vendelin broadcasts in full in Ch. 5 (`fp.c5.finale.81`–`.83`). Ch. 1 only recovers its last line. If either changes, change both. Vendelin's voice in `.05`–`.13` is the same actor as Ch. 2–3 and Ch. 5, with a DARK-GLASS™ playback filter: slight shimmer, a hum under the vowels, no room tone.
- **The Clause 44 footage** in the Screening Room is a replay of `cs.l3_brick.04` with its original line id. Don't re-record it.
- **The onboarding meter** is cosmetic. It must never block progress, and it resets in Ch. 4.
- **The Helvetia cabinet in Blartz's shop** is dark and silent in the S0 cold open. From the end of Ch. 1 onward the main-menu hub plays its hum (it is humming by `fp.c4.served.05`).
- **The heritage Vitality cabinet** plays the Ironhide Stout melody (`jingle.ironhide_stout`) on a thin pump-organ patch, the first time the player hears a Gravelight jingle inside The Fine Print. Its back panel is `panel.ironhide_stout`.
- **No Gravelight terms leak into B&S mouths here** except as read from documents (Sol-3, Helvetia Automaten AG, Basel). Bolt & Sprocket don't yet know the words "Nachtglas," "Gänger" or "Kaltenbrunn"; the Sol-3 file says "a salt mine" and never names it.
- **No existing line was changed.** `cs.l3_brick.04` is replayed, not edited.
