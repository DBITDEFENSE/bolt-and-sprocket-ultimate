class_name BlastFx
extends Node3D
## T-280 (the owner: "make explosions better more detailed", and "game should never go under 60 fps"): what a high
## explosive blast looks and sounds like, scaled by its kind and radius. Owned by Effects; every blast goes through
## Effects.explosion(pos, radius, kind), which hands it here. Data: data/gravelight/vfx.json "blast".
##
## One blast is: a white-hot flash (a camera-facing sprite) and one short-lived omni light with no shadow; a fireball
## whose puffs burn for a moment and roll on as dark smoke; a column of smoke that rises and drifts for a few
## seconds; dirt, snow or grit thrown up in a plume by whatever it went off on, chunks of it flying in arcs; sparks
## and slow embers; a ring of dust racing out along the ground and a low dust skirt; the scorch mark (Effects); a
## camera shake and, close by, a short flash and blur on the screen; a layered sound (a crack and a debris patter
## close to it, a rumble that arrives late far from it). A blast under SMALL_RADIUS is a small pop: flash, sparks,
## one puff, nothing thrown up, no smoke column.
##
## Cost (a hard rule of the order): everything is built once in setup() at game start: SLOTS blast slots, each a
## Node3D holding the emitters (GPUParticles3D) and two sprites, LIGHTS pooled lights. All slots share one process
## material per emitter kind and one draw material per look (the per-blast differences are instance uniforms, node
## scale, amount_ratio and speed_scale), so a blast allocates no node, material or resource and compiles nothing:
## it sets transforms and properties and restarts the emitters. warm() shows one tiny invisible blast in front of
## the camera when a match starts, so the shaders and pipelines are compiled during the load, not by the first
## grenade. When every slot is busy the oldest is reused; at most quality.blast_lights lights burn at once (the
## weakest is taken over). Particle counts follow Effects.particles_k() (vfx_quality, halved on Compatibility).

const SLOTS: int = 8
const LIGHTS: int = 4
const SMALL_RADIUS: float = 1.5
const PENDING: int = 16                 # delayed sounds (the far rumble, the debris patter)
const SPEED_OF_SOUND: float = 343.0
const VM_LAYER: int = 1 << 19           # the viewmodel's layer: a blast light does not light the gun in your hands
const TEX_DIR: String = "res://assets/ours/vfx/blast/"
## The emitters of a slot, in build order.
const EMITTERS: PackedStringArray = ["Fire", "Smoke", "Spray", "Skirt", "Debris", "Sparks", "Embers"]
## The emitters that need ground under the blast (an air burst throws no dirt).
const GROUND_PARTS: PackedStringArray = ["Spray", "Skirt", "Debris"]
## Surface (Effects.surface_of) -> the dirt kind thrown up (Effects.dirt_burst's kinds).
const DIRT_OF: Dictionary = {"snow": "snow", "earth": "earth", "hay": "earth", "mud": "earth", "grass": "earth",
	"cloth": "earth", "wood": "stone", "stone": "stone", "metal": "stone", "plaster": "stone", "glass": "stone"}
## Dirt kind -> [thrown dirt colour, dust colour].
const DUST: Dictionary = {
	"snow": [Color(0.86, 0.89, 0.94), Color(0.82, 0.85, 0.9, 0.55)],
	"earth": [Color(0.2, 0.15, 0.1), Color(0.42, 0.36, 0.29, 0.6)],
	"stone": [Color(0.4, 0.38, 0.35), Color(0.55, 0.53, 0.5, 0.55)],
}

var cfg: Dictionary = {}
var _slots: Array[Node3D] = []
var _em: Array[Dictionary] = []          # slot -> {emitter name -> GPUParticles3D}
var _flash: Array[MeshInstance3D] = []
var _ring: Array[MeshInstance3D] = []
var _age: PackedFloat32Array = PackedFloat32Array()     # seconds since the slot's blast, -1 = free
var _life: PackedFloat32Array = PackedFloat32Array()    # how long the slot stays shown
var _flash_t: PackedFloat32Array = PackedFloat32Array() # the flash's length
var _ring_t: PackedFloat32Array = PackedFloat32Array()
var _born: PackedInt32Array = PackedInt32Array()        # blast serial (the oldest slot is reused)
var _light_of: PackedInt32Array = PackedInt32Array()    # slot -> light or -1
var _lights: Array[OmniLight3D] = []
var _light_slot: PackedInt32Array = PackedInt32Array()  # light -> slot or -1
var _light_peak: PackedFloat32Array = PackedFloat32Array()
var _dirt_mesh: Dictionary = {}          # dirt kind -> Mesh (the debris chunks)
var _serial: int = 0
var _live: int = 0
var _pend_key: PackedStringArray = PackedStringArray()
var _pend_pos: PackedVector3Array = PackedVector3Array()
var _pend_db: PackedFloat32Array = PackedFloat32Array()
var _pend_t: PackedFloat32Array = PackedFloat32Array()
var _npend: int = 0
var _warm_left: int = 0
var screen: BlastScreen
## Counters for tests and the dev overlay.
var stats: Dictionary = {"blasts": 0, "small": 0, "lights": 0, "warmed": 0, "sounds": 0, "ground": 0}
## Tests: the last blast's resolved look {kind, scale, ratio, ground, dirt, light, shake, ...}.
var last: Dictionary = {}


