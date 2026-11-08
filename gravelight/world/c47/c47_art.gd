class_name C47Art
extends RefCounted
## UPDATE 12 section 5 (T-211): GRAVELIGHT ONE's model, whichever source is built. tools/c47/build.sh turns a C-47
## the owner downloaded (assets/user_supplied/u12/c47/<model>/, git-ignored) into
## assets/third_party/sketchfab/<id>/{intact,crashed}.glb with its SOURCE.txt / LICENSE.txt (the credits pick it up
## from there, data/credits_art.json); without one, our stand-in (assets/ours/world/c47_{intact,crashed}/model.glb,
## tools/c47/c47_airframe.py) is used. The first that exists in SOURCES wins, so the swap needs no code change.
##
## instance(kind) maps the GLB's named material slots once (c47_* onto c47_skin / c47_decal, mats_* / lib_* through
## WorldArt; a real model's own textured materials onto c47_skin with their albedo, so its scorch, soot and snow
## still apply), wires the LODs (the build's <piece>_LOD0/1/2, _INT the interior, _ALL ground pieces) to visibility
## ranges from data/gravelight/c47_wreck.json `lod`, and adds the far impostor (crashed only). No collision ever
## comes from the GLB: the map's colliders are gen_map00's (the hull) and data/gravelight/c47_colliders.json.

const LAYOUT: String = "res://data/gravelight/c47_wreck.json"
## [folder, credit id] in order of preference (UPDATE 12 section 5.1's table).
const SOURCES: Array = [
	["res://assets/third_party/sketchfab/c47-manilov-ap/", "c47-manilov-ap"],
	["res://assets/third_party/sketchfab/c47-dakota-kn645-mgg8/", "c47-dakota-kn645-mgg8"],
	["res://assets/third_party/sketchfab/c47-skytrain-spark-customs/", "c47-skytrain-spark-customs"],
	["res://assets/third_party/sketchfab/dc3-manilov-ap/", "dc3-manilov-ap"],
]
const STANDIN: String = "res://assets/ours/world/c47_%s/model.glb"
const SKIN: Shader = preload("res://gravelight/world/c47/c47_skin.gdshader")
const DECAL: Shader = preload("res://gravelight/world/c47/c47_decal.gdshader")
const IMPOSTOR: Shader = preload("res://gravelight/world/c47/c47_impostor.gdshader")
## slot -> [paint, roughness, metallic, snow]
const PAINTS: Dictionary = {
	"c47_od": ["#3b3e27", 0.74, 0.0, 1.0], "c47_ng": ["#4d5052", 0.7, 0.0, 1.0], "c47_int": ["#454c3b", 0.78, 0.0, 0.0],
	"c47_metal": ["#7d7f80", 0.45, 0.75, 0.6], "c47_black": ["#111111", 0.62, 0.0, 0.6], "c47_yellow": ["#86681c", 0.6, 0.0, 0.6],
	"c47_exhaust": ["#33251c", 0.65, 0.5, 0.4], "c47_char": ["#0b0a09", 0.95, 0.0, 0.7],
}

static var _mats: Dictionary = {}
static var _scenes: Dictionary = {}
static var _layout: Dictionary = {}


## "standin" or the credit id of the third-party model in use.
static func source_id() -> String:
	for s: Array in SOURCES:
		if ResourceLoader.exists(str(s[0]) + "crashed.glb"):
			return str(s[1])
	return "standin"


static func glb_path(kind: String) -> String:
	for s: Array in SOURCES:
		var p: String = str(s[0]) + kind + ".glb"
		if ResourceLoader.exists(p):
			return p
	return STANDIN % kind


## The folder of the model in use (its SOURCE.txt, impostor.png).
static func folder(kind: String) -> String:
	return glb_path(kind).get_base_dir() + "/"


static func layout() -> Dictionary:
	if _layout.is_empty():
		_layout = GLData.load_json(LAYOUT)
	return _layout


static func has(kind: String) -> bool:
	return _scene(kind) != null


static func _scene(kind: String) -> PackedScene:
	if WorldArt.disabled():
		return null
	var p: String = glb_path(kind)
	if not _scenes.has(p):
		_scenes[p] = load(p) as PackedScene if ResourceLoader.exists(p) else null
	return _scenes[p]


