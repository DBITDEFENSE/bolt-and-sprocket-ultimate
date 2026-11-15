class_name LookMaterials
extends RefCounted
## UPDATE 12 section 2 (DECISIONS T-208): the material pass, docs/ART_BIBLE.md section 7, from data/look/_materials.json.
## `apply_tree(map)` runs once when a map loads (LookGrade.attach, after the map's children have built themselves) on
## every world material under it, and tools/look/material_audit runs `evaluate()` before and after it per map:
##   - roughness floor 0.45 (metal 0.35): a flat roughness under it is raised; a roughness texture that averages under
##     it gets its scalar raised (`tex_rough`, written by the audit);
##   - no clean plastic (glossy, not metal, a saturated flat colour): the roughness lift, the wear layer and the
##     desaturation below take it to painted metal / enamel;
##   - albedo saturation under 0.30 and value 0.04..0.90: a flat colour is clamped in HSV; a texture whose average
##     fights the palette is desaturated (`tex_fix`, written by the audit: the surface shader's albedo_saturation; a StandardMaterial3D gets a desaturated copy of its texture); Nachtglas violet and blood
##     red (the accent hues on a material named for an accent) keep theirs;
##   - wear and dirt on everything: a StandardMaterial3D without a detail layer gets the shared grime map
##     (assets/materials/textures/look_grime.png, multiply; world-triplanar on an untextured material, so a box and a
##     wall wear at one scale); the shared surface shader's `grime` is raised to the floor 0.35.
## Skipped: transparent / unshaded / emissive materials (glass, cards, lamps), characters and viewmodels (their own
## shaders and skin rules), section 5's C-47 wreck, the cartoon worlds, and any other shader than surface_pbr (listed by
## the audit with the shader's name). Presentation only: no collision, navmesh, timing or prompt changes.

const DATA: String = "res://data/look/_materials.json"
const SURFACE_SHADER: String = "res://assets/materials/shaders/surface_pbr.gdshader"
const META: StringName = &"gl_look_mat"
const ISSUES: PackedStringArray = ["rough_low", "clean_plastic", "albedo_sat", "albedo_value", "no_wear"]

static var _rules: Dictionary = {}
static var _rules_map: Dictionary = {}   # map id -> the rules with the file's `maps.<id>` block merged over them (T-214)
static var _masks: Dictionary = {}       # strength -> a flat detail mask (the grime layer's strength, T-214)
static var _detail: Texture2D = null
static var _desat: Dictionary = {}   # "<tex key>|sat|val" -> the desaturated copy (one per texture and fix)


static func rules() -> Dictionary:
	if _rules.is_empty():
		_rules = LookGrade.load_file(DATA)
	return _rules


## T-214: the rules for one map: `maps.<map_id>` in the file merged over the shared ones (Mondlicht's clean concrete
## takes less grime, der Kranich's violet strips half their glow). The shared rules when the map has no block.
static func rules_for(map_id: String) -> Dictionary:
	var r: Dictionary = rules()
	var maps: Dictionary = r.get("maps", {})
	if map_id == "" or not maps.has(map_id):
		return r
	if not _rules_map.has(map_id):
		_rules_map[map_id] = LookGrade.merge(r, maps[map_id])
	return _rules_map[map_id]


static func reset_cache() -> void:
	_rules = {}
	_rules_map.clear()
	_masks.clear()
	_detail = null
	_desat.clear()


static func detail_texture(r: Dictionary = rules()) -> Texture2D:
	if _detail == null:
		var p: String = str((r.get("detail", {}) as Dictionary).get("texture", ""))
		if p != "" and ResourceLoader.exists(p):
			_detail = load(p) as Texture2D
	return _detail


# ================================================================== what is on a map

## Why `n` (and everything under it) is skipped, "" when it is not: characters and viewmodels, the C-47 wreck, the
## cartoon worlds (`skip_nodes`, `skip_groups`, a Skeleton3D: a rigged body).
static func skip_reason(n: Node, r: Dictionary = rules()) -> String:
	if n is Skeleton3D:
		return "character (rigged)"
	var nm: String = String(n.name)
	for w: Variant in r.get("skip_nodes", []):
		if nm.contains(str(w)):
			return "skipped node %s" % str(w)
	for g: Variant in r.get("skip_groups", []):
		if n.is_in_group(StringName(str(g))):
			return "group %s" % str(g)
	if n.scene_file_path != "" and path_skip(n.scene_file_path, r) != "":
		return path_skip(n.scene_file_path, r)
	return ""


static func path_skip(p: String, r: Dictionary = rules()) -> String:
	var lp: String = p.to_lower()
	for w: Variant in r.get("skip_paths", []):
		if lp.contains(str(w)):
			return "path %s" % str(w)
	return ""


