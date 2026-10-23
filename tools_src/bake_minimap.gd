extends Node
## Bakes the map data of playable levels (Update 04 section 1, DECISIONS T-065): data/maps/<map_id>/mapdata.json
## plus one stylised top-down PNG per floor.
##
## Per level: the scene is read for POIs, zones, stairs and lifts (MapScan; GRAVELIGHT scenes are instantiated
## but never enter the tree, B&S planets are built for real so their runtime geometry exists), then every visible
## mesh is copied into a private SubViewport world with the map_encode override and rendered from straight above
## with an orthographic camera, once per floor: the camera sits at the floor's cut height, so walls are sliced
## there and read as solid, ceilings and roofs above are left out, and the far plane stops just under the floor's
## band. A second pass (map_style.gdshader) turns that G-buffer into the floor image in the map's style (ink /
## holo / blueprint), clipped to the floor's XZ rects.
##
## Rendering needs the GPU, so run it in an off-screen, silent window (tools/bake_minimap.sh):
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . res://tools_src/bake_minimap.tscn -- --map=all
##   --map=<id>[,<id>...] | all     (MapCatalog ids)
## Prints "[bake_minimap] RESULT PASS <n> maps" (or FAIL with the reasons). Never captures the mouse.

const ENCODE: String = "res://ui/map/shaders/map_encode.gdshader"
const STYLE: String = "res://ui/map/shaders/map_style.gdshader"
const STYLE_IDS: Dictionary = {"ink": 0, "holo": 1, "blueprint": 2}
const SKIP_CLASSES: Array[String] = ["Label3D", "Sprite3D", "AnimatedSprite3D", "GPUParticles3D", "CPUParticles3D"]

var _maps: PackedStringArray = []
var _fails: PackedStringArray = []
var _baked: int = 0
var _enc_shader: Shader
var _enc_cache: Dictionary = {}   # source material instance id (or 0) -> ShaderMaterial
var _discard: ShaderMaterial
var _geo_y: Vector2 = Vector2(INF, -INF)
var _boxes: Array[Dictionary] = []   # wall colliders: {xf, size, lo, hi}
var _caps: Array[Node] = []
var _cap_mat: ShaderMaterial = null   # lowest / highest copied mesh inside the world rect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--map="):
			_maps = a.substr(6).split(",", false)
		elif a == "--list":   # tools/bake_minimap.sh all: the playable levels, one line
			print("[bake_minimap] ids ", ",".join(MapCatalog.ids().map(func(i: StringName) -> String: return String(i))))
			get_tree().quit.call_deferred(0)
			set_process(false)
			return
	if _maps.is_empty() or _maps[0] == "all":
		_maps = PackedStringArray()
		for id: StringName in MapCatalog.ids():
			_maps.append(String(id))
	for i: int in AudioServer.bus_count:
		AudioServer.set_bus_mute(i, true)
	_enc_shader = load(ENCODE) as Shader
	_discard = ShaderMaterial.new()
	var ds: Shader = Shader.new()
	ds.code = "shader_type spatial;\nrender_mode unshaded;\nvoid fragment() { discard; }\n"
	_discard.shader = ds
	_run.call_deferred()


