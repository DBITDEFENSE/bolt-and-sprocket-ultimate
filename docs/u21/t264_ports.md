# T-264: macOS and SteamOS (Linux, handheld) builds

Branch `claude/ports-mac-steamos`, 2026-11-23. The owner: "we need to make this playable on macOS SteamOS."

**In one paragraph.** The game now exports for Linux x86_64 and for macOS (universal), from this Windows PC, with
one script each. The Linux build was run under WSL: it boots, reaches the main menu, loads Map 0 and plays, headless
and rendered with Vulkan (Forward+, software GPU), and quits cleanly. The macOS build could only be inspected, not
run: nobody has started it on a Mac yet. Three things found on the way would have stopped a player and are fixed:
the macOS app could not start at all (the "&" in the project name broke its Info.plist), a controller could move
through the menus but not press anything (A and B were not bound to the menus' confirm / back), and every exported
build crashed on the way out when quitting. What is still unknown is everything only real hardware shows: the
frame rate on a Deck and on a Mac, Metal, and whether macOS lets the unsigned app through with the steps below.

## 1. How to build

All three from the repo root in Git Bash; each needs the Godot 4.7.2 export templates (installed on this PC).

| Build | Command | Result |
| --- | --- | --- |
| Linux / SteamOS | `tools/build_linux.sh` | `build/ClaudeZombies_<version>_linux.tar.gz` (folder with `ClaudeZombies.x86_64`, the WebRTC `.so`, `start.sh`) |
| macOS | `tools/build_macos.sh` | `build/ClaudeZombies_<version>_macos.zip` (holds `CLAUDE ZOMBIES.app`) |
| Windows | `tools/build_windows.sh` (unchanged) | `build/ClaudeZombies_<version>.zip` |

Measured here, 2026-11-23, with nothing else exporting: Linux 2 min 12 s, binary 1.15 GB (the pack is inside it),
tar.gz 873 MB. macOS 2 min 20 s, zip 901 MB (executable 171 MB for both architectures, pack 1.08 GB). Windows
1 min 58 s, exe 1.19 GB, zip 882 MB.

- **Linux executable bit.** Windows file systems have none. `build_linux.sh` writes the tar.gz with Python's
  `tarfile` and sets mode 0755 on the binary and `start.sh` itself, then reads the archive back and fails if the
  bit is missing. Unpack with `tar xzf`; do not re-pack it as a zip on Windows.
- **macOS zip.** Godot writes the zip itself and keeps the executable bit (checked: mode 0755 on the binary).
  Do not unzip and re-zip it on Windows: that loses the bit and breaks the signature's seal.
- `tools/check_macos_build.py <zip>` reads the archive without a Mac (Info.plist, both architectures, minimum
  macOS per slice, signature, pack, frameworks). `build_macos.sh` runs it and fails on a problem. It is what found
  the broken Info.plist.

### Export presets (`export_presets.cfg`)

- **Linux** (preset 2): x86_64, pack embedded, S3TC / BPTC textures, the Windows preset's include / exclude filters
  unchanged, custom feature `cz_direct`.
- **macOS** (preset 3): universal (arm64 + x86_64), the same filters, custom feature `cz_direct`, bundle identifier
  `org.claudezombies.termsandconditions` (no personal name in it; change it before any store release, it must then
  stay fixed), category Action games, minimum macOS 11.0 on both architectures, high-resolution (Retina) capable,
  version 0.0.1 (the project's `0.0.1-m0` is not a legal macOS version string), ad-hoc signed.
- **Windows** (preset 0): not changed at all (`git diff master -- export_presets.cfg` only adds presets 2 and 3).

### Signing on macOS: what is possible from Windows

Godot 4.7.2 offers `codesign/codesign` = 0 off, 1 built-in (ad-hoc only), 2 rcodesign, 3 Xcode's codesign (macOS
only). Without an Apple Developer ID certificate only the ad-hoc signature is possible, on any host. Chosen: **1,
built-in ad-hoc**. Apple silicon refuses to run arm64 code with no signature at all, so "none" is not an option.
The archive check confirms both slices carry an ad-hoc signature with our identifier and the bundle is sealed
(`_CodeSignature/CodeResources`). It is **not notarized** (that needs a paid Apple developer account, a Developer
ID certificate and `rcodesign` or a Mac), so Gatekeeper stops a downloaded copy until the steps in section 6.
Library validation is disabled in the entitlements because the WebRTC framework inside the app is signed by
someone else (Godot's documentation asks for this with GDExtensions and ad-hoc signing).

### What Macs get

- **Apple silicon** (M1 and later, macOS 11+): the arm64 slice, Godot's own Metal driver, Forward+.
- **Intel Macs**: the x86_64 slice. It links Metal but not MetalFX / MetalKit (read from the template's Mach-O
  headers), i.e. it renders through Vulkan on MoltenVK, Forward+. The engine's own floor for that slice is macOS
  10.13; ours is 11.0 because the WebRTC framework states 11.0. Intel Macs with Intel graphics get the Low preset
  and will be slow; this game on an Intel Mac is a courtesy, not a target. Not tested.

### Texture formats

- The macOS export **refuses** to run for arm64 / universal unless the project setting
  `rendering/textures/vram_compression/import_etc2_astc` is on ("Cannot export for universal or arm64 if ETC2 ASTC
  texture format is disabled"). So it is on now (`project.godot`).
- Cost, measured in this worktree: the re-import took **55 s** (headless `--import`), wrote 325 extra
  `.etc2.ctex` / `.astc.ctex` files, grew `.godot/imported` by about **370 MB** (1.49 to 1.85 GB) and rewrote the
  **325 committed `.import` files** of the VRAM-compressed textures (two more lines each). Only 329 textures use
  VRAM compression; the rest of the project is not touched.
- **The main checkout needs the same re-import after the merge**: about a minute, automatic the first time the
  editor opens the project, or `"$GODOT" --headless --audio-driver Dummy --path . --import`. Until then the game
  still starts (it reads the S3TC files it already has), and `git status` stays clean because the `.import` files
  come with the merge.
- Build size: none of it ships. The Windows and Linux presets export S3TC / BPTC only, and so does the macOS
  build: its pack was scanned and holds 646 `.s3tc.ctex` / 4 `.bptc.ctex` names and no ETC2 / ASTC one (Apple
  silicon Macs read BC textures; the exporter's own feature list for the preset is `s3tc, bptc`). The setting is a
  toll the exporter asks for, not data the Mac build uses.

## 2. The render thread (what Play.bat's `--render-thread separate` does)

**Chosen: no exported build turns it on by itself; it is a launch option.** I first switched it on for the Linux
and Windows builds and took it out again on the evidence below.

How it can be had:

- any build: the launch option `--render-thread separate` (Linux: `./start.sh fast`; macOS:
  `open "CLAUDE ZOMBIES.app" --args --render-thread separate`; Deck: put `fast` in the shortcut's launch options);
- per preset: `project.godot` has `rendering/driver/threads/thread_model.cz_render_thread=2`. A project setting
  with a feature suffix applies only in builds that carry that feature, so adding `cz_render_thread` to a preset's
  custom features makes that build start with the separate thread (checked: a Linux build exported that way
  logged `render thread separate`). No preset carries it now.

Why not by default (the Linux build under WSL, Vulkan Forward+ on the software GPU, Map 0, Handheld preset):

| | separate thread | default (safe) |
| --- | --- | --- |
| Menu, rendered | runs, exit 0; 3 `_texture_2d_update: image is null or empty`, 1 `finalize can only be called from the render thread` | not run separately |
| Map 0, rendered, then quit | plays; 4 `_texture_2d_update` errors; **the process never exits**: 150 s after the game printed its last line every thread was asleep, I had to kill it | plays, 0 error lines, exit 0 |
| Map 0, headless | PASS; one `Parameter "material" is null` (an earlier build: `Parameter "m" is null` x3, `Condition "!F"` x5) | PASS, 0 error lines |

The engine itself says at every start with it: "The separate rendering thread feature is experimental ... can lead
to project crashes or instability". A build that hangs on quit would have to be force-closed on a Deck. A software
GPU is not a Deck or a 5090, so this may not happen on real hardware: T-258's 66 to 92 FPS on the owner's PC
stands, and Play.bat is unchanged. **Worth checking on the owner's PC**: after quitting from a match started with
Play.bat, is a Godot process left in Task Manager? If not, and a Deck run with `fast` quits cleanly too, the tag
can go back into the Windows and Linux presets (one word each).

## 3. Quality defaults (`gravelight/autoload/settings.gd`)

First launch only (no saved graphics preset). A saved choice is never touched; `test_graphics_presets` covers it.

- **Handheld preset** (new, in the menu between Low and Medium): FXAA, 100 % render scale with no upscaler, Low
  shadows (4 shadow views), Low AO, no bounce light / SSIL / SSR, **Low volumetric fog kept** (the maps' look hangs
  on it), Low level of detail. Reasoning: 1280x800 is about the pixel count Low draws on a 1080p monitor
  (1080 x 0.75), so the GPU budget goes to fog instead of upscaling; everything that costs CPU draw calls is at
  Low because the frame is CPU-bound (T-258) and the Deck has four Zen 2 cores.
- **Deck detection**: the environment variable `SteamDeck=1` (set by its client for every game it starts, in game
  mode and desktop mode; community-documented, not in Valve's public API docs), or the adapter name. Looked up:
  the LCD model reports `AMD Custom GPU 0405 (RADV VANGOGH)`, the OLED model `AMD Custom GPU 0932 (RADV VANGOGH)`.
  Both say VANGOGH; "sephiroth" and "galileo" are the OLED chip's and board's code names and I found no report
  of a driver printing them. They are in the match list anyway (harmless).
- **Handheld frame cap**: V-Sync on and a cap that divides the panel's refresh: 60 on a 60 Hz panel, 45 on the
  90 Hz OLED. Only written when the shared settings file does not exist yet. The Frame cap menu gained 30 / 40 /
  45 / 90. The Deck's own limiter (the "..." menu) still works on top.
- **Handheld small text**: first launch sets "Small text" to 15 (see section 4).
- **Apple silicon**: was "low" (every integrated GPU). Now by chip tier from the adapter name Metal reports:
  base M-chips and Pro: Medium; Max / Ultra: High. And a **3D resolution limit** (new setting, Video tab): the 3D
  picture is drawn at most N lines high and upscaled, the menus and the HUD stay at the panel's full resolution.
  First launch: 900 lines on a base chip, 1200 on a Pro, 1440 on a Max / Ultra; "Off" everywhere else. It follows
  the window: fullscreen on a 5K display lowers the scale, a small window raises it back. The UI needs no scale of
  its own on Retina (the project stretches a 1920x1080 canvas to the window).
  These tiers are a judgement from the chips' class, **not measured on any Mac**.
- `detect_preset` is still a pure static function (a fourth, optional argument `steam_deck`); `apple_tier`,
  `is_deck_adapter`, `detect_max_lines`, `effective_scale`, `handheld_frame_cap` are pure too and tested.
- One log line at every start, e.g.
  `[GLSettings] Linux 24.04 | 16 threads | llvmpipe (...) (type 4, 1.4.318) | vulkan forward_plus | render thread safe | window (1280, 800), screen (1280, 800) x1.00 ... | preset low, 3D limit 0`:
  ask a tester for it.

### Forward+ or Mobile on the Deck? Recommendation: stay on Forward+, measure first

Nothing was switched. What the Mobile renderer would cost, from reading the code:

- no volumetric fog and no FogVolumes (12 files turn the fog on, 11 files place fog volumes; `WebProfile` replaces
  them with depth fog, but only on the Compatibility renderer);
- no SSAO, SSIL, SSR, SDFGI (Handheld already has the last three off; AO would go);
- a cap of 8 omni + 8 spot lights per mesh, on maps built from large batched static meshes and lit by many lamps
  (114 files create omni lights): the same kind of cap that blacks out rooms on the Compatibility renderer and is
  the reason for the git-ignored `override.cfg`;
- no TAA / FSR2 (not used by Handheld), MSAA and FXAA stay.

So Mobile is not a free switch: it needs its own profile like the web one. If the Deck measures too slow on
Forward+ with Handheld, the cheap experiment is the launch option `--rendering-method mobile` on the device, then
decide. The likelier limit on the Deck is the CPU (the game tick is 8 to 9 ms on the owner's desktop CPU), which
no renderer changes: that is T-265's work.

## 4. Controller-only play

Found by reading every menu, then pinned with a new headless smoke that uses real joypad events only
(`gravelight/tools_src/smoke_menus_pad.tscn`; `tools/run_smokes.sh .smoke_logs/x menus` runs it with the old one).

Fixed:

- **A and B did nothing in menus.** In this project the engine's `ui_accept` is Enter / Space and `ui_cancel` is
  Escape only; the D-pad and stick moved the focus, but no pad button confirmed or went back. The old menu smoke
  did not see it because it sends action events. `GLSettings.ensure_pad_ui_actions()` binds A and B at start, for
  every mode of the game. (Space is also jump and Escape is also pause, in the same way A is jump and B is crouch,
  so nothing new can fire in a match.)
- **Text fields** (display name, join code, LAN address): letter keys appear under the field when a controller is
  in use or on a Deck (`MenuKit.pad_keys`): the join code's own alphabet, digits and `.` `:` for an address. The
  Deck's system keyboard (STEAM + X) also works in any field.
- **Focus thrown to the top** on every rebuild (the lobby list refreshes every 5 s; every toggle in Muster,
  Settings > Video, squad setup): `MenuScreen.rebuild()` keeps the focused control's place and the scroll while
  the sub-page is the same, and leaves focus alone when it sits outside the content.
- **Credits and the Service Record** opened scrolled to the bottom and could not be scrolled: they open at the
  top, and the right stick scrolls any menu page.
- **Rebinding** could not be left without Esc: the wait ends by itself after 6 s, and pad B cancels a keyboard
  wait.
- The **Kündigung end screen**'s only button never had the focus: it has it now.
- The pause header said "Escape resumes" with a controller in hand: it names the pad's button.
- **Small text** (new setting, Accessibility tab): no menu / HUD text below 15 or 18. At 1280x800 the UI is drawn
  at 0.667 scale, so the type scale's 13 is 8.7 real pixels and 15 is 10. Handheld's first launch picks 15
  (10 px); 18 gives 12 px but was not checked for overflow. (Valve's public Deck recommendations page gives no
  number for text size; the two steps are my choice.) It
  works through `MenuKit.size()` / `px()`; about 30 places set a font size by hand and are not reached (smallest:
  12 in the squad wheel, 13 / 14 on the pause map and objectives).

Not fixed (listed for the owner / a follow-up):

- The **pause menu opens on the MAP tab**, whose view takes A / B / Y and the D-pad for the map cursor; START
  resumes and LB / RB change tabs, so nothing is unreachable, but A on "Resume" does nothing while the map tab is
  open. The map's stick cursor reads controller 0 only.
- **Prompt labels are raw**: "LEFT SHOULDER", "TRIGGER RIGHT+", "X". Readable, but not glyphs and not the short
  names (LB, RT) the Settings screen uses. Left alone because prompts were not to change in this task.
- Hard-coded keyboard hints in a few overlays ("[Esc/C] leave" on the radio dial and switchboard, "arrows / wheel
  scroll" on the readers, "[1] / [2]" on Peg's choice, the pause map's mouse help, "Press the VISOR key"): the
  actions behind them do work on a pad (B / crouch leaves, A confirms).
- No pad binding by default for lean, weapon 1-3, visor, bot mode (all 14 buttons are taken); rebindable.
- Tooltips (bot perk tiers, the Bot AI explanation) are mouse-only.
- The old hub's Forge screen opens with nothing focused. Exported builds start in CLAUDE ZOMBIES (`cz_direct`)
  and never show the hub first.
- Archive / Dossier long texts: the right stick scrolls the page now, not verified with the longest entries.

## 5. Platform audit: what was found

| Area | Finding | Done |
| --- | --- | --- |
| macOS app name | `TERMS & CONDITIONS` was written into Info.plist unescaped: invalid XML, the app cannot start | `config/name.macos="CLAUDE ZOMBIES"` in `project.godot` (app, window title and user folder on macOS) |
| Quit | Every exported (release) build crashed on the way out ("Pages in use exist at exit", "double free", exit 134 / 139; the Nov 8 Windows exe exits 127). Static caches of meshes / models outlive the rendering server | `ExitSweep` empties the scripts' static caches as the tree goes down. Linux build: exit 0 |
| Case of paths | none wrong (every `res://` path and repo-relative path in scripts, scenes, resources, shaders and JSON: more than 10,000) | `test_path_case.gd` keeps it so |
| GDExtension | one: `addons/webrtc` (webrtc-native 1.2.2), Windows + Linux x86_64 only: the Mac build had no online play | the macOS universal frameworks from the same release added (LFS), `.gdextension` extended. Unverified on a Mac |
| Windows-only code in the shipped game | none that stops a start: no `OS.get_name()` branches, no registry, no `.exe` paths outside the dev launcher (not reachable from the game) | - |
| Local-model bot (Ollama) | autostart only knew the Windows install path; HTTP to 127.0.0.1, async, falls back to the built-in planner | Unix / Homebrew / app-bundle paths added to `bots.json`. On Unix a missing binary still costs ~15 s of probing before it falls back (no stall, async) |
| Text-to-speech | only Bolt & Sprocket lines without a recording; nothing waits on it; an empty voice list was cached for the session; the language test could never match | empty lists are asked again, `en_US` matches `en-us`. Without speech-dispatcher on Linux those lines are silent (subtitles still show) |
| Fullscreen switch | Gravelight's switch did not save: the next start undid it | writes the shared `windowMode` |
| `--frame-log` | wrote to `res://logs`, which an exported build does not have | `user://logs` in exported builds |
| Networking | ENet direct IP (UDP 24785) and WebRTC + HTTPS lobbies; nothing platform-bound; packets are packed little-endian by Godot on every platform; no file paths with OS separators are sent | - |
| `user://` | Linux `~/.local/share/godot/app_userdata/TERMS & CONDITIONS/`, macOS `~/Library/Application Support/Godot/app_userdata/CLAUDE ZOMBIES/`; all paths are forward-slash constants | - |
| Window mode | default "borderless" = fullscreen. On macOS that is the native fullscreen Space (animates at each start); the system keeps a fullscreen app below the notch by default | not changed, not seen |
| Shaders | the menu and all seven maps load and draw on Vulkan Forward+ (Mesa lavapipe) with no shader error in any log (section 7). lavapipe is not RADV: a driver-specific rejection on the Deck would not show here | Metal cannot be tested here |

Left open on purpose (each is a decision or needs a device):

- **Mouse sensitivity depends on the window size.** Look reads `InputEventMouseMotion.relative`, which the
  1920x1080 canvas stretch scales: the same hand movement turns about 1.35x further at 1280x800 than at 1080p and
  less on a 4K / Retina window. `screen_relative` would fix it but changes how the mouse feels for anyone not at
  1080p (the owner's 1440p included), so it was not touched. On a Deck this affects the trackpads and gyro-as-mouse.
- **macOS: Ctrl + click is a right click** on a Mac. Ctrl is the scoreboard key in Gravelight and crouch in Bolt &
  Sprocket: holding it while firing will aim instead. Rebindable; a Mac default binding set would be cleaner.
  `ping` is middle-mouse only and F6 (bot mode) is a media key on Mac keyboards.
- **No version handshake** between host and client. A Windows host and a Mac / Linux client must run builds of
  the same commit, or they desync without a message.
- **Online lobbies on the Deck**: the WebRTC `.so` loaded under Ubuntu 24.04 (WSL); SteamOS's runtime was not tried.

## 6. Installing and starting

### Deck / SteamOS / any Linux

1. Copy `ClaudeZombies_<version>_linux.tar.gz` to the device (desktop mode: browser download, USB stick, or
   `scp`). Unpack: `tar xzf ClaudeZombies_*_linux.tar.gz` (Dolphin's "Extract here" also keeps the bit).
2. From a terminal (Konsole): `cd ClaudeZombies_*/ && ./start.sh`. The log is `game_last.log` next to it.
3. For game mode: in desktop mode open Steam > Games > "Add a Non-Steam Game to My Library" > Browse > pick
   `start.sh` (or `ClaudeZombies.x86_64`). Leave "Force the use of a compatibility tool" **off** (it is a native
   Linux build, no Proton). Return to game mode; it is under Library > Non-Steam.
4. To try the separate render thread (section 2): `./start.sh fast`, or `fast` as the shortcut's launch option.
   Then quit from a match and see that the game really closes.

Test first on the Deck: (1) it starts and the menu shows; (2) the D-pad moves, A confirms, B goes back; (3)
Settings > Video shows "Handheld" and Frame cap 60 (LCD) or 45 (OLED); (4) a solo match on Map 0 to round 5:
frame rate (the Deck's overlay, level 2) and whether the fog and lamps look right; (5) round 12+ with bots: the
frame rate there is the real question; (6) text size in the pause menu and on the HUD; (7) quit from the menu:
back to the library with no error; (8) Online > Join by code with the on-screen letters.

### macOS

1. Copy `ClaudeZombies_<version>_macos.zip` to the Mac and double-click it (Archive Utility). Move
   `CLAUDE ZOMBIES.app` to `/Applications` (from Downloads, macOS runs a quarantined app from a random read-only
   path).
2. Clear the quarantine flag (the build is ad-hoc signed and not notarized). Terminal:
   `xattr -dr com.apple.quarantine "/Applications/CLAUDE ZOMBIES.app"`
3. Open it. If macOS still refuses: System Settings > Privacy & Security, scroll to the line about CLAUDE ZOMBIES
   being blocked, "Open Anyway". (Godot's documentation also gives right-click the app > Open > Open; as far as I
   know macOS 15 no longer offers that, not re-checked.) If it says the app "is damaged": step 2 was skipped, or
   the zip was re-packed on Windows.
4. The log: `~/Library/Application Support/Godot/app_userdata/CLAUDE ZOMBIES/logs/godot.log`.
5. To try the separate render thread: `open "/Applications/CLAUDE ZOMBIES.app" --args --render-thread separate`.

Test first on the Mac: (1) does it open at all (this build has never run); (2) the `[GLSettings]` line in the log
(adapter name, `metal`, preset, 3D limit); (3) the menu scene and Map 0: missing or black textures would mean the
texture-format reading above is wrong; (4) fullscreen on the built-in display: frame rate, and whether the 3D
limit looks acceptable; (5) mouse look speed in a window against fullscreen; (6) quit with Cmd+Q: no "quit
unexpectedly" dialog; (7) Online: the lobby page opens without "needs WebRTC"; (8) a co-op match against the
Windows build of the same commit (LAN page, port 24785 UDP).

## 7. Verified, and how

Runs behind every line; logs under `.smoke_logs/t264/` (Windows) and in WSL `~/t264/` (not kept in the repo).
"Earlier build" = the same code exported with the separate render thread on (section 2), before it was taken out.

| What | Command (short) | Result |
| --- | --- | --- |
| Script check | `check_scripts.gd` | checked 977 scripts, 0 failed |
| Unit tests | full GUT, twice | 2473 tests (13 new). First run: 2472 passing, 1 risky (the known `test_neural_lines_are_loudness_normalised`). Second run, on the final code with three other workers loading the PC: 2471 passing, the same risky one, and 1 failure in `test_npc_life.test_warm_hands_meet_under_the_chin` (an NPC idle pose after 4 simulated seconds; not code this task touches); run alone afterwards it passed 3 times of 3 |
| Smokes (run twice, the second time on the final code) | `run_smokes.sh .smoke_logs/t264 menus` and `... map00` | `smoke_menus`, `smoke_menus_pad` (69 checks), `smoke_map00`, `smoke_map00_alive`, `smoke_map00_cellar_bay`, `smoke_map00_loop`: all PASS, 0 script errors |
| Linux build as committed, headless boot (WSL, Ubuntu 24.04) | `./ClaudeZombies.x86_64 --headless --audio-driver Dummy --quit-after 120` | exit 0 in 6 to 12 s (the menu scene's first frame 1.6 to 3.0 s after start), 0 error lines |
| Linux build as committed, Map 0 headless | `... -- --probe-campaign --solo --direct --seconds=30` | `RESULT PASS (alive at 30 s)`, exit 0, 0 error lines |
| Linux build as committed, rendered menu | `xvfb-run -a -s "-screen 0 1280x800x24" ./ClaudeZombies.x86_64 --rendering-driver vulkan --audio-driver Dummy --resolution 1280x800 --quit-after 300` | `Vulkan 1.4.318 - Forward+ - llvmpipe`, `render thread safe`, first launch picked Low for the software GPU, the menu scene drew, exit 0 after 298 s (300 software-rendered frames), **0 error lines** |
| Linux build as committed, Map 0 rendered on Vulkan | the same with `-- --probe-campaign --solo --direct --seconds=40 --set=graphics_preset:handheld` | Handheld preset in use (`gi=false ssil=false fog=low`), `RESULT PASS`, exit 0 after 160 s, **0 error lines**, no shader error |
| Windows build as committed | `tools/build_windows.sh`, then the exe `--headless` | exports; menu boot exit 0; Map 0 probe `RESULT PASS`, exit 0, 0 error lines |
| Linux build, rendered menu (earlier build, separate thread) | `xvfb-run ... --rendering-driver vulkan --resolution 1280x800 --quit-after 300` | `Vulkan 1.4.318 - Forward+ - llvmpipe`, first launch picked Low for the software GPU, the menu scene drew, exit 0 after 264 s (300 software-rendered frames), no shader error; the four error lines of section 2 |
| Linux build, Map 0 rendered on Vulkan (earlier build) | `... -- --probe-campaign --solo --direct --seconds=40 --set=graphics_preset:handheld` | default thread (`--render-thread safe`): `RESULT PASS`, **0 error lines, exit 0**, 109 s. Separate thread: `RESULT PASS`, 4 texture errors, then the hang on quit |
| Every map on Vulkan Forward+ (the Linux editor binary on this branch, lavapipe, one after another) | `tools/wsl_perf.sh <map> handheld` (perf_marks, `--quick`) | all seven maps (Crossroads, Kaltenbrunn, Totenhafen, Thalbach, der Kranich, Groom Lake, Mondlicht) loaded and ran their marks in 500 to 731 s each: **0 shader errors, 0 script errors**. Each log has the same two engine lines while the scene is torn down (`BUG, indexing did not unpair geometries from light`), which T-258's logs on master already show |
| Quit | the runs above | exit 0 after the menu and after a match, Linux and Windows. Before `ExitSweep`: 134 / 139 (Linux), 127 / 139 (Windows) |
| macOS archive | `tools/check_macos_build.py` | `RESULT: ok`: Info.plist parses (name CLAUDE ZOMBIES, identifier, version 0.0.1, minimum 11.00 for both architectures, high-resolution capable), executable mode 0755 with an x86_64 slice (87.6 MB) and an arm64 slice (83.3 MB), both ad-hoc signed with our identifier, pack 1.08 GB, the WebRTC framework inside with both slices ad-hoc signed, `_CodeSignature/CodeResources` present. **Not run.** |
| Windows preset | `git diff master -- export_presets.cfg` | preset 0 and the Web preset untouched |
| Feature override | an earlier Linux build's log | `render thread separate` printed by the build itself when its preset carried `cz_render_thread` |
| ETC2 / ASTC re-import | `--import`, timed | 55 s, +370 MB of import cache, 325 `.import` files |

Side effect to know: the match probe starts the owner's local Ollama server when it is installed and not running
(the game's own autostart, unchanged); the later probes here ran with `--set=bot_local_ai:false`.

## 8. Not verified

- The macOS build has never been started. Unknown: Gatekeeper with the steps above, Metal, any Metal shader
  problem, the ad-hoc signature with the WebRTC framework inside (if that framework fails to load, online play
  says so and the rest of the game is unaffected), texture formats on Apple silicon, the notch, Retina sizes,
  Cmd / Ctrl behaviour, a controller on macOS.
- Nothing ran on a Deck: frame rate, RADV, gamescope, the Handheld preset's values, the 45 / 60 cap, text size on
  the 7 inch panel, `SteamDeck=1` and the adapter names (taken from published device reports, not seen).
- Apple silicon tiers and their 3D limits are estimates.
- Whether the separate render thread hangs on quit on a real GPU (it did on the software one, Linux).
- No rendered run of any Windows build (not allowed on this PC); the Windows export was booted and played headless.
- Maps other than Map 0 were not loaded in the exported Linux build under Vulkan the other six maps were loaded on Vulkan with the Linux editor binary instead, section 7.
- Cross-platform co-op (Windows host, Linux or Mac client) was not played. The transport and packet code have
  nothing platform-specific by reading; that is not a played match.
- 18-px "Largest" small text was not looked at for overflow.

## 9. Decisions the owner may want differently

1. No exported build uses the separate render thread by default (section 2); it is a launch option until a real
   GPU shows it quits cleanly.
2. macOS is named "CLAUDE ZOMBIES" (app, window, user folder), the other platforms keep "TERMS & CONDITIONS".
3. Bundle identifier `org.claudezombies.termsandconditions`.
4. Apple silicon: Medium / High with a 3D limit instead of Low; macOS minimum 11.0 on Intel too.
5. Handheld: fog kept, V-Sync on, cap 60 / 45, small text 15.
6. A and B are bound to the menus' confirm / back in every mode of the game.
7. `import_etc2_astc` on (a one-minute re-import in every checkout, 325 `.import` files changed).
8. The macOS WebRTC library was added to the repo (10 MB, LFS, MIT / MPL / BSD / Apache as listed in
   `addons/webrtc/SOURCE.txt`), downloaded from the project's GitHub release.
9. Mouse sensitivity was left as it is (see section 5).

## 10. For the other two tasks

- T-265 (CPU per frame): the Deck's limit will be the game tick; a headless Map 0 probe in the Linux build is a
  ready harness (`./ClaudeZombies.x86_64 --headless --audio-driver Dummy -- --probe-campaign --solo --direct`).
  Synchronous mesh / texture read-backs on the main thread (`surface_get_arrays`, `Texture.get_image()` in
  `zombie_body.gd`, `weapon_glb.gd`, `arms.gd`, `weapon_shader.gd`) stall the game thread until the render thread
  answers when the renderer runs separately.
- T-266 (render load): Handheld leans on the shadow budget's Low tier and Low detail range; if occlusion culling
  lands, the Deck benefits most. `project.godot`: my lines are one block at the end of `[rendering]` plus one line
  under `config/name`.
