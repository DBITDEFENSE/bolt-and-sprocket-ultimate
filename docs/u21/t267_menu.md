# T-267: the main menu and the match loading screen

Branch `claude/menu-rework`. The owner: "The menu needs work. It needs to have like better animations, and ... when
you're customizing your starting pistol, you need to be able to see the pistol. ... what the heck is muster? ... Let's
make it more mainstream ... cutscenes are for the campaign, but for the solo or whatever squad, have it loading in,
just have like a simple video of like 10 seconds, 20 seconds while it loads."

## 1. Plain names

Rule: the player reads the word every shooter uses; code identifiers, class names (`Muster`, `MenuMuster`,
`MenuArchive`, `MenuDossiers`), data files (`muster.json` "habits", `dossiers.json`), profile keys (`loadouts`,
`dossiers`, `prestige`, `equipped.m1911_finish`) and test names are unchanged, so every saved profile loads as before.
Where a page keeps an in-world word, a plain line stands next to it.

| Where | Old | New | Why |
|---|---|---|---|
| Main menu | Muster | **Loadout** | The owner's own example. "Loadout" is what the pause menu's tab already said. |
| Main menu | Archive (page title "Intel Archive") | **Collection** | A list of things you have found; "Intel" stays as the name of the items, explained in the page's subtitle. |
| Play column | Online | **Co-op** | It also holds the LAN page; "Co-op" says what it is, not how it connects. |
| Extras | Dossiers | **Characters** | The page is the four characters' files. |
| Extras | Service Record | **Stats** | Standard. |
| Extras | Test Range | **Shooting Range** | "Test" read as a developer tool. (The map's own in-match name stays "Test Range".) |
| Quit column | Terms & Conditions | **Game Select** | It leaves to the outer title screen; the old label read like a legal page. |
| Loadout | Sidearm | **Starting pistol** | The owner's words. |
| Loadout, game over, unlock lists | Field Habits / Field Habit slot | **Starting perks** / Starting perk slot | Mainstream word. "Starting" keeps them apart from the perk machines in a match (T-079 asked for that separation); the heading's plain line says so. |
| Loadout, Play, Characters, unlock text | Dossier level | **Character level** | Standard. |
| Loadout, Stats, footer | Commendation | **Prestige** | The button already had "(prestige)" in brackets. |
| Stats | Citations | **Achievements** | Standard. |
| Stats | Weapon mastery | **Weapon camos** | The section lists camos. |
| Stats | Scrip earned | Scrip earned **(match money)** | "Scrip" is the HUD's currency and stays; the menu says what it is. |
| Challenges | Challenges & Rewards | **Challenges** (subtitle explains the rewards) | Shorter title. |
| Play pages | "Choose your survivor" / "Campaign: choose your survivor" | **Solo** / **Campaign**, with a step line "STEP 1 OF 2 · CHOOSE YOUR CHARACTER" | The page is named after the mode; the step line says what to do. |
| Play step 2 | "Muster: ..." button | **"Loadout: ..."** | As above. |
| Play step 2 | "Back to survivors" (bottom) | **"Character: Dutch (change)"** (top row, first) | The choice you made, where you look first. |
| Play step 2 | Squad: just you / you + 1 bot | **Bots: none / 1 teammate ...** | "Squad" is also the co-op word. |
| Play step 2 | campaign card "ROUND 10 EXFIL, THEN 30" | **"LEAVE AT ROUND 10, THEN 30"** | "Exfil" explained in the paragraph under it ("the exfil beacon (your way out)"). |
| Map cards | BEST 23 | **BEST ROUND 23** | Best what. |
| Character traits | "+10 Scrip on headshot kills" | "+10 Scrip **(the money you spend in a match)** ..." | First place a new player meets the word. |
| Co-op | Create Lobby / Browse Lobbies / Join by Code / LAN (direct IP) | **Host a Game / Find a Game / Join with a Code / Local Network (LAN)** | Host / Join. |
| Co-op | "Lobby code", "Leave the lobby", "Close the lobby", "Creating the lobby...", "Your survivor" | **"Join code"**, "Leave the game", "Close the game", "Setting up your game...", "Your character" | Same vocabulary through the page. |
| Loading screen | FIELD NOTE | **TIP** | Standard. |
| Game over | THE LEDGER IS CLOSED | **GAME OVER** | The flavour line "The account is closed." is still typed under the table. |
| Game over | SURVIVOR (column) | **PLAYER** | Standard. |
| Game over | "X's dossier reached level N" | **"X reached character level N"** | As above. |
| Pause | FIELD MAP | **MAP** | As the tab is called. |
| Pause, objectives | Open in Archive | **Open in Collection** | Follows the page. |
| Pause map legend | Requisition Crate | Requisition Crate **(random weapon box)** | In-world name kept, plain words beside it. |
| Settings > Gameplay | "M1911" section: Finish, Loadout Pick | moved to the Loadout page: **Finish**, **Fitted attachment** | See section 2. |

Kept on purpose: **Scrip** (the HUD's currency, spoken in recorded lines; menus add "match money"), **Requisition
Crate**, the perk machines' names, **Intel** (items), **Easter Egg Mode** / "EGG DONE" on the map cards (the genre's own
word; the mode button's line says "a map's hidden quest"), **MARKE** on the game-over table (the bonus the HUD pays in
every match), **Classic Rules**, **Rank**, **XP**, **Calling cards**, **Emblems**, **Extras**.

Voice lines: no recorded line says "Muster", "Field Habit", "Dossier", "Service Record", "Commendation" or "Citation"
(see section 6 for the search), so no rename contradicts a take.

Every main-menu link also shows one plain line under the column while it has the focus (`LINK_HINTS` in
`main_menu.gd`: "LOADOUT: Choose your starting pistol and your starting perks."), and every page has a one-line
subtitle under its title (`MenuScreen.subtitle`).

## 2. Structure

The path is **Play > Solo / Co-op / Campaign > character > map (press = start)**.

| Confusing spot | What it was | Now |
|---|---|---|
| **Solo started the campaign** (the cutscene the owner saw) | The Solo page's first card, the one under the focus, was the CAMPAIGN card. "Solo, a character, accept" began the campaign: on a new profile the prologue, then FOURTH DAY and GRAVELIGHT ONE. | Solo shows the seven maps only; the first open map has the focus. The campaign is reached only through Play > Campaign, which shows just its card. |
| No sign of where you are | The page was titled "Choose your survivor" in both steps and both modes. | Titled "Solo" or "Campaign", with a step line: "STEP 1 OF 2 · CHOOSE YOUR CHARACTER", then "STEP 2 OF 2 · DUTCH · CHOOSE A MAP TO START". |
| Changing the character | A small "Back to survivors" button under two rows of cards. | The first button of the top row: "Character: Dutch (change)". Back / Esc / pad B does the same. |
| The character you played last | Step 1 always opened on Dutch. | Opens with the last played character under the focus. |
| The M1911's finish and attachment | In Settings > Gameplay, between the boss names and the minimap. | On the Loadout page under the M1911, shown on the 3D model. Settings > Gameplay has one line saying where they went. The pause menu's LOADOUT tab still has its rows (`MenuSettings.m1911_rows`). |
| The Loadout page | One long list: rank, a paragraph, tabs, four pistols as text with a stat line, twelve habits. | Rank and next unlocks in a fixed header; the list on the left (tabs, pistols, M1911 options, perks); a fixed panel on the right with the pistol in 3D, its name, state, four stat bars and its description. |
| Locked pistols | Disabled rows: a controller could not even land on them. | They take the focus, so you can look at what you will unlock; pressing says what unlocks them. |
| Toggling a perk or a bot | The page rebuilt and the focus jumped to the top. | The focus (and the scroll position) stay on the control you pressed (`MenuScreen.rebuild(keep_focus)`). |
| What the links mean | Six bare words. | Each link shows a plain line under the column while focused; each page has a subtitle. |

Every feature is still reachable: Cutscenes (Extras, and inside Collection), Characters, Stats, Challenges, Credits,
Shooting Range, Easter Egg Mode (step 2's bottom row), bots / bot skill / bot AI (step 2's top row), LAN, Quick Match,
rejoin, name change, the co-op campaign (the host's Campaign button in the room), Game Select, Quit to Desktop.

## 3. The pistol (and the character) on screen

`gravelight/ui/menu_model_view.gd` (`MenuModelView`, a SubViewportContainer):

- A SubViewport with **its own World3D** (`own_world_3d`, a fresh `World3D`), transparent background, MSAA 2x, three
  directional lights (warm key, cool fill, violet rim), a flat ambient colour, filmic tonemap. No sky, no shadows, no
  glow, no SDFGI / SSAO / SSR / volumetrics: the same picture on Forward+ and on Compatibility. It draws only while
  its container is visible (SubViewportContainer switches the viewport off when hidden) and is freed with the page:
  a closed screen costs nothing.
- **The model is the in-game one.** `show_weapon(id, finish, pick)` makes a `WeaponInstance`, applies
  `M1911Kit.apply_start` (the call `WeaponHolder` makes at a match start) and builds
  `WeaponModels.build(base_id, false, ProfileSave.camo_for(id), WeaponKitModels.look_of(w))`: the GLB (or the
  procedural Luger), the profile's camo, the M1911's finish and its fitted attachment.
- **Framing** by the upright cylinder the model's box sweeps as it turns (`bounds_of`, `fit_distance`): it fills
  90 % of the view, near side included, so nothing is clipped at any angle and nothing is tiny. (The first render
  framed by the bounding sphere: correct but the pistol took only 42 % of the width; now about 60 %.)
- **Turn**: a weapon swings 40 degrees either side of its side view, muzzle to the left, there and back in about
  11 s (`yaw_at`); it is never end-on (the first render's full turn showed a pistol as a sliver for two seconds of
  each turn). A character swings 34 degrees either side of facing you. With Reduce motion both stand still.
- **Swap**: the old model fades out in 0.09 s, the new one fades in over 0.16 s with a small scale-up. A second
  change during a swap cuts the first short.
- Loadout page: the focus (or the mouse) over a pistol row shows that pistol, also a locked one; the M1911's Finish
  and Fitted attachment buttons step through the unlocked choices and the model follows; the focus on a perk row
  shows the equipped pistol again.
- The Loadout's view is 636 x 340, the character view 496 x 560 (logical pixels of the 1920 x 1080 layout).
- Solo / Campaign step 1: the same view shows the character under the focus (`PersonRig`, standing,
  breathing) with their name, role and trait. The panel is hidden on step 2 (the cards need the width), and a hidden
  view draws nothing.

## 4. Motion

All of it is in `gravelight/ui/menu_motion.gd` (`MenuMotion`); `MenuKit.transition_in / transition_out` call it.

| What | Motion | Time |
|---|---|---|
| A page opens / closes, a main-menu column changes | cross-fade with a 24 px slide | 0.20 s in, 0.12 s out |
| The rows of a page (first open, a change of step) | fade in one after another | 0.022 s apart, the whole list inside 0.14 s, each 0.10 s |
| Any button (MenuKit.button / check / options): hover or focus | a soft highlight, an underline growing from the left, a quiet tick (`ui_tick` at -9 dB) on focus | 0.11 s |
| Any button: press | the highlight flashes and settles | 0.16 s |
| Main-menu link | (as before) slides right, blood glow, heartbeat throb; new: its plain line fades in under the column | 0.12 s |
| Map card: focus | the preview leans in inside its frame (x1.07), violet underline, the lit border and glow | 0.22 s |
| The 3D view | slow swing; fade-and-scale swap | 0.25 s swap |
| Loadout stat bars | slide to the new pistol's values | 0.18 s |
| Loading clip | fades in when its first frame is there; the screen leaves through black | 0.4 s / 0.35 s |

- Longest press-to-settled: 0.24 s (`MenuMotion.worst_case_s`, unit-tested to stay at or under 0.25 s).
- Input is never blocked: a control is focusable and pressable from its first frame; the feedback rects take no
  input. A second press simply acts (`MenuMotion.finish` ends a running motion at its end state).
- **Reduce motion** (new, Settings > Accessibility > Motion; `GLSettings.values["reduce_motion"]`, a plain bool in
  the settings defaults, not in the graphics presets): no slides, no stagger, no zoom, no pulse, the 3D views stand
  still, fades are 0.06 s.
- The backdrop was already alive (the 40 s dolly and the over-the-shoulder shot, the fire's flicker, the walkers,
  the Watcher's beats, the heartbeat vignette from T-243) and is unchanged.
- Container-safe by construction: only `modulate` is animated on controls that sit in containers; scale and position
  only on children that sit in none (a Container resets its children's scale when it sorts).

## 5. Loading into a match

**What played before.** A story cutscene in a non-campaign match came from one place: the Solo page's pre-focused
CAMPAIGN card (section 2). `LazarusCinema.plan` already plays nothing outside the campaign (T-203,
`cutscenes_lazarus.json` hooks, `standalone_rule: never`), and the campaign's hops (`ExfilCutscene`) need
`Campaign.active`. One more thing looked like a cutscene on the Crossroads Inn: the opening's letterbox, hidden HUD
and typed place card (T-184) for the first eight seconds.

**Now.**
- Solo has no campaign card. Story cutscenes are triggered where they were (`MapRoot.start_rounds` >
  `LazarusCinema.on_rounds_started`, `ExfilPoint`, the endings) and only with `Campaign.active`.
- The inn's letterbox title card shows in the campaign only (`InnOpening.card_wanted`). A Solo / Co-op match starts
  with the HUD up and the map's plain intro banner, as on the other maps. The opening itself (the patrons, the cue,
  round 1's timing and its zombie accounting) is untouched: gameplay values do not change.
- **The loading screen plays a clip** for a single-map match (`gravelight/ui/loading_clips.gd`, `LoadingClips`):
  one of `assets/video/loading/*.ogv` at random (not the one shown last time), full screen (cover, by the clip's own
  aspect) over the map's art and under the dark grade, the map name, lore line, tip and progress bar; muted; looping
  if the load is longer than the clip. The map still loads on its thread (`ResourceLoader.load_threaded_request`).
  The match starts when the map is in **and** 3.0 s have shown (`MIN_VIDEO_S`), through a 0.35 s fade to black;
  Enter / pad A skips what is left of the 3 s once the map is in.
- **No clip** (no folder, no `.ogv`, a file that is not Ogg, the browser build): no video node is created and the
  screen is what it was (1.2 s minimum, a straight cut). This is the state of the branch as committed: the
  placeholder is not in the repository.
- Not in the Campaign (its loads keep the art card and its transition lines), not on the endings' curtains, not in
  the browser build.
- Co-op: every peer picks and plays its own clip; nothing about it is sent.
- Clips are opened by path (`VideoStreamTheora.file`), so they need no import step; `export_presets.cfg` already
  includes `*.ogv`.

## 6. What is verified, and how

Renders are WSL + Xvfb (Mesa llvmpipe, the Compatibility renderer, 1280 x 720), never a window on the PC.
`docs/captures/t267/before/` is master c5d5b5e0 through `shots_menus.tscn`; `docs/captures/t267/after/` is this
branch through the new `gravelight/tools_src/shots_t267.tscn`. The tools save PNG; the committed copies are JPG (q90).

| Check | Result |
|---|---|
| Script check | 980 scripts, 0 failed |
| Unit tests (GUT), full | 2486 tests, 2485 passing, 1 risky (the known `test_neural_lines_are_loudness_normalised`); master was 2460, `test_menu_rework.gd` adds 26 |
| `smoke_match_start` (new, headless, cutscenes forced on) | PASS, 41 checks: Solo page has no campaign card; plain loading screen with no clip; no cutscene, no letterbox card, input free after a solo start; with the placeholder clip the clip plays, the screen leaves at 3 s or when the map is in; the campaign page has only its card, plays no clip, and still plays lazarus_saturday, fourth_day, gravelight_one |
| Map load time, headless, Crossroads Inn | two runs: cold without a clip 4.30 s / 5.40 s, with the clip playing 3.78 s / 3.99 s, warm without 3.84 s / 4.36 s: the clip does not slow the threaded load |
| `smoke_menus` | PASS (every link by keyboard actions only, 10 screens) |
| `smoke_coop`, `smoke_map00`, `smoke_map00_alive`, `smoke_map00_cellar_bay`, `smoke_map00_loop` | PASS |
| `smoke_campaign`, `smoke_cinema_lazarus`, `smoke_transitions` (7 hops), `smoke_inn_opening_paths` (7 cases; round 1 still starts at 11.6 s) | PASS |
| Voice lines | `data/gravelight/vo/lines.json` searched for Muster, Field Habit, Dossier, Service Record, Commendation, Citation, Archive, Lobby, Test Range: no line uses any of them as the menu's term (one line says "I'll write her a commendation", one "A sidearm. Last resort.", both ordinary speech). No clash. |

What the unit tests hold (`gravelight/tests/unit/test_menu_rework.gd`): no page reads an old name; titles and
subtitles; every main-menu link has a hint line; Solo has no campaign card and Campaign only that; a solo start is
no campaign and plans no cutscene on any map; the title card is the campaign's; **every sidearm** builds in the view,
is pistol-sized, is inside the frame at five points of its swing, takes more than 45 % of the view's width, and
opens side-on with its muzzle to the left; the view has its own world, no shadows, nothing Compatibility lacks, and
stops drawing when hidden; the M1911's finish and attachment make another model; every character has a body and
never turns their back; the Loadout previews on focus, refuses a locked pistol, equips an unlocked one; every pistol
and perk row is reachable with focus-down alone; **every page fits the screen** (see below); motion's worst case is
within 0.25 s; Reduce motion; feedback never blocks a press; the clip's rules; no clip file and a broken clip file
give the old loading screen.

Two things only the renders showed, both fixed:
- The first after-render had **every page taller than the screen** (the frame's bottom edge and the Back button's
  right edge were off-screen). Cause: the new subtitle was a word-wrapping label outside the page's scroll; before it
  knows its width such a label reports one word per line, the page (anchored to the screen) grew to fit and never
  shrank. The subtitle and the Loadout's "Next unlocks" line are single-line now, the Loadout's rows wrap inside the
  scroll, and `test_every_page_fits_the_screen` holds it.
- The pistol was framed by its bounding sphere and turned a full circle: correct, but small (42 % of the width) and
  a sliver when end-on. It is framed by its swept cylinder and swings about its side view now.

Renders to look at (`docs/captures/t267/`):
- `before/09_muster.jpg` against `after/07_loadout_open.jpg`, `after/07_loadout_m1911.jpg`,
  `07_loadout_walther_p38.jpg`, `07_loadout_webley.jpg`, `07_loadout_luger_p08.jpg`,
  `07_loadout_m1911_nickel_extended_mag.jpg`, `07_loadout_perks.jpg`
- each sidearm alone, at the side view and the two ends of its swing: `after/view_<pistol>_a|b|c.jpg`, plus
  `view_m1911_nickel_extended_mag.jpg`, `view_m1911_blued_checkered_grips.jpg`
- `before/04_map_select.jpg` (the campaign card first) against `after/05_solo_maps.jpg`,
  `05b_solo_maps_second_card_focus.jpg`; `after/04_solo_character_<id>.jpg` and `view_character_<id>.jpg`
- `before/05_campaign.jpg` / `after/06_campaign.jpg`
- `before/01_main.jpg`, `02_play.jpg`, `03_extras.jpg` / `after/01_main.jpg`, `01b_main_loadout_focus.jpg`,
  `02_play.jpg`, `03_extras.jpg`
- `before/10_archive.jpg`, `06_online_home.jpg`, `08_online_room.jpg` / `after/08_collection.jpg`,
  `13_coop_home.jpg`, `13b_coop_host.jpg`, `13c_coop_room.jpg`; `after/09_characters.jpg`, `10_stats.jpg`,
  `11_challenges.jpg`, `12_settings_accessibility.jpg`, `12b_settings_gameplay.jpg`
- `before/15_loading.jpg` / `after/14_loading_no_clip.jpg`, `15_loading_clip.jpg`, `15b_loading_clip_later.jpg`
- `before/16_pause.jpg`, `17_game_over.jpg` (the after pair of these two was not rendered: text changes only)

## 7. Not verified / for the owner's eye on a real GPU

- **The loading clip's picture.** In the WSL render the placeholder (ffmpeg `testsrc2`, 1280x720, 24 fps, Theora
  q6) shows blocks of broken picture in places. Software GL draws a few frames a second there, so the decoder is
  far behind real time; whether that is the cause, or the test pattern, is not established. It must be looked at at
  full frame rate with a real clip. If it shows there too, re-encode with a short keyframe distance
  (`ffmpeg ... -c:v libtheora -q:v 7 -g 12`).
- Whether a bright clip leaves the map name, the lore line and the tip readable: the grade under the text is the
  old one (dark from 35 % down). A dark, low-contrast clip will be fine; a bright one may want a stronger grade.
- The clip is muted. If the clips have sound the owner wants heard, it is one line (`video.volume_db`).
- All motion: timing and feel (the stagger, the hover highlight and underline, the card zoom, the model swap).
  Stills cannot show it; the numbers are in section 4.
- The 3D view on Forward+ (the renders are Compatibility). It uses nothing Forward-only, but it has not been drawn
  there. The MSAA 2x edge quality and the lights' balance want a look.
- The **Luger P08** is the game's procedural greybox (docs/WEAPON_MODELS.md lists it as having no model yet): the
  view shows exactly what the match puts in the hand, which is plainer and darker than the other three.
- A controller in the hand: focus order is tested by `find_valid_focus_neighbor` and the keyboard actions in
  `smoke_menus`, not with a pad; T-264's branch touches the same pages.
- The browser build (no clip by rule; the view uses nothing Compatibility lacks) was not built or run.
- A real co-op session (two machines each picking their own clip): the rule is local by construction and
  `smoke_coop` passes, but two peers with clips were not run.
- Pause menu and game-over wording after the change were not rendered (`before/16`, `before/17` exist).

## 8. Decisions the owner may want differently

- **Starting perks** for "Field Habits" (not just "Perks"), to keep them apart from the perk machines as T-079 asked.
- **Collection** for the Archive, **Characters** for Dossiers, **Game Select** for the way back to the outer title.
- "GAME OVER" replaced "THE LEDGER IS CLOSED" as the end screen's title (the typed "The account is closed." stays).
- The inn's letterbox title card is campaign-only now. The opening's ten-second hold before round 1 (the patrons,
  the pounding at the window) still happens in Solo: it is gameplay timing, which this task may not change. If that
  wait is also "a cutscene" to the owner, it is `map00_opening.json` `look.min_seconds` / `max_seconds`.
- The clip's minimum is 3 s and Enter / A skips it; it plays only for single-map matches, not in the Campaign.
- The pistol swings 40 degrees either side of its side view instead of turning a full circle.
- A locked pistol can be focused and looked at (it could not before).
- The M1911's Finish and Fitted attachment left Settings > Gameplay for the Loadout page.
- Map cards still say "EGG DONE / EGG NOT DONE / NO EGG" (the genre's word; no room on the card for more).
- Found, not changed: leaving a map within about ten seconds of its start logs a script error in
  `MapRoot._spawn_intel` (it awaits `get_tree().physics_frame` after the map has left the tree). Harmless, old, and
  outside this task; `smoke_match_start` waits twelve seconds to stay clear of it.
