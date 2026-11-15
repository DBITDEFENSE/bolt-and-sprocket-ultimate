class_name ImpactFx
extends Node3D
## Pooled bullet-impact debris per surface (UPDATE 05 section 6, T-095), from data/gravelight/vfx.json "impacts":
## a tinted dust puff (soft billboards), a handful of chunks (a mesh per surface: wood splinters, plaster flakes,
## stone chips, glass slivers, hay chaff, cloth threads), sparks on stone and metal, and for snow and earth the
## rise's dirt pool (Effects.dirt_burst). Blood mist and droplets for zombie hits and the Nachtglas spark burst
## (a Crucible-taught weapon's hit, a Glasshide's plates) live here too. Everything is preallocated; a burst
## swaps a mesh / a colour ramp reference and restarts a one-shot emitter. Owned by Effects.

const PUFFS: int = 16
const CHUNKS: int = 16
const SPARKS: int = 8
const MIST: int = 8
const DROPS: int = 8
const GLASS: int = 6

var impacts: Dictionary = {}
var _puff: Array[CPUParticles3D] = []
var _chunk: Array[CPUParticles3D] = []
var _spark: Array[CPUParticles3D] = []
var _mist: Array[CPUParticles3D] = []
var _drops: Array[CPUParticles3D] = []
var _glass: Array[CPUParticles3D] = []
var _np: int = 0
var _nc: int = 0
var _nk: int = 0
var _nm: int = 0
var _nd: int = 0
var _ng: int = 0
var _ramps: Dictionary = {}        # surface -> Gradient
var _chunk_mesh: Dictionary = {}   # surface -> Mesh
var _default_ramp: Gradient
## Bursts by surface (tests / the dev overlay).
var counts: Dictionary = {}


func setup(impact_cfg: Dictionary, hits_cfg: Dictionary) -> void:
	impacts = impact_cfg
	var soft: Texture2D = _soft_tex()
	_default_ramp = _ramp(Color(0.55, 0.5, 0.43, 0.75), Color(0.45, 0.42, 0.38, 0.0))
	for surf: String in impacts.keys():
		var row: Dictionary = impacts[surf]
		var pf: Array = row.get("puff", [])
		if pf.size() >= 2:
			_ramps[surf] = _ramp(_col(pf[0]), _col(pf[1]))
		var ch: Variant = row.get("chunk", null)
		if ch is Dictionary:
			_chunk_mesh[surf] = _chunk_mesh_for(ch as Dictionary)
	for i: int in PUFFS:
		_puff.append(_make(_puff_mat(soft, false), 0.065, 9, 0.5, 0.6, 2.4, 28.0, Vector3(0, -3.0, 0), _default_ramp, 0.5, 1.8))
	var first_chunk: Mesh = _chunk_mesh.values()[0] if not _chunk_mesh.is_empty() else BoxMesh.new()
	for i: int in CHUNKS:
		var p: CPUParticles3D = CPUParticles3D.new()
		p.emitting = false
		p.one_shot = true
		p.amount = 8
		p.lifetime = 0.8
		p.explosiveness = 1.0
		p.mesh = first_chunk
		p.direction = Vector3(0, 0, 1)
		p.spread = 45.0
		p.initial_velocity_min = 2.0
		p.initial_velocity_max = 4.5
		p.gravity = Vector3(0, -9.8, 0)
		p.angular_velocity_min = -540.0
		p.angular_velocity_max = 540.0
		p.scale_amount_min = 0.6
		p.scale_amount_max = 1.4
		p.local_coords = false
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)
		_chunk.append(p)
	var spark_mat: StandardMaterial3D = StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.albedo_color = Color(3.0, 1.8, 0.7)
	spark_mat.vertex_color_use_as_albedo = true
	spark_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	for i: int in SPARKS:
		_spark.append(_make(spark_mat, 0.012, 7, 0.22, 3.0, 7.0, 35.0, Vector3(0, -9.8, 0),
			_ramp(Color(1.0, 0.85, 0.5, 1.0), Color(1.0, 0.4, 0.1, 0.0)), 0.6, 1.0))
	# blood (GoreFx drives these): a fine dark mist that hangs, streaks that fly and fall. Lit, never glowing.
	var mist_amount: int = int(hits_cfg.get("mist_amount", 7))
	var mist_mat: StandardMaterial3D = _puff_mat(soft, false)
	mist_mat.vertex_color_is_srgb = true     # (a ramp colour read as linear came out a bright cartoon red)
	for i: int in MIST:
		_mist.append(_make(mist_mat, 0.13, mist_amount, 0.5, 0.4, 1.6, 34.0, Vector3(0, -1.5, 0),
			_ramp(Color(0.34, 0.025, 0.03, 0.42), Color(0.16, 0.004, 0.008, 0.0)), 0.7, 2.8))
	var drop: CapsuleMesh = CapsuleMesh.new()
	drop.radius = 0.009
	drop.height = 0.07
	drop.radial_segments = 5
	drop.rings = 1
	drop.material = GoreFx.blood_material()
	for i: int in DROPS:
		var p: CPUParticles3D = CPUParticles3D.new()
		p.emitting = false
		p.one_shot = true
		p.amount = int(hits_cfg.get("blood_droplets", 12))
		p.lifetime = 0.6
		p.explosiveness = 1.0
		p.mesh = drop
		p.direction = Vector3(0, 0, 1)
		p.spread = 26.0
		p.initial_velocity_min = 1.5
		p.initial_velocity_max = 5.0
		p.gravity = Vector3(0, -9.8, 0)
		p.particle_flag_align_y = true      # a drop is a streak along its flight
		p.scale_amount_min = 0.5
		p.scale_amount_max = 1.4
		var c: Curve = Curve.new()
		c.add_point(Vector2(0.0, 1.0))
		c.add_point(Vector2(1.0, 0.4))
		p.scale_amount_curve = c
		p.local_coords = false
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)
		_drops.append(p)
	# Nachtglas: violet-teal crystal glints (a taught weapon's hit, a Glasshide's plates)
	var nc: Color = _col(hits_cfg.get("nachtglas_color", [0.72, 0.42, 1.0]))
	var glass_mat: StandardMaterial3D = spark_mat.duplicate() as StandardMaterial3D
	glass_mat.albedo_color = Color(1.2, 2.6, 2.6)
	for i: int in GLASS:
		_glass.append(_make(glass_mat, 0.016, int(hits_cfg.get("nachtglas_sparks", 14)), 0.3, 2.0, 6.0, 50.0, Vector3(0, -6.0, 0),
			_ramp(Color(0.55, 1.0, 0.95, 1.0), Color(nc, 0.0)), 0.6, 1.0))


