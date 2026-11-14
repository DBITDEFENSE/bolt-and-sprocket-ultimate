class_name CinemaSet
extends Node3D
## T-194 (UPDATE 11 "LAZARUS", docs/CUTSCENES_LAZARUS.md §6): one stage of the LAZARUS cutscenes. Every set is a
## small scene of its own (gravelight/world/cinema_sets/<id>.tscn: a Node3D with a script that extends this), built
## from code when the cutscene needs it (`build()`), shown only while its shots play (CinemaReel swaps the stage
## into its own World3D) and freed with the cutscene: nothing here is loaded by a map, nothing is a play space (no
## navmesh, no colliders, no spawns). The stage brings its own light: a WorldEnvironment and its sun or moon.
## A shot names its stage in `_set` and its effects in `fx` (at the shot's start) or `fx_at` ([[t, name], ...]); the
## stage plays them as `fx_<name>(seconds)` (the shot's length in real seconds). Nodes a shot aims at (`target`,
## `rel`) are named markers on the stage. Gore follows the Gore setting (`gore()`): an element that only draws on
## "full" joins the group "gore_full", one that draws on "low" and "full" the group "gore_low"; `apply_gore()` hides
## the rest (the shot still plays, the element simply is not there).
## Materials come from the game's own kits (Mats keys, the CC0 MaterialLibrary through them, PropLibrary's CC0
## props); the geometry is ours.

var variant: String = ""
var built: bool = false
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _mats: Dictionary = {}


## Builds the stage once (out of the tree is fine: everything is placed in local space).
func build() -> void:
	if built:
		return
	built = true
	rng.seed = hash(String(name) + variant)
	_build()
	_finish_light()
	apply_gore()


func _build() -> void:
	pass


## Real occlusion replaces the old unshadowed stage. Transparent atmosphere and
## luminous cards stay shadowless; at most four local lamps cast shadow maps.
func _finish_light() -> void:
	var local_shadows: int = 0
	for n: Node in find_children("*", "GeometryInstance3D", true, false):
		if n is GPUParticles3D or n is Label3D:
			continue
		var g: GeometryInstance3D = n as GeometryInstance3D
		var m: Material = g.material_override
		if m == null and n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			m = (n as MeshInstance3D).mesh.surface_get_material(0)
		if m is BaseMaterial3D:
			var bm: BaseMaterial3D = m as BaseMaterial3D
			if bm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or bm.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
				continue
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for n: Node in find_children("*", "Light3D", true, false):
		var l: Light3D = n as Light3D
		l.light_specular = 0.65
		if l is DirectionalLight3D:
			l.shadow_enabled = true
			(l as DirectionalLight3D).directional_shadow_max_distance = 90.0
			l.light_angular_distance = 0.9
		elif local_shadows < 4 and l.light_energy >= 0.7:
			l.shadow_enabled = true
			l.shadow_bias = 0.035
			l.shadow_normal_bias = 0.7
			local_shadows += 1
	var we: WorldEnvironment = get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we != null and we.environment != null and not GLSettings.is_compat():
		var e: Environment = we.environment
		e.ssao_enabled = str(GLSettings.values.get("graphics_preset", "high")) not in ["low", "web"]
		e.ssao_radius = 0.55
		e.ssao_intensity = 1.25
		e.ssao_light_affect = 0.3
		e.glow_bloom = minf(e.glow_bloom, 0.035)


func _ready() -> void:
	build()


## The shot's effect by name: fx_<name>(seconds). Unknown names warn once and do nothing.
func fx(fx_name: String, seconds: float) -> void:
	var m: String = "fx_" + fx_name
	if has_method(m):
		call(m, maxf(0.05, seconds))
	else:
		push_warning("[cinema] stage %s has no effect '%s'" % [name, fx_name])


func has_fx(fx_name: String) -> bool:
	return has_method("fx_" + fx_name)


## The Gore setting ("off" / "low" / "full").
static func gore() -> String:
	return str(GLSettings.values.get("gore", "full"))


## Hides what the Gore setting does not allow (groups "gore_full", "gore_low"; "gore_off" shows only with gore off).
func apply_gore(g: String = "") -> void:
	if g == "":
		g = gore()
	for n: Node in find_children("*", "Node3D", true, false):
		if n.is_in_group(&"gore_full"):
			(n as Node3D).visible = g == "full"
		elif n.is_in_group(&"gore_low"):
			(n as Node3D).visible = g == "full" or g == "low"
		elif n.is_in_group(&"gore_off"):
			(n as Node3D).visible = g == "off"


