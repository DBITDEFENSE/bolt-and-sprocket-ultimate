extends Node
## Global signal hub. Gameplay emits; VO, quests, challenges, stats and UI listen.
## Keep payloads plain (ints, StringNames, Dictionaries) so they can be sent over the network later.

# Match / rounds
signal match_started(map_id: StringName)
signal round_started(round_number: int, is_special: bool)
signal round_ended(round_number: int)
signal special_round_warning(kind: StringName)
signal game_over(stats: Dictionary)

# Combat
signal enemy_spawned(enemy_id: StringName, node_id: int)
signal enemy_damaged(enemy_id: StringName, limb: StringName, amount: float, by_player: int)
signal enemy_killed(enemy_id: StringName, limb: StringName, weapon_id: StringName, by_player: int)
signal enemy_killed_at(enemy_id: StringName, position: Vector3, by_player: int)
signal enemy_hit_feedback(by_player: int, killed: bool, headshot: bool)
## The Marke (UPDATE 09 section 1, T-137; C1): a hit on a zombie's Marke (the HUD tints the hitmarker violet;
## emitted by the host's zombie and by a client's predicted hit), and a kill from a Marke hit, right after the
## normal kill reward (stats, the bonus slip, the squad's lines).
signal marke_hit(by_player: int)
signal marke_kill(by_player: int, enemy_id: StringName)
signal explosion(position: Vector3, radius: float)
signal boss_spawned(enemy_id: StringName)
signal player_status(player: int, effect: StringName, seconds: float)
signal player_damaged(player: int, amount: float)
signal player_downed(player: int)
signal player_revived(player: int, by_player: int)
signal self_revive(player: int, uses_left: int)
signal low_ammo(player: int, weapon_id: StringName)
signal no_ammo(player: int, weapon_id: StringName)

# Economy & buying
signal scrip_changed(player: int, total: int, delta: int)
## A named bonus for the HUD's toast (T-078): Scrip bonuses (round pay, a clean round, a headshot streak, salvage)
## and gifts (the round-5 tonic bottle). `amount` is the Scrip (0 for a gift); `label` the toast text.
signal bonus_awarded(player: int, kind: StringName, amount: int, label: String)
signal purchase_made(player: int, item_id: StringName, cost: int)
signal purchase_denied(player: int, item_id: StringName, reason: StringName)
signal door_opened(door_id: StringName, by_player: int)
signal zone_opened(zone_id: StringName)
signal board_repaired(window_id: StringName, by_player: int)
signal ammo_bought(player: int, weapon_id: StringName)

# Weapons, perks, crate, crucible
signal weapon_acquired(player: int, weapon_id: StringName, source: StringName)
signal perk_bought(player: int, perk_id: StringName)
signal perk_denied(player: int, perk_id: StringName, reason: StringName)
signal perks_lost(player: int)
signal perks_changed(player: int)
## Overclock Cordial's static burst landed (WEAPONS.md section 20.2): spent = how empty the mag was (0.25..1).
signal overclock_burst(player: int, position: Vector3, spent: float, radius: float)
signal crate_opened(player: int)
signal crate_result(player: int, weapon_id: StringName, quality: StringName)
signal crate_drummer(location_index: int)
signal crate_moved(new_location_index: int)
signal weapon_upgraded(player: int, weapon_id: StringName)
## The Crucible: a weapon went in (the Operator's CRUCIBLE_START), the forge finished (CRUCIBLE_READY), nobody took it (CRUCIBLE_EXPIRE).
signal crucible_started(player: int, weapon_id: StringName)
signal crucible_ready(weapon_id: StringName)
signal crucible_expired(weapon_id: StringName)

# Power-ups
signal powerup_spawned(powerup_id: StringName, position: Vector3)
signal powerup_collected(powerup_id: StringName, by_player: int)
signal powerup_expired(powerup_id: StringName)

# World / quest
signal power_activated()
signal flag_changed(flag: StringName, value: Variant)
signal pylon_state_changed(pylon_id: StringName, state: StringName)
signal trap_activated(trap_id: StringName, by_player: int)
signal radio_tuned(freq_index: int)
signal quest_step_completed(quest_id: StringName, step_id: StringName)
signal quest_completed(quest_id: StringName)
signal quest_step_failed(quest_id: StringName, step_id: StringName, reason: StringName)
signal item_picked_up(item_id: StringName, by_player: int)
signal buildable_completed(buildable_id: StringName, by_player: int)
## Magpie Mead (T-105): a kill left something for `player` at `position` (ammo / scrip / grenade / powerup).
signal magpie_drop(player: int, kind: StringName, position: Vector3)
## A survivor left the ground on purpose (a jump, a slide-jump, a Skyhook hop): the Skyhook cabinet's propeller listens.
signal player_jumped(player: int, at: Vector3)
signal cylinder_played(index: int)
signal shootable_hit(target_id: StringName, weapon_id: StringName, upgraded: bool, by_player: int)
## Every trigger pull that fires (muzzle origin + aim direction). Perk machines use it to reveal their plan-ID
## stencils in an upgraded weapon's muzzle flash (T&C section 11.2).
signal weapon_fired(player: int, weapon_id: StringName, upgraded: bool, origin: Vector3, direction: Vector3)
## The Totenglocke's Great Toll rang (T-095): Effects draws the refraction ring racing out to `range_m` from `origin`.
signal great_toll(player: int, origin: Vector3, direction: Vector3, range_m: float)
signal intel_found(intel_id: StringName)

# VO / presentation
signal vo_line_started(line_id: StringName, speaker: StringName, text: String, duration: float)

# Debug
signal dev_overlay_toggled(overlay: StringName, enabled: bool)

## Suppressed shots (UPDATE_04 section 6): the shooter marks each shot just before weapon_fired is emitted, so a
## weapon_fired listener can ask shot_is_suppressed(player) during the emit (the minimap skips its firing reveal
## for a suppressed M1911). WeaponInstance.is_suppressed() answers the same for a held weapon.
var _suppressed_shot: Dictionary = {}


func mark_shot(player: int, suppressed: bool) -> void:
	_suppressed_shot[player] = suppressed


func shot_is_suppressed(player: int) -> bool:
	return bool(_suppressed_shot.get(player, false))
