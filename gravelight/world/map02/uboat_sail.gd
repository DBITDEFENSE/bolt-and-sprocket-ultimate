class_name UboatSail
extends Interactable
## THE LAST VOYAGE (Letzte Fahrt s9, UPDATE 10 contracts C2 "the boat" and C3, design section 6, DECISIONS T-153):
## the moving holdout on U-1047's deck and in her tower. Once the curtain is open (flag `curtain_open`), cast off at the
## helm (or the boat casts off by itself when every living player has been aboard for `auto_cast_s`). For
## `sail_seconds` the boat "sails": the host owns one float, `sail_t` 0..1 (mirrored at 4 Hz), and everything follows
## it: the scenery cards (the pen mouth, the breakwater light, the dead boat at the breakwater, the burning town on
## the cliff) scroll past, the open sea and the storm surround the boat, boarders come over the saddle tanks at
## `board_points`, the drowned drag at the hull (a lurch and a groan every `shake_every_s`), the tower searchlight
## tracks her (flag `sailing`), and Hinnerk Petersen takes the wheel if he is with the squad. Anyone who goes over the
## side is hauled back to the helm and takes `overboard_damage`. At 1.0: flag `lf_sailed` (the quest's s9), then the
## dive cutscene (s10).
## Why the boat does not move: U-1047's hull, deck colliders and navmesh are baked into the static geometry (T-145);
## moving them would re-lay the map, which U10 forbids. The motion is relative: the world scrolls past her, and from
## `hall_hide_at` the pen hall's visibility groups are hidden behind a lightning flash (a ViewCells cell over the deck
## that shows only the boat's groups), so the deck stands in open water. Colliders and navigation are untouched.

enum State { WAITING, READY, SAILING, DONE }

const QUEST: StringName = &"map02_letzte_fahrt"

var state: State = State.WAITING
var sail_t: float = 0.0
var boarders_sent: int = 0
var overboard_saves: int = 0

var _cfg: Dictionary = {}
var _aboard_t: float = 0.0
var _board_t: float = 0.0
var _shake_t: float = 0.0
var _net_t: float = 0.0
var _check_t: float = 0.0
var _stage: Node3D
var _cards: Dictionary = {}
var _hall_hidden: bool = false
var _cell_added: bool = false
var _hum: AudioStreamPlayer3D


func _ready() -> void:
	_cfg = (GLData.load_json("res://data/gravelight/map02.json").get("letzte_fahrt", {}) as Dictionary).get("boat", {})
	interact_size = Vector3(1.4, 1.8, 1.4)
	interact_offset = Vector3(0, 0.9, 0)
	super._ready()
	add_to_group(&"uboat_sail")
	GLBus.flag_changed.connect(_on_flag)


func build_greybox() -> void:
	var brass: StandardMaterial3D = greybox_mat(Color(0.6, 0.47, 0.22))
	add_box(self, Vector3(0.3, 1.0, 0.3), Vector3(0, 0.5, 0), greybox_mat(Color(0.2, 0.21, 0.22)))
	var wheel: MeshInstance3D = MeshInstance3D.new()
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = 0.3
	tm.outer_radius = 0.36
	wheel.mesh = tm
	wheel.material_override = brass
	wheel.rotation.x = PI * 0.5
	wheel.position = Vector3(0, 1.1, -0.2)
	add_child(wheel)
	var l: Label3D = add_label(self, "U-1047", Vector3(0, 0.75, -0.16), 16, Color(0.9, 0.85, 0.7))
	l.rotation.y = 0.0


# ------------------------------------------------------------------ pure rules (tested)

## sail_t after `dt` of sailing for `seconds` total.
static func advance(t: float, dt: float, seconds: float) -> float:
	return minf(1.0, t + dt / maxf(1.0, seconds))


## A scenery card's z at sail progress `t` (the world scrolls north past a boat sailing south).
static func card_z(base_z: float, t: float, scroll_m: float, parallax: float) -> float:
	return base_z - t * scroll_m * parallax


## Is `p` aboard (the deck and the boat's interior)?
static func aboard(p: Vector3, box: AABB) -> bool:
	return box.has_point(p)


