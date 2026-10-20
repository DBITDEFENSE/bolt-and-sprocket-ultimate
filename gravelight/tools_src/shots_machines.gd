extends Node3D
## Dev tool: renders every restyled interactable (D-063) in a dim studio, unpowered then powered.
## Silent, off-screen, no mouse capture:
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . res://gravelight/tools_src/shots_machines.tscn -- --out=<dir> [--only=perk,crucible]
## -> <dir>/mach_<name>_<off|on>.png (default dir user://shots)

const SP: float = 6.0   # spacing between exhibits along X

var _out: String = "user://shots"
var _only: PackedStringArray = []
var _cam: Camera3D
var _key: OmniLight3D
## [name, node, camera offset from the exhibit, look-at offset]
var _shots: Array = []
var _x: float = 0.0
var _env: Environment


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--only="):
			_only = a.substr(7).split(",")
	DirAccess.make_dir_recursive_absolute(_out if _out.is_absolute_path() else ProjectSettings.globalize_path(_out))
	GameState.power_on = false
	_studio()
	await get_tree().process_frame
	await _exhibits()
	await get_tree().create_timer(1.0).timeout
	for pass_i: int in 2:
		if pass_i == 1:
			GameState.power_on = true
			GLBus.power_activated.emit()
			await get_tree().create_timer(0.5).timeout
		for s: Array in _shots:
			if not _only.is_empty() and not _wanted(str(s[0])):
				continue
			var at: Vector3 = (s[1] as Node3D).global_position
			_cam.global_position = at + (s[2] as Vector3)
			_cam.look_at(at + (s[3] as Vector3), Vector3.UP)
			_key.global_position = at + (s[2] as Vector3) * 0.6 + Vector3(1.2, 1.5, 0)
			await get_tree().create_timer(0.35).timeout
			var img: Image = get_viewport().get_texture().get_image()
			var path: String = _out.path_join("mach_%s_%s.png" % [s[0], "on" if pass_i == 1 else "off"])
			img.save_png(path)
			print("shot ", path)
	get_tree().quit()


func _wanted(n: String) -> bool:
	for o: String in _only:
		if n.begins_with(o):
			return true
	return false


func _studio() -> void:
	var we: WorldEnvironment = WorldEnvironment.new()
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.02, 0.02, 0.03)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.3, 0.32, 0.4)
	_env.ambient_light_energy = 0.35
	_env.tonemap_mode = Environment.TONE_MAPPER_AGX
	_env.tonemap_exposure = 1.45
	_env.glow_enabled = true
	_env.glow_intensity = 0.8
	_env.glow_bloom = 0.06
	_env.glow_hdr_threshold = 1.1
	_env.ssao_enabled = true
	we.environment = _env
	add_child(we)
	var floor_: MeshInstance3D = MeshInstance3D.new()
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(260, 40)
	floor_.mesh = pm
	floor_.material_override = Mats.get_mat("concrete_floor")
	floor_.position = Vector3(110, 0, 0)
	add_child(floor_)
	var wall: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(260, 8, 0.4)
	wall.mesh = bm
	wall.material_override = Mats.get_mat("brick")
	wall.position = Vector3(110, 4, 3.2)
	add_child(wall)
	_cam = Camera3D.new()
	_cam.fov = 60
	add_child(_cam)
	_cam.make_current()
	_key = OmniLight3D.new()
	_key.light_color = Color(1.0, 0.85, 0.65)
	_key.light_energy = 1.2
	_key.omni_range = 9.0
	_key.shadow_enabled = true
	add_child(_key)


func _add(n: String, node: Node3D, pos: Vector3, yaw: float, cam: Vector3, look: Vector3) -> Node3D:
	node.position = pos
	node.rotation.y = deg_to_rad(yaw)
	add_child(node)
	_shots.append([n, node, cam, look])
	return node


func _next() -> Vector3:
	_x += SP
	return Vector3(_x, 0, 0)


