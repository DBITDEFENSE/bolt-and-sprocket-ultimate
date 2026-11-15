class_name PeopleBodies
extends RefCounted
## The named people's bodies (T-092, UPDATE_05 section 4; docs/CHARACTER_PIPELINE.md section 9): the squad, Jakub,
## the Map 0 patrons and survivors, the Cousins. Each person is one Blender-built GLB
## (assets/ours/characters/people/char_person_<id>.glb, tools/build_people.sh) skinned to the ZombieRig bone names;
## `mesh(id)` merges it into the same two-surface layout as a zombie (surface 0 skin with the shared skin shader,
## surface 1 the face parts, hair and clothes with the shared kit shader: two draw calls) and keeps the face's blend
## shapes (people.json "shapes": blink, jaw_open, fear, determined, pain, smile) on both surfaces, plus Godot's mesh
## LODs. `mesh(id, true)` is the same person risen (the infection skin, the violet eyes) for a patron or survivor who
## turns. Colours: the person's palette (people.json, sRGB) over ZombieBody.KEY_LOOK (linear); the skin is the shared living
## texture set times the person's tone times the painted skin (lips, cheeks, stubble, doll paint).
## `legacy` (`-- --legacy-people`) keeps the old primitive bodies for before / after shots.

const PEOPLE_JSON: String = "res://data/gravelight/art/people.json"
## Part keys the kit shader treats as fabric (1 wool, 2 knit, 3 leather, 4 rubber, 5 canvas / linen).
const DETAIL: Dictionary = {"cloth": 1, "cloth2": 1, "cloth3": 1, "navy": 1, "hat": 1, "armband": 1, "accent": 1,
	"knit": 2, "leather": 3, "glove": 4, "rubber": 4, "oilskin": 4, "white": 5, "patch": 5, "rope": 5, "canvas": 5}
## Looks for the keys T-092 added (colour, roughness, metallic, emission); the rest come from ZombieBody.KEY_LOOK.
const LOOK: Dictionary = {
	"cloth": [Color(0.32, 0.3, 0.26), 0.95, 0.0, 0.0],
	"cloth2": [Color(0.26, 0.25, 0.24), 0.95, 0.0, 0.0],
	"cloth3": [Color(0.22, 0.21, 0.2), 0.95, 0.0, 0.0],
	"canvas": [Color(0.36, 0.33, 0.22), 0.95, 0.0, 0.0],
	"accent": [Color(0.4, 0.15, 0.12), 0.9, 0.0, 0.0],
	"brow": [Color(0.1, 0.08, 0.07), 0.9, 0.0, 0.0],
	"stitch": [Color(0.18, 0.1, 0.12), 0.9, 0.0, 0.0],
	"eye_white": [Color(0.78, 0.75, 0.7), 0.18, 0.0, 0.0],
	"iris": [Color(0.16, 0.12, 0.09), 0.12, 0.0, 0.0],
	"dark": [Color(0.03, 0.02, 0.02), 0.3, 0.0, 0.0],
}

static var legacy: bool = false
static var _cfg: Dictionary = {}
static var _meshes: Dictionary = {}
static var _porcelain: ShaderMaterial = null
static var _risen: ShaderMaterial = null


static func cfg() -> Dictionary:
	if _cfg.is_empty():
		_cfg = GLData.load_json(PEOPLE_JSON)
		for a: String in OS.get_cmdline_user_args():
			if a == "--legacy-people":
				legacy = true
	return _cfg


static func ids() -> PackedStringArray:
	return PackedStringArray((cfg().get("people", {}) as Dictionary).keys())


static func row(id: String) -> Dictionary:
	return (cfg().get("people", {}) as Dictionary).get(id, {})


static func shape_names() -> PackedStringArray:
	return PackedStringArray(cfg().get("shapes", []))


static func path_of(id: String) -> String:
	return str(cfg().get("dir", "res://assets/ours/characters/people")).path_join(str(cfg().get("file", "char_person_%s.glb")) % id)