# ================================================================== light and air

## The stage's sky and air: {bg, ambient, ambient_e, fog, fog_d, fog_h (height falloff), exposure, glow, sky_top,
## sky_horizon (a ProceduralSky when given)}.
func env(o: Dictionary) -> WorldEnvironment:
	var we: WorldEnvironment = WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var e: Environment = Environment.new()
	if o.has("sky_top"):
		var sky: Sky = Sky.new()
		var ps: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
		ps.sky_top_color = _c(o["sky_top"])
		ps.sky_horizon_color = _c(o.get("sky_horizon", o["sky_top"]))
		ps.ground_bottom_color = _c(o.get("ground", [0.05, 0.05, 0.05]))
		ps.ground_horizon_color = _c(o.get("sky_horizon", o["sky_top"]))
		ps.sun_angle_max = 1.0
		ps.sky_energy_multiplier = float(o.get("sky_e", 1.0))
		sky.sky_material = ps
		e.sky = sky
		e.background_mode = Environment.BG_SKY
	else:
		e.background_mode = Environment.BG_COLOR
		e.background_color = _c(o.get("bg", [0.02, 0.02, 0.03]))
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = _c(o.get("ambient", [0.3, 0.32, 0.36]))
	e.ambient_light_energy = float(o.get("ambient_e", 0.5))
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = float(o.get("exposure", 1.0))
	if o.has("fog"):
		e.fog_enabled = true
		e.fog_light_color = _c(o["fog"])
		e.fog_density = float(o.get("fog_d", 0.01))
		e.fog_height = float(o.get("fog_y", 0.0))
		e.fog_height_density = float(o.get("fog_h", 0.0))
		e.fog_sky_affect = float(o.get("fog_sky", 0.6))
	if bool(o.get("glow", true)):
		e.glow_enabled = true
		e.glow_intensity = float(o.get("glow_i", 0.6))
		e.glow_bloom = float(o.get("bloom", 0.05))
		e.glow_hdr_threshold = float(o.get("glow_t", 1.1))
	we.environment = e
	add_child(we)
	return we


func sun(rot_deg: Vector3, color: Variant, energy: float, shadows: bool = false) -> DirectionalLight3D:
	var l: DirectionalLight3D = DirectionalLight3D.new()
	l.name = "Sun"
	l.rotation_degrees = rot_deg
	l.light_color = _c(color)
	l.light_energy = energy
	l.shadow_enabled = shadows
	if shadows:
		l.directional_shadow_max_distance = 80.0
	add_child(l)
	return l


func omni(parent: Node3D, pos: Vector3, color: Variant, energy: float, range_m: float, shadows: bool = false) -> OmniLight3D:
	var l: OmniLight3D = OmniLight3D.new()
	l.position = pos
	l.light_color = _c(color)
	l.light_energy = energy
	l.omni_range = range_m
	l.omni_attenuation = 1.3
	l.shadow_enabled = shadows
	l.light_specular = 0.25
	(parent if parent != null else self).add_child(l)
	return l


func spot(parent: Node3D, pos: Vector3, look_at_p: Vector3, color: Variant, energy: float, range_m: float, angle: float) -> SpotLight3D:
	var l: SpotLight3D = SpotLight3D.new()
	(parent if parent != null else self).add_child(l)
	l.position = pos
	l.light_color = _c(color)
	l.light_energy = energy
	l.spot_range = range_m
	l.spot_angle = angle
	l.shadow_enabled = false
	if pos.distance_to(look_at_p) > 0.01:
		l.look_at_from_position(pos, look_at_p, CinemaCamera.up_for(pos, look_at_p))
	return l


# ================================================================== materials

static func _c(a: Variant) -> Color:
	if a is Color:
		return a
	if a is Array and (a as Array).size() >= 3:
		return Color(float(a[0]), float(a[1]), float(a[2]), float(a[3]) if (a as Array).size() > 3 else 1.0)
	return Color.WHITE


## A game material by key (Mats: procedural or the CC0 library), or a flat colour for "#rrggbb".
func mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m: Material = null
	if key.begins_with("#"):
		m = flat(Color.html(key))
	else:
		m = Mats.get_mat(key)
	_mats[key] = m
	return m


