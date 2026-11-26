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
- **video_edit, omni_reference, text-to-video**: all twelve recorded shots went through `video_edit` first. Only the
  taproom (the swinging lantern) and the torn window (the figure outside) came back reading as film; the night
  exteriors stayed a re-lit game, and the figures (the face, the horde, the boards, the lunge) stayed mannequins (the
  T-277 failure mode). `omni_reference` with the recording as the reference kept the game look too (rejected). The
  other ten shots are text-to-video takes written from the same shot (the game's places and events described:
  the crossroads with crows on the wire, the inn, the radio on the high shelf, the open gate with its lantern, the
  watchtower's searchlight, the forest track with the silhouette, the violet-eyed face, the horde in the field, hands
  through the boards, the lunge), plus the breath shot that never had a recording. So the teaser is mostly generated
  footage in the game's world rather than a re-render of it; the recordings and every take are kept in build/.
- **Rule check** (frames of every take, source over result): no lettering, signs, flags, insignia or symbols in any
  kept take (the radio's dial is plain); no modern objects or road markings; clothes plain and ragged; nobody is
  Jakub; no Cousin appears in the teaser (they appear in the gameplay cut as the game's own porcelain-doll bosses).
- **Credits**: 443 of the 550 budget (964 -> 521): video_edit 224, omni_reference 60 (rejected), text-to-video 156,
  one filtered request free.

## Teaser (66.8 s, letterboxed 2.35:1)

Card "Silesia. Winter, 1944." / crossroads, crows on the wire / the inn / the taproom, a lantern swinging / the radio /
the breath in the cold / the open gate / the torn window, a figure outside / card "The dead are keeping count." /
the forest track, a silhouette at the treeline (+ "Something at the treeline has learned your name.") / the
watchtower's searchlight / the build: horde, eyes, boards, horde, lunge, eyes, boards, horde, lunge / hard cut to black /
GRAVELIGHT / black / the eyes, one last sting / "The fence will not hold." Sound: wind and a low drone, a far bell,
creaks, radio static, a whisper, a heartbeat that speeds from 52 to 120, a string cluster and a riser under the horde's
groans, silence, the title boom, the scream sting.

## Gameplay trailer (86 s, 120 BPM)

Cold open (tick bed): the U-boat pen, the Kaltenbrunn yard horde, the dead at the inn's window. Music A (the drop at
8 s, "HOLD THE INN"): firing the Thompson at the taproom window (the real HUD), the squad in the yard ("NEVER ALONE"),
the MG42 at Kaltenbrunn (HUD), a grenade into a pack, a 75 mm-sized shell in slow motion ("BRING EVERYTHING"), a bomb,
the Sherman driven in its orbit view ("TAKE THE STEEL"), its 75 mm firing, alongside the rolling tank, the Rocket Man
machine, the V2 from ignition to climb ("WATCH THE SKY"), its lift-off from the track mouth. Music B (the drop at 40 s):
the horse at a gallop and from the saddle ("RIDE"), the watchtower zip line, the Kaltenbrunn headframe zip line, the
Sherman rolling through Kaltenbrunn's gate, the dead on the U-boat pier, the pen from the tower, der Kranich's wing in
the golden hour ("FOUR FRONTS. ONE NIGHT THAT NEVER ENDS."), the bomb bay, a casing falling to a violet flash, the Earth
over the Moon, a meteor, das Totenross rearing, the Cousins in the taproom. Montage of half-second cuts, black,
GRAVELIGHT (solo or co-op, four maps, round after round), "Every round is a signature."
