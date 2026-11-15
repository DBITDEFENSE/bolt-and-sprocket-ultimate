class_name GoreFx
extends Node3D
## The blood (docs/gore/gore_rework_2026-11.md). Owned by Effects (Effects.gore), data in vfx.json "gore".
## Presentation only and local: every peer builds its own from the hit, sever and death calls it already makes.
##
## What a hit leaves depends on the weapon class (vfx.json gore.classes): a pistol puts a fine mist in the air and a
## few drops on the floor, a rifle round goes through and throws a spatter onto what is behind the body, a shotgun or
## a blast throws meat. The marks on the world are instances of ONE MultiMesh quad (blood_decal.gdshader shapes each
## from noise: spatter, pool, drip, boot print, smear), so a slaughtered room is one draw call, and nothing about a
## mark is ticked on the CPU: its age (the pool spreading under a corpse, the run creeping down a wall, wet blood
## drying to a dark crust) is its birth time against the shader's clock.
##
## Budgets (hard caps, oldest reused first): one ring of instances per mark kind (gore.budget), halved on the
## Compatibility renderer (gore.web_scale) and scaled by vfx_quality (quality.<level>.gore); at most
## gore.per_frame.rays raycasts and gore.per_frame.marks new marks in a physics frame; chances and particle counts
## fall with the number of live zombies (gore.horde). Marks go only on plain static world geometry
## (Effects.persists_on): never on a door, a machine, a prop that moves or a character; a mark whose corners would
## hang over an edge is shrunk or dropped. The Gore setting gates all of it: only "full" bleeds.

enum { SPLAT, POOL, DRIP, PRINT, SMEAR, KINDS }
const KIND_KEYS: PackedStringArray = ["splats", "pools", "drips", "prints", "smears"]
## Metres off the surface per kind, so overlapping kinds never fight for depth (a print lies on a pool on a spatter).
const LIFT: PackedFloat32Array = [0.004, 0.006, 0.005, 0.008, 0.007]
const SHADER: String = "res://gravelight/world/vfx/blood_decal.gdshader"
const PENDING: int = 12
const WALKERS: int = 10
const HIDDEN: Transform3D = Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)
# a class profile row (PackedFloat32Array), see _profile()
enum { P_MIST, P_DROPS, P_CHUNKS, P_EXIT, P_REACH, P_SIZE_MIN, P_SIZE_MAX, P_FLOOR, P_DRIP, P_SCREEN, P_COUNT }

var cfg: Dictionary = {}
var screen: GoreScreen
## Marks placed / reused / refused, rays cast (tests, the dev overlay).
var stats: Dictionary = {"marks": 0, "evicted": 0, "rejected": 0, "rays": 0, "pools": 0, "spurts": 0, "prints": 0, "sprays": 0, "walls": 0}

var _mm: MultiMesh
var _mmi: MultiMeshInstance3D
var _mat: ShaderMaterial
var _start: PackedInt32Array = PackedInt32Array()
var _cap: PackedInt32Array = PackedInt32Array()
var _next: PackedInt32Array = PackedInt32Array()
var _live: PackedInt32Array = PackedInt32Array()
var _clock: float = 0.0
var _rays_left: int = 0
var _marks_left: int = 0
var _max_rays: int = 12
var _max_marks: int = 6
var _q: PhysicsRayQueryParameters3D
var _profiles: Dictionary = {}          # weapon class -> PackedFloat32Array
var _weapon_prof: Dictionary = {}       # weapon id (StringName) -> PackedFloat32Array
var _default: PackedFloat32Array
var _horde_from: float = 12.0
var _horde_to: float = 40.0
var _horde_min: float = 0.35
var _wet_seconds: float = 35.0
# pools (for the walkers): a slot per pool instance
var _pool_pos: PackedVector3Array = PackedVector3Array()
var _pool_r: PackedFloat32Array = PackedFloat32Array()
var _pool_born: PackedFloat32Array = PackedFloat32Array()
# bodies that will pool: instance id and the clock time it is due
var _pend_id: PackedInt64Array = PackedInt64Array()
var _pend_t: PackedFloat32Array = PackedFloat32Array()
var _pend_big: PackedFloat32Array = PackedFloat32Array()
var _pend_n: int = 0
# arterial spurts: emitters that follow a neck
var _spurts: Array[CPUParticles3D] = []
var _spurt_id: PackedInt64Array = PackedInt64Array()
var _spurt_t: PackedFloat32Array = PackedFloat32Array()
var _spurt_len: PackedFloat32Array = PackedFloat32Array()
var _spurt_drop: PackedFloat32Array = PackedFloat32Array()
var _spurt_n: int = 0
var _nspurt: int = 0
# heavy bits (shotguns, blasts, severs)
var _chunks: Array[CPUParticles3D] = []
var _nchunk: int = 0
# walkers: whoever trod in a wet pool (prints) and crawlers (a smear behind them)
var _w_id: PackedInt64Array = PackedInt64Array()
var _w_left: PackedInt32Array = PackedInt32Array()
var _w_total: PackedInt32Array = PackedInt32Array()
var _w_kind: PackedInt32Array = PackedInt32Array()
var _w_last: PackedVector3Array = PackedVector3Array()
var _w_side: PackedFloat32Array = PackedFloat32Array()
var _w_n: int = 0
var _scan_t: float = 0.0
var _scan_every: float = 0.4
var _print_steps: int = 9
var _smear_steps: int = 14
var _zombie_prints_max: int = 16


func setup(c: Dictionary) -> void:
	cfg = c
	var budget: Dictionary = c.get("budget", {})
	var total: int = 0
	for k: int in KINDS:
		var n: int = maxi(4, int(budget.get(KIND_KEYS[k], 32)))
		_start.append(total)
		_cap.append(n)
		_next.append(0)
		_live.append(0)
		total += n
	var pf: Dictionary = c.get("per_frame", {})
	_max_rays = int(pf.get("rays", 12))
	_max_marks = int(pf.get("marks", 6))
	var h: Dictionary = c.get("horde", {})
	_horde_from = float(h.get("from", 12))
	_horde_to = maxf(_horde_from + 1.0, float(h.get("to", 40)))
	_horde_min = float(h.get("min", 0.35))
	_zombie_prints_max = int(h.get("zombie_prints_max", 16))
	var tr: Dictionary = c.get("tracks", {})
	_wet_seconds = float(tr.get("wet_seconds", 35.0))
	_scan_every = float(tr.get("scan_seconds", 0.4))
	_print_steps = int(tr.get("print_steps", 9))
	_smear_steps = int(tr.get("smear_steps", 14))
	var classes: Dictionary = c.get("classes", {})
	for cls: String in classes.keys():
		_profiles[cls] = _profile(classes[cls] as Dictionary)
	_default = _profiles.get("default", _profile({}))
	_q = PhysicsRayQueryParameters3D.new()
	_q.collision_mask = 1
	# the marks
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2.ONE
	_mat = ShaderMaterial.new()
	_mat.shader = load(SHADER) as Shader
	_mat.set_shader_parameter("noise_tex", noise_texture())
	_mat.set_shader_parameter("dry_seconds", float(c.get("dry_seconds", 50.0)))
	_mat.set_shader_parameter("wet_color", _col(c.get("wet_color", [0.3, 0.012, 0.018])))
	_mat.set_shader_parameter("dry_color", _col(c.get("dry_color", [0.075, 0.018, 0.012])))
	_mat.set_shader_parameter("snow_halo", _col(c.get("snow_halo", [0.42, 0.07, 0.08])))
	_mat.render_priority = 1
	quad.material = _mat
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_custom_data = true
	_mm.mesh = quad
	_mm.instance_count = total
	for i: int in total:
		_mm.set_instance_transform(i, HIDDEN)
		_mm.set_instance_custom_data(i, Color(0, 1, 0, 0))
	_mmi = MultiMeshInstance3D.new()
	_mmi.name = "Blood"
	_mmi.multimesh = _mm
	_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mmi.custom_aabb = AABB(Vector3(-4000, -4000, -4000), Vector3(8000, 8000, 8000))   # never culled as a whole
	add_child(_mmi)
	_pool_pos.resize(_cap[POOL])
	_pool_r.resize(_cap[POOL])
	_pool_born.resize(_cap[POOL])
	_pool_born.fill(-1.0e6)
	_pend_id.resize(PENDING)
	_pend_t.resize(PENDING)
	_pend_big.resize(PENDING)
	_w_id.resize(WALKERS)
	_w_left.resize(WALKERS)
	_w_total.resize(WALKERS)
	_w_kind.resize(WALKERS)
	_w_last.resize(WALKERS)
	_w_side.resize(WALKERS)
	_build_spurts(int((c.get("spurt", {}) as Dictionary).get("slots", 3)))
	_build_chunks(int(c.get("chunk_slots", 6)))
	screen = GoreScreen.new()
	screen.name = "Screen"
	screen.setup(c.get("screen", {}), noise_texture())
	add_child(screen)
	_rays_left = _max_rays
	_marks_left = _max_marks
	set_process(false)


static var _noise: ImageTexture


## The shared shape noise (seamless, generated once: a few milliseconds, no file).
static func noise_texture() -> ImageTexture:
	if _noise == null:
		var n: FastNoiseLite = FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.seed = 1945
		n.frequency = 0.035
		n.fractal_octaves = 3
		var img: Image = n.get_seamless_image(128, 128)
		img.generate_mipmaps()
		_noise = ImageTexture.create_from_image(img)
	return _noise


static func _col(v: Variant) -> Color:
	if v is Array and (v as Array).size() >= 3:
		var a: Array = v
		return Color(float(a[0]), float(a[1]), float(a[2]))
	return Color(0.3, 0.012, 0.018)


static func _profile(row: Dictionary) -> PackedFloat32Array:
	var p: PackedFloat32Array = PackedFloat32Array()
	p.resize(P_COUNT)
	var size: Array = row.get("size", [0.3, 0.6])
	p[P_MIST] = float(row.get("mist", 5))
	p[P_DROPS] = float(row.get("drops", 8))
	p[P_CHUNKS] = float(row.get("chunks", 0))
	p[P_EXIT] = float(row.get("exit", 0.5))
	p[P_REACH] = float(row.get("reach", 3.0))
	p[P_SIZE_MIN] = float(size[0])
	p[P_SIZE_MAX] = float(size[1])
	p[P_FLOOR] = float(row.get("floor", 0.4))
	p[P_DRIP] = float(row.get("drip", 0.3))
	p[P_SCREEN] = float(row.get("screen", 0.0))
	return p


# ================================================================== budgets

static func enabled() -> bool:
	return str(GLSettings.values.get("gore", "full")) == "full"


## The share of the instance budget in use: vfx_quality's "gore" (low 0.5 / medium 0.75 / high 1) and the web profile.
func budget_k() -> float:
	var k: float = float(Effects.quality().get("gore", 1.0))
	if GLSettings.is_compat():
		k *= float(cfg.get("web_scale", 0.5))
	return clampf(k, 0.1, 1.0)


## How many instances kind `k` may show right now.
func cap(k: int) -> int:
	return maxi(4, int(float(_cap[k]) * budget_k()))


func live(k: int) -> int:
	return _live[k]


func live_total() -> int:
	var n: int = 0
	for k: int in KINDS:
		n += _live[k]
	return n


## 1 with a handful of zombies, down to gore.horde.min in a big horde: fewer particles, fewer marks per hit.
func horde_k() -> float:
	var alive: float = float(RoundManager.alive)
	return lerpf(1.0, _horde_min, clampf((alive - _horde_from) / (_horde_to - _horde_from), 0.0, 1.0))


func clear() -> void:
	for i: int in _mm.instance_count:
		_mm.set_instance_transform(i, HIDDEN)
	for k: int in KINDS:
		_next[k] = 0
		_live[k] = 0
	_pool_born.fill(-1.0e6)
	_pend_n = 0
	_pend_t.fill(0.0)
	_w_left.fill(0)
	_w_n = 0
	for i: int in _spurts.size():
		_spurts[i].emitting = false
		_spurt_len[i] = 0.0
	_spurt_n = 0
	_clock = 0.0
	_mat.set_shader_parameter("now", 0.0)
	if screen != null:
		screen.clear()
	set_process(false)


func _process(delta: float) -> void:
	_clock += delta
	_mat.set_shader_parameter("now", _clock)


## A new physics frame: the ray and mark allowances are whole again.
func new_frame() -> void:
	_rays_left = _max_rays
	_marks_left = _max_marks


func _physics_process(delta: float) -> void:
	new_frame()
	if _pend_n > 0:
		_tick_pending()
	if _spurt_n > 0:
		_tick_spurts(delta)
	if _w_n > 0:
		_tick_walkers()
	if _live[POOL] > 0:
		_scan_t -= delta
		if _scan_t <= 0.0:
			_scan_t = _scan_every
			_scan_pools()


# ================================================================== a hit

func _prof(weapon_id: StringName) -> PackedFloat32Array:
	if weapon_id == &"":
		return _default
	if _weapon_prof.has(weapon_id):
		return _weapon_prof[weapon_id]
	var p: PackedFloat32Array = _profiles.get(Effects.weapon_class_of(weapon_id), _default)
	_weapon_prof[weapon_id] = p
	return p


## Blood from a wound at `pos`. `toward` is where the spray flies. `through` (a bullet): `toward` points back at the
## shooter; a little mist comes out of the entry, the body of it leaves the far side and marks what is behind.
## `overhead`: a spray flying up may mark a ceiling (a neck, a limb; not the blood off a burning body).
func spray(pos: Vector3, toward: Vector3, weapon_id: StringName, through: bool, overhead: bool = false) -> void:
	stats["sprays"] = int(stats["sprays"]) + 1
	var prof: PackedFloat32Array = _prof(weapon_id)
	var hk: float = horde_k()
	var k: float = Effects.particles_k() * hk
	var out: Vector3 = toward.normalized() if toward.length_squared() > 0.0001 else Vector3.UP
	var fly: Vector3 = -out if through else out
	var fx: ImpactFx = Effects.impact_fx
	if fx != null:
		fx.blood_mist(pos, out if through else fly, maxi(2, int(round(prof[P_MIST] * k))))
		fx.blood_drops(pos + (fly * 0.2 if through else Vector3.ZERO), fly, maxi(3, int(round(prof[P_DROPS] * k))))
	if prof[P_CHUNKS] > 0.0:
		chunks(pos, fly, maxi(2, int(round(prof[P_CHUNKS] * k))))
	if prof[P_SCREEN] > 0.0 and screen != null:
		var cam: Camera3D = get_viewport().get_camera_3d()
		if cam != null and cam.global_position.distance_squared_to(pos) < screen.near_sq:
			screen.add(prof[P_SCREEN])
	if _marks_left <= 0 or not is_inside_tree():
		return
	if randf() < prof[P_EXIT] * hk and (through or overhead or fly.y < 0.6):
		_exit_spatter(pos, fly, prof)
	if randf() < prof[P_FLOOR] * hk:
		_floor_drops(pos, fly, prof)


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	_rays_left -= 1
	stats["rays"] = int(stats["rays"]) + 1
	_q.from = from
	_q.to = to
	return get_world_3d().direct_space_state.intersect_ray(_q)


func _exit_spatter(pos: Vector3, fly: Vector3, prof: PackedFloat32Array) -> void:
	if _rays_left < 6:
		return
	var d: Vector3 = (fly + Vector3(randf_range(-0.16, 0.16), randf_range(-0.14, 0.06), randf_range(-0.16, 0.16))).normalized()
	var reach: float = prof[P_REACH]
	var hit: Dictionary = _ray(pos + fly * 0.1, pos + d * reach)
	if hit.is_empty() or not Effects.persists_on(hit["collider"]):
		return
	var n: Vector3 = hit["normal"]
	if n.length_squared() < 0.5:
		return   # the ray began inside something
	var at: Vector3 = hit["position"]
	var near: float = 1.0 - clampf(pos.distance_to(at) / reach, 0.0, 1.0)
	var size: float = lerpf(prof[P_SIZE_MIN], prof[P_SIZE_MAX], near) * randf_range(0.85, 1.2)
	if absf(n.y) < 0.5:
		# a wall: a burst where it struck, and often a run down from it
		var t: Vector3 = Vector3.UP.cross(n).normalized().rotated(n, randf() * TAU)
		if _mark(SPLAT, at, n, t, size, size * randf_range(0.8, 1.2), 1.0, 1.0, false, true):
			stats["walls"] = int(stats["walls"]) + 1
			if size > 0.3:
				AudioDirector.play_3d("gore_splat", at, -4.0 + 6.0 * near)
			if absf(n.y) < 0.25 and randf() < prof[P_DRIP]:
				_drip(at + Vector3.DOWN * size * 0.12, n)
	else:
		# the floor (or a ceiling): cast off along the flight, longer the shallower it lands
		var t2: Vector3 = d - n * d.dot(n)
		t2 = t2.normalized() if t2.length_squared() > 0.001 else n.cross(Vector3.RIGHT).normalized()
		var graze: float = 1.0 + 1.1 * (1.0 - absf(d.dot(n)))
		var snow: bool = n.y > 0.5 and _is_snow(hit["collider"], at, n)
		_mark(SPLAT, at + t2 * size * 0.25 * (graze - 1.0), n, t2, size * graze, size * 0.9, 1.0, 1.0, snow, true)


func _floor_drops(pos: Vector3, fly: Vector3, prof: PackedFloat32Array) -> void:
	if _rays_left < 2:
		return
	var flat: Vector3 = Vector3(fly.x, 0.0, fly.z)
	var from: Vector3 = pos + flat * randf_range(0.25, 1.1) + Vector3(randf_range(-0.2, 0.2), 0.0, randf_range(-0.2, 0.2))
	var hit: Dictionary = _ray(from, from + Vector3.DOWN * 2.6)
	if hit.is_empty() or not Effects.persists_on(hit["collider"]):
		return
	var n: Vector3 = hit["normal"]
	if n.y < 0.7:
		return
	var t: Vector3 = flat - n * flat.dot(n)
	t = t.normalized() if t.length_squared() > 0.001 else n.cross(Vector3.RIGHT).normalized()
	var size: float = prof[P_SIZE_MIN] * randf_range(0.6, 1.1)
	_mark(SPLAT, hit["position"], n, t, size * randf_range(1.0, 1.6), size, 1.0, 0.9, _is_snow(hit["collider"], hit["position"], n), false)


func _drip(top: Vector3, n: Vector3) -> void:
	if _rays_left < 2:
		return
	var length: float = randf_range(0.45, 1.15)
	var probe: Vector3 = top + Vector3.DOWN * length
	if _ray(probe + n * 0.12, probe - n * 0.12).is_empty():
		length *= 0.5
		probe = top + Vector3.DOWN * length
		if _ray(probe + n * 0.12, probe - n * 0.12).is_empty():
			return
	var per_m: Array = (cfg.get("drip_seconds_per_m", [6.0, 11.0]) as Array)
	_mark(DRIP, top + Vector3.DOWN * length * 0.5, n, Vector3.UP.cross(n).normalized(), randf_range(0.2, 0.3), length,
		length * randf_range(float(per_m[0]), float(per_m[1])), 1.0, false, false)


func _is_snow(collider: Object, at: Vector3, n: Vector3) -> bool:
	_rays_left -= 1
	return Effects.surface_of(collider, at, n, get_world_3d().direct_space_state) == "snow"


## True when the four corners of a mark (half extents hx, hy along t, b) all lie on something.
func _supported(at: Vector3, n: Vector3, t: Vector3, b: Vector3, hx: float, hy: float) -> bool:
	if _rays_left < 4:
		return false
	for i: int in 4:
		var c: Vector3 = at + t * (hx if (i & 1) == 0 else -hx) + b * (hy if (i & 2) == 0 else -hy)
		var hit: Dictionary = _ray(c + n * 0.14, c - n * 0.1)
		if hit.is_empty() or (hit["normal"] as Vector3).dot(n) < 0.9:
			return false
	return true


## One mark of `kind` at `at` on a surface facing `n`; `t` is its x axis (its y axis is n x t), sx / sy its size in
## metres. `grow`: seconds a pool spreads or a drip runs. Returns false when it was refused (budget, an edge).
func _mark(kind: int, at: Vector3, n: Vector3, t: Vector3, sx: float, sy: float, grow: float, strength: float, snow: bool, check: bool) -> bool:
	if _marks_left <= 0:
		return false
	var b: Vector3 = n.cross(t).normalized()
	t = b.cross(n)
	if check and not _supported(at, n, t, b, sx * 0.31, sy * 0.31):
		sx *= 0.5
		sy *= 0.5
		if not _supported(at, n, t, b, sx * 0.31, sy * 0.31):
			stats["rejected"] = int(stats["rejected"]) + 1
			return false
	_marks_left -= 1
	var c: int = cap(kind)
	var slot: int = _next[kind] % c
	_next[kind] = (slot + 1) % c
	if _live[kind] < c:
		_live[kind] += 1
	else:
		stats["evicted"] = int(stats["evicted"]) + 1
	stats["marks"] = int(stats["marks"]) + 1
	var i: int = _start[kind] + slot
	# a hair further out for each newer mark, so two of a kind that overlap never fight
	_mm.set_instance_transform(i, Transform3D(Basis(t * sx, b * sy, n), at + n * (LIFT[kind] + 0.000004 * float(slot))))
	_mm.set_instance_custom_data(i, Color(_clock, maxf(0.01, grow), float(kind) + randf() * 0.99, clampf(strength, 0.0, 1.0) + (2.0 if snow else 0.0)))
	if kind == POOL:
		_pool_pos[slot] = at
		_pool_r[slot] = maxf(sx, sy) * 0.42
		_pool_born[slot] = _clock
	if not is_processing():
		set_process(true)
	return true


# ================================================================== a death: the pool under the body

## `body` died (any peer). A second or so later, when it has come to rest, blood pools under it. `big` scales the
## pool (a head or a blast: more of it).
func death(body: Node3D, big: float = 1.0) -> void:
	if not enabled() or body == null:
		return
	var slot: int = -1
	var id: int = body.get_instance_id()
	for i: int in PENDING:
		if _pend_t[i] <= 0.0 or _pend_id[i] == id:
			slot = i
			break
	if slot < 0:
		return   # twelve bodies already waiting: this one leaves none
	if _pend_t[slot] <= 0.0:
		_pend_n += 1
	_pend_id[slot] = id
	_pend_t[slot] = _clock + randf_range(0.8, 1.5) + 0.001
	_pend_big[slot] = big
	set_process(true)


func _tick_pending() -> void:
	for i: int in PENDING:
		if _pend_t[i] <= 0.0 or _pend_t[i] > _clock or _rays_left < 6 or _marks_left <= 0:
			continue
		_pend_t[i] = 0.0
		_pend_n -= 1
		var body: Node3D = instance_from_id(_pend_id[i]) as Node3D
		if body == null or not body.is_inside_tree() or not body.visible:
			continue
		pool_under(_rest_point(body), _pend_big[i])


## Where a body's blood comes out: its hips (the ragdoll may have carried them off the root).
static func _rest_point(body: Node3D) -> Vector3:
	var z: Zombie = body as Zombie
	if z != null and z.has_rig():
		var hips: Node3D = z.bone_attachment("Hips")
		if hips != null:
			return hips.global_position
	return body.global_position + Vector3.UP * 0.3


## A pool on the floor under `from` (within 2.2 m below it). Returns true when one was laid.
func pool_under(from: Vector3, big: float = 1.0) -> bool:
	if not enabled() or not is_inside_tree():
		return false
	var hit: Dictionary = _ray(from + Vector3.UP * 0.4, from + Vector3.DOWN * 2.2)
	if hit.is_empty() or not Effects.persists_on(hit["collider"]):
		return false
	var n: Vector3 = hit["normal"]
	if n.y < 0.75:
		return false
	var at: Vector3 = hit["position"]
	var sz: Array = cfg.get("pool_size", [1.1, 1.7])
	var grow: Array = cfg.get("pool_grow_seconds", [6.0, 10.0])
	var size: float = randf_range(float(sz[0]), float(sz[1])) * big * lerpf(1.0, 0.7, 1.0 - horde_k())
	var t: Vector3 = n.cross(Vector3.FORWARD).normalized().rotated(n, randf() * TAU)
	var ok: bool = _mark(POOL, at, n, t, size, size * randf_range(0.8, 1.0), randf_range(float(grow[0]), float(grow[1])), 1.0,
		_is_snow(hit["collider"], at, n), true)
	if ok:
		stats["pools"] = int(stats["pools"]) + 1
		AudioDirector.play_3d("gore_drip", at, -6.0)
	return ok


# ================================================================== arterial spurts

func _build_spurts(n: int) -> void:
	var mat: StandardMaterial3D = blood_material()
	var streak: CapsuleMesh = CapsuleMesh.new()
	streak.radius = 0.009
	streak.height = 0.075
	streak.radial_segments = 5
	streak.rings = 1
	streak.material = mat
	for i: int in n:
		var p: CPUParticles3D = CPUParticles3D.new()
		p.name = "Spurt%d" % i
		p.emitting = false
		p.amount = 22
		p.lifetime = 0.75
		p.explosiveness = 0.0
		p.randomness = 0.3
		p.mesh = streak
		p.direction = Vector3(0, 0, 1)
		p.spread = 13.0
		p.initial_velocity_min = 2.2
		p.initial_velocity_max = 3.6
		p.gravity = Vector3(0, -9.8, 0)
		p.particle_flag_align_y = true
		p.scale_amount_min = 0.6
		p.scale_amount_max = 1.5
		p.local_coords = false
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)
		_spurts.append(p)
	_spurt_id.resize(n)
	_spurt_t.resize(n)
	_spurt_len.resize(n)
	_spurt_drop.resize(n)


## The one material every blood particle shares: dark, wet, lit (never emissive).
static var _blood_mat: StandardMaterial3D


static func blood_material() -> StandardMaterial3D:
	if _blood_mat == null:
		_blood_mat = StandardMaterial3D.new()
		_blood_mat.albedo_color = Color(0.26, 0.012, 0.016)
		_blood_mat.roughness = 0.12
		_blood_mat.metallic_specular = 0.7
	return _blood_mat


## An artery opened at `at` (a neck after the head went): pulses of blood that follow it for a few seconds and
## spatter the floor around it. At most gore.spurt.slots at once (the oldest is taken over).
func spurt(at: Node3D) -> void:
	if not enabled() or at == null or _spurts.is_empty():
		return
	var i: int = _nspurt
	_nspurt = (_nspurt + 1) % _spurts.size()
	if _spurt_len[i] <= 0.0:
		_spurt_n += 1
	var sc: Dictionary = cfg.get("spurt", {})
	var secs: Array = sc.get("seconds", [2.2, 3.4])
	_spurt_id[i] = at.get_instance_id()
	_spurt_t[i] = 0.0
	_spurt_len[i] = randf_range(float(secs[0]), float(secs[1])) * lerpf(1.0, 0.6, 1.0 - horde_k())
	_spurt_drop[i] = 0.25
	stats["spurts"] = int(stats["spurts"]) + 1
	AudioDirector.play_3d("gore_spurt", at.global_position, -2.0)


func _tick_spurts(delta: float) -> void:
	for i: int in _spurts.size():
		if _spurt_len[i] <= 0.0:
			continue
		var p: CPUParticles3D = _spurts[i]
		var at: Node3D = instance_from_id(_spurt_id[i]) as Node3D
		_spurt_t[i] += delta
		var t: float = _spurt_t[i]
		if at == null or not at.is_inside_tree() or t >= _spurt_len[i]:
			p.emitting = false
			_spurt_len[i] = 0.0
			_spurt_n -= 1
			continue
		var up: Vector3 = at.global_basis.y.normalized()
		p.global_position = at.global_position + up * 0.04
		p.global_basis = Basis.looking_at(-up, Vector3.RIGHT if absf(up.dot(Vector3.UP)) > 0.98 else Vector3.UP)
		var fade: float = sqrt(1.0 - t / _spurt_len[i])
		p.initial_velocity_max = 1.2 + 2.6 * fade
		p.initial_velocity_min = 0.6 + 1.6 * fade
		p.emitting = fmod(t, 0.44) < 0.27      # the heart still pumping
		if t >= _spurt_drop[i] and _rays_left >= 2 and _marks_left > 0:
			_spurt_drop[i] = t + randf_range(0.45, 0.8)
			var side: Vector3 = Vector3(randf_range(-0.7, 0.7), 0.0, randf_range(-0.7, 0.7)) * fade
			var hit: Dictionary = _ray(p.global_position + side, p.global_position + side + Vector3.DOWN * 2.6)
			if not hit.is_empty() and (hit["normal"] as Vector3).y > 0.7 and Effects.persists_on(hit["collider"]):
				var n: Vector3 = hit["normal"]
				var size: float = randf_range(0.22, 0.5)
				_mark(SPLAT, hit["position"], n, n.cross(Vector3.FORWARD).normalized().rotated(n, randf() * TAU), size, size, 1.0, 1.0,
					_is_snow(hit["collider"], hit["position"], n), false)


# ================================================================== heavy bits

func _build_chunks(n: int) -> void:
	var bit: SphereMesh = SphereMesh.new()
	bit.radius = 0.02
	bit.height = 0.026
	bit.radial_segments = 5
	bit.rings = 2
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(0.2, 0.03, 0.03)
	m.roughness = 0.3
	bit.material = m
	for i: int in n:
		var p: CPUParticles3D = CPUParticles3D.new()
		p.name = "Chunks%d" % i
		p.emitting = false
		p.one_shot = true
		p.amount = 8
		p.lifetime = 0.9
		p.explosiveness = 1.0
		p.mesh = bit
		p.direction = Vector3(0, 0, 1)
		p.spread = 38.0
		p.initial_velocity_min = 2.0
		p.initial_velocity_max = 5.5
		p.gravity = Vector3(0, -9.8, 0)
		p.angular_velocity_min = -400.0
		p.angular_velocity_max = 400.0
		p.scale_amount_min = 0.5
		p.scale_amount_max = 1.7
		p.local_coords = false
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)
		_chunks.append(p)


