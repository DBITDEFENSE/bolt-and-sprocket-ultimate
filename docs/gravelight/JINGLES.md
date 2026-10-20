# GRAVELIGHT: Jingles, Machines & Songs

> **SUPERSEDED (TERMS & CONDITIONS, §11):** the perk formula stories, founding history and plan IDs in this file are superseded by `docs/JINGLES.md` and `docs/CANON.md`. The jingle lyrics here are kept verbatim there. This file stays for history only.


All lyrics, slogans, mascots and melodies here are original to GRAVELIGHT. Until a composer delivers real recordings, every jingle ships as **placeholder audio**: silence markers or a TTS/MIDI sketch routed through `AudioDirector` on the `Jingles` bus.

## Helvetia Automaten AG: house style

**Helvetia Automaten AG**, Basel, Director **Konrad Imhof**. Founded 1921 to make chocolate and cigarette dispensers. In 1940 it won a contract through a Zürich holding company to build coin-op tonic dispensers "for the comfort of mining and research personnel." Imhof never asked what the tonics were. The company's motto is stamped on every machine's base plate:

> **HELVETIA AUTOMATEN AG · BASEL · "Ein Griff, ein Genuss" (One pull, one pleasure)**

Shared machine traits:
- **Shell:** an enamelled steel cabinet about 2.1 m tall, with a chrome trim strip, a glass bottle-window, and a Scrip slot shaped like a tally mark (`ǂ`) where a coin slot would be. The coin slots were re-milled after the Ledger came online.
- **Neon:** a top sign in the perk's color. Unpowered machines are dark, with only a faint Nachtglas violet glow behind the glass.
- **Proximity behavior:** within 6 m the machine hums its jingle's root note. Within 3 m there is a 1-in-4 chance per 60 s (global cooldown 45 s across all machines) that it plays a 6–10 s jingle excerpt. The full jingle plays on purchase while the bottle is dispensed (~4.5 s). The full song is an easter-egg-style "listen" interaction at a power-on machine: hold Interact for 3 s with no cost. It is never forced.
- **Dispense sounds (shared layers):** a coin-mech clunk, a gravity chute rattle, a glass clink, and a cap pop. Each perk adds a signature tag (below).
- **Bottle-cap HUD icons:** 64 px round crimped caps, with stamped tin texture and a two-color print. Unique caps are listed per perk.

---

## 1. Ironhide Stout (`ironhide_stout`), 2500

**Machine:** Squat and broad, shaped like a barrel stood on end with iron hoops riveted around it. Enamel is **iron-red**, with blackened steel hoops and brass rivets. The neon reads **IRONHIDE** in heavy slab letters over a smaller script line *Stout · Stark · Standhaft*. Mascot: **"Fassl,"** a cheerful riveted barrel with stubby arms flexing a bicep and a hobnail boot on one barrel-end. **Idle:** Fassl's painted arm is a tin cut-out that slowly flexes, and steam vents puff from a side valve every ~8 s. **Signature sound:** a deep cooper's mallet *thunk* on dispense and a low barrel-creak idle loop.

**Bottle cap:** iron-red with a black riveted ring and a white silhouette of Fassl's flexed arm.

**Ad copy (1941 poster):**
> **"BUILT LIKE A BARREL. FEELS LIKE ONE TOO."**
> *Ironhide Stout: for the man who meets the world head-on.*
> Small print: *Not for children, horses, or officers above Hauptmann. Helvetia Automaten AG accepts no liability for walls, doors, or persons walked through.*

**Formula backstory:** The raw tonic was developed for **assault engineers** (*Sturmpioniere*) who had to cross fire-swept ground. Its first form tasted, by one report, "like licking a cannon." **Otto Kessler**, a conscripted Bavarian brewmaster from Freising, was pulled out of a field kitchen and told to make it drinkable. He suspended it in a heavy roast stout and added smoked malt to hide the metallic edge. He sent his recipe notes home to his wife disguised as beer orders. In one of them he writes that the volunteers "stopped feeling the cold, and then stopped feeling the shrapnel, and then I stopped sleeping." His notes are an Intel Archive document.