## Every material under `root` once: [{mat, node (the first user), skip ("" or why its node is skipped)}].
## Walks GeometryInstance3D overrides, surface overrides and the meshes' own surfaces (MultiMesh too).
static func collect(root: Node, r: Dictionary = rules()) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	_walk(root, "", r, out, seen)
	return out


static func _walk(n: Node, skip: String, r: Dictionary, out: Array[Dictionary], seen: Dictionary) -> void:
	var why: String = skip
	if why == "":
		why = skip_reason(n, r)
	if n is GeometryInstance3D:
		for m: Material in materials_of(n as GeometryInstance3D):
			var id: int = m.get_instance_id()
			if seen.has(id):
				if why == "" and String(seen[id]["skip"]) != "":
					seen[id]["skip"] = ""   # a world user wins over a skipped one
					seen[id]["node"] = n
				continue
			var e: Dictionary = {"mat": m, "node": n, "skip": why}
			seen[id] = e
			out.append(e)
	for c: Node in n.get_children(true):
		_walk(c, why, r, out, seen)


static func materials_of(g: GeometryInstance3D) -> Array[Material]:
	var out: Array[Material] = []
	if g.material_override != null:
		out.append(g.material_override)
		return out
	var mesh: Mesh = null
	if g is MeshInstance3D:
		mesh = (g as MeshInstance3D).mesh
		for i: int in (g as MeshInstance3D).get_surface_override_material_count():
			var so: Material = (g as MeshInstance3D).get_surface_override_material(i)
			if so != null:
				out.append(so)
	elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh != null:
		mesh = (g as MultiMeshInstance3D).multimesh.mesh
	elif g is GPUParticles3D:
		# T-214: a particle system's draw passes (the stove barrel's smoke: `lit_smoke`)
		var gp: GPUParticles3D = g
		for k: int in gp.draw_passes:
			var dm: Mesh = gp.get_draw_pass_mesh(k)
			if dm != null:
				for si: int in dm.get_surface_count():
					if dm.surface_get_material(si) != null:
						out.append(dm.surface_get_material(si))
		return out
	if mesh != null:
		for i: int in mesh.get_surface_count():
			if g is MeshInstance3D and i < (g as MeshInstance3D).get_surface_override_material_count() \
					and (g as MeshInstance3D).get_surface_override_material(i) != null:
				continue
			var sm: Material = mesh.surface_get_material(i)
			if sm != null:
				out.append(sm)
	return out


## The words a material is known by: its name, its path, the first user's node name and mesh name (lower case).
static func words_of(m: Material, node: Node) -> String:
	var s: String = (m.resource_name + " " + m.resource_path).to_lower()
	if node != null:
		s += " " + String(node.name).to_lower()
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			s += " " + (node as MeshInstance3D).mesh.resource_name.to_lower()
	if m is BaseMaterial3D and (m as BaseMaterial3D).albedo_texture != null:
		s += " " + (m as BaseMaterial3D).albedo_texture.resource_path.to_lower()
	return s


static func has_word(words: String, list: Variant) -> bool:
	if list is Array:
		for w: Variant in list:
			if words.contains(str(w)):
				return true
	return false


static func is_accent(c: Color, r: Dictionary = rules()) -> bool:
	if c.s < 0.3:
		return false
	for a: Variant in r.get("accent_hues", []):
		var ad: Dictionary = a
		if absf(wrapf(c.h * 360.0 - float(ad.get("hue", 0.0)), -180.0, 180.0)) <= float(ad.get("width", 20.0)):
			return true
	return false


## A texture's key in the data (`tex_fix`, `tex_rough`, the audit's averages): its resource path, or its instance
## for a texture with none (one built in code; the data can't name it).
static func tex_key(t: Texture) -> String:
	if t == null:
		return ""
	return t.resource_path if t.resource_path != "" else "id:%d" % t.get_instance_id()


## The `tex_fix` key of a material: its albedo texture and its own colour ("<path>|<rrggbb>"; one texture under two
## library tints needs two multiplies). "" without a texture.
static func tint_key(m: Material) -> String:
	var t: Texture2D = albedo_texture(m)
	if t == null:
		return ""
	return tex_key(t) + "|" + own_color(m).to_html(false)


## The material's own albedo colour (StandardMaterial3D albedo_color, surface_pbr albedo_tint).
static func own_color(m: Material) -> Color:
	if m is BaseMaterial3D:
		return (m as BaseMaterial3D).albedo_color
	if m is ShaderMaterial:
		var tv: Variant = _param(m as ShaderMaterial, "albedo_tint", Color.WHITE)
		return tv if tv is Color else Color.WHITE
	return Color.WHITE


