class_name VfxAtmosphere
extends Node3D
## The atmosphere pass (UPDATE 05 section 6, T-095), attached to the map by Effects at match start from
## data/gravelight/vfx.json "atmosphere":
##   near snow  a camera-following box of big slow flakes over whatever the map's Snowfall covers (the near layer of
##              the snow's depth; Snowfall itself draws the mid and far layers), emitting only while the camera is
##              under open sky (a ray straight up every few frames);
##   motes      slow dust motes inside the stable's moonlight shafts (the Landscape's StableMoonLeaks sheets);
##   west fog   a low FogVolume over the west field, where the Landscape's three ground fogs left a gap;
##   flicker    the FlickerLight lamps get their fire kind from their names (data: flicker.fire_names).
## Presentation only; counts scale with GLSettings "vfx_quality" at attach.

var cfg: Dictionary = {}
var map: Node3D = null
var _near: GPUParticles3D = null
var _near_amount: int = 0
var _sky_t: float = 0.0
var _outdoors: bool = false
var _motes: Array[GPUParticles3D] = []
var _fog: FogVolume = null
var _flickers: int = 0


static func attach(map_root: Node3D, atmosphere_cfg: Dictionary) -> VfxAtmosphere:
	var a: VfxAtmosphere = VfxAtmosphere.new()
	a.name = "VfxAtmosphere"
	a.cfg = atmosphere_cfg
	a.map = map_root
	map_root.add_child(a)
	a.build()
	return a


func build() -> void:
	var q: Dictionary = Effects.quality()
	if map.find_child("Snowfall", false, false) != null:
		_build_near_snow(float(q.get("near_snow", 1.0)))
		_build_west_fog()
	_build_motes(float(q.get("motes", 1.0)))
	_tag_flicker()


# ---------------------------------------------------------------- near snow

func _build_near_snow(k: float) -> void:
	var c: Dictionary = cfg.get("near_snow", {})
	_near_amount = maxi(8, int(round(float(c.get("amount", 140)) * k)))
	var box_a: Array = c.get("box", [12.0, 7.0, 12.0])
	var box: Vector3 = Vector3(float(box_a[0]), float(box_a[1]), float(box_a[2]))
	var p: GPUParticles3D = GPUParticles3D.new()
	p.name = "NearSnow"
	p.amount = _near_amount
	p.lifetime = 4.5
	p.preprocess = 4.5
	p.local_coords = false
	p.visibility_aabb = AABB(-box, box * 2.0)
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(box.x * 0.5, box.y * 0.5, box.z * 0.5)
	pm.direction = Vector3(0.25, -1, 0.1)
	pm.spread = 10.0
	var fall: Array = c.get("fall", [0.9, 1.6])
	pm.initial_velocity_min = float(fall[0])
	pm.initial_velocity_max = float(fall[1])
	pm.gravity = Vector3(0.2, -0.4, 0.05)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = float(c.get("drift", 0.9))
	pm.turbulence_noise_scale = 4.0
	pm.scale_min = 0.6
	pm.scale_max = 1.5
	p.process_material = pm
	var q: QuadMesh = QuadMesh.new()
	var flake: float = float(c.get("flake", 0.085))
	q.size = Vector2(flake, flake)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.88, 0.9, 0.96, 0.8)
	m.albedo_texture = Snowfall.flake_texture()
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = 0.2
	m.distance_fade_max_distance = 0.6
	q.material = m
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emitting = false
	add_child(p)
	_near = p


func _process(delta: float) -> void:
	if _near == null:
		return
	var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() != null else null
	if cam == null:
		return
	var ahead: float = float((cfg.get("near_snow", {}) as Dictionary).get("ahead", 2.5))
	var fwd: Vector3 = -cam.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.1 else Vector3.FORWARD
	_near.global_position = cam.global_position + fwd * ahead + Vector3.UP * 1.0
	_sky_t -= delta
	if _sky_t <= 0.0:
		_sky_t = 0.25
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position + Vector3.UP * 14.0, 1)
		var res: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
		var open: bool = res.is_empty()
		if open != _outdoors:
			_outdoors = open
			_near.emitting = open


func near_snow_emitting() -> bool:
	return _near != null and _near.emitting


