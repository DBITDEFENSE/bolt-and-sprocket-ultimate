extends Node
## UPDATE 12 section 2 (DECISIONS T-208): the material audit, one map per run (tools/look/material_audit.sh runs every
## map and files docs/look/material_audit.md). Loads the map the way a match does (solo, no bots, headless), with the
## material pass held back, waits for the map to build itself (the landscape, the props its scripts place), then:
##   1. lists every material once (LookMaterials.collect) and the outliers of each against docs/ART_BIBLE.md section 7
##      (LookMaterials.evaluate: rough_low, clean_plastic, albedo_sat, albedo_value, no_wear), using each texture's
##      real average (albedo colour, the roughness channel) read from the imported image: "before";
##   2. runs the pass (LookMaterials.apply_tree) and lists them again: "after";
##   3. writes <out>/<map_id>.json: the counts, every remaining outlier with its material, user node and texture, the
##      exempt / skipped materials by reason, and the texture fixes a re-run needs (`tex_tint`, `tex_rough`) for
##      tools/look/material_audit.py --write-fixes to merge into data/look/_materials.json.
##   godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/material_audit.tscn -- --map=<id> --out=<dir>

const WAIT_S: float = 2.5

var _map: Node = null
var _map_id: String = "map00_crossroads"
var _out: String = "user://material_audit"
var _t: float = 0.0
var _done: bool = false
var _tex_avg: Dictionary = {}      # path -> Color (display rgb average)
var _rough_avg: Dictionary = {}    # path -> float (the roughness channel's average)


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--map="):
			_map_id = a.substr(6)
		elif a.begins_with("--out="):
			_out = a.substr(6)
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i: int in AudioServer.bus_count:
		AudioServer.set_bus_mute(i, true)
	ProfileSave.path = "user://_material_audit_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_material_audit_settings.cfg"
	GLSettings.values["homage_bosses"] = false
	Campaign.reset()
	GameState.character_id = &"dutch"
	GameState.bot_count = 0
	GameState.bot_ai_mode = "off"
	GameState.god_mode = true
	LookGrade.hold_materials = true   # the "before": the map loads without the pass
	var path: String = Campaign.scene_for(StringName(_map_id))
	print("[audit] %s: %s" % [_map_id, path])
	_map = (load(path) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)


func _process(delta: float) -> void:
	if _done or _map == null or not _map.is_inside_tree():
		return
	_t += delta
	if _t < WAIT_S:
		return
	_done = true
	var report: Dictionary = audit(_map)
	DirAccess.make_dir_recursive_absolute(_out)
	var p: String = _out.path_join(_map_id + ".json")
	var f: FileAccess = FileAccess.open(p, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, " "))
		f.close()
	print("[audit] %s: %d materials (%d checked, %d exempt, %d skipped); before %s; after %s -> %s" % [_map_id,
		int(report["materials"]), int(report["checked"]), int(report["exempt"]), int(report["skipped"]),
		JSON.stringify(report["before"]), JSON.stringify(report["after"]), p])
	print("RESULT material_audit %s: after %d outliers" % [_map_id, int(report["after_total"])])
	get_tree().quit(0)


func audit(root: Node) -> Dictionary:
	var r: Dictionary = LookMaterials.rules()
	var entries: Array[Dictionary] = LookMaterials.collect(root, r)
	var checked: Array[Dictionary] = []
	var exempt: Dictionary = {}
	var skipped: Dictionary = {}
	for e: Dictionary in entries:
		if String(e["skip"]) != "":
			skipped[e["skip"]] = int(skipped.get(e["skip"], 0)) + 1
			continue
		var why: String = LookMaterials.exempt_reason(e["mat"])
		if why != "":
			exempt[why] = int(exempt.get(why, 0)) + 1
			continue
		_read_textures(e["mat"])
		checked.append(e)
	var before: Dictionary = _count(checked, r)
	# the texture fixes this map needs (merged into the data by material_audit.py --write-fixes)
	var fixes: Dictionary = _texture_fixes(checked, r)
	var r2: Dictionary = r.duplicate(true)
	for k: String in ["tex_tint", "tex_rough"]:
		var merged: Dictionary = (r2.get(k, {}) as Dictionary).duplicate()
		merged.merge(fixes[k], false)
		r2[k] = merged
	for e: Dictionary in checked:
		LookMaterials.fix(e["mat"], e["node"], r2)
	var after: Dictionary = _count(checked, r2)
	var remaining: Array = []
	for e: Dictionary in checked:
		var ev: Dictionary = LookMaterials.evaluate(e["mat"], e["node"], _tex_avg, _rough_avg, r2)
		if not (ev["issues"] as Array).is_empty():
			remaining.append(_describe(e, ev))
	var bt: int = 0
	var at: int = 0
	for k: String in LookMaterials.ISSUES:
		bt += int(before.get(k, 0))
		at += int(after.get(k, 0))
	return {"map": _map_id, "materials": entries.size(), "checked": checked.size(), "exempt": _sum(exempt),
		"skipped": _sum(skipped), "exempt_by": exempt, "skipped_by": skipped, "before": before, "after": after,
		"before_total": bt, "after_total": at, "remaining": remaining, "fixes": fixes}


static func _sum(d: Dictionary) -> int:
	var n: int = 0
	for v: Variant in d.values():
		n += int(v)
	return n


