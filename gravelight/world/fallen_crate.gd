class_name FallenCrate
extends SquadCrate
## UPDATE 11 (T-192, Hard Truth): a squad member's death crate, left where their risen body was put down: the relief
## squads' free ammunition crate (SquadCrate: `uses_left` refills, gone after `seconds_left`), named for them.
## enemies.json hard_truth.crate_uses / crate_seconds. Spawned on the host by HardTruth and mirrored to every client
## (NetMatch.spawn_dynamic sets owner_name, uses_left and seconds_left before _ready).

@export var owner_name: String = ""


func _ready() -> void:
	super._ready()
	box_name = "%s's kit" % owner_name if owner_name != "" else "a fallen survivor's kit"
	add_to_group(&"fallen_crates")


func get_prompt(player: Player) -> String:
	var q: Dictionary = quote(player.weapons, cfg(), 0.0)
	if not bool(q["refill_weapon"]) and not bool(q["refill_grenades"]):
		return "Ammo full"
	var left: float = cooldown_left(player.player_id)
	if left > 0.0:
		return "Restocking... %.0f" % ceilf(left)
	var who: String = ("%s's" % owner_name) if owner_name != "" else "the fallen survivor's"
	return "Hold [%s] for %s ammunition (free, %d left)" % [prompt_key(&"interact"), who, uses_left]
