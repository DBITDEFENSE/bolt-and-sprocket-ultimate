# The launcher's news, pictures and Upcoming tab, November 2026

Branch `claude/launcher-news`, cut from master at `479f177b`. Not merged, not pushed.

## The order

The owner, 2026-11-15: "UPDATE THE LAUNCHER AFTER ADD MORE GRAPHICS AND NEWS, AND UPCOMING CHANGES U THINK WE
SHOULD ADD". Read as: bring the news up to date with what shipped, show more and better pictures, and add an
"Upcoming" section with the changes we propose next.

## What changed

- **News** (`launcher/feed.json`): five new items, newest first: the blood and gore rework, the fixes after the
  first playtest of Update 19, movement and frame rate, Update 19, Update 18. Written from `docs/gore/`,
  `docs/u19/`, `docs/u18/`, `docs/perf/` and `docs/DECISIONS.md` T-245..T-256. The carousel is now these four:
  blood, movement, Update 19, Update 18 (the launcher, zombies, Update 15 and bosses items stay in the list).
  "Update 15" and "All ten bosses reworked" lost their `channels: ["preview"]`: both were merged to master on
  2026-11-12 (`52ab3bf0`), so Stable players have them.
- **Pictures**: 14 new 960x540 JPEGs in `launcher/assets/news/` (1.13 MB together), cut from the repo's captures.
  A news item can carry a gallery (`images`, with captions).
  - Home page: the carousel shows a strip of the item's pictures under its text (five and a "+N" box); a click
    opens the article at that picture. The news list marks items that have a gallery ("7 pictures").
  - Article: previous / next arrows on the picture, a row of thumbnails, a caption with "3 / 7", Left / Right
    arrow keys. The close button takes the focus when an article opens.
  - A before / after pair is two gallery pictures with "Before:" and "After:" captions (the cellar fix has one).
  - A picture that cannot be loaded falls back: bundled copy, then the installed game, then the launcher's key
    art. Every picture box has a fixed size and a dark ground, so nothing moves when a picture arrives or fails.
- **Upcoming**: a tab between News and Patch notes and a one-line teaser under the patch notes panel, driven by
  `feed.json` `"upcoming"`. Each card says "Proposed"; the sheet's subtitle says "Proposed, not promised: no dates,
  and the order is not a schedule." The tab and the teaser hide when the list is empty.
- **Layout fixes found on the way**: the home page's two columns could grow past the view, so the GitHub / bug
  links slid under the bottom bar (`grid-template-rows: minmax(0, 1fr)`); the wordmark is 350 px wide below a
  window height of 860 px to make room for the strip; keyboard focus is now visible (an amber outline).
- **Code**: the feed logic moved out of `renderer/app.js` into `renderer/feed.js` (plain functions: channel
  filter and order, gallery, picture fallbacks, the upcoming list), loaded by the page and by `tests/check.js`.
  No new npm dependency, no remote image host; the page's content-security policy is unchanged.
- **Version**: `package.json` 1.0.0 -> 1.1.0. The launcher has no written rule for this; the installer's file name
  and the Settings page carry the version, and a build with a new tab under the old number could not be told from
  the old one. `images` and `upcoming` are documented as "launcher 1.1.0 and newer".
- **Screenshots**: `tests/shots.js` takes chosen states (`article:<id>[:<picture>]`, `hero:<id>`, `upcoming`) and
  `CZ_CAPTURE_SIZE=1080x660`.

## The news as written (titles and summaries; bodies are in feed.json)

1. **Blood stays where it lands** (BLOOD, 2026-11-15). A hit now marks the wall and the floor behind a zombie.
   Blood runs down plaster and brick, pools under the dead, and a head that comes off leaves the neck spurting.
   The body says where it shows (walls, lit stone rooms, headshots) and where it does not yet (the taproom's dark
   boards, snow), that it needs Gore set to Full, and that boot prints, smears and the sounds were only checked by
   tests.
2. **After the first playtest of Update 19** (FIXES, 2026-11-15). Tonic machines stand against their walls, the
   cellar can be read before the power is on, Käthe's drawing is back on its wall, and Intel pickups are no longer
   stacked in one corner.
3. **The same feel at every frame rate** (MOVEMENT, 2026-11-15). Recoil, the landing dip, the gun's sway and a
   controller's turn now behave the same at 30, 60, 144 and 240 FPS. Hitches from bodies built in the middle of a
   round are gone. The body gives the CPU result of our test scenes (6 to 16 % less work per frame) and says
   plainly that frame rates on the player's GPU were not measured and that some hitches are left.
