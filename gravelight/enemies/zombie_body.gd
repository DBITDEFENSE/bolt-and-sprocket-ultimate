class_name ZombieBody
extends RefCounted
## Procedural zombie bodies (ZOMBIE_ANIM_SPEC §1 and §6, T-041). Nothing is imported: every body is cylinders,
## spheres and boxes authored here, now **skinned to the shared ZombieRig skeleton**: `build_skinned()` merges a
## base body (build x height x sex) and an outfit kit into one ArrayMesh with bone weights, two surfaces:
##   0 "skin": the Nachtglas infection shader (veins pulsing with the map hum, cracks growing with the round,
##             per-instance tint / dirt / frost / char / fuel / dissolve as instance uniforms)
##   1 "kit":  one shared shader for cloth, leather, metal, eyes and crystal, albedo from vertex colour and
##             roughness / metallic / emission from CUSTOM0, so a whole horde is two draw calls per body.
## Gear pieces (helmets, caps, armbands...) are small meshes hung on bone attachments and rolled per instance.
## The old per-bone StandardMaterial3D path (`material()`, `build_mesh()`, `_cyl()`...) stays for the Foreman's
## own body, the kind parts (crystal plates, lantern) and the Screamer's throat.
## Kits: soldier, villager, miner, labstaff, technician, sailor, dockworker, bellringer, nurse, and (UPDATE 11,
## T-192) the Soviet risen: soviet (the shinel greatcoat), soviet_tunic (the M1935 gymnastyorka), soviet_burial (from
## a field grave). `laborer` is retired (forced laborers are never zombies, v2 §0.1).

const KITS: PackedStringArray = ["soldier", "villager", "miner", "labstaff", "technician", "sailor", "dockworker", "bellringer", "nurse",
	"soviet", "soviet_tunic", "soviet_burial"]
## T-192: the Soviet risen ("the Returned"): never marked (CANON 2.2), so no Marke; their weak point is the wound that
## killed them (WOUND_SITES), their skin the frost look, their eyes milky (KIT_PALETTE).
const SOVIET_KITS: PackedStringArray = ["soviet", "soviet_tunic", "soviet_burial"]
const BUILDS: PackedStringArray = ["thin", "medium", "heavy"]
const LIMB_BONES: PackedStringArray = ["LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot",
	"LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftHand", "RightHand", "Neck", "Head"]

## Legacy bone names for the hitbox layout (the gameplay contract: head/neck/torso/arms/legs).
const HITBOXES: Array = [
	["head", &"head", Vector3(0.24, 0.27, 0.25), Vector3(0, 0.11, -0.01)],
	["neck", &"neck", Vector3(0.12, 0.11, 0.12), Vector3(0, 0.05, 0)],
	["chest", &"torso", Vector3(0.44, 0.34, 0.26), Vector3(0, 0.15, 0)],
	["abdomen", &"torso", Vector3(0.36, 0.26, 0.24), Vector3(0, 0.1, 0)],
	["sh_l", &"arms", Vector3(0.13, 0.32, 0.13), Vector3(0, -0.15, 0)],
	["sh_r", &"arms", Vector3(0.13, 0.32, 0.13), Vector3(0, -0.15, 0)],
	["el_l", &"arms", Vector3(0.11, 0.42, 0.11), Vector3(0, -0.2, -0.01)],
	["el_r", &"arms", Vector3(0.11, 0.42, 0.11), Vector3(0, -0.2, -0.01)],
	["thigh_l", &"legs", Vector3(0.17, 0.46, 0.17), Vector3(0, -0.22, 0)],
	["thigh_r", &"legs", Vector3(0.17, 0.46, 0.17), Vector3(0, -0.22, 0)],
	["shin_l", &"legs", Vector3(0.14, 0.52, 0.17), Vector3(0, -0.25, -0.02)],
	["shin_r", &"legs", Vector3(0.14, 0.52, 0.17), Vector3(0, -0.25, -0.02)],
]

## The Marke (UPDATE 09 section 1, T-137; docs/U09_CONTRACTS.md C1): Darkmatter's chip under the skin, the weak
## point. site -> [bone, offset on that bone, the host limb a hit counts as]. Not part of HITBOXES (that layout is
## the body contract the mesh tests check); Zombie builds the "marke" hitbox and the glint from this table.
const MARKE_SITES: Dictionary = {
	&"hand": ["RightHand", Vector3(0.0, -0.05, 0.0), &"arms"],         # between thumb and forefinger
	&"forehead": ["Head", Vector3(0.04, 0.17, -0.125), &"head"],       # above the right brow
}
const MARKE_COLOR: Color = Color(0.75, 0.49, 1.0)   # Darkmatter violet (#c07dff)

## Which site a zombie's Marke sits on, from its net_id: deterministic, so a co-op client's puppet shows the same
## site as the host's zombie without anything being sent. hand_chance of a right-hand mark, else the forehead.
static func marke_site_for(net_id: int, hand_chance: float) -> StringName:
	var h: int = posmod(net_id * 2654435761 + 97, 1000)
	return &"hand" if float(h) / 1000.0 < hand_chance else &"forehead"


## The limb a hit on the Marke continues as (armour, wounds, death clips, the headshot path).
static func marke_host_limb(site: StringName) -> StringName:
	return StringName(weak_site(site)[2])


## UPDATE 11 (T-192): the wound that killed a Soviet risen, their weak point instead of a Marke (the same hitbox
## cube, the same enemies.json marke.damage_mult and scrip_bonus, a different place, no glint). site -> [bone, offset,
## host limb]; a kit's anim.json "wound_sites" lists which it can carry (picked from net_id like the Marke's).
## Local -Z is the front of each bone.
const WOUND_SITES: Dictionary = {
	&"chest": ["Chest", Vector3(-0.075, 0.17, -0.128), &"torso"],     # a rifle round on the heart side
	&"belly": ["Spine", Vector3(0.06, 0.07, -0.118), &"torso"],       # a shell splinter in the belly
	&"throat": ["Neck", Vector3(0.025, 0.05, -0.056), &"neck"],       # a splinter in the throat
	&"temple": ["Head", Vector3(0.088, 0.13, -0.03), &"head"],        # a round at the temple
}
const WOUND_COLOR: Color = Color(0.16, 0.025, 0.03)   # frozen blood, never emissive


## The site's [bone, offset, host limb] from the Marke table or the wound table (the hand when unknown).
static func weak_site(site: StringName) -> Array:
	if MARKE_SITES.has(site):
		return MARKE_SITES[site]
	if WOUND_SITES.has(site):
		return WOUND_SITES[site]
	return MARKE_SITES[&"hand"]


static func is_wound_site(site: StringName) -> bool:
	return WOUND_SITES.has(site)


## The wound a body of `kit` carries, from its net_id (deterministic, like marke_site_for, so a co-op puppet shows the
## host's): one of the kit's anim.json "wound_sites", &"" for a kit without them.
static func wound_site_for(net_id: int, kit: String) -> StringName:
	var sites: Array = ((GLData.table("anim")["kits"] as Dictionary).get(kit, {}) as Dictionary).get("wound_sites", [])
	if sites.is_empty():
		return &""
	var h: int = posmod(net_id * 40503 + 211, 997)
	return StringName(str(sites[h % sites.size()]))


## Colour / roughness / metallic / emission per material key (vertex-baked into the kit surface).
const KEY_LOOK: Dictionary = {
	"dark": [Color(0.05, 0.03, 0.04), 1.0, 0.0, 0.0],
	"eye": [Color(0.7, 0.3, 1.0), 0.3, 0.0, 3.2],
	"teeth": [Color(0.58, 0.54, 0.4), 0.5, 0.0, 0.0],
	"leather": [Color(0.2, 0.13, 0.08), 0.6, 0.0, 0.0],
	"metal": [Color(0.3, 0.3, 0.31), 0.45, 0.7, 0.0],
	"helmet": [Color(0.27, 0.3, 0.25), 0.55, 0.45, 0.0],
	"wood": [Color(0.42, 0.3, 0.18), 0.85, 0.0, 0.0],
	"lens": [Color(0.9, 0.75, 0.4), 0.2, 0.0, 0.6],
	"white": [Color(0.86, 0.84, 0.8), 0.9, 0.0, 0.0],
	"patch": [Color(0.85, 0.83, 0.75), 0.9, 0.0, 0.0],
	"crystal": [Color(0.42, 0.18, 0.78), 0.1, 0.4, 1.3],
	"glove": [Color(0.1, 0.14, 0.1), 0.35, 0.0, 0.0],
	"hair": [Color(0.1, 0.08, 0.07), 0.9, 0.0, 0.0],
	"hat": [Color(0.15, 0.13, 0.11), 0.9, 0.0, 0.0],
	"navy": [Color(0.12, 0.14, 0.22), 0.9, 0.0, 0.0],
	"oilskin": [Color(0.5, 0.42, 0.2), 0.3, 0.0, 0.0],
	"rubber": [Color(0.14, 0.14, 0.15), 0.35, 0.0, 0.0],
	"knit": [Color(0.3, 0.28, 0.24), 1.0, 0.0, 0.0],
	"armband": [Color(0.08, 0.08, 0.09), 0.9, 0.0, 0.0],
	"brass": [Color(0.6, 0.5, 0.25), 0.4, 0.8, 0.0],
	"rope": [Color(0.5, 0.42, 0.28), 1.0, 0.0, 0.0],
	"stump": [Color(0.3, 0.02, 0.03), 0.35, 0.0, 0.0],
	"eye_white": [Color(0.74, 0.7, 0.64), 0.25, 0.0, 0.0],
	"iris": [Color(0.16, 0.12, 0.09), 0.2, 0.0, 0.0],
	"lip": [Color(0.4, 0.28, 0.3), 0.5, 0.0, 0.0],
	"nail": [Color(0.46, 0.42, 0.4), 0.4, 0.0, 0.0],
	# T-092: the named people's keys (PeopleBodies colours them per person; these are the defaults)
	"canvas": [Color(0.36, 0.33, 0.22), 0.95, 0.0, 0.0],
	"cloth3": [Color(0.22, 0.21, 0.2), 0.95, 0.0, 0.0],
	"accent": [Color(0.4, 0.15, 0.12), 0.9, 0.0, 0.0],
	"lid": [Color(0.55, 0.45, 0.4), 0.6, 0.0, 0.0],
	"brow": [Color(0.1, 0.08, 0.07), 0.9, 0.0, 0.0],
	"stitch": [Color(0.18, 0.1, 0.12), 0.9, 0.0, 0.0],
}
## Kit cloth colours [cloth, cloth2].
const KIT_CLOTH: Dictionary = {
	"soldier": [Color(0.34, 0.36, 0.29), Color(0.25, 0.26, 0.23)],
	"villager": [Color(0.36, 0.3, 0.24), Color(0.3, 0.3, 0.32)],
	"miner": [Color(0.33, 0.27, 0.2), Color(0.19, 0.17, 0.15)],
	"labstaff": [Color(0.56, 0.56, 0.52), Color(0.21, 0.21, 0.23)],
	"technician": [Color(0.38, 0.4, 0.4), Color(0.24, 0.25, 0.26)],
	"sailor": [Color(0.12, 0.14, 0.22), Color(0.15, 0.16, 0.2)],
	"dockworker": [Color(0.3, 0.28, 0.24), Color(0.22, 0.2, 0.18)],
	"bellringer": [Color(0.22, 0.19, 0.16), Color(0.17, 0.15, 0.13)],
	"nurse": [Color(0.37, 0.41, 0.52), Color(0.15, 0.17, 0.28)],
	"drowned": [Color(0.11, 0.15, 0.15), Color(0.13, 0.15, 0.14)],
	"drowned_diver": [Color(0.27, 0.25, 0.2), Color(0.2, 0.19, 0.16)],
	# T-192: the shinel's grey-brown wool, the gymnastyorka's faded khaki, the breeches a shade darker
	"soviet": [Color(0.29, 0.265, 0.225), Color(0.25, 0.235, 0.17)],
	"soviet_tunic": [Color(0.4, 0.365, 0.235), Color(0.27, 0.255, 0.18)],
	"soviet_burial": [Color(0.37, 0.34, 0.23), Color(0.25, 0.235, 0.17)],
}
## T-192: per-kit part-key looks over KEY_LOOK ([colour, roughness, metallic, emission]): the Soviet risen's eyes are
## milky, not the Nachtglas violet (they rose from FOURTH DAY, not from the crystal; CANON 2.2: never marked).
const KIT_PALETTE: Dictionary = {
	"soviet": {"eye": [Color(0.6, 0.64, 0.68), 0.35, 0.0, 0.25]},
	"soviet_tunic": {"eye": [Color(0.6, 0.64, 0.68), 0.35, 0.0, 0.25]},
	"soviet_burial": {"eye": [Color(0.55, 0.58, 0.6), 0.35, 0.0, 0.15]},
}
## T-153 (Totenhafen): kits drawn with another kit's geometry (no GLB Kit_ object of their own). The drowned are
## U-1047's ratings and the harbour's divers: the sailor's cut, waterlogged (DROWNED_PALETTE recolours the part keys).
## Not in KITS: they are tagged onto Gangers by KielholerController, never rolled from variants_by_map.
const KIT_ALIAS: Dictionary = {"drowned": "sailor", "drowned_diver": "sailor"}
const DROWNED_PALETTE: Dictionary = {
	"navy": Color(0.1, 0.14, 0.14), "cloth": Color(0.11, 0.15, 0.15), "cloth2": Color(0.13, 0.15, 0.14),
	"white": Color(0.42, 0.45, 0.4), "hat": Color(0.1, 0.13, 0.13), "leather": Color(0.12, 0.1, 0.08),
}

