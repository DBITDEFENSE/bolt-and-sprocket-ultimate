class_name MaterialLibrary
extends RefCounted
## The CC0 texture library as shared materials (UPDATE_05 section 1, T-088; docs/ART_BIBLE.md section 3).
## `MaterialLibrary.get_mat("floorboards")` returns one cached ShaderMaterial on surface_pbr.gdshader built from
## data/gravelight/materials.json: the set's albedo / normal / ORM PNGs, the tile size as uv_scale, a tint, the
## roughness clamp and the shared wear parameters (grime, wetness, frost). Static and autoload-free, like Mats.
##
## materials.json's `generator` block maps the procedural Mats keys to library keys; `Mats.get_mat()` asks
## `for_generator(key)` first, so Map 0 switches over one key at a time (add the key to `generator.enabled`,
## re-run gen_map00). `texture(key, "albedo")` hands out a set's texture for code that needs the raw map.

const DATA: String = "res://data/gravelight/materials.json"
const TEX_ROOT: String = "res://assets/third_party/"
const MAPS: Array = ["albedo", "normal", "orm", "height"]

## UPDATE 19 (T-252): surface_pbr's variation uniforms (materials.json: macro_var, macro_scale, detile, sparkle).
const VARIATION: Array = ["macro_var", "macro_scale", "detile", "sparkle"]

static var _data: Dictionary = {}
static var _cache: Dictionary = {}
static var _shader: Shader = null
static var _built: Dictionary = {}   # instance id -> true: made by build() in this session (already current)


