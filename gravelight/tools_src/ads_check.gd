extends Node3D
## ADS alignment check (Update 02 §2, T-047). Loads every weapon (base + upgraded), aims it fully, and for each:
##   1. measures where its SightPoint (rear sight) and FrontSight (front post / bead) markers land on screen,
##      both through the real camera (unproject of the drawn pose) and through the pure ADS math
##      (WeaponHolder.sight_marks_camera), as a pixel offset from the screen center;
##   2. renders the frame with a center-dot overlay and saves <out>/<weapon>.png.
## Prints a PASS/FAIL table; the exit code is the number of failures. Run it after any weapon change:
##   tools/ads_check.sh                       (renders; off-screen, silent)
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . \
##       res://gravelight/tools_src/ads_check.tscn -- [--out=<dir>] [--only=thompson,mp40_up] [--tol=1.5]
##   godot --headless ... -- --no-shots     (numbers only)
## Attachments (UPDATE_04 section 6, T-068 / T-074): every sights x stock combination of the M1911 and Last Rites,
## and every other gun's sights options (a scope moves SightPoint / FrontSight to its eyepiece / objective) alone
## and with each grip part that goes on the model, are checked too (WeaponKit.sight_stock_builds; --no-kits skips
## them; --kits-only checks only them). An id may be a build string, "m1911_up:sights=raised_target,grip=stock";
## its image is <out>/m1911_up__sights-raised_target_grip-stock.png. Headless (--headless, no shots) the check is
## the pure ADS math through the real viewmodel rig: it needs no GPU.
## The viewmodel is posed with WeaponHolder.steady (no sway / bob / breathing / kick), so the check is exact.
## Uses a Player that is never added to the tree, so the mouse is untouched.

const W: int = 1280
const H: int = 720
const BASE_FOV: float = 80.0

var _ids: PackedStringArray = []
var _out: String = "res://morning/screenshots/ads"
var _tol: float = 1.5
var _shots: bool = true
var _cam: Camera3D
var _holder: WeaponHolder
var _fake: Player
var _overlay: Control
var _scope: Control
var _label: Label
var _i: int = -1
var _wait: float = 0.0
var _busy: bool = false
var _fails: int = 0
var _rows: Array[String] = []
var _kits: bool = true
var _kits_only: bool = false
## T-128 --picture: the sight picture per gun (gun geometry around the aim point; see _sight_picture).
var _picture: bool = false
var _pic_rows: Array[String] = []
## --ascii: also print an 81 x 41 character map of the 160 x 80 px round the aim point (2 px a column, 2 px a row),
## each covered cell the first letter of the mesh covering it, the aim point '+', the empty '.'.
var _ascii: bool = false
## --fit=dx,dy[,front]: a fitting aid (T-128). Moves the gun's SightPoint (or FrontSight with ",front") by the
## rig-space step that brings the screen point (dx, dy) px from the aim point (+x right, +y down, 1280x720, as the
## ascii map reads) onto the aim point, re-aims, and prints the marker's new rig-space position for model_fit.json
## (sight_rear / sight_front) and how many metres a pixel is at that marker's depth.
var _fit: Vector2 = Vector2.INF
var _fit_front: bool = false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--only="):
			_ids = PackedStringArray(a.substr(7).split(","))
		elif a.begins_with("--tol="):
			_tol = float(a.substr(6))
		elif a == "--no-shots":
			_shots = false
		elif a == "--no-kits":
			_kits = false
		elif a == "--kits-only":
			_kits_only = true
		elif a == "--picture":
			_picture = true
		elif a == "--ascii":
			_picture = true
			_ascii = true
		elif a.begins_with("--fit="):
			var fp: PackedStringArray = a.substr(6).split(",")
			_fit = Vector2(float(fp[0]), float(fp[1]))
			_fit_front = fp.size() > 2 and fp[2] == "front"
	if DisplayServer.get_name() == "headless":
		_shots = false
	if _ids.is_empty():
		_ids = all_weapon_ids() if not _kits_only else PackedStringArray()
		if _kits or _kits_only:
			_ids.append_array(WeaponKit.sight_stock_builds())
	if _out.begins_with("res://") or _out.begins_with("user://"):
		_out = ProjectSettings.globalize_path(_out)
	if _shots:
		DirAccess.make_dir_recursive_absolute(_out)
	_build_range()
	_cam = Camera3D.new()
	_cam.fov = BASE_FOV
	_cam.near = 0.01        # same as the player camera (the viewmodel is compressed toward the eye, D-062)
	_cam.far = 200.0
	add_child(_cam)
	_cam.make_current()
	_fake = Player.new()
	_fake.camera = _cam
	_holder = WeaponHolder.new()
	_cam.add_child(_holder)
	_holder.setup(_fake)
	_holder.steady = true
	_build_overlay()
	print("[ads_check] %d weapons, tolerance %.1f px at %dx%d, shots %s -> %s" % [_ids.size(), _tol, W, H, _shots, _out])
	print("[ads_check] %-18s %8s %8s %8s %8s  %s" % ["weapon", "rear_x", "rear_y", "front_x", "front_y", "result"])
	_next()