4. **A deeper cellar and a rebuilt Sherman** (UPDATE 19, 2026-11-15). The Inn's cellar is 75 % bigger, with power
   and the Crucible two doors deeper. Tonic machines are dealt to new places every match. New snow, ground, walls
   and night sky; the tank, the dive bomber and the aircraft rebuilt.
5. **Companions drink, new guns, a tank at the gate** (UPDATE 18, 2026-11-14). Companions buy tonics and carry
   wonder weapons. Four new guns in the Requisition Crate. On the Inn, a Sherman arrives on round 30 and an air
   raid on round 40.

## The Upcoming list as written

1. PERFORMANCE: **Hold 60 FPS and above, always.** Remove the one-off hitches that are left (a squad bot's first
   shots, a spawn tick, a survivor getting back up) and measure on a real graphics card instead of on the CPU
   alone.
2. SQUAD: **Smarter squad bots.** No more standing under a tonic machine that is on another floor, and reliable
   use of the workbench.
3. BLOOD: **Gore, second pass.** Blood that reads on snow and on dark floorboards, boot prints laid by your real
   footfalls, and blood on the weapon in your hands.
4. MAPS: **Random tonic places on the other maps.** Today only the Inn deals its tonic machines to new places
   every match. The other maps should too.
5. MAPS: **The Crucible walled into its room everywhere.** On Kaltenbrunn and the remaining Groom Lake maps it has
   a back plate and a flue. It should be built into the wall as it is on the Inn.
6. ART: **More detailed big models.** Kaltenbrunn's locomotive and boxcar, Groom Lake's trucks and bomber, the
   ships off Totenhafen. The C-47 wreck should be readable at night; today it is as dark as the sky behind it.
7. WEAPONS: **Wall-buys for the new guns.** The FG 42, the Mosin-Nagant, the Bren and the Sten only come out of
   the Requisition Crate today.
8. STORY: **Jakub's breakout, protected.** A relief patrol can shoot the zombie at his cage before he reaches it.
   His moment with the coal shovel should play every time.
