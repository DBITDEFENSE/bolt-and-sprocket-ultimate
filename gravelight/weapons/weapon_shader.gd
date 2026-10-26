class_name WeaponShader
extends RefCounted
## The shared weapon shader's Godot side (UPDATE_05 section 2, T-089): wraps every surface of a downloaded gun in
## assets/materials/shaders/weapon.gdshader, carrying the GLB's PBR maps (albedo, normal, ORM) across and setting
## the look uniforms: palette mode for the flat-colour OpenGameArt guns (the 8x8 palette is upscaled nearest so it
## can be sampled linearly with mipmaps), wear / grime / scratches (model_fit.json "shader" per gun), the camo
## tint (wood only), the M1911 finishes (metal only), the Nachtglas veins when upgraded, and frost by map
## (model_fit.json "frost_by_map", looked up from GameState.map_id; set_frost for live changes). Materials are
## cached per source material + look, so a whole pack of the same gun shares them.

const SHADER_PATH: String = "res://assets/materials/shaders/weapon.gdshader"

static var _shader: Shader = null
static var _cache: Dictionary = {}       # key -> ShaderMaterial
static var _palettes: Dictionary = {}    # source texture rid | remap -> upscaled ImageTexture
static var frost: float = -1.0           # -1 = not resolved yet (frost_for_map on first use)
static var _frost_map: StringName = &"?"
## Tools: false leaves the imported StandardMaterial3Ds on (vm_shots --noshader); debug 1 = raw albedo, 2 = the wood mask.
static var enabled: bool = true
static var debug: int = 0


static func shader() -> Shader:
	if _shader == null:
		_shader = load(SHADER_PATH) as Shader
	return _shader


## The frost a map asks for (model_fit.json "frost_by_map"; "default" for the rest).
static func frost_for_map(map_id: StringName) -> float:
	var t: Dictionary = (WeaponGLB._fit if WeaponGLB._loaded else {}).get("frost_by_map", {})
	if not WeaponGLB._loaded:
		WeaponGLB._load()
		t = WeaponGLB._fit.get("frost_by_map", {})
	return float(t.get(String(map_id), t.get("default", 0.0)))


## Sets the frost on every live weapon material (a map change, the dev console).
static func set_frost(v: float) -> void:
	frost = clampf(v, 0.0, 1.0)
	for m: ShaderMaterial in _cache.values():
		m.set_shader_parameter("frost", frost)


static func _tick_frost() -> void:
	var mid: StringName = GameState.map_id
	if mid != _frost_map or frost < 0.0:
		_frost_map = mid
		set_frost(frost_for_map(mid))


## Wraps the GLB surfaces under `root` (meshes tagged meta "glb"). opts: upgraded, camo, finish, palette, scale,
## fit (model_fit "shader": wear, grime, scratches, bluing [r,g,b], wood {material: share}).
static func apply(root: Node3D, opts: Dictionary) -> void:
	if not enabled:
		return
	_tick_frost()
	for c: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = c as MeshInstance3D
		if mi.mesh == null or not mi.has_meta("glb"):
			continue
		var basis: Basis = mi.transform.basis
		var p: Node = mi.get_parent()
		while p != null and p != root:
			basis = (p as Node3D).transform.basis * basis
			p = p.get_parent()
		# model_fit shader metal_parts / wood_parts: a whole part group forced to metal (the MG42's tan belt drum) or wood
		var part: String = ""
		var pn: Node = mi.get_parent()
		while pn != null and pn != root:
			part = String(pn.name)
			pn = pn.get_parent()
		var fit: Dictionary = opts.get("fit", {})
		var force: float = -1.0
		if (fit.get("metal_parts", []) as Array).has(part):
			force = 0.0
		elif (fit.get("wood_parts", []) as Array).has(part):
			force = 1.0
		var inv: Basis = basis.inverse()
		var fwd: Vector3 = (inv * Vector3.FORWARD).normalized()
		var up: Vector3 = (inv * Vector3.UP).normalized()
		var scale: float = basis.get_scale().x
		for si: int in mi.mesh.get_surface_count():
			var src: Material = mi.get_surface_override_material(si)
			if src == null:
				src = mi.mesh.surface_get_material(si)
			if src is ShaderMaterial and (src as ShaderMaterial).shader == shader():
				continue
			mi.set_surface_override_material(si, material_for(src as BaseMaterial3D, opts, fwd, up, scale, force))


