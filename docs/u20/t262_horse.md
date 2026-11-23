# T-262: shooting at a gallop, and the horse's tack

The owner: "allow player to shot gun while gallobing with horse, add horse upgrade". Branch `claude/horse-upgrades`
(from master at 69f089a5). The horse is T-240's (`docs/u15/t240_horses.md`); the Sherman (T-261) is not touched.

## 1. Shooting at a gallop

**What stopped it before.** Three things, all in the horse:
- `data/gravelight/horse.json` `fire.max_gait` was 2 (the trot), and `HorseRules.can_fire(gait, seated, f)` is
  `seated and gait <= max_gait`.
- `Horse._seat_rider` wrote that answer into `Player.carry_fire` every physics frame. `Player._gather_intent` turns
  `carry != null and not carry_fire` into the intent's `fire_block` (no shot) and `mantle` (no ADS).
- The same line called `WeaponHolder.set_hands(&"climb")` at a gallop: the gun hidden, both hands placed on the reins
  at the pommel (`_place_hands`).

**How it works now.**
- `fire.max_gait` is 3: the rider may fire, aim and reload at every gait.
- **The reins.** At a gallop (`fire.reins_gait` 3) the hands still rest on the reins while the weapon is idle. The
  moment the weapon is wanted (fire or aim held, grenade held, a reload / swap / knife / tactical press, or a reload
  already running) the gun comes up as after a weapon swap (`set_hands(&"")`: 0.29 s, `SWAP_TIME * 0.7`) and
  `carry_fire` goes true. It stays up between shots and goes back to the reins `fire.reins_after_s` (1.6 s) after the
  last of those. Below a gallop the gun is always up, as in T-240. The rule is `HorseRules.on_reins`.
- **A trigger pull from the reins is not eaten.** The holder already keeps a fire press made during a sprint-out or a
  mantle (`_move_fire_buffer`, 0.75 s) and fires it when it can. That only worked when the Player's tick ran before
  the horse's in that frame; the smoke caught the other order (press lost). `WeaponHolder.keep_fire_press()` (new, 3
  lines) lets the horse keep it too. One click from the reins is one shot 0.3 s later; an automatic held down starts
  firing as the gun arrives.
- **Not a free pass: the gallop is the worst gait to shoot from.**

| | stand | walk | trot | gallop (hip) | gallop (sights up) |
|---|---|---|---|---|---|
| second shake of the aim (`sway_*`) | 0.25 | 0.6 | 1.0 | 1.6 | 1.6 |
| the saddle's own rock in the view (`view_rock`, `rock_ads_mult`) | x1 | x1 | x1 | x1 | x0.5 |
| view pitch swing measured in the smoke, peak to peak | | | 1.1 deg | 6.1 deg | 3.8 deg |
| degrees added to the weapon's cone (`spread_*_deg`, `spread_ads_mult`) | 0 | 0 | 0 | +2.4 | +1.2 |

  The M1911's hip cone is 2.5 deg at a trot and 4.9 deg at a gallop (measured). The swing is the gallop's stride (once
  a stride, so it can be timed); the cone is random. Aiming down the sights halves both: the rider "stands in the
  stirrups". The walk and the trot are exactly as T-240 left them (their added cone is 0, their sway numbers the same).
- The cone reaches the weapon through `Player.carry_spread` (new; degrees, set by the carrier each frame, 0 on every
  `begin_carry` / `end_carry`), which `WeaponHolder.spread_deg()` adds. The crosshair reads `spread_deg()`, so it opens
  at a gallop without further work (read in code, not seen on a screen).
- Bots still never ride (`HorseRules.may_mount`, unchanged).

**First person and third person.** First person: reins in the fists while just riding fast, the gun in both hands
when it is wanted; the reins are a fixed part of the horse's mesh running back to the pommel, so "dropped" reins lie
where they always lie. A one-hand-on-the-reins pose was not built: the hands system has "both on the gun" and "both
off it", and a third state is a bigger edit of `weapon_holder.gd` than this task. Third person: a peer has always seen
the rider's `RemoteBody` holding its gun (the reins pose was never replicated), which is now simply true at a gallop
whenever it matters. The rider's third-person body still has no seated pose (T-240's limit, unchanged).

## 2. The tack (the horse's upgrades)