func setup(c: Dictionary, dirt_meshes: Dictionary) -> void:
	cfg = c
	_dirt_mesh = dirt_meshes
	var puff_tex: Texture2D = load(TEX_DIR + "blast_puff.png") as Texture2D
	var puff_mat: ShaderMaterial = ShaderMaterial.new()
	puff_mat.shader = load(TEX_DIR + "blast_puff.gdshader") as Shader
	puff_mat.set_shader_parameter("puff_tex", puff_tex)
	var puff_mesh: QuadMesh = QuadMesh.new()
	puff_mesh.size = Vector2.ONE
	puff_mesh.material = puff_mat
	var spark_mat: StandardMaterial3D = StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	spark_mat.vertex_color_use_as_albedo = true
	spark_mat.disable_receive_shadows = true
	spark_mat.disable_fog = true
	var spark_mesh: BoxMesh = BoxMesh.new()
	spark_mesh.size = Vector3(0.022, 0.42, 0.022)
	spark_mesh.material = spark_mat
	var ember_mesh: BoxMesh = BoxMesh.new()
	ember_mesh.size = Vector3(0.035, 0.07, 0.035)
	ember_mesh.material = spark_mat
	var pm: Dictionary = {
		"Fire": _pm_fire(), "Smoke": _pm_smoke(), "Spray": _pm_spray(), "Skirt": _pm_skirt(),
		"Debris": _pm_debris(), "Sparks": _pm_sparks(), "Embers": _pm_embers(),
	}
	var amounts: Dictionary = c.get("amounts", {})
	var lifetimes: Dictionary = c.get("lifetimes", {})
	var flash_mat: ShaderMaterial = ShaderMaterial.new()
	flash_mat.shader = load(TEX_DIR + "blast_flash.gdshader") as Shader
	var flash_mesh: QuadMesh = QuadMesh.new()
	flash_mesh.size = Vector2.ONE
	var ring_mat: ShaderMaterial = ShaderMaterial.new()
	ring_mat.shader = load(TEX_DIR + "blast_ring.gdshader") as Shader
	var ring_mesh: PlaneMesh = PlaneMesh.new()
	ring_mesh.size = Vector2(2, 2)
	for i: int in SLOTS:
		var root: Node3D = Node3D.new()
		root.name = "Blast%d" % i
		var ems: Dictionary = {}
		for nm: String in EMITTERS:
			var p: GPUParticles3D = GPUParticles3D.new()
			p.name = nm
			p.process_material = pm[nm]
			p.amount = int(amounts.get(nm, 16))
			p.lifetime = float(lifetimes.get(nm, 1.5))
			p.one_shot = true
			p.emitting = false
			p.explosiveness = 0.72 if nm == "Smoke" else 1.0
			p.local_coords = false
			p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			p.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			p.visibility_aabb = AABB(Vector3(-10, -3, -10), Vector3(20, 26, 20))
			match nm:
				"Sparks":
					p.draw_pass_1 = spark_mesh
				"Embers":
					p.draw_pass_1 = ember_mesh
				"Debris":
					p.draw_pass_1 = dirt_meshes.get("earth")
					p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				_:
					p.draw_pass_1 = puff_mesh
			# every instance uniform this emitter will ever take, set now (the first set of a key allocates)
			if p.draw_pass_1 == puff_mesh:
				p.set_instance_shader_parameter(&"tint", Color(0.13, 0.12, 0.11, 1.0))
				p.set_instance_shader_parameter(&"heat", 0.0)
				p.set_instance_shader_parameter(&"burn", 0.2)
			p.hide()
			root.add_child(p)
			ems[nm] = p
		var fl: MeshInstance3D = MeshInstance3D.new()
		fl.name = "Flash"
		fl.mesh = flash_mesh
		fl.material_override = flash_mat
		fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fl.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		fl.set_instance_shader_parameter(&"k", 0.0)
		fl.set_instance_shader_parameter(&"seed", 0.0)
		fl.hide()
		root.add_child(fl)
		var rg: MeshInstance3D = MeshInstance3D.new()
		rg.name = "Ring"
		rg.mesh = ring_mesh
		rg.material_override = ring_mat
		rg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rg.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		rg.set_instance_shader_parameter(&"k", 1.0)
		rg.set_instance_shader_parameter(&"tint", Color(0.5, 0.45, 0.4, 0.6))
		rg.hide()
		root.add_child(rg)
		root.hide()
		add_child(root)
		_slots.append(root)
		_em.append(ems)
		_flash.append(fl)
		_ring.append(rg)
		_age.append(-1.0)
		_life.append(0.0)
		_flash_t.append(0.1)
		_ring_t.append(0.5)
		_born.append(0)
		_light_of.append(-1)
	for i: int in LIGHTS:
		var l: OmniLight3D = OmniLight3D.new()
		l.name = "BlastLight%d" % i
		l.light_color = Color(1.0, 0.62, 0.3)
		l.shadow_enabled = false
		l.omni_attenuation = 1.6
		l.light_energy = 0.0
		l.light_cull_mask = 0xFFFFF & ~VM_LAYER
		l.light_specular = 0.2
		l.hide()
		add_child(l)
		_lights.append(l)
		_light_slot.append(-1)
		_light_peak.append(0.0)
	_pend_key.resize(PENDING)
	_pend_pos.resize(PENDING)
	_pend_db.resize(PENDING)
	_pend_t.resize(PENDING)
	_pend_t.fill(-1.0)
	screen = BlastScreen.new()
	screen.name = "BlastScreen"
	screen.setup(load(TEX_DIR + "blast_screen.gdshader") as Shader)
	add_child(screen)
	set_process(false)


