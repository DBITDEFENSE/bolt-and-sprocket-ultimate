class_name MysteryCrate
extends Interactable
## One Lost Requisition Crate location. Only the spot CrateManager.location_index is "here" (all spots
## during Clearance). Opening cycles weapons for 4.5 s, then offers one for 12 s to the player who paid.
## Herr Tamtam may appear instead: he drums, the crate sinks, the player is refunded, the crate moves.
## Co-op: the host rolls; every peer plays the opening (cycle, result, drummer) from Net.mirror calls. The result
## is offered only to the player who paid (WEAPONS.md §10); the crate's spot comes from the host.
## Local -Z faces the player; origin = floor center.
##
## T-254 (UPDATE 19, "make the mystery box better"): presentation only; the cost, the odds, the 4.5 s cycle, the 12 s
## window, the 3.6 s drummer scene, the prompts, the blocker and the mirrored calls are as they were.
##   the locator   a column of pale ashlight over the spot the crate is at (CrateFx.beacon): from the crate itself
##                 outdoors, from the roof up when the spot is under one (probed once with rays), so it shows over
##                 walls from across the map and never stands in a room; brighter for move_beam_seconds after a move.
##                 Indoors the lantern's halo, the crate's own breathing light and a quiet hum (crate_hum) lead you in.
##   the roll      the hasp gives, the lid heaves up and settles, light stands out of the box (CrateFx.spill), the
##                 real guns rise out of the straw in that light (their own materials under a violet rim), a ring
##                 runs out and the light flares when it settles (crate_settle), the offer hangs over a bed of light
##                 and sinks back in its last seconds, the lid falls shut with a thud and a puff.
##   the move      Herr Tamtam pops up, drums, the lid slams on him, the floor opens in a pool of light, the crate
##                 rattles and goes down through it (crate_sink) while its lantern gutters out; at the new spot the
##                 pool opens, the crate comes up through it (crate_arrive) and the lantern catches.
##   an empty spot the cold lantern, the chalk footprint, the scrapes of the skids, loose straw and hairline cracks
##                 with Nachtglas still breathing in them: the crate was here and comes here.
##   outside       snow on the lid (it slides off when the lid first opens) and drifted against the spot, on the maps
##                 crate.json "look" lists as snowy.

enum Phase { HIDDEN, CLOSED, CYCLING, OFFERED, DRUMMER }

const CrateArt: GDScript = preload("res://gravelight/world/crate_art.gd")
const CrateFx: GDScript = preload("res://gravelight/world/crate_fx.gd")
const BEACON_H: float = 60.0
const BEACON_IDLE: float = 0.3
const BEACON_FLARE: float = 1.1

@export var spot_index: int = 0
@export var can_start: bool = false
@export var spot_name: String = ""
## Herr Tamtam's escape route from this spot (world points) when the Requiem quest wants a chase.
@export var drummer_route: PackedVector3Array = []
## -1: probe the sky over the spot with rays at load (T-254); 0 / 1: under a roof / under the sky, whatever is there.
@export var outdoors: int = -1

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
var _art: Node3D = null   # the crate model while its parts are handed out (WorldArt "requisition_crate")
# T-254
var _beam_e: float = 0.0            # the locator's energy now
var _halo: MeshInstance3D           # the lantern's glow, seen from afar
var _spill: MeshInstance3D          # the light standing out of the open box
var _ring: MeshInstance3D           # the settle's flourish
var _ring_t: float = -1.0
var _bed: MeshInstance3D            # the bed of light under the offered weapon
var _pool: MeshInstance3D           # the floor under a crate that leaves or arrives
var _pool_k: float = 0.0
var _pool_out: bool = false
var _puff: CPUParticles3D
var _snow_puff: CPUParticles3D
var _away: Node3D                   # what the crate left behind (shown where the crate is not)
var _vein_mat: StandardMaterial3D
var _snow_lid: Node3D
var _snow_base: Node3D
var _under_sky: bool = false
var _open_k: float = 0.0            # 0 shut .. 1 open: the light out of the box
var _flash: float = 0.0
var _idle_t: float = 0.0
var _arrive_t: float = -1.0
var _lid_tw: Tween
var _open_tw: Tween
var _slammed: bool = false
var _sink_snd: bool = false
var _hum: AudioStreamPlayer3D
var _models: Dictionary = {}        # weapon id -> the floating model's holder (this opening)
var _rim: ShaderMaterial
var _seam_mat: StandardMaterial3D   # the light under the lid's edge
var _floor_glow: MeshInstance3D     # the ashlight the crate stands in
var _plate: MeshInstance3D          # the dark card behind the offered weapon's name


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
	_probe_sky()


