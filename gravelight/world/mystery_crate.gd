class_name MysteryCrate
extends Interactable
## One Lost Requisition Crate location. Only the spot CrateManager.location_index is "here" (all spots
## during Clearance). Opening cycles weapons for 4.5 s, then offers one for 12 s to the player who paid.
## Herr Tamtam may appear instead: he drums, the crate sinks, the player is refunded, the crate moves.
## Co-op: the host rolls; every peer plays the opening (cycle, result, drummer) from Net.mirror calls. The result
## is offered only to the player who paid (WEAPONS.md §10); the crate's spot comes from the host.
## Local -Z faces the player; origin = floor center.

enum Phase { HIDDEN, CLOSED, CYCLING, OFFERED, DRUMMER }

const CrateArt: GDScript = preload("res://gravelight/world/crate_art.gd")

@export var spot_index: int = 0
@export var can_start: bool = false
@export var spot_name: String = ""
## Herr Tamtam's escape route from this spot (world points) when the Requiem quest wants a chase.
@export var drummer_route: PackedVector3Array = []

var phase: Phase = Phase.HIDDEN
var _owner_player: int = 0
var _result: StringName = &""
var _t: float = 0.0
var _swap_t: float = 0.0
var _body: Node3D
var _lid: Node3D
var _glow: OmniLight3D
var _float: Node3D
var _float_label: Label3D
var _float_mesh: MeshInstance3D
var _drummer: Node3D
var _beam: MeshInstance3D
var _beam_t: float = 0.0
var _blocker: StaticBody3D
var _names: PackedStringArray = []
var _ids: PackedStringArray = []
var _float_model: Node3D
var _sticks: Array[Node3D] = []
var _lamp: OmniLight3D
var _lamp_glass: MeshInstance3D
var _motes: CPUParticles3D
var _lamp_t: float = 0.0
static var _ghost_mat: StandardMaterial3D


func _ready() -> void:
	interact_size = Vector3(1.6, 1.1, 0.3)
	interact_offset = Vector3(0, 0.55, -0.45)
	super._ready()
	add_to_group(&"crate_spots")
	for e: Dictionary in GLData.table("crate")["pool"]:
		var id: String = str(e["id"])
		var weps: Dictionary = GLData.table("weapons")
		_names.append(str(weps["weapons"].get(id, weps["tactical"].get(id, {})).get("name", id)))
		_ids.append(id)
	_blocker = StaticBody3D.new()
	_blocker.collision_layer = 1 << 8
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(1.4, 0.75, 0.7)
	cs.shape = box
	cs.position = Vector3(0, 0.375, 0)
	_blocker.add_child(cs)
	add_child(_blocker)
	GLBus.crate_moved.connect(_on_crate_moved)
	refresh()


func _on_crate_moved(index: int) -> void:
	refresh()
	if Net.is_client() and index == spot_index:
		show_beam()   # the host shows its own beam where the drummer took the crate


