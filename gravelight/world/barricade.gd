class_name Barricade
extends Interactable
## A window with 6 boards. Zombies tear boards from outside then climb in; players repair from inside.
## Origin: floor level, centered on the wall plane. Local +Z points INTO the room.
## The window opening always blocks players (layer "barricade"); zombies cross it with a scripted climb.

const LAYER_BARRICADE: int = 1 << 5

@export var window_id: StringName = &"window"
@export var zone_id: StringName = &""
@export var width: float = 1.6
@export var sill_height: float = 0.9
@export var top_height: float = 2.2
## A cellar window in a light well (Map 0's Old Cellar, Update 02 section 6.1): the room's floor is this far below
## the origin (the well's floor). Zombies climb in and drop to the room floor (the drop clip plays once the fall is
## over anim.json climb.high_window_m), and the repair area hangs low enough to reach from the room floor.
@export var inside_drop: float = 0.0

var boards: int = 6
var max_boards: int = 6
var occupant: Node3D = null      # the zombie currently tearing/climbing
var _board_nodes: Array[MeshInstance3D] = []
var _board_home: Array[Transform3D] = []


func _ready() -> void:
	max_boards = int(GLData.table("world")["barricade"]["boards"])
	boards = max_boards
	# Thin and flush with the inner face, so the player's view ray can never start inside it.
	interact_size = Vector3(width + 0.6, 2.2, 0.3)
	interact_offset = Vector3(0, 1.3, 0.3)
	if inside_drop > 0.0:
		# from 0.7 m above the room floor up to the window's top, just inside the wall
		var lo: float = 0.7 - inside_drop
		interact_size = Vector3(width + 0.6, top_height - lo, 0.3)
		interact_offset = Vector3(0, (top_height + lo) * 0.5, 0.35)
	super._ready()
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = LAYER_BARRICADE
	body.collision_mask = 0
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(width, top_height - sill_height + 0.6, 0.4)
	cs.shape = box
	cs.position = Vector3(0, (sill_height + top_height) * 0.5 + 0.3, 0)
	body.add_child(cs)
	add_child(body)
	add_to_group(&"barricades")


## Our planks' length (tools_src/blender/world/barricade_planks.py): a 1.6 m window plus the overlap.
const PLANK_MODEL_LEN: float = 1.85


func build_greybox() -> void:
	# nailed planks: our six board models, one per slot with its own splinters (UPDATE_05 section 5, T-094), offset
	# per window so neighbours differ; InteractableArt.board_mesh's three procedural variants when absent
	var span: float = top_height - sill_height
	var shift: int = int(absf(position.x) + absf(position.z))
	for i: int in max_boards:
		var mi: MeshInstance3D = MeshInstance3D.new()
		var plank: Mesh = WorldArt.part_mesh("barricade_planks", "Plank%d" % ((i + shift) % 6))
		var stretch: float = 1.0
		if plank != null:
			mi.mesh = plank
			stretch = (width + 0.25) / PLANK_MODEL_LEN
		else:
			mi.mesh = InteractableArt.board_mesh(width + 0.25, (i * 2 + int(absf(position.x))) % 3)
		var y: float = sill_height + span * (float(i) + 0.5) / float(max_boards)
		var tilt: float = deg_to_rad([-9.0, 7.0, -4.0, 11.0, -7.0, 5.0][i % 6])
		var t: Transform3D = Transform3D(Basis(Vector3.FORWARD, tilt) * Basis.from_scale(Vector3(stretch, 1.0, 1.0)), Vector3(0, y, 0.12))
		mi.transform = t
		add_child(mi)
		_board_nodes.append(mi)
		_board_home.append(t)


func outside_point() -> Vector3:
	return to_global(Vector3(0, 0, -0.9))


func inside_point() -> Vector3:
	return to_global(Vector3(0, -inside_drop, 1.0))


## Where waiting zombies stand, further out from the window.
func queue_point(index: int) -> Vector3:
	var side: float = -1.3 if index % 2 == 0 else 1.3
	return to_global(Vector3(side, 0, -2.4 - 0.9 * float(index >> 1)))