# ================================================================== the process materials (built once, shared)

static func _curve(points: Array) -> CurveTexture:
	var c: Curve = Curve.new()
	c.max_value = 4.0
	for pt: Variant in points:
		c.add_point(pt as Vector2)
	var t: CurveTexture = CurveTexture.new()
	t.curve = c
	return t


static func _ramp(stops: Array) -> GradientTexture1D:
	var offs: PackedFloat32Array = PackedFloat32Array()
	var cols: PackedColorArray = PackedColorArray()
	for s: Variant in stops:
		var a: Array = s
		offs.append(float(a[0]))
		cols.append(a[1] as Color)
	var g: Gradient = Gradient.new()
	g.offsets = offs
	g.colors = cols
	var t: GradientTexture1D = GradientTexture1D.new()
	t.gradient = g
	t.width = 64
	return t


static func _base(spread: float, vmin: float, vmax: float, gravity: Vector3) -> ParticleProcessMaterial:
	var m: ParticleProcessMaterial = ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.3
	m.direction = Vector3.UP
	m.spread = spread
	m.initial_velocity_min = vmin
	m.initial_velocity_max = vmax
	m.gravity = gravity
	return m


## The fireball: puffs flung out in every direction that stop short (heavy damping), swell, rise a little (hot air)
## and turn from fire to dark smoke (the puff shader, by age).
static func _pm_fire() -> ParticleProcessMaterial:
	var m: ParticleProcessMaterial = _base(180.0, 2.5, 7.5, Vector3(0, 1.6, 0))
	m.emission_sphere_radius = 0.45
	m.damping_min = 5.0
	m.damping_max = 9.0
	m.scale_min = 1.3
	m.scale_max = 2.4
	m.scale_curve = _curve([Vector2(0.0, 0.35), Vector2(0.12, 1.0), Vector2(1.0, 1.5)])
	m.angle_min = -180.0
	m.angle_max = 180.0
	m.angular_velocity_min = -25.0
	m.angular_velocity_max = 25.0
	m.anim_offset_max = 1.0
	m.lifetime_randomness = 0.35
	m.color_ramp = _ramp([[0.0, Color(1, 1, 1, 1.0)], [0.55, Color(1, 1, 1, 0.8)], [1.0, Color(1, 1, 1, 0.0)]])
	return m


