# T-270: one world (the war map)

Branch `claude/one-world`. The owner: "Maybe one idea I have is to simplify things, is to maybe just merge this all
into one map. So have all the maps just on one, and you know, you could play in different sections, but yeah, somehow
make it feel like all the maps are just one for one ultimate map."

## 1. What this is, and what it is not

It is the **feel**: Solo's map step (Play > Solo > character) is no longer seven cards. It is one drawn sheet, a paper
war map titled "ONE ROAD: Silesia to the Moon", on which the seven maps are seven places on one route:

Crossroads Inn (Silesia) > Kaltenbrunn (the salt mine) > Totenhafen (the Baltic pens) > Werk Thalbach > Der Kranich
(in flight over the Atlantic) > Groom Lake (Nevada) > Mondlicht (the Moon).

It is **not** one playable map. The seven map scenes are untouched and each match still loads one of them. Nothing in
a match changed: no gameplay, no map, no generator, no project setting. Travelling between places inside a running
match is not built (section 5).

## 2. The screen

- **The sheet** (`gravelight/ui/world_map.gd`, `WorldMap`): drawn in code with `_draw` calls, no texture and nothing
  downloaded. Sea, rough coasts (not a survey; the sheet says "not to scale"), a survey grid, folds and stains, a
  compass, a title block with the key. The colours are the menu's own (the pause menu's paper, the brass frame, the
  ink red, the violet of the focus).
