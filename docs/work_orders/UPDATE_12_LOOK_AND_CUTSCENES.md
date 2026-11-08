# UPDATE 12 — "THE LOOK": ONE ART STYLE, ARCHIVE-REEL CUTSCENES, A MOCAP PIPELINE, AND A REAL GRAVELIGHT ONE

A work order for the `bolt-and-sprocket-ultimate` repo (TERMS & CONDITIONS / CLAUDE ZOMBIES, Godot 4). All earlier rules still apply:
- data-driven tuning, tests, smokes, a branch per section, `master` always launches;
- the `PROGRESS.md` resume line; `docs/DECISIONS.md` for every call;
- licensed assets only (`SOURCE.txt` + `LICENSE.txt`, the license gate);
- the respect rules from UPDATE 11 §8;
- **the Easter egg guard test from UPDATE 11 §2 stays green.**

**Runs fully unattended. Never pause, never ask me questions, never wait for approval.** Make every call yourself, log it, fix what you find, and keep going. Merge each section into `master` when its tests and smokes pass. If a step needs a file only I can download, do everything else, put the exact step in `morning/NEEDS_DEVIN.md`, and keep going with a stand-in so nothing waits on me. If a usage limit cuts the session, checkpoint `PROGRESS.md` so rerunning this prompt resumes instantly.

## 0. DO NOT STOP
I'm away until this is finished. **Do not end your turn, summarize, or wait for me** until every section is done, merged and pushed.
- **When a section finishes:** start the next one.
- **When something fails:** fix it or route around it, and log it.
- **When an item is blocked:** stub it, note it, and move on.
- **Your only stopping point** is §8 FINISH.

## ORDER
1. Read `PROGRESS.md`. **If UPDATE 11 isn't finished, finish it first.** This update dresses the story it writes.
2. Read `docs/CUTSCENES_LAZARUS.md`, the T-184 cinema library, `docs/gravelight/MAPS.md` (Map 0), and the GRAVELIGHT ONE wreck code and smokes (`smoke_wreck_pilot`, `smoke_wreck_collapse`).
3. In a cloud session, run `tools/cloud_setup.sh` first.

---

## HOW TO RUN THIS: the agent team
You (the main session, **Fable 5.1, effort High**) are the **lead**.
- **Your job:** write the art bible, judge every style frame, review every branch against its acceptance list, and merge.
- **Workers:** each gets its own worktree and branch (`u12-<sec>-<slug>`), at most ~4 at a time.

| Task | Model | Effort |
|---|---|---|
| §1 Art bible, per-map grades, style frames, blind look review | **Fable** (a separate reviewer for the blind review) | High |
| §2 Post-processing stack and material pass, every map | **Opus** | High |
| §3 Archive-reel pipeline (ffmpeg treatment, `.ogv`, the player, subtitles, narration) | **Opus** | High |
| §4 Mocap import and retarget pipeline, lip sync, the filming guide | **Opus** | High |
| §5 GRAVELIGHT ONE: the new C-47, its crash state, the cabin and cockpit | **Opus** | High |
| §6 Background aircraft pass | **Sonnet** | Medium |
| Asset intake, licenses, credits, LODs, minimap re-bakes, test and smoke upkeep | **Haiku** | Low |

**Review every branch yourself before merging:** run the tests and smokes, look at the captures, check the acceptance list. "The worker says it's done" is not done.

---