func _aboard_box() -> AABB:
	var b: Array = _cfg.get("aboard_box", [[3.8, -2.6, 37.4], [10.2, 6.0, 86.8]])
	var lo: Vector3 = Vector3(float(b[0][0]), float(b[0][1]), float(b[0][2]))
	var hi: Vector3 = Vector3(float(b[1][0]), float(b[1][1]), float(b[1][2]))
	return AABB(lo, hi - lo)


# ------------------------------------------------------------------ casting off

func _on_flag(flag: StringName, value: Variant) -> void:
	if flag == &"curtain_open" and bool(value) and state == State.WAITING:
		state = State.READY


func get_prompt(_player: Player) -> String:
	match state:
		State.READY:
			return "Hold [%s] to cast off. (Everyone aboard: she won't wait.)" % prompt_key(&"interact")
		State.WAITING:
			return "The curtain is shut. She can't leave the pen."
	return ""


func can_interact(_player: Player) -> bool:
	return state == State.READY


func hold_time(_player: Player) -> float:
	return 1.5


func interact(_player: Player) -> void:
	if Net.is_authority() and state == State.READY:
		cast_off()


## BotEE hold_zone anchors: charging = the sail is on (hold the deck).
func is_holding() -> bool:
	return state == State.SAILING


func cast_off() -> void:
	if state == State.SAILING or state == State.DONE:
		return
	state = State.SAILING
	sail_t = 0.0
	_board_t = 2.0
	_shake_t = float(_cfg.get("shake_every_s", 9.0))
	_build_stage()
	_hum = AudioDirector.make_loop_3d("diesel_start", self)
	AudioDirector.play_3d("boat_horn", global_position + Vector3.UP * 3.0, 6.0, 0.0)
	GLBus.sail_started.emit()
	if Net.is_authority():
		GameState.set_flag(&"sailing", true)
		GameState.set_flag(&"holdout", true)
		RoundManager.set_hold(&"lf_sail", true)
		var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
		if dir != null:
			dir.set_spawn_boost(&"E_UBOAT", 2.0)
		_hinnerk_to_helm()
		GLVO.play(&"OPR_LF_SAIL_01")
		Net.mirror(self, &"cast_off")


func _hinnerk_to_helm() -> void:
	for c: Node in get_tree().get_nodes_in_group(&"map_companion"):
		var p: Player = c.get("player") as Player
		if p != null and is_instance_valid(p) and str(c.get("id")) == "petersen" and p.is_alive():
			p.global_position = global_position + global_basis * Vector3(0, 0, -1.0)
			GLVO.play(&"PET_LF_HELM_01")
			return


# ------------------------------------------------------------------ sailing

func _physics_process(delta: float) -> void:
	if state == State.READY and Net.is_authority():
		_auto_cast(delta)
	if state != State.SAILING:
		return
	_present(delta)
	if not Net.is_authority():
		return
	sail_t = advance(sail_t, delta, float(_cfg.get("sail_seconds", 150.0)))
	_net_t -= delta
	if _net_t <= 0.0:
		_net_t = 0.25
		Net.mirror(self, &"_net_sail", [sail_t])
	GLBus.sail_progress.emit(sail_t)
	_board_t -= delta
	if _board_t <= 0.0:
		_board_t = float(_cfg.get("board_every_s", 5.0))
		_send_boarders()
	_shake_t -= delta
	if _shake_t <= 0.0:
		_shake_t = float(_cfg.get("shake_every_s", 9.0))
		_lurch()
		Net.mirror(self, &"_lurch")
	_check_t -= delta
	if _check_t <= 0.0:
		_check_t = 0.5
		_overboard()
	if sail_t >= 1.0:
		_arrive()


## No one has to find the prompt: once every living player has been aboard `auto_cast_s`, she goes.
func _auto_cast(delta: float) -> void:
	var box: AABB = _aboard_box()
	var any: bool = false
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or not p.is_alive() or p.spectating:
			continue
		any = true
		if not aboard(p.global_position, box):
			_aboard_t = 0.0
			return
	if not any:
		return
	_aboard_t += delta
	if _aboard_t >= float(_cfg.get("auto_cast_s", 8.0)):
		cast_off()