## The crate's art (CrateArt): the planked, strapped body with its seal and stencils, the lid on its rear hinges,
## and, at every spot, the lantern stake and chalk footprint. The lantern burns only where the crate is.
func build_greybox() -> void:
	# always there: the chalk footprint and the lantern on its stake (the glass and light switch with the crate)
	InteractableArt.place(self, "crate_spot", func(r: Node3D) -> void: CrateArt.spot(r))
	var lp: Vector3 = CrateArt.lantern_pos()
	_lamp_glass = MeshInstance3D.new()
	var gm: CylinderMesh = CylinderMesh.new()
	gm.top_radius = 0.042
	gm.bottom_radius = 0.046
	gm.height = 0.19
	gm.radial_segments = 12
	_lamp_glass.mesh = gm
	_lamp_glass.position = lp
	_lamp_glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_lamp_glass)
	_lamp = OmniLight3D.new()
	_lamp.light_color = Color(1.0, 0.72, 0.42)
	_lamp.light_energy = 1.1
	_lamp.omni_range = 3.2
	_lamp.omni_attenuation = 1.4
	_lamp.shadow_enabled = false
	_lamp.position = lp
	add_child(_lamp)
	_body = Node3D.new()
	add_child(_body)
	InteractableArt.place(_body, "crate_body", func(r: Node3D) -> void: CrateArt.body(r))
	# stencilled requisition markings (invented): the lot number on the front, the works on the plate
	var st: Label3D = add_label(_body, "LOS 44-117", Vector3(0, 0.2, -0.395), 24, Color(0.86, 0.84, 0.72, 0.85))
	st.outline_size = 0
	var st2: Label3D = add_label(_body, "NICHT KIPPEN  ·  INHALT UNBEKANNT", Vector3(0.0, 0.1, -0.395), 11, Color(0.86, 0.84, 0.72, 0.7))
	st2.outline_size = 0
	st2.pixel_size = 0.0025
	var pl: Label3D = add_label(_body, "HELVETIA AUTOMATEN AG", Vector3(-0.41, 0.395, -0.405), 12, Color(0.12, 0.09, 0.03, 0.95))
	pl.outline_size = 0
	pl.pixel_size = 0.0022
	_lid = Node3D.new()
	_lid.position = Vector3(0, CrateArt.TOP + 0.1, CrateArt.HD)   # the hinge pins: the lid's top rear edge
	_body.add_child(_lid)
	InteractableArt.place(_lid, "crate_lid", func(r: Node3D) -> void: CrateArt.lid(r))
	var lt: Label3D = add_label(_lid, "AUSGABE  ·  H.A. AG", Vector3(0, 0.009, -0.38), 12, Color(0.12, 0.09, 0.03, 0.95))
	lt.outline_size = 0
	lt.pixel_size = 0.0025
	lt.rotation_degrees = Vector3(-90, 180, 0)   # reads from above, the top of the text toward the hinge
	# inside: straw packing and the violet glow of whatever is in there
	var inner: Node3D = Node3D.new()
	_body.add_child(inner)
	var inner_builder: Callable = func(r: Node3D) -> void:
		Props.block(r, Vector3(-0.64, 0.11, -0.3), Vector3(0.64, 0.3, 0.3), "hay")
		Props.block(r, Vector3(-0.5, 0.3, -0.2), Vector3(0.5, 0.33, 0.2), "nachtglas_dim")
		Props.block(r, Vector3(-0.2, 0.33, -0.08), Vector3(0.2, 0.35, 0.08), "nachtglas")
	InteractableArt.place(inner, "crate_inner", inner_builder, Vector3.ZERO, false)
	_glow = OmniLight3D.new()
	_glow.light_color = Color(0.65, 0.35, 1.0)
	_glow.omni_range = 5.0
	_glow.light_energy = 0.0
	_glow.position = Vector3(0, 0.9, 0)
	_body.add_child(_glow)
	_motes = CPUParticles3D.new()
	_motes.amount = 22
	_motes.lifetime = 2.6
	_motes.emitting = false
	_motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_motes.emission_box_extents = Vector3(0.5, 0.04, 0.22)
	_motes.direction = Vector3.UP
	_motes.spread = 25.0
	_motes.gravity = Vector3(0, 0.06, 0)
	_motes.initial_velocity_min = 0.12
	_motes.initial_velocity_max = 0.3
	_motes.scale_amount_min = 0.35
	_motes.scale_amount_max = 1.0
	_motes.position = Vector3(0, 0.36, 0)
	var mq: QuadMesh = QuadMesh.new()
	mq.size = Vector2(0.018, 0.018)
	_motes.mesh = mq
	var mm: StandardMaterial3D = StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.albedo_color = Color(0.8, 0.55, 1.0, 0.55)
	mm.emission_enabled = true
	mm.emission = Color(0.7, 0.4, 1.0)
	mm.emission_energy_multiplier = 2.5
	mm.vertex_color_use_as_albedo = true
	var ramp: Gradient = Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	_motes.color_ramp = ramp
	_motes.mesh.surface_set_material(0, mm)
	_body.add_child(_motes)
	_float = Node3D.new()
	_float.position = Vector3(0, 0.8, 0)
	_body.add_child(_float)
	_float_mesh = add_box(_float, Vector3(0.01, 0.01, 0.01), Vector3.ZERO, greybox_mat(Color(0.75, 0.6, 1.0), 3.0))
	_float_mesh.hide()
	_float_label = add_label(_float, "", Vector3(0, 0.3, 0), 32, Color(0.95, 0.9, 1.0))
	_float_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_float.hide()
	_drummer = Node3D.new()
	_drummer.position = Vector3(0, 0.62, 0)
	_body.add_child(_drummer)
	_build_drummer(_drummer)
	_drummer.hide()
	_beam = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.35
	cyl.bottom_radius = 0.35
	cyl.height = 30.0
	_beam.mesh = cyl
	var bm: StandardMaterial3D = greybox_mat(Color(0.6, 0.3, 1.0), 4.0)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.albedo_color.a = 0.35
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam.material_override = bm
	_beam.position = Vector3(0, 15.0, 0)
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beam)
	_beam.hide()