**Jingle: "Ironhide Stout"**
*Style:* Bavarian beer-hall oom-pah march. *Tempo:* 112 BPM, 2/4. *Key:* B♭ major. *Instrumentation:* tuba, two trumpets, snare, glockenspiel, male chorus shouting the "HEY!" hits, accordion fills. Recorded "through a tin horn" (band-limited 300 Hz–4 kHz, light crackle).

> **Verse 1**
> When the shells come down like hail, boys,
> and the wire's strung up tight,
> don't you fret and don't you flail, boys,
> pull a pint and stand upright!
>
> **Chorus**
> Iron-hide, iron-hide, (HEY!)
> hoops of steel around your middle!
> Iron-hide, iron-hide, (HEY!)
> hit me once? Why, that's a riddle!
> One more knock, and one more after,
> drink it down and roar with laughter.
> Ironhide Stout!
> (Stout! Stout!) The door's knocked out!
>
> **Verse 2**
> Mother said I'd break my head, boys,
> Father said I'd crack my spine,
> now I sleep on nails instead, boys,
> and the nails say I'm just fine!
>
> **Chorus**
>
> **Tag (spoken, cheerful announcer)**
> "Ironhide Stout, by Helvetia Automaten. One pull, one pleasure!"

---

## 2. Second Wind Schnapps (`second_wind`), 500 solo / 1500 co-op

**Machine:** Tall and slender like an apothecary cabinet, with a domed glass top holding a slowly turning bottle. Enamel is **pale blue** with white-cross panels, cream trim and a frosted-glass window. The neon reads **SECOND WIND** in thin script over a small white cross. Mascot: none on the cabinet, which is unique. Instead a hand-painted **swallow** in flight is painted over the factory decal. A careful observer can see the factory decal underneath, an angel with a trumpet. **Idle:** the dome bottle rotates, and a tiny bellows wheezes like slow breathing every 5 s. **Signature sound:** a soft breath-in *hhhh* and a gentle chime on dispense. **Solo logic:** after the third self-revive, the machine powers down with a long exhale and sinks into the floor (see GDD).

**Bottle cap:** pale blue with a white swallow and a thin red rim.

**Ad copy (1940 pamphlet):**
> **"BREATHE AGAIN."**
> *A clean Alpine schnapps for the weary and the winded.*
> Small print: *Take with water. Do not take with despair. Approved for medical orderlies only.* (The word "orderlies" is crossed out in pencil on the in-world copy, and **"Häftlinge"** (prisoners) is written in.)

**Formula backstory:** The base tonic was a failed resuscitation compound that kept the dead twitching, not the living breathing. **Sister Agnieszka Wróbel**, a Polish nurse in the forced-labor infirmary, was ordered to "stabilize it for staff use." She quietly cut it with juniper, honey and a reduction of her own design. That made it bring the *collapsed* back, not the dead. She then diverted bottles to exhausted laborers so they'd survive selections. She painted the swallow over the angel. Wren recognizes the swallow, because Agnieszka sent it as a sign on smuggled notes to the Home Army. Her fate is unknown and is a hook for Map 2.

**Jingle: "Second Wind"**
*Style:* close-harmony barbershop quartet, lullaby-slow. *Tempo:* 72 BPM, 3/4 waltz. *Key:* F major. *Instrumentation:* four voices a cappella with a single music-box line under the chorus. Very gentle, almost kind. It is the one jingle that doesn't sound like an advert.

> **Verse 1**
> When the lamps are guttering low, dear,
> and the floor is cold as stone,
> don't you close your eyes and go, dear,
> you were never meant to go alone.
>
> **Chorus**
> Second wind, second wind,
> little swallow, home again,
> one more breath and up you climb,
> second wind, and one more time.
>
> **Verse 2**
> I have counted every heartbeat,
> I have warmed your hands in mine,
> there's a road beyond the dark, sweet,
> and the morning's coming fine.
>
> **Chorus**
>
> **Coda (single soprano, spoken-sung)**
> "...and one more time."

*Composer note:* in Polish-language builds (or as an EE variant) the last line can be sung as *"...jeszcze raz."*

---

## 3. Trigger Tonic (`trigger_tonic`), 3000

