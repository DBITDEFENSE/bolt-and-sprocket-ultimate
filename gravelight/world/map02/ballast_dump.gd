class_name BallastDump
extends Interactable
## Ballast v2's second destination (UPDATE 10 contract C2, design section 3, DECISIONS T-153): the sea stairs on the
## quay's north parapet. A player carrying a BallastCoffin holds [interact] to put it over the side: the coffin is
## gone (it respawns on a pallet later), `ballast_dumped` counts up (a GameState flag holding the count), the
## Operator is snippy and the next round brings one more Glasshide (TotenhafenBallast listens to
## GLBus.ballast_dumped). Letzte Fahrt needs three dumped; the third leaves the Undertow's shard on the stairs.
## Co-op: the host decides, every peer mirrors `dumped(n)`.

@export var config_table: String = "map02"
@export var flag: StringName = &"ballast_dumped"

var count: int = 0


func _ready() -> void:
	interact_size = Vector3(2.6, 2.0, 2.4)
	interact_offset = Vector3(0, 1.0, 0)
	super._ready()
	add_to_group(&"ballast_dumps")


func build_greybox() -> void:
	var g: Node3D = Node3D.new()
	g.name = "Art"
	add_child(g)
	# a rope bollard and the chalked line on the landing stage where the coffins go over
	var iron: StandardMaterial3D = greybox_mat(Color(0.16, 0.17, 0.18))
	add_box(g, Vector3(0.3, 0.6, 0.3), Vector3(-0.9, 0.3, 0.6), iron)
	add_box(g, Vector3(0.3, 0.6, 0.3), Vector3(0.9, 0.3, 0.6), iron)
	var l: Label3D = add_label(self, "ÜBER BORD", Vector3(0, 0.03, 0), 26, Color(0.85, 0.85, 0.8, 0.7))
	l.rotation.x = -PI * 0.5


func _carried_by(pid: int) -> BallastCoffin:
	for n: Node in get_tree().get_nodes_in_group(&"ballast_coffins"):
		var c: BallastCoffin = n as BallastCoffin
		if c != null and c.carrier == pid and not c.delivered:
			return c
	return null


func get_prompt(player: Player) -> String:
	if _carried_by(player.player_id) == null:
		return ""
	return "Hold [%s] to put the coffin over the side (dumped: %d)" % [prompt_key(&"interact"), count]


func can_interact(player: Player) -> bool:
	return _carried_by(player.player_id) != null


func hold_time(_player: Player) -> float:
	return float(BallastCoffin.cfg(config_table).get("dump_seconds", 1.5))


func interact(player: Player) -> void:
	var c: BallastCoffin = _carried_by(player.player_id)
	if c == null or not Net.is_authority():
		return
	c.deliver()
	Net.mirror(c, &"deliver")
	dumped(count + 1)
	Net.mirror(self, &"dumped", [count])
	GLBus.ballast_dumped.emit(count, player.player_id)


## `n` coffins have gone over (every peer runs it; the host sets the flag).
func dumped(n: int) -> void:
	count = n
	AudioDirector.play_3d("water_splash", global_position + Vector3(0, -1.0, -1.5), 2.0, 0.05)
	AudioDirector.play_3d("board_slam", global_position, -4.0, 0.1)
	if Net.is_authority():
		GameState.set_flag(flag, count)
