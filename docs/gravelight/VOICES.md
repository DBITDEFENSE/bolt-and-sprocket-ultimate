# The squad's voices (T-073)

How the survivors (Dutch `DUT`, Peg `PEG`, Deacon `DEA`, Wren `WRN`) and Jakub (`JAK`) are voiced, how to bake
new lines, and what the runtime does with them. Placeholder VO until recorded lines replace it per id; the files
are generated, never hand-edited. Line text and triggers stay in `VO_SCRIPT.md`; who the people are is in
`CHARACTERS.md`.

## Engine

**Kokoro-82M** (v1.0, ONNX, CPU), an offline neural text-to-speech model, run through `kokoro-onnx`. It replaced
the Windows OneCore voices (David / Mark / Zira) for the squad because it sounds like people instead of a
screen reader, has both American and British voices, and lets one voice be blended from several styles, so each
character gets a voice of their own. The Operator, Fasbender, Reinholt and Liesl stay on OneCore: their channels
(tannoy, radio, PA, phonograph) were built around those voices and already sell the period; the OneCore path is
also the squad's fallback when the neural engine isn't set up.

| Piece | Licence | Where |
|---|---|---|
| Kokoro-82M weights + voice styles | Apache-2.0 | `tools/tts/kokoro/` (git-ignored download) |
| kokoro-onnx | MIT | `tools/venv` |
| onnxruntime | MIT | `tools/venv` |
| misaki (G2P lexicons; spaCy not needed) | Apache-2.0 | `tools/venv` |
| eSpeak NG (via espeakng-loader / phonemizer-fork) | GPL-3.0 | `tools/venv`; a build tool only: no part of it ships with the game, only our rendered audio |

Everything is project-local: `tools/setup_tts.sh` makes the venv and downloads the model once; nothing is
installed system-wide, no admin, no online service at bake time. A git worktree finds the main checkout's
`tools/` on its own.

Text to sound: English words go through misaki's US or GB dictionaries (the ones Kokoro was trained on), with
eSpeak NG for words they lack. Polish words (`voice_cast.json` `polish`) use eSpeak NG's Polish phonemes: Wren
and Jakub keep the Polish sounds, Dutch gets them anglicised (his "kitchen Polish"). The OneCore-only `tts`
respellings in lines.json are not used by the neural bake.

## Casting (`data/gravelight/vo/voice_cast.json`)

| Who | Kokoro style blend | Lexicon | Pace | Notes |
|---|---|---|---|---|
| Dutch, 34, Pittsburgh | am_onyx 55 % + am_fenrir 45 % | US | 0.95 | the deepest voice (median f0 ~115 Hz), chest EQ, a little tanh warmth for the gravel; emotion scale 0.7: he complains, he never panics |
| Peg, 29, SOE | bf_emma | GB (RP) | 1.04 | clipped and quick; emotion scale 0.35: her shouts and her down stay level, and her last full stop never becomes "!" ("in a crisis she sounds bored") |
| Deacon, 26, Louisiana | am_michael 70 % + am_puck 30 % | US | 0.93 | warm tenor (~130 Hz), low-mid warmth, soft top; emotion scale 1.0 |
| Wren, 24, Home Army | bf_isabella 75 % + bf_lily 25 % | GB | 1.0 | English learned from British radio; `polish_light` accent; emotion scale 0.75 |
| Jakub, 44, salt hewer | bm_george 60 % + bm_lewis 40 % | GB | 0.9 | an older, slower British-trained voice; `polish` accent; emotion scale 0.8 |

**Accents** are phoneme rules on the English words, modelled on a Polish first language, and kept light on
purpose (people speaking a second language well, never a comic voice): th-stopping (θ→t, ð→d), a tapped r,
Polish vowel qualities (æ→ɛ, ʌ→a, əʊ→ɔ), word-final devoicing (Wren: only z/v before a pause; Jakub: all final
voiced stops and fricatives), and for Jakub also short vowels (no English long/short pairs: iː→i, ɪ→i, ʊ→u...).