**Machine:** Lean and angular like an upright ammunition crate on legs, with a big chrome lever on the side that does nothing. Enamel is **lime-gold** with black chevron stripes and a sunburst-pattern glass window. The neon reads **TRIGGER TONIC!** in jittery italic letters that flicker in sequence. Mascot: **"Flitzi,"** a frantic cartoon hare with pinwheel eyes, an ammo belt over each shoulder, holding a spent magazine in each paw and sweating. **Idle:** Flitzi's paws are on a cam motor and blur back and forth. The fizz in the bottle window constantly bubbles. **Signature sound:** a rapid *chk-chk-chk* bolt-cycling ratchet on dispense, carbonated hiss, and a cartoon *boing*.

**Bottle cap:** lime-gold with a black hare head in profile and motion lines.

**Ad copy (1942 magazine insert):**
> **"FASTER THAN A FOX WITH A FIRECRACKER!"**
> *Trigger Tonic: the fizz that keeps the barrels busy.*
> Small print: *Side effects may include rapid blinking, rapid speech, rapid gratitude. Do not operate pianos.*

**Formula backstory:** Developed for **MG crews** to cut barrel-change and belt-feed time. Loaders on stimulant trials could change a barrel in under four seconds but couldn't stop moving their hands for hours afterward. The fizz was added by Helvetia's own flavor chemist to "convey energy." The lime-gold color is the company's guess at what "speed" looks like.

**Jingle: "Trigger Tonic!"**
*Style:* manic jump-swing / jive, cartoon-short tempo. *Tempo:* 208 BPM, 4/4. *Key:* E♭ major. *Instrumentation:* clarinet lead, slap bass, brushed snare at full gallop, trumpet stabs, xylophone runs. A fast-patter female vocalist with a comic male "hare" voice answering.

> **Verse 1**
> Click-clack, clip's out, hurry up, quick,
> slap a fresh one in and give it a lick!
> No time for dawdling, no time to dream,
> run like the hare in the ad on the screen!
>
> **Chorus**
> Trigger Tonic! (Zip-zip!)
> Faster than a sneeze!
> Trigger Tonic! (Zip-zip!)
> Fill your mags with ease!
> Gold and green and fizzing bright,
> reload the morning, reload the night,
> Trig-ger To-NIC!
>
> **Verse 2**
> Grandpa took a week to load a muzzle and a ball,
> I'll load a hundred while he's waddling down the hall!
> Barrel's hot and belt is long and fingers flying free,
> Flitzi says "you're slower than a cup of chamomile tea!"
>
> **Chorus**
>
> **Tag (hare voice, sped-up)**
> "Gotta-go-gotta-go-gotta-go!"

---

## 4. Twin Barrel Bitters (`twin_barrel`), 2000

**Machine:** A double-column cabinet with twin cylindrical towers like a side-by-side shotgun stood on its butt, joined by a brass bridge with the bottle window. Enamel is **amber** with walnut-wood side panels and brass trim. The neon reads **TWIN BARREL** over a slab-serif *Bitters*, and the two O's in "BITTERS" are drawn as muzzles. Mascot: **"Feldwebel Pomp,"** a mustachioed artillery sergeant with enormous handlebar moustaches, firing two pistols at once, chest out, medals clanking. **Idle:** a little tin Pomp on top fires his pistols in turns with tiny cap-gun flashes and pops. **Signature sound:** a double *ka-CHUNK* on dispense, cap-gun pops, and a brass-band "ta-da" sting.

**Bottle cap:** amber with two crossed black barrels and a white moustache beneath them.

**Ad copy (1941 poster):**
> **"WHY SAY IT ONCE WHEN YOU CAN SAY IT TWICE?"**
> *Twin Barrel Bitters: a sergeant's tonic, double strength.*
> Small print: *Recommended by eight out of ten ordnance officers. The other two could not be reached.*

**Formula backstory:** Formulated by **Major Rüdiger Strohwald**, an ordnance officer obsessed with rate of fire. He reasoned that if the shooter's nerves fired faster, the weapon would too. He tested it on himself first and kept a diary of increasingly cramped handwriting, until the final entry is a single word repeated for two pages. The bitters are gentian, orange peel and a little Nachtglas tincture, aged in artillery-shell casings.

**Jingle: "Twin Barrel Bitters"**
*Style:* military brass-band march with music-hall swagger. *Tempo:* 126 BPM, 6/8. *Key:* D major. *Instrumentation:* full brass band, bass drum on every beat, cymbal crashes, piccolo trill on the hook, and a baritone singer who can't stop hammering every consonant. Optional crowd "BANG BANG!" responses.

