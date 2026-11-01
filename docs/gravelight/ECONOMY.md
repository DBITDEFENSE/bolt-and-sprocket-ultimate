# GRAVELIGHT: Scrip and getting ahead (T-078)

The base economy (kill Scrip, repairs, prices) is GDD §5; power-up drops are GDD §11. This page covers what
T-078 added so a survivor can afford a real gun, the power's doors, Ironhide Stout and Second Wind before the
runners come (rounds 6-8 on Map 0), without making the late rounds free. Every number is data.

## 1. The round-5 milestone: a tonic bottle and a Resupply

`data/gravelight/rounds.json` `"milestones": {"5": ["tonic_bottle", "resupply"]}`. Any round can get its own list
later (a map or a mode only adds a key). Implemented by `PowerupManager` (`milestone_drops`, `drop_milestone`).

- **When:** the moment round 4's last zombie dies (`round_ended(4)`), once per match.
- **Where:** a step (`powerups.json milestone.ahead_m`, 1.8 m) ahead of the standing survivor nearest that last
  kill, toward it, side by side (`spacing_m`), snapped to the navmesh. Never outside a window, never out of reach.
- **How long:** 60 s (blinking from 50 s), not the usual 30. They don't count toward the 4-drops-a-round limit.
  **Guaranteed:** a milestone drop that runs out uncollected is applied anyway.