static func flat(c: Color, rough: float = 0.9, emit: float = 0.0, metal: float = 0.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	if c.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func glow(c: Color, energy: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


## A noise-textured surface (mud, snow, plaster) for the big planes; triplanar in world space.
static func noisy(lo: Color, hi: Color, freq: float, scale_m: float, rough: float = 0.95, wet: float = 0.0) -> StandardMaterial3D:
	var n: FastNoiseLite = FastNoiseLite.new()
	n.frequency = freq
	n.fractal_octaves = 4
	var g: Gradient = Gradient.new()
	g.set_color(0, lo)
	g.set_color(1, hi)
	var t: NoiseTexture2D = NoiseTexture2D.new()
	t.noise = n
	t.color_ramp = g
	t.seamless = true
	t.width = 256
	t.height = 256
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_texture = t
	var bump: NoiseTexture2D = NoiseTexture2D.new()
	bump.noise = n
	bump.seamless = true
	bump.width = 256
	bump.height = 256
	bump.as_normal_map = true
	bump.bump_strength = 0.8
	m.normal_enabled = true
	m.normal_texture = bump
	m.normal_scale = 0.35
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / maxf(0.1, scale_m)
	m.roughness = clampf(rough - wet * 0.6, 0.05, 1.0)
	m.metallic_specular = 0.3 + wet * 0.4
	return m


# ================================================================== geometry

func _m(material: Variant) -> Material:
	if material is Material:
		return material
	return mat(str(material))


func box(parent: Node3D, center: Vector3, size: Vector3, material: Variant, rot_deg: Vector3 = Vector3.ZERO, n: String = "") -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = Props.unit_box()
	mi.material_override = _m(material)
	mi.position = center
	mi.rotation_degrees = rot_deg
	mi.scale = size.max(Vector3(0.002, 0.002, 0.002))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if n != "":
		mi.name = n
	(parent if parent != null else self).add_child(mi)
	return mi


func cyl(parent: Node3D, center: Vector3, radius: float, height: float, material: Variant, rot_deg: Vector3 = Vector3.ZERO, n: String = "") -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = Props.unit_cyl()
	mi.material_override = _m(material)
	mi.position = center
	mi.rotation_degrees = rot_deg
	mi.scale = Vector3(radius * 2.0, height, radius * 2.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if n != "":
		mi.name = n
	(parent if parent != null else self).add_child(mi)
	return mi


func ball(parent: Node3D, center: Vector3, size: Vector3, material: Variant, n: String = "") -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = Props.unit_sphere()
	mi.material_override = _m(material)
	mi.position = center
	mi.scale = size
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if n != "":
		mi.name = n
	(parent if parent != null else self).add_child(mi)
	return mi


func cone(parent: Node3D, center: Vector3, r_bottom: float, r_top: float, height: float, material: Variant, sides: int = 8, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var cm: CylinderMesh = CylinderMesh.new()
	cm.bottom_radius = r_bottom
	cm.top_radius = r_top
	cm.height = height
	cm.radial_segments = sides
	cm.rings = 1
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = _m(material)
	mi.position = center
	mi.rotation_degrees = rot_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else self).add_child(mi)
	return mi


func plane(parent: Node3D, center: Vector3, size: Vector2, material: Variant, rot_deg: Vector3 = Vector3.ZERO, n: String = "") -> MeshInstance3D:
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = size
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = _m(material)
	mi.position = center
	mi.rotation_degrees = rot_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if n != "":
		mi.name = n
	(parent if parent != null else self).add_child(mi)
	return mi


## A vertical card facing +Z (a quad: a lit window, a far fire, a painted board).
func card(parent: Node3D, center: Vector3, size: Vector2, material: Variant, yaw_deg: float = 0.0, n: String = "") -> MeshInstance3D:
	var qm: QuadMesh = QuadMesh.new()
	qm.size = size
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = qm
	mi.material_override = _m(material)
	mi.position = center
	mi.rotation_degrees = Vector3(0, yaw_deg, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if n != "":
		mi.name = n
	(parent if parent != null else self).add_child(mi)
	return mi


func group(parent: Node3D, n: String, pos: Vector3 = Vector3.ZERO, yaw_deg: float = 0.0) -> Node3D:
	var g: Node3D = Node3D.new()
	g.name = n
	g.position = pos
	g.rotation_degrees = Vector3(0, yaw_deg, 0)
	(parent if parent != null else self).add_child(g)
	return g


## A named point a shot can aim at (`target` / `rel`).
func marker(n: String, pos: Vector3, parent: Node3D = null) -> Node3D:
	return group(parent if parent != null else self, n, pos)


## Many copies of one mesh as one draw call (logs, sandbags, birches, far figures).
func multi(parent: Node3D, mesh: Mesh, xforms: Array, material: Variant, n: String = "") -> MultiMeshInstance3D:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i: int in xforms.size():
		mm.set_instance_transform(i, xforms[i] as Transform3D)
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _m(material)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if n != "":
		mmi.name = n
	(parent if parent != null else self).add_child(mmi)
	return mmi


static func xf(pos: Vector3, scl: Vector3 = Vector3.ONE, rot_deg: Vector3 = Vector3.ZERO) -> Transform3D:
	var b: Basis = Basis.from_euler(rot_deg * (PI / 180.0)) * Basis.from_scale(scl)   # scale in the mesh's frame, then turn
	return Transform3D(b, pos)


## Words on a prop (a painted board, the line cut over a door): a Label3D in a face that has the letters (IBM Plex
## Sans has Cyrillic). Never a UI font on screen: this is paint or stone in the world.
func words(parent: Node3D, text: String, pos: Vector3, px: float, color: Color, yaw_deg: float = 0.0, n: String = "") -> Label3D:
	var l: Label3D = Label3D.new()
	l.text = text
	l.font = MenuKit.body_font()
	l.font_size = 64
	l.pixel_size = px
	l.modulate = color
	l.outline_size = 0
	l.shaded = true
	l.double_sided = false
	l.position = pos
	l.rotation_degrees = Vector3(0, yaw_deg, 0)
	l.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	if n != "":
		l.name = n
	(parent if parent != null else self).add_child(l)
	return l


func prop(parent: Node3D, key: String, pos: Vector3, yaw_deg: float = 0.0, scl: float = 1.0) -> Node3D:
	var p: Node3D = PropLibrary.instance(key) if PropLibrary.has_key(key) else null
	if p == null:
		return null
	p.position = pos
	p.rotation_degrees = Vector3(0, yaw_deg, 0)
	p.scale = Vector3.ONE * scl
	for mi: Node in p.find_children("*", "GeometryInstance3D", true, false):
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else self).add_child(p)
	return p


## A person of the cutscene (CinemaPerson: a modelled body in its costume, posed by PatronBody's solver).
func person(parent: Node3D, id: String, look: Dictionary, pos: Vector3, yaw_deg: float, pose_name: String = "stand") -> CinemaPerson:
	var p: CinemaPerson = CinemaPerson.new()
	(parent if parent != null else self).add_child(p)
	p.setup_look(id, look, pose_name)
	p.position = pos
	p.rotation_degrees = Vector3(0, yaw_deg, 0)
	p.reset_motion()
	return p


## The cast's looks (cutscenes_lazarus.json "cast"), by id.
static func look_of(id: String) -> Dictionary:
	return ((CinemaLibrary.data().get("cast", {}) as Dictionary).get(id, {}) as Dictionary).duplicate(true)


func fire(parent: Node3D, pos: Vector3, w: float, h: float, light_e: float = 2.0, amount: int = 40) -> void:
	var p: Node3D = parent if parent != null else self
	Props.flames(p, pos, w, h, amount)
	Props.embers(p, pos + Vector3(0, h * 0.6, 0), w * 0.8, maxi(6, amount / 3))
	if light_e > 0.0:
		var l: OmniLight3D = omni(p, pos + Vector3(0, h * 0.7, 0), [1.0, 0.55, 0.22], light_e, maxf(4.0, w * 4.0 + h * 2.0))
		l.set_meta("flicker", light_e)
		l.add_to_group(&"cinema_flicker")


## Tweens a node's property over `seconds` (the stage must be in the tree).
func tween_to(node: Object, prop_path: String, value: Variant, seconds: float, trans: Tween.TransitionType = Tween.TRANS_SINE, ease_t: Tween.EaseType = Tween.EASE_IN_OUT, delay: float = 0.0) -> Tween:
	if not is_inside_tree() or node == null:
		if node != null:
			node.set_indexed(NodePath(prop_path), value)
		return null
	var tw: Tween = create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(node, prop_path, value, maxf(0.01, seconds)).set_trans(trans).set_ease(ease_t)
	return tw


## Something to do `seconds` from now (the stage must be in the tree).
func later(seconds: float, f: Callable) -> void:
	if not is_inside_tree():
		f.call()
		return
	get_tree().create_timer(maxf(0.0, seconds)).timeout.connect(func() -> void:
		if is_instance_valid(self) and is_inside_tree():
			f.call())


# ================================================================== weather and dust

## Falling streaks over a box (`extents` half sizes): rain (fast, thin) or snow (slow, flakes).
func precipitation(parent: Node3D, center: Vector3, extents: Vector3, snow: bool, amount: int = 1400) -> GPUParticles3D:
	var p: GPUParticles3D = GPUParticles3D.new()
	p.name = "Snowfall" if snow else "Rain"
	p.amount = amount
	p.lifetime = 4.0 if snow else 0.9
	p.preprocess = p.lifetime
	p.position = center + Vector3(0, extents.y, 0)
	p.visibility_aabb = AABB(-extents * Vector3(1.2, 2.4, 1.2), extents * Vector3(2.4, 2.6, 2.4))
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(extents.x, 0.2, extents.z)
	pm.direction = Vector3(0.15 if snow else 0.08, -1, 0)
	pm.spread = 6.0
	pm.initial_velocity_min = 1.2 if snow else 16.0
	pm.initial_velocity_max = 2.0 if snow else 20.0
	pm.gravity = Vector3(0, -0.4 if snow else -9.8, 0)
	if snow:
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 0.6
	p.process_material = pm
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(0.035, 0.035) if snow else Vector2(0.012, 0.55)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.92, 0.94, 1.0, 0.85) if snow else Color(0.7, 0.75, 0.8, 0.32)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES if snow else BaseMaterial3D.BILLBOARD_FIXED_Y
	q.material = m
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else self).add_child(p)
	return p


## A burst of soft dust or smoke: `color`, `size` metres across, rising `rise` m/s, lying down for `life` seconds.
func dust(parent: Node3D, pos: Vector3, color: Color, size: float, rise: float, life: float, amount: int = 24, spread_m: float = 2.0) -> GPUParticles3D:
	var p: GPUParticles3D = GPUParticles3D.new()
	p.name = "Dust"
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.85
	p.position = pos
	p.visibility_aabb = AABB(Vector3(-1, -1, -1) * (size * 4.0 + spread_m * 4.0), Vector3(2, 2, 2) * (size * 4.0 + spread_m * 4.0))
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = spread_m
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 80.0
	pm.initial_velocity_min = rise * 0.5
	pm.initial_velocity_max = rise * 1.4
	pm.gravity = Vector3(0, -0.15, 0)
	pm.damping_min = 0.6
	pm.damping_max = 1.4
	pm.scale_min = 0.7
	pm.scale_max = 1.4
	pm.scale_curve = Props._curve_tex([[0.0, 0.35], [0.25, 0.85], [1.0, 1.6]])
	pm.color_ramp = Props._ramp_tex([[0.0, Color(color.r, color.g, color.b, 0.0)], [0.12, Color(color.r, color.g, color.b, color.a)], [1.0, Color(color.r, color.g, color.b, 0.0)]])
	p.process_material = pm
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(size, size)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = _puff_tex()
	m.roughness = 1.0
	q.material = m
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emitting = false
	(parent if parent != null else self).add_child(p)
	return p


static var _puff: GradientTexture2D = null


static func _puff_tex() -> GradientTexture2D:
	if _puff == null:
		var g: Gradient = Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_puff = GradientTexture2D.new()
		_puff.gradient = g
		_puff.fill = GradientTexture2D.FILL_RADIAL
		_puff.fill_from = Vector2(0.5, 0.5)
		_puff.fill_to = Vector2(1.0, 0.5)
		_puff.width = 64
		_puff.height = 64
	return _puff


## A soft round glow (a lit window far off, a flare, a village's lamp): an unshaded additive billboard.
func glow_dot(parent: Node3D, pos: Vector3, size: float, color: Color, energy: float, n: String = "") -> MeshInstance3D:
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(size, size)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = _puff_tex()
	m.albedo_color = Color(color.r * energy, color.g * energy, color.b * energy, 1.0)
	m.no_depth_test = false
	q.material = m
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = q
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if n != "":
		mi.name = n
	(parent if parent != null else self).add_child(mi)
	return mi


# ================================================================== the 1930 village kit (also the 1944 sets)

## A log house (izba): log walls, a plank gable roof along its length, carved window frames on the long side facing
## local +Z, a chimney. Local origin at the floor's centre.
func izba(parent: Node3D, pos: Vector3, yaw_deg: float, w: float = 6.0, d: float = 5.0, h: float = 3.0, burnt: bool = false) -> Node3D:
	var g: Node3D = group(parent, "Izba", pos, yaw_deg)
	var wall: Variant = "char" if burnt else _log_mat()
	box(g, Vector3(0, h * 0.5, 0), Vector3(w, h, d), wall)
	var logs: Array = []
	var y: float = 0.15
	while y < h:
		logs.append(xf(Vector3(0, y, d * 0.5 + 0.02), Vector3(0.24, w + 0.3, 0.24), Vector3(0, 0, 90)))
		logs.append(xf(Vector3(0, y, -d * 0.5 - 0.02), Vector3(0.24, w + 0.3, 0.24), Vector3(0, 0, 90)))
		y += 0.3
	multi(g, Props.unit_cyl(), logs, wall)
	if not burnt:
		var roof_m: Variant = "shingle" if rng.randf() < 0.5 else "hay"
		var rise: float = 2.0
		var half: float = d * 0.5 + 0.5
		var slope: float = sqrt(half * half + rise * rise)
		var ang: float = rad_to_deg(atan2(rise, half))
		box(g, Vector3(0, h + rise * 0.5, half * 0.5 - 0.02), Vector3(w + 0.8, 0.16, slope), roof_m, Vector3(ang, 0, 0))
		box(g, Vector3(0, h + rise * 0.5, -half * 0.5 + 0.02), Vector3(w + 0.8, 0.16, slope), roof_m, Vector3(-ang, 0, 0))
		var gable: PrismMesh = PrismMesh.new()
		gable.size = Vector3(d, rise, 0.2)
		for sx: float in [-w * 0.5, w * 0.5]:
			var gm: MeshInstance3D = MeshInstance3D.new()
			gm.mesh = gable
			gm.material_override = mat("planks")
			gm.position = Vector3(sx, h + rise * 0.5, 0)
			gm.rotation_degrees = Vector3(0, 90, 0)
			gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			g.add_child(gm)
		cyl(g, Vector3(w * 0.25, h + rise + 0.2, -0.6), 0.25, 1.4, "brick")
		for wx: float in [-w * 0.25, w * 0.25]:   # windows with their carved, painted frames (nalichniki)
			box(g, Vector3(wx, h * 0.55, d * 0.5 + 0.14), Vector3(0.75, 0.9, 0.04), "window_dark")
			box(g, Vector3(wx, h * 0.55 + 0.55, d * 0.5 + 0.17), Vector3(1.05, 0.22, 0.05), "#c9c7b4")
			box(g, Vector3(wx, h * 0.55 - 0.52, d * 0.5 + 0.17), Vector3(1.0, 0.12, 0.05), "#c9c7b4")
			for fx2: float in [-0.46, 0.46]:
				box(g, Vector3(wx + fx2, h * 0.55, d * 0.5 + 0.17), Vector3(0.1, 1.0, 0.05), "#8aa0a8")
	else:
		box(g, Vector3(0, 0.25, 0), Vector3(w, 0.5, d), "char")
	return g


func _log_mat() -> Material:
	if not _mats.has("_logs"):
		_mats["_logs"] = noisy(Color(0.26, 0.21, 0.16), Color(0.42, 0.36, 0.28), 0.6, 0.8, 0.95)
	return _mats["_logs"]


## Birches: white trunks with dark marks and bare twigs (April); `leaves` gives them a spring crown.
func birches(parent: Node3D, spots: Array, leaves: bool = false) -> void:
	var trunks: Array = []
	var twigs: Array = []
	var crowns: Array = []
	for s: Variant in spots:
		var p: Vector3 = s
		var hgt: float = rng.randf_range(9.0, 14.0)
		var tip: Vector3 = p + Vector3(rng.randf_range(-0.7, 0.7), hgt, rng.randf_range(-0.7, 0.7))
		for t: int in 5:
			var a0: Vector3 = p.lerp(tip, float(t) / 5.0)
			var b0: Vector3 = p.lerp(tip, float(t + 1) / 5.0)
			trunks.append(_branch_xf(a0, b0, 0.23 * (1.0 - float(t) * 0.17)))
		for k: int in 16:
			var fraction: float = 0.34 + float(k) * 0.038
			var a: float = float(k) * 2.4 + rng.randf_range(-0.3, 0.3)
			var reach: float = (1.0 - fraction) * 3.9
			var start: Vector3 = p.lerp(tip, fraction)
			var bend: Vector3 = start + Vector3(cos(a) * reach * 0.55, reach * 0.28, sin(a) * reach * 0.55)
			var end: Vector3 = start + Vector3(cos(a) * reach, reach * 0.55, sin(a) * reach)
			twigs.append(_branch_xf(start, bend, 0.06 * (1.0 - fraction)))
			twigs.append(_branch_xf(bend, end, 0.035 * (1.0 - fraction)))
			for fork: int in 3:
				var root: Vector3 = bend.lerp(end, float(fork) * 0.28)
				var fa: float = a + (-0.65 if fork % 2 == 0 else 0.65)
				var ft: Vector3 = root + Vector3(cos(fa) * reach * 0.42, reach * 0.25, sin(fa) * reach * 0.42)
				twigs.append(_branch_xf(root, ft, 0.013))
		if leaves:
			crowns.append(xf(p + Vector3(0, hgt * 0.78, 0), Vector3(3.4, 4.6, 3.4)))
	if not _mats.has("_birch"):
		_mats["_birch"] = noisy(Color(0.12, 0.11, 0.1), Color(0.86, 0.85, 0.8), 1.6, 0.5, 0.9)
	multi(parent, Props.unit_cyl(), trunks, _mats["_birch"], "BirchTrunks")
	var tapered: CylinderMesh = CylinderMesh.new()
	tapered.top_radius = 0.12
	tapered.bottom_radius = 0.5
	tapered.height = 1.0
	tapered.radial_segments = 6
	multi(parent, tapered, twigs, flat(Color(0.18, 0.14, 0.12)), "BirchTwigs")
	if leaves:
		multi(parent, Props.unit_sphere(), crowns, noisy(Color(0.2, 0.3, 0.12), Color(0.42, 0.52, 0.24), 1.2, 1.0, 0.9), "BirchCrowns")


func _branch_xf(start: Vector3, end: Vector3, diameter: float) -> Transform3D:
	var axis: Vector3 = end - start
	return Transform3D(Basis(Quaternion(Vector3.UP, axis.normalized())) * Basis.from_scale(Vector3(diameter, axis.length(), diameter)), (start + end) * 0.5)


## The grey lead case (the train in 1930, the vault in 1953): 40 x 25 x 25 cm, dull, two hasps, a rope handle.
## `worn`: the paint gone to the metal at the corners by twenty-three years of hands.
func lead_case(g: Node3D, worn: bool) -> void:
	var lead: StandardMaterial3D = noisy(Color(0.14, 0.145, 0.15), Color(0.23, 0.235, 0.24), 2.0, 0.3, 0.55)
	box(g, Vector3.ZERO, Vector3(0.4, 0.25, 0.25), lead)
	box(g, Vector3(0, 0.07, 0), Vector3(0.41, 0.012, 0.26), flat(Color(0.2, 0.2, 0.21), 0.5))
	for hx: float in [-0.12, 0.12]:
		box(g, Vector3(hx, 0.07, 0.127), Vector3(0.04, 0.06, 0.008), "iron")
	cyl(g, Vector3(0, 0.15, 0), 0.008, 0.18, "rope", Vector3(0, 0, 90))
	if worn:
		for cx: float in [-0.2, 0.2]:
			for cz: float in [-0.125, 0.125]:
				box(g, Vector3(cx, 0.0, cz), Vector3(0.014, 0.252, 0.014), flat(Color(0.6, 0.6, 0.58), 0.35, 0.0, 0.7))
		for cy: float in [-0.125, 0.125]:
			box(g, Vector3(0, cy, 0.126), Vector3(0.402, 0.012, 0.004), flat(Color(0.56, 0.56, 0.55), 0.4, 0.0, 0.7))


var _flick_t: float = 0.0


func _process(delta: float) -> void:
	_flick_t += delta
	for l: Node in get_tree().get_nodes_in_group(&"cinema_flicker"):
		if is_ancestor_of(l) and l is Light3D:
			var base: float = float(l.get_meta("flicker", 1.0))
			var ph: float = float(l.get_instance_id() % 97)
			(l as Light3D).light_energy = base * (0.82 + 0.12 * sin(_flick_t * 9.0 + ph) + 0.06 * sin(_flick_t * 23.0 + ph * 2.0))
