# Morning report — UPDATE 09 "CLAUDE ZOMBIES", 2026-11-01

**The zombies game is now called CLAUDE ZOMBIES, has online play by lobby code, a new main menu, a new perk
(Ledger Lager), relief squads that join your fights, the Mark in the story and on every zombie, and Totenhafen and
all four Fernflug acts rebuilt from boxes into places.** Everything is merged on `master` and pushed. The one thing
only you can do is the Vercel deploy (two commands, below).

## How to play online with your friend
Both of you need the game: either the Windows zip (`build/ClaudeZombies_0.0.1-m0.zip` after `sh tools/build_windows.sh`,
or the one in `build/` from tonight) or the browser link once it is deployed. Desktop and browser players can play
together.
1. Start the game. On the title screen pick **CLAUDE ZOMBIES**, then **PLAY → ONLINE**.
2. The first time it asks for a display name. Type anything; no account.
3. **CREATE LOBBY**: pick the map, public or private, and tick "fill empty slots with bots" if you want bots. The
   lobby shows a **6-letter code**. Text it to your friend.
4. Your friend: **PLAY → ONLINE → JOIN BY CODE**, types the code, picks a survivor (no duplicates), presses READY.
5. You press **START**. That's it. No ports to open, nothing exposed on your PC: the connection is peer to peer
   (WebRTC) and the lobby lives in your Supabase project, which is already set up and live.
- If your friend's network is strict (office, school, some mobile), a TURN relay helps; it is optional and one line
  in `NEEDS_DEVIN.md`.
- If the host quits, everyone gets "The host left the match." If a player drops, their slot becomes a bot (if ticked)
  and they can rejoin the same lobby within 60 s and get their survivor back.
- LAN by direct IP still exists under ONLINE → "LAN (direct IP)".
- Plain-words version with troubleshooting: `docs/ONLINE.md`.

## The browser link
**Not live yet: it needs your Vercel login.** The build is ready and tested locally (it reaches the menu at 129 MB,
the maps download in the background from the menu). To publish it:
```
npx vercel login
sh tools/deploy_web.sh
```
Then set the password gate once: `cd build/web && npx vercel env add CZ_PASSWORD production` (type the password you
want to give your friend), and run `sh tools/deploy_web.sh` again. The site asks for that password before it loads
the game. Browser reality check: it runs on Godot's Compatibility renderer, so it looks simpler than the desktop
build (no volumetric fog, no global illumination); the mood is kept with cheaper fog and lighting.