> **Verse 1**
> The sergeant's got a moustache, and the moustache has a twin,
> he's got two hands for shooting and two grins to wear a grin!
> He never says a thing just once, he says it twice instead,
> and when he says it twice, my boy, the enemy is dead!
>
> **Chorus**
> Twin, twin, Twin Barrel Bitters! (BANG BANG!)
> Twice the bark and twice the bite!
> Twin, twin, Twin Barrel Bitters! (BANG BANG!)
> Double up and do it right!
> Amber in the bottle and a fire in the vein,
> fire once, then fire twice, and fire again!
>
> **Verse 2**
> He's got two medals on his chest, he's got two boots that shine,
> he's got two wives in two towns and he says they both are fine!
> He drank a bottle in the morning and another one at tea,
> now he fires at the speed of light and so, by God, can we!
>
> **Chorus**
>
> **Tag (two voices in unison)**
> "Twin Barrel! Twin Barrel!"

---

## 5. Marathon Malt (`marathon_malt`), 2000

**Machine:** Tall and streamlined, Art Deco teardrop-shaped like a racing locomotive's nose stood upright, with chrome speed-lines down the sides. Enamel is **sky blue and white** with chrome. The neon reads **MARATHON MALT** in forward-slanting letters with motion streaks. Mascot: a **winged boot** (a laced infantry boot with white feathered wings at the ankle), always mid-stride. **Idle:** a little treadmill belt under the boot emblem endlessly rolls, and wind-whistle sounds come from vents. **Signature sound:** a *whoosh* on dispense, a running-feet patter, and a crisp starter-pistol pop on cap-off.

**Bottle cap:** sky blue with a white winged boot and a chrome-silver rim.

**Ad copy (1940 sporting gazette):**
> **"THE ROAD IS LONG. YOUR LEGS ARE LONGER."**
> *Marathon Malt: brewed for those who never stop.*
> Small print: *Helvetia Automaten AG is not responsible for distances covered after consumption. Consult a cobbler.*

**Formula backstory:** Formulated for **battlefield runners**, the message-carriers who crossed open ground when wires were cut. The chemist, **Dr. Hanne Ostrowski**, was a former Olympic-track physiologist. Her test subjects ran until their hearts gave out, and some kept running a short while after. Her lab journal records that she quit. The facility records that she was "transferred." The malt base is a sweet Munich-dunkel concentrate meant to replace calories as fast as they burned.

**Jingle: "Marathon Malt"**
*Style:* bright Hollywood-musical gallop / show tune. *Tempo:* 160 BPM, 2/2 (cut time). *Key:* G major. *Instrumentation:* strings sawing in running eighths, xylophone, horn calls, and a clip-clop percussion "footsteps" loop. A female trio sings in tight three-part harmony with a male tenor "coach" shouting the counts.

> **Verse 1**
> Up with the dawn and over the hill,
> past every farm and the water mill,
> the sergeant's tired and the mule is lame,
> but I keep running all the same!
>
> **Chorus**
> Marathon Malt! (Hup! two! three!)
> Wings upon your heel!
> Marathon Malt! (Hup! two! three!)
> Legs as strong as steel!
> Run to the river, run to the sea,
> run till the world is a memory,
> Marathon, Marathon Malt!
>
> **Verse 2**
> My boots have wings and my wings have boots,
> I've outrun bullets and the fruit-cart brutes,
> they'll put my name in the record books,
> if they can catch me long enough to look!
>
> **Chorus**
>
> **Tag (coach voice, out of breath)**
> "Don't... stop... running!"

---

## 6. Hawkeye Brandy (`hawkeye_brandy`), 1500

**Machine:** An upright cabinet with a periscope-like tower on top, ending in a glass lens that slowly swivels to "look" at the nearest player. Enamel is **deep forest green** with brass and a polished-walnut front. The neon reads **HAWKEYE** in elegant capitals with a stylized eye replacing the "A"'s crossbar. Mascot: a stern, monocled **hawk** in a hunting jacket, perched on a rifle barrel. **Idle:** the periscope lens tracks the player and the painted hawk's eyes slide (a sliding-plate mechanism). **Signature sound:** a crystal-glass decanter *ting* on dispense, a soft rifle-bolt click, and a falcon cry tail.

