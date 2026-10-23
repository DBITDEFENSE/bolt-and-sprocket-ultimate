# GRAVELIGHT: the pause tabs and the OBJECTIVES tab (Update 04 §3 shell, §4; DECISIONS T-066)

## 1. The pause page

`gravelight/ui/pause_menu.gd` (PauseMenu). Esc / Start opens it on **MAP** every time. Tabs: **MAP · OBJECTIVES ·
LOADOUT · SETTINGS · QUIT**; Q / E or LB / RB switch (not while a LineEdit / TextEdit has focus). Solo pauses the
tree; co-op only blocks your input (unchanged from T-040).

| Tab | Content |
|---|---|
| MAP | A host slot. A map builder either calls `pause_menu.set_map_view(view)` or ships a `PauseMapView` class (the menu makes one with `.new()` on the first MAP visit and calls `bind_pause_menu(self)` if it has it). Until then a ledger placeholder shows the map, round, power, open areas and the last highlighted place. |
| OBJECTIVES | `ObjectivesView` drawing `ObjectiveLog.build(...)` (below). |
| LOADOUT | Scrip, guns (mag / reserve, Crucible tier, attachments), knife, grenades, tactical, perks (slots used / cap, bonus perk marked), the bots' Scrip and guns. |
| SETTINGS | Quick sliders (sensitivity, FOV, shake, objective spoilers, subtitles, hint mode, classic rules) and "All settings" (the full MenuSettings page over the pause page). |
| QUIT | Restart / Quit to menu (co-op: Back to lobby, End the game, Leave), each behind the Yes / No confirmation. |

### Hooks for the map builders

- `signal location_requested(world_pos: Vector3, floor_id: StringName, label: String)` - an OBJECTIVES entry
  was selected (or "Show on map" pressed). `floor_id` is `""` unless the data names one: pick the floor by height.
- On the view (all optional): `highlight_location(world_pos, floor_id, label)`, `highlight_locations(points:
  Array[Vector3], floor_id, label)` (a step with several spots, e.g. the three notes), `refresh()` (each time the
  MAP tab opens).
- `show_location(world_pos, floor_id = &"", label = "", switch_to_map = false, points = [])`, `set_tab(i)`,
  `tab_name()`, `signal tab_changed(tab)`, `signal objective_selected(entry)`.

### Assign to bot (section 5)

A current easter-egg / side-quest step shows **Assign to bot** when the node in group `bot_squad` has
`ee_can_assign(quest_id: StringName, step_id: StringName) -> bool` and it returns true; pressing it calls
`ee_assign(quest_id, step_id, -1) -> {"ok": bool, "reason": String}` and prints the reason under the buttons.
Both are guarded with `has_method`, so the tab works without them.

## 2. The model

`gravelight/ui/objective_log.gd` (ObjectiveLog) is pure: `build(snapshot, data, spoiler) -> {spoiler, current,
sections}`. `gravelight/ui/objective_snapshot.gd` reads the match into the snapshot (GameState, RoundManager,
QuestManager incl. `random_values(qid)`, JakubCompanion, exfil points, ProfileSave challenges and intel) and turns a
selected entry back into world positions (`locate(root, entry)`: each named node, a scripted visible one first;
picked-up or hidden ones are skipped; then the fixed `pos`).

Sections: CURRENT OBJECTIVE (always on top), EASTER EGG, SIDE QUESTS, CHALLENGES (the map's three rotating
challenges with progress), INTEL (picked up this match, or filed by a quest since the match began; "Open in
Archive" opens the Intel Archive page).

### Spoiler levels (Settings -> Gameplay -> Objective spoilers, `GLSettings.values.objective_spoilers`)

| Level | Completed steps | Current step | Future steps | Map highlight | Unstarted secret side quest |
|---|---|---|---|---|---|
| Hidden | plain words | not shown | not shown | none | not listed |
| Hints (default) | plain words | in-character hint | `???` | none | listed, its first step's hint |
| Full Guide | plain words | instruction + "Where:" (and `{rand:...}` values the squad has heard) | `???` | yes | listed |

No level ever shows a future step's own words (GUT `test_no_level_leaks_a_future_step`).

## 3. The data (`data/gravelight/objectives.json`)

- `maps.<map_id>.current`: ordered rules `{when?, done?, text, progress? {flag, max} | {round}, nodes?}`; the first
  whose `when` holds and whose `done` does not wins. Each map's list ends with an unconditional "Survive."
- `maps.<map_id>.easter_egg`: QuestManager quest ids. `maps.<map_id>.side`: `{quest: id}` (a QuestManager quest) or
  a tracked side quest `{id, title, public?, show_when?, requires_setting?, steps: [{id, when, done, hint, guide,
  where, nodes?}]}` (each step is done when its `when` holds; the first not-done one is current).
- `quests.<quest_id>.steps.<step_id>`: `done`, `hint`, `guide`, `where`, optional `nodes`, `nodes_random {key,
  format}` (`{g}` group, `{v}` the seeded pick: `Radio_{v}`, `Part_{g}_{v}`), `pos`, `progress {flag, max}`.
- Tokens: `{n}`, `{target}`, `{rand:<key>}` (Full Guide only; digits print in pairs).
- Conditions: `power`, `flag`, `flag_at_least`, `zone_open`, `round_at_least`, `step`, `quest_done`, `intel_match`,
  `jakub_in`, `exfil_active`, `setting`, `all`, `any`, `not`. Unknown keys are false.

What exists now: Map 0 (current rules; easter egg *Glasmacher Calling*; side: *The Man in the Coal Cage* (Jakub's
escape), *Three Ribbons* (the Cousins' room, needs Homage Bosses)), Kaltenbrunn (rules up to the pylons; *Requiem*,
all 13 steps; side: *Lanterns Down Below*, *KB-4471*, *Jakub's Road* when he came with you), Totenhafen (rules: Pen
Hall, ballast, pump room, Pumpenschalter; no quests yet). A future map or side quest (the Moon plates, Paul's
letter, the Slender's watch-book, Helvetia Works) adds a `maps` block and its `quests` text; no code changes. A GUT
test fails if any quest JSON step lacks its three texts or isn't on some map's tab.

## 4. Bolt & Sprocket

`ui/bs/pause_menu.gd` gets an **OBJECTIVES** button: the same view in the holo skin over `ObjectiveLog.build_bs`:
MISSION (the HUD's mission tracker, else "Explore <planet>"), SIDE QUESTS (`data/bs/story/quests.json` for the
planet: running ones with their count, finished ones, unstarted ones as `???` / "talk to <npc>" at Full Guide),
GOLD BOLTS and MEMOS (found / total, the spots at Full Guide), CHALLENGES (`objectives.json` `bs.challenges.<level_id>`;
none yet). The spoiler setting is shared and written without re-applying Gravelight's visuals.

## 5. Tools

`gravelight/tools_src/shots_objectives.tscn -- --out=<dir> --map=map00|map01|bs` renders every tab, the
OBJECTIVES tab at the three levels, a Full Guide entry highlighted on the MAP tab, and the B&S holo tab.
