# HOMAGE BOSSES — The Cousins · PAUL · The Slender (GRAVELIGHT; ULTIMATE PROMPT v3; milestones HB1–HB3)

**Status: design only, paused for review (DECISIONS T-042).** Nothing here is built. Source: `C:\Users\Devin\PROJECTS\bolt-and-sprocket\ULTIMATE_PROMPT_V3_BOSSES.md` (v3), on top of v1 and v2. Where v3 conflicts with v1/v2 on these three bosses, v3 wins.

These three bosses are homages to real people in Devin's life: his cousins, his friend Paul, and Devin himself. They are love letters. In the game they are terrifying; out of it they are flattering: powerful, memorable, never mocking.

**Where things live.** This doc sits in `docs/` beside the other prompt-named design docs (`MAP3_MORGENROT.md`, `ZOMBIE_ANIM_SPEC.md`), as v3 §7 asks. The per-system docs carry summaries that point back here: `docs/gravelight/ENEMIES.md` §7, `docs/gravelight/LORE.md` §13.3 and §15, `docs/gravelight/VO_SCRIPT.md` §12 (the VO source of truth; §8 below mirrors it), `docs/JINGLES.md` §13 (the rhyme; §9 below mirrors it), `docs/gravelight/WEAPONS.md` §23, `docs/ASSETS.md`, `docs/ROADMAP.md` (HB1–HB3). The Likeness Sheet's data is `data/gravelight/bosses/likeness.json`.

---

## 0. Where the build stands, and where HB1–HB3 slot in