## True when this person has a built GLB and the modelled bodies are on (not the legacy primitives).
static func available(id: String) -> bool:
	cfg()
	return not legacy and not row(id).is_empty() and ResourceLoader.exists(path_of(id))


## Uniform scale of the person's skeleton (people.json "height"; visual only).
static func height_of(id: String) -> float:
	return float(row(id).get("height", 1.0))


## The GLB's mesh objects as {name: [arrays, blend shape arrays]}, bones remapped to ZombieRig indices.
static func glb_parts(id: String) -> Dictionary:
	var out: Dictionary = {}
	var ps: PackedScene = load(path_of(id)) as PackedScene
	if ps == null:
		return out
	var root: Node = ps.instantiate()
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		var am: ArrayMesh = mi.mesh as ArrayMesh
		if am == null or am.get_surface_count() == 0:
			continue
		var arrays: Array = am.surface_get_arrays(0)
		_remap_binds(arrays, mi.skin)
		var names: PackedStringArray = []
		for b: int in am.get_blend_shape_count():
			names.append(String(am.get_blend_shape_name(b)))
		out[String(mi.name)] = [arrays, am.surface_get_blend_shape_arrays(0), names]
	root.free()
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


static func _color(a: Variant, fallback: Color) -> Color:
	if a is Array and (a as Array).size() >= 3:
		return Color(float(a[0]), float(a[1]), float(a[2]))
	return fallback


## colour / roughness / metallic / emission of a part key for this person (risen: the dead's eyes and lids).
static func look_of(id: String, key: String, risen: bool = false) -> Array:
	var r: Dictionary = row(id)
	var tone: Color = _color(r.get("tone"), Color(0.62, 0.5, 0.44))
	var pal: Dictionary = r.get("palette", {})
	if risen:
		match key:
			"eye_white", "iris":
				return [Color(0.62, 0.28, 0.95), 0.3, 0.0, 1.4]   # the violet glow (dimmer than a horde eye: a whole eyeball)
			"lid":
				return [Color(0.48, 0.5, 0.52) * 0.9, 0.7, 0.0, 0.0]
	if key == "lid":
		return [tone * 0.93, 0.6, 0.0, 0.0]
	var base: Array = (LOOK.get(key, ZombieBody.KEY_LOOK.get(key, [Color(1, 0, 1), 0.8, 0.0, 0.0])) as Array).duplicate()
	# palette colours are picked as sRGB albedo (like RemoteBody's OUTFITS were); the kit shader takes linear
	if pal.has(key):
		base[0] = _color(pal[key], base[0]).srgb_to_linear()
	elif key == "brow" and pal.has("hair"):
		base[0] = _color(pal["hair"], base[0]).srgb_to_linear() * 0.8
	if key == "iris" and str(r.get("look", "")) == "porcelain":
		base = [base[0], 0.04, 0.0, 0.25]   # glassy doll eyes with a faint glint of their own
	return base


## The person's skin material: the shared living one, the Cousins' porcelain, or the infection shader (risen).
static func skin_material(id: String, risen: bool = false) -> ShaderMaterial:
	if risen:
		# the infection shader with the living texture set (the people's UVs are the living canonical layout; the
		# zombie set was baked on the zombie one): cracks and veins at the zombie strength, a dead roughness
		if _risen == null:
			var inf: Dictionary = GLData.table("anim")["infection"]
			_risen = ZombieBody.skin_material("living").duplicate() as ShaderMaterial
			_risen.set_shader_parameter("crack_energy", float(inf.get("crack_energy", 2.6)))
			_risen.set_shader_parameter("vein_energy", float(inf.get("vein_energy", 1.4)))
			_risen.set_shader_parameter("roughness", 0.68)
			_risen.set_shader_parameter("skin_mul", Vector3(0.82, 0.86, 0.92))
		return _risen
	if str(row(id).get("look", "")) == "porcelain":
		if _porcelain == null:
			_porcelain = ZombieBody.skin_material("living").duplicate() as ShaderMaterial
			_porcelain.set_shader_parameter("roughness", 0.26)
			_porcelain.set_shader_parameter("normal_depth", 0.2)
			_porcelain.set_shader_parameter("vein_energy", 0.35)        # a faint violet under the glaze (they are zombified)
			_porcelain.set_shader_parameter("vein_color", Color(0.55, 0.3, 0.9))
		return _porcelain
	return ZombieBody.skin_material("living")