## The albedo texture of a material (StandardMaterial3D's, surface_pbr's `albedo_tex`), null when none.
static func albedo_texture(m: Material) -> Texture2D:
	if m is BaseMaterial3D:
		return (m as BaseMaterial3D).albedo_texture
	if m is ShaderMaterial:
		var t: Variant = (m as ShaderMaterial).get_shader_parameter("albedo_tex")
		return t as Texture2D if t is Texture2D else null
	return null


## The saturation a colour may keep: sat_max, or `accent_hue_sat_max` when its hue sits in an accent window (violet,
## red) on a material that is not an accent ("a new asset in those hues that isn't Nachtglas or blood will read as
## one": a red curtain under a warm lamp came out of the grade's red keep as a red halo). Pure.
static func sat_cap(c: Color, accent_word: bool, r: Dictionary = rules()) -> float:
	var smax: float = float(r.get("sat_max", 0.3))
	if accent_word:
		return smax
	for a: Variant in r.get("accent_hues", []):
		var ad: Dictionary = a
		if absf(wrapf(c.h * 360.0 - float(ad.get("hue", 0.0)), -180.0, 180.0)) <= float(ad.get("width", 20.0)):
			return minf(smax, float(r.get("accent_hue_sat_max", 0.15)))
	return smax


## The fix for a textured material whose average `eff` fights the palette: {"sat": f, "val": g} where f takes its
## saturation to the cap (less a margin) and g its value under val_max. Pure.
static func tex_fix_for(eff: Color, r: Dictionary = rules(), accent_word: bool = false) -> Dictionary:
	var smax: float = sat_cap(eff, accent_word, r) - 0.03
	var vmax: float = float(r.get("val_max", 0.9)) - 0.02
	var f: float = 1.0
	if eff.s > smax:
		# mixing toward the luma l by f: s' = f (max - min) / (l + f (max - l)); solved for s' = smax
		var mx: float = maxf(eff.r, maxf(eff.g, eff.b))
		var mn: float = minf(eff.r, minf(eff.g, eff.b))
		var l: float = eff.r * 0.299 + eff.g * 0.587 + eff.b * 0.114
		var den: float = (mx - mn) - smax * (mx - l)
		f = clampf(smax * l / den, 0.0, 1.0) if den > 0.0001 else 0.0
	var g: float = clampf(vmax / maxf(eff.v, 0.001), 0.0, 1.0) if eff.v > vmax else 1.0
	return {"sat": snappedf(f, 0.001), "val": snappedf(g, 0.001)}


## `c` desaturated by `f` around its luma (the surface shader's albedo_saturation, the same rule). Pure.
static func desat(c: Color, f: float) -> Color:
	var l: float = c.r * 0.299 + c.g * 0.587 + c.b * 0.114
	return Color(lerpf(l, c.r, f), lerpf(l, c.g, f), lerpf(l, c.b, f), c.a)


## A StandardMaterial3D has no saturation control: its albedo texture is swapped for a desaturated copy made once at
## load (Image.adjust_bcs: saturation `sat`, brightness `val`; at most 1024 px, mipmapped), shared by every material
## that uses the same texture and fix. null when the texture can't be read (a NoiseTexture2D still generating).
static func desat_texture(t: Texture2D, fx: Dictionary) -> Texture2D:
	if t == null:
		return null
	var f: float = float(fx.get("sat", 1.0))
	var g: float = float(fx.get("val", 1.0))
	var key: String = "%s|%.3f|%.3f" % [tex_key(t), f, g]
	if _desat.has(key):
		return _desat[key]
	var img: Image = t.get_image()
	if img == null or img.is_empty():
		return null
	img = img.duplicate() as Image
	if img.is_compressed() and img.decompress() != OK:
		return null
	if img.has_mipmaps():
		img.clear_mipmaps()
	img.convert(Image.FORMAT_RGBA8)
	var big: int = maxi(img.get_width(), img.get_height())
	if big > 1024:
		img.resize(maxi(1, img.get_width() * 1024 / big), maxi(1, img.get_height() * 1024 / big), Image.INTERPOLATE_LANCZOS)
	img.adjust_bcs(g, 1.0, f)
	img.generate_mipmaps()
	var nt: ImageTexture = ImageTexture.create_from_image(img)
	nt.resource_name = t.resource_name + "_look"
	_desat[key] = nt
	return nt