func _on_crate_moved(index: int) -> void:
	refresh()
	if index == spot_index and phase == Phase.CLOSED and not GameState.has_flag(&"clearance"):
		_arrive()
	if Net.is_client() and index == spot_index:
		show_beam()   # the host shows its own beam where the drummer took the crate


## T-254: is there a roof over this spot? Rays straight up through whatever is solid (the world layer), after the
## map's bodies are in the physics space: the locator starts above the last thing hit, so it never stands in a room
## (not this one, not the one upstairs), and a spot with nothing over it is outdoors (snow, where the map has snow).
func _probe_sky() -> void:
	if not is_inside_tree():
		return
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree() or _beam == null:
		return
	var roof: float = -1.0
	if outdoors != 1:
		var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
		var from: Vector3 = global_position + Vector3.UP * 0.9
		var to: Vector3 = global_position + Vector3.UP * 70.0
		for i: int in 10:
			var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
			q.exclude = [_blocker.get_rid()]
			var hit: Dictionary = space.intersect_ray(q)
			if hit.is_empty():
				break
			roof = (hit["position"] as Vector3).y - global_position.y
			from = (hit["position"] as Vector3) + Vector3.UP * 0.08
			if from.y >= to.y:
				break
	if outdoors == 0 and roof < 0.0:
		roof = 6.0
	set_sky(roof)


## The locator and the weather for a spot whose roof is `roof` metres up (below 0: open sky).
func set_sky(roof: float) -> void:
	_under_sky = roof < 0.0
	var base: float = 0.0 if _under_sky else roof + 0.05
	_beam.position.y = base + BEACON_H * 0.5
	(_beam.material_override as ShaderMaterial).set_shader_parameter("foot", 6.0 if _under_sky else 1.2)
	var snowy: bool = _under_sky and str(_look().get("cover", "")) == "snow"
	if snowy and _snow_base == null:
		InteractableArt.place(_away, "crate_away_bare", func(r: Node3D) -> void: CrateArt.away_bare(r), Vector3.ZERO, false)
		_snow_base = Node3D.new()
		_snow_base.name = "SnowBase"
		add_child(_snow_base)
		InteractableArt.place(_snow_base, "crate_snow_base", func(r: Node3D) -> void: CrateArt.snow_base(r), Vector3.ZERO, false)
		_snow_lid = Node3D.new()
		_snow_lid.name = "SnowLid"
		_lid.add_child(_snow_lid)
		InteractableArt.place(_snow_lid, "crate_snow_lid", func(r: Node3D) -> void: CrateArt.snow_lid(r), Vector3.ZERO, false)
		_snow_puff = CrateFx.puff(Color(0.92, 0.95, 1.0, 0.8), 18, Vector3(0.6, 0.03, 0.28), 0.7)
		_snow_puff.position = Vector3(0, CrateArt.TOP + 0.15, 0)
		_snow_puff.gravity = Vector3(0, -2.2, 0)
		add_child(_snow_puff)
	if _snow_base != null:
		_snow_base.visible = snowy
		_snow_lid.visible = snowy and _lid.rotation.x < 0.05


## crate.json "look": the map's own entry (by its id up to the first underscore) over "default".
func _look() -> Dictionary:
	var look: Dictionary = GLData.table("crate").get("look", {})
	var out: Dictionary = (look.get("default", {}) as Dictionary).duplicate()
	out.merge(look.get(str(GameState.map_id).get_slice("_", 0), {}) as Dictionary, true)
	return out


