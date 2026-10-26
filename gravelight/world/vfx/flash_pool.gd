class_name FlashPool
extends Node3D
## Pooled muzzle flashes per weapon class (UPDATE 05 section 6, T-095). One flash = a set of additive cross-planes
## along the barrel (the class decides how many petals, how long and how wide), a front bloom disc, a billboard
## core sprite, one of three star textures for shape variety, a pulse on one of a few pooled OmniLight3Ds (the
## budget is data: quality.flash_lights, 4 on High) and a small smoke wisp. Everything is built once in _ready
## from data/gravelight/vfx.json "flash"; firing one swaps a mesh and a texture reference, sets a transform and
## shows a node: no allocation per shot. Owned by Effects; fire through Effects.muzzle_flash().

const VM_LAYER: int = 1 << 19   # WeaponHolder.VM_LAYER: the flash light must not light the gun in your hands

var cfg: Dictionary = {}
var _slots: Array[Node3D] = []
var _cross: Array[MeshInstance3D] = []
var _core: Array[MeshInstance3D] = []
var _cross_mat: Array[StandardMaterial3D] = []
var _core_mat: Array[StandardMaterial3D] = []
var _life: PackedFloat32Array = PackedFloat32Array()
var _total: PackedFloat32Array = PackedFloat32Array()
var _light_of: PackedInt32Array = PackedInt32Array()   # slot -> light index or -1
var _light_energy: PackedFloat32Array = PackedFloat32Array()
var _next: int = 0
var _lights: Array[OmniLight3D] = []
var _light_slot: PackedInt32Array = PackedInt32Array()  # light -> slot using it, or -1
var _light_budget: int = 4
var _frames: Array[ImageTexture] = []
var _core_tex: ImageTexture
var _meshes: Dictionary = {}        # class -> ArrayMesh
var _smoke: Array[CPUParticles3D] = []
var _nsmoke: int = 0
var _frame_i: int = 0
## Shots drawn (tests / the dev overlay).
var fired: int = 0


func setup(flash_cfg: Dictionary, smoke_slots: int) -> void:
	cfg = flash_cfg
	var n: int = int(cfg.get("slots", 8))
	for i: int in int(cfg.get("frames", 3)):
		_frames.append(_star_texture(i))
	_core_tex = _soft_texture()
	for cls: String in (cfg.get("classes", {}) as Dictionary).keys():
		var c: Dictionary = (cfg["classes"] as Dictionary)[cls]
		if bool(c.get("skip", false)):
			continue
		_meshes[cls] = _build_mesh(c)
	var core_quad: QuadMesh = QuadMesh.new()
	core_quad.size = Vector2(0.14, 0.14)
	for i: int in n:
		var root: Node3D = Node3D.new()
		root.name = "Flash%d" % i
		var cm: StandardMaterial3D = _flash_material(_frames[0])
		var cross: MeshInstance3D = MeshInstance3D.new()
		cross.name = "Cross"
		cross.material_override = cm
		cross.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(cross)
		var km: StandardMaterial3D = _flash_material(_core_tex)
		km.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		var core: MeshInstance3D = MeshInstance3D.new()
		core.name = "Core"
		core.mesh = core_quad
		core.material_override = km
		core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		core.position = Vector3(0, 0, -0.03)
		root.add_child(core)
		root.hide()
		add_child(root)
		_slots.append(root)
		_cross.append(cross)
		_core.append(core)
		_cross_mat.append(cm)
		_core_mat.append(km)
		_life.append(0.0)
		_total.append(0.05)
		_light_of.append(-1)
		_light_energy.append(0.0)
	for i: int in 4:   # the hard cap; the quality budget uses the first N
		var l: OmniLight3D = OmniLight3D.new()
		l.name = "FlashLight%d" % i
		l.light_color = Color(1.0, 0.75, 0.4)
		l.omni_range = 7.0
		l.omni_attenuation = 1.4
		l.light_energy = 0.0
		l.shadow_enabled = false
		l.light_cull_mask = 0xFFFFF & ~VM_LAYER
		l.hide()
		add_child(l)
		_lights.append(l)
		_light_slot.append(-1)
	var soft: Texture2D = _core_tex
	for i: int in maxi(1, smoke_slots):
		var p: CPUParticles3D = CPUParticles3D.new()
		var q: QuadMesh = QuadMesh.new()
		q.size = Vector2(0.12, 0.12)
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = soft
		m.vertex_color_use_as_albedo = true
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		m.disable_receive_shadows = true
		q.material = m
		p.mesh = q
		p.emitting = false
		p.one_shot = true
		p.amount = 6
		p.lifetime = 1.0
		p.explosiveness = 0.9
		p.direction = Vector3(0, 0, 1)
		p.spread = 30.0
		p.initial_velocity_min = 0.3
		p.initial_velocity_max = 0.9
		p.gravity = Vector3(0, 0.35, 0)
		p.damping_min = 0.6
		p.damping_max = 1.2
		p.scale_amount_min = 0.5
		p.scale_amount_max = 1.0
		var c: Curve = Curve.new()
		c.add_point(Vector2(0.0, 0.4))
		c.add_point(Vector2(1.0, 1.0))
		p.scale_amount_curve = c
		var g: Gradient = Gradient.new()
		g.set_color(0, Color(0.7, 0.68, 0.64, 0.38))
		g.set_color(1, Color(0.55, 0.54, 0.52, 0.0))
		p.color_ramp = g
		p.angle_min = -180.0
		p.angle_max = 180.0
		p.local_coords = false
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)
		_smoke.append(p)