## The fallback when a texture can't be copied: a multiply on its albedo colour toward the
## desaturated average, each channel at most x`tint_gain_max` (1.6: more amplifies the texture's own noise in the
## weak channel; a rusty barrel came out speckled blue at x8). Pure.
static func base_tint(eff: Color, fixd: Dictionary, r: Dictionary = rules()) -> Color:
	var t: Color = desat(eff, float(fixd.get("sat", 1.0)))
	var g: float = float(fixd.get("val", 1.0))
	var gm: float = float(r.get("tint_gain_max", 1.6))
	var k: Vector3 = Vector3(t.r * g / maxf(eff.r, 0.004), t.g * g / maxf(eff.g, 0.004), t.b * g / maxf(eff.b, 0.004))
	k = k.clamp(Vector3.ZERO, Vector3.ONE * gm)
	return Color(snappedf(k.x, 0.001), snappedf(k.y, 0.001), snappedf(k.z, 0.001))


## The average display colour of a texture (cut-out pixels ignored) from a 16x16 copy; Color(-1) when unreadable.
static func texture_average(t: Texture2D) -> Color:
	var img: Image = small_image(t)
	if img == null:
		return Color(-1, -1, -1)
	var acc: Vector3 = Vector3.ZERO
	var w: float = 0.0
	for y: int in img.get_height():
		for x: int in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.a < 0.3:
				continue   # cut-out leaves, fence gaps: what shows is what counts
			acc += Vector3(c.r, c.g, c.b)
			w += 1.0
	if w <= 0.0:
		return Color(-1, -1, -1)
	acc /= w
	return Color(acc.x, acc.y, acc.z)


static func small_image(t: Texture2D) -> Image:
	if t == null:
		return null
	var img: Image = t.get_image()
	if img == null or img.is_empty():
		return null
	img = img.duplicate() as Image
	if img.is_compressed() and img.decompress() != OK:
		return null
	if img.has_mipmaps():
		img.clear_mipmaps()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(16, 16, Image.INTERPOLATE_BILINEAR)
	return img


## T-214: a code-built NoiseTexture2D whose colour ramp (times the material's colour) fights the palette: a copy
## whose ramp is desaturated / darkened by the same rule as a texture (tex_fix_for); null when it is inside already.
static func noise_fix(t: NoiseTexture2D, own: Color, r: Dictionary) -> NoiseTexture2D:
	if t == null or t.color_ramp == null or t.color_ramp.get_point_count() == 0:
		return null
	var acc: Vector3 = Vector3.ZERO
	for i: int in 16:
		var gc: Color = t.color_ramp.sample(float(i) / 15.0)
		acc += Vector3(gc.r, gc.g, gc.b)
	acc /= 16.0
	var eff: Color = Color(acc.x * own.r, acc.y * own.g, acc.z * own.b)
	if eff.s <= sat_cap(eff, false, r) + 0.005 and eff.v <= float(r.get("val_max", 0.9)) + 0.005:
		return null
	var fx: Dictionary = tex_fix_for(eff, r)
	var g: Gradient = t.color_ramp.duplicate() as Gradient
	for i2: int in g.get_point_count():
		var pc: Color = desat(g.get_color(i2), float(fx.get("sat", 1.0)))
		var k: float = float(fx.get("val", 1.0))
		g.set_color(i2, Color(pc.r * k, pc.g * k, pc.b * k, pc.a))
	var nt: NoiseTexture2D = t.duplicate() as NoiseTexture2D
	nt.color_ramp = g
	return nt


## The fix for a texture the data can't name (built in code, no resource path): read once at load, small ones only.
static func runtime_fix(m: Material, t: Texture2D, r: Dictionary) -> Dictionary:
	if t == null or t.resource_path != "" or t.get_width() * t.get_height() > 512 * 512:
		return {}
	var a: Color = texture_average(t)
	if a.r < 0.0:
		return {}
	var c: Color = own_color(m)
	var eff: Color = Color(a.r * c.r, a.g * c.g, a.b * c.b)
	if eff.s <= sat_cap(eff, false, r) + 0.005 and eff.v <= float(r.get("val_max", 0.9)) + 0.005:
		return {}
	var fx: Dictionary = tex_fix_for(eff, r)
	fx["eff"] = eff.to_html(false)
	return fx


# ================================================================== the rules

## Why a material is outside the pass ("" = it is checked): transparent, unshaded, emissive, another shader.
static func exempt_reason(m: Material) -> String:
	if m is BaseMaterial3D:
		var b: BaseMaterial3D = m
		if b.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA or b.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS:
			return "transparent"
		if b.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
			return "unshaded"
		if b.emission_enabled and b.emission_energy_multiplier > 0.0 and b.emission != Color.BLACK:
			return "emissive"
		return ""
	if m is ShaderMaterial:
		var sh: Shader = (m as ShaderMaterial).shader
		if sh != null and sh.resource_path == SURFACE_SHADER:
			if float(_param(m as ShaderMaterial, "emission_energy", 0.0)) > 0.0:
				return "emissive"
			return ""
		return "shader %s" % (sh.resource_path.get_file() if sh != null and sh.resource_path != "" else "(built in code)")
	return "other material (%s)" % m.get_class()