static var _mats: Dictionary = {}
static var _meshes: Dictionary = {}
static var _crack_round: int = -999
static var _blood: StandardMaterial3D
static var _skin_shader: Shader
static var _kit_shader: Shader
static var _globals_ready: bool = false
static var _stump: ArrayMesh


# ================================================================== materials (legacy StandardMaterial path)

static func _noise_tex(seed_v: int, freq: float, lo: Color, hi: Color, cellular: bool = false) -> NoiseTexture2D:
	var n: FastNoiseLite = FastNoiseLite.new()
	n.seed = seed_v
	n.frequency = freq
	if cellular:
		n.noise_type = FastNoiseLite.TYPE_CELLULAR
		n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
		n.fractal_type = FastNoiseLite.FRACTAL_NONE
	else:
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.fractal_octaves = 3
	var t: NoiseTexture2D = NoiseTexture2D.new()
	t.width = 128
	t.height = 128
	t.seamless = true
	t.noise = n
	var g: Gradient = Gradient.new()
	g.set_color(0, lo)
	g.set_color(1, hi)
	t.color_ramp = g
	return t


## Hairline cracks: ridged noise, only the sharpest ridges glow (amber core, violet edge).
static func _crack_tex() -> NoiseTexture2D:
	var n: FastNoiseLite = FastNoiseLite.new()
	n.seed = 911
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX
	n.frequency = 0.035
	n.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	n.fractal_octaves = 3
	var t: NoiseTexture2D = NoiseTexture2D.new()
	t.width = 128
	t.height = 128
	t.seamless = true
	t.noise = n
	var g: Gradient = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.8, 0.88, 0.95, 1.0])
	g.colors = PackedColorArray([Color.BLACK, Color.BLACK, Color(0.45, 0.12, 0.8), Color(0.75, 0.3, 1.0), Color(1.0, 0.65, 0.3)])
	t.color_ramp = g
	return t


## Raw ridged noise (the crack density mask the shader thresholds by round).
static func _ridge_tex() -> NoiseTexture2D:
	var n: FastNoiseLite = FastNoiseLite.new()
	n.seed = 911
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX
	n.frequency = 0.035
	n.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	n.fractal_octaves = 3
	var t: NoiseTexture2D = NoiseTexture2D.new()
	t.width = 128
	t.height = 128
	t.seamless = true
	t.noise = n
	return t


## Cellular noise: the edges are the veins.
static func _vein_tex() -> NoiseTexture2D:
	var n: FastNoiseLite = FastNoiseLite.new()
	n.seed = 313
	n.frequency = 0.08
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	n.fractal_type = FastNoiseLite.FRACTAL_NONE
	var t: NoiseTexture2D = NoiseTexture2D.new()
	t.width = 128
	t.height = 128
	t.seamless = true
	t.noise = n
	return t