- **Built and playable:** Map 0 Crossroads Inn (with the Helvetia cellar, the Carters' Yard, the Crucible), Map 1 Kaltenbrunn, Map 2 Totenhafen (first playable), joined by the campaign chain (exfil at rounds 10 and 30, kit carried, T-033). Nine perks, three wonder weapons, the Crucible's three tiers (T-037), AI bot teammates (T-031), voiced placeholder VO (T-035), the slide and the in-match settings page (T-040).
- **MZ (v2 §7), the zombie animation upgrade, is built in the working tree but not yet committed** (T-041: the 19-bone `SkeletonProfileHumanoid` rig, the AnimationTree, ragdoll, dismemberment with the Gore setting, every map retrofitted). v3 rule 5 needs MZ first, so it is satisfied as soon as T-041 lands.
- **Designed, not built:** Morgenrot (Map 3, v2 milestone M8.5; `docs/MAP3_MORGENROT.md`) and Helvetia Works (M8). Bolt & Sprocket is between M3 (paused) and M4 (Verdant Sink built).
- **The slots** (ROADMAP):
  - **HB1 — The Cousins** (Map 0, round 10): Map 0 is built, so HB1 comes **immediately after MZ** is committed and reviewed.
  - **HB2 — PAUL** (Map 1, round 15): Kaltenbrunn is built, so HB2 comes **right after HB1**. HB1 builds the shared boss framework HB2 and HB3 reuse.
  - **HB3 — THE SLENDER** (Morgenrot, round 20): built **inside M8.5**, with the map, because he needs its forest, floodlights, truck and Launch Clock.

---

## 1. Rules for the homage bosses (v3 §0, applied)

1. **The Likeness Sheet drives the look** (§2). Hair, build, signature items and quirks come from it. The models are **stylized and zombified** in the MZ procedural style. They are not photoreal and not scans.
   - No real photo or face scan is ever imported unless it is in `assets/user_supplied/likeness/` with a note that the person agreed. That folder has no `likeness/` subfolder today, so nothing is used.
   - No real body feature is exaggerated for a joke. "Hulk-like" means **powerful**.
   - **Voices:** placeholder TTS like every other line (T-009, T-035). No real person's voice is cloned or imitated from recordings without that person's consent, by the same rule as scans.
2. **Every boss is a person first:** canon backstories in §4.1, §5.1 and §6.1, and in `LORE.md` §15.
3. **Toggles (Settings → Gameplay):**
   - **Homage Bosses: On / Off** (`GLSettings "homage_bosses"`, default On). When it's Off, a boss never spawns and its round plays as a normal round.
   - **Homage Names: Real / In-World** (`"homage_names"`, default Real). It sets which name shows on the title card, the boss bar, the subtitle speaker name and the Archive card heading.
     - **Real:** the real first name large, with the in-world name small beneath it ("ALIX · THE THIRD HAND").
     - **In-World:** only the in-world name ("THE THIRD HAND"). No real name appears anywhere on screen. Spoken lines that use a real name have an unnamed twin, which plays instead.
   - In co-op the **host's** settings decide, like Classic Rules.
4. **Originality:** the Slender is our design and must not copy the internet "Slender Man" (§6.2 has the checklist). The Cousins must not echo famous film twins or rhymes either (§4.1.4).
5. **Animation:** all three bosses use MZ (the rig, AnimationTree, additive layers, IK, ragdoll, dismemberment), extended with custom bones (§3.4).
6. **Health:** `HP = base × (1 + 0.75 × (players − 1))`. `players` is `MapRoot.scaled_player_count()`, the same count the Foreman's health uses, so bots count as they do for him. Tuning lives in `data/gravelight/bosses/*.json`. That is JSON, not `.tres`; see §13 D1.
7. **Presentation:** each boss gets three things.
   - A **title card in the red ledger-stamp style**: the HUD round stamp's rubber-stamp font in ledger red, slammed onto the screen with the stamp "thunk", plus a date line in the Ledger's typewriter face.
   - A **music sting** (§10).
   - An **Operator line on spawn and on death** (§8.1).

### 1.1 Readability (v3 §5)
Every big attack has a **0.5–1.0 s telegraph made of a pose, a sound and a light**; the tables below give all three for each attack. The bosses are scary, never cheap:
- no attack lands from off-screen without an audio tell;
- no grab can chain into another grab;
- every grab has a break-free that works in solo.

### 1.2 Art direction (binding for every model, animation and camera)
**All three:**
- Stylized and zombified on the MZ body kit.
- Nachtglas violet is the only saturated accent, apart from each boss's one signature colour: the Hammer's red-grey mittens, Alix's red ribbon, Paul's iron-red, the Slender's violet lantern.
- Each one is recognisable from 40 m in fog by silhouette and by sound (the v2 §7.6 rule).

**The Cousins: young women, creepy-doll horror, never sexualized.**
- They are written as **young women, roughly 18–22** (the Reach is the youngest at about 18, Alix about 20, the Hammer about 22). Their horror is the doll register: stillness, porcelain pallor, glassy unblinking eyes, joints that bend a little wrong, giggles that stop too suddenly.
- **Modest period clothing, always:** buttoned, long-sleeved, high-necked, below the knee or ankle-length (the sheet's coat, nightgown and cardigan, and Sunday dress). Gore and damage never tear or remove clothing. The only fabric that tears is the Reach's sleeves at the elbow as her arms stretch, and it shows stretched arm, nothing else.
- **No fan-service framing:** no low or upskirt camera, no lingering on bodies, no suggestive poses, idles or deaths, no wet or clinging cloth, no "pin-up" or flirtatious body language. Title-card and Archive framing is head-and-shoulders or full figure at eye level.
- **Alix's third arm** grows from the breastbone and is hidden under the red ribbon bow. The dress stays intact around it. The camera frames the **hand**, never her chest.
- **Their deaths are authored and dignified,** with no ragdoll sprawl: they never go into the MZ full ragdoll. Dismemberment applies only to the Reach's arms (her designed weak point), and only under the Gore setting. With Gore Off the arm "withers" back instead of severing.

**PAUL: powerful, heroic, never a joke.**
- He reads as a strongman and a protector, with a kind face under the rage. His three growth stages come from the stout; they are never played for laughs, and no line, animation or Archive text jokes about his size or weight.
- **Not Marvel's Hulk:** his skin is iron-red, like the stout, never green; no purple trousers; no "smash" catchphrase. The riveted bone plates echo the Ironhide barrel mascot.

**THE SLENDER: a person, just too long.**
- He is a calm, tired, kind-faced watchman. He is uncanny because he is patient and observant, never because he is monstrous. §6.2 has the originality checklist.

---

## 2. The Likeness Sheet (v3 §1)

Data: **`data/gravelight/bosses/likeness.json`**, which renders as this table. A value written as `[LIKE_THIS]` is an **unfilled placeholder**. The game never shows one: it uses the default beside it, and an empty default means the detail is left out.

| Boss | Real name | In-world name | Look (from Devin) | Quirk / signature to build in | Defaults for anything not given |
|---|---|---|---|---|---|
| Cousin 1 | `[COUSIN_1_NAME]` (default **"Mara"**) | **"The Hammer"** | Blonde hair; carries a mallet she throws | Throws the mallet like a boomerang and catches it | Long braid, oversized wool coat, knitted mittens |
| Cousin 2 | `[COUSIN_2_NAME]` (default **"Jo"**) | **"The Reach"** | Brown hair; extremely long arms | Reaching: grabs things far away, through windows and floors | Bob haircut with bangs, nightgown under a cardigan, bare feet |
| Cousin 3 | **Alix** | **"The Third Hand"** | An arm that extends out of her torso; double damage | The arm is "the hand she was always holding" | Dark hair in two buns, a too-big Sunday dress, a ribbon |
| Paul | **Paul** | **"PAUL"** (the title card just says PAUL) | Hulk-like (powerful) | `[PAUL_SIGNATURE: catchphrase, team, item, tattoo...]` | Big beard, rolled sleeves, dog tags, a crushed tin cup he carries everywhere |
| Devin | **Devin** | **"THE SLENDER"** | Based on Devin | `[DEVIN_SIGNATURE: hair, height, glasses, style...]` | Very tall, thin, calm; a watchman's greatcoat; a lantern and ring of keys; works the night shift |

Ages: the Cousins are young women (late teens to twenties), never sexualized (§1.2).

**Where each placeholder lands when it is filled:**

| Placeholder | Used in | If left unfilled |
|---|---|---|
| `[COUSIN_1_NAME]` | Title card (Real), boss bar, subtitles' speaker name, the cousins' named lines, the aunt's letter, the Archive card | "Mara" |
| `[COUSIN_2_NAME]` | Same, for the Reach | "Jo" |
| `[PAUL_LASTNAME]` | His POW card, the Archive card ("Pvt. Paul ___"), Peg's line `PEG_PAUL_DEAD_01` (named twin) | Left blank. The POW card's surname field is smudged by stout, and he is "Pvt. Paul" everywhere. |
| `[PAUL_UNIT]` | POW card, Archive card, Peg's read of his sleeve | "82nd Airborne attached engineer", **but see §13 D4: that default clashes with the Ardennes timeline.** |
| `[PAUL_SIGNATURE]` | Catchphrase → one extra `PAU_` bark and the tail of his last line. Team → the ball game in his letter, plus a cap or patch. Item → a second carried prop. Tattoo → a forearm decal under the rolled sleeve. | The defaults (beard, rolled sleeves, dog tags, tin cup) |
| `[PAUL_LETTER_DETAILS]` | His letter to his unit (§5.7) | He asks who won the Series and promises to buy the first round |
| `[DEVIN_SIGNATURE]` | The Slender's face and silhouette (glasses, beard, hair, height, style), the Archive card art | The defaults (tall, thin, calm, greatcoat, lantern, keys) |
| `[DEVIN_LASTNAME]` | The watch-book's flyleaf ("Property of D. ___, Night Watch"), the Archive card | Left blank: "Property of the Night Watch" |

**Unfilled as of this pass (all eight):** `COUSIN_1_NAME`, `COUSIN_2_NAME`, `PAUL_SIGNATURE`, `PAUL_LASTNAME`, `PAUL_UNIT` (has a default, but it needs a decision, §13 D4), `PAUL_LETTER_DETAILS`, `DEVIN_SIGNATURE`, `DEVIN_LASTNAME`. No consent note or likeness photo exists.

Text tokens: in Archive and VO text below, `%COUSIN_1_NAME%` and the like are replaced at runtime from the sheet, using the default when the sheet holds a placeholder. `%DEAD_COUSIN_NAME%` is whichever cousin just died. Curly braces stay reserved for the Operator's spliced words.

---

## 3. Shared systems (v3 §0.6, §5)

### 3.1 Health by player count
`HP = base × S(p)`, `S(p) = 1 + 0.75 × (p − 1)` → 1.00 / 1.75 / 2.50 / 3.25. This is the Foreman's `P_hp`, so bosses and the Foreman feel consistent.

| Boss | Base (solo) | 2P | 3P | 4P |
|---|---|---|---|---|
| The Hammer | 6,000 | 10,500 | 15,000 | 19,500 |
| The Reach | 5,000 | 8,750 | 12,500 | 16,250 |
| Alix, the Third Hand | 7,500 | 13,125 | 18,750 | 24,375 |
| PAUL (first visit) | 30,000 | 52,500 | 75,000 | 97,500 |
| PAUL (each later visit, §5.2) | ×(1 + 0.35 × visit) → 40,500 / 51,000 … solo | | | |
| THE SLENDER | 35,000 | 61,250 | 87,500 | 113,750 |

For scale: a round-10 Gänger has 1,045 HP; the Foreman has 30,000 solo at round 12.

### 3.2 The boss framework (new, built in HB1, reused by HB2/HB3)
- **`HomageBoss`** (`gravelight/enemies/homage/homage_boss.gd`, proposed). It extends the MZ `Zombie` body and tree and adds:
  - a data-driven move table: each move has its telegraph (pose clip, sound id, light), active window, damage, cooldown and counter;
  - per-hitbox weak-point multipliers that a state can switch on and off ("mallet in the air", "arm extended", "facing away");
  - phases (enrage steps);
  - a grab-and-break-free helper (§3.6);
  - the boss bar (§3.8);
  - the title card, sting and Operator spawn/death lines (§1.7).

  Bosses ignore barricades, never become crawlers, and are never culled by the last-zombie rule.
- **Round control** (`RoundManager`):
  - A boss round is never a special round. A Bellringer or LUFTALARM round that would land on it moves to the next round, as the Foreman already does.
  - A boss round is never a Foreman or Startmeister round either: that boss moves +1.
  - The normal horde keeps spawning at a reduced rate during the fight (Cousins 40%, Paul 60%, Slender 50%), and the round ends when the boss and the horde are both done.
  - The schedule rides the campaign carry-over (`next_boss`), as the Foreman's does.

### 3.3 Reusable components (v3 §5)
- **`ObservedFreeze`** (`gravelight/enemies/components/observed_freeze.gd`). A boss is **observed** when it is inside any living player's view frustum (the camera's, widened 5°) **and** a line-of-sight ray from that camera reaches its head or chest bone. Bots count as observers, so a bot squad still pins Alix.
  - **Unobserved:** full-rate animation and the component's `unseen_speed`.
  - **Observed:** the tree's time scale snaps to 0 in under one frame, so the pose freezes mid-step, and movement stops.
  - Checked at 20 Hz, with 2 observers per frame in round-robin and a 0.1 s hysteresis so it never flickers.
  - Used by **Alix** (beyond 8 m) and by the **Slender's teleport**. B&S's Grand Galleria mannequins (BS_LEVELS §7, M4, not built) are meant to share it, as v3 asks for the nod: whichever is built first owns it.
- **`AnimJitter`.** It steps a tree's playback at **12 fps** for a burst (0.2–0.6 s), holding each pose for 1/12 s, then returns to full rate. Used sparingly: the Hammer's hitch step (every third step) and the Reach's arm retract. With Settings → Accessibility "reduce screen effects", bursts are halved in length, never removed, because they are a gameplay tell.

### 3.4 Rigs (derived from the MZ humanoid, so every shared clip still retargets)
Each boss skeleton is the 19-bone `zombie_rig.gd` rig plus extra bones. The extras are appended after the shared ones, so the `BoneMap` and shared clips are unchanged. Boss-only clips are procedural, baked by a `homage_clips.gd` beside `zombie_clips.gd`.

| Boss | Extra bones | Notes |
|---|---|---|
| The Hammer | `Braid1..3` (spring chain), `Mallet` (attachment) | Standard proportions; the head look-at gets a 180° limit (§4.3) |
| The Reach | `LeftUpperArm_b/_c`, `LeftLowerArm_b/_c`, the same on the right (+8: a 3-segment telescoping humerus and forearm) | Stretch to 4× by animated bone translation along the chain plus a little scale. The skin shader's `stretch` uniform pulls the veins taut and widens the Nachtglas cracks. |
| Alix | `ThirdRoot`, `ThirdUpper`, `ThirdLower`, `ThirdHand` (a 4-bone chain from the chest) + an IK target `ThirdHandTarget` | Rest pose folded flat under the ribbon. It opens "like a lock-knife": each joint snaps open in sequence over 0.25 s. |
| PAUL | `Rack` (on the spine), `Bottle1..6` (attachments, each a separate hitbox), `IVLine` (a 3-bone spring to the neck) | Three growth stages by rest-scale on the spine and limbs (×1.00 / ×1.15 / ×1.30), plus plate meshes that extrude in on stage change. Morphs are per-stage body variants built by `ZombieBody` (the MZ bodies are procedural). |
| THE SLENDER | Lengthened limb rests (~1.55× the humanoid's proportions), `CoatBack1..4`, `CoatL1..3`, `CoatR1..3` (bone-chain cloth on springs, cheaper than SoftBody3D), `Lantern`, `Keys`, `Book` (attachments) | Coat cloth sim on the bone chains, with gravity and wind from the map's gusts |

### 3.5 Damage taken (shared rules)
- Limb multipliers as ENEMIES §2 unless a table below overrides them. Boss heads take ×2.0 (Paul ×1.25).
- Explosives deal ×1.0 to the body.
- Wonder weapons deal their listed boss rates (Super Sprocket ×0.5 on bosses).
- Every boss is immune to instant-kill power-ups: Death's Door doubles the damage they take instead.

### 3.6 Grabs and break-free (one helper for every grab)
A grab pins the player (no shooting except the held sidearm hand where stated) and shows a **break prompt**. It breaks on whichever of these comes first:
- the grabbed player's melee mash (N presses within the window);
- teammates' damage to the grabbing limb or weak point (a % of max HP);
- a set time limit (the grab ends by itself).

Bots break grabs too: they shoot the limb (BotBrain targets the grabbing weak point while a teammate is held). Nothing re-grabs the same player for 4 s after a release.

### 3.7 Audio framework
- **Stems:** the Cousins' rhyme is three stems, one voice each; a cousin's death mutes her stem.
- **Positional cues:** the Hammer's mallet scrape, the Reach's knuckle drag, the Slender's keys. **Silence is a telegraph** for the Slender: his keys go quiet before every attack (§6.4).
- **Boss voices:** a positional `BOSS` channel group (one line per boss at a time). It is not in the story group, so it never blocks the Operator.

### 3.8 HUD: title cards and boss bars
**Title cards:** the red ledger stamp, 2.2 s, then the name settles into the top-centre boss bar.
- **The Cousins:** three thin bars stacked, each with its cousin's name. A dead cousin's bar is crossed out in pencil, like a struck ledger line.
- **PAUL:** one bar plus the **rage meter drawn as a stout bottle filling**, with its three tiers marked on the glass.
- **THE SLENDER:** one bar with a small **lantern pip**. It shows lit amber when he can be damaged and grey when he can't, so players learn the light rule without a tutorial.
- In In-World name mode the bars show the in-world names.

### 3.9 Dev console (v3 §5)

| Command | Effect |
|---|---|
| `spawn_boss cousins\|paul\|slender` | Start that boss's encounter now, on its map; on the wrong map it says which map |
| `spawn_boss hammer\|reach\|alix` | One cousin alone (testing) |
| `set_rage <0-100>` | Paul's rage, with the growth stage that goes with it |
| `set_logged <player> <0-100>` | A player's LOGGED meter (player = id or `all`) |
| `force_quarantine [player]` | Pull a player (default: the local one) into the Watch Room now |
| `boss_phase <n>` | Skip the live boss to phase / enrage step n |
| `homage on\|off`, `homage_names real\|world` | The two settings for this session |

### 3.10 Archive and gallery (v3 §5)
Each boss gets a **boss-intro card** in the Archive. It holds:
- the canon backstory (LORE §15);
- the **likeness credit**: "Inspired by Alix and her cousins" / "Inspired by Paul" / "Inspired by Devin";
- the title card art;
- a replay of the **death scene**, viewable after the first kill.

The ids are `ARC_HB_COUSINS`, `ARC_HB_PAUL`, `ARC_HB_SLENDER`, and the cards are profile unlocks. The documents (the aunt's letter, Paul's POW card and letter, the Watch-Book) are Archive items listed in LORE §13.3. The game's credits roll gains one line: "The homage bosses are inspired by Alix and her cousins, by Paul, and by Devin."

---

## 4. HB1 — Map 0 "Crossroads Inn", round 10: THE COUSINS

### 4.1 Who they were (canon; LORE §15.1)

**The Kreuzweg's nieces.** Three cousins were sent down from the city to wait out the winter of 1944 with their aunt, **Helene "Lene" Vogt**. She is the innkeeper's wife, and the Gasthaus Zum Kreuzweg was her family's inn before it was Anselm's (canon addition, logged in LORE).
- They had spent every childhood summer at the inn. Every night of every summer they played the same game in the dark: a clapping rhyme that counts down from three, then hide, and whoever is left is "it".
- Their nicknames come from those summers:
  - **%COUSIN_1_NAME%** split the firewood with the inn's splitting maul;
  - **%COUSIN_2_NAME%**, the youngest, was always stretching for the jam jar on the top shelf;
  - **Alix** held the others' hands in the dark, every night, so nobody was scared.

**The night of 23 December 1944.**
- At 23:41 GRAVELIGHT ONE came down in the east field, burning. People were coming up along the rails who were not walking right.
- Lene would not put the girls in the cellar with the humming machines. She took them down instead to the **old ice cellar under the bar**, a trapdoor nobody had used since the war began.
- She told them to **keep playing their game, quietly, and stay down until she came back.** Then she went up for her daughter Käthe, who would not leave the wireless.
- **She never came back.** Käthe's fate, and Anselm's, stay **[OPEN]** (LORE §13.1). The Cousins never say.
- The girls had been drinking from the yard well all winter. After the Erwachen of 20 December, the **Nachtglas dust in the well water** did the rest, quietly, in the dark, a few metres under the squad's feet.

**Last impulse: the game.** They are still playing it, and the players are now "it".
- **The Hammer** still splits the wood. She throws the maul, and it always comes back to her hand.
- **The Reach** never stopped stretching. Her arms never stopped either.
- **Alix, the Third Hand**, would not let go when the others died. The arm growing out of her chest is **the hand she is still holding out for them**.

#### 4.1.4 Originality guardrails (the Cousins)
- **No film-twin echoes:** no "come play with us", no two girls side by side at the end of a corridor, no matching dresses (the three outfits are deliberately unlike each other).
- **The rhyme is original** (§9). It counts *down* from three and names no killer. It must not borrow the shape of any famous horror counting rhyme.
- **No chalk confusion on Morgenrot:** the chalk stick figures here are a child's game drawing. They must never be placed near Morgenrot's laborer memorial marks (§4.6).

### 4.2 The Cousins Round (round 10 replaces the normal round)

| Time | Beat | Notes |
|---|---|---|
| End of round 9 (the last kill) | The inn's lamps **gutter and go out one by one**, taproom → upstairs → stable, about 0.8 s apart, with a breath-out sound each. The fireplace dies to embers. Ambient music cuts. | If the cellar lever is thrown, the cellar stays lit, so the perk machines still glow. The lamps relight at the end. |
| Break +3 s | A **child-sized handprint smears across the taproom's north-west window from the outside**, a wet violet streak on frost. | A decal on the glass; it stays all round |
| Break +6 s | Silence. Then **three pairs of hands clapping, upstairs** (`CSN_CLAP_01`), in the rhyme's rhythm; then the **hummed** rhyme (three stems). | The Operator's half-formed setup line `OPR_BOSS_COUSINS_M0_01` |
| Round 10 starts | **Title card** for the Hammer. **Her maul is thrown down the stairwell first**: it tumbles down the flight, bounces off the vestibule wall and spins back up out of sight. 1.5 s later **the Hammer appears at the stair head** and skips down. | If Door 1 (750) is still closed, she splits it open on her way through. It stays open, free. |
| +30 s | **The Reach**, from the stable hayloft. **Her arms come through the taproom windows before her body does**: two arms snake in through two windows, feel along the sills, withdraw. 3 s later she drops from the hayloft (or, with Door 2 closed, climbs over the yard passage roof and comes in through a taproom window). | Title card on her body's first appearance |
| A cousin below 50% HP (or a cousin dies, or 3:00 into the round at the latest) | **Alix climbs up out of the trapdoor behind the bar**, a hatch the map never showed before. Dust and old ice fall from it, then a small hand comes up palm-first, then she rises perfectly upright, as if lifted. Title card. | The trapdoor is a hidden prop for this round only. After the round it stays open (§4.6). |

**Trio rules:**
- While all three live they **hum in harmony**: three stems in a close, slightly-off triad.
- **Each death removes a voice** from the song, and the survivors **enrage**:
  - +20% move and attack speed per death (stacking: +20%, then +40%);
  - one new attack each (§4.3–4.5);
  - the humming turns to **whispering** after the first death.
- **The last one standing sings alone, and it is awful.** Her line is sung full voice, too slow, a little sharp, and **she leaves a gap where each dead cousin's verse should be**. In the gap there is only her clapping, waiting for hands that don't come.
- **Lamps:** one lamp group relights at each death (taproom first), and all of them relight when the round clears. The fight gets more readable as it goes.
- **Horde:** normal Gängers keep spawning at **40% of round 10's count**, so the round stays chaotic but readable. The round ends when all three cousins are dead and the reduced horde is cleared.

**Fail-safe: the Cousins get bored.** If the round runs past **6:00**, they retreat laughing (`CSN_BORED_01`):
- the Hammer goes back up the stairs, the Reach into the hayloft, Alix down the trapdoor, which closes;
- the round ends normally once the horde is cleared, with no rewards;
- they **return on round 15 with full HP**, by the same sequence with a new Operator line (`OPR_BOSS_COUSINS_RETURN_M0_01`). Proposed: if they get bored again, they return every 5 rounds until cleared.

**Interplay with the existing systems:**
- **Specials:** if the Bellringer special round would land on 10 (or 15 on a return), it moves to the next round.
- **Fasbender's round-10 radio line** (`FAS_M0_R10_01`) moves to round 10's end, under the relit lamps.
- **The campaign beacon** (T-033: "THE CARTERS' ROAD" lights when round 10 starts):
  - with Homage Bosses On, the beacon's opening round becomes **11**, after the Cousins (retries 14, 17 … as usual);
  - squads that exfil before a bored return simply leave the Cousins playing at the inn;
  - with Homage Bosses Off nothing changes.

### 4.3 The Hammer

**Stats:**
- **HP:** 6,000 solo (§3.1).
- **Speed:** a 3.4 m/s skip-walk (+20% per enrage).
- **Hitboxes:** head ×2.0, body ×1.0, mittens and arms ×0.8.
- **Scrip:** 400 per player when she dies.

**Moves:**

| Move | Telegraph (pose + sound + light) | Active | Damage | Cooldown | Counter |
|---|---|---|---|---|---|
| **Maul drag swipe** (basic) | 0.5 s: the maul lifted off the floor, the sparks stop | 0.2 s, 2.4 m arc | 50 | 1.4 s | back off |
| **Mallet Throw** (signature) | **0.9 s total.** She **stops humming for one beat** (0.65 s at the rhyme's 92 BPM). Then a 0.25 s wind-up spin, braid swinging. The maul's head flares violet. | Flies at 14 m/s up to 25 m. It **arcs like a boomerang and curves round corners**: it follows the nav corridor toward the target, turning at most 90°/s, and rounds at most one corner. It **hits on the way out and on the way back**, then she **catches it without looking**. | 45 per pass (up to 3 targets per pass) | 6 s | Duck or step out of its line; dodge the **return**, which comes from behind. Punish her while it flies (weak point). |
| **Ricochet Throw** (enraged, after the first death) | Same, but the hum-stop lasts **two** beats | **Banks off two walls** (reflect on any surface within 30 m) before returning | 45 per pass | 7 s | Watch the first bounce: the return line is the mirror of it |
| **Overhead Split** | 0.8 s: both hands overhead, a creak of the haft, a violet glint on the head | 0.15 s, 2.5 m in front | 80 + the floor cracks: a **splinter zone** 3 m across for 3 s (move ×0.6, 5 per 0.5 s) | 9 s | Side-step; don't stand in the splinters |
| **Unarmed slap** (while the maul is in the air) | 0.4 s | 1.8 m | 25 | — | It's her weakest moment |

**Weak point:**
- **While the maul is in the air she is unarmed: all damage ×1.5**, and **a melee hit staggers her** (1.2 s, interrupting the catch).
- The maul then drops where she stands and she must stoop for it (1.0 s, still ×1.5).

**Creepy layers:**
- **The locked head:** her head stays locked on the nearest player even while her body walks away. It is an additive head-look with a **180° limit**, and the neck and shoulder joints visibly over-rotate past what a neck should do.
- **The catch:** when she catches the maul she **giggles and her whole body freezes for 0.3 s**, perfectly still, mid-pose, even the braid. Then she moves on as if nothing happened.
- **The hitch step:** her skipping walk **hitches, every third step missing a frame** (AnimJitter, 12 fps for one step). She drags the maul one-handed and its head scrapes **sparks** off the floorboards (a positional scrape loop and a spark trail).

**Animation list:**
- Locomotion: skip-walk (hitched), skip-walk enraged, idle (rocking heel-toe), turn-in-place ×2.
- Stairs: descend skipping (foot IK).
- Attacks: drag swipe, throw wind-up spin, throw release, catch (blind, behind the back), catch-freeze giggle, stoop-pickup, overhead split, unarmed slap.
- Reactions: stagger, flinch set (MZ additive).
- Enrage: snap-to-face (her head turns first, the body follows a beat later).
- Retreat: skip backward up the stairs, waving.
- Death: sit, maul across the lap, still, slow doll topple.

**Death:** she **sits down cross-legged, lays the maul across her lap, and stops**. 2 s. Then she **topples over slowly, like a doll**, stiff, all in one piece (authored, no ragdoll).

**Drop: the KINDERHAMMER** (WEAPONS.md §23.1):
- Her maul becomes a **throwable melee weapon** for whoever picks it up first, for the rest of the match.
- Hold melee to throw: it boomerangs back.
- Bolt, if playing, says *"...Oh, that's mine. Kind of."* (`BLT_KINDERHAMMER_01`), a quiet callback to his mallet throw.

### 4.4 The Reach

**Stats:**
- **HP:** 5,000 solo.
- **Speed:** a 3.0 m/s hunched walk (+20% per enrage); ceiling crawl 2.6 m/s.
- **Hitboxes:** head ×2.0, body ×1.0, arms ×0.8; **wrists ×2.0 while extended**.
- **Scrip:** 300 per player when she dies, plus her drop.

**Moves:**

| Move | Telegraph | Active | Damage | Cooldown | Counter |
|---|---|---|---|---|---|
| **Swipe** (basic) | 0.5 s: the arm uncoils | 3 m | 45 | 1.3 s | — |
| **Long Reach Grab** (signature) | **0.7 s:** the arm coils back over her shoulder, **her counting fingers stop**, a wet stretching creak, and the wrist glow brightens | The arm **shoots out up to 12 m** (24 m/s), grabs a player and **drags them toward her** at 2.5 m/s | **Hug-Crush** if she reels you in: 120 over 1.5 s (downs a player without Ironhide; Ironhide 250 → 130) | 8 s | **Break free:** shoot the glowing wrist for 8% of her max HP, melee-mash 6 presses, or a teammate's 250 damage to the arm. Bots shoot the wrist. |
| **Both Hands** (enraged, after the first death) | The same telegraph, both arms coil at once | Two grabs at two players (or one player, twice as fast) | as above | 10 s | Spread out |
| **Through-the-Wall** | **0.6 s: dust falls and the boards creak** at the spot (ceiling dust from above, floorboards bowing from below, a window board bulging) | An arm punches through floorboards or window boards **from the next room or the floor below**: a 1.5 m column | 60 + slowed ×0.7 for 0.8 s | 7 s | Watch the dust and move off the spot |
| **Window Spider** | **1.0 s: every barricade in the zone rattles at once** and every window's frost cracks | She hangs **outside** the building and **reaches through every window of the target's zone at once** for 6 s: a 2 m swipe area inside each window. Each barricade loses one board. | 40 per swipe | 25 s | Get away from the windows; while she hangs outside she is exposed through the glass (shoot her body) |

**Movement:**
- She walks hunched, knuckles dragging, arms folded and coiled against her chest like a spring.
- **On ceilings she crawls upside down along the rafters using only her arms, body hanging.** This uses authored rafter lines (MZ `ClimbLink` with a `ceiling` kind) in the taproom's beams and the stable's hayloft rafters. She drops from them onto players: 0.6 s, the body swinging.

**Weak point:**
- **The wrists while the arms are extended: ×2.**
- **Cutting an arm off** (75% of an arm's damage pool, 750 solo, with Gore Low/Full) disables that arm's grab until it **regrows 20 s later**, with a horrible animation: the stump shivers, then the arm unfolds out of it segment by segment with wet cracks (`RCH_REGROW_01`).
- With Gore Off the arm withers and folds back instead, same timing.

**Creepy layers:**
- **Her fingers are never still.** They keep counting, one-two-three, and clapping silently, even when the rest of her is frozen. This is an additive finger layer on every state.
- **Her arms retract slowly and wrongly:** the joints fold backward, segment by segment (AnimJitter on the retract).

**Animation list:**
- Locomotion: hunched walk with knuckle drag, ceiling crawl (arms only, body hanging), ceiling-to-floor drop.
- Grab sequence: arm coil, arm shoot (telescope), grab-close, drag-reel, hug-crush, release.
- Wall and window moves: through-floor punch from below, through-window punch, window-spider hang outside (both arms through two windows, then a cycling sweep).
- Arm loss: arm sever, regrow (20 s), Gore Off wither-and-refold.
- Idles: the finger-counting layer, the reach-up (stretching for a shelf that isn't there).
- Reactions: stagger, flinches.
- Death: reach for the others, drop.

**Death:** both arms **slowly reach for the other cousins**, toward wherever they are, or where they fell, across the room, through a doorway if they must. Then the arms drop.

**Drop:** a guaranteed **Fortify** + **500 Scrip** per player.

### 4.5 Alix, the Third Hand

**Stats:**
- **HP:** 7,500 solo.
- **Speed:** a slow, stiff, perfectly upright 1.8 m/s walk within 8 m of a player. Beyond 8 m she is on **ObservedFreeze**: frozen while seen, **6.0 m/s while unseen**. +20% per enrage.
- **Hitboxes:** head ×2.0, body ×1.0; **the Third Hand's palm ×2.0 while extended**.
- **Scrip:** 500 per player when she dies.

**Double damage:** **all of Alix's hits do 2× normal zombie damage.** Her standard swipe is 100, and on its own it **downs a player without Ironhide** (100 HP); Ironhide players take three.

**Moves:**

| Move | Telegraph | Active | Damage | Cooldown | Counter |
|---|---|---|---|---|---|
| **Swipe** (basic, either normal arm) | 0.55 s: the arm lifts stiffly from the shoulder, no wind-up sound, only the dress rustling | 2.2 m | **100** | 1.6 s | Don't let her close; she is slow when seen |
| **Holding Hand** (signature) | **0.5 s:** the Third Hand turns palm up and its fingers open, and the hum drops out | If a player is within **2 m**, the third arm **takes their hand**. The screen **vignettes**, the audio drops to **her humming alone** (everything else ducks −18 dB), and she **drags the player slowly** (1.0 m/s, toward the trapdoor). | **30 per second** (2× a 15/s hold), up to 6 s | 10 s | **Break:** the held player's melee ×3, or teammates' 300 damage to the hand. Bots shoot the hand. |
| **Lash** | **0.9 s: her two normal arms rise slowly to her ears**, as if she can't bear a sound | The third arm **whips out to 5 m in a flat arc** at chest height | **90** | 6 s | **Crouch or slide under it** |
| **Double Lash** (enraged) | the same | **Two lashes per attack**, the second 0.4 s after the first, mirrored | 90 each | 7 s | Stay down for both |

**When a cousin dies:**
- Alix walks to the body and **holds its hand for 3 s**, kneeling, the Third Hand folded over both. This is an **interruptible window in which she takes ×2 damage** (`ALX_COUSIN_01`). 20% of her max HP in the window ends it early.
- Then she **rises enraged**. **Her third arm now drips Nachtglas light**: an emissive drip trail that lights the floor, a readability gift in the dark inn. **Lash becomes Double Lash.**
- If Alix arrives after a cousin is already dead, she goes to that body first.

**Weak point:** the **palm of the Third Hand while it is extended: ×2**. It is extended almost always; it folds away only during Lash's wind-up.

**Creepy layers:**
- **She never blinks.**
- **Her steps make no sound;** only the dress rustles.
- **She moves only while no player is looking at her** (ObservedFreeze, the Grand Galleria mannequin rule as a nod):
  - beyond 8 m, her animation runs at full speed only while she is unseen, then **snaps to a frozen pose** the instant someone looks;
  - within 8 m she simply walks, slowly, upright, **as if she's being led by the hand**, the Third Hand extended in front of her, **palm up, waiting to be held**. That is the most unsettling silhouette on the map.

**Animation list:**
- Locomotion: the upright led-by-the-hand walk, the unseen glide (the same walk at speed), freeze poses (sampled from the walk; the freeze holds the current frame), turn without turning (the head turns, then the body snaps to match).
- Third arm: the lock-knife unfold (third arm open), the fold-flat (under the ribbon), the take-hand grab, the drag hold.
- Attacks: lash (rising arms, then the whip), double lash, swipes ×2.
- Trapdoor emerge: hand, then the rise as if lifted.
- Grief: kneel and hold a body's hand.
- Enrage: rise with the drip.
- Reactions: stagger, flinches.
- Retreat: lower into the trapdoor without bending.
- Death: reach up and close the fist.

**Death:** the third arm **reaches up toward the ceiling**, toward the inn upstairs, toward her aunt, and **closes slowly into a fist**. Then she is still, standing, and sinks to her knees (authored).

### 4.6 Rewards and aftermath

Clearing the round (all three dead) grants:
- **Death's Door** and **Resupply** drops at Alix's body (outside the 4-drop cap);
- **1,500 Scrip per player**;
- the **"The Game Is Over"** calling card;
- the **"Three Ribbons"** weapon charm: red, grey and navy ribbons tied round the foregrip. Weapon charms are a new cosmetic slot. HB1 records the unlock in `ProfileSave`, and the charm renders once the slot exists (no charm system yet, §13 D9);
- the **Archive entry "The Aunt's Letter"** (`INT_HB_01`, §4.7), found in the ice cellar. It unlocks **only if the round is cleared**.

**After the round, the ice cellar stays open:**
- Down a short ladder is a tiny hidden room, 3 × 2.5 m: three straw pallets, a lantern burnt dry, a jam jar, a pair of red-grey mittens, the letter on an upturned crate.
- On the wall, **three chalk stick figures holding hands**, and far off in the corner a **fourth, taller figure** (the aunt).
- **Shooting all three small figures** plays **one last line of the rhyme**, softly, in three voices together (`CSN_LASTLINE_01`), and gives **a free Mystery Crate pull** (the crate's next use at its current spot is free for whoever shot the last figure). Nothing else: just a small mercy.
- Zombies don't path into the ice cellar; it is a dead end with one ladder.

**Later maps: "The Cousins Are Still Playing."**
- A tiny chalk drawing of three girls holding hands is hidden on every later Gravelight map, as a collectible. Each one files an Archive stamp; all four set a profile flag that adds a fourth figure, hand in hand, to the Map 0 drawing.
- **Map 1:** inside the Rail Yard boxcar, low on the end wall.
- **Map 2:** under a torpedo trestle in the Torpedo Workshop.
- **Helvetia Works:** under the harmonium bench in the Jingle Room.
- **Morgenrot:** on the underside of the Bergbahn gondola's bench. **Never** in the Stollen or near any laborer memorial mark (v2 §0.1).

### 4.7 Archive text: The Aunt's Letter (`INT_HB_01`, DOC, Map 0)

> A sheet torn from the inn's order book, folded in four and left on an upturned crate in the ice cellar, under a burnt-dry lantern. Pencil, a hurried hand. Translated.
>
> Kreuzweg, the night of the 23rd.
> My girls,
> There is a fire in the east field. An aeroplane. And there are people coming up along the rails who are not walking right, and I do not want you to see them.
> You are to stay down here. Keep playing your game, the clapping one, the one you have played since you could stand. Play it quietly. Count down slowly, and then start again. Do not come up for anyone who is not me.
> I am going up for Käthe. She will not leave the wireless. When I have her we will all come down, and you can teach her the words properly, because she sings them wrong.
> Alix, hold their hands. You always do it best.
> %COUSIN_2_NAME%, the jam on the top shelf is yours. All of it. Don't stretch, stand on the crate.
> %COUSIN_1_NAME%, you are not to go out to the woodpile. I mean it. We have wood enough.
> I will be back before you finish the third verse.
> Tante Lene
>
> Under it, in a different pencil, in three hands, one line each: *"Dritter Vers." "Nochmal." "Nochmal."* (Third verse. Again. Again.)

---

## 5. HB2 — Map 1 "Kaltenbrunn", round 15: PAUL

### 5.1 Who he was (canon; LORE §15.2)

**Pvt. Paul %PAUL_LASTNAME%**, a US Army combat engineer (%PAUL_UNIT%), was captured in the Ardennes in the autumn of 1944 (the date is open: §13 D4).
- He was the strongest, loudest and most loyal man in his unit: the one who carried everyone's pack on the march, the one who never let anybody fall out.
- Abteilung III asked the front for "robust specimens". Projekt Wiederkehr picked him for one reason: to find the **maximum dose of Ironhide Stout a human could survive** (the IRON tolerance series).
  - They kept increasing it, and he kept surviving.
  - **He never broke, and he never stopped asking where his buddies were.** At every session he offered to take their doses for them. The request was declined each time.
- Then they pushed it too far. **Paul grew, and kept growing.**
  - His skin turned iron-red like the stout.
  - Riveted bone plates pushed through it like the barrel on the Ironhide mascot.
  - **IV lines of dark stout still run into his back** from a cracked rack of Helvetia bottles he drags with him.

The trials ran until the Erwachen of 20 December. When the facility fell he tore out of the Lab Wing, still on the drip.

**Last impulse: "protect my guys."** He doesn't know who his guys are any more, so everyone looks like the enemy, until the very end.

(A quiet parallel the writing honours: Wren's brother Tomasz was also "selected for a dosage trial owing to unusual tolerance" and also "asked repeatedly" for someone (CHARACTERS.md, Wren's dossier 10). Wren notices; §8.)

### 5.2 Spawn and schedule

- **Round 15 on Kaltenbrunn**, in addition to the round's (reduced, 60%) horde. Standalone and campaign alike: the campaign reaches Map 1 at round 11, so 15 is in reach.
- **Never in the same round as the Foreman** (r12–14 first, then every 5–7) **or a Bellringer round:** those move +1.
- **Arrival:**
  1. At round 15's start the **whole headframe tower in the Minehead Yard shakes**: dust off the girders, the cage chains swinging, the pylon's hum warbling.
  2. A voice roars **"WHERE'S MY SQUAD?!" over the PA** (`PAU_PA_01`). He has ripped through Fasbender's radio room in the Admin block. Its door is torn off, cosmetically; the egg's step-2 objects are untouched.
  3. A 3 s beat, then he **leaps down from the headframe** (he's been up it the whole time) and lands in a **crater** that **knocks every player within 10 m down** (0.8 s knockdown, no damage) and leaves a cracked-concrete decal for the match.
  4. Title card.
- **Returns (§13 D5):** v3 says he returns every 8–10 rounds, stronger. Here that means **he returns until he is beaten**.
  - If he is not killed within **6:00**, he roars, climbs the headframe and leaps away north (`PAU_LEAVE_01`, `OPR_BOSS_PAUL_LEFT_01`). He is back 8–10 rounds later with **+35% HP per return** and **all six bottles regrown**.
  - Once he is killed, the death and the twist (§5.6) play and he is **gone for the match**: his death is the most heroic in the game and is never undone.
- **Arena:** he follows players anywhere.
  - On the surface (A–D) he jumps between zones (Leap Slam).
  - Into the depths he goes **down the lift shaft** (he drops the 40 m and lands in F's lift mouth with the crater) or smashes down the maintenance stairs.
  - He never enters the Core Vault (it's too small): if everyone is in I, he waits in G, roaring.

### 5.3 The Rage system (the Hulk-like core)

The **rage meter, 0–100**, shows on his boss bar as a **stout bottle filling**.

**What fills it:**

| Source | Rage |
|---|---|
| Damage dealt to him | +1 per 1% of his max HP |
| A player fleeing (sprinting away while within 20 m of him, after he has targeted them) | +4 per second per fleeing player |
| He sees a player go down | +10 at once, then +1 per second per downed player in his sight |
| Natural cooling (no damage taken for 8 s) | −0.5 per second (proposed) |
| **Shooting an IV bottle on his back rack** until it breaks (400 HP solo each, scaled) | **−20**, with a stout splash; 6 bottles, regrown on his next return |

**The three stages** (5-point hysteresis, so he can shrink back when cooled; the growth plays in reverse with a hiss of steam):

| Stage | Rage | Size | Speed | Unlocks |
|---|---|---|---|---|
| **Calm** | 0–33 | 2.5 m (×1.00) | 2.6 m/s heavy two-legged stomp | Haymaker, Zombie Throw, Grab & Squeeze |
| **Angry** | 34–66 | ×1.15, animated (skin cracks, plates push out, 1.2 s, he roars through it) | 3.6 m/s | + Ground Pound Combo, Rip & Throw (ore carts, rail sections) |
| **BERSERK** | 67–100 | ×1.30, steam pours off him, the iron-red **glows** | 6.2 m/s knuckle-assisted gorilla run (still under the 6.8 sprint) | + Leap Slam (across zones), Thunderclap, Charge, Headframe Climb & Dive |

**Hitboxes:**
- head ×1.25, body ×1.0, arms and legs ×0.8;
- bottles: separate hitboxes;
- **back of the neck, where the main IV line goes in: ×2.0 when he is facing away** (more than 120° from the attacker). Flanking matters.
- He takes **no flinch from small hits**. A big explosive (one blast of 3% or more of his max HP) **staggers him one knee down for 2.5 s: a ×1.5 damage window.**

### 5.4 Moves

| Move | Stage | Telegraph (pose + sound + light) | Active | Damage | Cooldown | Counter |
|---|---|---|---|---|---|---|
| **Haymaker** | all | 0.8 s: the arm drawn all the way back, the dog tags clink, a grunt | 2.8 m arc | 70 + knockback | 3 s | Back out of reach |
| **Zombie Throw** | all | 0.9 s: he grabs the nearest Gänger within 6 m and lifts it overhead, and it shrieks | Bowled along the ground at a player up to 25 m; it **explodes into shards** at the end | 60 direct, 30 shards in 2 m | 10 s | Side-step the line |
| **Grab & Squeeze** | all | 0.7 s: an open hand reaching, a roar | 2.5 m. He lifts the player in one fist. **First-person view lifted off the ground**, his face filling the frame. | 25 per second for up to 5 s | 14 s | **Teammates hit him** for 6% of max HP (or break a bottle). **Solo: mash melee** (8 presses) to wriggle free while he roars in your face. |
| **Ground Pound Combo** | Angry+ | 1.0 s: both fists raised together, steam | Two fists, then a **ring shockwave** expanding to 8 m at 10 m/s | 50 + knockdown | 12 s | **Jump** the ring |
| **Rip & Throw** | Angry+ | 1.0 s: he rips an **ore cart or rail section out of the ground** (Rail Yard track, the Minehead's cart spur) | Thrown up to 30 m in an arc, with a landing shadow | 90 + knockdown in 2.5 m | 14 s | Move off the shadow |
| **Leap Slam** | Berserk | 1.0 s: he crouches, and **his shadow grows** on the landing spot (it can be another zone: Minehead Yard → the Admin balcony) | Lands within 30 m | 100 in 3 m, 50 at 3–6 m, knockdown | 10 s | Leave the shadow |
| **Thunderclap** | Berserk | 0.8 s: arms flung wide, a huge inhale, steam vents from the plates | A 60° **cone shockwave** 14 m long | 40 + knockback 6 m; **strips every board from the barricades in the cone** | 9 s | Get out of the cone, or behind cover |
| **Charge** | Berserk | 1.0 s: head down, knuckles paw the ground twice | 11 m/s for up to 20 m. **Smashes through doors**: an unbought door he crashes through opens for free and stays open. | 90 + big knockback | 12 s | Side-step. If he hits a solid wall he is stunned for 2 s (×1.5 window). |
| **Headframe Climb & Dive** | Berserk, Minehead Yard only | Climbs the steel headframe like a gorilla (3 s, visible from the whole yard), then **his shadow grows** under the target for 1.2 s | A dive onto that spot | 130 in 3 m (downs a non-Ironhide player), 60 at 3–7 m | 30 s | Keep moving; the shadow follows you for 0.6 s then locks |

**Idle / taunt** (Calm only, when nobody has hurt him for 4 s, at most every 20 s):
- He **beats his chest**, and the **dog tags clink**.
- Then he **looks at the crushed tin cup in his hand** and, for a moment, almost remembers something. The rage meter dips 5, and he mutters `PAU_CUP_01`.
- It's a breather the players can use, or spoil.

### 5.5 Animation list
- **Locomotion:** Calm stomp (foot IK planting hard on rubble, a cracked decal every step, camera shake within 12 m), Angry stride, Berserk knuckle-run, turn-in-place ×2 per stage.
- **Growth and shrink:** grow Calm→Angry, grow Angry→Berserk, shrink back (steam).
- **Spawn:** the PA-roar silhouette in the radio room window (seen from the yard), the headframe leap and crater landing.
- **Attacks:** haymaker, zombie pick-up and bowl, grab-lift / squeeze / release (and the third-person version for teammates), the ground-pound pair and shockwave, rip cart, rip rail, throw, leap crouch / flight / land, thunderclap, charge start / run / wall-stun.
- **Headframe:** climb loop, perch, dive.
- **Bottles:** a bottle-break flinch (no stagger, a gasp).
- **Reactions:** knee-down stagger and get-up.
- **Idle:** chest beat, the tin-cup look.
- **Retreat:** headframe leap away.
- **Death sequence:** knees, the drain-and-shrink, the look, the cup hand-over, the slow fall forward.

### 5.6 Death and the twist
1. At 0 HP he **drops to his knees**. The **rage drains out of him all at once**: steam, the glow fading, the bottle on his boss bar emptying. **His body shrinks a little** and the red fades toward a human colour.
2. He **looks at the nearest player** and, for the first time, **recognizes them as an American / Allied soldier**. His last line, subtitled and gentle, is per character (`PAU_LAST_*`, §8.3): *"...Hey. You found me. Tell the guys I carried my share."*
3. He **holds out the crushed tin cup** and presses it into that player's hand. A first-person close-up for them, a third-person shot for the others.
4. Then he **falls forward slowly**, arms at his sides, like a tree going down: the most heroic death animation in the game.
5. **Music:** the round's music cuts to an original, solo, bugle-like trumpet phrase (§10; **not** "Taps"). No crater, no gore.

### 5.7 Rewards
- **"PAUL'S LAST ROUND"** (unique drop; WEAPONS.md §23.3): a battered Ironhide bottle at his body, **one per player**. That is the one deviation from "unique", because Paul wouldn't leave anybody out (§13 D7).
  - Drinking it gives **Ironhide Stout for free, without using a perk slot, until you're downed**.
  - If you already have Ironhide, you get a one-time **+100 overshield** instead.
- **2,000 Scrip per player**, a **Double Scrip** drop, and the **"Carried My Share"** calling card.
- **Archive:** Paul's POW card (`INT_HB_02`) and his letter to his unit (`INT_HB_03`), below.
- **Character moments** (VO in §8.3):
  - **Dutch** knew a Paul like him: *"Every unit's got one. The big one. The one who carries you."*
  - **Deacon** says a short prayer over the body (a unique kneel animation, hand on the shoulder, hat off).
  - **Wren** adds Paul's name to her notebook: the first name she writes that isn't a kill.
- The tin cup stays in the receiving player's hand as a viewmodel trinket during the next inspect, and as an Archive photograph.

**`INT_HB_02` — POW Card: Pvt. Paul (DOC, Map 1)**
> An index card from Abteilung III's intake drawer, stained with stout, left on the floor of the torn-up radio room. Typed, with handwritten entries. Translated.
>
> KRIEGSGEFANGENEN-KARTEIKARTE. Abt. III, Aufnahme Kaltenbrunn. (Prisoner-of-war index card. Abteilung III intake.)
> Name: PAUL, %PAUL_LASTNAME%. Rank: Private. Arm of service: Engineers (USA). Unit: %PAUL_UNIT%.
> Taken: Ardennes, autumn 1944. Condition on arrival: excellent. "Refuses to stop talking."
> Assigned: tolerance series IRON (Helvetia preparation "Eisenhaut").
> Dose, by session: 1×, 2×, 4×, 8×, 12×, 20×. Each one initialled: *survived*.
> Remarks: "Subject asks after the men of his unit at every session. Subject offers to take their doses. Request declined."
> Last entry, in red: "30×. Subject did not stop. Continue."
>
> On the back, in pencil, in big careful capitals, in English: "TELL THE GUYS I'M OK."

**`INT_HB_03` — Letter to the Unit (DOC, Map 1)** (default text; `[PAUL_LETTER_DETAILS]` replaces the ball game and the round)
> A letter on Red Cross form paper, never posted, folded into the band of a torn wool cap by the headframe. Pencil.
>
> Dear fellas,
> They let me write one. Don't know if it gets anywhere. If it does: I'm fine. Food's lousy, the doc's a sourpuss, and they keep giving me this beer that tastes like a tin roof. I keep drinking it so they don't give it to anybody else.
> Somebody tell me who won the Series. I had two bucks riding on it, and I'm not paying if I lost, on account of being indisposed.
> When this is over the first round is on me. Every round. You know I'm good for it.
> Keep your heads down and your feet dry. Somebody carry Eddie's pack up the hills. He won't ask.
> Your pal,
> Paul
> P.S. If you're reading this and you're not my guys, this is a letter. You're supposed to send it. That's how letters work.

---

## 6. HB3 — Map 3 "Morgenrot", round 20: THE SLENDER (based on Devin)

### 6.1 Who he was (canon; LORE §15.3)

**Devin %DEVIN_LASTNAME%** was the **night watchman of the Hohe Wacht observatory**.
- He came up the mountain before the war, when the Hohe Wacht was a civilian astronomy station with a night staff from half of Europe. He stayed on in 1939 when the Reich took it, because nobody else would sit up there all night, and because nothing ever got past him.
- He was a tall, thin, quiet man who took the overnight shift every night for years, because he liked the silence and the stars.
- He sat up there with a **lantern and a ring of keys** and watched everything: every truck on the valley road, every light in Sankt Aurel, every shadow in the pine forest.
- **Nothing got past him.** He logged it all in a thick **watch-book**, in perfect handwriting, **every hour of every night**.

When the facility fell, **he kept his post.**

**Last impulse: "keep watch."** He still walks the Meiller Lanes forest and the Kessel ring road, lantern raised, and he still logs everything he sees. Now **you're in the log**.

(Creative note from Devin, kept subtle: the watch-book, the overnight shift, and the "nothing gets past him" detection quietly nod to how he really works. In the world he is only ever a WW2 watchman.)

### 6.2 Design: NOT Slender Man (v3 §0.4)

**What he is:**
- **About 2.6 m tall**, long-limbed, thin but not skeletal. He **looks like a person, just too long**, as if the night stretched him.
- A long, dark-grey **watchman's greatcoat** with brass buttons, the collar up, a scarf, and a **peaked watchman's cap**.
- **His face:** pale, calm and **tired**, with eyes that glow faint violet and **never blink**. It is rendered to `[DEVIN_SIGNATURE]` (glasses, beard, hair) if given, otherwise to the defaults.
- **Props:**
  - an old **brass lantern burning violet**;
  - a heavy **ring of keys** at his hip that **jingles when he moves and goes silent when he is about to attack**;
  - the **watch-book** under his arm, its pages fluttering.
- **He never runs. He never needs to.**

**Originality checklist** (a review gate for the HB3 model, animations and VO):

| The internet character | Ours |
|---|---|
| Faceless, blank head | **A real, kind, tired face** with eyes; expressions (the curious head tilt, a faint polite smile at "Evening") |
| Black suit and tie | **A grey watchman's greatcoat**, brass buttons, scarf, peaked cap. No suit, no tie, ever. |
| Tentacles or extra limbs from the back | **Two arms, long.** Nothing grows from his back; the coat's tails are cloth. |
| Collect 8 scattered pages in a forest | **One page, about you, in a bound book**, in a pocket room. You tear it **out** to be let go. |
| Black-and-white TV static on proximity | **Violet film grain and Nachtglas crackle**, building through four named tiers, and he *talks*: calm, courteous lines |
| A silent stalker who kills on sight | A **watchman doing his rounds** who logs, warns, and takes you in "for review" |

### 6.3 The Watch system (signature mechanic)

Each player has a hidden **LOGGED meter (0–100)**. It exists only while he is alive. The tiers show as a creeping screen effect plus **a whispered tier word**, and all effects scale with "reduce screen effects".

| Tier | Range | Effect | Whisper |
|---|---|---|---|
| — | 0–9 | nothing | — |
| **LOW** | 10–39 | faint film grain; a **soft jingle of keys** somewhere, positional and far | "Noted." (`SLN_TIER_LOW_01`) |
| **MEDIUM** | 40–69 | **violet static at the screen edges**; **his lantern glow appears between the trees** in your direction, even if he is far | "Observed." |
| **HIGH** | 70–94 | **audio dropouts** (200 ms gaps), the **HUD flickers**, **footsteps match your footsteps** (a second set, 0.1 s late, behind you); he **writes in the book while walking**, the pen scratching loudly in your audio | "Logged." |
| **CRITICAL** | 95–100 | **He appears right behind you** (a teleport, even if observed, the only exception). At 100 he quarantines you. | "Quarantined." |

**What fills it:**

| Source | Rate |
|---|---|
| Standing in his lantern's light (its 8 m pool) | +12 per second |
| A **Lantern Sweep** cone | +35 per second for its 2 s |
| Looking directly at him for more than 1.5 s | +8 per second after the 1.5 s |
| Standing still in the dark (no light source on you, 2 s or more) | +4 per second |
| Firing an unsuppressed weapon in the forest (B_MEILLER) | +2 per shot (at most +10 per second) |
| Shooting a decoy (Shift Change) | +15 per hit |

**What drains it:**

| Source | Rate |
|---|---|
| Out of his line of sight | −6 per second |
| Standing in Kessel floodlight or flare light (real light hides you from *his* light) | −15 per second |
| Within 6 m of a teammate (stacks with the above) | −4 per second |

**Quarantine:**
- **At 100 he "QUARANTINES" you.** The screen cuts to black, there is a key-turn sound, and you're pulled into **"The Watch Room"**, a small dark pocket room shaped like his observatory guard booth. It is a Nachtglas echo of the real one, built off-map below the playable space.
  - Inside: shelves of watch-books, a desk with a green-shaded lamp, a **clock stuck at 3:00 AM** that never ticks, and a **window showing your teammates fighting below**, a live render of the map from the booth's real summit position.
- **To escape:**
  1. Find **your page in the watch-book**. It is **one of 3 books**, randomized by the match seed; each book glows faintly when you're near and shows a page headed with your character's name.
  2. **Tear it out** (hold Use, 1.5 s) within **25 s**, while **he slowly walks in from the dark doorway** (1.0 m/s; he reaches the desk at 24 s).
- **Torn out in time:** you are returned standing, at the spot you were taken from, with 3 s of invulnerability. Your meter resets to 0 with 10 s of immunity (`SLN_ROOM_ESCAPE_01`).
- **Failed:** you are **downed when you're returned** (`SLN_ROOM_FAIL_01`). Second Wind and the revive rules apply as usual.
- **Co-op:** **teammates can shorten your quarantine by shooting his lantern** in the real world. Each lantern hit fills a release bar by 20%, and at 100% you're returned standing, page or no page. The Watch Room shows the bar as the window lightening.
- **Solo:** the room's timer is **35 s**.
- **Limits:**
  - one player in the room at a time (the second at 100 waits at CRITICAL);
  - while you're in it your body is gone from the map and zombies ignore your spot;
  - **bots never reach 100** (they cap at HIGH, §13 D8).

### 6.4 Moves

| Move | Phase | Telegraph | Active | Damage | Cooldown | Counter |
|---|---|---|---|---|---|---|
| **Walk** (locomotion) | all | — | 1.6 m/s, a long-legged walk with almost no bob, perfectly smooth, the coat trailing | — | — | — |
| **Teleport** | all | **Only while unobserved** (ObservedFreeze): a flicker and a key-jingle | **15 m closer**, behind a tree or a pillar | — | 4 s | Keep eyes on him; teammates watch each other's backs |
| **Mirroring** | all | — | Within 30 m and in sight, he **mirrors your movement**: you stop, he stops; you turn, he turns | — | — | Unnerving, not damaging. It also gives you a clean shot when he stops. |
| **Lantern Sweep** | all | **The lantern rises and the light brightens slowly over 1.0 s** (a rising glass-harmonic tone) | A **70° violet cone, 20 m**, sweeping 90° over 2 s | LOGGED +35 per second in the cone | 12 s | Break line of sight; get behind trees or into floodlight |
| **Key Ring Lash** | all | **The keys fall silent (0.6 s)**, then a 0.4 s backswing | At close range (2–4 m) a long-armed backhand with the heavy ring of keys | **85 + a 0.6 s stagger** | 4 s | **Silence is the telegraph:** when the jingle stops, move |
| **Shift Change** | **phase 2, below 50%** | "Change of shift." (`SLN_DECOY_01`) | He splits into **3 Watchmen**, only one of them real. **The decoys' lanterns flicker; the real one's lantern is steady.** Decoys walk, sweep and lash with the same timing, for 0 damage. | Shooting a decoy: +15 LOGGED to the shooter per hit (`SLN_DECOY_SHOT_01`) | They dissolve after 25 s, or when the real one takes 5% of max HP in light; recast every 40 s while in phase 2 | **Read the light, don't spray** |
| **End of Shift** | **phase 3, below 20%**, once | "Lights out. Last round of the night." | **The forest goes totally dark except his lantern** (every light, the moon and sky, the truck's headlights) **for 30 s**, and **the Kessel floodlights fail** and stay off | — | once | **Restore one floodlight generator**: one of the three ring-road masts' levers, a **5 s hold**. That mast relights, and he can be hurt in its light again. Flares and close muzzle flash still work in the dark. |

**Creepy layers:**
- His **head tilts** at a slow, curious, observing angle, like he's taking notes.
- At HIGH tier on any player, he **writes in the book while walking** (the pen-scratch in that player's audio).
- Between the trees, he is sometimes **simply standing at a distance, lantern raised**, logging. An idle that does nothing is the scariest thing he does.

### 6.5 How to hurt him

**He can only be damaged while lit.** In darkness, bullets pass through him like smoke: a violet smoke puff on hit, 0 damage, and his boss-bar lantern pip goes grey.

| Light | Where | Notes |
|---|---|---|
| **Kessel floodlights** | the three ring-road masts (on with power) | The arena's answer. Lure him into them. They're off during End of Shift until a generator is restored. |
| **Truck headlights** | Talstation chapel square (the squad's truck; on all match) | Two cones, 25 m. Off during End of Shift's 30 s. |
| **Flares: the Leuchtpistole** | a new crate tactical on Morgenrot (WEAPONS.md §23.2) | A landed flare lights 12 m for 20 s; one stuck to him lights him for 8 s |
| **Muzzle flash at under 5 m** | anywhere | Close and brave |
| **Die Lange Nacht** (v2 wonder weapon) | anywhere | **Freezes him in place for 3 s even in darkness** ("the frost catches the light"). While frozen he counts as lit. |

**Weak points:**
- **The lantern: ×2.** It has 3% of max HP (1,050 solo). **Breaking it stuns him for 6 s** (`SLN_LANTERN_01`, he gropes in the dark), then **it relights**. In co-op every lantern hit also fills a quarantined teammate's release bar (§6.3).
- **The watch-book.** 2% of max HP shoots it **out of his hands**. Pages scatter, and **he stops to pick them up: a ×1.5 damage window for 4 s** (`SLN_BOOK_01`). After that the book can't be shot loose again for 30 s.
- Head ×2.0 (lit), body ×1.0.

**HP:** 35,000 solo.

### 6.6 Spawn and schedule
- **Round 20 on Morgenrot**, with a 50% horde. **He needs the power on** (the floodlights). If power is still off at round 20, he comes on the first round after power-on (20 or later).
- **Never in the same round as the Startmeister or a LUFTALARM round** (they move +1).
- **Never during the main egg's Heartstorm or Reinholt** (steps 8–10): he waits until they're over.
- **Arrival:**
  1. At round 20's start, **keys jingle** across the whole forest, positional from everywhere at once.
  2. Then a single **calm voice** from the trees: *"Evening. Don't mind me. I'm only on my rounds."* (`SLN_ARRIVE_01`)
  3. A lantern lights at the far end of the Meiller Lanes. Title card.
- **Fail-safe (proposed, §13 D6):** if he isn't beaten within **8:00**, he walks back into the pines (`SLN_LEAVE_01`). The meters clear, and he returns 5 rounds later at full HP.

### 6.7 Animation list
- **Locomotion:** the smooth long walk (coat cloth), turn-in-place (slow, the head first), the mirror stop and turn (matched to the target).
- **Idles and teleport:** standing watch with the lantern raised, the observing head tilt (additive), the teleport flicker-out and flicker-in (ObservedFreeze-gated).
- **The book:** writing in it while walking (book open, pen), the book shot out of his hands (the pages scatter), kneeling to gather the pages.
- **Attacks:** lantern raise and sweep, key ring silence pose (hand closes over the keys), backhand lash.
- **Lantern break:** lantern broken, stunned and groping, relight.
- **Phases:** shift-change split (two copies peel off his silhouette), end-of-shift (he blows the lights out across the valley with one gesture of the lantern).
- **The Watch Room:** the doorway walk-in, slow and inevitable.
- **Reactions:** stagger (small), frozen by Die Lange Nacht.
- **Death:** look at the sky, close the book, set it down, set the lantern on it, blow it out, sit against a pine.
- **Afterwards:** the seated idle (breathing, eyes closed).

### 6.8 Death
1. At 0 HP he stops and **looks at the sky**. **Dawn is coming.** The SkyClock jumps a notch toward red, cosmetic only; it never moves the Launch Clock. It is always a little closer to dawn after his fight.
2. He **closes the watch-book**, **sets it down on the snow**, **sets the lantern on top**, and **blows it out**.
3. His last line, calm and relieved: *"...Shift's over. Someone else has the watch now."* (`SLN_DEATH_01`)
4. He **sits down against a pine tree and stays there, at peace, for the rest of the match.** He becomes part of the map: a silent, harmless figure with his eyes closed. **Later rounds' zombies walk past him and never touch him**: nav ignores him and nothing targets him.

### 6.9 Rewards
- **"OVERWATCH"** (squad-wide, the rest of the match, no perk slot): **zombies within 12 m are outlined through walls in faint violet** ("nothing gets past you now"). The outline is a depth-ignoring rim on the MZ shader, at most 24 zombies, and it respects "reduce screen effects".
- **The Watch-Book** (`INT_HB_04`): an Archive entry whose **every page logs a real event from that player's own match** (below).
- **2,500 Scrip per player**, the **"Night Shift"** calling card, and the **"Violet Lantern"** weapon charm.
- **The ending easter egg:** if the main egg ("Letztes Licht") is completed **after the Slender is defeated**, the Abort ending's final cable-car shot (CUTSCENES_MORGENROT shot 4a, the summit through the window) shows **his lantern lit again, back at his post on the summit**, keeping watch over the valley. A tiny final easter egg. The Moon and Launch endings don't show it.

**The Watch-Book's pages.** They are generated at match end from EventBus events logged while he was alive *and* after: he logged the whole night.
- **Times** read from the in-world night clock (the SkyClock: dusk 18:00 → dawn 06:00).
- **Selection:** at most one entry per event type per round and 40 entries in all, chronological, in his perfect hand.
- **Templates** (text, not voiced; `<subject>` is the character's name, `<zone>` a zone name):

| Event | Template |
|---|---|
| Barricade repaired | `<time> — Subject <subject> repaired a barricade. Diligent.` |
| Player downed | `<time> — Subject <subject> went down near the <zone>. Noted.` |
| Revive | `<time> — Subject <subject> got <subject2> back on their feet. Good.` |
| Perk bought | `<time> — Subject <subject> bought a <perk>. Receipt kept.` |
| Door bought | `<time> — Subject <subject> opened the way to the <zone>. Door left open. Noted.` |
| Stood still in the dark (≥ 10 s) | `<time> — Subject <subject> stood very still in the dark. Thought I wouldn't see. I did.` |
| Looked at him (≥ 5 s total) | `<time> — Subject <subject> looked at me for <n> seconds. Courteous.` |
| Power on | `<time> — Power restored at the Dam. Lights in the valley. Lovely.` |
| Kills (per round, the top player) | `<time> — Subject <subject> put down <n> of them. Tallied, not judged.` |
| Quarantine escaped / failed | `<time> — Subject <subject> was taken in for review. Found their page. Excused.` / `... Did not find their page. Noted.` |
| Decoy shot | `<time> — Subject <subject> shot the wrong lantern. Twice.` |
| Rocket sabotaged | `<time> — The <LONDON> rocket fell off its trailer. Good riddance.` |
| His defeat | `<time> — Shift ended. Relieved by: <squad>. Nothing further to report.` |

---

## 7. Damage summary (all three; player 100 HP, Ironhide 250, Gänger hit 50)

| Boss | Attack | Damage | Telegraph | Downs a 100-HP player? |
|---|---|---|---|---|
| Hammer | drag swipe / Mallet Throw (per pass) / Overhead Split / slap | 50 / 45 / 80 + splinters / 25 | 0.5 / **0.9** / 0.8 / 0.4 s | split + a pass, yes |
| Reach | swipe / Through-the-Wall / Window Spider / Hug-Crush | 45 / 60 / 40 / **120** | 0.5 / **0.6** / **1.0** / the grab's 0.7 s | Hug-Crush, yes |
| Alix | swipe / Lash / Holding Hand | **100** / 90 / 30 per second | 0.55 / **0.9** / **0.5** s | swipe, yes (her rule) |
| Paul | haymaker / zombie throw / squeeze / ground pound / rip-throw / leap / thunderclap / charge / dive | 70 / 60+30 / 25 per second / 50 / 90 / 100 / 40 / 90 / **130** | 0.8 / 0.9 / 0.7 / 1.0 / 1.0 / 1.0 / 0.8 / 1.0 / 1.2 s | dive, yes |
| Slender | Key Ring Lash / quarantine fail | 85 + stagger / downed | **silence 0.6 + 0.4 s** / the 25–35 s room | the room, yes |

Every move is at or inside the 0.5–1.0 s telegraph band. The Dive has 1.2 s and the Window Spider 1.0 s, on purpose: both reach players who can't see the source.

---

## 8. VO — every boss line and every playable character's reaction (mirrors VO_SCRIPT.md §12)

**Ids:** `{SPK}_{CAT}_{NN}` (VO_SCRIPT §1.1).
- **New speakers:** `HAM` the Hammer, `RCH` the Reach, `ALX` Alix, `CSN` the Cousins together (stems, clapping, giggles), `PAU` Paul, `SLN` the Slender.
- **Bolt and Vendelin** use the `BLT_` / `VEN_` / `SPR_` form, as VO_SCRIPT §11 does. Their CHARACTERS.md §6–7 quote-pack topic aliases are `boss_cousins`, `boss_paul`, `boss_slender` and `kinderhammer`.

**Rules:**
- **Subtitles:** the Cousins speak German. Their lines show the German, then the English in parentheses (VO_SCRIPT §1.5). Speaker names follow Homage Names (Real: "MARA"; In-World: "THE HAMMER").
- **Named lines:** a line containing a cousin's real name carries `conditions.homage_names: "real"` and has an **unnamed twin** (marked "twin") for In-World mode.
- **Priority:**
  - spawn / death / last lines: tier 4;
  - boss barks: tier 2, on the `BOSS` group;
  - squad reactions: tier 1, or tier 2 where marked;
  - the Operator: tier 3.
- **Extraction:** these tables use a `Line id` header, so `extract_vo.py` does **not** pick them up yet (it reads only tables headed `ID`). HB1 / HB2 / HB3 switch their block's header to `ID` and bake the lines with `gen_vo.py`, as the v2 Morgenrot reservation does.

### 8.1 The Operator (spawn and death lines for each boss)

| Line id | Trigger | Line |
|---|---|---|
| `OPR_BOSS_COUSINS_M0_01` | Map 0, end of round 9, the lamps going out | [static, half-formed, through the inn's horn] ...lights {out}, children... lights... {out}... |
| `OPR_BOSS_COUSINS_M0_02` | round 10 starts (spawn) | [static] ...it's... {playtime}. *[a child's clap on the tape]* ...{playtime}... |
| `OPR_BOSS_COUSINS_M0_03` | Alix rises | [static] ...one more... for the {game}... |
| `OPR_BOSS_COUSINS_DEAD_M0_01` | the first cousin dies | [static] ...{two} left... *[tape squeal]* |
| `OPR_BOSS_COUSINS_DEAD_M0_02` | the second cousin dies | [static] ...{one}... |
| `OPR_BOSS_COUSINS_DEAD_M0_03` | all three dead (death line) | [static, almost gentle] ...game... {over}. Good... {night}. |
| `OPR_BOSS_COUSINS_BORED_M0_01` | the 6:00 retreat | [static] ...they'll... come {back}... *[giggling under the hiss]* |
| `OPR_BOSS_COUSINS_RETURN_M0_01` | the round-15 return | [static] ...{ready}... or {not}... |
| `OPR_BOSS_PAUL_01` | Map 1, after the PA roar (spawn) | Oh my! A {gentleman} from overseas has broken into the {studio}! Do give him a warm welcome! |
| `OPR_BOSS_PAUL_02` | spawn (variant) | Ladies and gentlemen, our {strongest} account! Tremendous {tolerance}. Simply tremendous! |
| `OPR_BOSS_PAUL_03` | a return visit | Back by popular {demand}! And bigger than {ever}! |
| `OPR_BOSS_PAUL_RAGE_01` | his first BERSERK | Oh dear. He's gone right {off} the chart. We'll need a bigger {chart}! |
| `OPR_BOSS_PAUL_LEFT_01` | the 6:00 retreat | And he's off to find his {friends}! Aren't we {all}. |
| `OPR_BOSS_PAUL_DEAD_01` | his death (after the fall) | [three seconds of dead air] ...Maximum dose... {recorded}. *[and, very quietly, a splice from some other broadcast]* {Well done.} |
| `OPR_BOSS_SLENDER_01` | Morgenrot, round 20 (spawn) | Attention, valued customers: the night {shift} is now on duty. Please have your {papers} ready. |
| `OPR_BOSS_SLENDER_02` | spawn (variant) | Our {watchman} has never missed a night. Not {one}. Do try not to be {noticed}! |
| `OPR_BOSS_SLENDER_03` | Shift Change | Shift {change}! Three for the price of {one}! |
| `OPR_BOSS_SLENDER_04` | End of Shift | We are experiencing a brief {outage}. Please remain where you can be {seen}. |
| `OPR_BOSS_SLENDER_QUAR_01` | a player quarantined | A {customer} has been taken in for {review}. |
| `OPR_BOSS_SLENDER_LEFT_01` | the 8:00 retreat | The watch is... {rescheduled}. He'll be by again. He's always {by}. |
| `OPR_BOSS_SLENDER_DEAD_01` | his death | The night watch has clocked {out}! And dawn is... {closer} than you think. |

### 8.2 The Cousins (`HAM`, `RCH`, `ALX`, `CSN`)

| Line id | Trigger | Line |
|---|---|---|
| `CSN_CLAP_01` | end of round 9, upstairs | [three pairs of hands clapping the rhyme's rhythm, then stopping] |
| `CSN_HUM_01` | trio alive (stems, looped) | [the rhyme hummed in three voices: `jingle.cousins_rhyme` §9, stems A / B / C] |
| `CSN_WHISPER_01` | after the first death | [the rhyme whispered by the two survivors] |
| `CSN_GIGGLE_01` | random, 20–40 s | [a giggle from a room nobody is in] |
| `CSN_GIGGLE_02` | random | [two giggles, then a shush] |
| `CSN_BORED_01` | the 6:00 retreat | Langweilig! Morgen wieder! (Boring! Again tomorrow!) [laughing, running] |
| `CSN_RETURN_01` | the round-15 return | Bereit oder nicht, wir kommen! (Ready or not, here we come!) |
| `CSN_LASTLINE_01` | the ice cellar, all three chalk figures shot | [softly, three voices together, not scary] ...und wer noch übrig ist, ist dran. (...and whoever's left is it.) [a pause] Gute Nacht. (Good night.) |
| `HAM_THROW_01` | Mallet Throw release | Fang! (Catch!) |
| `HAM_CATCH_01` | the catch | [a giggle, cut off dead] |
| `HAM_SEE_01` | sees a new target | Ich seh dich. (I see you.) |
| `HAM_IT_01` | a player downed by her | Du bist dran. (You're it.) |
| `HAM_WOOD_01` | Overhead Split | Holz für Tante! (Wood for Auntie!) |
| `HAM_ENRAGE_01` | a cousin dies (named) | %DEAD_COUSIN_NAME%? ...%DEAD_COUSIN_NAME%! |
| `HAM_ENRAGE_TWIN_01` | the same (twin) | Wo bist du? ...Komm raus! (Where are you? ...Come out!) |
| `HAM_ALONE_01` | the last one standing | Jetzt sind nur noch ich. (Now there's only me.) [wrong on purpose: a child's grammar] |
| `HAM_DEATH_01` | death (sitting) | ...Ich mag nicht mehr spielen. (...I don't want to play any more.) |
| `RCH_COUNT_01` | idle (her fingers counting) | [whispered] Eins, zwei, drei... eins, zwei, drei... (One, two, three...) |
| `RCH_GRAB_01` | Long Reach Grab hits | Hab dich! (Got you!) |
| `RCH_REEL_01` | the drag | Komm her. Komm her. Komm her. (Come here. Come here. Come here.) |
| `RCH_HUG_01` | Hug-Crush | Halt still. Ganz still. (Hold still. Very still.) |
| `RCH_WALL_01` | Through-the-Wall, from below | [a knock under the floorboards] Hier unten... (Down here...) |
| `RCH_WINDOW_01` | Window Spider | Alle Fenster! Alle! (Every window! Every one!) |
| `RCH_REGROW_01` | an arm regrows | [a wet crack, then a sigh] ...nochmal. (...again.) |
| `RCH_SHELF_01` | idle reach-up | Nur noch ein bisschen höher... (Just a little bit higher...) |
| `RCH_ENRAGE_01` | a cousin dies | Du hast geschummelt! (You cheated!) |
| `RCH_DEATH_01` | death (reaching) | ...wartet auf mich. (...wait for me.) |
| `ALX_ARRIVE_01` | rising from the trapdoor | [a whisper] Ich hab sie noch. Ich halt sie noch. (I've still got them. I'm still holding on.) |
| `ALX_HOLD_01` | Holding Hand | Nicht loslassen. (Don't let go.) |
| `ALX_HOLD_02` | Holding Hand (variant) | Tante kommt gleich. Halt fest. (Auntie's coming soon. Hold tight.) |
| `ALX_UNSEEN_01` | a player turns away within 12 m | [right behind them] Hinter dir. (Behind you.) |
| `ALX_COUSIN_01` | holding a dead cousin's hand (named) | %DEAD_COUSIN_NAME%. Ich bin da. (I'm here.) |
| `ALX_COUSIN_TWIN_01` | the same (twin) | Ich bin da. Ich bin ja da. (I'm here. I'm right here.) |
| `ALX_ENRAGE_01` | rising enraged | Ihr habt sie losgelassen. (You let go of her.) |
| `ALX_DEATH_01` | death (the fist closing) | ...Tante? (...Auntie?) |

### 8.3 PAUL (`PAU`)

| Line id | Trigger | Line |
|---|---|---|
| `PAU_PA_01` | arrival, over the PA (channel PA) | WHERE'S MY SQUAD?! |
| `PAU_LAND_01` | the crater landing | [a roar with a man's voice inside it] |
| `PAU_CALM_01` | Calm, bark | Count off! ...COUNT OFF! |
| `PAU_CALM_02` | Calm, bark | Gimme your pack. I got it. I GOT it. |
| `PAU_CALM_03` | Calm, bark | Nobody gets left. Nobody. |
| `PAU_FLEE_01` | players fleeing (rage up) | DON'T YOU RUN! Nobody runs out on the squad! |
| `PAU_DOWN_01` | sees a player go down | MAN DOWN! ...MAN DOWN! ...medic... |
| `PAU_ANGRY_01` | becomes Angry | You're not my guys. YOU'RE NOT MY GUYS! |
| `PAU_BERSERK_01` | becomes BERSERK | [a roar, and inside it] WHERE ARE THEY?! |
| `PAU_GRAB_01` | Grab & Squeeze | GOT you. Who sent you? WHERE ARE THEY? |
| `PAU_THROW_01` | Zombie Throw / Rip & Throw | Heads UP! |
| `PAU_BOTTLE_01` | a bottle breaks | [a gasp] ...cold. That's cold. |
| `PAU_BOTTLE_02` | a bottle breaks (variant) | ...that's enough, doc. That's enough. |
| `PAU_CUP_01` | the tin-cup idle | [quietly, to the cup] ...coffee's on me, fellas. Whole pot. ...Fellas? |
| `PAU_KNEE_01` | knee-down stagger | Not yet. Not YET. |
| `PAU_LEAVE_01` | the 6:00 retreat | I'm coming, fellas! HOLD ON! |
| `PAU_LAST_DUT_01` | death, nearest player Dutch | ...Hey. Sarge. You found me. Tell the guys I carried my share. |
| `PAU_LAST_PEG_01` | death, Peg | ...Hey. Ma'am. You're English? Huh. You found me. Tell the guys I carried my share. |
| `PAU_LAST_DEA_01` | death, Deacon | ...Hey. Grease on your hands. Good man. You found me. Tell the guys I carried my share. |
| `PAU_LAST_WRN_01` | death, Wren | ...Hey. You're not one of them. You found me. Tell the guys I carried my share. |
| `PAU_LAST_BLT_01` | death, Bolt | ...Hey. Kid. Nice hammer. You found me. Tell the guys I carried my share. |
| `PAU_LAST_VEN_01` | death, Vendelin | ...Hey. Mister. You look like a man who keeps his word. You found me. Tell the guys I carried my share. |

### 8.4 THE SLENDER (`SLN`)

| Line id | Trigger | Line |
|---|---|---|
| `SLN_ARRIVE_01` | arrival, from the trees | [keys, then a calm voice] Evening. Don't mind me. I'm only on my rounds. |
| `SLN_TIER_LOW_01` | a player reaches LOW | [whisper] Noted. |
| `SLN_TIER_MED_01` | MEDIUM | [whisper] Observed. |
| `SLN_TIER_HIGH_01` | HIGH | [whisper] Logged. |
| `SLN_TIER_CRIT_01` | CRITICAL (he's behind you) | [right behind you, kindly] Quarantined. |
| `SLN_WRITE_01` | writing at HIGH (pen scratch) | [writing] ...three-twelve. Subject out after curfew. Noted. |
| `SLN_WRITE_02` | writing (variant) | [writing] ...stood very still. Thought I wouldn't see. |
| `SLN_MIRROR_01` | the first mirror stop | You stop, I stop. That's only manners. |
| `SLN_SWEEP_01` | Lantern Sweep | Let's have a look at you. |
| `SLN_ROOM_01` | Watch Room entry | Everyone has a page. Find yours. |
| `SLN_ROOM_02` | Watch Room, 12 s in | It's three o'clock. It's always three o'clock in here. |
| `SLN_ROOM_ESCAPE_01` | page torn out | ...Fair enough. You're excused. |
| `SLN_ROOM_FAIL_01` | the timer runs out | Noted. |
| `SLN_DECOY_01` | Shift Change | Change of shift. |
| `SLN_DECOY_SHOT_01` | a decoy is shot | Wrong lantern. Noted. |
| `SLN_DARK_01` | End of Shift | Lights out. Last round of the night. |
| `SLN_BOOK_01` | the book shot from his hands | [pages scattering] ...Ah. My book. One moment. |
| `SLN_LANTERN_01` | the lantern broken (stun) | ...Can't see. Can't see a thing. |
| `SLN_LEAVE_01` | the 8:00 retreat | Rounds aren't finished. I'll be back this way. |
| `SLN_DEATH_01` | death | ...Shift's over. Someone else has the watch now. |

### 8.5 The squad: Dutch, Peg, Deacon, Wren

| Line id | Trigger | Line |
|---|---|---|
| `DUT_COUSINS_01` | the lamps going out | Lamps are going. All of 'em. ...Somebody's turning 'em down. |
| `DUT_COUSINS_02` | the clapping upstairs | That's clapping. Upstairs. I don't like games I don't know the rules to. |
| `DUT_HAMMER_01` | the first Mallet Throw | Mallet! Heads down, it comes back! |
| `DUT_REACH_01` | the first Long Reach Grab | Her arms— how long are her ARMS? |
| `DUT_ALIX_01` | Alix rises | Girl's got a hand comin' out of her chest. And it's... waitin'. Like it wants me to take it. |
| `DUT_COUSINS_DEAD_01` | round cleared | They were just kids playin' a game. Somebody should've come back for 'em. |
| `DUT_LETTER_01` | reads the aunt's letter | She went up for her girl and told the others to keep playin'. ...Yeah. I'd have done the same. |
| `DUT_KINDERHAMMER_01` | picks up the Kinderhammer | Splittin' maul. Comes back when you throw it. My old man'd have sold his soul for one. |
| `PEG_COUSINS_01` | the lamps going out | The lamps are being put out. Methodically. One does hate a methodical enemy. |
| `PEG_COUSINS_02` | the clapping | Clapping. A children's game. ...Positions, everyone. Quietly. |
| `PEG_HAMMER_01` | the first Mallet Throw | She's thrown it, and it's coming back. Duck on the return, not the throw. |
| `PEG_REACH_01` | Window Spider | Mind the windows. All of them. She's at every window at once. |
| `PEG_ALIX_01` | Alix rises | Don't take her hand. Whatever it costs you, don't take her hand. |
| `PEG_COUSINS_DEAD_01` | round cleared | Three girls in a cellar, told to wait for someone who wasn't coming. I know a little about orders like that. |
| `PEG_LETTER_01` | reads the letter | "Keep playing, and stay quiet until I come back." ...She meant it kindly. They always mean it kindly. |
| `PEG_KINDERHAMMER_01` | picks it up | A splitting maul that comes back. I can think of three uses already. |
| `DEA_COUSINS_01` | the fire dies | Fire's out. Didn't burn down. Something just... told it to stop. |
| `DEA_COUSINS_02` | the clapping | Lord. That's a clapping game. Ruthie plays that on the porch. |
| `DEA_HAMMER_01` | the first Mallet Throw | That's a splitting maul. She's throwing it like it weighs nothing. |
| `DEA_REACH_01` | Through-the-Wall | Arms through the floorboards! Watch your feet! |
| `DEA_ALIX_01` | Alix rises | She's holding her hand out like she's waiting on somebody to take it. Lord, who's she waiting on? |
| `DEA_COUSINS_DEAD_01` | round cleared | Rest now, girls. Game's over. Somebody came. ...It was just us. |
| `DEA_LETTER_01` | reads the letter | Ruthie's twelve. ...I'm gonna go stand outside a minute. |
| `DEA_KINDERHAMMER_01` | picks it up | Good balance on this. Somebody took care of this tool. |
| `WRN_COUSINS_01` | the lamps going out | The lamps. One. Two. Three. Someone is counting them out. |
| `WRN_COUSINS_02` | the humming | A counting game. Every village has one. This one is wrong. |
| `WRN_HAMMER_01` | the first Mallet Throw | When the hammer is in the air, she has nothing. Shoot her then. |
| `WRN_REACH_01` | the first grab | The wrists. They glow. Shoot the wrists. |
| `WRN_ALIX_01` | Alix's first freeze | She only moves when we look away. So nobody looks away. |
| `WRN_COUSINS_DEAD_01` | round cleared | I will not write them in the book. They were not marks. |
| `WRN_LETTER_01` | reads the letter | She went to get her daughter. That is all. That is the whole story. |
| `WRN_KINDERHAMMER_01` | picks it up | Heavy. Good. It comes back, which is more than most things here. |
| `DUT_PAUL_01` | the PA roar | That's an American voice on the PA. ...That's an American VOICE. |
| `DUT_PAUL_02` | first sight | Big fella's wearing dog tags. Ours. Aw, hell. |
| `DUT_PAUL_RAGE_01` | his first Angry | The bottles on his back! Shoot the bottles, calm him down! |
| `DUT_PAUL_DEAD_01` | after the fall (tier 2) | Every unit's got one. The big one. The one who carries you. |
| `DUT_PAUL_CUP_01` | Dutch receives the cup | [turning it over] ...I'll buy the round, Paul. I'll buy every round. |
| `PEG_PAUL_01` | first sight | American. A private, engineers, what's left of the sleeve says so. They did this to one of ours. |
| `PEG_PAUL_02` | his first Angry | The bottles on his back are feeding him. Break them and he cools. |
| `PEG_PAUL_DEAD_01` | after the fall (tier 2) | Note it. Private Paul. Carried his share. ...Somebody in London ought to read that. |
| `PEG_PAUL_DEAD_NAMED_01` | the same, when `[PAUL_LASTNAME]` is filled | Note it. Private Paul %PAUL_LASTNAME%. Carried his share. ...Somebody in London ought to read that. |
| `PEG_PAUL_CUP_01` | Peg receives the cup | [quietly] I'll see it gets home, Private. You have my word. |
| `DEA_PAUL_01` | first sight | That's a soldier. That's a GI. Lord have mercy, what'd they pump into him? |
| `DEA_PAUL_02` | Calm, after a bottle breaks | Easy, big man. Easy. Nobody's leaving you. |
| `DEA_PAUL_PRAYER_01` | after the fall: the unique kneel (tier 2) | Lord, this man carried his brothers when they couldn't carry themselves. Carry him now. He's done his share. Amen. |
| `DEA_PAUL_CUP_01` | Deacon receives the cup | [softly] I'll keep it shined for you. |
| `WRN_PAUL_01` | first sight | They dosed him to see when he would die. He would not die. ...I know this file. I know this kind of file. |
| `WRN_PAUL_02` | his first turn away | The back of his neck, when he turns. The line goes in there. |
| `WRN_PAUL_NAME_01` | after the fall: writes in her notebook (tier 2) | [writing] Paul. ...Not a mark. A name. |
| `WRN_PAUL_CUP_01` | Wren receives the cup | [quiet] I will carry it. He carried enough. |
| `DUT_SLENDER_01` | first sight | Tall fella with a lantern. Just watching. I hate the ones that just watch. |
| `DUT_SLENDER_02` | Dutch at HIGH | He's writing. He's writing about ME. |
| `DUT_QUARANTINE_01` | returned from the Watch Room | Room full of books and a clock that don't move. I'm never goin' in a library again. |
| `DUT_SLENDER_DEAD_01` | his death | ...Shift's over, pal. Get some sleep. |
| `PEG_SLENDER_01` | his first smoke-hit in darkness | He only bleeds in the light. Bring him to the floodlights. Politely. |
| `PEG_SLENDER_02` | Shift Change | Three of him. Watch the lanterns. The steady one's real. |
| `PEG_QUARANTINE_01` | returned | A clerk's office with no clerk. I've been interrogated in worse. |
| `PEG_SLENDER_DEAD_01` | his death | A man who kept his post when everyone else ran. I've known worse men in better uniforms. |
| `DEA_SLENDER_01` | first sight | He's just doing his rounds. Lord, he's been doing his rounds this whole time. |
| `DEA_SLENDER_02` | his keys fall silent near Deacon | Keys went quiet— MOVE! |
| `DEA_QUARANTINE_01` | returned | Clock stopped at three. Mama always said nothing good happens after three. |
| `DEA_SLENDER_DEAD_01` | his death | Rest easy, watchman. We'll keep the lights on. |
| `WRN_SLENDER_01` | the first mirror stop | He stops when I stop. He turns when I turn. ...Good. I can count on him. |
| `WRN_SLENDER_02` | his book appears | The book! Shoot the book out of his hands! |
| `WRN_QUARANTINE_01` | returned | My page was neat. He has better handwriting than me. |
| `WRN_SLENDER_DEAD_01` | his death | He wrote everything down. Every hour. ...I understand him. |

### 8.6 Bolt (with Sprocket) and Vendelin

| Line id | Trigger | Line |
|---|---|---|
| `BLT_COUSINS_01` | the lamps going out | Okay. Okay. Lights going out one at a time is a BAD sign where I'm from too. |
| `SPR_COUSINS_01` | the clapping | Bolt, my sensors say three heartbeats. Then zero. Then three again. I'd like to stop sensing now. |
| `BLT_HAMMER_01` | the first Mallet Throw | Is she— that's a mallet throw. She's doing the throw! |
| `BLT_ALIX_01` | Alix rises | Nope. Nope. Sprocket, don't look at it. Wait. DO look at it. Keep looking at it! |
| `BLT_COUSINS_DEAD_01` | round cleared | ...Sprocket, don't make a joke. Not this time. |
| `SPR_COUSINS_DEAD_01` | round cleared (after Bolt's) | [quietly] No joke. Filing it under lullabies. |
| `BLT_KINDERHAMMER_01` | picks up the Kinderhammer | ...Oh, that's mine. Kind of. |
| `BLT_PAUL_01` | first sight | Okay, he's huge, he's angry, and I think he's on our side? Somewhere in there? |
| `SPR_PAUL_01` | his first bottle breaks | His vitals are mostly stout, Bolt. That is not a figure of speech. |
| `BLT_PAUL_DEAD_01` | after the fall | He was looking for his friends the whole time. ...Sprocket, we're telling everybody about this guy. |
| `BLT_PAUL_CUP_01` | Bolt receives the cup | I'll put it on the shelf in the garage. Front and center. Nobody touches it. |
| `BLT_SLENDER_01` | first sight | Tall guy, lantern, keys, just WATCHING? Sprocket, is that a security guard? That's a security guard. |
| `SPR_SLENDER_01` | Bolt at MEDIUM | He's logging us, Bolt. I've been logged before. I did not enjoy the terms. |
| `BLT_QUARANTINE_01` | returned | There was a clock, and a desk, and a guy, and I had to tear out a PAGE, Sprocket— |
| `BLT_SLENDER_DEAD_01` | his death | Night shift's the worst shift. ...Thanks for watching the place, man. |
| `VEN_COUSINS_01` | the lamps going out | I sat up one night by that stove. I never heard anyone under the floor. I should have listened better. |
| `VEN_ALIX_01` | Alix rises | That arm is not a weapon. It is a hand. Someone should take it. ...Not you. Please, not you. |
| `VEN_COUSINS_DEAD_01` | round cleared | "Retained." That is the word they would use. I have a better one: waiting. |
| `VEN_KINDERHAMMER_01` | picks it up | A splitting maul from the woodpile. Well kept. She kept it well. |
| `VEN_PAUL_01` | first sight | That rack. Those are my bottles. Those are MY bottles in his back. |
| `VEN_PAUL_DEAD_01` | after the fall | Ironhide was made so the boys would not go first. He went first for all of them. ...I am so sorry, Private. |
| `VEN_PAUL_CUP_01` | Vendelin receives the cup | [very carefully] I will not refill it. I will keep it exactly as he left it. |
| `VEN_SLENDER_01` | first sight | A watchman who never sleeps and writes everything down. They would have offered him a position. |
| `VEN_QUARANTINE_01` | returned | A room where it is always three in the morning. I have worked in that room. |
| `VEN_SLENDER_DEAD_01` | his death | He kept watch because he wanted to, not because anyone made him. That is the difference, and it is everything. |

**Counts:** Operator 21; the Cousins 35; Paul 22; the Slender 20; the squad 66; Bolt, Sprocket and Vendelin 25. **189 lines.** The Watch-Book templates are Archive text, not VO.

---

## 9. The Cousins' rhyme: "Drei Kusinen" (original; mirrors docs/JINGLES.md §13)

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

---

## 10. Music and stings (also docs/JINGLES.md §13.2)
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

---

## 11. Data and engineering plan (for the build; nothing created yet beyond the Likeness Sheet)

**Data** (`data/gravelight/bosses/`, JSON per §13 D1):

| File | Contents |
|---|---|
| `likeness.json` | **Created in this pass.** The sheet (§2). |
| `cousins.json` | HP, speeds, enrage step (+20%), the move table (telegraph id, pose clip, sound, light, active, damage, cooldown, counter, grab-break numbers), weak points, the round's horde 40%, fail-safe 360 s, the return round, rewards, the arrival timings, the lamp groups |
| `paul.json` | HP, return scaling 0.35, the rage table (sources, decay, bottles 6 × 400, −20), stage thresholds and hysteresis, sizes, speeds, moves, weak points, stagger threshold 3%, the horde 60%, retreat 360 s, return 8–10, rewards |
| `slender.json` | HP, walk, teleport 15 m / 4 s, the LOGGED tiers and every fill and drain rate, quarantine (25 / 35 s, release 5 hits, immunity 10 s), the light sources (radii, flare 12 m / 20 s), weak points (lantern 3%, stun 6 s; book 2%, 4 s, 30 s), phases (50% / 20%, decoys, End of Shift 30 s, generator hold 5 s), the horde 50%, retreat 480 s, rewards, the Watch-Book templates |

**Code** (proposed paths, following `gravelight/enemies/`):

| Piece | File | Reuses |
|---|---|---|
| Boss base | `enemies/homage/homage_boss.gd` | MZ `Zombie`, the `ZombieRig` / clips / ragdoll / gore, the Foreman's boss spawn and Scrip rules, `RoundManager` scheduling (`next_boss`, `carried_schedule`) |
| Boss rigs and clips | `enemies/homage/homage_rig.gd`, `homage_clips.gd` | `zombie_rig.gd` (appended bones), `zombie_clips.gd` (shared clips, the baking pipeline) |
| Components | `enemies/components/observed_freeze.gd`, `anim_jitter.gd` | the player cameras, `Physics` rays |
| The Cousins | `enemies/homage/cousin_hammer.gd`, `cousin_reach.gd`, `cousin_alix.gd`, `cousins_round.gd` (the round director: lamps, arrival, enrage chain, stems, fail-safe) | `ClimbLink` (rafters), Map 0's light groups, the BuyDoor's open, the window barricades |
| PAUL | `enemies/homage/paul.gd` | the ore-cart trap's carts and rails, the lift shaft, the PA channel, `Effects` shockwave |
| THE SLENDER | `enemies/homage/slender.gd`, `world/watch_room.gd` (+ `watch_room.tscn`), `player/logged_meter.gd` | Morgenrot's `SkyClock`, the floodlight masts, the truck, Die Lange Nacht's freeze, the Leuchtpistole |
| Map 0 additions | `gen_map00.gd`: the bar trapdoor, the ice cellar room, the window handprint decal, rafter lines | the generator's layering |
| HUD | `ui/boss_card.gd` (title card), `ui/boss_bar.gd` (the three bar styles) | the round stamp's font and thunk |
| Rewards | `world/kinderhammer_pickup.gd`, `world/pauls_last_round.gd`, the Overwatch outline on the MZ shader, Archive and profile entries | `PowerUp` drops, `ProfileSave` (calling cards; charms as a new key) |
| Settings | `GLSettings "homage_bosses"`, `"homage_names"`; Settings → Gameplay rows | `menu_settings.gd` |
| Dev console | the §3.9 commands | `dev_console.gd` `register` |
| VO | VO_SCRIPT §12 → `lines.json` + `gen_vo.py` (header switch per block) | T-035 |

---

## 12. Tests and acceptance

**GUT** (`gravelight/tests/unit/test_homage_bosses.gd`, v3 §5):
- **HP scaling:** by player count (1–4) for all five bosses, and Paul's return steps.
- **The Cousins' enrage chain:** the speed stacks per death, each one's new move unlocking, Alix's arrival triggers (50%, a death, 3:00), her hold-hand window.
- **The fail-safe:** retreat at 360 s, the return on round 15 at full HP, the beacon's round shifting to 11 in the campaign, the special round moving.
- **Paul's rage:** the thresholds, the hysteresis, every fill source, the bottles' −20, the stagger window, the retreat and return, and no Foreman on his round.
- **The LOGGED meter:** each fill and drain source, the tier crossings, the lit rule (no damage in the dark, damage in each light source, Die Lange Nacht's freeze).
- **Quarantine:** escape (page torn), fail (downed on return), co-op release by lantern hits, the solo 35 s, one player at a time, bots capped.
- **Reward grants:** the drops, Scrip per player, calling cards, charm unlock keys, Archive unlocks (the letter only on a clear), the Kinderhammer pickup, Paul's Last Round (free Ironhide / +100 overshield), Overwatch.
- **The Homage toggle:** Off = no spawn and a normal round. **Names:** Real / In-World on the card, the bar, subtitles and the named-line twins.
- **The Likeness Sheet:** placeholders resolve to their defaults, and nothing shows "[".

**Smoke tools** (headless, silent, off-screen): `smoke_hb1` (Map 0: rounds 9→10, the arrival sequence, each cousin killed by the debug path, the clear, the ice cellar, the drawing, plus a 6:00 boredom run), `smoke_hb2` (Map 1: round 15, the leap, the stages by `set_rage`, the bottles, the lift-shaft follow, the death sequence), `smoke_hb3` (Morgenrot, with M8.5). `shots_hb*` render the title cards and each boss's key poses.

**Acceptance for each milestone (v3 §6):**
- Devin can force-spawn the boss from the dev console and beat it **in solo and in co-op**.
- **Every listed animation is in**, and all telegraphs read clearly.
- Rewards grant correctly, and the Homage toggle works.
- **A short capture of the full fight** goes in the milestone summary.

---

## 13. Decisions taken where the prompt didn't fit the repo (proposed; also DECISIONS T-042)

| # | v3 said | This repo | Proposal |
|---|---|---|---|
| **D1** | Tuning in `/data/gravelight/bosses/*.tres` | Every GRAVELIGHT tuning table is JSON under `data/gravelight/` (`Data` loads `*.json`; no `.tres` tuning exists, despite old doc mentions) | **JSON:** `data/gravelight/bosses/{likeness,cousins,paul,slender}.json`, with the loader added in HB1. Only `likeness.json` exists now. |
| **D2** | `docs/HOMAGE_BOSSES.md`, `docs/JINGLES.md`, `docs/VO_SCRIPT.md`, `LORE.md`, `ENEMIES.md` | GRAVELIGHT system docs live in `docs/gravelight/`; the canon jingle file is `docs/JINGLES.md` (the `docs/gravelight/JINGLES.md` copy is marked superseded) | This doc and the rhyme go where v3 says (`docs/`). VO, Lore, Enemies and Weapons go to their real homes in `docs/gravelight/`. |
| **D3** | VO "with line IDs" in VO_SCRIPT | `extract_vo.py` turns every `ID`-headed table into live `lines.json` entries | The lines are written in full but **headed `Line id`, so they are not extracted** until each milestone (the v2 §11 reservation pattern). Ids follow `{SPK}_{CAT}_{NN}`; six new speakers. |
| **D4** | Paul: captured in the Ardennes; `PAUL_UNIT` default "82nd Airborne attached engineer" | Kaltenbrunn fell on 20 Dec 1944 (the Erwachen). Paul's dose series has to happen before that. The 82nd Airborne was in Holland until November and only entered the Ardennes on 18–19 Dec 1944. | **Needs Devin's call.** The canon text says "captured in the Ardennes in the autumn of 1944" with `%PAUL_UNIT%` and no date. Options: **(a)** keep the 82nd and move the capture to Holland, Sept 1944; **(b)** keep the Ardennes and make him an engineer of a unit holding the quiet Ardennes line in Oct–Nov 1944 (generic, no real battalion named); **(c)** Devin sends `PAUL_UNIT`. The sheet keeps the 82nd as the default meanwhile. |
| **D5** | Paul returns every 8–10 rounds, stronger; and he has the most heroic death | A death followed by a return would undo the death | **He returns until he is beaten:** if he isn't killed within 6:00 he leaves and comes back stronger; once killed, the twist plays and he's gone for the match. |
| **D6** | The Cousins have a 6:00 fail-safe; Paul and the Slender have none | A boss you can't finish stalls the round forever | Paul and the Slender get the same shape (6:00 / 8:00, return later). Proposed: the Cousins keep returning every 5 rounds after 15 if bored again. |
| **D7** | "PAUL'S LAST ROUND (unique drop)" | Co-op: one bottle would go to one player | **One per player**, each personal. |
| **D8** | Every player has a LOGGED meter | Bots can't read a room and tear a page | Bots' meters cap at HIGH (they get the effects but never get quarantined). |
| **D9** | "Three Ribbons" and "Violet Lantern" weapon charms | No charm system exists (profile has calling cards, emblems, cap styles, menu themes) | The milestones record the unlocks in `ProfileSave`; the charm renders when a charm slot exists (M9 meta). |
| **D10** | The inn "belonged to their aunt, the innkeeper" | Canon: kept by Anselm Vogt and his wife, daughter Käthe, fates [OPEN] | The aunt is **Helene "Lene" Vogt**, the innkeeper's wife; the inn was her family's. The Cousins hide in an **old ice cellar under the bar** (not the Helvetia vault). Lene went up for Käthe; Käthe's and Anselm's fates **stay [OPEN]**. |
| **D11** | Alix moves only while unobserved | A fully frozen-when-seen boss would be a free target | ObservedFreeze applies **beyond 8 m**; within 8 m she walks and fights normally (slowly). |
| **D12** | The Slender is damaged only in the Kessel floodlights, the truck, flares or close muzzle flash; he spawns on round 20 | The floodlights need power; the egg has its own climax | He needs power on (he arrives on the first round ≥ 20 after power-on), never during the Heartstorm or Reinholt, and never on a Startmeister or LUFTALARM round. |
| **D13** | Homage Names shows real or in-world names on title cards | Real names would also show on bars, subtitles and the Archive | In-World hides real names everywhere on screen; named lines have unnamed twins. |

---

## 14. Placeholders still to fill (send any of these and the sheet updates)

1. **`[COUSIN_1_NAME]`**: the Hammer's real name (default "Mara").
2. **`[COUSIN_2_NAME]`**: the Reach's real name (default "Jo").
3. **`[PAUL_SIGNATURE]`**: a catchphrase, team, item or tattoo for Paul.
4. **`[PAUL_LASTNAME]`**: Paul's surname (POW card, Archive, Peg's line).
5. **`[PAUL_UNIT]`**: his unit (default "82nd Airborne attached engineer"; see D4, it clashes with the Ardennes timeline).
6. **`[PAUL_LETTER_DETAILS]`**: what his letter to his unit talks about (default: a ball game back home and the first round).
7. **`[DEVIN_SIGNATURE]`**: Devin's look details: hair, height, glasses, beard, style.
8. **`[DEVIN_LASTNAME]`**: Devin's surname (the watch-book's flyleaf, the Archive).

Optional, any time: a different look or default for any row of the sheet, the cousins' ages if they should differ from about 22 / 18 / 20, and consent notes plus reference photos in `assets/user_supplied/likeness/` if real likeness references should ever be used.

---

## HB1 build notes (The Cousins, built 2026-10-22, overnight run)

**What's in (playable, tested):**
- **Data:** `data/gravelight/bosses/cousins.json` (HP, speeds, every move's telegraph / damage / cooldown / break numbers, the round rules, arrival points, lamp groups, rewards, the Cousins' subtitle lines). Loaded through `GLData` (`table("bosses/cousins")`, `table("bosses/likeness")`). Four player statuses added to `enemies.json` (`boss_grab`, `held_hand`, `splinters`, `reach_slow`).
- **Framework:**
  - `gravelight/enemies/homage/homage_boss.gd` (`HomageBoss`): HP scaling, boss limb multipliers (the weapon's own default divided back out), state multipliers, Death's Door doubles the damage while Blackout takes 25%, the move clock and enrage steps, the shared grab + break-free helper, authored deaths, retreat.
  - `homage_pose_mod.gd`: a post-animation SkeletonModifier3D that adds extra rotation / translation / scale per bone, plus a whole-skeleton hold.
  - `homage_arm.gd`: the stretchable arm segment with its weak-point hitbox (the Reach's telescoping forearms, her through-the-floor arm, Alix's Third Hand).
  - `gravelight/enemies/components/observed_freeze.gd`: reusable. It checks every living player's camera frustum (widened 5 deg) plus line of sight, at 20 Hz with 0.1 s hysteresis.
  - `gravelight/ui/boss_hud.gd`: the red ledger-stamp title card with its date line, the three stacked boss bars, and the pencil strike through a dead cousin's bar.
- **The round:** `cousins_round.gd` (`CousinsRound`), created by the ZombieDirector on Map 0, runs on the host / in solo.
  - **Setup** at the end of round 9: the 17 lamps gutter out (taproom, then upstairs, then stable), the fire dies to embers, a violet handprint smears the north-west window, then clapping upstairs. A skip straight to round 10 compresses this into about 2 s.
  - **Arrival:** the horde runs at 40%.
    - The Hammer first: her title card, her maul tumbling down the stairwell, and Door 1 split open for free.
    - The Reach at 0:30: her arms come through two taproom windows first. She comes from the hayloft if the stable door is open, else through the east window.
    - Alix out of a runtime trapdoor behind the bar, when a cousin is under 50%, a cousin dies, or 3:00 at the latest.
  - **Each death:** her bar is struck, one lamp group relights, the survivors get +20% move and attack speed (stacking), and Alix goes to hold the body's hand. The three hold the round open as reserved "alive" slots.
  - **Clear:** Death's Door + Resupply at the last body and 1500 Scrip each. `card_the_game_is_over`, `charm_three_ribbons` and `ARC_HB_COUSINS` are recorded in ProfileSave, and `INT_HB_01` is filed through `intel_found`.
  - **Fail-safe at 6:00:** they leave with no rewards and return on round 15 at full HP, then every 5 rounds.
- **The Hammer:**
  - Moves: the swipe; the Mallet Throw; the Ricochet when enraged (real wall banks, 2 bounces); the Overhead Split with its splinter zone; the unarmed slap.
  - The Mallet Throw's telegraph: the hum stops, a wind-up spin, the maul head flares. Then:
    - the maul boomerangs out and back, homing at up to 90 deg/s, and hits on both passes; crouching or sliding ducks it;
    - she catches it blind, then freezes for 0.3 s.
  - While the maul flies she takes x1.5, and a melee hit staggers her and drops the maul (a 1 s stoop to pick it up).
  - Creepy layers: the head locked on with a 175 deg limit, a hitch on every third step.
  - Death: she sits, then topples over stiffly like a doll.
  - Costume: the braid, the coat buttoned to the throat, a long skirt, red-grey mittens, the maul prop.
- **The Reach:**
  - Moves: the swipe; Both Hands when enraged.
    - **Long Reach Grab:** 12 m, drags at 2.5 m/s, then the Hug-Crush (120 over 1.5 s). It breaks on the wrist (x2) taking 8% of her HP, 6 melee presses, 250 team damage, or 6 s.
    - **Through-the-Wall:** 0.6 s of dust and creaking at the player's spot, then an arm up through the floor for 60 + a slow.
  - Costume: a bob with bangs, a high-collared ankle-length nightgown, a buttoned cardigan. Her arms are long even at rest: the forearm and hand bones are translated and the stretched skin is filled in.
  - Death: both arms reach toward the nearest cousin, then drop. She drops Fortify + 500 Scrip each.
- **Alix:**
  - Every hit does 2x; her swipe is 100.
  - **Holding Hand:** 2 m, 30 / s, dragging the player toward the trapdoor, with the held_hand screen FX. It breaks on 3 melee hits, 300 team damage, or 6 s.
  - **Lash:** both hands to her ears for 0.9 s, then the third arm whips a 5 m arc at chest height; crouch or slide under it. It becomes Double Lash after grieving.
  - **ObservedFreeze** beyond 8 m: frozen while seen, 6 m/s while unseen.
  - **The grief window:** a 3 s kneel holding the fallen cousin's hand, taking x2 damage; it ends early at 20% of her HP. She rises with the violet drip light.
  - Costume: two buns, a navy Sunday dress, a white collar, a red ribbon bow over the third arm's root, dark stockings.
  - Death: the third arm reaches up and closes into a fist.
- **Settings:** `homage_bosses` (On / Off) and `homage_names` (Real / In-World) in Settings -> Gameplay. In-World hides real names on the card, the bar and the subtitles, and swaps named lines for their unnamed twins.
- **Campaign:** with Homage Bosses On, Map 0's beacon opens on round 11 (retries on 14, 17 ...); Off leaves it unchanged. A Bellringer round or a Foreman that would land on a Cousins round moves to the next round (`RoundManager.reserve_round`).
- **Dev:**
  - Console:
    - `spawn_boss cousins|hammer|reach|alix`;
    - `cousins [status|kill <who|all>|bored]`;
    - `homage on|off` and `homage_names real|world`;
    - `boss <...>` unchanged, and it accepts the cousin ids too.
  - Dev launcher: "Boss test — The Cousins (Crossroads Inn, round 10)".
  - Capture: `tools/capture.sh <milestone> cousins` (the trio, the third hand, the title card, the bars).
- **Tests:** `gravelight/tests/unit/test_homage_cousins.gd` (21 tests) and `gravelight/tools_src/smoke_cousins.tscn` (cases ON, BORED and OFF).

**Stubbed / not built (HB1 scope cuts):**
- **Moves and extras:**
  - the Reach's ceiling crawl, Window Spider, and arm sever with its 20 s regrowth;
  - the Hammer's head-lock grab and the Kinderhammer drop;
  - the after-round ice-cellar room, its chalk figures and the free crate pull;
  - the "Cousins Are Still Playing" chalk collectibles.
- **Audio:**
  - No baked VO for the HAM / RCH / ALX / CSN / OPR_BOSS_COUSINS lines (VO_SCRIPT section 12 is still headed `Line id`), so every line falls back silently to its subtitle.
  - The rhyme stems, the toy-piano bed and the title-card sting are not composed. The hum is the Screamer's lullaby sample, pitched per cousin; the clapping is pitched knife hits.
- **Animation:** no new baked clips (`homage_clips.gd`) and no extra bones. The shapes are the shared MZ clips plus the pose layer; the third arm and the long reach are mesh segments, not bone chains. AnimJitter covers only the Hammer's hitch.
- **Co-op:** the host runs everything. A client sees each cousin as the generic puppet body, with no title card, bars or boss subtitles. Remote players are held by grabs but not dragged.
- **Small gaps:**
  - Fasbender's round-10 radio line still plays at round 10's start, not its end.
  - The lamp meshes keep glowing while their lights are out.
  - The Archive card for `INT_HB_01` won't show in the Archive until LORE section 13.3 is extracted into `intel.json`; the id is already filed in the profile.

**Decisions taken in the build:**
- **The trapdoor:** Alix's trapdoor is behind the bar (the canon ice cellar, section 4.1). It is a runtime node; `map00.tscn` was not regenerated.
- **Bots observe:** bots count as ObservedFreeze observers, as section 3.3 says. `observers_include_bots` in the JSON turns it off.
- **Limb multipliers:** for hitscan hits the boss's limb multipliers replace the weapon's defaults (a head shot: weapon x4 becomes boss x2). Melee, explosive and wonder hits use the boss table only for the weak points.
- **Instant kills:** Blackout and the console's `kill_all` take 25% of a boss's max HP instead of killing it; `cousins kill` kills.
- **Break damage:** teammates' damage counts in full on the grabbing limb or weak point and at half elsewhere, so bot fire (which aims at bodies) still frees a held player.
- **The held hand's effect:** Holding Hand's "vignette + audio drop" is the existing status FX (screen distortion + SFX low-pass), through the `held_hand` status.
- **Bodies and costumes:** the cousins use the female villager MZ body (thin build) with costume shells on bone attachments; the skirts and coats are sized to cover the base body. Faces are the shared stylized zombie face, paled.
- **Late arrivals:** a cousin who arrives after a death comes in with the current enrage steps. Alix gets Double Lash only from a grief window.
- **The bodies:** they stay until 12 s after the round ends, so the deaths play out and Alix can reach a fallen cousin, then they go.
- **smoke_campaign:** it runs with Homage Bosses Off (in memory, on a QA settings path) so it keeps testing the plain round-10 beacon. The shift to round 11 is unit-tested.
