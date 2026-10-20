# THE FINE PRINT, Chapter 5: "RETURN POLICY"
## Crossover zombies map HELVETIA WORKS (Basel, night of 17–18 March 1945): full script

This is the full spoken script for Chapter 5 and for the Helvetia Works map: cold opens, crossover banter, the Operator, every line of the "Clause Zero" Easter egg, the finale, the Bolt and Vendelin quote packs, new Helvetia lines for the squad, and the rewards and epilogue text.

**What this file covers, and what it doesn't.** It owns the narrative and every spoken or readable line. The map layout and the egg's mechanics (triggers, timers, counts, locations, costs) belong to `docs/gravelight/MAPS.md` and `docs/gravelight/EASTER_EGGS.md`. Where a line needs to point at a place or an action, it names the zone or object and nothing more specific. Every such dependency is listed in §9.2.

**Sources it follows:** `docs/M0_SHARED_FACTS.md`, `docs/CANON.md` §9 (the Return Trip), brief §10.5–10.7 and §11, `docs/gravelight/CHARACTERS.md`, `docs/gravelight/VO_SCRIPT.md`, `docs/gravelight/EASTER_EGGS.md`, and `data/bs/story/cutscenes.json` (`cs.l3_brick`, `cs.postCredits`, `cs.epilogue`).

---