## Shows/hides this spot based on where the crate is (and Clearance).
func refresh() -> void:
	var here: bool = CrateManager.location_index == spot_index or GameState.has_flag(&"clearance")
	if phase == Phase.CYCLING or phase == Phase.OFFERED or phase == Phase.DRUMMER:
		return
	phase = Phase.CLOSED if here else Phase.HIDDEN
	if _body != null:
		_body.visible = here
		_body.position.y = 0.0
		_set_lantern(here)
	_blocker.collision_layer = (1 << 8) if here else 0
	area.collision_layer = LAYER_INTERACTABLE if here else 0


## The lantern burns where the crate is: lit glass and its light, a cold lamp at the other spots.
func _set_lantern(lit: bool) -> void:
	if _lamp == null:
		return
	_lamp.visible = lit
	_lamp_glass.material_override = Mats.get_mat("lantern_glass" if lit else "neon_off")


func _process(delta: float) -> void:
	if _lamp != null and _lamp.visible:
		# a hurricane lamp's slow breathing, not a strobe
		_lamp_t += delta
		_lamp.light_energy = 1.1 + 0.1 * sin(_lamp_t * 5.3) + 0.06 * sin(_lamp_t * 13.7)
	if _beam_t > 0.0:
		_beam_t -= delta
		_beam.visible = _beam_t > 0.0
	var clearance_here: bool = GameState.has_flag(&"clearance")
	if phase == Phase.HIDDEN and clearance_here:
		refresh()
	elif phase == Phase.CLOSED and not clearance_here and CrateManager.location_index != spot_index:
		refresh()
	match phase:
		Phase.CYCLING:
			_t += delta
			_swap_t -= delta
			var cyc: float = float(GLData.table("crate")["cycle_seconds"])
			var u: float = clampf(_t / cyc, 0.0, 1.0)
			# rises out of the straw and slows its spin as the crate makes up its mind
			_float.position.y = lerpf(0.6, 1.1, 1.0 - (1.0 - u) * (1.0 - u)) + sin(_t * 3.0) * 0.012
			_float.rotation.y += delta * lerpf(5.0, 1.2, u)
			if _swap_t <= 0.0:
				_swap_t = lerpf(0.06, 0.4, clampf(_t / cyc, 0.0, 1.0))
				var k: int = randi() % _ids.size()
				_float_label.text = ""
				_show_model(StringName(_ids[k]), true)
				AudioDirector.play_3d("scrip_tick", global_position + Vector3.UP, -10.0, 0.2)
			if _t >= cyc:
				_finish_cycle()
		Phase.OFFERED:
			_t += delta
			_float.rotation.y += delta * 1.2
			_float.position.y = 1.1 + sin(_t * 2.2) * 0.02
			# a client waits for the host's close (a little longer, in case that message is late)
			if _t >= float(GLData.table("crate")["pickup_window_seconds"]) + (2.0 if Net.is_client() else 0.0):
				_close()
		Phase.DRUMMER:
			_t += delta
			_drummer.position.y = 0.62 + absf(sin(_t * 9.0)) * 0.03
			# tam-tam, ta-ta-tam: alternate the sticks
			for si: int in _sticks.size():
				_sticks[si].rotation.x = -0.6 + absf(sin(_t * 9.0 + si * PI * 0.5)) * 0.9
			# (the drum roll is AudioDirector's crate_drummer, from GLBus.crate_drummer)
			if _t > 2.4:
				_body.position.y = -(_t - 2.4) * 1.2
			if _t > 3.6:
				_drummer.hide()
				_float.hide()
				phase = Phase.HIDDEN
				_lid.rotation.x = 0.0
				_glow.light_energy = 0.0
				_motes.emitting = false
				if Net.is_client():
					refresh()
					return   # the host moves the crate (relayed crate_moved)
				var count: int = get_tree().get_nodes_in_group(&"crate_spots").size()
				CrateManager.move(count)
				for n: Node in get_tree().get_nodes_in_group(&"crate_spots"):
					(n as MysteryCrate).refresh()
					if (n as MysteryCrate).spot_index == CrateManager.location_index:
						(n as MysteryCrate).show_beam()


