# UPDATE 11 — "LAZARUS": A GRITTIER ORIGIN ROOTED IN HISTORY AND FAITH, NEW CUTSCENES, A HORROR PASS, AND ELEVENLABS FOR EVERY VOICE

A work order for the `bolt-and-sprocket-ultimate` repo (TERMS & CONDITIONS / CLAUDE ZOMBIES, Godot 4). All earlier rules still apply:
- data-driven tuning, tests, smokes, a branch per section, `master` always launches;
- the `PROGRESS.md` resume line; `docs/DECISIONS.md` for every call;
- licensed assets only;
- the respect rules: no real Nazi symbols; forced laborers are never zombies; civilians shown with care.

**Runs fully unattended. Never pause, never ask me questions, never wait for approval.** Make every call yourself, log it, fix what you find, and keep going. Merge each section into `master` when its tests and smokes pass. If a step needs my account or key, do everything up to that point, put the one-line step in `morning/NEEDS_DEVIN.md`, and move on. If a usage limit cuts the session, checkpoint `PROGRESS.md` so rerunning this prompt resumes instantly.

## 0. DO NOT STOP
I'm away until this is finished. **Do not end your turn, summarize, or wait for me** until every section is done, merged and pushed.
- **When a section finishes:** start the next one.
- **When something fails:** fix it or route around it, and log it.
- **When an item is blocked:** stub it, note it, and move on.
- **Your only stopping point** is §10 FINISH.

## ORDER
1. Read `PROGRESS.md`, `docs/CANON.md`, `docs/gravelight/LORE.md`, `docs/TIMELINE.md`, `docs/FINEPRINT_LORE.md`, `docs/MAP3_MORGENROT.md`, `docs/MAP4_FERNFLUG.md`, `docs/U10_TOTENHAFEN_DESIGN.md` and the cinema library from T-184.
2. If the owner's current list (T-179 onward) has workers still running, let them finish and merge first, then start this update.

---

## HOW TO RUN THIS: the agent team
You (the main session, **Fable 5.1, effort High**) are the **lead**. **This update is mostly writing, so the story work is yours or a Fable worker's.** Workers each get their own worktree and branch (`u11-<sec>-<slug>`), at most ~4 at a time.

| Task | Model | Effort |
|---|---|---|
| §1–§3 The new canon, the timeline, every doc rewrite, the Archive texts | **Fable** (you) | High |
| §4 Rewriting every VO line for the new story and tone (one worker per map plus one for The Fine Print / B&S cross-references) | **Fable** | High |
| §5 The four new cutscenes: staging, cameras, the sets they need | **Opus** builds; **Fable** writes the shot lists | High |
| §6 Horror pass: enemies (the Soviet risen), visuals, audio, the bleed-out rule | **Opus** | High |
| §7 ElevenLabs pipeline, casting, the bake | **Opus** for the pipeline; **Sonnet** for casting data and the batch runs | Medium |
| §8 The respect review (a separate reviewer that has NOT written any of it) | **Fable** | High |
| The Easter egg guard test, Archive wiring, credits, test and smoke upkeep | **Haiku** | Low |

Review every branch yourself before merging, and play-read every rewritten scene in order once before FINISH.

---

## 1. THE NEW CANON

The zombies no longer come from an alien company. **They come from an ancient sickness kept for centuries in a reliquary: the blood of Lazarus.** The Bolsheviks woke it, the Soviets hid it, the Soviets used it, and the Germans stole it and made it airborne.

**Darkmatter, Vendelin and the Bolt & Sprocket crossover stay, with a smaller job.** They explain **only the technology**: the perk machines, the Crucible (Pack-a-Punch), the Ledger and Scrip, the Operator, the mystery crate and the Nachtglas crystal. Darkmatter didn't make the dead. **It found them, and it came to sell to them.**

Refine everything below, but keep these beats.

