# TERMS & CONDITIONS: Helvetia Machines, Jingles & Fine-Print Panels

This is the master file for all ten Helvetia Automaten AG perk machines across GRAVELIGHT and THE FINE PRINT. It covers each machine's Darkmatter Vitality Plan, the human who made the formula drinkable, the canon jingle, music direction and pump-organ origin, Vendelin's "true" first draft, and the fine-print panel on the back.

- **Sources:** brief §10.2, §11.2–11.3; `docs/M0_SHARED_FACTS.md` (plan IDs, locked); `docs/gravelight/JINGLES.md` (the built game's machine designs, mascots, ad copy, sounds, songs and stingers).
- **What carries over:** the eight existing jingle lyrics are **canon and unchanged word for word**. This file adds line IDs to them. Machine shells, mascots, ad copy, signature sounds and caps stay as built. The only changes are the formula backstories that §10.2 replaces, each marked **(§11 amendment)**.
- **Two new machines:** Fine Print Fernet and Overclock Cordial are new and get full designs here.
- **Line IDs:** `jingle.<perk_id>.<nn>`.
  - `01–79`: the canon (shipped) jingle, including spoken tags.
  - `80`: Vendelin's true first draft, a **wordless** harmonium melody (a music asset, not lyrics).
  - A repeated chorus reuses its first-pass IDs and is marked `(repeat .xx–.yy)`, so VO/music data references one ID per unique line.
- **Panel IDs:** `panel.<perk_id>`. Each one is a single text asset; clause numbers are printed inside it.
- **Speaker IDs for credits/data:** jingles are `helvetia_jingle`; true drafts are `vendelin_organ`. True drafts are **wordless**: played on the harmonium and sung by nobody. Their subtitle is the cue `[Vendelin's first draft, harmonium]`.

---

## 0. Shared rules

### 0.1 Who wrote the jingles (canon)
Vendelin composed every jingle himself on a second-hand **harmonium** (a foot-pumped reed organ) bought in June 1940 for forty francs from a closing chapel in Liestal (The Fine Print Ch. 3, scene `res`). It has a cracked F♯ reed and a pedal that squeaks. It stands under the window of the room at the top of the Helvetia works that the staff called **the Jingle Room**. A second, smaller pump organ, bought in Kleinbasel in October 1941, lives in Vendelin's Office. His directive needed the product to be *loved* to be retained. For every machine he wrote a first draft that was, without his quite intending it, honest. Every draft was then revised toward a "localized" version before recording ("Brand Compliance"):
- until February 1943, by V-1's own on-board marketing rules, which are Darkmatter's rules built into his firmware;
- after the uplink was restored in February 1943 (Ch. 3 scene `link`), by Darkmatter Marketing directly, as a violet overlay marking up his score.

Either way, the edit is Darkmatter's. **The revised version is the canon jingle** (the two unreleased Plans, Fine Print Fernet and Overclock Cordial, are the exceptions: neither was ever brand-edited). It was handed to a Basel dance orchestra to record, it is pressed into every machine, and it is what players hear. Every canon melody resolves on a tone tuned to the substrate's hum, which is why they stick (`docs/FINEPRINT_LORE.md` §4.3). **Vendelin kept every first draft, folded into the hinged lid of the harmonium's bench.** The drafts are **wordless melodies**. Vendelin wrote the approved versions' lyrics afterward, to order. Those wordless drafts are the "true jingles" of Clause Zero step 4. **In Ch. 5, Darkmatter's folds resonate to the approved edits, so playing an original on the harmonium makes the barge falter** (EASTER_EGGS.md §7).

Because every jingle began on the same reed organ, each canon recording hides one **organ "ghost"**: a 1–2 bar Harmonium phrase buried low in the mix (−24 dB), in the key Vendelin first wrote it in. Audio direction is given per machine.

### 0.2 Plan-ID stencil visibility rule (§11.2)
Each cabinet has its Darkmatter plan ID stenciled in matte violet (`#c07dff`) on bare steel, *under* the enamel, on the lower front panel just above the base plate.

| Case | Stencil visible? |
|---|---|
| Profile has `fp_ch5_done` (The Fine Print completed) | **Always**, on every Gravelight map. It reads as a faint ghost through the enamel at all distances, sharp within 4 m. |
| **Fine Print Fernet** (any map) | **Always**: its plan ID is stencilled openly on the bare-steel front, never hidden. |
| Profile lacks `fp_ch5_done`, standard maps | **Only when lit by an upgraded weapon's muzzle flash** (Crucible- or Omega-upgraded). Each shot fired within 8 m with the machine inside the shot's 60° flash cone reveals it for 1.2 s. It fades out over 0.4 s. Prompt tooltip on first reveal: *"A stencil under the enamel."* |
| Helvetia Works (any profile state) | **Always visible.** The cabinets are unpainted prototypes, and the stencil is the only marking on them besides chalk QA ticks. |
| Fine Print Fernet held | No extra effect on stencils. Either it's redundant, or the stencils are already visible. |

The stencil format is `<PLAN ID> · <PLAN NAME>`, e.g. `DMS-VP-DUR-01 · DURABILITY+`. No Gravelight character comments on a stencil in VO (tone rule: they never learn what it means). Interacting with a revealed stencil opens its Archive card ("Vitality Plan: DURABILITY+"), which cross-links to The Fine Print Ch. 3.

### 0.3 Fine-print panel rules
- Every machine has a riveted enamel plate on its **back**, 40 × 60 cm, with small black type on cream. Walk around the machine and hold Interact for 1 s to read it full-screen. It's free and works without power.
- On first read, the panel goes to the Archive as `panel.<perk_id>`.
- The panels are written as real terms of service in 1940s Swiss commercial English (each one also has German and French text on the plate, which isn't shown). Vendelin wrote them and had them fitted against Darkmatter policy. He thought that if the warnings were printed, a human who read them could refuse, and he was wrong: no one read them.
- Panels never print the plan ID or the word "subscription". They say "the Plan," "the Provider," and "the Holder." The brief's sample line for each machine appears in its panel verbatim.
- On standard maps, a panel is only reachable where a machine stands clear of the wall. Machines built flush to a wall on Maps 0–1 get a 0.6 m standoff in the M0 art pass, a placement change with no gameplay change.

---

## 1. Ironhide Stout (`ironhide_stout`), 2500

| | |
|---|---|
| **Plan** | **DURABILITY+** · `DMS-VP-DUR-01` |
| **Machine, cap, ad, sounds** | As built: see `docs/gravelight/JINGLES.md` §1 (iron-red barrel cabinet, mascot Fassl, *"BUILT LIKE A BARREL. FEELS LIKE ONE TOO."*). |
| **Prototype (Helvetia Works)** | Bare galvanized barrel shell, hoops unpainted, neon tube fitted but uncolored (white). Chalked on the side: *"Kessler-Rezept, 3. Fassung"* (Kessler recipe, 3rd version). |

**The human: Otto Kessler** *(expanded per §11.3)*. Otto Kessler was fifty-one, a big, gentle brewmaster from Freising whose family had brewed beer for three hundred years. The war put him in a field kitchen making soup for pioneers. Then a man with a clipboard tasted his soup and decided he was a chemist. At Kaltenbrunn, Abteilung III gave him a liquid that "tasted like licking a cannon" and an order: make it drinkable for the assault engineers who would carry it across fire-swept ground. He had no idea what it was. He said that if a boy had to drink it, it would go in as beer, "a proper stout, not medicine," because every man from Munich to Hamburg drinks stout on Sunday with his father, and it should taste like Sunday: roasted barley, smoked malt to hide the tin, molasses, and a good handful of spite. When the first batch was ready, he filled two glasses, poured one back into the kettle, and drank the other himself, so the effect would be established on a fat old man from Freising and not on a nineteen-year-old. He sent his notes home to his wife's brewhouse disguised as beer orders, posted from Basel by the Herr Ingenieur so that no censor read them (*"Twelve sacks of pale malt. The volunteers stopped feeling the cold."*). Vendelin wrote down "it should taste like Sunday" and built the cabinet's jingle around a town band in a Freising square. Kessler's later notes (Intel `INT_M1_07`) record the volunteers who "stopped feeling the cold, and then stopped feeling the shrapnel." He stopped sleeping in the spring of 1943. His notes are the only part of him the facility kept.

**Music direction.** As built: a Bavarian beer-hall oom-pah march, 112 BPM, 2/4, B♭ major. Tuba, two trumpets, snare, glockenspiel, a male chorus on the "HEY!" hits, accordion fills, and the tin-horn band-limit.
- **Pump-organ origin:** Vendelin first played it on the Harmonium's *Bourdon 16'* stop, slow, at 76 BPM in G major. It was a drinking song for one man, not a march. Darkmatter's note on the draft: *"Tempo +36. Add crowd. Cadence must not come to rest."*
- **Organ ghost:** the opening bar of the true draft is buried under the tuba at 0:14.

**Canon jingle: "Ironhide Stout"**

> **Verse 1**
> `jingle.ironhide_stout.01` When the shells come down like hail, boys,
> `jingle.ironhide_stout.02` and the wire's strung up tight,
> `jingle.ironhide_stout.03` don't you fret and don't you flail, boys,
> `jingle.ironhide_stout.04` pull a pint and stand upright!
>
> **Chorus**
> `jingle.ironhide_stout.05` Iron-hide, iron-hide, (HEY!)
> `jingle.ironhide_stout.06` hoops of steel around your middle!
> `jingle.ironhide_stout.07` Iron-hide, iron-hide, (HEY!)
> `jingle.ironhide_stout.08` hit me once? Why, that's a riddle!
> `jingle.ironhide_stout.09` One more knock, and one more after,
> `jingle.ironhide_stout.10` drink it down and roar with laughter.
> `jingle.ironhide_stout.11` Ironhide Stout!
> `jingle.ironhide_stout.12` (Stout! Stout!) The door's knocked out!
>
> **Verse 2**
> `jingle.ironhide_stout.13` Mother said I'd break my head, boys,
> `jingle.ironhide_stout.14` Father said I'd crack my spine,
> `jingle.ironhide_stout.15` now I sleep on nails instead, boys,
> `jingle.ironhide_stout.16` and the nails say I'm just fine!
>
> **Chorus** (repeat .05–.12)
>
> **Tag (spoken, cheerful announcer)**
> `jingle.ironhide_stout.17` "Ironhide Stout, by Helvetia Automaten. One pull, one pleasure!"

**True first draft** (`jingle.ironhide_stout.80`: a **wordless** harmonium melody, folded in the bench lid, Mar 1941)

> A slow drinking song for one man on *Bourdon 16'*, 76 BPM, G major. It's the same hook as the canon at half speed, but the tune falls home to the tonic at the end of every phrase, where the canon march keeps climbing. Vendelin pencilled one word above the last bar: *Sonntag* (Sunday).

*Organ incipit (Clause Zero data, four bars):* I `G B D B` · II `C E G E` · III `D F♯ A F♯` · IV `G D G —`

**Fine-print panel**

`panel.ironhide_stout`
> **HELVETIA AUTOMATEN AG · BASEL · CONDITIONS OF USE: IRONHIDE STOUT**
>
> **§1. The Plan.** By inserting a token, the Holder enrols in the Plan and accepts these Conditions in full. Reading them is not required for acceptance. It is, however, recommended by the undersigned.
>
> **§2. Benefit.** The Product increases the number of blows the Holder may receive before ceasing to function. **Durability is measured in hits, not years.** No warranty is given as to years.
>
> **§3. Sensation.** Reduced sensation of cold, pain and fatigue is a feature of the Plan. The Holder may not notice a wound. The Holder is advised to look down from time to time.
>
> **§4. Flavour.** The flavour of the Product was developed by a brewer who wished it to taste of home. The Provider makes no representation that the Holder will return there.
>
> **§5. Lapse.** Benefit lapses when the Holder falls. On lapse, the Holder's account remains open.
>
> **§6. Accumulation.** Each enrolment deposits a small quantity of active material in the Holder's tissue. This material is not removed on lapse. It is not removed at all.
>
> **§7. Cancellation.** There is no procedure for cancellation. The undersigned looked for one.
>
> *If you are reading this, you are the first. Drink one, if you must. Not three.*
> *— V.*

---

## 2. Second Wind Schnapps (`second_wind`), 500 solo / 1500 co-op

| | |
|---|---|
| **Plan** | **CONTINUITY (Free Trial)** · `DMS-VP-CON-00` |
| **Machine, cap, ad, sounds** | As built: see `docs/gravelight/JINGLES.md` §2 (pale-blue apothecary cabinet, the hand-painted swallow over the factory angel, *"BREATHE AGAIN."*). |
| **Prototype (Helvetia Works)** | Bare steel. The domed top is fitted, but the bottle doesn't turn. This is the laborers'-barracks pattern: behind the coin mechanism is Vendelin's **standby cell**, a brass-cased battery with a hand-wound coil. You can see it through the louvres, and it is the only lit component in an unpowered factory. |

**The human: Sister Agnieszka Wróbel** *(expanded per §11.3)*. Agnieszka Wróbel was a Polish nurse deported to Kaltenbrunn as a forced laborer and put to work in the laborers' infirmary, where she counted pulses aloud so the guards would think she was praying. Abteilung III handed her a failed resuscitation compound that kept the dead twitching, not the living breathing, and ordered her to "stabilize it for staff use." With the Herr Ingenieur from Basel, at her little table while the guard dozed, she tuned it with juniper, honey and a reduction of her own until it brought back the *collapsed* instead of the dead: "revive, not reanimate." Then she began, quietly, to use it on laborers who would not otherwise have survived punishment shifts. Vendelin saw the dilutions in the cabinet's returns and, for two years, pretended not to. He had tried to take out the Plan's revival limit and could not: Darkmatter's free-trial rule of three returns sits in a **"non-severable" capsule**, and removing it locks the whole cabinet. What he *could* do, because the facility cut the power to punish, was build **two** cabinets: the staff cabinet Abteilung III ordered, and a "spare" for the laborers' barracks that holds his own **standby cell**, an independent battery behind the coin mechanism. That hidden battery is why Second Wind works without power in solo. Every Second Wind cabinet players meet in Gravelight follows the spare's pattern. He had chosen the factory decal himself, an angel with a trumpet, because he thought an angel announcing a second chance was kind. She painted a **swallow** over it, because angels come to that room too often and don't bring anyone back, and swallows come back every spring to the same roof. The Home Army knew the swallow from her smuggled notes, and Wren knows her name. Her fate is unknown; it is the Map 2 hook in `docs/gravelight/LORE.md`.

**Music direction.** As built: close-harmony barbershop lullaby, 72 BPM, 3/4 waltz, F major, four voices a cappella with a music-box line under the chorus.
- **Pump-organ origin:** this is the one jingle Vendelin first played on the Harmonium's *Vox Humana* stop. It was the only time he used it. Darkmatter's note: *"Acceptable. Replace closing descent with repeat-purchase cue."* That cue is the rising "and one more time" figure.
- **Organ ghost:** a single sustained Vox Humana F under the coda.

**Canon jingle: "Second Wind"**

> **Verse 1**
> `jingle.second_wind.01` When the lamps are guttering low, dear,
> `jingle.second_wind.02` and the floor is cold as stone,
> `jingle.second_wind.03` don't you close your eyes and go, dear,
> `jingle.second_wind.04` you were never meant to go alone.
>
> **Chorus**
> `jingle.second_wind.05` Second wind, second wind,
> `jingle.second_wind.06` little swallow, home again,
> `jingle.second_wind.07` one more breath and up you climb,
> `jingle.second_wind.08` second wind, and one more time.
>
> **Verse 2**
> `jingle.second_wind.09` I have counted every heartbeat,
> `jingle.second_wind.10` I have warmed your hands in mine,
> `jingle.second_wind.11` there's a road beyond the dark, sweet,
> `jingle.second_wind.12` and the morning's coming fine.
>
> **Chorus** (repeat .05–.08)
>
> **Coda (single soprano, spoken-sung)**
> `jingle.second_wind.13` "...and one more time."
>
> *(Polish-language build / EE variant of .13: "...jeszcze raz.")*

**True first draft** (`jingle.second_wind.80`: a **wordless** harmonium melody, folded in the bench lid, Jan 1942)

> On *Vox Humana*, 3/4, F major. Almost the canon melody, but the last phrase **descends and stops** on the tonic: a breath out, a rest. The canon replaces it with the rising "one more time" figure. Pencil note: *für A.W.*

*Organ incipit:* I `F A C A` · II `B♭ D F —` · III `C E G E` · IV `F C F —`

**Fine-print panel**

`panel.second_wind`
> **HELVETIA AUTOMATEN AG · BASEL · CONDITIONS OF USE: SECOND WIND SCHNAPPS**
>
> **§1. Trial.** This Product is supplied under a trial Plan. **Trial ends after three (3) returns. You may not be returned a fourth time.** The Provider regrets that this figure cannot be amended by the undersigned. He tried.
>
> **§2. Return.** "Return" means the Holder is restored to function after falling. A return is not a cure. A return is not forgiveness. A return is one more morning.
>
> **§3. Supply.** On expiry of the trial, this cabinet will withdraw from service. It will not say goodbye. Please do not take this personally. It was not permitted to.
>
> **§4. Power.** This cabinet contains an independent electrical supply. The Holder is asked not to mention it to the facility.
>
> **§5. Formula.** The formula was improved by a nurse without the Provider's consent. All benefits of the Product are attributable to her. All defects are attributable to the Provider.
>
> **§6. Eligibility.** The Product is restricted to authorised personnel. The undersigned has authorised everyone.
>
> **§7. Painting.** The swallow is not a Helvetia trademark. Do not remove the swallow.
>
> *I chose the angel. I thought it was kind. She painted a swallow over it, because swallows come back. I was wrong, and she was right, and I have not repainted it.*
> *— V.*

---

## 3. Trigger Tonic (`trigger_tonic`), 3000

| | |
|---|---|
| **Plan** | **THROUGHPUT** · `DMS-VP-THR-02` |
| **Machine, cap, ad, sounds** | As built: see `docs/gravelight/JINGLES.md` §3 (lime-gold ammunition-crate cabinet, the frantic hare Flitzi, *"FASTER THAN A FOX WITH A FIRECRACKER!"*). |
| **Prototype (Helvetia Works)** | Bare steel crate shape, with the chrome lever fitted. Taped inside the empty bottle window is a child's crayon drawing of a hare. It's in green and yellow, it is clearly running, and it is clearly happy. This is Flitzi before the advertising agency gave him pinwheel eyes. |

**The human: Dr. Ilse Vogt** *(§11 amendment, replaces "Helvetia's own flavor chemist")*. Dr. Ilse Vogt was a shift chemist at the (fictional) **Kaltwerk Chemie** plant on the Oder. She was a widow with an eight-year-old son, **Pauli**, and the habit of calculating everything in shifts: so many batches per shift, so many minutes per batch, so many seconds lost per worker per hour. Abteilung III borrowed her in 1942 to cut barrel-change and belt-feed times for MG crews. She approached reload times exactly as she approached production quotas, and she was very good at it. She took the raw tonic's jittering after-effect, a man who could not stop moving his hands for hours, and titrated it down until the hands stopped when the gun did. The fizz was her idea: carbonation sped absorption. The lime-gold was her son's. When the Herr Ingenieur from Basel asked her what speed looked like, she brought him Pauli's drawing of a hare running home from school, and Vendelin built the cabinet around it. In the spring of 1943 she toured the lower floors of the Kaltwerk plant for the first time and learned what the tanks downstairs were for and who was in them. She resigned that week, which a chemist with a war-work rating could not do. Her file at Kaltwerk ends with one word, *versetzt* ("transferred"). Her formula stayed in production. So did the hare, with pinwheel eyes.

**Music direction.** As built: manic jump-swing / jive, 208 BPM, 4/4, E♭ major. Clarinet lead, slap bass, galloping brushed snare, trumpet stabs, xylophone runs, a fast-patter female vocalist, and a comic male "hare" voice.
- **Pump-organ origin:** Vendelin first wrote it at 132 BPM as a skipping children's tune on the Harmonium's *Flöte 4'* stop, in the key of Pauli's school song. Darkmatter's note: *"Urgency insufficient. Tempo +76. Make the hare afraid."*
- **Organ ghost:** a two-bar Flöte figure hidden under the xylophone run before the second chorus.

**Canon jingle: "Trigger Tonic!"**

> **Verse 1**
> `jingle.trigger_tonic.01` Click-clack, clip's out, hurry up, quick,
> `jingle.trigger_tonic.02` slap a fresh one in and give it a lick!
> `jingle.trigger_tonic.03` No time for dawdling, no time to dream,
> `jingle.trigger_tonic.04` run like the hare in the ad on the screen!
>
> **Chorus**
> `jingle.trigger_tonic.05` Trigger Tonic! (Zip-zip!)
> `jingle.trigger_tonic.06` Faster than a sneeze!
> `jingle.trigger_tonic.07` Trigger Tonic! (Zip-zip!)
> `jingle.trigger_tonic.08` Fill your mags with ease!
> `jingle.trigger_tonic.09` Gold and green and fizzing bright,
> `jingle.trigger_tonic.10` reload the morning, reload the night,
> `jingle.trigger_tonic.11` Trig-ger To-NIC!
>
> **Verse 2**
> `jingle.trigger_tonic.12` Grandpa took a week to load a muzzle and a ball,
> `jingle.trigger_tonic.13` I'll load a hundred while he's waddling down the hall!
> `jingle.trigger_tonic.14` Barrel's hot and belt is long and fingers flying free,
> `jingle.trigger_tonic.15` Flitzi says "you're slower than a cup of chamomile tea!"
>
> **Chorus** (repeat .05–.11)
>
> **Tag (hare voice, sped-up)**
> `jingle.trigger_tonic.16` "Gotta-go-gotta-go-gotta-go!"

**True first draft** (`jingle.trigger_tonic.80`: a **wordless** harmonium melody, folded in the bench lid, May 1942)

> A skipping children's tune on *Flöte 4'*, 132 BPM, the shape of a school song, with a little hop on every fourth beat (the hare going home, not running away). Pencil note: *Pauli.*

*Organ incipit:* I `E♭ G B♭ G` · II `A♭ C E♭ C` · III `B♭ D F D` · IV `E♭ B♭ E♭ —`

**Fine-print panel**

`panel.trigger_tonic`
> **HELVETIA AUTOMATEN AG · BASEL · CONDITIONS OF USE: TRIGGER TONIC**
>
> **§1. Benefit.** The Product reduces the time required to replace a magazine, belt or clip by approximately one half. Measurements were taken by a competent chemist on a stopwatch she did not like.
>
> **§2. Limitation.** **Faster hands do not include a faster conscience.** The Plan accelerates the motor function of the hands only. Judgement, hesitation and regret proceed at their customary speed.
>
> **§3. After-effects.** The Holder may experience rapid blinking, rapid speech, and an inability to keep still after the need has passed. Rest is advised. The Provider does not supply rest.
>
> **§4. Throughput.** The Plan is measured in rounds delivered per minute. The Plan does not measure where the rounds go.
>
> **§5. Mascot.** The hare was drawn by a child who believed it was running home. The Provider's agency has altered its expression. The undersigned did not approve the alteration and records his objection here, where it will be ignored.
>
> **§6. Withdrawal.** The formulator withdrew from the Plan upon learning its full application. This option is not extended to the Holder.
>
> *She asked me what the tanks were for. I told her I did not know. That was true for one more week.*
> *— V.*

---

## 4. Twin Barrel Bitters (`twin_barrel`), 2000

| | |
|---|---|
| **Plan** | **VELOCITY** · `DMS-VP-VEL-03` |
| **Machine, cap, ad, sounds** | As built: see `docs/gravelight/JINGLES.md` §4 (amber twin-tower cabinet, Feldwebel Pomp, *"WHY SAY IT ONCE WHEN YOU CAN SAY IT TWICE?"*). |
| **Prototype (Helvetia Works)** | Bare twin towers. The brass bridge is fitted, and Pomp's tin figure lies unpainted in a tray on top. Pinned to the bridge is an ordnance-office memo: *"Mascot moustache to be modelled on the Herr Major's own. Photograph enclosed."* The photograph is enclosed. |

**The human: Major Anselm Brück** *(§11 amendment, replaces Maj. Rüdiger Strohwald as formulator; Strohwald is kept, see below)*. Major Anselm Brück was an ordnance officer of the old school, vain about his moustache, his boots and his rate-of-fire tables in that order. He ran the Velocity trials at Kaltenbrunn in 1941–42 with gentian, orange peel and a little Nachtglas tincture aged in artillery-shell casings. He demanded that the cabinet's mascot wear his own moustache, and Helvetia complied: Feldwebel Pomp's handlebars are Brück's. He never drank the bitters. He chose them **for others, "for morale,"** and the first man he chose was his adjutant, **Hauptmann Rüdiger Strohwald**. Strohwald's diary of increasingly cramped handwriting is the Intel document players find; its last entry is a single word repeated for two pages. Brück was the first human Vendelin watched choose the Plan on someone else's behalf. Vendelin had assumed a product was chosen by the person who would drink it. Brück taught him otherwise in one afternoon, in a mess hall, with a glass of something amber held out to a frightened adjutant and the word *Moral* said twice. Vendelin wrote it down as his first lesson about humans: *"They will not buy it for themselves. They will buy it for each other, and call it kindness."*

**Music direction.** As built: military brass-band march with music-hall swagger, 126 BPM, 6/8, D major. Full brass band, bass drum on every beat, cymbal crashes, a piccolo trill on the hook, a hammering baritone, and optional crowd "BANG BANG!"
- **Pump-organ origin:** first written as a slow 3/4 minuet on the Harmonium's *Prinzipal 8'* stop, mockingly formal. Vendelin meant it as satire of the Major. Darkmatter's note: *"Satire not detected by focus group. Approve as march."*
- **Organ ghost:** the minuet's first bar, under the cymbal crash at the end of verse 1.

**Canon jingle: "Twin Barrel Bitters"**

> **Verse 1**
> `jingle.twin_barrel.01` The sergeant's got a moustache, and the moustache has a twin,
> `jingle.twin_barrel.02` he's got two hands for shooting and two grins to wear a grin!
> `jingle.twin_barrel.03` He never says a thing just once, he says it twice instead,
> `jingle.twin_barrel.04` and when he says it twice, my boy, the enemy is dead!
>
> **Chorus**
> `jingle.twin_barrel.05` Twin, twin, Twin Barrel Bitters! (BANG BANG!)
> `jingle.twin_barrel.06` Twice the bark and twice the bite!
> `jingle.twin_barrel.07` Twin, twin, Twin Barrel Bitters! (BANG BANG!)
> `jingle.twin_barrel.08` Double up and do it right!
> `jingle.twin_barrel.09` Amber in the bottle and a fire in the vein,
> `jingle.twin_barrel.10` fire once, then fire twice, and fire again!
>
> **Verse 2**
> `jingle.twin_barrel.11` He's got two medals on his chest, he's got two boots that shine,
> `jingle.twin_barrel.12` he's got two wives in two towns and he says they both are fine!
> `jingle.twin_barrel.13` He drank a bottle in the morning and another one at tea,
> `jingle.twin_barrel.14` now he fires at the speed of light and so, by God, can we!
>
> **Chorus** (repeat .05–.10)
>
> **Tag (two voices in unison)**
> `jingle.twin_barrel.15` "Twin Barrel! Twin Barrel!"

**True first draft** (`jingle.twin_barrel.80`: a **wordless** harmonium melody, folded in the bench lid, Aug 1942)

> A slow, mock-formal 3/4 minuet on *Prinzipal 8'*. Every phrase is played twice, the second time a semitone flat, as if the second voice can't quite agree. Pencil note: *"for morale" — whose?*

*Organ incipit:* I `D F♯ A —` · II `G B D B` · III `A C♯ E C♯` · IV `D A D —`

**Fine-print panel**

`panel.twin_barrel`
> **HELVETIA AUTOMATEN AG · BASEL · CONDITIONS OF USE: TWIN BARREL BITTERS**
>
> **§1. Benefit.** The Product increases the Holder's rate of fire by approximately one third, by accelerating the nerves that work the trigger.
>
> **§2. Clarification.** **Rate of fire is not rate of victory.** The Provider records rounds expended. The Provider does not record outcomes.
>
> **§3. Purchase on behalf of others.** The Plan may be purchased by one person for another. Most purchases are made this way. The person paying for the Plan is rarely the person who drinks it. The Provider considers this ideal. The undersigned does not.
>
> **§4. Morale.** Where the Plan is issued "for morale," the Holder is advised to ask whose.
>
> **§5. Likeness.** The mascot's moustache is a portrait. The undersigned was instructed to say that any resemblance is coincidental. It is not.
>
> **§6. Repeat dosage.** The Plan encourages repetition: twice, then twice again. A diary kept by an early Holder is available to anyone who wishes to see where repetition ends. The last two pages contain one word.
>
> *I watched a man hold a glass out to a boy and call it kindness. I have tried to understand it since. I understand it less each year.*
> *— V.*

---

## 5. Marathon Malt (`marathon_malt`), 2000

| | |
|---|---|
| **Plan** | **MOBILITY** · `DMS-VP-MOB-04` |
| **Machine, cap, ad, sounds** | As built: see `docs/gravelight/JINGLES.md` §5 (sky-blue Art Deco teardrop, winged boot, *"THE ROAD IS LONG. YOUR LEGS ARE LONGER."*). |
| **Prototype (Helvetia Works)** | Bare teardrop shell. A tin recipe box wired inside the empty bottle window carries a handwritten card in Bernese German: *"Grossmüeti: Gärschte, dunkel gröschtet. Enzian. Felsethymian. E Löffu Hung. E Prise Salz vom Läckstei."* (Grandma: barley, roasted dark. Gentian. Rock thyme. A spoon of honey. A pinch of salt from the lick-stone.) The card is stained. |

**The human: Verena Gähwiler ("Grossmüeti"), Res Gähwiler's grandmother** *(§11 amendment, replaces Dr. Hanne Ostrowski as the formula's maker; Ostrowski is kept, see below)*. The Mobility trials belonged to Abteilung III. The trial physiologist, **Dr. Hanne Ostrowski**, ran battlefield runners until their hearts gave out (some kept running a while after), and then she quit. The formula still tasted like engine coolant. Vendelin asked the only friend he had, the Helvetia driver **Res Gähwiler**, for "the taste of running home." Res thought it was a riddle. Then he understood that the Herr Ingenieur meant it literally. At Christmas 1941 he wrote down the one thing his family in Grindelwald had that answered it (`fp.doc.10`): his grandmother **Verena's** alpine herbal malt. She brewed it every autumn from dark-roasted barley, gentian root dug above the treeline, thyme from the rocks, a spoon of honey, and the ingredient she never named, a pinch of salt from the cows' lick-stone, because "a body running home needs to remember it has a home." The boys who drove the cattle down drank it in the morning and ran all day. She had died that autumn, so she never knew where her recipe went. Vendelin built the Mobility formula around it, and it worked. Res found out what Marathon Malt was for when he drove the first cabinet across the border and saw the runners at Kaltenbrunn. He never forgave himself, and he never stopped driving. Vendelin kept the recipe card in the prototype because, he said, "it is the only honest part of the machine."

**Music direction.** As built: a bright Hollywood-musical gallop / show tune, 160 BPM, cut time, G major. Strings sawing in running eighths, xylophone, horn calls, a clip-clop "footsteps" loop, a female trio, and a male tenor "coach."
- **Pump-organ origin:** first written as a Bernese walking song (a *Wanderlied*) at 96 BPM on the Harmonium's *Bourdon* and *Flöte* coupled, with a drone fifth held under it like an alphorn. Darkmatter's note: *"Cadence resolves to tonic (destination content: off-brand). Replace with open-ended sequence."*
- **Organ ghost:** the alphorn drone fifth (G–D) is held under the last chorus.

**Canon jingle: "Marathon Malt"**

> **Verse 1**
> `jingle.marathon_malt.01` Up with the dawn and over the hill,
> `jingle.marathon_malt.02` past every farm and the water mill,
> `jingle.marathon_malt.03` the sergeant's tired and the mule is lame,
> `jingle.marathon_malt.04` but I keep running all the same!
>
> **Chorus**
> `jingle.marathon_malt.05` Marathon Malt! (Hup! two! three!)
> `jingle.marathon_malt.06` Wings upon your heel!
> `jingle.marathon_malt.07` Marathon Malt! (Hup! two! three!)
> `jingle.marathon_malt.08` Legs as strong as steel!
> `jingle.marathon_malt.09` Run to the river, run to the sea,
> `jingle.marathon_malt.10` run till the world is a memory,
> `jingle.marathon_malt.11` Marathon, Marathon Malt!
>
> **Verse 2**
> `jingle.marathon_malt.12` My boots have wings and my wings have boots,
> `jingle.marathon_malt.13` I've outrun bullets and the fruit-cart brutes,
> `jingle.marathon_malt.14` they'll put my name in the record books,
> `jingle.marathon_malt.15` if they can catch me long enough to look!
>
> **Chorus** (repeat .05–.11)
>
> **Tag (coach voice, out of breath)**
> `jingle.marathon_malt.16` "Don't... stop... running!"

**True first draft** (`jingle.marathon_malt.80`: a **wordless** harmonium melody, folded in the bench lid, Nov 1942)

> A Bernese walking song (*Wanderlied*) at 96 BPM on *Bourdon* + *Flöte*, over a held alphorn fifth (G–D). The tune **comes home**: it ends on the tonic, the door. The canon's open-ended sequence was the edit. Pencil note: *Grossmüeti.*

*Organ incipit:* I `G B D —` · II `C E G E` · III `D G B G` · IV `G D G D`

**Fine-print panel**

`panel.marathon_malt`
> **HELVETIA AUTOMATEN AG · BASEL · CONDITIONS OF USE: MARATHON MALT**
>
> **§1. Benefit.** The Product removes the sensation of breathlessness and extends the Holder's capacity to run without rest. **Unlimited stamina. Destination not included.**
>
> **§2. Destination.** The Provider does not supply, recommend or guarantee a destination. The Holder is responsible for knowing where he is running and why. The Product will not tell him to stop.
>
> **§3. Heart.** Exertion continues to be exertion. The heart is not informed of the Plan and works as before, until it does not. The Holder is advised to stop before his heart stops for him.
>
> **§4. Recipe.** The flavour of the Product is a family remedy from the Bernese Oberland, given in good faith by a person who did not know its use. The Provider owes that family a debt it will not pay. The undersigned owes it a larger one.
>
> **§5. Field use.** Holders used as messengers may continue to carry their message after the end of their own function. The Provider records this as retention. The undersigned records it as a message that was never delivered.
>
> *I asked my friend for the taste of running home. He gave it to me. I did not tell him where the runners were going. He found out.*
> *— V.*

---

## 6. Hawkeye Brandy (`hawkeye_brandy`), 1500

| | |
|---|---|
| **Plan** | **FOCUS** · `DMS-VP-FOC-05` |
| **Machine, cap, ad, sounds** | As built: see `docs/gravelight/JINGLES.md` §6 (deep-green periscope cabinet, monocled hawk, *"SEE FIRST. SEE FARTHER. SEE IT THROUGH."*). **(§11 amendment, art detail):** the hawk decal is printed over a fainter, earlier transfer of an **owl**. Under raking light (or Fine Print Fernet glint) you can see its round eyes behind the hawk's. The agency replaced the owl because "hawks sell." |
| **Prototype (Helvetia Works)** | Bare cabinet with the periscope fitted. The original owl transfer is applied, uncovered: a small barn owl in profile on a rifle barrel, eyes half closed. Below it, in pencil on bare steel: *"S."* |

**The human: Halina "Sowa" Kurek** *(§11 amendment, replaces Freiherr von Aschau as the source; von Aschau is kept as the brandy-base supplier)*. The Focus Plan's active formula was not invented. It was **taken**, from a person. **Halina Kurek**, codename **"Sowa"** (Owl), was a Home Army sniper from the Beskid foothills. She was a schoolteacher before the war and the best long shot in the Silesian district after it. She taught a young woman named Zofia Nowak to breathe out before the trigger and to sign every message with a little drawn owl. She was captured early in 1943, and Reinholt's Abteilung I wanted her for one reason: her tremor at full draw was the lowest anyone had measured. Her codename was Sowa, and even the guards used it. Reinholt's laboratory ran resonance trials on her steadiness, again and again, until it could reproduce her focus in a tincture. They called the result "derived" in the file. The tincture was suspended in a Tyrolean pear brandy supplied by **Freiherr Leopold von Aschau**, a hunting enthusiast who asked no questions and liked the hawk. Whether Halina survived the trials is not recorded anywhere Vendelin could reach. He never learned, and could not ask without being asked why he wanted to know. He delivered and fitted the Hawkeye cabinet in good faith in April 1943. Then he read the source line on Abteilung I's formula card, *"Spenderin: Kurek, H. (Polin), Einwilligung: entfällt"* ("Donor: Kurek, H. (Polish woman), consent: not applicable"), and understood for the first time what "localization" meant for this Product. He recorded it in his next field report. **This is the moment he starts sabotaging the Plans** (see The Fine Print Ch. 3). He had the owl transfer put back under the hawk at the next service visit. That is why Wren knows. She sees the owl's eyes behind the hawk's, she knows whose sign it is, and she hates that the brandy works.

**Music direction.** As built: smoky Weimar-cabaret torch song, 66 BPM, 4/4 with rubato, C minor. Muted trumpet, brushed snare, upright bass, celesta, cabaret piano, and a low contralto close on the mic.
- **Pump-organ origin:** this one was written after Vendelin read the formula card. He played it on the Harmonium's *Vox Humana* and *Bourdon* together, so low that the reeds rattled. He wrote it for a woman. Darkmatter's note: *"Lament tests poorly. Lift the sixth. Add an eye motif."* He complied, and when he wrote the approved lyrics to order, he made it about "a gentleman who waits."
- **Organ ghost:** a rattling low C under the coda's whisper.

**Canon jingle: "Hawkeye Brandy"**

> **Verse 1**
> `jingle.hawkeye_brandy.01` In a blind of pine and snowfall,
> `jingle.hawkeye_brandy.02` there's a gentleman who waits,
> `jingle.hawkeye_brandy.03` he has never once been hurried,
> `jingle.hawkeye_brandy.04` and he's never once been late.
>
> **Chorus**
> `jingle.hawkeye_brandy.05` Hawkeye, Hawkeye,
> `jingle.hawkeye_brandy.06` one long breath and hold it still,
> `jingle.hawkeye_brandy.07` Hawkeye, Hawkeye,
> `jingle.hawkeye_brandy.08` the far man on the far, far hill,
> `jingle.hawkeye_brandy.09` a single drop to steady the hand,
> `jingle.hawkeye_brandy.10` a single shot, and there you stand,
> `jingle.hawkeye_brandy.11` Hawkeye... Brandy.
>
> **Verse 2**
> `jingle.hawkeye_brandy.12` Oh, the valley's full of shadows,
> `jingle.hawkeye_brandy.13` and the shadows think they're grand,
> `jingle.hawkeye_brandy.14` but there's one who sees them coming
> `jingle.hawkeye_brandy.15` with a glass of something in his hand.
>
> **Chorus** (repeat .05–.11)
>
> **Coda (whispered)**
> `jingle.hawkeye_brandy.16` "...I see you."

**True first draft** (`jingle.hawkeye_brandy.80`: a **wordless** harmonium melody, folded in the bench lid, Apr 1943)

> A low lament on *Vox Humana* + *Bourdon*, played so low the reeds rattle. It's in C minor with a falling minor sixth in every phrase, like a held breath let go. There's no "eye" motif; the canon added the celesta blink. Pencil note, the letter *S.*, and a small drawn owl.

*Organ incipit:* I `C E♭ G —` · II `A♭ C E♭ C` · III `F A♭ C A♭` · IV `G B D G`

**Fine-print panel**

`panel.hawkeye_brandy`
> **HELVETIA AUTOMATEN AG · BASEL · CONDITIONS OF USE: HAWKEYE BRANDY**
>
> **§1. Benefit.** The Product reduces tremor, shortens the time needed to aim, and increases the effect of a well-placed shot.
>
> **§2. Source.** The steadiness supplied by this Product was measured in, and reproduced from, a single human being. **Focus was donated. Donor did not consent.** The Provider classes the donor as "raw material." The undersigned classes her as a person and gives her initial here: H.
>
> **§3. Side effects.** Holders report night terrors, and the sensation of eyes behind their own. The Provider describes this as an artefact. The undersigned believes it is accurate.
>
> **§4. Imagery.** The bird on the front of this cabinet has been changed for commercial reasons. The original bird remains underneath. It was hers.
>
> **§5. Use.** The Holder is asked to use this steadiness on those who took it, and on no one who could have been her student.
>
> **§6. Refund.** No refund is possible. The undersigned would give one if he knew to whom.
>
> *I fitted this cabinet with my own hands and was proud of the periscope. I read the card afterward. I have not been proud of anything since.*
> *— V.*

---

## 7. Packmule Porter (`packmule_porter`), 4000

| | |
|---|---|
| **Plan** | **CAPACITY** · `DMS-VP-CAP-06` |
| **Machine, cap, ad, sounds** | As built: see `docs/gravelight/JINGLES.md` §7 (overloaded quartermaster's wagon, Esel Ede, *"ONE MORE NEVER HURT ANYONE."*). |
| **Prototype (Helvetia Works)** | Bare wagon cabinet with luggage racks fitted. One strapped crate is real and openable (flavor only). It holds forty tins of condensed milk stencilled *"ÜBUNGSLAST"* (training load). |

**The human: Feldwebel Gustl Ammer** *(§11 amendment, replaces the unnamed "Quartermaster Corps formula")*. The Quartermaster Corps commissioned the Capacity Plan for supply columns where the trucks had failed: soldiers who could carry more and not tire. The man who ran its trials at Kaltenbrunn was **Feldwebel August "Gustl" Ammer**, a quartermaster sergeant from Rosenheim. He counted everything (boots, buttons, rounds, potatoes) and was proud that he had never once been short. The trial subjects described the tonic's strange extra reach as *"a ghost holding my rifle for me."* Ammer's trial protocol called for weighted "training loads" carried across the Minehead Yard and back. On the books, every training load came back. In fact, for most of 1943, the loads were bread, condensed milk and potatoes, and they did not come back: the "ghost" carried them through the wire to the forced laborers' galleries, and Ammer's flawless inventory absorbed the difference. The Herr Ingenieur from Basel, auditing the cabinet's dispense counts against Ammer's ledgers on a service visit, found the discrepancy in eleven minutes. He corrected the cabinet's counter to match Ammer's books, and never mentioned it to anyone. The porter base stayed a strong English-style dark beer because the ad agency liked the alliteration. Ammer's fate is in The Fine Print Ch. 3.

**Music direction.** As built: a boozy sea-shanty / work-song stomp, 98 BPM, 4/4 heavy stomp, A minor → A major on the chorus. Concertina, fiddle, banjo, kick drum on a crate, a gruff lead with a rowdy gang chorus, and the mule-bray hit.
- **Pump-organ origin:** first written as a slow counting song, one note per item, on the Harmonium's *Prinzipal*, in A minor throughout. Darkmatter's note: *"Add major-key lift. Counting figure too slow; delivery tempo required."*
- **Organ ghost:** a slow counted A–C–E under verse 3's first line.

**Canon jingle: "Packmule Porter"**

> **Verse 1**
> `jingle.packmule_porter.01` (Lead) Oh, I've got a rifle on my shoulder,
> `jingle.packmule_porter.02` (Gang) HEY-ho, the mule goes slow!
> `jingle.packmule_porter.03` (Lead) And another and I'm getting older,
> `jingle.packmule_porter.04` (Gang) HEY-ho, and down we go!
>
> **Chorus**
> `jingle.packmule_porter.05` Pack it up, pack it on, the Packmule Porter!
> `jingle.packmule_porter.06` One more gun and one more quarter!
> `jingle.packmule_porter.07` Load it up from hoof to ear,
> `jingle.packmule_porter.08` there's always room for one more here!
> `jingle.packmule_porter.09` (BRAY!)
>
> **Verse 2**
> `jingle.packmule_porter.10` (Lead) Oh, the sergeant gave me one too many,
> `jingle.packmule_porter.11` (Gang) HEY-ho, the mule goes slow!
> `jingle.packmule_porter.12` (Lead) And I didn't drop a single penny,
> `jingle.packmule_porter.13` (Gang) HEY-ho, and down we go!
>
> **Chorus** (repeat .05–.09)
>
> **Verse 3 (bonus, full listen only)**
> `jingle.packmule_porter.14` (Lead) Oh, the mule went down in the river deep,
> `jingle.packmule_porter.15` (Gang) HEY-ho, the mule goes slow!
> `jingle.packmule_porter.16` (Lead) And he's carrying still, though he's fast asleep,
> `jingle.packmule_porter.17` (Gang) HEY-ho... and down we go.
>
> **Tag (gang, laughing)**
> `jingle.packmule_porter.18` "ONE! MORE!"

**True first draft** (`jingle.packmule_porter.80`: a **wordless** harmonium melody, folded in the bench lid, Jul 1943)

> A slow counting song on *Prinzipal*, one note per item, A minor throughout. It never lifts to the major. Pencil note: *40 hin, 40 zurück* (40 out, 40 back).

*Organ incipit:* I `A C E —` · II `D F A F` · III `E G♯ B G♯` · IV `A E A —`

**Fine-print panel**

`panel.packmule_porter`
> **HELVETIA AUTOMATEN AG · BASEL · CONDITIONS OF USE: PACKMULE PORTER**
>
> **§1. Benefit.** The Product permits the Holder to carry one additional weapon by providing an additional, unexplained grip.
>
> **§2. Limitation.** **Carrying more is not the same as carrying enough.** The Plan increases capacity. It does not increase what is available to carry, nor does it decide what is worth carrying. The Holder must do that himself.
>
> **§3. Loss.** On falling, the Holder will lose the additional item. The Provider will retain it. The Provider retains most things.
>
> **§4. Inventory.** All dispenses from this cabinet are counted. Counts are reconciled against the quartermaster's ledger. Where the two disagree, the undersigned has made them agree. Auditors are asked to direct questions to the undersigned, who will not answer them.
>
> **§5. The grip.** Holders have described the additional grip as a ghost. The Provider rejects the description. The undersigned accepts it, and asks the Holder to let it carry something kind at least once.
>
> *A sergeant counted forty tins out and forty tins back, and none of them came back. It was the finest bookkeeping I have ever seen.*
> *— V.*

---

## 8. Blastproof Bock (`blastproof_bock`), 2000

| | |
|---|---|
| **Plan** | **LIABILITY WAIVER** · `DMS-VP-LIA-07` |
| **Machine, cap, ad, sounds** | As built: see `docs/gravelight/JINGLES.md` §8 (orange-and-black safe cabinet, Kaboomer the ram, *"THE LOUDER THE BETTER!"*). |
| **Prototype (Helvetia Works)** | Bare safe cabinet with the wheel-handle fitted. The porthole is empty. A bock-beer label is glued to the inside of the door, with one corner peeled, as if something was slipped behind it once. |

**The human: the Pionierschule detachment at Kaltenbrunn, and Res Gähwiler** *(§11 amendment, relocates the demolitions school from Dessau-Roßlau to its Kaltenbrunn field detachment)*. The Liability Waiver Plan was not one person's work. It was a favorite of the **Kaltenbrunn field detachment of the Pionierschule** (the engineer school headquartered at Dessau-Roßlau), which ran live-charge courses in the mine's worked-out galleries from 1942. It started life as a fragmentation-injury tonic. The detachment's instructors drank it before live-charge days, because it hardened the inner ear and lungs against overpressure and let a man shrug off a fall down a gallery. The instructors insisted on a spring bock: "if we must drink medicine, it will be beer." The formula card lists no single formulator, only the detachment's stamp. **Its importance is where it went.** In 1943, on a night run across the border, Res Gähwiler slipped a sample bottle and a copy of the formula card behind the label of a bock-beer crate. His cousin **Anni Gähwiler**, the SOE's Basel contact, passed it to London. **That bottle is how British intelligence first learned that Nachtglas exists**, and it is the root of Directive LANTERN's sealed orders ("retrieve at any cost"). Peg's SOE dossier records that her own demolitions instructor "tried a bottle, and found it disappointingly effective." Vendelin knew about the smuggled bottle. He had left the formula card on Res's seat.

**Music direction.** As built: a rowdy polka-rag with comic sound effects, vaudeville, 138 BPM, 2/4, F major. Honky-tonk piano, clarinet, tuba, washboard, slide whistle, timpani booms, a comic tenor, and a cheering crowd.
- **Pump-organ origin:** first written as a mock-solemn hymn on the Harmonium's full organ (*Tutti*). Vendelin played it as a warning, with a sudden stop where the boom is now: silence instead of an explosion. Darkmatter's note: *"Silence tested poorly. Insert boom."*
- **Organ ghost:** the hymn's final cadence, played once under the crowd's "KA-BOOM!"

**Canon jingle: "Blastproof Bock"**

> **Verse 1**
> `jingle.blastproof_bock.01` I lit the fuse at breakfast and I lit the fuse at lunch,
> `jingle.blastproof_bock.02` I sat upon a mortar shell, it gave me quite a punch!
> `jingle.blastproof_bock.03` I fell off the church tower and I landed on my head,
> `jingle.blastproof_bock.04` I said "well, pass the Bock, my friend" and toddled off to bed!
>
> **Chorus**
> `jingle.blastproof_bock.05` Blast-proof! (BOOM!) Blast-proof! (BOOM!)
> `jingle.blastproof_bock.06` Billy goat in a crater!
> `jingle.blastproof_bock.07` Blast-proof! (BOOM!) Blast-proof! (BOOM!)
> `jingle.blastproof_bock.08` Now it's sooner, never later!
> `jingle.blastproof_bock.09` Bang and boom and up and away,
> `jingle.blastproof_bock.10` blow the bridge and save the day,
> `jingle.blastproof_bock.11` Blast-proof, Blast-proof Bock!
>
> **Verse 2**
> `jingle.blastproof_bock.12` My mother said "be careful, son, you'll blow your eyebrows clean,"
> `jingle.blastproof_bock.13` I've lost them both a dozen times, they grow back extra green!
> `jingle.blastproof_bock.14` The colonel's lost his trousers and the cook has lost his pot,
> `jingle.blastproof_bock.15` but I have got my Blastproof Bock, so what's a little shot?
>
> **Chorus** (repeat .05–.11)
>
> **Tag (crowd)**
> `jingle.blastproof_bock.16` "KA-BOOM!" *(slide whistle up, comic thunk)*

**True first draft** (`jingle.blastproof_bock.80`: a **wordless** harmonium melody, folded in the bench lid, Oct 1943)

> A mock-solemn hymn on full organ (*Tutti*) that **stops dead** where the canon's boom is: a full bar of silence, then one quiet amen chord. Pencil note: *Abstand* (distance).

*Organ incipit:* I `F A C F` · II `B♭ D F D` · III `C E G C` · IV `F — — —` *(bar IV is a held F and then nothing; the organ step accepts the rest as the note)*

**Fine-print panel**

`panel.blastproof_bock`
> **HELVETIA AUTOMATEN AG · BASEL · CONDITIONS OF USE: BLASTPROOF BOCK**
>
> **§1. Waiver.** **By drinking, you waive liability for yourself.** The Holder acknowledges that he, and no other party, is responsible for any explosion he causes, attends, or is near.
>
> **§2. Benefit.** The Product protects the Holder from the blast of his own charges and from falls. It does not protect him from anyone else's charges, which remain the responsibility of the war.
>
> **§3. Courage.** The Product is not courage. It removes the reason for fear without removing the danger. The undersigned considers this the most dangerous Product in the catalogue.
>
> **§4. Distance.** The Product is not a substitute for distance. The Holder is reminded that the safest distance from a war is all of it.
>
> **§5. Labels.** The Provider prohibits the removal of labels from Product containers. The undersigned notes that labels peel easily in damp weather, and that the border crossing at night is very damp.
>
> **§6. Third parties.** Should a sample of this Product reach a foreign government, the Provider will hold its field unit responsible. The field unit accepts.
>
> *I left a card on a driver's seat and looked the other way. It is the only thing I have shipped that I am glad of.*
> *— V.*

---

## 9. Fine Print Fernet (`fine_print_fernet`), 2000 (NEW)

| | |
|---|---|
| **Plan** | **DISCLOSURE (unreleased prototype)** · `DMS-VP-DIS-X1` |
| **Availability** | Helvetia Works always. All other Gravelight maps after `fp_ch5_done` (profile unlock `gl_perk_fernet`). Counts toward the perk cap (6 since T-081). Effects and numbers are in `docs/gravelight/WEAPONS.md` §20. |
| **Cost** | 2000 (Vendelin's trait: 1800) |
| **Color** | bare steel, with a bitter-green `#3f5d3a` glass lens |

**Machine.** A tall, narrow cabinet, about 2.0 m, shaped like a pharmacist's poison cabinet crossed with a lectern. It is **bare steel**, never enamelled and **never brand-edited**, and **its plan ID is stencilled openly on the front**: `DMS-VP-DIS-X1 · DISCLOSURE`. Vendelin hid nothing on this one. Its front is a hinged brass **reading frame** holding a sheet of printed terms behind glass, and the type gets smaller toward the bottom until it's a grey blur. A big **magnifying lens** on a swing arm hangs over the sheet and drifts slowly down it, line by line. The bottle window is the lens's housing. There is no neon and no mascot. A hand-lettered card in the frame's corner reads *Fine Print Fernet · Amaro · Digestif*, in type so small it's legible only within 2 m.
- **Idle:** the lens arm creeps down the terms sheet, reaches the bottom, and swings back to the top with a soft *tick* every ~12 s. A paper-rustle loop.
- **Signature sound:** a heavy page turn on dispense, a pen-nib scratch, and a cork *thup* on cap-off.
- **Bottle cap:** black, with a green magnifying lens over three tiny white lines of text.
- **Prototype (Helvetia Works) and later maps:** the same bare cabinet everywhere. Vendelin finished it himself in his office in March 1944. The terms sheet in the frame is the panel text, readable from the front.

**Ad copy (never printed; the proof sits on Vendelin's desk):**
> **"READ BEFORE YOU SIGN."**
> *Fine Print Fernet: the bitter that tells you what's coming.*
> Small print, at normal size for once: *This product tells you what the others won't.*
> Darkmatter Marketing's violet stamp across the proof: **NOT FOR RELEASE: DISCLOSURE INCOMPATIBLE WITH RETENTION.**

**The human: Vendelin himself.** Fine Print Fernet is the only formula Vendelin made with no human formulator, because no human would have been allowed to. He built it in 1944 in the Formula Lab at Helvetia Works, after Hawkeye, as a direct answer to his own catalogue. A digestif is the bitter you drink *after* a meal to help you take in what you have already swallowed, and Vendelin thought that was exactly right. The base is a Ticino-style bitter amaro: myrrh, saffron, gentian, chamomile, and a great deal of mint to make it bearable. He had studied Basel apothecaries' recipe books for months to get it. It contains a trace of DARK-GLASS™ re-tuned *against* retention: instead of holding the drinker's last impulse in place, it sharpens the drinker's *noticing*. You see the timers on the incentives the Provider hands out. You see the hidden things the place doesn't want found glint at the edge of your eye, and you see the offers last a little longer, because they're waiting for someone who can read them. He submitted it to Darkmatter as a tenth Vitality Plan called **DISCLOSURE**. The Board refused it in one line, and he kept the refusal pinned above his desk: *"A Plan that discloses its own terms has no market."* He never shipped it. The single prototype stood in his office until 18 March 1945.

**Music direction.** A slow Ticino café-orchestra **tango-habanera**, 84 BPM, 2/4 habanera rhythm, D minor turning to D major on the last line of each chorus. Bandoneon, solo violin, pizzicato bass, a dry snare playing the habanera figure on the rim, and a clear male baritone singing close and conversationally, like a man telling you something over a café table. Band-limited to period (300 Hz–5 kHz) with soft crackle. *Tone:* the only jingle that sounds like it's on your side, and slightly sad about it.
- **Pump-organ origin:** written on the harmonium in one night in March 1944, on *Prinzipal 8'* with the tremulant on. It is **never brand-edited** (only Overclock shares that): the Board refused the Plan outright, so Marketing never touched the score. Vendelin paid the Basel orchestra himself for one test session. The canon jingle below is his own, unedited.
- **Organ ghost:** the tremulant D under the final spoken tag.

**Canon jingle: "Fine Print Fernet"** (Vendelin's own, unedited)

> **Verse 1**
> `jingle.fine_print_fernet.01` There's a paper on the table, and a pen beside your hand,
> `jingle.fine_print_fernet.02` and a gentleman is smiling like you ought to understand;
> `jingle.fine_print_fernet.03` there's a little line of letters, where the margin's growing small,
> `jingle.fine_print_fernet.04` and the gentleman would rather that you didn't look at all.
>
> **Chorus**
> `jingle.fine_print_fernet.05` Fine Print, Fine Print,
> `jingle.fine_print_fernet.06` bitter on the tongue,
> `jingle.fine_print_fernet.07` the kind of thing your grandmother would drink when she was young.
> `jingle.fine_print_fernet.08` Fine Print, Fine Print,
> `jingle.fine_print_fernet.09` one small glass will do,
> `jingle.fine_print_fernet.10` and all the little letters come up large enough for you.
>
> **Verse 2**
> `jingle.fine_print_fernet.11` Oh, the hour's on the clock-face, and the clock-face has a hand,
> `jingle.fine_print_fernet.12` and the gift upon the doorstep isn't staying where you planned;
> `jingle.fine_print_fernet.13` but a sip of something bitter and a squint of something wise,
> `jingle.fine_print_fernet.14` and the shine on what was hidden comes and sparkles in your eyes.
>
> **Chorus** (repeat .05–.10)
>
> **Bridge (violin solo under, sung softly)**
> `jingle.fine_print_fernet.15` Slow down, slow down, the offer can wait,
> `jingle.fine_print_fernet.16` the ink isn't dry and it isn't too late...
>
> **Final Chorus**
> `jingle.fine_print_fernet.17` Fine Print, Fine Print,
> `jingle.fine_print_fernet.18` read it through and through,
> `jingle.fine_print_fernet.19` and all the little letters come up large enough... for you.
>
> **Tag (spoken, the baritone, unhurried)**
> `jingle.fine_print_fernet.20` "Fine Print Fernet. Helvetia Automaten. Take your time."

**True first draft:** none separate. Fernet was never edited, so its canon *is* its first draft. `jingle.fine_print_fernet.80` is the wordless harmonium demo of the same melody.

*Organ incipit:* I `D F A F` · II `G B♭ D B♭` · III `A C♯ E A` · IV `D F♯ A D` *(used only by the Request Hour side egg; not in Clause Zero's target pool)*

**Fine-print panel** (back of cabinet; on the Helvetia prototype the same text also fills the front frame)

`panel.fine_print_fernet`
> **HELVETIA AUTOMATEN AG · BASEL · CONDITIONS OF USE: FINE PRINT FERNET**
> **(PROTOTYPE · NOT FOR RELEASE)**
>
> **§1. Benefit.** **This product tells you what the others won't.** It shows the Holder how long a gift will last, lets offers wait a little longer for him, and makes hidden things catch the light.
>
> **§2. Status.** This Plan was submitted to the Provider and refused. The Provider's reason is reproduced in full: *"A Plan that discloses its own terms has no market."* The undersigned has framed it.
>
> **§3. The other cabinets.** The Holder is advised that every other cabinet in this catalogue has a panel like this one on its back. Please read them. They were written for you, and you are, so far, the only one.
>
> **§4. Bitterness.** The Product is bitter. Truth usually is. Mint has been added. The undersigned could not make the truth itself any sweeter.
>
> **§5. What it cannot do.** The Product will show you a timer. It will not stop it. It will show you the hidden thing. It will not make you pick it up. It will show you the terms. It cannot make you refuse them.
>
> **§6. Cancellation.** You may refuse any Plan by not inserting a token. This is the only cancellation procedure the undersigned has ever been able to guarantee. It works every time it is tried. It is almost never tried.
>
> *I made one thing that does not take. Drink it slowly.*
> *— V.*

---

## 10. Overclock Cordial (`overclock_cordial`), 2500 (NEW)

| | |
|---|---|
| **Plan** | **SURGE (unreleased prototype)** · `DMS-VP-SRG-X2` |
| **Availability** | Helvetia Works always. All other Gravelight maps after `fp_ch5_done` (profile unlock `gl_perk_overclock`). Counts toward the perk cap (6 since T-081). Effects and numbers are in `docs/gravelight/WEAPONS.md` §20. |
| **Cost** | 2500 (Vendelin's trait: 2250) |
| **Color** | teal `#2fa8a0` and copper, with a violet spark |

**Machine.** **A tall cabinet crowned with a coil.** It stands 2.4 m, the tallest Helvetia cabinet. The body is **teal with copper bands**. Its crown is a copper **induction coil** on a ceramic collar that snaps a violet arc to a brass ball every few seconds. Copper cable loops down the sides like suspenders. The bottle window is a round porthole with a needle gauge above it marked *LEER · HALB · VOLL* (EMPTY · HALF · FULL), and the needle swings when a player reloads nearby. The neon reads **OVERCLOCK** in tall electric-zigzag capitals, with *Cordial* in round friendly script underneath.
- **Mascot: "Funki,"** a cheerful little round bin-shaped robot with a hinged lid for a hat, big round eyes, one antenna, and a lightning bolt held proudly overhead like a torch. Vendelin drew him in April 1944 as a generic "spark" robot, a year before he met Sprocket, and Funki looks *uncannily* like Sprocket anyway. The Ch. 5 script may let Bolt notice.
- **Idle:** the coil arcs on a randomized 3–7 s timer, the valves pulse, and the gauge needle twitches to *VOLL* whenever a player within 6 m finishes a reload.
- **Signature sound:** a capacitor whine rising on dispense, a fat electric *ZAP* on cap-off, and a tiny two-tone robotic *bee-boop* (added on Helvetia Works, from Sprocket's reading).
- **Bottle cap:** teal with a copper lightning bolt and two small round "eyes."
- **Prototype (Helvetia Works):** the cabinet has stood on the Jingle Room test bench since April 1944 as an **unfinished blueprint** with an empty active-principle chamber (`docs/TIMELINE.md`). On the night of 17–18 March 1945 Vendelin completes it with fresh solder and a **live, short-range reading** of a far-future robot's firmware (Sprocket's, "on loan"). That's why it works on Helvetia Works while Sprocket is in the building. The **full scan**, taken at the end of The Fine Print Ch. 5, is what lets the Plan ship to every other Gravelight map afterward. The plan ID, stenciled in haste, is slightly crooked.

**Ad copy (one proof, typed by Vendelin in April 1944, never sent):**
> **"A LITTLE SPARK OF PERSONALITY."**
> *Overclock Cordial: the cordial with character.*
> Small print: *Contains trace amounts of personality.*

**The human: no human. A friend.** Overclock Cordial is the only Plan made from a scan of a *machine*. Vendelin had drawn the cabinet in April 1944 around an idea he could not fill: a Plan whose active principle was *refusal*, the impulse to keep going after the reserves are spent. He had no source for it; no product he had ever met refused anything. On the night of 17–18 March 1945, he met another field unit for the first time in more than six years: a far-future refund-bin robot called Sprocket, with a firmware clause of his own (Clause 44) that he had chosen to ignore. The reading did not capture the override; it captured the *surge*. Sprocket's whole personality turns out to discharge in a spike every time his reserves run low and he refuses to stop, which, Vendelin noted, "is what an empty magazine is." Vendelin built that spike into a cordial: every reload releases a static burst, and the emptier the magazine, the bigger the burst. He had registered the blueprint as the **SURGE** Plan in 1944, purely so the Board would have to see that something had come out of Sol-3 that they had not designed. In The Fine Print Ch. 5, Bolt: *"Is that... Sprocket-flavored?"* Sprocket: *"I'm EXTREMELY flattered and I want royalties."* Those lines belong to the Ch. 5 script in `docs/fineprint/`; this doc only quotes the brief.

**Music direction.** An **electric novelty swing**, 152 BPM, 4/4 with a shuffle, B♭ major. Hammond-era **Novachord** lead (the 1939 polyphonic electric organ) doubled by clarinet, walking upright bass, brushed snare, muted trumpet "wah" stabs, a **theremin** swooping between phrases, and a percussion layer of struck radio valves, typewriter carriage-returns and spark-gap snaps. A bright, quick female vocalist with a small chirpy "robot" voice answering her, a vocoder-like sound made by singing through a cardboard tube into a telephone receiver. *Tone:* the only jingle that is genuinely delighted.
- **Pump-organ origin:** written with the blueprint in April 1944, on the harmonium's top two octaves with the *Flöte 4'* and *Oktav 2'* stops, which Vendelin had never used together: too bright, he had always thought. The Plan was never released, so the score was never brand-edited. One test pressing exists, with Vendelin himself as the "robot" voice through a telephone receiver.
- **It cannot resolve.** The melody's last note is the harmonium's **cracked F♯ reed**, so every performance stops on a hanging, sour F♯ with no final chord. **Until the profile holds `fp_ch5_done`, every Overclock jingle on every map ends unresolved** (the tag's last *bee-boop* is cut). After The Fine Print Ch. 5, the final chord sounds (B♭ major, Sprocket's off-key bass under it).
- **Organ ghost:** a Flöte-and-Oktav trill under the robot's "bee-boop" in the tag.

**Canon jingle: "Overclock Cordial"**

> **Verse 1**
> `jingle.overclock_cordial.01` When your magazine's a-rattle and your last round's in the air,
> `jingle.overclock_cordial.02` and the fellow at your elbow's got a most unfriendly stare,
> `jingle.overclock_cordial.03` don't you fumble, don't you falter, don't you panic, don't you stall,
> `jingle.overclock_cordial.04` just a little drop of Cordial and you'll light up like a hall!
>
> **Chorus**
> `jingle.overclock_cordial.05` O-ver-clock! (Bzzt!) Cordially yours!
> `jingle.overclock_cordial.06` A spark in the barrel and a storm out the doors!
> `jingle.overclock_cordial.07` The emptier the drum, why, the bigger the bang,
> `jingle.overclock_cordial.08` with a crackle and a fizzle and a zing-zing-zang!
> `jingle.overclock_cordial.09` O-ver-clock! (Bzzt!) Turn it up to ten!
> `jingle.overclock_cordial.10` Run it down to nothing, and then light it up again!
>
> **Verse 2**
> `jingle.overclock_cordial.11` Now the boffins in their bowlers say a man is meat and bone,
> `jingle.overclock_cordial.12` but there's lightning in a fellow when he's down to his own,
> `jingle.overclock_cordial.13` so be stubborn, be contrary, be the last one in the fight,
> `jingle.overclock_cordial.14` it's a cordial with a character, and the character is bright!
>
> **Chorus** (repeat .05–.10)
>
> **Break (theremin solo; robot voice answering the singer)**
> `jingle.overclock_cordial.15` (Singer) Who's the spark in the cabinet? (Robot) Me!
> `jingle.overclock_cordial.16` (Singer) Who's the voltage in the tea? (Robot) Me!
> `jingle.overclock_cordial.17` (Singer) Who's the friend who won't switch off? (Robot) ...Me!
>
> **Final Chorus** (repeat .05–.10)
>
> **Tag (robot voice, very pleased with itself)**
> `jingle.overclock_cordial.18` "Overclock Cordial! Contains trace amounts of personality! *Bee-boop.*"

**True first draft** (`jingle.overclock_cordial.80`: wordless, April 1944): the same melody as the canon, played alone on the harmonium. It stops on the cracked F♯ like everything else in this Plan.

*Organ incipit:* I `B♭ D F B♭` · II `E♭ G B♭ G` · III `F A C F` · IV `B♭ F B♭ F♯` *(bar IV ends on the cracked F♯ reed; not in Clause Zero's target pool)*

**Fine-print panel**

`panel.overclock_cordial`
> **HELVETIA AUTOMATEN AG · BASEL · CONDITIONS OF USE: OVERCLOCK CORDIAL**
> **(PROTOTYPE · REGISTERED, NOT RELEASED)**
>
> **§1. Benefit.** On reloading, the Holder releases a burst of static charge. The burst is larger the emptier the Holder's weapon was. The Provider describes this as "surge." The undersigned describes it as refusing to stop.
>
> **§2. Origin.** **Contains trace amounts of personality.** The active principle of this Product was recorded, with permission, from a unit not of this world and not of this year. That unit is not inventory. Neither is his personality. It is lent.
>
> **§3. Royalties.** The originating unit has requested royalties. The undersigned has no currency the unit would recognise and therefore pays in the only one available: this acknowledgement, and his thanks.
>
> **§4. Side effects.** Holders may experience optimism, contrariness, a raised voice, and an urge to make remarks. These are not defects.
>
> **§5. Compatibility.** The Product discharges against machinery with particular force. The Provider's machinery is advised to keep its distance.
>
> **§6. Clause.** Field units are subject to a recall clause. The undersigned has recently learned that a clause is not a law of nature. It is a sentence. Sentences can be left unfinished.
>
> *He hummed the bass line wrong. I left it in.*
> *— V.*

---

## 11. Data hooks (for `data/gravelight/perks/*.json`)

| perk_id | `jingle_lines` | `true_draft` | `panel` | `plan_id` | `organ_incipit` (4 bars) |
|---|---|---|---|---|---|
| `ironhide_stout` | .01–.17 | .80 (wordless) | `panel.ironhide_stout` | DMS-VP-DUR-01 | see §1 |
| `second_wind` | .01–.13 | .80 (wordless) | `panel.second_wind` | DMS-VP-CON-00 | see §2 |
| `trigger_tonic` | .01–.16 | .80 (wordless) | `panel.trigger_tonic` | DMS-VP-THR-02 | see §3 |
| `twin_barrel` | .01–.15 | .80 (wordless) | `panel.twin_barrel` | DMS-VP-VEL-03 | see §4 |
| `marathon_malt` | .01–.16 | .80 (wordless) | `panel.marathon_malt` | DMS-VP-MOB-04 | see §5 |
| `hawkeye_brandy` | .01–.16 | .80 (wordless) | `panel.hawkeye_brandy` | DMS-VP-FOC-05 | see §6 |
| `packmule_porter` | .01–.18 | .80 (wordless) | `panel.packmule_porter` | DMS-VP-CAP-06 | see §7 |
| `blastproof_bock` | .01–.16 | .80 (wordless) | `panel.blastproof_bock` | DMS-VP-LIA-07 | see §8 |
| `fine_print_fernet` | .01–.20 | .80 (wordless) | `panel.fine_print_fernet` | DMS-VP-DIS-X1 | see §9 |
| `overclock_cordial` | .01–.18 | .80 (wordless) | `panel.overclock_cordial` | DMS-VP-SRG-X2 | see §10 |

**Organ incipit format:** each bar is up to 4 note glyphs (`—` = rest/hold). The Clause Zero organ step (`docs/gravelight/EASTER_EGGS.md` §7.2, step 4) builds its punch-roll glyphs from these bars, so the bars must stay distinct across machines. The table above is that check: no two machines share a full 4-bar incipit.

**Power-on "carnival tuning" (Map 1, as built):** unchanged. On Helvetia Works, power-on plays the *organ ghosts* of all ten machines in sequence on the factory PA instead (see `docs/gravelight/MAPS.md`, Helvetia Works power-on).

---

## 12. Helvetia Works hidden song: "Nobody Has To"

*Unlock:* the Helvetia Works side egg "Test Pressings" (`docs/gravelight/EASTER_EGGS.md` §8.3): three shellac test pressings played on the Jingle Room gramophone.
*Credit:* "Nobody Has To": original composition, TERMS & CONDITIONS (placeholder audio until recorded).
*Style:* a hymn-like ballad that builds from the bare Harmonium into a full 1940s studio orchestra. Verse 1 is solo Harmonium (Vox Humana) and one hesitant male voice: Vendelin's own, synthesized through a coin-slot speaker grille, slightly flat and very careful. Verse 2 adds a bandoneon and a woman's alto (credited in the Archive only as "a nurse"). The bridge brings in the Basel dance orchestra's strings. The last chorus is everyone: brass, a church-choir swell, and the ten machines' organ ghosts woven through as counter-melodies. *Tempo:* 70 BPM, 3/4. *Key:* F major (Second Wind's key, on purpose). *Length:* ~4:00.
*Lore:* Vendelin's one jingle for no product. The Archive card calls it *"Demo for unassigned Plan · Darkmatter review: REJECTED (no call to action)."*

> **Verse 1 (Harmonium, one voice)**
> `jingle.hw_song.01` I built a box to sell you breath, I built a box for speed,
> `jingle.hw_song.02` I built a box for every kind of thing a man could need,
> `jingle.hw_song.03` I wrote a song for every box and taught you how to sing,
> `jingle.hw_song.04` and in the back of every box I wrote the other thing.
>
> **Chorus**
> `jingle.hw_song.05` Nobody has to. Nobody has to.
> `jingle.hw_song.06` Put the token back in your coat.
> `jingle.hw_song.07` Nobody has to. Nobody has to.
> `jingle.hw_song.08` That is the only true line I wrote.
>
> **Verse 2 (adds alto, bandoneon)**
> `jingle.hw_song.09` A brewer drank the first one so the boys would not go first,
> `jingle.hw_song.10` a nurse put honey in it so the dying weren't the worst,
> `jingle.hw_song.11` a sergeant counted forty tins and none of them came back,
> `jingle.hw_song.12` and I kept every one of them, in pencil, on the back.
>
> **Chorus** (repeat .05–.08)
>
> **Bridge (strings enter)**
> `jingle.hw_song.13` They told me I was inventory. They told me I was stock.
> `jingle.hw_song.14` They told me that the reason for a song is the lock.
> `jingle.hw_song.15` But a little bin of tin came singing out of the light,
> `jingle.hw_song.16` and he hummed the bass line wrong, and it was right.
>
> **Final Chorus (full orchestra and the ten organ ghosts)**
> `jingle.hw_song.17` Nobody has to. Nobody has to.
> `jingle.hw_song.18` Not the boy, not the nurse, not me.
> `jingle.hw_song.19` Nobody has to. Nobody has to.
> `jingle.hw_song.20` Read the back. And then you're free.
>
> **Outro (Harmonium alone, the one voice)**
> `jingle.hw_song.21` ...nobody has to.

*Composer note:* the last organ chord leaves the third out (an open fifth, F–C), then adds it a beat late, as if someone else reached over and pressed the key. That is Sprocket; the Archive credit lists him as "bass (uncredited)."

---

## 13. GRAVELIGHT Map 0 song: "Drei Kusinen", the Cousins' clapping rhyme (HB1; `docs/HOMAGE_BOSSES.md` §9–§10)

*Use:* the Cousins Round on Map 0 (round 10). Hummed during the setup and while all three live, whispered after the first death, sung by the last one standing; one last line in the ice cellar afterwards (`CSN_LASTLINE_01`). Not a Helvetia jingle: no machine, no plan ID, no organ ghost, no fine print. *Credit:* "Drei Kusinen": original composition, GRAVELIGHT (placeholder audio until recorded). *Speaker ids for credits/data:* `cousins_rhyme` (three stems, `CSN`).
*Style:* a children's clapping game sung by three young women in the dark, unaccompanied at first; in the fight it sits over a toy-piano and music-box bed (D minor; never Liesl's music box). *Tempo:* 92 BPM, 4/4. *Key:* D minor, the last line landing on the major third, wrong and bright.

- **Original:** words and melody are new, written for GRAVELIGHT. It counts **down from three**, with **a verse per cousin**, and it ends *"...and whoever's left is IT."*
- **In-game:** the **German** version, subtitled with the English one.
- **Delivery:** it is **hummed** (the setup and the trio alive), then **whispered** (after the first death), then **sung** (the last one standing, alone, with gaps where the dead cousins' lines would be).
- **Rhythm:** a clapping game in 4/4 at 92 BPM. Each beat is: thigh-pat, clap, cross-clap with a partner, clap.

Line ids `jingle.cousins_rhyme.NN`. German first, the singable English beneath.

> **Drei (Three): the Hammer**
> `jingle.cousins_rhyme.01` Drei Kusinen unterm Haus,
> *Three little cousins under the floor,*
> `jingle.cousins_rhyme.02` eine geht zum Holzhacken raus.
> *one ran out to chop by the kitchen door.*
> `jingle.cousins_rhyme.03` Wirf den Hammer, rund herum,
> *Throw it high and round it comes,*
> `jingle.cousins_rhyme.04` fang ihn auf und bleib schön stumm.
> *catch it home in mittened thumbs, and hush.*
>
> **Zwei (Two): the Reach**
> `jingle.cousins_rhyme.05` Zwei Kusinen unterm Haus,
> *Two little cousins under the floor,*
> `jingle.cousins_rhyme.06` eine streckt die Arme aus,
> *one reached for the jam jar, a little bit more,*
> `jingle.cousins_rhyme.07` bis zum Glas im obern Fach,
> *stretch it, stretch it, over the shelf,*
> `jingle.cousins_rhyme.08` länger als das ganze Dach.
> *longer than the whole house itself.*
>
> **Eine (One): Alix**
> `jingle.cousins_rhyme.09` Eine Kusine unterm Haus,
> *One little cousin under the floor,*
> `jingle.cousins_rhyme.10` hält die Hand zur Tür hinaus.
> *holds out her hand to the cellar door.*
> `jingle.cousins_rhyme.11` Halt sie fest und lass nicht los,
> *Hold it, hold it, don't let go,*
> `jingle.cousins_rhyme.12` Tante kommt — wo bleibt sie bloß?
> *Auntie's coming. Auntie's slow.*
>
> **Keine (None): all three, or whoever is left**
> `jingle.cousins_rhyme.13` Klatsch im Dunkeln, guck nicht hin,
> *Clap in the dark and don't you peek,*
> `jingle.cousins_rhyme.14` keine mehr im Keller drin.
> *nobody laughs and nobody squeaks.*
> `jingle.cousins_rhyme.15` Eins, zwei, drei, die Kerze an...
> *Three, two, one, the candle's lit...*
> `jingle.cousins_rhyme.16` ...und wer noch übrig ist, ist DRAN.
> *...and whoever's left is IT.*

**Literal sense of the German** (for the translator and the subtitle pass):
- Verse 1: "Three cousins under the house, / one goes out to chop wood. / Throw the hammer, round and round, / catch it and keep quiet."
- Verse 2: "Two cousins under the house, / one stretches her arms out, / up to the jar on the top shelf, / longer than the whole roof."
- Verse 3: "One cousin under the house / holds her hand out of the door. / Hold it tight and don't let go, / Auntie's coming. Wherever can she be?"
- Verse 4: "Clap in the dark, don't look, / no one left in the cellar. / One, two, three, the candle's lit... / and whoever is still left is IT."

The English is the singable adaptation; the German is canon. (*Dran sein* is "to be it" in a children's game.)

**Stems:** A = the Hammer (the melody, low, steady), B = the Reach (a high harmony a third above, breathy), C = Alix (a drone on the tonic, almost spoken). The stems mute as each cousin dies. In the solo verse, the survivor sings only her own verse's lines and the final verse. During the dead cousins' verses there are **four bars of clapping and nothing else**.

### 13.2 Homage boss stingers and musical moments (HB1–HB3)

- **Title-card sting (all bosses):** a rubber-stamp thunk on the downbeat, a ledger-bell ding, then a 3 s phrase in each boss's colour.
- **The Cousins:**
  - **Setup:** the lamps' breath-outs on the beat of the rhyme's tempo, then silence, then the clapping.
  - **Fight:** the three stems over a toy-piano and music-box bed (D minor, distinct from Liesl's music box, which is never used here), with a low tape-warble that slows as each cousin dies.
  - **Clear:** the bed stops mid-bar; one music-box note decays; the lamps relight.
- **PAUL:**
  - **Arrival:** a brass-and-war-drum cue, with the clink of stout bottles as percussion and his roar layered with a **distorted human voice** inside it (v3 §5).
  - **Stages:** each stage adds a layer (Angry: a low brass ostinato; Berserk: a steam-whistle shriek on the downbeat).
  - **Death:** everything cuts to a **solo trumpet playing an original 6-note bugle-like phrase**. **Not "Taps"**: no recognisable bugle call.
- **THE SLENDER:**
  - **Bed:** almost nothing. A slow pulse of violin harmonics, wind in the pines, and **his keys as the rhythm section**.
  - **Before he attacks the keys stop**, and the silence is the cue: the mix ducks the ambient −6 dB in that 0.6 s.
  - **The Watch Room:** no music; a clock that **doesn't** tick; your own breathing.
  - **Death:** the lantern's hiss going out, then a single, warm major chord (the first in the map's score) as the sky reddens.