static func _cloth(c: Color, seed_v: int, scale: float = 4.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_texture = _noise_tex(seed_v, 0.06, c.darkened(0.35), c.lightened(0.08))
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.roughness = 0.95
	return m


static func _skin(tint: Color, crack_color: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_texture = _noise_tex(77, 0.07, tint.darkened(0.38), tint.lightened(0.1))
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * 3.0
	m.roughness = 0.68
	m.emission_enabled = true
	m.emission = crack_color
	m.emission_texture = _crack_tex()
	m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	m.emission_energy_multiplier = 0.4
	return m


static func _plain(c: Color, rough: float = 0.8, metal: float = 0.0, emit: float = 0.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


## Legacy material for a key resolved against a kit (the Foreman, kind parts, the Screamer's throat, gibs).
static func material(variant: String, key: String) -> StandardMaterial3D:
	var cache_key: String = variant + ":" + key
	if _mats.has(cache_key):
		return _mats[cache_key]
	var m: StandardMaterial3D
	match key:
		"skin":
			if variant == "bellringer":
				m = material("_", "skin_bell")
			elif variant == "nurse":
				m = material("_", "skin_nurse")
			else:
				m = material("_", "skin_base")
		"skin_base":
			m = _skin(Color(0.55, 0.6, 0.62), Color(0.75, 0.4, 1.0))
		"skin_bell":
			m = _skin(Color(0.66, 0.64, 0.6), Color(1.0, 0.6, 0.3))
		"skin_nurse":
			m = _skin(Color(0.7, 0.68, 0.72), Color(0.75, 0.4, 1.0))
		"skin_glass":
			m = _skin(Color(0.42, 0.38, 0.52), Color(0.8, 0.4, 1.0))
			m.metallic = 0.25
			m.roughness = 0.35
		"cloth", "cloth2":
			var pair: Array = KIT_CLOTH.get(variant, KIT_CLOTH["soldier"])
			m = _cloth(pair[0] if key == "cloth" else pair[1], hash(variant + key) % 1000)
		"leather":
			m = _cloth(Color(0.2, 0.13, 0.08), 41, 5.0)
			m.roughness = 0.6
		"helmet":
			m = _cloth(Color(0.27, 0.3, 0.25), 12, 3.0)
			m.metallic = 0.45
			m.roughness = 0.55
		"wood":
			m = _cloth(Color(0.42, 0.3, 0.18), 63, 6.0)
		"white":
			m = _cloth(Color(0.86, 0.84, 0.8), 88, 3.0)
		"hair":
			m = _cloth(Color(0.1, 0.08, 0.07), 5, 8.0)
		"hat":
			m = _cloth(Color(0.15, 0.13, 0.11), 21, 4.0)
		_:
			if KEY_LOOK.has(key):
				var l: Array = KEY_LOOK[key]
				m = _plain(l[0], float(l[1]), float(l[2]), float(l[3]))
			else:
				m = _plain(Color(1, 0, 1))
	_mats[cache_key] = m
	return m


static func blood_material() -> StandardMaterial3D:
	if _blood == null:
		_blood = StandardMaterial3D.new()
		var g: Gradient = Gradient.new()
		g.set_color(0, Color(0.32, 0.02, 0.03, 1.0))
		g.set_color(1, Color(0.2, 0.0, 0.01, 0.0))
		g.add_point(0.55, Color(0.25, 0.01, 0.02, 0.9))
		var t: GradientTexture2D = GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 32
		t.height = 32
		_blood.albedo_texture = t
		_blood.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_blood.roughness = 0.25
		_blood.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _blood


## Crack glow follows the round: the global gl_round_k = clamp(r/30, 0.1, 1) the infection shader reads, and
## the legacy skin materials' emission. Cheap: runs once per round change.
static func update_cracks(round_number: int, max_energy: float) -> void:
	if round_number == _crack_round:
		return
	_crack_round = round_number
	var k: float = clampf(float(round_number) / 30.0, 0.1, 1.0)
	ensure_globals()
	RenderingServer.global_shader_parameter_set("gl_round_k", k)
	for key: String in ["_:skin_base", "_:skin_bell", "_:skin_nurse", "_:skin_glass"]:
		if _mats.has(key):
			(_mats[key] as StandardMaterial3D).emission_energy_multiplier = k * max_energy * (1.6 if key == "_:skin_glass" else 1.0)


## Global shader parameters the infection shader reads (registered at runtime so no project.godot entry is needed).
static func ensure_globals() -> void:
	if _globals_ready:
		return
	_globals_ready = true
	# not in project.godot (shader_globals), so they exist only once this process adds them; the static flag
	# keeps the add to one call (global_shader_parameter_get_list is editor-only)
	RenderingServer.global_shader_parameter_add("gl_hum", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.5)
	RenderingServer.global_shader_parameter_add("gl_round_k", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.1)


# ================================================================== the Marke's glint (T-137)

static var _marke_shader: Shader
static var _marke_mesh: ArrayMesh

## One shared unshaded violet material for every Marke glint: its emission pulses with the map hum (gl_hum) between
## enemies.json marke.glow_min and glow_max and brightens with the round (gl_round_k), all on the GPU (no per-frame
## work per zombie). A tiny glass bead with a slow amber shimmer inside, like the veins.
static func marke_material() -> ShaderMaterial:
	var key: String = "shader:marke"
	if _mats.has(key):
		return _mats[key]
	ensure_globals()
	if _marke_shader == null:
		_marke_shader = Shader.new()
		_marke_shader.code = """
shader_type spatial;
render_mode unshaded, cull_back;
global uniform float gl_hum;
global uniform float gl_round_k;
uniform vec3 glint_color : source_color = vec3(0.75, 0.49, 1.0);
uniform float glow_min = 0.25;
uniform float glow_max = 1.0;
void fragment() {
	float pulse = mix(glow_min, glow_max, clamp(gl_hum, 0.0, 1.0));
	float ring = 0.6 + 0.4 * sin(TIME * 2.6 + UV.x * 6.2831);
	vec3 core = mix(glint_color, vec3(1.0, 0.8, 0.45), 0.25 * ring);   // the amber vein inside the violet
	float k = pulse * (0.6 + 0.6 * gl_round_k);
	ALBEDO = core * 0.35;
	EMISSION = core * (1.6 + 2.4 * k);
}
"""
	var mk: Dictionary = (GLData.table("enemies") as Dictionary).get("marke", {})
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = _marke_shader
	m.set_shader_parameter("glint_color", MARKE_COLOR)
	m.set_shader_parameter("glow_min", float(mk.get("glow_min", 0.25)))
	m.set_shader_parameter("glow_max", float(mk.get("glow_max", 1.0)))
	_mats[key] = m
	return m


## The glint's mesh (shared): a bead a little smaller than the hitbox, so it reads as something under the skin.
static func marke_glint_mesh() -> ArrayMesh:
	if _marke_mesh != null:
		return _marke_mesh
	var mk: Dictionary = (GLData.table("enemies") as Dictionary).get("marke", {})
	var r: float = float(mk.get("hitbox_m", 0.07)) * 0.22
	_marke_mesh = build_mesh("_", [_sph(r, Vector3.ZERO, "crystal", Vector3(1.0, 0.75, 1.0), false, 8)])
	_marke_mesh.surface_set_material(0, marke_material())
	return _marke_mesh


# ================================================================== shaders (skinned path)

const TRIPLANAR: String = """
vec3 tri(sampler2D t, vec3 p, vec3 n, float s) {
	vec3 w = abs(n); w = w / max(0.0001, w.x + w.y + w.z);
	return texture(t, p.yz * s).rgb * w.x + texture(t, p.xz * s).rgb * w.y + texture(t, p.xy * s).rgb * w.z;
}
"""

static func skin_shader() -> Shader:
	if _skin_shader != null:
		return _skin_shader
	ensure_globals()
	_skin_shader = Shader.new()
	_skin_shader.code = """
shader_type spatial;
render_mode cull_back;
global uniform float gl_hum;
global uniform float gl_round_k;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D ridge_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D vein_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 skin_mul = vec3(1.0);
uniform vec3 crack_color : source_color = vec3(1.0, 0.65, 0.3);
uniform vec3 crack_edge : source_color = vec3(0.75, 0.3, 1.0);
uniform vec3 vein_color : source_color = vec3(0.55, 0.2, 1.0);
uniform float crack_energy = 2.6;
uniform float vein_energy = 1.4;
uniform float hum_pulse = 0.7;
uniform float roughness = 0.68;
uniform float metallic = 0.0;
// T-091: the base body's painted maps on its UVs (albedo: skin variation around linear 0.5 x the kit's skin tone,
// alpha = where the Nachtglas starts: eyes, mouth, hands; normal OpenGL +Y; ORM). use_maps 0 = the procedural look.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, hint_default_white;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_tex : filter_linear_mipmap, hint_default_white;
uniform float use_maps = 0.0;
uniform float normal_depth = 0.6;
uniform float origin_bias = 0.09;
instance uniform vec4 inst_tint : source_color = vec4(1.0);
instance uniform float inst_dirt = 0.3;
instance uniform float inst_frost = 0.0;
instance uniform float inst_char = 0.0;
instance uniform float inst_fuel = 0.0;
instance uniform float inst_dissolve = 0.0;
varying vec3 v_pos;
varying vec3 v_nrm;
varying vec4 v_col;
varying float v_h;
""" + TRIPLANAR + """
void vertex() {
	v_pos = CUSTOM1.xyz;
	v_nrm = NORMAL;
	v_col = COLOR;
	v_h = VERTEX.y;
}
void fragment() {
	vec3 nz = tri(noise_tex, v_pos, v_nrm, 3.0);
	float n = nz.r;
	vec4 alb = texture(albedo_tex, UV);
	vec3 orm = texture(orm_tex, UV).rgb;
	vec3 painted = alb.rgb * 1.5 * mix(0.9, 1.06, n);
	vec3 base = v_col.rgb * skin_mul * inst_tint.rgb * mix(vec3(mix(0.62, 1.1, n)), painted, use_maps);
	float dirt = inst_dirt * (1.0 - smoothstep(0.0, 1.3, v_h)) * (0.4 + 0.6 * n);
	base = mix(base, base * vec3(0.5, 0.42, 0.38), dirt);
	float up = clamp(v_nrm.y, 0.0, 1.0);
	float frost = inst_frost * smoothstep(0.35, 0.9, n * 0.55 + up * 0.55);
	base = mix(base, vec3(0.86, 0.9, 0.96), frost);
	base = mix(base, vec3(0.03, 0.02, 0.02), clamp(inst_char * smoothstep(0.15, 0.75, n + inst_char * 0.4), 0.0, 1.0));
	ALBEDO = base;
	ROUGHNESS = mix(roughness, 0.2, max(inst_fuel, frost * 0.6)) * mix(1.0, orm.g / max(roughness, 0.05), use_maps);
	METALLIC = metallic;
	if (use_maps > 0.5) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = normal_depth;
		AO = orm.r;
		AO_LIGHT_AFFECT = 0.6;
	}
	// where the Nachtglas starts (eyes, mouth, hands): cracks open there first and the veins run thicker
	float origin = alb.a * use_maps;
	// cracks: the ridged noise thresholded by the round (more of the body crystallises as rounds climb)
	float ridge = tri(ridge_tex, v_pos, v_nrm, 3.0).r;
	float thr = mix(0.93, 0.74, gl_round_k) - origin_bias * origin;
	float cr = smoothstep(thr, thr + 0.03, ridge);
	float cr_edge = smoothstep(thr - 0.05, thr, ridge) * (1.0 - cr);
	// veins: cellular edges under the skin, pulsing with the map's hum
	float cell = tri(vein_tex, v_pos, v_nrm, 2.2).r;
	float vein = (1.0 - smoothstep(0.0, 0.09, cell)) * 0.55 * mix(1.0, 0.45 + 0.9 * alb.a, use_maps);
	float pulse = 0.35 + hum_pulse * gl_hum;
	vec3 em = crack_color * cr * crack_energy * gl_round_k + crack_edge * cr_edge * crack_energy * 0.35 * gl_round_k
		+ vein_color * vein * vein_energy * pulse * (0.35 + 0.65 * gl_round_k);
	em *= (1.0 - frost * 0.7) * (1.0 - clamp(inst_char, 0.0, 1.0) * 0.5);
	if (inst_dissolve > 0.0) {
		if (n < inst_dissolve) { discard; }
		em += vec3(0.55, 0.25, 1.0) * smoothstep(inst_dissolve + 0.08, inst_dissolve, n) * 4.0;
	}
	EMISSION = em;
}
"""
	return _skin_shader


static func kit_shader() -> Shader:
	if _kit_shader != null:
		return _kit_shader
	ensure_globals()
	_kit_shader = Shader.new()
	_kit_shader.code = """
shader_type spatial;
render_mode cull_back;
global uniform float gl_hum;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D fabric_tex : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform sampler2D leather_tex : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform float fabric_mean = 1.0;
uniform float leather_mean = 1.0;
uniform float fabric_scale = 7.0;
uniform float knit_scale = 4.0;
uniform float leather_scale = 5.0;
uniform float detail_amount = 0.0;
instance uniform vec4 inst_tint : source_color = vec4(1.0);
instance uniform float inst_dirt = 0.3;
instance uniform float inst_frost = 0.0;
instance uniform float inst_char = 0.0;
instance uniform float inst_fuel = 0.0;
instance uniform float inst_dissolve = 0.0;
varying vec3 v_pos;
varying vec3 v_nrm;
varying vec4 v_col;
varying vec4 v_cus;
varying float v_h;
""" + TRIPLANAR + """
void vertex() {
	v_pos = CUSTOM1.xyz;
	v_nrm = NORMAL;
	v_col = COLOR;
	v_cus = CUSTOM0;
	v_h = VERTEX.y;
}
void fragment() {
	float n = tri(noise_tex, v_pos, v_nrm, 4.0).r;
	float emit = v_cus.b;
	vec3 base = v_col.rgb * mix(0.7, 1.08, n);
	// T-091: tiling detail by class (CUSTOM0.a): 1 wool, 2 knit, 5 canvas -> the fabric weave; 3 leather, 4 rubber
	// -> the leather grain (rubber flattened); triplanar on the rest position, centred on its mean so the vertex
	// colour stays the colour
	float cls = floor(v_cus.a + 0.5);
	if (cls > 0.5) {
		bool leathery = cls > 2.5 && cls < 4.5;
		float sc = cls > 1.5 && cls < 2.5 ? knit_scale : (leathery ? leather_scale : fabric_scale);
		vec3 t = leathery ? tri(leather_tex, v_pos, v_nrm, sc) : tri(fabric_tex, v_pos, v_nrm, sc);
		float l = dot(t, vec3(0.333)) / max(leathery ? leather_mean : fabric_mean, 0.05);
		float amt = cls > 3.5 && cls < 4.5 ? 0.25 : detail_amount;
		base *= mix(1.0, clamp(l, 0.3, 1.8), amt);
	}
	if (emit < 0.01) { base *= inst_tint.rgb; }
	float dirt = inst_dirt * (1.0 - smoothstep(0.0, 1.3, v_h)) * (0.4 + 0.6 * n) * (1.0 - step(0.01, emit));
	base = mix(base, base * vec3(0.5, 0.45, 0.4), dirt);
	float up = clamp(v_nrm.y, 0.0, 1.0);
	float frost = inst_frost * smoothstep(0.35, 0.9, n * 0.55 + up * 0.55) * (1.0 - step(0.01, emit));
	base = mix(base, vec3(0.86, 0.9, 0.96), frost);
	base = mix(base, vec3(0.03, 0.02, 0.02), clamp(inst_char * smoothstep(0.15, 0.75, n + inst_char * 0.4), 0.0, 1.0) * (1.0 - step(0.01, emit)));
	ALBEDO = base;
	ROUGHNESS = mix(v_cus.r, 0.2, max(inst_fuel, frost * 0.6));
	METALLIC = v_cus.g;
	vec3 em = v_col.rgb * emit * (1.0 + 0.35 * gl_hum * step(2.0, emit));
	if (inst_dissolve > 0.0) {
		if (n < inst_dissolve) { discard; }
		em += vec3(0.55, 0.25, 1.0) * smoothstep(inst_dissolve + 0.08, inst_dissolve, n) * 4.0;
	}
	EMISSION = em;
}
"""
	return _kit_shader


## The shared skin material (one per look: base, bellringer amber, nurse pale, glasshide glassy).
static func skin_material(look: String = "base") -> ShaderMaterial:
	var key: String = ("legacy:" if legacy_bodies else "") + "shader:skin:" + look
	if _mats.has(key):
		return _mats[key]
	var inf: Dictionary = GLData.table("anim")["infection"]
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = skin_shader()
	m.set_shader_parameter("noise_tex", _noise_tex(77, 0.07, Color(0.62, 0.62, 0.62), Color(1.1, 1.1, 1.1)))
	m.set_shader_parameter("ridge_tex", _ridge_tex())
	m.set_shader_parameter("vein_tex", _vein_tex())
	m.set_shader_parameter("crack_energy", float(inf.get("crack_energy", 2.6)))
	m.set_shader_parameter("vein_energy", float(inf.get("vein_energy", 1.4)))
	m.set_shader_parameter("hum_pulse", float(inf.get("hum_pulse", 0.7)))
	match look:
		"bell":
			m.set_shader_parameter("crack_color", Color(1.0, 0.6, 0.3))
			m.set_shader_parameter("crack_edge", Color(1.0, 0.75, 0.4))
			m.set_shader_parameter("vein_color", Color(1.0, 0.5, 0.2))
		"glass":
			m.set_shader_parameter("skin_mul", Vector3(0.75, 0.65, 0.85))
			m.set_shader_parameter("metallic", 0.25)
			m.set_shader_parameter("roughness", 0.35)
			m.set_shader_parameter("crack_energy", float(inf.get("crack_energy_glass", 4.2)))
		"frost":
			# T-192: the Soviet risen, frost-white: cold blue-grey veins that barely pulse, faint pale cracks, no violet
			# (anim.json infection.frost_look)
			var fr: Dictionary = inf.get("frost_look", {})
			var sm: Array = fr.get("skin_mul", [0.96, 1.0, 1.07])
			m.set_shader_parameter("skin_mul", Vector3(float(sm[0]), float(sm[1]), float(sm[2])))
			m.set_shader_parameter("vein_color", Color(0.24, 0.3, 0.42))
			m.set_shader_parameter("crack_color", Color(0.62, 0.74, 0.88))
			m.set_shader_parameter("crack_edge", Color(0.5, 0.58, 0.72))
			m.set_shader_parameter("vein_energy", float(fr.get("vein_energy", 0.12)))
			m.set_shader_parameter("crack_energy", float(fr.get("crack_energy", 0.3)))
			m.set_shader_parameter("hum_pulse", float(fr.get("hum_pulse", 0.1)))
			m.set_shader_parameter("roughness", float(fr.get("roughness", 0.5)))
		"living":
			# the people builder's living humans (no Nachtglas: no cracks, no veins)
			m.set_shader_parameter("crack_energy", 0.0)
			m.set_shader_parameter("vein_energy", 0.0)
			m.set_shader_parameter("roughness", 0.55)
	# T-091: the painted maps of the base bodies (all six share one UV layout)
	var set_name: String = "living" if look == "living" else "zombie"
	var tex: Dictionary = (char_cfg().get("textures", {}) as Dictionary).get(set_name, {})
	var dir: String = str(char_cfg().get("zombie_dir", "res://assets/ours/characters/zombie_base"))
	if set_name == "living":
		dir = dir.get_base_dir().path_join("human_base")
	var alb: String = dir.path_join(str(tex.get("albedo", "")))
	if not legacy_bodies and not tex.is_empty() and ResourceLoader.exists(alb):
		m.set_shader_parameter("albedo_tex", load(alb))
		m.set_shader_parameter("normal_tex", load(dir.path_join(str(tex.get("normal", "")))))
		m.set_shader_parameter("orm_tex", load(dir.path_join(str(tex.get("orm", "")))))
		m.set_shader_parameter("use_maps", 1.0)
	_mats[key] = m
	return m


## Fabric and leather detail for the kit shader (the CC0 library's wool and leather sets, T-088).
const FABRIC_TEX: String = "res://assets/third_party/ambientcg/fabric-031/textures/Fabric031_albedo.png"
const LEATHER_TEX: String = "res://assets/third_party/ambientcg/leather-014/textures/Leather014_albedo.png"


static func kit_material() -> ShaderMaterial:
	var mkey: String = ("legacy:" if legacy_bodies else "") + "shader:kit"
	if _mats.has(mkey):
		return _mats[mkey]
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = kit_shader()
	m.set_shader_parameter("noise_tex", _noise_tex(31, 0.06, Color(0.65, 0.65, 0.65), Color(1.08, 1.08, 1.08)))
	for pair: Array in [["fabric", FABRIC_TEX], ["leather", LEATHER_TEX]]:
		if not legacy_bodies and ResourceLoader.exists(str(pair[1])):
			var t: Texture2D = load(str(pair[1])) as Texture2D
			m.set_shader_parameter(str(pair[0]) + "_tex", t)
			m.set_shader_parameter(str(pair[0]) + "_mean", _linear_mean(t))
			m.set_shader_parameter("detail_amount", 0.55)
	_mats[mkey] = m
	return m


## Mean linear luminance of a texture (so a detail map multiplies around 1.0).
static func _linear_mean(t: Texture2D) -> float:
	var img: Image = t.get_image()
	if img == null:
		return 1.0
	img = img.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	img.resize(16, 16, Image.INTERPOLATE_BILINEAR)
	var sum: float = 0.0
	for y: int in 16:
		for x: int in 16:
			var c: Color = img.get_pixel(x, y).srgb_to_linear()
			sum += (c.r + c.g + c.b) / 3.0
	return maxf(0.05, sum / 256.0)


## Builds the kits a map uses up front (avoids a hitch on first spawn).
static func warm_up(kits: PackedStringArray = KITS) -> void:
	for k: String in kits:
		for b: String in BUILDS:
			build_skinned(k, b, false)
		build_skinned(k, "thin", true)
	skin_material("base")
	skin_material("glass")
	kit_material()
	material("_", "skin_glass")
	material("_", "crystal")
	blood_material()
	stump_mesh()
	ZombieClips.library()


# ================================================================== GLB bodies (T-091, docs/CHARACTER_PIPELINE.md)

const CHARACTERS_JSON: String = "res://data/gravelight/art/characters.json"
static var _char_cfg: Dictionary = {}
## Tools only (shots_zombie_anim's before / after lineup): build the pre-T-091 procedural bodies and plain skin.
static var legacy_bodies: bool = false
static var _base: Dictionary = {}      # "m_medium" / "living:f_thin" -> {object name: arrays (bones remapped to the rig)}

## Detail class per part key for the kit shader's tiling fabric (CUSTOM0.a): 0 none, 1 wool, 2 knit, 3 leather,
## 4 rubber / oilskin, 5 canvas / linen.
const DETAIL: Dictionary = {"cloth": 1, "cloth2": 1, "navy": 1, "hat": 1, "armband": 1, "knit": 2, "leather": 3,
	"glove": 4, "rubber": 4, "oilskin": 4, "white": 5, "patch": 5, "rope": 5}


static func char_cfg() -> Dictionary:
	if _char_cfg.is_empty():
		_char_cfg = GLData.load_json(CHARACTERS_JSON)
		# bench A/B switches (docs/gravelight/PERFORMANCE.md, T-091): `-- --legacy-bodies` runs the pre-T-091
		# procedural bodies, `-- --body-lod=auto|none` overrides characters.json lod.mode
		for a: String in OS.get_cmdline_user_args():
			if a == "--legacy-bodies":
				legacy_bodies = true
			elif a.begins_with("--body-lod="):
				(_char_cfg["lod"] as Dictionary)["mode"] = a.substr(11)
	return _char_cfg


## res:// path of a base body GLB (zombie or living).
static func body_path(build: String, female: bool, living: bool = false) -> String:
	var c: Dictionary = char_cfg()
	var dir: String = str(c.get("zombie_dir", "res://assets/ours/characters/zombie_base"))
	if living:
		dir = dir.get_base_dir().path_join("human_base")
	return dir.path_join(str(c.get("living_file" if living else "zombie_file", "")) % ["f" if female else "m", build])


## A living human (the people builder's entry point, docs/CHARACTER_PIPELINE.md): the human_base GLB for the
## build / sex, dressed in `kit` ("" = none; any ZombieBody.KITS kit fits every body), skin `tone` (linear), the
## living skin set (no Nachtglas, plain eyes). Same two-surface layout, rig and LODs as a zombie, so ZombieRig,
## ZombieClips and BoneAttachment3D gear work unchanged. Cached per kit / build / sex / tone.
static func build_living(kit: String, build: String = "medium", female: bool = false, tone: Color = Color(0.62, 0.5, 0.44)) -> ArrayMesh:
	var key: String = "living:%s:%s" % [_cache_key(kit, build, female), tone.to_html()]
	if _meshes.has(key):
		return _meshes[key]
	var base: Dictionary = base_parts(build, female, true)
	if not base.has("Body"):
		return build_skinned(kit if kit != "" else "villager", build, female)
	var mesh: ArrayMesh = _merge_glb(base, kit, female, true, Color(tone.r, tone.g, tone.b, 1.0))
	_meshes[key] = mesh
	return mesh


## T-142 (the relief squads): a body in `kit`'s clothes recoloured by `palette` (part key -> linear Color: cloth,
## cloth2, hair, leather...), living (the human_base GLB, the living skin, plain eyes, skin `tone`) or risen (the zombie
## base GLB, the kit's dead skin and the violet eyes). Same layout, rig and LODs as every body. Cached per argument set.
static func build_dressed(kit: String, build: String, female: bool, tone: Color, palette: Dictionary, living: bool = true) -> ArrayMesh:
	var pk: PackedStringArray = []
	for k: Variant in palette.keys():
		pk.append("%s=%s" % [str(k), (palette[k] as Color).to_html()])
	pk.sort()
	var key: String = "dressed:%s:%s:%s:%s" % [("living" if living else "risen"), _cache_key(kit, build, female), tone.to_html(), ",".join(pk)]
	if _meshes.has(key):
		return _meshes[key]
	var base: Dictionary = base_parts(build, female, living)
	if not base.has("Body"):
		return build_living(kit, build, female, tone) if living else build_skinned(kit, build, female)
	var mesh: ArrayMesh = _merge_glb(base, kit, female, living, Color(tone.r, tone.g, tone.b, 1.0) if living else Color(0, 0, 0, 0), palette)
	_meshes[key] = mesh
	return mesh


## Every mesh object of a body GLB as surface arrays, the skin's bind indices remapped to ZombieRig bone indices
## (the GLB's joints carry the rig's bone names; the bind order is the exporter's). Cached; {} when the GLB is absent.
static func base_parts(build: String, female: bool, living: bool = false) -> Dictionary:
	var key: String = ("living:" if living else "") + ("f_" if female else "m_") + build
	if _base.has(key):
		return _base[key]
	var out: Dictionary = {}
	var path: String = body_path(build, female, living)
	if ResourceLoader.exists(path):
		var ps: PackedScene = load(path) as PackedScene
		if ps != null:
			var root: Node = ps.instantiate()
			for n: Node in root.find_children("*", "MeshInstance3D", true, false):
				var mi: MeshInstance3D = n as MeshInstance3D
				var am: ArrayMesh = mi.mesh as ArrayMesh
				if am == null or am.get_surface_count() == 0:
					continue
				var arrays: Array = am.surface_get_arrays(0)
				_remap_binds(arrays, mi.skin)
				out[String(mi.name)] = arrays
			root.free()
	_base[key] = out
	return out


static func _remap_binds(arrays: Array, skin: Skin) -> void:
	if skin == null or arrays[Mesh.ARRAY_BONES] == null:
		return
	var map: PackedInt32Array = []
	for i: int in skin.get_bind_count():
		map.append(maxi(0, ZombieRig.bone_index(String(skin.get_bind_name(i)))))
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	for i: int in bones.size():
		bones[i] = map[bones[i]] if bones[i] < map.size() else 0
	arrays[Mesh.ARRAY_BONES] = bones


static func part_keys() -> Array:
	return char_cfg().get("part_keys", [])


## Bit of a kit in a body vertex's coverage mask (characters.json kit_order).
static func kit_bit(kit: String) -> int:
	var i: int = (char_cfg().get("kit_order", []) as Array).find(kit)
	return 0 if i < 0 else 1 << i


## The coverage mask a body vertex carries in its colour (bits 0-7 in blue, bit 8 = alpha below one half, bits 9-16
## in red: T-192, the skin key's index is 0, so the older GLBs read 0 there).
static func mask_of(c: Color) -> int:
	return int(round(c.b * 255.0)) | (0x100 if c.a < 0.5 else 0) | (int(round(c.r * 255.0)) << 9)


## Which hair object a kit wears (characters.json "hair"; "" = bald).
static func hair_for(kit: String, female: bool) -> String:
	var k: Dictionary = (char_cfg().get("hair", {}) as Dictionary).get(kit, {})
	return str(k.get("f" if female else "m", "Hair_f" if female else "Hair_m"))


## The two-surface mesh from a body GLB: surface 0 = Body minus the triangles the kit covers (all three vertices
## carry the kit's bit), surface 1 = the face parts, the hair and the kit's clothes (vertex colour = the part key's
## look x baked AO, CUSTOM0 = roughness / metallic / emission / detail class, CUSTOM1 = rest position). With
## characters.json lod.mode "auto" Godot's mesh LODs are generated on the result (no extra nodes or draw calls).
static func _merge_glb(base: Dictionary, kit: String, female: bool, living: bool = false, tone_override: Color = Color(0, 0, 0, 0), palette: Dictionary = {}) -> ArrayMesh:
	var keys: Array = part_keys()
	var bit: int = kit_bit(kit)
	var tone: Color = _look(kit, "skin")[0] if tone_override.a <= 0.0 else tone_override
	var flags: int = (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	# ---- surface 0: skin
	var b: Array = base["Body"]
	var sv: PackedVector3Array = b[Mesh.ARRAY_VERTEX]
	var scol: PackedColorArray = b[Mesh.ARRAY_COLOR]
	var sidx: PackedInt32Array = b[Mesh.ARRAY_INDEX]
	var keep: PackedInt32Array = []
	for t: int in range(0, sidx.size(), 3):
		if bit != 0 and (mask_of(scol[sidx[t]]) & mask_of(scol[sidx[t + 1]]) & mask_of(scol[sidx[t + 2]]) & bit) != 0:
			continue
		keep.append(sidx[t])
		keep.append(sidx[t + 1])
		keep.append(sidx[t + 2])
	var cols: PackedColorArray = []
	cols.resize(sv.size())
	var cus1: PackedFloat32Array = []
	cus1.resize(sv.size() * 4)
	for i: int in sv.size():
		var ao: float = scol[i].g
		cols[i] = Color(tone.r * ao, tone.g * ao, tone.b * ao, 1.0)
		cus1[i * 4] = sv[i].x
		cus1[i * 4 + 1] = sv[i].y
		cus1[i * 4 + 2] = sv[i].z
	var skin_arr: Array = []
	skin_arr.resize(Mesh.ARRAY_MAX)
	for slot: int in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS]:
		skin_arr[slot] = b[slot]
	skin_arr[Mesh.ARRAY_COLOR] = cols
	skin_arr[Mesh.ARRAY_CUSTOM1] = cus1
	skin_arr[Mesh.ARRAY_INDEX] = keep
	# ---- surface 1: parts + hair + clothes
	var acc: _SurfaceAcc = _SurfaceAcc.new()
	var objs: Array = ["Parts"]
	var hair: String = hair_for(kit, female)
	if hair != "":
		objs.append(hair)
	objs.append("Kit_" + kit)
	var looks: Dictionary = {}
	for name: String in objs:
		if not base.has(name):
			continue
		var a: Array = base[name]
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var c: PackedColorArray = a[Mesh.ARRAY_COLOR]
		var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var stride: int = bones.size() / maxi(1, v.size())
		var start: int = acc.verts.size()
		for i: int in v.size():
			var ki: int = int(round(c[i].r * 255.0))
			var kname: String = str(keys[ki]) if ki < keys.size() else "dark"
			if living and kname == "eye":
				kname = "eye_white"
			if not looks.has(kname):
				looks[kname] = _look(kit, kname)
				if palette.has(kname):
					if palette[kname] is Array:
						looks[kname] = (palette[kname] as Array).duplicate()   # T-192: a whole look (the milky eyes)
					else:
						var lk: Array = (looks[kname] as Array).duplicate()
						lk[0] = palette[kname]
						looks[kname] = lk
			var look: Array = looks[kname]
			var ao: float = c[i].g
			var col: Color = look[0]
			acc.verts.append(v[i])
			acc.norms.append(n[i])
			acc.cols.append(Color(col.r * ao, col.g * ao, col.b * ao, 1.0))
			acc.cus0.append_array(PackedFloat32Array([float(look[1]), float(look[2]), float(look[3]), float(DETAIL.get(kname, 0))]))
			acc.cus1.append_array(PackedFloat32Array([v[i].x, v[i].y, v[i].z, 0.0]))
			for k: int in 4:
				acc.bones.append(bones[i * stride + k] if k < stride else 0)
				acc.weights.append(weights[i * stride + k] if k < stride else 0.0)
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		for i: int in idx.size():
			acc.index.append(idx[i] + start)
	var kit_arr: Array = []
	kit_arr.resize(Mesh.ARRAY_MAX)
	kit_arr[Mesh.ARRAY_VERTEX] = acc.verts
	kit_arr[Mesh.ARRAY_NORMAL] = acc.norms
	kit_arr[Mesh.ARRAY_COLOR] = acc.cols
	kit_arr[Mesh.ARRAY_CUSTOM0] = acc.cus0
	kit_arr[Mesh.ARRAY_CUSTOM1] = acc.cus1
	kit_arr[Mesh.ARRAY_BONES] = acc.bones
	kit_arr[Mesh.ARRAY_WEIGHTS] = acc.weights
	kit_arr[Mesh.ARRAY_INDEX] = acc.index
	var im: ImporterMesh = ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, skin_arr, [], {}, skin_material("living" if living else _skin_look(kit)), "skin", flags)
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, kit_arr, [], {}, kit_material(), "kit", flags)
	if str((char_cfg().get("lod", {}) as Dictionary).get("mode", "auto")) == "auto":
		im.generate_lods(60.0, 25.0, [])
	var mesh: ArrayMesh = im.get_mesh()
	mesh.set_meta("lod_counts", [im.get_surface_lod_count(0), im.get_surface_lod_count(1)])
	return mesh


## The triangles of a merged body under `root_bone`'s chain (by dominant weight), unskinned, in that bone's rest
## frame, keeping every vertex attribute and the surface materials.
static func _cut_piece(body: ArrayMesh, root_bone: String) -> ArrayMesh:
	var chain: Dictionary = {}
	for bn: String in ZombieRig.chain_of(root_bone):
		chain[ZombieRig.bone_index(bn)] = true
	var origin: Vector3 = ZombieRig.rest_global(root_bone).origin
	var flags: int = (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	var out: ArrayMesh = ArrayMesh.new()
	for si: int in body.get_surface_count():
		var a: Array = body.surface_get_arrays(si)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var dom: PackedInt32Array = dominant_bones(a)
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		var remap: Dictionary = {}
		var nidx: PackedInt32Array = []
		for t: int in range(0, idx.size(), 3):
			if not (chain.has(dom[idx[t]]) and chain.has(dom[idx[t + 1]]) and chain.has(dom[idx[t + 2]])):
				continue
			for k: int in 3:
				var o: int = idx[t + k]
				if not remap.has(o):
					remap[o] = remap.size()
				nidx.append(remap[o])
		if nidx.is_empty():
			continue
		var order: Array = remap.keys()
		var na: Array = []
		na.resize(Mesh.ARRAY_MAX)
		var nv: PackedVector3Array = []
		var nn: PackedVector3Array = []
		var nc: PackedColorArray = []
		for o: int in order:
			nv.append(v[o] - origin)
			nn.append((a[Mesh.ARRAY_NORMAL] as PackedVector3Array)[o])
			nc.append((a[Mesh.ARRAY_COLOR] as PackedColorArray)[o])
		na[Mesh.ARRAY_VERTEX] = nv
		na[Mesh.ARRAY_NORMAL] = nn
		na[Mesh.ARRAY_COLOR] = nc
		if a[Mesh.ARRAY_TEX_UV] != null:
			var uv: PackedVector2Array = []
			for o: int in order:
				uv.append((a[Mesh.ARRAY_TEX_UV] as PackedVector2Array)[o])
			na[Mesh.ARRAY_TEX_UV] = uv
		for slot: int in [Mesh.ARRAY_TANGENT, Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1]:
			if a[slot] != null:
				var src: PackedFloat32Array = a[slot]
				var dst: PackedFloat32Array = []
				for o: int in order:
					dst.append_array(src.slice(o * 4, o * 4 + 4))
				na[slot] = dst
		na[Mesh.ARRAY_INDEX] = nidx
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, na, [], {}, flags)
		var s2: int = out.get_surface_count() - 1
		out.surface_set_name(s2, body.surface_get_name(si))
		out.surface_set_material(s2, body.surface_get_material(si))
	return out


## Dominant rig bone of every vertex of a surface's arrays (the gore split, tests).
static func dominant_bones(arrays: Array) -> PackedInt32Array:
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var stride: int = bones.size() / maxi(1, v.size())
	var out: PackedInt32Array = []
	out.resize(v.size())
	for i: int in v.size():
		var best: int = 0
		for k: int in range(1, stride):
			if weights[i * stride + k] > weights[i * stride + best]:
				best = k
		out[i] = bones[i * stride + best]
	return out


# ================================================================== geometry primitives

static func _cyl(top: float, bottom: float, h: float, pos: Vector3, mat: String, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE, segs: int = 9, caps: bool = true) -> Array:
	var c: CylinderMesh = CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = segs
	c.rings = 1
	c.cap_top = caps
	c.cap_bottom = caps
	return [c, Transform3D(Basis.from_euler(rot).scaled(scl), pos), mat]


static func _sph(r: float, pos: Vector3, mat: String, scl: Vector3 = Vector3.ONE, hemi: bool = false, segs: int = 10) -> Array:
	var s: SphereMesh = SphereMesh.new()
	s.radius = r
	s.height = r * (1.0 if hemi else 2.0)
	s.is_hemisphere = hemi
	s.radial_segments = segs
	s.rings = 5
	return [s, Transform3D(Basis.IDENTITY.scaled(scl), pos), mat]


static func _box(size: Vector3, pos: Vector3, mat: String, rot: Vector3 = Vector3.ZERO) -> Array:
	var b: BoxMesh = BoxMesh.new()
	b.size = size
	return [b, Transform3D(Basis.from_euler(rot), pos), mat]


## T-192: a flat five-pointed star of outer radius r facing -Z (a cap star), 2.5 mm proud.
static func _star(r: float, pos: Vector3, mat: String) -> Array:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: PackedVector2Array = []
	for i: int in 10:
		var a: float = PI * 0.5 + TAU * float(i) / 10.0
		var rr: float = r if i % 2 == 0 else r * 0.42
		pts.append(Vector2(cos(a), sin(a)) * rr)
	var d: float = 0.0025
	for i: int in 10:
		var p0: Vector2 = pts[i]
		var p1: Vector2 = pts[(i + 1) % 10]
		st.set_normal(Vector3(0, 0, -1))
		st.add_vertex(Vector3(0, 0, -d))
		st.add_vertex(Vector3(p1.x, p1.y, -d * 0.4))
		st.add_vertex(Vector3(p0.x, p0.y, -d * 0.4))
		var n: Vector3 = Vector3(p0.y - p1.y, p1.x - p0.x, 0).normalized()
		st.set_normal(-n)
		st.add_vertex(Vector3(p0.x, p0.y, -d * 0.4))
		st.add_vertex(Vector3(p1.x, p1.y, -d * 0.4))
		st.add_vertex(Vector3(p1.x, p1.y, 0))
		st.add_vertex(Vector3(p0.x, p0.y, -d * 0.4))
		st.add_vertex(Vector3(p1.x, p1.y, 0))
		st.add_vertex(Vector3(p0.x, p0.y, 0))
	return [st.commit(), Transform3D(Basis.IDENTITY, pos), mat]


static var _wound_mesh: ArrayMesh

## T-192: the wound a Soviet risen died of (one shared mesh): a dark frozen hole in a ragged, frost-rimmed tear, a
## little proud of the cloth so it reads at range. Vertex-coloured, one lit surface, never emissive (no glint).
static func wound_mesh() -> ArrayMesh:
	if _wound_mesh != null:
		return _wound_mesh
	var mk: Dictionary = (GLData.table("enemies") as Dictionary).get("marke", {})
	var r: float = float(mk.get("hitbox_m", 0.07)) * 0.5
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1944
	var n: int = 14
	var rim: Array[Vector3] = []
	var outer: Array[Vector3] = []
	for i: int in n:
		var a: float = TAU * float(i) / float(n)
		var k: float = rng.randf_range(0.7, 1.15)
		rim.append(Vector3(cos(a) * r * 0.45 * k, sin(a) * r * 0.45 * k, -0.004))
		outer.append(Vector3(cos(a) * r * k * rng.randf_range(0.9, 1.35), sin(a) * r * k * rng.randf_range(0.9, 1.35), -0.002))
	var hole: Color = Color(0.03, 0.005, 0.008)
	var frost: Color = Color(0.7, 0.74, 0.8)
	st.set_normal(Vector3(0, 0, -1))
	for i: int in n:
		var j: int = (i + 1) % n
		st.set_color(hole)
		st.add_vertex(Vector3(0, 0, 0.002))
		st.set_color(WOUND_COLOR)
		st.add_vertex(rim[j])
		st.add_vertex(rim[i])
		st.add_vertex(rim[i])
		st.add_vertex(rim[j])
		st.set_color(frost)
		st.add_vertex(outer[j])
		st.set_color(WOUND_COLOR)
		st.add_vertex(rim[i])
		st.set_color(frost)
		st.add_vertex(outer[j])
		st.add_vertex(outer[i])
	_wound_mesh = st.commit()
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.35
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_wound_mesh.surface_set_material(0, m)
	return _wound_mesh


## Legacy: an ArrayMesh from [primitive, transform, material key] parts, one StandardMaterial3D surface per key.
static func build_mesh(variant: String, parts: Array) -> ArrayMesh:
	var groups: Dictionary = {}
	for p: Array in parts:
		var k: String = p[2]
		if not groups.has(k):
			groups[k] = []
		(groups[k] as Array).append(p)
	var mesh: ArrayMesh = ArrayMesh.new()
	for k: String in groups.keys():
		var st: SurfaceTool = SurfaceTool.new()
		for p: Array in groups[k]:
			st.append_from(p[0] as Mesh, 0, p[1] as Transform3D)
		st.commit(mesh)
		var idx: int = mesh.get_surface_count() - 1
		mesh.surface_set_material(idx, material(variant, k))
		mesh.surface_set_name(idx, k)
	return mesh


# ================================================================== the skinned body

static func _look(kit: String, key: String) -> Array:
	if key == "cloth" or key == "cloth2":
		var pair: Array = KIT_CLOTH.get(kit, KIT_CLOTH["soldier"])
		return [pair[0] if key == "cloth" else pair[1], 0.95, 0.0, 0.0]
	if key == "skin":
		var tone: Array = (GLData.table("anim")["kits"] as Dictionary).get(kit, {}).get("skin", [0.55, 0.6, 0.62])
		return [Color(float(tone[0]), float(tone[1]), float(tone[2])), 0.68, 0.0, 0.0]
	return KEY_LOOK.get(key, [Color(1, 0, 1), 0.8, 0.0, 0.0])


static func _cache_key(kit: String, build: String, female: bool) -> String:
	return "%s/%s/%s" % [kit, build, "f" if female else "m"]


## The whole body as one skinned ArrayMesh (surface 0 skin, surface 1 kit). Cached per kit/build/sex. Since T-091
## the body and its clothes come from the Blender-built GLBs (`base_parts`, `_merge_glb`); the procedural primitives
## below stay as the fallback when a GLB is missing (a checkout that has not imported yet).
static func build_skinned(kit: String, build: String = "medium", female: bool = false) -> ArrayMesh:
	char_cfg()
	var key: String = ("legacy:" if legacy_bodies else "") + "skinned:" + _cache_key(kit, build, female)
	if _meshes.has(key):
		return _meshes[key]
	var mesh: ArrayMesh
	var base: Dictionary = {} if legacy_bodies else base_parts(build, female)
	var geo: String = str(KIT_ALIAS.get(kit, kit))
	if base.has("Body"):
		if geo != kit:
			# T-153: an alias kit (the drowned) wears its base kit's clothes in its own palette and skin tone
			mesh = _merge_glb(base, geo, female, false, _look(kit, "skin")[0], DROWNED_PALETTE)
		else:
			mesh = _merge_glb(base, kit, female, false, Color(0, 0, 0, 0), KIT_PALETTE.get(kit, {}))
	else:
		mesh = _skin_parts(body_parts(geo, build, female), kit)
	_meshes[key] = mesh
	return mesh


## Merges bone-local parts into skinned surfaces. parts_by_bone: bone -> [[primitive, xform, key], ...].
static func _skin_parts(parts_by_bone: Dictionary, kit: String, root_bone: String = "") -> ArrayMesh:
	var blend: float = float(GLData.table("anim")["skeleton"].get("joint_blend_m", 0.05))
	var root_inv: Transform3D = Transform3D.IDENTITY if root_bone == "" else ZombieRig.rest_global(root_bone).affine_inverse()
	var surf: Dictionary = {"skin": _SurfaceAcc.new(), "kit": _SurfaceAcc.new()}
	for bone: String in parts_by_bone.keys():
		var bi: int = ZombieRig.bone_index(bone)
		var parent: String = ZombieRig.parent_of(bone)
		var pi: int = ZombieRig.bone_index(parent) if parent != "" else bi
		var rest: Transform3D = root_inv * ZombieRig.rest_global(bone)
		for p: Array in parts_by_bone[bone]:
			var prim: Mesh = p[0]
			var xf: Transform3D = p[1]
			var mkey: String = str(p[2])
			var look: Array = _look(kit, mkey)
			var acc: _SurfaceAcc = surf["skin"] if mkey == "skin" else surf["kit"]
			var arrays: Array = prim.surface_get_arrays(0)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var base: int = acc.verts.size()
			var nb: Basis = (rest.basis * xf.basis).inverse().transposed()
			for i: int in verts.size():
				var local: Vector3 = xf * verts[i]           # bone-local
				var model: Vector3 = rest * local
				acc.verts.append(model)
				acc.norms.append((nb * norms[i]).normalized())
				acc.cols.append(look[0] as Color)
				acc.cus0.append_array(PackedFloat32Array([float(look[1]), float(look[2]), float(look[3]), 0.0]))
				acc.cus1.append_array(PackedFloat32Array([model.x, model.y, model.z, 0.0]))
				var w_parent: float = 0.0
				if LIMB_BONES.has(bone) and pi != bi and local.y > -blend and mkey != "eye":
					w_parent = clampf(0.5 * (local.y + blend) / blend, 0.0, 0.5)
				acc.bones.append_array(PackedInt32Array([bi, pi, 0, 0]))
				acc.weights.append_array(PackedFloat32Array([1.0 - w_parent, w_parent, 0.0, 0.0]))
			for i: int in idx.size():
				acc.index.append(idx[i] + base)
	var mesh: ArrayMesh = ArrayMesh.new()
	for name: String in ["skin", "kit"]:
		var acc2: _SurfaceAcc = surf[name]
		if acc2.verts.is_empty():
			continue
		var arr: Array = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = acc2.verts
		arr[Mesh.ARRAY_NORMAL] = acc2.norms
		arr[Mesh.ARRAY_COLOR] = acc2.cols
		arr[Mesh.ARRAY_CUSTOM0] = acc2.cus0
		arr[Mesh.ARRAY_CUSTOM1] = acc2.cus1
		arr[Mesh.ARRAY_BONES] = acc2.bones
		arr[Mesh.ARRAY_WEIGHTS] = acc2.weights
		arr[Mesh.ARRAY_INDEX] = acc2.index
		var flags: int = (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, flags)
		var si: int = mesh.get_surface_count() - 1
		mesh.surface_set_name(si, name)
		mesh.surface_set_material(si, skin_material(_skin_look(kit)) if name == "skin" else kit_material())
	return mesh


static func _skin_look(kit: String) -> String:
	if SOVIET_KITS.has(kit):
		return "frost"   # T-192
	return "bell" if kit == "bellringer" else "base"


class _SurfaceAcc:
	var verts: PackedVector3Array = []
	var norms: PackedVector3Array = []
	var cols: PackedColorArray = []
	var cus0: PackedFloat32Array = []
	var cus1: PackedFloat32Array = []
	var bones: PackedInt32Array = []
	var weights: PackedFloat32Array = []
	var index: PackedInt32Array = []


## A detachable piece (a severed forearm, a head): the triangles of the skinned body whose vertices all belong
## (by dominant bone weight) to the chain under `root_bone`, unskinned, in that bone's rest frame, both surfaces
## with the body's own materials (a sleeve comes off with the arm). Procedural fallback: the legacy primitives.
static func piece_mesh(kit: String, build: String, female: bool, root_bone: String) -> ArrayMesh:
	var key: String = ("legacy:" if legacy_bodies else "") + "piece:%s:%s" % [_cache_key(kit, build, female), root_bone]
	if _meshes.has(key):
		return _meshes[key]
	var mesh: ArrayMesh
	if not legacy_bodies and base_parts(build, female).has("Body"):
		mesh = _cut_piece(build_skinned(kit, build, female), root_bone)
	else:
		var all: Dictionary = body_parts(kit, build, female)
		var parts: Array = []
		var root_inv: Transform3D = ZombieRig.rest_global(root_bone).affine_inverse()
		for bone: String in ZombieRig.chain_of(root_bone):
			var rel: Transform3D = root_inv * ZombieRig.rest_global(bone)
			for p: Array in all.get(bone, []):
				parts.append([p[0], rel * (p[1] as Transform3D), p[2]])
		mesh = build_mesh(kit, parts)
	_meshes[key] = mesh
	return mesh


## The stump cap: a dark disc with a raw red core, placed at a severed joint.
static func stump_mesh() -> ArrayMesh:
	if _stump != null:
		return _stump
	_stump = build_mesh("_", [
		_cyl(0.055, 0.06, 0.03, Vector3(0, -0.01, 0), "dark", Vector3.ZERO, Vector3.ONE, 8),
		_cyl(0.04, 0.045, 0.012, Vector3(0, -0.028, 0), "stump", Vector3.ZERO, Vector3.ONE, 8),
		_sph(0.03, Vector3(0, -0.02, 0), "stump", Vector3(1.0, 0.5, 1.0))])
	return _stump


## The Projekt Wiederkehr armband mark (tools_src/blender/characters/make_textures.py emblem(), ART_FACTIONS.md).
const EMBLEM_TEX: String = "res://assets/ours/characters/zombie_base/tex_armband_wiederkehr.png"


## Gear pieces hung on a bone attachment: name -> [bone, ArrayMesh]. Rolled per instance from the kit's gear table.
static func gear_mesh(piece: String, female: bool = false) -> Array:
	var key: String = "gear:%s:%s" % [piece, "f" if female else "m"]
	if _meshes.has(key):
		return _meshes[key]
	var bone: String = "Head"
	var parts: Array = []
	match piece:
		"helmet":
			parts = [_sph(0.145, Vector3(0, 0.15, 0.008), "helmet", Vector3(1.0, 0.76, 1.06), true, 12),
				_cyl(0.142, 0.172, 0.055, Vector3(0, 0.13, 0.015), "helmet", Vector3(0.12, 0, 0), Vector3(1.0, 1.0, 1.04), 12, false),
				_box(Vector3(0.012, 0.11, 0.012), Vector3(-0.1, 0.06, -0.02), "leather")]
		"cap":
			parts = [_cyl(0.125, 0.128, 0.06, Vector3(0, 0.2, 0), "hat", Vector3.ZERO, Vector3(1, 1, 1.05), 10),
				_box(Vector3(0.13, 0.012, 0.08), Vector3(0, 0.18, -0.14), "hat", Vector3(-0.15, 0, 0))]
		"lamp_cap":
			parts = [_cyl(0.125, 0.13, 0.075, Vector3(0, 0.2, 0), "hat", Vector3.ZERO, Vector3(1, 1, 1.05), 10),
				_box(Vector3(0.14, 0.014, 0.09), Vector3(0, 0.17, -0.14), "hat", Vector3(-0.18, 0, 0)),
				_cyl(0.026, 0.026, 0.07, Vector3(0, 0.215, -0.14), "metal", Vector3(PI * 0.5, 0, 0), Vector3.ONE, 8),
				_cyl(0.021, 0.021, 0.012, Vector3(0, 0.215, -0.177), "lens", Vector3(PI * 0.5, 0, 0), Vector3.ONE, 8)]
		"goggles":
			parts = [_cyl(0.118, 0.118, 0.022, Vector3(0, 0.17, 0), "leather", Vector3(0.1, 0, 0), Vector3(0.9, 1, 1.01), 12, false),
				_cyl(0.03, 0.03, 0.035, Vector3(-0.042, 0.175, -0.105), "metal", Vector3(PI * 0.5 + 0.3, 0, 0), Vector3.ONE, 8),
				_cyl(0.03, 0.03, 0.035, Vector3(0.042, 0.175, -0.105), "metal", Vector3(PI * 0.5 + 0.3, 0, 0), Vector3.ONE, 8),
				_cyl(0.024, 0.024, 0.01, Vector3(-0.042, 0.181, -0.122), "lens", Vector3(PI * 0.5 + 0.3, 0, 0), Vector3.ONE, 8),
				_cyl(0.024, 0.024, 0.01, Vector3(0.042, 0.181, -0.122), "lens", Vector3(PI * 0.5 + 0.3, 0, 0), Vector3.ONE, 8)]
		"wimple":
			parts = [_box(Vector3(0.2, 0.07, 0.24), Vector3(0, 0.2, 0.01), "white"),
				_box(Vector3(0.28, 0.03, 0.2), Vector3(-0.16, 0.22, 0.02), "white", Vector3(0, 0, 0.5)),
				_box(Vector3(0.28, 0.03, 0.2), Vector3(0.16, 0.22, 0.02), "white", Vector3(0, 0, -0.5)),
				_box(Vector3(0.22, 0.24, 0.03), Vector3(0, 0.06, 0.1), "white")]
		"beret":
			# T-142: a commando's beret, pulled down over the right ear
			parts = [_sph(0.128, Vector3(0.03, 0.2, 0.0), "hat", Vector3(1.1, 0.32, 1.05), false, 12),
				_cyl(0.118, 0.118, 0.016, Vector3(0, 0.178, 0), "leather", Vector3(0, 0, -0.12), Vector3.ONE, 12, false)]
		"side_cap":
			# T-142: a folded side cap (a scout's pilotka, a field cap without its badge)
			parts = [_box(Vector3(0.11, 0.07, 0.25), Vector3(0, 0.215, 0.0), "hat", Vector3(0, 0, 0)),
				_box(Vector3(0.13, 0.03, 0.26), Vector3(0, 0.185, 0.0), "hat")]
		"sailor_cap":
			parts = [_cyl(0.13, 0.12, 0.05, Vector3(0, 0.2, 0), "navy", Vector3.ZERO, Vector3(1, 1, 1.05), 10),
				_cyl(0.125, 0.125, 0.018, Vector3(0, 0.175, 0), "dark", Vector3.ZERO, Vector3.ONE, 10),
				_box(Vector3(0.035, 0.012, 0.012), Vector3(0.0, 0.23, 0.0), "white")]
		"hood":
			parts = [_sph(0.14, Vector3(0, 0.13, 0.02), "oilskin", Vector3(1.0, 0.95, 1.05), true, 10),
				_box(Vector3(0.26, 0.12, 0.02), Vector3(0, 0.06, 0.13), "oilskin", Vector3(-0.3, 0, 0))]
		"scarf":
			bone = "Chest"
			parts = [_cyl(0.075, 0.08, 0.06, Vector3(0, 0.3, 0), "knit", Vector3.ZERO, Vector3(1.1, 1, 0.9), 9),
				_box(Vector3(0.07, 0.22, 0.012), Vector3(0.05, 0.17, -0.13), "knit", Vector3(0.1, 0, 0.15))]
		"armband":
			bone = "LeftUpperArm"
			# T-091: sized for the modelled sleeves; the Wiederkehr mark (docs/ART_FACTIONS.md) is a textured patch
			parts = [_cyl(0.081, 0.078, 0.05, Vector3(0, -0.11, 0), "armband", Vector3.ZERO, Vector3.ONE, 12, false)]
		"sling":
			bone = "Chest"
			parts = [_box(Vector3(0.035, 0.6, 0.014), Vector3(0.0, 0.13, -0.122), "leather", Vector3(0, 0, 0.72))]
		"apron":
			bone = "Spine"
			parts = [_box(Vector3(0.3, 0.56, 0.02), Vector3(0, -0.2, -0.13), "leather", Vector3(0.08, 0, 0)),
				_box(Vector3(0.24, 0.22, 0.015), Vector3(0, 0.14, -0.12), "leather")]
		"pack":
			bone = "Chest"
			parts = [_box(Vector3(0.26, 0.3, 0.14), Vector3(0, 0.1, 0.19), "cloth2"),
				_box(Vector3(0.03, 0.4, 0.012), Vector3(-0.1, 0.1, -0.12), "leather"),
				_box(Vector3(0.03, 0.4, 0.012), Vector3(0.1, 0.1, -0.12), "leather")]
		"collar":
			bone = "Chest"
			parts = [_box(Vector3(0.3, 0.26, 0.012), Vector3(0, 0.12, 0.13), "white", Vector3(0.1, 0, 0)),
				_box(Vector3(0.12, 0.08, 0.012), Vector3(0, 0.26, -0.11), "white", Vector3(0.3, 0, 0))]
		"oilskin":
			bone = "Spine"
			parts = [_cyl(0.19, 0.3, 0.7, Vector3(0, -0.3, 0.01), "oilskin", Vector3.ZERO, Vector3(1.05, 1, 0.85), 11, false)]
		"diver_helmet":
			# T-153: the Kielholer diver's brass salvage helmet: the bowl, the corselet on the shoulders, the front port
			# (its glass is the helmet_glass hitbox) and two side ports. Local -Z is the face.
			parts = [_sph(0.205, Vector3(0, 0.12, 0.0), "brass", Vector3(1.0, 1.05, 1.0), false, 14),
				_cyl(0.25, 0.27, 0.07, Vector3(0, -0.07, 0.0), "brass", Vector3.ZERO, Vector3(1.0, 1.0, 0.9), 14, true),
				_cyl(0.085, 0.085, 0.04, Vector3(0, 0.12, -0.2), "brass", Vector3(PI * 0.5, 0, 0), Vector3.ONE, 12),
				_cyl(0.07, 0.07, 0.012, Vector3(0, 0.12, -0.222), "lens", Vector3(PI * 0.5, 0, 0), Vector3.ONE, 12),
				_cyl(0.05, 0.05, 0.03, Vector3(-0.19, 0.13, -0.05), "brass", Vector3(0, 0, PI * 0.5), Vector3.ONE, 10),
				_cyl(0.05, 0.05, 0.03, Vector3(0.19, 0.13, -0.05), "brass", Vector3(0, 0, PI * 0.5), Vector3.ONE, 10),
				_box(Vector3(0.05, 0.05, 0.06), Vector3(0, 0.28, 0.06), "metal")]
		"pilotka":
			# T-192: the Red Army side cap (pilotka) with the small enamel cap star at the front (period issue; dull,
			# never emissive). Local -Z is the face.
			parts = [_box(Vector3(0.11, 0.065, 0.25), Vector3(0, 0.215, 0.005), "hat"),
				_box(Vector3(0.128, 0.028, 0.258), Vector3(0, 0.186, 0.005), "hat"),
				_star(0.0075, Vector3(0, 0.205, -0.124), "accent")]
		"ushanka":
			# T-192: the fur cap with its ear flaps tied up over the crown, the cap star on the front flap
			parts = [_sph(0.14, Vector3(0, 0.155, 0.006), "knit", Vector3(1.04, 0.82, 1.08), true, 12),
				_cyl(0.15, 0.155, 0.07, Vector3(0, 0.16, 0.006), "knit", Vector3.ZERO, Vector3(1.0, 1.0, 1.06), 12, false),
				_box(Vector3(0.15, 0.06, 0.03), Vector3(0, 0.205, -0.14), "knit", Vector3(-0.35, 0, 0)),
				_box(Vector3(0.05, 0.08, 0.13), Vector3(-0.135, 0.215, 0.01), "knit", Vector3(0, 0, 0.45)),
				_box(Vector3(0.05, 0.08, 0.13), Vector3(0.135, 0.215, 0.01), "knit", Vector3(0, 0, -0.45)),
				_star(0.009, Vector3(0, 0.205, -0.158), "accent")]
		"ssh40":
			# T-192: the SSh-40 steel helmet: a round bowl with a short even rim all the way round (no flared skirt)
			parts = [_sph(0.148, Vector3(0, 0.145, 0.006), "helmet", Vector3(1.0, 0.86, 1.06), true, 12),
				_cyl(0.155, 0.168, 0.018, Vector3(0, 0.15, 0.006), "helmet", Vector3.ZERO, Vector3(1.0, 1.0, 1.06), 12, false),
				_box(Vector3(0.012, 0.1, 0.012), Vector3(-0.11, 0.08, -0.01), "leather")]
		"weed":
			# T-153: kelp hanging off a drowned man's shoulders (dark green strips)
			bone = "Chest"
			parts = [_box(Vector3(0.03, 0.32, 0.01), Vector3(-0.14, 0.12, -0.12), "glove", Vector3(0.15, 0, 0.2)),
				_box(Vector3(0.025, 0.26, 0.01), Vector3(0.12, 0.15, -0.125), "glove", Vector3(0.1, 0, -0.25)),
				_box(Vector3(0.03, 0.36, 0.01), Vector3(0.06, 0.1, 0.13), "glove", Vector3(-0.1, 0, 0.1))]
	var m: ArrayMesh = build_mesh("_", parts)
	if piece == "armband" and ResourceLoader.exists(EMBLEM_TEX):
		var q: QuadMesh = QuadMesh.new()
		q.size = Vector2(0.075, 0.047)
		var st: SurfaceTool = SurfaceTool.new()
		st.append_from(q, 0, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-0.0835, -0.11, 0)))
		st.commit(m)
		var em: StandardMaterial3D = StandardMaterial3D.new()
		em.albedo_texture = load(EMBLEM_TEX)
		em.roughness = 0.95
		m.surface_set_material(m.get_surface_count() - 1, em)
		m.surface_set_name(m.get_surface_count() - 1, "emblem")
	var out: Array = [bone, m]
	_meshes[key] = out
	return out