## Does this surface have a visible answer (a puff, chunks, sparks or the dirt pool)?
func covers(surface: String) -> bool:
	if not impacts.has(surface):
		return false
	var row: Dictionary = impacts[surface]
	return _ramps.has(surface) or _chunk_mesh.has(surface) or bool(row.get("sparks", false)) or str(row.get("dirt", "")) != ""


## The debris of a bullet strike at `at` facing `normal` on `surface`; `k` scales particle counts (the quality row).
func burst(at: Vector3, normal: Vector3, surface: String, k: float = 1.0) -> void:
	var row: Dictionary = impacts.get(surface, impacts.get("stone", {}))
	counts[surface] = int(counts.get(surface, 0)) + 1
	var n: Vector3 = normal.normalized() if normal.length_squared() > 0.0001 else Vector3.UP
	var puff_n: int = int(round(float(row.get("puff_amount", 7)) * k))
	if puff_n > 0:
		var pf: CPUParticles3D = _puff[_np]
		_np = (_np + 1) % PUFFS
		pf.color_ramp = _ramps.get(surface, _default_ramp)
		if pf.amount != puff_n:
			pf.amount = puff_n
		_fire_at(pf, at + n * 0.02, n)
	var chunks_n: int = int(round(float(row.get("chunks", 0)) * k))
	if chunks_n > 0 and _chunk_mesh.has(surface):
		var ch: CPUParticles3D = _chunk[_nc]
		_nc = (_nc + 1) % CHUNKS
		var mesh: Mesh = _chunk_mesh[surface]
		if ch.mesh != mesh:
			ch.mesh = mesh
		if ch.amount != chunks_n:
			ch.amount = chunks_n
		var sp: Array = row.get("chunk_speed", [2.0, 4.5])
		ch.initial_velocity_min = float(sp[0])
		ch.initial_velocity_max = float(sp[1])
		_fire_at(ch, at + n * 0.01, n)
	if bool(row.get("sparks", false)):
		var s: CPUParticles3D = _spark[_nk]
		_nk = (_nk + 1) % SPARKS
		_fire_at(s, at + n * 0.01, n)
	var dirt: String = str(row.get("dirt", ""))
	if dirt != "":
		Effects.dirt_burst(at + n * 0.02, dirt, 0.6, n, maxi(3, int(round(10.0 * k))))


