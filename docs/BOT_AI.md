# GRAVELIGHT bot AI

Update 03 rewrites the AI teammates' brain. This file starts with the brain as it was before the rewrite and the
**baseline** numbers the rewrite has to beat (Update 03 section 0). The measuring tools are described after that
(section 9: the metrics logger and the soak test). The player-facing notes stay in `docs/gravelight/BOTS.md`.

## 1. The bots before Update 03 (T-031, plus later additions)

Code: `gravelight/bots/`. Tuning: `data/gravelight/bots.json`. The pure rules are in `bot_config.gd`
(tested in `test_bots.gd` and `test_bot_planner.gd`).

### Who decides what

| Piece | Job |
|---|---|
| `MapRoot` | In a solo match with `GameState.bot_count > 0`, it spawns a bot `Player` (`is_bot`) for each empty survivor slot (ids 2–4), starts an offline `NetMatch` that runs the co-op life cycle (down, bleed-out, revive, respawn, wipe), and adds a `BotSquad`. Round size counts each bot as 0.75 of a player (`scaling.bot_player_weight`). |
| `BotSquad` | Holds what the bots share. It hands out the **spawn kit** (a Thompson, Ironhide Stout and Second Wind, all free), decides **who leads** (the human, or the first standing bot when the human is spectating), and decides **who revives whom** (the human first, then bots; the nearest standing bot that isn't busy). It keeps the **claims** on errand objects (one bot per window or machine, cleared every round), the **kill-share** ledger, and the squad's **callouts** (survivor VO lines, one at a time, with a 7 s cooldown). |
| `BotBrain` | One per bot. A **mode machine**, re-decided at 8 Hz (`perception.think_hz`, staggered 0.05 s between bots). Movement, aiming and firing run every physics frame. |
| `BotPlanner` + `LocalAI` | Optional, on one bot only (`local_ai.bot_index`). Every 4 s it lists objectives (easter-egg steps, the power, doors, shopping, "stick with the team"), each with a score. A local Ollama LLM picks one, or the highest score wins when the model is offline, slow or answers nonsense. The pick becomes that bot's errand. With `GameState.bot_ai_mode = "off"` there is no planner at all. Every soak run uses that setting. |

### The modes (`BotBrain._decide_mode`, in priority order)

1. **REVIVE.** `BotSquad.revive_target_for(self)` names a downed teammate. The bot goes unless it is swarmed (a
   zombie within 3 m **and** either hurt below 40% or 3+ zombies within 6 m), but goes anyway when the target has
   15 s or less of bleed-out left. On arrival it holds for `revive_seconds` (4 s, or 2 s with Second Wind) by
   calling `coop.set_reviver` directly. It stops to shoot while a zombie is within 3 m and more than 15 s of bleed-out remain.
2. **FLEE.** A zombie within 3 m and (hurt, crowded, or the gun is dry). The bot kites to an open navmesh point 4–6.5 m
   away, picked from 12 directions, away from the zombies' centroid and toward the leader, and shoots on the move. It keeps
   fleeing for at least 1.2 s and while anything is within 4.8 m.
3. **FIGHT.** It has a target. Target choice: every active zombie within 26 m is scored (distance, minus a bonus
   when it is near a teammate, attacking, or at a window). The bot skips zombies the human is aiming at when the
   kill-share rule says the human is short of kills, then takes the first of the best 3 with a line of sight.
   Aim turns at the skill's rate. The error settles from `aim_error_deg` to `settle_error_deg`, and the bot fires
   inside `fire_tolerance_deg`, in bursts for automatics. It reloads, swaps to a loaded gun with a zombie within 6 m,
   and knifes anything within 1.7 m. It backpedals from zombies inside 2.6 m and moves to its slot if the leader gets far.
4. **ERRAND** (only when quiet: no zombies, the round break, or the nearest zombie beyond 7 m with 3 or fewer
   left). The highest score wins: boards within 9 m (30 minus distance), wall-gun ammo under 35% reserve (60), an
   ammo box (62), a perk from round 3 (45, up to 4), a better wall gun from the wishlist (20 + price/50), a door
   (25; the one the human looks at or stands nearest; 300 Scrip reserve; at most 1 per round, 20 s into the round),
   the Crucible from round 8 in the break (80). Everything must be within 24–30 m of the leader. Errands time out
   after 20 s. Bots never flip the power.
5. **FOLLOW.** A formation slot 3.2 m from the leader at 140°, −140° and 180°. If the slot is off the navmesh, the bot tries the same slot closer in, mirrored, or straight behind. It stays out of the leader's
   20° line-of-fire cone (sidesteps 1.8 m after 0.35 s in it) and out of doorways (1.3 m). It sprints beyond 11 m.
6. **DOWNED.** It lies still and shoots the pistol at whatever is within 14 m.
7. **OUT.** It bled out and spectates until the next round. It respawns with the start pistol, and the kit gives back the Thompson and the perks.

### Perception

- 8 Hz. Each think reads **every active zombie on the map** from the director (`active_zombies()`): there is no
  sight cone, no hearing and no memory. Awareness is omniscient, and only **shooting** needs a line of sight
  (at most 3 rays per think, from the eye; walls and closed doors block).
- "Danger" and "crowd" are plain distance counts (3 m, and zombies within 6 m). No threat types, speeds or "is it
  coming for me."
- The bots don't collide with each other. `_move` pushes apart anything inside 1 m of any player (bots and
  humans), which is the only personal-space rule.

### Known hacks and hard-coded behaviour

- **Teleports.** In FOLLOW, if the leader is more than 14 m away and the path is finished or empty for 8 s, the bot
  teleports to a navmesh point 2.2 m behind the leader. The leader must be able to see that point; nobody checks
  whether anyone can see the **bot** vanish. It also teleports when it falls below y = −20. The count is `BotBrain.teleports`.
- **Stuck handling** in `_move`. The bot is stuck when it moves less than 0.015 m in a frame while it wants to move. It jumps
  after 1.2 s and drops the goal and repaths after 3 s. There is no nudge stage, and nothing else watches for a lack of progress.
- **The free kit.** Every bot starts with a Thompson, Ironhide Stout (250 HP) and Second Wind (2× revive speed)
  at no cost and outside the power rule. The perks come back after every revive, and the Thompson after every
  respawn (`spawn_kit.restore_after_down`).
- **The free pistol ammo.** The start pistol is refilled at every round start (`round_start_pistol_refill`).
- **The claims** (one bot per window, machine or door) are cleared at every round start. The revive assignment is
  "nearest free bot" and is recomputed at every think. The bot doesn't check whether the path is safe.
- **Hard-coded thresholds in code** (not in bots.json): the 0.8 s target-lost timeout, 6 m swap-instead-of-reload,
  60% mag top-up when idle, 1.2 s / 1.6× flee hysteresis, 12 retreat samples 4–6.5 m out, a 0.42 s weapon swap,
  a 0.7 s errand re-pick cooldown, the stuck thresholds above, and an eye 1.55 m up.
- **The shots** are traced in the brain with WeaponHolder's damage rules. The bot's WeaponHolder is inventory only.
  `damage_taken_mult` exists per skill (veteran 0.9).
- **Shopping** only buys a wall gun that ranks higher on the wishlist than the best one it holds. The kit already
  holds the Thompson, so on Map 0 bots never buy a wall gun (only the BAR and StG 44 rank higher, and Map 0 has neither).

## 2. Baseline (before the rewrite)

*(Filled in by the baseline soak, below.)*

## 3. Measuring: the metrics logger and the soak test

*(See below.)*
