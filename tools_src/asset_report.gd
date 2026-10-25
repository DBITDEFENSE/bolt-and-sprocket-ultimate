extends Node
## Asset report (UPDATE_05 section 1, T-088): walks res://assets/ and prints, per asset, its triangles, materials,
## texture-memory estimate (as imported: VRAM-compressed with mipmaps counts 1 byte/texel x 1.33 for BC1/BC4-class
## maps, 1.33 for normal RGTC, 4 x 1.33 for uncompressed), LOD count and bounds, then totals per source and per
## kind, plus the procedural builders' meshes it knows (every WeaponModels gun, the zombie body). Writes
## morning/asset_report.md (or --out=<path>).
##
##   godot --headless --audio-driver Dummy --path . res://tools_src/asset_report.tscn [-- --out=morning/asset_report.md --root=res://assets]
##   (tools/asset_report.sh; a scene rather than --script so the autoloads the procedural builders lean on exist)
##
## Headless: meshes load from the imported scenes (run the editor import first); textures are measured from the
## source image headers plus their .import params, so no GPU is needed.

const BUDGET_PROP_TRIS: int = 3000
const BUDGET_PROP_TEX: int = 1024

var _out: String = "res://morning/asset_report.md"
var _root: String = "res://assets"
var _rows: Array = []        # per asset {path, kind, source, tris, mats, tex_bytes, lods, size}
var _tex_rows: Array = []    # per texture {path, w, h, bytes, mode}
var _tex_seen: Dictionary = {}


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--root="):
			_root = a.substr(7)
	_walk(_root)
	_procedural()
	_write()
	get_tree().quit(0)


func _walk(dir: String) -> void:
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		return
	for sub: String in d.get_directories():
		if sub.begins_with(".") or sub == "import_presets":
			continue
		_walk(dir.path_join(sub))
	for f: String in d.get_files():
		var p: String = dir.path_join(f)
		var ext: String = f.get_extension().to_lower()
		if ext in ["glb", "gltf", "fbx"]:
			_scene(p)
		elif ext in ["png", "jpg", "jpeg", "webp", "tga", "hdr", "exr"]:
			_texture(p, "")


func _source_of(path: String) -> String:
	var parts: PackedStringArray = path.trim_prefix("res://").split("/")
	if parts.size() >= 3 and parts[1] == "third_party":
		return parts[2]
	return parts[1] if parts.size() > 1 else "assets"


func _asset_dir(path: String) -> String:
	var parts: PackedStringArray = path.trim_prefix("res://").split("/")
	if parts.size() >= 4 and parts[1] == "third_party":
		return "/".join(parts.slice(0, 4))
	return path.get_base_dir().trim_prefix("res://")


## One imported scene: instance it, sum the surfaces' triangles, count the materials and LOD levels, estimate the
## textures its materials reference (embedded or external), and take the AABB of all its meshes.
func _scene(path: String) -> void:
	var row: Dictionary = {"path": path, "kind": "model", "source": _source_of(path), "tris": 0, "mats": 0, "tex_bytes": 0, "lods": 0, "size": Vector3.ZERO, "min": Vector3.ZERO, "note": ""}
	if not ResourceLoader.exists(path):
		row["note"] = "not imported"
		_rows.append(row)
		return
	var ps: PackedScene = load(path) as PackedScene
	if ps == null:
		row["note"] = "failed to load"
		_rows.append(row)
		return
	var inst: Node = ps.instantiate()
	var mats: Dictionary = {}
	var aabb: AABB = AABB()
	var first: bool = true
	for mi: MeshInstance3D in _meshes(inst):
		var m: Mesh = mi.mesh
		if m == null:
			continue
		for s: int in m.get_surface_count():
			row["tris"] = int(row["tris"]) + _surface_tris(m, s)
			var mat: Material = mi.get_active_material(s)
			if mat != null:
				mats[mat.get_instance_id()] = mat
				_material_textures(mat, row)
		var b: AABB = mi.global_transform * m.get_aabb() if mi.is_inside_tree() else _xform_to_root(mi, inst) * m.get_aabb()
		if first:
			aabb = b
			first = false
		else:
			aabb = aabb.merge(b)
	row["mats"] = mats.size()
	row["lods"] = _lods_from_import(path)
	row["size"] = aabb.size
	row["min"] = aabb.position
	inst.free()
	_rows.append(row)


