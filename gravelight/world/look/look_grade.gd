class_name LookGrade
extends RefCounted
## UPDATE 12 section 1 (DECISIONS T-207, contract C2): one colour grade per map from `data/look/<map_id>.json`,
## applied to the map's Environment at load (MapRoot), to the main menu's (MenuScene) and to every cutscene stage
## that plays over it (CinemaReel: the host map's grade, `menu` in the theatre, `cinema_reel` for the archive-reel
## history scenes). Environment-only: tonemap, exposure, the adjustments, a generated 3D colour-correction LUT (the
## split tone, the selective desaturation that keeps Nachtglas violet and blood red, the black lift), ambient scale,
## fog and volumetric fog. `post_params()` hands the `post` block (grain, vignette, edge softness, chromatic
## aberration) to section 2's post shader; nothing here draws.
##
## Rules (unit-tested in gravelight/tests/unit/test_look_grade.gd):
##   - a key that is absent leaves the map's own value alone; a map with no file is untouched;
##   - `zones` merge over the map's block (deep merge), `resolved(map_id, zone)`;
##   - the web / Compatibility profile merges `data/look/_web.json` over every grade (no LUT there);
##   - `--look=off` among the user command-line args (after `--`) turns every grade off (the "before" frames);
##   - the player's Brightness slider still scales the grade's brightness (GLSettings' gl_base_brightness, T-133),
##     and the horror layer's darker night (gl_horror_mult, T-192) still multiplies it.
## Presentation only: no gameplay number, timing, hitbox, navmesh or prompt is read or written here.

const DIR: String = "res://data/look/"
const WEB_FILE: String = "res://data/look/_web.json"
const LUT_SIZE: int = 32
const TONEMAPS: Dictionary = {
	"linear": Environment.TONE_MAPPER_LINEAR, "filmic": Environment.TONE_MAPPER_FILMIC,
	"aces": Environment.TONE_MAPPER_ACES, "agx": Environment.TONE_MAPPER_AGX,
}
## The post block's defaults when a file has a `post` block that leaves one out.
const POST_DEFAULTS: Dictionary = {"grain": 0.05, "vignette": 0.35, "edge_soft": 0.2, "ca": 0.001}

static var _cache: Dictionary = {}
static var _luts: Dictionary = {}
static var _off: int = -1   # -1 unread, 0 on, 1 off (the --look=off user arg)
## T-208: the material audit loads a map with the material pass held back (its "before"); nothing else sets it.
static var hold_materials: bool = false


# ================================================================== data

## The raw grade of a map id ({} when there is no file), the web overrides merged in on the Compatibility renderer.
static func data(map_id: String) -> Dictionary:
	var key: String = map_id + ("|web" if GLSettings.is_compat() else "")
	if _cache.has(key):
		return _cache[key]
	var d: Dictionary = load_file(DIR + map_id + ".json")
	if not d.is_empty() and GLSettings.is_compat():
		d = merge(d, load_file(WEB_FILE))   # the shared web overrides (no LUT on Compatibility) ...
		d = merge(d, d.get("web", {}))      # ... then the map's own `web` block (a plain saturation instead)
	_cache[key] = d
	return d


static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var v: Variant = JSON.parse_string(f.get_as_text())
	return v if v is Dictionary else {}


static func has(map_id: String) -> bool:
	return not data(map_id).is_empty()


## Forget the loaded files (tests, the dev console after an edit).
static func reset_cache() -> void:
	_cache.clear()
	_luts.clear()
	_off = -1


## Every grade is off while `--look=off` is among the user args (after `--`), for the "before" captures.
static func disabled() -> bool:
	if _off < 0:
		_off = 0
		for a: String in OS.get_cmdline_user_args():
			if a == "--look=off":
				_off = 1
	return _off == 1