## The crate's art (CrateArt): the planked, strapped body with its seal and stencils, the lid on its rear hinges,
## and, at every spot, the lantern stake and chalk footprint. The lantern burns only where the crate is.
func build_greybox() -> void:
	# always there: the chalk footprint and the lantern on its stake (the glass and light switch with the crate)
	_art = WorldArt.instance("requisition_crate")   # our model (UPDATE_05 section 5, T-094); CrateArt when absent
	_crate_part(self, "Spot", "crate_spot", func(r: Node3D) -> void: CrateArt.spot(r))
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
	# T-254: the lantern's glow from across a room, and what the crate leaves behind at a spot it is not at
	_halo = CrateFx.halo(0.62, Color(1.0, 0.7, 0.4, 0.5))
	_halo.position = lp
	add_child(_halo)
	_away = Node3D.new()
	_away.name = "Away"
	add_child(_away)
	InteractableArt.place(_away, "crate_away", func(r: Node3D) -> void: CrateArt.away(r), Vector3.ZERO, false)
	_vein_mat = (Mats.get_mat("nachtglas_vein") as StandardMaterial3D).duplicate() as StandardMaterial3D
	InteractableArt.place(_away, "crate_away_veins", func(r: Node3D) -> void: CrateArt.away_veins(r), Vector3.ZERO, false).material_override = _vein_mat
	_pool = CrateFx.pool(3.0)
	_pool.position = Vector3(0, 0.02, 0)
	_pool.hide()
	add_child(_pool)
	_body = Node3D.new()
	add_child(_body)
	_crate_part(_body, "Body", "crate_body", func(r: Node3D) -> void: CrateArt.body(r))
	# the lot number stencilled on the front (invented; T-247: the small print and the maker's plate are gone)
	add_label(_body, "LOS 44-117", Vector3(0, 0.2, -0.395), 22, Color(0.8, 0.78, 0.68, 0.6))
	_lid = Node3D.new()
	_lid.position = Vector3(0, CrateArt.TOP + 0.1, CrateArt.HD)   # the hinge pins: the lid's top rear edge
	_body.add_child(_lid)
	_crate_part(_lid, "Lid", "crate_lid", func(r: Node3D) -> void: CrateArt.lid(r))
	# the unit's own word for what is in it, stencilled across the lid ("returned goods"; invented, no maker)
	var lid_text: Label3D = add_label(_lid, "RÜCKGUT", Vector3(0.0, -0.006, -0.13), 20, Color(0.78, 0.76, 0.66, 0.5))
	lid_text.basis = Basis(Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0))
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
	_spill = CrateFx.spill(Vector2(0.6, 0.27), CrateArt.TOP - 0.2, 1.7)
	_spill.hide()
	_body.add_child(_spill)
	_ring = CrateFx.ring(2.8)
	_ring.position = Vector3(0, 1.0, 0)
	_ring.hide()
	_body.add_child(_ring)
	_bed = CrateFx.halo(1.5, Color(0.7, 0.45, 1.0, 0.0), true)
	_bed.position = Vector3(0, 0.63, 0)
	_bed.hide()
	_body.add_child(_bed)
	_puff = CrateFx.puff(Color(0.7, 0.66, 0.6, 0.5), 12, Vector3(0.66, 0.02, 0.05), 0.45)
	_puff.position = Vector3(0, CrateArt.TOP, -CrateArt.HD)
	_body.add_child(_puff)
	_rim = CrateFx.rim_mat()
	# shut, it is still not a dead box: light under the lid's edge, and a pool of it on the floor round the skids
	_seam_mat = StandardMaterial3D.new()
	_seam_mat.albedo_color = Color(0.1, 0.04, 0.16)
	_seam_mat.emission_enabled = true
	_seam_mat.emission = Color(0.66, 0.36, 1.0)
	_seam_mat.emission_energy_multiplier = 1.6
	var seam_y: float = CrateArt.TOP - 0.004
	for seam: Array in [[Vector3(0, seam_y, -CrateArt.HD - 0.012), Vector3(2.0 * CrateArt.HW - 0.1, 0.01, 0.016)],
			[Vector3(-CrateArt.HW - 0.012, seam_y, -0.02), Vector3(0.016, 0.01, 2.0 * CrateArt.HD - 0.12)],
			[Vector3(CrateArt.HW + 0.012, seam_y, -0.02), Vector3(0.016, 0.01, 2.0 * CrateArt.HD - 0.12)]]:
		add_box(_body, seam[1], seam[0], _seam_mat).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_floor_glow = CrateFx.halo(2.7, Color(0.62, 0.34, 1.0, 0.14), true)
	_floor_glow.name = "FloorGlow"
	_floor_glow.position = Vector3(0, 0.026, -0.05)
	_body.add_child(_floor_glow)
	_float = Node3D.new()
	_float.position = Vector3(0, 0.8, 0)
	_body.add_child(_float)
	_float_mesh = add_box(_float, Vector3(0.01, 0.01, 0.01), Vector3.ZERO, greybox_mat(Color(0.75, 0.6, 1.0), 3.0))
	_float_mesh.hide()
	_float_label = add_label(_float, "", Vector3(0, 0.3, 0), 28, Color(0.95, 0.9, 1.0), SurfaceText.FLOAT)
	_float_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_float_label.render_priority = 2
	_plate = CrateFx.name_plate()   # T-254: the name reads against a lit wall
	_plate.position = Vector3(0, 0.3, 0)
	_plate.hide()
	_float.add_child(_plate)
	_float.hide()
	_drummer = Node3D.new()
	_drummer.position = Vector3(0, 0.62, 0)
	_body.add_child(_drummer)
	_build_drummer(_drummer)
	_drummer.hide()
	# the locator (T-254): where it stands and how it fades in is set once the sky over the spot is known (set_sky)
	_beam = CrateFx.beacon(BEACON_H)
	add_child(_beam)
	_beam.hide()