## Every gun id the game can hand you: the weapons table, then the upgraded table.
static func all_weapon_ids() -> PackedStringArray:
	var out: PackedStringArray = []
	var t: Dictionary = GLData.table("weapons")
	for k: Variant in (t["weapons"] as Dictionary).keys():
		out.append(str(k))
	for k2: Variant in (t.get("upgraded", {}) as Dictionary).keys():
		out.append(str(k2))
	return out


func _build_range() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.42, 0.45, 0.5)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.62, 0.66)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 25, 0)
	sun.light_energy = 1.1
	add_child(sun)
	# a pale backstop with a target board 12 m out, so the sight picture reads against something
	var wall: MeshInstance3D = MeshInstance3D.new()
	var wm: PlaneMesh = PlaneMesh.new()
	wm.size = Vector2(30, 14)
	wall.mesh = wm
	wall.rotation_degrees = Vector3(90, 0, 0)
	wall.position = Vector3(0, 0, -12.5)
	var wmat: StandardMaterial3D = StandardMaterial3D.new()
	wmat.albedo_color = Color(0.66, 0.6, 0.5)
	wall.material_override = wmat
	add_child(wall)
	for r: Array in [[0.6, Color(0.92, 0.9, 0.84)], [0.4, Color(0.15, 0.15, 0.15)], [0.2, Color(0.92, 0.9, 0.84)]]:
		var disc: MeshInstance3D = MeshInstance3D.new()
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = float(r[0])
		cm.bottom_radius = float(r[0])
		cm.height = 0.01
		disc.mesh = cm
		disc.rotation_degrees = Vector3(90, 0, 0)
		disc.position = Vector3(0, 0, -12.45 + (0.6 - float(r[0])) * 0.05)
		var dm: StandardMaterial3D = StandardMaterial3D.new()
		dm.albedo_color = r[1]
		disc.material_override = dm
		add_child(disc)
	var floor_mi: MeshInstance3D = MeshInstance3D.new()
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(40, 40)
	floor_mi.mesh = pm
	floor_mi.position = Vector3(0, -1.6, -8)
	var fmat: StandardMaterial3D = StandardMaterial3D.new()
	fmat.albedo_color = Color(0.35, 0.33, 0.3)
	floor_mi.material_override = fmat
	add_child(floor_mi)


func _build_overlay() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	_scope = Hud.ScopeOverlay.new()
	_scope.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scope.visible = false
	layer.add_child(_scope)
	_overlay = CenterDot.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_overlay)
	_label = Label.new()
	_label.position = Vector2(12, 8)
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 5)
	layer.add_child(_label)


func _next() -> void:
	_i += 1
	if _i >= _ids.size():
		_finish()
		return
	var id: StringName = StringName(_ids[_i])
	_holder.slots.clear()
	if String(id).contains(":"):
		_holder.slots = [WeaponKit.from_build(String(id))]   # a gun with attachments
		_holder.current_index = 0
	else:
		_holder.give_weapon(id)
		_holder.current_index = _holder.slots.find(_holder.find_weapon(id))
	_holder.call("_rebuild_gun")
	_holder.set("_swap_t", 0.0)
	_holder.ads_t = 0.0
	_wait = 0.25 + maxf(0.05, _holder.current().f("ads_time", 0.25)) * 1.6
	if not _shots:
		_wait = 0.0
		_holder.ads_t = 1.0