func sill_point() -> Vector3:
	return to_global(Vector3(0, sill_height + 0.15, 0))


func claim(zombie: Node3D) -> bool:
	if occupant == null or not is_instance_valid(occupant) or occupant == zombie:
		occupant = zombie
		return true
	return false


func release(zombie: Node3D) -> void:
	if occupant == zombie:
		occupant = null


func tear_board() -> bool:
	if boards <= 0:
		return false
	boards -= 1
	Net.mirror(self, &"_net_boards", [boards])
	_tear_visual(boards)
	return true


func _tear_visual(index: int) -> void:
	var mi: MeshInstance3D = _board_index(index)
	if mi != null:
		var tw: Tween = create_tween()
		tw.tween_property(mi, "position", mi.position + Vector3(randf_range(-0.6, 0.6), -0.4, -1.2), 0.35)
		tw.parallel().tween_property(mi, "rotation:z", mi.rotation.z + randf_range(-1.5, 1.5), 0.35)
		tw.tween_callback(mi.hide)
	AudioDirector.play_3d("board_break", global_position + Vector3(0, 1.4, 0), -2.0)


func repair_board(player: Player) -> void:
	if boards >= max_boards:
		return
	boards += 1
	Net.mirror(self, &"_net_boards", [boards])
	_repair_visual(boards - 1)
	var before: int = Economy.get_scrip(player.player_id)
	Economy.award_repair(player.player_id)
	if Economy.get_scrip(player.player_id) > before:   # the board paid: Carpenter's Pencil adds its bit (T-079)
		Economy.award(player.player_id, int(Muster.value(player.player_id, "board_scrip", 0)))
	GLBus.board_repaired.emit(window_id, player.player_id)
	if occupant != null and is_instance_valid(occupant) and occupant.has_method("on_board_repaired"):
		occupant.call("on_board_repaired")


func _repair_visual(index: int) -> void:
	var mi: MeshInstance3D = _board_index(index)
	if mi != null:
		var home: Transform3D = _board_home[index]
		mi.show()
		mi.transform = Transform3D(home.basis.rotated(Vector3.UP, 0.6), home.origin + Vector3(0, 0, 0.9))
		var tw: Tween = create_tween()
		tw.tween_property(mi, "transform", home, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	AudioDirector.play_3d("board_place", global_position + Vector3(0, 1.4, 0.4), -1.0)


## Co-op client: the host's board count (torn by its zombies, rebuilt by anyone).
func _net_boards(n: int) -> void:
	n = clampi(n, 0, max_boards)
	if n >= max_boards and boards < max_boards - 1:
		fortify()
		return
	while boards > n:
		boards -= 1
		_tear_visual(boards)
	while boards < n:
		boards += 1
		_repair_visual(boards - 1)


## Instantly restores every board (Fortify power-up, M2).
func fortify() -> void:
	if boards < max_boards:
		Net.mirror(self, &"fortify")
	while boards < max_boards:
		var mi: MeshInstance3D = _board_index(boards)
		boards += 1
		if mi != null:
			mi.show()
			mi.transform = _board_home[boards - 1]


func _board_index(i: int) -> MeshInstance3D:
	if i >= 0 and i < _board_nodes.size():
		return _board_nodes[i]
	return null


func get_prompt(_player: Player) -> String:
	if boards >= max_boards:
		return ""
	return "Hold [%s] to rebuild barricade" % prompt_key(&"interact")


func can_interact(_player: Player) -> bool:
	return boards < max_boards


func hold_time(player: Player) -> float:
	var t: float = float(GLData.table("world")["barricade"]["repair_seconds"])
	if GameState.player_has_trait(player.player_id, &"deacon"):
		t *= float(GLData.table("player")["traits"]["deacon_work_speed_mult"])
	return t


func repeats() -> bool:
	return true


func interact(player: Player) -> void:
	repair_board(player)