func _exhibits() -> void:
	# perk dispensers, each alone and then all eight in a row
	var perks: Array = ["ironhide_stout", "second_wind", "trigger_tonic", "twin_barrel", "marathon_malt", "hawkeye_brandy",
		"packmule_porter", "blastproof_bock"]
	var row: Vector3 = _next()
	for i: int in perks.size():
		var pm: PerkMachine = PerkMachine.new()
		pm.perk_id = StringName(perks[i])
		_add("perk_" + str(perks[i]), pm, row + Vector3(i * 2.2, 0, 1.5), 0.0, Vector3(-1.3, 1.7, -2.9), Vector3(0, 1.2, 0))
	var anchor: Node3D = Node3D.new()
	_add("perks_row", anchor, row + Vector3(7.7, 0, 1.5), 0.0, Vector3(0, 2.4, -7.5), Vector3(0, 1.3, 0))
	_x += 17.0
	# the Crucible
	_add("crucible", Crucible.new(), _next() + Vector3(0, 0, 1.0), 0.0, Vector3(-2.2, 2.0, -4.6), Vector3(0, 1.6, 0))
	_x += 2.0
	# barricade (full, and half torn)
	var b1: Barricade = Barricade.new()
	_add("barricade_full", b1, _next() + Vector3(0, 0, 2.6), 180.0, Vector3(-0.8, 1.6, -2.2), Vector3(0, 1.5, 0))
	var b2: Barricade = Barricade.new()
	_add("barricade_torn", b2, _next() + Vector3(0, 0, 2.6), 180.0, Vector3(0.9, 1.6, -2.2), Vector3(0, 1.5, 0))
	# doors
	var d1: BuyDoor = BuyDoor.new()
	d1.label = "Rail Yard"
	d1.size = Vector3(2.0, 2.4, 0.25)
	_add("door_wood", d1, _next() + Vector3(0, 0, 1.0), 0.0, Vector3(-1.2, 1.6, -3.4), Vector3(0, 1.2, 0))
	var d2: BuyDoor = BuyDoor.new()
	d2.label = "Laboratory Wing"
	d2.cost = 2000
	d2.requires_power = true
	d2.size = Vector3(2.0, 2.4, 0.25)
	_add("door_power", d2, _next() + Vector3(0, 0, 1.0), 0.0, Vector3(1.2, 1.6, -3.4), Vector3(0, 1.2, 0))
	# Hauptschalter
	_add("hauptschalter", PowerSwitch.new(), _next() + Vector3(0, 0, 1.0), 0.0, Vector3(-1.0, 1.6, -2.6), Vector3(0, 1.1, 0))
	# pylon
	_add("pylon", Pylon.new(), _next() + Vector3(0, 0, 1.0), 0.0, Vector3(-1.8, 2.2, -4.2), Vector3(0, 1.8, 0))
	_x += 6.0
	# traps + levers
	var cart: OreCartTrap = OreCartTrap.new()
	cart.track_start = Vector3(0, 0, -4)
	cart.track_end = Vector3(0, 0, 6)
	var cp: Vector3 = _next()
	_add("ore_cart", cart, cp, 0.0, Vector3(-2.6, 2.0, -4.5), Vector3(0, 0.6, -2.0))
	var lv: TrapLever = TrapLever.new()
	lv.trap_id = &"ore_cart"
	_add("lever", lv, cp + Vector3(2.2, 0, 1.2), 0.0, Vector3(-0.6, 1.4, -1.6), Vector3(0, 1.1, 0))
	lv.trap_path = lv.get_path_to(cart)
	var wire: LiveWireTrap = LiveWireTrap.new()
	wire.size = Vector3(4.0, 3.0, 1.0)
	_add("live_wire", wire, _next() + Vector3(1, 0, 0.5), 0.0, Vector3(-1.6, 1.8, -4.6), Vector3(0, 1.4, 0))
	_x += 2.0
	# workbench
	var wb: Workbench = Workbench.new()
	var wp: Vector3 = _next() + Vector3(0, 0, 0.6)
	Props.block(self, wp + Vector3(-1.35, 0, 0), wp + Vector3(1.35, 1.0, 1.7), "furniture")
	_add("workbench", wb, wp, 0.0, Vector3(-1.0, 2.0, -2.6), Vector3(0, 1.0, 0.5))
	var wb2: Workbench = Workbench.new()
	var wp2: Vector3 = _next() + Vector3(0, 0, 0.6)
	Props.block(self, wp2 + Vector3(-1.35, 0, 0), wp2 + Vector3(1.35, 1.0, 1.7), "furniture")
	_add("workbench_built", wb2, wp2, 0.0, Vector3(1.0, 2.0, -2.6), Vector3(0, 1.0, 0.5))
	# lift
	var lift: Lift = Lift.new()
	lift.top_y = 0.0
	lift.bottom_y = -12.0
	_add("lift", lift, _next() + Vector3(1.0, 0, 0.0), 0.0, Vector3(-3.0, 2.4, -5.6), Vector3(0, 1.4, 0))
	_x += 3.0
	# quest props
	var qp: Vector3 = _next()
	var tbl: MeshInstance3D = Props.block(self, qp + Vector3(-2.2, 0, 0.2), qp + Vector3(2.2, 0.8, 1.0), "furniture")
	tbl.name = "Table"
	var fr: FieldRadio = FieldRadio.new()
	_add("field_radio", fr, qp + Vector3(-1.6, 0.8, 0.6), 0.0, Vector3(-0.4, 0.6, -1.0), Vector3(0, 0.15, 0))
	var qr: QuestRadio = QuestRadio.new()
	_add("quest_radio", qr, qp + Vector3(-0.6, 0.8, 0.6), 0.0, Vector3(-0.4, 0.6, -1.0), Vector3(0, 0.15, 0))
	var qn: QuestNote = QuestNote.new()
	_add("note", qn, qp + Vector3(0.3, 0.8, 0.6), 0.0, Vector3(-0.2, 0.55, -0.6), Vector3(0, 0, 0))
	var c1: QuestPickup = QuestPickup.new()
	c1.collect_tag = &"cylinder"
	_add("cylinder", c1, qp + Vector3(0.9, 0.8, 0.6), 0.0, Vector3(-0.3, 0.5, -0.8), Vector3(0, 0.1, 0))
	var tag: QuestPickup = QuestPickup.new()
	tag.interact_target = &"kb4471"
	_add("tag", tag, qp + Vector3(1.4, 0.8, 0.6), 0.0, Vector3(-0.2, 0.4, -0.6), Vector3(0, 0.05, 0))
	var shard: QuestPickup = QuestPickup.new()
	shard.item_id = &"nachtglas_shard"
	_add("shard", shard, qp + Vector3(1.9, 0.8, 0.6), 0.0, Vector3(-0.3, 0.5, -0.8), Vector3(0, 0.1, 0))
	var it: IntelPickup = IntelPickup.new()
	it.title = "Test"
	_add("intel", it, qp + Vector3(-1.1, 0.8, 0.5), 0.0, Vector3(-0.2, 0.55, -0.6), Vector3(0, 0, 0))
	var bells: Vector3 = _next()
	var qb: QuestBell = QuestBell.new()
	qb.size = 0.4
	_add("bell_small", qb, bells + Vector3(-1.0, 1.6, 0.5), 0.0, Vector3(-0.6, 0.3, -1.6), Vector3(0, 0, 0))
	var qb2: QuestBell = QuestBell.new()
	qb2.kind = &"chapel"
	qb2.size = 2.0
	_add("bell_chapel", qb2, bells + Vector3(1.5, 2.6, 0.5), 0.0, Vector3(-1.5, 0.2, -4.6), Vector3(0, 0, 0))
	var parts: Vector3 = _next()
	var pi_: int = 0
	for pid: String in ["tg_part_bell", "tg_part_frame", "tg_part_crank"]:
		var bp: BuildablePart = BuildablePart.new()
		bp.part_id = StringName(pid)
		_add("part_" + pid, bp, parts + Vector3(-1.0 + pi_ * 1.0, 0, 0.5), 0.0, Vector3(-0.4, 0.8, -1.3), Vector3(0, 0.15, 0))
		pi_ += 1
	var ph: Phonograph = Phonograph.new()
	_add("phonograph", ph, _next() + Vector3(0, 0, 0.6), 0.0, Vector3(-0.8, 1.5, -1.8), Vector3(0, 0.9, 0))
	var swb: Switchboard = Switchboard.new()
	_add("switchboard", swb, _next() + Vector3(0, 0, 0.6), 0.0, Vector3(-1.0, 1.6, -2.8), Vector3(0, 1.2, 0))
	await get_tree().process_frame
	await get_tree().process_frame
	# states after _ready
	for i2: int in 3:
		b2.tear_board()
	wb2.build(0)
	for n: Node in get_tree().get_nodes_in_group(&"buildable_parts"):
		n.call("_set_live", true)
	qb.visible = true