**Bottle cap:** deep green with a white hawk's eye and crosshair tick marks around the rim.

**Ad copy (1941 hunting-club newsletter):**
> **"SEE FIRST. SEE FARTHER. SEE IT THROUGH."**
> *Hawkeye Brandy: distilled for the steady hand and the patient eye.*
> Small print: *Pairs well with silence. Do not drink while being watched. You are being watched.*

**Formula backstory:** Made for **snipers**. The program's ideal marksman should "see the heartbeat in the target's throat." The distiller was **Freiherr Leopold von Aschau**, a Tyrolean noble and hunting enthusiast. His family's pear brandy recipe masked the tonic, which sharpens focus and steadies tremor, at the cost of night terrors and the feeling of "eyes behind the eyes." **Wren** hates that it works, because it was tested on Polish partisan prisoners first.

**Jingle: "Hawkeye Brandy"**
*Style:* smoky Weimar-cabaret torch song, slow and sultry, slightly menacing. *Tempo:* 66 BPM, 4/4 with rubato. *Key:* C minor. *Instrumentation:* muted trumpet, brushed snare, upright bass, celesta, cabaret piano. A low female contralto sings close to the microphone.

> **Verse 1**
> In a blind of pine and snowfall,
> there's a gentleman who waits,
> he has never once been hurried,
> and he's never once been late.
>
> **Chorus**
> Hawkeye, Hawkeye,
> one long breath and hold it still,
> Hawkeye, Hawkeye,
> the far man on the far, far hill,
> a single drop to steady the hand,
> a single shot, and there you stand,
> Hawkeye... Brandy.
>
> **Verse 2**
> Oh, the valley's full of shadows,
> and the shadows think they're grand,
> but there's one who sees them coming
> with a glass of something in his hand.
>
> **Chorus**
>
> **Coda (whispered)**
> "...I see you."

---

## 7. Packmule Porter (`packmule_porter`), 4000

**Machine:** The widest machine: a squat, overloaded quartermaster's wagon-style cabinet with luggage racks, canvas-strapped crates and spare rifles bolted to its sides and top. Enamel is **brown and olive drab** with stencil lettering and brass buckles. The neon reads **PACKMULE** in stencil letters, with a smaller *Porter* on a hanging tin sign that swings. Mascot: **"Esel Ede,"** a grinning mule in a kepi, with three rifles strapped to his back and a fourth in his teeth, carrying a sack labelled *MEHR* ("MORE"). **Idle:** the hanging sign swings and bolted gear rattles. A recorded mule bray happens rarely (1-in-6 per proximity trigger). **Signature sound:** a heavy canvas-and-buckle *thud*, a creaking-wagon rattle, and the bray on cap-off.

**Bottle cap:** olive drab with a brown mule head and three white rifle-lines fanning behind it.

**Ad copy (1942 supply-depot poster):**
> **"ONE MORE NEVER HURT ANYONE."**
> *Packmule Porter: the quartermaster's friend. Carry it all.*
> Small print: *Helvetia Automaten AG reminds you that the Quartermaster Corps counts everything. Everything.*

**Formula backstory:** The **Quartermaster Corps** commissioned it for supply columns where trucks failed. The goal was soldiers who could carry more without fatigue. The tonic gives a strange extra "reach," a third hand's worth of grip that trial subjects described as *"a ghost holding my rifle for me."* The porter base is a strong English-style dark beer. Helvetia's ad agency liked the alliteration and the joke stuck.

**Jingle: "Packmule Porter"**
*Style:* boozy sea-shanty / work-song stomp, call-and-response. *Tempo:* 98 BPM, 4/4 heavy stomp. *Key:* A minor → A major on the chorus. *Instrumentation:* concertina, fiddle, banjo, kick-drum on a wooden crate, a gruff male lead with a rowdy gang chorus, and a mule-bray sample hit.