## One part of the crate model in its place under `parent` (the parts' pivots are the frames MysteryCrate already
## uses: the origin for the spot and the body, the hinge pins for the lid), or CrateArt's procedural mesh.
func _crate_part(parent: Node3D, part_name: String, key: String, builder: Callable) -> void:
	var p: Node3D = WorldArt.detach(_art, part_name, parent) if _art != null else null
	if p == null:
		InteractableArt.place(parent, key, builder)
		return
	p.transform = Transform3D.IDENTITY
	var mi: MeshInstance3D = WorldArt.mesh_of(p)
	if mi != null and mi.mesh != null:
		for si: int in mi.mesh.get_surface_count():
			var m: Material = mi.mesh.surface_get_material(si)
			if m != null and m.resource_name == "chalk":
				mi.set_surface_override_material(si, CrateArt.chalk_mat())
	if part_name == "Lid":
		_art.free()   # the last part handed out
		_art = null


## Shows/hides this spot based on where the crate is (and Clearance).
func refresh() -> void:
	var here: bool = CrateManager.location_index == spot_index or GameState.has_flag(&"clearance")
	if phase == Phase.CYCLING or phase == Phase.OFFERED or phase == Phase.DRUMMER:
		return
	phase = Phase.CLOSED if here else Phase.HIDDEN
	if _body != null:
		_body.visible = here
		_body.position.y = 0.0
		_body.rotation.z = 0.0
		_set_lantern(here)
		_away.visible = not here
		_set_hum(here)
	_blocker.collision_layer = (1 | (1 << 8)) if here else 0   # T-125: world too (shots, zombies): the baked footprint is off at runtime
	area.collision_layer = LAYER_INTERACTABLE if here else 0


## The lantern burns where the crate is: lit glass and its light, a cold lamp at the other spots.
func _set_lantern(lit: bool) -> void:
	if _lamp == null:
		return
	_lamp.visible = lit
	_halo.visible = lit
	_lamp_glass.material_override = Mats.get_mat("lantern_glass" if lit else "neon_off")


## The crate's own quiet hum where it stands (crate_hum: you hear it a room away, not across the map).
func _set_hum(on: bool) -> void:
	if on and _hum == null and is_inside_tree() and AudioDirector.has_sound("crate_hum"):
		_hum = AudioDirector.make_loop_3d("crate_hum", self, -4.0)
		if _hum != null:
			_hum.position = Vector3(0, 0.4, 0)
			_hum.unit_size = 1.6
			_hum.max_distance = 11.0
	if _hum != null and _hum.playing != on:
		if on:
			_hum.play()
		else:
			_hum.stop()


