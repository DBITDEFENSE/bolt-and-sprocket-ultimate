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

## After (UPDATE 08, this run: partial)

### Egg completion
Bot-only runs: bot mode plays the human, with 3 Full Partner bots. The Kaltenbrunn runs were exploratory: god mode
so the squad lives long enough to reach later steps, 4× speed, `--until-egg`.

| Map | Egg | Runs | Completed | Furthest the bots got | What stopped them |
|---|---|---|---|---|---|
| Crossroads Inn | Glasmacher Calling | 1 (baseline) | **1/1** | complete | — |
| Kaltenbrunn | Requiem for Kaltenbrunn | 6 exploratory | **0/6** | s0 power, s3 parts, **Pylon A charged** (new) | Pylons F/H, then the untested later steps (below) |
| Totenhafen | — | — | — | the map has no egg | — |
| Fernflug | Kündigung | 1 (baseline) | 0/1 | s1 | The baseline used the scripted player; the new data fixes (s12b/s14 knowledge, Peg's default pick) aren't soaked yet |

What the Kaltenbrunn runs found, in order. Each was fixed, then the next run went further:
1. **No egg block for map01:** the agent never worked the Requiem. *Fixed.*
2. **The agent trained underground:** the surface tonics were 80–90 m away, so its plan stalled at Second Wind with 24,000 Scrip in hand, and the Lab door (behind which Pylon H stands) was never bought. *Fixed:* surface loop first, Lab door in the plan.
3. **Pylons waited for "a human within 22 m":** in bot mode the human is the agent, which never brought itself. *Fixed:* the agent counts as the human.
4. **The trainer pulled the agent off a charging pylon:** a charging pylon holds the round open, so the round never ended. *Fixed:* the agent stays while a pylon charges or a holdout runs.
5. **A Full Partner bot fell through the yard by Pylon A** and fell for the rest of the match with its egg step. *Fixed:* a fall rescue for every bot.
6. **Open:** in god mode the agent can kite two straggling crawlers for 30+ minutes while nobody hunts them, so the round doesn't end. This only shows up because god mode stops the wipe.
7. **Not reached by bots yet:**
   - s4: shoot the Chapel bell with a Crucible gun, then kill the Foreman in the Chapel while it's lit.
   - s6: the four bells.
   - s7: the drummer chase.
   - s8b: 30 Totenglocke kills.
   - s9: the Heartstorm holdout. The agent can start it now, but the 120 s hold, with Bellringers and two Foremen, is untested.

Acceptance (3/5 on Kaltenbrunn, at least once on every other map) is **not met**. The egg data test passes for every
step of every built egg (`test_bot_ee`). The per-map "completes within a time budget" smokes aren't written: they
wait on the eggs actually completing.

### Tier IV balance
No soak reached round 30 (the honest baselines wiped at rounds 10–20), so the "strong but not trivial at 30+" check
is still open.

The economy says tier IV comes late: in the Map 0 baseline nobody banked 12,000+ spare before round 17. The
Perk tier IV test button lets you feel it by hand.

### Late kit
Verified by `smoke_late_kit`. Its effect on bot survival past round 25 isn't measured, for the same reason as tier IV:
no run lived that long.