func _count(checked: Array[Dictionary], r: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: String in LookMaterials.ISSUES:
		out[k] = 0
	for e: Dictionary in checked:
		var ev: Dictionary = LookMaterials.evaluate(e["mat"], e["node"], _tex_avg, _rough_avg, r)
		for i: Variant in ev["issues"]:
			out[str(i)] = int(out.get(str(i), 0)) + 1
	return out


func _describe(e: Dictionary, ev: Dictionary) -> Dictionary:
	var m: Material = e["mat"]
	var n: Node = e["node"]
	var tex: String = ""
	if m is BaseMaterial3D and (m as BaseMaterial3D).albedo_texture != null:
		tex = LookMaterials.tex_key((m as BaseMaterial3D).albedo_texture)
	elif m is ShaderMaterial and (m as ShaderMaterial).get_shader_parameter("albedo_tex") is Texture2D:
		tex = LookMaterials.tex_key((m as ShaderMaterial).get_shader_parameter("albedo_tex"))
	var alb: Color = ev.get("albedo", Color.WHITE)
	return {"issues": ev["issues"], "class": m.get_class(), "name": m.resource_name, "path": m.resource_path,
		"node": str(n.get_path()) if n != null and n.is_inside_tree() else (String(n.name) if n != null else ""),
		"albedo": alb.to_html(false), "sat": snappedf(alb.s, 0.01), "val": snappedf(alb.v, 0.01),
		"roughness": snappedf(float(m.get("roughness")), 0.01) if m is BaseMaterial3D else -1.0, "texture": tex,
		"vertex_color": bool(m.get("vertex_color_use_as_albedo")) if m is BaseMaterial3D else false}


# ================================================================== the textures' averages

func _read_textures(m: Material) -> void:
	if m is BaseMaterial3D:
		var b: BaseMaterial3D = m
		if b.albedo_texture != null:
			_avg_color(b.albedo_texture)
		if b.roughness_texture != null:
			_avg_channel(b.roughness_texture, int(b.roughness_texture_channel))
	elif m is ShaderMaterial:
		var t: Texture2D = LookMaterials.albedo_texture(m)
		if t != null:
			_avg_color(t)


func _avg_color(t: Texture2D) -> void:
	var p: String = LookMaterials.tex_key(t)
	if _tex_avg.has(p):
		return
	var a: Color = LookMaterials.texture_average(t)
	if a.r >= 0.0:
		_tex_avg[p] = a


func _avg_channel(t: Texture2D, ch: int) -> void:
	var p: String = LookMaterials.tex_key(t)
	if _rough_avg.has(p):
		return
	var img: Image = LookMaterials.small_image(t)
	if img == null:
		return
	var s: float = 0.0
	for y: int in img.get_height():
		for x: int in img.get_width():
			var c: Color = img.get_pixel(x, y)
			match ch:
				BaseMaterial3D.TEXTURE_CHANNEL_RED: s += c.r
				BaseMaterial3D.TEXTURE_CHANNEL_GREEN: s += c.g
				BaseMaterial3D.TEXTURE_CHANNEL_BLUE: s += c.b
				BaseMaterial3D.TEXTURE_CHANNEL_ALPHA: s += c.a
				_: s += (c.r + c.g + c.b) / 3.0
	_rough_avg[p] = s / float(img.get_width() * img.get_height())


## tex_tint: an albedo texture whose average is too saturated or too bright gets the multiply that brings its average
## to the palette (saturation sat_max, value val_max), never brighter; tex_rough: a roughness texture that averages
## under the floor gets the scalar that lifts its average to it.
func _texture_fixes(checked: Array[Dictionary], r: Dictionary) -> Dictionary:
	var tint: Dictionary = {}
	var rough: Dictionary = {}
	var smax: float = float(r.get("sat_max", 0.3))
	var vmax: float = float(r.get("val_max", 0.9))
	for e: Dictionary in checked:
		var m: Material = e["mat"]
		var words: String = LookMaterials.words_of(m, e["node"])
		var atex: Texture2D = LookMaterials.albedo_texture(m)
		if atex != null and _tex_avg.has(LookMaterials.tex_key(atex)):
			var p: String = LookMaterials.tint_key(m)
			var eff: Color = LookMaterials.effective_albedo(m, _tex_avg)
			var accent: bool = LookMaterials.is_accent(eff, r) and LookMaterials.has_word(words, r.get("accent_words", []))
			smax = LookMaterials.sat_cap(eff, accent, r)
			if not accent and (eff.s > smax + 0.005 or eff.v > vmax + 0.005) and not tint.has(p) and not p.begins_with("id:"):
				var k: Color = LookMaterials.tint_for(eff, r)
				tint[p] = [k.r, k.g, k.b]
		if not (m is BaseMaterial3D):
			continue
		var b: BaseMaterial3D = m
		if b.roughness_texture != null and _rough_avg.has(LookMaterials.tex_key(b.roughness_texture)) 				and not LookMaterials.has_word(words, r.get("low_rough_words", [])):
			var rp: String = LookMaterials.tex_key(b.roughness_texture)
			var floor_: float = float(r.get("rough_floor_metal", 0.35)) if b.metallic >= float(r.get("metal_threshold", 0.5)) else float(r.get("rough_floor", 0.45))
			var avg: float = float(_rough_avg[rp])
			if avg * b.roughness < floor_ - 0.001 and not rp.begins_with("id:"):
				rough[rp] = maxf(float(rough.get(rp, 0.0)), snappedf(minf(1.0, floor_ / maxf(avg, 0.05) + 0.005), 0.001))
	return {"tex_tint": tint, "tex_rough": rough}