> **Verse 1**
> (Lead) Oh, I've got a rifle on my shoulder,
> (Gang) HEY-ho, the mule goes slow!
> (Lead) And another and I'm getting older,
> (Gang) HEY-ho, and down we go!
>
> **Chorus**
> Pack it up, pack it on, the Packmule Porter!
> One more gun and one more quarter!
> Load it up from hoof to ear,
> there's always room for one more here!
> (BRAY!)
>
> **Verse 2**
> (Lead) Oh, the sergeant gave me one too many,
> (Gang) HEY-ho, the mule goes slow!
> (Lead) And I didn't drop a single penny,
> (Gang) HEY-ho, and down we go!
>
> **Chorus**
>
> **Verse 3 (bonus, full listen only)**
> (Lead) Oh, the mule went down in the river deep,
> (Gang) HEY-ho, the mule goes slow!
> (Lead) And he's carrying still, though he's fast asleep,
> (Gang) HEY-ho... and down we go.
>
> **Tag (gang, laughing)**
> "ONE! MORE!"

---

## 8. Blastproof Bock (`blastproof_bock`), 2000

**Machine:** A thick armored cabinet like a bomb-disposal locker or bank safe, with a heavy riveted door, a porthole bottle window and a wheel-handle. Enamel is **orange and black** in hazard-diagonal stripes, with blast-scorched chrome. The neon reads **BLASTPROOF** in blocky letters, with a cartoon explosion starburst behind *Bock*. Mascot: **"Kaboomer,"** a grinning ram (a *Bock*, a billy goat) in a steel helmet with a lit fuse in his teeth and soot on his cheeks, totally unbothered. **Idle:** a small cartoon "explosion" sign behind the ram flashes, and the safe-wheel spins a quarter-turn now and then. **Signature sound:** a muffled *BOOM* with dust-rattle on dispense, a fuse-hiss, and a goat bleat on cap-off.

**Bottle cap:** orange and black with a white ram's head over a black starburst.

**Ad copy (1941 Pionierschule mess-hall poster):**
> **"THE LOUDER THE BETTER!"**
> *Blastproof Bock: a strong spring beer for strong spring cleaning.*
> Small print: *Not a substitute for distance. Not a substitute for sense. A fine substitute for everything else.*

**Formula backstory:** A **demolitions school** favorite at the Pionierschule in Dessau-Roßlau. Instructors drank it before live-charge days. It hardens the inner ear and lungs against overpressure and lets the drinker shrug off falls. It started as a fragmentation-injury tonic. **Peg's SOE dossier** notes that the formula was smuggled out to London in 1943 inside a bock-beer label, and that her own demolitions instructor "tried a bottle, and found it disappointingly effective."

**Jingle: "Blastproof Bock"**
*Style:* rowdy polka-rag with comic sound effects, vaudeville. *Tempo:* 138 BPM, 2/4. *Key:* F major. *Instrumentation:* honky-tonk piano, clarinet, tuba, washboard, slide whistle, and timpani "booms" on every chorus downbeat. A comedic male tenor and a cheering crowd.

> **Verse 1**
> I lit the fuse at breakfast and I lit the fuse at lunch,
> I sat upon a mortar shell, it gave me quite a punch!
> I fell off the church tower and I landed on my head,
> I said "well, pass the Bock, my friend" and toddled off to bed!
>
> **Chorus**
> Blast-proof! (BOOM!) Blast-proof! (BOOM!)
> Billy goat in a crater!
> Blast-proof! (BOOM!) Blast-proof! (BOOM!)
> Now it's sooner, never later!
> Bang and boom and up and away,
> blow the bridge and save the day,
> Blast-proof, Blast-proof Bock!
>
> **Verse 2**
> My mother said "be careful, son, you'll blow your eyebrows clean,"
> I've lost them both a dozen times, they grow back extra green!
> The colonel's lost his trousers and the cook has lost his pot,
> but I have got my Blastproof Bock, so what's a little shot?
>
> **Chorus**
>
> **Tag (crowd)**
> "KA-BOOM!" *(slide whistle up, comic thunk)*

---

## Song: "Come Along, Little Soldier" (*Komm mit, kleiner Soldat*)