## Delivery per category

`voice_cast.json` `categories` maps category prefixes to a delivery; `emotions` holds what each does. Each
speaker's `emotion_scale` scales the deviation from neutral.

| Delivery | Categories (examples) | Pace | Loudness | Colour |
|---|---|---|---|---|
| calm | spawn, round start/end, crate, perks, banter | 1.0 | target | small room |
| brisk | marks, orders, EE acks, reload, ammo, buys, revive | 1.05 | +0.5 LU | a touch of presence, no breath |
| raised | any calm/brisk line with "!", sky plane, Jakub fallen | 1.06 | +1.5 LU | presence, short inhale |
| shout | runner behind, danger mark, bosses, team down, window open, Jakub's alarm/breakout/calls | 1.1 | +2.5 LU | presence + air + drive, final "." read as "!", sharp inhale, a bit more room |
| hurt | DOWN, Jakub back wounded | 0.9 | -1.5 LU | darker top, a 5-6 Hz tremor, a longer inhale |
| quiet | chatter, midnight, blues, lantern, cage talk, Polish lessons, revived | 0.95 | -3 LU | soft top, closer room |
| mine | Jakub's Kaltenbrunn arrival / zone lines | 0.97 | -1 LU | a 0.9 s cavern |

## Post-processing (`gen_vo.py` `process_neural`)

Trim, per-character high-pass + EQ bands + warmth, the delivery's presence / air / drive / tremor, a gentle
2.4:1 compressor with a zero-phase gain, an inhale before lines of 1.2 s or more and in some sentence pauses of
350 ms or more, a small room (whisper / distant / radio cues still work), then loudness normalisation to
**-17.5 LUFS** integrated (ITU-R BS.1770, `vo_loudness.py`) moved by the delivery, and a 4x-oversampled
true-peak ceiling of -1.5 dBTP. No pitch or "size" shifting on neural lines (the old phase vocoder was the main
source of robotic artefacts).

## Baking new lines

```
python gravelight/tools_src/gen_vo.py                  # everything new or changed (incremental, deterministic)
python gravelight/tools_src/gen_vo.py --only=SQUAD     # just the squad + Jakub
python gravelight/tools_src/gen_vo.py --only=DUT_SQ5   # an id prefix
python gravelight/tools_src/vo_loudness.py --engine=kokoro   # loudness / peak / cut-off report
```

A line rebuilds when its text, its speaker's cast entry, its delivery, the accent rules (or the Polish list, if
the line has Polish in it) or `NEURAL_TOOL_VERSION` change. The manifest row records `engine`, `delivery`, the
measured `lufs` and the phonemes Kokoro read, so a mispronunciation can be found and fixed (add a Polish
override, a word to `polish.words`, or reword the line). First run on a new machine: `tools/setup_tts.sh`.
`--engine=onecore` bakes the squad with the old voices (the fallback), `--engine=neural` refuses to fall back.

## Runtime (`gravelight/autoload/vo_manager.gd`)

- Bots', other players' and Jakub's lines are positional at their body (`AudioStreamPlayer3D`, inverse-distance,
  `rules.json audio` unit size 5 m, max 40 m), following them while they talk.
- **Occlusion:** while such a line plays, one ray from the camera to the speaker's head every 0.12 s against the
  world and doors (layers 1 + 9). Behind a wall the voice slides to a 1.1 kHz low-pass and -5 dB, smoothed;
  the first check happens as the line starts. Tunable in `rules.json audio occlusion_*`.
- **Anti-repetition:** each speaker+category is a shuffle bag (no repeat until all variants played), and now a
  refilled bag never opens with the line that closed the last one. **Squad anti-echo** (`rules.json
  squad_echo`): when one survivor or Jakub has said a category (reload, ammo, runner behind, boss, powerup,
  crate moved, window open, headshot, chatter...), nobody else in the squad says it again for that category's
  window. Downs, revives, map-mark and order acknowledgements are never echo-limited.