func _process(_d: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # never hold the user's mouse (B&S levels try to capture it)


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("[bake_minimap] RESULT FAIL the bake renders: run it with a window (tools/bake_minimap.sh), not --headless")
		get_tree().quit(1)
		return
	for id: String in _maps:
		var row: Dictionary = MapCatalog.level(StringName(id))
		if row.is_empty():
			_fails.append("%s is not a playable level (MapCatalog)" % id)
			continue
		await _bake(row)
	if _fails.is_empty():
		print("[bake_minimap] RESULT PASS %d maps" % _baked)
	else:
		print("[bake_minimap] RESULT FAIL %s" % "; ".join(_fails))
	get_tree().quit(0 if _fails.is_empty() else 1)


func _bake(row: Dictionary) -> void:
	var t0: int = Time.get_ticks_msec()
	var map_id: StringName = row["map_id"]
	var game: String = str(row["game"])
	print("[bake_minimap] -- %s (%s)" % [map_id, row["scene"]])
	var root: Node = null
	var scan: Dictionary
	if game == "bs":
		var ps: PackedScene = load(str(row["scene"])) as PackedScene
		root = ps.instantiate()
		root.set("play_arrival", false)
		add_child(root)
		await _frames(6)
		scan = MapBake.scan_level(row)
	else:
		scan = MapBake.scan_level(row, true)
		if scan.has("error"):
			_fails.append(str(scan["error"]))
			return
		root = scan["root"]
	var md: MapData = MapBake.build(row, scan)
	var cfg: Dictionary = MapBake.config_for(map_id, game)
	var excl: Array = cfg.get("exclude", [])
	# the bake world: copies of every visible mesh with the encoder override
	_enc_cache.clear()
	_boxes.clear()
	_caps.clear()
	_cap_mat = null
	var sv: SubViewport = SubViewport.new()
	sv.own_world_3d = true
	sv.size = md.image_size
	sv.transparent_bg = true
	sv.msaa_3d = Viewport.MSAA_DISABLED
	sv.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	sv.scaling_3d_scale = 1.0
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)
	var we: WorldEnvironment = WorldEnvironment.new()
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	we.environment = env
	sv.add_child(we)
	_geo_y = Vector2(INF, -INF)
	var copied: int = _copy_geometry(root, root, sv, excl, md.world_rect)
	var geo_y: Vector2 = _geo_y
	var cam: Camera3D = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = md.world_rect.size.y
	var c2: Vector2 = md.world_rect.get_center()
	cam.basis = Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))   # looking down -Y, north (-Z) up
	sv.add_child(cam)
	cam.current = true
	await _frames(24)   # procedural noise textures finish generating
	var dir: String = MapData.dir_for(map_id)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var style_cfg: Dictionary = cfg.get("style_cfg", {})
	for f: Dictionary in md.floors:
		var y_lo: float = maxf(float(f["y_min"]) - float(f["depth"]), geo_y.x - 0.5)
		var y_hi: float = minf(float(f["cut"]), geo_y.y + 0.5)
		if y_hi <= y_lo + 0.1:
			y_hi = y_lo + 0.1
		for m: Variant in _enc_cache.values():
			(m as ShaderMaterial).set_shader_parameter("y_lo", y_lo)
			(m as ShaderMaterial).set_shader_parameter("y_hi", y_hi)
		var caps: int = _place_caps(sv, y_hi)
		cam.position = Vector3(c2.x, y_hi, c2.y)
		cam.near = 0.01
		cam.far = maxf(0.05, y_hi - y_lo)
		await _frames(3)
		await RenderingServer.frame_post_draw
		var gbuf: Image = sv.get_texture().get_image()
		var img: Image = await _stylize(gbuf, md, f, _mask_rects(f, scan), str(md.style), style_cfg, y_hi - y_lo)
		var out_path: String = dir.path_join(str(f["image"]))
		var err: int = img.save_png(ProjectSettings.globalize_path(out_path))
		if err != OK:
			_fails.append("%s: could not write %s" % [map_id, out_path])
		print("[bake_minimap]    floor %d %s: band %.2f..%.2f, %d wall caps -> %s (%dx%d)" % [int(f["index"]), f["id"], y_lo, y_hi, caps, out_path, img.get_width(), img.get_height()])
	md.baked_at = Time.get_datetime_string_from_system()
	var fa: FileAccess = FileAccess.open(ProjectSettings.globalize_path(MapData.path_for(map_id)), FileAccess.WRITE)
	if fa == null:
		_fails.append("%s: could not write mapdata.json" % map_id)
	else:
		fa.store_string(JSON.stringify(md.to_dict(), "  ", false))
		fa.close()
	MapData.clear_cache()
	sv.queue_free()
	if root.is_inside_tree():
		root.queue_free()
	else:
		root.free()
	await _frames(4)
	_baked += 1
	print("[bake_minimap]    %s: %d meshes, %d floors, %d zones, %d POIs, %d connectors, rect %s, %.1fs" % [map_id, copied,
		md.floors.size(), md.zones.size(), md.pois.size(), md.connectors.size(), md.world_rect, (Time.get_ticks_msec() - t0) / 1000.0])


## Copies every drawable mesh under `n` into the bake viewport (counts them; widens _geo_y to the meshes' heights
## inside the world rect).
func _copy_geometry(root: Node, n: Node, sv: SubViewport, excl: Array, rect: Rect2) -> int:
	if n is CanvasItem or n is CanvasLayer or n is SubViewport:
		return 0
	if n != root and _excluded(String(n.name), excl):
		return 0
	if n is Node3D and not (n as Node3D).visible:
		return 0
	var count: int = 0
	if n is GeometryInstance3D and not SKIP_CLASSES.has(n.get_class()):
		var gi: GeometryInstance3D = n as GeometryInstance3D
		var xf: Transform3D = MapScan.global_xform(n)
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			var src: MeshInstance3D = n as MeshInstance3D
			var ab: AABB = xf * src.mesh.get_aabb()
			if _overlaps(ab, rect):
				var mi: MeshInstance3D = MeshInstance3D.new()
				mi.mesh = src.mesh
				mi.transform = xf
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				for s: int in src.mesh.get_surface_count():
					mi.set_surface_override_material(s, _enc_for(_surface_mat(src, s)))
				sv.add_child(mi)
				_geo_y.x = minf(_geo_y.x, ab.position.y)
				_geo_y.y = maxf(_geo_y.y, ab.end.y)
				count += 1
		elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh != null and (n as MultiMeshInstance3D).multimesh.mesh != null:
			var mm: MultiMeshInstance3D = n as MultiMeshInstance3D
			var ab2: AABB = xf * mm.multimesh.get_aabb()
			if _overlaps(ab2, rect):
				var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
				mmi.multimesh = mm.multimesh
				mmi.transform = xf
				var m0: Material = gi.material_override if gi.material_override != null else mm.multimesh.mesh.surface_get_material(0)
				mmi.material_override = _enc_for(m0)
				sv.add_child(mmi)
				count += 1
	if n is CollisionShape3D and n.get_parent() is StaticBody3D and not (n as CollisionShape3D).disabled:
		count += _copy_collider(n as CollisionShape3D, sv, rect)
	for c: Node in n.get_children():
		count += _copy_geometry(root, c, sv, excl, rect)
	return count


## Upright box colliders taller than a metre are remembered as walls: per floor, every one the cut passes through
## gets a flat "section cap" just under the cut (_place_caps), so a wall cut by the slice always reads as solid,
## whatever the art meshes look like inside (open shells, floors running under the walls).
func _copy_collider(cs: CollisionShape3D, _sv: SubViewport, rect: Rect2) -> int:
	var box: BoxShape3D = cs.shape as BoxShape3D
	if box == null or box.size.y < 1.0:
		return 0
	var xf: Transform3D = MapScan.global_xform(cs)
	if absf(xf.basis.y.normalized().y) < 0.98:
		return 0
	var ab: AABB = xf * AABB(-box.size * 0.5, box.size)
	if not _overlaps(ab, rect):
		return 0
	_boxes.append({"xf": xf, "size": box.size, "lo": ab.position.y, "hi": ab.end.y})
	return 0


func _place_caps(sv: SubViewport, cut: float) -> int:
	for c: Node in _caps:
		c.queue_free()
	_caps.clear()
	if _cap_mat == null:
		_cap_mat = ShaderMaterial.new()
		_cap_mat.shader = _enc_shader
		_cap_mat.set_shader_parameter("force_wall", true)
		_enc_cache[-1] = _cap_mat
	for b: Dictionary in _boxes:
		if float(b["lo"]) >= cut - 0.05 or float(b["hi"]) <= cut + 0.05:
			continue
		var xf: Transform3D = b["xf"]
		var sz: Vector3 = b["size"]
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(sz.x, 0.01, sz.z)
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = bm
		mi.transform = Transform3D(xf.basis.orthonormalized(), Vector3(xf.origin.x, cut - 0.03, xf.origin.z))
		mi.material_override = _cap_mat
		sv.add_child(mi)
		_caps.append(mi)
	return _caps.size()


static func _overlaps(ab: AABB, rect: Rect2) -> bool:
	return Rect2(ab.position.x, ab.position.z, ab.size.x, ab.size.z).grow(0.5).intersects(rect)


static func _excluded(node_name: String, excl: Array) -> bool:
	for e: Variant in excl:
		if node_name.contains(str(e)):
			return true
	return false


static func _surface_mat(mi: MeshInstance3D, s: int) -> Material:
	if mi.material_override != null:
		return mi.material_override
	var o: Material = mi.get_surface_override_material(s)
	if o != null:
		return o
	return mi.mesh.surface_get_material(s)


## The encoder material for a source material (cached): its albedo colour, texture and UV / triplanar mapping;
## see-through materials (glass, glow cards, water) are not drawn at all.
func _enc_for(src: Material) -> Material:
	var key: int = src.get_instance_id() if src != null else 0
	if _enc_cache.has(key):
		return _enc_cache[key]
	if _see_through(src):
		_enc_cache[key] = _discard
		return _discard
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = _enc_shader
	var col: Color = Color(0.7, 0.7, 0.7)
	var tex: Texture2D = null
	var tri: bool = false
	var scale: Vector3 = Vector3.ONE
	var offset: Vector3 = Vector3.ZERO
	if src is BaseMaterial3D:
		var bm: BaseMaterial3D = src as BaseMaterial3D
		col = bm.albedo_color
		tex = bm.albedo_texture
		tri = bm.uv1_triplanar
		scale = bm.uv1_scale
		offset = bm.uv1_offset
	elif src is ShaderMaterial:
		var sm: ShaderMaterial = src as ShaderMaterial
		for p: String in ["albedo", "albedo_color", "base_color", "color", "tint"]:
			var v: Variant = sm.get_shader_parameter(p)
			if v is Color:
				col = v
				break
		for p2: String in ["albedo_texture", "texture_albedo", "albedo_tex", "tex", "texture"]:
			var t: Variant = sm.get_shader_parameter(p2)
			if t is Texture2D:
				tex = t
				break
	m.set_shader_parameter("albedo", col)
	if tex != null:
		m.set_shader_parameter("albedo_tex", tex)
	m.set_shader_parameter("triplanar", tri)
	m.set_shader_parameter("uv_scale", scale)
	m.set_shader_parameter("uv_offset", offset)
	_enc_cache[key] = m
	return m


static func _see_through(src: Material) -> bool:
	if src is BaseMaterial3D:
		var bm: BaseMaterial3D = src as BaseMaterial3D
		return bm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED and bm.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR \
			or bm.blend_mode == BaseMaterial3D.BLEND_MODE_ADD
	if src is ShaderMaterial and (src as ShaderMaterial).shader != null:
		var code: String = (src as ShaderMaterial).shader.code
		return code.contains("blend_add") or (code.contains("ALPHA =") and not code.contains("ALPHA_SCISSOR"))
	return false


## What the floor image keeps: the floor's own rects, or (when the config gives "mask_zones") the boxes of those
## zones grown by "mask_grow" metres; [] = everything.
static func _mask_rects(f: Dictionary, scan: Dictionary) -> Array:
	var mz: Array = f.get("mask_zones", [])
	if mz.is_empty():
		return f.get("rects", [])
	var grow: float = float(f.get("mask_grow", 0.0))
	var out: Array = []
	for b: Dictionary in scan.get("zone_boxes", []):
		if mz.has(str(b["id"])):
			var ab: AABB = b["aabb"]
			out.append(Rect2(ab.position.x, ab.position.z, ab.size.x, ab.size.z).grow(grow))
	return out


## Pass 2: the style shader over the G-buffer, clipped to the floor's rects.
func _stylize(gbuf: Image, md: MapData, f: Dictionary, rects: Array, style: String, sc: Dictionary, band_m: float) -> Image:
	var w: int = gbuf.get_width()
	var h: int = gbuf.get_height()
	var mask: Image = Image.create(w, h, false, Image.FORMAT_L8)
	if rects.is_empty():
		mask.fill(Color.WHITE)
	else:
		mask.fill(Color.BLACK)
		for r: Rect2 in rects:
			var a: Vector2 = md.world_to_pixel(Vector3(r.position.x, 0, r.position.y))
			var b: Vector2 = md.world_to_pixel(Vector3(r.end.x, 0, r.end.y))
			var ir: Rect2i = Rect2i(Vector2i(floori(a.x) - 2, floori(a.y) - 2), Vector2i(ceili(b.x - a.x) + 4, ceili(b.y - a.y) + 4))
			mask.fill_rect(ir.intersection(Rect2i(0, 0, w, h)), Color.WHITE)
	var sv: SubViewport = SubViewport.new()
	sv.size = Vector2i(w, h)
	sv.transparent_bg = true
	sv.disable_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)
	var tr: TextureRect = TextureRect.new()
	tr.texture = ImageTexture.create_from_image(gbuf)
	tr.size = Vector2(w, h)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = load(STYLE) as Shader
	mat.set_shader_parameter("gbuf", tr.texture)
	mat.set_shader_parameter("mask_tex", ImageTexture.create_from_image(mask))
	mat.set_shader_parameter("texel", Vector2(1.0 / w, 1.0 / h))
	mat.set_shader_parameter("style", int(STYLE_IDS.get(style, 0)))
	for k: String in ["paper", "paper_dark", "ink", "accent"]:
		if sc.has(k):
			mat.set_shader_parameter(k, Color(str(sc[k])))
	if sc.has("wall"):
		mat.set_shader_parameter("wall_col", Color(str(sc["wall"])))
	var r2: Rect2 = md.world_rect
	mat.set_shader_parameter("world_rect", Vector4(r2.position.x, r2.position.y, r2.size.x, r2.size.y))
	mat.set_shader_parameter("hscale", band_m)
	mat.set_shader_parameter("ppm", md.px_per_m)
	mat.set_shader_parameter("seed", float(int(f["index"]) * 0.137))
	tr.material = mat
	sv.add_child(tr)
	await _frames(3)
	await RenderingServer.frame_post_draw
	var out: Image = sv.get_texture().get_image()
	sv.queue_free()
	return out
