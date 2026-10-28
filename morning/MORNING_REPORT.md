# Morning report — UPDATE 08, 2026-10-28

**Tier IV "perma perks" and the bots' round-25 kit are in and merged.** Getting bots to finish every Easter egg is
partly done: Map 0's egg is finished by bots. Kaltenbrunn's now gets through the power, the parts and the first
pylon, but not the whole Requiem yet. Also merged today: the plane wreck with its trapped pilot, Jakub drinking
tonics, the fence fix outside the barn, and the gunplay pass (tracers, hitmarkers, sights).

## How to try it
Double-click **`Play.bat`**. The dev launcher has a new **Update 08** block:
- **Perk tier IV test (50,000 Scrip, power on, round 15).** Walk to a perk machine and brew one tonic I → II → III → IV. At IV, the machine glows gold and plays a sting, your survivor says "This one's mine for good," and the HUD cap gets a gold rim and "IV". Go down: that tonic stays.
- **Round 25 bot kit test.** Map 0 at round 25 with 3 bots. Each bot gears up with a Chicago Lament II and a tier III tonic, and says a line about it.
- **Kaltenbrunn — bots finish the egg (watch).** Bot mode plays your survivor, and three Full Partner bots work the Requiem. They get partway; see below.

## What's new
**Tier IV perks.** Every tonic has a fourth tier, 12,000–15,000 Scrip. You need tier III and the power on. A tier IV
tonic is **permanent**: you keep it when you go down, when you bleed out and respawn, and on the next map. It still
counts toward your cap of 6. Each tonic also gets a new effect:

| Tonic | Tier IV effect |
|---|---|
| Ironhide | Once a round, a hit that would down you leaves you on your last breath, with 3 s where nothing hurts you. |
| Second Wind | Instant revives and 5 s of safety for the revived. Solo: a spent self-revive comes back every 10 rounds. |
| Trigger Tonic | Reload a nearly empty mag and the next 6 rounds are shock rounds: harder, and they knock zombies down. |
| Twin Barrel | Every 10th bullet hits twice. |
| Marathon | Sprinting into zombies knocks them down. |
| Hawkeye | A headshot kill fires a half-strength shot at the nearest zombie. |
| Packmule | Every round, every gun gets 30% ammo back and a full mag. |
| Blastproof | The slide shockwave is twice as strong, reaches 5 m, and kills crawlers outright. |
| Overclock | The burst recharges faster and rings twice at full strength. |
| Skyhook | Two air hops, and a bigger, harder landing stomp. |
| Magpie | Drops come more often, last longer, and every 12th is a power-up. |

Classic Rules turns all tiers off.

**Bots after round 25.** Any bot that spawns, respawns or gets revived at round 25 or later, and every bot alive when
round 25 starts, gets a tier III tonic (a different one per bot) and a Chicago Lament II with full ammo. The "Bot
Bonus Perk" setting or Classic Rules turns it off.

**Bots and the Easter eggs (still in progress).**
- **What changed:**
  - In bot mode, the AI playing you now does *your* egg steps too: last inputs, starting the Heartstorm, story choices (it takes the default).
  - On Full Partner, if you're down or away at Peg's choice on Map 4, the bots take the canon pick after 20 s. If you're there, it's always your choice.
  - Two pieces of missing data that blocked Map 4's egg are fixed.
- **Kaltenbrunn results:**
  - The bots now get through the power, the parts and the first pylon.
  - Five specific blockers were found and fixed along the way (the full list is in `docs/QA_REPORT_U08.md`).
- **Not done yet:** the bots don't yet finish the other pylons, the Chapel bell and the Foreman, the drummer, the Totenglocke charge or the Heartstorm.

## Egg success rates (bots only, no human input)
| Map | Completed |
|---|---|
| Crossroads Inn | 1/1 |
| Kaltenbrunn | 0/6 (furthest: first pylon) |
| Totenhafen | no egg on this map |
| Fernflug | 0/1 (only the baseline run, before the fixes) |

The target was 3 of 5 on Kaltenbrunn and at least one on every map. That's **not met yet**. The work continues from
the resume line in `PROGRESS.md`.

## Also fixed today
- **Bots no longer lose their gun in the Crucible.** They always go back for it.
- **Map 0, outside the barn:** the yard fences were never drawn, so they acted as invisible walls. They're visible now, you can shoot over them, and the empty crate spot by the well is no longer a hidden box.
- **The plane wreck** is hollow: walk in through the cargo door or the torn hole on the low side. **Flt Lt Selwyn** is pinned in the cockpit. Give him a spare gun and he shoots zombies out of the nose, and asks for ammo when he runs dry.
- **Jakub** can be sent for a tonic from his Talk card (you pay).
- **Gunplay:** tracers fly to the hit; Crucible guns fire violet tracers. Hitmarkers are punchier and build on streaks. Kills have a ring and their own sound. Fixed the Garand and M1 Carbine apertures and the trench gun's hammer covering the bead.

## Tests
All unit tests and the touched smoke tests pass (numbers in `PROGRESS.md`). Nothing here was checked in a rendered
game except the sight pictures, which you OK'd. Please have a look at the yard fences, the wreck and Selwyn.
