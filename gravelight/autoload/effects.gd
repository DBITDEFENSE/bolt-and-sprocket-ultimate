extends Node3D
## Pooled, cheap greybox VFX: bullet impacts, blood, tracers, explosions, Overclock static bursts.
## Presentation only.
##
## Blood (the gore rework, docs/gore/gore_rework_2026-11.md) is GoreFx (`gore`, gravelight/world/vfx/gore_fx.gd):
## blood() and zombie_hit() hand it every wound; it throws the particles and lays the marks, pools and tracks.
##
## Update 02 section 8 (T-053): bullet holes in the static world persist for the match (one MultiMesh per surface
## kind, HOLES_PER_SURFACE each; when a kind is full its oldest hole is reused, so the cost is capped), except in
## snow, where they fill in after a few seconds. Holes in things that move or vanish (doors, seals, machines) stay
## short-lived quads, so nothing floats in the air when a door rises. Real explosions leave a scorch mark (a
## pooled Decal, SCORCHES of them, oldest reused). Both are wiped when a match starts.
##
## UPDATE 05 section 6 (T-095): the world-space gun and hit VFX live here, data in data/gravelight/vfx.json,
## helpers under gravelight/world/vfx/. Muzzle flashes per weapon class (FlashPool) are driven from
## GLBus.weapon_fired for every shooter (the local viewmodel's true muzzle, a bot's or teammate's third-person gun,
## else the shot origin); ejected casings use the real cartridge models (CasingPool; WeaponHolder ejects through
## GunFx.eject, which forwards here); impacts add per-surface debris (ImpactFx) to the decals; zombie hits get a
## mist, droplets and, from a Crucible-taught weapon, a Nachtglas spark burst; the Glasshide shatter and the
## Totenglocke's Great Toll refraction ring are pooled here too. GLSettings "vfx_quality" (low / medium / high)
## scales counts through quality(). The atmosphere pass (VfxAtmosphere: near snow, dust in the light shafts, the
## west field fog) attaches to the map at match start. TODO (hooks for other owners, see the T-095 report):
##   weapon_holder.gd _trace: after `Effects.blood(pos, -dir)` call `Effects.zombie_hit(pos, -dir, w.id, w.upgraded)`
##   weapon_holder.gd _eject_casing: pass the weapon id, `fx.eject(kind, from, vel, basis, w.id)`
##   zombie.gd _shards: `Effects.shatter(global_position + Vector3.UP * 1.1, color, amount, speed_max)` instead of a new emitter
##   menu_settings.gd: a "VFX quality" option for GLSettings "vfx_quality" (low / medium / high)