9. FIXES: **The invisible snag in front of the Crucible.** A chest-high collider nobody can see stands in front of
   the Crucible on every map. It should go. (Added: T-254's "found, not changed".)
10. FIXES: **Power lights that reset between maps.** Lights that belong to the power can stay lit when a map loads
    after one where the power was on. (Added: the open list in PROGRESS.md's resume line.)

## Pictures used

All 960x540, progressive JPEG quality 82, made by `python -I launcher/tools/news_images.py` (run from the repo
root; needs Pillow). The table is also in `launcher/assets/news/SOURCE.txt`.

| File | Bytes | Source | Used in |
|---|---|---|---|
| `gore_wall.jpg` | 60,953 | `docs/captures/gore_rework/after/pile_09_wall.jpg` | blood |
| `fix_perk_wall.jpg` | 100,882 | `docs/captures/u19_fixes/after/spot_vault_east.jpg` | fixes |
| `fix_perk_road.jpg` | 93,284 | `docs/captures/u19_fixes/after/spot_carters_road.jpg` | fixes |
| `fix_cellar_before.jpg` | 39,811 | `docs/captures/u19_fixes/pairs/lager_door_unlit.jpg`, left half | fixes |
| `fix_cellar_after.jpg` | 77,087 | the same file, right half | fixes |
| `u19_snow.jpg` | 77,943 | `docs/captures/u19_textures/after/m00_snow.jpg` | movement, Update 19 |
| `u19_taproom.jpg` | 79,350 | `docs/captures/u19_textures/after/m00_taproom.jpg` | Update 19 (lead) |
| `u19_chapel.jpg` | 80,698 | `docs/captures/u19_textures/after/m01_chapel_lit.jpg` | Update 19 |
| `u19_lagering_vault.jpg` | 83,764 | `docs/captures/u19_cellar/after/26_lager_tuns_work.jpg` (work light) | Update 19 |
| `u19_sherman.jpg` | 104,713 | `docs/captures/u19_models/turntable/tank_eye_3m.jpg` | Update 19 |
| `u19_crate_column.jpg` | 86,707 | `docs/captures/u19_box_crucible/after/map00_crate_well_idle.jpg` | Update 19 |
| `u19_crucible.jpg` | 101,945 | `docs/captures/u19_box_crucible/after/map00_crucible_forge_front.jpg` | Update 19 |
| `u18_type100.jpg` | 31,765 | `docs/captures/u18_guns/type100_blender_front34.png`, centre 16:9 | Update 18 |
| `u18_air_raid.jpg` | 109,735 | `docs/captures/u18_sherman/inn/inn_raid.png`, cut 560,180 to 1698,820 | Update 18 (lead) |

Total 1,128,637 bytes of pictures (the folder with `SOURCE.txt`: 1,130,106). The limit in the order was 6 MB; the
unit check holds it.

How they were chosen: contact sheets of every candidate folder were looked at, then the picks at full size.

- **Left out as too dark**: every `*_lit` and `*_unlit` frame of `u19_cellar/after` (mean brightness 3 to 11 of
  255), `u19_models/inn/inn_stuka*.jpg`, most Totenhafen and Groom Lake texture frames, `gore_rework/after/lamp_*`
  and `snow_*`.
- **Left out for a debug HUD**: `u19_models/inn/*` and `u18_sherman/inn/*` carry the capture's minimap and a
  "GOD MODE" line. `inn_raid.png` is used with those cut away.
- **Left out for the capture dummies**: `gore_rework/after/headshot_*`, `shotgun_*`, `wall_*`, `pile_00..07`
  show the untextured white zombies. That leaves one gore picture (`pile_09_wall`: a wall mark and a run, no body).
  So the blood item has one modest picture and no gallery; the headshot and neck spurt, which the note calls the
  clearest gain, have no usable frame.
- **Left out on purpose**: the dive bomber's turntables. Its crosses are still the owner's open decision
  (T-253), so the launcher does not put them in front of players.
- The movement item has no picture of its own (nothing about it can be photographed); it uses the Inn's yard.

## How the feed is loaded, and how to add things

`src/manager.js` `loadFeed`: after each fetch the launcher reads `launcher/feed.json` from the branch of the
player's channel (`git show origin/<branch>:launcher/feed.json`), then from the installed tree, then the copy
bundled in the exe. So **text goes live with a push to that branch; no rebuild**.

- A news item: add an object to `news` (`id`, `date`, `tag`, `title`, `summary`, optional `body`, `image`,
  `images`, `hero`, `channels`).
- A picture: add a row to `PICTURES` in `launcher/tools/news_images.py`, run it, and refer to the file as
  `repo:launcher/assets/news/<file>`. That form works twice: a launcher built after the picture has it in its
  bundle; an older launcher serves it from the game folder (`game://`) once the player has pressed UPDATE.
- An upcoming item: add `{ "id", "area", "title", "summary" }` to `upcoming.items`. No dates.
- Then `npm run check` in `launcher/` (it checks ids, dates, that every picture exists, is 16:9 and lives under
  `launcher/assets`, the 6 MB limit, and the upcoming list's wording).

`launcher/README.md` "For the owner: posting news" has the same, shorter.

## What players need to receive it

Two different things:

1. **The news text and the pictures** reach every installed launcher, also 1.0.0, when this branch is merged to
   `master` and pushed (Stable reads `master`). Nothing else to run. On launcher 1.0.0 the new pictures appear
   after the player presses UPDATE (they come from the game folder); until then the five new items show an empty
   thumbnail, and a player who has not installed the game sees the key art. 1.0.0 ignores `images` and
   `upcoming`.
2. **The Upcoming tab, the galleries, the picture strip and the layout fixes** are in the launcher's own code.
   Players get them only with a new launcher build. Nothing was built, published or uploaded by this work. To
   build, on the owner's PC:

   ```
   cd launcher
   npm install
   npm run dist
   ```

   That writes `launcher/dist/ClaudeZombiesLauncher-Setup-1.1.0.exe` and `ClaudeZombiesLauncher-1.1.0-portable.exe`
   (not code-signed, as before). The launcher has no self-update: the owner hands the new exe to the players the
   same way 1.0.0 was handed out.

The Preview channel reads `claude/boss-rework`'s own `feed.json`; it shows this news only if master is merged
into that branch (or `config.json` / the feed's `channels` point Preview somewhere else).

## Checks

- `npm run check` (`launcher/tests/check.js`): **19 checks, all pass.** 13 were there; one of them was widened
  and six are new:
  - widened: `feed.json parses and every image resolves` now also checks ids (present, unique), the date form,
    every gallery picture (exists, safe path, under `launcher/assets`, 16:9 read from the JPEG header), the 6 MB
    limit, https links, and that no e-mail address is in the feed;
  - the upcoming list is labelled as proposals, has eight to ten items, each with title, summary and area, and
    no dates or "soon";
  - a missing or malformed `upcoming` block gives an empty list and never throws;
  - picture fallbacks: bundled copy, then the installed game, then the key art; a remote URL, a path that climbs
    out of its folder, a non-picture or nonsense gives the key art only; the key art is in the bundle;
  - the gallery: `image` first, then `images`, no doubles, optional captions, at most 12;
  - the channel filter and the order (newest first, a day's items in file order), and the real feed's first five;
  - the page loads `feed.js` before `app.js`, keeps its picture policy (`'self' game: data:`) and has the new
    elements.
- `python -I tools/assets_manifest.py --check`: "manifest current: 117 folders". It does not cover `launcher/`
  (the folder has `.gdignore`); run to show nothing under `assets/` moved.
- `feed.json` parses (`node -e JSON.parse`, and the check above).
- **Not run**: `npm start` (a visible window), `npm run dist` (no build was asked for), `tests/live.js` (a 2 GB
  install from GitHub), any Godot test (no game file was touched).
- **Not tested**: the `game://` half of the picture fallback against a real installed game with launcher 1.0.0
  (the candidate order is unit-tested; the protocol handler is unchanged). Keyboard use was not driven by a test;
  every new control is a `<button>` in the page's tab order, and the arrow keys are wired in `app.js`.

## Screenshots (looked at)

`docs/captures/launcher_news/`, made with `node tests/shots.js` (Electron with `show: false` and `capturePage`;
no window appeared), then turned from PNG into JPEG (quality 86) to keep the repo small. 1280x760 is the launcher's default window; 1080x660 is its minimum.

| File | Shows |
|---|---|
| `launcher_play.jpg` | home, the first carousel slide (blood), the news list with the new items |
| `launcher_hero_u19.jpg` | home, the Update 19 slide with its picture strip, the Upcoming teaser, the links row back in view |
| `launcher_hero_u18.jpg` | home, the Update 18 slide |
| `launcher_hero_u19_1080x660.jpg` | the same at the minimum window: the strip is hidden, nothing is cut |
| `launcher_hero_u19_1920x1080.jpg` | the same on a full-HD window |
| `launcher_article_u19.jpg`, `launcher_article_u19_2.jpg` | an article with a gallery, at the first and the third picture (the Sherman) |
| `launcher_article_u19_2_1080x660.jpg` | the same at the minimum window |
| `launcher_article_u19-fixes_3.jpg` | the "after" picture of the cellar pair |
| `launcher_article_gore-1.jpg` | the blood article (one picture, a caption, no strip) |
| `launcher_article_launcher-1.jpg` | an old item with one bundled picture: unchanged look |
| `launcher_upcoming.jpg`, `_1080x660.jpg`, `_1920x1080.jpg` | the Upcoming tab |

Two things to know when reading them: the bottom bar says PREPARE because the capture runs against an empty data
folder (no game installed), and in `launcher_hero_u19_1920x1080.jpg` the progress bar and the carousel dots were
caught in the middle of their first transition (the capture fires 2.5 s after load; `CZ_CAPTURE_DELAY=4000` gives a
settled frame, as in `launcher_hero_u19.jpg`).

## Open items

1. **A launcher build is needed** for the tab and the galleries (above). Until then players on 1.0.0 get the text.
2. **The blood item has one modest picture.** A frame of the headshot spatter with a dressed zombie would be the
   picture this item wants; the gore captures only have the white dummies.
3. **No in-game frame of the rebuilt Sherman or the dive bomber is usable** (dark, with the debug HUD); the tank is
   shown on its turntable. A clean night frame at the yard gate would make a better lead for Update 19.
4. **The dive bomber's pictures wait on the owner's decision about its crosses.**
5. **Launcher 1.0.0 shows empty thumbnails for the new items until the player presses UPDATE.** A way round it
   would be to give those five items an `art/` picture that 1.0.0 already has and keep the new ones in `images`
   only; I kept the new pictures as the lead because 1.1.0 is where they are seen.
6. **The Preview channel's feed** is the one on `claude/boss-rework`.
7. The list of proposals is this session's reading of the notes' open items; the owner may want to reorder or cut.