*Use:* the Siren Gramophone's record. It plays the 8-second lure loop (verse 1 + half chorus), and the detonation hits on the last word "soldier." *Credit:* "Come Along, Little Soldier": original composition, GRAVELIGHT (placeholder audio).
*Style:* a creepy-sweet children's march in 1930s nursery-recording style. *Tempo:* 96 BPM, 4/4. *Key:* D major, with a final chord that slides flat to D♭. *Instrumentation:* toy piano, music-box, a child-sized snare, celesta, glockenspiel, and a bright young female soprano. The record is warped, so pitch wobbles ±15 cents and gets worse as the fuse nears detonation. Liesl's tin drummer **Herr Tamtam** plays the snare figure on the original. The same 4-bar drum cadence is used when the drummer appears in the Crate.
*Lore:* Reinholt's lab used it to herd test subjects. The resonant frequency in the record's groove attracts Gängers. Liesl's nursery had the original pressing.

> **Verse 1**
> Come along, little soldier, come along, come along,
> left foot, right foot, sing the marching song,
> button up your jacket and polish up your shoe,
> there's a place at the table, and it's waiting just for you.
>
> **Chorus**
> Rum-tum, tum-a-tum, hear the little drum,
> everybody's marching and everybody's come,
> rum-tum, tum-a-tum, closer, closer, closer,
> come along, come along, little soldier.
>
> **Verse 2**
> Come along, little soldier, the lamps are burning bright,
> Mother's in the kitchen and she's left on all the light,
> nobody is crying and nobody is cold,
> everyone is welcome, and nobody grows old.
>
> **Chorus**
>
> **Bridge (sung slower, the record dragging)**
> Don't you mind the singing, don't you mind the bell,
> don't you mind the hungry, they're only hungry, well...
>
> **Final Chorus**
> Rum-tum, tum-a-tum, hear the little drum,
> everybody's marching and everybody's come,
> rum-tum, tum-a-tum, closer, closer, *closer*,
> come along, come along, little... *(BOOM)*

*Composer note:* the explosion should land a beat early, cutting the word "soldier" mid-syllable. If the gramophone isn't detonated in-game (dev console), the full record ends on a lone child's "...soldier," and then a needle in the run-out groove.

---

## Song: "Lanterns Down Below" (Map 1 hidden song)

*Unlock:* find and play all 3 phonograph cylinders on Map 1 (side Easter egg).
*Credit:* "Lanterns Down Below": original composition, GRAVELIGHT (**placeholder audio**).
*Style:* a heavy doom-blues / industrial work-song hybrid. It opens as a lone, field-recorded miner's work song (wordless hum, pickaxe strikes on the beat), then breaks into a slow, crushing groove: down-tuned baritone guitar, a fuzz bass that is half guitar and half bowed cello, pounding floor-tom and anvil, a pipe-organ pedal drone recorded in a cavern, and a choir of male voices. The vocals are a weathered, cracked baritone that turns into a roar on the last chorus. A middle section quotes the chapel bell's toll at its exact pitch. *Tempo:* 68 BPM, half-time feel, 4/4 with one 5/4 bar per chorus to stumble the step. *Key:* D minor (drop-C tuning). *Length:* ~4:30.
*Lore framing:* the song is a forced laborers' work chant, written down on cylinders by an unknown hand. The final verse appears to have been sung by someone who had already been taken below.

