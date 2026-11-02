# CLAUDE ZOMBIES (GRAVELIGHT) UI kit (UPDATE 05 section 7, DECISIONS T-096)

One period style for the HUD and every menu, readable in the dark cellar and on bright snow. Everything is
data in `data/gravelight/ui.json`, served by `MenuKit` (`gravelight/ui/menu_kit.gd`) and the Theme resource
`gravelight/ui/gravelight_theme.tres`, which every HUD / menu root applies (`MenuKit.apply_theme(root)`).

## Fonts (bundled, `assets/third_party/google_fonts/<family>/` with LICENSE.txt + SOURCE.txt)

| Role | Family | Licence | Used for |
|---|---|---|---|
| `stamp` / `stamp_light` | Stardos Stencil Bold / Regular | OFL 1.1 | the round stamp, the zone stamp, boss names, menu titles, the wordmark |
| `type` | Special Elite | Apache 2.0 | headings, buttons, HUD prompts and labels, the Ledger's typed lines |
| `body` / `body_bold` | IBM Plex Sans (variable, wght 500 / 700) | OFL 1.1 | paragraphs, descriptions, captions, subtitles (bold) |
| `mono` / `mono_bold` | IBM Plex Mono SemiBold / Bold | OFL 1.1 | Scrip and ammo counters, stat grids, the co-op ledger, the dev console |