- **The tonic bottle** (`tonic_bottle`, "TONIC BOTTLE"; a stoppered amber-violet bottle with a paper label and a wax
  seal, a cork-pop chord when taken): every survivor still in the match (downed counts, bled out doesn't; Jakub
  never drinks) gets a free perk tonic they don't own, at random among the map's perk machines (every perks.json
  tonic if the map has none). No power needed, no Scrip. It respects the cap: with the cap full it brews the next
  tier of a carried tonic instead (only a tier the profile has unlocked by mastery; the tier's round gate is waived),
  and if there is none either it pays `powerups.json tonic_bottle.full_cap_scrip` (1500). Solo Second Wind is never
  given once its machine has left. It never enters the random bag.
- **Feedback:** the Operator announces the milestone (`MILESTONE`) and the bottle (`PWR_TONIC`); the survivor who
  grabbed it says their line; the bots call it with a ping (`PING_TONIC`); the HUD banner names the tonic each
  survivor got ("FREE TONIC: IRONHIDE STOUT" / "FREE MEASURE: RIVETED HOOPS" / "PERKS FULL: TONIC MONEY").
- **Co-op:** host-authoritative like every drop (the pickup is replicated with its lifetime; the gift runs on the
  host through PerkManager; the toast is relayed). **Bots** take it as an always-take drop (`ai/combat.json`); the
  **player-bot agent** goes for it too (no give-way etiquette toward its own heading).

## 2. New ways to earn (economy.json `"bonuses"`, `gravelight/autoload/scrip_bonuses.gd`)

Paid on the host, without the Double Scrip multiplier, each with a typed slip above the Scrip on the HUD
("+175  ROUND 5 PAY") through `GLBus.bonus_awarded` (relayed to co-op clients). The Operator remarks on the
first clean round, the first headshot streak and the first dog tags of a match.

| Source | Rule | Numbers (r1 / r5 / r10) |
|---|---|---|
| **Round pay** | every survivor standing (not downed, not bled out) when a round ends | 40 + 20 x round, max 300: 60 / 140 / 240 |
| **Untouched** | that survivor took no hit at all this round | 50 + 10 x round, max 200: 60 / 100 / 150 |
| **On your feet** | that survivor never went down this round | 25 |
| **Headshot streak** | every 10 headshot kills in a row (any other kill, or going down, breaks it) | 150, then +50 per further 10, max 250 |
| **Dog tags (salvage)** | a kill drops a dead soldier's tags with 6% chance (3.5% from round 11); they drift to a standing survivor within 3.5 m and are picked up within 1.2 m; gone after 20 s | 60 + 15 x round, max 300: 75 / 135 / 210; at most 4 a round, 6 on the map |

Why these: they reward the skills the game already asks for (not getting hit, staying up, aiming for the head,
covering ground for the drops), they are front-loaded (round pay and the clean bonus are a large share of a
round-2 income and a small one of a round-15 income), and none needs a new building or map work, so every map has
them. Kept as they were: board repairs (10 each, 500 a round cap: already generous early), Double Scrip, revive
bonus, Blackout / Fortify Scrip.

Ideas looked at and left out: a bank / loan (a menu and a debt rule for a small gain), bounties on a marked zombie
(the mark would need replicating to co-op clients' puppets), a once-a-round supply drop (it would compete with the
milestone and the power-ups).

## 3. What it adds (measured, 2026-10-25)

Headless soaks on Map 0 (`tools/ai_soak.sh`; the soak now logs player 1's Scrip earned, every source and the 500
start, at each round's end: `earned_r3/5/8` and `bonus_by_kind`). "Round" = the round the run ended on (botmode:
the solo player-bot agent, seeds 1-8; player3: the scripted player with the realistic kit + 3 bots, seeds 1-3,
which always ends at the Cousins, round 10). Before = master a2754e7.

| Batch | rounds (mean) | earned by r3 | by r5 | by r7 | by r8 |
|---|---|---|---|---|---|
| botmode solo, before | 8 8 6 8 8 8 7 8 (7.62) | 3,374 | 6,461 | 10,825 | never cleared |
| botmode solo, after | 6 7 7 9 8 9 9 9 (8.00) | 4,378 | 8,171 | 12,501 | 16,024 (4 of 8 cleared it) |
| player3 realistic, before | 10 10 10 | 2,027 | 3,943 | 5,717 | 7,187 |
| player3 realistic, after | 10 10 10 | 2,608 | 4,683 | 8,007 | 9,368 |

Plus the round-5 tonic (500-4000 of value) for everyone. A first tuning (round pay 50 + 25 x round, a 100 + 10 x round
untouched bonus, a streak every 5 headshots) gave the Elite agent +1,900 by round 3 (+57%) and no more rounds
(7.38): its headshot streaks paid almost every kill. The shipped numbers are the second pass. Per run the agent's
bonuses by its death are about 500-1,000 round pay, 300-400 untouched, 125-200 on your feet, 150-500 streaks and
225-1,560 dog tags. Rounds survived are noisy at 8 seeds; the agent's deaths are still its training (BOT_AI.md 10).

## 4. Tuning

All in data: `economy.json bonuses` (the table above), `rounds.json milestones`, `powerups.json milestone` and
`tonic_bottle`. Tests: `gravelight/tests/unit/test_scrip_bonuses.gd`, `test_milestones.gd`; smoke:
`gravelight/tools_src/smoke_milestone_r5.tscn` (round 4 to its end, the drops, the gift, the tags, round 5, the
agent taking a bottle, the expiry rule). Dev console: `powerup tonic_bottle` drops one in front of you.

## 5. Six tonics (T-081)

The perk-tonic cap went from 4 to **6** (`perks.json` `"cap"`; `"classic_cap": 4` under Classic Rules, read once per
match by `PerkManager.base_cap()`, the host's value in co-op). The Map 1 egg's slot is still +1 on top (7 there); a
bot's bonus perk and the tonic tiers use no slot. What it changes:

- **Late Scrip has somewhere to go.** On Map 0 the nine tonics cost 20,000 together (Ironhide 2500, Second Wind 500,
  Trigger 3000, Twin Barrel 2000, Marathon 2000, Hawkeye 1500, Packmule 4000, Blastproof 2000, Overclock 2500); four
  slots took 8-10k of it, six take 12-15k, and a downed survivor rebuys more. Tiers (section 1 of PERKS_LORE.md)
  still come after the cap is full, so they start later: the bots' `perk_upgrades` wait for `nothing_new`.
- **The round-5 tonic bottle** almost never hits a full cap now (it needs six tonics by round 5): it is a free tonic,
  and the tier / 1500 Scrip fallbacks are for the Requiem-style "everything" cases.
- **Bots and the player-bot agent** buy up to `cap_for` with no data change (`ai/economy.json perk_plan` and the
  agent's `perk_order` already list eight). Measured (2026-10-25, `tools/ai_soak.sh --scenario=botmode --runs=12`,
  seeds 1-12): rounds 9 8 9 10 9 3 9 9 8 9 8 6, mean 8.08, best 10 (before: mean 7.71, best 10; within the noise).
  The solo agent never filled the cap: it held 2-5 tonics when it died (the round-5 bottle gave its 5th) and
  330-6,385 Scrip unspent, saved for the Crucible step of its Map 0 plan. The extra slots matter past round 10 and in
  squads; the agent's unspent Scrip is a plan question (`ai/player_bot.json` map00 steps), not the cap.

## 6. The Crucible teaches, the boxes feed (T-083)

The Crucible no longer sells ammo. It used to offer "upgraded ammo [2500]" whenever you held a taught gun that was not
full, and the next teaching only once the gun was full, so a player bringing a half-empty Last Rites to be taught twice
was asked for ammo instead (the user's words: "it's asking me to buy ammo from the pack a punch machine. Don't have it
buy ammo from the pack a punch machine"). Now `Crucible.action_for` answers `upgrade` for any taught gun under the top
tier, `full` at tier III, and never `ammo`; `economy.json` lost `crucible_upgraded_ammo`.

Where a taught gun's ammo comes from instead, unchanged prices:

| Counter | Price | Notes |
|---|---|---|
| **Ammo box** (`economy.json ammo_box.upgraded`) | **2500** (taught wonder weapon 4000) | any tier; Packmule II halves it, Scrounger discounts it; every map has boxes (Map 0 taproom + Grounds, Map 1 Rail Yard, Map 2 harbour) |
| The gun's own wall chalk (`wallbuy_upgraded_ammo`) | 4500 | wall guns only |
| Resupply drop | free | everyone |
| Every teaching (I, II, III) | 5000 / 7500 / 10000 | the gun comes back full |

Bots follow: the `crucible_ammo` errand is gone (`bot_economy.gd`, `bot_tasks.gd`, the mark orders, the agent plan's
always-list, `bots.json shopping.crucible` lost `ammo_below_frac` / `ammo_reserve_scrip`, `ai/economy.json priorities`
lost `crucible_ammo`); a bot's taught gun under `ammo_box_below` (25%, 60% between waves with Scrip to spare) is the
ordinary ammo-box errand at the box's upgraded price (`BotEconomy._ammo_candidate`). `smoke_bots` phase 12 now checks
that refill. `BotMetrics.category_of` files any `<id>_ammo` purchase as wall ammo (`crucible` is upgrades only).

## 7. The Marke bonus (UPDATE 09 section 1, T-137)

Every Gänger carries the Marke, Darkmatter's chip under the skin of the right hand or the forehead (CANON section 2.2,
ENEMIES.md section 2.1): a small violet glint, a `"marke"` hitbox that does x1.5 on top of the host limb's multiplier.
A kill from a Marke hit pays **25 Scrip** (`enemies.json marke.scrip_bonus`) on top of the kill's Scrip, through
`Economy.award` right after the normal reward, so Double Scrip doubles it and section 3's `scrip_earn_mult` (the Ledger
Lager perk, contract C6) applies; `Zombie.marke_bonus_for(pid)` adds the perk's tier III `marke_tip` when PerkManager
has it. It shows as a "THE MARK" slip above the Scrip (`GLBus.bonus_awarded`, kind `&"marke"`) and counts in
`GameState.stats[&"marke_kills"]`. **Classic Rules pays nothing** (the weak point stays: it is part of the zombie). Bots
earn it like anyone when their shot lands on the mark; they do not aim for it. Why 25: a hand mark is an arm hit (body
Scrip 50), so a Marke kill from the hand pays 75, between a body kill and a head kill (100), and a forehead Marke kill
pays 125: the mark rewards the harder shot a little, never more than a headshot streak would. Measured in test_marke
(bonus once per kill, none on a body kill, doubled by Double Scrip, none in Classic Rules).



## 8. Ledger Lager and the bank on every map (UPDATE 09 section 3, T-141)

**The tonic** (`perks.json` `ledger_lager`, JINGLES.md §16; plan DIVIDEND): 3000, then 4000 / 7500 / 14000 for tiers II-IV
(II from round 8, III and IV from round 15, the same gates as every tonic; IV is permanent). Classic Rules: tier I only.

| Tier | Effect key | What it does | Where |
|---|---|---|---|
| I Ledger Lager | `scrip_earn_mult` 1.2 | every Scrip you **earn** is paid at 120% (nearest whole Scrip); the HUD "+N" shows the boosted number | `Economy.award`, `Economy.grant` |
| II Compound Interest | `bank_interest_bonus` 0.02 | the savings bank pays 3% a round, not 1% | `BankAccount.rate_for` / `accrue(pid)` |
| III Insider Rate | `purchase_discount` 0.10, `marke_tip` 15 | 10% off every purchase (the discount rounded down); a Marke kill pays 15 more | `Economy.spend` / `price_for`; `PerkManager.marke_tip` (read by `Zombie.marke_bonus_for`, contract C1) |
| IV Golden Parachute | `golden_parachute_pct` 0.05 / `_cap` 2500, `severance_pct` 0.10 / `_cap` 2500 | a round finished without a down moves 5% of the wallet in (a "DIVIDEND" slip); a down pays 10% of the savings out of the bank into the pocket; a down takes nothing | `ScripBonuses._on_round_ended` / `_on_player_downed`, `BankAccount.pay_severance` |

**Earning versus moving.** `Economy.award` (hits, kills, repairs, revives, power-up and Marke money, squad shares) and
`Economy.grant` (round pay, clean rounds, streaks, dog tags, quest and egg rewards, boss drops, companion gifts) apply
Double Scrip (`award` only) and then the earn multiplier. `Economy.bank_move` (deposits, withdrawals, the dividend, the
severance), `Economy.grant_raw` (the Requisition Crate's return when Herr Tamtam drums, the dev console, a match's
starting kit, the tonic bottle's "tonic money" when the cap is full) and a negative `grant` (the Account Manager's cut)
never take the multiplier. The multiplier is per player (`Economy.earn_mult(pid)`), so it goes with the tonic when a
down takes it. **Every price is `Economy.price_for(pid, list_price)`**: `Economy.spend` charges it and every prompt
(`Interactable.price_str`) shows "[855, was 950]" under Insider Rate.

**The bank on every map** (`bank.json`): the Crossroads' woodshed, Kaltenbrunn's pay office, and (new) Totenhafen's
Marinekasse on the crane office's south wall (teller Karl Jessen), Werk Thalbach's Lohnkasse in the yardmaster's hut
(Ilse Ruhland), the Kranich's Bordkasse at the centre body's forward bulkhead (Ruhland again, a stowaway with the cash
box), Groom Lake's Range Finance Office at Dee's cage (Pvt. Eugene Pruitt) and Darkmatter's Accounts window in
Mondlicht's concourse (no clerk: a brass speaking-tube window, the Operator answers). One balance in the profile.
Each branch carries a `nav_block` footprint the map generators cut out of the navmesh.

**Balance by soak** (`tools/ai_soak.sh --scenario=botmode --map=map00 --bots=3 --speed=4 --max-round=14 --seed=21`,
`ledger_curve.py`-style reading of `logs/ai_runs/*.csv`: earned = wallet change + Scrip spent in the round).

| Round | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Mean Scrip earned by a survivor, master's economy | 760 | 1710 | 1750 | 1680 | 1380 | 2420 | 2590 | 3410 | 6950 | 4120 | 4370 | 1710 | 4720 |
| Extra at +20% of base (bought at round 3) | 150 | 340 | 350 | 340 | 280 | 480 | 520 | 680 | 1390 | 820 | 870 | 340 | 940 |

A 3000 tonic bought at round 3 is paid back in round **9-10** for all four survivors (net +3300 to +5300 by round 14);
bought when a bot can first afford it (round 5-6) in round **11-12**. That is neither before round 8 nor past round 15, so
the prices stay: 3000 / 4000 / 7500 / 14000. In the bots' own run the squad bought it at rounds 10-12 (it sits third in
`perk_plan`, but doors, guns and the second tonic come first), so it pays back around round 15 there: the bots take it
late, as a human who saves for doors would.

A third run gave Peg (the agent's survivor) the tonic from round 1 (`--give=ledger_lager`, same seed): the squad's mean
Scrip earned per survivor over rounds 3-14 was 38,660 against 36,820 on master's economy (+5.0%, the +20% on one
survivor of four, inside the run-to-run noise). Logs: `.smoke_logs/u09/soak/{A,B,C}.log` (A: master's economy, Ledger
Lager out of every bot plan and bonus roll; B: the branch as shipped; C: Peg holds it).
