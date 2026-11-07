# Voices: ElevenLabs for every voice (UPDATE 11 §7, T-193; casting values T-201)

Every voice in Claude Zombies (GRAVELIGHT), The Fine Print and Bolt & Sprocket is baked by ElevenLabs. The local
voices (Kokoro for the squad, Windows OneCore for the rest, the B&S runtime TTS) stay as the fallback. A take
recorded by the owner or his friends (the U06 pipeline, `docs/VOICE_ACTING.md`) always wins over both.

Code: `tools/voice/eleven.py` (run as `tools/voice.sh elevenlabs ...`; the file is not called `elevenlabs.py` because
that name would shadow the official SDK package `elevenlabs`). Cast: `data/voice/cast.json`. Effects: `data/voice/fx.json`.
Tests: `tools/voice.sh test` (`tests/voice/test_elevenlabs.py`, `tests/voice/test_eleven_key.py`).

## The key

`ELEVENLABS_API_KEY` from the environment, or else from the git-ignored `.env.local` in the repo root that
`npx @elevenlabs/cli onboard` writes (a worktree finds the main checkout's). The tools only put it into `os.environ`.
It is never written to a file, a log or a commit, and it is never printed. API errors are shown as status, code and
message only, with no headers, and they are scrubbed of anything shaped like a key. `test_eleven_key.py` scans every
tracked file and every log or cache file the tools write for the key and for the `sk_…` key shape.

Without a key, `tools/voice.sh bake` and `gen_vo.py` print the one-line setup step. Nothing is baked by ElevenLabs,
and the game keeps its current voices.

## The model

`eleven_v4` (`TTS_MODEL` in `eleven.py`). On 2026-11-07 it was the newest model listed for the account: "most
emotive", 94 languages, audio tags. One model covers the English, German, Russian and Polish lines. v4 takes only
`stability` and `similarity_boost`. It has no style, speed or SSML; delivery comes from audio tags and punctuation.
`language_code` is sent per line. v4 bills one credit per character (the live check's `x-character-count` matched
the length of the text sent). Sound effects use `eleven_text_to_sound_v3`, and Voice Design uses `eleven_ttv_v3`.

Output: `pcm_44100` needs the Pro plan. The account is on Creator, so the tool steps down to `mp3_44100_192`
(Creator and up), then to `mp3_44100_128`. It remembers the format that worked. The audio is decoded and goes through
the same chain as a recorded take: trim, loudness by delivery (the `voice_cast.json` targets, true-peak -1.5 dB),
the character's effect from `fx.json` (the Operator's tannoy, the radios, phonograph, PA, the robots), and then the
line's effect cues (`[radio]`, `[distant]`, `[static]`). The result is OGG Vorbis, 48 kHz mono, at the path the game
already plays. No game code changed.

## What is said

- `speech` wins over `text`: the `speech` line is what gets said, and the subtitle stays `text` (T-154 / U11 C3).
  The subtitle's `[cues]` still count.
- `(parentheticals)` are glosses or stage notes, so they are not said. `{splice}` braces, `*markers*` and ™ ® ♪ are
  dropped.
- `[tags]`: delivery words become v4 tags (`[whisper]` → `[whispers]`, `[shout]` → `[shouting]`, `[sobbing]` →
  `[crying]`, `[tired]` → `[exhausted]`, `[softly]` → `[quietly]`). Effect words are stripped and applied after the
  synthesis (`radio`, `static`, `crackling`, `distant`, `slowed`). A pause becomes `...`. A short delivery word
  nobody maps passes through (`[weak]`, `[slowly]`). Blocking (`[to Dutch]`), sound cues (`[click]`,
  `[orchestra swell]`) and long stage directions are not sent.
- If a shout, hurt, quiet or "mine" line has no tag of its own, it gets one (`[shouting]`, `[pained]`, `[quietly]`,
  `[whispers]`). A character can switch this off with `eleven.delivery_tags: false`.
