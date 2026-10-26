# UPDATE 03 — SMARTER AI SQUAD-MATES (bots + Jakub)

A work order for the existing project. All rules from `ULTIMATE_PROMPT.md`, v2, v3, `OVERNIGHT_RUN.md`, and `UPDATE_02_POLISH.md` (all in `C:\Users\Devin\PROJECTS\bolt-and-sprocket\`) still apply. Work unattended per OVERNIGHT_RUN.md: branch, commits, `PROGRESS.md` resume line, `main` always launches, `PLAY.bat` updated, morning report at the end.

**The goal:** the bots should feel like **good human teammates who know classic zombies**. They train zombies in loops instead of camping in corners, revive smartly, spend Scrip wisely, call things out, and never get in the way. A player should want them around, not tolerate them. The same brain runs **Jakub** (UPDATE_02 §6), with his own personality settings.

---

## 0. FIRST: MEASURE THE CURRENT BOTS

Before changing anything:
1. Read the existing bot code and write a short summary in `docs/BOT_AI.md` (architecture, what decides what, known hacks).
2. Build the **bot metrics logger** (§9) first. Run a **baseline soak test**: 3 bots + 1 scripted "player" dummy that trains around Map 0, played from round 1 until the squad wipes, 3 runs.
3. Record the baseline numbers in `docs/BOT_AI.md`: highest round reached, bot downs per round, revive success rate, time stuck, friendly blocking events, Scrip wasted, ammo-empty moments.

Every change below must **beat the baseline** on these numbers. Put the before/after table in the morning report.

## 1. ARCHITECTURE: a utility-AI brain on a data-driven blackboard

Replace any if/else decision soup with a **Utility AI**:
- Each tick (staggered: bots think at ~5 Hz, not every frame), every **Action** scores itself from 0 to 1 using response curves over **Considerations**. The bot runs the highest-scoring action, with **hysteresis** (a +0.1 bonus for the current action) so it doesn't flip-flop.
- **Actions:**
  - Fight
  - Train (kite the horde)
  - Hold position
  - Revive
  - Retreat
  - Reload safely
  - Repair barricade
  - Buy (weapon, perk, ammo box, door)
  - Use the Mystery Crate
  - Collect a power-up
  - Follow leader
  - Regroup
  - Escort (Jakub)
  - Use a trap
  - Idle chatter between rounds
- **Considerations** (all normalized 0–1):
  - own HP %, own ammo % (mag and reserve), threat pressure (§2), distance to nearest zombie, number of zombies within 5 m / 10 m
  - teammate downed and bleed-out timer, path length to the target, Scrip available vs. cost, round phase (early / mid / break)
  - leader distance, line of sight, whether the action is on cooldown, personality weights (§8)
- All curves and weights live in `/data/gravelight/ai/*.tres`. Tuning must not require code changes.
- **Blackboard:** a shared squad blackboard holds known zombie positions, claimed tasks (who's reviving whom, who's repairing which window), the current training-loop route, the leader, danger zones (traps, fire, Bell Dome, Paul's leaps), and power-up locations.
- **The layering:** the brain decides WHAT to do; a separate **Locomotion layer** decides HOW to move (§3); an **Aim layer** handles shooting (§4).

## 2. PERCEPTION & THREAT ASSESSMENT

- **Senses:** sight (a 110° FOV cone + line-of-sight raycasts, budgeted), hearing (gunfire, barricade tearing, boss audio cues, the Slender's key jingle going silent), and **squad callouts** shared via the blackboard. No wallhacks: bots only know what they or a teammate perceived, with a memory that decays over 4s.
- **Threat score per zombie** = proximity × speed tier × type multiplier (sprinter > runner > walker; Glasshide, Treibstoff-Gänger, and bosses weighted up) × "is it targeting me or a downed teammate" × "is it behind me."
- **Threat pressure** = the sum of nearby threat. It drives Retreat vs. Fight vs. Train.
- **Special-enemy knowledge** (data per enemy type, `ai_counters.tres`):
  - **Glasshide:** aim for the head or use explosives.
  - **Treibstoff-Gänger:** don't kill with fire near teammates.
  - **Frostbiss:** keep distance.
  - **Bergwacht:** watch the walls.
  - **The Cousins:**
    - The Hammer: shoot her while the mallet is in flight.
    - The Reach: shoot the wrists, break grabs on teammates immediately.
    - Alix: NEVER get within 2 m, and focus her down when she holds a fallen cousin's hand.
  - **Paul:** shoot the IV bottles when rage > 66, don't stand in his leap-shadow, flank to his neck.
  - **The Slender:** stay in light, don't stare, don't shoot decoys (read lantern flicker), shoot his lantern when a teammate is quarantined.
  - **Bosses in general:** spread out, and never all stand in one cone.

## 3. MOVEMENT & POSITIONING (the biggest upgrade)

- **Training loops:** each map has authored **training-loop routes** (`TrainingRoute` resources: a closed spline + the open-space ring it sits in). Map 0 needs the taproom-to-stable loop and the cellar barrel stack. Kaltenbrunn uses the Minehead Yard headframe, the Salt Chapel pews, and the Generator Hall. Each later map gets them in its milestone.
  - **Bots know how to train:** when zombie count and threat pressure are high, a bot joins the leader's loop (or runs its own if the squad is split), runs the route **slightly ahead of the horde**, turns to fire in bursts at the train's head, and keeps the train tight.
  - A **"don't get cut off" check:** before committing to a path segment, it raycasts and samples zombie density ahead, and reverses direction if the path is blocked.
- **Holding:** in early rounds (1–6), bots **hold windows in pairs**, repairing between kills. Later they shift to training. They switch smoothly based on the utility scores, not a fixed round number.
- **Never block the player:**
  - Bots keep a **personal-space bubble** around players (1.2 m).
  - They step aside when a player walks toward them, and never stand in doorways, stairs, or the player's training line (sampled from the player's velocity).
  - Use NavigationAgent3D avoidance with players as obstacles of higher priority.
- **Smart pathing:**
  - Navmesh costs are higher near zombies, traps, fire, the Bell Dome edge, and Paul's ground-pound circles.
  - They use doors and stairs correctly, and the Kaltenbrunn lift only when the whole squad rides (or never, if a zombie train is near).
  - They don't path through unopened doors.
- **Stuck recovery:**
  - Detect no progress for 2s → repath.
  - After 4s → nudge (local random walk).
  - After 8s → a teleport-to-nearest-safe-navpoint **only when no player can see the bot** (and log it, because every teleport is a bug to fix).
- **Formation when following:** loose wedge positions relative to the leader, spread so they don't line up in one cone attack.
- **Movement fidelity:** bots use the same movement system as players (UPDATE_02 §1): sprint-out times, slide, mantle. No moonwalking, no instant 180° turns (turn rate limited like a player's).

## 4. AIM & COMBAT

- **Human-like aim:** aim acquires the target with a reaction delay (150–300 ms by difficulty), then converges with small overshoot and tracking error that shrinks over ~0.4s on a steady target. **Headshot preference** rises with weapon accuracy and when the target is slow or close.
- **Fire discipline:** burst-fire SMGs and LMGs at range, single shots with rifles, no firing through teammates (line-of-fire check against friendlies), and no spraying at targets they can't hit.
- **Reload intelligence:** reload when the mag is below 30% **and** threat pressure is low, or when it's empty. Never reload with a sprinter within 4 m (swap to the secondary instead, or knife). Reload after each wave break automatically.
- **Weapon choice:**
  - Swap to the right tool: wonder weapon for crowds, rifle for single high-HP targets, Totenglocke Great Toll only on 6+ tightly bunched zombies, Bell Dome for revives.
  - **Grenades:** only into groups of 4+ that are not near a teammate, and on bosses.
- **Melee:** knife only crawlers or a lone zombie for melee-kill Scrip in early rounds. **Never melee bosses.**
- **Kill-stealing etiquette:** in early rounds, bots don't finish zombies the player is clearly farming for points (low HP and being shot by a player) unless the player's in danger.

## 5. TEAMWORK: REVIVES, CALLOUTS, SHARING

- **Revive logic** (claimed on the blackboard so two bots don't both go):
  - The nearest healthy bot with a safe path claims it.
  - If threat at the downed spot is high, a second bot **covers** (fights facing outward), or throws a Siren Gramophone or uses a Bell Dome first.
  - **Never start a revive with a sprinter within 6 m** unless the bleed-out timer is under 10s.
  - Last-chance logic: under 8s of bleed-out, go anyway.
  - With Second Wind, the revive time drops; factor that into the scores.
- **Prioritize the human player**: player revive > bot revive > Jakub revive.
- **Callouts** through the VOManager with cooldowns (in-character lines from VO_SCRIPT, with subtitles), each also flashing a **small world-space ping** at the location:
  - "Sprinter, behind you!"
  - "Going down!" / "I've got you!" / "Reloading!"
  - "Resupply by the stable!" (our own power-up names only, never another game's)
  - "Crate moved to the barn!" / "Boss incoming!" / "I need ammo!" / "Window's open, upstairs!"
- **Power-ups:**
  - Bots don't grab Death's Door / Double Scrip at a bad moment; they leave them for the player, or grab them only when the player is nearby too.
  - They always grab Resupply and Fortify when it's safe.
  - They **never** grab a power-up the player is clearly walking toward.
- **Squad roles**, assigned dynamically and shown in the debug overlay: **Anchor** (holds the main spot), **Runner** (trains), **Medic** (revive priority), **Builder** (repairs, builds parts if allowed). Personality (§8) biases who gets which.

## 6. ECONOMY & PROGRESSION BRAIN

- **Each bot has its own Scrip** (earned the same way players do). Spending plan by priority:
  1. Perks in a sensible order (Ironhide first, then Second Wind in co-op, then Trigger Tonic or Twin Barrel by weapon type).
  2. A good wall weapon for the round (no more Kar98k at round 15).
  3. Ammo boxes when reserve < 25%.
  4. Opening doors only if the player has opened that path or the bot is told to.
  5. Mystery Crate when Scrip > 2,500 and its weapon is weak for the round.
  6. The Crucible only with a weapon worth upgrading.
- **Never spend the party into a corner:** bots keep a **reserve** (enough for one revive-critical perk rebuy and one ammo box).
- **Never touch Easter-egg objects, traps, or the power switch** unless the player commands it (command wheel) or the player has already done that step. Bots never steal a Crucible weapon. Bots never take the crate weapon the player rolled.
- **Command wheel** (from UPDATE_02), expanded: Follow · Hold here · Train with me · Repair windows · Revive priority · Buy perks now · Save Scrip · Go open [door you're looking at] · Fetch part [buildable you're looking at]. Each order is a high-weight action that decays after 60s or on completion.

## 7. DIFFICULTY & FAIRNESS

- **Bot Skill setting:** Recruit / Veteran / Elite. It scales reaction time, aim error, decision quality noise, and spend smartness. Default Veteran.
- **Bots never cheat:** no infinite ammo, no hidden health buffs, no perception through walls. The bonus perk (UPDATE_02 §5) is their only advantage, and it's visible.
- Bots should **lose sometimes**. Target on Veteran: bots alone (no player) survive to around round 20–25 on Map 0. They should not solo the game.

## 8. PERSONALITY (each bot plays like its character)

Personality is a weight profile in `ai_personality_<char>.tres`:
- **Dutch:** Anchor. Holds ground, aggressive with LMGs and the BAR, slow to retreat, loves melee on crawlers. Grumbles when told to move.
- **Peg:** a tactician. Best grenade and explosive use, prefers to flank, calls out bosses and specials first, saves Scrip.
- **Deacon:** Medic/Builder. Highest revive priority, repairs barricades every break, picks up buildable parts when allowed, talks to machines.
- **Wren:** the precision shooter. Takes high ground, prefers rifles, best headshot rate, kills specials first, keeps a running kill tally in her callouts.
- **Bolt** (when unlocked): reckless Runner, loves the Kinderhammer and melee, and Sprocket comments on his decisions.
- **Vendelin** (when unlocked): cautious, keeps distance, is very good with perk economy, avoids fire.
- **Jakub:** careful, conserves ammo, prefers bolt-actions, refuses perks, always covers the player who freed him, and never runs ahead. Under fire he stays steady. He has seen worse.

## 9. DEBUG TOOLS & TESTING (required)

- **AI debug overlay** (dev console `ai_debug 1`): above each bot, show the current action, its top 3 action scores, its role, its target, and its path line. A blackboard panel shows claimed tasks. A threat heatmap can be toggled on the floor.
- **Metrics logger:** per run, write a CSV to `logs/ai_runs/`: round reached, kills/headshots per bot, downs per bot per round, revive attempts / successes / time, stuck events and teleports, blocking events (bot inside a player's personal space while the player moves), Scrip spent by category, empty-mag moments, and command-wheel response time.
- **Soak tests** (`tools/ai_soak.gd`), runnable headless at an accelerated time scale:
  1. 3 bots + scripted player, Map 0, 3 runs to wipe.
  2. 3 bots alone, Map 0.
  3. A Cousins round test (forced spawn at round 10).
  4. Kaltenbrunn rounds 1–20 with Paul forced at 15, if the map exists.
- **GUT unit tests:** utility scoring picks the expected action for hand-built scenarios (low ammo + low threat → reload; downed player + sprinter near → cover first, then revive; high threat + loop available → train); revive-claim exclusivity; spending priorities; the never-touch-EE rule; the personal-space bubble.

## 10. ACCEPTANCE (all must pass; put the results in the morning report)
- Every baseline metric from §0 improved, shown in a before/after table. Target: **stuck events and teleports cut by 90%**, **zero sustained player-blocking events** in soak runs, **revive success above 85%**, **no bot buying a Kar98k after round 10**.
- A **clip** of 3 bots training a zombie train with the player on Map 0 round 15+, including a revive under pressure and a callout ping.
- A **clip** of the Cousins round where the bots focus correctly (shoot the mallet window, break a Reach grab, avoid Alix).
- Jakub uses the same brain with his personality, and both of his armed/unarmed modes work.
- 60 FPS holds with 3 bots + Jakub + 24 zombies (bot thinking within a **0.5 ms per bot** average budget; profile it and show the number).

## 11. FINISH
- Add `PLAY.bat` buttons: "Bot test — Map 0 round 15 (3 bots)", "Bot test — Cousins round", "Bot soak (headless, writes CSV)".
- Update `docs/BOT_AI.md` with the final architecture, tuning guide, and metrics.
- Write the morning report with each section marked works / partly / not started, the metrics table, clips, the decisions you made, and questions for me.