func _xform_to_root(n: Node3D, root: Node) -> Transform3D:
	var t: Transform3D = Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t


func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D:
		out.append(n)
	for c: Node in n.get_children():
		out.append_array(_meshes(c))
	return out


static func _surface_tris(m: Mesh, s: int) -> int:
	var arrays: Array = m.surface_get_arrays(s)
	if arrays.is_empty():
		return 0
	var idx: Variant = arrays[Mesh.ARRAY_INDEX]
	var count: int = 0
	if idx != null and (idx as PackedInt32Array).size() > 0:
		count = (idx as PackedInt32Array).size()
	elif arrays[Mesh.ARRAY_VERTEX] != null:
		count = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	if m is ArrayMesh:   # primitive meshes (Box, Cylinder, ...) are always triangle lists
		match (m as ArrayMesh).surface_get_primitive_type(s):
			Mesh.PRIMITIVE_TRIANGLES:
				return count / 3
			Mesh.PRIMITIVE_TRIANGLE_STRIP:
				return maxi(0, count - 2)
			_:
				return 0
	return count / 3


## 4.7 exposes no getter for an imported ArrayMesh's LOD chain, so the column reports the import preset's choice:
## 1 = generate_lods on (Godot builds the chain at import), 0 = off.
static func _lods_from_import(path: String) -> int:
	var cf: ConfigFile = ConfigFile.new()
	if cf.load(path + ".import") != OK:
		return 0
	return 1 if bool(cf.get_value("params", "meshes/generate_lods", false)) else 0


func _material_textures(mat: Material, row: Dictionary) -> void:
	var texes: Array = []
	if mat is BaseMaterial3D:
		var b: BaseMaterial3D = mat
		for t: int in [BaseMaterial3D.TEXTURE_ALBEDO, BaseMaterial3D.TEXTURE_NORMAL, BaseMaterial3D.TEXTURE_ORM, BaseMaterial3D.TEXTURE_ROUGHNESS, BaseMaterial3D.TEXTURE_METALLIC, BaseMaterial3D.TEXTURE_EMISSION, BaseMaterial3D.TEXTURE_AMBIENT_OCCLUSION]:
			var tx: Texture2D = b.get_texture(t)
			if tx != null:
				texes.append(tx)
	elif mat is ShaderMaterial:
		var sm: ShaderMaterial = mat
		if sm.shader != null:
			for u: Dictionary in sm.shader.get_shader_uniform_list():
				var v: Variant = sm.get_shader_parameter(u["name"])
				if v is Texture2D:
					texes.append(v)
	for tx: Texture2D in texes:
		var key: String = tx.resource_path if tx.resource_path != "" else str(tx.get_instance_id())
		if _tex_seen.has(key):
			continue
		var bytes: int = _texture_bytes(tx)
		_tex_seen[key] = bytes
		row["tex_bytes"] = int(row["tex_bytes"]) + bytes
		_tex_rows.append({"path": key if tx.resource_path != "" else "%s (embedded)" % row["path"].get_file(), "w": tx.get_width(), "h": tx.get_height(), "bytes": bytes, "mode": "compressed" if tx is CompressedTexture2D else "raw"})


## VRAM estimate: compressed (BC/RGTC class) ~ 1 byte per texel, raw 4 bytes; x 1.333 for mipmaps.
static func _texture_bytes(tx: Texture2D) -> int:
	var texels: int = tx.get_width() * tx.get_height()
	var per: float = 1.0 if tx is CompressedTexture2D else 4.0
	return int(float(texels) * per * 1.333)


