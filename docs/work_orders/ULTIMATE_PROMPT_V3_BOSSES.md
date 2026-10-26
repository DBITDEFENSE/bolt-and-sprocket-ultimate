# ULTIMATE PROMPT v3 — GRAVELIGHT "HOMAGE BOSSES": THE COUSINS · PAUL · THE SLENDER

This is an ADD-ON to `ULTIMATE_PROMPT.md` (v1) and `ULTIMATE_PROMPT_V2.md` (v2), which sit next to this file in `C:\Users\Devin\PROJECTS\bolt-and-sprocket\`. All v1/v2 rules still apply: originality, licensed assets, greybox first, data-driven tuning, autonomy with progress notes, git. Where this file conflicts with v1/v2 on these three bosses, this file wins.

These three bosses are **homages to real people in my life**: my cousins, my friend Paul, and me (Devin). Treat them as love letters. They should be terrifying in-game and flattering out of it: powerful, memorable, never mocking.

---

## 0. RULES FOR THE HOMAGE BOSSES

1. **The Likeness Sheet drives the look** (§1). Read the hair colors, builds, signature items, and quirks from it. The models are **stylized and zombified**, not photoreal scans.
   - Never import a real photo or face scan unless I drop it into `/assets/user_supplied/likeness/` with a note saying that person agreed.
   - Don't exaggerate real body features to make fun of anyone. "Hulk-like" means *powerful*, not a joke about size.
2. **Every boss is a person first.** Each one gets a Gravelight-canon backstory (who they were in 1944–45, what their "last impulse" is). That is what makes the horror land.
3. **Toggle:** settings → Gameplay → **"Homage Bosses: On / Off"** (default On). When Off, the bosses don't spawn and the normal round plays instead.
   - **"Homage Names: Real / In-World"** chooses whether the title cards show the real first names (Alix, Paul, Devin) or the in-world names. Default: Real.
4. **Originality:** The Slender must NOT copy the "Slender Man" internet character. No faceless blank head, no black suit and tie, no tentacles. He is our own design (§4).
5. All three bosses use the v2 §7 zombie-animation framework (AnimationTree, additive layers, IK, ragdoll, dismemberment), extended with the custom rig work below. **If MZ isn't built yet, build it first.**
6. **Boss health scaling:** `HP = base × (1 + 0.75 × (players − 1))`, with all numbers in `/data/gravelight/bosses/*.tres`. Each boss gets a title card in the red ledger-stamp style, a music sting, and an Operator line on spawn and death.

---

## 1. LIKENESS SHEET (fill in or edit; the defaults are used until I change them)

Save this as `/data/gravelight/bosses/likeness.json` and render it as a table in `docs/HOMAGE_BOSSES.md`.

| Boss | Real name | In-world name | Look (from me) | Quirk / signature to build in | Defaults for anything I haven't given |
|---|---|---|---|---|---|
| Cousin 1 | `[COUSIN_1_NAME]` (default "Mara") | **"The Hammer"** | Blonde hair; carries a mallet she throws | Throws the mallet like a boomerang and catches it | Long braid, oversized wool coat, knitted mittens |
| Cousin 2 | `[COUSIN_2_NAME]` (default "Jo") | **"The Reach"** | Brown hair; extremely long arms | Reaching: grabs things far away, through windows and floors | Bob haircut with bangs, nightgown under a cardigan, bare feet |
| Cousin 3 | **Alix** | **"The Third Hand"** | An arm that extends out of her torso; double damage | The arm is "the hand she was always holding" | Dark hair in two buns, a too-big Sunday dress, a ribbon |
| Paul | **Paul** | **"PAUL"** (the title card just says PAUL) | Hulk-like | `[PAUL_SIGNATURE: catchphrase, team, item, tattoo...]` | Big beard, rolled sleeves, dog tags, a crushed tin cup he carries everywhere |
| Devin | **Devin** | **"THE SLENDER"** | Based on me | `[DEVIN_SIGNATURE: hair, height, glasses, style...]` | Very tall, thin, calm; a watchman's greatcoat; a lantern and ring of keys; works the night shift |

Ages: the Cousins are written as **young women** (roughly late teens to twenties). Their designs are creepy-doll horror, **never sexualized**: modest period clothing, no fan-service framing, no suggestive poses or camera angles.

---

## 2. MAP 0 "CROSSROADS INN" — ROUND 10: **THE COUSINS**

### 2.1 Who they were (Gravelight canon; add it to `LORE.md` and the Archive)
Three cousins spent the winter of 1944 at the Crossroads Inn, which belonged to their aunt, the innkeeper. When the transport plane went down and the dead came up the rail line, their aunt hid them in the cellar and told them to **keep playing their game and stay quiet until she came back.** She never came back. Nachtglas dust in the well water did the rest.

Their last impulse is **the game.** They are still playing it, the same clapping-and-hiding game they played every night, and the players are now "it."

- **The Hammer** chopped the firewood with the inn's splitting mallet. She still does. She throws it, and it always comes back to her hand.
- **The Reach** was the youngest, always stretching for the jam jar on the top shelf. Her arms never stopped stretching.
- **Alix, the Third Hand**, held her cousins' hands every night in the dark cellar. When they died, she wouldn't let go. The arm growing out of her torso is **the hand she's still holding out for them.**

Their song is an **original** clapping rhyme (write full lyrics in `docs/JINGLES.md`). It counts down from three, a verse per cousin, and its last line is *"...and whoever's left is IT."* It's hummed, then whispered, then sung. Write it in German and English, with the German version used in-game and subtitled.

### 2.2 The Cousins Round (round 10 replaces the normal round)
- **Setup:** at the end of round 9, the inn's lamps gutter and go out one by one, and the fireplace dies. A child-sized handprint smears across the taproom window from the *outside*. Then silence, then clapping from upstairs.
- **Arrival, one at a time:**
  1. **The Hammer** first, from the upstairs rooms. Her mallet is thrown down the stairwell before she appears.
  2. **The Reach** 30 seconds later, from the stable hayloft. Her arms come through the windows before her body does.
  3. **Alix** last, when either cousin drops below 50% HP. She **climbs up out of the cellar trapdoor** that the player never knew was there; the trapdoor appears only for this round.
- **Trio rules:**
  - They hum in harmony while all three live. Each death **removes a voice** from the song, and the survivors **enrage** (+20% speed, new attacks).
  - The last one standing sings alone, and it's awful.
  - Normal zombies keep spawning at a reduced rate (40%) so the round stays chaotic but readable.
- **Base HP (solo, tunable):** The Hammer 6,000 · The Reach 5,000 · Alix 7,500.
- **Fail-safe:** if the round lasts longer than 6 minutes, the Cousins "get bored." They retreat, laughing, and return on round 15 with full HP.

### 2.3 The Hammer — moves & animations
- **Locomotion:** a skipping walk that hitches, with every third step missing a frame. Drag the mallet one-handed; its head scrapes sparks off the floorboards.
- **Mallet Throw (signature):** a wind-up spin, then a throw. The mallet arcs like a boomerang, **curves around corners**, hits on the way out AND back, and she catches it without looking. Telegraph: she stops humming for one beat before each throw.
- **Ricochet Throw** (enraged): the mallet banks off two walls before returning.
- **Overhead Split:** a two-handed chop that cracks the floor and leaves a slowing splinter zone for 3s.
- **Creepy layers:**
  - Her head stays locked on the nearest player even while her body walks away (an additive head-look with a 180° limit, joints visibly over-rotating).
  - When she catches the mallet, she giggles and her whole body freezes for 0.3s, perfectly still.
- **Weak point:** when the mallet is in the air, she's unarmed. Damage dealt during the throw is ×1.5, and a melee hit during the throw makes her stagger.
- **Death:** she sits down cross-legged, sets the mallet across her lap, and stops. Then she topples over slowly, like a doll.
- **Drop:** the **"KINDERHAMMER."** Her mallet becomes a **throwable melee weapon** for whoever picks it up, for the rest of the match. Throw with a melee-hold; it boomerangs back. (A quiet callback to Bolt's mallet throw; Bolt, if playing, says *"...Oh, that's mine. Kind of."*)

### 2.4 The Reach — moves & animations
- **Rig:** extra bones in each arm (a 3-segment "telescoping" humerus and forearm). Arms stretch up to **4× length** by animated bone translation and scale, with skin stretch shading (veins pull taut, Nachtglas cracks widen).
- **Locomotion:** walks hunched with her knuckles dragging, arms folded and coiled. On ceilings she **crawls upside down along the rafters** using only her arms, her body hanging.
- **Long Reach Grab (signature):** from up to 12 m away, her arm shoots out, grabs a player, and **drags them** toward her. Break free by shooting the arm (a weak-point glow on the wrist), melee-mashing, or a teammate's shot. If she reels you in, she does a hug-crush (big damage).
- **Through-the-Wall:** arms punch through floorboards and window boards from the next room or the floor below. The telegraph is dust falling and boards creaking 0.6s first.
- **Window Spider:** she hangs outside the building and reaches through every window at once; all the barricades rattle.
- **Creepy layers:** her fingers keep moving (counting, clapping silently) even when the rest of her is still. Her arms retract slowly and wrongly, the joints folding backward.
- **Weak point:** the wrists while the arms are extended (×2 damage). Cutting an arm off (dismemberment) disables that grab until it **regrows** 20s later, with a horrible animation.
- **Death:** both arms slowly reach for the other cousins (or for where they fell), then drop.
- **Drop:** guaranteed **Fortify** + 500 Scrip.

### 2.5 Alix, the Third Hand — moves & animations
- **Rig:** a **third arm** growing from the center of her torso, with its own 4-bone chain plus IK target. Normally it's held pressed flat against her chest, half hidden under the dress ribbon. When it opens, it unfolds forward like a lock-knife.
- **Locomotion:** a slow, stiff, perfectly upright walk, like she's being led by the hand. The **Third Hand is extended in front of her, palm up, waiting to be held.** That is the most unsettling silhouette on the map.
- **Holding Hand (signature):** if a player gets within 2 m, the third arm grabs their hand. The screen vignettes, the audio drops to her humming alone, and she drags the player slowly while they take damage over time. Break it with melee or by teammates shooting the hand.
- **Double Damage:** **all of Alix's hits do 2× normal zombie damage.** Her standard swipe alone downs a player with no Ironhide.
- **Lash:** the third arm whips out to 5 m in a flat arc (crouch or slide under it). The telegraph is her two normal arms rising slowly to her ears.
- **When a cousin dies:** Alix goes to the body and **holds its hand** for 3 seconds (an interruptible window where she takes ×2 damage), then rises enraged. Her third arm now drips Nachtglas light and lashes twice per attack.
- **Creepy layers:**
  - She never blinks.
  - Her steps make no sound; only the dress rustles.
  - When she's off-screen, she **moves only while no player is looking at her** (reuse the Grand Galleria mannequin rule from B&S as a nod). Her animation runs at full speed only while she's unseen, then snaps to a frozen pose when she's in view.
- **Weak point:** the palm of the Third Hand while it's extended (×2).
- **Death:** the third arm reaches up toward the ceiling, toward the inn upstairs, toward her aunt, and closes slowly into a fist.

### 2.6 Rewards & aftermath
- Clearing the round grants: **Death's Door**, **Resupply**, and **1,500 Scrip** per player.
- The **"The Game Is Over"** calling card.
- The **"Three Ribbons"** weapon charm, plus an Archive entry: the aunt's letter, found in the cellar, which unlocks only if the round is cleared.
- **After the round:** the cellar trapdoor stays open. Downstairs is a tiny hidden room with three chalk-drawn stick figures holding hands on the wall, plus a fourth, taller figure (the aunt) drawn far away. Shooting all three stick figures plays one last line of the rhyme and gives a free Mystery Crate pull. Nothing else, just a small mercy.
- **Later maps:** a tiny chalk drawing of three girls holding hands appears hidden somewhere on every later Gravelight map, as a collectible ("The Cousins Are Still Playing").

---

## 3. MAP 1 "KALTENBRUNN" — ROUND 15: **PAUL**

### 3.1 Who he was (canon)
**Pvt. Paul `[PAUL_LASTNAME]`**, a US Army combat engineer `[PAUL_UNIT, default: 82nd Airborne attached engineer]`, captured in the Ardennes. He was the strongest, loudest, most loyal man in his unit, the guy who carried everyone's pack on the march. Projekt Wiederkehr picked him for one reason: to find the **maximum dose of Ironhide Stout** a human could survive. They kept increasing it. He kept surviving. **He never broke and never stopped asking where his buddies were.**

Then they pushed it too far. Paul grew, and kept growing. Iron-red skin like the stout, riveted bone plates pushing through his skin like the barrel on the Ironhide mascot. IV lines of dark stout still run into his back from a cracked rack of Helvetia bottles he drags with him.

His last impulse is **"protect my guys."** He doesn't know who his guys are anymore, so everyone looks like the enemy, until the very end.

### 3.2 Spawn
- **Round 15** on Kaltenbrunn. This is separate from the Foreman (rounds 12–14 and periodic); **they never spawn in the same round.** Paul then returns every 8–10 rounds, stronger.
- **Arrival:** the whole headframe tower in the Minehead Yard shakes. A voice roars "WHERE'S MY SQUAD?!" over the PA (he's ripped through the radio room). Then he **leaps down from the headframe**, landing in a crater that knocks every nearby player down.
- **Base HP (solo):** 30,000. It scales up on later returns.

### 3.3 The Rage system (the Hulk-like core)
- **Rage meter (0–100)** shown on his boss bar as a filling stout bottle. Damage dealt to him raises it. So do players fleeing (he hates being left behind) and the sight of downed players.
- **Calm (0–33):** heavy, lumbering pursuit. Telegraphed haymakers; he picks up zombies and throws them.
- **Angry (34–66):** he grows ~15% (an animated scale-up with skin cracking and plates pushing out), moves faster, and **rips ore carts and rail sections out of the ground to throw.**
- **BERSERK (67–100):** he grows again, steam pours off him, and the iron-red glows. **Leap Slam** chases players across zones, so he can jump from the Minehead Yard onto the Admin balcony. **Thunderclap** sends a cone shockwave that knocks players back and strips barricades. **Charge** smashes through doors.
- **Cooling down:** shoot the **IV bottles on his back rack** (each one breaks with a stout splash) to drop his rage by 20. There are 6 bottles, and they regrow on his next return.

### 3.4 Moves & animations
- **Locomotion:** a knuckle-assisted gorilla run in Berserk, and a heavy two-legged stomp in Calm. Every step shakes the camera nearby, with foot IK planting hard on rubble and leaving cracked decals.
- **Grab & Squeeze:** he picks up a player in one fist (first-person view lifted off the ground). Teammates must hit him to free them; in solo, you mash melee to wriggle free while he roars in your face.
- **Ground Pound Combo:** two fists in a ring shockwave; jump to avoid it.
- **Zombie Throw:** grabs the nearest Gänger and throws it like a bowling ball, and it explodes into shards.
- **Headframe Climb:** at Berserk he climbs the steel headframe like a gorilla, then dives off it at a player (a huge telegraph: his shadow grows on the ground).
- **Idle / taunt:** he beats his chest. The dog tags clink. He looks at the crushed tin cup in his hand and for a moment almost remembers something.
- **Hit reactions:** small hits do nothing (no flinch). Big explosives make him stagger one knee down, and that is your damage window (×1.5).
- **Weak points:** the IV rack (rage drain) and **the back of his neck** where the main IV line goes in (×2 when he's facing away; flanking matters).

### 3.5 Death & the twist
- At 0 HP, he drops to his knees. The rage drains out of him all at once, his body shrinks a little, and the red fades.
- He looks at the nearest player and, for the first time, **recognizes them as an American/Allied soldier.** His last line is subtitled and gentle: *"...Hey. You found me. Tell the guys I carried my share."* (Write a version per character, plus Bolt and Vendelin.)
- He hands over the crushed tin cup and falls forward slowly. It is the most heroic death animation in the game.

### 3.6 Rewards
- **"PAUL'S LAST ROUND"** (unique drop): a battered Ironhide bottle. Drinking it gives **Ironhide Stout for free without using a perk slot** until you're downed. If you already have Ironhide, it gives a one-time +100 overshield instead.
- 2,000 Scrip per player, **Double Scrip**, and the **"Carried My Share"** calling card.
- **Archive:** Paul's POW card and his letter to his unit (`[PAUL_LETTER_DETAILS]`; default: he asks about a ball game back home and promises to buy the first round).
- **Character interactions:**
  - **Dutch** knew a Paul like him: *"Every unit's got one. The big one. The one who carries you."*
  - **Deacon** says a short prayer for him over the body (a unique animation).
  - **Wren** adds Paul's name to her notebook, the first name she writes that isn't a kill.

---

## 4. MAP 3 "MORGENROT" — ROUND 20: **THE SLENDER** (based on me, Devin)

### 4.1 Who he was (canon)
**Devin `[DEVIN_LASTNAME]`**, the **night watchman** of the Hohe Wacht observatory. A tall, thin, quiet man who took the overnight shift every night for years because he liked the silence and the stars. He sat up there with a lantern and a ring of keys and watched everything: every truck on the road, every light in the valley, every shadow in the pine forest. **Nothing got past him.** He logged it all in a thick watch-book, in perfect handwriting, every hour of every night.

When the facility fell, he kept his post. His last impulse is **"keep watch."** He still walks the Meiller Lanes forest and the Kessel ring road, lantern raised. He still logs everything he sees, and now **you're in the log.**

*(Creative note: the watch-book, the overnight shift, and the "nothing gets past him" detection all quietly nod to how I really work. Keep that subtle; the in-world version is a WW2 watchman.)*

### 4.2 Design (NOT Slender Man; see §0.4)
- **Extremely tall** (about 2.6 m), long-limbed, thin but not skeletal. He looks like a person, just too long, as if stretched by the night.
- A long, dark-gray **watchman's greatcoat** with brass buttons, the collar up, and a scarf. A peaked watchman's cap.
- **His face:** pale, calm, and *tired*, with eyes that glow faint violet and never blink. Render it to the `[DEVIN_SIGNATURE]` details (glasses, beard, etc.) if I've given them; otherwise use the defaults.
- **Props:** an old **brass lantern** that burns **violet**, a heavy **ring of keys** at his hip that jingles when he moves (and is silent when he's about to attack), and the **watch-book** under his arm, its pages fluttering.
- He never runs. He never needs to.

### 4.3 The Watch system (signature mechanic)
- Each player has a hidden **"LOGGED" meter** with severity tiers shown as a creeping screen effect and a whispered tier word:
  - **LOW:** faint film grain and a soft jingle of keys somewhere.
  - **MEDIUM:** violet static at the screen edges; the lantern glow appears between the trees.
  - **HIGH:** audio dropouts, the HUD flickers, footsteps match your footsteps.
  - **CRITICAL:** **he appears right behind you.**
- **What fills it:** being in his lantern's light, looking directly at him for more than 1.5s, standing still in the dark, and firing unsuppressed weapons in the forest.
- **What drains it:** breaking line of sight, standing in the Kessel floodlights (real light hides you from *his* light), and staying near teammates.
- **At CRITICAL, he "QUARANTINES" you:** the screen goes black, and you're pulled into **"The Watch Room,"** a small dark pocket dimension shaped like his observatory guard booth. Shelves of watch-books, a desk, a clock stuck at 3:00 AM, a window showing your teammates fighting below. To escape, find **your page in the watch-book** (one of 3 books, randomized) and **tear it out** within 25s, while he slowly walks in from the dark doorway. If you fail, you're downed when you're returned.
  - In co-op, teammates can shorten your quarantine by shooting his lantern.
  - In solo, the room's timer is 35s.

### 4.4 Moves & animations
- **Locomotion:** a slow, long-legged walk with almost no bob, perfectly smooth, the coat trailing. **He teleports between trees** when unseen: a flicker, a key-jingle, and he's 15 m closer. Never while observed.
- **Creepy layers:**
  - He **mirrors the player's movement** at a distance (they stop, he stops; they turn, he turns).
  - His head tilts with a slow, curious, observing angle, like he's taking notes.
  - At HIGH tier he **writes in the book** while walking, the pen scratching loudly in your audio.
- **Lantern Sweep:** raises the lantern, and a violet cone sweeps the area. Players in it get logged fast (a strong telegraph: the light brightens slowly over 1s).
- **Key Ring Lash:** at close range, a long-armed backhand with the heavy ring of keys (high damage and a stagger).
- **Shift Change** (phase 2, below 50% HP): he splits into **3 Watchmen**, only one of them real. The decoys' lanterns flicker; the real one's lantern is steady. Shooting a decoy fills YOUR logged meter, so read the light, don't spray.
- **"End of Shift"** (phase 3, below 20%): the forest goes totally dark except his lantern, and the Kessel floodlights fail for 30s. Players must restore one floodlight generator (a lever, a 5s hold) to make him vulnerable again.

### 4.5 How to hurt him
- **He can only be damaged while lit** by the Kessel floodlights, the truck headlights at the Talstation, flares (a new crate tactical on this map: the **Leuchtpistole** flare gun), or a muzzle flash at under 5 m.
- In darkness, bullets pass through him like smoke. **Lure him into the light.**
- **Weak points:** **the lantern** (×2; break it to stun him for 6s, then it relights) and **the watch-book** (shooting it out of his hands makes him stop and pick up the pages, a ×1.5 damage window for 4s).
- **Die Lange Nacht** (v2 wonder weapon) freezes him in place for 3s even in darkness, because the frost catches the light.
- **Base HP (solo):** 35,000.

### 4.6 Death
- At 0 HP he stops and looks at the sky. Dawn is coming (it's always closer to dawn after his fight). He closes the watch-book, sets it down on the snow, sets the lantern on top, and blows it out.
- His last line, calm and relieved: *"...Shift's over. Someone else has the watch now."*
- He sits down against a pine tree and stays there, at peace, for the rest of the match. **He becomes part of the map:** a silent, harmless figure. Later rounds' zombies walk past him and never touch him.

### 4.7 Rewards
- **"OVERWATCH"** (unique reward): for the rest of the match, zombies within 12 m are outlined through walls in faint violet ("nothing gets past you now"). It doesn't use a perk slot.
- **The Watch-Book** Archive entry: every page logs a real event from the player's own match. Generate it from match stats: "03:12 — Subject [character] repaired a barricade. Diligent." / "03:47 — Subject went down near the Dam. Noted." This is the payoff of the logging fiction.
- 2,500 Scrip per player, the **"Night Shift"** calling card, and the **"Violet Lantern"** weapon charm.
- **If the main Easter egg is completed after the Slender is defeated:** in the Abort ending's final cable-car shot, his lantern is lit again, back at his post on the summit, keeping watch over the valley. A tiny final easter egg in the ending.

---

## 5. SHARED IMPLEMENTATION NOTES

- **Rigs:** the Cousins, Paul, and the Slender each get a custom skeleton derived from the shared humanoid rig (v2 §7.1) so the base animations still retarget. Custom extras: The Reach's telescoping arm bones, Alix's torso arm chain, Paul's scale-stage morphs and rack bone, the Slender's lengthened limbs and coat cloth sim (SoftBody3D or bone-chain cloth).
- **"Moves only when unseen":** implement once as a reusable `ObservedFreeze` component. It uses each player's view frustum plus a line-of-sight check, with full-rate animation and movement when unobserved and a pose freeze when observed. Use it for Alix and for the Slender's teleport.
- **Frame-stutter creepiness:** a reusable `AnimJitter` component that steps animation playback at 12 fps for short bursts, used sparingly (the Hammer's hitch step, the Reach's arm retract).
- **Audio:**
  - The Cousins' rhyme as three stems that drop out as each cousin dies.
  - Paul's roars layered with distorted human voice.
  - The Slender's key jingle as a positional cue that **goes silent right before he attacks** (silence is the telegraph).
  - All VO goes into `docs/VO_SCRIPT.md` with line IDs: every boss's lines plus every playable character's reaction lines (Dutch, Peg, Deacon, Wren, Bolt, Vendelin).
- **Readability:** every big attack has a 0.5–1.0s telegraph (pose + sound + light). These bosses are scary, never cheap.
- **Dev console:** `spawn_boss cousins|paul|slender`, `set_rage <n>`, `set_logged <player> <0-100>`, `force_quarantine`.
- **Tests (GUT):** HP scaling by player count; the Cousins' enrage chain and fail-safe retreat; the rage meter's thresholds and drain; LOGGED meter fill and drain; quarantine escape and fail; reward grants; the Homage toggle.
- **Archive & gallery:** each boss gets a boss-intro card in the Archive with its backstory, the likeness credit ("Inspired by Alix and her cousins" / "Inspired by Paul" / "Inspired by Devin"), and its death scene, viewable after the first kill.

---

## 6. MILESTONES (insert into the existing roadmap)

- **HB1 — The Cousins** (Map 0). Builds on MZ (v2 §9). If Map 0 is already built, do this immediately after MZ; otherwise do it with the Map 0 milestone.
- **HB2 — PAUL** (Map 1). Build it with or right after the Kaltenbrunn milestone.
- **HB3 — THE SLENDER** (Morgenrot). Build it with the Morgenrot milestone (v2 M8.5).

**Acceptance for each:**
- I can force-spawn the boss from the dev console and beat it in solo and in co-op.
- Every listed animation is in, and all telegraphs read clearly.
- Rewards grant correctly, and the Homage toggle works.
- A short capture of the full fight goes in the milestone summary.

## 7. YOUR FIRST RESPONSE TO THIS FILE
1. Read v1, v2, and the project's current `docs/` and `ROADMAP.md`. Summarize in a few lines where the build stands and where HB1–HB3 slot in.
2. Write `docs/HOMAGE_BOSSES.md`: the full design (with move lists, animation lists, telegraph timings, HP and damage tables), the Likeness Sheet (§1), the canon backstories, all boss and reaction VO, and the Cousins' rhyme lyrics. Update ENEMIES, LORE, VO_SCRIPT, JINGLES, ASSETS, and ROADMAP.
3. List every `[PLACEHOLDER]` from the Likeness Sheet I haven't filled in, so I can send the details.
4. Commit, then **pause for my review** before building.
