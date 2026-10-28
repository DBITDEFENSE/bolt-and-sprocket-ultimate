# UPDATE 08 — TIER IV "PERMA PERKS", LATE-ROUND BOT KIT, BOTS FINISH EVERY EASTER EGG

A work order for the `bolt-and-sprocket-ultimate` repo. All earlier rules still apply (data-driven tuning, tests, commits, a `PROGRESS.md` resume line, no real Nazi symbols).

**Runs fully unattended:** never pause for approval and never ask me questions. Make every call yourself, log it in `docs/DECISIONS.md`, fix what you find, and merge to `master` when all tests and smokes pass. If you hit a usage limit, checkpoint `PROGRESS.md` so rerunning this prompt resumes where you stopped.

**When to run:** if Update 07 (Map 4) is still in progress, finish its full-playthrough soak first, then do this. In a cloud session, run `tools/cloud_setup.sh` first.

---

## 1. FULL PLAYTHROUGH FIRST
Before changing anything, run a full headless playthrough of every built Gravelight map with bots: Crossroads Inn, Kaltenbrunn, Totenhafen, and Morgenrot, Helvetia Works, and Fernflug if built. Use bot mode plus the soak tools. Record a baseline in `docs/QA_REPORT_U08.md`:
- rounds reached;
- deaths per round;
- the Scrip curve;
- the perk-tier purchase timeline;
- Easter-egg progress per map (which step the bots got stuck on, and why).

The same report gets an "after" section at the end.

## 2. PERK TIER IV — "PERMA PERKS"
Every tonic gets a **fourth tier** on top of the existing II/III system (data: `perks.json` `tiers`).
- **Requirement:** tier III of that perk is owned, and the power is on. Buy it at that perk's machine.
- **Cost:** **12,000–15,000 Scrip**, set per perk by how strong it is (e.g. Ironhide, Second Wind, and Packmule at 15,000; Hawkeye and Marathon at 12,000). Every price lives in data.
- **Effect 1, the big one: it becomes PERMANENT.** A tier-IV perk is **never lost when you go down**: not on a down, not on a bleed-out-and-respawn in co-op, and not on a downed-state reset. It stays for the rest of the match and carries through campaign transitions like everything else. It still counts toward the perk cap of 6.
- **Effect 2: one new great effect per perk.** Design one per tonic that's clearly stronger than tier III and fits its lore. Starting ideas to improve on:
  - **Ironhide Stout:** after taking a hit that would down you, you become invulnerable for 3 s, once per round.
  - **Second Wind Schnapps:** revives are instant, and the revived player gets 5 s of invulnerability. In solo, self-revives refill once per 10 rounds.
  - **Trigger Tonic:** reloading the last bullets of a mag fires a free burst of shock rounds.
  - **Twin Barrel Bitters:** every 10th bullet hits twice.
  - **Marathon Malt:** sprinting through zombies knocks them down.
  - **Hawkeye Brandy:** headshot kills chain a half-damage shot to the nearest zombie.
  - **Packmule Porter:** the third weapon slot also refills its ammo by 10% per round.
  - **Blastproof Bock:** your slide shockwave doubles and kills crawlers outright.
  - **Fine Print Fernet, Overclock Cordial, and the two Map 4 tonics:** design to match.
- **Presentation:** the bottle cap on the HUD gets a gold rim and a "IV" mark, plus a unique machine animation and jingle sting on purchase, and a voice line per character ("This one's mine for good."). The Objectives/pause UI shows each perk's tier.
- **Balance:** check in the soak that tier IV makes rounds 30+ feel strong but not trivial. Log before/after numbers. Classic Rules mode keeps tiers off.
- **Tests (GUT):** the tier gate, prices, permanence through down/revive/bleed-out/campaign carry, cap interaction, each tier-IV effect, and the save/load of tier state.

## 3. BOTS AFTER ROUND 25: LATE-GAME KIT
- **Any bot that spawns or respawns at round 25 or later** (including bots joining mid-match and bots coming back after a bleed-out) spawns with:
  - **one random tier-III perk** (on top of their existing random bonus perk; no duplicates, chosen from the perks available on that map);
  - **a Thompson upgraded to Crucible level 2** ("Chicago Lament" at tier 2, using the existing Crucible tier system), with full ammo.
- Bots already alive when round 25 starts get the same kit at the start of round 25.
- All of it is data-driven (`bots.json`: `late_kit_round: 25`, the perk tier, the weapon id, the Crucible level) and respects the "Bot Bonus Perk" and Classic Rules toggles.
- The bot's nameplate shows the new perk, and bots say an in-character line when they gear up.
- **Tests:** a bot spawning at round 24 gets no late kit, one at round 25 does, and an already-alive bot upgrades at round 25.

## 4. BOTS MUST BE ABLE TO FINISH EVERY EASTER EGG
**Map 2 (Kaltenbrunn, "Requiem for Kaltenbrunn")** is the known failure: bots get through the power, the doors, and the Totenglocke, but don't finish. Do the same check for every other built map.
1. **Find exactly where each map's egg breaks** for bots: run the Full Partner mode soak (Update 04 §5) and bot mode, several runs, and log the stuck step and the cause. Candidates to check:
   - steps with no `bot_task` defined;
   - puzzle info (codes, melodies, bell order) not reaching the blackboard;
   - the lift or other navigation the bots can't use (they can't ride the Kaltenbrunn lift);
   - boss-gated steps (killing the Foreman in the Salt Chapel while the bell is lit);
   - timing steps (the drummer walking away, the Heartstorm holdout);
   - steps marked player-only that don't need to be.
2. **Fix each one:**
   - add or repair the `bot_task` data;
   - teach bots the lift, or give them the stairs route;
   - make sure discovered info is shared;
   - add boss-fight tactics where a step needs a specific kill;
   - make the final holdouts winnable for a bot squad.

   Keep the rules from Update 04: bots never sequence-break, never fail the egg by guessing, and story choices stay with the player. **In Full Partner mode, a bot can now make a story choice's default pick** if the player is absent or downed, so the egg can finish.
3. **Bot-only completion:** in bot mode (the local agent playing my character) plus Full Partner bots, **every built map's main egg must be completable start to finish with no human input.**
   - Acceptance: the main egg is completed in **at least 3 of 5 soak runs on Kaltenbrunn**, and at least once on every other built map.
   - Report the success rate and the average completion time per map.
4. **Tests:** a GUT test per egg step that checks a `bot_task` exists or the step is explicitly marked player-only with a reason. A smoke per map that drives the egg with bots and asserts completion within a time budget.

## 5. FINISH
- Rerun the full playthrough from §1 and fill in the "after" section of `docs/QA_REPORT_U08.md`: the egg completion rates, tier-IV balance numbers, and the late-kit effect on bot survival.
- Add `Play.bat` buttons: "Kaltenbrunn — bots finish the egg (watch)", "Perk tier IV test (50,000 Scrip, power on)", "Round 25 bot kit test".
- Merge to `master` and push.
- Write `morning/MORNING_REPORT.md` for a player: what's new, how to try it, the egg success rates, anything still not working.
- Tell me the one line to paste into Claude Code on my PC to pull it.