static func data() -> Dictionary:
	if _data.is_empty():
		var f: FileAccess = FileAccess.open(DATA, FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_data = d
	return _data


## Every library key, in the data file's order.
static func keys() -> Array:
	return (data().get("library", {}) as Dictionary).keys()


static func has_key(key: String) -> bool:
	return (data().get("library", {}) as Dictionary).has(key)


## The entry for a key with the defaults filled in ({} for an unknown key).
static func entry(key: String) -> Dictionary:
	var lib: Dictionary = data().get("library", {})
	if not lib.has(key):
		return {}
	var e: Dictionary = (data().get("defaults", {}) as Dictionary).duplicate()
	e.merge(lib[key], true)
	return e


## Path of one of a set's maps ("albedo", "normal", "orm", "height"); "" when the key or the map is unknown.
static func texture_path(key: String, map: String) -> String:
	var e: Dictionary = entry(key)
	if e.is_empty() or not MAPS.has(map):
		return ""
	return "%s%s/textures/%s_%s.png" % [TEX_ROOT, str(e.get("set", "")), str(e.get("id", "")), map]


static func texture(key: String, map: String) -> Texture2D:
	var p: String = texture_path(key, map)
	if p == "" or not ResourceLoader.exists(p):
		return null
	return load(p) as Texture2D


static func shader() -> Shader:
	if _shader == null:
		_shader = load(str(data().get("shader", "res://assets/materials/shaders/surface_pbr.gdshader"))) as Shader
	return _shader


## The shared material for a key (cached). Null for an unknown key or a set whose textures aren't there.
static func get_mat(key: String) -> Material:
	if _cache.has(key):
		return _cache[key]
	var m: Material = build(key)
	if m != null:
		_cache[key] = m
	return m


## A fresh (uncached) material for a key, optionally with overrides on top of the data ({"grime": 0.8, ...}):
## for a one-off variant (a wetter floor by the door) without touching the shared one.
static func build(key: String, overrides: Dictionary = {}) -> ShaderMaterial:
	var e: Dictionary = entry(key)
	if e.is_empty():
		return null
	e.merge(overrides, true)
	var sh: Shader = shader()
	if sh == null:
		return null
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = sh
	m.resource_name = "lib_" + key
	if not _configure(m, key, e):
		push_warning("MaterialLibrary: '%s' is missing a map under %s" % [key, texture_path(key, "albedo").get_base_dir()])
		return null
	_built[m.get_instance_id()] = true
	return m


## The entry `e` of `key` written to `m`: the set's three maps and every parameter. False when a map is missing
## (nothing is written then).
static func _configure(m: ShaderMaterial, key: String, e: Dictionary) -> bool:
	var alb: Texture2D = texture(key, "albedo")
	var nrm: Texture2D = texture(key, "normal")
	var orm: Texture2D = texture(key, "orm")
	if alb == null or nrm == null or orm == null:
		return false
	m.set_shader_parameter("albedo_tex", alb)
	m.set_shader_parameter("normal_tex", nrm)
	m.set_shader_parameter("orm_tex", orm)
	var tile: float = maxf(0.05, float(e.get("tile_m", 1.0)))
	var scale: Vector3 = Vector3.ONE / tile
	if e.has("tile_xyz"):
		var t: Array = e["tile_xyz"]
		scale = Vector3(1.0 / maxf(0.05, float(t[0])), 1.0 / maxf(0.05, float(t[1])), 1.0 / maxf(0.05, float(t[2])))
	m.set_shader_parameter("uv_scale", scale)
	m.set_shader_parameter("triplanar", bool(e.get("triplanar", true)))
	m.set_shader_parameter("albedo_tint", _col(e.get("tint", [1, 1, 1])))
	var r: Array = e.get("rough", [0.0, 1.0])
	m.set_shader_parameter("rough_min", float(r[0]))
	m.set_shader_parameter("rough_max", float(r[1]))
	m.set_shader_parameter("normal_strength", float(e.get("normal_strength", 1.0)))
	for p: String in ["grime", "wetness", "frost", "frost_height", "frost_up", "grime_floor_y", "grime_height", "grime_scale", "metallic_mul", "ao_strength", "specular_amount", "albedo_saturation"]:
		if e.has(p):
			m.set_shader_parameter(p, float(e[p]))
	if e.has("grime_tint"):
		m.set_shader_parameter("grime_tint", _col(e["grime_tint"]))
	if e.has("frost_tint"):
		m.set_shader_parameter("frost_tint", _col(e["frost_tint"]))
	_variation(m, e)
	return true


static func _variation(m: ShaderMaterial, e: Dictionary) -> void:
	for p: String in VARIATION:
		if e.has(p):
			m.set_shader_parameter(p, float(e[p]))


## UPDATE 19 (T-252): a map scene bakes its library materials (sub-resources named lib_<key>), so a change to
## materials.json reached a map only when its generator ran again. This brings a baked material up to the data when
## its map loads: 0 = not a library material (or one build() made in this session), 1 = the variation values
## (macro_var, macro_scale, detile, sparkle; by the material's lib_<key> name, else by its albedo file in
## `by_texture`), 2 = the whole entry, textures included, for a key the data marks `"live": true` (a set that was
## swapped after the scenes were baked: the trodden snow, the frozen mud, the inn's plaster). Presentation only.
static func apply_runtime(mat: Material) -> int:
	var m: ShaderMaterial = mat as ShaderMaterial
	if m == null or m.shader == null or m.shader != shader() or _built.has(m.get_instance_id()):
		return 0
	var nm: String = String(m.resource_name)
	var key: String = nm.substr(4) if nm.begins_with("lib_") else ""
	var e: Dictionary = entry(key) if key != "" else {}
	if e.is_empty():
		var t: Texture2D = m.get_shader_parameter("albedo_tex") as Texture2D
		var by: Variant = (data().get("by_texture", {}) as Dictionary).get(t.resource_path.get_file() if t != null else "")
		if not (by is Dictionary):
			return 0
		_variation(m, by as Dictionary)
		return 1
	if bool(e.get("live", false)):
		if _configure(m, key, e):
			_built[m.get_instance_id()] = true
			return 2
	_variation(m, e)
	return 1


## The library material the generator should use for a procedural Mats key, or null to keep the procedural one:
## materials.json generator.use_library must be on and the key listed in generator.enabled.
static func for_generator(mats_key: String) -> Material:
	var g: Dictionary = data().get("generator", {})
	if not bool(g.get("use_library", false)):
		return null
	if not (g.get("enabled", []) as Array).has(mats_key):
		return null
	var lib_key: String = str((g.get("keys", {}) as Dictionary).get(mats_key, ""))
	if lib_key == "":
		return null
	return get_mat(lib_key)


## The library key a procedural Mats key maps to ("" when unmapped), whether or not it is enabled.
static func generator_key(mats_key: String) -> String:
	return str(((data().get("generator", {}) as Dictionary).get("keys", {}) as Dictionary).get(mats_key, ""))


## Drops the caches (tests, hot reloads of the data file).
static func reset() -> void:
	_data = {}
	_cache = {}
	_shader = null
	_built = {}


static func _col(a: Variant) -> Color:
	if a is Array and (a as Array).size() >= 3:
		return Color(float(a[0]), float(a[1]), float(a[2]), float(a[3]) if (a as Array).size() > 3 else 1.0)
	return Color.WHITE