> **Intro (solo voice, hammer on stone)**
> Hm, hm, hm... down below...
> Hm, hm, hm... down we go...
>
> **Verse 1**
> They woke us in the black of night and lined us in the snow,
> they gave us each a lantern, said the work is down below,
> I left my boots beside the door, my name upon the wall,
> I counted every step I took, and then I lost them all.
>
> **Pre-Chorus**
> The salt is in my eyes, and the salt is in my mouth,
> there's no north in the mine, boys, there's no east and there's no south...
>
> **Chorus**
> Lanterns, lanterns, down below,
> swinging where the dead men go,
> one for every soul they keep,
> burning in the salt so deep,
> hear the bell and hold your breath,
> it rings for work, it rings for death,
> lanterns, lanterns... down below.
>
> **Verse 2**
> The overseer's whistle and the overseer's chain,
> he walks the drift at midnight and he calls us all by name,
> the glass hums in the darkness like a hive inside the stone,
> it sings of every one of us, and none of us go home.
>
> **Pre-Chorus**
>
> **Chorus**
>
> **Bridge (bell toll at pitch; tempo slows; choir hums)**
> Count us, Ledger, count us all,
> every hand and every fall,
> one, and one, and one, and one,
> the tally's never, never done...
>
> **Verse 3 (the voice changes: older, hollow, close-mic'd)**
> I took my lantern down below, I'm working there tonight,
> I don't feel the cold no more, I don't need any light,
> and if you hear me singing when the mine is still and slow,
> come down and bring a lantern... *(beat)* ...come down below.
>
> **Final Chorus (full roar, all instruments)**
> Lanterns, LANTERNS, down below,
> swinging where the dead men go,
> one for every soul they keep,
> burning in the salt so deep,
> hear the bell and HOLD YOUR BREATH,
> it rings for work, it rings for death,
> lanterns, lanterns...
>
> **Outro (solo voice, hammer stops)**
> ...down below.

*Composer note:* the triggering player's character reacts afterward (see CHARACTERS.md, category `EE_SONG`). Wren's line references her brother.

---

## Stingers & musical moments

All are original, short, and band-limited to sound like period recordings, with a little low-end weight added for impact. They route through `AudioDirector` on the `Music` bus with ducking of the ambient score layer.

### Round start stinger (~4 s)
- **Concept:** "the march resumes." A muffled distant snare roll (field-drum, slightly too slow), a low brass cluster swelling from silence, and the chapel bell's fundamental note under it as a sub-bass hum, never a bell strike. It ends on an unresolved minor second.
- **Escalation:** from round 10 a male choir grunt is layered on the downbeat. From round 20 the snare doubles in tempo. From round 30 a reversed scream tail is added. **Round 1** uses a sparse version: solo snare + wind.
- **Pairs with:** the HUD round stamp "thunk," which lands on the stinger's downbeat (sync via a `stinger_downbeat` timing marker in data).

### Round end stinger (~6 s)
- **Concept:** "the needle lifts." A warped gramophone fragment of a sentimental waltz (original 4-bar phrase on violin + piano) slows and drops in pitch like a turntable losing power, then a soft vinyl crackle tail. It reads as "relief, but something's wrong."
- **Variants:** a Bellringer round end adds a single clean bell toll that rings out under the crackle. After round 25 the waltz fragment is replaced by a child humming the same 4 bars.

### Special round (Bellringer) stinger (~8 s)
- Three slow tolls of the Salt Chapel bell. Each toll's decay is gated short, as if the air is being sucked out. A rising fog-wind and a rumbling sub-drop sit under the toll. The ambient layer cuts to near-silence, and only the lantern-creak loop of the Bellringers remains.

### Map 1 power-on moment (~20 s, scripted)
1. **0.0 s:** the Hauptschalter lever slams, and there is 1.2 s of total silence (all ambient and music cut).
2. **1.2 s:** a deep turbine spin-up, a rising sine sweep from 30 Hz to 120 Hz plus an orchestral bass-string crescendo.
3. **4.0 s:** the Operator line (`OPR_POWER_ON_01`) over a lush, triumphant 1930s radio-orchestra fanfare (strings, harp glissando, timpani). It is *too* happy for the situation.
4. **6–14 s:** as each zone's lights sweep on, that zone's perk machine plays a 1-bar "hello" phrase of its jingle in sequence (Second Wind → Ironhide → Twin Barrel → Marathon → Trigger → Hawkeye → Packmule → Blastproof, if the zone is open; otherwise a distant muffled version), all in a shared key center (B♭) so they overlap like a carnival tuning up.
5. **14 s:** the fanfare swells to a final chord. Under it the Nachtglas heart's low hum (a dissonant tritone drone) fades in and *stays* under the score for the rest of the match.
6. **16 s:** the burst of zombies spawns. The ambient score jumps one intensity layer.

### Pylon attunement holdout (45 s)
A rising ostinato on a bowed saw and string tremolo, pitched up a semitone every 15 s. When charging pauses, the ostinato drops to a single pulsing note that "drains" downward. On attunement, a resonant chord blooms (the pylon's assigned note: A_MINEHEAD = D, F_CHAPEL = F, H_LAB = A, which together make D minor). On the third, the full chord rings and the vault-open sequence begins.

### Heartstorm (2:00 final holdout)
A dedicated cue: industrial percussion, choir, the Lanterns Down Below riff re-orchestrated, Reinholt's PA lines ducking the mix, and the bell tolling every 15 s. In the last 10 s everything drops out except a rising heart-throb pulse and a music box playing the quest's 4-note melody (generated per match).
