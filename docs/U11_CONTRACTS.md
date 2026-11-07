# UPDATE 11 "LAZARUS" contracts (the lead's interface spec between the parallel sections)

Work order: `docs/work_orders/UPDATE_11_LAZARUS.md`. Every worker reads it and this file first. The U09/U10 contracts
still hold (`docs/U09_CONTRACTS.md`, `docs/U10_CONTRACTS.md`): the Marke (`marke`, never `mark`), the budgets, the
capture path (WSL + Xvfb only; never a rendered Godot window on the owner's PC), headless Godot with
`--audio-driver Dummy`, one branch per task (`u11-<sec>-<slug>`), rebase on master before you report.

Map ids in code: map00 = Crossroads Inn, map01 = Kaltenbrunn, map02 = Totenhafen, map04a-d = Fernflug Acts I-IV
(Morgenrot, map03, is designed only). Use the code ids in data and tests.

## C1. Task numbers and branches
| T | Section | Branch | Model |
|---|---|---|---|
| T-189 | lead: guard test, contracts, merges, finish | master | lead |
| T-190 | §1-§3 canon, the docs, the Archive texts, story-prop texts | u11-1-canon | Fable |
| T-191 | §5 shot lists + every cutscene line + the new speakers' lines (§4 new speakers) | u11-5-shots | Fable |
| T-192 | §6 horror pass (Soviet risen, grit, audio, Hard Truth, menu) | u11-6-horror | Opus |
| T-193 | §7 ElevenLabs pipeline (default bake path, cache, quota, tests, docs/VOICES.md) | u11-7-eleven | Opus |
| T-194 | §5 the four cutscenes built on the T-184 cinema library, their sets | u11-5-cutscenes | Opus |
| T-195..T-199 | §4 the VO rewrite, one worker per slice (C4) | u11-4-vo-<slice> | Fable |
| T-200 | Archive wiring, story-prop placement, credits, test and smoke upkeep | u11-3-archive | Haiku |
| T-201 | §7 casting data + the batch bake | u11-7-bake | Sonnet |
| T-202 | §8 the respect review (a fresh reviewer) | (review only) | Fable |

Append only your own T paragraph to `docs/DECISIONS.md`. Don't edit `PROGRESS.md` or `morning/*` (the lead does).

## C2. The guard
`gravelight/tests/unit/test_u11_egg_guard.gd` hashes every file under `data/gravelight/quests/` (doc keys starting
with `_` left out). **No U11 branch changes a quest file.** Egg VO lines (the ids the quests name in `vo`, `on_vo`,
`vo_squad`, `vo_actor`, ...) may be re-toned in the VO docs, keeping the same id, the same cue and every piece of
gameplay information (a code, a frequency, a bell order, a place, a count).

## C3. Voice lines: where they live and how they change
- **Source of truth:** the `ID` tables in `docs/gravelight/VO_SCRIPT.md` and `docs/gravelight/CHARACTERS.md`;
  `python gravelight/tools_src/extract_vo.py` regenerates `data/gravelight/vo/lines.json` from them (lines that exist
  only in lines.json are kept as they are; edit those in lines.json directly). Run the extractor after editing and
  commit both. On merge the lead re-runs the extractor over the merged docs, so a lines.json conflict is resolved by
  regeneration, never by hand.
- **Keep every id.** A replaced line keeps its id; a new line gets a new id. Never delete an id a quest, a cutscene, a
  data file or a test names (grep for it first).
- **Foreign-language lines:** `text` is the English subtitle the player reads; `speech` is what is said (German,
  Russian in Cyrillic, Polish, Church Slavonic) when it differs (the T-154 convention gen_vo.py already honours). The
  older German style "Achtung. Turbulenz. (Attention. Turbulence.)" in `text` stays valid. For a table row, put the
  spoken form in a `Speech` column if the table has one, or in the line text as `<speech>...</speech>` before the
  subtitle (extract_vo.py turns it into the `speech` field; T-191 adds that to the extractor).
- **Audio tags** in `[brackets]` are kept (gen_vo.py turns them into cues; ElevenLabs v4 takes them as delivery tags:
  `[whispers]`, `[exhausted]`, `[crying]`, `[shouting]`, `[breathing heavily]`...). Use them; don't overdo them.
- **New speaker codes (three letters, registered here):** `SER` Father Serafim Lebedev (Russian, subtitled), `VOL`
  Arkady Volkov (Russian, subtitled), `SVR` Soviet radio traffic (Russian, subtitled), `RTN` the Returned: risen Red
  Army soldiers' last words (Russian, subtitled, close only), `BRG` the 1930 brigade's megaphone (Russian, subtitled),
  `NAR` the title-card narrator if a cutscene needs one (prefer cards without a voice). Any other new code: three
  letters not already in lines.json, added to this table by the lead.
- **New categories:** cutscene lines `<SPK>_LZS_*` (Lazarus Saturday), `<SPK>_FTD_*` (Fourth Day), `<SPK>_STB_*`
  (Staub), `<SPK>_GL1_*` (the rebuilt GRAVELIGHT ONE crash); Serafim's diary read-alouds `SER_DIARY_<MAP>_01`; Soviet
  radio `SVR_M0_*` / `SVR_M1_*`; the risen's close lines `RTN_CLOSE_01..` (the horror pass plays category
  `RTN_CLOSE`); the Moscow 1953 epilogue card `*_EPI53_*` if it is voiced.