## A zombie hit at `at`, flying `toward`: the mist and the droplets (the caller gates gore).
func blood(at: Vector3, toward: Vector3, k: float = 1.0) -> void:
	blood_mist(at, toward, maxi(2, int(round(7.0 * k))))
	blood_drops(at, toward, maxi(3, int(round(12.0 * k))))


## The fine mist of a wound at `at`, drifting along `dir` (`amount` puffs).
func blood_mist(at: Vector3, dir: Vector3, amount: int) -> void:
	var m: CPUParticles3D = _mist[_nm]
	_nm = (_nm + 1) % MIST
	if m.amount != amount:
		m.amount = amount
	_fire_at(m, at, dir)


## `amount` drops thrown from `at` along `dir`.
func blood_drops(at: Vector3, dir: Vector3, amount: int) -> void:
	var d: CPUParticles3D = _drops[_nd]
	_nd = (_nd + 1) % DROPS
	if d.amount != amount:
		d.amount = amount
	_fire_at(d, at, dir)


## Violet-teal glints at `at` flying `toward`: a taught weapon's hit, a bullet glancing off Nachtglas plates.
func nachtglas(at: Vector3, toward: Vector3) -> void:
	var g: CPUParticles3D = _glass[_ng]
	_ng = (_ng + 1) % GLASS
	_fire_at(g, at, toward)


# ---------------------------------------------------------------- internals

static func _col(v: Variant) -> Color:
	if v is Array and (v as Array).size() >= 3:
		var a: Array = v
		return Color(float(a[0]), float(a[1]), float(a[2]), float(a[3]) if a.size() > 3 else 1.0)
	return Color(1, 1, 1, 1)


func _fire_at(p: CPUParticles3D, at: Vector3, dir: Vector3) -> void:
	p.global_position = at
	if dir.length_squared() > 0.0001:
		var f: Vector3 = dir.normalized()
		var up: Vector3 = Vector3.UP if absf(f.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
		p.global_basis = Basis.looking_at(-f, up)   # local +Z = dir
	p.restart()
	p.emitting = true


func _make(mat: Material, size: float, amount: int, life: float, v_min: float, v_max: float, spread: float,
		gravity: Vector3, ramp: Gradient, scale_min: float, grow: float) -> CPUParticles3D:
	var p: CPUParticles3D = CPUParticles3D.new()
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = mat
	p.mesh = q
	p.emitting = false
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.92
	p.direction = Vector3(0, 0, 1)
	p.spread = spread
	p.initial_velocity_min = v_min
	p.initial_velocity_max = v_max
	p.gravity = gravity
	p.damping_min = v_max * 0.6
	p.damping_max = v_max * 1.2
	p.scale_amount_min = scale_min
	p.scale_amount_max = 1.0
	var c: Curve = Curve.new()
	c.add_point(Vector2(0.0, 1.0 / grow))
	c.add_point(Vector2(1.0, 1.0))
	p.scale_amount_curve = c
	p.color_ramp = ramp
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


static func _chunk_mesh_for(c: Dictionary) -> Mesh:
	var box: BoxMesh = BoxMesh.new()
	var s: Array = c.get("size", [0.02, 0.02, 0.02])
	box.size = Vector3(float(s[0]), float(s[1]), float(s[2]))
	var m: StandardMaterial3D = StandardMaterial3D.new()
	var col: Color = _col(c.get("color", [0.5, 0.5, 0.5]))
	m.albedo_color = col
	m.roughness = 0.9
	if c.has("alpha"):
		m.albedo_color.a = float(c["alpha"])
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.1
	var e: float = float(c.get("emissive", 0.0))
	if e > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = e
	box.material = m
	return box


static func _ramp(a: Color, b: Color) -> Gradient:
	var g: Gradient = Gradient.new()
	g.set_color(0, a)
	g.set_color(1, b)
	return g


static func _puff_mat(tex: Texture2D, unshaded: bool) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = tex
	m.albedo_color = Color(1, 1, 1, 1)
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.roughness = 1.0
	m.disable_receive_shadows = true
	return m


static func _soft_tex() -> Texture2D:
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.55))
	var t: GradientTexture2D = GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t
