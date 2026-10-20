class_name Workbench
extends Interactable
## The Generator Hall workbench: with all three parts, hold to build the Totenglocke (3 s, Deacon 15% faster).
## Once built, every player may take one Totenglocke from it, free.

@export var buildable_id: StringName = &"totenglocke"
@export var build_seconds: float = 3.0

var built: bool = false
var _taken_by: Dictionary = {}
var _bell_vis: Node3D
var _part_vis: Dictionary = {}   # part id -> its model on the bench (shown once found)

const BENCH_TOP: float = 1.0


func _ready() -> void:
	interact_size = Vector3(2.0, 1.2, 0.3)
	interact_offset = Vector3(0, 0.9, -0.45)
	super._ready()
	add_to_group(&"workbenches")


func build_greybox() -> void:
	# tools, the blueprint and three chalked part outlines on the bench top (the bench itself is map geometry,
	# running from this node toward local +Z, top at BENCH_TOP); the parts appear on it as they're found
	InteractableArt.place(self, "bench_tools", func(r: Node3D) -> void:
		InteractableArt.bench_tools(r, BENCH_TOP)
		InteractableArt.bench_slots(r, BENCH_TOP))
	var builders: Array = [
		func(r: Node3D) -> void: InteractableArt.part_bell(r),
		func(r: Node3D) -> void: InteractableArt.part_frame(r),
		func(r: Node3D) -> void: InteractableArt.part_crank(r)]
	var ids: Array = BuildablePart.NAMES.keys()
	for i: int in ids.size():
		var pid: StringName = StringName(ids[i])
		var mi: MeshInstance3D = InteractableArt.place(self, "tg_" + String(pid), builders[i % 3], Vector3(-0.55 + i * 0.55, BENCH_TOP, 0.22))
		_part_vis[pid] = mi
	_bell_vis = Node3D.new()
	_bell_vis.position = Vector3(0, BENCH_TOP, 0.3)
	add_child(_bell_vis)
	InteractableArt.place(_bell_vis, "totenglocke_built", func(r: Node3D) -> void: InteractableArt.totenglocke(r))
	_bell_vis.hide()
	var glow: OmniLight3D = OmniLight3D.new()
	glow.light_color = Color(1.0, 0.75, 0.45)
	glow.light_energy = 0.5
	glow.omni_range = 2.6
	glow.position = Vector3(0.95, BENCH_TOP + 0.35, 0.9)
	add_child(glow)
	add_label(self, "WORKBENCH", Vector3(0, 1.9, -0.3), 22, Color(0.85, 0.6, 1.0))
	GLBus.item_picked_up.connect(func(_id: StringName, _p: int) -> void: _refresh_parts())
	GLBus.flag_changed.connect(func(f: StringName, _v: Variant) -> void:
		if String(f).begins_with("part_"):
			_refresh_parts())
	_refresh_parts()


func _refresh_parts() -> void:
	for pid: Variant in _part_vis.keys():
		(_part_vis[pid] as Node3D).visible = not built and BuildablePart.has_part(StringName(pid))


func get_prompt(player: Player) -> String:
	var key: String = prompt_key(&"interact")
	if built:
		if _taken_by.has(player.player_id) and player.weapons.find_weapon_base(&"totenglocke") != null:
			return ""
		return "Hold [%s] to take the Totenglocke" % key
	if BuildablePart.parts_held() >= 3:
		return "Hold [%s] to build the Totenglocke" % key
	var parts: PackedStringArray = []
	for id: Variant in BuildablePart.NAMES.keys():
		parts.append(("[x] " if BuildablePart.has_part(StringName(id)) else "[ ] ") + str(BuildablePart.NAMES[id]))
	return "Totenglocke parts:  " + "   ".join(parts)


func can_interact(player: Player) -> bool:
	if built:
		return player.weapons.find_weapon_base(&"totenglocke") == null
	return BuildablePart.parts_held() >= 3


func hold_time(player: Player) -> float:
	if built:
		return super.hold_time(player)
	var t: float = build_seconds
	if GameState.player_has_trait(player.player_id, &"deacon"):
		t *= float(GLData.table("player")["traits"]["deacon_work_speed_mult"])
	return t


func interact(player: Player) -> void:
	if not built:
		if BuildablePart.parts_held() < 3:
			return
		build(player.player_id)
		return
	if player.weapons.find_weapon_base(&"totenglocke") == null:
		player.weapons.give_weapon(&"totenglocke")
		_taken_by[player.player_id] = true
		GLBus.weapon_acquired.emit(player.player_id, &"totenglocke", &"workbench")


func build(by_player: int) -> void:
	if built:
		return
	_net_built()
	Net.mirror(self, &"_net_built")
	GLBus.buildable_completed.emit(buildable_id, by_player)


func _net_built() -> void:
	if built:
		return
	built = true
	if _bell_vis != null:
		_bell_vis.show()
	_refresh_parts()
	AudioDirector.play_3d("door_open", global_position + Vector3.UP, 0.0)
	AudioDirector.play_3d("headshot", global_position + Vector3.UP, 4.0, 0.0)
