class_name SquadCrate
extends AmmoBox
## T-142: a relief squad's ammunition crate, left where a soldier fell (or the survivor's gift): an ammo box that
## costs nothing, good for `uses_left` refills (squads.json loot.crate_uses), then gone. It also goes after
## `seconds_left` (loot.loot_seconds) so the floor does not fill up with crates over a long match.

@export var uses_left: int = 4
@export var seconds_left: float = 90.0


func _ready() -> void:
	box_name = "relief squad crate"
	super._ready()
	add_to_group(&"squad_loot")


func _process(delta: float) -> void:
	if not Net.is_authority():
		return
	seconds_left -= delta
	if seconds_left <= 0.0:
		queue_free()


func get_prompt(player: Player) -> String:
	var q: Dictionary = quote(player.weapons, cfg(), 0.0)
	if not bool(q["refill_weapon"]) and not bool(q["refill_grenades"]):
		return "Ammo full"
	var left: float = cooldown_left(player.player_id)
	if left > 0.0:
		return "Restocking... %.0f" % ceilf(left)
	return "Hold [%s] for the relief squad's ammunition (free, %d left)" % [prompt_key(&"interact"), uses_left]


func can_interact(player: Player) -> bool:
	var q: Dictionary = quote(player.weapons, cfg(), 0.0)
	return uses_left > 0 and (bool(q["refill_weapon"]) or bool(q["refill_grenades"])) and cooldown_left(player.player_id) <= 0.0


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	if use_holder(player.weapons, player.player_id, player.player_id, 0.0) == &"ok":
		uses_left -= 1
		feedback_2d(player, "reload_end")
		if uses_left <= 0:
			queue_free()