## C4. The VO rewrite slices (T-195..T-199)
- T-195 `u11-4-vo-operator`: the Operator (`OPR`) everywhere, and the system/PA voices (`PA`, `TEL`, `BNT`, `WIT`...).
- T-196 `u11-4-vo-dutchpeg`: Dutch (`DUT`) and Peg (`PEG`), every section of both docs.
- T-197 `u11-4-vo-deawren`: Deacon (`DEA`) and Wren (`WRN`).
- T-198 `u11-4-vo-npcs`: Jakub (`JAK`), the squad lines (`SQD`), Fasbender (`FAS`), Reinholt (`REI`), Liesl, the map
  NPCs and the bosses' voices.
- T-199 `u11-4-vo-fineprint`: The Fine Print and Bolt & Sprocket, **only** where they say Darkmatter created the dead.
Each slice edits only its own speakers' rows. Tone (work order §4): fewer quips, gallows humour that thins map by map,
fear, grief, exhaustion; the Operator stays cheerful (the horror is its warmth); Fasbender haunted.

## C5. The canon in one paragraph (until T-190's docs land, the work order §1 is the canon)
The dead come from the blood of Lazarus kept in a sealed vessel (Constantinople 890, Rus 1453, the crypt of the Church
of St Lazarus the Four-Days-Dead in Chetverodnevo); a 1930 brigade opened it on Lazarus Saturday; the sickness raises
the dead on the fourth day; the NKVD's Laboratory No. 4 (FOURTH DAY) kept it; Darkmatter found it, packaged a culture
with its Nachtglas crystal (the 1938 probe) and sells to it: Darkmatter explains only the technology (perk machines,
the Crucible, the Ledger and Scrip, the Operator, the crate, Nachtglas). October 1944 the Soviets released it in East
Prussia and their own dead rose and walked west; the Germans took the bodies to Kaltenbrunn, where near Nachtglas it
takes minutes and ground with the crystal it carries on the air (STAUB); the Marke is sold as protection against it;
20 December 1944, the first STAUB release blew back over Kaltenbrunn the night the Heart went to full resonance.
Faith is never the villain; no real person is a villain or a victim by name; the horror is what people did.

## C6. Shared files and who owns them
- `data/gravelight/enemies.json` (+ zombie skins, spawn weights), `gravelight/enemies/*`, the Hard Truth rule,
  `data/gravelight/*_ambience.json` horror kinds, the main menu scene: T-192.
- `gravelight/ui/cinema/*`, new cutscene scenes/sets, the first-launch prologue hook, the campaign-start and
  Kaltenbrunn-arrival hooks, `docs/CUTSCENES_LAZARUS.md` (T-191 writes it, T-194 may add build notes): T-194.
- `tools/voice/*`, `gravelight/tools_src/gen_vo.py`, `data/voice/cast.json`, `data/gravelight/vo/voice_cast.json`,
  `tests/voice/*`, `docs/VOICES.md`: T-193 (then T-201 for casting values).
- The canon docs (work order §3), `docs/LAZARUS.md`, `docs/STORY_CHANGES.md`, the Archive texts
  (`data/gravelight/archive_lazarus.json`, C7) and story-prop texts: T-190.
- `data/gravelight/story_props.json` placement, `gravelight/ui/menu_archive.gd`, credits: T-200.
- `tools/dev_launcher*` / Play.bat buttons: the lead at FINISH.

## C7. The Archive texts (T-190 writes, T-200 places)
`data/gravelight/archive_lazarus.json`: `{"entries": [{"id", "map", "kind" ("diary" | "lab_file" | "front_report" |
"memo" | "order" | ...), "title", "date", "body" (plain text, the in-world document), "speaker_vo" (optional line id
for a read-aloud), "place_hint" (words: where in the map it lies, for T-200), "order"}]}`. One Serafim diary page per
map (map00, map01, map02, map04a, map04b, map04c, map04d: the last page on the Moon, in the relay's collection of
artifacts from every market), the Laboratory No. 4 files, the October 1944 Soviet front report, the STAUB memos at
Kaltenbrunn, Hale's sample order. Each is a world prop through the story-props system (no Easter egg step).

## C8. ElevenLabs (T-193 / T-201)
- The key: `ELEVENLABS_API_KEY` in the environment, or loaded at run time from the main checkout's git-ignored
  `.env.local` (made by the ElevenLabs CLI's onboarding on 2026-11-07). **Never open, print, cat, log or copy that file
  or the key.** Load it programmatically (python-dotenv / a parser that only sets os.environ). A worktree finds it at
  `$(git rev-parse --path-format=absolute --git-common-dir)/../.env.local`.
- Model: `eleven_v4` (expressive, audio tags, 90+ languages; supports `stability` and `similarity_boost` only, no SSML,
  `language_code` honoured). One model for English, German, Russian and Polish lines.
- Every take cached by a hash of (spoken text, voice id, model, settings, language); a cache hit never calls the API.
  Quota stop: on a 401/quota error the batch stops cleanly, writes where it got to, and the next run resumes.
- A recorded human take always wins over an AI take; every AI take is `ai: true` in the manifest.
- No cloning of a real person without `voice_inbox/<id>/consent.txt` saying `ai_voice_cloning: yes`.