## A fresh, material-mapped instance of "crashed" or "intact" (null when no model is built / --no-world-art).
static func instance(kind: String, node_name: String = "C47Model") -> Node3D:
	var ps: PackedScene = _scene(kind)
	if ps == null:
		return null
	var n: Node3D = ps.instantiate() as Node3D
	n.name = node_name
	for mi: MeshInstance3D in WorldArt.meshes(n):
		_map_mesh(mi.mesh)
		_lod(mi, kind)
	if kind == "crashed":
		var imp: MeshInstance3D = impostor(kind)
		if imp != null:
			n.add_child(imp)
	return n


static func _lod(mi: MeshInstance3D, kind: String) -> void:
	var lod: Dictionary = layout().get("lod", {})
	var l1: float = float(lod.get("lod1_m", 32.0))
	var l2: float = float(lod.get("lod2_m", 65.0))
	var imp: float = float(lod.get("impostor_m", 120.0)) if kind == "crashed" else 0.0
	var inner: float = float(lod.get("interior_m", 38.0))
	var m: float = float(lod.get("margin_m", 4.0))
	var nm: String = String(mi.name)
	mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	if nm.ends_with("_LOD0"):
		mi.visibility_range_end = l1
		mi.visibility_range_end_margin = m
	elif nm.ends_with("_LOD1"):
		mi.visibility_range_begin = l1
		mi.visibility_range_begin_margin = m
		mi.visibility_range_end = l2
		mi.visibility_range_end_margin = m
	elif nm.ends_with("_LOD2"):
		mi.visibility_range_begin = l2
		mi.visibility_range_begin_margin = m
		mi.visibility_range_end = imp
		mi.visibility_range_end_margin = m if imp > 0.0 else 0.0
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	elif nm.ends_with("_INT"):
		mi.visibility_range_end = inner
		mi.visibility_range_end_margin = m
	elif nm.ends_with("_ALL"):
		mi.visibility_range_end = imp
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The far view: a Y-billboard card with the build's 8-view atlas, from impostor_m on (null when no atlas).
static func impostor(kind: String) -> MeshInstance3D:
	var png: String = folder(kind) + "impostor.png"
	if not ResourceLoader.exists(png):
		return null
	var stats: Dictionary = GLData.load_json(folder(kind) + "stats.json") if FileAccess.file_exists(folder(kind) + "stats.json") else {}
	var info: Dictionary = stats.get("impostor", {}) if stats.get("impostor") is Dictionary else {}
	var w: float = float(info.get("width_m", 50.0))
	var c: Array = info.get("center", [0.0, 2.0, 0.0])
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Impostor"
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(w, w * 0.5)
	mi.mesh = q
	var sm: ShaderMaterial = ShaderMaterial.new()
	sm.shader = IMPOSTOR
	sm.set_shader_parameter("atlas", load(png))
	sm.set_shader_parameter("frames", int(info.get("frames", 8)))
	sm.set_shader_parameter("cols", int(info.get("cols", 4)))
	sm.set_shader_parameter("rows", int(info.get("rows", 2)))
	mi.material_override = sm
	mi.position = Vector3(float(c[0]), float(c[1]), float(c[2]))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# a card the size of the whole site, drawn only from impostor_m off: never "in" a doorway (DoorClearance)
	mi.set_meta(&"clearance_ignore", true)
	var lod: Dictionary = layout().get("lod", {})
	mi.visibility_range_begin = float(lod.get("impostor_m", 120.0))
	mi.visibility_range_begin_margin = float(lod.get("margin_m", 4.0))
	return mi


# ---------------------------------------------------------------- materials

static func _map_mesh(m: Mesh) -> void:
	if m == null or m.has_meta("c47_mapped"):
		return
	m.set_meta("c47_mapped", true)
	if m is ArrayMesh:
		fix_flipped_normals(m as ArrayMesh)
	for s: int in m.get_surface_count():
		var cur: Material = m.surface_get_material(s)
		if cur == null:
			continue
		var mapped: Material = mat(cur.resource_name, cur)
		if mapped != null:
			m.surface_set_material(s, mapped)