static func _param(m: ShaderMaterial, k: String, def: Variant) -> Variant:
	var v: Variant = m.get_shader_parameter(k)
	if v == null and m.shader != null:
		v = RenderingServer.shader_get_parameter_default(m.shader.get_rid(), k)
	return def if v == null else v


## The colour a material shows on average: its albedo colour times its texture's average (`tex_avg`: path -> Color,
## the audit's; a texture it has no average for counts as white). Pure.
static func effective_albedo(m: Material, tex_avg: Dictionary = {}) -> Color:
	var c: Color = Color.WHITE
	if m is BaseMaterial3D:
		c = (m as BaseMaterial3D).albedo_color
	elif m is ShaderMaterial:
		var tint: Variant = _param(m as ShaderMaterial, "albedo_tint", Color.WHITE)
		c = tint if tint is Color else Color.WHITE
	var t: Texture2D = albedo_texture(m)
	if t != null and tex_avg.has(tex_key(t)):
		var a: Color = tex_avg[tex_key(t)]
		c = Color(c.r * a.r, c.g * a.g, c.b * a.b)
	if m is ShaderMaterial:
		c = desat(c, float(_param(m as ShaderMaterial, "albedo_saturation", 1.0)))
	return c


## Whether the material's colour is known: no albedo texture, or one the audit read; vertex colours decide nothing.
static func albedo_known(m: Material, tex_avg: Dictionary = {}) -> bool:
	if m is BaseMaterial3D and (m as BaseMaterial3D).vertex_color_use_as_albedo:
		return false
	var t: Texture2D = albedo_texture(m)
	return t == null or tex_avg.has(tex_key(t))


## The outliers of one material: {issues: [...], exempt: why or "", ...}. `tex_avg` / `tex_rough_avg`: path -> the
## texture's average (Color / float), the audit's; `node` the first user (its name decides the word lists).
static func evaluate(m: Material, node: Node = null, tex_avg: Dictionary = {}, tex_rough_avg: Dictionary = {}, r: Dictionary = rules()) -> Dictionary:
	var why: String = exempt_reason(m)
	if why != "":
		return {"issues": [], "exempt": why}
	var words: String = words_of(m, node)
	var issues: Array = []
	var alb: Color = effective_albedo(m, tex_avg)
	var accent: bool = is_accent(alb, r) and has_word(words, r.get("accent_words", []))
	var low_ok: bool = has_word(words, r.get("low_rough_words", []))
	if m is BaseMaterial3D:
		var b: BaseMaterial3D = m
		var metal: float = b.metallic
		var floor_: float = float(r.get("rough_floor_metal", 0.35)) if metal >= float(r.get("metal_threshold", 0.5)) else float(r.get("rough_floor", 0.45))
		var rough: float = b.roughness
		if b.roughness_texture != null and tex_rough_avg.has(tex_key(b.roughness_texture)):
			rough *= float(tex_rough_avg[tex_key(b.roughness_texture)])
		if rough < floor_ - 0.001 and not low_ok:
			issues.append("rough_low")
		var pl: Dictionary = r.get("plastic", {})
		if b.albedo_texture == null and rough < float(pl.get("rough_below", 0.5)) and metal < float(pl.get("metal_below", 0.3)) \
				and alb.s > float(pl.get("sat_above", 0.3)) + 0.005 and not accent and not low_ok:
			issues.append("clean_plastic")
		if not b.detail_enabled and not has_word(words, r.get("no_wear_words", [])):
			issues.append("no_wear")
	elif m is ShaderMaterial:
		var sm: ShaderMaterial = m
		if float(_param(sm, "grime", 0.35)) < float(r.get("grime_min", 0.35)) - 0.001 and not has_word(words, r.get("no_wear_words", [])):
			issues.append("no_wear")
		if float(_param(sm, "rough_max", 1.0)) < float(r.get("rough_floor", 0.45)) - 0.001 and not low_ok:
			issues.append("rough_low")
	if albedo_known(m, tex_avg):
		if alb.s > sat_cap(alb, accent, r) + 0.005 and alb.v > 0.08 and not accent:
			issues.append("albedo_sat")
		if (alb.v > float(r.get("val_max", 0.9)) + 0.005 or alb.v < float(r.get("val_min", 0.04)) - 0.005) and not low_ok:
			issues.append("albedo_value")
	return {"issues": issues, "exempt": "", "albedo": alb, "accent": accent}


# ================================================================== the fixes