- Language: the line's own `lang`, else the language of `speech`, else the speaker's `eleven.language`. A whole line
  in another language (Jakub's "Precz! Precz ode mnie!") is sent as that language. A few Polish words inside English
  stay English, and the voice's accent carries them.

## Casting (`data/voice/cast.json`)

`characters.<game>.<code>.eleven`:

| field | meaning |
|---|---|
| `voice_id`, `voice_name` | the ElevenLabs voice (empty = not cast yet; the plan counts the line, the bake skips it) |
| `source` | `library` (a Voice Library voice) or `design` (made with Voice Design). A `clone` works only if the actor's `voice_inbox/<id>/consent.txt` says `ai_voice_cloning: yes` (`consent_actor`) |
| `design_prompt` | the Voice Design prompt (a first draft for every main character) |
| `language` | `en` `de` `ru` `pl`: the `language_code` sent |
| `stability`, `similarity_boost` | the only v4 settings (defaults 0.5 / 0.75; lower stability = more expressive) |
| `why` | the casting reason |
| `none` | a reason the character has no voice (PAUL / SLENDER: their lines are under PAU / SLN; NAR: silent cards preferred) |
| `candidates` | Voice Library search hits for T-201 to listen to (not assigned) |
| `same_as_voice` | a cameo sharing another game's voice (`BLT` → `bs:bolt`, `VEN` → `fp:vendelin`) |

`characters.gl.SQD.eleven_by_prefix` gives one voice per relief squad (`SQD_AK`, `SQD_SOV`, ...).
`characters.fp` holds The Fine Print's speakers, and `same_as` points to a voice they share (`wren` → `gl:WRN`,
`bolt` → `bs:bolt`). Every line in the three games maps to a cast entry or says why it has none
(`test_every_line_has_a_voice_or_a_reason`). The containers `BNT` and `TAG` are not voices: their exchange parts have
their own speakers.

Commands:
```
tools/voice.sh elevenlabs voices [--search=..]                         the account's voices with accent/age/gender labels
tools/voice.sh elevenlabs voices --library --accent=polish --gender=female   the shared Voice Library
tools/voice.sh elevenlabs assign --char=gl:WRN --voice=<id> --owner=<public owner id> --name="Wren" --why=".."
                                                                       adds a library voice to the account and casts it
tools/voice.sh elevenlabs design --char=gl:SER                         Voice Design previews from design_prompt (saved, listed)
tools/voice.sh elevenlabs design --char=gl:SER --pick=2                creates preview 2 and stores its voice_id
```

### Who sounds like what, and why

| Character | Voice | Why |
|---|---|---|
| Dutch (`DUT`) | Pittsburgh: a low, gravelly baritone, Western Pennsylvania vowels, unhurried | a Polish-American steelworker's son who grumbles to keep the men going; under U11 more tired and frightened |
| Peg (`PEG`) | posh English: Received Pronunciation, clipped, never raised | SOE; the worse it gets, the more politely she speaks |
| Deacon (`DEA`) | soft Southern: a warm Louisiana tenor with a preacher's rhythm | the saga's quiet theological voice, a line at a time, never a sermon |
| Wren (`WRN`) | Polish-accented English, low, economical, deadpan | Home Army; English learned from British radio; she knows the NKVD |
| Jakub (`JAK`) | an older Polish voice, careful English, calm and wry | a person and a hero, played straight, never a joke |
| The Operator (`OPR`) | a 1940s radio announcer with a salesman's warmth: bright, brassy, a little too quick; the tannoy is added afterwards | it stays cheerful about "the returned" and "the fourth day". The horror is the warmth |
| Fasbender (`FAS`) | German-accented English, nervous, hushed, haunted | he saw the Soviet dead come in on the trains; field radio afterwards |
| Reinholt (`REI`) | refined German-accented English, slow, cold; German lines in German | phonograph / PA afterwards |
| Father Serafim (`SER`) | Russian: an older village priest, a deep, gentle, worn bass-baritone, liturgical cadence | subtitled; frightened faith, never a villain, never a zombie on screen |
| Volkov (`VOL`) | Russian: a precise, quick, controlled baritone | frightened, clever, ambitious, never a cartoon |
| Soviet radio (`SVR`), the brigade (`BRG`), the Returned (`RTN`) | Russian: a flat signaller on the radio chain; a zealous megaphone; young soldiers' hoarse, broken whispers | subtitled; the risen only from close up |
| The PA (`PA`), the Bordwart (`BWT`), Lenz the Kielholer (`KLH`), U-boat radio (`UBR`) | German | the German announcements and Lenz's refusal stay German |
| The map people (`WIE` `BRA` `KRO` `SOB` `ROT` `KUB` `TRU` `POH` `AMM` `PET` ...) | real people speaking English as a second language with a light German (or Polish) accent | played straight, never comic (T-077) |
| The Cousins (`HAM` `RCH` `ALX` `CSN`) | German, creepy-doll horror, playful and sad | never sexualized; designed, never cloned from the owner's cousins |
| PAUL (`PAU`), THE SLENDER (`SLN`) | designed voices: a big loud private; a calm, tired night watchman | **no clone** until `voice_inbox/paul/` or `voice_inbox/devin/consent.txt` says `ai_voice_cloning: yes` |
| Bolt, Sprocket and the B&S cast | comedy voices: Bolt the warm straight man; Sprocket dry, smug, very fast (the robot treatment is added afterwards); Grindstone booming; Blartz loud and too close to the mic; GLAMBOT showbiz | the comedy is the contrast with Gravelight |
| The Fine Print (Vendelin, Res, Sable, the Underwriter, the Darkmatter PA ...) | from FINEPRINT_LORE §3.8: Vendelin low and slow with a hum under the vowels; Res warm, slow, Bernese; Sable a low unhurried alto | Darkmatter is played straight: soft, grateful, patient |

