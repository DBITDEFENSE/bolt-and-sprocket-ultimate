extends Node3D
## Pooled, cheap greybox VFX: bullet impacts, blood puffs, tracers, explosions, Overclock static bursts.
## Presentation only.
##
## Update 02 section 8 (T-053): bullet holes in the static world persist for the match (one MultiMesh per surface
## kind, HOLES_PER_SURFACE each; when a kind is full its oldest hole is reused, so the cost is capped), except in
## snow, where they fill in after a few seconds. Holes in things that move or vanish (doors, seals, machines) stay
## short-lived quads, so nothing floats in the air when a door rises. Real explosions leave a scorch mark (a
## pooled Decal, SCORCHES of them, oldest reused). Both are wiped when a match starts.

const IMPACTS: int = 48
const BLOOD: int = 16
const TRACERS: int = 12
const BLASTS: int = 4
const STATICS: int = 4
const STATIC_LIFE: float = 0.42
const STATIC_TEAL: Color = Color(0.25, 0.85, 0.8)
const STATIC_VIOLET: Color = Color(0.72, 0.42, 1.0)
const HOLES_PER_SURFACE: int = 96
const SNOW_HOLE_LIFE: float = 6.0
const SCORCHES: int = 16
const SCORCH_MIN_RADIUS: float = 1.2

## Bullet-hole decals per surface (Update 02 §1): hole and rim colors, size (m), rim width, how ragged.
const DECALS: Dictionary = {
	"wood": {"hole": Color(0.07, 0.045, 0.03, 0.95), "rim": Color(0.62, 0.46, 0.3, 0.9), "size": 0.075, "rim_w": 0.32, "rag": 0.55},
	"stone": {"hole": Color(0.09, 0.09, 0.09, 0.9), "rim": Color(0.66, 0.64, 0.6, 0.8), "size": 0.09, "rim_w": 0.45, "rag": 0.35},
	"snow": {"hole": Color(0.42, 0.47, 0.56, 0.55), "rim": Color(0.92, 0.95, 1.0, 0.5), "size": 0.13, "rim_w": 0.55, "rag": 0.2},
	"metal": {"hole": Color(0.04, 0.04, 0.045, 0.95), "rim": Color(0.82, 0.82, 0.85, 0.9), "size": 0.05, "rim_w": 0.22, "rag": 0.08},
	"hay": {"hole": Color(0.14, 0.11, 0.05, 0.8), "rim": Color(0.75, 0.62, 0.3, 0.5), "size": 0.07, "rim_w": 0.4, "rag": 0.7},
}

var _impacts: Array[MeshInstance3D] = []
var _decal_mats: Dictionary = {}       # surface -> material (DECALS); "" = the plain dark mark
var _impact_life: Array[float] = []
var _blood: Array[CPUParticles3D] = []
var _tracers: Array[MeshInstance3D] = []
var _tracer_life: Array[float] = []
var _blasts: Array[Node3D] = []
var _blast_life: Array[float] = []
var _statics: Array[Node3D] = []
var _static_life: Array[float] = []
var _ni: int = 0
var _nb: int = 0
var _nt: int = 0
var _nx: int = 0
var _ns: int = 0
var _holes: Dictionary = {}            # surface -> MultiMesh (persistent holes; "" = the plain mark)
var _hole_next: Dictionary = {}        # surface -> next slot
var _snow_life: PackedFloat32Array = PackedFloat32Array()
var _snow_alive: int = 0
var _scorches: Array[Decal] = []
var _nsc: int = 0