## A loose texture file (not reached through a material): measured from its header and its .import params.
func _texture(path: String, _owner: String) -> void:
	if _tex_seen.has(path):
		return
	var img: Image = Image.new()
	var w: int = 0
	var h: int = 0
	var ext: String = path.get_extension().to_lower()
	if ext in ["png", "jpg", "jpeg", "webp", "tga"]:
		if img.load(path) == OK:
			w = img.get_width()
			h = img.get_height()
	elif ResourceLoader.exists(path):
		var t: Texture2D = load(path) as Texture2D
		if t != null:
			w = t.get_width()
			h = t.get_height()
	var mode: int = 0
	var cf: ConfigFile = ConfigFile.new()
	if cf.load(path + ".import") == OK:
		mode = int(cf.get_value("params", "compress/mode", 0))
	var per: float = 1.0 if mode == 2 else 4.0
	var bytes: int = int(float(w * h) * per * 1.333)
	_tex_seen[path] = bytes
	_tex_rows.append({"path": path, "w": w, "h": h, "bytes": bytes, "mode": "vram" if mode == 2 else ("lossless" if mode == 0 else str(mode))})
	var row: Dictionary = {"path": path, "kind": "texture", "source": _source_of(path), "tris": 0, "mats": 0, "tex_bytes": bytes, "lods": 0, "size": Vector3(w, h, 0), "min": Vector3.ZERO, "note": ""}
	_rows.append(row)


## The procedural builders: every WeaponModels gun (plain) and one zombie body per outfit variant when the builders
## are available headless.
func _procedural() -> void:
	var weapons: Dictionary = {}
	var f: FileAccess = FileAccess.open("res://data/gravelight/weapons.json", FileAccess.READ)
	if f != null:
		var d: Variant = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			weapons = d
	var ids: Array = weapons.get("weapons", weapons).keys() if weapons is Dictionary else []
	for id: Variant in ids:
		if not (weapons.get("weapons", weapons)[id] is Dictionary):
			continue
		var n: Node3D = WeaponModels.build(StringName(str(id)))
		var row: Dictionary = {"path": "WeaponModels %s" % id, "kind": "procedural", "source": "procedural", "tris": 0, "mats": 0, "tex_bytes": 0, "lods": 0, "size": Vector3.ZERO, "min": Vector3.ZERO, "note": "viewmodel"}
		var mats: Dictionary = {}
		for mi: MeshInstance3D in _meshes(n):
			if mi.mesh == null:
				continue
			for s: int in mi.mesh.get_surface_count():
				row["tris"] = int(row["tris"]) + _surface_tris(mi.mesh, s)
				var m: Material = mi.get_active_material(s)
				if m != null:
					mats[m.get_instance_id()] = true
		row["mats"] = mats.size()
		_rows.append(row)
		n.free()


func _fmt_mb(b: int) -> String:
	return "%.1f" % (float(b) / 1048576.0)