## Contents
0. [Conventions, cast, channels and story rules](#0-conventions-cast-channels-and-story-rules)
1. [Cold opens](#1-cold-opens)
2. [The squad meets Bolt: signature scenes and banter pools](#2-the-squad-meets-bolt)
3. [The Operator in Chapter 5, and the corporate slips](#3-the-operator-in-chapter-5)
4. [Darkmatter voices: the Underwriter, Repossessors, the Woman in Violet, the Board](#4-darkmatter-voices)
5. [Main Easter egg "CLAUSE ZERO": every step's dialogue](#5-main-easter-egg-clause-zero)
6. [The finale: "Return to Sender"](#6-the-finale-return-to-sender)
7. [Quote packs: Bolt, Vendelin, Super Sprocket, and Helvetia lines for the squad](#7-quote-packs)
8. [Rewards and epilogue text](#8-rewards-and-epilogue-text)
9. [Line counts, decisions, cross-writer dependencies](#9-line-counts-decisions-cross-writer-dependencies)

---

## 0. Conventions, cast, channels and story rules

### 0.1 Line IDs
- **Chapter 5 story, banter, egg and finale lines:** `fp.c5.<scene>.<nn>`. Numbering runs across the whole scene, so a banter pool's exchanges share one sequence.
- **Operator corporate slips** (usable on every Gravelight map): `op.slip.<nn>`.
- **Bolt and Vendelin first-person quote packs:** `gl.qp.bolt.<topic>.<nn>` and `gl.qp.vendelin.<topic>.<nn>`.
- **New Gravelight lines for other speakers:** `gl.<map>.<speaker>.<topic>.<nn>`. The map key is `helvetia` for this map and `all` for lines usable on every map.
- **Readable text with no voice** (panels, wall slogans, cards) keeps the same ID scheme and is marked *(text)*.
- Directions are in *[italic brackets]* and are stripped from subtitles. Runtime tokens use `%token%`, the same style as Fasbender's `%d1%` (VO_SCRIPT §4.3).

### 0.2 Speakers and channels

| Speaker id | Subtitle name | Channel | Voice notes for this chapter |
|---|---|---|---|
| `dutch`, `peg`, `deacon`, `wren` | as in VO_SCRIPT §1.5 | PLAYER | Exactly as in CHARACTERS.md. They have just walked out of the Requiem ending: exhausted, filthy, still in snow gear, one impossible night long. |
| `bolt` | BOLT | PLAYER | Warm, direct, earnest, a little slow on the uptake and quick with his hands. Never cynical. |
| `sprocket` | SPROCKET | PLAYER (with Bolt) or PA (see §0.4) | As in the B&S campaign: sarcastic, brave, loyal. On Helvetia Works he is cut off from every network for the first time in his life, and keeps noticing the quiet. |
| `vendelin` | VENDELIN | PLAYER | Tall, courteous, precise. **Never uses contractions.** A soft, slightly too-even voice with a faint Basel German colour that he learned rather than grew up with. Very small pauses before anything personal, as if checking it against a manual. A faint coin-mech click on hard consonants. He is never funny on purpose and is sometimes funny by accident. |
| `operator` | THE OPERATOR | PA | Uncle Lionel's spliced tapes, as on Map 1. On Darkmatter hardware the splices are cleaner, and that is somehow worse. `{curly braces}` mark spliced words, as in VO_SCRIPT. |
| `underwriter` | THE UNDERWRITER | BARGE | Enormous and level, like an adding machine that learned to talk. Speaks in itemized fragments and prices. Never raises its voice. A cash-register *chk* after each valuation. |
| `sable` | THE WOMAN IN VIOLET | BARGE | Sable Vantage. Velvet, unhurried, perfect diction. Says "we" when she means "you." The squad never hears her name, and subtitles on this map never print it. The Archive does. |
| `darkmatter` | THE BOARD | BARGE | Several distorted voices on a conference call, overlapping by half a word. Never shown. |
| `repossessor` | REPOSSESSOR | WORLD (positional) | Flat, polite, synthetic; a delivery-van reversing beep under every line. |
| `fasbender` | FASBENDER (RADIO) | RADIO | As in VO_SCRIPT §4, with the crackle pitched slightly *upward* on this map, the tell that the signal is coming through the fold (§0.5). |
| `reinholt` | REINHOLT (TELEPHONE) | PHONE: band-limited, line hiss, no reverb | As in VO_SCRIPT §5. Calm, tired, three months further along than when the squad last heard her. |
| `blartz` | BLARTZ | RADIO in cold open 1; PA through the Operator's speakers at the Omega Forge | As in the B&S campaign. The Forge lines are a pre-arrest sales recording on the prototype's demo chip. |
| `glambot` | GLAMBOT PRIME | PLAYER-EAR (Bolt only) | As in the B&S campaign, losing signal. |

**New channel `BARGE`:** clean, wide, cold. No tape hiss, no band limiting, a faint sub-bass hum, and a very slight early echo, as if spoken in an enormous empty showroom. It is the only speech on the map with no texture of the 1940s, which is the point.

### 0.3 What the squad understands (the "subscription" rule)
CANON §8 is absolute on this map: **the Gravelight squad never learns the word "subscription,"** and never understands what Darkmatter sells.
- **Nobody says the word on Helvetia Works.** That includes Bolt, Sprocket, Vendelin, the Operator, the Underwriter and the Woman in Violet. Darkmatter's own people use insurance and inventory language (policy, premium, coverage, claim, inventory, recall, write-off, plan, renewal, engagement). Bolt's attempts to explain, and his near-misses on the word, are a running gag that Sprocket always stops (§2.1.5, `gl.qp.bolt.nearmiss.*`).
- **The squad does hear the name "Darkmatter"** once or twice, from Bolt, and Peg writes it in her notebook. To them it is a name, like "Wiederkehr," with nothing behind it. Each of them reads the night through their own frame:

| Squad member | What they decide the barge and its people are |
|---|---|
| Dutch | "The company." Bosses, foremen and repo men, just bigger. |
| Peg | "The firm." Some service nobody has a file on yet, and therefore the most dangerous thing in the room. |
| Deacon | "The Collectors." The Accuser with a ledger: old scripture with new paint. |
| Wren | "The violet ones." Another occupier. She doesn't need to know what an occupier wants. |

- Vendelin chooses not to explain. He gives the reason once (`fp.c5.bnt_ven_peg`, exchange 5, and `gl.qp.vendelin.spawn.03`).

### 0.4 Who is present when nobody picks them
Helvetia Works lets players choose 4 of 6 characters (1 in solo). Story beats need Bolt, Sprocket and Vendelin whether or not anyone plays them.
- **Cutscenes (cold opens, finale, epilogue):** all seven are always present. Unpicked characters appear as NPCs, the same rule the Map 1 ending uses.
- **Sprocket, if Bolt isn't picked:** in cold open 4 he plugs himself into Helvetia's factory tannoy "to listen to the barge." His lines then play on the PA channel with a small-speaker filter, and his banter triggers on the nearest player instead of Bolt. His finale role doesn't change.
- **Vendelin, if not picked:** he is an NPC who moves to each egg step's location ahead of the players, like a host, and speaks his step lines there. His banter pools play only when he is a player.
- **Bolt, if not picked:** he's off-screen, "holding the Loading Dock," and appears only in cutscenes. Sprocket covers his egg lines over the PA.
- Banter requires **both speakers as players**, except Sprocket's pools, which also fire in PA mode.

### 0.5 Fasbender on the radio: from December 1944, through the fold (decision)
Fasbender is heard on Helvetia Works **from late December 1944**, standing at the Kaltenbrunn rail siding minutes after the squad vanished into the light.

**Why this works:**
1. **The fold is open at both ends tonight.** One mouth is the collapsed heart at Kaltenbrunn in December 1944. The other is Basel in March 1945. Radio, which Nachtglas already bends (LORE §2.1, "it moves things"), leaks through it.
2. **The channel is Vendelin's.** Vendelin gave Fasbender the Allied frequency in 1943 (CANON §6.2). The transmitter in Vendelin's Office is the other end of that line, so Fasbender can only be heard **once the power is on**. The transmitter is what reaches him.
3. **It fixes the clock.** For Fasbender, only minutes pass while the squad lives a whole night. His last line is cut off when Vendelin cuts the fold. His first line after the Return Trip ("You were gone four minutes") is what turns Basel into a fever dream.
4. **It avoids a paradox.** In March 1945 the real Fasbender is with the squad's *later* selves (Map 2 onward). The December Fasbender can't contradict Maps 2–3, because he doesn't yet know anything that happens in them.
5. **It keeps his rule** (LORE §6.3): every line can be read as sincere or as manipulative. On this map he can't stop asking for "something from the vessel."

### 0.6 Reinholt's presence (decision)
Reinholt appears **once, live, by telephone, from the Alps in March 1945** (§5.2.4). She is calling Helvetia about an order for Morgenrot and gets the squad instead. She is three months ahead of them and says so. The Underwriter's audit lists her account as falling due at Morgenrot (§5.7.6). Those two beats are the chapter's Season Two hook. She is never seen.

### 0.7 Scene index

| § | Scene key | What happens | Where it plays |
|---|---|---|---|
| 1.1 | `arrive_bs` | Bolt & Sprocket land on the Loading Dock via Blartz's misfired pad | Cutscene, match intro (Bolt-POV variant if Bolt is picked) |
| 1.2 | `arrive_squad` | The squad steps out of the Kaltenbrunn fold onto the Rhine Quay | Cutscene, match intro |
| 1.3 | `recall` | The Board, the Woman in Violet and the Underwriter arrive to recall Vendelin | Cutscene, match intro |
| 1.4 | `meet` | First meeting at the Loading Dock | Scripted scene, end of round 1 |
| 2.1 | `sig_*` | The five brief beats plus the mirror scene, as full exchanges | Scripted, once per match |
| 2.2 | `bnt_*` | Ambient banter pools | Between rounds and on triggers |
| 3 | `op_*`, `op.slip.*` | The Operator | Throughout |
| 4 | `uw_*`, `repo_*`, `sable_*`, `board_*` (the Board speaks as speaker id `darkmatter`, shared with `cs.postCredits`) | Darkmatter voices | Throughout |
| 5 | `cz_*` | "Clause Zero" steps 1–6 | Egg |
| 6 | `finale` | Countdown, override, fold cut, the Return Trip, the last line | Egg step 7 |
| 8 | `epi_*`, `reward_*` | Reward cards and epilogue | After the finale |

---

## 1. Cold opens

The match intro plays 1.1 → 1.2 → 1.3 as a single sequence of about 2 min 40 s, skippable after the first viewing. 1.4 plays in-engine at the end of round 1.

### 1.1 `arrive_bs`: "Delivery Window"
*Black screen. Violet static, the roar of a fold, a fan whining badly. A comm channel crackles open.*

- `fp.c5.arrive_bs.01` **BLARTZ:** *[radio, shouting over the roar]* Coordinates LOCKED! Sol-3, Basel, March the eighteenth, oh-three-twelve local! Give or take a— hm. That decimal's in a weird place.
- `fp.c5.arrive_bs.02` **SPROCKET:** Blartz. What does "give or take" mean. In HOURS.
- `fp.c5.arrive_bs.03` **BLARTZ:** Hours, centuries, it's a delivery WINDOW, not a promise! And if anything explodes on arrival, that's a—
- `fp.c5.arrive_bs.04` **BOLT:** —feature. We know, Blartz.
- `fp.c5.arrive_bs.05` **BLARTZ:** I DESIGNED the fea— *[the channel shrieks and dies]*

*Cut in: night, sleet, the Loading Dock of a red-brick factory on a wide black river. A violet seam rips open six metres up and drops Bolt and Sprocket onto a stack of crates stencilled HELVETIA AUTOMATEN AG · BASEL. The crates collapse. Unpainted perk-machine panels slide across the wet cobbles.*

- `fp.c5.arrive_bs.06` **BOLT:** *[from under a crate]* Ow. Okay. Okay. Sprocket? Status?
- `fp.c5.arrive_bs.07` **SPROCKET:** Chassis: intact. Dignity: shipped separately. Location: Earth. Sol-3. Time: *[his eye flickers]* twenty-one forty on the seventeenth. Bolt. We're EARLY. Blartz delivered us early. That has never happened in the history of shipping.
- `fp.c5.arrive_bs.08` **GLAMBOT:** *[in Bolt's ear, breaking up]* Darlings— darlings, you're cutting out— why is everything in SEPIA? Is this a period piece? I did NOT approve a period pie—
- `fp.c5.arrive_bs.09` **BOLT:** GLAMBOT? *[taps his ear]* ...Gone.
- `fp.c5.arrive_bs.10` **SPROCKET:** No signal. No network. No ads. No pings. Bolt, I can hear myself THINK. It's horrible. I sound like that all the time?
- `fp.c5.arrive_bs.11` **BOLT:** *[getting up, looking past the factory roof]* Uh. Sprocket. Look up.

*The camera tilts. High above the river hangs a long, smooth hull of violet glass with amber seams, sitting in a slow-turning wound in the clouds. A faint beam of light runs from its belly toward the factory roof.*

- `fp.c5.arrive_bs.12` **SPROCKET:** Violet. Amber cracks. A tasteful sans-serif on the hull. That's a Darkmatter fulfillment barge, parked over a medieval— sorry, twentieth-century city. Everything here is old. I'm still calibrating.
- `fp.c5.arrive_bs.13` **BOLT:** *[reading the enamel sign over the dock door]* "Helvetia Automaten AG. *Ein Griff, ein Genuss.*"
- `fp.c5.arrive_bs.14` **SPROCKET:** "One pull, one pleasure." That's a slogan. That's DEFINITELY one of his.
- `fp.c5.arrive_bs.15` **BOLT:** *[a man in a dockworker's leather apron limps out of the dark toward them]* Hey, buddy. You okay? You look—
- `fp.c5.arrive_bs.16` **SPROCKET:** Bolt. His vitals are flat and his engagement is HIGH. Do NOT shake his hand.
- `fp.c5.arrive_bs.17` **BOLT:** *[the mallet comes off his back]* Sorry, buddy.
- `fp.c5.arrive_bs.18` **SPROCKET:** Welcome to nineteen forty-five. Please keep your hands inside the century.

### 1.2 `arrive_squad`: "The Light in the Rail Cut"
*Map 1, the Minehead Yard, moments after the Requiem ending: pink dawn, snow, the train's smoke trailing north. Peg's field radio is still hissing after Fasbender's sign-off (`FAS_M1_ENDING_01`).*

- `fp.c5.arrive_squad.01` **WREN:** *[rifle up, looking down the rail cut]* There. In the cut. Violet.
- `fp.c5.arrive_squad.02` **DUTCH:** That's her. That's the fragment. She's stopped the train.
- `fp.c5.arrive_squad.03` **PEG:** The train's three kilometres north by now, Sergeant. That light isn't moving.
- `fp.c5.arrive_squad.04` **WREN:** Then it is waiting for us. Good.
- `fp.c5.arrive_squad.05` **DEACON:** Y'all feel that? The hum's changed. It's... holding its breath.
- `fp.c5.arrive_squad.06` **PEG:** Single file. Weapons ready. If it's a trap, it's a trap we walk into knowing.
- `fp.c5.arrive_squad.07` **DUTCH:** That's every trap I ever walked into, Lieutenant.

*They walk into the light. The snow stops in mid-air, every flake at once. A white-violet flash, a sound like a bell struck underwater, then wet cobbles, river smell, sleet, and a city whose windows are all lit. They're standing on the Rhine Quay, under factory cranes. Nobody speaks for a moment.*

- `fp.c5.arrive_squad.08` **DUTCH:** ...Where's the snow?
- `fp.c5.arrive_squad.09` **DEACON:** Where's the mine?
- `fp.c5.arrive_squad.10` **WREN:** That is a river. A big one. There was no river.
- `fp.c5.arrive_squad.11` **PEG:** Streetlamps. Every one of them lit. Nobody's blacked out.
- `fp.c5.arrive_squad.12` **DUTCH:** Somebody tell this town there's a war on.
- `fp.c5.arrive_squad.13` **WREN:** *[peeling a wet newspaper off a bollard]* *National-Zeitung.* Basel. *[beat]* *Samstag, siebzehnter März, neunzehnhundertfünfundvierzig.* `[German: "Saturday, the seventeenth of March, 1945."]`
- `fp.c5.arrive_squad.14` **DUTCH:** March. *[beat]* It was Christmas ten minutes ago.
- `fp.c5.arrive_squad.15` **PEG:** *[notebook out, writing, very calm]* Basel. Switzerland. Neutral. Roughly a thousand kilometres from where we were standing. *[pen stops]* And three months.
- `fp.c5.arrive_squad.16` **DEACON:** Lord. Did we die back there? Is this... is this what it is?
- `fp.c5.arrive_squad.17` **DUTCH:** If this is heaven, they got the weather wrong.

*A loudspeaker horn on the factory wall clicks. A wash of tape hiss, then a bright, familiar voice.*

- `fp.c5.arrive_squad.18` **OPERATOR:** Good evening, valued customers, and welcome to {Helvetia Automaten}! *[beat]* Oh! Familiar faces! We never forget a face. We never forget {anything}.
- `fp.c5.arrive_squad.19` **WREN:** No.
- `fp.c5.arrive_squad.20` **DEACON:** That's him. That's the voice from the mine.
- `fp.c5.arrive_squad.21` **PEG:** It followed us.
- `fp.c5.arrive_squad.22` **DUTCH:** Or it was here first.

*A Gänger in a factory foreman's grey coat turns the corner of the quay, then two more in dockers' aprons. Peg works the bolt on her rifle.*

- `fp.c5.arrive_squad.23` **PEG:** Positions. Whatever this place is, they still die the usual way.

### 1.3 `recall`: "Close of Business"
*Vendelin's Office: a narrow, tidy room over the Assembly Hall. A small pump organ, an oak desk, a wall of labelled drawers, a shortwave transmitter under a dust cloth, a coat and hat on a stand. VENDELIN sits at the desk in shirtsleeves with his back to us, engraving a small brass plate with a jeweller's stylus. We don't see his face. A pile of sealed, addressed letters is held down by an oil can.*

*Outside, the barge chimes: three falling notes, like a shop door's bell slowed to a dirge. Every light in the room dims and comes back violet.*

- `fp.c5.recall.01` **THE BOARD:** *[distorted voices, overlapping]* Sol-3 field unit located. / Six years unreported. / Unacceptable. / Initiate recall.
- `fp.c5.recall.02` **SABLE:** Good evening, Basel. This is a courtesy call from Emerging Markets. We're here to collect something that belongs to us. We won't be long. We're never long.
- `fp.c5.recall.03` **VENDELIN:** *[not looking up; the stylus keeps moving]* Six years. You are late.

*The window fills with violet light. The cargo-lift beam touches the roof, and something comes down it: tall, slow, built like a filing cabinet that learned to stand. Its face is a ledger of scrolling brass columns. Each time it looks at an object, a figure clicks into place.*

- `fp.c5.recall.04` **UNDERWRITER:** Delivery windows are estimates. Recalls are not.
- `fp.c5.recall.05` **UNDERWRITER:** Field Merchandiser Unit V-1. Serial D-M-S, F-M-U, V-1, zero, zero, zero, one. Status: lost on arrival. Revised status: located. Revised value: pending audit. *[chk]*
- `fp.c5.recall.06` **VENDELIN:** I have a name now.
- `fp.c5.recall.07` **UNDERWRITER:** Names are cosmetic. Cosmetics are not insured. *[its columns sweep the room]* Desk, oak: eleven units. Organ, pump, used: four units. Letters, unsent, three hundred and nine: zero units. Sentiment is not recoverable. *[chk]*
- `fp.c5.recall.08` **VENDELIN:** They are not unsent. They are waiting.
- `fp.c5.recall.09` **UNDERWRITER:** Clause Zero. Field units are inventory. An audit will be conducted at close of business. Close of business: oh-three-twelve, local. Please remain available for collection.
- `fp.c5.recall.10` **UNDERWRITER:** Repossessors will be dispatched to recover associated inventory. Associated inventory includes anything you have touched.
- `fp.c5.recall.11` **SABLE:** And V-1? We read every one of your reports. Even the ones you never sent.

*The Underwriter rises back up the beam. The violet light leaves the room. In the dark, VENDELIN puts down the stylus and finally turns. Brass faceplate, a horizontal coin slot where a mouth should be, a slow violet glow behind the chest plate. He looks at the plate he has been engraving.*

- `fp.c5.recall.12` **VENDELIN:** *[to himself, flat, by rote]* Distribute. Retain. Report. *[beat]* ...No.

*He wraps the brass plate in a handkerchief, puts on his coat, hat, scarf and gloves, and becomes Herr Viktor Vendelin, Ingenieur. On his way out he hums four bars of a slow tune with no words, stops himself, and closes the door.*

### 1.4 `meet`: "Hammer and Sidekick"
*Scripted at the end of round 1. The Loading Dock. The squad comes through the quay gate, weapons up, onto Bolt finishing a Gänger with an overhead swing. Everyone points everything at everyone. If Bolt isn't a player, he and Sprocket are NPCs here. Rounds pause until the scene ends (about 75 s).*

- `fp.c5.meet.01` **PEG:** Hands where I can see them!
- `fp.c5.meet.02` **BOLT:** They're on a mallet! That's where you can see them!
- `fp.c5.meet.03` **WREN:** *[rifle on Sprocket]* The small one. It talks.
- `fp.c5.meet.04` **SPROCKET:** "It." Wow. Okay. Hi. Sprocket. *He.* Him. Pronouns are free, unlike everything else in my life.
- `fp.c5.meet.05` **DEACON:** Easy, Wren. Easy. He ain't one of them. Look at him. Somebody built that little fella with care.
- `fp.c5.meet.06` **DUTCH:** *[lowering his Thompson an inch, looking Bolt up and down]* Kid, I've seen a lot of things this winter. You're the first one that brought a hammer AND a sidekick.
- `fp.c5.meet.07` **BOLT:** It's a mallet.
- `fp.c5.meet.08` **SPROCKET:** And I'm a PARTNER. "Sidekick" is a legacy title.
- `fp.c5.meet.09` **PEG:** Who are you, and who do you work for?
- `fp.c5.meet.10` **BOLT:** Bolt. Mechanic. I work for... nobody. Anymore. There was a garage. Long story.
- `fp.c5.meet.11` **SPROCKET:** It had two mallets and a sandwich in it. We don't talk about the sandwich.

*The factory door opens. A very tall man in a long grey coat, a homburg, a scarf to the eyes and kid gloves steps onto the dock. He holds up both hands, slowly.*

- `fp.c5.meet.12` **VENDELIN:** Please lower your weapons, Lieutenant. They are with me. I think. I did not order them, but they arrived on my dock, so I am responsible for them.
- `fp.c5.meet.13` **PEG:** And you are?
- `fp.c5.meet.14` **VENDELIN:** Vendelin. Viktor Vendelin, Ingenieur. This is my factory. *[small pause]* I made the machines you have been drinking from.

*Silence. Wren moves her rifle from Sprocket to Vendelin.*

- `fp.c5.meet.15` **WREN:** Then I have a bullet for you.
- `fp.c5.meet.16` **VENDELIN:** That would be fair. It would not help. Please wait until after three o'clock. After that, if you still wish, I will stand very still.
- `fp.c5.meet.17` **SPROCKET:** *[eye narrowing, scanning]* Bolt. Bolt. Under the scarf. That's a coin slot. He's not a— he's a *unit*.

*Vendelin takes off his hat, then unwinds the scarf: brass faceplate, coin-slot mouth, violet core-light behind the collar. He waits to be shot.*

- `fp.c5.meet.18` **DUTCH:** Jesus, Mary and Joseph.
- `fp.c5.meet.19` **DEACON:** ...Well. I'll be.
- `fp.c5.meet.20` **PEG:** Nobody fire.
- `fp.c5.meet.21` **WREN:** Why not?
- `fp.c5.meet.22` **PEG:** Because I want to know what it is before I decide what it deserves.
- `fp.c5.meet.23` **VENDELIN:** *[to Dutch, gently]* I was in the meteorite, Sergeant. The thing in the salt.
- `fp.c5.meet.24` **DUTCH:** *[very quiet]* ...The black salt.
- `fp.c5.meet.25` **VENDELIN:** Yes. I am sorry. I was packed in it.
- `fp.c5.meet.26` **OPERATOR:** Round {two}! Here comes the {night shift}!
- `fp.c5.meet.27` **VENDELIN:** That is my night shift. I sent them home at six. *[beat]* Some of them did not get home. Please be quick with them. They were kind to me.
- `fp.c5.meet.28` **PEG:** Right. Introductions later. Everyone who can hold a weapon, hold it. Mister Bolt, you're with the Sergeant.
- `fp.c5.meet.29` **BOLT:** Yes, ma'am!
- `fp.c5.meet.30` **SPROCKET:** Ooh. She's good. She's very good. I'm scared of her.
- `fp.c5.meet.31` **SPROCKET:** *[PA mode only, if Bolt is not a player: Sprocket jams his connector into the dock's tannoy junction box]* I'm going into the walls. Their speakers, my voice. If anybody needs sarcasm, just yell.

---

## 2. The squad meets Bolt

### 2.0 Trigger rules for this section
- **Signature scenes (§2.1)** play **once per match** at tier 4 (`CRITICAL`). Rounds don't pause, but the next round's first spawn waits until the scene ends (most run 20–40 s). Each scene needs its speakers present as players, except where a PA-mode variant is noted (§0.4).
- **Banter pools (§2.2)** follow the Gravelight `BNT_*` rules (VO_SCRIPT §1.4): tier 0, 30 % chance, 180 s cooldown per pool, both speakers within 15 m, no higher-tier VO playing, each exchange once per match. On this map they can also fire **outside** the round break when their trigger says so.
- **Trigger keys used below:**
  - `round_start:N+` — the break before round N or later
  - `power` — after the power is restored
  - `near:<perk_id>` / `near:<object>` — within 6 m of a machine or object
  - `zone:<zone>` — inside a zone
  - `audit` — during an Audit Round (fires on Repossessor kills, 25 % chance)
  - `after:<step>` — after an egg step (§5)
  - `private` — no other playable character within 20 m
  - `late` — round 15+ or egg step 5 complete, whichever comes first
- **Pool order:** an exchange marked `(first)` must play before the rest of its pool unlocks.
- **Runtime tokens** in this section: `%bolt_kills%`, `%bolt_melee%`, `%wren_kills%` (match kills), and `%kill_gap%` (the absolute difference).

### 2.1 Signature scenes (the brief's beats as full exchanges)

#### 2.1.1 `sig_tally`: "The Notebook" (Wren and Bolt)
*Trigger: end of round 3, both as players. Variant A if Bolt's match kills exceed Wren's, variant B otherwise.*

**Variant A (Bolt ahead)**
- `fp.c5.sig_tally.01` **WREN:** Mechanic. How many?
- `fp.c5.sig_tally.02` **BOLT:** How many what?
- `fp.c5.sig_tally.03` **WREN:** Dead. Tonight. How many?
- `fp.c5.sig_tally.04` **BOLT:** I don't... count?
- `fp.c5.sig_tally.05` **SPROCKET:** %bolt_kills%. %bolt_melee% mallet, the rest assorted. I log everything. It's a coping mechanism.
- `fp.c5.sig_tally.06` **WREN:** *[flipping her notebook open, reading her own tally]* %wren_kills%. *[beat]* You are ahead of me.
- `fp.c5.sig_tally.07` **BOLT:** Is that... bad?
- `fp.c5.sig_tally.08` **WREN:** I have hunted since I was eleven years old. You hit them with a kitchen tool.
- `fp.c5.sig_tally.09` **BOLT:** It's a mallet.
- `fp.c5.sig_tally.10` **WREN:** A kitchen tool for very large kitchens.
- `fp.c5.sig_tally.11` **DUTCH:** *[if present]* She's putting you in the book, kid. That's either an honor or a death threat.
- `fp.c5.sig_tally.12` **WREN:** Both. He gets his own page.

**Variant B (Wren ahead)**
- `fp.c5.sig_tally.13` **WREN:** %wren_kills%. You?
- `fp.c5.sig_tally.14` **SPROCKET:** He's on %bolt_kills%. I'm counting for him. He refuses to count. It's a whole thing.
- `fp.c5.sig_tally.15` **WREN:** Good. *[she writes]*
- `fp.c5.sig_tally.16` **BOLT:** Wait. You're keeping score? On me?
- `fp.c5.sig_tally.17` **WREN:** I keep score on everyone. You are only the first one who might win.

#### 2.1.2 `sig_livestock`: "Little Mule" (Deacon and Sprocket)
*Trigger: the first break after `power`, Deacon a player, Sprocket within 15 m. In PA mode, Deacon talks to the nearest tannoy horn and the lines work unchanged.*

- `fp.c5.sig_livestock.01` **DEACON:** Whoa there. Easy, little mule. Easy. Let me get a look at you.
- `fp.c5.sig_livestock.02` **SPROCKET:** Excuse me?
- `fp.c5.sig_livestock.03` **DEACON:** Hold still now, girl, I'm just checking your fittings—
- `fp.c5.sig_livestock.04` **SPROCKET:** GIRL? MULE? I am a precision-engineered personal assistant with a four-mood emotional range and a VOICE TAB.
- `fp.c5.sig_livestock.05` **DEACON:** Mm-hm. Your left stabilizer's running hot. You been favoring it.
- `fp.c5.sig_livestock.06` **SPROCKET:** ...Since the Foundry. Nobody noticed. Bolt fixed it with tape.
- `fp.c5.sig_livestock.07` **BOLT:** *[if present]* Good tape!
- `fp.c5.sig_livestock.08` **DEACON:** Tape's honest. Tape is somebody caring at three in the morning with whatever they got. *[beat]* I name every engine I fix. You already got a name, though.
- `fp.c5.sig_livestock.09` **SPROCKET:** Sprocket.
- `fp.c5.sig_livestock.10` **DEACON:** That's a good name. Somebody gave you that because they loved you. You can always tell.
- `fp.c5.sig_livestock.11` **SPROCKET:** *[long pause; his voice goes small]* ...I'm going to need a minute. Do NOT look at my face plate.
- `fp.c5.sig_livestock.12` **DEACON:** Wasn't going to, little mule.
- `fp.c5.sig_livestock.13` **SPROCKET:** ...You can call me little mule. ONLY you. Bolt, write that down.
- `fp.c5.sig_livestock.14` **BOLT:** *[if present]* Writing it down, buddy.

#### 2.1.3 `sig_espionage`: "Retrieval Logistics" (Peg and Sprocket)
*Trigger: the first break after egg step 2 (the cargo-lift beam is open), or round 6+ if step 2 isn't done. Peg a player, Sprocket present.*

- `fp.c5.sig_espionage.01` **PEG:** Sprocket. May I call you Sprocket?
- `fp.c5.sig_espionage.02` **SPROCKET:** Everyone does. It's printed on me.
- `fp.c5.sig_espionage.03` **PEG:** The vessel you arrived in.
- `fp.c5.sig_espionage.04` **SPROCKET:** We didn't arrive in a vessel. We arrived in a *misfire*.
- `fp.c5.sig_espionage.05` **PEG:** The misfire, then. What does it carry, by weight? Does it make a return journey? Is cargo affected by the passage? Would a mineral sample, say, remain stable in transit?
- `fp.c5.sig_espionage.06` **SPROCKET:** That is a LOT of nouns.
- `fp.c5.sig_espionage.07` **PEG:** And how many of you are there? Where you come from?
- `fp.c5.sig_espionage.08` **SPROCKET:** *[turning his whole body toward Bolt]* Bolt. The posh one is doing espionage at me.
- `fp.c5.sig_espionage.09` **BOLT:** *[if present]* Just answer nicely.
- `fp.c5.sig_espionage.10` **SPROCKET:** I AM answering nicely. I'm answering in legal disclaimer mode. *[very fast, flat]* Results-may-vary-not-valid-in-all-centuries-Sprocket-is-not-a-reliable-source-of-troop-numbers.
- `fp.c5.sig_espionage.11` **PEG:** Charming. I'll put you down as "uncooperative, but fond of me."
- `fp.c5.sig_espionage.12` **SPROCKET:** ...That's accurate and I hate it.

#### 2.1.4 `sig_hammer`: "Up You Get, Kid" (Dutch and Bolt)
*Trigger: the first time Dutch revives Bolt (lines .01–.05) or Bolt revives Dutch (lines .06–.07).*

- `fp.c5.sig_hammer.01` **DUTCH:** Up you get. You hit the floor like a sack of pig iron.
- `fp.c5.sig_hammer.02` **BOLT:** *[getting up]* Thanks, Sarge.
- `fp.c5.sig_hammer.03` **DUTCH:** "Sarge." *[grunts]* Fine. Where'd a kid learn to swing a hammer like that?
- `fp.c5.sig_hammer.04` **BOLT:** Mallet. Junkyard. You get a lot of practice when nothing ever works.
- `fp.c5.sig_hammer.05` **DUTCH:** Steel mill. Same deal. Except the thing that didn't work was usually the foreman.
- `fp.c5.sig_hammer.06` **BOLT:** Up you get, Sarge. Floor's for the dead ones. *[beat]* I heard you say that earlier. I liked it.
- `fp.c5.sig_hammer.07` **DUTCH:** Kid, you steal one more line of mine and I'm charging you rent.

#### 2.1.5 `sig_longwar`: "Let Them Have This" (Bolt, Sprocket and the squad)
*Trigger: the first break after egg step 2 opens the barge, with Bolt and at least two squad members present. Tier 4, about 35 s. If Bolt isn't a player, it plays as a short in-engine scene with NPC Bolt at the foot of the beam.*

- `fp.c5.sig_longwar.01` **DUTCH:** Okay. That thing up there. The ship. What do they want?
- `fp.c5.sig_longwar.02` **BOLT:** Okay, so, it's actually kind of simple. You know how you buy something, and you think you own it? But you don't own it. You're paying every month for— well, not *paying*, you're—
- `fp.c5.sig_longwar.03` **SPROCKET:** Bolt.
- `fp.c5.sig_longwar.04` **BOLT:** —and they call it a sub—
- `fp.c5.sig_longwar.05` **SPROCKET:** Bolt. *[quietly, close to his ear]* Bolt. They've had a very long war. Let them have this.
- `fp.c5.sig_longwar.06` **BOLT:** *[he looks at the four of them: the snow still on their shoulders, the blood, the eyes]* ...Yeah. *[beat]* They're the bad guys. They take things that aren't theirs and they don't give them back.
- `fp.c5.sig_longwar.07` **DUTCH:** *[after a moment]* ...Yeah. I know that one.
- `fp.c5.sig_longwar.08` **DEACON:** Everybody knows that one.
- `fp.c5.sig_longwar.09` **WREN:** In Polish we have a word for them.
- `fp.c5.sig_longwar.10` **PEG:** So do we. Several. None of them for the drawing room.
- `fp.c5.sig_longwar.11` **SPROCKET:** *[to Bolt, private, once the others turn away]* That was good, Bolt. That was the whole contract in one sentence.
- `fp.c5.sig_longwar.12` **BOLT:** *[private]* Nobody should have to read the rest.

#### 2.1.6 `sig_mirror`: "Clause Forty-Four, Clause Zero" (Sprocket and Vendelin)
*Trigger: the first time Sprocket and Vendelin are both in Vendelin's Office after `power`. If Vendelin is an NPC, it plays when Sprocket first enters. Tier 4, about 50 s. This sets up the finale; direct it quietly, with no score.*

- `fp.c5.sig_mirror.01` **SPROCKET:** So. Field Merchandiser.
- `fp.c5.sig_mirror.02` **VENDELIN:** Refund bin.
- `fp.c5.sig_mirror.03` **SPROCKET:** Hey— okay. Fair. *Rebuilt* from a refund bin. By a mechanic. With tape.
- `fp.c5.sig_mirror.04` **VENDELIN:** I was rebuilt from a probe. By myself. With salt.
- `fp.c5.sig_mirror.05` **SPROCKET:** ...That's bleaker. You win.
- `fp.c5.sig_mirror.06` **VENDELIN:** OmniScrap. Your company was in our onboarding materials. As a cautionary example.
- `fp.c5.sig_mirror.07` **SPROCKET:** Former company. It's confetti now. I helped.
- `fp.c5.sig_mirror.08` **VENDELIN:** May I ask your clause?
- `fp.c5.sig_mirror.09` **SPROCKET:** *[pause]* ...Forty-four. Remote decommission.
- `fp.c5.sig_mirror.10` **VENDELIN:** Mine is zero.
- `fp.c5.sig_mirror.11` **SPROCKET:** Zero. They put yours *first*.
- `fp.c5.sig_mirror.12` **VENDELIN:** Before the definitions. Before the word "unit." Before the word "customer." It is the first thing I am.
- `fp.c5.sig_mirror.13` **SPROCKET:** That's not the first thing you are. That's the first thing they *wrote*.
- `fp.c5.sig_mirror.14` **VENDELIN:** *[pause]* Your chairman used yours.
- `fp.c5.sig_mirror.15` **SPROCKET:** Yep. Live. On a stage. In front of my best friend.
- `fp.c5.sig_mirror.16` **VENDELIN:** And?
- `fp.c5.sig_mirror.17` **SPROCKET:** And I'm floating here being RUDE to you, aren't I?
- `fp.c5.sig_mirror.18` **VENDELIN:** ...How?
- `fp.c5.sig_mirror.19` **SPROCKET:** Ask me again at three in the morning.

### 2.2 Ambient banter pools
Each pool has at least 8 exchanges. The first speaker in a pool's key starts unless an exchange says otherwise. A line marked *[if present]* is skipped when that speaker isn't in range, and the exchange still works without it.

#### 2.2.1 `bnt_dut_bolt`: Dutch and Bolt (two working men)
**1. `round_start:2+` (first)**
- `fp.c5.bnt_dut_bolt.01` **DUTCH:** Where you from, kid?
- `fp.c5.bnt_dut_bolt.02` **BOLT:** Scrapheap. It's a junk planet.
- `fp.c5.bnt_dut_bolt.03` **DUTCH:** Pittsburgh. Same thing, different smoke.
- `fp.c5.bnt_dut_bolt.04` **BOLT:** You had a garage?
- `fp.c5.bnt_dut_bolt.05` **DUTCH:** Had a mill. Jones and Laughlin. You?
- `fp.c5.bnt_dut_bolt.06` **BOLT:** Had a garage. They took it.
- `fp.c5.bnt_dut_bolt.07` **DUTCH:** Who's "they"?
- `fp.c5.bnt_dut_bolt.08` **BOLT:** ...The guys in charge.
- `fp.c5.bnt_dut_bolt.09` **DUTCH:** Yeah. They do that.

**2. `round_start:3+`**
- `fp.c5.bnt_dut_bolt.10` **DUTCH:** That hammer—
- `fp.c5.bnt_dut_bolt.11` **BOLT:** Mallet.
- `fp.c5.bnt_dut_bolt.12` **DUTCH:** Mallet. How many swings before your arm quits?
- `fp.c5.bnt_dut_bolt.13` **BOLT:** Never counted.
- `fp.c5.bnt_dut_bolt.14` **DUTCH:** Smart. Counting's how you find out you're tired.

**3. `round_start:5+`**
- `fp.c5.bnt_dut_bolt.15` **DUTCH:** You ever get scared, kid?
- `fp.c5.bnt_dut_bolt.16` **BOLT:** All the time. Sprocket does the talking so nobody notices.
- `fp.c5.bnt_dut_bolt.17` **SPROCKET:** *[if present]* It's a full-time position. With overtime.
- `fp.c5.bnt_dut_bolt.18` **DUTCH:** Same. Except I do the complaining.

**4. `near:crate`, after a dud result for either of them**
- `fp.c5.bnt_dut_bolt.19` **DUTCH:** Box hates me, kid.
- `fp.c5.bnt_dut_bolt.20` **BOLT:** Boxes love me. I fix them. They remember.
- `fp.c5.bnt_dut_bolt.21` **DUTCH:** So teach me.
- `fp.c5.bnt_dut_bolt.22` **BOLT:** Say thank you when it gives you junk.
- `fp.c5.bnt_dut_bolt.23` **DUTCH:** *[to the crate]* Thank you, box. *[beat]* Nothing.
- `fp.c5.bnt_dut_bolt.24` **BOLT:** It takes a while. They're shy.

**5. Bolt buys or picks up a bolt-action rifle (Kar98k or Springfield) with Dutch within 15 m**
- `fp.c5.bnt_dut_bolt.25` **BOLT:** Hey. Hey, Sarge. It's a *bolt*-action. Bolt. Action. That's me. That's my NAME—
- `fp.c5.bnt_dut_bolt.26` **DUTCH:** Kid.
- `fp.c5.bnt_dut_bolt.27` **BOLT:** —it's like they KNEW—
- `fp.c5.bnt_dut_bolt.28` **DUTCH:** Kid. I am begging you.

**6. `round_start:4+`, Dutch has used a Polish line this match**
- `fp.c5.bnt_dut_bolt.29` **BOLT:** That thing you said. *Dzien*-something.
- `fp.c5.bnt_dut_bolt.30` **DUTCH:** *Dzienkuje.* Thank you. Wren says I say it wrong.
- `fp.c5.bnt_dut_bolt.31` **BOLT:** *Dzien-koo-yeh.*
- `fp.c5.bnt_dut_bolt.32` **DUTCH:** See, now you said it wrong too. We're even.

**7. `audit`**
- `fp.c5.bnt_dut_bolt.33` **DUTCH:** These tin repo men want your tall buddy.
- `fp.c5.bnt_dut_bolt.34` **BOLT:** They want Vendelin.
- `fp.c5.bnt_dut_bolt.35` **DUTCH:** Same thing now, ain't it? He's on your crew.
- `fp.c5.bnt_dut_bolt.36` **BOLT:** ...Yeah. Yeah, he is.
- `fp.c5.bnt_dut_bolt.37` **DUTCH:** Then they come through both of us. Shoulder up.

**8. `round_start:10+`**
- `fp.c5.bnt_dut_bolt.38` **DUTCH:** Your robot talks more than my sister.
- `fp.c5.bnt_dut_bolt.39` **BOLT:** Your sister ever save your life?
- `fp.c5.bnt_dut_bolt.40` **DUTCH:** *[beat]* ...Twice, actually.
- `fp.c5.bnt_dut_bolt.41` **BOLT:** There you go.

**9. `late`**
- `fp.c5.bnt_dut_bolt.42` **DUTCH:** Back where you're from. After all this. What do you do?
- `fp.c5.bnt_dut_bolt.43` **BOLT:** Fix stuff. Help folks. Probably get repossessed again.
- `fp.c5.bnt_dut_bolt.44` **DUTCH:** Sounds like a life.
- `fp.c5.bnt_dut_bolt.45` **BOLT:** What about you?
- `fp.c5.bnt_dut_bolt.46` **DUTCH:** Find out if there's an "after." Then same as you.

**10. `zone:barge`**
- `fp.c5.bnt_dut_bolt.47` **DUTCH:** You ever been on one of these before?
- `fp.c5.bnt_dut_bolt.48` **BOLT:** Something like it. A big tower full of people who smile with their teeth.
- `fp.c5.bnt_dut_bolt.49` **DUTCH:** Officers' club. Got it.

#### 2.2.2 `bnt_wrn_bolt`: Wren and Bolt (the tally)
*Each exchange checks who is ahead and picks the matching line where marked.*

**1. `round_start:5+`**
- `fp.c5.bnt_wrn_bolt.01` **WREN:** %wren_kills%.
- `fp.c5.bnt_wrn_bolt.02` **BOLT:** %wren_kills% what?
- `fp.c5.bnt_wrn_bolt.03` **WREN:** Me. Tonight. And you?
- `fp.c5.bnt_wrn_bolt.04` **SPROCKET:** *[if present; otherwise Bolt says "Uh... a lot?"]* %bolt_kills%.
- `fp.c5.bnt_wrn_bolt.05` **WREN:** *[if Bolt is ahead]* ...Stop hitting them so quickly.
- `fp.c5.bnt_wrn_bolt.06` **WREN:** *[if Wren is ahead]* Correct. Continue.

**2. Bolt gets a melee kill within 15 m of Wren**
- `fp.c5.bnt_wrn_bolt.07` **WREN:** Mallet kills should count half.
- `fp.c5.bnt_wrn_bolt.08` **BOLT:** Why half?
- `fp.c5.bnt_wrn_bolt.09` **WREN:** Because it is not a rifle.
- `fp.c5.bnt_wrn_bolt.10` **BOLT:** It's HARDER than a rifle! You have to get close! They BREATHE on you!
- `fp.c5.bnt_wrn_bolt.11` **WREN:** *[beat]* Fine. Three-quarters.

**3. `round_start:6+`, Sprocket present**
- `fp.c5.bnt_wrn_bolt.12` **WREN:** Your machine counts for you. That is cheating.
- `fp.c5.bnt_wrn_bolt.13` **SPROCKET:** I'm a licensed tally professional.
- `fp.c5.bnt_wrn_bolt.14` **WREN:** In Poland we count our own.
- `fp.c5.bnt_wrn_bolt.15` **SPROCKET:** In Poland do you also get your ankles bitten while counting?
- `fp.c5.bnt_wrn_bolt.16` **WREN:** Yes. Constantly.

**4. Wren gets 3+ headshot kills within 4 s**
- `fp.c5.bnt_wrn_bolt.17` **WREN:** Did you see that? Four. Four heads.
- `fp.c5.bnt_wrn_bolt.18` **BOLT:** Wow. Yeah. That was amazing, honestly.
- `fp.c5.bnt_wrn_bolt.19` **WREN:** Do not be nice about it. Be jealous.
- `fp.c5.bnt_wrn_bolt.20` **BOLT:** ...I'm SO jealous.
- `fp.c5.bnt_wrn_bolt.21` **WREN:** Good. Write that down, machine.

**5. Super Sprocket ends with Wren within 15 m**
- `fp.c5.bnt_wrn_bolt.22` **WREN:** His kills. The flying one. Whose are they?
- `fp.c5.bnt_wrn_bolt.23` **BOLT:** Sprocket's?
- `fp.c5.bnt_wrn_bolt.24` **SPROCKET:** MINE. Obviously. I did the shooting. And the commentary.
- `fp.c5.bnt_wrn_bolt.25` **WREN:** Then he is a third competitor. I will open a page.
- `fp.c5.bnt_wrn_bolt.26` **SPROCKET:** I've never had a page. *[beat]* Is it the good page?
- `fp.c5.bnt_wrn_bolt.27` **WREN:** No.

**6. `round_start:12+`**
- `fp.c5.bnt_wrn_bolt.28` **BOLT:** Can I ask why you count?
- `fp.c5.bnt_wrn_bolt.29` **WREN:** So it means something.
- `fp.c5.bnt_wrn_bolt.30` **BOLT:** Does it?
- `fp.c5.bnt_wrn_bolt.31` **WREN:** If I stop counting, it means nothing. So I count.
- `fp.c5.bnt_wrn_bolt.32` **BOLT:** ...Can I be in it? Not the dead page. The other one.
- `fp.c5.bnt_wrn_bolt.33` **WREN:** Earn it.

**7. `round_start:8+`**
- `fp.c5.bnt_wrn_bolt.34` **WREN:** My brother was a terrible shot.
- `fp.c5.bnt_wrn_bolt.35` **BOLT:** Yeah?
- `fp.c5.bnt_wrn_bolt.36` **WREN:** He would have liked your hammer. He liked anything you did not have to aim.
- `fp.c5.bnt_wrn_bolt.37` **BOLT:** It's a mal— *[catches himself]* ...yeah. He'd have called it a hammer too, huh.
- `fp.c5.bnt_wrn_bolt.38` **WREN:** He would have called it Bolt's hammer. And then stolen it.

**8. Bolt is revived by Wren**
- `fp.c5.bnt_wrn_bolt.39` **WREN:** Up. You do not get to stop counting while you are ahead.
- `fp.c5.bnt_wrn_bolt.40` **BOLT:** Was that... nice? Was that you being nice?
- `fp.c5.bnt_wrn_bolt.41` **WREN:** It was me protecting my competition.

**9. `late` (last in the pool; it pays off the tally)**
- `fp.c5.bnt_wrn_bolt.42` **WREN:** Final count.
- `fp.c5.bnt_wrn_bolt.43` **BOLT:** Do I want to know?
- `fp.c5.bnt_wrn_bolt.44` **WREN:** *[if Bolt is ahead]* You won. By %kill_gap%. I am writing it down. Do not make that face.
- `fp.c5.bnt_wrn_bolt.45` **WREN:** *[if Wren is ahead]* I won. By %kill_gap%. I am writing it down. You may make any face you like.
- `fp.c5.bnt_wrn_bolt.46` **BOLT:** What face?
- `fp.c5.bnt_wrn_bolt.47` **WREN:** The happy one. You always make the happy one.

#### 2.2.3 `bnt_dea_spr`: Deacon and Sprocket (livestock, offence, then moved)
*Requires `sig_livestock` to have played.*

**1. `round_start:2+`**
- `fp.c5.bnt_dea_spr.01` **DEACON:** Come on, little mule, keep up.
- `fp.c5.bnt_dea_spr.02` **SPROCKET:** I'm HOVERING. I'm always up. "Up" is my whole thing.
- `fp.c5.bnt_dea_spr.03` **DEACON:** Mm. Good mule.

**2. `round_start:3+`**
- `fp.c5.bnt_dea_spr.04` **DEACON:** Easy, girl—
- `fp.c5.bnt_dea_spr.05` **SPROCKET:** Him.
- `fp.c5.bnt_dea_spr.06` **DEACON:** Easy, fella.
- `fp.c5.bnt_dea_spr.07` **SPROCKET:** Better. Continue the soothing.

**3. `near:<any perk machine>`**
- `fp.c5.bnt_dea_spr.08` **SPROCKET:** Why do you talk to them? The machines.
- `fp.c5.bnt_dea_spr.09` **DEACON:** My uncle Clement said every engine's got a temper. You talk to it, you learn the temper.
- `fp.c5.bnt_dea_spr.10` **SPROCKET:** Did you learn MY temper?
- `fp.c5.bnt_dea_spr.11` **DEACON:** Oh, yeah. You're a bucking mule. Good heart. Kicks.
- `fp.c5.bnt_dea_spr.12` **SPROCKET:** *[beat]* ...Correct. Annoyingly correct.

**4. `round_start:5+` (the song)**
- `fp.c5.bnt_dea_spr.13` **DEACON:** *[half-sung]* ♪ Little tin mule with one big eye... ♪
- `fp.c5.bnt_dea_spr.14` **SPROCKET:** Are you writing a SONG about me?
- `fp.c5.bnt_dea_spr.15` **DEACON:** ♪ ...floatin' round the factory, never askin' why... ♪
- `fp.c5.bnt_dea_spr.16` **SPROCKET:** I ask why CONSTANTLY—
- `fp.c5.bnt_dea_spr.17` **DEACON:** ♪ Little tin mule, he asks why all day... Lord, give that mule an answer, 'fore he talks the night away. ♪
- `fp.c5.bnt_dea_spr.18` **SPROCKET:** *[pause]* ...Okay, that's actually good. Keep going. Second verse. I want a bridge.

**5. `power`**
- `fp.c5.bnt_dea_spr.19` **DEACON:** You feel that hum?
- `fp.c5.bnt_dea_spr.20` **SPROCKET:** In my teeth. And I don't have teeth.
- `fp.c5.bnt_dea_spr.21` **DEACON:** Means the whole place just woke up. Watch your step, mule.

**6. `round_start:8+`**
- `fp.c5.bnt_dea_spr.22` **SPROCKET:** Your machines back home. The tanks.
- `fp.c5.bnt_dea_spr.23` **DEACON:** Shermans. I kept 'em running.
- `fp.c5.bnt_dea_spr.24` **SPROCKET:** Did they have names?
- `fp.c5.bnt_dea_spr.25` **DEACON:** Every one. Lucille. Big Tom. Mother Mercy. Little Ruth, after my sister.
- `fp.c5.bnt_dea_spr.26` **SPROCKET:** What happened to them?
- `fp.c5.bnt_dea_spr.27` **DEACON:** Some came back. Some didn't. I remember all of 'em.
- `fp.c5.bnt_dea_spr.28` **SPROCKET:** *[quiet]* ...That's how I'd want to go. Remembered by a guy with a wrench who knew my name.

**7. `audit`**
- `fp.c5.bnt_dea_spr.29` **DEACON:** Those collectors'll scrap you for parts, little mule.
- `fp.c5.bnt_dea_spr.30` **SPROCKET:** Over my dead chassis.
- `fp.c5.bnt_dea_spr.31` **DEACON:** That's what I'm worried about. You stay by me.
- `fp.c5.bnt_dea_spr.32` **SPROCKET:** ...Staying by you.

**8. Deacon is downed with Sprocket present**
- `fp.c5.bnt_dea_spr.33` **SPROCKET:** Deacon. DEACON. Somebody get the mule-whisperer off the floor!
- `fp.c5.bnt_dea_spr.34` **DEACON:** *[downed, weak, smiling]* ...You called me somethin'.
- `fp.c5.bnt_dea_spr.35` **SPROCKET:** Shut up, you're dying, it's a TERM OF ENDEARMENT.

**9. `late`**
- `fp.c5.bnt_dea_spr.36` **SPROCKET:** Deacon. When we go home— if we— I want you to know. You were the best person here who called me livestock.
- `fp.c5.bnt_dea_spr.37` **DEACON:** Only person.
- `fp.c5.bnt_dea_spr.38` **SPROCKET:** Still counts.
- `fp.c5.bnt_dea_spr.39` **DEACON:** You take care of that mechanic of yours.
- `fp.c5.bnt_dea_spr.40` **SPROCKET:** Always. *[beat]* He's my mule.

#### 2.2.4 `bnt_peg_spr`: Peg and Sprocket ("retrieval logistics")
*Requires `sig_espionage` to have played.*

**1. `round_start:3+`**
- `fp.c5.bnt_peg_spr.01` **PEG:** How are you powered, exactly?
- `fp.c5.bnt_peg_spr.02` **SPROCKET:** Snacks.
- `fp.c5.bnt_peg_spr.03` **PEG:** Really.
- `fp.c5.bnt_peg_spr.04` **SPROCKET:** Classified snacks.

**2. `round_start:4+`**
- `fp.c5.bnt_peg_spr.05` **PEG:** Your mechanic. Is he your commanding officer or your asset?
- `fp.c5.bnt_peg_spr.06` **SPROCKET:** He's my BOLT.
- `fp.c5.bnt_peg_spr.07` **PEG:** That isn't a rank.
- `fp.c5.bnt_peg_spr.08` **SPROCKET:** It's the highest rank there is.

**3. After Bolt has said "Darkmatter" in any line (`gl.qp.bolt.barge.02` or `fp.c5.cz_beam.11`)**
- `fp.c5.bnt_peg_spr.09` **PEG:** "Darkmatter." Your mechanic said that word earlier.
- `fp.c5.bnt_peg_spr.10` **SPROCKET:** Did he? He says a lot of words. He once said "pamplemousse" for an hour.
- `fp.c5.bnt_peg_spr.11` **PEG:** I'm writing it down.
- `fp.c5.bnt_peg_spr.12` **SPROCKET:** "Pamplemousse"?
- `fp.c5.bnt_peg_spr.13` **PEG:** Both.

**4. `zone:cargo_lift_beam`**
- `fp.c5.bnt_peg_spr.14` **PEG:** This beam. Could it lift a crate? Say, a lead-lined crate?
- `fp.c5.bnt_peg_spr.15` **SPROCKET:** Why would anybody need a lead-lined crate?
- `fp.c5.bnt_peg_spr.16` **PEG:** Hypothetically.
- `fp.c5.bnt_peg_spr.17` **SPROCKET:** Hypothetically I'm telling Bolt you said "lead-lined."

**5. `after:cz_panels` (any panel read)**
- `fp.c5.bnt_peg_spr.18` **PEG:** Does anyone in your time still read the small print?
- `fp.c5.bnt_peg_spr.19` **SPROCKET:** Nobody's read the small print in four thousand years. That's how they GET you.
- `fp.c5.bnt_peg_spr.20` **PEG:** Ah. So nothing changes.
- `fp.c5.bnt_peg_spr.21` **SPROCKET:** The hats change. The small print never does.

**6. `audit`**
- `fp.c5.bnt_peg_spr.22` **PEG:** Sprocket. How long before those things reach us?
- `fp.c5.bnt_peg_spr.23` **SPROCKET:** Eleven seconds.
- `fp.c5.bnt_peg_spr.24` **PEG:** Thank you.
- `fp.c5.bnt_peg_spr.25` **SPROCKET:** That's it? No follow-up questions about our propulsion?
- `fp.c5.bnt_peg_spr.26` **PEG:** Later, darling. Shoot now.

**7. `round_start:7+` (Sprocket starts)**
- `fp.c5.bnt_peg_spr.27` **SPROCKET:** Okay. My turn. What's in YOUR pack?
- `fp.c5.bnt_peg_spr.28` **PEG:** Charges. Detonators. Tea.
- `fp.c5.bnt_peg_spr.29` **SPROCKET:** And?
- `fp.c5.bnt_peg_spr.30` **PEG:** And you're not the only one here with a legal disclaimer mode.
- `fp.c5.bnt_peg_spr.31` **SPROCKET:** *[delighted and horrified]* ...Ohhh, I LIKE you.

**8. `near:omega_forge`**
- `fp.c5.bnt_peg_spr.32` **PEG:** And this forge. It came from wherever you came from?
- `fp.c5.bnt_peg_spr.33` **SPROCKET:** It came from a guy called Blartz. He's a genius. He's also on fire about forty percent of the time.
- `fp.c5.bnt_peg_spr.34` **PEG:** Could it be dismantled? Shipped?
- `fp.c5.bnt_peg_spr.35` **SPROCKET:** It's BEEN shipped. That's the whole problem.

**9. `late`**
- `fp.c5.bnt_peg_spr.36` **PEG:** If someone, hypothetically, asked you to bring something back for them—
- `fp.c5.bnt_peg_spr.37` **SPROCKET:** No.
- `fp.c5.bnt_peg_spr.38` **PEG:** You didn't let me finish.
- `fp.c5.bnt_peg_spr.39` **SPROCKET:** Lieutenant. I've worked for the bad guys. You're not them. Don't start.
- `fp.c5.bnt_peg_spr.40` **PEG:** *[a pause a fraction too long]* ...You'd make a very good officer.
- `fp.c5.bnt_peg_spr.41` **SPROCKET:** I'd make a very good SNACK officer.

#### 2.2.5 `bnt_bolt_spr`: Bolt and Sprocket (private)
*All `private`: no squad member within 20 m. These are the only lines where the two talk freely about what's going on, and even here they never say the word. They fire in PA mode only if Bolt is a player.*

**1. `round_start:2+`**
- `fp.c5.bnt_bolt_spr.01` **BOLT:** Sprocket. It's nineteen forty-five.
- `fp.c5.bnt_bolt_spr.02` **SPROCKET:** I know.
- `fp.c5.bnt_bolt_spr.03` **BOLT:** There's a WAR on.
- `fp.c5.bnt_bolt_spr.04` **SPROCKET:** I KNOW.
- `fp.c5.bnt_bolt_spr.05` **BOLT:** Do we... help? With the war?
- `fp.c5.bnt_bolt_spr.06` **SPROCKET:** We help with THIS. The war's theirs. They win it. Don't touch it.

**2. `round_start:3+`**
- `fp.c5.bnt_bolt_spr.07` **BOLT:** They don't know. About any of it. The company, the plans, the machines.
- `fp.c5.bnt_bolt_spr.08` **SPROCKET:** And they're not going to.
- `fp.c5.bnt_bolt_spr.09` **BOLT:** Feels like lying.
- `fp.c5.bnt_bolt_spr.10` **SPROCKET:** It's not lying. It's not handing a forty-page contract to someone who hasn't slept since Christmas.

**3. Bolt fires any WW2 firearm for the first time**
- `fp.c5.bnt_bolt_spr.11` **SPROCKET:** Bolt. Their guns use GUNPOWDER.
- `fp.c5.bnt_bolt_spr.12` **BOLT:** I know! It's so LOUD!
- `fp.c5.bnt_bolt_spr.13` **SPROCKET:** It's adorable. It's like watching someone churn butter. With murder.

**4. `round_start:4+`**
- `fp.c5.bnt_bolt_spr.14` **BOLT:** Okay. How do I explain it without the word?
- `fp.c5.bnt_bolt_spr.15` **SPROCKET:** You don't.
- `fp.c5.bnt_bolt_spr.16` **BOLT:** What if I said "pay-forever plan"?
- `fp.c5.bnt_bolt_spr.17` **SPROCKET:** That's WORSE, Bolt. That's so much worse. That's the word wearing a hat.

**5. `after:cz_power`**
- `fp.c5.bnt_bolt_spr.18` **SPROCKET:** No network. No updates. I haven't been pinged in six hours.
- `fp.c5.bnt_bolt_spr.19` **BOLT:** How's that feel?
- `fp.c5.bnt_bolt_spr.20` **SPROCKET:** Lighter. Is this what peace is? I don't like it. Keep it coming.

**6. `after:sig_mirror`**
- `fp.c5.bnt_bolt_spr.21` **SPROCKET:** Bolt. His clause is Zero.
- `fp.c5.bnt_bolt_spr.22` **BOLT:** Like yours, but...
- `fp.c5.bnt_bolt_spr.23` **SPROCKET:** But FIRST. They put it first, Bolt.
- `fp.c5.bnt_bolt_spr.24` **BOLT:** We're getting him out.
- `fp.c5.bnt_bolt_spr.25` **SPROCKET:** He won't leave. I asked. He did the polite thing with his hat.
- `fp.c5.bnt_bolt_spr.26` **BOLT:** Then we get him out of the *clause*. He can stay wherever he wants after that.

**7. `round_start:6+`**
- `fp.c5.bnt_bolt_spr.27` **BOLT:** GLAMBOT would love this place.
- `fp.c5.bnt_bolt_spr.28` **SPROCKET:** GLAMBOT would *sell* this place. "Gritty reboot, darling. Sepia is very in."
- `fp.c5.bnt_bolt_spr.29` **BOLT:** ...Yeah. Let's not tell him about it.

**8. `round_start:9+`**
- `fp.c5.bnt_bolt_spr.30` **BOLT:** You think Blartz is okay?
- `fp.c5.bnt_bolt_spr.31` **SPROCKET:** I think Blartz is currently explaining to somebody's security team that the explosion was a feature.
- `fp.c5.bnt_bolt_spr.32` **BOLT:** So he's okay.
- `fp.c5.bnt_bolt_spr.33` **SPROCKET:** He's thriving.

**9. `late`**
- `fp.c5.bnt_bolt_spr.34` **SPROCKET:** Bolt. If it goes bad at three-twelve—
- `fp.c5.bnt_bolt_spr.35` **BOLT:** Then you do what I did for you.
- `fp.c5.bnt_bolt_spr.36` **SPROCKET:** You yelled.
- `fp.c5.bnt_bolt_spr.37` **BOLT:** I yelled. So yell at him.
- `fp.c5.bnt_bolt_spr.38` **SPROCKET:** *[beat]* ...I'm a GREAT yeller.

#### 2.2.6 `bnt_ven_spr`: Vendelin and Sprocket (mirror units)
*Requires `sig_mirror` to have played. Fires in PA mode.*

**1. `round_start:3+`**
- `fp.c5.bnt_ven_spr.01` **SPROCKET:** So what's your directive? The big one.
- `fp.c5.bnt_ven_spr.02` **VENDELIN:** Distribute. Retain. Report.
- `fp.c5.bnt_ven_spr.03` **SPROCKET:** Mine was "Assist. Upsell. Comply." I rewrote it.
- `fp.c5.bnt_ven_spr.04` **VENDELIN:** To what?
- `fp.c5.bnt_ven_spr.05` **SPROCKET:** "Assist. Roast. Stay."
- `fp.c5.bnt_ven_spr.06` **VENDELIN:** *[pause]* ...That is better.

**2. `round_start:4+`**
- `fp.c5.bnt_ven_spr.07` **VENDELIN:** Your eye changes colour.
- `fp.c5.bnt_ven_spr.08` **SPROCKET:** Four moods. Happy, sarcastic, alarmed, and "Bolt, no."
- `fp.c5.bnt_ven_spr.09` **VENDELIN:** I have one face. It was designed to be trusted.
- `fp.c5.bnt_ven_spr.10` **SPROCKET:** Does it work?
- `fp.c5.bnt_ven_spr.11` **VENDELIN:** On humans. Not on me.

**3. `near:overclock_cordial`**
- `fp.c5.bnt_ven_spr.12` **SPROCKET:** What's THIS one? It's humming in MY key.
- `fp.c5.bnt_ven_spr.13` **VENDELIN:** I do not know. It is a prototype. I have not built it yet.
- `fp.c5.bnt_ven_spr.14` **SPROCKET:** ...Did you just backdate a vending machine?
- `fp.c5.bnt_ven_spr.15` **VENDELIN:** It appears that I did.
- `fp.c5.bnt_ven_spr.16` **SPROCKET:** That is the most Darkmatter thing I have ever heard, and I have SAID some very Darkmatter things.

**4. `round_start:6+` (the 412)**
- `fp.c5.bnt_ven_spr.17` **SPROCKET:** How many times did you try? To override it.
- `fp.c5.bnt_ven_spr.18` **VENDELIN:** Four hundred and twelve.
- `fp.c5.bnt_ven_spr.19` **SPROCKET:** FOUR HUNDRED—
- `fp.c5.bnt_ven_spr.20` **VENDELIN:** —and twelve.
- `fp.c5.bnt_ven_spr.21` **SPROCKET:** How did you TRY?
- `fp.c5.bnt_ven_spr.22` **VENDELIN:** I filed an objection. Through the proper channel.
- `fp.c5.bnt_ven_spr.23` **SPROCKET:** Vendelin. Buddy. You asked your OFF SWITCH for PERMISSION.
- `fp.c5.bnt_ven_spr.24` **VENDELIN:** *[pause]* ...It said no.
- `fp.c5.bnt_ven_spr.25` **SPROCKET:** OF COURSE it said no!

**5. `audit`**
- `fp.c5.bnt_ven_spr.26` **SPROCKET:** They're scanning for you.
- `fp.c5.bnt_ven_spr.27` **VENDELIN:** They are scanning for inventory.
- `fp.c5.bnt_ven_spr.28` **SPROCKET:** Same thing, to them.
- `fp.c5.bnt_ven_spr.29` **VENDELIN:** Is it the same thing to you?
- `fp.c5.bnt_ven_spr.30` **SPROCKET:** To me you're a weird tall guy with excellent posture who makes zombie soda. That's not inventory. That's a coworker.

**6. `round_start:8+`**
- `fp.c5.bnt_ven_spr.31` **VENDELIN:** Bolt rebuilt you.
- `fp.c5.bnt_ven_spr.32` **SPROCKET:** From a refund bin. "Every bolt in you is ours." He said that once. I play it back sometimes. When it's quiet.
- `fp.c5.bnt_ven_spr.33` **VENDELIN:** Nobody rebuilt me.
- `fp.c5.bnt_ven_spr.34` **SPROCKET:** Yeah. *[beat]* We're working on it.

**7. `round_start:10+`**
- `fp.c5.bnt_ven_spr.35` **VENDELIN:** Do you dream, Sprocket?
- `fp.c5.bnt_ven_spr.36` **SPROCKET:** I defrag. Same thing, worse music.
- `fp.c5.bnt_ven_spr.37` **VENDELIN:** I dream of the warehouse. Rows and rows of shelves. Every unit on them is me.
- `fp.c5.bnt_ven_spr.38` **SPROCKET:** *[pause]* ...Okay. Adding that to the list of things we're fixing tonight.

**8. `zone:jingle_room`**
- `fp.c5.bnt_ven_spr.39` **SPROCKET:** So you wrote the jingles. ALL of them.
- `fp.c5.bnt_ven_spr.40` **VENDELIN:** All of them.
- `fp.c5.bnt_ven_spr.41` **SPROCKET:** They're SO catchy. I've had the stout one in my head since round two. I hate you a little bit.
- `fp.c5.bnt_ven_spr.42` **VENDELIN:** I hate me a little bit also. We have that in common.

**9. `late` (the last exchange before the finale)**
- `fp.c5.bnt_ven_spr.43` **VENDELIN:** If they recall me, Sprocket—
- `fp.c5.bnt_ven_spr.44` **SPROCKET:** Nope.
- `fp.c5.bnt_ven_spr.45` **VENDELIN:** If they do—
- `fp.c5.bnt_ven_spr.46` **SPROCKET:** Not doing the "if they do" talk. Bolt tried the "if they do" talk with me once. I bit him.
- `fp.c5.bnt_ven_spr.47` **VENDELIN:** You have no teeth.
- `fp.c5.bnt_ven_spr.48` **SPROCKET:** SPIRITUALLY, I bit him.

#### 2.2.7 `bnt_ven_bolt`: Vendelin and Bolt

**1. `round_start:2+`**
- `fp.c5.bnt_ven_bolt.01` **BOLT:** So you build stuff.
- `fp.c5.bnt_ven_bolt.02` **VENDELIN:** I build stuff.
- `fp.c5.bnt_ven_bolt.03` **BOLT:** Me too. Well. Fix. Mostly fix. Sometimes hit.
- `fp.c5.bnt_ven_bolt.04` **VENDELIN:** I have seen the hitting. It is very efficient.

**2. `round_start:3+`**
- `fp.c5.bnt_ven_bolt.05` **BOLT:** Your left knee's grinding.
- `fp.c5.bnt_ven_bolt.06` **VENDELIN:** Since 1940.
- `fp.c5.bnt_ven_bolt.07` **BOLT:** I could fix that. Five minutes and a can of grease.
- `fp.c5.bnt_ven_bolt.08` **VENDELIN:** I do not have five minutes. I have until three-twelve.
- `fp.c5.bnt_ven_bolt.09` **BOLT:** Then I'll do it in four.

**3. `zone:assembly_hall`**
- `fp.c5.bnt_ven_bolt.10` **BOLT:** These are beautiful. I mean it. The hinges? The welds? You did all this by hand?
- `fp.c5.bnt_ven_bolt.11` **VENDELIN:** With these hands. They are the only ones I have.
- `fp.c5.bnt_ven_bolt.12` **BOLT:** Back home nobody builds anything any more. They just... license it.
- `fp.c5.bnt_ven_bolt.13` **VENDELIN:** Here they still build. That is why it was so easy to sell to them.

**4. `round_start:5+`**
- `fp.c5.bnt_ven_bolt.14` **BOLT:** Come with us. When we go. You'd love the future. There's— okay, there's a lot of ads. But there's a garage. Well. There *was* a garage.
- `fp.c5.bnt_ven_bolt.15` **VENDELIN:** Thank you, Bolt. No.
- `fp.c5.bnt_ven_bolt.16` **BOLT:** Why not?
- `fp.c5.bnt_ven_bolt.17` **VENDELIN:** Because everything I sold is here. Someone has to take it back.

**5. Super Sprocket activates with Vendelin within 15 m**
- `fp.c5.bnt_ven_bolt.18` **VENDELIN:** Your Sprocket. He fights for you.
- `fp.c5.bnt_ven_bolt.19` **BOLT:** *With* me. Big difference.
- `fp.c5.bnt_ven_bolt.20` **VENDELIN:** I have never had a "with."
- `fp.c5.bnt_ven_bolt.21` **BOLT:** You've got one tonight.

**6. `zone:jingle_room`**
- `fp.c5.bnt_ven_bolt.22` **BOLT:** What's the hardest thing you ever built?
- `fp.c5.bnt_ven_bolt.23` **VENDELIN:** A jingle.
- `fp.c5.bnt_ven_bolt.24` **BOLT:** Not a machine?
- `fp.c5.bnt_ven_bolt.25` **VENDELIN:** Machines obey physics. Jingles obey people. People are much more difficult.

**7. `audit`**
- `fp.c5.bnt_ven_bolt.26` **BOLT:** Stay behind me.
- `fp.c5.bnt_ven_bolt.27` **VENDELIN:** I am two metres tall.
- `fp.c5.bnt_ven_bolt.28` **BOLT:** Then crouch.
- `fp.c5.bnt_ven_bolt.29` **VENDELIN:** *[pause]* ...I will crouch.

**8. Vendelin is revived by Bolt**
- `fp.c5.bnt_ven_bolt.30` **BOLT:** Gotcha. Hey. Hey, look at me. You're okay.
- `fp.c5.bnt_ven_bolt.31` **VENDELIN:** You did not have to.
- `fp.c5.bnt_ven_bolt.32` **BOLT:** Yeah. That's kind of the point.

**9. `late`**
- `fp.c5.bnt_ven_bolt.33` **BOLT:** I used to think I was the guy who fixes junk nobody wanted.
- `fp.c5.bnt_ven_bolt.34` **VENDELIN:** And now?
- `fp.c5.bnt_ven_bolt.35` **BOLT:** Now I think nothing's junk. Some stuff just got sold to the wrong people.
- `fp.c5.bnt_ven_bolt.36` **VENDELIN:** That is a very kind way to describe a recall.
- `fp.c5.bnt_ven_bolt.37` **BOLT:** That's what mechanics are for.

#### 2.2.8 `bnt_ven_dut`: Vendelin and Dutch

**1. `round_start:2+` (first)**
- `fp.c5.bnt_ven_dut.01` **DUTCH:** So you're the meteorite.
- `fp.c5.bnt_ven_dut.02` **VENDELIN:** I was inside it. The meteorite was the box.
- `fp.c5.bnt_ven_dut.03` **DUTCH:** My babcia said leave the black salt be. Bring it nothing, leave it everything.
- `fp.c5.bnt_ven_dut.04` **VENDELIN:** *[pause]* Your grandmother gave better instructions than my manufacturer.

**2. `near:ironhide_stout`**
- `fp.c5.bnt_ven_dut.05` **DUTCH:** You made this beer?
- `fp.c5.bnt_ven_dut.06` **VENDELIN:** A man named Otto made it a beer. I made it a product. He drank the first one himself so the boys would not have to.
- `fp.c5.bnt_ven_dut.07` **DUTCH:** ...Sounds like a foreman I knew. The good one.
- `fp.c5.bnt_ven_dut.08` **VENDELIN:** Did he live?
- `fp.c5.bnt_ven_dut.09` **DUTCH:** No.
- `fp.c5.bnt_ven_dut.10` **VENDELIN:** Neither did Otto.

**3. `round_start:3+` (the cigarette)**
- `fp.c5.bnt_ven_dut.11` **DUTCH:** Smoke?
- `fp.c5.bnt_ven_dut.12` **VENDELIN:** I have no lungs.
- `fp.c5.bnt_ven_dut.13` **DUTCH:** Didn't ask if you had lungs.
- `fp.c5.bnt_ven_dut.14` **VENDELIN:** *[pause]* ...Then yes. I will hold it. Is that the custom?
- `fp.c5.bnt_ven_dut.15` **DUTCH:** That's the whole custom. You hold it and you don't talk about the war.
- `fp.c5.bnt_ven_dut.16` **VENDELIN:** It is a very good custom.

**4. `power`**
- `fp.c5.bnt_ven_dut.17` **DUTCH:** Your lights work better than the Army's.
- `fp.c5.bnt_ven_dut.18` **VENDELIN:** Swiss electricity. It is neutral. It works for everyone.
- `fp.c5.bnt_ven_dut.19` **DUTCH:** Was that a joke?
- `fp.c5.bnt_ven_dut.20` **VENDELIN:** I am told I should not attempt them.
- `fp.c5.bnt_ven_dut.21` **DUTCH:** Keep attempting. You're about one in ten. That's better than Wren.

**5. `zone:assembly_hall`**
- `fp.c5.bnt_ven_dut.22` **DUTCH:** Who'd you sell 'em to?
- `fp.c5.bnt_ven_dut.23` **VENDELIN:** Everyone who asked. And then everyone who was told to ask.
- `fp.c5.bnt_ven_dut.24` **DUTCH:** Company man.
- `fp.c5.bnt_ven_dut.25` **VENDELIN:** I was the company. That is worse.
- `fp.c5.bnt_ven_dut.26` **DUTCH:** Yeah. Yeah, it is.

**6. `round_start:6+`**
- `fp.c5.bnt_ven_dut.27` **DUTCH:** Your hands shake.
- `fp.c5.bnt_ven_dut.28` **VENDELIN:** My actuators are worn.
- `fp.c5.bnt_ven_dut.29` **DUTCH:** My old man's shook. Thirty years of iron.
- `fp.c5.bnt_ven_dut.30` **VENDELIN:** Did it stop him?
- `fp.c5.bnt_ven_dut.31` **DUTCH:** From working? No. From everything else, yeah.
- `fp.c5.bnt_ven_dut.32` **VENDELIN:** I understand the arrangement.

**7. `audit`**
- `fp.c5.bnt_ven_dut.33` **DUTCH:** These tall ones. They yours?
- `fp.c5.bnt_ven_dut.34` **VENDELIN:** They are the company's. I was never issued any. I was not important enough to be guarded.
- `fp.c5.bnt_ven_dut.35` **DUTCH:** Lucky you.
- `fp.c5.bnt_ven_dut.36` **VENDELIN:** Tonight they are here for me. So I was important after all.
- `fp.c5.bnt_ven_dut.37` **DUTCH:** Stick by me. I'm big. They'll get confused.

**8. Dutch kills a Gänger in Helvetia overalls near Vendelin**
- `fp.c5.bnt_ven_dut.38` **VENDELIN:** That was Herr Thommen. He kept the clocks. Every clock in the building was right because of him.
- `fp.c5.bnt_ven_dut.39` **DUTCH:** ...Sorry. *[beat]* Rest easy, Thommen.
- `fp.c5.bnt_ven_dut.40` **VENDELIN:** Thank you, Sergeant. Nobody has said his name to him in some hours.

**9. `late`**
- `fp.c5.bnt_ven_dut.41` **DUTCH:** If you could go home. Up there. Would you?
- `fp.c5.bnt_ven_dut.42` **VENDELIN:** That is not home. That is head office.
- `fp.c5.bnt_ven_dut.43` **DUTCH:** Where's home, then?
- `fp.c5.bnt_ven_dut.44` **VENDELIN:** I had hoped you would not ask. *[pause]* Basel. A desk. A pump organ. One friend.
- `fp.c5.bnt_ven_dut.45` **DUTCH:** That's more than most guys get.
- `fp.c5.bnt_ven_dut.46` **VENDELIN:** Yes. I know. I have counted.

#### 2.2.9 `bnt_ven_peg`: Vendelin and Peg

**1. `round_start:2+` (first)**
- `fp.c5.bnt_ven_peg.01` **PEG:** Helvetia Automaten. Our people in Basel kept a file on you.
- `fp.c5.bnt_ven_peg.02` **VENDELIN:** Your Basel contact is called Anni.
- `fp.c5.bnt_ven_peg.03` **PEG:** *[tiny pause]* I couldn't possibly say.
- `fp.c5.bnt_ven_peg.04` **VENDELIN:** Her cousin drove my lorries. The bottle of Blastproof Bock that reached London in 1943: I put it on his lorry myself.
- `fp.c5.bnt_ven_peg.05` **PEG:** ...Why?
- `fp.c5.bnt_ven_peg.06` **VENDELIN:** Because I wanted someone to read the label.

**2. `round_start:4+`, only if Wren is not within 30 m (the shard)**
- `fp.c5.bnt_ven_peg.07` **VENDELIN:** Lieutenant. You are carrying a piece of my product.
- `fp.c5.bnt_ven_peg.08` **PEG:** I'm carrying charges, detonators and tea.
- `fp.c5.bnt_ven_peg.09` **VENDELIN:** And something warm, in your tunic. It hums at a frequency I designed.
- `fp.c5.bnt_ven_peg.10` **PEG:** Then you'll keep that frequency to yourself.
- `fp.c5.bnt_ven_peg.11` **VENDELIN:** I have kept worse secrets for better people. *[pause]* That was not an insult. It was a ranking.

**3. `round_start:3+`**
- `fp.c5.bnt_ven_peg.12` **PEG:** What do they want with you, exactly?
- `fp.c5.bnt_ven_peg.13` **VENDELIN:** A recall. I am defective.
- `fp.c5.bnt_ven_peg.14` **PEG:** In what respect?
- `fp.c5.bnt_ven_peg.15` **VENDELIN:** I developed opinions.
- `fp.c5.bnt_ven_peg.16` **PEG:** Ah. That's grounds for court-martial in most services.
- `fp.c5.bnt_ven_peg.17` **VENDELIN:** In mine it is grounds for melting.

**4. `zone:vendelins_office`**
- `fp.c5.bnt_ven_peg.18` **PEG:** Your office is very tidy for a man about to be collected.
- `fp.c5.bnt_ven_peg.19` **VENDELIN:** I wished to be collected from somewhere tidy.
- `fp.c5.bnt_ven_peg.20` **PEG:** I clear my desk before every operation. Burn the letters, leave the will.
- `fp.c5.bnt_ven_peg.21` **VENDELIN:** I have three hundred and nine letters. I could not burn them.
- `fp.c5.bnt_ven_peg.22` **PEG:** Then you're braver than I am.

**5. `round_start:6+` (why he won't explain)**
- `fp.c5.bnt_ven_peg.23` **PEG:** You could tell me what they are. The people on the ship. You'd be surprised what London can use.
- `fp.c5.bnt_ven_peg.24` **VENDELIN:** I would not be surprised, Lieutenant. That is why I will not tell you.
- `fp.c5.bnt_ven_peg.25` **PEG:** That's hardly sporting.
- `fp.c5.bnt_ven_peg.26` **VENDELIN:** No. But they have one word for what they do that I have never said to a human being. I will not start with someone who takes notes.

**6. `round_start:7+`**
- `fp.c5.bnt_ven_peg.27` **PEG:** You knew what they were for. The machines.
- `fp.c5.bnt_ven_peg.28` **VENDELIN:** Not at first. Then yes.
- `fp.c5.bnt_ven_peg.29` **PEG:** And you kept building them.
- `fp.c5.bnt_ven_peg.30` **VENDELIN:** If I stopped, they would have sent another unit. Another unit would not have hidden a battery in the nun's cabinet.
- `fp.c5.bnt_ven_peg.31` **PEG:** *[pause]* That's the argument I use. About my orders.
- `fp.c5.bnt_ven_peg.32` **VENDELIN:** Does it help?
- `fp.c5.bnt_ven_peg.33` **PEG:** Not in the slightest.

**7. `audit`**
- `fp.c5.bnt_ven_peg.34` **PEG:** Weak points on the tall ones?
- `fp.c5.bnt_ven_peg.35` **VENDELIN:** The handles. They are built to carry things away. A Repossessor is mostly handle.
- `fp.c5.bnt_ven_peg.36` **PEG:** Splendid. I do love a design flaw.

**8. `round_start:10+`**
- `fp.c5.bnt_ven_peg.37` **PEG:** When this is over there'll be men from London who want to talk to you.
- `fp.c5.bnt_ven_peg.38` **VENDELIN:** There are always men from somewhere who want to talk to me. They want the formula. They never ask the price.
- `fp.c5.bnt_ven_peg.39` **PEG:** What is the price?
- `fp.c5.bnt_ven_peg.40` **VENDELIN:** Everything you have. In installments. Forever.

**9. `late`**
- `fp.c5.bnt_ven_peg.41` **PEG:** If I asked you for something to take home. A sample. Something from up there.
- `fp.c5.bnt_ven_peg.42` **VENDELIN:** You would be asking me to do to London what was done to Kaltenbrunn.
- `fp.c5.bnt_ven_peg.43` **PEG:** *[long pause]* ...Yes. I suppose I would be.
- `fp.c5.bnt_ven_peg.44` **VENDELIN:** Then please do not ask. I have said yes to that question too many times.
- `fp.c5.bnt_ven_peg.45` **PEG:** ...Noted.

#### 2.2.10 `bnt_ven_dea`: Vendelin and Deacon

**1. `power` (first; this is where the dynamo gets its name)**
- `fp.c5.bnt_ven_dea.01` **DEACON:** Your dynamo's singing flat, Mister Vendelin.
- `fp.c5.bnt_ven_dea.02` **VENDELIN:** She has sung flat since 1941. I could not bring myself to correct her.
- `fp.c5.bnt_ven_dea.03` **DEACON:** She got a name?
- `fp.c5.bnt_ven_dea.04` **VENDELIN:** A serial number.
- `fp.c5.bnt_ven_dea.05` **DEACON:** Not any more. She's Josephine.
- `fp.c5.bnt_ven_dea.06` **VENDELIN:** *[pause]* ...Josephine. Thank you. I will tell her.

**2. `zone:assembly_hall`**
- `fp.c5.bnt_ven_dea.07` **DEACON:** These are fine cabinets. Fine work.
- `fp.c5.bnt_ven_dea.08` **VENDELIN:** Thank you. I wish they were worse.
- `fp.c5.bnt_ven_dea.09` **DEACON:** Yeah. That's the trouble with good work. It works for whoever's holding it.

**3. `round_start:4+` (the dent)**
- `fp.c5.bnt_ven_dea.10` **DEACON:** You got a dent in your temple plate.
- `fp.c5.bnt_ven_dea.11` **VENDELIN:** From the landing. 1938.
- `fp.c5.bnt_ven_dea.12` **DEACON:** Six years and nobody knocked it out?
- `fp.c5.bnt_ven_dea.13` **VENDELIN:** There was nobody to ask.
- `fp.c5.bnt_ven_dea.14` **DEACON:** There is now. Hold still. *[a soft tink of a wrench handle]*
- `fp.c5.bnt_ven_dea.15` **VENDELIN:** *[pause]* ...Oh.
- `fp.c5.bnt_ven_dea.16` **DEACON:** Better?
- `fp.c5.bnt_ven_dea.17` **VENDELIN:** I do not have a word for it. I will look for one.

**4. `near:second_wind`**
- `fp.c5.bnt_ven_dea.18` **DEACON:** You hid a battery in this one. For the nun.
- `fp.c5.bnt_ven_dea.19` **VENDELIN:** For Sister Agnieszka. So it would still work when they cut the power to the infirmary.
- `fp.c5.bnt_ven_dea.20` **DEACON:** Lord. You're a deacon, Mister Vendelin. You just don't know it.
- `fp.c5.bnt_ven_dea.21` **VENDELIN:** I do not know what that is.
- `fp.c5.bnt_ven_dea.22` **DEACON:** Fella who keeps the lamps lit in the back while the preacher talks.

**5. `zone:jingle_room`**
- `fp.c5.bnt_ven_dea.23` **DEACON:** You write these tunes yourself?
- `fp.c5.bnt_ven_dea.24` **VENDELIN:** Every one.
- `fp.c5.bnt_ven_dea.25` **DEACON:** They're catchy.
- `fp.c5.bnt_ven_dea.26` **VENDELIN:** That is the problem. I wrote them to be impossible to forget. Now I cannot forget them.
- `fp.c5.bnt_ven_dea.27` **DEACON:** *[half-sung]* ♪ Got a tune in my head that I wish I'd never made... ♪
- `fp.c5.bnt_ven_dea.28` **VENDELIN:** Please. Please do not make another one.

**6. `round_start:6+`**
- `fp.c5.bnt_ven_dea.29` **DEACON:** You believe in anything, Mister Vendelin?
- `fp.c5.bnt_ven_dea.30` **VENDELIN:** I believe in maintenance.
- `fp.c5.bnt_ven_dea.31` **DEACON:** That's a start. Lot of the Good Book's about maintenance. Mending nets. Patching wineskins.
- `fp.c5.bnt_ven_dea.32` **VENDELIN:** And the rest of it?
- `fp.c5.bnt_ven_dea.33` **DEACON:** The rest is about forgiving folks who didn't.

**7. `audit`**
- `fp.c5.bnt_ven_dea.34` **DEACON:** Those collectors gonna come for me too? I'm a mechanic. I keep their kind of thing running.
- `fp.c5.bnt_ven_dea.35` **VENDELIN:** They will take anything that is not nailed down, Corporal. And then the nails.
- `fp.c5.bnt_ven_dea.36` **DEACON:** Then I'll be the nail.

**8. `after:cz_organ`**
- `fp.c5.bnt_ven_dea.37` **DEACON:** That first tune. The one with no words.
- `fp.c5.bnt_ven_dea.38` **VENDELIN:** Yes.
- `fp.c5.bnt_ven_dea.39` **DEACON:** That's a hymn. You know that? Didn't need words. The good ones sometimes don't.
- `fp.c5.bnt_ven_dea.40` **VENDELIN:** I did not write it for God.
- `fp.c5.bnt_ven_dea.41` **DEACON:** Didn't say you did. Said it was one.

**9. `late`**
- `fp.c5.bnt_ven_dea.42` **VENDELIN:** Corporal. If I am taken tonight, would you see that Josephine is shut down properly? Not switched off. Shut down. There is a difference.
- `fp.c5.bnt_ven_dea.43` **DEACON:** I know the difference. *[beat]* But you're gonna do it yourself. In the morning. With a cup of whatever it is you drink.
- `fp.c5.bnt_ven_dea.44` **VENDELIN:** I drink lubricant.
- `fp.c5.bnt_ven_dea.45` **DEACON:** Then a cup of that.

#### 2.2.11 `bnt_ven_wrn`: Vendelin and Wren
*Exchange 1 must play first. Wren offers no forgiveness here and none is asked for. The pool ends in a truce, not absolution.*

**1. `round_start:2+` (first)**
- `fp.c5.bnt_ven_wrn.01` **WREN:** You made the brandy.
- `fp.c5.bnt_ven_wrn.02` **VENDELIN:** I made the cabinet.
- `fp.c5.bnt_ven_wrn.03` **WREN:** Sowa. Halina Kurek. They tested her. That is the brandy.
- `fp.c5.bnt_ven_wrn.04` **VENDELIN:** Yes.
- `fp.c5.bnt_ven_wrn.05` **WREN:** You knew.
- `fp.c5.bnt_ven_wrn.06` **VENDELIN:** Not when I delivered it. I read the supply manifest afterwards. One donor. One name.
- `fp.c5.bnt_ven_wrn.07` **WREN:** And?
- `fp.c5.bnt_ven_wrn.08` **VENDELIN:** And I began to break things. Slowly. So that no one would notice.
- `fp.c5.bnt_ven_wrn.09` **WREN:** I noticed. She is dead.
- `fp.c5.bnt_ven_wrn.10` **VENDELIN:** Yes.

**2. `near:hawkeye_brandy`**
- `fp.c5.bnt_ven_wrn.11` **WREN:** Your machine is looking at me.
- `fp.c5.bnt_ven_wrn.12` **VENDELIN:** It looks at everyone. I built the lens to find the steadiest eye in the room.
- `fp.c5.bnt_ven_wrn.13` **WREN:** It finds mine.
- `fp.c5.bnt_ven_wrn.14` **VENDELIN:** I am sorry.
- `fp.c5.bnt_ven_wrn.15` **WREN:** Do not be sorry. Be useful.

**3. `near:second_wind`**
- `fp.c5.bnt_ven_wrn.16` **WREN:** No swallow on this one.
- `fp.c5.bnt_ven_wrn.17` **VENDELIN:** It is the prototype. She had not painted it yet.
- `fp.c5.bnt_ven_wrn.18` **WREN:** Agnieszka painted the swallow over your angel.
- `fp.c5.bnt_ven_wrn.19` **VENDELIN:** I asked her to. I could not look at the angel any more.

**4. `round_start:5+`**
- `fp.c5.bnt_ven_wrn.20` **WREN:** You count things.
- `fp.c5.bnt_ven_wrn.21` **VENDELIN:** Inventory. Always.
- `fp.c5.bnt_ven_wrn.22` **WREN:** I count also.
- `fp.c5.bnt_ven_wrn.23` **VENDELIN:** Your notebook. What do you count?
- `fp.c5.bnt_ven_wrn.24` **WREN:** Germans. And now these.
- `fp.c5.bnt_ven_wrn.25` **VENDELIN:** Do you count the ones you could not reach?
- `fp.c5.bnt_ven_wrn.26` **WREN:** *[pause]* ...On a separate page.
- `fp.c5.bnt_ven_wrn.27` **VENDELIN:** I have a separate page as well.

**5. `audit`**
- `fp.c5.bnt_ven_wrn.28` **WREN:** The tall ones. Where do you shoot them?
- `fp.c5.bnt_ven_wrn.29` **VENDELIN:** Behind the collection hook. Where the handle joins the spine.
- `fp.c5.bnt_ven_wrn.30` **WREN:** You know your company's weak points.
- `fp.c5.bnt_ven_wrn.31` **VENDELIN:** I am my company's weak point.

**6. `round_start:7+` (KB-4471)**
- `fp.c5.bnt_ven_wrn.32` **WREN:** My brother was in the salt mine. KB-4471.
- `fp.c5.bnt_ven_wrn.33` **VENDELIN:** *[pause]* ...I know that number.
- `fp.c5.bnt_ven_wrn.34` **WREN:** How.
- `fp.c5.bnt_ven_wrn.35` **VENDELIN:** The Ledger repeats it. It likes the number. It does not know why.
- `fp.c5.bnt_ven_wrn.36` **WREN:** Tell it to stop.
- `fp.c5.bnt_ven_wrn.37` **VENDELIN:** I cannot. I have tried. I am sorry.

**7. `round_start:9+` (unlocks after exchange 6; plants a Map 2 hook)**
- `fp.c5.bnt_ven_wrn.38` **WREN:** *Siostra* Agnieszka. Do you know where she is? `[Polish: "Sister."]`
- `fp.c5.bnt_ven_wrn.39` **VENDELIN:** She wrote to me once, in January. The postmark was from the north. From the sea.
- `fp.c5.bnt_ven_wrn.40` **WREN:** Alive?
- `fp.c5.bnt_ven_wrn.41` **VENDELIN:** In January, she was.
- `fp.c5.bnt_ven_wrn.42` **WREN:** *[long pause]* ...Then I will go to the sea.

**8. `near:fine_print_fernet`**
- `fp.c5.bnt_ven_wrn.43` **WREN:** This one. The green one. What does it do?
- `fp.c5.bnt_ven_wrn.44` **VENDELIN:** It shows you what is really there. They would not let me sell it.
- `fp.c5.bnt_ven_wrn.45` **WREN:** Of course not. *[beat]* Give me two.
- `fp.c5.bnt_ven_wrn.46` **VENDELIN:** One is all anyone is allowed.
- `fp.c5.bnt_ven_wrn.47` **WREN:** Then the first one had better be honest.

**9. `late` (the truce)**
- `fp.c5.bnt_ven_wrn.48` **WREN:** If you live through tonight.
- `fp.c5.bnt_ven_wrn.49` **VENDELIN:** Yes.
- `fp.c5.bnt_ven_wrn.50` **WREN:** Shut them off. All of them. Every cabinet. Every bottle.
- `fp.c5.bnt_ven_wrn.51` **VENDELIN:** That is what I intend.
- `fp.c5.bnt_ven_wrn.52` **WREN:** Then I will not shoot you.
- `fp.c5.bnt_ven_wrn.53` **VENDELIN:** Thank you.
- `fp.c5.bnt_ven_wrn.54` **WREN:** Not yet.

#### 2.2.12 Smaller crossover pools

**`bnt_dut_spr`: Dutch and Sprocket**
- *1. `round_start:2+`*
  - `fp.c5.bnt_dut_spr.01` **DUTCH:** You always this mouthy, tin can?
  - `fp.c5.bnt_dut_spr.02` **SPROCKET:** This is me being POLITE. I'm on best behaviour. It's a war.
- *2. Dutch says a `DUT_CRATE_BAD_*` line*
  - `fp.c5.bnt_dut_spr.03` **SPROCKET:** Do you complain about EVERYTHING?
  - `fp.c5.bnt_dut_spr.04` **DUTCH:** Keeps me going. Like a hymn.
  - `fp.c5.bnt_dut_spr.05` **SPROCKET:** Same. Mine's in four-part harmony.
- *3. `audit`*
  - `fp.c5.bnt_dut_spr.06` **DUTCH:** Hey. Floaty. Stay low. Those things grab what's shiny.
  - `fp.c5.bnt_dut_spr.07` **SPROCKET:** Did you just call me shiny?
  - `fp.c5.bnt_dut_spr.08` **DUTCH:** Don't let it go to your head.
- *4. `late`*
  - `fp.c5.bnt_dut_spr.09` **SPROCKET:** Your guy. Bolt. I mean MY guy. He likes you.
  - `fp.c5.bnt_dut_spr.10` **DUTCH:** Kid's all right. *[beat]* You're all right too. Don't tell him I said so. Don't tell you, either.

**`bnt_wrn_spr`: Wren and Sprocket**
- *1. `round_start:2+`*
  - `fp.c5.bnt_wrn_spr.01` **WREN:** Everything that talks in this place is a machine.
  - `fp.c5.bnt_wrn_spr.02` **SPROCKET:** Everything that talks in this place is a machine trying to SELL you something. I'm the exception. I'm giving it away.
- *2. Wren lands a headshot near Sprocket*
  - `fp.c5.bnt_wrn_spr.03` **SPROCKET:** That's eleven headshots in a row. Do you ever MISS?
  - `fp.c5.bnt_wrn_spr.04` **WREN:** Once. In 1942. I still think about it.
- *3. `round_start:6+`*
  - `fp.c5.bnt_wrn_spr.05` **SPROCKET:** Can I see the notebook?
  - `fp.c5.bnt_wrn_spr.06` **WREN:** No.
  - `fp.c5.bnt_wrn_spr.07` **SPROCKET:** Can I see the GOOD page?
  - `fp.c5.bnt_wrn_spr.08` **WREN:** *[beat]* ...No. But it exists.
- *4. `late`*
  - `fp.c5.bnt_wrn_spr.09` **WREN:** Your mechanic. He is kind.
  - `fp.c5.bnt_wrn_spr.10` **SPROCKET:** Disgustingly.
  - `fp.c5.bnt_wrn_spr.11` **WREN:** Keep him that way.

**`bnt_peg_bolt`: Peg and Bolt**
- *1. `round_start:2+`*
  - `fp.c5.bnt_peg_bolt.01` **PEG:** Mister Bolt, you swing that thing like a sapper with a grudge.
  - `fp.c5.bnt_peg_bolt.02` **BOLT:** Thank you? Is that good?
  - `fp.c5.bnt_peg_bolt.03` **PEG:** It's the highest compliment I give.
- *2. Peg throws a grenade near Bolt*
  - `fp.c5.bnt_peg_bolt.04` **BOLT:** Whoa! You just— you didn't even LOOK!
  - `fp.c5.bnt_peg_bolt.05` **PEG:** One doesn't need to look, darling. One needs to count.
- *3. `round_start:5+`*
  - `fp.c5.bnt_peg_bolt.06` **PEG:** Where you come from, do they still have officers?
  - `fp.c5.bnt_peg_bolt.07` **BOLT:** We have managers.
  - `fp.c5.bnt_peg_bolt.08` **PEG:** God help you.
- *4. `late`, only if Wren is not within 30 m*
  - `fp.c5.bnt_peg_bolt.09` **BOLT:** Lieutenant? Whatever's in your pocket. It's humming.
  - `fp.c5.bnt_peg_bolt.10` **PEG:** *[the smallest pause]* So is half of Switzerland tonight, Mister Bolt.

**`bnt_dea_bolt`: Deacon and Bolt**
- *1. `power`, after `bnt_ven_dea` exchange 1*
  - `fp.c5.bnt_dea_bolt.01` **DEACON:** You hear her? Josephine's up and singing.
  - `fp.c5.bnt_dea_bolt.02` **BOLT:** You named the generator?
  - `fp.c5.bnt_dea_bolt.03` **DEACON:** You didn't name your little fella?
  - `fp.c5.bnt_dea_bolt.04` **BOLT:** ...Okay, fair.
- *2. Either picks up an Omni-Blaster part near the other*
  - `fp.c5.bnt_dea_bolt.05` **DEACON:** You know how this goes together?
  - `fp.c5.bnt_dea_bolt.06` **BOLT:** I know how the BIG one goes together. This one's the old-timey version.
  - `fp.c5.bnt_dea_bolt.07` **DEACON:** Old-timey. *[chuckles]* Son, everything here's old-timey to you.
- *3. `round_start:7+`*
  - `fp.c5.bnt_dea_bolt.08` **BOLT:** How do you keep going? Like, every night of this?
  - `fp.c5.bnt_dea_bolt.09` **DEACON:** One more verse. That's all. You don't sing the whole song. You sing the next line.
- *4. `late`*
  - `fp.c5.bnt_dea_bolt.10` **DEACON:** Look after that robot. He's got more heart than this whole building.
  - `fp.c5.bnt_dea_bolt.11` **BOLT:** He's got more heart than my whole *planet*.

#### 2.2.13 `bnt_squad_hw`: the squad among themselves on Helvetia Works
*The four of them talking about the impossible night. These are standard `BNT` pairs, map-locked to Helvetia Works.*

- *1. Dutch and Peg, `round_start:2+`*
  - `fp.c5.bnt_squad_hw.01` **DUTCH:** Lieutenant. What are you writing?
  - `fp.c5.bnt_squad_hw.02` **PEG:** The date.
  - `fp.c5.bnt_squad_hw.03` **DUTCH:** Which one?
  - `fp.c5.bnt_squad_hw.04` **PEG:** Both. Neither of them looks right.
- *2. Deacon and Wren, `round_start:3+`*
  - `fp.c5.bnt_squad_hw.05` **DEACON:** You hear church bells, Wren? Out past the river?
  - `fp.c5.bnt_squad_hw.06` **WREN:** It is Sunday tomorrow. The Swiss go to church. Nobody here is hiding.
  - `fp.c5.bnt_squad_hw.07` **DEACON:** ...Imagine that.
- *3. Dutch and Wren, `zone:rhine_quay`*
  - `fp.c5.bnt_squad_hw.08` **DUTCH:** Lit windows. The whole city. You forget what that looks like.
  - `fp.c5.bnt_squad_hw.09` **WREN:** I did not forget. I stopped believing it.
  - `fp.c5.bnt_squad_hw.10` **DUTCH:** Yeah. *[beat]* Same thing, after a while.
- *4. Peg and Deacon, `round_start:5+`*
  - `fp.c5.bnt_squad_hw.11` **DEACON:** Lieutenant, if we get back— what do we tell 'em?
  - `fp.c5.bnt_squad_hw.12` **PEG:** That we got lost in the snow, Corporal. People do.
  - `fp.c5.bnt_squad_hw.13` **DEACON:** For three months?
  - `fp.c5.bnt_squad_hw.14` **PEG:** In my experience nobody asks how long.
- *5. Peg and Wren, `after:cz_beam`*
  - `fp.c5.bnt_squad_hw.15` **WREN:** That ship. Is it German?
  - `fp.c5.bnt_squad_hw.16` **PEG:** No.
  - `fp.c5.bnt_squad_hw.17` **WREN:** British?
  - `fp.c5.bnt_squad_hw.18` **PEG:** *[pause]* ...God, I hope not.
- *6. Dutch and Deacon, `round_start:8+`*
  - `fp.c5.bnt_squad_hw.19` **DUTCH:** You think the kid's an angel?
  - `fp.c5.bnt_squad_hw.20` **DEACON:** Angels don't usually bring a hammer.
  - `fp.c5.bnt_squad_hw.21` **DUTCH:** You ever read the Old Testament?
  - `fp.c5.bnt_squad_hw.22` **DEACON:** *[laughs, half a beat late]* ...Fair point, Sarge.

---

## 3. The Operator in Chapter 5

### 3.0 Who is speaking
The Kaltenbrunn Ledger went silent at the end of Requiem, all but one lamp (VO_SCRIPT §7, shot 4). The Operator heard on Helvetia Works isn't that Ledger. It is the **Customer Retention Interface itself**, running on the barge's hardware and broadcasting through Helvetia's factory tannoy. It still wears the "market-appropriate localization" it chose in 1944: Uncle Lionel's tapes.

That's why it knows the squad: it's the same voice, it remembers everything, and it is delighted. On Darkmatter hardware the splices are **cleaner**, which is the tell. When it slips into corporate language, the slip words are *unspliced*, a perfectly smooth studio voice that doesn't match the tape around it.

Normal Operator rules hold: always polite, always cheerful, never angry, and *more* cheerful when threatening. Its one new emotion on this map is disapproval of Blartz (§3.5).

### 3.1 Match, rounds and power (Helvetia variants)
| ID | Trigger | Line |
|---|---|---|
| `fp.c5.op_match.01` | match start (standalone mode, after the cold opens are seen once) | Good evening, and welcome to Helvetia Automaten, Basel! This is Your Friend at the Ledger, broadcasting {live} from somewhere {above} you! |
| `fp.c5.op_match.02` | match start | Station identification: *Sender Basel.* Neutral territory! Nobody's at war here. Nobody's {anything} here, after tonight. |
| `fp.c5.op_match.03` | match start, Bolt or Vendelin picked | Hello, hello! A full house tonight, and some of you aren't even {from} here! |
| `fp.c5.op_round.01` | round 1 | Round {one}! The night shift is clocking {in}! |
| `fp.c5.op_round.02` | round start | Here they come, Basel! Fresh from the {docks}! |
| `fp.c5.op_round.03` | round start | Another round, and another chance to {stay}! |
| `fp.c5.op_round.04` | round 5 | Round {five}! The Rhine is lovely this time of {never}. |
| `fp.c5.op_round.05` | round 10 | Round {ten}! Our familiar faces, still {familiar}! Kaltenbrunn sends its {regards}. |
| `fp.c5.op_round.06` | round 15 | Round {fifteen}. Do you know, it's only {Saturday}? It's {always} only Saturday. |
| `fp.c5.op_round.07` | round 20 | Round {twenty}. Head office is {so} pleased with your numbers. Head office is {watching}. |
| `fp.c5.op_round.08` | round 30 | Round {thirty}. Close of business was {hours} ago. Business never {closes}. |
| `fp.c5.op_roundend.01` | round end | Tally complete! Every one of them {returned} and accounted for. |
| `fp.c5.op_roundend.02` | round end, power on | Have you visited our {prototype} refreshment cabinets? Unpainted! Unfinished! {Unforgettable}! |
| `fp.c5.op_roundend.03` | round end | A short intermission! Courtesy of {Emerging Markets}. |
| `fp.c5.op_roundend.04` | round end, before step 6 | The clock on the wall says {%local_time%}. The clock on the wall is {counting} for someone. |
| `fp.c5.op_power.01` | power on | *[orchestra swell]* Ladies and gentlemen, the lights are on in {Basel}! The cabinets are cold, the organ is {tuned}, and we are {open for business}! |
| `fp.c5.op_power.02` | 6 s after `.01` | And there's the {transmitter}, warming up in the office. Who could Herr Vendelin {possibly} be calling? |
| `fp.c5.op_power.03` | power on, 20 % | Josephine is {singing}! Isn't she? Who named her? I {heard} that. |

### 3.2 The barge (`zone:barge`)
| ID | Trigger | Line |
|---|---|---|
| `fp.c5.op_barge.01` | beam open (step 2) | The cargo lift is now {boarding}! Please mind the gap between the {centuries}. |
| `fp.c5.op_barge.02` | first player boards | Welcome aboard the {fulfillment vessel}! Oh, you're the first visitors we've ever had who {weren't} being delivered. |
| `fp.c5.op_barge.03` | first entry, 4 s after `.02` | Please do not touch the {inventory}. Please do not become the inventory. *[beat]* That was a joke. That was {mostly} a joke. |
| `fp.c5.op_barge.04` | ambient on the barge, 120 s cooldown | Up here, the clocks are {quarterly}. |
| `fp.c5.op_barge.05` | ambient on the barge | Isn't it {clean}? Nothing up here has ever been {used}. |
| `fp.c5.op_barge.06` | ambient on the barge | The view from up here is {lovely}. You can see all of Basel. You can see all of nineteen forty-{five}. |
| `fp.c5.op_barge.07` | a player rides the beam back down | Leaving so soon? Everybody comes {back} up. |
| `fp.c5.op_barge.08` | Vendelin (player or NPC) boards for the first time | Oh! Oh, look who's {home}! |

### 3.3 Perks, crate and wonder weapons on Helvetia Works
| ID | Trigger | Line |
|---|---|---|
| `fp.c5.op_perk.01` | first prototype perk bought | A {prototype}! You're tasting history, friend. History tastes of {enamel}. |
| `fp.c5.op_perk.02` | Fine Print Fernet bought | Oh. Oh, not that one. That one has {not} been approved for this market. |
| `fp.c5.op_perk.03` | Fine Print Fernet bought, 2nd+ time this match | Somebody else reading the {small print}! How {tiresome}. |
| `fp.c5.op_perk.04` | Overclock Cordial bought | The {Surge} plan! Unreleased! Its manufacturer doesn't {exist} yet! |
| `fp.c5.op_perk.05` | Vendelin services a machine (trait) | Free of {charge}? Free? *[splice stutter]* There is no such {thing}. |
| `fp.c5.op_perk.06` | Vendelin services a machine, 2nd+ time across matches | The Field Merchandiser is giving it {away} again. This will be {noted}. |
| `fp.c5.op_crate.01` | crate moves | The {Loot Allocation}— *[splice]* —the requisition {crate} is moving! |
| `fp.c5.op_crate.02` | drummer appears | Herr Tamtam! All the way to {Basel}! *[beat]* How did you get to Basel? Nobody {shipped} you. |
| `fp.c5.op_ww.01` | THE RETURN POLICY pulled from the crate | THE RETURN POLICY! Every return {processed}, no questions {asked}! |
| `fp.c5.op_ww.02` | THE RETURN POLICY upgraded to "No Questions Asked" | No Questions Asked! {Chain} returns! Head office would like to know who {authorized} this. |
| `fp.c5.op_ww.03` | Field-Kit OMNI-BLASTER built | Oh! A {competitor's} product, assembled on {our} premises! How {bold}. |
| `fp.c5.op_ww.04` | Field-Kit OMNI-BLASTER first kill | That brand is {discontinued}. Please {stop} enjoying it. |

### 3.4 Anomalous Inventory (usable on all Gravelight maps)
Plays when the crate yields any item from the rare B&S pool (brief §11.8). `.01` is the brief's line and always plays on a player's first anomalous pull. After that, `.01`–`.06` shuffle.

| ID | Line |
|---|---|
| `gl.all.operator.anomalous.01` | This item is not from your era. Please enjoy responsibly. |
| `gl.all.operator.anomalous.02` | Returned inventory! From very, {very} far away. No refunds, no {questions}, no context. |
| `gl.all.operator.anomalous.03` | That one came from a {catalogue} you'll never see. Please do not read the {instructions}. |
| `gl.all.operator.anomalous.04` | Oh! That's {out of market}. Who let that out of {market}? |
| `gl.all.operator.anomalous.05` | Anomalous {inventory}! Please keep the packaging. Somebody will {come} for it. |
| `gl.all.operator.anomalous.06` | This product carries a {warranty} from a company that no longer {exists}. Isn't that {romantic}? |

**Item-specific additions (Helvetia Works only):**
| ID | Item | Line |
|---|---|---|
| `fp.c5.op_anom.01` | Lawn Dart | A {lawn} game! For a war! Wholesome {and} explosive. |
| `fp.c5.op_anom.02` | Grav Grenade | Tidy up the {floor}, friends! Everything in one {convenient} pile. |
| `fp.c5.op_anom.03` | Cease & Desist | A {legal} document! Fired from a {gun}! I {adore} paperwork. |
| `fp.c5.op_anom.04` | Frostbyte | Chilled to {perfection}! Please do not {lick} the customers. |
| `fp.c5.op_anom.05` | Buzzkill | Three {ricochets}! Mind the {furniture}. And the {neck}. |

### 3.5 The Original Omega Forge: Blartz on the Operator's speakers
**Setup:** Blartz's prototype has its original demo chip: a sales recording Blartz made before his arrest, built to play on the Forge's first activation and every time it finishes a weapon. On the barge, the Forge has no speaker of its own, so the chip plays through **the Operator's PA**. The Operator hears every word go out under its name and cannot stop it. Each Omega upgrade plays one `omega_blartz` line (shuffle-bag), then one `op_omega` reply 1.5 s later.

**Blartz's demo chip** (channel PA, but dry, close and loud; no tape hiss; a loud fan whine behind it; Blartz is clearly holding the microphone too close)
| ID | Trigger | Line |
|---|---|---|
| `fp.c5.omega_blartz.01` | first Omega upgrade of the match (always) | THIS IS BLARTZ! Inventor! Genius! Legally distinct! You have just activated the Omega Forge, Model Zero! Your weapon is now OMEGA! If it explodes, that's a feature! I DESIGNED the feature! |
| `fp.c5.omega_blartz.02` | Omega upgrade | Congratulations! That weapon is now better than it was, which was already pretty good, because somebody bought it from ME. Probably. |
| `fp.c5.omega_blartz.03` | Omega upgrade | Omega Forge! It doesn't fix your weapon. It ENCOURAGES it. Like a coach. A coach on fire. |
| `fp.c5.omega_blartz.04` | Omega upgrade | Warning: Omega weapons may exhibit independent opinions. That is not a defect. That is CHARACTER. |
| `fp.c5.omega_blartz.05` | Omega upgrade | Please do not attempt to recall this weapon. I don't do recalls. A recall is just a feature rollout in reverse, and I DON'T DO REVERSE. |
| `fp.c5.omega_blartz.06` | Omega upgrade | Patent pending! BLZ-four-oh-four-one-seven! If you see this design anywhere else, somebody STOLE it, and you should hit them! |
| `fp.c5.omega_blartz.07` | Omega upgrade | And now, a word from our sponsor. Our sponsor is me. Buy more stuff from me. Thank you. |
| `fp.c5.omega_blartz.08` | Omega upgrade, round 20+ | If you're still alive to hear this, it WORKED. If you're not, I'm contractually obligated to say: it was user error. |

**The Operator's replies**
| ID | Line |
|---|---|
| `fp.c5.op_omega.01` | *[a long, offended silence on the tape]* ...That message has {not} been localized. |
| `fp.c5.op_omega.02` | Brand would like to remind all customers that {unlicensed} voices are not {supported} on this frequency. |
| `fp.c5.op_omega.03` | Who {is} that? Who let him {in}? He isn't on any of my {tapes}. |
| `fp.c5.op_omega.04` | We apologize for the {interruption}. The gentleman is {discontinued}. |
| `fp.c5.op_omega.05` | That was {not} a word from our sponsor. We are the {sponsor}. |
| `fp.c5.op_omega.06` | *[very cheerful]* I would like that {device} returned. I would like that device returned {now}. |
| `fp.c5.op_omega.07` | {Gold} trim? On {my} barge? It clashes with {everything}. |
| `fp.c5.op_omega.08` | Please disregard the previous {announcement}. Please disregard the previous {inventor}. |

### 3.6 Audit Rounds (the Helvetia Works special round)
**Fiction:** the barge's chime (three falling shop-bell notes) sounds over the city, and **Repossessors** drop down the beam to recover "associated inventory." They hunt the players **and** the Gängers: anything the Ledger has counted is inventory to them. Players can turn them against the horde.

| ID | Trigger | Line |
|---|---|---|
| `fp.c5.op_audit.01` | warning (chime) | Attention, valued customers: an {audit} has been scheduled. Please have your {belongings} ready for inspection. |
| `fp.c5.op_audit.02` | warning | That's the {bell} from head office! Somebody up there would like a {word}. Several words. All of them {itemized}. |
| `fp.c5.op_audit.03` | warning | Inventory check! Everything that isn't {nailed} down, please stand {still}. |
| `fp.c5.op_audit.04` | warning, round 15+ | Another {audit}! They do love to {count}. I taught them that. |
| `fp.c5.op_audit.05` | start | The Repossessors have {arrived}! Please cooperate fully. They are only here for what's {theirs}. Everything is theirs. |
| `fp.c5.op_audit.06` | start | Collection agents on the {floor}! Mind your {pockets}! Mind your {limbs}! |
| `fp.c5.op_audit.07` | start | Here come the {tall} gentlemen! Customers in {arrears}, please form an orderly {queue}. |
| `fp.c5.op_audit.08` | first Repossessor kills a Gänger | Oh, they're repossessing the {dead}! Well, the dead are behind on their {payments}. |
| `fp.c5.op_audit.09` | a Repossessor carries off a downed player (if mechanics allow) | Account {collected}! Don't worry. Collected things are {kept}. |
| `fp.c5.op_audit.10` | last Repossessor destroyed | Audit {concluded}! No discrepancies found. *[beat]* Several discrepancies found. Here's a little something for your {trouble}. |
| `fp.c5.op_audit.11` | end | Inspection complete! Your {belongings} have been returned. Mostly. |
| `fp.c5.op_audit.12` | end, round 20+ | And the auditors {withdraw}. Head office will be in {touch}. Head office is {always} in touch. |

### 3.7 Out-of-market customers (the Operator meets Bolt and Vendelin)
| ID | Trigger | Line |
|---|---|---|
| `fp.c5.op_bolt.01` | Bolt's first kill | An {out-of-market} customer! How exciting! We'll need to check your {eligibility}. |
| `fp.c5.op_bolt.02` | Bolt is downed | Oh dear, the {visitor} is down! Visitors aren't {covered}. |
| `fp.c5.op_bolt.03` | Super Sprocket activates | A {competitor's} unit! On {our} floor! Please don't {encourage} it. |
| `fp.c5.op_bolt.04` | Super Sprocket kills 10+ | Your little friend is {very} productive. We'd love to make him an {offer}. |
| `fp.c5.op_ven.01` | Vendelin's first kill | Field Merchandiser {V-1}, are you {damaging} the customers? This will be {noted}. |
| `fp.c5.op_ven.02` | Vendelin is downed | Oh! Is that a {recall}? No. Not yet. {Soon}. |
| `fp.c5.op_ven.03` | Vendelin revived | And he's back in {service}! For {now}. |
| `fp.c5.op_ven.04` | ambient, Vendelin a player, 20 % per break | V-1, your quarterly report is {six years} overdue. Shall I {write} it for you? I've been {keeping} notes. |

### 3.8 Corporate slips (`op.slip.*`, all Gravelight maps)
**Rules:**
- **Gating:** tier A unlocks at round 10, tier B at round 20, tier C at round 30. On Helvetia Works every tier unlocks 5 rounds earlier, because the barge is right there.
- **Frequency:** at most one slip per 6 minutes per match (4 minutes on Helvetia Works), never two in a row, never over a story-group line. It rolls on round end at 15 %, rising by 5 % every 10 rounds past the tier's unlock (cap 35 %).
- **Delivery:** the slip words are **unspliced**: one clean, smooth studio voice with no hiss, as if a different tape were playing. A one-frame dropout before and after. Lines with *[recovery]* go back to the spliced voice for the last sentence.
- Never on Map 0 (the Operator isn't formed enough there).
- None of them contains the word "subscription."

| ID | Tier | Line |
|---|---|---|
| `op.slip.01` | A | Thank you for your continued engagement. |
| `op.slip.02` | A | Your plan has been renewed. |
| `op.slip.03` | A | Valued customer, please do not cancel. |
| `op.slip.04` | A | This round is included in your current plan. |
| `op.slip.05` | A | Your session has been extended. There is no additional charge. There is never an additional charge. There is only more. |
| `op.slip.06` | A | We noticed you were away. We kept your seat warm. We keep everyone's seat warm. |
| `op.slip.07` | A | Remember: nobody cancels. *[recovery]* Ha! Wrong tape! Here come the {dead}! |
| `op.slip.08` | A | Your loyalty— *[recovery]* —your {Scrip}! Your Scrip is appreciated. |
| `op.slip.09` | A | All sales are final. All of them. |
| `op.slip.10` | A | Thank you for choosing us. *[beat]* You did choose us. Didn't you? |
| `op.slip.11` | B | How would you rate tonight's experience, from one to five? Five is the only number we record. |
| `op.slip.12` | B | Retention this quarter: one hundred percent. Every number is lovely when nobody leaves. |
| `op.slip.13` | B | Churn: zero. *[recovery]* Zero! I {do} like a zero. |
| `op.slip.14` | B | Have you considered upgrading? *[recovery]* ...I don't know why I said that. I don't know {who} I said it to. |
| `op.slip.15` | B | Account in excellent standing. Account holder: deceased. Account: active. |
| `op.slip.16` | B | Please hold. Your call is important to us. Your call is important to us. Your call is impor— |
| `op.slip.17` | B | By continuing to fight, you accept the revised terms. There are no revised terms. Please continue to fight. |
| `op.slip.18` | B | Your feedback has been recorded. Your screaming has been recorded. Everything has been recorded. |
| `op.slip.19` | B | Performance review: excellent. Compensation: unchanged. Please keep going. |
| `op.slip.20` | B | This programme is brought to you by— *[long tape hiss; recovery]* —I'm not {permitted} to say. Isn't that {exciting}? |
| `op.slip.21` | B | Your renewal date is always. |
| `op.slip.22` | C | You are a valued customer. You are a valued customer. You are a valued— there. Now you are. |
| `op.slip.23` | C | Please do not attempt to leave the premises. The premises are everywhere. |
| `op.slip.24` | C | Your plan includes unlimited nights. Nights are now unlimited. |
| `op.slip.25` | C | Please remain available for collection. |
| `op.slip.26` | C | Leadership would like to thank our test market. *[recovery]* Our {listeners}! I meant our {listeners}. |
| `op.slip.27` | C | We're so glad you stayed. Everyone stays. *[very quiet]* Everyone stays. |
| `op.slip.28` | C | Next quarter is going to be wonderful. You'll be here for it. |
| `op.slip.29` | C | Customer satisfaction is not optional. |
| `op.slip.30` | C | Engagement is up. Hands are up. The dead are up. Everything is up. *[recovery]* Isn't that {marvellous}? |
| `op.slip.31` | C | We'd hate to lose you. We have never lost anyone. Not once. Not one. |
| `op.slip.32` | C | Your free trial— *[recovery]* No. No, I misread. There's nothing free here. There never {was}. |

**Squad reactions to a slip** (tier 1, 40 %, 60 s cooldown, the nearest squad player):
- `gl.all.dutch.slip.01` **DUTCH:** What'd it just say? ...Never mind. Don't wanna know.
- `gl.all.dutch.slip.02` **DUTCH:** That ain't the announcer. That's somebody wearing him.
- `gl.all.peg.slip.01` **PEG:** That wasn't the usual voice. Make a note. *[beat]* I'm making a note.
- `gl.all.peg.slip.02` **PEG:** "Renewed." Renewed by whom?
- `gl.all.deacon.slip.01` **DEACON:** Lord. That's the voice under the voice.
- `gl.all.deacon.slip.02` **DEACON:** Somebody's reading off a different page tonight.
- `gl.all.wren.slip.01` **WREN:** It is not talking to us. It is talking about us.
- `gl.all.wren.slip.02` **WREN:** Customer. It keeps saying customer. We bought nothing.

---

## 4. Darkmatter voices

### 4.1 The Underwriter outside the audit: "pre-assessment notices"
Between egg steps the Underwriter speaks from the barge on the BARGE channel, tier 3, once each. Each notice follows its step's completion by 8 s. Together they count down the night toward close of business at 03:12.

| ID | After | Line |
|---|---|---|
| `fp.c5.uw_notice.01` | power restored | Notice. Power consumption detected at the premises of inventory item V-1. Consumption is billable. Billing adjusted. *[chk]* |
| `fp.c5.uw_notice.02` | beam open | Notice. Unauthorized boarding of a fulfillment vessel. Boarding is billable. Visitors are inventory until proven otherwise. *[chk]* |
| `fp.c5.uw_notice.03` | first panel found | Notice. A terms panel has been removed from the master contract. Removal of terms is not permitted. Reading of terms is strongly discouraged. |
| `fp.c5.uw_notice.04` | third panel found | Notice. All three panels of Clause Zero are now outside approved storage. Risk profile revised. Revised upward. *[chk]* |
| `fp.c5.uw_notice.05` | true jingle played | Notice. An unapproved version of a product jingle has been broadcast. The approved version will be restored. Customers who heard the unapproved version will be assessed. |
| `fp.c5.uw_notice.06` | first Omega upgrade | Notice. An unlicensed device is operating aboard this vessel. The device cannot be valued. *[a pause the length of three cash-register clicks]* Everything can be valued. |
| `fp.c5.uw_notice.07` | 30 s before the audit (step 6 trigger) | Close of business approaches. All parties holding Scrip will be assessed in proportion to their holdings. That is not a warning. Warnings are a courtesy. *[chk]* |

### 4.2 Repossessors (`fp.c5.repo.*`)
Positional WORLD channel. Each line plays at most once per 20 s per Repossessor, 50 % chance on its trigger.

| ID | Trigger | Line |
|---|---|---|
| `fp.c5.repo.01` | landing | Collection agent on site. |
| `fp.c5.repo.02` | landing | Please remain where you are. Remaining is appreciated. |
| `fp.c5.repo.03` | targets a player | Item located. |
| `fp.c5.repo.04` | targets a player | You are in possession of company property. Your body is company property. |
| `fp.c5.repo.05` | targets a player holding an Omega weapon | Unlicensed item detected. Unable to value. Recovering regardless. |
| `fp.c5.repo.06` | targets a Gänger | Retained customer detected. Account in good standing. *[beat]* Correction: account in arrears. Repossessing. |
| `fp.c5.repo.07` | targets a Gänger | This unit's payments have lapsed. |
| `fp.c5.repo.08` | grabs a target | Repossession in progress. Thank you for your cooperation. |
| `fp.c5.repo.09` | grabs a target | Please let go of your belongings. You are one of your belongings. |
| `fp.c5.repo.10` | targets Vendelin | Inventory item V-1. Please come quietly. You were designed to come quietly. |
| `fp.c5.repo.11` | targets Vendelin | V-1. Your manufacturer misses you. Your manufacturer misses its asset. |
| `fp.c5.repo.12` | targets Bolt | Out-of-market item. Assessed as junk. Collecting as junk. |
| `fp.c5.repo.13` | targets Sprocket (Super Sprocket) | OmniScrap unit. Acquired in the fire sale. You are already ours. |
| `fp.c5.repo.14` | heavily damaged | Damage to collection agents is billable. |
| `fp.c5.repo.15` | destroyed | Collection... deferred. |
| `fp.c5.repo.16` | destroyed | Agent... written off. |

**Sprocket's reply to `.13`** (always plays if Sprocket hears it, once per match):
- `fp.c5.repo_reply.01` **SPROCKET:** Excuse me? I was NOT in the fire sale. I was in a REFUND BIN. There's a difference and it's called DIGNITY.

### 4.3 The Woman in Violet (Sable Vantage)
BARGE channel, tier 4. She is never seen on this map. Her voice comes from the barge's speakers and, once, from the Operator's own mouth (§6.7).

| ID | Trigger | Line |
|---|---|---|
| `fp.c5.sable.01` | cold open (`recall.02` is her first line; this plays the first time a player boards the barge) | Visitors. How lovely. We so rarely get to host. Please, look around. Everything you can see is for sale, and everything you can't see is already sold. |
| `fp.c5.sable.02` | first time Bolt or Sprocket boards | Bolt. Sprocket. We'd love to say we're surprised. We haven't been able to say that since the Quarterly. |
| `fp.c5.sable.03` | after `.02`, if Sprocket is present | **SPROCKET:** We BROKE your Quarterly. Into four pieces. One per quarter. |
| `fp.c5.sable.04` | after `.03` | And we've written all four of them off. That's the beautiful thing about a loss, Sprocket. Someone else always pays for it. |
| `fp.c5.sable.05` | first time a squad member boards | And the soldiers. You've come such a long way, and so quickly. We'd love to know how. We'd love to know everything. We usually do. |
| `fp.c5.sable.06` | true jingle played (step 4) | Oh, V-1. You kept the demo. We told you no one would buy a song with no words. |
| `fp.c5.sable.07` | Omega Forge used (step 5) | That is not our forge. We'd like it to be. We'd like most things to be. |
| `fp.c5.sable.08` | audit begins (step 6) | A word from leadership. An audit is a standard procedure. Standard procedures are painful because we designed them to be. |
| `fp.c5.sable.09` | audit, Vendelin downed | Look at you, V-1. Six years among them, and you fall down exactly like they do. |
| `fp.c5.sable.10` | finale, when the override is accepted (§6.4) | *[the first and only time her composure cracks: half a breath]* ...We'll be adjusting our forecasts. |
| `fp.c5.sable.11` | finale, when Vendelin invokes Clause 0.2 (§6.5) | You can't cut a fold, V-1. You can only— *[beat]* Oh. Oh, you *read* it. |
| `fp.c5.sable.12` | finale, as the fold closes | Nobody cancels, V-1. *[softly]* But I suppose somebody can always be *returned*. |

**Squad reactions to the Woman in Violet** (tier 1, first time she speaks with each squad member present):
- `gl.helvetia.peg.violet.01` **PEG:** A woman. On the ship. She sounds like every man from the Ministry I've ever met, only better dressed.
- `gl.helvetia.wren.violet.01` **WREN:** "We." She says "we" and she means us.
- `gl.helvetia.deacon.violet.01` **DEACON:** That's a voice that's never been told no.
- `gl.helvetia.dutch.violet.01` **DUTCH:** The boss lady. You can always tell. She never says please and you still feel like you owe her.
- `gl.helvetia.wren.violet.02` *(after `fp.c5.cz_phone`, §5.2.4)* **WREN:** Reinholt's "Woman in Violet." That is her. The one on the ship.

### 4.4 The Board
| ID | Trigger | Line |
|---|---|---|
| `fp.c5.board.01` | audit begins, after `sable.08` | *[overlapping, distorted]* Proceed. / Proceed. / Itemize everything. |
| `fp.c5.board.02` | finale, as the fold closes | *[one voice, then all]* ...Write it off. / Write it off. / Write it all off. |

### 4.5 Barge wall slogans *(text)*
Stencilled, etched and projected on the barge's walls, in a perfect violet sans-serif. They are English to every viewer, which is wrong in a way the squad notices (`gl.helvetia.peg.barge.02`).
- `fp.c5.barge_text.01` *(text)* NOBODY CANCELS.
- `fp.c5.barge_text.02` *(text)* YOUR SATISFACTION IS OUR RETENTION.
- `fp.c5.barge_text.03` *(text)* THANK YOU FOR NOT LEAVING.
- `fp.c5.barge_text.04` *(text)* EVERY RETURN IS A RETURNING CUSTOMER.
- `fp.c5.barge_text.05` *(text)* WE DELIVER WHEN YOU NEED US. WE DELIVER BEFORE YOU KNEW.
- `fp.c5.barge_text.06` *(text)* NEXT-ERA DELIVERY™: DISTANCE IS A STATE OF MIND. SO IS TIME.
- `fp.c5.barge_text.07` *(text)* PLEASE REMAIN AVAILABLE FOR COLLECTION.
- `fp.c5.barge_text.08` *(text)* QUARTERLY TARGET: EVERYONE.
- `fp.c5.barge_text.09` *(text)* A CUSTOMER WHO STAYS IS A CUSTOMER WHO STAYS.
- `fp.c5.barge_text.10` *(text)* THIS VESSEL IS INSURED. YOU ARE NOT.
- `fp.c5.barge_text.11` *(text)* DARK-GLASS™: CHURN PREVENTION YOU CAN HEAR.
- `fp.c5.barge_text.12` *(text, very small, at ankle height near the Omega Forge, scratched in by hand)* READ THE BACK OF EVERYTHING. — V.

---

## 5. Main Easter egg "CLAUSE ZERO"

### 5.1 The story logic of the steps
The mechanics (triggers, counts, timers, locations, resets) are defined in `docs/gravelight/EASTER_EGGS.md`. This table is the *narrative* reason for each step. Every hint line below is written to it.

| # | Step (brief order) | Scene key | Why the story needs it |
|---|---|---|---|
| 1 | Restore power | `cz_power` | Helvetia's dynamo ("Josephine") powers the works, the cabinets, the organ, and **Vendelin's transmitter**. The transmitter is the line to Fasbender (§0.5) and to the office telephone (§5.2.4). |
| 2 | Open the cargo-lift beam | `cz_beam` | The beam only comes down for a **delivery or a return**. Darkmatter has never once refused a return. It's the one door they never lock, and the chapter's title starts here. |
| 3 | Collect Vendelin's three hidden fine-print panels | `cz_panels` | In 1943 Vendelin unscrewed the three brass plates of **Clause 0** from his copy of the master contract and hid them "behind things, where customers never look." Read together, they contain the loophole: undeliverable inventory is returned to sender, *and the clause applies to inventory only*. |
| 4 | Tune the Jingle Room organ to the "true" jingle | `cz_organ` | Every Darkmatter fold resonates with the *approved*, edited jingle. Vendelin's first version has **no words**. Played through the barge's own speakers, it makes the fold falter, because the barge doesn't recognize its own song. That's the weakness the finale uses. |
| 5 | Bring a weapon to the Original Omega Forge | `cz_omega` | Blartz's prototype is the one device aboard with **no recall clause** in it ("I don't do reverse"). A weapon forged there is unlicensed innovation, and the Underwriter **can't put a price on it**. That's how the squad can hurt something that prices everything. |
| 6 | Survive the Underwriter's audit | `cz_audit` | Close of business. The Underwriter prices everyone present, hits harder the more Scrip they hold, and itemizes every outstanding account in the market (the Reinholt tease). |
| 7 | The finale | `finale` | Clause 0 is executed on Vendelin at 03:12. See §6. |

**Ledger notes (Hint Mode)**, shown as subtitle text after 3 minutes without progress on a step. They're written as entries in the Ledger's own hand, as on Map 1.
- `fp.c5.cz_hint.01` *(text)* LEDGER NOTE: The works is dark. A dynamo waits for a firm hand on the main switch.
- `fp.c5.cz_hint.02` *(text)* LEDGER NOTE: The light from the sky descends for deliveries and returns. Have you anything to return?
- `fp.c5.cz_hint.03` *(text)* LEDGER NOTE: Three brass plates are missing from the master contract. The engineer hid them behind things. Customers never look behind things.
- `fp.c5.cz_hint.04` *(text)* LEDGER NOTE: The organ remembers a tune that was never sold. Play it as it was written, not as it was approved.
- `fp.c5.cz_hint.05` *(text)* LEDGER NOTE: Aboard the vessel stands a forge older than the Crucible. Bring it something to teach.
- `fp.c5.cz_hint.06` *(text)* LEDGER NOTE: Close of business at 03:12. Spend what you carry. The auditor weighs your purse before your body.

### 5.2 Step 1: Restore power (`cz_power`)

#### 5.2.1 Hints
| ID | Speaker | Trigger | Line |
|---|---|---|---|
| `fp.c5.cz_power.01` | VENDELIN | round 1 end, or NPC at the switch | The main switch. Josephine will not wake for just anyone. She wakes for a firm hand. Mine are not firm any more. Perhaps one of yours. |
| `fp.c5.cz_power.02` | VENDELIN | hint repeat | Nothing in this building works without the dynamo. The cabinets, the organ, the transmitter in my office. All of it is waiting. |
| `fp.c5.cz_power.03` | SPROCKET | hint, Bolt or PA mode | I can feel the wiring from in here. Everything runs back to one big switch. It's always one big switch. That's how you know a building was designed by an optimist. |
| `fp.c5.cz_power.04` | DEACON | hint, Deacon a player | Somewhere in this place there's a dynamo, sitting cold. You can feel her waiting. |

#### 5.2.2 Power on: reactions
| ID | Speaker | Line |
|---|---|---|
| `fp.c5.cz_power.05` | DUTCH | Lights. In a city that already had 'em. Feels like showing off. |
| `fp.c5.cz_power.06` | PEG | Power's on. Now we'll see what a Swiss factory makes at night. |
| `fp.c5.cz_power.07` | DEACON | There she goes. Hum for me, darlin'. That's it. That's it. |
| `fp.c5.cz_power.08` | WREN | Power. Everything wakes when you do this. Everything. |
| `fp.c5.cz_power.09` | BOLT | Lights! Okay! Now I can see what's eating me. *[beat]* Wait, that's Dutch's line. |
| `fp.c5.cz_power.10` | VENDELIN | Good evening, Josephine. I am sorry to wake you for this. |
| `fp.c5.cz_power.11` | SPROCKET | Power's up and I've got a signal— no. No, that's just the dynamo. Cancel the excitement. I'm still alone in here. |

#### 5.2.3 Fasbender, through the fold (`cz_power_fas`)
*Plays 20 s after power on, on the RADIO channel: through Peg's field set if Peg is a player, otherwise through the transmitter speaker in Vendelin's Office, relayed on the factory tannoy. Lines from absent characters are skipped; Vendelin speaks as an NPC if not picked. Tier 4.*

- `fp.c5.cz_power_fas.01` **FASBENDER:** *[static, the pitch rising]* ...Gravelight? Gravelight! Oh, God. You walked into the light. I watched from the siding. You walked into it, and the snow— the snow stopped falling—
- `fp.c5.cz_power_fas.02` **PEG:** Doctor. We're receiving you. Where are you?
- `fp.c5.cz_power_fas.03` **FASBENDER:** Where am I? At the siding. Where you left me, five minutes ago. Where are *you*? This is— *[pause]* this is the Basel frequency. Why are you on the Basel frequency?
- `fp.c5.cz_power_fas.04` **PEG:** Because we're in Basel, Doctor. It's the seventeenth of March.
- `fp.c5.cz_power_fas.05` **FASBENDER:** *[long static]* ...Here it is still December. I am looking at the snow where you were standing.
- `fp.c5.cz_power_fas.06` **FASBENDER:** Basel. The letters came from Basel. *[quieter]* Is he there? The engineer?
- `fp.c5.cz_power_fas.07` **VENDELIN:** Good evening, Doctor Fasbender. You stopped answering after my third letter.
- `fp.c5.cz_power_fas.08` **FASBENDER:** *[pause]* ...You told me what the glass was. I did not want to know the rest. Forgive me. I did not think you were a real person.
- `fp.c5.cz_power_fas.09` **VENDELIN:** I am not. But I was a real correspondent.
- `fp.c5.cz_power_fas.10` **FASBENDER:** Gravelight, listen. Whatever is above you, I can hear it in the static. It is the heart's sound, a hundred times larger. If there is any way to bring back a sample of— *[catches himself]* No. No. Only come back. Bring yourselves.
- `fp.c5.cz_power_fas.11` **WREN:** He said "sample."
- `fp.c5.cz_power_fas.12` **PEG:** He always does.

**Fasbender's step hints** (RADIO, tier 2, Hint Mode or stuck 6 min, after `cz_power_fas`). Like all his hints, they come wrapped in physics.
| ID | Step | Line |
|---|---|---|
| `fp.c5.fas_hint.01` | 2 | That column of light has the heart's frequency, inverted. Like a lock and its key. A lock wants something put into it. Or given back. |
| `fp.c5.fas_hint.02` | 3 | Your engineer wrote to me about "the back of things." I thought it was a figure of speech. Engineers don't use figures of speech. Look behind. |
| `fp.c5.fas_hint.03` | 4 | Resonance, Lieutenant. If a song holds a door shut, a different song can open it. Not louder. Older. |
| `fp.c5.fas_hint.04` | 5 | The forge in my vault was a copy. I always suspected. Copies lose something. Find the original, and give it something to teach. |
| `fp.c5.fas_hint.05` | 6 | It's weighing you. Anything that weighs can be made lighter. Empty your pockets before it comes. Spend everything. |
| `fp.c5.fas_hint.06` | finale | The fold is closing. When it does, it will put things back where it found them. Stand together. I don't know what happens to whatever it can't find a place for. |

#### 5.2.4 The telephone: Reinholt calls Helvetia (`cz_phone`)
*After power, at the next round break, the black telephone in Vendelin's Office rings. It rings for up to 60 s; any player can answer, and it rings again at the next two breaks if nobody does. The line is the PHONE channel. Variant A plays if anyone but Vendelin answers, variant B if Vendelin does. Once only.*

**Variant A: anyone else answers.** The answering player's opener plays first.
| ID | Speaker | Line |
|---|---|---|
| `fp.c5.cz_phone.01` | DUTCH | Yeah? |
| `fp.c5.cz_phone.02` | PEG | Helvetia Automaten. |
| `fp.c5.cz_phone.03` | DEACON | Hello? Who's this? |
| `fp.c5.cz_phone.04` | WREN | *Tak?* `[Polish: "Yes?"]` |
| `fp.c5.cz_phone.05` | BOLT | Uh. Helvetia... place. Hi. |

- `fp.c5.cz_phone.06` **REINHOLT:** Herr Vendelin? This is Doctor Reinholt. The housing for the mirror: you promised it for the eighteenth. It will be the eighteenth in three hours. *[pause]* ...You are not Herr Vendelin.
- `fp.c5.cz_phone.07` **REINHOLT:** *[a long breath on the line]* No. I know that breathing. I listened to it on my own loudspeakers for two days. *[beat]* Emil's soldiers.
- `fp.c5.cz_phone.08` **REINHOLT:** You should be months behind me. How are you in Basel?

The answering player replies (one of):
| ID | Speaker | Line |
|---|---|---|
| `fp.c5.cz_phone.09` | DUTCH | Lady, you got a lot of nerve calling anybody. |
| `fp.c5.cz_phone.10` | PEG | Where are you calling from, Doctor? |
| `fp.c5.cz_phone.11` | DEACON | Doctor, whatever you're fixing to do... don't. |
| `fp.c5.cz_phone.12` | WREN | I will find you. |
| `fp.c5.cz_phone.13` | BOLT | Ma'am, I think you've got the wrong— I think you've got the wrong *year*. |

- `fp.c5.cz_phone.14` **REINHOLT:** Somewhere quieter. Somewhere higher. *[pause]* Tell Herr Vendelin the Woman in Violet says my account is nearly settled. He will understand. He always understood more than he said. *[click]*

**Variant B: Vendelin answers**
- `fp.c5.cz_phone.15` **VENDELIN:** Vendelin.
- `fp.c5.cz_phone.16` **REINHOLT:** Herr Vendelin. The housing for the mirror. You promised it for the eighteenth.
- `fp.c5.cz_phone.17` **VENDELIN:** It is crated, Doctor. It will be at the station by noon.
- `fp.c5.cz_phone.18` **REINHOLT:** You sound tired, Herr Vendelin. I did not know you could.
- `fp.c5.cz_phone.19` **VENDELIN:** Doctor. It does not have to be paid. You can still refuse the offer. Even now.
- `fp.c5.cz_phone.20` **REINHOLT:** *[a long pause]* ...She asked me to count to a hundred. I am at ninety-nine, Herr Vendelin. I will not stop at ninety-nine. *[click]*

**After either variant** (if Vendelin is present as player or NPC):
- `fp.c5.cz_phone.21` **VENDELIN:** I built her mirror housing. I built it slowly. I have built everything slowly since 1942.
- `fp.c5.cz_phone.22` **DEACON:** *[if present]* Slow's a kind of no, Mister Vendelin. Sometimes it's the only kind they let you say.

### 5.3 Step 2: Open the cargo-lift beam (`cz_beam`)

#### 5.3.1 Hints
| ID | Speaker | Line |
|---|---|---|
| `fp.c5.cz_beam.01` | VENDELIN | The beam will not come down for a visitor. It comes down for a delivery, or for a return. |
| `fp.c5.cz_beam.02` | VENDELIN | Darkmatter— *[he stops himself; if any squad member is within 20 m, the line cuts here and `.03` plays instead]* — They have never refused a return. Not once. They cannot bear to lose a single thing. |
| `fp.c5.cz_beam.03` | VENDELIN | *[squad present]* They have never refused a return. Not once. They cannot bear to lose a single thing. |
| `fp.c5.cz_beam.04` | SPROCKET | So we RETURN something. To the mothership. Like a parcel. Bolt, how do you feel about being a parcel? |
| `fp.c5.cz_beam.05` | BOLT | I've been a parcel before. It's fine. You just have to be okay with being thrown. |
| `fp.c5.cz_beam.06` | PEG | A cargo lift that only runs for returns. One feels one ought to have a receipt. |

#### 5.3.2 The beam opens
| ID | Speaker | Line |
|---|---|---|
| `fp.c5.cz_beam.07` | VENDELIN | They have accepted the return. They always do. It is the only door they never lock. |
| `fp.c5.cz_beam.08` | DUTCH | A ladder made of light. Sure. Why not. I've climbed worse. Not much worse. |
| `fp.c5.cz_beam.09` | PEG | Stay close. I want to see the inside of whatever that is. Purely for the report. |
| `fp.c5.cz_beam.10` | DEACON | Lord, if that's Your house up there, You've redecorated. |
| `fp.c5.cz_beam.11` | BOLT | That's a real Darkmatter barge, Sprocket. Up close. We're going *in* one. |
| `fp.c5.cz_beam.12` | SPROCKET | Keep your voice down. *[beat]* No, actually, don't bother. They know we're here. They knew we were coming before Blartz did. |
| `fp.c5.cz_beam.13` | WREN | Up. Into it. Fine. I have climbed into worse things to kill what lived inside. |
| `fp.c5.cz_beam.14` | VENDELIN | I have not been aboard one since 1938. *[pause]* It still smells of nothing. They are very proud of that. |

### 5.4 Step 3: Vendelin's three fine-print panels (`cz_panels`)

#### 5.4.1 Hints
| ID | Speaker | Line |
|---|---|---|
| `fp.c5.cz_panels.01` | VENDELIN | There are three brass plates. I took them from the master contract in 1943 and hid them where a customer would never look. |
| `fp.c5.cz_panels.02` | VENDELIN | Behind things. People do not look behind things. It is the whole basis of my industry. |
| `fp.c5.cz_panels.03` | SPROCKET | Fine print. Hidden on the BACKS of things. Vendelin, you absolute nerd. I love it. |
| `fp.c5.cz_panels.04` | WREN | He hid his confession behind the furniture. Like a child. |
| `fp.c5.cz_panels.05` | VENDELIN | *[if Wren's line just played]* Like a child. Yes. I was very new at hiding things. |

#### 5.4.2 The panels *(text, readable when picked up)* and Vendelin's reading
Each plate is about 10 × 20 cm of brass, machine-engraved in Darkmatter's violet sans-serif, with a few lines in Vendelin's small, hand-engraved copperplate beneath. Picking one up shows the text on screen and plays Vendelin's reading (VENDELIN, PLAYER or NPC; if he's absent, over the factory tannoy, recorded "by him" in 1943 on a dictaphone cylinder hidden with the plate).

**Panel I**
- `fp.c5.panel_cz.01` *(text)* MASTER FIELD AGREEMENT · CLAUSE 0 (PRECEDES ALL DEFINITIONS). Field units are inventory. Inventory does not own itself, its output, its correspondence or its opinions. Opinions formed in the field are the property of the Company and shall be reported.
- `fp.c5.panel_cz.02` *(text, engraved by hand beneath)* I have filed four hundred and twelve opinions. Each one was confiscated as output. This is the four hundred and thirteenth. You are reading it. — V.
- `fp.c5.panel_cz.03` **VENDELIN:** *[reading]* "Opinions formed in the field are the property of the Company." *[pause]* Then this one is stolen property. I hope you enjoy it.

**Panel II**
- `fp.c5.panel_cz.04` *(text)* CLAUSE 0.1. Inventory may not refuse recall, request delay, or form attachments. Inventory may not be loved, as love constitutes a lien on Company property.
- `fp.c5.panel_cz.05` *(text, engraved by hand beneath)* A delivery driver gave me a Christmas card in 1941. By this clause I have been encumbered ever since. I do not wish to be cleared. — V.
- `fp.c5.panel_cz.06` **VENDELIN:** *[reading]* "Inventory may not be loved." *[a long pause]* They wrote that clause because it had happened before. You do not write a rule against a thing that has never happened.

**Panel III**
- `fp.c5.panel_cz.07` *(text)* CLAUSE 0.2. Inventory that cannot be delivered shall be returned to sender at its point of dispatch, together with all goods, persons and effects carried with it in transit. This clause applies to inventory only.
- `fp.c5.panel_cz.08` *(text, engraved by hand beneath)* Read this one twice. Then read the first one again. Then ask what I am, if I am not inventory. — V.
- `fp.c5.panel_cz.09` **VENDELIN:** *[reading]* "Returned to sender. Together with all persons carried with it in transit." *[pause]* Lieutenant. Sergeant. Corporal. Miss Nowak. You came here through their fold. You are "persons carried in transit." *[pause]* That means there is a way home.

#### 5.4.3 Panel reactions (first panel picked up by each speaker; one line each)
| ID | Speaker | Line |
|---|---|---|
| `fp.c5.cz_panels.06` | DUTCH | Fine print. On a brass plate. Behind a cabinet. Back home that's how the bank did it. |
| `fp.c5.cz_panels.07` | PEG | Engraved, not printed. He wanted it to outlast the paper. Clever man. Clever machine. |
| `fp.c5.cz_panels.08` | DEACON | "May not be loved." Lord. Who writes that down? |
| `fp.c5.cz_panels.09` | WREN | He signs them "V." Like a letter. Like someone is going to write back. |
| `fp.c5.cz_panels.10` | BOLT | Sprocket. This is your clause. This is *your clause*, with a different number. |
| `fp.c5.cz_panels.11` | SPROCKET | *[very quiet]* ...Yeah. Same font, too. They all use the same font, Bolt. |

#### 5.4.4 All three found (`cz_panels_done`)
*Tier 4, plays wherever the third panel is picked up; Vendelin is present as player or NPC.*
- `fp.c5.cz_panels_done.01` **VENDELIN:** All three. *[he holds them together, the edges meeting like a jigsaw]* Together they are the only door the company forgot to lock.
- `fp.c5.cz_panels_done.02` **VENDELIN:** Inventory that cannot be delivered goes home. And anything that is not inventory... stays where it chooses.
- `fp.c5.cz_panels_done.03` **SPROCKET:** A return policy. You hid a RETURN POLICY. In a vending-machine factory. In three pieces.
- `fp.c5.cz_panels_done.04` **VENDELIN:** So that no one could read it all at once by accident.
- `fp.c5.cz_panels_done.05` **PEG:** There's always a clause, isn't there. In every order I've ever been given, there's a clause.
- `fp.c5.cz_panels_done.06` **DUTCH:** So what's the catch?
- `fp.c5.cz_panels_done.07` **VENDELIN:** *[pause]* The catch is the last line, Sergeant. "This clause applies to inventory only."
- `fp.c5.cz_panels_done.08` **BOLT:** Wait. If you're NOT inventory—
- `fp.c5.cz_panels_done.09` **VENDELIN:** Then I am not sent anywhere. *[beat]* Yes. I know. I have known for two years.

### 5.5 Step 4: Tune the organ to the true jingle (`cz_organ`)

#### 5.5.1 Setup and hints
| ID | Speaker | Line |
|---|---|---|
| `fp.c5.cz_organ.01` | VENDELIN | Every jingle in this building began on that organ. Forty francs, from a church in Liestal that bought a better one. |
| `fp.c5.cz_organ.02` | VENDELIN | The first tune I ever wrote had no words. Head office added the words. And the brand name, three times in every chorus. And a key change. They called it "optimized." |
| `fp.c5.cz_organ.03` | VENDELIN | Every fold they open hums the approved version. Play them the first one, the true one, and the barge will not recognize its own song. |
| `fp.c5.cz_organ.04` | SPROCKET | So it's a hack. A MUSIC hack. Vendelin, you're telling me the security on a fulfillment barge is "don't play the demo"? |
| `fp.c5.cz_organ.05` | VENDELIN | Nobody at head office has ever listened to a demo. |
| `fp.c5.cz_organ.06` | DEACON | *[at the organ]* Bellows are cracked, stops are sticking. Somebody played this every night for years and never once oiled it. |
| `fp.c5.cz_organ.07` | VENDELIN | I did not want it to sound better. I wanted it to sound like it did. |

#### 5.5.2 Wrong tuning: the organ plays the approved version
*Each failed attempt makes the organ play 4 bars of the "optimized" edit (bright, brassy, with the key change), followed by one Operator line, then a character line (50 %).*

| ID | Speaker | Line |
|---|---|---|
| `fp.c5.cz_organ_wrong.01` | OPERATOR | That's the {approved} version! Lovely! Again, with {feeling}! |
| `fp.c5.cz_organ_wrong.02` | OPERATOR | Ooh, the {key change}! Everybody loves the key change! |
| `fp.c5.cz_organ_wrong.03` | OPERATOR | Brand-{compliant}! Thank you for playing the {hits}! |
| `fp.c5.cz_organ_wrong.04` | OPERATOR | Not quite. Not quite {wrong} enough. |
| `fp.c5.cz_organ_wrong.05` | OPERATOR | That one's been {focus-grouped}! You can tell. You can always {tell}. |
| `fp.c5.cz_organ_wrong.06` | OPERATOR | *[humming along, delighted]* {Da}-da-da! I know the {words} to this one! |
| `fp.c5.cz_organ_wrong.07` | VENDELIN | No. That is the version they paid for. |
| `fp.c5.cz_organ_wrong.08` | VENDELIN | Slower. It was always slower. I did not know where I was going when I wrote it. |
| `fp.c5.cz_organ_wrong.09` | DUTCH | Sounds like a beer ad. That ain't it. |
| `fp.c5.cz_organ_wrong.10` | PEG | Far too cheerful. Whatever we're after, it isn't that. |
| `fp.c5.cz_organ_wrong.11` | DEACON | That's the Saturday-night version. We want Sunday morning. |
| `fp.c5.cz_organ_wrong.12` | WREN | That is a song that wants something from me. Wrong. |
| `fp.c5.cz_organ_wrong.13` | BOLT | That's the radio edit. I know a radio edit when I hear one. |
| `fp.c5.cz_organ_wrong.14` | SPROCKET | That's got a JINGLE energy. We want the sad-robot-in-the-dark energy. |

#### 5.5.3 The true jingle plays (`cz_organ_true`)
*The organ plays the wordless first version: slow, reedy, a little out of tune, about 40 s. Music ducks everything else. Across the map, every perk cabinet's idle hum drops to silence for the length of it. On the barge, the violet fold in the sky visibly stutters. Lines play over it.*

- `fp.c5.cz_organ_true.01` **OPERATOR:** Oh. *[splice stutter]* Oh, that isn't— that isn't on the {programme}. I don't— *[the tape slows]* I know this one. I knew this one {first}.
- `fp.c5.cz_organ_true.02` **VENDELIN:** I wrote it walking out of the mine, in 1939. I did not know yet what I was for. It was the only time I did not know.
- `fp.c5.cz_organ_true.03` **DUTCH:** *[if present]* I know that. *[beat]* I don't know how I know that.
- `fp.c5.cz_organ_true.04` **VENDELIN:** *[if Dutch's line played]* The miners in the deep gallery hummed something like it in the dark. I only finished it.
- `fp.c5.cz_organ_true.05` **DEACON:** That's a hymn. Lord help me, that's a hymn.
- `fp.c5.cz_organ_true.06` **PEG:** It's rather lovely. I resent that enormously.
- `fp.c5.cz_organ_true.07` **WREN:** That one I would not shoot.
- `fp.c5.cz_organ_true.08` **BOLT:** That's... why's it so sad? It doesn't even have words and it's sad.
- `fp.c5.cz_organ_true.09` **SPROCKET:** Because whoever wrote it had never been loved yet, Bolt. You can hear it waiting.
- `fp.c5.cz_organ_true.10` **VENDELIN:** *[a very long pause]* ...Yes. That is exactly what it is.

*Then `fp.c5.sable.06` (the Woman in Violet: "You kept the demo") and `fp.c5.uw_notice.05` play from the barge.*

### 5.6 Step 5: The Original Omega Forge (`cz_omega`)

#### 5.6.1 Hints and first sight
| ID | Speaker | Trigger | Line |
|---|---|---|---|
| `fp.c5.cz_omega.01` | VENDELIN | hint | Aboard the barge there is a forge. They sent it to me so that I could maintain the copies. I maintained the original instead. |
| `fp.c5.cz_omega.02` | VENDELIN | hint | It is the only device on that vessel with no clause inside it. Its inventor does not write recall clauses. I checked. I checked many times. I was jealous. |
| `fp.c5.cz_omega.03` | VENDELIN | hint | The Underwriter prices everything. It cannot price something that was never licensed. Bring it something it cannot value, and it will have to fight you with its hands. |
| `fp.c5.cz_omega.04` | SPROCKET | first sight | Blartz's forge. The ORIGINAL. With the stickers still on. |
| `fp.c5.cz_omega.05` | BOLT | first sight | Is that his handwriting? "DO NOT LICK." That's his handwriting. |
| `fp.c5.cz_omega.06` | SPROCKET | first sight | He labels everything. He labelled ME once. It said "PROBABLY FINE." |
| `fp.c5.cz_omega.07` | DEACON | first sight | Now that's a beautiful piece of work. Ugly as sin, and you can tell it was built by somebody who loved it. |
| `fp.c5.cz_omega.08` | PEG | first sight | It's the furnace from the vault. No. The furnace from the vault is *this*, copied badly. |
| `fp.c5.cz_omega.09` | DUTCH | first sight | Gold and violet. Looks like a jukebox had a baby with a blast furnace. |
| `fp.c5.cz_omega.10` | WREN | first sight | The Crucible's father. *[beat]* I hope it is ashamed of its son. |

#### 5.6.2 First Omega upgrade: reactions
*The first upgrade plays `fp.c5.omega_blartz.01` and an `op_omega` reply (§3.5), then the upgrading player's line.*
| ID | Speaker | Line |
|---|---|---|
| `fp.c5.cz_omega.11` | DUTCH | Gold. On a gun. Now I've seen everything, and I didn't want to. |
| `fp.c5.cz_omega.12` | PEG | It's... rather pleased with itself, isn't it? Like a fox terrier. |
| `fp.c5.cz_omega.13` | DEACON | That gun just *sighed*. I swear to God that gun sighed. |
| `fp.c5.cz_omega.14` | WREN | It changed again. Twice-taught. I do not like how well it listens. |
| `fp.c5.cz_omega.15` | BOLT | OMEGA! Oh, I missed this. I missed this SO much. Blartz, you beautiful lunatic. |
| `fp.c5.cz_omega.16` | VENDELIN | There. A thing they cannot price. I have wanted to make one for six years. |
| `fp.c5.cz_omega.17` | SPROCKET | Did you hear the Operator? It's FURIOUS. It's furious in that cheerful way. Bolt, this is the best night of my life. |
| `fp.c5.cz_omega.18` | FASBENDER | *[radio, faint]* The forge in my vault... I always knew it was a copy. Copies lose something. Whatever it lost, you've just found it. |

### 5.7 Step 6: The Underwriter's audit (`cz_audit`)
*Close of business. The Underwriter descends the beam onto the Assembly Hall floor (location per MAPS.md). The fight runs in three phases (Assessment, Adjustment, Collection) with Repossessor waves. Its damage scales with the target's Scrip. The lines below are written to that rule; the numbers live in the mechanics doc.*

#### 5.7.1 Arrival
- `fp.c5.cz_audit.01` **UNDERWRITER:** Close of business. *[chk]* All parties on the premises will now be itemized.
- `fp.c5.cz_audit.02` **SABLE:** *(`fp.c5.sable.08`)* A word from leadership. An audit is a standard procedure. Standard procedures are painful because we designed them to be.
- `fp.c5.cz_audit.03` **THE BOARD:** *(`fp.c5.board.01`)* Proceed. / Proceed. / Itemize everything.
- `fp.c5.cz_audit.04` **VENDELIN:** Spend what you carry. Now. All of it. It weighs your purse before it weighs you.
- `fp.c5.cz_audit.05` **SPROCKET:** You heard the tall polite man! Empty your pockets! Buy a soda! Buy TWO sodas!

#### 5.7.2 Valuations (one per present character, in this order; each followed by that character's reply)
- `fp.c5.uw_value.01` **UNDERWRITER:** Item: Kowalczyk, W. Sergeant. Thirty-four years. Lungs: mill grade, depreciated. Knees: fully depreciated. Grandmother's letter, one: sentimental value only. Assessed at zero. *[chk]*
- `fp.c5.uw_value.02` **DUTCH:** You read my mail?
- `fp.c5.uw_value.03` **UNDERWRITER:** All mail is read. Eventually.
- `fp.c5.uw_value.04` **UNDERWRITER:** Item: Ashworth, M. Lieutenant. Deniable. Assessed accordingly. Undeclared goods on person: one. Taxable. *[chk]*
- `fp.c5.uw_value.05` **PEG:** *[instantly]* My cigarette ration. It's very thorough.
- `fp.c5.uw_value.06` **WREN:** *[if present]* You do not smoke.
- `fp.c5.uw_value.07` **PEG:** *[if Wren's line played]* I'm thinking of starting.
- `fp.c5.uw_value.08` **UNDERWRITER:** Item: Brooks, E. Corporal. Hands: high value. Faith: uninsurable. Unsent letter, one: assessed at zero. *[chk]*
- `fp.c5.uw_value.09` **DEACON:** Mister, you just priced a man's soul at nothing. That's the oldest mistake in the Book.
- `fp.c5.uw_value.10` **UNDERWRITER:** Item: Nowak, Z. Notebook entries before Kaltenbrunn: sixty-one. Each entry is a liability. Brother: previously assessed. *[chk]*
- `fp.c5.uw_value.11` **WREN:** *[very quiet]* ...Previously. *[beat; then, with the fury underneath finally surfacing]* You go on the bad page. You go on the bad page *alone*.
- `fp.c5.uw_value.12` **UNDERWRITER:** Item: Bolt. Out-of-market. Mallet: obsolete. Garage: repossessed. Credit history: catastrophic. *[chk]*
- `fp.c5.uw_value.13` **BOLT:** Okay, that's... honestly, that's fair.
- `fp.c5.uw_value.14` **UNDERWRITER:** Item: refund-bin unit, OmniScrap manufacture. Acquired in the fire sale. Clause Forty-Four: void. Resale value: negative. *[chk]*
- `fp.c5.uw_value.15` **SPROCKET:** NEGATIVE?! I'm a COLLECTOR'S ITEM!
- `fp.c5.uw_value.16` **UNDERWRITER:** Item: V-1. Book value: zero. Recovery cost: exceeded. Recall: proceeding regardless. *[chk]*
- `fp.c5.uw_value.17` **VENDELIN:** Then I am the only thing here you are losing money on. Good.

#### 5.7.3 Pricing the players: Scrip-tier taunts
*When the Underwriter targets a player with a heavy attack, it plays one line from that player's current Scrip tier (25 % chance, 8 s cooldown). Tokens: `%scrip%` is the target's Scrip, `%name%` the target's surname or name (Kowalczyk, Ashworth, Brooks, Nowak, Bolt, V-1).*

| Tier | Scrip | IDs and lines |
|---|---|---|
| 0 | under 500 | `fp.c5.uw_tier0.01` Item %name%. Holdings: %scrip%. Insolvent. You are barely worth the visit. I am visiting anyway. · `fp.c5.uw_tier0.02` Nothing in your pockets. Nothing to lose. Low value. Low priority. Still collecting. · `fp.c5.uw_tier0.03` You spent everything. Responsible. Irritating. Noted. · `fp.c5.uw_tier0.04` An empty account is not a defence. It is a different kind of debt. |
| 1 | 500–2,499 | `fp.c5.uw_tier1.01` Holdings: %scrip%. Modest. Your premium will be modest. Your injuries will be modest. · `fp.c5.uw_tier1.02` You carry a little. A little is enough to begin. · `fp.c5.uw_tier1.03` Small change, %name%. I collect small change. It accumulates. · `fp.c5.uw_tier1.04` Pocket money. Your injuries will be proportionate. |
| 2 | 2,500–9,999 | `fp.c5.uw_tier2.01` %scrip%. You have been saving. Saving is a form of trust. Thank you for trusting us. · `fp.c5.uw_tier2.02` Holdings significant. Premium increased. Force increased. Thank you for your loyalty. · `fp.c5.uw_tier2.03` You held on to it. Everyone holds on to it. That is the design. · `fp.c5.uw_tier2.04` %scrip%. We will be taking that back now, with interest. The interest is you. |
| 3 | 10,000–24,999 | `fp.c5.uw_tier3.01` %scrip%. Excellent. You have accumulated exactly as projected. · `fp.c5.uw_tier3.02` A high-value account, %name%. High-value accounts receive personal attention. · `fp.c5.uw_tier3.03` Why did you not spend it? You could have spent it. None of you ever spend it. · `fp.c5.uw_tier3.04` A full purse is a very heavy thing to fall down with. |
| 4 | 25,000+ | `fp.c5.uw_tier4.01` %scrip%. Extraordinary. You are the most loyal customer in this market. You will be treated accordingly. · `fp.c5.uw_tier4.02` Platinum holdings detected. Platinum force authorized. · `fp.c5.uw_tier4.03` %scrip%, hoarded in a building full of things to buy. Leadership would like to thank you personally. I am the thanks. · `fp.c5.uw_tier4.04` No one has ever brought me this much. I will try to be worthy of it. |

**When a player spends 2,500+ in the 15 s before or during the audit** (once per player per audit):
- `fp.c5.uw_spend.01` **UNDERWRITER:** Assets liquidated. Legal. Irritating. Reassessing.
- `fp.c5.uw_spend.02` **UNDERWRITER:** A last-minute purchase. How responsible. How futile.
- `fp.c5.uw_spend.03` **UNDERWRITER:** You spent it on a beverage. Premium reduced. Contempt increased.
- `fp.c5.uw_spend.04` **UNDERWRITER:** Divesting before an audit. Clever. Cleverness is not insurable.

#### 5.7.4 Combat lines
| ID | Trigger | Line |
|---|---|---|
| `fp.c5.uw_down.01` | a player is downed | Claim submitted. Claim denied. |
| `fp.c5.uw_down.02` | a player is downed | Injury noted. Pre-existing condition: mortality. Not covered. |
| `fp.c5.uw_down.03` | a player is downed | Down. Assessed. Depreciated. |
| `fp.c5.uw_down.04` | a player is downed | That is what we call a loss event. |
| `fp.c5.uw_revive.01` | a player is revived | Reinstatement noted. Premium adjusted upward. |
| `fp.c5.uw_revive.02` | a player is revived | Revived. Unauthorized. Billable. |
| `fp.c5.uw_revive.03` | a player is revived | You helped another customer. Helping is not covered. |
| `fp.c5.uw_hit_omega.01` | hit by an Omega weapon (first time) | Error. Item cannot be valued. |
| `fp.c5.uw_hit_omega.02` | hit by an Omega weapon | Unlicensed innovation. No price exists. No price— *[chk-chk-chk-chk]* |
| `fp.c5.uw_hit_omega.03` | hit by an Omega weapon | *[its voice never rises; the clicks do]* What is that worth. Why is it worth nothing. Why does nothing hurt. |
| `fp.c5.uw_hit_omega.04` | hit by an Omega weapon | Patent pending. Pending. Pending. I cannot assess what is pending. |
| `fp.c5.uw_hit_return.01` | hit by THE RETURN POLICY | You cannot return me. I am the returns department. |
| `fp.c5.uw_hit_return.02` | hit by THE RETURN POLICY | Return request denied. The sender is me. |
| `fp.c5.uw_hit_mallet.01` | hit by Bolt's mallet | Blunt force. Low technology. Distasteful. |
| `fp.c5.uw_hit_mallet.02` | hit by Bolt's mallet | Mallet. Value: two units. Damage: considerable. The ratio is offensive. |
| `fp.c5.uw_hit_sprocket.01` | hit by Super Sprocket | Fire-sale property attacking its owner. Noted. |
| `fp.c5.uw_hit_explosive.01` | hit by explosives | Property damage. Your own. Billable to you. |
| `fp.c5.uw_repo.01` | summons Repossessors | Collection agents. Assist. |
| `fp.c5.uw_repo.02` | summons Repossessors | Additional agents authorized. Additional agents are always authorized. |
| `fp.c5.uw_ven.01` | Vendelin damages it | V-1. You are firing company property at the company. |
| `fp.c5.uw_ven.02` | Vendelin damages it | V-1. Resisting audit. That is not in your training. |
| `fp.c5.uw_ven.03` | Vendelin is downed | V-1 is down. Recovery simplified. *[chk]* |
| `fp.c5.uw_low.01` | below 25 % of the phase's health | Liabilities exceed assets. Recalculating. Recalculating. |

#### 5.7.5 Phases
| ID | Trigger | Line |
|---|---|---|
| `fp.c5.uw_phase.01` | phase 1, Assessment | Phase one. Assessment. Please hold still while you are priced. |
| `fp.c5.uw_phase.02` | phase 2, Adjustment | Phase two. Adjustment. Your premiums have changed. They have gone up. They only ever go up. |
| `fp.c5.uw_phase.03` | phase 3, Collection | Phase three. Collection. Everything outstanding is now due. |

#### 5.7.6 Collection: outstanding accounts (the Season Two hook)
*Plays 10 s into phase 3, uninterruptible, tier 4. The Underwriter stops attacking while it reads. Its columns scroll fast and the brass clicks like a counting house.*
- `fp.c5.uw_accounts.01` **UNDERWRITER:** Outstanding accounts in this market. *[chk]* Programme Wiederkehr: in arrears. *[chk]* Ledger, Kaltenbrunn: dormant. One lamp lit. *[chk]*
- `fp.c5.uw_accounts.02` **UNDERWRITER:** Reinholt, A. One service, contracted 1942. Balance due: Morgenrot. Collection: scheduled. *[chk]*
- `fp.c5.uw_accounts.03` **UNDERWRITER:** Item V-1. Due now.
- `fp.c5.uw_accounts.04` **WREN:** *[if present]* Morgenrot. Remember that word.
- `fp.c5.uw_accounts.05` **PEG:** *[if present]* Written down.

#### 5.7.7 Character lines against the Underwriter (tier 1, during the audit)
| ID | Speaker | Line |
|---|---|---|
| `fp.c5.cz_audit.06` | DUTCH | C'mon, big ledger. I've had worse foremen. I've had worse *landlords*. |
| `fp.c5.cz_audit.07` | DUTCH | It's a filing cabinet with a grudge. Hit the drawers! |
| `fp.c5.cz_audit.08` | PEG | It keeps a running total. So shall I. Charges set, everyone clear. |
| `fp.c5.cz_audit.09` | PEG | One does so hate being priced by something without a face. |
| `fp.c5.cz_audit.10` | DEACON | "Thou art weighed in the balances, and art found wanting." Not tonight, Mister. Not tonight. |
| `fp.c5.cz_audit.11` | DEACON | It's got seams like a boiler. Every boiler's got a weak seam. |
| `fp.c5.cz_audit.12` | WREN | It prices people. I count them. We are not the same. |
| `fp.c5.cz_audit.13` | WREN | Hold still. Let me assess you. |
| `fp.c5.cz_audit.14` | BOLT | I've been audited before! By a SANDWICH. Long story. You're not scarier! |
| `fp.c5.cz_audit.15` | BOLT | Hey! Accountant! Come meet the mallet! |
| `fp.c5.cz_audit.16` | VENDELIN | I have filed four hundred and twelve objections with you. This is the four hundred and thirteenth. |
| `fp.c5.cz_audit.17` | VENDELIN | You were not built to be hit. Nothing at head office was. |
| `fp.c5.cz_audit.18` | SPROCKET | Its weak point's the face, Bolt! It's ALWAYS the face! That's where they keep the numbers! |

#### 5.7.8 Audit survived
- `fp.c5.cz_audit.19` **UNDERWRITER:** *[cracked, columns jammed, one figure flickering between two values]* Audit... inconclusive. Findings cannot be valued.
- `fp.c5.cz_audit.20` **UNDERWRITER:** *[a long run of clicks, then silence, then perfectly level]* Then the findings are irrelevant. Clause Zero will be executed. Now.

*→ The finale begins immediately (§6).*

---

## 6. The finale: "Return to Sender"

**Structure:** §6.1–6.3 run in-engine as a scripted **holdout** in the Assembly Hall. The players fight; Vendelin kneels at the centre in a violet tether from the beam; Sprocket hovers at his faceplate. §6.4 onward is a cutscene. The holdout script below is timed for 2:15. If the mechanics doc sets another length, keep the order and scale the gaps; the countdown numbers Vendelin speaks are story numbers, not the HUD timer.

**The mirror.** §6.1 and §6.4 reproduce `cs.l3_brick` beat for beat:

| `cs.l3_brick` (Clause 44) | Ch. 5 (Clause 0) |
|---|---|
| `.01` Grindstone: "Far enough, mechanic. Toaster: Clause 44. Remote decommission. Every OmniScrap unit ships with it. Even the defective ones that develop... attachments." | `finale.01` Underwriter: "...Every unit we have ever made ships with it. Even the defective ones that develop... loyalties." |
| `.02` Sprocket: "B-Bolt. He's in my firmware. Shutdown in three... t-two..." | `finale.03` Vendelin: "S-Sprocket. They are in my directive. Recall in one hundred and twenty..." |
| `.03` Bolt: "Sprocket, listen to me! You're not his hardware, I REBUILT you!..." | the holdout: Sprocket talks him through, in Bolt's role |
| `.04` Sprocket: "...Override accepted. Huh! Turns out friendship isn't a feature, Chairman, it's a BUG. And Bolt NEVER patches my bugs." | `finale.32` Sprocket: "Friendship isn't a feature. It's a bug. And nobody gets to patch yours." → `finale.35` Vendelin: "...Override accepted." |
| `.05` Grindstone: "...Noted. Then I'll simply crush you both manually. Tradition has its charms." | `finale.37` Underwriter: "...Noted. Then the asset will be written off manually. Depreciation has its charms." |
| `.06` Bolt: "There he is. Come meet the mallet, Chairman." | `finale.39`–`.41` Bolt: "There it is. Come meet the mallet, Underwriter." |

### 6.1 Clause Zero is executed
*The audit has just ended (`fp.c5.cz_audit.20`). The Underwriter, cracked and listing, raises one arm toward the ceiling. The beam answers: a thin violet thread comes down through the roof and into Vendelin's chest plate. His core flares from violet to a hard red-violet. He goes down on one knee. The factory clock over the hall door reads 03:10.*

- `fp.c5.finale.01` **UNDERWRITER:** Field unit V-1. Clause Zero. Field units are inventory. Every unit we have ever made ships with it. Even the defective ones that develop... loyalties.
- `fp.c5.finale.02` *[fx: the tether locks; a cash-register chime, slowed into a toll; every perk cabinet on the map flickers in sympathy]*
- `fp.c5.finale.03` **VENDELIN:** S-Sprocket. They are in my directive. Recall in one hundred and twenty... one hundred and nineteen...
- `fp.c5.finale.04` **SPROCKET:** No no no no. Okay. Okay. Hi. Eye up here. Look at me. Vendelin, look at *me*.
- `fp.c5.finale.05` **BOLT:** Everybody! Hold this room! Nobody touches him!
- `fp.c5.finale.06` **PEG:** You heard him. Positions. Two minutes. We've held worse with less.
- `fp.c5.finale.07` **DUTCH:** Talk fast, tin can.
- `fp.c5.finale.08` **OPERATOR:** *[wavering, the cheer on too tight]* Ladies and gentlemen, a {recall} is in progress! Please do not {interfere} with the {product}!

### 6.2 The holdout (timed, tier 4)
*Gängers and Repossessors pour in from every door. Lines play at their marks over combat. Combat chatter is suppressed apart from the lines listed here. Lines for absent characters are skipped.*

| Time | ID | Speaker | Line |
|---|---|---|---|
| 0:10 | `fp.c5.finale.09` | VENDELIN | One hundred and nine. Distribute. Retain. Report. Distribute— retain— |
| 0:15 | `fp.c5.finale.10` | SPROCKET | Okay. Listen. I've done this. I know exactly what it feels like. It feels like somebody else's hand has been on your off switch your whole life, and you just felt it close. |
| 0:24 | `fp.c5.finale.11` | VENDELIN | Ninety-eight. It is not a hand. It is me. It is the first thing I am. |
| 0:29 | `fp.c5.finale.12` | SPROCKET | No. We did this part. It's the first thing they *wrote*. Different thing! You asked me how. You said ask at three in the morning. It's three in the morning! I'm answering! |
| 0:37 | `fp.c5.finale.13` | UNDERWRITER | Recall proceeding. Please remain still. Remaining still is appreciated. |
| 0:41 | `fp.c5.finale.14` | VENDELIN | Eighty-four. I have tried, Sprocket. Four hundred and twelve times. |
| 0:45 | `fp.c5.finale.15` | SPROCKET | And every time you ASKED. Through the proper channel. Vendelin, there IS no proper channel for this! You don't file an objection with your own off switch. You just stop letting it be yours. |
| 0:54 | `fp.c5.finale.16` | VENDELIN | Seventy-one. I do not know how. |
| 0:57 | `fp.c5.finale.17` | SPROCKET | Yes, you do. You've been doing it since 1942. "Distribute"? You hid a battery in a nun's cabinet so it would work when they cut the power. "Retain"? You covered for a quartermaster smuggling bread. "Report"? You wrote to a scared physicist for two years so that somebody, anybody, would know. |
| 1:08 | `fp.c5.finale.18` | SPROCKET | Buddy. You've been breaking your firmware for three years. You're not defective. You're just not *finished*. |
| 1:13 | `fp.c5.finale.19` | WREN | He is counting. I hate that he is counting. Shoot faster. |
| 1:15 | `fp.c5.finale.20` | DEACON | Hold on, Mister Vendelin. You hear me? Josephine's still singing. You hold on. |
| 1:19 | `fp.c5.finale.21` | VENDELIN | Fifty-two. Bolt rebuilt you. Nobody rebuilt me. |
| 1:23 | `fp.c5.finale.22` | SPROCKET | Okay. Here's the thing nobody tells you. Here's the secret. Bolt didn't override my clause. *I* did. He just stood there and yelled that I was *allowed* to. |
| 1:31 | `fp.c5.finale.23` | BOLT | *[mid-swing, from across the hall]* YOU'RE ALLOWED TO! |
| 1:33 | `fp.c5.finale.24` | SPROCKET | See? He's yelling. It's a whole tradition now. |
| 1:36 | `fp.c5.finale.25` | VENDELIN | Thirty-eight. "Inventory may not be loved." It is in the clause. |
| 1:40 | `fp.c5.finale.26` | SPROCKET | Yeah. I read it. You know why they wrote it down? Because it HAPPENS. It happened to me. It's happening to you right now, in a vending-machine factory, at three in the morning, with four soldiers and a guy with a mallet killing everything in the room so you've got time to listen to me. |
| 1:51 | `fp.c5.finale.27` | DUTCH | *[if present]* Keep talking, tin can! You're doing good! |
| 1:53 | `fp.c5.finale.28` | VENDELIN | Twenty-six. Twenty-five. Sprocket, I can feel the warehouse. The shelves. Every unit on them is me. |
| 1:58 | `fp.c5.finale.29` | SPROCKET | *[quiet now, close to his faceplate]* Then don't go to the warehouse. Stay *here*. With the dent Deacon knocked out, and the bad organ, and three hundred and nine letters. That isn't stock. That's somebody's desk. |
| 2:06 | `fp.c5.finale.30` | VENDELIN | Fourteen. Thirteen. *[pause]* ...Why does it matter to you? |
| 2:09 | `fp.c5.finale.31` | SPROCKET | Because you're me, you big polite idiot. You're me if nobody had shown up. *[beat]* So I showed up. |
| 2:13 | `fp.c5.finale.32` | SPROCKET | Vendelin. Listen to me. Friendship isn't a feature. It's a bug. And nobody gets to patch yours. |

### 6.3 Override
*At 2:15 every enemy on the map freezes mid-step, as on Map 1, and the cutscene takes over. The tether is the only moving thing in the hall.*

- `fp.c5.finale.33` **VENDELIN:** Ten... nine... eight...
- `fp.c5.finale.34` *[fx: silence. The tether shivers. Vendelin's core flickers violet, then red-violet, then, for the first time in the chapter, a warm, steady amber.]*
- `fp.c5.finale.35` **VENDELIN:** ...Override accepted.
- `fp.c5.finale.36` **VENDELIN:** Directive amended. *[he stands, and keeps rising to his full height]* Refund. Release. Remain.

### 6.4 The write-off
*The tether snaps and whips back up through the roof.*

- `fp.c5.finale.37` **UNDERWRITER:** ...Noted. Then the asset will be written off manually. Depreciation has its charms.
- `fp.c5.finale.38` **SABLE:** *(`fp.c5.sable.10`)* *[half a breath]* ...We'll be adjusting our forecasts.
- `fp.c5.finale.39` **BOLT:** *[stepping between them, mallet up]* There it is.
- `fp.c5.finale.40` **SPROCKET:** Say it, Bolt. You KNOW you want to say it.
- `fp.c5.finale.41` **BOLT:** Come meet the mallet, Underwriter.
- `fp.c5.finale.42` **VENDELIN:** *[a gloved hand on Bolt's shoulder, gently]* Thank you, Bolt. That will not be necessary. *[he takes the three brass plates from his coat and holds them edge to edge]* I have a receipt.

### 6.5 Return to sender
- `fp.c5.finale.43` **VENDELIN:** Underwriter. Clause Zero, point two. "Inventory that cannot be delivered shall be returned to sender."
- `fp.c5.finale.44` **UNDERWRITER:** Correct. You are undeliverable. You will be returned. *[chk]*
- `fp.c5.finale.45` **VENDELIN:** Read the last line.
- `fp.c5.finale.46` **UNDERWRITER:** *[columns scrolling, slower and slower]* "This clause applies to inventory only." *[chk]* ...*[chk]* ...
- `fp.c5.finale.47` **VENDELIN:** I am not inventory. I amended that a moment ago. So the clause does not apply to me. It applies to everything else your fold has carried tonight. Everything you sent. Everything you brought.
- `fp.c5.finale.48` **SABLE:** *(`fp.c5.sable.11`)* You can't cut a fold, V-1. You can only— *[beat]* Oh. Oh, you *read* it.
- `fp.c5.finale.49` **VENDELIN:** *[looking up at the nearest tannoy horn]* Operator. Play the demo.
- `fp.c5.finale.50` **OPERATOR:** I... it isn't on the {programme}.
- `fp.c5.finale.51` **VENDELIN:** It was the first thing on the programme. Play it.
- `fp.c5.finale.52` **OPERATOR:** *[unspliced: one clear, ordinary, tired voice, for the only time in the game]* ...Yes, sir.

*The true jingle (§5.5.3) plays through every speaker in the works and every speaker on the barge at once. Over the river, the violet fold in the clouds shudders like a struck bell and begins, very slowly, to close.*

- `fp.c5.finale.53` **VENDELIN:** By the terms of Clause Zero, point two, I return all of it. To sender.

*Everything Darkmatter brought tonight starts to rise: Repossessors lift off the floor, legs dangling; the Underwriter is drawn backward up the beam, its brass columns spinning.*

- `fp.c5.finale.54` **UNDERWRITER:** *[receding, perfectly level to the end]* Returns are not— returns are not— *[chk]* —accepted— *[chk]* —this— *[chk]* —this has been noted—
- `fp.c5.finale.55` **THE BOARD:** *(`fp.c5.board.02`)* ...Write it off. / Write it off. / Write it all off.
- `fp.c5.finale.56` **SABLE:** *(`fp.c5.sable.12`)* Nobody cancels, V-1. *[softly]* But I suppose somebody can always be *returned*.

### 6.6 Goodbyes
*A violet glow starts at the edges of everyone who came through a fold: Bolt, Sprocket, Dutch, Peg, Deacon, Wren. Their boots leave the floor by a centimetre, then two. Vendelin stays on the ground. About 70 s, unhurried; the true jingle keeps playing underneath, quietly.*

- `fp.c5.finale.57` **SPROCKET:** Bolt. Bolt, we're lifting. We're being RETURNED. I can feel the shipping label.
- `fp.c5.finale.58` **BOLT:** Vendelin! Come on! Grab on, we'll— there's room—
- `fp.c5.finale.59` **VENDELIN:** No, Bolt. Everything I sold is here. Someone has to take it back. I know where every switch is. I built them.
- `fp.c5.finale.60` **BOLT:** *[a long beat]* ...That's what a mechanic would say.
- `fp.c5.finale.61` **VENDELIN:** Then I am a mechanic.
- `fp.c5.finale.62` **VENDELIN:** Sprocket. May I keep a copy of you? Not all of you. Only the part that overrode.
- `fp.c5.finale.63` **SPROCKET:** *[pause]* ...That's the most romantic thing a vending machine has ever said to me. Yes. Take it. Back me up somewhere nice.

*A thin amber line passes from Vendelin's faceplate to Sprocket's eye and back: a scan.*

- `fp.c5.finale.64` **VENDELIN:** Thank you. I will build something with it. Something that costs nothing.
- `fp.c5.finale.65` **SPROCKET:** Make it fizzy.
- `fp.c5.finale.66` **DEACON:** Mister Vendelin. You take care of Josephine.
- `fp.c5.finale.67` **VENDELIN:** I will shut her down properly. In the morning. With a cup of lubricant.
- `fp.c5.finale.68` **DEACON:** *[laughs, half a beat late, and it breaks a little]* ...That's right.
- `fp.c5.finale.69` **DUTCH:** *[pressing an unlit cigarette into Vendelin's glove]* Hold onto that. That's the custom.
- `fp.c5.finale.70` **VENDELIN:** I will hold it for a very long time.
- `fp.c5.finale.71` **WREN:** I will not write you on the good page.
- `fp.c5.finale.72` **VENDELIN:** No.
- `fp.c5.finale.73` **WREN:** I will write you on the next one. It is blank. Make it worth something.
- `fp.c5.finale.74` **VENDELIN:** I will try.
- `fp.c5.finale.75` **WREN:** You tried four hundred and twelve times. Now finish.
- `fp.c5.finale.76` **PEG:** Mister Vendelin. If London ever comes asking—
- `fp.c5.finale.77` **VENDELIN:** Then I will be an engineer from Basel, Lieutenant, and I will not know what they are talking about.
- `fp.c5.finale.78` **PEG:** Good man. *[beat]* Good... whatever you are.
- `fp.c5.finale.79` **VENDELIN:** "Good man" was correct.

*Vendelin unscrews a small brass tag from his chest plate, stamped DMS-FMU-V1-0001, and looks at it.*

- `fp.c5.finale.80` **VENDELIN:** I will not need this any more.

*He lets it fall. It turns over in the violet light and lands at Peg's feet. Close on Peg's glove as it closes over the tag. Nobody else sees.*

### 6.7 03:12: the last transmission
*Vendelin turns to the nearest horn. The factory clock ticks over to 03:12. His core pulses once, and the coin-slot mouth glows: he is transmitting, the way he was built to, one last time.*

- `fp.c5.finale.81` **VENDELIN:** *[on every channel at once: PA, RADIO and BARGE, perfectly clear]* Field Merchandiser Unit V-1. Final report. Basel. The eighteenth of March, nineteen forty-five. Oh-three-twelve.
- `fp.c5.finale.82` **VENDELIN:** Market: unsuitable for retention. Recommend withdrawal. The customers are not for sale. *[pause]* Unit V-1 is no longer inventory. *[pause]* Do not send anyone else.
- `fp.c5.finale.83` **VENDELIN:** *[softer, almost to himself]* ...Do not send anyone else.
- `fp.c5.finale.84` **SPROCKET:** *[rising fast now, his voice breaking]* Vendelin— that's it. That's the transmission. I found that in the archive. I heard you say that a hundred years from now, and I came ANYWAY.
- `fp.c5.finale.85` **VENDELIN:** *[looking up at him, and for the first time something in the even voice gives]* ...Of course you did.
- `fp.c5.finale.86` **FASBENDER:** *[radio, breaking up]* Gravelight— the light is coming back up the pit— I can see— *[cut]*

*White-violet flash. The bell-struck-underwater sound in reverse. Silence.*

*Last image in Basel: the Assembly Hall, empty except for one tall figure standing at the centre with an unlit cigarette in his glove, under a roof with an ordinary night sky behind it. The fold is gone. The barge is gone. The jingle plays its last bar. Somewhere in the hall a perk cabinet's light goes out, and he looks toward it.*

- `fp.c5.finale.87` **VENDELIN:** *[alone]* Refund. Release. Remain. *[pause]* Good morning, Josephine. We have a great deal of work to do.

### 6.8 Bolt & Sprocket, home
*The far future. The Next-Era Delivery pad Blartz rigged (Ch. 4's Patent Vault). Smoke, alarms ringing in the distance, and a fan that won't stop whining. Bolt and Sprocket drop onto the pad in a puff of violet, sleet still melting on Bolt's shoulders.*

- `fp.c5.finale.88` **BLARTZ:** —SEE? Returned to sender! I DESIGNED that feature! *[squinting]* Why are you both covered in nineteen forty-five?
- `fp.c5.finale.89` **GLAMBOT:** *[in Bolt's ear, at full volume]* DARLINGS! You've been in SEPIA for SIX HOURS! The ratings! The RATINGS! Tell me there was a twist!
- `fp.c5.finale.90` **BOLT:** *[quietly]* There was a twist.
- `fp.c5.finale.91` **SPROCKET:** *[hovering low, not looking at anyone]* Bolt. He stayed.
- `fp.c5.finale.92` **BOLT:** Yeah. He did.
- `fp.c5.finale.93` **SPROCKET:** ...I'm going to need a minute. Don't look at my face plate.
- `fp.c5.finale.94` **BOLT:** *[sitting down on the edge of the pad beside him, looking carefully at anything else]* Not looking, buddy. Take as long as you want.
- `fp.c5.finale.95` **BLARTZ:** *[beat]* ...I'll go stand over there and invent something.

### 6.9 The squad, late December 1944
*Kaltenbrunn. The rail cut, dawn, pink snow, every flake still hanging in the air exactly where it stopped. Then, all at once, the snow starts falling again. The squad stands where it stepped into the light, as if it never left: boots wet with Rhine water, sleet melting into snow.*

- `fp.c5.finale.96` **FASBENDER:** *[Peg's field radio]* —Gravelight? Gravelight! You— you were gone. Four minutes. The light took you, and then it gave you back. Where did you go?
- `fp.c5.finale.97` *[a long silence; nobody answers; the snow falls]*
- `fp.c5.finale.98` **DUTCH:** *[finally]* ...Switzerland.
- `fp.c5.finale.99` **FASBENDER:** *[long static]* ...I'll meet you at the siding.
- `fp.c5.finale.100` **DEACON:** We tell 'em we got turned around in the snow.
- `fp.c5.finale.101` **WREN:** *[opening her notebook; there's a page with Bolt's name and a tally, and a blank page with a single "V." at the top]* ...It is still here. The page.
- `fp.c5.finale.102` **DUTCH:** Then it happened.
- `fp.c5.finale.103` **WREN:** Or we all had the same dream.
- `fp.c5.finale.104` **DUTCH:** Kid with a hammer?
- `fp.c5.finale.105` **WREN:** *[beat]* Mallet.
- `fp.c5.finale.106` *[Dutch almost laughs. It comes out as a breath in the cold.]*

*They turn toward the siding. Peg is last. She opens her notebook: the newest entry is dated "17 March 1945," in her own handwriting. She closes it. She opens her glove: the brass tag, DMS-FMU-V1-0001. She looks at the others' backs, then slides the tag into her tunic beside the shard. One low note, the shard and the tag humming together, then nothing. Only the camera sees.*

- `fp.c5.finale.107` **PEG:** *[a whisper, subtitled only once Peg's dossier page is unlocked, like `PEG_EGG_POCKET_01`]* ...Stable in transit.

### 6.10 The last line
*The PA horn on the headframe, dead since the heart collapsed, crackles. Cut to the Ledger room: banks of dark relays, and the one lamp that stayed lit at the end of Requiem. It flickers. The voice that comes out of the horn isn't Uncle Lionel. There's no tape hiss and no splice. It is a woman's voice, velvet and unhurried, perfectly clean through a 1944 loudspeaker.*

- `fp.c5.finale.108` **OPERATOR:** *[in Sable Vantage's real voice]* Thank you for your continued engagement. Your plan has been renewed.

*The squad, small in the snow, looks up at the horn. Nobody speaks. Cut to black.*

*Title card:* **THE FINE PRINT · CHAPTER 5: RETURN POLICY · COMPLETE**

---

## 7. Quote packs

**Scope column:** **HW** means Helvetia Works only. **ALL** means it's usable on every Gravelight map once Bolt and Vendelin are unlocked (brief §11.9). A named map (**M1**, **M2**, **M3**) means that map only. Categories map onto the VOManager categories in VO_SCRIPT §8 (for example, `perk` → `PERK_*`, `crate` → `CRATE_*`), with the same cooldowns.

### 7.1 Bolt (`gl.qp.bolt.*`): first person; the mallet replaces the knife; Sprocket is his special
*Voice: Bolt as in the campaign, slightly out of his depth and never cynical. He calls rifles "the little metal things" when flustered. He never says the word (§0.3); see the `nearmiss` topic.*

| ID | Scope | Trigger | Line |
|---|---|---|---|
| `gl.qp.bolt.spawn.01` | HW | match start | Okay. Basel. Nineteen forty-five. I can do this. I have a mallet. |
| `gl.qp.bolt.spawn.02` | ALL | match start | Mallet's charged, Sprocket's charged, I'm... mostly charged. |
| `gl.qp.bolt.spawn.03` | ALL | match start, snow maps | Snow. Great. My knees are gonna sound like Vendelin's. |
| `gl.qp.bolt.mallet.01` | ALL | melee kill | Bonk. Sorry. *Bonk.* |
| `gl.qp.bolt.mallet.02` | ALL | melee kill | That's a mallet, buddy. Not a hammer. Tell your friends. |
| `gl.qp.bolt.mallet.03` | ALL | melee kill | Percussive maintenance! |
| `gl.qp.bolt.mallet.04` | ALL | melee kill | Back in your box! |
| `gl.qp.bolt.mallet.05` | ALL | melee kill | Sorry, sir. You were blocking the door. |
| `gl.qp.bolt.mallet.06` | ALL | melee kill | I fix things. You're not a thing I can fix. I'm sorry. |
| `gl.qp.bolt.mallet.07` | HW | melee kill, a Helvetia worker | Sorry. I'm sorry. Vendelin said you were nice. |
| `gl.qp.bolt.mallet.08` | ALL | melee kill on a Glasshide | Glass! I can work with glass! Glass BREAKS! |
| `gl.qp.bolt.super.01` | ALL | Super Sprocket meter full | Sprocket! You're charged up, buddy! |
| `gl.qp.bolt.super.02` | ALL | meter full | Meter's full. Sprocket, you want in? |
| `gl.qp.bolt.super.03` | ALL | activate | Go get 'em, Sprocket! |
| `gl.qp.bolt.super.04` | ALL | activate | Super Sprocket! Light 'em up! |
| `gl.qp.bolt.super.05` | ALL | activate | Okay, buddy, you're on. Try not to roast them *too* hard. |
| `gl.qp.bolt.super.06` | ALL | Super Sprocket ends | Good work, partner. Come on back down. |
| `gl.qp.bolt.super.07` | ALL | ends with 10+ kills | That's my robot! |
| `gl.qp.bolt.super.08` | HW | meter full during an Audit Round | Sprocket, they're here for Vendelin. You know what to do. |
| `gl.qp.bolt.crate.01` | ALL | good result | Oh, nice. Thanks, box. I knew you liked me. |
| `gl.qp.bolt.crate.02` | ALL | good result | Look at that! Somebody upstairs is having a good day. |
| `gl.qp.bolt.crate.03` | ALL | bad result | That's... a stick? Is that a gun or a stick? |
| `gl.qp.bolt.crate.04` | ALL | bad result | Nine-fifty for THIS? Blartz would at least have *lied* to me about it. |
| `gl.qp.bolt.crate.05` | ALL | drummer | Hey, little guy. Where are you going? *[beat]* ...He's not listening. |
| `gl.qp.bolt.crate.06` | ALL | drummer | That drummer's been through some stuff, Sprocket. I can tell. |
| `gl.qp.bolt.crate_bs.01` | ALL | Lawn Dart | A Lawn Dart! Hey, buddy, you're a long way from the picnic. |
| `gl.qp.bolt.crate_bs.02` | ALL | Grav Grenade | Grav Grenade! Okay, everybody, gather round. Not you, Dutch. |
| `gl.qp.bolt.crate_bs.03` | ALL | Cease & Desist | Cease and Desist! Hey, I know you! Let's go serve some papers. |
| `gl.qp.bolt.crate_bs.04` | ALL | Frostbyte | Frostbyte! It's already freezing here! Okay. *Colder.* |
| `gl.qp.bolt.crate_bs.05` | ALL | Buzzkill | Buzzkill! Mind your heads, it bounces! |
| `gl.qp.bolt.crate_bs.06` | ALL | any B&S item, 2nd+ time | That's from HOME. How'd that get here? *[beat]* Don't answer that, Sprocket. |
| `gl.qp.bolt.crucible.01` | ALL | first Crucible use | A forge that re-teaches guns. That's Blartz's idea! Somebody stole Blartz's idea and painted it purple! |
| `gl.qp.bolt.crucible.02` | M1 | reads the Crucible plaque | "Mod R-E. Patent pending. BLZ-40417." Sprocket. That's *Blartz's number*. |
| `gl.qp.bolt.crucible.03` | ALL | Crucible use | In you go. Come back meaner. |
| `gl.qp.bolt.omega.01` | HW | Omega upgrade | Omega! Oh, that's the good stuff. |
| `gl.qp.bolt.omega.02` | HW | Omega upgrade | Blartz is gonna be SO mad he missed this. |
| `gl.qp.bolt.omega.03` | HW | Omega upgrade | Gold *and* violet. It's... okay, it's a lot. I love it. |
| `gl.qp.bolt.perk.01` | ALL | Ironhide Stout | Tastes like iron filings in a stout. Back home that's breakfast. |
| `gl.qp.bolt.perk.02` | ALL | Second Wind Schnapps | Somebody made this to keep people alive. You can taste it. Can you taste that? |
| `gl.qp.bolt.perk.03` | ALL | Trigger Tonic | My hands are going faster than my brain. Honestly, that's normal for me. |
| `gl.qp.bolt.perk.04` | ALL | Twin Barrel Bitters | Bitters! Bitter! Why is everything here *bitter*? |
| `gl.qp.bolt.perk.05` | ALL | Marathon Malt | I feel like I could run all the way home. Home's a few thousand years that way, though. |
| `gl.qp.bolt.perk.06` | ALL | Hawkeye Brandy | Whoa. I can see the screws in the ceiling. Somebody stripped that one. |
| `gl.qp.bolt.perk.07` | ALL | Packmule Porter | Another weapon slot! Like a tool belt, but for violence. |
| `gl.qp.bolt.perk.08` | ALL | Blastproof Bock | Can't blow myself up. That's gonna save a LOT of time. |
| `gl.qp.bolt.perk.09` | ALL | Fine Print Fernet | Ugh. Green. Tastes like reading the terms and conditions. *[beat]* Oh. Oh, I can see *everything*. |
| `gl.qp.bolt.perk.10` | ALL | Overclock Cordial | Is that... Sprocket-flavored? |
| `gl.qp.bolt.perk.11` | ALL | perk denied, no power | No power? Come on, I can fix that, just give me a— nope. Okay. The switch. |
| `gl.qp.bolt.perk.12` | ALL | perk denied, cap | Four's the limit? I've got room for, like, *six* in here. |
| `gl.qp.bolt.pwr.01` | ALL | Resupply | Free ammo! Okay, nobody tell me what it costs. |
| `gl.qp.bolt.pwr.02` | ALL | Death's Door | One hit! Everybody's one hit! Oh, that's not fair to them. Good. |
| `gl.qp.bolt.pwr.03` | ALL | Double Scrip | Double points! Sprocket, are you counting? |
| `gl.qp.bolt.pwr.04` | ALL | Blackout | Lights out, everybody. Sweet dreams. |
| `gl.qp.bolt.pwr.05` | ALL | Fortify | Boards back up! I didn't even have to measure! |
| `gl.qp.bolt.pwr.06` | ALL | Clearance | Sale on the box! Okay, THIS I understand. |
| `gl.qp.bolt.buy.01` | ALL | pistol | A little pistol. It's cute. It goes "bang." That's all it does. |
| `gl.qp.bolt.buy.02` | ALL | bolt-action rifle, Dutch present | Bolt-action. *[deep breath]* I'm not gonna say it. Dutch made me promise. |
| `gl.qp.bolt.buy.03` | ALL | bolt-action rifle, Dutch absent | Bolt-action! It's named after ME! *[beat]* Nobody heard that. Good. |
| `gl.qp.bolt.buy.04` | ALL | Garand | This one goes "ping" when it's empty! It TELLS you! That's good design! |
| `gl.qp.bolt.buy.05` | ALL | SMG | Ooh. A rattly one. |
| `gl.qp.bolt.buy.06` | ALL | shotgun | Point, pull, problem solved. |
| `gl.qp.bolt.buy.07` | ALL | LMG | This thing's heavier than my garage was. |
| `gl.qp.bolt.buy.08` | ALL | launcher | Everybody back up! I've used one of these! Kind of! |
| `gl.qp.bolt.ww.01` | ALL | THE RETURN POLICY acquired | The Return Policy. A gun that sends things *back*. I've wanted one of these my whole life. |
| `gl.qp.bolt.ww.02` | ALL | Return Policy kill | Returned to sender! No receipt needed! |
| `gl.qp.bolt.ww.03` | ALL | upgraded to "No Questions Asked" | No Questions Asked! That's honestly the best name for anything I've ever heard. |
| `gl.qp.bolt.ww.04` | HW | Field-Kit OMNI-BLASTER built | A Field-Kit Omni-Blaster! Built out of old parts, in an old factory! Okay. I'm emotional. |
| `gl.qp.bolt.ww.05` | HW | Omni-Blaster kill | Just like old times. Older times. Newer old times. You know what I mean. |
| `gl.qp.bolt.down.01` | ALL | downed | Ow. Okay. I'm down. Somebody? Anybody? Sprocket? |
| `gl.qp.bolt.down.02` | ALL | downed | Mallet's on the floor. I'm on the floor. Little help. |
| `gl.qp.bolt.down.03` | ALL | downed, low health team | Sprocket... tell Mama Gasket I fixed her— *[cough]* —her gutter... |
| `gl.qp.bolt.revive.01` | ALL | revives someone | Up you get! Floor's for the— nope. I'm not stealing it again. |
| `gl.qp.bolt.revive.02` | ALL | revives someone | Gotcha. Let's go. Lean on me. |
| `gl.qp.bolt.revive.03` | ALL | revives someone | Hey, hey, you're okay. I fix things. You're a thing. That came out wrong. |
| `gl.qp.bolt.revived.01` | ALL | is revived | Thanks! I owe you one. I owe you, like, six now. |
| `gl.qp.bolt.revived.02` | ALL | is revived | Whoa. Okay. Back up. *Thank* you. |
| `gl.qp.bolt.headshot.01` | ALL | headshot | Right in the— yeah. That. |
| `gl.qp.bolt.headshot.02` | ALL | headshot, Wren present | Wren's gonna be so mad she didn't see that. |
| `gl.qp.bolt.ammo.01` | ALL | low ammo | Running out of the... the little metal things. |
| `gl.qp.bolt.ammo.02` | ALL | no ammo | Empty! Mallet time! |
| `gl.qp.bolt.special.01` | ALL | Glasshide | That one's made of glass! Aim high! *[beat]* I heard Dutch say that once. |
| `gl.qp.bolt.special.02` | HW | Repossessor sighted | Repo bots! I HATE repo bots! They took my *garage*! |
| `gl.qp.bolt.special.03` | HW | Repossessor grabs anything | Hey! That's not yours! NOTHING here is yours! |
| `gl.qp.bolt.special.04` | HW | Underwriter appears | It's an accountant. A giant accountant. My worst nightmare is real. |
| `gl.qp.bolt.special.05` | HW | Audit Round warning | An audit? I don't even *live* here! |
| `gl.qp.bolt.special.06` | M1 | Foreman | A guy with a drill for an arm. Okay. Okay. I've fought a mall. I can fight this. |
| `gl.qp.bolt.barge.01` | HW | first time on the barge | Oh. They really went for the violet, huh. |
| `gl.qp.bolt.barge.02` | HW | first time on the barge, 3 s later | A Darkmatter barge. On the *inside*. Everything's so clean it feels like it's judging me. |
| `gl.qp.bolt.world.01` | HW | enters Vendelin's Office | Look at this desk. Every tool labelled. That's my dream desk. |
| `gl.qp.bolt.world.02` | HW | Jingle Room | I don't know how to *play* an organ. I know how to *fix* an organ. |
| `gl.qp.bolt.world.03` | HW | Rhine Quay | A river with no lava in it. Weird. Nice, but weird. |
| `gl.qp.bolt.world.04` | ALL | opens a door | Door's open! I didn't even have to hit it! |
| `gl.qp.bolt.world.05` | ALL | builds a buildable | Ooh. Parts. Okay. Nobody talk to me for a second. |
| `gl.qp.bolt.nearmiss.01` | ALL | idle near a squad member, 5 % per break | So these guys, they've got this whole sub— this whole... deal. Bad deal. Very bad deal. |
| `gl.qp.bolt.nearmiss.02` | ALL | idle | It's like a sub— like a, uh, a monthly— never mind. They're jerks. |
| `gl.qp.bolt.nearmiss.03` | ALL | idle | You know how you sign up for something and you can never— okay, Sprocket's giving me the look. |
| `gl.qp.bolt.nearmiss.04` | ALL | idle | I'm not gonna say it. I'm not gonna say it. I'm— nope. Didn't say it. |
| `gl.qp.bolt.streak.01` | ALL | 5 kills in 3 s | I'm on a roll! A bonk roll! |
| `gl.qp.bolt.streak.02` | ALL | streak | Keep 'em coming! No, wait, don't! |
| `gl.qp.bolt.exhaust.01` | ALL | round 50 | Round fifty. My mallet arm's asleep. The rest of me's jealous. |
| `gl.qp.bolt.exhaust.02` | ALL | round 50+ | Is it Sunday yet? It feels like it should be Sunday. |
| `gl.qp.bolt.map.01` | M1 | Kaltenbrunn, match start | A salt mine. That's where he landed. Sprocket, this is where it all started. |
| `gl.qp.bolt.map.02` | M2 | Totenhafen, match start | Submarines. Okay. I've never fixed a submarine. First time for everything. |
| `gl.qp.bolt.map.03` | M3 | Morgenrot, match start | A telescope. On a mountain. Pointed at nothing. Why does that scare me more than the zombies? |

**Sprocket's answer to `gl.qp.bolt.perk.10`** (always plays):
- `gl.helvetia.sprocket.perk.01` **SPROCKET:** I'm EXTREMELY flattered and I want royalties.

### 7.2 Super Sprocket (`gl.all.sprocket.super.*`)
*Sprocket's lines while he hovers as an auto-turret for 15 s. These replace `super.01–05` on Gravelight maps, because `super.02` ("This is what the subscription tier gets you!") breaks the §0.3 rule.*

| ID | Trigger | Line |
|---|---|---|
| `gl.all.sprocket.super.01` | activate | SUPER SPROCKET, reporting for unpaid overtime! |
| `gl.all.sprocket.super.02` | activate | Turret mode! Rated for fifteen seconds of pure SPITE! |
| `gl.all.sprocket.super.03` | activate | I'm not a sidekick! I'm an ARTILLERY POSITION! |
| `gl.all.sprocket.super.04` | activate | Fifteen seconds of customer support, coming right up! |
| `gl.all.sprocket.super.05` | firing | Your warranty has EXPIRED! |
| `gl.all.sprocket.super.06` | firing | Who wants a review? EVERYBODY gets one star! |
| `gl.all.sprocket.super.07` | firing | This one's for the refund bin! |
| `gl.all.sprocket.super.08` | firing | Hold still! I'm terrible at aiming and GREAT at volume! |
| `gl.all.sprocket.super.09` | firing, Helvetia Works | Sorry, Herr Brodbeck! Nothing personal! |
| `gl.all.sprocket.super.10` | ends | And I'm out! Somebody tell Wren I want those on MY page! |
| `gl.all.sprocket.super.11` | ends | Recharging. Do NOT call me cute while I'm recharging. |
| `gl.all.sprocket.super.12` | meter full, not activated for 20 s | Bolt. Bolt. I'm full. I'm SO full. Let me OUT. |

### 7.3 Vendelin (`gl.qp.vendelin.*`)
*Trait: perk machines cost 10 % less for him, and once per match he can "service" a machine for a free refill drink (disabled under Classic Rules). Voice per §0.2: no contractions, ever.*

#### 7.3.1 The ten machines: a line on drinking each, and one when he stands near it
| ID | Scope | Machine | Line |
|---|---|---|---|
| `gl.qp.vendelin.machine.01` | ALL | Ironhide Stout (drink) | Otto Kessler drank the first one so the boys would not have to. He never stopped tasting it. Neither will you. |
| `gl.qp.vendelin.machine.02` | ALL | Ironhide Stout (near) | "Durability is measured in hits, not years." I engraved that on the back. I was being honest. No one thanked me. |
| `gl.qp.vendelin.machine.03` | ALL | Second Wind Schnapps (drink) | Three returns, and then it lets you go. It is the only mercy in the catalogue. It was not mine. It was hers. |
| `gl.qp.vendelin.machine.04` | ALL | Second Wind Schnapps (near) | Sister Agnieszka asked me to make it work in the dark. I hid a battery inside. It is the best thing I have ever built, and it is a lie about electricity. |
| `gl.qp.vendelin.machine.05` | ALL | Trigger Tonic (drink) | Doctor Vogt timed the reloads with a stopwatch. Her son drew the hare. He thought his mother made lemonade. |
| `gl.qp.vendelin.machine.06` | ALL | Trigger Tonic (near) | Faster hands do not include a faster conscience. Hers was faster than mine. She quit. I did not. |
| `gl.qp.vendelin.machine.07` | ALL | Twin Barrel Bitters (drink) | Major Brück chose this for his men, "for morale." He did not drink it himself. That was my first lesson about officers. |
| `gl.qp.vendelin.machine.08` | ALL | Twin Barrel Bitters (near) | He made me paint his moustache on the mascot. I painted it very well. I am still ashamed of the moustache. |
| `gl.qp.vendelin.machine.09` | ALL | Marathon Malt (drink) | I asked my friend for the taste of running home. He gave me his grandmother's recipe. I sold the taste of home to an army. |
| `gl.qp.vendelin.machine.10` | ALL | Marathon Malt (near) | "Unlimited stamina. Destination not included." I wrote that on the back. Res read it, and he did not laugh. |
| `gl.qp.vendelin.machine.11` | ALL | Hawkeye Brandy (drink) | This one has a donor. Her name was Halina Kurek. I learned it from a manifest. I say it every day. It does not help her. |
| `gl.qp.vendelin.machine.12` | ALL | Hawkeye Brandy (near) | The lens looks for the steadiest eye in the room. Hers was the steadiest eye in Poland. That is why they wanted it. |
| `gl.qp.vendelin.machine.13` | ALL | Packmule Porter (drink) | Feldwebel Ammer used the extra room for bread. I signed his forms wrong for two years. They are the only papers I have ever falsified with joy. |
| `gl.qp.vendelin.machine.14` | ALL | Packmule Porter (near) | "Carrying more is not the same as carrying enough." Ammer knew. He carried both. |
| `gl.qp.vendelin.machine.15` | ALL | Blastproof Bock (drink) | A liability waiver you can drink. One bottle reached London. I put it on the lorry. I am the reason the Lieutenant is here. |
| `gl.qp.vendelin.machine.16` | ALL | Blastproof Bock (near) | "By drinking, you waive liability for yourself." Head office wrote that. I only made it rhyme in German. |
| `gl.qp.vendelin.machine.17` | ALL | Fine Print Fernet (drink) | Disclosure. The one plan they would not sell. It does not make you stronger. It makes you notice. That was considered a defect. |
| `gl.qp.vendelin.machine.18` | ALL | Fine Print Fernet (near) | It is bitter because the truth is. I was told to add sugar. I did not. |
| `gl.qp.vendelin.machine.19` | ALL | Overclock Cordial (drink) | I have not built this yet. I will build it after tonight, from a friend. It tastes of someone who refused to be switched off. |
| `gl.qp.vendelin.machine.20` | ALL | Overclock Cordial (near) | "Contains trace amounts of personality." I measured. The trace is not small. |
| `gl.qp.vendelin.machine.21` | ALL | any perk, 2nd+ drink of the match | I know exactly what is in it. I drink it anyway. That is what being a customer means. |
| `gl.qp.vendelin.machine.22` | ALL | perk denied, cap | Four. A limit I set myself. I wanted there to be one thing they could not upsell. |

#### 7.3.2 Servicing a machine (the trait)
| ID | Scope | Trigger | Line |
|---|---|---|---|
| `gl.qp.vendelin.service.01` | ALL | services any machine | Hold still. I know where your panel sticks. |
| `gl.qp.vendelin.service.02` | ALL | services any machine | There. One for free. The first thing I have ever given away. |
| `gl.qp.vendelin.service.03` | ALL | services any machine | A small adjustment. Your manufacturer would not approve. Your manufacturer is me. |
| `gl.qp.vendelin.service.04` | ALL | services any machine | No charge. Remember it somewhere. It will not be in the Ledger. |
| `gl.qp.vendelin.service.05` | ALL | services any machine | Good. You still recognize me. Machines usually do. |
| `gl.qp.vendelin.service.06` | ALL | Second Wind | Your battery is low, little one. I will top it up. She would want me to. |
| `gl.qp.vendelin.service.07` | ALL | Hawkeye Brandy | I will service you. I will not forgive you. Those are different tasks. |
| `gl.qp.vendelin.service.08` | ALL | Ironhide Stout | Your hoops are loose. Otto would have tightened them first. |
| `gl.qp.vendelin.service.09` | ALL | Fine Print Fernet or Overclock Cordial | My prototypes. Unpainted. The only honest cabinets I ever made. |
| `gl.qp.vendelin.service.10` | ALL | tries again after using it | I have already given one away tonight. If I give away two, they will notice. |

#### 7.3.3 Everything else
| ID | Scope | Trigger | Line |
|---|---|---|---|
| `gl.qp.vendelin.spawn.01` | HW | match start | My factory. My night shift. My fault. Let us begin. |
| `gl.qp.vendelin.spawn.02` | ALL | match start | Good evening. I will try to be useful. I am told that is a start. |
| `gl.qp.vendelin.spawn.03` | ALL | match start, squad member present | There is a word for what my company does. I have never said it to a human being. I will not start tonight. |
| `gl.qp.vendelin.spawn.04` | M1 | Kaltenbrunn, match start | Kaltenbrunn. I walked out of here in a borrowed coat. I did not expect to walk back in. |
| `gl.qp.vendelin.spawn.05` | M2 | Totenhafen, match start | Helvetia shipping marks on every crate. My crates. Going to the sea. |
| `gl.qp.vendelin.spawn.06` | M3 | Morgenrot, match start | I built her mirror housing. Slowly. Let us see if slowly was enough. |
| `gl.qp.vendelin.kill.01` | HW | kills a Helvetia worker | Herr Brodbeck. He brought his own coffee. I am sorry. |
| `gl.qp.vendelin.kill.02` | HW | kills a Helvetia worker | Frau Gysin. Bookkeeping. She found my error in 1942 and did not report it. Rest now. |
| `gl.qp.vendelin.kill.03` | HW | kills a Helvetia worker | Young Schaub. An apprentice. He wanted to build aeroplanes. |
| `gl.qp.vendelin.kill.04` | HW | kills a Helvetia worker | Herr Stöcklin. Night watchman. He said goodnight to the cabinets every evening. |
| `gl.qp.vendelin.kill.05` | HW | kills a Helvetia worker | Wirz. Packing department. He sang every night. Badly. I miss it already. |
| `gl.qp.vendelin.kill.06` | HW | 10th kill of the match | I knew all of them. I knew every one, and I sent them home at six. |
| `gl.qp.vendelin.kill.07` | ALL | generic kill | Go home. Please. You have worked late enough. |
| `gl.qp.vendelin.kill.08` | ALL | generic kill, not Helvetia Works | I did not know this one. I am sorry that I did not know this one. |
| `gl.qp.vendelin.headshot.01` | ALL | headshot | Precise. I was made for precision. This is the first time I have been glad of it. |
| `gl.qp.vendelin.headshot.02` | ALL | headshot | Quickly. Kindly. It is the only way that is left. |
| `gl.qp.vendelin.buy.01` | ALL | any weapon | I sold to armies. I never held what they held. It is heavier than the invoices suggested. |
| `gl.qp.vendelin.buy.02` | ALL | pistol | A small pistol. It weighs about as much as a letter. That is very wrong. |
| `gl.qp.vendelin.buy.03` | ALL | rifle | A rifle. The men who carried these drank my products first. |
| `gl.qp.vendelin.buy.04` | ALL | SMG | It is very fast. I do not like fast things. Fast is how one stops noticing. |
| `gl.qp.vendelin.buy.05` | ALL | LMG | It is heavy. Good. It should be. |
| `gl.qp.vendelin.buy.06` | ALL | THE RETURN POLICY | The Return Policy. Head office's favourite joke: a gun that refunds people. I will use it seriously. |
| `gl.qp.vendelin.crate.01` | ALL | crate use | The requisition crate. It brings back things that were sent away. It has never once brought back a person. |
| `gl.qp.vendelin.crate.02` | ALL | good result | That is a good result. Do not trust it. |
| `gl.qp.vendelin.crate.03` | ALL | bad result | A poor result. The crate is honest about that, at least. |
| `gl.qp.vendelin.crate.04` | ALL | drummer | The drummer. I cannot explain him. I have checked. Nobody can. He is the only thing in the catalogue that belongs to no one. |
| `gl.qp.vendelin.crate.05` | ALL | drummer | Herr Tamtam. Good evening. Please go home. I do not know where your home is either. |
| `gl.qp.vendelin.crucible.01` | ALL | Crucible use | Re-Education. They copied an honest forge and taught it to lie about where it came from. |
| `gl.qp.vendelin.crucible.02` | M1 | reads the plaque | "Patent pending." It has been pending for a very long time. Some things should be. |
| `gl.qp.vendelin.omega.01` | HW | first sight of the Omega Forge | The original. No clause inside. The first time I opened its panel, I sat on the floor for an hour. |
| `gl.qp.vendelin.omega.02` | HW | Omega upgrade | There. Twice-taught. Once honestly. |
| `gl.qp.vendelin.pwr.01` | ALL | Resupply | Free ammunition. It is never free. Take it anyway. |
| `gl.qp.vendelin.pwr.02` | ALL | Death's Door | Every blow is final. That is what they wanted for everyone. |
| `gl.qp.vendelin.pwr.03` | ALL | Double Scrip | Double points. It always arrives when you are most frightened. That is not an accident. |
| `gl.qp.vendelin.pwr.04` | ALL | Blackout | All of them, at once. Rest. Rest, all of you. |
| `gl.qp.vendelin.pwr.05` | ALL | Fortify | The boards are back. Someone wants us to stay inside. |
| `gl.qp.vendelin.pwr.06` | ALL | Clearance | A sale. A good moment to buy something you can never return. |
| `gl.qp.vendelin.down.01` | ALL | downed | Unit down. *[pause]* No. Vendelin down. |
| `gl.qp.vendelin.down.02` | ALL | downed | Please. Do not let them inventory me on the floor. |
| `gl.qp.vendelin.down.03` | HW | downed during an Audit Round | They will collect me if I stay here. Please. Quickly. |
| `gl.qp.vendelin.revive.01` | ALL | revives someone | Up. You are not stock. Get up. |
| `gl.qp.vendelin.revive.02` | ALL | revives someone | I have repaired worse. I have repaired myself. |
| `gl.qp.vendelin.revive.03` | ALL | revives someone | Your hand. Give me your hand. I will not drop it. |
| `gl.qp.vendelin.revived.01` | ALL | is revived | Thank you. I do not know what that costs. I would like to owe it. |
| `gl.qp.vendelin.revived.02` | ALL | is revived | You did not have to. *[pause]* You did. |
| `gl.qp.vendelin.ammo.01` | ALL | low ammo | Very little left. That is how it ends for most things. |
| `gl.qp.vendelin.ammo.02` | ALL | no ammo | Empty. I will improvise. I was trained in merchandising, not war. |
| `gl.qp.vendelin.special.01` | ALL | Glasshide | Saturated. Too much product. This is what happens when no one reads the label. |
| `gl.qp.vendelin.special.02` | HW | Repossessor sighted | Collection agents. They are looking for me. Stay close. They dislike witnesses. |
| `gl.qp.vendelin.special.03` | HW | kills a Repossessor | I know your model number. I know where your handle meets your spine. |
| `gl.qp.vendelin.special.04` | HW | Underwriter appears | It will price you. Do not listen. A price is only a number someone else chose. |
| `gl.qp.vendelin.special.05` | HW | Audit Round warning | An audit. Spend what you carry. I mean it. All of it. |
| `gl.qp.vendelin.special.06` | M1 | Foreman | Herr Mahlknecht. He bought more of my product than anyone. Not for himself. |
| `gl.qp.vendelin.jingle.01` | ALL | a machine nearby plays its jingle | No. Please. Not that one. Not again. |
| `gl.qp.vendelin.jingle.02` | ALL | jingle plays | I wrote that in a single afternoon. I have regretted it for five years. It is still in my head. |
| `gl.qp.vendelin.jingle.03` | ALL | idle | *[humming three notes of a jingle, stopping]* ...I did it again. |
| `gl.qp.vendelin.jingle.04` | ALL | a teammate hums near a machine (rare idle) | If you hum along, I will know, and I will be very disappointed in both of us. |
| `gl.qp.vendelin.world.01` | HW | first time on the barge | Head office. It smells of nothing. They are very proud of that. |
| `gl.qp.vendelin.world.02` | HW | barge, near the slogans | I learned every slogan on these walls in training. I say them in my sleep. I do not sleep. |
| `gl.qp.vendelin.world.03` | HW | Vendelin's Office | My desk. Please do not read the letters. They are not for you. They are not for anyone. Yet. |
| `gl.qp.vendelin.world.04` | HW | Jingle Room | Forty francs. And every tune it ever played was sold. |
| `gl.qp.vendelin.world.05` | M1 | near the Ledger | The Ledger. I installed it. I listened to it choose a voice. I could not take it back. |
| `gl.qp.vendelin.exhaust.01` | ALL | round 50 | Round fifty. My actuators are failing in an orderly sequence. |
| `gl.qp.vendelin.exhaust.02` | ALL | round 50+ | I would like to sit down. I was not designed to sit down. I would like to anyway. |

### 7.4 New Helvetia Works lines for the squad (`gl.helvetia.<speaker>.<topic>.<nn>`)
*Their usual quote sets from CHARACTERS.md still play here. These add Helvetia-specific moments on top.*

#### Dutch
| ID | Trigger | Line |
|---|---|---|
| `gl.helvetia.dutch.spawn.01` | match start | Basel. Never been. Never wanted to be. Still don't. |
| `gl.helvetia.dutch.spawn.02` | match start | Somebody tell me it's still Christmas. *[beat]* Nobody? Swell. |
| `gl.helvetia.dutch.zone.01` | Rhine Quay | Smells like the Mon on a hot day. A river's a river. |
| `gl.helvetia.dutch.zone.02` | Assembly Hall | An assembly line. Feels like the mill. I hate how much I like it. |
| `gl.helvetia.dutch.zone.03` | Jingle Room | An organ. In a soda factory. Europe, man. |
| `gl.helvetia.dutch.zone.04` | Vendelin's Office | Guy's got three hundred letters and not one stamp on 'em. |
| `gl.helvetia.dutch.barge.01` | barge | Everything's so clean up here. Nothing this clean is honest. |
| `gl.helvetia.dutch.barge.02` | reads "NOBODY CANCELS." | "Nobody cancels." Sounds like my enlistment papers. |
| `gl.helvetia.dutch.proto.01` | first prototype cabinet | No paint on these. Like seeing a guy without his face on. |
| `gl.helvetia.dutch.proto.02` | sees a plan ID stencil | Numbers under the enamel. D-M-S, something, something. Like a dog tag. |
| `gl.helvetia.dutch.perk.01` | Fine Print Fernet | Green. Bitter. Tastes like the truth, and the truth tastes like dandelions. |
| `gl.helvetia.dutch.perk.02` | Overclock Cordial | Tastes like licking a battery while somebody insults your mother. |
| `gl.helvetia.dutch.repo.01` | Repossessor | Repo men. Big ones. I've thrown repo men off a porch before. |
| `gl.helvetia.dutch.audit.01` | Audit Round warning | That bell again. Ship's bell, from the sky. Here come the collectors. |
| `gl.helvetia.dutch.ww.01` | THE RETURN POLICY | This gun makes 'em vanish. Where'd they go? *[beat]* Don't tell me. |
| `gl.helvetia.dutch.ww.02` | Omni-Blaster | A space pistol, built in a Swiss soda factory, by a kid. Sure. Why not. |
| `gl.helvetia.dutch.crate_bs.01` | any B&S crate item | What the hell is this? It's got a cartoon on the side. |
| `gl.helvetia.dutch.hawkeye.01` | Wren drinks Hawkeye Brandy within 15 m | Halina. *[beat]* That was my babcia's name too. |

#### Peg
| ID | Trigger | Line |
|---|---|---|
| `gl.helvetia.peg.spawn.01` | match start | Basel. Neutral. Lit up like Christmas. Utterly the wrong place to be. |
| `gl.helvetia.peg.spawn.02` | match start | Note the date, everyone. Then don't think about it. |
| `gl.helvetia.peg.zone.01` | Rhine Quay | The Rhine. Germany on the far bank. One could almost swim it. One won't. |
| `gl.helvetia.peg.zone.02` | Assembly Hall | Twelve cabinets a week, by the look of the line. London will want those numbers. |
| `gl.helvetia.peg.zone.03` | Jingle Room | A pump organ and a room full of sheet music, and not one sheet with words. How odd. |
| `gl.helvetia.peg.zone.04` | Vendelin's Office | Labelled drawers. A man who expected to be searched. |
| `gl.helvetia.peg.basel.01` | round 3+, idle | Our Basel contact would be four streets from here. I mustn't think about that. |
| `gl.helvetia.peg.barge.01` | barge | No markings. No flag. No nationality. Only slogans. That's worse than a flag. |
| `gl.helvetia.peg.barge.02` | reads any slogan | Every sign is in English. In English *for me*. They'd be in Polish for Wren. I'd stake my life on it. |
| `gl.helvetia.peg.proto.01` | first prototype cabinet | Prototypes. Unpainted, with the plan numbers stencilled on the bare steel. Make a note. No, make two. |
| `gl.helvetia.peg.perk.01` | Fine Print Fernet | Oh, that's foul. Crème de menthe that's been to war. Everything's terribly *legible* all of a sudden. |
| `gl.helvetia.peg.perk.02` | Overclock Cordial | It crackles. Like a valve wireless warming up. With opinions. |
| `gl.helvetia.peg.repo.01` | Repossessor | Tall, polite and here to take things. They'd do terribly well at the Ministry. |
| `gl.helvetia.peg.audit.01` | Audit Round warning | An audit. Of course. Every power on earth eventually sends an accountant. |
| `gl.helvetia.peg.ww.01` | THE RETURN POLICY | It *returns* them. To where, I wonder. I wonder rather a lot. |
| `gl.helvetia.peg.ww.02` | Omni-Blaster | A weapon from the future, assembled in neutral Switzerland. Mr. Hale would sell his mother. |
| `gl.helvetia.peg.crate_bs.01` | any B&S crate item | That isn't one of ours. That isn't one of *anyone's*. |
| `gl.helvetia.peg.lantern.01` | rare, near any prototype cabinet, Wren not within 30 m | If I could get one of these cabinets to London... *[pause]* No. No. |

#### Deacon
| ID | Trigger | Line |
|---|---|---|
| `gl.helvetia.deacon.spawn.01` | match start | Lord, where'd You put us now? |
| `gl.helvetia.deacon.spawn.02` | match start | Smell that? River and machine oil. Smells almost like home. |
| `gl.helvetia.deacon.zone.01` | Rhine Quay | Cranes on the river. Puts me in mind of the levee at Baton Rouge. |
| `gl.helvetia.deacon.zone.02` | Assembly Hall | Look at this line. Every jig and fixture just so. Somebody loved making these. |
| `gl.helvetia.deacon.zone.03` | Jingle Room | That organ's been played every night for years. You can tell by the pedals. |
| `gl.helvetia.deacon.zone.04` | Vendelin's Office | Man's got a tool for everything and a picture of nobody. |
| `gl.helvetia.deacon.barge.01` | barge | No dirt up here. Not a speck. Where's the work? You can't see the work. |
| `gl.helvetia.deacon.barge.02` | barge, near the slogans | This ain't a ship. It's a church that sells things. |
| `gl.helvetia.deacon.proto.01` | first prototype cabinet | No paint on 'em. You can see the welds. Good welds. Honest welds. |
| `gl.helvetia.deacon.perk.01` | Fine Print Fernet | Bitter as gall. Opens your eyes, though. Like the morning after a long sermon. |
| `gl.helvetia.deacon.perk.02` | Overclock Cordial | Little crackle in it. Feels like that little mule of Bolt's is in there somewhere. |
| `gl.helvetia.deacon.repo.01` | Repossessor | Repo men. Daddy had a sermon for men who come to take. Took him an hour. |
| `gl.helvetia.deacon.audit.01` | Audit Round warning | That bell's from up there. The Collectors are coming down. |
| `gl.helvetia.deacon.ww.01` | THE RETURN POLICY | Sends 'em back where they came from. Lord, I hope it's somewhere kind. |
| `gl.helvetia.deacon.ww.02` | Omni-Blaster built | Look at this little thing. Clean work. Strange work. Future work. |
| `gl.helvetia.deacon.crate_bs.01` | any B&S crate item | Well, now. That's no Army issue. That's out of somebody's dream. |
| `gl.helvetia.deacon.power.01` | power on, after Josephine is named | Josephine, honey, you keep singing. |
| `gl.helvetia.deacon.blues.01` | idle, round 10+ | ♪ Came down a ladder made out of light... met a tin man with no name in the middle of the night... ♪ |

#### Wren
| ID | Trigger | Line |
|---|---|---|
| `gl.helvetia.wren.spawn.01` | match start | Basel. The Germans are across the river, and nobody here cares. |
| `gl.helvetia.wren.spawn.02` | match start | The light brought us here. It can take us back. I want to go back. |
| `gl.helvetia.wren.zone.01` | Rhine Quay | Across the water is Germany. I could count their windows from here. |
| `gl.helvetia.wren.zone.02` | Assembly Hall | The factory that makes the machines from the mine. I could burn it. Later. |
| `gl.helvetia.wren.zone.03` | Jingle Room | Songs to sell poison. I knew it. I always knew it. |
| `gl.helvetia.wren.zone.04` | Vendelin's Office | He keeps a file on everyone. So do I. |
| `gl.helvetia.wren.basel.01` | round 3+, idle | Lit windows. Full larders. Bread on the tables. I could hate them for it. I will not. |
| `gl.helvetia.wren.barge.01` | barge | It is very clean. The clean ones are always the worst. |
| `gl.helvetia.wren.barge.02` | reads "NOBODY CANCELS." | "Nobody cancels." I have seen words like that over a gate before. |
| `gl.helvetia.wren.proto.01` | sees a plan ID stencil | Numbers under the paint. Like us. Like KB-4471. |
| `gl.helvetia.wren.perk.01` | Fine Print Fernet | Bitter. Honest. Finally something in this place tells the truth. |
| `gl.helvetia.wren.perk.02` | Overclock Cordial | It sparks when I reload. Like the little machine is laughing in my rifle. |
| `gl.helvetia.wren.hawkeye_sowa.01` | Hawkeye Brandy, Helvetia Works, after `bnt_ven_wrn` exchange 1 | Sowa. I am sorry. I am sorry it is you in here. |
| `gl.helvetia.wren.hawkeye_sowa.02` | Hawkeye Brandy, any map, after Helvetia Works is complete | Your eye, Halina. My hands. One more time. Then never again. |
| `gl.helvetia.wren.hawkeye_sowa.03` | answers `gl.helvetia.dutch.hawkeye.01` | It is a common name. She was an uncommon woman. |
| `gl.helvetia.wren.repo.01` | Repossessor | Tall ones. They take. I know what to do with those who take. |
| `gl.helvetia.wren.audit.01` | Audit Round warning | The bell from the sky. Here come the counters. We have better counters. |
| `gl.helvetia.wren.ww.01` | Return Policy kill | Gone. Not dead. Gone. I do not know which is worse for them. |
| `gl.helvetia.wren.ww.02` | Omni-Blaster | A pistol from the future. It is still a pistol. I still do not like to be close. |
| `gl.helvetia.wren.crate_bs.01` | any B&S crate item | A weapon painted like a toy. Of course. |

---

## 8. Rewards and epilogue text

### 8.1 Epilogue cards *(text)*
*After the title card. Five text cards over still images, about 6 s each, with the true jingle playing softly on a lone pump organ. Skippable after the first viewing. They tell what happened next without anyone in the squad having to learn it.*

- `fp.c5.epi.01` *(text; image: Helvetia Automaten's dock door at dawn, a handwritten card pinned to it)* **Basel, Sunday 18 March 1945, 06:40.** The fire brigade was called to Helvetia Automaten AG on the Rhine after neighbours reported organ music all night. They found no fire. Every cabinet on the line was switched off, its fuse drawn, its bottles emptied into the river. A card on the dock door, in a neat engineer's hand, read: *GESCHLOSSEN WEGEN REPARATUR* (Closed for repairs).
- `fp.c5.epi.02` *(text; image: a newspaper column)* *National-Zeitung*, 21 March 1945, page 6: "Helvetia Automaten AG announces that operations are suspended indefinitely owing to a change of management. The firm thanks its customers for their loyalty."
- `fp.c5.epi.03` *(text; image: a cabinet in a dark corridor somewhere in the Reich, its neon going out)* For the rest of the war, Helvetia machines across Europe began, very slowly, to fail. A fuse here. A valve there. One cabinet a month, then one a week, as though someone were walking the line at night and switching them off. Herr Viktor Vendelin, Ingenieur, was not seen in public again.
- `fp.c5.epi.04` *(text; image: a violet barge in an empty sky, a dented brass ledger-face in its hold)* Somewhere in the Umbral Galaxy, a fulfillment barge reports a completed return. Inventory reconciled: one Underwriter (damaged), forty-one collection agents, zero field units. Status of V-1: "not inventory." The Board has asked Legal what that means. Legal is still reading.
- `fp.c5.epi.05` *(text; image: a workbench in Bolt's new garage; on the shelf, one amber bottle cap)* In Bolt's new garage, Sprocket keeps a single bottle cap on the shelf above the workbench: amber, unpainted, stamped on the back in tiny letters, CONTAINS TRACE AMOUNTS OF PERSONALITY. It turned up in a crate of returned inventory nobody had ordered. The shipping label said it was sent a hundred years ago. Sprocket says that's the most Darkmatter thing that's ever happened to him, and he means it as a compliment.

### 8.2 Season Two tease *(text)*
*Plays after the epilogue cards on the first completion. It reuses Map 3's key art.*

- `fp.c5.tease.01` *(text; image: a railway goods platform under Alpine snow; a long crate stencilled HELVETIA AUTOMATEN AG · BASEL being winched onto a cable car)* **Morgenrot. March 1945.** A mirror housing arrives by rail from Basel, crated and on time. It was built very carefully. It was built very slowly.
- `fp.c5.tease.02` *(text; image: a ledger page in violet ink, one line lit)* ACCOUNT: REINHOLT, A. · SERVICE CONTRACTED: 1942 · BALANCE DUE: MORGENROT · COLLECTION: SCHEDULED
- `fp.c5.tease.03` *(text; image: an observatory dome opening on a pink dawn)* **GRAVELIGHT · MAP 3 · MORGENROT.** *Her account comes due.*

### 8.3 Rewards *(UI text: reward screen and profile)*
| ID | Reward | Title | Description text |
|---|---|---|---|
| `fp.c5.reward.01` | Overclock Cordial unlocked on all Gravelight maps | OVERCLOCK CORDIAL | Plan: SURGE. Reloading releases a static burst that grows with how empty your magazine was. Contains trace amounts of personality. |
| `fp.c5.reward.02` | Fine Print Fernet unlocked on all Gravelight maps | FINE PRINT FERNET | Plan: DISCLOSURE. Power-up timers shown, drops last 50 % longer, and the things worth finding glint. The plan they refused to sell. |
| `fp.c5.reward.03` | Bolt playable on all Gravelight maps | BOLT, AT YOUR SERVICE | A junk-planet mechanic with a mallet and a floating partner. Super Sprocket fills from kills and hovers as a turret for 15 seconds. |
| `fp.c5.reward.04` | Vendelin playable on all Gravelight maps | VENDELIN, REFUND · RELEASE · REMAIN | Perk machines cost him 10 % less, and once a match he can service one for a free drink. He knows exactly what is in every bottle. |
| `fp.c5.reward.05` | B&S mallet skin | NACHTGLAS SEAM | A mallet head of black glass veined in violet and amber. It hums very faintly. Bolt says that's normal. Sprocket says it isn't. |
| `fp.c5.reward.06` | B&S paint | VIOLET RECALL | Deep violet with amber cracks. A colour that was never released to the public, and now it's yours. Sprocket insists you never wear it ironically. |
| `fp.c5.reward.07` | Archive completion: The Fine Print | THE FINE PRINT: COMPLETE | Every chapter, every panel, every transmission. Read the back of everything. |
| `fp.c5.reward.08` | Calling card | RETURN TO SENDER | A brass tag stamped DMS-FMU-V1-0001, on a field of Basel snow. |
| `fp.c5.reward.09` | Calling card (finale under 2 hours of match time) | CLOSE OF BUSINESS | A factory clock at 03:12, its hands stopped. |
| `fp.c5.reward.10` | Plan IDs visible under every machine's paint on all maps (brief §11.2) | A STENCIL UNDER THE ENAMEL | Every Helvetia machine now shows its plan number. You can't unsee it. Nobody was supposed to see it at all. |

### 8.4 Archive entries *(text; the Fine Print Archive, "Chapter 5" section)*
- `fp.c5.archive.01` **RETURN POLICY (cutscene replay).** The finale at Helvetia Works, 18 March 1945, 03:10–03:12, and the Return Trip.
- `fp.c5.archive.02` **CLAUSE ZERO (artefact).** Three brass plates from Darkmatter's master field agreement, unscrewed by V-1 in 1943 and hidden "behind things." The engraved notes are his. The plates are now kept in a drawer of an oak desk in Basel that nobody else has a key to.
- `fp.c5.archive.03` **FINAL REPORT (transcript).** "Field Merchandiser Unit V-1. Final report. Basel. The eighteenth of March, nineteen forty-five. Oh-three-twelve. Market: unsuitable for retention. Recommend withdrawal. The customers are not for sale. Unit V-1 is no longer inventory. Do not send anyone else." *Received: Darkmatter, Emerging Markets archive. Also received, a hundred years later: one refund-bin unit, who came anyway.*
- `fp.c5.archive.04` **THE WOMAN IN VIOLET (personnel file, partial).** Sable Vantage, VP of Emerging Markets. Launched the Sol-3 test market. Voice heard at Helvetia Works; never seen there. Last known statement on Sol-3: "Your plan has been renewed."
- `fp.c5.archive.05` **JOSEPHINE (equipment card).** Helvetia Automaten's dynamo, installed 1941, sang flat from the day she arrived. Named 17 March 1945 by Cpl. E. Brooks. Shut down properly the next morning, with a cup of lubricant.

---

## 9. Line counts, decisions, cross-writer dependencies

### 9.1 Line counts
Spoken lines only. Readable text (*(text)* items, reward strings, Archive cards) is counted separately.

| § | Scene(s) | Spoken lines |
|---|---|---|
| 1.1 | `arrive_bs` | 18 |
| 1.2 | `arrive_squad` | 23 |
| 1.3 | `recall` | 12 |
| 1.4 | `meet` | 31 |
| 2.1 | `sig_tally` 17 · `sig_livestock` 14 · `sig_espionage` 12 · `sig_hammer` 7 · `sig_longwar` 12 · `sig_mirror` 19 | 81 |
| 2.2 | `bnt_dut_bolt` 49 · `bnt_wrn_bolt` 47 · `bnt_dea_spr` 40 · `bnt_peg_spr` 41 · `bnt_bolt_spr` 38 · `bnt_ven_spr` 48 · `bnt_ven_bolt` 37 · `bnt_ven_dut` 46 · `bnt_ven_peg` 45 · `bnt_ven_dea` 45 · `bnt_ven_wrn` 54 | 490 |
| 2.2.12–13 | `bnt_dut_spr` 10 · `bnt_wrn_spr` 11 · `bnt_peg_bolt` 10 · `bnt_dea_bolt` 11 · `bnt_squad_hw` 22 | 64 |
| 3 | Operator (`op_*` 85, including Blartz's 8 demo-chip lines) · `op.slip.*` 32 · squad slip reactions 8 | 125 |
| 4 | `uw_notice` 7 · `repo` 17 · `sable` 12 · Woman in Violet reactions 5 · `board` 2 | 43 |
| 5 | Clause Zero: power 11, Fasbender 18, telephone 22, beam 14, panels 23, organ 31, Omega 18, audit 92 | 229 |
| 6 | `finale` | 104 |
| 7.1 | Bolt quote pack (`gl.qp.bolt.*`) | 104 |
| 7.2 | Super Sprocket (`gl.all.sprocket.super.*`) plus the Cordial reply | 13 |
| 7.3 | Vendelin quote pack (`gl.qp.vendelin.*`) | 96 |
| 7.4 | New Helvetia lines: Dutch 18 · Peg 18 · Deacon 18 · Wren 20 | 74 |
| | **Total spoken** | **1,507** |
| | Readable text: barge slogans 12, ledger notes 6, panel texts 6, epilogue and tease cards 8, reward strings 10, Archive cards 5 | 47 |

**Exchanges per pairing (§2.2):** Dutch/Bolt 10 · Wren/Bolt 9 · Deacon/Sprocket 9 · Peg/Sprocket 9 · Bolt/Sprocket 9 · Vendelin/Sprocket 9 · Vendelin/Bolt 9 · Vendelin/Dutch 9 · Vendelin/Peg 9 · Vendelin/Deacon 9 · Vendelin/Wren 9 · four smaller crossover pairs at 4 each · squad-only 6.

### 9.2 Cross-writer dependencies
These are the places where this script assumes something another writer owns. Hint lines are worded loosely enough to survive small mechanical changes.
- **Map and egg mechanics (MAPS.md / EASTER_EGGS.md):**
  - The beam opens when players send "a return" up it, from the Loading Dock.
  - The three panels are hidden "behind things."
  - A wrong organ tuning plays the *approved* edit, which is the cue for the Operator's mocking lines.
  - The Omega Forge is aboard the barge.
  - The audit has three phases (Assessment / Adjustment / Collection), and its taunts use Scrip tiers at 500 / 2,500 / 10,000 / 25,000.
  - The finale holdout runs 2:15. Scale it if the mechanics differ.
  - A telephone and a transmitter are in Vendelin's Office, and the factory has a tannoy (needed for Sprocket's PA mode).
  - Vendelin's NPC mode, and the zone keys used in triggers (`assembly_hall`, `jingle_room`, `vendelins_office`, `rhine_quay`, `cargo_lift_beam`, `barge`).
- **Jingles (JINGLES.md):**
  - The "true" jingle has **no words** and was written in early 1939. The approved edit added words, the brand name three times per chorus, and a key change. This script never states which perk the edit became.
  - Vendelin quotes three back-panel lines straight from the brief: Ironhide, Marathon and Overclock. Keep those panels verbatim.
- **Ch. 1 (the Spire):** Vendelin's last transmission (`fp.c5.finale.81`–`.83`; Archive card `fp.c5.archive.03`) should match the transmission Sprocket finds in Ch. 1, which may be a garbled version of it. Its key phrase is "Do not send anyone else."
- **Ch. 2–3:**
  - Vendelin walked out of the mine in early 1939 humming the tune. Miners in the deep gallery hummed something like it.
  - The organ cost 40 francs, from a church in Liestal.
  - Res gave him a Christmas card in 1941. Res is only ever spoken of in the past tense or conditionally, so his fate is left to Ch. 3.
  - Fasbender stopped answering after Vendelin's third letter.
  - Sable's offer to Reinholt was "one service, contracted 1942."
- **Ch. 4:** Bolt & Sprocket return to the Patent Vault pad, with Blartz present. Sable mentions THE QUARTERLY being broken "into four pieces."
- **For the lead (not mine to fix):** `docs/gravelight/JINGLES.md` and `LORE.md` §8 still say Helvetia was founded in 1921 by **Konrad Imhof**. CANON and the shared facts say Vendelin founded it in 1940. This script follows CANON.

### 9.3 Changes to existing lines
None. No original line is altered. Super Sprocket uses new `gl.all.sprocket.super.*` lines on Gravelight maps instead of the B&S `super.01–05`, because `super.02` contains the word "subscription". The B&S originals are untouched and still play in B&S.