func _ready() -> void:
	var dark: StandardMaterial3D = StandardMaterial3D.new()
	dark.albedo_color = Color(0.05, 0.05, 0.05, 0.85)
	dark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.07, 0.07)
	_decal_mats[""] = dark
	for surf: String in DECALS.keys():
		_decal_mats[surf] = _decal_mat(DECALS[surf])
	for i: int in IMPACTS:
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = quad
		mi.material_override = dark
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.hide()
		add_child(mi)
		_impacts.append(mi)
		_impact_life.append(0.0)
	_build_holes(quad)
	_build_scorches()
	if not GLBus.match_started.is_connected(_on_match_started):
		GLBus.match_started.connect(_on_match_started)
	var blood_mat: StandardMaterial3D = StandardMaterial3D.new()
	blood_mat.albedo_color = Color(0.32, 0.03, 0.04)
	var blood_mesh: BoxMesh = BoxMesh.new()
	blood_mesh.size = Vector3(0.04, 0.04, 0.04)
	blood_mesh.material = blood_mat
	for i: int in BLOOD:
		var p: CPUParticles3D = CPUParticles3D.new()
		p.emitting = false
		p.one_shot = true
		p.amount = 10
		p.lifetime = 0.45
		p.explosiveness = 1.0
		p.mesh = blood_mesh
		p.direction = Vector3(0, 0, 1)
		p.spread = 35.0
		p.initial_velocity_min = 1.5
		p.initial_velocity_max = 3.5
		p.gravity = Vector3(0, -9.0, 0)
		p.scale_amount_min = 0.6
		p.scale_amount_max = 1.4
		add_child(p)
		_blood.append(p)
	var tracer_mat: StandardMaterial3D = StandardMaterial3D.new()
	tracer_mat.albedo_color = Color(1.0, 0.85, 0.55, 0.5)
	tracer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tracer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var tracer_mesh: BoxMesh = BoxMesh.new()
	tracer_mesh.size = Vector3(0.008, 0.008, 1.0)
	for i: int in TRACERS:
		var t: MeshInstance3D = MeshInstance3D.new()
		t.mesh = tracer_mesh
		t.material_override = tracer_mat
		t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		t.hide()
		add_child(t)
		_tracers.append(t)
		_tracer_life.append(0.0)
	var fire_mat: StandardMaterial3D = StandardMaterial3D.new()
	fire_mat.albedo_color = Color(1.0, 0.55, 0.2, 0.8)
	fire_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fire_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	for i: int in BLASTS:
		var root: Node3D = Node3D.new()
		var ball: MeshInstance3D = MeshInstance3D.new()
		ball.mesh = sphere
		ball.material_override = fire_mat.duplicate()
		ball.name = "Ball"
		root.add_child(ball)
		var light: OmniLight3D = OmniLight3D.new()
		light.name = "Light"
		light.light_color = Color(1.0, 0.6, 0.3)
		light.omni_range = 12.0
		root.add_child(light)
		root.hide()
		add_child(root)
		_blasts.append(root)
		_blast_life.append(0.0)
	# Overclock Cordial's static burst: a flat ring that races out to the burst radius, a core flash, sparks
	# and a violet light (WEAPONS.md section 20.2 "a teal-violet ring pulse").
	var ring_mat: StandardMaterial3D = StandardMaterial3D.new()
	ring_mat.albedo_color = Color(STATIC_TEAL, 0.9)
	ring_mat.emission_enabled = true
	ring_mat.emission = STATIC_TEAL
	ring_mat.emission_energy_multiplier = 2.5
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var ring_mesh: TorusMesh = TorusMesh.new()
	ring_mesh.inner_radius = 0.9
	ring_mesh.outer_radius = 1.0
	ring_mesh.rings = 48
	ring_mesh.ring_segments = 6
	var spark_mesh: BoxMesh = BoxMesh.new()
	spark_mesh.size = Vector3(0.03, 0.03, 0.2)
	spark_mesh.material = ring_mat
	for i: int in STATICS:
		var root: Node3D = Node3D.new()
		var ring_: MeshInstance3D = MeshInstance3D.new()
		ring_.name = "Ring"
		ring_.mesh = ring_mesh
		ring_.material_override = ring_mat.duplicate()
		ring_.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(ring_)
		var core: MeshInstance3D = MeshInstance3D.new()
		core.name = "Core"
		core.mesh = sphere
		core.material_override = ring_mat.duplicate()
		core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(core)
		var sparks: CPUParticles3D = CPUParticles3D.new()
		sparks.name = "Sparks"
		sparks.emitting = false
		sparks.one_shot = true
		sparks.amount = 36
		sparks.lifetime = 0.35
		sparks.explosiveness = 1.0
		sparks.mesh = spark_mesh
		sparks.direction = Vector3(0, 0.3, 0)
		sparks.spread = 180.0
		sparks.initial_velocity_min = 6.0
		sparks.initial_velocity_max = 14.0
		sparks.gravity = Vector3(0, -4.0, 0)
		sparks.scale_amount_min = 0.5
		sparks.scale_amount_max = 1.6
		root.add_child(sparks)
		var light: OmniLight3D = OmniLight3D.new()
		light.name = "Light"
		light.light_color = STATIC_VIOLET
		light.omni_range = 9.0
		root.add_child(light)
		root.hide()
		add_child(root)
		_statics.append(root)
		_static_life.append(0.0)