## The column: dark smoke pushed up out of the fireball over its first half second, rising on its own heat, swelling
## and drifting downwind (the shared gravity's sideways part) as it thins out over a few seconds.
static func _pm_smoke() -> ParticleProcessMaterial:
	var m: ParticleProcessMaterial = _base(24.0, 1.5, 4.2, Vector3(0.35, 0.75, 0.16))
	m.emission_sphere_radius = 0.7
	m.damping_min = 0.7
	m.damping_max = 1.4
	m.scale_min = 1.7
	m.scale_max = 3.0
	m.scale_curve = _curve([Vector2(0.0, 0.4), Vector2(0.25, 1.0), Vector2(1.0, 1.9)])
	m.angle_min = -180.0
	m.angle_max = 180.0
	m.angular_velocity_min = -12.0
	m.angular_velocity_max = 12.0
	m.anim_offset_max = 1.0
	m.lifetime_randomness = 0.3
	m.color_ramp = _ramp([[0.0, Color(1, 1, 1, 0.0)], [0.08, Color(1, 1, 1, 0.8)], [0.55, Color(1, 1, 1, 0.5)], [1.0, Color(1, 1, 1, 0.0)]])
	return m


## The plume: the ground under the blast thrown straight up in a narrow cone, falling back as it spreads.
static func _pm_spray() -> ParticleProcessMaterial:
	var m: ParticleProcessMaterial = _base(26.0, 6.0, 13.0, Vector3(0, -9.8, 0))
	m.damping_min = 0.4
	m.damping_max = 1.2
	m.scale_min = 0.7
	m.scale_max = 1.5
	m.scale_curve = _curve([Vector2(0.0, 0.5), Vector2(0.4, 1.1), Vector2(1.0, 1.6)])
	m.angle_min = -180.0
	m.angle_max = 180.0
	m.anim_offset_max = 1.0
	m.lifetime_randomness = 0.3
	m.color_ramp = _ramp([[0.0, Color(1, 1, 1, 0.95)], [0.6, Color(1, 1, 1, 0.65)], [1.0, Color(1, 1, 1, 0.0)]])
	return m


## The skirt: low dust pushed out flat along the ground by the blast wave, slowing and settling.
static func _pm_skirt() -> ParticleProcessMaterial:
	var m: ParticleProcessMaterial = _base(0.0, 0.0, 0.0, Vector3(0, 0.25, 0))
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	m.emission_ring_axis = Vector3.UP
	m.emission_ring_radius = 0.7
	m.emission_ring_inner_radius = 0.3
	m.emission_ring_height = 0.1
	m.radial_velocity_min = 5.0
	m.radial_velocity_max = 9.5
	m.damping_min = 3.5
	m.damping_max = 5.5
	m.scale_min = 1.0
	m.scale_max = 2.0
	m.scale_curve = _curve([Vector2(0.0, 0.4), Vector2(0.3, 1.0), Vector2(1.0, 1.7)])
	m.angle_min = -180.0
	m.angle_max = 180.0
	m.anim_offset_max = 1.0
	m.lifetime_randomness = 0.3
	m.color_ramp = _ramp([[0.0, Color(1, 1, 1, 0.8)], [0.5, Color(1, 1, 1, 0.45)], [1.0, Color(1, 1, 1, 0.0)]])
	return m


## Chunks: clods, stones or snow lumps (the dirt meshes) flung out in arcs, tumbling, gone as they come down.
static func _pm_debris() -> ParticleProcessMaterial:
	var m: ParticleProcessMaterial = _base(58.0, 5.0, 14.0, Vector3(0, -14.0, 0))
	m.scale_min = 2.2
	m.scale_max = 6.0
	m.scale_curve = _curve([Vector2(0.0, 1.0), Vector2(0.8, 1.0), Vector2(1.0, 0.0)])
	m.particle_flag_rotate_y = true
	m.angle_min = -180.0
	m.angle_max = 180.0
	m.angular_velocity_min = -480.0
	m.angular_velocity_max = 480.0
	m.lifetime_randomness = 0.35
	return m


## Sparks: white-hot streaks along their flight (aligned to their velocity), cooling to red.
static func _pm_sparks() -> ParticleProcessMaterial:
	var m: ParticleProcessMaterial = _base(180.0, 8.0, 22.0, Vector3(0, -6.0, 0))
	m.emission_sphere_radius = 0.2
	m.damping_min = 1.0
	m.damping_max = 2.5
	m.particle_flag_align_y = true
	m.scale_min = 0.5
	m.scale_max = 1.4
	m.scale_curve = _curve([Vector2(0.0, 1.0), Vector2(1.0, 0.25)])
	m.lifetime_randomness = 0.55
	m.color_ramp = _ramp([[0.0, Color(3.0, 2.4, 1.5, 1.0)], [0.3, Color(2.2, 1.0, 0.3, 1.0)], [0.75, Color(1.0, 0.25, 0.05, 0.7)], [1.0, Color(0.4, 0.05, 0.0, 0.0)]])
	return m


