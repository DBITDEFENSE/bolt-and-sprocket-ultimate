# Archive-reel clips: drop them here

The three history cutscenes (**Lazarus Saturday** 1930, **Fourth Day** 1944, **Staub** 1944) play as archive film
reels. Each reel is cut into shots; every shot you generate replaces its span of the scene, and every shot you have not
generated yet plays in-engine through the same film look. So you can drop in one clip or all of them, in any order.

## 1. Generate

Open `docs/cutscenes/SHOT_PROMPTS.md`. For each scene it lists the shots **in priority order** (do priority 1 first),
with the file name, the length to ask for, and the full prompt (it already starts with the shared style block). Paste
the prompt into Higgsfield in the Claude app as it is. Any length from 4 to 10 seconds works; the build trims a longer
clip and slows / holds a shorter one to fit its span.

Before you keep a clip, check it against the rules at the top of `SHOT_PROMPTS.md`: no violence on screen, no real
people, **no text, letters, signs, insignia or logos in frame**, no political or Nazi symbols, the priest and the church
shown with respect. If a clip breaks one, generate it again.

## 2. Save

Save each clip, exactly named, into its scene folder here:

```
assets/user_supplied/cutscenes/lazarus_saturday/shot_01.mp4
assets/user_supplied/cutscenes/fourth_day/shot_14.mp4
assets/user_supplied/cutscenes/staub/shot_08.mp4
```

`.mp4`, `.mov`, `.webm`, `.mkv` and `.m4v` all work. A shot marked *Gore-safe* in the prompt file may also get a
`shot_NN_gore.mp4`; the game uses it only when the Gore setting is on Full. The clips stay on your PC (this
folder is git-ignored except for this README and the paperwork); only the treated `.ogv` files ship.

Then open the scene's `SOURCE.txt` and fill in the two `FILL IN` lines (the Higgsfield model and the dates), and read
`LICENSE.txt`: the plan's commercial-use terms still need your check before a public release.

## 3. Build

From the repo root:

```
python -I tools/cinema/archive_reel.py build      # treats every new or changed clip (incremental)
python -I tools/cinema/archive_reel.py report     # what is filmed, what is still a stand-in, in priority order
```

`build` writes `assets/cutscene_reels/<scene>/shot_NN.ogv` (1080p) and `shot_NN_720.ogv` (the web build's), graded to
match the scene's reference shot, cropped to the Academy frame, and copies `SOURCE.txt` / `LICENSE.txt` beside them.
The game picks them up on its next start with no code change. `tools/build_web.sh` and `tools/build_windows.sh` run the
same build step before they export, so a release never misses a clip.

To watch a whole scene as one finished film (cards in Russian or German with English, the voices and the ambience
mixed in, film damage baked in):

```
python -I tools/cinema/archive_reel.py reel --scene lazarus_saturday     # -> build/reels/lazarus_saturday_reel.ogv (+ _720)
```

In the game: Play.bat > the dev launcher > "Cutscene — Lazarus Saturday (reel)" (and Fourth Day, Staub).

**Windows note.** The Windows builds of ffmpeg write broken Theora video, so on Windows the tool checks the encoder and
uses the ffmpeg inside WSL (Ubuntu: `sudo apt install ffmpeg`) automatically. If neither works it says so and the
game keeps its in-engine stand-ins. `REEL_FFMPEG` overrides the command (e.g. `wsl -d Ubuntu-24.04 -e ffmpeg`).
