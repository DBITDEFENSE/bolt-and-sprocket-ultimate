class_name Arms
extends RefCounted
## Per-character first-person arms (UPDATE_05 section 2 "Arms", T-089): the hand, forearm and sleeve meshes
## WeaponHolder puts on its two-bone IK rig, loaded from assets/ours/arms/<character>.glb (made by
## tools_src/blender/arms/make_arms.py in exactly the frames of the procedural arms in WeaponModels, so the IK,
## the sway and the reload choreography are untouched):
##   hand(left, grip_radius, pose)  "fist" / "trigger" (right: index finger on the trigger) / "open" (left: a looser
##                                  cup for a handguard), the nearest of three grip radii (14 / 19 / 27 mm);
##   forearm()                      the cuff piece (origin = wrist, +Y up the forearm);
##   sleeve()                       a unit sleeve tube the holder stretches between wrist, elbow and shoulder.
## The character is GameState.character_of(the holder's player) (Dutch, Peg, Deacon, Wren, Bolt, Vendelin;
## docs/gravelight/CHARACTERS.md). A character without a set falls back to Dutch's; without any GLB (or with
## GLSettings "greybox_arms") the procedural WeaponModels arms are used, so nothing depends on the files.

const DIR: String = "res://assets/ours/arms/"
const FALLBACK: StringName = &"dutch"
const RADII: Dictionary = {"s": 0.014, "m": 0.019, "l": 0.027}

static var _scenes: Dictionary = {}     # character -> Node3D (the instantiated GLB, kept as a mesh library)
static var _missing: Dictionary = {}    # character -> true when the GLB is absent


## The arms set a player uses: their survivor's, or Dutch's when that survivor has no set yet.
static func character_for(player: Player) -> StringName:
	var ch: StringName = GameState.character_of(player.player_id) if player != null else GameState.character_id
	if ch == &"" or not available(ch):
		return FALLBACK if available(FALLBACK) else &""
	return ch


## True when a GLB for this character is in the project (and imported).
static func available(ch: StringName) -> bool:
	if bool(GLSettings.values.get("greybox_arms", false)):
		return false
	if _missing.has(ch):
		return false
	if _scenes.has(ch):
		return true
	var path: String = DIR + String(ch) + ".glb"
	if not ResourceLoader.exists(path):
		if not MapPacks.pending():   # T-139: in the browser the arms arrive with a game pack; don't remember a miss before
			_missing[ch] = true
		return false
	var ps: PackedScene = load(path) as PackedScene
	if ps == null:
		_missing[ch] = true
		return false
	_scenes[ch] = ps.instantiate()
	return true


static func _mesh(ch: StringName, node_name: String) -> Mesh:
	if not available(ch):
		return null
	var key: String = String(ch) + "|" + node_name
	if _dressed.has(key):
		return _dressed[key]
	var n: MeshInstance3D = (_scenes[ch] as Node).find_child(node_name, true, false) as MeshInstance3D
	var m: Mesh = n.mesh if n != null else null
	if m != null and not bool(GLSettings.values.get("plain_arms", false)):
		m = dress(m)
	_dressed[key] = m
	return m


# ------------------------------------------------------------------ the surface detail (2026-11-12)

## 2026-11-12 (the owner: the first-person hands were "plain untextured shapes"): every surface of the arms GLB
## (flat Principled colours) is drawn with arms.gdshader: its colour, roughness and metal kept, the ambientCG
## fabric or leather laid over it in object space, a pore grain on skin. GLSettings "plain_arms" keeps the GLB's own.
const ARMS_SHADER: String = "res://assets/materials/shaders/arms.gdshader"
const DETAIL: Dictionary = {
	"fabric": ["res://assets/third_party/ambientcg/fabric-031/textures/Fabric031_", 11.0, 0.55, 0.75],    # [path prefix, repeats/m, albedo, normal]
	"leather": ["res://assets/third_party/ambientcg/leather-014/textures/Leather014_", 9.0, 0.45, 0.8],
	"skin": ["res://assets/third_party/ambientcg/leather-014/textures/Leather014_", 34.0, 0.0, 0.18],
	"metal": ["res://assets/third_party/ambientcg/leather-014/textures/Leather014_", 20.0, 0.0, 0.08],
}
static var _dressed: Dictionary = {}    # "<character>|<node>" -> Mesh
static var _shader_mats: Dictionary = {}
static var _means: Dictionary = {}


## A copy of `src` whose surfaces use the arms shader (the mesh data is shared, only the materials differ).
static func dress(src: Mesh) -> Mesh:
	var m: Mesh = src.duplicate(false)
	for si: int in m.get_surface_count():
		var sm: StandardMaterial3D = m.surface_get_material(si) as StandardMaterial3D
		if sm != null:
			m.surface_set_material(si, material_for(sm))
	return m