## `over` merged into a copy of `base`: dictionaries merge key by key, anything else replaces.
static func merge(base: Dictionary, over: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	for k: Variant in over.keys():
		if out.has(k) and out[k] is Dictionary and over[k] is Dictionary:
			out[k] = merge(out[k], over[k])
		else:
			out[k] = over[k].duplicate(true) if over[k] is Dictionary or over[k] is Array else over[k]
	return out


## The map's grade with `zone`'s block merged over it (the `zones` key dropped); {} when the map has no file.
static func resolved(map_id: String, zone: String = "") -> Dictionary:
	var d: Dictionary = data(map_id)
	if d.is_empty():
		return {}
	var zones: Dictionary = d.get("zones", {})
	var out: Dictionary = d.duplicate(true)
	out.erase("zones")
	if zone != "" and zones.has(zone):
		out = merge(out, zones[zone])
	return out


## The `post` block for section 2's shader (grain, vignette, edge_soft, ca, and whatever else the file adds), the
## defaults filled in; {} when the map has no file or no post block (the shader keeps its own).
static func post_params(map_id: String, zone: String = "") -> Dictionary:
	if disabled():
		return {}
	var d: Dictionary = resolved(map_id, zone)
	if not d.has("post"):
		return {}
	return merge(POST_DEFAULTS, d["post"])


# ================================================================== applying

## Applies the map's grade (and `zone`'s block) to `env`; returns what was applied ({} when nothing: no file, off).
static func apply(env: Environment, map_id: String, zone: String = "") -> Dictionary:
	if env == null or disabled():
		return {}
	var d: Dictionary = resolved(map_id, zone)
	if d.is_empty():
		return {}
	apply_dict(env, d)
	env.set_meta("gl_look", map_id if zone == "" else map_id + ":" + zone)
	return d


## The MapRoot hook: the map's WorldEnvironment gets `data/look/<map_id>.json`; a WorldEnvironment script with
## `look_zones(zones)` (Kaltenbrunn's depth grade) gets the file's zones to blend by itself.
static func attach(map: Node) -> Dictionary:
	if map == null or disabled():
		return {}
	var id: String = String(map.get("map_id")) if map.get("map_id") != null else ""
	if id == "" or not has(id):
		return {}
	var we: WorldEnvironment = find_env(map)
	if we == null or we.environment == null:
		return {}
	var d: Dictionary = apply(we.environment, id)
	if we.has_method("look_zones"):
		we.call("look_zones", data(id).get("zones", {}))
	elif LookZones.has_boxes(data(id).get("zones", {})):
		# T-214: any other map's zones with `boxes` (Map 0's inn: the interior haze cut) follow the camera
		var lz: LookZones = LookZones.new()
		lz.setup(we.environment, data(id).get("zones", {}), map)
		map.add_child(lz)
	var sp: Array = d.get("shader_params", [])
	apply_shader_params(map, sp)
	if not sp.is_empty() and map.is_inside_tree():
		# a set piece built later (the living world's extra searchlights on Thalbach's ridges, rebuilt beams) gets it
		# too: every mesh that enters the map from now on, while the map lives
		var tree: SceneTree = map.get_tree()
		var hook: Callable = func(n: Node) -> void:
			if n is GeometryInstance3D and is_instance_valid(map) and map.is_ancestor_of(n):
				apply_shader_params(n, sp, true)
		tree.node_added.connect(hook)
		map.tree_exiting.connect(func() -> void:
			if tree.node_added.is_connected(hook):
				tree.node_added.disconnect(hook), CONNECT_ONE_SHOT)
	apply_nodes(map, d.get("nodes", []))
	var dome: Dictionary = d.get("sky_dome", {})   # UPDATE 19 (T-252): a night-sky dome for a map without a Landscape
	if not dome.is_empty() and map.find_child("SkyDome", true, false) == null:
		NightSkyDome.add_to(map, dome)
	map.set_meta("gl_look", id)
	if not hold_materials and not map.has_meta("gl_look_materials"):   # T-208: the material pass (roughness floor, palette, the wear layer)
		var mp: Dictionary = LookMaterials.apply_tree(map, LookMaterials.rules_for(id))
		map.set_meta("gl_look_materials", mp)
		print("[LookMaterials] %s: %d materials, %d fixed, %d exempt, %d skipped, %.1f ms" % [id, int(mp.get("materials", 0)),
			int(mp.get("changed", 0)), int(mp.get("exempt", 0)), int(mp.get("skipped", 0)), float(mp.get("ms", 0.0))])
	return d


## T-214: the grade's `shader_params` list, [{"shader": "<file name>", "node": "<path substring>", "params": {...}}]:
## every ShaderMaterial of that shader under `root` (on a node whose path holds `node`, when given) gets the params
## (a "#rrggbb" string is a colour). Thalbach's cloud deck: the searchlight spots no longer burn white; Kaltenbrunn's
## far ridge. Returns how many materials it set.
static func apply_shader_params(root: Node, list: Array, only_root: bool = false) -> int:
	if root == null or list.is_empty():
		return 0
	var n: int = 0
	var seen: Dictionary = {}
	var nodes: Array = [root] if only_root else root.find_children("*", "GeometryInstance3D", true, false)
	for g: Node in nodes:
		if not (g is GeometryInstance3D):
			continue
		var path: String = String(g.get_path()) if only_root and g.is_inside_tree() else String(root.get_path_to(g))
		for m: Material in LookMaterials.materials_of(g as GeometryInstance3D):
			if not (m is ShaderMaterial) or seen.has(m.get_instance_id()):
				continue
			var sh: Shader = (m as ShaderMaterial).shader
			if sh == null:
				continue
			for e: Variant in list:
				var ed: Dictionary = e
				if ed.has("shader") and not sh.resource_path.get_file().contains(str(ed["shader"])):
					continue   # (no "shader": any shader on the named node, e.g. one built in code)
				if not ed.has("shader") and not ed.has("node"):
					continue
				if ed.has("node") and not path.contains(str(ed["node"])):
					continue
				var pr: Dictionary = ed.get("params", {})
				for k: Variant in pr.keys():
					var v: Variant = pr[k]
					if v is Array and (v as Array).size() == 3:
						v = Vector3(float(v[0]), float(v[1]), float(v[2]))   # a vec3 uniform (a beam's colour)
					(m as ShaderMaterial).set_shader_parameter(str(k), color(v) if v is String else v)
				seen[m.get_instance_id()] = true
				n += 1
				break
	return n


## T-214: the grade's `nodes` list, [{"path": "Landscape/RidgeBand1", "scale": [x, y, z]}]: a far set piece reshaped
## for the frame (presentation only: never a collider, a navmesh or anything a player can reach).
static func apply_nodes(root: Node, list: Array) -> int:
	var n: int = 0
	for e: Variant in list:
		var ed: Dictionary = e
		var nd: Node = root.get_node_or_null(NodePath(str(ed.get("path", ""))))
		if not (nd is Node3D):
			continue
		if ed.get("scale", null) is Array:
			var sc: Array = ed["scale"]
			(nd as Node3D).scale *= Vector3(float(sc[0]), float(sc[1]), float(sc[2]))
		if ed.get("material", null) is Dictionary and nd is GeometryInstance3D:
			for m: Material in LookMaterials.materials_of(nd as GeometryInstance3D):
				set_props(m, ed["material"])   # a material's own properties by name (roughness, specular, ...)
		n += 1
	return n


## T-208: the MapRoot's _enter_tree hook, before any child's _ready (so a flicker or power script caches the new
## energy): the grade's `lights` block on the map's omni / spot lights. Returns how many lights it changed.
static func attach_scene(map: Node) -> int:
	if map == null or disabled() or map.has_meta("gl_look_lights"):
		return 0
	var id: String = String(map.get("map_id")) if map.get("map_id") != null else ""
	if id == "" or not has(id):
		return 0
	map.set_meta("gl_look_lights", id)
	return apply_lights(map, resolved(id).get("lights", {}))


## The `lights` block (darker nights, stronger practicals; DECISIONS T-208) on every OmniLight3D / SpotLight3D under
## `root` (and a DirectionalLight3D, by a rule that names "type": "directional"):
##   "practical_scale": x   the energy of every lamp (warm, cold or red: the practicals) times x; a light a rule
##                          matches is left to its rule;
##   "rules": [{...}, ...]  the first rule that matches a light decides it. Match (every key optional):
##                          "hue" / "width" / "min_sat" its colour (a hue window, saturated past min_sat), "type"
##                          omni | spot | directional, "name" substrings of its name, "min_range" / "max_range" its
##                          reach, "box" [x0, y0, z0, x1, y1, z1] where it stands (map frame);
##                          effects: "energy_scale", "range_scale", "fog_scale" (its volumetric fog energy),
##                          "sat_scale" (its colour toward white: a violet fill becomes a neutral one, T-214),
##                          "color" (a new colour), "pool": {"range", "energy"} (a small light of the old colour
##                          left under it: the tube keeps its own violet pool while its fill goes neutral, T-214).
##                          Groom Lake's crater lamps keep their violet on the Nachtglas and stop lighting the salt.
## The base energy a script keeps in the light's `energy` meta (power switches, the director's fog tween) scales too.
static func apply_lights(root: Node, block: Dictionary) -> int:
	if root == null or block.is_empty():
		return 0
	var practical: float = float(block.get("practical_scale", 1.0))
	var rules: Array = block.get("rules", [])
	var n: int = 0
	for l: Node in root.find_children("*", "Light3D", true, false):
		var lt: Light3D = l as Light3D
		var at: Vector3 = _rel_origin(lt, root)
		var rule: Dictionary = light_rule(lt.light_color, rules, lt, at)
		if lt is DirectionalLight3D and rule.is_empty():
			continue   # the sun / moon: only a rule that names it
		var e_scale: float = float(rule.get("energy_scale", 1.0)) if not rule.is_empty() else practical
		var changed: bool = false
		var old_col: Color = lt.light_color
		var old_e: float = lt.light_energy
		if not is_equal_approx(e_scale, 1.0):
			lt.light_energy *= e_scale
			if lt.has_meta("energy"):
				lt.set_meta("energy", float(lt.get_meta("energy")) * e_scale)
			if lt.get("base_energy") != null:   # T-214: FlickerLight / HumPulse drive their energy from base_energy
				lt.set("base_energy", float(lt.get("base_energy")) * e_scale)
			changed = true
		if not rule.is_empty():
			var rs: float = float(rule.get("range_scale", 1.0))
			if not is_equal_approx(rs, 1.0):
				if lt is OmniLight3D:
					(lt as OmniLight3D).omni_range *= rs
				elif lt is SpotLight3D:
					(lt as SpotLight3D).spot_range *= rs
				changed = true
			if rule.has("fog_scale"):
				lt.light_volumetric_fog_energy *= float(rule["fog_scale"])
				changed = true
			if rule.has("color"):
				lt.light_color = color(rule["color"], lt.light_color)
				changed = true
			if rule.has("sat_scale"):
				var c: Color = lt.light_color
				lt.light_color = Color.from_hsv(c.h, c.s * float(rule["sat_scale"]), c.v, c.a)
				changed = true
			if rule.get("pool", null) is Dictionary and lt is OmniLight3D and old_e > 0.0:
				var pd: Dictionary = rule["pool"]
				var pool: OmniLight3D = OmniLight3D.new()
				pool.name = "LookPool"
				pool.light_color = old_col
				pool.light_energy = old_e * float(pd.get("energy", 1.0))
				pool.omni_range = float(pd.get("range", 3.0))
				pool.omni_attenuation = float(pd.get("attenuation", 1.4))
				pool.shadow_enabled = false
				pool.light_volumetric_fog_energy = float(pd.get("fog", 0.0))
				pool.light_specular = lt.light_specular
				lt.add_child.call_deferred(pool)
		if changed:
			n += 1
	return n


## Where `n` stands in `root`'s frame, from the local transforms (the map's _enter_tree: nothing is in the tree yet).
static func _rel_origin(n: Node, root: Node) -> Vector3:
	var xf: Transform3D = Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf.origin


## The first rule of `rules` that matches a light of colour `c` ({} for none). Pure: `light` (its type, name and
## range) and `at` (where it stands) only matter to a rule that asks about them; a rule with a `hue` only takes a
## saturated colour in its window.
static func light_rule(c: Color, rules: Array, light: Light3D = null, at: Vector3 = Vector3.ZERO) -> Dictionary:
	for r: Variant in rules:
		if not (r is Dictionary):
			continue
		var rd: Dictionary = r
		if rd.has("type"):
			var ty: String = str(rd["type"])
			if light == null or (ty == "omni" and not light is OmniLight3D) or (ty == "spot" and not light is SpotLight3D) 					or (ty == "directional" and not light is DirectionalLight3D):
				continue
		elif light is DirectionalLight3D:
			continue
		if rd.has("name"):
			if light == null:
				continue
			var nm: String = String(light.name)
			var names: Array = rd["name"] if rd["name"] is Array else [rd["name"]]
			if not names.any(func(w: Variant) -> bool: return nm.contains(str(w))):
				continue
		if rd.has("min_range") or rd.has("max_range"):
			var rg: float = (light as OmniLight3D).omni_range if light is OmniLight3D else ((light as SpotLight3D).spot_range if light is SpotLight3D else 0.0)
			if rg < float(rd.get("min_range", -1.0)) or rg > float(rd.get("max_range", 1e9)):
				continue
		if rd.has("box"):
			var bx: Array = rd["box"]
			if at.x < float(bx[0]) or at.y < float(bx[1]) or at.z < float(bx[2]) or at.x > float(bx[3]) or at.y > float(bx[4]) or at.z > float(bx[5]):
				continue
		if rd.has("hue"):
			if c.s < float(rd.get("min_sat", 0.4)):
				continue
			var dh: float = absf(wrapf(c.h * 360.0 - float(rd.get("hue", 0.0)), -180.0, 180.0))
			if dh > float(rd.get("width", 20.0)):
				continue
		return rd
	return {}


## A cutscene stage (CinemaSet, its own World3D) built over `host`: the stage's environment gets `grade_id`'s look.
static func apply_stage(stage: Node, grade_id: String) -> Dictionary:
	if stage == null or disabled() or not has(grade_id):
		return {}
	var we: WorldEnvironment = find_env(stage)
	if we == null or we.environment == null:
		return {}
	return apply(we.environment, grade_id)


## Which grade a cutscene cut takes: `cinema_reel` for the archive-reel history scenes (its file's `cuts` list),
## else the host map's own, else `menu` (the theatre, the prologue over the main menu).
static func cinema_id(host: Node, cut_id: String) -> String:
	# The new 3D treatment is consistent in the theatre and in a live campaign.
	# Explicit archive replays still use their historical film presentation.
	if CinemaArchive.plays_as_reel(cut_id):
		return "cinema_reel"
	if CinemaLibrary.has_cut(CinemaArchive.base_id(cut_id)):
		return "cinema_horror"
	var reel: Array = data("cinema_reel").get("cuts", [])
	if reel.has(cut_id):
		return "cinema_reel"
	if host != null and host.get("map_id") != null:
		var id: String = String(host.get("map_id"))
		if has(id):
			return id
	return "menu"


static func find_env(root: Node) -> WorldEnvironment:
	if root is WorldEnvironment:
		return root as WorldEnvironment
	var direct: Node = root.get_node_or_null(^"WorldEnvironment")
	if direct is WorldEnvironment:
		return direct as WorldEnvironment
	for n: Node in root.find_children("*", "WorldEnvironment", true, false):
		return n as WorldEnvironment
	return null


## The keys of `d` written to `env`; every absent key leaves the Environment as it was. Pure apart from the
## brightness slider (GLSettings.values "brightness") and the LUT cache.
static func apply_dict(env: Environment, d: Dictionary) -> void:
	if d.has("tonemap") and TONEMAPS.has(str(d["tonemap"])):
		env.tonemap_mode = TONEMAPS[str(d["tonemap"])]
	if d.has("exposure"):
		env.tonemap_exposure = float(d["exposure"])
	if d.has("white"):
		env.tonemap_white = float(d["white"])
	var adj: Dictionary = d.get("adjust", {})
	if not adj.is_empty():
		env.adjustment_enabled = true
		if adj.has("contrast"):
			env.adjustment_contrast = float(adj["contrast"])
		if adj.has("saturation"):
			env.adjustment_saturation = float(adj["saturation"])
		if adj.has("brightness"):
			set_brightness(env, float(adj["brightness"]))
	if d.has("lut") or d.has("tint") or d.has("mono") or d.has("lift"):
		var tex: Texture = lut_for(d)
		env.adjustment_enabled = true
		env.adjustment_color_correction = tex
	var amb: Dictionary = d.get("ambient", {})
	if not amb.is_empty():
		if amb.has("color"):
			env.ambient_light_color = color(amb["color"], env.ambient_light_color)
		if amb.has("energy"):
			env.ambient_light_energy = float(amb["energy"])
			env.set_meta("gl_look_ambient_base", env.ambient_light_energy)
		if amb.has("energy_scale"):
			if not env.has_meta("gl_look_ambient_base"):
				env.set_meta("gl_look_ambient_base", env.ambient_light_energy)
			env.ambient_light_energy = float(env.get_meta("gl_look_ambient_base")) * float(amb["energy_scale"])
	var fog: Dictionary = d.get("fog", {})
	if not fog.is_empty():
		if fog.has("enabled"):
			env.fog_enabled = bool(fog["enabled"])
		if fog.has("density"):
			env.fog_density = float(fog["density"])
		if fog.has("color"):
			env.fog_light_color = color(fog["color"], env.fog_light_color)
		if fog.has("energy"):
			env.fog_light_energy = float(fog["energy"])
		if fog.has("sky_affect"):
			env.fog_sky_affect = float(fog["sky_affect"])
		if fog.has("height"):
			env.fog_height = float(fog["height"])
		if fog.has("height_density"):
			env.fog_height_density = float(fog["height_density"])
		if fog.has("aerial"):
			env.fog_aerial_perspective = float(fog["aerial"])
		if fog.has("volumetric"):
			env.volumetric_fog_density = float(fog["volumetric"])   # on / off stays the preset's (GLSettings gfx_fog)
		if fog.has("albedo"):
			env.volumetric_fog_albedo = color(fog["albedo"], env.volumetric_fog_albedo)
		if fog.has("emission"):
			env.volumetric_fog_emission = color(fog["emission"], env.volumetric_fog_emission)
		if fog.has("anisotropy"):
			env.volumetric_fog_anisotropy = float(fog["anisotropy"])
		if fog.has("length"):
			env.volumetric_fog_length = float(fog["length"])
	var sky: Dictionary = d.get("sky", {})   # T-208: a sky shader's colours (Groom Lake's dust instead of the dawn violet)
	if not sky.is_empty() and env.sky != null and env.sky.sky_material is ShaderMaterial:
		var sm: ShaderMaterial = env.sky.sky_material as ShaderMaterial
		for k: Variant in sky.keys():
			var v: Variant = sky[k]
			sm.set_shader_parameter(str(k), color(v) if (v is String or v is Array) else v)
	elif not sky.is_empty() and env.sky != null and env.sky.sky_material != null:
		set_props(env.sky.sky_material, sky)   # T-214: a ProceduralSkyMaterial's own properties (Thalbach's soot sky)
	var envp: Dictionary = d.get("env", {})   # T-214: any other Environment property by name (sdfgi_energy, ssil_intensity, ...)
	if not envp.is_empty():
		set_props(env, envp)
	var glow: Dictionary = d.get("glow", {})
	if not glow.is_empty():
		if glow.has("intensity"):
			env.glow_intensity = float(glow["intensity"])
		if glow.has("bloom"):
			env.glow_bloom = float(glow["bloom"])
		if glow.has("threshold"):
			env.glow_hdr_threshold = float(glow["threshold"])


## `props` on `obj` by property name (a "#rrggbb" string or [r, g, b] for a Color property); unknown names are skipped.
static func set_props(obj: Object, props: Dictionary) -> void:
	for k: Variant in props.keys():
		var cur: Variant = obj.get(str(k))
		if cur == null:
			continue
		var v: Variant = props[k]
		obj.set(str(k), color(v, cur) if cur is Color else v)


## The grade's brightness is the map's base brightness: the Brightness slider (T-133) scales it and the horror
## layer's darker night (T-192, gl_horror_mult) multiplies it, in whichever order they run.
static func set_brightness(env: Environment, b: float) -> void:
	var base: float = b * float(env.get_meta("gl_horror_mult", 1.0))
	env.set_meta("gl_base_brightness", base)
	var slider: float = clampf(float(GLSettings.values.get("brightness", 1.0)), 0.6, 1.5)
	env.adjustment_brightness = base * slider


# ================================================================== colours and the LUT

## "#rrggbb" / "#rrggbbaa" / [r, g, b] / a Color; `fallback` for anything else.
static func color(v: Variant, fallback: Color = Color.WHITE) -> Color:
	if v is Color:
		return v
	if v is String and Color.html_is_valid(v):
		return Color.html(v)
	if v is Array and (v as Array).size() >= 3:
		return Color(float(v[0]), float(v[1]), float(v[2]))
	return fallback


## The colour-correction texture a grade asks for: `lut` a texture path (a 3D texture, or a 2D strip for the 1D
## mode), else one generated from `tint` / `mono` / `keep` / `lift` (cached by spec); null when the spec is neutral.
static func lut_for(d: Dictionary) -> Texture:
	var lut: Variant = d.get("lut", null)
	if lut is String and lut != "" and ResourceLoader.exists(lut):
		return load(lut) as Texture
	var spec: Dictionary = lut_spec(d)
	if spec.is_empty():
		return null
	var key: String = JSON.stringify(spec)
	if not _luts.has(key):
		_luts[key] = make_lut(spec)
	return _luts[key]


## The generated LUT's spec out of a grade: {} when nothing in it would change a colour.
static func lut_spec(d: Dictionary) -> Dictionary:
	var spec: Dictionary = {}
	var tint: Dictionary = d.get("tint", {})
	if float(tint.get("amount", 0.0)) > 0.0005:
		spec["tint"] = {"shadows": color(tint.get("shadows", "#000000")).to_html(false),
			"highlights": color(tint.get("highlights", "#ffffff")).to_html(false), "amount": float(tint["amount"])}
	if float(d.get("mono", 0.0)) > 0.0005:
		spec["mono"] = float(d["mono"])
		var keep: Array = []
		for k: Variant in d.get("keep", []):
			if k is Dictionary:
				var kd: Dictionary = k
				var ke: Dictionary = {"hue": float(kd.get("hue", 0.0)), "width": float(kd.get("width", 20.0)), "amount": float(kd.get("amount", 1.0))}
				if kd.has("sat"):   # T-214: how saturated a colour must be to be kept ([from, full]; default [0.3, 0.55])
					ke["sat"] = [float(kd["sat"][0]), float(kd["sat"][1])]
				if kd.has("val"):   # T-214: how bright it must be ([from, full] display value)
					ke["val"] = [float(kd["val"][0]), float(kd["val"][1])]
				keep.append(ke)
		spec["keep"] = keep
	var sup: Array = []
	for u: Variant in d.get("suppress", []):
		if u is Dictionary:
			sup.append({"hue": float((u as Dictionary).get("hue", 0.0)), "width": float((u as Dictionary).get("width", 20.0)),
				"amount": float((u as Dictionary).get("amount", 1.0)), "max_sat": float((u as Dictionary).get("max_sat", 2.0))})
	if not sup.is_empty():
		spec["suppress"] = sup
	if absf(float(d.get("lift", 0.0))) > 0.0005:
		spec["lift"] = float(d["lift"])
	return spec


## One texel of the LUT: `c` (display-space rgb, 0..1) through the mono / keep rule, the split tone and the lift.
static func lut_color(c: Color, spec: Dictionary) -> Color:
	var out: Color = c
	var luma: float = out.r * 0.299 + out.g * 0.587 + out.b * 0.114
	if spec.has("mono"):
		# the kept hues (Nachtglas violet, blood red) keep their colour; the rest fades toward grey by `mono`
		var w: float = 0.0
		for k: Dictionary in spec.get("keep", []):
			var dh: float = absf(wrapf(out.h * 360.0 - float(k["hue"]), -180.0, 180.0))
			var half: float = maxf(0.5, float(k["width"]))
			var win: float = 1.0 - smoothstep(half * 0.6, half, dh)
			var sat: Array = k.get("sat", [0.3, 0.55])
			var vk: float = 1.0
			if k.has("val"):   # T-214: a dark violet (a floor washed by a fill light) is not the accent; the lit tube is
				vk = smoothstep(float(k["val"][0]), float(k["val"][1]), out.v)
			w = maxf(w, win * float(k["amount"]) * smoothstep(float(sat[0]), float(sat[1]), out.s) * vk)   # only a saturated violet / red is kept; moonlit salt or a bluish grey is not
		var grey: Color = Color(luma, luma, luma)
		out = out.lerp(grey, float(spec["mono"]) * (1.0 - w))
	if spec.has("suppress"):
		# T-214: hue bands greyed further whatever `mono` leaves: the pink / magenta / salmon where a warm lamp and the
		# cold moon meet on a pale wall (blue + orange light sums to pink), never a colour of the palette
		var sw: float = 0.0
		for u: Dictionary in spec["suppress"]:
			var du: float = absf(wrapf(out.h * 360.0 - float(u["hue"]), -180.0, 180.0))
			var hu: float = maxf(0.5, float(u["width"]))
			var ms: float = float(u.get("max_sat", 2.0))   # a band can spare what is past max_sat (blood red is)
			sw = maxf(sw, (1.0 - smoothstep(hu * 0.6, hu, du)) * float(u["amount"]) * smoothstep(0.04, 0.12, out.s) \
				* (1.0 - smoothstep(ms - 0.1, ms + 0.1, out.s)))
		var g2: float = out.r * 0.299 + out.g * 0.587 + out.b * 0.114
		out = out.lerp(Color(g2, g2, g2), sw)
	if spec.has("tint"):
		var t: Dictionary = spec["tint"]
		var sh: Color = Color.html(str(t["shadows"]))
		var hi: Color = Color.html(str(t["highlights"]))
		var mixc: Color = sh.lerp(hi, smoothstep(0.08, 0.75, luma))
		var tl: float = maxf(0.02, mixc.r * 0.299 + mixc.g * 0.587 + mixc.b * 0.114)
		var tinted: Color = Color(out.r * mixc.r / tl, out.g * mixc.g / tl, out.b * mixc.b / tl)   # the tint keeps the luma
		out = out.lerp(tinted, float(t["amount"]))
	if spec.has("lift"):
		var l: float = float(spec["lift"])
		out = Color(l + out.r * (1.0 - l), l + out.g * (1.0 - l), l + out.b * (1.0 - l))
	return Color(clampf(out.r, 0.0, 1.0), clampf(out.g, 0.0, 1.0), clampf(out.b, 0.0, 1.0))


## A LUT_SIZE^3 colour-correction texture of `spec` (x = red, y = green, slice = blue, as Godot samples it).
static func make_lut(spec: Dictionary, size: int = LUT_SIZE) -> ImageTexture3D:
	var slices: Array[Image] = []
	var n1: float = float(size - 1)
	for b: int in size:
		var img: Image = Image.create(size, size, false, Image.FORMAT_RGB8)
		for g: int in size:
			for r: int in size:
				img.set_pixel(r, g, lut_color(Color(float(r) / n1, float(g) / n1, float(b) / n1), spec))
		slices.append(img)
	var tex: ImageTexture3D = ImageTexture3D.new()
	tex.create(Image.FORMAT_RGB8, size, size, size, false, slices)
	return tex