Three pieces, sold **in this order, one at a time**, at a **tack chest beside the hitching rail** (1.62 m east of the
rail's middle, at (25.77, 0, 35.95) on the Inn), for **Scrip**, with the usual hold-Use and the wall-buy prompt shape:
`Hold [F] to fit Studded Shoes [1500]` and the piece's one-line description under it. Prices go through
`Economy.spend`, so Ledger Lager's insider rate applies as at any machine.

| # | id | Name | Scrip | What it changes (`horse.json` "upgrades": `mul` / `add` on the table) |
|---|---|---|---|---|
| 1 | `shoes` | Studded Shoes | 1,500 | gallop 9.5 -> 10.64 m/s (x1.12); turn rate x1.2 at every gait (1.0 -> 1.2 rad/s at a gallop); the hard-turn gallop 6.4 -> 7.36 m/s; acceleration x1.15; the sprint urge x1.2. Its hard turn at a gallop is a little tighter than before (radius 5.67 m from 5.84), so it still fits the yard. |
| 2 | `saddle` | Trooper's Saddle | 2,000 | the aim: `sway_*` x0.6 at every gait, the saddle's rock in the view x0.7, the gallop's added cone 2.4 -> 1.2 deg (0.6 deg with the sights up). |
| 3 | `barding` | Carter's Barding | 2,500 | trample damage 90 -> 225, the speed it costs the horse 35% -> 17.5%, its cooldown 0.7 -> 0.42 s, the fling 7 -> 8.4 m/s; in a crowd: 3 zombies cost it nothing (was 1), it shies at 6 (was 3), and its slowest crowded pace is 2.0 (a trot; was 1.4). A horse boss frightens it exactly as before. |

The whole set is 6,000 Scrip (perk bottles are 1,500 to 4,000 for the first tier). 225 trample damage is still under a
tenth of a round-20 zombie's 2,710 health (the T-240 test's "not a win button" line holds, and is asserted again).

**Rules** (`HorseRules.may_buy`, tested): a live human on their feet (not downed, not a bot / companion, not carried
by a horse, a ladder or a line), the horse **standing tied at its rail** (after a ride it walks home by itself in 25
s; otherwise the prompt says "the horse must stand tied at its rail"), and only the next piece in the order.

**Lifetime.** Per match, on the horse (not on the buyer): every rider has it, the squad shares it. Nothing is written
to the profile. There is no pattern in the game for a permanent world unlock bought with Scrip, so none was invented.

