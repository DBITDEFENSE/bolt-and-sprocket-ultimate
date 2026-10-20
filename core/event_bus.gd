extends Node
## Shared signals between systems so they never reference each other directly. Mode-specific buses
## (B&S, Gravelight) add their own signals in M1/M2; these are the ones every mode needs.

signal mode_changed(mode: int)
signal vo_line_started(line_id: String, speaker: String, text: String)
signal vo_line_finished(line_id: String)
signal subtitle(speaker: String, text: String, color: Color, seconds: float)
signal save_written(path: String)
signal unlock_granted(unlock_id: String)
signal archive_entry_found(entry_id: String)

# ---- Bolt & Sprocket
signal bolts_changed(total: int, delta: int)
signal gold_bolt_found(gold_id: String)
signal memo_found(memo_id: String)
signal player_damaged(amount: float, hp: float)
signal player_died
signal enemy_hit(enemy: Node, hit: RefCounted, killed: bool)
signal enemy_killed(enemy: Node, by_weapon: StringName)
signal combo_changed(hits: int)
signal weapon_changed(weapon_id: StringName)
signal weapon_leveled(weapon_id: StringName, level: int)
signal super_meter_changed(value: float)
signal boss_started(boss_id: StringName, display_name: String)
signal boss_health(boss_id: StringName, frac: float, break_frac: float)
signal boss_defeated(boss_id: StringName)
signal story_beat(beat_id: String)
signal quest_progress(quest_id: String, count: int, need: int)
signal quest_done(quest_id: String)
signal interact_prompt(text: String)
signal hint(text: String, key: String)
signal banner(title: String, sub: String, seconds: float)
signal bark(line_id: String)