### 1.1 The relic
- **Lazarus of Bethany** was four days dead when he was called out of the tomb (John 11).
- **Orthodox tradition** calls him **Lazarus the Four-Days-Dead**. His relics went from Kition on Cyprus to Constantinople in the year 890.
- **This story's invention** (fictional, and never presented as real history or real Church teaching):
  - A small sealed vessel went with those relics, kept apart from them. The monks who guarded it wrote that it held **"what death left behind when it gave him back"**: the debt death was owed and never collected.
  - When Constantinople fell in 1453, monks carried the vessel north to Rus. For almost five hundred years it sat sealed in the crypt of a fictional village church, **the Church of St Lazarus the Four-Days-Dead** in the village of **Chetverodnevo**.
  - A brotherhood of watchers kept a lamp lit over the crypt day and night. Their rule was one line, cut over the crypt door in Church Slavonic: **"What was closed on the fourth day, let no one open."**
- **The faith is never the villain.** The miracle is never depicted as fake or evil. The monks, and the village priest in 1930, are the most decent people in the saga. **The horror is entirely what men did when they broke the seal.**

### 1.2 Lazarus Saturday, 1930 (the awakening)
- **Real history to ground it:** the Soviet anti-religious campaigns. The League of Militant Godless, church bells melted down, churches dynamited or turned into warehouses (the Cathedral of Christ the Saviour in Moscow was blown up in December 1931). Research it and get the period right.
- **Our fictional event:** on **Lazarus Saturday, April 1930** (the day before Orthodox Palm Sunday; check the date), a district brigade arrives to close the church. The village priest, **Father Serafim Lebedev**, refuses to give up the keys.
  - They take the bell down, dynamite the bell tower, and break into the crypt looking for church silver to requisition.
  - A young OGPU officer, **Arkady Volkov**, opens the vessel on the altar step to prove there's nothing in it.
  - The blood inside is still wet.
- **The sickness keeps its own calendar: the dead rise on the fourth day.**
  - Three of the brigade fall ill. They die in the fever ward at the district town.
  - **On the fourth day they get up.**
  - So does everyone they bit, and so does the village, because Father Serafim had buried the brigade's first victims himself.
- **The cover-up:**
  - The OGPU seals the district and records it as a typhus quarantine.
  - What happened inside the cordon is never written down.
  - **Chetverodnevo is erased from the map.**
  - Volkov survives, because he was never bitten. He carries the vessel to Moscow in a lead case.

### 1.3 Laboratory No. 4 (the Soviets hide it)
- **The program:** the vessel becomes a secret NKVD program, **Laboratory No. 4**, codename **"FOURTH DAY" (ЧЕТВЁРТЫЙ ДЕНЬ)**, run by Volkov, who rises through the 1930s purges by being useful.
- **The work:**
  - They culture the sickness ("Lazar" in their files) and learn that it lives in blood.
  - They learn that the dead rise on the fourth day, and that the risen spread it by bite.
  - They learn that **you can't make it obey.**
- **Its victims:** prisoners from the camps are the test subjects. Handle that with weight, never as spectacle: documents, empty bunks, a list of names.
- **The rule:** it stays in the vault, an order of last resort.

