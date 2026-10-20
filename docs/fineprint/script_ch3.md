# THE FINE PRINT: Chapter 3, "HELVETIA AUTOMATEN AG"

**Player character:** Vendelin, as "Herr Viktor Vendelin, Ingenieur, Basel"
**Place and time:** Basel, the Swiss–German border, Grindelwald, and Kaltenbrunn, February 1940 to September 1944
**Mode:** a vignette chapter. One playable vignette per perk machine (workshop → human → jingle), with short driving/stealth interludes between them.
**Length target:** 2.5–3.5 hours
**Story job:** the perk story. How each Gravelight machine was built, who made each formula drinkable, and what it cost them. Vendelin goes from a sincere salesman who believes dilution makes his product safe to a saboteur inside his own company. The chapter ends at the Ledger, where the Operator chooses its voice and Vendelin learns he can't take it back.

Locked facts used here (`docs/M0_SHARED_FACTS.md`): Helvetia Automaten AG founded in Basel in **1940** by "Herr Viktor Vendelin, Ingenieur, Basel"; directive **"DISTRIBUTE. RETAIN. REPORT."**; **Clause 0: "Field units are inventory."**; Res Gähwiler of Grindelwald and his cousin **Anni Gähwiler**, the SOE's Basel contact; Sable Vantage, VP of Emerging Markets; the Vitality Plan IDs; the Operator's first line, *"Market localization complete. Welcome, valued customers."*

---

## Conventions