func show_beam() -> void:
	_beam_t = float(GLData.table("crate")["move_beam_seconds"])
	_beam.show()


func get_prompt(player: Player) -> String:
	match phase:
		Phase.CLOSED:
			return "Hold [%s] to open the Requisition Crate [%d]" % [prompt_key(&"interact"), CrateManager.cost()]
		Phase.OFFERED:
			if player.player_id != _owner_player:
				return ""
			return "Hold [%s] to take %s" % [prompt_key(&"interact"), _float_label.text]
	return ""


func can_interact(_player: Player) -> bool:
	return phase == Phase.CLOSED or phase == Phase.OFFERED


func interact(player: Player) -> void:
	if phase == Phase.CLOSED:
		var price: int = CrateManager.cost()
		if not try_purchase(player, &"crate", price):
			return
		_owner_player = player.player_id
		GLBus.crate_opened.emit(player.player_id)
		var held: Array = []
		for w: WeaponInstance in player.weapons.slots:
			held.append(w.id)
		var res: Dictionary = CrateManager.roll(player.player_id, held)
		_result = StringName(res["id"])
		_paid = price
		_net_open(_owner_player, String(_result))
		Net.mirror(self, &"_net_open", [_owner_player, String(_result)])
		if _result == CrateManager.DRUMMER:
			_start_drummer()
	elif phase == Phase.OFFERED and player.player_id == _owner_player:
		_give(player)


## The lid opens and the cycle (or the drummer) starts: on the host from interact(), on clients from the host.
func _net_open(owner_pid: int, result: String) -> void:
	_owner_player = owner_pid
	_result = StringName(result)
	_open_lid()
	if _result == CrateManager.DRUMMER:
		_drummer_visual()
	else:
		phase = Phase.CYCLING
		_t = 0.0
		_swap_t = 0.0
		_float.show()


var _paid: int = 0