const IMPACTS: int = 48
const TRACERS: int = 48
const BLASTS: int = BlastFx.SLOTS   # T-280: the blast pool lives in BlastFx (blast)
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
	# T-095: a plaster crater (a grey pit in a pale chipped ring), a glass star (a pale ragged hole with a white rim)
	"plaster": {"hole": Color(0.42, 0.4, 0.37, 0.9), "rim": Color(0.93, 0.91, 0.86, 0.85), "size": 0.11, "rim_w": 0.55, "rag": 0.45},
	"glass": {"hole": Color(0.8, 0.88, 0.95, 0.4), "rim": Color(1.0, 1.0, 1.0, 0.55), "size": 0.09, "rim_w": 0.6, "rag": 0.95},
}
const SHATTERS: int = 4
const TOLL_RINGS: int = 2
const MODELS_PATH: String = "res://data/gravelight/weapons/models.json"
const VM_LAYER: int = 1 << 19
const TOLL_RING_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec2 center_uv = vec2(0.5, 0.5);
uniform float k = 0.0;          // 0 at birth -> 1 gone
uniform float strength = 0.06;
uniform vec4 tint : source_color = vec4(0.72, 0.42, 1.0, 1.0);
void fragment() {
	float r = length(UV - 0.5) * 2.0;        // 0 at the ring's centre, 1 at the mesh edge (the front of the ring)
	float band = smoothstep(0.62, 0.96, r) * smoothstep(1.0, 0.9, r);
	float fade = 1.0 - k;
	vec2 dir = SCREEN_UV - center_uv;
	float dl = length(dir);
	dir = dl > 0.0001 ? dir / dl : vec2(0.0);
	vec2 off = dir * band * strength * fade;
	vec3 c = texture(screen_tex, SCREEN_UV - off).rgb;
	c += tint.rgb * band * 0.45 * fade;
	ALBEDO = c;
	ALPHA = clamp(band * (0.7 + 0.3 * fade), 0.0, 1.0) * fade;
}
"""

var _impacts: Array[MeshInstance3D] = []
var _decal_mats: Dictionary = {}       # surface -> material (DECALS); "" = the plain dark mark
var _impact_life: Array[float] = []
var _dirt: Array[CPUParticles3D] = []    # the rise from the ground (T-085): snow / earth / stone sprays and puffs
var _dirt_meshes: Dictionary = {}        # surface class -> Mesh
var _ndirt: int = 0
var _tracers: Array[Node3D] = []
var _tracer_life: Array[float] = []
## T-128: each live tracer's flight: {from, dir, total, skip, speed, length, t}.
var _tracer_fly: Array[Dictionary] = []
## T-128: [core, glow] materials per tracer look (normal / upgraded), additive.
var _tracer_mats: Dictionary = {}
var _tracer_cfg: Dictionary = {}
var _statics: Array[Node3D] = []
var _static_life: Array[float] = []
var _ni: int = 0
var _nt: int = 0
var _ns: int = 0
var _holes: Dictionary = {}            # surface -> MultiMesh (persistent holes; "" = the plain mark)
var _hole_next: Dictionary = {}        # surface -> next slot
var _hole_used: Dictionary = {}        # surface -> Array of 0/1, 1 where a slot shows a hole (CPU-side count)
var _snow_life: PackedFloat32Array = PackedFloat32Array()
var _snow_alive: int = 0
var _scorches: Array[Decal] = []
var _nsc: int = 0
# ---- T-095
var vfx: Dictionary = {}                 # data/gravelight/vfx.json
var flash: FlashPool
var casings: CasingPool
var impact_fx: ImpactFx
var gore: GoreFx
var blast: BlastFx                       # T-280: every explosion (explosion())
var _shatters: Array[Node3D] = []
var _shatter_life: PackedFloat32Array = PackedFloat32Array()
var _nsh: int = 0
var _toll: Array[MeshInstance3D] = []
var _toll_life: PackedFloat32Array = PackedFloat32Array()
var _toll_mat: Array[ShaderMaterial] = []
var _toll_range: PackedFloat32Array = PackedFloat32Array()
var _toll_origin: Array[Vector3] = []
var _ntoll: int = 0
## The last shot by player id: {"weapon": StringName, "upgraded": bool, "frame": int} (the zombie-hit bridge: a hit
## reported in the same physics frame as an upgraded weapon's shot throws Nachtglas sparks until the holder passes
## the weapon itself, see zombie_hit()).
var _last_shot: Dictionary = {}
var _skip_bridge: bool = false
var _atmosphere: Node = null
## Flashes drawn / casings thrown (tests, the dev overlay).
var stats: Dictionary = {"flashes": 0, "casings": 0, "impacts": 0, "hits": 0, "shatters": 0, "tolls": 0}


func _ready() -> void:
	vfx = GLData.table("vfx")
	flash = FlashPool.new()
	flash.name = "Flash"
	flash.setup(vfx.get("flash", {}), int((vfx.get("smoke", {}) as Dictionary).get("slots", 6)))
	add_child(flash)
	casings = CasingPool.new()
	casings.name = "Casings"
	casings.setup(vfx.get("casings", {}), GLData.load_json(MODELS_PATH).get("extras", {}))
	add_child(casings)
	impact_fx = ImpactFx.new()
	impact_fx.name = "Impacts"
	impact_fx.setup(vfx.get("impacts", {}), vfx.get("hits", {}))
	add_child(impact_fx)
	gore = GoreFx.new()
	gore.name = "Gore"
	gore.setup(vfx.get("gore", {}))
	add_child(gore)
	_build_shatters()
	_build_toll_rings()
	if not GLBus.weapon_fired.is_connected(_on_weapon_fired):
		GLBus.weapon_fired.connect(_on_weapon_fired)
	if not GLBus.great_toll.is_connected(_on_great_toll):
		GLBus.great_toll.connect(_on_great_toll)
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
	_build_dirt()
	_build_tracers()
	blast = BlastFx.new()
	blast.name = "Blasts"
	blast.setup(vfx.get("blast", {}), _dirt_meshes)
	add_child(blast)
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
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
	for i: int in SHATTERS:
		if _shatter_life[i] > 0.0:
			_shatter_life[i] -= delta
			var k: float = clampf(_shatter_life[i] / 0.5, 0.0, 1.0)
			(_shatters[i].get_node("Light") as OmniLight3D).light_energy = k * k * 6.0
			if _shatter_life[i] <= 0.0:
				_shatters[i].hide()
	if _ntoll_live() > 0:
		_update_toll_rings(delta)
	for i: int in IMPACTS:
		if _impact_life[i] > 0.0:
			_impact_life[i] -= delta
			if _impact_life[i] <= 0.0:
				_impacts[i].hide()
	_tick_tracers(delta)
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
	stats["impacts"] = int(stats["impacts"]) + 1
	if impact_fx != null:
		impact_fx.burst(pos, normal, surface, particles_k())   # T-095: the per-surface debris
	var decal: String = surface
	if impact_fx != null and impact_fx.impacts.has(surface):
		decal = str((impact_fx.impacts[surface] as Dictionary).get("decal", surface))
	if decal == "" and surface != "":
		return   # cloth, earth: no mark
	surface = decal
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


## Blood from a wound at `pos`, the spray flying `toward` (gore-gated). A call in the same physics frame as a shot
## is that shot's hit (bots and soldiers report theirs this way, with `toward` pointing back at the shooter): the
## round goes through, and a Crucible-taught weapon throws Nachtglas sparks too. The local player's own hits come
## through zombie_hit(), which knows the weapon.
func blood(pos: Vector3, toward: Vector3) -> void:
	var through: bool = false
	var weapon: StringName = &""
	if not _skip_bridge:
		var frame: int = Engine.get_physics_frames()
		for pid: Variant in _last_shot.keys():
			var s: Dictionary = _last_shot[pid]
			if int(s.get("frame", -1)) == frame:
				through = true
				weapon = s.get("weapon", &"")
				if bool(s.get("upgraded", false)):
					nachtglas_spark(pos, toward)
				break
	stats["hits"] = int(stats["hits"]) + 1
	if not GoreFx.enabled():
		return   # the Gore setting (MZ, T-041): Off and Low show no blood
	gore.spray(pos, toward, weapon, through)


## Blood thrown from `pos` along `dir` by something that is not a bullet (a limb coming off, a neck): never read as
## a shot's hit. `heavy` adds bits of meat.
func gore_burst(pos: Vector3, dir: Vector3, heavy: bool = false) -> void:
	stats["hits"] = int(stats["hits"]) + 1
	if not GoreFx.enabled():
		return
	gore.spray(pos, dir, &"", false, heavy)   # a limb or a neck may reach the ceiling
	if heavy:
		gore.chunks(pos, dir, maxi(3, int(round(7.0 * particles_k() * gore.horde_k()))))


# ================================================================== the rise from the ground (T-085)

const DIRT: int = 24

## One pooled CPUParticles3D per burst (a 24-zombie horde rising at once reuses the oldest), with a clump mesh
## per surface class: snow flakes, earth clods, stone grit. Nothing is allocated per burst beyond the mesh swap.
func _build_dirt() -> void:
	var looks: Dictionary = {
		"snow": [Color(0.9, 0.93, 0.98), 0.05],
		"earth": [Color(0.2, 0.14, 0.09), 0.045],
		"stone": [Color(0.42, 0.4, 0.37), 0.04],
	}
	for kind: String in looks.keys():
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = (looks[kind] as Array)[0]
		m.roughness = 1.0
		var box: BoxMesh = BoxMesh.new()
		var s: float = float((looks[kind] as Array)[1])
		box.size = Vector3(s, s * 0.8, s)
		box.material = m
		_dirt_meshes[kind] = box
	for i: int in DIRT:
		var p: CPUParticles3D = CPUParticles3D.new()
		p.emitting = false
		p.one_shot = true
		p.amount = 14
		p.lifetime = 0.7
		p.explosiveness = 1.0
		p.mesh = _dirt_meshes["earth"]
		p.direction = Vector3.UP
		p.spread = 40.0
		p.initial_velocity_min = 1.8
		p.initial_velocity_max = 4.0
		p.gravity = Vector3(0, -9.0, 0)
		p.scale_amount_min = 0.6
		p.scale_amount_max = 1.6
		p.angular_velocity_min = -180.0
		p.angular_velocity_max = 180.0
		add_child(p)
		_dirt.append(p)


func _dirt_next(kind: String, amount: int) -> CPUParticles3D:
	var p: CPUParticles3D = _dirt[_ndirt]
	_ndirt = (_ndirt + 1) % DIRT
	var mesh: Mesh = _dirt_meshes.get(kind, _dirt_meshes["earth"])
	if p.mesh != mesh:
		p.mesh = mesh
	if p.amount != amount:
		p.amount = amount   # a resize; only when the count differs
	return p


## Ground thrown up at `pos` (a hand bursting through, the head tearing free, clumps off a shoulder): `kind` is
## the surface class (snow / earth / stone), `strength` scales the throw, `dir` the cone's axis.
func dirt_burst(pos: Vector3, kind: String, strength: float = 1.0, dir: Vector3 = Vector3.UP, amount: int = 14) -> void:
	var p: CPUParticles3D = _dirt_next(kind, maxi(1, amount))
	p.lifetime = 0.7
	p.spread = 40.0
	p.initial_velocity_min = 1.8 * strength
	p.initial_velocity_max = 4.0 * strength
	p.gravity = Vector3(0, -9.0, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	p.direction = dir.normalized() if dir.length_squared() > 0.001 else Vector3.UP
	p.global_position = pos
	p.global_basis = Basis.IDENTITY
	p.restart()
	p.emitting = true


## A low, slow puff at `pos` (the stagger step as it stands, a body sliding back into the hole): bigger, lighter
## grains that drift rather than fly.
func dust_puff(pos: Vector3, kind: String, amount: int = 10) -> void:
	var p: CPUParticles3D = _dirt_next(kind, maxi(1, amount))
	p.lifetime = 0.9
	p.spread = 80.0
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.2
	p.gravity = Vector3(0, -0.8, 0)
	p.scale_amount_min = 1.2
	p.scale_amount_max = 2.6
	p.direction = Vector3.UP
	p.global_position = pos
	p.global_basis = Basis.IDENTITY
	p.restart()
	p.emitting = true


## T-128 (the owner: "make sure ... tracers and hitmarkers feel satisfying"): a tracer is a short bright streak with a
## soft glow that flies from the muzzle to the hit at the class's visual speed and drains into the impact (it used to
## be a muzzle-to-hit line shown for 0.04 s). vfx.json "tracer": per-class length, width and speed; the first metres
## in front of your own camera are skipped so the streak never smears across the sights; a Crucible-taught gun's
## tracers burn violet (the Nachtglas). `cls` is the weapons.json class; `first_person` is the local shooter's own.
func tracer(from: Vector3, to: Vector3, upgraded: bool = false, cls: StringName = &"", first_person: bool = false) -> void:
	var cfg: Dictionary = _tracer_cfg
	var dist: float = from.distance_to(to)
	if dist < float(cfg.get("min_dist_m", 2.0)):
		return
	var look: Dictionary = (cfg.get("classes", {}) as Dictionary).get(String(cls), (cfg.get("classes", {}) as Dictionary).get("default", {}))
	var i: int = _nt
	_nt = (_nt + 1) % TRACERS
	var node: Node3D = _tracers[i]
	var mats: Array = _tracer_mats[&"upgraded" if upgraded else &"normal"]
	var core: MeshInstance3D = node.get_child(0)
	var glow: MeshInstance3D = node.get_child(1)
	core.material_override = mats[0]
	glow.material_override = mats[1]
	var w: float = float(look.get("width", 0.012))
	core.scale = Vector3(w, w, 1.0)
	var gw: float = w * float(cfg.get("glow_width_mult", 3.5))
	glow.scale = Vector3(gw, gw, 1.0)
	var alpha: float = float(look.get("alpha", 0.85))
	node.set_meta("alpha", alpha)
	var total: float = minf(dist, float(cfg.get("max_m", 160.0)))
	_tracer_fly[i] = {"from": from, "dir": (to - from) / dist, "total": total,
		"skip": minf(total * 0.5, float(cfg.get("first_person_skip_m" if first_person else "remote_skip_m", 0.5))),
		"speed": float(look.get("speed", cfg.get("speed", 380.0))), "length": float(look.get("length", 4.0)), "t": 0.0}
	_tracer_life[i] = 1.0
	node.hide()   # shown on its first tick, once it has a length


## The tracer pool: two stretched boxes per tracer (a hot core and a wider, fainter glow), additive and unshaded.
func _build_tracers() -> void:
	_tracer_cfg = (_cfg_table() as Dictionary).get("tracer", {})
	for key: StringName in [&"normal", &"upgraded"]:
		var col: Array = _tracer_cfg.get("upgraded_color" if key == &"upgraded" else "color", [1.0, 0.72, 0.38])
		var core_col: Array = _tracer_cfg.get("upgraded_core" if key == &"upgraded" else "core", [1.6, 1.35, 1.0])
		_tracer_mats[key] = [_tracer_mat(Color(float(core_col[0]), float(core_col[1]), float(core_col[2]), 1.0)),
			_tracer_mat(Color(float(col[0]), float(col[1]), float(col[2]), float(_tracer_cfg.get("glow_alpha", 0.28))))]
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3.ONE
	for i: int in TRACERS:
		var node: Node3D = Node3D.new()
		node.name = "Tracer"
		for part: String in ["Core", "Glow"]:
			var mi: MeshInstance3D = MeshInstance3D.new()
			mi.name = part
			mi.mesh = box
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			node.add_child(mi)
		node.hide()
		add_child(node)
		_tracers.append(node)
		_tracer_life.append(0.0)
		_tracer_fly.append({})


func _cfg_table() -> Dictionary:
	return GLData.table("vfx")


static func _tracer_mat(c: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.no_depth_test = false
	m.disable_receive_shadows = true
	m.disable_fog = true
	return m


## Flies every live tracer: the head runs out at its speed and stops at the hit; the tail follows `length` behind
## and drains into the hit; the streak fades over its last stretch.
func _tick_tracers(delta: float) -> void:
	for i: int in TRACERS:
		if _tracer_life[i] <= 0.0:
			continue
		var f: Dictionary = _tracer_fly[i]
		f["t"] = float(f["t"]) + delta
		var run: float = float(f["speed"]) * float(f["t"])
		var total: float = float(f["total"])
		var head: float = minf(run, total)
		var tail: float = maxf(float(f["skip"]), run - float(f["length"]))
		var node: Node3D = _tracers[i]
		if tail >= total - 0.02:
			_tracer_life[i] = 0.0
			node.hide()
			continue
		var seg: float = head - tail
		if seg < 0.02:
			node.hide()
			continue
		var dir: Vector3 = f["dir"]
		var from: Vector3 = f["from"]
		var mid: Vector3 = from + dir * ((head + tail) * 0.5)
		var up: Vector3 = Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
		node.global_transform = Transform3D(Basis.looking_at(dir, up), mid)
		for c: Node in node.get_children():
			var mi: MeshInstance3D = c as MeshInstance3D
			mi.scale.z = seg
		# fade in over the first metre it shows, out as it drains into the hit
		var a: float = float(node.get_meta("alpha", 0.85)) * clampf(seg / minf(1.0, float(f["length"])), 0.0, 1.0)
		for c2: Node in node.get_children():
			(c2 as GeometryInstance3D).transparency = 1.0 - a
		node.show()


## An explosion at `pos` with the damage radius `radius` (presentation only: the damage is the caller's). T-280:
## BlastFx draws and sounds it (flash, light, fireball rolling into smoke, the ground thrown up, debris, sparks and
## embers, the dust ring, camera shake, a near flash and blur, a crack, a late far rumble and a debris patter),
## pooled and prewarmed. `kind` picks the look: "small" (a pop), "grenade", "shell", "bomb" (vfx.json blast.kinds);
## "" (the old two-argument call) picks it from the radius. A blast big enough leaves a scorch mark.
func explosion(pos: Vector3, radius: float, kind: String = "") -> void:
	if radius >= SCORCH_MIN_RADIUS:
		scorch(pos, radius)
	if blast != null:
		blast.blast(pos, radius, kind, quality(), particles_k())


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
		var used: Array = []
		used.resize(HOLES_PER_SURFACE)
		used.fill(0)
		_hole_used[surf] = used
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
	(_hole_used[surface] as Array)[i] = 1
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
			(_hole_used["snow"] as Array)[i] = 0
		elif l < 2.0:
			mm.set_instance_color(i, Color(1, 1, 1, l * 0.5))


## How many persistent holes are showing (tests and the dev overlay).
func persistent_hole_count() -> int:
	var n: int = 0
	for surf: String in _hole_used.keys():
		for u: Variant in (_hole_used[surf] as Array):
			n += int(u)
	return n


func _build_scorches() -> void:
	# T-280: the soot mark is a drawn texture (gen_blast_textures.py: a black heart, burnt spokes, a ragged rim)
	var tex: Texture2D = load(BlastFx.TEX_DIR + "blast_scorch.png") as Texture2D
	if tex == null:
		tex = _scorch_texture()
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
	var w: float = clampf(radius * 0.9, 1.2, 4.0) * randf_range(0.9, 1.15)
	d.size = Vector3(w, 2.4, w)
	d.global_position = pos + Vector3(0, 0.6, 0)
	d.rotation = Vector3(0, randf() * TAU, 0)
	d.modulate = Color(1, 1, 1, clampf(0.75 + radius * 0.04, 0.75, 0.95))
	d.show()


func scorch_count() -> int:
	var n: int = 0
	for d: Decal in _scorches:
		if d.visible:
			n += 1
	return n


## A new match: every persistent hole, scorch and bloodstain goes.
func clear_marks() -> void:
	if gore != null:
		gore.clear()
	for surf: String in _holes.keys():
		var mm: MultiMesh = _holes[surf]
		for i: int in HOLES_PER_SURFACE:
			mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
		_hole_next[surf] = 0
		(_hole_used[surf] as Array).fill(0)
	_snow_life.fill(0.0)
	_snow_alive = 0
	for d: Decal in _scorches:
		d.hide()
	if blast != null:
		blast.clear()
	for i: int in IMPACTS:
		_impact_life[i] = 0.0
		_impacts[i].hide()


func _on_match_started(_map_id: StringName) -> void:
	clear_marks()
	if blast != null:
		blast.warm()   # T-280: the blast's shaders compile while the map loads, not on the first grenade
	_attach_atmosphere.call_deferred()   # T-095: the map is in the tree by then (MapRoot._ready emits match_started)


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


# ================================================================== UPDATE 05 section 6 (T-095)

## The quality row for GLSettings "vfx_quality" (low / medium / high; unknown = high).
func quality() -> Dictionary:
	var q: Dictionary = vfx.get("quality", {})
	var key: String = str(GLSettings.values.get("vfx_quality", "high"))
	return (q.get(key, q.get("high", {})) as Dictionary)


## The particle-count multiplier of the current quality.
func particles_k() -> float:
	# T-139: halved on the Compatibility renderer (the browser build's WebProfile)
	return float(quality().get("particles", 1.0)) * (WebProfile.PARTICLE_RATIO if GLSettings.is_compat() else 1.0)


# ---- muzzle flashes

## A muzzle flash at `pos` along `dir` for `weapon_id` (the class comes from weapons.json; upgraded ids resolve
## through their base). `scale` grows third-person flashes a little; `with_light` false skips the pooled light
## pulse (the local viewmodel already has its own flash light).
func muzzle_flash(pos: Vector3, dir: Vector3, weapon_id: StringName, upgraded: bool, scale: float = 1.0, with_light: bool = true) -> void:
	if flash == null:
		return
	var cls: String = weapon_class_of(weapon_id)
	var q: Dictionary = quality()
	if not with_light:
		q = q.duplicate()
		q["flash_lights"] = 0
	flash.fire(pos, dir, cls, upgraded, scale, q)
	stats["flashes"] = int(stats["flashes"]) + 1


## The weapon class of a weapon id (an upgraded id through its base row), "rifle" when unknown.
static func weapon_class_of(weapon_id: StringName) -> String:
	var t: Dictionary = GLData.table("weapons")
	var id: String = String(weapon_id)
	var rows: Dictionary = t.get("weapons", {})
	if rows.has(id):
		return str((rows[id] as Dictionary).get("class", "rifle"))
	var up: Dictionary = t.get("upgraded", {})
	if up.has(id):
		var row: Dictionary = up[id]
		if row.has("class"):
			return str(row["class"])
		var base: String = str(row.get("base", ""))
		if rows.has(base):
			return str((rows[base] as Dictionary).get("class", "rifle"))
	return "rifle"


## Every trigger pull (GLBus.weapon_fired): resolve where the muzzle really is and draw the class flash there.
## The local human's own gun: its viewmodel muzzle (wall-clamped, the holder's _muzzle_world), and when
## vfx.json flash.first_person is "effects" the holder's own star is suppressed through the "size" meta it reads
## (its flash light stays: no pooled light is spent on it). A bot or remote teammate: its RemoteBody's "Muzzle"
## (its own flash is hidden, since it was shown just before this signal). Anyone else: the shot origin.
func _on_weapon_fired(player: int, weapon_id: StringName, upgraded: bool, origin: Vector3, direction: Vector3) -> void:
	_last_shot[player] = {"weapon": weapon_id, "upgraded": upgraded, "frame": Engine.get_physics_frames()}
	var cls: String = weapon_class_of(weapon_id)
	if flash == null or not flash.has_class(cls):
		return
	var fp_effects: bool = str((vfx.get("flash", {}) as Dictionary).get("first_person", "effects")) == "effects"
	var p: Node3D = player_node(player)
	var pos: Vector3 = origin + direction * 0.55 - Vector3.UP * 0.12
	var dir: Vector3 = direction
	var scale: float = 1.0
	var with_light: bool = true
	if p != null:
		if bool(p.get("is_local")) and not bool(p.get("is_bot")):
			var holder: Node = p.get("weapons") as Node
			if holder != null and holder.has_method("_muzzle_world"):
				var mx: Transform3D = holder.call("_muzzle_world")
				pos = mx.origin
				dir = -mx.basis.z
				with_light = false   # the holder's own flash light already pulses
				if fp_effects:
					var fm: Node = holder.get("_flash_mesh") as Node
					if fm != null and is_instance_valid(fm):
						fm.set_meta("size", 0.0)   # the holder scales its star by this: zero = the world flash alone
						if fm is Node3D:
							(fm as Node3D).hide()
				else:
					return   # the holder draws the first-person flash itself
		else:
			var body: Node = p.get("remote_body") as Node
			if body != null and is_instance_valid(body):
				var mz: Node3D = body.get("_muzzle") as Node3D
				if mz != null and is_instance_valid(mz):
					pos = mz.global_position
					var gun: Node3D = body.get("_gun") as Node3D
					if gun != null and is_instance_valid(gun):
						dir = -gun.global_basis.z
				scale = 1.3
				var bf: Node = body.get("_flash") as Node
				if bf is Node3D and is_instance_valid(bf):
					(bf as Node3D).hide()
				var bl: Node = body.get("_flash_light") as Node
				if bl is Light3D and is_instance_valid(bl):
					(bl as Light3D).light_energy = 0.0
	muzzle_flash(pos, dir, weapon_id, upgraded, scale, with_light)


## The Player node for an id (the "players" group), or null.
static func player_node(player: int) -> Node3D:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	for n: Node in tree.get_nodes_in_group(&"players"):
		if int(n.get("player_id")) == player:
			return n as Node3D
	return null


# ---- casings

## Throws the cartridge model for `weapon_id` (or the holder's `kind`: pistol / rifle / shell) from `from`.
func casing(kind: String, from: Vector3, vel: Vector3, basis: Basis, weapon_id: StringName = &"") -> void:
	if casings == null:
		return
	if weapon_id == &"":
		weapon_id = _local_weapon_id()
	casings.eject(casings.node_for(weapon_id, kind), from, vel, basis, float(quality().get("casings", 1.0)))
	stats["casings"] = int(stats["casings"]) + 1


## The weapon the local human is holding (GunFx.eject does not know the weapon; only the local viewmodel ejects).
func _local_weapon_id() -> StringName:
	var tree: SceneTree = get_tree()
	if tree == null:
		return &""
	for n: Node in tree.get_nodes_in_group(&"players"):
		if bool(n.get("is_local")) and not bool(n.get("is_bot")):
			var holder: Node = n.get("weapons") as Node
			if holder != null and holder.has_method("current"):
				var w: Variant = holder.call("current")
				if w != null:
					return StringName(str(w.get("id")))
	return &""


# ---- smoke, hits, shatter

## A muzzle smoke puff at `at` drifting along `dir` (the holder's bolt / shotgun smoke; the flash's own wisp is smaller).
func muzzle_smoke(at: Vector3, dir: Vector3, strength: float = 1.0) -> void:
	if flash == null or flash._smoke.is_empty() or not bool(quality().get("smoke", true)):
		return
	var p: CPUParticles3D = flash._smoke[flash._nsmoke]
	flash._nsmoke = (flash._nsmoke + 1) % flash._smoke.size()
	var amount: int = clampi(int((4.0 + 4.0 * strength) * particles_k()), 2, 10)
	if p.amount != amount:
		p.amount = amount
	p.initial_velocity_max = 0.7 + 0.8 * strength
	p.global_position = at
	var f: Vector3 = dir.normalized() if dir.length_squared() > 0.0001 else Vector3.FORWARD
	p.global_basis = Basis.looking_at(-f, Vector3.UP if absf(f.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT)
	p.restart()
	p.emitting = true


## A bullet hit on a zombie at `pos`, the spray flying `toward`: blood (gore-gated) plus, from a Crucible-taught
## weapon, the violet Nachtglas spark burst. The proper hook for WeaponHolder._trace (see the TODO at the top).
func zombie_hit(pos: Vector3, toward: Vector3, weapon_id: StringName, upgraded: bool) -> void:
	if upgraded:
		nachtglas_spark(pos, toward)
	stats["hits"] = int(stats["hits"]) + 1
	if GoreFx.enabled():
		gore.spray(pos, toward, weapon_id, true)   # the weapon's class decides what it leaves (vfx.json gore.classes)


## Violet-teal glints at `pos` flying `toward` (Nachtglas: a taught weapon's hit, a Glasshide's crystal plates).
func nachtglas_spark(pos: Vector3, toward: Vector3) -> void:
	if impact_fx != null:
		impact_fx.nachtglas(pos, toward)


func _build_shatters() -> void:
	var piece: PrismMesh = PrismMesh.new()
	piece.size = Vector3(0.05, 0.09, 0.025)
	var pm: StandardMaterial3D = StandardMaterial3D.new()
	pm.albedo_color = Color(1, 1, 1, 0.85)
	pm.vertex_color_use_as_albedo = true
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.roughness = 0.12
	pm.metallic_specular = 1.0
	pm.emission_enabled = true
	pm.emission = Color(0.6, 0.4, 1.0)
	pm.emission_energy_multiplier = 1.6
	piece.material = pm
	var flash_mesh: SphereMesh = SphereMesh.new()
	flash_mesh.radius = 0.5
	flash_mesh.height = 1.0
	for i: int in SHATTERS:
		var root: Node3D = Node3D.new()
		root.name = "Shatter%d" % i
		var p: CPUParticles3D = CPUParticles3D.new()
		p.name = "Pieces"
		p.emitting = false
		p.one_shot = true
		p.amount = 40
		p.lifetime = 0.9
		p.explosiveness = 1.0
		p.mesh = piece
		p.direction = Vector3.UP
		p.spread = 80.0
		p.initial_velocity_min = 2.4
		p.initial_velocity_max = 6.0
		p.gravity = Vector3(0, -9.0, 0)
		p.angular_velocity_min = -720.0
		p.angular_velocity_max = 720.0
		p.scale_amount_min = 0.5
		p.scale_amount_max = 1.3
		var g: Gradient = Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.7, Color(1, 1, 1, 1))
		p.color_ramp = g
		p.local_coords = false
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(p)
		var core: MeshInstance3D = MeshInstance3D.new()
		core.name = "Core"
		core.mesh = flash_mesh
		var cm: StandardMaterial3D = StandardMaterial3D.new()
		cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		cm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		cm.albedo_color = Color(0.7, 0.45, 1.0, 0.6)
		core.material_override = cm
		core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(core)
		var l: OmniLight3D = OmniLight3D.new()
		l.name = "Light"
		l.light_color = Color(0.65, 0.35, 1.0)
		l.omni_range = 7.0
		l.shadow_enabled = false
		l.light_energy = 0.0
		root.add_child(l)
		root.hide()
		add_child(root)
		_shatters.append(root)
		_shatter_life.append(0.0)


## A burst of crystal shards and a violet flash at `pos` (a Glasshide shattering, a Bellringer's lantern, a
## portal): `color` tints the pieces, `amount` and `speed` size the burst. Pooled; the hook for Zombie._shards.
func shatter(pos: Vector3, color: Color = Color(0.6, 0.3, 1.0), amount: int = 40, speed: float = 6.0) -> void:
	var b: Node3D = _shatters[_nsh]
	_shatter_life[_nsh] = 0.5
	_nsh = (_nsh + 1) % SHATTERS
	stats["shatters"] = int(stats["shatters"]) + 1
	b.global_position = pos
	b.show()
	var p: CPUParticles3D = b.get_node("Pieces")
	var want: int = clampi(int(round(float(amount) * particles_k())), 6, 60)
	if p.amount != want:
		p.amount = want
	p.color = color
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.restart()
	p.emitting = true
	var core: MeshInstance3D = b.get_node("Core")
	(core.material_override as StandardMaterial3D).albedo_color = Color(color.lightened(0.2), 0.6)
	core.scale = Vector3.ONE * clampf(speed * 0.12, 0.4, 1.2)
	(b.get_node("Light") as OmniLight3D).light_color = color
	(b.get_node("Light") as OmniLight3D).light_energy = 6.0
	var tw: Tween = core.create_tween()   # the core flash dies with the light
	tw.tween_property(core, "scale", Vector3.ONE * 0.05, 0.3).set_ease(Tween.EASE_IN)


# ---- the Totenglocke's Great Toll ring

func _build_toll_rings() -> void:
	var sh: Shader = Shader.new()
	sh.code = TOLL_RING_SHADER
	var disc: PlaneMesh = PlaneMesh.new()
	disc.size = Vector2(2.0, 2.0)
	var tr: Dictionary = vfx.get("toll_ring", {})
	var col: Array = tr.get("color", [0.72, 0.42, 1.0])
	for i: int in TOLL_RINGS:
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "TollRing%d" % i
		mi.mesh = disc
		var m: ShaderMaterial = ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("strength", float(tr.get("strength", 0.035)))
		m.set_shader_parameter("tint", Color(float(col[0]), float(col[1]), float(col[2])))
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.custom_aabb = AABB(Vector3(-60, -5, -60), Vector3(120, 10, 120))
		mi.hide()
		add_child(mi)
		_toll.append(mi)
		_toll_mat.append(m)
		_toll_life.append(0.0)
		_toll_range.append(10.0)
		_toll_origin.append(Vector3.ZERO)


## The Great Toll's refraction ring: a flat disc racing out from `origin` to `range_m` over the ring's seconds,
## bending what is behind its rim (a screen-texture spatial shader) with a violet glow. World-space, so a
## teammate's toll shows too. Hooked on GLBus.great_toll.
func toll_ring(origin: Vector3, range_m: float) -> void:
	var i: int = _ntoll
	_ntoll = (_ntoll + 1) % TOLL_RINGS
	stats["tolls"] = int(stats["tolls"]) + 1
	_toll_life[i] = float((vfx.get("toll_ring", {}) as Dictionary).get("seconds", 0.55))
	_toll_range[i] = maxf(2.0, range_m)
	_toll_origin[i] = origin
	var mi: MeshInstance3D = _toll[i]
	mi.global_transform = Transform3D(Basis.IDENTITY, origin + Vector3.UP * 0.9)
	mi.scale = Vector3.ONE * 0.2
	_toll_mat[i].set_shader_parameter("k", 0.0)
	mi.show()


func _on_great_toll(_player: int, origin: Vector3, _direction: Vector3, range_m: float) -> void:
	toll_ring(origin, range_m)


func _ntoll_live() -> int:
	var n: int = 0
	for i: int in TOLL_RINGS:
		if _toll_life[i] > 0.0:
			n += 1
	return n


func _update_toll_rings(delta: float) -> void:
	var total: float = float((vfx.get("toll_ring", {}) as Dictionary).get("seconds", 0.55))
	var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() != null else null
	for i: int in TOLL_RINGS:
		if _toll_life[i] <= 0.0:
			continue
		_toll_life[i] -= delta
		if _toll_life[i] <= 0.0:
			_toll[i].hide()
			continue
		var k: float = 1.0 - clampf(_toll_life[i] / total, 0.0, 1.0)   # 0 -> 1
		var grow: float = 1.0 - (1.0 - k) * (1.0 - k)
		var r: float = maxf(0.2, _toll_range[i] * grow)
		_toll[i].scale = Vector3(r, 1.0, r)
		_toll_mat[i].set_shader_parameter("k", k)
		if cam != null and not cam.is_position_behind(_toll_origin[i]):
			var vp: Vector2 = get_viewport().get_visible_rect().size
			var uv: Vector2 = cam.unproject_position(_toll_origin[i]) / Vector2(maxf(1.0, vp.x), maxf(1.0, vp.y))
			_toll_mat[i].set_shader_parameter("center_uv", uv)


# ---- surfaces

## What a bullet hit is made of, for decals and debris: the collider's (or its parent's) "surface" meta, then the
## vfx.json surfaces.name_hints table against the collider's and its parent's names, then by map and facing: open
## ground (nothing above it) is the map's open-ground surface, other floors the map's floor default, walls the
## map's wall default. (The maps' static meshes are merged at generation, so the colliders carry no material.)
static func surface_of(collider: Object, at: Vector3, normal: Vector3, space: PhysicsDirectSpaceState3D) -> String:
	var n: Node = collider as Node
	var s: Dictionary = GLData.table("vfx").get("surfaces", {})
	var map_id: String = String(GameState.map_id)
	var wall: String = str((s.get("wall_default", {}) as Dictionary).get(map_id, "stone"))
	if n == null:
		return wall
	for k: Node in [n, n.get_parent()]:
		if k != null and k.has_meta("surface"):
			return str(k.get_meta("surface"))
	if n is AnimatableBody3D:
		return "metal"
	var names: Array[String] = [String(n.name).to_lower()]
	if n.get_parent() != null and n.get_parent().get_script() == null:
		names.append(String(n.get_parent().name).to_lower())
	for nm: String in names:
		if nm.begins_with("ground"):
			if space != null:
				var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.3, at + Vector3.UP * 10.0, 1)
				if space.intersect_ray(q).is_empty():
					return str((s.get("open_ground", {}) as Dictionary).get(map_id, "snow"))
			return str((s.get("floor_default", {}) as Dictionary).get(map_id, "stone"))
		for pair: Variant in (s.get("name_hints", []) as Array):
			var h: Array = pair
			if nm.contains(str(h[0])):
				return str(h[1])
	if absf(normal.y) > 0.6:
		return str((s.get("floor_default", {}) as Dictionary).get(map_id, "stone"))
	return wall


# ---- atmosphere

## At match start: wipe the marks (above) and attach the atmosphere pass to the map once it is in the tree.
func _attach_atmosphere() -> void:
	if _atmosphere != null and is_instance_valid(_atmosphere):
		_atmosphere.queue_free()
	_atmosphere = null
	var dir_node: Node = get_tree().get_first_node_in_group(&"director")
	var map: Node3D = dir_node.get_parent() as Node3D if dir_node != null else null
	if map == null:
		return
	_atmosphere = VfxAtmosphere.attach(map, vfx.get("atmosphere", {}))


func atmosphere() -> Node:
	return _atmosphere if _atmosphere != null and is_instance_valid(_atmosphere) else null
