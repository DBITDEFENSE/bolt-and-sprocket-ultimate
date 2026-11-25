# Morning report: 2026-11-24 (cutscenes, the tower's ladders, the V2 site, the map detail pass)

**Everything is on master and pushed.** Nothing was shown on your screen: pictures came from software renders under
WSL, everything else ran headless. Full unit suite on the final master: 2,649 tests, 2,648 passing, 1 risky (the known one); check_scripts 1,029 scripts, 0 failed.

## 1. The cutscenes are photoreal (T-277)
- The three history cutscenes (Lazarus Saturday, Fourth Day, Staub) now play as real-looking film in the campaign.
- How: each of the 49 shots was recorded in-engine, then Higgsfield (Seedance 2.5, video edit) re-rendered it as
  live-action footage, keeping the same camera, timing and layout. Colour, with a light film grain.
- Every shot was checked against its recording. 10 were redone (lettering kept from the game, modern lane
  markings on a 1930 road, mannequin-like soldiers). Cost: about 1,580 credits; about 940 left.
- The 3D versions are still there (`engine:` in the Archive). Pictures: `.smoke_logs/reel_wire/` (not committed).
- The loading screen clips now play through (up to 20 s) instead of cutting at 3 s.

## 2. The watchtower's ladders (T-275)
- The lower ladder now comes up through an opening in the landing's rail; the upper one moved inside the tower and
  goes through a hatch in the top floor with a guard rail. Zombies climb the same way.
- Before/after pictures: `docs/captures/t275/`.

## 3. The V2 site and Rocket Man (T-276)
- Map 0 is bigger: a gate in the east fence ("The Forest Track", 1500) leads through the woods to a V2 firing site.
- The rocket launches on round 6 and every 5th round after: siren, countdown, a blast that kills zombies near the
  table, lift-off. Stand back: up to 45 damage within 7 m.
- **Rocket Man** (2500, in the firing dugout): your explosives hit 1.3x harder and wider, never hurt you, and a
  close blast throws you (rocket jump, about 1 m up). Upgrades add stagger, then fire, then more damage.
- Also there: an STG-44 wall-buy (1200) and an ammo box. Pictures: `docs/captures/t276/`.

## 4. Maps 1-6 brought up to Map 0 (T-271..T-274)
- Kaltenbrunn, Totenhafen and the Fernflug acts got Map 0's kind of detail: new props, ladders and zip lines,
  round events (the tank through the gate, a dive bomber on the boat), perk deals, survivors and openings.

Details and what is not verified: `docs/DECISIONS.md` T-271 to T-277. Your list: `morning/NEEDS_DEVIN.md`.
