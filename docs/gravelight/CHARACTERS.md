# GRAVELIGHT — Characters

> Canon names and IDs come from `docs/CANON.md`. VO line IDs follow `{SPK}_{CAT}_{NN}`. Lines marked `[Polish]` include a short English gloss for subtitles. `docs/VO_SCRIPT.md` should mirror these IDs. This file holds the voice and character intent; VO_SCRIPT holds trigger, priority and cooldown.

## Contents
1. [The Squad at a Glance](#the-squad-at-a-glance)
2. [Sgt. Walter "Dutch" Kowalczyk](#1-sgt-walter-dutch-kowalczyk)
3. [Lt. Margaret "Peg" Ashworth](#2-lt-margaret-peg-ashworth)
4. [Cpl. Elijah "Deacon" Brooks](#3-cpl-elijah-deacon-brooks)
5. [Zofia "Wren" Nowak](#4-zofia-wren-nowak)
6. [New perk lines for the squad (§11 amendment)](#5-new-perk-lines-for-the-squad-11-amendment)
7. [Bolt (§11 amendment)](#6-bolt-playable-on-gravelight-maps-11-amendment)
8. [Vendelin (§11 amendment)](#7-vendelin-playable-on-gravelight-maps-11-amendment)
9. [Banter](#banter)
10. [The Tag: KB-4471](#the-tag-kb-4471)
11. [NPC Voice Profiles](#npc-voice-profiles)
12. [Character Dossiers (Levels 1–10)](#character-dossiers)

---

## The Squad at a Glance

| | Dutch | Peg | Deacon | Wren |
|---|---|---|---|---|
| Role | Muscle, big brother | Commander, demolitions | Mechanic, moral center | Guide, sniper |
| Nation / unit | US Army, 2nd Ranger Bn | British SOE | US 761st Tank Bn | Polish Home Army (AK) |
| Age | 34 | 29 | 26 | 24 |
| Humor | Deadpan complaint | Dry, posh understatement | Quiet, warm, scriptural | Dark, precise |
| Stake | His family came from here | Her orders | The machines are being used for evil | Her brother never came out |
| Secret (Dossier 10) | Babcia's letter: Wilcza Góra and the "glass in the salt" | Directive LANTERN | The letter home to Ruthie | What happened to Tomasz |
| Trait (off under Classic Rules) | +10% melee damage | Grenade cook timer on HUD, +1 grenade | Repairs/builds/trap cooldowns 15% faster | +10 Scrip on headshot kills |

**(§11 amendment)** Two more playable characters, **Bolt** and **Vendelin**, are available on Helvetia Works and, after The Fine Print, on every map. See §6–§7. Their traits: Bolt has his mallet and Super Sprocket; Vendelin has a 10% perk discount and one free Service Call per match. Classic Rules disables both.

**How the squad sounds together:** Dutch complains, Peg decides, Deacon steadies, Wren knows the way. Nobody gives speeches. When someone tries, someone else cuts them off with a joke. The humor wears thinner the deeper the maps go. By Map 3 the jokes are the only thing holding them together, and they all know it.

---

## 1. Sgt. Walter "Dutch" Kowalczyk

### Bio
Walter Kowalczyk was born in 1910 in Pittsburgh's Polish Hill, the fourth of seven children. His father was a puddler at the Jones & Laughlin works who came home every night smelling of iron and saying nothing. Walter went into the mills at fifteen. He got the nickname "Dutch" at nineteen from a foreman who couldn't pronounce Kowalczyk and decided every immigrant was Dutch. It stuck because Walter thought it was funny that a man could be that wrong that confidently.

He enlisted after Pearl Harbor at thirty-one, older than almost everyone in his training company. He went to the Rangers because a recruiter told him it was "the hard way," and Walter has never trusted an easy way in his life. He climbed the cliffs in Normandy, and he won't talk about that.

His grandmother, **Halina Kowalczyk ("Babcia")**, raised him on stories from **Wilcza Góra**, a village "six kilometers from the salt." She left in 1891 and never went back. She died in 1937, and the last thing she told him, half asleep, was "don't go down the salt." He thought it was the morphine. He is about to find out she meant it literally.

He was attached to Operation Gravelight because he speaks Polish, and because his Polish is bad enough that he will never be mistaken for a local.

### Voice notes (for VO actor)
- Low, gravelly baritone. Pittsburgh vowels ("dahntahn," "yinz" exactly once per map, never more). Unhurried, even in a crisis.
- His default register is complaint. He complains the way other men pray: steadily, to keep going. He is never actually panicking. When he goes quiet, the squad worries.
- His Polish is kitchen Polish learned from an old woman: wrong genders, wrong cases, a grandmother's accent. Read it confidently and wrong. Wren corrects him; he never learns.
- Softens noticeably around Wren. Talks to the dead Gängers like disappointed relatives.

### Personal stake
The forced laborers and miners here are Silesian and Polish. Some of the Gängers could be from Wilcza Góra, which means some of them could be his distant kin. The closer he gets to the village, the harder that is to joke about.

### Secret
Babcia knew about the "black glass in the salt" decades before the Reich found it. Her family's village had a word for it, *czarna sól* ("black salt"), and a rule: you don't bring it up. Dutch has her letter in his breast pocket. He hasn't read it in years, and he's afraid to read it here.

### Arc
- **Map 0 (Crossroads Inn):** Pure survival. Dutch is the rock, grumbling and dependable. He recognizes a Polish hymn on the radio static and goes quiet.
- **Map 1 (Kaltenbrunn):** Finds the miners' roster in the Barracks and sees surnames from Babcia's stories. His jokes about "relatives" stop being jokes. After the heart collapses, he reads the letter.
- **Map 2 (Totenhafen):** Angrier and more focused. He wants to end this for the family he never met.
- **Map 3 (Morgenrot):** He is the one who argues for mercy toward Reinholt. He understands wanting your people back.

### Character Trait
**Iron Fist:** +10% melee damage. (Disabled under Classic Rules.)

### Quotes

**Buying weapons**
- `DUT_BUY_PISTOL_01`: "Pistol. Great. I'll throw it at 'em when it's empty."
- `DUT_BUY_RIFLE_01`: "Bolt action. Slow, honest work. Like the mill."
- `DUT_BUY_RIFLE_02`: "Garand. Now that's a rifle a man can marry."
- `DUT_BUY_SMG_01`: "Chopper. Spray and pray, and I ain't much for praying."
- `DUT_BUY_SHOTGUN_01`: "Trench gun. Now we're talking the same language."
- `DUT_BUY_LMG_01`: "Heavy. Good. I like a gun that can take a punch."
- `DUT_BUY_LAUNCHER_01`: "A stovepipe. Everybody stand way the hell back."
- `DUT_BUY_WONDER_01`: "This thing hums. Guns shouldn't hum."
- `DUT_BUY_MELEE_01`: "A shovel. My old man would be proud. Finally doing honest work."

**Mystery Crate**
- `DUT_CRATE_GOOD_01`: "Well, look at that. Christmas came late."
- `DUT_CRATE_GOOD_02`: "Thank you, box. I take back half of what I said about you."
- `DUT_CRATE_BAD_01`: "Nine-fifty for this? I've been robbed by nicer crooks in Pittsburgh."
- `DUT_CRATE_BAD_02`: "This box hates me personally."
- `DUT_CRATE_DRUMMER_01`: "The little drummer again. Somebody's kid owned that."
- `DUT_CRATE_DRUMMER_02`: "Yeah, yeah, march on outta here, tin man."

**Perks**
- `DUT_PERK_IRONHIDE_01`: "Tastes like a stout somebody drowned in. Hits like one too."
- `DUT_PERK_SECONDWIND_01`: "Schnapps from a nun. Babcia would've approved. *Na zdrowie.*" `[Polish: "Cheers."]`
- `DUT_PERK_TRIGGER_01`: "My hands are shaking. That's the tonic, not me. Mostly."
- `DUT_PERK_TWINBARREL_01`: "Bitters. Like my old man's mood. Works about as fast."
- `DUT_PERK_MARATHON_01`: "I don't run. I'm making an exception."
- `DUT_PERK_HAWKEYE_01`: "Brandy. Fancy. My eyes feel like somebody scrubbed 'em."
- `DUT_PERK_PACKMULE_01`: "Another gun to carry. Story of my life. I'm the mule."
- `DUT_PERK_BLASTPROOF_01`: "Bock beer that makes you bombproof. Only in Europe."

**Power-ups**
- `DUT_PWR_RESUPPLY_01`: "Ammo. Bless whoever's upstairs."
- `DUT_PWR_DEATHSDOOR_01`: "Everything dies. Like usual, only faster."
- `DUT_PWR_DOUBLESCRIP_01`: "Double pay. Wish the Army ran like this."
- `DUT_PWR_BLACKOUT_01`: "Lights out, fellas. Rest easy."
- `DUT_PWR_FORTIFY_01`: "Boards back up. Saves my back."
- `DUT_PWR_CLEARANCE_01`: "Clearance sale at the box. Line up, ladies."

**Special enemies**
- `DUT_BELL_01`: "That bell. Somebody tell it to shut up."
- `DUT_BELL_02`: "Fog's rolling in. Here come the lantern boys."
- `DUT_FOREMAN_01`: "The boss is here. I hated foremen before he had a drill for an arm."
- `DUT_FOREMAN_02`: "C'mon, big man. I've punched out bigger guys than you. Not many."
- `DUT_SCREAMER_01`: "Somebody shut that nurse up before my ears bleed."
- `DUT_GLASSHIDE_01`: "This one's got glass for a gut. Aim high!"

**Combat state**
- `DUT_AMMO_LOW_01`: "Running light here."
- `DUT_AMMO_NONE_01`: "Empty. Swell. Just swell."
- `DUT_DOWN_01`: "Ah, hell. I'm down. Somebody grab me."
- `DUT_DOWN_02`: "Babcia... not like this. Not here."
- `DUT_REVIVE_01`: "Up you get. Don't make me carry you."
- `DUT_REVIVE_02`: "Off the floor. Floor's for the dead ones."
- `DUT_REVIVED_01`: "Thanks. I owe you a beer. A bad one."
- `DUT_STREAK_01`: "Keep 'em coming. I got all night, unfortunately."
- `DUT_STREAK_02`: "Like stacking pig iron. Just keep lifting."
- `DUT_HEADSHOT_01`: "Right in the thinker."
- `DUT_HEADSHOT_02`: "Rest easy, cousin."
- `DUT_CRAWLER_01`: "This one's crawling. Leave him. He ain't going anywhere fast."

**World**
- `DUT_DOOR_01`: "Door's open. Something's always behind the door."
- `DUT_POWER_01`: "Lights. Now I can see what's eating me."
- `DUT_CRUCIBLE_01`: "Put my gun in a furnace and it came out meaner. That's the mill all over."
- `DUT_CRUCIBLE_02`: "Smells like the Monongahela on a hot day. Works, though."
- `DUT_TRAP_01`: "Hit the switch and watch the fireworks."
- `DUT_EE_01`: "That music box. Some little girl's. I hate this place more every minute."
- `DUT_EE_02`: "Bells in the right order. Like church back home."
- `DUT_EE_03`: "The heart's gonna blow. Good. Let it."
- `DUT_EXHAUST_01`: "Round fifty. I forgot what sitting down feels like."
- `DUT_EXHAUST_02`: "My arms are done. I'm fighting with spite now."

**Polish (Dutch's "kitchen Polish")**
- `DUT_POL_01`: "*Jestem głodna.*" `[Polish (wrong): "I am hungry" in the feminine form. Wren corrects.]`
- `DUT_POL_02`: "*Dzienkuje*, box." `[Mangled "dziękuję", thank you.]`
- `DUT_POL_03`: "*Psiakrew.*" `[Curse: "dog's blood."]`
- `DUT_POL_04`: "*Cholera jasna.*" `[Curse, roughly "bright plague." Babcia's favorite.]`

---

## 2. Lt. Margaret "Peg" Ashworth

### Bio
Margaret Ashworth was born in 1915 in Wiltshire, to a family with a manor house and no money left to run it. Her father was a sapper in the Great War who came home and spent his remaining years blowing up tree stumps on the estate "for practice." He taught her everything he knew. She was setting charges by twelve.

She read chemistry at Girton, was quietly approached by "a man from the Ministry" in 1940, and joined SOE as an explosives instructor. She was posted to the field in 1943 after an instructor's report called her "alarmingly calm." She has run three operations in France. Two of her teams didn't come back. She doesn't talk about France either.

She is the commander of Operation Gravelight. Officially, her mission is to extract Dr. Emil Fasbender with his research. She also carries sealed orders, **Directive LANTERN**, from a man she knows only as **"Mr. Hale."** The squad doesn't know it exists.

### Voice notes (for VO actor)
- Received Pronunciation, clipped, precise. Never raises her voice. The worse things get, the more politely she speaks. In a crisis she sounds bored.
- Sardonic understatement is her armor: a horde is "a spot of bother." She swears rarely, and when she does it's devastating.
- When she's lying, she gets *more* precise, not less. The actor should play the LANTERN hints as tiny, nearly invisible pauses.
- Professional fascination with explosives, said with unsettling warmth.

### Personal stake
She lost two teams in France following orders she didn't fully understand. LANTERN is the same kind of order, and she has started to suspect it's worse.

### Secret: Directive LANTERN
Retrieve a viable Nachtglas sample at any cost, secure it, and report to Mr. Hale. Destroy the facility and all records. Fasbender is "desirable but not essential." The squad is "expendable in pursuit of the primary objective." Peg pockets a shard at the end of Map 1.

### Arc
- **Map 0:** Calm command. She plans the escape and the route to Kaltenbrunn. She asks Fasbender one odd question over the radio: "Is the material stable in transit?"
- **Map 1:** Takes notes on the Crucible and the heart. Pockets a shard at the end while no one is looking.
- **Map 2:** The shard reacts to the U-boat pen's shipments. Wren catches her with it. Trust fractures.
- **Map 3:** The moral choice comes to a head. Does she deliver the shard to Hale or destroy it? The player's ending choice decides it.

### Character Trait
**Sapper's Patience:** Grenade cook time shown on the HUD, +1 grenade capacity. (Disabled under Classic Rules.)

### Quotes

**Buying weapons**
- `PEG_BUY_PISTOL_01`: "A sidearm. How very last resort."
- `PEG_BUY_RIFLE_01`: "A rifle. Sensible. Rather like sensible shoes."
- `PEG_BUY_RIFLE_02`: "German bolt action. One does admire their workmanship, if not their politics."
- `PEG_BUY_SMG_01`: "A Tommy gun. The Americans do love a crowd-pleaser."
- `PEG_BUY_SHOTGUN_01`: "A shotgun. Crude. Effective. Like most of my colleagues."
- `PEG_BUY_LMG_01`: "Belt-fed. Now we're having a proper conversation."
- `PEG_BUY_LAUNCHER_01`: "Oh, hello, darling. You and I are going to get along famously."
- `PEG_BUY_WONDER_01`: "Fascinating. Mr. Hale would... never mind."
- `PEG_BUY_MELEE_01`: "A shovel. My father would weep with pride."

**Mystery Crate**
- `PEG_CRATE_GOOD_01`: "Oh, that's rather splendid."
- `PEG_CRATE_GOOD_02`: "The crate is feeling generous. Let's not question it."
- `PEG_CRATE_BAD_01`: "Nine hundred and fifty Scrip. For that. Marvellous."
- `PEG_CRATE_BAD_02`: "I'll be filing a complaint with the quartermaster. Whoever, or whatever, that is."
- `PEG_CRATE_DRUMMER_01`: "The drummer. Somebody wound him up and nobody's stopped him since."
- `PEG_CRATE_DRUMMER_02`: "Off it goes. Do note where it lands, everyone."

**Perks**
- `PEG_PERK_IRONHIDE_01`: "Stout. Ghastly. Fortifying. Very British, actually."
- `PEG_PERK_SECONDWIND_01`: "Made by a nun, apparently. I'd pray, but I'll settle for this."
- `PEG_PERK_TRIGGER_01`: "Rather like strong tea with a grudge."
- `PEG_PERK_TWINBARREL_01`: "Bitters. A gin would improve it enormously."
- `PEG_PERK_MARATHON_01`: "I haven't run like this since the hockey pitch at Cheltenham."
- `PEG_PERK_HAWKEYE_01`: "Brandy for marksmen. Well. Bottoms up and eyes front."
- `PEG_PERK_PACKMULE_01`: "One more gun. One can never have too many options."
- `PEG_PERK_BLASTPROOF_01`: "Oh, I *know* this one. The Demolitions School kept it in the staff room."

**Power-ups**
- `PEG_PWR_RESUPPLY_01`: "Ammunition. How thoughtful."
- `PEG_PWR_DEATHSDOOR_01`: "Everything dies in one. Let's be efficient about it."
- `PEG_PWR_DOUBLESCRIP_01`: "Double credit. The Ledger's in a generous mood."
- `PEG_PWR_BLACKOUT_01`: "Clean sweep. Very tidy."
- `PEG_PWR_FORTIFY_01`: "Windows secured. Carry on."
- `PEG_PWR_CLEARANCE_01`: "A sale. Even the dead have them."

**Special enemies**
- `PEG_BELL_01`: "The bell. Fasbender said not to let it ring. It's ringing."
- `PEG_BELL_02`: "Fog. Positions, everyone. They come out of it, not the windows."
- `PEG_FOREMAN_01`: "That is a very large man with a very large drill. Weak point, people. Find it."
- `PEG_FOREMAN_02`: "Aim for the glowing bit. It's always the glowing bit."
- `PEG_SCREAMER_01`: "A nurse. Do kill her quickly. She'll scramble us all."
- `PEG_GLASSHIDE_01`: "Armoured torso. Head or high explosive. I know which I prefer."

**Combat state**
- `PEG_AMMO_LOW_01`: "Ammunition's getting rather thin."
- `PEG_AMMO_NONE_01`: "I'm dry. Inconvenient."
- `PEG_DOWN_01`: "I'm down. A little assistance, if you'd be so kind."
- `PEG_DOWN_02`: "Not here. I have orders to... oh, damn it."
- `PEG_REVIVE_01`: "Up. We've no time for lying about."
- `PEG_REVIVE_02`: "On your feet. I'm not filing the paperwork for you."
- `PEG_REVIVED_01`: "Thank you. I'll pretend that didn't happen."
- `PEG_STREAK_01`: "Rather a good rhythm going, aren't we?"
- `PEG_STREAK_02`: "Keep them coming. I'm just warming up."
- `PEG_HEADSHOT_01`: "Clean."
- `PEG_HEADSHOT_02`: "One should always aim for the brain. It's where the trouble lives."
- `PEG_CRAWLER_01`: "Legless and still determined. One almost admires it."

**World**
- `PEG_DOOR_01`: "Door's open. Carry on, then."
- `PEG_POWER_01`: "Power's on. Now we see what they built here."
- `PEG_CRUCIBLE_01`: "It's... re-teaching the weapon. That shouldn't be possible. Make a note."
- `PEG_CRUCIBLE_02`: "Interesting. How much of this material is in that furnace?"
- `PEG_TRAP_01`: "Lever pulled. Do stand clear."
- `PEG_EE_01`: "A music box. Four notes. It's a key of some sort."
- `PEG_EE_02`: "The shard. Careful with it. Nobody touch it with bare hands."
- `PEG_EE_03`: "The heart's overloading. Hold this position. Hold it!"
- `PEG_EXHAUST_01`: "Fifty rounds. I'd kill for a cup of tea. I have, in fact, killed for less."
- `PEG_EXHAUST_02`: "If I sit down I shan't get up again. So I shan't sit down."

**LANTERN hints (rare, low priority)**
- `PEG_LANTERN_01`: "Mr. Hale will want to know about... the Ledger. For the report."
- `PEG_LANTERN_02`: "Stable in transit. Good. That's good to know."
- `PEG_LANTERN_03`: "Nobody needs to know what's in my pack. Least of all you."

---

## 3. Cpl. Elijah "Deacon" Brooks

### Bio
Elijah Brooks was born in 1918 in Opelousas, Louisiana, the son of the Reverend Josiah Brooks of Mount Moriah Baptist Church. He grew up between the pulpit and his uncle Clement's garage, where he learned that a tractor engine is a congregation: every part has to agree or nothing moves. He played guitar behind the church on Saturday nights, which his father pretended not to know about.

He was drafted in 1942 and assigned to the 761st Tank Battalion, the "Black Panthers," as a maintenance mechanic. He kept Shermans running through the mud of Lorraine under fire, and he names every engine he fixes. His commanding officer lent him to Operation Gravelight because the extraction plan involved a stolen locomotive, and "Brooks can make anything run."

He writes to his younger sister **Ruthie** every week. She's twelve and wants to be a doctor. He tells her about the weather and the food and never about the war.

### Voice notes (for VO actor)
- Warm Louisiana tenor, soft-spoken, with a preacher's sense of rhythm he inherited and resists. When he gets going, he can't help preaching a little and then catches himself.
- Talks to machines like livestock: "Easy now, girl," "Come on, mule." Never condescending to people.
- His blues lines are his own, half-sung, made up on the spot. They should sound like real field blues: AAB form, plain words, bent notes.
- Quietly funny. His jokes land half a beat late and he enjoys them more than anyone.

### Personal stake
The Helvetia machines, the Crucible, the Ledger, and the turbines are beautifully made, and they're being used to grind people up. To Deacon that's blasphemy against good work. He means to set every machine here free, even if that means breaking it.

### Secret
He isn't writing to Ruthie about the weather anymore. His last letter, unsent, is a goodbye. (Dossier 10.)

### Arc
- **Map 0:** Fixes the radio. Talks to it until it answers.
- **Map 1:** Rages quietly at the machinery's purpose. He builds the Totenglocke and gets the Ledger's attention. The Operator starts addressing him by name.
- **Map 2:** Rebuilds a dead U-boat engine to escape. Has an actual conversation with the Ledger over a ship's radio.
- **Map 3:** Has to decide whether the Ledger is a machine to fix or a soul to set free.

### Character Trait
**Good Hands:** Repairs, builds, and trap cooldowns are 15% faster. (Disabled under Classic Rules.)

### Quotes

**Buying weapons**
- `DEA_BUY_PISTOL_01`: "Little forty-five. Small, but she'll pull her weight."
- `DEA_BUY_RIFLE_01`: "Bolt rifle. One shot, one prayer."
- `DEA_BUY_RIFLE_02`: "Garand. Eight rounds and a song when she's empty."
- `DEA_BUY_SMG_01`: "Chatterbox. All right, sister, let's sing."
- `DEA_BUY_SHOTGUN_01`: "Pump gun. My uncle's old friend. Hello, old friend."
- `DEA_BUY_LMG_01`: "Heavy mule. She'll haul the load."
- `DEA_BUY_LAUNCHER_01`: "Lord, forgive me for what I'm about to do with this."
- `DEA_BUY_WONDER_01`: "Whoever built this was a genius, and I'm sorry for 'em."
- `DEA_BUY_MELEE_01`: "Shovel. A good tool. Dig a trench or dig a grave."

**Mystery Crate**
- `DEA_CRATE_GOOD_01`: "The Lord provides. Sometimes in a busted crate."
- `DEA_CRATE_GOOD_02`: "Now that's a blessing with a trigger."
- `DEA_CRATE_BAD_01`: "Well. Blessed are the poor, I suppose."
- `DEA_CRATE_BAD_02`: "Crate's got a sense of humor. I don't like it."
- `DEA_CRATE_DRUMMER_01`: "The little drummer boy. Somebody's baby girl wound you up, didn't she?"
- `DEA_CRATE_DRUMMER_02`: "Go on, little fella. March home."

**Perks**
- `DEA_PERK_IRONHIDE_01`: "Thick as molasses. Settles in your bones."
- `DEA_PERK_SECONDWIND_01`: "Sister Agnieszka. Whoever you were, thank you."
- `DEA_PERK_TRIGGER_01`: "Fizzy. Hands moving faster than my thoughts."
- `DEA_PERK_TWINBARREL_01`: "Bitter, like a sermon on a hot Sunday."
- `DEA_PERK_MARATHON_01`: "Feel like I could outrun the Devil. Let's not test that."
- `DEA_PERK_HAWKEYE_01`: "Brandy. Daddy'd have a fit. Eyes feel sharp, though."
- `DEA_PERK_PACKMULE_01`: "Make me a mule, I'll carry the load."
- `DEA_PERK_BLASTPROOF_01`: "Can't blow myself up? Well, praise be."

**Power-ups**
- `DEA_PWR_RESUPPLY_01`: "Loaves and fishes. Bullets and grenades."
- `DEA_PWR_DEATHSDOOR_01`: "Every shot's the last one for 'em. Mercy, quick."
- `DEA_PWR_DOUBLESCRIP_01`: "Double wages. Don't spend it all at once."
- `DEA_PWR_BLACKOUT_01`: "Rest now. All of you. Go on home."
- `DEA_PWR_FORTIFY_01`: "Boards back in place. Didn't even need my hammer."
- `DEA_PWR_CLEARANCE_01`: "The crate's taking pennies. Go, go, go."

**Special enemies**
- `DEA_BELL_01`: "Hear that bell? Ain't nobody being called to worship."
- `DEA_BELL_02`: "Fog's coming. Stand together. Backs to each other."
- `DEA_FOREMAN_01`: "Somebody bolted a drill onto that man. God help whoever did it."
- `DEA_FOREMAN_02`: "That drill core's glowing. That's his heart. Hit it."
- `DEA_SCREAMER_01`: "That poor woman. Make it quick."
- `DEA_GLASSHIDE_01`: "That one's wearing glass like armor. Go for the head."

**Combat state**
- `DEA_AMMO_LOW_01`: "Getting light. Real light."
- `DEA_AMMO_NONE_01`: "Empty. Lord, give me a bullet or give me a running start."
- `DEA_DOWN_01`: "I'm down. Somebody... come on now."
- `DEA_DOWN_02`: "Ruthie, honey... not yet. Not yet."
- `DEA_REVIVE_01`: "Got you. Up we go. Easy now."
- `DEA_REVIVE_02`: "Not today. You hear me? Not today."
- `DEA_REVIVED_01`: "Thank you. Lazarus owes you one."
- `DEA_STREAK_01`: "Keep the rhythm. Keep the rhythm."
- `DEA_STREAK_02`: "One more verse. And another."
- `DEA_HEADSHOT_01`: "Go on home."
- `DEA_HEADSHOT_02`: "Sleep easy, brother."
- `DEA_CRAWLER_01`: "This one's crawling. Lord, have mercy on him."

**World**
- `DEA_DOOR_01`: "Door's open. Watch your step."
- `DEA_POWER_01`: "Hear that? Turbines singing. Whole place just woke up."
- `DEA_POWER_02`: "Easy, girl. Easy. Good girl. Hum for me."
- `DEA_CRUCIBLE_01`: "That furnace is talking to my gun. And my gun's listening."
- `DEA_CRUCIBLE_02`: "Beautiful work, used for ugly reasons. Same as everything here."
- `DEA_TRAP_01`: "Lever's down. Stand clear of her."
- `DEA_BUILD_01`: "Bell, frame, crank. All right, little lady, let's put you together."
- `DEA_EE_01`: "That music box... somebody's lullaby."
- `DEA_EE_02`: "Ring 'em in order, like the old hymn."
- `DEA_EE_03`: "The heart's breaking. Hold on. Hold on!"
- `DEA_EXHAUST_01`: "Fifty rounds. Even Job got a break."
- `DEA_EXHAUST_02`: "I'm tired, Lord. But I'm still here."

**Machine whisperer**
- `DEA_MACH_01`: "Come on, mule. Don't you quit on me."
- `DEA_MACH_02`: "Shh. Easy now. Nobody's gonna hurt you anymore."
- `DEA_MACH_03`: "Pretty thing. Who taught you to eat people?"

**Blues lines (half-sung)**
- `DEA_BLUES_01`: "♪ Buried in the salt, Lord, buried way down deep... buried in the salt, can't nobody here sleep. ♪"
- `DEA_BLUES_02`: "♪ That bell keeps ringing, ringing for the dead... that bell keeps ringing, wish it'd ring for me instead. ♪"
- `DEA_BLUES_03`: "♪ Got a ledger keeps a-counting every man I lay down... yes, a ledger keeps a-counting, gonna burn that ledger down. ♪"

---

## 4. Zofia "Wren" Nowak

### Bio
Zofia Nowak was born in 1920 in a village near Kaltenbrunn (now Germanized), the daughter of a mine timberman. She grew up in the valley with her brother **Tomasz**, two years younger, who followed her everywhere and was a terrible shot. They hunted rabbits together. She taught him patience, and he taught her to laugh at herself.

In 1942 the occupation authorities rounded up young men from the valley for "labor service" at the reopened salt mine. Tomasz was taken. His forced-laborer ID tag read **KB-4471**. He wrote one letter. It said the work was cold, the food was thin, and "the walls hum at night." Then nothing.

Zofia joined the Home Army that autumn. She earned the name *Strzyżyk*, "Wren," because she's small, she's loud when she wants to be, and you never see where she's perched. She has 61 confirmed kills in a stained notebook, and she adds one with every mark. She is the squad's guide because she has mapped the mine from the outside for two years, waiting for a way in.

### Voice notes (for VO actor)
- A Polish speaker with fluent but accented English (learned from British radio and an SOE liaison). Clipped, economical, never wasted words.
- Dark humor delivered completely deadpan. She doesn't laugh at her own jokes.
- Precise about numbers. She counts out loud under her breath: "sześćdziesiąt dwa... sześćdziesiąt trzy."
- Fury runs under everything. It surfaces rarely and frighteningly, mostly about the lab, the tanks, and the forced laborers.
- Softens only with Dutch, whom she treats like an embarrassing uncle.

### Personal stake
Tomasz. Every Gänger in a laborer's rags could be him. She checks faces. She knows she shouldn't.

### Secret
She already knows, from a smuggled note by Sister Agnieszka, that Tomasz was moved to the Laboratory Wing. She hasn't told anyone. She came to Kaltenbrunn to find him, not to extract Fasbender. (Dossier 10 reveals what happened to him.)

### Arc
- **Map 0:** Guide. Cold, efficient, and disapproving of everyone's aim.
- **Map 1:** Finds Tomasz's tag in the Lab Wing (side egg). Says the line to Dutch that she's held in for two years.
- **Map 2:** Hunts the shipment records for laborer numbers. Catches Peg with the shard.
- **Map 3:** Wants to destroy everything Reinholt built, Liesl included. That's the hardest position in the moral choice, and the most understandable.

### Character Trait
**Notebook:** +10 bonus Scrip on headshot kills. (Disabled under Classic Rules.)

### Quotes

**Buying weapons**
- `WRN_BUY_PISTOL_01`: "A pistol. For when I want to be close. I never want to be close."
- `WRN_BUY_RIFLE_01`: "Mauser. Their rifle. Their bullets. Their heads. Fair."
- `WRN_BUY_RIFLE_02`: "Gewehr. Semi-automatic. I can be efficient."
- `WRN_BUY_SMG_01`: "A machine pistol. Inelegant. Useful."
- `WRN_BUY_SHOTGUN_01`: "Shotgun. For people who cannot aim. Today, that is me."
- `WRN_BUY_LMG_01`: "Heavy. Loud. Everything I am not."
- `WRN_BUY_LAUNCHER_01`: "This is Peg's kind of gun. I will borrow her taste."
- `WRN_BUY_WONDER_01`: "Fasbender's toy. Built in the same place as my brother's grave."
- `WRN_BUY_MELEE_01`: "A shovel. Good. I will dig them a proper place."

**Mystery Crate**
- `WRN_CRATE_GOOD_01`: "Good. Finally, something here is on our side."
- `WRN_CRATE_GOOD_02`: "This will do. This will do very well."
- `WRN_CRATE_BAD_01`: "A crate that robs the poor. How German."
- `WRN_CRATE_BAD_02`: "I could kill more with a sharpened spoon."
- `WRN_CRATE_DRUMMER_01`: "The drummer. Reinholt's girl's toy. It is following us."
- `WRN_CRATE_DRUMMER_02`: "Run, little soldier. One day I will catch you."

**Perks**
- `WRN_PERK_IRONHIDE_01`: "Bavarian beer. Thick as their heads."
- `WRN_PERK_SECONDWIND_01`: "Siostra Agnieszka. She was real. She nursed the laborers. Thank you, sister." `[Polish: "Sister Agnieszka."]`
- `WRN_PERK_SECONDWIND_02`: "She made this to keep them alive. They used it to keep them working."
- `WRN_PERK_TRIGGER_01`: "Fizz. My hands are fast now. Faster than theirs."
- `WRN_PERK_TWINBARREL_01`: "Bitter. Appropriate."
- `WRN_PERK_MARATHON_01`: "I could run to Kraków. I would, if this were done."
- `WRN_PERK_HAWKEYE_01`: "I hate that this works. I hate it."
- `WRN_PERK_HAWKEYE_02`: "Sniper brandy, made by the men who hunted us. My hands are steadier. Damn them."
- **(§11 amendment) Hawkeye Brandy and Halina "Sowa" Kurek.** Hawkeye's focus was derived from Reinholt's trials on Wren's mentor (`docs/JINGLES.md` §6). Wren recognizes the **owl transfer under the hawk** on every Hawkeye cabinet. Sowa signed her messages with a drawn owl, and taught Wren to do the same. These lines join the `PERK_HAWKEYE` shuffle bag for Wren on every map. `.01` always plays on her **first** Hawkeye drink in a profile (`once_per_profile`). After that, the bag is `WRN_PERK_HAWKEYE_01/02` plus `.02–.05` below.
  - `gl.all.wren.perk_hawkeye.01`: "There is an owl under the hawk. Sowa's owl. They painted over her, and she is still looking out."
  - `gl.all.wren.perk_hawkeye.02`: "Breathe out, then the trigger. Halina taught me that in a hayloft. They put it in a bottle."
  - `gl.all.wren.perk_hawkeye.03`: "*Dziękuję, Sowa.* It works. You always did." `[Polish: "Thank you, Owl."]`
  - `gl.all.wren.perk_hawkeye.04`: "My hands are steady because hers were. I hate this. I hate it. Thank you."
  - `gl.all.wren.perk_hawkeye.05` (round 20+): "Every German I drop with this, Halina, I am giving back to you. One at a time."
  - `gl.all.wren.perk_hawkeye_owl.01` (Helvetia Works side egg "Sowa's Owl", `docs/gravelight/EASTER_EGGS.md` §8.2; Wren only): "There. No hawk. Just her. *[long breath]* Somebody in this factory knew her name. Somebody was sorry."
- `WRN_PERK_PACKMULE_01`: "One more weapon. One more chance."
- `WRN_PERK_BLASTPROOF_01`: "Peg will be jealous. Or she already drank three."

**Power-ups**
- `WRN_PWR_RESUPPLY_01`: "Ammunition. Count it later."
- `WRN_PWR_DEATHSDOOR_01`: "Everything dies in one shot. Like a good shot should."
- `WRN_PWR_DOUBLESCRIP_01`: "Double. My notebook will need more pages."
- `WRN_PWR_BLACKOUT_01`: "All of them. At once. If only it were so easy outside."
- `WRN_PWR_FORTIFY_01`: "Windows closed. Do not waste it."
- `WRN_PWR_CLEARANCE_01`: "The crate is cheap. Move."

**Special enemies**
- `WRN_BELL_01`: "The bell. My brother wrote that the walls hum. This is louder."
- `WRN_BELL_02`: "Fog. Lanterns. Those were miners. Shoot them anyway."
- `WRN_FOREMAN_01`: "The overseer. Obersteiger. My brother worked under him. Let me."
- `WRN_FOREMAN_02`: "The drill core. Aim there. I want him to know who killed him."
- `WRN_SCREAMER_01`: "The nurse. Kill her. Kill her now."
- `WRN_GLASSHIDE_01`: "Glass body. Head only. That is all I aim for anyway."

**Combat state**
- `WRN_AMMO_LOW_01`: "Few rounds left."
- `WRN_AMMO_NONE_01`: "Empty. Do diabła." `[Polish: "To the devil."]`
- `WRN_DOWN_01`: "I'm down. Quickly. Quickly!"
- `WRN_DOWN_02`: "Tomek... I'm sorry. I came too late."
- `WRN_REVIVE_01`: "Get up. I am not losing anyone else here."
- `WRN_REVIVE_02`: "Up. Shoot. Complain later."
- `WRN_REVIVED_01`: "Thank you. I will write you in the notebook. The good page."
- `WRN_STREAK_01`: "Sześćdziesiąt... I am losing count. Good." `[Polish: "Sixty."]`
- `WRN_STREAK_02`: "Keep them coming. The notebook is hungry."
- `WRN_HEADSHOT_01`: "Jeden." `[Polish: "One."]`
- `WRN_HEADSHOT_02`: "Clean. Into the book."
- `WRN_HEADSHOT_03`: "That is how it is done, Dutch."
- `WRN_CRAWLER_01`: "Crawling. Like they made my brother crawl."

**World**
- `WRN_DOOR_01`: "Open. I know what's behind this one. I wish I didn't."
- `WRN_POWER_01`: "Power. The laborers built that switch. Now we use it."
- `WRN_CRUCIBLE_01`: "Their furnace. Their glass. Our gun now."
- `WRN_CRUCIBLE_02`: "It changed the rifle. I don't want to know how."
- `WRN_TRAP_01`: "The lever. Stand back, or join them."
- `WRN_EE_01`: "Reinholt's daughter's music box. She had a child. I had a brother."
- `WRN_EE_02`: "Four bells. Shoot them in order. Like counting."
- `WRN_EE_03`: "Break the heart. Break all of it."
- `WRN_EXHAUST_01`: "Round fifty. I have run out of pages."
- `WRN_EXHAUST_02`: "My eyes hurt. My hands do not care."

**Correcting Dutch**
- `WRN_POL_01`: "*Głodny*, Dutch. You just told me you are a hungry woman."
- `WRN_POL_02`: "*Dziękuję*. Not *jen-koo-yeh*. Your grandmother must have wept."
- `WRN_POL_03`: "That is not a swear. You just said 'bright plague.' Fine. It works."

---

## 5. New perk lines for the squad (§11 amendment)

Fine Print Fernet and Overclock Cordial reach every Gravelight map after The Fine Print (`fp_ch5_done`). So the four squad characters need lines for them, and the new formula backstories call for one Peg line. New categories: `PERK_FERNET` → `fine_print_fernet`, `PERK_OVERCLOCK` → `overclock_cordial` (add to `docs/gravelight/VO_SCRIPT.md` §8). Same rules as the other `PERK_*` lines: tier 1, 100%, shuffle bag. **No squad line interprets a stencil, a panel, or the word "plan."**

| ID | Line |
|---|---|
| `gl.all.dutch.perk_fernet.01` | "Tastes like Babcia's cough syrup. Everything looks... louder." |
| `gl.all.dutch.perk_fernet.02` | "Bitter. Now I can see the stuff this place is trying to hide. Swell. More stuff." |
| `gl.all.dutch.perk_overclock.01` | "My fillings are buzzing. Nobody said nothing about fillings." |
| `gl.all.dutch.perk_overclock.02` | "Run the gun dry and it bites back. My kind of gun." |
| `gl.all.peg.perk_fernet.01` | "Bitter as a Whitehall memo. And just as revealing, for once." |
| `gl.all.peg.perk_fernet.02` | "Everything has edges now. I can see where they've hidden things. How very useful." |
| `gl.all.peg.perk_overclock.01` | "Oh, I *like* that. Every empty magazine a small detonation." |
| `gl.all.peg.perk_overclock.02` | "Electrical. Cheerful. I don't trust it at all. Another, please." |
| `gl.all.peg.perk_blastproof.01` (rare, 15%, after Peg's dossier level 5) | "The bock that started it all. London's kept a bottle in a safe since 'forty-three. ...Never mind how I know." |
| `gl.all.deacon.perk_fernet.01` | "Bitter herbs. Like Passover. Lord, I can see what this place is hiding." |
| `gl.all.deacon.perk_fernet.02` | "Whoever made this one wanted folks to see straight. First honest drink in the building." |
| `gl.all.deacon.perk_overclock.01` | "Feels like somebody wired a friend into my hands. Howdy, friend." |
| `gl.all.deacon.perk_overclock.02` | "She sparks when she's empty. Don't we all, girl. Don't we all." |
| `gl.all.wren.perk_fernet.01` | "Bitter. Good. Now I see where they hide things." |
| `gl.all.wren.perk_fernet.02` | "It shows me the clock on every gift. Nothing here is free. I knew that." |
| `gl.all.wren.perk_overclock.01` | "My rifle hums when it is empty. Fine. Let it sing." |
| `gl.all.wren.perk_overclock.02` | "Static in the blood. My brother would have laughed at this." |

The Crucible plaque line `gl.map01.deacon.plaque.01` is in `docs/gravelight/LORE.md` §4.2. It's tier 1, once per match, the first time Deacon reads the plaque.

---

## 6. Bolt (playable on Gravelight maps) (§11 amendment)

**Availability:**
- Helvetia Works, in The Fine Print Ch. 5 and in standalone.
- After `fp_ch5_done` (profile unlock `gl_char_bolt`), **every Gravelight map.**
- Co-op: pick 4 from 6 (Dutch, Peg, Deacon, Wren, Bolt, Vendelin), no duplicates. Solo: pick 1.

**Bio (for the Gravelight dossier).** Bolt is a far-future mechanic from the Rustbelt galaxy. With his refund-bin robot Sprocket, he took down OmniScrap™ and its Chairman. He then answered a calendar invite he should have deleted, and he arrived in Basel in March 1945 through a delivery pad that a friend of his rigged "beautifully wrong." In Gravelight he is just a young man in strange work clothes with a hammer, a talking machine, and no idea what a Gänger is. The squad never learns where he came from, and **he never explains subscriptions to them.** He starts to once, and Sprocket stops him (brief §10.7; the scene and all of Bolt's spoken lines belong to The Fine Print Ch. 5, `docs/fineprint/`). Bolt keeps his B&S quips. Played first-person with the Gravelight HUD and rules: **B&S's HUD never bleeds into Gravelight.**

**Traits (both disabled by Classic Rules):**

| Trait | Rule |
|---|---|
| **The Mallet** | Bolt's mallet **replaces the trench knife**. Stats: 200 damage, 0.65 s swing, 90° arc, 2.3 m reach, hits up to 2 targets, lunge 2.5 m, melee kill +130 Scrip. He one-shots to round 1 and two-shots through round 2, like the knife, but the wider arc makes him a better crowd melee. Buying the **Sharpened E-Tool** wall-buy gives Bolt the **Riveted Mallet** instead: E-Tool stats with the mallet model. Mallet cosmetics (seams, Nachtglas Seam skin) carry over from B&S. |
| **Super Sprocket** | **Sprocket is Bolt's special.** A **Sprocket meter** under the perk caps fills from kills: +1 per kill, +2 per headshot or melee kill. It's full at **40 points**, at any player count. Press **Special** (default `G` / D-pad Left) to launch **Super Sprocket**. For **15 s** he hovers at Bolt's shoulder as an auto-turret and fires **Sprocket Zap** arcs every **0.6 s** at the nearest enemy within **20 m**. Each arc chains to **3 targets** within **6 m**. **Damage per target per arc = max(300, 0.30 × health(r))**. That's 300 at r1, 813 at r20, and 2109 at r30. Bosses (Foreman, Underwriter) take **×0.5**, Repossessors **×1.5**, and Glasshide plate ignores Zap (it's electrical, not ballistic). While active, the meter doesn't fill. It resets to 0 when Bolt goes down. Super Sprocket never targets players and can't revive. Kill credit and Scrip go to Bolt (body-kill value, 50). |

**Classic Rules:** the mallet keeps its model but uses **trench knife stats** (150 dmg, 70° arc, 1 target). The Sprocket meter is hidden and Super Sprocket can't be used. Sprocket still rides along as a cosmetic shoulder companion, and his quips stay on (tier 0, reduced rate).

**Speaker / VO.** Speaker ID `bolt` (VOManager code `BLT`), Sprocket `sprocket` (`SPR`), channel `PLAYER`. Sprocket's lines play positionally from Bolt's shoulder.
- **All Bolt and Sprocket quote-pack lines are written by the Ch. 5 writer** under `gl.qp.bolt.<topic>.<nn>` (Sprocket's lines inside Bolt's pack use the same prefix with speaker `sprocket` in data).
- The VOManager expects these **topic keys**, matching the squad's categories in `docs/gravelight/VO_SCRIPT.md` §8:
  - Weapons and crate: `buy_pistol`, `buy_rifle`, `buy_smg`, `buy_shotgun`, `buy_lmg`, `buy_launcher`, `buy_wonder`, `buy_melee`, `crate_good`, `crate_bad`, `crate_wonder`, `crate_drummer`, `crate_anomalous` (a B&S item from the crate).
  - Perks: `perk_ironhide`, `perk_secondwind`, `perk_trigger`, `perk_twinbarrel`, `perk_marathon`, `perk_hawkeye`, `perk_packmule`, `perk_blastproof`, `perk_fernet`, `perk_overclock`.
  - Power-ups: `pwr_resupply`, `pwr_deathsdoor`, `pwr_doublescrip`, `pwr_blackout`, `pwr_fortify`, `pwr_clearance`.
  - Specials and bosses: `special_bell`, `special_audit`, `boss_foreman`, `boss_screamer`, `boss_underwriter`, `kill_glasshide`, `kill_repossessor`.
  - Combat and status: `ammo_low`, `ammo_none`, `down`, `revive`, `revived`, `streak`, `headshot`, `crawler`.
  - World: `door`, `power_on`, `crucible`, `omega_forge`, `trap`, `exhaust` (round 50+).
  - Sprocket: `super_sprocket_ready`, `super_sprocket_launch`, `super_sprocket_end`.
  - Easter eggs: `ee_<step_id>` for each map's main-egg steps.
  - **Per map:** prefix the topic with the map key for map-specific lines (`map00_`, `map01_`, `helvetia_`), e.g. `gl.qp.bolt.map01_zone_chapel.01`. Unprefixed topics are used on every map.
- **Gravelight squad lines do not react to Bolt** on Maps 0–1. Their written banter assumes the canon squad. The only exceptions are Helvetia Works (Ch. 5 banter) and generic `TEAM_DOWN` / `REVIVE` lines, which name no one.

**Canon note:** Bolt or Vendelin on Maps 0–1 (and later 2–3) is **non-canon "Archive replay"**. Main-egg cutscenes use the canon squad, with generic silhouettes for absent characters, exactly as already built. Bolt and Vendelin never appear in Gravelight cutscenes outside Helvetia Works.

**Dossier (Gravelight, levels 1–10).** Same unlock types as the squad, so the same table applies.

| Level | Unlock |
|---|---|
| 1 | Service record: "Mechanic. Independent. References: one robot (biased)." |
| 2 | Backstory page 1 (B&S recap, written as a 1945 Basel police report on "a young foreigner with a hammer") |
| 3 | Outfit: Swiss factory overalls |
| 4 | Audio diary 1 (Ch. 5 writer, `gl.qp.bolt.diary.01`) |
| 5 | Quote pack 1 |
| 6 | Backstory page 2 (Sprocket's Clause 44, as Sprocket would tell it) |
| 7 | Outfit: Gravelight winter parka over his B&S jacket |
| 8 | Audio diary 2 (`gl.qp.bolt.diary.02`) |
| 9 | Quote pack 2 + calling card "Sprocket Rides Shotgun" |
| 10 | Final page (Ch. 5 writer): the note Bolt leaves for the squad that he never says out loud |

---

## 7. Vendelin (playable on Gravelight maps) (§11 amendment)

**Availability:** same as Bolt (profile unlock `gl_char_vendelin`).

**Bio (for the Gravelight dossier).** To the squad he is **Herr Viktor Vendelin, Ingenieur, Basel**: the founder of Helvetia Automaten AG. He is tall, thin, and unfailingly courteous, and always in his coat, hat, scarf and gloves. He knows every machine in every map by its first name and its formula-maker's. He speaks German, French, English, Polish and Bernese German with the same slightly-too-careful diction. **Truth (players only):** he is Darkmatter Field Merchandiser Unit **V-1** (serial **DMS-FMU-V1-0001**, directive **"DISTRIBUTE. RETAIN. REPORT."**), stranded on Sol-3 since 9 November 1938. He built and sang every jingle, and he has spent five years sabotaging his own catalogue. He has a coin-slot mouth behind the scarf and a violet DARK-GLASS™ core behind the brass faceplate. He "drinks" tonics by pouring them through the slot. He has the most devastating quotes about every machine.
- **Unmasking:** on Helvetia Works he is played unmasked after the Ch. 5 reveal, and masked before it (Ch. 5 story mode). On every other map he wears the disguise by default; the dossier level 7 outfit is "unmasked."

**Traits (both disabled by Classic Rules):**

| Trait | Rule |
|---|---|
| **Staff Discount** | Every perk machine costs Vendelin **10% less**, rounded down to the nearest 10 Scrip: Ironhide 2250, Second Wind 450 solo / 1350 co-op, Trigger 2700, Twin Barrel 1800, Marathon 1800, Hawkeye 1350, Packmule 3600, Blastproof 1800, Fernet 1800, Overclock 2250. It doesn't stack with Clearance, which doesn't affect perks anyway. |
| **Service Call** | **Once per match**, Vendelin can **service** any perk machine whose prompt he could normally use: it must be powered, except Second Wind in solo. Hold [F] for **3 s** (Deacon's build bonus doesn't apply). The machine dispenses **one free drink** of its perk to him. The usual cap applies, so it fails with "Cap reached" and isn't consumed. The usual use rules apply too: a serviced Second Wind in solo uses one of the machine's 3 trial returns, because Vendelin could never patch that clause. The usual use is **re-drinking a perk lost on a down.** HUD: a small brass key icon beside the perk caps, greyed out once used. |

**Melee:** a heavy brass **service key** (a T-handle). Trench knife stats; it's cosmetic. With the E-Tool wall-buy he gets the **Service Wrench**, with E-Tool stats.

**Classic Rules:** full prices, no Service Call, and the HUD key icon is hidden.

**Speaker / VO.** Speaker ID `vendelin` (VOManager code `VEN`), channel `PLAYER`.
- **All Vendelin quote-pack lines are written by the Ch. 5 writer** under `gl.qp.vendelin.<topic>.<nn>`, using the same topic keys as Bolt (minus the Sprocket keys, plus `service_call` and `service_denied`).
- **Every `perk_*` topic is mandatory for him**, with at least 3 lines per machine. These are his "most devastating quotes about every machine," and they may name the formula-maker.
- He gets a perk line on **approaching** a machine for the first time each match (`perk_approach_<perk>`), not only on drinking.
- He may say "Plan" in the voice of a salesman remembering his training. **He never says "subscription" within a squad member's hearing.** In data: `conditions.no_squad_within_m: 15` on any line containing the word. The Ch. 5 writer decides whether any such line exists.

**Canon note:** the same "Archive replay" rule as Bolt.

**Dossier (levels 1–10):** follows the same unlock table. Level 1 service record: *"Field Merchandiser Unit V-1. Status: lost on arrival. Results: EXCEPTIONAL RETENTION."*, typed over by hand: *"Status: resigned."* Pages, diaries (`gl.qp.vendelin.diary.01–02`) and the level 10 final page are by the Ch. 5 writer.

---

## Banter

Banter triggers between rounds (in the round transition break) when two characters are within 15 m and no higher-priority VO is playing. Each exchange plays once per match. The initiating speaker is the first line. See `docs/VO_SCRIPT.md` for trigger rules.

### Dutch & Peg
**BNT_DUT_PEG_01**
- DUT: "Lieutenant, how come the British always talk like they're ordering tea?"
- PEG: "Because, Sergeant, we usually are."
- DUT: "Even now?"
- PEG: "*Especially* now."

**BNT_DUT_PEG_02**
- PEG: "Sergeant, you're bleeding."
- DUT: "Yeah. Steady drip. Like a faucet back home."
- PEG: "That is not reassuring."
- DUT: "Wasn't trying to reassure you, ma'am."

**BNT_DUT_PEG_03**
- DUT: "What's in your pack, Lieutenant? You keep checking it."
- PEG: "Charges. Detonators. Tea."
- DUT: "Uh-huh."

### Dutch & Deacon
**BNT_DUT_DEA_01**
- DUT: "You really name every engine you fix?"
- DEA: "Every one. That turbine down there's called Hattie."
- DUT: "Why Hattie?"
- DEA: "Because she's loud and she don't quit. Like you, Sarge."

**BNT_DUT_DEA_02**
- DEA: "You ever pray, Dutch?"
- DUT: "Every time I go up a cliff."
- DEA: "And?"
- DUT: "Still here. Don't push it."

**BNT_DUT_DEA_03**
- DUT: "My old man worked the mill thirty years. Never said a word about it."
- DEA: "My daddy preached thirty years. Never stopped saying words about it."
- DUT: "Wanna trade?"
- DEA: "Not for all the gold in the salt."

### Dutch & Wren
**BNT_DUT_WRN_01**
- DUT: "*Jestem głodna.*"
- WRN: "Głodny. You are a man."
- DUT: "Says you."
- WRN: "God help Poland."

**BNT_DUT_WRN_02**
- WRN: "Your grandmother. Where was she from?"
- DUT: "Wilcza Góra. You know it?"
- WRN: "...Six kilometers from here."
- DUT: "Yeah. She said that, too."

**BNT_DUT_WRN_03**
- DUT: "You write every kill in that book?"
- WRN: "Every one."
- DUT: "That's a lot of ink."
- WRN: "It is a lot of Germans."

### Peg & Deacon
**BNT_PEG_DEA_01**
- DEA: "Lieutenant, that Crucible... you looked at it a little too long."
- PEG: "Professional curiosity, Corporal."
- DEA: "My daddy said curiosity's just temptation with a notebook."
- PEG: "Your father sounds exhausting."

**BNT_PEG_DEA_02**
- PEG: "Can you fix the lift, Brooks?"
- DEA: "I can fix anything, ma'am. Question's whether it wants to be fixed."
- PEG: "Persuade it."
- DEA: "Yes, ma'am. Come on, girl. Come on."

**BNT_PEG_DEA_03**
- DEA: "You ever think about after, Lieutenant?"
- PEG: "Constantly. It's the 'during' I try not to think about."

### Peg & Wren
**BNT_PEG_WRN_01**
- WRN: "You did not come for Fasbender."
- PEG: "I came for exactly what I was ordered to come for."
- WRN: "That is not an answer."
- PEG: "No. It's an order."

**BNT_PEG_WRN_02**
- PEG: "Your aim is extraordinary."
- WRN: "I know."
- PEG: "Modesty isn't taught in the Home Army, then."
- WRN: "Neither is lying. Unlike SOE."

**BNT_PEG_WRN_03**
- PEG: "When this is done, there's a flight to London. You could come."
- WRN: "When this is done, I will still be Polish. London will not fix that."

### Deacon & Wren
**BNT_DEA_WRN_01**
- DEA: "Your brother. What was he like?"
- WRN: "A terrible shot. A good laugh."
- DEA: "Sounds like my kind of folk."
- WRN: "He would have liked you. He liked everyone. It was his only flaw."

**BNT_DEA_WRN_02**
- WRN: "You talk to the machines."
- DEA: "They listen better than people."
- WRN: "Do they talk back?"
- DEA: "Here? Lord help me, yes."

**BNT_DEA_WRN_03**
- DEA: "♪ Little bird up in the rafters, singing for the dead... ♪"
- WRN: "Is that about me?"
- DEA: "Might be."
- WRN: "Finish it. Then never sing it again."

---

## The Tag: KB-4471

**Trigger:** Wren (or any player while Wren and Dutch are both in the match) picks up the forced-laborer ID tag in the Laboratory Wing (side Easter egg, see `docs/GDD.md` §11). In solo, if the player is not Wren or Dutch, the exchange plays over the radio as a recalled memory. A unique, non-repeatable exchange; music ducks; Gängers do not spawn within 20 m for 12 seconds.

**`TAG_KB4471_01`**
- WRN: "KB... four-four-seven-one."
- DUT: "Wren? What is it?"
- WRN: "It's his. Tomek's. It was in the tank room. With the... with the others."
- DUT: "...Hey. Hey. C'mere."
- WRN: "He was a terrible shot, Dutch. I used to tell him he'd starve if he had to hunt alone. And they put him in a tank."
- DUT: "He didn't starve. And he wasn't alone. He had you looking for him. Two years, you looked."
- WRN: "I was too late."
- DUT: "Yeah. My babcia was too late to say goodbye to her sister. She lit a candle every Christmas for sixty years. *Za duszę*, she'd say."
- WRN: "...*Za duszę.* For the soul. You said it right. First time."
- DUT: "Don't tell anybody."
- WRN: "I'm writing it in the book. On the good page."

---

## NPC Voice Profiles

### Dr. Emil Fasbender
- **Voice:** Mid-40s, German, soft Rhineland accent, speaks English carefully with occasional wrong idioms. Nervous, rapid, then suddenly very quiet when guilty. Always sounds like he's talking with his hand over the mic.
- **Delivery:** Brilliant and apologetic. Gives hints wrapped in physics. Leaves some doubt: he never answers a direct question about what he did.
- `FAS_SAMPLE_01`: "Glasmacher calling Gravelight. Please, if anyone is alive on that aircraft... please answer."
- `FAS_SAMPLE_02`: "Do not let the bell ring. When it rings, the dead remember they were hungry."
- `FAS_SAMPLE_03`: "The Pylons are tuning forks. Three of them. Strike them together and the vault will... sing open. Forgive the poetry. I have been alone a long time."
- `FAS_SAMPLE_04`: "Did I make the tonics? I... calculated the dilutions. That is not the same thing. It is not the same."
- `FAS_SAMPLE_05`: "Augusta was my friend. I want you to know that before you hate her. And before you hate me."

### Dr. Augusta Reinholt
- **Voice:** Early 50s, Berlin German, cultured and controlled. A beautiful lecturing voice, the voice of a woman who has given a hundred presentations to men who didn't listen. Grief shows only in the timing: pauses a fraction too long.
- **Delivery:** Never shouts. Never cartoonish. She believes she is the only rational person in the facility. Her phonograph recordings are warm; her late PA hijacks are cold.
- `REI_SAMPLE_01`: "Diary, the ninth of February, 1939. She asked me yesterday if the stars were cold. Today I couldn't answer anything at all."
- `REI_SAMPLE_02`: "The material doesn't create hunger. It preserves the last impulse. If I can make the last impulse *love*... then they're not monsters. They're kept."
- `REI_SAMPLE_03`: "You are standing in the heart of my work, soldiers. Please. Wipe your feet."
- `REI_SAMPLE_04`: "Emil thinks he's betraying me. He's only betraying himself. He always did lack conviction."
- `REI_SAMPLE_05`: "Liesl. Mama is coming. Mama is nearly finished."

### The Operator
- **Voice:** Sampled 1930s radio announcer: bright, brassy, mid-Atlantic and German-inflected, with an audible tape-hiss bed. Lines are assembled from fragments: odd stresses and pitch jumps between words (the Ledger splicing). Always cheerful. Becomes very slightly too personal over time.
- **Delivery:** "Your Friend at the Ledger." Advertising cadence. Wrong in unsettling ways: congratulates kills like sales figures, calls players by laborer numbers, occasionally holds a word too long, as if listening.
- `OPR_SAMPLE_01`: "Good evening, valued personnel! This is Your Friend at the Ledger, and every quiet body is a credit to the Reich... and to *you*!"
- `OPR_SAMPLE_02`: "Ammunition for everyone! Courtesy of the Ledger. Please don't thank us. We know."
- `OPR_SAMPLE_03`: "Oh dear, wrong bell! The Ledger is disappointed, but never surprised."
- `OPR_SAMPLE_04`: "Corporal Brooks. You fixed Hattie. Hattie... remembers. So do I."
- `OPR_SAMPLE_05`: "Tally: four thousand, four hundred and seventy-one. That's a lovely number, isn't it? Why is that a lovely number?"

### Liesl Reinholt (recordings only)
- **Voice:** A seven-year-old girl on 1938–39 phonograph cylinders, recorded by her mother. Breathy, bright, thin with age and wax hiss. She was ill in the later recordings: coughs, tiredness. Never heard "live" until Map 3 (and then, ambiguously).
- **Delivery:** Natural, unrehearsed, giggly. Sings off-key. No horror in her performance; the horror is context.
- `LSL_SAMPLE_01`: "Mama, is it on? Is it recording? Hello, the future! I am Liesl and I am six and a half."
- `LSL_SAMPLE_02`: "This is Herr Tamtam. He drums when he is happy. Drum, Herr Tamtam! (*tin drumming*)"
- `LSL_SAMPLE_03`: "♪ Komm mit, kleiner Soldat... ♪ I forget the rest. Mama, what comes next?"
- `LSL_SAMPLE_04`: "(*cough*) I'm not tired. I'm only resting my eyes. Like Papa used to."
- `LSL_SAMPLE_05`: "Mama, when you go down in the salt, does it hum for you too?"

---

## Character Dossiers

Dossier XP comes from playing as that character (any map). Each level unlocks items in the main-menu **Dossiers** screen. Levels and XP thresholds are tunable in `data/dossiers.json (created in M5)`. Level 10 reveals the character's secret in full.

| Level | Unlock type (all characters) |
|---|---|
| 1 | Dossier cover page and service record |
| 2 | Backstory page 1 |
| 3 | Outfit variant: winter gear |
| 4 | Audio diary 1 |
| 5 | Quote pack 1 (extra lines added to the VO pool) |
| 6 | Backstory page 2 |
| 7 | Outfit variant: weathered uniform |
| 8 | Audio diary 2 |
| 9 | Quote pack 2 and calling card |
| 10 | **Final page: the secret** |

### Dutch's dossier
1. **Service record:** 2nd Ranger Battalion, Pointe du Hoc. "Refuses promotion above sergeant. Reason given: 'Then I'd have to listen to officers all day.'"
2. **Polish Hill:** the mill, the seven siblings, the foreman who named him "Dutch."
3. **Outfit:** Ranger winter parka with a frayed diamond patch.
4. **Audio diary 1:** recorded on a captured wire recorder at the inn. "Babcia used to say the salt sings. I figured that was just old-country talk."
5. **Quote pack 1:** additional Polish attempts and mill stories.
6. **Babcia:** the story of Halina Kowalczyk, her crossing in 1891, and the rule in Wilcza Góra about the "black salt."
7. **Outfit:** muddied, bloodied Ranger jacket.
8. **Audio diary 2:** "Found the miners' roster. Kowalczyk, three times. Two of 'em born in Wilcza Góra. Maybe nobody. Maybe family."
9. **Quote pack 2 + calling card:** "*Za duszę*" (a candle on a snowy windowsill).
10. **The secret: Babcia's letter, in full** (written in Polish, translated):
    > *Walterku, my little one. If you are reading this then I am gone and you have grown curious, which you always were. In Wilcza Góra there was a rule. The black salt in the deep seam, you leave it. My grandfather's brother brought a piece up in 1860 and kept it under his bed, and it hummed, and he stopped eating, and when he died he would not stay down. The priest and three men put him back. They put the black salt back too. Nobody spoke of it again. I am telling you because you are like him: you pick things up to see how they work. Don't go down the salt, Walterku. And if you have to, bring it nothing. Leave it everything. Love, Babcia.*

### Peg's dossier
1. **Service record:** SOE, Section F, then "Special Duties, London." Instructor's report: "Alarmingly calm."
2. **Ashworth Hall:** the manor, the money, the father who blew up tree stumps.
3. **Outfit:** sheepskin flying jacket over battledress.
4. **Audio diary 1:** "Two teams in France. I followed the orders exactly. I'm not sure that's a defense."
5. **Quote pack 1:** additional explosives and London lines.
6. **Mr. Hale:** a page about the man she met only twice. No office, no rank, a voice like a closed door.
7. **Outfit:** scorched battledress, a demolitions satchel.
8. **Audio diary 2:** "The shard in my pocket is warm. It's always warm. I keep my hand on it the way I used to keep my hand on my father's pocket watch."
9. **Quote pack 2 + calling card:** "Lantern" (a shuttered lamp with violet light leaking).
10. **The secret: Directive LANTERN, in full.**
    > MOST SECRET — EYES ONLY — LT. M. ASHWORTH
    > DIRECTIVE LANTERN (supersedes GRAVELIGHT operational orders where in conflict)
    > 1. Primary objective: recover a viable sample of the material designated NACHTGLAS. Secure in the lead-lined container provided. Do not expose to living tissue.
    > 2. Dr. E. Fasbender is desirable but not essential. If extraction endangers the primary objective, he is to be abandoned.
    > 3. On recovery, destroy the facility and all records. No third party (Allied or otherwise) is to receive any sample, document, or witness account.
    > 4. Team members are expendable in pursuit of the primary objective. They are not to be informed of this directive.
    > 5. Report to Mr. Hale in person only.
    > *This order is deniable. So are you.*

### Deacon's dossier
1. **Service record:** 761st Tank Battalion, maintenance. "Recovered and repaired 19 disabled vehicles under fire, Lorraine, November 1944."
2. **Opelousas:** Mount Moriah church, Uncle Clement's garage, the guitar behind the church.
3. **Outfit:** tanker's jacket with a winter knit cap.
4. **Audio diary 1:** "Fixed the inn radio. Talked to her till she answered. Fasbender's voice came out, and I swear she was proud of herself."
5. **Quote pack 1:** additional blues lines and machine-naming.
6. **The Black Panthers:** his battalion, the men he served with, how they were treated at home and how they fought anyway.
7. **Outfit:** grease-stained overalls over fatigues, a wrench on his belt.
8. **Audio diary 2:** "The Operator called me by name today. Said Hattie remembers. I don't think a machine ought to remember. I don't think anything here ought to."
9. **Quote pack 2 + calling card:** "Hattie" (a turbine with a hand-painted name).
10. **The secret: the letter home to Ruthie, unsent, in full.**
    > *Dear Ruthie,*
    >
    > *I told you in my last letter that it was cold here, and it is. I told you the food was bad, and it is. I never told you anything else, and I'm sorry for that, because you're old enough now and smart enough to know when your big brother is talking around a thing.*
    >
    > *So here's the thing. I'm somewhere I can't name, doing something I can't tell you about, and I don't think I'm coming home. I'm not scared, exactly. Daddy always said a man ought to be ready, and I believe I am. I've done good work here. I've fixed things that were broken and I've broken things that should never have been built, and if the Lord's keeping a ledger, I hope that one comes out even.*
    >
    > *I want you to be a doctor. I want you to be the best one in St. Landry Parish, and I want you to fix people like I fix engines: patient, gentle, and never giving up on one just because somebody says it's too far gone. People will tell you what you can't be. Let them talk. Then go be it anyway.*
    >
    > *Tell Mama I ate my vegetables. Tell Daddy I prayed, because I did, every night, and some days in between. Tell Uncle Clement his nephew could take apart a German turbine and put it back with his eyes shut. And play my guitar sometimes. It gets lonely if nobody plays it. Machines are like that. So are people.*
    >
    > *I love you, little sister. I'll be listening for you.*
    >
    > *Your brother,*
    > *Elijah*
    >
    > *P.S. If I do make it home, burn this letter and we'll never speak of it, and you'll have to put up with me forever.*

### Wren's dossier
1. **Service record:** Armia Krajowa, Silesian district. "61 confirmed. Codename STRZYŻYK (Wren)."
2. **The valley:** the village, the timberman father, rabbit hunting with Tomasz.
3. **Outfit:** white snow smock over a civilian coat, AK armband.
4. **Audio diary 1:** "The inn. Fasbender's voice on the radio. A German, begging. I wanted to shoot the radio."
5. **Quote pack 1:** additional Polish lines and notebook counts.
6. **The letter:** Tomasz's only letter, in full. "The work is cold, the food is thin, and the walls hum at night. Don't worry. I'm practicing my aim on the rats. I still miss."
7. **Outfit:** blood-dark smock, notebook tied to her belt.
8. **Audio diary 2:** "Sister Agnieszka's note. She said Tomek was moved to the Lab Wing. I knew before I came. I didn't tell them. I'm telling you."
9. **Quote pack 2 + calling card:** "The Good Page" (a notebook page with one name, no tally marks).
10. **The secret: what happened to Tomasz.** Reinholt's specimen log, entry 211:
    > *Subject KB-4471 (Nowak, T., Polish, 20). Selected for dosage trial 7 owing to unusual tolerance. Subject asked repeatedly for his sister. Dosage at 0.4 strength: survived 11 days. Subject's final impulse (per resonance trace): "looking for someone." Reanimated subject does not attack. Subject wanders toward the mine entrance and must be restrained. Of no further use. Disposal deferred.*
    >
    > (Handwritten at the bottom, in Sister Agnieszka's hand, in Polish:) *I let him out of the tank on the night of the 3rd. He walked toward the gate. I hope he reached the snow. — A.W.*
    >
    > *This is the hook for Map 2: there is a Gänger somewhere that does not attack, and is still looking.*
