# T-285: two trailers (teaser + gameplay)

The owner, 2026-11-25: "MAKE A TRAILER FOR THE GAME USING HIGGSFEILD, SCARY ANTICIPATION BUILDING. ALSO MAKE A GAME PLAY TRAILER TOO".

Outputs (not in git, `build/` is ignored): `build/trailers/teaser_1080p.mp4`, `teaser_720p.mp4`, `gameplay_1080p.mp4`,
`gameplay_720p.mp4` (H.264 High + AAC 256 kbit/s at 1080p, 192 kbit/s at 720p), `build/trailers/README.txt` (shot
list, prompts, credits, licences), per-shot sources in `build/trailers/src/<run>/` and `build/trailers/hf/`.

## Pipeline

1. **Record** in-engine shots invisibly under WSL Xvfb: `tools/trailer/record.sh <run> [--only=a,b] [--stride=n]`
   runs `gravelight/tools_src/clip_trailer.tscn` (Forward+ on lavapipe) for one run of
   `gravelight/tools_src/trailer_shots.json` (one map per run) and encodes each shot's JPG frames to
   `build/trailers/src/<run>/<shot>.mp4`. It refuses to start while another Xvfb runs in WSL or under 8 GB free.
2. **The capture tool** (`clip_trailer.gd`): each shot is set up with the render loop off (game time runs as fast as
   the CPU allows, nothing drawn), then recorded frame by frame at a fixed game step (`--fixed-fps 24`). Cameras:
   `free` (keyframed position, look target or yaw/pitch, fov, ease, a little handheld shake; `anchor`/`orbit` round
   a node, `follow` riding with the tank or the horse, `look_follow` tracking the V2), `eye` (the player's own eye
   and viewmodel, aimed at the nearest zombie, fire held by the real input action), `tank` (the T-278 orbit camera
   turned relative to the hull), `keep` (whatever is current: the horse's saddle, the zip line). Ops: hordes at a
   point / ahead of the camera / in the tank's frame, still figures, blasts at the horde's middle
   (`Effects.explosion`, the T-280 kinds), the V2 launch at a given second of its sequence, mount the horse, ride a zip
   line, drive / fire the Sherman, bots moved, and every CaptureDo verb (power, doors, boards, bosses, timescale ...).
   The HUD is hidden per shot (`off` keeps the viewmodel, `none` hides it, `on` keeps the real HUD without its
   debug lines: no "GOD MODE"); layers that set their own `visible` every frame (the squad roster) are moved
   off-screen; every Label3D (painted signs, stencils, name tags) and the world marks (the people's
   "Courier at the gate · 11 m" labels) are hidden, because lettering is what a Higgsfield re-render keeps worst.
   In an eye shot the magazine is topped up when it runs low (no empty click mid-shot).
3. **Render cost** under lavapipe (16 WSL cores): Low preset about 0.3 s a frame at 720p (75 % scale), about 1-2.5 s
   at 1080p full scale with a horde and bots; Medium cost 10-20 s an exterior frame (SSIL, volumetric fog) and reads
   nearly the same at night, so every run uses Low (the gameplay runs at full scale, 1920x1080).
4. **Teaser**: twelve shots recorded at 1280x720, 12 fps (every second frame of the 24 fps game step: Higgsfield's
   output was checked to be full 24 fps motion from a 12 fps reference, 131 unique frames of 137), uploaded and
   re-rendered by Seedance 2.5 `video_edit` at 480p (the T-277 recipe; prompts in `tools/trailer/teaser_prompts.json`,
   requests by `tools/trailer/hf_batch.py`, results fetched and compared source-over-result by
   `tools/trailer/hf_fetch.sh`). One shot (the breath in the cold) is text-to-video.
5. **Cut** (`tools/trailer/make_trailers.py`, `edit.py`, `gameplay_edl.py`): ffmpeg per segment (trim, speed,
   lanczos to 1080p, grade, letterbox for the teaser, fades, flash frames, card overlays), joined and muxed with the
   score. Cards (`cards.py`): Stardos Stencil Bold and Special Elite (OFL, already in assets/third_party).
6. **Sound** (`tools/trailer/trailer_audio.py`): synthesized with the game's own DSP core
   (`gravelight/tools_src/gen_audio.py`) plus the game's own in-house sound files (T-280 blast layers, the Sherman's gun
   and engine, the horse, the boss roars, the horror whispers and far bell; every one made by the repo's
   gen_audio_*.py scripts). The cue list comes from the edit, so hits land on cuts.

Run order: `sh tools/trailer/record.sh teaser_m0 --stride=2`, `TRAILER_RES=1920x1080 sh tools/trailer/record.sh game_m0`
(and game_m1, game_m2, game_m4b, game_m4d), the Higgsfield calls, then
`tools/venv/Scripts/python.exe tools/trailer/make_trailers.py both`.

## Decisions

- **Title**: the cards read GRAVELIGHT with "TERMS & CONDITIONS" under it (project.godot's name). The zombie menu's
  wordmark reads CLAUDE ZOMBIES; that is a real product's name, so it is left off the trailers (the owner can swap
  the word in `cards.py` / `make_trailers.py`). Card lines are the menu's own taglines ("Silesia, winter 1944. The
  dead are keeping count.", "Something at the treeline has learned your name.", "The fence will not hold.",
  "Every round is a signature.").
- **Upscale**: Higgsfield's upscaler has no cost preflight, so the 480p teaser clips are upscaled locally (lanczos,
  a light unsharp, film grain, letterbox 2.35:1) instead.
- **Prompt words**: a first text-to-video prompt with "horror" and "blood" was rejected by the filter (not charged);
  the teaser's prompts say "suspense film", "pale gaunt figures with grey skin" and leave gore words out.
- **video_edit vs omni_reference**: the dark empty places (crossroads, inn, taproom, window, gate, tower) re-render
  well in `video_edit`; the figure shots (the face, the horde, the boards, the lunge) stayed mannequin-like (the
  T-277 failure mode) and were redone in `omni_reference` with the source clip as the reference.