## Embers: slow glowing bits carried up in the hot air, drifting, winking out.
static func _pm_embers() -> ParticleProcessMaterial:
	var m: ParticleProcessMaterial = _base(70.0, 1.0, 4.5, Vector3(0.3, 0.8, 0.12))
	m.emission_sphere_radius = 0.6
	m.damping_min = 0.6
	m.damping_max = 1.4
	m.scale_min = 0.6
	m.scale_max = 1.3
	m.turbulence_enabled = false
	m.lifetime_randomness = 0.5
	m.color_ramp = _ramp([[0.0, Color(2.6, 1.4, 0.5, 1.0)], [0.5, Color(1.8, 0.6, 0.12, 0.9)], [1.0, Color(0.6, 0.1, 0.0, 0.0)]])
	return m


# ================================================================== a blast

## The kind a caller did not name: from the radius (a small pop, a shell, a bomb).
static func kind_for(radius: float) -> String:
	if radius < SMALL_RADIUS:
		return "small"
	return "shell" if radius < 6.5 else "bomb"


## The kind's row of vfx.json blast.kinds ("" or unknown = by radius).
func kind_row(kind: String, radius: float) -> Dictionary:
	var kinds: Dictionary = cfg.get("kinds", {})
	var k: String = kind if kinds.has(kind) else kind_for(radius)
	var row: Dictionary = (kinds.get(k, {}) as Dictionary).duplicate()
	row["kind"] = k
	return row


## The visual scale of a blast: the kind's size, nudged by how its radius compares with the kind's usual one.
static func visual_scale(row: Dictionary, radius: float) -> float:
	var ref: float = maxf(0.1, float(row.get("ref_radius", radius)))
	return float(row.get("size", 1.0)) * clampf(radius / ref, float(row.get("min_k", 0.7)), float(row.get("max_k", 1.3)))