## The class config for a weapon class (the "rifle" look when a class has none).
func class_cfg(weapon_class: String) -> Dictionary:
	var classes: Dictionary = cfg.get("classes", {})
	return classes.get(weapon_class, classes.get("rifle", {})) as Dictionary


func has_class(weapon_class: String) -> bool:
	return (cfg.get("classes", {}) as Dictionary).has(weapon_class)


## A flash at `pos` pointing along `dir` for `weapon_class`; `upgraded` tints the petals with the Nachtglas fringe,
## `scale` is an extra multiplier (third-person bodies draw them a little larger), `quality` the resolved quality row.
func fire(pos: Vector3, dir: Vector3, weapon_class: String, upgraded: bool, scale: float, quality: Dictionary) -> void:
	var c: Dictionary = class_cfg(weapon_class)
	if c.is_empty() or bool(c.get("skip", false)) or _slots.is_empty():
		return
	fired += 1
	var i: int = _next
	_next = (_next + 1) % _slots.size()
	_release_light(i)
	var root: Node3D = _slots[i]
	var f: Vector3 = dir.normalized() if dir.length_squared() > 0.0001 else Vector3.FORWARD
	var up: Vector3 = Vector3.UP if absf(f.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	var k: float = float(c.get("size", 0.8)) * scale * randf_range(0.85, 1.15)
	root.global_transform = Transform3D(Basis.looking_at(f, up) * Basis(Vector3.BACK, randf() * TAU), pos)
	root.scale = Vector3(k, k, k * randf_range(0.8, 1.25))
	var cross: MeshInstance3D = _cross[i]
	var mesh: Mesh = _meshes.get(weapon_class, _meshes.get("rifle"))
	if cross.mesh != mesh:
		cross.mesh = mesh
	_frame_i = (_frame_i + 1 + randi() % 2) % _frames.size()
	var cm: StandardMaterial3D = _cross_mat[i]
	cm.albedo_texture = _frames[_frame_i]
	var col: Color = _color(c.get("color", [2.0, 1.4, 0.75]))
	if upgraded and weapon_class != "wonder":
		var fr: Color = _color(cfg.get("upgraded_fringe", [1.3, 0.8, 2.2]))
		col = col.lerp(fr, 0.45)
	cm.albedo_color = col
	var km: StandardMaterial3D = _core_mat[i]
	km.albedo_color = col * 1.1
	_core[i].visible = bool(quality.get("flash_core", true))
	_core[i].scale = Vector3.ONE * float(c.get("core", 0.8))
	var life: float = float(c.get("life", 0.05))
	_life[i] = life
	_total[i] = life
	root.show()
	# the light pulse: one of the budgeted pooled lights, stealing the one with the least life left
	_light_budget = clampi(int(quality.get("flash_lights", 4)), 0, _lights.size())
	for li: int in range(_light_budget, _lights.size()):   # a smaller budget than last shot: drop the extras
		if _light_slot[li] >= 0:
			_release_light(_light_slot[li])
	if _light_budget > 0:
		var li: int = _pick_light()
		var l: OmniLight3D = _lights[li]
		_light_slot[li] = i
		_light_of[i] = li
		_light_energy[i] = float(c.get("light", 2.0)) * (1.25 if upgraded else 1.0)
		var lc: Variant = c.get("light_color", null)
		if lc != null:
			l.light_color = _color(lc)
		elif upgraded:
			l.light_color = Color(1.0, 0.75, 0.4).lerp(Color(0.85, 0.55, 1.0), 0.5)   # a taught gun's warm flash, violet-edged
		else:
			l.light_color = Color(1.0, 0.75, 0.4)
		l.omni_range = float(c.get("light_range", 7.0)) * scale
		l.global_position = pos + f * 0.6
		l.light_energy = _light_energy[i]
		l.show()
	# the wisp
	var smoke_k: float = float(c.get("smoke", 0.5)) * float(quality.get("particles", 1.0))
	if smoke_k > 0.05 and bool(quality.get("smoke", true)) and not _smoke.is_empty():
		var p: CPUParticles3D = _smoke[_nsmoke]
		_nsmoke = (_nsmoke + 1) % _smoke.size()
		var amount: int = clampi(int(3.0 + 4.0 * smoke_k), 2, 10)
		if p.amount != amount:
			p.amount = amount
		p.initial_velocity_max = 0.6 + 0.6 * smoke_k
		p.global_position = pos + f * 0.08
		p.global_basis = Basis.looking_at(-f, up)
		p.restart()
		p.emitting = true


func _process(delta: float) -> void:
	for i: int in _slots.size():
		if _life[i] <= 0.0:
			continue
		_life[i] -= delta
		var k: float = clampf(_life[i] / maxf(0.001, _total[i]), 0.0, 1.0)   # 1 at birth -> 0
		var li: int = _light_of[i]
		if _life[i] <= 0.0:
			_slots[i].hide()
			_release_light(i)
			continue
		# shape: a hard bright first third, then the petals shrink and fade; the core holds a little longer
		var a: float = clampf(k * 1.6, 0.0, 1.0)
		_cross_mat[i].albedo_color.a = a
		_core_mat[i].albedo_color.a = clampf(k * 1.3, 0.0, 1.0)
		var s: Vector3 = _slots[i].scale
		_slots[i].scale = Vector3(s.x, s.y, s.z * lerpf(0.75, 1.0, k)) if k < 0.7 else s
		if li >= 0:
			_lights[li].light_energy = _light_energy[i] * clampf(k * 1.4, 0.25, 1.0)


func _pick_light() -> int:
	var best: int = 0
	var best_life: float = INF
	for li: int in _light_budget:
		var s: int = _light_slot[li]
		var life: float = 0.0 if s < 0 else _life[s]
		if life < best_life:
			best_life = life
			best = li
	var old: int = _light_slot[best]
	if old >= 0:
		_light_of[old] = -1
	return best


func _release_light(slot: int) -> void:
	var li: int = _light_of[slot]
	if li < 0:
		return
	_light_of[slot] = -1
	_light_slot[li] = -1
	_lights[li].light_energy = 0.0
	_lights[li].hide()


## How many flashes and lights are showing right now (tests).
func live_count() -> int:
	var n: int = 0
	for i: int in _slots.size():
		if _life[i] > 0.0:
			n += 1
	return n


func live_lights() -> int:
	var n: int = 0
	for l: OmniLight3D in _lights:
		if l.visible and l.light_energy > 0.0:
			n += 1
	return n


static func _color(v: Variant) -> Color:
	if v is Array and (v as Array).size() >= 3:
		var a: Array = v
		return Color(float(a[0]), float(a[1]), float(a[2]), float(a[3]) if a.size() > 3 else 1.0)
	return Color(2.0, 1.4, 0.75)


static func _flash_material(tex: Texture2D) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	mat.albedo_color = Color(2.0, 1.4, 0.75)
	mat.albedo_texture = tex
	mat.disable_receive_shadows = true
	return mat


## The petal set: `petals` planes through the barrel axis (muzzle at the origin, petals reaching -Z), a front
## bloom disc just ahead of the muzzle. Petals sample the star from its hot centre (at the muzzle) to a spike tip.
static func _build_mesh(c: Dictionary) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var front: float = 0.05 * float(c.get("core", 0.8)) * 1.3
	var l: float = 0.24 * float(c.get("length", 1.0))
	var w: float = 0.05 * (0.8 + 0.2 * float(c.get("length", 1.0)))
	var petals: int = maxi(2, int(c.get("petals", 4)))
	var uvs: Array = [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	var quads: Array = []
	var side: Array = []   # true = a petal (tapered UVs)
	quads.append([Vector3(-front, -front, -0.012), Vector3(front, -front, -0.012), Vector3(front, front, -0.012), Vector3(-front, front, -0.012)])
	side.append(false)
	var planes: int = maxi(1, int(ceil(float(petals) / 2.0)))
	for i: int in planes:
		var ang: float = PI * float(i) / float(planes)
		var r: Vector3 = Vector3(cos(ang), sin(ang), 0.0) * w
		var jitter: float = 1.0 - 0.18 * float(i % 2)
		quads.append([-r + Vector3(0, 0, 0.01), r + Vector3(0, 0, 0.01), r + Vector3(0, 0, -l * jitter), -r + Vector3(0, 0, -l * jitter)])
		side.append(true)
	for i: int in quads.size():
		var q: Array = quads[i]
		for idx: int in [0, 1, 2, 0, 2, 3]:
			var uv: Vector2 = uvs[idx]
			if bool(side[i]):
				uv = Vector2(uv.x, 1.0 - 0.5 * uv.y)
			st.set_uv(uv)
			st.add_vertex(q[idx])
	return st.commit()


## A spiky star with a hot core, one of three shapes (lobe count and a little lobe noise differ per frame).
static func _star_texture(frame: int) -> ImageTexture:
	var n: int = 64
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	var lobes: int = [6, 7, 5][frame % 3]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 9001 + frame * 17
	var jit: Array[float] = []
	for i: int in lobes:
		jit.append(rng.randf_range(0.6, 1.0))
	for y: int in n:
		for x: int in n:
			var v: Vector2 = Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5) / (n * 0.5)
			var r: float = v.length()
			var a: float = atan2(v.y, v.x) + float(frame) * 0.37
			var li: int = int(floor((a + PI) / TAU * float(lobes))) % lobes
			var spike: float = pow(maxf(0.0, cos(a * float(lobes) * 0.5)), 10.0) * jit[li]
			var core: float = exp(-r * r * 9.0)
			var reach: float = clampf(1.0 - r / (0.35 + 0.65 * spike), 0.0, 1.0)
			var k: float = clampf(core * 1.3 + reach * 1.1, 0.0, 1.0)
			var warm: Color = Color(1.0, 0.95, 0.85).lerp(Color(1.0, 0.55, 0.2), clampf(r * 1.6, 0.0, 1.0))
			img.set_pixel(x, y, Color(warm.r, warm.g, warm.b, k))
	return ImageTexture.create_from_image(img)


static func _soft_texture() -> ImageTexture:
	var n: int = 32
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y: int in n:
		for x: int in n:
			var v: Vector2 = Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5) / (n * 0.5)
			var k: float = clampf(1.0 - v.length(), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, k * k))
	return ImageTexture.create_from_image(img)