## One ShaderMaterial for a source material and a look (cached).
static func material_for(src: BaseMaterial3D, opts: Dictionary, fwd: Vector3, up: Vector3, scale: float, force: float = -1.0) -> ShaderMaterial:
	var fit: Dictionary = opts.get("fit", {})
	var key: String = "%d|%s|%s|%s|%s|%.3f|%s|%.1f" % [src.get_instance_id() if src != null else 0, opts.get("upgraded", false), opts.get("camo", ""),
		opts.get("finish", ""), opts.get("palette", false), scale, JSON.stringify(fit), force]
	if _cache.has(key):
		return _cache[key]
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = shader()
	var palette: bool = bool(opts.get("palette", false))
	var sm: StandardMaterial3D = src as StandardMaterial3D
	if sm != null:
		var alb: Texture2D = sm.albedo_texture
		if palette and alb != null:
			alb = _palette_tex(alb, fit.get("palette_remap", {}))
		if alb != null:
			m.set_shader_parameter("albedo_tex", alb)
		m.set_shader_parameter("base_color", sm.albedo_color)
		if sm.normal_enabled and sm.normal_texture != null:
			m.set_shader_parameter("normal_tex", sm.normal_texture)
			m.set_shader_parameter("has_normal", 1.0)
			m.set_shader_parameter("normal_depth", sm.normal_scale)
		var orm: Texture2D = sm.metallic_texture if sm.metallic_texture != null else (sm.roughness_texture if sm.roughness_texture != null else sm.ao_texture)
		if orm != null and not palette:
			m.set_shader_parameter("orm_tex", orm)
			m.set_shader_parameter("has_orm", 1.0)
		m.set_shader_parameter("metallic_f", sm.metallic if not palette else 0.8)
		m.set_shader_parameter("roughness_f", sm.roughness if not palette else 0.5)
	m.set_shader_parameter("palette", 1.0 if palette else 0.0)
	m.set_shader_parameter("debug", float(debug))
	m.set_shader_parameter("detail_scale", scale)
	m.set_shader_parameter("fwd_axis", fwd)
	m.set_shader_parameter("up_axis", up)
	m.set_shader_parameter("wear", float(fit.get("wear", 0.55)))
	m.set_shader_parameter("grime", float(fit.get("grime", 0.5)))
	m.set_shader_parameter("scratches", float(fit.get("scratches", 0.5)))
	m.set_shader_parameter("grain_scale", float(fit.get("grain_scale", 1.0)))
	m.set_shader_parameter("seed", float(fit.get("seed", 0.0)))
	if fit.has("bluing"):
		m.set_shader_parameter("bluing", WeaponGLB._v3(fit["bluing"], Vector3(0.86, 0.9, 1.0)))
	var wood_force: float = -1.0
	var wf: Dictionary = fit.get("wood", {})
	if sm != null and wf.has(str(sm.resource_name)):
		wood_force = float(wf[str(sm.resource_name)])
	if force >= 0.0:
		wood_force = force
	m.set_shader_parameter("wood_force", wood_force)
	m.set_shader_parameter("frost", maxf(0.0, frost))
	m.set_shader_parameter("nachtglas", 1.0 if bool(opts.get("upgraded", false)) else 0.0)
	var camo: StringName = StringName(str(opts.get("camo", "")))
	if camo != &"" and WeaponModels.CAMO_TINT.has(camo):
		var c: Color = WeaponModels.CAMO_TINT[camo]
		if camo == &"nachtglas":
			m.set_shader_parameter("nachtglas", 0.7)
		else:
			m.set_shader_parameter("camo_tint", Color(c.r, c.g, c.b, 1.0))
			# a tint brighter than white (winter) is a field whitewash: the shader's own capped, chipped path (T-098)
			m.set_shader_parameter("whitewash", 1.0 if maxf(c.r, maxf(c.g, c.b)) > 1.0 else 0.0)
			if camo in [&"gold", &"silver", &"bronze"]:
				m.set_shader_parameter("camo_metal", 0.9)
	var finish: String = str(opts.get("finish", ""))
	if finish != "":
		var d: Dictionary = M1911Kit.finish_def(StringName(finish))
		if d.has("color"):
			var fc: Array = d["color"]
			m.set_shader_parameter("metal_tint", Color(float(fc[0]), float(fc[1]), float(fc[2]), 1.0))
			if d.has("metallic"):
				m.set_shader_parameter("metal_metallic", float(d["metallic"]))
			if d.has("roughness"):
				m.set_shader_parameter("metal_roughness", float(d["roughness"]))
	_cache[key] = m
	return m


## The OGA 8x8 palette, upscaled 16x nearest (no mipmaps), so linear filtering never bleeds between cells.
## `remap` (model_fit shader "palette_remap" {cell index: [r,g,b]}, cell = row * width + column) repaints a cell
## for this gun only (T-098: the STG44 stock's crimson cell, which the shader read as blued metal, to walnut).
static func _palette_tex(src: Texture2D, remap: Dictionary = {}) -> Texture2D:
	var k: String = "%d|%s" % [src.get_rid().get_id(), JSON.stringify(remap)]
	if _palettes.has(k):
		return _palettes[k]
	var img: Image = src.get_image()
	if img == null:
		return src
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	for ck: Variant in remap.keys():
		var ci: int = int(str(ck))
		var cc: Array = remap[ck]
		if ci >= 0 and ci < img.get_width() * img.get_height() and cc.size() >= 3:
			img.set_pixel(ci % img.get_width(), ci / img.get_width(), Color(float(cc[0]), float(cc[1]), float(cc[2]), 1.0))
	if img.get_width() <= 16:
		img.resize(img.get_width() * 16, img.get_height() * 16, Image.INTERPOLATE_NEAREST)
	var t: ImageTexture = ImageTexture.create_from_image(img)
	_palettes[k] = t
	return t


## Drops the material cache (tests, shader edits).
static func reset() -> void:
	_cache.clear()
	_palettes.clear()
	_shader = null
	frost = -1.0
	_frost_map = &"?"
