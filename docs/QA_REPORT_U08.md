# QA report, UPDATE 08 (tier IV perks, the bots' late kit, bots finish every egg)

Work order: `docs/work_orders/UPDATE_08.md`. Decisions: `docs/DECISIONS.md` T-129 (tier IV), T-130 (the late kit),
T-131 (the eggs).

Built Gravelight maps: Crossroads Inn (`map00`), Kaltenbrunn (`map01`), Totenhafen (`map02`), Fernflug (`map04a-d`,
one campaign run). Morgenrot and Helvetia Works are not built yet, so they aren't covered here.

How the numbers were taken: `tools/ai_soak.sh`, headless, 60 fixed fps, seed 1, Bot Easter-Egg Help on **Full
Partner**.
- Maps 0, 1 and 2: `--scenario=botmode --bots=3`. Bot mode: the agent plays the human, and three bots follow it.
- Fernflug: `--scenario=fernflug`. The scripted player plus three bots, Act I onward.

BotMetrics now also logs:
- each player's Scrip at every round start;
- every perk tier change;
- every egg step done or failed.

These go to the run CSV in `logs/ai_runs/`, which is git-ignored. The baseline runs for Maps 0–2 started in the same
second and shared a run id, so their CSVs overwrote each other. The per-round detail below is from Map 0's CSV; Maps
1, 2 and 4 come from each run's summary line and its `[ee]` log.

## Baseline (before UPDATE 08: master 6874e80 + the logging)

| Map | End | Rounds | Game min | Bot downs (per round) | Human downs | Scrip spent (squad) | Egg |
|---|---|---|---|---|---|---|---|
| Crossroads Inn | wipe | 20 | 34.6 | 6 (0.30) | 1 | 151,250 | **complete** ("Glasmacher Calling": the notes, then the radio tuned by Peg and Dutch) |
| Kaltenbrunn | wipe | 12 | 20.4 | 5 (0.42) | 4 | 45,850 | stuck at **s1_vault** (s3_build done) |
| Totenhafen | wipe | 11 | 14.8 | 3 (0.27) | 3 | 15,100 | the map has no egg |
| Fernflug (Act I) | wipe | 10 | 13.8 | 4 (0.40) | 7 | 27,450 | s1_power done; s2_files "not_found"; s4_tunnel cancelled ("the player left") |

### Deaths per round (Crossroads Inn)
Downs by round, all players: rounds 1–9: 0, then:

| Round | 10 | 11–15 | 16 | 17 | 18 | 19 | 20 |
|---|---|---|---|---|---|---|---|
| Downs | 1 | 0 | 1 | 0 | 1 | 0 | 4 (the wipe) |

### The Scrip curve (Crossroads Inn)
Each player's purse at the start of a round. P1 is the agent; P2–P4 are the bots; P9 is Jakub, who has no purse.

| Round | P1 | P2 | P3 | P4 |
|---|---|---|---|---|
| 1 | 500 | 500 | 500 | 500 |
| 5 | 1,385 | 2,180 | 4,805 | 2,640 |
| 10 | 5,180 | 4,240 | 6,135 | 5,765 |
| 15 | 9,010 | 10,150 | 8,290 | 4,385 |
| 20 | 6,210 | 655 | 18,335 | 11,230 |

### The perk-tier timeline (Crossroads Inn)
- **Round 4:** four tier IIs (Second Wind, Magpie ×2, Overclock).
- **Round 8:** Ironhide II.
- **Round 10:** Ironhide II and Second Wind II.
- **Round 12:** Ironhide II and Trigger II.
- **Round 15:** Second Wind II.
- **Round 17:** the first tier III (Ironhide III).
- **Round 18:** three more tier IIs.
- **Round 19:** Second Wind III.

Nobody had 12,000+ to spare before round 17. Tier IV only comes in reach in the late game, which is what the work
order intends.

### Egg progress and why it stopped (baseline)
- **Crossroads Inn:** completed by the bots. Full Partner bots do the notes; the agent plus a bot tune the radio.
- **Kaltenbrunn ("Requiem for Kaltenbrunn"):** s3 (the parts) done. **s1 (charge the vault's pylons) stuck**: "can't reach Pylon_H", "couldn't use Pylon_F". A pylon only starts with a human within 22 m (`start_needs_player_m`). Further blockers found in the code survey:
  - `player_bot.json` has no `egg` block for map01, so the bot-mode agent never works the Requiem.
  - **s4:** the bell is a `risky:"shoot"` stage that needs an upgraded gun, and there are no Foreman tactics in the Chapel.
  - **s7:** the drummer's crate pull runs only when ordered.
  - **s9:** the Heartstorm is `start:"player"`, and nothing lets a bot or the agent start it.
- **Totenhafen:** no egg on the map, so nothing to complete.
- **Fernflug ("Kündigung"):**
  - s1 done.
  - s2_files "not_found" (the files must be seen first).
  - The s4 tunnel escort is cancelled when the player is away.
  - Boss steps (s5, s7, s13, s17) are escort-only.
  - Player-only `final` steps: s6, s10, s11b (Peg's choice), s14, s18.
  - s12b needs `power`, which isn't in the quest's `bot_knowledge`.

## After (UPDATE 08)

*(filled in at the end of the run)*