func _process(delta: float) -> void:
	if _busy or _i >= _ids.size():
		return
	_holder.tick(delta, {"ads": true})
	_cam.fov = BASE_FOV * _holder.fov_mult()
	_scope.visible = _holder.scoped()
	_wait -= delta
	if _wait > 0.0 or _holder.ads_t < 1.0:
		return
	_measure_and_shoot()


## Pixel offsets (+x right, +y down) of [rear, front] from the screen center, through the camera.
func _rendered_offsets() -> Array:
	var c: Vector2 = Vector2(W, H) * 0.5
	var marks: Array = _holder.sight_marks_camera(true)
	var out: Array = []
	for p: Vector3 in marks:
		var g: Vector3 = _holder.global_transform * p
		if _cam.is_inside_tree() and DisplayServer.get_name() != "headless":
			# the viewport may not be exactly W x H: scale to the reference resolution
			var vs: Vector2 = get_viewport().get_visible_rect().size
			out.append((_cam.unproject_position(g) - vs * 0.5) * (float(H) / vs.y))
		else:
			out.append(WeaponHolder.project_offset_px(p, _cam.fov, H))
	return out


func _measure_and_shoot() -> void:
	var id: String = _ids[_i]
	var live: Array = _rendered_offsets()
	var pure: Array = []
	for p: Vector3 in _holder.sight_marks_camera(false):
		pure.append(WeaponHolder.project_offset_px(p, _cam.fov, H))
	var worst: float = 0.0
	for v: Vector2 in live + pure:
		worst = maxf(worst, v.length())
	var ok: bool = worst <= _tol
	if not ok:
		_fails += 1
	var rear: Vector2 = live[0]
	var front: Vector2 = live[1]
	var row: String = "%-18s %8.2f %8.2f %8.2f %8.2f  %s" % [id, rear.x, rear.y, front.x, front.y, "PASS" if ok else "FAIL (%.2f px)" % worst]
	_rows.append(row)
	print("[ads_check] " + row)
	if _fit.is_finite():
		_apply_fit()
	if _picture:
		var pic: Dictionary = _sight_picture()
		var prow: String = "%-34s disc %4.0f%%  above %4.0f%%  over_post %4.0f%%  post gap %4.0f h %4.0f w %5.1f px%s %s" % [id,
			100.0 * float(pic["disc"]), 100.0 * float(pic["above"]), 100.0 * float(pic["column"]), float(pic["post_gap"]), float(pic["post_h"]),
			float(pic["post_w"]), "  SCOPED" if bool(pic["scoped"]) else "", str(pic["parts_over"]) if not (pic["parts_over"] as Dictionary).is_empty() else ""]
		_pic_rows.append(prow)
		print("[sight] " + prow)
	if _shots:
		var w: WeaponInstance = _holder.current()
		_label.text = "%s  (%s)   ADS zoom %.2f  eye relief %.2f m   rear %+.1f,%+.1f px  front %+.1f,%+.1f px   %s" % [
			id, String(w.data.get("name", id)), _holder.ads_zoom(w), float((_holder.get("_model") as Node3D).get_meta("eye_relief", _holder.feel_for(w).get("eye_relief", 0.0)) if _holder.get("_model") != null else _holder.feel_for(w).get("eye_relief", 0.0)),   # T-098: a model_fit eye_relief wins, as in the holder
			rear.x, rear.y, front.x, front.y, "PASS" if ok else "FAIL"]
		_busy = true
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		if img.get_width() != W:
			img.resize(W, H)
		img.save_png(_out.path_join(WeaponKit.build_file_name(id) + ".png"))
		_busy = false
	_next()