## A blast at `pos`. `quality` is Effects.quality(), `particles` Effects.particles_k(). Allocates nothing.
func blast(pos: Vector3, radius: float, kind: String, quality: Dictionary, particles: float) -> void:
	var row: Dictionary = kind_row(kind, radius)
	var small: bool = String(row["kind"]) == "small"
	var s: float = visual_scale(row, radius)
	var i: int = _take_slot()
	var root: Node3D = _slots[i]
	var ems: Dictionary = _em[i]
	stats["blasts"] = int(stats["blasts"]) + 1
	if small:
		stats["small"] = int(stats["small"]) + 1
	# what it went off on (a ray straight down): ground bursts throw dirt, air bursts don't
	var dirt: String = "earth"
	var ground: bool = false
	var ground_y: float = pos.y
	if is_inside_tree() and not small:
		var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.4, pos + Vector3.DOWN * float(cfg.get("ground_reach_m", 2.2)), 1)
		var hit: Dictionary = space.intersect_ray(q)
		if not hit.is_empty():
			ground = true
			ground_y = (hit["position"] as Vector3).y
			dirt = str(DIRT_OF.get(Effects.surface_of(hit.get("collider"), hit["position"], hit["normal"], space), "stone"))
			stats["ground"] = int(stats["ground"]) + 1
	var ratio: float = clampf(particles * float(row.get("count_k", 1.0)), 0.05, 1.0)
	var low: bool = particles < 0.6
	var speed: float = float(row.get("speed", 1.0)) * (float(cfg.get("low_speed_k", 1.3)) if low else 1.0)
	root.position = pos   # Effects sits at the origin, unrotated
	root.rotation = Vector3(0, randf() * TAU, 0)
	root.scale = Vector3.ONE * s
	root.show()
	var cols: Array = DUST.get(dirt, DUST["earth"])
	var parts: Dictionary = row.get("parts", {})
	for nm: String in EMITTERS:
		var p: GPUParticles3D = ems[nm]
		var on: bool = bool(parts.get(nm, true))
		if GROUND_PARTS.has(nm) and not ground:
			on = false
		if nm == "Skirt" and low:
			on = false   # Low: no skirt (the ring stays)
		if not on:
			p.emitting = false
			p.hide()
			continue
		p.amount_ratio = ratio
		p.speed_scale = speed
		match nm:
			"Fire":
				p.set_instance_shader_parameter(&"tint", Color(0.11, 0.1, 0.09, 1.0))
				p.set_instance_shader_parameter(&"heat", 1.0)
				p.set_instance_shader_parameter(&"burn", float(row.get("burn", 0.18)))
			"Smoke":
				var sc: Color = Color(0.13, 0.12, 0.11, 1.0).lerp(cols[1] as Color, 0.25 if ground else 0.0)
				p.set_instance_shader_parameter(&"tint", Color(sc, float(row.get("smoke_alpha", 1.0))))
				p.set_instance_shader_parameter(&"heat", 0.35)
				p.set_instance_shader_parameter(&"burn", 0.06)
			"Spray":
				p.set_instance_shader_parameter(&"tint", cols[0] as Color)
				p.set_instance_shader_parameter(&"heat", 0.0)
			"Skirt":
				p.set_instance_shader_parameter(&"tint", cols[1] as Color)
				p.set_instance_shader_parameter(&"heat", 0.0)
			"Debris":
				var mesh: Mesh = _dirt_mesh.get(dirt, _dirt_mesh.get("earth"))
				if p.draw_pass_1 != mesh:
					p.draw_pass_1 = mesh
		if GROUND_PARTS.has(nm):
			p.position = Vector3(0, (ground_y - pos.y) / s + 0.1, 0)
		else:
			p.position = Vector3.ZERO
		p.show()
		p.restart()
		p.emitting = true
	# the flash, the ground ring
	var fl: MeshInstance3D = _flash[i]
	fl.position = Vector3(0, 0.25, 0)
	fl.scale = Vector3.ONE * float(row.get("flash_m", 3.0))
	fl.set_instance_shader_parameter(&"k", 1.0)
	fl.set_instance_shader_parameter(&"seed", randf() * TAU)
	fl.show()
	_flash_t[i] = float(row.get("flash_s", 0.12))
	var rg: MeshInstance3D = _ring[i]
	if ground and bool(parts.get("Ring", true)):
		rg.position = Vector3(0, (ground_y - pos.y) / s + 0.12, 0)
		rg.scale = Vector3.ONE * 0.1
		rg.set_instance_shader_parameter(&"k", 0.0)
		rg.set_instance_shader_parameter(&"tint", cols[1] as Color)
		rg.show()
		_ring_t[i] = float(row.get("ring_s", 0.5))
		rg.set_meta("reach", float(row.get("ring_m", 5.0)))
	else:
		rg.hide()
		_ring_t[i] = 0.0
	_age[i] = 0.0
	_life[i] = float(row.get("life_s", 6.0)) / maxf(0.2, speed)
	_light(i, pos + Vector3.UP * (0.6 * s), row, quality)
	# the player's eyes and ears
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	var shake: float = _shake_players(pos, radius, s, row)
	var near: float = 0.0
	if cam != null:
		var d: float = cam.global_position.distance_to(pos)
		near = clampf(1.0 - d / maxf(1.0, radius * float(cfg.get("screen_reach_k", 1.6)) + 4.0 * s), 0.0, 1.0)
		if near > 0.0 and screen != null:
			var uv: Vector2 = Vector2(0.5, 0.5)
			if not cam.is_position_behind(pos):
				uv = cam.unproject_position(pos) / Vector2(get_viewport().get_visible_rect().size)
			screen.pulse(near * float(row.get("screen", 1.0)), uv)
		_sounds(pos, d, row)
	last = {"kind": row["kind"], "scale": s, "ratio": ratio, "ground": ground, "dirt": dirt, "slot": i,
		"light": _light_of[i], "shake": shake, "near": near, "speed": speed}
	_live = 0
	for a: float in _age:
		if a >= 0.0:
			_live += 1
	set_process(true)


## The free slot, else the oldest.
func _take_slot() -> int:
	var best: int = 0
	var oldest: int = 1 << 30
	for i: int in SLOTS:
		if _age[i] < 0.0:
			best = i
			break
		if _born[i] < oldest:
			oldest = _born[i]
			best = i
	_serial += 1
	_born[best] = _serial
	_release_light(best)
	return best


