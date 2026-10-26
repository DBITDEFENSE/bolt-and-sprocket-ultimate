# UPDATE 02 — FEEL, FIXES & A LIVING CROSSROADS INN

This is a work order for the existing project. All rules from `ULTIMATE_PROMPT.md`, `ULTIMATE_PROMPT_V2.md`, `ULTIMATE_PROMPT_V3_BOSSES.md`, and `OVERNIGHT_RUN.md` (all in `C:\Users\Devin\PROJECTS\bolt-and-sprocket\`) still apply. **Work unattended per OVERNIGHT_RUN.md:**
- no pausing to ask;
- a branch per section;
- `main` always launches;
- commit every 30–45 minutes;
- keep the `PROGRESS.md` "RESUME HERE" line current;
- update `PLAY.bat`;
- refresh screenshots;
- finish with an updated `morning/MORNING_REPORT.md`.

**Before changing anything, playtest what exists:** launch Map 0, play to round 10 with the dev console, and write down in `PROGRESS.md` what currently feels wrong. Then do the sections below **in this order**. Each section has acceptance criteria. Don't call a section done until they pass AND you've captured a screenshot or short clip of it for the morning report.

---

## 1. MOVEMENT & GUNPLAY FEEL (do first; it touches everything)

The goal is classic round-based-zombies feel: weighty, responsive, readable. Put every number in `/data/gravelight/movement.tres` and per-weapon `WeaponData`.

**Movement**
- **Acceleration and deceleration curves** instead of instant velocity: ~0.12s to full speed, a slight slide on stop, and lower air control.
- **Sprint:** hold or toggle (a setting), with slightly reduced turn speed while sprinting, a sprint FOV kick (+6°, smoothed), and a stronger head-bob. **Sprint-out time** (time from releasing sprint until you can fire) is set per weapon class: pistol 0.15s, SMG 0.2s, rifle 0.3s, LMG 0.45s, launcher 0.5s. Firing or ADS input **cancels sprint immediately** and plays the sprint-out animation, so the input never gets eaten.
- **Firing while moving:** walking fire is allowed with a spread penalty. There is no firing while sprinting (classic), but the sprint-to-fire transition must feel instant at the input level.
- **ADS while moving:** ADS-walk speed is 60% of walk (per weapon), with ADS move-sway (figure-8) and smooth ADS in/out using per-weapon ADS time (SMG 0.18s, rifle 0.25s, LMG 0.4s).
- **Crouch** (smooth camera lerp) and **prone** optional, behind a setting.
- **Slide:** sprint + crouch, a short burst with an FOV dip and a low camera. You can fire from the hip during the last 50% of the slide. Blastproof Bock's slide shockwave hooks in here.
- **Mantle / vault** over waist-high objects (fences, bar counters, low walls) with a 0.4s animation. This makes training loops flow.
- **Jump:** a small jump with weapon dip on takeoff and landing, landing camera shake scaled by fall height, and no bunny-hop speed gain.
- **Camera:** subtle weapon inertia (the weapon lags the look slightly), strafe roll (±1.5°), footstep-synced bob, and a "punch" on taking damage.
- **Footsteps:** surface-aware (snow, wood, stone, hay, metal), louder when sprinting.

**Gunplay**
- **Recoil:** a per-weapon recoil pattern (vertical climb plus a small random horizontal kick) that recovers after you stop firing, separate from **visual kick** (the gun model moving).
- **Hip-fire spread:** a bloom that grows while firing and shrinks while still or crouched, plus a crosshair that reflects it.
- **Feedback:** hitmarkers (white for a hit, red-tinted for a kill, a heavier sound for a headshot), muzzle flash, light flash, shell casings, impact decals per surface, and blood/Nachtglas spark on zombies.
- **Reloads:** partial vs. empty reload animations and times; reload cancel by sprinting or swapping; a "last bullet" audio click.

**Acceptance:** a side-by-side clip (before/after) of sprinting into firing, ADS-strafing, sliding, and mantling. No eaten inputs. 60 FPS holds.

## 2. FIX THE THOMPSON ADS (and make every gun's ADS correct)

The Thompson's ADS is misaligned. Fix it properly, so it can't happen to any weapon again:
- Every weapon scene gets a **`SightPoint` Marker3D** placed exactly at the rear sight aperture / front post line. ADS moves the weapon so `SightPoint` sits on the camera's center ray, at a per-weapon eye relief distance. **No hand-tuned position offsets anywhere.**
- Per-weapon ADS FOV (Thompson ~10% zoom; scoped weapons use a scope overlay).
- **Thompson specifically:**
  - Line up the rear peep sight and the front blade.
  - Fix any clipping of the drum or stick magazine and the hand into view.
  - Fix the ADS sway so it isn't excessive.
  - Give it its iconic feel: a heavy, controllable climb with a satisfying chunky report.
- **Build an alignment check tool:** `tools/ads_check.gd` loads every weapon, enters ADS, renders a frame with a center dot overlay, and saves `morning/screenshots/ads/<weapon>.png`. Fix every weapon whose sight isn't on the dot. Run it after any weapon change from now on.

**Acceptance:** every `ads/<weapon>.png` shows the sights on the center dot; the Thompson is shown in the report.

## 3. REBUILD THE TOTENGLOCKE (the bell gun currently sucks)

Diagnose first. Write down why it feels bad (damage falloff? too few charges? weak feedback? a slow cone?). Then rebuild it around a **"wind and toll"** mechanic. It should feel like the most powerful thing on the map.
- **Primary (tap):** a quick toll. A fast, mid-range shockwave cone (8 m, 50°) that staggers everything and **kills outright up to about round 20**. After that it does **% of max HP** (35% per toll), so it never stops being useful.
- **Primary (hold) — WIND UP:** crank the handle (the animation speeds up and the bell starts humming, rising in pitch over 1.5s). Release for the **GREAT TOLL**: a 14 m, 70° cone that **shatters** everything in it. Players get a big screen-ring distortion, snow and dust blown off every surface in the cone, a delayed echo off the walls, and a brief hitstop slow-mo on mass shatters. It costs 3 charges.
- **Resonance marks:** zombies that survive a toll are **"tolled"** (a faint ringing glow). A second toll on a tolled zombie always shatters it. This rewards herding a train and tolling it twice.
- **Alt-fire — BELL DOME:** plant the bell's ring as a 6 m resonance field for 8s that slows zombies by 60% and makes them take +25% damage. One active at a time. Perfect for revives and Easter-egg steps.
- **Ammo:** 12 charges per "magazine." **The crank IS the reload** (a satisfying winding animation). 48 reserve. Ammo boxes refill it (§4), and kills with it drop small "bronze shards" that restore 1 charge (max 1 per 5 kills).
- **Feel:** a deep, layered bell sound (low body, metallic shimmer, a tail that rings out for 3 seconds). The bell visibly vibrates after firing. Controller rumble. The tolling camera kick.
- **Upgraded — "TOTENGLOCKE: MITTERNACHT":** cones +30%, the Great Toll costs 2 charges, shattered zombies **chain-ring** to 3 nearby zombies, the Bell Dome lasts 12s and pulls zombies in slightly, and the sound becomes a midnight chime with a violet visual layer.
- **Keep the lore:** the bell, frame, and crank parts and the workbench build stay the same.

**Acceptance:** a clip of a Great Toll shattering a 10+ zombie train on round 15+, the Bell Dome holding a revive, and the upgraded chain-ring. On round 25, test that the gun still feels strong.

## 4. AMMO BOXES ON EVERY MAP

- A diegetic, olive-drab ammunition crate with stencils and a visible pile of loose rounds and stripper clips, a flickering lamp on top, and a buy prompt. **Hold [F] to refill your current weapon.**
- **Cost:** 250 Scrip normally; **2,500 Scrip if the current weapon is Crucible-upgraded.** The prompt shows the right price for whatever you're holding. Grenades are refilled too (not tacticals).
- **Wonder weapons** (Ashlight, Totenglocke, Die Lange Nacht, Return Policy): 1,000 normal / 4,000 upgraded. Log this in `DECISIONS.md` if you tune it.
- **Placement:**
  - **Map 0:** 2 boxes (the taproom behind the bar, the stable).
  - **Kaltenbrunn:** 4 (Rail Yard, Barracks, Salt Chapel, Lab Wing).
  - **Morgenrot and Helvetia Works:** 4 each, when those maps exist.
  - Never place one next to a perk machine or the Crucible. Spread them so they shape the route.
- Per-player use with a 3-second cooldown. Bots and the prisoner companion (§6) can use them too, from shared Scrip rules.

**Acceptance:** buying works with the right price on normal, upgraded, and wonder weapons; boxes are placed on all built maps; there's a test in GUT.

## 5. BOTS: A RANDOM BONUS PERK EACH + MUCH BETTER DESIGN

(The bots are the AI squad-mates who fill empty slots in solo or co-op.)

**Random bonus perk**
- At match start, each bot gets **one random perk** that doesn't count toward its cap. It's drawn from the perks on that map, with **no two bots getting the same one**.
- It shows as a bottle cap on the bot's nameplate and in the scoreboard.
- Bots announce it in character the first time it matters ("That stout's still in my blood, I can take a hit.").
- If a bot goes down it loses perks as players do, **but keeps its bonus perk** (it's their "trait").
- It's data-driven and can be toggled in settings ("Bot Bonus Perk: On/Off").

**Design** (they should feel like the four squad characters, not generic NPCs)
- Each bot uses its character's full model, outfit, and gear (Dutch, Peg, Deacon, Wren; Bolt and Vendelin when unlocked), with distinct silhouettes: Dutch's helmet and BAR posture, Peg's beret and satchel charges, Deacon's mechanic's coveralls and wrench on his belt, Wren's scarf, notebook, and scoped rifle.
- **Animations:** idle fidgets per character (Wren writes in her notebook, Deacon taps machines, Dutch stretches his back, Peg checks her watch). They play perk-drinking and weapon-buy animations. They do reload, revive, barricade-repair, and downed animations.
- **Voice/barks:** they use the character quote packs (VO_SCRIPT). They call out what they're doing ("Reloading!", "Board's up!", "I've got you, hold on!"), bosses, power-ups, and low ammo.
- **Behaviour upgrades:**
  - They follow the player's training loop instead of camping.
  - They don't block doorways or the player's path (they step aside on a nudge).
  - They prioritize reviving the player, use the ammo boxes, buy wall weapons sensibly with their own Scrip, and repair barricades between waves.
  - They stay out of trap zones and never trigger Easter-egg steps on their own.
  - A **simple command wheel** (hold a key): Follow / Hold here / Repair barricades / Revive priority.
- **Nameplate:** a clean small plate with name, bottle-cap perks, and health bar, readable at a distance and hidden behind walls.

**Acceptance:** a clip of 3 bots playing rounds 1–12 on Map 0 alongside the player (training together, reviving, using an ammo box, bonus perks visible). No bot stuck in a doorway in a 10-minute soak test.

## 6. MAP 0: A BIGGER CELLAR + THE PRISONER COMPANION

### 6.1 The bigger cellar
Expand the Crossroads Inn cellar into a real zone (a door from the taproom, 1,250 Scrip):
- a **wine cellar** (racks, barrels, low arches, dripping water);
- a **root cellar / storeroom** (potato sacks, hanging hams, preserves; the cousins' jam jars on the top shelf, a v3 nod);
- the **holding cell** where a German patrol locked a prisoner before they fled (an iron-barred cage built into the old coal room);
- the **cousins' hidden room** behind the trapdoor (v3 §2.6) connected to it.

Add 2 windows at ground level (half-height, zombies crawl in through them), one wall-buy (M1 Garand or Thompson), the perk machines that were placed down here (v1 Appendix A §A9 note), and one ammo box. It must support a **training loop** around the central barrel stack.

### 6.2 The prisoner: **Jakub Ostrowski**
- **Who he is:** a Polish miner in his forties, a forced laborer who escaped from **Kaltenbrunn** two days ago. The patrol caught him on the road and locked him in the inn's coal cage. He knows the mine like his own hands, and **he knew Wren's brother.** That's a quiet scene the first time Wren talks to him, if Wren is in the match (as a player or a bot).
- **Design:** gaunt, stubble, a mismatched oversized army greatcoat over his work clothes, a cloth cap, a miner's lamp hook on his belt. Calm, wry, polite. He has seen worse than zombies and isn't impressed by them.
- **When he gets out:** at **round 5** (data-driven), a zombie bursts the cage hinge while trying to reach him. You hear him shouting in Polish from downstairs if you're not in the cellar (subtitled, positional audio pulls you there). He kills it with a coal shovel, then waits by the cage.
- **Your choice** (an interact prompt, "Talk to Jakub"):
  - **GIVE HIM A GUN:** hand over **the weapon in your hands** (you lose it), or interact with a wall-buy while he's beside you to **buy one for him** at the normal price. He becomes an **armed companion**.
  - **NOT YET:** he follows you unarmed with the coal shovel (weak melee), repairs barricades, points out power-ups and crate locations, and calls out sprinters. You can give him a gun any time later.
- **As a companion:**
  - He follows the player who freed him and uses the bot behaviour system (§5): command wheel, repair, revive.
  - He has his **own health**, can be **downed and revived**, and **bleeds out after 60s**. If he bleeds out, he's gone for that match, but he returns at the next map in the campaign, wounded, saying *"Not yet. Not tonight."*
  - **He doesn't drink perks** (he refuses: "I've seen what they put in those."). This is a story beat, and it keeps him balanced.
  - **He doesn't count as a player** for zombie scaling, and doesn't take a player slot.
  - Weapon handling: ~70% of a player's accuracy. He reloads, uses ammo boxes from the party's Scrip pool at half the box cost, and prefers rifles. "Bolt-actions, please. I don't trust things that fire by themselves."
- **For the rest of the match:** he stays with the squad, comments on events (the Cousins round terrifies him: "I know that song. Everyone in this valley knows that song."), and stays out of Easter-egg steps unless asked.
- **For the rest of the campaign:**
  - A profile flag `companion_jakub = joined` carries him into **Kaltenbrunn** (where he becomes your guide: he knows a shortcut through the Maintenance Stairs that opens for 500 less, and new mine lines), and onward to later maps.
  - He gets a **Dossier page**, an Archive entry (his escape story, written as a letter to his wife), and VO for every map.
  - Plan his arc in `CANON.md` toward the Morgenrot finale. The chalk sabotage marks in v2 §4.2 should mean something to him, because he made some at Kaltenbrunn.
- **Respect rule** (v2 §0.1): Jakub is a person and a hero, never a joke, never a zombie.

**Acceptance:** play from round 1 to 12. Jakub breaks out at round 5, both choices work, he fights or helps, can be revived, survives into round 10 with the Cousins, and the profile flag is saved.

## 7. MAP 0: A LIVING WORLD — LANDSCAPE, SKY & DISTANT WAR

The inn should feel like a tiny island in a huge, burning winter war.
- **Terrain beyond the play space:** rolling snowy hills in 3 depth layers (near playable edge → mid hills with pine forest → far mountain silhouettes).
  - The crossroads road continues out into the dark with abandoned vehicles: a burnt-out kübelwagen-type car, a horse cart tipped over, scattered suitcases, a fallen signpost with village names.
  - Telephone poles with sagging wires, a frozen stream with a small stone bridge, a distant farmhouse with one lit window that goes dark at round 8.
  - A church steeple on a far hill.
  - Use MultiMeshInstance3D forests, LOD, impostors, and fog cards for performance. Players can't reach it, but it must look reachable.
- **Planes overhead** (randomized every 2–4 minutes, data-driven):
  - Allied bomber formations droning high across the sky, with engine audio that sweeps overhead.
  - A low pair of fighters chasing each other with tracer fire.
  - Occasionally (once per match, round 6+) a **plane gets hit and goes down** trailing smoke behind the hills, with a delayed crash flash and boom, mirroring the squad's own crash. Character lines react.
  - Searchlights sweep the clouds in the distance.
- **Distant battle:**
  - Artillery flashes on the horizon with the **boom delayed by distance** (speed of sound, ~3s per km), plus rumble and rumble-shake.
  - Arcs of tracer fire over the far hills. Flares drifting down under parachutes, lighting the snow red or white.
  - The glow of a burning town on one horizon. An occasional distant machine-gun stutter.
  - All of this escalates subtly with round number (the war is getting closer).
- **Weather & ambient life:**
  - Snowfall with gusts that blow snow off the roofs, breath fog on characters, frost creeping on window panes, icicles.
  - Crows that scatter when gunfire starts. A dog barking somewhere far away (it stops at round 10).
  - A creaking inn sign, a shutter banging in the wind, a distant church bell at midnight. Smoke from the inn's chimney (stops when the fire dies at the Cousins round).
- **The crash site:** the transport plane wreck in the field is more detailed. It is burning, with ammunition occasionally cooking off, scattered cargo, a parachute caught on a tree, and the pilot's seat empty (a mystery line from Dutch).
- **Lighting:**
  - Warm lamp pools inside versus cold blue moonlight outside, and fire light flickering on the snow.
  - Volumetric fog in the field and god-rays through the stable gaps.
  - Lamps that sway when artillery lands nearby.

**Acceptance:** screenshots from the spawn, the upstairs window, the stable, and the field edge show the layered landscape, planes, and distant battle. FPS stays at 60+ with 24 zombies.

## 8. MAP 0: SMALL-DETAIL POLISH PASS (room by room)

Go room by room (taproom, upstairs rooms, stable and hayloft, cellar, exterior) and write a checklist in `docs/MAP0_POLISH.md`, then do it. Every room needs:
- **Story props:** half-eaten meals, an overturned chair, a calendar on December 1944, the aunt's apron on a hook, the cousins' drawings and clothes upstairs, the patrol's abandoned gear and a map with a circle around Kaltenbrunn, the radio with handwritten frequency notes.
- **Surface variety and wear:** worn floorboards, scuffed paint, water stains, cobwebs in corners, snow drifting through broken windows, and frost and grime decals.
- **Reactive details:**
  - Bottles and glasses shatter when shot.
  - Hanging lamps swing when hit.
  - Hay puffs when you walk through it.
  - Curtains move in drafts.
  - Doors creak.
  - Bullet holes and scorch marks persist (pooled, capped).
  - Footprints in the snow outside (player and zombie, fading over time).
- **Audio zones:** fireplace crackle, wind howl near broken windows, stable creaks and a horse whinny early (the horse is gone later; don't show what happened), dripping in the cellar.
- **Readability stays first:** buyables, doors, and windows must still read instantly. Keep the clutter out of the paths.

**Acceptance:** before/after screenshots of every room; no new navmesh snags (run a 10-minute zombie pathing soak test).

---

## 9. FINISH
- Run the full test suite, `tools/ads_check.gd`, and the screenshot capture.
- Update `PLAY.bat`'s dev menu with direct buttons: "Map 0 — round 5 (Jakub)", "Map 0 — round 10 (Cousins)", "Kaltenbrunn — Totenglocke test", "Weapon range — ADS check".
- Update `morning/MORNING_REPORT.md` with each section marked works / partly / not started, a "try this first" list, clips and screenshots, decisions made, and questions for me.
