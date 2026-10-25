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
| **Round pay** | every survivor standing (not downed, not bled out) when a round ends | 50 + 25 x round, max 400: 75 / 175 / 300 |
| **Untouched** | that survivor took no hit at all this round | 100 + 10 x round, max 250: 110 / 150 / 200 |
| **On your feet** | that survivor never went down this round | 50 |
| **Headshot streak** | every 5 headshot kills in a row (any other kill, or going down, breaks it) | 100, then +50 per further 5, max 300 |
| **Dog tags (salvage)** | a kill drops a dead soldier's tags with 7% chance (3.5% from round 11); they drift to a standing survivor within 3.5 m and are picked up within 1.2 m; gone after 20 s | 75 + 15 x round, max 300: 90 / 150 / 225; at most 4 a round, 6 on the map |

Why these: they reward the skills the game already asks for (not getting hit, staying up, aiming for the head,
covering ground for the drops), they are front-loaded (round pay and the clean bonus are a large share of a
round-2 income and a small one of a round-15 income), and none needs a new building or map work, so every map has
them. Kept as they were: board repairs (10 each, 500 a round cap: already generous early), Double Scrip, revive
bonus, Blackout / Fortify Scrip.

Ideas looked at and left out: a bank / loan (a menu and a debt rule for a small gain), bounties on a marked zombie
(the mark would need replicating to co-op clients' puppets), a once-a-round supply drop (it would compete with the
milestone and the power-ups).

## 3. What it adds (measured)

Soak numbers (headless, `tools/ai_soak.sh`, Map 0, Scrip earned by player 1 including the 500 start) are in
DECISIONS T-078 and the builder's report. In short: solo, rounds 1-5 earn roughly 1,300-1,600 more (round pay and
clean rounds are most of it), plus the free tonic at round 5 (500-4000 of value).

## 4. Tuning

All in data: `economy.json bonuses` (the table above), `rounds.json milestones`, `powerups.json milestone` and
`tonic_bottle`. Tests: `gravelight/tests/unit/test_scrip_bonuses.gd`, `test_milestones.gd`; smoke:
`gravelight/tools_src/smoke_milestone_r5.tscn` (round 4 to its end, the drops, the gift, the tags, round 5, the
agent taking a bottle, the expiry rule). Dev console: `powerup tonic_bottle` drops one in front of you.