func _light(slot: int, at: Vector3, row: Dictionary, quality: Dictionary) -> void:
	var budget: int = clampi(int(quality.get("blast_lights", cfg.get("lights", 3))), 0, LIGHTS)
	if budget <= 0 or float(row.get("light", 1.0)) <= 0.0:
		return
	var li: int = -1
	var alive: int = 0
	for j: int in budget:
		if _light_slot[j] < 0:
			if li < 0:
				li = j
		else:
			alive += 1
	if li < 0:   # all busy: take over the one that is furthest gone
		var oldest: int = 1 << 30
		for j: int in budget:
			var sj: int = _light_slot[j]
			if _born[sj] < oldest:
				oldest = _born[sj]
				li = j
		_release_light(_light_slot[li])
	var l: OmniLight3D = _lights[li]
	_light_slot[li] = slot
	_light_of[slot] = li
	_light_peak[li] = float(cfg.get("light_energy", 9.0)) * float(row.get("light", 1.0))
	l.omni_range = float(cfg.get("light_range_m", 9.0)) * float(row.get("light_range_k", 1.0))
	l.global_position = at
	l.light_energy = _light_peak[li]
	l.show()
	stats["lights"] = int(stats["lights"]) + 1


func _release_light(slot: int) -> void:
	var li: int = _light_of[slot]
	if li < 0:
		return
	_light_of[slot] = -1
	_light_slot[li] = -1
	_lights[li].light_energy = 0.0
	_lights[li].hide()


## How many blast lights burn now (tests: the cap).
func lights_alive() -> int:
	var n: int = 0
	for l: OmniLight3D in _lights:
		if l.visible:
			n += 1
	return n


func live_count() -> int:
	var n: int = 0
	for a: float in _age:
		if a >= 0.0:
			n += 1
	return n


## The local players' camera shake (the BossFx pattern: their `_shake`, which they scale by the Screen Shake setting
## themselves, so 0 there means none here). Returns the strongest given.
func _shake_players(pos: Vector3, radius: float, s: float, row: Dictionary) -> float:
	var best: float = 0.0
	if not is_inside_tree():
		return 0.0
	var strength: float = float(row.get("shake", 0.6))
	var reach: float = maxf(2.0, radius * float(cfg.get("shake_reach_k", 3.0)) + 6.0 * s)
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or not p.is_local or p.is_bot:
			continue
		var d: float = p.global_position.distance_to(pos)
		if d >= reach:
			continue
		var k: float = strength * pow(1.0 - d / reach, 1.4)
		p.set("_shake", maxf(float(p.get("_shake")), k))
		best = maxf(best, k)
	return best


# ================================================================== the sound

## The layers on top of the caller's own boom: a crack close to it, a rumble that arrives late from far off
## (sound takes d / 343 s to get there), a patter of falling debris. All from the bank (gen_audio_blast.py).
func _sounds(pos: Vector3, d: float, row: Dictionary) -> void:
	var snd: Dictionary = row.get("sound", {})
	if snd.is_empty():
		return
	var crack: String = str(snd.get("crack", ""))
	if crack != "" and d < float(snd.get("crack_m", 30.0)):
		_queue(crack, pos, float(snd.get("crack_db", 0.0)), d / SPEED_OF_SOUND)
	var rumble: String = str(snd.get("rumble", ""))
	if rumble != "" and d > float(snd.get("rumble_from_m", 25.0)):
		var k: float = clampf((d - float(snd.get("rumble_from_m", 25.0))) / 40.0, 0.0, 1.0)
		_queue(rumble, pos, float(snd.get("rumble_db", 0.0)) + lerpf(-6.0, 0.0, k), minf(d / SPEED_OF_SOUND, 1.5))
	var debris: String = str(snd.get("debris", ""))
	if debris != "" and d < float(snd.get("debris_m", 40.0)):
		_queue(debris, pos, float(snd.get("debris_db", -4.0)), float(snd.get("debris_delay_s", 0.45)) + d / SPEED_OF_SOUND)


func _queue(key: String, pos: Vector3, db: float, delay: float) -> void:
	if delay <= 0.02:
		_play(key, pos, db)
		return
	var slot: int = -1
	var soonest: float = INF
	for j: int in PENDING:
		if _pend_t[j] < 0.0:
			slot = j
			break
		if _pend_t[j] < soonest:
			soonest = _pend_t[j]
			slot = j
	if _pend_t[slot] >= 0.0:
		_play(_pend_key[slot], _pend_pos[slot], _pend_db[slot])   # full: the one nearest its time goes now
	else:
		_npend += 1
	_pend_key[slot] = key
	_pend_pos[slot] = pos
	_pend_db[slot] = db
	_pend_t[slot] = delay


func _play(key: String, pos: Vector3, db: float) -> void:
	stats["sounds"] = int(stats["sounds"]) + 1
	if AudioDirector.has_sound(key):
		AudioDirector.play_3d(key, pos, db, 0.07)