## The kind of detail a surface gets, from its material's name (make_arms.py: glove, palm, skin, strap, cuff,
## sleeve, button) and its look: metal (Vendelin's brass hands, buttons), leather (smooth gloves, palms, straps),
## fabric (sleeves, cuffs, wool and work gloves: rough), skin.
static func kind_of(sm: StandardMaterial3D) -> String:
	var nm: String = String(sm.resource_name).to_lower()
	if sm.metallic > 0.5 or nm.begins_with("button"):
		return "metal"
	if nm.begins_with("skin"):
		return "skin"
	if nm.begins_with("sleeve") or nm.begins_with("cuff"):
		return "fabric"
	if nm.begins_with("glove") or nm.begins_with("palm") or nm.begins_with("strap"):
		return "leather" if sm.roughness <= 0.78 else "fabric"
	return "fabric"


static func material_for(sm: StandardMaterial3D) -> Material:
	if _shader_mats.has(sm):
		return _shader_mats[sm]
	var sh: Shader = load(ARMS_SHADER) as Shader
	if sh == null:
		return sm
	var kind: String = kind_of(sm)
	var d: Array = DETAIL[kind]
	var pre: String = str(d[0])
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("base_color", sm.albedo_color)
	m.set_shader_parameter("roughness", sm.roughness)
	m.set_shader_parameter("metallic", sm.metallic)
	m.set_shader_parameter("kind", ["fabric", "leather", "skin", "metal"].find(kind))
	for slot: String in ["albedo", "normal", "orm"]:
		var t: Texture2D = load(pre + slot + ".png") as Texture2D if ResourceLoader.exists(pre + slot + ".png") else null
		if t != null:
			m.set_shader_parameter("detail_" + slot, t)
	m.set_shader_parameter("detail_mean", _mean_of(pre + "albedo.png"))
	m.set_shader_parameter("detail_scale", float(d[1]))
	m.set_shader_parameter("albedo_amount", float(d[2]))
	m.set_shader_parameter("normal_strength", float(d[3]))
	m.set_shader_parameter("orm_amount", 0.0 if kind == "metal" or kind == "skin" else 0.5)
	_shader_mats[sm] = m
	return m


## The mean luminance of a detail texture (sampled on a grid), so the detail centres on the character's colour.
static func _mean_of(path: String) -> float:
	if _means.has(path):
		return _means[path]
	var mean: float = 0.5
	var t: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	var img: Image = t.get_image() if t != null else null
	if img != null:
		if img.is_compressed():
			img.decompress()
		var sum: float = 0.0
		var cnt: int = 0
		var step: int = maxi(1, img.get_width() / 32)
		for y: int in range(0, img.get_height(), step):
			for x: int in range(0, img.get_width(), step):
				var c: Color = img.get_pixel(x, y)
				sum += (c.r + c.g + c.b) / 3.0
				cnt += 1
		if cnt > 0:
			mean = sum / float(cnt)
	_means[path] = mean
	return mean


static func _radius_key(r: float) -> String:
	var best: String = "m"
	var best_d: float = INF
	for k: String in RADII.keys():
		var d: float = absf(float(RADII[k]) - r)
		if d < best_d:
			best_d = d
			best = k
	return best


## A hand mesh in the fist frame (origin = centre of the gripped part, grip axis +Y, palm +X for the right hand).
## null when the character has no set (the holder then uses WeaponModels.hand_mesh).
static func hand(ch: StringName, left: bool, grip_radius: float, pose: String = "fist") -> Mesh:
	var p: String = pose
	if left and p == "trigger":
		p = "fist"
	if not left and p == "open":
		p = "fist"
	return _mesh(ch, "Hand%s_%s_%s" % ["L" if left else "R", p, _radius_key(grip_radius)])


## The forearm cuff piece (origin = wrist, +Y up the forearm), or null.
static func forearm(ch: StringName) -> Mesh:
	return _mesh(ch, "Forearm")


## The unit sleeve tube (height 1 along Y, centred), or null.
static func sleeve(ch: StringName) -> Mesh:
	return _mesh(ch, "Sleeve")


## The wrist point of a hand in its frame: the same as the procedural hand's, so the IK chain is unchanged.
static func hand_wrist(left: bool, grip_radius: float) -> Vector3:
	return WeaponModels.hand_wrist(left, grip_radius)


## Drops the cached sets (tests, regenerated GLBs).
static func reset() -> void:
	for n: Node in _scenes.values():
		n.free()
	_scenes.clear()
	_missing.clear()