func _send_boarders() -> void:
	var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
	if dir == null:
		return
	var pts: Array = []
	for a: Variant in _cfg.get("board_points", []):
		pts.append(Vector3(float(a[0]), float(a[1]), float(a[2])))
	if pts.is_empty():
		return
	pts.shuffle()
	boarders_sent += dir.spawn_burst(pts, int(_cfg.get("board_per_wave", 2)))


func _lurch() -> void:
	GLBus.explosion.emit(global_position + Vector3(2.0, -2.0, 10.0), 3.0)
	AudioDirector.play_3d("hull_groan", global_position + Vector3(0, -1.5, 8.0), 3.0, 0.1)


## Over the side: hauled back to the helm, a little hurt (a down only through the normal damage).
func _overboard() -> void:
	var box: AABB = _aboard_box()
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or not p.is_alive() or p.spectating or aboard(p.global_position, box):
			continue
		p.global_position = global_position + global_basis * Vector3(0.8, 0.2, 0.6)
		p.velocity = Vector3.ZERO
		p.take_hit(float(_cfg.get("overboard_damage", 20.0)), self)
		overboard_saves += 1


func _arrive() -> void:
	state = State.DONE
	sail_t = 1.0
	var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
	if dir != null:
		dir.set_spawn_boost(&"E_UBOAT", 1.0)
	RoundManager.set_hold(&"lf_sail", false)
	GameState.set_flag(&"holdout", false)
	GameState.set_flag(&"lf_sailed", true)
	if _hum != null:
		_hum.stop()
	Net.mirror(self, &"_net_arrived")


func _net_sail(t: float) -> void:
	if state != State.SAILING:
		cast_off()
	sail_t = t
	GLBus.sail_progress.emit(t)


func _net_arrived() -> void:
	state = State.DONE
	sail_t = 1.0
	if _hum != null:
		_hum.stop()


# ------------------------------------------------------------------ presentation (every peer)

func _present(_delta: float) -> void:
	if _stage == null:
		return
	var scroll: float = float(_cfg.get("scroll_m", 220.0))
	var cards: Dictionary = _cfg.get("cards", {})
	for k: Variant in _cards.keys():
		var c: Dictionary = cards.get(str(k), {})
		var n: Node3D = _cards[k]
		n.global_position.z = card_z(float(c.get("z", 100.0)), sail_t, scroll, float(c.get("parallax", 1.0)))
	if not _hall_hidden and sail_t >= float(_cfg.get("hall_hide_at", 0.22)):
		_hall_hidden = true
		_flash()
		_set_sea_cell(true)


func _flash() -> void:
	var l: OmniLight3D = OmniLight3D.new()
	l.omni_range = 120.0
	l.light_energy = 9.0
	l.light_color = Color(0.85, 0.9, 1.0)
	l.shadow_enabled = false
	_stage.add_child(l)
	l.global_position = global_position + Vector3(0, 30, 20)
	var tw: Tween = create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.6)
	tw.tween_callback(l.queue_free)
	AudioDirector.play_2d("war_crash_boom", -2.0, 0.0)


## The deck cell: while sailing the camera on the boat sees only the boat's own groups (and everything in ALL,
## which is where the sea stage lives); off again after the dive.
func _set_sea_cell(on: bool) -> void:
	var vc: Node = get_tree().current_scene.get_node_or_null("ViewCells") if get_tree().current_scene != null else null
	if vc == null:
		return
	var cells: Array = vc.get("cells")
	if on and not _cell_added:
		var box: AABB = _aboard_box().grow(1.0)
		box.size.y += 30.0
		cells.insert(0, {"name": "SAIL", "aabb": box, "show": PackedStringArray(["E", "DH"]), "moon": true})
		_cell_added = true
	elif not on and _cell_added:
		for i: int in cells.size():
			if str((cells[i] as Dictionary).get("name", "")) == "SAIL":
				cells.remove_at(i)
				break
		_cell_added = false
	vc.set("cells", cells)
	if vc.has_method("update_now"):
		vc.call("update_now")