Library voices are voices that people chose to share in the Voice Library. Voice Design makes a new voice from a
prompt. Neither one copies a real person without their consent. `clone` (an Instant Voice Clone of a cast member's
own takes) is refused unless their consent says so.

## Cost control and baking

```
tools/voice.sh plan                 characters still to bake per group, the account's quota and the plan it needs
                                    (writes the estimate under "## UPDATE 11: ElevenLabs" in morning/NEEDS_DEVIN.md)
tools/voice.sh bake [--only=2] [--limit-chars=20000] [--ids=DUT_,OPR_ROUND] [--game=gl] [--dry-run]
python gravelight/tools_src/gen_vo.py      the Gravelight bake: the ElevenLabs pass first, then Kokoro / OneCore for
                                           whatever is left (--no-eleven, --engine=eleven, --eleven-limit-chars=N)
```

- **Order:** 1 the new cutscenes (`*_LZS_*`, `*_FTD_*`, `*_STB_*`, `*_GL1_*`, SER VOL SVR RTN BRG NAR), 2 the squad,
  3 the Operator, 4 the map NPCs, 5 the bosses, 6 barks (gameplay-trigger categories), 7 The Fine Print (read from
  `docs/fineprint/script_ch*.md`; it plays where B&S plays recorded lines, `res://audio/vo/<id>.ogg`), 8 Bolt &
  Sprocket.
- **Cache:** every take is stored raw by sha256 of (spoken text, voice id, model, settings, language) in
  `<main checkout>/.voice_cache/eleven/`. The folder is git-ignored and shared by every worktree. A cache hit never
  calls the API, so changing an effect or the loudness reprocesses for free. A line is paid for again only when what
  is said, the voice or its settings change.
- **Quota:** before each call the bake checks the account's remaining characters, and `--limit-chars` adds a cap of
  your own. A 401 quota or auth error, 402, or a 429 / 5xx that persists after 4 retries stops the bake cleanly. It
  writes where it stopped (`.voice_cache/eleven/bake_state.json`), and the next run says "resuming" and carries on.
  A 400 / 422 skips that one line.
- **Credits log:** `logs/elevenlabs.log` (git-ignored) gets one JSON line per batch of 20 lines: the characters billed
  (from `x-character-count`), the account's count before and after, and the stop reason. It never holds the key.
- **Manifest:** every AI take is `source: ai_eleven`, `"ai": true`, with the model, voice, language, settings and
  cache hash. The TTS row is kept under `tts` to fall back to. The review page (`tools/voice.sh review`) shows it as
  AI. `gen_vo.py` keeps it while the subtitle is unchanged, just as it keeps a recorded take. A recorded take that
  arrives later replaces it. If that take is withdrawn, the TTS comes back, and the next bake ships the cached AI take
  again at no cost.
- **Sound effects:** `tools/voice.sh elevenlabs sfx --name=risen_groan_01 --prompt="..." --seconds=4 [--loop]
  [--out=path.ogg]` (cached the same way) is for the horror pass. None are baked yet.
- **The live check:** `tools/voice.sh elevenlabs check` makes at most 3 calls under 300 characters into a scratch
  folder, never the game.

### The estimate (2026-11-07, before the U11 rewrite)

409,479 characters still to bake: squad 39,994, Operator 27,862, NPCs 37,508, bosses 2,182, barks 47,041,
The Fine Print 197,650, Bolt & Sprocket 57,242. The new cutscene lines and the rewritten lines are not counted yet.
The account is on Creator (131,000 characters a month, reset on the 7th), so the whole bake takes one month on Pro,
or about four monthly periods on Creator. Rerun `tools/voice.sh plan` after T-191 and T-195..T-199 merge.