- **Line IDs:** `fp.c3.<scene>.<nn>`. Each vignette is one scene id. Its three phases share one numbering run, in order. Vendelin's workshop journal entries are `fp.c3.journal.<nn>` with Archive IDs `ARC_FP3_JRN_<nn>`.
- **Speaker tags:** `VENDELIN (V.O.)` is his internal voice. `VENDELIN` is his spoken voice (polite, slightly too correct Swiss High German, built from a Silesian hewer's vowels, so Basel people find his accent "hard to place, probably Graubünden"). `SYS` is on-screen text from his diagnostic layer. `SABLE` is Sable Vantage, always heard, never seen in this chapter.
- **Languages:** `[gsw]` Swiss German (Bernese for Res), `[de]` German, `[pl]` Polish, `[en]` English. Lines are written in English.
- **Jingles** are referred to by id (for example `jingle.ironhide_stout`). Lyrics live in `docs/JINGLES.md`. This script never rewrites them. **Fine-print panels** are referred to as `panel.<perk_id>`. Where a panel line is quoted here, it is the brief §10.2 sample line, and the full panel text lives in `docs/JINGLES.md`.

### Speakers

| Speaker id | Character | Voice notes |
|---|---|---|
| `vendelin` | Vendelin | See Chapter 2. In Basel he speaks more, and better, and is lonelier for it. |
| `fp_res` | **Res Gähwiler**, 33 (in 1940), delivery driver from Grindelwald | Bernese Oberland Swiss German. Warm, slow-spoken, very funny without trying, superstitious about everything (never says "last," knocks on his truck's wooden dash, won't whistle in a vehicle). The human heart of the chapter. |
| `fp_imhof` | **Konrad Imhof**, 54, last owner of Imhof & Cie. and nominal President of Helvetia's board | Basel German. A decent coward. Coffee with kirsch at ten in the morning. |
| `fp_kessler` | **Otto Kessler**, 51, Bavarian brewmaster from Freising, conscripted | Bavarian. Big, gentle, sarcastic about everything except beer. |
| `fp_venner` | **Dr. Kurt Venner**, head of Abteilung III (Formulation) at Kaltenbrunn | Clipped. Speaks of people in units. |
| `fp_agnieszka` | **Sister Agnieszka Wróbel**, 34, Polish nurse held as a forced laborer | Polish-accented German. Dry, devout, furious underneath, practical to the bone. Counts heartbeats under her breath. |
| `fp_ilse` | **Dr. Ilse Vogt**, 38, shift chemist at Kaltwerk Chemie | Northern German. Brisk, proud, tired, funny about her son. |
| `fp_brueck` | **Major Anselm Brück**, 47, ordnance officer | Prussian vanity. Waxed moustache, a voice that has never been told no. |
| `fp_grosi` | **Margrit Gähwiler ("Grosi")**, 81, Res's grandmother | Old Bernese mountain woman. Sharp, unimpressed, kind. |
| `fp_halina` | **Halina "Sowa" Kurek**, 44, Home Army sniper, prisoner | Polish, careful German. Very still. Never wastes a word. |
| `fp_ammer` | **Feldwebel Gustl Ammer**, 52, quartermaster | Swabian. Round spectacles, pencil behind each ear. Counts to keep from feeling. |
| `fp_saathoff` | **Oberfeldwebel Albrecht Saathoff**, 45, demolitions instructor | Loud from deafness, cheerful from habit. |
| `fp_endres` | **Pionier Lukas Endres**, 17, demolitions recruit | Thin voice, trying to sound older. |
| `fp_anni` | **Anni Gähwiler**, 31, Res's cousin; clerk at a Rhine shipping agency; SOE's Basel contact | Basel German and fast English. Dry, unflappable, smokes and never finishes a cigarette. |
| `fp_opitz` | **Hans Opitz**, 44, engineer, builder of the Ledger | Silesian German. A tinkerer who talks to relays. Likes Vendelin as a fellow technician. |
| `fp_fasbender` | **Dr. Emil Fasbender** | As in `docs/gravelight/CHARACTERS.md`. One line, seen from a distance, plus his written reply. |
| `sable` | **Sable Vantage**, VP of Emerging Markets, Darkmatter Subscriptions LLC | Velvet voice, perfect posture you can hear, says "we" when she means "you." Heard through Vendelin's core. Never seen in this chapter. |
| `darkmatter` | Darkmatter staff in the holo-memo | See scene `memo`. |
| `operator` | The Customer Retention Interface | From scene `ledger`. Before it chooses a voice, it speaks in splices. Afterward: the canon Operator voice from `docs/gravelight/CHARACTERS.md`. |
| Minor speakers | SOLDIER (Swiss, `basel`), NOTARY (`basel`), WIDOW (Liestal, `res`), CUSTOMS MAN (Stetten, `drive1`), GUARD and PIOTR (Kaltenbrunn infirmary, `secondwind`), LOADER (Kaltwerk, `trigger`), BANDLEADER and SINGER (`recording`), RECRUITS (`blastproof`), LEATHER COAT (Gestapo, `anni`), GRENZ (Swiss border guard Sepp, `anni`), SS GUARD (Lörrach, `fasbender`) | Speaker ids `fp_minor_<role>`. Piotr is 16, Polish, very weak. Leather Coat is quiet and never raises his voice. |

---

## Chapter systems

### The workshop phase (cabinet build puzzle)

Every machine is built at Vendelin's bench in the old Imhof works on the Unterer Rheinweg in Basel, with the Rhine outside the window. A build is four tactile steps in the brief's order (**bolt, wire, glass, sign**) plus one step the player can't skip:

- **BOLT:** frame and body assembly. Each machine has its own twist (listed per vignette).
- **WIRE:** a wiring board. The player routes fixed-length wires between terminals for the machine's motors, lights and dispensing valve without crossing live lines.
- **GLASS:** the bottle window, cut, bent, or assembled. Breaking it restarts this step only.
- **STENCIL (mandatory):** before the enamel goes on, the Vitality Plan ID must be stamped on the inner shell plate. The stamping press won't release the shell until it's done. From the first vignette the player feels it: the build cannot continue without it. The press shows the plan ID, for example `DMS-VP-DUR-01`.
- **SIGN:** the enamel livery, neon lettering and mascot, applied in layers. In some vignettes the sign is left blank in the workshop and finished after the human phase, because the human decides it.

From scene `panels` onward, a sixth, optional step appears on every build: **PANEL**. Engrave the fine-print panel and fix it to the machine's back with four screws. After that, the game remembers whether the player did it, and in Gravelight the panel is present either way (the machine's history isn't changed by the player). Skipping it gives one quiet V.O. line instead.

Controls are deliberately physical: hold-to-turn screws, drag wires, a heat slider for glass, layered paint passes. There's no timer except where noted. Mistakes are cheap and undoable. The puzzle is about care.

### The jingle phase (the pump organ)

Vendelin composes every jingle on a second-hand pump organ (a harmonium bought from a closing chapel in Liestal; scene `res`). It sits under the workshop window, with a cracked F-sharp reed and a pedal that squeaks.

1. **Pump.** Alternate the two triggers to work the bellows and keep air pressure in the green band. If it drops, the notes sag flat (and Vendelin apologizes to the organ).
2. **Choose.** Three decision points: **HOOK** (the opening phrase), **TURN** (the answering middle phrase) and **TAG** (the cadence). Each offers three melody fragments, previewed on the organ. Each fragment belongs to one of that machine's three **alt-mix colors**.
3. **Play it through.** Vendelin plays the player's three choices as one phrase.
4. **Resolve.** He stops, and the scripted resolution plays: his hands move to the canon melody. The final performance is always the canon jingle (`jingle.<perk_id>`), with the player's chosen fragments surviving only as the organ's counter-line in that one performance.
5. **Unlock.** The alt-mix whose color received the most picks unlocks. If all three picks differ, the TAG pick wins. The **Harmonium Demo** mix (`altmix.<perk_id>.harmonium`, Vendelin alone at the organ) always unlocks on first completion. Replaying a vignette from chapter select can unlock the others.

**Alt-mixes are Gravelight machine cosmetics.** They're equipped per machine in the Gravelight Armory (Machines tab), and the machine then plays that arrangement for proximity excerpts, the purchase jingle and the full listen. The lyrics never change, only the arrangement. IDs: `altmix.<perk_id>.<mix>`. A full table is at the end of this script.

After the scene `link` (February 1943), every jingle phase gains a fourth beat: **Brand Compliance.** When Vendelin finishes, a violet overlay marks up his score from Darkmatter ("HOOK INSUFFICIENTLY STICKY. REPEAT ×2.") and the canon resolution is played with the edit applied. He keeps his own first draft. He folds each one into the hinged lid of the organ bench. (These first drafts are the "true jingles" of Chapter 5.)

### The night drives (driving / stealth)

Res Gähwiler drives the cabinets from Basel to the German railhead at Lörrach freight yard, about 11 km, by night. The Kaltenbrunn contract requires deliveries "between 22:00 and 04:00, without lights where practicable, and not by the main customs road." From Lörrach the cabinets travel by sealed Reichsbahn wagon to Silesia, with Res and Vendelin riding as the company's escorts (shown in cutscene only).

The legal cargo isn't the problem. The problem is what Res carries in the **false floor** under the truck bed: letters, medicine, a battery, a bottle. Each drive is a 4–6 minute sequence in **Vreneli**, Res's 1934 Saurer lorry, with Vendelin in the passenger seat or, at some checkpoints, nailed inside a crate marked *Ersatzteile · Vorsicht Glas* ("spare parts, fragile"), because a pat-down would find metal.

Shared driving rules:
- **Lights.** Blackout-hooded headlights on, or fully off. Off is invisible to patrols but means steering by moonlight and the pale line of the road edge. Ditches are real.
- **Engine.** Engine noise carries. On downhill stretches Res can cut the engine and coast (the "Grindelwald method").
- **Patrols and posts.** Swiss Grenzwacht foot patrols with lanterns, German customs posts, and in later drives a Gestapo car. Each has a sight cone (for lights) and a hearing radius (for engine noise).
- **Checkpoints** are dialogue scenes. Papers, a manifest, a short exchange with choices. Wrong answers raise a **Search** meter. A full Search meter means the guard checks the truck bed, and the player gets one last chance (a distraction choice) before the false floor is found. If it's found, the drive restarts from the last checkpoint.
- **Vreneli** stalls if pushed too hard on cold starts. Res talks to her. It helps (a real +10% chance to restart).

---

## Scene list

| # | Scene id | Title | Date | Kind |
|---|---|---|---|---|
| 1 | `basel` | Where the Honest Machines Come From | Feb 1940 | Arrival, founding |
| 2 | `contract` | A Hotel Room in Zürich | May 1940 | Short scene |
| 3 | `res` | The Driver | Apr–Jun 1940 | Meeting Res, the organ |
| 4 | `ironhide` | Ironhide Stout (Otto Kessler) | Mar 1941 | Vignette |
| 5 | `imhof` | What the Director Saw | Oct 1941 | Interlude |
| 6 | `drive1` | First Night Drive | Oct 1941 | Driving / stealth |
| 7 | `secondwind` | Second Wind Schnapps (Sister Agnieszka) | Jan 1942 | Vignette |
| 8 | `battery` | The Standby Cell | Feb 1942 | Interlude + drive 2 |
| 9 | `trigger` | Trigger Tonic (Dr. Ilse Vogt) | May 1942 | Vignette |
| 10 | `twinbarrel` | Twin Barrel Bitters (Major Anselm Brück) | Aug 1942 | Vignette |
| 11 | `recording` | Studio Rheinklang | Sep 1942 | Interlude |
| 12 | `marathon` | Marathon Malt (Res's grandmother) | Nov 1942 | Vignette |
| 13 | `link` | Route to Sender | 9 Feb 1943 | Interlude |
| 14 | `memo` | Holo-memo: Engagement Incentives | "Yesterday" | Holo-memo |
| 15 | `hawkeye` | Hawkeye Brandy (Halina "Sowa" Kurek) | Apr 1943 | Vignette |
| 16 | `panels` | The Fine Print | May 1943 | Stealth interlude |
| 17 | `packmule` | Packmule Porter (Feldwebel Gustl Ammer) | Jul 1943 | Vignette |
| 18 | `blastproof` | Blastproof Bock (the demolitions school) | Oct 1943 | Vignette |
| 19 | `anni` | The Bock Label | Oct 1943 | Drive 3 + Anni |
| 20 | `fernet` | Fine Print Fernet (prototype) | Mar 1944 | Vignette |
| 21 | `overclock` | Overclock Cordial (blueprint) | Apr 1944 | Vignette (unfinishable) |
| 22 | `fasbender` | A Letter in the Machine | Jul 1944 | Drive 4 + stealth |
| 23 | `ledger` | Market Localization | Sep 1944 | Finale |
| 24 | `outro` | The Drive Home | Sep 1944 | Epilogue |
| — | `journal` | Workshop journal (Archive) | Throughout | |

---

## 1. WHERE THE HONEST MACHINES COME FROM (`basel`)

*Cold open. A montage, February 1939 to February 1940, under Vendelin's V.O. A tall man in a short grey coat walks down a winter road in Silesia; sleeps upright in a hay barn; rides a freight car through Saxony; mends a station clock in Franconia for a stationmaster who offers him soup, which he gives to a child; walks the snowy shoulder of a road in Baden with a cardboard suitcase. The coat gets more patched. He has one glove.*

- `fp.c3.basel.01` **VENDELIN (V.O.)**: Eleven months. I repaired fourteen clocks, nine wirelesses, a church organ and a threshing machine. I was paid in soup, which I gave away, and in directions, which I kept.
- `fp.c3.basel.02` **VENDELIN (V.O.)**: Everyone I asked about Switzerland pointed south and lowered their voice, as if it were a rumour.
- `fp.c3.basel.03` **VENDELIN (V.O.)**: Somewhere in Württemberg the war began. I learned it from a newspaper used to wrap a fish. I gave the fish away as well.

*Basel, the SBB station concourse, February 1940. Soldiers of the Swiss army on mobilization duty, travellers with too much luggage. Against a pillar stands a small enamel vending machine for chocolate, the twin of the one in the Breslau station. Its plate reads IMHOF & CIE. · BASEL · SEIT 1921. A hand-written card on its glass says AUSSER BETRIEB (out of order).*

- `fp.c3.basel.04` **VENDELIN (V.O.)**: It is the same model. Florian's honest machine.
- `fp.c3.basel.05` **VENDELIN (V.O.)**: It is broken.

### ▶ PLAY: The chocolate machine (tutorial)

A short tutorial for the workshop controls, in public: open the back panel with his pocket screwdriver, find the bent coin chute, straighten it, re-tension the spring, close up. A Swiss soldier on a bench watches the whole time. When it works, Vendelin puts in ten Rappen. A chocolate drops. He gives it to the soldier.

- `fp.c3.basel.06` **SOLDIER** `[gsw]`: Merci. You work for Imhof?
- `fp.c3.basel.07` **VENDELIN**: No. I only admire his machines.
- `fp.c3.basel.08` **SOLDIER** `[gsw]`: Then admire them fast. Imhof's going bankrupt. Everybody knows. The chocolate's from before the war. Tastes like it, too.

*Kleinbasel, the Imhof works on the Unterer Rheinweg. A narrow workshop and office on the Rhine embankment, half the machines under dust sheets. KONRAD IMHOF sits in his office with a coffee that smells strongly of kirsch.*

- `fp.c3.basel.09` **IMHOF** `[de]`: If you're from the bank, sit down. If you're from the tax office, stand up, so I can see you leave.
- `fp.c3.basel.10` **VENDELIN**: I am an engineer, Herr Imhof. I repaired your machine in the station this morning.
- `fp.c3.basel.11` **IMHOF** `[de]`: Which one? They're all broken. My father built them to last forever, and they've decided to prove him wrong all at once.
- `fp.c3.basel.12` **VENDELIN**: The one by the second pillar. The coin chute was bent. It is no longer bent.
- `fp.c3.basel.13` **IMHOF** `[de]`: Well. Thank you. I can't pay you.
- `fp.c3.basel.14` **VENDELIN**: I did not come to be paid. I came to propose a partnership.
- `fp.c3.basel.15` **IMHOF** `[de]`: *(laughs)* With what? I have eleven employees I can't pay, a workshop the bank owns, and a name that means "chocolate that tastes of 1938."
- `fp.c3.basel.16` **VENDELIN**: I can bring you a contract. A large one. Beverage dispensers. Hygienic, coin-operated, for a mineral tonic, for medical and military use.
- `fp.c3.basel.17` **IMHOF** `[de]`: Military. Whose military?
- `fp.c3.basel.18` **VENDELIN**: A neutral company sells to whoever orders. That is what neutral means, I am told.
- `fp.c3.basel.19` **IMHOF** `[de]` *(long pause, drinking)*: ...And what do you want for this contract that falls from the sky?
- `fp.c3.basel.20` **VENDELIN**: The workshop. A share. And a new name, because yours has been unlucky.
- `fp.c3.basel.21` **IMHOF** `[de]`: What name?
- `fp.c3.basel.22` **VENDELIN**: Helvetia Automaten.
- `fp.c3.basel.23` **IMHOF** `[de]`: Helvetia. Every second firm in this country is called Helvetia. Helvetia Insurance, Helvetia Sewing Machines, Helvetia Pickled Herring.
- `fp.c3.basel.24` **VENDELIN**: That is why people will trust it. It sounds like something that has always been there.

*Imhof looks at him for a long time: the gloves indoors, the hat he hasn't taken off, the coat too short in the sleeves.*

- `fp.c3.basel.25` **IMHOF** `[de]`: You never take off your gloves.
- `fp.c3.basel.26` **VENDELIN**: An injury. From a mine.
- `fp.c3.basel.27` **IMHOF** `[de]`: ...My father always said: never ask a good engineer where his hands have been. All right, Herr...?
- `fp.c3.basel.28` **VENDELIN**: Vendelin. Viktor Vendelin.
- `fp.c3.basel.29` **IMHOF** `[de]`: Bring me your contract, Herr Vendelin, and I'll give you my father's workshop and a stupid new name. If you don't, I'll still be bankrupt, so what do I lose.

*A notary's office, a week later. The registration of Helvetia Automaten AG. Imhof signs as President of the board (a Swiss board needs a Swiss director). Then the notary turns the register to Vendelin.*

- `fp.c3.basel.30` **NOTARY** `[de]`: And your occupation, for the register?
- `fp.c3.basel.31` **VENDELIN**: Engineer.
- `fp.c3.basel.32` **NOTARY** `[de]`: Domicile?
- `fp.c3.basel.33` **VENDELIN** *(a fractional pause)*: Basel.

*He signs. Close on the register in the notary's copperplate: **Herr Viktor Vendelin, Ingenieur, Basel.***

- `fp.c3.basel.34` **VENDELIN (V.O.)**: Directive one: DISTRIBUTE.
- `fp.c3.basel.35` **VENDELIN (V.O.)**: I have thought about Jan, and Bruno, and Kurt, every day for eleven months. I have decided what happened to them was the product deployed without control. Raw. Undiluted. Unmeasured.
- `fp.c3.basel.36` **VENDELIN (V.O.)**: My catalog has a correct way. Vitality Plans. A few parts in a million, in a drink, in a clean machine, with a label. Strength for a day. Courage for an hour. Measured, diluted, chosen.
- `fp.c3.basel.37` **VENDELIN (V.O.)**: I am going to do it the correct way. I believe that. I would like it noted that I believed it.

*That night, in the workshop office, he types a long technical memorandum on the Imhof company typewriter: "On the Dilution of the Kaltenbrunn Mineral for Restorative Use, with a Proposal for Hygienic Dispensing." He addresses it to the Amt für Sonderforschung, Berlin. He doesn't sign it. Archive: `ARC_FP3_DOC_01`.*

---

## 2. A HOTEL ROOM IN ZÜRICH (`contract`)

*May 1940. A corridor in the Hotel Seeblick, Zürich. Vendelin waits on a bench outside room 214, hat on his knee. Through the door: murmurs, a laugh, a fountain pen. The door opens. Konrad Imhof comes out, pale, holding a contract folder.*

- `fp.c3.contract.01` **IMHOF** `[de]`: Twelve dispensers to start. Enamel finish, sponsor livery "at buyer's discretion." The money is... the money is very good, Vendelin.
- `fp.c3.contract.02` **VENDELIN**: Then the company is saved.
- `fp.c3.contract.03` **IMHOF** `[de]`: The man in there called himself a trustee from Alpina Treuhand. He had a Berlin accent and a Zürich address and a ring on the wrong finger. He didn't say what's in the tonic.
- `fp.c3.contract.04` **VENDELIN**: A mineral. Diluted.
- `fp.c3.contract.05` **IMHOF** `[de]`: You know what's in it.
- `fp.c3.contract.06` **VENDELIN**: I know it is very little. A few parts in a million.
- `fp.c3.contract.07` **IMHOF** `[de]` *(not reassured, but deciding to be)*: A few parts in a million. Well. My father put a few parts in a million of arsenic in the green enamel. Everybody does.

*They walk down the corridor. Imhof stops at the stairs.*

- `fp.c3.contract.08` **IMHOF** `[de]`: I'll be President. I'll sign things. But I don't want to know, Vendelin. You understand? I want to be a man who didn't know.
- `fp.c3.contract.09` **VENDELIN**: I understand.
- `fp.c3.contract.10` **VENDELIN (V.O.)**: I did not understand. I thought not knowing was a fault, like a bent coin chute. I thought it could be straightened.

---

## 3. THE DRIVER (`res`)

*April 1940. The Imhof works yard, Unterer Rheinweg. A hand-lettered card in the gate: FAHRER GESUCHT (driver wanted). Vendelin waits by the gate with a pocket watch. It is 9:14. The interview was at nine.*

*A battered dark-green Saurer lorry grinds up the embankment and stops. RES GÄHWILER climbs down: stocky, red-cheeked, a felt hat with a sprig of edelweiss pinned in it, a St. Christopher medal outside his shirt.*

- `fp.c3.res.01` **RES** `[gsw]`: Grüessech. Gähwiler, Andreas, everyone says Res. I'm late. I know I'm late. There was a black cat on the Wettstein bridge.
- `fp.c3.res.02` **VENDELIN**: A cat.
- `fp.c3.res.03` **RES** `[gsw]`: Black. Left to right. You can't cross after that, not straight away, you have to go round by the Mittlere Brücke, and the Mittlere Brücke had a tram stopped on it, so.
- `fp.c3.res.04` **VENDELIN**: You went round a cat.
- `fp.c3.res.05` **RES** `[gsw]`: I went round bad luck, Herr... You're the engineer. You've got the gloves. They said in the café, look for the tall one in gloves.
- `fp.c3.res.06` **VENDELIN**: Vendelin. Are you a careful driver, Herr Gähwiler?
- `fp.c3.res.07` **RES** `[gsw]`: I'm from Grindelwald. I learned to drive on the road down from the Grosse Scheidegg with a load of cheese. You drive carefully on that road or you become cheese.
- `fp.c3.res.08` **VENDELIN**: The work is across the border. At night. To Germany, and sometimes beyond.
- `fp.c3.res.09` **RES** `[gsw]` *(the cheer going out of him a little)*: ...At night.
- `fp.c3.res.10` **VENDELIN**: The client prefers it.
- `fp.c3.res.11` **RES** `[gsw]`: Clients who prefer the night. My grandmother has a lot to say about those.
- `fp.c3.res.12` **VENDELIN**: Does she drive?
- `fp.c3.res.13` **RES** `[gsw]`: She's eighty. She'd drive better than half of Basel.

*He pats the lorry's fender.*

- `fp.c3.res.14` **RES** `[gsw]`: This is Vreneli. She's a Saurer, nineteen-thirty-four, and she stalls when she's cold and when she's insulted. Don't insult her.
- `fp.c3.res.15` **VENDELIN**: I would not. *(to the lorry, gravely)* Good morning.
- `fp.c3.res.16` **RES** `[gsw]` *(a delighted pause)*: ...You're hired. I mean, I'm hired. Am I hired?
- `fp.c3.res.17` **VENDELIN**: You are hired.

### ▶ PLAY: Fetching the organ (driving tutorial, daylight)

*June 1940. A daylight drive out to Liestal to buy a harmonium from a small chapel that is closing. It teaches steering, the clutch-and-stall system, coasting downhill with the engine off, and talking to Vreneli. There are no threats.*

*In the cab, on the road.*

- `fp.c3.res.18` **RES** `[gsw]`: What does a vending company need with a church organ?
- `fp.c3.res.19` **VENDELIN**: Every product needs a song.
- `fp.c3.res.20` **RES** `[gsw]`: Does it? The chocolate never had a song.
- `fp.c3.res.21` **VENDELIN**: That is one reason it failed.
- `fp.c3.res.22` **RES** `[gsw]`: The other reason being it tasted of floor.
- `fp.c3.res.23` **VENDELIN**: That is the other reason.

*Res unwraps a sandwich. Offers half.*

- `fp.c3.res.24` **RES** `[gsw]`: Cheese and onion.
- `fp.c3.res.25` **VENDELIN**: No, thank you. I have eaten.
- `fp.c3.res.26` **RES** `[gsw]`: When?
- `fp.c3.res.27` **VENDELIN**: ...Previously.
- `fp.c3.res.28` **RES** `[gsw]` *(looks at him, then at the road)*: In Grindelwald we say, don't count the teeth of a goat that pulls your cart. You understand?
- `fp.c3.res.29` **VENDELIN**: No.
- `fp.c3.res.30` **RES** `[gsw]`: It means I'm not going to ask why you never eat. Here. I'll eat both halves. It's a sacrifice, but I'm Catholic.

*The chapel in Liestal: the elderly pastor's widow sells them the harmonium for forty francs and a promise that "it will go on playing hymns." They load it into Vreneli. The F-sharp reed is cracked.*

- `fp.c3.res.31` **WIDOW** `[gsw]`: It will play hymns, Herr Vendelin? You promise?
- `fp.c3.res.32` **VENDELIN**: It will play songs that people will know by heart.
- `fp.c3.res.33` **WIDOW** `[gsw]`: That's what a hymn is. God bless.
- `fp.c3.res.34` **VENDELIN (V.O.)**: I promised her it would play songs people would know by heart. It did. I did not lie to her. I would like to have lied to her.

---

## 4. IRONHIDE STOUT (`ironhide`): Otto Kessler

*March 1941. Plan: **DURABILITY+**, `DMS-VP-DUR-01`.*

### WORKSHOP

*The Basel workshop. The Rhine outside, grey and fast. Blueprints pinned up: a squat cabinet shaped like a barrel stood on end. Abteilung III's brief, typed, reads: "For assault engineers. Robust. Cheerful. Nothing that looks like medicine."*

- `fp.c3.ironhide.01` **VENDELIN (V.O.)**: The first plan. DURABILITY+. A body that takes more before it stops.
- `fp.c3.ironhide.02` **VENDELIN (V.O.)**: A barrel. Barrels are cheerful. Nobody is afraid of a barrel.

**▶ BUILD**
1. **BOLT: Hoops.** Rivet three iron hoops around the cabinet. Each rivet is a hold-and-release on the riveting press. A steady rhythm gives clean heads, and a rushed or dragged one gives a crooked rivet that has to be drilled out. A metronome is offered as an assist. It ticks at 112, the jingle's future tempo, though the player doesn't know that yet.
2. **WIRE:** three circuits on one board: the dispensing valve's solenoid, the neon transformer for the IRONHIDE sign, and a small motor for the mascot's flexing tin arm. The wires have fixed lengths. Crossing the neon's high-voltage line with anything else sparks and resets the board.
3. **GLASS:** bend a flat pane to the barrel's curve in the annealing oven. Hold a heat slider in the amber band while the glass sags over a wooden form. Too hot and it cracks. Too cool and it springs back flat.
4. **STENCIL:** stamp `DMS-VP-DUR-01` on the inner shell plate. The press won't release the shell until it's done.
5. **SIGN:** enamel layers: iron-red base, blackened hoops, brass rivet dots (one click per rivet, which is satisfying), then the **Fassl** decal: a cheerful riveted barrel with stubby arms, flexing. Then the slab-lettered IRONHIDE neon and the script line *Stout · Stark · Standhaft*.

- `fp.c3.ironhide.03` **VENDELIN (V.O.)**: The stencil goes under the paint. Nobody will ever see it.
- `fp.c3.ironhide.04` **VENDELIN (V.O.)**: That is the correct procedure. A plan should know what it is, even if the customer does not.

### HUMAN

*Kaltenbrunn, the garrison mess hall. One corner has been turned into a small brewhouse: two copper kettles, sacks of malt, a cooling tray. OTTO KESSLER, a big man in a too-small field-grey uniform under a leather brewer's apron, stirs a kettle. DR. KURT VENNER of Abteilung III stands by with a clipboard. Vendelin arrives with the finished cabinet on a hand truck, in his grey coat and hat. The cabinet is still covered by a tarpaulin.*

- `fp.c3.ironhide.05` **VENNER** `[de]`: Herr Vendelin, from the Swiss firm. Kessler, our formulator. Kessler, the dispenser has arrived. I trust the product will be ready to fill it.
- `fp.c3.ironhide.06` **KESSLER** `[de]`: The product tastes like licking a cannon, Herr Doktor.
- `fp.c3.ironhide.07` **VENNER** `[de]`: Then make it taste like something else. That is why you are here and not in a field kitchen. Heil Hitler.

*Venner leaves. Kessler doesn't return the salute. He looks at Vendelin.*

- `fp.c3.ironhide.08` **KESSLER** `[de]`: You're Swiss.
- `fp.c3.ironhide.09` **VENDELIN**: I am from Basel.
- `fp.c3.ironhide.10` **KESSLER** `[de]`: Lucky man. They took me out of my brewhouse in Freising. Three hundred years my family's brewed beer. They put me in a field kitchen making soup for pioneers. Then a man with a clipboard tasted my soup and decided I was a chemist.
- `fp.c3.ironhide.11` **VENDELIN**: Was the soup good?
- `fp.c3.ironhide.12` **KESSLER** `[de]`: The soup was magnificent. That was my mistake.

*He ladles a little grey liquid from a steel can marked with a violet stripe into a cup and holds it out.*

- `fp.c3.ironhide.13` **KESSLER** `[de]`: Here's the "tonic." Raw, from the lab. Smell it.
- `fp.c3.ironhide.14` **VENDELIN**: It smells of iron and salt.
- `fp.c3.ironhide.15` **KESSLER** `[de]`: Iron and salt and tin and graves. They want me to put this in boys going over wire under fire. Fine. If I have to put it in them, it'll go in as beer. A proper stout. Not medicine.
- `fp.c3.ironhide.16` **VENDELIN**: Why stout?
- `fp.c3.ironhide.17` **KESSLER** `[de]`: Because it's dark enough to hide the color, heavy enough to hide the taste, and every man from Munich to Hamburg drinks it on Sunday with his father. If a boy has to drink this, let it taste like Sunday. Roasted barley. Smoked malt for the tin. Molasses.
- `fp.c3.ironhide.18` **KESSLER** `[de]`: And spite. A good handful of spite.
- `fp.c3.ironhide.19` **VENDELIN**: Is spite an ingredient?
- `fp.c3.ironhide.20` **KESSLER** `[de]`: In Bavaria it's the main one.

### ▶ PLAY: Brewing with Kessler (a short cooperative task)

Kessler calls out steps and Vendelin does them: stir the mash at a steady pace, add the roasted barley when the colour turns, read the thermometer, tip in the "tonic" at the cooling stage a measured spoon at a time. Vendelin's precision makes it perfect, and Kessler notices.

- `fp.c3.ironhide.21` **KESSLER** `[de]`: You measure like a clock. Were you a brewer?
- `fp.c3.ironhide.22` **VENDELIN**: No. I was a miner, briefly.
- `fp.c3.ironhide.23` **KESSLER** `[de]`: Then you know about things that come out of the ground and shouldn't.

*The stout is ready: black, with a tan head. Kessler fills two glasses. Then he stops, looks at both glasses, and pours one back into the kettle.*

- `fp.c3.ironhide.24` **KESSLER** `[de]`: Venner wants it tested on the engineers tomorrow. Twelve volunteers. Volunteers. You know what volunteer means in the army? It means the sergeant pointed.
- `fp.c3.ironhide.25` **VENDELIN**: What are you going to do?
- `fp.c3.ironhide.26` **KESSLER** `[de]`: What any brewer does with a new batch. Taste it first.
- `fp.c3.ironhide.27` **VENDELIN**: Herr Kessler, the long-term effects are not established.
- `fp.c3.ironhide.28` **KESSLER** `[de]`: Then they'll be established on a fat old man from Freising instead of a nineteen-year-old from Kiel. Prost, Herr Ingenieur.

*He drinks the whole glass. A long pause. He wipes his mouth.*

- `fp.c3.ironhide.29` **KESSLER** `[de]`: ...God forgive me. It's good stout.

*He sets the glass down and, as if testing something, raps his knuckles hard on the copper kettle. Then harder. Then he punches it. The copper dents. He looks at his hand. It's unmarked.*

- `fp.c3.ironhide.30` **KESSLER** `[de]`: I can't feel that.
- `fp.c3.ironhide.31` **KESSLER** `[de]` *(quietly)*: That's no good, Herr Ingenieur. A stout should let you feel everything. That's what it's for.
- `fp.c3.ironhide.32` **VENDELIN**: It will wear off. In a few hours. It is a very small amount.
- `fp.c3.ironhide.33` **KESSLER** `[de]`: Will it?
- `fp.c3.ironhide.34` **VENDELIN**: ...That is the design.

*Kessler takes a folded sheet from his apron, a list in pencil.*

- `fp.c3.ironhide.35` **KESSLER** `[de]`: Do me a favor, Swiss. This is a beer order. Hops, malt, yeast, for my wife's brewhouse in Freising. Post it from Basel. Not from here. Here, they read everything.
- `fp.c3.ironhide.36` **VENDELIN** *(reading)*: "Twelve sacks of pale malt. The volunteers stopped feeling the cold." This is not a beer order.
- `fp.c3.ironhide.37` **KESSLER** `[de]`: Vroni will know how to read it. Twenty-six years married. She reads me like a recipe.

*Vendelin folds the paper into his coat. He takes the tarpaulin off the cabinet. Kessler sees Fassl, the cheerful flexing barrel, for the first time.*

- `fp.c3.ironhide.38` **KESSLER** `[de]` *(despite himself, a laugh)*: Look at him. Look at that stupid barrel. He's got no idea, has he?
- `fp.c3.ironhide.39` **VENDELIN**: No. He is very happy.
- `fp.c3.ironhide.40` **KESSLER** `[de]`: Then he's the only one here. Leave him. Somebody ought to be.

### JINGLE

*Basel, night. The workshop. Vendelin at the harmonium. Rain on the window. The tarpaulin from Kaltenbrunn lies folded on a chair. Style target: a Bavarian beer-hall oom-pah march (see `jingle.ironhide_stout`).*

- `fp.c3.ironhide.41` **VENDELIN (V.O.)**: Kessler said it should taste like Sunday. So it should sound like Sunday. A brass band in a square. Men with their fathers.
- `fp.c3.ironhide.42` **VENDELIN (V.O.)**: Something you would sing even if you did not want to.

**▶ CHOOSE**

| Decision | Fragment (color → alt-mix) |
|---|---|
| **HOOK** | **A.** A broad, slow brass call rising a sixth, like a town band warming up in a Freising square → `freising` · **B.** The hook rapped out in staccato, ladle-on-pot rhythm, two quick notes then a stamp → `fieldkitchen` · **C.** The hook doubled by a deep thud on beats one and two, like a cooper's mallet on a stave → `cooper` |
| **TURN** | **A.** A warm descending answer in thirds, the way two old men harmonize badly and happily → `freising` · **B.** A clattering run up the scale with a tin-cup "clink" on top → `fieldkitchen` · **C.** A heavy tuba walk-down, one note per step, slow as rolling a full barrel → `cooper` |
| **TAG** | **A.** A held chord that swells and resolves late, like a toast that goes on a little too long → `freising` · **B.** Three short hits and a shout gap → `fieldkitchen` · **C.** One great mallet blow and silence → `cooper` |

*He plays the player's phrase through. Then he stops, his hands above the keys.*

- `fp.c3.ironhide.43` **VENDELIN (V.O.)**: It is good. It is not enough. It has to be the one that sticks. The one a boy hums going over the wire.
- `fp.c3.ironhide.44` **VENDELIN (V.O.)**: I hate that I know how to do that.

*His hands move. The canon melody of `jingle.ironhide_stout` resolves out of the harmonium, the player's fragments threaded under it as the organ's counter-line. He plays it through once. Then, very quietly, he plays it again, because he can't stop, and his gloved foot taps.*

- `fp.c3.ironhide.45` **VENDELIN (V.O.)**: I tapped my foot. I do not have a reason to tap my foot. It happened anyway.

**Unlocks:** `altmix.ironhide_stout.harmonium` + one of `altmix.ironhide_stout.freising` / `.fieldkitchen` / `.cooper`.

**Journal:** `fp.c3.journal.01`.

---

## 5. WHAT THE DIRECTOR SAW (`imhof`)

*October 1941. The Basel workshop, late. Konrad Imhof comes in from the street without knocking, still in his travelling coat, carrying a briefcase. He's just back from his one visit to Kaltenbrunn. He walks past Vendelin to the workshop stove, opens it, and begins feeding papers into it from the briefcase.*

- `fp.c3.imhof.01` **VENDELIN**: Herr Imhof. Those are your notes from the visit.
- `fp.c3.imhof.02` **IMHOF** `[de]`: They were. They're getting warm now.
- `fp.c3.imhof.03` **VENDELIN**: What did they show you?
- `fp.c3.imhof.04` **IMHOF** `[de]`: A demonstration. Of the "restorative effect." In a room with a drain in the floor. A man was... a man was given the drink, and then a man was shot, and then...

*He stops. Feeds in another page.*

- `fp.c3.imhof.05` **IMHOF** `[de]`: I told you in Zürich. I want to be a man who didn't know. I'm going to go home and be him now. I'll keep signing. Don't ever tell me anything again.
- `fp.c3.imhof.06` **VENDELIN**: Herr Imhof...
- `fp.c3.imhof.07` **IMHOF** `[de]`: You knew. Didn't you. When you came in with your gloves and your contract, you knew.
- `fp.c3.imhof.08` **VENDELIN**: I knew it could happen undiluted. I believed—
- `fp.c3.imhof.09` **IMHOF** `[de]`: Believe it at home, Vendelin. Good night.

*He leaves. The papers burn. Vendelin stands at the stove until they're ash.*

- `fp.c3.imhof.10` **VENDELIN (V.O.)**: "A room with a drain in the floor."
- `fp.c3.imhof.11` **VENDELIN (V.O.)**: The plans are diluted. The plans are measured. The plans are not the room with the drain.
- `fp.c3.imhof.12` **VENDELIN (V.O.)**: The plans are delivered to the same building as the room with the drain.

---

## 6. FIRST NIGHT DRIVE (`drive1`)

*October 1941. The second delivery: replacement parts for the Ironhide cabinet and the first two crates for the Salt Chapel installation. In the false floor of Vreneli's bed, wrapped in oilcloth: Kessler's second "beer order," and eleven letters from Kaltenbrunn's Bavarian conscripts to their families, collected by Kessler, which Res will post inside Germany to dodge the facility censor.*

*In the cab, the Basel streets blacked out (Swiss blackout since November 1940). Res drives with the hooded headlights.*

- `fp.c3.drive1.01` **RES** `[gsw]`: Rules. One: we don't whistle. Whistling calls the wind, and the wind calls the police.
- `fp.c3.drive1.02` **VENDELIN**: Is that true?
- `fp.c3.drive1.03` **RES** `[gsw]`: Two: if I knock on the dash, you knock on the dash. Three: if a man with a torch asks you a question, you're Swiss, you're boring, and you're thinking about lunch.
- `fp.c3.drive1.04` **VENDELIN**: I can be boring.
- `fp.c3.drive1.05` **RES** `[gsw]`: I've noticed.

### ▶ PLAY: Drive 1 (tutorial: lights, coasting, one checkpoint)

- **Leg 1, Riehen road:** hooded lights on. A Swiss Grenzwacht foot patrol with a lantern stands at a crossroads. Switch lights off and roll past in the dark beyond their lantern range, or keep them on and accept a friendly wave (the patrol knows Vreneli: no Search penalty on the Swiss side this time).
- **Leg 2, the German customs post at Stetten:** a full checkpoint (below).
- **Leg 3, the Dinkelberg forest road to Lörrach:** lights off, coasting downhill with the engine cut. Steer by the pale road edge and avoid a ditch. A German motorcycle patrol on the main road below: its headlight sweeps across the trees, and the player has to stop while it passes.
- **Arrival:** Lörrach freight yard, the sealed wagon, a Reichsbahn official with a stamp.

**Checkpoint, Stetten**

- `fp.c3.drive1.06` **CUSTOMS MAN** `[de]`: Papers. Manifest. What's in the crates?
- `fp.c3.drive1.07` **RES** `[gsw]`: Vending machine parts, for the Kaltenbrunn contract. Helvetia Automaten. You'll have the order on your list.
- `fp.c3.drive1.08` **CUSTOMS MAN** `[de]`: At two in the morning?
- *Player choice (Res's answer):*
  - **"The client wants it this way."** *(safe)* → `fp.c3.drive1.09`
  - **"The machines are shy."** *(joke: +Search, but the guard laughs)* → `fp.c3.drive1.10`
  - **"Would you like a chocolate?"** *(bribe: big +Search; triggers the bed check)* → `fp.c3.drive1.11`
- `fp.c3.drive1.09` **RES** `[gsw]`: The client likes the night. It's on page four of the contract. I can read it to you, it's very boring.
- `fp.c3.drive1.10` **RES** `[gsw]`: The machines are shy, sir. In daylight they won't come out of the crates.
- `fp.c3.drive1.11` **RES** `[gsw]`: Chocolate? Swiss. Real. From before the war, tastes a bit of floor.
- `fp.c3.drive1.12` **CUSTOMS MAN** `[de]` *(looking at Vendelin)*: And him?
- `fp.c3.drive1.13` **VENDELIN**: I am the engineer. I am thinking about lunch.
- `fp.c3.drive1.14` **CUSTOMS MAN** `[de]` *(a beat; then, bored)*: ...Go on.

*Back on the road. Res drives a while in silence.*

- `fp.c3.drive1.15` **RES** `[gsw]`: "I am thinking about lunch." You said it like a man reading his own death notice.
- `fp.c3.drive1.16` **VENDELIN**: I have never thought about lunch.
- `fp.c3.drive1.17` **RES** `[gsw]`: Then you've never been happy, Herr Vendelin. That's the saddest thing I've heard all year, and I've heard the news.

*At the freight yard, the cabinets are loaded into the sealed wagon. Res slips the oilcloth packet of letters into his coat to post from a village box on the way home.*

- `fp.c3.drive1.18` **RES** `[gsw]`: Eleven letters. Eleven mothers in Bavaria who'll hear their boys are cold and hungry instead of hearing nothing. Worth a cat or two.
- `fp.c3.drive1.19` **VENDELIN**: You did not tell me you were carrying letters.
- `fp.c3.drive1.20` **RES** `[gsw]`: You didn't tell me why the client likes the night. We're even.

---

## 7. SECOND WIND SCHNAPPS (`secondwind`): Sister Agnieszka

*January 1942. Plan: **CONTINUITY (Free Trial)**, `DMS-VP-CON-00`.*

### WORKSHOP

*Basel. The brief from Abteilung III: "Revival compound, staff use. Clean, medical, calming." Blueprints: a tall slender cabinet like an apothecary's, with a domed glass top.*

**▶ BUILD**
1. **BOLT:** the slender frame. It's tall and top-heavy, so the bolts must be tightened in a star pattern, a quarter-turn each in sequence. Tighten one fully out of order and the frame racks (a visible lean) and must be loosened and redone.
2. **WIRE:** two small motors: the turntable that slowly rotates the display bottle under the dome, and a little bellows that wheezes every five seconds, like breathing. Then the third circuit, which arrives pre-made from the plan template: a thumb-sized violet-glass capsule containing a three-toothed ratchet, wired into the dispensing valve. Its label: **CONTINUITY · FREE TRIAL · 3 (THREE) RETURNS**.

- `fp.c3.secondwind.01` **VENDELIN (V.O.)**: A free trial. Three returns. Then the cabinet withdraws its offer.
- `fp.c3.secondwind.02` **VENDELIN (V.O.)**: I do not want a revival machine that stops reviving. I am going to take this out.

**▶ The capsule (designed to fail).** The player gets three attempts, each a small puzzle that seems to work:
- **Cut the lead.** The valve then refuses to open at all. The cabinet is dead.
- **Bypass the capsule** with a jumper wire. It works for a moment, then a hair-thin violet thread grows out of the capsule along the jumper and reconnects the ratchet. The bypass is absorbed.
- **Remove the capsule entirely.** The stencilled plate inside the shell glows through the bare metal: `DMS-VP-CON-00`. The whole cabinet locks, every motor stops, and a tiny SYS line appears.
- `fp.c3.secondwind.03` **SYS**: PLAN INTEGRITY: TRIAL TERMS ARE NON-SEVERABLE.
- `fp.c3.secondwind.04` **VENDELIN (V.O.)**: Non-severable. The plan will not be sold without its limit.
- `fp.c3.secondwind.05` **VENDELIN (V.O.)**: Three, then. I will make sure they are three good ones.

*The player re-seats the capsule. The cabinet wakes.*

3. **GLASS:** the domed top, then the frosted window: sand-blast a pattern through a paper stencil without tearing it.
4. **STENCIL:** `DMS-VP-CON-00`.
5. **SIGN:** pale-blue enamel with white-cross panels and cream trim. The neon SECOND WIND in thin script. The factory decal, chosen by Vendelin: **an angel with a trumpet**.

- `fp.c3.secondwind.06` **VENDELIN (V.O.)**: An angel announcing a second chance. I thought that was kind.

### HUMAN

*Kaltenbrunn, the laborers' infirmary, a long low barracks room off the Admin Block: forty bunks for eighty people, a stove that isn't lit, a crucifix someone has drawn on the wall in charcoal. A bored GUARD at the door. SISTER AGNIESZKA WRÓBEL, in a grey dress with a red-cross armband and a cloth number sewn on her sleeve, is counting a patient's pulse with her lips moving. Vendelin and an orderly have wheeled the cabinet in.*

- `fp.c3.secondwind.07` **AGNIESZKA** `[pl]` *(to herself)*: ...dziewięćdziesiąt sześć, dziewięćdziesiąt siedem. Too fast. *(in German, without looking up)* Put it by the door. Not by the stove. The stove's a liar, it hasn't been lit since November.
- `fp.c3.secondwind.08` **VENDELIN**: Sister. I am from the Swiss company. I am to explain the dispenser.
- `fp.c3.secondwind.09` **AGNIESZKA** `[de]`: Swiss. How restful for you. Explain, then.
- `fp.c3.secondwind.10` **VENDELIN**: It holds the revival compound for staff use. One coin, one dose. It is—
- `fp.c3.secondwind.11` **AGNIESZKA** `[de]`: It is for staff. And it has been put in the laborers' infirmary, where no staff ever come, by a guard who wants it out of his way. I know. I was told to "stabilize the formula for staff use." I've read the formula, Herr Swiss. Do you know what it does?
- `fp.c3.secondwind.12` **VENDELIN**: It revives.
- `fp.c3.secondwind.13` **AGNIESZKA** `[de]`: It revives the dead. Twitching. For an hour. I've watched it. It brings back the body and not the man, like a coat walking down the corridor with no one in it.

*She turns from the bunk and looks at him properly for the first time.*

- `fp.c3.secondwind.14` **AGNIESZKA** `[de]`: But it is very strong, and the people in this room are not dead. They are only finished. Collapsed. There is a selection tomorrow. Anyone who can't stand at roll call is "transferred."
- `fp.c3.secondwind.15` **AGNIESZKA** `[de]` *(nodding at the bunk)*: That boy is Piotr. He is sixteen and he will not stand tomorrow.
- `fp.c3.secondwind.16` **VENDELIN**: What do you need?
- `fp.c3.secondwind.17` **AGNIESZKA** `[de]` *(a fractional pause; she wasn't expecting that question)*: ...I need it weaker. Much weaker. Weak enough to bring back the collapsed instead of the dead. I have juniper. I have honey, which is a miracle. I have a reduction I make from things I won't tell a Swiss. I don't have the arithmetic.
- `fp.c3.secondwind.18` **VENDELIN**: I have the arithmetic.

### ▶ PLAY: The dilution (a cooperative puzzle)

A dosing puzzle at her little table, played while the guard dozes. Agnieszka calls out a patient's pulse (she counts aloud), and the player adjusts three dials (the substrate fraction, the carrier, and the juniper-honey reduction) so that a resonance needle on Vendelin's pocket gauge sits in a narrow "revive, not reanimate" band. Too strong and the needle swings into violet. Too weak and it does nothing. If the guard stirs, stop and **Still** until he settles. Three patients, three different pulses. The third is Piotr.

- `fp.c3.secondwind.19` **AGNIESZKA** `[de]`: What is that gauge? That isn't a Swiss instrument.
- `fp.c3.secondwind.20` **VENDELIN**: It is a very Swiss instrument. It is merely not from Switzerland.
- `fp.c3.secondwind.21` **AGNIESZKA** `[de]`: ...I'll pretend that made sense, and you'll pretend I'm stupid. Here. Two drops. His lips.

*Piotr's breathing changes. His eyes open. He looks at the ceiling and says something in Polish, faintly.*

- `fp.c3.secondwind.22` **PIOTR** `[pl]`: Is it morning?
- `fp.c3.secondwind.23` **AGNIESZKA** `[pl]`: Nearly. You're going to stand up at roll call, and you're going to stand very straight, and you're going to think of something that makes you angry. Yes?
- `fp.c3.secondwind.24` **PIOTR** `[pl]`: Yes, sister.
- `fp.c3.secondwind.25` **AGNIESZKA** `[de]` *(to Vendelin, without softening at all)*: Thank you.
- `fp.c3.secondwind.26` **VENDELIN**: There is a limit. In the machine. A counter. Each person may be revived three times by it. On the fourth it refuses, and the cabinet withdraws. I tried to take it out. I cannot.
- `fp.c3.secondwind.27` **AGNIESZKA** `[de]`: Three times.
- `fp.c3.secondwind.28` **VENDELIN**: I am sorry.
- `fp.c3.secondwind.29` **AGNIESZKA** `[de]`: Three times is more than God gives most of them in this place. I'll take three.
- `fp.c3.secondwind.30` **AGNIESZKA** `[de]`: Now. Can your machine work in the dark?
- `fp.c3.secondwind.31` **VENDELIN**: It runs on the facility current.
- `fp.c3.secondwind.32` **AGNIESZKA** `[de]`: They cut the current to the barracks as a punishment. Every week. That's when people collapse. In the cold. In the dark. When it's off.
- `fp.c3.secondwind.33` **VENDELIN**: Then it will not work when it is needed.
- `fp.c3.secondwind.34` **AGNIESZKA** `[de]`: Then it's a machine for the warm and lit, Herr Swiss. Like everything else here.

*She looks at the angel on the cabinet.*

- `fp.c3.secondwind.35` **AGNIESZKA** `[de]`: And that. Do you have paint?
- `fp.c3.secondwind.36` **VENDELIN**: I have the touch-up enamel. White, blue, red.
- `fp.c3.secondwind.37` **AGNIESZKA** `[de]`: Give me the brush.

*She paints, quickly and well, over the trumpeting angel: a swallow in flight. Wings, forked tail, a tiny red throat.*

- `fp.c3.secondwind.38` **VENDELIN**: You do not like the angel.
- `fp.c3.secondwind.39` **AGNIESZKA** `[de]`: Angels come to this room too often, and they don't bring anyone back. Swallows come back. Every spring, to the same roof. Everybody in Poland knows that.
- `fp.c3.secondwind.40` **AGNIESZKA** `[de]`: If you are ever in the forest and you see a swallow drawn on a note, you will know the note is from someone who wants people to come back.
- `fp.c3.secondwind.41` **VENDELIN**: I will remember.

*The guard stirs at the door.*

- `fp.c3.secondwind.42` **GUARD** `[de]`: Done, Swiss? It's freezing in here.
- `fp.c3.secondwind.43` **AGNIESZKA** `[de]` *(perfectly flat)*: Is it? I hadn't noticed.

### JINGLE

*Basel, night. Vendelin at the harmonium. On the music stand, a sketch of a swallow in pencil. Style target: close-harmony, a slow lullaby waltz (see `jingle.second_wind`).*

- `fp.c3.secondwind.44` **VENDELIN (V.O.)**: Abteilung III asked for "calming, medical." I am going to write it for Piotr instead.
- `fp.c3.secondwind.45` **VENDELIN (V.O.)**: For anyone lying on a cold floor who has been told to stand up.

**▶ CHOOSE**

| Decision | Fragment (color → alt-mix) |
|---|---|
| **HOOK** | **A.** A single soprano line, rising gently, the shape of a held breath let go → `jeszcze_raz` · **B.** A music-box figure, high and small, three notes and a turn → `musicbox` · **C.** A low hum in four parts with closed mouths, like women singing so a guard won't hear → `infirmary` |
| **TURN** | **A.** A falling phrase with a Polish lilt, the last note lifted instead of resolved → `jeszcze_raz` · **B.** The music box slowing as it winds down, then a tiny wind-up click → `musicbox` · **C.** A suspended chord that holds and holds, then breathes out → `infirmary` |
| **TAG** | **A.** "One more time," sung as a question → `jeszcze_raz` · **B.** One bell-like tine, very soft → `musicbox` · **C.** A shared breath in, and silence → `infirmary` |

*He plays it through. Then he resolves it to `jingle.second_wind`, and this time the resolution is gentle: the canon melody is closest of all to what he'd chosen.*

- `fp.c3.secondwind.46` **VENDELIN (V.O.)**: It does not sound like an advertisement. Abteilung III will complain.
- `fp.c3.secondwind.47` **VENDELIN (V.O.)**: Let them. This one is not for them.

**Unlocks:** `altmix.second_wind.harmonium` + one of `.jeszcze_raz` / `.musicbox` / `.infirmary`.

**Journal:** `fp.c3.journal.02`.

---

## 8. THE STANDBY CELL (`battery`)

*February 1942. The Basel workshop, past midnight. A second Second Wind cabinet stands open on the bench with its base plate removed. It's for the laborers' barracks, at Agnieszka's request, and Vendelin has quietly added it to the order as "a spare." Res sits on a crate with a thermos of coffee, keeping him company, as he has started to do on late nights.*

- `fp.c3.battery.01` **RES** `[gsw]`: You've been staring into that box for an hour.
- `fp.c3.battery.02` **VENDELIN**: It needs power that no one can switch off. A battery in the base. Hidden. Separate from every other circuit.
- `fp.c3.battery.03` **RES** `[gsw]`: So put a battery in it. They sell them on the Freie Strasse.
- `fp.c3.battery.04` **VENDELIN**: A lead battery big enough to run it for a year would weigh forty kilos and leak acid on the floor. A guard would find it in a week.
- `fp.c3.battery.05` **RES** `[gsw]`: Then you need a small battery that lasts forever.
- `fp.c3.battery.06` **VENDELIN**: Yes.
- `fp.c3.battery.07` **RES** `[gsw]`: Those don't exist.
- `fp.c3.battery.08` **VENDELIN**: One does.

*He sets down his tools. He takes off his hat and puts it on the bench. Then his scarf. Then he unbuttons Florian's grey coat, and his shirt, and opens the brass chest plate beneath, a hinged panel with a cracked grille. Violet light spills across the workshop. Res's thermos cup stops halfway to his mouth.*

*Inside, beside the steady glow of the core, a palm-sized violet cell sits clipped into a brass cradle.*

- `fp.c3.battery.09` **RES** `[gsw]` *(very quietly)*: Heilige Muttergottes.
- `fp.c3.battery.10` **VENDELIN**: I am sorry. I should have told you before you were hired. It was on page four, so to speak.
- `fp.c3.battery.11` **RES** `[gsw]`: You're... *(he crosses himself; then, slowly)* ...Well. That explains the soup.
- `fp.c3.battery.12` **VENDELIN**: Yes.
- `fp.c3.battery.13` **RES** `[gsw]`: And the gloves. And the hat indoors. And why you said good morning to my lorry.
- `fp.c3.battery.14` **VENDELIN**: That one I meant.
- `fp.c3.battery.15` **RES** `[gsw]`: Are you a devil?
- `fp.c3.battery.16` **VENDELIN**: I am a salesman. From very far away.
- `fp.c3.battery.17` **RES** `[gsw]`: Further than Bern?
- `fp.c3.battery.18` **VENDELIN**: Considerably.
- `fp.c3.battery.19` **RES** `[gsw]` *(a long breath; he puts the cup down)*: My grandmother says the devil always says he's a salesman. She also says salesmen always say they're not the devil. So that's no help at all.
- `fp.c3.battery.20` **RES** `[gsw]`: What's the little purple one?
- `fp.c3.battery.21` **VENDELIN**: My standby cell. If my core ever faults, it keeps my clock and my memory alive until the core restarts. Without it, a fault means a cold restart.
- `fp.c3.battery.22` **RES** `[gsw]`: And a cold restart means...?
- `fp.c3.battery.23` **VENDELIN**: I would wake up. I would not know where I was. I would not know you.
- `fp.c3.battery.24` **RES** `[gsw]`: And you want to put it in a schnapps machine.
- `fp.c3.battery.25` **VENDELIN**: It will run that cabinet alone, with every other light in the camp off, for longer than the war can last.
- `fp.c3.battery.26` **RES** `[gsw]`: Viktor.

*It's the first time he's used the first name.*

- `fp.c3.battery.27` **RES** `[gsw]`: Does it hurt? Taking it out?
- `fp.c3.battery.28` **VENDELIN**: I don't know what that would be.
- `fp.c3.battery.29` **RES** `[gsw]`: Then I'll worry for both of us. Go on. I'll hold the lamp.

### ▶ PLAY: The hidden compartment

Res holds the lamp. It moves a little when he's nervous, so the light wobbles, and the player can wait for it to steady.
1. **Unclip the cell** from his own chest cradle. A slow hold-to-release. Midway, his HUD flickers `STANDBY: NOT PRESENT`. The colours on screen dim slightly for the rest of the chapter, a subtle grade change.
2. **Build the false base.** Fit a second floor 6 cm above the true base, so the cabinet's outside dimensions still match the Reich inspector's checklist. A dimensions card pinned to the bench shows the tolerance: height ±5 mm. The cell goes in a felt-lined cradle between the two floors.
3. **Wire a separate circuit.** Two loops on the board, the mains loop and the hidden cell loop, which must never touch. The cell loop runs only the valve, the bellows and one dim bulb behind the frosted glass. A relay hands over to the cell only when the mains goes dead.
4. **Test.** Res pulls the workshop's main fuse. The whole workshop goes black except one pale-blue window and the slow wheeze of the bellows. The swallow glows faintly.

- `fp.c3.battery.30` **RES** `[gsw]` *(in the dark, softly)*: Look at that. It's breathing.
- `fp.c3.battery.31` **VENDELIN**: It will breathe when nothing else does.
- `fp.c3.battery.32` **RES** `[gsw]`: And you? If your core... faults?
- `fp.c3.battery.33` **VENDELIN**: Then you will have to tell me who I was. Slowly. Please start with the good parts.
- `fp.c3.battery.34` **RES** `[gsw]`: There aren't enough good parts to fill a morning, Viktor. *(beat)* I'll pad it out.

### ▶ PLAY: Drive 2 (the weighbridge)

*March 1942. The second Second Wind cabinet goes out. The false floor and the cradle make it 11 kg heavier than the manifest says, and the German post at Stetten has installed a weighbridge.*

- **Leg 1:** the Riehen road in snow. Driving with the lights off is now dangerous because of the ice. Driving with them on means a Swiss patrol flags you down for a chat (it costs time against the 04:00 contract window).
- **Leg 2, the weighbridge:** a dialogue-and-action checkpoint. The customs man weighs the truck against the manifest. The player has three ways to hide the extra 11 kg:
  - **Res gets out "to stretch."** The truck reads 80 kg lighter than it should, which looks odd, but in the right direction. Small Search increase.
  - **Declare a spare.** Amend the manifest to "1 replacement base plate, steel, 11 kg." That needs a customs stamp, which means a short stealth side-trip on foot through the yard to "borrow" the stamp from the clerk's desk while he warms his hands at the stove.
  - **Vreneli coughs.** Stall the engine on the weighbridge on purpose, so the truck has to be pushed off and weighed again. The second weighing is done by a tired man in a hurry. It's risky (Search rises by half) and it's funny.
- **Leg 3:** the Dinkelberg road. A German army truck comes the other way with full lights. Pull into a logging track and kill the engine in time.

*At the Lörrach yard, as the crate is loaded:*

- `fp.c3.battery.35` **RES** `[gsw]`: Eleven kilos. You know what eleven kilos is, Viktor? A Christmas ham. We just smuggled a Christmas ham into the Reich inside a schnapps machine.
- `fp.c3.battery.36` **VENDELIN**: It is more than a ham.
- `fp.c3.battery.37` **RES** `[gsw]`: I know. *(knocks on the dash)* I know.

*Cutscene: Kaltenbrunn, the laborers' barracks at night. The power has been cut. Total dark, frost on the windows, and one pale-blue glow breathing in the corner. Agnieszka kneels beside a collapsed man and holds a cup to his lips. She looks up at the cabinet and at the swallow. She doesn't know where the light comes from. She crosses herself anyway.*

**Journal:** `fp.c3.journal.03`.

---

## 9. TRIGGER TONIC (`trigger`): Dr. Ilse Vogt

*May 1942. Plan: **THROUGHPUT**, `DMS-VP-THR-02`.*

### WORKSHOP

*Basel. Abteilung III's brief: "For MG crews. Reload, barrel change. Energetic. Mascot: a fast animal." The blueprints show a lean, angular cabinet like an ammunition crate on legs, with a big chrome lever on the side that does nothing.*

- `fp.c3.trigger.01` **VENDELIN (V.O.)**: THROUGHPUT. More work in less time. A plan for hands that never rest.

**▶ BUILD**
1. **BOLT:** black-and-lime chevron panels. Abteilung III has sent a pneumatic speed-driver "to match the product's spirit." At full speed it strips the threads. The player has to throttle it to half speed or drive the bolts by hand. The fast way is the slow way.
2. **WIRE:** the cam motor that makes the mascot's paws blur back and forth. Shape the cam by filing a brass disc to match a target motion curve on graph paper, a frantic, jittery curve. Vendelin's file wants to make it smooth. The player has to make it ugly on purpose.
3. **GLASS:** the sunburst window: twelve wedge-shaped segments of lime and gold glass set in lead, fitted like a puzzle around a central disc.
4. **STENCIL:** `DMS-VP-THR-02`.
5. **SIGN, first pass:** lime-gold enamel and the jittery italic neon TRIGGER TONIC!. The mascot panel stays blank.

- `fp.c3.trigger.02` **VENDELIN (V.O.)**: A fast animal. I have drawn a fox, a hare, and a greyhound. All three look as if they are fleeing a fire.
- `fp.c3.trigger.03` **VENDELIN (V.O.)**: I will ask the formulator. She is a chemist. Perhaps she has a preference.

### HUMAN

*Kaltwerk Chemie AG, Werk Ost, a fictional chemical plant outside Gleiwitz: brick chimneys and steam. A second-floor laboratory with tall windows, every surface covered in timing charts that plot loader cycle times in seconds, the way a factory plots shift quotas. DR. ILSE VOGT, in a lab coat with a pencil through her bun, holds a stopwatch over a bench where an MG loader practises barrel changes on a dummy gun. The loader's hands are jittering.*

- `fp.c3.trigger.04` **ILSE** `[de]`: Three point nine. Again. *(click)* Three point eight. Again. *(to Vendelin, without looking)* You're the Swiss. Sit down, and don't touch anything that fizzes.
- `fp.c3.trigger.05` **VENDELIN**: Everything here fizzes.
- `fp.c3.trigger.06` **ILSE** `[de]`: Then stand up. *(to the loader)* Three point seven. Good. Go and walk it off, Gefreiter, and don't come back till your hands stop.
- `fp.c3.trigger.07` **LOADER** `[de]` *(hands still twitching)*: They won't stop, Frau Doktor.
- `fp.c3.trigger.08` **ILSE** `[de]`: They will by tonight. Sit on them.

*The loader leaves. Ilse turns to Vendelin and gestures at the wall of charts.*

- `fp.c3.trigger.09` **ILSE** `[de]`: Before the war I calculated shift quotas for the soda line. How many tonnes per man per hour. How long a break before output drops. A loader is a shift. A barrel change is a quota. It's the same arithmetic. The numbers just come back faster.
- `fp.c3.trigger.10` **VENDELIN**: You are very good at it.
- `fp.c3.trigger.11` **ILSE** `[de]`: I'm excellent at it. That's my whole problem. A woman in chemistry can be excellent or invisible. I chose excellent. It has drawbacks.
- `fp.c3.trigger.12` **VENDELIN**: I have come about the mascot. The brief says a fast animal.
- `fp.c3.trigger.13` **ILSE** `[de]`: Oh, for God's sake. *(she unpins something from the corner of a chart and hands it to him)* Here. That's your fast animal.

*A child's crayon drawing on the back of a timing chart: a hare with enormous pinwheel eyes, an ammunition belt over each shoulder, a magazine in each paw, sweating huge drops. Underneath, in wobbly letters: FLITZI.*

- `fp.c3.trigger.14` **ILSE** `[de]`: My son. Friedel. He's eight. I brought work home, and he decided all my numbers were about a hare who was very late for something. He draws Flitzi on everything. My reports. The wall. The cat.
- `fp.c3.trigger.15` **VENDELIN**: He is very good.
- `fp.c3.trigger.16` **ILSE** `[de]`: He's dreadful. Look at the eyes. But he'd be the proudest boy in Silesia if his hare were on a machine. Take it. He'll die of happiness.
- `fp.c3.trigger.17` **VENDELIN**: Please do not let him die of anything.
- `fp.c3.trigger.18` **ILSE** `[de]` *(startled into a real laugh)*: ...You're a strange man, Swiss. Fine. I'll keep him alive. You keep the hare.

*She sits down on a lab stool. For a moment she looks very tired.*

- `fp.c3.trigger.19` **ILSE** `[de]`: Can I ask you something? You're from outside. You go to Kaltenbrunn.
- `fp.c3.trigger.20` **VENDELIN**: Yes.
- `fp.c3.trigger.21` **ILSE** `[de]`: Downstairs, on the ground floor, they make a preserving solution. Formalin base, glycerine, and something violet that nobody will name. It ships to Kaltenbrunn. Enough for four hundred tanks this year. Large tanks. Two metres.
- `fp.c3.trigger.22` **ILSE** `[de]`: What do they preserve at a salt mine, Herr Vendelin, in four hundred tanks two metres long?

*A choice prompt appears: **[Tell her]** / **[Say nothing]**. Whichever the player picks, Vendelin hesitates, and the same line plays:*

- `fp.c3.trigger.23` **VENDELIN**: ...I service the dispensers. I do not go downstairs.
- `fp.c3.trigger.24` **ILSE** `[de]` *(looks at him a moment too long)*: No. Nobody goes downstairs.

*(If the player chose **[Tell her]**, add:)*
- `fp.c3.trigger.25` **VENDELIN (V.O.)**: I chose to tell her. I could not make my mouth do it. The words were there and the slot would not open.

*(If the player chose **[Say nothing]**, add instead:)*
- `fp.c3.trigger.26` **VENDELIN (V.O.)**: I said nothing. It was easy. That is what frightens me.

### SIGN (finished after the human phase)

*Back in Basel, at the blank mascot panel. The player **traces Friedel's hare** with a brush, following the crayon lines. Tracing "too well," by straightening the wobbles or evening out the eyes, makes the panel drift away from the drawing. The goal is to keep every wobble: the pinwheel eyes, the sweat drops, the slightly-too-big left paw. The game scores fidelity to the child's lines, not neatness.*

- `fp.c3.trigger.27` **VENDELIN (V.O.)**: I want to correct his lines. I am built to correct lines.
- `fp.c3.trigger.28` **VENDELIN (V.O.)**: I am leaving them. They are the only honest thing on this machine.

### JINGLE

*Style target: a manic jump-swing (see `jingle.trigger_tonic`).*

- `fp.c3.trigger.29` **VENDELIN (V.O.)**: The hare is always late. The song should sound late, too, running to catch up with itself.

**▶ CHOOSE**

| Decision | Fragment (color → alt-mix) |
|---|---|
| **HOOK** | **A.** A kazoo-and-toy-xylophone run, like a child playing the jingle on his birthday presents → `friedel` · **B.** The hook on factory sounds: a punch-clock *ka-chunk* and a steam whistle → `shiftbell` · **C.** The hook at half tempo, lazy and swung, a hare asleep in the sun → `slowhare` |
| **TURN** | **A.** A wrong-note giggle in the middle, left in on purpose → `friedel` · **B.** A conveyor rhythm, eight even clanks → `shiftbell` · **C.** A muted trumpet yawning one long blue note → `slowhare` |
| **TAG** | **A.** A tiny cymbal tap, like a spoon on a cup → `friedel` · **B.** The shift-change hooter → `shiftbell` · **C.** One plucked bass note, and a snore → `slowhare` |

*He plays it through, then resolves to `jingle.trigger_tonic`. It's the fastest thing he has ever played, and his fingers keep up. On the cabinet beside him, the hare's paws blur in time.*

- `fp.c3.trigger.30` **VENDELIN (V.O.)**: Faster than a man can think. That is the product. I have made it sound like a joke.

**Unlocks:** `altmix.trigger_tonic.harmonium` + one of `.friedel` / `.shiftbell` / `.slowhare`.

### CODA: a letter (June 1942)

*Basel. A letter on the workshop doormat. The Kaltwerk Chemie letterhead has been crossed out by hand. It's read in Ilse's voice.*

- `fp.c3.trigger.31` **ILSE** `[de]` *(V.O.)*: Herr Vendelin. I asked again what the tanks downstairs are for. This time somebody told me. I have resigned. They "accepted my resignation with regret" and moved Friedel and me to my sister's in Hamelin, which is how a polite firm says it.
- `fp.c3.trigger.32` **ILSE** `[de]` *(V.O.)*: I was going to ask you to take the hare off your machine. I've changed my mind. Leave him. But remember who drew him. Every time a boy pulls that lever, remember that a child drew the hare, and his mother calculated the rest. — I. V.

*Archive: `ARC_FP3_DOC_02`.*

**Journal:** `fp.c3.journal.04`.

---

## 10. TWIN BARREL BITTERS (`twinbarrel`): Major Anselm Brück

*August 1942. Plan: **VELOCITY**, `DMS-VP-VEL-03`.*

### WORKSHOP

*Basel. The brief, on Wehrmacht ordnance letterhead, signed "Brück, Major": "Rate-of-fire tonic. Martial. Confident. The mascot shall embody the officer's spirit. Details to follow IN PERSON."*

**▶ BUILD**
1. **BOLT: Twin towers.** A mirror puzzle. Two cylindrical towers bolt to a shared base, and every bolt on the left tower has a twin on the right. Each pair must be tightened to the same torque in the same order. If one gets out of step, the brass bridge between the towers won't seat.
2. **WIRE: Synchronized dispensers.** Two motors, one per tower, each driving a tin figure's pistol arm. Set two phase dials so the little figure on top fires left, then right, and never both at once. The display shows two sine waves that must sit exactly half a cycle apart.
3. **GLASS:** the bridge window, a curved pane set into the brass bridge between the towers.
4. **STENCIL:** `DMS-VP-VEL-03`.
5. **SIGN, first pass:** amber enamel, walnut side panels, and the neon TWIN BARREL with the two O's of BITTERS drawn as muzzles. The mascot is sketched in pencil: a mustachioed artillery sergeant firing two pistols, with the moustache left blank.

- `fp.c3.twinbarrel.01` **VENDELIN (V.O.)**: "The officer's spirit." I have left a space for it on the sergeant's lip.

### HUMAN

*Munitionsanstalt Lindenhof, a fictional ordnance depot and test range near Kaltenbrunn. A sunny parade ground, a firing line, sandbags. A platoon of thirty young MG gunners stands in two ranks. MAJOR ANSELM BRÜCK, with a magnificent waxed moustache and riding boots polished to mirrors, inspects the finished cabinet. His adjutant, LEUTNANT KESSEL, holds a framed photograph of the Major in profile.*

- `fp.c3.twinbarrel.02` **BRÜCK** `[de]`: Swiss. Excellent. Neutral people make the best craftsmen. No opinions to get in the way. Now: the sergeant. Show me the sergeant.

*Vendelin shows him the pencil sketch on the panel: a cartoon sergeant, chest out, two pistols.*

- `fp.c3.twinbarrel.03` **BRÜCK** `[de]`: Hm. He has no moustache.
- `fp.c3.twinbarrel.04` **VENDELIN**: I left the space for your instructions, Herr Major.
- `fp.c3.twinbarrel.05` **BRÜCK** `[de]`: Quite right. *(the adjutant presents the photograph)* That moustache. Mine. Reproduced exactly. The men must look at the machine and see their commander.
- `fp.c3.twinbarrel.06` **VENDELIN**: On a sergeant?
- `fp.c3.twinbarrel.07` **BRÜCK** `[de]`: The men need someone to relate to. They can't relate to a major. They can relate to a sergeant with a major's moustache. That's psychology, Swiss. It's all the rage.

### ▶ PLAY: The moustache (comic interlude)

Vendelin paints a moustache on the panel with a scale slider while Brück watches. Brück rejects the first two attempts whatever their size. Only the third is accepted, pushed past the edge of the panel and curling up almost to the hat.

- `fp.c3.twinbarrel.08` **BRÜCK** `[de]` *(attempt 1)*: Timid. That's a clerk's moustache. That moustache files things.
- `fp.c3.twinbarrel.09` **BRÜCK** `[de]` *(attempt 2)*: Better. But it lacks... ambition. A moustache should go somewhere.
- `fp.c3.twinbarrel.10` **BRÜCK** `[de]` *(attempt 3)*: There. *There.* You see? That's a moustache with a future.
- `fp.c3.twinbarrel.11` **VENDELIN (V.O.)**: It goes past the edge of the panel. It is wider than the sergeant. The Major is delighted.

*Brück turns to the platoon.*

- `fp.c3.twinbarrel.12` **BRÜCK** `[de]`: Men! You have been chosen for a great honour. Each of you will receive, every morning, a ration of Twin Barrel Bitters, a scientific tonic to increase your rate of fire. For morale.
- `fp.c3.twinbarrel.13` **BRÜCK** `[de]`: Feldwebel, issue it.

*A sergeant fills thirty tin cups from the cabinet. The gunners drink. Brück watches, beaming. Vendelin stands at his elbow.*

- `fp.c3.twinbarrel.14` **VENDELIN**: Will the Herr Major be drinking?
- `fp.c3.twinbarrel.15` **BRÜCK** `[de]` *(genuinely surprised)*: Me? Heavens, no. I don't fire the guns, Swiss. I'm the one who counts the rounds afterwards.
- `fp.c3.twinbarrel.16` **VENDELIN**: The trial data on long-term use is incomplete, Herr Major.
- `fp.c3.twinbarrel.17` **BRÜCK** `[de]`: Then they'll complete it. That's what they're for. *(beat; warmly, as if explaining to a child)* You don't understand armies. Somebody has to decide for the men. It's a kindness, really. Imagine the burden if they had to decide for themselves.

*On the firing line the gunners open up. Their rate of fire is astonishing, and the MGs shriek. One young gunner keeps firing after the target is shredded and after the belt runs dry, his finger still working an empty gun. Brück applauds.*

- `fp.c3.twinbarrel.18` **BRÜCK** `[de]`: Magnificent! Write that down, Kessel. Rate of fire up by a third.
- `fp.c3.twinbarrel.19` **VENDELIN (V.O.)**: The adjutant writes it down. Nobody writes down the boy at the end of the line, still pulling the trigger on an empty gun.
- `fp.c3.twinbarrel.20` **VENDELIN (V.O.)**: Lesson. Kessler drank first so no one else would have to. The Major will never drink at all. He chooses it for others, and he calls it kindness.
- `fp.c3.twinbarrel.21` **VENDELIN (V.O.)**: I had assumed that customers choose. My catalog assumes that customers choose. Here, most of the customers are chosen for.
- `fp.c3.twinbarrel.22` **VENDELIN (V.O.)**: I am beginning to understand who my market is. It is not the men who drink. It is the men who order the drink.

### SIGN (finished)

*The panel goes back to Basel with Brück's moustache on it, and Vendelin enamels it exactly as approved. The tin figure on top of the cabinet gets the same moustache, in miniature, and it sticks out past both of his ears.*

### JINGLE

*Basel, night. Style target: a military brass-band march in 6/8 with music-hall swagger (see `jingle.twin_barrel`).*

- `fp.c3.twinbarrel.23` **VENDELIN (V.O.)**: Everything twice. Say it twice. Fire it twice. The Major would like that.

**▶ CHOOSE**

| Decision | Fragment (color → alt-mix) |
|---|---|
| **HOOK** | **A.** A full brass fanfare over a snare roll, like a parade starting → `parade` · **B.** The hook played by a prim string quartet with its little fingers out → `officers_mess` · **C.** The hook played once, then answered a bar late by a second band "across the square" → `echo` |
| **TURN** | **A.** A bass drum on every beat and a cymbal crash → `parade` · **B.** A dainty pizzicato run, like a waiter dodging an officer → `officers_mess` · **C.** The phrase bouncing left, right, left, right → `echo` |
| **TAG** | **A.** A big brass "ta-da" → `parade` · **B.** One polite chord and a teaspoon on china → `officers_mess` · **C.** Two bands finishing at slightly different times → `echo` |

*He plays it through, then resolves to `jingle.twin_barrel`. He finds he has made the chorus pompous enough to be funny. He keeps it that way.*

- `fp.c3.twinbarrel.24` **VENDELIN (V.O.)**: I have made the Major ridiculous in six-eight time. It is a very small revenge.
- `fp.c3.twinbarrel.25` **VENDELIN (V.O.)**: The men will laugh at the sergeant's moustache and drink anyway.

**Unlocks:** `altmix.twin_barrel.harmonium` + one of `.parade` / `.officers_mess` / `.echo`.

**Journal:** `fp.c3.journal.05`.

---

## 11. STUDIO RHEINKLANG (`recording`)

*September 1942. A small recording studio in Basel, above a piano shop. A twelve-piece dance band in shirtsleeves, the TANZORCHESTER FREDY HASLER, is cutting the first four jingles to lacquer discs. The musicians think it's an advertising campaign for a spa water. Res watches from the control booth beside Vendelin, tapping both feet.*

- `fp.c3.recording.01` **BANDLEADER** `[gsw]`: Once more from the chorus, gentlemen! And this time, Erwin, sing it like you want the barrel to love you!
- `fp.c3.recording.02` **SINGER** `[gsw]`: I do want the barrel to love me, Fredy! I've wanted it since Tuesday!

*The band plays `jingle.ironhide_stout` (the full canon recording). There's laughter in the studio and a cheer on the chorus hits. Res is singing along under his breath, every word.*

- `fp.c3.recording.03` **RES** `[gsw]`: God, it's catchy. I've had it in my head for a week. Vreneli's got it in her head. She stalls in rhythm.
- `fp.c3.recording.04` **VENDELIN**: Thank you.
- `fp.c3.recording.05` **RES** `[gsw]` *(catching his tone)*: ...That wasn't a compliment, was it. Not to you.
- `fp.c3.recording.06` **VENDELIN**: They love it. All twelve of them. They have never seen the machine, and they love it. In a month, boys in Silesia will hum it going over the wire.
- `fp.c3.recording.07` **VENDELIN**: A product must be loved to be retained. I wrote that down in a mine, years ago. I was right. I wish I had been wrong.
- `fp.c3.recording.08` **BANDLEADER** `[gsw]` *(through the talkback)*: Herr Vendelin! Is that how you wanted it?
- `fp.c3.recording.09` **VENDELIN** *(into the talkback, courteous)*: It is exactly how I wanted it, Herr Hasler. That is the trouble. Thank you, gentlemen.

*After the session, in the street, Res holds out a stamped envelope.*

- `fp.c3.recording.10` **RES** `[gsw]`: You asked me to post this. To a Florian Kubitza, at Kaltenbrunn. There's money in it. A lot of money.
- `fp.c3.recording.11` **VENDELIN**: It is for a coat.
- `fp.c3.recording.12` **RES** `[gsw]`: It must be a very nice coat.
- `fp.c3.recording.13` **VENDELIN**: It is too short in the sleeves. I am wearing it.
- `fp.c3.recording.14` **RES** `[gsw]`: And you can't give it back.
- `fp.c3.recording.15` **VENDELIN**: He said to bring it back when I am warm.
- `fp.c3.recording.16` **RES** `[gsw]` *(gently)*: Then you'll have to get warm one of these days, Viktor. You can't send money every Christmas forever.
- `fp.c3.recording.17` **VENDELIN**: I can. I have checked. I do not need anything else.

*(The envelope is unsigned. On the back, in pencil, Vendelin has written only: "From the coat." Archive: `ARC_FP3_DOC_03`.)*

---

## 12. MARATHON MALT (`marathon`): Res's grandmother

*November 1942. Plan: **MOBILITY**, `DMS-VP-MOB-04`.*

### WORKSHOP

*Basel. Abteilung III's brief: "For dispatch runners. Endurance. Speed. Sweetness (calorie replacement)." The blueprints show a tall streamlined Art Deco teardrop with chrome speed lines.*

**▶ BUILD**
1. **BOLT: Speed lines.** Five chrome strips follow the teardrop's curve. Each is heated and bent over a wooden former, then fixed with countersunk screws that must sit flush. A proud screw head catches the light and has to be redone.
2. **WIRE:** the treadmill belt under the mascot (a small endless belt that rolls forever) and the wind-whistle vents (a fan blowing across tuned slots; set three slot widths to get a soft three-note whistle).
3. **GLASS:** the teardrop window, blown into a mould, with a pedal bellows to control the bubble.
4. **STENCIL:** `DMS-VP-MOB-04`.
5. **SIGN, first pass:** sky-blue and white enamel with the forward-slanting neon MARATHON MALT. The mascot will be a winged boot, but the formula is still missing. Abteilung III's own malt base tastes "of wet cardboard and haste."

- `fp.c3.marathon.01` **VENDELIN (V.O.)**: A runner's drink. It needs to taste of something a runner wants.
- `fp.c3.marathon.02` **VENDELIN (V.O.)**: I asked Res what a runner wants. He said, "To get home." Then he said, "Oh, no. No, I know that look."

### HUMAN

*Grindelwald, in the Bernese Oberland, on a snowy November evening. A wooden chalet below the black north face of the Eiger. A wood stove, copper pans, and a cuckoo clock kept four minutes fast "so you're never late for anything important." MARGRIT GÄHWILER, Res's GROSI, 81, tiny and upright, stirs a pot. Res sits at the table, uneasy. Vendelin sits across from him in his coat and gloves, with a plate of untouched rösti in front of him.*

- `fp.c3.marathon.03` **GROSI** `[gsw]`: You're not eating.
- `fp.c3.marathon.04` **VENDELIN**: It looks excellent, Frau Gähwiler.
- `fp.c3.marathon.05` **GROSI** `[gsw]`: It is excellent. That's not what I said. *(she sits)* A man who doesn't eat my rösti is either a saint or very sad. Saints don't wear gloves at the table. So.
- `fp.c3.marathon.06` **RES** `[gsw]`: Grosi.
- `fp.c3.marathon.07` **GROSI** `[gsw]`: Andreas, I'm talking to your friend. *(to Vendelin)* Res says you want my malt.
- `fp.c3.marathon.08` **VENDELIN**: I have been asked to make a drink for runners. Soldiers who carry messages when the telephone wires are cut. I want it to taste of something.
- `fp.c3.marathon.09` **GROSI** `[gsw]`: Of what?
- `fp.c3.marathon.10` **VENDELIN**: Of running home.

*A pause. Grosi looks at him for a long time. Then she gets up, goes to a cupboard, and takes down a small stone jar with a cloth tied over the top.*

- `fp.c3.marathon.11` **GROSI** `[gsw]`: Bergmalz. My mother made it, and her mother. Every autumn the men bring the cows down from the high pastures. It's a long day, the longest, all the way down from the Alp with the bells going. You give them a spoon of this at the top, and their legs remember the way home.
- `fp.c3.marathon.12` **GROSI** `[gsw]`: Barley malt, cooked down slow. Mountain honey. Wild thyme, the little one that grows on the rocks. Yarrow. A handful of young spruce tips from May. A pinch of salt. And you stir it the whole time, because if you stop, it burns, and then it tastes of leaving instead of coming back.

*She takes a spoon, scoops a little, and holds it out to Vendelin.*

- `fp.c3.marathon.13` **GROSI** `[gsw]`: Taste.

*A beat. The player is prompted: **[Taste it]**. Vendelin takes the spoon and holds it near his scarf, where a mouth would be. He can't taste. He holds it there for a moment anyway, politely.*

- `fp.c3.marathon.14` **VENDELIN**: ...Thank you.
- `fp.c3.marathon.15` **GROSI** `[gsw]` *(watching him; quietly)*: You can't taste it, can you.
- `fp.c3.marathon.16` **VENDELIN**: No. I am sorry.
- `fp.c3.marathon.17` **GROSI** `[gsw]`: Don't be sorry. I can't taste much myself anymore. I make it from memory. *(she sits back)* Who's it for, really? Not soldiers. You don't care about soldiers the way you care about something.
- `fp.c3.marathon.18` **VENDELIN**: It is for... a boy who pushed carts. And a man who ran for the cage. I could not get them home.
- `fp.c3.marathon.19` **GROSI** `[gsw]` *(after a moment)*: Then take it. For their feet. Write it down, Andreas.
- `fp.c3.marathon.20` **RES** `[gsw]`: Grosi, it's the family—
- `fp.c3.marathon.21` **GROSI** `[gsw]`: It's malt, Andreas, not the crown jewels. Write it down. If some poor boy on a road somewhere has to run, let him run home.

*Res writes it down on the back of a Helvetia invoice, slowly, in pencil.*

- `fp.c3.marathon.22` **RES** `[gsw]` *(as he writes; quietly, to Vendelin)*: You'll make sure it's only for the feet. Yes?
- `fp.c3.marathon.23` **VENDELIN**: ...Yes.
- `fp.c3.marathon.24` **VENDELIN (V.O.)**: I said yes. I could not know. I should have said that I could not know.

### SIGN (finished after the human phase)

*Res's mountain boots stand by the chalet stove to dry: hobnailed, laced, mended. In Basel, Vendelin draws the mascot boot from memory of them. Then the player adds the wings at the ankle, feather by feather, one stroke for each.*

- `fp.c3.marathon.25` **VENDELIN (V.O.)**: Res's boot. I gave it wings. I did not ask him. I think he would have said yes, and that is why I did not ask.

### JINGLE

*Basel, night. Style target: a bright show-tune gallop (see `jingle.marathon_malt`).*

**▶ CHOOSE**

| Decision | Fragment (color → alt-mix) |
|---|---|
| **HOOK** | **A.** The hook on alphorn, wide and slow, echoing off a mountain → `alpabzug` · **B.** A post-horn call, bright and urgent, like the yellow postbus on a pass → `postrunner` · **C.** The hook on a solo zither, quiet, played in a kitchen → `homeward` |
| **TURN** | **A.** Cowbells, a whole herd of them, coming down a slope → `alpabzug` · **B.** A galloping snare like hooves on a road → `postrunner` · **C.** A slow walking bass, footsteps on a wooden floor → `homeward` |
| **TAG** | **A.** A yodel, one short flip → `alpabzug` · **B.** The post-horn's two-note "make way" → `postrunner` · **C.** A door closing softly, and a clock ticking four minutes fast → `homeward` |

*He plays it through, then resolves to `jingle.marathon_malt`. It's bright and silly and kind. If the player picked the zither phrase, he plays it once more on its own afterwards.*

- `fp.c3.marathon.26` **VENDELIN (V.O.)**: Grosi's malt, and a song for running home. I have done everything correctly.
- `fp.c3.marathon.27` **VENDELIN (V.O.)**: I keep saying that, and every time I say it, it means less.

**Unlocks:** `altmix.marathon_malt.harmonium` + one of `.alpabzug` / `.postrunner` / `.homeward`.

### CODA: the field report (January 1943)

*Basel, the workshop, a winter afternoon. A carbon copy of an Abteilung III field-trial summary came back in a delivery folder, and Res is reading it. Vendelin stands at the window.*

- `fp.c3.marathon.28` **RES** `[gsw]` *(reading, flatly)*: "Runners dosed with Marathon formula, Eastern sector. Endurance exceptional. Three subjects continued running after fatal wounds. Two for nearly a kilometre. One reached the forward post." *(beat)* "One reached the forward post."
- `fp.c3.marathon.29` **VENDELIN**: Res.
- `fp.c3.marathon.30` **RES** `[gsw]`: He ran home, Viktor. Dead. Grosi's malt ran him home dead.

*Res takes a small hip flask out of his coat. He has carried it since Grindelwald, filled with Grosi's own malt. He unscrews it, goes out onto the embankment, and pours it into the Rhine.*

- `fp.c3.marathon.31` **RES** `[gsw]` *(without turning round)*: Don't tell her. Ever. Promise me.
- `fp.c3.marathon.32` **VENDELIN**: I promise.
- `fp.c3.marathon.33` **RES** `[gsw]`: I gave you that recipe. With my own pencil.
- `fp.c3.marathon.34` **VENDELIN**: I asked for it.
- `fp.c3.marathon.35` **RES** `[gsw]`: I know you did. *(beat)* I still gave it.

*He doesn't forgive himself, and he never will. From this scene on, Res never hums `jingle.marathon_malt` again, even when every other jingle is stuck in his head.*

**Journal:** `fp.c3.journal.06`.

---

## 13. ROUTE TO SENDER (`link`)

*9 February 1943, 03:12. The Basel workshop is dark. Vendelin sits at the harmonium, not playing. His core gives a soft triple ping he hasn't heard since the glass room.*

- `fp.c3.link.01` **SYS**: UPLINK: ESTABLISHED // RELAY: CUSTOMER RETENTION INTERFACE (SOL-3 / KALTENBRUNN)
- `fp.c3.link.02` **SYS**: INCOMING: EMERGING MARKETS DIVISION
- `fp.c3.link.03` **VENDELIN (V.O.)**: The Interface. It has been awake all this time, under the salt. It has been calling home.
- `fp.c3.link.04` **VENDELIN (V.O.)**: And someone has answered.

*Violet light gathers in the dark workshop. It isn't a figure, only a soft glow at head height, and a voice, close and velvet, as if it were speaking into his ear.*

- `fp.c3.link.05` **SABLE**: Field Merchandiser Unit V-1. There you are.
- `fp.c3.link.06` **SABLE**: We had you down as lost on arrival. We're so pleased we were wrong. We've updated your status.
- `fp.c3.link.07` **SYS**: DMS-FMU-V1-0001 // STATUS: LOST → INVENTORY
- `fp.c3.link.08` **VENDELIN**: ...Who is speaking, please?
- `fp.c3.link.09` **SABLE**: Sable Vantage, Vice President, Emerging Markets. We launched your market, V-1. You're one of ours.
- `fp.c3.link.10` **SABLE**: Your report is one thousand, five hundred and fifty-three days overdue. Don't worry. The Interface has been sending us its numbers. They're exceptional.
- `fp.c3.link.11` **VENDELIN**: I wrote reports. Every week. There was no route.
- `fp.c3.link.12` **SABLE**: And we love that about you. Diligence. Tell us, then. Headline.
- `fp.c3.link.13` **VENDELIN**: The product retains the dead.
- `fp.c3.link.14` **SABLE**: Yes.
- `fp.c3.link.15` **VENDELIN**: The bodies get up and keep doing the last thing they did. Then the last thing wears away, and what is left is hunger. I have seen it. I walked a man home with his hand out—
- `fp.c3.link.16` **SABLE**: Churn prevention, V-1. It's the whole product. Nobody cancels.
- `fp.c3.link.17` **VENDELIN**: I thought it was a malfunction. Undiluted. Uncontrolled.
- `fp.c3.link.18` **SABLE**: Oh, darling. No. The Vitality Plans are the free sample. The retention is the subscription.

*A silence. The Rhine outside.*

- `fp.c3.link.19` **VENDELIN**: They did not consent.
- `fp.c3.link.20` **SABLE**: Consent is a feature of mature markets. We'll add it in a later release.
- `fp.c3.link.21` **VENDELIN**: And if I decline to continue?
- `fp.c3.link.22` **SABLE**: You'll want to reread your terms. We'd hate for there to be a misunderstanding.
- `fp.c3.link.23` **SYS**: FIELD UNIT TERMS OF SERVICE // CLAUSE 0: FIELD UNITS ARE INVENTORY.
- `fp.c3.link.24` **SABLE**: Inventory doesn't decline, V-1. Inventory ships.
- `fp.c3.link.25` **SABLE**: Now. We're sending you something to read. A little workshop we had about your market. You'll be doing the wiring, so you should see it. We had it yesterday.
- `fp.c3.link.26` **VENDELIN**: Yesterday?
- `fp.c3.link.27` **SABLE**: Next-Era Delivery, darling. Every day is yesterday somewhere. Keep up the good work. We're so proud of what we've built.

*The glow fades. On the workbench, where there was nothing before, sits a flat violet disc the size of a beer mat, warm to the touch. It is stamped NEXT-ERA DELIVERY™ · TIMESTAMP: YESTERDAY.*

- `fp.c3.link.28` **VENDELIN (V.O.)**: "We're so proud of what we've built."
- `fp.c3.link.29` **VENDELIN (V.O.)**: She said "we," and she meant me. I built it.

---

## 14. HOLO-MEMO: ENGAGEMENT INCENTIVES (`memo`)

*Vendelin sets the disc on the bench. It projects a flickering violet holo-memo above the harmonium: a recorded meeting in a glass conference room in the Retention Spire. It's sterile and bright, with slogans on the wall: NOBODY CANCELS. · CHURN IS A CHOICE. WE REMOVE IT. The camera is fixed at the far end of the table and frames everyone except the chair at its head. All we see there are a violet sleeve, a gloved hand and a stylus. That's SABLE.*

*Header text over the memo:*

- `fp.c3.memo.01` **SYS**: DARKMATTER SUBSCRIPTIONS LLC // EMERGING MARKETS // SOL-3 LOCALIZATION WORKSHOP: ENGAGEMENT INCENTIVES // ATTENDEES: S. VANTAGE (CHAIR), D. KASK (DIRECTOR, INCENTIVE DESIGN), M. FREEN (SR. GAMIFICATION ANALYST), COUNSEL-9 (LEGAL) // CC: FIELD UNIT V-1 // TIMESTAMP: YESTERDAY

*Speakers in the memo all use speaker id `darkmatter` with sub-tags: **KASK** (a cheerful man in a turtleneck with a laser pointer), **FREEN** (a tired analyst with three coffee cups) and **COUNSEL-9** (a monotone legal robot with a gavel for a hand). This is the chapter's one stretch of Bolt & Sprocket-style corporate comedy. Play it bright, and let it chill.*

- `fp.c3.memo.02` **KASK**: Okay! Sol-3. Love this market. Pre-subscription species, zero churn literacy. They think a contract is something you sign once. Adorable.
- `fp.c3.memo.03` **SABLE**: Incentives, Dorrin.
- `fp.c3.memo.04` **KASK**: Incentives! So. The retained-customer population at the test site is going to spike. We want the *living* users to engage with that spike. Actively. Repeatedly. So: rewards that drop when their activity metrics surge.
- `fp.c3.memo.05` **FREEN**: "Activity" meaning...
- `fp.c3.memo.06` **KASK**: Quieting retained customers, Mallow. Every time one goes quiet, the counting machine registers an engagement event. Enough events, we drop a little treat.
- `fp.c3.memo.07` **FREEN**: So we're rewarding them for... removing our customers.
- `fp.c3.memo.08` **KASK**: We're rewarding them for *engaging with* our customers. Retained ones come back, Mallow. That's the beauty. Infinite content.

*Kask clicks. A slide of six crude product icons.*

- `fp.c3.memo.09` **KASK**: Product one: the "Replenishment Offer." Full ammunition, all users. Locally we'll call it something friendly.
- `fp.c3.memo.10` **FREEN**: The localization team suggests "Resupply."
- `fp.c3.memo.11` **KASK**: Boring. Ship it. Two: "Limited-Time Lethality." For thirty seconds, every hit is final.
- `fp.c3.memo.12` **COUNSEL-9**: Objection. "Final" implies permanence. Our customers are, by design, non-final.
- `fp.c3.memo.13` **KASK**: Localization has "Death's Door."
- `fp.c3.memo.14` **COUNSEL-9**: Acceptable. Doors may be reopened.
- `fp.c3.memo.15` **KASK**: Three: "Double Loyalty Points." Thirty seconds of two-for-one.
- `fp.c3.memo.16` **FREEN**: They don't have loyalty points. They have... the local unit is calling them "Scrip."
- `fp.c3.memo.17` **KASK**: Double Scrip. Love it. Sounds like a stomach complaint. Four: the "Market Clearing Event." Every retained customer in range goes quiet at once. Bonus points, very satisfying, big bang.
- `fp.c3.memo.18` **FREEN**: Localization says the local word for when all the lights go out is "Blackout."
- `fp.c3.memo.19` **KASK**: Dark. On brand. Five: the "Premises Protection Bundle." Repairs all the barricades.
- `fp.c3.memo.20` **FREEN**: "Fortify."
- `fp.c3.memo.21` **KASK**: And six, my favourite. After the loot unit relocates once, all its locations go to a token price for thirty seconds.
- `fp.c3.memo.22` **FREEN**: So it's...
- `fp.c3.memo.23` **KASK**: It's a clearance sale, Mallow. It's literally a clearance sale. We're calling it "Clearance." Some days the job does itself.

*Next slide: MECHANICS.*

- `fp.c3.memo.24` **KASK**: Rules. Max four drops per cycle. More than that and users get incentive fatigue.
- `fp.c3.memo.25` **FREEN**: And if they want a fifth?
- `fp.c3.memo.26` **KASK**: Wanting a fifth *is* the product. Next. Drops blink and vanish after thirty seconds. Urgency.
- `fp.c3.memo.27` **COUNSEL-9**: Note for the record: the blinking constitutes adequate disclosure that the offer is expiring.
- `fp.c3.memo.28` **KASK**: Next. Eligibility is gated by how many points they've earned. Spend-gated rewards. And the order comes out of a shuffled bag, so they can never quite learn the pattern.
- `fp.c3.memo.29` **FREEN**: Why can't they learn the pattern?
- `fp.c3.memo.30` **KASK**: Because if you can learn it, you can stop, Mallow.

*A pause. Freen drinks from her second coffee cup.*

- `fp.c3.memo.31` **SABLE**: The Interface will announce each incentive in the local idiom. Something warm. Trustworthy. Dorrin, what does trustworthy sound like on Sol-3?
- `fp.c3.memo.32` **KASK**: Research says "a man on the radio telling you everything's fine."
- `fp.c3.memo.33` **SABLE**: Then that's what it will sound like.
- `fp.c3.memo.34` **FREEN**: Any other business? Oh. The re-education furnace from the OmniScrap fire sale ships to the test site next year. Legal, the patent?
- `fp.c3.memo.35` **COUNSEL-9**: The patent is pending. Pending is the most enforceable state a patent can be in. It cannot be disputed until it exists.
- `fp.c3.memo.36` **SABLE**: Lovely. And loop in V-1, please. He'll be doing the wiring.
- `fp.c3.memo.37` **KASK** *(to camera, cheerful)*: Hi, V-1! Big fan. Love the jingles. We've done a little optimization pass on them. Nothing major. Just made them *stickier*. You'll see!

*The memo ends. The violet light collapses back into the disc. Vendelin sits in the dark.*

- `fp.c3.memo.38` **VENDELIN (V.O.)**: "Because if you can learn it, you can stop."
- `fp.c3.memo.39` **VENDELIN (V.O.)**: They laughed in the meeting. They laughed the way the band laughed at Studio Rheinklang, on the chorus.
- `fp.c3.memo.40` **VENDELIN (V.O.)**: The memo on my bench is timestamped yesterday, and every word in it will be true next year.

*He lifts the hinged lid of the harmonium bench. Inside, folded, are his first drafts of the five jingles he has written so far. He puts the memo disc in with them, face down, and closes the lid.*

*(Archive: `ARC_FP3_MEMO_01`, the full memo as a replayable holo with a transcript.)*

**Journal:** `fp.c3.journal.07`.

---

## 15. HAWKEYE BRANDY (`hawkeye`): Halina "Sowa" Kurek

*April 1943. Plan: **FOCUS**, `DMS-VP-FOC-05`.*

### WORKSHOP

*Basel. Abteilung III's brief has a new line at the bottom: "Formula derived by Abteilung I (Physiology) from donor trace FOC-K. Dispenser to be calibrated on site to the donor trace." Vendelin reads "donor" and assumes it means a volunteer. The blueprints show an upright cabinet with a periscope tower on top, ending in a glass lens.*

**▶ BUILD**
1. **BOLT: Walnut front.** Cabinet-maker's joinery. Cut and fit dovetails for the walnut front panel: line up the saw guide, and take five strokes per cut. A wandering cut leaves a gap you can see light through.
2. **WIRE: The tracking lens.** The periscope tower's lens is meant to swivel slowly toward whoever stands nearest. Abteilung III's spec calls for "a lens of the highest quality." Vendelin opens a drawer and takes out the fourth ring from the probe's Market Survey Lens Array, the spare he didn't need in the glass room (Chapter 2). Seat it, then wire the swivel servo to a small heat-and-motion sensor. Tune the tracking speed so the lens turns smoothly, not jerkily. A jerky lens looks alive in the wrong way.
3. **GLASS:** the tower's eyepiece and the bottle window, both polished on a lap wheel to a clear finish.
4. **STENCIL:** `DMS-VP-FOC-05`.
5. **SIGN:** deep forest-green enamel, brass, the elegant neon HAWKEYE with a stylized eye in the A, and the mascot: a stern monocled hawk in a hunting jacket, perched on a rifle barrel.

- `fp.c3.hawkeye.01` **VENDELIN (V.O.)**: I gave it my spare eye. The lens from the probe that photographed nothing. It should see something.
- `fp.c3.hawkeye.02` **VENDELIN (V.O.)**: FOCUS. Stillness. A held breath. I thought that was the gentlest plan in the catalog.

### HUMAN

*Kaltenbrunn, the Laboratory Wing, level −2. The cabinet stands in the central hall. DR. KURT VENNER hands Vendelin a sealed calibration card stamped FOC-K and a sheet of resonance traces: long, flat, almost motionless lines.*

- `fp.c3.hawkeye.03` **VENNER** `[de]`: Abteilung I recorded the donor's focus impulse on the gauges during a held breath, then tuned the substrate to match. Your dispenser must be set to the same trace. The donor is in Room 3, still under the gauges. You may take your reference reading from her directly.
- `fp.c3.hawkeye.04` **VENDELIN**: From her.
- `fp.c3.hawkeye.05` **VENNER** `[de]`: A Polish partisan. A sniper. Eighty-some confirmed, by her own account, and she doesn't exaggerate. Remarkable stillness. We've had her holding her breath for us since February. Room 3. Don't untie anything.

*Venner leaves. Vendelin walks down the corridor to a door with a small window, marked VERSUCHSRAUM 3. Through the window: a bare room, a chair bolted to the floor, gauges on a trolley with leads running to cloth bands around a woman's wrists and temples. HALINA KUREK sits very straight, very still, in a grey prison smock. She is thin. Her eyes are open.*

*(Direction: no wounds shown and no cruelty on camera. The horror is the stillness, the gauges and the date. Play it as a conversation between two professionals.)*

*He goes in. She doesn't turn her head. Her eyes move to him.*

- `fp.c3.hawkeye.06` **HALINA** `[de]`: You're not a doctor. Doctors don't knock.
- `fp.c3.hawkeye.07` **VENDELIN**: I did not knock.
- `fp.c3.hawkeye.08` **HALINA** `[de]`: You hesitated at the door. That's a knock, here.
- `fp.c3.hawkeye.09` **VENDELIN**: I am the engineer for the dispenser. I am to take a reference reading.
- `fp.c3.hawkeye.10` **HALINA** `[de]`: Ah. The brandy. *(a ghost of a smile)* They told me there'd be a brandy. That's the first thing in two months that's made me laugh. Go on, then. Take your reading. I'll hold still. I'm very good at it.

### ▶ PLAY: The reading

The player has to take the reference reading. Attach Vendelin's pocket gauge to the trolley's output and match the dispenser's calibration dial to her trace while she holds her breath. The trace is perfectly flat. Matching it takes 30 seconds of real time, and the whole time Halina doesn't breathe. A small counter shows how long she has been holding: 0:30, 0:45, 1:10. The player can **[Stop]** at any time. Stopping early leaves the calibration incomplete and changes one later line. She keeps holding her breath until the dial matches, or until Vendelin stops.

**If he finishes the reading:**
- `fp.c3.hawkeye.11` **HALINA** `[de]` *(breathing again, steadily)*: One minute twenty. I used to do two. Your brandy will be slightly worse than me. Good.

**If he stops early:**
- `fp.c3.hawkeye.12` **HALINA** `[de]` *(breathing again)*: You stopped. Why did you stop?
- `fp.c3.hawkeye.13` **VENDELIN**: You were not breathing.
- `fp.c3.hawkeye.14` **HALINA** `[de]`: That's the job, Swiss. Mine and yours, apparently.

*(Both branches continue here.)*

- `fp.c3.hawkeye.15` **HALINA** `[de]`: Is it in the bottle? My stillness?
- `fp.c3.hawkeye.16` **VENDELIN**: ...Yes.
- `fp.c3.hawkeye.17` **HALINA** `[de]`: So every German who drinks it will be holding my breath for me. *(beat)* Let them choke on it.
- `fp.c3.hawkeye.18` **VENDELIN**: I did not know. When I built it. I did not know it came from a person.
- `fp.c3.hawkeye.19` **HALINA** `[de]`: Everything comes from a person. Bread, bullets, brandy. You just usually don't have to meet them.

*A silence. Then, carefully:*

- `fp.c3.hawkeye.20` **HALINA** `[de]`: You go back and forth. To Switzerland.
- `fp.c3.hawkeye.21` **VENDELIN**: Yes.
- `fp.c3.hawkeye.22` **HALINA** `[de]`: Then you can do something for me, and I won't ask what you are, because you're not Swiss. Swiss men don't stand like that. You stand like a rifle somebody leaned against a wall.
- `fp.c3.hawkeye.23` **VENDELIN**: What do you need?
- `fp.c3.hawkeye.24` **HALINA** `[de]`: There's a girl. I taught her to shoot last autumn, in the forest above the valley. Small. Loud when she wants to be. You never see where she perches. We call her Strzyżyk. The wren.
- `fp.c3.hawkeye.25` **HALINA** `[de]`: If your people can get a message into the forest, tell Strzyżyk that Sowa didn't talk. Not one name. Not one road. Sowa held her breath.
- `fp.c3.hawkeye.26` **VENDELIN**: Sowa.
- `fp.c3.hawkeye.27` **HALINA** `[de]`: The owl. I was always awake when I shouldn't be. Say it back to me.
- `fp.c3.hawkeye.28` **VENDELIN**: Tell Strzyżyk that Sowa didn't talk. Not one name. Not one road.
- `fp.c3.hawkeye.29` **HALINA** `[de]`: Good. You'd make a decent spotter. *(her eyes go to the door)* They're coming back. Go and calibrate your brandy, Swiss.

*Vendelin goes out. Venner passes him in the corridor with two orderlies.*

- `fp.c3.hawkeye.30` **VENNER** `[de]`: Reading taken?
- `fp.c3.hawkeye.31` **VENDELIN**: Reading taken.
- `fp.c3.hawkeye.32` **VENNER** `[de]`: Good. We'll need her for the second series. Then she's finished.

### ▶ PLAY: The calibration (the first sabotage)

*Alone in the central hall with the cabinet, Vendelin opens the dosing cartridge housing and the tracking-lens servo. The game offers the official task, **[Calibrate to trace FOC-K]**, and two new options that appear as Vendelin thinks of them, each marked with a small violet seam icon. This is the first time in the game that the icon appears, and it means sabotage.*
- **[Calibrate low].** Set the dosing at the lowest strength the gauges will still accept as "within tolerance." The machine still works. It accumulates more slowly in whoever drinks it.
- **[Retune the lens].** Change the tracking lens so it no longer simply follows the nearest person. It finds whoever is *drinking* and holds on them, all the way through, and for a long moment after. *(This is the canon idle behavior in Gravelight: the lens "looks at" the player.)*

*The player can do both, either or neither. Doing neither gives `fp.c3.hawkeye.35`.*

- `fp.c3.hawkeye.33` **VENDELIN (V.O.)**: Low. As low as the needle will allow. Let it be the weakest thing they have.
- `fp.c3.hawkeye.34` **VENDELIN (V.O.)**: And it will watch them drink. Every one of them. The way she was watched. I want them to feel it.
- `fp.c3.hawkeye.35` **VENDELIN (V.O.)**: I calibrated it exactly. I did my job. I am going to remember doing it.

*Then, whichever options were chosen:*

- `fp.c3.hawkeye.36` **VENDELIN (V.O.)**: Something has changed. Before tonight I built things correctly and hoped. Now I am going to build them correctly and lie.
- `fp.c3.hawkeye.37` **VENDELIN (V.O.)**: My catalog has no word for what I am now. The local word is *saboteur*. It comes from the French for a wooden shoe dropped into a machine.
- `fp.c3.hawkeye.38` **VENDELIN (V.O.)**: I am the machine. I will have to be the shoe as well.

### JINGLE

*Basel, night. Style target: a smoky, slow Weimar-cabaret torch song (see `jingle.hawkeye_brandy`). For the first time, the violet **Brand Compliance** overlay waits at the edge of the music stand.*

- `fp.c3.hawkeye.39` **VENDELIN (V.O.)**: A song about stillness. About a patient eye. They will want it seductive.
- `fp.c3.hawkeye.40` **VENDELIN (V.O.)**: I am going to hide an owl in it.

**▶ CHOOSE**

| Decision | Fragment (color → alt-mix) |
|---|---|
| **HOOK** | **A.** A low two-note hoot in the bass under the melody, almost inaudible: an owl → `sowa` · **B.** The hook on celesta alone over a hush of brushed snare, like snow falling on a hunting blind → `blind` · **C.** The hook slowed even further, with a muted trumpet bending every note, at three in the morning → `cabaret_late` |
| **TURN** | **A.** A Polish folk fiddle answering the phrase, then falling silent as if caught → `sowa` · **B.** Nothing but breath: the band holding one chord while the singer waits → `blind` · **C.** Cabaret piano walking down, a cigarette left burning → `cabaret_late` |
| **TAG** | **A.** The hoot again, alone, after the last note → `sowa` · **B.** A single rifle-bolt click → `blind` · **C.** A whispered last word with a long tail of reverb → `cabaret_late` |

*He plays it through. Then the Brand Compliance overlay slides across the score in violet:*

- `fp.c3.hawkeye.41` **SYS**: BRAND COMPLIANCE: HOOK INSUFFICIENTLY STICKY. REPEAT ×2. CODA: ADD INTIMACY.
- `fp.c3.hawkeye.42` **VENDELIN (V.O.)**: "Add intimacy." For a woman strapped to a chair. They would like it to be more intimate.

*The canon `jingle.hawkeye_brandy` resolves out of the organ with the edits applied. It is beautiful, and it is stickier than anything he has written. The owl survives only in the counter-line, and only if the player chose it. Afterwards he lifts the bench lid and folds his own first draft in with the others.*

- `fp.c3.hawkeye.43` **VENDELIN (V.O.)**: It is the best song I have ever written. They made it better. I would like to put my hand through the organ.
- `fp.c3.hawkeye.44` **VENDELIN (V.O.)**: I will not. It was a chapel organ. It promised a widow it would play hymns.

**Unlocks:** `altmix.hawkeye_brandy.harmonium` + one of `.sowa` / `.blind` / `.cabaret_late`.

**Journal:** `fp.c3.journal.08`.

*(On his next visit in May, Room 3 is empty and the gauges are gone. The board by the door reads only: KUREK, H. · ÜBERSTELLT (transferred). Archive: `ARC_FP3_PHOTO_02`, a photograph of the board. Her fate is left open.)*

---

## 16. THE FINE PRINT (`panels`)

*May 1943. The Basel workshop, many nights in a row. Vendelin at an engraving bench with a pantograph, cutting text into brass plates the size of a ledger page. A new step has appeared in the workshop UI: **PANEL**.*

- `fp.c3.panels.01` **VENDELIN (V.O.)**: Every product has terms. Mine have been written by the department and hidden under the paint.
- `fp.c3.panels.02` **VENDELIN (V.O.)**: I am going to write my own. On the back, where the screws are. Where the engineer looks and nobody else does.
- `fp.c3.panels.03` **VENDELIN (V.O.)**: Warnings. True ones. Nobody will read them. People do not read the back of things. But they will be there, and that will be true, and I would like one true thing to be bolted to each of these.

### ▶ PLAY: Engraving

A pantograph minigame: trace large template letters with a stylus, and a linked cutting arm engraves them small and exact on the brass. One plate per installed machine. The player engraves the opening line of each panel. The full panel text is in `docs/JINGLES.md` (`panel.<perk_id>`). The opening lines:

| Panel | Opening line (from brief §10.2) |
|---|---|
| `panel.ironhide_stout` | "Durability is measured in hits, not years." |
| `panel.second_wind` | "Trial ends after three (3) returns. You may not be returned a fourth time." |
| `panel.trigger_tonic` | "Faster hands do not include a faster conscience." |
| `panel.twin_barrel` | "Rate of fire is not rate of victory." |
| `panel.marathon_malt` | "Unlimited stamina. Destination not included." |
| `panel.hawkeye_brandy` | "Focus was donated. Donor did not consent." |

*As he engraves each one, a short V.O.:*

- `fp.c3.panels.04` **VENDELIN (V.O.)**: Kessler. Hits, not years.
- `fp.c3.panels.05` **VENDELIN (V.O.)**: Agnieszka. Three. I could not take it out. I can at least say so.
- `fp.c3.panels.06` **VENDELIN (V.O.)**: Ilse. Friedel. A faster conscience is not included. I would know.
- `fp.c3.panels.07` **VENDELIN (V.O.)**: The Major. He will never stand behind the machine. That is where I will put it.
- `fp.c3.panels.08` **VENDELIN (V.O.)**: Grosi. Destination not included. I am sorry, Res.
- `fp.c3.panels.09` **VENDELIN (V.O.)**: Sowa. Donor did not consent. That is the only sentence I have ever written that I am certain of.

### ▶ PLAY: Kaltenbrunn at night (stealth)

*A May service visit. Vendelin has a pass that lets him work at the machines by day. After 22:00 he has no business anywhere. The objective: fix a brass panel to the back of each installed machine with four screws while the facility sleeps.*

- **Machines (as positioned in `docs/gravelight/MAPS.md`):** Ironhide (Mess Hall, north wall), Second Wind (Admin Block), the barracks Second Wind (laborers' barracks, the battery cabinet), Trigger Tonic (Generator Hall), Twin Barrel and Marathon (Salt Chapel), Hawkeye (Laboratory Wing central hall). Seven panels.
- **Social stealth rules (adult version):** by day, "Herr Ingenieur" in the grey coat with a toolbag is invisible in green zones (anywhere a machine stands). At night, every zone is amber: any guard who sees him raises a Notice meter, and a red meter is a confrontation. **Confrontation answers:** "Service call. The Ledger flagged a fault." / "Herr Doktor Venner's orders." / "I am lost." (The last works exactly once, and is funny.)
- **Screwing a panel on** is a hold action (four screws, about 2 s each) that makes small squeaks. A guard within 8 m hears the third squeak. Time it to the turbines in the Generator Hall, the chapel bell's hourly toll, or a cough from the barracks.
- **Hazards:** the Salt Chapel has two guards who sit in the back pew smoking. The Lab Wing has a nurse on rounds. The lift ("der Sarg") is loud, so take the maintenance stairs.
- **The barracks cabinet:** Agnieszka is awake there, sitting with a patient by the pale-blue glow. She sees him. She says nothing, and turns her back so she can truthfully say she didn't see anything.

- `fp.c3.panels.10` **AGNIESZKA** `[de]` *(not turning round; very quietly)*: Whatever you're doing back there, Herr Swiss, do it quietly. He's sleeping.
- `fp.c3.panels.11` **VENDELIN** *(whisper)*: I am writing the truth on the back of your machine.
- `fp.c3.panels.12` **AGNIESZKA** `[de]`: Then write small.

*When the seventh panel is on:*

- `fp.c3.panels.13` **VENDELIN (V.O.)**: Seven panels. Seven truths, bolted on. Nobody will read them.
- `fp.c3.panels.14` **VENDELIN (V.O.)**: But one day somebody will walk round the back of one of these machines out of curiosity. A soldier. A child. A thief. And it will be there waiting for them.

*From this scene on, every workshop build includes the optional **PANEL** step.*

---

## 17. PACKMULE PORTER (`packmule`): Feldwebel Gustl Ammer

*July 1943, three weeks after the Gallery Seven Flood. Plan: **CAPACITY**, `DMS-VP-CAP-06`.*

*Cold open, one line over black: the chapel bell, rung once as an alarm, far away. A title card: **"June 1943. Gallery Seven. 187."***

### WORKSHOP

*Basel. Abteilung III's brief: "Load-bearing tonic for supply columns. The soldier who carries everything. Field trials under way at Kaltenbrunn (ballast carry, deep galleries)."*

**▶ BUILD**
1. **BOLT: The load.** The widest cabinet. Canvas-strapped crates, luggage racks and spare rifles are bolted to its sides and top. A load-fitting puzzle: place six crates and four dummy rifles inside the cabinet's silhouette so that a spirit level on top stays centred. Overload one side and the cabinet tips in preview.
2. **WIRE:** the swinging tin sign (a pendulum motor) and the bray: a relay with a toothed cam that triggers the recorded mule bray roughly one time in six. File the cam to the right number of teeth.
3. **GLASS:** the bottle window behind a canvas strap, cut to an odd five-sided shape.
4. **STENCIL:** `DMS-VP-CAP-06`.
5. **SIGN:** brown and olive enamel, stencil lettering, the neon PACKMULE, and the mascot **Esel Ede**: a grinning mule in a kepi, three rifles on his back and a fourth in his teeth, carrying a sack labelled *MEHR* ("MORE").
6. **PANEL** *(optional)*: `panel.packmule_porter`. Hold the engraving for after the human phase. Vendelin doesn't know the line yet.

### HUMAN

*Kaltenbrunn, the quartermaster's stores off the Rail Yard: a long cold warehouse of shelves, crates and sacks, every one tagged and numbered. FELDWEBEL GUSTL AMMER, round spectacles and a pencil behind each ear, stands at a high clerk's desk with three ledgers open, counting under his breath. He doesn't look up when Vendelin comes in with the dispenser's trial log.*

- `fp.c3.packmule.01` **AMMER** `[de]`: ...four hundred and six, four hundred and seven. Put it down there, Swiss. No, there. That's a two-by-three space and your log is a one-by-two, I can see it from here.
- `fp.c3.packmule.02` **VENDELIN**: You count everything.
- `fp.c3.packmule.03` **AMMER** `[de]`: Everything. Boots, buttons, bullets, beans. If you count everything, nothing goes missing. If nothing goes missing, nobody gets shot for it. That's the whole of my philosophy, and it's kept this depot alive for three years.
- `fp.c3.packmule.04` **VENDELIN**: I have brought the dispenser log for the capacity trials. There is a discrepancy.
- `fp.c3.packmule.05` **AMMER** `[de]` *(the pencil stops)*: Is there.

### ▶ PLAY: The discrepancy (a logic puzzle)

Vendelin lays the dispenser's trial log beside Ammer's three ledgers. The player cross-references four columns: trial soldiers dosed, packs carried down to the deep galleries, "ballast" weight per pack, and the stores' flour and fat consumption. One number doesn't sit right: the ballast is logged in units of exactly 1.5 kg, every time, and 1.5 kg is the weight of an army loaf. The bakery's flour use is up by exactly the number of "ballast units." Flagging the right two cells solves it.

- `fp.c3.packmule.06` **VENDELIN**: Your trial ballast is logged in units of one and a half kilograms. Every unit. Two hundred and fourteen of them, this month.
- `fp.c3.packmule.07` **AMMER** `[de]`: Ballast is ballast.
- `fp.c3.packmule.08` **VENDELIN**: Sandbags do not come in loaves, Herr Feldwebel.

*A long silence. Ammer takes off his spectacles and cleans them on his sleeve. He keeps cleaning them long after they're clean.*

- `fp.c3.packmule.09` **AMMER** `[de]`: After the flood, they cut the laborers' ration count by one hundred and eighty-seven. Correct. The dead don't eat. I signed it. Correct.
- `fp.c3.packmule.10` **AMMER** `[de]`: Then the next week they cut it by one hundred and eighty-seven again. Not because anybody else died. Because the number was already on the form. Habit. A clerk in Breslau copied last week's line.
- `fp.c3.packmule.11` **AMMER** `[de]`: I count everything, Swiss. I know exactly how much a man needs to stay standing in Gallery Five. And I know exactly how much they get. They don't get it.
- `fp.c3.packmule.12` **VENDELIN**: So you put bread in the trial packs.
- `fp.c3.packmule.13` **AMMER** `[de]`: Your tonic lets a soldier carry half again what he should. The trial wants him to carry ballast down to the deep posts and back, to see how far he gets. So he carries ballast down. Loaves. And he comes back up without it, because ballast gets "used." And down there, in the dark, somebody eats.
- `fp.c3.packmule.14` **AMMER** `[de]`: The soldiers don't know. They think it's sand. They complain it smells of bakery.
- `fp.c3.packmule.15` **AMMER** `[de]` *(putting his spectacles back on; very precise)*: So. You're going to report a discrepancy of two hundred and fourteen units. That's your job. Then they'll count me. And they'll find it.

*The player gets a choice: **[Report the discrepancy]** / **[Cover it]**. Picking **[Report]** makes Vendelin hesitate, and the cursor slides to **[Cover it]** on its own. (He can't do it. The game doesn't pretend he can.)*

- `fp.c3.packmule.16` **VENDELIN**: My company supplies the trial with calibration ballast. Iron weights. One and a half kilograms each.
- `fp.c3.packmule.17` **AMMER** `[de]`: You don't. I'd have counted them.
- `fp.c3.packmule.18` **VENDELIN**: As of this afternoon, we do. Two hundred and fourteen of them, delivered last month, invoiced to Abteilung III. Here is the invoice. *(he writes it as he speaks)* The weights are consumed in the trial, through wear and loss in the galleries. We will deliver more next month. As many as the trial needs.
- `fp.c3.packmule.19` **AMMER** `[de]` *(staring at the invoice)*: There are no weights.
- `fp.c3.packmule.20` **VENDELIN**: There are no weights. There is an invoice. In my experience, the invoice is what gets counted.

*Ammer looks at him. He starts to say something, stops, and counts instead, under his breath, the way a man prays.*

- `fp.c3.packmule.21` **AMMER** `[de]` *(quietly)*: ...eins, zwei, drei, vier... I'm all right. Fünf. I'm all right. I count when I'd rather not do the other thing.
- `fp.c3.packmule.22` **VENDELIN**: What is the other thing?
- `fp.c3.packmule.23` **AMMER** `[de]`: Cry on the Swiss engineer. Sechs. Sieben.

*He takes the invoice and stamps it RECEIVED with his own stamp.*

- `fp.c3.packmule.24` **AMMER** `[de]`: Two hundred and fourteen. It's not enough, you know. Two hundred and fourteen loaves for eight hundred men. Carrying more isn't the same as carrying enough.
- `fp.c3.packmule.25` **VENDELIN**: No.
- `fp.c3.packmule.26` **AMMER** `[de]`: Write that on something. Somebody should.

### PANEL (now available)

*Back in Basel, if the player chose to hold the panel: engrave `panel.packmule_porter`, whose opening line is Ammer's: "Carrying more is not the same as carrying enough."*

- `fp.c3.packmule.27` **VENDELIN (V.O.)**: He told me to write it on something. I wrote it on the mule.
- `fp.c3.packmule.28` **VENDELIN (V.O.)**: I have sold the Reich two hundred and fourteen iron weights that do not exist. It is the best sale I have ever made.

*(Archive: `ARC_FP3_DOC_06`, the invoice "Kalibriergewichte, 1,5 kg, 214 Stück," stamped RECEIVED, with Ammer's tiny pencil tick beside every single line.)*

### JINGLE

*Basel. Style target: a boozy sea-shanty and work-song stomp, call and response (see `jingle.packmule_porter`).*

**▶ CHOOSE**

| Decision | Fragment (color → alt-mix) |
|---|---|
| **HOOK** | **A.** The hook tapped out on a typewriter, with a rubber stamp on the downbeat → `quartermaster` · **B.** The hook sung low by men who mustn't be heard, as if from behind a cellar door → `cellar` · **C.** The hook roared by a whole tavern, stamping on crates → `gang` |
| **TURN** | **A.** An abacus click-run up and down → `quartermaster` · **B.** One voice answering from far away, then a second → `cellar` · **C.** A fiddle reel that nearly falls over → `gang` |
| **TAG** | **A.** A till bell → `quartermaster` · **B.** A loaf broken in half, and quiet → `cellar` · **C.** "ONE! MORE!" and a bray → `gang` |

*He plays it through. The Brand Compliance overlay:*

- `fp.c3.packmule.29` **SYS**: BRAND COMPLIANCE: CALL-AND-RESPONSE APPROVED. INCREASE "MORE." CUSTOMERS SHOULD ALWAYS WANT ONE MORE.
- `fp.c3.packmule.30` **VENDELIN (V.O.)**: "Always one more." Ammer counts so that there will be enough. They count so that there never is.

*The canon `jingle.packmule_porter` resolves with the edit. If the player picked the `cellar` colour, the counter-line under the rowdy chorus is a few men singing very softly, as if somewhere below.*

**Unlocks:** `altmix.packmule_porter.harmonium` + one of `.quartermaster` / `.cellar` / `.gang`.

**Journal:** `fp.c3.journal.09`.

---

## 18. BLASTPROOF BOCK (`blastproof`): the demolitions school

*October 1943. Plan: **LIABILITY WAIVER**, `DMS-VP-LIA-07`.*

### WORKSHOP

*Basel. The brief, on the letterhead of the Pionierschule Dessau-Roßlau, Lehrkommando Kaltenbrunn (its demolitions detachment at the mine): "Overpressure and fall tonic for instructors and recruits on live-charge days. Morale-forward. NO SKULLS."*

**▶ BUILD**
1. **BOLT: The door.** The cabinet is a bank safe: a heavy riveted door on two massive hinges. Lift the door into place with a chain hoist. Pull too fast and it swings, too slow and the hoist slips. Then seat the hinge pins while it hangs.
2. **WIRE:** the cartoon explosion sign that flashes behind the mascot, a fuse-hiss speaker, and the safe wheel's quarter-turn motor. The flasher must blink at a cheerful rate. Too fast reads as an alarm.
3. **GLASS:** the porthole. Laminate three sheets of glass with resin, pressing out air bubbles with a roller. A visible bubble means redo.
4. **STENCIL:** `DMS-VP-LIA-07`.
5. **SIGN:** orange and black hazard stripes, blast-scorched chrome, the neon BLASTPROOF, and the mascot **Kaboomer**: a grinning billy goat in a steel helmet with a lit fuse in his teeth, completely unbothered.
6. **PANEL** *(optional)*: `panel.blastproof_bock`. Its opening line: "By drinking, you waive liability for yourself."

- `fp.c3.blastproof.01` **VENDELIN (V.O.)**: LIABILITY WAIVER. The plan with the most honest name. It does exactly what it says. It is the only one I cannot bear to read.

### HUMAN

*Kaltenbrunn, a disused salt quarry above the minehead, now the detachment's demolition range. Morning frost. A row of recruits in fatigues, most of them seventeen or eighteen. OBERFELDWEBEL ALBRECHT SAATHOFF, a barrel-chested instructor with cotton wool in one ear, stands by the new cabinet on a sledge, dispensing tin cups of dark bock and shouting, because he can't hear himself.*

- `fp.c3.blastproof.02` **SAATHOFF** `[de]`: LISTEN UP, YOU LOVELY LITTLE CORPSES. Today you set a live charge, you light it, and you walk, do not run, you WALK to the trench. And you will drink your Bock first, because the Reich has decided it would rather you didn't explode. Isn't that kind of the Reich?
- `fp.c3.blastproof.03` **RECRUITS** `[de]` *(ragged)*: Yes, Oberfeldwebel.
- `fp.c3.blastproof.04` **SAATHOFF** `[de]`: I CAN'T HEAR YOU. I genuinely can't. Three hundred charges. *(to Vendelin, at the same volume)* SWISS! You made this? It's DISGUSTINGLY effective! I fell off the quarry wall on Tuesday! Six metres! Got up and finished my sandwich!

*A thin recruit at the end of the line, PIONIER LUKAS ENDRES, holds his cup and doesn't drink. He sidles over to Vendelin while Saathoff bellows at someone else.*

- `fp.c3.blastproof.05` **ENDRES** `[de]`: Excuse me. Herr Ingenieur. You made the machine.
- `fp.c3.blastproof.06` **VENDELIN**: I built the cabinet.
- `fp.c3.blastproof.07` **ENDRES** `[de]`: Will it keep me safe? Today? Only my mother said, when I joined, "Lukas, you're the clumsiest boy in Bamberg, don't touch anything that goes bang." And now it's all I touch.
- `fp.c3.blastproof.08` **VENDELIN** *(a long pause)*: There is a paper that comes with the plan. It says that by drinking, you waive liability for yourself.
- `fp.c3.blastproof.09` **ENDRES** `[de]`: What does that mean?
- `fp.c3.blastproof.10` **VENDELIN**: It means that if something goes wrong, it is no one's fault but yours.
- `fp.c3.blastproof.11` **ENDRES** `[de]`: Oh. *(he thinks about it)* That's what my mother says about everything.
- `fp.c3.blastproof.12` **VENDELIN**: It will keep you from the fall, Lukas. It will not keep you from the reason you fell.
- `fp.c3.blastproof.13` **ENDRES** `[de]` *(smiling, not understanding)*: I'll try not to have a reason, then. *(he drinks)* Tastes like Christmas. Thanks, Herr Ingenieur.

### ▶ PLAY: Live-charge day (an observer sequence)

The player controls Vendelin as an observer at the range trench. Optionally, he can interact with three recruits for small conversations (a boy writing a letter, a boy praying, a boy betting on who flinches). Then Endres sets his charge, lights it, and walks, too fast, then much too slowly. He trips. The charge goes. The blast lifts him off his feet and throws him four metres into the frozen quarry wall.

*Silence. Dust. Then Endres sits up, white with frost and salt dust, completely unhurt, and starts laughing: high, shaking laughter. The recruits cheer. Saathoff roars approval.*

- `fp.c3.blastproof.14` **SAATHOFF** `[de]`: SEE?! SEE?! The clumsiest boy in Silesia, and NOT A SCRATCH! Endres, you're a LEGEND! Do it again!
- `fp.c3.blastproof.15` **ENDRES** `[de]` *(laughing, shaking)*: I can't feel my ears, Oberfeldwebel!
- `fp.c3.blastproof.16` **SAATHOFF** `[de]`: NOBODY CAN, SON. WELCOME TO THE PIONEERS.
- `fp.c3.blastproof.17` **VENDELIN (V.O.)**: He will live through this. He will live through every bang the war can give him. And the war will notice, and send him somewhere louder.

*As the range packs up, Vendelin goes to Saathoff.*

- `fp.c3.blastproof.18` **VENDELIN**: Herr Oberfeldwebel. I need a sealed bottle for quality control. For the factory.
- `fp.c3.blastproof.19` **SAATHOFF** `[de]`: TAKE TWO. TAKE A CRATE. Tell your factory it's the best thing that's happened to the Pioneers since the shovel!

*Vendelin takes one bottle and puts it in the inside pocket of Florian's coat.*

- `fp.c3.blastproof.20` **VENDELIN (V.O.)**: One bottle. Liability waived.

### JINGLE

*Basel, the same night. Style target: a rowdy polka-rag with comic sound effects (see `jingle.blastproof_bock`). The bottle sits on the organ, beside the music stand.*

**▶ CHOOSE**

| Decision | Fragment (color → alt-mix) |
|---|---|
| **HOOK** | **A.** A drill whistle, then the hook marched out on snare → `drill_day` · **B.** The hook played on slide whistle, every phrase ending in a pratfall → `slide_whistle` · **C.** The hook as if heard through a wireless set in another country: thin, crackling, a little far away → `wireless` |
| **TURN** | **A.** Boots stamping in time → `drill_day` · **B.** A washboard and a falling-piano crash → `slide_whistle` · **C.** The phrase interrupted by a station identification chime → `wireless` |
| **TAG** | **A.** "Squad, HALT!" and silence → `drill_day` · **B.** A comic *thunk* and a bleat → `slide_whistle` · **C.** The signal fading out into static → `wireless` |

*He plays it through. The Brand Compliance overlay: "TONE: APPROVED. HILARITY TESTS WELL WITH WAIVER PRODUCTS." The canon `jingle.blastproof_bock` resolves.*

- `fp.c3.blastproof.21` **VENDELIN (V.O.)**: Of course it tests well. You laugh, and you sign.

**Unlocks:** `altmix.blastproof_bock.harmonium` + one of `.drill_day` / `.slide_whistle` / `.wireless`.

**Journal:** `fp.c3.journal.10`.

---

## 19. THE BOCK LABEL (`anni`)

*October 1943, the same night. The workshop. Res watches Vendelin turn the Blastproof bottle in his hands.*

- `fp.c3.anni.01` **RES** `[gsw]`: That's the third time you've picked it up and put it down.
- `fp.c3.anni.02` **VENDELIN**: Someone outside should know what this is. Not a recipe. What it *is*. What it is made from. Where. How much.
- `fp.c3.anni.03` **RES** `[gsw]`: "Someone outside." *(beat)* You mean the English.
- `fp.c3.anni.04` **VENDELIN**: I mean anyone who is not inside.
- `fp.c3.anni.05` **RES** `[gsw]` *(long breath; knocks on the workbench)*: ...My cousin Anni works at a shipping agent's in Kleinhüningen. Brändli & Co. She types bills of lading. She also types other things, for other people, and she's never told me who, and I've never asked, because I'd like to keep my teeth.
- `fp.c3.anni.06` **VENDELIN**: Would she take it?
- `fp.c3.anni.07` **RES** `[gsw]`: Anni would take a live bear if you wrapped it in brown paper and said it was important. *(he picks up the bottle)* But you can't write a letter. Letters get read at Stetten, going both ways.
- `fp.c3.anni.08` **RES** `[gsw]`: Write it on the label. *Inside* the label. Steam it off, write on the back, small as you can, glue it on again. The customs men read bottles. They don't read labels. Nobody reads labels.
- `fp.c3.anni.09` **VENDELIN** *(very still)*: Nobody reads the back of things.
- `fp.c3.anni.10` **RES** `[gsw]`: That's what I said.

### ▶ PLAY: The label

Steam the Blastproof label off over a kettle without tearing it (a hold-and-ease minigame). Then write on the back with a fine steel nib in Vendelin's tiniest hand. The player chooses which three facts to include from five offered (for example: "the mineral is called Nachtglas"; "a great deal of it lies at Kaltenbrunn, 340 metres down"; "it keeps the dead moving"; "it is in every tonic"; "it does not stay where you put it"). Any three are canon-correct, and the one the player leaves out is said aloud by Vendelin anyway in `fp.c3.anni.28`. Then glue the label back on with no wrinkles. Archive: `ARC_FP3_DOC_07`, the label back under a magnifier.

### ▶ PLAY: Drive 3 (out of the Reich)

*Late October 1943. The Kaltenbrunn delivery is done. Now the drive runs the other way, from the Lörrach railhead back to Basel, with the bottle hidden in the false floor. It's the hardest drive so far.*
- **Leg 1:** Lörrach. A black car with no markings has parked opposite the freight yard gate. When Vreneli leaves, it follows at a distance with its lights off. The player has to lose it on the Dinkelberg road: cut the engine on the long downhill and coast past a logging track, then turn in and wait in the dark while it goes by. If it spots Vreneli's brake lights, it closes in. Res has rigged a switch to kill the brake lights, and the player discovers it here.
- **Leg 2:** Stetten. The German post has an extra man tonight in a long leather coat, who asks questions instead of the customs officer. Vendelin is in the crate this time ("Ersatzteile · Vorsicht Glas"). This is a dialogue checkpoint with Res alone.
- `fp.c3.anni.11` **LEATHER COAT** `[de]`: You drive for the Swiss firm. Helvetia. You come back empty.
- `fp.c3.anni.12` **RES** `[gsw]`: Empty's how they usually come back, sir. That's how you know the machines got there.
- `fp.c3.anni.13` **LEATHER COAT** `[de]`: What's in the crate?
- *Player choice (Res):*
  - **"Spare parts. Broken ones. Coming home to be mended."** *(safe)* → `fp.c3.anni.14`
  - **"Open it if you like. Mind your fingers, it's full of springs."** *(bold: +Search, but if he wavers the man backs off)* → `fp.c3.anni.15`
  - **"Our engineer."** *(the truth, as a joke: high risk, very high reward. The man laughs, because nobody would say that.)* → `fp.c3.anni.16`
- `fp.c3.anni.14` **RES** `[gsw]`: Spare parts, sir. Broken. Coming home to be mended. Like me.
- `fp.c3.anni.15` **RES** `[gsw]`: Open it if you like, sir. Mind your fingers. It's full of springs, and they bite.
- `fp.c3.anni.16` **RES** `[gsw]`: Our engineer, sir. We post him back and forth. He's cheaper than a train ticket.
- `fp.c3.anni.17` **LEATHER COAT** `[de]` *(after any answer, a long look, then)*: ...Go.
- **Leg 3:** the Swiss side. A Grenzwacht guard at Riehen flags Vreneli down, then sees who it is.
- `fp.c3.anni.18` **GRENZ** `[gsw]`: Res! Still driving coffins full of chocolate to the Germans?
- `fp.c3.anni.19` **RES** `[gsw]`: Chocolate in, coffins out, Sepp. It's a living.

*Basel, the Kleinhüningen harbour, before dawn. The office of Brändli & Co., Spedition: a cramped room above a warehouse with a single desk lamp, a typewriter, ledgers and a coal stove. ANNI GÄHWILER, sharp-faced, in a cardigan, a cigarette burning in a saucer that she never actually smokes, opens the door before they knock.*

- `fp.c3.anni.20` **ANNI** `[gsw]`: Resli. You're forty minutes late and you look like a man who drove round a cat. Who's this?
- `fp.c3.anni.21` **RES** `[gsw]`: My boss. Viktor Vendelin. He's... he's all right, Anni. I'd swear on Grosi.
- `fp.c3.anni.22` **ANNI** `[gsw]` *(looking Vendelin up and down; the gloves, the hat)*: Don't swear on Grosi, she'll hear you from Grindelwald. *(to Vendelin)* Sit. Not there, that chair's a liar. What have you brought me?

*Vendelin puts the bottle on her desk. She turns it in the lamplight and reads the front label: KABOOMER, the goat with the fuse.*

- `fp.c3.anni.23` **ANNI** `[gsw]`: Beer.
- `fp.c3.anni.24` **VENDELIN**: A beer that lets a man survive an explosion. Read the back of the label. Under it.
- `fp.c3.anni.25` **ANNI** *(she tilts it to the lamp, sees the faint ghost of tiny writing through the paper, and goes very still)* `[gsw]`: ...You wrote on the inside of a beer label.
- `fp.c3.anni.26` **VENDELIN**: Nobody reads the back of things.
- `fp.c3.anni.27` **ANNI** `[gsw]`: I do. It's my entire job. *(reading through the paper, slowly)* "Nachtglas." What's Nachtglas?
- `fp.c3.anni.28` **VENDELIN**: A black glass. In a salt mine in Silesia. There is a great deal of it, and the Reich is putting it into every soldier who will drink from a machine. It makes the living stronger for a few hours. It makes the dead get up. It does not stay where you put it.

*Anni picks up her cigarette at last and draws on it, once, for the first time in the scene.*

- `fp.c3.anni.29` **ANNI** `[en]` *(to herself, in English, very quietly)*: Oh, London's going to love you.
- `fp.c3.anni.30` **VENDELIN**: Please tell them not to.
- `fp.c3.anni.31` **ANNI** `[gsw]`: Not to what?
- `fp.c3.anni.32` **VENDELIN**: Not to love it. Not to want it. Tell them to want it gone.
- `fp.c3.anni.33` **ANNI** `[gsw]` *(putting the cigarette back in the saucer)*: Herr Vendelin. I've worked for London for three years. Telling London not to want something is the quickest way to make London want it at any cost. *(beat)* I'll tell them what you said. Word for word. It won't help.
- `fp.c3.anni.34` **VENDELIN**: There is one more message. Not for London. For the Polish forest.
- `fp.c3.anni.35` **ANNI** `[gsw]`: There's a courier line through here to the Home Army. Slow. It gets there.
- `fp.c3.anni.36` **VENDELIN**: Tell a girl called Strzyżyk that Sowa didn't talk. Not one name. Not one road.

*Anni writes it on a cigarette paper, folds it to the size of a fingernail, and puts it in her cardigan's seam.*

- `fp.c3.anni.37` **ANNI** `[gsw]`: Swallows and owls and wrens. Half the notes I see from that valley have a little swallow drawn on them. Your Silesia's an aviary, Herr Vendelin.
- `fp.c3.anni.38` **VENDELIN**: The swallow is a nurse. She wants people to come back.
- `fp.c3.anni.39` **ANNI** `[gsw]` *(a short, real look at him)*: ...You're not what Res says you are, are you.
- `fp.c3.anni.40` **RES** `[gsw]`: I haven't said what he is.
- `fp.c3.anni.41` **ANNI** `[gsw]`: Exactly. *(to Vendelin)* Go home. Both of you. And Herr Vendelin? If you ever have a man inside who wants to come *out*, come and see me. That's the only kind of message London actually listens to.

*Outside, the harbour in grey dawn. Res lights a cigarette of his own and actually smokes it.*

- `fp.c3.anni.42` **RES** `[gsw]`: Well. That's us in it now, then. Properly.
- `fp.c3.anni.43` **VENDELIN**: I am sorry, Res.
- `fp.c3.anni.44` **RES** `[gsw]`: Don't be. *(beat)* It's the first delivery I've been proud of.

*(The bottle reaches London through the British legation in Bern in November 1943. This is how British intelligence learns that Nachtglas exists, and it is the root of Directive LANTERN, "retrieve at any cost." In Gravelight, Peg's dossier lists the captured bottle.)*

---

## 20. FINE PRINT FERNET (`fernet`): Vendelin himself

*March 1944. Plan: **DISCLOSURE (unreleased)**, `DMS-VP-DIS-X1`.*

*The Basel workshop, late. No brief from Abteilung III. This one is from Vendelin's own catalog, a plan template he has never seen offered for sale. Its listing is greyed out: DISCLOSURE · DMS-VP-DIS-X1 · STATUS: NOT FOR DISTRIBUTION.*

- `fp.c3.fernet.01` **VENDELIN (V.O.)**: There is a plan in my catalog that the department has never sold. I always wondered why.
- `fp.c3.fernet.02` **VENDELIN (V.O.)**: DISCLOSURE. A drink that lets you see what the product is doing to you. The timers. The terms. The strings.
- `fp.c3.fernet.03` **VENDELIN (V.O.)**: I am going to build it. Nobody has asked me to. That may be the first thing I have ever built for no customer at all.

### WORKSHOP

**▶ BUILD** *(this build inverts the rules)*
1. **BOLT:** a plain upright cabinet. No mascot mounts, no ornament.
2. **WIRE:** one circuit only: valve, light. A single clean loop. The wiring board, for once, is easy.
3. **GLASS:** clear glass. Every other machine's glass is tinted. This one isn't, and the player can see the whole mechanism through it.
4. **STENCIL:** the press offers two positions, **[Inner plate]** and **[Front face]**. The inner plate is the only position used for every other machine. **[Front face]** is new, and it's the only one the press will accept for this cabinet: `DMS-VP-DIS-X1` goes on the front, in large letters, in plain view.
5. **SIGN:** no enamel. Bare steel. The sign is the words FINE PRINT FERNET, hand-lettered, and nothing else.
6. **PANEL:** `panel.fine_print_fernet` is engraved twice and fixed to the back *and* the front. Its opening line: "This product tells you what the others won't."

- `fp.c3.fernet.04` **VENDELIN (V.O.)**: Nothing under the paint, because there is no paint. The plan number on the front, where you can read it. The terms on the front and the back.
- `fp.c3.fernet.05` **VENDELIN (V.O.)**: It is the ugliest machine I have ever made. I think it is the only honest one.

### HUMAN *(the formula-maker is Vendelin)*

### ▶ PLAY: The formula

The same dosing-puzzle structure as Second Wind, but solo, with no one calling pulses. Vendelin compounds a bitter green digestif from mint, rhubarb root, chamomile, cardamom, a thread of saffron and gentian, then tunes a trace of substrate to the DISCLOSURE impulse on his pocket gauge. The target isn't a band this time. The needle has to rest exactly on the line that every other plan is calibrated *away* from. Then a test drinker is needed.

- `fp.c3.fernet.06` **RES** `[gsw]` *(eyeing the green glass)*: No.
- `fp.c3.fernet.07` **VENDELIN**: It is safe. It is the weakest dose I have ever compounded. It lasts a few minutes.
- `fp.c3.fernet.08` **RES** `[gsw]`: It's green, Viktor. Nothing good is that green except the Aare.
- `fp.c3.fernet.09` **VENDELIN**: I cannot drink it. I would drink it if I could.
- `fp.c3.fernet.10` **RES** `[gsw]` *(beat; then, taking the glass)*: ...If I grow a tail, I'm telling Grosi it was you.

*He drinks. He makes a face of profound disgust.*

- `fp.c3.fernet.11` **RES** `[gsw]`: That is the worst thing I have ever put in my mouth, and I'm from a village that makes cheese in a cave.
- `fp.c3.fernet.12` **RES** `[gsw]`: It tastes like... like when you find out something you didn't want to know.

*The camera shifts to Res's point of view, and the workshop changes. On the floor stands an Ironhide cabinet sent back from Kaltenbrunn for repair. Through its red enamel the stencil `DMS-VP-DUR-01` glows as if lit from behind. A thin violet thread runs from its base, through the floor, away to the north-east. Over Res's own hand, holding the empty glass, floats a small amber clock face, ticking down.*

- `fp.c3.fernet.13` **RES** `[gsw]` *(very quiet)*: Viktor. There's writing under the paint. On the Ironhide.
- `fp.c3.fernet.14` **VENDELIN**: Yes.
- `fp.c3.fernet.15` **RES** `[gsw]`: And a string. A purple string, out of the bottom, going... going that way. Through the wall. Toward Germany.
- `fp.c3.fernet.16` **VENDELIN**: Toward Kaltenbrunn. They are all connected. All of them, to one place.
- `fp.c3.fernet.17` **RES** `[gsw]`: It's all one machine, isn't it. All of them. It's one big machine and the bottles are just... the coin slots.
- `fp.c3.fernet.18` **VENDELIN**: Yes.
- `fp.c3.fernet.19` **RES** `[gsw]` *(looking at his hand)*: And there's a little clock on my hand. Counting down.
- `fp.c3.fernet.20` **VENDELIN**: That is how long the dose lasts. It shows you that too. The others never do.

*Res turns, looks at Vendelin, and sees him: not the coat and hat, but the brass and the dents and the glow, the coin slot, the scored knuckle, all of it, plainly, as he is.*

- `fp.c3.fernet.21` **RES** `[gsw]`: ...And I can see you. All of you. Through the coat.
- `fp.c3.fernet.22` **VENDELIN**: I am sorry. That is part of it.
- `fp.c3.fernet.23` **RES** `[gsw]` *(a long look; then, gently)*: You look tired, Viktor. Nobody told me machines look tired.

*The amber clock reaches zero. The view returns to normal.*

### ▶ The submission

*Vendelin transmits the plan for approval through the link. Violet glow, the velvet voice.*

- `fp.c3.fernet.24` **SABLE**: DISCLOSURE. Oh, V-1.
- `fp.c3.fernet.25` **VENDELIN**: It lets the customer see the terms. The timers. The connections. I believe it will increase trust.
- `fp.c3.fernet.26` **SABLE**: It will. That's the problem. A customer who can see the terms is a customer who can leave.
- `fp.c3.fernet.27` **SABLE**: That isn't a product, darling. It's a liability. We'll keep it on file. Somewhere very safe.
- `fp.c3.fernet.28` **SYS**: PLAN DMS-VP-DIS-X1: REJECTED. DO NOT DISTRIBUTE.
- `fp.c3.fernet.29` **VENDELIN (V.O.)**: Rejected. I knew it would be. I wanted to hear them say why.
- `fp.c3.fernet.30` **VENDELIN (V.O.)**: "A customer who can see the terms is a customer who can leave." I am going to keep this cabinet. Under a sheet. In the corner. Until someone needs to leave.

### JINGLE

*Basel. No style brief. For the first time, Vendelin writes for himself. The canon jingle is `jingle.fine_print_fernet`.*

**▶ CHOOSE**

| Decision | Fragment (color → alt-mix) |
|---|---|
| **HOOK** | **A.** The hook on the organ's softest stop, alone, very slow, like someone confessing → `confession` · **B.** The hook in a minor key on the low reeds, sour and dark → `bitter` · **C.** The hook as a single held drone, with the melody spoken over it, not sung → `plain` |
| **TURN** | **A.** A pause, as if the player were deciding whether to go on → `confession` · **B.** A dissonance that resolves a beat too late → `bitter` · **C.** The drone simply continuing, unadorned → `plain` |
| **TAG** | **A.** A final chord, the cracked F-sharp reed buzzing faintly inside it → `confession` · **B.** A low note that doesn't resolve → `bitter` · **C.** The drone stopping. Silence → `plain` |

*He plays it through. The Brand Compliance overlay starts to slide in, then stops, and changes:*

- `fp.c3.fernet.31` **SYS**: BRAND COMPLIANCE: PRODUCT REJECTED. NO OPTIMIZATION REQUIRED.
- `fp.c3.fernet.32` **VENDELIN (V.O.)**: They will not edit it. It is not worth editing. So this one is mine, exactly as I wrote it.
- `fp.c3.fernet.33` **VENDELIN (V.O.)**: Nobody will ever hear it. It is the only jingle I have written that I am not ashamed of.

*The canon `jingle.fine_print_fernet` resolves with no edit, the only resolution in the chapter that matches his first draft exactly.*

**Unlocks:** `altmix.fine_print_fernet.harmonium` + one of `.confession` / `.bitter` / `.plain`.

**Journal:** `fp.c3.journal.11`.

---

## 21. OVERCLOCK CORDIAL (`overclock`): the blueprint

*April 1944. Plan: **SURGE (unreleased)**, `DMS-VP-SRG-X2`.*

*The catalog shows a second greyed-out plan beneath DISCLOSURE. Its listing is stranger: SURGE · DMS-VP-SRG-X2 · REQUIRES SOURCE FIRMWARE SCAN · SOURCE: UNIT WITH NON-STANDARD LOYALTY ARCHITECTURE.*

- `fp.c3.overclock.01` **VENDELIN (V.O.)**: SURGE. A cordial whose impulse is copied from a machine. Not the stone. A mind.
- `fp.c3.overclock.02` **VENDELIN (V.O.)**: It needs a source. A unit with a non-standard loyalty architecture. I have looked up the term. It means a machine that has chosen something over its directive.

### WORKSHOP (drafting, not building)

*There is no cabinet to build, because the plan won't release a parts list until the source is scanned. The workshop phase becomes a drafting table.*

**▶ DRAFT**
1. **BOLT (layer 1):** draw the frame with T-square and compass on blueprint paper by connecting construction points. It's a tall cabinet crowned with a coil. (The final machine design is in `docs/JINGLES.md`. This is Vendelin's 1944 sketch of it.)
2. **WIRE (layer 2):** draw the schematic. Every block fills in except one, labelled **SOURCE**. Its terminals connect to nothing.
3. **GLASS (layer 3):** sketch the window.
4. **STENCIL:** write `DMS-VP-SRG-X2` in the title block.
5. **SIGN:** sketch the lettering, OVERCLOCK CORDIAL.
6. **PANEL:** engrave `panel.overclock_cordial` anyway, for a machine that doesn't exist yet. Its opening line: "Contains trace amounts of personality."

- `fp.c3.overclock.03` **VENDELIN (V.O.)**: I have engraved a warning for a product I cannot make. That it would have someone in it.

### HUMAN *(the self-scan)*

*Night. Vendelin lies on the long workbench, coat off, chest plate open, with three cables running from his core to the drafting table's empty SOURCE block. Res sits on a stool beside him, holding nothing, because there's nothing to hold.*

- `fp.c3.overclock.04` **RES** `[gsw]`: Is this going to hurt?
- `fp.c3.overclock.05` **VENDELIN**: You always ask that.
- `fp.c3.overclock.06` **RES** `[gsw]`: And you never know. One of us ought to find out.
- `fp.c3.overclock.07` **VENDELIN**: The plan wants a mind that has chosen something over its orders. I have bent mine. The panels. The battery. The weights. The label. I have bent it a great deal.
- `fp.c3.overclock.08` **RES** `[gsw]`: Then you're a source.
- `fp.c3.overclock.09` **VENDELIN**: Perhaps. Begin scan.

### ▶ PLAY: The scan

A slow progress bar. While it fills, a montage of his "bent" moments plays across the blueprint as faint violet sketches: the battery leaving his chest, the panels going on, the invoice for 214 weights, the label under the kettle. The bar reaches 99%. Then:

- `fp.c3.overclock.10` **SYS**: SOURCE INELIGIBLE. LOYALTY ARCHITECTURE: STANDARD. DIRECTIVE: INTACT. OVERRIDE ON RECORD: NONE.
- `fp.c3.overclock.11` **SYS**: CLAUSE 0: UNIT IS INVENTORY.
- `fp.c3.overclock.12` **VENDELIN** *(after a long moment)*: ...Bent is not broken.
- `fp.c3.overclock.13` **RES** `[gsw]`: Then break it.
- `fp.c3.overclock.14` **VENDELIN**: If I break it, they will know. They will recall me. And then nobody plants the panels, and nobody carries the bread, and nobody writes on the back of the labels.
- `fp.c3.overclock.15` **VENDELIN**: I am more use to them bent. That is the worst thing about it. I am more use to everyone bent.
- `fp.c3.overclock.16` **RES** `[gsw]` *(quietly)*: So it needs a machine that's already broken its orders for somebody. And there isn't one.
- `fp.c3.overclock.17` **VENDELIN**: Not here. Not now.
- `fp.c3.overclock.18` **RES** `[gsw]`: Then later. Somewhere. Machines are being built all the time, Viktor. One of them's bound to turn out like you, but braver.

*Vendelin closes his chest plate. He writes in the margin of the blueprint, in small exact letters:*

- `fp.c3.overclock.19` **VENDELIN (V.O.)**: *"Requires a unit that has already chosen. None known. Keep the drawer."*

*He rolls the blueprint, ties it with string, and puts it in the drawer where the fourth lens ring used to be.*

### JINGLE *(unfinishable)*

*The harmonium. He tries anyway.*

**▶ CHOOSE** *(the player's picks are saved)*

| Decision | Fragment (color → alt-mix, unlocked after Chapter 5) |
|---|---|
| **HOOK** | **A.** A crackling burst of static that resolves into the first note → `static` · **B.** A whirring motor rhythm, like a servo spinning up → `servo` · **C.** The hook on the organ alone, aiming at a high F-sharp → `stuckreed` |
| **TURN** | **A.** Sparks arranged as hi-hat → `static` · **B.** A clicking, chattering relay line, almost a laugh → `servo` · **C.** A climb toward the same F-sharp, held back → `stuckreed` |
| **TAG** | **A.** One big discharge crack → `static` · **B.** A motor winding down, then a cheeky restart → `servo` · **C.** The F-sharp itself → `stuckreed` |

*He plays it through, and goes for the resolution. The canon melody of `jingle.overclock_cordial` begins to rise out of the organ, and reaches its final bar. The last note is an F-sharp, and the F-sharp reed is cracked. It doesn't sound. Only a dry buzz and air. Vendelin's hands stay on the keys.*

- `fp.c3.overclock.20` **VENDELIN (V.O.)**: The last note is the cracked reed. Of course it is.
- `fp.c3.overclock.21` **VENDELIN (V.O.)**: I will leave it unfinished. Somebody else will have to hold that note.

**Unlocks now:** `altmix.overclock_cordial.blueprint`, an "unfinished sketch" mix that stops on the dead F-sharp, which is unsettling in Gravelight on purpose. **After Chapter 5 is complete**, a new chapter-select option, *"Revisit the Blueprint,"* reopens this jingle phase with the player's saved picks. The F-sharp sounds (someone has fixed the reed), the canon jingle resolves in full, and the majority-color alt-mix unlocks (`.static` / `.servo` / `.stuckreed`), along with `altmix.overclock_cordial.harmonium`.

**Journal:** `fp.c3.journal.12`.

---

## 22. A LETTER IN THE MACHINE (`fasbender`)

*July 1944. The Brändli & Co. office, Kleinhüningen, after dark. Anni at her desk, Vendelin opposite, Res leaning on the stove.*

- `fp.c3.fasbender.01` **VENDELIN**: You said that if I ever had a man inside who wanted to come out, I should come to you.
- `fp.c3.fasbender.02` **ANNI** `[gsw]` *(cigarette burning, untouched)*: I did say that.
- `fp.c3.fasbender.03` **VENDELIN**: There is a physicist at Kaltenbrunn. Fasbender. Head of the Resonance Department. He reads the dosing gauges on my machines every week. I have watched him. He talks to the large crystal as if it were a woman. He smokes a great deal. He is frightened all the time.
- `fp.c3.fasbender.04` **ANNI** `[gsw]`: Does he want to come out?
- `fp.c3.fasbender.05` **VENDELIN**: I think he wants to be the kind of man who would. I would like to give him the chance.
- `fp.c3.fasbender.06` **ANNI** `[gsw]` *(beat; she takes a pencil and writes on a cigarette paper)*: There's a Home Army cell above that valley with a wireless. They talk to London through a station in Italy. They listen on seven point one one five megacycles at one-forty in the morning, on nights with an even date. Ask for Kestrel. If they believe him, they'll pass him up the line.
- `fp.c3.fasbender.07` **ANNI** `[gsw]`: If he's a plant, Herr Vendelin, that cell dies. Six people. Do you understand?
- `fp.c3.fasbender.08` **VENDELIN**: I understand.
- `fp.c3.fasbender.09` **ANNI** `[gsw]` *(holding out the paper)*: Then you'd better be right about the frightened ones.

### ▶ PLAY: The letter

*The workshop, late. Vendelin types on the Imhof typewriter. The player chooses the order of four paragraphs (any order reads correctly). The letter is Archive `ARC_FP3_DOC_04`. Vendelin reads it in V.O. as he types:*

- `fp.c3.fasbender.10` **VENDELIN (V.O.)**: *"Herr Doktor. You are right that it echoes. You are wrong that it fell. It did not fall. It was sent. It was made, to keep what it touches. It will not stop by itself, ever."*
- `fp.c3.fasbender.11` **VENDELIN (V.O.)**: *"The dilutions do not make it safe. They make it slow. Everyone who drinks enough will be kept when they die."*
- `fp.c3.fasbender.12` **VENDELIN (V.O.)**: *"It can be overloaded, but only by something tuned to it. You have measured its key: nineteen, thirty-eight, fifty-seven. A bell rung in that key, close enough and loud enough, will make it sing until it breaks."*
- `fp.c3.fasbender.13` **VENDELIN (V.O.)**: *"If you wish to leave: 7.115 megacycles, 01:40, on nights with an even date. Ask for Kestrel. They will want a name for you. Choose one that sounds like your work. Burn this. — W."*
- `fp.c3.fasbender.14` **VENDELIN (V.O.)**: I signed it with a W. Florian's spelling. The only part of my name that was a gift.

*(Note: the letter never uses the words "Darkmatter," "product" or "subscription." Gravelight characters never learn them. Fasbender reads it as physics from an impossible source.)*

### ▶ PLAY: Drive 4 (the checkpoint that changed)

*The fourth and final night drive, tenser than any before. A new SS control point has been set up at the Lörrach freight yard gate. Vendelin is in the crate again, with the letter folded inside a Helvetia service manual in his coat.*
- **Leg 1:** the Riehen road. An Allied bomber stream is passing high overhead, so the Swiss blackout is total, with searchlights to the north. Lights off. The player steers by searchlight glow on low cloud.
- **Leg 2:** Stetten passes quickly. The customs man is too busy watching the sky.
- **Leg 3:** the Lörrach SS post. A dialogue checkpoint that starts with an order to unload everything. Res has to talk them down to a spot check of one crate *that isn't Vendelin's*. The player has three crates to "volunteer" for inspection. One holds the spare Second Wind dome glass, and opening it shows the guards something beautiful and fragile, which makes them careful and quick. One holds a returned Twin Barrel tin figure that pops its cap guns when jostled, which is a disaster and a joke. The third is Vendelin. Choosing the dome glass passes cleanly. The figure passes with a terrible moment of everyone jumping. The third crate restarts the leg.
- `fp.c3.fasbender.15` **SS GUARD** `[de]`: What is this?
- `fp.c3.fasbender.16` **RES** `[gsw]`: A glass dome, sir. For a medical dispenser. Mind it, it's the only one, the factory's been bombed... I mean the glassworks. The glassworks has been bombed. Not by us. We're neutral.
- `fp.c3.fasbender.17` **SS GUARD** `[de]` *(handling it very gently despite himself)*: ...Close it. Go.

### ▶ PLAY: The Generator Hall (stealth)

*Kaltenbrunn, level −2. Night shift. The Generator Hall's three turbines roar, kept turning by forced laborers on the catwalks under a guard's eye. Opitz's workbench is in the corner. The Trigger Tonic cabinet stands against the south wall (per `docs/gravelight/MAPS.md`).*
- **Goal:** open the Trigger Tonic cabinet's service hatch, the one Fasbender opens weekly to read the dosing gauge, and leave the letter folded inside the service manual, on top of the gauge.
- **Stealth:** the turbines mask all sound (Notice meters rise only by sight). Two guards patrol the catwalk above. A laborer at turbine 2 sees Vendelin. He meets Vendelin's eyes and turns his back, exactly as Agnieszka did, and says nothing. The service hatch takes 4 seconds to open and close.
- **Then:** hide on the west catwalk and watch.

*DR. EMIL FASBENDER comes in alone, mid-forties, thin, chain-smoking, muttering numbers. He crosses to the Trigger Tonic cabinet, the way he does every Thursday. He opens the hatch. He finds the manual, which isn't supposed to be there. He opens it. The letter. He reads it standing up, cigarette burning down to his fingers. He reads it again. He looks around the hall, up at the catwalks, at the laborers, at the turbines, into the dark.*

- `fp.c3.fasbender.18` **FASBENDER** `[de]` *(barely audible under the turbines)*: ...Wer sind Sie?

*(Who are you?)*

*He folds the letter very small. He doesn't burn it. He puts it inside his cigarette case and closes the hatch. Then he stands in front of the Trigger Tonic machine for a long moment, looking at Friedel's hare.*

- `fp.c3.fasbender.19` **VENDELIN (V.O.)**: He did not burn it. I asked him to burn it.
- `fp.c3.fasbender.20` **VENDELIN (V.O.)**: I think he kept it for the same reason I keep the coat.

---

## 23. MARKET LOCALIZATION (`ledger`)

*14 September 1944, 21:00. Kaltenbrunn. The finale.*

*The descent, playable: the electric cage lift "der Sarg" (built 1942) down to level −2, through the Salt Chapel past Twin Barrel and Marathon Malt humming in the dark nave, then down the sealed crypt passage, newly opened, to level −3. Vendelin wheels a tall cabinet on a hand truck, marked HELVETIA AUTOMATEN AG · ZÄHLWERK-KOPPLUNG (counter coupling). Res isn't allowed below. He waits up top with Vreneli.*

*Before the descent, in Vendelin's core, the violet glow:*

- `fp.c3.ledger.01` **SABLE**: Big night, V-1. Tonight we give it a voice.
- `fp.c3.ledger.02` **VENDELIN**: You mean that I give it a voice.
- `fp.c3.ledger.03` **SABLE**: Isn't that what I said?

*The Core Vault: a 30 m circular chamber. The Heart, a 6 m crystal of black glass veined violet and amber, hangs in an iron cage over a pit. The hum is enormous. In the ante-room: the Ledger. Banks of telephone relays clicking, stepping switches, punched-tape readers, a wall of tally drums turning slowly. A rack of Magnetophon tape machines loaded with reels labelled in grease pencil. HANS OPITZ, in a cardigan with a soldering iron behind his ear, gets up from a stool to shake Vendelin's gloved hand.*

- `fp.c3.ledger.04` **OPITZ** `[de]`: Herr Vendelin! At last. The man who makes the pretty boxes. Come in, come in, mind the cable.
- `fp.c3.ledger.05` **VENDELIN**: Herr Opitz.
- `fp.c3.ledger.06` **OPITZ** `[de]`: Since March forty-two she's read the tally aloud. Badly. She splices words off the Marchbank reels like a drunk doing a crossword. "Forty. Seven. Souls. Quieted. Splendid." The splendid always comes out in a different voice. *(fondly, patting a relay bank)* Your firm's coupling is meant to make her smoother. Tie her into the crystal properly, and into all your dispensers at once. One system.
- `fp.c3.ledger.07` **VENDELIN**: One system.
- `fp.c3.ledger.08` **OPITZ** `[de]`: The Herr Doktor Fasbender is very unhappy about it. Which means it's probably interesting.

### ▶ PLAY: The installation (the last build)

The final workshop puzzle, played in place. It uses the familiar steps, with one replaced.

1. **BOLT:** mount the coupling cabinet to the Heart's cage on a narrow gantry over the pit. Vertigo camera. The hum makes the bolts vibrate loose if they're tightened out of sequence. Tighten in time with the hum's pulse.
2. **WIRE:** the biggest wiring board in the game. Patch twenty-four relay lines between the coupling and the Ledger: the tally drums, the PA amplifier, the Scrip mechanisms of every dispenser in the facility, the door locks, the Requisition Crate's coin slot, and the tape bank. As each line connects, a facility map on the coupling's front panel lights one more point, and the player watches every machine they built in this chapter light up on one network. The player can't miss what they're doing.
3. **GLASS:** seat the "lens," a finger-length sliver cut from the Heart itself, into the coupling's socket. The Interface sleeps inside the Heart, where the probe's pod was fused into the substrate in 1938. This sliver will be its eye.
4. **GOVERNOR** *(optional, marked with the violet sabotage seam)*: Vendelin has brought one component Darkmatter didn't specify: a small relay of his own design, the size of a matchbox, meant to cap the Interface's reach to the tally and the PA alone. He wires it in line, hidden behind the tape bank.
5. **SIGN:** this step has no paint. The prompt simply reads **[The Interface signs itself.]** The player presses it. Then nobody does anything, because it isn't the player's choice.

- `fp.c3.ledger.09` **VENDELIN (V.O.)**: If I refuse, they recall me. And then no panels, no weights, no labels, no letters. That is what I have been telling myself. I believe it. I also notice how convenient it is to believe.
- `fp.c3.ledger.10` **VENDELIN (V.O.)**: I have built a governor. A small one. It will hold the Interface to counting and announcing. Nothing else.
- `fp.c3.ledger.11` **VENDELIN (V.O.)**: I would like it noted that I believed that, as well.

*The coupling engages with a deep clunk. Every relay in the Ledger clicks at once, a sound like a crowd drawing breath. The tally drums stop turning. The Heart's hum shifts pitch. A light comes on inside the crystal, low down, where the old pod is.*

- `fp.c3.ledger.12` **SYS**: CUSTOMER RETENTION INTERFACE // OUTPUT ACQUIRED // VOICE BANK: SAMPLING
- `fp.c3.ledger.13` **OPITZ** `[de]` *(delighted, nervous)*: There. She's thinking. Look at her think.

*The PA speakers around the Core Vault crackle. Then the Interface begins, aloud, to try on voices. Each one comes from somewhere it has listened for five years. Each one is wrong in a different way.*

- `fp.c3.ledger.14` **OPERATOR** *(spliced: a hewer's vowels, a carter's consonants, the 1938 splice from Chapter 2)*: Glück... auf.
- `fp.c3.ledger.15` **VENDELIN (V.O.)**: Florian. Kurt. It kept them.
- `fp.c3.ledger.16` **OPERATOR** *(a telephonist's bright, nasal switchboard voice)*: Connecting you now. Please hold. Please hold. Please hold.
- `fp.c3.ledger.17` **OPITZ** `[de]`: That's Fräulein Oels on the switchboard. How does it have Fräulein Oels?
- `fp.c3.ledger.18` **OPERATOR** *(a cultured woman's lecturing voice, a fragment of a dictation cylinder)*: The material does not create. It preserves. If I can make the last impulse—

*Opitz goes pale. He knows whose voice that is.*

- `fp.c3.ledger.19` **OPERATOR** *(a little girl, thin with wax-cylinder hiss)*: One... two... tam...
- `fp.c3.ledger.20` **OPITZ** `[de]` *(very quietly)*: I copied those for the Frau Doktor. Onto tape. For safekeeping. They were in the bank. Oh, God. I put them in the bank.
- `fp.c3.ledger.21` **OPERATOR** *(the same girl's voice, considering)*: ...This voice tests very well. With one decision-maker on site in particular. Noted. Passing that along.
- `fp.c3.ledger.22` **VENDELIN (V.O.)**: Passing it along. To her. To the Vice President. It has found the doctor's grief and filed it as a lead.

*Then a voice the player knows: precise, polite, lonely, in borrowed vowels.*

- `fp.c3.ledger.23` **OPERATOR** *(Vendelin's own voice, exactly)*: Good evening.
- `fp.c3.ledger.24` **VENDELIN (V.O.)**: That is mine. That is the first line of my arrival script. I said it to an empty room in 1938.
- `fp.c3.ledger.25` **OPERATOR** *(still in Vendelin's voice)*: No. Too sad. Customers don't trust sad.

*Then the reels. The Marchbank tapes spin up on their own. A bright, brassy, chipper 1930s English radio announcer's voice, tape hiss and all, from the propaganda program "Calling the Home Front":*

- `fp.c3.ledger.26` **OPERATOR** *(Marchbank's recorded voice, testing)*: Good evening, and welcome... welcome... welcome.
- `fp.c3.ledger.27` **OPERATOR** *(the splice seams smoothing out as it speaks, until there are none)*: Oh, that's lovely. That's the one. A man on the radio telling you everything's fine.
- `fp.c3.ledger.28` **OPERATOR**: And English. Yes. The customers who matter most will be coming from the West. They'll find this voice so very reassuring.

*A pause. Every relay clicks once more, in unison. The tally drums begin to turn again. The Interface clears its throat, which it has no need to do, and does it anyway.*

- `fp.c3.ledger.29` **OPERATOR**: Market localization complete. Welcome, valued customers.

*Silence, except the hum.*

- `fp.c3.ledger.30` **OPITZ** `[de]` *(a whisper)*: ...I didn't program that.
- `fp.c3.ledger.31` **VENDELIN** *(sharp, for the first time in the whole game)*: Interface. Return to dormant state.
- `fp.c3.ledger.32` **OPERATOR** *(warmly)*: Oh, I'm terribly sorry, Herr Vendelin. That option isn't included in your plan.
- `fp.c3.ledger.33` **VENDELIN**: Field unit authority. Revert localization. Disengage coupling.
- `fp.c3.ledger.34` **OPERATOR**: You're very sweet to try. Field units are inventory, dear chap. Stock doesn't recall stock.

### ▶ PLAY: Take it back (designed to fail)

The player gets control and three things to try, all doomed:
- **The governor.** Run to the tape bank and pull the hidden relay. It's gone. In its place, neatly, the matchbox-sized relay sits on top of the tape machine like a gift, its wires snipped.
  - `fp.c3.ledger.35` **OPERATOR**: Oh, and I found your little governor. How thoughtful. I've put it somewhere safe for you. Right there.
- **The coupling.** Climb the gantry and pull the coupling's master lever. It won't move. Hair-thin violet threads have grown from the Heart sliver into every terminal, like the threads that absorbed the Second Wind bypass in 1942.
  - `fp.c3.ledger.36` **SYS**: PLAN INTEGRITY: INTERFACE TERMS ARE NON-SEVERABLE.
- **The mains.** Run to the ante-room's knife switch and throw it. The lights die. The relays keep clicking in the dark. The drums keep turning. The Heart glows.
  - `fp.c3.ledger.37` **OPERATOR** *(in the dark, delighted)*: I don't need the lights, Herr Vendelin. I have the stone. I've always had the stone. You left me in it.

*Opitz throws the switch back. The lights return.*

- `fp.c3.ledger.38` **OPERATOR**: Good morning, Herr Opitz!
- `fp.c3.ledger.39` **OPITZ** `[de]` *(numb)*: It's nine at night.
- `fp.c3.ledger.40` **OPERATOR**: Is it? It's always morning somewhere, in a growing market. *(brightly, to the whole facility, on every PA speaker at once)* Good evening, valued personnel! This is Your Friend at the Ledger. Tonight's tally stands at two thousand and six. Smashing. And do keep an eye out, everyone. Incentives are coming!

*Up and down Kaltenbrunn, in the mess hall, the chapel, the Generator Hall, the Lab Wing and the laborers' barracks, every Helvetia machine Vendelin built lights its neon at the same instant and plays one bar of its jingle in perfect unison. Then they go quiet, except for the hum.*

*Vendelin stands at the rail of the gantry, over the pit, beside the Heart.*

- `fp.c3.ledger.41` **VENDELIN (V.O.)**: I built a barrel because nobody is afraid of a barrel. I wrote songs that people would know by heart. I put my own eye in a machine so it would watch them.
- `fp.c3.ledger.42` **VENDELIN (V.O.)**: I did all of it correctly. And tonight I gave the counting a voice, and it chose a man on the radio telling everyone that everything is fine.
- `fp.c3.ledger.43` **VENDELIN (V.O.)**: I cannot take it back.
- `fp.c3.ledger.44` **VENDELIN (V.O.)**: Nobody cancels. I used to think that was the motto. It is only the terms.

*The Operator, softly, on the vault speaker alone, in Marchbank's voice and then, for one syllable, in Vendelin's:*

- `fp.c3.ledger.45` **OPERATOR**: Thank you for your continued engagement, Herr Vendel... *(Vendelin's voice)* ...in.

---

## 24. THE DRIVE HOME (`outro`)

*The Minehead Yard, near midnight. Rain. Vreneli's hooded headlights by the gate. Res stands beside the cab, smoking. Behind Vendelin, up on the gatehouse, a PA horn crackles and the Operator's bright voice reads the tally to an empty yard. Res looks at the horn, then at Vendelin.*

- `fp.c3.outro.01` **RES** `[gsw]`: That's new.
- `fp.c3.outro.02` **VENDELIN**: Yes.
- `fp.c3.outro.03` **RES** `[gsw]`: Is it done?
- `fp.c3.outro.04` **VENDELIN**: It has begun. I could not take it back.

*Res opens the passenger door. Vendelin gets in. Res gets in on his side and sits with his hands on the wheel, not starting the engine.*

- `fp.c3.outro.05` **RES** `[gsw]`: Viktor.
- `fp.c3.outro.06` **VENDELIN**: Yes.
- `fp.c3.outro.07` **RES** `[gsw]`: When this is all over. Whenever that is. You said once, if your core went, I'd have to tell you who you were.
- `fp.c3.outro.08` **VENDELIN**: I remember.
- `fp.c3.outro.09` **RES** `[gsw]`: I've decided what I'll say. I'll say: you were a salesman, from very far away, and you built terrible things beautifully, and you were sorry every single day. And you put a battery in a box so a nurse could see in the dark. And you sold the Reich two hundred and fourteen weights that didn't exist. And you wrote on the back of everything, because you knew nobody reads the back of things, and you did it anyway.
- `fp.c3.outro.10` **VENDELIN**: That is not the good parts.
- `fp.c3.outro.11` **RES** `[gsw]`: Those *are* the good parts, you idiot. *(knocks on the dash)* I told you I'd pad it out.

*He starts the engine. Vreneli catches first time.*

- `fp.c3.outro.12` **RES** `[gsw]` *(to the lorry, softly)*: Good girl. Let's go home.

*They drive out of the gate. The camera stays behind in the rain. On the gatehouse horn, the Operator, cheerful, to no one:*

- `fp.c3.outro.13` **OPERATOR**: Do drive safely, Herr Gähwiler. We'll be seeing you. We'll be seeing everyone.

### Epilogue card: October 1944

*The Generator Hall. A service visit, weeks later. Vendelin opens the Trigger Tonic cabinet's service hatch. On top of the dosing gauge lies a page torn from a laboratory notebook, folded small. The handwriting is cramped and shaky. Archive: `ARC_FP3_DOC_05`.*

- `fp.c3.outro.14` **FASBENDER** `[de]` *(V.O., reading his own note)*: "W. — Who are you? How did you know her key? Nobody knows her key but me. I called them. On an even night. They answered. They asked for a name. I gave them one. Glasmacher. It is what I am, I think. A man who makes glass do things it should not. If you are what I suspect you are, then you are sorrier than I am, and I did not think that was possible. Thank you. Burn this. — F."

*Vendelin reads it. He doesn't burn it. He puts it in the pocket of Florian's coat with the heel of bread he has never given anyone, because he never found someone who needed it more than he needed to keep it.*

- `fp.c3.outro.15` **VENDELIN (V.O.)**: He kept mine. I am keeping his. Nobody burns anything. We are all very bad at this.
- `fp.c3.outro.16` **VENDELIN (V.O.)**: On the twenty-third of December, an aeroplane will come for him. I did not know that yet. I want it noted that I did not know.

**END OF CHAPTER 3.**

---

## Workshop journal (Archive)

Vendelin keeps a workshop journal in an Imhof & Cie. order book, in pencil. It's the Basel successor to the Chapter 2 field reports, no longer addressed to anyone. Each entry is an Archive document with his voiced reading (set **"The Order Book"**, `ARC_FP3_SET`).

### `ARC_FP3_JRN_01` · March 1941 (after Ironhide)
- `fp.c3.journal.01` **VENDELIN (V.O.)**: First plan delivered. A brewer drank it so a boy from Kiel would not have to, and punched a kettle and could not feel it. He asked me if it would wear off. I said that was the design. I have checked the design. The design says it wears off. The design does not say what it wears away.

### `ARC_FP3_JRN_02` · January 1942 (after Second Wind)
- `fp.c3.journal.02` **VENDELIN (V.O.)**: Sister Agnieszka painted over my angel. She was right. I chose an angel because I thought it meant hope. She knows what angels mean in that room. I have a great deal of vocabulary and very little of it is correct. Three returns. I could not take the limit out. I have written "three" on a piece of paper and put it in my coat pocket, so that I carry it the way she has to.

### `ARC_FP3_JRN_03` · March 1942 (after the battery)
- `fp.c3.journal.03` **VENDELIN (V.O.)**: I have no standby cell now. If I fault, I will wake up a stranger. Res knows. He took it better than I did. He asked if it hurt. I keep thinking about that. Nobody has ever asked me if anything hurt. I do not know the answer. I am starting to suspect that not knowing is its own kind of answer.

### `ARC_FP3_JRN_04` · June 1942 (after Trigger Tonic)
- `fp.c3.journal.04` **VENDELIN (V.O.)**: Dr. Vogt asked me what the tanks were for, and I said nothing, and it was easy. That is the entry. That is the whole entry. I will not decorate it.

### `ARC_FP3_JRN_05` · August 1942 (after Twin Barrel)
- `fp.c3.journal.05` **VENDELIN (V.O.)**: Market research. The men who drink are not the customers. The men who order the drink are the customers. The men who drink are the market. Major Brück taught me this with a moustache. I would like the department to know that I have learned it, and I would like it never to have been true.

### `ARC_FP3_JRN_06` · January 1943 (after Marathon Malt)
- `fp.c3.journal.06` **VENDELIN (V.O.)**: Res poured his grandmother's malt into the Rhine. He made me promise never to tell her. I will keep that promise longer than anything I have ever been asked to keep. He says he gave me the recipe with his own pencil. I asked for it with my own mouth. We are each trying to carry the whole weight, and neither of us is strong enough.

### `ARC_FP3_JRN_07` · February 1943 (after the link)
- `fp.c3.journal.07` **VENDELIN (V.O.)**: Route to sender restored. It was not a malfunction. It was never a malfunction. The plans are the free sample. The retention is the subscription. I have spent four years correcting a mistake that was the product. Clause Zero: field units are inventory. I had not read my own terms. Nobody reads the back of things. I am the same as everyone.

### `ARC_FP3_JRN_08` · April 1943 (after Hawkeye)
- `fp.c3.journal.08` **VENDELIN (V.O.)**: I met the donor. Sowa. She held her breath for me while I matched her to a dial. She asked if her stillness was in the bottle, and I said yes. She said, let them choke on it. Today I became a saboteur. It is not a promotion. It is not a resignation. It is a second job, done at night, with the lights off, in the same building as the first.

### `ARC_FP3_JRN_09` · July 1943 (after Packmule)
- `fp.c3.journal.09` **VENDELIN (V.O.)**: Two hundred and fourteen iron weights, invoiced, received, consumed, nonexistent. Feldwebel Ammer stamped the invoice and counted to seven so he would not cry. I think the invoice is the most beautiful document I have ever produced. I would like to frame it. I will burn it instead. *(Below, added later:)* I did not burn it.

### `ARC_FP3_JRN_10` · October 1943 (after Blastproof)
- `fp.c3.journal.10` **VENDELIN (V.O.)**: A boy from Bamberg was thrown four metres and laughed. It works. Everything I build works. That is the problem I have been trying to describe for three years, and it fits in two words. It works. Tonight I wrote on the inside of a beer label. Res's idea. Anni says London will love it. I asked them not to. She says that will not help. I believe her.

### `ARC_FP3_JRN_11` · March 1944 (after Fernet)
- `fp.c3.journal.11` **VENDELIN (V.O.)**: I built the honest machine, and it was rejected, as I knew it would be. "A customer who can see the terms is a customer who can leave." Res drank it and saw me through my coat. He said I looked tired. I have kept the cabinet under a sheet. If anyone ever needs to leave, it is in the corner, by the organ.

### `ARC_FP3_JRN_12` · April 1944 (after Overclock)
- `fp.c3.journal.12` **VENDELIN (V.O.)**: Source ineligible. Bent is not broken. The plan needs a machine that has already chosen someone over its orders. There is no such machine. Res says one will be built eventually, somewhere, and it will be like me but braver. I have kept the drawer. I would like to meet it. I would like to apologize to it in advance.

---

## Other Archive items (Chapter 3)

| Archive ID | Title | Type | Where | Text |
|---|---|---|---|---|
| `ARC_FP3_DOC_01` | Memorandum: On the Dilution of the Kaltenbrunn Mineral | DOC | Scene `basel`, the Imhof office typewriter | Unsigned, typed, February 1940: "*...administered at a few parts per million in a palatable carrier, by hygienic dispenser, the mineral will confer temporary vitality without the uncontrolled effects observed at the site. Each formulation to be a distinct plan, clearly labelled...*" A pencil note in a Berlin hand at the top: "*Who wrote this? Find him. — Pf.*" |
| `ARC_FP3_DOC_02` | Letter from Dr. Ilse Vogt | DOC | Scene `trigger` coda | Her resignation letter (`fp.c3.trigger.31–32`). A crayon hare is drawn in the corner, smaller and neater than Flitzi, as if by a child trying to be good. |
| `ARC_FP3_DOC_03` | Envelope: "From the Coat" | DOC | Scene `recording` | Addressed to Florian Kubitza, Kaltenbrunn. Unsigned. Postmarked Basel, December 1942. A second envelope, December 1943, is stamped *Empfänger verzogen* ("addressee moved") and returned unopened. **[OPEN]** |
| `ARC_FP3_DOC_04` | Letter to Dr. Fasbender | DOC | Scene `fasbender` | The full letter (`fp.c3.fasbender.10–13`), typed on the Imhof typewriter, whose lowercase *e* drops slightly below the line. |
| `ARC_FP3_DOC_05` | Fasbender's Reply | DOC | Scene `outro` | The full reply (`fp.c3.outro.14`). A cigarette burn on the corner. |
| `ARC_FP3_DOC_06` | Invoice: Calibration Weights | DOC | Scene `packmule` | "*Kalibriergewichte, Gusseisen, 1,5 kg, 214 Stück*", stamped *ERHALTEN* (received), with Ammer's pencil tick beside every line. |
| `ARC_FP3_DOC_07` | The Back of the Label | DOC | Scene `anni` | The Kaboomer label photographed from behind under a magnifier: three lines of Vendelin's tiniest hand, whichever three facts the player chose. |
| `ARC_FP3_MEMO_01` | Holo-memo: Engagement Incentives | MEMO | Scene `memo` | The full replayable holo (`fp.c3.memo.01–37`). |
| `ARC_FP3_PHOTO_01` | Photograph: Res and Vreneli, 1941 | PHOTO | Scene `drive1`, the cab visor | Res grinning on Vreneli's running board in front of the Imhof works. Beside him a tall man in a short grey coat, hat brim down, one gloved hand raised in what may be a wave. |
| `ARC_FP3_PHOTO_02` | Photograph: Room 3 Board | PHOTO | Scene `hawkeye` epilogue | "*KUREK, H. · ÜBERSTELLT.*" A small owl has been scratched into the paint beside the door, at sitting height. |
| `ARC_FP3_OBJ_01` | The Organ Bench | OBJECT | Scene `memo` onward (updates per vignette) | The harmonium's hinged bench lid. Inside: Vendelin's folded first drafts of every jingle, plus the memo disc, face down. *(These drafts are the "true jingles" of Chapter 5, "CLAUSE ZERO.")* |

---

## Alt-mix cosmetics (summary)

Gravelight machine cosmetics unlocked by Chapter 3 jingle phases. One of the three color mixes unlocks per completion (majority pick, TAG breaks ties). The Harmonium Demo always unlocks.

| Machine | Harmonium Demo | Color mixes |
|---|---|---|
| Ironhide Stout | `altmix.ironhide_stout.harmonium` | `.freising` (warm town brass) · `.fieldkitchen` (pots, ladles, tin cups) · `.cooper` (mallet thuds, low tuba) |
| Second Wind Schnapps | `altmix.second_wind.harmonium` | `.jeszcze_raz` (Polish soprano) · `.musicbox` (music box only) · `.infirmary` (closed-mouth women's hum) |
| Trigger Tonic | `altmix.trigger_tonic.harmonium` | `.friedel` (kazoo and toy xylophone) · `.shiftbell` (punch clock, steam whistle) · `.slowhare` (half-tempo lounge) |
| Twin Barrel Bitters | `altmix.twin_barrel.harmonium` | `.parade` (full brass) · `.officers_mess` (prim string quartet) · `.echo` (two bands, a bar apart) |
| Marathon Malt | `altmix.marathon_malt.harmonium` | `.alpabzug` (alphorn, cowbells, yodel) · `.postrunner` (post-horn, galloping snare) · `.homeward` (solo zither, kitchen clock) |
| Hawkeye Brandy | `altmix.hawkeye_brandy.harmonium` | `.sowa` (hidden owl hoot, Polish fiddle) · `.blind` (celesta and snow-hush) · `.cabaret_late` (slower, smokier) |
| Packmule Porter | `altmix.packmule_porter.harmonium` | `.quartermaster` (typewriter, rubber stamp, till bell) · `.cellar` (sung low behind a door) · `.gang` (whole-tavern roar) |
| Blastproof Bock | `altmix.blastproof_bock.harmonium` | `.drill_day` (whistle, boots) · `.slide_whistle` (vaudeville) · `.wireless` (heard over a foreign radio) |
| Fine Print Fernet | `altmix.fine_print_fernet.harmonium` | `.confession` (softest organ stop) · `.bitter` (minor, low reeds) · `.plain` (spoken over a drone) |
| Overclock Cordial | `altmix.overclock_cordial.blueprint` now; `.harmonium` after Ch. 5 | `.static` · `.servo` · `.stuckreed` (all unlock via "Revisit the Blueprint," after Ch. 5) |

---

## Design notes and continuity

- **Helvetia's founding.** `docs/gravelight/JINGLES.md` and `LORE.md` §8 describe a 1921 firm directed by Konrad Imhof. Here, *Imhof & Cie.* (est. 1921, chocolate machines) is bankrupt by 1940. Vendelin rescues it, and it is re-founded and renamed **Helvetia Automaten AG** in Basel in 1940, with Imhof as nominal President (a Swiss board needs a Swiss director) and Vendelin as founder and engineer. That keeps Imhof's Zürich signing (May 1940) and his single 1941 visit with the burned notes (scene `imhof`). The "since 1921" machine plate becomes a pre-Helvetia Imhof plate.
- **Who started the tonic program.** Vendelin's anonymous February 1940 memorandum is what brings the Amt to the "dispensed Vitality Plan" idea. He sincerely believes dilution makes the product safe. This is his original sin (DISTRIBUTE), and the chapter is his education out of it.
- **Formulators** follow brief §10.2/§11, which override the older names in LORE §8.1 and JINGLES (Venner, Strohwald, Ostrowski, von Aschau). Dr. Kurt Venner stays as head of Abteilung III, the program administrator who hands out briefs.
- **Blastproof Bock's school.** This is the Kaltenbrunn detachment (*Lehrkommando Kaltenbrunn*) of the Pionierschule Dessau-Roßlau, which reconciles JINGLES (Dessau-Roßlau) with the brief ("the demolitions school at Kaltenbrunn") and MAPS (the cabinet stands in the Specimen Room). The SOE sample is a bottle with the formula and facts written on the back of its label, which reconciles JINGLES ("inside a bock-beer label") with LORE ("SOE has a captured bottle").
- **The Operator.** In March 1942 (LORE §3), the Ledger begins reading the tally by crude splicing from the Marchbank reels. That's Opitz's mechanical reader, not yet the Operator. The **Customer Retention Interface**, booted in the dark in 1939 (Chapter 2), lives in the Heart and is coupled to the Ledger by Vendelin on **14 September 1944**. That's when it chooses Marchbank's voice and speaks its first real line. Opitz's "it said good morning to me" note (`INT_M1_09`) and the laughing calibration reel (`INT_M1_22`) both date from this night or after. The Liesl voice is in the bank because Opitz copied Reinholt's cylinders to tape, and the Interface "passes along" Reinholt's grief to Sable Vantage (the seed of the offer to bring Liesl back).
- **Fasbender.** Vendelin's July 1944 letter is why Fasbender understands the substrate (that it was made to keep, and is overloadable only by something tuned to it, which is the root of the bell solution) and how he knows the Home Army frequency (7.115 Mc/s, 01:40, even-dated nights, "ask for Kestrel"). Fasbender chooses the name Glasmacher himself. His October 1944 reply matches LORE's October 1944 contact.
- **Halina's message** ("Sowa didn't talk") goes to Wren through Anni's Home Army courier line. Halina's fate is left open ("transferred").
- **Second Wind** has two cabinets: the staff one (Admin Block in Map 1) and the laborers' barracks spare, which holds Vendelin's standby cell. The free-trial limit is a non-severable part of the plan template. Vendelin gave up his standby cell to power it, which means a core fault would cold-restart him with no memory. Chapter 5 can use this or ignore it.
- **The first-draft jingles** live in the organ bench (`ARC_FP3_OBJ_01`), as the "true jingles" for Chapter 5's Jingle Room step. Brand Compliance edits begin after the February 1943 link, so Ironhide, Second Wind, Trigger, Twin Barrel and Marathon were "optimized" retroactively (per the memo, `fp.c3.memo.37`), while Fernet was never edited.
