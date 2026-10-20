class_name RevivePoint
extends Interactable
## Co-op revive (GDD §3): a child of every Player in an online match. While its owner is downed (crawling, not
## yet bled out) a teammate can hold use on them: 4 s, or 2 s when the reviver has Second Wind (perks.json
## revive_speed_mult). The bleed-out clock pauses while the hold is on (hold_changed). Host-validated: the host
## runs interact() with the reviver's puppet and NetMatch.coop_revive() decides.

var owner_player: Player


func _ready() -> void:
	interact_size = Vector3(1.8, 1.0, 1.8)
	interact_offset = Vector3(0, 0.45, 0)
	super._ready()
	area.collision_layer = 0


func _physics_process(_delta: float) -> void:
	var on: bool = owner_player != null and not owner_player.is_local and _owner_downed()
	var want: int = LAYER_INTERACTABLE if on else 0
	if area.collision_layer != want:
		area.collision_layer = want


## Downed and still bleeding out (the replicated life state on clients, the authority's on the host).
func _owner_downed() -> bool:
	if owner_player == null or Net.session == null:
		return false
	return Net.session.coop.is_downed(owner_player.player_id)


func get_prompt(player: Player) -> String:
	if not can_interact(player):
		return ""
	return "Hold [%s] to revive %s" % [prompt_key(&"interact"), Net.display_name(owner_player.player_id)]


func can_interact(player: Player) -> bool:
	return player != owner_player and player.is_alive() and not player.spectating and _owner_downed()


func hold_time(player: Player) -> float:
	var base: float = float(GLData.table("player")["revive_seconds"])
	return CoopState.revive_seconds(base, float(PerkManager.stat(player.player_id, "revive_speed_mult", 1.0)))


func hold_changed(player: Player, active: bool) -> void:
	if owner_player == null or Net.session == null:
		return
	if Net.is_client():
		if player.is_local:
			Net.session.request_hold(self, active)
		return
	Net.session.coop.set_reviver(owner_player.player_id, player.player_id, active)


func interact(player: Player) -> void:
	if Net.is_host() and Net.session != null and can_interact(player):
		var max_d: float = float(GLData.table("net").get("revive_max_distance_m", 3.2))
		if player.global_position.distance_to(owner_player.global_position) <= max_d + 1.0:
			Net.session.coop_revive(owner_player.player_id, player.player_id)