## 1. THE ART BIBLE: desaturated war-film realism
**The direction (decided; don't re-litigate it):** grim, stylized realism, closer to Black Ops 1 zombies than to modern photoreal.
- **Colour:** muted greys, browns and cold blues; heavy fog.
- **Accents:** **Nachtglas violet** is the only bright supernatural colour; **blood red** is the second accent.
- **Not:** photoreal (free assets can't reach it, and near-real faces fall into the uncanny valley).
- **Bolt & Sprocket and The Fine Print stay cartoon.** The contrast is part of the story.

**Write `docs/ART_BIBLE.md`:**
- the palette, with hex swatches;
- the value range for day, dusk and night;
- the fog density range;
- the grain, vignette and lens settings;
- the rules for violet and red (where they may appear and how much of the frame);
- material rules (roughness floor, no clean plastic, wear and dirt on everything);
- lighting rules (warm practical lamps against cold ambient, darker nights);
- a do/don't sheet with captured examples from our own maps.

**One grade per map** (a 3D LUT or `Environment` adjustment preset in `data/look/<map>.json`), applied to everything on that map, cutscenes included:

| Map | Grade |
|---|---|
| Crossroads Inn | frozen night: blue-grey, warm windows, orange fire glow from the wreck |
| Kaltenbrunn | salt white and sodium amber underground, cold steel on the surface |
| Totenhafen | storm green-grey, wet black concrete, red battle lanterns |
| Fernflug I (Thalbach) | industrial ochre and soot |
| Fernflug II (der Kranich) | dawn blue over cloud, cold aluminium inside |
| Fernflug III (Groom Lake) | bleached desert, dust brown |
| Fernflug IV (Mondlicht) | hard black and white, with violet as the only colour |
| Menu / prologue | the archive-reel black-and-white (§3) |

**Style frames first.** Before rolling a grade out, capture **one style frame per map** (same camera, before and after) into `docs/look/frames/`. Pick by the bible, log the choice, then roll out.

**Blind review:** at the end, a fresh Fable reviewer that has seen none of the work gets the before and after captures of every map and answers one question: *does it look like one game?* Fix what it flags.

## 2. THE SHARED LOOK: post stack and material pass
- **One post stack on every map:**
  - film grain;
  - vignette;
  - slight lens softness at the edges;
  - mild chromatic aberration at the frame edge only;
  - filmic tonemap;
  - volumetric fog (Forward+);
  - the per-map grade.

  It's data-driven, with a quality preset for the web build (the U09 §2d budget), and the existing graphics settings toggle each piece.
- **The material pass:** every material on every map against the bible.
  - Raise roughness on anything that reads as plastic.
  - Add a dirt or wear layer (a shared detail texture or triplanar grime) so assets from different artists sit together.
  - Desaturate albedo where it fights the palette.
  - Write a tool (`tools/look/material_audit`) that lists outliers.
- **Darker nights:** lower ambient, stronger practical lights, and keep readability; zombies and pickups stay readable.
- **Acceptance:**
  - before and after captures of every map and act;
  - FPS within the U09 §2d targets on the min-spec profile and in the web build;
  - the material audit is clean.

## 3. ARCHIVE-REEL CUTSCENES (the history scenes)
These are the 1930 church ("Lazarus Saturday"), the October 1944 release ("Fourth Day"), and the dust mill ("Staub"). **The shots are generated outside this repo** (I make them with Higgsfield in the Claude app) and dropped into `assets/user_supplied/cutscenes/<scene>/shot_<NN>.mp4`. Build everything around them:
1. **Shot prompts.** Write `docs/cutscenes/SHOT_PROMPTS.md`: for every shot in the three scenes' shot lists, a generation prompt, a duration (4–10 s) and a note on what it must show.
   - **Every prompt starts with the same style block:** *"Black-and-white 1930s/1940s archival film footage, heavy film grain, flicker, scratches and dust, hand-cranked camera judder, documentary realism"*.
   - **Content limits:** no on-screen violence, no real people, and no text in-frame (title cards are ours).
   - **Order:** keep it short enough that one scene is about 15–20 shots, ordered by priority.
2. **The treatment tool** (`tools/cinema/archive_reel.py`, ffmpeg) turns raw clips into the finished reel:
   - grade to black-and-white or sepia, matched across shots (histogram match to a reference frame);
   - grain, scratches, dust, gate weave and flicker, all deterministic per shot so re-renders match;
   - an aspect crop with a slight vignette;
   - **title cards** (Cyrillic or German with English subtitles, period typefaces under free licenses);
   - the ElevenLabs narration and ambience bed mixed in;
   - **output as Ogg Theora (`.ogv`) plus Vorbis**, the format Godot 4 plays natively (and in the web build), at 1080p and a 720p web variant.
3. **The player:** a `cinema_video` shot type in the T-184 cinema library.
   - **It plays a reel and keeps the rest of the cinema library's behaviour:** hold to skip, subtitles, co-op/online sync from the host, and the Gore setting.
   - **It mixes video and in-engine shots in one scene,** so a reel can cut straight into gameplay.
4. **Stand-ins so nothing waits on me:** until a shot file exists, the scene renders that shot **in-engine**, through the same treatment as a shader on the cinema camera, or as a still with a slow push. When the file arrives, the build picks it up with no code change.
5. **Licensing:** each clip folder gets a `SOURCE.txt` (the tool, the model, the date and my account) and a `LICENSE.txt` noting the plan's commercial-use terms. If the terms aren't confirmed, put one line in `NEEDS_DEVIN.md` asking me to check them.
6. **Tests and smokes:**
   - the treatment is deterministic (same input → same hash);
   - every scene plays end to end with stand-ins and with real clips;
   - skip and subtitles;
   - online sync;
   - the web build plays the `.ogv`.

## 4. IN-ENGINE SCENES WITH MOTION CAPTURE (the squad scenes)
The squad's scenes (the new GRAVELIGHT ONE crash, the Kaltenbrunn ending, Fernflug's acts) stay in the engine. **What holds them back is the animation, so build the pipeline for phone motion capture of me and my friends:**
1. **The filming guide:** `docs/MOCAP_GUIDE.md` covers every in-engine cutscene, shot by shot, written for non-actors with a phone:
   - who plays which character, and their marks (tape on the floor, distances in metres);
   - the camera spot, what each person does, how long it lasts, and the props to stand in;
   - the line they say (so the lip sync and the ElevenLabs take match the timing).

   Also include a one-page "how to film it" (landscape, whole body in frame, steady phone, plain clothes, good light, one take per shot) and which free apps to run the video through (Rokoko Vision, DeepMotion, QuickMagic: check each one's current free tier and export formats).
2. **Intake:** files dropped into `assets/user_supplied/mocap/<scene>/<shot>_<character>.fbx` (or `.bvh`) are found automatically. The pipeline:
   - retargets them onto our character rigs (the humanoid rig the squad uses);
   - fixes foot sliding with foot locks and smooths jitter;
   - trims to the shot;
   - writes Godot animation resources.

   Provide a dry-run report listing what's missing per scene.
3. **Lip sync:** generate mouth shapes from each ElevenLabs line with **Rhubarb Lip Sync** (free, MIT), mapped to our faces' blend shapes or jaw bone. If a head has no blend shapes, use the jaw-and-brow fallback.
4. **Stand-ins:** until a mocap file exists, the shot uses the current stand-in animation, so nothing breaks.
5. **Tests:** retarget a sample clip end to end, foot lock, the missing-file report, and lip-sync timing against the audio length.

## 5. GRAVELIGHT ONE: A BETTER PLANE ON MAP 1 (CROSSROADS INN)
The crashed C-47 is the hero landmark of the first map (THE BAR row 4), and it has to look the part. **Replace it with a real model** and keep every interaction exactly where it is.

### 5.1 The model
| Use | Asset | License | Notes |
|---|---|---|---|
| **The main model** | [C47 by manilov.ap](https://sketchfab.com/3d-models/c47-c4fb0f24d55f4866a9669aa952dceaf3) | CC-BY 4.0 (credit the artist) | 20k faces: game weight, and the best-liked free C-47 on Sketchfab |
| **Detail reference, or an alternative** | [Douglas C-47B Dakota IV — KN645 by mgg8](https://sketchfab.com/3d-models/35da2958566f421593bcc2dac9c3b762) | CC0 | 187k faces, PBR; decimate for game use; useful for close-up parts (engines, props, gear) |
| Alternatives if those fail | [Douglas C-47 Skytrain by Spark_Customs](https://sketchfab.com/3d-models/bd01ee417416492f919a4b988f03bc8b), [Dc3 by manilov.ap](https://sketchfab.com/3d-models/1668ac86c20b4c3eb2a04d22959a87e1) | CC-BY | |

Sketchfab downloads need my login. **If the files aren't already in `assets/user_supplied/u12/c47/`:**
- put the download step in `NEEDS_DEVIN.md` (GLB format, one folder per model, with a `SOURCE.txt` of the page link);
- build everything below on a stand-in made from the current wreck;
- swap the real model in automatically when the files exist.

### 5.2 What to build
1. **Two versions from one source:**
   - **intact** (for the new in-flight crash cutscene from UPDATE 11 §5.4): exterior and cabin, spinning props, exhaust glow, formation lights;
   - **crashed** (the map set).
2. **The crash state**, modelled in Blender headless from the source mesh:
   - **The wings and engines:** the starboard wing sheared at the root and lying behind the fuselage; the port engine torn off its mount; prop blades bent backward.
   - **The fuselage:** the nose crushed into the frozen field; a split behind the wing; the tail broken up.
   - **The surface:** burned and scorched paint along the fuel line, torn skin with the stringers showing, and shattered glazing.
   - **The ground:** snow drifted against the windward side and a gouge in the field behind it.

   **Keep the layout the map already uses:** the cockpit with Selwyn, the cabin interior, the door, the burning section, and the collapse event (`smoke_wreck_collapse`).
3. **Markings:**
   - a period-correct, plausible C-47 from Brindisi flying special operations;
   - olive drab over neutral grey;
   - **a fictional tail code** and the name **GRAVELIGHT ONE** stencilled small near the nose;
   - Allied national markings are fine (the respect rule bans real Nazi symbols, not Allied ones).
4. **The cabin interior:**
   - bucket seats along both walls, static line, cargo straps, a supply crate;
   - wartime stencils, the navigator's table, the radio;
   - debris from the crash: seats torn loose, a parachute pack, frost on the windows;
   - **the dead co-pilot shown with care:** covered, not gore.
5. **The cockpit** (no free C-47 cockpit exists, so build it):
   - the instrument panel from reference photos, the yokes, the throttle quadrant;
   - the crushed frame pinning **Selwyn** exactly where the current interaction expects him.

   Use the B-29 cockpit (CC-BY, Ulysse Cambier) only as a texture and lighting reference, not as geometry.
6. **Life around it:**
   - the fuel fire (the existing system) with heat haze;
   - smoke drifting with the map's wind;
   - sparks;
   - creaking metal sounds;
   - the collapse event re-staged on the new geometry.
7. **Performance:** LOD0–LOD2 plus an impostor for the far view from the inn, collision hulls that match the art (the T-188 ArtCollider rule), and a re-baked navmesh around it. Stay within the frame budget.
8. **Don't break anything:**
   - Selwyn's rescue (`smoke_wreck_pilot`), the collapse (`smoke_wreck_collapse`), every egg and side-quest interaction near the wreck, the minimap marker and the bot routes all keep working;
   - **the egg guard test stays green**;
   - re-bake the minimap.
9. **Acceptance:**
   - captures from the inn's front door, from the field, inside the cabin and inside the cockpit, before and after;
   - the smokes pass;
   - FPS within budget;
   - the credits screen lists the artist.

## 6. BACKGROUND AIRCRAFT (match the new story)
**After UPDATE 11, the war on Map 0's horizon is the Soviet front.** Audit the aircraft in the living world (bomber streams, fighter pairs, the plane shot down at round 6) and match them to the story.

**What should fly:**
- Soviet aircraft over the front (an Il-2 or Pe-2 class silhouette);
- German night fighters;
- **the plane shot down at round 6 becomes a Soviet aircraft** (log the call in `DECISIONS.md`).

**How to source them:** free CC-BY or CC0 models through the asset pipeline, as low-poly or impostor versions. Use generic silhouettes where no free model exists. No real Nazi insignia: use the fictional emblems.

Apply the same pass to Kaltenbrunn's sky (U10 §5).

## 7. TESTS AND SMOKES
- The egg guard test.
- Every map smoke and egg smoke.
- The cinema smokes (reels, stand-ins, skip, online).
- The mocap pipeline tests.
- The wreck smokes.
- The license gate (every new asset has `SOURCE.txt` and `LICENSE.txt`).
- The FPS gate on the min-spec profile and the web build.
- **The full unit suite and every smoke at FINISH.**

## 8. FINISH
- **Add `Play.bat` buttons:**
  - "Look test — every map's style frame"
  - "Cutscene — Lazarus Saturday (reel)"
  - "Cutscene — Fourth Day (reel)"
  - "Cutscene — Staub (reel)"
  - "Map 0 — GRAVELIGHT ONE crash intro"
  - "Map 0 — walk the wreck"
- **Merge to `master` and push.**
- **`morning/MORNING_REPORT.md`, written for a player:**
  - the before and after look of every map;
  - what to watch;
  - **the shot list still waiting for generated clips** (with the prompt file);
  - **the mocap filming guide in one paragraph** (what my friends and I need to film, and how long it takes);
  - anything not working.
- **`morning/NEEDS_DEVIN.md`:** the C-47 downloads (if missing), the Higgsfield commercial-terms check, and anything else that needs me.
- **Tell me the one line to paste into Claude Code on my PC to pull it.**