func _process(delta: float) -> void:
	if _snow_alive > 0:
		_fade_snow_holes(delta)
	for i: int in IMPACTS:
		if _impact_life[i] > 0.0:
			_impact_life[i] -= delta
			if _impact_life[i] <= 0.0:
				_impacts[i].hide()
	for i: int in TRACERS:
		if _tracer_life[i] > 0.0:
			_tracer_life[i] -= delta
			if _tracer_life[i] <= 0.0:
				_tracers[i].hide()
	for i: int in BLASTS:
		if _blast_life[i] > 0.0:
			_blast_life[i] -= delta
			var k: float = clampf(_blast_life[i] / 0.45, 0.0, 1.0)
			var ball: MeshInstance3D = _blasts[i].get_node("Ball")
			var r: float = float(_blasts[i].get_meta("radius", 3.0)) * lerpf(0.55, 0.15, k)
			ball.scale = Vector3.ONE * r
			(ball.material_override as StandardMaterial3D).albedo_color.a = k * 0.8
			(_blasts[i].get_node("Light") as OmniLight3D).light_energy = k * 6.0
			if _blast_life[i] <= 0.0:
				_blasts[i].hide()
	for i: int in STATICS:
		if _static_life[i] > 0.0:
			_static_life[i] -= delta
			var k: float = clampf(_static_life[i] / STATIC_LIFE, 0.0, 1.0)   # 1 at birth -> 0
			var grow: float = 1.0 - k * k
			var radius: float = float(_statics[i].get_meta("radius", 3.0))
			var ring_: MeshInstance3D = _statics[i].get_node("Ring")
			ring_.scale = Vector3(1, 1, 1) * maxf(0.05, radius * grow)
			var tint: Color = STATIC_TEAL.lerp(STATIC_VIOLET, 1.0 - k)
			var rm: StandardMaterial3D = ring_.material_override
			rm.albedo_color = Color(tint, k * 0.9)
			rm.emission = tint
			var core: MeshInstance3D = _statics[i].get_node("Core")
			core.scale = Vector3.ONE * lerpf(0.15, 0.9, 1.0 - k) * 0.5
			(core.material_override as StandardMaterial3D).albedo_color = Color(STATIC_VIOLET, k * k * 0.8)
			(_statics[i].get_node("Light") as OmniLight3D).light_energy = k * 5.0
			if _static_life[i] <= 0.0:
				_statics[i].hide()


## A bullet hole at `pos` facing `normal`, styled by `surface` (wood / stone / snow / metal / hay; "" = plain).
## `collider` (what was hit) decides whether the hole persists: see persists_on().
func impact(pos: Vector3, normal: Vector3, surface: String = "", collider: Object = null) -> void:
	if persists_on(collider) and _holes.has(surface):
		_persistent_hole(pos, normal, surface)
		return
	var mi: MeshInstance3D = _impacts[_ni]
	_impact_life[_ni] = 8.0 if surface != "snow" else 5.0
	_ni = (_ni + 1) % IMPACTS
	mi.material_override = _decal_mats.get(surface, _decal_mats[""])
	var size: float = float((DECALS.get(surface, {}) as Dictionary).get("size", 0.07))
	mi.scale = Vector3.ONE * (size / 0.07) * randf_range(0.85, 1.15)
	mi.show()
	mi.global_position = pos + normal * 0.01
	if absf(normal.dot(Vector3.UP)) > 0.99:
		mi.look_at(pos + normal, Vector3.FORWARD)
	else:
		mi.look_at(pos + normal, Vector3.UP)
	mi.rotate_object_local(Vector3.UP, PI)
	mi.rotate_object_local(Vector3.BACK, randf() * TAU)


## A procedural bullet-hole texture: a dark ragged hole with a lighter chipped / splintered rim that fades out.
static func _decal_mat(d: Dictionary) -> StandardMaterial3D:
	var n: int = 64
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(str(d.get("rim")))
	var lobes: Array[float] = []
	for i: int in 9:
		lobes.append(rng.randf_range(-1.0, 1.0))
	var hole: Color = d["hole"]
	var rim: Color = d["rim"]
	var rag: float = float(d.get("rag", 0.3))
	var rim_w: float = float(d.get("rim_w", 0.35))
	for y: int in n:
		for x: int in n:
			var v: Vector2 = Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5) / (n * 0.5)
			var r: float = v.length()
			var a: float = atan2(v.y, v.x)
			var wob: float = 0.0
			for k: int in lobes.size():
				wob += lobes[k] * sin(a * float(k + 2) + float(k)) / float(k + 2)
			var edge: float = 0.32 * (1.0 + wob * rag)
			var c: Color = Color(0, 0, 0, 0)
			if r < edge:
				c = hole
			elif r < edge + rim_w * (1.0 + wob * rag * 0.8):
				var t: float = (r - edge) / maxf(0.01, rim_w)
				c = Color(rim.r, rim.g, rim.b, rim.a * (1.0 - t) * (0.7 + 0.3 * rng.randf()))
			img.set_pixel(x, y, c)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 1.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	return m