func _process(delta: float) -> void:
	if _lamp != null and _lamp.visible:
		# a hurricane lamp's slow breathing, not a strobe; it gutters as the crate goes down and catches as it arrives
		_lamp_t += delta
		var live: float = 1.0
		if phase == Phase.DRUMMER and _t > 2.4:
			live = clampf(1.0 - (_t - 2.4) / 1.1, 0.0, 1.0) * (0.6 + 0.4 * sin(_lamp_t * 31.0))
		elif _arrive_t >= 0.0:
			live = clampf(_arrive_t / 0.9, 0.0, 1.0)
		_lamp.light_energy = (1.1 + 0.1 * sin(_lamp_t * 5.3) + 0.06 * sin(_lamp_t * 13.7)) * live
		(_halo.material_override as StandardMaterial3D).albedo_color.a = 0.5 * live
	_fx_process(delta)
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
			_float.position.y = lerpf(0.46, 1.1, 1.0 - (1.0 - u) * (1.0 - u)) + sin(_t * 3.0) * 0.012
			_float.rotation.y += delta * lerpf(5.0, 1.2, u)
			if _swap_t <= 0.0:
				_swap_t = lerpf(0.06, 0.4, clampf(_t / cyc, 0.0, 1.0))
				var k: int = randi() % _ids.size()
				_float_label.text = ""
				_plate.hide()
				_show_model(StringName(_ids[k]), true)
				AudioDirector.play_3d("scrip_tick", global_position + Vector3.UP, -10.0, 0.2)
			if _t >= cyc:
				_finish_cycle()
		Phase.OFFERED:
			_t += delta
			_float.rotation.y += delta * 1.2
			# it hangs there, then sinks back toward the box over its last seconds and gutters at the very end
			var window: float = float(GLData.table("crate")["pickup_window_seconds"])
			var sink: float = clampf(1.0 - (window - _t) / 4.0, 0.0, 1.0)
			_float.position.y = lerpf(1.1, 0.74, sink * sink) + sin(_t * 2.2) * 0.02
			if _float_model != null and is_instance_valid(_float_model):
				_float_model.visible = window - _t > 1.5 or fmod(_t, 0.26) < 0.17
			(_bed.material_override as StandardMaterial3D).albedo_color.a = (0.5 + 0.12 * sin(_t * 3.1)) * (1.0 - 0.6 * sink)
			# a client waits for the host's close (a little longer, in case that message is late)
			if _t >= window + (2.0 if Net.is_client() else 0.0):
				_close()
		Phase.DRUMMER:
			_t += delta
			# he pops up out of the straw
			var up: float = clampf(_t / 0.28, 0.0, 1.0)
			_drummer.position.y = lerpf(0.34, 0.62, 1.0 - (1.0 - up) * (1.0 - up)) + absf(sin(_t * 9.0)) * 0.03
			_drummer.rotation.y = sin(_t * 2.6) * 0.5
			# the floor opens under the crate, the lid slams on him, the crate rattles on its skids
			_pool.visible = _t > 1.3
			_pool_k = smoothstep(1.3, 2.3, _t) * 0.86
			if _t > 2.0 and not _slammed:
				_slammed = true
				_drop_lid(0.16, true)
			if _t > 2.05:
				_body.rotation.z = sin(_t * 53.0) * 0.022 * clampf((_t - 2.05) * 4.0, 0.0, 1.0)
			if _t > 2.3 and not _sink_snd:
				_sink_snd = true
				AudioDirector.play_3d("crate_sink", global_position + Vector3.UP * 0.3, 0.0, 0.0)
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
				if _lid_tw != null:
					_lid_tw.kill()
				_lid.rotation.x = 0.0
				_body.rotation.z = 0.0
				_open_k = 0.0
				_glow.light_energy = 0.0
				_spill.hide()
				_motes.emitting = false
				_pool_out = true   # the pool closes over it (_fx_process)
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