## T-128: what the aimed gun covers on screen (pure ADS pose, 1280x720, the camera's FOV), from its triangles:
## disc: the share of a 70 px circle round the aim point the gun covers; above: the same for the circle's upper half
## (where the target is; aperture rings and post wings land here, a receiver or a hood shouldn't fill it);
## column: the share of a 6 px wide strip from 4 to 40 px straight above the aim point that is covered (anything
## sitting over the front sight's tip hides the target); post_h / post_w: the front sight's visible height and width
## under the aim point (the strip from 0 to 60 px below it, how far down it stays covered, and its width there).
func _sight_picture() -> Dictionary:
	var tris: Array[PackedVector2Array] = []
	var tri_part: PackedStringArray = []   # the mesh each triangle came from (the detail report names them)
	var model: Node3D = _holder.get("_model") as Node3D
	if model == null:
		return {"disc": 0.0, "above": 0.0, "column": 0.0, "post_h": 0.0, "post_w": 0.0}
	var rig: Node3D = _holder.get("_rig") as Node3D
	var gun: Node3D = _holder.get("_gun") as Node3D
	var ads: Vector3 = _holder.get("_ads")
	var ads_rot: Vector3 = _holder.get("_ads_rot")
	var xf: Transform3D = rig.transform * Transform3D(Basis.from_euler(ads_rot), ads) * gun.transform * model.transform
	var box: Rect2 = Rect2(-75, -75, 150, 150)
	for n: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null or not _visible_under(mi, model):
			continue
		var rel: Transform3D = Transform3D.IDENTITY
		var c: Node = mi
		while c != null and c != model:
			if c is Node3D:
				rel = (c as Node3D).transform * rel
			c = c.get_parent()
		var full: Transform3D = xf * rel
		var faces: PackedVector3Array = mi.mesh.get_faces()
		for i: int in range(0, faces.size() - 2, 3):
			var a: Vector2 = WeaponHolder.project_offset_px(full * faces[i], _cam.fov, H)
			var b: Vector2 = WeaponHolder.project_offset_px(full * faces[i + 1], _cam.fov, H)
			var d: Vector2 = WeaponHolder.project_offset_px(full * faces[i + 2], _cam.fov, H)
			if not (a.is_finite() and b.is_finite() and d.is_finite()):
				continue
			var tb: Rect2 = Rect2(a, Vector2.ZERO).expand(b).expand(d)
			if tb.intersects(box):
				tris.append(PackedVector2Array([a, b, d]))
				tri_part.append(str(model.get_path_to(mi)) if model.is_ancestor_of(mi) else str(mi.name))
	var covered: Callable = func(p: Vector2) -> bool:
		for t: PackedVector2Array in tris:
			if Geometry2D.point_is_inside_triangle(p, t[0], t[1], t[2]):
				return true
		return false
	var n_disc: int = 0
	var c_disc: int = 0
	var n_up: int = 0
	var c_up: int = 0
	for gy: int in range(-70, 71, 5):
		for gx: int in range(-70, 71, 5):
			var p: Vector2 = Vector2(gx, gy)
			if p.length() > 70.0 or p.length() < 3.0:
				continue
			var hit: bool = covered.call(p)
			n_disc += 1
			c_disc += int(hit)
			if gy < -3:
				n_up += 1
				c_up += int(hit)
	var n_col: int = 0
	var c_col: int = 0
	for gy2: int in range(-40, -3, 2):
		for gx2: int in [-3, 0, 3]:
			n_col += 1
			c_col += int(covered.call(Vector2(gx2, gy2)))
	var post_h: float = 0.0
	var post_gap: float = -1.0   # px from the aim point down to the first covered pixel under it (-1: none in 60 px)
	for gy4: int in range(0, 61):
		if covered.call(Vector2(0, gy4)):
			post_gap = float(gy4)
			break
	for gy3: int in range(maxi(1, int(post_gap)), 61):
		if post_gap < 0.0 or not covered.call(Vector2(0, gy3)):
			break
		post_h = float(gy3) - maxf(0.0, post_gap)
	var post_w: float = 0.0
	if post_h > 3.0:
		var y: float = minf(6.0, post_h)
		var l: float = 0.0
		while l < 60.0 and covered.call(Vector2(-l - 0.5, y)):
			l += 0.5
		var r: float = 0.0
		while r < 60.0 and covered.call(Vector2(r + 0.5, y)):
			r += 0.5
		post_w = l + r
	if _ascii:
		var legend: Dictionary = {}
		print("[ascii] " + _ids[_i])
		for ry: int in range(-40, 41, 2):
			var line: String = ""
			for rx: int in range(-80, 81, 2):
				var ch: String = "."
				if rx == 0 and ry == 0:
					ch = "+"
				else:
					for ti2: int in tris.size():
						var tt: PackedVector2Array = tris[ti2]
						if Geometry2D.point_is_inside_triangle(Vector2(rx, ry), tt[0], tt[1], tt[2]):
							var nm: String = tri_part[ti2]
							if not legend.has(nm):
								legend[nm] = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"[legend.size() % 26]
							ch = str(legend[nm])
							break
				line += ch
			print("[ascii] " + line)
		print("[ascii] legend " + str(legend))
	var parts_over: Dictionary = {}   # mesh -> samples it covers in the strip over the post
	for gy5: int in range(-40, -3, 2):
		for gx5: int in [-3, 0, 3]:
			for ti: int in tris.size():
				var t5: PackedVector2Array = tris[ti]
				if Geometry2D.point_is_inside_triangle(Vector2(gx5, gy5), t5[0], t5[1], t5[2]):
					parts_over[tri_part[ti]] = int(parts_over.get(tri_part[ti], 0)) + 1
					break
	return {"disc": float(c_disc) / maxf(1.0, n_disc), "above": float(c_up) / maxf(1.0, n_up), "column": float(c_col) / maxf(1.0, n_col),
		"post_h": post_h, "post_w": post_w, "post_gap": post_gap, "parts_over": parts_over, "scoped": _holder.scoped()}