# ---------------------------------------------------------------- dust motes in the light shafts

func _build_motes(k: float) -> void:
	var leaks: Node = map.find_child("StableMoonLeaks", true, false)
	if leaks == null:
		return
	var c: Dictionary = cfg.get("motes", {})
	var per: int = maxi(4, int(round(float(c.get("per_beam", 18)) * k)))
	var col_a: Array = c.get("color", [0.75, 0.8, 1.0, 0.55])
	var col: Color = Color(float(col_a[0]), float(col_a[1]), float(col_a[2]), float(col_a[3]))
	var q: QuadMesh = QuadMesh.new()
	var fl: float = float(c.get("flake", 0.012))
	q.size = Vector2(fl, fl)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = col
	m.albedo_texture = Snowfall.flake_texture()
	q.material = m
	var seen: int = 0
	for n: Node in leaks.get_children():
		var sheet: MeshInstance3D = n as MeshInstance3D
		if sheet == null or not (sheet.mesh is QuadMesh):
			continue
		seen += 1
		if seen % 2 == 0:
			continue   # one emitter per slit (each slit has two crossed sheets)
		var size: Vector2 = (sheet.mesh as QuadMesh).size
		var p: GPUParticles3D = GPUParticles3D.new()
		p.name = "BeamMotes"
		p.amount = per
		p.lifetime = 8.0
		p.preprocess = 8.0
		p.local_coords = true
		p.visibility_aabb = AABB(Vector3(-size.x, -size.y, -1.0), Vector3(size.x * 2.0, size.y * 2.0, 2.0))
		var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(size.x * 0.5, size.y * 0.5, 0.25)
		pm.direction = Vector3(0, 1, 0)
		pm.spread = 180.0
		pm.initial_velocity_min = 0.01
		pm.initial_velocity_max = 0.05
		pm.gravity = Vector3(0, -0.004, 0)
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 0.25
		pm.turbulence_noise_scale = 2.0
		pm.scale_min = 0.5
		pm.scale_max = 1.3
		p.process_material = pm
		p.draw_pass_1 = q
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sheet.add_child(p)
		_motes.append(p)


func mote_count() -> int:
	return _motes.size()


# ---------------------------------------------------------------- the west field fog

func _build_west_fog() -> void:
	var c: Dictionary = cfg.get("west_fog", {})
	if c.is_empty():
		return
	var pos_a: Array = c.get("position", [-10.0, 1.0, 20.0])
	var size_a: Array = c.get("size", [22.0, 2.4, 90.0])
	var fv: FogVolume = FogVolume.new()
	fv.name = "WestGroundFog"
	fv.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	fv.size = Vector3(float(size_a[0]), float(size_a[1]), float(size_a[2]))
	fv.position = Vector3(float(pos_a[0]), float(pos_a[1]), float(pos_a[2]))
	var fm: FogMaterial = FogMaterial.new()
	fm.density = float(c.get("density", 0.045))
	fm.albedo = Color(0.8, 0.84, 0.92)
	fm.height_falloff = 0.7
	fm.edge_fade = 0.4
	fv.material = fm
	add_child(fv)
	_fog = fv


func has_west_fog() -> bool:
	return _fog != null


# ---------------------------------------------------------------- firelight flicker

## Every FlickerLight on the map learns its kind from its name (the hearth, the wreck, candles burn fast and deep;
## lanterns breathe slowly) and the gutter settings; counts them for the smoke.
func _tag_flicker() -> void:
	var c: Dictionary = cfg.get("flicker", {})
	var fire_names: Array = c.get("fire_names", ["hearth", "wreck", "candle", "fire"])
	for n: Node in map.find_children("*", "OmniLight3D", true, false):
		var fl: FlickerLight = n as FlickerLight
		if fl == null:
			continue
		var nm: String = String(fl.name).to_lower()
		var is_fire: bool = false
		for f: Variant in fire_names:
			if nm.contains(str(f)):
				is_fire = true
				break
		fl.configure(is_fire, float(c.get("fire_speed_mult", 1.7)), float(c.get("fire_amount_mult", 1.25)),
			float(c.get("gutter_threshold", 0.74)), float(c.get("gutter_depth", 0.55)))
		_flickers += 1


func flicker_count() -> int:
	return _flickers