## Brings one material inside the rules (once: a material carries the META after). Returns what it changed.
static func fix(m: Material, node: Node = null, r: Dictionary = rules()) -> Array:
	if m == null or m.has_meta(META) or exempt_reason(m) != "":
		return []
	m.set_meta(META, true)
	var words: String = words_of(m, node)
	var low_ok: bool = has_word(words, r.get("low_rough_words", []))
	var accent_word: bool = has_word(words, r.get("accent_words", []))
	var changed: Array = []
	if m is BaseMaterial3D:
		var b: BaseMaterial3D = m
		var floor_: float = float(r.get("rough_floor_metal", 0.35)) if b.metallic >= float(r.get("metal_threshold", 0.5)) else float(r.get("rough_floor", 0.45))
		var pl: Dictionary = r.get("plastic", {})
		if b.albedo_texture == null and b.roughness_texture == null and b.metallic < float(pl.get("metal_below", 0.3)) \
				and b.roughness < float(pl.get("rough_below", 0.5)) and b.albedo_color.s > float(pl.get("sat_above", 0.3)) \
				and not (is_accent(b.albedo_color, r) and accent_word):
			floor_ = maxf(floor_, float(pl.get("rough_below", 0.5)) + 0.05)   # clean plastic: past the plastic line, to enamel
		if not low_ok:
			if b.roughness_texture == null:
				if b.roughness < floor_:
					b.roughness = floor_
					changed.append("rough")
			else:
				var tr: Dictionary = r.get("tex_rough", {})
				var p: String = tex_key(b.roughness_texture)
				if tr.has(p) and b.roughness < float(tr[p]):
					b.roughness = minf(1.0, float(tr[p]))
					changed.append("rough")
		# the albedo: a flat colour clamped in HSV, a texture through the audit's tint
		var c: Color = b.albedo_color
		if b.albedo_texture != null:
			var tt: Dictionary = r.get("tex_fix", {})
			var tp: String = tint_key(b)
			var fx: Dictionary = tt[tp] if tt.has(tp) else runtime_fix(m, b.albedo_texture, r)
			if not accent_word and fx.is_empty() and b.albedo_texture is NoiseTexture2D and b.albedo_texture.resource_path == "":
				# T-214: a noise texture built in code is not generated yet at load (Map 0's red draft curtains kept
				# their red): its colour ramp is the colour, so the ramp is desaturated instead
				var nz: NoiseTexture2D = noise_fix(b.albedo_texture as NoiseTexture2D, c, r)
				if nz != null:
					b.albedo_texture = nz
					changed.append("tint")
			elif not accent_word and not fx.is_empty():
				var nt: Texture2D = desat_texture(b.albedo_texture, fx)
				if nt != null:
					b.albedo_texture = nt
					changed.append("tint")
				elif fx.has("eff"):
					var t: Color = base_tint(LookGrade.color(fx["eff"], Color.WHITE), fx, r)
					if not t.is_equal_approx(Color.WHITE):
						b.albedo_color = Color(c.r * t.r, c.g * t.g, c.b * t.b, c.a)
						changed.append("tint")
		else:
			var nc: Color = clamp_albedo(c, r, is_accent(c, r) and accent_word, low_ok)
			if not nc.is_equal_approx(c):
				b.albedo_color = nc
				changed.append("albedo")
		# the wear layer: the shared grime map at the strength and size of the material's class (T-214)
		if not b.detail_enabled and not has_word(words, r.get("no_wear_words", [])) and detail_texture(r) != null:
			var dc: Dictionary = detail_class(b, words, r)
			var tile: float = maxf(0.25, float(dc.get("tile_m", 2.5)))
			b.detail_enabled = true
			b.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
			b.detail_albedo = detail_texture(r)
			var strength: float = clampf(float(dc.get("strength", 1.0)), 0.0, 1.0)
			if strength < 0.999:
				b.detail_mask = detail_mask(strength)
			if b.albedo_texture == null and b.normal_texture == null and b.roughness_texture == null and b.metallic_texture == null \
					and b.get("orm_texture") == null and not b.uv1_triplanar:
				b.detail_uv_layer = BaseMaterial3D.DETAIL_UV_1
				b.uv1_triplanar = true
				b.uv1_world_triplanar = true
				b.uv1_scale = Vector3.ONE / tile
			elif not b.uv2_triplanar and not b.ao_on_uv2 and not b.emission_on_uv2:
				# a textured material: the grime on its own triplanar (UV2) at the class's size, not stretched over the
				# texture's UVs (a wall's 4 m UV tile made 2 m blotches: the camouflage on Mondlicht's concrete)
				b.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
				b.uv2_triplanar = true
				b.uv2_world_triplanar = false
				b.uv2_scale = Vector3.ONE / tile
			else:
				b.detail_uv_layer = BaseMaterial3D.DETAIL_UV_1
			changed.append("wear")
	elif m is ShaderMaterial:
		var sm: ShaderMaterial = m
		var gmin: float = float(r.get("grime_min", 0.35))
		if float(_param(sm, "grime", 0.35)) < gmin and not has_word(words, r.get("no_wear_words", [])):
			sm.set_shader_parameter("grime", gmin)
			changed.append("wear")
		var tint: Variant = _param(sm, "albedo_tint", Color.WHITE)
		var stex: Texture2D = albedo_texture(sm)
		var stt: Dictionary = r.get("tex_fix", {})
		var fx: Dictionary = {}
		if tint is Color and stex != null and not accent_word:
			fx = stt[tint_key(sm)] if stt.has(tint_key(sm)) else runtime_fix(sm, stex, r)
		if not fx.is_empty():
			sm.set_shader_parameter("albedo_saturation", float(fx.get("sat", 1.0)))
			var g: float = float(fx.get("val", 1.0))
			if g < 0.999:
				var tc: Color = tint
				sm.set_shader_parameter("albedo_tint", Color(tc.r * g, tc.g * g, tc.b * g, tc.a))
			changed.append("tint")
		elif tint is Color and stex == null:
			var nt: Color = clamp_albedo(tint, r, is_accent(tint, r) and accent_word, low_ok)
			if not nt.is_equal_approx(tint):
				sm.set_shader_parameter("albedo_tint", nt)
				changed.append("albedo")
		var rmax: float = float(_param(sm, "rough_max", 1.0))
		if rmax < float(r.get("rough_floor", 0.45)) and not low_ok:
			sm.set_shader_parameter("rough_max", float(r.get("rough_floor", 0.45)))
			changed.append("rough")
	return changed