## T-214: the torn skin's few faces whose vertex normals point against their winding (49 of the fuselage's 14,492:
## peeled petals at the tears) were lit and snowed on as if they faced the sky while the cabin saw their inside:
## pure-white triangles in the roof. Each such face gets its own vertices with the normal turned to its winding.
## Returns how many faces it turned. (A real model's import goes through the same check.)
static func fix_flipped_normals(m: ArrayMesh) -> int:
	var turned: int = 0
	var surfs: Array = []
	for si: int in m.get_surface_count():
		var arr: Array = m.surface_get_arrays(si)
		var vx: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nr: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var bad: Array[int] = []
		if not nr.is_empty() and not ix.is_empty() and m.surface_get_primitive_type(si) == Mesh.PRIMITIVE_TRIANGLES:
			for f: int in ix.size() / 3:
				var a: int = ix[f * 3]
				var b: int = ix[f * 3 + 1]
				var c: int = ix[f * 3 + 2]
				var wn: Vector3 = (vx[c] - vx[a]).cross(vx[b] - vx[a])   # Godot's front face is clockwise
				if wn.dot(nr[a] + nr[b] + nr[c]) < 0.0:
					bad.append(f)
		surfs.append([arr, bad])
		turned += bad.size()
	if turned == 0:
		return 0
	var mats: Array = []
	var names: Array = []
	var prims: Array = []
	for si2: int in m.get_surface_count():
		mats.append(m.surface_get_material(si2))
		names.append(m.surface_get_name(si2))
		prims.append(m.surface_get_primitive_type(si2))
	m.clear_surfaces()
	for si3: int in surfs.size():
		var arr2: Array = surfs[si3][0]
		var bad2: Array = surfs[si3][1]
		if not bad2.is_empty():
			arr2 = _turn_faces(arr2, bad2)
		m.add_surface_from_arrays(prims[si3], arr2)
		m.surface_set_material(si3, mats[si3])
		m.surface_set_name(si3, str(names[si3]))
	return turned