## The open sea, the storm's light, the cards; top-level and never a view_cell_member (group ALL: never hidden).
func _build_stage() -> void:
	if _stage != null:
		return
	_stage = Node3D.new()
	_stage.name = "SailStage"
	_stage.top_level = true
	add_child(_stage)
	var sea: MeshInstance3D = MeshInstance3D.new()
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(700, 700)
	sea.mesh = pm
	var sm: StandardMaterial3D = StandardMaterial3D.new()
	sm.albedo_color = Color(0.04, 0.07, 0.09)
	sm.roughness = 0.12
	sm.metallic = 0.4
	sea.material_override = sm
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sea.visible = false
	_stage.add_child(sea)
	sea.global_position = Vector3(7.0, -0.9, 62.0)
	_cards["sea"] = sea
	var cards: Dictionary = _cfg.get("cards", {})
	for k: Variant in cards.keys():
		var c: Dictionary = cards[k]
		var n: Node3D = _card(str(k))
		_stage.add_child(n)
		n.global_position = Vector3(float(c.get("x", 0.0)), 0.0, float(c.get("z", 100.0)))
		_cards[k] = n
	_cards.erase("sea")
	sea.set_meta(&"sea", true)
	_stage.set_meta(&"sea_node", sea)
	GLBus.sail_progress.connect(func(t: float) -> void:
		if is_instance_valid(sea):
			sea.visible = t >= float(_cfg.get("hall_hide_at", 0.22)))


func _card(kind: String) -> Node3D:
	var g: Node3D = Node3D.new()
	g.name = "Card_" + kind
	var concrete: StandardMaterial3D = greybox_mat(Color(0.2, 0.21, 0.22))
	var dark: StandardMaterial3D = greybox_mat(Color(0.05, 0.05, 0.06))
	match kind:
		"pen_mouth":
			add_box(g, Vector3(6, 16, 6), Vector3(-14, 6, 0), concrete)
			add_box(g, Vector3(6, 16, 6), Vector3(28, 6, 0), concrete)
			add_box(g, Vector3(48, 4, 6), Vector3(7, 15, 0), concrete)
		"breakwater":
			add_box(g, Vector3(60, 3, 6), Vector3(10, 0.5, 0), concrete)
			var tower: MeshInstance3D = MeshInstance3D.new()
			var cm: CylinderMesh = CylinderMesh.new()
			cm.top_radius = 1.4
			cm.bottom_radius = 2.0
			cm.height = 14.0
			tower.mesh = cm
			tower.material_override = greybox_mat(Color(0.7, 0.68, 0.62))
			tower.position = Vector3(-14, 8, 0)
			g.add_child(tower)
			var lamp: OmniLight3D = OmniLight3D.new()
			lamp.light_color = Color(1.0, 0.9, 0.7)
			lamp.light_energy = 3.0
			lamp.omni_range = 30.0
			lamp.shadow_enabled = false
			lamp.position = Vector3(-14, 15.5, 0)
			g.add_child(lamp)
		"dead_uboat":
			var hull: MeshInstance3D = add_box(g, Vector3(5, 3, 40), Vector3(0, -0.5, 0), dark)
			hull.rotation = Vector3(0.12, 0.3, 0.2)
			add_box(g, Vector3(2.5, 4, 5), Vector3(0.5, 2.0, 2.0), dark)
		"town":
			for i: int in 9:
				add_box(g, Vector3(8, 6 + float(i % 4) * 3.0, 8), Vector3(float(i) * 11.0 - 44.0, 30.0 + float(i % 3) * 2.0, float(i % 2) * 8.0), dark)
			for j: int in 4:
				var fire: OmniLight3D = OmniLight3D.new()
				fire.light_color = Color(1.0, 0.45, 0.15)
				fire.light_energy = 6.0
				fire.omni_range = 40.0
				fire.shadow_enabled = false
				fire.position = Vector3(float(j) * 25.0 - 36.0, 38.0, 0)
				g.add_child(fire)
	return g


## After the dive: the pen hall back, the stage gone (the cutscene runner calls it).
func end_presentation() -> void:
	if _cell_added:
		_set_sea_cell(false)
	if _stage != null:
		_stage.queue_free()
		_stage = null
	_cards.clear()
	if Net.is_authority():
		GameState.set_flag(&"sailing", false)