func blood(pos: Vector3, toward: Vector3) -> void:
	if str(GLSettings.values.get("gore", "full")) != "full":
		return   # the Gore setting (MZ, T-041): Off and Low show no spray
	var p: CPUParticles3D = _blood[_nb]
	_nb = (_nb + 1) % BLOOD
	p.global_position = pos
	if toward.length_squared() > 0.001:
		var fwd: Vector3 = toward.normalized()
		var up: Vector3 = Vector3.UP if absf(fwd.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
		p.global_basis = Basis.looking_at(-fwd, up)
	p.restart()
	p.emitting = true


func tracer(from: Vector3, to: Vector3) -> void:
	var dist: float = from.distance_to(to)
	if dist < 1.5:
		return
	var t: MeshInstance3D = _tracers[_nt]
	_tracer_life[_nt] = 0.04
	_nt = (_nt + 1) % TRACERS
	t.show()
	t.global_position = from.lerp(to, 0.5)
	t.look_at(to, Vector3.UP if absf((to - from).normalized().dot(Vector3.UP)) < 0.98 else Vector3.RIGHT)
	t.scale = Vector3(1, 1, dist)


func explosion(pos: Vector3, radius: float) -> void:
	if radius >= SCORCH_MIN_RADIUS:
		scorch(pos, radius)
	var b: Node3D = _blasts[_nx]
	_blast_life[_nx] = 0.45
	_nx = (_nx + 1) % BLASTS
	b.set_meta("radius", radius)
	b.global_position = pos
	b.show()


## Overclock Cordial's static burst at `pos`, racing out to `radius` (WEAPONS.md section 20.2).
func static_burst(pos: Vector3, radius: float) -> void:
	var b: Node3D = _statics[_ns]
	_static_life[_ns] = STATIC_LIFE
	_ns = (_ns + 1) % STATICS
	b.set_meta("radius", radius)
	b.global_position = pos
	b.show()
	(b.get_node("Ring") as MeshInstance3D).scale = Vector3.ONE * 0.05   # a TorusMesh already lies flat (XZ)
	var sparks: CPUParticles3D = b.get_node("Sparks")
	sparks.restart()
	sparks.emitting = true


# ================================================================== persistent marks (Update 02 section 8, T-053)

## True when a hole in `collider` can stay for the match: plain static world geometry (a StaticBody3D on the world
## layer whose parent is not a scripted gameplay node), unless it is tagged with the meta "decal_persist" (bool).
static func persists_on(collider: Object) -> bool:
	var n: Node = collider as Node
	if n == null:
		return false
	if n.has_meta("decal_persist"):
		return bool(n.get_meta("decal_persist"))
	var body: StaticBody3D = n as StaticBody3D
	if body == null or body is AnimatableBody3D or (body.collision_layer & 1) == 0 or body.get_script() != null:
		return false
	var p: Node = body.get_parent()
	return p == null or p.get_script() == null


func _build_holes(quad: QuadMesh) -> void:
	for surf: String in _decal_mats.keys():
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = surf == "snow"
		mm.mesh = quad
		mm.instance_count = HOLES_PER_SURFACE
		for i: int in HOLES_PER_SURFACE:
			mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
		var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mmi.name = "Holes_" + (surf if surf != "" else "plain")
		mmi.multimesh = mm
		var m: StandardMaterial3D = (_decal_mats[surf] as StandardMaterial3D).duplicate() as StandardMaterial3D
		if mm.use_colors:
			m.vertex_color_use_as_albedo = true
		mmi.material_override = m
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.custom_aabb = AABB(Vector3(-4000, -4000, -4000), Vector3(8000, 8000, 8000))   # never culled as a whole
		add_child(mmi)
		_holes[surf] = mm
		_hole_next[surf] = 0
	_snow_life.resize(HOLES_PER_SURFACE)
	_snow_life.fill(0.0)


func _persistent_hole(pos: Vector3, normal: Vector3, surface: String) -> void:
	var mm: MultiMesh = _holes[surface]
	var i: int = int(_hole_next[surface])
	_hole_next[surface] = (i + 1) % HOLES_PER_SURFACE
	var size: float = float((DECALS.get(surface, {}) as Dictionary).get("size", 0.07))
	var up: Vector3 = Vector3.FORWARD if absf(normal.dot(Vector3.UP)) > 0.99 else Vector3.UP
	var b: Basis = Basis.looking_at(normal, up) * Basis(Vector3.UP, PI) * Basis(Vector3.BACK, randf() * TAU)
	b = b * Basis.from_scale(Vector3.ONE * (size / 0.07) * randf_range(0.85, 1.15))
	# a hair off the surface, a little more for each newer hole so overlapping holes don't fight
	mm.set_instance_transform(i, Transform3D(b, pos + normal * (0.006 + 0.00002 * float(i))))
	if surface == "snow":
		mm.set_instance_color(i, Color(1, 1, 1, 1))
		if _snow_life[i] <= 0.0:
			_snow_alive += 1
		_snow_life[i] = SNOW_HOLE_LIFE


## Holes in snow fill in: they fade over their last two seconds, then their slot is hidden.
func _fade_snow_holes(delta: float) -> void:
	var mm: MultiMesh = _holes["snow"]
	for i: int in HOLES_PER_SURFACE:
		var l: float = _snow_life[i]
		if l <= 0.0:
			continue
		l -= delta
		_snow_life[i] = l
		if l <= 0.0:
			_snow_alive -= 1
			mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
		elif l < 2.0:
			mm.set_instance_color(i, Color(1, 1, 1, l * 0.5))


## How many persistent holes are showing (tests and the dev overlay).
func persistent_hole_count() -> int:
	var n: int = 0
	for surf: String in _holes.keys():
		var mm: MultiMesh = _holes[surf]
		for i: int in HOLES_PER_SURFACE:
			if mm.get_instance_transform(i).basis.get_scale().x > 0.0001:
				n += 1
	return n


func _build_scorches() -> void:
	var tex: ImageTexture = _scorch_texture()
	for i: int in SCORCHES:
		var d: Decal = Decal.new()
		d.name = "Scorch"
		d.texture_albedo = tex
		d.modulate = Color(1, 1, 1, 0.9)
		d.upper_fade = 0.25
		d.lower_fade = 0.25
		d.distance_fade_enabled = true
		d.distance_fade_begin = 40.0
		d.distance_fade_length = 10.0
		d.hide()
		add_child(d)
		_scorches.append(d)


## A soot mark under an explosion at `pos` (projected straight down onto whatever is below).
func scorch(pos: Vector3, radius: float) -> void:
	var d: Decal = _scorches[_nsc]
	_nsc = (_nsc + 1) % SCORCHES
	var w: float = clampf(radius * 0.9, 1.2, 4.0)
	d.size = Vector3(w, 2.4, w)
	d.global_position = pos + Vector3(0, 0.6, 0)
	d.rotation = Vector3(0, randf() * TAU, 0)
	d.show()


func scorch_count() -> int:
	var n: int = 0
	for d: Decal in _scorches:
		if d.visible:
			n += 1
	return n


## A new match: every persistent hole and scorch goes.
func clear_marks() -> void:
	for surf: String in _holes.keys():
		var mm: MultiMesh = _holes[surf]
		for i: int in HOLES_PER_SURFACE:
			mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
		_hole_next[surf] = 0
	_snow_life.fill(0.0)
	_snow_alive = 0
	for d: Decal in _scorches:
		d.hide()
	for i: int in IMPACTS:
		_impact_life[i] = 0.0
		_impacts[i].hide()


func _on_match_started(_map_id: StringName) -> void:
	clear_marks()


## Soot: a dark, ragged disc that thins out to the edge, with a few streaks thrown outward.
static func _scorch_texture() -> ImageTexture:
	var n: int = 128
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5331
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 77
	noise.frequency = 0.06
	var streaks: Array[float] = []
	for i: int in 14:
		streaks.append(rng.randf() * TAU)
	for y: int in n:
		for x: int in n:
			var v: Vector2 = Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5) / (n * 0.5)
			var r: float = v.length()
			var a: float = atan2(v.y, v.x)
			var ray: float = 0.0
			for s: float in streaks:
				ray = maxf(ray, pow(maxf(0.0, cos(a - s)), 60.0))
			var edge: float = 0.55 + 0.25 * noise.get_noise_2d(x, y) + ray * 0.35
			var k: float = clampf(1.0 - r / maxf(0.05, edge), 0.0, 1.0)
			k = pow(k, 0.7) * (0.75 + 0.25 * noise.get_noise_2d(x * 3.0, y * 3.0))
			img.set_pixel(x, y, Color(0.03, 0.025, 0.02, clampf(k * 0.95, 0.0, 0.92)))
	return ImageTexture.create_from_image(img)