## `arr` with each face in `bad` given its own three vertices (copied from its corners) whose normals (and
## tangents) are turned around.
static func _turn_faces(arr: Array, bad: Array) -> Array:
	var out: Array = arr.duplicate()
	var ix: PackedInt32Array = (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).duplicate()
	var per_vertex: Array = []
	for k: int in Mesh.ARRAY_MAX:
		if k == Mesh.ARRAY_INDEX or arr[k] == null:
			continue
		var n0: int = (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var a: Variant = arr[k]
		var sz: int = a.size()
		if sz % n0 == 0 and sz > 0:
			per_vertex.append([k, sz / n0])
			out[k] = a.duplicate()
	var nv: int = (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	for f: int in bad:
		for j: int in 3:
			var src: int = ix[f * 3 + j]
			for pv: Array in per_vertex:
				var k2: int = pv[0]
				var w: int = pv[1]
				for e: int in w:
					var val: Variant = arr[k2][src * w + e]
					if k2 == Mesh.ARRAY_NORMAL:
						val = -Vector3(val)
					elif k2 == Mesh.ARRAY_TANGENT and e < 3:
						val = -float(val)
					out[k2].append(val)
			ix[f * 3 + j] = nv
			nv += 1
	out[Mesh.ARRAY_INDEX] = ix
	return out


## The game material for a GLB slot (`cur` = the imported one, for the slots that keep their texture).
static func mat(slot: String, cur: Material = null) -> Material:
	var key: String = slot
	if not PAINTS.has(slot) and not slot.begins_with("c47_") and not slot.begins_with("mats_") and not slot.begins_with("lib_") and slot != "linen_chute":
		key = "src:" + str(cur.get_instance_id() if cur != null else 0)
	if _mats.has(key):
		return _mats[key]
	var out: Material = _build(slot, cur)
	_mats[key] = out
	return out


static func _wear(sm: ShaderMaterial) -> void:
	var a: Texture2D = MaterialLibrary.texture("wreck", "albedo")
	var nrm: Texture2D = MaterialLibrary.texture("wreck", "normal")
	if a != null:
		sm.set_shader_parameter("wear_tex", a)
	if nrm != null:
		sm.set_shader_parameter("wear_normal", nrm)


static func _build(slot: String, cur: Material) -> Material:
	if PAINTS.has(slot):
		var p: Array = PAINTS[slot]
		var sm: ShaderMaterial = ShaderMaterial.new()
		sm.shader = SKIN
		sm.resource_name = slot
		sm.set_shader_parameter("paint_color", Color(str(p[0])))
		sm.set_shader_parameter("roughness_base", float(p[1]))
		sm.set_shader_parameter("metal_amount", float(p[2]))
		sm.set_shader_parameter("snow_amount", float(p[3]))
		if slot == "c47_int":
			sm.set_shader_parameter("wear_amount", 0.3)
		_wear(sm)
		return sm
	match slot:
		"c47_decal":
			var dm: ShaderMaterial = ShaderMaterial.new()
			dm.shader = DECAL
			dm.resource_name = slot
			var tex: Texture2D = _albedo_of(cur)
			dm.set_shader_parameter("use_tex", tex != null)
			if tex != null:
				dm.set_shader_parameter("albedo_tex", tex)
			dm.set_shader_parameter("paint_color", Color(1, 1, 1))
			dm.set_shader_parameter("wear_amount", 0.35)
			_wear(dm)
			return dm
		"c47_frost":
			var fm: StandardMaterial3D = (cur as StandardMaterial3D).duplicate() if cur is StandardMaterial3D else StandardMaterial3D.new()
			fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			fm.roughness = 0.7
			fm.albedo_color = Color(0.85, 0.9, 0.96, 0.75)
			return fm
		"c47_glass":
			var g: StandardMaterial3D = StandardMaterial3D.new()
			g.resource_name = slot
			g.albedo_color = Color(0.08, 0.1, 0.12, 0.55)
			g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			g.roughness = 0.08
			g.metallic_specular = 1.0
			g.cull_mode = BaseMaterial3D.CULL_DISABLED
			return g
		"c47_rubber":
			var r: StandardMaterial3D = StandardMaterial3D.new()
			r.albedo_color = Color(0.035, 0.035, 0.035)
			r.roughness = 0.9
			return r
		"c47_light_red", "c47_light_green", "c47_light_white":
			var l: StandardMaterial3D = StandardMaterial3D.new()
			l.resource_name = slot
			var c: Color = {"c47_light_red": Color(1.0, 0.12, 0.06), "c47_light_green": Color(0.15, 1.0, 0.35), "c47_light_white": Color(1.0, 0.95, 0.85)}[slot]
			l.albedo_color = c * 0.35
			l.emission_enabled = true
			l.emission = c
			l.emission_energy_multiplier = 0.0   # the lights are off; C47Intact turns them on
			return l
		"linen_chute":
			return Mats.get_mat("linen")
	if slot.begins_with("mats_") or slot.begins_with("lib_"):
		return WorldArt.mat(slot)
	# a real model's own material: its texture under our weathering
	if cur is BaseMaterial3D:
		var b: BaseMaterial3D = cur as BaseMaterial3D
		var sm2: ShaderMaterial = ShaderMaterial.new()
		sm2.shader = SKIN
		sm2.resource_name = slot
		sm2.set_shader_parameter("paint_color", b.albedo_color)
		if b.albedo_texture != null:
			sm2.set_shader_parameter("use_tex", true)
			sm2.set_shader_parameter("albedo_tex", b.albedo_texture)
		if b.normal_enabled and b.normal_texture != null:
			sm2.set_shader_parameter("use_normal_tex", true)
			sm2.set_shader_parameter("normal_tex", b.normal_texture)
		sm2.set_shader_parameter("roughness_base", clampf(b.roughness, 0.55, 1.0))
		sm2.set_shader_parameter("metal_amount", b.metallic * 0.6)
		sm2.set_shader_parameter("wear_amount", 0.25)
		_wear(sm2)
		return sm2
	return null


static func _albedo_of(m: Material) -> Texture2D:
	if m is BaseMaterial3D:
		return (m as BaseMaterial3D).albedo_texture
	return null


## The credit line of the model in use ("" for our stand-in): its SOURCE.txt's "Credit line:".
static func credit_line() -> String:
	if source_id() == "standin":
		return ""
	var f: String = folder("crashed") + "SOURCE.txt"
	for line: String in FileAccess.get_file_as_string(f).split("\n"):
		if line.to_lower().begins_with("credit line:"):
			return line.substr(12).strip_edges()
	return ""


static func reset() -> void:
	_mats = {}
	_scenes = {}
	_layout = {}
