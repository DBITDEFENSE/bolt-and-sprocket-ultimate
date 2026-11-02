class_name TowerLadder
extends Interactable
## The radar tower's ladder (UPDATE 10 §3 Act III, row 8 "verticality"; DECISIONS T-157): the sniper perch on the
## lattice's 16 m deck. Holding Use at the foot climbs the player up the south-face ladder (`climb_s`, the view
## rising with them, weapons down), at the top it sets them on the deck; the same ladder at the top (a second
## TowerLadder with `down` set) climbs them back down. The zombies get up there too, by their own climb link
## (map04c.json climb_links "TowerPerch"), so the perch is a good spot, not a safe one.

@export var down: bool = false
@export var to_pos: Vector3 = Vector3.ZERO      # where the climb ends (world)
@export var climb_s: float = 3.0

var climbs: int = 0                             # the smoke
var _busy: Dictionary = {}                      # player id -> true while climbing


func _ready() -> void:
	interact_size = Vector3(1.2, 2.0, 1.0)
	interact_offset = Vector3(0, 1.0, 0)
	super._ready()
	add_to_group(&"tower_ladders")


func get_prompt(_player: Player) -> String:
	return "Hold [%s] to climb %s the radar tower" % [prompt_key(&"interact"), "down" if down else "up"]


func can_interact(player: Player) -> bool:
	return player != null and player.is_alive() and not bool(player.get("downed")) and not _busy.has(player.player_id)


func hold_time(_player: Player) -> float:
	return 0.4


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	climb(player)


## The climb moves the user's own body: it runs on their machine (co-op), like the other movement.
func net_local() -> bool:
	return true


## The climb: the player is carried up (or down) the ladder line over climb_s, then set at to_pos.
func climb(player: Player) -> void:
	_busy[player.player_id] = true
	climbs += 1
	var from: Vector3 = player.global_position
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	var foot: Vector3 = global_position
	var tw: Tween = create_tween()
	# onto the ladder, then the long climb, then off onto the deck (or the ground)
	tw.tween_property(player, "global_position", Vector3(foot.x, from.y, foot.z), 0.25)
	tw.tween_property(player, "global_position", Vector3(foot.x, to_pos.y, foot.z if not down else to_pos.z), climb_s)
	tw.tween_property(player, "global_position", to_pos, 0.35)
	tw.finished.connect(func() -> void:
		if is_instance_valid(player):
			player.set_physics_process(true)
			player.velocity = Vector3.ZERO
		_busy.erase(player.player_id))
	AudioDirector.play_3d("footstep_metal", foot + Vector3.UP, 0.0)