## T-254: the light the crate makes, every frame: the locator (on where the crate is, brighter after a move, out as
## it sinks), the light out of the open box, the settle's ring, the pool under a crate that leaves or arrives, the
## cracks of an empty spot, the crate coming up through the floor.
func _fx_process(delta: float) -> void:
	if _beam == null:
		return
	_idle_t += delta
	_beam_t = maxf(0.0, _beam_t - delta)
	var here: bool = phase != Phase.HIDDEN
	var want: float = 0.0
	if here:
		want = BEACON_FLARE if _beam_t > 0.0 else BEACON_IDLE
		if phase == Phase.DRUMMER and _t > 2.4:
			want = 0.0
	_beam_e = move_toward(_beam_e, want, delta * (1.2 if want > _beam_e else 0.8))
	_beam.visible = _beam_e > 0.004
	if _beam.visible:
		(_beam.material_override as ShaderMaterial).set_shader_parameter("energy", _beam_e)
	_flash = maxf(0.0, _flash - delta * 2.2)
	if here:
		# shut, a little violet leaks through the planks and breathes; open, the light stands out of the box
		var breathe: float = 0.2 + 0.09 * sin(_idle_t * 1.7)
		var open_e: float = 2.5 * (1.0 + 0.07 * sin(_idle_t * 9.0) + 0.05 * sin(_idle_t * 23.0))
		_glow.light_energy = lerpf(breathe if phase == Phase.CLOSED else 0.0, open_e, _open_k) + _flash * 3.2
		var pulse: float = 0.5 + 0.5 * sin(_idle_t * 1.7)
		_seam_mat.emission_energy_multiplier = lerpf(0.9 + 1.5 * pulse, 4.0, _open_k) + _flash * 3.0
		(_floor_glow.material_override as StandardMaterial3D).albedo_color.a = lerpf(0.1 + 0.07 * pulse, 0.26, _open_k) + _flash * 0.15
		_spill.visible = _open_k > 0.01
		if _spill.visible:
			(_spill.material_override as ShaderMaterial).set_shader_parameter("energy", 0.55 * _open_k + _flash * 0.5)
	if _ring_t >= 0.0:
		_ring_t += delta / 0.75
		(_ring.material_override as ShaderMaterial).set_shader_parameter("progress", minf(_ring_t, 1.0))
		if _ring_t >= 1.0:
			_ring_t = -1.0
			_ring.hide()
	if _arrive_t >= 0.0:
		# up through the floor: the pool opens, the crate rises with a small overshoot, the pool closes under it
		_arrive_t += delta
		var k: float = clampf((_arrive_t - 0.25) / 0.75, 0.0, 1.0)
		var e: float = 1.0 - pow(1.0 - k, 3.0)
		_body.position.y = -0.95 * (1.0 - e) + 0.05 * sin(k * PI) * (1.0 - k)
		_pool.visible = true
		_pool_k = 0.86 * (smoothstep(0.0, 0.3, _arrive_t) - smoothstep(0.95, 1.45, _arrive_t))
		if _arrive_t >= 1.45:
			_arrive_t = -1.0
			_body.position.y = 0.0
			_pool.hide()
	elif _pool_out:
		_pool_k = move_toward(_pool_k, 0.0, delta * 1.3)
		if _pool_k <= 0.0:
			_pool_out = false
			_pool.hide()
	if _pool.visible:
		(_pool.material_override as ShaderMaterial).set_shader_parameter("radius", _pool_k)
	if _away.visible and _vein_mat != null:
		_vein_mat.emission_energy_multiplier = 1.0 + 0.6 * sin(_idle_t * 0.9 + float(spot_index) * 1.7)


## The crate comes up at this spot (every peer, from the move): the pool, the rise, the knock of the skids.
func _arrive() -> void:
	_arrive_t = 0.0
	_pool_out = false
	_body.position.y = -0.95
	if _snow_lid != null:
		_snow_lid.visible = _snow_base.visible
	AudioDirector.play_3d("crate_arrive", global_position + Vector3.UP * 0.4, 0.0, 0.0)