### 1.4 How Darkmatter fits (the technology, not the dead)
- **The awakening is visible across the galaxy.** On Sol-3, something that refuses to stay dead has woken up: a "natural retention phenomenon." For Darkmatter, that's the most valuable thing a market can have. **This is why Darkmatter comes to Earth at all.**
- **The 1938 probe and the crystal:**
  - Their test-market probe, TM-SOL3-001, lands in the Kaltenbrunn salt mine in November 1938 (unchanged).
  - Its crystal, **Nachtglas**, doesn't make the dead rise. What it does is answer the sickness: anywhere near it, the sickness wakes faster and runs further.
  - Darkmatter shipped a culture of the sickness along with the crystal: "returned inventory," acquired from Laboratory No. 4 through a fold and backdated (CANON §2's Next-Era Delivery).
  - **That's why Jan Pilch rose in the mine in 1938 (unchanged), on the fourth day**, and why Vendelin saw it (Fine Print Ch. 2, kept).
- **Everything else stays as built:** Vendelin, the perk cabinets and the formulas behind them, the Crucible as Blartz's forge, the Operator, the Ledger, the crate, Sable Vantage, and the relay on the Moon. **It's all the technology layer.** The Fine Print keeps its chapters. Only the lines that say Darkmatter *created* the dead change: Darkmatter now *found* the sickness, *packaged* it with its crystal, and *sells* to it.

### 1.5 Kaltenbrunn and Reinholt
- **Projekt Wiederkehr (1939 onward) studies the crystal and the miners it raised.** Dr. Augusta Reinholt wants her daughter Liesl back.
- **Lazarus is now the name her grief hangs on:** a man four days dead who came home. Her program's German name for the sickness is **Lazarusblut**.
- **The perks, the Ledger and the Crucible come in through Helvetia Automaten AG,** as built.

### 1.6 The Soviets unleash it (October 1944)
- **Real history:** the Red Army first crossed onto German soil in **East Prussia in October 1944** (the Gumbinnen–Goldap operation).
- **Our alternate history:** when that attack stalls, Moscow sends Volkov and the last-resort order.
  - **FOURTH DAY is released by shell and by infected volunteers' blood** on the German lines.
- **It works:**
  - The German line breaks.
  - Then, four days later, **the Red Army's own dead start getting up**: thousands of them, from field graves, aid stations and the snow.
  - They don't know whose side they were on. They walk west.
- **The cover-up again:** Moscow buries it. Front reports call it "an epidemic among the enemy."
- **The war on the first map:**
  - **The distant war you see from the Crossroads Inn** (the guns on the eastern horizon, the flares, the burning town) **is the front where the Soviet dead are walking.**
  - The Red Army is fighting both the Germans and its own risen.
  - In this alternate history the front has come further west than it did in real life, because the line broke.

### 1.7 The Germans make it airborne
- **The Germans are quick.** They recover infected Soviet dead, and the bodies go to the one place in the Reich that already understands what rises: **Kaltenbrunn**.
- **What Reinholt's lab finds:**
  - Near Nachtglas the sickness no longer waits four days. **It takes minutes.**
  - Ground fine with the crystal into a violet dust, **it carries on the air.**
  - The program calls this **STAUB** ("dust"), and the plan is to send it back east.
- **The Marke becomes part of this** (it's kept from U09 and given a new reason):
  - Abteilung III sells the troops a chip under the skin of the right hand or the forehead, **"die Marke, die dich hält"**, as **protection against the Lazarus sickness**.
  - It isn't protection. It's a Nachtglas tag that makes the marked **rise on command and walk where the relay points them**.
  - Deacon still knows it from Revelation 13. Everything in CANON §2.2 stays, except that it now ties into the sickness.
- **20 December 1944, the Erwachen (the "Awakening"):** it was **the first STAUB release**, aimed at the Soviet front.
  - The wind turned and blew the dust back over Kaltenbrunn, the villages and the road garrison.
  - That same night, Reinholt drove the Heart to full resonance to reach Liesl.
  - **Both things are true at once (this fits the existing canon):** every body for 30 km rose, Soviet and German alike.
- **Three nights later**, the violet light from that same Heart brings down GRAVELIGHT ONE (unchanged).

### 1.8 How the escalation runs through the maps you already have
- **Map 0 Crossroads Inn (Dec 1944):**
  - **The crash:** the squad's plane crosses a front where the dead walk west under flares, then the violet column kills its engines.
  - **The dead at the inn are now a mix:** villagers, the marked German road garrison, and **Soviet risen in greatcoats coming out of the east**.
  - **Fasbender's radio:** he says what Kaltenbrunn did, and now also **what the Russians did first**.
- **Map 1 Kaltenbrunn:** the STAUB plant, the vats and the dust mills, Reinholt's records, Liesl. As built, plus the new layer.
- **Totenhafen:** the lead coffins hold **Lazarusblut and STAUB** shipped out of the Reich to the highest bidder, consigned to "Hale, L." Captain Lenz's refusal reads even harder now. **Letzte Fahrt sinks it.**
- **Helvetia Works** (designed): unchanged. It's the technology crossover.
- **Morgenrot** (designed): the dawn salvo carries STAUB to London, Antwerp and Paris. **Keep the cities and the egg as designed.** The regime aimed it east first (the Erwachen); now that it's losing, it aims at everyone.
- **Fernflug:** the Kranich's bombs carry STAUB across the Atlantic. At Groom Lake the Allies have their own program, built on samples Peg's orders bought, and the relay on the Moon is what **keeps the sickness awake worldwide and the marked obedient**. Cancelling it makes the dead lie down, as built.
- **A new epilogue card after the Fernflug canon ending**, set **Moscow, 1953**:
  - A lead case in a vault under Laboratory No. 4.
  - An old man's hand (Volkov's) resting on it.
  - **The vessel is still there, and it is still wet.**
  - Write it as dread, not as a sequel advert.

### 1.9 The people
**Father Serafim Lebedev**, the 1930 priest:
- His **diary** is the thread through the whole game: **one Archive page per map**, in order, written before and during the awakening. The last page is found on the Moon. Decide how; the Fernflug relay holds artifacts from every market.
- **He's never a zombie on screen.** His fate is left to a single diary line.

**Arkady Volkov:** the man who opened the vessel and ran FOURTH DAY.
- **He's never a cartoon.** He's frightened, clever and ambitious, and he keeps the vessel because it keeps him alive.
- He's present in the documents on every map, and in the October 1944 cutscene.

**The squad**, with their existing secrets and arcs kept:
- **Deacon** (preacher's son): the saga's quiet theological voice. Lazarus, the Mark, "the last enemy that shall be destroyed is death." **No sermons**, a line at a time.
- **Wren** (Home Army): knows the NKVD. Her brother's story is unchanged.
- **Dutch:** his grandmother's letter is about the glass in the salt, as now.
- **Peg:** Hale's orders now say *retrieve samples of the sickness and the crystal*.
- **Jakub:** unchanged.

### 1.10 Names (in German, Russian and Church Slavonic; check every one)
| Name | What it means |
|---|---|
| Lazarusblut | the Germans' name for the sickness |
| STAUB | the airborne program ("dust") |
| ЧЕТВЁРТЫЙ ДЕНЬ / FOURTH DAY | the Soviet program |
| "Lazar" | the Soviet files' name for the sickness |
| Gänger (from Wiedergänger, "one who walks again") | stays as the German word for the risen |
| "the Returned" (вернувшиеся) | what the Red Army calls its own risen |

**No real person is a villain or a victim by name.** Real history is the backdrop only: the anti-religious campaigns, East Prussia 1944.

---

## 2. WHAT MUST NOT CHANGE
1. **The Easter eggs are frozen.**
   - Every main and side egg on every map keeps its step graph, its items, puzzles, codes, melodies, bells, radios and rewards.
   - Its quest JSON (`data/gravelight/quests/*.json`), its `bot_task` data and its smokes stay as they are.
   - Egg VO may be re-voiced and re-toned, but each line keeps **the same ID, the same cue and every piece of gameplay information** it carries.
   - **Write a guard test** that hashes every quest file's step and reward structure before your first change and fails if any of it differs at FINISH.
2. **The maps, systems and balance** are untouched by this update, except the new enemy skins and the bleed-out rule (§6).
3. **The Fernflug "CANCEL" ending and its mechanics stay.** Only its meaning is re-explained.
4. **The Darkmatter/Bolt & Sprocket technology layer stays** (§1.4).

## 3. THE DOCS (the new canon goes in writing first)
- **Rewrite** `docs/CANON.md` (a new §0 "The Lazarus origin" ahead of everything, and every section that says Darkmatter made the dead), `docs/gravelight/LORE.md`, `docs/TIMELINE.md`, `docs/gravelight/CHARACTERS.md` (stakes and quotes), `docs/FINEPRINT_LORE.md` (Darkmatter's motive), `docs/MAP3_MORGENROT.md` and `docs/MAP4_FERNFLUG.md` (story sections only) and `docs/U10_TOTENHAFEN_DESIGN.md` (story section only).
- **`docs/STORY_CHANGES.md`:** a full entry on what changed and why.
- **`docs/LAZARUS.md`:** the new bible for this layer, covering the relic, 1930, Laboratory No. 4, October 1944, STAUB and the Marke, with a sources section for the real history used.
- **The Archive:**
  - Father Serafim's diary pages (one per map);
  - the Laboratory No. 4 files;
  - a Soviet front report from October 1944;
  - the STAUB memos at Kaltenbrunn;
  - Hale's sample order.
- **Each Archive entry is a world prop where it makes sense,** using the story-props system, so it doesn't add Easter egg steps.

## 4. GRIT: REWRITE THE VOICE LINES
Read every line in `data/gravelight/vo/lines.json`, the cutscene tables and the story props, and rewrite them for the new canon and a harder tone:
- **The squad:**
  - **Fewer quips:** humor stays, but it's gallows humor from tired, frightened people, and it thins out map by map.
  - **More fear, more grief:** exhaustion, frostbite, prayers said under the breath, the things soldiers actually said.
- **The Operator stays cheerful.** That's the horror. But it now talks about "the returned" and "the fourth day" with a salesman's warmth.
- **Fasbender** is more haunted. He saw the Soviet dead come in on the trains.
- **New speakers:**
  - Father Serafim (Russian, subtitled; he appears in the 1930 cutscene and in the diary read-alouds);
  - Volkov (Russian, subtitled);
  - Soviet radio traffic on Map 0 and Kaltenbrunn (Russian, subtitled);
  - the risen Red Army soldiers' last words, repeated (Russian, subtitled, only from close up).
- **Keep every line ID** where a line is replaced. Add new IDs for new lines. Run the VO extractors and tests.
- Story lines in The Fine Print and Bolt & Sprocket change **only where they say Darkmatter created the dead**. Their comedy stays. That's the contrast.

## 5. THE NEW CUTSCENES (on the T-184 cinema library)
Write a shot list for each in `docs/CUTSCENES_LAZARUS.md`, build the sets each one needs (period-correct, from free assets first), and voice them with ElevenLabs (§7).
1. **"LAZARUS SATURDAY" (the prologue, about 3 minutes)** — Chetverodnevo, April 1930. **It plays before the main menu on first launch**, can be skipped, and is replayable from the Archive.
   - **The village:** mud, thaw and grey light; the villagers kneeling in the road.
   - **The brigade arrives:** a truck, red banners as plain cloth, megaphone slogans (subtitled).
   - **Father Serafim at the door with the keys,** refusing.
   - **The bell:** they rope it down off the tower, and it cracks on the ground.
   - **The tower:** the dynamite and the tower coming down.
   - **The crypt:** the lamp still lit; the line over the crypt door. Volkov breaks the seal on the altar step.
   - **The blood is still wet.** Close on it.
   - **Cut to black. Title card: "The fourth day."**
   - **The fever ward:** a sheet over a face, then the sheet moving.
   - **The cordon:** the OGPU cordon in the snow, the village burning at night, and a typhus sign nailed over the church door.
   - **The lead case** in Volkov's arms on a Moscow train.
   - **Last card:** "Chetverodnevo is not on any map."
2. **"FOURTH DAY" (October 1944, about 90 seconds)** — East Prussia.
   - Rain, mud, a German line.
   - The shells that hit and don't explode properly.
   - Soviet officers watching through binoculars.
   - **Four days later:** a field grave with the earth moving; Red Army soldiers turning to look at it.
   - **The last shot:** a long line of the risen walking west in greatcoats past their own guns.
   - It plays as **the opening of a new campaign start** (before Map 0's crash) and in the Archive.
3. **"STAUB" (Kaltenbrunn, 20 December 1944, about 60 seconds)** — the dust mill.
   - The violet powder; Reinholt watching the gauges.
   - The canisters loaded onto rockets aimed east.
   - The weather report going wrong.
   - The wind vane swinging.
   - The dust coming back over the hills, and the lights of the villages going out one by one.
   - It plays as **Kaltenbrunn's arrival** and in the Archive.
4. **"GRAVELIGHT ONE" (Map 0's crash, rebuilt):**
   - Inside the C-47 over the front at night.
   - Through the window: flares, and **the dead walking west in the snow** below.
   - Selwyn on the intercom.
   - The violet column ahead. The engines die, the crash, the inn's lit windows. Then the existing match start.

**Rules:**
- **Every cutscene is skippable** (hold to skip, as built), works in co-op and online (host-driven), and has subtitles.
- **Gore follows the Gore setting.**
- **The 1930 cutscene shows no violence against clergy or villagers on screen.** It cuts away and lets sound and aftermath carry it.

## 6. HORROR PASS (look, sound and one rule)
- **The Soviet risen**, a new set of skins on the existing zombie rig (no new AI needed). Every one gets the CANON §2.2 Marke glint rule, or not, as the canon says: the Soviet dead were never marked, so **they have no glint**. Instead, their weak point is **the wound that killed them**.
  - **Look:** frost-white skin; greatcoats stiff with ice; the ones from field graves dressed in burial wrappings; boots missing.
  - **Uniforms:** period-correct, with **no caricature and no political imagery used for shock.** These were soldiers, and they're victims of their own command too.
  - **Spawning:** they join the spawn mix on Map 0 and Kaltenbrunn's surface (data-driven weights), and appear in the background war (§1.6) **walking west in the distance** on Map 0's landscape.
- **Visual grit, on every map:**
  - more blood and mud;
  - frost on the screen edges in the cold;
  - flies over the dead in warm zones;
  - breath fog;
  - darker night grading;
  - lamps that gutter.
- **Audio:**
  - a low bed of **public-domain Orthodox chant** fragments (or newly recorded or synthesized chant), distorted, rising with the round number;
  - church bells far off;
  - Russian whispers from the risen up close;
  - the squad's breathing when hurt.
- **Keep the Operator's jingles bright.** The contrast is the point.
- **The fourth-day rule, as a toggle:** "Hard Truth", on by default in Story mode, off in Classic Rules.
  - **When a teammate bleeds out**, their body **rises as a zombie** after 4 seconds (a nod to the fourth day). It must be put down, and that drops their death crate as now.
  - **The respawn rules don't change.**
  - **Bots' bodies** do it too.
  - **Tests:** the toggle, co-op, and online.
- **Main menu:** the live menu scene from T-144 gets the new tone. Add the far-off front's flares on the eastern horizon, the Soviet risen walking past the fence at the treeline, and the chant bed.

## 7. ELEVENLABS FOR EVERY VOICE
**Every voice in the game moves to ElevenLabs:** Claude Zombies, The Fine Print, and Bolt & Sprocket. The pipeline exists (`tools/voice/elevenlabs.py`, `tools/voice.sh elevenlabs`, off by default).

**1. Make it the default bake path.**
- The key comes from `ELEVENLABS_API_KEY` in the environment, **never written to any file, log or commit, and never printed.**
- **If the key isn't set:** do all the prep below, then put the exact setup steps in `NEEDS_DEVIN.md`, and keep going with the rest of the update.

**2. Cast every speaker** in `data/voice/cast.json`. Use ElevenLabs library voices or **Voice Design** voices, and pick by the character docs:
- age, nation, accent and register: Dutch's Pittsburgh, Peg's posh English, Deacon's soft Southern, Wren's Polish-accented English, Russian for Serafim and Volkov, German for the PA, Reinholt and Lenz;
- Bolt, Sprocket and the B&S cast in their comedy voices;
- the Operator: a 1940s radio announcer with a salesman's warmth.

Write the casting reasons into `docs/VOICES.md`.

**3. No cloning of real people** unless that person's `consent.txt` says `ai_voice_cloning: yes`. That includes PAUL and THE SLENDER: their voices are designed, not cloned, until consent exists.

**4. Choose the model.** Use the current best ElevenLabs model for expressive dialogue that supports audio tags (screams, whispers, breathing, crying). Check the API docs for what's current and update `TTS_MODEL`. Use a multilingual model for the Russian, German and Polish lines.

**5. Cost control.**
- Before any bulk bake, count the characters of every line to be baked, write the estimate and the plan size it needs to `NEEDS_DEVIN.md`, and bake in priority order:
  1. the new cutscenes;
  2. the squad;
  3. the Operator;
  4. the map NPCs;
  5. the bosses;
  6. barks;
  7. The Fine Print;
  8. Bolt & Sprocket.
- Cache every take by a hash of the text, voice and settings, so nothing is ever paid for twice.
- Stop cleanly when the quota runs out, and resume next run.
- Log credits used per batch.

**6. Recorded takes still win.** A take from me or my friends (the U06 recording pipeline) always overrides the ElevenLabs take for that line. Mark every AI line as AI in the manifest and the review page, as now.

**7. Zombie and creature sounds:** ElevenLabs sound effects (if the plan includes them) for the Soviet risen's groans and whispers, the Kielholer, and the chant bed. Otherwise, use free CC0 sound packs.

**8. Tests:**
- the key is never written to disk (scan the repo and the logs);
- the cache;
- quota-stop and resume;
- every line ID has a voice or an explicit reason it doesn't;
- human takes override.

## 8. THE RESPECT REVIEW
Spawn a **fresh Fable reviewer that wrote none of this**, and have it read `docs/LAZARUS.md`, the four cutscene shot lists and a sample of 200 rewritten lines. It checks that:
- **Faith is treated with respect.** The miracle is never mocked or called a disease, the clergy are never the villains, and no real Church body is shown doing anything it didn't do.
- **Real history is accurate where it's used, and labelled fiction where it isn't.** No real person is named as a villain. The anti-religious campaigns are shown as they were, without gloating.
- **Soviet and German soldiers are people, not caricatures.** Forced laborers and camp prisoners are never zombies and never spectacle.
- **No real Nazi symbols.** Soviet uniforms are period-correct, and political imagery is never used for shock.
- **The horror comes from what people did.**

Fix everything it flags, and record the review in `docs/LAZARUS.md`.

## 9. TESTS AND SMOKES
- The Easter egg guard test (§2).
- Every egg smoke and every map smoke still passes.
- The cutscenes: each plays, skips, and runs online.
- The fourth-day rule tests.
- The ElevenLabs tests.
- Story-prop and Archive counts updated.
- The VO extractors pass.
- **The full unit suite and every smoke at FINISH.**

## 10. FINISH
- **Add `Play.bat` buttons:**
  - "Prologue — Lazarus Saturday"
  - "Cutscene — Fourth Day (1944)"
  - "Cutscene — Staub"
  - "Map 0 — new crash intro"
  - "Hard Truth test (bleed-out rises)"
  - "Voice review (ElevenLabs takes)"
- **Regenerate the voice script** for me to read (the per-actor scripts and a single PDF of every line, by character).
- **Merge to `master` and push.**
- **`morning/MORNING_REPORT.md`, written for a player:**
  - the new story in one page;
  - what to watch first;
  - which lines are voiced by ElevenLabs and how many are left (with the credit numbers);
  - anything not working.
- **`morning/NEEDS_DEVIN.md`:** the ElevenLabs key and plan steps, if they weren't done.
- **Tell me the one line to paste into Claude Code on my PC to pull it.**