func _apply_fit() -> void:
	var model: Node3D = _holder.get("_model") as Node3D
	var mk: Node3D = model.find_child("FrontSight" if _fit_front else "SightPoint", true, false) as Node3D
	var cam_pts: Array = _holder.sight_marks_camera(false)
	var depth: float = absf((cam_pts[1 if _fit_front else 0] as Vector3).z)
	var f: float = float(H) * 0.5 / tan(deg_to_rad(_cam.fov) * 0.5)
	var rig: Node3D = _holder.get("_rig") as Node3D
	var gun: Node3D = _holder.get("_gun") as Node3D
	var xf: Transform3D = rig.transform * Transform3D(Basis.from_euler(_holder.get("_ads_rot")), _holder.get("_ads")) * gun.transform * model.transform
	var d_cam: Vector3 = Vector3(_fit.x * depth / f, -_fit.y * depth / f, 0.0)
	var d_model: Vector3 = xf.basis.inverse() * d_cam
	var host: Node3D = mk.get_parent() as Node3D
	var before: Vector3 = _model_pos(model, mk)
	mk.position += (host.global_transform.basis.inverse() * model.global_transform.basis * d_model) if host != model and host.is_inside_tree() else d_model
	_holder.call("_compute_ads_pose")
	print("[fit] %s %s: %s -> %s (rig m); %.5f m per px at its depth (%.3f m from the eye, rig scale %.3f)" % [_ids[_i],
		"sight_front" if _fit_front else "sight_rear", str(before.snapped(Vector3.ONE * 0.0001)), str(_model_pos(model, mk).snapped(Vector3.ONE * 0.0001)),
		depth / f / rig.scale.x, depth, rig.scale.x])


static func _model_pos(model: Node3D, n: Node3D) -> Vector3:
	var t: Transform3D = Transform3D.IDENTITY
	var c: Node = n
	while c != null and c != model:
		if c is Node3D:
			t = (c as Node3D).transform * t
		c = c.get_parent()
	return t.origin


static func _visible_under(n: Node, top: Node) -> bool:
	var c: Node = n
	while c != null:
		if c is Node3D and not (c as Node3D).visible:
			return false
		if c == top:
			return true
		c = c.get_parent()
	return true


func _finish() -> void:
	print("[ads_check] RESULT %d/%d aligned, %d failed (tolerance %.1f px)" % [_ids.size() - _fails, _ids.size(), _fails, _tol])
	if _picture:
		var pf: FileAccess = FileAccess.open(ProjectSettings.globalize_path("res://.smoke_logs").path_join("sight_picture.txt"), FileAccess.WRITE)
		if pf != null:
			pf.store_string("\n".join(_pic_rows) + "\n")
	if _shots:
		var f: FileAccess = FileAccess.open(_out.path_join("ads_check.txt"), FileAccess.WRITE)
		if f != null:
			f.store_string("\n".join(_rows) + "\n")
	_busy = true
	_fake.free()        # never entered the tree, so nothing else frees it
	get_tree().quit(_fails)


## Screen-center dot (the aim point the sights must sit on), with short ticks well clear of it.
class CenterDot extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var col: Color = Color(1.0, 0.15, 0.1, 0.95)
		for d: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_line(c + d * 70.0, c + d * 110.0, Color(1.0, 0.15, 0.1, 0.6), 1.0)
		draw_circle(c, 2.0, col)