## The merged two-surface skinned mesh with the face blend shapes (cached per person / risen).
static func mesh(id: String, risen: bool = false) -> ArrayMesh:
	var key: String = id + (":risen" if risen else "")
	if _meshes.has(key):
		return _meshes[key]
	var parts: Dictionary = glb_parts(id)
	if not parts.has("Body"):
		return null
	var r: Dictionary = row(id)
	var tone: Color = _color(r.get("tone"), Color(0.62, 0.5, 0.44))
	if risen:
		tone = Color(0.55, 0.58, 0.6)
	var shapes: PackedStringArray = shape_names()
	var keys: Array = ZombieBody.part_keys()
	var flags: int = (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	var im: ImporterMesh = ImporterMesh.new()
	im.set_blend_shape_mode(Mesh.BLEND_SHAPE_MODE_NORMALIZED)
	for s: String in shapes:
		im.add_blend_shape(s)
	# ---- surface 0: the skin (Body), colour = tone x paint
	var body: Array = parts["Body"]
	var b: Array = body[0]
	var bv: PackedVector3Array = b[Mesh.ARRAY_VERTEX]
	var bc: PackedColorArray = b[Mesh.ARRAY_COLOR]
	var cols: PackedColorArray = []
	cols.resize(bv.size())
	var cus1: PackedFloat32Array = []
	cus1.resize(bv.size() * 4)
	for i: int in bv.size():
		var p: Color = bc[i] if i < bc.size() else Color.WHITE
		cols[i] = Color(tone.r * p.r, tone.g * p.g, tone.b * p.b, 1.0)
		cus1[i * 4] = bv[i].x
		cus1[i * 4 + 1] = bv[i].y
		cus1[i * 4 + 2] = bv[i].z
	var skin_arr: Array = []
	skin_arr.resize(Mesh.ARRAY_MAX)
	for slot: int in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS, Mesh.ARRAY_INDEX]:
		skin_arr[slot] = b[slot]
	skin_arr[Mesh.ARRAY_COLOR] = cols
	skin_arr[Mesh.ARRAY_CUSTOM1] = cus1
	var skin_bs: Array = _shape_arrays(body, shapes)
	# ---- surface 1: parts + hair + kit (packed arrays are values: accumulate in locals)
	var av: PackedVector3Array = []
	var an: PackedVector3Array = []
	var at: PackedFloat32Array = []
	var ac: PackedColorArray = []
	var ac0: PackedFloat32Array = []
	var ac1: PackedFloat32Array = []
	var ab: PackedInt32Array = []
	var aw: PackedFloat32Array = []
	var ai: PackedInt32Array = []
	var obj_shapes: Array = []    # per object: its _shape_arrays
	var looks: Dictionary = {}
	for name: String in ["Parts", "Hair", "Kit"]:
		if not parts.has(name):
			continue
		var obj: Array = parts[name]
		var a: Array = obj[0]
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var tg: PackedFloat32Array = a[Mesh.ARRAY_TANGENT] if a[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
		var c: PackedColorArray = a[Mesh.ARRAY_COLOR]
		var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var stride: int = bones.size() / maxi(1, v.size())
		var start: int = av.size()
		var has_t: bool = tg.size() == v.size() * 4
		for i: int in v.size():
			var ki: int = int(round(c[i].r * 255.0))
			var kname: String = str(keys[ki]) if ki < keys.size() else "dark"
			if not looks.has(kname):
				looks[kname] = look_of(id, kname, risen)
			var lk: Array = looks[kname]
			var ao: float = c[i].g
			var col: Color = lk[0]
			av.append(v[i])
			an.append(n[i])
			if has_t:
				at.append_array(tg.slice(i * 4, i * 4 + 4))
			else:
				at.append_array(PackedFloat32Array([1.0, 0.0, 0.0, 1.0]))
			ac.append(Color(col.r * ao, col.g * ao, col.b * ao, 1.0))
			ac0.append_array(PackedFloat32Array([float(lk[1]), float(lk[2]), float(lk[3]), float(DETAIL.get(kname, 0))]))
			ac1.append_array(PackedFloat32Array([v[i].x, v[i].y, v[i].z, 0.0]))
			for k: int in 4:
				ab.append(bones[i * stride + k] if k < stride else 0)
				aw.append(weights[i * stride + k] if k < stride else 0.0)
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		for i: int in idx.size():
			ai.append(idx[i] + start)
		obj_shapes.append([_shape_arrays(obj, shapes), v.size()])
	var kit_arr: Array = []
	kit_arr.resize(Mesh.ARRAY_MAX)
	kit_arr[Mesh.ARRAY_VERTEX] = av
	kit_arr[Mesh.ARRAY_NORMAL] = an
	kit_arr[Mesh.ARRAY_TANGENT] = at
	kit_arr[Mesh.ARRAY_COLOR] = ac
	kit_arr[Mesh.ARRAY_CUSTOM0] = ac0
	kit_arr[Mesh.ARRAY_CUSTOM1] = ac1
	kit_arr[Mesh.ARRAY_BONES] = ab
	kit_arr[Mesh.ARRAY_WEIGHTS] = aw
	kit_arr[Mesh.ARRAY_INDEX] = ai
	var kit_bs: Array = []
	for si: int in shapes.size():
		var sv: PackedVector3Array = []
		var sn: PackedVector3Array = []
		var stg: PackedFloat32Array = []
		for os: Array in obj_shapes:
			var sa: Array = (os[0] as Array)[si]
			var nv: int = int(os[1])
			sv.append_array(sa[Mesh.ARRAY_VERTEX])
			sn.append_array(sa[Mesh.ARRAY_NORMAL])
			var st: PackedFloat32Array = sa[Mesh.ARRAY_TANGENT] if sa[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
			if st.size() != nv * 4:
				st = PackedFloat32Array()
				for q: int in nv:
					st.append_array(PackedFloat32Array([1.0, 0.0, 0.0, 1.0]))
			stg.append_array(st)
		var sa2: Array = []
		sa2.resize(Mesh.ARRAY_MAX)
		sa2[Mesh.ARRAY_VERTEX] = sv
		sa2[Mesh.ARRAY_NORMAL] = sn
		sa2[Mesh.ARRAY_TANGENT] = stg
		kit_bs.append(sa2)
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, skin_arr, skin_bs, {}, skin_material(id, risen), "skin", flags)
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, kit_arr, kit_bs, {}, ZombieBody.kit_material(), "kit", flags)
	if str((ZombieBody.char_cfg().get("lod", {}) as Dictionary).get("mode", "auto")) == "auto":
		im.generate_lods(60.0, 25.0, [])
	var m: ArrayMesh = im.get_mesh()
	m.set_meta("lod_counts", [im.get_surface_lod_count(0), im.get_surface_lod_count(1)])
	m.set_meta("person", id)
	_meshes[key] = m
	return m