## T-214: the grime layer's strength and size for a material: the file's `detail` block, then the first
## `detail_classes` entry that fits it ({"words": [...]} in its name / path, "untextured": true, "min_value": v of its
## flat colour). Pale flat walls and clean concrete / steel take a light, small grime; Map 0's timber keeps the old.
static func detail_class(b: BaseMaterial3D, words: String, r: Dictionary = rules()) -> Dictionary:
	var out: Dictionary = (r.get("detail", {}) as Dictionary).duplicate()
	for c: Variant in r.get("detail_classes", []):
		var cd: Dictionary = c
		if cd.has("words") and not has_word(words, cd["words"]):
			continue
		if bool(cd.get("untextured", false)) and b.albedo_texture != null:
			continue
		if cd.has("min_value") and (b.albedo_texture != null or b.albedo_color.v < float(cd["min_value"])):
			continue
		for k: String in ["strength", "tile_m"]:
			if cd.has(k):
				out[k] = cd[k]
		break
	return out


## A flat detail mask of `strength` (the grime layer's mix; the mask's red channel scales the detail in Godot's
## material). One small texture per strength, shared.
static func detail_mask(strength: float) -> Texture2D:
	var key: int = int(round(strength * 100.0))
	if not _masks.has(key):
		var img: Image = Image.create(4, 4, false, Image.FORMAT_L8)
		img.fill(Color(strength, strength, strength))
		_masks[key] = ImageTexture.create_from_image(img)
	return _masks[key]