## Bits of meat thrown from `at` along `dir` (a shotgun, a blast, a limb coming off).
func chunks(at: Vector3, dir: Vector3, amount: int) -> void:
	if _chunks.is_empty() or not is_inside_tree():
		return
	var p: CPUParticles3D = _chunks[_nchunk]
	_nchunk = (_nchunk + 1) % _chunks.size()
	if p.amount != amount:
		p.amount = amount
	p.global_position = at
	var f: Vector3 = dir.normalized() if dir.length_squared() > 0.0001 else Vector3.UP
	p.global_basis = Basis.looking_at(-f, Vector3.UP if absf(f.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT)
	p.restart()
	p.emitting = true


# ================================================================== tracks: boot prints and crawler smears

## `who` now leaves `steps` marks behind it: kind PRINT (trod in blood) or SMEAR (a crawler dragging itself).
func track(who: Node3D, kind: int, steps: int) -> void:
	if not enabled() or who == null or steps <= 0:
		return
	var id: int = who.get_instance_id()
	var slot: int = -1
	var weakest: int = 0
	for i: int in WALKERS:
		if _w_left[i] > 0 and _w_id[i] == id:
			slot = i
			break
		if _w_left[i] <= 0 and slot < 0:
			slot = i
		if _w_left[i] < _w_left[weakest]:
			weakest = i
	if slot < 0:
		slot = weakest
	if _w_left[slot] <= 0:
		_w_n += 1
		_w_last[slot] = who.global_position
		_w_side[slot] = 1.0
	_w_id[slot] = id
	_w_left[slot] = steps
	_w_total[slot] = steps
	_w_kind[slot] = kind


## A zombie lost its legs and drags itself on: a smear follows it.
func crawler(z: Node3D) -> void:
	track(z, SMEAR, _smear_steps)


func tracked() -> int:
	return _w_n


func _tick_walkers() -> void:
	for i: int in WALKERS:
		if _w_left[i] <= 0:
			continue
		var who: Node3D = instance_from_id(_w_id[i]) as Node3D
		var z: Zombie = who as Zombie
		if who == null or not who.is_inside_tree() or (z != null and not z.is_active()):
			_w_left[i] = 0
			_w_n -= 1
			continue
		var smear: bool = _w_kind[i] == SMEAR
		var d: Vector3 = who.global_position - _w_last[i]
		d.y = 0.0
		var stride: float = 0.5 if smear else 0.78
		if d.length_squared() < stride * stride or _rays_left < 2 or _marks_left <= 0:
			continue
		var dir: Vector3 = d.normalized()
		var from: Vector3 = who.global_position + Vector3.UP * 0.4
		var hit: Dictionary = _ray(from, from + Vector3.DOWN * 1.0)
		_w_last[i] = who.global_position
		if hit.is_empty() or (hit["normal"] as Vector3).y < 0.7 or not Effects.persists_on(hit["collider"]):
			continue
		var n: Vector3 = hit["normal"]
		var at: Vector3 = hit["position"]
		var strength: float = float(_w_left[i]) / float(maxi(1, _w_total[i]))
		var snow: bool = _is_snow(hit["collider"], at, n)
		if smear:
			_mark(SMEAR, at - dir * 0.35, n, dir, randf_range(0.8, 1.05), randf_range(0.34, 0.5), 1.0, 0.5 + 0.5 * strength, snow, false)
		else:
			var right: Vector3 = dir.cross(n).normalized()
			_mark(PRINT, at + right * 0.11 * _w_side[i], n, right, 0.125, 0.3, 1.0, strength, snow, false)
			_w_side[i] = -_w_side[i]
			stats["prints"] = int(stats["prints"]) + 1
		_w_left[i] -= 1
		if _w_left[i] <= 0:
			_w_n -= 1


## Who stands in a wet pool (players always; zombies only while there are few of them).
func _scan_pools() -> void:
	var tree: SceneTree = get_tree()
	for p: Node in tree.get_nodes_in_group(&"players"):
		var p3: Node3D = p as Node3D
		if p3 != null and _in_wet_pool(p3.global_position):
			track(p3, PRINT, _print_steps)
	if RoundManager.alive > _zombie_prints_max:
		return
	var dir: ZombieDirector = tree.get_first_node_in_group(&"director") as ZombieDirector
	if dir == null:
		return
	for z: Zombie in dir.active_zombies():
		if not z.is_crawler and _in_wet_pool(z.global_position):
			track(z, PRINT, _print_steps)


func _in_wet_pool(at: Vector3) -> bool:
	for i: int in _pool_pos.size():
		if _clock - _pool_born[i] > _wet_seconds:
			continue
		var d: Vector3 = at - _pool_pos[i]
		if absf(d.y) < 0.6 and d.x * d.x + d.z * d.z < _pool_r[i] * _pool_r[i]:
			return true
	return false