## What's new on each map
- **Every map:** every zombie carries a faint violet **mark** on the right hand or the forehead that pulses with the
  infection. Hit it for ×1.5 damage and a Scrip bonus; the hitmarker goes violet. Deacon names it the first time you
  kill one. Five new intel documents explain it (an implant order, the recruiting poster, a medic's notes, Darkmatter's
  "Terms of the Mark", Jakub's refusal). **Relief squads** arrive from round 4 on: Home Army partisans, Soviet
  scouts, Volkssturm old men, commandos, an American stick, Groom Lake MPs; they shout, fight beside you, mostly get
  overrun, and their dead rise. Sometimes one survives to the end of the round. Loot their crates and dropped guns.
  **Ledger Lager** (a brass cash-register cabinet, 3000 Scrip) pays +20% on everything you earn; tier II adds 2% a
  round to the bank; tier III is a 10% discount on every purchase plus a tip on mark kills; tier IV is permanent and
  pays a dividend every round you finish standing. The **savings bank** is now on every map.
- **Crossroads Inn:** three more people to talk to (a deserter in the hayloft, the carter's widow upstairs, a courier
  at the gate), each with a favour. The people upstairs no longer walk into walls.
- **Kaltenbrunn:** miners hiding in the chapel, a field medic (do his favour and he becomes a revive point), the
  switchboard operator, and Ammer trades ammo for Scrip once a round. The bots' wall-walking at the gatehouse corner
  and on the stairs is fixed.
- **Totenhafen:** rebuilt. U-1047 is a real Type VII hull in a wet dock, the cutter is a real boat, the cannery and
  workshop have their machines, the pens drip, the storm flashes beyond the steel curtain, every zone has its own
  sound. The bank is in the crane office; the teller is Karl Jessen.
- **Fernflug Act I (Werk Thalbach):** rebuilt. The Great Hangar has trusses and netting over a real flying wing; the
  assembly halls hold two half-built wings in jigs; the rail yard has flatcars with the Totenhafen coffins; the housing
  blocks, canteen, church square, wind tunnel and test stands are dressed. Searchlights sweep the clouds.
- **Fernflug Act II (der Kranich):** the box is gone. You are inside a flying wing: ribs, spars, riveted skin, bomb
  racks, the galley, the engine room's violet core, the gun blisters, the cockpit glass, and outside every window the
  night sky, clouds, the coast, the sea, London under searchlights, fighters strafing past.
- **Fernflug Act III (Groom Lake):** the dry lake under a real desert sky, the burning wreck, a wooden hangar with the
  bomber, trucks in the motor pool, the lattice radar tower, the lab's specimen rooms, the silo with the LANTERN rocket.
- **Fernflug Act IV (the Moon):** each dome has its own floor and tone, the capsule in reception, the Earth over the
  crater rim with the dish's beam, boot prints in the regolith, the suited inventory with tags, the retention hall's
  columns, Jan Pilch's hand under the glass in the Account.
- **Main menu:** a live scene instead of a video: the inn at night in the snow, our zombies at the fence with glowing
  marks, the squad by a fire barrel, artillery on the horizon, bombers crossing. After you beat Fernflug, a violet light
  shows on the Moon. New map select with previews and your best rounds, loading screens with tips, a game-over
  ledger, settings with graphics presets and auto-detect.

## Performance on the minimum-spec target (a laptop with Iris Xe / Radeon 680M at 1080p)
Nothing here could be measured on a real GPU: this PC's renders must stay off-screen, so every number is from
software rendering (draw calls and triangles, which are hardware-independent) and headless CPU timing. Real FPS
needs your `--frame-log` run and a laptop browser test (both in `NEEDS_DEVIN.md`).

| Map | Draw calls in view (peak, browser profile) | Triangles in view (peak) | Budget |
|---|---|---|---|
| Crossroads Inn | 5,804 | 1.74M | over (the inn's forest and village visibility are the next lever) |
| Kaltenbrunn | 1,448 | 375k | ok |
| Totenhafen (rebuilt) | 2,028 | 394k | ok (was 4,651 / 627k before the rebuild) |
| Fernflug I | 2,259 | 390k | ok |
| Fernflug II | 1,482 | 368k | ok |
| Fernflug III | 2,287 | 381k | ok |
| Fernflug IV | 1,054 | 223k | ok |

The budget is 2,500 draw calls and 400k triangles on desktop (200k in the browser; most maps are over that
browser figure in their widest views). The browser build is 129 MB to the menu, 368–387 MB before the first match.
The CPU side (zombies, bot brains, the new squads) is 9–16 ms a frame of script time with 24 zombies, 3 bots and a
squad, which is the real risk for 60 FPS on Low on a laptop; the squads' brains cost 0.2–0.3 ms.

## Tests
Unit suite and the smokes: the numbers are in `PROGRESS.md`'s resume line (every section was merged only with the
suite green and its smokes passing; the full run at the end is listed there). Nothing was checked in a rendered
window on this PC; all screenshots came from an invisible software renderer. Please look, in this order: the main
menu, Totenhafen's pen hall, Fernflug Act II, the Moon yard.

## Still not working or not done
- The browser link is not deployed (your login).
- Real FPS on a laptop is unmeasured; Crossroads Inn is over the draw-call budget in the browser.
- The minimap images of the rebuilt maps were not re-baked (the POIs are current).
- Act II's five wall-buys face the wall (pre-existing; they got backing plates), and the inspection hatches look into
  closets rather than the sky.
- Browser ↔ desktop play was not tried in a real browser (the same WebRTC code runs on both; two desktop
  instances were tested over real WebRTC).
- UPDATE 08 §4 (bots finishing the Kaltenbrunn egg) is still open, as before.

## Pull it on the PC
```
cd C:\Users\Devin\PROJECTS\bolt-and-sprocket-ultimate && git pull origin master && git lfs checkout
```
(You are already on this PC's checkout; the line is for any other machine.)