func _write() -> void:
	var lines: PackedStringArray = []
	lines.append("# Asset report")
	lines.append("")
	lines.append("Generated by tools/asset_report.sh on %s. Triangles are per imported scene (all surfaces, LOD0); texture memory is the VRAM estimate (compressed 1 B/texel, raw 4 B/texel, x1.33 mipmaps); LODs: 1 = the import preset generates the LOD chain (4.7 has no getter for the levels), 0 = none. Budgets: docs/ART_BIBLE.md section 5 (prop <= %d tris, <= %d px)." % [Time.get_datetime_string_from_system(), BUDGET_PROP_TRIS, BUDGET_PROP_TEX])
	lines.append("")
	# models
	lines.append("## Models")
	lines.append("")
	lines.append("| Asset | Source | Tris | Mats | Tex MB | LODs | Size (m) | Note |")
	lines.append("|---|---|---:|---:|---:|---:|---|---|")
	var total_tris: int = 0
	var over: int = 0
	for r: Dictionary in _rows:
		if r["kind"] != "model":
			continue
		total_tris += int(r["tris"])
		var sz: Vector3 = r["size"]
		var note: String = str(r["note"])
		if int(r["tris"]) > BUDGET_PROP_TRIS:
			note += (" " if note != "" else "") + "OVER tris budget"
			over += 1
		var label: String = _asset_dir(str(r["path"])).trim_prefix("assets/third_party/") + ("" if str(r["path"]).get_file() == "model.glb" else "/" + str(r["path"]).get_file())
		lines.append("| %s | %s | %d | %d | %s | %d | %.2f x %.2f x %.2f | %s |" % [label, r["source"], r["tris"], r["mats"], _fmt_mb(int(r["tex_bytes"])), r["lods"], sz.x, sz.y, sz.z, note])
	lines.append("")
	# textures
	lines.append("## Textures")
	lines.append("")
	lines.append("| Texture | Size | Import | VRAM MB |")
	lines.append("|---|---|---|---:|")
	var total_tex: int = 0
	_tex_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["bytes"]) > int(b["bytes"]))
	for t: Dictionary in _tex_rows:
		total_tex += int(t["bytes"])
		lines.append("| %s | %dx%d | %s | %s |" % [str(t["path"]).trim_prefix("res://assets/third_party/"), t["w"], t["h"], t["mode"], _fmt_mb(int(t["bytes"]))])
	lines.append("")
	# procedural
	lines.append("## Procedural builders")
	lines.append("")
	lines.append("| Builder | Tris | Mats |")
	lines.append("|---|---:|---:|")
	var proc_tris: int = 0
	for r: Dictionary in _rows:
		if r["kind"] != "procedural":
			continue
		proc_tris += int(r["tris"])
		lines.append("| %s | %d | %d |" % [r["path"], r["tris"], r["mats"]])
	lines.append("")
	# totals
	var per_source: Dictionary = {}
	for r: Dictionary in _rows:
		var s: String = str(r["source"])
		var e: Dictionary = per_source.get(s, {"n": 0, "tris": 0, "tex": 0})
		e["n"] = int(e["n"]) + 1
		e["tris"] = int(e["tris"]) + int(r["tris"])
		e["tex"] = int(e["tex"]) + int(r["tex_bytes"])
		per_source[s] = e
	lines.append("## Totals")
	lines.append("")
	lines.append("| Source | Assets | Tris | Tex MB |")
	lines.append("|---|---:|---:|---:|")
	for s: String in per_source:
		var e: Dictionary = per_source[s]
		lines.append("| %s | %d | %d | %s |" % [s, e["n"], e["tris"], _fmt_mb(int(e["tex"]))])
	lines.append("")
	lines.append("- Models: %d, %d triangles at LOD0, %d over the prop budget." % [_count("model"), total_tris, over])
	lines.append("- Textures: %d, %s MB of VRAM as imported." % [_tex_rows.size(), _fmt_mb(total_tex)])
	lines.append("- Procedural: %d builders, %d triangles." % [_count("procedural"), proc_tris])
	var abs_out: String = ProjectSettings.globalize_path(_out) if _out.begins_with("res://") else _out
	DirAccess.make_dir_recursive_absolute(abs_out.get_base_dir())
	var f: FileAccess = FileAccess.open(abs_out, FileAccess.WRITE)
	if f == null:
		push_error("[asset_report] cannot write %s" % abs_out)
		return
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("[asset_report] %d models (%d tris), %d textures (%s MB VRAM), %d procedural -> %s" % [_count("model"), total_tris, _tex_rows.size(), _fmt_mb(total_tex), _count("procedural"), abs_out])
	for r: Dictionary in _rows:
		if r["kind"] == "model":
			var sz: Vector3 = r["size"]
			var mn: Vector3 = r["min"]
			var label: String = _asset_dir(str(r["path"])) + ("" if str(r["path"]).get_file() == "model.glb" else "/" + str(r["path"]).get_file())
			print("[asset_report] %s tris %d mats %d lods %d size %.3f %.3f %.3f min %.3f %.3f %.3f %s" % [label, r["tris"], r["mats"], r["lods"], sz.x, sz.y, sz.z, mn.x, mn.y, mn.z, r["note"]])


func _count(kind: String) -> int:
	var n: int = 0
	for r: Dictionary in _rows:
		if r["kind"] == kind:
			n += 1
	return n