## Blend shape arrays (VERTEX / NORMAL / TANGENT, absolute: BLEND_SHAPE_MODE_NORMALIZED) of one GLB object in the
## order of `shapes`; an object without that shape gets its base arrays (it doesn't move).
static func _shape_arrays(obj: Array, shapes: PackedStringArray) -> Array:
	var a: Array = obj[0]
	var bs: Array = obj[1]
	var names: PackedStringArray = obj[2]
	var out: Array = []
	for s: String in shapes:
		var j: int = names.find(s)
		var sa: Array = []
		sa.resize(Mesh.ARRAY_MAX)
		if j >= 0 and j < bs.size():
			var src: Array = bs[j]
			sa[Mesh.ARRAY_VERTEX] = src[Mesh.ARRAY_VERTEX]
			sa[Mesh.ARRAY_NORMAL] = src[Mesh.ARRAY_NORMAL] if src[Mesh.ARRAY_NORMAL] != null else a[Mesh.ARRAY_NORMAL]
			sa[Mesh.ARRAY_TANGENT] = src[Mesh.ARRAY_TANGENT] if src[Mesh.ARRAY_TANGENT] != null else a[Mesh.ARRAY_TANGENT]
		else:
			sa[Mesh.ARRAY_VERTEX] = a[Mesh.ARRAY_VERTEX]
			sa[Mesh.ARRAY_NORMAL] = a[Mesh.ARRAY_NORMAL]
			sa[Mesh.ARRAY_TANGENT] = a[Mesh.ARRAY_TANGENT]
		out.append(sa)
	return out