func get_prompt(player: Player) -> String:
	match phase:
		Phase.CLOSED:
			return "Hold [%s] to open the Requisition Crate [%s]" % [prompt_key(&"interact"), price_str(player, CrateManager.cost())]
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
	# T-254: the hasp gives (a jolt), then the lid heaves up and rocks once against its stays
	if _lid_tw != null:
		_lid_tw.kill()
	_lid_tw = create_tween()
	_lid_tw.tween_property(_lid, "rotation:x", 0.13, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_lid_tw.tween_property(_lid, "rotation:x", 0.05, 0.08)
	_lid_tw.tween_property(_lid, "rotation:x", 1.52, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_lid_tw.tween_property(_lid, "rotation:x", 1.43, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_lid_tw.tween_property(_lid, "rotation:x", 1.52, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if _open_tw != null:
		_open_tw.kill()
	_open_tw = create_tween()
	_open_tw.tween_interval(0.1)
	_open_tw.tween_property(self, "_open_k", 1.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flash = maxf(_flash, 0.35)
	_slammed = false
	_sink_snd = false
	if _snow_lid != null and _snow_lid.visible:
		_snow_lid.hide()   # the snow slides off the lid
		_snow_puff.restart()
		_snow_puff.emitting = true
	_motes.emitting = true
	AudioDirector.play_3d("crate_open", global_position + Vector3.UP * 0.6, 0.0, 0.0)
	AudioDirector.play_3d("crate_spill", global_position + Vector3.UP * 0.8, 0.0, 0.0)


## The lid falls shut in `secs` (a slam when the drummer's scene does it), the light goes back in the box.
func _drop_lid(secs: float, slam: bool = false) -> void:
	if _lid_tw != null:
		_lid_tw.kill()
	_lid_tw = create_tween()
	_lid_tw.tween_property(_lid, "rotation:x", 0.0, secs).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_lid_tw.tween_callback(_lid_shut.bind(slam))
	if _open_tw != null:
		_open_tw.kill()
	_open_tw = create_tween()
	_open_tw.tween_property(self, "_open_k", 0.0, secs)
	_motes.emitting = false
	_bed.hide()


func _lid_shut(slam: bool) -> void:
	if slam:
		_drummer.hide()
		_flash = maxf(_flash, 0.5)
	if _body.visible:
		_puff.restart()
		_puff.emitting = true
		AudioDirector.play_3d("crate_close", global_position + Vector3.UP * 0.6, 2.0 if slam else 0.0)


func _finish_cycle() -> void:
	phase = Phase.OFFERED
	_t = 0.0
	var weps: Dictionary = GLData.table("weapons")
	var row: Dictionary = weps["weapons"].get(String(_result), weps["tactical"].get(String(_result), {}))
	_float_label.text = str(row.get("name", _result))
	CrateFx.fit_plate(_plate, _float_label)
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
	# T-254: the settle: a ring runs out, the light flares, the gun gives a small kick and hangs over a bed of light
	_flash = 1.0
	_ring.show()
	_ring_t = 0.0
	(_ring.material_override as ShaderMaterial).set_shader_parameter("tint", Color(1.0, 0.9, 0.7) if quality == &"wonder" else CrateFx.ASH)
	_bed.show()
	if _float_model != null and is_instance_valid(_float_model):
		var k: Vector3 = _float_model.scale
		var tw: Tween = create_tween()
		tw.tween_property(_float_model, "scale", k * 1.16, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(_float_model, "scale", k, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	AudioDirector.play_3d("crate_settle" if AudioDirector.has_sound("crate_settle") else "buy", global_position + Vector3.UP, -2.0)


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
	_clear_models()
	_drop_lid(0.3)
	phase = Phase.CLOSED
	refresh()


func _start_drummer() -> void:
	Economy.grant_raw(_owner_player, _paid)   # refund (no Double Scrip, no Ledger Lager: it is moved, not earned, T-141)
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


## Floating weapon: the real model in its own materials; while the crate is still deciding it wears a violet rim
## of the box's light (T-254: the old flat violet ghost hid what gun it was). One holder per id for this opening.
func _show_model(id: StringName, ghost: bool) -> void:
	if _float_model != null and is_instance_valid(_float_model):
		_float_model.hide()
	var holder: Node3D = _models.get(id) as Node3D
	if holder == null or not is_instance_valid(holder):
		var model: Node3D = WeaponModels.build(id)
		var bb: AABB = WeaponModels.model_bounds(model)
		var length: float = maxf(0.2, bb.size.z)
		holder = Node3D.new()
		var k: float = clampf(0.95 / length, 0.6, 2.2)
		holder.scale = Vector3.ONE * k
		# barrel along -X, the model's bounding box centred on the float (a yaw of 90 maps local (x, z) to (z, -x))
		var c: Vector3 = bb.get_center()
		model.rotation_degrees = Vector3(0, 90, 0)
		model.position = -Vector3(c.z, c.y, -c.x)
		holder.add_child(model)
		_float.add_child(holder)
		_models[id] = holder
	CrateFx.set_overlay(holder, _rim if ghost else null)
	holder.show()
	_float_model = holder


func _clear_models() -> void:
	for id: Variant in _models:
		var h: Node3D = _models[id] as Node3D
		if h != null and is_instance_valid(h):
			h.queue_free()
	_models.clear()
	_float_model = null


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