# ================================================================== body parts

## Every part of a body keyed by profile bone: the base body for the build / sex, then the kit's clothes.
static func body_parts(kit: String, build: String, female: bool) -> Dictionary:
	var builds: Dictionary = GLData.table("anim")["builds"]
	var b: Dictionary = builds.get(build, builds["medium"])
	var w: float = float(b.get("w", 1.0))
	var sh: float = float(b.get("shoulder", 1.0))
	var hipw: float = 1.0
	if female:
		var f: Dictionary = builds["female"]
		w *= float(f.get("w", 0.92))
		sh *= float(f.get("shoulder", 0.88))
		hipw = float(f.get("hip", 1.08))
	if kit == "bellringer":
		w *= 0.85
	var out: Dictionary = {}
	for bone: String in ZombieRig.bone_names():
		var parts: Array = _bone_parts(kit, bone, w, sh, hipw, female)
		if not parts.is_empty():
			out[bone] = parts
	return out


static func _bone_parts(v: String, bone: String, w: float, sh: float, hipw: float, female: bool) -> Array:
	var p: Array = []
	var bell: bool = v == "bellringer"
	var sleeve: String = "skin" if bell else ("navy" if v == "sailor" else ("knit" if v == "dockworker" else "cloth"))
	var leg_mat: String = "cloth2" if not bell else "cloth2"
	if v == "sailor":
		leg_mat = "navy"
	elif v == "technician":
		leg_mat = "cloth"
	match bone:
		"Hips":
			p.append(_cyl(0.135 * w * hipw, 0.13 * w * hipw, 0.17, Vector3.ZERO, leg_mat, Vector3.ZERO, Vector3(1.25, 1, 0.82)))
			match v:
				"soldier":
					p.append(_cyl(0.18, 0.27, 0.56, Vector3(0, -0.27, 0.01), "cloth", Vector3.ZERO, Vector3(1.05, 1, 0.82), 11, false))
					p.append(_box(Vector3(0.09, 0.17, 0.012), Vector3(0.2, -0.6, -0.12), "cloth", Vector3(0.1, 0.3, 0.25)))
					p.append(_box(Vector3(0.07, 0.13, 0.012), Vector3(-0.15, -0.6, 0.2), "cloth", Vector3(-0.15, 0, -0.2)))
				"labstaff":
					p.append(_cyl(0.17, 0.22, 0.62, Vector3(0, -0.3, 0.01), "cloth", Vector3.ZERO, Vector3(1.05, 1, 0.82), 11, false))
					p.append(_box(Vector3(0.06, 0.3, 0.012), Vector3(0.12, -0.42, -0.19), "dark", Vector3(0.12, 0, 0.05)))
				"miner":
					p.append(_box(Vector3(0.3, 0.56, 0.02), Vector3(0, -0.2, -0.13), "leather", Vector3(0.08, 0, 0)))
				"bellringer":
					p.append(_cyl(0.15, 0.2, 0.32, Vector3(0, -0.17, 0), "cloth", Vector3.ZERO, Vector3(1.1, 1, 0.85), 7, false))
					p.append(_box(Vector3(0.06, 0.2, 0.012), Vector3(-0.1, -0.36, -0.15), "cloth", Vector3(0, 0, 0.35)))
				"nurse":
					p.append(_cyl(0.165, 0.31, 0.8, Vector3(0, -0.39, 0), "cloth", Vector3.ZERO, Vector3(1.05, 1, 0.9), 12, false))
					p.append(_box(Vector3(0.28, 0.62, 0.015), Vector3(0, -0.3, -0.22), "white", Vector3(0.18, 0, 0)))
				"villager":
					if female:
						p.append(_cyl(0.17, 0.3, 0.78, Vector3(0, -0.38, 0), "cloth2", Vector3.ZERO, Vector3(1.05, 1, 0.9), 12, false))
					else:
						p.append(_cyl(0.15, 0.16, 0.12, Vector3(0, -0.04, 0), "cloth", Vector3.ZERO, Vector3(1.22, 1, 0.84), 10, false))
						p.append(_box(Vector3(0.14, 0.02, 0.02), Vector3(0, 0.07, -0.12), "leather"))
				"technician":
					p.append(_cyl(0.152, 0.152, 0.045, Vector3(0, 0.03, 0), "leather", Vector3.ZERO, Vector3(1.24, 1, 0.86)))
					p.append(_box(Vector3(0.09, 0.09, 0.04), Vector3(0.1, -0.05, -0.12), "cloth2"))
				"sailor":
					p.append(_box(Vector3(0.2, 0.09, 0.03), Vector3(0, -0.03, -0.118), "navy"))
					for i: int in 3:
						p.append(_sph(0.009, Vector3(-0.05 + 0.05 * float(i), -0.03, -0.136), "brass"))
				"dockworker":
					p.append(_cyl(0.155, 0.155, 0.045, Vector3(0, 0.03, 0), "leather", Vector3.ZERO, Vector3(1.24, 1, 0.86)))
					p.append(_box(Vector3(0.05, 0.035, 0.02), Vector3(0, 0.03, -0.13), "metal"))
		"LeftUpperLeg", "RightUpperLeg":
			var flare: float = 1.0
			if v == "sailor":
				flare = 1.12
			p.append(_cyl(0.075 * w, 0.058 * w * flare, 0.44, Vector3(0, -0.22, 0), leg_mat))
			if bell:
				p.append(_box(Vector3(0.05, 0.12, 0.012), Vector3(0.05, -0.3, -0.06), "skin", Vector3(0, 0, 0.3)))
		"LeftLowerLeg", "RightLowerLeg":
			match v:
				"soldier":
					p.append(_cyl(0.056, 0.045, 0.2, Vector3(0, -0.1, 0), "cloth2"))
					p.append(_cyl(0.063, 0.055, 0.23, Vector3(0, -0.29, 0), "leather"))
				"bellringer":
					p.append(_cyl(0.045, 0.036, 0.22, Vector3(0, -0.11, 0), "cloth2"))
					p.append(_cyl(0.035, 0.03, 0.18, Vector3(0, -0.31, 0), "skin"))
				"technician":
					p.append(_cyl(0.052, 0.044, 0.18, Vector3(0, -0.09, 0), "cloth"))
					p.append(_cyl(0.06, 0.054, 0.24, Vector3(0, -0.29, 0), "rubber"))
				"sailor":
					p.append(_cyl(0.058, 0.07, 0.4, Vector3(0, -0.2, 0), "navy"))
				"dockworker":
					p.append(_cyl(0.055, 0.046, 0.16, Vector3(0, -0.08, 0), "cloth2"))
					p.append(_cyl(0.064, 0.058, 0.26, Vector3(0, -0.28, 0), "rubber"))
				"villager":
					if female:
						p.append(_cyl(0.05, 0.04, 0.4, Vector3(0, -0.2, 0), "dark"))
					else:
						p.append(_cyl(0.055, 0.043, 0.4, Vector3(0, -0.2, 0), leg_mat))
						p.append(_box(Vector3(0.04, 0.06, 0.012), Vector3(0.02, -0.15, -0.045), "patch", Vector3(0, 0, 0.2)))
				_:
					p.append(_cyl(0.055, 0.043, 0.4, Vector3(0, -0.2, 0), leg_mat))
		"LeftFoot", "RightFoot":
			var boot: String = "leather"
			match v:
				"bellringer":
					boot = "skin"
				"technician", "dockworker":
					boot = "rubber"
				"nurse", "labstaff":
					boot = "dark"
			p.append(_box(Vector3(0.095, 0.07, 0.22), Vector3(0, -0.03, -0.05), boot))
		"Spine":
			var ab_mat: String = "skin" if bell else ("navy" if v == "sailor" else ("knit" if v == "dockworker" else "cloth"))
			p.append(_cyl(0.145 * w, 0.135 * w, 0.24, Vector3(0, 0.11, 0), ab_mat, Vector3.ZERO, Vector3(1.2, 1, 0.82)))
			match v:
				"soldier":
					p.append(_cyl(0.152, 0.152, 0.05, Vector3(0, 0.02, 0), "leather", Vector3.ZERO, Vector3(1.24, 1, 0.86)))
					p.append(_box(Vector3(0.07, 0.07, 0.05), Vector3(-0.09, 0.02, -0.13), "leather"))
					p.append(_box(Vector3(0.07, 0.07, 0.05), Vector3(0.09, 0.02, -0.13), "leather"))
					p.append(_box(Vector3(0.04, 0.035, 0.02), Vector3(0, 0.02, -0.13), "metal"))
				"miner":
					p.append(_box(Vector3(0.3, 0.26, 0.02), Vector3(0, 0.13, -0.12), "leather"))
				"bellringer":
					for i: int in 3:
						p.append(_box(Vector3(0.2, 0.012, 0.02), Vector3(0, 0.08 + i * 0.05, -0.108), "dark"))
					p.append(_box(Vector3(0.24, 0.1, 0.012), Vector3(0.02, 0.02, -0.11), "cloth", Vector3(0, 0, 0.2)))
				"labstaff":
					p.append(_box(Vector3(0.05, 0.08, 0.015), Vector3(0.07, 0.15, -0.12), "dark", Vector3(0, 0, 0.4)))
				"nurse":
					p.append(_box(Vector3(0.24, 0.22, 0.015), Vector3(0, 0.12, -0.12), "white"))
				"villager":
					p.append(_box(Vector3(0.26, 0.2, 0.014), Vector3(0, 0.12, -0.117), "cloth2"))
					for i: int in 3:
						p.append(_sph(0.009, Vector3(0.0, 0.05 + 0.06 * float(i), -0.126), "dark"))
				"technician":
					p.append(_box(Vector3(0.1, 0.12, 0.02), Vector3(-0.07, 0.1, -0.12), "cloth2"))
					p.append(_box(Vector3(0.1, 0.12, 0.02), Vector3(0.07, 0.1, -0.12), "cloth2"))
				"sailor":
					for i: int in 2:
						p.append(_sph(0.009, Vector3(-0.045 + 0.09 * float(i), 0.12, -0.122), "brass"))
		"Chest":
			var ch_mat: String = "skin" if bell else ("navy" if v == "sailor" else ("knit" if v == "dockworker" else "cloth"))
			var cw: float = (1.05 if bell or w < 0.95 else 1.3) * sh
			p.append(_cyl(0.17 * w, 0.145 * w, 0.3, Vector3(0, 0.15, 0), ch_mat, Vector3.ZERO, Vector3(cw, 1, 0.78)))
			p.append(_sph(0.075 * w, Vector3(-0.19 * w * sh, 0.25, 0), sleeve))
			p.append(_sph(0.075 * w, Vector3(0.19 * w * sh, 0.25, 0), sleeve))
			if female and not bell:
				p.append(_sph(0.055, Vector3(-0.06, 0.15, -0.09), ch_mat, Vector3(1.0, 0.8, 0.7)))
				p.append(_sph(0.055, Vector3(0.06, 0.15, -0.09), ch_mat, Vector3(1.0, 0.8, 0.7)))
			match v:
				"soldier":
					p.append(_cyl(0.085, 0.13, 0.08, Vector3(0, 0.31, 0), "cloth", Vector3.ZERO, Vector3(1.1, 1, 0.9)))
					for i: int in 3:
						p.append(_sph(0.011, Vector3(-0.04, 0.06 + i * 0.08, -0.12), "metal"))
					p.append(_box(Vector3(0.1, 0.16, 0.012), Vector3(0.14, 0.05, -0.1), "dark", Vector3(0, 0, -0.3)))
				"labstaff":
					p.append(_box(Vector3(0.06, 0.2, 0.012), Vector3(-0.06, 0.18, -0.118), "cloth", Vector3(0, 0, 0.18)))
					p.append(_box(Vector3(0.06, 0.2, 0.012), Vector3(0.06, 0.18, -0.118), "cloth", Vector3(0, 0, -0.18)))
					p.append(_box(Vector3(0.05, 0.035, 0.01), Vector3(-0.1, 0.2, -0.125), "patch"))
				"miner":
					p.append(_box(Vector3(0.03, 0.32, 0.014), Vector3(-0.08, 0.14, -0.116), "leather"))
					p.append(_box(Vector3(0.03, 0.32, 0.014), Vector3(0.08, 0.14, -0.116), "leather"))
				"bellringer":
					for i: int in 4:
						p.append(_box(Vector3(0.24, 0.014, 0.02), Vector3(0, 0.06 + i * 0.05, -0.112), "dark"))
					p.append(_cyl(0.07, 0.1, 0.07, Vector3(0, 0.31, 0), "cloth"))
				"nurse":
					p.append(_box(Vector3(0.2, 0.2, 0.014), Vector3(0, 0.13, -0.117), "white"))
					p.append(_box(Vector3(0.46, 0.55, 0.02), Vector3(0, 0.05, 0.13), "cloth2", Vector3(-0.08, 0, 0)))
					p.append(_cyl(0.085, 0.11, 0.06, Vector3(0, 0.31, 0), "white"))
				"villager":
					p.append(_box(Vector3(0.05, 0.26, 0.012), Vector3(-0.055, 0.14, -0.118), "cloth2", Vector3(0, 0, 0.12)))
					p.append(_box(Vector3(0.05, 0.26, 0.012), Vector3(0.055, 0.14, -0.118), "cloth2", Vector3(0, 0, -0.12)))
					if female:
						p.append(_box(Vector3(0.4, 0.3, 0.02), Vector3(0, 0.15, 0.1), "knit", Vector3(-0.15, 0, 0)))
				"technician":
					p.append(_box(Vector3(0.03, 0.3, 0.012), Vector3(0, 0.15, -0.12), "cloth2"))
					p.append(_box(Vector3(0.07, 0.05, 0.01), Vector3(-0.09, 0.22, -0.123), "patch"))
					p.append(_box(Vector3(0.1, 0.07, 0.03), Vector3(0.1, 0.08, -0.115), "cloth2"))
				"sailor":
					for i: int in 3:
						p.append(_sph(0.01, Vector3(-0.05, 0.05 + i * 0.08, -0.122), "brass"))
						p.append(_sph(0.01, Vector3(0.05, 0.05 + i * 0.08, -0.122), "brass"))
					p.append(_box(Vector3(0.1, 0.1, 0.01), Vector3(0, 0.26, -0.11), "white", Vector3(0.3, 0, 0)))
				"dockworker":
					p.append(_cyl(0.08, 0.1, 0.06, Vector3(0, 0.31, 0), "knit", Vector3.ZERO, Vector3(1.1, 1, 0.9)))
					p.append(_cyl(0.02, 0.02, 0.5, Vector3(0.1, 0.14, 0.0), "rope", Vector3(0.0, 0, 0.5), Vector3.ONE, 6))
		"Neck":
			p.append(_cyl(0.048 * w, 0.055 * w, 0.11, Vector3(0, 0.05, 0), "skin"))
			p.append(_box(Vector3(0.03, 0.06, 0.012), Vector3(0.03, 0.05, -0.048), "dark", Vector3(0, 0, 0.3)))
		"Head":
			p.append(_sph(0.115, Vector3(0, 0.11, 0), "skin", Vector3(0.88 * (0.96 if female else 1.0), 1.08, 1.0)))
			p.append(_sph(0.034, Vector3(-0.042, 0.125, -0.086), "dark", Vector3(1.25, 0.85, 0.6)))
			p.append(_sph(0.034, Vector3(0.042, 0.125, -0.086), "dark", Vector3(1.25, 0.85, 0.6)))
			p.append(_sph(0.0135, Vector3(-0.042, 0.124, -0.102), "eye"))
			p.append(_sph(0.0135, Vector3(0.042, 0.124, -0.102), "eye"))
			p.append(_box(Vector3(0.17, 0.026, 0.045), Vector3(0, 0.158, -0.088), "skin"))
			p.append(_box(Vector3(0.026, 0.05, 0.03), Vector3(0, 0.1, -0.112), "skin", Vector3(0.25, 0, 0)))
			p.append(_box(Vector3(0.07, 0.03, 0.01), Vector3(0, 0.058, -0.1), "dark"))
			p.append(_box(Vector3(0.06, 0.012, 0.01), Vector3(0, 0.066, -0.102), "teeth"))
			p.append(_box(Vector3(0.02, 0.05, 0.04), Vector3(-0.1, 0.11, 0), "skin"))
			p.append(_box(Vector3(0.02, 0.05, 0.04), Vector3(0.1, 0.11, 0), "skin"))
			p.append(_box(Vector3(0.04, 0.012, 0.004), Vector3(0.05, 0.19, -0.092), "dark", Vector3(0, 0, 0.6)))
			if female and v != "nurse":
				p.append(_sph(0.12, Vector3(0, 0.14, 0.02), "hair", Vector3(0.92, 0.9, 1.0), true))
				p.append(_sph(0.06, Vector3(0, 0.08, 0.1), "hair", Vector3(1.0, 1.2, 0.8)))
			elif v in ["labstaff", "villager", "sailor", "dockworker", "technician"]:
				p.append(_sph(0.118, Vector3(0, 0.13, 0.005), "hair", Vector3(0.9, 0.95, 1.0), true))
			elif bell:
				p.append(_box(Vector3(0.012, 0.06, 0.012), Vector3(-0.04, 0.22, 0.02), "hair", Vector3(0, 0, 0.5)))
				p.append(_box(Vector3(0.012, 0.05, 0.012), Vector3(0.05, 0.21, 0.04), "hair", Vector3(0, 0, -0.6)))
		"Jaw":
			p.append(_box(Vector3(0.085, 0.035, 0.085), Vector3(0, -0.012, -0.045), "skin"))
			p.append(_box(Vector3(0.055, 0.011, 0.008), Vector3(0, 0.008, -0.086), "teeth"))
		"LeftUpperArm", "RightUpperArm":
			p.append(_cyl(0.055 * w, 0.046 * w, 0.31, Vector3(0, -0.15, 0), sleeve))
			if v == "soldier" or v == "labstaff":
				p.append(_box(Vector3(0.05, 0.1, 0.012), Vector3(0.0, -0.22, 0.05), "cloth", Vector3(0.3, 0, 0)))
		"LeftLowerArm", "RightLowerArm":
			var hand: String = "glove" if v == "labstaff" else ("rubber" if v == "technician" else "skin")
			if bell:
				p.append(_cyl(0.042 * w, 0.033 * w, 0.27, Vector3(0, -0.135, 0), "skin"))
			else:
				p.append(_cyl(0.05 * w, 0.047 * w, 0.13, Vector3(0, -0.065, 0), sleeve))
				p.append(_cyl(0.04 * w, 0.033 * w, 0.16, Vector3(0, -0.19, 0), hand if v in ["labstaff", "technician"] else "skin"))
		"LeftHand", "RightHand":
			var hand2: String = "glove" if v == "labstaff" else ("rubber" if v == "technician" else "skin")
			p.append(_box(Vector3(0.06, 0.085, 0.03), Vector3(0, -0.02, -0.005), hand2))
			for f: float in [-0.021, 0.0, 0.021]:
				p.append(_box(Vector3(0.013, 0.075, 0.013), Vector3(f, -0.085, -0.025), hand2, Vector3(0.55, 0, 0)))
			p.append(_box(Vector3(0.014, 0.05, 0.014), Vector3(0.036, -0.02, -0.02), hand2, Vector3(0.3, 0, -0.5)))
	return p