## A patron or survivor who turns (T-076 / T-077): the zombie that gets up wears the same person, risen (the same
## face, hair and clothes; the infection skin and the violet eyes), on the zombie's own skeleton, so its rise, clips,
## hitboxes and gore are the zombie's. The rolled gear is hidden and the build / sex follow the person (the gore
## pieces are cut from the same person: piece_mesh, T-099). No-op without a built GLB (the zombie keeps its kit).
## The id is kept as the zombie's "person" meta; the host sends it with the zombie's spawn event so co-op clients
## dress their puppet the same (NetMatch._send_spawn, T-099); Zombie._reset_presentation clears it on pool reuse.
static func dress_risen(z: Node, id: String) -> void:
	if z == null or not available(id):
		return
	var mi: MeshInstance3D = z.get("_body") as MeshInstance3D
	if mi == null:
		return
	mi.mesh = mesh(id, true)
	mi.set_surface_override_material(0, null)
	for g: Variant in (z.get("_gear") as Array):
		(g as Node3D).hide()
	var r: Dictionary = row(id)
	z.set("_build", str(r.get("build", "medium")))
	z.set("_female", bool(r.get("female", false)))
	z.set_meta("person", id)


## Builds, at map load, what a person's rise needs: their risen mesh and the zombie body the rise is activated on
## (`variant` in each build of its kit, the person's sex). Merging these took 40-100 ms in the tick the person got
## up (the inn's survivors and the patrons of the opening: the worst frames of a live round on Map 0).
static func warm_risen(id: String, variant: String, female: bool) -> void:
	if available(id):
		ZombieBody.warm_mesh_pieces("person:" + id, mesh(id, true))   # and the limbs they can lose, on a worker
	var kit: Dictionary = (GLData.table("anim")["kits"] as Dictionary).get(variant, {})
	for b: Variant in kit.get("builds", []):
		ZombieBody.build_skinned(variant, str(b), female)


## T-099: a severed piece of a risen person (ZombieGore._throw_piece): the person's risen mesh cut by dominant bone
## at `root_bone` (ZombieBody._cut_piece, the same split the zombie bodies use), so a turned patron's arm flies off in
## their own sleeve, not the generic villager kit. null without a built GLB (the caller falls back to the kit piece).
static func piece_mesh(id: String, root_bone: String) -> ArrayMesh:
	if not available(id):
		return null
	var key: String = "piece:%s:%s" % [id, root_bone]
	if _meshes.has(key):
		return _meshes[key]
	var m: ArrayMesh = mesh(id, true)
	if m == null:
		return null
	var cut: ArrayMesh = ZombieBody.take_mesh_piece("person:" + id, root_bone, m)   # (cut ahead by warm_risen's worker)
	if cut == null:
		cut = ZombieBody._cut_piece(m, root_bone)
	cut.set_meta("person", id)
	_meshes[key] = cut
	return cut