# ================================================================== per frame

func _process(delta: float) -> void:
	if _warm_left > 0:
		_warm_step()
	var any: bool = _npend > 0 or _warm_left > 0
	if _npend > 0:
		for j: int in PENDING:
			if _pend_t[j] >= 0.0:
				_pend_t[j] -= delta
				if _pend_t[j] < 0.0:
					_npend -= 1
					_play(_pend_key[j], _pend_pos[j], _pend_db[j])
	for i: int in SLOTS:
		var a: float = _age[i]
		if a < 0.0:
			continue
		any = true
		a += delta
		_age[i] = a
		var fl: MeshInstance3D = _flash[i]
		if fl.visible:
			var fk: float = exp(-a / maxf(0.01, _flash_t[i]))
			if fk < 0.02:
				fl.hide()
			else:
				fl.set_instance_shader_parameter(&"k", fk)
		var rg: MeshInstance3D = _ring[i]
		if rg.visible:
			var rk: float = a / maxf(0.05, _ring_t[i])
			if rk >= 1.0:
				rg.hide()
			else:
				rg.set_instance_shader_parameter(&"k", rk)
				var reach: float = float(rg.get_meta("reach", 5.0))
				rg.scale = Vector3.ONE * maxf(0.1, reach * sqrt(rk))
		var li: int = _light_of[i]
		if li >= 0:
			# the flash (a few hundredths of a second), then the fireball's flickering glow for under a second
			var e: float = exp(-a / 0.05) * 0.75 + 0.25 * clampf(1.0 - a / 0.8, 0.0, 1.0) * (0.8 + 0.2 * sin(a * 47.0 + float(i)))
			if e < 0.01:
				_release_light(i)
			else:
				_lights[li].light_energy = _light_peak[li] * e
		if a >= _life[i]:
			_age[i] = -1.0
			_release_light(i)
			for nm: String in EMITTERS:
				var p: GPUParticles3D = _em[i][nm]
				p.emitting = false
				p.hide()
			_slots[i].hide()
	if not any:
		set_process(false)


# ================================================================== the warm-up

## Called when a match starts: over the next frames one blast with every part on is shown in front of the camera at
## a scale too small to see, its light at no energy, and the screen pass with nothing in it, so every shader and
## pipeline a blast needs is compiled while the map loads.
func warm() -> void:
	_warm_left = 4
	set_process(true)


func _warm_step() -> void:
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return   # wait for the map's camera
	_warm_left -= 1
	var i: int = SLOTS - 1
	var root: Node3D = _slots[i]
	if _warm_left == 3:
		if _age[i] >= 0.0:
			_warm_left = 0
			return   # a real blast is using it
		root.position = cam.global_position - cam.global_basis.z * 3.0
		root.scale = Vector3.ONE * 0.001
		root.show()
		for nm: String in EMITTERS:
			var p: GPUParticles3D = _em[i][nm]
			p.amount_ratio = 0.05
			p.position = Vector3.ZERO
			p.show()
			p.restart()
			p.emitting = true
		_flash[i].set_instance_shader_parameter(&"k", 0.0)
		_flash[i].show()
		_ring[i].set_instance_shader_parameter(&"k", 1.0)
		_ring[i].show()
		var l: OmniLight3D = _lights[LIGHTS - 1]
		if _light_slot[LIGHTS - 1] < 0:
			l.global_position = root.global_position
			l.light_energy = 0.0001
			l.omni_range = 0.05
			l.show()
		if screen != null:
			screen.pulse(0.0, Vector2(0.5, 0.5), true)
	elif _warm_left == 0:
		for nm: String in EMITTERS:
			var p: GPUParticles3D = _em[i][nm]
			p.emitting = false
			p.hide()
		_flash[i].hide()
		_ring[i].hide()
		root.hide()
		if _light_slot[LIGHTS - 1] < 0:
			_lights[LIGHTS - 1].light_energy = 0.0
			_lights[LIGHTS - 1].hide()
		stats["warmed"] = int(stats["warmed"]) + 1


## A new match: every blast, light and pending sound goes.
func clear() -> void:
	for i: int in SLOTS:
		_age[i] = -1.0
		_release_light(i)
		for nm: String in EMITTERS:
			var p: GPUParticles3D = _em[i][nm]
			p.emitting = false
			p.hide()
		_flash[i].hide()
		_ring[i].hide()
		_slots[i].hide()
	_pend_t.fill(-1.0)
	_npend = 0
	if screen != null:
		screen.clear()