- **The route** runs east to west, like the story. Three kinds of leg: a solid line (road and rail) from the inn to
  Werk Thalbach, a dashed flight line across the Atlantic with a small aircraft on it and the Kranich's place at its
  middle, a dotted rocket trail from Groom Lake up into an inset of night sky where the Moon is ("INSET · NOT ON THIS
  SHEET"). Legs you have travelled (both ends open) are red ink; the rest is pencil.
- **A place** is a numbered red mark with a dark name plate: the name, the date line, the best round and the egg
  state, the same four things the card showed, from the same sources (`MapCards.ROWS`, `ProfileSave.best_round`,
  `MapCards.egg_status`). A locked place is a grey mark with a padlock and "LOCKED" on its plate. A finished egg
  also puts a violet lozenge on the mark.
- **The side panel** (right, 430 wide) shows the place under the focus: "STOP 3 OF 7 · MAP 2", its 16:9 preview (the
  same PNG the card and the loading screen use), name, date line, best round and egg state, or the LOCKED stamp over
  a darkened preview with "To unlock: " and the card's own unlock text, then two route lines ("From Kaltenbrunn, by
  road and rail." / "Onward to Werk Thalbach, by road and rail.") and what a press does.
- **Pressing a place starts the match** exactly as its card did (`MenuCharacter._start` with the scene from
  `MenuCharacter.MAPS`: `prepare_match(false)`, then `LoadingScreen.go`).
- The top row (character, loadout, bots) and Easter Egg Mode are where they were. The bots' paragraph moved under the
  sheet so the sheet stays in view when bots are on.
- The step line reads "STEP 2 OF 2 · DUTCH · PICK A PLACE ON THE MAP TO START".

## 3. Keyboard, mouse, controller

- **Mouse**: hovering a place (its mark or its plate) gives it the focus, a click starts it.
- **Keyboard / D-pad / stick**: the sheet runs west, so **LEFT is onward and RIGHT is back**, always, over the whole
  route (x falls with every step; a unit test holds that). **UP / DOWN** follow the route where it runs up or down
  (inn - Kaltenbrunn, Kaltenbrunn - Totenhafen - Werk Thalbach, Groom Lake - the Moon) and otherwise leave the sheet:
  UP to the top row, DOWN to Easter Egg Mode; from either row the way back lands on the place last looked at. Tab
  order is story order. At the two ends of the road LEFT / RIGHT stay put.
- A **locked place takes the focus** (so its unlock rule can be read) but cannot be pressed.
- The first open place has the focus when the page opens (as the first open card had).
- **Motion** (all in `MenuMotion`): the violet ring glides to the place under the focus in 0.18 s (`MenuMotion.glide`,
  new), a soft second ring pulses round it while it has the focus, the side panel's content fades in over 0.14 s.
  With **Reduce motion** the ring is simply there, nothing pulses, and the fade is 0.06 s. The sheet itself is drawn
  once and only redrawn when its size changes; the marks redraw on a change of focus; only the ring redraws per frame.

## 4. What stayed

- **The Campaign page** keeps what it had: its one card, its paragraph, Easter Egg Mode.
- **The co-op lobby's map choice is unchanged** (a drop-down when hosting online, a list of buttons on LAN). It works
  as before; it does not use the war map. Reason: the lobby rebuilds every five seconds and its map choice is one
  row among the host's controls; putting the sheet there is its own piece of work.
- **`MapCards`** is untouched (the loading screen and `test_tips`, `test_menu_scene` read it), including `card()` and
  `map_card()`; the campaign's card is still built by it.
- The places sit in a node named `MapCards` in story order and carry the cards' metas (`map_id`, `egg`, `best`), and a
  locked one is `disabled`, so `smoke_match_start` and `test_menu_rework` find and press them as before.

## 5. How it could grow into real travel between regions (not built; the owner's call)

Honest order of cost, cheapest first:

1. **A campaign that is drawn on this sheet.** The campaign already carries the squad and their kit from one map to
   the next (`Campaign`, the exfil beacon, `ExfilCutscene`). Showing this sheet between two campaign maps, with the
   mark travelling along the leg, would cost a screen and no gameplay. It would also want the campaign to go on past
   Totenhafen, which today it does not.
2. **Choosing the next region at the beacon.** Where the route forks (it does not today), the exfil could open the
   sheet and let the squad pick. That needs the unlock rules and the rounds-so-far to carry across (`GameState`,
   `ProfileSave.cur_match`), and co-op needs the host's choice sent to every peer.
3. **Regions loaded into one running match** (what the owner's sentence literally says). Each map is its own scene
   with its own navigation, lighting, round rules and bosses, spread over Silesia, the Baltic, an aircraft, Nevada and
   the Moon. Loading two at once is not affordable while frame rate is the main complaint (T-265), so "one map" would
   have to mean streaming: unload one region, load the next behind a travel moment (a train, the flight, the rocket),
   keeping the players, their kit and the round counter. That is the campaign's hop made seamless; it is a large
   piece of work in the round director, the save of a match in flight, and co-op.

Nothing in this task stands in the way of any of the three.

## 6. Tests

- `gravelight/tests/unit/test_world_map.gd` (13 tests): the places are `MapCards`' and `MenuCharacter.MAPS`' maps in
  story order and start the same scenes; LEFT walks the whole route; the UP / DOWN table; a place's state from the
  three profile facts and from the profile; travelled legs; the legs join their places and the Kranich is on the
  crossing; every coast is a simple outline that can be filled, the land places are on land, the Kranich is over the
  sea, Totenhafen is on the coast, the Moon is in its inset; the name plates stay on the sheet and off each other and
  off the marks at three widths; the dash cutter; the places are focusable buttons and a press calls the start with
  the map's id; a locked place can be focused; Reduce motion; the Solo page (seven places, focus, the side panel for
  an open and a locked place, the rows above and below reachable in both directions, the page fits the screen); the
  Campaign page has no sheet.
- `smoke_menus` walks the sheet by `ui_left / ui_right / ui_up / ui_down / ui_accept / ui_cancel` actions;
  `smoke_menus_pad` walks it with real D-pad, A and B events (and checks that A on a locked place starts nothing).
- `smoke_match_start` is unchanged and still starts the Crossroads Inn from the Solo page.

Numbers are in section 8.

## 7. Renders

WSL + Xvfb (Mesa llvmpipe, the Compatibility renderer), never a window on the PC, through the new
`gravelight/tools_src/shots_t270.tscn`. In `docs/captures/t270/` (JPG q90):

Rendered at 1920 x 1080. Look first at:

- `open_sheet_only.jpg`: the sheet alone, every place open (the picture of the idea).
- `open_crossroads.jpg`: the whole page as it opens on a profile with everything unlocked.
- `fresh_crossroads.jpg`: the same page on a new profile (only the inn open, the rest in pencil with padlocks).
- `part_kranich.jpg`: the road open as far as Werk Thalbach, the focus on a locked place (the stamp, the unlock
  text), two bots on (their paragraph under the sheet).

The rest: `open_totenhafen.jpg`, `open_kranich.jpg`, `open_mondlicht.jpg` (the focus on other places, the ring on the
Moon), `part_thalbach.jpg`, `fresh_kaltenbrunn.jpg`, `fresh_mondlicht.jpg`, `fresh_sheet_only.jpg`,
`reduced_groomlake.jpg` (Reduce motion on), `campaign_unchanged.jpg` (the Campaign page, as it was).

Two things only the first render (1280 x 720, not kept) showed, both fixed: the best round and the egg state ran
into each other on the name plates and the longest date line was cut ("the salt min"), so the plates are wider and
the sheet's smallest width went up to 1250; and the road legs bowed far enough to run under their neighbours'
plates, so they are straighter.

## 8. Verified / not verified

| Check | Result |
|---|---|
| Script check | 991 scripts, 0 failed |
| Unit tests (GUT), full | 2546 tests, 2545 passing, 1 risky (the known `test_neural_lines_are_loudness_normalised`); `test_world_map.gd` adds 13 (580 asserts) |
| `test_menu_rework` / `test_menu_scene` / `test_tips` | 26 / 9 / 5 passing |
| `smoke_menus` | PASS (10 screens, plus the walk over the sheet by actions) |
| `smoke_menus_pad` | PASS (10 screens, plus the walk with D-pad, A, B) |
| `smoke_match_start` | PASS, 41 checks (the inn still starts from the Solo page; no cutscene; the campaign page has only its card) |
| `shots_t270` headless (a crash check) and under WSL Xvfb | PASS, 13 pictures |

Not verified, or not done:

- **Never seen on a GPU or on Forward+.** The renders are Mesa llvmpipe on the Compatibility renderer. The sheet is
  plain 2D drawing (lines, polygons, text), so it should look the same, but antialiased line quality and the thin
  pencil legs want a look on the real screen.
- **Motion** (the ring's glide and pulse, the panel's fade) is in no still. The timings are in section 3.
- **A controller in the hand.** The pad smoke sends real joypad events, and the focus neighbours are unit-tested, but
  nobody has held a pad on this page. Whether LEFT = onward feels right on a sheet that runs west is the owner's call
  (the alternative is a sheet that does not follow geography).
- **The mouse** was not driven by a test: hover-gives-focus is one line (`mouse_entered` > `grab_focus`), the click is
  the Button's own.
- **Ultrawide and 4:3 windows.** The sheet needs 1250 logical pixels of width and gets 1318 at 16:9. The plates were
  tested at 1250, 1300 and 1600 wide; a 4:3 window was not rendered.
- **The co-op lobby** does not show the sheet (section 4), and nothing about co-op was run for this task beyond the
  menu smokes (the lobby page opens and closes).
- **The coasts are rough shapes**, drawn by hand in code from memory: recognisable, not accurate. No real map data
  was used.
- The route lines in the side panel ("by road and rail", "by air", "by rocket") are new game text. They follow the
  unlock texts ("Board the Kranich at Werk Thalbach", "Ride the rocket from Groom Lake"); how the squad gets from
  Totenhafen to Werk Thalbach is not said anywhere in the game, and "by road and rail" is this task's guess.
- The old Solo captures in `docs/captures/t267/after/05_solo_maps*.jpg` now show a page that no longer exists.
- `shots_t267.gd` and `shots_menus.gd` still run on this page (they find the places through the `MapCards` node) but
  were not re-run.
- `docs/DECISIONS.md` has no T-270 paragraph yet (the lead logs it).