func _open_lid() -> void:
	# the lid swings up to just short of vertical (crates stand against walls: nothing may pass the hinge line)
	var tw: Tween = create_tween()
	tw.tween_property(_lid, "rotation:x", 1.52, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_glow.light_energy = 2.5
	_motes.emitting = true
	AudioDirector.play_3d("crate_open", global_position + Vector3.UP * 0.6, 0.0, 0.0)


func _finish_cycle() -> void:
	phase = Phase.OFFERED
	_t = 0.0
	var weps: Dictionary = GLData.table("weapons")
	var row: Dictionary = weps["weapons"].get(String(_result), weps["tactical"].get(String(_result), {}))
	_float_label.text = str(row.get("name", _result))
	_show_model(_result, false)
	var tier: String = ""
	for e: Dictionary in GLData.table("crate")["pool"]:
		if StringName(e["id"]) == _result:
			tier = str(e["tier"])
	var quality: StringName = &"good" if tier == "A" or tier == "B" else &"bad"
	if _result == &"ashlight":
		quality = &"wonder"
	if Net.is_authority():
		GLBus.crate_result.emit(_owner_player, _result, quality)   # relayed to the clients
	AudioDirector.play_3d("buy", global_position + Vector3.UP, -2.0)


func _give(player: Player) -> void:
	if GLData.table("weapons")["tactical"].has(String(_result)):
		player.weapons.give_tactical(_result)
	else:
		player.weapons.give_weapon(_result)
	GLBus.weapon_acquired.emit(player.player_id, _result, &"crate")
	_close()


func _close() -> void:
	if phase == Phase.OFFERED or phase == Phase.CYCLING:
		Net.mirror(self, &"_close")
	_float.hide()
	_glow.light_energy = 0.0
	_motes.emitting = false
	var tw: Tween = create_tween()
	tw.tween_property(_lid, "rotation:x", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	phase = Phase.CLOSED
	refresh()


func _start_drummer() -> void:
	Economy.grant(_owner_player, _paid)   # refund (no Double Scrip)
	GLBus.crate_drummer.emit(spot_index)
	_maybe_start_chase()


func _drummer_visual() -> void:
	phase = Phase.DRUMMER
	_t = 0.0
	_drummer.show()


## Requiem step 7: instead of vanishing, Herr Tamtam hops out and marches off along this spot's route.
func _maybe_start_chase() -> void:
	var armed: Array = QuestManager.is_chase_armed(&"drummer")
	if armed.is_empty():
		return
	var p: Dictionary = QuestManager.step_def(armed[0], armed[1]).get("params", {})
	var walker: QuestDrummer = QuestDrummer.new()
	var route: PackedVector3Array = drummer_route.duplicate()
	if route.is_empty():
		route = PackedVector3Array([global_position, global_position + global_basis.x * 8.0])
	walker.route = route
	walker.seconds = float(p.get("seconds", 20.0)) * (float(p.get("solo_mult", 1.2)) if GameState.is_solo() else 1.0)
	get_parent().add_child(walker)
	if Net.replicating():
		Net.session.spawn_dynamic(walker, "res://gravelight/world/quest_drummer.gd", {"route": walker.route, "seconds": walker.seconds})


## Floating weapon: a real model, ghostly violet while the crate is still deciding.
func _show_model(id: StringName, ghost: bool) -> void:
	if _float_model != null and is_instance_valid(_float_model):
		_float_model.queue_free()
	var model: Node3D = WeaponModels.build(id)
	var bb: AABB = WeaponModels.model_bounds(model)
	var length: float = maxf(0.2, bb.size.z)
	var holder: Node3D = Node3D.new()
	var k: float = clampf(0.95 / length, 0.6, 2.2)
	holder.scale = Vector3.ONE * k
	# barrel along -X, the model's bounding box centred on the float (a yaw of 90 maps local (x, z) to (z, -x))
	var c: Vector3 = bb.get_center()
	model.rotation_degrees = Vector3(0, 90, 0)
	model.position = -Vector3(c.z, c.y, -c.x)
	holder.add_child(model)
	if ghost:
		if _ghost_mat == null:
			_ghost_mat = StandardMaterial3D.new()
			_ghost_mat.albedo_color = Color(0.55, 0.3, 1.0, 0.55)
			_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_ghost_mat.emission_enabled = true
			_ghost_mat.emission = Color(0.6, 0.3, 1.0)
			_ghost_mat.emission_energy_multiplier = 2.0
			_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		WeaponModels._set_material_recursive(model, _ghost_mat)
	_float.add_child(holder)
	_float_model = holder


## Herr Tamtam: Liesl's wind-up tin drummer. Painted tin, a drum, two sticks and a key in his back.
func _build_drummer(root: Node3D) -> void:
	var red: StandardMaterial3D = greybox_mat(Color(0.62, 0.08, 0.07))
	red.metallic = 0.5
	red.roughness = 0.35
	var navy: StandardMaterial3D = greybox_mat(Color(0.1, 0.12, 0.3))
	navy.metallic = 0.5
	var white: StandardMaterial3D = greybox_mat(Color(0.9, 0.88, 0.82))
	var gold: StandardMaterial3D = greybox_mat(Color(0.85, 0.65, 0.2), 0.3)
	gold.metallic = 0.9
	var skin: StandardMaterial3D = greybox_mat(Color(0.95, 0.8, 0.68))
	var black: StandardMaterial3D = greybox_mat(Color(0.05, 0.05, 0.06))
	for x: float in [-0.025, 0.025]:
		_cyl(root, 0.018, 0.12, Vector3(x, 0.06, 0), navy)
		add_box(root, Vector3(0.03, 0.02, 0.045), Vector3(x, 0.006, -0.008), black)
	_cyl(root, 0.045, 0.12, Vector3(0, 0.18, 0), red)                 # coat
	add_box(root, Vector3(0.095, 0.012, 0.012), Vector3(0, 0.2, -0.044), white).rotation.z = 0.7
	add_box(root, Vector3(0.095, 0.012, 0.012), Vector3(0, 0.2, -0.044), white).rotation.z = -0.7
	var head: MeshInstance3D = MeshInstance3D.new()
	var hs: SphereMesh = SphereMesh.new()
	hs.radius = 0.035
	hs.height = 0.07
	head.mesh = hs
	head.material_override = skin
	head.position = Vector3(0, 0.27, 0)
	root.add_child(head)
	add_box(root, Vector3(0.008, 0.008, 0.004), Vector3(-0.012, 0.275, -0.034), black)
	add_box(root, Vector3(0.008, 0.008, 0.004), Vector3(0.012, 0.275, -0.034), black)
	_cyl(root, 0.034, 0.07, Vector3(0, 0.33, 0), black)               # shako
	add_box(root, Vector3(0.03, 0.03, 0.004), Vector3(0, 0.33, -0.035), gold)
	_cyl(root, 0.008, 0.04, Vector3(0, 0.385, 0), red)                # plume
	var drum: MeshInstance3D = _cyl(root, 0.05, 0.05, Vector3(0, 0.15, -0.07), white)
	drum.rotation.x = 0.35
	for dy: float in [-0.025, 0.025]:
		var rim: MeshInstance3D = _cyl(root, 0.052, 0.008, Vector3(0, 0.15 + dy * 0.94, -0.07 + dy * 0.34), red)
		rim.rotation.x = 0.35
	_sticks.clear()
	for x: float in [-0.04, 0.04]:
		var arm: Node3D = Node3D.new()
		arm.position = Vector3(x * 1.3, 0.22, -0.02)
		root.add_child(arm)
		add_box(arm, Vector3(0.018, 0.018, 0.07), Vector3(0, -0.02, -0.03), red)
		add_box(arm, Vector3(0.006, 0.006, 0.08), Vector3(-x * 0.2, -0.03, -0.09), gold)
		_sticks.append(arm)
	var key: Node3D = Node3D.new()
	key.position = Vector3(0, 0.19, 0.05)
	root.add_child(key)
	add_box(key, Vector3(0.006, 0.006, 0.03), Vector3(0, 0, 0.01), gold)
	add_box(key, Vector3(0.05, 0.02, 0.004), Vector3(0, 0, 0.028), gold)


func _cyl(parent: Node3D, r: float, h: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi
