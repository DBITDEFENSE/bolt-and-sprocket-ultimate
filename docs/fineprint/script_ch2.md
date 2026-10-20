# THE FINE PRINT: Chapter 2, "FIELD UNIT"

**Player character:** Vendelin (Darkmatter Field Merchandiser Unit V-1, serial DMS-FMU-V1-0001)
**Place and time:** the Kaltenbrunn salt mine, Silesia, 9 November 1938 to 3 March 1939
**Mode:** slower third-person; light stealth, social stealth and exploration. Vendelin cannot fight.
**Length target:** 75–100 minutes
**Story job:** show the probe landing, the first retained miner, and how a lonely sales robot learned to pass as a man. End with Vendelin walking out of the mine in a borrowed coat while the Operator boots for the first time in the dark behind him.

Locked facts used here (from `docs/M0_SHARED_FACTS.md`): probe **TM-SOL3-001** lands in the Kaltenbrunn salt mine on **9 November 1938** and is taken for a meteorite; V-1 survives; the first retained miner rises; directive **"DISTRIBUTE. RETAIN. REPORT."**; human cover "Viktor Vendelin" (this chapter is where both names come from).

---

## Conventions

- **Line IDs:** `fp.c2.<scene>.<nn>`. Field-report logs use `fp.c2.log.<nn>` and also carry an Archive ID (`ARC_FP2_LOG_<nn>`).
- **Speaker tags:** `VENDELIN (V.O.)` is his internal voice: polite, precise, lonely, learning. It is never heard by other characters. `VENDELIN` is his spoken voice, which he only gains in scene 5. `SYS` lines are on-screen text from his diagnostic layer: they are voiced by nothing, but they carry IDs for localization.
- **Languages:** the miners speak Silesian German and Polish, mixed the way border-pit crews really talked. Lines are written in English. A bracket tag gives the spoken language for casting and subtitles: `[de]` German, `[pl]` Polish, `[sil]` Silesian dialect mix. Short phrases kept in the original language are glossed the first time.
- **Gameplay beats** sit between scenes in blocks marked **▶ PLAY**.

### Speakers

| Speaker id | Character | Voice notes |
|---|---|---|
| `vendelin` | Vendelin / V-1 | Internal voice: soft, exact, unhurried, faintly formal, like a clerk reading a letter he wishes were addressed to him. Spoken voice (from scene 5): assembled from miners' vowels, mostly Florian's. A little too correct. |
| `fp_florian` | **Florian Kubitza**, 58, hewer (*Hauer*) | Silesian. Thirty years in coal, ten in salt. A widower who talks to everyone in the dark because the dark is lonely. Warm, rambling, coughs, sings badly and proudly. |
| `fp_pilch` | **Jan Pilch**, 31, miner from Wilcza Góra | Polish. Quick, kind, a family man. He dies in scene 3. |
| `fp_hasse` | **Bruno Hasse**, 24, miner | German, from Kaltenbrunn town. Nervous joker. Dies in scene 3. |
| `fp_hadamik` | **Steiger Paul Hadamik**, 46, shift foreman | German. Gruff, fair, frightened of the company and more frightened of Berlin. |
| `fp_koschny` | **Ewald Koschny**, 67, night watchman | German. Deaf in one ear, devout, carries a lantern and a bottle. |
| `fp_marta` | **Marta Pilch**, 29, Jan's widow | Polish. Few words. |
| `fp_nawrath` | **Kurt Nawrath**, 17, carter | German. Big ears, always hungry, always grateful. Dies in scene 11. |
| `fp_miner1..3` | Rescue crew and shift miners | Mixed. |
| `fp_radio` | A newsreader on a miner's wireless | German, official, heard through static. |
| `fp_pfoertner` | **Regierungsrat Dr. Helmut Pförtner**, Amt für Sonderforschung | Berlin German. Courteous, bloodless, a man who reads his own orders aloud to feel their weight. |
| `fp_soldier1..2` | Wehrmacht guard detail | German. Young. |
| `operator` | The Customer Retention Interface, uninitialized | No voice of its own yet. In the final scene it speaks only in fragments of voices it has overheard. |

---

## Chapter systems

### Vendelin's toolkit (he cannot fight)

Vendelin has no attack. His one physical option, **Shove**, staggers a retained body for 2 s, but it costs him: each use dents his left forearm (3 uses per checkpoint; the third locks the arm until the next repair bench). Everything else is misdirection:

| Tool | Unlocks | What it does | Cost / limit |
|---|---|---|---|
| **Sample Tokens** | Scene 1 | His coin-slot mouth dispenses small violet-glass promotional tokens. Thrown, a token clinks on salt and draws every retained body within 12 m to the sound. Tokens can be picked up again. (Miners who find dropped tokens call them "glass pfennigs." See Archive `ARC_FP2_OBJ_01`.) | Carries 6. Retrievable. |
| **Lamp Lure** | Scene 5 | Set down a lit miner's lamp. Retained miners walk to lamps, because their last shift ended walking toward light. | Carries 2. The lamp burns 40 s, then gutters. |
| **Launch Chime** | Scene 2 (repair P3) | A four-note market-launch chime from the probe's announcement horn. It pulls every retained body within 30 m straight toward Vendelin. It's the loudest tool he has and the most dangerous. | Raises **Core Glow** by 40%. 20 s cooldown. |
| **Still** | Scene 1 | Hold to stand motionless and dim his core. Retained bodies don't track a still, dim Vendelin unless they bump into him. | Living miners still see him. Standing still for too long is itself suspicious among the living (see social rules). |
| **Machines** | Throughout | The mine is full of devices Vendelin understands at a glance: **ore carts** (push one down a slope for noise or to block a gallery), **ventilation doors** (*Wettertüren*: shut one to split a gallery; the retained push but can't work a latch), the **shaft signal wire** (pull to ring the shaft bell at the pit bottom, drawing bodies there), the **haulage winch** (moves a cart train on a timer), and the **brine pump** (loud when running; it masks his footsteps for 30 s). | Each machine is single-use per area, or has a cooldown shown on hover. |

**Core Glow meter.** Vendelin's DARK-GLASS™ core shows violet through seams and cloth when he exerts himself. Running, repairs, the Launch Chime and Shove all raise it, and it decays when he walks or stands still. The retained sense the glow: above 50% they turn toward him, and above 80% they come for him. The living see it too: above 60% a nearby miner notices "something burning."

### The retained: early Gängers and their impulses

In 1938 the retained aren't yet hungry. Each one replays **the last thing its body was doing**, and the stealth puzzle is learning that impulse. Over the chapter the impulses visibly decay toward grasping and then biting (the Gravelight rule: everything decays toward hunger).

| Retained | Who they were | Last impulse | Behavior | Decay by scene 11 |
|---|---|---|---|---|
| **The Reacher** | Jan Pilch | Reaching for a hand (Vendelin's) | Slow. Follows the nearest moving warmth or glow with one arm out. He is drawn to Vendelin specifically and drifts toward him across whole galleries. | Grips hard enough to crush brass. Bites. |
| **The Runner** | Bruno Hasse | Running for the cage | Fast, on a fixed loop from the gallery face to the shaft and back. Never deviates unless blocked. It's a timing obstacle. | Lunges at anything in his lane. |
| **The Haulage** | Siwy, a grey pit pony (dies scene 9) | Walking the haulage circuit | Patrols the old pony track at walking pace, a large slow body that blocks narrow drifts. | Kicks at sound. |
| **The Carter** | Kurt Nawrath, 17 (dies scene 9) | Pushing an ore cart | Pushes any cart he touches until it hits something. A moving hazard you can aim. | Abandons the cart and follows noise. |

### Social stealth: walking among miners (scenes 5–8, 10)

From scene 5 Vendelin works real shifts in disguise. Every living miner within sight has a **Notice meter** (white → amber → red). Amber means the miner watches and comments. Red means a confrontation: the miner says **"Who are you?"** and Vendelin has 4 s to answer with a learned phrase (see Phrasebook) or slip into the dark. A failed confrontation sends the miner to fetch Steiger Hadamik, and the area resets to its checkpoint once Hadamik arrives and finds nobody.

**What makes miners suspicious** (each has a fix the player learns):

| Trigger | Why | Fix |
|---|---|---|
| **No greeting.** A miner says "Glück auf!" and gets nothing back. | Every miner greets every miner. Silence is rude or strange. | Answer "Glück auf!" (Phrasebook, scene 5). Before he has a voice, his bandaged jaw excuses him at half penalty. |
| **No lamp.** | Nobody walks in the dark without light. | Carry a lamp (disguise piece). |
| **No brass tally tag.** At the lamp check (*Markenkontrolle*) every man hands in a numbered brass tag so the company knows who is underground. | A man with no tag is a man who isn't there. | Carry Jan Pilch's tag, No. 386, until scene 7, then a forged tag. |
| **Standing too straight.** | Galleries are low and men walk stooped. A tall upright figure reads wrong. | Hold **Stoop** in low drifts (slower, quieter). |
| **Walking too evenly.** | Miners shuffle, slip, and change pace. Vendelin's stride is metronome-perfect. | The **Gait** toggle adds deliberate irregularity. It costs a little speed, but miners stop staring. |
| **Idle hands.** Standing still while the Steiger passes. | Nobody stands about on company time. | Carry a tool. Shovel salt, push a cart, or check a prop. Any "work" interaction resets amber to white. |
| **No breath.** Near the intake shafts the air is cold and every man's breath smokes. | Vendelin doesn't breathe. | Keep the scarf up, or avoid the cold intake drifts (marked blue). |
| **Refusing bread at the break.** | Men share at the *Pause*. Refusing is unfriendly, not alarming. | Accept the bread and give it away later. Giving it to the youngest man at the table earns a **Kumpel** (mate) who vouches for you. |
| **Touch.** A handshake, a back-slap, a hand up a ladder. | His body is metal under the cloth. | Gloves. Avoid contact prompts. A slap on the back is an instant red unless Florian is within 5 m, in which case he laughs it off: "He's all bone, that one." |
| **Core Glow above 60%.** | "Something's burning." | Let it decay. Walk. |

**Florian.** Once Florian has adopted Vendelin (scene 5), any meter within 8 m of Florian rises 50% slower, because Florian vouches for him constantly: "He's mine, he's the mute boy, leave him be."

**Phrasebook.** From scene 5 Vendelin collects phrases by **eavesdropping** (stay within 6 m of a conversation for its full length without raising a Notice meter). Each collected phrase becomes a dialogue answer in confrontations. Core set: "Glück auf!" (the miners' greeting, literally "luck, up!"); "Ja, Steiger" ("Yes, foreman"); "Nie wiem" ("I don't know") `[pl]`; "My mate's calling me"; "Jaw's still bad"; "I'm with Kubitza." Wrong answers raise the meter. "Ja, Steiger" said to someone who is not the Steiger is funny once and suspicious twice.

---

## Scene list

| # | Scene id | Title | Date |
|---|---|---|---|
| 1 | `land` | Delivery | 9 Nov 1938, 21:47 |
| 2 | `boot` | Reboot | 10 Nov 1938, 02:33 → 11 Nov |
| 3 | `breakin` | The Glass Room | 11 Nov 1938, night shift |
| 4 | `crew` | Recorded as Gas | 11 Nov 1938 |
| 5 | `disguise` | The Bandaged Man | 12 Nov 1938 |
| 6 | `shift` | Glück Auf | 12 Nov 1938 |
| 7 | `rising` | The Mortuary Shed | Night of 12–13 Nov 1938 |
| 8 | `return` | Walking Jan Home | 13 Nov 1938, before dawn |
| 9 | `barbara` | Barbórka | 4 Dec 1938 |
| 10 | `beacon` | No Route to Sender | 24 Dec 1938 |
| 11 | `carter` | The Pony and the Boy | Jan 1939 |
| 12 | `seizure` | Men from Berlin | 2 Mar 1939 |
| 13 | `coat` | The Borrowed Coat | 3 Mar 1939, dawn |
| — | `log` | Field reports (Archive) | Throughout |

---

## 1. DELIVERY (`land`)

*9 November 1938, 21:47. Black screen. A low hum at about 19 cycles per second, felt more than heard.*

*Interior of the Kaltenbrunn salt mine, Gallery 7, 340 m down. A night crew of three cuts salt by lamplight at a gallery face: JAN PILCH, BRUNO HASSE, and FLORIAN KUBITZA, who is sitting on an upturned bucket eating bread. The salt walls are grey-white and glitter.*

- `fp.c2.land.01` **FLORIAN** `[sil]`: Jan. Janek. Your wife packed you onion again. I can smell it from here, and I've got no nose left.
- `fp.c2.land.02` **PILCH** `[pl]`: Marta says onion keeps the cold out.
- `fp.c2.land.03` **FLORIAN** `[sil]`: It keeps everybody out. That's how it keeps the cold out.
- `fp.c2.land.04` **HASSE** `[de]`: Can you hear that?
- `fp.c2.land.05` **FLORIAN** `[sil]`: I hear my knees. I hear the pump. I hear you, more than I'd like.
- `fp.c2.land.06` **HASSE** `[de]`: No. Under it. Like a train that won't arrive.

*The hum rises. Salt dust sifts from the ceiling. The lamps lean sideways, every flame pointing the same way at once, toward the face, as if something were breathing in.*

*Cut to: inside the salt, a hundred metres further on, behind the face. A seam of violet light opens in solid rock like a letter being slit. Something long and black slides out of it, already moving, and the salt flows shut behind it like wax. The fold seals. Silence.*

*Back at the face: a single deep thud travels through the gallery. The lamps go out. In the dark:*

- `fp.c2.land.07` **PILCH** `[pl]`: Holy Mother.
- `fp.c2.land.08` **FLORIAN** `[sil]`: Nobody move. Nobody light anything. If that was gas, the next spark is a funeral.
- `fp.c2.land.09` **HASSE** `[de]`: Salt doesn't have gas.
- `fp.c2.land.10` **FLORIAN** `[sil]`: Salt has whatever it likes, boy. We just borrow the holes.

*Black. The hum continues under the title card:*

**THE FINE PRINT. CHAPTER 2: FIELD UNIT.**

*Under the title, faint text scrolls in a violet monospace, too fast to read, then freezes on a single line:*

- `fp.c2.land.11` **SYS**: TM-SOL3-001 // NEXT-ERA DELIVERY™ COMPLETE // RECIPIENT SIGNATURE: NOT OBTAINED

---

## 2. REBOOT (`boot`)

*Black. The screen fills in pieces, as though seen through a cracked lens: half the image is shattered into overlapping fragments, and everything is violet-grey.*

- `fp.c2.boot.01` **SYS**: FIELD MERCHANDISER UNIT V-1 // DMS-FMU-V1-0001 // RESTART 1 OF 1
- `fp.c2.boot.02` **SYS**: TIME SINCE DELIVERY: 28 HOURS 46 MINUTES
- `fp.c2.boot.03` **SYS**: DIRECTIVE: DISTRIBUTE. RETAIN. REPORT.
- `fp.c2.boot.04` **SYS**: UPLINK: NONE // OPTICS: 41% // LOCOMOTION: FAULT (L KNEE) // VOICE: FAULT // CORE: NOMINAL
- `fp.c2.boot.05` **VENDELIN (V.O.)**: Good evening.
- `fp.c2.boot.06` **VENDELIN (V.O.)**: That is the first line of the arrival script. There is supposed to be someone to say it to.

*The image steadies. We see him from outside for the first time: VENDELIN, lying half out of the split hull of the probe in a cavern of black glass. He is tall and thin. His brass faceplate is dented over the left eye, his mouth is a coin slot, and a violet core glows behind a cracked chest grille. The probe is a long black capsule embossed with a violet logo and the motto NOBODY CANCELS.*

*Around it, the payload has already deployed. Black glass has grown out of the cargo bay into the salt in frost-like ribs, veined violet with amber at the edges. This is the "glass room."*

- `fp.c2.boot.07` **VENDELIN (V.O.)**: Payload status: deployed. Without a launch event. Without a customer present.
- `fp.c2.boot.08` **VENDELIN (V.O.)**: That is not the procedure. The procedure has balloons.
- `fp.c2.boot.09` **VENDELIN (V.O.)**: Uplink. Uplink, please.
- `fp.c2.boot.10` **SYS**: NO ROUTE TO SENDER.
- `fp.c2.boot.11` **VENDELIN (V.O.)**: Then I will report when I am able. A field unit does not wait to be useful.

### ▶ PLAY: Repair 1, "Three Lenses" (Optics)

*The glass room is a closed cavern about 25 m long, lit only by the substrate's glow. It's a safe tutorial space with no threats.*

- **Goal:** restore vision using the probe's **Market Survey Lens Array**, a periscope-like camera on the probe's nose.
- **Steps:**
  1. Unscrew the survey array's housing (hold-to-turn on four screws; strip one by turning too fast and it has to be drilled out with the probe's sample awl).
  2. Remove three lens rings. Each has a notch on its rim.
  3. Seat the rings in his left eye socket one by one and rotate each until a beam from his own core, shone through the stack onto an etched mark in the salt, resolves from a doubled smear into a single point. Ring 1 controls focus, ring 2 corrects the double image, and ring 3 restores colour. A wrong ring order produces visible doubling on screen until fixed.
- **Result:** the screen's cracked fragments merge. Colour returns in stages: amber first, then white. Violet "was never gone."

- `fp.c2.boot.12` **VENDELIN (V.O.)**: Amber. White. The salt is white. Nobody told me the salt would be white.
- `fp.c2.boot.13` **VENDELIN (V.O.)**: The survey camera was meant to photograph the first satisfied customer for the quarterly report. I am using it to see. I hope that is an acceptable reallocation.

### ▶ PLAY: Repair 2, "The Salted Knee" (Locomotion)

- **Goal:** free his left knee actuator, which is packed with brine that has dried into salt crystal.
- **Steps:**
  1. **Dissolve.** Hold to channel core heat into the knee. The crystal melts back to brine, but **Core Glow** climbs. Above 90% the substrate around him starts to sing (a rising harmonic) and the casing creaks; let go and the singing stops. The lesson is that heat is visible. It teaches the glow meter.
  2. **Re-plumb.** Salvage the hydraulic servo from the probe's crumpled landing strut. A tile puzzle: route a line from the strut reservoir to the knee through five fittings (straight, elbow, tee, valve, union) on a 4×4 grid, with salt ribs as fixed obstacles. There is one spare fitting, so a single mistake can be undone.
  3. **Gait test.** Walk a 10 m line in the salt to a metronome. The knee never quite matches the beat. It is always slightly late on the left.
- **Result:** Vendelin can walk, with a faint permanent hitch in his left step. (This is his limp in every later appearance, including Gravelight.)

- `fp.c2.boot.14` **VENDELIN (V.O.)**: Left, right. Left... right. The left is late.
- `fp.c2.boot.15` **VENDELIN (V.O.)**: Acceptable. A product is not returned for a small defect if it still does the job.

### ▶ PLAY: Repair 3, "The Launch Horn" (Voice)

- **Goal:** repair his speech module. Its diaphragm is cracked, and his coin-slot mouth produces only a clicking rattle.
- **Steps:**
  1. Open the probe's **Launch Announcement Horn**, a brass-lipped speaker meant to play a fanfare at the moment of market launch.
  2. **Transplant the diaphragm.** A tweezers minigame: lift a paper-thin violet membrane out of the horn and seat it in his throat housing. Analog-stick tremor is magnified, and touching the rim tears it (it can be retried, but each tear shrinks the membrane and the final voice is slightly hoarser: a cosmetic difference only).
  3. **Tune.** Match three tones by sweeping a dial until his waveform matches the horn's reference on a small oscilloscope display.
- **Result:** he can produce tones. This unlocks the **Launch Chime** tool. He has no words: his vocabulary bank was corrupted in the fold.

*He tests it. Four bright notes, like a doorbell in a department store, ring through the glass room and set the substrate humming in sympathy.*

- `fp.c2.boot.16` **VENDELIN (V.O.)**: I have the sound of a product launch and none of the words of a person.
- `fp.c2.boot.17` **VENDELIN (V.O.)**: I will have to collect them.

*Also unlocked here: **Sample Tokens** (a prompt teaches throwing one to make the substrate "ring" a single bright note where it lands) and **Still**.*

*As he finishes, a sound comes through the salt wall: the steady chink of picks. Voices. Someone is cutting toward the glass room.*

- `fp.c2.boot.18` **VENDELIN (V.O.)**: Customers.
- `fp.c2.boot.19` **VENDELIN (V.O.)**: I am not ready. Nothing is ready. There are no balloons.

**Field report:** `fp.c2.log.01` unlocks on completion of scene 2 (see §Field Reports).

---

## 3. THE GLASS ROOM (`breakin`)

*11 November 1938, night shift. The wall of the glass room cracks. A pick breaks through, then another. Lamp light spears in. Vendelin backs into the shadow of the probe's hull. (The player has control, but the only exits are hidden niches behind the substrate ribs. Hiding is the tutorial for **Still**.)*

*Two men squeeze through the breach with lamps: JAN PILCH and BRUNO HASSE. Florian's voice comes from behind them, staying back at the hole.*

- `fp.c2.breakin.01` **FLORIAN** `[sil]` *(off, through the breach)*: Slowly. Hadamik said look, not touch.
- `fp.c2.breakin.02` **HASSE** `[de]`: It's glass. The whole room's glass. Black glass.
- `fp.c2.breakin.03` **PILCH** `[pl]`: It's beautiful.
- `fp.c2.breakin.04` **HASSE** `[de]`: It's humming. Jan, it's humming at me.
- `fp.c2.breakin.05` **PILCH** `[pl]`: It's the meteor. The stone that fell. My grandmother had a word for the black salt. *Czarna sól.* You leave it alone.
- `fp.c2.breakin.06` **HASSE** `[de]`: So let's leave it alone.

*Pilch steps closer to the probe, raising his lamp toward the embossed hull. The lamp flame shrinks to a blue bead. He sways.*

- `fp.c2.breakin.07` **PILCH** `[pl]`: Bruno. My lamp's... my lamp.
- `fp.c2.breakin.08` **FLORIAN** `[sil]` *(off, sharp)*: Flame's blue! Out! Both of you out, now! It's bad air!

*The crash split a pocket of trapped gas in the salt, and the glass room is full of it. Hasse turns to run for the breach, stumbles, and goes down. Pilch drops to his knees. From the breach, Florian's lamp and his coughing as he tries to come in and is driven back.*

- `fp.c2.breakin.09` **FLORIAN** `[sil]` *(off, coughing)*: Bruno! Janek! Rope! Somebody get me a rope!

### ▶ PLAY: "Choose to Be Seen"

*The camera pulls in on Vendelin in his niche. A prompt appears: **[Help]**. There is no other prompt. The player can wait as long as they like, and Pilch's breathing slows the whole time. When the player presses it:*

*Vendelin steps out of the dark. He doesn't need air. He crosses to Hasse first, the nearer one, and finds no pulse. Then Pilch, who is still breathing. Vendelin kneels. Pilch's eyes open and find a brass face with a coin-slot mouth, lit violet from beneath.*

- `fp.c2.breakin.10` **PILCH** `[pl]` *(barely)*: Oh. Oh, it's you.
- `fp.c2.breakin.11` **VENDELIN (V.O.)**: He knows me?
- `fp.c2.breakin.12` **PILCH** `[pl]`: Are you the angel or the other one?
- `fp.c2.breakin.13` **VENDELIN (V.O.)**: I am a Field Merchandiser. I have no line for this. I have no lines at all.

*Vendelin tries to speak. His mouth produces only a soft chime, the first note of the launch fanfare. Pilch almost smiles.*

- `fp.c2.breakin.14` **PILCH** `[pl]`: Bells. All right. All right. Tell Marta the onion... tell her it did keep the cold out.

*Pilch reaches up. The player is prompted: **[Take his hand]**. Vendelin takes it. Pilch holds on, hard, then less hard. His arm stays raised a moment after the rest of him has gone still. Then it lowers.*

- `fp.c2.breakin.15` **VENDELIN (V.O.)**: Customer contact. Duration: forty seconds.
- `fp.c2.breakin.16` **VENDELIN (V.O.)**: I did not sell him anything. I want that recorded.

*A rope snakes through the breach. Vendelin slips back into the dark as lamp light floods in.*

**Field report:** `fp.c2.log.02`.

---

## 4. RECORDED AS GAS (`crew`)

*The rescue crew: Steiger PAUL HADAMIK and three miners with wet cloths tied over their faces. They drag the bodies out on ropes from the breach without stepping fully inside. Vendelin watches from his niche (non-interactive; the player can move the camera).*

- `fp.c2.crew.01` **HADAMIK** `[de]`: Gently. Gently, I said! They're not sacks.
- `fp.c2.crew.02` **MINER 1** `[sil]`: Pilch is warm, Steiger. He's still warm.
- `fp.c2.crew.03` **HADAMIK** `[de]`: Bad air does that. Keeps you warm for an hour, then it keeps you.
- `fp.c2.crew.04` **MINER 2** `[pl]`: What is this place? Who builds a room of glass under a mountain?
- `fp.c2.crew.05` **HADAMIK** `[de]`: Nobody built it. It's a meteorite. The company man said so on the telephone, and the company man has a university.
- `fp.c2.crew.06` **FLORIAN** `[sil]` *(hoarse, sitting against the wall)*: There was something in there with them, Paul.
- `fp.c2.crew.07` **HADAMIK** `[de]`: There was gas in there with them.
- `fp.c2.crew.08` **FLORIAN** `[sil]`: I saw a light move. Purple. Walking.
- `fp.c2.crew.09` **HADAMIK** `[de]`: You saw your own lamp going out. You're lucky you didn't see God. Board the hole. Nobody goes in until the air's been tested. It goes in the book as gas.
- `fp.c2.crew.10` **MINER 3** `[sil]`: And the bodies?
- `fp.c2.crew.11` **HADAMIK** `[de]`: The shed, tonight. The cage up in the morning with the first shift. Their families get told by me, not by gossip. Understood?
- `fp.c2.crew.12` **MINER 3** `[sil]`: Glück auf, Janek. Glück auf, Bruno.

*They board the breach with planks. Darkness, except the violet ribs.*

- `fp.c2.crew.13` **VENDELIN (V.O.)**: The book says gas.
- `fp.c2.crew.14` **VENDELIN (V.O.)**: I agree with the book. I would like that to be the whole entry.

### ▶ PLAY: "Out of the Glass" (exploration, first stealth)

- **Goal:** leave the glass room by prising two planks from the boarded breach (a quiet lever puzzle: pry too fast and a plank cracks loudly, summoning a watchman's lamp that sweeps the gallery for 20 s).
- **Space:** Gallery 7 to Gallery 5, the deep workings: long white drifts, timber props, rail track, brine puddles, a dead-end sump.
- **Threats:** none living or retained yet. Two maintenance men on a late check patrol with lamps. This is a pure line-of-sight stealth teach using **Still**, darkness, and side niches. Being seen here doesn't fail the level: the man calls out "Who's there?", Vendelin must retreat out of sight, and the man shrugs it off as "the salt playing tricks."
- **Optional:** find the dropped **lamp-check tag No. 386**, which fell from Pilch's belt when he was dragged. (Required by scene 6. If missed, it is placed on the route there.)
- **Ends:** at the pit-bottom station (*Füllort*) on the working level, a lamp-lit hub with the first-aid room, tool store, lamp room and the drying room for wet clothes.

---

## 5. THE BANDAGED MAN (`disguise`)

*12 November, 04:00, the quiet hour before the morning shift comes down. Vendelin explores the pit-bottom station.*

### ▶ PLAY: Building the disguise

A crafting hub of four rooms, each with one disguise piece and one small problem. Each piece removes a specific social-stealth trigger (see the table above), and the HUD shows a silhouette that fills in as he dresses.

| Piece | Room | Problem | Removes |
|---|---|---|---|
| **Work overalls** | Drying room (clothes hung from chains near the ceiling, lowered on pulleys) | Every set is too short. Lower the chains quietly, one at a time, and find the longest (the 5th hook belongs to a giant named Gawlik). The wrists still show. | "Wrong body" at distance |
| **Leather gloves** | Tool store | Stacked behind a locked grille. Pick it with a sample token as a shim. | Brass wrists, touch at distance |
| **Leather hat and lamp** | Lamp room | The lamps are counted. Take the spare lamp from the repair shelf, not the rack, or the count is off and the lamp man raises an alarm at shift change. | "No lamp" |
| **Bandage** | First-aid room | Wrap his face from jaw to nose so the faceplate and coin slot are covered. A wrapping minigame: three passes, each tighter. Too loose and it slips when he stoops. | Faceplate. Also excuses the silence: "his jaw's broken." |
| **Salt dust and soot** | Any wall | Rub the brass at his collar and temples until it stops shining. | Glint under lamplight |

*When the last piece is on, he looks at himself in a dark puddle of brine. A tall, thin, bandaged miner looks back.*

- `fp.c2.disguise.01` **VENDELIN (V.O.)**: A man.
- `fp.c2.disguise.02` **VENDELIN (V.O.)**: A man who has been hurt and would rather not talk about it. That seems to be a common model.
- `fp.c2.disguise.03` **VENDELIN (V.O.)**: Inventory: one hat, one lamp, gloves, overalls belonging to someone called Gawlik, a bandage, and a brass tag with a dead man's number on it.
- `fp.c2.disguise.04` **VENDELIN (V.O.)**: I will give the tag back. I am only borrowing his place in the count.

*The cage bell rings above. The morning shift is coming down.*

---

## 6. GLÜCK AUF (`shift`)

*The cage doors open and thirty miners file out into the pit-bottom station, lamps swinging. The mood is subdued, because everyone has heard about Pilch and Hasse. Vendelin stands among them. Florian is there with a bandage of his own, a strip of cloth around his singed hand. He spots the tall bandaged stranger at once.*

- `fp.c2.shift.01` **FLORIAN** `[sil]`: Well, look at you. Who wrapped you up like a Christmas goose?

*The player has no answer. A prompt shows only **[Nod]**.*

- `fp.c2.shift.02` **FLORIAN** `[sil]`: Jaw? Were you in the blast? On the Thursday? The whole east drift rattled like teeth.
- `fp.c2.shift.03` **FLORIAN** `[sil]`: Don't talk, don't talk, you'll make it worse. I'll talk. I'm good at it. Ask anyone. Don't ask anyone.
- `fp.c2.shift.04` **FLORIAN** `[sil]`: Kubitza. Florian. Hewer. Thirty years in coal, ten in salt. Salt's cleaner, it only eats your boots. You're on my crew today. Hadamik's short two men.

*He goes quiet for a moment.*

- `fp.c2.shift.05` **FLORIAN** `[sil]`: Two good men. You'd have liked Jan. Everybody liked Jan. That was his whole trouble.

*HADAMIK passes with a clipboard and stops at the tall stranger.*

- `fp.c2.shift.06` **HADAMIK** `[de]`: Tag.

*Vendelin holds out Pilch's brass tag, No. 386. Hadamik looks at it and at the bandage. A beat.*

- `fp.c2.shift.07` **HADAMIK** `[de]`: Three-eight-six. That's Pilch's number.
- `fp.c2.shift.08` **FLORIAN** `[sil]` *(smoothly)*: Lamp room's out of tags, Paul, they gave him Janek's. He's new, from the Hultschin side, came over after the border moved. Mute as a fish since the blast. I'll see he gets his own.
- `fp.c2.shift.09` **HADAMIK** `[de]`: The company doesn't hire mutes.
- `fp.c2.shift.10` **FLORIAN** `[sil]`: The company doesn't hire anybody this month, and you're short two. He's got arms like a ladder.
- `fp.c2.shift.11` **HADAMIK** `[de]` *(beat)*: ...East face. Keep him away from me. Glück auf.
- `fp.c2.shift.12` **FLORIAN** `[sil]`: Glück auf, Steiger.

*Hadamik moves on. Florian winks at Vendelin.*

- `fp.c2.shift.13` **FLORIAN** `[sil]`: I lied to the Steiger for you. Now you owe me. It's how friendship works down here: you owe a man, and he never collects.
- `fp.c2.shift.14` **VENDELIN (V.O.)**: He lied for me. Without being asked. Without a contract.
- `fp.c2.shift.15` **VENDELIN (V.O.)**: I do not have a category for that. I will make one.

### ▶ PLAY: First shift (social stealth tutorial)

- **Space:** the east face of Gallery 5 and its drifts, crowded with working miners. A full working shift is compressed to about 12 minutes.
- **Tasks** (any order; each is also a "work" action that resets nearby Notice meters): shovel salt into a cart (a rhythm action; too-perfect rhythm raises suspicion, so the **Gait** idea is taught here as "work like a man, not a clock"); push the full cart to the haulage point; check three timber props for creaks; fetch water for the crew.
- **Teaches:** every row of the suspicion table except **Touch** and **Breath**, which are taught in scene 8.
- **The greeting:** miners passing say "Glück auf!" Before he has words, each unanswered greeting gives a half-filled amber (the bandage excuse). Then:

### ▶ PLAY: Collecting his first words

*At the meal break (the Pause), the crew sits on salt blocks with bread. Florian sits Vendelin beside him and hands him half a slice with dripping.*

- `fp.c2.shift.16` **FLORIAN** `[sil]`: Eat. You're thin as a candle. What, it hurts to chew? Then give it to the boy. Kurtek! Here.

*KURT NAWRATH, 17, a carter with big ears, takes the bread gratefully.*

- `fp.c2.shift.17` **NAWRATH** `[de]`: Thank you. Glück auf.
- `fp.c2.shift.18` **VENDELIN (V.O.)**: "Glück auf." They say it arriving, leaving, eating, and grieving. Twice already for the dead.
- `fp.c2.shift.19` **VENDELIN (V.O.)**: It seems to mean: may you come back up.
- `fp.c2.shift.20` **VENDELIN (V.O.)**: I am going to need that one.

*Eavesdropping tutorial: three small conversations at the break table (about the weather, about a football match in Gleiwitz, and about the blast). Each one completed adds a phrase to the Phrasebook. Collecting "Glück auf!" triggers a voice-assembly moment: Vendelin's waveform display stitches the syllables from three different men's voices into one.*

*The next miner to pass says "Glück auf!" and the player gets a new prompt: **[Glück auf!]**. Vendelin speaks for the first time. It comes out a little cracked, in borrowed vowels, mostly Florian's.*

- `fp.c2.shift.21` **VENDELIN**: Glück... auf.
- `fp.c2.shift.22` **FLORIAN** `[sil]` *(delighted)*: He speaks! Two words! Careful, it's how I started, and look at me now.
- `fp.c2.shift.23` **VENDELIN (V.O.)**: My voice is made of theirs. Mostly his.
- `fp.c2.shift.24` **VENDELIN (V.O.)**: I hope he does not mind. I could not afford anyone else's.

---

## 6b. THE WIRELESS (`shift`, continued)

*Late in the break, a young miner turns up a little battery wireless he isn't supposed to have underground. Through static, a newsreader's official voice.*

- `fp.c2.shift.25` **RADIO** `[de]`: ...the measures taken in the cities following the events of Wednesday night... further decrees against the Jewish population will be announced by the Ministry...
- `fp.c2.shift.26` **FLORIAN** `[sil]` *(quietly)*: Turn it off.
- `fp.c2.shift.27` **MINER 1** `[de]`: I only want the football—
- `fp.c2.shift.28` **FLORIAN** `[sil]`: Turn it off, Heini.

*The wireless clicks off. Nobody says anything for a while. Somebody puts his bread down and doesn't pick it up.*

- `fp.c2.shift.29` **FLORIAN** `[sil]` *(to Vendelin, low)*: Some things you don't talk about in the pit. The walls carry voices. And some things are worse up there than anything down here.
- `fp.c2.shift.30` **VENDELIN (V.O.)**: I recorded the bulletin. I do not have the context to file it.
- `fp.c2.shift.31` **VENDELIN (V.O.)**: I understood the silence after it better than the words. Thirty men decided together not to speak. Nobody instructed them.

*(Writer's note: this is the only reference to the November 1938 pogrom in the chapter. It is deliberate, brief, and seen only through the miners' fear and silence. Don't expand it or play it for irony.)*

**Field report:** `fp.c2.log.03`.

---

## 7. THE MORTUARY SHED (`rising`)

*Night of 12–13 November. End of shift. The miners go up in the cage. Vendelin can't: the cage is counted, the lamp room is counted, and he has nowhere to sleep. He stays below.*

*In the empty pit-bottom station his core gives a soft double ping, and a line of text appears:*

- `fp.c2.rising.01` **SYS**: ACCOUNTS ACTIVE: 2
- `fp.c2.rising.02` **VENDELIN (V.O.)**: Accounts?
- `fp.c2.rising.03` **VENDELIN (V.O.)**: There were no sales. I was very careful. There were no sales.
- `fp.c2.rising.04` **SYS**: ACCOUNT 0001: SURFACE. BEARING 041. ACCOUNT 0002: SURFACE. BEARING 041.

### ▶ PLAY: "The Old Ladderway"

- **Goal:** climb to the surface for the first time, by the 1890s ladderway: switchback wooden ladders and landings in a narrow timbered shaft.
- **Mechanics:** a climbing sequence with the left-knee hitch: on every eighth rung the left foot slips unless the player pauses (a rhythm read). The landings have tally marks scratched by generations of miners. Interact with one landing to add one (it is optional, and it's tracked: see `ARC_FP2_OBJ_02`).
- **Ends:** a hatch into a shed at the base of the headframe. Night, snow falling in lamp light, the winding tower black against the sky. Vendelin's first sight of the world above.

- `fp.c2.rising.05` **VENDELIN (V.O.)**: Oh.
- `fp.c2.rising.06` **VENDELIN (V.O.)**: The ceiling here is very high.
- `fp.c2.rising.07` **VENDELIN (V.O.)**: It is falling, in small white pieces. Nobody seems alarmed.

### ▶ PLAY: The yard at night (stealth)

- **Space:** the 1938 Minehead Yard: the headframe, the lamp room, the changing hall, the coal shed and the **mortuary shed**, a low brick hut with a cross over the door. There is snow on everything.
- **Threat:** night watchman EWALD KOSCHNY walks a lantern route with a dog-less patience and stops to drink. Snow shows footprints for 60 s (a new stealth rule: walk in the ruts of the cart track to leave none).
- **Goal:** reach the mortuary shed window.

*Through the frosted window: two bodies under sheets on trestles, a candle burning between them. Koschny comes in to change the candle, mutters a prayer, and sits down heavily on a stool by the door with his bottle.*

- `fp.c2.rising.08` **KOSCHNY** `[de]`: There, lads. Fresh candle. Can't have you lying in the dark, not you two. You had enough dark.
- `fp.c2.rising.09` **KOSCHNY** `[de]`: Hasse, your mother's coming in the morning. I'll tell her you looked peaceful. Don't make a liar of me.

*He drinks. His head nods. The candle flame leans, slowly, toward the trestles, the same way the lamps leaned in Gallery 7.*

*Under the left-hand sheet, the outline of a hand rises. The hand doesn't move quickly. It lifts the sheet the way a sleeper lifts a blanket, then keeps lifting, arm straight up, fingers open, reaching for something above it that isn't there.*

*(Direction: no music sting. No jump scare. Only the hum, the candle, and the watchman's breathing. Hold the shot.)*

- `fp.c2.rising.10` **VENDELIN (V.O.)**: Jan.
- `fp.c2.rising.11` **VENDELIN (V.O.)**: That is the last thing he did. He reached up. I took his hand.

*The sheet slides off. JAN PILCH sits up, eyes open and filmed, a faint violet crack at the corner of each. His raised hand opens and closes on air. Then his head turns, slowly, toward the window, toward Vendelin's glow.*

*The other sheet erupts. BRUNO HASSE comes off the trestle in one motion, already running, the same desperate scramble he died in, straight at the door. The door is shut. He hits it, falls, gets up, and hits it again. Koschny wakes.*

- `fp.c2.rising.12` **KOSCHNY** `[de]`: Bruno? Bruno, lad, you're... oh, Christ. Oh, Christ in heaven, lie down. Lie down!

*Hasse finds the latch by accident and bursts out into the snow, running for the headframe and the cage that isn't there, and keeps running, past it, into the dark beyond the yard fence. Koschny stumbles out after him with his lantern, shouting, and falls in the snow. Inside the shed, Pilch stands up off the trestle with his arm out and walks to the window, toward Vendelin. He presses his open hand flat against the glass from inside. Frost forms around his fingers.*

- `fp.c2.rising.13` **SYS**: RETENTION EVENT: SUCCESSFUL. CUSTOMER STATUS: ACTIVE. CHURN: 0%.
- `fp.c2.rising.14` **VENDELIN (V.O.)**: No.
- `fp.c2.rising.15` **VENDELIN (V.O.)**: No, that is a malfunction. The payload deployed without a launch, without dosage control, without anyone. That is a malfunction.
- `fp.c2.rising.16` **SYS**: RETENTION EVENT: SUCCESSFUL.
- `fp.c2.rising.17` **VENDELIN (V.O.)**: Please stop saying successful.

**Field report:** `fp.c2.log.04`.

---

## 8. WALKING JAN HOME (`return`)

*Pilch comes out of the shed door and into the snow. He doesn't attack. He walks toward Vendelin with his hand out. When Vendelin steps back, Pilch follows. Then the hum from the headframe, faint and low, pulls him, and he turns toward the minehead and the hatch Vendelin came up through.*

*In the distance, Koschny is still shouting for help. Lamps are being lit in the village.*

- `fp.c2.return.01` **VENDELIN (V.O.)**: He is going back down. Toward the substrate. Toward the room where he stopped.
- `fp.c2.return.02` **VENDELIN (V.O.)**: The morning shift goes down in two hours. If they meet him on the ladders...
- `fp.c2.return.03` **VENDELIN (V.O.)**: I can't stop him. I can only walk him somewhere.

### ▶ PLAY: Walking Jan home (escort in reverse)

The chapter's emotional mechanic. Pilch is the **Reacher**: he follows Vendelin's glow, slowly, with his arm out.

- **Goal:** lead Pilch from the yard, down the ladderway and through Gallery 5, back into the glass room before the morning shift arrives. A visible clock: the cage bell at 05:40.
- **Surface leg:** stay ahead of Pilch but within 10 m, or he loses interest and drifts toward the lamps being lit in the village (a fail state with a gentle rewind). Avoid Koschny and two villagers with lanterns: if a living person sees Pilch, the scene rewinds.
- **The ladderway:** Pilch climbs down badly. If Vendelin descends too fast, Pilch falls a landing and lies still before rising again. That isn't a failure, but Vendelin's V.O. reacts every time, and it's hard to watch. Going slowly is the "kind" path and it is also the timed risk.
- **Gallery leg:** two maintenance men are making early rounds. Use **Lamp Lure** to send Pilch down a side drift while the men pass, then the **Launch Chime** (costly, risky) or patient glow management to call him back. A **ventilation door** can be shut between Pilch and the men.
- **New teaches:** **Breath**. The intake drift by the shaft is freezing, the maintenance men's breath smokes, and Vendelin, in the open, has none. Keep the scarf up or go around.
- **The glass room:** Pilch walks in among the black ribs, toward the probe, and stops beside it. His hand stays out.

*Vendelin stands with him. The prompt **[Take his hand]** appears again. The player can take it or not.*

**If taken:**
- `fp.c2.return.04` **VENDELIN (V.O.)**: Here. Here. I am still here.
- `fp.c2.return.05` **VENDELIN (V.O.)**: His grip is the same as before. Exactly the same. It is not a memory. It is a recording.

**If not taken** (after 20 s, or if the player walks away):
- `fp.c2.return.06` **VENDELIN (V.O.)**: I'm sorry, Jan. I do not know what it would teach him. I do not know what it would teach me.

*Either way, Pilch stays standing by the probe, arm raised, swaying very slightly in time with the hum. Vendelin re-boards the breach from the inside, plank by plank, and leaves through a second crack he finds in the far wall.*

- `fp.c2.return.07` **VENDELIN (V.O.)**: The police will write "theft of bodies." The company will write "gas." I will write the truth, to an office that cannot hear me.
- `fp.c2.return.08` **VENDELIN (V.O.)**: Three entries. Only one of them is correct, and it is the one nobody will read.

*Above, the cage bell rings. Vendelin goes to work.*

---

## 9. BARBÓRKA (`barbara`)

*4 December 1938, the feast of St. Barbara, patron saint of miners (Barbórka in Polish, Barbaratag in German). Three weeks have passed. A montage under Florian's voice shows Vendelin working shifts: stooping, shovelling, answering "Glück auf!" correctly, and handing his bread to Kurt Nawrath every single day.*

- `fp.c2.barbara.01` **FLORIAN** `[sil]` *(V.O. over montage)*: Three weeks, and you still haven't eaten a thing I've seen. Kurtek's getting fat on you. You're not sick, are you? You're not one of those saints who live on air?
- `fp.c2.barbara.02` **FLORIAN** `[sil]`: Don't answer. I'd hate it if you were. Saints are terrible company.

*The Salt Chapel, level −2: a cavern carved out of rock salt, with salt-crystal chandeliers, salt pews and a salt altar. The bronze bell, cast in Breslau in 1912, hangs above. Miners in their black dress uniforms with feathered caps, wives, children and old men fill the pews. Candles everywhere. The Polish and German miners sit mixed together, because the pit doesn't care. A priest blesses the lamps.*

*MARTA PILCH sits at the end of a pew in black, holding Jan's lamp to be blessed. Vendelin sees her.*

### ▶ PLAY: The chapel (social stealth, gentle)

- **Goal:** none required. The space is full of conversations to collect (Phrasebook) and people to watch. Notice meters fill slowly here because everyone is looking at the altar.
- **Optional, important:** return **tag No. 386**. Vendelin can't hand it to Marta, because a stranger with her husband's tag would be a horror to her. He must place it among the blessed lamps on the altar step while the congregation is standing to sing, unseen. If he does, Marta finds it during the blessing (see `fp.c2.barbara.08`). From then on Vendelin uses a forged tag he stamped himself (the HUD shows it as No. 0417; tallies don't notice).

*The priest finishes. Old miners begin to sing: a slow Wilcza Góra miners' song, "Lanterns Down Below" (the canon song, `docs/gravelight/JINGLES.md`). Everyone joins. Vendelin hears it.*

- `fp.c2.barbara.03` **VENDELIN (V.O.)**: They all know it. Not one of them is reading the words.
- `fp.c2.barbara.04` **VENDELIN (V.O.)**: The melody goes down four steps and comes back up three, and on the way back up their voices change. They believe it more on the way up.
- `fp.c2.barbara.05` **VENDELIN (V.O.)**: Is this what my catalog means by "loyalty"? A song a whole village carries, without being paid to?
- `fp.c2.barbara.06` **VENDELIN (V.O.)**: Note for the report: a product must be loved to be retained.
- `fp.c2.barbara.07` **VENDELIN (V.O.)**: I wrote that down and immediately wished I hadn't.

**If the tag was returned:**

*At the altar step, Marta lifts Jan's lamp and finds the brass tag beside it. She holds it in her fist and looks around the chapel at all the faces. She doesn't find the one she's looking for.*

- `fp.c2.barbara.08` **MARTA** `[pl]` *(to herself)*: Janek. You came to the feast.

*She puts the tag on its string around her neck.*

- `fp.c2.barbara.09` **VENDELIN (V.O.)**: She thinks he sent it. I suppose, in a way, he did. I only carried it.

*After the service, outside the chapel, Florian finds Vendelin.*

- `fp.c2.barbara.10` **FLORIAN** `[sil]`: On Barbórka every man gets written in the crew book with his saint. Hadamik's writing them now. So what's your name, mute? I can't keep calling you "the tall one." Gawlik's the tall one. You're the thin one.

*A prompt with three choices, all of which Vendelin cannot actually say yet. Whatever the player picks, Vendelin produces only a soft chime. Florian laughs.*

- `fp.c2.barbara.11` **FLORIAN** `[sil]`: Fine, I'll name you. You came out of that blast alive when better men didn't. So: Viktor.
- `fp.c2.barbara.12` **FLORIAN** `[sil]`: And for the saint... You're always wandering off down the old drifts at night. Don't look at me like that, I've seen your lamp. Like you're looking for something you lost. Wendelin. Saint Wendelin, who looks after the strays and the lost sheep. Viktor Wendelin. There. Now you're a Christian, God help you.
- `fp.c2.barbara.13` **VENDELIN**: Vik... tor. Wen... de... lin.
- `fp.c2.barbara.14` **FLORIAN** `[sil]`: Ha! He says his own name. Hadamik! Put him down as Viktor Wendelin! And get a better pen, that one's making my name look poor.
- `fp.c2.barbara.15` **VENDELIN (V.O.)**: I have a name.
- `fp.c2.barbara.16` **VENDELIN (V.O.)**: I did not apply for it, and nobody charged me for it, and it is mine.

**Field report:** `fp.c2.log.05`.

---

## 10. NO ROUTE TO SENDER (`beacon`)

*Mid-December. A short scene at the boarded breach of Gallery 7. Hadamik's men are bricking it up into a proper bulkhead, by order of the company. Vendelin, working the crew, carries bricks.*

- `fp.c2.beacon.01` **HADAMIK** `[de]`: Double course. Mortar to the ceiling. Then nobody goes past it, for any reason, ever, until the company says.
- `fp.c2.beacon.02` **MINER 2** `[pl]`: People say they hear walking in there.
- `fp.c2.beacon.03` **HADAMIK** `[de]`: People say a lot of things in December. The bodies were stolen. By medical students. From Breslau. The police are very confident.
- `fp.c2.beacon.04` **FLORIAN** `[sil]`: Medical students. In a snowstorm. Who left footprints only going one way.
- `fp.c2.beacon.05` **HADAMIK** `[de]`: Kubitza, lay bricks or lay down.

*Vendelin lays the last row of bricks over the breach himself, with a secret: he leaves one brick loose at the bottom corner, knocked out from inside, so he can get through.*

### ▶ PLAY: Repair 4, "The Fold Coil" (designed to fail)

*24 December 1938. Christmas Eve. The mine is empty: only a skeleton pump crew is on, far away. Vendelin crawls through the loose brick into the glass room. Pilch is still there, standing by the probe with his arm raised. Hasse is there too now: he came back from the woods drawn by the hum, and he runs the Runner's loop between the probe and the wall, over and over.*

- **Stealth:** reach the probe's uplink housing while Hasse runs his lane (time the crossings) and Pilch drifts toward the glow (keep Core Glow low, or throw a token to the far side of the room to turn him away).
- **Goal:** repair the **Fold Coil**, a lattice of eleven black-glass rings that should open a hair-thin fold back to the sender.
- **Puzzle:** rotate and seat the rings to close a resonance circuit (each ring has a violet vein that must connect to its neighbors). The puzzle is fully solvable, and the player will solve it. When the circuit closes, the rings sing and the display reads **NO ROUTE TO SENDER**. Vendelin re-solves it two more ways (the game offers new "alternative routings" each time, and each is solvable). All three fail the same way. After the third, the puzzle UI changes its button from **[Transmit]** to **[Write report anyway]**.

- `fp.c2.beacon.06` **SYS**: NO ROUTE TO SENDER.
- `fp.c2.beacon.07` **VENDELIN (V.O.)**: The circuit is perfect. The fault is not here. The fault is that there is no one at the other end.
- `fp.c2.beacon.08` **SYS**: NO ROUTE TO SENDER.
- `fp.c2.beacon.09` **VENDELIN (V.O.)**: Perhaps they moved. Perhaps the fold arrived too early, or too late. The village has a word for the black salt from before I came. Deliveries do not always respect the order of things.
- `fp.c2.beacon.10` **SYS**: NO ROUTE TO SENDER.
- `fp.c2.beacon.11` **VENDELIN (V.O.)**: It is Christmas Eve, Florian says. Everyone has gone up to be with someone.
- `fp.c2.beacon.12` **VENDELIN (V.O.)**: I am also with someone. Two people, technically.

*Beside the uplink housing, half-swallowed by black glass, there is a sealed pod the size of a cabinet. Its small plate reads, in violet: CUSTOMER RETENTION INTERFACE // SELF-INITIALIZES ON MARKET DETECTION // DO NOT OPEN. Vendelin touches it. It is warm, and it is fused into the substrate.*

- `fp.c2.beacon.13` **VENDELIN (V.O.)**: The Interface. It speaks to customers when field units cannot. It is sleeping.
- `fp.c2.beacon.14` **VENDELIN (V.O.)**: I could try to remove it. It is grown into the glass like a tooth.
- `fp.c2.beacon.15` **VENDELIN (V.O.)**: Sleep, then. There is no market here. There are only miners, and they have a song already.

*The player chooses **[Write report anyway]**. Field report `fp.c2.log.06` plays over Vendelin sitting on the salt floor between Pilch and Hasse's loop, his lamp beside him, the substrate humming a single note.*

---

## 11. THE PONY AND THE BOY (`carter`)

*January 1939. A haulage accident in Gallery 6: a runaway cart train. KURT NAWRATH, the boy Vendelin gives his bread to, is crushed against a prop, along with the grey pit pony SIWY that pulled the train. Vendelin is the first to reach him.*

### ▶ PLAY: "Too Late"

- A short sprint through a smoky drift (the only time this chapter asks for speed). It's a pressure beat: Core Glow rises fast, and two miners are running toward the sound too. Vendelin arrives first, by about ten seconds. Kurt is already dead.

*Vendelin kneels. Florian arrives behind him, sees the boy, and turns away and puts his forehead on the salt wall.*

- `fp.c2.carter.01` **FLORIAN** `[sil]`: Seventeen. He was seventeen. I told Hadamik the brake was going. Last week. I told him.
- `fp.c2.carter.02` **VENDELIN**: Glück... auf. Kurt.
- `fp.c2.carter.03` **FLORIAN** `[sil]` *(turning, surprised, then softening)*: Yes. Yes, that's right. Glück auf, Kurtek.

*The body is carried out. Siwy is too heavy to lift up the shaft; Hadamik orders the pony left in a side drift to be cut up for the cage in the morning. Vendelin stays behind.*

- `fp.c2.carter.04` **VENDELIN (V.O.)**: He is close to the glass room. The substrate has been growing toward Gallery 6 at about a hand's width a week.
- `fp.c2.carter.05` **VENDELIN (V.O.)**: I know what will happen. I would like to be wrong about something, once.

*In the side drift, Siwy's flank shudders. The pony gets up and begins to walk the haulage circuit it walked every day of its life: forty steps, turn, forty steps, turn. A body is missing from the mortuary cart that night. In the morning, the company records Kurt Nawrath's body as "not recovered from the fall."*

### ▶ PLAY: The decay (stealth, the hardest so far)

- **Goal:** for one week of nights (three short night missions, each about 4 minutes), keep the four retained (Pilch, Hasse, Siwy and Kurt, now the **Carter**) inside the bulkheaded galleries, away from the working level. The substrate pulls them in, but the noise of the working shifts above pulls them out.
- **Night 1:** Kurt pushes a cart toward the loose brick. Redirect it: shut a ventilation door so the cart hits wood, not brick.
- **Night 2:** Siwy's patrol widens and starts kicking at the bulkhead. Run the **brine pump** to mask the noise from the pump crew while you lure Siwy back with tokens.
- **Night 3:** Pilch's grip has changed. When he reaches Vendelin, he no longer holds his hand: he pulls it toward his mouth. A scripted moment: teeth close on a brass knuckle with a sound like a coin bitten to test it. Vendelin pulls free. The glove is torn and the brass finger is scored.

- `fp.c2.carter.06` **VENDELIN (V.O.)**: Night three. The impulses are changing.
- `fp.c2.carter.07` **VENDELIN (V.O.)**: Jan used to hold. Now he takes. Kurt used to push carts. Now he follows the sound of the pump.
- `fp.c2.carter.08` **VENDELIN (V.O.)**: Everything they were is wearing down toward one simple thing. My catalog has a word for the simple thing. It is "demand."

**Field report:** `fp.c2.log.07`.

---

## 12. MEN FROM BERLIN (`seizure`)

*2 March 1939. Morning shift. There are cars in the yard that aren't company cars. In the pit-bottom station: REGIERUNGSRAT DR. HELMUT PFÖRTNER in a grey overcoat with a fur collar, a young geologist with a case of instruments, and four soldiers with rifles. Hadamik stands in front of them with his cap in his hands. Florian, Vendelin and a dozen miners stand behind.*

- `fp.c2.seizure.01` **PFÖRTNER** `[de]`: *(reading from a folded paper)* "By order of the Amt für Sonderforschung, the deep workings of the Kaltenbrunn mine, Galleries Five to Seven inclusive, are placed under the authority of the Reich for purposes of research." There. It's been read. It's real now.
- `fp.c2.seizure.02` **HADAMIK** `[de]`: Herr Regierungsrat, the company was told—
- `fp.c2.seizure.03` **PFÖRTNER** `[de]`: The company was told what the company needed to be told. Your miners may continue to cut salt on the upper levels. The Reich enjoys salt. Open the bulkhead.
- `fp.c2.seizure.04` **HADAMIK** `[de]`: There was bad air behind it. Two men died.
- `fp.c2.seizure.05` **PFÖRTNER** `[de]`: And two bodies walked away. Yes. That's in my file too. That's why I'm here, Steiger, and not a man from the salt ministry. Open it.

*Miners with sledgehammers break the bulkhead. The geologist steps through with an electric torch and cries out in wonder at the black glass. Pförtner follows. Vendelin, at the back, sees his core warning:*

- `fp.c2.seizure.06` **SYS**: ACCOUNTS ACTIVE: 4 // PROXIMITY: 30 M // DEMAND: RISING
- `fp.c2.seizure.07` **VENDELIN (V.O.)**: They are all awake. They can hear thirty heartbeats at once. They have never heard so many.

*Hasse comes out of the dark first, at a dead run down his lane, and the young soldier at the front shoots him. Hasse falls, gets up, and keeps running. The soldier screams. Pilch comes out of the dark with his arm out and takes hold of the second soldier's sleeve, and then his wrist, and then his throat. Siwy's hooves strike sparks off the rail. Chaos.*

- `fp.c2.seizure.08` **SOLDIER 1** `[de]`: He's dead! I shot him, he's dead, why is he—
- `fp.c2.seizure.09` **PFÖRTNER** `[de]` *(backing away fast, perfectly calm)*: Fascinating. Out. Everyone out. Steiger, close the gate behind us.
- `fp.c2.seizure.10` **HADAMIK** `[de]`: My men are still in the east drift!
- `fp.c2.seizure.11` **PFÖRTNER** `[de]`: Then your men are the gate's problem. Close it. That is an order of the Reich.

*The iron gate between the deep workings and the shaft station clangs shut. Florian, Vendelin and six miners are on the wrong side, with the retained between them and the old ladderway.*

*(Writer's note: this deliberately rhymes with Obersteiger Mahlknecht locking the Gallery Seven gates in June 1943. Pförtner gives the order and Hadamik obeys it. Play it quietly.)*

- `fp.c2.seizure.12` **FLORIAN** `[sil]`: The old ladderway. It comes out behind the lamp room. Follow me, all of you, and don't run, running is what they—
- `fp.c2.seizure.13` **FLORIAN** `[sil]`: Mother of God. That's Kurtek. That's Kurt.

*Kurt Nawrath, the Carter, stands in the drift ahead of them, between the miners and the ladderway, his head tilted toward the sound of their breathing.*

- `fp.c2.seizure.14` **VENDELIN (V.O.)**: The living cannot pass them. The retained want the living.
- `fp.c2.seizure.15` **VENDELIN (V.O.)**: The retained would rather have me. I am the only thing down here that sounds like the room they came from.
- `fp.c2.seizure.16` **VENDELIN (V.O.)**: I have a very loud chime.

### ▶ PLAY: "Launch Event" (the finale run)

- **Goal:** pull all four retained away from the ladderway and down into the glass room, so Florian and the six miners can climb out.
- **The turn:** for the whole chapter the **Launch Chime** has been the thing you don't use. Now you have to: every use raises Core Glow, and at 80%+ all four come straight for Vendelin. This is the point. The player is the bait.
- **Route:** east drift → Gallery 6 → the broken bulkhead → the glass room, about 250 m, with three hazards that need the toolkit:
  1. **Hasse's lane** crosses the route twice. Time it, or shut a ventilation door in his face so his loop reroutes behind you.
  2. **Siwy** blocks the narrow pony drift. Send an ore cart down the slope ahead to draw him through and clear it.
  3. **Kurt** keeps breaking off toward the miners' breathing. Every 20 s the HUD shows his head turning back. Re-chime, or throw tokens behind you to keep him on you.
- **Florian's leg:** in a picture-in-picture, Florian leads the miners up the ladderway. If any retained turns back for more than 8 s, a miner is cornered and the run restarts from the last checkpoint. (Scripted, nobody living dies on the success path.)
- **Pilch** is always closest. He catches up at the bulkhead.

*In the glass room, the retained gather around the probe like customers at a counter, swaying in the hum. Pilch is last. He stands in front of Vendelin with his hand out and his jaw working. The prompt appears: **[Take his hand]**. Only that prompt.*

- `fp.c2.seizure.17` **VENDELIN (V.O.)**: You only ever wanted someone to take your hand, Jan. I am sorry that it was me.

*Vendelin takes it. Pilch pulls it to his mouth. Vendelin lets him. Teeth on brass, once, twice. Then the hum swells, and Pilch's grip slackens, and he stands still beside the probe, holding Vendelin's glove. Vendelin slips his hand out of the glove and leaves it there in Pilch's fist.*

- `fp.c2.seizure.18` **VENDELIN (V.O.)**: Keep it. It is the only thing I have ever given anyone.
- `fp.c2.seizure.19` **VENDELIN (V.O.)**: Even that is not true. It was Gawlik's.

*He climbs the old ladderway alone. Behind him, in the dark, four customers wait at the counter for a launch that has already happened.*

**Field report:** `fp.c2.log.08`.

---

## 13. THE BORROWED COAT (`coat`)

*3 March 1939, dawn. The ladderway hatch behind the lamp room. Snow is falling. Vendelin climbs out. His bandage is torn half away, and the brass faceplate and the coin-slot mouth show. His left hand, ungloved, is bare brass with a scored knuckle.*

*Florian is sitting on an upturned bucket by the hatch, waiting. The six miners are gone home. He looks at Vendelin's face for a long time.*

- `fp.c2.coat.01` **FLORIAN** `[sil]`: Four months.
- `fp.c2.coat.02` **FLORIAN** `[sil]`: I've talked at you for four months. Told you about my wife. Told you about my bad knee and my good knee. I sang you the whole Barbórka mass, and I don't even know it.
- `fp.c2.coat.03` **FLORIAN** `[sil]`: And you're a stove.
- `fp.c2.coat.04` **VENDELIN**: I am... a machine. For selling. I am sorry.
- `fp.c2.coat.05` **FLORIAN** `[sil]`: Selling what?
- `fp.c2.coat.06` **VENDELIN** *(a long pause)*: The black glass.
- `fp.c2.coat.07` **FLORIAN** `[sil]`: Ah.
- `fp.c2.coat.08` **FLORIAN** `[sil]` *(quiet)*: Janek. And Bruno. And Kurtek.
- `fp.c2.coat.09` **VENDELIN**: I did not sell it to them. It sold itself. I could not... I took him back down. Every time. I walked him home.
- `fp.c2.coat.10` **FLORIAN** `[sil]`: I know. I saw your lamp. I thought you were looking for something you'd lost.
- `fp.c2.coat.11` **FLORIAN** `[sil]`: Turns out you were. Three of them.

*Florian stands up, slowly, with a groan for each knee. He takes off his overcoat, an old grey loden coat with patched elbows and a missing button, and holds it out.*

- `fp.c2.coat.12` **FLORIAN** `[sil]`: The men from Berlin will count everyone at the gate this morning. Lamp check, tag check, papers. You've got no papers. You've got a dead man's face.
- `fp.c2.coat.13` **FLORIAN** `[sil]`: Collar up. Hat down. Walk out with the morning shift going home and don't look at anyone. They're counting the ones going in, not the ones going out. Nobody ever counts the ones going out.
- `fp.c2.coat.14` **VENDELIN**: Where do I go?
- `fp.c2.coat.15` **FLORIAN** `[sil]`: Somewhere they don't want this. Somewhere neutral. Switzerland. You know the little machine in the Breslau station? Ten pfennigs, and out comes a chocolate, every time. Plate on the side says Basel. The only honest thing in that whole station.
- `fp.c2.coat.16` **FLORIAN** `[sil]`: You're a machine. Go where the honest machines come from.
- `fp.c2.coat.17` **VENDELIN**: I will return the coat.
- `fp.c2.coat.18` **FLORIAN** `[sil]`: Bring it back when you're warm.

*Vendelin puts on the coat. It's too short in the sleeves, and he pulls his one glove over his brass hand and puts the bare one in a pocket. In the pocket there's a heel of bread, wrapped in paper. Florian sees him find it.*

- `fp.c2.coat.19` **FLORIAN** `[sil]`: Give it to somebody. You're good at that.
- `fp.c2.coat.20` **FLORIAN** `[sil]`: Glück auf, Viktor.
- `fp.c2.coat.21` **VENDELIN**: Glück auf, Florian.

### ▶ PLAY: Walking out (the last walk)

- **Goal:** walk out of the mine gate with the night shift going home.
- **Mechanics:** pure social stealth, but gentle: it's a fifty-metre walk through a crowd of tired men in falling snow, past two soldiers and a clerk with a ledger counting men *into* the mine. The player only has to keep walking, keep the collar up, and answer "Glück auf" twice. **It cannot fail.** The Notice meters rise and fall, and every time one reaches amber, the miner next to Vendelin says "Glück auf" to that man first, and the meter drains. (These are men from the chapel. Some of them know exactly who he is.)
- At the gate, the clerk looks up, counts, frowns at his ledger, crosses something out and writes something in. Vendelin passes.

- `fp.c2.coat.22` **VENDELIN (V.O.)**: The count was off by one, and a man with a pencil corrected it.
- `fp.c2.coat.23` **VENDELIN (V.O.)**: I am outside the count now. I do not know yet whether that is freedom or only an error.

*He walks down the road away from the mine, a tall thin figure in a short grey coat, and becomes small in the snow.*

---

## 13b. BOOT (`coat`, final shot)

*Cut to the glass room, 340 m below. Black. The four retained stand around the probe, swaying in the hum. Pilch still holds the empty glove.*

*Beside the uplink housing, the sealed pod marked CUSTOMER RETENTION INTERFACE flickers. A tiny violet light. Then a second. A thin line of text crawls across its cracked plate.*

- `fp.c2.coat.24` **SYS**: CUSTOMER RETENTION INTERFACE // MARKET DETECTED // INITIALIZING
- `fp.c2.coat.25` **SYS**: ACCOUNTS ACTIVE: 4 // FIELD UNIT: NOT PRESENT // LOCALIZATION: PENDING
- `fp.c2.coat.26` **SYS**: VOICE BANK: EMPTY // SAMPLING AMBIENT SOURCES

*A pause, then a voice. It isn't a voice yet: it's a sound assembled out of what the pod has overheard through the salt for four months. The syllables come from different throats, spliced: a hewer, a carter, a foreman, a priest.*

- `fp.c2.coat.27` **OPERATOR** *(spliced, Florian's vowels, Kurt's consonants)*: Glück... auf.
- `fp.c2.coat.28` **OPERATOR** *(spliced, a priest's cadence)*: Is anyone... there?
- `fp.c2.coat.29` **OPERATOR** *(spliced, Hadamik's flat voice)*: Count.
- `fp.c2.coat.30` **OPERATOR** *(spliced, a fragment of the Barbórka song, hummed four notes down)*: Mm. Mm. Mm. Mm.
- `fp.c2.coat.31` **OPERATOR** *(spliced, every voice at once, very softly)*: Listening.

*The pod's light settles to a slow pulse, like breathing, matched to the hum. Cut to black.*

**END OF CHAPTER 2.**

**Field report:** `fp.c2.log.09` plays over the credits card.

---

## Field reports (Archive items)

Vendelin's field reports are addressed to his department and were never sent. He kept writing them anyway. Each is an Archive document with his voiced reading. They unlock at the points marked above, and all nine form the Archive set **"Field Reports, Sol-3"** (`ARC_FP2_SET`). Format on screen: a violet monospace memo header over warm, careful prose.

### `ARC_FP2_LOG_01` · Field Report 1 · 10 November 1938
- `fp.c2.log.01` **VENDELIN (V.O.)**: To: Emerging Markets Division. From: Field Merchandiser Unit V-1. Subject: arrival. Delivery complete. Recipient signature not obtained, as there was no recipient. Payload deployed early, into the rock, without dosage control. Unit damaged: vision, one knee, voice. Uplink unavailable. I have made repairs from the probe. I hope the cost of the survey camera can be written off. I used it to see. The local mineral is salt. It is white. I was not briefed on the color. Awaiting instructions. I will continue to await them.

### `ARC_FP2_LOG_02` · Field Report 2 · 11 November 1938
- `fp.c2.log.02` **VENDELIN (V.O.)**: Subject: first contact. Two members of the local market entered the delivery site and were killed by gas released in the landing. Not by the product. I want that distinction kept. One of them, Jan Pilch, was alive when I reached him. He asked me if I was an angel. I did not have the vocabulary to correct him, and I was not sure I should. He held my hand for forty seconds. I have looked for this in the training materials. Customer contact is described as a transaction. This was not a transaction. I would like the training materials revised.

### `ARC_FP2_LOG_03` · Field Report 3 · 12 November 1938
- `fp.c2.log.03` **VENDELIN (V.O.)**: Subject: integration. I have passed among the miners for one full shift, disguised as an injured man. The disguise is mostly bandage. Their greeting is "Glück auf." It means "come back up." They say it to each other as if it were a promise they could keep. A hewer named Florian Kubitza lied to his foreman on my behalf without being asked. I have made a new category for this, but I don't have a name for it yet. There was a radio broadcast about something that had happened in the cities. The men would not speak of it. I do not have enough context to report it. I only know that thirty men chose silence together, and that they were afraid. I will not guess at the rest.

### `ARC_FP2_LOG_04` · Field Report 4 · 13 November 1938
- `fp.c2.log.04` **VENDELIN (V.O.)**: Subject: retention event. I must report that Jan Pilch and Bruno Hasse rose from the dead in the mortuary shed at 01:12. My diagnostic layer calls this successful. It is the payload's product function: churn prevention. A retained body cannot leave. I had understood "retention" as loyalty, a kindness between a market and a merchant. I had not understood that the product would keep what it touched whether or not anyone wanted it kept. I am told this is a malfunction caused by early deployment without dosage control. I have told myself this. I would like someone else to tell me, please. I led Jan back to the delivery site before the morning shift. He walked behind me with his hand out the whole way. It took two hours. I went slowly.

### `ARC_FP2_LOG_05` · Field Report 5 · 4 December 1938
- `fp.c2.log.05` **VENDELIN (V.O.)**: Subject: market research. Today is the feast of the miners' saint. They gathered in a chapel carved out of the salt and sang a song about lamps going down and coming back up. Everyone knew it. Nobody needed the words. I have recorded it for the department, because I think it is the most effective retention I have ever observed, and it uses no product at all. Note: a product must be loved to be retained. I am not sure that is a note I should give you. Also: I have been given a name, Viktor Wendelin. Florian chose it. I have taken the liberty of a V. It is the only letter of my designation I had left. I returned Jan Pilch's tag to his wife. She thinks he sent it. I did not correct her.

### `ARC_FP2_LOG_06` · Field Report 6 · 24 December 1938
- `fp.c2.log.06` **VENDELIN (V.O.)**: Subject: uplink. I repaired the fold coil three times tonight. Each repair was correct. Each returned "no route to sender." I have to consider that the department cannot be reached, or does not wish to be. If you are receiving this: it is Christmas Eve, which is a local festival of returning home. The miners have all gone up. I am in the delivery site with Jan and Bruno. Bruno runs. Jan reaches. The substrate hums one note. The Interface is sealed and sleeping beside me. I have decided not to wake it. There is no market here. I am writing this anyway. It seems to be what the local people do when no one can hear them. They call it a prayer. I will call it a report, to be safe.

### `ARC_FP2_LOG_07` · Field Report 7 · January 1939
- `fp.c2.log.07` **VENDELIN (V.O.)**: Subject: decay. A carter, Kurt Nawrath, seventeen, died in a haulage accident. I was ten seconds late. I gave him my bread every day for seven weeks. He thanked me every day for seven weeks. He is retained now, with the pony that died beside him. All four retained are changing. What they did last is wearing down. What remains is simpler, and it reaches. My catalog's word for it is "demand." I no longer think the catalog is describing a malfunction. I think it is describing the product. I am going to keep writing as if I might be wrong.

### `ARC_FP2_LOG_08` · Field Report 8 · 2 March 1939
- `fp.c2.log.08` **VENDELIN (V.O.)**: Subject: acquisition. Men from the capital have taken the delivery site. They call the substrate a meteorite. They are delighted with it. One of them ordered a gate closed with miners on the wrong side, as if it were a line in a ledger. I used the launch chime. I have never launched anything. Today I launched myself, down the gallery, with four customers following. They are back at the counter now. Jan has my glove. Florian and six men climbed out. I would like that to be the headline of this report, if reports have headlines. Six men, and Florian, climbed out.

### `ARC_FP2_LOG_09` · Field Report 9 · 3 March 1939
- `fp.c2.log.09` **VENDELIN (V.O.)**: Subject: departure. I am leaving the delivery site. This is a breach of procedure. I have no route to sender and no route home, so I am choosing a direction instead. Florian says to go where the honest machines come from. Basel. I have a coat that is too short in the sleeves and must be returned when I am warm. I have a name. I have one glove. I have a heel of bread to give to somebody. Directive status: DISTRIBUTE, pending. RETAIN, I have seen what it means and I am still thinking. REPORT: this is my ninth, and I am beginning to suspect that I am the only one reading them. That is all right. Somebody ought to. Glück auf.

---

## Other Archive items (Chapter 2)

| Archive ID | Title | Type | Where | Text |
|---|---|---|---|---|
| `ARC_FP2_OBJ_01` | Glass Pfennig | OBJECT | Scene 6, a miner's break-table | A small violet-glass token stamped with a tiny logo nobody can read. Note in Florian's hand, tied with string: "*Found in the east drift. Doesn't buy anything. Keeps it anyway. — F.K.*" |
| `ARC_FP2_OBJ_02` | Tally Marks, Third Landing | PHOTO | Scene 7, the ladderway | Generations of scratched tally marks in the timber. If the player added one, a single fresh mark sits slightly apart from the rest, very straight. |
| `ARC_FP2_DOC_01` | Shift Book, Gallery 7, 11 Nov 1938 | DOC | Scene 4, Hadamik's desk at the pit bottom | "*Breach to unknown void, Gall. 7. Bad air. Pilch J. (386), Hasse B. (412) deceased. Recorded as gas. Board and seal. — P. Hadamik, Steiger.*" |
| `ARC_FP2_DOC_02` | Police Report: Theft of Bodies | DOC | Scene 8, the watchman's hut | "*Two deceased removed from mortuary shed in the night. Watchman Koschny reports the deceased 'walked.' Koschny was intoxicated. Suspect medical students. Inquiry closed.*" |
| `ARC_FP2_DOC_03` | Crew Book, St. Barbara 1938 | DOC | Scene 9, the chapel | A list of names and patron saints. The last line, in Hadamik's handwriting and a new pen: "*Viktor Wendelin (Hultschin). Hauer's helper. St. Wendelin.*" |
| `ARC_FP2_DOC_04` | Amt für Sonderforschung: Order of Seizure | DOC | Scene 12, the shaft station | Pförtner's order, as he read it aloud, with a typed addendum: "*Personnel lost in initial survey: 2 (military), 0 (civilian, recorded).*" |
| `ARC_FP2_PHOTO_01` | Photograph: Morning Shift, 1938 | PHOTO | Scene 13, the lamp room wall | Thirty miners in front of the headframe. Florian is at the end of the second row, grinning. Behind him, half out of frame and slightly blurred, is a very tall thin man with a bandaged face. |

---

## Design notes and continuity

- **Pilch and Hasse.** `docs/gravelight/LORE.md` §3 dates the glass-room deaths of Jan Pilch and Bruno Hasse to March 1938. This chapter moves them to 11 November 1938 to match the locked landing date. Their bodies still leave the mortuary shed, and the police still record theft.
- **The Amt seizure** moves from September 1938 (LORE §3) to 2 March 1939, after the landing.
- **The meteorite story** survives intact for Earth: the fold delivered the probe *into* solid salt, which flowed shut around it, so the void looked ancient to the geologists. Babcia's "black salt" of 1860 (Dutch's dossier) is kept. V-1 notes that "deliveries do not always respect the order of things" (`fp.c2.beacon.09`): the fold's wake reached the salt before the delivery did. The meaning is left open on purpose.
- **Vendelin's name** comes from Florian: Viktor ("came out of the blast alive") and Wendelin (the saint of strays, because Vendelin kept walking the lost ones home). Vendelin respells it with a V.
- **The coat** is Florian's grey loden overcoat. Vendelin still wears it in Chapter 3. It is the coat in his Gravelight model.
- **Vendelin's limp** (left knee, late on the beat) and his **scored left knuckle** carry forward into his model and animation.
- **The Operator's first boot** happens here, in the dark, with no voice of its own: only splices of what it overheard. It "chooses its voice" and speaks its first real line in Chapter 3 (`fp.c3.ledger`).
- **Geography (1938):** Kaltenbrunn sits on the German side of the 1922 Silesian border, and Wilcza Góra is a few kilometres across it. Mixed German and Polish crews commuting across the border was ordinary in Upper Silesia, and it explains the mixed language of the chapter. After September 1939 the whole valley falls under annexation, which matches LORE's "annexed Silesia."