**On the model** (`Horse._show_tack`, bone attachments on the procedural rig, no colliders): steel shoes with heel
studs under the four hooves; saddlebags, knee rolls, a strap and a rolled green blanket behind the cantle; a leather
breast piece with rivets round the chest and a strap over the withers. Built from `Props` boxes and cylinders with the
library's `leather` / `steel` / `iron` / `brass` / `cloth_green` materials. The chest itself is a small carter's box
(drawn only: like the rail's bucket it has no collider, so nothing baked changes and no navmesh is touched).

**Co-op.** As the mount: `HorseTack.interact` is not `net_local`, so a client's hold is sent to the host
(`Player.use_interactable` -> `request_interact`), the host checks the rule, takes the buyer's Scrip
(`Interactable.try_purchase`, item ids `horse_shoes` / `horse_saddle` / `horse_barding`) and mirrors
`Horse.net_upgrades(owned)` with `Net.mirror`. Every peer then rides by the same table: the rider's machine moves the
horse with it, the host decides the trample with it. A client can buy.

**How it is built.** `HorseRules.upgraded(owned)` returns `horse.json` with the owned rows' `mul` / `add` applied to a
copy (the shared table is never written to); the horse keeps that as `_tab` and every rule it calls reads its blocks
from there (`_blk`). A new piece of tack is one more row in the json.

## 3. Decisions taken

1. **Hands on the reins until the weapon is wanted**, rather than the gun always up at a gallop or a one-handed pose:
   it keeps T-240's picture while just riding, costs a 0.3 s draw at a gallop (part of the handicap), and needs no new
   hands state. The press is kept, so it never feels like a dead click.
2. **The gallop's handicap is the stride's swing plus an added cone**, both halved by aiming. The walk and the trot
   were left exactly as they were.
3. **Tack is sold in a fixed order at one chest** (the perk tiers' pattern) instead of three separate buy points:
   one prompt, no clutter at the rail, cheapest first.
4. **The horse must be tied at its rail to be fitted.** It is the place the owner's brief names and it stops a buy
   while someone rides off on it.
5. **The saddle steadies the aim; it carries no ammunition.** Free ammunition would cut into the wall-buy and
   ammo-box prices and the Packmule perk; a steadier aim is the thing a mounted shooter wants after this change.
6. **Upgrades belong to the horse and the match**, not to a player or the profile.
7. **The barding does not change what zombies do to the horse** (they still ignore it) or the boss fear.
8. `Player.carry_spread` and `WeaponHolder.keep_fire_press()` were added instead of reaching into the holder's
   private state from the horse. Both are inert for every other carrier (ladders, zip lines, the Sherman: 0 / never
   called).

## 4. Every edit

| File | Edit |
|---|---|
| `data/gravelight/horse.json` | `fire` block (max_gait 3 and the new keys), `upgrades` rows, `tack` block, `_doc`, version 2 |
| `gravelight/world/horse/horse_rules.gd` | `can_fire` default, `fire_sway` gallop, new `fire_spread`, `view_rock`, `on_reins`, and the tack rules (`upgrade_rows`, `upgrade`, `upgrade_cost`, `clean_owned`, `next_upgrade`, `may_buy`, `upgraded`, `tack_names`) |
| `gravelight/world/horse/horse.gd` | `_seat_rider` (reins rule, spread, kept press), `_weapon_wanted`, the table through `_blk`, the tack (`tack_prompt`, `can_buy`, `on_buy`, `net_upgrades`, `_show_tack`), `HorseTack` (inner class, built by `spawn_all` when a row has a rail), smoke hook `weapon_override` |
| `gravelight/player/player.gd` | 3 lines: `var carry_spread`, reset in `begin_carry` and `end_carry` |
| `gravelight/weapons/weapon_holder.gd` | `spread_deg()` adds `player.carry_spread`; new `keep_fire_press()` |
| `gravelight/tests/unit/test_horse_gait.gd` | `test_fire_from_the_saddle` rewritten for the gallop; new `test_tack_rows_prices_and_order`, `test_tack_who_may_buy_and_when`, `test_tack_effects` |
| `gravelight/tools_src/smoke_horse.gd` | the gallop shooting section, `_tack`, `_tack_ridden` |
| `docs/u15/t240_horses.md` | a three-line pointer to this file |

Not touched: `gravelight/world/sherman/`, the navmesh, `gen_map00.gd`, any map json, `zombie*.gd`, `gravelight/bots/`,
`project.godot`, PROGRESS, DECISIONS, `morning/`.

## 5. Results

All headless on the owner's PC, 2026-11-22, in the worktree `.wt/horse`.

- `check_scripts.gd`: checked 969 scripts, 0 failed.
- `test_horse_gait.gd` alone: 18 tests, 18 passing, 943 asserts (3 new tests, 1 rewritten).
- Full GUT suite: 245 scripts, **2,442 tests, 2,441 passing, 0 failing, 1 risky** (the known
  `test_neural_lines_are_loudness_normalised`), 88,160 asserts, 536 s.
- `tools/run_smokes.sh .smoke_logs/horse horse`: `smoke_horse` PASS (116 checks, 0 failed, 96 s; it was 72 checks
  before), `smoke_horse_boss` PASS (79 checks). Exit 0.
- `tools/run_smokes.sh .smoke_logs/horse sherman`: `smoke_sherman` PASS (74 checks). Exit 0.

Two things on the way, for the record:
- The first full GUT run showed 22 failing tests, all "Unexpected Errors: invalid UID ... using text path instead":
  the fresh worktree had no `.godot/uid_cache.bin` (the import's scan thread was cut off by `--quit-after`). Copying
  the main checkout's `uid_cache.bin` cleared all 22; none was in code this branch touches.
- The smoke's first version of the trigger-from-the-reins check failed, and that was a real bug (the press was lost
  when the horse's tick ran before the Player's): fixed with `keep_fire_press()`. Two later failures were the smoke's
  own (a gallop started 1.5 m too far west, where the horse refuses the yard's edge) and were fixed in the smoke; the
  final scene passed three times in a row alone and once more under `run_smokes.sh`.

## 6. Not verified, and open

- **Nothing was seen on a screen.** Headless only on this PC. The feel of the swing and the cone at a gallop, the
  0.3 s draw from the reins, the look of the tack on the horse (the breast piece is a few boxes on the `Body` bone, and
  the fore legs' shoulders move under it: it may clip in a gallop), the chest's look and whether it sits cleanly in
  the snow by the east post, and the crosshair opening are all unjudged. The `u15_horse` capture set would show the
  horse; no camera was added for the tack.
- **No live two-machine co-op run.** The buy path on a client and the mirrored list were checked by reading the code
  and by calling `net_upgrades` in the smoke with a dirty list. A client that joins after a purchase is not sent the
  list (the horse has no late-join state at all, T-240's included).
- **The numbers are a first setting.** 6.1 deg of swing from the hip at a gallop is large on purpose (aim, or buy the
  saddle); if it plays as too hard, `fire.view_rock` / `rock_ads_mult` / `spread_gallop_deg` are the three knobs.
- The reins pose is not replicated to other peers and there is no one-handed pose (section 1).
- Only the Inn has a horse, so only the Inn has a tack chest; another map's "horses" row with a rail gets one
  by itself.
- No VO, no Archive entry and no challenge for the tack; bots do not buy it (they do not ride).
