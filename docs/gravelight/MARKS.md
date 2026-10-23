# The pause map, map marks and what bots do with them (Update 04 section 3, DECISIONS T-069)

## 1. The MAP tab (`gravelight/ui/pause_map_view.gd`, PauseMapView)

The pause page opens on MAP (T-066's shell makes the view: the class name `PauseMapView`). In solo the world is frozen
underneath (the view runs with PROCESS_MODE_ALWAYS); in co-op it isn't.

- The whole level on a `MapCanvas` (the section 2 renderer): floor tabs (the floor you are on has a dot), pan (drag /
  right stick), zoom (wheel / triggers / + -), floors (the tabs, Shift + wheel, PgUp / PgDn, D-pad up / down), zone
  labels, the fog of war and the colourblind shapes from the minimap settings, a legend, round and power in the corner.
- Hover any icon: what it is, its price, open / bought / locked (a door "Locked: needs the power", a perk "Bought (you
  have it)", a trap "Recharging"...); a mark: whose it is and that bot's order line; a bot: its order line.
- Down the side: each bot's portrait (its body icon in its colour), its Scrip and its **order line** ("Going to buy
  Ironhide Stout (1,200 short, 45 s)", "Bringing you a Thompson", "Defending Rail Yard", "Doing: Collecting the radio
  notes (2/3)", "Reviving Peg", "Idle"); your marks (n / 3) with a remove button each; the keys.
- `highlight_location(s)` (the OBJECTIVES tab's "Show on map"): the floor, centred, a pulsing ring for 8 s.

Controller: left stick moves a crosshair cursor, A marks, B removes the mark under the cursor (or backs out of a
menu), Y centres on you. LB / RB stay the pause page's tab keys (section 4 took them), so floors are on the D-pad.

## 2. Marking

Click (A) on:
- **an empty spot** -> the radial **Go Here · Defend Here · Danger · Regroup · Custom note** (a short typed note or a
  preset: `data/maps/marks.json note_presets`);
- **a buyable** -> **BUY THIS** (perk, wall weapon, ammo box, door: OPEN THIS DOOR, the Requisition Crate where it is,
  the Crucible, a trap lever, the Armorer's Bench: the bot's pick or a slot, then an option with its price);
- **an easter-egg object / part, a power-up, the power switch** -> **Collect / Activate this**;
- **a mark** -> Remove mark (plus the options of what it sits on). Right-click / B removes directly.

Then **who**: Me (a waypoint), Any bot, a bot by portrait (its current order under it), Jakub. Defaults: Any bot for
BUY / COLLECT / DEFEND, Me for Go here; Danger and Regroup are for the squad; notes are yours. A wall weapon offers
**FOR ME** (a bot buys it for you). A door then asks **"Open this door for 1,250?"**. Jakub isn't offered for
purchases (he has no Scrip, and refuses perk machines and the Crucible).

Limits (`data/maps/marks.json limits`): 3 personal marks per player, 3 Danger marks, 1 Regroup, **1 order per bot**;
a new one replaces the oldest (an order: the bot's last order and its mark). Danger and Regroup marks last 60 s.

Marks show on the minimap, the full map and **in the world** (`core/map/world_marks.gd`): GRAVELIGHT a chalk X decal
on the floor (lightly self-lit so it reads in a dark cellar, fading out past 30 m), B&S a holo pin; a small label over
each (letter, name, the bot it is for, the distance) that fades with distance, shows for the 4 nearest only, hides
when you stand on it and never overlaps a nearer one.

### The ping key (`gravelight/ui/mark_ping.gd`)
GRAVELIGHT action `ping`: **middle mouse / D-pad up** (rebindable; alt-fire, which was also on middle mouse, keeps B
and D-pad right; nothing else used D-pad up). B&S `bs_ping`: G / Back (B&S's middle mouse is the Omni-Blaster's alt
fire and its D-pad up the Super Sprocket). Same logic as the map: a buyable -> Buy this for any bot; a door -> "Ping
again to have a bot open it" (the second press within 3 s confirms); an egg object / power-up / the power switch ->
Collect; a wall or the floor -> Go here (yours); a double-tap (0.35 s) -> that mark becomes Danger; pinging one of
your marks removes it.

## 3. What bots do (`gravelight/bots/bot_mark_orders.gd`, `bot_mark_task.gd`; tuning `data/gravelight/ai/marks.json`)

A mark for a bot becomes its order: the utility action **mark_order** (actions.json weight 0.93 on
`BotMarkTask.value()`, falling with pressure). A revive (weight 1.25) wins; the order resumes after with "Back to it."
(`MARK_RESUME`). "Any bot": not down, not reviving, closest by path; for a purchase one who can afford it beats one who
can't; a bot that can't take it (has that perk, no room for a tonic, slots full of upgraded guns) is skipped.

| Order | What the bot does |
|---|---|
| BUY THIS | Acknowledges in character with a ping at the target. Checks its Scrip: affordable -> paths there, buys (the same hold and use as a player) and confirms ("Got the Ironhide. Feel like a barrel."; the automatic perk / buy / door line is held back for it). Short -> says by how much ("Need 600 more for that, boss."), waits up to `queue_s` (60 s) while it earns (it fights, repairs, as usual), goes when it can ("Got the Scrip now. On my way."), or gives up ("Couldn't scrape it together."). A wall gun it has already -> its ammo. The Crucible: its best gun, or upgraded ammo. The Armorer's Bench: `ArmorersBench.buy` with the slot / option picked, or its own pick (`bench_prefs`: the first it hasn't fitted and can afford, else it saves for the cheapest). |
| BUY FOR ME (a wall weapon) | Pays at the wall with its own Scrip (the gun doesn't go in its hands), carries it (a `WeaponParcel` hanging at its side: you can take it off the bot), walks to you and drops it at your feet ("Dropped it at your feet."); while you are down it holds it. Only you can pick it up. |
| Doors | Only marked and confirmed, and affordable (else it waits like any purchase). |
| GO HERE | Walks there, waits 45 s, goes back to following. |
| DEFEND HERE | Holds within ~4 m, fights from there, rebuilds windows within 7 m between kills, for 90 s. |
| REGROUP | Every standing bot drops its order and comes (within 3 m); the mark goes when all arrived. |
| DANGER | Every bot's paths avoid the spot (a blackboard danger zone, 4.5 m, for the mark's 60 s); the nearest bot calls it out. Removing the mark lifts it. |
| COLLECT / ACTIVATE | An egg object: `BotSquad.ee_assign_node` (section 5's rules: the setting, what the squad knows, Jakub's limits; it speaks its own lines); the mark goes when that object is done. A power-up: walks over it. The power switch: throws it. |

Jakub: goes, defends, regroups, calls danger and does the egg steps section 5 allows; he refuses purchases
("I have no Scrip, friend.") and, in his section 5 lines, the perk machines and the Crucible.

Full Partner (section 5) never gives a bot on a mark order an egg task of its own.

## 4. APIs

- `MapMarks.current()` (core/map/map_marks.gd, a child of the MapState): `place(spec) -> {ok, id, reason, pid, replaced,
  label}` (spec: kind, pos, label, owner, target "me" / "squad" / "any" / "jakub" / pid, node, poi_id, for_pid, slot,
  option, confirmed), `remove(id)`, `remove_near(pos, r)`, `nearest`, `personal(owner)`, `order_mark_of(pid)`,
  `bots()`, `status_of(pid)`, `clear()`, signals `placed` / `removed`, `ping` (the MarkPing).
- The order handler is any node in group `map_mark_orders` (`place_order`, `cancel_order`, `on_danger`, `on_regroup`,
  `mark_removed`, `bots`, `status_of`): GRAVELIGHT's is `BotSquad.mark_orders`. B&S has none (personal marks only).
- `MarkTargets.classify(node)` / `classify_poi(poi, ms)`: what marking something means (shared by the map, the ping and
  the bots). A future map's buyables are covered by their classes; a new class adds a branch there.
- Pure rules (GUT `test_mark_orders.gd`): `MapMarks.drop_for_limit / limit_class / default_target`,
  `BotMarkOrders.best_bot / refusal / route / pick_bench_option`, `BotMarkTask.short_by / short_category /
  queue_expired / value_for / away_kind / resume_due`, `MarkPing.decide`, `PauseMapView.radial_for / who_options /
  tooltip_lines`.

## 5. Tools

- `gravelight/tools_src/smoke_marks.tscn` (11 phases; `-- --clip [--only=<phase>]` films it with a chase camera).
- `gravelight/tools_src/shots_marks.tscn -- --out=<dir> --map=map01|map00`: the MAP tab, zoom, hover, radials,
  who-picker, the door question, the chalk X.
- `gravelight/tools_src/perf_marks.tscn [-- --no-marks]`: Map 0 round 15, minimap, 3 bots + Jakub, 24 zombies, marks.
- Launchers: `play_marks.tscn` (Map 0, 3 bots, Scrip, marks placed, the map opened), `play_ee_full.tscn` (Kaltenbrunn,
  3 bots, Bot Easter-Egg Help on Full Partner for the session).
- VO: VO_SCRIPT section 19 (247 lines, `SQ5`, baked).