## T-214: what the pass does to materials it otherwise leaves alone (emissive, unshaded; once, its own meta):
##   "emission": [{"hue", "width", "scale"}] an emissive material whose glow is in the hue window glows `scale` x
##               (der Kranich's violet strips at half);
##   "accent_caps": [{"node", "hue", "width", "sat_max", "val_max"}] an unshaded / emissive colour on a node whose
##               path holds `node`, in the hue window, capped (Kaltenbrunn's pylon cable in the snow);
##   "lit_smoke": true  an unshaded alpha particle smoke (Props.smoke) is lit by the scene instead, so a smoke column
##               in a dark hall is dark (Totenhafen's cannery stove read as a pale ghost).
## Returns what it changed.
static func fix_special(m: Material, node: Node, r: Dictionary = rules()) -> Array:
	var out: Array = []
	if m == null or m.has_meta(&"gl_look_mat2") or not (m is BaseMaterial3D or m is ShaderMaterial):
		return out
	m.set_meta(&"gl_look_mat2", true)
	var path: String = String(node.get_path()) if node != null and node.is_inside_tree() else (String(node.name) if node != null else "")
	for e: Variant in r.get("emission", []):
		var ed: Dictionary = e
		if m is BaseMaterial3D and (m as BaseMaterial3D).emission_enabled:
			var b: BaseMaterial3D = m
			if _in_hue(b.emission, ed):
				b.emission_energy_multiplier *= float(ed.get("scale", 1.0))
				out.append("emission")
				break
		elif m is ShaderMaterial and (m as ShaderMaterial).shader != null and (m as ShaderMaterial).shader.resource_path == SURFACE_SHADER:
			var ec: Variant = _param(m as ShaderMaterial, "emission_color", Color.BLACK)
			if ec is Color and _in_hue(ec, ed) and float(_param(m as ShaderMaterial, "emission_energy", 0.0)) > 0.0:
				(m as ShaderMaterial).set_shader_parameter("emission_energy", float(_param(m as ShaderMaterial, "emission_energy", 0.0)) * float(ed.get("scale", 1.0)))
				out.append("emission")
				break
	if m is BaseMaterial3D:
		var b2: BaseMaterial3D = m
		var glows: bool = b2.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED or b2.emission_enabled
		for a: Variant in r.get("accent_caps", []):
			var ad: Dictionary = a
			if not glows or (ad.has("node") and not path.contains(str(ad["node"]))) or not _in_hue(b2.albedo_color, ad):
				continue
			var c: Color = b2.albedo_color
			b2.albedo_color = Color.from_hsv(c.h, minf(c.s, float(ad.get("sat_max", 1.0))), minf(c.v, float(ad.get("val_max", 1.0))), c.a)
			if b2.emission_enabled:
				var ec2: Color = b2.emission
				b2.emission = Color.from_hsv(ec2.h, minf(ec2.s, float(ad.get("sat_max", 1.0))), minf(ec2.v, float(ad.get("val_max", 1.0))), ec2.a)
			out.append("accent_cap")
			break
		if bool(r.get("lit_smoke", false)) and b2.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED \
				and b2.billboard_mode == BaseMaterial3D.BILLBOARD_PARTICLES and b2.vertex_color_use_as_albedo \
				and b2.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and b2.blend_mode == BaseMaterial3D.BLEND_MODE_MIX \
				and not b2.emission_enabled:
			b2.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
			b2.roughness = 1.0
			b2.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			out.append("lit_smoke")
	return out


static func _in_hue(c: Color, d: Dictionary) -> bool:
	if not d.has("hue"):
		return true
	if c.s < float(d.get("min_sat", 0.3)):
		return false
	return absf(wrapf(c.h * 360.0 - float(d["hue"]), -180.0, 180.0)) <= float(d.get("width", 20.0))


## A flat colour inside the palette: saturation under sat_max (an accent keeps its own), value 0.04..0.90. Pure.
static func clamp_albedo(c: Color, r: Dictionary = rules(), accent: bool = false, low_ok: bool = false) -> Color:
	var h: float = c.h
	var s: float = c.s
	var v: float = c.v
	if not accent:
		s = minf(s, sat_cap(c, false, r) - 0.005)
	if not low_ok:
		v = clampf(v, float(r.get("val_min", 0.04)), float(r.get("val_max", 0.9)))
	if is_equal_approx(s, c.s) and is_equal_approx(v, c.v):
		return c
	return Color.from_hsv(h, s, v, c.a)


## UPDATE 19 (T-252): MaterialLibrary.apply_runtime on every material under `root` (MapRoot._ready, before the pass
## below): a scene's baked library materials brought up to data/gravelight/materials.json. Returns [materials that
## took the variation values, materials rewritten whole (a `live` key)]. It lives here, not in MaterialLibrary, so
## that class stays free of the look's scripts (the map generators load it as plain SceneTree scripts).
static func apply_library(root: Node) -> Array:
	var out: Array = [0, 0]
	if root == null:
		return out
	for e: Dictionary in collect(root):
		var r: int = MaterialLibrary.apply_runtime(e["mat"] as Material)
		if r > 0:
			out[r - 1] = int(out[r - 1]) + 1
	return out


## The pass over a whole map (LookGrade.attach): every world material fixed once. Returns {materials, changed,
## skipped, exempt, ms}.
static func apply_tree(root: Node, r: Dictionary = rules()) -> Dictionary:
	var t0: int = Time.get_ticks_usec()
	var out: Dictionary = {"materials": 0, "changed": 0, "skipped": 0, "exempt": 0}
	if root == null or r.is_empty():
		return out
	for e: Dictionary in collect(root, r):
		out["materials"] = int(out["materials"]) + 1
		if String(e["skip"]) != "":
			out["skipped"] = int(out["skipped"]) + 1
			continue
		var m: Material = e["mat"]
		if not fix_special(m, e["node"], r).is_empty():
			out["special"] = int(out.get("special", 0)) + 1
		if exempt_reason(m) != "":
			out["exempt"] = int(out["exempt"]) + 1
			continue
		if not fix(m, e["node"], r).is_empty():
			out["changed"] = int(out["changed"]) + 1
	out["ms"] = float(Time.get_ticks_usec() - t0) / 1000.0
	return out