`MenuKit.font(key)` returns a `FontVariation` on the bundled file with the system font named in ui.json as its
fallback (the only `SystemFont` left in `gravelight/ui`, plus `perk_cap.gd`'s own, T-082). `stamp_font()`,
`type_font()`, `body_font()`, `mono_font()` are the role shortcuts; `role_font("heading")` maps a role through
ui.json `roles`. The fonts are credited in the Credits screen through `data/credits_art.json`
(`python -I tools/assets_manifest.py`), and the licence gate test covers their paperwork.

## Type scale and outlines

`ui.json "scale"` holds the sizes (px on the 1920x1080 canvas): `fine 13, caption 15, body 18, body_large 20,
button 24, subheading 26, heading 30, title_small 38, title 46, display 64, wordmark 104` plus the HUD keys
(`hud_stamp`, `hud_scrip`, `hud_ammo`, `hud_prompt`, `hud_subtitle`, `hud_powerup`, `hud_zone_stamp`, `boss_*`,
`coop_*`...). `MenuKit.size(key)` reads one; `MenuKit.px(n)` snaps a free number onto the scale's `steps`, so
`MenuKit.label(text, 22)` lands on a scale size. `MenuKit.text(role, text)` builds a label by role.

`ui.json "outline"` has the dark outline + drop shadow kinds: `menu` (3 px), `hud` (4 px + shadow), `prompt`
(6 px), `banner` (8 px), `subtitle`, `stamp` (a pale outline for red ink), `paper` (none: ink on the ledger
pages). `MenuKit.outline(label, kind)` applies one. The theme's own Label default has no outline, so paper
pages stay clean; the HUD labels add theirs.

## HUD grid (`ui.json "hud"`)

`margin` [x, y] from the screen edge, never under `safe_frac` of the viewport (`MenuKit.hud_margin(vp)`, the TV
/ ultrawide safe area). Bottom-left: the perk caps row above the round stamp (`perk_cap`, `perk_gap`,
`perk_row_gap`). Bottom-right: Scrip, the gun, ammo, grenades. Bottom-centre: subtitles (`subtitle_width`,
`subtitle_bottom`) over the prompt (`prompt_y`) and the hold bar; the power-up countdown right of centre
(`powerup_x`). Top-left: the minimap (its bezel's outer edge on the margin), the zone stamp and floor under it.
Top-centre: the boss bars (`boss_top`, `boss_width`). The window stretch is `canvas_items` with the aspect kept,
so a 21:9 monitor letterboxes the 16:9 canvas (the user's own 3440x1440 does); the safe-area margin is ready for
an `expand` aspect if that ever changes.

## Crosshair, hit marker (`ui.json "crosshair"`, `"hitmarker"`)

Four 2 px ticks on the real shot cone, plus `move_spread_px` with movement speed; drawn snapped to physical
pixels (`Hud.crisp_line`, `Hud.canvas_scale`) with a 1 px dark edge for snow. Hit marker states: hit = short
white ticks, headshot = longer amber ticks with a centre dot, kill = a thick red X (amber-edged for a headshot
kill); sizes and seconds per state in the table.

## Minimap bezel (`ui/map/minimap.gd`, `ui.json "minimap"`)

A drawn brass bezel: bevelled band, light upper-left / shade lower-right, four slotted screws, N/E/S/W on brass
discs, intercardinal rose points on the tick ring, a faint eight-point rose etched in the glass and a glint over
the map (`compass_rose_alpha`, `glint_alpha`), the zone stamp and floor name under it. Open ground
(`outdoor_zone_frac`: a zone whose bounding box covers more than that fraction of the map's rect, Map 0's
Grounds) steps the view out by `outdoor_zoom_step` levels, so the 104 x 118 m field reads at a useful scale
while rooms keep the chosen zoom (`Minimap.zoom_level_effective`).

## Pause map (`ui.json "pause_map"`)

The MAP tab's first view fits the built zones (`PauseMapView.built_rect`: the zones whose bounding box is under
`fit_zone_max_frac` of the map's rect; Map 0: the inn, stable and yard), not the whole rect; the whole rect stays
the zoom-out floor so the Grounds are reachable by zoom and pan, and the last zoom is kept for the match. Zone
labels belong to the floor their polygon's middle height is on (no more Old Cellar over Taproom).

## Wordmark (T-140)

The zombies mode is CLAUDE ZOMBIES (`Game.GAME_MODE_NAME` / `GAME_MODE_NAME_TITLE`). Its wordmark is
`gravelight/ui/wordmark/claude_zombies.svg` (Stardos Stencil Bold outlines, OFL, built by `tools/gen_wordmark_svg.py`:
CLAUDE small and letter-spaced over ZOMBIES, violet #c07dff glow, amber cracks, a five-stroke tally under the word),
rasterised headless to `claude_zombies.png` (2048 wide, transparent, the glow baked from the lettering's alpha) by
`gravelight/tools_src/render_wordmark.gd`; `claude_zombies_icon.png` (256 px, the Z with the tally) is also copied to
`web/favicon.png`. `MenuKit.wordmark(height_px) -> Control` returns it as a TextureRect (aspect kept); the Gravelight
main menu's title slot and the hub's CLAUDE ZOMBIES door card use it.

## Tooling and tests

`gravelight/tools_src/shots_hud.tscn` renders the readability set (cellar, taproom at night, snow at the north
edge, the front door, the pause tabs, game over, the main menu, Credits, Muster, Settings) at `--size=1280x720`
and `1920x1080` into `morning/screenshots/u05/ui/{before,after}/`. `gravelight/tests/unit/test_ui_theme.gd`
checks the fonts load (no system fallback), every scale key exists, the theme is applied at the HUD / menu /
pause roots and no stray `SystemFont` is built in `gravelight/ui` or `ui/map`.

## Ultrawide (T-100)
- Settings > Video > **Aspect**: *Fill screen* (default, `GLSettings.values.aspect = "fill"`) sets the root window's
  `content_scale_aspect` to `expand`, so a 21:9 (3440x1440) or 32:9 screen shows more world instead of black bars;
  *Keep 16:9* restores the letterbox. Applied by `GLSettings.apply_aspect()` while Gravelight is active.
- The canvas stays 1080 tall and grows wide (2580x1080 at 21:9, 3840x1080 at 32:9). Every HUD piece reads its edge
  from `MenuKit.hud_margin(viewport)`; past `ui.json hud.max_aspect` (2.4, 21:9) the side margins grow so the HUD
  keeps to a centred 21:9 frame on 32:9.
- Full-screen menu pages and the pause page keep their panel in a centred 16:9 frame (`MenuKit.keep_centred`,
  `MenuKit.frame_inset`); the main menu's column sits inside the same frame.
- Shots: `shots_hud.tscn -- --size=3440x1440 --aspect=fill|keep` (2560x720 is a 32:9 window that fits any monitor).

## The main menu (UPDATE 09 section 7, T-144)
- The scene behind every menu page is `MenuScene` (`gravelight/ui/menu_scene.gd`; `MenuBackdrop` is a thin wrapper):
  the Crossroads Inn at night cut from Map 0 by `tools_src/gen_menu_scene.gd` into `gravelight/ui/menu_inn.tscn`
  (re-run it after `gen_map00.gd`), our zombies at a fence, the squad by a fire barrel, Map 0's MapAmbience on menu
  timings. Budgets: <= 1200 draw calls, <= 4 shadowed lights (web / Compatibility: half the zombies, 1 shadowed
  light, depth fog). `MenuScene.census()` gives the numbers.
- Layout (1920 x 1080, scaled by `canvas_items` down to a 1280 x 720 browser window): the wordmark 140 px top left
  with TERMS & CONDITIONS under it in the type face (letter-spaced, `MenuKit.spaced(font, px)`), a column of
  `MenuKit.menu_link(text, cb, 40)` buttons behind `MenuKit.rule(h)` (the thin violet rule). A link's hover and focus
  are one state: the label slides 12 px right, a violet glow comes up, `ui_tick` plays; a press plays `ui_stamp`.
  Programmatic focus stays silent through `MenuKit.quiet()`.
- Transitions: `MenuKit.transition_in(control)` / `transition_out(control, done)`: 0.25 s cross-fade with a 20 px
  slide (the control must not sit in a container); every `MenuScreen` uses them and darkens the scene behind it.
  Column changes play `ui_whoosh`. The three sounds come from `gen_sfx.gd -- --only=menu`.
- Map cards: `MapCards.map_card(map_id, cb)` (16:9 preview from `gravelight/ui/map_previews/`, the kicker, the
  name, the date line, BEST and the egg status). Loading: `LoadingScreen.go(tree, scene)` (preview art, a lore line
  and a tip from `data/gravelight/tips.json`).
- Shots: `gravelight/tools_src/shots_menus.tscn` through `tools/wsl_godot.sh` only (contract C8).
